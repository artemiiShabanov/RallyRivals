class_name Roster
extends RefCounted
## The campaign's rival drivers (field-matching spec §3, ROSTER.md). Generates 4 chapters × 9 = 36
## DriverDefs ONCE per save and persists them in SaveProfile.roster, so the same save always shows the
## same rivals. Per chapter: an exact 3/3/3 apex/wreck/mayfly brand split (so every (brand, class)→car
## lookup resolves), campaign-unique numbers from the 1–100 pool minus the boss plates + the player's
## #99, and unique surnames (the HUD names). Behaviour tags are left blank — that set is code-ai-
## difficulty's to define. The field DRAW (RaceField) is separate and random per race; only this
## generation is deterministic and banked.
##
## No active save (F6 / a bare test scene) → an ephemeral roster from a fixed seed, stable in-session.

const CHAPTERS := 4
const PER_CHAPTER := 9
const RESERVED := [1, 7, 23, 66, 99]      ## boss plates {66,23,7,1} + the player's #99 (RIVALS.md)
const BRANDS := ["apex", "wreck", "mayfly"]
const EPHEMERAL_SEED := 20260726          ## stable rivals when there's no save (demo / F6)

const FIRST_NAMES := [
	"Ari", "Bex", "Cato", "Dima", "Enzo", "Faye", "Gio", "Hana", "Juno", "Kai", "Lena", "Milo",
	"Nadia", "Oskar", "Pia", "Quinn", "Raf", "Sana", "Tomas", "Ulla", "Vince", "Wren", "Xan", "Yara",
	"Zeke", "Bo", "Del", "Esa", "Freya", "Goran", "Ines", "Jax", "Kira", "Lev", "Mika", "Noor",
	"Otto", "Petra", "Remy", "Suvi", "Tavi", "Vesa",
]
# 45 surnames (the HUD names); the boss surnames Drago/Mercer/Vance/Kozak are deliberately absent.
const SURNAMES := [
	"Astor", "Bosch", "Cray", "Dunne", "Ebert", "Falk", "Grim", "Holt", "Ilves", "Juvela", "Kade",
	"Lund", "Mott", "Novak", "Oksa", "Pryce", "Quist", "Roos", "Salo", "Thorne", "Udin", "Vint",
	"Wade", "Yost", "Zane", "Brandt", "Corso", "Dax", "Enko", "Frey", "Groves", "Haas", "Ingram",
	"Joos", "Krall", "Lenz", "Marsh", "Niko", "Osei", "Park", "Reyes", "Sandu", "Tersk", "Voss", "Weir",
]

static var _ephemeral: Array = []   # cached no-save roster (Array of DriverDef)

## All 36 drivers (Array[DriverDef]), generating + persisting them on first access.
static func all() -> Array:
	if Save.active == null:
		if _ephemeral.is_empty():
			_ephemeral = _generate(EPHEMERAL_SEED)
		return _ephemeral
	if Save.active.roster.is_empty():
		var g := _generate(Save.active.created_unix if Save.active.created_unix != 0 else EPHEMERAL_SEED)
		Save.active.roster = _to_dicts(g)
		Save.write()
	return _from_dicts(Save.active.roster)

## The 9 drivers of chapter `idx` (0-based, clamped).
static func chapter(idx: int) -> Array:
	var c := clampi(idx, 0, CHAPTERS - 1)
	return all().slice(c * PER_CHAPTER, c * PER_CHAPTER + PER_CHAPTER)

# ---------- generation ----------
static func _generate(gen_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen_seed
	var numbers := _shuffled(_number_pool(), rng)
	var surnames := _shuffled(SURNAMES.duplicate(), rng)
	var out: Array = []
	var i := 0
	for _c in CHAPTERS:
		var brands := _shuffled(_brand_slots(), rng)   # 9 slots, exactly 3 of each brand
		for k in PER_CHAPTER:
			var first: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
			var sur: String = surnames[i]
			out.append(DriverDef.make("%s %s" % [first, sur], sur, numbers[i], brands[k]))
			i += 1
	return out

static func _number_pool() -> Array:
	var pool: Array = []
	for n in range(1, 101):
		if n not in RESERVED:
			pool.append(n)
	return pool

static func _brand_slots() -> Array:
	var slots: Array = []
	for b in BRANDS:
		for _i in 3:
			slots.append(b)
	return slots

# Deterministic Fisher–Yates using the seeded rng (Array.shuffle() would use the global RNG instead).
static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]; a[i] = a[j]; a[j] = t
	return a

static func _to_dicts(drivers: Array) -> Array:
	var out: Array = []
	for d in drivers:
		out.append((d as DriverDef).to_dict())
	return out

static func _from_dicts(dicts: Array) -> Array:
	var out: Array = []
	for d in dicts:
		out.append(DriverDef.from_dict(d))
	return out
