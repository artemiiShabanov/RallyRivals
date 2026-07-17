# Car roster (v1)

> Canonical roster per GDD §8. 15 cars: 3 brands x classes S/A/B/C/D. Stats are the five
> 1-10 bars — **Speed / Accel / Steering / Braking / Grip** — fixed per car, no tuning.
> Defined by content-cars-roster; wired to handling by code-vehicle-stats; tuned by
> balance-handling-classes.

## The system

- **Class budgets (sum of 5 bars):** D=22 · C=26 · B=30 · A=34 · S=38. Linear steps —
  one class up is a readable, similar-size jump.
- **Brand skew (budget-neutral, +/-1):** brands whisper, classes shout — identity is felt
  before it's read.
  - Apex Cartel: +1 steering, +1 braking, -1 speed, -1 accel
  - Wreckhouse: +1 speed, +1 grip, -1 steering, -1 braking
  - Mayfly Speedworks: +1 accel, +1 steering, -1 braking, -1 grip
- **Pink-slip cars (4, one per boss) are spiky**: same class budget, deliberately off-meta
  spread. Never sold in the shop. Each duel's weakness is the lesson; the win hands you the
  weapon.
- Shop stock = the other 11. Every class keeps >=2 buyable cars (GP class-gating never
  strands you). Starter: the Apex **Kerb**, gifted (the father's old project build).

## Roster (Speed / Accel / Steering / Braking / Grip)

| class | car | brand | stats | notes |
|-------|-----|-------|-------|-------|
| D | **Kerb** | Apex | 3/3/6/5/5 | STARTER — most forgiving D; teaches clean lines |
| D | **Mule** | Wreckhouse | 5/4/4/3/6 | planted workhorse |
| D | **Spark** | Mayfly | 4/5/6/3/4 | darty, slippy |
| C | **Tangent** | Apex | 4/4/6/6/6 | the clean-line pick |
| C | **Crowbar** | Wreckhouse | 8/5/3/4/6 | **Ch1 BOSS, pink-slip** — C-class freight train; beat it in corners |
| C | **Fuse** | Mayfly | 5/6/6/4/5 | eager, light |
| B | **Meridian** | Apex | 5/5/7/7/6 | scalpel-in-training |
| B | **Anvil** | Wreckhouse | 7/6/5/5/7 | straight-line bully |
| B | **Strobe** | Mayfly | 7/9/6/3/5 | **Ch2 BOSS, pink-slip** — all launch, no brakes |
| A | **Verdict** | Apex | 5/3/9/8/9 | **Ch3 BOSS, pink-slip** — rails in corners, crawls out of hairpins |
| A | **Sledge** | Wreckhouse | 8/7/6/5/8 | heavyweight contender |
| A | **Comet** | Mayfly | 7/8/8/5/6 | the flowing fast lap |
| S | **Stiletto** | Apex | 7/7/9/8/7 | the precision endgame |
| S | **Juggernaut** | Wreckhouse | 10/8/4/8/8 | **Ch4 BOSS: the garage-wrecker, pink-slip** — owns every straight; steering 4 is the designed weakness — beat him where the road bends |
| S | **Nova** | Mayfly | 8/9/9/6/6 | lives fast |

## Rules for future cars

Pick class budget -> apply brand skew to the balanced baseline -> adjust +/-1 swaps that keep
the sum. Spiky spreads are reserved for pink-slips. New brands/classes change this doc first.
