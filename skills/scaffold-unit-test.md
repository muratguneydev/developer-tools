---
name: scaffold-unit-test
description: >
  Produce a correctly structured NUnit + AutoFixture + Shouldly test method for
  a specific class and scenario. Use this skill as a sub-step inside
  implement-tdd-feature when adding individual test cases.
inputs:
  class: fully qualified name of the class under test
  scenario: the behaviour or edge case to cover
---

# Skill: Scaffold Unit Test

## Output

A single test method ready to paste into the appropriate `<ClassUnderTest>Tests` class.

## Rules

Apply every item in this checklist. Do not emit the method until all pass.

| # | Rule |
|---|------|
| 1 | Method name follows `ShouldXXX_WhenYYY` |
| 2 | No `[TestFixture]` on the class |
| 3 | Attribute is `[Test, AutoMoqData]` (or `[Test, AutoData]` if no mocks needed) |
| 4 | `[Frozen]` deps use `using AutoFixture.NUnit4;`, not just `using AutoFixture;` |
| 4a | If a dependency is a concrete class, use both `[Frozen]` and `[Mock]` attributes |
| 5 | Parameter order: plain data values → `[Frozen]` deps → `sut` last |
| 6 | Mock parameter named by role: `Stub` / `Spy` / `Dummy` |
| 7 | Sections: `// Arrange`, `// Act`, `// Assert` — all three present |
| 8 | Assertions use Shouldly on the **whole object** (`result.ShouldBe(expected with { ... })`) |
| 9 | `Times.Once` omitted from any `Verify` calls |
| 10 | No `[TestFixture]`, no `Fixture` field, no `new Fixture()` in the body |

## Template

```csharp
[Test, AutoMoqData]
public async Task ShouldXXX_WhenYYY(
    SomeValue setupValue,                            // 1. plain AutoFixture values
    [Frozen] Mock<IDependency> dependencyStub,       // 2. [Frozen] deps (interface)
    ClassUnderTest sut)                              // 3. sut last
{
    // Arrange
    dependencyStub.Setup(d => d.Method()).ReturnsAsync(setupValue);

    // Act
    var result = await sut.Method();

    // Assert
    result.ShouldBe(expected);
}
```

**For concrete class dependencies, use both attributes:**
```csharp
[Frozen, Mock] ConcreteService serviceSpy
```
