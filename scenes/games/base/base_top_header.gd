class_name BaseTopHeader
extends Control

# Base Top Header for Cafe Fekr — Warm Classic Parlor Shared HUD (Godot 4 Mobile Portrait)
# Features:
# - Single compact Top Row: 2D/3D View Toggle (Left) | Dynamic PlayersContainer (Center) | Settings (Right)
# - Player Mode: Local player card is removed completely; Opponents Only are shown (1-pod horizontal pill in 2P, 2-3 vertical pods in 3-4P)
# - Spectator Mode: All 2-4 players shown (2-3 standard vertical, or 4 ultra-compact vertical)
# - Vertical Social Rail tucked directly beneath Settings button (Chat & Emoji 38x38px with 8px gap)
# - Tiny Spectator Pill below 2D button when spectating
# - Dual Visual Turn & Timer System (digits removed):
#     - Active opponent turn: clockwise radial gold progress ring on avatar (turns danger red <4s)
#     - Local player turn: slim 4px gold progress bar below header + centered floating pill "نوبت شما" + bottom edge glow
# - 100% empty and pass-through bottom area for board/card gameplay
# - Strict backwards-compatibility: legacy nodes (p1_card, p2_card, match_details_box, lbl_timer) preserved and hidden

signal view_mode_toggled(is_2d: bool)
signal chat_pressed(anchor_btn: Button)
signal emoji_pressed(anchor_btn: Button)
signal menu_requested()
signal player_profile_clicked(player_index: int)
signal p1_profile_clicked()
signal p2_profile_clicked()
signal header_height_changed(new_height: float)

const CARD_HEIGHT_2P := 42.0
const CARD_HEIGHT_MULTI := 58.0
const MENU_COL_WIDTH := 40.0
const POD_SCENE_PATH := "res://scenes/games/base/player_pod.tscn"

const KORIS: Array[String] = [
	"شکست دیگه عادتت شده!",
	"عجب حرکت هوشمندانه‌ای بود!",
	"برنده فقط منم!",
	"بازی شروع نشده، تمومه!",
	"خیلی خوب بازی کردی!",
	"حریف من نیستی!",
	"بازم بردم!",
	"اون استراتژی عالی بود!",
	"قهرمان برگشته!",
	"این فقط تمرین بود!",
	"خوشم اومد از سبک بازیت!",
	"یه باخت دیگه تو کارنامت!",
	"بهتره تسلیم شی!",
	"آفرین!",
	"سریع‌تر از اینم می‌بازی؟",
	"حیف وقتی که گذاشتی!",
	"حرکتت واقعاً تحسین‌برانگیز بود!",
	"بهتره تمرین کنی!",
	"حالا یاد گرفتی؟",
	"ممنونم!",
	"راحت‌تر از این نبود!",
	"این فقط شروعشه!",
	"اون تاکتیک خیلی جالب بود!",
	"تو حتی نزدیک هم نشدی!",
	"پایانش همین بود؟",
	"این یکی رو عالی مدیریت کردی!",
	"بازم دیر کردی!",
	"این برد مال منه!",
	"ایده خوبی داشتی، بهش ادامه بده!",
	"مثل همیشه برنده!",
	"یک حرکت و تموم!",
	"این حرکت غیرمنتظره بود",
	"بازی رو یاد بگیر!",
	"بهترین بودن سخته!",
	"خیلی خوب مسیر بازی رو تغییر دادی!",
	"حریف من نیستی!",
	"دوباره باختی!",
	"این تاکتیکت واقعاً کارساز بود!",
	"تو از اول هم شانسی نداشتی!",
	"بردم، طبق معمول!",
	"پیشرفتت تو این بازی محسوسه!",
	"تسلیم شو، هنوز وقت داری!",
	"بازم ساده بردم!",
	"خیلی خوب کنترل کردی اوضاع رو!",
	"این فقط یه گرم کردن بود!",
	"قهرمان برگشت!",
	"اون تصمیم واقعاً درست بود!",
	"دیر رسیدی به بازی!",
	"بازی کردن با تو وقت تلف کردنه!",
	"حرکت نهایی‌ات خیلی قوی بود!",
	"با همین سرعت می‌بازی!",
	"یه کلاس درس دیگه برات بود!",
	"این راندو خیلی حرفه‌ای زدی!",
	"هنوز مونده تا به من برسی!",
	"فقط نگاه کن چطور برنده می‌شم!",
	"خیلی خوب بود!",
	"شروع نکرده باختی!",
	"پایان داستان تو همین‌جاست!",
	"عجب حرکت هوشمندانه‌ای!",
	"به همین سادگی!",
	"این فقط یک نمایش بود!",
	"عالی بازی کردی!",
	"پایان رو از الان می‌دونم!",
	"خسته نشدی از باختن؟",
	"به به!",
	"دوباره شانس داری، امتحان کن!",
	"فکر کنم هنوز نوبتت نشده!",
	"اون تاکتیک معرکه بود!",
	"بازی براتو تفریحه، برا من زندگیه!",
	"توی لیگ خودت بازی کن!",
	"چقد خوب دفاع کردی!",
	"این بود تمام توانت؟",
	"امروز روز تو نبود!",
	"بازی خفنی کردی!",
	"شاید دفعه بعد!",
	"باید تلاش بیشتری کنی!",
	"ایده فوق‌العاده‌ای بود!",
	"هنوز اول راحته!"
]

@export var show_timer_digits: bool = false
@export var opponent_only_mode: bool = true

# --- Modern Balanced Top Row & Pure Icon Controls ---
@onready var top_row: HBoxContainer = $Margin/VBoxMain/TopRow
@onready var btn_settings: Button = $Margin/VBoxMain/TopRow/BtnSettings
@onready var btn_view_2d3d: Button = $Margin/VBoxMain/TopRow/BtnView2D3D
@onready var img_view_2d3d: TextureRect = $Margin/VBoxMain/TopRow/BtnView2D3D/Icon
@onready var players_container: HBoxContainer = $Margin/VBoxMain/TopRow/PlayersContainer
@onready var btn_chat: Button = $Margin/VBoxMain/TopRow/BtnChat
@onready var btn_emoji: Button = $Margin/VBoxMain/TopRow/BtnEmoji

@onready var match_meta_ribbon: PanelContainer = $Margin/VBoxMain/MatchMetaRibbon
@onready var lbl_match_meta: Label = $Margin/VBoxMain/MatchMetaRibbon/LblMatchMeta

@onready var local_turn_bar_wrap: MarginContainer = $Margin/VBoxMain/LocalTurnBarWrap
@onready var local_turn_bar: ProgressBar = $Margin/VBoxMain/LocalTurnBarWrap/LocalTurnVBox/LocalTurnProgressBar
@onready var local_turn_pill: PanelContainer = $Margin/VBoxMain/LocalTurnBarWrap/LocalTurnVBox/LocalTurnPillCenter/LocalTurnPill
@onready var lbl_local_turn: Label = $Margin/VBoxMain/LocalTurnBarWrap/LocalTurnVBox/LocalTurnPillCenter/LocalTurnPill/LblLocalTurn

@onready var edge_overlay: Control = $EdgeOverlay
@onready var spectator_pill: PanelContainer = $EdgeOverlay/SpectatorPill
@onready var lbl_spectator: Label = $EdgeOverlay/SpectatorPill/HBox/LblSpectator
@onready var penalty_details_box: PanelContainer = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox
@onready var opp_dot1: Panel = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/OppRow/OppDots/OppDot1
@onready var opp_dot2: Panel = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/OppRow/OppDots/OppDot2
@onready var lbl_opp_penalty: Label = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/OppRow/LblOppCount
@onready var my_dot1: Panel = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/MyRow/MyDots/MyDot1
@onready var my_dot2: Panel = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/MyRow/MyDots/MyDot2
@onready var lbl_my_penalty: Label = $Margin/VBoxMain/BelowTimerRow/PenaltyDetailsBox/VBox/MyRow/LblMyCount
@onready var match_result_box: PanelContainer = $Margin/VBoxMain/BelowTimerRow/MatchResultBox
@onready var lbl_result_title: Label = $Margin/VBoxMain/BelowTimerRow/MatchResultBox/HBox/LblResultTitle
@onready var lbl_result_score: Label = $Margin/VBoxMain/BelowTimerRow/MatchResultBox/HBox/LblResultScore
var social_rail: VBoxContainer = null

@onready var bottom_turn_glow: TextureRect = $BottomTurnGlow

# --- Legacy Player 1 & 2 Nodes (kept for 100% backwards compatibility) ---
@onready var p1_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P1Card
@onready var p1_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/Avatar
@onready var p1_name: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/Name
@onready var p1_role_badge: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/RoleBadge
@onready var p1_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/ScoreBadge/Score
@onready var _p1_score_badge: PanelContainer = $Margin/VBoxMain/PlayersRow/P1Card/HBox/ScoreBadge
@onready var p1_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble
@onready var p1_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p1_profile: Button = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/BtnP1Profile

@onready var p2_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P2Card
@onready var p2_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/Avatar
@onready var p2_name: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/Name
@onready var p2_role_badge: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/RoleBadge
@onready var p2_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/ScoreBadge/Score
@onready var _p2_score_badge: PanelContainer = $Margin/VBoxMain/PlayersRow/P2Card/HBox/ScoreBadge
@onready var p2_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble
@onready var p2_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p2_profile: Button = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/BtnP2Profile

var p3_card: PanelContainer = null
var p4_card: PanelContainer = null
var _players_row2: HBoxContainer = null
var _p4_empty_spacer: Control = null
var _row2_menu_spacer: Control = null
var _extra_cards: Dictionary = {}
var _card_decorations: Dictionary = {}
var _style_card_disabled: StyleBoxFlat = null

# --- Legacy Match Details & Turn Timer Nodes (hidden) ---
@onready var match_details_box: PanelContainer = $Margin/VBoxMain/MatchDetailsBox
@onready var lbl_round: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel/LblRound
@onready var lbl_turn_banner: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnBanner
@onready var lbl_timer: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow/LblTimer
@onready var turn_timer_bar: ProgressBar = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnTimerBar

# --- Dynamic State ---
var _profile_clicks_enabled: bool = false
var _is_2d_mode: bool = false
var _current_turn: int = 1
var _my_player_index: int = 1
var _total_players: int = 2
var _safe_top_inset: int = 16
var _last_displayed_sec: int = -1
var _last_critical_sec: int = -1

var _pods_by_idx: Dictionary = {} # int (1..4) -> PlayerPod
var _cached_counters: Dictionary = {} # int -> String
var _cached_statuses: Dictionary = {} # int -> Dictionary {text, color}
var _p1_raw_data: Dictionary = {}
var _p2_raw_data: Dictionary = {}
var _extra_raw_data: Dictionary = {}
var _disabled_players: Dictionary = {} # int -> String
var _player_names: Dictionary = {
	1: "بازیکن ۱",
	2: "بازیکن ۲",
	3: "بازیکن ۳",
	4: "بازیکن ۴"
}

var _turn_toast_panel: PanelContainer = null
var _lbl_turn_toast: Label = null
var _turn_toast_seq: int = 0
var _turn_toast_tween: Tween = null
var _turn_toast_persistent: bool = false
var _bottom_glow_tween: Tween = null

static var _pod_scene: PackedScene = preload(POD_SCENE_PATH)
static var _avatar_cache: Dictionary = {}
static var _reaction_cache: Dictionary = {}
static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")
static var _font_vazir: FontFile = preload("res://assets/fonts/Vazir.ttf")
static var _tex_2d: Texture2D = preload("res://assets/images/badges/2d.png")
static var _tex_3d: Texture2D = preload("res://assets/images/badges/3d.png")
static var _tex_menu_icon: Texture2D = preload("res://assets/images/config.png")


static func _get_cached_avatar(av_id: int) -> Texture2D:
	if _avatar_cache.has(av_id):
		return _avatar_cache[av_id]
	var path = "res://assets/icons/Avatars/%d.png" % av_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		_avatar_cache[av_id] = tex
		return tex
	return null


static func _get_cached_reaction(r_id: int) -> Texture2D:
	if _reaction_cache.has(r_id):
		return _reaction_cache[r_id]
	var path = "res://assets/icons/Reactions/%d.png" % r_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		_reaction_cache[r_id] = tex
		return tex
	return null


static func _fa_digits(val: Variant) -> String:
	return HudTheme.fa_digits(val)


func set_profile_clicks_enabled(enabled: bool) -> void:
	_profile_clicks_enabled = enabled


func _can_emit_profile_click() -> bool:
	return _profile_clicks_enabled and GameManager.is_game_active


func _ready() -> void:
	_setup_styles()
	_apply_safe_area_insets()
	_setup_modern_controls()
	_connect_buttons()
	_rebuild_pods()
	if not NetworkManager.spectator_count_updated.is_connected(_on_spectator_count_updated):
		NetworkManager.spectator_count_updated.connect(_on_spectator_count_updated)
	if not GameManager.chat_and_stickers_toggled.is_connected(_on_chat_and_stickers_toggled):
		GameManager.chat_and_stickers_toggled.connect(_on_chat_and_stickers_toggled)
	set_chat_and_stickers_enabled(not GameManager.chat_and_stickers_disabled)
	update_spectator_count(GameManager.spectator_count)


func _exit_tree() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.spectator_count_updated.is_connected(_on_spectator_count_updated):
		NetworkManager.spectator_count_updated.disconnect(_on_spectator_count_updated)
	if is_instance_valid(GameManager) and GameManager.chat_and_stickers_toggled.is_connected(_on_chat_and_stickers_toggled):
		GameManager.chat_and_stickers_toggled.disconnect(_on_chat_and_stickers_toggled)


func _on_chat_and_stickers_toggled(disabled: bool) -> void:
	set_chat_and_stickers_enabled(not disabled)


func set_chat_and_stickers_enabled(enabled: bool) -> void:
	if is_instance_valid(btn_chat):
		btn_chat.visible = enabled
	if is_instance_valid(btn_emoji):
		btn_emoji.visible = enabled


func _apply_safe_area_insets() -> void:
	var insets := HudTheme.get_safe_insets(get_viewport())
	_safe_top_inset = int(insets.get("top", 16))
	var margin := get_node_or_null("Margin") as MarginContainer
	if is_instance_valid(margin):
		margin.add_theme_constant_override("margin_top", _safe_top_inset)
		margin.add_theme_constant_override("margin_left", int(insets.get("left", 10)))
		margin.add_theme_constant_override("margin_right", int(insets.get("right", 10)))
	if is_instance_valid(edge_overlay):
		var spec := edge_overlay.get_node_or_null("SpectatorPill") as Control
		if is_instance_valid(spec):
			spec.offset_top = float(_safe_top_inset) + 42.0
		var rail := edge_overlay.get_node_or_null("SocialRail") as Control
		if is_instance_valid(rail):
			rail.offset_top = float(_safe_top_inset) + 42.0
	_sync_header_height()


func _get_current_header_height() -> float:
	var bar_h: float = 24.0 if (is_instance_valid(local_turn_bar_wrap) and local_turn_bar_wrap.visible) else 0.0
	var meta_h: float = 26.0 if (is_instance_valid(match_meta_ribbon) and match_meta_ribbon.visible) else 0.0
	var has_below: bool = (is_instance_valid(penalty_details_box) and penalty_details_box.visible) or (is_instance_valid(match_result_box) and match_result_box.visible)
	var below_h: float = 34.0 if has_below else 0.0
	var row_h: float = 56.0 if _total_players <= 2 else 84.0
	return float(_safe_top_inset) + row_h + bar_h + meta_h + below_h


func _sync_header_height() -> void:
	var desired_h: float = _get_current_header_height()
	offset_bottom = desired_h
	_position_turn_toast()
	header_height_changed.emit(desired_h)


func _apply_pure_icon_button(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.flat = true
	btn.button_down.connect(func():
		btn.modulate = Color(1.35, 1.35, 1.35, 0.82)
	)
	btn.button_up.connect(func():
		btn.modulate = Color.WHITE
	)


func _setup_modern_controls() -> void:
	if is_instance_valid(btn_settings):
		_apply_pure_icon_button(btn_settings)
		btn_settings.pressed.connect(func():
			AudioManager.sfx_button()
			menu_requested.emit()
		)

	if is_instance_valid(btn_view_2d3d):
		_apply_pure_icon_button(btn_view_2d3d)
		btn_view_2d3d.pressed.connect(func():
			_is_2d_mode = not _is_2d_mode
			if is_instance_valid(img_view_2d3d):
				img_view_2d3d.texture = _tex_3d if _is_2d_mode else _tex_2d
			AudioManager.sfx_button()
			view_mode_toggled.emit(_is_2d_mode)
		)

	if is_instance_valid(btn_chat):
		_apply_pure_icon_button(btn_chat)
		btn_chat.pressed.connect(func():
			chat_pressed.emit(btn_chat)
		)

	if is_instance_valid(btn_emoji):
		_apply_pure_icon_button(btn_emoji)
		btn_emoji.pressed.connect(func():
			emoji_pressed.emit(btn_emoji)
		)

	if is_instance_valid(bottom_turn_glow):
		bottom_turn_glow.texture = HudTheme.make_bottom_edge_glow_texture()
		bottom_turn_glow.visible = false

	if is_instance_valid(spectator_pill):
		spectator_pill.add_theme_stylebox_override("panel", HudTheme.make_spectator_pill_style())
		spectator_pill.visible = GameManager.is_spectating

	var players_row := get_node_or_null("Margin/VBoxMain/PlayersRow") as Control
	if is_instance_valid(players_row):
		players_row.visible = false
		players_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(match_details_box):
		match_details_box.visible = false
		match_details_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_turn_toast()


func _setup_styles() -> void:
	if is_instance_valid(local_turn_bar):
		local_turn_bar.add_theme_stylebox_override("background", HudTheme.make_local_turn_bar_track_style())
		local_turn_bar.add_theme_stylebox_override("fill", HudTheme.make_local_turn_bar_fill_style(false))
	if is_instance_valid(local_turn_pill):
		local_turn_pill.add_theme_stylebox_override("panel", HudTheme.make_local_turn_pill_style(false))
	if is_instance_valid(lbl_local_turn):
		lbl_local_turn.text = "نوبت شما"
		HudTheme.configure_bidi_label(lbl_local_turn, false)


func _build_turn_toast() -> void:
	if is_instance_valid(_turn_toast_panel):
		return
	_turn_toast_panel = PanelContainer.new()
	_turn_toast_panel.name = "TurnStatusToast"
	_turn_toast_panel.visible = false
	_turn_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_toast_panel.z_index = 18
	_turn_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_turn_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn_toast_panel.grow_vertical = Control.GROW_DIRECTION_END
	_turn_toast_panel.add_theme_stylebox_override("panel", HudTheme.make_turn_toast_style())
	add_child(_turn_toast_panel)

	_lbl_turn_toast = Label.new()
	_lbl_turn_toast.name = "LblTurnToast"
	_lbl_turn_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font_vazir:
		_lbl_turn_toast.add_theme_font_override("font", _font_vazir)
	_lbl_turn_toast.add_theme_font_size_override("font_size", 14)
	_lbl_turn_toast.add_theme_color_override("font_color", HudTheme.COL_TEXT_GOLD)
	_lbl_turn_toast.add_theme_color_override("font_shadow_color", HudTheme.COL_SHADOW_DARK)
	_lbl_turn_toast.add_theme_constant_override("shadow_offset_y", 1)
	_lbl_turn_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_turn_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudTheme.configure_bidi_label(_lbl_turn_toast, false)
	_turn_toast_panel.add_child(_lbl_turn_toast)
	_position_turn_toast()


func _position_turn_toast() -> void:
	if not is_instance_valid(_turn_toast_panel):
		return
	var top_y: float = offset_bottom + 6.0
	_turn_toast_panel.offset_top = top_y
	_turn_toast_panel.offset_bottom = top_y + 32.0
	_turn_toast_panel.offset_left = -120.0
	_turn_toast_panel.offset_right = 120.0


func show_turn_toast(msg: String, text_color: Color = HudTheme.COL_TEXT_GOLD, persistent: bool = false, duration: float = 1.8) -> void:
	if not is_instance_valid(_turn_toast_panel) or not is_instance_valid(_lbl_turn_toast):
		return
	var trimmed := msg.strip_edges()
	if trimmed.is_empty():
		hide_turn_toast()
		return
	_turn_toast_seq += 1
	var my_seq := _turn_toast_seq
	_turn_toast_persistent = persistent
	_position_turn_toast()
	_lbl_turn_toast.text = trimmed
	_lbl_turn_toast.add_theme_color_override("font_color", text_color)

	if is_instance_valid(_turn_toast_tween):
		_turn_toast_tween.kill()
		_turn_toast_tween = null

	_turn_toast_panel.visible = true
	_turn_toast_panel.modulate.a = 0.0
	_turn_toast_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_turn_toast_tween.tween_property(_turn_toast_panel, "modulate:a", 0.94 if persistent else 1.0, 0.16)
	if not persistent:
		_turn_toast_tween.tween_interval(duration)
		_turn_toast_tween.tween_property(_turn_toast_panel, "modulate:a", 0.0, 0.28)
		_turn_toast_tween.tween_callback(func():
			if _turn_toast_seq == my_seq and is_instance_valid(_turn_toast_panel) and not _turn_toast_persistent:
				_turn_toast_panel.visible = false
		)


func hide_turn_toast() -> void:
	_turn_toast_persistent = false
	_turn_toast_seq += 1
	if is_instance_valid(_turn_toast_tween):
		_turn_toast_tween.kill()
		_turn_toast_tween = null
	if is_instance_valid(_turn_toast_panel):
		_turn_toast_panel.visible = false


func _connect_buttons() -> void:
	if is_instance_valid(btn_p1_profile):
		btn_p1_profile.focus_mode = Control.FOCUS_NONE
		btn_p1_profile.pressed.connect(func():
			if _can_emit_profile_click():
				p1_profile_clicked.emit()
		)
	if is_instance_valid(btn_p2_profile):
		btn_p2_profile.focus_mode = Control.FOCUS_NONE
		btn_p2_profile.pressed.connect(func():
			if _can_emit_profile_click():
				p2_profile_clicked.emit()
		)


func _on_spectator_count_updated(game_id: String, count: int) -> void:
	var active_gid: String = GameManager.active_game_id
	var spec_gid: String = GameManager.spectated_game_id
	var open_gid: String = GameManager.get_open_game_id()
	if game_id.is_empty() or game_id == active_gid or game_id == spec_gid or game_id == open_gid:
		update_spectator_count(count)


func update_spectator_count(count: int) -> void:
	var safe_count: int = maxi(0, count)
	if is_instance_valid(spectator_pill):
		spectator_pill.visible = GameManager.is_spectating or safe_count > 0
	if is_instance_valid(lbl_spectator):
		lbl_spectator.text = "تماشاچی (%s)" % _fa_digits(safe_count) if safe_count > 0 else "تماشاچی"


func _get_player_data_for_index(idx: int) -> Dictionary:
	var p_data: Dictionary = {}
	if GameManager.match_players.size() >= idx and idx > 0:
		p_data = GameManager.get_player_data_by_gamer_id(idx)
	if p_data.is_empty():
		if idx == 1:
			p_data = _p1_raw_data
		elif idx == 2:
			p_data = _p2_raw_data
		elif _extra_raw_data.has(idx):
			p_data = _extra_raw_data[idx]

	var name_str := str(p_data.get("name", p_data.get("username", _player_names.get(idx, "بازیکن %d" % idx))))
	var av_id := int(p_data.get("image", p_data.get("user_image", 0)))
	var av_tex: Texture2D = _get_cached_avatar(av_id)
	var col_val: Color = HudTheme.get_seat_accent(idx)

	return {
		"id": str(idx),
		"index": idx,
		"seat_index": idx,
		"name": name_str,
		"avatar_texture": av_tex,
		"color": col_val,
		"counter": str(_cached_counters.get(idx, "")),
		"eliminated": is_player_disabled(idx)
	}


func _rebuild_pods() -> void:
	if not is_instance_valid(players_container):
		return

	for child in players_container.get_children():
		child.queue_free()
	_pods_by_idx.clear()

	var is_spec := GameManager.is_spectating or not opponent_only_mode
	if is_instance_valid(spectator_pill):
		spectator_pill.visible = GameManager.is_spectating

	var my_idx := _my_player_index
	if my_idx <= 0:
		my_idx = GameManager.my_player_index
	if my_idx <= 0:
		my_idx = 1

	var total := clampi(_total_players, 2, 4)

	# In Player mode: opponents only. In Spectator mode: all players.
	var display_indices: Array[int] = []
	if is_spec:
		for i in range(1, total + 1):
			display_indices.append(i)
	else:
		for i in range(1, total + 1):
			if i != my_idx:
				display_indices.append(i)

	var mode: PlayerPod.PodMode = PlayerPod.PodMode.VERTICAL_STANDARD
	if not is_spec and display_indices.size() == 1:
		mode = PlayerPod.PodMode.HORIZONTAL_PILL
	elif is_spec and total == 4:
		mode = PlayerPod.PodMode.VERTICAL_COMPACT
	else:
		mode = PlayerPod.PodMode.VERTICAL_STANDARD

	for idx in display_indices:
		var p_data := _get_player_data_for_index(idx)
		var pod: PlayerPod = _pod_scene.instantiate() as PlayerPod
		players_container.add_child(pod)
		pod.setup_pod(p_data, mode, true)
		if _cached_counters.has(idx):
			pod.set_counter(str(_cached_counters[idx]))
		else:
			pod.set_counter("")
		if _cached_statuses.has(idx):
			var st_info: Dictionary = _cached_statuses[idx]
			pod.set_status_badge(str(st_info.get("text", "")), st_info.get("color", Color(-1, -1, -1)))
		else:
			pod.set_status_badge("")
		pod.pod_pressed.connect(func(_pid: String) -> void:
			if _can_emit_profile_click():
				player_profile_clicked.emit(idx)
				if idx == 1:
					p1_profile_clicked.emit()
				elif idx == 2:
					p2_profile_clicked.emit()
		)
		_pods_by_idx[idx] = pod

	_setup_initial_result_display()
	_sync_header_height()


func set_opponent_only_mode(enabled: bool) -> void:
	opponent_only_mode = enabled
	_rebuild_pods()


func _apply_opponent_only_layout() -> void:
	_rebuild_pods()


func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_profile_clicks_enabled = false
	_my_player_index = my_idx
	_p1_raw_data = p1_data
	_p2_raw_data = p2_data

	var p1_str := str(p1_data.get("name", p1_data.get("username", "میزبان")))
	var p2_str := str(p2_data.get("name", p2_data.get("username", "مهمان")))
	_player_names[1] = p1_str
	_player_names[2] = p2_str

	if is_instance_valid(p1_name):
		p1_name.text = p1_str
	if is_instance_valid(p2_name):
		p2_name.text = p2_str

	_rebuild_pods()


func setup_match(game_name_fa: String, _mode_title: String, round_num: int, max_rounds: int, _turn_time: float) -> void:
	_last_displayed_sec = -1
	_last_critical_sec = -1
	update_spectator_count(GameManager.spectator_count)
	var meta_str := "%s" % game_name_fa if max_rounds <= 1 else "راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_round):
		lbl_round.text = meta_str
	set_match_meta_text(meta_str)
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
	if is_instance_valid(lbl_timer):
		lbl_timer.text = ""
		lbl_timer.visible = false
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0

	_rebuild_pods()


func set_round(round_num: int, max_rounds: int) -> void:
	var meta_str := ""
	if max_rounds <= 1:
		var g_info = GameRegistry.get_game_info(GameManager.current_game_type)
		var game_name_fa = g_info.get("name_fa", "بازی")
		meta_str = "%s" % game_name_fa
	else:
		meta_str = "راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_round):
		lbl_round.text = meta_str
	set_match_meta_text(meta_str)


func set_match_meta_text(text: String) -> void:
	if not is_instance_valid(match_meta_ribbon) or not is_instance_valid(lbl_match_meta):
		return
	var clean := text.strip_edges()
	if clean.is_empty():
		match_meta_ribbon.visible = false
	else:
		lbl_match_meta.text = clean
		match_meta_ribbon.visible = not (is_instance_valid(local_turn_bar_wrap) and local_turn_bar_wrap.visible)


func update_player_counter(player_idx: int, val_str: String) -> void:
	_cached_counters[player_idx] = val_str
	if _pods_by_idx.has(player_idx):
		var pod: PlayerPod = _pods_by_idx[player_idx]
		if is_instance_valid(pod):
			pod.set_counter(val_str)


func update_scores(p1_s: int, p2_s: int) -> void:
	if not _is_score_based_game():
		return
	update_player_counter(1, str(p1_s))
	update_player_counter(2, str(p2_s))
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = _fa_digits(p1_s)
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = _fa_digits(p2_s)
	set_current_result_scores(p1_s, p2_s)


func set_current_result_scores(p1_s: int, p2_s: int) -> void:
	if not _is_score_based_game():
		if is_instance_valid(match_result_box):
			match_result_box.visible = false
		return
	if is_instance_valid(lbl_result_score):
		lbl_result_score.text = "%s - %s" % [_fa_digits(p1_s), _fa_digits(p2_s)]
	if is_instance_valid(match_result_box):
		match_result_box.visible = true
	_sync_header_height()


func set_current_result_text(text: String) -> void:
	if not is_instance_valid(match_result_box) or not is_instance_valid(lbl_result_score):
		return
	var clean := text.strip_edges()
	if clean.is_empty():
		match_result_box.visible = false
	else:
		lbl_result_score.text = clean
		match_result_box.visible = true
	_sync_header_height()


func _setup_initial_result_display() -> void:
	if not _is_score_based_game():
		if is_instance_valid(match_result_box):
			match_result_box.visible = false
		return
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.OTHELLO:
		set_current_result_scores(2, 2)
	elif g_type in [GameTypes.DOTBOX, GameTypes.MILL, GameTypes.BATTLESHIP, GameTypes.BOXFOUR, GameTypes.FOURINROW, GameTypes.MNUMBERS, GameTypes.YATZY, GameTypes.YINSH, GameTypes.QUIZ]:
		set_current_result_scores(GameManager.p1_score, GameManager.p2_score)
	elif GameRegistry.has_round_score(g_type) and GameManager.max_rounds > 1:
		set_current_result_scores(GameManager.p1_score, GameManager.p2_score)
	else:
		if is_instance_valid(match_result_box):
			match_result_box.visible = false


func _pulse_bottom_glow() -> void:
	if not is_instance_valid(bottom_turn_glow):
		return
	if is_instance_valid(_bottom_glow_tween):
		_bottom_glow_tween.kill()
	bottom_turn_glow.visible = true
	bottom_turn_glow.modulate.a = 0.25
	_bottom_glow_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bottom_glow_tween.tween_property(bottom_turn_glow, "modulate:a", 0.85, 0.9)
	_bottom_glow_tween.tween_property(bottom_turn_glow, "modulate:a", 0.25, 0.9)


func _is_simultaneous_turn() -> bool:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.QUIZ:
		return true
	return false


func _get_simultaneous_turn_text() -> String:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.QUIZ:
		return "پاسخ به سوال"
	return "اقدام همزمان"


func _get_player_color_for_turn(turn: int) -> Color:
	if _is_simultaneous_turn():
		return Color.WHITE
	var p_data := _get_player_data_for_index(turn)
	var col_val: Variant = p_data.get("color", null)
	if col_val is Color:
		return col_val as Color
	return HudTheme.get_seat_accent(turn)


func _apply_turn_bar_colors(turn: int, is_danger: bool) -> void:
	var fill_color: Color
	if is_danger:
		fill_color = HudTheme.COL_DANGER
	elif _is_simultaneous_turn():
		fill_color = Color.WHITE
	else:
		fill_color = _get_player_color_for_turn(turn)

	if is_instance_valid(local_turn_bar):
		var sb_fill := StyleBoxFlat.new()
		sb_fill.bg_color = fill_color
		sb_fill.set_corner_radius_all(2)
		local_turn_bar.add_theme_stylebox_override("fill", sb_fill)

	if is_instance_valid(local_turn_pill):
		var sb_pill := StyleBoxFlat.new()
		sb_pill.content_margin_left = 12.0
		sb_pill.content_margin_top = 2.0
		sb_pill.content_margin_right = 12.0
		sb_pill.content_margin_bottom = 2.0
		sb_pill.bg_color = Color(0.10, 0.07, 0.04, 0.94)
		sb_pill.border_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.85)
		sb_pill.set_border_width_all(1)
		sb_pill.set_corner_radius_all(10)
		sb_pill.shadow_color = Color(0, 0, 0, 0.4)
		sb_pill.shadow_size = 3
		local_turn_pill.add_theme_stylebox_override("panel", sb_pill)


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	if not p1_n.is_empty(): _player_names[1] = p1_n
	if not p2_n.is_empty(): _player_names[2] = p2_n

	if _pods_by_idx.is_empty():
		_rebuild_pods()

	var is_spec := GameManager.is_spectating or not opponent_only_mode
	var is_simul := _is_simultaneous_turn()
	var is_me := (not is_spec and turn == my_idx)

	# Highlight active pod border/glow (radial progress ring is removed)
	for idx in _pods_by_idx:
		var pod: PlayerPod = _pods_by_idx[idx]
		if is_instance_valid(pod):
			pod.set_active_turn(idx == turn)

	# Universal Timer Bar is visible during any active game turn
	if is_instance_valid(local_turn_bar_wrap):
		local_turn_bar_wrap.visible = GameManager.is_game_active
	if is_instance_valid(match_meta_ribbon):
		match_meta_ribbon.visible = false

	# Set pill text
	if is_instance_valid(lbl_local_turn):
		if is_simul:
			lbl_local_turn.text = _get_simultaneous_turn_text()
		elif is_me:
			lbl_local_turn.text = "نوبت شما"
		else:
			var opp_name := str(_player_names.get(turn, "بازیکن %d" % turn))
			lbl_local_turn.text = "نوبت %s" % opp_name

	_apply_turn_bar_colors(turn, false)

	# Bottom edge glow only pulses for local player's turn
	if is_me and not is_simul and GameManager.is_game_active:
		_pulse_bottom_glow()
	else:
		if is_instance_valid(bottom_turn_glow):
			bottom_turn_glow.visible = false
		if is_instance_valid(_bottom_glow_tween):
			_bottom_glow_tween.kill()
			_bottom_glow_tween = null

	_sync_header_height()

	if not GameManager.is_game_active:
		hide_turn_toast()
	elif is_simul:
		show_turn_toast(_get_simultaneous_turn_text(), HudTheme.COL_TEXT_IVORY, false, 1.5)
	elif is_me:
		show_turn_toast("✨ نوبت شماست!", HudTheme.COL_TEXT_GOLD, false, 1.8)
	else:
		var opp_name := str(_player_names.get(turn, "بازیکن %d" % turn))
		show_turn_toast("نوبت %s" % opp_name, HudTheme.COL_TEXT_SAND, false, 1.5)


func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	var pct := clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
	var is_danger := (remaining_sec <= 4.0 and remaining_sec > 0.0)

	# Universal Turn Bar progress for all players
	if is_instance_valid(local_turn_bar_wrap):
		local_turn_bar_wrap.visible = GameManager.is_game_active
	if is_instance_valid(local_turn_bar):
		local_turn_bar.value = pct

	_apply_turn_bar_colors(turn, is_danger)

	for idx in _pods_by_idx:
		var pod: PlayerPod = _pods_by_idx[idx]
		if is_instance_valid(pod) and idx == turn:
			pod.update_ring_timer(remaining_sec, total_sec)

	# Clean silent timer: ticking numbers suppressed
	if is_instance_valid(lbl_timer):
		lbl_timer.text = ""
		lbl_timer.visible = false
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = pct


func set_penalty_box_visible(enabled: bool) -> void:
	if is_instance_valid(penalty_details_box):
		penalty_details_box.visible = enabled
		_sync_header_height()


func update_penalty_dots(gamer_id: int, count: int, max_count: int = 2) -> void:
	var is_me: bool = (gamer_id == _my_player_index)
	var dots: Array = [my_dot1, my_dot2] if is_me else [opp_dot1, opp_dot2]
	var count_lbl: Label = lbl_my_penalty if is_me else lbl_opp_penalty
	if not is_instance_valid(count_lbl):
		return
	var clamped := clampi(count, 0, max_count)
	count_lbl.text = "%s/%s" % [_fa_digits(clamped), _fa_digits(max_count)]
	for i in range(dots.size()):
		var dot = dots[i]
		if not is_instance_valid(dot):
			continue
		var sb := StyleBoxFlat.new()
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		if clamped > i:
			if clamped >= max_count:
				sb.bg_color = HudTheme.COL_DANGER
				sb.border_color = Color(1.0, 0.78, 0.78, 1.0)
			else:
				sb.bg_color = HudTheme.COL_AMBER_GLOW
				sb.border_color = HudTheme.COL_GOLD_ACTIVE
		else:
			sb.bg_color = HudTheme.COL_WALNUT_DEEP
			sb.border_color = HudTheme.COL_BRONZE_MUTED
		dot.add_theme_stylebox_override("panel", sb)


func update_not_played_turns(gamer_id: int, count: int) -> void:
	set_penalty_box_visible(true)
	update_penalty_dots(gamer_id, count, 2)


func set_camera_mode_indicator(is_top_down: bool) -> void:
	_is_2d_mode = is_top_down
	if is_instance_valid(img_view_2d3d):
		img_view_2d3d.texture = _tex_3d if is_top_down else _tex_2d


func is_player_disabled(player_idx: int) -> bool:
	return _disabled_players.has(player_idx)


func set_player_disabled(player_idx: int, disabled: bool, reason_text: String = "خارج شد") -> void:
	if disabled:
		_disabled_players[player_idx] = reason_text
	else:
		_disabled_players.erase(player_idx)
	if _pods_by_idx.has(player_idx):
		var pod: PlayerPod = _pods_by_idx[player_idx]
		if is_instance_valid(pod):
			pod.set_eliminated(disabled)


func reset_header() -> void:
	_current_turn = 1
	_disabled_players.clear()
	_cached_counters.clear()
	set_penalty_box_visible(false)
	if is_instance_valid(match_result_box):
		match_result_box.visible = false
	if is_instance_valid(local_turn_bar_wrap):
		local_turn_bar_wrap.visible = false
	if is_instance_valid(bottom_turn_glow):
		bottom_turn_glow.visible = false
	hide_turn_toast()
	_rebuild_pods()


func show_reaction(user_index: int, reaction_id: int) -> void:
	if GameManager.chat_and_stickers_disabled:
		return
	var vp_sz := get_viewport_rect().size
	var my_idx: int = _my_player_index if _my_player_index > 0 else GameManager.my_player_index

	# Determine if this reaction is from local player or an opponent
	var is_opponent: bool = true
	if user_index == my_idx or (GameManager.my_player_index > 0 and user_index == GameManager.my_player_index):
		is_opponent = false
	elif GameManager.user_data and int(GameManager.user_data.get("id", -1)) == user_index:
		is_opponent = false

	# Resolve user_index to gamer_id (1..4) if passed as database ID or if not directly in pods
	var resolved_idx: int = user_index
	if not _pods_by_idx.has(resolved_idx):
		for p in GameManager.match_players:
			if int(p.get("id", 0)) == user_index or int(p.get("user_id", 0)) == user_index or int(p.get("playerId", 0)) == user_index:
				resolved_idx = int(p.get("gamer_id", 0))
				break

	var spawn_pos: Vector2 = Vector2.ZERO

	if is_opponent:
		var target_pod: PlayerPod = null
		if _pods_by_idx.has(resolved_idx):
			target_pod = _pods_by_idx[resolved_idx]
		elif _pods_by_idx.size() > 0:
			target_pod = _pods_by_idx.values()[0]

		if is_instance_valid(target_pod):
			var pod_rect := target_pod.get_global_rect()
			spawn_pos = Vector2(pod_rect.get_center().x, pod_rect.end.y + 6.0)
		else:
			spawn_pos = Vector2(80.0, float(_safe_top_inset) + 56.0)
	else:
		# Local player sent sticker: spawn in lower-middle screen prominently above cards/hand
		spawn_pos = Vector2(vp_sz.x * 0.5, vp_sz.y - 210.0)

	_spawn_floating_reaction(is_opponent, reaction_id, spawn_pos)


func _spawn_floating_reaction(is_opponent: bool, reaction_id: int, spawn_pos: Vector2) -> void:
	var is_kori: bool = reaction_id > 100
	var vp_sz := get_viewport_rect().size
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.top_level = true
	bubble.z_index = 100

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.12, 0.08, 0.05, 0.96)
	bubble_style.border_color = HudTheme.COL_GOLD_ACTIVE if not is_opponent else HudTheme.COL_GOLD_BRUSHED
	bubble_style.set_border_width_all(2)
	bubble_style.border_width_bottom = 2
	bubble_style.shadow_color = Color(0, 0, 0, 0.60)
	bubble_style.shadow_size = 14 if not is_opponent else (8 if is_kori else 12)
	bubble_style.shadow_offset = Vector2(0, 4 if not is_opponent else 3)

	if not is_opponent:
		# Local player sent reaction: prominent speech bubble
		bubble_style.set_corner_radius_all(18)
		bubble_style.content_margin_left = 18
		bubble_style.content_margin_right = 18
		bubble_style.content_margin_top = 8 if is_kori else 10
		bubble_style.content_margin_bottom = 8 if is_kori else 10
	else:
		# Opponent reaction: compact and clean at bottom of pod
		bubble_style.set_corner_radius_all(14 if is_kori else 20)
		bubble_style.content_margin_left = 12
		bubble_style.content_margin_right = 12
		bubble_style.content_margin_top = 4 if is_kori else 10
		bubble_style.content_margin_bottom = 4 if is_kori else 10
	bubble.add_theme_stylebox_override("panel", bubble_style)

	if is_kori:
		var k_idx: int = clampi(reaction_id - 101, 0, KORIS.size() - 1)
		var msg_text: String = KORIS[k_idx]
		var lbl := Label.new()
		if _font_vazir:
			lbl.add_theme_font_override("font", _font_vazir)
		# Local player chat gets larger font size 15, opponent gets 12
		lbl.add_theme_font_size_override("font_size", 15 if not is_opponent else 12)
		lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		lbl.add_theme_color_override("font_shadow_color", HudTheme.COL_SHADOW_DARK)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.text_direction = Control.TEXT_DIRECTION_RTL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.text = msg_text
		bubble.add_child(lbl)
		bubble.custom_minimum_size = Vector2(0, 38 if not is_opponent else 28)
	else:
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(112, 112)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var r_tex := _get_cached_reaction(reaction_id)
		if r_tex:
			icon_rect.texture = r_tex
		bubble.add_child(icon_rect)
		bubble.custom_minimum_size = Vector2(136, 136)

	# Opponent reaction special VFX: luminous expanding golden aura shockwave
	var aura: Panel = null
	if is_opponent:
		aura = Panel.new()
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var aura_sb := StyleBoxFlat.new()
		aura_sb.bg_color = Color(HudTheme.COL_GOLD_ACTIVE.r, HudTheme.COL_GOLD_ACTIVE.g, HudTheme.COL_GOLD_ACTIVE.b, 0.45)
		aura_sb.set_corner_radius_all(18 if is_kori else 24)
		aura.add_theme_stylebox_override("panel", aura_sb)
		aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aura.show_behind_parent = true
		bubble.add_child(aura)

	add_child(bubble)
	bubble.reset_size()

	var bubble_w: float = bubble.size.x
	var bubble_h: float = bubble.size.y
	if bubble_w <= 0.0:
		bubble_w = bubble.custom_minimum_size.x if bubble.custom_minimum_size.x > 0 else 136.0
	if bubble_h <= 0.0:
		bubble_h = bubble.custom_minimum_size.y if bubble.custom_minimum_size.y > 0 else ((38.0 if not is_opponent else 28.0) if is_kori else 136.0)
	var half_w: float = bubble_w * 0.5
	var target_x: float = clampf(spawn_pos.x - half_w, 12.0, maxf(12.0, vp_sz.x - bubble_w - 12.0))
	var target_y: float = spawn_pos.y
	if not is_opponent:
		target_y = clampf(spawn_pos.y, 160.0, maxf(160.0, vp_sz.y - bubble_h - 100.0))

	bubble.global_position = Vector2(target_x, target_y if not is_opponent else target_y - 6.0)
	bubble.scale = Vector2(0.18, 0.18)
	bubble.pivot_offset = Vector2(half_w, 0.0 if is_opponent else bubble_h * 0.5)
	bubble.modulate.a = 0.0

	AudioManager.play_sound("chat")

	var tw := create_tween().set_parallel(false)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.10, 1.10), 0.20)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.14)
	if is_opponent:
		tw.parallel().tween_property(bubble, "global_position:y", target_y + 4.0, 0.20)
		if is_instance_valid(aura):
			tw.parallel().tween_property(aura, "scale", Vector2(1.35, 1.35), 0.32)
			tw.parallel().tween_property(aura, "modulate:a", 0.0, 0.32)
	else:
		tw.parallel().tween_property(bubble, "global_position:y", target_y - 12.0, 0.20)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.08)

	var idle_tw: Tween = null
	if is_opponent:
		idle_tw = create_tween().set_loops(3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle_tw.tween_property(bubble, "global_position:y", target_y, 0.5)
		idle_tw.tween_property(bubble, "global_position:y", target_y + 4.0, 0.5)

	tw.tween_interval(2.6 if not is_kori else 3.2)
	tw.tween_callback(func():
		if is_instance_valid(idle_tw) and idle_tw.is_valid():
			idle_tw.kill()
	)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(bubble, "scale", Vector2(0.80, 0.80), 0.18)
	tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.18)
	tw.tween_callback(bubble.queue_free)


# --- Backwards Compatibility Helpers for Child Classes ---
func _update_two_row_visibility(total_players: int) -> void:
	_total_players = clampi(total_players, 2, 4)
	_rebuild_pods()


func _get_player_card_bundle(player_idx: int) -> Dictionary:
	return {
		"card": p1_card if player_idx == 1 else p2_card,
		"avatar": p1_avatar if player_idx == 1 else p2_avatar,
		"avatar_container": (p1_avatar.get_parent() as Control) if (player_idx == 1 and is_instance_valid(p1_avatar)) else ((p2_avatar.get_parent() as Control) if is_instance_valid(p2_avatar) else null),
		"name": p1_name if player_idx == 1 else p2_name,
		"role": p1_role_badge if player_idx == 1 else p2_role_badge,
		"score": p1_score_lbl if player_idx == 1 else p2_score_lbl,
		"reaction_bubble": p1_reaction_bubble if player_idx == 1 else p2_reaction_bubble,
		"reaction_icon": p1_reaction_icon if player_idx == 1 else p2_reaction_icon,
	}


func _set_role_badge(player_idx: int, text: String, color: Color = Color.WHITE) -> void:
	_cached_statuses[player_idx] = {"text": text, "color": color}
	if _pods_by_idx.has(player_idx):
		var pod: PlayerPod = _pods_by_idx[player_idx]
		if is_instance_valid(pod):
			pod.set_status_badge(text, color)


func _set_active_cards_visual(_active_indices: Array, _is_danger: bool = false, _pulse_active: bool = false) -> void:
	pass


func _update_card_timer_visuals(remaining_sec: float, total_sec: float, active_indices: Array) -> void:
	var turn: int = active_indices[0] if not active_indices.is_empty() else _current_turn
	update_timer(remaining_sec, total_sec, turn)


func _is_score_based_game() -> bool:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.CHESS or g_type == GameTypes.QUORIDOR or g_type == GameTypes.FEKRBEKR or g_type == GameTypes.COUP or g_type == GameTypes.UNO or g_type == GameTypes.MONOPOLY or g_type == GameTypes.RISK:
		return false
	if g_type in [GameTypes.OTHELLO, GameTypes.DOTBOX, GameTypes.MILL, GameTypes.BATTLESHIP, GameTypes.BOXFOUR, GameTypes.FOURINROW, GameTypes.MNUMBERS, GameTypes.YATZY, GameTypes.YINSH, GameTypes.QUIZ]:
		return true
	return GameRegistry.has_round_score(g_type)


func _on_turn_changed(_turn: int) -> void:
	pass


func _update_score_badges_visibility() -> void:
	var show_scores := _is_score_based_game()
	if is_instance_valid(_p1_score_badge):
		_p1_score_badge.visible = show_scores
	elif is_instance_valid(p1_score_lbl) and p1_score_lbl.get_parent() is Control:
		(p1_score_lbl.get_parent() as Control).visible = show_scores
	if is_instance_valid(_p2_score_badge):
		_p2_score_badge.visible = show_scores
	elif is_instance_valid(p2_score_lbl) and p2_score_lbl.get_parent() is Control:
		(p2_score_lbl.get_parent() as Control).visible = show_scores


func _apply_disabled_visual(player_idx: int) -> void:
	if _pods_by_idx.has(player_idx):
		var pod: PlayerPod = _pods_by_idx[player_idx]
		if is_instance_valid(pod):
			var is_dis := is_player_disabled(player_idx)
			var reason: String = str(_disabled_players.get(player_idx, "خارج شد"))
			pod.set_eliminated(is_dis, reason)


func _animate_card_pulse(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.16)
	tw.tween_property(card, "scale", Vector2.ONE, 0.14)


func _animate_score_bump(badge: Control) -> void:
	if not is_instance_valid(badge):
		return
	badge.pivot_offset = badge.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.20, 1.20), 0.14)
	tw.tween_property(badge, "scale", Vector2.ONE, 0.16)


func _get_or_create_players_row2() -> HBoxContainer:
	if is_instance_valid(_players_row2):
		return _players_row2
	var vbox_main := get_node_or_null("Margin/VBoxMain") as VBoxContainer
	var players_row := get_node_or_null("Margin/VBoxMain/PlayersRow") as HBoxContainer
	if not vbox_main or not players_row:
		return null
	var existing := vbox_main.get_node_or_null("PlayersRow2") as HBoxContainer
	if is_instance_valid(existing):
		_players_row2 = existing
		return _players_row2
	_players_row2 = HBoxContainer.new()
	_players_row2.name = "PlayersRow2"
	_players_row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_players_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_players_row2.add_theme_constant_override("separation", 8)
	_players_row2.visible = false
	vbox_main.add_child(_players_row2)
	vbox_main.move_child(_players_row2, players_row.get_index() + 1)
	return _players_row2


func _register_extra_player_card(idx: int, card: PanelContainer) -> Dictionary:
	if not is_instance_valid(card):
		return {}
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT_MULTI)
	var av_cont := card.get_node_or_null("HBox/AvatarContainer") as Control
	var av := card.get_node_or_null("HBox/AvatarContainer/Avatar") as TextureRect
	var nm := card.get_node_or_null("HBox/InfoBox/Name") as Label
	var rl := card.get_node_or_null("HBox/InfoBox/RoleBadge") as Label
	var sc := card.get_node_or_null("HBox/ScoreBadge/Score") as Label
	var rb := card.get_node_or_null("ReactionBubble") as Control
	var ri := card.get_node_or_null("ReactionBubble/BubbleFrame/Icon") as TextureRect
	var av_frame: Panel = (av_cont.get_node_or_null("AvatarMedallionFrame") as Panel) if is_instance_valid(av_cont) else null
	var bundle := {
		"card": card,
		"avatar": av,
		"avatar_container": av_cont,
		"av_frame": av_frame,
		"name": nm,
		"role": rl,
		"score": sc,
		"reaction_bubble": rb,
		"reaction_icon": ri,
	}
	_extra_cards[idx] = bundle
	if idx == 3:
		p3_card = card
	elif idx == 4:
		p4_card = card
	return bundle
