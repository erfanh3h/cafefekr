class_name TutorialCoordinator
extends Node

## Master onboarding & tutorial orchestrator for Cafe Fekr.
## Coordinates two completely decoupled, extensible flows:
##
## 1. Pre-Login Offline Interactive Tic-Tac-Toe Tutorial
##    - Runs automatically on launch whenever the player is NOT logged in yet
##      (100% offline, zero NetworkManager emissions).
##    - Interactively teaches every top HUD button (2D/3D camera, Chat/Kori,
##      Emoji/Stickers, Settings/Menu, Opponent Card & Turn Timer) and how to
##      play & win Tic-Tac-Toe easily.
##    - Displays the real Win Dialog, then cleanly exits into the Auth Dialog.
##
## 2. Post-Auth One-Time Main Page Guided Tour
##    - Runs ONCE after authentication is completed (persisted via TutorialStore).
##    - Interactively showcases all 5 main bottom tabs (Play, Clan, Leaderboard,
##      Library, Profile) AND all 5 top buttons of the main page (Watch Live,
##      Match History, Friends, Notifications, Exit).

signal game_tutorial_finished()
signal main_tutorial_finished()

const TUTORIAL_BOARD_SCENE: PackedScene = preload("res://scenes/games/tictactoe/tutorial_tictactoe_3d.tscn")
const DEFAULT_RETURN_BTN_TEXT: String = "بازگشت به کافه"

var is_game_tutorial_active: bool = false
var is_main_tutorial_active: bool = false

var _overlay: TutorialCoachOverlay = null
var _cafe_table: Node = null
var _base_game_hud: Control = null
var _menu_container: Control = null
var _main_tab_shell: Control = null
var _board: TutorialTicTacToe3D = null

var _steps: Array[TutorialStep] = []
var _step_index: int = -1
var _active_flow: String = "" # "" | "game" | "main"
var _game_phase: String = ""  # "" | "hud_tour" | "move_1" | "move_2" | "move_3" | "win"
var _saved_return_btn_text: String = DEFAULT_RETURN_BTN_TEXT
var _session_token: int = 0

# Bound temporary signal callables for clean disconnect
var _view_toggle_cb: Callable = Callable()
var _reaction_cb: Callable = Callable()


func _ready() -> void:
	_overlay = TutorialCoachOverlay.new()
	_overlay.name = "TutorialCoachOverlay"
	add_child(_overlay)
	_overlay.next_pressed.connect(_on_overlay_next)
	_overlay.back_pressed.connect(_on_overlay_back)


# ==============================================================================
# PHASE 1: PRE-LOGIN OFFLINE INTERACTIVE TIC-TAC-TOE TUTORIAL
# ==============================================================================

func start_offline_game_tutorial(cafe_table: Node, base_game_hud: Control, menu_container: Control) -> void:
	if is_game_tutorial_active:
		return
	_stop_any_active_tour()

	_session_token += 1
	var my_token: int = _session_token
	is_game_tutorial_active = true
	_active_flow = "game"
	_game_phase = "hud_tour"

	_cafe_table = cafe_table
	_base_game_hud = base_game_hud
	_menu_container = menu_container

	# 1. Configure pure local offline match state in GameManager (no server IDs)
	GameManager.reset_match_state()
	GameManager.active_game_id = ""
	GameManager.current_game_type = GameTypes.TIC_TAC_TOE
	GameManager.current_round = 1
	GameManager.max_rounds = 1
	GameManager.p1_score = 0
	GameManager.p2_score = 0
	GameManager.my_player_index = 1
	GameManager.current_turn = 1
	GameManager.is_my_turn = true
	GameManager.is_game_active = true
	GameManager.is_spectating = false
	GameManager.match_players = [
		{
			"gamer_id": 1,
			"team_id": 1,
			"user_id": "tutorial_player",
			"name": "شما",
			"username": "شما",
			"image": 0,
			"level": 1,
			"score": 0,
			"not_played_turns": 0
		},
		{
			"gamer_id": 2,
			"team_id": 2,
			"user_id": "tutorial_bot",
			"name": "استاد کافه",
			"username": "استاد کافه",
			"image": 1,
			"level": 5,
			"score": 0,
			"not_played_turns": 0
		}
	]

	# 2. Switch UI cleanly into the 3D game table scene
	if is_instance_valid(_menu_container):
		_menu_container.visible = false
	if is_instance_valid(_cafe_table):
		_cafe_table.visible = true
		if _cafe_table.has_method("update_opponent_avatar"):
			_cafe_table.update_opponent_avatar(1)

	# 3. Prepare BaseGameHUD in offline tutorial mode
	if is_instance_valid(_base_game_hud):
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", true)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = true
		_base_game_hud.setup_match("دوز (آموزش)", "میز تمرینی کافه فکر")
		_base_game_hud.is_game_started = true
		_base_game_hud.is_start_overlay_dismissed = true
		_base_game_hud.force_dismiss_start_overlay(false)
		_base_game_hud.hide_turn_banner()
		_base_game_hud.update_turn(1)
		_base_game_hud.pause_turn_timer()
		if _base_game_hud.has_method("set_missed_turns_limit_visible"):
			_base_game_hud.set_missed_turns_limit_visible(false)
		if is_instance_valid(_base_game_hud.current_top_header) and _base_game_hud.current_top_header.has_method("update_timer"):
			_base_game_hud.current_top_header.update_timer(15.0, 15.0, 1)

	# 4. Spawn our inherited offline TutorialTicTacToe3D board onto CafeTable
	if is_instance_valid(_cafe_table) and _cafe_table.has_method("spawn_board"):
		var spawned: Node3D = _cafe_table.spawn_board(TUTORIAL_BOARD_SCENE)
		_board = spawned as TutorialTicTacToe3D

	if is_instance_valid(_board):
		_board.tutorial_input_enabled = false
		_board.tutorial_player_moved.connect(_on_tutorial_player_moved)
		_board.tutorial_bot_moved.connect(_on_tutorial_bot_moved)
		_board.tutorial_wrong_cell_tapped.connect(_on_tutorial_wrong_cell_tapped)
		_board.tutorial_player_won.connect(_on_tutorial_player_won)
		_board.tutorial_draw_reached.connect(_on_tutorial_draw_reached)

	AudioManager.play_game_music()

	# Hook optional interactive HUD feedback during the button tour
	_connect_game_tutorial_hud_listeners()

	# Wait briefly for the 3D camera intro glide & header layout to settle
	get_tree().create_timer(1.05).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or _session_token != my_token:
			return
		_steps = _build_game_tutorial_steps()
		_step_index = -1
		_advance_step()
	)


func _build_game_tutorial_steps() -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome modal
	var st_welcome: TutorialStep = TutorialStep.create(
		"game_welcome",
		"به کافه فکر خوش آمدید!",
		"قبل از ورود به حساب کاربری، بیایید در یک دست کوتاه و ساده دوز با تمام دکمه‌های صفحه بازی و روش بازی آشنا شویم."
	)
	st_welcome.with_badge("آموزش تعاملی")
	st_welcome.with_cta("شروع آموزش")
	st_welcome.with_placement("center")
	s.append(st_welcome)

	# 2. Top Button: 2D/3D Camera Toggle (interactive!)
	var st_view: TutorialStep = TutorialStep.create(
		"hud_view_2d3d",
		"تغییر زاویه دوربین (۳D / ۲D)",
		"با این دکمه می‌توانید هر زمان که بخواهید نمای میز بازی را بین حالت سه‌بعدی و نمای عمودی (دوبعدی) تغییر دهید. همین الان امتحانش کنید!"
	)
	st_view.with_badge("دکمه‌های بالای بازی")
	st_view.with_cta("بعدی")
	st_view.with_hint("همین الان روی دکمه ۳D/۲D بزنید یا «بعدی» را لمس کنید")
	st_view.with_target(func(): return _get_top_header_node("btn_view_2d3d"), 8.0, 16.0)
	st_view.with_avoid_rect(_get_game_header_avoid_rect)
	st_view.with_scrim_alpha(0.56)
	st_view.with_interactive(false, true)
	st_view.with_placement("bottom")
	s.append(st_view)

	# 3. Top Button: Quick Chat / Kori
	var st_chat: TutorialStep = TutorialStep.create(
		"hud_chat",
		"چت و کُری‌خوانی",
		"از این دکمه برای ارسال پیام‌های آماده، تشویق یا کُری‌خوانی دوستانه در طول مسابقه استفاده کنید."
	)
	st_chat.with_badge("دکمه‌های بالای بازی")
	st_chat.with_cta("بعدی")
	st_chat.with_target(func(): return _get_top_header_node("btn_chat"), 8.0, 16.0)
	st_chat.with_avoid_rect(_get_game_header_avoid_rect)
	st_chat.with_scrim_alpha(0.56)
	st_chat.with_placement("bottom")
	st_chat.with_hooks(_on_enter_chat_step)
	s.append(st_chat)

	# 4. Top Button: Emoji & Stickers
	var st_emoji: TutorialStep = TutorialStep.create(
		"hud_emoji",
		"استیکر و واکنش",
		"با این دکمه می‌توانید استیکرهای جذاب و واکنش‌های لحظه‌ای برای حریف ارسال کنید تا هیجان بازی دوچندان شود."
	)
	st_emoji.with_badge("دکمه‌های بالای بازی")
	st_emoji.with_cta("بعدی")
	st_emoji.with_target(func(): return _get_top_header_node("btn_emoji"), 8.0, 16.0)
	st_emoji.with_avoid_rect(_get_game_header_avoid_rect)
	st_emoji.with_scrim_alpha(0.56)
	st_emoji.with_placement("bottom")
	st_emoji.with_hooks(_on_enter_emoji_step)
	s.append(st_emoji)

	# 5. Top Button: Settings / Menu Drawer
	var st_settings: TutorialStep = TutorialStep.create(
		"hud_settings",
		"منو و تنظیمات بازی",
		"در این منو به تنظیمات صدا و موسیقی، خواندن قوانین بازی، غیرفعال‌سازی چت و گزینه انصراف از مسابقه دسترسی دارید."
	)
	st_settings.with_badge("دکمه‌های بالای بازی")
	st_settings.with_cta("بعدی")
	st_settings.with_target(func(): return _get_top_header_node("btn_settings"), 8.0, 16.0)
	st_settings.with_avoid_rect(_get_game_header_avoid_rect)
	st_settings.with_scrim_alpha(0.56)
	st_settings.with_placement("bottom")
	s.append(st_settings)

	# 6. Opponent Pod & Turn Timer Bar
	var st_timer: TutorialStep = TutorialStep.create(
		"hud_turn_and_timer",
		"نوبت بازیکن و نوار زمان",
		"در بالای صفحه مشخصات حریف دیده می‌شود و این نوار طلایی زمان باقی‌مانده نوبت شما را نشان می‌دهد. هرگاه نوار روشن باشد، نوبت حرکت شماست!"
	)
	st_timer.with_badge("نوار زمان و نوبت")
	st_timer.with_cta("بزن بریم بازی!")
	st_timer.with_target(_get_timer_bar_target, 10.0, 16.0)
	st_timer.with_avoid_rect(_get_game_header_avoid_rect)
	st_timer.with_scrim_alpha(0.56)
	st_timer.with_placement("bottom")
	st_timer.with_hooks(Callable(), _on_exit_timer_step)
	s.append(st_timer)

	# 7. Interactive Gameplay Move 1 — Guided Center Cell (Index 4)
	var st_move1: TutorialStep = TutorialStep.create(
		"play_move_1",
		"نوبت شماست! حرکت اول",
		"در بازی دوز باید ۳ مهره خودتان (X) را در یک ردیف افقی، عمودی یا مورب بچینید. برای شروع، خانه وسط را لمس کنید!"
	)
	st_move1.with_badge("آموزش بازی دوز")
	st_move1.with_hint("👆 روی خانه طلایی وسط صفحه لمس کنید")
	st_move1.with_target(func(): return _get_board_cell_rect(4), 8.0, 18.0)
	st_move1.with_avoid_rect(_get_board_screen_rect)
	st_move1.with_scrim_alpha(0.40)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_on_enter_move_1_step)
	s.append(st_move1)

	return s


func _on_enter_chat_step() -> void:
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_toast_hint("💬 نمونه کُری‌خوانی: «عجب حرکت هوشمندانه‌ای بود!»")


func _on_enter_emoji_step() -> void:
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_reaction(2, 1)


func _get_timer_bar_target() -> Control:
	var frame: Control = _get_top_header_node("timer_bar_frame")
	if is_instance_valid(frame) and frame.is_visible_in_tree():
		return frame
	return _get_top_header_node("local_turn_bar_wrap")


func _on_exit_timer_step() -> void:
	if is_instance_valid(_base_game_hud) and is_instance_valid(_base_game_hud.reaction_picker) and _base_game_hud.reaction_picker.visible:
		_base_game_hud.reaction_picker.close()


func _on_enter_move_1_step() -> void:
	_game_phase = "move_1"
	if is_instance_valid(_board):
		_board.tutorial_input_enabled = true
		_board.set_guided_cells([4])


func _on_tutorial_player_moved(cell_idx: int) -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return

	# Hide coach overlay while bot thinks so player enjoys the 3D piece drop
	_overlay.hide_overlay()
	_board.tutorial_input_enabled = false

	if _game_phase == "move_1":
		_game_phase = "bot_1"
		if is_instance_valid(_base_game_hud):
			_base_game_hud.update_turn(2)
			_base_game_hud.pause_turn_timer()
			_base_game_hud.show_toast_hint("عالی بود! حالا نوبت استاد کافه است...")
		# Bot places O in top-left corner (0), keeping row 3-4-5 completely open
		_board.trigger_easy_bot_move(0, 0.70)
	elif _game_phase == "move_2":
		_game_phase = "bot_2"
		if is_instance_valid(_base_game_hud):
			_base_game_hud.update_turn(2)
			_base_game_hud.pause_turn_timer()
			_base_game_hud.show_toast_hint("حرکت هوشمندانه! فقط یک قدم تا پیروزی...")
		# Bot places O in top-right corner (2), leaving cell 5 wide open for player's easy win!
		_board.trigger_easy_bot_move(2, 0.70)
	elif _game_phase == "move_3":
		# Player just tapped winning cell (or free move if somehow not yet won)
		if _board._check_winning_line(1).is_empty():
			_game_phase = "bot_free"
			if is_instance_valid(_base_game_hud):
				_base_game_hud.update_turn(2)
				_base_game_hud.pause_turn_timer()
			_board.trigger_easy_bot_move(-1, 0.65)
	elif _game_phase == "free_play":
		if _board._check_winning_line(1).is_empty():
			_game_phase = "bot_free"
			if is_instance_valid(_base_game_hud):
				_base_game_hud.update_turn(2)
				_base_game_hud.pause_turn_timer()
			_board.trigger_easy_bot_move(-1, 0.65)


func _on_tutorial_bot_moved(_cell_idx: int) -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return

	if is_instance_valid(_base_game_hud):
		_base_game_hud.update_turn(1)
		_base_game_hud.pause_turn_timer()
		if is_instance_valid(_base_game_hud.current_top_header) and _base_game_hud.current_top_header.has_method("update_timer"):
			_base_game_hud.current_top_header.update_timer(15.0, 15.0, 1)

	if _game_phase == "bot_1":
		_game_phase = "move_2"
		var next_cell: int = 3 if int(_board.board_state[3]) == 0 else _board.find_recommended_player_cell()
		var step2: TutorialStep = TutorialStep.create(
			"play_move_2",
			"حرکت دوم — ساخت ردیف برنده",
			"حریف مهره‌اش را گذاشت. حالا با انتخاب این خانه، دو مهره X کنار هم قرار می‌گیرند و برای پیروزی آماده می‌شوید!"
		)
		step2.with_badge("آموزش بازی دوز")
		step2.with_hint("👆 خانه طلایی مشخص‌شده را لمس کنید")
		step2.with_target(func(): return _get_board_cell_rect(next_cell), 8.0, 18.0)
		step2.with_avoid_rect(_get_board_screen_rect)
		step2.with_scrim_alpha(0.40)
		step2.with_interactive(true, false)
		step2.with_placement("auto")

		_board.tutorial_input_enabled = true
		_board.set_guided_cells([next_cell])
		_overlay.show_step(step2, 7, 9, false)

	elif _game_phase == "bot_2" or _game_phase == "bot_free":
		var win_cell: int = _board.find_recommended_player_cell()
		_game_phase = "move_3" if win_cell >= 0 else "free_play"
		var step3: TutorialStep = TutorialStep.create(
			"play_move_3",
			"ضربه نهایی — برنده شوید!",
			"یک حرکت تا پیروزی باقی مانده! این خانه را لمس کنید تا سه مهره شما در یک ردیف کامل شوند و برنده مسابقه شوید."
		)
		step3.with_badge("حرکت پیروزی!")
		step3.with_hint("🏆 روی خانه طلایی بزنید تا برنده شوید!")
		step3.with_target(func(): return _get_board_cell_rect(win_cell), 8.0, 18.0)
		step3.with_avoid_rect(_get_board_screen_rect)
		step3.with_scrim_alpha(0.40)
		step3.with_interactive(true, false)
		step3.with_placement("auto")

		_board.tutorial_input_enabled = true
		if win_cell >= 0:
			_board.set_guided_cells([win_cell])
		else:
			_board.clear_guided_cells()
		_overlay.show_step(step3, 8, 9, false)


func _on_tutorial_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_overlay):
		_overlay.show_nudge("برای تکمیل آموزش، خانه روشن و طلایی را لمس کنید")


func _on_tutorial_draw_reached() -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return
	# Safety net: guarantee the player always finishes with an easy victory
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_toast_hint("بیایید یک دست سریع دیگر برویم تا پیروز شوید!")
	get_tree().create_timer(0.9).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or not is_instance_valid(_board):
			return
		_board.reset_tutorial_match()
		_game_phase = "move_1"
		_board.tutorial_input_enabled = true
		_board.set_guided_cells([4])
		var retry_step: TutorialStep = TutorialStep.create(
			"play_retry",
			"شروع مجدد — خانه وسط را بزنید",
			"خانه وسط را لمس کنید تا خیلی راحت برنده شوید!"
		)
		retry_step.with_badge("آموزش بازی دوز")
		retry_step.with_hint("👆 خانه طلایی وسط را لمس کنید")
		retry_step.with_target(func(): return _get_board_cell_rect(4), 8.0, 18.0)
		retry_step.with_avoid_rect(_get_board_screen_rect)
		retry_step.with_scrim_alpha(0.40)
		retry_step.with_interactive(true, false)
		retry_step.with_placement("auto")
		_overlay.show_step(retry_step, 6, 9, false)
	)


func _on_tutorial_player_won(_winning_line: Array) -> void:
	if not is_game_tutorial_active:
		return
	var my_token: int = _session_token
	_game_phase = "win"
	_overlay.hide_overlay()
	TutorialStore.record_game_tutorial_win()

	GameManager.p1_score = 1
	GameManager.p2_score = 0
	if is_instance_valid(_base_game_hud):
		_base_game_hud.update_scores(1, 0)
		_base_game_hud.show_toast_hint("🎉 آفرین! شما برنده بازی آموزشی شدید!")

	# Let the golden winning laser beam & 3D victory effects shine briefly,
	# then show the real GameResultDialog (Win Dialog).
	get_tree().create_timer(1.15).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or _session_token != my_token:
			return
		if is_instance_valid(_base_game_hud):
			var rd: Control = _base_game_hud.result_dialog
			if is_instance_valid(rd) and is_instance_valid(rd.btn_return):
				_saved_return_btn_text = rd.btn_return.text
			_base_game_hud.show_game_result(1, 1, 0, 50, 25, 0, true)
			if is_instance_valid(rd):
				if is_instance_valid(rd.lbl_title):
					rd.lbl_title.text = "پیروزی درخشان!"
				if is_instance_valid(rd.lbl_subtitle):
					rd.lbl_subtitle.visible = true
					rd.lbl_subtitle.text = "آفرین! بازی دوز و امکانات صفحه بازی را یاد گرفتید. حالا وارد حساب کاربری شوید!"
				if is_instance_valid(rd.btn_return):
					rd.btn_return.text = "ورود به کافه فکر"
	)


func finish_offline_game_tutorial() -> void:
	if not is_game_tutorial_active:
		return
	_session_token += 1
	is_game_tutorial_active = false
	_active_flow = ""
	_game_phase = ""

	_disconnect_game_tutorial_hud_listeners()
	_overlay.hide_overlay()

	# Clean up board & 3D table
	if is_instance_valid(_cafe_table):
		if _cafe_table.has_method("clear_board"):
			_cafe_table.clear_board()
		if _cafe_table.has_method("reset_table_state"):
			_cafe_table.reset_table_state()
		if _cafe_table.has_method("transition_to_menu_view"):
			_cafe_table.transition_to_menu_view(0.4)
		_cafe_table.visible = false
	_board = null

	# Restore BaseGameHUD completely cleanly for future real online matches
	if is_instance_valid(_base_game_hud):
		if is_instance_valid(_base_game_hud.result_dialog) and is_instance_valid(_base_game_hud.result_dialog.btn_return):
			_base_game_hud.result_dialog.btn_return.text = _saved_return_btn_text if not _saved_return_btn_text.is_empty() else DEFAULT_RETURN_BTN_TEXT
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", false)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = false

	# Restore menu shell & clean GameManager match state
	if is_instance_valid(_menu_container):
		_menu_container.visible = true
	GameManager.reset_match_state()
	AudioManager.play_theme_music()

	game_tutorial_finished.emit()


func _connect_game_tutorial_hud_listeners() -> void:
	_disconnect_game_tutorial_hud_listeners()
	if is_instance_valid(_base_game_hud):
		_view_toggle_cb = func():
			if is_game_tutorial_active and _active_flow == "game" and _step_index >= 0 and _step_index < _steps.size():
				if _steps[_step_index].id == "hud_view_2d3d":
					if is_instance_valid(_base_game_hud):
						_base_game_hud.show_toast_hint("عالی! هر زمان خواستید می‌توانید بین نمای ۲D و ۳D جابه‌جا شوید.")
		if _base_game_hud.has_signal("top_view_requested") and not _base_game_hud.top_view_requested.is_connected(_view_toggle_cb):
			_base_game_hud.top_view_requested.connect(_view_toggle_cb)

		_reaction_cb = func(_r_id):
			if is_game_tutorial_active and is_instance_valid(_base_game_hud):
				_base_game_hud.show_toast_hint("آفرین! واکنش شما در بازی واقعی هم همین‌طور نمایش داده می‌شود.")
		if _base_game_hud.has_signal("reaction_sent") and not _base_game_hud.reaction_sent.is_connected(_reaction_cb):
			_base_game_hud.reaction_sent.connect(_reaction_cb)


func _disconnect_game_tutorial_hud_listeners() -> void:
	if is_instance_valid(_base_game_hud):
		if _view_toggle_cb.is_valid() and _base_game_hud.has_signal("top_view_requested") and _base_game_hud.top_view_requested.is_connected(_view_toggle_cb):
			_base_game_hud.top_view_requested.disconnect(_view_toggle_cb)
		if _reaction_cb.is_valid() and _base_game_hud.has_signal("reaction_sent") and _base_game_hud.reaction_sent.is_connected(_reaction_cb):
			_base_game_hud.reaction_sent.disconnect(_reaction_cb)
	_view_toggle_cb = Callable()
	_reaction_cb = Callable()


# ==============================================================================
# PHASE 2: POST-AUTH ONE-TIME MAIN PAGE GUIDED TOUR (5 TABS + TOP BUTTONS)
# ==============================================================================

func try_start_main_page_tutorial(main_tab_shell: Control) -> bool:
	if TutorialStore.is_main_tour_completed():
		return false
	if is_game_tutorial_active or is_main_tutorial_active:
		return false
	if not is_instance_valid(main_tab_shell) or not main_tab_shell.visible:
		return false

	_session_token += 1
	var my_token: int = _session_token
	is_main_tutorial_active = true
	_active_flow = "main"
	_main_tab_shell = main_tab_shell

	# Ensure we start cleanly on the Play tab
	if _main_tab_shell.has_method("close_subpage"):
		_main_tab_shell.close_subpage()
	if _main_tab_shell.has_method("switch_to_tab"):
		_main_tab_shell.switch_to_tab("play")

	# Wait briefly so layout & controls finalize their global rects
	get_tree().create_timer(0.35).timeout.connect(func():
		if not is_instance_valid(self) or not is_main_tutorial_active or _session_token != my_token:
			return
		_steps = _build_main_page_tutorial_steps()
		_step_index = -1
		_advance_step()
	)
	return true


func _build_main_page_tutorial_steps() -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome to Main Lobby
	var st_main_welcome: TutorialStep = TutorialStep.create(
		"main_welcome",
		"خوش آمدید به سالن کافه فکر!",
		"حساب کاربری شما آماده است. بیایید یک گشت سریع و یک‌باره در ۵ بخش اصلی و دکمه‌های بالای صفحه بزنیم."
	)
	st_main_welcome.with_badge("آشنایی با کافه فکر")
	st_main_welcome.with_cta("شروع گشت")
	st_main_welcome.with_placement("center")
	s.append(st_main_welcome)

	# --- 5 MAIN TABS (BottomNavigation) ---

	# 2. Tab: Play (بازی)
	var st_tab_play: TutorialStep = TutorialStep.create(
		"tab_play",
		"۱. بخش بازی (صفحه اصلی)",
		"اینجا مرکز رقابت‌های کافه فکر است! می‌توانید وارد رقابت ۱ به ۱، بازی‌های چندنفره، کلاسیک یا لابی دوستانه شوید."
	)
	st_tab_play.with_badge("تب‌های اصلی (۱ از ۵)")
	st_tab_play.with_cta("بعدی")
	st_tab_play.with_target(func(): return _get_bottom_nav_btn("btn_play"), 8.0, 16.0)
	st_tab_play.with_placement("top")
	st_tab_play.with_hooks(func(): _switch_main_tab("play"))
	s.append(st_tab_play)

	# 3. Tab: Social / Clan (اتحاد)
	var st_tab_social: TutorialStep = TutorialStep.create(
		"tab_social",
		"۲. بخش اتحاد (کلن)",
		"در بخش اتحاد می‌توانید کلن اختصاصی خودتان را بسازید یا به اتحاد دیگران بپیوندید، با هم‌تیمی‌ها چت کنید و با هم امتیاز بگیرید."
	)
	st_tab_social.with_badge("تب‌های اصلی (۲ از ۵)")
	st_tab_social.with_cta("بعدی")
	st_tab_social.with_target(func(): return _get_bottom_nav_btn("btn_social"), 8.0, 16.0)
	st_tab_social.with_placement("top")
	st_tab_social.with_hooks(func(): _switch_main_tab("social"))
	s.append(st_tab_social)

	# 4. Tab: Leaderboard (برترین‌ها)
	var st_tab_history: TutorialStep = TutorialStep.create(
		"tab_history",
		"۳. بخش برترین‌ها",
		"رتبه‌بندی برترین بازیکنان کافه فکر را اینجا ببینید و با کسب پیروزی‌های بیشتر، جایگاه خودتان را در جدول بالا ببرید."
	)
	st_tab_history.with_badge("تب‌های اصلی (۳ از ۵)")
	st_tab_history.with_cta("بعدی")
	st_tab_history.with_target(func(): return _get_bottom_nav_btn("btn_history"), 8.0, 16.0)
	st_tab_history.with_placement("top")
	st_tab_history.with_hooks(func(): _switch_main_tab("history"))
	s.append(st_tab_history)

	# 5. Tab: Library (کتابخانه)
	var st_tab_library: TutorialStep = TutorialStep.create(
		"tab_library",
		"۴. بخش کتابخانه بازی‌ها",
		"در کتابخانه می‌توانید با تمام بازی‌های فکری کافه فکر، قوانین، امتیازدهی و نکات هر بازی آشنا شوید."
	)
	st_tab_library.with_badge("تب‌های اصلی (۴ از ۵)")
	st_tab_library.with_cta("بعدی")
	st_tab_library.with_target(func(): return _get_bottom_nav_btn("btn_library"), 8.0, 16.0)
	st_tab_library.with_placement("top")
	st_tab_library.with_hooks(func(): _switch_main_tab("library"))
	s.append(st_tab_library)

	# 6. Tab: User Profile (کاربر)
	var st_tab_user: TutorialStep = TutorialStep.create(
		"tab_user",
		"۵. بخش پروفایل کاربری",
		"اینجا سطح، تجربه (XP)، سکه‌ها، آواتار و قاب اختصاصی خودتان را مدیریت می‌کنید و به فروشگاه و تنظیمات حساب دسترسی دارید."
	)
	st_tab_user.with_badge("تب‌های اصلی (۵ از ۵)")
	st_tab_user.with_cta("بعدی")
	st_tab_user.with_target(func(): return _get_bottom_nav_btn("btn_user"), 8.0, 16.0)
	st_tab_user.with_placement("top")
	st_tab_user.with_hooks(func(): _switch_main_tab("user"))
	s.append(st_tab_user)

	# --- TOP BUTTONS OF MAIN PAGE (PlayTab TopBarRow) ---

	# 7. Top Button: Watch Live (تماشای زنده)
	var st_top_watch: TutorialStep = TutorialStep.create(
		"top_watch_live",
		"تماشای زنده بازی‌ها",
		"با این دکمه می‌توانید مسابقات زنده بازیکنان حرفه‌ای را تماشا کنید و استراتژی‌های جدید یاد بگیرید."
	)
	st_top_watch.with_badge("دکمه‌های بالای صفحه")
	st_top_watch.with_cta("بعدی")
	st_top_watch.with_target(func(): return _get_play_tab_btn("btn_watch_live"), 8.0, 16.0)
	st_top_watch.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_watch.with_scrim_alpha(0.56)
	st_top_watch.with_placement("bottom")
	st_top_watch.with_hooks(_focus_play_tab_top)
	s.append(st_top_watch)

	# 8. Top Button: Match History (تاریخچه بازی‌ها)
	var st_top_history: TutorialStep = TutorialStep.create(
		"top_history",
		"تاریخچه بازی‌ها",
		"نتایج، امتیازات و جزئیات بازی‌های قبلی خودتان را هر زمان که بخواهید از اینجا بررسی کنید."
	)
	st_top_history.with_badge("دکمه‌های بالای صفحه")
	st_top_history.with_cta("بعدی")
	st_top_history.with_target(func(): return _get_play_tab_btn("btn_history"), 8.0, 14.0)
	st_top_history.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_history.with_scrim_alpha(0.56)
	st_top_history.with_placement("bottom")
	st_top_history.with_hooks(_focus_play_tab_top)
	s.append(st_top_history)

	# 9. Top Button: Friends & Direct Messages (دوستان و پیام‌ها)
	var st_top_friends: TutorialStep = TutorialStep.create(
		"top_friends",
		"دوستان و پیام‌های خصوصی",
		"لیست دوستان، درخواست‌های دوستی و گفتگوی خصوصی شما در این بخش قرار دارد. دوستانتان را به رقابت دعوت کنید!"
	)
	st_top_friends.with_badge("دکمه‌های بالای صفحه")
	st_top_friends.with_cta("بعدی")
	st_top_friends.with_target(func(): return _get_play_tab_btn("btn_friends"), 8.0, 14.0)
	st_top_friends.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_friends.with_scrim_alpha(0.56)
	st_top_friends.with_placement("bottom")
	st_top_friends.with_hooks(_focus_play_tab_top)
	s.append(st_top_friends)

	# 10. Top Button: Notifications (اعلان‌ها)
	var st_top_notif: TutorialStep = TutorialStep.create(
		"top_notifications",
		"اعلان‌ها و دعوت‌نامه‌ها",
		"همه دعوت‌های بازی، درخواست‌های دوستی و پیام‌های مهم سیستم در این بخش به شما اطلاع داده می‌شوند."
	)
	st_top_notif.with_badge("دکمه‌های بالای صفحه")
	st_top_notif.with_cta("بعدی")
	st_top_notif.with_target(func(): return _get_play_tab_btn("btn_notifications"), 8.0, 14.0)
	st_top_notif.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_notif.with_scrim_alpha(0.56)
	st_top_notif.with_placement("bottom")
	st_top_notif.with_hooks(_focus_play_tab_top)
	s.append(st_top_notif)

	# 11. Top Button: Exit (خروج)
	var st_top_exit: TutorialStep = TutorialStep.create(
		"top_exit",
		"دکمه خروج",
		"هر زمان خواستید از برنامه خارج شوید، از این دکمه استفاده کنید تا با تاییدیه ایمن از بازی خارج شوید."
	)
	st_top_exit.with_badge("دکمه‌های بالای صفحه")
	st_top_exit.with_cta("بعدی")
	st_top_exit.with_target(func(): return _get_play_tab_btn("btn_exit"), 8.0, 14.0)
	st_top_exit.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_exit.with_scrim_alpha(0.56)
	st_top_exit.with_placement("bottom")
	st_top_exit.with_hooks(_focus_play_tab_top)
	s.append(st_top_exit)

	# 12. Completion Card
	var st_main_done: TutorialStep = TutorialStep.create(
		"main_done",
		"آموزش کامل شد — آماده رقابتید!",
		"اکنون با تمام بخش‌های کافه فکر آشنا شدید. اولین مسابقه واقعی خودتان را انتخاب کنید و لذت ببرید!"
	)
	st_main_done.with_badge("پایان آموزش")
	st_main_done.with_cta("شروع رقابت!")
	st_main_done.with_placement("center")
	st_main_done.with_hooks(func(): _switch_main_tab("play"))
	s.append(st_main_done)

	return s


func _finish_main_page_tutorial() -> void:
	if not is_main_tutorial_active:
		return
	is_main_tutorial_active = false
	_active_flow = ""
	_overlay.hide_overlay()
	_switch_main_tab("play")
	TutorialStore.mark_main_tour_completed()
	main_tutorial_finished.emit()


func cancel_main_page_tutorial_if_active() -> void:
	if is_main_tutorial_active:
		is_main_tutorial_active = false
		_active_flow = ""
		_overlay.hide_overlay()


# ==============================================================================
# STEP ENGINE & TARGET RESOLVERS
# ==============================================================================

func _advance_step() -> void:
	if _step_index >= 0 and _step_index < _steps.size():
		var prev_step: TutorialStep = _steps[_step_index]
		if prev_step.on_exit.is_valid():
			prev_step.on_exit.call()

	_step_index += 1
	if _step_index >= _steps.size():
		if _active_flow == "main":
			_finish_main_page_tutorial()
		return

	_present_current_step()


func _go_back_step() -> void:
	if _step_index <= 0:
		return
	var curr_step: TutorialStep = _steps[_step_index]
	if curr_step.on_exit.is_valid():
		curr_step.on_exit.call()
	_step_index -= 1
	_present_current_step()


func _present_current_step() -> void:
	if _step_index < 0 or _step_index >= _steps.size():
		return
	var step: TutorialStep = _steps[_step_index]
	if step.on_enter.is_valid():
		step.on_enter.call()

	var total_display: int = 9 if _active_flow == "game" else _steps.size()
	var can_back: bool = (_active_flow == "main" and _step_index > 0) or (_active_flow == "game" and _step_index > 0 and _game_phase == "hud_tour")
	_overlay.show_step(step, _step_index, total_display, can_back)


func _on_overlay_next() -> void:
	if _active_flow == "game" or _active_flow == "main":
		_advance_step()


func _on_overlay_back() -> void:
	if _active_flow == "game" or _active_flow == "main":
		_go_back_step()


func _stop_any_active_tour() -> void:
	_disconnect_game_tutorial_hud_listeners()
	is_game_tutorial_active = false
	is_main_tutorial_active = false
	_active_flow = ""
	_game_phase = ""
	_steps.clear()
	_step_index = -1
	if is_instance_valid(_overlay):
		_overlay.hide_overlay()


func _get_top_header_node(prop_name: String) -> Control:
	if not is_instance_valid(_base_game_hud):
		return null
	var header: Node = _base_game_hud.get("current_top_header")
	if not is_instance_valid(header):
		return null
	var node: Variant = header.get(prop_name)
	if node is Control and is_instance_valid(node):
		return node as Control
	return null


func _get_board_cell_rect(cell_idx: int) -> Rect2:
	if not is_instance_valid(_board):
		return Rect2()
	return _board.get_cell_screen_rect(cell_idx)


func _get_board_screen_rect() -> Rect2:
	if not is_instance_valid(_board):
		return Rect2()
	return _board.get_board_screen_rect()


func _get_game_header_avoid_rect() -> Rect2:
	var combined := Rect2()
	var top_row: Control = _get_top_header_node("top_row")
	if is_instance_valid(top_row) and top_row.is_visible_in_tree():
		combined = top_row.get_global_rect()
	var timer_wrap: Control = _get_top_header_node("local_turn_bar_wrap")
	if is_instance_valid(timer_wrap) and timer_wrap.is_visible_in_tree():
		var tr: Rect2 = timer_wrap.get_global_rect()
		if tr.size.x > 1.0 and tr.size.y > 1.0:
			combined = tr if combined.size.x <= 1.0 else combined.merge(tr)
	return combined


func _focus_play_tab_top() -> void:
	_switch_main_tab("play")
	if not is_instance_valid(_main_tab_shell):
		return
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	if is_instance_valid(play_tab):
		var sc: ScrollContainer = play_tab.get_node_or_null("Scroll") as ScrollContainer
		if is_instance_valid(sc):
			sc.scroll_vertical = 0


func _get_play_topbar_avoid_rect() -> Rect2:
	if not is_instance_valid(_main_tab_shell):
		return Rect2()
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	if not is_instance_valid(play_tab):
		return Rect2()
	var top_bar: Control = play_tab.get_node_or_null("Scroll/Content/TopBarRow") as Control
	if is_instance_valid(top_bar) and top_bar.is_visible_in_tree():
		return top_bar.get_global_rect()
	return Rect2()


func _switch_main_tab(tab_name: String) -> void:
	if is_instance_valid(_main_tab_shell) and _main_tab_shell.has_method("switch_to_tab"):
		_main_tab_shell.switch_to_tab(tab_name)


func _get_bottom_nav_btn(prop_name: String) -> Control:
	if not is_instance_valid(_main_tab_shell):
		return null
	var nav: Node = _main_tab_shell.get("bottom_navigation")
	if not is_instance_valid(nav):
		return null
	var btn: Variant = nav.get(prop_name)
	if btn is Control and is_instance_valid(btn):
		return btn as Control
	return null


func _get_play_tab_btn(prop_name: String) -> Control:
	if not is_instance_valid(_main_tab_shell):
		return null
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	elif _main_tab_shell.has_method("get_active_tab_instance"):
		play_tab = _main_tab_shell.call("get_active_tab_instance") as Control
	if not is_instance_valid(play_tab):
		return null
	var btn: Variant = play_tab.get(prop_name)
	if btn is Control and is_instance_valid(btn):
		return btn as Control
	return null
