extends SceneTree
## Scaffolds the whole voxel-model inventory (ADR-003 pipeline) so filling is "open the .vox
## in MagicaVoxel, sculpt, re-export over the stub":
##   assets/voxels/cars/<id>.vox|.obj|.mtl|.png        base shell (blockout tinted per brand)
##   assets/voxels/cars/<id>_d1|_d2.*                  damage-variant slots (copies for now)
##   assets/voxels/wheels/wheel_<brand>.*              shared voxel wheel, axle along X
## .vox files are REAL MagicaVoxel files (VOX 150) with the master palette embedded — they are
## the sources to sculpt over. .obj/.png follow the MV export conventions (palette-texel UVs).
## Reads the roster from assets/cars/*.tres. Run:
##   godot --headless --script res://scripts/tools/gen_voxel_stubs.gd

const VOX := 0.1
const W := 18
const H := 12
const L := 40
const Y0 := -0.45

const GLASS := 34
const LIGHT := 71
# brand -> [body, body_dark, under, accent]
const BRAND_SLOTS := {
	"apex": [39, 37, 36, 66],
	"wreck": [45, 43, 42, 67],
	"mayfly": [51, 49, 48, 68],
}

var grid := {}
var _palette: Image

func _initialize() -> void:
	_palette = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	var cars_dir := "res://assets/voxels/cars/"
	var wheels_dir := "res://assets/voxels/wheels/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cars_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(wheels_dir))

	var count := 0
	for f in DirAccess.open("res://assets/cars").get_files():
		if f.get_extension() != "tres":
			continue
		var def := load("res://assets/cars/".path_join(f)) as CarDef
		if def == null:
			continue
		_build_car(BRAND_SLOTS[def.brand])
		for variant in ["", "_d1", "_d2"]:
			var model: String = def.id + variant
			_write_vox(cars_dir + model + ".vox", Vector3i(W, L, H))
			_write_obj(cars_dir, model, Vector3(W * 0.5, -Y0 / VOX, L * 0.5))
			count += 1
	for brand in BRAND_SLOTS:
		_build_wheel(BRAND_SLOTS[brand][3])
		_write_vox(wheels_dir + "wheel_" + brand + ".vox", Vector3i(3, 8, 8))
		_write_obj(wheels_dir, "wheel_" + brand, Vector3(1.5, 4.0, 4.0))
	print("voxel stubs: %d car models + %d wheels" % [count, BRAND_SLOTS.size()])
	quit()

# ---------- car shell (the block-out, brand-tinted) ----------
func _fill(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				grid[Vector3i(x, y, z)] = slot

func _carve(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				grid.erase(Vector3i(x, y, z))

func _paint(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				if grid.has(Vector3i(x, y, z)):
					grid[Vector3i(x, y, z)] = slot

func _build_car(slots: Array) -> void:
	grid = {}
	var body: int = slots[0]
	var dark: int = slots[1]
	var under: int = slots[2]
	var accent: int = slots[3]
	_fill(3, 14, 0, 1, 3, 36, under)
	_fill(1, 16, 2, 5, 1, 38, body)
	_paint(1, 16, 2, 2, 1, 38, dark)
	for zr in [[3, 9], [30, 36]]:
		_carve(1, 3, 0, 4, zr[0], zr[1])
		_carve(14, 16, 0, 4, zr[0], zr[1])
	_carve(1, 16, 5, 5, 35, 38)
	_carve(1, 16, 5, 5, 1, 3)
	_fill(4, 13, 6, 9, 13, 27, dark)
	_carve(4, 13, 9, 9, 24, 27)
	_carve(4, 13, 8, 8, 26, 27)
	_carve(4, 13, 9, 9, 13, 14)
	_paint(4, 4, 6, 8, 16, 23, GLASS)
	_paint(13, 13, 6, 8, 16, 23, GLASS)
	_paint(5, 12, 6, 8, 24, 27, GLASS)
	_paint(5, 12, 6, 8, 13, 14, GLASS)
	_paint(8, 9, 5, 5, 1, 38, accent)
	_paint(8, 9, 9, 9, 13, 27, accent)
	_paint(2, 4, 3, 4, 38, 38, LIGHT)
	_paint(13, 15, 3, 4, 38, 38, LIGHT)
	_paint(2, 4, 3, 4, 1, 1, accent)
	_paint(13, 15, 3, 4, 1, 1, accent)

# ---------- wheel (axle along X: spins in the y/z plane like VehicleWheel3D) ----------
# 8x8 disc, outer corners at exactly +/-0.4 m = the physics wheel_radius (no visual float).
func _build_wheel(hub_slot: int) -> void:
	grid = {}
	for x in 3:
		for y in 8:
			for z in 8:
				var d := Vector2(y + 0.5 - 4.0, z + 0.5 - 4.0).length()
				if d <= 3.55:
					grid[Vector3i(x, y, z)] = hub_slot if (x > 0 and d <= 1.8) else 36

# ---------- writers ----------
const FACES := [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
]

## OBJ + MTL + palette PNG in MV-export conventions; `center` is the grid point that lands at
## the mesh origin (in voxels; y component = -Y0 in voxels for cars, envelope middle for wheels).
func _write_obj(dir: String, model: String, center: Vector3) -> void:
	var v_lines := PackedStringArray()
	var vt_lines := PackedStringArray()
	var vn_lines := PackedStringArray()
	var f_lines := PackedStringArray()
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
				vcount += 1
				ids.append(vcount)
			var vt: int = vt_index[slot]
			f_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d" % [
				ids[0], vt, fi + 1, ids[1], vt, fi + 1, ids[2], vt, fi + 1, ids[3], vt, fi + 1])
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".obj"), FileAccess.WRITE)
	f.store_string("mtllib %s.mtl\nusemtl palette\n" % model + "\n".join(v_lines) + "\n" + "\n".join(vt_lines) + "\n" + "\n".join(vn_lines) + "\n" + "\n".join(f_lines) + "\n")
	var mtl := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".mtl"), FileAccess.WRITE)
	mtl.store_string("newmtl palette\nKd 1 1 1\nmap_Kd %s.png\n" % model)
	_palette.save_png(ProjectSettings.globalize_path(dir + model + ".png"))

## Real MagicaVoxel file (VOX 150: MAIN > SIZE + XYZI + RGBA). MV is z-up: our y (height)
## becomes MV z, our z (length) becomes MV y. Palette embedded so sculpting starts on-ramp.
func _write_vox(path: String, mv_size: Vector3i) -> void:
	var xyzi := StreamPeerBuffer.new()
	xyzi.put_32(grid.size())
	for key in grid:
		xyzi.put_u8(key.x)
		xyzi.put_u8(key.z)
		xyzi.put_u8(key.y)
		xyzi.put_u8(grid[key] + 1)   # colour indices are 1-based
	var size_c := StreamPeerBuffer.new()
	size_c.put_32(mv_size.x)
	size_c.put_32(mv_size.y)
	size_c.put_32(mv_size.z)
	var rgba := StreamPeerBuffer.new()
	for i in 256:
		var c := _palette.get_pixel(i, 0) if i < 256 else Color.BLACK
		rgba.put_u8(int(c.r * 255.0))
		rgba.put_u8(int(c.g * 255.0))
		rgba.put_u8(int(c.b * 255.0))
		rgba.put_u8(255)
	var children := _chunk("SIZE", size_c.data_array) + _chunk("XYZI", xyzi.data_array) + _chunk("RGBA", rgba.data_array)
	var out := StreamPeerBuffer.new()
	out.put_data("VOX ".to_ascii_buffer())
	out.put_32(150)
	out.put_data("MAIN".to_ascii_buffer())
	out.put_32(0)
	out.put_32(children.size())
	out.put_data(children)
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_buffer(out.data_array)

func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_data(id.to_ascii_buffer())
	b.put_32(content.size())
	b.put_32(0)
	b.put_data(content)
	return b.data_array
