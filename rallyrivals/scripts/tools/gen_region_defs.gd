extends SceneTree
## Writes the 4 campaign REGION .tres (code-track-regions) to assets/regions/, 1:1 with chapters.
## Placeholder biomes — off-road SurfaceType (grip + ground colour) + per-type prop tints — until
## art-world-regions authors the real look. Run: godot --headless --script res://scripts/tools/gen_region_defs.gd

const RegionDef = preload("res://scripts/world/region_def.gd")

func _initialize() -> void:
	var dir := "res://assets/regions/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	# Regions are places, NOT chapter tiers — Campaign mixes them across a chapter's races.
	# Backwoods — dirt — forest + Eastern-European countryside: dense conifers, lush greens.
	_write(dir, "backwoods", "Backwoods", "dirt",
		"Forest + Eastern-European countryside — dense conifers, log fences, muddy tracks, a treeline horizon.",
		{"tree": Color(0.15, 0.42, 0.15), "rock": Color(0.42, 0.40, 0.36), "bush": Color(0.19, 0.45, 0.17)},
		Color(0.17, 0.40, 0.16))
	# Dunes — sand — salt lake + desert, Mexico vibe: dusty olive scrub, sandstone, pale flats.
	_write(dir, "dunes", "Dunes", "sand",
		"Salt lake + desert, Mexico vibe — cactus scrub, sandstone mesas, a pale salt-flat horizon under warm haze.",
		{"tree": Color(0.42, 0.50, 0.26), "rock": Color(0.72, 0.58, 0.40), "bush": Color(0.56, 0.55, 0.33)},
		Color(0.66, 0.60, 0.42))
	# Island — grass — Iceland + volcanic, water on the horizon: vivid moss-green, black volcanic rock.
	_write(dir, "island", "Island", "grass",
		"Iceland + volcanic, water on the horizon — vivid moss-green fields, black basalt rock, sea/lake at the edge.",
		{"tree": Color(0.18, 0.50, 0.24), "rock": Color(0.19, 0.19, 0.21), "bush": Color(0.24, 0.52, 0.26)},
		Color(0.22, 0.48, 0.26))
	# Alpine — snow — mountains + alpine village: dark pines on white, slate rock.
	_write(dir, "alpine", "Alpine", "snow",
		"Mountains + alpine village — dark pines on white, slate outcrops, timber chalets, a peaked skyline.",
		{"tree": Color(0.12, 0.30, 0.22), "rock": Color(0.50, 0.53, 0.58), "bush": Color(0.16, 0.34, 0.26)},
		Color(0.62, 0.68, 0.76))

	# quarry was Stage 1's placeholder — replaced by island; remove the stale .tres.
	var stale := ProjectSettings.globalize_path(dir + "quarry.tres")
	if FileAccess.file_exists(stale):
		DirAccess.remove_absolute(stale)

	print("region defs: 4")
	quit()

func _write(dir: String, id: String, name: String, off_road: String, vibe: String, tints: Dictionary, dressing: Color) -> void:
	var r = RegionDef.new()
	r.id = id
	r.display_name = name
	r.vibe = vibe
	r.off_road_surface = load("res://assets/surfaces/%s.tres" % off_road) as SurfaceType
	r.prop_tints = tints
	r.dressing_tint = dressing
	var err := ResourceSaver.save(r, dir + id + ".tres")
	if err != OK:
		push_error("gen_region_defs: save %s failed (%d)" % [id, err])
