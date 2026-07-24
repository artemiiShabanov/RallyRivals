# Spec — Field matching for open (non-GP) races

- **Status:** draft
- **Date:** 2026-07-24
- **Task:** `design-spec-field-matching`

## Intent
Every open race fields a grid drawn from the chapter's own cast of drivers, sized to the race
type and spread across a class band the race itself authors — so the difficulty of a race is a
property of the *race*, and the car you bring is your own lever on it.

## Serves
GDD §5 (race structure), §6 (AI rivals), §8 (classes: only Grand Prix is class-gated). Pillar 3
— *Old-School Campaign*: buying a better car is a real, felt reward, and no race is ever locked.

## Model

### 1. The field is anchored to the RACE, not to your car
A race authors a **class band** (`class_low`..`class_high`, e.g. `D–A`). Rivals are drawn inside
that band. Your own car has **no** influence on it.

This is the deliberate consequence: **bringing a stronger car than the band buys you an easier
race, up to a walkover.** That is the payoff for having earned the car — the shop must mean
something, and the arcade lineage (NFS) treats out-classing an event as a legitimate reward
rather than a bug.

It is equally deliberate that **the field never drops to meet an underpowered car.** Bring a D
into a `B–S` race and you will lose. You are not blocked from entering and you still earn (the
banked-best economy pays every finish), but the game is honest that you brought the wrong tool.

> **Not rubber-banding.** All of this resolves *before the lights*. Nothing about a rival's car
> or pace changes in response to how you are doing mid-race — that stays forbidden (GDD §4).

### 2. Leniency comes from the BAND, not from scaling
A hard floor would be a frustration wall (anti-pillar) if a race were a single class. It is not:
the band's **bottom** is always reachable, so an underpowered car always has someone in the pack
to actually race, even while the front runs away. Authoring guidance:

- A band should span **at least two classes**, and should include a class the player can
  plausibly own at that point in the chapter.
- A band should not exceed **three classes** — beyond that the race splits into two unrelated
  races happening at once.

### 3. Chapter driver roster
Each chapter owns **9 drivers**, generated once per save and persisted:

| Field | Rule |
|---|---|
| `name` | generated |
| `number` | 1–100, **unique across the whole campaign** (never reused between chapters) |
| `brand` | one of apex / wreck / mayfly — split **3/3/3** so every brand is represented |
| `behaviour` | one of a fixed set; **defining the set and implementing it is a separate task** |

These 9 are the chapter's cast. They are **identities, not characters** — a name, a number, a
brand and a driving manner. No dialogue, taunts or story: v1 narrative stays deferred (GDD §6).

The **chapter boss is a separate 10th driver**, not one of the 9. The boss appears *only* in the
boss race, so their arrival is an event rather than a familiar face.

### 4. Per-race field
```
field_size  =  sprint 4  ·  circuit 6  ·  endurance 8  ·  time_trial 0
entrants    =  random N of the chapter's 9, drawn fresh each race
class(each) =  uniform random within the race's band
car(each)   =  lookup(driver.brand, assigned_class)
```

The roster is a perfect 3 brands × 5 classes grid, so `(brand, class)` resolves to **exactly one
car** — no ambiguity, no fallback needed.

**Rivals may drive `pink_slip_only` cars.** That flag bars the *shop*, not the AI. Seeing a
rival in a car you cannot buy is aspirational: you are looking at a prize before you have won it.

**Time trial fields no rivals at all** — it is you against the clock by definition (GDD §5).

### 5. Boss race
The boss race is the chapter's finale and ignores the per-type field size: **all 9 regulars + the
boss + the player = 11 cars.** The boss runs their signature `pink_slip_only` car at the
chapter's top class — the car the win pink-slips.

## Acceptance criteria
- [ ] A race authors a class band; the field is drawn from it and is unaffected by the player's car.
- [ ] Entering with a car above the band is allowed and produces an easy race; nothing scales up.
- [ ] Entering with a car below the band is allowed, is not blocked, and still pays out.
- [ ] Field size is 4 / 6 / 8 by type; time trial fields no rivals.
- [ ] Each chapter generates 9 drivers with unique campaign-wide numbers and a 3/3/3 brand split.
- [ ] The same save always regenerates the same roster (generated once, persisted).
- [ ] A rival's car is exactly `lookup(brand, assigned_class)`, pink-slip cars included.
- [ ] The boss is not among the 9 and appears only in the boss race, which fields 11 cars.
- [ ] No rival's car or pace changes in response to the player's position mid-race.

## Feel criteria
- [ ] Winning a car you could not afford last chapter visibly *changes* what races feel like.
- [ ] Out-classing an event feels earned and a little indulgent — not like the game broke.
- [ ] Under-classing an event feels like your own choice, never like the game locked a door.
- [ ] Even at the back of a wide band, there is always someone to scrap with.
- [ ] Rival names and numbers become familiar over a chapter, without any dialogue.

## Out of scope
- **Behaviour definitions and AI implementation** — this spec only reserves the field
  (`code-ai-rival`, `code-ai-difficulty`, `code-ai-boss`).
- **Grand Prix**, which stays class-gated with a qualifying-set grid (`code-race-grandprix`).
- Name generation wordlists.
- Per-driver liveries and paint.
- Any standings or championship table across a chapter — the roster is a cast, not a season.

## Notes
- **This amends the GDD.** §8 previously read *"field matched to your car"*; the field is now
  anchored to the race's band and explicitly ignores the player's car. §8's *"Open:
  field-matching/scaling rule for open races"* and §6's *"Open: rival count"* are both closed by
  this spec.
- **Consequence for the HUD:** the race leaderboard was built for 10 rows (9 + player). The boss
  race needs **11**.
- **Open — random selection has no memory.** Entrants are drawn fresh per race, so a rival you
  beat may be absent next time and there is no running pecking order. This was chosen for
  simplicity; if a chapter ends up feeling like interchangeable strangers, the smallest fix is to
  bias the draw toward drivers the player has recently raced.
- **Open — band authoring is unvalidated.** The two/three-class guidance above is a starting
  guess and wants a playtest (`design-playtest-race`) before the campaign track set is authored.
