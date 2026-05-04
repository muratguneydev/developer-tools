[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ProjectRoot,

    [string]$TestDir = "e2e",

    [string]$BaseUrl = "http://localhost:5000",

    [string]$Filter = "",

    [string]$OutputDir = "playwright-results"
)

$ErrorActionPreference = "Stop"

# Translate localhost/127.0.0.1 to host.docker.internal so the container can reach the host app.
$dockerBaseUrl = $BaseUrl -replace "localhost", "host.docker.internal"
$dockerBaseUrl = $dockerBaseUrl -replace "127\.0\.0\.1", "host.docker.internal"

$resultsFile = Join-Path $ProjectRoot $OutputDir "results.json"
$resultsDir  = Split-Path $resultsFile -Parent
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

$filterArg = if ($Filter) { " --grep `"$Filter`"" } else { "" }
$bashCmd = "if [ -f package-lock.json ]; then npm ci; else npm install; fi && npx playwright test$filterArg"

Write-Host ""
Write-Host "=== Playwright (Docker) ===" -ForegroundColor Cyan
Write-Host "Project : $ProjectRoot"
Write-Host "Test dir: $TestDir"
Write-Host "Base URL: $dockerBaseUrl (translated from: $BaseUrl)"
if ($Filter) { Write-Host "Filter  : $Filter" }
Write-Host ""

& docker run --rm `
    --volume "${ProjectRoot}:/work" `
    --workdir "/work/$TestDir" `
    --env "BASE_URL=$dockerBaseUrl" `
    --env "PLAYWRIGHT_JSON_OUTPUT_FILE=/work/$OutputDir/results.json" `
    "mcr.microsoft.com/playwright:v1.52.0-jammy" `
    bash -c $bashCmd

$exitCode = $LASTEXITCODE

Write-Host ""
if (Test-Path $resultsFile) {
    $results = Get-Content $resultsFile -Raw | ConvertFrom-Json
    $stats   = $results.stats

    $passColor = if ($stats.unexpected -gt 0) { "Red" } else { "Green" }
    Write-Host "=== Results ===" -ForegroundColor Cyan
    Write-Host ("Passed : {0}" -f $stats.expected)  -ForegroundColor Green
    Write-Host ("Failed : {0}" -f $stats.unexpected) -ForegroundColor $passColor
    Write-Host ("Skipped: {0}" -f $stats.skipped)   -ForegroundColor Yellow
    Write-Host ("Flaky  : {0}" -f $stats.flaky)     -ForegroundColor Yellow
    Write-Host ("Time   : {0:F1}s" -f ($stats.duration / 1000))
    Write-Host ""
    Write-Host "Results : $resultsFile" -ForegroundColor Gray
    Write-Host "Report  : $(Join-Path $ProjectRoot $OutputDir "html" "index.html")" -ForegroundColor Gray
} else {
    Write-Warning "No results file found — Playwright may have crashed before writing output."
}

exit $exitCode
