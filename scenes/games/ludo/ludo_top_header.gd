class_name LudoTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Ludo Multi-Player Top Header (Supports 2, 3, or 4 Players)
# Inherits BaseTopHeader structurally without altering 2-player headers.
# Dynamically creates P3Card (Emerald Green) and P4Card (Sunburst Yellow)
# inside PlayersRow when a 3-player or 4-player Ludo match is active.

signal player_profile_clicked(player_index: int)

var p3_card: PanelContainer = null
var p4_card: PanelContainer = null

var _extra_cards: Dictionary = {} # idx (3,4) -> Dictionary of child node refs
var _style_p3_active: StyleBoxFlat
var _style_p3_inactive: StyleBoxFlat
var _style_p4_active: StyleBoxFlat
var _style_p4_inactive: StyleBoxFlat
var _style_avatar_p3_active: StyleBoxFlat
var _style_avatar_p3_idle: StyleBoxFlat
var _style_avatar_p4_active: StyleBoxFlat
var _style_avatar_p4_idle: StyleBoxFlat
var _style_match_box_p3: StyleBoxFlat
var _style_match_box_p4: StyleBoxFlat

var _player_names: Dictionary = {
	1: "بازیکن ۱",
	2: "بازیکن ۲",
	3: "بازیکن ۳",
	4: "بازیکن ۴"
}
var _home_counts: Array = [0, 0, 0, 0]
var _reaction_seqs: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.25, 0.30), # Ruby Red
	2: Color(0.25, 0.65, 1.00), # Sapphire Blue
	3: Color(0.22, 0.88, 0.44), # Emerald Green
	4: Color(1.00, 0.80, 0.18), # Sunburst Yellow
}

const FACTION_BADGES_2P: Dictionary = {
	1: "🔴 مهره قرمز",
	2: "🔵 مهره آبی",
	3: "🟢 مهره سبز",
	4: "🟡 مهره زرد",
}

const FACTION_BADGES_COMPACT: Dictionary = {
	1: "🔴 قرمز",
	2: "🔵 آبی",
	3: "🟢 سبز",
	4: "🟡 زرد",
}

func _ready() -> void:
	super._ready()
	_setup_multiplayer_styles()
	_build_extra_player_cards()
	_update_score_badges_visibility()

func _is_score_based_game() -> bool:
	return true

func _setup_multiplayer_styles() -> void:
	# P3 Active (Emerald Jade Illuminated Plaque)
	_style_p3_active = _style_p1_active.duplicate()
	_style_p3_active.bg_color = Color(0.06, 0.24, 0.12, 0.96)
	_style_p3_active.border_color = Color(0.32, 0.95, 0.52, 1.0)
	_style_p3_active.shadow_color = Color(0.15, 0.85, 0.38, 0.55)
	_style_p3_inactive = _style_p1_inactive.duplicate()

	# P4 Active (Sunburst Royal Gold Plaque)
	_style_p4_active = _style_p1_active.duplicate()
	_style_p4_active.bg_color = Color(0.26, 0.19, 0.05, 0.96)
	_style_p4_active.border_color = Color(1.0, 0.86, 0.25, 1.0)
	_style_p4_active.shadow_color = Color(1.0, 0.78, 0.15, 0.55)
	_style_p4_inactive = _style_p1_inactive.duplicate()

	# Avatar Medallion Rings for P3 & P4
	_style_avatar_p3_active = _style_avatar_p1_active.duplicate()
	_style_avatar_p3_active.bg_color = Color(0.05, 0.22, 0.10, 0.95)
	_style_avatar_p3_active.border_color = Color(0.38, 0.96, 0.55, 1.0)
	_style_avatar_p3_active.shadow_color = Color(0.18, 0.88, 0.42, 0.50)
	_style_avatar_p3_idle = _style_avatar_p1_idle.duplicate()

	_style_avatar_p4_active = _style_avatar_p1_active.duplicate()
	_style_avatar_p4_active.bg_color = Color(0.24, 0.18, 0.04, 0.95)
	_style_avatar_p4_active.border_color = Color(1.0, 0.88, 0.32, 1.0)
	_style_avatar_p4_active.shadow_color = Color(1.0, 0.78, 0.18, 0.50)
	_style_avatar_p4_idle = _style_avatar_p1_idle.duplicate()

	_style_match_box_p3 = _style_match_box_normal.duplicate()
	_style_match_box_p3.border_color = Color(0.35, 0.92, 0.52, 0.95)
	_style_match_box_p4 = _style_match_box_normal.duplicate()
	_style_match_box_p4.border_color = Color(1.0, 0.86, 0.28, 0.95)

func _build_extra_player_cards() -> void:
	var players_row = get_node_or_null("Margin/VBoxMain/PlayersRow") as HBoxContainer
	if not players_row or not is_instance_valid(p2_card):
		return
	for idx in [3, 4]:
		var card_dup = p2_card.duplicate(0) as PanelContainer
		card_dup.name = "P%dCard" % idx
		card_dup.visible = false
		players_row.add_child(card_dup)

		var av_container = card_dup.get_node_or_null("HBox/AvatarContainer") as Control
		var av_rect = card_dup.get_node_or_null("HBox/AvatarContainer/Avatar") as TextureRect
		var av_frame = card_dup.get_node_or_null("HBox/AvatarContainer/AvatarMedallionFrame") as Panel
		var side_lbl = card_dup.get_node_or_null("HBox/AvatarContainer/PlayerSideTag") as Label
		var btn_prof = card_dup.get_node_or_null("HBox/AvatarContainer/BtnP2Profile") as Button
		var name_lbl = card_dup.get_node_or_null("HBox/InfoBox/Name") as Label
		var role_lbl = card_dup.get_node_or_null("HBox/InfoBox/RoleBadge") as Label
		var score_badge = card_dup.get_node_or_null("HBox/ScoreBadge") as PanelContainer
		var score_lbl = card_dup.get_node_or_null("HBox/ScoreBadge/Score") as Label
		var react_bubble = card_dup.get_node_or_null("ReactionBubble") as Control
		var react_icon = card_dup.get_node_or_null("ReactionBubble/BubbleFrame/Icon") as TextureRect

		if is_instance_valid(btn_prof):
			btn_prof.name = "BtnP%dProfile" % idx
			for conn in btn_prof.pressed.get_connections():
				btn_prof.pressed.disconnect(conn["callable"])
			var player_i = idx
			btn_prof.pressed.connect(func(): player_profile_clicked.emit(player_i))

		if is_instance_valid(role_lbl):
			var sb_role = StyleBoxFlat.new()
			if idx == 3:
				sb_role.bg_color = Color(0.08, 0.34, 0.16, 0.82)
				sb_role.border_color = Color(0.38, 0.95, 0.55, 0.72)
			else:
				sb_role.bg_color = Color(0.38, 0.28, 0.06, 0.82)
				sb_role.border_color = Color(1.0, 0.88, 0.32, 0.72)
			sb_role.set_border_width_all(1)
			sb_role.set_corner_radius_all(10)
			sb_role.content_margin_left = 8
			sb_role.content_margin_right = 8
			sb_role.content_margin_top = 2
			sb_role.content_margin_bottom = 2
			role_lbl.add_theme_stylebox_override("normal", sb_role)
			role_lbl.text = FACTION_BADGES_COMPACT[idx]

		if is_instance_valid(score_lbl):
			score_lbl.text = _fa_digits(0)

		card_dup.add_theme_stylebox_override("panel", _style_p3_inactive if idx == 3 else _style_p4_inactive)
		if is_instance_valid(av_frame):
			av_frame.add_theme_stylebox_override("panel", _style_avatar_p3_idle if idx == 3 else _style_avatar_p4_idle)

		_extra_cards[idx] = {
			"card": card_dup,
			"av_container": av_container,
			"avatar": av_rect,
			"av_frame": av_frame,
			"side_tag": side_lbl,
			"name": name_lbl,
			"role": role_lbl,
			"score_badge": score_badge,
			"score": score_lbl,
			"reaction_bubble": react_bubble,
			"reaction_icon": react_icon,
		}
		if idx == 3:
			p3_card = card_dup
		else:
			p4_card = card_dup

func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)

func _apply_layout_for_player_count(total_players: int) -> void:
	var players_row = get_node_or_null("Margin/VBoxMain/PlayersRow") as HBoxContainer
	var is_compact = (total_players > 2)
	if is_instance_valid(players_row):
		players_row.add_theme_constant_override("separation", 8 if is_compact else 16)

	var all_cards = [
		{"idx": 1, "card": p1_card, "av_c": p1_avatar.get_parent() if is_instance_valid(p1_avatar) else null, "name": p1_name, "role": p1_role_badge, "score_b": _p1_score_badge, "score": p1_score_lbl},
		{"idx": 2, "card": p2_card, "av_c": p2_avatar.get_parent() if is_instance_valid(p2_avatar) else null, "name": p2_name, "role": p2_role_badge, "score_b": _p2_score_badge, "score": p2_score_lbl},
	]
	for idx in [3, 4]:
		if _extra_cards.has(idx):
			var d = _extra_cards[idx]
			all_cards.append({
				"idx": idx,
				"card": d["card"],
				"av_c": d["av_container"],
				"name": d["name"],
				"role": d["role"],
				"score_b": d["score_badge"],
				"score": d["score"],
			})

	for item in all_cards:
		var idx: int = item["idx"]
		var c: PanelContainer = item["card"]
		if not is_instance_valid(c):
			continue
		c.visible = (idx <= total_players)
		c.custom_minimum_size = Vector2(0, 118 if is_compact else 140)
		var hbox = c.get_node_or_null("HBox") as HBoxContainer
		if hbox:
			hbox.add_theme_constant_override("separation", 6 if is_compact else 12)
		var av_c: Control = item["av_c"]
		if is_instance_valid(av_c):
			var av_sz = 68.0 if total_players == 4 else (76.0 if total_players == 3 else 96.0)
			av_c.custom_minimum_size = Vector2(av_sz, av_sz)
		var nm: Label = item["name"]
		if is_instance_valid(nm):
			nm.add_theme_font_size_override("font_size", 22 if total_players == 4 else (25 if total_players == 3 else 32))
		var rl: Label = item["role"]
		if is_instance_valid(rl):
			rl.add_theme_font_size_override("font_size", 18 if is_compact else 22)
			rl.text = FACTION_BADGES_COMPACT[idx] if is_compact else FACTION_BADGES_2P[idx]
		var sb: PanelContainer = item["score_b"]
		if is_instance_valid(sb):
			sb.visible = true
			var b_sz = 44.0 if total_players == 4 else (48.0 if total_players == 3 else 58.0)
			sb.custom_minimum_size = Vector2(b_sz, b_sz)
		var sc: Label = item["score"]
		if is_instance_valid(sc):
			sc.add_theme_font_size_override("font_size", 28 if is_compact else 38)

func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_my_player_index = my_idx
	var total_players = _get_total_players()
	_apply_layout_for_player_count(total_players)

	var d1 = GameManager.get_player_data_by_gamer_id(1) if total_players > 2 else p1_data
	var d2 = GameManager.get_player_data_by_gamer_id(2) if total_players > 2 else p2_data
	super.setup_players(d1, d2, my_idx)

	_player_names[1] = str(d1.get("name", d1.get("username", "بازیکن ۱")))
	_player_names[2] = str(d2.get("name", d2.get("username", "بازیکن ۲")))

	for idx in [3, 4]:
		if not _extra_cards.has(idx):
			continue
		var info = _extra_cards[idx]
		var card: PanelContainer = info["card"]
		if idx > total_players:
			card.visible = false
			continue
		card.visible = true
		var p_data = GameManager.get_player_data_by_gamer_id(idx)
		var p_name = str(p_data.get("name", p_data.get("username", "بازیکن %d" % idx)))
		_player_names[idx] = p_name
		if is_instance_valid(info["name"]):
			info["name"].text = p_name
		if is_instance_valid(info["role"]):
			info["role"].text = FACTION_BADGES_COMPACT[idx] if total_players > 2 else FACTION_BADGES_2P[idx]
		var av_id = int(p_data.get("image", p_data.get("user_image", 0)))
		var tex = _get_cached_avatar(av_id)
		if tex and is_instance_valid(info["avatar"]):
			info["avatar"].texture = tex
		if is_instance_valid(info["side_tag"]):
			var is_me = (my_idx == idx)
			info["side_tag"].text = "شما" if is_me else "حریف"
			var sb_side = StyleBoxFlat.new()
			sb_side.bg_color = Color(0.18, 0.65, 0.30, 0.94) if is_me else Color(0.24, 0.16, 0.10, 0.92)
			sb_side.border_color = Color(0.96, 0.80, 0.35, 0.90)
			sb_side.set_border_width_all(1)
			sb_side.set_corner_radius_all(8)
			info["side_tag"].add_theme_stylebox_override("normal", sb_side)

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	var total_players = _get_total_players()
	_apply_layout_for_player_count(total_players)
	if is_instance_valid(lbl_round):
		lbl_round.text = "%s (%s نفره)" % [game_name_fa, _fa_digits(total_players)]

func update_ludo_home_counts(home_counts: Array, rank1: int = 0, rank2: int = 0) -> void:
	_home_counts = home_counts.duplicate()
	var labels = {
		1: p1_score_lbl,
		2: p2_score_lbl,
		3: _extra_cards.get(3, {}).get("score", null),
		4: _extra_cards.get(4, {}).get("score", null),
	}
	for idx in [1, 2, 3, 4]:
		var lbl: Label = labels[idx]
		if not is_instance_valid(lbl):
			continue
		var cnt = int(home_counts[idx - 1]) if idx - 1 < home_counts.size() else 0
		if rank1 == idx:
			lbl.text = "👑"
		elif rank2 == idx:
			lbl.text = "🥈"
		else:
			lbl.text = "%s/۴" % _fa_digits(cnt)

func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_player_names[1] = p1_n
	_player_names[2] = p2_n

	var total_players = _get_total_players()
	_apply_layout_for_player_count(total_players)

	var cards = {
		1: {"card": p1_card, "av": _p1_avatar_frame, "act": _style_p1_active, "idl": _style_p1_inactive, "av_act": _style_avatar_p1_active, "av_idl": _style_avatar_p1_idle},
		2: {"card": p2_card, "av": _p2_avatar_frame, "act": _style_p2_active, "idl": _style_p2_inactive, "av_act": _style_avatar_p2_active, "av_idl": _style_avatar_p2_idle},
	}
	for idx in [3, 4]:
		if _extra_cards.has(idx):
			cards[idx] = {
				"card": _extra_cards[idx]["card"],
				"av": _extra_cards[idx]["av_frame"],
				"act": _style_p3_active if idx == 3 else _style_p4_active,
				"idl": _style_p3_inactive if idx == 3 else _style_p4_inactive,
				"av_act": _style_avatar_p3_active if idx == 3 else _style_avatar_p4_active,
				"av_idl": _style_avatar_p3_idle if idx == 3 else _style_avatar_p4_idle,
			}

	for idx in cards.keys():
		var item = cards[idx]
		var c: PanelContainer = item["card"]
		var av: Panel = item["av"]
		var is_act = (turn == idx)
		if is_instance_valid(c):
			c.add_theme_stylebox_override("panel", item["act"] if is_act else item["idl"])
			c.pivot_offset = c.size * 0.5
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", Vector2(1.03, 1.03) if is_act else Vector2(0.97, 0.97), 0.22)
		if is_instance_valid(av):
			av.add_theme_stylebox_override("panel", item["av_act"] if is_act else item["av_idl"])

	var active_col: Color = FACTION_COLORS.get(turn, Color(1.0, 0.88, 0.45))
	if is_instance_valid(match_details_box):
		match turn:
			1: match_details_box.add_theme_stylebox_override("panel", _style_match_box_p1)
			2: match_details_box.add_theme_stylebox_override("panel", _style_match_box_p2)
			3: match_details_box.add_theme_stylebox_override("panel", _style_match_box_p3)
			4: match_details_box.add_theme_stylebox_override("panel", _style_match_box_p4)
			_: match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)

	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = active_col
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = active_col

	if is_instance_valid(lbl_turn_banner):
		if not GameManager.is_game_active or turn <= 0:
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		elif turn == my_idx:
			lbl_turn_banner.text = "🎲 نوبت شماست! تاس بریزید"
			lbl_turn_banner.add_theme_color_override("font_color", active_col.lightened(0.25))
		else:
			var t_name = _player_names.get(turn, "بازیکن %d" % turn)
			var color_words = {1: "قرمز", 2: "آبی", 3: "سبز", 4: "زرد"}
			lbl_turn_banner.text = "🎲 نوبت %s (%s)..." % [t_name, color_words.get(turn, "")]
			lbl_turn_banner.add_theme_color_override("font_color", active_col.lightened(0.22))

func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	if turn <= 2:
		super.update_timer(remaining_sec, total_sec, turn)
		return
	var is_danger = (remaining_sec <= 5.0 and remaining_sec > 0.0)
	var base_col: Color = FACTION_COLORS.get(turn, Color(0.25, 0.65, 1.0))
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = is_danger
		_timer_vfx_overlay.theme_color = base_col
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
		else:
			match_details_box.add_theme_stylebox_override("panel", _style_match_box_p3 if turn == 3 else _style_match_box_p4)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(1.0, 0.24, 0.26) if is_danger else base_col

func show_reaction(user_index: int, reaction_id: int) -> void:
	if user_index <= 2 or not _extra_cards.has(user_index):
		super.show_reaction(user_index, reaction_id)
		return
	var info = _extra_cards[user_index]
	var bubble: Control = info.get("reaction_bubble", null)
	var icon: TextureRect = info.get("reaction_icon", null)
	if not is_instance_valid(bubble) or not is_instance_valid(icon):
		return
	_reaction_seqs[user_index] = int(_reaction_seqs.get(user_index, 0)) + 1
	var my_seq: int = _reaction_seqs[user_index]
	var bubble_frame = bubble.get_node_or_null("BubbleFrame") as PanelContainer
	var kori_lbl: Label = null
	if is_instance_valid(bubble_frame):
		kori_lbl = bubble_frame.get_node_or_null("KoriLabel") as Label
		if not is_instance_valid(kori_lbl):
			kori_lbl = Label.new()
			kori_lbl.name = "KoriLabel"
			kori_lbl.add_theme_font_override("font", _font_hekayat)
			kori_lbl.add_theme_font_size_override("font_size", 22)
			kori_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
			kori_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kori_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			kori_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			kori_lbl.custom_minimum_size = Vector2(260, 70)
			bubble_frame.add_child(kori_lbl)
	bubble.z_index = 30
	var hold_duration = 2.4
	if reaction_id > 100:
		var k_idx = clampi(reaction_id - 101, 0, KORIS.size() - 1)
		icon.visible = false
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = true
			kori_lbl.text = "💬 " + KORIS[k_idx]
		hold_duration = 4.0
	else:
		if is_instance_valid(kori_lbl):
			kori_lbl.visible = false
		icon.visible = true
		var r_tex = _get_cached_reaction(reaction_id)
		if r_tex:
			icon.texture = r_tex
	bubble.visible = true
	bubble.scale = Vector2(0.1, 0.1)
	bubble.modulate.a = 0.0
	AudioManager.play_sound("chat")
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.12, 1.12), 0.22)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.16)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.1)
	await get_tree().create_timer(hold_duration).timeout
	if int(_reaction_seqs.get(user_index, 0)) != my_seq:
		return
	if is_instance_valid(bubble):
		bubble.visible = false
