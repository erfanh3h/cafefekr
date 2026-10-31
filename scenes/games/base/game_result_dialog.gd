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

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel and is_instance_valid(panel):
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_chip.visible = false
	_setup_styles()
	
	# Authentic Kenney 3D Depth Buttons & Action Juice
	KenneyUI.style_button(btn_return, KenneyUI.COLOR_BLUE)
	
	btn_return.pressed.connect(func():
		AudioManager.sfx_button()
		close()
		return_to_menu_requested.emit()
	)

func _setup_styles() -> void:
	# Winner Card Style
	_style_winner = StyleBoxFlat.new()
	_style_winner.bg_color = Color(0.24, 0.15, 0.08, 0.95)
	_style_winner.border_color = Color(1.0, 0.85, 0.3, 1.0)
	_style_winner.set_border_width_all(3)
	_style_winner.set_corner_radius_all(18)
	_style_winner.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
	_style_winner.shadow_size = 10
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
	_style_plaque_win.shadow_size = 16

	_style_plaque_lose = StyleBoxFlat.new()
	_style_plaque_lose.bg_color = Color(0.11, 0.13, 0.20, 0.98)
	_style_plaque_lose.border_color = Color(0.72, 0.84, 0.98, 1.0)
	_style_plaque_lose.set_border_width_all(3)
	_style_plaque_lose.set_corner_radius_all(48)
	_style_plaque_lose.shadow_color = Color(0.35, 0.55, 0.9, 0.45)
	_style_plaque_lose.shadow_size = 14

	_style_plaque_draw = StyleBoxFlat.new()
	_style_plaque_draw.bg_color = Color(0.14, 0.11, 0.08, 0.98)
	_style_plaque_draw.border_color = Color(0.85, 0.72, 0.45, 1.0)
	_style_plaque_draw.set_border_width_all(3)
	_style_plaque_draw.set_corner_radius_all(48)
	_style_plaque_draw.shadow_color = Color(0.65, 0.5, 0.2, 0.35)
	_style_plaque_draw.shadow_size = 12

var _current_winner_index: int = -1
var _current_is_friendly: bool = true

func show_result(winner_player_index: int, p1_score: int, p2_score: int, is_friendly: bool = true) -> void:
	if visible and is_instance_valid(panel) and panel.visible:
		return
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	if panel and is_instance_valid(panel):
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if btn_return and is_instance_valid(btn_return):
		btn_return.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_return.disabled = false

	var resolved_winner = winner_player_index
	if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and GameManager.get_player_not_played_turns(1) < 4 and GameManager.get_player_not_played_turns(2) < 4:
		if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE]:
			if p1_score > p2_score:
				resolved_winner = 1
			elif p2_score > p1_score:
				resolved_winner = 2
	winner_player_index = resolved_winner
	_current_winner_index = winner_player_index
	_current_is_friendly = is_friendly

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
	
	# Friendly games have no rank rewards
	rewards_hbox.visible = not is_friendly
	
	# Start rotating background sunburst aura
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(aura_ray, "rotation", TAU, 6.0).from(0.0)
	
	if _aura_pulse and _aura_pulse.is_valid():
		_aura_pulse.kill()
	_aura_pulse = create_tween().set_loops()
	_aura_pulse.tween_property(aura_ray, "scale", Vector2(1.12, 1.12), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_aura_pulse.tween_property(aura_ray, "scale", Vector2(0.92, 0.92), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
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
		
	# Setup player cards (supports both standard 2-player and 3-4 player Ludo podium)
	var is_multi_ludo = (GameManager.match_players.size() > 2 or GameManager.current_game_type == GameTypes.LUDO) and (GameManager.ludo_rank1 > 0 or winner_player_index > 2)
	var p1_data: Dictionary = {}
	var p2_data: Dictionary = {}
	if is_multi_ludo:
		var r1 = GameManager.ludo_rank1 if GameManager.ludo_rank1 > 0 else max(1, winner_player_index)
		var r2 = GameManager.ludo_rank2 if GameManager.ludo_rank2 > 0 else (2 if r1 != 2 else 1)
		p1_data = GameManager.get_player_data_by_gamer_id(r1)
		p2_data = GameManager.get_player_data_by_gamer_id(r2)
		var color_names = {1: " (قرمز)", 2: " (آبی)", 3: " (سبز)", 4: " (زرد)"}
		var color_vals = {
			1: Color(1.0, 0.48, 0.52),
			2: Color(0.48, 0.82, 1.0),
			3: Color(0.42, 0.95, 0.55),
			4: Color(1.0, 0.88, 0.32)
		}
		lbl_p1_name.text = str(p1_data.get("name", p1_data.get("username", "بازیکن %d" % r1))) + color_names.get(r1, "")
		lbl_p2_name.text = str(p2_data.get("name", p2_data.get("username", "بازیکن %d" % r2))) + color_names.get(r2, "")
		lbl_p1_name.add_theme_color_override("font_color", color_vals.get(r1, Color(1.0, 0.88, 0.3)))
		lbl_p2_name.add_theme_color_override("font_color", color_vals.get(r2, Color(0.85, 0.85, 0.95)))
		update_scores(p1_score, p2_score)
		p1_card.add_theme_stylebox_override("panel", _style_winner)
		p2_card.add_theme_stylebox_override("panel", _style_normal)
		p1_winner_tag.text = "👑 مقام اول"
		p1_winner_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		p2_winner_tag.text = "🥈 مقام دوم"
		p2_winner_tag.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	else:
		p1_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()
		p2_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()
		var p1_suffix = "" if GameManager.current_game_type == GameTypes.FEKRBEKR else " (قرمز)"
		var p2_suffix = "" if GameManager.current_game_type == GameTypes.FEKRBEKR else " (آبی)"
		lbl_p1_name.text = p1_data.get("name", p1_data.get("username", "بازیکن ۱")) + p1_suffix
		lbl_p2_name.text = p2_data.get("name", p2_data.get("username", "بازیکن ۲")) + p2_suffix
		lbl_p1_name.add_theme_color_override("font_color", Color(1.0, 0.48, 0.52))
		lbl_p2_name.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0))
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
	
	var av1_path = "res://assets/icons/Avatars/%d.png" % av1_id
	if ResourceLoader.exists(av1_path):
		img_p1_avatar.texture = load(av1_path)
		
	var av2_path = "res://assets/icons/Avatars/%d.png" % av2_id
	if ResourceLoader.exists(av2_path):
		img_p2_avatar.texture = load(av2_path)
		
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
	var show_round_scores = GameRegistry.has_round_score(GameManager.current_game_type) and ((GameManager.max_rounds > 1) or (p1_score > 0 or p2_score > 0))
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
		if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and GameManager.get_player_not_played_turns(1) < 4 and GameManager.get_player_not_played_turns(2) < 4:
			if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE]:
				var score_winner = _current_winner_index
				if p1_score > p2_score:
					score_winner = 1
				elif p2_score > p1_score:
					score_winner = 2
				if score_winner != _current_winner_index and score_winner > 0:
					visible = false
					panel.visible = false
					show_result(score_winner, p1_score, p2_score, _current_is_friendly)

