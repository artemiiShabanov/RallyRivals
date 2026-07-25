# Campaign — the four-chapter structure

Authoritative shape of v1's campaign (`content-rivals-campaign`): the four chapters, what each is
made of, and how you get through it. Bosses are defined in [RIVALS.md](RIVALS.md); field rules in
[specs/field-matching.md](specs/field-matching.md); the loop in GDD §5/§8.

This fixes **structure**, not numbers. Exact CP/money pools, the precise gate %, and per-race
tuning are `balance-economy-tables` and `balance-difficulty-pacing`.

## The four chapters

| Ch | Region | Class mix | Boss (finale) | Boss car |
|----|--------|-----------|---------------|----------|
| 1 | R1 | **C + D** | Marek Drago (Wreckhouse, C) | Crowbar |
| 2 | R2 | **D + B** | Rae Mercer (Mayfly, B) | Strobe |
| 3 | R3 | **D + A** | Ivo Vance (Apex, A) | Verdict |
| 4 | R4 | **A + S** | Boris Kozak (Wreckhouse, S) | Juggernaut |

Chapter = region, 1:1 (GDD §3). The class mix widens as you climb; D persists through Ch1–3 as the
budget/variety tier (GDD §6/§8). Region identity/theming (look + off-road surface + dressing) is
`art-world-regions`, not this doc — regions are referenced here by number only.

## What a chapter contains

**8 CP-earning races + 1 boss duel.** The 8 pay money + CP; the duel is the finale, gated behind
them.

**Per-chapter race template (full menu, exactly 2 grand prix):**

| Count | Type | Notes |
|-------|------|-------|
| 2 | grand prix | class-gated — one to each class of the chapter mix (see below) |
| 2 | circuit | multi-lap |
| 2 | sprint | point-to-point |
| 1 | time trial | solo vs the medal clock (no field) |
| 1 | endurance | attrition, the largest field (8 rivals) |

That's the authoring **default**; a chapter may rebalance the 6 non-GP slots as long as it keeps 8
races total, exactly 2 GP, at least one of every type, and a culture mix (below). All five race
types therefore appear in every chapter.

### Class bands & the two grand prix
- **Open races** (everything except GP) author a **class band = the chapter's own two classes**
  (Ch1 → C–D, Ch4 → A–S), drawn from the 9-driver roster per the field-matching spec. The band's
  bottom is always the class you can most plausibly own, so the chapter is never a wall.
- **The 2 grand prix are class-gated**, one to **each** class of the mix — e.g. Ch1 runs a **D** GP
  and a **C** GP. GP is the only class-gated type (GDD §8); splitting the two across the mix's
  classes gives the low tier a reason to keep a car (a D GP exists in Ch1–3) and makes the gate
  bite without locking the whole chapter.

### Cultures
Each chapter **mixes Officials and Wilds**, roughly half and half across its 8 races (GDD §5). No
chapter is all-clean or all-contact. Which races are which is author's discretion.

## The boss duel

**A 1-on-1 sprint: just you versus the boss, point-to-point.** No pack — the finale is a personal
grudge race (Pillar 3), not another field. This *replaces* the earlier "11-car boss race" idea.

- **Unlocked** when you've banked ≈70% of the chapter's CP (GDD §5 two-step gate; exact % is
  `balance-difficulty-pacing`). The ~30% slack lets you skip races you dislike or lose.
- **The boss** drives their signature `pink_slip_only` car at the chapter's top class (Kozak in the
  S-class Juggernaut, etc.). **Not class-gated** — you bring what you own — but the boss is
  top-class, so a competitive car is the real prerequisite. That is exactly what the money→garage
  loop is *for*: the duel is the payoff for having built a car that can run at the top of the mix.
- **Winning** advances to the next region **and** pink-slips the boss's car (GDD §8). Losing costs
  nothing but the retry — lenient, never hard-walled.
- **AI never rams the player**, even in a Wilds duel (GDD §6). The boss's pressure is positional.

## Track reuse (why 32 races is not 32 tracks)

Races **reuse baked tracks** two ways, so the race count is cheap in track-authoring terms:
- **Across regions** — the same track appears in different chapters under different region modifiers
  (off-road surface + dressing swap), reading as a new place.
- **Across race types** — one baked track hosts a circuit *and* a sprint *and* a time trial; the
  spline already carries lap/checkpoint/finish order for all of them.

So `content-tracks-campaign` authors a **small pool of tracks**, not one per race. The exact pool
size and the reuse map are that task's job; this doc only establishes that reuse is the plan.

## Out of scope

- **The 9 regular drivers per chapter** (names, numbers, brands, behaviour) — `content-rivals-roster`.
- **CP/money pool values, the exact gate %, per-race tuning** — `balance-economy-tables`,
  `balance-difficulty-pacing`.
- **The actual tracks and the reuse map** — `content-tracks-first`, `content-tracks-campaign`.
- **Region look / off-road surface / dressing** — `art-world-regions`.
- **The gate + advance machinery** — `code-meta-chapters`; **field assembly** — `code-race-field`.

## Amends

- **field-matching spec**: the boss race is no longer 11 cars — it is a **1v1 sprint duel**
  (player + boss = 2). §5 and its acceptance criterion updated.
- **GDD §6**: "the boss race fields all 11" → the boss race is a 1v1 sprint duel.
- **HUD**: the leaderboard's largest field is now **endurance (8 rivals + player = 9)**, so
  `MAX_ROWS` drops 11 → 9.
