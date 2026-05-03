---
applyTo: "**/*.cs"
---

# C# Coding Conventions

## File structure

Every `.cs` file must open with the `namespace` declaration, followed by a blank line, then `using` directives:

```csharp
namespace MyProject.Services;

using System.Collections.Generic;
using MyProject.Models;
```

Never put `using` directives above the `namespace` declaration.

## Naming

Do **not** suffix async method names with `Async`. The `Task` / `ValueTask` return type is sufficient.

```csharp
// Good
Task<Child> GetChild(ChildId id)

// Avoid
Task<Child> GetChildAsync(ChildId id)
```

## Constructor design

When a class has two distinct modes, use two explicit constructors and a private `bool` field. Do not use nullable optional parameters to distinguish modes.

```csharp
// Good
public MyConfig(string key, string projectId)
{
    _useEmulator = false;
}

public MyConfig(string key, string projectId, string emulatorHost) : this(key, projectId)
{
    _useEmulator = true;
    EmulatorHost = emulatorHost;
}

private readonly bool _useEmulator;
public bool UseEmulator => _useEmulator;

// Avoid
public MyConfig(string key, string projectId, string? emulatorHost = null) { }
```

## Null Object pattern

Do not use nullable types for "nothing selected / not set" state in view models or domain objects. Add a static `Empty` sentinel instead.

```csharp
public record Child(ChildId Id, string Name)
{
    public static readonly Child Empty = new(new ChildId(string.Empty), string.Empty);
}
```

Initialise properties to `Type.Empty` — never to `null`. Eliminates null-checks and `!` operators throughout callers.

## Immutable domain model

Use `record` types for all domain objects. State mutations return new instances via `with` expressions.

```csharp
// Good
public GameState MoveLeft(GameState state) => state with { Player = state.Player with { X = state.Player.X - 1 } };

// Avoid
state.Player.X -= 1;
```

## Brace style (.editorconfig)

- Always use curly braces for `if` / `for` / `foreach` / `while` / `do`, even single-line bodies
- Opening brace on its own line (Allman style)
- Expression-bodied properties are fine; prefer block-bodied methods

```csharp
// Good
if (condition)
{
    DoSomething();
}

// Avoid
if (condition) DoSomething();
```

## Interfaces vs virtual

Use interfaces at real architectural boundaries: I/O, external systems, interops, system resources. For single-implementation utilities, prefer a concrete class with `virtual` members over a gratuitous interface.
