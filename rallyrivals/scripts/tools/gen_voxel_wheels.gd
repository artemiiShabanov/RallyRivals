extends SceneTree
## Generate the 3 brand wheels (apex / wreck / mayfly) as voxel models and bake each to a game-ready
## ArrayMesh .tres — per-class StandardMaterial3D (rubber tyre / metallic rim / painted hub), reversed
## SurfaceTool winding + CULL_DISABLED (same fix as the car), palette embedded. Authored axle-along-X,
## centred at origin, radius 0.44 m so it drops onto the VehicleWheel3D (wheel_radius 0.44) at identity.
## Wire each into its CarDefs' wheel_model. Run: godot --headless --script res://scripts/tools/gen_voxel_wheels.gd
const WVOX := 0.022
const R := 20            # 0.44 / 0.022
const W := 10            # ~0.22 m tyre width
const TIRE := 3.5        # tyre radial thickness (voxels)
const RIMLIP := 2.0      # rim lip ring inside the tyre
const HUB := 3.6         # hub cap radius
const DIR := "res://assets/voxels/wheels/"

var _pal: Image
var S := {}
var grid := {}

const STYLES := [
	{"id": "apex", "type": "spoke", "spokes": 5, "spoke_w": 0.44, "hub": "red", "uid": "uid://bapexwheel1x"},
	# The uid MUST match what is on disk and in the CarDefs that point here. Godot replaced wreck's
	# hand-written uid with a real one on an editor pass; re-baking with the old string silently
	# orphans every CarDef that references the wheel (the mesh loads as <null> and the car loses its
	# wheels). Read the uid off the .tres before changing anything in this table.
	{"id": "wreck", "type": "dish", "lugs": 5, "hub": "orange", "uid": "uid://clx2erd51v682"},
	# hub = the brand ACCENT, same as apex:red and wreck:orange. Was "cyan" — the pre-gold Mayfly
	# accent — which now clashes with the gold body instead of tying the wheel to it.
	{"id": "mayfly", "type": "spoke", "spokes": 10, "spoke_w": 0.24, "hub": "indigo", "uid": "uid://bmayflwheel3z"},
]

func _initialize() -> void:
	_pal = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR + "_review/"))
	S = {
		"tire": _slot(Color("101014")), "chrome": _slot(Color("c6cad0")), "steel": _slot(Color("8f9196")),
		"dark": _slot(Color("18181c")), "red": _slot(Color("c9303e")), "orange": _slot(Color("ff8c00")),
		"cyan": _slot(Color("abf5ed")), "indigo": _slot(Color("202d85")),
	}
	var cells := {}
	for st in STYLES:
		_build(st)
		_bake(st.id, st.uid)
		cells[st.id] = _render(st.id)
	_sheet(cells)
	print("wheels -> %s{wheel_apex,wheel_wreck,wheel_mayfly}.tres + _review/sheet_wheels.png" % DIR)
	quit()

# ---------------- build ----------------
func _build(st: Dictionary) -> void:
	grid = {}
	var hub_slot: int = S[st.hub]
	for x in W:
		for y in 2 * R:
			for z in 2 * R:
				var dy := y + 0.5 - R; var dz := z + 0.5 - R
				var d := sqrt(dy * dy + dz * dz)
				if d > R: continue
				var slot := _wheel_slot(st, d, atan2(dz, dy), dy, dz, hub_slot)
				if slot >= 0: grid[Vector3i(x, y, z)] = slot

func _wheel_slot(st: Dictionary, d: float, ang: float, dy: float, dz: float, hub_slot: int) -> int:
	if d >= R - TIRE: return S.tire                    # tyre ring (full width)
	if d < HUB: return hub_slot                        # hub cap
	if d >= R - TIRE - RIMLIP: return S.chrome         # rim lip (ties spokes to tyre)
	if st.type == "spoke":
		var n: int = st.spokes; var sw: float = st.spoke_w
		var sect := fposmod(ang, TAU / n) / (TAU / n)  # 0..1 within a sector
		var edge := minf(sect, 1.0 - sect) * 2.0       # 1 at sector centre, 0 at boundary
		if edge > 1.0 - sw: return S.chrome            # spoke
		return -1                                      # gap (see-through)
	else:                                              # dish: solid steel + lug holes
		var lugs: int = st.lugs; var lr := R * 0.5
		for k in lugs:
			var la := TAU * k / lugs
			var lx := lr * cos(la); var ly := lr * sin(la)
			if Vector2(dy - lx, dz - ly).length() < 1.9: return -1
		return S.steel

# ---------------- bake to .tres ----------------
func _class(slot: int) -> String:
	if slot == S.tire: return "rubber"
	if slot == S.chrome or slot == S.steel: return "chrome"
	return "paint"

func _bake(id: String, uid: String) -> void:
	var quads := _greedy()
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in 256: img.set_pixel(i, 0, _pal.get_pixel(i, 0))
	var tex := ImageTexture.create_from_image(img)
	var mats := {
		"paint": _mat(tex, 0.5, 0.0, 0.5), "chrome": _mat(tex, 0.25, 1.0, 0.6), "rubber": _mat(tex, 0.95, 0.0, 0.3),
	}
	var order := ["rubber", "chrome", "paint"]
	var sts := {}
	for cls in order:
		var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); sts[cls] = s
	var used := {}
	for q in quads:
		var g := _quad(q)
		var st: SurfaceTool = sts[_class(q[7])]
		for idx in [0, 2, 1, 0, 3, 2]:                 # reversed winding for SurfaceTool
			st.set_uv(Vector2(g[5], 0.5)); st.set_normal(g[4]); st.add_vertex(g[idx])
		used[_class(q[7])] = true
	var mesh := ArrayMesh.new()
	for cls in order:
		if not used.has(cls): continue
		sts[cls].set_material(mats[cls]); sts[cls].commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, cls)
	var path := DIR + "wheel_" + id + ".tres"
	ResourceSaver.save(mesh, path)
	# stamp the stable uid (ResourceSaver drops it headless) so CarDef refs don't churn
	var gp := ProjectSettings.globalize_path(path)
	var txt := FileAccess.get_file_as_string(gp)
	var he := txt.find("]")
	if he > 0 and not txt.substr(0, he).contains("uid="):
		txt = txt.insert(he, " uid=\"%s\"" % uid)
		FileAccess.open(gp, FileAccess.WRITE).store_string(txt)
	print("  wheel_%s: surfaces=%d aabb=%s" % [id, mesh.get_surface_count(), str(mesh.get_aabb())])

func _wp(px: float, py: float, pz: float) -> Vector3:
	return Vector3((px - W / 2.0) * WVOX, (py - R) * WVOX, (pz - R) * WVOX)

func _quad(q: Array) -> Array:
	var naxis: int = q[0]; var sgn: int = q[1]; var s: int = q[2]
	var a0: int = q[3]; var b0: int = q[4]; var da: int = q[5]; var db: int = q[6]; var slot: int = q[7]
	var A := (naxis + 1) % 3; var B := (naxis + 2) % 3
	var base := [0.0, 0.0, 0.0]
	base[naxis] = float(s + 1) if sgn > 0 else float(s); base[A] = float(a0); base[B] = float(b0)
	var order := [[0, 0], [1, 0], [1, 1], [0, 1]] if sgn > 0 else [[0, 0], [0, 1], [1, 1], [1, 0]]
	var pts := []
	for ij in order:
		var p := base.duplicate(); p[A] += float(ij[0] * da); p[B] += float(ij[1] * db)
		pts.append(_wp(p[0], p[1], p[2]))
	var nv := [0, 0, 0]; nv[naxis] = sgn
	return [pts[0], pts[1], pts[2], pts[3], Vector3(nv[0], nv[1], nv[2]), (slot + 0.5) / 256.0]

func _mat(tex: Texture2D, rough: float, metal: float, spec: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = rough; m.metallic = metal; m.metallic_specular = spec
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _greedy() -> Array:
	var quads: Array = []
	for naxis in 3:
		var A := (naxis + 1) % 3; var B := (naxis + 2) % 3
		for sgn in [1, -1]:
			var nrm := Vector3i.ZERO; nrm[naxis] = sgn
			var slices := {}
			for key in grid:
				if grid.has(key + nrm): continue
				var s: int = key[naxis]
				if not slices.has(s): slices[s] = {}
				slices[s][Vector2i(key[A], key[B])] = grid[key]
			for s in slices: _merge(slices[s], quads, naxis, sgn, s)
	return quads

func _merge(mask: Dictionary, quads: Array, naxis: int, sgn: int, s: int) -> void:
	var amin := 1 << 30; var amax := -(1 << 30); var bmin := 1 << 30; var bmax := -(1 << 30)
	for k in mask:
		amin = mini(amin, k.x); amax = maxi(amax, k.x); bmin = mini(bmin, k.y); bmax = maxi(bmax, k.y)
	var done := {}
	for b in range(bmin, bmax + 1):
		for a in range(amin, amax + 1):
			var k0 := Vector2i(a, b)
			if not mask.has(k0) or done.has(k0): continue
			var slot: int = mask[k0]; var da := 1
			while mask.get(Vector2i(a + da, b), -1) == slot and not done.has(Vector2i(a + da, b)): da += 1
			var db := 1; var grow := true
			while grow:
				for aa in range(a, a + da):
					if mask.get(Vector2i(aa, b + db), -1) != slot or done.has(Vector2i(aa, b + db)): grow = false; break
				if grow: db += 1
			for aa in range(a, a + da):
				for bb in range(b, b + db): done[Vector2i(aa, bb)] = true
			quads.append([naxis, sgn, s, a, b, da, db, slot])

func _slot(target: Color) -> int:
	var best := INF; var pick := 0
	for i in 256:
		var col := _pal.get_pixel(i, 0)
		if col.r + col.g + col.b < 0.06: continue
		var dd := Vector3(col.r - target.r, col.g - target.g, col.b - target.b).length()
		if dd < best: best = dd; pick = i
	return pick

# ---------------- preview ----------------
const N6 := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
const CW := 240
const CH := 240
func _render(nm: String) -> Image:
	var d := Vector3(0.62, 0.32, 0.72).normalized()
	var right := Vector3.UP.cross(d).normalized(); var up := d.cross(right).normalized()
	if up.y < 0.0: up = -up
	var lightv := Vector3(0.4, 0.85, 0.32).normalized()
	var shell := []; var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for key in grid:
		var n := Vector3.ZERO
		for o in N6:
			if not grid.has(key + o): n += Vector3(o)
		if n == Vector3.ZERO: continue
		var p := Vector3(key); var sp := Vector2(p.dot(right), p.dot(up))
		shell.append([sp, p.dot(d), n.normalized(), grid[key]]); mn = mn.min(sp); mx = mx.max(sp)
	var span := mx - mn
	var scale := minf((CW - 16) / maxf(span.x, 1.0), (CH - 16) / maxf(span.y, 1.0))
	var ox := (CW - span.x * scale) * 0.5; var oy := (CH - span.y * scale) * 0.5
	var blk := maxi(int(ceil(scale)), 1)
	var img := Image.create(CW, CH, false, Image.FORMAT_RGBA8); img.fill(Color(0.11, 0.12, 0.15))
	var zb := PackedFloat32Array(); zb.resize(CW * CH); zb.fill(-INF)
	for e in shell:
		var sp: Vector2 = e[0]; var dep: float = e[1]
		var sh: float = clampf((e[2] as Vector3).dot(lightv), 0.0, 1.0) * 0.7 + 0.3
		var base: Color = _pal.get_pixel(int(e[3]), 0)
		var col := Color(base.r * sh, base.g * sh, base.b * sh)
		var px := int((sp.x - mn.x) * scale + ox); var py := CH - 1 - int((sp.y - mn.y) * scale + oy)
		for iy in range(py - blk, py + 1):
			for ix in range(px, px + blk):
				if ix < 0 or iy < 0 or ix >= CW or iy >= CH: continue
				var zi := iy * CW + ix
				if dep > zb[zi]: zb[zi] = dep; img.set_pixel(ix, iy, col)
	return img

func _sheet(cells: Dictionary) -> void:
	var img := Image.create(CW * 3, CH, false, Image.FORMAT_RGBA8); img.fill(Color(0.07, 0.08, 0.1))
	var i := 0
	for id in ["apex", "wreck", "mayfly"]:
		if cells.has(id): img.blit_rect(cells[id], Rect2i(0, 0, CW, CH), Vector2i(i * CW, 0))
		i += 1
	img.save_png(ProjectSettings.globalize_path(DIR + "_review/sheet_wheels.png"))
