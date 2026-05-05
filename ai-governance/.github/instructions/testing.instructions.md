---
applyTo: "tests/**/*.cs"
---

# NUnit / AutoFixture / Shouldly Testing Conventions

## Test class rules

- Do **not** add `[TestFixture]` to test classes — NUnit 3+ auto-discovers them without it.
- Class names: `<ClassUnderTest>Tests` (e.g. `ChoreServiceTests`).
- Method names: `ShouldXXX_WhenYYY` (e.g. `ShouldMarkComplete_WhenChoreExists`).

## AutoFixture — parameter injection

Use `[Test, AutoData]` (or `[Test, AutoMoqData]`) to inject randomised values as method parameters. Do not create a `Fixture` field on the class.

```csharp
[Test, AutoMoqData]
public async Task ShouldReturnChore_WhenChoreExists(
    List<Chore> chores,                              // 1. setup values first
    [Frozen] Mock<IChoreRepository> repoStub,        // 2. [Frozen] deps next
    ChoreService sut)                                // 3. sut always last
{
    // Arrange
    repoStub.Setup(r => r.GetAll()).ReturnsAsync(chores);

    // Act
    var result = await sut.GetAll();

    // Assert
    result.ShouldBe(chores);
}
```

### Parameter order (mandatory)

1. Plain AutoFixture values used as test data (no attributes)
2. `[Frozen]` dependencies
3. `sut` — always the last parameter

### `[Frozen]` namespace

`[Frozen]` lives in `AutoFixture.NUnit4`, not `AutoFixture`. Always add:

```csharp
using AutoFixture.NUnit4;
```

alongside `using AutoFixture;`.

## Test double naming

Name every `[Frozen] Mock<T>` parameter by its role:

| Suffix | Role | Example |
|--------|------|---------|
| `Stub` | Set up to return values; drives Arrange | `repoStub` |
| `Spy`  | Verified with `Verify(...)` in Assert | `repoSpy` |
| `Dummy`| Only present to prevent a crash; no setup, no verify | `repoDummy` |

## Verify calls

Omit `Times.Once` from `Verify` — it is the default and adding it is redundant noise.

```csharp
// Good
repoSpy.Verify(r => r.Save(It.IsAny<Chore>()));

// Avoid
repoSpy.Verify(r => r.Save(It.IsAny<Chore>()), Times.Once);
```

## Structure

Every test follows Arrange / Act / Assert with explicit `// Arrange`, `// Act`, `// Assert` comments.

## Assertions

Use Shouldly. Assert on the **whole object** rather than individual properties.

```csharp
// Good
result.ShouldBe(expected with { Status = Status.Complete });

// Avoid
result.Status.ShouldBe(Status.Complete);
result.Title.ShouldBe(expected.Title);
```

Use `ShouldBe`, `ShouldNotBeNull`, `ShouldContain`, etc. Do not use `Assert.That`.
