extends SceneTree
## Synthesizes placeholder SFX (pure sine/noise — CC0 by construction) so the audio pipeline is
## audible before real sounds are sourced; the audio-sfx-* tasks replace them stream-by-stream.
## Writes assets/audio/sfx/*.wav, then on a SECOND run (after an import pass registers the wavs)
## the matching SfxDef .tres files.
## Run: godot --headless --script res://scripts/tools/gen_test_sfx.gd   (x2, --editor --quit between)

const DIR := "res://assets/audio/sfx/"
const RATE := 44100

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_save_wav("ui_click", _click())
	_save_wav("checkpoint", _chime())
	_save_wav("impact", _thud())
	_defs()
	quit()

func _save_wav(sname: String, samples: PackedFloat32Array) -> void:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	s.data = data
	s.save_to_wav(ProjectSettings.globalize_path(DIR + sname + ".wav"))
	print("wav: %s (%.0f ms)" % [sname, 1000.0 * samples.size() / RATE])

# name, bus, volume_db, pitch jitter (+-)
const SPECS := [
	["ui_click", "UI", -6.0, 0.0],
	["checkpoint", "SFX", -4.0, 0.03],
	["impact", "SFX", -2.0, 0.12],
]

func _defs() -> void:
	var wrote := 0
	for sp in SPECS:
		var wav: String = DIR + sp[0] + ".wav"
		if not ResourceLoader.exists(wav):
			continue
		var def := SfxDef.new()
		def.streams.append(load(wav) as AudioStream)
		def.bus = sp[1]
		def.volume_db = sp[2]
		def.pitch_min = 1.0 - sp[3]
		def.pitch_max = 1.0 + sp[3]
		ResourceSaver.save(def, DIR + sp[0] + ".tres")
		wrote += 1
	if wrote == 0:
		print("defs skipped — wavs not imported yet; run --headless --editor --quit, then rerun")
	else:
		print("defs: ", wrote)

# ---------- synthesis ----------
func _click() -> PackedFloat32Array:
	return _tone(1250.0, 0.05, 0.5)

func _chime() -> PackedFloat32Array:
	var a := _tone(660.0, 0.07, 0.4)
	a.append_array(_tone(990.0, 0.14, 0.45))
	return a

func _tone(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := pow(1.0 - float(i) / n, 2.0) * minf(t / 0.002, 1.0)   # decay + 2ms anti-click attack
		out[i] = sin(TAU * freq * t) * amp * env
	return out

func _thud() -> PackedFloat32Array:
	var n := int(0.16 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0   # one-pole lowpass keeps the noise burst woody instead of hissy
	for i in n:
		var t := float(i) / RATE
		var env := pow(1.0 - float(i) / n, 3.0)
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.18
		out[i] = (lp * 1.8 + sin(TAU * 70.0 * t) * 0.5) * env
	return out
