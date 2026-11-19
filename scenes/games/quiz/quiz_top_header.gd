class_name QuizTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Quiz Multi-Player Top Header (Supports 2, 3, or 4 Players)
# Warm Classic Parlor compact layout displaying live lock-in status and color-coded quiz scores (+ / - / 0).

var _quiz_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var _player_answered: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _surrendered_players: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _local_answered_confirmed: bool = false
var _last_layout_players: int = -1
var _score_styles: Dictionary = {}


func _ready() -> void:
	super._ready()
	_score_styles["pos"] = HudTheme.make_score_badge_style("pos")
	_score_styles["neg"] = HudTheme.make_score_badge_style("neg")
	_score_styles["zero"] = HudTheme.make_score_badge_style("normal")
	_build_extra_player_cards()
	_update_score_badges_visibility()


func _is_score_based_game() -> bool:
	return true


func _build_extra_player_cards() -> void:
	var players_row2 := _get_or_create_players_row2()
	if not players_row2 or not is_instance_valid(p2_card):
		return
	for idx in [3, 4]:
		var card_dup := p2_card.duplicate(0) as PanelContainer
		card_dup.name = "P%dCard" % idx
		card_dup.visible = false
		players_row2.add_child(card_dup)
		var bundle := _register_extra_player_card(idx, card_dup)
		var sc: Label = bundle.get("score", null)
		if is_instance_valid(sc):
			sc.text = _fa_digits(0)


func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)


func _get_active_player_indices() -> Array[int]:
	var total := _get_total_players()
	var list: Array[int] = []
	for gid in range(1, total + 1):
		if not is_player_disabled(gid) and not bool(_surrendered_players.get(gid, false)):
			list.append(gid)
	return list


func _apply_layout_for_player_count(total_players: int) -> void:
	_last_layout_players = total_players
	_update_two_row_visibility(total_players)
	var is_compact := (total_players > 2)
	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var c: PanelContainer = b.get("card", null)
		if not is_instance_valid(c):
			continue
		c.visible = (idx <= total_players)
		var sc: Label = b.get("score", null)
		if is_instance_valid(sc):
			sc.add_theme_font_size_override("font_size", 22 if is_compact else 26)
			var sb := sc.get_parent() as PanelContainer
			if is_instance_valid(sb):
				sb.visible = true
				sb.custom_minimum_size = Vector2(40, 36) if is_compact else Vector2(44, 40)
		if is_player_disabled(idx):
			_apply_disabled_visual(idx)
		elif bool(_surrendered_players.get(idx, false)):
			set_player_disabled(idx, true, "🏳️ انصراف")
		elif bool(_player_answered.get(idx, false)):
			_set_role_badge(idx, "🔒 ثبت شد", HudTheme.COL_EMERALD)
		else:
			_set_role_badge(idx, "")


func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_my_player_index = my_idx
	var total_players := _get_total_players()
	_apply_layout_for_player_count(total_players)

	var d1: Dictionary = GameManager.get_player_data_by_gamer_id(1) if total_players > 2 else p1_data
	var d2: Dictionary = GameManager.get_player_data_by_gamer_id(2) if total_players > 2 else p2_data
	super.setup_players(d1, d2, my_idx)

	for idx in [3, 4]:
		if not _extra_cards.has(idx):
			continue
		var info: Dictionary = _extra_cards[idx]
		var card: PanelContainer = info["card"]
		if idx > total_players:
			card.visible = false
			continue
		card.visible = true
		var p_data: Dictionary = GameManager.get_player_data_by_gamer_id(idx)
		var p_name := str(p_data.get("name", p_data.get("username", "بازیکن %d" % idx)))
		_player_names[idx] = p_name
		if is_instance_valid(info["name"]):
			info["name"].text = p_name
			HudTheme.configure_bidi_label(info["name"], true)
		var av_id := int(p_data.get("image", p_data.get("user_image", 0)))
		var p_fid: int = int(GameManager.get_player_frame_id(p_data))
		var tex := _get_cached_avatar(av_id)
		if is_instance_valid(info["avatar"]):
			if tex:
				info["avatar"].texture = tex
			var p_parent = info["avatar"].get_parent()
			CafeSocialTheme.apply_frame_to_container(p_parent if p_parent is Control else info["avatar"], info["avatar"], p_fid)

	update_quiz_scores(_quiz_scores)
	for gid in range(1, total_players + 1):
		if bool(_player_answered.get(gid, false)):
			set_player_answered(gid, true)
	_set_active_cards_visual(_get_active_player_indices(), false, false)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	var total_players := _get_total_players()
	_apply_layout_for_player_count(total_players)
	if is_instance_valid(lbl_round):
		lbl_round.text = "%s (%s نفره)" % [game_name_fa, _fa_digits(total_players)]
	update_quiz_scores(_quiz_scores)
	_set_active_cards_visual(_get_active_player_indices(), false, false)


func set_local_answered(answered: bool) -> void:
	_local_answered_confirmed = answered
	if answered:
		set_player_answered(_my_player_index, true)
		set_quiz_turn_banner("🔒 پاسخ شما ثبت شد — منتظر حریفان...", HudTheme.COL_EMERALD)


func _on_turn_changed(_turn: int) -> void:
	_set_active_cards_visual(_get_active_player_indices(), false, false)
	if GameManager.is_game_active:
		if _local_answered_confirmed:
			show_turn_toast("🔒 پاسخ شما ثبت شد — منتظر حریفان...", HudTheme.COL_EMERALD, false, 2.0)
		else:
			show_turn_toast("🤔 گزینه درست را انتخاب کنید", HudTheme.COL_TEXT_GOLD, false, 1.8)


func update_timer(remaining_sec: float, total_sec: float, _turn: int) -> void:
	_update_card_timer_visuals(remaining_sec, total_sec, _get_active_player_indices())


func set_player_surrendered(gid: int) -> void:
	if gid <= 0:
		return
	_surrendered_players[gid] = true
	_player_answered[gid] = false
	set_player_disabled(gid, true, "🏳️ انصراف")


func set_player_answered(gid: int, answered: bool) -> void:
	if bool(_surrendered_players.get(gid, false)):
		return
	var was_answered := bool(_player_answered.get(gid, false))
	_player_answered[gid] = answered
	if answered:
		_set_role_badge(gid, "🔒 ثبت شد", HudTheme.COL_EMERALD)
		var b := _get_player_card_bundle(gid)
		var rl: Label = b.get("role", null)
		if is_instance_valid(rl):
			rl.add_theme_color_override("font_color", Color(0.68, 0.98, 0.78))
		if not was_answered:
			var card: Control = b.get("card", null)
			if is_instance_valid(card):
				_animate_card_pulse(card)
	else:
		_set_role_badge(gid, "")


func clear_answered_states() -> void:
	_local_answered_confirmed = false
	for gid in [1, 2, 3, 4]:
		if not bool(_surrendered_players.get(gid, false)):
			set_player_answered(gid, false)


func update_scores(p1_score: int, p2_score: int) -> void:
	var next_scores := _quiz_scores.duplicate()
	next_scores[1] = p1_score
	next_scores[2] = p2_score
	update_quiz_scores(next_scores)


func update_quiz_scores(scores: Dictionary) -> void:
	for gid in [1, 2, 3, 4]:
		var val: int = int(_quiz_scores.get(gid, 0))
		if scores.has(gid):
			val = int(scores[gid])
		elif scores.has(str(gid)):
			val = int(scores[str(gid)])
		var prev_val: int = int(_quiz_scores.get(gid, 0))
		_quiz_scores[gid] = val

		var b := _get_player_card_bundle(gid)
		var lbl: Label = b.get("score", null)
		var badge: PanelContainer = lbl.get_parent() as PanelContainer if is_instance_valid(lbl) else null
		if is_instance_valid(lbl):
			lbl.text = _fa_digits(val) if val >= 0 else ("-%s" % _fa_digits(abs(val)))
			var txt_col := HudTheme.COL_EMERALD if val > 0 else (HudTheme.COL_DANGER if val < 0 else HudTheme.COL_TEXT_GOLD)
			lbl.add_theme_color_override("font_color", txt_col)
			if is_instance_valid(badge):
				var sb_key := "pos" if val > 0 else ("neg" if val < 0 else "zero")
				if _score_styles.has(sb_key):
					badge.add_theme_stylebox_override("panel", _score_styles[sb_key])
			if val != prev_val:
				_animate_score_bump(badge if is_instance_valid(badge) else lbl)


func set_quiz_turn_banner(text: String, col: Color = HudTheme.COL_TEXT_GOLD) -> void:
	show_turn_toast(text, col, false, 2.0)


func set_question_number(turn_num: int, total: int = 10) -> void:
	if is_instance_valid(lbl_round):
		lbl_round.text = "سوال %s از %s" % [_fa_digits(turn_num), _fa_digits(total)]
	if turn_num > 0:
		show_turn_toast("سوال %s از %s" % [_fa_digits(turn_num), _fa_digits(total)], HudTheme.COL_TEXT_GOLD, false, 1.6)


func reset_header() -> void:
	_local_answered_confirmed = false
	_quiz_scores = {1: 0, 2: 0, 3: 0, 4: 0}
	_surrendered_players = {1: false, 2: false, 3: false, 4: false}
	super.reset_header()
	clear_answered_states()
	update_quiz_scores(_quiz_scores)
	_apply_layout_for_player_count(_get_total_players())
