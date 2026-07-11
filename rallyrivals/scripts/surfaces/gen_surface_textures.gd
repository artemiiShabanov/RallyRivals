extends SceneTree
## Generates STUB grayscale detail textures for each SurfaceType into assets/surfaces/tex/.
## Grayscale (mean ~0.9) so it multiplies the surface colour without recolouring; seamlessly
## tileable (wrapping value-noise lattice + per-pixel speckle + integer-freq ripple) so it looks
## right triplanar-tiled on the ground. Placeholder until real splat art (art-world-terrain-tex).
## Run: godot --headless --script res://scripts/surfaces/gen_surface_textures.gd

const S := 256
const OUT := "res://assets/surfaces/tex/"

# id -> [lattice_n, contrast, speckle, base, ripple]
var _cfg := {
	"asphalt": [28, 0.06, 0.10, 0.90, 0.0],
	"gravel":  [16, 0.20, 0.12, 0.84, 0.0],
	"dirt":    [11, 0.18, 0.06, 0.86, 0.0],
	"sand":    [7,  0.08, 0.03, 0.90, 0.05],
	"snow":    [9,  0.04, 0.02, 0.95, 0.0],
	"ice":     [6,  0.07, 0.02, 0.93, 0.0],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id in _cfg:
		var c: Array = _cfg[id]
		var n: int = c[0]
		var contrast: float = c[1]
		var speckle: float = c[2]
		var base: float = c[3]
		var ripple: float = c[4]
		var seed := int(hash(id))
		var rng := RandomNumberGenerator.new(); rng.seed = seed
		var lat := PackedFloat32Array(); lat.resize(n * n)
		for i in n * n:
			lat[i] = rng.randf()
		var img := Image.create(S, S, false, Image.FORMAT_RGB8)
		for y in S:
			for x in S:
				var u := float(x) / S
				var v := float(y) / S
				var nz := _samp(lat, n, u, v)                     # smooth tileable blobs 0..1
				var g := base + (nz - 0.5) * 2.0 * contrast
				if ripple > 0.0:
					g += sin(TAU * 3.0 * v) * ripple              # integer freq -> tileable
				g += (_hash(x, y, seed) - 0.5) * 2.0 * speckle    # per-pixel grain (tileable)
				g = clampf(g, 0.0, 1.0)
				img.set_pixel(x, y, Color(g, g, g))
		img.save_png(OUT + id + ".png")
		print("surface tex: ", id)
	quit()

# Wrapping bilinear (smoothstep) sample of a lattice -> seamless value noise.
func _samp(lat: PackedFloat32Array, n: int, u: float, v: float) -> float:
	var fx := u * n
	var fy := v * n
	var x0 := int(floor(fx)) % n
	var y0 := int(floor(fy)) % n
	var x1 := (x0 + 1) % n
	var y1 := (y0 + 1) % n
	var tx: float = fx - floor(fx)
	var ty: float = fy - floor(fy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := lat[y0 * n + x0]; var b := lat[y0 * n + x1]
	var c := lat[y1 * n + x0]; var d := lat[y1 * n + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

# Deterministic per-pixel hash in [0,1) — high-freq speckle tiles with no visible seam.
func _hash(x: int, y: int, s: int) -> float:
	var h := x * 374761393 + y * 668265263 + s * 69069
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)
