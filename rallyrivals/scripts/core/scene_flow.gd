extends Node
## Scene/flow manager (autoloaded as "Flow"). Owns the one active screen and swaps it behind a
## transition cover/reveal so scene loads never flash raw. goto(target) changes scene (a res:// path
## or a PackedScene); reload() re-enters the current scene (race restart); quit() exits. Callers
## fire-and-forget — the calling node is freed by the swap, so don't rely on code after `await goto`.
##
## Pause primitive: a scene opts in with pausable(true); the `pause` action then toggles
## get_tree().paused and emits pause_toggled — the pause *menu* UI is code-ui-pause. The transition
## visual is pluggable via set_transition(); it defaults to a black fade until art-ui-transition
## installs the VHS channel-change wipe.

signal scene_changed(scene: Node)
signal pause_toggled(paused: bool)

var _transition: Node        # any Node exposing async cover()/reveal()
var _busy := false           # a goto() is mid-flight — guards against re-entrancy
var _pausable := false       # does the active scene accept the pause action?

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_transition(FadeTransition.new())

func _unhandled_input(event: InputEvent) -> void:
	if _pausable and not _busy and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

## Change to another scene behind the transition. target: a res:// path or a PackedScene.
func goto(target: Variant, cover := true) -> void:
	if _busy:
		return
	_busy = true
	_pausable = false
	if get_tree().paused:               # never carry a pause across a scene change
		_set_paused(false)
	var ps := _resolve(target)
	if ps == null:
		push_error("Flow.goto: could not resolve scene %s" % [target])
		_busy = false
		return
	if cover and _transition != null:
		await _transition.cover()
	get_tree().change_scene_to_packed(ps)
	# change_scene_to_packed defers the swap to the end of the frame; two frames lands us past it
	# with the new scene's _ready already run.
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit(get_tree().current_scene)
	if cover and _transition != null:
		await _transition.reveal()
	_busy = false

## Reload the active scene — used by the race "restart" path.
func reload() -> void:
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path != "":
		await goto(cur.scene_file_path)

func quit() -> void:
	get_tree().quit()

# --- pause primitive (the menu that reacts is code-ui-pause) ---

func pausable(on: bool) -> void:
	_pausable = on

func toggle_pause() -> void:
	_set_paused(not get_tree().paused)

func set_paused(p: bool) -> void:
	_set_paused(p)

func is_paused() -> bool:
	return get_tree().paused

func _set_paused(p: bool) -> void:
	get_tree().paused = p
	pause_toggled.emit(p)

## Swap the transition visual (art-ui-transition). t: a Node exposing async cover()/reveal().
func set_transition(t: Node) -> void:
	if _transition != null and _transition.is_inside_tree():
		_transition.queue_free()
	_transition = t
	if t != null:
		add_child(t)

func _resolve(target: Variant) -> PackedScene:
	if target is PackedScene:
		return target
	if target is String:
		return load(target) as PackedScene
	return null
