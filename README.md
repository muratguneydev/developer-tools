# developer-tools

Central repository for shared AI capabilities and developer utilities. VS Code workspaces reference this folder to get Copilot instructions, reusable prompts, and coding conventions without duplicating them per project.

## How to use in a workspace

Open VS Code with a multi-root workspace that includes this repo. Copilot automatically picks up `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md` from any folder in the workspace.

Example `.code-workspace` entry:

```json
{
  "folders": [
    { "path": "C:/Code/developer-tools" },
    { "path": "C:/Code/my-project" }
  ]
}
```

## Repository layout

```
.github/
  copilot-instructions.md          # workspace-level rules loaded for every Copilot session
  instructions/
    csharp.instructions.md         # C# conventions, applied to **/*.cs
    testing.instructions.md        # NUnit/AutoFixture/Shouldly conventions, applied to tests/**/*.cs
  prompts/
    grill-me.prompt.md             # relentless design interview (user-invocable)
skills/
  implement-tdd-feature.md         # agent skill: full TDD cycle for a feature
  scaffold-unit-test.md            # agent skill: produce a single NUnit test method
.vscode/
  mcp.json                         # MCP tool server configurations for Copilot agent mode (context7)
  tasks.json                       # shared VS Code tasks
ai-governance/
  agents/                          # agent configuration files
  policies/                        # AI usage policies
utilities/
  playwright/
    run-tests.ps1                  # run Playwright tests via Docker from any project root
    docker-compose.yml             # reference compose file — copy to your e2e/ directory
    playwright.config.template.ts  # Playwright config template for projects
    package.template.json          # package.json template for the e2e directory
    tasks.snippet.json             # VS Code task snippets to paste into a project's tasks.json
  vscode/
    extensions.md                  # recommended VS Code extensions
    snippets/                      # shared VS Code snippet files
  scripts/                         # shared automation scripts
  configs/                         # shared configuration files
```

## AI capabilities

### Copilot instructions (`.github/copilot-instructions.md`)

Always-on rules loaded into every Copilot Chat session. Covers:
- Immutable domain model with C# records
- Domain predicates, static factories, single source of truth for constants
- Abstracting I/O behind interfaces; interfaces only at real boundaries
- TDD workflow: small red-green-refactor cycles, one at a time
- Fake implementations as assertion surfaces
- Saving plans to `PLAN.md`

### Coding instructions (`.github/instructions/`)

File-scoped instructions applied automatically based on `applyTo` glob:

| File | Applies to | What it covers |
|------|-----------|----------------|
| `csharp.instructions.md` | `**/*.cs` | Namespace-first file layout, no Async suffix, constructor pattern, Null Object/Empty sentinel, Allman brace style, interface vs virtual guidance |
| `testing.instructions.md` | `tests/**/*.cs` | No `[TestFixture]`, `ShouldXXX_WhenYYY` naming, `[Test, AutoData]` injection, parameter order, Stub/Spy/Dummy naming, whole-object Shouldly assertions |

### Prompts (`.github/prompts/`)

User-invocable prompt files selectable in Copilot Chat (`@workspace /prompt <name>`):

| Prompt | Purpose |
|--------|---------|
| `grill-me` | Relentless design interview — stress-tests a plan by walking down every branch of the decision tree |

### Agents (`ai-governance/agents/`)

Specialized agent workflows that can be invoked for specific development tasks.

| Agent | Purpose |
|-------|---------|
| `orchestrator` | Master agent that orchestrates implementation of a complete kanban board: creates development PR, manages task scheduling, runs implementation + code-review cycles, gates on human approval, and handles feedback loops (automated reviewer + human) until all tasks are approved |
| `slice-implementer` | Implements code for a single vertical slice task using the TDD workflow; called by the orchestrator; can be called multiple times to resolve automated and human review feedback |
| `pr-manager` | Manages GitHub PR operations using `gh` CLI: creates PRs, reads comments, updates descriptions, and tracks PR lifecycle |
| `code-reviewer` | Reviews C# code for clean code, SOLID, composition, TDD conventions, and workspace instruction compliance without modifying files |

### Agent skills (`skills/`)

Instruction modules consumed by an implementation agent as part of its workflow — not invoked directly by the user.

| Skill | Purpose |
|-------|---------|
| `tracer-bullet-planning` | Create a vertical slice plan from grill-me output and feature scope, optimized for fast validation and minimal end-to-end delivery |
| `kanban-organizer` | Convert vertical slice tasks into a markdown kanban board with phases, dependencies, and a Mermaid graph |
| `implement-tdd-feature` | Full TDD cycle for a feature: failing unit tests → failing E2E tests → minimum implementation → refactor → commit+push |
| `scaffold-unit-test` | Produces a single, checklist-verified NUnit + AutoFixture + Shouldly test method; used as a sub-step inside `implement-tdd-feature` |
| `run-playwright-tests` | Runs the project's Playwright test suite via Docker and uses results as a feedback loop during UI implementation: invocation, result parsing, failure interpretation, and red-green iteration |

### Playwright testing (`utilities/playwright/`)

Shared infrastructure for running Playwright UI tests inside Docker so browsers never need to be
installed locally. Works for manual runs from VS Code and for automated agent feedback loops.

**Quick start for a project:**

1. Copy `utilities/playwright/playwright.config.template.ts` → `e2e/playwright.config.ts`
2. Copy `utilities/playwright/package.template.json` → `e2e/package.json` (then `npm install`)
3. Write tests in `e2e/tests/`
4. Add the entries from `utilities/playwright/tasks.snippet.json` to your project's `.vscode/tasks.json`
5. Run **Playwright: Run All Tests (Docker)** from the VS Code task runner

**Manual run from the terminal:**

```powershell
& "C:\Code\developer-tools\utilities\playwright\run-tests.ps1" `
    -ProjectRoot "C:\Code\my-project" `
    -BaseUrl "http://localhost:5000"
```

The script translates `localhost` to `host.docker.internal` automatically, starts the official
Playwright Docker image, mounts the project, runs `npm ci && npx playwright test`, and writes
results to `playwright-results/results.json` and an HTML report to `playwright-results/html/`.

**VS Code tasks** (`Playwright: Run All Tests (Docker)`, `Playwright: Run Filtered Tests (Docker)`)
are defined in `.vscode/tasks.json` and prompt for project path and base URL — usable from the
developer-tools workspace without any per-project setup.

**Agent feedback loop:** the `run-playwright-tests` skill tells agents how to wire Playwright into
the UI implementation cycle. The `slice-implementer` agent uses it automatically when a task
involves UI: run baseline → write failing tests → implement → run again → fix → repeat until green.

### MCP servers (`.vscode/mcp.json`)

Registers tool servers for Copilot agent mode. Add server entries here and they become available across all workspaces that include this repo.

| Server | Purpose |
|--------|---------|
| `context7` | Fetches up-to-date library documentation on demand — use `use context7` in any Copilot/agent prompt to pull accurate docs for ASP.NET Core, EF Core, NuGet packages, and any other library instead of relying on potentially stale training data |

**Prerequisites:** Node.js must be installed (the server runs via `npx` and is downloaded automatically on first use — no manual install needed).

**Usage in prompts:** append `use context7` to any agent or Copilot Chat prompt, e.g.:

```
How do I configure minimal APIs in ASP.NET Core 9? use context7
```

The server resolves the library from the prompt, fetches the current docs, and injects them into the model context before answering.
