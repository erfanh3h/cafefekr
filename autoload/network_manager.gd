extends Node

# NetworkManager Autoload (Singleton)
signal game_match_found(game_id: String)
signal game_data_received(data: Dictionary)
signal game_play_data_received(data: Dictionary)
signal game_play_time_received(time: int)
signal game_play_navigate_received(data: Dictionary)
signal turn_changed(turn: int)
signal turn_data_received(payload: Dictionary)
signal roll_result_received(payload: Dictionary)
signal out_of_move_received(payload: Dictionary)
signal win_happened_received(payload: Dictionary)
signal piece_selected(user_id: int, target_peace: int, extra: Dictionary)
signal piece_swapped(data: Dictionary)
signal piece_removed(data: Dictionary)
signal select_remove_peace_received(remover_id: int)
signal round_finished(winner_id: Variant)
signal new_turn_round_received()
signal finish_turn_round_received(data: Dictionary)
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
signal start_game_data_received(payload: Dictionary)
signal wrong_solve_received()
signal select_peace_result_received(payload: Dictionary)
signal mine_selected_received(payload: Dictionary)
signal select_mine_correct_received(payload: Dictionary)
signal select_mine_wrong_received(payload: Dictionary)
signal player_score_received(payload: Dictionary)
signal classic_rank_match_ready(game_id: String, game_type: String)
signal queue_accept_game_received()
signal pre_game_started(pre_game_id: String, queuers: Array)
signal system_banned_games_received(banned_games: Array)
signal select_game_turn(active_user_id: String)
signal selected_game_received(active_index: int, game_type: String)
signal queue_game_canceled()
signal queue_game_finished()
signal queue_reconnect_data_received(data: Dictionary)
signal queue_start_game_received(game_id: String)
signal queue_user_disconnected(user_id: String, wait_time: int)
signal queue_user_reconnected(user_id: String, remaining_time: int)
signal ranked_locked_received(data: Dictionary)

var api: APIClient
var socket: SocketIOClient
var game_port: int = 5000
var api_port: int = 5001

var _reconnect_timer: Timer

# Automatically resolve the server host based on platform and user configuration
var server_host: String:
	get:
		var config = ConfigFile.new()
		if config.load("user://server.cfg") == OK and config.has_section_key("network", "host"):
			return str(config.get_value("network", "host"))
		if OS.get_name() == "Android":
			# Default host on Android, can be configured via user://server.cfg
			return "192.168.1.2"
		return "192.168.1.2"

var is_online: bool:
	get:
		return socket != null and socket.is_connected_to_server

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
	
	GameManager.user_logged_in.connect(func(_user_data):
		api.set_token(GameManager.token)
	)
	
	# Background reconnection timer
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = 4.0
	_reconnect_timer.one_shot = false
	_reconnect_timer.autostart = false
	add_child(_reconnect_timer)
	_reconnect_timer.timeout.connect(_on_reconnect_timeout)

func restore_session(callback: Callable) -> void:
	var saved_token = GameManager.load_saved_token()
	if saved_token.is_empty():
		if not is_online:
			callback.call(false, "OFFLINE")
		else:
			callback.call(false, "No saved session")
		return
	
	if GameManager.is_guest or saved_token.begins_with("guest_"):
		GameManager.logout()
		callback.call(false, "Guest session disabled")
		return

	api.set_token(saved_token)
	api.get_my_data(func(success: bool, response_code: int, data: Variant):
		if success and typeof(data) == TYPE_DICTIONARY and (data.has("result") or data.has("user_data")):
			var user_data = data.get("result", data.get("user_data", {}))
			GameManager.set_session(saved_token, user_data, true)
			print("[NetworkManager] Session restored successfully for %s" % GameManager.get_username())
			callback.call(true, "Restored")
		elif response_code == 401:
			print("[NetworkManager] Saved token invalid or expired (401).")
			GameManager.logout()
			callback.call(false, "Invalid token")
		else:
			print("[NetworkManager] Server unreachable or network error (%d). Preserving local session." % response_code)
			var cached_data = GameManager.load_saved_user_data()
			if not cached_data.is_empty():
				GameManager.token = saved_token
				GameManager.user_data = cached_data
				GameManager.is_logged_in = true
				callback.call(true, "Restored from local cache")
			else:
				callback.call(false, "OFFLINE")
	)

func fetch_server_config(callback: Callable = Callable()) -> void:
	api.get_config(func(success: bool, _response_code: int, data: Variant):
		if success and typeof(data) == TYPE_DICTIONARY:
			var cfg = data.get("result", data)
			if typeof(cfg) == TYPE_DICTIONARY:
				GameManager.server_config = cfg
				GameManager.is_queue_open = bool(cfg.get("is_queue_open", true))
				GameManager.latest_version = str(cfg.get("latest_version", ""))
				GameManager.allowed_version = str(cfg.get("allowed_version", ""))
				var app_ver = GameManager.get_app_version()
				if not GameManager.is_version_ok(app_ver, GameManager.allowed_version):
					GameManager.is_force_update_required = true
					print("[NetworkManager] App version %s is outdated! Allowed version is %s. Force update required." % [app_ver, GameManager.allowed_version])
				else:
					GameManager.is_force_update_required = false
					print("[NetworkManager] Server config loaded. Queue open: %s, Allowed ver: %s" % [GameManager.is_queue_open, GameManager.allowed_version])
		if callback.is_valid():
			callback.call(success, GameManager.server_config)
	)

func connect_to_game_server() -> void:
	socket.connect_to_host(server_host, game_port, false)
	if _reconnect_timer and _reconnect_timer.is_stopped():
		_reconnect_timer.start()

func disconnect_from_game_server() -> void:
	_reconnect_timer.stop()
	socket.disconnect_from_host()

func _on_reconnect_timeout() -> void:
	if not is_online:
		print("[NetworkManager] Attempting to reconnect to game backend (%s:%d)..." % [server_host, game_port])
		connect_to_game_server()

# --- QUEUE & MATCHMAKING ---

func join_matchmaking_queue(pre_game_id: Variant = null) -> void:
	var auth = {
		"token": GameManager.token,
		"pre_game_id": pre_game_id
	}
	socket.connect_namespace("/queue", auth)

func leave_matchmaking_queue() -> void:
	socket.disconnect_namespace("/queue")

func send_queue_command(command_id: String, data: Variant = null) -> void:
	var payload = {
		"id": command_id,
		"data": data
	}
	socket.emit_event("/queue", "user_command", payload)

func send_queue_accept() -> void:
	var payload = {
		"id": Commands.Accept,
		"user_id": GameManager.get_user_id()
	}
	print("[NetworkManager] Sending Accept to /queue: %s" % str(payload))
	socket.emit_event("/queue", "user_command", payload)

func send_queue_reject() -> void:
	var payload = {
		"id": Commands.Reject,
		"user_id": GameManager.get_user_id()
	}
	print("[NetworkManager] Sending Reject to /queue: %s" % str(payload))
	socket.emit_event("/queue", "user_command", payload)

func send_pre_game_select(pre_game_id: String, game_type: String) -> void:
	var payload = {
		"pre_game_id": pre_game_id,
		"id": Commands.Select_Game,
		"game_type": game_type
	}
	print("[NetworkManager] Sending Select_Game to /queue: %s" % str(payload))
	socket.emit_event("/queue", "user_command", payload)

# --- FRIENDLY LOBBY ---

func join_lobby(auth_data: Dictionary = {}) -> void:
	var auth = auth_data.duplicate()
	if not auth.has("token"):
		auth["token"] = GameManager.token
	socket.connect_namespace("/lobby", auth)

func leave_lobby() -> void:
	socket.disconnect_namespace("/lobby")

func send_lobby_command(command_id: String, data: Variant = null) -> void:
	var payload = {
		"id": command_id,
		"data": data
	}
	socket.emit_event("/lobby", "user_command", payload)

# --- CLASSIC RANK MATCHMAKING ---

func start_classic_rank(game_type: String) -> void:
	var auth = {
		"token": GameManager.token,
		"game_type": game_type,
		"username": GameManager.get_username(),
		"user_image": GameManager.get_avatar_id()
	}
	print("[NetworkManager] Requesting Classic Rank match for %s..." % game_type)
	socket.connect_namespace("/classic-rank", auth)

# --- IN-GAME SESSION ---

func join_active_game(game_id: String) -> void:
	GameManager.set_active_game(game_id)
	var auth = {
		"token": GameManager.token,
		"game_id": game_id
	}
	socket.connect_namespace("/game", auth)

func leave_active_game() -> void:
	GameManager.set_active_game("")
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

func send_select_mine(piece_data: Variant) -> void:
	print("[NetworkManager] Sending Select_Mine: %s" % str(piece_data))
	send_game_command(Commands.Select_Mine, piece_data)

func send_game_command(command_id: String, data: Variant = null) -> void:
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
	_reconnect_timer.stop()
	connection_status_changed.emit(true)
	# Auto-rejoin active game namespace if socket reconnected during ongoing match (takes priority!)
	var open_gid = GameManager.get_open_game_id()
	var act_gid = GameManager.active_game_id
	var target_game_id = act_gid if not act_gid.is_empty() else open_gid
	
	if GameManager.is_game_active or not target_game_id.is_empty():
		print("[NetworkManager] Game is already started (%s). Rejoining /game namespace..." % target_game_id)
		GameManager.clear_open_pre_game_id()
		join_active_game(target_game_id)
		return

	# Only rejoin /queue if we are truly still in pre-game draft!
	var open_pre_id = GameManager.get_open_pre_game_id()
	if not open_pre_id.is_empty():
		print("[NetworkManager] Socket reconnected during active pre-game draft (%s). Rejoining /queue..." % open_pre_id)
		join_matchmaking_queue(open_pre_id)

func _on_socket_disconnected() -> void:
	print("[NetworkManager] Disconnected from game backend.")
	connection_status_changed.emit(false)
	if _reconnect_timer.is_stopped():
		_reconnect_timer.start()

func _on_namespace_connected(ns: String) -> void:
	print("[NetworkManager] Namespace %s ready." % ns)
	if ns == "/game" and GameManager.is_game_active:
		print("[NetworkManager] Active game session detected upon /game connection. Actively requesting Reconnect_Data...")
		send_game_command("RequestReconnectData", {})

func _on_socket_event(ns: String, event_name: String, data: Variant) -> void:
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
			if ns == "/classic-rank":
				if typeof(payload) == TYPE_DICTIONARY and payload.has("game_id"):
					var c_gid = str(payload["game_id"])
					var c_gtype = str(payload.get("game_type", ""))
					socket.disconnect_namespace("/classic-rank")
					print("[NetworkManager] Classic Rank match found: %s (%s)" % [c_gid, c_gtype])
					classic_rank_match_ready.emit(c_gid, c_gtype)
				return
			if ns == "/queue":
				var g_id = ""
				if typeof(payload) == TYPE_DICTIONARY and payload.has("game_id"):
					g_id = str(payload["game_id"])
				print("[NetworkManager] Start_Game received on /queue with game_id: %s" % g_id)
				leave_matchmaking_queue()
				if not g_id.is_empty():
					GameManager.set_active_game(g_id)
				queue_start_game_received.emit(g_id)
				return
			if typeof(payload) == TYPE_DICTIONARY and payload.has("game_id"):
				var game_id = payload["game_id"]
				game_match_found.emit(game_id)
				leave_matchmaking_queue()
				join_active_game(game_id)
			else:
				print("[NetworkManager] Start_Game command received inside game session.")
				if typeof(payload) == TYPE_DICTIONARY:
					start_game_data_received.emit(payload)
				start_game_received.emit()

		Commands.Wait_Time:
			var w_time = int(payload) if typeof(payload) != TYPE_DICTIONARY else int(payload.get("time", 5))
			print("[NetworkManager] Wait_Time received: %d sec" % w_time)
			wait_time_received.emit(w_time)

		Commands.AcceptGame:
			print("[NetworkManager] Match Found! AcceptGame received on /queue.")
			queue_accept_game_received.emit()

		Commands.Start_Pre_Game:
			var pre_id = payload.get("id", "") if typeof(payload) == TYPE_DICTIONARY else ""
			var queuers = payload.get("queuers", []) if typeof(payload) == TYPE_DICTIONARY else []
			print("[NetworkManager] PreGame started: %s with %d players" % [pre_id, queuers.size()])
			pre_game_started.emit(pre_id, queuers)

		Commands.System_Banned_Games:
			var b_games = payload if typeof(payload) == TYPE_ARRAY else []
			print("[NetworkManager] System Banned Games: %s" % str(b_games))
			system_banned_games_received.emit(b_games)

		Commands.Select_Game:
			var active_uid = str(payload)
			print("[NetworkManager] PreGame Select_Game Turn for user: %s" % active_uid)
			select_game_turn.emit(active_uid)

		Commands.Selected_Game:
			var s_idx = int(payload.get("active_index", 0)) if typeof(payload) == TYPE_DICTIONARY else 0
			var s_gtype = str(payload.get("game_type", "")) if typeof(payload) == TYPE_DICTIONARY else ""
			print("[NetworkManager] PreGame Selected_Game: Turn %d -> %s" % [s_idx, s_gtype])
			selected_game_received.emit(s_idx, s_gtype)

		Commands.Game_Canceled:
			print("[NetworkManager] PreGame Game_Canceled received.")
			queue_game_canceled.emit()

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
				elif payload.has("current_turn"):
					turn = int(payload["current_turn"])
					GameManager.current_round = turn
				else:
					turn = int(payload.get("turn", 1))
			else:
				turn = int(payload)
			GameManager.current_turn = turn
			print("[NetworkManager] Current Turn/Round: %d | My Player Index: %d | Is My Turn: %s" % [turn, GameManager.my_player_index, str(GameManager.is_my_turn)])
			if typeof(payload) == TYPE_DICTIONARY:
				turn_data_received.emit(payload)
			turn_changed.emit(turn)

		Commands.Roll_Result:
			roll_result_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})

		Commands.Out_Of_Move:
			out_of_move_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})

		Commands.Win_Happened:
			win_happened_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {"Winner": payload})

		Commands.Peace_Selected:
			if typeof(payload) == TYPE_DICTIONARY:
				if payload.has("player1_score") and payload.has("player2_score"):
					GameManager.p1_score = int(payload["player1_score"])
					GameManager.p2_score = int(payload["player2_score"])
				var user_id = int(payload.get("gamer_id", payload.get("user", 0)))
				var target_peace = int(payload.get("target_peace", payload.get("selected_index", payload.get("index", 0))))
				var extra: Dictionary = payload.duplicate()
				if payload.has("select_data") and typeof(payload["select_data"]) == TYPE_DICTIONARY:
					var sdata = payload["select_data"]
					user_id = int(sdata.get("gamer_id", user_id))
					if sdata.has("index"):
						target_peace = int(sdata.get("index", target_peace))
					for k in sdata.keys():
						extra[k] = sdata[k]
					var tc = int(sdata.get("t_c_index", -1))
					var tr = int(sdata.get("t_r_index", -1))
					if tc != -1 and tr != -1:
						target_peace = tc * 8 + tr
					elif sdata.has("c_index") and sdata.has("r_index"):
						var ci = int(sdata.get("c_index", -1))
						var ri = int(sdata.get("r_index", -1))
						if ci != -1 and ri != -1:
							target_peace = ci * 8 + ri
				piece_selected.emit(user_id, target_peace, extra)

		Commands.Peace_Swaped:
			if typeof(payload) == TYPE_DICTIONARY:
				piece_swapped.emit(payload)

		Commands.Peace_Removed:
			if typeof(payload) == TYPE_DICTIONARY:
				piece_removed.emit(payload)

		Commands.Select_Remove_Peace:
			var rem_id = int(payload) if typeof(payload) != TYPE_DICTIONARY else int(payload.get("remover_id", payload.get("user", 1)))
			select_remove_peace_received.emit(rem_id)

		Commands.New_Turn_Round:
			print("[NetworkManager] New Turn-Round started")
			new_turn_round_received.emit()

		Commands.Finish_Turn_Round:
			print("[NetworkManager] Finish Turn-Round: %s" % str(payload))
			finish_turn_round_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})

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
			print("[NetworkManager] Player %d missed turn (Count: %d/2)" % [g_id, cnt])
			not_played_turns_received.emit(g_id, cnt)

		Commands.Finish_Game:
			game_finished.emit(payload if typeof(payload) == TYPE_DICTIONARY else {"winner": payload})

		Commands.Game_Finished:
			if ns == "/queue":
				print("[NetworkManager] Game_Finished received on /queue namespace.")
				queue_game_finished.emit()
			game_finished.emit(payload if typeof(payload) == TYPE_DICTIONARY else {"winner": payload})

		Commands.User_Disconnected:
			var u_id = str(payload.get("user_id", "")) if typeof(payload) == TYPE_DICTIONARY else str(payload)
			if ns == "/queue":
				var w_time_q = int(payload.get("time", 60)) if typeof(payload) == TYPE_DICTIONARY else 60
				print("[NetworkManager] PreGame User_Disconnected: %s (Wait Time: %d)" % [u_id, w_time_q])
				queue_user_disconnected.emit(u_id, w_time_q)
				return
			var w_time = int(payload.get("time", 60)) if typeof(payload) == TYPE_DICTIONARY else 60
			print("[NetworkManager] User disconnected: %s (Wait Time: %d)" % [u_id, w_time])
			user_disconnected.emit(u_id, w_time)

		Commands.User_Reconnected:
			var u_id = str(payload.get("user_id", "")) if typeof(payload) == TYPE_DICTIONARY else str(payload)
			if ns == "/queue":
				var r_time_q = int(payload.get("time", 20)) if typeof(payload) == TYPE_DICTIONARY else 20
				print("[NetworkManager] PreGame User_Reconnected: %s (Resume Time: %d)" % [u_id, r_time_q])
				queue_user_reconnected.emit(u_id, r_time_q)
				return
			var r_time = int(payload.get("time", 10)) if typeof(payload) == TYPE_DICTIONARY else 10
			print("[NetworkManager] User reconnected: %s (Resume Time: %d)" % [u_id, r_time])
			user_reconnected.emit(u_id, r_time)

		Commands.Reconnect_Data:
			if ns == "/queue":
				print("[NetworkManager] PreGame Reconnect_Data received: %s" % str(payload))
				if typeof(payload) == TYPE_DICTIONARY:
					queue_reconnect_data_received.emit(payload)
				return
			print("[NetworkManager] Received Reconnect_Data: %s" % str(payload))
			if typeof(payload) == TYPE_DICTIONARY:
				GameManager.is_game_active = true
				if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
					GameManager.set_match_gamers(payload["gamers"])
				var g_data = payload.get("game_data", {})
				if typeof(g_data) == TYPE_DICTIONARY:
					if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
						GameManager.p1_score = int(g_data["scores"][0])
						GameManager.p2_score = int(g_data["scores"][1])
					if g_data.has("current_turn"):
						var turn = int(g_data["current_turn"])
						if g_data.has("is_play_phase") and not bool(g_data["is_play_phase"]):
							turn = 0
						GameManager.current_turn = turn
						print("[NetworkManager] Reconnect Current Turn: %d | My Index: %d | Is My Turn: %s" % [turn, GameManager.my_player_index, str(GameManager.is_my_turn)])
						turn_changed.emit(turn)
					elif g_data.has("current_round"):
						var r_num = int(g_data["current_round"])
						GameManager.current_round = max(1, r_num)
						GameManager.current_turn = max(1, r_num)
				reconnect_data_received.emit(payload)

		Commands.Finish_Reconnect_Time:
			var u_id = payload.get("user_id", "") if typeof(payload) == TYPE_DICTIONARY else str(payload)
			print("[NetworkManager] Opponent reconnect time expired: %s" % u_id)
			finish_reconnect_time_received.emit(u_id)

		Commands.Reaction:
			reaction_received.emit(payload)

		Commands.Wrong_Solve:
			print("[NetworkManager] Wrong_Solve received!")
			wrong_solve_received.emit()
		Commands.Select_Peace_Result:
			select_peace_result_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})
		Commands.Mine_Selected:
			mine_selected_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})
		Commands.Select_Mine_Correct:
			select_mine_correct_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})
		Commands.Select_Mine_Wrong:
			select_mine_wrong_received.emit(payload if typeof(payload) == TYPE_DICTIONARY else {})
		Commands.Player_Score:
			if typeof(payload) == TYPE_DICTIONARY:
				var g_id = int(payload.get("gamer_id", 0))
				var s_val = int(payload.get("value", 0))
				if g_id == 1:
					GameManager.p1_score = s_val
				elif g_id == 2:
					GameManager.p2_score = s_val
				player_score_received.emit(payload)
		Commands.Rank_Locked:
			print("[NetworkManager] Rank_Locked received from server!")
			var r_data = payload if typeof(payload) == TYPE_DICTIONARY else {}
			ranked_locked_received.emit(r_data)
		Commands.Logout:
			GameManager.logout()
