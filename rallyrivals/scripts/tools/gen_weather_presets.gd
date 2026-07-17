extends SceneTree
## Writes the five WeatherPreset .tres files (art-vfx-weather). Colours derive from
## master-palette anchors; grip multipliers ship dormant for code-track-weather-grip.
## Run: godot --headless --script res://scripts/tools/gen_weather_presets.gd

func _initialize() -> void:
	var dir := "res://assets/weather/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var presets: Array[WeatherPreset] = []

	var clear := WeatherPreset.new()
	clear.id = "clear"
	presets.append(clear)

	var rain := WeatherPreset.new()
	rain.id = "rain"
	rain.precipitation = "rain"
	rain.amount = 700
	rain.fall_speed = 20.0
	rain.wind = Vector3(2.0, 0.0, 0.0)
	rain.particle_size = Vector3(0.03, 0.35, 0.03)   # stretched cube = streak
	rain.particle_color = Color("afbfd8", 0.55)
	rain.fog_enabled = true
	rain.fog_density = 0.006
	rain.fog_color = Color("738fb1")
	rain.grip_multiplier = 0.85
	presets.append(rain)

	var snow := WeatherPreset.new()
	snow.id = "snow"
	snow.precipitation = "snow"
	snow.amount = 450
	snow.fall_speed = 2.8
	snow.wind = Vector3(0.6, 0.0, 0.3)
	snow.turbulence = 0.15
	snow.particle_size = Vector3(0.07, 0.07, 0.07)
	snow.particle_color = Color("ebf0f7", 0.9)
	snow.fog_enabled = true
	snow.fog_density = 0.008
	snow.fog_color = Color("afbfd8")
	snow.grip_multiplier = 0.75
	presets.append(snow)

	var thunder := WeatherPreset.new()
	thunder.id = "thunder"
	thunder.precipitation = "rain"
	thunder.amount = 900
	thunder.fall_speed = 24.0
	thunder.wind = Vector3(4.0, 0.0, 1.5)
	thunder.particle_size = Vector3(0.03, 0.4, 0.03)
	thunder.particle_color = Color("8fa6c5", 0.6)
	thunder.fog_enabled = true
	thunder.fog_density = 0.012
	thunder.fog_color = Color("597a9e")
	thunder.thunder = true
	thunder.grip_multiplier = 0.8
	presets.append(thunder)

	var fog := WeatherPreset.new()
	fog.id = "fog"
	fog.precipitation = "none"
	fog.fog_enabled = true
	fog.fog_density = 0.028   # moderate: corners must still telegraph (GDD fairness)
	fog.fog_color = Color("b8b8ad")
	presets.append(fog)

	for pr in presets:
		ResourceSaver.save(pr, dir + pr.id + ".tres")
	print("weather presets: ", presets.size())
	quit()
