# RallyRivals — Game Design Document

> Canonical, decided design. Undecided ideas live in IDEAS.md until settled, then move
> here. Open sub-questions marked **Open:** inline.

## 1. High concept
Arcade 3D rally racer in a voxel world, presented as a **degraded bootleg VHS of a pirate broadcast**
covering an underground outlaw racing festival. You're an unknown **wildcard** who climbs the
broadcast's card — region to region, race to race — pink-slipping each local champion's car until
you dethrone the reigning outlaw legend at the top.

**Framing (Decided — the pivot).** The whole game is *footage on a tape*, and it's fully diegetic:
- a subtle **VHS post-process** wraps the entire render (grain, mild bleed, occasional tracking
  wobble) — noticeable, but it barely touches the driving;
- all menus/meta are the pirate broadcast's cheap **white-on-blue VCR-OSD** graphics;
- the in-race HUD is a clean **broadcast telemetry scorebug** (kept legible — *not* the blue menu look);
- loading = tracking/rewind/"PLEASE STAND BY", saving = "● REC", the shop is a teleshopping ad
  break, and story is delivered **on-air** (rival interviews, a commentary ticker, title cards).
Nothing breaks the conceit that you found a weird tape. The **mechanical core is unchanged** —
handling, tracks, surfaces, roster, economy all stand; the pivot reshapes the frame, not the drive.

## 2. Pillars
See [PILLARS.md](PILLARS.md). In short:
1. **Glance to Read, Grind to Master** — arcade clarity over hidden depth.
2. **Arcade Rally Flow** — feel-first + performance-first driving on shifting terrain.
3. **Old-School Campaign — On The Tape** — NFS:MW-style boss climb told through the pirate
   broadcast (wildcard → champion).

## 3. Core loop
- **Moment-to-moment:** drive shifting surfaces, draft rivals, manage damage, hit jumps,
  hold the line.
- **Race:** enter an Officials or Wilds race (varied types) → place (no win required) →
  earn **money** + **campaign points (CP)**.
- **Meta:** spend money at the always-open **teleshopping** car shop; earn achievement paint
  skins (§8); bank CP toward the chapter boss.
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
  boss duel. Personality, signature ride, taunts — the hook to want the next win. **Delivered
  on-air** (§9): VHS interview segments, "UP NEXT" bumpers, a commentary chyron that starts
  acknowledging the wildcard as you rise. The S boss is the **reigning champion** who publicly
  dismisses you — the beef is earned on the broadcast, no backstory.
- **Brand identity:** each rival reps a manufacturer and drives the car you pink-slip.
- **Behavior (player-favoring asymmetry):** slipstream and damage are **player-side tools**.
  AI *provides* draft but never uses it; AI *takes* damage (your hits or its own crashes)
  but never deliberately rams/wrecks the player — even in Wilds, aggression is *yours*.
- **Difficulty:** scales via opponents + track complexity — **never** nastier weather.
- **v1 campaign = 4 chapters**, each a **mix of two classes** (races draw from both),
  widening as you climb:
  - Ch1 **C+D** · Ch2 **D+B** · Ch3 **D+A** · Ch4 **A+S**. Boss sits at the chapter's top
    class (C → B → A → **S** = the reigning champion). Low tiers (esp. D) persist for variety +
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
- **Pink-slip unlocks (broadcast title match):** the boss race is a **"PINK SLIP ON THE LINE"**
  stakes match; win → an on-air **"● OWNERSHIP TRANSFERRED"** bumper hands you their (brand's) car.
  Story progress = garage growth. Each rival's car must be desirable + distinct.
- **Garage / car selection (competitor profiles):** your stable and the pick-a-car screen are the
  broadcast's **competitor profile cards** — VCR-navigated, the 5 stat bars shown as a broadcast
  stat-line, never a gamey garage menu.
- **Achievements → paint skins (cosmetic only):** achievements unlock **paint skins** —
  purely visual, **never** stats/class, off the money/CP economies. A light collect-loop.
- **Car shop (the teleshopping break):** always open, gated by **price**; parallel to pink-slips —
  presented as a sleazy VHS **used-car / teleshopping ad segment** ("CALL NOW", price flashing on
  screen). ⚠️ Keep pink-slip cars special vs buyable. **Decided:** money comes **solely from race
  payouts** (per-race, banked-best money pool) — one clean source, mirroring CP.
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
    wedges, mono paint + one accent stripe. Ch3 boss (A). Starter car = a battered D-class Apex
    the wildcard rolls in with.
  - **Wreckhouse** — straight-line bruiser: top speed + heavy chassis, weak
    steering/braking. Slab muscle, bumper bars, scuffed plates. The **reigning champion's** own
    outfit: Ch1 boss (C, junior enforcer) and Ch4 boss (S, the champion themselves) — the
    first badge you pink-slip and the last.
  - **Mayfly Speedworks** — fast-but-brittle: top acceleration, light, damage hurts it
    more (hooks into the damage system). Cab-forward bodies, big intakes, loud two-tones.
    Ch2 boss (B).

## 9. UI / UX — the broadcast (Decided — pivot)
Fully diegetic: every screen is the pirate broadcast, or the VCR playing the tape. **Two visual
registers, deliberately different:**
- **Broadcast chrome (all menus/meta):** ultra-simple **white-on-blue VCR-OSD / teletext** look —
  chunky mono type, hard blue fields, minimal. Career map, car selection, shop, results, settings.
- **Telemetry scorebug (in-race HUD):** clean broadcast-motorsport graphics — a lower-third
  speed / time / split strip + a "● LIVE" bug. Legible at speed, and **not** the blue menu look;
  kept clean per the clarity pillar — the tape filter never fogs it.

**Diegetic touchpoints (fully committed):** loading = tracking distortion / rewind / "PLEASE STAND
BY"; race start = broadcast title card + "● LIVE"; results = scorebug + "INSTANT REPLAY" wipe;
save = "● REC"; **career map** = the broadcast's programming schedule / TV-guide grid; **shop** =
teleshopping ad break (§8); pink-slip win = "● OWNERSHIP TRANSFERRED" bumper (§8).

- **Story delivery (on-air only):** rival **interview segments** — static pixel portraits
  everywhere, few-frame animated talking-heads for boss intros (budget where it lands) — plus a
  persistent **commentary ticker / chyron** carrying flavor + the running arc, and **title cards /
  hype packages** before big races. "The tape is damaged" is a free ellipsis for anything we don't
  want to show. Cheaper than cutscenes, and it can never break the on-the-tape fiction.
- **Readability:** five stat bars are the competitor stat-line; instant car comparison. The pre-race
  screen (track/surfaces/season/weather + chosen car & bars) is a broadcast preview; a loading
  screen (as tracking/rewind) covers async scene load — no hitch into the race.
- **Font:** a broadcast/OSD face — teletext-mono for the chrome, a clean wide face with tabular
  figures for the scorebug (sourced; see `assets/fonts/`).
- **Systems:** settings + input remap + save (ship reqs), **plus a tape-filter intensity slider and
  an off switch** (accessibility — non-optional).
- **Rule:** the VHS/broadcast look is decoration. It must never cost a glance-read or a corner.
- **Open:** the in-fiction show / pirate-station name + station ident (bug, sign-off card).

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
- **VHS tape filter (Decided — pivot):** a subtle full-screen post-process over the *entire*
  render — grain, mild chroma bleed, vignette, occasional tracking wobble. "Noticeable, but it
  barely affects the driving." Heavier tracking/glitch is reserved for **transitions** (menus,
  loading, replays) where nothing's moving. **Intensity slider + off switch** (§9, accessibility).
  The voxel world + master palette are untouched underneath — the tape sits on top. **UI palette**
  shifts to VHS **white-on-blue** for the chrome; the world-side palette is unchanged. **Open:**
  the shader recipe (post-process pass vs. Environment adjustments) + perf cost.

## 12. Scope / cut list
- **Pivot (Decided):** re-framed the game as a **bootleg VHS of a pirate broadcast** (§1, §9, §11).
  **Dropped:** the scripted *revenge / father's-garage* backstory (a broadcast can't show it) and
  the pixel-art *arcade* UI direction. **Kept, unchanged:** career structure, boss climb,
  pink-slips, economy, handling, tracks, surfaces, roster — the pivot reshapes the frame, not the
  mechanics. Stakes relocate to the broadcast (wildcard → dethrone the reigning champion, beef
  earned on-air).
- **Cut:** upgrade-card system (contradicted "no upgrades"; nitro parked as the post-v1
  brand-feature candidate — v1 brands are pure stat personalities, §8).
- **v1 scoping (Open):** number of chapters (= regions, 1:1), rivals/tiers, total cars,
  tracks, and how many get full seasonal dressing. Trim to a shippable vertical slice first
  (work tracked in `tasks.yaml` / `STATUS.md`).
