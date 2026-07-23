class_name MenuScreen
extends Control
## Shared chrome for the OSD menu screens (title / slots / settings / career hub): a full-screen
## electric-blue field with the menu-tier VHS filter (glitch on) layered on top. Content is
## LEFT-ALIGNED against a margin and vertically centred — the VCR on-screen-display look.
## Subclasses fill the column by overriding _build(col); they must NOT define _ready (this one runs
## the scaffold, then calls _build).
##
## UI cues follow the debug-menu convention (audio-sfx-ui): ui_move on focus change, ui_confirm on a
## forward action, ui_click on back/plain. Cues are armed one frame after _build so the initial
## programmatic grab_focus doesn't chirp on entry.

const BG := Color(0.07, 0.16, 0.78)
const PAD_LEFT := 110
const PAD_EDGE := 64

var _sfx_armed := false

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAD_LEFT)
	margin.add_theme_constant_override("margin_right", PAD_EDGE)
	margin.add_theme_constant_override("margin_top", PAD_EDGE)
	margin.add_theme_constant_override("margin_bottom", PAD_EDGE)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	if _scrolls():
		# Long screens (settings) top-align inside a scroll view; follow_focus keeps keyboard and
		# gamepad navigation from walking off the bottom of the frame.
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		margin.add_child(sc)
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		sc.add_child(col)
	else:
		col.alignment = BoxContainer.ALIGNMENT_CENTER   # centre the stack vertically…
		margin.add_child(col)

	_build(col)                                       # …children hug the left edge (SHRINK_BEGIN)

	var vhs := VHSFilter.new()
	vhs.name = "VHSFilter"
	vhs.glitch = 1.0     # menus/loading run the full unstable-tape look
	add_child(vhs)

	await get_tree().process_frame
	_sfx_armed = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		play_cue("ui_click")
		_on_cancel()
		get_viewport().set_input_as_handled()

## Override to fill the left-aligned content column.
func _build(_col: VBoxContainer) -> void:
	pass

## Screens whose content can exceed the frame (settings) override this to scroll instead of centre.
func _scrolls() -> bool:
	return false

## ui_cancel / Esc handler — default does nothing; screens with a "back" override this.
func _on_cancel() -> void:
	pass

# --- audio ---

## Play a UI cue by SfxDef id (ui_move / ui_confirm / ui_click / ui_error / …).
func play_cue(id: String) -> void:
	if not _sfx_armed:
		return
	var def := load("res://assets/audio/sfx/%s.tres" % id) as SfxDef
	if def != null:
		Sfx.play(def)

## Give any button the standard cue wiring: ui_move when focus lands, `cue` when pressed.
func wire_button(b: Button, cue := "ui_confirm") -> Button:
	b.focus_entered.connect(func() -> void: play_cue("ui_move"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void: play_cue(cue))
	return b

# --- themed-control helpers (all left-aligned) ---

func heading(text: String, variation := "OsdTitle") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = SIZE_SHRINK_BEGIN
	return l

func menu_button(text: String, cue := "ui_confirm") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 0)
	b.size_flags_horizontal = SIZE_SHRINK_BEGIN
	return wire_button(b, cue)

func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c
