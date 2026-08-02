extends SceneTree
## Generates the voxel SCENERY/ENVIRONMENT block-out set (art-voxel-environment, ADR-003 pipeline) to
## assets/voxels/environment/<name>.vox|.obj|.mtl|.png. Same machinery as gen_voxel_stubs: build a voxel
## grid (master-palette slots), write a real MagicaVoxel .vox (sculpt over it) + the .obj/.png export
## artifact Godot imports. 1 voxel = 0.1 m. Placed + scaled by RegionSkin's dressing per region.
##   Backdrop (horizon ring, scaled up): ridge / mesa / treeline
##   Buildings (off-road mid-field, collidable): house / hall / tower
## Run: godot --headless --script res://scripts/tools/gen_env_voxels.gd

const VOX := 0.1
var grid := {}
var _palette: Image

func _initialize() -> void:
	_palette = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	var dir := "res://assets/voxels/environment/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# palette slots picked by nearest master-palette colour (block-out tints; sculpt/recolour in MV)
	var rock := _slot(Color(0.42, 0.42, 0.46))
	var rock_dark := _slot(Color(0.20, 0.20, 0.23))
	var snow := _slot(Color(0.90, 0.92, 0.96))
	var sand := _slot(Color(0.72, 0.60, 0.42))
	var foliage := _slot(Color(0.16, 0.42, 0.18))
	var trunk := _slot(Color(0.34, 0.22, 0.12))
	var wall := _slot(Color(0.80, 0.74, 0.60))
	var timber := _slot(Color(0.50, 0.34, 0.20))
	var roof := _slot(Color(0.55, 0.22, 0.18))
	var metal := _slot(Color(0.60, 0.62, 0.66))

	# --- backdrop silhouettes ---
	_build_ridge(rock, snow);       _emit(dir, "ridge", 64, 20, 44)
	_build_ridge(rock_dark, rock);  _emit(dir, "ridge_volcanic", 64, 20, 44)
	_build_mesa(sand);              _emit(dir, "mesa", 56, 44, 40)
	_build_treeline(foliage, trunk);_emit(dir, "treeline", 56, 18, 40)
	# --- buildings ---
	_build_house(wall, roof);       _emit(dir, "house", 40, 50, 46)
	_build_hall(timber, roof);      _emit(dir, "hall", 60, 96, 48)
	_build_tower(metal, roof);      _emit(dir, "tower", 24, 24, 100)

	print("env voxels: 7 models -> ", dir)
	quit()

# ---------- models (grid: x=width, y=height, z=depth) ----------
# A jagged mountain-wall segment: a heightfield ridge, snow-capped on the tall peaks.
func _build_ridge(rock: int, cap: int) -> void:
	grid = {}
	var w := 64; var d := 20
	for x in w:
		var edge: float = minf(float(x), float(w - 1 - x)) / (w * 0.5)   # taper the ends down
		for z in d:
			var dz: float = 1.0 - absf(z + 0.5 - d * 0.5) / (d * 0.5)    # thin front-to-back
			var h := 22.0 + 16.0 * sin(x * 0.11) + 7.0 * sin(x * 0.37 + 1.3) + 5.0 * sin(x * 0.9)
			h = h * clampf(0.35 + 0.65 * edge, 0.0, 1.0) * (0.55 + 0.45 * dz)
			var hi := clampi(int(h), 1, 43)
			for y in hi:
				grid[Vector3i(x, y, z)] = cap if (y >= hi - 4 and hi > 26) else rock

# Flat-topped butte with battered (inward-sloping) sides.
func _build_mesa(rock: int) -> void:
	grid = {}
	var w := 56; var d := 44; var h := 40
	for y in h:
		var inset := int(y * 0.16)
		_fill(6 + inset, w - 7 - inset, y, y, 6 + inset, d - 7 - inset, rock)

# A row of conifer cones (stacked shrinking layers) on short trunks.
func _build_treeline(foliage: int, trunk: int) -> void:
	grid = {}
	for cx in [9, 23, 37, 51]:
		var x0 := int(cx)
		var top := 6 + ((x0 * 7) % 5) * 4       # a little height variety per tree
		_fill(x0 - 1, x0 + 1, 0, 6, 8, 10, trunk)
		for layer in 5:
			var r := 8 - layer                  # cone taper
			if r < 1:
				break
			var y0 := 6 + layer * (top / 5 + 1)
			_fill(x0 - r, x0 + r, y0, y0 + top / 5, 9 - r, 9 + r, foliage)

# A small pitched-roof house: solid wall box + a gable roof (different slot).
func _build_house(wall: int, roof: int) -> void:
	grid = {}
	_fill(3, 36, 0, 27, 3, 46, wall)
	for dy in 13:
		_fill(3 + dy, 36 - dy, 28 + dy, 28 + dy, 0, 49, roof)   # gable narrows with height

# A long low barn/warehouse/lodge: bigger box + a broad low gable.
func _build_hall(wall: int, roof: int) -> void:
	grid = {}
	_fill(3, 56, 0, 32, 3, 92, wall)
	for dy in 15:
		_fill(3 + dy, 56 - dy, 33 + dy, 33 + dy, 0, 95, roof)

# A round silo/tower with a conical cap.
func _build_tower(body: int, cap: int) -> void:
	grid = {}
	var c := 11.5
	for y in 92:
		_disc(c, c, 11.0, y, body)
	for k in 9:
		_disc(c, c, 10.0 - k * 1.1, 92 + k, cap)

func _disc(cx: float, cz: float, r: float, y: int, slot: int) -> void:
	var ri := int(ceil(r))
	for x in range(int(cx - ri), int(cx + ri) + 1):
		for z in range(int(cz - ri), int(cz + ri) + 1):
			if Vector2(x + 0.5 - cx, z + 0.5 - cz).length() <= r:
				grid[Vector3i(x, y, z)] = slot

# ---------- grid ops (from gen_voxel_stubs) ----------
func _fill(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				grid[Vector3i(x, y, z)] = slot

func _slot(target: Color) -> int:
	var best := INF; var pick := 0
	for i in 256:
		var c := _palette.get_pixel(i, 0)
		if c.r + c.g + c.b < 0.06:
			continue
		var dd := Vector3(c.r - target.r, c.g - target.g, c.b - target.b).length()
		if dd < best:
			best = dd; pick = i
	return pick

# ---------- writers (from gen_voxel_stubs): .vox + .obj/.mtl/.png, base at y=0, centred in x/z ----------
func _emit(dir: String, name: String, w: int, d: int, h: int) -> void:
	_write_vox(dir + name + ".vox", Vector3i(w, d, h))
	_write_obj(dir, name, Vector3(w * 0.5, 0.0, d * 0.5))

const FACES := [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
]

func _write_obj(dir: String, model: String, center: Vector3) -> void:
	var v_lines := PackedStringArray(); var vt_lines := PackedStringArray()
	var vn_lines := PackedStringArray(); var f_lines := PackedStringArray()
	var vt_index := {}
	for fi in FACES.size():
		var n: Vector3i = FACES[fi][0]
		vn_lines.append("vn %d %d %d" % [n.x, n.y, n.z])
	var vcount := 0
	for key in grid:
		var slot: int = grid[key]
		if not vt_index.has(slot):
			vt_index[slot] = vt_index.size() + 1
			vt_lines.append("vt %.6f 0.5" % [(slot + 0.5) / 256.0])
		for fi in FACES.size():
			if grid.has(key + (FACES[fi][0] as Vector3i)):
				continue
			var ids := PackedInt32Array()
			for corner in FACES[fi][1]:
				var p: Vector3 = Vector3(key) + corner
				v_lines.append("v %.4f %.4f %.4f" % [(p.x - center.x) * VOX, (p.y - center.y) * VOX, (p.z - center.z) * VOX])
				vcount += 1; ids.append(vcount)
			var vt: int = vt_index[slot]
			f_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d" % [
				ids[0], vt, fi + 1, ids[1], vt, fi + 1, ids[2], vt, fi + 1, ids[3], vt, fi + 1])
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".obj"), FileAccess.WRITE)
	f.store_string("mtllib %s.mtl\nusemtl palette\n" % model + "\n".join(v_lines) + "\n" + "\n".join(vt_lines) + "\n" + "\n".join(vn_lines) + "\n" + "\n".join(f_lines) + "\n")
	var mtl := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".mtl"), FileAccess.WRITE)
	mtl.store_string("newmtl palette\nKd 1 1 1\nmap_Kd %s.png\n" % model)
	_palette.save_png(ProjectSettings.globalize_path(dir + model + ".png"))

func _write_vox(path: String, mv_size: Vector3i) -> void:
	var xyzi := StreamPeerBuffer.new()
	xyzi.put_32(grid.size())
	for key in grid:
		xyzi.put_u8(key.x); xyzi.put_u8(key.z); xyzi.put_u8(key.y); xyzi.put_u8(grid[key] + 1)
	var size_c := StreamPeerBuffer.new()
	size_c.put_32(mv_size.x); size_c.put_32(mv_size.y); size_c.put_32(mv_size.z)
	var rgba := StreamPeerBuffer.new()
	for i in 256:
		var c := _palette.get_pixel(i, 0)
		rgba.put_u8(int(c.r * 255.0)); rgba.put_u8(int(c.g * 255.0)); rgba.put_u8(int(c.b * 255.0)); rgba.put_u8(255)
	var children := _chunk("SIZE", size_c.data_array) + _chunk("XYZI", xyzi.data_array) + _chunk("RGBA", rgba.data_array)
	var out := StreamPeerBuffer.new()
	out.put_data("VOX ".to_ascii_buffer()); out.put_32(150)
	out.put_data("MAIN".to_ascii_buffer()); out.put_32(0); out.put_32(children.size()); out.put_data(children)
	var wf := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	wf.store_buffer(out.data_array)

func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_data(id.to_ascii_buffer()); b.put_32(content.size()); b.put_32(0); b.put_data(content)
	return b.data_array
