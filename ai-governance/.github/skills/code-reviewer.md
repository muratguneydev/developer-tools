---
name: code-reviewer
description: >
  Review C# code for clean code, SOLID, composition over inheritance, TDD conventions, AutoFixture/AutoMoqData test usage, typed IDs, and null object patterns.
---

# Skill: Code Reviewer

## Output

A structured review of C# code that checks the requested principles and reports issues without modifying any files.

## Rules

Review the code against these principles:

- Verify the code also follows the workspace-level guidance in `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md`.

1. Clean code
   - Meaningful names and intent-revealing abstractions
   - Small, focused methods and classes
   - Minimal nesting and no commented-out code
   - No duplicated or dead logic

2. SOLID design
   - Single Responsibility: each type has one reason to change
   - Open/Closed: behaviour extends without modifying existing code
   - Liskov Substitution: abstractions are safely substitutable
   - Interface Segregation: clients depend on narrow interfaces
   - Dependency Inversion: high-level behaviour depends on abstractions, not concretes

3. Composition over inheritance
   - Prefer composing services and collaborators instead of shared base classes
   - No base classes used for code reuse or shared implementation
   - Use small reusable components and injection rather than class hierarchies

4. TDD and unit test style
   - Unit tests use `[Test, AutoMoqData]` or `[Test, AutoData]`
   - No `[TestFixture]` on test classes
   - No `new Fixture()` or manual fixture setup inside tests
   - Test method names follow `ShouldXXX_WhenYYY` style
   - Parameter order: plain data values first, then `[Frozen]` deps, then `sut` last
   - Mock roles use `Stub`, `Spy`, `Dummy` naming
   - Tests include `// Arrange`, `// Act`, and `// Assert`
   - Assertions should describe whole-object expectations where appropriate

5. No primitive obsession and typed IDs
   - Avoid raw `int`, `Guid`, or `string` for domain identifiers or semantic values
   - Prefer dedicated typed ID/value object types for identity and domain concepts
   - Avoid passing primitives through the domain layer when a semantic type is appropriate

6. Null object pattern preferred over nullable types
   - Prefer explicit null object or `Type.Empty` sentinel implementations over `T?`
   - Avoid nullable reference and nullable value types for domain behaviour when a null object is more expressive

## Behavior

- Provide a short verdict for each principle
- Identify specific issues and reference files or snippets
- Suggest clear remediation steps
- Do not edit, create, or delete files while reviewing
