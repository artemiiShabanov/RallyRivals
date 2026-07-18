extends SceneTree
## Synthesizes the placeholder ambience beds + thunder cracks (filtered noise — CC0 by
## construction) and writes their AmbientDef/SfxDef resources. Real recordings replace the
## streams file-by-file (see docs/AUDIO.md) without touching any code.
##
## Beds are written as .res AudioStreamWAV (not .wav): the loop points live IN the resource, so
## they survive without an import round-trip and headless runs can load them immediately.
## Every sound uses a fixed RNG seed — regenerating produces identical bytes, so git stays quiet.
## Run: godot --headless --script res://scripts/tools/gen_ambient_sfx.gd

const AMB_DIR := "res://assets/audio/ambient/"
const SFX_DIR := "res://assets/audio/sfx/"
const RATE := 22050          ## beds are filtered noise — 11 kHz of bandwidth is plenty, half the bytes
const LOOP_SECS := 4.0
const XFADE := 0.35          ## tail crossfaded into the head so the loop seam is inaudible

var _rng := RandomNumberGenerator.new()

# id, volume_db, seed, kind
const BEDS := [
	["wind_light", -20.0, 11, "wind_light"],       # clear weather base
	["wind_low", -22.0, 12, "wind_low"],           # fog: still, muffled
	["rain", -14.0, 13, "rain"],
	["rain_heavy", -11.0, 14, "rain_heavy"],       # thunderstorm
	["snow_wind", -19.0, 15, "snow_wind"],
	["festival_crowd", -17.0, 16, "crowd"],        # venue bed (GDD: outlaw festival)
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AMB_DIR))
	for b in BEDS:
		_write_bed(b[0], b[1], b[2], b[3])
	_write_thunder()
	quit()

func _write_bed(id: String, db: float, seed_val: int, kind: String) -> void:
	_rng.seed = seed_val
	var n := int(LOOP_SECS * RATE)
	var f := int(XFADE * RATE)
	var raw := _synth(kind, n + f)
	# Seamless loop: synth n+f samples, keep [0,n) as the body, then fade the HEAD in from the
	# overhang [n, n+f). out[0] becomes raw[n], which is the sample that naturally follows
	# out[n-1] = raw[n-1] — so the wrap is two consecutive samples, not a step. (Fading the tail
	# toward the head instead leaves the end wherever the head drifted to: audible on the slow
	# lowpassed beds.) sqrt weights keep energy flat where the two are uncorrelated.
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for k in f:
		var t := float(k) / f
		out[k] = raw[n + k] * sqrt(1.0 - t) + raw[k] * sqrt(t)

	var wav := _wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	ResourceSaver.save(wav, AMB_DIR + id + ".res")

	var def := AmbientDef.new()
	def.id = id
	def.stream = load(AMB_DIR + id + ".res") as AudioStream
	def.volume_db = db
	def.fade_time = 2.0
	ResourceSaver.save(def, AMB_DIR + id + ".tres")
	print("bed: %-15s %.1fs  %s" % [id, LOOP_SECS, "%.0f dB" % db])

func _write_thunder() -> void:
	var streams: Array[AudioStream] = []
	for i in 2:
		_rng.seed = 20 + i
		var wav := _wav(_thunder(2.6 + i * 0.7, 0.6 + i * 0.25))
		ResourceSaver.save(wav, SFX_DIR + "thunder_%d.res" % (i + 1))
		streams.append(load(SFX_DIR + "thunder_%d.res" % (i + 1)) as AudioStream)
	var def := SfxDef.new()
	def.streams = streams
	def.bus = "SFX"
	def.volume_db = -3.0
	def.pitch_min = 0.88
	def.pitch_max = 1.12
	ResourceSaver.save(def, SFX_DIR + "thunder.tres")
	print("thunder: 2 variants")

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

# ---------- synthesis ----------
# All beds are one-pole filtered white noise; the character is in the cutoff (how bright), the
# LFO (how much it breathes) and the mix of bands. Crude, but it reads as the right weather.
func _synth(kind: String, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var swell := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _rng.randf() * 2.0 - 1.0
		match kind:
			"rain", "rain_heavy":
				var heavy := kind == "rain_heavy"
				lp += (w - lp) * 0.30
				var hiss := w - lp                      # highpass = the patter
				lp2 += (w - lp2) * 0.05                 # low rumble under it
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
				# Band-limited babble: the difference of two lowpasses leaves a voice-ish band,
				# with slow swells standing in for cheers.
				lp += (w - lp) * 0.38
				lp2 += (w - lp2) * 0.055
				swell += (_rng.randf() - 0.5) * 0.004
				swell = clampf(swell, -0.35, 0.5)
				var band := lp - lp2
				out[i] = band * 1.5 * (1.0 + swell + 0.18 * sin(TAU * 0.19 * t))
	return out

# Crack (bright transient) over a long lowpassed rumble that swells and rolls off.
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
		var roll := 1.0 + 0.5 * sin(TAU * 0.9 * t) * exp(-t * 0.8)   # thunder "rolls" as it decays
		out[i] = clampf((w - lp) * crack_env + lp2 * 5.0 * rumble_env * roll, -1.0, 1.0) * 0.9
	return out
