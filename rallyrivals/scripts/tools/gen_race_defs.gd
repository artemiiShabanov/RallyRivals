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
	day_race.class_low = "D"          # field band (field-matching): D–C beginner circuit
	day_race.class_high = "C"
	day_race.lighting = load("res://assets/lighting/golden.tres")
	day_race.weather = load("res://assets/weather/clear.tres")
	ResourceSaver.save(day_race, dir + "test_circuit.tres")

	var storm := RaceDef.new()
	storm.id = "night_thunder"
	storm.display_name = "Test Circuit — Night Storm"
	storm.track_scene = "res://assets/tracks/test/baked_track.tscn"
	storm.race_type = "circuit"
	storm.laps = 3
	storm.class_low = "C"             # field band: a tougher C–A night circuit
	storm.class_high = "A"
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

	# Sprint: a single point-to-point stage (A→B) on the point-to-point baked track. laps is ignored.
	var sprint := RaceDef.new()
	sprint.id = "test_sprint"
	sprint.display_name = "Coast Run — Sprint"
	sprint.track_scene = "res://assets/tracks/track 1/baked_track.tscn"
	sprint.race_type = "sprint"
	sprint.class_low = "D"            # field band: D–C sprint
	sprint.class_high = "C"
	sprint.lighting = load("res://assets/lighting/golden.tres")
	sprint.weather = load("res://assets/weather/clear.tres")
	ResourceSaver.save(sprint, dir + "test_sprint.tres")

	# Endurance: a long-form lap race with the largest field (8). Same finish as a circuit (RaceDef.laps
	# on a loop); attrition is deferred to the damage system (code-vehicle-damage), not a bespoke rule.
	# Real endurance races author more laps; this test stays short (4) so it's quick to drive-check.
	var endur := RaceDef.new()
	endur.id = "test_endurance"
	endur.display_name = "Test Circuit — Endurance"
	endur.track_scene = "res://assets/tracks/test/baked_track.tscn"   # loop
	endur.race_type = "endurance"
	endur.laps = 4
	endur.class_low = "C"            # field band: a demanding C–A long race
	endur.class_high = "A"
	endur.lighting = load("res://assets/lighting/golden.tres")
	endur.weather = load("res://assets/weather/clear.tres")
	ResourceSaver.save(endur, dir + "test_endurance.tres")

	# Grand prix: the two-session type (qualify → grid → race). Class-GATED (C+), and its field is built
	# by GrandPrix from the gate band, not RaceField — so class_low/high are left unset here. A loop, so
	# the finish counts RaceDef.laps like a circuit. Kept short (3) for quick drive-checks.
	var gp := RaceDef.new()
	gp.id = "test_grandprix"
	gp.display_name = "Test Circuit — Grand Prix"
	gp.track_scene = "res://assets/tracks/test/baked_track.tscn"   # loop
	gp.race_type = "grand_prix"
	gp.laps = 3
	gp.car_class = "C"                # class gate: a C-or-better car is required to enter
	gp.lighting = load("res://assets/lighting/golden.tres")
	gp.weather = load("res://assets/weather/clear.tres")
	ResourceSaver.save(gp, dir + "test_grandprix.tres")

	# test_timetrial has no field, so it authors no band.
	print("race defs: 6")
	quit()
