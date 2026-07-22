class_name VHSFilter
extends CanvasLayer
## The tape look (art-shader-vhs): a full-screen ColorRect running the VHS post-process over
## whatever's rendered below it. Drop one into a scene. Its `layer` decides what it wraps — put it
## BELOW the HUD (default 5, HUD is 50) so the road gets the tape but the telemetry scorebug stays
## crisp; put it high (above everything) for a menu/loading screen where the whole broadcast is on
## the tape.
##
## `intensity` is a static, so the settings slider and the debug menu drive every filter at once
## (0 = clean passthrough, the "off switch"). The world palette underneath is untouched — the tape
## only sits on top.

## 0 = off (clean), 1 = full. Settings + debug menu write this; all filters read it.
static var intensity := 0.55

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	if layer == 1:
		layer = 5   # default: over the world, under the HUD (layer 50) — scorebug stays crisp
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/vhs.gdshader")
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)

func _process(_dt: float) -> void:
	_mat.set_shader_parameter("intensity", intensity)
	_rect.visible = intensity > 0.001   # true off — no draw, no back-buffer copy, no cost
