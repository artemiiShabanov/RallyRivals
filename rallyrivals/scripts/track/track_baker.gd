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
var scatter_budget := 30000             ## hard cap on scatter cubes; densities scale down together if exceeded (logged)
var scatter_seed := 5                   ## bakes must be reproducible — same images in, same scatter out
var scatter_max_slope := 0.62           ## skip cliffs: min ground normal.y that still gets debris
var terrace_step := 0.6                 ## off-road slab height in metres (0 = smooth, no terracing)

# Race colours (semantic dots in race.png). A dot is any small blob; its centroid is what counts.
# Pairs of dots straddle the road: start pair = the start line (gate 0), each gate pair = one
# checkpoint gate, dot spacing = gate width. A cyan FINISH pair makes the track POINT-TO-POINT:
# the march runs start -> finish (open road, no loop), and the finish becomes the last gate.
const R_START := Color(1, 0, 1)
const R_DIR := Color(1, 1, 0)
const R_GATE := Color(0, 1, 0)
const R_FINISH := Color(0, 1, 1)

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
	var is_loop: bool = not race.has("finish_mid")

	var root := Node3D.new()
	root.name = "Track"
	_add_environment(root)
	var counts := _add_ground(root)
	var nscatter := _add_scatter(root)
	var spline_pts := _extract_spline(race["start_mid"], race["dir"], Vector2.INF if is_loop else race["finish_mid"])
	var curve := _add_path(root, spline_pts, is_loop)
	var ngates := _add_checkpoints(root, race, curve, is_loop)
	_add_markers(root, race["start_mid"])
	if not is_loop:
		var fm := Marker3D.new()
		fm.name = "FinishLine"
		fm.position = _worldf(race["finish_mid"].x, race["finish_mid"].y) + Vector3.UP * 0.5
		root.add_child(fm)

	_own_all(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, out_scene)
	print("bake: size=", _size, " spline_pts=", spline_pts.size(), " gates=", ngates, " loop=", is_loop, " surfaces=", counts, " scatter=", nscatter, " save_err=", err)
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

## Top of the terrace slab covering this point. Quantises the height at the CELL CENTRE (not at the
## point), which is what makes a whole cell one flat tread. round(), not floor(), so the slab
## straddles the true surface — that halves how far the visual ground can sit from the collision the
## wheels actually ride. Shared by the mesher and by anything placed on top (scatter), so the two
## can never disagree about where the ground is.
func _slab_top(fx: float, fy: float) -> float:
	var stepf := mesh_res / mpp
	var cx := (floorf(fx / stepf) + 0.5) * stepf
	var cy := (floorf(fy / stepf) + 0.5) * stepf
	return roundf(_height_bilinear(cx, cy) / terrace_step) * terrace_step

## Where the VISUAL ground actually is: the slab top off-road, the true surface on the smooth road
## ribbon. (Collision always follows the true surface — see _add_ground.)
func _visual_height(fx: float, fy: float) -> float:
	if terrace_step <= 0.0 or _surface_of(fx, fy) != off_road_surface:
		return _height_bilinear(fx, fy)
	return _slab_top(fx, fy)

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

	# --- terrain shader weights: one-hot per classified surface. Bilinear sampling + fragment
	# argmax renders boundaries as smooth iso-lines (no pixel serration, no blur, no phantom
	# in-between surfaces). Canonical colours come from the .tres palette via uniforms.
	var all_surfaces: Array = surfaces.duplicate()
	all_surfaces.append(off_road_surface)
	var w0 := Image.create(_size, _size, false, Image.FORMAT_RGBA8)
	var w1 := Image.create(_size, _size, false, Image.FORMAT_RGBA8)
	for y in _size:
		for x in _size:
			var idx := all_surfaces.find(SurfaceMap.classify(_surface_colour(x, y), surfaces, off_road_surface))
			var a := Color(0, 0, 0, 0)
			var b := Color(0, 0, 0, 0)
			match idx:
				0: a.r = 1.0
				1: a.g = 1.0
				2: a.b = 1.0
				3: a.a = 1.0
				4: b.r = 1.0
				5: b.g = 1.0
			w0.set_pixel(x, y, a)
			w1.set_pixel(x, y, b)
	var w0_tex := ImageTexture.create_from_image(w0)
	ResourceSaver.save(w0_tex, _out_dir.path_join("ground_weights0.res"))
	w0_tex.take_over_path(_out_dir.path_join("ground_weights0.res"))
	var w1_tex := ImageTexture.create_from_image(w1)
	ResourceSaver.save(w1_tex, _out_dir.path_join("ground_weights1.res"))
	w1_tex.take_over_path(_out_dir.path_join("ground_weights1.res"))
	# Per-surface look, indexed the same way as the weight channels: colour, tint noise, how matte
	# it is, and how much fake blocky relief it gets. All authored on the SurfaceType .tres.
	var pal := PackedVector3Array()
	var vars := PackedFloat32Array()
	var rough := PackedFloat32Array()
	var chunk := PackedFloat32Array()
	for s in all_surfaces:
		pal.append(Vector3(s.color.r, s.color.g, s.color.b))
		vars.append(s.tint_variation)
		rough.append(s.roughness)
		chunk.append(s.chunkiness)
	while pal.size() < 6:
		pal.append(Vector3.ZERO)
		vars.append(0.0)
		rough.append(1.0)
		chunk.append(0.0)
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = load("res://assets/shaders/terrain_surface.gdshader")
	terrain_mat.set_shader_parameter("weights0", w0_tex)
	terrain_mat.set_shader_parameter("weights1", w1_tex)
	terrain_mat.set_shader_parameter("palette", pal)
	terrain_mat.set_shader_parameter("variation", vars)
	terrain_mat.set_shader_parameter("rough", rough)
	terrain_mat.set_shader_parameter("chunk", chunk)
	terrain_mat.set_shader_parameter("world_size", _size * mpp)

	# --- visual: per-surface bucketed meshes (no collision) ---
	# OFF-ROAD GROUND IS TERRACED: each cell becomes a flat slab at a quantised height with vertical
	# risers down to lower neighbours, so the elevation already present in the heightmap finally
	# READS as 3-D form. (A smooth slope under matte, flat-shaded lighting produces almost no shading
	# gradient, which is why real hills looked like a flat plane.) The drivable ribbon stays smooth —
	# stairs across a race track would look wrong and would not line up with the wheels. Collision is
	# untouched either way: it is the smooth heightfield above, so terracing is purely something you
	# see, and the driving feel is exactly as it was.
	var buckets := {}   # id -> {surface, st, tris}
	var stepf := mesh_res / mpp
	var cells := int((_size - 1) / stepf)

	# Pass 1 — per-cell slab height. INF marks a cell left smooth (the road ribbon, or terracing off).
	var slab := PackedFloat32Array()
	slab.resize(cells * cells)
	for r in cells:
		for c in cells:
			var cx := (c + 0.5) * stepf
			var cy := (r + 0.5) * stepf
			slab[r * cells + c] = _slab_top(cx, cy) \
				if terrace_step > 0.0 and _surface_of(cx, cy) == off_road_surface else INF

	# Pass 2 — emit treads + risers (or the original smooth pair for un-terraced cells).
	for r in cells:
		for c in cells:
			var fx0 := c * stepf; var fx1 := (c + 1) * stepf
			var fy0 := r * stepf; var fy1 := (r + 1) * stepf
			var v00 := _worldf(fx0, fy0); var v10 := _worldf(fx1, fy0)
			var v01 := _worldf(fx0, fy1); var v11 := _worldf(fx1, fy1)
			var h := slab[r * cells + c]

			if is_inf(h):
				var c00 := _surface_bilinear(fx0, fy0); var c10 := _surface_bilinear(fx1, fy0)
				var c01 := _surface_bilinear(fx0, fy1); var c11 := _surface_bilinear(fx1, fy1)
				var n00 := _normalf(fx0, fy0); var n10 := _normalf(fx1, fy0)
				var n01 := _normalf(fx0, fy1); var n11 := _normalf(fx1, fy1)
				# Bucket each triangle by the surface at its centroid pixel.
				_emit(buckets, _surface_of((fx0 + fx0 + fx1) / 3.0, (fy0 + fy1 + fy1) / 3.0), v00, c00, n00, v01, c01, n01, v11, c11, n11)
				_emit(buckets, _surface_of((fx0 + fx1 + fx1) / 3.0, (fy0 + fy1 + fy0) / 3.0), v00, c00, n00, v11, c11, n11, v10, c10, n10)
				continue

			var mx := (fx0 + fx1) * 0.5; var my := (fy0 + fy1) * 0.5
			var s := _surface_of(mx, my)
			var col := _surface_bilinear(mx, my)
			var a := Vector3(v00.x, h, v00.z); var b := Vector3(v01.x, h, v01.z)
			var d := Vector3(v11.x, h, v11.z); var e := Vector3(v10.x, h, v10.z)
			_emit(buckets, s, a, col, Vector3.UP, b, col, Vector3.UP, d, col, Vector3.UP)
			_emit(buckets, s, a, col, Vector3.UP, d, col, Vector3.UP, e, col, Vector3.UP)

			# Risers. A slab neighbour only gets one when it sits LOWER (so the higher cell owns the
			# wall and it is never drawn twice); a smooth neighbour always gets one, which is what
			# seals the step where terraced land meets the road ribbon.
			_edge_riser(buckets, s, col, slab, cells, r - 1, c, h, v00, v10)
			_edge_riser(buckets, s, col, slab, cells, r + 1, c, h, v01, v11)
			_edge_riser(buckets, s, col, slab, cells, r, c - 1, h, v00, v01)
			_edge_riser(buckets, s, col, slab, cells, r, c + 1, h, v10, v11)

	var counts := {}
	for id in buckets:
		var b: Dictionary = buckets[id]
		var st: SurfaceTool = b["st"]
		st.index()
		var mesh := st.commit()
		ResourceSaver.save(mesh, _out_dir.path_join("ground_%s_mesh.res" % id))
		mesh.take_over_path(_out_dir.path_join("ground_%s_mesh.res" % id))
		var mi := MeshInstance3D.new(); mi.name = "Mesh_%s" % id; mi.mesh = mesh; mi.material_override = terrain_mat
		ground.add_child(mi)
		counts[id] = int(b["tris"])   # triangle count (for the bake log)

	root.add_child(ground)
	return counts

# One terrace riser: the vertical quad between this slab's edge (both ends at `h`) and whatever the
# neighbour presents along that edge — a flat slab height, or the true sloped ground when the
# neighbour is a smooth (road) cell. Nothing is emitted toward a slab that is level or higher, so
# each wall has exactly one owner. Off-map edges are skipped. The terrain material is cull_disabled,
# so winding does not matter here.
func _edge_riser(buckets: Dictionary, s: SurfaceType, col: Color, slab: PackedFloat32Array,
		cells: int, nr: int, nc: int, h: float, p0: Vector3, p1: Vector3) -> void:
	if nr < 0 or nc < 0 or nr >= cells or nc >= cells:
		return
	var hn := slab[nr * cells + nc]
	var y0 := p0.y
	var y1 := p1.y
	if not is_inf(hn):
		if hn >= h:
			return          # the neighbour is level or higher — it owns that wall, not us
		y0 = hn
		y1 = hn
	var dir := p1 - p0
	dir.y = 0.0
	var n := dir.cross(Vector3.UP).normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var a := Vector3(p0.x, h, p0.z)
	var b := Vector3(p1.x, h, p1.z)
	var an := Vector3(p0.x, y0, p0.z)
	var bn := Vector3(p1.x, y1, p1.z)
	_emit(buckets, s, a, col, n, an, col, n, bn, col, n)
	_emit(buckets, s, a, col, n, bn, col, n, b, col, n)

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
	var out := {
		"start_a": starts[0], "start_b": starts[1], "start_mid": mid,
		"dir": (dirs[0] - mid).normalized(),
		"gates": pairs,
	}
	var finishes := _blobs(_rc, R_FINISH)
	if finishes.size() == 2:   # point-to-point track
		out["finish_a"] = finishes[0]
		out["finish_b"] = finishes[1]
		out["finish_mid"] = (finishes[0] + finishes[1]) * 0.5
	elif not finishes.is_empty():
		push_error("TrackBaker: race.png has %d finish dots (need 2 for point-to-point, or none)" % finishes.size())
		return {}
	return out

# ---------- spline extraction (ant-march the road centreline) ----------
func _recenter(p: Vector2, dir: Vector2) -> Vector2:
	var perp := Vector2(-dir.y, dir.x)
	var hi := 0.0; var lo := 0.0
	var t := 1.0
	while t < 26.0 and _is_road(p + perp * t): hi = t; t += 1.0
	t = 1.0
	while t < 26.0 and _is_road(p - perp * t): lo = t; t += 1.0
	return p + perp * ((hi - lo) * 0.5)

# Marches from the start line along the road. Loop tracks (finish == INF) terminate on
# returning to the start; point-to-point tracks terminate on reaching the finish line.
func _extract_spline(start: Vector2, dir: Vector2, finish := Vector2.INF) -> PackedVector2Array:
	var target := start if finish == Vector2.INF else finish
	var pts := PackedVector2Array()
	var pos := start
	var step := 4.0
	var armed := false   # termination check arms once the march has actually left the start area
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
		# Arm after leaving the start area, terminate on reaching the target (start again for a
		# loop, the finish line for point-to-point). The radius must comfortably beat the march's
		# lateral zigzag or a lap gets doubled / a finish gets overshot.
		if not armed:
			armed = pos.distance_to(start) > step * 6.0
		elif pos.distance_to(target) < step * 2.5:
			if finish != Vector2.INF:
				pts.append(finish)   # run the path right up to the finish line
			return pts
	# Fell out without terminating: a corner sharper than the marcher can follow (it may even
	# have U-turned and retraced). TrackPath and gate ordering are NOT trustworthy — fix the layout.
	var what := "close the loop" if finish == Vector2.INF else "reach the finish line"
	push_warning("TrackBaker: spline march did not %s (%d pts, ended %.0f px away)" % [what, pts.size(), pos.distance_to(target)])
	return pts

func _add_path(root: Node3D, pts: PackedVector2Array, is_loop := true) -> Curve3D:
	var path := Path3D.new(); path.name = "TrackPath"
	var curve := Curve3D.new()
	var keep := PackedVector2Array()
	var stride := maxi(1, int(float(pts.size()) / path_points))
	for i in range(0, pts.size(), stride):
		keep.append(pts[i])
	if not is_loop and keep[keep.size() - 1] != pts[pts.size() - 1]:
		keep.append(pts[pts.size() - 1])   # an open road must keep its end point
	var n := keep.size()
	for i in n:
		var p := keep[i]
		var wp := Vector3((p.x - _size * 0.5) * mpp, _height(int(p.x), int(p.y)) + 0.5, (p.y - _size * 0.5) * mpp)
		var ia := (i - 1 + n) % n if is_loop else maxi(i - 1, 0)
		var ib := (i + 1) % n if is_loop else mini(i + 1, n - 1)
		var pa := keep[ia]; var pb := keep[ib]
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
func _add_checkpoints(root: Node3D, race: Dictionary, curve: Curve3D, is_loop := true) -> int:
	var cps := TrackCheckpoints.new()
	cps.name = "Checkpoints"
	cps.loop = is_loop
	root.add_child(cps)
	var length := curve.get_baked_length()
	var start_off := curve.get_closest_offset(_pair_mid_world(race["start_a"], race["start_b"]))
	var entries := []   # [offset from start line, dot a, dot b]
	for pr in race["gates"]:
		var off: float = curve.get_closest_offset(_pair_mid_world(pr[0], pr[1]))
		entries.append([fposmod(off - start_off, length) if is_loop else off, pr[0], pr[1]])
	entries.sort_custom(func(a, b): return a[0] < b[0])
	entries.push_front([0.0, race["start_a"], race["start_b"]])
	if not is_loop:
		entries.append([INF, race["finish_a"], race["finish_b"]])   # finish = the last gate
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

# ---------- scatter (the ground's volume) ----------
# Loose cubes strewn over the loose surfaces. The terrain shader's chunkiness is lighting-only, so
# this is the only thing that gives the ground a real silhouette and self-shadowing. ONE MultiMesh
# for the whole track (single draw call, per-instance colour carries all six surfaces) and NO
# collider — volume you can see but never catch a wheel on, so the drivable surface stays honest.
#
# Placement walks a jittered grid at the densest surface's spacing and rejection-samples each point
# against its own surface's density, so one pass yields correct per-surface densities. Cubes sink
# ~30% so they read as embedded in the ground rather than resting on a plane.
func _add_scatter(root: Node3D) -> int:
	var densest := 0.0
	for s in _all_surfaces():
		densest = maxf(densest, s.scatter_density)
	if densest <= 0.0:
		return 0

	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var spacing := 1.0 / sqrt(densest)          # grid pitch that satisfies the densest surface
	var steps := int(floor(_size * mpp / spacing))

	# Collect at the authored densities first, then subsample only if we genuinely overshoot —
	# guessing the accept rate up front just throws away density we were allowed to keep.
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for iy in steps:
		for ix in steps:
			# jitter inside the cell so the grid never reads as rows
			var fx := (ix + rng.randf()) * spacing / mpp
			var fy := (iy + rng.randf()) * spacing / mpp
			if fx >= _size - 1 or fy >= _size - 1:
				continue
			var surf := _surface_of(fx, fy)
			if surf == null or surf.scatter_density <= 0.0:
				continue
			if rng.randf() > surf.scatter_density / densest:
				continue
			if _normalf(fx, fy).y < scatter_max_slope:
				continue                          # no debris clinging to cliff faces
			var e := surf.scatter_size * rng.randf_range(0.65, 1.4)
			var pos := _worldf(fx, fy)
			pos.y = _visual_height(fx, fy)        # sit on the terrace, not the smooth height under it
			pos.y += e * 0.2                      # sunk ~30% of its height into the ground
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			basis = basis.rotated(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			basis = basis.rotated(Vector3.FORWARD, rng.randf_range(-0.25, 0.25))
			xforms.append(Transform3D(basis.scaled(Vector3(e, e, e)), pos))
			var j := rng.randf_range(0.82, 1.18)  # per-cube brightness so it isn't one flat mass
			colors.append(Color(surf.scatter_color.r * j, surf.scatter_color.g * j, surf.scatter_color.b * j))
	if xforms.is_empty():
		return 0

	var wanted := xforms.size()
	if wanted > scatter_budget:
		var keep := float(scatter_budget) / float(wanted)
		var kx: Array[Transform3D] = []
		var kc: Array[Color] = []
		for i in wanted:
			if rng.randf() < keep:
				kx.append(xforms[i])
				kc.append(colors[i])
		xforms = kx
		colors = kc
		print("bake: scatter over budget — kept %d of %d cubes" % [xforms.size(), wanted])

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE                       # per-instance scale carries the real size
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true         # instance colour drives albedo
	mat.roughness = 1.0
	mat.specular = 0.05                           # loose debris must catch no highlight (see SurfaceType)
	cube.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true                          # must be set BEFORE instance_count allocates buffers
	mm.mesh = cube
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	ResourceSaver.save(mm, _out_dir.path_join("ground_scatter.res"))
	mm.take_over_path(_out_dir.path_join("ground_scatter.res"))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "SurfaceScatter"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # the shadows ARE the volume
	root.add_child(mmi)
	return xforms.size()

## Road palette + off-road, the same list the weights are indexed by.
func _all_surfaces() -> Array:
	var a := surfaces.duplicate()
	if off_road_surface != null and not a.has(off_road_surface):
		a.append(off_road_surface)
	return a

# ---------- environment ----------
func _add_environment(root: Node3D) -> void:
	var we := WorldEnvironment.new(); we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	VhsSky.ensure(env)   # bake the custom VHS sky; conditions retune its uniforms at runtime
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
