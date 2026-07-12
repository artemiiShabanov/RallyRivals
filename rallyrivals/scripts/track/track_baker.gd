class_name TrackBaker
extends RefCounted
## Bakes a static track scene from 4 authored images (ADR-002 image-driven pipeline).
## Reads a float heightmap (EXR), a surface/splat map (PNG), a markers map (PNG, world props),
## and a race map (PNG, race data: start line + direction + checkpoint gates); writes a static
## .tscn with:
##   - a "Ground" StaticBody3D whose collision is ONE HeightMapShape3D (smooth, cheap), plus one
##     vertex-coloured MeshInstance3D per surface (visuals only). Grip is position-based: the body
##     carries a SurfaceMap (meta "surface_map") the vehicle samples per wheel.
##   - a rough auto-extracted Path3D (hand-tune it in the editor!), ordered "Checkpoints" gates
##     from the authored dot pairs, a start marker, placeholder props.
##
## Set the config vars, then call bake(). Runs headless (bake_track_cli.gd) today; the in-editor
## @tool button is code-track-bake-tool. Scheduled ADR-002 deltas: splat textures (this bakes a
## vertex-colour + stub-texture gray-box). NOTE: the heightfield collision is at IMAGE resolution
## while the visual mesh samples at mesh_res — they coincide only while mesh_res == mpp (both 1 here).

# --- config (set before bake()) ---
var src_dir := ""                       ## folder holding heightmap.exr / surface.png / markers.png / race.png
var out_scene := ""                     ## path to write the baked .tscn (its dir also holds the .res)
var mpp := 1.0                          ## metres per pixel (image precision)
var max_height := 28.0                  ## heightmap R=1.0 maps to this many metres
var mesh_res := 1.0                     ## mesh quad size in metres — decoupled from image res
var surfaces: Array = []                ## Array[SurfaceType] road palette (asphalt, dirt, ice, ...)
var off_road_surface: SurfaceType = null ## surface for everything off the road (grass/sand)
var gate_height := 8.0                  ## checkpoint box height (catches airborne cars)
var gate_depth := 4.0                   ## checkpoint box thickness along travel (no tunnelling at speed)
var path_points := 24                   ## TrackPath control points after decimation (more = closer hand-tune fit on long tracks)

# Race colours (semantic dots in race.png). A dot is any small blob; its centroid is what counts.
# Pairs of dots straddle the road: start pair = the start/finish line (gate 0), each gate pair =
# one checkpoint gate, dot spacing = gate width. Cyan (0,1,1) is reserved for a point-to-point
# FINISH pair (implemented when code-race-types needs sprints).
const R_START := Color(1, 0, 1)
const R_DIR := Color(1, 1, 0)
const R_GATE := Color(0, 1, 0)

# Marker colours (semantic pixels in markers.png — world props only).
const M_TREE := Color(1, 0, 0)
const M_ROCK := Color(0, 0, 1)

var _hm: Image
var _sf: Image
var _mk: Image
var _rc: Image
var _size := 0
var _out_dir := ""

# ---------- entry ----------
func bake() -> Error:
	if off_road_surface == null or surfaces.is_empty():
		push_error("TrackBaker: set surfaces + off_road_surface"); return ERR_INVALID_PARAMETER
	_hm = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("heightmap.exr")))
	_sf = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("surface.png")))
	_mk = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("markers.png")))
	_rc = Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join("race.png")))
	if _hm == null or _sf == null or _mk == null or _rc == null:
		push_error("TrackBaker: missing images in " + src_dir); return ERR_FILE_NOT_FOUND
	_size = _hm.get_width()
	_out_dir = out_scene.get_base_dir()

	var race := _read_race()
	if race.is_empty():
		return ERR_INVALID_DATA

	var root := Node3D.new()
	root.name = "Track"
	_add_environment(root)
	var counts := _add_ground(root)
	var spline_pts := _extract_spline(race["start_mid"], race["dir"])
	var curve := _add_path(root, spline_pts)
	var ngates := _add_checkpoints(root, race, curve)
	_add_markers(root, race["start_mid"])

	_own_all(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out_scene)
	print("bake: size=", _size, " spline_pts=", spline_pts.size(), " gates=", ngates, " surfaces=", counts, " save_err=", err)
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

# Nearest SurfaceType for a fractional pixel, via the shared classifier (same code SurfaceMap uses
# at runtime, so bake-time buckets and drive-time grip agree exactly).
func _surface_of(fx: float, fy: float) -> SurfaceType:
	return SurfaceMap.classify(_surface_colour(int(round(fx)), int(round(fy))), surfaces, off_road_surface)

func _is_road(p: Vector2) -> bool:
	var x := int(round(p.x)); var y := int(round(p.y))
	if x < 0 or y < 0 or x >= _size or y >= _size:
		return false
	return SurfaceMap.classify(_sf.get_pixel(x, y), surfaces, off_road_surface) != off_road_surface

# ---------- ground ----------
# Collision is ONE HeightMapShape3D — a continuous heightfield, so there are no trimesh internal
# edges to catch on (no "ghost collision" bumps) and it's far cheaper. Visuals stay per-surface
# (bucketed meshes, for the textures/colours). Grip: the ground body carries a SurfaceMap
# (meta "surface_map") that the vehicle samples by wheel position — a single collision body can't
# hold a per-body SurfaceType meta the way separate per-surface bodies would.
func _add_ground(root: Node3D) -> Dictionary:
	var ground := StaticBody3D.new(); ground.name = "Ground"

	# --- collision: heightfield from the raw pixel heights ---
	var wsz := _size
	var data := PackedFloat32Array(); data.resize(wsz * wsz)
	for z in wsz:
		for x in wsz:
			data[z * wsz + x] = _height(x, z)
	var hs := HeightMapShape3D.new()
	hs.map_width = wsz; hs.map_depth = wsz; hs.map_data = data
	ResourceSaver.save(hs, _out_dir.path_join("ground_heightfield.res"))
	hs.take_over_path(_out_dir.path_join("ground_heightfield.res"))
	var cs := CollisionShape3D.new(); cs.name = "Col"; cs.shape = hs
	# Heightfield samples are 1 unit apart, centred on origin; scale to mpp and shift half a cell
	# so it lines up with the visual mesh's world mapping (pixel px -> world (px - size/2)*mpp).
	cs.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(mpp, 1.0, mpp)), Vector3(-0.5 * mpp, 0.0, -0.5 * mpp))
	ground.add_child(cs)

	# --- grip: position -> SurfaceType via the surface image ---
	var smap := SurfaceMap.new()
	smap.surface_image_path = src_dir.path_join("surface.png")
	var typed: Array[SurfaceType] = []
	for s in surfaces:
		typed.append(s)
	smap.surfaces = typed
	smap.off_road = off_road_surface
	smap.mpp = mpp
	ground.set_meta("surface_map", smap)

	# --- visual: per-surface bucketed meshes (no collision) ---
	var buckets := {}   # id -> {surface, st, tris}
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
			# Bucket each triangle by the surface at its centroid pixel.
			_emit(buckets, _surface_of((fx0 + fx0 + fx1) / 3.0, (fy0 + fy1 + fy1) / 3.0), v00, c00, n00, v01, c01, n01, v11, c11, n11)
			_emit(buckets, _surface_of((fx0 + fx1 + fx1) / 3.0, (fy0 + fy1 + fy0) / 3.0), v00, c00, n00, v11, c11, n11, v10, c10, n10)

	var counts := {}
	for id in buckets:
		var b: Dictionary = buckets[id]
		var s: SurfaceType = b["surface"]
		var st: SurfaceTool = b["st"]
		st.index()
		var mesh := st.commit()
		ResourceSaver.save(mesh, _out_dir.path_join("ground_%s_mesh.res" % id))
		mesh.take_over_path(_out_dir.path_join("ground_%s_mesh.res" % id))
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true   # keeps the anti-aliased edge blend
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Stub detail, triplanar-tiled x the vertex colour. Prefer the SurfaceType's texture, but
		# fall back to the convention path so a dropped .tres field (editor re-import) can't blank it.
		var tex: Texture2D = s.texture
		if tex == null:
			var conv := "res://assets/surfaces/tex/%s.png" % id
			if ResourceLoader.exists(conv):
				tex = load(conv)
		if tex != null:
			mat.albedo_texture = tex
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.2, 0.2, 0.2)   # ~5 m tile
		var mi := MeshInstance3D.new(); mi.name = "Mesh_%s" % id; mi.mesh = mesh; mi.material_override = mat
		ground.add_child(mi)
		counts[id] = int(b["tris"])   # triangle count (for the bake log)

	root.add_child(ground)
	return counts

# Append one triangle to its surface bucket's mesh (collision is the shared heightfield, so we only
# track a triangle count per bucket, not the geometry).
func _emit(buckets: Dictionary, s: SurfaceType, a: Vector3, ca: Color, na: Vector3, b: Vector3, cb: Color, nb: Vector3, c: Vector3, cc: Color, nc: Vector3) -> void:
	var id: String = s.id
	if not buckets.has(id):
		var new_st := SurfaceTool.new()
		new_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		buckets[id] = {"surface": s, "st": new_st, "tris": 0}
	var b0: Dictionary = buckets[id]
	var st: SurfaceTool = b0["st"]
	st.set_color(ca); st.set_normal(na); st.add_vertex(a)
	st.set_color(cb); st.set_normal(nb); st.add_vertex(b)
	st.set_color(cc); st.set_normal(nc); st.add_vertex(c)
	b0["tris"] = int(b0["tris"]) + 1

# ---------- race layer (race.png): start pair + direction dot + gate pairs ----------
# Centroids of every blob of `target` colour (8-neighbour flood fill, so a hand-painted dot can
# be 1 px or a small blot — its centre is what counts).
func _blobs(img: Image, target: Color) -> Array[Vector2]:
	var seen := {}
	var out: Array[Vector2] = []
	for y in _size:
		for x in _size:
			if seen.has(y * _size + x) or _cdist(img.get_pixel(x, y), target) >= 0.2:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[y * _size + x] = true
			var sum := Vector2.ZERO
			var count := 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				sum += Vector2(p); count += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q := Vector2i(p.x + dx, p.y + dy)
						if q.x < 0 or q.y < 0 or q.x >= _size or q.y >= _size or seen.has(q.y * _size + q.x):
							continue
						if _cdist(img.get_pixel(q.x, q.y), target) < 0.2:
							seen[q.y * _size + q.x] = true
							stack.append(q)
			out.append(sum / count)
	return out

# Greedy nearest-first pairing with a road-crossing check: a valid pair's midpoint must be road,
# which stops two adjacent gates' same-side dots from pairing with each other. Any dot left
# unpaired (or an odd count) is a loud bake error naming the pixel. Returns null on error.
func _pair_dots(dots: Array[Vector2]) -> Variant:
	if dots.size() % 2 != 0:
		push_error("TrackBaker: race.png has an odd number of gate dots (%d) — dots pair into gates" % dots.size())
		return null
	var cand := []
	for i in dots.size():
		for j in range(i + 1, dots.size()):
			cand.append([dots[i].distance_to(dots[j]), i, j])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var used := {}
	var pairs := []
	for c in cand:
		var i: int = c[1]; var j: int = c[2]
		if used.has(i) or used.has(j) or not _is_road((dots[i] + dots[j]) * 0.5):
			continue
		used[i] = true; used[j] = true
		pairs.append([dots[i], dots[j]])
	if used.size() != dots.size():
		for i in dots.size():
			if not used.has(i):
				push_error("TrackBaker: gate dot at pixel (%d, %d) found no partner across the road" % [int(dots[i].x), int(dots[i].y)])
		return null
	return pairs

# Reads race.png -> {start_a, start_b, start_mid, dir, gates}; empty Dictionary on authoring errors.
func _read_race() -> Dictionary:
	var starts := _blobs(_rc, R_START)
	var dirs := _blobs(_rc, R_DIR)
	if starts.size() != 2 or dirs.size() != 1:
		push_error("TrackBaker: race.png needs exactly 2 start dots (magenta) + 1 direction dot (yellow); found %d + %d" % [starts.size(), dirs.size()])
		return {}
	var pairs: Variant = _pair_dots(_blobs(_rc, R_GATE))
	if pairs == null:
		return {}
	var mid := (starts[0] + starts[1]) * 0.5
	return {
		"start_a": starts[0], "start_b": starts[1], "start_mid": mid,
		"dir": (dirs[0] - mid).normalized(),
		"gates": pairs,
	}

# ---------- spline extraction (ant-march the road centreline) ----------
func _recenter(p: Vector2, dir: Vector2) -> Vector2:
	var perp := Vector2(-dir.y, dir.x)
	var hi := 0.0; var lo := 0.0
	var t := 1.0
	while t < 26.0 and _is_road(p + perp * t): hi = t; t += 1.0
	t = 1.0
	while t < 26.0 and _is_road(p - perp * t): lo = t; t += 1.0
	return p + perp * ((hi - lo) * 0.5)

func _extract_spline(start: Vector2, dir: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := start
	var step := 4.0
	var armed := false   # closure check arms once the march has actually left the start area
	for _i in 800:
		pos = _recenter(pos, dir)
		pts.append(pos)
		# Fold the recentring pull into the heading: on a sustained curve the centreline drags
		# each point sideways, and a heading that never absorbs that goes stale, pokes off-road,
		# and the rotation scan (measured from the stale heading) can pick a U-turn.
		if pts.size() > 1:
			var motion := pos - pts[pts.size() - 2]
			if motion.length() > 0.001:
				dir = motion.normalized()
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
		# Loop closure: arm after leaving the start area, close on returning near it. The radius
		# must comfortably beat the march's lateral zigzag or the lap gets doubled.
		if pos.distance_to(start) > step * 6.0:
			armed = true
		elif armed and pos.distance_to(start) < step * 2.5:
			return pts
	# Fell out without closing: a corner sharper than the marcher can follow (it may even have
	# U-turned and retraced). TrackPath and gate ordering are NOT trustworthy — fix the layout.
	push_warning("TrackBaker: spline march did not close the loop (%d pts, ended %.0f px from start)" % [pts.size(), pos.distance_to(start)])
	return pts

func _add_path(root: Node3D, pts: PackedVector2Array) -> Curve3D:
	var path := Path3D.new(); path.name = "TrackPath"
	var curve := Curve3D.new()
	var keep := PackedVector2Array()
	var stride := maxi(1, int(float(pts.size()) / path_points))
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
	return curve

# ---------- checkpoints: authored gate pairs -> ordered Area3D gates ----------
# Order is NOT authored: the start pair is gate 0 and the rest sort by arc-length along the
# extracted spline (the track's direction defines the sequence). Caveat: where two track sections
# run closer together than the road is wide, a midpoint can project onto the wrong section —
# rare, visible in the baked scene, fixed by nudging a dot or hand-moving the baked gate.
func _add_checkpoints(root: Node3D, race: Dictionary, curve: Curve3D) -> int:
	var cps := TrackCheckpoints.new()
	cps.name = "Checkpoints"
	root.add_child(cps)
	var length := curve.get_baked_length()
	var start_off := curve.get_closest_offset(_pair_mid_world(race["start_a"], race["start_b"]))
	var entries := []   # [offset from start line, dot a, dot b]
	for pr in race["gates"]:
		var off: float = curve.get_closest_offset(_pair_mid_world(pr[0], pr[1]))
		entries.append([fposmod(off - start_off, length), pr[0], pr[1]])
	entries.sort_custom(func(a, b): return a[0] < b[0])
	entries.push_front([0.0, race["start_a"], race["start_b"]])
	for i in entries.size():
		cps.add_child(_gate(i, entries[i][1], entries[i][2]))
	return entries.size()

func _pair_mid_world(a: Vector2, b: Vector2) -> Vector3:
	var m := (a + b) * 0.5
	return _worldf(m.x, m.y)

func _gate(idx: int, a: Vector2, b: Vector2) -> CheckpointGate:
	var g := CheckpointGate.new()
	g.name = "Gate%d" % idx
	g.index = idx
	var wa := _worldf(a.x, a.y); var wb := _worldf(b.x, b.y)
	var lateral := wb - wa; lateral.y = 0.0
	var width := lateral.length()
	lateral = lateral.normalized()
	g.basis = Basis(lateral, Vector3.UP, lateral.cross(Vector3.UP))
	# Height from the road centre (not the dots — they sit on the shoulders, possibly higher),
	# sunk 1 m so terrain undulation under a wide gate can't leave a gap.
	var midw := _pair_mid_world(a, b)
	g.position = Vector3(midw.x, midw.y + gate_height * 0.5 - 1.0, midw.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, gate_height, gate_depth)
	var cs := CollisionShape3D.new(); cs.name = "Shape"; cs.shape = shape
	g.add_child(cs)
	# Placeholder visuals: a pole at each end (white = start/finish, orange = checkpoint), children
	# of the gate so hand-moved gates carry them. Real gate props come with code-track-props/art.
	var pole_h := 4.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.88) if idx == 0 else Color(1.0, 0.45, 0.05)
	var pm := BoxMesh.new(); pm.size = Vector3(0.4, pole_h, 0.4); pm.material = mat
	for e in [["PoleA", wa, -width * 0.5], ["PoleB", wb, width * 0.5]]:
		var mi := MeshInstance3D.new()
		mi.name = e[0]
		mi.mesh = pm
		# Stand on the terrain at this end (dots sit on the shoulders, whose height differs from
		# the road centre the gate itself is anchored to), sunk 0.4 m against slope.
		mi.position = Vector3(e[2], (e[1] as Vector3).y + pole_h * 0.5 - 0.4 - g.position.y, 0.0)
		g.add_child(mi)
	return g

# ---------- markers: start position + placeholder props ----------
func _add_markers(root: Node3D, start_mid: Vector2) -> void:
	var m := Marker3D.new(); m.name = "StartFinish"
	m.position = _worldf(start_mid.x, start_mid.y) + Vector3.UP * 0.5
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
