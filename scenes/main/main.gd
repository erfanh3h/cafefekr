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

@onready var logo_plate = get_node_or_null("CanvasLayer/MenuContainer/CenterContent/LogoSection/LogoPlate")



# Menu Cards

@onready var btn_ranked = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnRanked
@onready var ranked_title: Label = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnRanked/Margin/HBox/TextCol/CardTitle
@onready var ranked_subtitle: Label = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnRanked/Margin/HBox/TextCol/CardSubtitle
@onready var btn_multi_rank = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnMultiRank
@onready var btn_classic_rank = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnClassicRank
@onready var btn_lobby = $CanvasLayer/MenuContainer/CenterContent/CardsContainer/BtnLobby



# Bottom Dock

@onready var btn_ranking = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnRanking

@onready var btn_history = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnHistory

@onready var btn_rules = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnRules

@onready var btn_audio = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnAudio

@onready var btn_exit = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnExit

@onready var img_audio = $CanvasLayer/MenuContainer/BottomDock/HBoxDock/BtnAudio/VBox/Icon



# Dialogs

@onready var dialog_backdrop: ColorRect = $CanvasLayer/DialogBackdrop

@onready var login_dialog = $CanvasLayer/LoginDialog

@onready var queue_dialog = $CanvasLayer/QueueDialog

@onready var lobby_dialog = $CanvasLayer/LobbyDialog

@onready var classic_rank_dialog = $CanvasLayer/ClassicRankDialog

@onready var multi_rank_dialog = $CanvasLayer/MultiRankDialog

@onready var ranking_dialog = $CanvasLayer/RankingDialog

@onready var game_history_dialog = $CanvasLayer/GameHistoryDialog

@onready var store_dialog = $CanvasLayer/StoreDialog

@onready var rules_dialog = $CanvasLayer/RulesDialog

@onready var user_profile_dialog = $CanvasLayer/UserProfileDialog

@onready var pick_ban_dialog = $CanvasLayer/PickBanDialog
@onready var ranked_breakout_dialog = $CanvasLayer/RankedBreakoutDialog
var _ranked_series_games: Array = []
var _active_series_game_index: int = -1
var _last_game_play_payload: Dictionary = {}
var _ranked_rewards_applied: bool = false



# Base Game HUD

@onready var base_game_hud = $CanvasLayer/BaseGameHUD



var _sound_on_tex = preload("res://assets/images/badges/sound-on.png")

var _sound_off_tex = preload("res://assets/images/badges/sound-off.png")



var _splash_layer: CanvasLayer = null
var _splash_overlay: Control = null
var _splash_dismissed: bool = false
var _splash_progress_bar: ProgressBar = null
var _splash_load_lbl: Label = null
var _splash_dot_timer: Timer = null
var _offline_dialog: Control = null
var _offline_status_lbl: Label = null
var _offline_retry_btn: Button = null
var _is_retrying_connection: bool = false
var _offline_retry_token: int = 0
var _change_username_dialog: Control = null
var _ranked_locked_overlay: Control = null
var _ranked_locked_panel: PanelContainer = null
var _ranked_locked_bar: ProgressBar = null
var _ranked_locked_progress_lbl: Label = null
var _ranked_locked_remain_lbl: Label = null

func _ready() -> void:
	_setup_signals()
	_start_logo_animation()
	_setup_button_juice()
	_update_audio_button_visual()
	
	# Start in Menu Mode
	base_game_hud.visible = false
	menu_container.visible = true
	if is_instance_valid(cafe_table):
		cafe_table.visible = false
	_update_ranked_button_state()
	
	# Display polished in-engine splash overlay matching boot splash screen
	_setup_splash_overlay()
	
	# Connect to real-time game server (port 5000)
	NetworkManager.connect_to_game_server()
	
	# Fetch server configuration at startup (version validation & queue status)
	NetworkManager.fetch_server_config(func(_success, _config):
		_update_ranked_button_state()
		if GameManager.is_force_update_required:
			_show_force_update_dialog()
	)
	
	# Safety fallback timer: ensure splash always dismisses even if offline or slow server response
	get_tree().create_timer(2.6).timeout.connect(func():
		if not _splash_dismissed and is_instance_valid(self):
			_dismiss_splash_overlay(func():
				if GameManager.is_force_update_required:
					_show_force_update_dialog()
					return
				if not NetworkManager.is_online:
					_show_offline_dialog()
			)
	)
	
	# Allow brief moment for initial socket connection before verifying online session
	get_tree().create_timer(0.75).timeout.connect(func():
		if not is_instance_valid(self):
			return
		NetworkManager.restore_session(func(restored: bool, msg: String):
			user_header.update_ui()
			_update_ranked_button_state()
			if not is_instance_valid(self):
				return
			_dismiss_splash_overlay(func():
				if GameManager.is_force_update_required:
					_show_force_update_dialog()
					return
				if msg == "OFFLINE" or not NetworkManager.is_online:
					NetworkManager.connect_to_game_server()
					_show_offline_dialog()
					return
				_hide_offline_dialog()
				if not restored and not GameManager.is_logged_in:
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
	if not _splash_layer or not is_instance_valid(_splash_layer):
		_splash_layer = CanvasLayer.new()
		_splash_layer.name = "SplashCanvasLayer"
		_splash_layer.layer = 128
		add_child(_splash_layer)

	_splash_overlay = Control.new()
	_splash_overlay.name = "SplashOverlay"
	_splash_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_splash_layer.add_child(_splash_overlay)
	_splash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_splash_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH

	# Base mahogany background matching project boot_splash (Color(0.12, 0.08, 0.05, 1))
	var bg = ColorRect.new()
	_splash_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.color = Color(0.12, 0.08, 0.05, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Full-screen splash art image
	var splash_img = TextureRect.new()
	_splash_overlay.add_child(splash_img)
	splash_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_img.grow_horizontal = Control.GROW_DIRECTION_BOTH
	splash_img.grow_vertical = Control.GROW_DIRECTION_BOTH
	splash_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/images/splash.png"):
		splash_img.texture = load("res://assets/images/splash.png")
	elif ResourceLoader.exists("res://assets/images/splash.jpg"):
		splash_img.texture = load("res://assets/images/splash.jpg")

	# Ensure overlay covers 100% of viewport and dynamically tracks Android display insets/rotations
	var vp = get_viewport()
	if vp:
		var sync_splash = func():
			if is_instance_valid(_splash_overlay):
				_splash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not vp.size_changed.is_connected(sync_splash):
			vp.size_changed.connect(sync_splash)

	# Subtle bottom dark gradient/scrim for loading bar and text contrast
	var bottom_scrim = ColorRect.new()
	_splash_overlay.add_child(bottom_scrim)
	bottom_scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_scrim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_scrim.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_scrim.anchor_top = 1.0
	bottom_scrim.anchor_bottom = 1.0
	bottom_scrim.offset_top = -280.0
	bottom_scrim.offset_bottom = 0.0
	bottom_scrim.color = Color(0.06, 0.04, 0.02, 0.65)
	bottom_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom loading container
	var bottom_margin = MarginContainer.new()
	_splash_overlay.add_child(bottom_margin)
	bottom_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_margin.anchor_top = 1.0
	bottom_margin.anchor_bottom = 1.0
	bottom_margin.offset_top = -240.0
	bottom_margin.offset_bottom = -60.0
	bottom_margin.offset_left = 60.0
	bottom_margin.offset_right = -60.0
	bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var load_vbox = VBoxContainer.new()
	load_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	load_vbox.add_theme_constant_override("separation", 16)
	load_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_margin.add_child(load_vbox)

	# Persian Loading status label
	_splash_load_lbl = Label.new()
	_splash_load_lbl.text = "در حال ورود به کافه..."
	_splash_load_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	_splash_load_lbl.add_theme_font_size_override("font_size", 28)
	_splash_load_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65, 1.0))
	_splash_load_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_splash_load_lbl.add_theme_constant_override("shadow_outline_size", 4)
	_splash_load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_vbox.add_child(_splash_load_lbl)

	# Stylized Loading Bar
	_splash_progress_bar = ProgressBar.new()
	_splash_progress_bar.custom_minimum_size = Vector2(0, 20)
	_splash_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_splash_progress_bar.show_percentage = false
	_splash_progress_bar.min_value = 0.0
	_splash_progress_bar.max_value = 100.0
	_splash_progress_bar.value = 8.0

	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.10, 0.06, 0.04, 0.92)
	bg_sb.border_width_left = 2
	bg_sb.border_width_top = 2
	bg_sb.border_width_right = 2
	bg_sb.border_width_bottom = 2
	bg_sb.border_color = Color(0.65, 0.50, 0.26, 0.9)
	bg_sb.corner_radius_top_left = 10
	bg_sb.corner_radius_top_right = 10
	bg_sb.corner_radius_bottom_right = 10
	bg_sb.corner_radius_bottom_left = 10
	_splash_progress_bar.add_theme_stylebox_override("background", bg_sb)

	var fill_sb = StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.96, 0.76, 0.24, 1.0)
	fill_sb.corner_radius_top_left = 8
	fill_sb.corner_radius_top_right = 8
	fill_sb.corner_radius_bottom_right = 8
	fill_sb.corner_radius_bottom_left = 8
	_splash_progress_bar.add_theme_stylebox_override("fill", fill_sb)

	load_vbox.add_child(_splash_progress_bar)

	# Smooth loading bar progression toward 90%
	var p_tw = _splash_progress_bar.create_tween()
	p_tw.tween_property(_splash_progress_bar, "value", 90.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Animated dots for the Persian text
	var dot_step = 0
	_splash_dot_timer = Timer.new()
	_splash_dot_timer.wait_time = 0.35
	_splash_dot_timer.autostart = true
	_splash_overlay.add_child(_splash_dot_timer)
	_splash_dot_timer.timeout.connect(func():
		if not is_instance_valid(_splash_load_lbl):
			return
		dot_step = (dot_step + 1) % 4
		var dots = ""
		for d in range(dot_step):
			dots += " ."
		_splash_load_lbl.text = "در حال ورود به کافه" + dots
	)


func _dismiss_splash_overlay(callback: Callable = Callable()) -> void:
	if _splash_dismissed:
		if callback.is_valid():
			callback.call()
		return
	_splash_dismissed = true

	if not _splash_overlay or not is_instance_valid(_splash_overlay):
		if GameManager.is_game_active or (is_instance_valid(base_game_hud) and base_game_hud.visible) or not GameManager.get_open_game_id().is_empty() or not GameManager.active_game_id.is_empty():
			AudioManager.play_game_music()
		else:
			AudioManager.play_theme_music()
		if callback.is_valid():
			callback.call()
		return

	# Stop dot timer if running
	if is_instance_valid(_splash_dot_timer):
		_splash_dot_timer.stop()

	# Fast-forward progress bar to 100% and show welcome text
	if is_instance_valid(_splash_load_lbl):
		_splash_load_lbl.text = "خوش آمدید!"

	if is_instance_valid(_splash_progress_bar):
		var fin_tw = _splash_progress_bar.create_tween()
		fin_tw.tween_property(_splash_progress_bar, "value", 100.0, 0.2).set_trans(Tween.TRANS_LINEAR)

	# Music begins playing as splash smoothly fades out
	if GameManager.is_game_active or (is_instance_valid(base_game_hud) and base_game_hud.visible) or not GameManager.get_open_game_id().is_empty() or not GameManager.active_game_id.is_empty():
		AudioManager.play_game_music()
	else:
		AudioManager.play_theme_music()

	var tw = create_tween().set_parallel(true)
	# Wait a short 0.2s for progress to hit 100%, then fade out
	tw.tween_property(_splash_overlay, "modulate:a", 0.0, 0.45).set_delay(0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(_splash_overlay):
			_splash_overlay.queue_free()
			_splash_overlay = null
			_splash_progress_bar = null
			_splash_load_lbl = null
			_splash_dot_timer = null
		if is_instance_valid(_splash_layer):
			_splash_layer.queue_free()
			_splash_layer = null
		if callback.is_valid():
			callback.call()
	)



func _setup_signals() -> void:

	# Menu Button Connections

	btn_ranked.pressed.connect(_on_ranked_pressed)

	if is_instance_valid(btn_multi_rank):
		btn_multi_rank.pressed.connect(_on_multi_rank_pressed)

	btn_classic_rank.pressed.connect(_on_classic_rank_pressed)

	btn_lobby.pressed.connect(_on_lobby_pressed)

	

	btn_ranking.pressed.connect(_on_ranking_pressed)

	btn_history.pressed.connect(_on_history_pressed)

	btn_rules.pressed.connect(_on_rules_pressed)

	btn_audio.pressed.connect(_on_audio_toggle)

	btn_exit.pressed.connect(_on_exit_pressed)

	

	# Header events - tapping avatar image opens avatar list dialog directly

	user_header.store_requested.connect(_on_store_pressed)

	user_header.profile_requested.connect(func():
		AudioManager.sfx_tap()
		_on_store_pressed()
	)

	if user_header.has_signal("change_username_requested"):
		user_header.change_username_requested.connect(_show_change_username_dialog)

	if user_profile_dialog.has_signal("change_username_requested"):
		user_profile_dialog.change_username_requested.connect(_show_change_username_dialog)

	if user_header.has_signal("login_requested"):
		user_header.login_requested.connect(func():
			_show_backdrop()
			if not GameManager.is_logged_in:
				login_dialog.open()
			else:
				login_dialog.open_for_phone_upgrade("برای ذخیره دائمی حساب و شرکت در رقابت‌ها، لطفاً شماره موبایل خود را ثبت کنید.")
		)

	# User State & Progression Listeners
	GameManager.user_logged_in.connect(func(_user_data):
		_update_ranked_button_state()
	)
	GameManager.user_logged_out.connect(func():
		_update_ranked_button_state()
	)
	GameManager.game_finished.connect(func(_winner):
		_update_ranked_button_state()
	)
	NetworkManager.ranked_locked_received.connect(func(_data):
		if is_instance_valid(queue_dialog) and queue_dialog.visible:
			queue_dialog.stop_queue()
		_show_ranked_locked_dialog()
	)

	

	# Dialog events

	login_dialog.login_completed.connect(func():

		user_header.update_ui()
		_update_ranked_button_state()

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
		var mode_to_use = "multi_rank" if current_match_mode == "multi_rank" else "ranked"
		_start_game_match(gid, gtype, mode_to_use)
	)

	queue_dialog.queue_cancelled.connect(func():

		_hide_backdrop()

	)

	queue_dialog.pre_game_ready.connect(func(pre_game_id, queuers):
		if GameManager.is_game_active or not GameManager.active_game_id.is_empty() or not GameManager.get_open_game_id().is_empty():
			print("[Main] Blocked pre_game_ready: Game match is already active.")
			if is_instance_valid(pick_ban_dialog):
				pick_ban_dialog.visible = false
			return
		_hide_backdrop()
		GameManager.set_active_pre_game(pre_game_id)
		current_match_mode = "ranked"
		if is_instance_valid(pick_ban_dialog):
			pick_ban_dialog.open(pre_game_id, queuers)
			_show_backdrop()
	)

	if is_instance_valid(pick_ban_dialog):
		pick_ban_dialog.pick_ban_finished.connect(func(gid, first_gtype):
			print("[Main] Pick & Ban finished! Navigating to game scene: %s (%s)..." % [gid, first_gtype])
			GameManager.clear_open_pre_game_id()
			_start_game_match(gid, first_gtype, "ranked")
		)
		pick_ban_dialog.pick_ban_cancelled.connect(func():
			AudioManager.play_theme_music()
			GameManager.clear_open_pre_game_id()
			_hide_backdrop()
			menu_container.visible = true
			user_header.visible = true
			if is_instance_valid(cafe_table):
				cafe_table.visible = false
		)

	if is_instance_valid(ranked_breakout_dialog):
		ranked_breakout_dialog.exit_match_requested.connect(_on_ranked_breakout_exit_requested)

	NetworkManager.queue_reconnect_data_received.connect(func(data: Dictionary):
		if GameManager.is_game_active or not GameManager.active_game_id.is_empty() or not GameManager.get_open_game_id().is_empty():
			print("[Main] Ignored Pick & Ban reconnect data: Game match is already active.")
			if is_instance_valid(pick_ban_dialog):
				pick_ban_dialog.visible = false
			return
		print("[Main] Reconnect Data received for Pick & Ban: %s" % str(data))
		current_match_mode = "ranked"
		_hide_backdrop()
		if is_instance_valid(pick_ban_dialog):
			pick_ban_dialog.open_from_reconnect(data)
			_show_backdrop()
	)
	NetworkManager.queue_user_disconnected.connect(func(user_id: String, wait_time: int):
		if is_instance_valid(pick_ban_dialog) and pick_ban_dialog.visible:
			pick_ban_dialog.show_opponent_disconnected(user_id, wait_time)
	)
	NetworkManager.queue_user_reconnected.connect(func(user_id: String, remaining_time: int):
		if is_instance_valid(pick_ban_dialog) and pick_ban_dialog.visible:
			pick_ban_dialog.show_opponent_reconnected(user_id, remaining_time)
	)

	lobby_dialog.match_ready.connect(func(gid, gtype = ""):

		_start_game_match(gid, gtype, "lobby")

	)

	lobby_dialog.closed.connect(_update_backdrop_state)

	classic_rank_dialog.start_game_requested.connect(_on_classic_rank_start_requested)

	classic_rank_dialog.closed.connect(_update_backdrop_state)

	if is_instance_valid(multi_rank_dialog):
		multi_rank_dialog.start_multi_rank_requested.connect(_on_multi_rank_start_requested)
		multi_rank_dialog.closed.connect(_update_backdrop_state)

	NetworkManager.classic_rank_match_ready.connect(func(gid, gtype = ""):

		_start_game_match(gid, gtype, "classic_rank")

	)

	ranking_dialog.closed.connect(_update_backdrop_state)

	game_history_dialog.closed.connect(_update_backdrop_state)

	store_dialog.closed.connect(_update_backdrop_state)

	rules_dialog.closed.connect(_update_backdrop_state)

	user_profile_dialog.closed.connect(_update_backdrop_state)

	

	if is_instance_valid(dialog_backdrop):
		dialog_backdrop.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				# Non-dismissible modal dialogs: area around dialog must NOT be tappable!
				if (is_instance_valid(queue_dialog) and queue_dialog.visible) 					or (is_instance_valid(pick_ban_dialog) and pick_ban_dialog.visible) 					or (is_instance_valid(ranked_breakout_dialog) and ranked_breakout_dialog.visible) 					or (is_instance_valid(lobby_dialog) and lobby_dialog.visible):
					return
				if is_instance_valid(login_dialog) and login_dialog.visible:
					# Auth dialog is non-closable!
					AudioManager.sfx_tap()
					return
				elif is_instance_valid(user_profile_dialog) and user_profile_dialog.visible:
					user_profile_dialog.close()
				elif is_instance_valid(rules_dialog) and rules_dialog.visible:
					rules_dialog.close()
				elif is_instance_valid(store_dialog) and store_dialog.visible:
					store_dialog.close()
				elif is_instance_valid(ranking_dialog) and ranking_dialog.visible:
					ranking_dialog.close()
				elif is_instance_valid(game_history_dialog) and game_history_dialog.visible:
					game_history_dialog.close()
				elif is_instance_valid(multi_rank_dialog) and multi_rank_dialog.visible:
					multi_rank_dialog.close()
				elif is_instance_valid(classic_rank_dialog) and classic_rank_dialog.visible:
					classic_rank_dialog.close()
				else:
					_hide_backdrop()
		)

	ranking_dialog.user_selected.connect(func(u_dict):
		user_profile_dialog.open_for_user(u_dict)
		_show_backdrop()
	)

	if is_instance_valid(game_history_dialog):
		game_history_dialog.user_profile_requested.connect(func(u_dict):
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

	NetworkManager.player_score_received.connect(_on_player_score_received)

	NetworkManager.connection_status_changed.connect(_on_connection_status_changed)



func _start_logo_animation() -> void:
	if not is_instance_valid(logo_plate):
		return
	logo_plate.pivot_offset = logo_plate.size / 2.0

	var tw = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.tween_property(logo_plate, "scale", Vector2(1.05, 1.05), 1.8)

	tw.tween_property(logo_plate, "scale", Vector2(0.97, 0.97), 1.8)



func _setup_button_juice() -> void:

	var buttons = [btn_ranked, btn_multi_rank, btn_classic_rank, btn_lobby, btn_ranking, btn_history, btn_rules, btn_audio, btn_exit]

	for b in buttons:
		if is_instance_valid(b):
			ActionVFXManager.apply_button_juice(b, "tap_button")



func _on_ranked_pressed() -> void:
	AudioManager.sfx_button()
	if GameManager.is_force_update_required:
		_show_force_update_dialog()
		return
	if not GameManager.is_queue_open:
		_show_queue_closed_dialog()
		return
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	if GameManager.is_guest or not GameManager.has_phone():
		login_dialog.open_for_phone_upgrade("برای شرکت در مسابقات رده‌بندی (Ranked)، لطفاً ابتدا شماره موبایل خود را ثبت کنید.")
		return
	if not GameManager.has_username():
		login_dialog.open_for_username_completion()
		return
	if not GameManager.is_ranked_unlocked():
		_hide_backdrop()
		_show_ranked_locked_dialog()
		return
	current_match_mode = "ranked"
	queue_dialog.start_queue()

func _on_multi_rank_pressed() -> void:
	AudioManager.sfx_button()
	if GameManager.is_force_update_required:
		_show_force_update_dialog()
		return
	if not GameManager.is_queue_open:
		_show_queue_closed_dialog()
		return
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	if GameManager.is_guest or not GameManager.has_phone():
		login_dialog.open_for_phone_upgrade("برای شرکت در مسابقات رنک چهارنفره، لطفاً ابتدا شماره موبایل خود را ثبت کنید.")
		return
	if not GameManager.has_username():
		login_dialog.open_for_username_completion()
		return
	if is_instance_valid(multi_rank_dialog):
		multi_rank_dialog.open()

func _on_multi_rank_start_requested(game_type: String) -> void:
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	print("[Main] Multi-Rank 4-player queue requested for game: %s" % game_type)
	current_match_mode = "multi_rank"
	GameManager.current_match_mode = "multi_rank"
	_show_backdrop()
	queue_dialog.start_multi_rank_queue(game_type)

func _on_classic_rank_pressed() -> void:
	AudioManager.sfx_button()
	if GameManager.is_force_update_required:
		_show_force_update_dialog()
		return
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	if GameManager.is_guest or not GameManager.has_phone():
		login_dialog.open_for_phone_upgrade("برای شرکت در مسابقات رنک کلاسیک، لطفاً ابتدا شماره موبایل خود را ثبت کنید.")
		return
	if not GameManager.has_username():
		login_dialog.open_for_username_completion()
		return
	classic_rank_dialog.open()

func _on_classic_rank_start_requested(game_type: String) -> void:
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	print("[Main] Classic rank match requested for game: %s" % game_type)
	current_match_mode = "classic_rank"
	GameManager.current_match_mode = "classic_rank"
	_show_backdrop()
	_show_menu_toast("🎮 در حال آغاز رقابت رنک کلاسیک...")
	NetworkManager.start_classic_rank(game_type)

func _on_lobby_pressed() -> void:
	AudioManager.sfx_button()
	if GameManager.is_force_update_required:
		_show_force_update_dialog()
		return
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
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
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	_show_backdrop()
	ranking_dialog.open()

func _on_history_pressed() -> void:
	AudioManager.sfx_button()
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
	_show_backdrop()
	if not GameManager.is_logged_in:
		login_dialog.open()
		return
	game_history_dialog.open()

func _on_store_pressed() -> void:
	AudioManager.sfx_button()
	if not NetworkManager.is_online:
		NetworkManager.connect_to_game_server()
		_show_offline_dialog()
		return
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
		var is_open = func(dlg: Control) -> bool:
			return is_instance_valid(dlg) and dlg.visible and dlg.modulate.a > 0.05
		var is_queue_active = is_open.call(queue_dialog)
			
		var any_open = is_queue_active or is_open.call(lobby_dialog) \
			or is_open.call(classic_rank_dialog) or is_open.call(multi_rank_dialog) or is_open.call(pick_ban_dialog) \
			or is_open.call(ranking_dialog) or is_open.call(game_history_dialog) or is_open.call(store_dialog) \
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

	if current_match_mode == "ranked":

		return "بازی رقابتی"

	elif current_match_mode == "multi_rank":

		return "رنک چهارنفره"

	elif current_match_mode == "classic_rank":

		return "رنک کلاسیک"

	else:

		return "لابی دوستانه"



func _start_game_match(game_id: String, requested_game_type: String = "", match_mode: String = "", is_reconnect: bool = false) -> void:

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

	GameManager.current_match_mode = current_match_mode

	GameManager.is_game_active = is_reconnect

	GameManager.current_turn = 0

	GameManager.local_player_surrendered = false

	GameManager.opponent_player_surrendered = false

	_camera_hint_shown = false

	_pending_start_game = false

	_pending_turn = -1

	_current_round_scored = false
	_active_series_game_index = 0
	_ranked_rewards_applied = false

	

	# Dismiss and clear all menu overlays and backdrops so nothing intercepts gameplay touch input

	_hide_backdrop()

	if is_instance_valid(queue_dialog):

		queue_dialog.visible = false

	if is_instance_valid(lobby_dialog):

		lobby_dialog.visible = false

	if is_instance_valid(classic_rank_dialog):

		classic_rank_dialog.visible = false

	if is_instance_valid(multi_rank_dialog):

		multi_rank_dialog.visible = false

	if is_instance_valid(pick_ban_dialog):

		pick_ban_dialog.visible = false

	if is_instance_valid(ranked_breakout_dialog):

		ranked_breakout_dialog.visible = false

	if is_instance_valid(ranking_dialog):

		ranking_dialog.visible = false

	if is_instance_valid(game_history_dialog):

		game_history_dialog.visible = false

	if is_instance_valid(store_dialog):

		store_dialog.visible = false

	if is_instance_valid(rules_dialog):

		rules_dialog.visible = false

	if is_instance_valid(login_dialog):

		login_dialog.visible = false

	if is_instance_valid(user_profile_dialog):

		user_profile_dialog.visible = false
		user_profile_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(base_game_hud) and is_instance_valid(base_game_hud.user_profile_dialog):
		base_game_hud.user_profile_dialog.visible = false
		base_game_hud.user_profile_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE



	menu_container.visible = false
	user_header.visible = false
	if is_instance_valid(cafe_table):
		cafe_table.visible = true
	base_game_hud.visible = true

	base_game_hud.reset_for_new_match()

	base_game_hud.setup_match(game_name_fa, _get_mode_title())

	

	# Spawn 3D board onto the table through unified GameRegistry BEFORE joining namespace

	_spawn_board_for_game(GameManager.current_game_type)

	

	# Play in-game background music

	AudioManager.play_game_music()

	

	# Connect to real-time game server namespace

	NetworkManager.join_active_game(game_id)

	

	if is_reconnect:
		print("[Main] Reconnecting to active game: skipping 5-second start countdown.")
		base_game_hud.is_game_started = true
		base_game_hud.is_start_overlay_dismissed = true
		base_game_hud.force_dismiss_start_overlay(false)
		base_game_hud.hide_turn_banner()
	else:
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

	if is_instance_valid(user_profile_dialog):
		user_profile_dialog.visible = false
	if is_instance_valid(base_game_hud) and is_instance_valid(base_game_hud.user_profile_dialog):
		base_game_hud.user_profile_dialog.visible = false
		base_game_hud.user_profile_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE

	base_game_hud.force_dismiss_start_overlay(false)

	if GameManager.current_game_type in [GameTypes.FEKRBEKR, GameTypes.BATTLESHIP]:

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



func _on_player_score_received(_payload: Dictionary) -> void:

	if is_instance_valid(base_game_hud):

		base_game_hud.update_scores(GameManager.p1_score, GameManager.p2_score)



func _on_select_remove_peace_received(remover_id: int) -> void:

	if GameManager.current_game_type == GameTypes.MILL and is_instance_valid(base_game_hud):

		var my_idx = GameManager.my_player_index

		if remover_id == my_idx:

			base_game_hud.start_turn_timer(15.0, "⚔️ دوز ساختید! یک مهره حریف را برای حذف انتخاب کنید")

		else:

			base_game_hud.start_turn_timer(15.0, "⚠️ حریف دوز ساخته و در حال حذف مهره است...")

	elif GameManager.current_game_type == GameTypes.YINSH and is_instance_valid(base_game_hud):

		var my_idx = GameManager.my_player_index

		if remover_id == my_idx:

			base_game_hud.start_turn_timer(20.0, "🎉 ردیف ۵ تایی! یکی از حلقه‌های خود را برای دریافت امتیاز انتخاب کنید")

		else:

			base_game_hud.start_turn_timer(20.0, "⚠️ حریف ردیف ۵ تایی ساخت و در حال انتخاب حلقه است...")



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

		if is_instance_valid(base_game_hud) and not base_game_hud.is_round_finished and not base_game_hud.is_game_finished:

			base_game_hud.start_wait_timer(3, result_msg)

	elif GameManager.current_game_type == GameTypes.QUIZ:

		var my_idx = GameManager.my_player_index
		var player_answers: Dictionary = data.get("player_answers", {}) if typeof(data.get("player_answers", {})) == TYPE_DICTIONARY else {}
		var my_res = player_answers.get(str(my_idx), player_answers.get(my_idx, {}))
		var is_corr = bool(my_res.get("is_correct", false)) if typeof(my_res) == TYPE_DICTIONARY else false
		var delta = int(my_res.get("score_delta", 0)) if typeof(my_res) == TYPE_DICTIONARY else 0
		var quiz_msg = "🎉 آفرین! پاسخ شما صحیح بود (+۱)" if is_corr else ("❌ پاسخ نادرست بود (-۱)" if delta < 0 else "⏳ مهلت پاسخ پایان یافت (۰)")
		if is_instance_valid(base_game_hud) and not base_game_hud.is_round_finished and not base_game_hud.is_game_finished:
			base_game_hud.start_wait_timer(4, quiz_msg)



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
	_last_game_play_payload = payload.duplicate(true)
	var score_type_str = str(payload.get("game_score_type", ""))
	if score_type_str == "Rank":
		current_match_mode = "ranked"
		GameManager.current_match_mode = "ranked"
	elif score_type_str == "MultiRANK":
		current_match_mode = "multi_rank"
		GameManager.current_match_mode = "multi_rank"
	elif score_type_str == "ClassicRank":
		current_match_mode = "classic_rank"
		GameManager.current_match_mode = "classic_rank"
	elif score_type_str == "Lobby":
		current_match_mode = "lobby"
		GameManager.current_match_mode = "lobby"

	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
		_update_table_opponent_avatar()
		if GameManager.is_game_active and GameManager.current_game_type == GameTypes.QUIZ and is_instance_valid(base_game_hud):
			base_game_hud.refresh_players_only()

	var current_idx = int(payload.get("current_game_index", 0))
	var games_arr = payload.get("games", []) as Array
	if not games_arr.is_empty():
		_ranked_series_games = games_arr.duplicate()

	var is_finished = bool(payload.get("is_game_finished", false))
	var is_between_games = bool(payload.get("is_between_games", false))
	var winners_arr = payload.get("winners", [-1, -1, -1]) as Array

	if current_match_mode == "ranked":
		if is_finished and not _ranked_rewards_applied:
			_ranked_rewards_applied = true
			var my_uid = str(GameManager.get_user_id())
			var xp_map = payload.get("xp_awarded", {})
			var sc_map = payload.get("score_awarded", {})
			var cn_map = payload.get("coin_awarded", {})
			var my_xp = int(xp_map.get(my_uid, 0)) if typeof(xp_map) == TYPE_DICTIONARY else 0
			var my_sc = int(sc_map.get(my_uid, 0)) if typeof(sc_map) == TYPE_DICTIONARY else 0
			var my_cn = int(cn_map.get(my_uid, 0)) if typeof(cn_map) == TYPE_DICTIONARY else 0
			GameManager.apply_ranked_rewards(my_sc, my_xp, my_cn)

		var prev_game_finished = (current_idx > 0 and not winners_arr.is_empty() and int(winners_arr[current_idx - 1]) != -1)
		if is_finished or (prev_game_finished and is_between_games):
			print("[Main] Ranked breakout view shown: Game %d/3 (is_finished=%s)" % [current_idx + 1, str(is_finished)])
			GameManager.is_game_active = false
			GameManager.local_player_surrendered = false
			GameManager.opponent_player_surrendered = false
			if is_instance_valid(base_game_hud):
				base_game_hud.stop_timer()
				base_game_hud.stop_round_timer()
				base_game_hud._surrender_handled = false
				base_game_hud.is_game_finished = false
				base_game_hud.hide_round_finish_banner()
				base_game_hud.hide_pause_dialog()
			var cur_board = cafe_table.current_board_node
			if cur_board and is_instance_valid(cur_board) and cur_board.has_method("set_board_locked"):
				cur_board.set_board_locked(true)
			if is_instance_valid(ranked_breakout_dialog):
				ranked_breakout_dialog.open(payload)
			return
		else:
			if not games_arr.is_empty() and current_idx < games_arr.size():
				var server_game_type = str(games_arr[current_idx])
				var norm = GameRegistry.normalize_type(server_game_type)
				if norm.to_lower() != GameManager.current_game_type.to_lower():
					_switch_active_game(norm)
	else:
		if not games_arr.is_empty() and current_idx < games_arr.size():
			var server_game_type = str(games_arr[current_idx])
			var norm = GameRegistry.normalize_type(server_game_type)
			if norm.to_lower() != GameManager.current_game_type.to_lower():
				_switch_active_game(norm)

	if not GameManager.is_game_active and not is_finished and not (current_match_mode == "ranked" and is_between_games and current_idx > 0):
		base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		if not base_game_hud.is_countdown_running and not base_game_hud.is_start_overlay_dismissed:
			base_game_hud.play_start_countdown(Callable(), 5)
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
		board.sync_turn_state()

func _on_game_play_time_received(time: int) -> void:

	if is_instance_valid(ranked_breakout_dialog) and ranked_breakout_dialog.is_open():

		ranked_breakout_dialog.update_timer(time)

	elif is_instance_valid(base_game_hud.round_finish_banner) and base_game_hud.round_finish_banner.visible:

		var norm = GameManager.current_game_type

		var next_name = GameTypes.get_display_name_fa(norm)

		base_game_hud.update_transition_countdown(time, next_name, GameManager.p1_score, GameManager.p2_score)

	elif not base_game_hud.is_start_overlay_dismissed:

		base_game_hud.update_start_countdown_time(time)



func _on_game_data_received(payload: Dictionary) -> void:
	if GameManager.is_game_active:
		print("[Main] Game_Data received while match is active (reconnect). Dismissing overlays.")
		if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
			GameManager.set_match_gamers(payload["gamers"])
			_update_table_opponent_avatar()
			base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		base_game_hud.is_game_started = true
		base_game_hud.is_start_overlay_dismissed = true
		base_game_hud.force_dismiss_start_overlay(false)
		return

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
	_hide_backdrop()
	if is_instance_valid(ranked_breakout_dialog) and ranked_breakout_dialog.is_open():
		ranked_breakout_dialog.dismiss()
	elif is_instance_valid(ranked_breakout_dialog):
		ranked_breakout_dialog.visible = false
	base_game_hud.hide_game_transition_banner()
	# Reset surrender status so new game is active and interactive
	GameManager.local_player_surrendered = false
	GameManager.opponent_player_surrendered = false
	if is_instance_valid(base_game_hud):
		base_game_hud._surrender_handled = false
		base_game_hud.is_game_finished = false

	var current_idx = int(payload.get("current_game_index", 0))
	var games_arr = payload.get("games", []) as Array
	if games_arr.is_empty() and not _ranked_series_games.is_empty():
		games_arr = _ranked_series_games
	var target_norm = GameManager.current_game_type
	if not games_arr.is_empty() and current_idx < games_arr.size():
		var server_game_type = str(games_arr[current_idx])
		target_norm = GameRegistry.normalize_type(server_game_type)

	var is_reconnect = bool(payload.get("is_reconnect", false))
	if is_reconnect:
		print("[Main] Game_Play_Navigate received during reconnect. Bypassing start countdown.")
		_active_series_game_index = current_idx
		if not target_norm.is_empty() and target_norm.to_lower() != GameManager.current_game_type.to_lower():
			_switch_active_game(target_norm)
		GameManager.is_game_active = true
		base_game_hud.is_game_started = true
		base_game_hud.is_start_overlay_dismissed = true
		base_game_hud.force_dismiss_start_overlay(false)
		base_game_hud.hide_turn_banner()
		var b_node = cafe_table.current_board_node
		if b_node and is_instance_valid(b_node) and b_node.has_method("sync_turn_state"):
			b_node.sync_turn_state()
		NetworkManager.send_game_command("RequestReconnectData", {})
		return

	# Check if we are transitioning to a NEW game in the series (e.g. Game 2 or Game 3),
	# or if Game 1 was already initialized by _start_game_match.
	var is_new_series_game: bool = (current_idx != _active_series_game_index)
	_active_series_game_index = current_idx

	if is_new_series_game:
		_pending_start_game = false
		_pending_turn = -1
		_current_round_scored = false
		GameManager.is_game_active = false
		GameManager.current_turn = 0
		GameManager.current_round = 1
		GameManager.p1_score = 0
		GameManager.p2_score = 0

		if not target_norm.is_empty():
			_switch_active_game(target_norm)
		AudioManager.play_game_music()

		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("set_board_locked"):
			board.set_board_locked(true)
		base_game_hud.reset_for_new_match()
		base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		base_game_hud.play_start_countdown(Callable(), 5)
	else:
		if not target_norm.is_empty() and target_norm.to_lower() != GameManager.current_game_type.to_lower():
			_switch_active_game(target_norm)
		base_game_hud.setup_match(GameManager.get_game_display_name(), _get_mode_title())
		if not base_game_hud.is_countdown_running and not base_game_hud.is_start_overlay_dismissed and not GameManager.is_game_active:
			base_game_hud.play_start_countdown(Callable(), 5)

func _on_surrender_requested() -> void:
	print("[Main] User confirmed surrender. Sending command to backend...")
	GameManager.local_player_surrendered = true
	GameManager.opponent_player_surrendered = false
	if current_match_mode != "ranked":
		GameManager.clear_open_game_id()
	NetworkManager.send_surrender()
	var board = cafe_table.current_board_node
	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)
	_on_player_surrendered(GameManager.my_player_index)

func _on_player_surrendered(gamer_id: int) -> void:

	if GameManager.current_game_type in [GameTypes.LUDO, GameTypes.RISK, GameTypes.UNO, GameTypes.QUIZ, GameTypes.COUP, GameTypes.MONOPOLY] and GameManager.match_players.size() > 2 and gamer_id != GameManager.my_player_index:

		var p_data = GameManager.get_player_data_by_gamer_id(gamer_id)

		var p_name = str(p_data.get("name", p_data.get("username", "بازیکن %d" % gamer_id)))

		base_game_hud.show_toast_hint("🏳️ %s از ادامه مسابقه انصراف داد!" % p_name)

		var b_node = cafe_table.current_board_node

		if b_node and is_instance_valid(b_node) and b_node.has_method("on_player_surrendered"):

			b_node.on_player_surrendered(gamer_id)

		return

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
	AudioManager.play_theme_music()
	GameManager.is_game_active = false
	GameManager.clear_open_game_id()
	GameManager.clear_open_pre_game_id()

	# If pick_ban_dialog is currently active, show game finished dialog and return cleanly
	if is_instance_valid(pick_ban_dialog) and pick_ban_dialog.visible:
		print("[Main] Game_Finished received while Pick & Ban dialog is open. Showing dialog...")
		pick_ban_dialog.show_game_finished_dialog("این بازی به پایان رسیده است.")
		return

	var board = cafe_table.current_board_node
	if not board or not is_instance_valid(board):
		print("[Main] Game_Finished received without an active board. Returning to main menu.")
		_hide_backdrop()
		menu_container.visible = true
		user_header.visible = true
		if is_instance_valid(cafe_table):
			cafe_table.visible = false
		base_game_hud.visible = false
		if is_instance_valid(pick_ban_dialog):
			pick_ban_dialog.show_game_finished_dialog("این بازی به پایان رسیده است.")
		return

	if board and is_instance_valid(board):

		if board.has_method("_recalculate_scores_from_boxes"):

			board._recalculate_scores_from_boxes()

		if board.has_method("_sync_hud_scores"):

			board._sync_hud_scores()

	if data.has("rank1") and data["rank1"] != null:

		GameManager.ludo_rank1 = int(data["rank1"])

	if data.has("rank2") and data["rank2"] != null:

		GameManager.ludo_rank2 = int(data["rank2"])

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

	if not GameManager.local_player_surrendered and not GameManager.opponent_player_surrendered and not base_game_hud.is_pause_active and GameManager.get_player_not_played_turns(1) < 2 and GameManager.get_player_not_played_turns(2) < 2:

		if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.MNUMBERS, GameTypes.BATTLESHIP, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE, GameTypes.MSWEEPER, GameTypes.BOXFOUR]:

			if GameManager.p1_score > GameManager.p2_score:

				winner = 1

			elif GameManager.p2_score > GameManager.p1_score:

				winner = 2

			elif GameManager.current_game_type == GameTypes.DOTBOX and (GameManager.p1_score + GameManager.p2_score) >= 25 and GameManager.p1_score == GameManager.p2_score:

				winner = 0

			elif GameManager.current_game_type == GameTypes.MNUMBERS and (GameManager.p1_score + GameManager.p2_score) >= 18 and GameManager.p1_score == GameManager.p2_score:

				winner = 0

		elif GameManager.current_game_type == GameTypes.QUIZ and GameManager.match_players.size() <= 2:

			if GameManager.p1_score > GameManager.p2_score:

				winner = 1

			elif GameManager.p2_score > GameManager.p1_score:

				winner = 2

			else:

				winner = 0

	var xp_earned: int = int(data.get("xp_earned", data.get("xp_awarded", 0)))
	var coin_earned: int = int(data.get("coin_earned", data.get("coin_awarded", 0)))
	var score_earned: int = int(data.get("score_earned", data.get("score_awarded", 0)))

	# Fallback XP if not provided by backend
	if xp_earned <= 0:
		var is_win = (winner == GameManager.my_player_index)
		var is_draw = (winner == 0)
		if current_match_mode == "classic_rank":
			xp_earned = GameRegistry.get_classic_rank_xp(GameManager.current_game_type, is_win, is_draw)
		elif current_match_mode == "multi_rank":
			var is_second = (GameManager.ludo_rank2 == GameManager.my_player_index)
			xp_earned = GameRegistry.get_multi_rank_xp(GameManager.current_game_type, is_win, is_second)
		elif current_match_mode == "lobby":
			xp_earned = GameRegistry.get_lobby_xp(GameManager.current_game_type, is_win, is_draw)

	if board and is_instance_valid(board) and board.has_method("set_board_locked"):
		board.set_board_locked(true)

	if current_match_mode == "multi_rank":
		if not _ranked_rewards_applied:
			_ranked_rewards_applied = true
			GameManager.apply_ranked_rewards(score_earned, xp_earned, coin_earned)
		base_game_hud.show_game_result(winner, GameManager.p1_score, GameManager.p2_score, xp_earned, coin_earned, score_earned)
		return

	if current_match_mode == "ranked":
		if not _ranked_rewards_applied:
			_ranked_rewards_applied = true
			var r_xp = int(data.get("xp_earned", data.get("xp_awarded", 0)))
			var r_sc = int(data.get("score_earned", data.get("score_awarded", 0)))
			var r_cn = int(data.get("coin_earned", data.get("coin_awarded", 0)))
			GameManager.apply_ranked_rewards(r_sc, r_xp, r_cn)
		if is_instance_valid(ranked_breakout_dialog):
			var payload = _last_game_play_payload.duplicate() if not _last_game_play_payload.is_empty() else {}
			for k in data.keys():
				payload[k] = data[k]
			payload["is_game_finished"] = true
			if data.has("game_winner_id") and data["game_winner_id"] != null:
				payload["game_winner_id"] = data["game_winner_id"]
			_last_game_play_payload = payload
			if not ranked_breakout_dialog.is_open():
				ranked_breakout_dialog.open(payload)
			else:
				ranked_breakout_dialog.update_data(payload)
		return

	if xp_earned > 0:
		GameManager.add_xp(xp_earned)
	if coin_earned > 0:
		GameManager.add_coins(coin_earned)

	base_game_hud.show_game_result(winner, GameManager.p1_score, GameManager.p2_score, xp_earned, coin_earned, score_earned)



# Auto enters ongoing match if one is active on server when game starts or reconnects

func _check_and_auto_enter_active_game() -> void:
	# Priority 1: If game is already started, enter match directly and suppress Pick & Ban!
	var open_id = GameManager.get_open_game_id()
	if not open_id.is_empty() or GameManager.is_game_active or not GameManager.active_game_id.is_empty():
		var target_gid = open_id if not open_id.is_empty() else GameManager.active_game_id
		print("[Main] Active ongoing game session found (%s). Suppressing Pick & Ban and auto-joining match..." % target_gid)
		GameManager.clear_open_pre_game_id()
		if is_instance_valid(pick_ban_dialog):
			pick_ban_dialog.visible = false
		if not base_game_hud.visible:
			_start_game_match(target_gid, "", current_match_mode if not current_match_mode.is_empty() else "ranked", true)
		AudioManager.play_game_music()
		return

	# Priority 2: Only show pick & ban if we are truly still in pick & ban phase!
	var open_pre_id = GameManager.get_open_pre_game_id()
	if not open_pre_id.is_empty():
		print("[Main] Active Pick & Ban draft session found on server: %s. Auto-rejoining..." % open_pre_id)
		current_match_mode = "ranked"
		NetworkManager.join_matchmaking_queue(open_pre_id)
		if is_instance_valid(pick_ban_dialog):
			pick_ban_dialog.show_reconnecting_state(open_pre_id)
			_show_backdrop()
		return



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
	AudioManager.play_game_music()

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
	var is_silent_sync: bool = NetworkManager.consume_silent_quiz_sync()
	print("[Main] Received Reconnect_Data from server (silent_quiz_sync=%s). Restoring match state..." % str(is_silent_sync))
	_pending_start_game = false
	_pending_turn = -1
	GameManager.is_game_active = true
	AudioManager.play_game_music()

	# Ensure gameplay HUD is visible and menu/dialogs are hidden
	_hide_backdrop()
	if is_instance_valid(queue_dialog):
		queue_dialog.visible = false
	if is_instance_valid(lobby_dialog):
		lobby_dialog.visible = false
	if is_instance_valid(classic_rank_dialog):
		classic_rank_dialog.visible = false
	if is_instance_valid(multi_rank_dialog):
		multi_rank_dialog.visible = false
	if is_instance_valid(pick_ban_dialog):
		pick_ban_dialog.visible = false
	if is_instance_valid(ranked_breakout_dialog) and ranked_breakout_dialog.is_open():
		ranked_breakout_dialog.dismiss()
	elif is_instance_valid(ranked_breakout_dialog):
		ranked_breakout_dialog.visible = false
	menu_container.visible = false
	user_header.visible = false
	if is_instance_valid(cafe_table):
		cafe_table.visible = true
	base_game_hud.visible = true

	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
		_update_table_opponent_avatar()

	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		var inferred_type = ""
		if payload.has("game_type") and not str(payload["game_type"]).is_empty():
			inferred_type = GameRegistry.normalize_type(str(payload["game_type"]))
		elif g_data.has("game_type") and not str(g_data["game_type"]).is_empty():
			inferred_type = GameRegistry.normalize_type(str(g_data["game_type"]))
		elif payload.has("current_question") or (payload.has("total_questions") and payload.has("scores")):
			inferred_type = GameTypes.QUIZ
		elif g_data.has("is_setup_ring_phase") or g_data.has("disk_count") or (g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 85):
			inferred_type = GameTypes.YINSH
		elif g_data.has("players_out_pieces") or g_data.has("start_board"):
			inferred_type = GameTypes.LUDO
		elif g_data.has("tokens") and g_data.has("continents") and g_data.has("strategies"):
			inferred_type = GameTypes.RISK
		elif g_data.has("hands_count") and g_data.has("current_color") and g_data.has("top_card"):
			inferred_type = GameTypes.UNO
		elif g_data.has("tiles") and g_data.has("phase") and g_data.has("last_dice"):
			inferred_type = GameTypes.MONOPOLY
		elif g_data.has("phase") and g_data.has("players") and g_data.has("deck_remaining"):
			inferred_type = GameTypes.COUP
		elif g_data.has("current_question") or (g_data.has("total_questions") and g_data.has("scores")):
			inferred_type = GameTypes.QUIZ
		elif g_data.has("walls_left") or (g_data.has("h_walls") and g_data.has("v_walls")):
			inferred_type = GameTypes.QUORIDOR
		elif g_data.has("rotation_played") or g_data.has("selection_played") or g_data.has("pawns"):
			inferred_type = GameTypes.PENTAGO
		elif g_data.has("player1_choices") or g_data.has("player2_choices"):
			inferred_type = GameTypes.FEKRBEKR
		elif g_data.has("is_play_phase") and g_data.has("player1_board") and g_data.has("player2_board"):
			inferred_type = GameTypes.BATTLESHIP
		elif g_data.has("is_play_phase"):
			inferred_type = GameTypes.FEKRBEKR
		elif g_data.has("out_pieces") or g_data.has("end_phases"):
			inferred_type = GameTypes.BACKGAMMON
		elif g_data.has("player1_board") or g_data.has("current_dices"):
			inferred_type = GameTypes.YATZY
		elif g_data.has("peaces") or g_data.has("board_data"):
			inferred_type = GameTypes.CHESS
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 64:
			var b_arr: Array = g_data["board"]
			if not b_arr.is_empty() and typeof(b_arr[0]) == TYPE_DICTIONARY:
				if (b_arr[0] as Dictionary).has("correctly_selected_mine") or g_data.has("remaining_selectable_mines"):
					inferred_type = GameTypes.MSWEEPER
				else:
					inferred_type = GameTypes.CHECKERS
			elif g_data.has("scores"):
				inferred_type = GameTypes.OTHELLO
			else:
				inferred_type = GameTypes.FOURINROW
		elif g_data.has("current_turn__round") or (g_data.has("round_scores") and not g_data.has("board")):
			inferred_type = GameTypes.RPC
		elif g_data.has("lines_board") or g_data.has("boxes_board"):
			inferred_type = GameTypes.DOTBOX
		elif g_data.has("played_peaces") or (g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 24 and not g_data.has("out_pieces")):
			inferred_type = GameTypes.MILL
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 81:
			inferred_type = GameTypes.SUDOKU
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 36:
			inferred_type = GameTypes.MNUMBERS
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 25:
			inferred_type = GameTypes.BOXFOUR
		elif g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY and (g_data["board"] as Array).size() == 9:
			inferred_type = GameTypes.TIC_TAC_TOE
		if not inferred_type.is_empty():
			if cafe_table.current_board_node == null or inferred_type.to_lower() != GameManager.current_game_type.to_lower():
				_switch_active_game(inferred_type)

	# Never show the start countdown dialog on reconnect
	base_game_hud.is_game_started = true
	base_game_hud.is_start_overlay_dismissed = true
	base_game_hud.force_dismiss_start_overlay(false)
	if not is_silent_sync:
		base_game_hud.hide_turn_banner()
	base_game_hud.handle_reconnect_data(payload, not is_silent_sync)

	var board = cafe_table.current_board_node
	if board and is_instance_valid(board):
		if board.has_method("_on_internal_reconnect_data"):
			board._on_internal_reconnect_data(payload)
		else:
			if typeof(g_data) == TYPE_DICTIONARY and board.has_method("sync_board_state"):
				if g_data.has("board_data"):
					board.sync_board_state(g_data["board_data"])
				elif g_data.has("board"):
					board.sync_board_state(g_data["board"])
				elif g_data.has("lines_board"):
					board.sync_board_state(g_data["lines_board"])
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
	if GameManager.match_players.size() > 2 or current_match_mode == "multi_rank":
		base_game_hud.show_toast_hint("⏱️ مهلت اتصال بازیکن قطع‌شده به پایان رسید!")
		var board = cafe_table.current_board_node
		if board and is_instance_valid(board) and board.has_method("sync_turn_state"):
			board.sync_turn_state()
		return
	base_game_hud.show_toast_hint("🏆 مهلت اتصال حریف به پایان رسید!")
	if current_match_mode == "ranked":
		return
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
		if not connected:
			if _splash_dismissed:
				_show_offline_dialog()
		else:
			if _offline_dialog and is_instance_valid(_offline_dialog) and _offline_dialog.visible:
				if not _is_retrying_connection:
					_on_offline_retry_pressed()
			else:
				if not GameManager.is_logged_in and not GameManager.load_saved_token().is_empty():
					NetworkManager.restore_session(func(_restored: bool, _msg: String):
						user_header.update_ui()
					)
				_show_menu_toast("✅ اتصال با سرور بازی برقرار شد!")

func _show_offline_dialog() -> void:
	if not _offline_dialog or not is_instance_valid(_offline_dialog):
		_offline_dialog = Control.new()
		_offline_dialog.name = "OfflineDialogOverlay"
		_offline_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
		_offline_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
		_offline_dialog.z_index = 95

		var dark_bg = ColorRect.new()
		dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark_bg.color = Color(0.04, 0.02, 0.01, 0.86)
		dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		_offline_dialog.add_child(dark_bg)

		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_STOP
		_offline_dialog.add_child(center)

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(780, 480)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var style = StyleBoxTexture.new()
		style.texture = preload("res://assets/images/frames/board.png")
		style.texture_margin_left = 60.0
		style.texture_margin_top = 60.0
		style.texture_margin_right = 60.0
		style.texture_margin_bottom = 60.0
		panel.add_theme_stylebox_override("panel", style)
		center.add_child(panel)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 48)
		margin.add_theme_constant_override("margin_top", 44)
		margin.add_theme_constant_override("margin_right", 48)
		margin.add_theme_constant_override("margin_bottom", 44)
		panel.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 24)
		margin.add_child(vbox)

		var font_hekayat = preload("res://assets/fonts/hekayat.ttf")

		var lbl_title = Label.new()
		lbl_title.text = "📡 عدم ارتباط با سرور"
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_title.add_theme_font_override("font", font_hekayat)
		lbl_title.add_theme_font_size_override("font_size", 46)
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
		lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl_title.add_theme_constant_override("shadow_outline_size", 3)
		vbox.add_child(lbl_title)

		var lbl_desc = Label.new()
		lbl_desc.text = "شما به سرور بازی متصل نیستید.
بازی کافه‌فکر فقط به صورت آنلاین در دسترس است.
لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید."
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.custom_minimum_size = Vector2(640, 120)
		lbl_desc.add_theme_font_override("font", font_hekayat)
		lbl_desc.add_theme_font_size_override("font_size", 30)
		lbl_desc.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
		vbox.add_child(lbl_desc)

		_offline_status_lbl = Label.new()
		_offline_status_lbl.text = ""
		_offline_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_offline_status_lbl.add_theme_font_override("font", font_hekayat)
		_offline_status_lbl.add_theme_font_size_override("font_size", 26)
		_offline_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.45))
		vbox.add_child(_offline_status_lbl)

		_offline_retry_btn = Button.new()
		_offline_retry_btn.text = "🔄 تلاش مجدد"
		_offline_retry_btn.custom_minimum_size = Vector2(380, 108)
		_offline_retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_offline_retry_btn.add_theme_font_override("font", font_hekayat)
		_offline_retry_btn.add_theme_font_size_override("font_size", 34)
		KenneyUI.style_button(_offline_retry_btn, KenneyUI.COLOR_GREEN)
		_offline_retry_btn.pressed.connect(_on_offline_retry_pressed)
		vbox.add_child(_offline_retry_btn)

		ui_canvas.add_child(_offline_dialog)

	_is_retrying_connection = false
	if is_instance_valid(_offline_retry_btn):
		_offline_retry_btn.disabled = false
		_offline_retry_btn.text = "🔄 تلاش مجدد"
	if is_instance_valid(_offline_status_lbl):
		_offline_status_lbl.text = ""
	_offline_dialog.visible = true

func _hide_offline_dialog() -> void:
	_is_retrying_connection = false
	if _offline_dialog and is_instance_valid(_offline_dialog):
		_offline_dialog.visible = false

func _on_offline_retry_pressed() -> void:
	if _is_retrying_connection:
		return
	AudioManager.sfx_button()
	_is_retrying_connection = true
	_offline_retry_token += 1
	var current_token = _offline_retry_token

	if is_instance_valid(_offline_retry_btn):
		_offline_retry_btn.disabled = true
		_offline_retry_btn.text = "در حال اتصال..."
	if is_instance_valid(_offline_status_lbl):
		_offline_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
		_offline_status_lbl.text = "در حال بررسی اتصال به سرور..."

	NetworkManager.connect_to_game_server()

	var start_time = Time.get_ticks_msec()
	var timeout_ms = 10000

	while Time.get_ticks_msec() - start_time < timeout_ms:
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or _offline_retry_token != current_token:
			return

		if NetworkManager.is_online:
			var finished = false
			var restored_ok = false
			var result_msg = ""
			NetworkManager.restore_session(func(restored: bool, msg: String):
				finished = true
				restored_ok = restored
				result_msg = msg
			)
			var sub_wait = 0
			while not finished and sub_wait < 25:
				await get_tree().create_timer(0.1).timeout
				sub_wait += 1
			if not is_instance_valid(self) or _offline_retry_token != current_token:
				return
			if NetworkManager.is_online and result_msg != "OFFLINE":
				_is_retrying_connection = false
				_hide_offline_dialog()
				user_header.update_ui()
				_update_ranked_button_state()
				_show_menu_toast("✅ اتصال با سرور بازی برقرار شد!")
				if not restored_ok or not GameManager.is_logged_in:
					login_dialog.open()
					_show_backdrop()
				elif not GameManager.is_guest and not GameManager.has_username():
					login_dialog.open_for_username_completion()
					_show_backdrop()
				else:
					_check_and_auto_enter_active_game()
				return
		else:
			NetworkManager.connect_to_game_server()

	# 10-second timeout elapsed: return to init state with toast "ناموفق"
	if not is_instance_valid(self) or _offline_retry_token != current_token:
		return
	_is_retrying_connection = false
	if is_instance_valid(_offline_retry_btn):
		_offline_retry_btn.disabled = false
		_offline_retry_btn.text = "🔄 تلاش مجدد"
	if is_instance_valid(_offline_status_lbl):
		_offline_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.48))
		_offline_status_lbl.text = ""
	_show_menu_toast("ناموفق")

func _on_leave_game_pressed() -> void:
	AudioManager.sfx_button()
	GameManager.clear_open_game_id()
	GameManager.clear_open_pre_game_id()
	NetworkManager.leave_active_game()
	cafe_table.clear_board()
	cafe_table.reset_table_state()
	cafe_table.transition_to_menu_view(1.0)
	
	base_game_hud.reset_for_new_match()
	base_game_hud.visible = false
	user_header.visible = true
	menu_container.visible = true
	if is_instance_valid(cafe_table):
		cafe_table.visible = false
	_hide_backdrop()
	
	GameManager.reset_match_state()
	user_header.update_ui()
	_update_ranked_button_state()
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



# --- Menu Showcase & Gamer Experience Methods ---



func _unhandled_input(event: InputEvent) -> void:

	if not is_instance_valid(cafe_table):

		return

	if is_instance_valid(menu_container) and menu_container.visible:

		if event is InputEventMouseMotion:

			var vp_rect = get_viewport().get_visible_rect()

			if vp_rect.size.x > 0 and vp_rect.size.y > 0:

				var norm = (event.position / vp_rect.size) * 2.0 - Vector2.ONE

				cafe_table.set_menu_parallax(norm)

		elif event is InputEventScreenDrag:

			var vp_rect = get_viewport().get_visible_rect()

			if vp_rect.size.x > 0 and vp_rect.size.y > 0:

				var norm = (event.position / vp_rect.size) * 2.0 - Vector2.ONE

				cafe_table.set_menu_parallax(norm)



func _on_ranked_breakout_exit_requested() -> void:
	print("[Main] User exited ranked match series.")
	_hide_backdrop()
	if is_instance_valid(ranked_breakout_dialog):
		ranked_breakout_dialog.dismiss()
	cafe_table.clear_board()
	cafe_table.reset_table_state()
	cafe_table.transition_to_menu_view(1.0)
	base_game_hud.reset_for_new_match()
	base_game_hud.visible = false
	menu_container.visible = true
	user_header.visible = true
	if is_instance_valid(cafe_table):
		cafe_table.visible = false
	user_header.update_ui()
	_update_ranked_button_state()
	GameManager.reset_match_state()
	GameManager.clear_open_game_id()
	GameManager.clear_open_pre_game_id()
	NetworkManager.leave_game()
	AudioManager.play_theme_music()

func _update_ranked_button_state() -> void:
	if not is_instance_valid(btn_ranked):
		return
	var title_lbl = ranked_title if is_instance_valid(ranked_title) else btn_ranked.get_node_or_null("Margin/HBox/TextCol/CardTitle")
	var sub_lbl = ranked_subtitle if is_instance_valid(ranked_subtitle) else btn_ranked.get_node_or_null("Margin/HBox/TextCol/CardSubtitle")
	
	if not GameManager.is_queue_open:
		if is_instance_valid(title_lbl):
			title_lbl.text = "⛔ رقابت دو نفره آنلاین (بسته است)"
		if is_instance_valid(sub_lbl):
			sub_lbl.text = "صف مسابقات رده‌بندی در حال حاضر بسته است."
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.60, 0.50, 1.0))
		btn_ranked.modulate = Color(0.85, 0.85, 0.85, 1.0)
		return
		
	var is_unlocked = GameManager.is_ranked_unlocked()
	
	if is_unlocked:
		if is_instance_valid(title_lbl):
			title_lbl.text = "رقابت دو نفره آنلاین"
		if is_instance_valid(sub_lbl):
			sub_lbl.text = "دوئل نفس‌گیر تن‌به‌تن، کسب کاپ و صعود به صدر جدول قهرمانان"
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
		btn_ranked.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		var prog = GameManager.get_ranked_unlock_progress()
		if is_instance_valid(title_lbl):
			title_lbl.text = "🔒 رقابت دو نفره آنلاین (رنک)"
		if is_instance_valid(sub_lbl):
			sub_lbl.text = "قفل است • بازگشایی در سطح ۳ (%s / %s XP)" % [GameManager.to_fa_num(prog.current_xp), GameManager.to_fa_num(prog.target_xp)]
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38, 1.0))
		btn_ranked.modulate = Color(0.92, 0.90, 0.88, 1.0)

func _show_ranked_locked_dialog() -> void:
	var prog = GameManager.get_ranked_unlock_progress()
	if not _ranked_locked_overlay or not is_instance_valid(_ranked_locked_overlay):
		_ranked_locked_overlay = Control.new()
		_ranked_locked_overlay.name = "RankedLockedOverlay"
		_ranked_locked_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ranked_locked_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_ranked_locked_overlay.z_index = 96

		var dark_bg = ColorRect.new()
		dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark_bg.color = Color(0.04, 0.02, 0.01, 0.82)
		dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
		dark_bg.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_close_ranked_locked_dialog()
		)
		_ranked_locked_overlay.add_child(dark_bg)

		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ranked_locked_overlay.add_child(center)

		_ranked_locked_panel = PanelContainer.new()
		_ranked_locked_panel.custom_minimum_size = Vector2(820, 520)
		_ranked_locked_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var style = StyleBoxTexture.new()
		style.texture = preload("res://assets/images/frames/board.png")
		style.texture_margin_left = 60.0
		style.texture_margin_top = 60.0
		style.texture_margin_right = 60.0
		style.texture_margin_bottom = 60.0
		_ranked_locked_panel.add_theme_stylebox_override("panel", style)
		center.add_child(_ranked_locked_panel)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 48)
		margin.add_theme_constant_override("margin_top", 40)
		margin.add_theme_constant_override("margin_right", 48)
		margin.add_theme_constant_override("margin_bottom", 40)
		_ranked_locked_panel.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 20)
		margin.add_child(vbox)

		var font_hekayat = preload("res://assets/fonts/hekayat.ttf")

		var lbl_title = Label.new()
		lbl_title.text = "🔒 بخش مسابقات رنک آنلاین قفل است"
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_title.add_theme_font_override("font", font_hekayat)
		lbl_title.add_theme_font_size_override("font_size", 44)
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl_title.add_theme_constant_override("shadow_outline_size", 3)
		vbox.add_child(lbl_title)

		var lbl_desc = Label.new()
		lbl_desc.text = "برای تضمین کیفیت مسابقات رده‌بندی و آشنایی با بازی‌ها،\nورود به مسابقات دونفره آنلاین پس از رسیدن به سطح ۳ (۱۶۰ XP) بازگشایی می‌شود."
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.custom_minimum_size = Vector2(680, 70)
		lbl_desc.add_theme_font_override("font", font_hekayat)
		lbl_desc.add_theme_font_size_override("font_size", 27)
		lbl_desc.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
		vbox.add_child(lbl_desc)

		# Progress Panel Box
		var prog_panel = PanelContainer.new()
		var prog_box_style = StyleBoxFlat.new()
		prog_box_style.bg_color = Color(0.10, 0.06, 0.04, 0.9)
		prog_box_style.border_width_left = 2
		prog_box_style.border_width_top = 2
		prog_box_style.border_width_right = 2
		prog_box_style.border_width_bottom = 2
		prog_box_style.border_color = Color(0.60, 0.45, 0.22, 0.85)
		prog_box_style.corner_radius_top_left = 14
		prog_box_style.corner_radius_top_right = 14
		prog_box_style.corner_radius_bottom_right = 14
		prog_box_style.corner_radius_bottom_left = 14
		prog_box_style.content_margin_left = 24.0
		prog_box_style.content_margin_top = 16.0
		prog_box_style.content_margin_right = 24.0
		prog_box_style.content_margin_bottom = 16.0
		prog_panel.add_theme_stylebox_override("panel", prog_box_style)
		vbox.add_child(prog_panel)

		var prog_vbox = VBoxContainer.new()
		prog_vbox.add_theme_constant_override("separation", 10)
		prog_panel.add_child(prog_vbox)

		var prog_row = HBoxContainer.new()
		prog_row.alignment = BoxContainer.ALIGNMENT_CENTER
		prog_vbox.add_child(prog_row)

		_ranked_locked_remain_lbl = Label.new()
		_ranked_locked_remain_lbl.text = ""
		_ranked_locked_remain_lbl.add_theme_font_override("font", font_hekayat)
		_ranked_locked_remain_lbl.add_theme_font_size_override("font_size", 24)
		_ranked_locked_remain_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
		prog_row.add_child(_ranked_locked_remain_lbl)

		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prog_row.add_child(spacer)

		var lvl_box = VBoxContainer.new()
		lvl_box.alignment = BoxContainer.ALIGNMENT_CENTER
		lvl_box.add_theme_constant_override("separation", 2)

		var level_icon = TextureRect.new()
		level_icon.texture = preload("res://assets/images/badges/level.png")
		level_icon.custom_minimum_size = Vector2(58, 66)
		level_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		level_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		level_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		level_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvl_box.add_child(level_icon)

		_ranked_locked_progress_lbl = Label.new()
		_ranked_locked_progress_lbl.text = ""
		_ranked_locked_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ranked_locked_progress_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_ranked_locked_progress_lbl.add_theme_font_override("font", font_hekayat)
		_ranked_locked_progress_lbl.add_theme_font_size_override("font_size", 24)
		_ranked_locked_progress_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))

		var lvl_pill = StyleBoxFlat.new()
		lvl_pill.bg_color = Color(0.10, 0.06, 0.03, 0.94)
		lvl_pill.border_color = Color(0.85, 0.68, 0.28, 0.88)
		lvl_pill.set_border_width_all(1)
		lvl_pill.set_corner_radius_all(10)
		lvl_pill.content_margin_left = 14
		lvl_pill.content_margin_right = 14
		lvl_pill.content_margin_top = 2
		lvl_pill.content_margin_bottom = 2
		_ranked_locked_progress_lbl.add_theme_stylebox_override("normal", lvl_pill)

		lvl_box.add_child(_ranked_locked_progress_lbl)

		prog_row.add_child(lvl_box)

		_ranked_locked_bar = ProgressBar.new()
		_ranked_locked_bar.custom_minimum_size = Vector2(0, 22)
		_ranked_locked_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ranked_locked_bar.show_percentage = false
		_ranked_locked_bar.min_value = 0.0
		_ranked_locked_bar.max_value = float(GameManager.MIN_RANKED_XP)
		_ranked_locked_bar.value = 0.0

		var bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.06, 0.04, 0.02, 0.95)
		bar_bg.corner_radius_top_left = 10
		bar_bg.corner_radius_top_right = 10
		bar_bg.corner_radius_bottom_right = 10
		bar_bg.corner_radius_bottom_left = 10
		bar_bg.border_width_left = 1
		bar_bg.border_width_top = 1
		bar_bg.border_width_right = 1
		bar_bg.border_width_bottom = 1
		bar_bg.border_color = Color(0.4, 0.3, 0.15, 0.8)
		_ranked_locked_bar.add_theme_stylebox_override("background", bar_bg)

		var bar_fill = StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.96, 0.76, 0.24, 1.0)
		bar_fill.corner_radius_top_left = 10
		bar_fill.corner_radius_top_right = 10
		bar_fill.corner_radius_bottom_right = 10
		bar_fill.corner_radius_bottom_left = 10
		_ranked_locked_bar.add_theme_stylebox_override("fill", bar_fill)
		prog_vbox.add_child(_ranked_locked_bar)

		# Tip Hint
		var lbl_hint = Label.new()
		lbl_hint.text = "💡 راهنما: با انجام ۳ تا ۵ بازی در «رنک تک‌نفره (ربات)» به راحتی تجربه کسب کرده و رنک را باز کنید!"
		lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_hint.custom_minimum_size = Vector2(680, 40)
		lbl_hint.add_theme_font_override("font", font_hekayat)
		lbl_hint.add_theme_font_size_override("font_size", 24)
		lbl_hint.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0, 0.95))
		vbox.add_child(lbl_hint)

		# Action Buttons Row
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 20)
		vbox.add_child(btn_hbox)

		var btn_play_bot = Button.new()
		btn_play_bot.text = "🎮 کسب XP در رنک تک‌نفره (ربات)"
		btn_play_bot.custom_minimum_size = Vector2(420, 102)
		btn_play_bot.add_theme_font_override("font", font_hekayat)
		btn_play_bot.add_theme_font_size_override("font_size", 30)
		KenneyUI.style_button(btn_play_bot, KenneyUI.COLOR_GREEN)
		btn_play_bot.pressed.connect(func():
			_close_ranked_locked_dialog(func():
				_on_classic_rank_pressed()
			)
		)
		btn_hbox.add_child(btn_play_bot)

		var btn_close = Button.new()
		btn_close.text = "متوجه شدم"
		btn_close.custom_minimum_size = Vector2(220, 102)
		btn_close.add_theme_font_override("font", font_hekayat)
		btn_close.add_theme_font_size_override("font_size", 28)
		KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREY)
		btn_close.pressed.connect(func():
			_close_ranked_locked_dialog()
		)
		btn_hbox.add_child(btn_close)

		ui_canvas.add_child(_ranked_locked_overlay)

	# Update dynamic values
	if is_instance_valid(_ranked_locked_progress_lbl):
		_ranked_locked_progress_lbl.text = "%s (%s / %s XP)" % [GameManager.to_fa_num(prog.current_level), GameManager.to_fa_num(prog.current_xp), GameManager.to_fa_num(prog.target_xp)]
	if is_instance_valid(_ranked_locked_remain_lbl):
		_ranked_locked_remain_lbl.text = "%s XP تا بازگشایی رنک" % [GameManager.to_fa_num(prog.remaining_xp)]
	if is_instance_valid(_ranked_locked_bar):
		_ranked_locked_bar.value = float(clamp(prog.current_xp, 0, prog.target_xp))

	_ranked_locked_overlay.visible = true
	ActionVFXManager.animate_dialog_open(_ranked_locked_panel, _ranked_locked_overlay, true)

func _close_ranked_locked_dialog(callback: Callable = Callable()) -> void:
	if not _ranked_locked_overlay or not is_instance_valid(_ranked_locked_overlay) or not _ranked_locked_overlay.visible:
		if callback.is_valid():
			callback.call()
		return
	ActionVFXManager.animate_dialog_close(_ranked_locked_panel, _ranked_locked_overlay, func():
		if is_instance_valid(_ranked_locked_overlay):
			_ranked_locked_overlay.visible = false
		_update_backdrop_state()
		if callback.is_valid():
			callback.call()
	)

var _force_update_overlay: Control = null
var _queue_closed_overlay: Control = null

func _show_force_update_dialog() -> void:
	if _force_update_overlay and is_instance_valid(_force_update_overlay):
		_force_update_overlay.visible = true
		return

	var ui_canvas = $CanvasLayer
	var font_hekayat = preload("res://assets/fonts/hekayat.ttf")

	_force_update_overlay = Control.new()
	_force_update_overlay.name = "ForceUpdateOverlay"
	_force_update_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_force_update_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_force_update_overlay.z_index = 100

	var dark_bg = ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0.04, 0.02, 0.01, 0.92)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_force_update_overlay.add_child(dark_bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_force_update_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 480)
	var panel_sb = StyleBoxTexture.new()
	panel_sb.texture = preload("res://assets/images/frames/board.png")
	panel_sb.texture_margin_left = 60.0
	panel_sb.texture_margin_top = 60.0
	panel_sb.texture_margin_right = 60.0
	panel_sb.texture_margin_bottom = 60.0
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "🔄 به‌روزرسانی اجباری"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_override("font", font_hekayat)
	lbl_title.add_theme_font_size_override("font_size", 42)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl_title.add_theme_constant_override("shadow_outline_size", 3)
	vbox.add_child(lbl_title)

	var lbl_msg = Label.new()
	lbl_msg.text = "نسخه جدیدی از بازی در دسترس است.\nلطفاً بازی را به روز رسانی کنید."
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_override("font", font_hekayat)
	lbl_msg.add_theme_font_size_override("font_size", 30)
	lbl_msg.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	vbox.add_child(lbl_msg)

	var btn_update = Button.new()
	btn_update.text = "به‌روزرسانی"
	btn_update.custom_minimum_size = Vector2(300, 90)
	btn_update.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_update.add_theme_font_override("font", font_hekayat)
	btn_update.add_theme_font_size_override("font_size", 34)
	KenneyUI.style_button(btn_update, KenneyUI.COLOR_GREEN)
	btn_update.pressed.connect(func():
		AudioManager.sfx_tap()
		OS.shell_open("https://myket.ir/app/kafeh.fekr.classic")
		get_tree().quit()
	)
	vbox.add_child(btn_update)

	ui_canvas.add_child(_force_update_overlay)
	ActionVFXManager.animate_dialog_open(panel, _force_update_overlay, true)

func _show_queue_closed_dialog() -> void:
	if _queue_closed_overlay and is_instance_valid(_queue_closed_overlay):
		_queue_closed_overlay.visible = true
		return

	var ui_canvas = $CanvasLayer
	var font_hekayat = preload("res://assets/fonts/hekayat.ttf")

	_queue_closed_overlay = Control.new()
	_queue_closed_overlay.name = "QueueClosedOverlay"
	_queue_closed_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_queue_closed_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_queue_closed_overlay.z_index = 97

	var dark_bg = ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0.04, 0.02, 0.01, 0.82)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dark_bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_queue_closed_dialog()
	)
	_queue_closed_overlay.add_child(dark_bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_queue_closed_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 420)
	var panel_sb = StyleBoxTexture.new()
	panel_sb.texture = preload("res://assets/images/frames/board.png")
	panel_sb.texture_margin_left = 60.0
	panel_sb.texture_margin_top = 60.0
	panel_sb.texture_margin_right = 60.0
	panel_sb.texture_margin_bottom = 60.0
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "⛔ صف رده‌بندی موقتاً بسته است"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_override("font", font_hekayat)
	lbl_title.add_theme_font_size_override("font_size", 38)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vbox.add_child(lbl_title)

	var lbl_msg = Label.new()
	lbl_msg.text = "صف مسابقات رده‌بندی در حال حاضر بسته است.\nلطفاً بعداً مراجعه نمایید."
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_override("font", font_hekayat)
	lbl_msg.add_theme_font_size_override("font_size", 28)
	lbl_msg.add_theme_color_override("font_color", Color(0.92, 0.86, 0.76))
	vbox.add_child(lbl_msg)

	var btn_ok = Button.new()
	btn_ok.text = "متوجه شدم"
	btn_ok.custom_minimum_size = Vector2(240, 80)
	btn_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_ok.add_theme_font_override("font", font_hekayat)
	btn_ok.add_theme_font_size_override("font_size", 30)
	KenneyUI.style_button(btn_ok, KenneyUI.COLOR_YELLOW)
	btn_ok.pressed.connect(func():
		AudioManager.sfx_tap()
		_close_queue_closed_dialog()
	)
	vbox.add_child(btn_ok)

	ui_canvas.add_child(_queue_closed_overlay)
	ActionVFXManager.animate_dialog_open(panel, _queue_closed_overlay, true)

func _close_queue_closed_dialog() -> void:
	if _queue_closed_overlay and is_instance_valid(_queue_closed_overlay):
		var center = _queue_closed_overlay.get_child(1) if _queue_closed_overlay.get_child_count() > 1 else null
		var panel = center.get_child(0) if center and center.get_child_count() > 0 else null
		ActionVFXManager.animate_dialog_close(panel, _queue_closed_overlay, func():
			_queue_closed_overlay.visible = false
		)

func _show_change_username_dialog() -> void:
	if not GameManager.is_logged_in:
		_show_menu_toast("ابتدا وارد حساب کاربری خود شوید.")
		return

	if _change_username_dialog and is_instance_valid(_change_username_dialog):
		_change_username_dialog.queue_free()

	var ui_canvas = $CanvasLayer
	var font_hekayat = preload("res://assets/fonts/hekayat.ttf")

	_change_username_dialog = Control.new()
	_change_username_dialog.name = "ChangeUsernameDialogOverlay"
	_change_username_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_change_username_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_change_username_dialog.z_index = 96

	var dark_bg = ColorRect.new()
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0.04, 0.02, 0.01, 0.85)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_change_username_dialog.add_child(dark_bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_change_username_dialog.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxTexture.new()
	style.texture = preload("res://assets/images/frames/board.png")
	style.texture_margin_left = 60.0
	style.texture_margin_top = 60.0
	style.texture_margin_right = 60.0
	style.texture_margin_bottom = 60.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var lbl_title = Label.new()
	lbl_title.text = "✏️ تغییر نام کاربری"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_override("font", font_hekayat)
	lbl_title.add_theme_font_size_override("font_size", 42)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl_title.add_theme_constant_override("shadow_outline_size", 3)
	vbox.add_child(lbl_title)

	var lbl_desc = Label.new()
	lbl_desc.text = "نام کاربری جدید خود را وارد کنید:"
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.add_theme_font_override("font", font_hekayat)
	lbl_desc.add_theme_font_size_override("font_size", 28)
	lbl_desc.add_theme_color_override("font_color", Color(0.92, 0.86, 0.76))
	vbox.add_child(lbl_desc)

	var input_name = LineEdit.new()
	input_name.custom_minimum_size = Vector2(500, 80)
	input_name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	input_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_name.text = GameManager.get_username()
	input_name.placeholder_text = "نام کاربری جدید..."
	input_name.max_length = 30
	input_name.add_theme_font_override("font", font_hekayat)
	input_name.add_theme_font_size_override("font_size", 32)
	input_name.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	var in_style = StyleBoxFlat.new()
	in_style.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	in_style.border_color = Color(0.85, 0.70, 0.35, 0.9)
	in_style.set_border_width_all(2)
	in_style.set_corner_radius_all(14)
	in_style.content_margin_left = 18
	in_style.content_margin_right = 18
	input_name.add_theme_stylebox_override("normal", in_style)
	vbox.add_child(input_name)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_hbox)

	var btn_confirm = Button.new()
	btn_confirm.text = "تأیید"
	btn_confirm.custom_minimum_size = Vector2(240, 84)
	btn_confirm.add_theme_font_override("font", font_hekayat)
	btn_confirm.add_theme_font_size_override("font_size", 32)
	KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_GREEN)
	btn_hbox.add_child(btn_confirm)

	var btn_cancel = Button.new()
	btn_cancel.text = "انصراف"
	btn_cancel.custom_minimum_size = Vector2(200, 84)
	btn_cancel.add_theme_font_override("font", font_hekayat)
	btn_cancel.add_theme_font_size_override("font_size", 30)
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_GREY)
	btn_hbox.add_child(btn_cancel)

	btn_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		_change_username_dialog.visible = false
	)

	btn_confirm.pressed.connect(func():
		var new_val = input_name.text.strip_edges()
		if new_val.length() < 3:
			_show_menu_toast("نام کاربری باید حداقل ۳ حرف باشد.")
			return
		if new_val == GameManager.get_username():
			_change_username_dialog.visible = false
			return

		AudioManager.sfx_button()
		btn_confirm.disabled = true
		btn_confirm.text = "در حال ذخیره..."

		NetworkManager.api.update_username(new_val, func(success: bool, resp_code: int, data: Variant):
			if not is_instance_valid(self):
				return
			if success:
				GameManager.update_username(new_val)
				if GameManager.get_coins() >= 75:
					GameManager.user_data["coin"] = GameManager.get_coins() - 75
					GameManager._save_session_config()
				user_header.update_ui()
				_show_menu_toast("✅ نام کاربری با موفقیت تغییر یافت.")
				if is_instance_valid(_change_username_dialog):
					_change_username_dialog.visible = false
			else:
				if is_instance_valid(btn_confirm):
					btn_confirm.disabled = false
					btn_confirm.text = "تأیید"
				if resp_code == 422:
					_show_menu_toast("سکه کافی ندارید (حداقل ۷۵ سکه نیاز است).")
				else:
					var err_msg = "خطا در تغییر نام کاربری."
					if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
						err_msg = str(data["detail"])
					_show_menu_toast(err_msg)
		)
	)

	ui_canvas.add_child(_change_username_dialog)
	ActionVFXManager.animate_dialog_open(panel, _change_username_dialog, true)
