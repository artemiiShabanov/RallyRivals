@tool
class_name TrackBakeConfig
extends Node
## In-editor bake button. Open scenes/tools/track_bake.tscn (or drop this node anywhere), point
## src_dir at a folder holding the 4 authored images, select the node and click "Bake Track" in
## the inspector. Wraps TrackBaker — the same bake bake_track_cli.gd runs headless. Does nothing
## at runtime. The GUI map editor (code-tools-map-editor-*) will drive the same baker later.

@export_dir var src_dir := "res://assets/tracks/demo"   ## folder with heightmap.exr/surface.png/markers.png/race.png
@export var out_scene := "res://assets/tracks/demo/baked_track.tscn"
@export var mpp := 1.0
@export var max_height := 28.0
@export var mesh_res := 1.0
@export var surfaces: Array[SurfaceType] = []           ## road palette
@export var off_road_surface: SurfaceType
@export_tool_button("Bake Track") var bake_action := _bake

func _bake() -> void:
	var baker := TrackBaker.new()
	baker.src_dir = src_dir
	baker.out_scene = out_scene
	baker.mpp = mpp
	baker.max_height = max_height
	baker.mesh_res = mesh_res
	baker.surfaces = surfaces
	baker.off_road_surface = off_road_surface
	var err := baker.bake()
	if err == OK:
		print("TrackBakeConfig: baked ", out_scene)
		# String lookup, not a direct EditorInterface reference — keeps the script parseable in
		# release builds should it ever slip into an export.
		if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
			Engine.get_singleton("EditorInterface").get_resource_filesystem().scan()
	else:
		push_error("TrackBakeConfig: bake failed (%s) — see errors above" % error_string(err))
