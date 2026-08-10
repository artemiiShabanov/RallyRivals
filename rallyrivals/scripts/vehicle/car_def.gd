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

@export_group("Models (assets/voxels)")
## ONE shell per car. There are no damaged variants: damage is shown with VFX instead (hood smoke +
## a body judder, both in VehicleController), so a car needs no extra sculpts and every car gets the
## damage read for free. The old model_damaged_1/_2 slots were removed 2026-08-10.
@export var model: Mesh                 ## base shell
@export var wheel_model: Mesh           ## brand wheel, axle along X (no corrective rotation)

@export_group("Collision")
## Body box, sized to THIS car's shell instead of the scene's shared 2x1x4. Zero = keep the scene box
## (the stub cars that have no baked model yet). Emitted by scripts/tools/bake_car.gd so it cannot
## drift from the mesh; aerials (antenna, wing mast) are trimmed out or they become collidable spikes.
## The BOTTOM of every box is pinned to the scene box's y = -0.30: the wheels are raycasts, so the body
## shape never supports the car, and how low it reaches is the ONLY thing that changes ride height and
## bottoming-out. Keeping that fixed means collisions and damage get the real footprint with no
## change to how the car drives.
@export var collision_size := Vector3.ZERO
@export var collision_offset_y := 0.0   ## centre of the box above the car origin
