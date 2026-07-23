extends Node
## Settings (autoloaded as "Settings") — persistence + application of the player's options
## (code-core-settings-apply). Backed by user://settings.cfg, loaded and applied once on boot so the
## game always starts in the configured state. Three groups:
##   audio  — per-bus linear volume (Master/Music/SFX/UI) -> Sfx.set_bus_volume
##   video  — VHS filter intensity (0 = the off switch, GDD §9 accessibility) + fullscreen
##   input  — remapped actions, serialised with var_to_str (same shape project.godot uses)
## Kept separate from Save: settings are global, career progress is per-slot.

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX", "UI"]
const REMAPPABLE := ["accelerate", "brake_reverse", "steer_left", "steer_right",
	"handbrake", "reset_car", "pause"]
const DEF_VHS := 0.75

var _cfg := ConfigFile.new()
var _dirty := false
var _defaults: Dictionary = {}    ## action -> Array[InputEvent] as shipped, for Reset Defaults

func _ready() -> void:
	for a in REMAPPABLE:
		if InputMap.has_action(a):
			_defaults[a] = InputMap.action_get_events(a).duplicate()
	_cfg.load(PATH)               # missing file is fine — every getter has a default
	apply_all()

func _exit_tree() -> void:
	save_all()

## Push every stored setting into the live engine state.
func apply_all() -> void:
	for b in BUSES:
		Sfx.set_bus_volume(b, get_bus(b))
	VHSFilter.intensity = get_vhs()
	_apply_fullscreen(get_fullscreen())
	_apply_input()

func save_all() -> void:
	if not _dirty:
		return
	_cfg.save(PATH)
	_dirty = false

# --- audio ---

func get_bus(bus: String) -> float:
	return float(_cfg.get_value("audio", bus, 1.0))

func set_bus(bus: String, linear: float) -> void:
	_cfg.set_value("audio", bus, linear)
	_dirty = true
	Sfx.set_bus_volume(bus, linear)

# --- video ---

func get_vhs() -> float:
	return float(_cfg.get_value("video", "vhs_intensity", DEF_VHS))

func set_vhs(v: float) -> void:
	_cfg.set_value("video", "vhs_intensity", v)
	_dirty = true
	VHSFilter.intensity = v

func get_fullscreen() -> bool:
	return bool(_cfg.get_value("video", "fullscreen", false))

func set_fullscreen(on: bool) -> void:
	_cfg.set_value("video", "fullscreen", on)
	_dirty = true
	_apply_fullscreen(on)

## Only touch the window when it actually needs changing — a blind windowed-set on boot would
## clobber the project's own launch mode (display/window/size/mode = maximized).
func _apply_fullscreen(on: bool) -> void:
	var cur := DisplayServer.window_get_mode()
	var is_fs := cur == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if on and not is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not on and is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

# --- input remap ---

## Human-readable label for an action's keyboard binding ("W", "SPACE", …).
func binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			return OS.get_keycode_string(code)
	return "—"

## Replace the action's keyboard binding, preserving its gamepad events.
func rebind(action: String, key: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	var kept: Array = []
	for e in InputMap.action_get_events(action):
		if not (e is InputEventKey):
			kept.append(e)                     # gamepad bindings survive a keyboard remap
	var ne := InputEventKey.new()
	ne.device = -1     # match the shipped bindings: any device, not just the one that typed it
	ne.physical_keycode = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	kept.push_front(ne)
	InputMap.action_erase_events(action)
	for e in kept:
		InputMap.action_add_event(action, e)
	var arr: Array = []
	for e in InputMap.action_get_events(action):
		arr.append(var_to_str(e))
	_cfg.set_value("input", action, arr)
	_dirty = true

func _apply_input() -> void:
	for a in REMAPPABLE:
		var arr: Variant = _cfg.get_value("input", a, null)
		if arr == null or not InputMap.has_action(a):
			continue
		InputMap.action_erase_events(a)
		for s in arr:
			var e: Variant = str_to_var(s)
			if e is InputEvent:
				InputMap.action_add_event(a, e)

## Wipe every stored option and restore the shipped input map.
func reset_defaults() -> void:
	_cfg.clear()
	for a in _defaults.keys():
		InputMap.action_erase_events(a)
		for e in _defaults[a]:
			InputMap.action_add_event(a, e)
	_dirty = true
	apply_all()
