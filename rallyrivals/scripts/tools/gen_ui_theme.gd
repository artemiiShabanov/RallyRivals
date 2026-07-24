extends SceneTree
## Builds the shared UI theme (art-ui-theme): assets/ui/theme.tres, set as the project default.
## Ultra-simple white-on-blue VCR-OSD (GDD §9): flat blue fields, white text, NO borders. The
## selected menu item inverts to a white field with blue text — the OSD cursor. One accent: white.
## The in-race HUD (Hud* variations) uses NEUTRAL TRANSLUCENT GREY rather than the blue chrome:
## it is broadcast furniture laid over a live picture, so it must not compete with the road. Same
## hard corners and pixel font as the menus, just a quieter field.
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
# HUD: neutral translucent greys, so the readouts sit OVER the world instead of competing with it.
# (The menus keep the electric blue; the race screen wants the road to stay the loudest thing.)
const HUD_GRAY := Color(0.07, 0.08, 0.10, 0.55)     # race-details panel
const HUD_STRIP := Color(0.07, 0.08, 0.10, 0.72)    # bottom info strip, slightly firmer to carry text
const HUD_ROW_HOT := Color(0.95, 0.97, 1.0, 0.18)   # the player's own leaderboard row

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/"))
	var t := Theme.new()
	var font := _find_font()
	if font != null:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.variation_embolden = EMBOLDEN
		t.default_font = fv
	t.default_font_size = 24   # chrome is one uniform size (= Button) — flat teletext look

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

	# chrome label variations — all one uniform size (= Button), per the flat-teletext look; they
	# differ only by colour now (OsdDim is muted).
	_var(t, "OsdTitle", 24, WHITE, 3)
	_var(t, "OsdHead", 24, WHITE, 3)
	_var(t, "OsdDim", 24, DIM, 3)

	# telemetry / scorebug register (white-on-dark, kept distinct from the chrome)
	_var(t, "HudValue", 32, WHITE, 5)    # speed numerals (was 46 — 30% down)
	_var(t, "HudUnit", 16, DIM, 4)
	# Lap and clock share ONE face and sit on one line, so the top row reads as a single statement
	# rather than two competing readouts.
	_var(t, "HudTimer", 21, WHITE, 4)
	_var(t, "HudBest", 16, DIM, 4)
	_var(t, "HudTag", 21, WHITE, 4)      # lap counter — same size as HudTimer by design
	_var(t, "HudRow", 18, WHITE, 4)      # a leaderboard line
	_var(t, "HudSplit", 20, WHITE, 4)    # the bottom strip's message

	# Race details: flat translucent grey, hard corners, tight margins.
	t.set_type_variation("HudPanel", "PanelContainer")
	var race_panel := _fill(HUD_GRAY)
	race_panel.content_margin_left = 12
	race_panel.content_margin_right = 12
	race_panel.content_margin_top = 8
	race_panel.content_margin_bottom = 8
	t.set_stylebox("panel", "HudPanel", race_panel)

	# The player's own row, lifted out of the field so you find yourself instantly in a 10-car list.
	t.set_type_variation("HudRowHot", "PanelContainer")
	var hot := _fill(HUD_ROW_HOT)
	hot.content_margin_left = 6
	hot.content_margin_right = 6
	hot.content_margin_top = 2
	hot.content_margin_bottom = 2
	t.set_stylebox("panel", "HudRowHot", hot)

	# Every other row: same metrics, no fill, so rows line up whether highlighted or not.
	t.set_type_variation("HudRowPlain", "PanelContainer")
	var plain := _fill(Color(0, 0, 0, 0))
	plain.content_margin_left = 6
	plain.content_margin_right = 6
	plain.content_margin_top = 2
	plain.content_margin_bottom = 2
	t.set_stylebox("panel", "HudRowPlain", plain)

	# Bottom info strip — full width, only on screen when it has something to say.
	t.set_type_variation("HudStrip", "Panel")
	t.set_stylebox("panel", "HudStrip", _fill(HUD_STRIP))

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
