class_name CafeSocialTheme
extends RefCounted

## Cafe Fekr — Antique Board-Game Club Social UI Component Library
## Provides cohesive dark walnut / mahogany surfaces, ornate gold/bronze frames,
## emerald highlights, crisp RTL Persian typography, and reusable social widgets.

const FONT_TITLE = preload("res://assets/fonts/hekayat.ttf")
const FONT_BODY = preload("res://assets/fonts/Vazir.ttf")

# Authentic Cafe Fekr Frames & UI Textures
const TEX_BOARD = preload("res://assets/images/frames/board.png")
const TEX_DIALOG = preload("res://assets/images/frames/dialog.png")
const TEX_DIALOG_TALL = preload("res://assets/images/frames/dialog_tall.png")
const TEX_FRAME = preload("res://assets/images/frames/frame.png")
const TEX_FRAME2 = preload("res://assets/images/frames/frame2.png")
const TEX_FRAME3 = preload("res://assets/images/frames/frame3.png")
const TEX_FRAME4 = preload("res://assets/images/frames/frame4.png")
const TEX_FRAME5 = preload("res://assets/images/frames/frame5.png")
const TEX_BUTTON = preload("res://assets/images/frames/button.png")
const TEX_CLOSE = preload("res://assets/images/frames/close.png")
const TEX_ADD = preload("res://assets/images/frames/add.png")
const TEX_CHECK = preload("res://assets/images/frames/check.png")
const TEX_RIGHT = preload("res://assets/images/frames/right.png")
const TEX_REPLY = preload("res://assets/images/frames/reply.png")
const TEX_FRAME_SMALL = preload("res://assets/images/frames/frame_small.png")
const TEX_FRAME_TALL = preload("res://assets/images/frames/frame_tall.png")
const TEX_CHAT_OTHER = preload("res://assets/images/frames/chat_other.png")
const TEX_CHAT_MY = preload("res://assets/images/frames/chat_my.png")
const TEX_CONFIG = preload("res://assets/images/config.png")
const TEX_DELETE = preload("res://assets/images/delete.png")
const TEX_PLUS = preload("res://assets/images/frames/plus.png")

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

const TEX_TAB_FRIENDS = preload("res://assets/images/frames/friends.png")
const TEX_TAB_CLANS = preload("res://assets/images/frames/clan.png")
const TEX_TAB_MESSAGES = preload("res://assets/images/frames/chat.png")
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
const COL_GOLD_FRAME := Color(0.80, 0.61, 0.25, 0.95)
const COL_BRONZE_BORDER := Color(0.56, 0.41, 0.21, 0.88)
const COL_WALNUT_DEEP := Color(0.11, 0.07, 0.04, 0.96)
const COL_WALNUT_CARD := Color(0.16, 0.10, 0.06, 0.95)
const COL_MAHOGANY_CARD := Color(0.21, 0.13, 0.08, 0.96)
const COL_EMERALD_TEXT := Color(0.50, 0.92, 0.64, 1.0)
const COL_EMERALD_BG := Color(0.12, 0.27, 0.18, 0.96)
const COL_EMERALD_BORDER := Color(0.36, 0.78, 0.50, 0.92)
const COL_CRIMSON_TEXT := Color(0.98, 0.54, 0.52, 1.0)
const COL_CRIMSON_BG := Color(0.28, 0.10, 0.10, 0.95)
const COL_CRIMSON_BORDER := Color(0.84, 0.34, 0.32, 0.90)

static func is_mobile() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm and "is_mobile" in gm:
			return bool(gm.is_mobile)
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or (OS.get_name() in ["Android", "iOS"])

static var _shell_style_cache: StyleBoxTexture = null
static var _dialog_style_cache: StyleBoxTexture = null
static var _frame_banner_cache: StyleBoxTexture = null
static var _btn_cache: Dictionary = {}

# Profile Frame visual tiers (1..20)
const PROFILE_FRAMES := [
	{"id": 1, "name": "قاب سلطنتی زرین", "border": Color(0.98, 0.82, 0.35, 1.0), "glow": Color(1.0, 0.85, 0.3, 0.5)},
	{"id": 2, "name": "قاب برنز باستانی", "border": Color(0.85, 0.55, 0.28, 1.0), "glow": Color(0.75, 0.45, 0.2, 0.4)},
	{"id": 3, "name": "قاب زمرد شاهانه", "border": Color(0.35, 0.90, 0.58, 1.0), "glow": Color(0.25, 0.85, 0.5, 0.45)},
	{"id": 4, "name": "قاب یاقوت سرخ", "border": Color(0.95, 0.32, 0.40, 1.0), "glow": Color(0.90, 0.25, 0.35, 0.45)},
	{"id": 5, "name": "قاب لعل درخشان", "border": Color(0.98, 0.45, 0.55, 1.0), "glow": Color(0.95, 0.35, 0.45, 0.45)},
	{"id": 6, "name": "قاب فیروزه نیشابور", "border": Color(0.30, 0.85, 0.90, 1.0), "glow": Color(0.20, 0.80, 0.85, 0.45)},
	{"id": 7, "name": "قاب الماس کوه نور", "border": Color(0.88, 0.92, 1.0, 1.0), "glow": Color(0.80, 0.88, 1.0, 0.5)},
	{"id": 8, "name": "قاب کهربای گرم", "border": Color(0.96, 0.70, 0.25, 1.0), "glow": Color(0.90, 0.65, 0.2, 0.4)},
	{"id": 9, "name": "قاب لاجورد کهن", "border": Color(0.40, 0.65, 0.95, 1.0), "glow": Color(0.30, 0.55, 0.9, 0.45)},
	{"id": 10, "name": "قاب طلای عتیق", "border": Color(0.90, 0.75, 0.30, 1.0), "glow": Color(0.85, 0.70, 0.25, 0.45)},
	{"id": 11, "name": "قاب شاخ و برگ زرین", "border": Color(0.85, 0.80, 0.40, 1.0), "glow": Color(0.80, 0.75, 0.35, 0.45)},
	{"id": 12, "name": "قاب اژدهای پارسی", "border": Color(0.92, 0.50, 0.25, 1.0), "glow": Color(0.88, 0.45, 0.2, 0.45)},
	{"id": 13, "name": "قاب بال سیمرغ", "border": Color(0.95, 0.60, 0.35, 1.0), "glow": Color(0.90, 0.55, 0.3, 0.45)},
	{"id": 14, "name": "قاب ستاره شاهنشاهی", "border": Color(0.98, 0.88, 0.40, 1.0), "glow": Color(1.0, 0.90, 0.35, 0.5)},
	{"id": 15, "name": "قاب تاج کیانی", "border": Color(0.95, 0.75, 0.30, 1.0), "glow": Color(0.90, 0.70, 0.25, 0.45)},
	{"id": 16, "name": "قاب شمشیر دلاوران", "border": Color(0.80, 0.70, 0.50, 1.0), "glow": Color(0.75, 0.65, 0.45, 0.4)},
	{"id": 17, "name": "قاب گل و مرغ", "border": Color(0.92, 0.65, 0.70, 1.0), "glow": Color(0.88, 0.60, 0.65, 0.45)},
	{"id": 18, "name": "قاب شوالیه کافه", "border": Color(0.75, 0.75, 0.85, 1.0), "glow": Color(0.70, 0.70, 0.80, 0.4)},
	{"id": 19, "name": "قاب خورشید تابان", "border": Color(1.0, 0.78, 0.25, 1.0), "glow": Color(1.0, 0.75, 0.2, 0.5)},
	{"id": 20, "name": "قاب اسطوره قهرمانان", "border": Color(0.95, 0.85, 0.45, 1.0), "glow": Color(0.90, 0.80, 0.4, 0.5)},
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
	sb.texture = TEX_DIALOG_TALL
	sb.texture_margin_left = 40.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 60.0
	_shell_style_cache = sb
	return sb


static func create_dialog_frame_style(tall: bool = false) -> StyleBoxTexture:
	if tall:
		return create_board_shell_style()
	if _dialog_style_cache != null:
		return _dialog_style_cache
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_DIALOG
	sb.texture_margin_left = 44.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_bottom = 80.0
	_dialog_style_cache = sb
	return sb


static func create_header_banner_style(pad_x: float = 44.0, pad_y: float = 26.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME2
	sb.texture_margin_left = 40.0
	sb.texture_margin_top = 24.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 24.0
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_item_frame_style(pad_x: float = 46.0, pad_y: float = 28.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME
	sb.texture_margin_left = 48.0
	sb.texture_margin_top = 28.0
	sb.texture_margin_right = 48.0
	sb.texture_margin_bottom = 28.0
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_clan_top_header_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME3
	sb.texture_margin_left = 68.0
	sb.texture_margin_top = 74.0
	sb.texture_margin_right = 68.0
	sb.texture_margin_bottom = 32.0
	sb.content_margin_left = 56.0
	sb.content_margin_right = 56.0
	sb.content_margin_top = 82.0
	sb.content_margin_bottom = 36.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_panel_box_style(pad_x: float = 44.0, pad_y: float = 44.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME4
	sb.texture_margin_left = 48.0
	sb.texture_margin_top = 42.0
	sb.texture_margin_right = 48.0
	sb.texture_margin_bottom = 42.0
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_frame5_style(pad_x: float = 46.0, pad_y: float = 32.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_FRAME5
	sb.texture_margin_left = 54.0
	sb.texture_margin_top = 96.0
	sb.texture_margin_right = 54.0
	sb.texture_margin_bottom = 44.0
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y + 12.0
	sb.content_margin_bottom = pad_y
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_frame_style(is_tall: bool = false, pad_x: float = 36.0, pad_y: float = 20.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if is_tall:
		sb.texture = TEX_FRAME_TALL
		sb.texture_margin_left = 50.0
		sb.texture_margin_right = 50.0
		sb.texture_margin_top = 26.0
		sb.texture_margin_bottom = 26.0
		sb.content_margin_left = maxf(pad_x, 36.0)
		sb.content_margin_right = maxf(pad_x, 36.0)
		sb.content_margin_top = maxf(pad_y, 20.0)
		sb.content_margin_bottom = maxf(pad_y, 30.0)
	else:
		sb.texture = TEX_FRAME_SMALL
		sb.texture_margin_left = 50.0
		sb.texture_margin_right = 50.0
		sb.texture_margin_top = 18.0
		sb.texture_margin_bottom = 18.0
		sb.content_margin_left = maxf(pad_x, 36.0)
		sb.content_margin_right = maxf(pad_x, 36.0)
		sb.content_margin_top = maxf(pad_y, 16.0)
		sb.content_margin_bottom = maxf(pad_y, 22.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_chat_bubble_style(is_mine: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	if is_mine:
		sb.texture = TEX_CHAT_MY
		sb.texture_margin_left = 20.0
		sb.texture_margin_right = 46.0
		sb.texture_margin_top = 18.0
		sb.texture_margin_bottom = 30.0
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 18.0
		sb.content_margin_bottom = 38.0
	else:
		sb.texture = TEX_CHAT_OTHER
		sb.texture_margin_left = 44.0
		sb.texture_margin_right = 20.0
		sb.texture_margin_top = 18.0
		sb.texture_margin_bottom = 36.0
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 20.0
		sb.content_margin_bottom = 44.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func create_flat_chat_bubble_style(is_mine: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if is_mine:
		sb.bg_color = Color(0.12, 0.28, 0.18, 0.96)
		sb.border_color = Color(0.38, 0.80, 0.52, 0.82)
		sb.corner_radius_top_left = 16
		sb.corner_radius_top_right = 16
		sb.corner_radius_bottom_left = 16
		sb.corner_radius_bottom_right = 4
	else:
		sb.bg_color = Color(0.20, 0.13, 0.08, 0.96)
		sb.border_color = Color(0.58, 0.44, 0.22, 0.75)
		sb.corner_radius_top_left = 16
		sb.corner_radius_top_right = 16
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 16
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 0 if is_mobile() else 5
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func make_metric_card(
	label_txt: String,
	val_txt: String,
	val_color: Color = COL_GOLD_BRIGHT,
	icon_tex: Texture2D = null
) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := create_card_style(Color(0.13, 0.09, 0.05, 0.92), Color(0.50, 0.38, 0.20, 0.65), 14, 1, 10.0, 8.0)
	card.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var l_lbl := make_body(label_txt, 18, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
	vbox.add_child(l_lbl)

	var v_lbl := make_title(val_txt, 24, val_color, HORIZONTAL_ALIGNMENT_CENTER, false)
	vbox.add_child(v_lbl)

	if icon_tex != null:
		var ico := TextureRect.new()
		ico.texture = icon_tex
		ico.custom_minimum_size = Vector2(32, 32)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(ico)

	return card


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
	sb.shadow_size = 0 if is_mobile() else 8
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
	sb.shadow_size = 0 if is_mobile() else 4
	return sb


static func make_title(
	txt: String,
	font_size: int = 35,
	col: Color = COL_GOLD_BRIGHT,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT,
	wrap: bool = false
) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var norm_sz: int = UITypography.normalize_raw_px(font_size)
	l.set_meta(&"_resp_base_px", norm_sz)
	l.set_meta(&"_resp_min_px", 18)
	l.set_meta(&"_resp_max_px", maxi(48, norm_sz))
	l.add_theme_font_override("font", FONT_TITLE)
	l.add_theme_font_size_override("font_size", UITypography.scale_px(norm_sz, 18, maxi(48, norm_sz)))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)
	UITypography.configure_bidi(l, false, wrap)
	return l


static func make_body(
	txt: String,
	font_size: int = 25,
	col: Color = COL_WARM_CREAM,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT,
	wrap: bool = true
) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var norm_sz: int = UITypography.normalize_raw_px(font_size)
	l.set_meta(&"_resp_base_px", norm_sz)
	l.set_meta(&"_resp_min_px", 16)
	l.set_meta(&"_resp_max_px", maxi(36, norm_sz))
	l.add_theme_font_override("font", FONT_BODY)
	l.add_theme_font_size_override("font_size", UITypography.scale_px(norm_sz, 16, maxi(36, norm_sz)))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	l.add_theme_constant_override("shadow_outline_size", 2)
	UITypography.configure_bidi(l, false, wrap)
	return l


static func make_line_edit(
	placeholder: String,
	min_height: float = 64.0,
	font_size: int = 26,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, min_height)
	le.alignment = align
	var norm_sz: int = UITypography.normalize_raw_px(font_size)
	le.set_meta(&"_resp_base_px", norm_sz)
	le.set_meta(&"_resp_min_px", 18)
	le.set_meta(&"_resp_max_px", maxi(32, norm_sz))
	le.add_theme_font_override("font", FONT_BODY)
	le.add_theme_font_size_override("font_size", UITypography.scale_px(norm_sz, 18, maxi(32, norm_sz)))
	le.add_theme_color_override("font_color", COL_IVORY)
	le.add_theme_color_override("font_placeholder_color", Color(0.68, 0.60, 0.48, 0.78))
	le.add_theme_stylebox_override("normal", create_input_style(false))
	le.add_theme_stylebox_override("focus", create_input_style(true))
	UITypography.configure_bidi(le, false, false)
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
	sb.shadow_size = 0 if is_mobile() else 5
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
	font_size: int = 25,
	icon_tex: Texture2D = null,
	use_title_font: bool = false,
	corner: int = 14
) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var norm_sz: int = UITypography.normalize_raw_px(font_size)
	var min_sz: int = 16 if use_title_font else 15
	b.set_meta(&"_resp_base_px", norm_sz)
	b.set_meta(&"_resp_min_px", min_sz)
	b.set_meta(&"_resp_max_px", maxi(36, norm_sz))
	b.add_theme_font_override("font", FONT_TITLE if use_title_font else FONT_BODY)
	b.add_theme_font_size_override("font_size", UITypography.scale_px(norm_sz, min_sz, maxi(36, norm_sz)))
	b.add_theme_color_override("font_color", COL_IVORY)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_pressed_color", COL_WARM_CREAM)
	b.add_theme_color_override("font_focus_color", COL_IVORY)
	b.add_theme_color_override("font_hover_pressed_color", COL_WARM_CREAM)
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
	font_size: int = 33
) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", UITypography.scale_px(font_size, 22, 42))
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
	is_active: bool = false,
	custom_icon: Texture2D = null
) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 142)
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

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vbox)

	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(0, 84)
	tr.texture = custom_icon if custom_icon != null else get_nav_tab_texture(tab_id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_active:
		tr.modulate = Color(0.76, 0.72, 0.68, 0.90)
	else:
		tr.modulate = Color(1.0, 1.0, 1.0, 1.0)
	vbox.add_child(tr)

	var tab_title: String = ""
	match tab_id:
		"friends":
			tab_title = "دوستان"
		"clans":
			tab_title = "اتحاد"
		"messages":
			tab_title = "پیام‌ها"
		"notifs":
			tab_title = "اعلان‌ها"
		_:
			tab_title = ""

	if not tab_title.is_empty():
		var lbl := Label.new()
		lbl.text = tab_title
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.85, 0.82, 0.78, 0.85))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.90))
		lbl.add_theme_constant_override("shadow_outline_size", 3)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	if is_active:
		var highlight_bar := ColorRect.new()
		highlight_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		highlight_bar.offset_top = -6
		highlight_bar.offset_bottom = -1
		highlight_bar.offset_left = 26
		highlight_bar.offset_right = -26
		highlight_bar.color = Color(0.42, 0.92, 0.60, 0.98)
		highlight_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(highlight_bar)

	if badge_count > 0:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -42
		badge.offset_top = 4
		badge.offset_right = -6
		badge.offset_bottom = 34
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
		bl.add_theme_font_size_override("font_size", 19)
		bl.add_theme_color_override("font_color", COL_IVORY)
		badge.add_child(bl)
		holder.add_child(badge)

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


static func make_subtab(label_txt: String, is_active: bool = false, badge_count: int = 0) -> Button:
	var txt := label_txt
	if badge_count > 0:
		txt += " (%s)" % GameManager.to_fa_num(badge_count)
	var b := make_button(
		txt,
		"emerald" if is_active else "muted",
		Vector2(0, 56),
		24,
		null,
		false,
		13
	)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func make_ornate_section_header(title_txt: String, icon_tex: Texture2D = null, subtitle_txt: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", create_header_banner_style(46.0, 26.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	text_col.add_child(make_title(title_txt, 31, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, true))
	if not subtitle_txt.is_empty():
		text_col.add_child(make_body(subtitle_txt, 22, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	if icon_tex != null:
		var ico := TextureRect.new()
		ico.texture = icon_tex
		ico.custom_minimum_size = Vector2(36, 36)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ico)

	return p


static var _frame_texture_cache: Dictionary = {}
static var _avatar_texture_cache: Dictionary = {}
static var _game_thumb_cache: Dictionary = {}

static func get_avatar_texture(avatar_id: int) -> Texture2D:
	var safe_id: int = clampi(avatar_id, 0, 71)
	if _avatar_texture_cache.has(safe_id):
		return _avatar_texture_cache[safe_id] as Texture2D
	var path: String = "res://assets/icons/Avatars/%d.png" % safe_id
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_avatar_texture_cache[safe_id] = tex
		return tex
	if safe_id != 0 and _avatar_texture_cache.has(0):
		var fb0: Texture2D = _avatar_texture_cache[0] as Texture2D
		_avatar_texture_cache[safe_id] = fb0
		return fb0
	var fallback_path: String = "res://assets/icons/Avatars/0.png"
	if ResourceLoader.exists(fallback_path):
		var fb_tex: Texture2D = load(fallback_path) as Texture2D
		_avatar_texture_cache[0] = fb_tex
		_avatar_texture_cache[safe_id] = fb_tex
		return fb_tex
	_avatar_texture_cache[safe_id] = null
	return null


static func get_frame_texture(frame_id: int) -> Texture2D:
	var fid: int = frame_id if frame_id >= 1 else 1
	fid = clampi(fid, 1, 20)
	if _frame_texture_cache.has(fid):
		return _frame_texture_cache[fid]
	var path: String = "res://assets/images/avatar_frames/%d.png" % fid
	if ResourceLoader.exists(path):
		var tex = load(path)
		_frame_texture_cache[fid] = tex
		return tex
	var fallback_path: String = "res://assets/images/avatar_frames/1.png"
	if ResourceLoader.exists(fallback_path):
		var fb_tex = load(fallback_path)
		_frame_texture_cache[fid] = fb_tex
		return fb_tex
	return null


static var _avatar_aperture_mats: Dictionary = {}

# Exact per-frame aperture data inside a square KEEP_ASPECT_CENTERED container:
# - "rect": superellipse clipping bounds (0 gaps inside bezel, 0 leaks outside silhouette)
# - "hole": visible inner opening normalized inside "rect" (for clean portrait framing)
# - "pow": superellipse exponent (2.0 = true oval, 2.2..3.6 = rounded-shield/squircle)
const _FRAME_APERTURES: Dictionary = {
	1:  {"rect": Vector4(0.189, 0.161, 0.797, 0.741), "hole": Vector4(0.023, 0.012, 0.977, 0.976), "pow": 2.0},
	2:  {"rect": Vector4(0.102, 0.039, 0.898, 0.772), "hole": Vector4(0.059, 0.075, 0.950, 0.957), "pow": 2.8},
	3:  {"rect": Vector4(0.197, 0.214, 0.797, 0.793), "hole": Vector4(0.011, 0.036, 0.977, 0.964), "pow": 2.0},
	4:  {"rect": Vector4(0.148, 0.159, 0.803, 0.793), "hole": Vector4(0.021, 0.043, 0.979, 0.989), "pow": 2.0},
	5:  {"rect": Vector4(0.104, 0.100, 0.896, 0.838), "hole": Vector4(0.068, 0.062, 0.932, 0.927), "pow": 3.0},
	6:  {"rect": Vector4(0.141, 0.221, 0.838, 0.855), "hole": Vector4(0.069, 0.043, 0.931, 0.946), "pow": 2.2},
	7:  {"rect": Vector4(0.169, 0.176, 0.801, 0.816), "hole": Vector4(0.070, 0.034, 0.930, 0.931), "pow": 3.6},
	8:  {"rect": Vector4(0.177, 0.156, 0.787, 0.745), "hole": Vector4(0.023, 0.024, 0.977, 0.964), "pow": 2.0},
	9:  {"rect": Vector4(0.115, 0.099, 0.878, 0.809), "hole": Vector4(0.070, 0.065, 0.960, 0.968), "pow": 2.8},
	10: {"rect": Vector4(0.140, 0.132, 0.838, 0.787), "hole": Vector4(0.074, 0.056, 0.947, 0.966), "pow": 2.0},
	11: {"rect": Vector4(0.126, 0.140, 0.860, 0.776), "hole": Vector4(0.067, 0.066, 0.943, 0.967), "pow": 2.8},
	12: {"rect": Vector4(0.214, 0.188, 0.773, 0.779), "hole": Vector4(0.081, 0.077, 0.919, 0.956), "pow": 2.6},
	13: {"rect": Vector4(0.218, 0.141, 0.763, 0.686), "hole": Vector4(0.082, 0.035, 0.918, 0.965), "pow": 2.0},
	14: {"rect": Vector4(0.178, 0.174, 0.808, 0.790), "hole": Vector4(0.011, 0.035, 0.977, 0.965), "pow": 2.0},
	15: {"rect": Vector4(0.184, 0.237, 0.809, 0.809), "hole": Vector4(0.032, 0.046, 0.968, 0.954), "pow": 2.0},
	16: {"rect": Vector4(0.162, 0.165, 0.838, 0.806), "hole": Vector4(0.064, 0.045, 0.936, 0.921), "pow": 2.4},
	17: {"rect": Vector4(0.187, 0.197, 0.793, 0.776), "hole": Vector4(0.034, 0.012, 0.966, 0.965), "pow": 2.0},
	18: {"rect": Vector4(0.164, 0.153, 0.836, 0.788), "hole": Vector4(0.076, 0.011, 0.924, 0.954), "pow": 2.2},
	19: {"rect": Vector4(0.183, 0.200, 0.769, 0.772), "hole": Vector4(0.012, 0.024, 0.976, 0.964), "pow": 2.0},
	20: {"rect": Vector4(0.185, 0.196, 0.764, 0.783), "hole": Vector4(0.025, 0.025, 0.987, 0.963), "pow": 2.0},
}

static var _avatar_aperture_shader: Shader = null

static func _get_avatar_aperture_material(frame_id: int = 1) -> ShaderMaterial:
	var safe_fid: int = clampi(frame_id if frame_id >= 1 else 1, 1, 20)
	if _avatar_aperture_mats.has(safe_fid):
		return _avatar_aperture_mats[safe_fid]

	if _avatar_aperture_shader == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float shape_pow = 2.0;
uniform float box_aspect = 1.0;
uniform vec4 hole_uv = vec4(0.02, 0.02, 0.98, 0.98);
uniform float portrait_fit = 0.93;

void fragment() {
	vec2 p = abs(UV * 2.0 - vec2(1.0));
	vec2 p2 = p * p;
	float d;
	if (shape_pow <= 2.05) {
		d = p2.x + p2.y;
	} else if (shape_pow <= 3.0) {
		vec2 p3 = p2 * p;
		vec2 pv = mix(p2, p3, shape_pow - 2.0);
		d = pv.x + pv.y;
	} else {
		vec2 p3 = p2 * p;
		vec2 p4 = p2 * p2;
		vec2 pv = mix(p3, p4, clamp(shape_pow - 3.0, 0.0, 1.0));
		d = pv.x + pv.y;
	}
	float mask = 1.0 - smoothstep(0.94, 1.0, d);

	vec2 hole_center = vec2(0.5 * (hole_uv.x + hole_uv.z), 0.5 * (hole_uv.y + hole_uv.w));
	vec2 hole_half = max(vec2(0.1), 0.5 * (hole_uv.zw - hole_uv.xy));
	vec2 hv = (UV - hole_center) / hole_half;
	float r_hole_sq = dot(hv, hv);
	vec3 bg_center = vec3(0.22, 0.128, 0.072);
	vec3 bg_edge = vec3(0.105, 0.056, 0.030);
	vec3 bg = mix(bg_center, bg_edge, smoothstep(0.0, 1.1025, r_hole_sq));
	bg *= mix(1.0, 0.80, smoothstep(0.5776, 1.1025, r_hole_sq));

	float px_w = max(TEXTURE_PIXEL_SIZE.x, 0.0001);
	float px_h = max(TEXTURE_PIXEL_SIZE.y, 0.0001);
	float tex_aspect = px_h / px_w;
	float hole_w = max(0.05, hole_uv.z - hole_uv.x);
	float hole_h = max(0.05, hole_uv.w - hole_uv.y);
	float avail_w = hole_w * portrait_fit * box_aspect;
	float avail_h = hole_h * portrait_fit;
	vec2 draw_size;
	if (avail_w / avail_h > tex_aspect) {
		draw_size = vec2(avail_h * tex_aspect, avail_h);
	} else {
		draw_size = vec2(avail_w, avail_w / tex_aspect);
	}
	vec2 draw_uv_size = vec2(draw_size.x / max(box_aspect, 0.05), draw_size.y);
	vec2 target_center = vec2(hole_center.x, hole_uv.w + 0.015 * hole_h - 0.5 * draw_uv_size.y);
	vec2 tex_uv = (UV - target_center) / draw_uv_size + vec2(0.5);

	vec4 tex = vec4(0.0);
	if (tex_uv.x > 0.001 && tex_uv.x < 0.999 && tex_uv.y > 0.001 && tex_uv.y < 0.999) {
		tex = texture(TEXTURE, tex_uv);
	}

	vec3 rgb = mix(bg, tex.rgb, tex.a);
	COLOR = vec4(rgb, mask);
}
"""
		_avatar_aperture_shader = sh

	var ap_data: Dictionary = _FRAME_APERTURES.get(safe_fid, _FRAME_APERTURES[1])
	var r: Vector4 = ap_data["rect"]
	var hole: Vector4 = ap_data["hole"]
	var spow: float = float(ap_data["pow"])
	var box_aspect: float = maxf(0.1, (r.z - r.x) / maxf(0.05, r.w - r.y))

	var mat := ShaderMaterial.new()
	mat.shader = _avatar_aperture_shader
	mat.set_shader_parameter("shape_pow", spow)
	mat.set_shader_parameter("box_aspect", box_aspect)
	mat.set_shader_parameter("hole_uv", hole)
	mat.set_shader_parameter("portrait_fit", 0.93)
	_avatar_aperture_mats[safe_fid] = mat
	return mat


static func _get_frame_aperture(frame_id: int) -> Vector4:
	var safe_fid: int = clampi(frame_id if frame_id >= 1 else 1, 1, 20)
	if _FRAME_APERTURES.has(safe_fid):
		var ap_data: Dictionary = _FRAME_APERTURES[safe_fid]
		return ap_data["rect"]
	return Vector4(0.189, 0.161, 0.797, 0.741)


static func make_avatar_badge(
	avatar_id: int,
	frame_id: int = 1,
	size_px: float = 88.0,
	presence_status: String = "",
	show_dot: bool = false
) -> Control:
	var final_sz: float = maxf(size_px, 66.0) + 6.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(final_sz, final_sz)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var safe_fid: int = frame_id if frame_id >= 1 else 1
	safe_fid = clampi(safe_fid, 1, 20)
	var ap: Vector4 = _get_frame_aperture(safe_fid)

	# 1. Avatar texture framed and masked cleanly inside the frame's inner aperture
	var av := TextureRect.new()
	av.name = "Avatar"
	av.anchor_left = ap.x
	av.anchor_top = ap.y
	av.anchor_right = ap.z
	av.anchor_bottom = ap.w
	av.offset_left = 0.0
	av.offset_top = 0.0
	av.offset_right = 0.0
	av.offset_bottom = 0.0
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_SCALE
	av.material = _get_avatar_aperture_material(safe_fid)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.texture = get_avatar_texture(avatar_id)
	holder.add_child(av)

	# 2. Frame Overlay Texture (Locked 1:1 to holder rect so aperture coordinates align cleanly)
	var frame_rect := TextureRect.new()
	frame_rect.name = "FrameOverlay"
	frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_rect.offset_left = 0.0
	frame_rect.offset_top = 0.0
	frame_rect.offset_right = 0.0
	frame_rect.offset_bottom = 0.0
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.texture = get_frame_texture(safe_fid)
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame_rect)

	# 3. Presence status dot if requested
	if show_dot:
		var dot := PanelContainer.new()
		var dot_sz := clampf(final_sz * 0.26, 16.0, 24.0)
		dot.custom_minimum_size = Vector2(dot_sz, dot_sz)
		dot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		dot.offset_left = -2
		dot.offset_top = -dot_sz + 2
		dot.offset_right = dot_sz - 2
		dot.offset_bottom = 2
		var dst := StyleBoxFlat.new()
		var p_info := format_presence({"status": presence_status})
		dst.bg_color = p_info["dot_color"]
		dst.border_color = Color(0.08, 0.05, 0.03, 1.0)
		dst.set_border_width_all(3)
		dst.set_corner_radius_all(int(dot_sz * 0.5))
		dot.add_theme_stylebox_override("panel", dst)
		holder.add_child(dot)

	return holder


static func apply_frame_to_container(container: Control, avatar_rect: TextureRect, frame_id: int = 1) -> TextureRect:
	if not is_instance_valid(container) and not is_instance_valid(avatar_rect):
		return null
	var safe_fid: int = frame_id if frame_id >= 1 else 1
	safe_fid = clampi(safe_fid, 1, 20)
	var ap: Vector4 = _get_frame_aperture(safe_fid)

	var host_ctrl: Control = container
	if is_instance_valid(avatar_rect):
		var p_node: Node = avatar_rect.get_parent()
		if p_node is Panel or p_node is PanelContainer:
			var p_ctrl: Control = p_node as Control
			p_ctrl.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			p_ctrl.clip_contents = false
		var is_dedicated_slot: bool = is_instance_valid(container) and not (container is BoxContainer) and not (container is GridContainer) and not (container is MarginContainer)
		if is_dedicated_slot:
			if container is Panel or container is PanelContainer:
				container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			container.clip_contents = false
			if not container.has_meta("_av_box_boosted") and container.custom_minimum_size.x > 0.0 and container.custom_minimum_size.y > 0.0:
				var sq_sz: float = maxf(container.custom_minimum_size.x, container.custom_minimum_size.y) + 6.0
				container.custom_minimum_size = Vector2(sq_sz, sq_sz)
				container.set_meta("_av_box_boosted", true)
			if container.get_parent() is Container:
				if container.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
					container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				if container.size_flags_vertical != Control.SIZE_EXPAND_FILL:
					container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for legacy_name in ["AvatarRing", "AvatarMedallionFrame", "WoodDisc", "BgDisc", "PlayerSideTag"]:
				var leg: Node = container.get_node_or_null(legacy_name)
				if is_instance_valid(leg) and leg is CanvasItem:
					(leg as CanvasItem).visible = false

		# If avatar_rect is a direct child of a Godot Container (BoxContainer, PanelContainer, GridContainer, etc.),
		# wrap it inside a plain Control (AvatarInnerHost) so the Container does not override anchor/offset layout.
		if p_node is Control and (p_node as Control).name == "AvatarInnerHost":
			host_ctrl = p_node as Control
			var grand_p: Node = host_ctrl.get_parent()
			if grand_p is PanelContainer:
				host_ctrl.custom_minimum_size = Vector2.ZERO
				host_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				host_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		elif p_node is Container:
			var cont_parent: Container = p_node as Container
			var existing_host: Node = cont_parent.get_node_or_null("AvatarInnerHost")
			if is_instance_valid(existing_host) and existing_host is Control and cont_parent is PanelContainer:
				host_ctrl = existing_host as Control
				host_ctrl.custom_minimum_size = Vector2.ZERO
				host_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				host_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			else:
				var wrapper := Control.new()
				wrapper.name = "AvatarInnerHost"
				wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if cont_parent is PanelContainer:
					wrapper.custom_minimum_size = Vector2.ZERO
					wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
				else:
					var min_sz: Vector2 = avatar_rect.custom_minimum_size
					if min_sz.x <= 0.0 or min_sz.y <= 0.0:
						min_sz = cont_parent.custom_minimum_size
					if min_sz.x <= 0.0 or min_sz.y <= 0.0:
						min_sz = Vector2(102.0, 102.0)
					else:
						var sq_w: float = maxf(min_sz.x, min_sz.y) + 6.0
						min_sz = Vector2(sq_w, sq_w)
					wrapper.custom_minimum_size = min_sz
					wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var idx: int = avatar_rect.get_index()
				cont_parent.add_child(wrapper)
				cont_parent.move_child(wrapper, idx)
				avatar_rect.reparent(wrapper, false)
				host_ctrl = wrapper
		elif p_node is Control:
			host_ctrl = p_node as Control
			if not host_ctrl.has_meta("_av_box_boosted") and host_ctrl.custom_minimum_size.x > 0.0 and host_ctrl.custom_minimum_size.y > 0.0:
				var sq_h: float = maxf(host_ctrl.custom_minimum_size.x, host_ctrl.custom_minimum_size.y) + 6.0
				host_ctrl.custom_minimum_size = Vector2(sq_h, sq_h)
				host_ctrl.set_meta("_av_box_boosted", true)
			if host_ctrl.get_parent() is Container:
				if host_ctrl.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
					host_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				if host_ctrl.size_flags_vertical != Control.SIZE_EXPAND_FILL:
					host_ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		for legacy_name2 in ["AvatarRing", "AvatarMedallionFrame", "WoodDisc", "BgDisc", "PlayerSideTag"]:
			var leg2: Node = host_ctrl.get_node_or_null(legacy_name2)
			if is_instance_valid(leg2) and leg2 is CanvasItem:
				(leg2 as CanvasItem).visible = false

		# Crucial: clear custom_minimum_size on avatar_rect and match 1:1 normalized coords inside square host_ctrl
		avatar_rect.custom_minimum_size = Vector2.ZERO
		avatar_rect.anchor_left = ap.x
		avatar_rect.anchor_top = ap.y
		avatar_rect.anchor_right = ap.z
		avatar_rect.anchor_bottom = ap.w
		avatar_rect.offset_left = 0.0
		avatar_rect.offset_top = 0.0
		avatar_rect.offset_right = 0.0
		avatar_rect.offset_bottom = 0.0
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_SCALE
		avatar_rect.material = _get_avatar_aperture_material(safe_fid)

	if not is_instance_valid(host_ctrl):
		return null

	var frame_node: Node = host_ctrl.get_node_or_null("FrameOverlay")
	var frame_rect: TextureRect = null
	if is_instance_valid(frame_node) and frame_node is TextureRect:
		frame_rect = frame_node as TextureRect
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_rect.offset_left = 0.0
		frame_rect.offset_top = 0.0
		frame_rect.offset_right = 0.0
		frame_rect.offset_bottom = 0.0
	else:
		frame_rect = TextureRect.new()
		frame_rect.name = "FrameOverlay"
		frame_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_rect.offset_left = 0.0
		frame_rect.offset_top = 0.0
		frame_rect.offset_right = 0.0
		frame_rect.offset_bottom = 0.0
		frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host_ctrl.add_child(frame_rect)

	frame_rect.texture = get_frame_texture(safe_fid)
	# Move frame above avatar, keeping profile buttons (BaseButton) on top for clicks
	host_ctrl.move_child(frame_rect, host_ctrl.get_child_count() - 1)
	for ch in host_ctrl.get_children():
		if ch is Label or ch is BaseButton:
			host_ctrl.move_child(ch, host_ctrl.get_child_count() - 1)
	return frame_rect


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


static func make_status_badge(status: String, custom_h: float = 37.0) -> Control:
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
		lbl.add_theme_font_size_override("font_size", 23)
		lbl.add_theme_color_override("font_color", COL_IVORY)
		lbl.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.01, 0.92))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_constant_override("shadow_outline_size", 2)
		hbox.add_child(lbl)

	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


static func make_badge_pill(txt: String, text_col: Color = COL_GOLD_BRIGHT, bg_col: Color = Color(0.10, 0.06, 0.03, 0.94), border_col: Color = Color(0.75, 0.58, 0.25, 0.80), font_size: int = 22) -> PanelContainer:
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
		box.add_child(make_body(right_text, 21, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

	return box


static func make_empty_state(
	icon_tex: Texture2D,
	title_txt: String,
	subtitle_txt: String,
	cta_txt: String = "",
	cta_variant: String = "gold",
	cta_cb: Callable = Callable(),
	use_frame: bool = true
) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 180)
	if use_frame:
		card.add_theme_stylebox_override("panel", create_frame_style(true, 42.0, 32.0))
	else:
		card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

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

	vbox.add_child(make_title(title_txt, 31, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not subtitle_txt.is_empty():
		vbox.add_child(make_body(subtitle_txt, 24, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	if not cta_txt.is_empty() and cta_cb.is_valid():
		var btn := make_button(cta_txt, cta_variant, Vector2(240, 56), 26)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			cta_cb.call()
		)
		vbox.add_child(btn)

	return card


static func make_loading_state(msg: String = "در حال بارگذاری...") -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 148)
	p.add_theme_stylebox_override("panel", create_frame_style(true, 40.0, 28.0))
	var lbl := make_body(msg, 26, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
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
	var dlg_sz: Vector2 = UITypography.compute_dialog_size(620.0, 0.0, Vector2.ZERO, UITypography.get_safe_insets())
	card.custom_minimum_size = Vector2(dlg_sz.x, 0)
	card.add_theme_stylebox_override("panel", create_dialog_frame_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	m.add_child(vbox)

	vbox.add_child(make_title(title_txt, 30, COL_CRIMSON_TEXT if is_danger else COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	vbox.add_child(make_body(body_txt, 22, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var b_cancel := make_button("انصراف", "bronze", Vector2(180, 54), 22)
	b_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
	)
	btn_row.add_child(b_cancel)

	var b_ok := make_button(confirm_txt, "crimson" if is_danger else "emerald", Vector2(180, 54), 22)
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
	var local_dt := GameManager.parse_server_iso_to_local(iso_str)
	if not local_dt.is_empty() and bool(local_dt.get("has_time", false)):
		var time_part := "%02d:%02d" % [int(local_dt["hour"]), int(local_dt["minute"])]
		return GameManager.to_fa_num(time_part)
	return ""


static func gregorian_to_jalali(gy: int, gm: int, gd: int) -> Dictionary:
	var g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var jy: int
	if gy > 1600:
		jy = 979
		gy -= 1600
	else:
		jy = 0
		gy -= 621
	var gy2 = gy + 1 if gm > 2 else gy
	var days = 365 * gy + int((gy2 + 3) / 4) - int((gy2 + 99) / 100) + int((gy2 + 399) / 400) - 80 + gd + g_d_m[gm - 1]
	jy += 33 * int(days / 12053)
	days %= 12053
	jy += 4 * int(days / 1461)
	days %= 1461
	if days > 365:
		jy += int((days - 1) / 365)
		days = (days - 1) % 365
	var jm: int
	var jd: int
	if days < 186:
		jm = 1 + int(days / 31)
		jd = 1 + (days % 31)
	else:
		jm = 7 + int((days - 186) / 30)
		jd = 1 + ((days - 186) % 30)
	return {"year": jy, "month": jm, "day": jd}


static func format_chat_datetime_fa(iso_str: String) -> String:
	var s := iso_str.strip_edges()
	if s.is_empty():
		return ""
	var local_dt := GameManager.parse_server_iso_to_local(s)
	if not local_dt.is_empty():
		var gy := int(local_dt["year"])
		var gm := int(local_dt["month"])
		var gd := int(local_dt["day"])
		var time_part := ""
		if bool(local_dt.get("has_time", false)):
			time_part = "%02d:%02d" % [int(local_dt["hour"]), int(local_dt["minute"])]
		if gy > 1900:
			var j = gregorian_to_jalali(gy, gm, gd)
			var month_names = [
				"فروردین", "اردیبهشت", "خرداد",
				"تیر", "مرداد", "شهریور",
				"مهر", "آبان", "آذر",
				"دی", "بهمن", "اسفند"
			]
			var m_name = month_names[j["month"] - 1] if j["month"] >= 1 and j["month"] <= 12 else ""
			var dt_formatted := "%s %s" % [GameManager.to_fa_num(j["day"]), m_name]
			if not time_part.is_empty():
				return "%s - %s" % [dt_formatted, GameManager.to_fa_num(time_part)]
			return dt_formatted
		if not time_part.is_empty():
			return GameManager.to_fa_num(time_part)
	return GameManager.to_fa_num(s)


static func format_shamsi_datetime_fa(iso_str: String) -> String:
	return format_chat_datetime_fa(iso_str)



static func get_game_thumb(game_type: String) -> Texture2D:
	var key := game_type.strip_edges().to_lower()
	if key.is_empty():
		return null
	if _game_thumb_cache.has(key):
		return _game_thumb_cache[key] as Texture2D
	var tex: Texture2D = null
	var png_p := "res://assets/images/games/%s.png" % key
	if ResourceLoader.exists(png_p):
		tex = load(png_p) as Texture2D
	else:
		var jpg_p := "res://assets/images/games/%s.jpg" % key
		if ResourceLoader.exists(jpg_p):
			tex = load(jpg_p) as Texture2D
	_game_thumb_cache[key] = tex
	return tex


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
	var dlg_sz: Vector2 = UITypography.compute_dialog_size(640.0, 960.0, Vector2.ZERO, UITypography.get_safe_insets())
	card.custom_minimum_size = Vector2(dlg_sz.x, 0)
	card.add_theme_stylebox_override("panel", create_dialog_frame_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	var btn_x := TextureButton.new()
	btn_x.texture_normal = TEX_CLOSE
	btn_x.custom_minimum_size = Vector2(48, 48)
	btn_x.ignore_texture_size = true
	btn_x.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_x.focus_mode = Control.FOCUS_NONE
	ActionVFXManager.apply_button_juice(btn_x, "tap_button")
	btn_x.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top_row.add_child(btn_x)

	var ttl := make_title("دعوت «%s» به مسابقه دوستانه" % target_name, 28, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(48, 48)
	top_row.add_child(sp)

	vbox.add_child(make_body("بازی مورد نظر خود را برای ارسال دعوت‌نامه مستقیم انتخاب کنید:", 19, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var g_scroll := ScrollContainer.new()
	g_scroll.custom_minimum_size = Vector2(0, clampf(UITypography.get_viewport_size().y * 0.40, 260.0, 520.0))
	g_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(g_scroll)

	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	g_scroll.add_child(grid)

	var all_invite_games: Array[String] = [
		GameTypes.TIC_TAC_TOE,
		GameTypes.CHESS,
		GameTypes.BACKGAMMON,
		GameTypes.CHECKERS,
		GameTypes.FOURINROW,
		GameTypes.OTHELLO,
		GameTypes.MILL,
		GameTypes.DOTBOX,
		GameTypes.PENTAGO,
		GameTypes.YINSH,
		GameTypes.QUORIDOR,
		GameTypes.YATZY,
		GameTypes.LUDO,
		GameTypes.RISK,
		GameTypes.UNO,
		GameTypes.COUP,
		GameTypes.MONOPOLY,
		GameTypes.QUIZ,
		GameTypes.BATTLESHIP,
		GameTypes.FEKRBEKR,
		GameTypes.RPC,
		GameTypes.SUDOKU,
		GameTypes.BOXFOUR,
		GameTypes.MNUMBERS,
		GameTypes.MSWEEPER,
	]

	for gid in all_invite_games:
		var gtitle: String = GameRegistry.get_display_name_fa(gid)
		var gbtn := Button.new()
		gbtn.custom_minimum_size = Vector2(0, 82)
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

		var lbl_go := make_body("دعوت", 22, COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
		lbl_go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grow.add_child(lbl_go)

		var lbl_g := make_title(gtitle, 29, COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
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
	var dlg_sz: Vector2 = UITypography.compute_dialog_size(620.0, 0.0, Vector2.ZERO, UITypography.get_safe_insets())
	card.custom_minimum_size = Vector2(dlg_sz.x, 0)
	card.add_theme_stylebox_override("panel", create_dialog_frame_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	vbox.add_child(make_title("گزارش تخلف: %s" % target_name, 30, COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	vbox.add_child(make_body("لطفاً دلیل گزارش را انتخاب کنید تا توسط تیم نظارت بررسی شود:", 20, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_details := make_line_edit("توضیحات تکمیلی (اختیاری)...", 52.0, 22)
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
		var rb := make_button(r["label"], "muted", Vector2(0, 48), 21)
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
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var b_cancel := make_button("انصراف", "bronze", Vector2(180, 52), 22)
	b_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		overlay.queue_free()
	)
	btn_row.add_child(b_cancel)

	var b_send := make_button("ثبت گزارش", "crimson", Vector2(200, 52), 22)
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


static func show_clan_details_modal(host: Node, clan_id: String, initial_data: Dictionary = {}) -> Control:
	var overlay := Control.new()
	overlay.name = "ClanDetailsModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 80

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.82)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var card := PanelContainer.new()
	var dlg_sz: Vector2 = UITypography.compute_dialog_size(640.0, 960.0, Vector2.ZERO, UITypography.get_safe_insets())
	card.custom_minimum_size = Vector2(dlg_sz.x, 0)
	card.add_theme_stylebox_override("panel", create_dialog_frame_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	# 1. Top bar with close button and title
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

	var ttl := make_title("مشخصات کلن", 34, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(54, 54)
	top_row.add_child(sp)

	# Content Holder for live updating
	var content_holder := VBoxContainer.new()
	content_holder.add_theme_constant_override("separation", 16)
	vbox.add_child(content_holder)

	var populate_clan_ui = func(data: Dictionary):
		for c in content_holder.get_children():
			c.queue_free()

		var cname := str(data.get("name", "کلن کافه فکر"))
		var ctag := str(data.get("tag", ""))
		var emb_id := int(data.get("emblem_id", 1))
		var clvl := int(data.get("clan_level", 1))
		var cscore := int(data.get("clan_score", 0))
		var mem_cnt := int(data.get("member_count", 1))
		var max_mem := int(data.get("max_members", 50))
		var jtype := str(data.get("join_type", "open"))
		var jtype_fa := "آزاد" if jtype == "open" else "نیازمند تأیید درخواست"
		var desc := str(data.get("description", data.get("desc", "")))
		var leader_name := str(data.get("leader_name", data.get("leader_username", "")))

		# Hero Header
		var hero := PanelContainer.new()
		hero.custom_minimum_size = Vector2(0, 184)
		hero.add_theme_stylebox_override("panel", create_clan_top_header_style())
		content_holder.add_child(hero)

		var h_row := HBoxContainer.new()
		h_row.add_theme_constant_override("separation", 18)
		hero.add_child(h_row)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		info_vbox.add_theme_constant_override("separation", 6)
		h_row.add_child(info_vbox)

		var title_row := HBoxContainer.new()
		title_row.alignment = BoxContainer.ALIGNMENT_END
		title_row.add_theme_constant_override("separation", 10)
		info_vbox.add_child(title_row)

		if not ctag.is_empty():
			title_row.add_child(make_badge_pill("[%s]" % ctag, COL_GOLD_BRIGHT, Color(0.12, 0.08, 0.04), COL_GOLD_ANTIQUE, 20))

		var name_lbl := make_title(cname, 34, COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_lbl)

		if not leader_name.is_empty():
			info_vbox.add_child(make_body("رهبر کلن: %s" % leader_name, 22, COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

		if not desc.is_empty():
			info_vbox.add_child(make_body("«%s»" % desc, 21, COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
		else:
			info_vbox.add_child(make_body("باشگاه رسمی اعضای کافه فکر", 20, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

		h_row.add_child(make_clan_emblem(emb_id, 96.0))

		# Metrics Grid / Row
		var chips_row := HBoxContainer.new()
		chips_row.add_theme_constant_override("separation", 10)
		content_holder.add_child(chips_row)

		var make_chip = func(label_txt: String, val_txt: String, accent: Color) -> PanelContainer:
			var cp := PanelContainer.new()
			cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cp.add_theme_stylebox_override("panel", create_well_style(14, 10.0, 10.0))
			var cv := VBoxContainer.new()
			cv.alignment = BoxContainer.ALIGNMENT_CENTER
			cv.add_theme_constant_override("separation", 2)
			cp.add_child(cv)
			cv.add_child(make_title(val_txt, 27, accent, HORIZONTAL_ALIGNMENT_CENTER, false))
			cv.add_child(make_body(label_txt, 19, COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false))
			return cp

		chips_row.add_child(make_chip.call("سطح کلن", GameManager.to_fa_num(clvl), COL_EMERALD_TEXT))
		chips_row.add_child(make_chip.call("مجموع امتیاز", GameManager.to_fa_num(cscore), COL_GOLD_BRIGHT))
		chips_row.add_child(make_chip.call("اعضای کلن", "%s / %s" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], COL_IVORY))
		chips_row.add_child(make_chip.call("نوع پذیرش", jtype_fa, COL_WARM_CREAM))

		# Action buttons row
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 16)
		content_holder.add_child(btn_row)

		var b_close := make_button("بستن", "bronze", Vector2(180, 56), 23)
		b_close.pressed.connect(func():
			AudioManager.sfx_tap()
			overlay.queue_free()
		)
		btn_row.add_child(b_close)

		# Join or Navigate button
		var cid_str := str(data.get("clan_id", data.get("_id", clan_id)))
		if not cid_str.is_empty():
			var b_join := make_button("عضویت در کلن" if jtype == "open" else "ارسال درخواست عضویت", "emerald", Vector2(240, 56), 23)
			b_join.pressed.connect(func():
				AudioManager.sfx_button()
				b_join.disabled = true
				NetworkManager.api.join_or_request_clan(cid_str, "", func(ok_j: bool, _cj: int, dj: Variant):
					if ok_j:
						if is_instance_valid(overlay):
							overlay.queue_free()
						if is_instance_valid(host) and host.has_method("refresh_my_clan_data"):
							host.current_clans_subtab = "my_clan"
							host.refresh_my_clan_data(true)
						else:
							var shell: Node = host.get_tree().root.find_child("MainTabShell", true, false)
							if shell and shell.has_method("switch_to_tab"):
								shell.switch_to_tab("social")
							else:
								var s_dlg: Node = host.get_tree().root.find_child("SocialDialog", true, false)
								if s_dlg and s_dlg.has_method("open"):
									s_dlg.open("clans")
					elif typeof(dj) == TYPE_DICTIONARY:
						if is_instance_valid(b_join):
							b_join.disabled = false
				)
			)
			btn_row.add_child(b_join)

	populate_clan_ui.call(initial_data)

	# Fetch live details
	var fetch_id := str(initial_data.get("clan_id", initial_data.get("_id", clan_id)))
	if not fetch_id.is_empty():
		NetworkManager.api.get_clan_details(fetch_id, func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(overlay) or not overlay.is_inside_tree():
				return
			if ok and typeof(data) == TYPE_DICTIONARY:
				var res = data.get("result", {})
				if typeof(res) == TYPE_DICTIONARY and typeof(res.get("clan")) == TYPE_DICTIONARY and not res["clan"].is_empty():
					var c_info: Dictionary = res["clan"]
					for k in initial_data.keys():
						if not c_info.has(k):
							c_info[k] = initial_data[k]
					populate_clan_ui.call(c_info)
		)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
	return overlay


# ==============================================================================
# WARM CLASSIC PARLOR CONTROLS (Tabs, Sliders, Toggles)
# ==============================================================================

static var _parlor_slider_grabber_cache: Dictionary = {}
static var _parlor_toggle_icon_cache: Dictionary = {}


static func style_parlor_tab_button(btn: Button, is_active: bool, font_size: int = 18, clip: bool = false, pad_x: float = 24.0, pad_y: float = 10.0) -> void:
	if not is_instance_valid(btn):
		return
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = clip
	if clip:
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var norm_sz: int = UITypography.normalize_raw_px(font_size)
	btn.set_meta(&"_resp_base_px", norm_sz)
	btn.set_meta(&"_resp_min_px", 16)
	btn.set_meta(&"_resp_max_px", maxi(28, norm_sz))
	btn.add_theme_font_override("font", FONT_TITLE)
	btn.add_theme_font_size_override("font_size", UITypography.scale_px(norm_sz, 16, maxi(28, norm_sz)))

	var make_frame_sb := func(mod_col: Color) -> StyleBoxTexture:
		var sb := StyleBoxTexture.new()
		sb.texture = TEX_FRAME2
		sb.texture_margin_left = 40.0
		sb.texture_margin_top = 24.0
		sb.texture_margin_right = 40.0
		sb.texture_margin_bottom = 24.0
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.modulate_color = mod_col
		return sb

	if is_active:
		var col_active := Color(1.0, 0.98, 0.90, 1.0)
		var col_hover := Color(1.10, 1.05, 0.95, 1.0)
		var col_press := Color(0.85, 0.82, 0.78, 1.0)
		btn.add_theme_stylebox_override("normal", make_frame_sb.call(col_active))
		btn.add_theme_stylebox_override("hover", make_frame_sb.call(col_hover))
		btn.add_theme_stylebox_override("pressed", make_frame_sb.call(col_press))
		btn.add_theme_stylebox_override("focus", make_frame_sb.call(col_active))

		var cream_txt := Color("#FFF7E0")
		btn.add_theme_color_override("font_color", cream_txt)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_pressed_color", cream_txt)
		btn.add_theme_color_override("font_focus_color", cream_txt)
		btn.add_theme_color_override("font_shadow_color", Color(0.06, 0.03, 0.01, 0.96))
		btn.add_theme_constant_override("shadow_offset_x", 0)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		btn.add_theme_constant_override("shadow_outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color(0.11, 0.05, 0.01, 0.94))
		btn.add_theme_constant_override("outline_size", 2)
	else:
		var col_inactive := Color(0.58, 0.52, 0.46, 0.85)
		var col_hover := Color(0.72, 0.65, 0.58, 0.92)
		var col_press := Color(0.48, 0.44, 0.38, 0.80)
		btn.add_theme_stylebox_override("normal", make_frame_sb.call(col_inactive))
		btn.add_theme_stylebox_override("hover", make_frame_sb.call(col_hover))
		btn.add_theme_stylebox_override("pressed", make_frame_sb.call(col_press))
		btn.add_theme_stylebox_override("focus", make_frame_sb.call(col_inactive))

		var tan_txt := Color("#CBB89D")
		btn.add_theme_color_override("font_color", tan_txt)
		btn.add_theme_color_override("font_hover_color", Color("#EFE2CB"))
		btn.add_theme_color_override("font_pressed_color", tan_txt)
		btn.add_theme_color_override("font_focus_color", tan_txt)
		btn.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.01, 0.80))
		btn.add_theme_constant_override("shadow_offset_x", 0)
		btn.add_theme_constant_override("shadow_offset_y", 1)
		btn.add_theme_constant_override("shadow_outline_size", 1)
		btn.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 0.65))
		btn.add_theme_constant_override("outline_size", 1)


static func _get_gold_grabber_texture(diameter: int, highlight: bool, disabled: bool = false) -> ImageTexture:
	var key := "%d_%s_%s" % [diameter, str(highlight), str(disabled)]
	if _parlor_slider_grabber_cache.has(key):
		return _parlor_slider_grabber_cache[key] as ImageTexture

	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c: float = (float(diameter) - 1.0) * 0.5
	var r_outer: float = float(diameter) * 0.5 - 1.0
	var r_rim: float = r_outer - 2.2
	var r_inner: float = r_outer - 5.2

	var rim_col: Color = Color("#4A2B12") if disabled else Color("#4C2B0E")
	var gold_outer: Color = Color("#8C7352") if disabled else (Color("#FFE27A") if highlight else Color("#E5A93B"))
	var gold_center: Color = Color("#A89070") if disabled else (Color("#FFF4C2") if highlight else Color("#F5C542"))

	for y in range(diameter):
		var dy: float = float(y) - c
		for x in range(diameter):
			var dx: float = float(x) - c
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > r_outer + 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var aa: float = clampf(r_outer - dist + 0.5, 0.0, 1.0)
			var col: Color
			if dist > r_rim:
				col = rim_col
			else:
				var t: float = clampf(dist / maxf(1.0, r_rim), 0.0, 1.0)
				# Slight top-left brushed-gold sheen
				var sheen: float = clampf((-dx - dy) / (r_rim * 2.2) + 0.35, 0.0, 1.0)
				col = gold_center.lerp(gold_outer, t * 0.78)
				col = col.lightened(sheen * 0.16)
				if dist < r_inner and dist > r_inner - 1.2:
					col = col.darkened(0.14)
			col.a = aa * (0.65 if disabled else 1.0)
			img.set_pixel(x, y, col)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_parlor_slider_grabber_cache[key] = tex
	return tex


static func style_parlor_slider(slider: HSlider) -> void:
	if not is_instance_valid(slider):
		return
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var track := StyleBoxFlat.new()
	track.bg_color = Color("#26140B")
	track.border_color = Color("#634125")
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#E5A93B")
	fill.border_color = Color("#F5C542")
	fill.border_width_top = 1
	fill.border_width_bottom = 1
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 6.0
	fill.content_margin_bottom = 6.0

	var fill_hi: StyleBoxFlat = fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = Color("#F5C542")

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	slider.add_theme_icon_override("grabber", _get_gold_grabber_texture(24, false, false))
	slider.add_theme_icon_override("grabber_highlight", _get_gold_grabber_texture(26, true, false))
	slider.add_theme_icon_override("grabber_disabled", _get_gold_grabber_texture(24, false, true))


static func _get_parlor_toggle_texture(is_on: bool, mirrored: bool = false, disabled: bool = false) -> ImageTexture:
	var key := "%s_%s_%s" % [str(is_on), str(mirrored), str(disabled)]
	if _parlor_toggle_icon_cache.has(key):
		return _parlor_toggle_icon_cache[key] as ImageTexture

	var w: int = 58
	var h: int = 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rad: float = float(h) * 0.5 - 1.0
	var cy: float = (float(h) - 1.0) * 0.5
	var left_cx: float = rad + 1.0
	var right_cx: float = float(w) - 1.0 - rad - 1.0

	var track_bg: Color = Color("#1F7A3E") if is_on else Color("#2E1A10")
	var track_bdr: Color = Color("#F5C542") if is_on else Color("#6B4729")
	var knob_col: Color = Color("#FFF4D2") if is_on else Color("#CBB89D")
	var knob_rim: Color = Color("#D49B2A") if is_on else Color("#4F321B")

	var knob_on_right: bool = (not mirrored) if is_on else mirrored
	var knob_cx: float = right_cx if knob_on_right else left_cx
	var knob_r: float = rad - 3.2

	for y in range(h):
		var dy: float = float(y) - cy
		for x in range(w):
			var fx: float = float(x)
			# Signed distance to capsule (pill)
			var clamped_x: float = clampf(fx, left_cx, right_cx)
			var dist_pill: float = sqrt((fx - clamped_x) * (fx - clamped_x) + dy * dy)
			if dist_pill > rad + 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var pill_aa: float = clampf(rad - dist_pill + 0.5, 0.0, 1.0)
			var base_col: Color = track_bdr if dist_pill > (rad - 2.0) else track_bg
			# Subtle top highlight on track interior
			if dist_pill <= (rad - 2.0) and dy < 0.0:
				base_col = base_col.lightened(clampf(-dy / rad, 0.0, 1.0) * 0.08)

			# Circular knob
			var dist_knob: float = sqrt((fx - knob_cx) * (fx - knob_cx) + dy * dy)
			var final_col: Color = base_col
			if dist_knob <= knob_r + 1.0:
				var k_aa: float = clampf(knob_r - dist_knob + 0.5, 0.0, 1.0)
				var k_col: Color = knob_rim if dist_knob > (knob_r - 1.6) else knob_col
				if dist_knob <= (knob_r - 1.6):
					var k_sheen: float = clampf((-(fx - knob_cx) - dy) / (knob_r * 2.5) + 0.35, 0.0, 1.0)
					k_col = k_col.lightened(k_sheen * 0.14)
				final_col = base_col.lerp(k_col, k_aa)

			final_col.a = pill_aa * (0.55 if disabled else 1.0)
			img.set_pixel(x, y, final_col)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_parlor_toggle_icon_cache[key] = tex
	return tex


static func style_parlor_check_button(cb: CheckButton) -> void:
	if not is_instance_valid(cb):
		return
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cb.flat = true

	var empty_sb := StyleBoxEmpty.new()
	cb.add_theme_stylebox_override("normal", empty_sb)
	cb.add_theme_stylebox_override("hover", empty_sb)
	cb.add_theme_stylebox_override("pressed", empty_sb)
	cb.add_theme_stylebox_override("focus", empty_sb)
	cb.add_theme_stylebox_override("disabled", empty_sb)
	cb.add_theme_stylebox_override("hover_pressed", empty_sb)

	cb.add_theme_icon_override("checked", _get_parlor_toggle_texture(true, false, false))
	cb.add_theme_icon_override("unchecked", _get_parlor_toggle_texture(false, false, false))
	cb.add_theme_icon_override("checked_mirrored", _get_parlor_toggle_texture(true, true, false))
	cb.add_theme_icon_override("unchecked_mirrored", _get_parlor_toggle_texture(false, true, false))
	cb.add_theme_icon_override("checked_disabled", _get_parlor_toggle_texture(true, false, true))
	cb.add_theme_icon_override("unchecked_disabled", _get_parlor_toggle_texture(false, false, true))
	cb.add_theme_icon_override("checked_disabled_mirrored", _get_parlor_toggle_texture(true, true, true))
	cb.add_theme_icon_override("unchecked_disabled_mirrored", _get_parlor_toggle_texture(false, true, true))

	cb.add_theme_color_override("font_color", COL_IVORY)
	cb.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT)
	cb.add_theme_color_override("font_pressed_color", COL_GOLD_BRIGHT)
	cb.add_theme_color_override("font_hover_pressed_color", COL_GOLD_BRIGHT)


