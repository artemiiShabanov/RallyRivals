extends SceneTree
## Writes the five WeatherPreset .tres files (art-vfx-weather). Colours derive from
## master-palette anchors; grip multipliers feed code-track-weather-grip; each preset also
## carries the ambience bed it plays (audio-sfx-ambient) — run gen_ambient_sfx.gd first.
## Run: godot --headless --script res://scripts/tools/gen_weather_presets.gd

func _amb(id: String) -> AmbientDef:
	return load("res://assets/audio/ambient/%s.tres" % id) as AmbientDef

func _initialize() -> void:
	var dir := "res://assets/weather/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var presets: Array[WeatherPreset] = []

	var clear := WeatherPreset.new()
	clear.id = "clear"
	clear.cloud_cover = 0.3
	clear.cloud_color = Color("f2ebd9")
	clear.ambient = _amb("wind_light")
	presets.append(clear)

	var rain := WeatherPreset.new()
	rain.id = "rain"
	rain.precipitation = "rain"
	rain.amount = 700
	rain.fall_speed = 20.0
	rain.wind = Vector3(2.0, 0.0, 0.0)
	rain.particle_size = Vector3(0.018, 0.22, 0.018)   # stretched cube = streak
	rain.particle_color = Color("afbfd8", 0.32)
	rain.fog_enabled = true
	rain.fog_density = 0.006
	rain.fog_color = Color("738fb1")
	rain.cloud_cover = 0.85
	rain.cloud_color = Color("8fa6c5")
	rain.grip_multiplier = 0.85
	rain.wetness = 0.8
	rain.ambient = _amb("rain")
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
	snow.cloud_cover = 0.85
	snow.cloud_color = Color("ebf0f7")
	snow.grip_multiplier = 0.75
	snow.wetness = 0.15
	snow.ambient = _amb("snow_wind")
	presets.append(snow)

	var thunder := WeatherPreset.new()
	thunder.id = "thunder"
	thunder.precipitation = "rain"
	thunder.amount = 900
	thunder.fall_speed = 24.0
	thunder.wind = Vector3(4.0, 0.0, 1.5)
	thunder.particle_size = Vector3(0.018, 0.26, 0.018)
	thunder.particle_color = Color("8fa6c5", 0.38)
	thunder.fog_enabled = true
	thunder.fog_density = 0.012
	thunder.fog_color = Color("597a9e")
	thunder.cloud_cover = 1.0
	thunder.cloud_color = Color("597a9e")
	thunder.thunder = true
	thunder.grip_multiplier = 0.8
	thunder.wetness = 1.0
	thunder.ambient = _amb("rain_heavy")
	thunder.thunder_sfx = load("res://assets/audio/sfx/thunder.tres") as SfxDef
	presets.append(thunder)

	var fog := WeatherPreset.new()
	fog.id = "fog"
	fog.precipitation = "none"
	fog.fog_enabled = true
	fog.fog_density = 0.028   # moderate: corners must still telegraph (GDD fairness)
	fog.fog_color = Color("b8b8ad")
	fog.cloud_cover = 0.95
	fog.cloud_color = Color("b8b8ad")
	fog.wetness = 0.25
	fog.ambient = _amb("wind_low")
	presets.append(fog)

	for pr in presets:
		ResourceSaver.save(pr, dir + pr.id + ".tres")
	print("weather presets: ", presets.size())
	quit()
