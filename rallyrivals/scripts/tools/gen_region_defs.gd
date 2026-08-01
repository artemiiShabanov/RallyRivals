extends SceneTree
## Writes the 4 campaign REGION .tres (code-track-regions) to assets/regions/, 1:1 with chapters.
## Placeholder biomes — off-road SurfaceType (grip + ground colour) + per-type prop tints — until
## art-world-regions authors the real look. Run: godot --headless --script res://scripts/tools/gen_region_defs.gd

const RegionDef = preload("res://scripts/world/region_def.gd")

func _initialize() -> void:
	var dir := "res://assets/regions/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# Ch1 Backwoods — earthy dirt off-road, lush green scatter.
	_write(dir, "backwoods", "Backwoods", "dirt", {
		"tree": Color(0.16, 0.44, 0.16), "rock": Color(0.42, 0.40, 0.36), "bush": Color(0.20, 0.46, 0.18)})
	# Ch2 Dunes — sand off-road, dry olive/khaki scatter.
	_write(dir, "dunes", "Dunes", "sand", {
		"tree": Color(0.45, 0.48, 0.22), "rock": Color(0.68, 0.60, 0.44), "bush": Color(0.52, 0.50, 0.28)})
	# Ch3 Quarry — grey gravel off-road, muted grey-green industrial scatter.
	_write(dir, "quarry", "Quarry", "gravel", {
		"tree": Color(0.30, 0.38, 0.30), "rock": Color(0.38, 0.38, 0.40), "bush": Color(0.34, 0.40, 0.32)})
	# Ch4 Alpine — snow off-road, dark pines on white.
	_write(dir, "alpine", "Alpine", "snow", {
		"tree": Color(0.12, 0.30, 0.22), "rock": Color(0.50, 0.53, 0.58), "bush": Color(0.16, 0.34, 0.26)})

	print("region defs: 4")
	quit()

func _write(dir: String, id: String, name: String, off_road: String, tints: Dictionary) -> void:
	var r = RegionDef.new()
	r.id = id
	r.display_name = name
	r.off_road_surface = load("res://assets/surfaces/%s.tres" % off_road) as SurfaceType
	r.prop_tints = tints
	r.dressing_tint = tints.get("bush", Color(0.2, 0.4, 0.18))
	var err := ResourceSaver.save(r, dir + id + ".tres")
	if err != OK:
		push_error("gen_region_defs: save %s failed (%d)" % [id, err])
