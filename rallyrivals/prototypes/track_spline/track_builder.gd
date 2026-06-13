extends Node3D
## ADR-002 Spike — HEIGHTMAP-CARVE track. THROWAWAY prototype.
## The whole ground is ONE heightmap mesh. The road is carved into it along a spline (the
## corridor is flattened to the road height, ramping out to natural hills), and the road
## surface is shown with per-vertex colour (a stand-in for a splat map).
## Because it's a single body, grip is POSITION-based (distance to the spline -> surface zone),
## not per-contact-body meta — that's the heightmap-carve trade-off.

@export var checkpoint_spacing := 30.0
@export var road_half_width := 6.0
@export var shoulder := 10.0          ## metres the carve ramps from road edge to natural ground
@export var grid_step := 5.0          ## heightmap resolution (smaller = crisper road, more verts)
@export var terrain_amplitude := 9.0
@export var off_road_grip := 5.0
@export var rear_grip_ratio := 0.7
@export var handbrake_rear_ratio := 0.2

@onready var _path: Path3D = $TrackPath
@onready var _checkpoints: Node3D = $Checkpoints

var _curve: Curve3D
var _length := 0.0
var _car_wheels: Array[VehicleWheel3D] = []

# Surface zones by fraction of track length: [start, end, name, grip_slip, colour].
var _zones := [
	[0.00, 0.25, "asphalt", 10.5, Color(0.18, 0.18, 0.20)],
	[0.25, 0.45, "dirt",     6.0, Color(0.45, 0.30, 0.16)],
	[0.45, 0.58, "ice",      3.0, Color(0.82, 0.90, 0.96)],
	[0.58, 0.80, "asphalt", 10.5, Color(0.18, 0.18, 0.20)],
	[0.80, 1.01, "dirt",     6.0, Color(0.45, 0.30, 0.16)],
]
var _off_road_colour := Color(0.28, 0.40, 0.20)

func _ready() -> void:
	process_physics_priority = 100   # apply grip AFTER the car script so our surface grip wins
	_curve = _make_loop()
	_length = _curve.get_baked_length()
	_path.curve = _curve
	_build_ground(_curve)
	_place_checkpoints(_curve)
	for c in ($Car as Node3D).get_children():
		if c is VehicleWheel3D:
			_car_wheels.append(c)
	print("ADR-002 heightmap spike: length=", roundf(_length), "m")

# Closed loop with elevation; Catmull-Rom-ish handles + closing point.
func _make_loop() -> Curve3D:
	var positions := [
		Vector3(0, 0, 70), Vector3(55, 8, 55), Vector3(100, 0, 70),
		Vector3(120, 8, 55), Vector3(130, 6, 70), Vector3(160, -5, 55),
		Vector3(170, 0, 70), Vector3(255, 0, 5),
	]
	var curve := Curve3D.new()
	var n := positions.size()
	for i in n:
		var prev: Vector3 = positions[(i - 1 + n) % n]
		var next: Vector3 = positions[(i + 1) % n]
		var t: Vector3 = (next - prev) * 0.18
		curve.add_point(positions[i], -t, t)
	var t0: Vector3 = (positions[1] - positions[n - 1]) * 0.18
	curve.add_point(positions[0], -t0, t0)
	return curve

func _zone_at(frac: float) -> int:
	for i in _zones.size():
		if frac >= _zones[i][0] and frac < _zones[i][1]:
			return i
	return _zones.size() - 1

# One heightmap mesh: natural hills, with the road corridor carved flat and coloured.
func _build_ground(curve: Curve3D) -> void:
	# Centreline samples carry (position, baked offset).
	var center := []
	var s := 0.0
	while s < _length:
		center.append([curve.sample_baked(s), s])
		s += 3.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for e in center:
		var p: Vector3 = e[0]
		lo.x = minf(lo.x, p.x); lo.y = minf(lo.y, p.z)
		hi.x = maxf(hi.x, p.x); hi.y = maxf(hi.y, p.z)
	var margin := shoulder + 30.0
	lo -= Vector2(margin, margin)
	hi += Vector2(margin, margin)
	var cols := int((hi.x - lo.x) / grid_step) + 1
	var rows := int((hi.y - lo.y) / grid_step) + 1
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.008
	var hw := road_half_width
	var blend := hw + shoulder
	# Per-vertex height + colour.
	var hgt := []
	var col := []
	hgt.resize(rows)
	col.resize(rows)
	for r in rows:
		var hrow := PackedFloat32Array(); hrow.resize(cols)
		var crow := PackedColorArray(); crow.resize(cols)
		for c in cols:
			var x := lo.x + c * grid_step
			var z := lo.y + r * grid_step
			var best := INF
			var road_h := 0.0
			var road_off := 0.0
			for e in center:
				var p: Vector3 = e[0]
				var d2: float = (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
				if d2 < best:
					best = d2; road_h = p.y; road_off = e[1]
			var dist := sqrt(best)
			var natural := noise.get_noise_2d(x, z) * terrain_amplitude
			if dist <= hw:
				hrow[c] = road_h
				crow[c] = _zones[_zone_at(road_off / _length)][4]
			elif dist <= blend:
				var t := (dist - hw) / (blend - hw)
				t = t * t * (3.0 - 2.0 * t)
				hrow[c] = lerpf(road_h, natural, t)
				crow[c] = _off_road_colour
			else:
				hrow[c] = natural
				crow[c] = _off_road_colour
		hgt[r] = hrow
		col[r] = crow
	# Build coloured mesh + collision.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := PackedVector3Array()
	for r in rows - 1:
		for c in cols - 1:
			var x0 := lo.x + c * grid_step
			var x1 := x0 + grid_step
			var z0 := lo.y + r * grid_step
			var z1 := z0 + grid_step
			var v00 := Vector3(x0, hgt[r][c], z0)
			var v10 := Vector3(x1, hgt[r][c + 1], z0)
			var v01 := Vector3(x0, hgt[r + 1][c], z1)
			var v11 := Vector3(x1, hgt[r + 1][c + 1], z1)
			var c00: Color = col[r][c]
			var c10: Color = col[r][c + 1]
			var c01: Color = col[r + 1][c]
			var c11: Color = col[r + 1][c + 1]
			var n00 := _hmap_normal(hgt, r, c, rows, cols)
			var n10 := _hmap_normal(hgt, r, c + 1, rows, cols)
			var n01 := _hmap_normal(hgt, r + 1, c, rows, cols)
			var n11 := _hmap_normal(hgt, r + 1, c + 1, rows, cols)
			_tri(st, tris, v00, c00, n00, v01, c01, n01, v11, c11, n11)
			_tri(st, tris, v00, c00, n00, v11, c11, n11, v10, c10, n10)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # single-layer ground: draw both sides
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(tris)
	var cshape := CollisionShape3D.new()
	cshape.shape = shape
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.add_child(mi)
	body.add_child(cshape)
	add_child(body)

func _tri(st: SurfaceTool, tris: PackedVector3Array, a: Vector3, ca: Color, na: Vector3, b: Vector3, cb: Color, nb: Vector3, c: Vector3, cc: Color, nc: Vector3) -> void:
	st.set_color(ca); st.set_normal(na); st.add_vertex(a)
	st.set_color(cb); st.set_normal(nb); st.add_vertex(b)
	st.set_color(cc); st.set_normal(nc); st.add_vertex(c)
	tris.append_array([a, b, c])

# Upward normal from neighbouring heightmap cells (always points +Y, so lighting reads correctly).
func _hmap_normal(hgt: Array, r: int, c: int, rows: int, cols: int) -> Vector3:
	var hl: float = hgt[r][maxi(c - 1, 0)]
	var hr: float = hgt[r][mini(c + 1, cols - 1)]
	var hd: float = hgt[maxi(r - 1, 0)][c]
	var hu: float = hgt[mini(r + 1, rows - 1)][c]
	return Vector3(hl - hr, 2.0 * grid_step, hd - hu).normalized()

func _place_checkpoints(curve: Curve3D) -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3(road_half_width * 2.0 + 2.0, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1)
	var off := 0.0
	while off < _length:
		var pos := curve.sample_baked(off)
		var ahead := curve.sample_baked(fmod(off + 1.0, _length))
		var fwd := ahead - pos
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var right := fwd.cross(Vector3.UP).normalized()
		var gate := MeshInstance3D.new()
		gate.mesh = bar
		gate.material_override = mat
		gate.transform = Transform3D(Basis(right, Vector3.UP, -fwd), pos + Vector3.UP * 2.0)
		_checkpoints.add_child(gate)
		off += checkpoint_spacing

# Position-based per-wheel grip: nearest point on the spline decides road-vs-offroad + surface.
func _physics_process(_dt: float) -> void:
	if _car_wheels.is_empty():
		return
	var handbraking := Input.is_action_pressed("handbrake")
	for w in _car_wheels:
		var wp := w.global_position
		var off := _curve.get_closest_offset(wp)
		var cp := _curve.sample_baked(off)
		var d := Vector2(wp.x - cp.x, wp.z - cp.z).length()
		var base := off_road_grip
		if d <= road_half_width:
			base = float(_zones[_zone_at(off / _length)][3])
		var is_front: bool = w.use_as_steering
		var s := base if is_front else base * rear_grip_ratio
		if handbraking and not is_front:
			s = base * handbrake_rear_ratio
		w.wheel_friction_slip = s
