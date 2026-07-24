extends SceneTree
## Writes STUB HUD art: the broadcast channel bug and a default driver avatar (art-ui-hud-gfx).
## Deliberately crude, flat and pixel-scale so they read as placeholders and sit correctly against
## the pixel font — real art replaces the files, not the code.
## Run: godot --headless --script res://scripts/tools/gen_hud_stubs.gd

const OUT := "res://assets/ui/"
const WHITE := Color(0.95, 0.97, 1.0, 1.0)
const CLEAR := Color(0, 0, 0, 0)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_logo().save_png(ProjectSettings.globalize_path(OUT + "channel_logo.png"))
	_avatar().save_png(ProjectSettings.globalize_path(OUT + "avatar_default.png"))
	print("hud stubs -> channel_logo.png, avatar_default.png")
	quit()

## Channel bug: a play chevron with two trailing speed bars. Abstract on purpose — it should read
## as "a broadcaster's logo goes here", not as final branding.
func _logo() -> Image:
	var w := 64
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	# chevron
	for y in h:
		var d: int = mini(y, h - 1 - y)          # distance to the vertical centre
		for x in range(4 + d, 4 + d + 5):
			if x < w:
				img.set_pixel(x, y, WHITE)
	# trailing bars, shortest at the bottom
	var bars := [[6, 34], [10, 26], [14, 18]]
	for i in bars.size():
		var row: Array = bars[i]
		var y0: int = 4 + i * 6
		for y in range(y0, mini(y0 + 4, h)):
			for x in range(22, 22 + int(row[1])):
				if x < w:
					img.set_pixel(x, y, WHITE)
	return img

## Driver avatar: a head-and-shoulders bust. A helmet was tried first and read as a broken circle
## at this size — a bust is unmistakably "a person" even at 32 px, which is all a placeholder
## portrait has to achieve.
func _avatar() -> Image:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	_disc(img, 16.0, 11.0, 6.5, s)              # head
	_disc(img, 16.0, 33.0, 12.5, s, 21)         # shoulders, clipped to the lower band
	return img

## Filled ellipse-ish disc, optionally only from row `from_y` down.
func _disc(img: Image, cx: float, cy: float, r: float, s: int, from_y := 0) -> void:
	for y in range(from_y, s):
		for x in s:
			var dx := (x - cx) / r
			var dy := (y - cy) / r
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, WHITE)
