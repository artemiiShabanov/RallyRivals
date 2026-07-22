extends SceneTree
## Builds the shared UI theme (art-ui-theme): assets/ui/theme.tres, set as the project default.
## Ultra-simple white-on-blue VCR-OSD (GDD §9): flat blue fields, white text, NO borders. The
## selected menu item inverts to a white field with blue text — the OSD cursor. One accent: white.
## The in-race TELEMETRY register (Hud* variations + HudPanel) stays clean white-on-dark, distinct
## from the blue chrome, so the scorebug reads as broadcast graphics not a menu.
## Font: first .ttf/.otf in assets/fonts/ (README there), else the engine default.
## Run: godot --headless --script res://scripts/tools/gen_ui_theme.gd

const OUT := "res://assets/ui/theme.tres"
const FONTS := "res://assets/fonts/"
const EMBOLDEN := 0.35

# --- palette: white on electric blue, nothing else ---
const BLUE := Color(0.10, 0.22, 0.95)      # electric OSD field
const BLUE_DK := Color(0.05, 0.11, 0.60)   # recessed field (buttons/inputs/tracks)
const WHITE := Color(0.95, 0.97, 1.0)
const DIM := Color(0.62, 0.68, 0.92)       # disabled / secondary (a muted white-blue)
const SEL_FG := Color(0.05, 0.10, 0.55)    # blue text on the white cursor
# telemetry (scorebug)
const TELE_DARK := Color(0.02, 0.02, 0.04, 0.68)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/"))
	var t := Theme.new()
	var font := _find_font()
	if font != null:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.variation_embolden = EMBOLDEN
		t.default_font = fv
	t.default_font_size = 22

	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("outline_size", "Label", 3)

	# Panels: flat blue field, no border.
	t.set_stylebox("panel", "PanelContainer", _fill(BLUE))
	t.set_stylebox("panel", "Panel", _fill(BLUE))

	# Buttons: OSD menu items. Idle = recessed field; hover/press/FOCUS invert to the white cursor
	# (focus carries the highlight since there are no borders to mark it).
	var cursor := _fill(WHITE)
	t.set_stylebox("normal", "Button", _fill(BLUE_DK))
	t.set_stylebox("hover", "Button", cursor)
	t.set_stylebox("pressed", "Button", cursor)
	t.set_stylebox("focus", "Button", cursor)
	t.set_stylebox("disabled", "Button", _fill(BLUE_DK.darkened(0.35)))
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", SEL_FG)
	t.set_color("font_pressed_color", "Button", SEL_FG)
	t.set_color("font_focus_color", "Button", SEL_FG)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", 24)

	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	t.set_color("font_color", "OptionButton", WHITE)
	t.set_color("font_hover_color", "OptionButton", SEL_FG)

	# LineEdit — recessed field, brighter when focused (no border to signal it).
	t.set_stylebox("normal", "LineEdit", _fill(BLUE_DK))
	t.set_stylebox("focus", "LineEdit", _fill(BLUE_DK.lightened(0.12)))
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("caret_color", "LineEdit", WHITE)
	t.set_color("selection_color", "LineEdit", Color(1, 1, 1, 0.30))

	t.set_color("font_color", "CheckBox", WHITE)
	t.set_color("font_hover_color", "CheckBox", WHITE)
	t.set_color("font_pressed_color", "CheckBox", WHITE)
	t.set_color("font_disabled_color", "CheckBox", DIM)

	t.set_stylebox("slider", "HSlider", _bar(BLUE_DK))
	t.set_stylebox("grabber_area", "HSlider", _bar(WHITE))
	t.set_stylebox("grabber_area_highlight", "HSlider", _bar(WHITE))

	t.set_stylebox("background", "ProgressBar", _fill(BLUE_DK))
	t.set_stylebox("fill", "ProgressBar", _fill(WHITE))
	t.set_color("font_color", "ProgressBar", WHITE)

	# chrome label variations (all white now — size is the only distinction)
	_var(t, "OsdTitle", 44, WHITE, 4)
	_var(t, "OsdHead", 28, WHITE, 3)
	_var(t, "OsdDim", 18, DIM, 2)

	# telemetry / scorebug register (white-on-dark, kept distinct from the chrome)
	_var(t, "HudValue", 68, WHITE, 8)
	_var(t, "HudUnit", 20, WHITE, 5)
	_var(t, "HudTimer", 44, WHITE, 7)
	_var(t, "HudBest", 18, WHITE, 4)
	_var(t, "HudTag", 28, WHITE, 6)
	_var(t, "HudSplit", 32, WHITE, 7)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", _fill(TELE_DARK))
	t.set_type_variation("HudPanelHot", "PanelContainer")
	t.set_stylebox("panel", "HudPanelHot", _fill(TELE_DARK))

	ResourceSaver.save(t, OUT)
	_set_project_default()
	print("VHS-OSD theme -> %s   font: %s" % [OUT, font.resource_path if font != null else "(default fallback)"])
	quit()

func _find_font() -> FontFile:
	var da := DirAccess.open(FONTS)
	if da != null:
		for f in da.get_files():
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				var fnt := load(FONTS + f)
				if fnt is FontFile:
					# Crisp bitmap rendering — DotGothic16 (and any pixel font) blurs to mush with
					# antialiasing on. Swap these two lines back to GRAY / AUTO for a smooth font.
					fnt.antialiasing = TextServer.FONT_ANTIALIASING_NONE
					fnt.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
					return fnt
	return null

# Flat filled box, no border, hard corners — the OSD field / menu item.
func _fill(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

func _bar(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

func _var(t: Theme, name: String, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_color("font_outline_color", name, Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", name, outline)

func _set_project_default() -> void:
	ProjectSettings.set_setting("gui/theme/custom", OUT)
	ProjectSettings.save()
