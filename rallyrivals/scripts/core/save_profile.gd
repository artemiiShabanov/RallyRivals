class_name SaveProfile
extends Resource
## One career save (a slot). Holds the whole persistent player state: the two currencies (money for
## the garage, CP for progression — GDD §8), owned cars + current pick, and the banked-best finishing
## place per race (GDD §5, feeds code-meta-economy later). Persisted as JSON via to_dict/from_dict —
## human-readable and robust across schema changes (a missing key falls back to its default).

@export var slot := 0
@export var money := 0
@export var cp := 0
@export var owned_cars: PackedStringArray = []   ## CarDef ids the player owns
@export var current_car := ""                    ## selected CarDef id
@export var bests: Dictionary = {}               ## race_id (String) -> best place (int, 1 = win)
@export var created_unix := 0                     ## slot creation time
@export var played_unix := 0                      ## last save time
@export var playtime_sec := 0.0

func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"money": money,
		"cp": cp,
		"owned_cars": Array(owned_cars),
		"current_car": current_car,
		"bests": bests,
		"created_unix": created_unix,
		"played_unix": played_unix,
		"playtime_sec": playtime_sec,
	}

static func from_dict(d: Dictionary) -> SaveProfile:
	var p := SaveProfile.new()
	p.slot = int(d.get("slot", 0))
	p.money = int(d.get("money", 0))
	p.cp = int(d.get("cp", 0))
	p.owned_cars = PackedStringArray(d.get("owned_cars", []))
	p.current_car = String(d.get("current_car", ""))
	p.bests = d.get("bests", {})
	p.created_unix = int(d.get("created_unix", 0))
	p.played_unix = int(d.get("played_unix", 0))
	p.playtime_sec = float(d.get("playtime_sec", 0.0))
	return p
