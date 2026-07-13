class_name TrackDocument
extends RefCounted
## The map editor's working document = a track folder (assets/tracks/<name>/). The editable
## layers ARE the pipeline's source images (surface.png / markers.png / race.png) — saving
## writes them directly, so there is no second file format and the baker can consume the folder
## as-is. heightmap.exr is NOT edited here: it derives from the painted road at export
## (code-tools-map-editor-height/-export). editor.json carries editor-only state (blueprint
## underlay, layer view settings). Conventions match the pipeline: RGB8, black = empty on
## markers/race, surface = solid SurfaceType colours (off-road/sand everywhere by default).

const LAYERS := ["surface", "markers", "race"]
const META_FILE := "editor.json"

var dir := ""
var size := 512
var images := {}                 # layer -> Image (authoring data, saved to PNG)
var textures := {}               # layer -> ImageTexture (display; black-empty layers shown transparent)
var blueprint_path := ""         # reference underlay (absolute or res:// path; never exported)
var blueprint_texture: Texture2D
var layer_visible := {"blueprint": true, "surface": true, "markers": true, "race": true}
var layer_opacity := {"blueprint": 0.5, "surface": 1.0, "markers": 1.0, "race": 1.0}

static func _off_road_color() -> Color:
	return (load("res://assets/surfaces/sand.tres") as SurfaceType).color

## Fresh blank document (surface = all off-road, markers/race = empty).
static func create(p_dir: String, p_size: int) -> TrackDocument:
	var doc := TrackDocument.new()
	doc.dir = p_dir
	doc.size = p_size
	for layer in LAYERS:
		doc.images[layer] = _blank_layer(layer, p_size)
		doc.refresh_texture(layer)
	return doc

## Open an existing track folder; null if there's nothing to open there.
static func open(p_dir: String) -> TrackDocument:
	var doc := TrackDocument.new()
	doc.dir = p_dir
	for layer in LAYERS:
		var path := ProjectSettings.globalize_path(p_dir.path_join(layer + ".png"))
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null:
				doc.images[layer] = img
				if doc.size == 512 or doc.size == 0:
					doc.size = img.get_width()
	var has_meta := FileAccess.file_exists(ProjectSettings.globalize_path(p_dir.path_join(META_FILE)))
	if doc.images.is_empty() and not has_meta:
		return null
	doc._load_meta()
	if not doc.images.is_empty():
		doc.size = (doc.images.values()[0] as Image).get_width()
	for layer in LAYERS:   # anything missing on disk becomes a blank layer at the doc size
		if not doc.images.has(layer):
			doc.images[layer] = _blank_layer(layer, doc.size)
		doc.refresh_texture(layer)
	if doc.blueprint_path != "":
		doc.load_blueprint(doc.blueprint_path)
	return doc

static func _blank_layer(layer: String, p_size: int) -> Image:
	var img := Image.create(p_size, p_size, false, Image.FORMAT_RGB8)
	if layer == "surface":
		img.fill(_off_road_color())
	return img

## Write the 3 layer PNGs + editor.json into the track folder.
func save() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for layer in LAYERS:
		var err: Error = (images[layer] as Image).save_png(ProjectSettings.globalize_path(dir.path_join(layer + ".png")))
		if err != OK:
			return err
	var meta := {
		"size": size,
		"blueprint": {"path": blueprint_path, "opacity": layer_opacity["blueprint"], "visible": layer_visible["blueprint"]},
		"layer_visible": {"surface": layer_visible["surface"], "markers": layer_visible["markers"], "race": layer_visible["race"]},
		"layer_opacity": {"surface": layer_opacity["surface"], "markers": layer_opacity["markers"], "race": layer_opacity["race"]},
	}
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join(META_FILE)), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(meta, "\t"))
	return OK

func _load_meta() -> void:
	var path := ProjectSettings.globalize_path(dir.path_join(META_FILE))
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary:
		return
	size = int(data.get("size", size))
	var bp: Dictionary = data.get("blueprint", {})
	blueprint_path = bp.get("path", "")
	layer_opacity["blueprint"] = float(bp.get("opacity", 0.5))
	layer_visible["blueprint"] = bool(bp.get("visible", true))
	for layer in LAYERS:
		layer_visible[layer] = bool((data.get("layer_visible", {}) as Dictionary).get(layer, true))
		layer_opacity[layer] = float((data.get("layer_opacity", {}) as Dictionary).get(layer, 1.0))

## Rebuild a layer's display texture. Call after any edit to images[layer] (paint tools do).
## markers/race use black-as-empty, shown transparent so layers below stay visible.
func refresh_texture(layer: String) -> void:
	var img: Image = images[layer]
	if layer == "surface":
		textures[layer] = ImageTexture.create_from_image(img)
		return
	var disp := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.05:
				disp.set_pixel(x, y, c)
	textures[layer] = ImageTexture.create_from_image(disp)

## Fast in-place display refresh after painting. Surface displays its raw image, so the GPU
## texture updates directly; overlay layers derive a transparent image -> full rebuild.
func update_texture(layer: String) -> void:
	if layer == "surface" and textures.has(layer):
		(textures[layer] as ImageTexture).update(images[layer])
	else:
		refresh_texture(layer)

## Load a reference underlay image (any path on disk). Not part of the export.
func load_blueprint(path: String) -> bool:
	var img := Image.load_from_file(path if path.is_absolute_path() else ProjectSettings.globalize_path(path))
	if img == null:
		blueprint_texture = null
		return false
	blueprint_path = path
	blueprint_texture = ImageTexture.create_from_image(img)
	return true
