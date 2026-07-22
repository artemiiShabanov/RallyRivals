extends CanvasLayer
## Debug toolkit (autoloaded as "DebugMenu"; debug builds only — frees itself in release).
## `\` opens a pause menu: up/down select, right/enter activate, left back, `\`/esc close.
## Hosts cheat actions (respawn at last checkpoint, reset to spawn), toggleable overlays
## (performance, vehicle state) and time scale. The game is PAUSED while the menu is open, so
## the arrow keys don't fight the steering inputs. Extend by adding entries in _menu().

var _open := false
var _stack: Array = []            # submenu stack (Arrays of item Dictionaries)
var _titles: PackedStringArray = []
var _sel := 0
var _huds := {"perf": false, "vehicle": false}

var _pending := Callable()   # action deferred to the physics step (see _activate)

var _panel: PanelContainer
var _list: VBoxContainer
var _title: Label
var _hud_label: Label

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 12)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 6)
	add_child(_hud_label)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 120)
	var vb := VBoxContainer.new()
	_title = Label.new()
	_title.modulate = Color(0.6, 0.8, 1.0)
	vb.add_child(_title)
	_list = VBoxContainer.new()
	vb.add_child(_list)
	var hint := Label.new()
	hint.text = "arrows navigate · enter run · \\ close"
	hint.modulate = Color(1, 1, 1, 0.45)
	vb.add_child(hint)
	_panel.add_child(vb)
	_panel.hide()
	add_child(_panel)

# The menu tree, rebuilt on open/refresh so labels reflect live state.
#   sub: Array  -> submenu    hud: String -> overlay toggle    run: Callable -> action (closes menu)
func _menu() -> Array:
	var current := _car()
	return [
		{"label": "Vehicle", "sub": [
			{"label": "Return to last checkpoint", "run": _respawn_checkpoint},
			{"label": "Reset to spawn", "run": _reset_car},
			{"label": "Car: %s" % (current.car.display_name if current != null and current.car != null else "?"), "sub": _car_menu()},
		]},
		{"label": "Overlays", "sub": [
			{"label": "Performance", "hud": "perf"},
			{"label": "Vehicle state", "hud": "vehicle"},
		]},
		{"label": "Lighting", "sub": _lighting_menu()},
		{"label": "Weather", "sub": _weather_menu()},
		{"label": "Audio", "sub": _audio_menu()},
		{"label": "VHS filter (%d%%)" % roundi(VHSFilter.intensity * 100.0), "sub": _vhs_menu()},
		{"label": "Font (compare)", "sub": _font_menu()},
		{"label": "Time scale (%sx)" % String.num(Engine.time_scale), "sub": [
			{"label": "0.25x", "run": func() -> void: Engine.time_scale = 0.25},
			{"label": "0.5x", "run": func() -> void: Engine.time_scale = 0.5},
			{"label": "1x", "run": func() -> void: Engine.time_scale = 1.0},
			{"label": "2x", "run": func() -> void: Engine.time_scale = 2.0},
		]},
	]

# ---------- input / navigation ----------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		_set_open(not _open)
	elif not _open:
		return
	elif event.is_action_pressed("ui_down", true):
		_sel = (_sel + 1) % (_stack.back() as Array).size(); _refresh(); _ui("ui_move")
	elif event.is_action_pressed("ui_up", true):
		_sel = (_sel - 1 + (_stack.back() as Array).size()) % (_stack.back() as Array).size(); _refresh(); _ui("ui_move")
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_left"):
		_back(); _ui("ui_click")
	elif event.is_action_pressed("ui_cancel"):
		_set_open(false)
	else:
		return
	get_viewport().set_input_as_handled()

func _set_open(v: bool) -> void:
	_open = v
	_panel.visible = v
	get_tree().paused = v
	if v:
		_stack = [_menu()]
		_titles = ["debug"]
		_sel = 0
		_refresh()

# The debug menu is the only navigable UI that exists, so it doubles as the audition harness for
# the UI cue set. Real menus (code-ui-*) call the same sounds.
func _ui(id: String) -> void:
	var def := load("res://assets/audio/sfx/%s.tres" % id) as SfxDef
	if def != null:
		Sfx.play(def)

func _activate() -> void:
	var it: Dictionary = (_stack.back() as Array)[_sel]
	_ui("ui_confirm" if it.has("sub") else "ui_click")
	if it.has("sub"):
		_stack.append(it["sub"])
		_titles.append(it["label"])
		_sel = 0
		_refresh()
	elif it.has("hud"):
		_huds[it["hud"]] = not _huds[it["hud"]]
		_refresh()
	elif it.has("run"):
		# Deferred to the physics step: space-state queries (the respawn ray) are only legal
		# there while physics runs on its own thread — and closing first resumes physics.
		_pending = it["run"]
		_set_open(false)

func _back() -> void:
	if _stack.size() > 1:
		_stack.pop_back()
		_titles.remove_at(_titles.size() - 1)
		_sel = 0
		_refresh()
	else:
		_set_open(false)

func _refresh() -> void:
	_title.text = "/".join(_titles)
	for c in _list.get_children():
		c.queue_free()
	var items: Array = _stack.back()
	for i in items.size():
		var it: Dictionary = items[i]
		var txt: String = it["label"]
		if it.has("hud"):
			txt = ("[x] " if _huds[it["hud"]] else "[ ] ") + txt
		if it.has("sub"):
			txt += "  >"
		var l := Label.new()
		l.text = ("> " if i == _sel else "   ") + txt
		if i == _sel:
			l.modulate = Color(1.0, 0.85, 0.3)
		_list.add_child(l)

# ---------- actions ----------
func _physics_process(_dt: float) -> void:
	if _pending.is_valid():
		var c := _pending
		_pending = Callable()
		c.call()

func _car() -> VehicleController:
	return get_tree().get_first_node_in_group("vehicles") as VehicleController

# Teleport the car onto the last gate it passed (the start line before any pass), facing the next
# gate, dropped onto the ground by a downward ray. The gate's own progress state is untouched.
func _respawn_checkpoint() -> void:
	var car := _car()
	var cps := get_tree().get_first_node_in_group("track_checkpoints") as TrackCheckpoints
	if car == null or cps == null:
		return
	var last: CheckpointGate = cps.last_gate(car)
	if last == null:
		return
	var fwd := car.global_transform.basis.z
	var nxt: CheckpointGate = cps.gate_node(cps.next_gate(car))
	if nxt != null and nxt != last:
		var d := nxt.global_position - last.global_position
		d.y = 0.0
		if d.length() > 0.1:
			fwd = d.normalized()
	var pos := last.global_position
	var hit := car.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 80.0, 1))
	if not hit.is_empty():
		pos = hit["position"]
	var right := Vector3.UP.cross(fwd).normalized()
	car.respawn_at(Transform3D(Basis(right, Vector3.UP, fwd), pos + Vector3.UP * 1.5))

func _reset_car() -> void:
	var car := _car()
	if car != null:
		car.reset()

# One entry per roster CarDef — pick to hot-swap the drive (A/B feel testing across the roster).
func _car_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/cars")
	if da != null:
		for f in da.get_files():
			if f.get_extension() == "tres":
				var def := load("res://assets/cars/".path_join(f)) as CarDef
				if def != null:
					out.append({"label": "%s  %s  (%s)" % [def.car_class, def.display_name, def.brand], "run": _swap_car.bind(def)})
	return out

# Time-of-day presets (assets/lighting) applied live to the current scene's env + sun.
func _lighting_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/lighting")
	if da != null:
		for f in da.get_files():
			if f.get_extension() == "tres":
				var preset := load("res://assets/lighting/".path_join(f)) as LightingPreset
				if preset != null:
					out.append({"label": preset.id, "run": _apply_lighting.bind(preset)})
	return out

func _apply_lighting(preset: LightingPreset) -> void:
	if preset.apply_in(get_tree().current_scene if get_tree().current_scene != null else get_tree().root):
		print("debug: lighting -> ", preset.id)
	else:
		print("debug: no WorldEnvironment/Sun in this scene")

# Weather presets (assets/weather) — find-or-create the scene's WeatherFX and apply.
func _weather_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/weather")
	if da != null:
		for f in da.get_files():
			if f.get_extension() == "tres":
				var preset := load("res://assets/weather/".path_join(f)) as WeatherPreset
				if preset != null:
					out.append({"label": preset.id, "run": _apply_weather.bind(preset)})
	return out

func _apply_weather(preset: WeatherPreset) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := scene.get_node_or_null("WeatherFX") as WeatherFX
	if fx == null:
		fx = WeatherFX.new()
		fx.name = "WeatherFX"
		scene.add_child(fx)
	fx.apply(preset)
	print("debug: weather -> ", preset.id)

# Audition every SfxDef (assets/audio/sfx) at the car + quick per-bus volume set.
func _audio_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/audio/sfx")
	if da != null:
		for f in da.get_files():
			if f.get_extension() == "tres":
				var def := load("res://assets/audio/sfx/".path_join(f)) as SfxDef
				if def != null:
					out.append({"label": "play " + f.get_basename(), "run": _play_sfx.bind(def)})
	out.append({"label": "Ambience (world bed)", "sub": _ambient_menu()})
	out.append({"label": "Driven loops (toggle on car)", "sub": _loops_menu()})
	for bus in ["Master", "Music", "SFX", "UI"]:
		out.append({"label": "%s vol (%d%%)" % [bus, roundi(Sfx.get_bus_volume(bus) * 100.0)], "sub": _bus_menu(bus)})
	return out

# Swap the venue bed live. The weather layer is owned by WeatherFX (use the Weather menu).
func _ambient_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/audio/ambient")
	if da != null:
		for f in da.get_files():
			if f.get_extension() == "tres":
				var def := load("res://assets/audio/ambient/".path_join(f)) as AmbientDef
				if def != null:
					out.append({"label": def.id, "run": _set_ambient.bind(def)})
	out.append({"label": "(silence)", "run": _set_ambient.bind(null)})
	return out

func _set_ambient(def: AmbientDef) -> void:
	var bed := AmbientBed.find_or_create(get_tree())
	if bed != null:
		bed.set_layer("world", def)
		print("debug: ambience -> ", def.id if def != null else "off")

# Audition the driven loops (assets/audio/loops) before their systems exist: toggles a looping
# 3D player on the car so engine/tyre placeholders can be heard while driving. The real wiring
# (throttle -> pitch, surface -> crossfade) belongs to audio-sfx-engine / audio-sfx-surface.
func _loops_menu() -> Array:
	var out: Array = []
	var da := DirAccess.open("res://assets/audio/loops")
	if da != null:
		for f in da.get_files():
			# .res while a sound is still a generated placeholder, .wav/.ogg once it's sourced.
			if f.get_extension() in ["res", "wav", "ogg"]:
				out.append({"label": f.get_basename(), "run": _toggle_loop.bind(f)})
	out.append({"label": "(stop all)", "run": _toggle_loop.bind("")})
	return out

func _toggle_loop(file: String) -> void:
	var car := _car()
	if car == null:
		return
	var id := file.get_basename()
	var node_name := "DebugLoop_" + id
	for c in car.get_children():
		if c.name.begins_with("DebugLoop_"):
			if id == "" or c.name == node_name:
				c.queue_free()
				if id != "":
					print("debug: loop off -> ", id)
					return
	if file == "":
		print("debug: all loops off")
		return
	var stream := load("res://assets/audio/loops/".path_join(file)) as AudioStream
	if stream == null:
		return
	var p := Sfx.attach_loop(car, stream)
	p.name = node_name
	p.play()
	print("debug: loop on -> ", id)

# Swap the UI font live to compare candidates (assets/fonts + assets/fonts/candidates). Sets the
# project theme's default_font, so every themed control re-renders. CRISP mode turns antialiasing
# off — pixel/bitmap fonts MUST render crisp or they blur into mush; smooth fonts want it on. Also
# adjusts weight (embolden). Pick a combo you like and it gets baked into gen_ui_theme.gd.
var _last_font_path := "res://assets/fonts/DotGothic16-Regular.ttf"
var _font_embolden := 0.2
var _font_crisp := true

func _font_menu() -> Array:
	var out: Array = []
	for dir in ["res://assets/fonts/", "res://assets/fonts/candidates/"]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				out.append({"label": f.get_basename(), "run": _set_font.bind(dir + f, _font_embolden, _font_crisp)})
	out.append({"label": "· AA: %s (toggle)" % ("crisp" if _font_crisp else "smooth"),
		"run": func() -> void: _set_font(_last_font_path, _font_embolden, not _font_crisp)})
	out.append({"label": "· weight: %.1f  (+)" % _font_embolden,
		"run": func() -> void: _set_font(_last_font_path, minf(_font_embolden + 0.2, 1.2), _font_crisp)})
	out.append({"label": "· weight: %.1f  (−)" % _font_embolden,
		"run": func() -> void: _set_font(_last_font_path, maxf(_font_embolden - 0.2, 0.0), _font_crisp)})
	return out

func _set_font(path: String, embolden: float, crisp: bool) -> void:
	_last_font_path = path
	_font_embolden = embolden
	_font_crisp = crisp
	var base := load(path) as FontFile
	var theme := load("res://assets/ui/theme.tres") as Theme
	if base == null or theme == null:
		return
	base.antialiasing = TextServer.FONT_ANTIALIASING_NONE if crisp else TextServer.FONT_ANTIALIASING_GRAY
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED if crisp else TextServer.SUBPIXEL_POSITIONING_AUTO
	base.clear_cache()   # force re-rasterisation at the new antialiasing
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = embolden
	theme.default_font = fv
	print("debug: font -> %s  (%s, weight %.1f)" % [path.get_file(), "crisp" if crisp else "smooth", embolden])

# Tune the tape look live. 0% is the true off switch (settings will expose the same dial).
func _vhs_menu() -> Array:
	var out: Array = []
	for pct in [0, 25, 40, 55, 75, 100]:
		out.append({"label": "%d%%" % pct, "run": func() -> void:
			VHSFilter.intensity = pct / 100.0
			print("debug: VHS -> %d%%" % pct)})
	# Preview the menu-only scrolling artifacts (rolling bar + tear) on the driving filter.
	out.append({"label": "Menu glitch (preview toggle)", "run": func() -> void:
		var v := get_tree().get_first_node_in_group("vhs_filter") as VHSFilter
		if v != null:
			v.glitch = 1.0 - v.glitch
			print("debug: VHS glitch -> %s" % v.glitch)})
	return out

func _bus_menu(bus: String) -> Array:
	var out: Array = []
	for pct in [0, 25, 50, 75, 100]:
		out.append({"label": "%d%%" % pct, "run": func() -> void: Sfx.set_bus_volume(bus, pct / 100.0)})
	return out

func _play_sfx(def: SfxDef) -> void:
	var car := _car()
	if car != null:
		Sfx.play_at(def, car.global_position)
	else:
		Sfx.play(def)
	print("debug: sfx -> ", def.resource_path.get_file())

func _swap_car(def: CarDef) -> void:
	var c := _car()
	if c != null:
		c.car = def
		c.apply_car_def()
		print("debug: now driving %s (%s %s)" % [def.display_name, def.brand, def.car_class])

# ---------- overlays ----------
func _process(_dt: float) -> void:
	var lines: PackedStringArray = []
	if _huds["perf"]:
		lines.append("fps %d  frame %.1f ms  physics %.1f ms" % [
			Performance.get_monitor(Performance.TIME_FPS),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		lines.append("nodes %d  objects %d  draw calls %d" % [
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	if _huds["vehicle"]:
		var car := _car()
		if car != null:
			lines.append("speed %.1f m/s (%.0f km/h)  yaw %.2f rad/s" % [
				car.linear_velocity.length(), car.get_forward_speed() * 3.6,
				car.angular_velocity.dot(car.global_transform.basis.y)])
			for w in car.get_children():
				if w is VehicleWheel3D:
					lines.append("  " + _wheel_line(w))
	_hud_label.text = "\n".join(lines)
	_hud_label.visible = not lines.is_empty()

func _wheel_line(w: VehicleWheel3D) -> String:
	var surf := "air"
	if w.is_in_contact():
		surf = "untagged"
		var body := w.get_contact_body()
		if body != null:
			if body.has_meta("surface"):
				surf = (body.get_meta("surface") as SurfaceType).id
			elif body.has_meta("surface_map"):
				var s: SurfaceType = (body.get_meta("surface_map") as SurfaceMap).surface_at(w.global_position.x, w.global_position.z)
				surf = s.id if s != null else "?"
	return "%s  grip %.1f  %s" % [w.name, w.wheel_friction_slip, surf]
