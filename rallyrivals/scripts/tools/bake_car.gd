extends SceneTree
## Bake a hand-finished car .vox into the game body mesh: greedy-mesh it, split faces into MATERIAL
## CLASSES (paint / glass / chrome / rubber), and bake the RIG transform into the vertices so it drops
## straight onto car.tscn's wheels. Emits an ArrayMesh `.tres` with a real StandardMaterial3D per surface
## (reflective glass, metallic chrome, matte paint) — the palette is embedded (ImageTexture from the .vox
## RGBA) so it's self-contained. Reversed winding + CULL_DISABLED so the shell shades right (not flat) and
## never renders see-through. The car's CarDef (assets/cars/<id>.tres) `model` field must point at this .tres.
## Run: godot --headless --script res://scripts/tools/bake_car.gd
const VOX := 0.033
# rig anchor (car.tscn: wheels x=±0.85, z=±1.4, r0.40; front=+z). .vox generator-space: spine x=32,
# wheel-centre y=3, axle-mid z=69.5. 180° Y-rotation puts the nose (model z≈0) at the rig front (+z).
const OY := -0.5
# Per-car rig anchor. CY = (RIG_WHEEL_R - SPEC.floor)/VOX (wheel centre above the settled floor);
# CZ = axle midpoint (wz_f+wz_r)/2 / VOX. CX is the spine, measured from the data. Getting these wrong
# floats or buries the wheels, so they are per-car — never reuse one car's numbers for another.
const CAR := "strobe"
const CARS := {
	"delta":   {"src": "res://assets/voxels/cars/delta.vox",   "tres": "res://assets/voxels/cars/delta_body.tres",
	            "uid": "uid://bk42crjm5lw41", "cy": 3.0, "cz": 69.7},
	"tangent": {"src": "res://assets/voxels/cars/tangent.vox", "tres": "res://assets/voxels/cars/tangent_body.tres",
	            "uid": "uid://bos1221f5owhm", "cy": 3.0, "cz": 74.24},
	"meridian": {"src": "res://assets/voxels/cars/meridian.vox", "tres": "res://assets/voxels/cars/meridian_body.tres",
	            "uid": "", "cy": 3.0, "cz": 73.33},
	# Verdict sits LOWER than the others (floor 0.25, not 0.30 — its scaled wheel is nearly rig-size), so its
	# cy is not the shared 3.0: (RIG_WHEEL_R - floor)/VOX = (0.40-0.25)/0.033. cz = axle midpoint, voxels 27/112.
	"verdict": {"src": "res://assets/voxels/cars/verdict.vox", "tres": "res://assets/voxels/cars/verdict_body.tres",
	            "uid": "", "cy": 4.55, "cz": 69.5},
	# Stiletto is back on the shared floor 0.30 -> cy 3.0. cz = axle midpoint: _rz(0.75)=23, _rz(3.55)=108.
	"stiletto": {"src": "res://assets/voxels/cars/stiletto.vox", "tres": "res://assets/voxels/cars/stiletto_body.tres",
	            "uid": "", "cy": 3.0, "cz": 65.5},
	# Mule rides HIGH (floor 0.40) — level with RIG_WHEEL_R, so cy is 0: the model floor sits exactly at
	# the wheel centre. Same axles as Stiletto: _rz(0.75)=23, _rz(3.55)=108 -> cz 65.5.
	"mule": {"src": "res://assets/voxels/cars/mule.vox", "tres": "res://assets/voxels/cars/mule_body.tres",
	            "uid": "", "cy": 0.0, "cz": 65.5},
	# Crowbar: floor 0.30 -> cy 3.0. Axles _rz(0.93)=28, _rz(3.73)=113 -> cz 70.5.
	"crowbar": {"src": "res://assets/voxels/cars/crowbar.vox", "tres": "res://assets/voxels/cars/crowbar_body.tres",
	            "uid": "", "cy": 3.0, "cz": 70.5},
	# Anvil rides high like the Mule (floor 0.40 == RIG_WHEEL_R) -> cy 0. Axles _rz(0.79)=24, _rz(3.59)=109.
	"anvil": {"src": "res://assets/voxels/cars/anvil.vox", "tres": "res://assets/voxels/cars/anvil_body.tres",
	            "uid": "", "cy": 0.0, "cz": 66.5},
	# Sledge: floor 0.30 -> cy 3.0. Axles _rz(0.86)=26, _rz(3.66)=111 -> cz 68.5.
	"sledge": {"src": "res://assets/voxels/cars/sledge.vox", "tres": "res://assets/voxels/cars/sledge_body.tres",
	            "uid": "", "cy": 3.0, "cz": 68.5},
	# Juggernaut is the FIRST car with a NEGATIVE cy: floor 0.46 is ABOVE RIG_WHEEL_R 0.40, so the model
	# floor sits above the wheel centre. (0.40-0.46)/VOX = -1.82. Axles _rz(0.85)=26, _rz(3.65)=111.
	"juggernaut": {"src": "res://assets/voxels/cars/juggernaut.vox", "tres": "res://assets/voxels/cars/juggernaut_body.tres",
	            "uid": "", "cy": -1.82, "cz": 68.5},
	# Spark: floor 0.30 -> cy 3.0, the shared tarmac value. Axles _rz(0.72)=22, _rz(3.52)=107 -> cz 64.5,
	# the SMALLEST in the roster — it is the shortest car, so its axle midpoint sits furthest forward.
	"spark": {"src": "res://assets/voxels/cars/spark.vox", "tres": "res://assets/voxels/cars/spark_body.tres",
	            "uid": "", "cy": 3.0, "cz": 64.5},
	# Fuse: floor 0.30 -> cy 3.0. Axles _rz(0.88)=27, _rz(3.68)=112 -> cz 69.5.
	"fuse": {"src": "res://assets/voxels/cars/fuse.vox", "tres": "res://assets/voxels/cars/fuse_body.tres",
	            "uid": "", "cy": 3.0, "cz": 69.5},
	# Strobe is the SECOND car off the shared floor after the Verdict: floor 0.26, because its 205/55VR16
	# scales to 389 mm against the rig 400 — only 3% of arcade inflation, so the body is not lifted off
	# its wheels. cy = (0.40-0.26)/VOX = 4.24. Axles _rz(0.94)=28, _rz(3.74)=113 -> cz 70.5.
	"strobe": {"src": "res://assets/voxels/cars/strobe.vox", "tres": "res://assets/voxels/cars/strobe_body.tres",
	            "uid": "", "cy": 4.24, "cz": 70.5},
}
var CX := 32.0
var CY: float = CARS[CAR]["cy"]
var CZ: float = CARS[CAR]["cz"]
var SRC: String = CARS[CAR]["src"]
var TRES: String = CARS[CAR]["tres"]
var TRES_UID: String = CARS[CAR]["uid"]

var grid := {}
var rgba: PackedByteArray
var _class := {}
const ORDER := ["paint", "glass", "chrome", "rubber"]

func _initialize() -> void:
	var b := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(SRC))
	var xi := _find(b, "XYZI"); var n := b.decode_u32(xi + 12); var off := xi + 16
	for i in n:
		grid[Vector3i(b[off], b[off+2], b[off+1])] = b[off+3] - 1
		off += 4
	var ri := _find(b, "RGBA"); rgba = b.slice(ri + 12, ri + 12 + 1024)
	var lox := 1 << 30; var hix := -(1 << 30)
	for k in grid: lox = mini(lox, k.x); hix = maxi(hix, k.x)
	CX = (lox + hix) / 2.0                     # spine measured from the data, not assumed
	# (the old mint->dirty-white recolour now lives in the master palette itself, so nothing to remap here)
	var glass := _nearest(0x5c, 0x70, 0x86); var chrome := _nearest(0xc6, 0xca, 0xd0); var tyre := _nearest(0x10, 0x10, 0x14)
	for s in 256: _class[s] = "paint"
	_class[glass] = "glass"; _class[chrome] = "chrome"; _class[tyre] = "rubber"
	print("class slots: glass=%d chrome=%d rubber=%d  (%d voxels)" % [glass, chrome, tyre, n])
	var exposed := [0]
	var quads := _greedy_quads(exposed)
	print("quads=%d exposed=%d" % [quads.size(), exposed[0]])
	_write_tres(quads)
	print("baked %s -> %s (%d quads, spine x=%.1f)" % [CAR, TRES.get_file(), quads.size(), CX])
	_print_collision()
	quit()

# Emit the CarDef body box for this car, so collision_size/offset can never drift from the mesh.
# The box FLOOR is pinned to the scene box's y = -0.30 on every car: the wheels are raycasts, so the
# body shape never supports the car and how low it reaches is the only thing that alters ride height.
# Fixing it means collisions and damage get the true footprint while the car drives exactly as before.
# Aerials are trimmed — an antenna is 1-3 voxels per row where a wing blade is 300+, so 30 separates
# them — otherwise a mast becomes a collidable spike that snags on scenery.
const COL_FLOOR_Y := -0.30
const AERIAL_ROW := 30
func _print_collision() -> void:
	var rows := {}
	var lox := 1 << 30; var hix := -(1 << 30); var loz := 1 << 30; var hiz := -(1 << 30)
	for k in grid:
		rows[k.y] = int(rows.get(k.y, 0)) + 1
		lox = mini(lox, k.x); hix = maxi(hix, k.x); loz = mini(loz, k.z); hiz = maxi(hiz, k.z)
	var top := -(1 << 30); var raw := -(1 << 30)
	for y in rows:
		raw = maxi(raw, int(y))
		if int(rows[y]) >= AERIAL_ROW: top = maxi(top, int(y))
	var ty := float(top + 1 - CY) * VOX + OY
	var size := Vector3(float(hix - lox + 1) * VOX, ty - COL_FLOOR_Y, float(hiz - loz + 1) * VOX)
	# Derive the offset from the ROUNDED size, not the exact one — writing both independently at 2 and 3
	# decimals drifts the floor by a couple of mm, and "the floor never moves" is the entire guarantee.
	var sy := snappedf(size.y, 0.01)
	print("  CarDef collision:  collision_size = Vector3(%.2f, %.2f, %.2f)   collision_offset_y = %.3f%s" % [
		size.x, sy, size.z, COL_FLOOR_Y + sy * 0.5,
		("   (aerial trimmed %.2f m)" % (float(raw - top) * VOX)) if raw > top else ""])

func _find(b: PackedByteArray, id: String) -> int:
	var c := id.to_ascii_buffer()
	for i in range(0, b.size() - 4):
		if b[i] == c[0] and b[i+1] == c[1] and b[i+2] == c[2] and b[i+3] == c[3]: return i
	return -1

# Overwrite every palette slot matching `from` (near-exact) with `to`, in the in-memory RGBA that feeds
# both the .obj texture and the .tres ImageTexture. Localised recolour without touching the .vox/palette.
func _recolor(from: Color, to: Color) -> void:
	for i in 256:
		var o := i * 4
		var c := Color8(rgba[o], rgba[o+1], rgba[o+2])
		if Vector3(c.r - from.r, c.g - from.g, c.b - from.b).length() < 0.06:
			rgba[o] = int(round(to.r * 255.0)); rgba[o+1] = int(round(to.g * 255.0)); rgba[o+2] = int(round(to.b * 255.0))

func _nearest(r: int, g: int, bl: int) -> int:
	var best := 1 << 30; var pick := 0
	for i in 256:
		var o := i * 4; var dr := rgba[o] - r; var dg := rgba[o+1] - g; var db := rgba[o+2] - bl
		var dd := dr*dr + dg*dg + db*db
		if dd < best: best = dd; pick = i
	return pick

func _wp(px: float, py: float, pz: float) -> Vector3:
	return Vector3(-(px - CX) * VOX, (py - CY) * VOX + OY, -(pz - CZ) * VOX)

# corners of a quad in world space + its rotated normal + slot uv-u. Returns [Vector3 x4, Vector3 n, float u].
func _quad_geom(q: Array) -> Array:
	var naxis: int = q[0]; var sgn: int = q[1]; var s: int = q[2]
	var a0: int = q[3]; var b0: int = q[4]; var da: int = q[5]; var db: int = q[6]; var slot: int = q[7]
	var A := (naxis + 1) % 3; var B := (naxis + 2) % 3
	var base := [0.0, 0.0, 0.0]
	base[naxis] = float(s + 1) if sgn > 0 else float(s); base[A] = float(a0); base[B] = float(b0)
	var order := [[0, 0], [1, 0], [1, 1], [0, 1]] if sgn > 0 else [[0, 0], [0, 1], [1, 1], [1, 0]]
	var pts := []
	for ij in order:
		var p := base.duplicate()
		p[A] += float(ij[0] * da); p[B] += float(ij[1] * db)
		pts.append(_wp(p[0], p[1], p[2]))
	var nv := [0, 0, 0]; nv[naxis] = sgn
	return [pts[0], pts[1], pts[2], pts[3], Vector3(-nv[0], nv[1], -nv[2]), (slot + 0.5) / 256.0]

func _write_tres(quads: Array) -> void:
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in 256:
		var o := i * 4; img.set_pixel(i, 0, Color8(rgba[o], rgba[o+1], rgba[o+2], 255))
	var tex := ImageTexture.create_from_image(img)
	var mats := {
		"paint": _mat(tex, 0.5, 0.0, 0.5, 0.0),     # no emission -> real directional shading/shadows
		"glass": _mat(tex, 0.06, 0.0, 0.9, 0.0),    # low roughness -> reflective
		"chrome": _mat(tex, 0.18, 1.0, 0.5, 0.0),   # metallic
		"rubber": _mat(tex, 0.95, 0.0, 0.3, 0.0),
	}
	var sts := {}
	for cls in ORDER:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); sts[cls] = st
	var used := {}
	for q in quads:
		var cls: String = _class[q[7]]
		var g := _quad_geom(q)
		var st: SurfaceTool = sts[cls]
		# reversed winding [0,2,1 / 0,3,2] so outward faces are FRONT in SurfaceTool's convention
		# (opposite of the OBJ importer) -> correct front-normal lighting, real diffuse shading on paint
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_uv(Vector2(g[5], 0.5)); st.set_normal(g[4]); st.add_vertex(g[idx])
		used[cls] = true
	var mesh := ArrayMesh.new()
	for cls in ORDER:
		if not used.has(cls): continue
		sts[cls].set_material(mats[cls])
		sts[cls].commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, cls)
	ResourceSaver.save(mesh, TRES)
	# stamp the stable uid into the header (ResourceSaver drops it headless) so refs resolve without churn
	var p := ProjectSettings.globalize_path(TRES)
	var txt := FileAccess.get_file_as_string(p)
	var hdr_end := txt.find("]")
	if TRES_UID != "" and hdr_end > 0 and not txt.substr(0, hdr_end).contains("uid="):
		txt = txt.insert(hdr_end, " uid=\"%s\"" % TRES_UID)
		FileAccess.open(p, FileAccess.WRITE).store_string(txt)
	print("  surfaces=%d aabb=%s" % [mesh.get_surface_count(), str(mesh.get_aabb())])

func _mat(tex: Texture2D, rough: float, metal: float, spec: float, emis: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = rough; m.metallic = metal; m.metallic_specular = spec
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # voxel shell: double-sided, never see-through
	if emis > 0.0:                               # self-lit tint so colours read in dim scene lighting
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission = Color.WHITE
		m.emission_energy_multiplier = emis
	return m

func _greedy_quads(exposed: Array) -> Array:
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
			for s in slices:
				var mask: Dictionary = slices[s]
				exposed[0] += mask.size()
				_merge_slice(mask, quads, naxis, sgn, s)
	return quads

func _merge_slice(mask: Dictionary, quads: Array, naxis: int, sgn: int, s: int) -> void:
	var amin := 1 << 30; var amax := -(1 << 30); var bmin := 1 << 30; var bmax := -(1 << 30)
	for k in mask:
		amin = mini(amin, k.x); amax = maxi(amax, k.x); bmin = mini(bmin, k.y); bmax = maxi(bmax, k.y)
	var done := {}
	for b in range(bmin, bmax + 1):
		for a in range(amin, amax + 1):
			var k0 := Vector2i(a, b)
			if not mask.has(k0) or done.has(k0): continue
			var slot: int = mask[k0]
			var da := 1
			while mask.get(Vector2i(a + da, b), -1) == slot and not done.has(Vector2i(a + da, b)): da += 1
			var db := 1; var grow := true
			while grow:
				for aa in range(a, a + da):
					var kk := Vector2i(aa, b + db)
					if mask.get(kk, -1) != slot or done.has(kk): grow = false; break
				if grow: db += 1
			for aa in range(a, a + da):
				for bb in range(b, b + db): done[Vector2i(aa, bb)] = true
			quads.append([naxis, sgn, s, a, b, da, db, slot])
