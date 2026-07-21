class_name SurfaceType
extends Resource
## A drivable surface (asphalt, dirt, ice, ...). Data-only resource; instances live as .tres in
## assets/surfaces/. The vehicle controller sources per-wheel grip from the surface each wheel is
## touching (code-vehicle-surface-grip), so `grip` is the wheel friction_slip baseline for this
## surface — higher = grippier. FX/audio fields get added by their own tasks later.

@export var id := "asphalt"                 ## debug/lookup name
@export var grip := 10.5                     ## base wheel friction_slip on this surface (asphalt ~10.5, ice ~3)
@export var color := Color(0.30, 0.30, 0.32) ## tint; multiplies `texture`, and is the fallback when texture is null
@export var texture: Texture2D               ## legacy stub detail (terrain shader ignores it)
@export var tint_variation := 0.1            ## terrain-shader noise amplitude — the surface's visual "roughness character"

@export_group("Look")
## How matte this surface is. 1 = fully diffuse (gravel, dirt, sand — they should catch no
## highlight at all), 0 = mirror. Ice is the only surface that should look wet when it isn't.
@export_range(0.0, 1.0) var roughness := 0.95
## Fake blocky relief: how far the terrain shader tilts the normal per cell, as if the ground were
## made of little cubes turned different ways. Loose surfaces want a lot (gravel reads as chunks),
## hard ones almost none. Costs nothing — it's lighting variation, not geometry.
@export_range(0.0, 1.0) var chunkiness := 0.2
## The mark a sliding tyre leaves here: black rubber on tarmac, a paler displaced groove on loose
## ground, almost nothing on ice. Alpha is how visible the mark is — SkidMarks scales it by slip.
@export var mark_color := Color(0.05, 0.05, 0.06, 0.55)

# Later: @export var particles: PackedScene, @export var tire_sfx: AudioStream, rolling drag, etc.
