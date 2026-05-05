---
name: implement-tdd-feature
description: >
  Full TDD cycle for a single feature or user story. Use this skill when an
  implementation subtask requires writing new behaviour — not for refactors or
  config-only changes.
inputs:
  feature: plain-English description of the behaviour to implement
---

# Skill: Implement TDD Feature

## Preconditions

- Tests can be run (build passes before you start)
- You know which unit test project and which integration/E2E test project to target

## Step 1 — Write failing unit tests

1. Locate or create the test class: `<ClassUnderTest>Tests`
2. Add one test method per scenario, following the conventions in `testing.instructions.md`:
   - Method name: `ShouldXXX_WhenYYY`
   - Attribute: `[Test, AutoMoqData]` — no `[TestFixture]` on the class
   - Parameter order: setup values → `[Frozen]` deps → `sut` last
   - Mock suffix: `Stub` (returns values) / `Spy` (verified) / `Dummy` (prevents crash)
   - `[Frozen]` requires `using AutoFixture.NUnit4;`
   - Sections: `// Arrange`, `// Act`, `// Assert`
   - Assertions: Shouldly on the whole object — not individual properties
   - Omit `Times.Once` from `Verify` calls
3. Run tests. **Confirm they are red before continuing.**

## Step 2 — Write failing integration / E2E tests

1. Add tests that cover the new behaviour end-to-end
2. Run tests. **Confirm they are red before continuing.**

## Step 3 — Implement (green)

Write the minimum code to make all tests pass. Apply conventions from `csharp.instructions.md`:

- `namespace` declaration first in every `.cs` file, then `using` directives
- No `Async` suffix on method names
- Two-constructor pattern instead of nullable optional parameters
- `Type.Empty` sentinel instead of `Type?` nullable in view models / domain objects
- Allman brace style; always use braces on `if` / `for` / `while`
- Use `record` types for domain objects; return `this with { ... }` for mutations

Run tests. **All must be green before proceeding.**

## Step 4 — Refactor

- Remove duplication
- Clarify naming; move logic to the type it belongs on
- Extract complex conditions into named `bool` variables
- Re-run tests — must stay green

## Step 5 — Commit and push

```
git add <changed files>
git commit -m "<concise message>"
git push
```

Every iteration ends with a commit and push.

## Output

Indicate which files were created or modified and confirm that all tests pass.
