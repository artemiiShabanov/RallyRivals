extends SceneTree
## Authoritative look/mark/dust values for the six surfaces (assets/surfaces/*.tres). Run IN Godot
## and saved via ResourceSaver, because hand-editing the .tres around an editor pass loses fields —
## the editor re-serialises new script properties back to their defaults.
## Run: godot --headless --script res://scripts/tools/gen_surface_defs.gd
##
## Leaves grip / color / tint_variation / texture as authored; sets only the visual-response set.
## Columns: roughness, chunkiness | mark rgba, mark_baseline | dust amount, rgba, size, baseline,
## rise, gravity, spread, lifetime | scatter density, size, colour.

const S := {
	"asphalt": {"rough": 0.92, "chunk": 0.06, "mark": [0.05, 0.05, 0.06, 0.55], "mbase": 0.0,
		"damt": 0, "dcol": [0.1, 0.1, 0.1, 0.0], "dsize": 0.06, "dbase": 0.0, "drise": 0.0, "dgrav": 0.0, "dspread": 20.0, "dlife": 0.5, "sden": 0.0, "ssize": 0.1, "scol": [0.3, 0.3, 0.32]},
	"gravel": {"rough": 1.0, "chunk": 1.0, "mark": [0.20, 0.18, 0.15, 0.50], "mbase": 0.24,
		"damt": 276, "dcol": [0.46, 0.45, 0.42, 0.9], "dsize": 0.037, "dbase": 0.20, "drise": 1.6, "dgrav": -6.0, "dspread": 65.0, "dlife": 0.15, "sden": 1.6, "ssize": 0.22, "scol": [0.52, 0.5, 0.47]},
	"dirt": {"rough": 1.0, "chunk": 0.55, "mark": [0.14, 0.09, 0.05, 0.55], "mbase": 0.26,
		"damt": 360, "dcol": [0.30, 0.20, 0.11, 0.8], "dsize": 0.025, "dbase": 0.22, "drise": 2.2, "dgrav": -2.0, "dspread": 75.0, "dlife": 0.225, "sden": 0.9, "ssize": 0.17, "scol": [0.28, 0.19, 0.11]},
	"sand": {"rough": 1.0, "chunk": 0.30, "mark": [0.50, 0.42, 0.27, 0.50], "mbase": 0.30,
		"damt": 432, "dcol": [0.76, 0.66, 0.42, 0.75], "dsize": 0.017, "dbase": 0.26, "drise": 2.0, "dgrav": -1.8, "dspread": 85.0, "dlife": 0.225, "sden": 0.05, "ssize": 0.13, "scol": [0.78, 0.68, 0.44]},
	"snow": {"rough": 0.88, "chunk": 0.22, "mark": [0.32, 0.38, 0.47, 0.55], "mbase": 0.32,
		"damt": 384, "dcol": [0.95, 0.97, 1.0, 0.9], "dsize": 0.017, "dbase": 0.30, "drise": 2.6, "dgrav": -0.7, "dspread": 90.0, "dlife": 0.3, "sden": 0.7, "ssize": 0.19, "scol": [0.93, 0.95, 1.0]},
	"ice": {"rough": 0.25, "chunk": 0.0, "mark": [0.60, 0.70, 0.82, 0.16], "mbase": 0.05,
		"damt": 0, "dcol": [0.8, 0.9, 1.0, 0.0], "dsize": 0.05, "dbase": 0.0, "drise": 0.0, "dgrav": 0.0, "dspread": 20.0, "dlife": 0.5, "sden": 0.0, "ssize": 0.1, "scol": [0.8, 0.9, 1.0]},
}

func _initialize() -> void:
	for id in S:
		var path := "res://assets/surfaces/%s.tres" % id
		var s := load(path) as SurfaceType
		if s == null:
			push_error("missing surface: " + id)
			continue
		var d: Dictionary = S[id]
		s.roughness = d["rough"]
		s.chunkiness = d["chunk"]
		s.mark_color = _c(d["mark"])
		s.mark_baseline = d["mbase"]
		s.dust_amount = d["damt"]
		s.dust_color = _c(d["dcol"])
		s.dust_size = d["dsize"]
		s.dust_baseline = d["dbase"]
		s.dust_rise = d["drise"]
		s.dust_gravity = d["dgrav"]
		s.dust_spread = d["dspread"]
		s.dust_lifetime = d["dlife"]
		s.scatter_density = d["sden"]
		s.scatter_size = d["ssize"]
		s.scatter_color = Color(d["scol"][0], d["scol"][1], d["scol"][2])
		ResourceSaver.save(s, path)
		print("%-8s rough %.2f chunk %.2f  mark a=%.2f base=%.2f  dust %d size=%.3f  scatter %.2f/m2 @%.2fm" % [
			id, s.roughness, s.chunkiness, s.mark_color.a, s.mark_baseline, s.dust_amount, s.dust_size,
			s.scatter_density, s.scatter_size])
	quit()

func _c(a: Array) -> Color:
	return Color(a[0], a[1], a[2], a[3])
