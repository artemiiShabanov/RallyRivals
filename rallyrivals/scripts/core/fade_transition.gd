extends CanvasLayer
class_name FadeTransition
## Default screen transition for Flow: a full-screen black rect that fades to opaque (cover) then
## back (reveal). A transition is just any Node exposing async cover()/reveal() — art-ui-transition
## swaps in the VHS channel-change wipe by implementing the same two methods.

const DUR := 0.28

var _rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # runs during the (brief) swap regardless of pause
	layer = 80                                # above game + HUD, below the debug menu (100)
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)

## Fade to opaque — hides the old scene before the swap.
func cover() -> void:
	_rect.visible = true
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, DUR)
	await tw.finished

## Fade back to clear — reveals the new scene after the swap.
func reveal() -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, DUR)
	await tw.finished
	_rect.visible = false
