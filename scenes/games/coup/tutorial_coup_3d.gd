class_name TutorialCoup3D
extends "res://scenes/games/coup/coup_3d.gd"

## Offline interactive Coup 3D board for the Library tutorial.

signal tutorial_action_chosen(action_name: String)
signal tutorial_reaction_chosen(cmd: String, detail: String)

var tutorial_input_enabled: bool = false


func _ready() -> void:
	super._ready()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	setup_tutorial_coup_state()


func _connect_coup_signals() -> void:
	pass


func _disconnect_coup_signals() -> void:
	pass


func setup_tutorial_coup_state() -> void:
	_apply_coup_state_dict({
		"players_count": 2,
		"phase": "action",
		"current_turn": 1,
		"deck_remaining": 11,
		"my_cards": [
			{"role": "duke", "revealed": false},
			{"role": "assassin", "revealed": false}
		],
		"players": [
			{"gamer_id": 1, "coins": 4, "cards_count": 2, "alive": true, "dead_cards": []},
			{"gamer_id": 2, "coins": 2, "cards_count": 2, "alive": true, "dead_cards": []}
		]
	})
	is_my_turn = true
	is_board_locked = false


func _is_my_response_needed() -> bool:
	if phase not in ["challenge_action", "block_action", "challenge_block"]:
		return false
	if not eligible_responders.has(my_player_index):
		return false
	if passed_players.has(my_player_index):
		return false
	return true


func trigger_enemy_bluff_duke() -> void:
	_apply_coup_state_dict({
		"phase": "challenge_action",
		"current_turn": 2,
		"pending_action": "tax",
		"pending_actor": 2,
		"pending_target": 0,
		"pending_claimed_role": "duke",
		"eligible_responders": [1],
		"passed_players": []
	})
	is_my_turn = false
	set_board_locked(false)


func trigger_enemy_assassinate() -> void:
	_apply_coup_state_dict({
		"phase": "block_action",
		"current_turn": 2,
		"pending_action": "assassinate",
		"pending_actor": 2,
		"pending_target": 1,
		"pending_claimed_role": "assassin",
		"eligible_responders": [1],
		"passed_players": []
	})
	is_my_turn = false
	set_board_locked(false)


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id in [Commands.Coup_Challenge, Commands.Coup_Block, Commands.Coup_Pass]:
		var detail: String = ""
		if typeof(payload) == TYPE_DICTIONARY:
			detail = str((payload as Dictionary).get("block_role", ""))
		_apply_coup_state_dict({
			"phase": "action",
			"current_turn": 1,
			"pending_action": "",
			"pending_claimed_role": "",
			"eligible_responders": [],
			"passed_players": []
		})
		is_my_turn = true
		set_board_locked(false)
		tutorial_reaction_chosen.emit(command_id, detail)
		return
	var act: String = ""
	if typeof(payload) == TYPE_DICTIONARY:
		act = str((payload as Dictionary).get("action", command_id))
	else:
		act = command_id

	var my_coins: int = _get_my_coins()
	if act == "tax":
		my_coins += 3
	elif act == "income":
		my_coins += 1
	elif act == "foreign_aid":
		my_coins += 2
	elif act == "steal":
		my_coins += 2
	elif act == "assassinate":
		my_coins = maxi(0, my_coins - 3)
	elif act == "coup":
		my_coins = maxi(0, my_coins - 7)

	_apply_coup_state_dict({
		"phase": "action",
		"current_turn": 1,
		"players": [
			{"gamer_id": 1, "coins": my_coins, "cards_count": 2, "alive": true, "dead_cards": []},
			{"gamer_id": 2, "coins": 2, "cards_count": 2, "alive": true, "dead_cards": []}
		]
	})
	is_my_turn = true
	set_board_locked(false)
	tutorial_action_chosen.emit(act)


func get_action_button_matching(keywords: Array[String]) -> Control:
	if not is_instance_valid(actions_container):
		return bottom_dock
	var found: Control = _find_btn_with_text(actions_container, keywords)
	return found if is_instance_valid(found) else bottom_dock


func _find_btn_with_text(node: Node, keywords: Array[String]) -> Control:
	if node is Button:
		var b: Button = node as Button
		if _node_contains_any_text(b, keywords):
			return b
	for ch in node.get_children():
		var res: Control = _find_btn_with_text(ch, keywords)
		if is_instance_valid(res):
			return res
	return null


func _node_contains_any_text(node: Node, keywords: Array[String]) -> bool:
	if node is Label:
		var t: String = (node as Label).text
		for kw in keywords:
			if kw in t:
				return true
	elif node is Button:
		var bt: String = (node as Button).text
		for kw in keywords:
			if kw in bt:
				return true
	for ch in node.get_children():
		if _node_contains_any_text(ch, keywords):
			return true
	return false


func get_actions_dock_control() -> Control:
	return bottom_dock


func get_my_cards_control() -> Control:
	return my_cards_hbox


func get_roles_button() -> Control:
	return rules_btn


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
