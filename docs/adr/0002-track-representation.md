# 0002 — Track representation

- **Status:** accepted
- **Date:** 2026-06-06

## Context
Tracks are procedural from light authored data (GDD §7): a 2D layout + height + cosmetic
modifiers, with per-surface tags. From one source we must derive the **road mesh**, its
**collision**, ordered **checkpoint gates** (anti-shortcut, GDD §5), and an **AI racing line**
(M3). The setting is realistic rally, so the road must read as **part of the ground**, not a
floating ribbon. This ADR picks the representation + authoring/bake pipeline.

## What we built & drove (two spikes)
- `prototypes/track_spline/` — a spline → ground generator, iterated live: CSG ribbon →
  per-surface mesh segments → **heightmap-carve** (road carved into one ground mesh) →
  terrain integration.
- `prototypes/track_image/` — an **image-driven bake pipeline**: a generator writes 3 sample
  images; a baker reads them and saves a static `baked_track.tscn` with ground mesh+collision,
  an **auto-extracted `Path3D`** (hand-tunable), start/finish, and props.

## Findings (validated in-hand)
1. **The road is 1-D.** Anything road-related — height, width, edges, surface — must be computed
   from the **centreline** (project each point onto it), never from per-pixel/per-cell raster
   math. Using raw angle/position gave a twisting cross-cant ("phantom bumps") and scalloped
   edges; centreline projection gave flat cross-sections + clean parallel edges.
2. **Heightmaps must be float/16-bit, never 8-bit.** 8-bit PNG = 256 height levels ≈ 0.1 m
   stair-steps → a bumpy road no matter the pixel resolution. Float `EXR` (`FORMAT_RF`) fixed it.
3. **Three independent resolutions:** image (precision / road-edge crispness), **mesh**
   (geometry — decoupled via bilinear sampling between texels), **texture** (surface detail —
   splat). Conflating them is why early versions looked blocky.
4. **Surface grip:** with *separate* per-surface bodies, the car reads grip from
   `VehicleWheel3D.get_contact_body()` meta. With a *single* ground mesh, grip is **position-
   based** (nearest point on the spline, or sample the surface image) — the heightmap-carve
   trade-off (carries over from ADR-001: grip via `wheel_friction_slip`, not `PhysicsMaterial`).
5. **Collision:** a generated trimesh works but needs `backface_collision = true` (our winding
   is arbitrary) and is heavy at high res. `HeightMapShape3D` is the cheap production collision.
6. **Bake-time beats runtime.** Generating in a tool and **saving a static scene** (external
   `.res` mesh via `take_over_path`, `st.index()` to dedupe) gives a small, inspectable,
   optimizable asset and zero load-time cost — vs regenerating every play.
7. **Images encode space, splines encode order.** A raster gives *where* (height, surface,
   spawn points) but not *sequence*. Laps, ordered checkpoints, and the AI line need the spline.

## Decision
**Tracks = a spline (race) + images (world), baked offline into a static scene.**
- **Spline (`Path3D` / `Curve3D`)** is the source of truth for the **racing line, lap order,
  checkpoints, AI line, and the road's vertical profile**. Authored by hand (and rough-
  auto-extractable from the road image to start).
- **Images** author the **world**: a **float heightmap** (terrain), a **surface/splat map**
  (road location + surface type + grip), and a **markers map** (start/finish, props).
- **Road is carved into the terrain** (cut-and-fill) so it's part of the ground; road geometry,
  edges, and surface are computed from the **centreline**, terrain blends to the road edges.
- A **bake tool** (`@tool`/EditorScript) reads spline + images → static scene: ground mesh +
  collision, checkpoints + AI line sampled from the spline, markers/props placed.
- **Grip** comes from a surface tag (`SurfaceType`): per-body meta for segmented roads, or
  position/splat lookup for unified ground.

## Alternatives considered
- **CSGPolygon3D ribbon** — kept as a quick blockout tool; one body/one material, so no
  per-surface grip and it floats on terrain. Not the production road.
- **Per-surface mesh segments on terrain** — works and tags surfaces cleanly, but the road
  floats/seams over the ground; rejected for the realism goal.
- **Pure runtime generation** — fine for prototyping; rejected for shipping (no static
  optimization, load-time cost, not inspectable).
- **Terrain3D plugin** — the likely production upgrade for terrain (sculpt + splat + LOD +
  holes); deferred — our own bake proves the pipeline first, plugin can slot in later.

## Consequences
- M1's test track can be a simple authored `Path3D` + the spline generator; the image pipeline
  is for content (M3+).
- Define a **`SurfaceType`** resource (grip + particle + audio) — the `grip_slip`/colour stand-
  ins become this.
- Production deltas to schedule: **`HeightMapShape3D`** collision, **splat textures**, the bake
  tool as an in-editor button, spline-driven road height (vs rasterised), and Terrain3D eval.
- Locked to Godot Physics (per ADR-001). 2.5-D heightmap ⇒ no bridges/overpasses without extra
  work — acceptable for rally.
- Prototype bake outputs (`*.res`, `baked_track.tscn`, generated images) are regenerable and
  git-ignored; the generator/baker scripts are the source of truth.
