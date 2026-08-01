extends RefCounted
## Prop catalog + prop-instance list I/O (code-track-props). Single source of truth for the track prop
## TYPES the map editor stamps and the TrackBaker spawns. Intentionally has NO class_name — the baker,
## the document and the editor preload() it by path, so it never depends on the global class registry
## (which lags newly-created scripts in an open editor and would parse-error until a restart).
##
## A prop INSTANCE is {type, x, y, deg?} in IMAGE-PIXEL space (deg optional; absent = random yaw for
## scatter). Instances live in <track>/props.json, authored by the editor and read by the baker.
## TYPES are placeholder gray-box (box/cylinder) until art-voxel-props authors real meshes; scatter
## already fakes the art's per-region x3 variety with seeded size/hue jitter at bake time.
##
## Categories decide placement + authoring:
##   scatter     — a point; random yaw; solid (tree/rock) or decor (bush). One click to place.
##   oriented    — a FIXED-LENGTH run anchored at one END, yaw aimed along its length (fence/barrier).
##                 Two clicks: end, then direction. Tile several for a longer wall.
##   directional — a point with an AIMED yaw (signs face where you point). Two clicks: spot, then facing.
## solid = a StaticBody3D obstacle the car hits; decor = a mesh only (signs/bushes are drive-through).

const PROPS_FILE := "props.json"

const TYPES := {
	"tree":         {"label": "Tree",     "category": "scatter",     "solid": true,  "length": 0.0, "size": Vector3(0.7, 4.2, 0.7), "color": Color(0.20, 0.48, 0.16), "jitter": 0.28},
	"rock":         {"label": "Rock",     "category": "scatter",     "solid": true,  "length": 0.0, "size": Vector3(1.3, 1.1, 1.3), "color": Color(0.48, 0.48, 0.52), "jitter": 0.30},
	"bush":         {"label": "Bush",     "category": "scatter",     "solid": false, "length": 0.0, "size": Vector3(1.1, 0.7, 1.1), "color": Color(0.16, 0.40, 0.14), "jitter": 0.30},
	"fence":        {"label": "Fence",    "category": "oriented",    "solid": true,  "length": 4.0, "size": Vector3(0.15, 1.2, 4.0), "color": Color(0.55, 0.40, 0.24), "jitter": 0.0},
	"barrier_hard": {"label": "Barrier",  "category": "oriented",    "solid": true,  "length": 4.0, "size": Vector3(0.40, 0.9, 4.0), "color": Color(0.70, 0.70, 0.72), "jitter": 0.0},
	"barrier_soft": {"label": "Tirewall", "category": "oriented",    "solid": true,  "length": 3.0, "size": Vector3(0.50, 0.8, 3.0), "color": Color(0.80, 0.28, 0.24), "jitter": 0.0},
	"sign_left":    {"label": "Sign L",   "category": "directional", "solid": false, "length": 0.0, "size": Vector3(1.2, 1.3, 0.14), "color": Color(0.95, 0.80, 0.20), "jitter": 0.0},
	"sign_right":   {"label": "Sign R",   "category": "directional", "solid": false, "length": 0.0, "size": Vector3(1.2, 1.3, 0.14), "color": Color(0.30, 0.65, 0.95), "jitter": 0.0},
}

## Editor palette / tool order.
const ORDER := ["tree", "rock", "bush", "fence", "barrier_hard", "barrier_soft", "sign_left", "sign_right"]

static func has_type(t: String) -> bool:
	return TYPES.has(t)

static func def(t: String) -> Dictionary:
	return TYPES.get(t, {})

static func category(t: String) -> String:
	return String(def(t).get("category", ""))

## Oriented props are fixed-length and anchored at one END (their box extends forward by `length`).
static func is_oriented(t: String) -> bool:
	return category(t) == "oriented"

## Point props (scatter) place with one click; oriented + directional props aim with two clicks.
static func needs_aim(t: String) -> bool:
	var c := category(t)
	return c == "oriented" or c == "directional"

# --- props.json I/O (instances in image-pixel coords) ---

static func load_list(dir: String) -> Array:
	var path := ProjectSettings.globalize_path(dir.path_join(PROPS_FILE))
	if not FileAccess.file_exists(path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and (data as Dictionary).has("props"):
		return (data as Dictionary)["props"]
	if data is Array:
		return data
	return []

static func save_list(dir: String, list: Array) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(ProjectSettings.globalize_path(dir.path_join(PROPS_FILE)), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"props": list}, "\t"))
	f.close()
	return OK
