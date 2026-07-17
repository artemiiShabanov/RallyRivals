extends SceneTree
## Writes the 15 CarDef .tres files from the canonical roster (docs/CARS.md). The doc is the
## source of truth — edit it, mirror the table here, regenerate. Prices stay 0 until
## balance-economy-tables. Run: godot --headless --script res://scripts/tools/gen_car_defs.gd

const BRAND_MASS := {"apex": 800.0, "wreck": 950.0, "mayfly": 680.0}
const BRAND_DMG := {"apex": 1.0, "wreck": 0.8, "mayfly": 1.25}

# id, name, brand, class, pink_slip, speed, accel, steering, braking, grip
const ROSTER := [
	["kerb", "Kerb", "apex", "D", false, 3, 3, 6, 5, 5],
	["mule", "Mule", "wreck", "D", false, 5, 4, 4, 3, 6],
	["spark", "Spark", "mayfly", "D", false, 4, 5, 6, 3, 4],
	["tangent", "Tangent", "apex", "C", false, 4, 4, 6, 6, 6],
	["crowbar", "Crowbar", "wreck", "C", true, 8, 5, 3, 4, 6],
	["fuse", "Fuse", "mayfly", "C", false, 5, 6, 6, 4, 5],
	["meridian", "Meridian", "apex", "B", false, 5, 5, 7, 7, 6],
	["anvil", "Anvil", "wreck", "B", false, 7, 6, 5, 5, 7],
	["strobe", "Strobe", "mayfly", "B", true, 7, 9, 6, 3, 5],
	["verdict", "Verdict", "apex", "A", true, 5, 3, 9, 8, 9],
	["sledge", "Sledge", "wreck", "A", false, 8, 7, 6, 5, 8],
	["comet", "Comet", "mayfly", "A", false, 7, 8, 8, 5, 6],
	["stiletto", "Stiletto", "apex", "S", false, 7, 7, 9, 8, 7],
	["juggernaut", "Juggernaut", "wreck", "S", true, 10, 8, 4, 8, 8],
	["nova", "Nova", "mayfly", "S", false, 8, 9, 9, 6, 6],
]
const BUDGETS := {"D": 22, "C": 26, "B": 30, "A": 34, "S": 38}

func _initialize() -> void:
	var dir := "res://assets/cars/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for row in ROSTER:
		var total: int = row[5] + row[6] + row[7] + row[8] + row[9]
		if total != BUDGETS[row[3]]:
			push_error("%s: stats sum %d != class %s budget %d" % [row[0], total, row[3], BUDGETS[row[3]]])
			continue
		var def := CarDef.new()
		def.id = row[0]
		def.display_name = row[1]
		def.brand = row[2]
		def.car_class = row[3]
		def.pink_slip_only = row[4]
		def.speed = row[5]
		def.accel = row[6]
		def.steering = row[7]
		def.braking = row[8]
		def.grip = row[9]
		def.mass = BRAND_MASS[row[2]]
		def.damage_sensitivity = BRAND_DMG[row[2]]
		ResourceSaver.save(def, dir + row[0] + ".tres")
	print("car defs written: ", ROSTER.size())
	quit()
