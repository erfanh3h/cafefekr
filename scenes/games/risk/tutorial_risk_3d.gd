class_name TutorialRisk3D
extends "res://scenes/games/risk/risk_3d.gd"

## Offline interactive Risk Strike 3D board for the Library tutorial.
## Mirrors the full real-game Draw, Tactic, Attack (AttackerArmy -> Attack reroll/stop),
## Defense (DefenderArmy -> mid-battle Cancel/Canon), and Pass Turn flow.

signal tutorial_cards_drawn(draw_type: int)
signal tutorial_strategy_used(strat_name: String)
signal tutorial_attack_declared()
signal tutorial_attacker_committed(count: int)
signal tutorial_battle_resolved(conquered: bool)
signal tutorial_defender_committed(count: int, canceled: bool)
signal tutorial_defense_stopped()
signal tutorial_turn_passed()

var tutorial_input_enabled: bool = false


func _ready() -> void:
	super._ready()
	my_player_index = 1
	_active_turn = 1
	is_my_turn = true
	is_board_locked = false
	setup_tutorial_risk_state()


func _connect_signals() -> void:
	pass


func _exit_tree() -> void:
	super._exit_tree()


func setup_tutorial_risk_state() -> void:
	_match_started = true
	game_state = "Draw"
	_active_turn = 1
	_attacked_this_turn = false
	active_attack.clear()
	_sync_full_game_data({
		"current_turn": 1,
		"game_state": "Draw",
		"active_player_indexes": [1, 2],
		"continents": 30,
		"strategies": 28,
		"tokens": [0, 0, 0, 0, 0, 0],
		"players_data": [
			{"index": 1, "continents": {"Asia": 3, "Europe": 1, "Africa": 1}, "strategies_count": 9, "tokens": []},
			{"index": 2, "continents": {"Europe": 2, "NorthAmerica": 2, "Australia": 1}, "strategies_count": 3, "tokens": []}
		]
	})
	_sync_private_user_data({
		"index": 1,
		"continents": {"Asia": 3, "Europe": 1, "Africa": 1},
		"strategies": ["Army", "Army", "Backup", "Bomb", "Destroy", "Cancel", "Canon", "Expand", "Spy"],
		"tokens": []
	})
	is_my_turn = true
	is_board_locked = false
	_refresh_all_3d_and_hud()


func prepare_attack_scenario() -> void:
	# Ensure player holds source continents + Army + Canon cards for the full Attack scenario
	if _to_int(my_continents.get("Asia", 0)) < 3:
		my_continents["Asia"] = 3
	if _to_int(my_continents.get("Europe", 0)) < 1:
		my_continents["Europe"] = 1
	if _to_int(my_continents.get("Africa", 0)) < 1:
		my_continents["Africa"] = 1
	for needed: String in ["Army", "Canon"]:
		if needed not in my_strategies:
			my_strategies.append(needed)
	players_state[2] = {
		"continents": {"Europe": 2, "NorthAmerica": 2, "Australia": 1},
		"strategies_count": 3,
		"tokens": [],
	}
	_active_turn = 1
	_attacked_this_turn = false
	game_state = "SelectAction"
	selected_hand_card_idx = -1
	selected_source_continent = ""
	selected_target_continent = ""
	selected_strategy_name = ""
	_sync_private_user_data({
		"index": 1,
		"continents": my_continents.duplicate(true),
		"strategies": my_strategies.duplicate(),
		"tokens": my_tokens.duplicate(),
	})
	is_my_turn = true
	set_board_locked(false)
	_refresh_all_3d_and_hud()
	call_deferred("scroll_hand_to_continents")


func start_enemy_attack_scenario() -> void:
	# Ensure player holds defensive Army + Canon + Cancel cards for the interactive defense sequence
	for needed: String in ["Army", "Canon", "Cancel"]:
		if needed not in my_strategies:
			my_strategies.append(needed)
	if my_continents.get("Asia", 0) < 3:
		my_continents["Asia"] = 3
	var conts_copy: Dictionary = my_continents.duplicate(true)
	var strats_copy: Array[String] = my_strategies.duplicate()
	_active_turn = 2
	_attacked_this_turn = false
	selected_hand_card_idx = -1
	selected_source_continent = ""
	selected_target_continent = ""
	selected_strategy_name = ""
	selected_army_commit = 0
	game_state = "DefenderArmy"
	active_attack = {
		"attacker_id": 2,
		"defender_id": 1,
		"source_continent": "NorthAmerica",
		"target_continent": "Asia",
		"attacker_army": 1,
		"defender_army": 0,
		"attacker_canon_bonus": 0,
		"defender_canon_bonus": 0,
		"battle_started": false,
	}
	players_state[2] = {
		"continents": {"NorthAmerica": 3, "Australia": 1},
		"strategies_count": 2,
		"tokens": [],
	}
	_sync_private_user_data({
		"index": 1,
		"continents": conts_copy,
		"strategies": strats_copy,
		"tokens": my_tokens.duplicate(),
	})
	is_my_turn = false
	set_board_locked(false)
	_show_combat_toast("⚔️ دشمن (بازیکن ۲) از «آمریکای شمالی» به «آسیا» حمله کرد — نوبت دفاع شماست!", 3.2)
	_refresh_all_3d_and_hud()


func prepare_pass_turn_state() -> void:
	active_attack.clear()
	_active_turn = 1
	_attacked_this_turn = false
	game_state = "SelectAction"
	selected_hand_card_idx = -1
	selected_source_continent = ""
	selected_target_continent = ""
	selected_strategy_name = ""
	is_my_turn = true
	set_board_locked(false)
	_refresh_all_3d_and_hud()


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	var d: Dictionary = payload as Dictionary if typeof(payload) == TYPE_DICTIONARY else {}

	if command_id == Commands.Draw_Card:
		var dt: int = int(d.get("draw_type", 1))
		game_state = "SelectAction"
		var strats_copy: Array[String] = my_strategies.duplicate()
		if strats_copy.is_empty():
			strats_copy = ["Army", "Army", "Backup", "Bomb", "Destroy", "Cancel", "Canon", "Expand", "Spy"]
		_sync_private_user_data({
			"index": 1,
			"continents": {"Asia": 4, "Europe": 2, "Africa": 1},
			"strategies": strats_copy,
			"tokens": []
		})
		is_my_turn = true
		set_board_locked(false)
		_refresh_all_3d_and_hud()
		tutorial_cards_drawn.emit(dt)

	elif command_id == Commands.Use_Strategy:
		var strat: String = str(d.get("strategy", "Backup"))
		if strat in my_strategies:
			my_strategies.erase(strat)
		selected_strategy_name = ""
		selected_hand_card_idx = -1

		# Combat-time Canon (+1 to highest die) keeps combat active without advancing out of combat
		if strat == "Canon" and game_state in ["AttackerArmy", "DefenderArmy", "Attack"]:
			var atk_id: int = _to_int(active_attack.get("attacker_id", 1))
			var is_def: bool = (_to_int(active_attack.get("defender_id", 0)) == my_player_index)
			var bonus_key: String = "defender_canon_bonus" if is_def else "attacker_canon_bonus"
			active_attack[bonus_key] = 1
			var strats_c: Array[String] = my_strategies.duplicate()
			_sync_private_user_data({
				"index": 1,
				"continents": my_continents.duplicate(true),
				"strategies": strats_c,
				"tokens": my_tokens.duplicate()
			})
			_handle_strategy_result_payload({
				"gamer_id": my_player_index,
				"strategy": "Canon",
				"canon_role": "defender" if is_def else "attacker",
				bonus_key: 1,
				"game_state": game_state
			})
			is_my_turn = (atk_id == my_player_index and game_state != "DefenderArmy")
			set_board_locked(false)
			_refresh_all_3d_and_hud()
			return

		var conts_after: Dictionary = my_continents.duplicate(true)
		if strat in ["Backup", "Expand", "Army", "Spy"]:
			conts_after["Asia"] = _to_int(conts_after.get("Asia", 4)) + (2 if strat == "Backup" else 1)
		if strat == "Expand":
			expand_ignore_adjacency = true
		var strats_after: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": conts_after,
			"strategies": strats_after,
			"tokens": my_tokens.duplicate()
		})
		_handle_strategy_result_payload({
			"gamer_id": my_player_index,
			"strategy": strat,
			"target_index": 2,
			"target_continent": "Europe",
			"game_state": "SelectAction"
		})
		is_my_turn = true
		set_board_locked(false)
		_refresh_all_3d_and_hud()
		tutorial_strategy_used.emit(strat)

	elif command_id == Commands.Declare_Attack:
		var src_c: String = str(d.get("source_continent", "Asia"))
		var tgt_c: String = str(d.get("target_continent", "Europe"))
		game_state = "AttackerArmy"
		_attacked_this_turn = true
		selected_army_commit = 0
		active_attack = {
			"attacker_id": 1,
			"defender_id": 2,
			"source_continent": src_c,
			"target_continent": tgt_c,
			"attacker_army": 0,
			"defender_army": 0,
			"attacker_canon_bonus": _pending_attacker_canon_bonus,
			"defender_canon_bonus": 0,
			"battle_started": false,
		}
		is_my_turn = true
		set_board_locked(false)
		_refresh_all_3d_and_hud()
		tutorial_attack_declared.emit()

	elif command_id == Commands.AttackerArmy:
		var count: int = _to_int(d.get("count", 0))
		for _i: int in range(count):
			if "Army" in my_strategies:
				my_strategies.erase("Army")
		selected_army_commit = 0
		var src_c: String = str(active_attack.get("source_continent", "Asia"))
		var tgt_c: String = str(active_attack.get("target_continent", "Europe"))
		var my_c: Dictionary = my_continents.duplicate(true)
		var opp_c: Dictionary = (players_state.get(2, {}).get("continents", {}) as Dictionary).duplicate(true)
		# Round 1 combat: ties go to defender, 1 loss on defender continent!
		opp_c[tgt_c] = maxi(1, _to_int(opp_c.get(tgt_c, 2)) - 1)
		var my_s: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": my_c,
			"strategies": my_s,
			"tokens": my_tokens.duplicate()
		})
		_handle_combat_resolution_payload({
			"game_state": "Attack",
			"battle_continues": true,
			"attacker_id": 1,
			"defender_id": 2,
			"source_continent": src_c,
			"target_continent": tgt_c,
			"attacker_army": count,
			"defender_army": 0,
			"attacker_dice": [6, 5, 3],
			"defender_dice": [5, 2],
			"attacker_losses": 0,
			"defender_losses": 1,
			"attacker_canon_used": _to_int(active_attack.get("attacker_canon_bonus", 0)),
			"players_data": [
				{"index": 1, "continents": my_c, "strategies_count": my_s.size(), "tokens": my_tokens.duplicate()},
				{"index": 2, "continents": opp_c, "strategies_count": 3, "tokens": []}
			]
		})
		is_my_turn = true
		set_board_locked(false)
		tutorial_attacker_committed.emit(count)

	elif command_id == Commands.Attack:
		var src_c: String = str(active_attack.get("source_continent", "Asia"))
		var tgt_c: String = str(active_attack.get("target_continent", "Europe"))
		var my_c: Dictionary = my_continents.duplicate(true)
		var opp_c: Dictionary = (players_state.get(2, {}).get("continents", {}) as Dictionary).duplicate(true)
		opp_c.erase(tgt_c)
		my_c[tgt_c] = _to_int(my_c.get(tgt_c, 0)) + 1
		var my_s: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": my_c,
			"strategies": my_s,
			"tokens": my_tokens.duplicate()
		})
		_handle_combat_resolution_payload({
			"game_state": "SelectAction",
			"battle_continues": false,
			"conquered": true,
			"attacker_id": 1,
			"defender_id": 2,
			"source_continent": src_c,
			"target_continent": tgt_c,
			"attacker_dice": [6, 5, 4],
			"defender_dice": [3],
			"attacker_losses": 0,
			"defender_losses": 1,
			"attacker_canon_used": _to_int(active_attack.get("attacker_canon_bonus", 0)),
			"players_data": [
				{"index": 1, "continents": my_c, "strategies_count": my_s.size(), "tokens": my_tokens.duplicate()},
				{"index": 2, "continents": opp_c, "strategies_count": 3, "tokens": []}
			]
		})
		is_my_turn = true
		set_board_locked(false)
		tutorial_battle_resolved.emit(true)

	elif command_id == Commands.DefenderArmy:
		var is_cancel: bool = bool(d.get("cancel", false))
		var count: int = _to_int(d.get("count", 0))
		if is_cancel:
			if "Cancel" in my_strategies:
				my_strategies.erase("Cancel")
			var strats_c: Array[String] = my_strategies.duplicate()
			_sync_private_user_data({
				"index": 1,
				"continents": my_continents.duplicate(true),
				"strategies": strats_c,
				"tokens": my_tokens.duplicate()
			})
			_handle_combat_resolution_payload({
				"game_state": "SelectAction",
				"battle_continues": false,
				"canceled": true,
				"attacker_id": 2,
				"defender_id": 1,
				"source_continent": "NorthAmerica",
				"target_continent": "Asia",
			})
			_active_turn = 1
			is_my_turn = true
			set_board_locked(false)
			tutorial_defender_committed.emit(0, true)
			return

		for _i: int in range(count):
			if "Army" in my_strategies:
				my_strategies.erase("Army")
		selected_army_commit = 0
		var my_c: Dictionary = my_continents.duplicate(true)
		var opp_c: Dictionary = (players_state.get(2, {}).get("continents", {}) as Dictionary).duplicate(true)
		opp_c["NorthAmerica"] = maxi(1, _to_int(opp_c.get("NorthAmerica", 3)) - 1)
		var my_s: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": my_c,
			"strategies": my_s,
			"tokens": my_tokens.duplicate()
		})
		# Defender holds the tie (5 vs 5) + absorbs or wins Wave 1; Wave 2 continues!
		_handle_combat_resolution_payload({
			"game_state": "Attack",
			"battle_continues": true,
			"attacker_id": 2,
			"defender_id": 1,
			"source_continent": "NorthAmerica",
			"target_continent": "Asia",
			"attacker_army": 0,
			"defender_army": count,
			"attacker_dice": [5, 4, 2],
			"defender_dice": [5, 4],
			"attacker_losses": 2,
			"defender_losses": 0,
			"defender_canon_used": _to_int(active_attack.get("defender_canon_bonus", 0)),
			"players_data": [
				{"index": 1, "continents": my_c, "strategies_count": my_s.size(), "tokens": my_tokens.duplicate()},
				{"index": 2, "continents": opp_c, "strategies_count": 2, "tokens": []}
			]
		})
		is_my_turn = false
		set_board_locked(false)
		tutorial_defender_committed.emit(count, false)

	elif command_id == Commands.Cancel_Attack:
		var is_stop: bool = bool(d.get("stop", false))
		var def_id: int = _to_int(active_attack.get("defender_id", 2))
		if not is_stop and def_id == my_player_index:
			if "Cancel" in my_strategies:
				my_strategies.erase("Cancel")
			var my_s: Array[String] = my_strategies.duplicate()
			_sync_private_user_data({
				"index": 1,
				"continents": my_continents.duplicate(true),
				"strategies": my_s,
				"tokens": my_tokens.duplicate()
			})
			_handle_combat_resolution_payload({
				"game_state": "SelectAction",
				"battle_continues": false,
				"canceled": true,
				"attacker_id": 2,
				"defender_id": 1,
				"source_continent": "NorthAmerica",
				"target_continent": "Asia",
			})
			_active_turn = 1
			is_my_turn = true
			set_board_locked(false)
			tutorial_defense_stopped.emit()
		else:
			_handle_combat_resolution_payload({
				"game_state": "SelectAction",
				"battle_continues": false,
				"stopped": true,
				"attacker_id": 1,
				"defender_id": 2,
				"source_continent": str(active_attack.get("source_continent", "Asia")),
				"target_continent": str(active_attack.get("target_continent", "Europe")),
			})
			is_my_turn = true
			set_board_locked(false)
			tutorial_battle_resolved.emit(false)

	elif command_id == Commands.Pass_Turn:
		if "Expand" not in my_strategies:
			my_strategies.append("Expand")
		var my_s: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": my_continents.duplicate(true),
			"strategies": my_s,
			"tokens": my_tokens.duplicate()
		})
		_show_combat_toast("⏭️ نوبت پایان یافت (+۱ کارت استراتژی جایزه برای حمله نکردن!)", 2.8)
		is_my_turn = true
		set_board_locked(false)
		_refresh_all_3d_and_hud()
		tutorial_turn_passed.emit()


func get_hud_dock_control() -> Control:
	if is_instance_valid(_command_dock_panel):
		return _command_dock_panel
	return _hand_scroll_wrap if is_instance_valid(_hand_scroll_wrap) else _hud_root


func get_hand_strip_control() -> Control:
	return _hand_scroll_wrap if is_instance_valid(_hand_scroll_wrap) else _hand_cards_hbox


func get_action_row_control() -> Control:
	return _action_buttons_row if is_instance_valid(_action_buttons_row) else get_hud_dock_control()


func ensure_tactic_cards_visible() -> void:
	var required: Array[String] = ["Army", "Backup", "Bomb", "Destroy", "Cancel", "Canon", "Expand", "Spy"]
	var changed: bool = false
	for s_id in required:
		if s_id not in my_strategies:
			my_strategies.append(s_id)
			changed = true
	if game_state == "Draw":
		game_state = "SelectAction"
		changed = true
	if changed:
		var conts_copy: Dictionary = my_continents.duplicate(true)
		if conts_copy.is_empty():
			conts_copy = {"Asia": 4, "Europe": 2, "Africa": 1}
		var strats_copy: Array[String] = my_strategies.duplicate()
		_sync_private_user_data({
			"index": 1,
			"continents": conts_copy,
			"strategies": strats_copy,
			"tokens": []
		})
		is_my_turn = true
		set_board_locked(false)
		_refresh_all_3d_and_hud()
	call_deferred("scroll_hand_to_strategies")


func scroll_hand_to_continents() -> void:
	if is_instance_valid(_hand_scroll_wrap):
		_hand_scroll_wrap.scroll_horizontal = 0


func scroll_hand_to_strategies() -> void:
	if not is_instance_valid(_hand_scroll_wrap) or not is_instance_valid(_hand_cards_hbox):
		return
	for ch in _hand_cards_hbox.get_children():
		if ch is VSeparator:
			_hand_scroll_wrap.scroll_horizontal = maxi(0, int(ch.position.x) - 12)
			return
	var max_scroll: int = maxi(0, int(_hand_cards_hbox.size.x - _hand_scroll_wrap.size.x))
	_hand_scroll_wrap.scroll_horizontal = max_scroll


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
