extends SceneTree
## Generates the placeholder voxel car block-out (art-voxel-car-blockout) in the EXACT format
## MagicaVoxel exports (ADR-003): OBJ with per-face palette-texel UVs + MTL + palette PNG copy,
## 1 voxel = 0.1 m. Validates the Godot half of the voxel pipeline; real cars come from MV.
## All four corners of a face share the texel-centre UV, so filtering can never bleed colours.
## Writes assets/voxels/cars/blockout.{obj,mtl,png}.
## Run: godot --headless --script res://scripts/tools/gen_car_blockout.gd

const VOX := 0.1                       # metres per voxel (ADR-003)
const W := 18                          # x: width  (1.8 m)
const H := 12                          # y: height (1.2 m, base at world y -0.45)
const L := 40                          # z: length (4.0 m), +z = forward
const Y0 := -0.45                      # world y of voxel layer 0

# palette slots (assets/palette/README.md)
const BODY := 39        # apex mid graphite
const BODY_DARK := 37
const UNDER := 36
const GLASS := 34       # frost ice-light
const STRIPE := 66      # apex crimson
const LIGHT := 71       # near-white
const TAIL := 66

var grid := {}   # Vector3i -> palette slot

func _initialize() -> void:
	_build()
	var dir := "res://assets/voxels/cars/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write_obj(dir)
	var pal := Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	pal.save_png(ProjectSettings.globalize_path(dir + "blockout.png"))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + "blockout.mtl"), FileAccess.WRITE)
	f.store_string("newmtl palette\nKd 1 1 1\nmap_Kd blockout.png\n")
	print("blockout: %d voxels -> %s" % [grid.size(), dir])
	quit()

# ---------- the car ----------
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

func _build() -> void:
	_fill(3, 14, 0, 1, 3, 36, UNDER)          # undercarriage
	_fill(1, 16, 2, 5, 1, 38, BODY)           # main slab
	_paint(1, 16, 2, 2, 1, 38, BODY_DARK)     # rocker line
	for zr in [[3, 9], [30, 36]]:             # wheel arches (rear, front)
		_carve(1, 3, 0, 4, zr[0], zr[1])
		_carve(14, 16, 0, 4, zr[0], zr[1])
	_carve(1, 16, 5, 5, 35, 38)               # nose taper
	_carve(1, 16, 5, 5, 1, 3)                 # tail taper
	_fill(4, 13, 6, 9, 13, 27, BODY_DARK)     # cabin
	_carve(4, 13, 9, 9, 24, 27)               # windshield slope
	_carve(4, 13, 8, 8, 26, 27)
	_carve(4, 13, 9, 9, 13, 14)               # rear window slope
	_paint(4, 4, 6, 8, 16, 23, GLASS)         # side windows
	_paint(13, 13, 6, 8, 16, 23, GLASS)
	_paint(5, 12, 6, 8, 24, 27, GLASS)        # windshield
	_paint(5, 12, 6, 8, 13, 14, GLASS)        # rear window
	_paint(8, 9, 5, 5, 1, 38, STRIPE)         # bonnet/boot stripe
	_paint(8, 9, 9, 9, 13, 27, STRIPE)        # roof stripe
	_paint(2, 4, 3, 4, 38, 38, LIGHT)         # headlights
	_paint(13, 15, 3, 4, 38, 38, LIGHT)
	_paint(2, 4, 3, 4, 1, 1, TAIL)            # taillights
	_paint(13, 15, 3, 4, 1, 1, TAIL)

# ---------- meshing (exposed faces only; CCW winding seen from outside) ----------
const FACES := [
	[Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
	[Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3i(-1, 0, 0), [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]],
]

func _write_obj(dir: String) -> void:
	var v_lines := PackedStringArray()
	var vt_lines := PackedStringArray()
	var vn_lines := PackedStringArray()
	var f_lines := PackedStringArray()
	var vt_index := {}   # slot -> vt id
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
			var n: Vector3i = FACES[fi][0]
			if grid.has(key + n):
				continue
			var ids := PackedInt32Array()
			for corner in FACES[fi][1]:
				var p: Vector3 = Vector3(key) + corner
				v_lines.append("v %.4f %.4f %.4f" % [(p.x - W * 0.5) * VOX, p.y * VOX + Y0, (p.z - L * 0.5) * VOX])
				vcount += 1
				ids.append(vcount)
			var vt: int = vt_index[slot]
			f_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d" % [
				ids[0], vt, fi + 1, ids[1], vt, fi + 1, ids[2], vt, fi + 1, ids[3], vt, fi + 1])
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + "blockout.obj"), FileAccess.WRITE)
	f.store_string("mtllib blockout.mtl\nusemtl palette\n" + "\n".join(v_lines) + "\n" + "\n".join(vt_lines) + "\n" + "\n".join(vn_lines) + "\n" + "\n".join(f_lines) + "\n")
	print("faces: ", f_lines.size())
