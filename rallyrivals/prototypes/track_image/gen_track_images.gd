extends SceneTree
## ADR-002 — generate 3 SAMPLE track images. THROWAWAY prototype tool.
## Run headless:  godot --headless --script res://prototypes/track_image/gen_track_images.gd
## Produces heightmap.png (elevation), surface.png (surfaces+road), markers.png (start + props).
## Replace these PNGs with your own paintings later; the baker reads whatever's here.

const SIZE := 384
const ROAD_HW_PX := 8
const SHOULDER_PX := 11
const EDGE_PX := 4          # anti-aliased colour edge width (road -> grass)

# Surface palette (must match the baker).
const GRASS := Color8(72, 102, 51)
const ASPHALT := Color8(46, 46, 51)
const DIRT := Color8(115, 77, 41)
const ICE := Color8(209, 230, 245)
# Marker palette.
const START := Color8(255, 0, 255)
const STARTDIR := Color8(255, 255, 0)
const TREE := Color8(255, 0, 0)
const ROCK := Color8(0, 0, 255)

func _initialize() -> void:
	var dir := "res://prototypes/track_image/"
	var hm := Image.create(SIZE, SIZE, false, Image.FORMAT_RF)   # 32-bit float height (no 8-bit stair-steps)
	var sf := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var mk := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	# Wavy closed-loop road, as waypoints in pixel space.
	var n := 150
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var wps: Array[Vector2] = []
	for i in n:
		var a := TAU * i / n
		var rr := SIZE * 0.32 + SIZE * 0.08 * sin(a * 3.0)
		wps.append(c + Vector2(cos(a), sin(a)) * rr)
	# Per-pixel: nearest road waypoint decides road vs terrain, height, and surface.
	for y in SIZE:
		for x in SIZE:
			var px := Vector2(x, y)
			# Coarse nearest waypoint.
			var best := INF
			var bi := 0
			for i in n:
				var d2 := px.distance_squared_to(wps[i])
				if d2 < best:
					best = d2
					bi = i
			# Refine: project onto the two adjacent centreline segments -> a CONTINUOUS
			# arc-parameter and a TRUE perpendicular distance. This gives flat cross-sections
			# (no twist/bumps) and clean parallel road edges (no scalloping).
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
					dperp = dd
					param = (float(ia) + tt) / n
			var frac := fposmod(param, 1.0)
			var natural: float = noise.get_noise_2d(x, y) * 0.5 + 0.5
			var road_h: float = 0.42 + 0.12 * sin(TAU * frac * 2.0)
			# Height: flat road, smooth shoulder to natural terrain.
			var h: float
			if dperp <= ROAD_HW_PX:
				h = road_h
			elif dperp <= ROAD_HW_PX + SHOULDER_PX:
				var t := (dperp - ROAD_HW_PX) / float(SHOULDER_PX)
				t = t * t * (3.0 - 2.0 * t)
				h = lerpf(road_h, natural, t)
			else:
				h = natural
			# Colour: blended surface zones + anti-aliased road edge.
			var road_col := _zone_blend(frac)
			var scol: Color
			if dperp <= ROAD_HW_PX:
				scol = road_col
			elif dperp <= ROAD_HW_PX + EDGE_PX:
				var te := (dperp - ROAD_HW_PX) / float(EDGE_PX)
				te = te * te * (3.0 - 2.0 * te)
				scol = road_col.lerp(GRASS, te)
			else:
				scol = GRASS
			hm.set_pixel(x, y, Color(h, 0, 0))
			sf.set_pixel(x, y, scol)
			mk.set_pixel(x, y, Color(0, 0, 0))
	# Start marker + a direction pixel just ahead of it.
	var d := (wps[1] - wps[0]).normalized()
	_setpx(mk, wps[0], START)
	_setpx(mk, wps[0] + d * 4.0, STARTDIR)
	# Scatter some prop markers off-road.
	for p in [Vector2(18, 18), Vector2(SIZE - 22, 26), Vector2(28, SIZE - 26), Vector2(SIZE * 0.5, 16)]:
		_setpx(mk, p, TREE)
	for p in [Vector2(SIZE - 18, SIZE - 18), Vector2(22, SIZE * 0.5)]:
		_setpx(mk, p, ROCK)
	hm.save_exr(dir + "heightmap.exr")
	sf.save_png(dir + "surface.png")
	mk.save_png(dir + "markers.png")
	print("generated 3 images at ", SIZE, "x", SIZE)
	quit()

# Average the zone colour over a small window so asphalt/dirt/ice transitions blend smoothly.
func _zone_blend(frac: float) -> Color:
	var acc := Color(0, 0, 0)
	for k in 5:
		acc += _surface_for(fposmod(frac + (k - 2) * 0.012, 1.0))
	return acc * 0.2

func _surface_for(frac: float) -> Color:
	if frac < 0.25:
		return ASPHALT
	elif frac < 0.45:
		return DIRT
	elif frac < 0.58:
		return ICE
	elif frac < 0.80:
		return ASPHALT
	return DIRT

func _setpx(img: Image, p: Vector2, col: Color) -> void:
	img.set_pixel(clampi(int(round(p.x)), 0, SIZE - 1), clampi(int(round(p.y)), 0, SIZE - 1), col)
