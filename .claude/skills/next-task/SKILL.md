---
name: next-task
description: >-
  Suggest what to work on next in RallyRivals. Use when the user asks "what's next",
  "what should I work on", "give me a task", "next task", "pick something", or asks for
  work of a certain size (micro/small/default/big/huge) or type (code/art/audio/content/
  balance/design/setup) or subgroup. Reads the backlog (tasks.yaml) and proposes 3 random
  unblocked tasks.
---

# Next task

Pick the next task from the dependency-aware backlog (`tasks.yaml`), respecting blockers.

## Steps
1. **Parse filters** from the user's message (all optional):
   - `--size` — micro · small · default · big · huge
   - `--type` — code · art · audio · content · balance · design · setup
   - `--group` — a subgroup (e.g. `vehicle`, `voxel`, `sfx`); see `meta.types` in tasks.yaml.
2. If the user gave **no** filter and seems open, you may ask one quick question: *what size
   and/or type are you in the mood for?* — or just run unfiltered if they want anything.
3. From the project root, run:
   ```
   python3 tasks.py next [--size S] [--type T] [--group G]
   ```
   It prints up to 3 random **unblocked** TODO tasks (all blockers done).
4. Present the options plainly and let the user choose. Don't auto-start.
5. **When they finish a task**, mark it and refresh:
   ```
   python3 tasks.py done <id>
   python3 tasks.py sync
   ```

## Notes
- Only `tasks.yaml` is authoritative. `STATUS.md` is generated — never hand-edit it.
- If `next` says nothing is available, blockers are gating everything that matches — suggest a
  different filter, or look at the blocked items via `python3 tasks.py list --status all`.
- Tasks are atomic by design; if a chosen task feels splittable, that's a signal to edit
  tasks.yaml (break it up) and re-`sync`.
