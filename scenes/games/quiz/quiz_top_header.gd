class_name QuizTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Quiz Multi-Player Top Header (Supports 2, 3, or 4 Players)
# Displays player avatars, names, live lock-in status, and color-coded quiz scores (+1 / -1 / 0).
# Inherits BaseTopHeader structurally without altering other games.

var _quiz_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var _player_answered: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _role_styles_default: Dictionary = {}
var _role_style_answered: StyleBoxFlat = null
var _score_styles: Dictionary = {}

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.25, 0.30), # Ruby Red
	2: Color(0.25, 0.65, 1.00), # Sapphire Blue
	3: Color(0.22, 0.88, 0.44), # Emerald Green
	4: Color(1.00, 0.80, 0.18), # Sunburst Yellow
}

const FACTION_BADGES_2P: Dictionary = {
	1: "🔴 بازیکن ۱",
	2: "🔵 بازیکن ۲",
	3: "🟢 بازیکن ۳",
	4: "🟡 بازیکن ۴",
}

const FACTION_BADGES_COMPACT: Dictionary = {
	1: "🔴 ۱",
	2: "🔵 ۲",
	3: "🟢 ۳",
	4: "🟡 ۴",
}

func _ready() -> void:
	super._ready()
	_setup_multiplayer_styles()
	_build_extra_player_cards()
	_update_score_badges_visibility()

func _is_score_based_game() -> bool:
	return true

func _get_role_badge_text(player_idx: int) -> String:
	var total_players = _get_total_players()
	if total_players > 2:
		return FACTION_BADGES_COMPACT.get(player_idx, "بازیکن")
	return FACTION_BADGES_2P.get(player_idx, "بازیکن")

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

	_role_style_answered = StyleBoxFlat.new()
	_role_style_answered.bg_color = Color(0.08, 0.34, 0.22, 0.92)
	_role_style_answered.border_color = Color(0.35, 0.98, 0.62, 0.92)
	_role_style_answered.set_border_width_all(1)
	_role_style_answered.set_corner_radius_all(10)
	_role_style_answered.content_margin_left = 8
	_role_style_answered.content_margin_right = 8
	_role_style_answered.content_margin_top = 2
	_role_style_answered.content_margin_bottom = 2

	for idx in [1, 2]:
		var role_lbl = p1_role_badge if idx == 1 else p2_role_badge
		if is_instance_valid(role_lbl):
			var sb = role_lbl.get_theme_stylebox("normal")
			if sb is StyleBoxFlat:
				_role_styles_default[idx] = sb.duplicate()

	for k in ["pos", "neg", "zero"]:
		var sb_s = StyleBoxFlat.new()
		sb_s.set_border_width_all(2)
		sb_s.border_width_bottom = 3
		sb_s.set_corner_radius_all(14)
		sb_s.shadow_color = Color(0, 0, 0, 0.42)
		sb_s.shadow_size = 4
		sb_s.content_margin_left = 6
		sb_s.content_margin_right = 6
		sb_s.content_margin_top = 4
		sb_s.content_margin_bottom = 4
		if k == "pos":
			sb_s.bg_color = Color(0.06, 0.22, 0.11, 0.95)
			sb_s.border_color = Color(0.35, 0.96, 0.55, 0.95)
		elif k == "neg":
			sb_s.bg_color = Color(0.24, 0.06, 0.08, 0.95)
			sb_s.border_color = Color(1.0, 0.38, 0.40, 0.95)
		else:
			sb_s.bg_color = Color(0.09, 0.05, 0.03, 0.92)
			sb_s.border_color = Color(0.94, 0.76, 0.28, 0.90)
		_score_styles[k] = sb_s

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
		if is_instance_valid(react_bubble):
			react_bubble.top_level = true
			react_bubble.visible = false
		var react_icon = card_dup.get_node_or_null("ReactionBubble/BubbleFrame/Icon") as TextureRect

		if is_instance_valid(btn_prof):
			btn_prof.name = "BtnP%dProfile" % idx
			btn_prof.focus_mode = Control.FOCUS_NONE
			for conn in btn_prof.pressed.get_connections():
				btn_prof.pressed.disconnect(conn["callable"])
			var player_i = idx
			btn_prof.pressed.connect(func():
				if _can_emit_profile_click():
					player_profile_clicked.emit(player_i)
			)

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
			_role_styles_default[idx] = sb_role.duplicate()
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

func _get_card_refs(gid: int) -> Dictionary:
	if gid == 1:
		return {
			"card": p1_card,
			"av_frame": _p1_avatar_frame,
			"name": p1_name,
			"role": p1_role_badge,
			"score_badge": _p1_score_badge,
			"score": p1_score_lbl,
		}
	elif gid == 2:
		return {
			"card": p2_card,
			"av_frame": _p2_avatar_frame,
			"name": p2_name,
			"role": p2_role_badge,
			"score_badge": _p2_score_badge,
			"score": p2_score_lbl,
		}
	elif _extra_cards.has(gid):
		return _extra_cards[gid]
	return {}

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
		c.custom_minimum_size = Vector2(0, 114 if is_compact else 136)
		var hbox = c.get_node_or_null("HBox") as HBoxContainer
		if hbox:
			hbox.add_theme_constant_override("separation", 6 if is_compact else 12)
		var av_c: Control = item["av_c"]
		if is_instance_valid(av_c):
			var av_sz = 64.0 if total_players == 4 else (74.0 if total_players == 3 else 94.0)
			av_c.custom_minimum_size = Vector2(av_sz, av_sz)
		var nm: Label = item["name"]
		if is_instance_valid(nm):
			nm.add_theme_font_size_override("font_size", 24 if total_players == 4 else (26 if total_players == 3 else 34))
		var rl: Label = item["role"]
		if is_instance_valid(rl):
			rl.add_theme_font_size_override("font_size", 19 if is_compact else 23)
			rl.text = "🔒 ثبت شد" if bool(_player_answered.get(idx, false)) else (FACTION_BADGES_COMPACT[idx] if is_compact else FACTION_BADGES_2P[idx])
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

	update_quiz_scores(_quiz_scores)
	_sync_all_cards_visual()

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	var total_players = _get_total_players()
	_apply_layout_for_player_count(total_players)
	if is_instance_valid(lbl_round):
		lbl_round.text = "%s (%s نفره)" % [game_name_fa, _fa_digits(total_players)]
	update_quiz_scores(_quiz_scores)
	_sync_all_cards_visual()

func _on_turn_changed(_turn: int) -> void:
	# Simultaneous quiz: illuminate all active player cards uniformly and preserve quiz status banner
	_sync_all_cards_visual()
	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
	if is_instance_valid(lbl_turn_banner) and GameManager.is_game_active:
		if bool(_player_answered.get(_my_player_index, false)):
			lbl_turn_banner.text = "🔒 پاسخ شما ثبت شد — منتظر پایان زمان..."
			lbl_turn_banner.add_theme_color_override("font_color", Color(0.42, 0.95, 0.65))
		else:
			lbl_turn_banner.text = "🤔 گزینه درست را انتخاب کنید"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))

func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	super.update_timer(remaining_sec, total_sec, turn)
	# Keep royal gold match box border when not in final 4-second danger countdown
	var is_danger = (remaining_sec <= 4.0 and remaining_sec > 0.0)
	if not is_danger and is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)

func _sync_all_cards_visual() -> void:
	var active_styles = {1: _style_p1_active, 2: _style_p2_active, 3: _style_p3_active, 4: _style_p4_active}
	var av_active_styles = {1: _style_avatar_p1_active, 2: _style_avatar_p2_active, 3: _style_avatar_p3_active, 4: _style_avatar_p4_active}
	var total_players = _get_total_players()
	for gid in range(1, total_players + 1):
		var refs = _get_card_refs(gid)
		var c: PanelContainer = refs.get("card")
		var av_f: Panel = refs.get("av_frame")
		if is_instance_valid(c) and active_styles.get(gid):
			c.add_theme_stylebox_override("panel", active_styles[gid])
			c.scale = Vector2.ONE
		if is_instance_valid(av_f) and av_active_styles.get(gid):
			av_f.add_theme_stylebox_override("panel", av_active_styles[gid])

func set_player_answered(gid: int, answered: bool) -> void:
	var was_answered = bool(_player_answered.get(gid, false))
	_player_answered[gid] = answered
	var refs = _get_card_refs(gid)
	var role_lbl: Label = refs.get("role")
	var total_players = _get_total_players()
	if is_instance_valid(role_lbl):
		if answered:
			role_lbl.text = "🔒 ثبت شد"
			if is_instance_valid(_role_style_answered):
				role_lbl.add_theme_stylebox_override("normal", _role_style_answered)
			role_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
		else:
			role_lbl.text = FACTION_BADGES_COMPACT.get(gid, "") if total_players > 2 else FACTION_BADGES_2P.get(gid, "")
			if _role_styles_default.has(gid):
				role_lbl.add_theme_stylebox_override("normal", _role_styles_default[gid])
			role_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	if answered and not was_answered:
		var card: Control = refs.get("card")
		if is_instance_valid(card):
			_animate_card_pulse(card)

func clear_answered_states() -> void:
	for gid in [1, 2, 3, 4]:
		set_player_answered(gid, false)

func update_scores(p1_score: int, p2_score: int) -> void:
	# Preserve multiplayer scores while keeping 2-player updates accurate
	var next_scores = _quiz_scores.duplicate()
	next_scores[1] = p1_score
	next_scores[2] = p2_score
	update_quiz_scores(next_scores)

func update_quiz_scores(scores: Dictionary) -> void:
	for gid in [1, 2, 3, 4]:
		var val = _quiz_scores.get(gid, 0)
		if scores.has(gid):
			val = int(scores[gid])
		elif scores.has(str(gid)):
			val = int(scores[str(gid)])
		var prev_val = int(_quiz_scores.get(gid, 0))
		_quiz_scores[gid] = val

		var refs = _get_card_refs(gid)
		var lbl: Label = refs.get("score")
		var badge: PanelContainer = refs.get("score_badge")

		if is_instance_valid(lbl):
			var formatted = _fa_digits(val) if val >= 0 else ("-%s" % _fa_digits(abs(val)))
			lbl.text = formatted
			var txt_col = Color(0.45, 0.98, 0.58) if val > 0 else (Color(1.0, 0.42, 0.45) if val < 0 else Color(1.0, 0.90, 0.35))
			lbl.add_theme_color_override("font_color", txt_col)
			if is_instance_valid(badge):
				var sb_key = "pos" if val > 0 else ("neg" if val < 0 else "zero")
				if _score_styles.has(sb_key):
					badge.add_theme_stylebox_override("panel", _score_styles[sb_key])
			if val != prev_val:
				var anim_target: Control = badge if is_instance_valid(badge) else lbl
				anim_target.pivot_offset = anim_target.size * 0.5
				var tw = create_tween()
				tw.tween_property(anim_target, "scale", Vector2(1.22, 1.22), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(anim_target, "scale", Vector2.ONE, 0.16)

func set_quiz_turn_banner(text: String, col: Color = Color(1.0, 0.88, 0.45)) -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = text
		lbl_turn_banner.add_theme_color_override("font_color", col)

func set_question_number(turn_num: int, total: int = 10) -> void:
	if is_instance_valid(lbl_round):
		lbl_round.text = "سوال %s از %s" % [_fa_digits(turn_num), _fa_digits(total)]

func reset_header() -> void:
	_quiz_scores = {1: 0, 2: 0, 3: 0, 4: 0}
	super.reset_header()
	clear_answered_states()
	update_quiz_scores(_quiz_scores)
	for idx in [3, 4]:
		if _extra_cards.has(idx):
			var info = _extra_cards[idx]
			if is_instance_valid(info.get("card")):
				info["card"].scale = Vector2.ONE
			if is_instance_valid(info.get("reaction_bubble")):
				info["reaction_bubble"].top_level = true
				info["reaction_bubble"].visible = false

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
			kori_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kori_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			kori_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bubble_frame.add_child(kori_lbl)
		kori_lbl.add_theme_font_size_override("font_size", 30)
		kori_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 1.0))
		kori_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		kori_lbl.add_theme_constant_override("shadow_outline_size", 3)
		kori_lbl.custom_minimum_size = Vector2(280, 80)
	bubble.z_index = 30
	bubble.top_level = true
	bubble.size = Vector2.ZERO
	bubble.custom_minimum_size = Vector2.ZERO
	bubble.pivot_offset = Vector2.ZERO
	var card_node = info.get("card", null) as Control
	if is_instance_valid(card_node):
		bubble.global_position = card_node.global_position + card_node.size * 0.5
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
		icon.texture = load("res://assets/icons/Reactions/%d.png" % reaction_id)

	bubble.visible = true
	bubble.scale = Vector2(0.1, 0.1)
	bubble.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold_duration)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if int(_reaction_seqs.get(user_index, 0)) == my_seq:
			bubble.visible = false
	)
