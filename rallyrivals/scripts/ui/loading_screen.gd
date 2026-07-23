extends CanvasLayer
class_name LoadingScreen
## Async-load cover for Flow (code-ui-loading). Flow shows this over the transition's black while a
## slow scene loads on a background thread, so the main thread never freezes and the player sees
## progress instead of a hang. Quick loads never trip it (Flow only shows it past a short threshold).
## Carries its own black in case it's ever shown without a transition behind it.

var _bar: ProgressBar
var _dots: Label
var _t := 0.0

func _ready() -> void:
	layer = 85                       # above the transition (80), below the debug menu (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_dots = Label.new()
	_dots.theme_type_variation = "OsdTitle"
	_dots.text = "LOADING"
	box.add_child(_dots)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 18)
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.show_percentage = false
	box.add_child(_bar)

func _process(dt: float) -> void:
	_t += dt                         # a little life on the label so a long load doesn't look frozen
	_dots.text = "LOADING" + ".".repeat(1 + (int(_t * 2.0) % 3))

func show_loading() -> void:
	_bar.value = 0
	_t = 0.0
	visible = true

func set_progress(p: float) -> void:
	_bar.value = clampf(p, 0.0, 1.0) * 100.0

func hide_loading() -> void:
	visible = false
