class_name UnoTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# UNO Multi-Player Top Header (Supports 2, 3, or 4 Players)
# Warm Classic Parlor compact layout displaying live hand counts (🃏۷) and UNO alerts (🔥 اونو!).

var _hand_counts: Array = [7, 7, 7, 7]
var _last_layout_players: int = -1


func _ready() -> void:
	super._ready()
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
			sc.text = "🃏%s" % _fa_digits(7)


func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)


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
			sc.add_theme_font_size_override("font_size", 18 if is_compact else 20)
			var sb := sc.get_parent() as PanelContainer
			if is_instance_valid(sb):
				sb.visible = true
				sb.custom_minimum_size = Vector2(46, 36) if is_compact else Vector2(52, 40)
		if is_player_disabled(idx):
			_apply_disabled_visual(idx)
	_apply_opponent_only_layout()


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

	update_uno_hands(_hand_counts, 0, 0)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	var total_players := _get_total_players()
	_apply_layout_for_player_count(total_players)
	if is_instance_valid(lbl_round):
		lbl_round.text = "%s (%s نفره)" % [game_name_fa, _fa_digits(total_players)]
	set_match_meta_text("🃏 اونو (%s نفره)" % _fa_digits(total_players))
	update_uno_hands(_hand_counts, 0, 0)


func update_uno_hands(hands_data: Variant, rank1: int = 0, rank2: int = 0) -> void:
	if typeof(hands_data) == TYPE_ARRAY:
		var arr: Array = hands_data
		if not arr.is_empty():
			_hand_counts = arr.duplicate()
	elif typeof(hands_data) == TYPE_DICTIONARY:
		var d: Dictionary = hands_data
		if not d.is_empty():
			for i in [1, 2, 3, 4]:
				if d.has(str(i)):
					_hand_counts[i - 1] = int(d[str(i)])
				elif d.has(i):
					_hand_counts[i - 1] = int(d[i])
	var total_players := _get_total_players()
	if total_players != _last_layout_players:
		_apply_layout_for_player_count(total_players)

	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var lbl: Label = b.get("score", null)
		var cnt := int(_hand_counts[idx - 1]) if idx - 1 < _hand_counts.size() else 7
		var badge_str := "👑" if (rank1 == idx or cnt == 0) else ("🥈" if rank2 == idx else ("🔥۱" if cnt == 1 else "🃏%s" % _fa_digits(cnt)))
		if is_instance_valid(lbl):
			lbl.text = badge_str
		update_player_counter(idx, badge_str)
		if not is_player_disabled(idx):
			_set_role_badge(idx, "🔥 اونو!" if cnt == 1 else "", HudTheme.COL_DANGER if cnt == 1 else Color(-1, -1, -1))


func update_scores(_p1_score: int, _p2_score: int) -> void:
	update_uno_hands(_hand_counts, 0, 0)


func reset_header() -> void:
	super.reset_header()
	_hand_counts = [7, 7, 7, 7]
	update_uno_hands(_hand_counts, 0, 0)


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	super.update_turn(turn, my_idx, p1_n, p2_n)

	if not GameManager.is_game_active or turn <= 0:
		hide_turn_toast()
	elif turn == my_idx:
		show_turn_toast("🃏 نوبت شماست!", HudTheme.COL_TEXT_GOLD, false, 1.7)
	else:
		var t_name := str(_player_names.get(turn, "بازیکن %d" % turn))
		show_turn_toast("نوبت %s" % t_name, HudTheme.COL_TEXT_SAND, false, 1.5)


func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	super.update_timer(remaining_sec, total_sec, turn)
