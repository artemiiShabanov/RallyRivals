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
	# One glyph per RaceDef.race_type, so the HUD can name the format at a glance.
	for id in ["circuit", "sprint", "time_trial", "endurance", "grand_prix"]:
		_race_icon(id).save_png(ProjectSettings.globalize_path(OUT + "race_%s.png" % id))
	print("hud stubs -> logo, avatar, 5 race-type icons")
	quit()

## Race-format glyphs, 24px, flat white. Each has to be told apart from the others at ~22px on the
## HUD, so they differ in SHAPE not detail: ring, arrow, clock, hourglass, podium.
func _race_icon(id: String) -> Image:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	match id:
		"circuit":                                   # closed loop
			_ring(img, 12.0, 12.0, 10.0, 6.0, s)
		"sprint":                                    # arrow into a finish post
			for y in range(6, 18):
				var d: int = absi(y - 12)
				for x in range(4 + d, 4 + d + 3):
					img.set_pixel(x, y, WHITE)
			for y in range(3, 21):
				for x in range(17, 20):
					img.set_pixel(x, y, WHITE)
		"time_trial":                                # clock: ring + two hands
			_ring(img, 12.0, 12.0, 10.0, 7.0, s)
			for y in range(6, 13):
				img.set_pixel(12, y, WHITE)
			for x in range(12, 18):
				img.set_pixel(x, 12, WHITE)
		"endurance":                                 # hourglass
			for y in range(4, 20):
				var k: int = 8 - absi(y - 12) if y != 12 else 1
				for x in range(12 - k, 12 + k):
					if y < 11 or y > 13 or absi(x - 12) < 2:
						img.set_pixel(x, y, WHITE)
		"grand_prix":                                # podium: 2nd, 1st, 3rd
			_bar(img, 3, 11, 6, 20, s)
			_bar(img, 10, 6, 6, 20, s)
			_bar(img, 17, 14, 5, 20, s)
	return img

func _ring(img: Image, cx: float, cy: float, r_out: float, r_in: float, s: int) -> void:
	for y in s:
		for x in s:
			var d := Vector2(x - cx, y - cy).length()
			if d <= r_out and d >= r_in:
				img.set_pixel(x, y, WHITE)

func _bar(img: Image, x0: int, y0: int, w: int, y1: int, s: int) -> void:
	for y in range(y0, mini(y1, s)):
		for x in range(x0, mini(x0 + w, s)):
			img.set_pixel(x, y, WHITE)

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
