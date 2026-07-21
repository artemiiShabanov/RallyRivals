extends Node3D
## Drive-verify harness for TrackBaker output. Instances the baked track at runtime, drops the
## production car at StartFinish facing along the TrackPath, and adds a chase camera. Not the
## polished M1 track (that's code-track-test-track) — just a place to F6 and feel the surfaces.
## Bake first: godot --headless --script res://scripts/track/bake_track_cli.gd

@export var baked_scene_path := "res://assets/tracks/track 1/baked_track.tscn"
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")
@export var race: RaceDef                ## optional: overrides the track + applies conditions

func _ready() -> void:
	var scene_path := baked_scene_path
	if race != null and race.track_scene != "":
		scene_path = race.track_scene
	var ps := load(scene_path) as PackedScene
	if ps == null:
		push_warning("No baked track at %s — run bake_track_cli.gd first." % scene_path)
		return
	var track := ps.instantiate()
	add_child(track)

	# Venue ambience ("world" layer). Weather lays its own bed over this via WeatherFX.
	var bed := AmbientBed.find_or_create(get_tree())
	if bed != null:
		var venue: AmbientDef = race.ambience if race != null and race.ambience != null \
			else load("res://assets/audio/ambient/festival_crowd.tres") as AmbientDef
		bed.set_layer("world", venue)

	# Per-race conditions (code-track-conditions): fixed time-of-day + weather from the RaceDef.
	if race != null:
		if race.lighting != null:
			race.lighting.apply_in(track)
		if race.weather != null:
			var fx := WeatherFX.new()
			fx.name = "WeatherFX"
			add_child(fx)
			fx.apply(race.weather)

	# Checkpoint + timing debug: gate passes, lap times, stage time (cut a corner -> no lap).
	var cps := track.get_node_or_null("Checkpoints") as TrackCheckpoints
	var timing: RaceTiming = null
	if cps != null:
		var cp_sfx := load("res://assets/audio/sfx/checkpoint.tres") as SfxDef
		cps.gate_passed.connect(func(body: Node3D, index: int, total: int) -> void:
			Sfx.play_at(cp_sfx, body.global_position)
			print("checkpoint %d/%d — %s" % [index, total, body.name]))
		timing = RaceTiming.new()
		timing.name = "RaceTiming"
		add_child(timing)
		timing.setup(cps)
		var lap_best_sfx := load("res://assets/audio/sfx/lap_best.tres") as SfxDef
		var finish_sfx := load("res://assets/audio/sfx/finish_win.tres") as SfxDef
		timing.lap_completed.connect(func(body: Node3D, t: float, n: int, best: bool) -> void:
			print("LAP %d — %s: %.3f s%s" % [n, body.name, t, "  (best)" if best else ""])
			if best and lap_best_sfx != null:
				Sfx.play(lap_best_sfx))
		timing.stage_completed.connect(func(body: Node3D, t: float) -> void:
			print("STAGE FINISH — %s: %.3f s" % [body.name, t])
			if finish_sfx != null:
				Sfx.play(finish_sfx)
			# Cut the engine at the finish — the wind-down cue plus every loop out.
			var ca := body.get_node_or_null("CarAudio") as CarAudio
			if ca != null:
				ca.shut_down())
		timing.begin()

	var start := track.get_node_or_null("StartFinish") as Marker3D
	var path := track.get_node_or_null("TrackPath") as Path3D
	var spawn := (start.global_position if start else Vector3.ZERO) + Vector3.UP * 1.5
	# Face along the first segment of the extracted spline (car drives toward +Z).
	var fwd := Vector3.FORWARD
	if path != null and path.curve != null and path.curve.point_count > 1:
		var f := path.curve.get_point_position(1) - path.curve.get_point_position(0)
		f.y = 0.0
		if f.length() > 0.01:
			fwd = f.normalized()
	var right := Vector3.UP.cross(fwd).normalized()

	var car := car_scene.instantiate() as Node3D
	car.name = "Car"
	car.transform = Transform3D(Basis(right, Vector3.UP, fwd), spawn)
	add_child(car)

	var cam := ChaseCamera.new()
	cam.name = "ChaseCamera"
	cam.target_path = NodePath("../Car")
	add_child(cam)
	cam.current = true

	# HUD (code-ui-hud): speed / time / lap / split. Needs the car + timing, so it's built last.
	if cps != null and timing != null:
		var hud := RaceHud.new()
		hud.name = "RaceHud"
		add_child(hud)
		var laps_total: int = race.laps if race != null else 3
		hud.bind(car as VehicleController, timing, cps, laps_total)
