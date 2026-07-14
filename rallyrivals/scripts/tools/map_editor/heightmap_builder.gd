class_name HeightmapBuilder
extends RefCounted
## Derives the heightmap from the painted road + authored height control points — the editor's
## core guarantee: height is never hand-painted, so road-edge lips and cross-track steps (the
## invisible-bump class of authoring errors) are unrepresentable. Same corridor model the image
## generators proved: flat road corridor, smoothstep shoulders, cut-and-fill noise terrain that
## hugs the road's local height.
##
## analyze() extracts the centreline with TrackBaker's own march (seeded by the race layer's
## start line), so the editor's notion of the lap agrees with a bake exactly. build() rasterizes
## at any resolution — quarter-res for the live preview, full-res for export (heightmap.exr).

const FLAT_HW := 12.0        # flat corridor half-width, source px (covers road colour + edge)
const SHOULDER := 28.0       # soft ramp from road height to natural terrain
const TERRAIN_AMP := 0.12    # off-road undulation around the local road height
const DEFAULT_H := 0.3       # profile with no authored points (normalized 0..1)
const NOISE_SEED := 11
const NOISE_FREQ := 0.015
const CELL := 32.0           # centreline bucket size for nearest lookups

var surfaces: Array = []                  # road palette (SurfaceType), for _is_road
var off_road_surface: SurfaceType = null
var max_height := 28.0                    # metres at heightmap value 1.0

func _baker(surface_img: Image, race_img: Image, size: int) -> TrackBaker:
	var b := TrackBaker.new()
	b._sf = surface_img
	b._rc = race_img
	b._size = size
	b.surfaces = surfaces
	b.off_road_surface = off_road_surface
	return b

## Extract + measure the centreline. -> {ok, msg, pts, cum, total}
func analyze(surface_img: Image, race_img: Image, size: int) -> Dictionary:
	var b := _baker(surface_img, race_img, size)
	var race := b._read_race()
	if race.is_empty():
		return {"ok": false, "msg": "height needs a valid race layer (start line + direction)"}
	var pts := b._extract_spline(race["start_mid"], race["dir"])
	if pts.size() < 10 or pts[pts.size() - 1].distance_to(race["start_mid"]) > 14.0:
		return {"ok": false, "msg": "road loop doesn't close — fix the layout (see console warning)"}
	var cum := PackedFloat32Array()
	cum.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		cum[i] = acc
		acc += pts[i].distance_to(pts[(i + 1) % pts.size()])
	return {"ok": true, "msg": "", "pts": pts, "cum": cum, "total": acc}

## Nearest centreline point index for an image position.
func nearest_index(analysis: Dictionary, p: Vector2) -> int:
	var pts: PackedVector2Array = analysis["pts"]
	var bi := 0
	var best := INF
	for i in pts.size():
		var d := p.distance_squared_to(pts[i])
		if d < best:
			best = d; bi = i
	return bi

## Lap fraction of an image position (projected onto the centreline).
func frac_of(analysis: Dictionary, p: Vector2) -> float:
	return (analysis["cum"][nearest_index(analysis, p)] as float) / (analysis["total"] as float)

## Authored points -> sorted profile anchors [{frac, h 0..1}]. Flat default when none.
func anchors_from(analysis: Dictionary, height_points: Array) -> Array:
	var out: Array = []
	for hp in height_points:
		out.append({
			"frac": frac_of(analysis, Vector2(float(hp["x"]), float(hp["y"]))),
			"h": clampf(float(hp["h"]) / max_height, 0.0, 1.0),
		})
	out.sort_custom(func(a, b): return a["frac"] < b["frac"])
	if out.is_empty():
		out.append({"frac": 0.0, "h": DEFAULT_H})
	return out

## Road height (0..1) at a lap fraction — smoothstep between anchors, wrapping the loop.
static func profile_h(anchors: Array, frac: float) -> float:
	var n := anchors.size()
	if n == 1:
		return anchors[0]["h"]
	for i in n:
		var a: Dictionary = anchors[i]
		var b: Dictionary = anchors[(i + 1) % n]
		var f0: float = a["frac"]
		var f1: float = b["frac"] if i + 1 < n else float(b["frac"]) + 1.0
		var f := frac if frac >= f0 else frac + 1.0
		if f >= f0 and f <= f1:
			var t := (f - f0) / maxf(f1 - f0, 0.0001)
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(a["h"], b["h"], t)
	return anchors[0]["h"]

## Rasterize at out_size (== size for export; size/4 for the editor preview). FORMAT_RF.
func build(size: int, analysis: Dictionary, anchors: Array, out_size: int) -> Image:
	var pts: PackedVector2Array = analysis["pts"]
	var cum: PackedFloat32Array = analysis["cum"]
	var total: float = analysis["total"]
	var n := pts.size()
	var noise := FastNoiseLite.new()
	noise.seed = NOISE_SEED
	noise.frequency = NOISE_FREQ
	var grid := {}
	for i in n:
		var key := Vector2i(int(pts[i].x / CELL), int(pts[i].y / CELL))
		if not grid.has(key):
			grid[key] = []   # plain Array: PackedInt32Array in a Dictionary is COW — appends vanish
		(grid[key] as Array).append(i)
	var img := Image.create(out_size, out_size, false, Image.FORMAT_RF)
	var s := float(size) / out_size
	for oy in out_size:
		for ox in out_size:
			var p := Vector2((ox + 0.5) * s, (oy + 0.5) * s)
			var bi := _nearest_bucketed(grid, pts, p)
			# true perpendicular distance + continuous arc via the two adjacent segments
			var dperp := INF
			var arc := 0.0
			for off in [-1, 0]:
				var ia := (bi + int(off) + n) % n
				var ib := (ia + 1) % n
				var a := pts[ia]
				var ab := pts[ib] - a
				var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var dd := p.distance_to(a + ab * tt)
				if dd < dperp:
					dperp = dd
					arc = cum[ia] + ab.length() * tt
			var road_h := profile_h(anchors, fposmod(arc / total, 1.0))
			var natural := clampf(road_h + noise.get_noise_2d(p.x, p.y) * TERRAIN_AMP, 0.0, 1.0)
			var h: float
			if dperp <= FLAT_HW:
				h = road_h
			elif dperp <= FLAT_HW + SHOULDER:
				var t := (dperp - FLAT_HW) / SHOULDER
				t = t * t * (3.0 - 2.0 * t)
				h = lerpf(road_h, natural, t)
			else:
				h = natural
			img.set_pixel(ox, oy, Color(h, 0, 0))
	return img

# Expanding-ring bucket search; after the first hit, scan one extra ring (a nearer point can sit
# in the next ring when the hit came from a cell corner).
func _nearest_bucketed(grid: Dictionary, pts: PackedVector2Array, p: Vector2) -> int:
	var c := Vector2i(int(p.x / CELL), int(p.y / CELL))
	var bi := 0
	var best := INF
	var stop_ring := 1000
	var ring := 0
	while ring <= stop_ring and ring < 64:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var key := c + Vector2i(dx, dy)
				if not grid.has(key):
					continue
				for i in grid[key]:
					var d := p.distance_squared_to(pts[i])
					if d < best:
						best = d; bi = i
		if best < INF and stop_ring == 1000:
			stop_ring = ring + 1
		ring += 1
	return bi
