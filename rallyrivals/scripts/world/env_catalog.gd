extends RefCounted
## Scenery/environment model catalog (art-voxel-environment). Maps a model id to its imported .obj mesh
## + placement metadata, for RegionSkin's dressing. NO class_name — preloaded by path (RegionSkin), so
## it stays off the global class registry. Models are the gen_env_voxels block-outs under
## assets/voxels/environment/. mesh() returns the imported .obj, or null when it isn't imported yet
## (fresh headless run, before the editor scans) — the caller then box-fallbacks so dressing always shows.

const DIR := "res://assets/voxels/environment/"

# id -> { category, collision, size(authored bounds in m — used to size the box fallback + collider) }
const MODELS := {
	"ridge":          {"category": "backdrop", "collision": false, "size": Vector3(6.4, 4.4, 2.0)},
	"ridge_volcanic": {"category": "backdrop", "collision": false, "size": Vector3(6.4, 4.4, 2.0)},
	"mesa":           {"category": "backdrop", "collision": false, "size": Vector3(5.6, 4.0, 4.4)},
	"treeline":       {"category": "backdrop", "collision": false, "size": Vector3(5.6, 4.0, 1.8)},
	"house":          {"category": "building", "collision": true,  "size": Vector3(4.0, 4.6, 5.0)},
	"hall":           {"category": "building", "collision": true,  "size": Vector3(6.0, 4.8, 9.6)},
	"tower":          {"category": "building", "collision": true,  "size": Vector3(2.4, 10.0, 2.4)},
}

static func has(id: String) -> bool:
	return MODELS.has(id)

static func def(id: String) -> Dictionary:
	return MODELS.get(id, {})

static func size(id: String) -> Vector3:
	return def(id).get("size", Vector3(2, 2, 2))

static func is_solid(id: String) -> bool:
	return bool(def(id).get("collision", false))

## The imported .obj mesh for `id`, or null if it isn't imported yet / missing (caller box-fallbacks).
## The .obj base sits at y=0, centred in x/z (gen_env_voxels), so it drops straight onto the ground.
static func mesh(id: String) -> Mesh:
	var p := DIR + id + ".obj"
	if not ResourceLoader.exists(p):
		return null
	var res = load(p)
	return res if res is Mesh else null
