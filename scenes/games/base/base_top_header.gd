class_name BaseTopHeader
extends Control

# Base Top Header for Cafe Fekr
# Standard in-game top header for all board games.
# Manages Player 1 and Player 2 profile cards, scores, turn highlights,
# active turn banners, and real-time turn countdown timer.
# Extended via inheritance for games requiring custom header widgets (e.g. ChessTopHeader).

signal p1_profile_clicked()
signal p2_profile_clicked()

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

# --- Match Details & Turn Timer Nodes ---
@onready var match_details_box: PanelContainer = $Margin/VBoxMain/MatchDetailsBox
@onready var lbl_round: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel/LblRound
@onready var lbl_turn_banner: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnBanner
@onready var lbl_timer: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow/LblTimer
@onready var turn_timer_bar: ProgressBar = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnTimerBar

# --- Theme Styles ---
var _style_p1_active: StyleBoxFlat
var _style_p1_inactive: StyleBoxFlat
var _style_p2_active: StyleBoxFlat
var _style_p2_inactive: StyleBoxFlat
var _timer_style_fill: StyleBoxFlat
var _timer_style_bg: StyleBoxFlat
var _style_match_box_normal: StyleBoxFlat
var _style_match_box_p1: StyleBoxFlat
var _style_match_box_p2: StyleBoxFlat
var _style_match_box_danger: StyleBoxFlat
var _style_timer_pill_normal: StyleBoxFlat
var _style_timer_pill_danger: StyleBoxFlat
var _style_avatar_p1_active: StyleBoxFlat
var _style_avatar_p1_idle: StyleBoxFlat
var _style_avatar_p2_active: StyleBoxFlat
var _style_avatar_p2_idle: StyleBoxFlat

# --- Dynamic Game-UI Decorations ---
var _p1_avatar_frame: Panel = null
var _p2_avatar_frame: Panel = null
var _p1_side_tag: Label = null
var _p2_side_tag: Label = null
var _p1_turn_pill: PanelContainer = null
var _p2_turn_pill: PanelContainer = null
var _p1_turn_lbl: Label = null
var _p2_turn_lbl: Label = null
var _timer_pill: PanelContainer = null
var _timer_icon: TextureRect = null
var _vs_badge: PanelContainer = null

# --- State ---
var _current_turn: int = 1
var _my_player_index: int = 1
var _last_critical_sec: int = -1
var _last_displayed_sec: int = -1
var _last_p1_score: int = 0
var _last_p2_score: int = 0

static var _avatar_cache: Dictionary = {}
static var _reaction_cache: Dictionary = {}
static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")
static var _tex_time_icon: Texture2D = preload("res://assets/icons/General/time.png")
static var _tex_cup_icon: Texture2D = preload("res://assets/icons/General/cup.png")
static var _tex_wood_disc: Texture2D = preload("res://assets/images/frames/button5.png")

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
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out

func _ready() -> void:
	_setup_styles()
	_build_game_ui_enhancements()
	_connect_buttons()
	if is_instance_valid(p1_reaction_bubble):
		p1_reaction_bubble.visible = false
	if is_instance_valid(p2_reaction_bubble):
		p2_reaction_bubble.visible = false

func _connect_buttons() -> void:
	if is_instance_valid(btn_p1_profile):
		btn_p1_profile.pressed.connect(func(): p1_profile_clicked.emit())
	if is_instance_valid(btn_p2_profile):
		btn_p2_profile.pressed.connect(func(): p2_profile_clicked.emit())

func _setup_styles() -> void:
	# P1 Active (Royal Crimson-Gold Illuminated Plaque)
	_style_p1_active = StyleBoxFlat.new()
	_style_p1_active.bg_color = Color(0.28, 0.07, 0.09, 0.96)
	_style_p1_active.border_color = Color(1.0, 0.42, 0.38, 1.0)
	_style_p1_active.set_border_width_all(3)
	_style_p1_active.border_width_bottom = 6
	_style_p1_active.set_corner_radius_all(22)
	_style_p1_active.shadow_color = Color(1.0, 0.18, 0.24, 0.55)
	_style_p1_active.shadow_size = 18
	_style_p1_active.shadow_offset = Vector2(0, 5)
	_style_p1_active.content_margin_left = 14
	_style_p1_active.content_margin_top = 10
	_style_p1_active.content_margin_right = 14
	_style_p1_active.content_margin_bottom = 12

	# P1 Inactive (Carved Dark Walnut Plaque with Warm Brass Trim)
	_style_p1_inactive = StyleBoxFlat.new()
	_style_p1_inactive.bg_color = Color(0.13, 0.08, 0.05, 0.90)
	_style_p1_inactive.border_color = Color(0.54, 0.36, 0.20, 0.82)
	_style_p1_inactive.set_border_width_all(2)
	_style_p1_inactive.border_width_bottom = 5
	_style_p1_inactive.set_corner_radius_all(22)
	_style_p1_inactive.shadow_color = Color(0, 0, 0, 0.52)
	_style_p1_inactive.shadow_size = 10
	_style_p1_inactive.shadow_offset = Vector2(0, 4)
	_style_p1_inactive.content_margin_left = 14
	_style_p1_inactive.content_margin_top = 10
	_style_p1_inactive.content_margin_right = 14
	_style_p1_inactive.content_margin_bottom = 12

	# P2 Active (Royal Sapphire-Gold Illuminated Plaque)
	_style_p2_active = StyleBoxFlat.new()
	_style_p2_active.bg_color = Color(0.07, 0.15, 0.30, 0.96)
	_style_p2_active.border_color = Color(0.32, 0.76, 1.0, 1.0)
	_style_p2_active.set_border_width_all(3)
	_style_p2_active.border_width_bottom = 6
	_style_p2_active.set_corner_radius_all(22)
	_style_p2_active.shadow_color = Color(0.18, 0.56, 1.0, 0.55)
	_style_p2_active.shadow_size = 18
	_style_p2_active.shadow_offset = Vector2(0, 5)
	_style_p2_active.content_margin_left = 14
	_style_p2_active.content_margin_top = 10
	_style_p2_active.content_margin_right = 14
	_style_p2_active.content_margin_bottom = 12

	# P2 Inactive
	_style_p2_inactive = _style_p1_inactive.duplicate()

	# Avatar Medallion Rings
	_style_avatar_p1_active = StyleBoxFlat.new()
	_style_avatar_p1_active.bg_color = Color(0.22, 0.06, 0.08, 0.95)
	_style_avatar_p1_active.border_color = Color(1.0, 0.48, 0.42, 1.0)
	_style_avatar_p1_active.set_border_width_all(3)
	_style_avatar_p1_active.set_corner_radius_all(20)
	_style_avatar_p1_active.shadow_color = Color(1.0, 0.25, 0.30, 0.50)
	_style_avatar_p1_active.shadow_size = 8

	_style_avatar_p1_idle = StyleBoxFlat.new()
	_style_avatar_p1_idle.bg_color = Color(0.16, 0.10, 0.06, 0.92)
	_style_avatar_p1_idle.border_color = Color(0.76, 0.58, 0.28, 0.85)
	_style_avatar_p1_idle.set_border_width_all(2)
	_style_avatar_p1_idle.set_corner_radius_all(20)

	_style_avatar_p2_active = StyleBoxFlat.new()
	_style_avatar_p2_active.bg_color = Color(0.06, 0.14, 0.26, 0.95)
	_style_avatar_p2_active.border_color = Color(0.38, 0.80, 1.0, 1.0)
	_style_avatar_p2_active.set_border_width_all(3)
	_style_avatar_p2_active.set_corner_radius_all(20)
	_style_avatar_p2_active.shadow_color = Color(0.20, 0.62, 1.0, 0.50)
	_style_avatar_p2_active.shadow_size = 8

	_style_avatar_p2_idle = _style_avatar_p1_idle.duplicate()

	# Match Details Box Styles (Carved Game Clock Console)
	_style_match_box_normal = StyleBoxFlat.new()
	_style_match_box_normal.bg_color = Color(0.11, 0.07, 0.04, 0.95)
	_style_match_box_normal.border_color = Color(0.86, 0.66, 0.28, 0.92)
	_style_match_box_normal.set_border_width_all(3)
	_style_match_box_normal.border_width_bottom = 6
	_style_match_box_normal.set_corner_radius_all(24)
	_style_match_box_normal.shadow_color = Color(0, 0, 0, 0.62)
	_style_match_box_normal.shadow_size = 16
	_style_match_box_normal.shadow_offset = Vector2(0, 6)
	_style_match_box_normal.content_margin_left = 24
	_style_match_box_normal.content_margin_right = 24
	_style_match_box_normal.content_margin_top = 10
	_style_match_box_normal.content_margin_bottom = 14

	_style_match_box_p1 = _style_match_box_normal.duplicate()
	_style_match_box_p1.border_color = Color(0.95, 0.48, 0.36, 0.95)

	_style_match_box_p2 = _style_match_box_normal.duplicate()
	_style_match_box_p2.border_color = Color(0.42, 0.76, 0.98, 0.95)

	_style_match_box_danger = _style_match_box_normal.duplicate()
	_style_match_box_danger.border_color = Color(1.0, 0.28, 0.30, 1.0)
	_style_match_box_danger.shadow_color = Color(1.0, 0.15, 0.20, 0.55)

	# Timer Capsule Pill Styles
	_style_timer_pill_normal = StyleBoxFlat.new()
	_style_timer_pill_normal.bg_color = Color(0.06, 0.04, 0.02, 0.92)
	_style_timer_pill_normal.border_color = Color(0.82, 0.64, 0.26, 0.85)
	_style_timer_pill_normal.set_border_width_all(2)
	_style_timer_pill_normal.set_corner_radius_all(14)
	_style_timer_pill_normal.content_margin_left = 16
	_style_timer_pill_normal.content_margin_right = 16
	_style_timer_pill_normal.content_margin_top = 3
	_style_timer_pill_normal.content_margin_bottom = 3

	_style_timer_pill_danger = _style_timer_pill_normal.duplicate()
	_style_timer_pill_danger.bg_color = Color(0.28, 0.05, 0.06, 0.96)
	_style_timer_pill_danger.border_color = Color(1.0, 0.32, 0.32, 1.0)
	_style_timer_pill_danger.shadow_color = Color(1.0, 0.18, 0.20, 0.55)
	_style_timer_pill_danger.shadow_size = 8

	# Timer Bar Background & Glossy Fill
	_timer_style_bg = StyleBoxFlat.new()
	_timer_style_bg.bg_color = Color(0.05, 0.03, 0.02, 0.95)
	_timer_style_bg.border_color = Color(0.66, 0.48, 0.24, 0.88)
	_timer_style_bg.set_border_width_all(2)
	_timer_style_bg.set_corner_radius_all(11)
	_timer_style_bg.content_margin_left = 3
	_timer_style_bg.content_margin_right = 3
	_timer_style_bg.content_margin_top = 3
	_timer_style_bg.content_margin_bottom = 3

	_timer_style_fill = StyleBoxFlat.new()
	_timer_style_fill.bg_color = Color(0.25, 0.65, 1.0)
	_timer_style_fill.border_color = Color(1.0, 0.96, 0.82, 0.55)
	_timer_style_fill.border_width_top = 3
	_timer_style_fill.set_corner_radius_all(9)

	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.custom_minimum_size = Vector2(480, 22)
		turn_timer_bar.add_theme_stylebox_override("background", _timer_style_bg)
		turn_timer_bar.add_theme_stylebox_override("fill", _timer_style_fill)

	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)

func _build_game_ui_enhancements() -> void:
	# 1. Enhance Player 1 & Player 2 Cards (Avatar Medallion, Side Tag, Role Pill, Score Shield, Active Turn Crown)
	_enhance_player_card(1)
	_enhance_player_card(2)

	# 2. Add Center "VS / ⚔️" Duel Emblem overlay on PlayersRow
	var players_row = get_node_or_null("Margin/VBoxMain/PlayersRow") as Control
	if players_row and not is_instance_valid(_vs_badge):
		players_row.add_theme_constant_override("separation", 22)
		var vs_holder = Control.new()
		vs_holder.name = "VsOverlayHolder"
		vs_holder.set_anchors_preset(Control.PRESET_CENTER)
		vs_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vs_holder.z_index = 5
		# Since PlayersRow is an HBoxContainer, attach the floating VS badge to Margin/VBoxMain or P1Card's right edge
		if is_instance_valid(p1_card):
			_vs_badge = PanelContainer.new()
			_vs_badge.name = "VsDuelBadge"
			_vs_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_vs_badge.custom_minimum_size = Vector2(44, 44)
			var sb_vs = StyleBoxFlat.new()
			sb_vs.bg_color = Color(0.18, 0.11, 0.05, 0.98)
			sb_vs.border_color = Color(0.96, 0.78, 0.28, 1.0)
			sb_vs.set_border_width_all(2)
			sb_vs.set_corner_radius_all(22)
			sb_vs.shadow_color = Color(0, 0, 0, 0.65)
			sb_vs.shadow_size = 8
			_vs_badge.add_theme_stylebox_override("panel", sb_vs)

			var lbl_vs = Label.new()
			lbl_vs.text = "⚔️"
			lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl_vs.add_theme_font_size_override("font_size", 20)
			lbl_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_vs_badge.add_child(lbl_vs)

			vs_holder.add_child(_vs_badge)
			add_child(vs_holder)
			_vs_badge.position = Vector2(-22, 94)

	# 3. Enhance MatchDetailsBox: Round Crown Ribbon, Turn Banner Strip, and Stopwatch Timer Capsule
	var round_panel = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel") as PanelContainer
	if round_panel:
		var sb_round = StyleBoxFlat.new()
		sb_round.bg_color = Color(0.24, 0.14, 0.06, 0.96)
		sb_round.border_color = Color(0.95, 0.78, 0.30, 0.92)
		sb_round.set_border_width_all(2)
		sb_round.set_corner_radius_all(14)
		sb_round.content_margin_left = 20
		sb_round.content_margin_right = 20
		sb_round.content_margin_top = 3
		sb_round.content_margin_bottom = 3
		round_panel.add_theme_stylebox_override("panel", sb_round)

	if is_instance_valid(lbl_turn_banner):
		var sb_banner = StyleBoxFlat.new()
		sb_banner.bg_color = Color(0.06, 0.04, 0.02, 0.65)
		sb_banner.border_color = Color(0.55, 0.40, 0.22, 0.45)
		sb_banner.set_border_width_all(1)
		sb_banner.set_corner_radius_all(12)
		sb_banner.content_margin_left = 16
		sb_banner.content_margin_right = 16
		sb_banner.content_margin_top = 4
		sb_banner.content_margin_bottom = 4
		lbl_turn_banner.add_theme_stylebox_override("normal", sb_banner)

	var timer_row = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow") as HBoxContainer
	if timer_row and is_instance_valid(lbl_timer):
		timer_row.add_theme_constant_override("separation", 10)
		if not is_instance_valid(_timer_icon):
			_timer_icon = TextureRect.new()
			_timer_icon.name = "TimerStopwatchIcon"
			_timer_icon.texture = _tex_time_icon
			_timer_icon.custom_minimum_size = Vector2(28, 28)
			_timer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_timer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_timer_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_timer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timer_row.add_child(_timer_icon)
			timer_row.move_child(_timer_icon, 0)

		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
		lbl_timer.add_theme_font_size_override("font_size", 28)

func _enhance_player_card(player_idx: int) -> void:
	var card = p1_card if player_idx == 1 else p2_card
	var avatar_rect = p1_avatar if player_idx == 1 else p2_avatar
	var name_lbl = p1_name if player_idx == 1 else p2_name
	var role_lbl = p1_role_badge if player_idx == 1 else p2_role_badge
	var score_lbl = p1_score_lbl if player_idx == 1 else p2_score_lbl
	if not is_instance_valid(card):
		return

	# A. Framed Avatar Medallion + Side Tag ("شما" / "حریف")
	if is_instance_valid(avatar_rect):
		var av_container = avatar_rect.get_parent() as Control
		if av_container:
			var av_frame = Panel.new()
			av_frame.name = "AvatarMedallionFrame"
			av_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			av_frame.add_theme_stylebox_override("panel", _style_avatar_p1_idle if player_idx == 1 else _style_avatar_p2_idle)
			av_container.add_child(av_frame)
			av_container.move_child(av_frame, 0)

			# Inset avatar slightly inside the medallion frame
			avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			avatar_rect.offset_left = 6.0
			avatar_rect.offset_top = 6.0
			avatar_rect.offset_right = -6.0
			avatar_rect.offset_bottom = -6.0

			# Bottom Mini-Tag ("شما" / "حریف")
			var side_lbl = Label.new()
			side_lbl.name = "PlayerSideTag"
			side_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			side_lbl.offset_top = -24.0
			side_lbl.offset_bottom = 2.0
			side_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			side_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			side_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _font_hekayat:
				side_lbl.add_theme_font_override("font", _font_hekayat)
			side_lbl.add_theme_font_size_override("font_size", 18)
			side_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
			side_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
			side_lbl.add_theme_constant_override("outline_size", 2)

			var sb_side = StyleBoxFlat.new()
			sb_side.bg_color = Color(0.78, 0.18, 0.22, 0.94) if player_idx == 1 else Color(0.16, 0.45, 0.82, 0.94)
			sb_side.border_color = Color(0.96, 0.80, 0.35, 0.90)
			sb_side.set_border_width_all(1)
			sb_side.set_corner_radius_all(8)
			side_lbl.add_theme_stylebox_override("normal", sb_side)
			side_lbl.text = "شما" if player_idx == 1 else "حریف"
			av_container.add_child(side_lbl)
			# Ensure BtnP1Profile / BtnP2Profile stays on top for clicks
			var btn_prof = btn_p1_profile if player_idx == 1 else btn_p2_profile
			if is_instance_valid(btn_prof):
				av_container.move_child(btn_prof, av_container.get_child_count() - 1)

			if player_idx == 1:
				_p1_avatar_frame = av_frame
				_p1_side_tag = side_lbl
			else:
				_p2_avatar_frame = av_frame
				_p2_side_tag = side_lbl

	# B. Crisp Game Typography & Role Pill Styling
	if is_instance_valid(name_lbl):
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
		name_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 0.95))
		name_lbl.add_theme_constant_override("outline_size", 3)
		name_lbl.clip_text = true

	if is_instance_valid(role_lbl):
		role_lbl.add_theme_font_size_override("font_size", 22)
		role_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
		role_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.9))
		role_lbl.add_theme_constant_override("outline_size", 2)
		var sb_role = StyleBoxFlat.new()
		sb_role.bg_color = Color(0.38, 0.10, 0.12, 0.78) if player_idx == 1 else Color(0.10, 0.24, 0.44, 0.78)
		sb_role.border_color = Color(0.95, 0.45, 0.45, 0.65) if player_idx == 1 else Color(0.40, 0.75, 1.0, 0.65)
		sb_role.set_border_width_all(1)
		sb_role.set_corner_radius_all(10)
		sb_role.content_margin_left = 10
		sb_role.content_margin_right = 10
		sb_role.content_margin_top = 2
		sb_role.content_margin_bottom = 2
		role_lbl.add_theme_stylebox_override("normal", sb_role)

	# C. 3D Trophy Score Shield Plaque (`ScoreBadge`)
	if is_instance_valid(score_lbl):
		var score_badge = score_lbl.get_parent() as PanelContainer
		if score_badge:
			score_badge.custom_minimum_size = Vector2(68, 86)
			var sb_score = StyleBoxFlat.new()
			sb_score.bg_color = Color(0.09, 0.05, 0.03, 0.94)
			sb_score.border_color = Color(0.94, 0.76, 0.28, 0.92)
			sb_score.set_border_width_all(2)
			sb_score.border_width_bottom = 4
			sb_score.set_corner_radius_all(16)
			sb_score.shadow_color = Color(0, 0, 0, 0.45)
			sb_score.shadow_size = 6
			sb_score.content_margin_left = 8
			sb_score.content_margin_right = 8
			sb_score.content_margin_top = 4
			sb_score.content_margin_bottom = 4
			score_badge.add_theme_stylebox_override("panel", sb_score)

			score_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
			score_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.95))
			score_lbl.add_theme_constant_override("outline_size", 3)
			score_lbl.add_theme_font_size_override("font_size", 42)

			# Small golden trophy crown label at top of ScoreBadge
			var crown_lbl = Label.new()
			crown_lbl.name = "ScoreCrownTag"
			crown_lbl.text = "🏆"
			crown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			crown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			crown_lbl.add_theme_font_size_override("font_size", 15)
			crown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			score_badge.add_child(crown_lbl)

func _get_role_badge_text(player_idx: int) -> String:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.FEKRBEKR:
		return "🔐 کدشکن"
	elif g_type == GameTypes.CHESS:
		return "🔴 ارتش قرمز" if player_idx == 1 else "🔵 ارتش آبی"
	else:
		return "🔴 مهره قرمز" if player_idx == 1 else "🔵 مهره آبی"

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	_last_displayed_sec = -1
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			lbl_round.text = "👑 %s — %s" % [game_name_fa, mode_title]
		else:
			lbl_round.text = "🏆 راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % int(turn_time))
		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = _get_role_badge_text(1)
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = _get_role_badge_text(2)

func set_round(round_num: int, max_rounds: int) -> void:
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			var g_info = GameRegistry.get_game_info(GameManager.current_game_type)
			var game_name_fa = g_info.get("name_fa", "بازی")
			lbl_round.text = "👑 %s" % game_name_fa
		else:
			lbl_round.text = "🏆 راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]

func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_my_player_index = my_idx

	if is_instance_valid(p1_name):
		p1_name.text = p1_data.get("name", "میزبان")
	if is_instance_valid(p2_name):
		p2_name.text = p2_data.get("name", "مهمان")

	if is_instance_valid(p1_avatar):
		var p1_img_id = int(p1_data.get("image", p1_data.get("user_image", 0)))
		var tex1 = _get_cached_avatar(p1_img_id)
		if tex1:
			p1_avatar.texture = tex1

	if is_instance_valid(p2_avatar):
		var p2_img_id = int(p2_data.get("image", p2_data.get("user_image", 0)))
		var tex2 = _get_cached_avatar(p2_img_id)
		if tex2:
			p2_avatar.texture = tex2

	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = _get_role_badge_text(1)
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = _get_role_badge_text(2)

	if is_instance_valid(_p1_side_tag):
		_p1_side_tag.text = "شما" if my_idx == 1 else "حریف"
	if is_instance_valid(_p2_side_tag):
		_p2_side_tag.text = "شما" if my_idx == 2 else "حریف"

func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1

	var is_p1 = (turn == 1)
	var is_me = (turn == my_idx)

	# Update Player Cards & Avatar Medallions Active/Inactive Highlights
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_active if is_p1 else _style_p1_inactive)
		if is_instance_valid(_p1_avatar_frame):
			_p1_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p1_active if is_p1 else _style_avatar_p1_idle)
		if is_p1:
			_animate_card_pulse(p1_card)
		else:
			p1_card.scale = Vector2.ONE

	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_active if not is_p1 else _style_p2_inactive)
		if is_instance_valid(_p2_avatar_frame):
			_p2_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p2_active if not is_p1 else _style_avatar_p2_idle)
		if not is_p1:
			_animate_card_pulse(p2_card)
		else:
			p2_card.scale = Vector2.ONE

	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_p1 if is_p1 else _style_match_box_p2)

	# Timer Fill Color
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(1.0, 0.32, 0.35) if is_p1 else Color(0.25, 0.65, 1.0)

	# Turn Banner Text
	if is_instance_valid(lbl_turn_banner):
		if not GameManager.is_game_active:
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		elif is_me:
			var color_str = "قرمز" if is_p1 else "آبی"
			var dot = "🔴" if is_p1 else "🔵"
			lbl_turn_banner.text = "%s نوبت شماست (%s) — یک خانه خالی انتخاب کنید" % [dot, color_str]
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		else:
			var opp_name = p1_n if is_p1 else p2_n
			var opp_color = "قرمز" if is_p1 else "آبی"
			lbl_turn_banner.text = "⏳ نوبت %s (%s) — در انتظار حرکت حریف..." % [opp_name, opp_color]
			lbl_turn_banner.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	_on_turn_changed(turn)

func _animate_card_pulse(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.18)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.14)

func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	var is_danger = (remaining_sec <= 4.0 and remaining_sec > 0.0)
	if is_instance_valid(lbl_timer):
		var sec_ceil = int(ceil(remaining_sec))
		if sec_ceil != _last_displayed_sec:
			_last_displayed_sec = sec_ceil
			lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % sec_ceil)
		if is_danger:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
			lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_danger)
			if sec_ceil != _last_critical_sec:
				_last_critical_sec = sec_ceil
				_animate_timer_warning()
		else:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)

	if is_instance_valid(match_details_box):
		if is_danger:
			match_details_box.add_theme_stylebox_override("panel", _style_match_box_danger)
		elif GameManager.current_game_type == GameTypes.FEKRBEKR:
			match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
		else:
			match_details_box.add_theme_stylebox_override("panel", _style_match_box_p1 if turn == 1 else _style_match_box_p2)

	if is_instance_valid(turn_timer_bar):
		var pct = clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
		turn_timer_bar.value = pct

	if is_instance_valid(_timer_style_fill):
		if is_danger:
			_timer_style_fill.bg_color = Color(1.0, 0.24, 0.26)
		else:
			_timer_style_fill.bg_color = Color(1.0, 0.32, 0.35) if turn == 1 else Color(0.25, 0.65, 1.0)

func _animate_timer_warning() -> void:
	if not is_instance_valid(lbl_timer):
		return
	lbl_timer.pivot_offset = lbl_timer.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl_timer, "scale", Vector2(1.18, 1.18), 0.12)
	tw.tween_property(lbl_timer, "scale", Vector2(1.0, 1.0), 0.14)
	if is_instance_valid(_timer_icon):
		_timer_icon.pivot_offset = _timer_icon.size / 2.0
		var tw_i = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_i.tween_property(_timer_icon, "scale", Vector2(1.25, 1.25), 0.12)
		tw_i.tween_property(_timer_icon, "scale", Vector2(1.0, 1.0), 0.14)

func update_scores(p1_score: int, p2_score: int) -> void:
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = _fa_digits(p1_score)
		if p1_score > _last_p1_score:
			_animate_score_bump(p1_score_lbl.get_parent() as Control)
		_last_p1_score = p1_score
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = _fa_digits(p2_score)
		if p2_score > _last_p2_score:
			_animate_score_bump(p2_score_lbl.get_parent() as Control)
		_last_p2_score = p2_score

func _animate_score_bump(badge: Control) -> void:
	if not is_instance_valid(badge):
		return
	badge.pivot_offset = badge.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.24, 1.24), 0.16)
	tw.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.18)

func show_reaction(user_index: int, reaction_id: int) -> void:
	var bubble = p1_reaction_bubble if user_index == 1 else p2_reaction_bubble
	var icon = p1_reaction_icon if user_index == 1 else p2_reaction_icon
	if not is_instance_valid(bubble) or not is_instance_valid(icon):
		return

	var r_tex = _get_cached_reaction(reaction_id)
	if r_tex:
		icon.texture = r_tex

	bubble.visible = true
	bubble.scale = Vector2(0.1, 0.1)
	bubble.modulate.a = 0.0
	bubble.pivot_offset = Vector2(60, 60)

	var start_rot = -7.0 if user_index == 1 else 7.0
	bubble.rotation_degrees = start_rot

	AudioManager.play_sound("chat")

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.18, 1.18), 0.22)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.22)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.1)

	var idle_tw = create_tween().set_loops(3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tw.tween_property(bubble, "scale", Vector2(1.05, 1.05), 0.35)
	idle_tw.parallel().tween_property(bubble, "rotation_degrees", -3.5 if user_index == 1 else 3.5, 0.35)
	idle_tw.tween_property(bubble, "scale", Vector2.ONE, 0.35)
	idle_tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.35)

	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(bubble) and bubble.visible:
		var fade_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tw.tween_property(bubble, "scale", Vector2(1.12, 1.12), 0.1)
		fade_tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.28)
		await fade_tw.finished
		if is_instance_valid(bubble):
			bubble.visible = false
			bubble.scale = Vector2.ONE
			bubble.rotation_degrees = 0.0

func reset_header() -> void:
	_last_displayed_sec = -1
	_last_p1_score = 0
	_last_p2_score = 0
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = "۰"
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = "۰"
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "--"
		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_inactive)
		p1_card.scale = Vector2.ONE
	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_inactive)
		p2_card.scale = Vector2.ONE
	if is_instance_valid(_p1_avatar_frame):
		_p1_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p1_idle)
	if is_instance_valid(_p2_avatar_frame):
		_p2_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p2_idle)
	if is_instance_valid(p1_reaction_bubble):
		p1_reaction_bubble.visible = false
	if is_instance_valid(p2_reaction_bubble):
		p2_reaction_bubble.visible = false

# Virtual hook for child headers
func _on_turn_changed(_turn: int) -> void:
	pass
