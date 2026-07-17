class_name LightingPreset
extends Resource
## One time-of-day look (GDD 7: morning / day / golden hour / night — visibility/aesthetics
## only, no gameplay effect). Applies onto a baked track's WorldEnvironment + Sun (the baker
## always creates both). Per-race selection is code-track-conditions' job; the debug menu can
## apply presets live meanwhile. Colours derive from the master palette (assets/palette) so
## skies sit in the same world as the models. Night stays deliberately readable — low
## visibility must be fair.

## The preset most recently applied decides whether cars run headlights (late-spawned cars
## read this in _ready, so they match the scene's time of day).
static var current_headlights := false

@export var id := ""
@export var headlights := false          ## cars switch beams on under this preset (night)
@export var sun_rotation_degrees := Vector3(-50, -40, 0)
@export var sun_color := Color(1, 1, 1)
@export var sun_energy := 1.2
@export var ambient_energy := 0.5
@export var sky_top := Color(0.2, 0.37, 0.5)
@export var sky_horizon := Color(0.78, 0.88, 0.95)
@export var ground_horizon := Color(0.69, 0.75, 0.85)
@export var ground_bottom := Color(0.1, 0.1, 0.13)

## Retune the first WorldEnvironment + DirectionalLight3D found under `root`.
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
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_mat == null:
		var sky := Sky.new()
		sky_mat = ProceduralSkyMaterial.new()
		sky.sky_material = sky_mat
		env.sky = sky
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = ground_horizon
	sky_mat.ground_bottom_color = ground_bottom
	current_headlights = headlights
	if root.is_inside_tree():
		for v in root.get_tree().get_nodes_in_group("vehicles"):
			if v.has_method("set_headlights"):
				v.set_headlights(headlights)
	return true
