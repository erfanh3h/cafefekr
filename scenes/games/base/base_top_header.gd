class_name BaseTopHeader
extends Control

# Base Top Header for Cafe Fekr — Warm Classic Parlor Shared HUD
# Compact (<12% viewport height) portrait header supporting 2-4 players with:
# - Integrated bottom-edge card turn timer bars + compact seconds chips
# - Lightweight fading TurnStatusToast (replacing heavy permanent turn banner)
# - Top-corner Menu/Settings trigger + compact live spectator counter
# - Strictly below-avatar emote & Kori pop-ups (zero overlap over names/counters)
# - Full Persian RTL & English LTR BiDi support and mobile safe-area insets

signal p1_profile_clicked()
signal p2_profile_clicked()
signal player_profile_clicked(player_index: int)
signal menu_requested()
signal header_height_changed(new_height: float)

const CARD_HEIGHT_2P := 84.0
const CARD_HEIGHT_MULTI := 68.0
const MENU_COL_WIDTH := 46.0

var _profile_clicks_enabled: bool = false

func set_profile_clicks_enabled(enabled: bool) -> void:
	_profile_clicks_enabled = enabled

func _can_emit_profile_click() -> bool:
	return _profile_clicks_enabled and GameManager.is_game_active

# --- Player 1 Card Nodes ---
@onready var p1_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P1Card
@onready var p1_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/Avatar
@onready var p1_name: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/Name
@onready var p1_role_badge: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/RoleBadge
@onready var p1_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/ScoreBadge/Score
@onready var p1_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble
@onready var p1_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p1_profile: Button = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/BtnP1Profile

# --- Player 2 Card Nodes ---
@onready var p2_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P2Card
@onready var p2_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/Avatar
@onready var p2_name: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/Name
@onready var p2_role_badge: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/RoleBadge
@onready var p2_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/ScoreBadge/Score
@onready var p2_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble
@onready var p2_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p2_profile: Button = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/BtnP2Profile

# --- Legacy Match Details & Turn Timer Nodes (kept alive & hidden for 100% compatibility) ---
@onready var match_details_box: PanelContainer = $Margin/VBoxMain/MatchDetailsBox
@onready var lbl_round: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel/LblRound
@onready var lbl_turn_banner: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnBanner
@onready var lbl_timer: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow/LblTimer
@onready var turn_timer_bar: ProgressBar = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnTimerBar

# --- Dynamic Player 3 & Player 4 Cards (for 3-4 player games) ---
var p3_card: PanelContainer = null
var p4_card: PanelContainer = null
var _players_row2: HBoxContainer = null
var _p4_empty_spacer: Control = null
var _row2_menu_spacer: Control = null
var _extra_cards: Dictionary = {} # idx (3,4) -> Dictionary of child node refs
var _card_decorations: Dictionary = {} # idx (1..4) -> {timer_bar, timer_fill, timer_chip, seat_dot, overlay}
var _disabled_players: Dictionary = {} # idx (1..4) -> reason string
var _player_names: Dictionary = {
	1: "بازیکن ۱",
	2: "بازیکن ۲",
	3: "بازیکن ۳",
	4: "بازیکن ۴"
}
var _reaction_seqs: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}

# --- Theme Styles (Warm Classic Parlor) ---
var _style_p1_active: StyleBoxFlat
var _style_p1_inactive: StyleBoxFlat
var _style_p2_active: StyleBoxFlat
var _style_p2_inactive: StyleBoxFlat
var _style_p3_active: StyleBoxFlat
var _style_p3_inactive: StyleBoxFlat
var _style_p4_active: StyleBoxFlat
var _style_p4_inactive: StyleBoxFlat
var _style_card_active_danger: StyleBoxFlat
var _style_card_disabled: StyleBoxFlat
var _timer_style_fill: StyleBoxFlat
var _timer_style_bg: StyleBoxFlat
var _style_match_box_normal: StyleBoxFlat
var _style_match_box_p1: StyleBoxFlat
var _style_match_box_p2: StyleBoxFlat
var _style_match_box_p3: StyleBoxFlat
var _style_match_box_p4: StyleBoxFlat
var _style_match_box_danger: StyleBoxFlat
var _style_timer_pill_normal: StyleBoxFlat
var _style_timer_pill_danger: StyleBoxFlat
var _style_avatar_p1_active: StyleBoxFlat
var _style_avatar_p1_idle: StyleBoxFlat
var _style_avatar_p2_active: StyleBoxFlat
var _style_avatar_p2_idle: StyleBoxFlat
var _style_avatar_p3_active: StyleBoxFlat
var _style_avatar_p3_idle: StyleBoxFlat
var _style_avatar_p4_active: StyleBoxFlat
var _style_avatar_p4_idle: StyleBoxFlat
var _style_chip_normal: StyleBoxFlat
var _style_chip_danger: StyleBoxFlat

# --- Dynamic Game-UI Decorations ---
var _p1_avatar_frame: Panel = null
var _p2_avatar_frame: Panel = null
var _p1_side_tag: Label = null
var _p2_side_tag: Label = null
var _p1_score_badge: PanelContainer = null
var _p2_score_badge: PanelContainer = null
var _timer_icon: TextureRect = null
var _timer_vfx_overlay: Control = null
var _spectator_badge_panel: PanelContainer = null
var _lbl_spectator_count: Label = null
var _menu_col: VBoxContainer = null
var _btn_hud_menu: Button = null
var _turn_toast_panel: PanelContainer = null
var _lbl_turn_toast: Label = null
var _turn_toast_seq: int = 0
var _turn_toast_tween: Tween = null
var _turn_toast_persistent: bool = false

# --- State ---
var _current_turn: int = 1
var _my_player_index: int = 1
var _total_players: int = 2
var _active_card_indices: Array = [1]
var _last_critical_sec: int = -1
var _last_displayed_sec: int = -1
var _last_p1_score: int = 0
var _last_p2_score: int = 0
var _cached_timer_danger: int = -1
var _cached_timer_box_style: StyleBox = null
var _cached_timer_fill_color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _safe_top_inset: int = 16
var _p1_reaction_seq: int = 0
var _p2_reaction_seq: int = 0

static var _avatar_cache: Dictionary = {}
static var _reaction_cache: Dictionary = {}
static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")
static var _font_vazir: FontFile = preload("res://assets/fonts/Vazir.ttf")
static var _tex_time_icon: Texture2D = preload("res://assets/icons/General/time.png")
static var _tex_menu_icon: Texture2D = preload("res://assets/icons/General/setting.png")


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


func _ready() -> void:
	_setup_styles()
	_build_game_ui_enhancements()
	_apply_safe_area_insets()
	_update_score_badges_visibility()
	_connect_buttons()
	if not NetworkManager.spectator_count_updated.is_connected(_on_spectator_count_updated):
		NetworkManager.spectator_count_updated.connect(_on_spectator_count_updated)
	update_spectator_count(GameManager.spectator_count)
	if is_instance_valid(p1_reaction_bubble):
		p1_reaction_bubble.top_level = true
		p1_reaction_bubble.visible = false
	if is_instance_valid(p2_reaction_bubble):
		p2_reaction_bubble.top_level = true
		p2_reaction_bubble.visible = false


func _exit_tree() -> void:
	if is_instance_valid(NetworkManager) and NetworkManager.spectator_count_updated.is_connected(_on_spectator_count_updated):
		NetworkManager.spectator_count_updated.disconnect(_on_spectator_count_updated)


func _apply_safe_area_insets() -> void:
	var insets := HudTheme.get_safe_insets(get_viewport())
	_safe_top_inset = int(insets.get("top", 16))
	var margin := get_node_or_null("Margin") as MarginContainer
	if is_instance_valid(margin):
		margin.add_theme_constant_override("margin_top", _safe_top_inset)
		margin.add_theme_constant_override("margin_left", int(insets.get("left", 10)))
		margin.add_theme_constant_override("margin_right", int(insets.get("right", 10)))
	_sync_header_height()


func _sync_header_height() -> void:
	var is_multi := _total_players > 2
	var cards_h: float = (CARD_HEIGHT_MULTI * 2.0 + 6.0) if is_multi else CARD_HEIGHT_2P
	# Keep total visible footprint compact (<12% of 1280px = 153px for 2P)
	var desired_h: float = float(_safe_top_inset) + cards_h + 12.0
	if not is_multi:
		desired_h = clampf(desired_h, 112.0, 148.0)
	else:
		desired_h = clampf(desired_h, 164.0, 204.0)
	offset_bottom = desired_h
	_position_turn_toast()
	header_height_changed.emit(desired_h)


func _on_spectator_count_updated(game_id: String, count: int) -> void:
	var active_gid: String = GameManager.active_game_id
	var spec_gid: String = GameManager.spectated_game_id
	var open_gid: String = GameManager.get_open_game_id()
	if game_id.is_empty() or game_id == active_gid or game_id == spec_gid or game_id == open_gid:
		update_spectator_count(count)


func update_spectator_count(count: int) -> void:
	var safe_count: int = maxi(0, count)
	if is_instance_valid(_spectator_badge_panel):
		_spectator_badge_panel.visible = (safe_count > 0)
	if is_instance_valid(_lbl_spectator_count) and safe_count > 0:
		_lbl_spectator_count.text = _fa_digits(safe_count)


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


func _setup_styles() -> void:
	var compact := _total_players > 2
	_style_p1_active = HudTheme.make_player_card_style(true, false, compact)
	_style_p1_inactive = HudTheme.make_player_card_style(false, false, compact)
	_style_p2_active = HudTheme.make_player_card_style(true, false, compact)
	_style_p2_inactive = HudTheme.make_player_card_style(false, false, compact)
	_style_p3_active = HudTheme.make_player_card_style(true, false, true)
	_style_p3_inactive = HudTheme.make_player_card_style(false, false, true)
	_style_p4_active = HudTheme.make_player_card_style(true, false, true)
	_style_p4_inactive = HudTheme.make_player_card_style(false, false, true)
	_style_card_active_danger = HudTheme.make_player_card_style(true, true, compact)
	_style_card_disabled = HudTheme.make_disabled_card_style(compact)

	# Transparent avatar medallion rings (decorative avatar frames handle framing)
	_style_avatar_p1_active = StyleBoxFlat.new()
	_style_avatar_p1_active.bg_color = Color(0, 0, 0, 0)
	_style_avatar_p1_active.border_color = Color(0, 0, 0, 0)
	_style_avatar_p1_active.set_border_width_all(0)
	_style_avatar_p1_idle = _style_avatar_p1_active.duplicate()
	_style_avatar_p2_active = _style_avatar_p1_active.duplicate()
	_style_avatar_p2_idle = _style_avatar_p1_active.duplicate()
	_style_avatar_p3_active = _style_avatar_p1_active.duplicate()
	_style_avatar_p3_idle = _style_avatar_p1_active.duplicate()
	_style_avatar_p4_active = _style_avatar_p1_active.duplicate()
	_style_avatar_p4_idle = _style_avatar_p1_active.duplicate()

	# Hidden legacy MatchDetailsBox styles (Warm Classic Parlor fallback if a child ever shows it)
	_style_match_box_normal = HudTheme.make_turn_toast_style()
	_style_match_box_p1 = _style_match_box_normal.duplicate()
	_style_match_box_p2 = _style_match_box_normal.duplicate()
	_style_match_box_p3 = _style_match_box_normal.duplicate()
	_style_match_box_p4 = _style_match_box_normal.duplicate()
	_style_match_box_danger = _style_match_box_normal.duplicate()
	_style_match_box_danger.border_color = HudTheme.COL_DANGER

	_style_timer_pill_normal = HudTheme.make_timer_chip_style(false)
	_style_timer_pill_danger = HudTheme.make_timer_chip_style(true)
	_style_chip_normal = HudTheme.make_timer_chip_style(false)
	_style_chip_danger = HudTheme.make_timer_chip_style(true)

	_timer_style_bg = HudTheme.make_card_timer_track_style()
	_timer_style_fill = HudTheme.make_card_timer_fill_style(HudTheme.COL_GOLD_ACTIVE)

	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.custom_minimum_size = Vector2(0, 6)
		turn_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		turn_timer_bar.add_theme_stylebox_override("background", _timer_style_bg)
		turn_timer_bar.add_theme_stylebox_override("fill", _timer_style_fill)

	if is_instance_valid(match_details_box):
		match_details_box.visible = false
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)


func _build_game_ui_enhancements() -> void:
	# 1. Enhance Player 1 & Player 2 Cards + attach integrated bottom timer bars & seat dots
	_enhance_player_card(1)
	_enhance_player_card(2)

	# 2. Keep legacy MatchDetailsBox collapsed to save vertical screen space
	if is_instance_valid(match_details_box):
		match_details_box.visible = false

	# 3. Add Top-Corner Menu/Settings Button + Compact Spectator Counter to PlayersRow
	var players_row := get_node_or_null("Margin/VBoxMain/PlayersRow") as HBoxContainer
	if is_instance_valid(players_row) and not is_instance_valid(_menu_col):
		_menu_col = VBoxContainer.new()
		_menu_col.name = "MenuColumn"
		_menu_col.custom_minimum_size = Vector2(MENU_COL_WIDTH, 0)
		_menu_col.size_flags_horizontal = Control.SIZE_SHRINK_END
		_menu_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_menu_col.alignment = BoxContainer.ALIGNMENT_CENTER
		_menu_col.add_theme_constant_override("separation", 4)
		_menu_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		players_row.add_child(_menu_col)

		_btn_hud_menu = Button.new()
		_btn_hud_menu.name = "BtnHudMenu"
		_btn_hud_menu.custom_minimum_size = Vector2(46, 46)
		_btn_hud_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_btn_hud_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_btn_hud_menu.tooltip_text = "منوی بازی و تنظیمات"
		HudTheme.apply_floating_button_style(_btn_hud_menu, false)
		_btn_hud_menu.pressed.connect(func():
			AudioManager.play_sound("click")
			menu_requested.emit()
		)
		_menu_col.add_child(_btn_hud_menu)

		var menu_icon := TextureRect.new()
		menu_icon.name = "Icon"
		menu_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_icon.offset_left = 10
		menu_icon.offset_top = 10
		menu_icon.offset_right = -10
		menu_icon.offset_bottom = -10
		menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_icon.texture = _tex_menu_icon
		menu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		menu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		menu_icon.modulate = HudTheme.COL_TEXT_GOLD
		_btn_hud_menu.add_child(menu_icon)

		# Compact live spectator badge directly under menu button (hidden when 0)
		_spectator_badge_panel = PanelContainer.new()
		_spectator_badge_panel.name = "SpectatorCountBadge"
		_spectator_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spectator_badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var sb_spec := StyleBoxFlat.new()
		sb_spec.bg_color = Color(HudTheme.COL_EMERALD_BG.r, HudTheme.COL_EMERALD_BG.g, HudTheme.COL_EMERALD_BG.b, 0.94)
		sb_spec.border_color = Color(HudTheme.COL_EMERALD.r, HudTheme.COL_EMERALD.g, HudTheme.COL_EMERALD.b, 0.85)
		sb_spec.set_border_width_all(1)
		sb_spec.set_corner_radius_all(8)
		sb_spec.content_margin_left = 5
		sb_spec.content_margin_right = 5
		sb_spec.content_margin_top = 1
		sb_spec.content_margin_bottom = 1
		_spectator_badge_panel.add_theme_stylebox_override("panel", sb_spec)

		var spec_hbox := HBoxContainer.new()
		spec_hbox.layout_direction = Control.LAYOUT_DIRECTION_LTR
		spec_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		spec_hbox.add_theme_constant_override("separation", 3)
		spec_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spectator_badge_panel.add_child(spec_hbox)

		var spec_eye := Label.new()
		spec_eye.text = "👁"
		spec_eye.add_theme_font_size_override("font_size", 11)
		spec_eye.add_theme_color_override("font_color", Color(0.76, 0.98, 0.85))
		spec_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spec_hbox.add_child(spec_eye)

		_lbl_spectator_count = Label.new()
		_lbl_spectator_count.name = "LblSpectatorCount"
		if _font_vazir:
			_lbl_spectator_count.add_theme_font_override("font", _font_vazir)
		_lbl_spectator_count.add_theme_font_size_override("font_size", 12)
		_lbl_spectator_count.add_theme_color_override("font_color", Color(0.76, 0.98, 0.85))
		_lbl_spectator_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spec_hbox.add_child(_lbl_spectator_count)
		_spectator_badge_panel.visible = false
		_menu_col.add_child(_spectator_badge_panel)

	# 4. Build Lightweight Fading Floating TurnStatusToast
	if not is_instance_valid(_turn_toast_panel):
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
		_lbl_turn_toast.add_theme_font_size_override("font_size", 15)
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
	var is_multi := _total_players > 2
	var cards_h: float = (CARD_HEIGHT_MULTI * 2.0 + 6.0) if is_multi else CARD_HEIGHT_2P
	var top_y: float = float(_safe_top_inset) + cards_h + 6.0
	_turn_toast_panel.offset_top = top_y
	_turn_toast_panel.offset_bottom = top_y + 34.0
	_turn_toast_panel.offset_left = -160.0
	_turn_toast_panel.offset_right = 160.0


func show_turn_toast(msg: String, text_color: Color = HudTheme.COL_TEXT_GOLD, persistent: bool = false, duration: float = 1.9) -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = msg
		lbl_turn_banner.add_theme_color_override("font_color", text_color)
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
		_turn_toast_tween.tween_property(_turn_toast_panel, "modulate:a", 0.0, 0.30)
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


func _attach_card_decorations(player_idx: int, card: PanelContainer, avatar_rect: TextureRect, name_lbl: Label, role_lbl: Label, score_lbl: Label) -> void:
	if not is_instance_valid(card):
		return

	# Clean BiDi typography on name & role
	if is_instance_valid(name_lbl):
		if _font_vazir:
			name_lbl.add_theme_font_override("font", _font_vazir)
		name_lbl.add_theme_font_size_override("font_size", 16 if _total_players > 2 else 18)
		name_lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		name_lbl.add_theme_color_override("font_shadow_color", HudTheme.COL_SHADOW_DARK)
		name_lbl.add_theme_constant_override("shadow_offset_y", 1)
		name_lbl.remove_theme_constant_override("outline_size")
		HudTheme.configure_bidi_label(name_lbl, true)

	if is_instance_valid(role_lbl):
		if _font_vazir:
			role_lbl.add_theme_font_override("font", _font_vazir)
		role_lbl.add_theme_font_size_override("font_size", 12 if _total_players > 2 else 13)
		role_lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)
		role_lbl.remove_theme_constant_override("outline_size")
		role_lbl.add_theme_stylebox_override("normal", HudTheme.make_status_pill_style(HudTheme.get_seat_accent(player_idx), 0.72))
		HudTheme.configure_bidi_label(role_lbl, true)
		role_lbl.visible = false

	# Compact Score Badge
	if is_instance_valid(score_lbl):
		var score_badge := score_lbl.get_parent() as PanelContainer
		if is_instance_valid(score_badge):
			if player_idx == 1:
				_p1_score_badge = score_badge
			elif player_idx == 2:
				_p2_score_badge = score_badge
			score_badge.custom_minimum_size = Vector2(38, 36) if _total_players > 2 else Vector2(40, 40)
			score_badge.add_theme_stylebox_override("panel", HudTheme.make_score_badge_style("normal"))
			if _font_hekayat:
				score_lbl.add_theme_font_override("font", _font_hekayat)
			score_lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_GOLD)
			score_lbl.add_theme_color_override("font_shadow_color", HudTheme.COL_SHADOW_DARK)
			score_lbl.add_theme_constant_override("shadow_offset_y", 1)
			score_lbl.remove_theme_constant_override("outline_size")
			score_lbl.add_theme_font_size_override("font_size", 24 if _total_players > 2 else 28)
			if score_lbl.text.is_empty() or score_lbl.text == "0":
				score_lbl.text = _fa_digits(0)

	# Subtle 10x10 Seat Color Dot on Avatar Bottom Corner
	var seat_dot: Panel = null
	if is_instance_valid(avatar_rect):
		var av_container := avatar_rect.get_parent() as Control
		if is_instance_valid(av_container):
			var existing_side_tag := av_container.get_node_or_null("PlayerSideTag")
			if is_instance_valid(existing_side_tag):
				existing_side_tag.queue_free()

			var av_frame := av_container.get_node_or_null("AvatarMedallionFrame") as Panel
			if not is_instance_valid(av_frame):
				av_frame = Panel.new()
				av_frame.name = "AvatarMedallionFrame"
				av_frame.visible = false
				av_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
				av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
				av_container.add_child(av_frame)
				av_container.move_child(av_frame, 0)
			if player_idx == 1:
				_p1_avatar_frame = av_frame
			elif player_idx == 2:
				_p2_avatar_frame = av_frame

			seat_dot = av_container.get_node_or_null("SeatAccentDot") as Panel
			if not is_instance_valid(seat_dot):
				seat_dot = Panel.new()
				seat_dot.name = "SeatAccentDot"
				seat_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				seat_dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				seat_dot.offset_left = -12
				seat_dot.offset_top = -12
				seat_dot.offset_right = -1
				seat_dot.offset_bottom = -1
				av_container.add_child(seat_dot)
			var sb_dot := StyleBoxFlat.new()
			sb_dot.bg_color = HudTheme.get_seat_accent(player_idx)
			sb_dot.border_color = HudTheme.COL_WALNUT_DEEP
			sb_dot.set_border_width_all(2)
			sb_dot.set_corner_radius_all(6)
			seat_dot.add_theme_stylebox_override("panel", sb_dot)

			# Keep profile button topmost inside AvatarContainer
			for ch in av_container.get_children():
				if ch is Button:
					(ch as Button).focus_mode = Control.FOCUS_NONE
					av_container.move_child(ch, av_container.get_child_count() - 1)
					break

	# Integrated Bottom-Edge Progress Bar + Compact Seconds Chip (inside CardChromeOverlay)
	var old_overlay := card.get_node_or_null("CardChromeOverlay")
	if is_instance_valid(old_overlay):
		old_overlay.queue_free()

	var overlay := Control.new()
	overlay.name = "CardChromeOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = false
	card.add_child(overlay)

	var card_timer_fill := HudTheme.make_card_timer_fill_style(HudTheme.COL_GOLD_ACTIVE)
	var card_timer_bar := ProgressBar.new()
	card_timer_bar.name = "CardTimerBar"
	card_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_timer_bar.show_percentage = false
	card_timer_bar.min_value = 0.0
	card_timer_bar.max_value = 100.0
	card_timer_bar.value = 100.0
	card_timer_bar.visible = false
	card_timer_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card_timer_bar.offset_left = -4.0
	card_timer_bar.offset_right = 4.0
	card_timer_bar.offset_top = 2.0
	card_timer_bar.offset_bottom = 8.0
	card_timer_bar.add_theme_stylebox_override("background", HudTheme.make_card_timer_track_style())
	card_timer_bar.add_theme_stylebox_override("fill", card_timer_fill)
	overlay.add_child(card_timer_bar)

	var card_timer_chip := Label.new()
	card_timer_chip.name = "CardTimerChip"
	card_timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_timer_chip.visible = false
	card_timer_chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_timer_chip.offset_left = -2.0
	card_timer_chip.offset_top = -13.0
	card_timer_chip.offset_right = 42.0
	card_timer_chip.offset_bottom = 6.0
	if _font_vazir:
		card_timer_chip.add_theme_font_override("font", _font_vazir)
	card_timer_chip.add_theme_font_size_override("font_size", 11)
	card_timer_chip.add_theme_color_override("font_color", HudTheme.COL_TEXT_GOLD)
	card_timer_chip.add_theme_stylebox_override("normal", _style_chip_normal)
	card_timer_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_timer_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_timer_chip.text = ""
	overlay.add_child(card_timer_chip)

	_card_decorations[player_idx] = {
		"overlay": overlay,
		"timer_bar": card_timer_bar,
		"timer_fill": card_timer_fill,
		"timer_chip": card_timer_chip,
		"seat_dot": seat_dot,
	}


func _enhance_player_card(player_idx: int) -> void:
	var card := p1_card if player_idx == 1 else p2_card
	var avatar_rect := p1_avatar if player_idx == 1 else p2_avatar
	var name_lbl := p1_name if player_idx == 1 else p2_name
	var role_lbl := p1_role_badge if player_idx == 1 else p2_role_badge
	var score_lbl := p1_score_lbl if player_idx == 1 else p2_score_lbl
	_attach_card_decorations(player_idx, card, avatar_rect, name_lbl, role_lbl, score_lbl)


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
	var btn: Button = null
	if is_instance_valid(av_cont):
		av_cont.custom_minimum_size = Vector2(46, 46)
		if is_instance_valid(av):
			av.custom_minimum_size = Vector2(46, 46)
		for ch in av_cont.get_children():
			if ch is Button:
				btn = ch as Button
				break
	if is_instance_valid(btn):
		for c in btn.pressed.get_connections():
			btn.pressed.disconnect(c["callable"])
		btn.focus_mode = Control.FOCUS_NONE
		var captured_idx := idx
		btn.pressed.connect(func():
			if _can_emit_profile_click():
				player_profile_clicked.emit(captured_idx)
		)
	if is_instance_valid(rb):
		rb.top_level = true
		rb.visible = false
	_attach_card_decorations(idx, card, av, nm, rl, sc)
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


func _set_role_badge(player_idx: int, text: String, accent_col: Color = Color(-1, -1, -1)) -> void:
	var b := _get_player_card_bundle(player_idx)
	var rl: Label = b.get("role", null)
	if not is_instance_valid(rl):
		return
	var trimmed := text.strip_edges()
	rl.text = trimmed
	rl.visible = not trimmed.is_empty()
	if accent_col.r >= 0.0:
		rl.add_theme_stylebox_override("normal", HudTheme.make_status_pill_style(accent_col, 0.78))


func _set_active_cards_visual(active_indices: Array, is_danger: bool = false, pulse_active: bool = false) -> void:
	_active_card_indices = active_indices.duplicate()
	var compact := _total_players > 2
	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var card: PanelContainer = b.get("card", null)
		if not is_instance_valid(card) or not card.visible:
			continue
		var dec: Dictionary = _card_decorations.get(idx, {})
		var t_bar: ProgressBar = dec.get("timer_bar", null)
		var t_chip: Label = dec.get("timer_chip", null)

		if is_player_disabled(idx):
			_apply_disabled_visual(idx)
			if is_instance_valid(t_bar):
				t_bar.visible = false
			if is_instance_valid(t_chip):
				t_chip.visible = false
			continue

		var is_act := active_indices.has(idx)
		var style_act := _style_card_active_danger if is_danger else (_style_p1_active if not compact else _style_p3_active)
		var style_idle := _style_p1_inactive if not compact else _style_p3_inactive
		card.add_theme_stylebox_override("panel", style_act if is_act else style_idle)
		card.modulate = Color.WHITE if is_act else Color(0.88, 0.85, 0.82, 0.94)
		if is_act and pulse_active:
			_animate_card_pulse(card)
		elif not is_act:
			card.scale = Vector2.ONE
		if is_instance_valid(t_bar):
			t_bar.visible = is_act
		if is_instance_valid(t_chip):
			t_chip.visible = is_act and not t_chip.text.is_empty()


func _update_card_timer_visuals(remaining_sec: float, total_sec: float, active_indices: Array) -> void:
	var pct := clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
	var is_danger := (remaining_sec <= 4.0 and remaining_sec > 0.0)
	var sec_ceil := maxi(0, int(ceil(remaining_sec)))
	var chip_str := "%s″" % _fa_digits(sec_ceil)
	var fill_col := HudTheme.COL_DANGER if is_danger else HudTheme.COL_GOLD_ACTIVE

	for idx in [1, 2, 3, 4]:
		var dec: Dictionary = _card_decorations.get(idx, {})
		if dec.is_empty():
			continue
		var is_act := active_indices.has(idx) and not is_player_disabled(idx)
		var t_bar: ProgressBar = dec.get("timer_bar", null)
		var t_fill: StyleBoxFlat = dec.get("timer_fill", null)
		var t_chip: Label = dec.get("timer_chip", null)
		if is_instance_valid(t_bar):
			t_bar.visible = is_act
			if is_act:
				t_bar.value = pct
		if is_instance_valid(t_fill) and is_act:
			t_fill.bg_color = fill_col
		if is_instance_valid(t_chip):
			t_chip.visible = is_act
			if is_act:
				t_chip.text = chip_str
				t_chip.add_theme_stylebox_override("normal", _style_chip_danger if is_danger else _style_chip_normal)
				t_chip.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82) if is_danger else HudTheme.COL_TEXT_GOLD)

	var danger_i := 1 if is_danger else 0
	if danger_i != _cached_timer_danger:
		_cached_timer_danger = danger_i
		_set_active_cards_visual(active_indices, is_danger, false)

	if is_danger and sec_ceil != _last_critical_sec:
		_last_critical_sec = sec_ceil
		for idx in active_indices:
			var dec: Dictionary = _card_decorations.get(idx, {})
			var t_chip: Label = dec.get("timer_chip", null)
			if is_instance_valid(t_chip):
				_animate_chip_warning(t_chip)

	# Keep hidden legacy timer nodes synchronized
	if is_instance_valid(lbl_timer) and sec_ceil != _last_displayed_sec:
		_last_displayed_sec = sec_ceil
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % sec_ceil)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = pct


func _animate_chip_warning(chip: Control) -> void:
	if not is_instance_valid(chip):
		return
	chip.pivot_offset = chip.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chip, "scale", Vector2(1.18, 1.18), 0.11)
	tw.tween_property(chip, "scale", Vector2.ONE, 0.13)


func _is_score_based_game() -> bool:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.CHESS or g_type == GameTypes.FEKRBEKR:
		return false
	return GameRegistry.has_round_score(g_type)


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


func _get_role_badge_text(_player_idx: int) -> String:
	# Clean compact cards: hide redundant static role labels ("مهره قرمز" / "بازیکن ۱").
	# Games with live gameplay status (Monopoly props, Coup lives, UNO alert, etc.) set badges explicitly.
	return ""


func setup_match(game_name_fa: String, _mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	_last_displayed_sec = -1
	_last_critical_sec = -1
	_update_score_badges_visibility()
	update_spectator_count(GameManager.spectator_count)
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			lbl_round.text = "%s" % game_name_fa
		else:
			lbl_round.text = "راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % int(turn_time))
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	_set_role_badge(1, _get_role_badge_text(1))
	_set_role_badge(2, _get_role_badge_text(2))


func set_round(round_num: int, max_rounds: int) -> void:
	_update_score_badges_visibility()
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			var g_info = GameRegistry.get_game_info(GameManager.current_game_type)
			var game_name_fa = g_info.get("name_fa", "بازی")
			lbl_round.text = "%s" % game_name_fa
		else:
			lbl_round.text = "راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]


func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_profile_clicks_enabled = false
	_my_player_index = my_idx
	_update_score_badges_visibility()

	var p1_str := str(p1_data.get("name", p1_data.get("username", "میزبان")))
	var p2_str := str(p2_data.get("name", p2_data.get("username", "مهمان")))
	_player_names[1] = p1_str
	_player_names[2] = p2_str

	if is_instance_valid(p1_name):
		p1_name.text = p1_str
		HudTheme.configure_bidi_label(p1_name, true)
	if is_instance_valid(p2_name):
		p2_name.text = p2_str
		HudTheme.configure_bidi_label(p2_name, true)

	if is_instance_valid(p1_avatar):
		var p1_img_id = int(p1_data.get("image", p1_data.get("user_image", 0)))
		var p1_fid = GameManager.get_player_frame_id(p1_data)
		var tex1 = _get_cached_avatar(p1_img_id)
		if tex1:
			p1_avatar.texture = tex1
		var p1_parent = p1_avatar.get_parent()
		CafeSocialTheme.apply_frame_to_container(p1_parent if p1_parent is Control else p1_avatar, p1_avatar, p1_fid)

	if is_instance_valid(p2_avatar):
		var p2_img_id = int(p2_data.get("image", p2_data.get("user_image", 0)))
		var p2_fid = GameManager.get_player_frame_id(p2_data)
		var tex2 = _get_cached_avatar(p2_img_id)
		if tex2:
			p2_avatar.texture = tex2
		var p2_parent = p2_avatar.get_parent()
		CafeSocialTheme.apply_frame_to_container(p2_parent if p2_parent is Control else p2_avatar, p2_avatar, p2_fid)

	_set_role_badge(1, _get_role_badge_text(1))
	_set_role_badge(2, _get_role_badge_text(2))


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_cached_timer_danger = -1
	_update_score_badges_visibility()

	var is_simul: bool = bool(GameRegistry.is_simultaneous(GameManager.current_game_type))
	var is_p1 := (turn == 1)
	var is_me := (turn == my_idx)

	var active_list: Array = [1, 2] if is_simul else [turn]
	_set_active_cards_visual(active_list, false, not is_simul)

	# Lightweight fading turn toast
	if not GameManager.is_game_active:
		hide_turn_toast()
	elif is_simul:
		var sim_text := "سنگ، کاغذ یا قیچی را انتخاب کنید!" if GameManager.current_game_type == GameTypes.RPC else ("خانه‌های امن را باز کنید!" if GameManager.current_game_type == GameTypes.MSWEEPER else "حرکت خود را انتخاب کنید")
		show_turn_toast(sim_text, HudTheme.COL_TEXT_GOLD, false, 2.0)
	elif is_me:
		show_turn_toast("نوبت شماست", HudTheme.COL_TEXT_GOLD, false, 1.7)
	else:
		var opp_name := p1_n if is_p1 else p2_n
		show_turn_toast("نوبت %s" % opp_name, HudTheme.COL_TEXT_SAND, false, 1.5)

	_invalidate_timer_visual_cache()
	_on_turn_changed(turn)


func _animate_card_pulse(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.16)
	tw.tween_property(card, "scale", Vector2.ONE, 0.14)


func _invalidate_timer_visual_cache() -> void:
	_cached_timer_danger = -1
	_cached_timer_box_style = null
	_cached_timer_fill_color = Color(-1.0, -1.0, -1.0, -1.0)


func _apply_timer_visual_state(is_danger: bool, box_style: StyleBox, fill_col: Color) -> void:
	var danger_i: int = 1 if is_danger else 0
	if danger_i != _cached_timer_danger:
		_cached_timer_danger = danger_i
	if is_instance_valid(match_details_box) and box_style != null and box_style != _cached_timer_box_style:
		_cached_timer_box_style = box_style
		match_details_box.add_theme_stylebox_override("panel", box_style)
	if is_instance_valid(_timer_style_fill) and fill_col != _cached_timer_fill_color:
		_cached_timer_fill_color = fill_col
		_timer_style_fill.bg_color = fill_col


func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	var is_simul: bool = bool(GameRegistry.is_simultaneous(GameManager.current_game_type))
	var active_list: Array = [1, 2] if is_simul else [turn]
	_update_card_timer_visuals(remaining_sec, total_sec, active_list)


func update_scores(p1_score: int, p2_score: int) -> void:
	_update_score_badges_visibility()
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = _fa_digits(p1_score)
		if p1_score > _last_p1_score and _is_score_based_game():
			_animate_score_bump(p1_score_lbl.get_parent() as Control)
		_last_p1_score = p1_score
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = _fa_digits(p2_score)
		if p2_score > _last_p2_score and _is_score_based_game():
			_animate_score_bump(p2_score_lbl.get_parent() as Control)
		_last_p2_score = p2_score


func _animate_score_bump(badge: Control) -> void:
	if not is_instance_valid(badge):
		return
	badge.pivot_offset = badge.size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.20, 1.20), 0.14)
	tw.tween_property(badge, "scale", Vector2.ONE, 0.16)


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
	"این راندو خیلی حرفه‌ای بازی کردی!",
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


func show_reaction(user_index: int, reaction_id: int) -> void:
	var b := _get_player_card_bundle(user_index)
	var bubble: Control = b.get("reaction_bubble", null)
	var icon: TextureRect = b.get("reaction_icon", null)
	var player_card: Control = b.get("card", null)
	var av_container: Control = b.get("avatar_container", null)
	if not is_instance_valid(bubble) or not is_instance_valid(icon):
		return

	var next_seq: int = int(_reaction_seqs.get(user_index, 0)) + 1
	_reaction_seqs[user_index] = next_seq
	if user_index == 1:
		_p1_reaction_seq = next_seq
	elif user_index == 2:
		_p2_reaction_seq = next_seq

	var bubble_frame := bubble.get_node_or_null("BubbleFrame") as PanelContainer
	var kori_lbl: Label = null
	if is_instance_valid(bubble_frame):
		kori_lbl = bubble_frame.get_node_or_null("KoriLabel") as Label
		if not is_instance_valid(kori_lbl):
			kori_lbl = Label.new()
			kori_lbl.name = "KoriLabel"
			if _font_vazir:
				kori_lbl.add_theme_font_override("font", _font_vazir)
			kori_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kori_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			kori_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			kori_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bubble_frame.add_child(kori_lbl)
		kori_lbl.add_theme_font_size_override("font_size", 18)
		kori_lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		kori_lbl.add_theme_color_override("font_shadow_color", HudTheme.COL_SHADOW_DARK)
		kori_lbl.add_theme_constant_override("shadow_offset_y", 1)
		HudTheme.configure_bidi_label(kori_lbl, false)

	var is_kori := reaction_id > 100
	var bubble_size := Vector2(288.0, 74.0) if is_kori else Vector2(96.0, 96.0)
	var hold_duration := 3.6 if is_kori else 2.2

	if is_kori:
		var k_idx := clampi(reaction_id - 101, 0, KORIS.size() - 1)
		icon.visible = false
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = true
			kori_lbl.custom_minimum_size = Vector2(256.0, 48.0)
			kori_lbl.text = "💬 " + KORIS[k_idx]
		if is_instance_valid(bubble_frame):
			bubble_frame.add_theme_stylebox_override("panel", HudTheme.make_emote_bubble_style(true))
	else:
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = false
		icon.visible = true
		icon.custom_minimum_size = Vector2(76.0, 76.0)
		var r_tex := _get_cached_reaction(reaction_id)
		if r_tex:
			icon.texture = r_tex
		if is_instance_valid(bubble_frame):
			bubble_frame.add_theme_stylebox_override("panel", HudTheme.make_emote_bubble_style(false))

	if is_instance_valid(bubble_frame):
		var half := bubble_size * 0.5
		bubble_frame.custom_minimum_size = bubble_size
		bubble_frame.offset_left = -half.x
		bubble_frame.offset_top = -half.y
		bubble_frame.offset_right = half.x
		bubble_frame.offset_bottom = half.y
		bubble_frame.size = bubble_size

	# Anchor STRICTLY BELOW the player's avatar/card bottom edge (never overlapping name/counter!)
	bubble.z_index = 32
	bubble.top_level = true
	bubble.size = Vector2.ZERO
	bubble.custom_minimum_size = Vector2.ZERO
	bubble.pivot_offset = Vector2.ZERO
	if is_instance_valid(player_card):
		var card_rect := player_card.get_global_rect()
		var av_rect := av_container.get_global_rect() if is_instance_valid(av_container) else card_rect
		var vp_w := get_viewport_rect().size.x
		var half_w := bubble_size.x * 0.5
		var anchor_x := clampf(av_rect.get_center().x, half_w + 12.0, maxf(half_w + 12.0, vp_w - half_w - 12.0))
		var anchor_y := maxf(card_rect.end.y, av_rect.end.y) + 8.0 + bubble_size.y * 0.5
		bubble.global_position = Vector2(anchor_x, anchor_y)

	bubble.visible = true
	bubble.scale = Vector2(0.25, 0.25)
	bubble.modulate.a = 0.0
	bubble.rotation_degrees = -4.0 if (user_index % 2 == 1) else 4.0
	AudioManager.play_sound("chat")

	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.06, 1.06), 0.18)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.18)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.10)

	await get_tree().create_timer(hold_duration).timeout
	if int(_reaction_seqs.get(user_index, 0)) != next_seq:
		return
	if is_instance_valid(bubble) and bubble.visible:
		var fade_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_tw.tween_property(bubble, "scale", Vector2(0.88, 0.88), 0.22)
		fade_tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.24)
		await fade_tw.finished
		if int(_reaction_seqs.get(user_index, 0)) == next_seq and is_instance_valid(bubble):
			bubble.visible = false
			bubble.scale = Vector2.ONE
			bubble.rotation_degrees = 0.0


func reset_header() -> void:
	_profile_clicks_enabled = false
	_last_displayed_sec = -1
	_last_critical_sec = -1
	_invalidate_timer_visual_cache()
	_last_p1_score = 0
	_last_p2_score = 0
	_update_score_badges_visibility()
	hide_turn_toast()
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = _fa_digits(0)
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = _fa_digits(0)
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "--"
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0

	_disabled_players.clear()
	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var c: PanelContainer = b.get("card", null)
		if is_instance_valid(c):
			c.modulate = Color.WHITE
			c.scale = Vector2.ONE
			c.add_theme_stylebox_override("panel", _style_p1_inactive if _total_players <= 2 else _style_p3_inactive)
		var nm: Label = b.get("name", null)
		if is_instance_valid(nm):
			nm.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		var rl: Label = b.get("role", null)
		if is_instance_valid(rl):
			rl.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)
			rl.visible = false
		var rb: Control = b.get("reaction_bubble", null)
		if is_instance_valid(rb):
			rb.top_level = true
			rb.visible = false
		var dec: Dictionary = _card_decorations.get(idx, {})
		var t_bar: ProgressBar = dec.get("timer_bar", null)
		var t_chip: Label = dec.get("timer_chip", null)
		if is_instance_valid(t_bar):
			t_bar.visible = false
			t_bar.value = 100.0
		if is_instance_valid(t_chip):
			t_chip.visible = false
			t_chip.text = ""


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

	_p4_empty_spacer = Control.new()
	_p4_empty_spacer.name = "P4EmptySpacer"
	_p4_empty_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p4_empty_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p4_empty_spacer.visible = false
	_players_row2.add_child(_p4_empty_spacer)

	# Symmetrical spacer on Row 2 aligning with MenuColumn on Row 1
	_row2_menu_spacer = Control.new()
	_row2_menu_spacer.name = "Row2MenuSpacer"
	_row2_menu_spacer.custom_minimum_size = Vector2(MENU_COL_WIDTH, 0)
	_row2_menu_spacer.size_flags_horizontal = Control.SIZE_SHRINK_END
	_row2_menu_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_players_row2.add_child(_row2_menu_spacer)
	return _players_row2


func _update_two_row_visibility(total_players: int) -> void:
	_total_players = clampi(total_players, 2, 4)
	var is_multi := _total_players > 2
	var card_h := CARD_HEIGHT_MULTI if is_multi else CARD_HEIGHT_2P
	var av_sz := Vector2(46, 46) if is_multi else Vector2(56, 56)

	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var c: PanelContainer = b.get("card", null)
		var av_cont: Control = b.get("avatar_container", null)
		var av: TextureRect = b.get("avatar", null)
		var nm: Label = b.get("name", null)
		if is_instance_valid(c):
			c.custom_minimum_size = Vector2(0, card_h)
		if is_instance_valid(av_cont):
			av_cont.custom_minimum_size = av_sz
		if is_instance_valid(av):
			av.custom_minimum_size = av_sz
		if is_instance_valid(nm):
			nm.add_theme_font_size_override("font_size", 16 if is_multi else 18)

	var row2 := _get_or_create_players_row2()
	if is_instance_valid(row2):
		row2.visible = is_multi
		row2.add_theme_constant_override("separation", 8)
		if is_instance_valid(_p4_empty_spacer):
			row2.move_child(_p4_empty_spacer, row2.get_child_count() - 1)
			_p4_empty_spacer.visible = (_total_players == 3)
		if is_instance_valid(_row2_menu_spacer):
			row2.move_child(_row2_menu_spacer, row2.get_child_count() - 1)
			_row2_menu_spacer.visible = is_multi

	_sync_header_height()


func _get_player_card_bundle(player_idx: int) -> Dictionary:
	if player_idx == 1:
		return {
			"card": p1_card,
			"avatar": p1_avatar,
			"avatar_container": p1_avatar.get_parent() as Control if is_instance_valid(p1_avatar) else null,
			"av_frame": _p1_avatar_frame,
			"name": p1_name,
			"role": p1_role_badge,
			"score": p1_score_lbl,
			"reaction_bubble": p1_reaction_bubble,
			"reaction_icon": p1_reaction_icon,
		}
	elif player_idx == 2:
		return {
			"card": p2_card,
			"avatar": p2_avatar,
			"avatar_container": p2_avatar.get_parent() as Control if is_instance_valid(p2_avatar) else null,
			"av_frame": _p2_avatar_frame,
			"name": p2_name,
			"role": p2_role_badge,
			"score": p2_score_lbl,
			"reaction_bubble": p2_reaction_bubble,
			"reaction_icon": p2_reaction_icon,
		}
	elif _extra_cards.has(player_idx):
		return _extra_cards[player_idx]
	return {}


func is_player_disabled(player_idx: int) -> bool:
	return _disabled_players.has(player_idx)


func set_player_disabled(player_idx: int, disabled: bool, reason_text: String = "خارج شد") -> void:
	if player_idx < 1 or player_idx > 4:
		return
	if disabled:
		_disabled_players[player_idx] = reason_text if not reason_text.is_empty() else "خارج شد"
	else:
		_disabled_players.erase(player_idx)
	_apply_disabled_visual(player_idx)


func _apply_disabled_visual(player_idx: int) -> void:
	var b := _get_player_card_bundle(player_idx)
	var card: PanelContainer = b.get("card", null)
	var nm: Label = b.get("name", null)
	var rl: Label = b.get("role", null)
	var dec: Dictionary = _card_decorations.get(player_idx, {})
	if is_player_disabled(player_idx):
		var reason: String = str(_disabled_players.get(player_idx, "خارج شد"))
		if is_instance_valid(card):
			if is_instance_valid(_style_card_disabled):
				card.add_theme_stylebox_override("panel", _style_card_disabled)
			card.modulate = Color(0.58, 0.56, 0.54, 0.60)
			card.scale = Vector2(0.97, 0.97)
		if is_instance_valid(nm):
			nm.add_theme_color_override("font_color", Color(0.70, 0.68, 0.66, 0.85))
		if is_instance_valid(rl):
			var has_prefix := reason.begins_with("💀") or reason.begins_with("🏳") or reason.begins_with("🚫") or reason.begins_with("📡") or reason.begins_with("⏱")
			rl.text = reason if has_prefix else ("🚫 %s" % reason)
			rl.visible = true
			rl.add_theme_color_override("font_color", Color(0.95, 0.62, 0.62, 0.94))
		var t_bar: ProgressBar = dec.get("timer_bar", null)
		var t_chip: Label = dec.get("timer_chip", null)
		if is_instance_valid(t_bar):
			t_bar.visible = false
		if is_instance_valid(t_chip):
			t_chip.visible = false
	else:
		if is_instance_valid(card):
			card.modulate = Color.WHITE
			card.scale = Vector2.ONE
		if is_instance_valid(nm):
			nm.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		if is_instance_valid(rl):
			rl.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)


# Virtual hook for child headers
func _on_turn_changed(_turn: int) -> void:
	pass
