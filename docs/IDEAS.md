# Ideas Dump

> No filtering. Distill Pillars/GDD from this later. Revisit; promote good ones, strike dead ones.
> Tags: **Confirmed** / **Resolved** = decided · **Open** = to decide · ⚠️ = risk/tension · ADR = needs a record.

## Cross-cutting rules / principles
> Constraints every system must respect. Pillar candidates.
- **Performance-first.** Design every system for performance up front, not as an afterthought.
  Voxels + procedural tracks + crowds of cars/particles/weather stack up fast, and a stuttering
  racer fails game feel. Bias data-oriented / pooled / batched / LOD-aware; measure early.
- **Arcade clarity.** Readability over realism everywhere (stats, surfaces, grip). Pillar candidate.

## Mechanics / gameplay
- **Slipstream / drafting (must-have).** Draft in a leading car's wake → speed boost → overtake.
  Gives interesting decisions (tuck/pull/block) and organic, skill-based catch-up (no rubber-banding).
  AI must both give and use draft. *Open:* readable visual/audio feedback for the boost.
- **Car damage.** Hitting geometry/cars deals **visible** + **performance** damage.
  - Visible: cheapest method (material swap, broken-part props, sparks/smoke — not mesh deform).
    Voxel chipping is the likely fit (see art).
  - Performance: mild but punishing (slight steering pull / reduced top speed) — makes contact cost
    something without death-spiraling the race.
  - **Resolved:** resets per race; pristine start; no repair economy. Purely in-race pressure.

## Tracks / environments
- **Verticality + jumps (requirement).** Real height variation + jumps (ramps/gaps/crests);
  vehicle controller handles airborne.
- **Procedural track generation from simple data (KEY DIRECTION — ADR before M1).** Build the 3D
  track from light authored data instead of modeling — tracks become **data + code** (routes around
  the no-3D-art constraint).
  - Inputs: 2D layout (spline/`Curve3D`) + height (per-point or heightmap image) + cosmetic
    season/time/weather modifiers.
  - Approach (Godot): road = spline-extruded ribbon (`CSGPolygon3D` proto → `ArrayMesh` prod) with
    per-segment width/banking/**surface tags** (tags drive material + grip). Terrain from heightmap
    (custom mesh or `Terrain3D`). Jumps = tagged ramp/gap segments. Props scattered along spline.
  - Payoff: huge variety from tiny inputs; surfaces/jumps/banking fall out of one data model.
  - ⚠️ Risks/open: producing a *fun, readable* racing line (not just valid geometry); collision +
    AI line baked from spline; LOD/perf; how much procedural vs hand-tuned (likely backbone + knobs).
- **Road surfaces, mixable within one race.** asphalt, dirt, snow, sand, gravel, ice, shallow water.
  Each gives **readable** grip/traction effects (ice = long slides, asphalt = max grip). Makes the
  **grip** stat and **manufacturer styles** situational; reinforces rally identity.
  Impl: tagged physics-material zones → grip multiplier + per-surface particle/audio feedback.
  *Open:* persistent effects (mud slow, hydroplane)?
- **Seasons (purely visual).** 4 seasons swap models/FX (foliage, palette, ambient). **No gameplay
  effect** — cheap variety multiplier. ⚠️ Keep decoupled from grip ("winter" look ≠ ice). ⚠️ Cost:
  4× dressing per track. *Open:* author-picked per race vs free.
- **Time of day + weather (combinable).**
  - Time → visibility/aesthetics: morning, day, golden hour, night.
  - Weather → grip (stacks on surface): clear, rain/snow, thunder, fog.
  - Combine freely → big aesthetic + difficulty range from few blocks. Keep combined grip readable
    (not invisible RNG). ⚠️ Low-visibility (night/fog) must stay *fair* — telegraph corners.
  - **Resolved:** fixed per race (no mid-race shift); does NOT escalate for boss/late races — it's
    variety/aesthetic, not a difficulty lever.

## Cars / progression
- **Two currencies (Resolved).** **money → garage** (what you drive), **points → story** (how far
  you advance). No overlap.
- **Pink-slip unlocks (Confirmed).** Beat a rival → win their car. Story progress = garage growth.
  Each rival's car must be desirable + distinct; rivals drive the car you'll inherit.
- **Car shop (Confirmed).** Always open; better cars gated by **price**. Runs parallel to pink-slips.
  ⚠️ Keep pink-slip cars special vs buyable (unique/unbuyable, or cheaper-than-equivalent). *Open:*
  money sources (winnings/bounty/events).
- **Classes S, A, B, C, D (Resolved; E/F dropped).** One at-a-glance rank bundling the 5 stats.
  Backbone: shop price ↔ class, rivals escalate by class (early D/C → final S), pink-slips climb it.
  Likely enables class-restricted events. *Open:* descriptive only, or gates event entry?
- **Readable stats, no tuning (Resolved).** Cars = 5 legible bars: **speed, accel, steering, braking,
  grip**. **Fixed per car; no upgrades.** Progression = acquiring cars. Balance lives in roster design;
  every car must be a distinct point in stat space (no filler).
- **3–4 manufacturers, implicit identities (Borderlands-style).** Each brand leans into a racing
  style + shares a visual family; styles **never stated** — learned through play (mastery/depth).
  Style examples: aggressive/engaging, fast-but-brittle, corner-king, (TBD).
  - **Confirmed:** antagonists rep a brand (unifies cars+story+art); pink-slip = a car of their brand.
  - **Confirmed:** full class coverage — every brand has ≥1 car per class S–D, so a style-loyal player
    always has an in-style upgrade. ⚠️ Scope: ~brands×5 cars min (4×5 = 20) → lean on kitbashing.
  - **Brand features:** a brand's cars may carry a baked-in ability (e.g. nitro) as identity — not an
    upgrade/loadout. *Open:* brand names/personalities; which brand gets which feature.

## Modes
- **CHOSEN story: "The Circuit" — traveling outlaw racing festival + revenge spine.** Festival moves
  region to region; each chapter = a region with a local champion (boss).
  - **Real goal = beat the final boss** (placeholder: wrecked your father's garage). Tournaments are
    just the path to reach him; pink-slips along the way build toward the reckoning. Rivals tie to it.
  - ⚠️ **Decoupling rule:** region = aesthetic/cultural theme, **not a surface biome**. Every region
    still mixes surfaces per race (avoid "the snow level"). Travel changes the *look*, not the surfaces.
  - Difficulty escalates via opponents + track complexity, never "the sand world."
- **Blacklist-style career.** Roster of named, characterful rivals climbed one by one; each chapter
  ends in a boss-fight duel. Catchy antagonists (personality, signature car, taunts) are the hook.
  *Open:* how many rivals/tiers for v1.
- **Race types.** Time trial, circuit (laps), sprint (point-to-point), endurance (attrition), grand
  prix (qualy + race). Each a different pattern to master.
- **Lenient progression (anti-frustration; Resolved).** No 1st-place requirement; every race pays
  **money + campaign points**; replay optional. **Points** unlock the chapter boss at **≈70% of the
  chapter's total** (skip ~30% — escape valve for disliked/lost races). Points gate **only** boss +
  next chapter. Implication: most races skippable → each must be fun enough to play voluntarily.
- **Officials vs Wilds (Resolved).** Two race cultures reframing the damage mechanic:
  Officials = clean (contact → time penalty); Wilds = ramming is valid. Both always available, mixed
  every chapter. Pairs with brands (aggressive brand shines in Wilds).

## Vibe / art / audio
- **Style: voxel models + voxel FX, polygon roads (DIRECTION — ADR; whole art pipeline).** Cars/props/
  environment voxel; road surface stays polygon (smooth — voxel roads ruin feel).
  - Fit: voxel authoring (MagicaVoxel, free) is approachable for a programmer w/ ok 2D skills → makes
    ~20 cars + brand families achievable solo; distinct/marketable; paint skins = palette swap; damage
    = voxel chipping; brand families = kitbash voxel chunks.
  - ⚠️ Seam coherence: voxel objects vs polygon road/terrain — match terrain to voxel, or lean into
    voxel-on-low-poly contrast. *Open:* MagicaVoxel→mesh export vs runtime voxels; FX (particles vs
    voxel sim); terrain style.
- **Pixel art for avatars + UI (matches voxel = 3D pixel art).** Rival portraits, HUD, menus, icons.
  Leans on the dev's real 2D skill (self-made, not sourced); gives antagonists real faces.
  *Open:* avatar presentation (static/animated/talking-head); UI theme.
- **Skins = paint, universal across cars (Resolved).** Cosmetic rewards from **achievements** (not
  bought), freely chosen, must display on every car. A skin = **(color, finish)** on a designated
  "paintable" material slot — trivial, no shared UV needed. Finishes: matte/metallic/chrome/pearlescent
  (chrome/pearl = rare/prestige). *Open:* achievement-list scope.

## Wild / maybe-too-much
-

## Quick wins (<1hr, for low-energy days)
> Small satisfying tasks: a particle, a sound, screen-shake, a tweak.
-

## Parking lot (revisit / undecided)
-
