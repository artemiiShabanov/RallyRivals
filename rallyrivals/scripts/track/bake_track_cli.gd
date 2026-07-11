extends SceneTree
## Headless entry point for TrackBaker — bakes the demo track from assets/tracks/demo/.
## Run: godot --headless --script res://scripts/track/bake_track_cli.gd
## (The in-editor bake button is code-track-bake-tool; this is the source of truth meanwhile.)

func _initialize() -> void:
	var baker := TrackBaker.new()
	baker.src_dir = "res://assets/tracks/demo"
	baker.out_scene = "res://assets/tracks/demo/baked_track.tscn"
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
