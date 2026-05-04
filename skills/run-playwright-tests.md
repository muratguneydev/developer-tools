---
name: run-playwright-tests
description: >
  Skill for running Playwright tests via Docker and using the results as a feedback mechanism
  during UI implementation. Covers invocation, result parsing, failure interpretation, and the
  iterative red-green loop for building user interfaces.
---

# Skill: Run Playwright Tests

## Purpose

Run the project's Playwright test suite inside a Docker container and interpret the results to
drive UI implementation. Use this skill whenever a task involves creating or modifying UI — pages,
components, forms, views, or any user-facing behaviour.

## Prerequisites

Verify before running:
1. Docker Desktop is running (`docker info` succeeds).
2. The project has a Playwright test directory — look for `e2e/package.json`, `playwright/package.json`,
   or `e2e-tests/package.json`.
3. The application under test is already running (start it before invoking this skill).
4. The `playwright.config.ts` in the test directory configures the `json` reporter outputting to
   `../playwright-results/results.json`, OR the run script will override via env var.

If the test directory or config does not exist, scaffold it using the templates at
`developer-tools/utilities/playwright/playwright.config.template.ts` and
`developer-tools/utilities/playwright/package.template.json`.

## Invocation

Run via the shared PowerShell script. Replace `$projectRoot`, `$baseUrl`, and optionally `$filter`:

```powershell
& "C:\Code\developer-tools\utilities\playwright\run-tests.ps1" `
    -ProjectRoot "C:\Code\my-project" `
    -BaseUrl "http://localhost:5000" `
    -TestDir "e2e"
```

To run a subset of tests by name/pattern:

```powershell
& "C:\Code\developer-tools\utilities\playwright\run-tests.ps1" `
    -ProjectRoot "C:\Code\my-project" `
    -BaseUrl "http://localhost:5000" `
    -Filter "login"
```

Parameters:
| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ProjectRoot` | *(required)* | Absolute path to the project root |
| `-TestDir` | `e2e` | Subdirectory containing `package.json` and `playwright.config.ts` |
| `-BaseUrl` | `http://localhost:5000` | URL of the running application (`localhost` is auto-translated to `host.docker.internal` for Docker) |
| `-Filter` | *(empty — all tests)* | Grep pattern passed to `--grep` |
| `-OutputDir` | `playwright-results` | Subdirectory under `ProjectRoot` where results are written |

## Reading results

After the run, results are at `$projectRoot/playwright-results/results.json`.

Key fields:
```json
{
  "stats": {
    "expected": 12,
    "unexpected": 2,
    "skipped": 0,
    "duration": 18432
  },
  "suites": [ ... ]
}
```

**Quick pass/fail check**: `stats.unexpected > 0` means there are failures.

**Finding failed tests** — recursively walk `suites[].suites[]` until you reach entries with `specs`:
```
suites[].specs[].tests[].results[].status  →  "expected" | "unexpected" | "skipped" | "flaky"
suites[].specs[].tests[].results[].error.message  →  failure reason
suites[].specs[].tests[].results[].attachments  →  screenshots, traces, videos
```

Attachment paths are relative to the `playwright-results/` directory. Screenshots and traces give
the most diagnostic value when fixing UI failures.

## The UI feedback loop

Use this loop whenever implementing or modifying UI:

```
1. Run tests (establish baseline — note which tests were already failing)
2. Write new Playwright tests for the feature (red — they should fail)
3. Implement the UI
4. Run tests again
5. Read results.json — find tests where status = "unexpected"
6. For each failure:
   a. Read error.message for what assertion failed
   b. Check screenshot attachment for the visual state
   c. Fix the UI to satisfy the assertion
7. Repeat from step 4 until stats.unexpected = 0
8. Confirm no previously-passing tests are now failing (no regressions)
9. Commit
```

Do not consider a UI task complete until all Playwright tests pass.

## Interpreting common failures

| Error pattern | Likely cause | Where to look |
|---------------|-------------|---------------|
| `Locator not found` / `waiting for ...` | Element missing or wrong selector | Check the rendered HTML; verify the component is mounted |
| `Expected ... to contain ...` | Wrong text content | Check data binding, string interpolation, translations |
| `TimeoutError: page.goto` | App not running or wrong port | Confirm the app is started; check `-BaseUrl` |
| `net::ERR_CONNECTION_REFUSED` | App crashed or port mismatch | Restart the app; verify the port |
| `Expected: ... Received: ...` (visual diff) | CSS/layout regression | Compare screenshots; check CSS changes |

## Practical tips for agents

- Run tests **before** starting UI implementation to capture the pre-change baseline.
- When a test fails with a vague error, read the screenshot attachment — it reveals the actual visual state faster than reading error messages.
- Keep the feedback loop tight: implement one UI change, run the relevant test filter, fix, repeat — rather than implementing everything and running all tests at the end.
- If `npm ci` fails in Docker (missing lockfile), the run script falls back to `npm install`. First-run installs are slow; subsequent runs use the Docker layer cache.
- Add `playwright-results/` to the project's `.gitignore`.
