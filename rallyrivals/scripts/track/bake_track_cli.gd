extends SceneTree
## Headless entry point for TrackBaker. Bakes assets/tracks/demo by default; pass a track folder
## (and optionally a TrackPath point count) as user args:
##   godot --headless --script res://scripts/track/bake_track_cli.gd -- res://assets/tracks/test 36
## (The in-editor button is scenes/tools/track_bake.tscn.)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var baker := TrackBaker.new()
	baker.src_dir = args[0] if args.size() > 0 else "res://assets/tracks/demo"
	baker.out_scene = baker.src_dir.path_join("baked_track.tscn")
	if args.size() > 1:
		baker.path_points = int(args[1])
	baker.surfaces = [
		load("res://assets/surfaces/asphalt.tres"),
		load("res://assets/surfaces/dirt.tres"),
		load("res://assets/surfaces/ice.tres"),
	]
	baker.off_road_surface = load("res://assets/surfaces/sand.tres")
	var err := baker.bake()
	if err != OK:
		push_error("bake failed: %d" % err)
	quit()
