class_name RaceField
extends RefCounted
## Assembles a race's AI field (field-matching spec §4). Given a RaceDef and the current chapter, it
## draws N of the chapter's 9 rivals (N by race type), assigns each a uniform-random class inside the
## race's class band, and resolves (brand, class) → the exact car. The player's own car has NO effect
## — difficulty is a property of the RACE (its band), not a reaction to what you brought.
##
## The draw is FRESH and RANDOM per race (drawn entrants + their classes vary each time); only the
## roster it draws from is deterministic (Roster). Time trial fields nobody; grand prix builds its own
## qualifying grid (code-race-grandprix), so both return an empty field here.

const SIZE_BY_TYPE := {
	"sprint": 4, "circuit": 6, "endurance": 8, "time_trial": 0, "grand_prix": 0,
}

## Number of AI rivals a race type fields (0 = no field).
static func size_for(race_type: String) -> int:
	return int(SIZE_BY_TYPE.get(race_type, 0))

## The field for `race` in `chapter` (0-based): an Array of {driver: DriverDef, car: CarDef, car_class}.
## Empty when the type fields nobody. Any (brand, class) that fails to resolve a car is skipped with a
## warning (a data error, not a normal outcome — the 3×5 grid is complete).
static func assemble(race: RaceDef, chapter := 0) -> Array:
	var n := size_for(race.race_type)
	if n <= 0 or race == null:
		return []
	var pool := Roster.chapter(chapter).duplicate()
	pool.shuffle()                                  # fresh draw each race (global RNG, non-deterministic)
	var band := _band_classes(race)
	var field: Array = []
	for i in mini(n, pool.size()):
		var driver: DriverDef = pool[i]
		var cls: String = band[randi() % band.size()]
		var car := Cars.by_brand_class(driver.brand, cls)
		if car == null:
			push_warning("RaceField: no car for (%s, %s) — driver %s skipped" % [driver.brand, cls, driver.hud])
			continue
		field.append({"driver": driver, "car": car, "car_class": cls})
	return field

# The class letters a race's band admits (CarClass.in_band). Falls back to the full S–D range if the
# race left its band open — an open race should author one, but the field must never come up empty.
static func _band_classes(race: RaceDef) -> Array:
	var out: Array = []
	for cls in CarClass.ALL:
		if CarClass.in_band(cls, race.class_low, race.class_high):
			out.append(cls)
	return out if not out.is_empty() else CarClass.ALL.duplicate()
