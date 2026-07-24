extends SceneTree
## Writes sample RaceDef .tres files (code-race-defs). Real career races come with
## content-rivals-campaign; these two exercise the conditions pipeline end to end.
## Run: godot --headless --script res://scripts/tools/gen_race_defs.gd

func _initialize() -> void:
	var dir := "res://assets/races/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var day_race := RaceDef.new()
	day_race.id = "test_circuit"
	day_race.display_name = "Test Circuit — Golden Hour"
	day_race.track_scene = "res://assets/tracks/test/baked_track.tscn"
	day_race.race_type = "circuit"
	day_race.laps = 3
	day_race.lighting = load("res://assets/lighting/golden.tres")
	day_race.weather = load("res://assets/weather/clear.tres")
	ResourceSaver.save(day_race, dir + "test_circuit.tres")

	var storm := RaceDef.new()
	storm.id = "night_thunder"
	storm.display_name = "Test Circuit — Night Storm"
	storm.track_scene = "res://assets/tracks/test/baked_track.tscn"
	storm.race_type = "circuit"
	storm.laps = 3
	storm.culture = "wilds"
	storm.lighting = load("res://assets/lighting/night.tres")
	storm.weather = load("res://assets/weather/thunder.tres")
	ResourceSaver.save(storm, dir + "night_thunder.tres")

	var trial := RaceDef.new()
	trial.id = "test_timetrial"
	trial.display_name = "Test Circuit — Time Trial"
	trial.track_scene = "res://assets/tracks/test/baked_track.tscn"
	trial.race_type = "time_trial"
	trial.laps = 2
	trial.lighting = load("res://assets/lighting/day.tres")
	trial.weather = load("res://assets/weather/clear.tres")
	trial.tt_gold = 62.0        # placeholder targets until balance sets real ones
	trial.tt_silver = 72.0
	trial.tt_bronze = 85.0
	ResourceSaver.save(trial, dir + "test_timetrial.tres")

	print("race defs: 3")
	quit()
