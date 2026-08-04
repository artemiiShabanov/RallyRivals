extends SceneTree
## Voxel CAR generator (art-voxel-brand-families, ADR-003) — SPEC-DRIVEN per the Car Spec Sheet: real-car
## proportions/angles/details are inputs (SPEC), not guesses. First reference: Lancia Delta HF Integrale
## Evoluzione (3900x1770x1365, WB 2480), in Apex livery (pale-yellow #fff59e body + red #e81900 accent).
## Flat hood (Rule 4), upright 80s greenhouse, flared arches, full detail pass (Rule 5). 25 mm.
## Run: godot --headless --script res://scripts/tools/gen_voxel_cars.gd

const VOX := 0.033
# Staged build (validate between steps). 1 base volume · 2 body kit (arches/flares/wing) · 3 doors+windows ·
# 4 hood+roof · 5 front · 6 back · 7 accessories (mirrors/handles). Wheels are a SEPARATE model — never here.
const STEP := 7
var grid := {}
var _palette: Image
var _cells := {}
var S := {}   # resolved palette slots

# ---- rig geometry (Godot VehicleBody3D in car.tscn — FIXED, shared by EVERY car model) ----
const RIG_WB := 2.8        # wheels at z = ±1.4
const RIG_TRACK := 1.7     # wheels at x = ±0.85
const RIG_WHEEL_R := 0.40
# ---- Lancia Delta HF Integrale Evo — real proportions SCALED (×1.13) so its wheelbase matches the rig.
# Arches (Step 1) are rig-fixed: radius RIG_WHEEL_R at wz_f/wz_r, half-track 0.85 -> identical on every car.
# Front/back kept flat & upright (Lancia), roof 15% narrower than body, window base ~flush with the doors. ----
const SPEC := {
	"L": 4.40, "body_w": 2.00,
	"floor": 0.3, "belt": 0.98, "roof": 1.52, "glass_top": 1.45,     # raised body -> more ground clearance
	"cowl": 1.30, "roof_front": 1.92, "roof_rear": 2.99,          # lengthwise z boundaries (from nose)
	"green_belt_w": 1.92, "roof_w": 1.70,                         # greenhouse: belt ~flush; roof 15% narrower
	"wz_f": 0.90, "wz_r": 3.70,                                   # front/rear axle z (wheelbase 2.8)
	"nose_taper": 0.06, "tail_taper": 0.06, "nose_drop": 0.06,    # flat, upright front/back (Lancia)
	"nose_point_d": 0.10, "nose_side_d": 0.07, "nose_side_z": 0.30,  # step-5 pointy nose: 60° lower chamfer + lighter plan bevel
	"tail_point_d": 0.16, "tail_side_d": 0.07, "tail_side_z": 0.30,  # step-6 tail: harder lower tuck + lighter plan bevel
	"tail_top_d": 0.12,                                          # step-6 tail: top-rear edge chamfer
	"spoiler": false, "roof_bulge": false,                       # per-model kit toggles (this Delta: neither)
}

func _initialize() -> void:
	_palette = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/voxels/cars/_review/"))
	S = {
		"body": _slot(Color("bfffe6")), "shade": _slot(Color("7fc4ad")), "acc": _slot(Color("c9303e")),
		"dark": _slot(Color("18181c")), "glass": _slot(Color("5c7086")), "tire": _slot(Color("101014")),
		"chrome": _slot(Color("c6cad0")), "amber": _slot(Color("ff8c00")), "red": _slot(Color("c01818")),
	}
	_car()
	_render("front", Vector3(0.5, 0.3, -0.8))           # nose 3/4, near head-on — for front details/shape
	_render("side", Vector3(1.0, 0.1, 0.04))            # true side profile — for judging proportions vs spec
	_render("rear", Vector3(-0.5, 0.32, 0.8))           # tail 3/4, near head-on — for rear details/shape
	_sheet()
	_write_vox("res://assets/voxels/cars/_review/delta.vox")   # open in MagicaVoxel to inspect
	print("delta -> assets/voxels/cars/_review/{sheet_car.png, delta.vox} (%d vox)" % grid.size())
	quit()

func _rz(m: float) -> int:
	return int(round(m / VOX))

# ============================ BUILD ============================
var c := 0   # x-centre (voxels)
func _car() -> void:
	grid = {}
	c = _rz(SPEC.body_w * 0.5) + _rz(0.14)
	_lower_body()                       # 1 · base volume (+ arches: rig-fixed, all cars)
	_greenhouse()
	_arches()
	if STEP >= 2:                       # 2 · body kit (added volumes)
		_bodykit()
	if STEP >= 3:                       # 3 · doors + windows
		_glass()
		_door_seams()
	if STEP >= 4:                       # 4 · hood + roof
		_hood_details()
	if STEP >= 5:                       # 5 · front (shape THEN detail)
		_nose_shape()
		_front_details()
	if STEP >= 6:                       # 6 · back (shape THEN detail)
		_tail_shape()
		_rear_details()
	if STEP >= 7:                       # 7 · accessories
		_accessories()
	_settle()

# Lower tub with a FLAT hood/beltline top. Front + back are kept flat & upright (small taper/drop only at
# the very ends) — a Lancia has near-vertical nose/tail, not a rounded wedge. Subtle top-outer shoulder.
func _lower_body() -> void:
	var L := _rz(SPEC.L); var floor := _rz(SPEC.floor); var belt := _rz(SPEC.belt)
	var bhw := _rz(SPEC.body_w * 0.5)
	var nt := float(bhw) * float(SPEC.nose_taper); var tt := float(bhw) * float(SPEC.tail_taper)
	for z in range(0, L):
		var zm := z * VOX
		var hw := bhw
		if zm < 0.18: hw = bhw - int(nt * smoothstep(0.18, 0.0, zm))
		elif zm > SPEC.L - 0.18: hw = bhw - int(tt * smoothstep(SPEC.L - 0.18, SPEC.L, zm))
		var top := belt
		if zm < 0.14: top = belt - int(float(_rz(SPEC.nose_drop)) * smoothstep(0.14, 0.0, zm))
		for x in range(c - hw, c + hw):
			var ex := float(absi(x - c)) / float(maxi(hw, 1))
			var t := top - int(_rz(0.04) * smoothstep(0.84, 1.02, ex))       # subtle top-outer shoulder
			for y in range(floor, t):
				grid[Vector3i(x, y, z)] = S.body

# Upright greenhouse: raked windshield -> flat roof -> raked backlight. Width flows FLUSH from the doors
# (belt ~body width, small shoulder) and tumbles inward to a roof 15% narrower than the body — no big step.
func _greenhouse() -> void:
	var belt := _rz(SPEC.belt); var roof := _rz(SPEC.roof)
	var wb := _rz(SPEC.green_belt_w * 0.5); var wr := _rz(SPEC.roof_w * 0.5)
	for z in range(_rz(SPEC.cowl), _htail() + 1):
		var rp := _roof_at(z)
		for y in range(belt, rp):
			var yf := float(y - belt) / float(maxi(roof - belt, 1))
			var w := int(lerpf(float(wb), float(wr), yf))                     # tumblehome: belt -> roof
			for x in range(c - w, c + w):
				grid[Vector3i(x, y, z)] = S.body

# Hatchback: no flat deck — the rear glass/hatch rakes from the roof rear all the way down to ~belt near
# the tail (backlight + deck merged into one continuous slope). Only a short tailgate/bumper below it.
func _htail() -> int:
	return _rz(SPEC.L) - _rz(0.12)

func _roof_at(z: int) -> int:
	var belt := _rz(SPEC.belt); var roof := _rz(SPEC.roof)
	var cowl := _rz(SPEC.cowl); var rf := _rz(SPEC.roof_front); var rr := _rz(SPEC.roof_rear); var ht := _htail()
	if z <= cowl or z >= ht: return belt
	if z < rf: return int(lerpf(float(belt), float(roof), smoothstep(0.0, 1.0, float(z - cowl) / float(maxi(rf - cowl, 1)))))
	if z > rr: return int(lerpf(float(roof), float(belt), smoothstep(0.0, 1.0, float(z - rr) / float(maxi(ht - rr, 1)))))
	return roof

# 3 · WINDOWS — windshield / side DLO (front + rear door + triangular quarter) / backlight, glass INSET
# 1 voxel so the frame + pillars sit proud. Pillars: A moderate (body), B moderate (BLACK), C VERY THICK
# (body) — the Delta's signature. Widths/colours are per-model choices (not tier).
const INSET_DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]
func _glass() -> void:
	var belt := _rz(SPEC.belt); var header := _rz(SPEC.glass_top); var ht := _htail()
	var cowl := _rz(SPEC.cowl); var apz := _rz(SPEC.roof_front); var cpz := _rz(SPEC.roof_rear)
	var bpz := (apz + cpz) / 2
	var bth := 1                                                      # B-pillar thin ~3-voxel line
	for k in grid.keys():
		if grid[k] != S.body or k.z < cowl or k.z > ht: continue
		if k.y < belt + _rz(0.04) or k.y > header: continue
		var xexp := not grid.has(k + Vector3i(1, 0, 0)) or not grid.has(k + Vector3i(-1, 0, 0))
		var oexp := not grid.has(k + Vector3i(0, 0, 1)) or not grid.has(k + Vector3i(0, 0, -1)) or not grid.has(k + Vector3i(0, 1, 0))
		if not xexp and not oexp: continue                            # interior
		var zc: int = k.z
		if zc <= apz:                                                 # WINDSHIELD ramp — glass its front/top surface
			if xexp and not oexp: continue                            # its x-edge IS the thin diagonal A-pillar (body)
			grid[k] = S.glass; continue
		if zc < cpz:                                                  # SIDE DLO — front + rear door windows
			if not xexp: continue
			if absi(zc - bpz) <= bth: grid[k] = S.dark; continue      # B-pillar: black, proud
			_inset(k, S.glass); continue                              # door windows: inset 1 voxel
		# zc >= cpz — C-pillar body TRIANGLE (apex touches roof at cpz) + a triangular BLACK quarter light,
		# framed so it eats only the front ~1/3 of the C-pillar, never the roof-touching front/top edges.
		if xexp:
			var rp := _roof_at(zc)
			if zc > cpz + 2 and zc < cpz + (ht - cpz) / 3 and k.y < rp - _rz(0.06):
				_inset(k, S.dark)                                     # quarter light: black, inset
			continue                                                  # rest of the C-pillar: body (reaches roof)
		grid[k] = S.glass                                             # backlight rear glass (flush)

func _inset(k: Vector3i, slot: int) -> void:
	for o in INSET_DIRS:
		if not grid.has(k + o):
			grid.erase(k)
			if grid.has(k - o): grid[k - o] = slot                    # recess 1 voxel along the surface normal
			return

# 4 · HOOD + ROOF surface detail (colour only — Rule 6; paints the actual TOP voxel so it rides the
# power bulge instead of a covered voxel underneath). Hood: fender + cowl shut lines, centre power-bulge
# shadow, twin NACA bonnet louvres. Roof: drip rails down both gutters (see _roof_details).
func _hood_details() -> void:
	var cowl := _rz(SPEC.cowl)
	# fender shut lines (both sides) + a shut line across the cowl base
	for z in range(_rz(0.26), cowl):
		_paint_top(c - _rz(0.62), z, S.shade); _paint_top(c + _rz(0.62), z, S.shade)
	for x in range(c - _rz(0.64), c + _rz(0.64) + 1):
		_paint_top(x, cowl - 1, S.shade)
	# centre power-bulge shadow lines (imply the raised dome)
	for z in range(_rz(0.46), cowl - _rz(0.05)):
		_paint_top(c - _rz(0.17), z, S.shade); _paint_top(c + _rz(0.17), z, S.shade)
	# twin NACA bonnet louvres on the bulge (Integrale cue) — alternating dark/shade slats
	for vz in [_rz(0.62), _rz(0.86)]:
		for x in range(c - _rz(0.13), c + _rz(0.13) + 1):
			for dz in range(0, _rz(0.12)):
				_paint_top(x, vz + dz, S.dark if dz % 2 == 0 else S.shade)
	_roof_details()

# Roof drip rails — the gutter where the roof panel meets the side glass, both sides, front→rear.
func _roof_details() -> void:
	var rf := _rz(SPEC.roof_front); var rr := _rz(SPEC.roof_rear); var roof := _rz(SPEC.roof)
	var bhw := _rz(SPEC.body_w * 0.5)
	for z in range(rf - _rz(0.04), rr + _rz(0.05)):
		for side in [-1, 1]:
			var s: int = side
			for x in range(c + s * (bhw + 2), c, -s):
				if grid.has(Vector3i(x, roof - 1, z)):
					grid[Vector3i(x, roof - 1, z)] = S.shade
					break

# Paint the topmost solid voxel of column (x, z) — follows bulges/shoulders instead of a fixed y.
func _paint_top(x: int, z: int, slot: int) -> void:
	for y in range(_rz(1.7), _rz(SPEC.floor) - 1, -1):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			grid[k] = slot
			return

# 5 · FRONT shape — Step 1 left the nose a flat slab (Rule 4). Point it up now, per SPEC (per-model):
#  · lower-front chamfer, ~60° from the ground, over the bottom third, a couple of voxels deep (side view)
#  · a LIGHTER plan-view bevel pulling the front corners in near the tip (top view)
# so the nose reads pointed both ways instead of a wall. Runs before the detail paint so it paints what stays.
func _nose_shape() -> void:
	var floor := _rz(SPEC.floor); var belt := _rz(SPEC.belt); var bhw := _rz(SPEC.body_w * 0.5)
	var third := int((belt - floor) / 3.0)
	var vd := _rz(SPEC.nose_point_d)                          # lower chamfer depth at the very bottom
	var sd := _rz(SPEC.nose_side_d); var sz := _rz(SPEC.nose_side_z)   # plan bevel: depth over front z-span
	for k in grid.keys():
		if k.z > sz: continue                                # nose zone only
		# lower-front chamfer (side view): cut z ahead of a rising ~60° plane over the bottom third
		if k.y < floor + third:
			var cut := int(round(float(vd) * (1.0 - float(k.y - floor) / float(maxi(third, 1)))))
			if k.z < cut: grid.erase(k); continue
		# front-corner bevel (plan view): outer x pulled in near the tip, easing to full width by sz
		var keep_hw := bhw - int(round(float(sd) * (1.0 - float(k.z) / float(maxi(sz, 1)))))
		if absi(k.x - c) >= keep_hw: grid.erase(k)

# 5 · FRONT detail — paints the actual FRONT FACE (first solid voxel scanning back from z=0, via
# _paint_front) so nothing hides under the z=0 skin, and it follows the raked chin from _nose_shape.
func _front_details() -> void:
	var floor := _rz(SPEC.floor)
	var gl := floor + _rz(0.32); var gh := floor + _rz(0.54)         # grille / headlight band
	# grille — dark slatted panel across the centre
	for x in range(c - _rz(0.32), c + _rz(0.32)):
		for y in range(gl, gh):
			_paint_front(x, y, S.dark if (y - gl) % 3 != 0 else S.shade)
	# Lancia shield badge (red) in the grille centre
	for x in range(c - _rz(0.05), c + _rz(0.05)):
		for y in range(gl + _rz(0.04), gh - _rz(0.04)):
			_paint_front(x, y, S.acc)
	# rectangular headlights flanking the grille (chrome)
	for hx in [c - _rz(0.66), c + _rz(0.48)]:
		for x in range(hx, hx + _rz(0.18)):
			for y in range(gl + _rz(0.02), gh - _rz(0.02)):
				_paint_front(x, y, S.chrome)
	# amber indicators outboard of the lights
	for ix in [c - _rz(0.8), c + _rz(0.72)]:
		for x in range(ix, ix + _rz(0.08)):
			for y in range(gl + _rz(0.03), gl + _rz(0.11)):
				_paint_front(x, y, S.amber)
	# dark bumper band across the lower nose + round fog lights + a light plate patch
	for x in range(c - _rz(0.72), c + _rz(0.72)):
		for y in range(floor + _rz(0.13), floor + _rz(0.27)):
			_paint_front(x, y, S.dark)
	for fx in [c - _rz(0.5), c + _rz(0.42)]:
		for x in range(fx, fx + _rz(0.09)):
			for y in range(floor + _rz(0.16), floor + _rz(0.24)):
				_paint_front(x, y, S.chrome)
	for x in range(c - _rz(0.16), c + _rz(0.16)):
		for y in range(floor + _rz(0.15), floor + _rz(0.25)):
			_paint_front(x, y, S.chrome)                             # licence plate
	for x in range(c - _rz(0.5), c + _rz(0.06)):                     # wiper resting across the cowl
		_paint_top(x, _rz(SPEC.cowl), S.dark)

# Paint the FRONT face voxel of column (x, y) — first solid scanning back from the nose (z=0).
func _paint_front(x: int, y: int, slot: int) -> void:
	for z in range(0, _rz(0.45)):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			grid[k] = slot
			return

# 6 · TAIL shape — Step 1 left the tail a flat slab; carve it now, per SPEC (per-model). Same two cuts as
# the nose but the lower tuck is HARDER (deeper + taller): a diffuser-like lower-rear chamfer + a lighter
# plan-view bevel on the rear corners. Runs before the detail paint so it paints what stays.
func _tail_shape() -> void:
	var L := _rz(SPEC.L); var floor := _rz(SPEC.floor); var belt := _rz(SPEC.belt); var bhw := _rz(SPEC.body_w * 0.5)
	var hh := int((belt - floor) * 0.42)                          # taller than the nose third ("bottom even harder")
	var th := int((belt - floor) * 0.30)                          # top-rear chamfer height
	var vd := _rz(SPEC.tail_point_d)                             # deeper lower-rear chamfer
	var td := _rz(SPEC.tail_top_d)                              # top-rear edge chamfer depth
	var sd := _rz(SPEC.tail_side_d); var sz := _rz(SPEC.tail_side_z)
	for k in grid.keys():
		var zr: int = (L - 1) - k.z                              # distance forward from the rear face
		if zr > sz: continue                                    # tail zone only
		# lower-rear chamfer (side view): tuck z behind a rising cut over the bottom ~40%
		if k.y < floor + hh:
			var cut := int(round(float(vd) * (1.0 - float(k.y - floor) / float(maxi(hh, 1)))))
			if zr < cut: grid.erase(k); continue
		# top-rear chamfer (side view): bevel the top edge, deepest at the deck, easing down
		if k.y > belt - th:
			var cutt := int(round(float(td) * (1.0 - float(belt - k.y) / float(maxi(th, 1)))))
			if zr < cutt: grid.erase(k); continue
		# rear-corner bevel (plan view): outer x pulled in near the tail, easing to full width by sz
		var keep_hw := bhw - int(round(float(sd) * (1.0 - float(zr) / float(maxi(sz, 1)))))
		if absi(k.x - c) >= keep_hw: grid.erase(k)

# 6 · REAR detail — paints the visible REAR face (first solid scanning forward from z=L-1, via _paint_rear)
# so it follows the tucked tail. Tail lamps, bumper, reflectors, plate, badge. (No spoiler: this model kit-off.)
func _rear_details() -> void:
	var floor := _rz(SPEC.floor)
	# full-width tail lamp band (red)
	for x in range(c - _rz(0.72), c + _rz(0.72)):
		for y in range(floor + _rz(0.3), floor + _rz(0.46)):
			_paint_rear(x, y, S.red)
	# dark rear bumper band + amber reflectors + a light plate patch
	for x in range(c - _rz(0.72), c + _rz(0.72)):
		for y in range(floor + _rz(0.12), floor + _rz(0.26)):
			_paint_rear(x, y, S.dark)
	for rx in [c - _rz(0.56), c + _rz(0.48)]:
		for x in range(rx, rx + _rz(0.08)):
			for y in range(floor + _rz(0.15), floor + _rz(0.23)):
				_paint_rear(x, y, S.amber)
	for x in range(c - _rz(0.18), c + _rz(0.18)):
		for y in range(floor + _rz(0.14), floor + _rz(0.24)):
			_paint_rear(x, y, S.chrome)                          # licence plate
	# badge high on the tailgate
	for x in range(c - _rz(0.05), c + _rz(0.05)):
		for y in range(floor + _rz(0.52), floor + _rz(0.62)):
			_paint_rear(x, y, S.acc)

# Paint the REAR face voxel of column (x, y) — first solid scanning forward from the tail (z = L-1).
func _paint_rear(x: int, y: int, slot: int) -> void:
	for z in range(_rz(SPEC.L) - 1, _rz(SPEC.L) - 1 - _rz(0.45), -1):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			grid[k] = slot
			return

# 3 · doors — shut lines are VERTICAL (perpendicular to ground) and drop from where each pillar meets the
# base: A-pillar foot (cowl), B-pillar (bpz), C-pillar foot (roof_rear). + a dark rocker sill.
func _door_seams() -> void:
	var floor := _rz(SPEC.floor); var belt := _rz(SPEC.belt); var bhw := _rz(SPEC.body_w * 0.5)
	var bpz := (_rz(SPEC.roof_front) + _rz(SPEC.roof_rear)) / 2
	var cpz := _rz(SPEC.roof_rear); var cfront := cpz + (_htail() - cpz) / 3   # solid C-pillar (behind quarter)
	for dz in [_rz(SPEC.cowl), bpz, cfront]:
		for x in [c - bhw, c - bhw + 1, c + bhw - 1, c + bhw]:
			for y in range(floor + _rz(0.18), belt):
				_paint(x, y, dz, S.shade)
	for k in grid.keys():
		if grid[k] == S.body and k.y < floor + _rz(0.14) and k.z > _rz(0.9) and k.z < _rz(SPEC.L) - _rz(0.7):
			grid[k] = S.dark

# 7 · ACCESSORIES — side mirrors (short body stalk + dark glass head, at the A-pillar base ~belt height,
# ADDED outboard) + door handles (chrome nubs on the door skin just under the belt, painted on the outer face).
func _accessories() -> void:
	var belt := _rz(SPEC.belt); var bhw := _rz(SPEC.body_w * 0.5)
	var mz0 := _rz(SPEC.cowl) + _rz(0.05)                        # mirror sits just behind the A-pillar foot
	for side in [-1, 1]:
		var s: int = side; var xe: int = c + s * bhw            # first column just outside the body edge
		for z in range(mz0, mz0 + _rz(0.06)):                   # stalk bridging body -> housing
			grid[Vector3i(xe, belt + _rz(0.05), z)] = S.body
		for z in range(mz0 + _rz(0.04), mz0 + _rz(0.17)):       # mirror housing + glass, protruding outboard
			for y in range(belt + _rz(0.03), belt + _rz(0.12)):
				grid[Vector3i(xe + s, y, z)] = S.body
				grid[Vector3i(xe + s * 2, y, z)] = S.dark       # outward-facing mirror glass
	for hz in [_rz(2.0), _rz(2.72)]:                            # front-door + rear-door handles
		for side in [-1, 1]:
			for z in range(hz, hz + _rz(0.15)):
				_paint_side(belt - _rz(0.09), z, side, S.chrome)

# Paint the outer SIDE-face voxel of row (y, z) on the given side (-1 left / +1 right) — first solid scanning in.
func _paint_side(y: int, z: int, side: int, slot: int) -> void:
	var s: int = side
	for x in range(c + s * _rz(1.3), c, -s):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			grid[k] = slot
			return

# Wheel arches — RIG-FIXED so the shared wheel model (radius 0.40, at z ±1.4 / x ±0.85) sits inside every
# car identically. Carves the opening + a shade lip. NO wheels here (separate brand model at runtime).
func _arches() -> void:
	var r := _rz(RIG_WHEEL_R); var cy := _rz(RIG_WHEEL_R); var hw := _rz(SPEC.body_w * 0.5); var clr := 3
	for wz in [_rz(SPEC.wz_f), _rz(SPEC.wz_r)]:
		for x in range(c - hw - _rz(0.09), c + hw + _rz(0.09)):    # wide enough to cut through the flares too
			if x > c - hw + _rz(0.22) and x < c + hw - _rz(0.22): continue
			for y in range(_rz(SPEC.floor), cy + r + clr + 3):
				for z in range(wz - r - clr, wz + r + clr):
					var dz := float(z) + 0.5 - float(wz); var dy := float(y) + 0.5 - float(cy)
					var d := sqrt(dy * dy + dz * dz)
					if d <= float(r) + float(clr): grid.erase(Vector3i(x, y, z))            # opening: wheel + 3 vox
					elif d <= float(r) + float(clr) + 2.0 and grid.has(Vector3i(x, y, z)): grid[Vector3i(x, y, z)] = S.shade

# 2 · BODY KIT — added structural volumes (Delta Evo: box flares, tailgate spoiler, power/roof bulge,
# front lip, side skirts). Surface paint/vents/lights come in later steps. Magnitude would scale by tier.
func _bodykit() -> void:
	_flares()
	_arches()            # re-carve the openings through the new flare material
	if SPEC.get("spoiler", true): _spoiler()
	_splitter()
	_skirts()
	_hood_bulge()
	if SPEC.get("roof_bulge", false): _roof_bulge()

# Fender flares — an arch-following eyebrow lip protruding outboard (the Evo widebody), NOT a corner box.
# Fills a disc around each opening; _arches then re-carves the wheel hole, leaving the flare as a lip.
func _flares() -> void:
	var hw := _rz(SPEC.body_w * 0.5); var fw := _rz(0.05); var r := _rz(RIG_WHEEL_R); var cy := _rz(RIG_WHEEL_R)
	var floor := _rz(SPEC.floor)
	for wz in [_rz(SPEC.wz_f), _rz(SPEC.wz_r)]:
		for side in [-1, 1]:
			var s: int = side; var xe: int = c + s * hw
			for k in range(1, fw + 1):
				for z in range(wz - r - _rz(0.13), wz + r + _rz(0.13)):
					for y in range(floor, cy + r + _rz(0.13)):
						var dy := float(y) + 0.5 - float(cy); var dz := float(z) + 0.5 - float(wz)
						if sqrt(dy * dy + dz * dz) <= float(r) + float(_rz(0.14)):
							grid[Vector3i(xe + s * k, y, z)] = S.body

# Tailgate-top spoiler blade across the roof rear.
func _spoiler() -> void:
	var rr := _rz(SPEC.roof_rear); var rw := _rz(SPEC.roof_w * 0.5); var ry := _rz(SPEC.roof)
	for x in range(c - rw, c + rw):
		for z in range(rr - _rz(0.02), rr + _rz(0.14)):
			grid[Vector3i(x, ry, z)] = S.body
			grid[Vector3i(x, ry + 1, z)] = S.body

# Front lip / splitter chin at the nose base.
func _splitter() -> void:
	var floor := _rz(SPEC.floor)
	for x in range(c - _rz(0.8), c + _rz(0.8)):
		for z in range(0, _rz(0.09)):
			grid[Vector3i(x, floor, z)] = S.dark
			grid[Vector3i(x, floor + 1, z)] = S.dark

# Side sill / skirt extensions along the lower body between the arches.
func _skirts() -> void:
	var hw := _rz(SPEC.body_w * 0.5); var floor := _rz(SPEC.floor)
	for z in range(_rz(SPEC.wz_f) + _rz(0.45), _rz(SPEC.wz_r) - _rz(0.45)):
		for side in [-1, 1]:
			var s: int = side
			var xe: int = c + s * hw
			grid[Vector3i(xe + s, floor + _rz(0.05), z)] = S.dark
			grid[Vector3i(xe + s, floor + _rz(0.1), z)] = S.dark

# Bonnet power bulge — a SMOOTH dome: the raise tapers to zero toward the edges (x and z), so it blends
# into the hood instead of sitting as a hard raised block.
func _hood_bulge() -> void:
	var belt := _rz(SPEC.belt)
	var z0 := _rz(0.42); var z1 := _rz(SPEC.cowl) - _rz(0.08); var zc := (z0 + z1) / 2
	var xw := _rz(0.3); var maxh := _rz(0.055)
	for z in range(z0, z1):
		var fz := 1.0 - smoothstep(0.55, 1.0, float(absi(z - zc)) / float(maxi((z1 - z0) / 2, 1)))
		for x in range(c - xw, c + xw):
			var fx := 1.0 - smoothstep(0.5, 1.0, float(absi(x - c)) / float(maxi(xw, 1)))
			var h := int(round(float(maxh) * fx * fz))
			for y in range(belt, belt + h):
				grid[Vector3i(x, y, z)] = S.body

# Subtle roof bulge (requested) — raise the roof centre.
func _roof_bulge() -> void:
	var roof := _rz(SPEC.roof)
	for z in range(_rz(SPEC.roof_front) + _rz(0.15), _rz(SPEC.roof_rear) - _rz(0.1)):
		for x in range(c - _rz(0.22), c + _rz(0.22)):
			for y in range(roof, roof + _rz(0.04)):
				grid[Vector3i(x, y, z)] = S.body

# ---------- grid helpers ----------
func _paint(x: int, y: int, z: int, slot: int) -> void:
	if grid.has(Vector3i(x, y, z)): grid[Vector3i(x, y, z)] = slot

func _boxpaint(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for z in range(mini(z0, z1), maxi(z0, z1) + 1):
				_paint(x, y, z, slot)

func _box(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, slot: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1):
			for z in range(mini(z0, z1), maxi(z0, z1) + 1):
				grid[Vector3i(x, y, z)] = slot

func _slot(target: Color) -> int:
	var best := INF; var pick := 0
	for i in 256:
		var col := _palette.get_pixel(i, 0)
		if col.r + col.g + col.b < 0.06: continue
		var dd := Vector3(col.r - target.r, col.g - target.g, col.b - target.b).length()
		if dd < best: best = dd; pick = i
	return pick

# Real MagicaVoxel .vox (VOX 150) with the master palette embedded — open it to inspect/sculpt.
func _write_vox(path: String) -> void:
	var mx := 0; var my := 0; var mz := 0
	for k in grid: mx = maxi(mx, k.x); my = maxi(my, k.y); mz = maxi(mz, k.z)
	var xyzi := StreamPeerBuffer.new()
	xyzi.put_32(grid.size())
	for k in grid:
		xyzi.put_u8(k.x); xyzi.put_u8(k.z); xyzi.put_u8(k.y); xyzi.put_u8(grid[k] + 1)   # MV axes: x, z(depth), y(up)
	var size_c := StreamPeerBuffer.new()
	size_c.put_32(mx + 1); size_c.put_32(mz + 1); size_c.put_32(my + 1)
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

func _settle() -> void:
	if grid.is_empty(): return
	var mn := Vector3i(1 << 30, 1 << 30, 1 << 30)
	for k in grid: mn.x = mini(mn.x, k.x); mn.y = mini(mn.y, k.y); mn.z = mini(mn.z, k.z)
	if mn == Vector3i.ZERO: return
	var ng := {}
	for k in grid: ng[k - mn] = grid[k]
	grid = ng

# ---------- preview ----------
const N6 := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const CW := 430
const CH := 210
func _render(nm: String, dv: Vector3) -> void:
	var d := dv.normalized()
	var right := Vector3.UP.cross(d).normalized()
	var up := d.cross(right).normalized()
	if up.y < 0.0: up = -up
	var lightv := Vector3(0.4, 0.85, 0.32).normalized()
	var shell: Array = []
	var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for key in grid:
		var nrm := Vector3.ZERO
		for o in N6:
			if not grid.has(key + o): nrm += Vector3(o)
		if nrm == Vector3.ZERO: continue
		var p := Vector3(key)
		var s := Vector2(p.dot(right), p.dot(up))
		shell.append([s, p.dot(d), nrm.normalized(), grid[key]])
		mn = mn.min(s); mx = mx.max(s)
	var span := mx - mn
	var scale := minf((CW - 20) / maxf(span.x, 1.0), (CH - 20) / maxf(span.y, 1.0))
	var ox := (CW - span.x * scale) * 0.5; var oy := (CH - span.y * scale) * 0.5
	var blk := maxi(int(ceil(scale)), 1)
	var img := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.11, 0.12, 0.15))
	var zbuf := PackedFloat32Array(); zbuf.resize(CW * CH); zbuf.fill(-INF)
	for e in shell:
		var s: Vector2 = e[0]; var depth: float = e[1]
		var shade: float = clampf((e[2] as Vector3).dot(lightv), 0.0, 1.0) * 0.7 + 0.3
		var base: Color = _palette.get_pixel(int(e[3]), 0)
		var col := Color(base.r * shade, base.g * shade, base.b * shade)
		var px := int((s.x - mn.x) * scale + ox); var py := CH - 1 - int((s.y - mn.y) * scale + oy)
		for iy in range(py - blk, py + 1):
			for ix in range(px, px + blk):
				if ix < 0 or iy < 0 or ix >= CW or iy >= CH: continue
				var zi := iy * CW + ix
				if depth > zbuf[zi]: zbuf[zi] = depth; img.set_pixel(ix, iy, col)
	_cells[nm] = img

func _sheet() -> void:
	var img := Image.create(CW, CH * 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.08, 0.1))
	var i := 0
	for nm in ["front", "side", "rear"]:
		if _cells.has(nm): img.blit_rect(_cells[nm], Rect2i(0, 0, CW, CH), Vector2i(0, i * CH))
		i += 1
	img.save_png(ProjectSettings.globalize_path("res://assets/voxels/cars/_review/sheet_car.png"))
