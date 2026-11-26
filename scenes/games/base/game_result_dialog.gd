extends Control

# Game Result Dialog
# High-polish Warm Classic Parlor result modal for Cafe Fekr.
# Features outcome-tinted walnut-gold framing, rotating sunburst aura, metallic crest plaque,
# crisp player matchup / 4-player podium standings, responsive reward chips, and entrance juice.

signal return_to_menu_requested()
signal rematch_requested()

# Modal Nodes
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var confetti_shower: CPUParticles2D = $ConfettiShower
@onready var defeat_particles: CPUParticles2D = $DefeatParticles

# Emblem & Header Nodes
@onready var lbl_mode_tag: Label = $CenterContainer/Panel/VBox/LblModeTag
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
@onready var rewards_hbox: HFlowContainer = $CenterContainer/Panel/VBox/RewardsHBox
@onready var coin_chip: PanelContainer = $CenterContainer/Panel/VBox/RewardsHBox/CoinChip
@onready var lbl_coin: Label = $CenterContainer/Panel/VBox/RewardsHBox/CoinChip/LblCoin
@onready var lbl_xp: Label = $CenterContainer/Panel/VBox/RewardsHBox/XPChip/LblXP

# Buttons
@onready var btn_return: Button = $CenterContainer/Panel/VBox/ButtonsRow/BtnReturn

# Icons & Fonts
var _icon_win: Texture2D = preload("res://assets/icons/General/cup.png")
var _icon_lose: Texture2D = preload("res://assets/icons/General/lose_white.png")
var _icon_draw: Texture2D = preload("res://assets/icons/General/draw.png")
const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")
const PostMatchSocialPanelScript = preload("res://scenes/games/base/post_match_social_panel.gd")

var _style_panel_win: StyleBox
var _style_panel_lose: StyleBox
var _style_panel_draw: StyleBox
var _style_winner: StyleBoxFlat
var _style_normal: StyleBoxFlat
var _style_plaque_win: StyleBoxFlat
var _style_plaque_lose: StyleBoxFlat
var _style_plaque_draw: StyleBoxFlat

var _aura_tween: Tween = null
var _aura_pulse: Tween = null
var _particle_stop_token: int = 0

var _current_winner_index: int = -1
var _current_is_friendly: bool = true
var _current_xp_earned: int = 0
var _current_coin_earned: int = 0
var _current_score_earned: int = 0
var _score_chip: PanelContainer = null
var _lbl_score_delta: Label = null
var _multi_podium_box: VBoxContainer = null
var _hero_outcome_box: PanelContainer = null
var _hero_score_lbl: Label = null
var _self_result_box: PanelContainer = null
var _post_match_panel: VBoxContainer = null


func _is_mobile() -> bool:
	return GameManager.is_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel and is_instance_valid(panel):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_chip.visible = false
	_setup_styles()
	if _is_mobile():
		if is_instance_valid(confetti_shower):
			confetti_shower.amount = maxi(14, int(confetti_shower.amount * 0.55))
		if is_instance_valid(defeat_particles):
			defeat_particles.amount = maxi(10, int(defeat_particles.amount * 0.55))
		if is_instance_valid(aura_sparkles):
			aura_sparkles.amount = maxi(8, int(aura_sparkles.amount * 0.55))

	KenneyUI.style_button(btn_return, KenneyUI.COLOR_GREEN)

	btn_return.pressed.connect(func():
		AudioManager.sfx_button()
		if is_instance_valid(_post_match_panel):
			_post_match_panel.notify_leave_if_active()
		close()
		return_to_menu_requested.emit()
	)


func _make_modal_panel_style(modulate_col: Color = Color.WHITE, compact: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = preload("res://assets/images/frames/dialog.png")
	sb.texture_margin_left = 44.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_bottom = 80.0
	sb.content_margin_left = 42.0 if compact else 48.0
	sb.content_margin_top = 90.0 if compact else 104.0
	sb.content_margin_right = 42.0 if compact else 48.0
	sb.content_margin_bottom = 86.0 if compact else 100.0
	sb.modulate_color = modulate_col
	return sb


func _load_avatar_tex(avatar_id: int) -> Texture2D:
	var path: String = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(path):
		return load(path)
	var fallback: String = "res://assets/icons/Avatars/0.png"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null


func _format_mode_tag(is_friendly: bool) -> String:
	var gname: String = GameRegistry.get_display_name_fa(GameManager.current_game_type)
	if gname.is_empty():
		gname = str(GameManager.current_game_type)
	var mode_str: String = "تماشای زنده" if GameManager.is_spectating else ("بازی با ربات" if GameManager.is_bot_match() else ("رقابت دوستانه" if is_friendly else "رقابت رنک"))
	return "🎮 %s  •  %s" % [gname, mode_str]


func _get_player_display_name(pid: int) -> String:
	var pd: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
	var nm: String = str(pd.get("name", pd.get("username", ""))).strip_edges()
	if nm.is_empty():
		return "بازیکن %s" % _fa_digits(pid)
	return nm


func _populate_2p_matchup(winner_player_index: int, p1_score: int, p2_score: int, is_draw: bool, my_idx: int) -> void:
	var matchup_box: Control = p1_card.get_parent() as Control
	if not is_instance_valid(matchup_box):
		return
	matchup_box.visible = true

	var cards: Array[PanelContainer] = [p1_card, p2_card]
	var name_lbls: Array[Label] = [lbl_p1_name, lbl_p2_name]
	var score_lbls: Array[Label] = [lbl_p1_score, lbl_p2_score]
	var tag_lbls: Array[Label] = [p1_winner_tag, p2_winner_tag]
	var avatars: Array[TextureRect] = [img_p1_avatar, img_p2_avatar]
	var scores: Array[int] = [p1_score, p2_score]

	var show_round_scores: bool = GameRegistry.has_round_score(GameManager.current_game_type) and ((GameManager.current_game_type == GameTypes.QUIZ) or (GameManager.max_rounds > 1) or (p1_score > 0 or p2_score > 0))
	var score_prefix: String = "امتیاز: %s" if GameRegistry.is_cumulative_score(GameManager.current_game_type) else "دست‌ها: %s"

	for i in range(2):
		var pid: int = i + 1
		var card: PanelContainer = cards[i]
		if is_instance_valid(card):
			card.custom_minimum_size.y = 122.0
		var pd: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
		var base_name: String = _get_player_display_name(pid)
		var suffix: String = _get_side_suffix(GameManager.current_game_type, pid)
		var is_me: bool = (not GameManager.is_spectating) and (pid == my_idx)
		if is_instance_valid(name_lbls[i]):
			name_lbls[i].text = "%s%s%s" % [base_name, suffix, " (شما)" if is_me else ""]
			name_lbls[i].add_theme_font_size_override("font_size", 17)

		var av_id: int = int(pd.get("image", pd.get("user_image", 0)))
		var fid: int = GameManager.get_player_frame_id(pd)
		if is_instance_valid(avatars[i]):
			avatars[i].texture = _load_avatar_tex(av_id)
			_apply_avatar_frame_safe(avatars[i], fid, 54.0)

		if is_instance_valid(score_lbls[i]):
			score_lbls[i].visible = show_round_scores
			if show_round_scores:
				score_lbls[i].text = score_prefix % _fa_digits(scores[i])

		var is_p_winner: bool = (not is_draw) and (winner_player_index == pid)
		if is_draw:
			if is_instance_valid(card):
				card.add_theme_stylebox_override("panel", _style_normal)
			_style_tag_pill(tag_lbls[i], "🤝 مساوی", Color(1.0, 0.90, 0.55), Color(0.24, 0.18, 0.08, 0.92), Color(0.80, 0.65, 0.32, 0.72))
		elif is_p_winner:
			if is_instance_valid(card):
				card.add_theme_stylebox_override("panel", _style_winner)
			_style_tag_pill(tag_lbls[i], "🏆 برنده", Color(1.0, 0.92, 0.38), Color(0.30, 0.21, 0.05, 0.95), Color(1.0, 0.82, 0.28, 0.90))
		else:
			if is_instance_valid(card):
				card.add_theme_stylebox_override("panel", _style_normal)
			var did_surrender: bool = (is_me and GameManager.local_player_surrendered) or ((not is_me) and GameManager.opponent_player_surrendered)
			var lose_txt: String = "🏳️ انصراف" if did_surrender else "نفر دوم"
			_style_tag_pill(tag_lbls[i], lose_txt, Color(0.76, 0.80, 0.88), Color(0.14, 0.16, 0.22, 0.88), Color(0.42, 0.48, 0.62, 0.55))


func _setup_styles() -> void:
	var mobile_mode: bool = _is_mobile()

	_style_panel_win = _make_modal_panel_style(Color.WHITE)
	_style_panel_lose = _make_modal_panel_style(Color(0.88, 0.90, 0.96))
	_style_panel_draw = _make_modal_panel_style(Color(0.92, 0.92, 0.92))

	# Winner Card Style
	_style_winner = StyleBoxFlat.new()
	_style_winner.bg_color = Color(0.20, 0.135, 0.070, 0.96)
	_style_winner.border_color = Color(0.98, 0.82, 0.30, 0.96)
	_style_winner.border_width_left = 2
	_style_winner.border_width_top = 3
	_style_winner.border_width_right = 2
	_style_winner.border_width_bottom = 2
	_style_winner.set_corner_radius_all(16)
	_style_winner.shadow_color = Color(1.0, 0.8, 0.2, 0.28)
	_style_winner.shadow_size = 0 if mobile_mode else 8
	_style_winner.content_margin_left = 12
	_style_winner.content_margin_right = 12
	_style_winner.content_margin_top = 18
	_style_winner.content_margin_bottom = 18

	# Normal Card Style
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.145, 0.095, 0.06, 0.92)
	_style_normal.border_color = Color(0.45, 0.33, 0.20, 0.72)
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 2
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 2
	_style_normal.set_corner_radius_all(16)
	_style_normal.content_margin_left = 12
	_style_normal.content_margin_right = 12
	_style_normal.content_margin_top = 18
	_style_normal.content_margin_bottom = 18

	# Plaque Styles for Win, Lose, Draw
	_style_plaque_win = StyleBoxFlat.new()
	_style_plaque_win.bg_color = Color(0.20, 0.12, 0.04, 0.98)
	_style_plaque_win.border_color = Color(1.0, 0.86, 0.32, 1.0)
	_style_plaque_win.set_border_width_all(3)
	_style_plaque_win.set_corner_radius_all(46)
	_style_plaque_win.shadow_color = Color(1.0, 0.82, 0.22, 0.45)
	_style_plaque_win.shadow_size = 0 if mobile_mode else 14

	_style_plaque_lose = StyleBoxFlat.new()
	_style_plaque_lose.bg_color = Color(0.12, 0.14, 0.21, 0.98)
	_style_plaque_lose.border_color = Color(0.68, 0.80, 0.96, 0.95)
	_style_plaque_lose.set_border_width_all(3)
	_style_plaque_lose.set_corner_radius_all(46)
	_style_plaque_lose.shadow_color = Color(0.35, 0.55, 0.9, 0.38)
	_style_plaque_lose.shadow_size = 0 if mobile_mode else 12

	_style_plaque_draw = StyleBoxFlat.new()
	_style_plaque_draw.bg_color = Color(0.16, 0.12, 0.075, 0.98)
	_style_plaque_draw.border_color = Color(0.86, 0.72, 0.42, 0.98)
	_style_plaque_draw.set_border_width_all(3)
	_style_plaque_draw.set_corner_radius_all(46)
	_style_plaque_draw.shadow_color = Color(0.65, 0.5, 0.2, 0.32)
	_style_plaque_draw.shadow_size = 0 if mobile_mode else 10


func _style_tag_pill(lbl: Label, txt: String, fg: Color, bg: Color, border_col: Color) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.text = txt
	lbl.add_theme_color_override("font_color", fg)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	sb.bg_color = bg
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	lbl.add_theme_stylebox_override("normal", sb)


func _ensure_score_chip() -> void:
	if is_instance_valid(_score_chip) or not is_instance_valid(rewards_hbox):
		return
	_score_chip = PanelContainer.new()
	_score_chip.name = "ScoreChip"
	_score_chip.visible = false
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.bg_color = Color(0.10, 0.24, 0.14, 0.94)
	sb.border_color = Color(0.35, 0.92, 0.52, 0.90)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	_score_chip.add_theme_stylebox_override("panel", sb)

	_lbl_score_delta = Label.new()
	_lbl_score_delta.add_theme_font_override("font", FONT_HEKAYAT)
	_lbl_score_delta.add_theme_font_size_override("font_size", 19)
	_lbl_score_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_chip.add_child(_lbl_score_delta)
	rewards_hbox.add_child(_score_chip)
	rewards_hbox.move_child(_score_chip, 0)


func _apply_avatar_frame_safe(avatar_rect: TextureRect, frame_id: int, slot_sz: float = 70.0) -> void:
	if not is_instance_valid(avatar_rect):
		return
	var p: Node = avatar_rect.get_parent()
	var slot: Control = null
	if p is Control and p.name.ends_with("_AvatarSlot"):
		slot = p as Control
	elif p is Container:
		var idx: int = avatar_rect.get_index()
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
	var has_reward: bool = false
	if score_earned != 0 and is_instance_valid(_score_chip) and is_instance_valid(_lbl_score_delta):
		_score_chip.visible = true
		var is_pos: bool = score_earned > 0
		var sb: StyleBoxFlat = _score_chip.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.bg_color = Color(0.10, 0.25, 0.14, 0.95) if is_pos else Color(0.28, 0.08, 0.08, 0.95)
			sb.border_color = Color(0.35, 0.92, 0.52, 0.92) if is_pos else Color(0.95, 0.36, 0.36, 0.92)
		var sign_s: String = "+" if is_pos else "-"
		_lbl_score_delta.text = "%s%s امتیاز رنک" % [sign_s, _fa_digits(abs(score_earned))]
		_lbl_score_delta.add_theme_color_override("font_color", Color(0.45, 0.98, 0.62) if is_pos else Color(1.0, 0.54, 0.54))
		has_reward = true
	elif is_instance_valid(_score_chip):
		_score_chip.visible = false

	if xp_earned > 0:
		if is_instance_valid(lbl_xp) and is_instance_valid(lbl_xp.get_parent()):
			lbl_xp.get_parent().visible = true
			lbl_xp.text = "+%s تجربه" % _fa_digits(xp_earned)
		has_reward = true
	else:
		if is_instance_valid(lbl_xp) and is_instance_valid(lbl_xp.get_parent()):
			lbl_xp.get_parent().visible = false

	if coin_earned > 0:
		if is_instance_valid(coin_chip):
			coin_chip.visible = true
		if is_instance_valid(lbl_coin):
			lbl_coin.text = "+%s سکه" % _fa_digits(coin_earned)
		has_reward = true
	else:
		if is_instance_valid(coin_chip):
			coin_chip.visible = false

	rewards_hbox.visible = has_reward
	if has_reward:
		_animate_rewards_countup(xp_earned, coin_earned, score_earned)


func _animate_rewards_countup(xp_earned: int, coin_earned: int, score_earned: int) -> void:
	var dur: float = 0.52
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var has_any: bool = false
	if coin_earned > 0 and is_instance_valid(lbl_coin):
		has_any = true
		tw.tween_method(func(v: int):
			if is_instance_valid(lbl_coin):
				lbl_coin.text = "+%s سکه" % _fa_digits(v)
		, 0, coin_earned, dur)
	if xp_earned > 0 and is_instance_valid(lbl_xp):
		has_any = true
		if tw.is_running() or coin_earned > 0:
			tw.parallel().tween_method(func(v: int):
				if is_instance_valid(lbl_xp):
					lbl_xp.text = "+%s تجربه" % _fa_digits(v)
			, 0, xp_earned, dur)
		else:
			tw.tween_method(func(v: int):
				if is_instance_valid(lbl_xp):
					lbl_xp.text = "+%s تجربه" % _fa_digits(v)
			, 0, xp_earned, dur)
	if score_earned != 0 and is_instance_valid(_lbl_score_delta):
		has_any = true
		var sign_s: String = "+" if score_earned > 0 else "-"
		var target_abs: int = abs(score_earned)
		tw.parallel().tween_method(func(v: int):
			if is_instance_valid(_lbl_score_delta):
				_lbl_score_delta.text = "%s%s امتیاز رنک" % [sign_s, _fa_digits(v)]
		, 0, target_abs, dur)
	if not has_any:
		tw.kill()


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
	if is_instance_valid(_hero_outcome_box):
		_hero_outcome_box.visible = false
	if is_instance_valid(_self_result_box):
		_self_result_box.visible = false
	matchup_box.visible = false

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

	var medals: Array[String] = ["🥇 رتبه اول", "🥈 رتبه دوم", "🥉 رتبه سوم", "🎖️ رتبه چهارم"]
	var accent_cols: Array[Color] = [
		Color(1.0, 0.86, 0.30),
		Color(0.82, 0.88, 0.96),
		Color(0.90, 0.64, 0.36),
		Color(0.74, 0.66, 0.56)
	]

	for rank_i in range(ordered_ids.size()):
		var pid: int = ordered_ids[rank_i]
		var pd: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
		var pname: String = str(pd.get("name", pd.get("username", "بازیکن %s" % _fa_digits(pid))))
		var is_me: bool = (pid == my_idx)
		var ac: Color = accent_cols[mini(rank_i, accent_cols.size() - 1)]

		var row_card: PanelContainer = PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rsb: StyleBoxFlat = StyleBoxFlat.new()
		rsb.bg_color = Color(0.21, 0.145, 0.068, 0.96) if rank_i == 0 else (Color(0.11, 0.21, 0.14, 0.94) if is_me else Color(0.14, 0.095, 0.06, 0.90))
		rsb.border_color = ac if rank_i == 0 else (Color(0.36, 0.88, 0.54, 0.90) if is_me else Color(0.45, 0.34, 0.20, 0.65))
		rsb.set_border_width_all(2 if (rank_i == 0 or is_me) else 1)
		rsb.set_corner_radius_all(14)
		rsb.content_margin_left = 12.0
		rsb.content_margin_right = 12.0
		rsb.content_margin_top = 14.0
		rsb.content_margin_bottom = 14.0
		row_card.add_theme_stylebox_override("panel", rsb)

		var rh: HBoxContainer = HBoxContainer.new()
		rh.alignment = BoxContainer.ALIGNMENT_CENTER
		rh.add_theme_constant_override("separation", 10)
		row_card.add_child(rh)

		var badge_lbl: Label = Label.new()
		badge_lbl.custom_minimum_size = Vector2(88, 0)
		badge_lbl.add_theme_font_override("font", FONT_VAZIR)
		badge_lbl.add_theme_font_size_override("font_size", 13)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_tag_pill(
			badge_lbl,
			medals[mini(rank_i, medals.size() - 1)],
			ac,
			Color(ac.r * 0.22, ac.g * 0.22, ac.b * 0.22, 0.92),
			Color(ac.r, ac.g, ac.b, 0.72)
		)
		rh.add_child(badge_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = "%s (شما)" % pname if is_me else pname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.add_theme_font_override("font", FONT_HEKAYAT)
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.68) if is_me else Color(0.984, 0.953, 0.894))
		rh.add_child(name_lbl)

		var av_id: int = int(pd.get("image", pd.get("user_image", 0)))
		var fid: int = GameManager.get_player_frame_id(pd)
		var av_ctrl: Control = CafeSocialTheme.make_avatar_badge(av_id, fid, 54.0)
		rh.add_child(av_ctrl)

		_multi_podium_box.add_child(row_card)


func _build_multiplayer_self_result(my_idx: int, winner_player_index: int) -> void:
	var matchup_box: Control = p1_card.get_parent() as Control
	var root_vbox: VBoxContainer = matchup_box.get_parent() as VBoxContainer
	if is_instance_valid(_multi_podium_box):
		_multi_podium_box.visible = false
	if is_instance_valid(_hero_outcome_box):
		_hero_outcome_box.visible = false
	matchup_box.visible = false

	if not is_instance_valid(_self_result_box):
		_self_result_box = PanelContainer.new()
		_self_result_box.name = "SelfResultBox"
		_self_result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(_self_result_box)
		root_vbox.move_child(_self_result_box, matchup_box.get_index() + 1)

	for ch in _self_result_box.get_children():
		ch.queue_free()
	_self_result_box.visible = true

	var ssb: StyleBoxFlat = StyleBoxFlat.new()
	ssb.bg_color = Color(0.14, 0.095, 0.06, 0.94)
	ssb.border_color = Color(0.88, 0.72, 0.35, 0.85)
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(16)
	ssb.content_margin_left = 16.0
	ssb.content_margin_right = 16.0
	ssb.content_margin_top = 20.0
	ssb.content_margin_bottom = 20.0
	_self_result_box.add_theme_stylebox_override("panel", ssb)

	var sv: VBoxContainer = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	_self_result_box.add_child(sv)

	var my_pd: Dictionary = GameManager.get_my_player_data()
	var my_name: String = str(my_pd.get("name", my_pd.get("username", "شما")))
	var my_av_id: int = int(my_pd.get("image", my_pd.get("user_image", 0)))
	var my_fid: int = GameManager.get_player_frame_id(my_pd)

	var row_h: HBoxContainer = HBoxContainer.new()
	row_h.alignment = BoxContainer.ALIGNMENT_CENTER
	row_h.add_theme_constant_override("separation", 12)
	sv.add_child(row_h)

	var status_tag: Label = Label.new()
	status_tag.custom_minimum_size = Vector2(96, 0)
	status_tag.add_theme_font_override("font", FONT_VAZIR)
	status_tag.add_theme_font_size_override("font_size", 13)
	status_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if GameManager.local_player_surrendered:
		_style_tag_pill(status_tag, "انصراف از بازی", Color(1.0, 0.65, 0.65), Color(0.28, 0.10, 0.10, 0.90), Color(0.85, 0.35, 0.35, 0.75))
	elif GameManager.ludo_rank1 == my_idx and my_idx > 0:
		_style_tag_pill(status_tag, "🥇 مقام اول", Color(1.0, 0.88, 0.30), Color(0.28, 0.20, 0.06, 0.92), Color(0.95, 0.80, 0.28, 0.85))
	elif GameManager.ludo_rank2 == my_idx and my_idx > 0:
		_style_tag_pill(status_tag, "🥈 مقام دوم", Color(0.85, 0.92, 1.0), Color(0.14, 0.20, 0.28, 0.92), Color(0.55, 0.75, 0.95, 0.85))
	else:
		_style_tag_pill(status_tag, "نتیجه شما", Color(0.92, 0.88, 0.75), Color(0.20, 0.15, 0.08, 0.90), Color(0.65, 0.50, 0.25, 0.75))
	row_h.add_child(status_tag)

	var name_lbl: Label = Label.new()
	name_lbl.text = "%s (شما)" % my_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.68))
	row_h.add_child(name_lbl)

	var av_ctrl: Control = CafeSocialTheme.make_avatar_badge(my_av_id, my_fid, 56.0)
	row_h.add_child(av_ctrl)

	var notice_panel: PanelContainer = PanelContainer.new()
	notice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nsb: StyleBoxFlat = StyleBoxFlat.new()
	nsb.bg_color = Color(0.10, 0.14, 0.20, 0.92)
	nsb.border_color = Color(0.35, 0.52, 0.78, 0.65)
	nsb.set_border_width_all(1)
	nsb.set_corner_radius_all(10)
	nsb.content_margin_left = 12.0
	nsb.content_margin_right = 12.0
	nsb.content_margin_top = 8.0
	nsb.content_margin_bottom = 8.0
	notice_panel.add_theme_stylebox_override("panel", nsb)

	var notice_lbl: Label = Label.new()
	notice_lbl.text = "⏳ رقابت سایر بازیکنان روی میز مسابقه همچنان ادامه دارد...\nامتیاز و دستاوردهای شما با موفقیت ثبت شد."
	notice_lbl.add_theme_font_override("font", FONT_VAZIR)
	notice_lbl.add_theme_font_size_override("font_size", 13)
	notice_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_panel.add_child(notice_lbl)
	sv.add_child(notice_panel)


func _build_2p_hero_outcome(is_winner: bool, is_draw: bool, p1_score: int, p2_score: int, my_idx: int) -> void:
	var matchup_box: Control = p1_card.get_parent() as Control
	var root_vbox: VBoxContainer = matchup_box.get_parent() as VBoxContainer
	if is_instance_valid(_multi_podium_box):
		_multi_podium_box.visible = false
	if is_instance_valid(_self_result_box):
		_self_result_box.visible = false
	matchup_box.visible = false

	if not is_instance_valid(_hero_outcome_box):
		_hero_outcome_box = PanelContainer.new()
		_hero_outcome_box.name = "HeroOutcomeBox"
		_hero_outcome_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_vbox.add_child(_hero_outcome_box)
		root_vbox.move_child(_hero_outcome_box, matchup_box.get_index() + 1)

	for ch in _hero_outcome_box.get_children():
		ch.queue_free()
	_hero_outcome_box.visible = true

	var hsb: StyleBoxFlat = StyleBoxFlat.new()
	if is_winner:
		hsb.bg_color = Color(0.18, 0.125, 0.055, 0.96)
		hsb.border_color = Color(1.0, 0.84, 0.32, 0.95)
		hsb.shadow_color = Color(1.0, 0.8, 0.2, 0.25)
	elif is_draw:
		hsb.bg_color = Color(0.15, 0.12, 0.07, 0.96)
		hsb.border_color = Color(0.85, 0.72, 0.42, 0.90)
		hsb.shadow_color = Color(0.65, 0.5, 0.2, 0.20)
	else:
		hsb.bg_color = Color(0.12, 0.13, 0.18, 0.96)
		hsb.border_color = Color(0.55, 0.68, 0.88, 0.85)
		hsb.shadow_color = Color(0.3, 0.45, 0.7, 0.20)
	hsb.set_border_width_all(2)
	hsb.set_corner_radius_all(18)
	hsb.shadow_size = 0 if _is_mobile() else 8
	hsb.content_margin_left = 18.0
	hsb.content_margin_right = 18.0
	hsb.content_margin_top = 16.0
	hsb.content_margin_bottom = 16.0
	_hero_outcome_box.add_theme_stylebox_override("panel", hsb)

	var hv: VBoxContainer = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 8)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_outcome_box.add_child(hv)

	var status_tag: Label = Label.new()
	status_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_tag.add_theme_font_override("font", FONT_HEKAYAT)
	status_tag.add_theme_font_size_override("font_size", 22)
	status_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_winner:
		_style_tag_pill(status_tag, "🏆 پیروزی شما در این بازی", Color(1.0, 0.90, 0.35), Color(0.28, 0.20, 0.05, 0.95), Color(0.96, 0.78, 0.28, 0.85))
	elif is_draw:
		_style_tag_pill(status_tag, "🤝 نتیجه بازی: مساوی", Color(1.0, 0.92, 0.60), Color(0.24, 0.18, 0.08, 0.90), Color(0.80, 0.65, 0.32, 0.75))
	else:
		if GameManager.local_player_surrendered:
			_style_tag_pill(status_tag, "🏳️ انصراف از مسابقه", Color(1.0, 0.65, 0.65), Color(0.28, 0.10, 0.10, 0.90), Color(0.85, 0.35, 0.35, 0.75))
		else:
			_style_tag_pill(status_tag, "🏳️ شکست در این بازی", Color(0.85, 0.90, 1.0), Color(0.14, 0.18, 0.26, 0.90), Color(0.48, 0.65, 0.88, 0.70))
	hv.add_child(status_tag)

	var show_round_scores: bool = GameRegistry.has_round_score(GameManager.current_game_type) and ((GameManager.current_game_type == GameTypes.QUIZ) or (GameManager.max_rounds > 1) or (p1_score > 0 or p2_score > 0))
	if show_round_scores:
		var score_panel: PanelContainer = PanelContainer.new()
		score_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc_sb: StyleBoxFlat = StyleBoxFlat.new()
		sc_sb.bg_color = Color(0.08, 0.05, 0.03, 0.88)
		sc_sb.border_color = Color(0.70, 0.55, 0.25, 0.50)
		sc_sb.set_border_width_all(1)
		sc_sb.set_corner_radius_all(10)
		sc_sb.content_margin_left = 12.0
		sc_sb.content_margin_right = 12.0
		sc_sb.content_margin_top = 5.0
		sc_sb.content_margin_bottom = 5.0
		score_panel.add_theme_stylebox_override("panel", sc_sb)

		var my_s: int = p1_score if my_idx == 1 else p2_score
		var opp_s: int = p2_score if my_idx == 1 else p1_score
		var is_spec: bool = GameManager.is_spectating

		_hero_score_lbl = Label.new()
		_hero_score_lbl.add_theme_font_override("font", FONT_HEKAYAT)
		_hero_score_lbl.add_theme_font_size_override("font_size", 18)
		_hero_score_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
		_hero_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		if is_spec:
			var p1_name: String = _get_player_display_name(1)
			var p2_name: String = _get_player_display_name(2)
			_hero_score_lbl.text = "نتیجه: %s: %s  |  %s: %s" % [p1_name, _fa_digits(p1_score), p2_name, _fa_digits(p2_score)]
		else:
			_hero_score_lbl.text = "امتیاز نهایی: شما %s  —  %s حریف" % [_fa_digits(my_s), _fa_digits(opp_s)]

		score_panel.add_child(_hero_score_lbl)
		hv.add_child(score_panel)
	else:
		_hero_score_lbl = null


func show_result(winner_player_index: int, p1_score: int, p2_score: int, is_friendly: bool = true, xp_earned: int = 0, coin_earned: int = 0, score_earned: int = 0, is_match_finished: bool = true) -> void:
	if visible and is_instance_valid(panel) and panel.visible:
		return
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp_w: float = get_viewport_rect().size.x if get_viewport() != null else 720.0
	if panel and is_instance_valid(panel):
		panel.custom_minimum_size = Vector2(clampf(vp_w - 36.0, 320.0, 600.0), 0.0)
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
		btn_return.text = "بازگشت به منو"
		btn_return.custom_minimum_size.y = 62.0
	var root_vbox_rst: VBoxContainer = get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if is_instance_valid(root_vbox_rst):
		root_vbox_rst.add_theme_constant_override("separation", 18)
	if is_instance_valid(_post_match_panel):
		_post_match_panel.reset_and_hide()

	var resolved_winner: int = winner_player_index
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

	if is_instance_valid(lbl_mode_tag):
		lbl_mode_tag.visible = false
	if is_instance_valid(emblem_box):
		emblem_box.visible = true
		emblem_box.custom_minimum_size = Vector2(124, 102)
	if is_instance_valid(lbl_subtitle):
		lbl_subtitle.visible = true
	if is_instance_valid(lbl_title):
		lbl_title.add_theme_font_size_override("font_size", 30)
		lbl_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.92))
		lbl_title.add_theme_constant_override("outline_size", 4)

	var my_idx: int = GameManager.my_player_index
	var is_winner: bool = false
	var is_draw: bool = false

	if GameManager.local_player_surrendered:
		is_winner = false
		is_draw = false
	elif GameManager.opponent_player_surrendered:
		is_winner = true
		is_draw = false
	else:
		is_winner = (winner_player_index == my_idx) and (winner_player_index != 0)
		is_draw = (winner_player_index == 0)

	_apply_rewards_ui(xp_earned, coin_earned, score_earned)

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
		_aura_pulse.tween_property(aura_ray, "scale", Vector2(1.10, 1.10), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_aura_pulse.tween_property(aura_ray, "scale", Vector2(0.94, 0.94), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_particle_stop_token += 1
	var burst_token: int = _particle_stop_token
	var burst_dur: float = 2.4 if _is_mobile() else 4.0
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
		panel.add_theme_stylebox_override("panel", _style_panel_draw)
		plaque.add_theme_stylebox_override("panel", _style_plaque_draw)
		icon_center.texture = _icon_draw
		icon_center.modulate = Color(1.0, 1.0, 1.0, 1.0)
		aura_ray.modulate = Color(0.9, 0.75, 0.45, 0.55)
		star_crown.visible = true
		star_left.modulate = Color(0.85, 0.75, 0.5)
		star_center.modulate = Color(1.0, 0.9, 0.6)
		star_right.modulate = Color(0.85, 0.75, 0.5)

		lbl_title.text = "نتیجه مساوی!"
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
		lbl_subtitle.text = "رقابت پایاپای و هیجان‌انگیزی بود، هر دو بازیکن عالی بازی کردید."
		KenneyUI.style_button(btn_return, KenneyUI.COLOR_YELLOW)
		AudioManager.sfx_draw()
		p1_card.add_theme_stylebox_override("panel", _style_normal)
		p2_card.add_theme_stylebox_override("panel", _style_normal)
		_style_tag_pill(p1_winner_tag, "مساوی", Color(1.0, 0.90, 0.55), Color(0.24, 0.18, 0.08, 0.9), Color(0.80, 0.65, 0.32, 0.7))
		_style_tag_pill(p2_winner_tag, "مساوی", Color(1.0, 0.90, 0.55), Color(0.24, 0.18, 0.08, 0.9), Color(0.80, 0.65, 0.32, 0.7))

		confetti_shower.emitting = false
		defeat_particles.emitting = false
		aura_sparkles.restart()
		aura_sparkles.emitting = true
		ActionVFXManager.shake_camera(0.18, 0.28)
	elif is_winner:
		panel.add_theme_stylebox_override("panel", _style_panel_win)
		plaque.add_theme_stylebox_override("panel", _style_plaque_win)
		icon_center.texture = _icon_win
		icon_center.modulate = Color(1.0, 1.0, 1.0, 1.0)
		aura_ray.modulate = Color(1.0, 0.85, 0.25, 0.90)
		star_crown.visible = true
		star_left.modulate = Color(1.0, 0.88, 0.3)
		star_center.modulate = Color(1.0, 0.98, 0.55)
		star_right.modulate = Color(1.0, 0.88, 0.3)

		if GameManager.opponent_player_surrendered:
			lbl_title.text = "حریف تسلیم شد!"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
			lbl_subtitle.text = "حریف از ادامه مسابقه انصراف داد و پیروزی به نام شما ثبت شد."
		else:
			lbl_title.text = "پیروزی درخشان!"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
			lbl_subtitle.text = "تبریک! با بازی هوشمندانه و دقیق برنده این مسابقه شدید."
		KenneyUI.style_button(btn_return, KenneyUI.COLOR_GREEN)
		AudioManager.sfx_win()

		defeat_particles.emitting = false
		confetti_shower.restart()
		confetti_shower.emitting = true
		aura_sparkles.restart()
		aura_sparkles.emitting = true
		ActionVFXManager.shake_camera(0.38, 0.42)
		ActionVFXManager.spawn_ui_click_burst(panel.global_position + panel.size / 2.0, Color(1.0, 0.88, 0.25))
	else:
		panel.add_theme_stylebox_override("panel", _style_panel_lose)
		plaque.add_theme_stylebox_override("panel", _style_plaque_lose)
		icon_center.texture = _icon_lose
		icon_center.modulate = Color(0.96, 0.94, 0.90, 1.0)
		aura_ray.modulate = Color(0.38, 0.52, 0.78, 0.45)
		star_crown.visible = false

		if GameManager.local_player_surrendered:
			lbl_title.text = "انصراف از مسابقه"
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.52, 0.52))
			if GameManager.last_early_surrender_no_reward:
				lbl_subtitle.text = "به دلیل تسلیم زودهنگام، پاداشی برای این مسابقه ثبت نشد."
			else:
				lbl_subtitle.text = "شما از ادامه مسابقه انصراف دادید و بازی به حریف واگذار شد."
		elif GameManager.match_players.size() > 2 and GameManager.ludo_rank2 == my_idx and my_idx > 0:
			lbl_title.text = "کسب مقام دوم!"
			lbl_title.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
			lbl_subtitle.text = "آفرین! در این رقابت چندنفره به مقام دوم دست پیدا کردید."
		else:
			lbl_title.text = "خسته نباشید!"
			lbl_title.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
			lbl_subtitle.text = "اشکالی ندارد، در دست‌های بعدی حتماً جبران می‌کنید."
		KenneyUI.style_button(btn_return, KenneyUI.COLOR_BLUE)
		AudioManager.sfx_lose()

		confetti_shower.emitting = false
		aura_sparkles.emitting = false
		defeat_particles.restart()
		defeat_particles.emitting = true
		ActionVFXManager.shake_camera(0.18, 0.22)

	if GameManager.match_players.size() > 2:
		_build_multiplayer_podium(winner_player_index, my_idx)
	else:
		if is_instance_valid(_multi_podium_box):
			_multi_podium_box.visible = false
		if is_instance_valid(_hero_outcome_box):
			_hero_outcome_box.visible = false
		if is_instance_valid(_self_result_box):
			_self_result_box.visible = false
		_populate_2p_matchup(winner_player_index, p1_score, p2_score, is_draw, my_idx)

	panel.scale = Vector2(0.72, 0.72)
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0

	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.30)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.20)

	if is_instance_valid(emblem_box) and emblem_box.visible:
		emblem_box.scale = Vector2.ZERO
		emblem_box.pivot_offset = emblem_box.size / 2.0
		var tw_emb: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_emb.tween_property(emblem_box, "scale", Vector2.ONE, 0.52)

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


func _ensure_post_match_panel() -> VBoxContainer:
	if is_instance_valid(_post_match_panel):
		return _post_match_panel
	var vbox: VBoxContainer = get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if not is_instance_valid(vbox):
		return null
	_post_match_panel = PostMatchSocialPanelScript.new()
	_post_match_panel.name = "PostMatchSocialPanel"
	vbox.add_child(_post_match_panel)
	var btn_row: Node = vbox.get_node_or_null("ButtonsRow")
	if is_instance_valid(btn_row):
		vbox.move_child(_post_match_panel, btn_row.get_index())
	return _post_match_panel


func configure_post_match(post_match_data: Dictionary) -> void:
	if GameManager.is_bot_match() or GameManager.match_players.size() != 2 or post_match_data.is_empty():
		if is_instance_valid(_post_match_panel):
			_post_match_panel.reset_and_hide()
		return
	var pm_panel: VBoxContainer = _ensure_post_match_panel()
	if not is_instance_valid(pm_panel):
		return
	var shown: bool = pm_panel.configure(post_match_data)
	var root_vbox: VBoxContainer = get_node_or_null("CenterContainer/Panel/VBox") as VBoxContainer
	if shown:
		if is_instance_valid(root_vbox):
			root_vbox.add_theme_constant_override("separation", 10)
		if is_instance_valid(emblem_box):
			emblem_box.custom_minimum_size = Vector2(110, 88)
		if is_instance_valid(p1_card):
			p1_card.custom_minimum_size.y = 112.0
		if is_instance_valid(p2_card):
			p2_card.custom_minimum_size.y = 112.0
		if is_instance_valid(btn_return):
			btn_return.custom_minimum_size.y = 48.0
			btn_return.text = "خروج به منو"
			KenneyUI.style_button(btn_return, KenneyUI.COLOR_GREY)


func close() -> void:
	if is_instance_valid(_post_match_panel):
		_post_match_panel.reset_and_hide()
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
	if is_instance_valid(_post_match_panel):
		_post_match_panel.reset_and_hide()
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
	var s: String = str(val)
	var fa: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out: String = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out


func update_scores(p1_score: int, p2_score: int) -> void:
	var show_round_scores: bool = GameRegistry.has_round_score(GameManager.current_game_type) and ((GameManager.current_game_type == GameTypes.QUIZ) or (GameManager.max_rounds > 1) or (p1_score > 0 or p2_score > 0))
	var prefix: String = "امتیاز: %s" if GameRegistry.is_cumulative_score(GameManager.current_game_type) else "دست‌ها: %s"
	if is_instance_valid(lbl_p1_score):
		lbl_p1_score.visible = show_round_scores
		if show_round_scores:
			lbl_p1_score.text = prefix % _fa_digits(p1_score)
	if is_instance_valid(lbl_p2_score):
		lbl_p2_score.visible = show_round_scores
		if show_round_scores:
			lbl_p2_score.text = prefix % _fa_digits(p2_score)

	if is_instance_valid(_hero_score_lbl):
		var my_i: int = GameManager.my_player_index
		var my_s: int = p1_score if my_i == 1 else p2_score
		var opp_s: int = p2_score if my_i == 1 else p1_score
		if GameManager.is_spectating:
			var p1_name: String = _get_player_display_name(1)
			var p2_name: String = _get_player_display_name(2)
			_hero_score_lbl.text = "نتیجه: %s: %s  |  %s: %s" % [p1_name, _fa_digits(p1_score), p2_name, _fa_digits(p2_score)]
		else:
			_hero_score_lbl.text = "نتیجه مسابقه: شما %s  —  %s حریف" % [_fa_digits(my_s), _fa_digits(opp_s)]

	if visible and is_instance_valid(panel) and panel.visible:
		if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and GameManager.get_player_not_played_turns(1) < 2 and GameManager.get_player_not_played_turns(2) < 2:
			if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE] or (GameManager.current_game_type == GameTypes.QUIZ and GameManager.match_players.size() <= 2):
				var score_winner: int = _current_winner_index
				if p1_score > p2_score:
					score_winner = 1
				elif p2_score > p1_score:
					score_winner = 2
				elif GameManager.current_game_type == GameTypes.QUIZ:
					score_winner = 0
				if score_winner != _current_winner_index and (score_winner > 0 or GameManager.current_game_type == GameTypes.QUIZ):
					_current_winner_index = score_winner
					var my_i: int = GameManager.my_player_index
					var won_now: bool = (int(score_winner) == my_i) and (int(score_winner) != 0)
					var draw_now: bool = (int(score_winner) == 0)
					if draw_now:
						panel.add_theme_stylebox_override("panel", _style_panel_draw)
						lbl_title.text = "نتیجه مساوی!"
						lbl_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
					elif won_now:
						panel.add_theme_stylebox_override("panel", _style_panel_win)
						lbl_title.text = "پیروزی درخشان!"
						lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
					else:
						panel.add_theme_stylebox_override("panel", _style_panel_lose)
						lbl_title.text = "خسته نباشید!"
						lbl_title.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))

					if GameManager.match_players.size() <= 2:
						_populate_2p_matchup(score_winner, p1_score, p2_score, draw_now, my_i)
