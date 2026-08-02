extends SceneTree
## Voxel PROP block-out generator (art-voxel-props, ADR-003). Props are modelled in CONTINUOUS
## METRE-SPACE and rasterized at VOX, so resolution is one knob. Locked at 25 mm.
##
## The full set is 46 models (see the emit() calls in _initialize):
##   scatter (per region x3): tree (backwoods/dunes/alpine), rock + bush (all 4 regions)   [Island is treeless]
##   fence   (per region x2): timber / adobe / basalt+rope / snow-rail
##   neutral infra:           barrier_hard x2, barrier_soft, sign_left, sign_right
##
## Nothing is a clean primitive: a shared imperfection toolkit (_rdisc/_rball lumpy edges, _erode surface
## roughening, _mottle colour variation, _snowcap, per-model RNG) breaks up perfect forms. Determinism:
## surface detail uses a SPATIAL hash (_h) and variant randomness a name-seeded RNG, so re-runs reproduce.
##
## Review round: EMIT_OBJ = false -> writes .vox + a preview contact sheet per family only. The .obj
## export (greedy-meshed, for Godot) is switched on once the look is approved. Run:
##   godot --headless --script res://scripts/tools/gen_voxel_props.gd

const FINE := 0.025               # crisp props: snag, cactus, lupine, rocks, fences, barriers, signs
const COARSE := 0.075             # dense foliage: tree crowns, leafy/moss/snow bushes, tumbleweed (1/vox^2 lighter)
const EMIT_OBJ := true            # finalize: greedy-meshed .obj/.mtl/.png alongside the .vox
var VOX := FINE                   # current resolution (m/voxel); set per model in _initialize

var grid := {}
var _palette: Image
var _dir := "res://assets/voxels/props/"
var _cells := {}                 # name -> preview cell Image (for the contact sheets)
var S := {}                      # named palette slots
var _obj_faces := 0              # quad count of the last .obj (greedy-meshed)

func _initialize() -> void:
	_palette = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir + "_review/"))

	S = {
		"pine_d": _slot(Color(0.13, 0.34, 0.16)), "pine_l": _slot(Color(0.24, 0.48, 0.22)),
		"conif_d": _slot(Color(0.10, 0.28, 0.20)), "conif_l": _slot(Color(0.20, 0.40, 0.28)),
		"trunk": _slot(Color(0.34, 0.22, 0.12)), "deadwood": _slot(Color(0.46, 0.37, 0.28)),
		"cactus": _slot(Color(0.27, 0.45, 0.28)), "cactus_l": _slot(Color(0.38, 0.55, 0.34)),
		"snow": _slot(Color(0.90, 0.92, 0.96)),
		"granite": _slot(Color(0.50, 0.50, 0.54)), "granite_d": _slot(Color(0.32, 0.32, 0.36)),
		"moss": _slot(Color(0.22, 0.44, 0.18)),
		"sandstone": _slot(Color(0.74, 0.58, 0.38)), "sandstone_d": _slot(Color(0.60, 0.44, 0.26)),
		"basalt": _slot(Color(0.17, 0.17, 0.20)), "basalt_l": _slot(Color(0.28, 0.28, 0.32)),
		"slate": _slot(Color(0.44, 0.48, 0.54)), "slate_d": _slot(Color(0.30, 0.33, 0.39)),
		"leaf_d": _slot(Color(0.15, 0.40, 0.15)), "leaf_l": _slot(Color(0.26, 0.52, 0.22)),
		"scrub": _slot(Color(0.52, 0.46, 0.26)), "scrub_l": _slot(Color(0.64, 0.58, 0.34)),
		"mossbush": _slot(Color(0.24, 0.46, 0.20)), "mossbush_l": _slot(Color(0.34, 0.54, 0.26)),
		"lupine": _slot(Color(0.44, 0.34, 0.68)),
		"timber": _slot(Color(0.50, 0.34, 0.20)), "timber_d": _slot(Color(0.38, 0.25, 0.14)),
		"adobe": _slot(Color(0.74, 0.60, 0.44)), "adobe_d": _slot(Color(0.60, 0.47, 0.32)),
		"rope": _slot(Color(0.68, 0.58, 0.38)),
		"concrete": _slot(Color(0.66, 0.66, 0.68)), "stripe_r": _slot(Color(0.74, 0.22, 0.18)),
		"stripe_w": _slot(Color(0.90, 0.90, 0.92)), "tire": _slot(Color(0.13, 0.13, 0.14)),
		"sign_y": _slot(Color(0.92, 0.78, 0.20)), "sign_b": _slot(Color(0.26, 0.58, 0.90)),
		"post": _slot(Color(0.58, 0.60, 0.63)), "ink": _slot(Color(0.10, 0.10, 0.12)),
	}

	# --- trees (9) --- dense conifer/broadleaf crowns COARSE; sparse cactus/snag FINE
	VOX = COARSE
	_conifer("tree_backwoods_0", S.pine_d, S.pine_l, false)
	_broadleaf("tree_backwoods_1", S.trunk, S.leaf_d, S.leaf_l)
	_broadleaf("tree_backwoods_2", S.trunk, S.leaf_d, S.leaf_l)
	VOX = FINE
	_cactus("tree_dunes_0"); _snag("tree_dunes_1", true); _snag("tree_dunes_2", false)
	VOX = COARSE
	for v in 3: _conifer("tree_alpine_%d" % v, S.conif_d, S.conif_l, true)
	# --- rocks (12) --- FINE
	VOX = FINE
	for v in 3: _boulder("rock_backwoods_%d" % v, S.granite, S.granite_d, S.moss, false)
	for v in 3: _boulder("rock_dunes_%d" % v, S.sandstone, S.sandstone_d, -1, false)
	for v in 3: _boulder("rock_island_%d" % v, S.basalt, S.basalt_l, -1, true)
	for v in 3: _boulder("rock_alpine_%d" % v, S.slate, S.slate_d, S.snow, false)
	# --- bushes (12) --- dense foliage/tumbleweed COARSE; lupine FINE
	VOX = COARSE
	for v in 3: _shrub("bush_backwoods_%d" % v, S.leaf_d, S.leaf_l, "leafy")
	for v in 3: _tumbleweed("bush_dunes_%d" % v)
	_shrub("bush_island_0", S.mossbush, S.mossbush_l, "moss")
	VOX = FINE
	_lupine("bush_island_1"); _lupine("bush_island_2")
	VOX = COARSE
	for v in 3: _shrub("bush_alpine_%d" % v, S.leaf_d, S.leaf_l, "snowy")
	# --- fences (8) --- FINE
	VOX = FINE
	for v in 2: _fence("fence_backwoods_%d" % v, "timber")
	for v in 2: _fence("fence_dunes_%d" % v, "adobe")
	for v in 2: _fence("fence_island_%d" % v, "basalt")
	for v in 2: _fence("fence_alpine_%d" % v, "snow")
	# --- neutral infra (5) ---
	_barrier_hard("barrier_hard_0", false); _barrier_hard("barrier_hard_1", true)
	_barrier_soft("barrier_soft_0")
	_sign("sign_left", -1); _sign("sign_right", 1)

	# --- contact sheets ---
	_sheet("sheet_trees", [["tree_backwoods_0", "tree_backwoods_1", "tree_backwoods_2"],
		["tree_dunes_0", "tree_dunes_1", "tree_dunes_2"], ["tree_alpine_0", "tree_alpine_1", "tree_alpine_2"]])
	_sheet("sheet_rocks", [["rock_backwoods_0", "rock_backwoods_1", "rock_backwoods_2"],
		["rock_dunes_0", "rock_dunes_1", "rock_dunes_2"], ["rock_island_0", "rock_island_1", "rock_island_2"],
		["rock_alpine_0", "rock_alpine_1", "rock_alpine_2"]])
	_sheet("sheet_bushes", [["bush_backwoods_0", "bush_backwoods_1", "bush_backwoods_2"],
		["bush_dunes_0", "bush_dunes_1", "bush_dunes_2"], ["bush_island_0", "bush_island_1", "bush_island_2"],
		["bush_alpine_0", "bush_alpine_1", "bush_alpine_2"]])
	_sheet("sheet_infra", [["fence_backwoods_0", "fence_backwoods_1", ""],
		["fence_dunes_0", "fence_dunes_1", ""], ["fence_island_0", "fence_island_1", ""],
		["fence_alpine_0", "fence_alpine_1", ""], ["barrier_hard_0", "barrier_hard_1", "barrier_soft_0"],
		["sign_left", "sign_right", ""]])

	print("props: %d models @ %.0f mm/vox -> %s (obj=%s)" % [_cells.size(), VOX * 1000.0, _dir, EMIT_OBJ])
	quit()

# ============================ MODELS ============================

# Conifer (spruce/pine): irregular tiered cone with a lumpy edge, asymmetric drift, foliage gaps and a
# two-tone canopy; snowy = snow patches on the upper surfaces (Alpine). Per-name RNG varies each variant.
func _conifer(nm: String, dark: int, light: int, snowy: bool) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var h := rng.randf_range(3.6, 4.6)
	var tiers := rng.randf_range(5.0, 7.0)
	var base_r := rng.randf_range(0.82, 1.02)
	var lean := rng.randf_range(-0.10, 0.10)
	var drift := rng.randf_range(0.06, 0.14)
	var canopy_bot := 0.60
	var c := float(_rz(base_r * 1.25 + drift)) + 3.0
	var rows := _rz(h)
	for yi in _rz(minf(1.05, h)):                                 # trunk
		_disc(c + float(_rz(lean)) * (float(yi) / rows), c, float(_rz(0.07)), yi, S.trunk)
	for yi in rows:
		var wy := (yi + 0.5) * VOX
		if wy < canopy_bot: continue
		var t := (wy - canopy_bot) / (h - canopy_bot)
		var prof: float = lerpf(base_r, 0.03, t)
		var local: float = fmod(t * tiers, 1.0)
		var r: float = prof * (0.80 + 0.36 * (1.0 - local))
		var cx := c + float(_rz(lean)) * t + float(_rz(drift)) * (_cn(0, yi, 0, salt, 6) - 0.5) * 2.0
		var cz := c + float(_rz(drift)) * (_cn(0, yi, 91, salt, 6) - 0.5) * 2.0
		_rdisc(cx, cz, float(_rz(r)), yi, dark, 0.32, salt)
	_erode(0.14, salt + 1)
	_mottle(dark, light, 0.30, salt + 2, 3)
	if snowy: _snowcap(S.snow, 0.55, salt + 3, 3, 0.0)
	_emit(nm)

# Saguaro-ish cactus: a fluted column with a rounded dome and one or two arms that elbow out then rise.
func _cactus(nm: String) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var h := rng.randf_range(2.7, 3.5)
	var col_r := rng.randf_range(0.16, 0.20)
	var c := float(_rz(1.0)) + 3.0
	var rows := _rz(h)
	for yi in rows:
		var taper := 1.0 - 0.15 * smoothstep(0.75, 1.0, float(yi) / rows)   # slight top taper
		_flute(c, c, float(_rz(col_r)) * taper, yi, S.cactus, salt)
	_ball(Vector3(c, rows - _rz(col_r) * 0.6, c), float(_rz(col_r)), S.cactus)   # dome top
	var az0 := rng.randf_range(0.0, TAU)
	for a in 2:                                                    # two arms on roughly opposite sides
		var az := az0 + float(a) * PI + rng.randf_range(-0.5, 0.5)
		var yb := rng.randf_range(0.9, 1.5)
		var base := Vector3(c, float(_rz(yb)), c)
		var outv := Vector3(cos(az), 0, sin(az))
		var elbow := base + outv * float(_rz(0.40))               # reach further out so arms clear the trunk
		var top := elbow + Vector3(0, float(_rz(rng.randf_range(0.7, 1.1))), 0)
		_capsule(base + outv * float(_rz(col_r) * 0.5), elbow, float(_rz(0.13)), S.cactus)
		_capsule(elbow, top, float(_rz(0.12)), S.cactus)
		_ball(top, float(_rz(0.12)), S.cactus)
	_erode(0.06, salt + 1)
	_mottle(S.cactus, S.cactus_l, 0.22, salt + 2, 4)
	_emit(nm)

# Dead snag. `sweeping` = a broad SPREADING dead tree: a SLIM trunk with many long, arcing bare branches
# (a wide gnarled crown). Otherwise a plain upright snag: tapered trunk + a few short stubby branches.
func _snag(nm: String, sweeping: bool) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	if sweeping:
		var h := rng.randf_range(2.4, 2.9)
		var lean := float(_rz(rng.randf_range(0.05, 0.12)))
		var c := float(_rz(1.7)) + 3.0                          # wide margin for the spreading branches
		var rows := _rz(h)
		for yi in rows:
			var t := float(yi) / rows
			_rdisc(c + lean * t * t, c, float(_rz(lerpf(0.12, 0.03, t))), yi, S.deadwood, 0.28, salt)
		for b in range(rng.randi_range(6, 8)):                  # many long arcing limbs
			var az := rng.randf_range(0.0, TAU)
			var hf := rng.randf_range(0.4, 0.95)                # attach height fraction
			var base := Vector3(c + lean * hf * hf, float(rows) * hf, c)
			_sweep(base, Vector3(cos(az), 0, sin(az)), rng.randf_range(0.9, 1.5), rng.randf_range(0.5, 1.0), 0.06, salt + b)
		_erode(0.12, salt + 1)
		_mottle(S.deadwood, S.trunk, 0.20, salt + 2, 3)
		_emit(nm)
		return
	var h := rng.randf_range(2.8, 3.4)
	var lean := float(_rz(rng.randf_range(0.12, 0.26)))
	var c := float(_rz(1.05)) + 3.0
	var rows := _rz(h)
	for yi in rows:
		var t := float(yi) / rows
		_rdisc(c + lean * t * t, c, float(_rz(lerpf(0.16, 0.03, t))), yi, S.deadwood, 0.28, salt)
	for b in [[0.44, 25.0, 32.0, 0.75, 0.06], [0.60, 205.0, 28.0, 0.9, 0.055],
			[0.76, 115.0, 42.0, 0.6, 0.045], [0.93, 300.0, 52.0, 0.45, 0.04]]:
		var t: float = b[0]
		var az: float = deg_to_rad(b[1]); var el: float = deg_to_rad(b[2])
		var base := Vector3(c + lean * t * t, float(rows) * t, c)
		var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		_capsule(base, base + dir * float(_rz(b[3])), float(_rz(b[4])), S.deadwood)
	_erode(0.12, salt + 1)
	_mottle(S.deadwood, S.trunk, 0.20, salt + 2, 3)
	_emit(nm)

# Broadleaf/deciduous tree: a leaning tapered trunk under a big rounded, lumpy, airy foliage crown.
func _broadleaf(nm: String, trunk_i: int, leaf_d: int, leaf_l: int) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var h := rng.randf_range(3.4, 4.2)
	var crown_r := rng.randf_range(1.0, 1.3)
	var trunk_h := rng.randf_range(1.1, 1.6)
	var lean := rng.randf_range(-0.08, 0.08)
	var c := float(_rz(crown_r * 1.25)) + 3.0
	var rows := _rz(minf(trunk_h + 0.4, h))
	for yi in rows:
		var t := float(yi) / float(maxi(rows, 1))
		_disc(c + float(_rz(lean)) * t, c, float(_rz(lerpf(0.13, 0.07, t))), yi, trunk_i)
	var crown_y := float(_rz(h - crown_r * 0.9))
	for i in rng.randi_range(4, 6):
		var off := Vector3(rng.randf_range(-crown_r * 0.5, crown_r * 0.5), rng.randf_range(-crown_r * 0.35, crown_r * 0.35), rng.randf_range(-crown_r * 0.5, crown_r * 0.5))
		_rball(Vector3(c + float(_rz(off.x + lean)), crown_y + float(_rz(off.y)), c + float(_rz(off.z))), float(_rz(rng.randf_range(0.55, 0.8) * crown_r)), leaf_d, 0.36, salt + i)
	_erode(0.14, salt + 1)
	_mottle(leaf_d, leaf_l, 0.30, salt + 2, 3)
	_emit(nm)

# Tumbleweed: a roughly spherical, heavily-eroded airy ball of dry twigs with a few criss-cross branches.
func _tumbleweed(nm: String) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var r := rng.randf_range(0.5, 0.7)
	var c := float(_rz(r * 1.3)) + 3.0
	var cy := float(_rz(r * 0.95))
	var ctr := Vector3(c, cy, c)
	_rball(ctr, float(_rz(r)), S.scrub, 0.30, salt)
	_erode(0.42, salt + 1)                                       # airy, wiry
	for i in 6:
		var az := rng.randf_range(0.0, TAU); var el := rng.randf_range(-0.6, 0.6)
		var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		_capsule(ctr - dir * float(_rz(r)), ctr + dir * float(_rz(r)), 0.7, S.deadwood)
	_erode(0.30, salt + 2)
	_mottle(S.scrub, S.deadwood, 0.32, salt + 3, 3)
	_emit(nm)

# Lupine: a low green leafy base with several tall vertical stalks tipped by purple flower spikes (Iceland).
func _lupine(nm: String) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var c := float(_rz(0.6)) + 3.0
	for i in rng.randi_range(3, 4):
		var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		_rball(Vector3(c + float(_rz(off.x)), float(_rz(0.12)), c + float(_rz(off.z))), float(_rz(0.22)), S.mossbush, 0.4, salt + i)
	for s in rng.randi_range(5, 8):
		var bx := c + float(_rz(rng.randf_range(-0.35, 0.35)))
		var bz := c + float(_rz(rng.randf_range(-0.35, 0.35)))
		var sh := rng.randf_range(0.45, 0.75)
		var mid := float(_rz(sh * 0.5))
		_capsule(Vector3(bx, float(_rz(0.1)), bz), Vector3(bx, mid, bz), 0.7, S.mossbush)   # green stem
		_capsule(Vector3(bx, mid, bz), Vector3(bx, float(_rz(sh)), bz), 0.9, S.lupine)      # purple spike
	_erode(0.10, salt + 1)
	_mottle(S.mossbush, S.mossbush_l, 0.25, salt + 2, 3)
	_emit(nm)

# Boulder: a solid mass with subtle surface detail (not a gravel pile). `angular` builds it from stacked
# blocks with chipped corners (basalt columns); otherwise overlapping rounded lumps. accent>=0 caps the
# top (moss on granite, snow on slate). Sandstone (second==sandstone_d) gets horizontal strata bands.
func _boulder(nm: String, main: int, second: int, accent: int, angular: bool) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var big := rng.randf_range(0.55, 0.9)
	var c := float(_rz(big * 1.6)) + 3.0
	if angular:
		var blocks := rng.randi_range(3, 6)                      # faceted stack -> basalt chunk
		for i in blocks:
			var sx := _rz(rng.randf_range(0.22, big * 0.7)); var sz := _rz(rng.randf_range(0.22, big * 0.7))
			var sy := _rz(rng.randf_range(0.4, big * 1.3)); var by := _rz(rng.randf_range(0.0, 0.35))
			var ox := _rz(rng.randf_range(-big * 0.5, big * 0.5)); var oz := _rz(rng.randf_range(-big * 0.5, big * 0.5))
			_fillb(int(c) + ox - sx, int(c) + ox + sx, by, by + sy, int(c) + oz - sz, int(c) + oz + sz, main)
		_erode(0.06, salt + 5)                                   # chip the hard corners
	else:
		var lumps := rng.randi_range(2, 4)
		for i in lumps:
			var r := rng.randf_range(big * 0.6, big)
			var ctr := Vector3(c + float(_rz(rng.randf_range(-big * 0.45, big * 0.45))), float(_rz(r * 0.5)),
				c + float(_rz(rng.randf_range(-big * 0.45, big * 0.45))))
			_rball(ctr, float(_rz(r)), main, 0.18, salt + i)     # gently lumpy, still a solid mass
		_erode(0.04, salt + 5)
	for k in grid.keys():                                        # flat base: cut below ground
		if k.y < 0: grid.erase(k)
	if second == S.sandstone_d:                                  # strata bands (sandstone)
		for k in grid.keys():
			if (int(k.y / maxi(_rz(0.16), 1)) % 2) == 0: grid[k] = second
	_mottle(main, second, 0.22, salt + 8, 6)                     # broad colour zones, not speckle
	if accent >= 0: _snowcap(accent, 0.5, salt + 9, 5, 0.45)     # cap the top only
	_emit(nm)

# Shrub: a clump of small foliage balls, two-tone, eroded for airiness. Style sets density + extras:
# leafy (round), scrub (sparse + a few twigs), moss (low soft mound), snowy (leafy + snow).
func _shrub(nm: String, a: int, b: int, style: String) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var wide := rng.randf_range(0.5, 0.8)
	var tall: float = wide * (0.55 if style == "moss" else 0.9)
	var c := float(_rz(wide * 1.5)) + 3.0
	var clumps := rng.randi_range(3, 6)
	for i in clumps:
		var off := Vector3(rng.randf_range(-wide * 0.6, wide * 0.6), 0, rng.randf_range(-wide * 0.6, wide * 0.6))
		var y := rng.randf_range(0.12, tall)
		var r := rng.randf_range(0.20, 0.34)
		_rball(Vector3(c + float(_rz(off.x)), float(_rz(y)), c + float(_rz(off.z))), float(_rz(r)), a, 0.42, salt + i)
	if style == "scrub":
		for i in 3:                                             # dry twigs poking out
			var az := rng.randf_range(0.0, TAU)
			var base := Vector3(c, float(_rz(0.1)), c)
			var tip := base + Vector3(cos(az), 1.4, sin(az)) * float(_rz(rng.randf_range(0.4, 0.7)))
			_capsule(base, tip, 0.7, S.deadwood)
	var ero: float = 0.30 if style == "scrub" else (0.10 if style == "moss" else 0.20)
	_erode(ero, salt + 5)
	_mottle(a, b, 0.30, salt + 6, 3)
	if style == "snowy": _snowcap(S.snow, 0.4, salt + 7, 3, 0.0)
	_emit(nm)

# Fence: a ~4 m run along +Z (posts + two rails), origin centred (baker offsets it forward). Styles:
# timber (wood), adobe (a low solid wall), basalt (dark stone posts + rope rails), snow (timber + snow).
func _fence(nm: String, style: String) -> void:
	grid = {}
	var rng := RandomNumberGenerator.new(); rng.seed = hash(nm)
	var salt := int(rng.randi() & 0x7fffffff)
	var zN := _rz(4.0)
	var cx := float(_rz(0.3)) + 3.0
	var post_c: int = S.timber if style != "adobe" else S.adobe
	var rail_c: int = S.rope if style == "basalt" else post_c
	if style == "basalt": post_c = S.basalt
	if style == "adobe":
		for z in zN:
			var top := _rz(0.7 + 0.08 * sin(float(z) * 0.15))       # uneven wall top
			for y in top:
				_rdisc(cx, float(z), float(_rz(0.16)), y, S.adobe, 0.18, salt)   # thick along x via disc in x/y? use box
	else:
		var posts := 5
		for p in posts:
			var pz := int(float(p) / float(posts - 1) * float(zN - 1))
			var ph := _rz(1.0 + rng.randf_range(-0.06, 0.06))
			for y in ph:
				_fillb(int(cx) - _rz(0.05), int(cx) + _rz(0.05), y, y, pz - _rz(0.05), pz + _rz(0.05), post_c)
		for lvl in [0.45, 0.85]:                                    # two rails
			var ry := _rz(lvl)
			var rr: int = _rz(0.03) if style == "basalt" else _rz(0.05)
			for z in zN:
				var sag := int(round(2.0 * sin(float(z) / float(zN) * PI)))   # slight rail sag
				_fillb(int(cx) - rr, int(cx) + rr, ry - sag, ry - sag, z, z, rail_c)
	_erode(0.06, salt + 1)
	if style == "timber" or style == "snow": _mottle(S.timber, S.timber_d, 0.25, salt + 2, 3)
	if style == "snow": _snowcap(S.snow, 0.5, salt + 3, 3, 0.0)
	_emit(nm)

# Concrete jersey barrier: ~4 m, trapezoid cross-section, red/white end stripes. scuffed = eroded + dirt.
func _barrier_hard(nm: String, scuffed: bool) -> void:
	grid = {}
	var salt := hash(nm) & 0x7fffffff
	var zN := _rz(4.0)
	var cx := float(_rz(0.35)) + 3.0
	var hN := _rz(0.9)
	for y in hN:
		var t := float(y) / float(hN)
		var half := _rz(lerpf(0.20, 0.07, t))                       # wide base, narrow top
		for z in zN:
			_fillb(int(cx) - half, int(cx) + half, y, y, z, z, S.concrete)
	var band := maxi(_rz(0.35), 1)                                  # alternating red/white bands near both ends
	for k in grid.keys():
		if k.z < _rz(0.7) or k.z > zN - _rz(0.7):
			grid[k] = S.stripe_r if (int(k.z / band) % 2 == 0) else S.stripe_w
	if scuffed:
		_erode(0.10, salt)
		_mottle(S.concrete, S.granite_d, 0.18, salt + 1, 3)
	_emit(nm)

# Tyre wall: rows of stacked tyres (annuli facing the track, +X) — a soft rally barrier.
func _barrier_soft(nm: String) -> void:
	grid = {}
	var salt := hash(nm) & 0x7fffffff
	var zN := _rz(3.0)
	var cx := float(_rz(0.25)) + 3.0
	var tr := 0.34; var tube := 0.12
	var stepz := _rz(0.72); var stepy := _rz(0.62)
	var row := 0
	var zpos := _rz(tr)
	while zpos < zN - _rz(tr):
		var yc := _rz(tr) + (row % 2) * (stepy / 2)                 # brick-stagger the stack
		while yc < _rz(2.0):
			for y in range(yc - _rz(tr + tube), yc + _rz(tr + tube)):
				if y < 0: continue
				var dy := float(y) + 0.5 - yc
				for z in range(zpos - _rz(tr + tube), zpos + _rz(tr + tube)):
					var dz := float(z) + 0.5 - zpos
					var d := sqrt(dy * dy + dz * dz)
					if absf(d - _rz(tr)) <= _rz(tube):               # annulus (tyre ring)
						for x in range(int(cx) - _rz(0.14), int(cx) + _rz(0.14)):
							grid[Vector3i(x, y, z)] = S.tire
			yc += stepy
		zpos += stepz; row += 1
	_erode(0.05, salt)
	_emit(nm)

# Rally arrow sign: a post + a square panel facing +Z, with an arrow (ink) pointing left(-1)/right(+1).
func _sign(nm: String, dir: int) -> void:
	grid = {}
	var salt := hash(nm) & 0x7fffffff
	var c := float(_rz(0.7)) + 3.0
	var panel: int = S.sign_y if dir < 0 else S.sign_b
	var postH := _rz(1.05)
	for y in postH:                                                 # post
		_fillb(int(c) - _rz(0.04), int(c) + _rz(0.04), y, y, int(c) - _rz(0.04), int(c) + _rz(0.04), S.post)
	var pw := _rz(0.45); var py0 := _rz(1.0); var py1 := _rz(1.9); var pz := int(c) + _rz(0.06)
	for y in range(py0, py1):                                       # panel (thin in z, faces +Z)
		for x in range(int(c) - pw, int(c) + pw):
			_fillb(x, x, y, y, pz, pz + _rz(0.04), panel)
	var fz := pz + _rz(0.04)                                        # front (+Z) face — the side that faces the driver
	var midy := (py0 + py1) / 2
	var x_tail := int(c) - dir * _rz(0.26)                          # shaft: tail -> head base, along `dir`
	var x_hbase := int(c) + dir * _rz(0.08)
	for x in range(mini(x_tail, x_hbase), maxi(x_tail, x_hbase) + 1):
		for yy in range(midy - _rz(0.05), midy + _rz(0.05) + 1):
			_recolor(x, yy, fz, S.ink)
	var tipx := int(c) + dir * _rz(0.30)                           # head: POINT at the tip, widening to the shaft
	var hlen := _rz(0.22)
	for k in range(0, hlen + 1):
		var w := int(round(float(k) / float(maxi(hlen, 1)) * float(_rz(0.20))))
		for yy in range(midy - w, midy + w + 1):
			_recolor(tipx - dir * k, yy, fz, S.ink)
	_emit(nm)

# ============================ IMPERFECTION TOOLKIT ============================

func _rz(m: float) -> int:
	return int(round(m / VOX))

# Nearest master-palette slot to a target colour (block-out tints; recolour in MagicaVoxel later).
func _slot(target: Color) -> int:
	var best := INF; var pick := 0
	for i in 256:
		var col := _palette.get_pixel(i, 0)
		if col.r + col.g + col.b < 0.06:
			continue
		var dd := Vector3(col.r - target.r, col.g - target.g, col.b - target.b).length()
		if dd < best:
			best = dd; pick = i
	return pick

# Deterministic spatial hash in [0,1] — surface detail that reproduces across runs.
func _h(x: int, y: int, z: int, salt: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + z * 2147483647 + salt * 974711
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0

# Coarse (blocky) noise — hashes a downsampled grid so lumps are ~scale voxels and stay connected.
func _cn(x: int, y: int, z: int, salt: int, scale: int) -> float:
	return _h(x / scale, y / scale, z / scale, salt)

func _disc(cx: float, cz: float, r: float, y: int, slot: int) -> void:
	var ri := int(ceil(r))
	for x in range(int(cx - ri), int(cx + ri) + 1):
		for z in range(int(cz - ri), int(cz + ri) + 1):
			if Vector2(x + 0.5 - cx, z + 0.5 - cz).length() <= r:
				grid[Vector3i(x, y, z)] = slot

# Lumpy disc — boundary perturbed by coarse noise (organic, non-circular).
func _rdisc(cx: float, cz: float, r: float, y: int, slot: int, rough: float, salt: int) -> void:
	var ri := int(ceil(r * (1.0 + rough))) + 1
	for x in range(int(cx) - ri, int(cx) + ri + 1):
		for z in range(int(cz) - ri, int(cz) + ri + 1):
			var dist := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
			if dist <= r * (1.0 + rough * (_cn(x, y, z, salt, 4) - 0.5) * 2.0):
				grid[Vector3i(x, y, z)] = slot

# A fluted column layer (cactus ribs) — radius dips on a cosine around the angle.
func _flute(cx: float, cz: float, r: float, y: int, slot: int, salt: int) -> void:
	var ri := int(ceil(r)) + 1
	for x in range(int(cx) - ri, int(cx) + ri + 1):
		for z in range(int(cz) - ri, int(cz) + ri + 1):
			var dx := x + 0.5 - cx; var dz := z + 0.5 - cz
			var ang := atan2(dz, dx)
			if sqrt(dx * dx + dz * dz) <= r * (1.0 - 0.13 * (0.5 + 0.5 * cos(ang * 12.0))):
				grid[Vector3i(x, y, z)] = slot

func _ball(ctr: Vector3, r: float, slot: int) -> void:
	var ri := int(ceil(r))
	for x in range(int(ctr.x - ri), int(ctr.x + ri) + 1):
		for y in range(int(ctr.y - ri), int(ctr.y + ri) + 1):
			for z in range(int(ctr.z - ri), int(ctr.z + ri) + 1):
				if Vector3(x + 0.5 - ctr.x, y + 0.5 - ctr.y, z + 0.5 - ctr.z).length() <= r:
					grid[Vector3i(x, y, z)] = slot

# Lumpy ball (rocks/foliage) — coarse-noise-perturbed radius.
func _rball(ctr: Vector3, r: float, slot: int, rough: float, salt: int) -> void:
	var ri := int(ceil(r * (1.0 + rough)))
	for x in range(int(ctr.x) - ri, int(ctr.x) + ri + 1):
		for y in range(int(ctr.y) - ri, int(ctr.y) + ri + 1):
			for z in range(int(ctr.z) - ri, int(ctr.z) + ri + 1):
				var d := Vector3(x + 0.5 - ctr.x, y + 0.5 - ctr.y, z + 0.5 - ctr.z).length()
				if d <= r * (1.0 + rough * (_cn(x, y, z, salt, 3) - 0.5) * 2.0):
					grid[Vector3i(x, y, z)] = slot

func _capsule(p0: Vector3, p1: Vector3, r: float, slot: int) -> void:
	var steps := maxi(int(ceil((p1 - p0).length())), 1)
	for i in range(steps + 1):
		_ball(p0.lerp(p1, float(i) / float(steps)), maxf(r, 0.6), slot)

# An arcing branch: sweeps outward (linear) while curving upward (accelerating), tapering to a thin tip.
func _sweep(base: Vector3, outdir: Vector3, reach_m: float, rise_m: float, r0_m: float, salt: int) -> void:
	var steps := maxi(_rz(reach_m + rise_m), 6)
	var prev := base
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var pos := base + outdir * float(_rz(reach_m * t)) + Vector3.UP * float(_rz(rise_m * t * t))
		_capsule(prev, pos, float(_rz(lerpf(r0_m, 0.02, t))), S.deadwood)
		prev = pos

func _fillb(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for z in range(mini(z0, z1), maxi(z0, z1) + 1):
				grid[Vector3i(x, y, z)] = slot

func _recolor(x: int, y: int, z: int, slot: int) -> void:
	if grid.has(Vector3i(x, y, z)): grid[Vector3i(x, y, z)] = slot

# Remove surface voxels with probability `prob` (keeps the bottom rows so models stay grounded).
func _erode(prob: float, salt: int) -> void:
	for k in grid.keys():
		if k.y < 2: continue
		var surface := false
		for o in N6:
			if not grid.has(k + o): surface = true; break
		if surface and _h(k.x, k.y, k.z, salt) < prob:
			grid.erase(k)

# Recolour some `from` voxels to `to` in coarse-noise patches (colour variation across a surface).
func _mottle(from_slot: int, to_slot: int, prob: float, salt: int, scale: int) -> void:
	for k in grid.keys():
		if grid[k] == from_slot and _cn(k.x, k.y, k.z, salt, scale) < prob:
			grid[k] = to_slot

# Recolour top-exposed voxels to `snow` in patches. `scale` sets patch size (bigger = broader caps);
# `ybias` (0..1) skips the lower fraction of the model so snow settles on the top, not all over.
func _snowcap(snow: int, prob: float, salt: int, scale: int, ybias: float) -> void:
	var maxy := 0
	for k in grid: maxy = maxi(maxy, k.y)
	var floor_y := int(maxy * ybias)
	for k in grid.keys():
		if k.y < floor_y: continue
		if not grid.has(k + Vector3i(0, 1, 0)) and _cn(k.x, 0, k.z, salt, scale) < prob:
			grid[k] = snow

const N6 := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

# ============================ EMIT + PREVIEW ============================

func _emit(nm: String) -> void:
	_settle()
	if grid.is_empty():
		push_error("empty model: " + nm); return
	var mx := 0; var mz := 0; var my := 0
	for key in grid:
		mx = maxi(mx, key.x); mz = maxi(mz, key.z); my = maxi(my, key.y)
	var size := Vector3i(mx + 1, mz + 1, my + 1)
	_write_vox(_dir + nm + ".vox", size)
	if EMIT_OBJ:
		_write_obj(_dir, nm, Vector3(size.x * 0.5, 0.0, size.y * 0.5))
	_render_cell(nm)
	print("  %-20s %2.0fmm %6d vox  %dx%dx%d  faces=%d" % [nm, VOX * 1000.0, grid.size(), size.x, size.z, size.y, _obj_faces])

# Clip below-ground voxels, then shift EVERY axis so its min = 0. Normalizing X/Z (not just Y) is load-
# bearing: it removes the build margin so _emit's size*0.5 is the TRUE bbox centre (props must be centred
# in x/z — RegionSkin drops the mesh on the placement point and the baked collision box is centre-origin),
# and it lifts the slightly-negative coords oriented props build into range so _write_vox's put_u8 can't wrap.
func _settle() -> void:
	for k in grid.keys():
		if k.y < 0: grid.erase(k)                       # below-ground -> flat base
	if grid.is_empty(): return
	var mn := Vector3i(1 << 30, 1 << 30, 1 << 30)
	for k in grid:
		mn.x = mini(mn.x, k.x); mn.y = mini(mn.y, k.y); mn.z = mini(mn.z, k.z)
	if mn == Vector3i.ZERO: return
	var ng := {}
	for k in grid:
		ng[k - mn] = grid[k]
	grid = ng

# A 3/4 orthographic voxel-shaded preview cell (fixed size for the contact sheet).
const CW := 250
const CH := 320
func _render_cell(nm: String) -> void:
	var d := Vector3(0.82, 0.5, 0.72).normalized()
	var right := Vector3.UP.cross(d).normalized()
	var up := d.cross(right).normalized()
	if up.y < 0.0: up = -up
	var light := Vector3(0.4, 0.85, 0.35).normalized()
	var shell: Array = []
	var min_s := Vector2(INF, INF); var max_s := Vector2(-INF, -INF)
	for key in grid:
		var nrm := Vector3.ZERO
		for o in N6:
			if not grid.has(key + o): nrm += Vector3(o)
		if nrm == Vector3.ZERO: continue
		var p := Vector3(key)
		var s := Vector2(p.dot(right), p.dot(up))
		shell.append([s, p.dot(d), nrm.normalized(), grid[key]])
		min_s = min_s.min(s); max_s = max_s.max(s)
	var span := max_s - min_s
	var scale := minf((CW - 24) / maxf(span.x, 1.0), (CH - 24) / maxf(span.y, 1.0))
	var ox := (CW - span.x * scale) * 0.5
	var oy := (CH - span.y * scale) * 0.5
	var blk := maxi(int(ceil(scale)), 1)
	var img := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.11, 0.12, 0.15))
	var zbuf := PackedFloat32Array(); zbuf.resize(CW * CH); zbuf.fill(-INF)
	for e in shell:
		var s: Vector2 = e[0]
		var depth: float = e[1]
		var shade: float = clampf((e[2] as Vector3).dot(light), 0.0, 1.0) * 0.72 + 0.28
		var base: Color = _palette.get_pixel(int(e[3]), 0)
		var col := Color(base.r * shade, base.g * shade, base.b * shade)
		var px := int((s.x - min_s.x) * scale + ox)
		var py := CH - 1 - int((s.y - min_s.y) * scale + oy)
		for iy in range(py - blk, py + 1):
			for ix in range(px, px + blk):
				if ix < 0 or iy < 0 or ix >= CW or iy >= CH: continue
				var zi := iy * CW + ix
				if depth > zbuf[zi]:
					zbuf[zi] = depth; img.set_pixel(ix, iy, col)
	img.save_png(ProjectSettings.globalize_path(_dir + "_review/" + nm + ".png"))
	_cells[nm] = img

func _sheet(name: String, rows: Array) -> void:
	var cols := 0
	for r in rows: cols = maxi(cols, (r as Array).size())
	var img := Image.create(cols * CW, rows.size() * CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.08, 0.10))
	for ri in rows.size():
		var row: Array = rows[ri]
		for ci in row.size():
			var nm: String = row[ci]
			if nm != "" and _cells.has(nm):
				img.blit_rect(_cells[nm], Rect2i(0, 0, CW, CH), Vector2i(ci * CW, ri * CH))
	img.save_png(ProjectSettings.globalize_path(_dir + "_review/" + name + ".png"))

# ============================ WRITERS (.vox + .obj/.mtl/.png) ============================

# Greedy-mesh the exposed voxel faces into large quads (per axis / sign / slice), then write .obj. Merging
# coplanar same-slot faces cuts triangle count several-fold vs one quad per voxel face, with an identical
# surface. `_greedy_quads` also returns the raw exposed-face count so we can assert the merge lost no area.
func _write_obj(dir: String, model: String, center: Vector3) -> void:
	var exposed := [0]
	var quads := _greedy_quads(exposed)
	var v_lines := PackedStringArray(); var vt_lines := PackedStringArray()
	var vn_lines := PackedStringArray(); var f_lines := PackedStringArray()
	var vt_index := {}; var vn_index := {}; var vpos := {}   # vpos: shared vertex positions -> index
	var area := 0
	for q in quads:
		var naxis: int = q[0]; var sgn: int = q[1]; var s: int = q[2]
		var a0: int = q[3]; var b0: int = q[4]; var da: int = q[5]; var db: int = q[6]; var slot: int = q[7]
		area += da * db
		if not vt_index.has(slot):
			vt_index[slot] = vt_index.size() + 1
			vt_lines.append("vt %.6f 0.5" % [(slot + 0.5) / 256.0])
		var nkey := naxis * 2 + (0 if sgn > 0 else 1)
		if not vn_index.has(nkey):
			vn_index[nkey] = vn_index.size() + 1
			var nv := [0, 0, 0]; nv[naxis] = sgn
			vn_lines.append("vn %d %d %d" % nv)
		var A := (naxis + 1) % 3; var B := (naxis + 2) % 3
		var base := [0.0, 0.0, 0.0]
		base[naxis] = float(s + 1) if sgn > 0 else float(s); base[A] = float(a0); base[B] = float(b0)
		# corner order picked so the winding faces `sgn` along naxis (cross(eA,eB) = +naxis)
		var order := [[0, 0], [1, 0], [1, 1], [0, 1]] if sgn > 0 else [[0, 0], [0, 1], [1, 1], [1, 0]]
		var ids := PackedInt32Array()
		for ij in order:
			var p := base.duplicate()
			p[A] += float(ij[0] * da); p[B] += float(ij[1] * db)
			var vk := Vector3i(int(p[0]), int(p[1]), int(p[2]))   # integer corner -> exact vertex sharing
			if not vpos.has(vk):
				vpos[vk] = vpos.size() + 1
				v_lines.append("v %.4f %.4f %.4f" % [(p[0] - center.x) * VOX, (p[1] - center.y) * VOX, (p[2] - center.z) * VOX])
			ids.append(vpos[vk])
		var vt: int = vt_index[slot]; var vn: int = vn_index[nkey]
		f_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d" % [
			ids[0], vt, vn, ids[1], vt, vn, ids[2], vt, vn, ids[3], vt, vn])
	if area != exposed[0]:
		push_error("greedy area mismatch %s: %d quads-area vs %d exposed" % [model, area, exposed[0]])
	_obj_faces = quads.size()
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".obj"), FileAccess.WRITE)
	f.store_string("mtllib %s.mtl\nusemtl palette\n" % model + "\n".join(v_lines) + "\n" + "\n".join(vt_lines) + "\n" + "\n".join(vn_lines) + "\n" + "\n".join(f_lines) + "\n")
	var mtl := FileAccess.open(ProjectSettings.globalize_path(dir + model + ".mtl"), FileAccess.WRITE)
	mtl.store_string("newmtl palette\nKd 1 1 1\nmap_Kd %s.png\n" % model)
	_palette.save_png(ProjectSettings.globalize_path(dir + model + ".png"))

# Exposed faces bucketed by (axis, sign, slice) then greedy-merged in the plane. exposed[0] receives the
# raw exposed-face count (for the area-conservation check). Quad = [naxis, sgn, slice, a0, b0, da, db, slot].
func _greedy_quads(exposed: Array) -> Array:
	var quads: Array = []
	for naxis in 3:
		var A := (naxis + 1) % 3; var B := (naxis + 2) % 3
		for sgn in [1, -1]:
			var nrm := Vector3i.ZERO
			nrm[naxis] = sgn
			var slices := {}
			for key in grid:
				if grid.has(key + nrm): continue
				var s: int = key[naxis]
				if not slices.has(s): slices[s] = {}
				slices[s][Vector2i(key[A], key[B])] = grid[key]
			for s in slices:
				var mask: Dictionary = slices[s]
				exposed[0] += mask.size()
				_merge_slice(mask, quads, naxis, sgn, s)
	return quads

func _merge_slice(mask: Dictionary, quads: Array, naxis: int, sgn: int, s: int) -> void:
	var amin := 1 << 30; var amax := -(1 << 30); var bmin := 1 << 30; var bmax := -(1 << 30)
	for k in mask:
		amin = mini(amin, k.x); amax = maxi(amax, k.x); bmin = mini(bmin, k.y); bmax = maxi(bmax, k.y)
	var done := {}
	for b in range(bmin, bmax + 1):
		for a in range(amin, amax + 1):
			var k0 := Vector2i(a, b)
			if not mask.has(k0) or done.has(k0): continue
			var slot: int = mask[k0]
			var da := 1
			while mask.get(Vector2i(a + da, b), -1) == slot and not done.has(Vector2i(a + da, b)):
				da += 1
			var db := 1
			var grow := true
			while grow:
				for aa in range(a, a + da):
					var kk := Vector2i(aa, b + db)
					if mask.get(kk, -1) != slot or done.has(kk):
						grow = false; break
				if grow: db += 1
			for aa in range(a, a + da):
				for bb in range(b, b + db):
					done[Vector2i(aa, bb)] = true
			quads.append([naxis, sgn, s, a, b, da, db, slot])

func _write_vox(path: String, mv_size: Vector3i) -> void:
	var xyzi := StreamPeerBuffer.new()
	xyzi.put_32(grid.size())
	for key in grid:
		xyzi.put_u8(key.x); xyzi.put_u8(key.z); xyzi.put_u8(key.y); xyzi.put_u8(grid[key] + 1)
	var size_c := StreamPeerBuffer.new()
	size_c.put_32(mv_size.x); size_c.put_32(mv_size.y); size_c.put_32(mv_size.z)
	var rgba := StreamPeerBuffer.new()
	for i in 256:
		var col := _palette.get_pixel(i, 0)
		rgba.put_u8(int(col.r * 255.0)); rgba.put_u8(int(col.g * 255.0)); rgba.put_u8(int(col.b * 255.0)); rgba.put_u8(255)
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
