# RallyRivals — Game Design Document

> Canonical, decided design. Undecided ideas live in IDEAS.md until settled, then move
> here. Open sub-questions marked **Open:** inline.

## 1. High concept
Arcade 3D rally racer, voxel world, old-school boss-to-boss revenge campaign vs AI rivals.
You climb a traveling outlaw racing festival — region to region, beating each local champion
and winning their car — to reach the man who wrecked your father's garage.

## 2. Pillars
See [PILLARS.md](PILLARS.md). In short:
1. **Glance to Read, Grind to Master** — arcade clarity over hidden depth.
2. **Arcade Rally Flow** — feel-first + performance-first driving on shifting terrain.
3. **Old-School Campaign** — NFS:MW-style boss climb with a personal grudge.

## 3. Core loop
- **Moment-to-moment:** drive shifting surfaces, draft rivals, manage damage, hit jumps,
  hold the line.
- **Race:** enter an Officials or Wilds race (varied types) → place (no win required) →
  earn **money** + **campaign points (CP)**.
- **Meta:** spend money in the always-open car shop; earn achievement paint skins (§8);
  bank CP toward the chapter boss.
- **Chapter (= 1 region):** at ≈70% chapter CP the **boss race** unlocks → beat the boss →
  **pink-slip their car** → next region.

## 4. Vehicle & controls
- **Handling:** arcade, feel-first — buttery, weighty, responsive; never hitches.
- **Stats:** five legible bars — **speed, acceleration, steering, braking, grip**. **Fixed
  per car; no tuning, no upgrades.** Balance lives in roster design.
- **Slipstream (must-have):** drafting gives a speed boost — organic, skill-based catch-up,
  no rubber-banding. **Player-only:** AI *provides* draft (tuck behind to close a gap) but
  never uses it itself — asymmetry favors the player. **Feedback:** speed-line/wind FX +
  whoosh cue + subtle HUD glow while drafting (readable, per clarity pillar).
- **Damage:** **visible** (cheap material/prop/particle swaps — likely voxel chipping) +
  **performance** (mild but punishing: steering pull / reduced speed). **Resets every
  race** — pristine start, no repair economy. Pure in-race pressure.
- **Airborne:** controller handles jumps (ramps/gaps/crests).
- **Inputs:** keyboard + gamepad — see [README](../README.md#input-actions).
- **Physics (Decided — ADR-001):** `VehicleBody3D` + a thin custom handling layer: per-wheel
  surface grip via `wheel_friction_slip` (surface `PhysicsMaterial` is ignored by the wheel
  solver), front/rear grip split + handbrake rear-grip cut for drift. Godot Physics, not Jolt.

## 5. Race structure
- **Types:** time trial (vs clock), circuit (laps), sprint (point-to-point), endurance
  (attrition), grand prix (qualifying sets grid + race).
- **Two cultures:** **Officials** — clean, contact → time penalty; **Wilds** — ramming is
  valid. Both always available, mixed every chapter.
- **Checkpoint gates (anti-shortcut):** ordered gates along the spline must be passed in
  sequence — a lap/stage only counts if all gates are hit, so cutting the track is invalid.
- **Lenient progression:** no 1st-place requirement; every race pays out; replay optional.
  Most races skippable — so each must be fun enough to play voluntarily.
- **Rewards economy (banked-best, top-up):** each race has a fixed **money pool** and **CP
  pool**, split across places (1st > 2nd > 3rd …; even a poor finish earns the bottom slice).
  The game **banks your best-ever finish** per race:
  - **Improving** pays the **remaining** reward — tops you up from your old place to the new.
  - **Matching or below** your best pays only **10%** (small farm trickle).
  - Reaching 1st collects the whole pool — no double-dipping.
  - *Example (1st=10, 2nd=8, 3rd=3):* first run 2nd = **+8**; replay 2nd = **+0.8**; improve
    to 1st = **+2** (tops the banked 8 to 10).
  - Identical for money and CP. Rewards chasing better results, not grinding the same finish.
- **Chapter gating (two-step):** (1) **CP** unlock the **boss race** at ≈70% chapter total
  (~30% slack = escape valve for disliked/lost races); (2) **beating the boss** unlocks the
  **next chapter/region** + pink-slips the boss's car. CP get you *to* the boss; only the
  win advances the story. CP gate nothing else.

## 6. AI rivals
- **Antagonists:** named, characterful rivals climbed one by one; each chapter ends in a
  boss duel. Personality, signature ride, taunts — the hook to want the next win.
- **Brand identity:** each rival reps a manufacturer and drives the car you pink-slip.
- **Behavior (player-favoring asymmetry):** slipstream and damage are **player-side tools**.
  AI *provides* draft but never uses it; AI *takes* damage (your hits or its own crashes)
  but never deliberately rams/wrecks the player — even in Wilds, aggression is *yours*.
- **Difficulty:** scales via opponents + track complexity — **never** nastier weather.
- **v1 campaign = 4 chapters**, each a **mix of two classes** (races draw from both),
  widening as you climb:
  - Ch1 **C+D** · Ch2 **D+B** · Ch3 **D+A** · Ch4 **A+S**. Boss sits at the chapter's top
    class (C → B → A → **S** = garage-wrecker). Low tiers (esp. D) persist for variety +
    budget options. 4 boss-rivals total.
  - **Open:** rival count if non-boss rivals are added.

## 7. Tracks & environments
- **Generation (Decided — ADR-002):** tracks = **spline (race) + images (world)**, baked
  offline into a static scene. Three authored images — float heightmap (terrain), surface
  splat (road placement + surface/grip), markers (start, props) — feed a bake tool that
  outputs ground mesh + `HeightMapShape3D` collision, per-surface visuals, props, and a
  hand-tunable `TrackPath` (`Path3D`, auto-extracted from the road image). The road is
  carved into the terrain (part of the ground, never a floating ribbon); grip is
  position-sampled from the splat. The spline owns *order*: laps, checkpoints, AI line.
  Jumps are painted into the heightmap (ramps/crests). **Open:** a *fun, readable* racing
  line; LOD/perf; Terrain3D eval; procedural vs hand-tuned balance.
- **Verticality + jumps:** required.
- **Surfaces (mixable within one race):** asphalt, dirt, snow, sand, gravel, ice — each with
  **readable** grip effects; makes the grip stat and brand styles situational; reinforces
  rally identity. Impl (ADR-001): `SurfaceType` resources → per-wheel `wheel_friction_slip`
  (physics materials don't affect wheels) + per-surface particle/audio. **Decided:** instant
  grip only — surface sets grip while you're on it,
  **no lingering state** (clean, readable, cheap; fits clarity + performance pillars).
- **Seasons (visual only):** 4 seasons swap models/FX, no gameplay effect (decoupled from
  grip). **Decided:** **author-picked per race** — coherent aesthetics, and you only build
  the seasonal sets a track uses (caps the 4× dressing cost).
- **Time + weather (combinable, fixed per race):** time → visibility/aesthetics
  (morning/day/golden hour/night); weather → grip, stacks on surface
  (clear/rain·snow/thunder/fog). Keep combined grip readable. ⚠️ Low-visibility must stay
  fair (telegraph corners). Does **not** escalate for boss/late races — variety, not
  difficulty.
- **Regions:** ⚠️ a region is an **aesthetic/cultural theme, not a surface biome** — every
  region still mixes surfaces per race. Travel changes the *look*, not the surface set.

## 8. Progression & meta
- **Two currencies, no overlap:** **money → garage** (what you drive), **CP → story** (how
  far you advance).
- **Pink-slip unlocks:** beat a rival → win their (brand's) car. Story progress = garage
  growth. Each rival's car must be desirable + distinct.
- **Achievements → paint skins (cosmetic only):** achievements unlock **paint skins** —
  purely visual, **never** stats/class, off the money/CP economies. A light collect-loop.
- **Car shop:** always open, gated by **price**; parallel to pink-slips. ⚠️ Keep pink-slip
  cars special vs buyable. **Decided:** money comes **solely from race payouts** (per-race,
  banked-best money pool) — one clean source, mirroring CP.
- **Classes S/A/B/C/D:** one at-a-glance rank bundling the 5 stats. Shop price ↔ class;
  rivals escalate D/C → S; pink-slips climb it. **Decided:** **only Grand Prix is
  class-gated** (bring a car of the event's class — the "serious" event, tied to the
  chapter's class range); **all other types are open** (run what you brought, field matched
  to your car). **Open:** field-matching/scaling rule for open races.
- **Manufacturers (Decided: 3), implicit identities (Borderlands-style):** each brand leans
  a racing style + shares a visual family; styles **never stated** — learned through play.
  Coverage: ≥1 car per class S–D per brand (≥15 cars). **Decided (v1): no brand features** —
  pure stat/feel personalities; revisit post-v1 (nitro is the canonical candidate).
  - **Apex Cartel** — corner-king: grip/steering/braking high, modest power. Low crisp
    wedges, mono paint + one accent stripe. Ch3 boss (A). Starter car = a D-class Apex,
    the father's old project build.
  - **Wreckhouse** — straight-line bruiser: top speed + heavy chassis, weak
    steering/braking. Slab muscle, bumper bars, scuffed plates. The garage-wrecker's own
    outfit: Ch1 boss (C, junior enforcer) and Ch4 boss (S, the wrecker himself) — the
    first badge you pink-slip and the last.
  - **Mayfly Speedworks** — fast-but-brittle: top acceleration, light, damage hurts it
    more (hooks into the damage system). Cab-forward bodies, big intakes, loud two-tones.
    Ch2 boss (B).

## 9. UI / UX
- **Style:** pixel-art HUD, menus, icons (matches voxel = 3D pixel art).
- **Readability:** five stat bars front-and-center; instant car comparison.
- **Avatars:** static pixel portraits throughout (cheap, everywhere); few-frame animated
  talking-head only for boss-rival intros (spend animation budget where it lands).
- **Career screen:** a region map of selectable races showing CP/boss progress — how you
  navigate a chapter.
- **Pre-race screen:** track/surfaces/season/weather + chosen car & its 5 stat bars before
  the start; a **loading screen** covers async scene load (no hitch into the race).
- **Systems:** settings + input remapping + save (ship requirements).
- **Open:** UI theme — deferred to M3 (menus/settings build).

## 10. Audio
> No audio experience → lean on CC0 libraries + tooling (log in [CREDITS.md](../CREDITS.md)).
- Engine sound; surface SFX (tire pitch; dust on dirt/sand/gravel, snow crunch, ice skitter;
  rain spray when wet); impact/damage SFX.
- **Open:** music direction; engine sound (sampled vs synthesized); sourcing plan.

## 11. Art direction
- **Voxel models + FX, polygon roads (Decided — ADR-003):** cars/props/environment voxel;
  road stays polygon (smooth — voxel roads ruin feel). MagicaVoxel authoring (1 voxel =
  0.1 m), manual `.obj` export, source + artifact both committed. Damage = pre-authored
  voxel damage-state swaps + cube-particle bursts; **all particles are voxel cubes** (never
  billboards). Makes the ~15-car roster + brand families solo-achievable.
- **Pixel art** for 2D/UI/characters (§9).
- **Seam coherence (Decided — ADR-003):** voxel-on-low-poly contrast — terrain/road keep
  smooth geometry but render flat-shaded with solid splat colours; ONE master palette shared
  by voxel models and terrain ties the world together.

## 12. Scope / cut list
- **Cut:** upgrade-card system (contradicted "no upgrades"; nitro parked as the post-v1
  brand-feature candidate — v1 brands are pure stat personalities, §8).
- **v1 scoping (Open):** number of chapters (= regions, 1:1), rivals/tiers, total cars,
  tracks, and how many get full seasonal dressing. Trim to a shippable vertical slice first
  (work tracked in `tasks.yaml` / `STATUS.md`).
