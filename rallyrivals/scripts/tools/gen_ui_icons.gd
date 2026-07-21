extends SceneTree
## Starter UI icon set (art-ui-theme): assets/ui/icons/*.png. Chunky 16x16 pixel glyphs scaled 4x
## to 64px with nearest-neighbour crispness kept by the import preset, drawn in the master palette
## so they sit with the voxel look. Hand-authored bitmaps — one char grid per icon.
##   '.' outline/dark   '#' body   '+' accent   'o' highlight   ' ' transparent
## Run: godot --headless --script res://scripts/tools/gen_ui_icons.gd

const DIR := "res://assets/ui/icons/"
const SCALE := 4

const PAL := {
	".": Color(0.05, 0.05, 0.07),     # outline
	"#": Color(0.95, 0.92, 0.85),     # cream body
	"+": Color("a10b2b"),             # carmine accent
	"o": Color("f5f5b8"),             # sulphur highlight
	"g": Color(0.82, 0.68, 0.38),     # gold
}

# 16x16 icons.
const ICONS := {
	"speed": [
		"                ",
		"    ......      ",
		"   .######.     ",
		"  .##....##.    ",
		" .##..o...##.   ",
		" .#..oo....#.   ",
		" .#.oo..+..#.   ",
		" .#o...+++.#.   ",
		" .#....+...#.   ",
		" .##......##.   ",
		"  .##....##.    ",
		"   .######.     ",
		"    ......      ",
		"                ",
		"                ",
		"                ",
	],
	"lap": [
		" .              ",
		" .#.......       ",
		" .########.      ",
		" .#oo##oo#.      ",
		" .#oo##oo#.      ",
		" .########.      ",
		" .#oo##oo#.      ",
		" .#oo##oo#.      ",
		" .########.      ",
		" .......           ",
		" .#.            ",
		" .#.            ",
		" .#.            ",
		" .#.            ",
		" ..             ",
		"                ",
	],
	"timer": [
		"      ..        ",
		"     .##.       ",
		"   ...##...      ",
		"  .########.    ",
		" .##..#...##.   ",
		" .#...#....#.   ",
		" .#...#....#.   ",
		" .#...###..#.   ",
		" .#........#.   ",
		" .#........#.   ",
		"  .########.    ",
		"   .######.     ",
		"    ......      ",
		"                ",
		"                ",
		"                ",
	],
	"trophy": [
		" .##########.   ",
		" .gggggggggg.   ",
		" .g.gggggg.g.   ",
		" .g.gggggg.g.   ",
		" .g.gggggg.g.   ",
		"  .g.gggg.g.    ",
		"   .gggggg.     ",
		"    .gggg.      ",
		"     .gg.       ",
		"     .gg.       ",
		"    .####.      ",
		"   .######.     ",
		"   .######.     ",
		"    ......      ",
		"                ",
		"                ",
	],
	"money": [
		"    ......      ",
		"   .gggggg.     ",
		"  .gg.oo.gg.    ",
		" .gg.o..o.gg.   ",
		" .g..o....g..   ",
		" .g..oo...g..   ",
		" .g...oo..g..   ",
		" .g....o..g..   ",
		" .gg.o..o.gg.   ",
		"  .gg.oo.gg.    ",
		"   .gggggg.     ",
		"    ......      ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
	"cp": [
		"       oo       ",
		"       ..       ",
		"      .oo.      ",
		"   ...+oo+...   ",
		"   .+oooooo+.   ",
		"    .+oooo+.    ",
		"    .oo..oo.    ",
		"   .+o.  .o+.   ",
		"   ..      ..   ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
		"                ",
	],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for name in ICONS:
		var rows: Array = ICONS[name]
		var w := 16 * SCALE
		var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			var line: String = rows[y]
			for x in mini(line.length(), 16):
				var ch := line[x]
				if PAL.has(ch):
					img.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), PAL[ch])
		img.save_png(ProjectSettings.globalize_path(DIR + name + ".png"))
		print("icon: ", name)
	quit()
