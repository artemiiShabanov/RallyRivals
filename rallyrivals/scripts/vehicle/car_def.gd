class_name CarDef
extends Resource
## One car of the roster (docs/CARS.md). The five 1-10 bars are the ONLY displayed stats
## (GDD 4: fixed per car, no tuning); mass and damage_sensitivity are hidden brand-physique
## traits (mass = contact/momentum identity, forces are mass-compensated so bars never lie;
## damage_sensitivity is consumed by code-vehicle-damage). VehicleController.apply_car_def()
## maps bars onto handling via endpoint tables — balance tunes endpoints, never cars.

@export var id := ""
@export var display_name := ""
@export var brand := ""             ## apex | wreck | mayfly
@export var car_class := ""         ## D | C | B | A | S
@export var price := 0              ## 0 = TBD (balance-economy-tables)
@export var pink_slip_only := false ## boss trophy — never in the shop

@export_group("Stats (1-10 bars)")
@export_range(1, 10) var speed := 5
@export_range(1, 10) var accel := 5
@export_range(1, 10) var steering := 5
@export_range(1, 10) var braking := 5
@export_range(1, 10) var grip := 5

@export_group("Physique (hidden traits)")
@export var mass := 800.0               ## kg — brand identity channel
@export var damage_sensitivity := 1.0   ## multiplies performance-damage effects
