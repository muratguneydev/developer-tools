---
name: kanban-organizer
description: >
  Convert tracer bullet vertical slices into a markdown kanban board with phases,
  dependencies, and a Mermaid dependency diagram, optimized for fast feedback loops.
inputs:
  slicesDocument: markdown content containing vertical slice tasks and dependencies
---

# Skill: Kanban Organizer

## Goal

Transform `slices.md` input into `kanban.md` with a task board, phases, and a Mermaid dependency diagram.

## Output

A `kanban.md` document containing:

- Kanban columns by phase: Backlog, Ready, In Progress, Done (or similar)
- tasks organized by phase
- explicit dependencies or relationships
- a Mermaid graph of task flow
- notes on parallel opportunities and phase ordering

## Process

1. Extract tasks and dependencies from `slicesDocument`.
2. Classify each task by phase:
   - discovery/prep
   - design/architecture
   - build/implement
   - test/validate
   - deploy/review
3. Identify tasks that can run in parallel without blocking each other.
4. Identify critical path tasks.
5. Create a Mermaid graph showing task dependencies.
6. Generate a markdown board with columns and task cards.
7. Include guidance on next priorities and what to pull first.

## Rules

- Preserve original task names and outcomes.
- Avoid overloading a single phase with too many tasks.
- Ensure dependencies are explicit in both the board and the graph.
- Favor tasks that unblock feedback loops early.
- Label tasks with owners or types only if present in source.
