# Rivals — the four chapter bosses

Authoritative definition of v1's four boss-rivals (`content-rivals-defs`). Each is a chapter's
finale: beat them to pink-slip their car and advance to the next region (GDD §5, §8).

## What a boss is (and isn't)

- **A progression gate and a car, not a character.** No backstory, no taunts, no dialogue — v1
  cuts all narrative (GDD §6, §12). A boss's identity is a name, a number, and *how they drive*.
- **A separate 10th driver.** The 9 generated chapter regulars (`content-rivals-roster`) race all
  chapter long; the boss appears **only in the boss race** (spec: [field-matching](specs/field-matching.md)).
  The boss race fields all 11 (9 + boss + you).
- **Brand + class + car are already fixed** by GDD §8 and the roster's `pink_slip_only` cars — the
  boss drives the very car you win. This doc authors the rest: name, number, driving manner.
- **AI never rams the player**, even in a Wilds boss race (GDD §6). Boss aggression is positional
  (blocking, holding the line), never contact.

## The four bosses

| Ch | Name | HUD | No. | Brand | Class | Car (pink-slip) |
|----|------|-----|-----|-------|-------|-----------------|
| 1 | Marek Drago | DRAGO | **66** | Wreckhouse | C | Crowbar |
| 2 | Rae Mercer | MERCER | **23** | Mayfly | B | Strobe |
| 3 | Ivo Vance | VANCE | **7** | Apex | A | Verdict |
| 4 | Boris Kozak | KOZAK | **1** | Wreckhouse | S | Juggernaut |

- **HUD** is the short name the leaderboard shows (it only fits a surname); the full name is for the
  boss-intro screen (`code-ui-boss-intro`).
- **Numbers are reserved** campaign-wide — the roster generator must exclude {66, 23, 7, 1} so no
  regular driver shares a boss's plate (spec: numbers are 1–100, campaign-unique).

## Driving intent

One authored line each — the *manner* the AI should express, for `code-ai-boss` /
`code-ai-difficulty` to realise. **Not a formal behaviour enum** (defining that set is a separate
task); it is the design intent the enum must serve. Styles are learned through play, never stated
in-game (GDD §8).

- **Drago (Ch1, Wreckhouse C)** — Bulls the start and sits in the middle of the road: heavy, hard
  to pass cleanly, but bleeds whole seconds every time the track turns. The wall that *teaches* you
  a Wreckhouse can't corner — the campaign's gentlest boss, beatable once you commit to the bends.
- **Mercer (Ch2, Mayfly B)** — Detonates off the line and gaps the field early, then fades: flighty
  and brittle, rattled by contact and by her own mistakes. Sit on her and wait — she cracks.
- **Vance (Ch3, Apex A)** — Surgical. Textbook line every lap, brakes impossibly deep, never puts a
  wheel wrong. Doesn't attack you; makes you beat a clean lap you can't *quite* match yet.
- **Kozak (Ch4, Wreckhouse S)** — Immovable. Parks his mass on the racing line and dares you
  through, then rockets out of every corner on raw power. Drago's wall at full size — you pass him
  only once you've mastered everything the campaign taught. The final check.

The arc is deliberate: the first and last bosses share a brand (Wreckhouse), so Ch4 reads as Ch1's
lesson escalated — the bruiser you learned to out-corner, now with an S-class engine and no
mistakes to punish.

## Out of scope

- **Chapter structure** (which classes each chapter mixes, non-boss race lists) — `content-rivals-campaign`.
- **The 9 regular drivers per chapter** — `content-rivals-roster`.
- **The behaviour enum + AI** that realises the driving intents — `code-ai-boss`, `code-ai-difficulty`.
- **A `RivalDef` resource** to load this from — a code task; this doc is the authored source it will mirror.
- **Region/aesthetic theming** of each chapter — `art-world-regions`.

## Notes

- Full names authored though the HUD shows only the surname: the boss-intro screen has room for the
  whole name, and it costs nothing to author now.
- Kozak takes **#1** on purpose — the reigning number the final boss is defending; Vance's **#7**
  reads as precision. Drago **#66** and Mercer **#23** are simply memorable and distinct.
