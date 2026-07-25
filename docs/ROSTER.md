# Rosters — the nine drivers per chapter

Source material and rules for the chapter driver rosters (`content-rivals-roster`). Each chapter
fields **9 regular drivers** (the boss is separate — [RIVALS.md](RIVALS.md)); the field for any one
race is drawn from them per [specs/field-matching.md](specs/field-matching.md).

**These drivers are GENERATED, not hand-authored.** The field-matching spec fixes them as "generated
once per save and persisted" — so this doc defines the *inputs* a generator composes (name pools,
number pool, brand rule), not 36 specific people. A worked example is included to show the shape.

## Reserved numbers

Racing numbers are 1–100 and **campaign-unique** (never reused between chapters). Five are reserved
and the generator must never draw them:

| Number | Holder |
|--------|--------|
| **99** | the **player** |
| **66** | Drago (Ch1 boss) |
| **23** | Mercer (Ch2 boss) |
| **7**  | Vance (Ch3 boss) |
| **1**  | Kozak (Ch4 boss) |

That leaves a pool of **95** numbers for the 36 regulars (4 chapters × 9) — comfortably more than
enough for unique plates campaign-wide.

## Per-driver generation

Each of the 9 per chapter is `{name, number, brand, behaviour}`:

- **name** — a first name + a surname, drawn from the pools below. The **surname is the HUD name**
  (the leaderboard only fits one word), matching the bosses (DRAGO, MERCER…). The full name is for
  any place with room (results, a future car card). Never draw a boss surname (Drago / Mercer /
  Vance / Kozak) or repeat a name within the campaign.
- **number** — unique from the 95-number pool, campaign-wide.
- **brand** — **exactly 3 Apex · 3 Wreckhouse · 3 Mayfly per chapter** (the 3/3/3 split the spec
  requires), so every brand is represented and the `(brand, class)→car` lookup always has a car.
- **behaviour** — a tag from the AI behaviour set. **That set is defined by the AI work, not here**
  (the field-matching spec is explicit: "defining the set and implementing it is a separate task").
  Each driver carries one; which tags exist is `code-ai-difficulty`'s call. Left as a field for now.

**Determinism:** the generator is seeded from the save so the same save always rebuilds the same 36
drivers (spec acceptance). Generation happens once and is persisted; it is not re-rolled per race.

## Name pools

Swappable wordlists — international, terse, and picked so the surnames read cleanly in all-caps on
the HUD. Grow or replace freely; the generator only needs "enough for 36 unique combos" (there are
hundreds here).

**First names:**
Ari, Bex, Cato, Dima, Enzo, Faye, Gio, Hana, Juno, Kai, Lena, Milo, Nadia, Oskar, Pia, Quinn, Raf,
Sana, Tomas, Ulla, Vince, Wren, Xan, Yara, Zeke, Bo, Del, Esa, Freya, Goran, Ines, Jax, Kira, Lev,
Mika, Noor, Otto, Petra, Remy, Suvi, Tavi, Vesa

**Surnames** (HUD names — avoid the boss surnames):
Astor, Bosch, Cray, Dunne, Ebert, Falk, Grim, Holt, Ilves, Juvela, Kade, Lund, Mott, Novak, Oksa,
Pryce, Quist, Roos, Salo, Thorne, Udin, Vint, Wade, Yost, Zane, Brandt, Corso, Dax, Enko, Frey,
Groves, Haas, Ingram, Joos, Krall, Lenz, Marsh, Niko, Osei, Park, Reyes, Sandu, Tersk, Voss, Weir

## Worked example — a Chapter 1 roster

Illustrative output only (real rosters are per-save). Ch1 mix is C+D; the 9 fill 3/3/3 brands, none
using a reserved number, none named like a boss:

| # | Name | HUD | Brand |
|---|------|-----|-------|
| 14 | Kai Thorne | THORNE | Apex |
| 31 | Petra Falk | FALK | Apex |
| 58 | Milo Roos | ROOS | Apex |
| 9  | Bex Grim | GRIM | Wreckhouse |
| 47 | Goran Haas | HAAS | Wreckhouse |
| 72 | Del Krall | KRALL | Wreckhouse |
| 3  | Sana Niko | NIKO | Mayfly |
| 26 | Raf Dax | DAX | Mayfly |
| 88 | Yara Vint | VINT | Mayfly |

(Class per race is drawn from the chapter band at race time, not fixed to the driver — the same
Thorne runs a C-class Tangent in a C-race and a D-class Kerb in a D-race. The car is always
`(brand, race-class)`.)

## Out of scope

- **The behaviour set + AI** that gives the tags meaning — `code-ai-difficulty`, `code-ai-rival`.
- **The generator + persistence** (a `RivalDef` / save field) — code; this doc is its source.
- **Per-driver liveries / paint / car numbers on the mesh** — later art.
- **Which drivers enter a given race** — drawn at race time (`code-race-field`).

## Notes

- **Player is #99.** Reserving it means the plate can be the player's on the car and in any numbered
  UI without ever colliding with a rival. Added to the boss reservations in RIVALS.md.
- Boss brands are **not** counted in a chapter's 3/3/3 — the boss is a separate 10th driver who only
  appears in the duel, so the nine regulars always split 3/3/3 on their own.
