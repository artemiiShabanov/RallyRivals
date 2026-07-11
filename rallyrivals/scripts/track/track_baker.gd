class_name TrackBaker
extends RefCounted
## Bakes a static track scene from 3 authored images (ADR-002 image-driven pipeline).
## Reads a float heightmap (EXR), a surface/splat map (PNG), and a markers map (PNG); writes a
## static .tscn with the carved ground (one StaticBody3D PER SURFACE, tagged with its SurfaceType
## so the shipped VehicleController._surface_grip() reads grip from get_meta("surface")), a rough
## auto-extracted Path3D (hand-tune it in the editor!), a start marker, and placeholder props.
##
## Set the config vars, then call bake(). Runs headless (bake_track_cli.gd) today; the in-editor
## @tool button is code-track-bake-tool. Scheduled ADR-002 deltas: HeightMapShape3D collision and
## splat textures (this bakes a trimesh + vertex-colour gray-box).

# --- config (set before bake()) ---
var src_dir := ""                       ## folder holding heightmap.exr / surface.png / markers.png
var out_scene := ""                     ## path to write the baked .tscn (its dir also holds the .res)
var mpp := 1.0                          ## metres per pixel (image precision)
var max_height := 28.0                  ## heightmap R=1.0 maps to this many metres
var mesh_res := 1.0                     ## mesh quad size in metres — decoupled from image res
var surfaces: Array = []                ## Array[SurfaceType] road palette (asphalt, dirt, ice, ...)
var off_road_surface: SurfaceType = null ## surface for everything off the road (grass/sand)

# Marker colours (semantic pixels in markers.png).
const M_START := Color(1, 0, 1)
const M_DIR := Color(1, 1, 0)
const M_TREE := Color(1, 0, 0)
const M_ROCK := Color(0, 0, 1)

var _hm: Image
var _sf: Image
var _mk: Image
var _size := 0
var _out_dir := ""

# ---------- entry ----------
func bake() -> Error:
	if off_road_surface == null or surfaces.is_empty():
		push_error("TrackBaker: set surfaces + off_road_surface"); return ERR_INVALID_PARAMETER
	_hm = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("heightmap.exr")))
	_sf = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("surface.png")))
	_mk = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("markers.png")))
	if _hm == null or _sf == null or _mk == null:
		push_error("TrackBaker: missing images in " + src_dir); return ERR_FILE_NOT_FOUND
	_size = _hm.get_width()
	_out_dir = out_scene.get_base_dir()

	var root := Node3D.new()
	root.name = "Track"
	_add_environment(root)
	var counts := _add_ground(root)
	var spline_pts := _extract_spline()
	_add_path(root, spline_pts)
	_add_markers(root)

	_own_all(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out_scene)
	print("bake: size=", _size, " spline_pts=", spline_pts.size(), " surfaces=", counts, " save_err=", err)
	return err

# ---------- world / image helpers ----------
func _height(px: int, py: int) -> float:
	return _hm.get_pixel(clampi(px, 0, _size - 1), clampi(py, 0, _size - 1)).r * max_height

func _height_bilinear(fx: float, fy: float) -> float:
	var x0 := int(floor(fx)); var y0 := int(floor(fy))
	var tx := fx - x0; var ty := fy - y0
	var h00 := _height(x0, y0); var h10 := _height(x0 + 1, y0)
	var h01 := _height(x0, y0 + 1); var h11 := _height(x0 + 1, y0 + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)

func _worldf(fx: float, fy: float) -> Vector3:
	return Vector3((fx - _size * 0.5) * mpp, _height_bilinear(fx, fy), (fy - _size * 0.5) * mpp)

func _world(px: int, py: int) -> Vector3:
	return Vector3((px - _size * 0.5) * mpp, _height(px, py), (py - _size * 0.5) * mpp)

func _normalf(fx: float, fy: float) -> Vector3:
	var e := mesh_res / mpp
	var hl := _height_bilinear(fx - e, fy); var hr := _height_bilinear(fx + e, fy)
	var hd := _height_bilinear(fx, fy - e); var hu := _height_bilinear(fx, fy + e)
	return Vector3(hl - hr, 2.0 * mesh_res, hd - hu).normalized()

func _surface_colour(px: int, py: int) -> Color:
	return _sf.get_pixel(clampi(px, 0, _size - 1), clampi(py, 0, _size - 1))

# Bilinear surface colour — anti-aliases the road/off-road boundary in the VISUAL mesh.
# (Grip stays crisp: triangles are bucketed by nearest-palette classification, below.)
func _surface_bilinear(fx: float, fy: float) -> Color:
	var x0 := int(floor(fx)); var y0 := int(floor(fy))
	var tx := fx - x0; var ty := fy - y0
	var c00 := _surface_colour(x0, y0); var c10 := _surface_colour(x0 + 1, y0)
	var c01 := _surface_colour(x0, y0 + 1); var c11 := _surface_colour(x0 + 1, y0 + 1)
	return c00.lerp(c10, tx).lerp(c01.lerp(c11, tx), ty)

func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

# Nearest SurfaceType by colour — the whole palette is the SurfaceType.color set (single source
# of truth). Off-road is just another entry, so is_road = (classify != off_road_surface).
func _classify(col: Color) -> SurfaceType:
	var best := INF
	var pick: SurfaceType = off_road_surface
	for s in surfaces:
		var d := _cdist(col, s.color)
		if d < best:
			best = d; pick = s
	if _cdist(col, off_road_surface.color) < best:
		pick = off_road_surface
	return pick

func _is_road(p: Vector2) -> bool:
	var x := int(round(p.x)); var y := int(round(p.y))
	if x < 0 or y < 0 or x >= _size or y >= _size:
		return false
	return _classify(_sf.get_pixel(x, y)) != off_road_surface

# ---------- ground (per-surface bucketed) ----------
# One StaticBody3D per SurfaceType. Every triangle is classified by its centroid pixel and emitted
# into that surface's bucket; buckets share vertex positions, so the ground stays seamless.
func _add_ground(root: Node3D) -> Dictionary:
	# bucket id -> {surface, st, tris}
	var buckets := {}
	var stepf := mesh_res / mpp
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
			# Triangle A (v00, v01, v11), Triangle B (v00, v11, v10). Classify by centroid pixel.
			_emit(buckets, _bucket_at(fx0, fy1, fx1),  v00, c00, n00, v01, c01, n01, v11, c11, n11)
			_emit(buckets, _bucket_at(fx0, fy0, fx1),  v00, c00, n00, v11, c11, n11, v10, c10, n10)

	var counts := {}
	for id in buckets:
		var b: Dictionary = buckets[id]
		var s: SurfaceType = b["surface"]
		var st: SurfaceTool = b["st"]
		var tris: PackedVector3Array = b["tris"]
		st.index()
		var mesh := st.commit()
		ResourceSaver.save(mesh, _out_dir.path_join("ground_%s_mesh.res" % id))
		mesh.take_over_path(_out_dir.path_join("ground_%s_mesh.res" % id))
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(tris)
		ResourceSaver.save(shape, _out_dir.path_join("ground_%s_shape.res" % id))
		shape.take_over_path(_out_dir.path_join("ground_%s_shape.res" % id))
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var body := StaticBody3D.new(); body.name = "Ground_%s" % id
		body.set_meta("surface", s)   # <-- shipped grip reads this on wheel contact
		var mi := MeshInstance3D.new(); mi.name = "Mesh"; mi.mesh = mesh; mi.material_override = mat
		var cs := CollisionShape3D.new(); cs.name = "Col"; cs.shape = shape
		body.add_child(mi); body.add_child(cs)
		root.add_child(body)
		counts[id] = tris.size() / 3
	return counts

# Classify the triangle whose centroid pixel is the average of its 3 corners' pixel coords.
func _bucket_at(fx_a: float, fy_a: float, fx_b: float) -> SurfaceType:
	# corners passed loosely; sample midpoint of the quad edge span for a stable classification.
	var mx := (fx_a + fx_b) * 0.5
	return _classify(_surface_colour(int(round(mx)), int(round(fy_a))))

func _emit(buckets: Dictionary, s: SurfaceType, a: Vector3, ca: Color, na: Vector3, b: Vector3, cb: Color, nb: Vector3, c: Vector3, cc: Color, nc: Vector3) -> void:
	var id: String = s.id
	if not buckets.has(id):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[id] = {"surface": s, "st": st, "tris": PackedVector3Array()}
	var b0: Dictionary = buckets[id]
	var st: SurfaceTool = b0["st"]
	var tris: PackedVector3Array = b0["tris"]
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
	var keep := PackedVector2Array()
	var stride := maxi(1, int(pts.size() / 24.0))
	for i in range(0, pts.size(), stride):
		keep.append(pts[i])
	var n := keep.size()
	for i in n:
		var p := keep[i]
		var wp := Vector3((p.x - _size * 0.5) * mpp, _height(int(p.x), int(p.y)) + 0.5, (p.y - _size * 0.5) * mpp)
		var pa := keep[(i - 1 + n) % n]; var pb := keep[(i + 1) % n]
		var tan := Vector3((pb.x - pa.x) * mpp, 0, (pb.y - pa.y) * mpp) * 0.18
		curve.add_point(wp, -tan, tan)
	path.curve = curve
	root.add_child(path)

# ---------- markers: start + placeholder props ----------
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

# ---------- environment ----------
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
