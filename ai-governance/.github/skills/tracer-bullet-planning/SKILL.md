---
name: tracer-bullet-planning
description: >
  Produce a tracer bullet plan for a development vertical slice using grill-me output,
  by identifying the smallest end-to-end task and the key dependencies needed to deliver it.
inputs:
  scope: plain-English description of the feature, story, or user need
  grillMeOutput: optional text from grill-me if available
---

# Skill: Tracer Bullet Planning

## Goal

Create a vertical slice plan for a working skeleton that can be delivered quickly and validated end-to-end.

## Output

A `slices.md` document containing:

- one or more vertical slice tasks
- why each slice is valuable
- dependencies and risks
- order by fastest feedback loop
- selected slices optimized for minimal scope and clear success criteria

## Process

1. Summarize the desired outcome from `scope` and `grillMeOutput`.
2. Identify the smallest feasible vertical slice that delivers a complete loop.
3. Break that slice into:
   - user-facing result
   - core behaviour or backend work
   - validation/test path
4. Identify dependencies:
   - architectural dependencies
   - data or API dependencies
   - platform or integration dependencies
5. Call out risks and unknowns.
6. Propose next slice(s) if additional scope remains.
7. Format the output as markdown sections and task items.

## Rules

- Prefer a working stub over a full feature.
- Optimize for one end-to-end pass, not complete polish.
- Expose assumptions and decision points.
- Keep each slice small enough to complete in a single short iteration.
- Name each slice as a task with a clear outcome.
