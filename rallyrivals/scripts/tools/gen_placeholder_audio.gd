extends SceneTree
## Generates EVERY placeholder sound in the manifest (docs/AUDIO.md §2) from synthesis — filtered
## noise and harmonic stacks, so it is CC0 by construction and safe to ship, though not intended
## to. Replace streams file-by-file as real recordings are sourced; the defs and call sites do not
## change. Supersedes gen_test_sfx.gd + gen_ambient_sfx.gd.
##
## Three outputs, three shapes:
##   assets/audio/ambient/  AmbientDef + .res  looping beds, crossfaded by AmbientBed
##   assets/audio/sfx/      SfxDef + .res      one-shots played through the Sfx pool
##   assets/audio/loops/    .res only          driven loops (engine, tyres) — NO SfxDef, because a
##                                             looping stream in the one-shot pool never releases
##                                             its player. Their systems own their own config.
##
## Everything is written as .res AudioStreamWAV: loop points live in the resource, so no import
## round-trip is needed and headless runs can load them immediately. Every sound uses a fixed RNG
## seed — regenerating produces identical bytes, so git stays quiet.
## Run: godot --headless --script res://scripts/tools/gen_placeholder_audio.gd

const AMB := "res://assets/audio/ambient/"
const SFX := "res://assets/audio/sfx/"
const LOOPS := "res://assets/audio/loops/"
const RATE := 22050        ## filtered noise and engine harmonics — 11 kHz of bandwidth is plenty
const XFADE := 0.35        ## noise loops: tail overhang faded into the head (see _noise_loop)

var _rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- beds (ambience)
# id, volume_db, seed, recipe
const BEDS := [
	["wind_light", -20.0, 11, "wind_light"],
	["wind_low", -22.0, 12, "wind_low"],
	["rain", -14.0, 13, "rain"],
	["rain_heavy", -11.0, 14, "rain_heavy"],
	["snow_wind", -19.0, 15, "snow_wind"],
	["festival_crowd", -17.0, 16, "crowd"],
]

# ---------------------------------------------------------------- driven loops
# id, seed, recipe, seconds
const DRIVEN := [
	["engine_low", 30, "engine_low", 0.4],       # pitch-scaled at runtime; short + exactly periodic
	["engine_mid", 31, "engine_mid", 0.4],
	["engine_high", 32, "engine_high", 0.4],
	["roll_asphalt", 33, "roll_asphalt", 2.0],   # one per SurfaceType id
	["roll_gravel", 34, "roll_gravel", 2.0],
	["roll_dirt", 35, "roll_dirt", 2.0],
	["roll_sand", 36, "roll_sand", 2.0],
	["roll_snow", 37, "roll_snow", 2.0],
	["roll_ice", 38, "roll_ice", 2.0],
	["skid_asphalt", 39, "skid_asphalt", 2.0],   # squeal
	["skid_loose", 40, "skid_loose", 2.0],       # gravel slide, no tone
	["scrape", 41, "scrape", 2.0],
]

# ---------------------------------------------------------------- one-shots
# id, variants, bus, volume_db, pitch jitter, recipe
const ONESHOTS := [
	["ui_click", 1, "UI", -6.0, 0.0, "ui_click"],
	["ui_move", 1, "UI", -11.0, 0.04, "ui_move"],
	["ui_confirm", 1, "UI", -6.0, 0.02, "ui_confirm"],
	["ui_error", 1, "UI", -6.0, 0.0, "ui_error"],
	["ui_purchase", 1, "UI", -5.0, 0.02, "ui_purchase"],
	["ui_unlock", 1, "UI", -4.0, 0.01, "ui_unlock"],
	["checkpoint", 1, "SFX", -4.0, 0.03, "checkpoint"],
	["countdown_beep", 1, "SFX", -4.0, 0.0, "countdown_beep"],
	["countdown_go", 1, "SFX", -2.0, 0.0, "countdown_go"],
	["lap_best", 1, "SFX", -4.0, 0.02, "lap_best"],
	["finish_win", 1, "SFX", -3.0, 0.01, "finish_win"],
	["finish_lose", 1, "SFX", -5.0, 0.01, "finish_lose"],
	["wrong_way", 1, "SFX", -6.0, 0.0, "wrong_way"],
	["impact_light", 3, "SFX", -5.0, 0.12, "impact_light"],
	["impact_heavy", 3, "SFX", -2.0, 0.10, "impact_heavy"],
	["debris_cubes", 3, "SFX", -8.0, 0.18, "debris"],
	["engine_start", 1, "SFX", -6.0, 0.04, "engine_start"],
	["engine_off", 1, "SFX", -8.0, 0.04, "engine_off"],
	["thunder", 2, "SFX", -3.0, 0.12, "thunder"],
]

var _skipped: PackedStringArray = []

func _initialize() -> void:
	for d in [AMB, SFX, LOOPS]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	var n := 0
	for b in BEDS:
		if _sourced(AMB, b[0]): continue
		_write_bed(b[0], b[1], b[2], b[3]); n += 1
	var l := 0
	for d in DRIVEN:
		if _sourced(LOOPS, d[0]): continue
		_write_driven(d[0], d[1], d[2], d[3]); l += 1
	var o_count := 0
	for o in ONESHOTS:
		if _sourced(SFX, o[0]): continue
		_write_oneshot(o[0], o[1], o[2], o[3], o[4], o[5]); o_count += 1
	print("placeholders written: %d beds, %d loops, %d one-shot defs" % [n, l, o_count])
	if not _skipped.is_empty():
		print("left alone (already sourced): %s" % ", ".join(_skipped))
	quit()

## A sound that has a real recording next to it is NEVER regenerated. Without this, running the
## generator after sourcing silently reverts the def to the placeholder and resurrects the .res —
## which is exactly what happened once. The sourced file is the source of truth.
func _sourced(dir: String, id: String) -> bool:
	for ext in ["wav", "ogg", "mp3"]:
		if FileAccess.file_exists("%s%s.%s" % [dir, id, ext]):
			_skipped.append(id)
			return true
	return false

# ---------------------------------------------------------------- writers
func _write_bed(id: String, db: float, seed_val: int, recipe: String) -> void:
	_rng.seed = seed_val
	var wav := _noise_loop(recipe, 4.0)
	ResourceSaver.save(wav, AMB + id + ".res")
	var def := AmbientDef.new()
	def.id = id
	def.stream = load(AMB + id + ".res") as AudioStream
	def.volume_db = db
	def.fade_time = 2.0
	ResourceSaver.save(def, AMB + id + ".tres")

func _write_driven(id: String, seed_val: int, recipe: String, secs: float) -> void:
	_rng.seed = seed_val
	ResourceSaver.save(_noise_loop(recipe, secs), LOOPS + id + ".res")

func _write_oneshot(id: String, variants: int, bus: String, db: float, jitter: float, recipe: String) -> void:
	var streams: Array[AudioStream] = []
	for i in variants:
		_rng.seed = hash(id) % 100000 + i
		var wav := _wav(_oneshot(recipe, i))
		var path := SFX + (id if variants == 1 else "%s_%d" % [id, i + 1]) + ".res"
		ResourceSaver.save(wav, path)
		streams.append(load(path) as AudioStream)
	var def := SfxDef.new()
	def.streams = streams
	def.bus = bus
	def.volume_db = db
	def.pitch_min = 1.0 - jitter
	def.pitch_max = 1.0 + jitter
	ResourceSaver.save(def, SFX + id + ".tres")

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	s.data = data
	return s

## Seamless loop. Synth n+f samples, keep [0,n) as the body, then fade the HEAD in from the
## overhang [n, n+f): out[0] becomes the sample that naturally follows out[n-1], so the wrap is
## two consecutive samples rather than a step. (Fading the tail toward the head instead leaves the
## end wherever the head drifted to — audible as a click on the slow lowpassed beds.) sqrt weights
## hold energy flat where the two halves are uncorrelated.
##
## Engines pass through here too, and the crossfade is TRANSPARENT to them: their partials each
## complete a whole number of cycles in `secs`, so raw[n+k] == raw[k] exactly for the tonal part
## and only the white-noise component — which does not repeat, and ticks once per loop without
## this — actually gets blended.
func _noise_loop(recipe: String, secs: float) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var f := int(XFADE * RATE)
	var raw := _synth(recipe, n + f)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for k in f:
		var t := float(k) / f
		out[k] = raw[n + k] * sqrt(1.0 - t) + raw[k] * sqrt(t)
	return _looped(_wav(out), n)

func _looped(wav: AudioStreamWAV, n: int) -> AudioStreamWAV:
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

# ---------------------------------------------------------------- loop synthesis
# One-pole filtered white noise throughout: character comes from the cutoff (how bright), the LFO
# (how much it breathes) and which bands get mixed. Crude, but it reads as the right material.
func _synth(recipe: String, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var swell := 0.0
	var grit := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		match recipe:
			"rain", "rain_heavy":
				var heavy := recipe == "rain_heavy"
				lp += (w - lp) * 0.30
				var hiss := w - lp
				lp2 += (w - lp2) * 0.05
				var breathe := 1.0 + 0.10 * sin(TAU * 0.13 * t) + 0.06 * sin(TAU * 0.41 * t)
				out[i] = (hiss * (0.85 if heavy else 0.62) + lp2 * (1.1 if heavy else 0.5)) * breathe * 0.5
			"snow_wind":
				lp += (w - lp) * 0.020
				out[i] = lp * 3.2 * (1.0 + 0.35 * sin(TAU * 0.07 * t))
			"wind_light":
				lp += (w - lp) * 0.045
				lp2 += (w - lp2) * 0.011
				out[i] = (lp * 1.6 + lp2 * 2.0) * (1.0 + 0.30 * sin(TAU * 0.09 * t))
			"wind_low":
				lp += (w - lp) * 0.014
				out[i] = lp * 3.4 * (1.0 + 0.22 * sin(TAU * 0.05 * t))
			"crowd":
				lp += (w - lp) * 0.38
				lp2 += (w - lp2) * 0.055
				swell += (_rng.randf() - 0.5) * 0.004
				swell = clampf(swell, -0.35, 0.5)
				out[i] = (lp - lp2) * 1.5 * (1.0 + swell + 0.18 * sin(TAU * 0.19 * t))
			# --- engines: sawtooth-ish harmonic stack + firing-order pulse + broadband noise ---
			"engine_low", "engine_mid", "engine_high":
				var base := 45.0 if recipe == "engine_low" else (55.0 if recipe == "engine_mid" else 90.0)
				var parts := 8 if recipe == "engine_low" else (12 if recipe == "engine_mid" else 16)
				var v := 0.0
				for k in range(1, parts + 1):
					v += sin(TAU * base * k * t) / float(k)
				var fire := 0.75 + 0.25 * sin(TAU * base * 0.5 * t)   # half-order = 4-stroke firing
				out[i] = (v * 0.30 * fire + w * 0.05) * 0.9
			# --- tyres on surfaces ---
			"roll_asphalt":
				lp += (w - lp) * 0.22
				out[i] = (w - lp) * 0.55 + lp * 0.25
			"roll_gravel":
				# crackle: sparse impulses over a mid-band rumble = loose stones under the tread
				grit = grit * 0.82 + (1.0 if _rng.randf() < 0.02 else 0.0) * (_rng.randf() * 2.0 - 1.0)
				lp += (w - lp) * 0.30
				out[i] = grit * 0.85 + (w - lp) * 0.30 + lp * 0.30
			"roll_dirt":
				grit = grit * 0.88 + (1.0 if _rng.randf() < 0.012 else 0.0) * (_rng.randf() * 2.0 - 1.0)
				lp += (w - lp) * 0.14
				out[i] = grit * 0.5 + lp * 1.5
			"roll_sand":
				lp += (w - lp) * 0.10
				out[i] = lp * 2.2
			"roll_snow":
				lp += (w - lp) * 0.08
				out[i] = lp * 1.9 * (1.0 + 0.2 * sin(TAU * 3.0 * t))
			"roll_ice":
				lp += (w - lp) * 0.06
				out[i] = lp * 1.1 + sin(TAU * 420.0 * t) * 0.04   # faint ring: 420*2.0s = 840 cycles
			"skid_asphalt":
				# squeal = narrow resonance; 1100 and 6 Hz both complete whole cycles in 2.0 s
				lp += (w - lp) * 0.45
				var squeal := sin(TAU * 1100.0 * t + 0.8 * sin(TAU * 6.0 * t)) * 0.30
				out[i] = (w - lp) * 0.42 + squeal
			"skid_loose":
				grit = grit * 0.80 + (1.0 if _rng.randf() < 0.05 else 0.0) * (_rng.randf() * 2.0 - 1.0)
				lp += (w - lp) * 0.35
				out[i] = grit * 0.7 + (w - lp) * 0.45
			"scrape":
				grit = grit * 0.70 + (1.0 if _rng.randf() < 0.09 else 0.0) * (_rng.randf() * 2.0 - 1.0)
				lp += (w - lp) * 0.50
				out[i] = (grit * 0.9 + (w - lp) * 0.5) * (1.0 + 0.4 * sin(TAU * 11.0 * t))
	return out

# ---------------------------------------------------------------- one-shot synthesis
func _oneshot(recipe: String, variant: int) -> PackedFloat32Array:
	match recipe:
		"ui_click": return _tone(1250.0, 0.05, 0.5)
		"ui_move": return _tone(900.0, 0.035, 0.32)
		"ui_confirm": return _seq([[660.0, 0.07, 0.40], [990.0, 0.14, 0.45]])
		"ui_error": return _buzz(180.0, 0.18, 0.42)
		"ui_purchase": return _seq([[523.0, 0.07, 0.34], [659.0, 0.07, 0.36], [784.0, 0.20, 0.42]])
		"ui_unlock": return _seq([[523.0, 0.09, 0.34], [659.0, 0.09, 0.36], [784.0, 0.09, 0.38], [1046.0, 0.34, 0.46]])
		"checkpoint": return _seq([[660.0, 0.07, 0.40], [990.0, 0.14, 0.45]])
		"countdown_beep": return _tone(880.0, 0.18, 0.45)
		"countdown_go": return _tone(1318.0, 0.40, 0.55)
		"lap_best": return _seq([[784.0, 0.08, 0.36], [1046.0, 0.08, 0.38], [1318.0, 0.26, 0.44]])
		"finish_win": return _seq([[523.0, 0.11, 0.38], [659.0, 0.11, 0.40], [784.0, 0.11, 0.42], [1046.0, 0.45, 0.50]])
		"finish_lose": return _seq([[440.0, 0.14, 0.38], [370.0, 0.14, 0.36], [294.0, 0.45, 0.40]])
		"wrong_way": return _alarm(700.0, 520.0, 3, 0.1)
		"impact_light": return _hit(0.13, 0.20, 3.0, 120.0, 0.45)
		"impact_heavy": return _hit(0.34, 0.13, 1.6, 62.0, 0.75)
		"debris": return _debris(variant)
		"engine_start": return _engine_start()
		"engine_off": return _engine_off()
		"thunder": return _thunder(2.6 + variant * 0.7, 0.6 + variant * 0.25)
	return PackedFloat32Array()

## Decaying sine with a 2 ms attack (a hard start would click).
func _tone(freq: float, dur: float, amp: float, decay := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = pow(1.0 - float(i) / n, decay) * minf(t / 0.002, 1.0)
		out[i] = sin(TAU * freq * t) * amp * env
	return out

func _seq(notes: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for nt in notes:
		out.append_array(_tone(nt[0], nt[1], nt[2]))
	return out

## Odd harmonics only = hollow/square-ish, which reads as "wrong" for errors.
func _buzz(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env: float = pow(1.0 - float(i) / n, 1.2) * minf(t / 0.002, 1.0)
		var v := sin(TAU * freq * t) + sin(TAU * freq * 3.0 * t) / 3.0 + sin(TAU * freq * 5.0 * t) / 5.0
		out[i] = v * amp * env * 0.7
	return out

func _alarm(f1: float, f2: float, cycles: int, note: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in cycles:
		out.append_array(_tone(f1, note, 0.40, 0.6))
		out.append_array(_tone(f2, note, 0.40, 0.6))
	return out

## Lowpassed noise burst over a sine thump — the sine carries the weight, the noise the material.
func _hit(dur: float, lp_coef: float, decay: float, sub: float, sub_amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env: float = pow(1.0 - float(i) / n, decay)
		lp += ((_rng.randf() * 2.0 - 1.0) - lp) * lp_coef
		out[i] = (lp * 1.8 + sin(TAU * sub * t) * sub_amp) * env
	return out

## Several short clatters in a row — the ADR-003 cube burst scattering.
func _debris(variant: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(0.5 * RATE))
	for hit in 5 + variant:
		var start := int(_rng.randf() * 0.34 * RATE)
		var piece := _hit(0.07, 0.42, 4.0, 300.0 + _rng.randf() * 500.0, 0.25)
		for i in piece.size():
			if start + i < out.size():
				out[start + i] += piece[i] * 0.55
	return out

## Starter motor chugs, then the engine catches and settles.
func _engine_start() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var crank := int(0.9 * RATE)
	out.resize(crank)
	var lp := 0.0
	for i in crank:
		var t := float(i) / RATE
		lp += ((_rng.randf() * 2.0 - 1.0) - lp) * 0.25
		var chug := 0.5 + 0.5 * sin(TAU * 8.0 * t)   # the starter turning over
		out[i] = (lp * 1.2 + sin(TAU * 42.0 * t) * 0.4) * chug * 0.5
	var catch_n := int(0.8 * RATE)
	for i in catch_n:
		var t := float(i) / RATE
		var rpm := lerpf(120.0, 55.0, minf(t / 0.6, 1.0))   # flares, then drops to idle
		var v := 0.0
		for k in range(1, 10):
			v += sin(TAU * rpm * k * t) / float(k)
		out.append(v * 0.28 * minf(t / 0.05, 1.0))
	return out

func _engine_off() -> PackedFloat32Array:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / n
		var rpm := lerpf(55.0, 18.0, p * p)      # winds down, then dies
		var v := 0.0
		for k in range(1, 8):
			v += sin(TAU * rpm * k * t) / float(k)
		out[i] = v * 0.28 * (1.0 - p) * (1.0 - p)
	return out

## Crack (bright transient) over a long lowpassed rumble that swells and rolls off.
func _thunder(dur: float, crack: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		lp2 += (lp - lp2) * 0.02
		var crack_env: float = exp(-t * 26.0) * crack
		var rumble_env := (1.0 - exp(-t * 12.0)) * exp(-t * 1.5)
		var roll := 1.0 + 0.5 * sin(TAU * 0.9 * t) * exp(-t * 0.8)
		out[i] = clampf((w - lp) * crack_env + lp2 * 5.0 * rumble_env * roll, -1.0, 1.0) * 0.9
	return out
