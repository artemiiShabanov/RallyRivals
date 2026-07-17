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

## Bars -> handling (code-vehicle-stats)

Each bar lerps between a bar-1 and bar-10 endpoint (one table in `vehicle_controller.gd` —
`balance-handling-classes` tunes ENDPOINTS, never cars). Bar ~5 == the original hand-tuned
feel. Forces are mass-compensated, so bars mean the same in every car.

| bar | drives | bar 1 -> 10 |
|-----|--------|-------------|
| Speed | top speed (engine tapers as 1-(v/max)^4) | 110 -> 210 km/h |
| Accel | engine force (at 800 kg ref, mass-scaled) | 1600 -> 3600 N |
| Steering | lock angle / response / yaw-rate cap | 0.45->0.78 rad · 2.8->6.5 · 1.05->1.65 rad/s |
| Braking | brake force (mass-scaled) | 24 -> 62 |
| Grip | multiplier on SURFACE grip (stays situational) | x0.80 -> x1.22 |

The grip-falloff curve spans each car's own envelope (starts at 20% of its top speed, fades
over 30%).

## Brand physique (hidden traits, not bars)

| brand | mass | damage_sensitivity |
|-------|------|--------------------|
| Apex Cartel | 800 kg | 1.0 |
| Wreckhouse | 950 kg | 0.8 |
| Mayfly Speedworks | 680 kg | 1.25 |

Mass = contact/momentum identity (suspension + forces auto-scale with it); damage_sensitivity
multiplies performance-damage effects when code-vehicle-damage lands. CarDef .tres files in
`assets/cars/` are generated from this doc by `scripts/tools/gen_car_defs.gd`.

## Rules for future cars

Pick class budget -> apply brand skew to the balanced baseline -> adjust +/-1 swaps that keep
the sum. Spiky spreads are reserved for pink-slips. New brands/classes change this doc first.
