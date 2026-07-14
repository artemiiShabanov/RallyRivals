extends SceneTree
## Authors the M1 gray-box test track (code-track-test-track): writes the 4 source images to
## assets/tracks/test/. Unlike gen_demo_images (a parametric circle), this is a DESIGNED layout —
## a Catmull-Rom centreline through hand-placed control points, with surface zones, height
## anchors and checkpoint gates all tied to layout features by control-point index.
## Run: godot --headless --script res://scripts/track/gen_test_track_images.gd
##
## Layout (512x512 px = 512 m, ~1.3 km lap, driven east from the start):
##   bottom start straight -> T1 -> climb up the right side -> crest at the top -> dirt S-curves
##   across the top -> down the left edge -> dirt hairpin -> asphalt mid-link -> ICE on the
##   descending corner -> back onto the straight.

const SIZE := 512
const ROAD_HW_PX := 8       # same proven corridor constants as gen_demo_images (no edge lip)
const EDGE_PX := 4
const FLAT_HW_PX := 12
const SHOULDER_PX := 28
const TERRAIN_AMP := 0.12

# Race palette (must match TrackBaker.R_*) + markers (M_*).
const START := Color8(255, 0, 255)
const STARTDIR := Color8(255, 255, 0)
const GATE := Color8(0, 255, 0)
const TREE := Color8(255, 0, 0)
const ROCK := Color8(0, 0, 255)
const GATE_HW_PX := 14

# The design: centreline control points (closed loop, image coords).
const CTRL: Array[Vector2] = [
	Vector2(90, 420),    #  0 start straight (drive east)
	Vector2(200, 420),   #  1
	Vector2(300, 414),   #  2 slight kink
	Vector2(385, 392),   #  3 T1 entry
	Vector2(440, 330),   #  4 climbing the right side
	Vector2(432, 250),   #  5
	Vector2(452, 172),   #  6 upper climb
	Vector2(398, 108),   #  7 T3 top-right
	Vector2(330, 92),    #  8 crest
	Vector2(278, 128),   #  9 S-curves (dirt)
	Vector2(222, 92),    # 10
	Vector2(166, 128),   # 11
	Vector2(112, 98),    # 12 S exit
	Vector2(68, 148),    # 13 down the left edge
	Vector2(66, 230),    # 14
	Vector2(98, 268),    # 15 hairpin
	Vector2(140, 246),   # 16
	Vector2(150, 205),   # 17 hairpin exit (heading north)
	Vector2(190, 190),   # 18 curl east
	Vector2(225, 235),   # 19 heading south
	Vector2(228, 300),   # 20 mid-link
	Vector2(190, 345),   # 21 ICE descending corner
	Vector2(140, 358),   # 22 ice run west
	Vector2(95, 368),    # 23 ice exit
	Vector2(62, 390),    # 24 horseshoe onto the straight (kept wide — a sharp vertex here
	Vector2(72, 412),    # 25 U-turns the baker's spline march)
]

# Surface zones by control-point index [from, to): asphalt unless listed.
const DIRT_ZONES := [[8.0, 17.0]]        # crest through S-curves + hairpin
const ICE_ZONES := [[20.0, 23.0]]        # the descending corner + west run
# Height anchors (control-point index -> 0..1 of max_height 28 m), smoothly interpolated.
const HEIGHTS := [[0.0, 0.30], [3.0, 0.30], [6.0, 0.55], [8.0, 0.62], [12.0, 0.55],
	[14.0, 0.44], [17.0, 0.40], [20.0, 0.38], [23.0, 0.31], [26.0, 0.30]]
# Gates by control-point index (start pair is separate, at index 0.35 on the straight).
const GATES := [3.0, 6.0, 8.0, 10.5, 14.0, 15.5, 19.0, 21.5]
const START_AT := 0.35

const TREES := [Vector2(44, 64), Vector2(302, 44), Vector2(478, 224), Vector2(352, 306), Vector2(84, 330)]
const ROCKS := [Vector2(34, 296), Vector2(206, 152), Vector2(470, 90)]

var _asphalt: Color
var _dirt: Color
var _ice: Color
var _offroad: Color

var _wps := PackedVector2Array()   # dense centreline (~3 px apart)
var _cum := PackedFloat32Array()   # cumulative arc length per dense point
var _cpfrac := PackedFloat32Array()  # lap fraction of each control point
var _total := 0.0

func _initialize() -> void:
	var dir := "res://assets/tracks/test/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_asphalt = (load("res://assets/surfaces/asphalt.tres") as SurfaceType).color
	_dirt = (load("res://assets/surfaces/dirt.tres") as SurfaceType).color
	_ice = (load("res://assets/surfaces/ice.tres") as SurfaceType).color
	_offroad = (load("res://assets/surfaces/sand.tres") as SurfaceType).color
	_sample_centreline()

	var hm := Image.create(SIZE, SIZE, false, Image.FORMAT_RF)
	var sf := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var mk := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rc := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.015

	var n := _wps.size()
	var coarse := PackedVector2Array()   # every 4th dense point, for the cheap nearest pass
	for i in range(0, n, 4):
		coarse.append(_wps[i])
	for y in SIZE:
		for x in SIZE:
			var px := Vector2(x, y)
			var cb := 0
			var best := INF
			for i in coarse.size():
				var d2 := px.distance_squared_to(coarse[i])
				if d2 < best:
					best = d2; cb = i
			# Refine on the dense points around the coarse hit, then project onto the two
			# adjacent segments -> true perpendicular distance + continuous lap fraction.
			var bi := cb * 4
			var bd := INF
			for i in range(bi - 5, bi + 6):
				var ii := (i + n) % n
				var d2 := px.distance_squared_to(_wps[ii])
				if d2 < bd:
					bd = d2; bi = ii
			var dperp := INF
			var arc := 0.0
			for off in [-1, 0]:
				var ia := (bi + int(off) + n) % n
				var ib := (ia + 1) % n
				var a := _wps[ia]
				var b := _wps[ib]
				var ab := b - a
				var tt := clampf((px - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var dd := px.distance_to(a + ab * tt)
				if dd < dperp:
					dperp = dd
					arc = _cum[ia] + ab.length() * tt
			var frac := fposmod(arc / _total, 1.0)
			var road_h := _road_height(frac)
			var natural := clampf(road_h + noise.get_noise_2d(x, y) * TERRAIN_AMP, 0.0, 1.0)
			var h: float
			if dperp <= FLAT_HW_PX:
				h = road_h
			elif dperp <= FLAT_HW_PX + SHOULDER_PX:
				var t := (dperp - FLAT_HW_PX) / float(SHOULDER_PX)
				t = t * t * (3.0 - 2.0 * t)
				h = lerpf(road_h, natural, t)
			else:
				h = natural
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

	# Race layer: start pair + direction on the straight, gate pairs at the designed corners.
	var sp := _at_index(START_AT)
	var sd := _tangent_at(sp)
	var sperp := Vector2(-sd.y, sd.x)
	_dot(rc, sp + sperp * GATE_HW_PX, START)
	_dot(rc, sp - sperp * GATE_HW_PX, START)
	_dot(rc, sp + sd * 6.0, STARTDIR)
	for g in GATES:
		var gp := _at_index(g)
		var gd := _tangent_at(gp)
		var gperp := Vector2(-gd.y, gd.x)
		_dot(rc, gp + gperp * GATE_HW_PX, GATE)
		_dot(rc, gp - gperp * GATE_HW_PX, GATE)

	# Markers are SINGLE pixels: the baker spawns one prop per matching pixel (no blob merge).
	for p in TREES:
		mk.set_pixel(int(p.x), int(p.y), TREE)
	for p in ROCKS:
		mk.set_pixel(int(p.x), int(p.y), ROCK)

	hm.save_exr(dir + "heightmap.exr")
	sf.save_png(dir + "surface.png")
	mk.save_png(dir + "markers.png")
	rc.save_png(dir + "race.png")
	print("test track authored: ", SIZE, "x", SIZE, "  lap %.0f px  -> " % _total, dir)
	quit()

# ---------- centreline ----------
# Closed Catmull-Rom through CTRL, sampled every ~3 px; records arc length + control-point fracs.
func _sample_centreline() -> void:
	var m := CTRL.size()
	var cp_at := PackedInt32Array()
	for i in m:
		var p0 := CTRL[(i - 1 + m) % m]
		var p1 := CTRL[i]
		var p2 := CTRL[(i + 1) % m]
		var p3 := CTRL[(i + 2) % m]
		cp_at.append(_wps.size())
		var steps := maxi(4, int(p1.distance_to(p2) / 3.0))
		for s in steps:
			var t := float(s) / steps
			_wps.append(_catmull(p0, p1, p2, p3, t))
	_cum.resize(_wps.size())
	var acc := 0.0
	for i in _wps.size():
		_cum[i] = acc
		acc += _wps[i].distance_to(_wps[(i + 1) % _wps.size()])
	_total = acc
	_cpfrac.resize(m)
	for i in m:
		_cpfrac[i] = _cum[cp_at[i]] / _total

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

# Lap fraction of a (possibly fractional) control-point index.
func _index_frac(ci: float) -> float:
	var m := CTRL.size()
	var i := int(floor(ci)) % m
	var next_f := _cpfrac[(i + 1) % m]
	if i + 1 >= m:
		next_f = 1.0
	return lerpf(_cpfrac[i], next_f, ci - floor(ci))

# Dense point at a control-point index (via its lap fraction).
func _at_index(ci: float) -> Vector2:
	var target := _index_frac(ci) * _total
	for i in _wps.size():
		if _cum[i] >= target:
			return _wps[i]
	return _wps[0]

func _tangent_at(p: Vector2) -> Vector2:
	var bi := 0
	var best := INF
	for i in _wps.size():
		var d2 := p.distance_squared_to(_wps[i])
		if d2 < best:
			best = d2; bi = i
	var n := _wps.size()
	return (_wps[(bi + 2) % n] - _wps[(bi - 2 + n) % n]).normalized()

# ---------- zones ----------
func _surface_for(frac: float) -> Color:
	for z in ICE_ZONES:
		if frac >= _index_frac(z[0]) and frac < _index_frac(z[1]):
			return _ice
	for z in DIRT_ZONES:
		if frac >= _index_frac(z[0]) and frac < _index_frac(z[1]):
			return _dirt
	return _asphalt

func _road_height(frac: float) -> float:
	var pts := HEIGHTS
	for i in pts.size() - 1:
		var f0 := _index_frac(pts[i][0]) if pts[i][0] < CTRL.size() else 1.0
		var f1 := _index_frac(pts[i + 1][0]) if pts[i + 1][0] < CTRL.size() else 1.0
		if frac >= f0 and frac <= f1:
			var t := (frac - f0) / maxf(f1 - f0, 0.0001)
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(pts[i][1], pts[i + 1][1], t)
	return pts[0][1]

func _dot(img: Image, p: Vector2, col: Color) -> void:
	for dy in 2:
		for dx in 2:
			img.set_pixel(clampi(int(round(p.x)) + dx, 0, SIZE - 1), clampi(int(round(p.y)) + dy, 0, SIZE - 1), col)
