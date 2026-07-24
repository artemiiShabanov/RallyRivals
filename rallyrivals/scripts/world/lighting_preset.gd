class_name LightingPreset
extends Resource
## One time-of-day look (GDD 7: morning / day / golden hour / night — visibility/aesthetics
## only, no gameplay effect). Applies onto a baked track's WorldEnvironment + Sun (the baker
## always creates both). Time-of-day does NOT own the sky's colours — WEATHER does (see
## WeatherPreset / the VHS sky shader). A LightingPreset only sets the SUN (angle/colour/
## energy), ambient level, and a sky TINT (sky_tint × sky_energy) that darkens/warms whatever
## weather sky is up. So a grey rain sky reads bright-grey at noon and dark-grey at night.
## Colours derive from the master palette (assets/palette). Night stays deliberately readable —
## low visibility must be fair.

## The preset most recently applied decides whether cars run headlights (late-spawned cars
## read this in _ready, so they match the scene's time of day).
static var current_headlights := false

@export var id := ""
@export var headlights := false          ## cars switch beams on under this preset (night)
@export var sun_rotation_degrees := Vector3(-50, -40, 0)
@export var sun_color := Color(1, 1, 1)
@export var sun_energy := 1.2
@export var ambient_energy := 0.5
@export_group("Sky tint")
@export var sky_tint := Color(1, 1, 1)    ## multiplied over the weather sky (warmth)
@export var sky_energy := 1.0             ## brightness: ~1 by day, low at night

## Retune the first WorldEnvironment + DirectionalLight3D found under `root`. Ensures the VHS
## sky material is present, then writes the time-of-day tint onto it. Returns false if the
## scene has no environment/sun to drive.
func apply_in(root: Node) -> bool:
	var envs := root.find_children("*", "WorldEnvironment", true, false)
	var suns := root.find_children("*", "DirectionalLight3D", true, false)
	if envs.is_empty() or suns.is_empty():
		return false
	var env := (envs[0] as WorldEnvironment).environment
	var sun := suns[0] as DirectionalLight3D
	sun.rotation_degrees = sun_rotation_degrees
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	env.ambient_light_energy = ambient_energy
	var sky_mat := VhsSky.ensure(env)
	if sky_mat != null:
		sky_mat.set_shader_parameter("sky_tint", sky_tint)
		sky_mat.set_shader_parameter("sky_energy", sky_energy)
	current_headlights = headlights
	if root.is_inside_tree():
		for v in root.get_tree().get_nodes_in_group("vehicles"):
			if v.has_method("set_headlights"):
				v.set_headlights(headlights)
	return true
