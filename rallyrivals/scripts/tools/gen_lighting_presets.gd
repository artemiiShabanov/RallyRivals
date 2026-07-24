extends SceneTree
## Writes the four time-of-day LightingPreset .tres files (art-world-lighting). A LightingPreset
## no longer owns the sky's colours (weather does — see gen_weather_presets.gd); it sets the sun
## (angle/colour/energy), ambient, and a sky TINT (mul colour × energy) that warms/darkens
## whatever weather sky is up. Tints derive from master-palette anchors so the hours stay in the
## same world. Edit here, regenerate.
## Run: godot --headless --script res://scripts/tools/gen_lighting_presets.gd

func _initialize() -> void:
	var dir := "res://assets/lighting/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	#      id         sun_rotation          sun_color                                energy amb   sky_tint         sky_energy
	var presets := [
		_p("morning", Vector3(-22, -70, 0),  Color("f2ebd9"),                          1.0,  0.45, Color("f7e6cf"), 0.92),
		_p("day",     Vector3(-50, -40, 0),  Color("f2ebd9").lerp(Color.WHITE, 0.5),   1.25, 0.5,  Color("ffffff"), 1.05),
		_p("golden",  Vector3(-14, -115, 0), Color("d9a836").lerp(Color("db7a33"), 0.4), 1.15, 0.42, Color("f0b46a"), 0.9),
		_p("night",   Vector3(-38, 30, 0),   Color("afbfd8"),                          0.4,  0.3,  Color("8d9ccb"), 0.3),
	]
	for pr in presets:
		pr.headlights = pr.id == "night"
		ResourceSaver.save(pr, dir + pr.id + ".tres")
	print("lighting presets: ", presets.size())
	quit()

func _p(id: String, rot: Vector3, sun_col: Color, energy: float, ambient: float,
		tint: Color, sky_energy: float) -> LightingPreset:
	var p := LightingPreset.new()
	p.id = id
	p.sun_rotation_degrees = rot
	p.sun_color = sun_col
	p.sun_energy = energy
	p.ambient_energy = ambient
	p.sky_tint = tint
	p.sky_energy = sky_energy
	return p
