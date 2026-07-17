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

@export_group("Reward pools (banked-best)")
@export var money_pool := 0
@export var cp_pool := 0
