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

var _splash_overlay: Control = null
var _splash_dismissed: bool = false

func _ready() -> void:
	_setup_signals()
	_start_logo_animation()
	_setup_button_juice()
	_update_audio_button_visual()
	
	# Start in Menu Mode
	base_game_hud.visible = false
	menu_container.visible = true
	
	# Display polished in-engine splash overlay matching boot splash screen
	_setup_splash_overlay()
	
	# Connect to real-time game server (port 5000)
	NetworkManager.connect_to_game_server()
	
	# Safety fallback timer: ensure splash always dismisses even if offline or slow server response
	get_tree().create_timer(2.6).timeout.connect(func():
		if not _splash_dismissed and is_instance_valid(self):
			_dismiss_splash_overlay()
	)
	
	# Try to restore saved session
	NetworkManager.restore_session(func(restored: bool, _msg: String):
		user_header.update_ui()
		# Allow at least 0.75s display so the splash transition feels smooth & deliberate
		get_tree().create_timer(0.75).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_dismiss_splash_overlay(func():
				if not restored:
					if not NetworkManager.is_online:
						NetworkManager.connect_to_game_server()
						_show_menu_toast("🔄 در حال تلاش برای اتصال مجدد به سرور بازی...")
					else:
						login_dialog.open()
						_show_backdrop()
				else:
					if GameManager.is_logged_in and not GameManager.is_guest and not GameManager.has_username():
						print("[Main] Returning user has phone but no username. Enforcing username registration.")
						login_dialog.open_for_username_completion()
						_show_backdrop()
						return
					_check_and_auto_enter_active_game()
			)
		)
	)

func _setup_splash_overlay() -> void:
	_splash_overlay = Control.new()
	_splash_overlay.name = "SplashOverlay"
	_splash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_splash_overlay.z_index = 100
	
	# Solid warm mahogany background matching project boot_splash (Color(0.12, 0.08, 0.05, 1))
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.08, 0.05, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_overlay.add_child(bg)
	
	# Center content
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	
	# Cafe Logo (280x280)
	var logo_rect = TextureRect.new()
	logo_rect.custom_minimum_size = Vector2(280, 280)
	logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.pivot_offset = Vector2(140, 140)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/icons/logo_432.png"):
		logo_rect.texture = load("res://assets/icons/logo_432.png")
	elif ResourceLoader.exists("res://assets/icons/logo.png"):
		logo_rect.texture = load("res://assets/icons/logo.png")
	vbox.add_child(logo_rect)
	
	# Subtle breathing scale loop
	var tw = logo_rect.create_tween().set_loops()
	tw.tween_property(logo_rect, "scale", Vector2(1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(logo_rect, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Persian App Title
	var title_lbl = Label.new()
	title_lbl.text = "کافه فِکـــر"
	title_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title_lbl.add_theme_constant_override("shadow_outline_size", 4)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	# Persian Subtitle
	var sub_lbl = Label.new()
	sub_lbl.text = "باشگاه بازی‌های فکری و دورهمی آنلاین"
	sub_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	sub_lbl.add_theme_font_size_override("font_size", 26)
	sub_lbl.add_theme_color_override("font_color", Color(0.88, 0.80, 0.68, 0.95))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)
	
	# Animated Loading Text / Dots
	var load_lbl = Label.new()
	load_lbl.text = "در حال ورود به کافه..."
	load_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	load_lbl.add_theme_font_size_override("font_size", 24)
	load_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 0.9))
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(load_lbl)
	
	var dot_step = 0
	var dot_timer = Timer.new()
	dot_timer.wait_time = 0.35
	dot_timer.autostart = true
	_splash_overlay.add_child(dot_timer)
	dot_timer.timeout.connect(func():
		if not is_instance_valid(load_lbl):
			return
		dot_step = (dot_step + 1) % 4
		var dots = ""
		for d in range(dot_step):
			dots += " ."
		load_lbl.text = "در حال ورود به کافه" + dots
	)
	
	$CanvasLayer.add_child(_splash_overlay)

func _dismiss_splash_overlay(callback: Callable = Callable()) -> void:
	if _splash_dismissed:
		if callback.is_valid():
			callback.call()
		return
	_splash_dismissed = true
	
	if not _splash_overlay or not is_instance_valid(_splash_overlay):
		AudioManager.play_theme_music()
		if callback.is_valid():
			callback.call()
		return
	
	# Music begins playing right as splash smoothly fades out!
	AudioManager.play_theme_music()
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_splash_overlay, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(_splash_overlay):
			_splash_overlay.queue_free()
			_splash_overlay = null
		if callback.is_valid():
			callback.call()
	)

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
		if GameManager.is_logged_in and not GameManager.is_guest and not GameManager.has_username():
			login_dialog.open_for_username_completion()
			_show_backdrop()
			return
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
					if login_dialog.is_mandatory_username:
						AudioManager.sfx_tap()
						_show_menu_toast("ثبت نام کاربری الزامی است.")
						return
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
	NetworkManager.new_turn_round_received.connect(_on_new_turn_round_received)
	NetworkManager.finish_turn_round_received.connect(_on_finish_turn_round_received)
	NetworkManager.new_round_started.connect(_on_new_round_started)
	NetworkManager.player_surrendered.connect(_on_player_surrendered)
	NetworkManager.game_finished.connect(_on_game_finished)
	NetworkManager.user_disconnected.connect(_on_user_disconnected)
	NetworkManager.user_reconnected.connect(_on_user_reconnected)
	NetworkManager.reconnect_data_received.connect(_on_reconnect_data_received)
	NetworkManager.finish_reconnect_time_received.connect(_on_finish_reconnect_time)
	NetworkManager.not_played_turns_received.connect(_on_not_played_turns_received)
	NetworkManager.select_remove_peace_received.connect(_on_select_remove_peace_received)
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
	if not NetworkManager.is_online:
		_hide_backdrop()
		NetworkManager.connect_to_game_server()
		_show_menu_toast("🔄 در حال تلاش برای اتصال مجدد به سرور بازی...")
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	if GameManager.is_guest or not GameManager.has_phone():
		login_dialog.open_for_phone_upgrade("برای شرکت در بازی رده‌بندی (رنک)، لطفاً ابتدا شماره موبایل خود را ثبت کنید.")
		return
	if not GameManager.has_username():
		login_dialog.open_for_username_completion()
		return
	queue_dialog.start_queue()

func _on_lobby_pressed() -> void:
	AudioManager.sfx_button()
	if not NetworkManager.is_online:
		_hide_backdrop()
		NetworkManager.connect_to_game_server()
		_show_menu_toast("🔄 در حال تلاش برای اتصال مجدد به سرور بازی...")
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	if GameManager.is_guest or not GameManager.has_phone():
		login_dialog.open_for_phone_upgrade("برای ورود به اتاق دوستانه (لابی)، لطفاً ابتدا شماره موبایل خود را ثبت کنید.")
		return
	if not GameManager.has_username():
		login_dialog.open_for_username_completion()
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
	_current_round_scored = false
	
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
var _current_round_scored: bool = false

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
	_current_round_scored = false
	var was_active = GameManager.is_game_active
	GameManager.is_game_active = true
	GameManager.current_turn = turn
	if not was_active:
		AudioManager.play_sound("bell")
	if not base_game_hud.is_start_overlay_dismissed:
		base_game_hud.force_dismiss_start_overlay(false)
	if GameManager.current_game_type == GameTypes.YATZY and turn > 0:
		GameManager.current_round = turn
		base_game_hud.set_round(turn, GameManager.max_rounds)
	base_game_hud.update_turn(turn)
	
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
		board.sync_turn_state()
	
	var is_opp_turn = (turn != GameManager.my_player_index) if not GameRegistry.is_simultaneous(GameManager.current_game_type) else false
	if is_instance_valid(cafe_table):
		cafe_table.set_opponent_thinking(is_opp_turn)
	


func _on_reaction_received(data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		var p_id = int(data.get("playerId", 0))
		var r_id = int(data.get("reactionId", 1))
		base_game_hud.show_reaction(p_id, r_id)
		if p_id != GameManager.my_player_index and is_instance_valid(cafe_table):
			cafe_table.play_opponent_reaction()

func _on_select_remove_peace_received(remover_id: int) -> void:
	if GameManager.current_game_type == GameTypes.MILL and is_instance_valid(base_game_hud):
		var my_idx = GameManager.my_player_index
		if remover_id == my_idx:
			base_game_hud.start_turn_timer(15.0, "⚔️ دوز ساختید! یک مهره حریف را برای حذف انتخاب کنید")
		else:
			base_game_hud.start_turn_timer(15.0, "⚠️ حریف دوز ساخته و در حال حذف مهره است...")

func _on_new_turn_round_received() -> void:
	if GameManager.current_game_type == GameTypes.RPC:
		_current_round_scored = false
		GameManager.is_game_active = true
		if is_instance_valid(base_game_hud):
			base_game_hud.force_dismiss_start_overlay(false)
			base_game_hud.hide_round_finish_banner()
			base_game_hud.set_round(min(GameManager.current_round, GameManager.max_rounds), GameManager.max_rounds)
			base_game_hud.start_turn_timer(7.0, "سنگ، کاغذ یا قیچی را انتخاب کنید!")
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board):
			if board.has_method("set_board_locked"):
				board.set_board_locked(false)

func _on_finish_turn_round_received(data: Dictionary) -> void:
	if GameManager.current_game_type == GameTypes.RPC:
		var winner = int(data.get("Winner", 0))
		var p1_sel = str(data.get("P1_selection", "rock")).to_lower()
		var p2_sel = str(data.get("P2_selection", "rock")).to_lower()
		var my_idx = GameManager.my_player_index
		var my_sel = p1_sel if my_idx == 1 else p2_sel
		var opp_sel = p2_sel if my_idx == 1 else p1_sel
		var sel_names = {"rock": "سنگ", "paper": "کاغذ", "cutter": "قیچی"}
		var my_name = sel_names.get(my_sel, my_sel)
		var opp_name = sel_names.get(opp_sel, opp_sel)
		var result_msg = ""
		if winner == my_idx:
			result_msg = "🎉 شما این دست را بردید! (%s بر %s)" % [my_name, opp_name]
		elif winner == 0:
			result_msg = "🤝 مساوی شد! (هر دو: %s)" % my_name
		else:
			result_msg = "💥 حریف این دست را برد! (%s بر %s)" % [opp_name, my_name]
		if is_instance_valid(base_game_hud):
			base_game_hud.start_wait_timer(3, result_msg)

func _on_round_finished(payload: Variant) -> void:
	if is_instance_valid(base_game_hud):
		base_game_hud.stop_round_timer()
	AudioManager.stop_sound("time")
	
	var winner = 0
	if typeof(payload) == TYPE_DICTIONARY:
		winner = int(payload.get("Winner", payload.get("winner", 0)))
	else:
		winner = int(payload)
		
	if not _current_round_scored:
		_current_round_scored = true
		if winner == 1:
			GameManager.p1_score += 1
		elif winner == 2:
			GameManager.p2_score += 1
		
	base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)
	if GameManager.current_game_type == GameTypes.RPC:
		var cur_r = GameManager.current_round
		GameManager.current_round = min(GameManager.current_round + 1, GameManager.max_rounds)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(base_game_hud) and not base_game_hud.is_game_finished:
				base_game_hud.show_round_finish_banner(winner, cur_r, GameManager.p1_score, GameManager.p2_score)
				base_game_hud.set_round(min(GameManager.current_round, GameManager.max_rounds), GameManager.max_rounds)
		)
	else:
		# Wait for winning piece placement animation, drop sound, and laser strike to complete visibly before showing round finish banner
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(base_game_hud) and not base_game_hud.is_game_finished:
				base_game_hud.show_round_finish_banner(winner, GameManager.current_round, GameManager.p1_score, GameManager.p2_score)
		)

func _on_new_round_started(round_num: int) -> void:
	_current_round_scored = false
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
	if GameManager.current_game_type == GameTypes.RPC:
		GameManager.is_game_active = true
		GameManager.current_round = 1
		if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
			GameManager.set_match_gamers(payload["gamers"])
			_update_table_opponent_avatar()
			base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		base_game_hud.set_round(1, GameManager.max_rounds)
		base_game_hud.force_dismiss_start_overlay(false)
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board):
			if board.has_method("set_board_locked"):
				board.set_board_locked(false)
			if board.has_method("sync_turn_state"):
				board.sync_turn_state()
		return

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
	var winner = int(data.get("winner", data.get("Winner", data.get("rank1", 0))))
	if GameRegistry.has_round_score(GameManager.current_game_type):
		if data.has("scores") and typeof(data["scores"]) == TYPE_ARRAY and (data["scores"] as Array).size() >= 2:
			GameManager.p1_score = int(data["scores"][0])
			GameManager.p2_score = int(data["scores"][1])
			_current_round_scored = true
		elif not GameRegistry.is_cumulative_score(GameManager.current_game_type) and not _current_round_scored and not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and not base_game_hud.is_pause_active:
			_current_round_scored = true
			if winner == 1:
				GameManager.p1_score += 1
			elif winner == 2:
				GameManager.p2_score += 1
		base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	base_game_hud.show_game_result(winner, GameManager.p1_score, GameManager.p2_score)

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
		elif g_data.has("out_pieces") or g_data.has("end_phases"):
			inferred_type = GameTypes.BACKGAMMON
		elif g_data.has("player1_board") or g_data.has("current_dices"):
			inferred_type = GameTypes.YATZY
		elif g_data.has("peaces"):
			inferred_type = GameTypes.CHESS
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 64:
			var b_arr: Array = g_data["board"]
			if not b_arr.is_empty() and typeof(b_arr[0]) == TYPE_DICTIONARY:
				inferred_type = GameTypes.CHECKERS
			elif g_data.has("scores"):
				inferred_type = GameTypes.OTHELLO
			else:
				inferred_type = GameTypes.FOURINROW
		elif g_data.has("current_turn__round") or (g_data.has("round_scores") and not g_data.has("board")):
			inferred_type = GameTypes.RPC
		elif g_data.has("played_peaces") or g_data.has("current_remover") or (g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 24 and not g_data.has("out_pieces")):
			inferred_type = GameTypes.MILL
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
		if board.has_method("on_reconnect_data"):
			board.on_reconnect_data(payload)
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
	else:
		if connected:
			if not GameManager.is_logged_in and not GameManager.load_saved_token().is_empty():
				NetworkManager.restore_session(func(_restored: bool, _msg: String):
					user_header.update_ui()
				)
			_show_menu_toast("✅ اتصال با سرور بازی برقرار شد!")

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

var _menu_toast_label: Label = null
var _menu_toast_tween: Tween = null

func _show_menu_toast(msg: String) -> void:
	if not _menu_toast_label or not is_instance_valid(_menu_toast_label):
		_menu_toast_label = Label.new()
		_menu_toast_label.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		_menu_toast_label.add_theme_font_size_override("font_size", 32)
		_menu_toast_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		_menu_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		_menu_toast_label.add_theme_constant_override("shadow_outline_size", 3)
		_menu_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_menu_toast_label.custom_minimum_size = Vector2(760, 80)
		_menu_toast_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
		_menu_toast_label.anchor_left = 0.5
		_menu_toast_label.anchor_right = 0.5
		_menu_toast_label.anchor_top = 1.0
		_menu_toast_label.anchor_bottom = 1.0
		_menu_toast_label.offset_left = -380.0
		_menu_toast_label.offset_right = 380.0
		_menu_toast_label.offset_top = -320.0
		_menu_toast_label.offset_bottom = -240.0
		_menu_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_canvas.add_child(_menu_toast_label)
		
	if _menu_toast_tween and _menu_toast_tween.is_valid():
		_menu_toast_tween.kill()
		
	_menu_toast_label.text = msg
	_menu_toast_label.visible = true
	_menu_toast_label.modulate.a = 0.0
	_menu_toast_label.scale = Vector2(0.9, 0.9)
	_menu_toast_label.pivot_offset = _menu_toast_label.size / 2.0
	
	_menu_toast_tween = create_tween()
	_menu_toast_tween.set_parallel(true)
	_menu_toast_tween.tween_property(_menu_toast_label, "modulate:a", 1.0, 0.25)
	_menu_toast_tween.tween_property(_menu_toast_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_toast_tween.chain().tween_interval(2.5)
	_menu_toast_tween.chain().tween_property(_menu_toast_label, "modulate:a", 0.0, 0.4)
	_menu_toast_tween.chain().tween_callback(func(): _menu_toast_label.visible = false)
