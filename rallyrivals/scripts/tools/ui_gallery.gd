extends Control
## UI theme gallery (art-ui-theme test bed). F6 this scene to see every themed control at once,
## under the menu-tier VHS filter (glitch on) — i.e. the actual broadcast-menu experience. Both
## registers are shown: the white-on-blue OSD chrome, and a mock telemetry scorebug row.
## Purely a test harness; not shipped.

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	# Full-screen blue OSD field behind everything.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.10, 0.50)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	add_child(scroll)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 28)
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	pad.add_child(col)

	# Header
	col.add_child(_label("BIG SAL'S SPEED NETWORK", "OsdTitle"))
	col.add_child(_label("UI THEME GALLERY  ·  press \\ for the VHS/debug menu", "OsdDim"))
	col.add_child(_rule())

	# Text register
	col.add_child(_label("TEXT", "OsdHead"))
	col.add_child(_label("Default label — white on blue, teletext register.", ""))
	col.add_child(_label("Cyan heading accent (OsdHead).", "OsdHead"))
	col.add_child(_label("Dim / secondary line (OsdDim).", "OsdDim"))

	# Buttons
	col.add_child(_rule())
	col.add_child(_label("BUTTONS  (hover / focus inverts to the white OSD cursor)", "OsdHead"))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	col.add_child(brow)
	brow.add_child(_button("RACE"))
	brow.add_child(_button("GARAGE"))
	var disabled := _button("LOCKED")
	disabled.disabled = true
	brow.add_child(disabled)
	var opt := OptionButton.new()
	opt.add_item("OFFICIALS")
	opt.add_item("WILDS")
	brow.add_child(opt)

	# Inputs
	col.add_child(_rule())
	col.add_child(_label("INPUTS", "OsdHead"))
	var le := LineEdit.new()
	le.placeholder_text = "enter driver tag…"
	le.custom_minimum_size.x = 320
	col.add_child(le)
	var c1 := CheckBox.new(); c1.text = "VHS filter"; c1.button_pressed = true
	col.add_child(c1)
	var c2 := CheckBox.new(); c2.text = "Invert steering"
	col.add_child(c2)
	var sl := HSlider.new()
	sl.min_value = 0; sl.max_value = 100; sl.value = 75
	sl.custom_minimum_size = Vector2(320, 24)
	col.add_child(_label("VHS intensity", "OsdDim"))
	col.add_child(sl)

	# Progress bars
	col.add_child(_rule())
	col.add_child(_label("PROGRESS  (CP toward boss, etc.)", "OsdHead"))
	for v in [30, 70, 100]:
		var pb := ProgressBar.new()
		pb.value = v
		pb.custom_minimum_size = Vector2(360, 22)
		col.add_child(pb)

	# Panels
	col.add_child(_rule())
	col.add_child(_label("PANELS", "OsdHead"))
	var pc := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_child(_label("PanelContainer — the OSD window box.", ""))
	inner.add_child(_label("Nested content sits inside the border.", "OsdDim"))
	pc.add_child(inner)
	col.add_child(pc)

	# Telemetry register (the scorebug — deliberately a different look)
	col.add_child(_rule())
	col.add_child(_label("TELEMETRY REGISTER  (the in-race scorebug — NOT blue chrome)", "OsdHead"))
	var telerow := HBoxContainer.new()
	telerow.add_theme_constant_override("separation", 14)
	col.add_child(telerow)
	telerow.add_child(_hud_panel("HudPanel", [_label("LAP 2/3", "HudTag")]))
	telerow.add_child(_hud_panel("HudPanelHot", [_label("0:48.20", "HudTimer"), _label("BEST 0:47.05", "HudBest")]))
	var spd := VBoxContainer.new()
	spd.add_child(_label("142", "HudValue"))
	spd.add_child(_label("KM/H", "HudUnit"))
	telerow.add_child(_hud_panel("HudPanel", [spd]))

	# Bottom spacer + the menu-tier tape filter on top.
	col.add_child(Control.new())
	var vhs := VHSFilter.new()
	vhs.name = "VHSFilter"
	vhs.glitch = 1.0   # menus/loading run the full unstable-tape look
	add_child(vhs)

func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = 130
	return b

func _hud_panel(variation: String, kids: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in kids:
		v.add_child(k)
	p.add_child(v)
	return p

func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.35)
	r.custom_minimum_size.y = 2
	return r
