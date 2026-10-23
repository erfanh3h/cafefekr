extends Node

# NetworkManager Autoload (Singleton)

signal game_match_found(game_id: String)
signal game_data_received(data: Dictionary)
signal game_play_data_received(data: Dictionary)
signal game_play_time_received(time: int)
signal game_play_navigate_received(data: Dictionary)
signal turn_changed(turn: int)
signal piece_selected(user_id: int, target_peace: int, extra: Dictionary)
signal round_finished(winner_id: Variant)
signal new_round_started(round_num: int)
signal game_finished(data: Dictionary)
signal reaction_received(reaction_data: Variant)
signal player_surrendered(gamer_id: int)
signal user_disconnected(user_id: String, wait_time: int)
signal user_reconnected(user_id: String, remaining_time: int)
signal reconnect_data_received(data: Dictionary)
signal finish_reconnect_time_received(user_id: String)
signal connection_status_changed(connected: bool)
signal not_played_turns_received(gamer_id: int, count: int)
signal wait_time_received(time: int)
signal start_game_received()

var api: APIClient
var socket: SocketIOClient

var game_port: int = 5000
var api_port: int = 5001

# Automatically resolve the server host based on platform:
# - Android emulator uses 10.0.2.2 to reach the host machine's localhost
# - Windows (and other desktop) uses the local network IP
var server_host: String:
	get:
		if OS.get_name() == "Android":
			return "10.0.2.2"
		return "192.168.1.2"

func _ready() -> void:
	# Initialize REST API Client
	api = APIClient.new()
	api.set_base_url("http://%s:%d" % [server_host, api_port])
	add_child(api)
	
	# Initialize Socket.IO Client
	socket = SocketIOClient.new()
	add_child(socket)
	
	socket.connected_to_server.connect(_on_socket_connected)
	socket.disconnected_from_server.connect(_on_socket_disconnected)
	socket.namespace_connected.connect(_on_namespace_connected)
	socket.event_received.connect(_on_socket_event)
	
	GameManager.user_logged_in.connect(func(user_data):
		api.set_token(GameManager.token)
	)

func restore_session(callback: Callable) -> void:
	var saved_token = GameManager.load_saved_token()
	if saved_token.is_empty():
		callback.call(false, "No saved session")
		return
	
	api.set_token(saved_token)
	api.get_my_data(func(success: bool, response_code: int, data: Variant):
		if success and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var user_data = data["result"]
			GameManager.set_session(saved_token, user_data, false)
			print("[NetworkManager] Session restored successfully for %s" % GameManager.get_username())
			callback.call(true, "Restored")
		else:
			print("[NetworkManager] Saved token invalid or expired. Response code: %d" % response_code)
			GameManager.logout()
			callback.call(false, "Invalid token")
	)

func connect_to_game_server() -> void:
	socket.connect_to_host(server_host, game_port, false)

func disconnect_from_game_server() -> void:
	socket.disconnect_from_host()

# --- QUEUE & MATCHMAKING ---

func join_matchmaking_queue(pre_game_id: Variant = null) -> void:
	var auth = {
		"token": GameManager.token,
		"pre_game_id": pre_game_id
	}
	socket.connect_namespace("/queue", auth)

func leave_matchmaking_queue() -> void:
	socket.disconnect_namespace("/queue")

func accept_match(pre_game_id: String = "") -> void:
	var payload = {
		"id": Commands.Accept,
		"user_id": GameManager.get_user_id()
	}
	if not pre_game_id.is_empty():
		payload["pre_game_id"] = pre_game_id
	socket.emit_event("/queue", "user_command", payload)

# --- GAMEPLAY ---

func join_active_game(game_id: String) -> void:
	if GameManager.active_game_id == game_id and socket.connected_namespaces.has("/game") and socket.connected_namespaces["/game"]:
		print("[NetworkManager] Already connected to /game namespace for match: %s" % game_id)
		return
	GameManager.active_game_id = game_id
	var auth = {
		"token": GameManager.token,
		"game_id": game_id
	}
	socket.connect_namespace("/game", auth)

func leave_active_game() -> void:
	GameManager.active_game_id = ""
	GameManager.clear_open_game_id()
	socket.disconnect_namespace("/game")

func send_surrender() -> void:
	print("[NetworkManager] Sending Surrender command to server...")
	send_game_command(Commands.Surrender, {})

func send_save_board(board_data: Variant) -> void:
	print("[NetworkManager] Sending Save_Board: %s" % str(board_data))
	send_game_command(Commands.Save_Board, board_data)

func send_select_peace(piece_data: Variant) -> void:
	print("[NetworkManager] Sending Select_Peace: %s" % str(piece_data))
	send_game_command(Commands.Select_Peace, piece_data)

func send_game_command(command_id: String, data: Variant = null) -> void:
	# Format matches server: {"id": command_id, ...} or raw command
	var payload = {
		"id": command_id,
		"data": data
	}
	socket.emit_event("/game", "user_command", payload)

func send_game_reaction(reaction_id: Variant) -> void:
	socket.emit_event("/game", "user_reaction", reaction_id)

# --- SOCKET EVENT DISPATCHER ---

func _on_socket_connected() -> void:
	print("[NetworkManager] Connected to game backend!")
	connection_status_changed.emit(true)
	# Auto-rejoin active game namespace if socket reconnected during ongoing match
	if not GameManager.active_game_id.is_empty():
		print("[NetworkManager] Socket reconnected during active game (%s). Rejoining /game namespace..." % GameManager.active_game_id)
		join_active_game(GameManager.active_game_id)

func _on_socket_disconnected() -> void:
	print("[NetworkManager] Disconnected from game backend.")
	connection_status_changed.emit(false)

func _on_namespace_connected(ns: String) -> void:
	print("[NetworkManager] Namespace %s ready." % ns)

func _on_socket_event(ns: String, event_name: String, data: Variant) -> void:
	# Server emits: emit('command', {'id': command_id, 'data': ...})
	if event_name == "command" and typeof(data) == TYPE_DICTIONARY:
		var cmd_id = data.get("id", "")
		var payload = data.get("data", {})
		_handle_server_command(ns, cmd_id, payload)
	elif event_name == "reaction":
		print("[NetworkManager] Reaction received: %s" % str(data))
		reaction_received.emit(data)

func _handle_server_command(ns: String, cmd_id: String, payload: Variant) -> void:
	print("[NetworkManager] Command from %s: %s -> %s" % [ns, cmd_id, str(payload)])
	
	match cmd_id:
		Commands.Start_Game:
			# Match found in queue!
			if typeof(payload) == TYPE_DICTIONARY and payload.has("game_id"):
				var game_id = payload["game_id"]
				game_match_found.emit(game_id)
				leave_matchmaking_queue()
				join_active_game(game_id)
			else:
				print("[NetworkManager] Start_Game command received inside game session.")
				start_game_received.emit()

		Commands.Wait_Time:
			var w_time = int(payload) if typeof(payload) != TYPE_DICTIONARY else int(payload.get("time", 5))
			print("[NetworkManager] Wait_Time received: %d sec" % w_time)
			wait_time_received.emit(w_time)

		Commands.Game_Play_Data:
			if typeof(payload) == TYPE_DICTIONARY:
				if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
					GameManager.set_match_gamers(payload["gamers"])
				game_play_data_received.emit(payload)

		Commands.Game_Play_Time:
			var t_val = int(payload) if typeof(payload) != TYPE_DICTIONARY else int(payload.get("time", 5))
			game_play_time_received.emit(t_val)

		Commands.Game_Play_Navigate:
			game_play_navigate_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})

		Commands.Game_Data:
			if typeof(payload) == TYPE_DICTIONARY:
				if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
					GameManager.set_match_gamers(payload["gamers"])
				game_data_received.emit(payload)

		Commands.Current_Turn:
			var turn = 1
			if typeof(payload) == TYPE_DICTIONARY:
				if payload.has("current_round"):
					turn = int(payload["current_round"])
					GameManager.current_round = turn
				else:
					turn = int(payload.get("turn", 1))
			else:
				turn = int(payload)
			GameManager.current_turn = turn
			print("[NetworkManager] Current Turn/Round: %d | My Player Index: %d | Is My Turn: %s" % [turn, GameManager.my_player_index, str(GameManager.is_my_turn)])
			turn_changed.emit(turn)

		Commands.Peace_Selected:
			if typeof(payload) == TYPE_DICTIONARY:
				var user_id = int(payload.get("gamer_id", payload.get("user", 0)))
				var target_peace = int(payload.get("target_peace", 0))
				var extra: Dictionary = payload.duplicate()
				if payload.has("select_data") and typeof(payload["select_data"]) == TYPE_DICTIONARY:
					var sdata = payload["select_data"]
					user_id = int(sdata.get("gamer_id", user_id))
					for k in sdata.keys():
						extra[k] = sdata[k]
					var tc = int(sdata.get("t_c_index", -1))
					var tr = int(sdata.get("t_r_index", -1))
					if tc != -1 and tr != -1:
						target_peace = tc * 8 + tr
				piece_selected.emit(user_id, target_peace, extra)

		Commands.Finish_Round:
			round_finished.emit(payload)

		Commands.New_Round:
			var r_num = int(payload) if typeof(payload) != TYPE_DICTIONARY else int(payload.get("round", 1))
			new_round_started.emit(r_num)

		Commands.Surrender:
			var g_id = int(payload.get("gamer_id", 0)) if typeof(payload) == TYPE_DICTIONARY else int(payload)
			print("[NetworkManager] Player surrendered: %d" % g_id)
			player_surrendered.emit(g_id)

		Commands.Not_played_Turns:
			var g_id = int(payload.get("gamer_id", 0)) if typeof(payload) == TYPE_DICTIONARY else 0
			var cnt = int(payload.get("count", 0)) if typeof(payload) == TYPE_DICTIONARY else int(payload)
			print("[NetworkManager] Player %d missed turn (Count: %d/4)" % [g_id, cnt])
			not_played_turns_received.emit(g_id, cnt)

		Commands.Finish_Game:
			game_finished.emit(payload if typeof(payload) == TYPE_DICTIONARY else {"winner": payload})

		Commands.Game_Finished:
			game_finished.emit(payload if typeof(payload) == TYPE_DICTIONARY else {"winner": payload})

		Commands.User_Disconnected:
			var u_id = payload.get("user_id", "") if typeof(payload) == TYPE_DICTIONARY else ""
			var w_time = int(payload.get("time", 30)) if typeof(payload) == TYPE_DICTIONARY else 30
			print("[NetworkManager] User disconnected: %s (Wait Time: %d)" % [u_id, w_time])
			user_disconnected.emit(u_id, w_time)

		Commands.User_Reconnected:
			var u_id = payload.get("user_id", "") if typeof(payload) == TYPE_DICTIONARY else ""
			var r_time = int(payload.get("time", 10)) if typeof(payload) == TYPE_DICTIONARY else 10
			print("[NetworkManager] User reconnected: %s (Resume Time: %d)" % [u_id, r_time])
			user_reconnected.emit(u_id, r_time)

		Commands.Reconnect_Data:
			print("[NetworkManager] Received Reconnect_Data: %s" % str(payload))
			if typeof(payload) == TYPE_DICTIONARY:
				GameManager.is_game_active = true
				if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
					GameManager.set_match_gamers(payload["gamers"])
				var g_data = payload.get("game_data", {})
				if typeof(g_data) == TYPE_DICTIONARY and g_data.has("current_turn"):
					var turn = int(g_data["current_turn"])
					GameManager.current_turn = turn
					print("[NetworkManager] Reconnect Current Turn: %d | My Index: %d | Is My Turn: %s" % [turn, GameManager.my_player_index, str(GameManager.is_my_turn)])
					turn_changed.emit(turn)
				reconnect_data_received.emit(payload)

		Commands.Finish_Reconnect_Time:
			var u_id = payload.get("user_id", "") if typeof(payload) == TYPE_DICTIONARY else str(payload)
			print("[NetworkManager] Opponent reconnect time expired: %s" % u_id)
			finish_reconnect_time_received.emit(u_id)

		Commands.Reaction:
			reaction_received.emit(payload)

		Commands.Logout:
			GameManager.logout()
