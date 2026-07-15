# 0003 — Voxel art pipeline

- **Status:** accepted
- **Date:** 2026-07-12

## Context
GDD §11: cars/props/environment are voxel, the road stays polygon (smooth — voxel roads ruin
feel), pixel-art 2D. A solo dev with no 3D-modelling background must produce a ~15-car roster
with per-brand visual families (§8) plus prop/scenery sets — voxel authoring is what makes that
achievable. Three questions were left open: how voxels get from the authoring tool into Godot,
how visible damage works (§4: "visible damage, likely voxel chipping"), and how voxel objects
coexist with the smooth polygon terrain without looking pasted-on ("seam coherence").

Unlike ADR-001/002 this one is decided from constraints + community practice, not a spike —
**`art-voxel-car-blockout` is the designated validation spike**; if the export path fights us
there, revisit before the roster work starts.

## Decision
**Author in MagicaVoxel; export `.obj` by hand; commit both source and artifact. Damage =
pre-authored voxel damage-state swaps + cube-particle bursts. World = smooth flat-shaded
low-poly terrain sharing one palette discipline with the voxel models.**

1. **Authoring — MagicaVoxel** (free), one `.vox` per asset.
   **Scale convention: 1 voxel = 0.1 m** everywhere (a 4 m car ≈ 40 voxels long — chunky but
   enough resolution for brand silhouettes). Consistent scale is what makes cars, props and
   particles read as one world.
2. **Import route — MV's `.obj` export.** Export `.obj` + palette `.png` from MagicaVoxel,
   Godot imports the obj natively; no third-party addon to vet or maintain. Both files are
   committed together (`.vox` = source of truth, `.obj`/`.png` = artifact — same
   committed-source/regenerable-artifact philosophy as track images vs bakes, except the
   export step is manual, so the artifact is committed too).
   Layout: `assets/voxels/<category>/<name>.vox|.obj|.png` (e.g. `cars/apex_d.*`).
   Material conventions: palette texture as albedo with **nearest filtering**, roughness 1,
   metallic 0, no normal maps — flat colour is the aesthetic.
3. **Damage — pre-authored state swaps + cube bursts** (feeds `code-vehicle-damage`,
   `art-vfx-damage`): each car ships 2 damage variants (light/heavy) authored as quick `.vox`
   copies with voxels deleted/dented; runtime swaps the mesh by damage tier. Impacts spawn
   `GPUParticles3D` bursts of small cubes tinted from the car's palette — the "chipping" read
   without runtime mesh surgery. Damage resets per race (GDD §4), so swaps are trivially
   reversible.
4. **FX coherence rule: every particle is a cube.** Dust, snow spray, sparks, damage chips —
   all voxel-scale box meshes, never billboards/soft sprites. Cheap, and it's what ties FX to
   the models.
5. **World coherence — voxel-on-low-poly contrast, unified palette.** Terrain and road keep
   their smooth geometry (heightfield collision stays honest) but render **flat-shaded** with
   solid splat colours (faceted low-poly look; `art-shader-surface` / `art-world-terrain-tex`
   implement it, replacing today's stub textures). One **master palette** document defines the
   colour ramps used by BOTH the MagicaVoxel palettes and the terrain/surface colours —
   coherence comes from colour discipline, not from voxelizing the world. `SurfaceType.color`
   remains the classifier source of truth.

## Alternatives considered
- **`.vox` importer addon** — single source of truth, no manual export; rejected for the
  third-party dependency to vet and carry across Godot upgrades. Revisit only if manual
  exports become a real iteration drag.
- **Runtime voxel meshing / true chipping** — per-voxel removal at impacts, rebuilt meshes.
  Most spectacular, but significant engineering + perf risk for a solo v1; the swap+burst
  combo buys ~80% of the read for ~5% of the cost. Post-v1 candidate if damage feel
  underwhelms.
- **Shader-faked damage only** — cheapest, roster-neutral, but fails the "visible damage"
  bar; kept as a fallback if authoring damage variants blows the art budget.
- **Terraced voxel-look terrain** — strongest style unity, but quantized terrain visuals
  fight the smooth heightfield (visual/collision mismatch) and the buttery-road pillar.

## Consequences
- Unblocks the `art-voxel-*` chain; **`art-voxel-car-blockout` doubles as the pipeline spike**
  (author → export → import → drive it on the test track). Any friction found there amends
  this ADR before the roster (~15 cars × 3 damage states) commits to the path.
- Damage variants triple the per-car voxel work; accepted because variants are quick
  destructive edits of a copy, not new models. `content-cars-roster` should budget for it.
- A master palette needs authoring before serious art starts (candidate addition to
  `art-ui-theme` or its own small task).
- Terrain flat-shading + splat colours land with `art-shader-surface`; until then the
  gray-box look stays.
- MagicaVoxel is macOS-friendly but its exports are manual — document the export settings in
  the assets README when the first model lands (CREDITS.md already tracks tooling).
