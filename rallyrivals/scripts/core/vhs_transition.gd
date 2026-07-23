extends CanvasLayer
class_name VHSTransition
## The VHS channel-change scene transition (art-ui-transition) — Flow's default. A full-screen rect
## running vhs_transition.gdshader over the frame below; cover() ramps `progress` 0->1 (tear apart,
## collapse to black), Flow swaps the scene behind the black peak, reveal() ramps 1->0 (settle back).
## Same async cover()/reveal() contract as the old FadeTransition, so Flow.set_transition swaps it in.
## `strength` tracks the VHS filter intensity, so the accessibility off switch calms this to a plain
## fade cut.

const DUR := 0.28

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # transitions run during the (unpaused) swap
	layer = 80                                # above game + HUD, below the debug menu (100)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/vhs_transition.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

## Tear the current frame apart and collapse to black — call before swapping the scene.
func cover() -> void:
	_mat.set_shader_parameter("strength", VHSFilter.intensity)
	_mat.set_shader_parameter("progress", 0.0)
	_rect.visible = true
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, DUR)
	await tw.finished

## Settle the new frame back to clean — call after the swap.
func reveal() -> void:
	_mat.set_shader_parameter("strength", VHSFilter.intensity)
	var tw := create_tween()
	tw.tween_method(_set_progress, 1.0, 0.0, DUR)
	await tw.finished
	_rect.visible = false

func _set_progress(p: float) -> void:
	_mat.set_shader_parameter("progress", p)
