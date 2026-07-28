class_name SlipstreamLines
extends CanvasLayer
## Screen speed-lines for the slipstream (art-vfx-slipstream): a full-screen ColorRect running the
## slipstream_lines shader — radial streaks that rush inward and intensify with draft strength. Sits
## over the world (and the VHS tape) but UNDER the HUD, so the scorebug stays crisp. The RaceDirector
## drives set_strength() each frame from the player's slip_intensity; at 0 it doesn't draw at all.

var _mat: ShaderMaterial
var _rect: ColorRect

func _ready() -> void:
	layer = 6                       # over world + VHS (5), under the HUD (50)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/slipstream_lines.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

func set_strength(s: float) -> void:
	_mat.set_shader_parameter("strength", s)
	_rect.visible = s > 0.001       # true off — no draw when you're not drafting
