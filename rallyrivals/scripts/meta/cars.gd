class_name Cars
extends RefCounted
## Car catalog (code-meta-car-catalog). Loads every CarDef under assets/cars/ once and answers the
## queries the shop and garage need: all cars, a car by id, the owned set, what's buyable, and a
## price. Prices are a PLACEHOLDER derived from class (D cheap → S dear) until balance-economy-tables
## authors real ones — an authored price on the CarDef wins if set. Cars sort by class (S→D) then name.

const DIR := "res://assets/cars/"
const CLASS_ORDER := ["S", "A", "B", "C", "D"]
const CLASS_PRICE := {"S": 160000, "A": 85000, "B": 40000, "C": 18000, "D": 8000}

static var _cache: Array[CarDef] = []

static func all() -> Array[CarDef]:
	if _cache.is_empty():
		_load()
	return _cache

static func _load() -> void:
	var da := DirAccess.open(DIR)
	if da == null:
		push_error("Cars: cannot open %s" % DIR)
		return
	for f in da.get_files():
		if f.get_extension() == "tres":
			var def := load(DIR + f) as CarDef
			if def != null:
				_cache.append(def)
	_cache.sort_custom(func(a: CarDef, b: CarDef) -> bool:
		var ra := class_rank(a.car_class)
		var rb := class_rank(b.car_class)
		if ra != rb:
			return ra < rb
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)

static func by_id(id: String) -> CarDef:
	for d in all():
		if d.id == id:
			return d
	return null

static func is_owned(id: String) -> bool:
	return Save.active != null and id in Save.active.owned_cars

## The player's owned cars as CarDefs (in catalog order).
static func owned() -> Array[CarDef]:
	var out: Array[CarDef] = []
	for d in all():
		if is_owned(d.id):
			out.append(d)
	return out

## What the shop sells: not a pink-slip trophy, and not already owned.
static func buyable() -> Array[CarDef]:
	var out: Array[CarDef] = []
	for d in all():
		if not d.pink_slip_only and not is_owned(d.id):
			out.append(d)
	return out

static func price_of(def: CarDef) -> int:
	if def == null:
		return 0
	if def.price > 0:                       # an authored price wins over the class placeholder
		return def.price
	return int(CLASS_PRICE.get(def.car_class, 0))

## 0 = S (top) … 4 = D. Unknown classes sort last.
static func class_rank(cls: String) -> int:
	var i := CLASS_ORDER.find(cls)
	return i if i >= 0 else CLASS_ORDER.size()
