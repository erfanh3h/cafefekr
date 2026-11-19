class_name LudoTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Ludo Multi-Player Top Header (Supports 2, 3, or 4 Players)
# Warm Classic Parlor compact layout displaying each player's home token count (۰/۴ .. ۴/۴).

var _home_counts: Array = [0, 0, 0, 0]


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
			sc.text = "۰/۴"


func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)


func _apply_layout_for_player_count(total_players: int) -> void:
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
				sb.custom_minimum_size = Vector2(44, 36) if is_compact else Vector2(48, 40)
		if is_player_disabled(idx):
			_apply_disabled_visual(idx)


func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_my_player_index = my_idx
	var total_players := _get_total_players()
	_apply_layout_for_player_count(total_players)

	var d1 := GameManager.get_player_data_by_gamer_id(1) if total_players > 2 else p1_data
	var d2 := GameManager.get_player_data_by_gamer_id(2) if total_players > 2 else p2_data
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
		var p_data := GameManager.get_player_data_by_gamer_id(idx)
		var p_name := str(p_data.get("name", p_data.get("username", "بازیکن %d" % idx)))
		_player_names[idx] = p_name
		if is_instance_valid(info["name"]):
			info["name"].text = p_name
			HudTheme.configure_bidi_label(info["name"], true)
		var av_id := int(p_data.get("image", p_data.get("user_image", 0)))
		var p_fid := GameManager.get_player_frame_id(p_data)
		var tex := _get_cached_avatar(av_id)
		if is_instance_valid(info["avatar"]):
			if tex:
				info["avatar"].texture = tex
			var p_parent = info["avatar"].get_parent()
			CafeSocialTheme.apply_frame_to_container(p_parent if p_parent is Control else info["avatar"], info["avatar"], p_fid)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	var total_players := _get_total_players()
	_apply_layout_for_player_count(total_players)
	if is_instance_valid(lbl_round):
		lbl_round.text = "%s (%s نفره)" % [game_name_fa, _fa_digits(total_players)]


func update_home_counts(counts: Variant, rank1: Variant = 0, rank2: Variant = 0) -> void:
	var arr: Array = [0, 0, 0, 0]
	if typeof(counts) == TYPE_DICTIONARY:
		var d: Dictionary = counts
		for idx in [1, 2, 3, 4]:
			arr[idx - 1] = int(d.get(idx, d.get(str(idx), 0)))
	elif typeof(counts) == TYPE_ARRAY:
		var a: Array = counts
		for i in range(min(4, a.size())):
			arr[i] = int(a[i])
	var r1: int = int(rank1) if rank1 != null else 0
	var r2: int = int(rank2) if rank2 != null else 0
	update_ludo_home_counts(arr, r1, r2)


func update_ludo_home_counts(home_counts: Array, rank1: int = 0, rank2: int = 0) -> void:
	_home_counts = home_counts.duplicate()
	for idx in [1, 2, 3, 4]:
		var b := _get_player_card_bundle(idx)
		var lbl: Label = b.get("score", null)
		if not is_instance_valid(lbl):
			continue
		var cnt := int(home_counts[idx - 1]) if idx - 1 < home_counts.size() else 0
		if rank1 == idx:
			lbl.text = "👑"
		elif rank2 == idx:
			lbl.text = "🥈"
		else:
			lbl.text = "%s/۴" % _fa_digits(cnt)


func reset_header() -> void:
	super.reset_header()
	_home_counts = [0, 0, 0, 0]
	update_ludo_home_counts(_home_counts, 0, 0)
	_apply_layout_for_player_count(_get_total_players())


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_cached_timer_danger = -1
	_player_names[1] = p1_n
	_player_names[2] = p2_n

	_apply_layout_for_player_count(_get_total_players())
	_set_active_cards_visual([turn], false, true)

	if not GameManager.is_game_active or turn <= 0:
		hide_turn_toast()
	elif turn == my_idx:
		show_turn_toast("🎲 نوبت شماست! تاس بریزید", HudTheme.COL_TEXT_GOLD, false, 1.7)
	else:
		var t_name := str(_player_names.get(turn, "بازیکن %d" % turn))
		show_turn_toast("🎲 نوبت %s" % t_name, HudTheme.COL_TEXT_SAND, false, 1.5)


func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	_update_card_timer_visuals(remaining_sec, total_sec, [turn])
