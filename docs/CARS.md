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

## Voxel art references (art-voxel-car-*)

Every car is modelled **reference-first** from a real rally car (never free-handed) — pick the reference,
fill the Car Spec Sheet from its real dimensions, then model to spec. Chosen per CAR, not per brand. The
reference must match the car's **stat archetype**, not just its tier: Verdict is 5/3/9/8/9 ("rails in
corners, crawls out of hairpins"), so it gets the nimble low-power Stratos — not a Group B rocket.

Every model is scaled so its **wheelbase = 2.8 m** (the fixed rig), so in-game lengths differ from real
life: short-wheelbase cars (Stratos 2.18 m, RS200 2.53 m) scale up and lose some real-world stubbiness.
Ratios stay internally honest.

| class | car | reference | why |
|-------|-----|-----------|-----|
| D | **Kerb** | Lancia Delta HF Integrale Evoluzione (3900×1770×1365, WB 2480) | forgiving Group A hatch — DONE |
| C | **Tangent** | Subaru Impreza WRX STi GC8 **4-door sedan** (4340×1690×1405, WB 2520) | notchback trunk breaks the silhouette vs the Delta hatch |
| B | **Meridian** | Audi Ur-Quattro (**not** the Sport S1) | boxy coupe + blistered arches = "scalpel-in-training"; S1's aero would out-drama the A car |
| A | **Verdict** | Lancia Stratos HF | light, nimble, modest power — matches "rails in corners, crawls out of hairpins" |
| S | **Stiletto** | Ford RS200 | purpose-built 4WD balance = "the precision endgame" |

**Apex Cartel — all five DONE** (2026-08-06). Precision/tarmac family: every one a homologation rally car.

### Wreckhouse (locked 2026-08-06)

Brand skew +1 speed / +1 grip / −1 steering / −1 braking, so every reference is heavy, blunt and
straight-line-fast. Where Apex is the tarmac-precision family, Wreckhouse is the **brute/off-road**
family — three of the five are off-roaders, which is the brand identity, not an accident.

| class | car | stats | reference | why |
|-------|-----|-------|-----------|-----|
| D | **Mule** | 5/4/4/3/6 | Lada Niva | "planted workhorse" is literal — best D grip, worst D steering/braking. Tall boxy 4×4, and genuinely rally-bred (there was a Group B Niva) |
| C | **Crowbar** | 8/5/3/4/6 | Volvo 240 Turbo | *the flying brick*. Steering **3** is the lowest number in the roster and this boss's designed weakness — a long heavy 3-box saloon sells that on sight |
| B | **Anvil** | 7/6/5/5/7 | Mitsubishi Pajero Evolution | seven straight Dakar wins and ~1900 kg of it. Colossal blistered arches, wide and squat; nose-heavy 4WD understeer is steering 5 honestly |
| A | **Sledge** | 8/7/6/5/8 | Mercedes-Benz 500 SLC | "heavyweight contender" — and not a stretch, it won the 1979 Bandama. A vast low coupe, unlike anything else in the game |
| S | **Juggernaut** | 10/8/4/8/8 | Baja pickup (Ford F-150 trophy-style) | the literal garage-wrecker. Nothing else in the roster is a pickup, so it reads instantly; scaling a 3.7 m wheelbase onto our fixed 2.8 m rig makes the wheels read proportionally huge — exactly the Baja look |

**Silhouette separation to hold onto while modelling:** Mule is *narrow and tall* (agricultural),
Anvil is *wide and squat* (aero-flared). They are both boxy 4×4s and will blur into each other if
that contrast is not deliberate. Juggernaut's pickup bed is its own separator.

### Mayfly Speedworks (locked 2026-08-08)

Brand skew +1 accel / +1 steering / −1 braking / −1 grip: every reference is light, high-revving and
slightly nervous — the opposite of Wreckhouse's mass. Apex is the tarmac-precision family, Wreckhouse
the brute/off-road family, Mayfly the **lightweight/nervous** family.

**Wheelbase is a selection criterion here, not just a spec value.** It decides how badly a reference
distorts on the fixed 2.80 m rig, and Mayfly's natural candidates are the worst offenders: a classic
Mini (WB 2036) scales ×1.375 into a 4.2 m long, 1.85 m tall box — a Niva — and an Alpine A110
(WB 2100) stretches to 5.1 m. Both stop being small cars, which was the whole reason to pick them.
Every reference below sits in the 2.2–2.45 m band where inflation stays mild.

| class | car | stats | reference | why |
|-------|-----|-------|-----------|-----|
| D | **Spark** | 4/5/6/3/4 | Peugeot 205 GTI (WB 2420) | 850 kg, front-drive, famous snap lift-off oversteer — "darty, slippy" is this car's reputation. Worst braking and grip in the class |
| C | **Fuse** | 5/6/6/4/5 | Toyota AE86 (WB 2400) | "eager, light" — high-revving RWD coupe with pop-up lamps. Shares `popup_lights` with the Nova (the F40 has them too), but the faces do not collide: a tall upright coupe against a wedge with a radiator outlet through the bonnet |
| B | **Strobe** | 7/9/6/3/5 | Porsche 911 Turbo (930) (WB 2272) | Ch2 boss. The widowmaker: vast turbo lag then explosive boost, brakes that never matched the engine — "all launch, no brakes" is its folklore. Whale tail over a rear-engine fastback |
| A | **Comet** | 7/8/8/5/6 | Lotus Elise S1 (WB 2300) | 725 kg and the definition of "the flowing fast lap"; the only genuinely rounded, organic body in a roster of boxes and wedges |
| S | **Nova** | 8/9/9/6/6 | Ferrari F40 (WB 2450) | "lives fast". 1100 kg — the lightest extreme supercar, which is Mayfly's identity. Huge rear wing, NACA ducts, slatted engine cover: reads as extreme even at 33 mm voxels |

**Silhouette watch-outs while modelling:**
- The 205 is a hatch like the Delta and the AE86 a 2-door coupe like the Ur-Quattro. They separate on
  size and detail rather than silhouette class — keep the 205 small and rounded against the Delta's
  boxy widebody, and the AE86 a low notchback with pop-ups against the Quattro's upright blisters.
- Elise (A) and F40 (S) are both low mid-engines. Keep the Elise small, rounded and organic; the F40
  angular, wide and winged.
- The 930's overhangs must be held at their REAL absolute lengths (the Mule/Niva rule) or its 2272 mm
  wheelbase inflates it to 5.29 m — longer than the Crowbar, which no 911 should ever be.

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
