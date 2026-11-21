extends Control

# Game Result Dialog
# High-polish, celebratory game result modal for Cafe Fekr
# Features rotating sunburst aura, 3D metallic medal crest, star crown,
# continuous celebratory particle confetti shower, and juicy bouncy entrance animations.

signal return_to_menu_requested()
signal rematch_requested()

# Modal Nodes
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var confetti_shower: CPUParticles2D = $ConfettiShower
@onready var defeat_particles: CPUParticles2D = $DefeatParticles

# Emblem Nodes
@onready var emblem_box: Control = $CenterContainer/Panel/VBox/EmblemBox
@onready var aura_ray: TextureRect = $CenterContainer/Panel/VBox/EmblemBox/AuraRay
@onready var aura_sparkles: CPUParticles2D = $CenterContainer/Panel/VBox/EmblemBox/AuraSparkles
@onready var plaque: PanelContainer = $CenterContainer/Panel/VBox/EmblemBox/Plaque
@onready var icon_center: TextureRect = $CenterContainer/Panel/VBox/EmblemBox/Plaque/IconCenter
@onready var star_crown: HBoxContainer = $CenterContainer/Panel/VBox/EmblemBox/StarCrown
@onready var star_left: TextureRect = $CenterContainer/Panel/VBox/EmblemBox/StarCrown/StarLeft
@onready var star_center: TextureRect = $CenterContainer/Panel/VBox/EmblemBox/StarCrown/StarCenter
@onready var star_right: TextureRect = $CenterContainer/Panel/VBox/EmblemBox/StarCrown/StarRight

# Typography
@onready var lbl_title: Label = $CenterContainer/Panel/VBox/LblTitle
@onready var lbl_subtitle: Label = $CenterContainer/Panel/VBox/LblSubtitle

# Player 1
@onready var p1_card: PanelContainer = $CenterContainer/Panel/VBox/MatchupBox/P1Card
@onready var p1_winner_tag: Label = $CenterContainer/Panel/VBox/MatchupBox/P1Card/VBox/WinnerTag
@onready var img_p1_avatar: TextureRect = $CenterContainer/Panel/VBox/MatchupBox/P1Card/VBox/Avatar
@onready var lbl_p1_name: Label = $CenterContainer/Panel/VBox/MatchupBox/P1Card/VBox/Name
@onready var lbl_p1_score: Label = $CenterContainer/Panel/VBox/MatchupBox/P1Card/VBox/Score

# Player 2
@onready var p2_card: PanelContainer = $CenterContainer/Panel/VBox/MatchupBox/P2Card
@onready var p2_winner_tag: Label = $CenterContainer/Panel/VBox/MatchupBox/P2Card/VBox/WinnerTag
@onready var img_p2_avatar: TextureRect = $CenterContainer/Panel/VBox/MatchupBox/P2Card/VBox/Avatar
@onready var lbl_p2_name: Label = $CenterContainer/Panel/VBox/MatchupBox/P2Card/VBox/Name
@onready var lbl_p2_score: Label = $CenterContainer/Panel/VBox/MatchupBox/P2Card/VBox/Score

# Rewards
@onready var rewards_hbox: HBoxContainer = $CenterContainer/Panel/VBox/RewardsHBox
@onready var coin_chip: PanelContainer = $CenterContainer/Panel/VBox/RewardsHBox/CoinChip
@onready var lbl_coin: Label = $CenterContainer/Panel/VBox/RewardsHBox/CoinChip/LblCoin
@onready var lbl_xp: Label = $CenterContainer/Panel/VBox/RewardsHBox/XPChip/LblXP

# Buttons
@onready var btn_return: Button = $CenterContainer/Panel/VBox/ButtonsRow/BtnReturn

# Icons
var _icon_win = preload("res://assets/icons/General/cup.png")
var _icon_lose = preload("res://assets/icons/General/lose_white.png")
var _icon_draw = preload("res://assets/icons/General/draw.png")

var _style_winner: StyleBoxFlat
var _style_normal: StyleBoxFlat
var _style_plaque_win: StyleBoxFlat
var _style_plaque_lose: StyleBoxFlat
var _style_plaque_draw: StyleBoxFlat

var _aura_tween: Tween = null
var _aura_pulse: Tween = null
var _particle_stop_token: int = 0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel and is_instance_valid(panel):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_chip.visible = false
	_setup_styles()
	if _is_mobile():
		if is_instance_valid(confetti_shower):
			confetti_shower.amount = maxi(16, int(confetti_shower.amount * 0.55))
		if is_instance_valid(defeat_particles):
			defeat_particles.amount = maxi(10, int(defeat_particles.amount * 0.55))
		if is_instance_valid(aura_sparkles):
			aura_sparkles.amount = maxi(8, int(aura_sparkles.amount * 0.55))
	
	# Authentic Kenney 3D Depth Buttons & Action Juice
	KenneyUI.style_button(btn_return, KenneyUI.COLOR_BLUE)
	
	btn_return.pressed.connect(func():
		AudioManager.sfx_button()
		close()
		return_to_menu_requested.emit()
	)

func _setup_styles() -> void:
	var mobile_mode := _is_mobile()
	# Winner Card Style
	_style_winner = StyleBoxFlat.new()
	_style_winner.bg_color = Color(0.24, 0.15, 0.08, 0.95)
	_style_winner.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_style_winner.set_border_width_all(3)
	_style_winner.set_corner_radius_all(18)
	_style_winner.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
	_style_winner.shadow_size = 0 if mobile_mode else 10
	_style_winner.content_margin_left = 16
	_style_winner.content_margin_right = 16
	_style_winner.content_margin_top = 14
	_style_winner.content_margin_bottom = 14

	# Normal Card Style
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.12, 0.08, 0.05, 0.85)
	_style_normal.border_color = Color(0.38, 0.28, 0.18, 0.7)
	_style_normal.set_border_width_all(2)
	_style_normal.set_corner_radius_all(18)
	_style_normal.content_margin_left = 16
	_style_normal.content_margin_right = 16
	_style_normal.content_margin_top = 14
	_style_normal.content_margin_bottom = 14

	# Plaque Styles for Win, Lose, Draw
	_style_plaque_win = StyleBoxFlat.new()
	_style_plaque_win.bg_color = Color(0.2, 0.12, 0.04, 0.98)
	_style_plaque_win.border_color = Color(1.0, 0.88, 0.32, 1.0)
	_style_plaque_win.set_border_width_all(4)
	_style_plaque_win.set_corner_radius_all(48)
	_style_plaque_win.shadow_color = Color(1.0, 0.82, 0.22, 0.5)
	_style_plaque_win.shadow_size = 0 if mobile_mode else 16

	_style_plaque_lose = StyleBoxFlat.new()
	_style_plaque_lose.bg_color = Color(0.11, 0.13, 0.20, 0.98)
	_style_plaque_lose.border_color = Color(0.72, 0.84, 0.98, 1.0)
	_style_plaque_lose.set_border_width_all(3)
	_style_plaque_lose.set_corner_radius_all(48)
	_style_plaque_lose.shadow_color = Color(0.35, 0.55, 0.9, 0.45)
	_style_plaque_lose.shadow_size = 0 if mobile_mode else 14

	_style_plaque_draw = StyleBoxFlat.new()
	_style_plaque_draw.bg_color = Color(0.14, 0.11, 0.08, 0.98)
	_style_plaque_draw.border_color = Color(0.85, 0.72, 0.45, 1.0)
	_style_plaque_draw.set_border_width_all(3)
	_style_plaque_draw.set_corner_radius_all(48)
	_style_plaque_draw.shadow_color = Color(0.65, 0.5, 0.2, 0.35)
	_style_plaque_draw.shadow_size = 0 if mobile_mode else 12

var _current_winner_index: int = -1
var _current_is_friendly: bool = true
var _current_xp_earned: int = 0
var _current_coin_earned: int = 0
var _current_score_earned: int = 0
var _score_chip: PanelContainer = null
var _lbl_score_delta: Label = null
var _multi_podium_box: VBoxContainer = null


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _ensure_score_chip() -> void:
	if is_instance_valid(_score_chip) or not is_instance_valid(rewards_hbox):
		return
	_score_chip = PanelContainer.new()
	_score_chip.name = "ScoreChip"
	_score_chip.visible = false
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	sb.bg_color = Color(0.10, 0.24, 0.14, 0.94)
	sb.border_color = Color(0.35, 0.92, 0.52, 0.90)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	_score_chip.add_theme_stylebox_override("panel", sb)

	_lbl_score_delta = Label.new()
	_lbl_score_delta.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	_lbl_score_delta.add_theme_font_size_override("font_size", 24)
	_lbl_score_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_chip.add_child(_lbl_score_delta)
	rewards_hbox.add_child(_score_chip)
	rewards_hbox.move_child(_score_chip, 0)


func _apply_avatar_frame_safe(avatar_rect: TextureRect, frame_id: int, slot_sz: float = 74.0) -> void:
	if not is_instance_valid(avatar_rect):
		return
	var p := avatar_rect.get_parent()
	var slot: Control = null
	if p is Control and p.name.ends_with("_AvatarSlot"):
		slot = p as Control
	elif p is Container:
		var idx := avatar_rect.get_index()
		slot = Control.new()
		slot.name = avatar_rect.name + "_AvatarSlot"
		slot.custom_minimum_size = Vector2(slot_sz, slot_sz)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(slot)
		p.move_child(slot, idx)
		p.remove_child(avatar_rect)
		slot.add_child(avatar_rect)
		avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		slot = p as Control if p is Control else avatar_rect
	CafeSocialTheme.apply_frame_to_container(slot, avatar_rect, frame_id)


func _apply_rewards_ui(xp_earned: int, coin_earned: int, score_earned: int) -> void:
	_ensure_score_chip()
	var has_reward := false
	if score_earned != 0 and is_instance_valid(_score_chip) and is_instance_valid(_lbl_score_delta):
		_score_chip.visible = true
		var is_pos := score_earned > 0
		var sb: StyleBoxFlat = _score_chip.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.bg_color = Color(0.10, 0.25, 0.14, 0.95) if is_pos else Color(0.28, 0.08, 0.08, 0.95)
			sb.border_color = Color(0.35, 0.92, 0.52, 0.92) if is_pos else Color(0.95, 0.36, 0.36, 0.92)
		var sign_s := "+" if is_pos else "-"
		_lbl_score_delta.text = "🏆 %s%s امتیاز رنک" % [sign_s, _fa_digits(abs(score_earned))]
		_lbl_score_delta.add_theme_color_override("font_color", Color(0.45, 0.98, 0.62) if is_pos else Color(1.0, 0.52, 0.52))
		has_reward = true
	elif is_instance_valid(_score_chip):
		_score_chip.visible = false

	if xp_earned > 0:
		if is_instance_valid(lbl_xp) and is_instance_valid(lbl_xp.get_parent()):
			lbl_xp.get_parent().visible = true
			lbl_xp.text = "⚡ +%s تجربه" % _fa_digits(xp_earned)
		has_reward = true
	else:
		if is_instance_valid(lbl_xp) and is_instance_valid(lbl_xp.get_parent()):
			lbl_xp.get_parent().visible = false

	if coin_earned > 0:
		if is_instance_valid(coin_chip):
			coin_chip.visible = true
		if is_instance_valid(lbl_coin):
			lbl_coin.text = "🪙 +%s سکه" % _fa_digits(coin_earned)
		has_reward = true
	else:
		if is_instance_valid(coin_chip):
			coin_chip.visible = false

	rewards_hbox.visible = has_reward


func _get_side_suffix(game_type: String, p_idx: int) -> String:
	match game_type:
		GameTypes.CHESS, GameTypes.BACKGAMMON:
			return " (سفید)" if p_idx == 1 else " (سیاه)"
		GameTypes.OTHELLO:
			return " (سیاه)" if p_idx == 1 else " (سفید)"
		GameTypes.CHECKERS:
			return " (قرمز)" if p_idx == 1 else " (سیاه)"
		GameTypes.TIC_TAC_TOE, GameTypes.FOURINROW, GameTypes.DOTBOX, GameTypes.PENTAGO, GameTypes.QUORIDOR, GameTypes.MILL, GameTypes.YINSH, GameTypes.BOXFOUR, GameTypes.LUDO:
			return " (قرمز)" if p_idx == 1 else " (آبی)"
		_:
			return ""


func _build_multiplayer_podium(winner_player_index: int, my_idx: int) -> void:
	var matchup_box: Control = p1_card.get_parent() as Control
	var root_vbox: VBoxContainer = matchup_box.get_parent() as VBoxContainer
	if not is_instance_valid(_multi_podium_box):
		_multi_podium_box = VBoxContainer.new()
		_multi_podium_box.name = "MultiPodiumBox"
		_multi_podium_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_multi_podium_box.add_theme_constant_override("separation", 8)
		root_vbox.add_child(_multi_podium_box)
		root_vbox.move_child(_multi_podium_box, matchup_box.get_index() + 1)
	for ch in _multi_podium_box.get_children():
		ch.queue_free()
	_multi_podium_box.visible = true
	matchup_box.visible = false

	# Assemble ordered list of all 3..4 players (1st, 2nd, remaining)
	var total_p: int = clampi(GameManager.match_players.size(), 3, 4)
	var ordered_ids: Array[int] = []
	var r1: int = GameManager.ludo_rank1 if GameManager.ludo_rank1 > 0 else clampi(winner_player_index, 1, total_p)
	var r2: int = GameManager.ludo_rank2 if GameManager.ludo_rank2 > 0 else 0
	if r1 >= 1 and r1 <= total_p:
		ordered_ids.append(r1)
	if r2 >= 1 and r2 <= total_p and not ordered_ids.has(r2):
		ordered_ids.append(r2)
	for pid in range(1, total_p + 1):
		if not ordered_ids.has(pid):
			ordered_ids.append(pid)

	var medals := ["👑 اول", "🥈 دوم", "🥉 سوم", "۴ام"]
	var accent_cols := [
		Color(1.0, 0.86, 0.30),
		Color(0.84, 0.88, 0.96),
		Color(0.90, 0.62, 0.36),
		Color(0.75, 0.68, 0.58)
	]

	for rank_i in range(ordered_ids.size()):
		var pid: int = ordered_ids[rank_i]
		var pd: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
		var pname := str(pd.get("name", pd.get("username", "بازیکن %s" % _fa_digits(pid))))
		var is_me: bool = (pid == my_idx)

		var row_card := PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.22, 0.15, 0.07, 0.95) if rank_i == 0 else (Color(0.12, 0.22, 0.14, 0.92) if is_me else Color(0.12, 0.08, 0.05, 0.88))
		rsb.border_color = accent_cols[rank_i] if rank_i == 0 else (Color(0.38, 0.88, 0.54, 0.92) if is_me else Color(0.45, 0.34, 0.20, 0.70))
		rsb.set_border_width_all(2 if (rank_i == 0 or is_me) else 1)
		rsb.set_corner_radius_all(12)
		rsb.content_margin_left = 12.0
		rsb.content_margin_right = 12.0
		rsb.content_margin_top = 6.0
		rsb.content_margin_bottom = 6.0
		row_card.add_theme_stylebox_override("panel", rsb)

		var rh := HBoxContainer.new()
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		rh.add_theme_constant_override("separation", 10)
		row_card.add_child(rh)

		var badge_lbl := Label.new()
		badge_lbl.text = medals[min(rank_i, medals.size() - 1)]
		badge_lbl.custom_minimum_size = Vector2(88, 0)
		badge_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		badge_lbl.add_theme_font_size_override("font_size", CafeSocialTheme.FONT_SIZE_BADGE)
		badge_lbl.add_theme_color_override("font_color", accent_cols[min(rank_i, accent_cols.size() - 1)])
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rh.add_child(badge_lbl)

		var name_lbl := Label.new()
		name_lbl.text = "%s (شما)" % pname if is_me else pname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.68) if is_me else Color(1.0, 0.96, 0.88))
		rh.add_child(name_lbl)

		var av_id := int(pd.get("image", pd.get("user_image", 0)))
		var fid := GameManager.get_player_frame_id(pd)
		var av_ctrl := CafeSocialTheme.make_avatar_badge(av_id, fid, 66.0)
		rh.add_child(av_ctrl)

		_multi_podium_box.add_child(row_card)


func show_result(winner_player_index: int, p1_score: int, p2_score: int, is_friendly: bool = true, xp_earned: int = 0, coin_earned: int = 0, score_earned: int = 0) -> void:
	if visible and is_instance_valid(panel) and panel.visible:
		return
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp_w: float = get_viewport_rect().size.x if get_viewport() != null else 720.0
	if panel and is_instance_valid(panel):
		CafeSocialTheme.constrain_modal_card(panel, self, 660.0, 20.0)
		panel.custom_minimum_size.y = 0.0
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(confetti_shower):
		confetti_shower.position.x = vp_w * 0.5
		confetti_shower.emission_rect_extents.x = vp_w * 0.52
	if is_instance_valid(defeat_particles):
		defeat_particles.position.x = vp_w * 0.5
		defeat_particles.emission_rect_extents.x = vp_w * 0.52
	if btn_return and is_instance_valid(btn_return):
		btn_return.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_return.disabled = false

	var resolved_winner = winner_player_index
	if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and GameManager.get_player_not_played_turns(1) < 2 and GameManager.get_player_not_played_turns(2) < 2:
		if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE]:
			if p1_score > p2_score:
				resolved_winner = 1
			elif p2_score > p1_score:
				resolved_winner = 2
		elif GameManager.current_game_type == GameTypes.QUIZ and GameManager.match_players.size() <= 2:
			if p1_score > p2_score:
				resolved_winner = 1
			elif p2_score > p1_score:
				resolved_winner = 2
			else:
				resolved_winner = 0
	winner_player_index = resolved_winner
	_current_winner_index = winner_player_index
	_current_is_friendly = is_friendly
	_current_xp_earned = xp_earned
	_current_coin_earned = coin_earned
	_current_score_earned = score_earned

	var my_idx = GameManager.my_player_index
	var is_winner = false
	var is_draw = false
	
	if GameManager.local_player_surrendered:
		is_winner = false
		is_draw = false
	elif GameManager.opponent_player_surrendered:
		is_winner = true
		is_draw = false
	else:
		is_winner = (winner_player_index == my_idx) and (winner_player_index != 0)
		is_draw = (winner_player_index == 0)
	
	# Rank Score, EXP & Coin reward chips
	_apply_rewards_ui(xp_earned, coin_earned, score_earned)
	
	# Start rotating background sunburst aura (keep lightweight on mobile)
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(aura_ray, "rotation", TAU, 8.0 if _is_mobile() else 6.0).from(0.0)
	
	if _aura_pulse and _aura_pulse.is_valid():
		_aura_pulse.kill()
	if _is_mobile():
		aura_ray.scale = Vector2.ONE
	else:
		_aura_pulse = create_tween().set_loops()
		_aura_pulse.tween_property(aura_ray, "scale", Vector2(1.12, 1.12), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_aura_pulse.tween_property(aura_ray, "scale", Vector2(0.92, 0.92), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Auto-stop particle emission after celebratory burst so GPU doesn't idle-burn on result screen
	_particle_stop_token += 1
	var burst_token: int = _particle_stop_token
	var burst_dur: float = 2.6 if _is_mobile() else 4.2
	get_tree().create_timer(burst_dur).timeout.connect(func():
		if _particle_stop_token == burst_token:
			if is_instance_valid(confetti_shower):
				confetti_shower.emitting = false
			if is_instance_valid(defeat_particles):
				defeat_particles.emitting = false
			if is_instance_valid(aura_sparkles):
				aura_sparkles.emitting = false
	)
	
	if is_draw:
		plaque.add_theme_stylebox_override("panel", _style_plaque_draw)
		icon_center.texture = _icon_draw
		icon_center.modulate = Color(1.0, 1.0, 1.0, 1.0)
		aura_ray.modulate = Color(0.9, 0.75, 0.45, 0.6)
		star_crown.visible = true
		star_left.modulate = Color(0.85, 0.75, 0.5)
		star_center.modulate = Color(1.0, 0.9, 0.6)
		star_right.modulate = Color(0.85, 0.75, 0.5)
		
		lbl_title.text = "🤝 نتیجه مساوی!"
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		lbl_subtitle.text = "رقابت پایاپای و هیجان‌انگیزی بود، هر دو بازیکن عالی بودید!"
		AudioManager.sfx_draw()
		p1_card.add_theme_stylebox_override("panel", _style_normal)
		p2_card.add_theme_stylebox_override("panel", _style_normal)
		p1_winner_tag.text = "مساوی"
		p2_winner_tag.text = "مساوی"
		
		confetti_shower.emitting = false
		defeat_particles.emitting = false
		aura_sparkles.restart()
		aura_sparkles.emitting = true
		ActionVFXManager.shake_camera(0.2, 0.3)
	elif is_winner:
		plaque.add_theme_stylebox_override("panel", _style_plaque_win)
		icon_center.texture = _icon_win
		icon_center.modulate = Color(1.0, 1.0, 1.0, 1.0)
		aura_ray.modulate = Color(1.0, 0.85, 0.25, 0.95)
		star_crown.visible = true
		star_left.modulate = Color(1.0, 0.88, 0.3)
		star_center.modulate = Color(1.0, 0.98, 0.55)
		star_right.modulate = Color(1.0, 0.88, 0.3)
		
		if GameManager.opponent_player_surrendered:
			lbl_title.text = "🏆 حریف تسلیم شد!"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
			lbl_subtitle.text = "حریف از ادامه مسابقه انصراف داد و شما برنده مسابقه شدید."
		else:
			lbl_title.text = "🏆 پیروزی درخشان!"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
			lbl_subtitle.text = "تبریک! با بازی هوشمندانه و دقیق برنده این مسابقه شدی."
		AudioManager.sfx_win()
		
		# Celebratory VFX: Confetti shower & sparkles
		defeat_particles.emitting = false
		confetti_shower.restart()
		confetti_shower.emitting = true
		aura_sparkles.restart()
		aura_sparkles.emitting = true
		ActionVFXManager.shake_camera(0.42, 0.45)
		ActionVFXManager.spawn_ui_click_burst(panel.global_position + panel.size / 2.0, Color(1.0, 0.88, 0.25))
	else:
		plaque.add_theme_stylebox_override("panel", _style_plaque_lose)
		icon_center.texture = _icon_lose
		icon_center.modulate = Color(0.96, 0.94, 0.90, 1.0) # Crisp bone white / light ivory
		aura_ray.modulate = Color(0.35, 0.50, 0.75, 0.5)
		star_crown.visible = false
		
		if GameManager.local_player_surrendered:
			lbl_title.text = "🏳️ شما تسلیم شدید!"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			lbl_subtitle.text = "شما از ادامه مسابقه انصراف دادید و بازی را به حریف واگذار کردید."
		elif GameManager.match_players.size() > 2 and GameManager.ludo_rank2 == my_idx and my_idx > 0:
			lbl_title.text = "🥈 کسب مقام دوم!"
			lbl_title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
			lbl_subtitle.text = "آفرین! در این رقابت چندنفره به مقام دوم دست پیدا کردید."
		else:
			lbl_title.text = "👏 خسته نباشید!"
			lbl_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			lbl_subtitle.text = "اشکالی نداره، در دست‌های بعدی جبران می‌کنی!"
		AudioManager.sfx_lose()
		
		# Defeat VFX: Dark drifting embers/smoke, no happy confetti
		confetti_shower.emitting = false
		aura_sparkles.emitting = false
		defeat_particles.restart()
		defeat_particles.emitting = true
		ActionVFXManager.shake_camera(0.2, 0.25)
		
	# Setup player cards (full 3-4 player ranked podium for multiplayer, clean 2-player matchup otherwise)
	var is_multi_standings := (GameManager.match_players.size() > 2) and not is_draw
	if is_multi_standings:
		_build_multiplayer_podium(winner_player_index, my_idx)
	else:
		if is_instance_valid(_multi_podium_box):
			_multi_podium_box.visible = false
		if is_instance_valid(p1_card) and is_instance_valid(p1_card.get_parent()):
			(p1_card.get_parent() as Control).visible = true
		var p1_data: Dictionary = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()
		var p2_data: Dictionary = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()
		var p1_suffix := _get_side_suffix(GameManager.current_game_type, 1)
		var p2_suffix := _get_side_suffix(GameManager.current_game_type, 2)
		lbl_p1_name.text = str(p1_data.get("name", p1_data.get("username", "بازیکن ۱"))) + p1_suffix
		lbl_p2_name.text = str(p2_data.get("name", p2_data.get("username", "بازیکن ۲"))) + p2_suffix
		lbl_p1_name.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86) if p1_suffix.is_empty() else Color(1.0, 0.56, 0.56))
		lbl_p2_name.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96) if p2_suffix.is_empty() else Color(0.52, 0.84, 1.0))
		update_scores(p1_score, p2_score)
		if not is_draw:
			var winning_idx = 0
			if GameManager.local_player_surrendered:
				winning_idx = 2 if my_idx == 1 else 1
			elif GameManager.opponent_player_surrendered:
				winning_idx = my_idx
			else:
				winning_idx = winner_player_index
			if winning_idx == 1:
				p1_card.add_theme_stylebox_override("panel", _style_winner)
				p2_card.add_theme_stylebox_override("panel", _style_normal)
				p1_winner_tag.text = "👑 برنده مسابقه"
				p1_winner_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
				p2_winner_tag.text = "بازیکن ۲"
				p2_winner_tag.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
			elif winning_idx == 2:
				p1_card.add_theme_stylebox_override("panel", _style_normal)
				p2_card.add_theme_stylebox_override("panel", _style_winner)
				p1_winner_tag.text = "بازیکن ۱"
				p1_winner_tag.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
				p2_winner_tag.text = "👑 برنده مسابقه"
				p2_winner_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		
		var av1_id = p1_data.get("image", p1_data.get("user_image", 0))
		var av2_id = p2_data.get("image", p2_data.get("user_image", 0))
		var f1_id = GameManager.get_player_frame_id(p1_data)
		var f2_id = GameManager.get_player_frame_id(p2_data)
		
		var av1_path = "res://assets/icons/Avatars/%d.png" % av1_id
		if ResourceLoader.exists(av1_path):
			img_p1_avatar.texture = load(av1_path)
		_apply_avatar_frame_safe(img_p1_avatar, f1_id, 72.0)
			
		var av2_path = "res://assets/icons/Avatars/%d.png" % av2_id
		if ResourceLoader.exists(av2_path):
			img_p2_avatar.texture = load(av2_path)
		_apply_avatar_frame_safe(img_p2_avatar, f2_id, 72.0)
		
	# Panel Entrance animation with spring overshoot and VFX sparkle burst
	panel.scale = Vector2(0.65, 0.65)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	
	# Emblem elastic punch animation
	emblem_box.scale = Vector2.ZERO
	emblem_box.pivot_offset = emblem_box.size / 2.0
	var tw_emb = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_emb.tween_property(emblem_box, "scale", Vector2.ONE, 0.55)
	
	# Magical star burst VFX
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(panel):
			ActionVFXManager.spawn_dialog_sparkle_burst(panel.global_position + panel.size / 2.0)
	)

func update_xp(xp: int, coins: int = 0, score_delta: int = 0) -> void:
	if xp > 0:
		_current_xp_earned = xp
	if coins > 0:
		_current_coin_earned = coins
	if score_delta != 0:
		_current_score_earned = score_delta
	_apply_rewards_ui(_current_xp_earned, _current_coin_earned, _current_score_earned)

func close() -> void:
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
		_aura_tween = null
	if _aura_pulse and _aura_pulse.is_valid():
		_aura_pulse.kill()
		_aura_pulse = null
	confetti_shower.emitting = false
	defeat_particles.emitting = false
	aura_sparkles.emitting = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel and is_instance_valid(panel):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(panel, self)

func close_immediate() -> void:
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
		_aura_tween = null
	if _aura_pulse and _aura_pulse.is_valid():
		_aura_pulse.kill()
		_aura_pulse = null
	if confetti_shower:
		confetti_shower.emitting = false
	if defeat_particles:
		defeat_particles.emitting = false
	if aura_sparkles:
		aura_sparkles.emitting = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel and is_instance_valid(panel):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false

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

func update_scores(p1_score: int, p2_score: int) -> void:
	var show_round_scores = GameRegistry.has_round_score(GameManager.current_game_type) and ((GameManager.current_game_type == GameTypes.QUIZ) or (GameManager.max_rounds > 1) or (p1_score > 0 or p2_score > 0))
	var prefix = "مجموع امتیاز: %s" if GameRegistry.is_cumulative_score(GameManager.current_game_type) else "امتیاز دست‌ها: %s"
	if is_instance_valid(lbl_p1_score):
		lbl_p1_score.visible = show_round_scores
		if show_round_scores:
			lbl_p1_score.text = prefix % _fa_digits(p1_score)
	if is_instance_valid(lbl_p2_score):
		lbl_p2_score.visible = show_round_scores
		if show_round_scores:
			lbl_p2_score.text = prefix % _fa_digits(p2_score)
	if visible and is_instance_valid(panel) and panel.visible:
		if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and GameManager.get_player_not_played_turns(1) < 2 and GameManager.get_player_not_played_turns(2) < 2:
			if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE] or (GameManager.current_game_type == GameTypes.QUIZ and GameManager.match_players.size() <= 2):
				var score_winner = _current_winner_index
				if p1_score > p2_score:
					score_winner = 1
				elif p2_score > p1_score:
					score_winner = 2
				elif GameManager.current_game_type == GameTypes.QUIZ:
					score_winner = 0
				if score_winner != _current_winner_index and (score_winner > 0 or GameManager.current_game_type == GameTypes.QUIZ):
					# Update winner state in-place without recursively re-triggering SFX/tween or dropping coins/score!
					_current_winner_index = score_winner
					var my_i: int = GameManager.my_player_index
					var won_now: bool = (int(score_winner) == my_i) and (int(score_winner) != 0)
					var draw_now: bool = (int(score_winner) == 0)
					if draw_now:
						lbl_title.text = "🤝 نتیجه مساوی!"
						lbl_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
						p1_card.add_theme_stylebox_override("panel", _style_normal)
						p2_card.add_theme_stylebox_override("panel", _style_normal)
						p1_winner_tag.text = "مساوی"
						p2_winner_tag.text = "مساوی"
					elif won_now:
						lbl_title.text = "🏆 پیروزی درخشان!"
						lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
						p1_card.add_theme_stylebox_override("panel", _style_winner if score_winner == 1 else _style_normal)
						p2_card.add_theme_stylebox_override("panel", _style_winner if score_winner == 2 else _style_normal)
						p1_winner_tag.text = "👑 برنده مسابقه" if score_winner == 1 else "بازیکن ۱"
						p2_winner_tag.text = "👑 برنده مسابقه" if score_winner == 2 else "بازیکن ۲"
					else:
						lbl_title.text = "👏 خسته نباشید!"
						lbl_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
						p1_card.add_theme_stylebox_override("panel", _style_winner if score_winner == 1 else _style_normal)
						p2_card.add_theme_stylebox_override("panel", _style_winner if score_winner == 2 else _style_normal)
						p1_winner_tag.text = "👑 برنده مسابقه" if score_winner == 1 else "بازیکن ۱"
						p2_winner_tag.text = "👑 برنده مسابقه" if score_winner == 2 else "بازیکن ۲"

