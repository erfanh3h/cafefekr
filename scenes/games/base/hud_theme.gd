class_name HudTheme
extends RefCounted

# Cafe Fekr — Warm Classic Parlor HUD Design System
# Unified palette, StyleBoxFlat builders, Theme factory, safe-area helper,
# and BiDi (Persian RTL / English LTR) typography utilities for all in-game HUDs.

# --- Core Warm Classic Parlor Palette ---
const COL_WALNUT_DEEP := Color("#1A110B")       # Modal / Drawer / Popover surface
const COL_WALNUT_ELEVATED := Color("#23160F")   # Elevated row / secondary card
const COL_LEATHER_ACTIVE := Color("#2D1C12")    # Active player card fill
const COL_LEATHER_IDLE := Color("#1B120C")      # Inactive player card fill
const COL_CARD_DISABLED := Color("#181513")     # Eliminated / Disconnected card

const COL_GOLD_BRUSHED := Color("#C99D4E")      # Subtle resting antique gold border
const COL_GOLD_ACTIVE := Color("#F5C451")       # Active turn warm gold highlight
const COL_AMBER_GLOW := Color("#E8A230")        # Soft active aura / shadow
const COL_BRONZE_MUTED := Color("#5A422B")      # Idle hairline border
const COL_TIMER_TRACK := Color("#120B07")       # Integrated progress bar track

const COL_DANGER := Color("#E04848")            # Low timer (<= 4s) / Surrender
const COL_DANGER_BG := Color("#381314")         # Urgent pill / button surface
const COL_EMERALD := Color("#3DB872")           # Positive / Confirmed / Live viewers
const COL_EMERALD_BG := Color("#122B1D")        # Positive pill surface

const COL_TEXT_IVORY := Color("#FBF3E4")        # Primary text (names, headings)
const COL_TEXT_SAND := Color("#C9B699")         # Secondary / muted text
const COL_TEXT_GOLD := Color("#FAD46B")         # Scores, counters, active timer
const COL_SHADOW_DARK := Color(0.04, 0.02, 0.01, 0.85)

# Subtle parlor seat accents (wax seal / dot markers — never loud neon fills)
const SEAT_ACCENTS: Dictionary = {
	1: Color("#D94E4E"), # Ruby Wax
	2: Color("#4E8FD9"), # Cobalt Ink
	3: Color("#3EAD6B"), # Parlor Emerald
	4: Color("#E8B838"), # Imperial Ochre
}

static var _font_display: FontFile = preload("res://assets/fonts/hekayat.ttf")
static var _font_ui: FontFile = preload("res://assets/fonts/Vazir.ttf")


static func get_display_font() -> FontFile:
	return _font_display


static func get_ui_font() -> FontFile:
	return _font_ui


static func get_seat_accent(player_idx: int) -> Color:
	return SEAT_ACCENTS.get(player_idx, COL_GOLD_ACTIVE)


static func fa_digits(val: Variant) -> String:
	var s := str(val)
	const FA := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += FA[int(ch)]
		else:
			out += ch
	return out


static func configure_bidi_label(lbl: Label, clip_with_ellipsis: bool = true) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.text_direction = Control.TEXT_DIRECTION_AUTO
	if clip_with_ellipsis:
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# Computes mobile-safe canvas insets (supports 9:16 and 9:19.5 tall notch displays)
static func get_safe_insets(viewport: Viewport) -> Dictionary:
	var result := {"top": 16, "bottom": 16, "left": 12, "right": 12}
	if viewport == null:
		return result
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return result
	var safe_rect := DisplayServer.get_display_safe_area()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return result
	var vp_rect := viewport.get_visible_rect()
	if vp_rect.size.x <= 0.0 or vp_rect.size.y <= 0.0:
		return result
	var scale_x: float = vp_rect.size.x / float(screen_size.x)
	var scale_y: float = vp_rect.size.y / float(screen_size.y)
	var top_px := int(ceil(float(safe_rect.position.y) * scale_y))
	var bottom_raw := int(ceil(float(screen_size.y - safe_rect.end.y) * scale_y))
	var left_px := int(ceil(float(safe_rect.position.x) * scale_x))
	var right_px := int(ceil(float(screen_size.x - safe_rect.end.x) * scale_x))
	result["top"] = clampi(maxi(14, top_px + 6), 14, 54)
	result["bottom"] = clampi(maxi(14, bottom_raw + 6), 14, 48)
	result["left"] = clampi(maxi(10, left_px + 8), 10, 28)
	result["right"] = clampi(maxi(10, right_px + 8), 10, 28)
	return result


# --- StyleBoxFlat Builders ---

static func is_mobile() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm and "is_mobile" in gm:
			return bool(gm.is_mobile)
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or (OS.get_name() in ["Android", "iOS"])

static func make_player_card_style(active: bool, is_danger: bool = false, compact: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.24, 0.09, 0.09, 0.96) if is_danger else Color(COL_LEATHER_ACTIVE.r, COL_LEATHER_ACTIVE.g, COL_LEATHER_ACTIVE.b, 0.96)
		sb.border_color = COL_DANGER if is_danger else COL_GOLD_ACTIVE
		sb.set_border_width_all(2)
		sb.border_width_bottom = 3
		var glow := COL_DANGER if is_danger else COL_AMBER_GLOW
		sb.shadow_color = Color(glow.r, glow.g, glow.b, 0.42 if is_danger else 0.34)
		sb.shadow_size = 0 if is_mobile() else 12
		sb.shadow_offset = Vector2(0, 3)
	else:
		sb.bg_color = Color(COL_LEATHER_IDLE.r, COL_LEATHER_IDLE.g, COL_LEATHER_IDLE.b, 0.86)
		sb.border_color = Color(COL_BRONZE_MUTED.r, COL_BRONZE_MUTED.g, COL_BRONZE_MUTED.b, 0.72)
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.shadow_size = 0 if is_mobile() else 5
		sb.shadow_offset = Vector2(0, 2)
	sb.set_corner_radius_all(14 if compact else 16)
	sb.content_margin_left = 8 if compact else 10
	sb.content_margin_right = 8 if compact else 10
	sb.content_margin_top = 5 if compact else 6
	sb.content_margin_bottom = 9 if compact else 11 # Reserves crisp clearance for bottom-docked timer bar
	return sb


static func make_disabled_card_style(compact: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_CARD_DISABLED.r, COL_CARD_DISABLED.g, COL_CARD_DISABLED.b, 0.68)
	sb.border_color = Color(0.32, 0.28, 0.25, 0.48)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14 if compact else 16)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.16)
	sb.shadow_size = 0 if is_mobile() else 3
	sb.content_margin_left = 8 if compact else 10
	sb.content_margin_right = 8 if compact else 10
	sb.content_margin_top = 5 if compact else 6
	sb.content_margin_bottom = 9 if compact else 11
	return sb


static func make_card_timer_track_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_TIMER_TRACK.r, COL_TIMER_TRACK.g, COL_TIMER_TRACK.b, 0.92)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	return sb


static func make_card_timer_fill_style(fill_col: Color = COL_GOLD_ACTIVE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = Color(1.0, 0.96, 0.84, 0.55)
	sb.border_width_top = 1
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	return sb


static func make_score_badge_style(state: String = "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if state == "pos":
		sb.bg_color = Color(COL_EMERALD_BG.r, COL_EMERALD_BG.g, COL_EMERALD_BG.b, 0.94)
		sb.border_color = Color(COL_EMERALD.r, COL_EMERALD.g, COL_EMERALD.b, 0.92)
	elif state == "neg":
		sb.bg_color = Color(COL_DANGER_BG.r, COL_DANGER_BG.g, COL_DANGER_BG.b, 0.94)
		sb.border_color = Color(COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 0.92)
	else:
		sb.bg_color = Color(0.08, 0.05, 0.03, 0.92)
		sb.border_color = Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


static func make_status_pill_style(accent: Color = COL_GOLD_BRUSHED, bg_alpha: float = 0.84) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.07, 0.04, bg_alpha)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


static func make_timer_chip_style(is_danger: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.07, 0.08, 0.96) if is_danger else Color(0.11, 0.07, 0.04, 0.94)
	sb.border_color = COL_DANGER if is_danger else Color(COL_GOLD_ACTIVE.r, COL_GOLD_ACTIVE.g, COL_GOLD_ACTIVE.b, 0.90)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


static func make_turn_toast_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_WALNUT_DEEP.r, COL_WALNUT_DEEP.g, COL_WALNUT_DEEP.b, 0.90)
	sb.border_color = Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	sb.shadow_size = 0 if is_mobile() else 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func make_floating_btn_style(state: String = "normal", active_highlight: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match state:
		"hover":
			sb.bg_color = Color(0.24, 0.16, 0.10, 0.96)
			sb.border_color = COL_GOLD_ACTIVE
		"pressed":
			sb.bg_color = Color(0.14, 0.09, 0.06, 0.98)
			sb.border_color = COL_GOLD_ACTIVE
		"disabled":
			sb.bg_color = Color(0.12, 0.09, 0.07, 0.55)
			sb.border_color = Color(0.42, 0.33, 0.22, 0.45)
		_:
			sb.bg_color = Color(0.22, 0.14, 0.09, 0.95) if active_highlight else Color(0.14, 0.09, 0.06, 0.92)
			sb.border_color = COL_GOLD_ACTIVE if active_highlight else Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.86)
	sb.set_border_width_all(2 if active_highlight or state != "normal" else 1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(15)
	sb.shadow_color = Color(COL_AMBER_GLOW.r, COL_AMBER_GLOW.g, COL_AMBER_GLOW.b, 0.34) if active_highlight else Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 0 if is_mobile() else (8 if active_highlight else 6)
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func apply_floating_button_style(btn: Button, active_highlight: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", make_floating_btn_style("normal", active_highlight))
	btn.add_theme_stylebox_override("hover", make_floating_btn_style("hover", active_highlight))
	btn.add_theme_stylebox_override("pressed", make_floating_btn_style("pressed", active_highlight))
	btn.add_theme_stylebox_override("disabled", make_floating_btn_style("disabled", false))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func make_rail_btn_style(state: String = "normal", active_highlight: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match state:
		"hover":
			sb.bg_color = Color(0.22, 0.14, 0.09, 0.94)
			sb.border_color = COL_GOLD_ACTIVE
		"pressed":
			sb.bg_color = Color(0.12, 0.08, 0.05, 0.96)
			sb.border_color = COL_GOLD_ACTIVE
		"disabled":
			sb.bg_color = Color(0.12, 0.09, 0.07, 0.45)
			sb.border_color = Color(0.42, 0.33, 0.22, 0.35)
		_:
			sb.bg_color = Color(0.20, 0.13, 0.08, 0.92) if active_highlight else Color(0.12, 0.08, 0.05, 0.84)
			sb.border_color = COL_GOLD_ACTIVE if active_highlight else Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.72)
	sb.set_border_width_all(2 if active_highlight else 1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(13)
	sb.shadow_color = Color(COL_AMBER_GLOW.r, COL_AMBER_GLOW.g, COL_AMBER_GLOW.b, 0.30) if active_highlight else Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 0 if is_mobile() else (6 if active_highlight else 4)
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func apply_rail_button_style(btn: Button, active_highlight: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", make_rail_btn_style("normal", active_highlight))
	btn.add_theme_stylebox_override("hover", make_rail_btn_style("hover", active_highlight))
	btn.add_theme_stylebox_override("pressed", make_rail_btn_style("pressed", active_highlight))
	btn.add_theme_stylebox_override("disabled", make_rail_btn_style("disabled", false))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func make_popover_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COL_WALNUT_DEEP.r, COL_WALNUT_DEEP.g, COL_WALNUT_DEEP.b, 0.96)
	sb.border_color = Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.92)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	sb.shadow_size = 0 if is_mobile() else 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_drawer_panel_style() -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = preload("res://assets/images/frames/dialog.png")
	sb.texture_margin_left = 44.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_bottom = 80.0
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 28.0
	sb.content_margin_bottom = 28.0
	return sb


static func make_drawer_item_btn_style(state: String = "normal", variant: String = "default") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if variant == "danger":
		match state:
			"hover":
				sb.bg_color = Color(0.38, 0.11, 0.12, 0.96)
				sb.border_color = Color(1.0, 0.45, 0.45, 1.0)
			"pressed":
				sb.bg_color = Color(0.24, 0.07, 0.08, 0.98)
				sb.border_color = COL_DANGER
			_:
				sb.bg_color = Color(0.28, 0.09, 0.10, 0.92)
				sb.border_color = Color(COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 0.85)
	elif variant == "primary":
		match state:
			"hover":
				sb.bg_color = Color(0.32, 0.22, 0.11, 0.98)
				sb.border_color = COL_GOLD_ACTIVE
			"pressed":
				sb.bg_color = Color(0.20, 0.13, 0.06, 0.98)
				sb.border_color = COL_GOLD_BRUSHED
			_:
				sb.bg_color = Color(0.25, 0.17, 0.09, 0.96)
				sb.border_color = COL_GOLD_ACTIVE
	else:
		match state:
			"hover":
				sb.bg_color = Color(0.24, 0.16, 0.10, 0.96)
				sb.border_color = COL_GOLD_ACTIVE
			"pressed":
				sb.bg_color = Color(0.14, 0.09, 0.06, 0.98)
				sb.border_color = COL_GOLD_BRUSHED
			_:
				sb.bg_color = Color(COL_WALNUT_ELEVATED.r, COL_WALNUT_ELEVATED.g, COL_WALNUT_ELEVATED.b, 0.94)
				sb.border_color = Color(COL_BRONZE_MUTED.r, COL_BRONZE_MUTED.g, COL_BRONZE_MUTED.b, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func apply_drawer_item_style(btn: Button, variant: String = "default") -> void:
	if not is_instance_valid(btn):
		return
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", make_drawer_item_btn_style("normal", variant))
	btn.add_theme_stylebox_override("hover", make_drawer_item_btn_style("hover", variant))
	btn.add_theme_stylebox_override("pressed", make_drawer_item_btn_style("pressed", variant))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _font_ui:
		btn.add_theme_font_override("font", _font_ui)
	btn.add_theme_font_size_override("font_size", 18)
	var text_col := Color(1.0, 0.86, 0.86) if variant == "danger" else (COL_TEXT_GOLD if variant == "primary" else COL_TEXT_IVORY)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COL_TEXT_GOLD)


static func make_emote_bubble_style(is_kori: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96) if is_kori else Color(0.14, 0.09, 0.05, 0.88)
	sb.border_color = COL_GOLD_ACTIVE if is_kori else Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.85)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(14 if is_kori else 22)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	sb.shadow_size = 0 if is_mobile() else (8 if is_kori else 12)
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 12 if is_kori else 8
	sb.content_margin_right = 12 if is_kori else 8
	sb.content_margin_top = 4 if is_kori else 8
	sb.content_margin_bottom = 4 if is_kori else 8
	return sb


static func build_theme() -> Theme:
	var theme := Theme.new()
	if _font_ui:
		theme.default_font = _font_ui
	theme.default_font_size = 18

	theme.set_stylebox("panel", "PanelContainer", make_player_card_style(false))
	theme.set_stylebox("normal", "Button", make_floating_btn_style("normal"))
	theme.set_stylebox("hover", "Button", make_floating_btn_style("hover"))
	theme.set_stylebox("pressed", "Button", make_floating_btn_style("pressed"))
	theme.set_stylebox("disabled", "Button", make_floating_btn_style("disabled"))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_color("font_color", "Button", COL_TEXT_IVORY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", COL_TEXT_GOLD)
	theme.set_color("font_color", "Label", COL_TEXT_IVORY)
	theme.set_color("font_shadow_color", "Label", COL_SHADOW_DARK)
	theme.set_constant("shadow_offset_y", "Label", 1)

	theme.set_stylebox("background", "ProgressBar", make_card_timer_track_style())
	theme.set_stylebox("fill", "ProgressBar", make_card_timer_fill_style(COL_GOLD_ACTIVE))
	return theme


# --- PlayerPod & CommonHUD v4 Helpers ---

static var _cached_ring_textures: Dictionary = {}
static var _cached_bottom_glow_tex: GradientTexture2D = null


static func format_seconds(seconds_left: float, use_fa: bool = true) -> String:
	var sec_int: int = maxi(0, int(ceil(seconds_left)))
	if use_fa:
		return "%sث" % fa_digits(sec_int)
	return "%ds" % sec_int


static func make_pod_style(active: bool, is_danger: bool = false, radius: int = 16, pad_h: int = 8, pad_v: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.24, 0.09, 0.09, 0.96) if is_danger else Color(COL_LEATHER_ACTIVE.r, COL_LEATHER_ACTIVE.g, COL_LEATHER_ACTIVE.b, 0.96)
		sb.border_color = COL_DANGER if is_danger else COL_GOLD_ACTIVE
		sb.set_border_width_all(2)
		sb.border_width_bottom = 3
		var glow := COL_DANGER if is_danger else COL_AMBER_GLOW
		sb.shadow_color = Color(glow.r, glow.g, glow.b, 0.44 if is_danger else 0.36)
		sb.shadow_size = 0 if is_mobile() else 10
		sb.shadow_offset = Vector2(0, 3)
	else:
		sb.bg_color = Color(COL_LEATHER_IDLE.r, COL_LEATHER_IDLE.g, COL_LEATHER_IDLE.b, 0.88)
		sb.border_color = Color(COL_BRONZE_MUTED.r, COL_BRONZE_MUTED.g, COL_BRONZE_MUTED.b, 0.78)
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		sb.shadow_size = 0 if is_mobile() else 5
		sb.shadow_offset = Vector2(0, 2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func make_spectator_pill_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.07, 0.04, 0.90)
	sb.border_color = Color(COL_GOLD_BRUSHED.r, COL_GOLD_BRUSHED.g, COL_GOLD_BRUSHED.b, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 0 if is_mobile() else 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


static func make_local_turn_bar_track_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.04, 0.84)
	sb.border_color = Color(COL_BRONZE_MUTED.r, COL_BRONZE_MUTED.g, COL_BRONZE_MUTED.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


static func make_local_turn_bar_fill_style(is_danger: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var col := COL_DANGER if is_danger else COL_GOLD_ACTIVE
	sb.bg_color = col
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.55)
	sb.shadow_size = 0 if is_mobile() else 6
	return sb


static func make_local_turn_pill_style(is_danger: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.08, 0.09, 0.94) if is_danger else Color(COL_WALNUT_DEEP.r, COL_WALNUT_DEEP.g, COL_WALNUT_DEEP.b, 0.92)
	sb.border_color = COL_DANGER if is_danger else Color(COL_GOLD_ACTIVE.r, COL_GOLD_ACTIVE.g, COL_GOLD_ACTIVE.b, 0.90)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(13)
	sb.shadow_color = Color(COL_AMBER_GLOW.r, COL_AMBER_GLOW.g, COL_AMBER_GLOW.b, 0.28)
	sb.shadow_size = 0 if is_mobile() else 8
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	return sb


static func get_radial_ring_texture(diameter: int = 128, thickness: float = 9.0) -> ImageTexture:
	var key: String = "%d_%.1f" % [diameter, thickness]
	if _cached_ring_textures.has(key):
		return _cached_ring_textures[key] as ImageTexture

	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center: float = (float(diameter) - 1.0) * 0.5
	var outer_r: float = float(diameter) * 0.5 - 1.5
	var inner_r: float = maxf(2.0, outer_r - thickness)
	var aa: float = 1.35

	for y in range(diameter):
		var dy: float = float(y) - center
		for x in range(diameter):
			var dx: float = float(x) - center
			var dist: float = sqrt(dx * dx + dy * dy)
			var alpha_outer: float = clampf((outer_r - dist) / aa + 0.5, 0.0, 1.0)
			var alpha_inner: float = clampf((dist - inner_r) / aa + 0.5, 0.0, 1.0)
			var alpha: float = minf(alpha_outer, alpha_inner)
			if alpha > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			else:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cached_ring_textures[key] = tex
	return tex


static func make_bottom_edge_glow_texture() -> GradientTexture2D:
	if _cached_bottom_glow_tex != null:
		return _cached_bottom_glow_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(0.960784, 0.768627, 0.317647, 0.30),
		Color(0.909804, 0.635294, 0.188235, 0.14),
		Color(0.909804, 0.635294, 0.188235, 0.04),
		Color(0.909804, 0.635294, 0.188235, 0.0),
	])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 64
	gtex.height = 128
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 1.0)
	gtex.fill_to = Vector2(0.5, 0.0)
	_cached_bottom_glow_tex = gtex
	return gtex

