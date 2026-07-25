extends Node
## Music (autoload). One track at a time on the Music bus, crossfaded on context change.
##
## Menu screens call `Music.play("menu")`; the race director plays the race-type track. It is
## IDEMPOTENT: asking for the track already playing is a no-op, so walking between menu screens
## (title → settings → hub …) never restarts the music. A context whose file is missing fades the
## current track to silence rather than erroring — so this plumbing is complete before any real
## `.ogg` exists. To add a track: drop `assets/audio/music/<id>.ogg` (import Loop on, Offset 0) and
## a `<id>.tres` MusicDef pointing at it; the matching context then plays it.
##
## Volume is the Music bus (already a settings slider); this only sets per-track level + fades.
## Runs on PROCESS_MODE_ALWAYS so music keeps playing, and keeps fading, under the pause menu.

const DIR := "res://assets/audio/music/"
const SILENT := -60.0

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer          # the currently-audible player
var _current := ""                      # requested context id (tracked even if its file is missing)
var _fades := {}                        # AudioStreamPlayer -> {from, to, t, dur, stop}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make_player()
	_b = _make_player()
	_active = _a

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = SILENT
	add_child(p)
	return p

## Switch to the music for `context` ("menu", "circuit", "sprint", …). Loads
## `assets/audio/music/<context>.tres`; if absent, fades the current track out.
func play(context: String) -> void:
	if context == _current:
		return
	_current = context
	var path := DIR + context + ".tres"
	var def := load(path) as MusicDef if ResourceLoader.exists(path) else null
	_switch_to(def)

## Fade everything out and forget the context (e.g. leaving to a cutscene).
func stop(fade := 1.5) -> void:
	_current = ""
	_fade_out(_a, fade)
	_fade_out(_b, fade)

func _switch_to(def: MusicDef) -> void:
	if def == null or def.stream == null:
		_fade_out(_active, 1.5)     # no track for this context — go quiet
		return
	var incoming := _b if _active == _a else _a
	_fade_out(_active, def.fade)
	incoming.stream = def.stream
	incoming.volume_db = SILENT
	incoming.play()
	_fades[incoming] = {from = SILENT, to = def.volume_db, t = 0.0, dur = maxf(def.fade, 0.01), stop = false}
	_active = incoming

func _fade_out(p: AudioStreamPlayer, dur: float) -> void:
	if not p.playing:
		return
	_fades[p] = {from = p.volume_db, to = SILENT, t = 0.0, dur = maxf(dur, 0.01), stop = true}

func _process(delta: float) -> void:
	if _fades.is_empty():
		return
	var done: Array = []
	for p in _fades:
		var f: Dictionary = _fades[p]
		f.t += delta
		var k := clampf(f.t / f.dur, 0.0, 1.0)
		p.volume_db = lerpf(f.from, f.to, k)
		if k >= 1.0:
			if f.stop:
				p.stop()
			done.append(p)
	for p in done:
		_fades.erase(p)
