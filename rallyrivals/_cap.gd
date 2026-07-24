extends Node
const DIR := "/private/tmp/claude-501/-Users-artemiishabanov-Documents-GitHub-RallyRivals/37b0a7dd-619d-4cd9-a860-5f6cb62b1e42/scratchpad/"
func _ready() -> void:
	for i in Save.SLOTS: Save.delete_slot(i)
	Save.new_game(0); Save.add_car("comet"); Save.add_car("tangent"); Save.select_car("comet")
	Save.active.money = 200000
	await _shot("res://scenes/ui/shop.tscn", "tw_backbottom_shop.png")
	await _shot("res://scenes/ui/garage.tscn", "tw_backbottom_garage.png")
	for i in Save.SLOTS: Save.delete_slot(i)
	get_tree().quit()
func _shot(scene: String, name: String) -> void:
	var s := (load(scene) as PackedScene).instantiate()
	add_child(s)
	for i in 26: await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size.y
	for b in _nodes(s):
		if b is Button and b.text == "BACK":
			print("[cap] ", name, " BACK bottom=", b.get_global_rect().end.y, " vp=", vp, " ok=", b.get_global_rect().end.y <= vp)
	get_viewport().get_texture().get_image().save_png(DIR + name)
	s.queue_free(); await get_tree().process_frame; await get_tree().process_frame
func _nodes(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children(): _nodes(c, out)
	return out
