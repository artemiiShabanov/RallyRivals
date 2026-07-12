extends SceneTree
## Writes 4 SAMPLE track images to assets/tracks/demo/ for the baker to consume. Real tracks are
## hand-painted; this just produces a valid demo set. Crucially, road/off-road colours are taken
## from the actual SurfaceType .tres files, so bake-time classification maps each pixel back to
## the right surface. Run: godot --headless --script res://scripts/track/gen_demo_images.gd

const SIZE := 384
const ROAD_HW_PX := 8       # flat road half-width (surface COLOUR) in pixels
const EDGE_PX := 4          # anti-aliased colour edge width (road -> off-road)
const FLAT_HW_PX := 12      # flat HEIGHT half-width — must cover road colour+edge (ROAD_HW+EDGE) so
                            # no drivable pixel sits on the shoulder ramp (kills the edge lip / invisible bump)
const SHOULDER_PX := 28     # wide, soft ramp from flat road to natural terrain (no steep lip)
const TERRAIN_AMP := 0.12   # off-road undulation amplitude AROUND the local road height (cut-and-fill:
                            # keeps terrain near the track gentle instead of absolute 0..1 hills)

# Marker + race palettes (must match TrackBaker.M_* / R_*).
const START := Color8(255, 0, 255)
const STARTDIR := Color8(255, 255, 0)
const GATE := Color8(0, 255, 0)
const TREE := Color8(255, 0, 0)
const ROCK := Color8(0, 0, 255)
const GATE_HW_PX := 14      # gate dot offset from centreline — just past road colour+edge (8+4),
                            # so gates span the road plus a forgiving strip of shoulder

var _asphalt: Color
var _dirt: Color
var _ice: Color
var _offroad: Color

func _initialize() -> void:
	var dir := "res://assets/tracks/demo/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# Pull surface colours from the real resources so bake-time classification agrees.
	_asphalt = (load("res://assets/surfaces/asphalt.tres") as SurfaceType).color
	_dirt = (load("res://assets/surfaces/dirt.tres") as SurfaceType).color
	_ice = (load("res://assets/surfaces/ice.tres") as SurfaceType).color
	_offroad = (load("res://assets/surfaces/sand.tres") as SurfaceType).color

	var hm := Image.create(SIZE, SIZE, false, Image.FORMAT_RF)   # 32-bit float height
	var sf := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var mk := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rc := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02

	# Wavy closed-loop road as waypoints in pixel space.
	var n := 150
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var wps: Array[Vector2] = []
	for i in n:
		var a := TAU * i / n
		var rr := SIZE * 0.32 + SIZE * 0.08 * sin(a * 3.0)
		wps.append(c + Vector2(cos(a), sin(a)) * rr)

	for y in SIZE:
		for x in SIZE:
			var px := Vector2(x, y)
			var best := INF
			var bi := 0
			for i in n:
				var d2 := px.distance_squared_to(wps[i])
				if d2 < best:
					best = d2; bi = i
			# Refine onto the two adjacent centreline segments -> continuous arc-param + true
			# perpendicular distance (flat cross-sections, clean parallel edges).
			var dperp := INF
			var param := 0.0
			for off in [-1, 0]:
				var ia := (bi + int(off) + n) % n
				var ib := (ia + 1) % n
				var a: Vector2 = wps[ia]
				var b: Vector2 = wps[ib]
				var ab := b - a
				var tt := clampf((px - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var dd := px.distance_to(a + ab * tt)
				if dd < dperp:
					dperp = dd; param = (float(ia) + tt) / n
			var frac := fposmod(param, 1.0)
			var road_h: float = 0.42 + 0.12 * sin(TAU * frac * 2.0)
			# Off-road terrain undulates AROUND the nearby road height (cut-and-fill), so the
			# shoulder never has to climb metres to meet it -> no lip, gentle off-road.
			var natural: float = clampf(road_h + noise.get_noise_2d(x, y) * TERRAIN_AMP, 0.0, 1.0)
			# Height: flat corridor covers the full drivable width, then a wide soft shoulder.
			var h: float
			if dperp <= FLAT_HW_PX:
				h = road_h
			elif dperp <= FLAT_HW_PX + SHOULDER_PX:
				var t := (dperp - FLAT_HW_PX) / float(SHOULDER_PX)
				t = t * t * (3.0 - 2.0 * t)
				h = lerpf(road_h, natural, t)
			else:
				h = natural
			# Colour: crisp surface zone on the road, anti-aliased edge to off-road.
			var road_col := _surface_for(frac)
			var scol: Color
			if dperp <= ROAD_HW_PX:
				scol = road_col
			elif dperp <= ROAD_HW_PX + EDGE_PX:
				var te := (dperp - ROAD_HW_PX) / float(EDGE_PX)
				te = te * te * (3.0 - 2.0 * te)
				scol = road_col.lerp(_offroad, te)
			else:
				scol = _offroad
			hm.set_pixel(x, y, Color(h, 0, 0))
			sf.set_pixel(x, y, scol)
			mk.set_pixel(x, y, Color(0, 0, 0))

	# Race layer: start pair astride the road + a direction dot ahead, then 4 gate pairs.
	var d := (wps[1] - wps[0]).normalized()
	var perp := Vector2(-d.y, d.x)
	_dot(rc, wps[0] + perp * GATE_HW_PX, START)
	_dot(rc, wps[0] - perp * GATE_HW_PX, START)
	_dot(rc, wps[0] + d * 5.0, STARTDIR)
	for f in [0.2, 0.4, 0.6, 0.8]:
		var i := int(f * n)
		var gd := (wps[(i + 1) % n] - wps[(i - 1 + n) % n]).normalized()
		var gp := Vector2(-gd.y, gd.x)
		_dot(rc, wps[i] + gp * GATE_HW_PX, GATE)
		_dot(rc, wps[i] - gp * GATE_HW_PX, GATE)

	# Markers layer: world props only.
	for p in [Vector2(18, 18), Vector2(SIZE - 22, 26), Vector2(28, SIZE - 26), Vector2(SIZE * 0.5, 16)]:
		_setpx(mk, p, TREE)
	for p in [Vector2(SIZE - 18, SIZE - 18), Vector2(22, SIZE * 0.5)]:
		_setpx(mk, p, ROCK)

	hm.save_exr(dir + "heightmap.exr")
	sf.save_png(dir + "surface.png")
	mk.save_png(dir + "markers.png")
	rc.save_png(dir + "race.png")
	print("generated 4 demo images at ", SIZE, "x", SIZE, " -> ", dir)
	quit()

# Zone by fraction of the lap: asphalt -> dirt -> ice -> asphalt -> dirt.
func _surface_for(frac: float) -> Color:
	if frac < 0.25:
		return _asphalt
	elif frac < 0.45:
		return _dirt
	elif frac < 0.58:
		return _ice
	elif frac < 0.80:
		return _asphalt
	return _dirt

func _setpx(img: Image, p: Vector2, col: Color) -> void:
	img.set_pixel(clampi(int(round(p.x)), 0, SIZE - 1), clampi(int(round(p.y)), 0, SIZE - 1), col)

# 2x2 dot — blob centroids are what the baker reads, so dots don't need pixel precision.
func _dot(img: Image, p: Vector2, col: Color) -> void:
	for dy in 2:
		for dx in 2:
			img.set_pixel(clampi(int(round(p.x)) + dx, 0, SIZE - 1), clampi(int(round(p.y)) + dy, 0, SIZE - 1), col)
