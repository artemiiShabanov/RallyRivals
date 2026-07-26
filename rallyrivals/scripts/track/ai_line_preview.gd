extends Node3D
## AI-line test bed (code-track-ai-line). Instances a baked track and overlays its two splines so
## you can eyeball the racing line the baker computed:
##   - TrackPath (road centreline)  -> dim white ribbon
##   - AiLine    (baked racing line) -> bright orange ribbon, cutting the apexes inside the road
## Drops the production car at the start on the racing line with a chase camera; press C to pop to a
## top-down overview of the whole track (the clearest way to judge apex-cutting), C again to drive.
## Bake first: godot --headless --script res://scripts/track/bake_track_cli.gd -- "<track folder>"
## This is the seed of the AI test scene — code-ai-rival will drive a rival along AiLine here.

@export var baked_scene_path := "res://assets/tracks/test/baked_track.tscn"
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")

var _chase: ChaseCamera
var _overview: Camera3D
var _top := false

func _ready() -> void:
	var ps := load(baked_scene_path) as PackedScene
	if ps == null:
		push_warning("No baked track at %s — run bake_track_cli.gd first." % baked_scene_path)
		return
	var track := ps.instantiate()
	add_child(track)

	var centre := track.get_node_or_null("TrackPath") as Path3D
	var ai := track.get_node_or_null("AiLine") as Path3D
	if centre != null:
		track.add_child(_ribbon(centre.curve, Color(0.85, 0.85, 0.85, 0.45), 0.6, 0.30))
	if ai != null:
		track.add_child(_ribbon(ai.curve, Color(1.0, 0.55, 0.1, 0.9), 1.0, 0.40))

	# Car at the start, faced along the racing line's first segment (start it ON the line).
	var start := track.get_node_or_null("StartFinish") as Marker3D
	var lead := ai if ai != null else centre
	var spawn := (start.global_position if start else Vector3.ZERO) + Vector3.UP * 1.5
	var fwd := Vector3.FORWARD
	if lead != null and lead.curve != null and lead.curve.point_count > 1:
		var f := lead.curve.get_point_position(1) - lead.curve.get_point_position(0)
		f.y = 0.0
		if f.length() > 0.01:
			fwd = f.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	var car := car_scene.instantiate() as Node3D
	car.name = "Car"
	car.transform = Transform3D(Basis(right, Vector3.UP, fwd), spawn)
	add_child(car)

	_chase = ChaseCamera.new()
	_chase.name = "ChaseCamera"
	_chase.target_path = NodePath("../Car")
	add_child(_chase)
	_chase.current = true

	_overview = _make_overview(track)
	add_child(_overview)

	var vhs := VHSFilter.new()
	vhs.name = "VHSFilter"
	add_child(vhs)
	print("AI-line preview: white = centreline, orange = racing line. Drive with WASD; press C for a top-down overview.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_top = not _top
		if _top:
			_overview.current = true
		else:
			_chase.current = true

# A flat coloured band laid along a curve, lifted just off the road so it reads without z-fighting.
func _ribbon(curve: Curve3D, col: Color, width: float, lift: float) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = col
	var pts := curve.get_baked_points()
	var hw := width * 0.5
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for i in range(pts.size() - 1):
		var a := pts[i]; var b := pts[i + 1]
		var f := b - a; f.y = 0.0
		if f.length() < 0.0001:
			continue
		var l := Vector3.UP.cross(f.normalized()).normalized() * hw
		var up := Vector3.UP * lift
		var a0 := a + l + up; var a1 := a - l + up
		var b0 := b + l + up; var b1 := b - l + up
		for v in [a0, a1, b0, b0, a1, b1]:
			im.surface_add_vertex(v)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "Ribbon"
	mi.mesh = im
	return mi

# A camera high above the track centre looking down, framed on the ground's bounds.
func _make_overview(track: Node3D) -> Camera3D:
	var aabb := AABB()
	var first := true
	for mi in track.find_children("Mesh_*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		if first:
			aabb = b; first = false
		else:
			aabb = aabb.merge(b)
	var cam := Camera3D.new()
	cam.name = "Overview"
	var centre := aabb.get_center()
	var span := maxf(aabb.size.x, aabb.size.z)
	var eye := centre + Vector3(0, span * 0.9, span * 0.15)
	cam.look_at_from_position(eye, centre, Vector3.FORWARD)   # not in-tree yet, so not look_at()
	cam.far = span * 4.0
	return cam
