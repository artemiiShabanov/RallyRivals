extends CanvasLayer
## Pause menu (code-ui-pause). A global overlay driven by Flow's pause primitive: a scene opts in
## with Flow.pausable(true) (the race does), the pause action then toggles pause and this appears,
## dimming the frozen game with RESUME / RESTART / QUIT TO HUB. process_mode ALWAYS so it runs while
## the tree is paused; hidden everywhere else. Pressing the pause action again toggles it off via
## Flow, which also unpauses on any scene change (RESTART / QUIT), so this just follows the signal.

const DIM := Color(0.02, 0.04, 0.10, 0.72)

var _built := false
var _resume: Button

func _ready() -> void:
	layer = 90                        # above HUD (50) + race banner (60), below the debug menu (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Flow.pause_toggled.connect(func(paused: bool) -> void:
		if paused:
			_open()
		else:
			visible = false)

func _open() -> void:
	if not _built:
		_build()
	visible = true
	_resume.grab_focus()

func _build() -> void:
	_built = true
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP     # swallow clicks meant for the game beneath
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.theme_type_variation = "OsdTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sp := Control.new()
	sp.custom_minimum_size.y = 14
	box.add_child(sp)

	_resume = _button("RESUME", "ui_confirm")
	_resume.pressed.connect(func() -> void: Flow.set_paused(false))
	box.add_child(_resume)

	var restart := _button("RESTART", "ui_confirm")
	# Reloads the race scene (fresh countdown). It restarts the scene's own race — fine while there's
	# one race; a career map picking many will re-arm RaceDirector.pending here.
	restart.pressed.connect(func() -> void: Flow.reload())
	box.add_child(restart)

	var quit := _button("QUIT TO HUB", "ui_click")
	quit.pressed.connect(func() -> void: Flow.goto(Routes.CAREER_HUB))
	box.add_child(quit)

func _button(text: String, cue: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 0)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_entered.connect(func() -> void: Sfx.play(load("res://assets/audio/sfx/ui_move.tres") as SfxDef))
	b.pressed.connect(func() -> void: Sfx.play(load("res://assets/audio/sfx/%s.tres" % cue) as SfxDef))
	return b
