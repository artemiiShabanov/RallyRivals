class_name RaceDef
extends Resource
## One race on the career map (GDD 5/7/8): which track, what type, whose rules, what
## conditions, what it pays. Consumed by the race harness (track + conditions today; types,
## timing rules and the banked-best economy consume the rest as their tasks land — pools stay
## 0 until balance-economy-tables).

@export var id := ""
@export var display_name := ""
@export var track_scene := ""            ## path to the baked track .tscn

@export_group("Format")
@export_enum("circuit", "sprint", "time_trial", "endurance", "grand_prix") var race_type := "circuit"
@export var laps := 3                    ## circuit/endurance; ignored for point-to-point
@export_enum("officials", "wilds") var culture := "officials"   ## contact rules (code-race-contact)
@export var car_class := ""              ## Grand-Prix class gate (a class letter; "" = open entry). See gate_class()/admits().

@export_group("Field (open races)")
## Class band the AI field is drawn from (field-matching spec): rivals get a uniform-random class in
## [class_low..class_high]; the player's own car has no effect. Either bound "" leaves that side open.
## Author a band spanning 2–3 classes. Ignored by time trial (no field) and grand prix (its own grid).
@export var class_low := ""
@export var class_high := ""

@export_group("Conditions (fixed per race)")
@export var lighting: LightingPreset
@export var weather: WeatherPreset
@export var season := "summer"           ## visual set (code-track-seasons)
@export var ambience: AmbientDef         ## venue bed ("world" layer); weather brings its own

@export_group("Time trial")
## Medal target times in seconds, authored gold < silver < bronze (0 = unset). A time trial has no
## field, so these ARE the field: your time maps to the fastest medal it beats, and that medal is
## your "place" for the banked-best economy (code-race-timetrial). Ignored by every other type.
@export var tt_gold := 0.0
@export var tt_silver := 0.0
@export var tt_bronze := 0.0

@export_group("Reward pools (banked-best)")
@export var money_pool := 0
@export var cp_pool := 0

## The set medal targets, best-first, dropping any left at 0. [] means a time trial with no medals —
## it still finishes and pays the completion slice, it just has nothing to chase.
func tt_targets() -> Array:
	var out: Array = []
	for t in [tt_gold, tt_silver, tt_bronze]:
		if t > 0.0:
			out.append(t)
	out.sort()
	return out

## The class a car must reach to enter — code-meta-classes gating policy. ONLY grand_prix is
## class-gated (GDD §8, field-matching spec); every other type ignores car_class and is open. "" = no
## gate. (The GP task may later widen this to a band; a single required class is the v1 gate.)
func gate_class() -> String:
	return car_class if race_type == "grand_prix" else ""

## May this car enter this race? Open races admit anything; a grand prix needs the car at or ABOVE its
## gate class. Bringing a stronger car is always allowed — out-classing is a reward, never blocked
## (field-matching spec); the gate exists only to stop under-classing the one serious event type.
func admits(car: CarDef) -> bool:
	return car != null and CarClass.at_least(car.car_class, gate_class())
