extends Resource
## A campaign REGION = the visual BIOME / land identity (code-track-regions). Applied as a RUNTIME
## RESKIN over a neutral baked track by RegionSkin: the off-road ground (grip + colour), the prop
## visual variants, and the scenery dressing. A region PERSISTS across a race's time-of-day and
## weather — it is NOT the "moment": lighting / weather / ambience / sky / fog stay per-race conditions
## and are untouched by region. Placeholder gray-box look (tints) until art-world-regions / art-voxel-*
## author the real sets; the region already carries the structure the art fills in.
##
## Intentionally has NO class_name — preloaded BY PATH (Campaign, RegionSkin) and referenced from
## RaceDef as a plain Resource, so it never depends on the global class registry (which lags a new
## class in an open editor and would parse-error the boot-critical RaceDef/Campaign until a restart).
## Authored as .tres in assets/regions/ (gen_region_defs.gd), loaded by name like lighting/weather.

@export var id := ""
@export var display_name := ""
@export_multiline var vibe := ""   ## art-direction note (dressing/look intent) for art-world-regions + Stage 3

@export_group("Off-road ground (Stage 2 reskin)")
## The biome's off-road SurfaceType — carries BOTH grip (sand 5.0 / snow 4.x …) and ground colour.
## RegionSkin swaps this onto the track's SurfaceMap (grip) and the terrain palette slot (colour).
@export var off_road_surface: SurfaceType

@export_group("Props (placeholder tints until art-voxel-props ×3)")
## PropCatalog type id -> placeholder box colour for this region (tree/rock/bush …). A missing key
## keeps the catalog default. Barriers / fences / signs are race INFRASTRUCTURE (region-neutral) — so
## regions normally tint only the natural scatter (tree/rock/bush), not the man-made props.
@export var prop_tints: Dictionary = {}
## Optional real variant meshes per type (art authors ×3). Empty = keep the baked placeholder box.
@export var prop_meshes: Dictionary = {}

@export_group("Dressing (scenery — art-voxel-environment models via EnvCatalog)")
@export var dressing_tint := Color(0.20, 0.40, 0.18)   ## box-fallback / water tint; 0-density = no dressing
@export var dressing_density := 1.0                    ## 0 = no dressing
@export var dressing_backdrop := ""                    ## EnvCatalog id tiled around the horizon (ridge/mesa/treeline)
@export var dressing_buildings: Array = []             ## EnvCatalog ids ringed OUTSIDE the track (house/hall/tower)
@export var dressing_water := false                    ## a flat water plane at the horizon (Island)
@export var backdrop_scale := 1.0                      ## backdrop size multiplier (Alpine mountains x2)
@export var backdrop_dist := 1.0                       ## backdrop ring distance multiplier (Alpine x2 further)
@export var backdrop_count := 1.0                      ## backdrop segment-count multiplier (Island/Dunes fewer)
@export var building_scale := 4.0                      ## building size multiplier (they ring outside the track)
## Sky BOTTOM-hemisphere colour (the band below the horizon). a<=0 = use off_road_surface.color, so the
## distant ground blends into the horizon; set explicitly for a water region (Island -> deep blue).
@export var sky_ground := Color(0, 0, 0, 0)
## Recolour the backdrop model to this flat colour (a<=0 = keep the model's own palette). Use it to
## match a ground-type backdrop to the surface — e.g. Dunes mesas = sand — so bg + ground read as one.
@export var backdrop_tint := Color(0, 0, 0, 0)

## The placeholder colour for a prop type in this region, or `fallback` (the catalog colour) if unset.
func prop_tint(type_id: String, fallback: Color) -> Color:
	return prop_tints.get(type_id, fallback)
