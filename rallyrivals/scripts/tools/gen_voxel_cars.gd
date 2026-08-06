extends SceneTree
## Voxel CAR generator (art-voxel-car-*, ADR-003) — SPEC-DRIVEN per the Car Spec Sheet: real-car
## proportions/angles/details are inputs (SPEC), not guesses. Each car picks a real reference (docs/CARS.md)
## and is scaled so its wheelbase = the rig's 2.8 m; arches are rig-fixed so the shared wheel model drops in.
## Set CAR + STEP, run, validate the render, bump STEP. 33 mm voxels.
## Run: godot --headless --script res://scripts/tools/gen_voxel_cars.gd

const VOX := 0.033
# Staged build (validate between steps). 0 BLUEPRINT (side/top/rear ortho views straight from SPEC — validate
# proportions BEFORE any modelling, when a fix is one number) · 1 base volume · 2 body kit (arches/flares/wing) ·
# 3 doors+windows · 4 hood+roof · 5 front · 6 back · 7 accessories (mirrors/handles) · 8 accent colouring
# (livery stripes, roundel, prints). Wheels are a SEPARATE model — never here.
const STEP := 8
var grid := {}
var _palette: Image
var _cells := {}
var S := {}   # resolved palette slots

# ---- rig geometry (Godot VehicleBody3D in car.tscn — FIXED, shared by EVERY car model) ----
const RIG_WB := 2.8        # wheels at z = ±1.4
const RIG_TRACK := 1.7     # wheels at x = ±0.85
const RIG_WHEEL_R := 0.40
# ---- Per-car SPECs: real reference dimensions SCALED so the wheelbase matches the rig's 2.8 m. Arches are
# rig-fixed (radius RIG_WHEEL_R at wz_f/wz_r, half-track 0.85) -> identical on every car, shared wheel drops in.
# `body_style`: "hatch" = the backlight rakes to the tail, no deck (rule 7) · "sedan" = the backlight lands on
# a FLAT trunk deck at `deck_z`. References + rationale: docs/CARS.md. ----
const CAR := "verdict"
const CARS := {
	# Apex D — Lancia Delta HF Integrale Evoluzione (3900×1770×1365, WB 2480) ×1.13. Flat upright nose/tail,
	# upright 80s greenhouse, widebody flares. DONE (hand-finished in MV -> assets/voxels/cars/delta.vox).
	"kerb": {
		"body_style": "hatch",
		"L": 4.40, "body_w": 2.00,
		"floor": 0.3, "belt": 0.98, "roof": 1.52, "glass_top": 1.45,
		"cowl": 1.30, "roof_front": 1.92, "roof_rear": 2.99,
		"green_belt_w": 1.92, "roof_w": 1.70,
		"wz_f": 0.90, "wz_r": 3.70,
		"nose_taper": 0.06, "tail_taper": 0.06, "nose_drop": 0.06,
		"nose_point_d": 0.10, "nose_side_d": 0.07, "nose_side_z": 0.30,
		"tail_point_d": 0.16, "tail_side_d": 0.07, "tail_side_z": 0.30, "tail_top_d": 0.12,
		"spoiler": false, "roof_bulge": false, "hood_louvres": true, "side_doors": 1,
		"accent_twin_stripe": true, "accent_belt_stripe": true, "accent_roundel": true, "accent_rocker": false,
	},
	# Apex C — Subaru Impreza WRX STi GC8 4-DOOR SEDAN (4340×1690×1405, WB 2520) ×1.111. Notchback: raked
	# backlight onto a flat trunk deck. Longer nose (boxer bay) than the cab-forward Delta, more tumblehome,
	# rounder 90s nose (bigger taper/drop), and the 555's big deck wing.
	"tangent": {
		"body_style": "sedan",
		"L": 4.82, "body_w": 1.88,
		# lengthwise z + belt MEASURED OFF THE REFERENCE PHOTO (assets/refs/tangent_side.png), as fractions of
		# L: windshield ~0.11 · roof ~0.27 (long — it spans BOTH doors) · backlight ~0.11 · belt 0.64 of height.
		# base (floor->belt) +15%: belt 1.05 -> 1.16, and roof/glass_top LIFTED by the same +0.11 so the
		# greenhouse keeps its full height and rake instead of being squashed against a fixed roof.
		"floor": 0.30, "belt": 1.16, "roof": 1.67, "glass_top": 1.62,
		"roof_crown": 0.03, "tail_drop": 0.07, "shoulder_r": 0.13,      # crowned roof, rounded tail + shoulders
		# glass rake: windshield run 0.85 / backlight 0.75 over a 0.51 rise -> 31° / 34° from horizontal
		# (was ~46° avg and ~57° through the smoothstep middle). Roof length unchanged at 1.30.
		"cowl": 1.45, "roof_front": 2.30, "roof_rear": 3.60, "deck_z": 4.35,
		"green_belt_w": 1.80, "roof_w": 1.52,
		"wz_f": 1.05, "wz_r": 3.85,
		"skirt_h": 0.24, "skirt_out": 0.08,                          # beefy perimeter skirt (front/side/rear)
		"hood_drop": 0.22, "deck_drop": 0.06,                        # hood rakes hard toward the nose (~10°)
		"nose_taper": 0.10, "tail_taper": 0.08, "nose_drop": 0.04,
		"nose_point_d": 0.12, "nose_side_d": 0.09, "nose_side_z": 0.34,
		"nose_round": 0.12, "nose_upback": 0.14,                     # nose is a VOLUME: convex face, lip proud
		"tail_point_d": 0.12, "tail_side_d": 0.08, "tail_side_z": 0.30, "tail_top_d": 0.06,
		"spoiler": true, "roof_bulge": false,
		"side_doors": 2,                                             # 4-door sedan -> a handle on each door
		"hood_scoop": true, "scoop_z": 0.72, "scoop_len": 0.44,      # the Impreza's bonnet scoop
		# 555-style livery in Apex colours: flank sweep + door number panel + accented wing
		"accent_twin_stripe": false, "accent_belt_stripe": false, "accent_roundel": false, "accent_rocker": false,
		"accent_flank_sweep": true, "accent_door_panel": true, "accent_wing": true,
	},
	# Apex B — Audi Ur-Quattro (4404×1722×1346, WB 2524) ×1.109. NOT the Sport S1: the long-wheelbase
	# original, boxy and angular — flat level hood, upright greenhouse, short boot, and its signature
	# BLISTERED arches (flare_w nearly double the Impreza's). 2-door coupé, modest boot-lid lip.
	"meridian": {
		"body_style": "hatch",                                       # backlight rakes to the very tail
		"L": 4.89, "body_w": 1.91,
		"floor": 0.30, "belt": 1.09, "roof": 1.60, "glass_top": 1.55,
		"roof_crown": 0.02, "tail_drop": 0.04, "shoulder_r": 0.09,   # angular: crisper than the Impreza
		"cowl": 1.72, "roof_front": 2.41, "roof_rear": 3.57,
		"green_belt_w": 1.81, "roof_w": 1.59,
		"wz_f": 1.02, "wz_r": 3.82,
		"skirt_h": 0.20, "skirt_out": 0.05,
		"hood_drop": 0.10, "deck_drop": 0.04,                        # flat, level bonnet
		"nose_taper": 0.05, "tail_taper": 0.05, "nose_drop": 0.03,
		"nose_point_d": 0.08, "nose_side_d": 0.06, "nose_side_z": 0.30,
		"nose_round": 0.06, "nose_upback": 0.08,                     # flat upright face
		"tail_point_d": 0.26, "tail_cut_h": 0.52,                    # lower rear chopped hard away
		"tail_side_d": 0.06, "tail_side_z": 0.28, "tail_top_d": 0.05, "tail_round": 0.05,
		"flare_w": 0.09,                                             # BLISTERED arches — the Quattro cue
		"spoiler": true, "spoiler_style": "stand", "spoiler_h": 0.20,     # blade raised on stands at the tail
		"roof_bulge": false, "hood_bulge": false,                    # the Quattro bonnet is FLAT
		"side_doors": 1,
		"antenna": true, "antenna_h": 0.46,                           # roof whip antenna
		# Audi Sport works livery reads white + red + black, which the Apex palette already is: a red
		# beltline stripe and rocker flash with a dark competition number panel on the doors.
		"accent_twin_stripe": false, "accent_roundel": false, "accent_flank_sweep": false,
		"accent_belt_stripe": true, "accent_rocker": true, "accent_door_panel": true,
	},
	# Apex A — Lancia Stratos HF Stradale (3710×1750×1110, WB 2180) ×1.284, the biggest scale-up in the
	# roster. MID-ENGINED, so "sedan": the backlight drops onto a FLAT engine deck that then runs a third of
	# the car to a Kamm tail — the notchback branch, but with a Group 4 tail LIP, not a saloon's deck wing.
	# THREE numbers make this car, and two of them fight the rig:
	#  · Its reputation is NOT a short wheelbase-vs-length (0.588 is actually LONG — a Dino is 0.553); it is
	#    wheelbase-vs-WIDTH, 1.25 (Dino 1.38). So the character is LOW AND WIDE, never stubby. Don't shorten it.
	#  · Pure scaling wants body_w 2.25, but the rig track (1.7) is 0.14 NARROWER than scale-correct here, so a
	#    2.25 body would sink the wheels ~5 voxels into tunnels. Real Stratos: the body overhangs the outer
	#    tyre by only 43 mm. Fix: the waist is 2.06 (0.07 overhang, honest) and the FLARES carry the missing
	#    width back out to 2.24 at the arches — which is the Stratos's actual plan-view shape anyway.
	#  · It is the ONE car whose arcade wheel is nearly honest: real r 0.321 ×1.284 = 0.413 vs the rig's 0.44,
	#    +7% (every other car is +30%). So it needs almost none of the usual arcade lift — floor 0.25, not 0.30
	#    — and it still must not be slammed: 130 mm of real ground clearance, because it was bred to rally.
	"verdict": {
		"body_style": "sedan",                                       # backlight -> flat engine deck -> Kamm tail
		"L": 4.44, "body_w": 2.06,
		"floor": 0.25, "belt": 1.04, "roof": 1.45, "glass_top": 1.40,
		"deck_rise": 0.24,                                           # engine cover rides 30% higher than the belt
		"roof_crown": 0.02, "tail_drop": 0.02, "shoulder_r": 0.10,   # Kamm tail: cut off square, barely rounded
		# Cabin landmarks straight off the side view as fractions of L: cowl 0.30 · screen top 0.44 · roof end
		# 0.56 · deck 0.69 — i.e. a SHORT helmet cabin centred on the wheelbase, with 0.31 L of engine deck
		# behind it. Both rakes land ~32° from horizontal (planar glass, per the smoothstep lesson).
		"cowl": 1.42, "roof_front": 2.08, "roof_rear": 3.44, "deck_z": 3.74,
		"green_belt_w": 1.70, "roof_w": 1.42,                        # helmet cabin: huge tumblehome (0.69 of body)
		"wz_f": 0.90, "wz_r": 3.70,                                  # overhangs 0.19 L front / 0.22 L rear
		"skirt_h": 0.16, "skirt_out": 0.04,                          # slim sills — no chunky bolt-on kit
		"hood_drop": 0.32, "deck_drop": 0.02,                        # WEDGE bonnet: nose tip drops to 0.64 m
		"nose_taper": 0.14, "tail_taper": 0.04, "nose_drop": 0.08,
		"nose_point_d": 0.24, "nose_side_d": 0.09, "nose_side_z": 0.34,   # deep 30° chin chamfer
		"nose_round": 0.10, "nose_upback": 0.10,
		# The lower rear is chopped away as ONE long ramp starting under the backlight (z 3.76) and rising to
		# the tail — not a corner chamfer. tail_side_z has to span the whole ramp or _tail_shape's zone gate
		# (`zr > sz: continue`) clips it back to a stub.
		"tail_point_d": 0.70, "tail_cut_h": 0.45,
		"tail_side_d": 0.05, "tail_side_z": 0.75, "tail_top_d": 0.64, "tail_round": 0.04,
		"flare_w": 0.09,                                             # blisters carry the width back out to 2.24
		"crown_clear": 0.13, "deck_louvres": true,                                         # wedge bonnet -> wings must hump over the front wheel
		"spoiler": true, "spoiler_style": "tail", "spoiler_h": 0.10, "spoiler_len": 0.26,
		"roof_bulge": false, "hood_bulge": false,
		"side_doors": 1,
		"antenna": false,
		# Alitalia 1977-78 reads white + green + red; the Apex palette is dirty-white + red, so the scheme
		# lands as red bands on white: bonnet fan, flank chevron, and the louvred deck between the buttresses.
		"accent_twin_stripe": true, "accent_belt_stripe": false, "accent_roundel": true,
		"accent_flank_sweep": true, "accent_rocker": true, "accent_door_panel": false,
	},
}
var SPEC: Dictionary = CARS[CAR]

func _initialize() -> void:
	_palette = Image.load_from_file(ProjectSettings.globalize_path("res://assets/palette/rallyrivals_palette.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/voxels/cars/_review/"))
	S = {
		"body": _slot(Color("e7e4da")), "shade": _slot(Color("c4c1b5")), "acc": _slot(Color("c9303e")),
		"dark": _slot(Color("18181c")), "glass": _slot(Color("5c7086")), "tire": _slot(Color("101014")),
		"chrome": _slot(Color("c6cad0")), "amber": _slot(Color("ff8c00")), "red": _slot(Color("c01818")),
	}
	if STEP == 0:                                       # 0 · proportion blueprint, no modelling
		_blueprint()
		quit()
		return
	_car()
	_render("front", Vector3(0.5, 0.3, -0.8))           # nose 3/4, near head-on — for front details/shape
	_render("side", Vector3(1.0, 0.1, 0.04))            # true side profile — for judging proportions vs spec
	_render("rear", Vector3(-0.5, 0.32, 0.8))           # tail 3/4, near head-on — for rear details/shape
	_sheet()
	_write_vox("res://assets/voxels/cars/_review/%s.vox" % CAR)   # open in MagicaVoxel to inspect
	print("%s STEP %d -> assets/voxels/cars/_review/{sheet_%s.png, %s.vox} (%d vox)" % [CAR, STEP, CAR, CAR, grid.size()])
	quit()

func _rz(m: float) -> int:
	return int(round(m / VOX))

# ============================ BUILD ============================
var c := 0   # x-centre (voxels)
func _car() -> void:
	grid = {}
	c = _rz(SPEC.body_w * 0.5) + _rz(0.14)
	_lower_body()                       # 1 · base volume (+ arches: rig-fixed, all cars)
	_fender_crowns()                    # wings hump over the wheels BEFORE the openings are cut
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
		_splitter()                     # re-apply: the nose chamfer erases the step-2 chin (bolts on UNDER it)
		_front_details()
	if STEP >= 6:                       # 6 · back (shape THEN detail)
		_tail_shape()
		if STEP >= 4 and SPEC.get("deck_louvres", false): _deck_louvres()   # re-apply onto the chopped deck
		_rear_valance()                 # re-apply: the tail chamfer erases the step-2 valance
		# ...and so does it to a TAIL LIP, which rides the deck's trailing edge — exactly the material the
		# top-rear chamfer cuts away. (The other spoiler styles sit forward or high enough to survive.)
		if STEP >= 2 and SPEC.get("spoiler", true) and _spoiler_style() == "tail": _spoiler()
		_rear_details()
	if STEP >= 7:                       # 7 · accessories
		_accessories()
	if STEP >= 8:                       # 8 · accent colouring (livery)
		_accents()
	_settle()

# Lower tub with a FLAT hood/beltline top. Front + back are kept flat & upright (small taper/drop only at
# the very ends) — a Lancia has near-vertical nose/tail, not a rounded wedge. Subtle top-outer shoulder.
func _lower_body() -> void:
	var L := _rz(SPEC.L); var floor := _rz(SPEC.floor); var belt := _rz(SPEC.belt)
	var bhw := _rz(SPEC.body_w * 0.5)
	var nt := float(bhw) * float(SPEC.nose_taper); var tt := float(bhw) * float(SPEC.tail_taper)
	var sr := _rz(SPEC.get("shoulder_r", 0.05))
	var cowlz := _rz(SPEC.cowl); var htz := _htail()
	for z in range(0, L):
		var zm := z * VOX
		var hw := bhw
		if zm < 0.18: hw = bhw - int(nt * smoothstep(0.18, 0.0, zm))
		elif zm > SPEC.L - 0.18: hw = bhw - int(tt * smoothstep(SPEC.L - 0.18, SPEC.L, zm))
		var top := _rz(_body_top_m(zm))                                     # shared profile (hood/belt/deck/tail)
		for x in range(c - hw, c + hw + 1):
			# ROUNDED TOP-OUTER SHOULDER — a true quarter-round of radius `sr` where the hood / trunk lid turns
			# down into the flank. Without it those surfaces meet the sides at a hard 90° edge head-on.
			# ...but only on the HOOD and TRUNK. Under the cabin the beltline is the body's widest point (the
			# greenhouse tumbles in from it) — rounding there would leave the cabin standing proud of the body.
			var srz := sr
			if z >= cowlz and z < htz: srz = mini(sr, _rz(0.04))
			var dxa := absi(x - c)
			var t := top
			if srz > 0 and dxa > hw - srz:
				var u := float(dxa - (hw - srz))
				t = top - int(round(float(srz) - sqrt(maxf(float(srz * srz) - u * u, 0.0))))
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
			for x in range(c - w, c + w + 1):
				grid[Vector3i(x, y, z)] = S.body

# Where the greenhouse meets the body top (rule 7 — read the body style before mapping the rear).
# HATCH: no flat deck — the backlight rakes from the roof all the way to the tail (one continuous slope).
# SEDAN/notchback: the backlight lands on the trunk at `deck_z`, leaving a FLAT deck from there to the tail
# (the deck is just _lower_body's belt-height top, so nothing extra to build).
func _htail() -> int:
	if SPEC.get("body_style", "hatch") == "sedan":
		return _rz(SPEC.get("deck_z", float(SPEC.L) - 0.6))
	return _rz(SPEC.L) - _rz(0.12)

# ---- ONE profile, shared by the voxel build AND the blueprint (they must never drift apart) ----
# Glass is PLANAR: windshield/backlight interpolate LINEARLY (a straight pane), never smoothstep — a
# smoothstep's mid-slope is 1.5x its average, which renders the greenhouse as a bubble. The roof gets a
# slight CROWN (roof_crown), and _gh() runs a short moving average that FILLETS the glass/roof corners.
const SMOOTH_R := 0.05        # fillet radius (m) at the greenhouse junctions — ~1.5 voxels: enough to break
                              # the hard corner, small enough to keep windshield/roof/backlight reading as
                              # distinct straight segments (0.11 rounded them into one continuous dome)

func _gh_raw(z: float) -> float:
	var belt: float = SPEC.belt; var roof: float = SPEC.roof; var cowl: float = SPEC.cowl
	var rf: float = SPEC.roof_front; var rr: float = SPEC.roof_rear; var ht := _ht_m()
	# Outside the cabin FOLLOW THE BODY (raked hood / trunk lid / rounded tail) — returning a flat `belt`
	# here would make _top_m's max() clamp those rakes away, flattening the hood and deck.
	if z <= cowl or z >= ht: return _body_top_m(z)
	if z < rf: return lerpf(belt, roof, (z - cowl) / maxf(rf - cowl, 0.001))
	if z > rr: return lerpf(roof, _deck_m(), (z - rr) / maxf(ht - rr, 0.001))   # backlight lands ON the deck
	return roof + float(SPEC.get("roof_crown", 0.0)) * sin(PI * (z - rf) / maxf(rr - rf, 0.001))

func _gh(z: float) -> float:                          # smoothed greenhouse top (metres)
	var acc := 0.0
	for i in range(-3, 4):
		acc += _gh_raw(z + float(i) * SMOOTH_R / 3.0)
	return acc / 7.0

# Engine-deck top (metres). A MID-ENGINED car's engine cover sits ABOVE the door beltline — a saloon's boot
# lid sits level with it — so `deck_rise` lifts the whole deck (and with it the base of the backlight).
func _deck_m() -> float:
	return float(SPEC.belt) + float(SPEC.get("deck_rise", 0.0))

# Body top (metres): raked hood · belt · raked trunk lid, plus a rounded tail ("butt") at the very end.
func _body_top_m(z: float) -> float:
	var belt: float = SPEC.belt; var cowl: float = SPEC.cowl; var L: float = SPEC.L
	var t := belt
	if z <= cowl:
		t = belt - float(SPEC.get("hood_drop", 0.0)) * (1.0 - z / maxf(cowl, 0.001))
		if z < 0.14: t -= float(SPEC.nose_drop) * smoothstep(0.14, 0.0, z)
	elif SPEC.get("body_style", "hatch") == "sedan" and z >= _ht_m():
		var ht := _ht_m()
		t = _deck_m() - float(SPEC.get("deck_drop", 0.0)) * ((z - ht) / maxf(L - ht, 0.001))
	var td: float = SPEC.get("tail_drop", 0.0)
	if td > 0.0: t -= td * smoothstep(L - 0.30, L, z)    # round the tail instead of a hard square corner
	return t

func _roof_at(z: int) -> int:
	return _rz(_gh(float(z) * VOX))

# 3 · WINDOWS — windshield / side DLO (front + rear door + triangular quarter) / backlight, glass INSET
# 1 voxel so the frame + pillars sit proud. Pillars: A moderate (body), B moderate (BLACK), C VERY THICK
# (body) — the Delta's signature. Widths/colours are per-model choices (not tier).
const INSET_DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0)]
func _glass() -> void:
	var belt := _rz(SPEC.belt); var header := _rz(SPEC.glass_top); var ht := _htail()
	var cowl := _rz(SPEC.cowl); var apz := _rz(SPEC.roof_front); var cpz := _rz(SPEC.roof_rear)
	var roofv := _rz(SPEC.roof)
	# B-pillar sits mid-cabin on a 4-door, but well BACK on a 2-door coupe (one long door ahead of it).
	var bfrac := 0.5 if int(SPEC.get("side_doors", 1)) >= 2 else 0.70
	var bpz := apz + int(round(float(cpz - apz) * bfrac))
	var bth := _rz(0.05)                                              # B-pillar half-thickness
	var pth := _rz(0.05)                                              # A/C pillar thickness
	# PASS 1 — classify every voxel against the PRISTINE grid. (Mutating the grid while iterating it makes
	# each voxel's exposure test depend on which neighbours were already erased, i.e. on dictionary order —
	# that produced venetian-blind striping across the windshield and side glass.)
	var ops := []
	for k in grid.keys():
		if grid[k] != S.body or k.z < cowl or k.z > ht: continue
		if k.y < belt + _rz(0.04) or k.y > header: continue
		var xexp := not grid.has(k + Vector3i(1, 0, 0)) or not grid.has(k + Vector3i(-1, 0, 0))
		var zc: int = k.z
		if xexp:
			# SIDE FACE = the DLO. Its front/rear limits are the A and C pillars, which are DIAGONAL — they
			# ride the glass rake, so the window is a trapezoid, not a box cut at vertical lines.
			# NB: test x-exposure ALONE. Tumblehome narrows every row, so the stepped rows are ALSO top-
			# exposed; requiring "side and not top" skipped them and striped the window like a venetian blind.
			var t := float(k.y - belt) / float(maxi(roofv - belt, 1))
			var za := cowl + int(round(float(apz - cowl) * t))        # A-pillar at this height
			var zcp := cpz + int(round(float(ht - cpz) * (1.0 - t)))  # C-pillar at this height
			if zc < za + pth or zc > zcp - pth: continue              # pillar body
			if absi(zc - bpz) <= bth: ops.append([k, S.dark, false]); continue    # B-pillar: black, proud
			ops.append([k, S.glass, true])                            # door glass, inset 1 voxel
			continue
		var oexp := not grid.has(k + Vector3i(0, 0, 1)) or not grid.has(k + Vector3i(0, 0, -1)) or not grid.has(k + Vector3i(0, 1, 0))
		if not oexp: continue                                         # interior
		if zc <= apz or zc >= cpz: ops.append([k, S.glass, false])    # windshield / backlight, FLUSH
		# else: the roof's top face -> stays body
	# PASS 2 — apply
	for op in ops:
		if op[2]: _inset(op[0], op[1])
		else: grid[op[0]] = op[1]

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
	var fx := _rz(SPEC.body_w * 0.5) - _rz(0.32)          # fender shut line, inset from the body edge
	# hood-to-fender shut lines (both sides) + the shut line across the cowl base
	for z in range(_rz(0.26), cowl):
		_paint_top(c - fx, z, S.shade); _paint_top(c + fx, z, S.shade)
	for x in range(c - fx - 1, c + fx + 2):
		_paint_top(x, cowl - 1, S.shade)
	if SPEC.get("hood_scoop", false): _hood_scoop()
	if SPEC.get("hood_louvres", false):
		# centre power-bulge shadow lines + twin NACA louvres (the Integrale's cue)
		for z in range(_rz(0.46), cowl - _rz(0.05)):
			_paint_top(c - _rz(0.17), z, S.shade); _paint_top(c + _rz(0.17), z, S.shade)
		for vz in [_rz(0.62), _rz(0.86)]:
			for x in range(c - _rz(0.13), c + _rz(0.13) + 1):
				for dz in range(0, _rz(0.12)):
					_paint_top(x, vz + dz, S.dark if dz % 2 == 0 else S.shade)
	if SPEC.get("deck_louvres", false): _deck_louvres()
	_roof_details()

# Engine-deck LOUVRES — the slatted cover over a mid-mounted engine. Transverse slats painted onto the
# ACTUAL deck surface via _paint_top, so they ride the raised deck and then follow the step-6 tail chop
# instead of sitting at some fixed height. Inset from the edges so the deck still reads as a panel with a
# border, and started past `deck_z` so the comb never runs onto the backlight glass.
# Re-applied after _tail_shape() for the same reason the valance and the tail lip are: the chop is what
# creates most of the surface these sit on.
func _deck_louvres() -> void:
	var z0 := _rz(float(SPEC.get("deck_z", float(SPEC.L) - 0.6)) + 0.06)
	var z1 := _rz(SPEC.L) - 1
	var hw := _rz(SPEC.body_w * 0.5) - _rz(0.14)
	for z in range(z0, z1 + 1):
		var slot: int = S.dark if (z - z0) % 2 == 0 else S.shade
		for x in range(c - hw, c + hw + 1):
			_paint_top(x, z, slot)

# Bonnet scoop — the Impreza's signature. A raised trapezoid on the hood centre with a DARK forward-facing
# intake mouth, narrowing slightly toward the mouth. Sits ON the raked hood (reads the surface per column).
func _hood_scoop() -> void:
	var z0 := _rz(SPEC.get("scoop_z", 0.70)); var dep := _rz(SPEC.get("scoop_len", 0.42))
	var w := _rz(0.26); var h := _rz(0.13)
	for z in range(z0, z0 + dep + 1):
		var base := _rz(_body_top_m(float(z) * VOX))
		var t := float(z - z0) / float(maxi(dep, 1))
		var ww := w - int(round(float(_rz(0.05)) * (1.0 - t)))
		for x in range(c - ww, c + ww + 1):
			for y in range(base, base + h):
				grid[Vector3i(x, y, z)] = S.body
	# intake MOUTH: carve a shallow recess into the scoop's front face and black it out, so it reads as an
	# opening rather than a painted line.
	var basef := _rz(_body_top_m(float(z0) * VOX))
	for x in range(c - w + _rz(0.06), c + w - _rz(0.06) + 1):
		for y in range(basef + 1, basef + h):
			grid.erase(Vector3i(x, y, z0))
			grid[Vector3i(x, y, z0 + 1)] = S.dark

# Roof whip ANTENNA — a thin mast standing on the roof (rally cars run one for the radio/intercom).
# Starts from the first SOLID voxel found under it, so it is always attached, whatever the roof crown does.
func _antenna() -> void:
	var az := _rz(SPEC.get("antenna_z", float(SPEC.roof_rear) - 0.12))
	var ax := c + _rz(SPEC.get("antenna_x", 0.0))
	var base := -1
	for y in range(_rz(2.4), _rz(SPEC.floor), -1):
		if grid.has(Vector3i(ax, y, az)): base = y; break
	if base < 0: return
	for k in range(1, _rz(SPEC.get("antenna_h", 0.46)) + 1):
		grid[Vector3i(ax, base + k, az)] = S.dark

# Roof drip rails — the gutter where the roof panel meets the side glass, both sides, front→rear.
func _roof_details() -> void:
	if SPEC.get("antenna", false): _antenna()
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
	# The nose is a VOLUME, not a sawn-off plane. Its face curves back toward the outer corners (plan) and
	# back as it rises (elevation), which leaves the bumper LIP as the forward-most point — so the lip
	# stands proud of the front, not just of the sides.
	var nr := _rz(SPEC.get("nose_round", 0.10))               # corners sit this far behind the centreline
	var nub := _rz(SPEC.get("nose_upback", 0.12))             # top of the nose sits this far behind the lip
	var lipTop := floor + _skirt_h()
	var noseTop := _rz(_body_top_m(0.06))
	for k in grid.keys():
		if k.z > sz: continue                                # nose zone only
		var ex := float(absi(k.x - c)) / float(maxi(bhw, 1))
		var back := int(round(float(nr) * ex * ex))          # plan: convex face, corners swept back
		if k.y > lipTop:                                     # elevation: face leans back above the lip
			var tt := clampf(float(k.y - lipTop) / float(maxi(noseTop - lipTop, 1)), 0.0, 1.0)
			back += int(round(float(nub) * tt))
		# lower-front chamfer (side view): cut z ahead of a rising ~60° plane over the bottom third
		if k.y < floor + third:
			back = maxi(back, int(round(float(vd) * (1.0 - float(k.y - floor) / float(maxi(third, 1))))))
		if k.z < back: grid.erase(k); continue
		# front-corner bevel (plan view): outer x pulled in near the tip, easing to full width by sz
		var keep_hw := bhw - int(round(float(sd) * (1.0 - float(k.z) / float(maxi(sz, 1)))))
		if absi(k.x - c) >= keep_hw: grid.erase(k)

# 5 · FRONT detail — paints the actual FRONT FACE (first solid voxel scanning back from z=0, via
# _paint_front) so nothing hides under the z=0 skin, and it follows the raked chin from _nose_shape.
# All positions are PROPORTIONAL to the body half-width and the nose-face height, so the face lands
# correctly on any car instead of being pinned to the Delta's dimensions.
func _front_details() -> void:
	var floorv := _rz(SPEC.floor)
	var hw := _rz(SPEC.body_w * 0.5)
	var noseTop := _rz(_body_top_m(0.06))                            # hood's leading edge
	var h := maxi(noseTop - floorv, 8)
	var gl := floorv + int(h * 0.52); var gh := floorv + int(h * 0.82)   # headlight / grille band
	var il := floorv + int(h * 0.14); var ih := floorv + int(h * 0.42)   # lower intake band
	var gw := int(hw * 0.32)                                         # grille half-width
	# grille — dark slatted panel across the centre
	for x in range(c - gw, c + gw + 1):
		for y in range(gl, gh):
			_paint_front(x, y, S.dark if (y - gl) % 3 != 0 else S.shade)
	# badge in the grille centre
	for x in range(c - _rz(0.05), c + _rz(0.05) + 1):
		for y in range(gl + int(h * 0.08), gh - int(h * 0.08)):
			_paint_front(x, y, S.acc)
	# wide rectangular headlights flanking the grille, out to near the fender edge
	for sgn in [-1, 1]:
		var x0: int = c + sgn * (gw + _rz(0.05)); var x1: int = c + sgn * (hw - _rz(0.09))
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			for y in range(gl + 1, gh - 1):
				_paint_front(x, y, S.chrome)
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):               # amber indicator strip under the lamp
			_paint_front(x, gl, S.amber)
	# dark lower intake across the nose + fog lights outboard + a light plate patch centred in it
	for x in range(c - int(hw * 0.80), c + int(hw * 0.80) + 1):
		for y in range(il, ih):
			_paint_front(x, y, S.dark)
	for sgn2 in [-1, 1]:
		var f0: int = c + sgn2 * int(hw * 0.50); var f1: int = c + sgn2 * int(hw * 0.68)
		for x in range(mini(f0, f1), maxi(f0, f1) + 1):
			for y in range(il + 1, ih - 1):
				_paint_front(x, y, S.chrome)
	for x in range(c - _rz(0.17), c + _rz(0.17) + 1):
		for y in range(il + 1, ih - 1):
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
	var hh := int((belt - floor) * float(SPEC.get("tail_cut_h", 0.42)))   # how far up the lower-rear cut reaches
	# The top-rear chamfer hangs off the ACTUAL surface at the tail, not the beltline — a raised engine deck
	# (deck_rise) puts the top well above `belt`, and measuring from belt would rake the wrong band.
	var topv := _rz(_body_top_m(float(SPEC.L) - 0.06))
	var th := int((topv - floor) * 0.30)                          # top-rear chamfer height
	var vd := _rz(SPEC.tail_point_d)                             # deeper lower-rear chamfer
	var td := _rz(SPEC.tail_top_d)                              # top-rear edge chamfer depth
	var sd := _rz(SPEC.tail_side_d); var sz := _rz(SPEC.tail_side_z)
	# Like the nose, the tail is a VOLUME: its face curves back toward the outer corners so it doesn't read
	# as a flat sawn-off panel, and the valance lip below keeps the rear-most z band.
	var tr := _rz(SPEC.get("tail_round", 0.09))
	for k in grid.keys():
		var zr: int = (L - 1) - k.z                              # distance forward from the rear face
		if zr > sz: continue                                    # tail zone only
		var ex := float(absi(k.x - c)) / float(maxi(bhw, 1))
		var back := int(round(float(tr) * ex * ex))              # plan: convex tail, corners swept in
		# lower-rear chamfer (side view): tuck z behind a rising cut over the bottom ~40%
		if k.y < floor + hh:
			back = maxi(back, int(round(float(vd) * (1.0 - float(k.y - floor) / float(maxi(hh, 1))))))
		# top-rear chamfer (side view): bevel the top edge, deepest at the deck, easing down
		if k.y > topv - th:
			back = maxi(back, int(round(float(td) * (1.0 - float(topv - k.y) / float(maxi(th, 1))))))
		if zr < back: grid.erase(k); continue
		# rear-corner bevel (plan view): outer x pulled in near the tail, easing to full width by sz
		var keep_hw := bhw - int(round(float(sd) * (1.0 - float(zr) / float(maxi(sz, 1)))))
		if absi(k.x - c) >= keep_hw: grid.erase(k)

# 6 · REAR detail — paints the visible REAR face (first solid scanning forward from z=L-1, via _paint_rear)
# so it follows the tucked tail. Tail lamps, bumper, reflectors, plate, badge. (No spoiler: this model kit-off.)
# Positions are PROPORTIONAL to the body half-width and the tail-face height (as on the front), so they
# land correctly on any car rather than being pinned to the Delta's metres.
func _rear_details() -> void:
	var floorv := _rz(SPEC.floor)
	var hw := _rz(SPEC.body_w * 0.5)
	var tailTop := _rz(_body_top_m(float(SPEC.L) - 0.06))
	var h := maxi(tailTop - floorv, 8)
	var ll := floorv + int(h * 0.50); var lh := floorv + int(h * 0.76)   # lamp band
	var bl := floorv + int(h * 0.16); var bh := floorv + int(h * 0.42)   # bumper band
	# tail lamp cluster: red, out to the corners, with a body-coloured break at the centre
	for sgn in [-1, 1]:
		var x0: int = c + sgn * int(hw * 0.24); var x1: int = c + sgn * (hw - _rz(0.07))
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			for y in range(ll, lh):
				_paint_rear(x, y, S.red)
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):                  # amber indicator in the cluster
			_paint_rear(x, ll, S.amber)
	# dark rear bumper band + a light plate patch centred in it
	for x in range(c - int(hw * 0.82), c + int(hw * 0.82) + 1):
		for y in range(bl, bh):
			_paint_rear(x, y, S.dark)
	for x in range(c - _rz(0.17), c + _rz(0.17) + 1):
		for y in range(bl + 1, bh - 1):
			_paint_rear(x, y, S.chrome)                                  # licence plate
	# badge high on the tailgate, above the lamps
	for x in range(c - _rz(0.05), c + _rz(0.05) + 1):
		for y in range(lh + int(h * 0.05), lh + int(h * 0.15)):
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
	var belt := _rz(SPEC.belt)
	# MIRRORS — anchored to the ACTUAL body surface at that height (via _outer_x), mounted just under the
	# beltline at the A-pillar foot. Anchoring to body_w/2 above the belt left them floating in space:
	# the greenhouse has already tumbled inboard up there, so there was nothing to attach to.
	var mz := _rz(SPEC.cowl) + _rz(0.12)
	var my := belt - _rz(0.03)
	for side in [-1, 1]:
		var s: int = side
		var xe := _outer_x(my, mz, s)
		for k in range(1, 3):                                   # stalk bridging body -> housing
			grid[Vector3i(xe + s * k, my, mz)] = S.body
		var z0 := mz - _rz(0.02); var z1 := mz + _rz(0.08)
		for z in range(z0, z1 + 1):                             # housing block, protruding outboard
			for y in range(my, my + _rz(0.10)):
				for k in range(2, 5):
					grid[Vector3i(xe + s * k, y, z)] = S.body
		# The mirror GLASS faces BACKWARD (toward the driver) — it is the housing's REAR face, not its
		# outboard face. An outward-facing mirror would be reflecting the scenery, not the road behind.
		for y in range(my, my + _rz(0.10)):
			for k in range(2, 5):
				grid[Vector3i(xe + s * k, y, z1)] = S.dark
	# DOOR HANDLES — one per door, set just ahead of each door's trailing shut line.
	var bpz := (_rz(SPEC.roof_front) + _rz(SPEC.roof_rear)) / 2
	var cfront := _rz(SPEC.roof_rear) + (_htail() - _rz(SPEC.roof_rear)) / 3
	var hzs := [bpz - _rz(0.36)]
	if int(SPEC.get("side_doors", 1)) >= 2: hzs.append(cfront - _rz(0.36))
	for hz in hzs:
		for side in [-1, 1]:
			for z in range(hz, hz + _rz(0.16)):
				_paint_side(belt - _rz(0.10), z, side, S.chrome)

# Outermost solid x at (y, z) on a side — the real skin, whatever the tumblehome/flares put there.
func _outer_x(y: int, z: int, side: int) -> int:
	var s: int = side
	for x in range(c + s * _rz(1.3), c, -s):
		if grid.has(Vector3i(x, y, z)): return x
	return c

# 8 · ACCENT COLOURING — the livery pass. Pure COLOUR (never geometry), painted on the visible faces via
# _paint_top / _paint_side so it rides bulges and the tumblehome instead of floating. Per-model SPEC toggles:
# twin longitudinal rally stripes · beltline pinstripe · door roundel (race-number disc) · rocker flash.
func _accents() -> void:
	var hw := _rz(0.055)                                             # stripe half-width
	if SPEC.get("accent_twin_stripe", false):                        # twin stripes: hood -> roof -> hatch
		for off in [-_rz(0.20), _rz(0.20)]:
			for z in range(_rz(0.26), _htail()):
				for dx in range(-hw, hw + 1):
					_acc_top(c + off + dx, z, S.acc)
	if SPEC.get("accent_belt_stripe", false):                        # pinstripe along both flanks at the belt
		var by := _rz(SPEC.belt) - _rz(0.06)
		for z in range(_rz(SPEC.cowl), _htail() - _rz(0.12)):
			for side in [-1, 1]:
				_acc_side(by, z, side, S.acc)
	if SPEC.get("accent_roundel", false):                            # race-number disc on both doors
		var rz := (_rz(SPEC.cowl) + _htail()) / 2
		var ry := _rz(SPEC.belt) - _rz(0.30)
		var r := _rz(0.22)
		for z in range(rz - r, rz + r + 1):
			for y in range(ry - r, ry + r + 1):
				var d := Vector2(z - rz, y - ry).length()
				if d > float(r): continue
				var slot: int = S.acc if d > float(r) - 2.0 else S.chrome   # accent ring, light centre
				for side in [-1, 1]:
					_acc_side(y, z, side, slot)
	if SPEC.get("accent_rocker", false):                             # accent flash along the rocker
		var ry2 := _rz(SPEC.floor) + _rz(0.2)
		for z in range(_rz(SPEC.wz_f) + _rz(0.4), _rz(SPEC.wz_r) - _rz(0.4)):
			for side in [-1, 1]:
				_acc_side(ry2, z, side, S.acc)
	# --- 555-style rally livery ---
	# Bold flank band that runs low at the nose and SWEEPS UP over the rear arch (the works-Subaru cue).
	if SPEC.get("accent_flank_sweep", false):
		var z0 := _rz(0.34); var z1 := _rz(SPEC.L) - _rz(0.28)
		for z in range(z0, z1):
			var t := float(z - z0) / float(maxi(z1 - z0, 1))
			var yb := _rz(SPEC.floor) + _rz(0.26) + int(round(float(_rz(0.40)) * t * t))
			for dy in range(0, _rz(0.14)):
				for side in [-1, 1]:
					_acc_side(yb + dy, z, side, S.acc)
	# Big competition NUMBER PANEL on the doors: a light square with a bold accent bar across it.
	if SPEC.get("accent_door_panel", false):
		# Sits ABOVE the flank sweep, and is DARK with a light number bar — a light panel would vanish
		# against the dirty-white body, and a red one would merge into the sweep.
		var pz := (_rz(SPEC.cowl) + _htail()) / 2 - _rz(0.24)
		var py := _rz(SPEC.belt) - _rz(0.38)
		for z in range(pz, pz + _rz(0.50)):
			for y in range(py, py + _rz(0.30)):
				for side in [-1, 1]:
					_acc_side(y, z, side, S.dark)
		for z in range(pz + _rz(0.10), pz + _rz(0.40)):
			for y in range(py + _rz(0.10), py + _rz(0.20)):
				for side in [-1, 1]:
					_acc_side(y, z, side, S.body, true)
	# Accent the wing blade so the tail reads from behind.
	if SPEC.get("accent_wing", false):
		var wz := _rz(float(SPEC.deck_z) + 0.22)
		for z in range(wz - _rz(0.09), wz + _rz(0.09) + 1):
			for x in range(c - _rz(0.80), c + _rz(0.80) + 1):
				_acc_top(x, z, S.acc)

# Accent painters — recolour the visible face ONLY where it's painted body skin, so livery never runs
# across glass, black pillars or chrome (a stripe over the backlight is the tell-tale of a naive pass).
func _acc_top(x: int, z: int, slot: int) -> void:
	for y in range(_rz(1.7), _rz(SPEC.floor) - 1, -1):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			if grid[k] == S.body or grid[k] == S.shade: grid[k] = slot
			return

func _acc_side(y: int, z: int, side: int, slot: int, over_trim := false) -> void:
	var s: int = side
	for x in range(c + s * _rz(1.3), c, -s):
		var k := Vector3i(x, y, z)
		if grid.has(k):
			var g: int = grid[k]
			if g == S.body or g == S.shade or (over_trim and (g == S.chrome or g == S.dark)): grid[k] = slot
			return

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
# WING CROWNS. The arch opening is RIG-fixed (top at cy + r + clr ≈ 0.89 m on every car), so on a car with
# a hard-raked bonnet the body top can fall to within a voxel of it — the fender over the wheel comes out one
# voxel thick, which reads as a hole and snaps off. A real front wing humps ABOVE the bonnet centreline over
# the wheel (Stratos, Delta and Quattro all do it), so raise the OUTER band over each arch to clear the
# opening by `crown_clear`, easing back to the natural body top toward the centreline and along z. Default 0
# -> cars that already have deep fenders are untouched.
func _fender_crowns() -> void:
	var clear := _rz(SPEC.get("crown_clear", 0.0))
	if clear <= 0: return
	var hw := _rz(SPEC.body_w * 0.5); var floorv := _rz(SPEC.floor)
	var arch_top := _rz(RIG_WHEEL_R) * 2 + 3                     # must match _arches(): cy + r + clr
	var span := _rz(0.55); var band := _rz(0.42)
	for wz in [_rz(SPEC.wz_f), _rz(SPEC.wz_r)]:
		for z in range(wz - span, wz + span + 1):
			var nat := _rz(_body_top_m(float(z) * VOX))
			var want := arch_top + clear
			if want <= nat: continue                             # this end already has fender depth to spare
			# PLATEAU, not a bell: flat over the wheel and across the outer band, falling off only at the
			# edges. Blending two smoothsteps across a 2-3 voxel lift quantises into speckle — a lumpy blob
			# rather than a wing. Keep the crown flat wherever it is at full height.
			var fz := 1.0 - smoothstep(0.45, 1.0, float(absi(z - wz)) / float(maxi(span, 1)))
			for x in range(c - hw, c + hw + 1):
				var dxa := absi(x - c)
				if dxa < hw - band: continue
				var fx := clampf(float(dxa - (hw - band)) / float(maxi(_rz(0.16), 1)), 0.0, 1.0)
				var t := int(round(float(want - nat) * fz * fx))
				if t <= 0: continue
				# Grow from the column's ACTUAL top so the rounded shoulder survives underneath the hump.
				var ytop := -1
				for y in range(want + 2, floorv - 1, -1):
					if grid.has(Vector3i(x, y, z)): ytop = y; break
				if ytop < 0: continue
				for y in range(ytop + 1, nat + t + 1):
					grid[Vector3i(x, y, z)] = S.body

func _arches() -> void:
	var r := _rz(RIG_WHEEL_R); var cy := _rz(RIG_WHEEL_R); var hw := _rz(SPEC.body_w * 0.5); var clr := 3
	for wz in [_rz(SPEC.wz_f), _rz(SPEC.wz_r)]:
		for x in range(c - hw - _rz(0.09), c + hw + _rz(0.09) + 1):    # wide enough to cut through the flares too
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
	_rear_valance()
	_skirts()
	if SPEC.get("hood_bulge", true): _hood_bulge()
	if SPEC.get("roof_bulge", false): _roof_bulge()

# Outermost BODY column on a side. Every centre-symmetric fill spans an INCLUSIVE range(c-X, c+X+1) so the
# car's symmetry axis is exactly column `c` — upper-exclusive ranges put it at c-0.5, which silently made the
# right side one column short and floated the flares/skirts/mirrors off the body as disconnected shells.
func _edge(side: int, hw: int) -> int:
	return c + side * hw

# Fender flares — an arch-following eyebrow lip protruding outboard (the Evo widebody), NOT a corner box.
# Fills a disc around each opening; _arches then re-carves the wheel hole, leaving the flare as a lip.
func _flares() -> void:
	var hw := _rz(SPEC.body_w * 0.5); var fw := _rz(SPEC.get("flare_w", 0.05)); var r := _rz(RIG_WHEEL_R); var cy := _rz(RIG_WHEEL_R)
	var floor := _rz(SPEC.floor)
	for wz in [_rz(SPEC.wz_f), _rz(SPEC.wz_r)]:
		for side in [-1, 1]:
			var s: int = side; var xe: int = _edge(s, hw)
			for k in range(1, fw + 1):
				for z in range(wz - r - _rz(0.13), wz + r + _rz(0.13)):
					for y in range(floor, cy + r + _rz(0.13)):
						var dy := float(y) + 0.5 - float(cy); var dz := float(z) + 0.5 - float(wz)
						if sqrt(dy * dy + dz * dz) <= float(r) + float(_rz(0.14)):
							# A flare is an eyebrow BOLTED TO the body, so only grow it where there is material
							# directly inboard. Stamping the whole disc blind leaves floating shells wherever
							# the body top falls below the disc's reach — over a raked bonnet, or under the
							# rounded shoulder — which is 12 orphan clusters at the Verdict's front arch.
							if not grid.has(Vector3i(xe + s * (k - 1), y, z)): continue
							grid[Vector3i(xe + s * k, y, z)] = S.body

# Rear wing — `spoiler_style` picks the shape, INDEPENDENT of body style (a mid-engined notchback wants a
# tail lip, not a saloon's deck wing, so the body style may only supply the DEFAULT):
#   "deck"  unibody deck wing on a notchback trunk (the 555 Impreza)   · sedan default
#   "arch"  blade across the roof rear / tailgate top (hot hatch)      · hatch default
#   "stand" blade raised on two stands at the tail (classic rally wing)
#   "tail"  full-width lip riding the tailgate's trailing edge (Group 4 Kamm-tail lip)
func _spoiler_style() -> String:
	return SPEC.get("spoiler_style", "deck" if SPEC.get("body_style", "hatch") == "sedan" else "arch")

func _spoiler() -> void:
	var style := _spoiler_style()
	if style == "deck":
		var zc := _rz(float(SPEC.deck_z) + 0.22)
		var deck_y := _rz(_body_top_m(float(zc) * VOX))
		# UNIBODY deck wing (the Impreza's signature): ONE piece — a blade spanning the deck with a DEEP arch
		# cut out underneath, leaving thick end supports. Not a flat blade perched on two thin stanchions.
		var h := _rz(0.36)                                   # total height above the deck (tall 555-style wing)
		var bw := _rz(SPEC.body_w * 0.5) - _rz(0.13)         # half-span of the wing
		var th := _rz(0.07)                                  # blade thickness on top
		var aw := bw - _rz(0.17)                             # arch half-width (thick legs sit outboard of it)
		var ah := h - th                                     # arch height
		for x in range(c - bw, c + bw + 1):
			for y in range(deck_y, deck_y + h + 1):
				var dx := float(x - c) / float(maxi(aw, 1))
				var dy := float(y - deck_y) / float(maxi(ah, 1))
				if dx * dx + dy * dy < 1.0: continue         # the deep arch opening
				var blade := y >= deck_y + ah                # blade runs deeper front-to-back than the legs
				var zt := _rz(0.09) if blade else _rz(0.035)
				for z in range(zc - zt, zc + zt + 1):
					grid[Vector3i(x, y, z)] = S.body
		return
	if style == "stand":
		# Blade RAISED ON TWO STANDS at the tail (classic rally wing) — clear air under the blade.
		var wz := _rz(SPEC.L) - _rz(0.17)
		var wbase := _rz(_top_m(float(wz) * VOX))
		var wh := _rz(SPEC.get("spoiler_h", 0.20))
		var wbw := _rz(SPEC.body_w * 0.5) - _rz(0.12)
		for sx in [-_rz(0.42), _rz(0.42)]:                        # stands
			for y in range(wbase, wbase + wh):
				for z in range(wz - _rz(0.03), wz + _rz(0.04) + 1):
					grid[Vector3i(c + sx, y, z)] = S.dark
		for x in range(c - wbw, c + wbw + 1):                     # blade
			for z in range(wz - _rz(0.11), wz + _rz(0.11) + 1):
				for y in range(wbase + wh, wbase + wh + _rz(0.07)):
					grid[Vector3i(x, y, z)] = S.body
		return
	if style == "tail":
		# Full-width LIP riding the tailgate's trailing edge — the back of the car. Height is `spoiler_h`
		# (a lip, not a wing), and it wraps the rear corners in plan by following the body's own half-width.
		var tz0 := _rz(SPEC.L) - _rz(SPEC.get("spoiler_len", 0.24)); var tz1 := _rz(SPEC.L) - 1
		var lip := _rz(SPEC.get("spoiler_h", 0.10)); var floorv := _rz(SPEC.floor)
		for z in range(tz0, tz1 + 1):
			var thw := _rz(_hw_m(float(z) * VOX)) - _rz(0.03)
			var ceil_y := _rz(_top_m(float(z) * VOX))
			for x in range(c - thw, c + thw + 1):
				# Ride the ACTUAL deck, not the uncarved profile: a deep top-rear chamfer (tail_top_d) drops
				# the real surface well below _top_m, and a lip pinned to _top_m would float over the chop.
				var ty := -1
				for y in range(ceil_y, floorv - 1, -1):
					if grid.has(Vector3i(x, y, z)): ty = y; break
				if ty < 0: continue                                   # chopped away here — no lip to hang
				for y in range(ty + 1, ty + 1 + lip):
					grid[Vector3i(x, y, z)] = S.body
		return
	var rr := _rz(SPEC.roof_rear); var rw := _rz(SPEC.roof_w * 0.5); var ry := _rz(SPEC.roof)
	for x in range(c - rw, c + rw + 1):
		for z in range(rr - _rz(0.02), rr + _rz(0.14)):
			grid[Vector3i(x, ry, z)] = S.body
			grid[Vector3i(x, ry + 1, z)] = S.body

# ---- BEEFY PERIMETER SKIRT: front valance · side sills · rear valance. A chunky band of ADDED volume that
# protrudes outboard/forward/back around the whole lower body, so it reads as a bolted-on kit rather than a
# painted line. Height/protrusion are per-model (`skirt_h`, `skirt_out`). The front + rear pieces are
# re-applied after the step-5/6 nose and tail chamfers, which would otherwise carve them away.
func _skirt_h() -> int: return _rz(SPEC.get("skirt_h", 0.15))
func _skirt_out() -> int: return _rz(SPEC.get("skirt_out", 0.05))

# Front valance / splitter across the nose, wrapping the corners.
func _splitter() -> void:
	var floorv := _rz(SPEC.floor); var h := _skirt_h()
	var hw := _rz(SPEC.body_w * 0.5)
	var dep := _skirt_out() + _rz(0.03)
	# Grow FORWARD from the bodywork that is actually there, per column — the mirror of _rear_valance().
	# Stamping the lip into a fixed z=0..dep band only works while the lower nose still reaches z=0; a deep
	# chin chamfer (nose_point_d) sweeps it back several voxels and leaves the lip hanging in the void the
	# chamfer just carved (865 orphaned voxels on the Verdict). Growing forward also makes the air dam
	# follow the chin rake, which is what a real one does.
	for y in range(floorv, floorv + h):
		for x in range(c - hw, c + hw + 1):
			var zf := -1
			for z in range(0, _rz(0.9)):
				if grid.has(Vector3i(x, y, z)): zf = z; break
			if zf <= 0: continue                    # no body here, or it already owns the forward-most band
			for z in range(maxi(zf - dep, 0), zf):
				grid[Vector3i(x, y, z)] = S.body

# Rear valance / diffuser across the tail, wrapping the corners.
func _rear_valance() -> void:
	var floorv := _rz(SPEC.floor); var h := _skirt_h()
	var hw := _rz(SPEC.body_w * 0.5); var L := _rz(SPEC.L)
	var dep := _skirt_out() + _rz(0.03)
	# Grow BACKWARD from the bodywork that is actually there, and only where the body already reaches
	# near the tail. A deep lower-rear chop removes that material, and blindly stamping the valance at the
	# tail face left it floating in the void the chop had just carved (1332 orphaned voxels).
	for y in range(floorv, floorv + h):
		for x in range(c - hw, c + hw + 1):
			var zs := -1
			for z in range(L - 1, maxi(L - 1 - _rz(0.7), 0), -1):
				if grid.has(Vector3i(x, y, z)): zs = z; break
			if zs < 0 or zs < L - 1 - dep: continue      # chopped away here -> leave the undercut alone
			for z in range(zs + 1, L):
				grid[Vector3i(x, y, z)] = S.body

# Side sills — a thick skirt protruding outboard between the arches, tapering in at both ends.
func _skirts() -> void:
	var hw := _rz(SPEC.body_w * 0.5); var floorv := _rz(SPEC.floor)
	var h := _skirt_h(); var out := _skirt_out()
	var z0 := _rz(SPEC.wz_f) + _rz(0.40); var z1 := _rz(SPEC.wz_r) - _rz(0.40)
	for z in range(z0, z1 + 1):
		var taper := mini(mini(z - z0, z1 - z), _rz(0.20))
		var o := out if taper >= _rz(0.20) else int(round(float(out) * float(taper) / float(maxi(_rz(0.20), 1))))
		for side in [-1, 1]:
			var s: int = side
			var xe: int = _edge(s, hw)
			for k in range(0, o + 1):
				for y in range(floorv, floorv + h - k):     # top edge tucks in -> a rocker, not a slab
					grid[Vector3i(xe + s * k, y, z)] = S.body

# Bonnet power bulge — a SMOOTH dome: the raise tapers to zero toward the edges (x and z), so it blends
# into the hood instead of sitting as a hard raised block.
func _hood_bulge() -> void:
	var belt := _rz(SPEC.belt)
	var z0 := _rz(0.42); var z1 := _rz(SPEC.cowl) - _rz(0.08); var zc := (z0 + z1) / 2
	var xw := _rz(0.3); var maxh := _rz(0.055)
	for z in range(z0, z1):
		var fz := 1.0 - smoothstep(0.55, 1.0, float(absi(z - zc)) / float(maxi((z1 - z0) / 2, 1)))
		var base := _rz(_body_top_m(float(z) * VOX))     # sit ON the raked hood, not at the (higher) beltline
		for x in range(c - xw, c + xw + 1):
			var fx := 1.0 - smoothstep(0.5, 1.0, float(absi(x - c)) / float(maxi(xw, 1)))
			var h := int(round(float(maxh) * fx * fz))
			for y in range(base, base + h):
				grid[Vector3i(x, y, z)] = S.body

# Subtle roof bulge (requested) — raise the roof centre.
func _roof_bulge() -> void:
	var roof := _rz(SPEC.roof)
	for z in range(_rz(SPEC.roof_front) + _rz(0.15), _rz(SPEC.roof_rear) - _rz(0.1)):
		for x in range(c - _rz(0.22), c + _rz(0.22) + 1):
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
const CW := 620
const CH := 300
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
		var exposed := false
		for o in N6:
			if not grid.has(key + o): nrm += Vector3(o); exposed = true
		if not exposed: continue                      # truly interior -> skip
		# A 1-voxel-thick feature (antenna, thin trim) has opposing exposed faces that CANCEL to zero.
		# Testing `nrm == ZERO` alone treated those as interior and deleted them from the preview.
		if nrm == Vector3.ZERO: nrm = Vector3.UP
		var p := Vector3(key)
		var s := Vector2(p.dot(right), p.dot(up))
		shell.append([s, p.dot(d), nrm.normalized(), grid[key]])
		mn = mn.min(s); mx = mx.max(s)
	var span := mx - mn
	var scale := minf((CW - 20) / maxf(span.x, 1.0), (CH - 20) / maxf(span.y, 1.0))
	var ox := (CW - span.x * scale) * 0.5; var oy := (CH - span.y * scale) * 0.5
	var blk := maxi(int(ceil(scale)), 1)
	var img := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.34, 0.37, 0.42))
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
	img.fill(Color(0.28, 0.31, 0.35))
	var i := 0
	for nm in ["front", "side", "rear"]:
		if _cells.has(nm): img.blit_rect(_cells[nm], Rect2i(0, 0, CW, CH), Vector2i(0, i * CH))
		i += 1
	img.save_png(ProjectSettings.globalize_path("res://assets/voxels/cars/_review/sheet_%s.png" % CAR))

# ============================ 0 · BLUEPRINT ============================
# The three orthographic views (side / top-down / rear) drawn straight from SPEC using the SAME profile
# maths the modelling steps use (_top_m mirrors _roof_at, _hw_m mirrors the tapers, wheels/arches rig-fixed).
# No voxels: at this stage proportions are just numbers, so a fix is one SPEC value instead of a re-model.
# Validate here FIRST, then bump STEP to 1. Colours: body silhouette, glass = the DLO band, dark = wheels.
const PPM := 200                 # blueprint pixels per metre
const BPAD := 30
const RIG_WHEEL_VIS := 0.44      # wheel MODEL radius (car.tscn wheel_radius); arches stay rig-fixed at RIG_WHEEL_R

func _ht_m() -> float:                                # greenhouse/body-top meeting point in metres (see _htail)
	if SPEC.get("body_style", "hatch") == "sedan": return float(SPEC.get("deck_z", float(SPEC.L) - 0.6))
	return float(SPEC.L) - 0.12

# True if (z, y) in metres would be CARVED AWAY by the step-5/6 nose & tail shaping, so the blueprint shows
# the FINAL silhouette rather than just the base volume (the chamfers are shape, and shape is what step 0 is for).
func _carved_m(z: float, y: float) -> bool:
	var floorm: float = SPEC.floor; var belt: float = SPEC.belt; var L: float = SPEC.L
	if z <= float(SPEC.get("nose_side_z", 0.30)):
		var third := (belt - floorm) / 3.0
		if y < floorm + third:
			if z < float(SPEC.get("nose_point_d", 0.0)) * (1.0 - (y - floorm) / maxf(third, 0.001)): return true
	var zr := L - z
	if zr <= float(SPEC.get("tail_side_z", 0.30)):
		var hh := (belt - floorm) * float(SPEC.get("tail_cut_h", 0.42))
		var topm := _body_top_m(L - 0.06)                 # real surface at the tail (see _tail_shape)
		var th := (topm - floorm) * 0.30
		if y < floorm + hh:
			if zr < float(SPEC.get("tail_point_d", 0.0)) * (1.0 - (y - floorm) / maxf(hh, 0.001)): return true
		elif y > topm - th:
			if zr < float(SPEC.get("tail_top_d", 0.0)) * (1.0 - (topm - y) / maxf(th, 0.001)): return true
	return false

func _top_m(z: float) -> float:                       # silhouette top at z (metres) — mirrors _roof_at
	return maxf(_body_top_m(z), _gh(z))               # body (hood/belt/deck/tail) vs greenhouse — same maths

func _hw_m(z: float) -> float:                        # body half-width at z (metres) — mirrors the tapers
	var bhw: float = float(SPEC.body_w) * 0.5
	if z < 0.18: return bhw - bhw * float(SPEC.nose_taper) * smoothstep(0.18, 0.0, z)
	if z > float(SPEC.L) - 0.18: return bhw - bhw * float(SPEC.tail_taper) * smoothstep(float(SPEC.L) - 0.18, float(SPEC.L), z)
	return bhw

const BG := Color(0.07, 0.08, 0.11)
const GRID := Color(0.13, 0.15, 0.19)
const RULE := Color(0.36, 0.42, 0.54)
const DIMC := Color(0.55, 0.62, 0.76)

func _blueprint() -> void:
	var L: float = SPEC.L; var bw: float = SPEC.body_w; var roof: float = SPEC.roof
	var body := _palette.get_pixel(S.body, 0)
	var shade := _palette.get_pixel(S.shade, 0)
	var glass := _palette.get_pixel(S.glass, 0)
	var tyre := _palette.get_pixel(S.tire, 0)
	var side_h := roof + 0.30; var top_h := bw + 0.30; var rear_h := roof + 0.30
	var cw := int(maxf(L, bw) * PPM) + BPAD * 2
	var ch := int((side_h + top_h + rear_h) * PPM) + BPAD * 4
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var y0 := BPAD + int(side_h * PPM)                                   # side: ground line
	var y1 := y0 + BPAD + int(top_h * PPM * 0.5)                         # top: centreline
	var y2 := y1 + int(top_h * PPM * 0.5) + BPAD + int(rear_h * PPM)     # rear: ground line
	_bp_grid(img, y0, y1, y2, L, bw, side_h, top_h, rear_h)

	# ---- SIDE (z x height): silhouette + DLO band, arches carved, wheels, dimension ticks ----
	# REFERENCE TRACE: if assets/refs/<car>_side.png exists (a true side view CROPPED to the car's bounding
	# box — bumper to bumper, roof to ground contact) it is scaled to L x roof and drawn UNDER the profile,
	# which then renders as an outline + landmark lines. Proportion errors become obvious instead of guessed.
	var belt: float = SPEC.belt; var floorm: float = SPEC.floor; var gtop: float = SPEC.glass_top
	var cowl: float = SPEC.cowl; var ht := _ht_m()
	var refp := "res://assets/refs/%s_side.png" % CAR
	var ref: Image = null
	if FileAccess.file_exists(ProjectSettings.globalize_path(refp)):
		ref = Image.load_from_file(ProjectSettings.globalize_path(refp))
		if ref != null:
			if ref.get_format() != Image.FORMAT_RGBA8: ref.convert(Image.FORMAT_RGBA8)
			ref.resize(int(L * PPM), int(roof * PPM), Image.INTERPOLATE_BILINEAR)
			img.blit_rect(ref, Rect2i(0, 0, ref.get_width(), ref.get_height()), Vector2i(BPAD, y0 - int(roof * PPM)))
			print("  TRACING over %s" % refp)
	if ref != null:                                                    # traced: outline + landmarks only
		for px in range(0, int(L * PPM)):
			var zt := float(px) / PPM
			var tt := int(_top_m(zt) * PPM)
			for t in 3: _bp_set(img, BPAD + px, y0 - tt - t, Color(0.30, 1.0, 0.72))
		for hm2 in [floorm, belt, gtop]:
			_bp_hline(img, BPAD, BPAD + int(L * PPM), y0 - int(hm2 * PPM), Color(1.0, 0.55, 0.25))
		for zl in [cowl, float(SPEC.roof_front), float(SPEC.roof_rear), ht]:
			_bp_vline(img, BPAD + int(zl * PPM), y0 - int(_top_m(zl) * PPM), y0 - int(belt * PPM), Color(1.0, 0.85, 0.2))
	else:
		for px in range(0, int(L * PPM)):
			var z := float(px) / PPM
			var top := _top_m(z)
			for py in range(int(floorm * PPM), int(top * PPM)):
				var ym := float(py) / PPM
				if _carved_m(z, ym): continue                  # nose / tail chamfers (steps 5-6)
				var col := body
				if ym > belt + 0.02 and ym < gtop and z > cowl and z < ht and top > belt + 0.04: col = glass
				elif ym < floorm + 0.06: col = shade
				_bp_set(img, BPAD + px, y0 - py, col)
	for wz in [float(SPEC.wz_f), float(SPEC.wz_r)]:                       # arch openings (rig-fixed) + wheels
		_bp_disc(img, BPAD + int(wz * PPM), y0 - int(RIG_WHEEL_R * PPM), int((RIG_WHEEL_R + 0.099) * PPM), BG)
		_bp_disc(img, BPAD + int(wz * PPM), y0 - int(RIG_WHEEL_VIS * PPM), int(RIG_WHEEL_VIS * PPM), tyre)
		_bp_disc(img, BPAD + int(wz * PPM), y0 - int(RIG_WHEEL_VIS * PPM), int(0.17 * PPM), RULE)
	_bp_hline(img, BPAD - 12, BPAD + int(L * PPM) + 12, y0, RULE)         # ground
	for z in [0.0, float(SPEC.wz_f), float(SPEC.wz_r), L]:                # wheelbase / overhang ticks
		_bp_vline(img, BPAD + int(z * PPM), y0 + 4, y0 + 16, DIMC)
	_bp_hline(img, BPAD, BPAD + int(L * PPM), y0 + 11, DIMC)
	for hm in [floorm, belt, roof]:                                       # height ticks
		_bp_hline(img, BPAD - 16, BPAD - 4, y0 - int(hm * PPM), DIMC)

	# ---- TOP-DOWN (z x width): body plan + greenhouse belt plan + roof plan outline + wheels ----
	for px in range(0, int(L * PPM)):
		var z2 := float(px) / PPM
		var hw := _hw_m(z2)
		var gh := 0.0
		if z2 > cowl and z2 < ht: gh = float(SPEC.green_belt_w) * 0.5
		for py in range(-int(hw * PPM), int(hw * PPM)):
			var xm := absf(float(py) / PPM)
			_bp_set(img, BPAD + px, y1 + py, glass if (gh > 0.0 and xm < gh) else body)
	for z3 in [float(SPEC.roof_front), float(SPEC.roof_rear)]:            # roof plan outline
		_bp_vline(img, BPAD + int(z3 * PPM), y1 - int(float(SPEC.roof_w) * 0.5 * PPM), y1 + int(float(SPEC.roof_w) * 0.5 * PPM), RULE)
	for sgn in [-1, 1]:
		_bp_hline(img, BPAD + int(float(SPEC.roof_front) * PPM), BPAD + int(float(SPEC.roof_rear) * PPM), y1 + sgn * int(float(SPEC.roof_w) * 0.5 * PPM), RULE)
	for wz2 in [float(SPEC.wz_f), float(SPEC.wz_r)]:                      # wheels (track ±0.85)
		for sgn2 in [-1, 1]:
			_bp_rect(img, BPAD + int((wz2 - RIG_WHEEL_VIS) * PPM), BPAD + int((wz2 + RIG_WHEEL_VIS) * PPM),
				y1 + sgn2 * int((RIG_TRACK * 0.5 - 0.11) * PPM), y1 + sgn2 * int((RIG_TRACK * 0.5 + 0.11) * PPM), tyre)

	# ---- REAR (width x height): body + tumblehome greenhouse + wheels ----
	var bhw: float = bw * 0.5; var rhw: float = float(SPEC.roof_w) * 0.5; var ghw: float = float(SPEC.green_belt_w) * 0.5
	var cx := BPAD + int(maxf(L, bw) * PPM * 0.5)
	for py in range(int(floorm * PPM), int(roof * PPM)):
		var ym2 := float(py) / PPM
		var half := bhw
		var col2 := body
		if ym2 > belt:
			half = lerpf(ghw, rhw, (ym2 - belt) / maxf(roof - belt, 0.001))
			if ym2 < gtop: col2 = glass
		else:
			var srm: float = SPEC.get("shoulder_r", 0.05)          # rounded top-outer shoulder
			var dyy := ym2 - (belt - srm)
			if srm > 0.0 and dyy > 0.0: half = (bhw - srm) + sqrt(maxf(srm * srm - dyy * dyy, 0.0))
			if ym2 < floorm + 0.06: col2 = shade
		for px2 in range(-int(half * PPM), int(half * PPM)):
			_bp_set(img, cx + px2, y2 - py, col2)
	for sgn3 in [-1, 1]:                                                  # wheels at ±track/2 (edge-on: tread rect)
		var wx: int = cx + sgn3 * int(RIG_TRACK * 0.5 * PPM)
		_bp_rect(img, wx - int(0.11 * PPM), wx + int(0.11 * PPM), y2, y2 - int(RIG_WHEEL_VIS * 2.0 * PPM), tyre)
	_bp_hline(img, cx - int(bhw * PPM) - 22, cx + int(bhw * PPM) + 22, y2, RULE)
	for sgn4 in [-1, 1]:
		_bp_vline(img, cx + sgn4 * int(bhw * PPM), y2 + 4, y2 + 14, DIMC)
		_bp_vline(img, cx + sgn4 * int(rhw * PPM), y2 - int(roof * PPM) - 14, y2 - int(roof * PPM) - 4, DIMC)

	img.save_png(ProjectSettings.globalize_path("res://assets/voxels/cars/_review/blueprint_car.png"))
	print("BLUEPRINT (STEP 0) -> assets/voxels/cars/_review/blueprint_car.png")
	print("  L %.2f  body_w %.2f  wheelbase %.2f (wz %.2f/%.2f)  overhangs f %.2f / r %.2f" % [
		L, bw, float(SPEC.wz_r) - float(SPEC.wz_f), float(SPEC.wz_f), float(SPEC.wz_r), float(SPEC.wz_f), L - float(SPEC.wz_r)])
	print("  heights: floor %.2f  belt %.2f  roof %.2f  (glass band %.2f)  greenhouse %.2f -> roof_w %.2f" % [
		floorm, belt, roof, gtop - belt, float(SPEC.green_belt_w), float(SPEC.roof_w)])
	print("  rake z: cowl %.2f  roof_front %.2f  roof_rear %.2f  greenhouse ends %.2f  [%s]" % [
		cowl, float(SPEC.roof_front), float(SPEC.roof_rear), ht, str(SPEC.get("body_style", "hatch"))])

# ---- blueprint pixel helpers ----
func _bp_set(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height(): img.set_pixel(x, y, col)

func _bp_hline(img: Image, x0: int, x1: int, y: int, col: Color) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1): _bp_set(img, x, y, col)

func _bp_vline(img: Image, x: int, y0: int, y1: int, col: Color) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1): _bp_set(img, x, y, col)

func _bp_rect(img: Image, x0: int, x1: int, y0: int, y1: int, col: Color) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for y in range(mini(y0, y1), maxi(y0, y1) + 1): _bp_set(img, x, y, col)

func _bp_disc(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for x in range(cx - r, cx + r + 1):
		for y in range(cy - r, cy + r + 1):
			if Vector2(x - cx, y - cy).length() <= float(r): _bp_set(img, x, y, col)

func _bp_grid(img: Image, y0: int, y1: int, y2: int, L: float, bw: float, sh: float, th: float, rh: float) -> void:
	var w := int(maxf(L, bw) * PPM)
	for m in range(0, int(L * 2) + 1):                       # 0.5 m verticals
		var x := BPAD + int(float(m) * 0.5 * PPM)
		_bp_vline(img, x, y0 - int(sh * PPM), y0, GRID)
		_bp_vline(img, x, y1 - int(th * PPM * 0.5), y1 + int(th * PPM * 0.5), GRID)
	for m2 in range(0, int(sh * 2) + 1):                     # 0.5 m horizontals
		var y := y0 - int(float(m2) * 0.5 * PPM)
		_bp_hline(img, BPAD, BPAD + w, y, GRID)
		_bp_hline(img, BPAD, BPAD + w, y2 - int(float(m2) * 0.5 * PPM), GRID)
