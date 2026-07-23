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
const LOADING_AFTER_FRAMES := 6   # show the loading screen only if a load runs past ~0.1s

var _busy := false           # a goto() is mid-flight — guards against re-entrancy
var _pausable := false       # does the active scene accept the pause action?
var _loading: LoadingScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_transition(VHSTransition.new())
	_loading = LoadingScreen.new()
	add_child(_loading)

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
	if cover and _transition != null:
		await _transition.cover()
	# Load behind the black cover — threaded, so the main thread keeps ticking (loading screen can
	# animate) instead of freezing on a big track.
	var ps: PackedScene = target if target is PackedScene else await load_async(target)
	if ps == null:
		push_error("Flow.goto: could not resolve scene %s" % [target])
		if cover and _transition != null:
			await _transition.reveal()
		_busy = false
		return
	get_tree().change_scene_to_packed(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	scene_changed.emit(scene)
	# A scene that finishes building asynchronously (the race loads its track) can hold the reveal
	# until it's ready — otherwise the tape lifts on a half-built frame.
	if scene != null and scene.has_method("ready_to_reveal"):
		await scene.ready_to_reveal()
	if cover and _transition != null:
		await _transition.reveal()
	_busy = false

## Threaded scene load with a loading screen for slow loads (also used by scenes that stream their
## own content, e.g. the race track). Returns the PackedScene, or null on failure.
func load_async(path: String) -> PackedScene:
	if ResourceLoader.load_threaded_request(path) != OK:
		return load(path) as PackedScene          # unsupported/bad path — best-effort sync fallback
	var frames := 0
	var showing := false
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			if showing:
				_loading.hide_loading()
			return ResourceLoader.load_threaded_get(path) as PackedScene
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			frames += 1
			if not showing and frames >= LOADING_AFTER_FRAMES:
				showing = true
				_loading.show_loading()
			if showing:
				_loading.set_progress(progress[0] if progress.size() > 0 else 0.0)
			await get_tree().process_frame
		else:
			if showing:
				_loading.hide_loading()
			push_error("Flow.load_async: failed to load %s" % path)
			return null
	return null   # unreachable (the loop only exits via return) — satisfies the typed-return check

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
