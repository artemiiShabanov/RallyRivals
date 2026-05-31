# prototypes/

Throwaway spikes, experiments, and test scenes. **Not production code.**

## Rules
- Anything here is disposable — no other code outside `prototypes/` may depend on it.
- When a prototype proves an idea, **rewrite** the keeper parts into the real
  `scenes/` / `scripts/` (with a spec, per the gamedev-sdd skill). Don't promote
  prototype code by moving it — port the lessons, leave the mess behind.
- Excluded from release builds via the export preset filter `prototypes/*` (set at M3).
- Keep it runnable in-editor — do **not** add a `.gdignore` here.

## Why
Keeps production scope honest: if it's not in `scenes/`/`scripts/`, it isn't shipping.
