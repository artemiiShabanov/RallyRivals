extends Node3D
## Drive-verify harness for TrackBaker output. Instances the baked track at runtime, drops the
## production car at StartFinish facing along the TrackPath, and adds a chase camera. Not the
## polished M1 track (that's code-track-test-track) — just a place to F6 and feel the surfaces.
## Bake first: godot --headless --script res://scripts/track/bake_track_cli.gd

@export var baked_scene_path := "res://assets/tracks/track 1/baked_track.tscn"
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")

func _ready() -> void:
	var ps := load(baked_scene_path) as PackedScene
	if ps == null:
		push_warning("No baked track at %s — run bake_track_cli.gd first." % baked_scene_path)
		return
	var track := ps.instantiate()
	add_child(track)

	# Checkpoint + timing debug: gate passes, lap times, stage time (cut a corner -> no lap).
	var cps := track.get_node_or_null("Checkpoints") as TrackCheckpoints
	if cps != null:
		cps.gate_passed.connect(func(body: Node3D, index: int, total: int) -> void:
			print("checkpoint %d/%d — %s" % [index, total, body.name]))
		var timing := RaceTiming.new()
		timing.name = "RaceTiming"
		add_child(timing)
		timing.setup(cps)
		timing.lap_completed.connect(func(body: Node3D, t: float, n: int, best: bool) -> void:
			print("LAP %d — %s: %.3f s%s" % [n, body.name, t, "  (best)" if best else ""]))
		timing.stage_completed.connect(func(body: Node3D, t: float) -> void:
			print("STAGE FINISH — %s: %.3f s" % [body.name, t]))
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
