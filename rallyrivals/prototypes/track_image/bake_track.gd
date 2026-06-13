extends SceneTree
## ADR-002 — BAKE a track scene from 3 images. THROWAWAY prototype tool.
## Run headless:  godot --headless --script res://prototypes/track_image/bake_track.gd
## Reads heightmap/surface/markers PNGs -> writes baked_track.tscn containing:
##   ground mesh + collision, a rough auto-extracted Path3D (hand-tune it!), start, props, car.

const DIR := "res://prototypes/track_image/"
const MPP := 1.0            # metres per pixel (image precision)
const MAXH := 28.0          # max terrain height (metres)
const MESH_RES := 1.0       # mesh quad size in METRES — independent of image; smaller = finer geometry

const GRASS := Color(0.28, 0.40, 0.20)
const ASPHALT := Color(0.18, 0.18, 0.20)
const DIRT := Color(0.45, 0.30, 0.16)
const ICE := Color(0.82, 0.90, 0.96)
const M_START := Color(1, 0, 1)
const M_DIR := Color(1, 1, 0)
const M_TREE := Color(1, 0, 0)
const M_ROCK := Color(0, 0, 1)

var _hm: Image
var _sf: Image
var _mk: Image
var _size := 0

func _initialize() -> void:
	_hm = Image.load_from_file(ProjectSettings.globalize_path(DIR + "heightmap.exr"))
	_sf = Image.load_from_file(ProjectSettings.globalize_path(DIR + "surface.png"))
	_mk = Image.load_from_file(ProjectSettings.globalize_path(DIR + "markers.png"))
	if _hm == null or _sf == null or _mk == null:
		push_error("missing images"); quit(); return
	_size = _hm.get_width()

	var root := Node3D.new()
	root.name = "Track"
	root.set_script(load(DIR + "track_runtime.gd"))
	root.set("image_size", _size)
	root.set("meters_per_pixel", MPP)

	_add_environment(root)
	_add_ground(root)
	var spline_pts := _extract_spline()
	_add_path(root, spline_pts)
	_add_markers(root)
	_add_car(root, spline_pts)

	# Own every descendant so it serialises into the scene.
	_own_all(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, DIR + "baked_track.tscn")
	print("bake: size=", _size, " spline_pts=", spline_pts.size(), " save_err=", err)
	quit()

# ---------- world / image helpers ----------
func _world(px: int, py: int) -> Vector3:
	return Vector3((px - _size * 0.5) * MPP, _height(px, py), (py - _size * 0.5) * MPP)

func _height(px: int, py: int) -> float:
	return _hm.get_pixel(clampi(px, 0, _size - 1), clampi(py, 0, _size - 1)).r * MAXH

# Bilinear height at fractional pixel coords — smooths geometry between heightmap texels.
func _height_bilinear(fx: float, fy: float) -> float:
	var x0 := int(floor(fx)); var y0 := int(floor(fy))
	var tx := fx - x0; var ty := fy - y0
	var h00 := _height(x0, y0); var h10 := _height(x0 + 1, y0)
	var h01 := _height(x0, y0 + 1); var h11 := _height(x0 + 1, y0 + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)

func _worldf(fx: float, fy: float) -> Vector3:
	return Vector3((fx - _size * 0.5) * MPP, _height_bilinear(fx, fy), (fy - _size * 0.5) * MPP)

func _normalf(fx: float, fy: float) -> Vector3:
	var e := MESH_RES / MPP
	var hl := _height_bilinear(fx - e, fy); var hr := _height_bilinear(fx + e, fy)
	var hd := _height_bilinear(fx, fy - e); var hu := _height_bilinear(fx, fy + e)
	return Vector3(hl - hr, 2.0 * MESH_RES, hd - hu).normalized()

func _surface_colour(px: int, py: int) -> Color:
	return _sf.get_pixel(clampi(px, 0, _size - 1), clampi(py, 0, _size - 1))

# Bilinear surface colour — anti-aliases the road/grass boundary in the VISUAL mesh.
# (Grip stays crisp: track_runtime samples the surface image with nearest-palette separately.)
func _surface_bilinear(fx: float, fy: float) -> Color:
	var x0 := int(floor(fx)); var y0 := int(floor(fy))
	var tx := fx - x0; var ty := fy - y0
	var c00 := _surface_colour(x0, y0); var c10 := _surface_colour(x0 + 1, y0)
	var c01 := _surface_colour(x0, y0 + 1); var c11 := _surface_colour(x0 + 1, y0 + 1)
	return c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)

func _is_road(p: Vector2) -> bool:
	var x := int(round(p.x)); var y := int(round(p.y))
	if x < 0 or y < 0 or x >= _size or y >= _size:
		return false
	return _cdist(_sf.get_pixel(x, y), GRASS) > 0.12

func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _hmap_normal(px: int, py: int) -> Vector3:
	var hl := _height(px - 1, py); var hr := _height(px + 1, py)
	var hd := _height(px, py - 1); var hu := _height(px, py + 1)
	return Vector3(hl - hr, 2.0 * MPP, hd - hu).normalized()

# ---------- ground ----------
func _add_ground(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := PackedVector3Array()
	# Mesh grid is independent of image resolution: sub-pixel step + bilinear height = smooth.
	var stepf := MESH_RES / MPP
	var cells := int((_size - 1) / stepf)
	for r in cells:
		for c in cells:
			var fx0 := c * stepf; var fx1 := (c + 1) * stepf
			var fy0 := r * stepf; var fy1 := (r + 1) * stepf
			var v00 := _worldf(fx0, fy0); var v10 := _worldf(fx1, fy0)
			var v01 := _worldf(fx0, fy1); var v11 := _worldf(fx1, fy1)
			var c00 := _surface_bilinear(fx0, fy0); var c10 := _surface_bilinear(fx1, fy0)
			var c01 := _surface_bilinear(fx0, fy1); var c11 := _surface_bilinear(fx1, fy1)
			var n00 := _normalf(fx0, fy0); var n10 := _normalf(fx1, fy0)
			var n01 := _normalf(fx0, fy1); var n11 := _normalf(fx1, fy1)
			_tri(st, tris, v00, c00, n00, v01, c01, n01, v11, c11, n11)
			_tri(st, tris, v00, c00, n00, v11, c11, n11, v10, c10, n10)
	st.index()   # dedupe shared vertices -> much smaller mesh
	var mesh := st.commit()
	ResourceSaver.save(mesh, DIR + "ground_mesh.res")
	mesh.take_over_path(DIR + "ground_mesh.res")   # reference, don't embed in the .tscn
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(tris)
	ResourceSaver.save(shape, DIR + "ground_shape.res")
	shape.take_over_path(DIR + "ground_shape.res")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := StaticBody3D.new(); body.name = "Ground"
	var mi := MeshInstance3D.new(); mi.name = "Mesh"; mi.mesh = mesh; mi.material_override = mat
	var cs := CollisionShape3D.new(); cs.name = "Col"; cs.shape = shape
	body.add_child(mi); body.add_child(cs)
	root.add_child(body)

func _tri(st: SurfaceTool, tris: PackedVector3Array, a: Vector3, ca: Color, na: Vector3, b: Vector3, cb: Color, nb: Vector3, c: Vector3, cc: Color, nc: Vector3) -> void:
	st.set_color(ca); st.set_normal(na); st.add_vertex(a)
	st.set_color(cb); st.set_normal(nb); st.add_vertex(b)
	st.set_color(cc); st.set_normal(nc); st.add_vertex(c)
	tris.append_array([a, b, c])

# ---------- spline extraction (ant-march the road centreline) ----------
func _find_marker(target: Color) -> Vector2:
	for y in _size:
		for x in _size:
			if _cdist(_mk.get_pixel(x, y), target) < 0.2:
				return Vector2(x, y)
	return Vector2(-1, -1)

func _recenter(p: Vector2, dir: Vector2) -> Vector2:
	var perp := Vector2(-dir.y, dir.x)
	var hi := 0.0; var lo := 0.0
	var t := 1.0
	while t < 26.0 and _is_road(p + perp * t): hi = t; t += 1.0
	t = 1.0
	while t < 26.0 and _is_road(p - perp * t): lo = t; t += 1.0
	return p + perp * ((hi - lo) * 0.5)

func _extract_spline() -> PackedVector2Array:
	var start := _find_marker(M_START)
	var dirpx := _find_marker(M_DIR)
	var pts := PackedVector2Array()
	if start.x < 0:
		return pts
	var dir := (dirpx - start).normalized() if dirpx.x >= 0 else Vector2.RIGHT
	var pos := start
	var step := 4.0
	for _i in 800:
		pos = _recenter(pos, dir)
		pts.append(pos)
		var nxt := pos + dir * step
		if not _is_road(nxt):
			var found := false
			for deg in [15, -15, 30, -30, 45, -45, 60, -60, 80, -80, 100, -100]:
				var nd := dir.rotated(deg_to_rad(deg))
				if _is_road(pos + nd * step):
					dir = nd; nxt = pos + nd * step; found = true; break
			if not found:
				break
		dir = (nxt - pos).normalized()
		pos = nxt
		if pts.size() > 15 and pos.distance_to(start) < step * 1.8:
			break
	return pts

func _add_path(root: Node3D, pts: PackedVector2Array) -> void:
	var path := Path3D.new(); path.name = "TrackPath"
	var curve := Curve3D.new()
	# Decimate for a hand-tunable number of points.
	var keep := PackedVector2Array()
	var stride := maxi(1, int(pts.size() / 24.0))
	for i in range(0, pts.size(), stride):
		keep.append(pts[i])
	var n := keep.size()
	for i in n:
		var p := keep[i]
		var wp := Vector3((p.x - _size * 0.5) * MPP, _height(int(p.x), int(p.y)) + 0.5, (p.y - _size * 0.5) * MPP)
		var pa := keep[(i - 1 + n) % n]; var pb := keep[(i + 1) % n]
		var tan := Vector3((pb.x - pa.x) * MPP, 0, (pb.y - pa.y) * MPP) * 0.18
		curve.add_point(wp, -tan, tan)
	path.curve = curve
	root.add_child(path)

# ---------- markers: start + props ----------
func _add_markers(root: Node3D) -> void:
	var start := _find_marker(M_START)
	if start.x >= 0:
		var m := Marker3D.new(); m.name = "StartFinish"
		m.position = _world(int(start.x), int(start.y)) + Vector3.UP * 0.5
		root.add_child(m)
	var props := Node3D.new(); props.name = "Props"
	root.add_child(props)
	for y in _size:
		for x in _size:
			var c := _mk.get_pixel(x, y)
			if _cdist(c, M_TREE) < 0.2:
				props.add_child(_prop(Vector3(0.6, 4, 0.6), Color(0.2, 0.5, 0.15), x, y))
			elif _cdist(c, M_ROCK) < 0.2:
				props.add_child(_prop(Vector3(1.2, 1.2, 1.2), Color(0.5, 0.5, 0.52), x, y))

func _prop(box_size: Vector3, col: Color, px: int, py: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = box_size
	mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = col
	mi.material_override = mat
	mi.position = _world(px, py) + Vector3.UP * box_size.y * 0.5
	return mi

# ---------- car + camera ----------
func _add_car(root: Node3D, pts: PackedVector2Array) -> void:
	var car := VehicleBody3D.new(); car.name = "Car"; car.mass = 800.0
	car.set_script(load("res://prototypes/physics_vehiclebody/vehicle_body_car.gd"))
	var body := MeshInstance3D.new(); body.name = "Body"
	var bmesh := BoxMesh.new(); bmesh.size = Vector3(2, 1, 4); body.mesh = bmesh
	var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(0.75, 0.18, 0.18)
	body.material_override = bmat
	car.add_child(body)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(2, 1, 4); cs.shape = bs
	car.add_child(cs)
	for wpos in [Vector3(-0.85, -0.5, 1.4), Vector3(0.85, -0.5, 1.4), Vector3(-0.85, -0.5, -1.4), Vector3(0.85, -0.5, -1.4)]:
		var w := VehicleWheel3D.new()
		w.position = wpos
		w.use_as_traction = true
		w.use_as_steering = wpos.z > 0.0
		w.wheel_radius = 0.4
		car.add_child(w)
	# Spawn at the start of the extracted spline, facing along it.
	if pts.size() > 1:
		var p0 := pts[0]; var p1 := pts[1]
		var pos := Vector3((p0.x - _size * 0.5) * MPP, _height(int(p0.x), int(p0.y)) + 1.5, (p0.y - _size * 0.5) * MPP)
		var fwd := Vector3((p1.x - p0.x), 0, (p1.y - p0.y)).normalized()
		var right := Vector3.UP.cross(fwd).normalized()
		car.transform = Transform3D(Basis(right, Vector3.UP, fwd), pos)
	root.add_child(car)
	var cam := Camera3D.new(); cam.name = "ChaseCamera"
	cam.set_script(load("res://prototypes/physics_vehiclebody/chase_camera.gd"))
	cam.set("target_path", NodePath("../Car"))
	root.add_child(cam)

func _add_environment(root: Node3D) -> void:
	var we := WorldEnvironment.new(); we.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root.add_child(sun)

func _own_all(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own_all(child, owner)
