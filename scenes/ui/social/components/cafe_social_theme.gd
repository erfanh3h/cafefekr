class_name CafeSocialTheme
extends RefCounted

## Cafe Fekr — Antique Board-Game Club Social UI Component Library
## Provides cohesive dark walnut / mahogany surfaces, ornate gold/bronze frames,
## emerald highlights, crisp RTL Persian typography, and reusable social widgets.

const FONT_TITLE = preload("res://assets/fonts/hekayat.ttf")
const FONT_BODY = preload("res://assets/fonts/Vazir.ttf")

# Authentic Cafe Fekr Frames & UI Textures
const TEX_BOARD = preload("res://assets/images/frames/board.png")
const TEX_DIALOG2 = preload("res://assets/images/frames/dialog2.png")
const TEX_DIALOG3 = preload("res://assets/images/frames/dialog3.png")
const TEX_FRAME = preload("res://assets/images/frames/frame.png")
const TEX_FRAME2 = preload("res://assets/images/frames/frame2.png")
const TEX_FRAME3 = preload("res://assets/images/frames/frame3.png")
const TEX_FRAME4 = preload("res://assets/images/frames/frame4.png")
const TEX_BUTTON = preload("res://assets/images/frames/button.png")
const TEX_BUTTON2 = preload("res://assets/images/frames/button2.png")
const TEX_BUTTON3 = preload("res://assets/images/frames/button3.png")
const TEX_BUTTON4 = preload("res://assets/images/frames/button4.png")
const TEX_BUTTON5 = preload("res://assets/images/frames/button5.png")
const TEX_CLOSE = preload("res://assets/images/frames/close.png")
const TEX_ADD = preload("res://assets/images/frames/add.png")
const TEX_CHECK = preload("res://assets/images/frames/check.png")
const TEX_RIGHT = preload("res://assets/images/frames/right.png")
const TEX_REPLY = preload("res://assets/images/frames/reply.png")

# Authentic Cafe Fekr Icons & Badges
const ICO_REFRESH = preload("res://assets/icons/General/refresh.png")
const ICO_CUP = preload("res://assets/icons/General/cup.png")
const ICO_STAR = preload("res://assets/icons/General/star.png")
const ICO_COIN = preload("res://assets/icons/General/coin.png")
const ICO_EXP = preload("res://assets/icons/General/exp.png")
const ICO_RANK = preload("res://assets/icons/General/rank.png")
const ICO_RANKING = preload("res://assets/icons/General/ranking.png")
const ICO_MULTI_RANK = preload("res://assets/icons/General/multi-rank.png")
const ICO_LOBBY = preload("res://assets/icons/General/lobby.png")
const ICO_HISTORY = preload("res://assets/icons/General/history.png")
const ICO_SETTING = preload("res://assets/icons/General/setting.png")
const ICO_INFO = preload("res://assets/icons/General/info.png")
const ICO_WIN = preload("res://assets/icons/General/win.png")
const ICO_LOSE = preload("res://assets/icons/General/lose.png")
const ICO_FIRST = preload("res://assets/icons/General/first.png")
const ICO_SECOND = preload("res://assets/icons/General/second.png")
const ICO_THIRD = preload("res://assets/icons/General/third.png")
const ICO_SPARKLE = preload("res://assets/icons/General/sparkle.png")
const ICO_KING = preload("res://assets/icons/General/chess-king.png")
const ICO_QUEEN = preload("res://assets/icons/General/chess-queen.png")
const ICO_ARMY = preload("res://assets/icons/General/army.png")
const ICO_CANCEL = preload("res://assets/icons/General/cancel.png")
const ICO_CHECK = preload("res://assets/icons/General/check.png")

const BADGE_SCORE = preload("res://assets/images/badges/score.png")
const BADGE_LEVEL = preload("res://assets/images/badges/level.png")
const BADGE_CHAT = preload("res://assets/images/badges/chat.png")
const BADGE_BESTS = preload("res://assets/images/badges/bests.png")
const BADGE_PLUS = preload("res://assets/images/badges/plus.png")
const BADGE_LOBBY = preload("res://assets/images/badges/lobby.png")
const BADGE_RANK = preload("res://assets/images/badges/rank.png")

# Authentic Cutout UI Assets
const BADGE_SOCIAL = preload("res://assets/images/badges/social.png")

const CLAN_BADGES := [
	preload("res://assets/images/clans/badge_1.png"),
	preload("res://assets/images/clans/badge_2.png"),
	preload("res://assets/images/clans/badge_3.png"),
	preload("res://assets/images/clans/badge_4.png"),
	preload("res://assets/images/clans/badge_5.png"),
	preload("res://assets/images/clans/badge_6.png"),
	preload("res://assets/images/clans/badge_7.png"),
	preload("res://assets/images/clans/badge_8.png"),
	preload("res://assets/images/clans/badge_9.png"),
]

const TEX_STATUS_ONLINE = preload("res://assets/images/status/status_online.png")
const TEX_STATUS_IN_GAME = preload("res://assets/images/status/status_in_game.png")
const TEX_STATUS_IN_LOBBY = preload("res://assets/images/status/status_in_lobby.png")
const TEX_STATUS_IN_QUEUE = preload("res://assets/images/status/status_in_queue.png")
const TEX_STATUS_OFFLINE = preload("res://assets/images/status/status_offline.png")

const TEX_TAB_FRIENDS = preload("res://assets/images/social/tab_friends.png")
const TEX_TAB_CLANS = preload("res://assets/images/social/tab_clans.png")
const TEX_TAB_MESSAGES = preload("res://assets/images/social/tab_messages.png")
const TEX_TAB_NOTIFS = preload("res://assets/images/social/tab_notifs.png")

const TEX_FRIEND_ADD = preload("res://assets/images/social/friend_add.png")
const TEX_FRIEND_CANCEL = preload("res://assets/images/social/friend_cancel.png")
const TEX_FRIEND_REJECT = preload("res://assets/images/social/friend_reject.png")

# Rich Antique Palette (Dark Walnut / Mahogany + Aged Gold + Jewel Emerald)
const COL_IVORY := Color(0.99, 0.96, 0.88, 1.0)
const COL_WARM_CREAM := Color(0.91, 0.84, 0.72, 1.0)
const COL_MUTED_SAND := Color(0.74, 0.67, 0.56, 1.0)
const COL_GOLD_BRIGHT := Color(0.98, 0.83, 0.36, 1.0)
const COL_GOLD_ANTIQUE := Color(0.80, 0.61, 0.25, 0.95)
const COL_BRONZE_BORDER := Color(0.56, 0.41, 0.21, 0.88)
const COL_WALNUT_DEEP := Color(0.11, 0.07, 0.04, 0.96)
const COL_WALNUT_CARD := Color(0.16, 0.10, 0.06, 0.95)
const COL_MAHOGANY_CARD := Color(0.21, 0.13, 0.08, 0.96)
const COL_EMERALD_TEXT := Color(0.50, 0.92, 0.64, 1.0)
const COL_EMERALD_BG := Color(0.12, 0.27, 0.18, 0.96)
const COL_EMERALD_BORDER := Color(0.36, 0.78, 0.50, 0.92)
const COL_CRIMSON_TEXT := Color(0.98, 0.54, 0.52, 1.0)
const COL_CRIMSON_BG := Color(0.28, 0.10, 0.10, 0.95)

static var _shell_style_cache: StyleBoxTexture = null
static var _frame_banner_cache: StyleBoxTexture = null
static var _btn_cache: Dictionary = {}

# Profile Frame visual tiers (0..5)
const PROFILE_FRAMES := [
	{"id": 0, "name": "چوب کلاسیک", "border": Color(0.68, 0.52, 0.28, 0.95), "glow": Color(0, 0, 0, 0.45)},
	{"id": 1, "name": "برنز کافه", "border": Color(0.84, 0.55, 0.30, 1.0), "glow": Color(0.75, 0.45, 0.20, 0.35)},
	{"id": 2, "name": "طلای شاهانه", "border": Color(1.0, 0.85, 0.32, 1.0), "glow": Color(1.0, 0.82, 0.22, 0.45)},
	{"id": 3, "name": "زمرد سلطنتی", "border": Color(0.35, 0.90, 0.58, 1.0), "glow": Color(0.25, 0.85, 0.50, 0.45)},
	{"id": 4, "name": "یاقوت کبود", "border": Color(0.45, 0.80, 1.0, 1.0), "glow": Color(0.30, 0.70, 1.0, 0.45)},
	{"id": 5, "name": "لعل قهرمانان", "border": Color(0.98, 0.45, 0.55, 1.0), "glow": Color(0.95, 0.35, 0.45, 0.45)},
]

# Clan Emblem configurations (1..9)
const CLAN_EMBLEMS := [
	{"id": 1, "name": "پنجه شیر", "texture": preload("res://assets/images/clans/badge_1.png")},
	{"id": 2, "name": "قلعه کافه", "texture": preload("res://assets/images/clans/badge_2.png")},
	{"id": 3, "name": "شمشیر نبرد", "texture": preload("res://assets/images/clans/badge_3.png")},
	{"id": 4, "name": "نشان هدف", "texture": preload("res://assets/images/clans/badge_4.png")},
	{"id": 5, "name": "برگ زیتون", "texture": preload("res://assets/images/clans/badge_5.png")},
	{"id": 6, "name": "الماس درخشان", "texture": preload("res://assets/images/clans/badge_6.png")},
	{"id": 7, "name": "پیک شاهانه", "texture": preload("res://assets/images/clans/badge_7.png")},
	{"id": 8, "name": "گشنیز کهن", "texture": preload("res://assets/images/clans/badge_8.png")},
	{"id": 9, "name": "دل سرخ", "texture": preload("res://assets/images/clans/badge_9.png")},
]


static func create_board_shell_style() -> StyleBoxTexture:
	if _shell_style_cache != null:
		return _shell_style_cache
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_BOARD
	sb.texture_margin_left = 60.0
	sb.texture_margin_top = 60.0
	sb.texture_margin_right = 60.0
	sb.texture_margin_bottom = 60.0
	_shell_style_cache = sb
	return sb


static func create_header_banner_style() -> StyleBoxTexture:
	if _frame_banner_cache != null:
		return _frame_banner_cache
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME2
	sb.texture_margin_left = 40.0
	sb.texture_margin_top = 24.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 24.0
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_frame_banner_cache = sb
	return sb


static func create_card_style(
	bg: Color = COL_WALNUT_CARD,
	border: Color = COL_BRONZE_BORDER,
	corner: int = 18,
	border_w: int = 2,
	pad_x: float = 18.0,
	pad_y: float = 14.0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func create_highlight_card_style(is_emerald: bool = false) -> StyleBoxFlat:
	if is_emerald:
		return create_card_style(
			Color(0.11, 0.21, 0.15, 0.97),
			Color(0.45, 0.85, 0.58, 0.94),
			18, 2, 18.0, 14.0
		)
	return create_card_style(
		Color(0.20, 0.13, 0.07, 0.98),
		Color(0.92, 0.74, 0.30, 0.95),
		18, 2, 18.0, 14.0
	)


static func create_well_style(corner: int = 16, pad_x: float = 14.0, pad_y: float = 12.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.92)
	sb.border_color = Color(0.48, 0.35, 0.19, 0.78)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func create_input_style(focused: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.03, 0.96)
	sb.border_color = Color(0.96, 0.80, 0.34, 1.0) if focused else Color(0.62, 0.47, 0.25, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	return sb


static func make_title(
	txt: String,
	font_size: int = 32,
	col: Color = COL_GOLD_BRIGHT,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT,
	wrap: bool = false
) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_TITLE)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


static func make_body(
	txt: String,
	font_size: int = 22,
	col: Color = COL_WARM_CREAM,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT,
	wrap: bool = true
) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_BODY)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	l.add_theme_constant_override("shadow_outline_size", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


static func make_line_edit(
	placeholder: String,
	min_height: float = 64.0,
	font_size: int = 24,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, min_height)
	le.alignment = align
	le.add_theme_font_override("font", FONT_BODY)
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", COL_IVORY)
	le.add_theme_color_override("font_placeholder_color", Color(0.68, 0.60, 0.48, 0.78))
	le.add_theme_stylebox_override("normal", create_input_style(false))
	le.add_theme_stylebox_override("focus", create_input_style(true))
	return le


static func _get_flat_btn_style(variant: String, state: String, corner: int) -> StyleBoxFlat:
	var key := "%s_%s_%d" % [variant, state, corner]
	if _btn_cache.has(key):
		return _btn_cache[key]

	var bg := Color(0.24, 0.16, 0.09, 0.96)
	var border := Color(0.75, 0.58, 0.30, 0.90)
	match variant:
		"gold":
			bg = Color(0.56, 0.39, 0.11, 0.98)
			border = Color(0.98, 0.82, 0.34, 1.0)
		"emerald":
			bg = Color(0.14, 0.38, 0.23, 0.98)
			border = Color(0.46, 0.88, 0.58, 0.96)
		"crimson":
			bg = Color(0.46, 0.13, 0.13, 0.98)
			border = Color(0.92, 0.44, 0.42, 0.95)
		"sapphire":
			bg = Color(0.14, 0.29, 0.44, 0.98)
			border = Color(0.48, 0.78, 0.98, 0.95)
		"bronze":
			bg = Color(0.26, 0.17, 0.10, 0.96)
			border = Color(0.76, 0.58, 0.30, 0.88)
		"muted":
			bg = Color(0.16, 0.11, 0.07, 0.92)
			border = Color(0.44, 0.33, 0.20, 0.75)

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(corner)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0

	if state == "hover":
		sb.bg_color = bg.lightened(0.12)
		sb.border_color = border.lightened(0.15)
	elif state == "pressed":
		sb.bg_color = bg.darkened(0.14)
		sb.border_color = border
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 8.0
	elif state == "disabled":
		sb.bg_color = bg.darkened(0.35)
		sb.bg_color.a = 0.65
		sb.border_color = Color(border.r, border.g, border.b, 0.38)
	else:
		sb.bg_color = bg
		sb.border_color = border

	_btn_cache[key] = sb
	return sb


static func make_button(
	txt: String,
	variant: String = "emerald",
	min_size: Vector2 = Vector2(140, 56),
	font_size: int = 23,
	icon_tex: Texture2D = null,
	use_title_font: bool = false,
	corner: int = 14
) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT_TITLE if use_title_font else FONT_BODY)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", COL_IVORY)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_pressed_color", COL_WARM_CREAM)
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.60, 0.55, 0.65))
	b.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.92))
	b.add_theme_constant_override("shadow_offset_y", 2)
	b.add_theme_constant_override("shadow_outline_size", 2)

	b.add_theme_stylebox_override("normal", _get_flat_btn_style(variant, "normal", corner))
	b.add_theme_stylebox_override("hover", _get_flat_btn_style(variant, "hover", corner))
	b.add_theme_stylebox_override("pressed", _get_flat_btn_style(variant, "pressed", corner))
	b.add_theme_stylebox_override("focus", _get_flat_btn_style(variant, "hover", corner))
	b.add_theme_stylebox_override("disabled", _get_flat_btn_style(variant, "disabled", corner))

	# User requested removing ugly icons from sub buttons; text alone is clean and sufficient.
	# Only attach icon if button has NO text (pure icon button like refresh)
	if txt.is_empty() and icon_tex != null:
		b.icon = icon_tex
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(clampf(min_size.y * 0.48, 22.0, 34.0)))

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


static func make_wood_hero_button(
	txt: String,
	color_name: String = KenneyUI.COLOR_GREEN,
	min_size: Vector2 = Vector2(260, 96),
	font_size: int = 30
) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", font_size)
	KenneyUI.style_button(b, color_name)
	return b


static func get_nav_tab_texture(tab_id: String) -> Texture2D:
	match tab_id:
		"friends":
			return TEX_TAB_FRIENDS
		"clans":
			return TEX_TAB_CLANS
		"messages":
			return TEX_TAB_MESSAGES
		"notifs":
			return TEX_TAB_NOTIFS
		_:
			return TEX_TAB_FRIENDS


static func make_nav_tab(
	tab_id: String,
	badge_count: int = 0,
	is_active: bool = false
) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var empty_sb := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty_sb)
	b.add_theme_stylebox_override("hover", empty_sb)
	b.add_theme_stylebox_override("pressed", empty_sb)
	b.add_theme_stylebox_override("disabled", empty_sb)
	b.add_theme_stylebox_override("focus", empty_sb)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(holder)

	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.texture = get_nav_tab_texture(tab_id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_active:
		tr.modulate = Color(0.68, 0.65, 0.62, 0.88)
	else:
		tr.modulate = Color(1.0, 1.0, 1.0, 1.0)
	holder.add_child(tr)

	if is_active:
		var highlight_bar := ColorRect.new()
		highlight_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		highlight_bar.offset_top = -6
		highlight_bar.offset_bottom = -1
		highlight_bar.offset_left = 28
		highlight_bar.offset_right = -28
		highlight_bar.color = Color(0.42, 0.92, 0.60, 0.98)
		highlight_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(highlight_bar)

	if badge_count > 0:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -38
		badge.offset_top = 4
		badge.offset_right = -4
		badge.offset_bottom = 32
		var bst := StyleBoxFlat.new()
		bst.bg_color = Color(0.82, 0.18, 0.16, 0.98)
		bst.border_color = Color(1.0, 0.86, 0.42, 0.95)
		bst.set_border_width_all(2)
		bst.set_corner_radius_all(12)
		bst.content_margin_left = 6.0
		bst.content_margin_right = 6.0
		badge.add_theme_stylebox_override("panel", bst)
		var bl := Label.new()
		bl.text = GameManager.to_fa_num(badge_count) if badge_count <= 99 else "۹۹+"
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.add_theme_font_override("font", FONT_BODY)
		bl.add_theme_font_size_override("font_size", 16)
		bl.add_theme_color_override("font_color", COL_IVORY)
		badge.add_child(bl)
		holder.add_child(badge)

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


static func make_subtab(label_txt: String, is_active: bool = false, badge_count: int = 0) -> Button:
	var txt := label_txt
	if badge_count > 0:
		txt += " (%s)" % GameManager.to_fa_num(badge_count)
	var b := make_button(
		txt,
		"emerald" if is_active else "muted",
		Vector2(0, 52),
		21,
		null,
		false,
		13
	)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func make_ornate_section_header(title_txt: String, icon_tex: Texture2D = null, subtitle_txt: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.11, 0.06, 0.92)
	st.border_color = Color(0.76, 0.58, 0.24, 0.72)
	st.border_width_bottom = 2
	st.border_width_top = 1
	st.border_width_left = 1
	st.border_width_right = 1
	st.set_corner_radius_all(14)
	st.content_margin_left = 16.0
	st.content_margin_right = 16.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	p.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	text_col.add_child(make_title(title_txt, 28, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
	if not subtitle_txt.is_empty():
		text_col.add_child(make_body(subtitle_txt, 19, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	if icon_tex != null:
		var ico := TextureRect.new()
		ico.texture = icon_tex
		ico.custom_minimum_size = Vector2(36, 36)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ico)

	return p


static func make_avatar_badge(
	avatar_id: int,
	frame_id: int = 0,
	size_px: float = 84.0,
	presence_status: String = "",
	show_dot: bool = false
) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size_px, size_px)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var f_idx := clampi(frame_id, 0, PROFILE_FRAMES.size() - 1)
	var f_cfg: Dictionary = PROFILE_FRAMES[f_idx]

	var frame_panel := PanelContainer.new()
	frame_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_panel.clip_contents = true
	var fst := StyleBoxFlat.new()
	fst.bg_color = Color(0.10, 0.06, 0.03, 0.96)
	fst.border_color = f_cfg["border"]
	fst.set_border_width_all(3)
	fst.set_corner_radius_all(int(size_px * 0.22))
	fst.shadow_color = f_cfg["glow"]
	fst.shadow_size = 6
	fst.content_margin_left = 4.0
	fst.content_margin_right = 4.0
	fst.content_margin_top = 4.0
	fst.content_margin_bottom = 4.0
	frame_panel.add_theme_stylebox_override("panel", fst)
	holder.add_child(frame_panel)

	var av := TextureRect.new()
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var av_path := "res://assets/icons/Avatars/%d.png" % clampi(avatar_id, 0, 26)
	if ResourceLoader.exists(av_path):
		av.texture = load(av_path)
	frame_panel.add_child(av)

	if show_dot:
		var dot := PanelContainer.new()
		var dot_sz := clampf(size_px * 0.26, 16.0, 24.0)
		dot.custom_minimum_size = Vector2(dot_sz, dot_sz)
		dot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		dot.offset_left = -3
		dot.offset_top = -dot_sz + 3
		dot.offset_right = dot_sz - 3
		dot.offset_bottom = 3
		var dst := StyleBoxFlat.new()
		var p_info := format_presence({"status": presence_status})
		dst.bg_color = p_info["dot_color"]
		dst.border_color = Color(0.08, 0.05, 0.03, 1.0)
		dst.set_border_width_all(3)
		dst.set_corner_radius_all(int(dot_sz * 0.5))
		dot.add_theme_stylebox_override("panel", dst)
		holder.add_child(dot)

	return holder


static func get_clan_emblem_texture(emblem_id: int = 1) -> Texture2D:
	var idx := clampi(emblem_id - 1, 0, CLAN_BADGES.size() - 1)
	return CLAN_BADGES[idx]


static func make_clan_emblem(emblem_id: int = 1, size_px: float = 84.0) -> Control:
	var tex := get_clan_emblem_texture(emblem_id)
	var ico := TextureRect.new()
	var w := size_px * (88.0 / 108.0)
	ico.custom_minimum_size = Vector2(w, size_px)
	ico.texture = tex
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ico


static func get_status_texture(status: String) -> Texture2D:
	match status:
		"online":
			return TEX_STATUS_ONLINE
		"in_game":
			return TEX_STATUS_IN_GAME
		"in_lobby":
			return TEX_STATUS_IN_LOBBY
		"in_queue":
			return TEX_STATUS_IN_QUEUE
		_:
			return TEX_STATUS_OFFLINE


static func make_status_badge(status: String, custom_h: float = 34.0) -> Control:
	var tr := TextureRect.new()
	var w := custom_h * 2.4
	tr.custom_minimum_size = Vector2(w, custom_h)
	tr.texture = get_status_texture(status)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func get_friend_button_texture(type: String) -> Texture2D:
	match type:
		"add", "accept":
			return TEX_FRIEND_ADD
		"cancel", "remove":
			return TEX_FRIEND_CANCEL
		"reject":
			return TEX_FRIEND_REJECT
		_:
			return TEX_FRIEND_ADD


static func make_friend_button(
	type: String,
	label_txt: String = "",
	min_size: Vector2 = Vector2(0, 52)
) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var variant := "emerald"
	match type:
		"add", "accept":
			variant = "emerald"
		"cancel", "remove", "reject":
			variant = "crimson"

	b.add_theme_stylebox_override("normal", _get_flat_btn_style(variant, "normal", 14))
	b.add_theme_stylebox_override("hover", _get_flat_btn_style(variant, "hover", 14))
	b.add_theme_stylebox_override("pressed", _get_flat_btn_style(variant, "pressed", 14))
	b.add_theme_stylebox_override("focus", _get_flat_btn_style(variant, "hover", 14))
	b.add_theme_stylebox_override("disabled", _get_flat_btn_style(variant, "disabled", 14))

	b.custom_minimum_size = min_size

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	b.add_child(hbox)

	var ico := TextureRect.new()
	ico.texture = get_friend_button_texture(type)
	ico.custom_minimum_size = Vector2(38, 32)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(ico)

	if not label_txt.is_empty():
		var lbl := Label.new()
		lbl.text = label_txt
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", FONT_BODY)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", COL_IVORY)
		lbl.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.92))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_constant_override("shadow_outline_size", 2)
		hbox.add_child(lbl)

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


static func make_badge_pill(txt: String, text_col: Color = COL_GOLD_BRIGHT, bg_col: Color = Color(0.10, 0.06, 0.03, 0.94), border_col: Color = Color(0.75, 0.58, 0.25, 0.80), font_size: int = 19) -> PanelContainer:
	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 10.0
	st.content_margin_right = 10.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", st)
	pill.add_child(make_body(txt, font_size, text_col, HORIZONTAL_ALIGNMENT_CENTER, false))
	return pill


static func make_xp_progress_bar(progress_01: float, right_text: String = "", bar_col: Color = Color(0.28, 0.78, 0.42)) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 20)
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = clampf(progress_01, 0.0, 1.0) * 100.0
	pb.show_percentage = false

	var bg_st := StyleBoxFlat.new()
	bg_st.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	bg_st.border_color = Color(0.55, 0.42, 0.22, 0.85)
	bg_st.set_border_width_all(2)
	bg_st.set_corner_radius_all(10)
	pb.add_theme_stylebox_override("background", bg_st)

	var fill_st := StyleBoxFlat.new()
	fill_st.bg_color = bar_col
	fill_st.set_corner_radius_all(8)
	pb.add_theme_stylebox_override("fill", fill_st)
	box.add_child(pb)

	if not right_text.is_empty():
		box.add_child(make_body(right_text, 18, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

	return box


static func make_empty_state(
	icon_tex: Texture2D,
	title_txt: String,
	subtitle_txt: String,
	cta_txt: String = "",
	cta_variant: String = "gold",
	cta_cb: Callable = Callable()
) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", create_well_style(18, 24.0, 28.0))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	if icon_tex != null:
		var ico := TextureRect.new()
		ico.texture = icon_tex
		ico.custom_minimum_size = Vector2(68, 68)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ico.modulate = Color(1.0, 0.92, 0.72, 0.88)
		vbox.add_child(ico)

	vbox.add_child(make_title(title_txt, 28, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not subtitle_txt.is_empty():
		vbox.add_child(make_body(subtitle_txt, 21, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	if not cta_txt.is_empty() and cta_cb.is_valid():
		var btn := make_button(cta_txt, cta_variant, Vector2(240, 56), 23)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			cta_cb.call()
		)
		vbox.add_child(btn)

	return card


static func make_loading_state(msg: String = "در حال بارگذاری...") -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", create_well_style(16, 20.0, 22.0))
	var lbl := make_body(msg, 23, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	p.add_child(lbl)
	return p


static func show_confirm_modal(
	host: Node,
	title_txt: String,
	body_txt: String,
	confirm_txt: String = "تأیید",
	is_danger: bool = true,
	on_confirm: Callable = Callable()
) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 40

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.78)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 42)
	m.add_theme_constant_override("margin_right", 42)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 36)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	m.add_child(vbox)

	vbox.add_child(make_title(title_txt, 34, COL_CRIMSON_TEXT if is_danger else COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	vbox.add_child(make_body(body_txt, 23, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var b_cancel := make_button("انصراف", "bronze", Vector2(200, 60), 23)
	b_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
	)
	btn_row.add_child(b_cancel)

	var b_ok := make_button(confirm_txt, "crimson" if is_danger else "emerald", Vector2(220, 60), 23)
	b_ok.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
		if on_confirm.is_valid():
			on_confirm.call()
	)
	btn_row.add_child(b_ok)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
	return overlay


static func format_presence(presence: Dictionary) -> Dictionary:
	var st := str(presence.get("status", "offline"))
	var gtype := str(presence.get("current_game_type", ""))
	var gid := str(presence.get("current_game_id", ""))
	match st:
		"online":
			return {
				"text": "آنلاین",
				"color": Color(0.46, 0.94, 0.58),
				"dot_color": Color(0.24, 0.88, 0.42),
				"is_in_game": false,
				"game_id": ""
			}
		"in_game":
			var gt_fa := GameRegistry.get_display_name_fa(gtype) if not gtype.is_empty() else "مسابقه"
			return {
				"text": "در حال بازی (%s)" % gt_fa,
				"color": Color(0.48, 0.86, 1.0),
				"dot_color": Color(0.26, 0.72, 0.98),
				"is_in_game": not gid.is_empty(),
				"game_id": gid,
				"game_type": gtype
			}
		"in_lobby":
			return {
				"text": "در لابی دوستانه",
				"color": Color(0.98, 0.84, 0.36),
				"dot_color": Color(0.96, 0.76, 0.22),
				"is_in_game": false,
				"game_id": ""
			}
		"in_queue":
			return {
				"text": "در صف مسابقه",
				"color": Color(0.96, 0.74, 0.32),
				"dot_color": Color(0.92, 0.64, 0.20),
				"is_in_game": false,
				"game_id": ""
			}
		"away":
			return {
				"text": "دور از دسترس",
				"color": Color(0.84, 0.76, 0.56),
				"dot_color": Color(0.76, 0.64, 0.32),
				"is_in_game": false,
				"game_id": ""
			}
		_:
			return {
				"text": "آفلاین",
				"color": Color(0.66, 0.60, 0.54),
				"dot_color": Color(0.45, 0.40, 0.36),
				"is_in_game": false,
				"game_id": ""
			}


static func format_time_fa(iso_str: String) -> String:
	var s := iso_str.strip_edges()
	if s.is_empty():
		return ""
	# ISO formats like "2026-11-14T15:30:45.123456"
	var t_idx := s.find("T")
	if t_idx > 0 and s.length() >= t_idx + 6:
		var time_part := s.substr(t_idx + 1, 5)
		return GameManager.to_fa_num(time_part)
	return ""


static func get_game_thumb(game_type: String) -> Texture2D:
	var key := game_type.strip_edges().to_lower()
	if key.is_empty():
		return null
	var png_p := "res://assets/images/games/%s.png" % key
	if ResourceLoader.exists(png_p):
		return load(png_p)
	var jpg_p := "res://assets/images/games/%s.jpg" % key
	if ResourceLoader.exists(jpg_p):
		return load(jpg_p)
	return null


static func show_game_invite_modal(host: Node, target_uid: String, target_name: String, on_sent: Callable = Callable()) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 45

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.80)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(860, 0)
	card.add_theme_stylebox_override("panel", create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 42)
	m.add_theme_constant_override("margin_right", 42)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	var btn_x := TextureButton.new()
	btn_x.texture_normal = TEX_CLOSE
	btn_x.custom_minimum_size = Vector2(54, 54)
	btn_x.ignore_texture_size = true
	btn_x.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_x.focus_mode = Control.FOCUS_NONE
	ActionVFXManager.apply_button_juice(btn_x, "tap_button")
	btn_x.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top_row.add_child(btn_x)

	var ttl := make_title("دعوت «%s» به مسابقه دوستانه" % target_name, 34, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(54, 54)
	top_row.add_child(sp)

	vbox.add_child(make_body("بازی مورد نظر خود را برای ارسال دعوت‌نامه مستقیم انتخاب کنید:", 22, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	var popular_games := [
		{"id": "Monopoly", "title": "مونوپولی"},
		{"id": "Ludo", "title": "منچ (لودو)"},
		{"id": "BackGammon", "title": "تخته نرد"},
		{"id": "Chess", "title": "شطرنج"},
		{"id": "Coup", "title": "کودتا"},
		{"id": "Uno", "title": "اونو"},
		{"id": "BattleShip", "title": "نبرد کشتی"},
		{"id": "Quoridor", "title": "کوریدور"},
		{"id": "Risk", "title": "ریسک استرایک"},
		{"id": "TicTacToe", "title": "تیک تاک تو"},
	]

	for g in popular_games:
		var gid: String = str(g["id"])
		var gtitle: String = str(g["title"])
		var gbtn := Button.new()
		gbtn.custom_minimum_size = Vector2(360, 82)
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.focus_mode = Control.FOCUS_NONE
		gbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gbtn.add_theme_stylebox_override("normal", _get_flat_btn_style("bronze", "normal", 16))
		gbtn.add_theme_stylebox_override("hover", _get_flat_btn_style("gold", "normal", 16))
		gbtn.add_theme_stylebox_override("pressed", _get_flat_btn_style("bronze", "pressed", 16))

		var gm := MarginContainer.new()
		gm.set_anchors_preset(Control.PRESET_FULL_RECT)
		gm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gm.add_theme_constant_override("margin_left", 14)
		gm.add_theme_constant_override("margin_right", 14)
		gbtn.add_child(gm)

		var grow := HBoxContainer.new()
		grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grow.add_theme_constant_override("separation", 14)
		grow.alignment = BoxContainer.ALIGNMENT_END
		gm.add_child(grow)

		var lbl_go := make_body("دعوت", 19, COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
		lbl_go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grow.add_child(lbl_go)

		var lbl_g := make_title(gtitle, 26, COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		lbl_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grow.add_child(lbl_g)

		var thumb_wrap := PanelContainer.new()
		thumb_wrap.custom_minimum_size = Vector2(56, 56)
		thumb_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_wrap.add_theme_stylebox_override("panel", create_card_style(Color(0.08, 0.05, 0.03), COL_GOLD_ANTIQUE, 12, 2, 3.0, 3.0))
		var thumb := TextureRect.new()
		thumb.texture = get_game_thumb(gid)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_wrap.add_child(thumb)
		grow.add_child(thumb_wrap)

		ActionVFXManager.apply_button_juice(gbtn, "tap_button")
		gbtn.pressed.connect(func():
			AudioManager.sfx_button()
			if NetworkManager.is_online:
				NetworkManager.send_game_invite_realtime(target_uid, gid, "direct_match")
			else:
				NetworkManager.api.send_game_invitation_rest(target_uid, gid, "direct_match")
			overlay.queue_free()
			if on_sent.is_valid():
				on_sent.call(gtitle)
		)
		grid.add_child(gbtn)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
	return overlay


static func show_report_modal(host: Node, target_type: String, target_id: String, target_name: String, on_done: Callable = Callable()) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 45

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.80)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	card.add_theme_stylebox_override("panel", create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 42)
	m.add_theme_constant_override("margin_right", 42)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	vbox.add_child(make_title("گزارش تخلف: %s" % target_name, 34, COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	vbox.add_child(make_body("لطفاً دلیل گزارش را انتخاب کنید تا توسط تیم نظارت بررسی شود:", 22, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_details := make_line_edit("توضیحات تکمیلی (اختیاری)...", 58.0, 21)
	var selected_reason := ["inappropriate_behavior"]
	var reason_defs := [
		{"id": "inappropriate_behavior", "label": "رفتار نامناسب یا توهین در گفتگو"},
		{"id": "cheating", "label": "تقلب یا سوءاستفاده از قوانین بازی"},
		{"id": "offensive_name", "label": "نام کاربری یا عنوان نامناسب"},
		{"id": "spam", "label": "ارسال پیام‌های تبلیغاتی یا مزاحمت"},
	]
	var reason_btns: Dictionary = {}
	var refresh_reasons := func():
		for rk in reason_btns.keys():
			var b: Button = reason_btns[rk]
			var is_sel: bool = (rk == selected_reason[0])
			b.add_theme_stylebox_override("normal", _get_flat_btn_style("crimson" if is_sel else "muted", "normal", 13))
			b.add_theme_stylebox_override("hover", _get_flat_btn_style("crimson" if is_sel else "muted", "hover", 13))

	for r in reason_defs:
		var rid: String = r["id"]
		var rb := make_button(r["label"], "muted", Vector2(0, 54), 21)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_reason[0] = rid
			refresh_reasons.call()
		)
		reason_btns[rid] = rb
		vbox.add_child(rb)
	refresh_reasons.call()
	vbox.add_child(inp_details)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var b_cancel := make_button("انصراف", "bronze", Vector2(200, 58), 22)
	b_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
	)
	btn_row.add_child(b_cancel)

	var b_send := make_button("ثبت گزارش", "crimson", Vector2(240, 58), 22)
	b_send.pressed.connect(func():
		AudioManager.sfx_button()
		b_send.disabled = true
		NetworkManager.api.report_social_target(target_type, target_id, selected_reason[0], inp_details.text.strip_edges(), func(ok: bool, _c: int, _d: Variant):
			overlay.queue_free()
			if on_done.is_valid():
				on_done.call(ok)
		)
	)
	btn_row.add_child(b_send)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
	return overlay

