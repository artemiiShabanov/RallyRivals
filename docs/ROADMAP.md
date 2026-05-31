# Roadmap

> Milestones gated by checkpoints. Each milestone = a thing you can play.

## Checkpoint gate 🚧

No milestone is "passed" until its **fun verdict** is logged. A checkpoint is reached
only when:

1. Its task boxes are checked.
2. The build is played and read through the [Fun Checklist](FUN_CHECKLIST.md) lenses
   (feel / flow / decisions).
3. A **fun verdict** ("was it fun? why/why not?") is written in [PLAYTESTS.md](PLAYTESTS.md).
4. If the verdict is "not fun" → don't advance. Iterate or cut, then re-test.

This is the one place fun validation is mandatory — at the playable boundary, where
there's actually something to judge. Individual specs don't carry this burden.

## M0 — Foundation ✅ (in progress)
Project structure, input map, docs scaffold.

## M1 — Feel ("one good car")
_Single car that's fun to drive on a gray-box track. No content._
- [ ] Vehicle controller
- [ ] Test track
- [ ] Camera
- **Checkpoint:** driving feels good (subjective gut check).

## M2 — Race ("one rival")
- [ ] 1 AI rival on a spline
- [ ] Lap/stage timing + win/lose
- [ ] Basic HUD
- **Checkpoint:** a full race start→finish.

## M3 — Content ("a real track")
- [ ] CC0 car + track art integrated
- [ ] Audio (engine, SFX)
- [ ] Menus, settings, save
- [ ] Export presets + exclude `prototypes/*` from release builds
- **Checkpoint:** vertical slice — shippable-quality single race.

## M4 — Game ("the loop")
- [ ] Multiple tracks/cars, progression
- [ ] Polish, juice, options
- **Checkpoint:** content-complete beta.

## M5 — Ship
- [ ] Store page, exports, launch checklist
- **Checkpoint:** release.
