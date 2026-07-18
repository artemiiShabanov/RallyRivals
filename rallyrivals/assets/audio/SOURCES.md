# Audio provenance

One row per audio file, filled in **at download time**. See `docs/AUDIO.md` §4 for the rules
(CC0 preferred, CC-BY needs a credits entry, CC-BY-NC never — this game is commercial).

Anything CC-BY also needs a line in the in-game credits screen.

| file | source | licence | author | date |
|---|---|---|---|---|
| everything under `ambient/`, `loops/`, `sfx/` | synthesized — `scripts/tools/gen_placeholder_audio.gd` | CC0 (own work) | project | 2026-07-18 |

**All 41 sounds are currently placeholders** — filtered noise and harmonic stacks generated from
code, so CC0 by construction and safe to ship, though not intended to. As each is replaced with a
real recording, delete it from the blanket row above and give it its own row with a real source,
licence and URL.

Example of what a filled row looks like:

| `loops/engine_mid.ogg` | https://freesound.org/s/123456/ | CC0 1.0 | username | 2026-08-01 |
