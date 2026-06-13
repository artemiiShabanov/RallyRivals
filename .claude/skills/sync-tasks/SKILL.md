---
name: sync-tasks
description: >-
  Validate and re-render the RallyRivals task backlog. Use after editing tasks.yaml (adding,
  removing, re-sizing, re-blocking, or completing tasks), or when the user says "sync tasks",
  "update status", "refresh progress", "regenerate STATUS", or "did I break the backlog".
  Runs validation (ids, labels, blockers, cycles) and regenerates STATUS.md.
---

# Sync tasks

Keep `STATUS.md` in sync with `tasks.yaml`, and catch backlog mistakes early.

## Steps
1. From the project root, run:
   ```
   python3 tasks.py sync
   ```
   This **validates** then **renders**:
   - validate: unique ids; every `type`/`group`/`size` is known; every blocker exists; no
     dependency cycles.
   - render: rewrites `STATUS.md` (progress per type + subgroup, available-now, blocked).
2. **If validation fails**, it exits with a list of issues and does NOT render. Fix the
   reported problems in `tasks.yaml` (e.g. a typo'd blocker id, an unknown group, a cycle),
   then run `sync` again.
3. Report the summary line back to the user (e.g. `7/47 done, 12 available, 28 blocked`).

## When to run
- After any hand-edit to `tasks.yaml`.
- After `python3 tasks.py done <id>`.
- Whenever the user wants a fresh progress snapshot.

## Notes
- `STATUS.md` is generated output — if it looks stale or someone edited it, just re-run sync.
- Requires PyYAML (`pip3 install --user pyyaml`) — already installed in this project.
