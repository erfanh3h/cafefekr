class_name BaseTopHeader
extends Control

# Base Top Header for Cafe Fekr
# Standard in-game top header for all board games.
# Manages Player 1 and Player 2 profile cards, scores, turn highlights,
# active turn banners, and real-time turn countdown timer with dynamic VFX.
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
var _p1_score_badge: PanelContainer = null
var _p2_score_badge: PanelContainer = null
var _timer_icon: TextureRect = null
var _timer_vfx_overlay: TimerBarVFXOverlay = null

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
static var _font_vazir: FontFile = preload("res://assets/fonts/Vazir.ttf")
static var _tex_time_icon: Texture2D = preload("res://assets/icons/General/time.png")


# ============================================================================
# REAL-TIME PROCEDURAL VFX OVERLAY FOR TURN TIMER BAR
# ============================================================================
class TimerBarVFXOverlay extends Control:
	var bar_ref: ProgressBar = null
	var icon_ref: TextureRect = null
	var is_danger: bool = false
	var is_active: bool = true
	var theme_color: Color = Color(0.25, 0.65, 1.0)
	var time_accum: float = 0.0
	var _sparks: Array = []
	var _shockwaves: Array = []
	var _spawn_accum: float = 0.0
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false

	func trigger_danger_shockwave() -> void:
		if not is_instance_valid(bar_ref):
			return
		var pct = clampf(bar_ref.value / 100.0, 0.0, 1.0)
		var tip_x = clampf(size.x * pct, 8.0, maxf(8.0, size.x - 6.0))
		_shockwaves.append({
			"pos": Vector2(tip_x, size.y * 0.5),
			"radius": 4.0,
			"max_radius": 34.0,
			"alpha": 1.0
		})
		for _i in range(12):
			_spawn_spark(tip_x, true, 1.45)

	func _process(delta: float) -> void:
		if not is_instance_valid(bar_ref) or not is_visible_in_tree():
			return
		time_accum += delta
		var pct = clampf(bar_ref.value / 100.0, 0.0, 1.0)

		# Ringing stopwatch icon animation when time is finishing
		if is_instance_valid(icon_ref):
			icon_ref.pivot_offset = icon_ref.size * 0.5
			if is_danger and pct > 0.005:
				icon_ref.rotation_degrees = sin(time_accum * 38.0) * 16.0
				var s_pulse = 1.0 + 0.14 * abs(sin(time_accum * 10.0))
				icon_ref.scale = Vector2(s_pulse, s_pulse)
				icon_ref.modulate = Color(1.0, 0.55 + 0.45 * abs(sin(time_accum * 12.0)), 0.45, 1.0)
			else:
				icon_ref.rotation_degrees = lerpf(icon_ref.rotation_degrees, 0.0, 12.0 * delta)
				icon_ref.scale = icon_ref.scale.lerp(Vector2.ONE, 10.0 * delta)
				icon_ref.modulate = Color.WHITE

		var tip_x = clampf(size.x * pct, 6.0, maxf(6.0, size.x - 4.0))
		if pct > 0.01 and size.x > 20.0:
			var spawn_rate = 42.0 if is_danger else 14.0
			_spawn_accum += delta * spawn_rate
			while _spawn_accum >= 1.0:
				_spawn_accum -= 1.0
				_spawn_spark(tip_x, is_danger, 1.0)

		for i in range(_sparks.size() - 1, -1, -1):
			var sp = _sparks[i]
			sp["age"] += delta
			if sp["age"] >= sp["life"]:
				_sparks.remove_at(i)
				continue
			sp["pos"] += sp["vel"] * delta
			sp["vel"].y += sp["grav"] * delta
			sp["pos"].y += sin(time_accum * 12.0 + sp["phase"]) * 8.0 * delta

		for i in range(_shockwaves.size() - 1, -1, -1):
			var sw = _shockwaves[i]
			sw["radius"] += delta * 95.0
			sw["alpha"] = clampf(1.0 - (sw["radius"] / sw["max_radius"]), 0.0, 1.0)
			if sw["alpha"] <= 0.02:
				_shockwaves.remove_at(i)

		queue_redraw()

	func _spawn_spark(tip_x: float, danger_mode: bool, speed_mult: float = 1.0) -> void:
		if _sparks.size() > 60:
			return
		var cy = size.y * 0.5 + _rng.randf_range(-size.y * 0.32, size.y * 0.32)
		var angle = _rng.randf_range(-PI * 0.88, PI * 0.88)
		var spd = _rng.randf_range(26.0, 76.0) * (1.45 if danger_mode else 0.75) * speed_mult
		var vx = -abs(cos(angle)) * spd + _rng.randf_range(-12.0, 22.0)
		var vy = sin(angle) * spd * 0.85
		var col: Color
		if danger_mode:
			var r_pick = _rng.randf()
			if r_pick < 0.38:
				col = Color(1.0, 0.96, 0.65, 1.0)
			elif r_pick < 0.72:
				col = Color(1.0, 0.55, 0.15, 1.0)
			else:
				col = Color(1.0, 0.22, 0.28, 1.0)
		else:
			col = theme_color.lightened(_rng.randf_range(0.32, 0.65))
			col.a = 0.95

		_sparks.append({
			"pos": Vector2(tip_x, cy),
			"vel": Vector2(vx, vy),
			"grav": _rng.randf_range(-16.0, 24.0),
			"size": _rng.randf_range(2.0, 4.2 if danger_mode else 3.2),
			"age": 0.0,
			"life": _rng.randf_range(0.26, 0.54 if danger_mode else 0.44),
			"col": col,
			"phase": _rng.randf_range(0.0, TAU)
		})

	func _draw() -> void:
		if not is_instance_valid(bar_ref) or size.x <= 10.0:
			return
		var pct = clampf(bar_ref.value / 100.0, 0.0, 1.0)
		if pct <= 0.005:
			return

		var pad: float = 2.0
		var inner_w: float = maxf(0.0, (size.x - pad * 2.0) * pct)
		var inner_h: float = maxf(4.0, size.y - pad * 2.0)
		var tip_x: float = pad + inner_w
		var center_y: float = size.y * 0.5

		# 1. CRITICAL FINISHING TIME: Pulsing Outer Neon Danger Aura around the Bar
		if is_danger:
			var danger_pulse = 0.5 + 0.5 * sin(time_accum * 15.0)
			var aura_col = Color(1.0, 0.22, 0.25, 0.32 + 0.45 * danger_pulse)
			draw_rect(Rect2(Vector2(-2.0, -2.0), size + Vector2(4.0, 4.0)), aura_col, false, 2.2 + danger_pulse * 1.4)
			var inner_flash = Color(1.0, 0.65, 0.20, 0.16 + 0.24 * danger_pulse)
			draw_rect(Rect2(Vector2(pad, pad), Vector2(inner_w, inner_h)), inner_flash, true)

		# 2. TRAVELING ENERGY SHIMMER WAVES along the filled bar
		var wave_speed = 2.4 if is_danger else 0.95
		var wave_count = 3
		for w_idx in range(wave_count):
			var phase = fmod(time_accum * wave_speed + float(w_idx) / float(wave_count), 1.0)
			var wx = pad + inner_w * phase
			var band_w = clampf(inner_w * 0.16, 12.0, 36.0)
			if wx - band_w * 0.5 >= pad and wx + band_w * 0.5 <= tip_x:
				var edge_fade = sin(phase * PI)
				var shimmer_col = Color(1.0, 0.95, 0.78, (0.34 if is_danger else 0.20) * edge_fade)
				draw_rect(Rect2(Vector2(wx - band_w * 0.5, pad + 1.0), Vector2(band_w, inner_h - 2.0)), shimmer_col, true)

		# 3. EXPANDING SHOCKWAVE RINGS (Critical Countdown)
		for sw in _shockwaves:
			var sw_col = Color(1.0, 0.55, 0.22, sw["alpha"] * 0.85)
			draw_arc(sw["pos"], sw["radius"], 0.0, TAU, 28, sw_col, 2.2)

		# 4. FLOATING SPARKLES & FIERY EMBERS
		for sp in _sparks:
			var t_norm = clampf(1.0 - (sp["age"] / sp["life"]), 0.0, 1.0)
			var c: Color = sp["col"]
			c.a *= t_norm
			var r: float = sp["size"] * (0.45 + 0.55 * t_norm)
			var p: Vector2 = sp["pos"]
			draw_circle(p, r * 1.8, Color(c.r, c.g, c.b, c.a * 0.32))
			draw_circle(p, r, c)

		# 5. GLOWING LEADING-EDGE COMET / FUSE HEAD AT TIP
		var tip_pos = Vector2(tip_x, center_y)
		var pulse = 1.0 + (0.28 if is_danger else 0.12) * sin(time_accum * (22.0 if is_danger else 8.0))
		var base_glow_col = Color(1.0, 0.35, 0.18, 0.45) if is_danger else Color(theme_color.r, theme_color.g, theme_color.b, 0.38)
		var mid_glow_col = Color(1.0, 0.75, 0.25, 0.82) if is_danger else theme_color.lightened(0.45)
		mid_glow_col.a = 0.82

		draw_circle(tip_pos, (12.0 if is_danger else 8.5) * pulse, base_glow_col)
		draw_circle(tip_pos, (7.5 if is_danger else 5.5) * pulse, mid_glow_col)
		draw_circle(tip_pos, (4.2 if is_danger else 3.2) * pulse, Color(1.0, 0.98, 0.88, 0.98))

		var ray_len = (14.0 if is_danger else 8.0) * pulse
		var rot = time_accum * (6.5 if is_danger else 2.2)
		var flare_col = Color(1.0, 0.92, 0.65, 0.90 if is_danger else 0.60)
		for k in range(4):
			var a = rot + float(k) * PI * 0.5
			var dir = Vector2(cos(a), sin(a))
			draw_line(tip_pos - dir * ray_len, tip_pos + dir * ray_len, flare_col, 2.0 if is_danger else 1.4)


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
	_update_score_badges_visibility()
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

	# Match Details Box Styles (Compact Sleek Game Clock Console)
	_style_match_box_normal = StyleBoxFlat.new()
	_style_match_box_normal.bg_color = Color(0.11, 0.07, 0.04, 0.94)
	_style_match_box_normal.border_color = Color(0.86, 0.66, 0.28, 0.90)
	_style_match_box_normal.set_border_width_all(2)
	_style_match_box_normal.border_width_bottom = 4
	_style_match_box_normal.set_corner_radius_all(18)
	_style_match_box_normal.shadow_color = Color(0, 0, 0, 0.55)
	_style_match_box_normal.shadow_size = 10
	_style_match_box_normal.shadow_offset = Vector2(0, 4)
	_style_match_box_normal.content_margin_left = 14
	_style_match_box_normal.content_margin_right = 14
	_style_match_box_normal.content_margin_top = 6
	_style_match_box_normal.content_margin_bottom = 8

	_style_match_box_p1 = _style_match_box_normal.duplicate()
	_style_match_box_p1.border_color = Color(0.95, 0.48, 0.36, 0.95)

	_style_match_box_p2 = _style_match_box_normal.duplicate()
	_style_match_box_p2.border_color = Color(0.42, 0.76, 0.98, 0.95)

	_style_match_box_danger = _style_match_box_normal.duplicate()
	_style_match_box_danger.border_color = Color(1.0, 0.28, 0.30, 1.0)
	_style_match_box_danger.shadow_color = Color(1.0, 0.15, 0.20, 0.55)

	# Timer Capsule Pill Styles (Compact)
	_style_timer_pill_normal = StyleBoxFlat.new()
	_style_timer_pill_normal.bg_color = Color(0.06, 0.04, 0.02, 0.92)
	_style_timer_pill_normal.border_color = Color(0.82, 0.64, 0.26, 0.85)
	_style_timer_pill_normal.set_border_width_all(1)
	_style_timer_pill_normal.set_corner_radius_all(10)
	_style_timer_pill_normal.content_margin_left = 10
	_style_timer_pill_normal.content_margin_right = 10
	_style_timer_pill_normal.content_margin_top = 1
	_style_timer_pill_normal.content_margin_bottom = 1

	_style_timer_pill_danger = _style_timer_pill_normal.duplicate()
	_style_timer_pill_danger.bg_color = Color(0.28, 0.05, 0.06, 0.96)
	_style_timer_pill_danger.border_color = Color(1.0, 0.32, 0.32, 1.0)
	_style_timer_pill_danger.shadow_color = Color(1.0, 0.18, 0.20, 0.55)
	_style_timer_pill_danger.shadow_size = 6

	# Timer Bar Background & Glossy Fill (Compact Sleek Bar)
	_timer_style_bg = StyleBoxFlat.new()
	_timer_style_bg.bg_color = Color(0.05, 0.03, 0.02, 0.95)
	_timer_style_bg.border_color = Color(0.66, 0.48, 0.24, 0.88)
	_timer_style_bg.set_border_width_all(2)
	_timer_style_bg.set_corner_radius_all(9)
	_timer_style_bg.content_margin_left = 2
	_timer_style_bg.content_margin_right = 2
	_timer_style_bg.content_margin_top = 2
	_timer_style_bg.content_margin_bottom = 2

	_timer_style_fill = StyleBoxFlat.new()
	_timer_style_fill.bg_color = Color(0.25, 0.65, 1.0)
	_timer_style_fill.border_color = Color(1.0, 0.96, 0.82, 0.55)
	_timer_style_fill.border_width_top = 2
	_timer_style_fill.set_corner_radius_all(7)

	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.custom_minimum_size = Vector2(460, 16)
		turn_timer_bar.add_theme_stylebox_override("background", _timer_style_bg)
		turn_timer_bar.add_theme_stylebox_override("fill", _timer_style_fill)

	if is_instance_valid(match_details_box):
		match_details_box.custom_minimum_size = Vector2(540, 0)
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)

func _build_game_ui_enhancements() -> void:
	# 1. Enhance Player 1 & Player 2 Cards (Avatar Medallion, Side Tag, Role Pill, Score Shield)
	_enhance_player_card(1)
	_enhance_player_card(2)

	# 2. Restructure MatchDetailsBox into a Sleek, Compact 2-Row Console (without shrinking font sizes!)
	var vbox_main = get_node_or_null("Margin/VBoxMain") as VBoxContainer
	if vbox_main:
		vbox_main.add_theme_constant_override("separation", 8)

	var match_vbox = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox") as VBoxContainer
	var round_panel = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel") as PanelContainer
	var timer_row = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow") as HBoxContainer

	if round_panel:
		var sb_round = StyleBoxFlat.new()
		sb_round.bg_color = Color(0.22, 0.13, 0.05, 0.92)
		sb_round.border_color = Color(0.95, 0.78, 0.30, 0.85)
		sb_round.set_border_width_all(1)
		sb_round.set_corner_radius_all(10)
		sb_round.content_margin_left = 12
		sb_round.content_margin_right = 12
		sb_round.content_margin_top = 1
		sb_round.content_margin_bottom = 1
		round_panel.add_theme_stylebox_override("panel", sb_round)

	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_turn_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if timer_row and is_instance_valid(lbl_timer):
		timer_row.add_theme_constant_override("separation", 6)
		if not is_instance_valid(_timer_icon):
			_timer_icon = TextureRect.new()
			_timer_icon.name = "TimerStopwatchIcon"
			_timer_icon.texture = _tex_time_icon
			_timer_icon.custom_minimum_size = Vector2(24, 24)
			_timer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_timer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_timer_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_timer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timer_row.add_child(_timer_icon)
			timer_row.move_child(_timer_icon, 0)

		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)

	# Combine [TimerRow] + [TurnBanner] + [RoundPanel] into a single compact top row inside MatchDetailsBox/VBox!
	if match_vbox and round_panel and timer_row and is_instance_valid(lbl_turn_banner):
		match_vbox.add_theme_constant_override("separation", 5)
		var top_compact_row = HBoxContainer.new()
		top_compact_row.name = "TopCompactRow"
		top_compact_row.alignment = BoxContainer.ALIGNMENT_CENTER
		top_compact_row.add_theme_constant_override("separation", 12)
		top_compact_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match_vbox.add_child(top_compact_row)
		match_vbox.move_child(top_compact_row, 0)

		timer_row.reparent(top_compact_row)
		lbl_turn_banner.reparent(top_compact_row)
		round_panel.reparent(top_compact_row)

	# 3. Attach Real-Time Procedural VFX Overlay to TurnTimerBar
	if is_instance_valid(turn_timer_bar) and not is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay = TimerBarVFXOverlay.new()
		_timer_vfx_overlay.name = "TimerBarVFXOverlay"
		_timer_vfx_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_timer_vfx_overlay.bar_ref = turn_timer_bar
		_timer_vfx_overlay.icon_ref = _timer_icon
		turn_timer_bar.add_child(_timer_vfx_overlay)

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

			avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			avatar_rect.offset_left = 6.0
			avatar_rect.offset_top = 6.0
			avatar_rect.offset_right = -6.0
			avatar_rect.offset_bottom = -6.0

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

	# C. Clean Score Badge with Standard Normal Font (`Vazir.ttf` + clean digits)
	if is_instance_valid(score_lbl):
		var score_badge = score_lbl.get_parent() as PanelContainer
		if score_badge:
			if player_idx == 1:
				_p1_score_badge = score_badge
			else:
				_p2_score_badge = score_badge
			score_badge.custom_minimum_size = Vector2(58, 58)
			var sb_score = StyleBoxFlat.new()
			sb_score.bg_color = Color(0.09, 0.05, 0.03, 0.92)
			sb_score.border_color = Color(0.94, 0.76, 0.28, 0.90)
			sb_score.set_border_width_all(2)
			sb_score.border_width_bottom = 3
			sb_score.set_corner_radius_all(14)
			sb_score.shadow_color = Color(0, 0, 0, 0.40)
			sb_score.shadow_size = 4
			sb_score.content_margin_left = 6
			sb_score.content_margin_right = 6
			sb_score.content_margin_top = 4
			sb_score.content_margin_bottom = 4
			score_badge.add_theme_stylebox_override("panel", sb_score)

			# Use Persian game font (hekayat.ttf) + Persian numerals like on the FekrBekr board
			if _font_hekayat:
				score_lbl.add_theme_font_override("font", _font_hekayat)
			score_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			score_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.95))
			score_lbl.add_theme_constant_override("outline_size", 3)
			score_lbl.add_theme_font_size_override("font_size", 40)
			score_lbl.text = _fa_digits(0)

func _is_score_based_game() -> bool:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.CHESS or g_type == GameTypes.FEKRBEKR:
		return false
	return GameRegistry.has_round_score(g_type)

func _update_score_badges_visibility() -> void:
	var show_scores = _is_score_based_game()
	if is_instance_valid(_p1_score_badge):
		_p1_score_badge.visible = show_scores
	elif is_instance_valid(p1_score_lbl) and p1_score_lbl.get_parent() is Control:
		(p1_score_lbl.get_parent() as Control).visible = show_scores
	if is_instance_valid(_p2_score_badge):
		_p2_score_badge.visible = show_scores
	elif is_instance_valid(p2_score_lbl) and p2_score_lbl.get_parent() is Control:
		(p2_score_lbl.get_parent() as Control).visible = show_scores

func _get_role_badge_text(player_idx: int) -> String:
	var g_type = GameManager.current_game_type
	if g_type == GameTypes.FEKRBEKR:
		return "🔐 کدشکن"
	elif g_type == GameTypes.YATZY:
		return "🎲 تاس‌انداز قرمز" if player_idx == 1 else "🎲 تاس‌انداز آبی"
	elif g_type == GameTypes.CHESS:
		return "🔴 ارتش قرمز" if player_idx == 1 else "🔵 ارتش آبی"
	elif g_type == GameTypes.MSWEEPER:
		return "💣 کاوشگر قرمز" if player_idx == 1 else "💣 کاوشگر آبی"
	elif g_type == GameTypes.YINSH:
		return "⭕ حلقه قرمز" if player_idx == 1 else "🔵 حلقه آبی"
	elif g_type == GameTypes.BOXFOUR:
		return "💥 قلمرو قرمز" if player_idx == 1 else "💥 قلمرو آبی"
	else:
		return "🔴 مهره قرمز" if player_idx == 1 else "🔵 مهره آبی"

func setup_match(game_name_fa: String, _mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	_last_displayed_sec = -1
	_update_score_badges_visibility()
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			lbl_round.text = "%s" % game_name_fa
		else:
			lbl_round.text = "راند %s از %s" % [_fa_digits(round_num), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % int(turn_time))
		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = Color(0.92, 0.72, 0.22) if GameManager.current_game_type == GameTypes.FEKRBEKR else Color(0.25, 0.65, 1.0)
	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = _get_role_badge_text(1)
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = _get_role_badge_text(2)

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
	_my_player_index = my_idx
	_update_score_badges_visibility()

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
	_update_score_badges_visibility()

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

	var is_simul = GameRegistry.is_simultaneous(GameManager.current_game_type)
	if is_simul:
		if is_instance_valid(p1_card):
			p1_card.add_theme_stylebox_override("panel", _style_p1_active)
			p1_card.scale = Vector2.ONE
		if is_instance_valid(p2_card):
			p2_card.add_theme_stylebox_override("panel", _style_p2_active)
			p2_card.scale = Vector2.ONE
		if is_instance_valid(match_details_box):
			match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
	elif is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_p1 if is_p1 else _style_match_box_p2)

	# Timer Fill Color & VFX Theme Color
	var fill_col = Color(1.0, 0.85, 0.30) if is_simul else (Color(1.0, 0.32, 0.35) if is_p1 else Color(0.25, 0.65, 1.0))
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = fill_col
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = fill_col

	# Concise, high-impact Turn Banner Text
	if is_instance_valid(lbl_turn_banner):
		if not GameManager.is_game_active:
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		elif is_simul:
			var sim_text = "سنگ، کاغذ یا قیچی را انتخاب کنید!" if GameManager.current_game_type == GameTypes.RPC else ("خانه‌های امن را باز کنید و ۱۰ مین را پرچم بزنید!" if GameManager.current_game_type == GameTypes.MSWEEPER else "انتخاب خود را مشخص کنید")
			lbl_turn_banner.text = sim_text
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		elif is_me:
			var color_str = "قرمز" if is_p1 else "آبی"
			var dot = "🔴" if is_p1 else "🔵"
			lbl_turn_banner.text = "%s نوبت شماست (%s)" % [dot, color_str]
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		else:
			var opp_name = p1_n if is_p1 else p2_n
			lbl_turn_banner.text = "⏳ نوبت %s" % opp_name
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
	var fill_col = Color(1.0, 0.85, 0.30) if GameRegistry.is_simultaneous(GameManager.current_game_type) else (Color(1.0, 0.32, 0.35) if turn == 1 else Color(0.25, 0.65, 1.0))
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = is_danger
		_timer_vfx_overlay.theme_color = fill_col

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
				if is_instance_valid(_timer_vfx_overlay):
					_timer_vfx_overlay.trigger_danger_shockwave()
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
			_timer_style_fill.bg_color = fill_col

func _animate_timer_warning() -> void:
	if not is_instance_valid(lbl_timer):
		return
	lbl_timer.pivot_offset = lbl_timer.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl_timer, "scale", Vector2(1.18, 1.18), 0.12)
	tw.tween_property(lbl_timer, "scale", Vector2(1.0, 1.0), 0.14)

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
	badge.pivot_offset = badge.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(badge, "scale", Vector2(1.24, 1.24), 0.16)
	tw.tween_property(badge, "scale", Vector2(1.0, 1.0), 0.18)

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

var _p1_reaction_seq: int = 0
var _p2_reaction_seq: int = 0

func show_reaction(user_index: int, reaction_id: int) -> void:
	var bubble = p1_reaction_bubble if user_index == 1 else p2_reaction_bubble
	var icon = p1_reaction_icon if user_index == 1 else p2_reaction_icon
	if not is_instance_valid(bubble) or not is_instance_valid(icon):
		return

	if user_index == 1:
		_p1_reaction_seq += 1
	else:
		_p2_reaction_seq += 1
	var my_seq = _p1_reaction_seq if user_index == 1 else _p2_reaction_seq

	var bubble_frame = bubble.get_node_or_null("BubbleFrame") as PanelContainer
	var kori_lbl: Label = null
	if is_instance_valid(bubble_frame):
		kori_lbl = bubble_frame.get_node_or_null("KoriLabel") as Label
		if not is_instance_valid(kori_lbl):
			kori_lbl = Label.new()
			kori_lbl.name = "KoriLabel"
			kori_lbl.add_theme_font_override("font", _font_hekayat)
			kori_lbl.add_theme_font_size_override("font_size", 24)
			kori_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
			kori_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			kori_lbl.add_theme_constant_override("shadow_offset_y", 2)
			kori_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kori_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			kori_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			kori_lbl.custom_minimum_size = Vector2(290, 74)
			bubble_frame.add_child(kori_lbl)

	bubble.z_index = 30
	var hold_duration = 2.4

	if reaction_id > 100:
		# Persian Kori (کری‌خوانی) Speech Bubble
		var k_idx = clampi(reaction_id - 101, 0, KORIS.size() - 1)
		icon.visible = false
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = true
			kori_lbl.text = "💬 " + KORIS[k_idx]
		if is_instance_valid(bubble_frame):
			bubble_frame.custom_minimum_size = Vector2(330, 104)
			bubble_frame.offset_left = -165.0
			bubble_frame.offset_top = -52.0
			bubble_frame.offset_right = 165.0
			bubble_frame.offset_bottom = 52.0
		hold_duration = 4.2
	else:
		# Sticker / Emoji Reaction
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = false
		icon.visible = true
		if is_instance_valid(bubble_frame):
			bubble_frame.custom_minimum_size = Vector2(120, 120)
			bubble_frame.offset_left = -60.0
			bubble_frame.offset_top = -60.0
			bubble_frame.offset_right = 60.0
			bubble_frame.offset_bottom = 60.0
		var r_tex = _get_cached_reaction(reaction_id)
		if r_tex:
			icon.texture = r_tex

	bubble.visible = true
	bubble.scale = Vector2(0.1, 0.1)
	bubble.modulate.a = 0.0
	bubble.pivot_offset = bubble.size * 0.5

	var start_rot = (-4.0 if user_index == 1 else 4.0) if reaction_id > 100 else (-7.0 if user_index == 1 else 7.0)
	bubble.rotation_degrees = start_rot

	AudioManager.play_sound("chat")

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.12, 1.12) if reaction_id > 100 else Vector2(1.18, 1.18), 0.22)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.22)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.1)

	if reaction_id <= 100:
		var idle_tw = create_tween().set_loops(3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle_tw.tween_property(bubble, "scale", Vector2(1.05, 1.05), 0.35)
		idle_tw.parallel().tween_property(bubble, "rotation_degrees", -3.5 if user_index == 1 else 3.5, 0.35)
		idle_tw.tween_property(bubble, "scale", Vector2.ONE, 0.35)
		idle_tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.35)

	await get_tree().create_timer(hold_duration).timeout
	var current_seq = _p1_reaction_seq if user_index == 1 else _p2_reaction_seq
	if current_seq != my_seq:
		return
	if is_instance_valid(bubble) and bubble.visible:
		var fade_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tw.tween_property(bubble, "scale", Vector2(1.08, 1.08), 0.1)
		fade_tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.28)
		await fade_tw.finished
		var after_seq = _p1_reaction_seq if user_index == 1 else _p2_reaction_seq
		if after_seq == my_seq and is_instance_valid(bubble):
			bubble.visible = false
			bubble.scale = Vector2.ONE
			bubble.rotation_degrees = 0.0

func reset_header() -> void:
	_last_displayed_sec = -1
	_last_p1_score = 0
	_last_p2_score = 0
	_update_score_badges_visibility()
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = _fa_digits(0)
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = _fa_digits(0)
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "--"
		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay._sparks.clear()
		_timer_vfx_overlay._shockwaves.clear()
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
