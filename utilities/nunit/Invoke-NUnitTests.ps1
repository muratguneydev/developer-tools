[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('CurrentFile', 'Repository')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'

# ─── File-system navigation ────────────────────────────────────────────────────

function Find-NearestCsproj {
    param([string]$StartDirectory)
    $dir = $StartDirectory
    while ($dir) {
        $hit = Get-ChildItem -Path $dir -Filter '*.csproj' -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { return [string]::Empty }
        $dir = $parent
    }
    return [string]::Empty
}

function Find-SolutionDirectory {
    param([string]$StartDirectory)
    $dir = $StartDirectory
    while ($dir) {
        $hit = Get-ChildItem -Path $dir -Filter '*.sln' -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { return [string]::Empty }
        $dir = $parent
    }
    return [string]::Empty
}

function Get-NUnitProjectPaths {
    param([string]$RootDirectory)
    @(Get-ChildItem -Path $RootDirectory -Filter '*.csproj' -Recurse -File |
        Where-Object { (Get-Content $_.FullName -Raw) -match 'NUnit' } |
        ForEach-Object { $_.FullName })
}

# ─── C# source parsing ────────────────────────────────────────────────────────

function Get-Namespace {
    param([string]$SourcePath)
    $content = Get-Content $SourcePath -Raw
    $m = [regex]::Match($content, '(?m)^namespace\s+([\w.]+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return [string]::Empty
}

function Get-ClassName {
    param([string]$SourcePath)
    $content = Get-Content $SourcePath -Raw
    $m = [regex]::Match($content, '(?:public|internal)\s+class\s+(\w+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return [string]::Empty
}

function Get-TestMethods {
    param([string]$SourcePath)
    $content = Get-Content $SourcePath -Raw
    # Matches [Test] or [Test, Attr] but NOT [TestCase] / [TestFixture] etc.
    # Lookahead (?=[,\]]) ensures the char after "Test" is , or ] only.
    $pattern = '\[Test(?=[,\]])[^\]]*\](?:\s*\[[^\]]*\])*\s+' +
               '(?:public|internal|protected)\s+(?:override\s+)?(?:async\s+)?' +
               '(?:\w+(?:<[^>]+>)?)\s+(\w+)\s*\('
    $hits = [regex]::Matches($content, $pattern,
                [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return @($hits | ForEach-Object { $_.Groups[1].Value })
}

function Get-TestCategory {
    param([string]$Namespace)
    if ($Namespace -imatch '\bcomponent\b') { return 'Component' }
    if ($Namespace -imatch '\bunit\b')      { return 'Unit' }
    return 'Other'
}

# ─── Test discovery ───────────────────────────────────────────────────────────

function Get-TestRecordsFromProject {
    param([string]$CsprojPath)
    $dir   = Split-Path $CsprojPath -Parent
    $files = @(Get-ChildItem -Path $dir -Filter '*.cs' -Recurse -File |
               Where-Object { (Get-Content $_.FullName -Raw) -match '\[Test(?=[,\]])' })

    $records = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($f in $files) {
        $ns      = Get-Namespace    $f.FullName
        $class   = Get-ClassName    $f.FullName
        $methods = Get-TestMethods  $f.FullName
        $cat     = Get-TestCategory $ns
        foreach ($method in $methods) {
            $records.Add([pscustomobject]@{
                Index    = 0    # assigned after all projects are collected
                Method   = $method
                Class    = $class
                NS       = $ns
                Category = $cat
                Project  = $CsprojPath
            })
        }
    }
    return @($records)
}

function Get-AllTestRecords {
    param([string]$RootDirectory)
    $all = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($proj in (Get-NUnitProjectPaths $RootDirectory)) {
        foreach ($rec in (Get-TestRecordsFromProject $proj)) {
            $all.Add($rec)
        }
    }
    $idx = 1
    foreach ($rec in $all) { $rec.Index = $idx++ }
    return @($all)
}

# ─── Display ──────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ''
    Write-Host ('  ' + ('─' * 54)) -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('  ' + ('─' * 54)) -ForegroundColor DarkGray
}

function Write-TestGroup {
    param([string]$Label, [string]$Color, [pscustomobject[]]$Tests)
    if ($Tests.Count -eq 0) { return }
    Write-Host ''
    Write-Host "  $Label" -ForegroundColor $Color
    foreach ($t in $Tests) {
        Write-Host ("    [{0,3}]  " -f $t.Index) -NoNewline -ForegroundColor DarkGray
        Write-Host "$($t.Class).$($t.Method)" -ForegroundColor $Color
    }
}

function Show-RepositoryTestList {
    param([pscustomobject[]]$Tests)
    $units      = @($Tests | Where-Object { $_.Category -eq 'Unit' })
    $components = @($Tests | Where-Object { $_.Category -eq 'Component' })
    $others     = @($Tests | Where-Object { $_.Category -ne 'Unit' -and $_.Category -ne 'Component' })
    Write-TestGroup 'Unit Tests'      'Green'  $units
    Write-TestGroup 'Component Tests' 'Blue'   $components
    Write-TestGroup 'Other Tests'     'Yellow' $others
    Write-Host ''
}

# ─── Docker helpers ───────────────────────────────────────────────────────────

function Test-DockerAvailable {
    $result = & docker info 2>&1
    return $LASTEXITCODE -eq 0
}

function Get-DotnetSdkVersion {
    param([string]$RootDirectory)
    $globalJson = Join-Path $RootDirectory 'global.json'
    if (Test-Path $globalJson) {
        $json = Get-Content $globalJson -Raw | ConvertFrom-Json
        if ($json.sdk -and $json.sdk.version -and
            $json.sdk.version -match '^(\d+\.\d+)') {
            return $Matches[1]
        }
    }

    $csproj = Get-ChildItem -Path $RootDirectory -Filter '*.csproj' -Recurse -File |
              Select-Object -First 1
    if ($csproj) {
        $content = Get-Content $csproj.FullName -Raw
        if ($content -match '<TargetFramework>net(\d+\.\d+)</TargetFramework>') {
            return $Matches[1]
        }
    }

    return '8.0'
}

function ConvertTo-ContainerPath {
    param([string]$HostPath, [string]$HostRoot)
    $relative = [System.IO.Path]::GetRelativePath($HostRoot, $HostPath)
    if ($relative -eq '.') { return '/work' }
    return '/work/' + $relative.Replace('\', '/')
}

# ─── Container test execution ─────────────────────────────────────────────────

function Invoke-ContainerTest {
    param([string]$HostRoot, [string]$ContainerTarget, [string]$Filter, [string]$ResolvedSdk)
    $image      = "mcr.microsoft.com/dotnet/sdk:$ResolvedSdk"
    $nugetCache = Join-Path $env:USERPROFILE '.nuget\packages'

    Write-Host ''
    Write-Host '  ══════════════════════════════════════════════════════' -ForegroundColor Cyan
    Write-Host '  Running Tests in Container' -ForegroundColor Cyan
    Write-Host '  ══════════════════════════════════════════════════════' -ForegroundColor Cyan
    Write-Host "  Image  : $image"
    Write-Host "  Source : $HostRoot"
    Write-Host "  Target : $ContainerTarget"
    if ($Filter) { Write-Host "  Filter : $Filter" -ForegroundColor DarkGray }
    Write-Host ''

    $dockerArgs = [System.Collections.Generic.List[string]]@(
        'run', '--rm',
        '--volume', "${HostRoot}:/work",
        '--workdir', '/work'
    )
    if (Test-Path $nugetCache) {
        $dockerArgs.Add('--volume')
        $dockerArgs.Add("${nugetCache}:/root/.nuget/packages")
    }
    $dockerArgs.Add($image)
    $dockerArgs.Add('dotnet')
    $dockerArgs.Add('test')
    $dockerArgs.Add($ContainerTarget)
    if ($Filter) {
        $dockerArgs.Add('--filter')
        $dockerArgs.Add($Filter)
    }

    & docker @dockerArgs
}

function Invoke-AllContainerTests {
    param([string]$HostRoot, [string]$ResolvedSdk)
    $sln = Get-ChildItem -Path $HostRoot -Filter '*.sln' -File | Select-Object -First 1
    $containerTarget = if ($sln) { ConvertTo-ContainerPath $sln.FullName $HostRoot } else { '/work' }
    Invoke-ContainerTest $HostRoot $containerTarget '' $ResolvedSdk
}

function Invoke-SelectedContainerTests {
    param([string]$HostRoot, [pscustomobject[]]$Records, [string]$ResolvedSdk)
    $sln = Get-ChildItem -Path $HostRoot -Filter '*.sln' -File | Select-Object -First 1
    $containerTarget = if ($sln) { ConvertTo-ContainerPath $sln.FullName $HostRoot } else { '/work' }
    $filter = ($Records |
               ForEach-Object { "FullyQualifiedName=$($_.NS).$($_.Class).$($_.Method)" }) -join '|'
    Invoke-ContainerTest $HostRoot $containerTarget $filter $ResolvedSdk
}

# ─── Task 1 – current file ────────────────────────────────────────────────────

function Invoke-CurrentFileMode {
    param([string]$SourcePath, [string]$ResolvedSdk)

    $ns      = Get-Namespace   $SourcePath
    $class   = Get-ClassName   $SourcePath
    $methods = Get-TestMethods $SourcePath
    $csproj  = Find-NearestCsproj (Split-Path $SourcePath -Parent)

    if ($methods.Count -eq 0) {
        Write-Host ''
        Write-Host '  No [Test] methods found in the current file.' -ForegroundColor Yellow
        return
    }
    if (-not $csproj) {
        Write-Host ''
        Write-Host '  Could not locate a .csproj for this file.' -ForegroundColor Red
        return
    }

    $slnDir          = Find-SolutionDirectory (Split-Path $SourcePath -Parent)
    $hostRoot        = if ($slnDir) { $slnDir } else { Split-Path $csproj -Parent }
    $containerCsproj = ConvertTo-ContainerPath $csproj $hostRoot

    $category = Get-TestCategory $ns
    $color    = switch ($category) { 'Component' { 'Blue' } 'Unit' { 'Green' } default { 'White' } }

    Write-Header $class
    Write-Host "  Namespace : $ns"      -ForegroundColor DarkGray
    Write-Host "  Category  : $category" -ForegroundColor DarkGray
    Write-Host ''

    for ($i = 0; $i -lt $methods.Count; $i++) {
        Write-Host ("    [{0,2}]  " -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
        Write-Host $methods[$i] -ForegroundColor $color
    }

    Write-Host ''
    Write-Host '  Press Enter to run ALL, or type numbers to run specific tests (e.g. 1,3):' -ForegroundColor Cyan
    $selection = Read-Host '  >'

    $chosenMethods = @()
    if ($selection.Trim() -ne '') {
        $chosenMethods = @($selection.Split(',') |
            ForEach-Object { $_.Trim() } |
            Where-Object   { $_ -match '^\d+$' } |
            ForEach-Object {
                $idx = [int]$_ - 1
                if ($idx -ge 0 -and $idx -lt $methods.Count) { $methods[$idx] }
            } |
            Where-Object   { $_ })
    }

    $filter = if ($chosenMethods.Count -eq 0) {
        "FullyQualifiedName~$ns.$class"
    }
    else {
        ($chosenMethods | ForEach-Object { "FullyQualifiedName=$ns.$class.$_" }) -join '|'
    }

    Invoke-ContainerTest $hostRoot $containerCsproj $filter $ResolvedSdk
}

# ─── Task 2 – whole repository ────────────────────────────────────────────────

function Invoke-RepositoryMode {
    param([string]$SourcePath, [string]$ResolvedSdk)

    $slnDir = Find-SolutionDirectory (Split-Path $SourcePath -Parent)
    if (-not $slnDir) {
        $csproj = Find-NearestCsproj (Split-Path $SourcePath -Parent)
        if (-not $csproj) {
            Write-Host ''
            Write-Host '  Could not locate a .sln or .csproj for this file.' -ForegroundColor Red
            return
        }
        $slnDir = Split-Path $csproj -Parent
    }

    Write-Host ''
    Write-Host '  Discovering tests …' -ForegroundColor DarkGray
    $allTests = Get-AllTestRecords $slnDir

    if ($allTests.Count -eq 0) {
        Write-Host '  No NUnit tests found in the solution.' -ForegroundColor Yellow
        return
    }

    $unitCount      = @($allTests | Where-Object { $_.Category -eq 'Unit' }).Count
    $componentCount = @($allTests | Where-Object { $_.Category -eq 'Component' }).Count

    Write-Header "All NUnit Tests  ($($allTests.Count) total)"
    Show-RepositoryTestList $allTests

    Write-Host '  ─────────────────────────────────────────────────────' -ForegroundColor DarkGray
    Write-Host "  U  – all unit tests ($unitCount)" -ForegroundColor Green
    Write-Host "  C  – all component tests ($componentCount)" -ForegroundColor Blue
    Write-Host '  A  – all tests in solution' -ForegroundColor Cyan
    Write-Host '  1,3,5 … – run specific tests by number' -ForegroundColor Gray
    Write-Host ''
    $selection = Read-Host '  >'
    $choice    = $selection.Trim().ToUpper()

    if ($choice -eq 'A') {
        Invoke-AllContainerTests $slnDir $ResolvedSdk
        return
    }

    if ($choice -eq 'U') {
        $subset = @($allTests | Where-Object { $_.Category -eq 'Unit' })
        if ($subset.Count -eq 0) { Write-Host '  No unit tests found.' -ForegroundColor Yellow; return }
        Invoke-SelectedContainerTests $slnDir $subset $ResolvedSdk
        return
    }

    if ($choice -eq 'C') {
        $subset = @($allTests | Where-Object { $_.Category -eq 'Component' })
        if ($subset.Count -eq 0) { Write-Host '  No component tests found.' -ForegroundColor Yellow; return }
        Invoke-SelectedContainerTests $slnDir $subset $ResolvedSdk
        return
    }

    $indices  = @($choice.Split(',') |
                  ForEach-Object { $_.Trim() } |
                  Where-Object   { $_ -match '^\d+$' } |
                  ForEach-Object { [int]$_ })
    $selected = @($allTests | Where-Object { $_.Index -in $indices })

    if ($selected.Count -eq 0) {
        Write-Host '  No valid selection made.' -ForegroundColor Red
        return
    }

    Invoke-SelectedContainerTests $slnDir $selected $ResolvedSdk
}

# ─── Entry point ──────────────────────────────────────────────────────────────

if (-not (Test-Path $FilePath)) {
    Write-Host "  File not found: $FilePath" -ForegroundColor Red
    exit 1
}

if ([System.IO.Path]::GetExtension($FilePath) -ne '.cs') {
    Write-Host '  The active file is not a C# source file.' -ForegroundColor Yellow
    exit 0
}

if (-not (Test-DockerAvailable)) {
    Write-Host ''
    Write-Host '  Docker is not available or not running.' -ForegroundColor Red
    Write-Host '  Start Docker Desktop and try again.' -ForegroundColor DarkGray
    exit 1
}

$fileDir     = Split-Path $FilePath -Parent
$slnDir      = Find-SolutionDirectory $fileDir
$csproj      = Find-NearestCsproj $fileDir
$lookupRoot  = if ($slnDir) { $slnDir } elseif ($csproj) { Split-Path $csproj -Parent } else { $fileDir }
$resolvedSdk = Get-DotnetSdkVersion $lookupRoot

Write-Host "  SDK : mcr.microsoft.com/dotnet/sdk:$resolvedSdk" -ForegroundColor DarkGray

switch ($Mode) {
    'CurrentFile' { Invoke-CurrentFileMode $FilePath $resolvedSdk }
    'Repository'  { Invoke-RepositoryMode  $FilePath $resolvedSdk }
}
