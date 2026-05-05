# Copilot Instructions

General coding principles applied across all projects in this workspace.

## C# design

### Immutable domain model
Use `record` types for all domain objects. State mutations return new instances via `with` expressions — never mutate in place.

### Domain predicates as properties
Encode meaningful boolean checks as properties on the record rather than computing them externally. If a condition only requires the object's own state, it belongs on the type.

### Static factory methods on value types
Use named static factory methods instead of raw constructors when the meaning of arguments depends on context. Removes magic numbers; makes intent clear at call sites.

### Single source of truth for constants
Keep global constants in a single static class. All factory methods and checks derive from it — no scattered magic numbers.

### Pure static classes for stateless operations
Operations that transform state without owning it go in static classes: inputs in, outputs out, no side effects.

### Abstract I/O behind interfaces
Any component that performs I/O or side effects (rendering, storage, messaging) sits behind an interface. Core logic depends only on the interface, never the concrete implementation.

### Interfaces only at architectural boundaries
Use interfaces at real boundaries: I/O, external systems, interops, system resources. For single-implementation utilities, prefer a concrete class with virtual members — interfaces without multiple implementations are just ceremony.

### Expose behaviour, not internal data
Prefer methods that answer a domain question over properties that expose raw collections for the caller to query. Keep internals private; callers describe *what* they need, not *how* to compute it.

### Move logic to the type it belongs on
If a helper is doing arithmetic on another type's own fields, move that logic into the type as a method. The type is the natural home for its own behaviour.

### Extract complex conditions into named booleans
When a condition involves multiple checks, extract it into a named `bool` variable at the point of use. Named variables communicate intent without requiring a comment.

## Testing

### TDD with small iterations
Work in small TDD cycles: write a failing test, make it pass, stop and wait for review. Do not proceed to the next cycle until the green state has been committed. One red-green cycle at a time.

### Fake implementations as assertion surfaces
Test fakes capture calls and expose domain-meaningful `ShouldHaveReceived*` / `ShouldShow*` assertion methods. Integration tests assert on observable behaviour, not internal state.

### Separate test helper project
Shared test infrastructure (fakes, fixture builders) lives in its own `*.Testing` project referenced by both unit and integration test projects.

### AutoFixture with domain-aware customization
Use AutoFixture with a project-specific fixture class that customizes generation to always produce valid domain objects. Any new domain type should get a corresponding customization.

## Workflow

### Save plans to file
When a non-trivial implementation plan is agreed upon, write it to `PLAN.md` in the project root with checkboxes. Update after every completed step.
