extends Node3D
## AI rival test bed (code-ai-rival). A player car and an AI rival line up side by side on a baked
## track; the rival drives the baked AiLine via RivalDriver. Drive with WASD; press C to cycle the
## camera (you → rival → top-down overview). A small readout shows each car's speed + next gate so
## you can see who's ahead. This is the hands-on companion to the headless drive checks; the polished
## race (grid, countdown, standings) is race_director's job — this stays a bare AI proving ground.

@export var baked_scene_path := "res://assets/tracks/test/baked_track.tscn"
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")

var _cams: Array[Camera3D] = []
var _cam_i := 0
var _player: VehicleController
var _rival: VehicleController
var _driver: RivalDriver
var _cps: TrackCheckpoints
var _label: Label

func _ready() -> void:
	var ps := load(baked_scene_path) as PackedScene
	if ps == null:
		push_warning("No baked track at %s — run bake_track_cli.gd first." % baked_scene_path)
		return
	var track := ps.instantiate()
	add_child(track)

	var ai := track.get_node_or_null("AiLine") as Path3D
	_cps = track.get_node_or_null("Checkpoints") as TrackCheckpoints
	var loop: bool = _cps.loop if _cps != null else true

	# Start frame: forward along the line, right perpendicular to it.
	var start := track.get_node_or_null("StartFinish") as Marker3D
	var lead := ai if ai != null else track.get_node_or_null("TrackPath") as Path3D
	var base := start.global_position if start != null else Vector3.ZERO
	var fwd := Vector3.FORWARD
	if lead != null and lead.curve != null and lead.curve.point_count > 1:
		var f := lead.curve.get_point_position(1) - lead.curve.get_point_position(0)
		f.y = 0.0
		if f.length() > 0.01:
			fwd = f.normalized()
	var right := Vector3.UP.cross(fwd).normalized()

	# Side by side, offset off the line so neither starts buried in the other.
	_player = _spawn_car(base + right * -1.9 + Vector3.UP * 1.5, fwd, right, "Player")
	_rival = _spawn_car(base + right * 1.9 + Vector3.UP * 1.5, fwd, right, "Rival")
	if ai != null:
		_driver = RivalDriver.new(ai, loop)
		_rival.driver = _driver
	else:
		push_warning("Baked track has no AiLine — the rival will just sit there. Re-bake with the current TrackBaker.")

	# Cameras: chase you, chase the rival, top-down overview. C cycles.
	_cams.append(_chase(_player, "You"))
	_cams.append(_chase(_rival, "Rival"))
	_cams.append(_overview(track))
	for c in _cams:
		add_child(c)
	_cams[0].current = true

	if _cps != null:
		_cps.gate_passed.connect(func(body: Node3D, i: int, n: int) -> void:
			print("%s — gate %d/%d" % [body.name, i, n]))

	var vhs := VHSFilter.new()
	vhs.name = "VHSFilter"
	add_child(vhs)
	_label = _make_readout()
	print("AI rival test: you (WASD) vs the rival driving the racing line. C = cycle camera.")

func _spawn_car(pos: Vector3, fwd: Vector3, right: Vector3, nm: String) -> VehicleController:
	var car := car_scene.instantiate() as VehicleController
	car.name = nm
	car.transform = Transform3D(Basis(right, Vector3.UP, fwd), pos)
	add_child(car)
	return car

func _chase(car: Node3D, nm: String) -> ChaseCamera:
	var cam := ChaseCamera.new()
	cam.name = nm + "Cam"
	cam.target_path = NodePath("../" + car.name)
	return cam

func _overview(track: Node3D) -> Camera3D:
	var aabb := AABB()
	var first := true
	for mi in track.find_children("Mesh_*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	var cam := Camera3D.new()
	cam.name = "OverviewCam"
	var centre := aabb.get_center()
	var span := maxf(aabb.size.x, aabb.size.z)
	cam.look_at_from_position(centre + Vector3(0, span * 0.9, span * 0.15), centre, Vector3.FORWARD)
	cam.far = span * 4.0
	return cam

func _make_readout() -> Label:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	add_child(layer)
	var lbl := Label.new()
	lbl.position = Vector2(16, 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	layer.add_child(lbl)
	return lbl

func _process(_delta: float) -> void:
	if _label == null:
		return
	_label.text = "%s\n%s\n[C] camera: %s" % [_row("You", _player), _row("Rival", _rival), _cams[_cam_i].name]

func _row(tag: String, car: VehicleController) -> String:
	var kmh := int(round(absf(car.get_forward_speed()) * 3.6))
	if _cps == null:
		return "%s  %d km/h" % [tag, kmh]
	return "%s  %d km/h  next gate %d/%d" % [tag, kmh, _cps.next_gate(car), _cps.gate_count()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_cams[_cam_i].current = false
		_cam_i = (_cam_i + 1) % _cams.size()
		_cams[_cam_i].current = true
