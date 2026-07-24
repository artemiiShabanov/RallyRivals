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
@export var car_class := ""              ## GP class gate ("" = open entry)

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
