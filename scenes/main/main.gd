extends Node

const GameRegistry = preload("res://scripts/games/game_registry.gd")

# Main Scene Controller
# Master coordinator for Cafe Fekr 3D:
# Integrates UserHeader, 1v1 Queue, Friendly Lobby, Multiplayer, Ranking, Store, Rules, Auth, and 3D In-Game table.

@onready var cafe_table = $CafeTableScene
@onready var ui_canvas = $CanvasLayer

# UI Components
@onready var user_header = $CanvasLayer/UserHeader
@onready var menu_container = $CanvasLayer/MenuContainer
@onready var logo_plate = $CanvasLayer/MenuContainer/CenterContent/LogoSection/LogoPlate

# Menu Cards
@onready var btn_ranked = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnRanked
@onready var btn_lobby = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnLobby

# Bottom Dock
@onready var btn_ranking = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnRanking
@onready var btn_rules = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnRules
@onready var btn_audio = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnAudio
@onready var btn_exit = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnExit
@onready var img_audio = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnAudio/VBox/Icon

# Dialogs
@onready var dialog_backdrop: ColorRect = $CanvasLayer/DialogBackdrop
@onready var login_dialog = $CanvasLayer/LoginDialog
@onready var queue_dialog = $CanvasLayer/QueueDialog
@onready var lobby_dialog = $CanvasLayer/LobbyDialog
@onready var ranking_dialog = $CanvasLayer/RankingDialog
@onready var store_dialog = $CanvasLayer/StoreDialog
@onready var rules_dialog = $CanvasLayer/RulesDialog
@onready var user_profile_dialog = $CanvasLayer/UserProfileDialog

# Base Game HUD
@onready var base_game_hud = $CanvasLayer/BaseGameHUD

var _sound_on_tex = preload("res://assets/icons/General/soundOn.png")
var _sound_off_tex = preload("res://assets/icons/General/soundOff.png")

func _ready() -> void:
	_setup_signals()
	_start_logo_animation()
	_setup_button_juice()
	_update_audio_button_visual()
	
	# Start in Menu Mode
	base_game_hud.visible = false
	menu_container.visible = true
	
	# Start theme background music
	AudioManager.play_theme_music()
	
	# Try to restore saved session
	NetworkManager.restore_session(func(restored: bool, _msg: String):
		user_header.update_ui()
		if not restored:
			login_dialog.open()
		else:
			_check_and_auto_enter_active_game()
	)
	
	# Connect to real-time game server (port 5000)
	NetworkManager.connect_to_game_server()

func _setup_signals() -> void:
	# Menu Button Connections (Only 2 central game buttons)
	btn_ranked.pressed.connect(_on_ranked_pressed)
	btn_lobby.pressed.connect(_on_lobby_pressed)
	
	btn_ranking.pressed.connect(_on_ranking_pressed)
	btn_rules.pressed.connect(_on_rules_pressed)
	btn_audio.pressed.connect(_on_audio_toggle)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	# Header events - tapping avatar image opens avatar list dialog directly
	user_header.store_requested.connect(_on_store_pressed)
	user_header.profile_requested.connect(_on_store_pressed)
	
	# Dialog events
	login_dialog.login_completed.connect(func():
		user_header.update_ui()
		_check_and_auto_enter_active_game()
		_hide_backdrop()
		_update_backdrop_state()
	)
	login_dialog.closed.connect(_update_backdrop_state)
	
	queue_dialog.match_ready.connect(func(gid, gtype = ""):
		_start_game_match(gid, gtype, "ranked")
	)
	queue_dialog.queue_cancelled.connect(func():
		_hide_backdrop()
	)
	lobby_dialog.match_ready.connect(func(gid, gtype = ""):
		_start_game_match(gid, gtype, "lobby")
	)
	lobby_dialog.closed.connect(_update_backdrop_state)
	ranking_dialog.closed.connect(_update_backdrop_state)
	store_dialog.closed.connect(_update_backdrop_state)
	rules_dialog.closed.connect(_update_backdrop_state)
	user_profile_dialog.closed.connect(_update_backdrop_state)
	
	if is_instance_valid(dialog_backdrop):
		dialog_backdrop.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if is_instance_valid(login_dialog) and login_dialog.visible:
					login_dialog.close()
				elif is_instance_valid(user_profile_dialog) and user_profile_dialog.visible:
					user_profile_dialog.close()
				elif is_instance_valid(rules_dialog) and rules_dialog.visible:
					rules_dialog.close()
				elif is_instance_valid(store_dialog) and store_dialog.visible:
					store_dialog.close()
				elif is_instance_valid(ranking_dialog) and ranking_dialog.visible:
					ranking_dialog.close()
				else:
					_hide_backdrop()
		)
	
	ranking_dialog.user_selected.connect(func(u_dict):
		user_profile_dialog.open_for_user(u_dict)
		_show_backdrop()
	)
	
	base_game_hud.leave_game_requested.connect(_on_leave_game_pressed)
	base_game_hud.surrender_requested.connect(_on_surrender_requested)
	base_game_hud.zoom_in_requested.connect(func():
		cafe_table.zoom_in()
	)
	base_game_hud.zoom_out_requested.connect(func():
		cafe_table.zoom_out()
	)
	base_game_hud.top_view_requested.connect(func():
		cafe_table.toggle_top_down_view()
	)
	base_game_hud.reset_camera_requested.connect(func():
		cafe_table.reset_camera_orbit()
	)
	cafe_table.camera_mode_changed.connect(func(is_top_down: bool):
		base_game_hud.set_camera_mode_indicator(is_top_down)
	)
	base_game_hud.start_countdown_finished.connect(_on_start_countdown_finished)
	base_game_hud.fekrbekr_submit_pressed.connect(func():
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("_on_hud_submit_pressed"):
			board._on_hud_submit_pressed()
	)
	base_game_hud.fekrbekr_clear_pressed.connect(func():
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("_on_hud_clear_pressed"):
			board._on_hud_clear_pressed()
	)
	base_game_hud.fekrbekr_opponent_view_pressed.connect(func():
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("_on_hud_opponent_pressed"):
			board._on_hud_opponent_pressed()
	)
	base_game_hud.fekrbekr_dual_view_pressed.connect(func():
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("_on_hud_dual_pressed"):
			board._on_hud_dual_pressed()
	)
	
	# NetworkManager Real-time Gameplay Event Connections
	NetworkManager.game_play_data_received.connect(_on_game_play_data_received)
	NetworkManager.game_play_time_received.connect(_on_game_play_time_received)
	NetworkManager.game_play_navigate_received.connect(_on_game_play_navigate_received)
	NetworkManager.game_data_received.connect(_on_game_data_received)
	NetworkManager.start_game_received.connect(_on_start_game_received)
	NetworkManager.wait_time_received.connect(_on_wait_time_received)
	NetworkManager.turn_changed.connect(_on_turn_changed)
	NetworkManager.reaction_received.connect(_on_reaction_received)
	NetworkManager.round_finished.connect(_on_round_finished)
	NetworkManager.new_round_started.connect(_on_new_round_started)
	NetworkManager.player_surrendered.connect(_on_player_surrendered)
	NetworkManager.game_finished.connect(_on_game_finished)
	NetworkManager.user_disconnected.connect(_on_user_disconnected)
	NetworkManager.user_reconnected.connect(_on_user_reconnected)
	NetworkManager.reconnect_data_received.connect(_on_reconnect_data_received)
	NetworkManager.finish_reconnect_time_received.connect(_on_finish_reconnect_time)
	NetworkManager.not_played_turns_received.connect(_on_not_played_turns_received)
	NetworkManager.connection_status_changed.connect(_on_connection_status_changed)

func _start_logo_animation() -> void:
	logo_plate.pivot_offset = logo_plate.size / 2.0
	var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(logo_plate, "scale", Vector2(1.05, 1.05), 1.8)
	tw.tween_property(logo_plate, "scale", Vector2(0.97, 0.97), 1.8)

func _setup_button_juice() -> void:
	var buttons = [btn_ranked, btn_lobby, btn_ranking, btn_rules, btn_audio, btn_exit]
	for b in buttons:
		ActionVFXManager.apply_button_juice(b, "tap_button")

func _on_ranked_pressed() -> void:
	AudioManager.sfx_button()
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	queue_dialog.start_queue()

func _on_lobby_pressed() -> void:
	AudioManager.sfx_button()
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	lobby_dialog.open()

func _on_ranking_pressed() -> void:
	AudioManager.sfx_button()
	_show_backdrop()
	ranking_dialog.open()

func _on_store_pressed() -> void:
	AudioManager.sfx_button()
	_show_backdrop()
	store_dialog.open()

func _on_rules_pressed() -> void:
	AudioManager.sfx_button()
	_show_backdrop()
	rules_dialog.open()

func _show_backdrop() -> void:
	if not is_instance_valid(dialog_backdrop):
		return
	if (is_instance_valid(base_game_hud) and base_game_hud.visible) or not GameManager.active_game_id.is_empty() or GameManager.is_game_active:
		_hide_backdrop()
		return
	dialog_backdrop.visible = true
	dialog_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

func _hide_backdrop() -> void:
	if is_instance_valid(dialog_backdrop):
		dialog_backdrop.visible = false
		dialog_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_backdrop_state() -> void:
	get_tree().create_timer(0.22).timeout.connect(func():
		if not is_instance_valid(dialog_backdrop):
			return
		if (is_instance_valid(base_game_hud) and base_game_hud.visible) or not GameManager.active_game_id.is_empty() or GameManager.is_game_active:
			_hide_backdrop()
			return
		var is_queue_active = is_instance_valid(queue_dialog) and queue_dialog.visible and queue_dialog.timer_active
		var is_open = func(dlg: Control) -> bool:
			return is_instance_valid(dlg) and dlg.visible and dlg.modulate.a > 0.05
			
		var any_open = is_queue_active or is_open.call(lobby_dialog) \
			or is_open.call(ranking_dialog) or is_open.call(store_dialog) \
			or is_open.call(rules_dialog) or is_open.call(login_dialog) \
			or is_open.call(user_profile_dialog)
			
		if any_open:
			_show_backdrop()
		else:
			_hide_backdrop()
	)

func _on_audio_toggle() -> void:
	var new_state = not AudioManager.is_music_enabled
	AudioManager.set_music_enabled(new_state)
	AudioManager.set_sound_enabled(new_state)
	AudioManager.sfx_tap()
	_update_audio_button_visual()

func _update_audio_button_visual() -> void:
	if AudioManager.is_music_enabled:
		img_audio.texture = _sound_on_tex
	else:
		img_audio.texture = _sound_off_tex

func _on_exit_pressed() -> void:
	AudioManager.sfx_button()
	get_tree().quit()

var current_match_mode: String = "lobby"

func _get_mode_title() -> String:
	return "بازی رقابتی" if current_match_mode == "ranked" else "لابی دوستانه"

func _start_game_match(game_id: String, requested_game_type: String = "", match_mode: String = "") -> void:
	if not match_mode.is_empty():
		current_match_mode = match_mode
	else:
		if current_match_mode.is_empty():
			current_match_mode = "lobby"
	if not requested_game_type.is_empty():
		GameManager.set_game_type(requested_game_type)
	elif GameManager.current_game_type.is_empty():
		GameManager.set_game_type(GameRegistry.DEFAULT_GAME_TYPE)
		
	var game_info = GameRegistry.get_game_info(GameManager.current_game_type)
	var game_name_fa = game_info.get("name_fa", "بازی")
	
	print("[Main] Match confirmed: %s (Game: %s / %s, Mode: %s). Spawning 3D table..." % [game_id, GameManager.current_game_type, game_name_fa, current_match_mode])
	GameManager.is_game_active = false
	GameManager.current_turn = 0
	GameManager.local_player_surrendered = false
	GameManager.opponent_player_surrendered = false
	_camera_hint_shown = false
	_pending_start_game = false
	_pending_turn = -1
	
	# Dismiss and clear all menu overlays and backdrops so nothing intercepts gameplay touch input
	_hide_backdrop()
	if is_instance_valid(queue_dialog):
		queue_dialog.visible = false
	if is_instance_valid(lobby_dialog):
		lobby_dialog.visible = false
	if is_instance_valid(ranking_dialog):
		ranking_dialog.visible = false
	if is_instance_valid(store_dialog):
		store_dialog.visible = false
	if is_instance_valid(rules_dialog):
		rules_dialog.visible = false
	if is_instance_valid(login_dialog):
		login_dialog.visible = false
	if is_instance_valid(user_profile_dialog):
		user_profile_dialog.visible = false

	menu_container.visible = false
	user_header.visible = false
	base_game_hud.visible = true
	base_game_hud.reset_for_new_match()
	base_game_hud.setup_match(game_name_fa, _get_mode_title())
	
	# Spawn 3D board onto the table through unified GameRegistry BEFORE joining namespace
	_spawn_board_for_game(GameManager.current_game_type)
	
	# Play in-game background music
	AudioManager.play_game_music()
	
	# Connect to real-time game server namespace
	NetworkManager.join_active_game(game_id)
	
	# Start pre-game countdown dialog! (Real game stays locked until server sends Start_Game / Current_Turn)
	base_game_hud.play_start_countdown(Callable(), 5)

func _spawn_board_for_game(game_type: String) -> void:
	var board_scene = GameRegistry.get_board_packed_scene(game_type)
	var board = cafe_table.spawn_board(board_scene)
	if board:
		if board.has_method("set_board_locked"):
			board.set_board_locked(true)
		if board.has_signal("invalid_move_attempted"):
			board.invalid_move_attempted.connect(func(hint_msg):
				base_game_hud.show_toast_hint(hint_msg)
			)
		if board.has_method("sync_turn_state"):
			board.sync_turn_state()

func _switch_active_game(new_game_type: String) -> void:
	print("[Main] Switching active game to: %s" % new_game_type)
	GameManager.set_game_type(new_game_type)
	_spawn_board_for_game(new_game_type)
	base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())

var _camera_hint_shown: bool = false
var _pending_start_game: bool = false
var _pending_turn: int = -1

func _on_start_game_received() -> void:
	print("[Main] Server Start_Game received!")
	var was_active = GameManager.is_game_active
	GameManager.is_game_active = true
	if not was_active:
		AudioManager.play_sound("bell")
	if not base_game_hud.is_start_overlay_dismissed:
		base_game_hud.force_dismiss_start_overlay(false)
	_activate_start_game()

func _activate_start_game() -> void:
	base_game_hud.force_dismiss_start_overlay(false)
	if GameManager.current_game_type == GameTypes.FEKRBEKR:
		base_game_hud.set_setup_phase()
	else:
		var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)
		base_game_hud.start_turn_timer(def_time)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board):
		if board.has_method("set_board_locked"):
			board.set_board_locked(false)
		if board.has_method("on_start_game"):
			board.on_start_game()
		if board.has_method("sync_turn_state"):
			board.sync_turn_state()

func _on_start_countdown_finished() -> void:
	print("[Main] Pre-game countdown dialog finished! Waiting for server game start...")
	if _pending_start_game:
		_pending_start_game = false
		GameManager.is_game_active = true
		_activate_start_game()
	if _pending_turn != -1:
		var t = _pending_turn
		_pending_turn = -1
		GameManager.is_game_active = true
		_on_turn_changed(t)

func _on_wait_time_received(wait_sec: int) -> void:
	print("[Main] Server Wait_Time received: %d sec" % wait_sec)
	base_game_hud.start_wait_timer(wait_sec)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("on_wait_time"):
		board.on_wait_time(wait_sec)

func _on_turn_changed(turn: int) -> void:
	# Current_Turn signal proves real game has begun on server
	var was_active = GameManager.is_game_active
	GameManager.is_game_active = true
	GameManager.current_turn = turn
	if not was_active:
		AudioManager.play_sound("bell")
	if not base_game_hud.is_start_overlay_dismissed:
		base_game_hud.force_dismiss_start_overlay(false)
	base_game_hud.update_turn(turn)
	
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
		board.sync_turn_state()
	
	var is_opp_turn = (turn != GameManager.my_player_index) if GameManager.current_game_type != GameTypes.FEKRBEKR else false
	if is_instance_valid(cafe_table):
		cafe_table.set_opponent_thinking(is_opp_turn)
	


func _on_reaction_received(data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		var p_id = int(data.get("playerId", 0))
		var r_id = int(data.get("reactionId", 1))
		base_game_hud.show_reaction(p_id, r_id)
		if p_id != GameManager.my_player_index and is_instance_valid(cafe_table):
			cafe_table.play_opponent_reaction()

func _on_round_finished(payload: Variant) -> void:
	if is_instance_valid(base_game_hud):
		base_game_hud.stop_round_timer()
	AudioManager.stop_sound("time")
	
	var winner = 0
	if typeof(payload) == TYPE_DICTIONARY:
		winner = int(payload.get("Winner", 0))
	else:
		winner = int(payload)
		
	if winner == 1:
		GameManager.p1_score += 1
	elif winner == 2:
		GameManager.p2_score += 1
		
	base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)
	# Wait for winning piece placement animation, drop sound, and laser strike to complete visibly before showing round finish banner
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(base_game_hud) and not base_game_hud.is_game_finished:
			base_game_hud.show_round_finish_banner(winner, GameManager.current_round, GameManager.p1_score, GameManager.p2_score)
	)

func _on_new_round_started(round_num: int) -> void:
	GameManager.current_round = round_num
	base_game_hud.set_round(round_num, GameManager.max_rounds)
	base_game_hud.hide_round_finish_banner()
	base_game_hud.show_toast_hint("🏁 راند %d آغاز شد!" % round_num)

func _on_game_play_data_received(payload: Dictionary) -> void:
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
		_update_table_opponent_avatar()
	if payload.has("games") and typeof(payload["games"]) == TYPE_ARRAY and not payload["games"].is_empty():
		var server_game_type = str(payload["games"][0])
		var norm = GameRegistry.normalize_type(server_game_type)
		if norm.to_lower() != GameManager.current_game_type.to_lower():
			_switch_active_game(norm)
	if not GameManager.is_game_active:
		base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		if not base_game_hud.is_countdown_running and not base_game_hud.is_start_overlay_dismissed:
			base_game_hud.play_start_countdown(Callable(), 5)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
		board.sync_turn_state()

func _on_game_play_time_received(time: int) -> void:
	if not base_game_hud.is_start_overlay_dismissed:
		base_game_hud.update_start_countdown_time(time)

func _on_game_data_received(payload: Dictionary) -> void:
	# Server sends Game_Data and then counts Start_Game_Time (5s) before starting the real game.
	# Keep GameManager.is_game_active = false and board locked during this pre-game delay!
	GameManager.is_game_active = false
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
		_update_table_opponent_avatar()
		base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
	
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board):
		if board.has_method("set_board_locked"):
			board.set_board_locked(true)
		if board.has_method("sync_turn_state"):
			board.sync_turn_state()
	
	base_game_hud.start_pre_game_countdown(5)
	if not base_game_hud.is_countdown_running and not base_game_hud.is_start_overlay_dismissed:
		base_game_hud.play_start_countdown(Callable(), 5)

func _on_game_play_navigate_received(payload: Dictionary) -> void:
	print("[Main] Server Game_Play_Navigate received: %s" % str(payload))

func _on_surrender_requested() -> void:
	print("[Main] User confirmed surrender. Sending command to backend...")
	GameManager.local_player_surrendered = true
	GameManager.opponent_player_surrendered = false
	NetworkManager.send_surrender()
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	_on_player_surrendered(GameManager.my_player_index)

func _on_player_surrendered(gamer_id: int) -> void:
	AudioManager.stop_sound("time")
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	if gamer_id == GameManager.my_player_index:
		GameManager.local_player_surrendered = true
		GameManager.opponent_player_surrendered = false
	elif gamer_id > 0:
		GameManager.opponent_player_surrendered = true
		GameManager.local_player_surrendered = false
	base_game_hud.show_surrender_notification(gamer_id)

func _on_not_played_turns_received(gamer_id: int, count: int) -> void:
	GameManager.update_gamer_not_played_turns(gamer_id, count)
	if is_instance_valid(base_game_hud):
		base_game_hud.update_not_played_turns(gamer_id, count)

func _on_game_finished(data: Dictionary) -> void:
	AudioManager.stop_sound("time")
	GameManager.is_game_active = false
	GameManager.clear_open_game_id()
	_hide_backdrop()
	var winner = data.get("winner", data.get("Winner", data.get("rank1", 0)))
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	base_game_hud.show_game_result(int(winner), GameManager.p1_score, GameManager.p2_score)

# Auto enters ongoing match if one is active on server when game starts or reconnects
func _check_and_auto_enter_active_game() -> void:
	var open_id = GameManager.get_open_game_id()
	if not open_id.is_empty():
		print("[Main] Active ongoing game session found on server: %s. Auto-joining..." % open_id)
		_start_game_match(open_id, "", current_match_mode if not current_match_mode.is_empty() else "lobby")

func _on_user_disconnected(user_id: String, wait_time: int) -> void:
	print("[Main] Opponent disconnected (%s). Pausing match for %d seconds..." % [user_id, wait_time])
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	base_game_hud.show_pause_dialog(wait_time)

func _on_user_reconnected(user_id: String, remaining_time: int) -> void:
	print("[Main] User reconnected (%s, remaining_time=%ds). Resuming match..." % [user_id, remaining_time])
	_pending_start_game = false
	_pending_turn = -1
	GameManager.is_game_active = true
	base_game_hud.hide_pause_dialog()
	base_game_hud.force_dismiss_start_overlay(false)
	base_game_hud.resume_timer_on_user_reconnected(remaining_time)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
		board.sync_turn_state()
	base_game_hud.resume_timer_on_user_reconnected(remaining_time)
	if str(user_id) != str(GameManager.get_user_id()):
		base_game_hud.show_toast_hint("✅ حریف مجدداً متصل شد! بازی از سر گرفته شد.")

func _on_reconnect_data_received(payload: Dictionary) -> void:
	print("[Main] Received Reconnect_Data from server. Restoring match state...")
	_pending_start_game = false
	_pending_turn = -1
	GameManager.is_game_active = true
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		var inferred_type = ""
		if g_data.has("is_play_phase") or g_data.has("player1_choices"):
			inferred_type = GameTypes.FEKRBEKR
		elif g_data.has("peaces"):
			inferred_type = GameTypes.CHESS
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 9:
			inferred_type = GameTypes.TIC_TAC_TOE
		if not inferred_type.is_empty() and inferred_type.to_lower() != GameManager.current_game_type.to_lower():
			_switch_active_game(inferred_type)
	base_game_hud.handle_reconnect_data(payload)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board):
		if typeof(g_data) == TYPE_DICTIONARY and board.has_method("sync_board_state"):
			if g_data.has("board"):
				board.sync_board_state(g_data["board"])
			elif g_data.has("board_data"):
				board.sync_board_state(g_data["board_data"])
			elif g_data.has("peaces"):
				board.sync_board_state(g_data["peaces"])
		if board.has_method("sync_turn_state"):
			board.sync_turn_state()
	base_game_hud.sync_reconnect_timer(payload)
	base_game_hud.call_deferred("sync_reconnect_timer", payload)

func _on_finish_reconnect_time(user_id: String) -> void:
	print("[Main] Opponent reconnect time expired for user: %s." % user_id)
	base_game_hud.hide_pause_dialog()
	base_game_hud.show_toast_hint("🏆 مهلت اتصال حریف به پایان رسید!")
	var my_idx = GameManager.my_player_index
	_on_game_finished({"winner": my_idx})

func _on_connection_status_changed(connected: bool) -> void:
	if not GameManager.active_game_id.is_empty():
		if not connected:
			base_game_hud.pause_turn_timer()
			base_game_hud.show_toast_hint("📡 اتصال اینترنت قطع شد! در حال تلاش برای اتصال مجدد...")
			var board = cafe_table.current_board_node
			if board and is_instance_valid(board) and board.has_method("set_board_locked"):
				board.set_board_locked(true)
		else:
			base_game_hud.show_toast_hint("📡 اینترنت متصل شد! در حال بازیابی مسابقه...")

func _on_leave_game_pressed() -> void:
	AudioManager.sfx_button()
	NetworkManager.leave_active_game()
	cafe_table.clear_board()
	cafe_table.reset_table_state()
	cafe_table.transition_to_menu_view(1.0)
	
	base_game_hud.reset_for_new_match()
	base_game_hud.visible = false
	user_header.visible = true
	menu_container.visible = true
	_hide_backdrop()
	
	GameManager.reset_match_state()
	AudioManager.play_theme_music()

func _update_table_opponent_avatar() -> void:
	if not is_instance_valid(cafe_table):
		return
	var opp_data = GameManager.get_opponent_player_data()
	var opp_av_id = int(opp_data.get("image", opp_data.get("user_image", 0)))
	cafe_table.update_opponent_avatar(opp_av_id)
