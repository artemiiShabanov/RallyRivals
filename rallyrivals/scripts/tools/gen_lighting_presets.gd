extends SceneTree
## Writes the four time-of-day LightingPreset .tres files (art-world-lighting). Colours are
## derived from master-palette anchors (lerps between palette hexes, never foreign hues) so
## skies belong to the same world as the models. Edit here, regenerate.
## Run: godot --headless --script res://scripts/tools/gen_lighting_presets.gd

func _initialize() -> void:
	var dir := "res://assets/lighting/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var presets := [
		_p("morning", Vector3(-22, -70, 0), Color("f2ebd9"), 1.0, 0.45,
			Color("738fb1"), Color("f27a85").lerp(Color("f2ebd9"), 0.45),
			Color("afbfd8"), Color("1a1a21")),
		_p("day", Vector3(-50, -40, 0), Color("f2ebd9").lerp(Color.WHITE, 0.5), 1.25, 0.5,
			Color("335d80"), Color("c7e0f2"),
			Color("afbfd8"), Color("1a1a21")),
		_p("golden", Vector3(-14, -115, 0), Color("d9a836").lerp(Color("db7a33"), 0.4), 1.15, 0.42,
			Color("5180a0"), Color("d1ad61").lerp(Color("db7a33"), 0.5),
			Color("a56640"), Color("1a1a21")),
		_p("night", Vector3(-38, 30, 0), Color("afbfd8"), 0.4, 0.3,
			Color("0d2440"), Color("1d3e60"),
			Color("141417"), Color("0d0d10")),
	]
	for pr in presets:
		ResourceSaver.save(pr, dir + pr.id + ".tres")
	print("lighting presets: ", presets.size())
	quit()

func _p(id: String, rot: Vector3, sun_col: Color, energy: float, ambient: float,
		top: Color, horizon: Color, g_h: Color, g_b: Color) -> LightingPreset:
	var p := LightingPreset.new()
	p.id = id
	p.sun_rotation_degrees = rot
	p.sun_color = sun_col
	p.sun_energy = energy
	p.ambient_energy = ambient
	p.sky_top = top
	p.sky_horizon = horizon
	p.ground_horizon = g_h
	p.ground_bottom = g_b
	return p
