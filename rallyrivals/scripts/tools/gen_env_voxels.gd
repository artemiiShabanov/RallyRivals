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
	var window := _slot(Color(0.60, 0.74, 0.90))
	var door := _slot(Color(0.28, 0.19, 0.11))
	var wall2 := _slot(Color(0.64, 0.56, 0.42))
	var white := _slot(Color(0.92, 0.93, 0.96))
	var red := _slot(Color(0.72, 0.20, 0.17))
	var stone := _slot(Color(0.50, 0.48, 0.46))

	# --- backdrop silhouettes ---
	_build_ridge(rock, snow, 7);      _emit(dir, "ridge", 96, 24, 52)          # smoother, snowier (Alpine)
	_build_ridge(rock_dark, rock, 3); _emit(dir, "ridge_volcanic", 96, 24, 52) # (Island)
	_build_mesa(sand);                _emit(dir, "mesa", 168, 60, 16)          # wide, low, eroded (Dunes)
	_build_treeline(foliage, trunk);  _emit(dir, "treeline", 88, 52, 16)       # small round conifers, 4 rows (Backwoods)
	# --- buildings ---
	_build_house(wall, wall2, roof, window, door);  _emit(dir, "house", 48, 60, 96)
	_build_hall(timber, roof, window, door);        _emit(dir, "hall", 72, 120, 60)
	_build_tower(metal, roof, window);              _emit(dir, "tower", 30, 30, 152)
	_build_lighthouse(white, red, window);          _emit(dir, "lighthouse", 28, 28, 140)   # Island
	_build_chalet(timber, stone, roof, window);     _emit(dir, "chalet", 50, 58, 94)        # Alpine village

	print("env voxels: 9 models -> ", dir)
	quit()

# ---------- models (grid: x=width, y=height, z=depth) ----------
# A jagged mountain-wall segment: a heightfield ridge, snow-capped on the tall peaks. `oct` shifts the
# high-frequency octave so ridge vs ridge_volcanic read as different mountains (variety).
func _build_ridge(rock: int, cap: int, oct: int) -> void:
	grid = {}
	var w := 96; var d := 24
	for x in w:
		var edge: float = minf(float(x), float(w - 1 - x)) / (w * 0.5)   # taper the ends down
		for z in d:
			var dz: float = 1.0 - absf(z + 0.5 - d * 0.5) / (d * 0.5)    # thin front-to-back
			var h := 30.0 + 15.0 * sin(x * 0.06) + 7.0 * sin(x * 0.15 + 1.3)   # low freqs -> rounded, less zigzag
			h += 3.0 * sin(x * 0.4 + float(oct))                              # a little variation between models
			h = h * clampf(0.3 + 0.7 * edge, 0.0, 1.0) * (0.5 + 0.5 * dz)
			var hi := clampi(int(h), 1, 51)
			for y in hi:
				grid[Vector3i(x, y, z)] = cap if (y >= hi - 14 and hi > 22) else rock   # deeper snow caps

# A wide, low, eroded butte: rolling top with gullies + battered sides (Dunes salt-flat mesas).
func _build_mesa(rock: int) -> void:
	grid = {}
	var w := 168; var d := 60; var h := 16
	for x in w:
		for z in d:
			var e := 12.0 + 2.5 * sin(x * 0.13) + 2.0 * sin(z * 0.2 + 1.0)          # rolling top
			e -= 4.0 * maxf(0.0, sin(x * 0.5) * sin(z * 0.4))                        # gullies (erosion)
			var edge: float = minf(minf(float(x), float(w - 1 - x)), minf(float(z), float(d - 1 - z)))
			e *= clampf(edge / 6.0, 0.0, 1.0)                                        # battered sides
			var hi := clampi(int(e), 0, h)
			for y in hi:
				grid[Vector3i(x, y, z)] = rock

# Small, rounded conifers in 4 staggered rows — depth + less blocky (Backwoods forest).
func _build_treeline(foliage: int, trunk: int) -> void:
	grid = {}
	var w := 88
	for ri in 4:
		var rz := 8 + ri * 12
		var x := 8 + (ri % 2) * 6
		while x < w - 8:
			_conifer(x, rz, foliage, trunk, 8 + ((x + rz) % 5))
			x += 12

func _conifer(cx: int, cz: int, foliage: int, trunk: int, top: int) -> void:
	_fill(cx, cx, 0, 2, cz, cz, trunk)
	for l in top:
		var r := (1.0 - float(l) / float(top)) * 3.5 + 0.6   # smooth round taper -> detail
		_disc(float(cx) + 0.5, float(cz) + 0.5, r, 2 + l, foliage)

# A tall multi-storey house: two wall tones (floor-line bands), window rows per floor, a door, a roof.
func _build_house(wall: int, wall2: int, roof: int, window: int, door: int) -> void:
	grid = {}
	var w := 48; var d := 60; var floors := 3; var fh := 24
	var top := floors * fh
	_fill(2, w - 3, 0, top, 2, d - 3, wall)
	for fl in range(1, floors):                                  # a contrasting band at each floor line
		_paint(2, w - 3, fl * fh - 1, fl * fh, 2, d - 3, wall2)
	_paint(2, w - 3, 0, 3, 2, d - 3, wall2)                       # plinth
	for fl in floors:
		var yb := 8 + fl * fh
		for wx in range(7, w - 7, 11):
			_paint(wx, wx + 4, yb, yb + 12, 2, 2, window)
			_paint(wx, wx + 4, yb, yb + 12, d - 3, d - 3, window)
		for wz in range(7, d - 7, 11):
			_paint(2, 2, yb, yb + 12, wz, wz + 4, window)
			_paint(w - 3, w - 3, yb, yb + 12, wz, wz + 4, window)
	_paint(int(w / 2) - 3, int(w / 2) + 3, 0, 16, 2, 2, door)
	for dy in 18:
		_fill(2 + dy, w - 3 - dy, top + dy, top + dy, 0, d - 1, roof)

# A long warehouse/barn: side window strips, a big door, a broad low gable.
func _build_hall(wall: int, roof: int, window: int, door: int) -> void:
	grid = {}
	var w := 72; var d := 120; var wh := 40
	_fill(2, w - 3, 0, wh, 2, d - 3, wall)
	for wz in range(12, d - 12, 14):
		_paint(2, 2, 12, 28, wz, wz + 6, window)
		_paint(w - 3, w - 3, 12, 28, wz, wz + 6, window)
	_paint(int(w / 2) - 6, int(w / 2) + 6, 0, 24, 2, 2, door)
	for dy in 18:
		_fill(2 + dy, w - 3 - dy, wh + dy, wh + dy, 0, d - 1, roof)

# A tall round silo/tower with banded window rings and a conical cap.
func _build_tower(body: int, cap: int, window: int) -> void:
	grid = {}
	var c := 14.5
	for y in 138:
		_disc(c, c, 13.0, y, body)
	for k in 6:                                  # window/detail bands up the shaft
		_disc(c, c, 13.0, 22 + k * 18, window)
		_disc(c, c, 13.0, 23 + k * 18, window)
	for k in 14:
		_disc(c, c, 13.0 - k * 0.9, 138 + k, cap)

# A lighthouse: tapered WHITE tower with RED bands, a glass lantern head, a red dome cap.
func _build_lighthouse(white: int, red: int, glass: int) -> void:
	grid = {}
	var c := 13.5
	for y in 108:
		_disc(c, c, 12.0 - y * 0.03, y, white)          # tapered white shaft
	for k in 4:                                          # red bands
		for yy in 8:
			var yb := 16 + k * 24 + yy
			_disc(c, c, 12.0 - yb * 0.03, yb, red)
	_disc(c, c, 11.0, 108, red); _disc(c, c, 11.0, 109, red)   # gallery rim
	for y in range(111, 126):
		_disc(c, c, 8.0, y, glass)                       # lantern room (glass)
	for k in 10:
		_disc(c, c, 9.0 - k, 126 + k, red)               # red dome

# An alpine chalet: stone base, timber upper with window rows, a steep gable roof.
func _build_chalet(timber: int, stone: int, roof: int, window: int) -> void:
	grid = {}
	var w := 50; var d := 58
	_fill(2, w - 3, 0, 14, 2, d - 3, stone)
	_fill(2, w - 3, 14, 46, 2, d - 3, timber)
	for wx in range(9, w - 9, 12):
		_paint(wx, wx + 5, 20, 34, 2, 2, window)
		_paint(wx, wx + 5, 20, 34, d - 3, d - 3, window)
	_paint(int(w / 2) - 4, int(w / 2) + 4, 0, 18, 2, 2, timber)   # door
	for dy in 30:                                        # steep gable
		_fill(2 + dy, w - 3 - dy, 46 + dy, 46 + dy, 0, d - 1, roof)

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

# Recolour only voxels that already exist (windows/doors on a wall surface).
func _paint(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				if grid.has(Vector3i(x, y, z)):
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
