class_name SurfaceMap
extends Resource
## Maps a world XZ position to the SurfaceType painted there, by sampling the track's surface image.
## Needed because a track's ground is ONE collision body (HeightMapShape3D) that can't carry a
## per-body SurfaceType meta — so grip is position-based. The baker attaches this to the ground body
## as meta "surface_map"; VehicleController._surface_grip() samples it per wheel. (Simple single-
## surface bodies can still use per-body meta "surface" instead.)

@export var surface_image_path := ""            ## res:// path to the surface splat PNG (exact colours)
@export var surfaces: Array[SurfaceType] = []   ## road palette
@export var off_road: SurfaceType               ## fallback / off-road surface
@export var mpp := 1.0                           ## metres per pixel (matches the bake)

var _img: Image
var _size := 0
var _loaded := false

func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	# Load the raw PNG (not the imported texture) so palette colours are exact, not VRAM-compressed.
	if surface_image_path != "":
		_img = Image.load_from_file(ProjectSettings.globalize_path(surface_image_path))
		if _img == null:
			var tex := load(surface_image_path)
			if tex is Texture2D:
				_img = (tex as Texture2D).get_image()
	if _img != null:
		_size = _img.get_width()

## SurfaceType painted at a world XZ. Off-road / out of bounds -> off_road.
func surface_at(wx: float, wz: float) -> SurfaceType:
	_ensure()
	if _img == null or _size == 0:
		return off_road
	var px := int(round(wx / mpp + _size * 0.5))
	var py := int(round(wz / mpp + _size * 0.5))
	if px < 0 or py < 0 or px >= _size or py >= _size:
		return off_road
	return _classify(_img.get_pixel(px, py))

## Grip value of the surface at a world XZ.
func grip_at(wx: float, wz: float) -> float:
	var s := surface_at(wx, wz)
	return s.grip if s != null else 0.0

func _classify(col: Color) -> SurfaceType:
	var best := INF
	var pick: SurfaceType = off_road
	for s in surfaces:
		var d := _cd(col, s.color)
		if d < best:
			best = d; pick = s
	if off_road != null and _cd(col, off_road.color) < best:
		pick = off_road
	return pick

func _cd(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
