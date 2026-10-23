class_name BaseGameBoard
extends Node3D

# BaseGameBoard
# Abstract base class for all Cafe Fekr 3D game boards (TicTacToe, Chess, Checkers, Backgammon, etc.)
# Mirrors BaseGameController from Flutter:
# Standardizes network command handling, turn management, physical interaction,
# move dispatching, board state synchronization, and round lifecycle.

signal invalid_move_attempted(reason: String)
signal move_played(move_data: Dictionary)
signal round_completed(winner_id: int, extra: Dictionary)

@export var game_type: String = GameTypes.TIC_TAC_TOE

var is_board_locked: bool = false
var is_my_turn: bool = false
var current_turn: int = 1
var my_player_index: int = 1

func _enter_tree() -> void:
	_connect_network_signals()

func _ready() -> void:
	sync_turn_state()

func _exit_tree() -> void:
	_disconnect_network_signals()
	cleanup_board()

func sync_turn_state() -> void:
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	if not GameManager.is_game_active:
		is_my_turn = false
		is_board_locked = true
		if game_type == GameTypes.FEKRBEKR:
			on_turn_changed(0, true)
		return
	if game_type == GameTypes.FEKRBEKR:
		is_my_turn = true
		is_board_locked = false
		on_turn_changed(current_turn, true)
		return
	is_my_turn = (current_turn == my_player_index)
	is_board_locked = not is_my_turn
	on_turn_changed(current_turn, is_my_turn)

# --- Network Signal Wiring ---

func _connect_network_signals() -> void:
	if not NetworkManager.turn_changed.is_connected(_on_internal_turn_changed):
		NetworkManager.turn_changed.connect(_on_internal_turn_changed)
	if not NetworkManager.piece_selected.is_connected(_on_internal_piece_selected):
		NetworkManager.piece_selected.connect(_on_internal_piece_selected)
	if not NetworkManager.round_finished.is_connected(_on_internal_round_finished):
		NetworkManager.round_finished.connect(_on_internal_round_finished)
	if not NetworkManager.new_round_started.is_connected(_on_internal_new_round):
		NetworkManager.new_round_started.connect(_on_internal_new_round)
	if not NetworkManager.game_finished.is_connected(_on_internal_game_finished):
		NetworkManager.game_finished.connect(_on_internal_game_finished)
	if not NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.connect(_on_internal_reconnect_data)
	if not NetworkManager.game_data_received.is_connected(_on_internal_game_data):
		NetworkManager.game_data_received.connect(_on_internal_game_data)
	if not NetworkManager.wait_time_received.is_connected(_on_internal_wait_time):
		NetworkManager.wait_time_received.connect(_on_internal_wait_time)
	if not NetworkManager.start_game_received.is_connected(_on_internal_start_game):
		NetworkManager.start_game_received.connect(_on_internal_start_game)

func _disconnect_network_signals() -> void:
	if NetworkManager.turn_changed.is_connected(_on_internal_turn_changed):
		NetworkManager.turn_changed.disconnect(_on_internal_turn_changed)
	if NetworkManager.piece_selected.is_connected(_on_internal_piece_selected):
		NetworkManager.piece_selected.disconnect(_on_internal_piece_selected)
	if NetworkManager.round_finished.is_connected(_on_internal_round_finished):
		NetworkManager.round_finished.disconnect(_on_internal_round_finished)
	if NetworkManager.new_round_started.is_connected(_on_internal_new_round):
		NetworkManager.new_round_started.disconnect(_on_internal_new_round)
	if NetworkManager.game_finished.is_connected(_on_internal_game_finished):
		NetworkManager.game_finished.disconnect(_on_internal_game_finished)
	if NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)
	if NetworkManager.game_data_received.is_connected(_on_internal_game_data):
		NetworkManager.game_data_received.disconnect(_on_internal_game_data)
	if NetworkManager.wait_time_received.is_connected(_on_internal_wait_time):
		NetworkManager.wait_time_received.disconnect(_on_internal_wait_time)
	if NetworkManager.start_game_received.is_connected(_on_internal_start_game):
		NetworkManager.start_game_received.disconnect(_on_internal_start_game)

# --- Internal Network Callbacks (Dispatches to Virtual Hooks) ---

func _on_internal_turn_changed(turn: int) -> void:
	current_turn = turn
	my_player_index = GameManager.my_player_index
	if game_type == GameTypes.FEKRBEKR:
		is_my_turn = true
		is_board_locked = false
		on_turn_changed(turn, true)
		return
	is_my_turn = (turn == my_player_index)
	is_board_locked = false
	on_turn_changed(turn, is_my_turn)

func _on_internal_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	on_piece_selected(user_id, target_peace, extra)

func _on_internal_round_finished(payload: Variant) -> void:
	set_board_locked(true)
	on_round_finished(payload)

func _on_internal_new_round(round_num: int) -> void:
	reset_board()
	on_new_round(round_num)

func _on_internal_game_finished(_data: Dictionary) -> void:
	set_board_locked(true)

func _on_internal_reconnect_data(payload: Dictionary) -> void:
	GameManager.is_game_active = true
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY and g_data.has("current_turn"):
		current_turn = int(g_data["current_turn"])
		GameManager.current_turn = current_turn
	else:
		current_turn = GameManager.current_turn
	if GameManager.current_game_type == GameTypes.FEKRBEKR:
		is_my_turn = true
		is_board_locked = false
	else:
		is_my_turn = (current_turn == my_player_index)
		is_board_locked = not is_my_turn
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board"):
			sync_board_state(g_data["board"])
		elif g_data.has("board_data"):
			sync_board_state(g_data["board_data"])
		elif g_data.has("peaces"):
			sync_board_state(g_data["peaces"])
	on_turn_changed(current_turn, is_my_turn)
	on_reconnect_data(payload)

func _on_internal_game_data(payload: Dictionary) -> void:
	setup_board(payload)

func _on_internal_start_game() -> void:
	on_start_game()

func _on_internal_wait_time(time_sec: int) -> void:
	on_wait_time(time_sec)

# --- Public Helper Methods ---

func set_board_locked(locked: bool) -> void:
	is_board_locked = locked

func send_move(command_id: String, payload: Variant) -> void:
	NetworkManager.send_game_command(command_id, payload)
	move_played.emit({"command": command_id, "data": payload})

func show_hint(message: String) -> void:
	invalid_move_attempted.emit(message)

# --- Virtual Methods to Override in Concrete Game Implementations ---

func setup_board(_game_data: Dictionary) -> void:
	pass

func on_start_game() -> void:
	pass

func on_wait_time(_time_sec: int) -> void:
	pass

func on_turn_changed(_turn: int, _is_me: bool) -> void:
	pass

func on_piece_selected(_user_id: int, _target_peace: int, _extra: Dictionary = {}) -> void:
	pass

func on_piece_swapped(_data: Dictionary) -> void:
	pass

func on_piece_removed(_data: Dictionary) -> void:
	pass

func on_round_finished(_payload: Variant) -> void:
	pass

func on_new_round(_round_num: int) -> void:
	pass

func on_reconnect_data(_payload: Dictionary) -> void:
	pass

func sync_board_state(_board_data: Variant) -> void:
	pass

func reset_board() -> void:
	pass

func cleanup_board() -> void:
	pass
