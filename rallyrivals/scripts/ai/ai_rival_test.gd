extends Node3D
## AI rival test bed (code-ai-rival). Lines up a pack — you plus `ai_count` AI rivals — on a baked
## track's starting grid; each rival drives the baked AiLine via its own RivalDriver. Drive with WASD;
## press C to cycle the camera (each car's chase, then a top-down overview). A readout lists every
## car's speed + next gate so you can see the order.
##
## CAVEAT: rivals have no mutual awareness yet — they all track the SAME racing line, so with identical
## settings they'd run nose-to-tail and nudge (no traffic avoidance is built). To keep the pack
## readable here, each AI gets a small corner-pace spread so they string out. That spread is a
## VIEWING CONVENIENCE of this scene, not the real per-opponent tuning (that's code-ai-difficulty).
##
## This is the hands-on companion to the headless drive checks; the polished race (grid, countdown,
## standings) is race_director's job — this stays a bare AI proving ground.

@export var baked_scene_path := "res://assets/tracks/test/baked_track.tscn"
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")
@export var ai_count := 3          ## how many AI rivals to spawn
@export var include_player := true ## also spawn a WASD car on the grid

# demo-only pace spread applied across the AIs (see the CAVEAT above) — NOT code-ai-difficulty
const CORNER_GRIP_LO := 7.8
const CORNER_GRIP_HI := 9.2

var _cams: Array[Camera3D] = []
var _cam_i := 0
var _cars: Array[VehicleController] = []
var _drivers: Array = []           # RivalDriver per car, null for the player
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
	if ai == null:
		push_warning("Baked track has no AiLine — rivals will sit still. Re-bake with the current TrackBaker.")

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

	# Build the grid: optional player on pole, then the AIs. Each gets a staggered 2-wide slot.
	var slot := 0
	if include_player:
		_add_car(_grid_pos(base, fwd, right, slot), fwd, right, "You", null)
		slot += 1
	for k in ai_count:
		var d := RivalDriver.new(ai, loop) if ai != null else null
		if d != null and ai_count > 1:
			# spread corner pace across the field so they don't drive in lockstep (demo convenience)
			d.corner_grip = lerpf(CORNER_GRIP_LO, CORNER_GRIP_HI, float(k) / float(ai_count - 1))
		_add_car(_grid_pos(base, fwd, right, slot), fwd, right, "AI %d" % (k + 1), d)
		slot += 1

	# Cameras: a chase per car, then a top-down overview. C cycles.
	for car in _cars:
		_cams.append(_chase(car))
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
	print("AI pack test: %d AI rival(s)%s. C = cycle camera." % [ai_count, " + you (WASD)" if include_player else ""])

# Staggered 2-wide starting grid, rows marching back along -fwd.
func _grid_pos(base: Vector3, fwd: Vector3, right: Vector3, i: int) -> Vector3:
	var side := -1.9 if i % 2 == 0 else 1.9
	var row := i / 2
	return base + right * side + (-fwd) * (row * 6.0) + Vector3.UP * 1.5

func _add_car(pos: Vector3, fwd: Vector3, right: Vector3, nm: String, drv) -> void:
	var car := car_scene.instantiate() as VehicleController
	car.name = nm
	car.transform = Transform3D(Basis(right, Vector3.UP, fwd), pos)
	add_child(car)
	if drv != null:
		car.driver = drv
	_cars.append(car)
	_drivers.append(drv)

func _chase(car: Node3D) -> ChaseCamera:
	var cam := ChaseCamera.new()
	cam.name = car.name + "Cam"
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
	var lines := PackedStringArray()
	for car in _cars:
		lines.append(_row(car))
	lines.append("[C] camera: %s" % _cams[_cam_i].name)
	_label.text = "\n".join(lines)

func _row(car: VehicleController) -> String:
	var kmh := int(round(absf(car.get_forward_speed()) * 3.6))
	if _cps == null:
		return "%s  %d km/h" % [car.name, kmh]
	return "%s  %d km/h  next gate %d/%d" % [car.name, kmh, _cps.next_gate(car), _cps.gate_count()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_cams[_cam_i].current = false
		_cam_i = (_cam_i + 1) % _cams.size()
		_cams[_cam_i].current = true
