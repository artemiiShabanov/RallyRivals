class_name SurfaceType
extends Resource
## A drivable surface (asphalt, dirt, ice, ...). Data-only resource; instances live as .tres in
## assets/surfaces/. The vehicle controller sources per-wheel grip from the surface each wheel is
## touching (code-vehicle-surface-grip), so `grip` is the wheel friction_slip baseline for this
## surface — higher = grippier. FX/audio fields get added by their own tasks later.

@export var id := "asphalt"                 ## debug/lookup name
@export var grip := 10.5                     ## base wheel friction_slip on this surface (asphalt ~10.5, ice ~3)
@export var color := Color(0.30, 0.30, 0.32) ## placeholder tint for debug/mesh until real textures land

# Later: @export var particles: PackedScene, @export var tire_sfx: AudioStream, rolling drag, etc.
