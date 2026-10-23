extends Control

const BaseTopHeaderClass = preload("res://scenes/games/base/base_top_header.gd")

# Base Game HUD
# Shared in-game HUD for all Cafe Fekr games (TicTacToe, Chess, Backgammon, etc.)
# Displays player profiles, turn statuses, real-time turn countdown timer,
# pre-game countdown match intro, live reaction bubbles, and bottom controls

signal leave_game_requested()
signal surrender_requested()
signal reaction_sent(reaction_id: int)
signal start_countdown_finished()
signal fekrbekr_submit_pressed()
signal fekrbekr_clear_pressed()
signal fekrbekr_opponent_view_pressed()
signal fekrbekr_dual_view_pressed()
signal zoom_in_requested()
signal zoom_out_requested()
signal reset_camera_requested()
signal top_view_requested()

# --- Bottom Controls & Camera Dock ---
@onready var btn_surrender: Button = $BottomBar/Margin/HBox/BtnSurrender
@onready var btn_reactions: Button = $BottomBar/Margin/HBox/BtnReactions
@onready var btn_zoom_in: Button = $BottomBar/Margin/HBox/BtnZoomIn
@onready var btn_zoom_out: Button = $BottomBar/Margin/HBox/BtnZoomOut
@onready var btn_cam_top: Button = $BottomBar/Margin/HBox/BtnCamTop
@onready var btn_cam_reset: Button = $BottomBar/Margin/HBox/BtnCamReset
@onready var btn_audio: Button = $BottomBar/Margin/HBox/BtnAudio
@onready var img_audio: TextureRect = $BottomBar/Margin/HBox/BtnAudio/Icon

# --- FekrBekr Dedicated HUD Action Buttons (Center-Right Vertical Column) ---
@onready var fekrbekr_actions: Control = $FekrBekrActions
@onready var btn_fekr_submit: Button = $FekrBekrActions/VBox/BtnFekrSubmit
@onready var btn_fekr_clear: Button = $FekrBekrActions/VBox/BtnFekrClear
@onready var btn_fekr_opp: Button = $FekrBekrActions/VBox/BtnFekrOpponent
@onready var btn_fekr_dual: Button = $FekrBekrActions/VBox/BtnFekrDual

# --- Top Header Slot & Dynamic Header Component ---
@onready var top_header_slot: Control = $TopHeaderSlot
var current_top_header: BaseTopHeaderClass = null

# Seamless backwards-compatible delegates to active top header
var p1_card: PanelContainer:
	get: return current_top_header.p1_card if is_instance_valid(current_top_header) else null
var p1_avatar: TextureRect:
	get: return current_top_header.p1_avatar if is_instance_valid(current_top_header) else null
var p1_name: Label:
	get: return current_top_header.p1_name if is_instance_valid(current_top_header) else null
var p1_role_badge: Label:
	get: return current_top_header.p1_role_badge if is_instance_valid(current_top_header) else null
var p1_score_lbl: Label:
	get: return current_top_header.p1_score_lbl if is_instance_valid(current_top_header) else null
var p1_missed_turns_box: HBoxContainer:
	get: return current_top_header.get("p1_missed_turns_box") if is_instance_valid(current_top_header) else null
var p1_dot1: Panel:
	get: return current_top_header.get("p1_dot1") if is_instance_valid(current_top_header) else null
var p1_dot2: Panel:
	get: return current_top_header.get("p1_dot2") if is_instance_valid(current_top_header) else null
var p1_dot3: Panel:
	get: return current_top_header.get("p1_dot3") if is_instance_valid(current_top_header) else null
var p1_strike_count_lbl: Label:
	get: return current_top_header.get("p1_strike_count_lbl") if is_instance_valid(current_top_header) else null
var p1_reaction_bubble: Control:
	get: return current_top_header.p1_reaction_bubble if is_instance_valid(current_top_header) else null
var p1_reaction_icon: TextureRect:
	get: return current_top_header.p1_reaction_icon if is_instance_valid(current_top_header) else null

var p2_card: PanelContainer:
	get: return current_top_header.p2_card if is_instance_valid(current_top_header) else null
var p2_avatar: TextureRect:
	get: return current_top_header.p2_avatar if is_instance_valid(current_top_header) else null
var p2_name: Label:
	get: return current_top_header.p2_name if is_instance_valid(current_top_header) else null
var p2_role_badge: Label:
	get: return current_top_header.p2_role_badge if is_instance_valid(current_top_header) else null
var p2_score_lbl: Label:
	get: return current_top_header.p2_score_lbl if is_instance_valid(current_top_header) else null
var p2_missed_turns_box: HBoxContainer:
	get: return current_top_header.get("p2_missed_turns_box") if is_instance_valid(current_top_header) else null
var p2_dot1: Panel:
	get: return current_top_header.get("p2_dot1") if is_instance_valid(current_top_header) else null
var p2_dot2: Panel:
	get: return current_top_header.get("p2_dot2") if is_instance_valid(current_top_header) else null
var p2_dot3: Panel:
	get: return current_top_header.get("p2_dot3") if is_instance_valid(current_top_header) else null
var p2_strike_count_lbl: Label:
	get: return current_top_header.get("p2_strike_count_lbl") if is_instance_valid(current_top_header) else null
var p2_reaction_bubble: Control:
	get: return current_top_header.p2_reaction_bubble if is_instance_valid(current_top_header) else null
var p2_reaction_icon: TextureRect:
	get: return current_top_header.p2_reaction_icon if is_instance_valid(current_top_header) else null

var match_details_box: PanelContainer:
	get: return current_top_header.match_details_box if is_instance_valid(current_top_header) else null
var lbl_round: Label:
	get: return current_top_header.lbl_round if is_instance_valid(current_top_header) else null
var lbl_turn_banner: Label:
	get: return current_top_header.lbl_turn_banner if is_instance_valid(current_top_header) else null
var lbl_timer: Label:
	get: return current_top_header.lbl_timer if is_instance_valid(current_top_header) else null
var turn_timer_bar: ProgressBar:
	get: return current_top_header.turn_timer_bar if is_instance_valid(current_top_header) else null
var afk_rule_row: HBoxContainer:
	get: return current_top_header.get("afk_rule_row") if is_instance_valid(current_top_header) else null
var lbl_afk_rule: Label:
	get: return current_top_header.get("lbl_afk_rule") if is_instance_valid(current_top_header) else null

var btn_p1_profile: Button:
	get: return current_top_header.btn_p1_profile if is_instance_valid(current_top_header) else null
var btn_p2_profile: Button:
	get: return current_top_header.btn_p2_profile if is_instance_valid(current_top_header) else null

# --- Surrender Dialog ---
@onready var surrender_dialog: Control = $SurrenderDialog
@onready var surrender_card: PanelContainer = $SurrenderDialog/Card
@onready var btn_confirm_surrender: Button = $SurrenderDialog/Card/VBox/BtnHBox/BtnConfirmSurrender
@onready var btn_cancel_surrender: Button = $SurrenderDialog/Card/VBox/BtnHBox/BtnCancelSurrender

# --- Disconnect / Auto-Pause Dialog ---
@onready var pause_dialog: Control = $DisconnectPauseDialog
@onready var pause_card: PanelContainer = $DisconnectPauseDialog/Card
@onready var lbl_pause_title: Label = $DisconnectPauseDialog/Card/VBox/Title
@onready var lbl_pause_desc: Label = $DisconnectPauseDialog/Card/VBox/Desc
@onready var pause_timer_bar: ProgressBar = $DisconnectPauseDialog/Card/VBox/TimerBar
@onready var lbl_pause_countdown: Label = $DisconnectPauseDialog/Card/VBox/Countdown

# --- Pre-Game Match Intro & Loading Countdown ---
@onready var start_overlay: Control = $StartGameOverlay
@onready var intro_card: PanelContainer = $StartGameOverlay/Card
@onready var intro_cafe_title: Label = $StartGameOverlay/Card/VBox/CafeTitle
@onready var intro_game_title: Label = $StartGameOverlay/Card/VBox/GameTitle
@onready var intro_p1_avatar: TextureRect = $StartGameOverlay/Card/VBox/VSBox/IntroP1/Avatar
@onready var intro_p1_name: Label = $StartGameOverlay/Card/VBox/VSBox/IntroP1/Name
@onready var intro_p1_role: Label = $StartGameOverlay/Card/VBox/VSBox/IntroP1/Role
@onready var intro_p2_avatar: TextureRect = $StartGameOverlay/Card/VBox/VSBox/IntroP2/Avatar
@onready var intro_p2_name: Label = $StartGameOverlay/Card/VBox/VSBox/IntroP2/Name
@onready var intro_p2_role: Label = $StartGameOverlay/Card/VBox/VSBox/IntroP2/Role
@onready var intro_countdown_lbl: Label = $StartGameOverlay/Card/VBox/Countdown
@onready var intro_status_lbl: Label = $StartGameOverlay/Card/VBox/Status

# --- Popups ---
@onready var reaction_picker: Control = $ReactionPicker
@onready var result_dialog: Control = $GameResultDialog
@onready var user_profile_dialog: Control = $UserProfileDialog

# (Avatar Profile Buttons delegated to BaseTopHeader via getters)

# --- Round Finish & Toast Notifications ---
@onready var round_finish_banner: Control = $RoundFinishBanner
@onready var round_finish_card: PanelContainer = $RoundFinishBanner/Card
@onready var round_finish_title: Label = $RoundFinishBanner/Card/VBox/RoundTitle
@onready var round_finish_desc: Label = $RoundFinishBanner/Card/VBox/WinnerDesc
@onready var round_finish_score: Label = $RoundFinishBanner/Card/VBox/ScoreRow
@onready var toast_hint: PanelContainer = $ToastHint
@onready var lbl_toast: Label = $ToastHint/LblToast

# Turn Timer Settings
var turn_duration: float = 10.0
var turn_time_left: float = 10.0
var is_timer_active: bool = false
var is_round_finished: bool = false
var last_second_ticked: int = -1
var is_game_started: bool = false
var is_game_finished: bool = false
var is_start_overlay_dismissed: bool = false
var is_countdown_running: bool = false

# Disconnect Pause Timer
var is_pause_active: bool = false
var pause_time_left: float = 30.0
var pause_total_time: float = 30.0
var _last_pause_sec_ticked: int = -1

# Audio icons (White UI)
var _sound_on_tex = preload("res://assets/icons/General/soundOn_white.png")
var _sound_off_tex = preload("res://assets/icons/General/soundOff_white.png")

# Card and Timer Styles
var _style_p1_active: StyleBoxFlat
var _style_p1_inactive: StyleBoxFlat
var _style_p2_active: StyleBoxFlat
var _style_p2_inactive: StyleBoxFlat
var _timer_style_fill: StyleBoxFlat
var _dot_style_empty: StyleBoxFlat
var _dot_style_warning: StyleBoxFlat
var _dot_style_danger: StyleBoxFlat
var _turn_glow_tween: Tween = null
var _toast_tween: Tween = null
var _loading_pulse_tween: Tween = null

# Checks if missed turns limit rule is active for current game session or board
func has_missed_turns_limit_active(game_type_hint: String = "") -> bool:
	var g_type = game_type_hint if not game_type_hint.is_empty() else GameManager.current_game_type
	var cafe_table = get_parent()
	if cafe_table and "current_board_node" in cafe_table and is_instance_valid(cafe_table.current_board_node):
		var board = cafe_table.current_board_node
		if "has_missed_turns_limit" in board:
			return bool(board.has_missed_turns_limit)
	var boards = get_tree().get_nodes_in_group("board")
	for b in boards:
		if is_instance_valid(b) and "has_missed_turns_limit" in b:
			return bool(b.has_missed_turns_limit)
	return GameRegistry.has_missed_turns_limit(g_type)

# Toggles visibility of all missed turn limit indicators across the HUD
func set_missed_turns_limit_visible(enabled: bool) -> void:
	if is_instance_valid(afk_rule_row):
		afk_rule_row.visible = enabled
	if is_instance_valid(p1_missed_turns_box):
		p1_missed_turns_box.visible = enabled
	if is_instance_valid(p2_missed_turns_box):
		p2_missed_turns_box.visible = enabled

func _ensure_top_header_for_current_game() -> void:
	if not is_instance_valid(top_header_slot):
		return
	var header_scene = GameRegistry.get_top_header_packed_scene(GameManager.current_game_type)
	if not is_instance_valid(current_top_header) or current_top_header.scene_file_path != header_scene.resource_path:
		if is_instance_valid(current_top_header):
			current_top_header.queue_free()
		current_top_header = header_scene.instantiate() as BaseTopHeaderClass
		top_header_slot.add_child(current_top_header)
		current_top_header.p1_profile_clicked.connect(func(): _show_player_profile(1))
		current_top_header.p2_profile_clicked.connect(func(): _show_player_profile(2))

func _ready() -> void:
	_ensure_top_header_for_current_game()
	_setup_card_styles()
	_setup_connections()
	surrender_dialog.visible = false
	start_overlay.visible = false
	round_finish_banner.visible = false
	if _toast_tween and is_instance_valid(_toast_tween):
		_toast_tween.kill()
		_toast_tween = null
	toast_hint.visible = false
	pause_dialog.visible = false
	_update_audio_visual()
	
	# Default to hidden; dynamically enabled only for games with AFK rules (e.g. Chess)
	set_missed_turns_limit_visible(false)
	
	is_game_finished = false
	is_game_started = false
	is_timer_active = false
	lbl_turn_banner.text = "بازی درحال آغاز است"
	lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)
	turn_duration = def_time
	turn_time_left = def_time
	lbl_timer.text = "%02d ثانیه" % int(def_time)
	turn_timer_bar.value = 100.0

func _process(delta: float) -> void:
	if is_pause_active:
		pause_time_left = max(0.0, pause_time_left - delta)
		var p_sec = int(ceil(pause_time_left))
		if p_sec != _last_pause_sec_ticked:
			_last_pause_sec_ticked = p_sec
			lbl_pause_countdown.text = "⏳ مهلت بازگشت به بازی: %d ثانیه" % p_sec
		if pause_total_time > 0:
			pause_timer_bar.value = (pause_time_left / pause_total_time) * 100.0

	if is_game_finished or is_round_finished or (round_finish_banner and round_finish_banner.visible):
		return

	if is_timer_active and is_game_started and not is_pause_active and not is_round_finished:
		turn_time_left = max(0.0, turn_time_left - delta)
		var sec = int(ceil(turn_time_left))
		if is_instance_valid(current_top_header):
			current_top_header.update_timer(turn_time_left, turn_duration, GameManager.current_turn)
		if turn_time_left <= 3.0 and turn_time_left > 0.0:
			if sec != last_second_ticked:
				last_second_ticked = sec
				if (GameManager.is_my_turn or not GameManager.is_game_active) and not is_game_finished and not is_round_finished:
					AudioManager.play_sound("time")

func _setup_card_styles() -> void:
	# P1 (Red Player) Active Style (Glowing & Vibrant)
	_style_p1_active = StyleBoxFlat.new()
	_style_p1_active.bg_color = Color(0.24, 0.08, 0.08, 0.98)
	_style_p1_active.border_color = Color(1.0, 0.35, 0.4, 1.0) # Radiant Crimson Red Border
	_style_p1_active.set_border_width_all(4)
	_style_p1_active.set_corner_radius_all(22)
	_style_p1_active.shadow_color = Color(1.0, 0.2, 0.25, 0.7)
	_style_p1_active.shadow_size = 18
	_style_p1_active.shadow_offset = Vector2(0, 4)
	_style_p1_active.content_margin_left = 14
	_style_p1_active.content_margin_right = 14
	_style_p1_active.content_margin_top = 10
	_style_p1_active.content_margin_bottom = 10

	# P1 (Red Player) Idle Style (Muted, Dimmed, No Glow)
	_style_p1_inactive = StyleBoxFlat.new()
	_style_p1_inactive.bg_color = Color(0.11, 0.06, 0.06, 0.75)
	_style_p1_inactive.border_color = Color(0.28, 0.14, 0.14, 0.35)
	_style_p1_inactive.set_border_width_all(1)
	_style_p1_inactive.set_corner_radius_all(22)
	_style_p1_inactive.shadow_color = Color(0, 0, 0, 0.0)
	_style_p1_inactive.shadow_size = 0
	_style_p1_inactive.content_margin_left = 14
	_style_p1_inactive.content_margin_right = 14
	_style_p1_inactive.content_margin_top = 10
	_style_p1_inactive.content_margin_bottom = 10

	# P2 (Blue Player) Active Style (Glowing & Vibrant)
	_style_p2_active = StyleBoxFlat.new()
	_style_p2_active.bg_color = Color(0.08, 0.15, 0.28, 0.98)
	_style_p2_active.border_color = Color(0.32, 0.75, 1.0, 1.0) # Radiant Sapphire Blue Border
	_style_p2_active.set_border_width_all(4)
	_style_p2_active.set_corner_radius_all(22)
	_style_p2_active.shadow_color = Color(0.2, 0.6, 1.0, 0.7)
	_style_p2_active.shadow_size = 18
	_style_p2_active.shadow_offset = Vector2(0, 4)
	_style_p2_active.content_margin_left = 14
	_style_p2_active.content_margin_right = 14
	_style_p2_active.content_margin_top = 10
	_style_p2_active.content_margin_bottom = 10

	# P2 (Blue Player) Idle Style (Muted, Dimmed, No Glow)
	_style_p2_inactive = StyleBoxFlat.new()
	_style_p2_inactive.bg_color = Color(0.06, 0.08, 0.12, 0.75)
	_style_p2_inactive.border_color = Color(0.14, 0.22, 0.32, 0.35)
	_style_p2_inactive.set_border_width_all(1)
	_style_p2_inactive.set_corner_radius_all(22)
	_style_p2_inactive.shadow_color = Color(0, 0, 0, 0.0)
	_style_p2_inactive.shadow_size = 0
	_style_p2_inactive.content_margin_left = 14
	_style_p2_inactive.content_margin_right = 14
	_style_p2_inactive.content_margin_top = 10
	_style_p2_inactive.content_margin_bottom = 10

	# Fill stylebox is managed directly by current_top_header (BaseTopHeader or game-specific header)

	# Missed Turns Strike Dot Styles
	_dot_style_empty = StyleBoxFlat.new()
	_dot_style_empty.bg_color = Color(0.22, 0.16, 0.12, 0.65)
	_dot_style_empty.border_color = Color(0.50, 0.38, 0.25, 0.85)
	_dot_style_empty.set_border_width_all(1)
	_dot_style_empty.set_corner_radius_all(7)

	_dot_style_warning = StyleBoxFlat.new()
	_dot_style_warning.bg_color = Color(1.0, 0.75, 0.20, 1.0)
	_dot_style_warning.border_color = Color(1.0, 0.90, 0.50, 1.0)
	_dot_style_warning.set_border_width_all(2)
	_dot_style_warning.set_corner_radius_all(7)
	_dot_style_warning.shadow_color = Color(1.0, 0.65, 0.1, 0.6)
	_dot_style_warning.shadow_size = 4

	_dot_style_danger = StyleBoxFlat.new()
	_dot_style_danger.bg_color = Color(1.0, 0.18, 0.22, 1.0)
	_dot_style_danger.border_color = Color(1.0, 0.60, 0.60, 1.0)
	_dot_style_danger.set_border_width_all(2)
	_dot_style_danger.set_corner_radius_all(7)
	_dot_style_danger.shadow_color = Color(1.0, 0.15, 0.2, 0.85)
	_dot_style_danger.shadow_size = 6

func _setup_connections() -> void:
	# Kenney UI Tactile Game Buttons & Action Juice
	KenneyUI.style_button(btn_zoom_in, KenneyUI.COLOR_YELLOW)
	KenneyUI.style_button(btn_zoom_out, KenneyUI.COLOR_YELLOW)
	KenneyUI.style_button(btn_cam_top, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_cam_reset, KenneyUI.COLOR_GREY)
	KenneyUI.style_button(btn_surrender, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_reactions, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_audio, KenneyUI.COLOR_GREY)
	KenneyUI.style_button(btn_confirm_surrender, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_cancel_surrender, KenneyUI.COLOR_RED)
	
	btn_zoom_in.text = ""
	btn_zoom_out.text = ""
	btn_cam_reset.text = ""
	btn_surrender.text = ""
	btn_reactions.text = ""
	btn_audio.text = ""
	
	btn_cam_top.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	btn_cam_top.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn_cam_top.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9, 1.0))
	btn_cam_top.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	btn_cam_top.add_theme_constant_override("shadow_offset_y", 2)
	btn_cam_top.add_theme_font_size_override("font_size", 34)
	
	var all_btns = [btn_zoom_in, btn_zoom_out, btn_cam_top, btn_cam_reset, btn_surrender, btn_reactions, btn_audio]
	for b in all_btns:
		b.pivot_offset = b.custom_minimum_size / 2.0
		ActionVFXManager.apply_button_juice(b, "tap_button")
	
	btn_surrender.pressed.connect(func():
		if not GameManager.is_game_active:
			show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
			return
		AudioManager.sfx_button()
		_open_surrender_dialog()
	)
	
	btn_confirm_surrender.pressed.connect(func():
		AudioManager.sfx_button()
		_close_surrender_dialog()
		surrender_requested.emit()
	)
	
	btn_cancel_surrender.pressed.connect(func():
		AudioManager.sfx_button()
		_close_surrender_dialog()
	)
	
	btn_reactions.pressed.connect(func():
		if not GameManager.is_game_active:
			show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
			return
		AudioManager.sfx_button()
		reaction_picker.open()
	)
	
	btn_audio.pressed.connect(func():
		var new_state = not AudioManager.is_music_enabled
		AudioManager.set_music_enabled(new_state)
		AudioManager.set_sound_enabled(new_state)
		AudioManager.sfx_tap()
		_update_audio_visual()
	)
	
	# Style FekrBekr Center-Right HUD Action Buttons
	if is_instance_valid(btn_fekr_submit):
		KenneyUI.style_button(btn_fekr_submit, KenneyUI.COLOR_GREEN)
		KenneyUI.style_button(btn_fekr_clear, KenneyUI.COLOR_RED)
		KenneyUI.style_button(btn_fekr_opp, KenneyUI.COLOR_BLUE)
		KenneyUI.style_button(btn_fekr_dual, KenneyUI.COLOR_YELLOW)
		btn_fekr_submit.text = ""
		btn_fekr_clear.text = ""
		btn_fekr_opp.text = ""
		btn_fekr_dual.text = ""
		var fekr_btns = [btn_fekr_submit, btn_fekr_clear, btn_fekr_opp, btn_fekr_dual]
		for b in fekr_btns:
			b.pivot_offset = b.custom_minimum_size / 2.0
			ActionVFXManager.apply_button_juice(b, "tap_button")
		btn_fekr_submit.pressed.connect(func():
			if not GameManager.is_game_active:
				show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
				return
			AudioManager.sfx_button()
			fekrbekr_submit_pressed.emit()
		)
		btn_fekr_clear.pressed.connect(func():
			if not GameManager.is_game_active:
				show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
				return
			AudioManager.sfx_button()
			fekrbekr_clear_pressed.emit()
		)
		btn_fekr_opp.pressed.connect(func():
			if not GameManager.is_game_active:
				show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
				return
			AudioManager.sfx_button()
			fekrbekr_opponent_view_pressed.emit()
		)
		btn_fekr_dual.pressed.connect(func():
			if not GameManager.is_game_active:
				show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
				return
			AudioManager.sfx_button()
			fekrbekr_dual_view_pressed.emit()
		)
	
	reaction_picker.reaction_selected.connect(func(r_id):
		NetworkManager.send_game_reaction(r_id)
		show_reaction(GameManager.my_player_index, r_id)
		reaction_sent.emit(r_id)
	)
	
	result_dialog.return_to_menu_requested.connect(func():
		leave_game_requested.emit()
	)
	
	# Profile buttons connected via BaseTopHeader signals (p1_profile_clicked / p2_profile_clicked)
	
	btn_zoom_in.pressed.connect(func():
		AudioManager.sfx_tap()
		zoom_in_requested.emit()
	)
	btn_zoom_out.pressed.connect(func():
		AudioManager.sfx_tap()
		zoom_out_requested.emit()
	)
	btn_cam_top.pressed.connect(func():
		AudioManager.sfx_tap()
		top_view_requested.emit()
	)
	btn_cam_reset.pressed.connect(func():
		AudioManager.sfx_tap()
		reset_camera_requested.emit()
		show_toast_hint("زاویه دوربین به حالت پیش‌فرض بازگشت")
	)

func _show_player_profile(player_index: int) -> void:
	AudioManager.sfx_tap()
	var my_idx = GameManager.my_player_index
	var p_data = {}
	var side_tag = "(شما)" if player_index == my_idx else "(حریف)"
	var role_str = ""
	if player_index == 1:
		p_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()
		if GameManager.current_game_type == GameTypes.FEKRBEKR:
			role_str = "🔐 بازیکن ۱ — طراح و کاشف رمز %s" % side_tag
		elif GameManager.current_game_type == GameTypes.CHESS:
			role_str = "🔴 بازیکن ۱ — ارتش قرمز %s" % side_tag
		else:
			role_str = "🔴 بازیکن ۱ — مهره قرمز %s" % side_tag
	else:
		p_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()
		if GameManager.current_game_type == GameTypes.FEKRBEKR:
			role_str = "🔐 بازیکن ۲ — طراح و کاشف رمز %s" % side_tag
		elif GameManager.current_game_type == GameTypes.CHESS:
			role_str = "🔵 بازیکن ۲ — ارتش آبی %s" % side_tag
		else:
			role_str = "🔵 بازیکن ۲ — مهره آبی %s" % side_tag
	user_profile_dialog.open_for_user(p_data, role_str)

func _open_surrender_dialog() -> void:
	ActionVFXManager.animate_dialog_open(surrender_card, surrender_dialog, true)

func _close_surrender_dialog() -> void:
	ActionVFXManager.animate_dialog_close(surrender_card, surrender_dialog)

func reset_for_new_match() -> void:
	set_fekrbekr_hud_buttons(false)
	is_start_overlay_dismissed = false
	is_countdown_running = false
	is_game_started = false
	is_game_finished = false
	is_round_finished = false
	is_timer_active = false
	turn_duration = GameRegistry.get_turn_time(GameManager.current_game_type)
	turn_time_left = turn_duration
	last_second_ticked = -1
	start_overlay.visible = false
	start_overlay.modulate.a = 1.0
	intro_card.modulate.a = 1.0
	intro_card.scale = Vector2.ONE
	start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if start_overlay.has_node("Dimmer"):
		start_overlay.get_node("Dimmer").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if intro_card:
		intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_camera_mode_indicator(false)
	round_finish_banner.visible = false
	if _toast_tween and is_instance_valid(_toast_tween):
		_toast_tween.kill()
		_toast_tween = null
	toast_hint.visible = false
	toast_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lbl_toast and is_instance_valid(lbl_toast):
		lbl_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surrender_dialog.visible = false
	surrender_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_dialog.visible = false
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reaction_picker and is_instance_valid(reaction_picker):
		reaction_picker.visible = false
		reaction_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if result_dialog and is_instance_valid(result_dialog):
		if result_dialog.has_method("close_immediate"):
			result_dialog.close_immediate()
		else:
			result_dialog.visible = false
			result_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_p1_role.visible = false
	intro_p2_role.visible = false
	if not is_countdown_running:
		intro_countdown_lbl.text = "⏳"
		intro_countdown_lbl.add_theme_font_size_override("font_size", 54)
	_ensure_top_header_for_current_game()
	if is_instance_valid(current_top_header):
		current_top_header.reset_header()
	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):
		_turn_glow_tween.kill()
		_turn_glow_tween = null

func setup_match(game_title: String = "تیک تاک تو", mode_title: String = "لابی دوستانه") -> void:
	visible = true
	set_fekrbekr_hud_buttons(false)
	_ensure_top_header_for_current_game()

	if intro_cafe_title:
		intro_cafe_title.text = mode_title
	if intro_game_title:
		intro_game_title.text = game_title
	intro_p1_role.visible = false
	intro_p2_role.visible = false
	if not is_countdown_running:
		intro_countdown_lbl.text = "⏳"
		intro_countdown_lbl.add_theme_font_size_override("font_size", 54)
	
	var my_idx = GameManager.my_player_index
	var p1_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()
	var p2_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()
	
	var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)
	turn_duration = def_time
	turn_time_left = def_time
	
	if is_instance_valid(current_top_header):
		current_top_header.setup_players(p1_data, p2_data, my_idx)
		current_top_header.setup_match(game_title, mode_title, GameManager.current_round, GameManager.max_rounds, def_time)

	# Setup intro names and roles
	var p1_name_str = p1_data.get("name", p1_data.get("username", "بازیکن ۱"))
	var p2_name_str = p2_data.get("name", p2_data.get("username", "بازیکن ۲"))
	intro_p1_name.text = p1_name_str
	intro_p2_name.text = p2_name_str
	if GameManager.current_game_type == GameTypes.FEKRBEKR:
		intro_p1_role.text = "🔐 طراح و کاشف رمز"
		intro_p2_role.text = "🔐 طراح و کاشف رمز"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		intro_p2_role.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		intro_p1_role.visible = true
		intro_p2_role.visible = true
	elif GameManager.current_game_type == GameTypes.CHESS:
		intro_p1_role.text = "🔴 ارتش قرمز"
		intro_p2_role.text = "🔵 ارتش آبی"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
		intro_p2_role.add_theme_color_override("font_color", Color(0.38, 0.78, 1.0))
		intro_p1_role.visible = true
		intro_p2_role.visible = true
	else:
		intro_p1_role.text = "🔴 مهره قرمز"
		intro_p2_role.text = "🔵 مهره آبی"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
		intro_p2_role.add_theme_color_override("font_color", Color(0.38, 0.78, 1.0))
		intro_p1_role.visible = true
		intro_p2_role.visible = true
	
	var av1_id = int(p1_data.get("image", p1_data.get("user_image", 0)))
	var tex1 = BaseTopHeaderClass._get_cached_avatar(av1_id)
	if tex1:
		intro_p1_avatar.texture = tex1
	var av2_id = int(p2_data.get("image", p2_data.get("user_image", 0)))
	var tex2 = BaseTopHeaderClass._get_cached_avatar(av2_id)
	if tex2:
		intro_p2_avatar.texture = tex2

	# Initial clean state before game actually starts
	is_game_finished = false
	is_game_started = false
	is_timer_active = false
	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):
		_turn_glow_tween.kill()
		_turn_glow_tween = null

func update_not_played_turns(gamer_id: int, count: int) -> void:
	if is_instance_valid(current_top_header) and current_top_header.has_method("update_not_played_turns"):
		current_top_header.update_not_played_turns(gamer_id, count)

	# Warnings & Sound Juice
	if count > 0:
		if gamer_id == GameManager.my_player_index:
			AudioManager.play_sound("bell")
			if count == 1:
				show_toast_hint("⚠️ نوبت شما سپری شد! خطای ۱ از ۳ (در ۴ خطا بازنده می‌شوید)")
			elif count == 2:
				show_toast_hint("⚠️ نوبت شما سپری شد! خطای ۲ از ۳ (تنها ۱ فرصت دیگر باقیست!)")
			elif count == 3:
				show_toast_hint("🚨 اخطار نهایی! در صورت عدم حرکت در نوبت بعد، بازنده خواهید شد!")
		else:
			if count < 3:
				show_toast_hint("⚠️ حریف در زمان مجاز حرکت نکرد (خطای %d از ۳)" % count)
			elif count == 3:
				show_toast_hint("⚠️ حریف به آخرین اخطار عدم حرکت رسید (۳ از ۳ خطا)")

func _start_loading_pulse() -> void:
	_stop_loading_pulse()
	if not intro_countdown_lbl or not is_instance_valid(intro_countdown_lbl):
		return
	intro_countdown_lbl.scale = Vector2.ONE
	intro_countdown_lbl.pivot_offset = intro_countdown_lbl.size / 2.0
	_loading_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loading_pulse_tween.tween_property(intro_countdown_lbl, "scale", Vector2(1.18, 1.18), 0.55)
	_loading_pulse_tween.tween_property(intro_countdown_lbl, "scale", Vector2(0.92, 0.92), 0.55)

func _stop_loading_pulse() -> void:
	if _loading_pulse_tween and _loading_pulse_tween.is_valid():
		_loading_pulse_tween.kill()
		_loading_pulse_tween = null
	if intro_countdown_lbl and is_instance_valid(intro_countdown_lbl):
		intro_countdown_lbl.scale = Vector2.ONE

# Shows the initial match connection loading overlay
func show_match_loading(status_text: String = "در حال آماده‌سازی میز مسابقه و همگام‌سازی بازیکنان...") -> void:
	if is_start_overlay_dismissed or is_game_started:
		return
	is_game_finished = false
	is_game_started = false
	is_timer_active = false
	is_countdown_running = false
	lbl_turn_banner.text = "بازی درحال آغاز است"
	lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	lbl_timer.text = "%02d ثانیه" % int(turn_duration)
	turn_timer_bar.value = 100.0
	
	intro_status_lbl.text = status_text
	intro_countdown_lbl.text = "⏳"
	intro_countdown_lbl.add_theme_font_size_override("font_size", 54)
	intro_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	intro_p1_role.visible = false
	intro_p2_role.visible = false
	
	_start_loading_pulse()
	
	if not start_overlay.visible:
		ActionVFXManager.animate_dialog_open(intro_card, start_overlay, true)

func set_overlay_status(status_text: String) -> void:
	intro_status_lbl.text = status_text

# Updates server-synchronized countdown timer
func update_start_countdown_time(sec: int) -> void:
	if is_start_overlay_dismissed:
		return
	# When real countdown has not started yet, ignore early server setup values (such as 1) and remain in loading state
	if not is_countdown_running:
		intro_countdown_lbl.text = "⏳"
		intro_countdown_lbl.add_theme_font_size_override("font_size", 54)
		return
	if sec <= 0:
		pass
	else:
		intro_countdown_lbl.add_theme_font_size_override("font_size", 96)
		intro_countdown_lbl.text = "%d" % sec
		_pulse_countdown_label()
		AudioManager.play_sound("time")

# Plays synchronized pre-game loading countdown
func play_start_countdown(on_finished: Callable = Callable(), total_seconds: int = 5) -> void:
	if is_start_overlay_dismissed or is_game_started:
		if on_finished.is_valid():
			on_finished.call()
		return
	if is_countdown_running:
		if on_finished.is_valid():
			on_finished.call()
		return
		
	is_countdown_running = true
	is_game_started = false
	is_timer_active = false
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_stop_loading_pulse()
	intro_countdown_lbl.add_theme_font_size_override("font_size", 96)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if not start_overlay.visible:
		ActionVFXManager.animate_dialog_open(intro_card, start_overlay, true)
	intro_status_lbl.text = "میز مسابقه آماده است! نبرد آغاز می‌شود در:"
	
	# Reveal game-specific roles when real countdown begins
	if GameManager.current_game_type == GameTypes.FEKRBEKR:
		intro_p1_role.text = "🔐 طراح و کاشف رمز"
		intro_p2_role.text = "🔐 طراح و کاشف رمز"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		intro_p2_role.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	elif GameManager.current_game_type == GameTypes.CHESS:
		intro_p1_role.text = "🔴 ارتش قرمز"
		intro_p2_role.text = "🔵 ارتش آبی"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
		intro_p2_role.add_theme_color_override("font_color", Color(0.38, 0.78, 1.0))
	else:
		intro_p1_role.text = "🔴 مهره قرمز"
		intro_p2_role.text = "🔵 مهره آبی"
		intro_p1_role.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
		intro_p2_role.add_theme_color_override("font_color", Color(0.38, 0.78, 1.0))
	intro_p1_role.visible = true
	intro_p2_role.visible = true
	intro_p1_role.modulate.a = 0.0
	intro_p2_role.modulate.a = 0.0
	var tw_roles = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_roles.tween_property(intro_p1_role, "modulate:a", 1.0, 0.4)
	tw_roles.tween_property(intro_p2_role, "modulate:a", 1.0, 0.4)
	
	for i in range(total_seconds, 0, -1):
		if not start_overlay.visible or is_start_overlay_dismissed:
			break
		intro_countdown_lbl.text = "%d" % i
		_pulse_countdown_label()
		AudioManager.play_sound("time")
		await get_tree().create_timer(1.0).timeout
	
	if start_overlay.visible and not is_start_overlay_dismissed:
		intro_countdown_lbl.text = "شروع!"
		intro_countdown_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		_pulse_countdown_label()
		AudioManager.play_sound("bell")
		await get_tree().create_timer(0.4).timeout
		force_dismiss_start_overlay()
	else:
		force_dismiss_start_overlay()
	
	is_countdown_running = false
	if on_finished.is_valid():
		on_finished.call()

# Guarantees the loading overlay is dismissed as soon as the intro countdown finishes or match becomes active
func force_dismiss_start_overlay(emit_finished: bool = true) -> void:
	if is_start_overlay_dismissed:
		return
	_stop_loading_pulse()
	is_start_overlay_dismissed = true
	is_countdown_running = false
	start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if start_overlay.has_node("Dimmer"):
		start_overlay.get_node("Dimmer").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if intro_card:
		intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(intro_card, start_overlay, func():
		if emit_finished:
			start_countdown_finished.emit()
	)
	if GameManager.is_game_active:
		is_game_started = true
		if not is_timer_active and not is_game_finished:
			var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)
			start_turn_timer(def_time)
	else:
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

func _pulse_countdown_label() -> void:
	intro_countdown_lbl.scale = Vector2(1.35, 1.35)
	intro_countdown_lbl.pivot_offset = intro_countdown_lbl.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(intro_countdown_lbl, "scale", Vector2.ONE, 0.22)

# Shows between-rounds banner dialog (like Flutter's showFinishRoundDialog)
func stop_round_timer() -> void:
	is_round_finished = true
	is_timer_active = false
	last_second_ticked = -1
	turn_time_left = 0.0
	turn_timer_bar.value = 0.0
	lbl_timer.text = "-- ثانیه"
	AudioManager.stop_sound("time")
	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):
		_turn_glow_tween.kill()
		_turn_glow_tween = null

func show_round_finish_banner(round_winner: int, current_r: int, p1_s: int, p2_s: int) -> void:
	stop_round_timer()
	round_finish_title.text = "✨ پایان دست %d" % current_r
	round_finish_score.text = "📊 نتیجه دست‌ها تا این لحظه: %d - %d  |  آماده‌سازی دست بعدی..." % [p1_s, p2_s]
	
	var my_idx = GameManager.my_player_index
	var p1_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()
	var p2_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()
	var p1_user = p1_data.get("name", p1_data.get("username", "بازیکن ۱"))
	var p2_user = p2_data.get("name", p2_data.get("username", "بازیکن ۲"))
	
	if round_winner == 0:
		round_finish_desc.text = "🤝 این دست بدون برنده (مساوی) به پایان رسید"
		round_finish_desc.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
		AudioManager.play_sound("draw")
	elif round_winner == 1:
		if my_idx == 1:
			round_finish_desc.text = "🎉 آفرین! شما برنده این دست شدید (%s)" % p1_user
			round_finish_desc.add_theme_color_override("font_color", Color(0.38, 0.95, 0.50))
		else:
			round_finish_desc.text = "🔴 برنده این دست: %s" % p1_user
			round_finish_desc.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		AudioManager.play_sound("win" if my_idx == 1 else "lose")
	elif round_winner == 2:
		if my_idx == 2:
			round_finish_desc.text = "🎉 آفرین! شما برنده این دست شدید (%s)" % p2_user
			round_finish_desc.add_theme_color_override("font_color", Color(0.38, 0.95, 0.50))
		else:
			round_finish_desc.text = "🔵 برنده این دست: %s" % p2_user
			round_finish_desc.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
		AudioManager.play_sound("win" if my_idx == 2 else "lose")
		
	ActionVFXManager.animate_dialog_open(round_finish_card, round_finish_banner, true, false)

func hide_round_finish_banner() -> void:
	is_round_finished = false
	if not round_finish_banner.visible:
		return
	ActionVFXManager.animate_dialog_close(round_finish_card, round_finish_banner)

# Shows auto-pause overlay when a user disconnects
func show_pause_dialog(wait_time: int, reason_text: String = "") -> void:
	is_pause_active = true
	_last_pause_sec_ticked = -1
	var actual_time = wait_time if wait_time > 0 else 45
	pause_total_time = float(actual_time)
	pause_time_left = pause_total_time
	
	if is_instance_valid(lbl_pause_title):
		lbl_pause_title.text = "📡 وقفه موقت در مسابقه"
	var opp_data = GameManager.get_opponent_player_data()
	var opp_name = opp_data.get("name", opp_data.get("username", "حریف"))
	if not reason_text.is_empty():
		lbl_pause_desc.text = reason_text
	else:
		lbl_pause_desc.text = "ارتباط اینترنتی «%s» موقتاً قطع شده است.\nلطفاً تا بازگشت حریف شکیبا باشید؛ در صورت پایان مهلت، پیروزی این مسابقه برای شما ثبت خواهد شد." % opp_name
		
	lbl_pause_countdown.text = "⏳ مهلت بازگشت به بازی: %d ثانیه" % int(pause_time_left)
	pause_timer_bar.value = 100.0
	
	pause_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	ActionVFXManager.animate_dialog_open(pause_card, pause_dialog, true)
	stop_timer()
	AudioManager.play_sound("miss_turn")

func hide_pause_dialog() -> void:
	is_pause_active = false
	if pause_dialog and is_instance_valid(pause_dialog):
		pause_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if pause_dialog.visible:
			ActionVFXManager.animate_dialog_close(pause_card, pause_dialog)

# Handles full game reconnect data payload (re-syncs gamers, round, scores, turn, and timer)
func handle_reconnect_data(payload: Dictionary) -> void:
	visible = true
	hide_pause_dialog()
	force_dismiss_start_overlay(false)
	
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
		setup_match(GameManager.get_game_display_name(), "مسابقه زنده")
		
	GameManager.is_game_active = true
	is_game_started = true
	is_round_finished = false
	is_game_finished = false
	force_dismiss_start_overlay(false)
	if pause_dialog and is_instance_valid(pause_dialog):
		hide_pause_dialog()
	var game_data = payload.get("game_data", {})
	if typeof(game_data) == TYPE_DICTIONARY:
		var scores = game_data.get("scores", [0, 0])
		if scores.size() >= 2:
			update_scores(int(scores[0]), int(scores[1]))
		var r_num = int(game_data.get("current_round", 1))
		if is_instance_valid(current_top_header) and current_top_header.has_method("set_round"):
			current_top_header.set_round(r_num, GameManager.max_rounds)
		if GameManager.current_game_type == GameTypes.FEKRBEKR:
			var is_play_rec = bool(game_data.get("is_play_phase", false))
			var is_waiting = bool(game_data.get("is_turn_played", false)) if is_play_rec else bool(game_data.get("is_player_rdy", false))
			if is_play_rec:
				update_turn(max(1, r_num))
			else:
				set_setup_phase()
			set_fekrbekr_hud_buttons(is_play_rec)
			if is_waiting:
				set_waiting_opponent("حدس شما ثبت شده است. در انتظار حریف..." if is_play_rec else "رمز شما ثبت شده است. در انتظار حریف...")
		else:
			var turn = int(game_data.get("current_turn", 1))
			update_turn(turn)
		
	var max_time = GameRegistry.get_turn_time(GameManager.current_game_type)
	turn_duration = max_time
	var timer_data = payload.get("timer_data", {})
	if typeof(timer_data) == TYPE_DICTIONARY:
		var elapsed = float(timer_data.get("time", 0))
		turn_time_left = clampf(max_time - elapsed, 1.0, max_time)
	else:
		turn_time_left = max_time
		
	is_game_started = true
	is_start_overlay_dismissed = true
	is_round_finished = false
	is_pause_active = false
	is_timer_active = true
	last_second_ticked = -1
	
	# Force refresh timer UI immediately
	var sec = int(ceil(turn_time_left))
	lbl_timer.text = "%02d ثانیه" % sec
	turn_timer_bar.value = (turn_time_left / turn_duration) * 100.0
			
	show_toast_hint("✅ اتصال به مسابقه با موفقیت برقرار شد!")

# Shows non-blocking floating hint centered at bottom of screen
func show_toast_hint(text: String) -> void:
	if _toast_tween and is_instance_valid(_toast_tween):
		_toast_tween.kill()
		_toast_tween = null
		
	lbl_toast.text = text
	
	var font = lbl_toast.get_theme_font("font")
	var font_size = lbl_toast.get_theme_font_size("font_size")
	var text_w = 360.0
	if font:
		text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var total_w = max(440.0, text_w + 80.0)
	var half_w = total_w / 2.0
	
	toast_hint.offset_left = -half_w
	toast_hint.offset_right = half_w
	toast_hint.offset_top = -240.0
	toast_hint.offset_bottom = -165.0
	toast_hint.pivot_offset = Vector2(half_w, (240.0 - 165.0) / 2.0)
	
	toast_hint.visible = true
	toast_hint.modulate.a = 0.0
	toast_hint.scale = Vector2(0.85, 0.85)
	
	_toast_tween = create_tween()
	_toast_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast_hint, "scale", Vector2.ONE, 0.2)
	_toast_tween.parallel().tween_property(toast_hint, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.2)
	_toast_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_toast_tween.tween_property(toast_hint, "modulate:a", 0.0, 0.25)
	_toast_tween.finished.connect(func():
		toast_hint.visible = false
	)

func set_round(current_r: int, max_r: int) -> void:
	is_round_finished = false
	GameManager.current_round = current_r
	if is_instance_valid(current_top_header):
		current_top_header.set_round(current_r, max_r)

func update_scores(p1_s: int, p2_s: int) -> void:
	GameManager.p1_score = p1_s
	GameManager.p2_score = p2_s
	if is_instance_valid(current_top_header):
		current_top_header.update_scores(p1_s, p2_s)

func start_turn_timer(duration: float, custom_banner: String = "") -> void:

	if is_game_finished:

		return

	turn_duration = duration

	turn_time_left = duration

	last_second_ticked = -1

	is_timer_active = true

	is_game_started = true

	if not custom_banner.is_empty() and is_instance_valid(lbl_turn_banner):

		lbl_turn_banner.text = custom_banner

	if is_instance_valid(current_top_header):

		current_top_header.update_timer(turn_time_left, turn_duration, GameManager.current_turn)



func start_wait_timer(wait_sec: int, msg: String = "") -> void:
	if is_game_finished:
		return
	var banner_text = msg if not msg.is_empty() else ("بازی درحال آغاز است" if not GameManager.is_game_active else "⏳ آماده‌سازی مرحله بعدی...")
	turn_duration = float(wait_sec)
	turn_time_left = float(wait_sec)
	last_second_ticked = -1
	is_timer_active = true
	is_game_started = true
	if is_instance_valid(current_top_header):
		if msg.is_empty() and current_top_header.has_method("set_round_wait"):
			current_top_header.set_round_wait(wait_sec)
		current_top_header.update_timer(turn_time_left, turn_duration, 0)
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = banner_text
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

func start_pre_game_countdown(wait_sec: int = 5) -> void:
	if is_game_finished or GameManager.is_game_active:
		return
	set_fekrbekr_hud_buttons(false)
	start_wait_timer(wait_sec, "بازی درحال آغاز است")

func set_setup_phase() -> void:
	set_fekrbekr_hud_buttons(false)
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_setup_phase"):
		current_top_header.set_setup_phase()
	var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)
	start_turn_timer(def_time)

func set_waiting_opponent(custom_text: String = "در انتظار حریف...") -> void:
	if is_instance_valid(btn_fekr_submit):
		btn_fekr_submit.visible = false
	if is_instance_valid(btn_fekr_clear):
		btn_fekr_clear.visible = false
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_waiting_opponent"):
		current_top_header.set_waiting_opponent(custom_text)
	elif is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = custom_text

func set_round_wait(time_sec: int) -> void:
	start_wait_timer(time_sec)

func update_turn(turn: int) -> void:
	if is_game_finished or is_round_finished:
		return
		
	set_fekrbekr_hud_buttons(turn > 0)
	GameManager.current_turn = turn
	var is_me = (turn == GameManager.my_player_index) if GameManager.current_game_type != GameTypes.FEKRBEKR else true
	
	# Current_Turn signal proves match is actively running!
	if not is_countdown_running:
		force_dismiss_start_overlay(false)

	hide_round_finish_banner()

	

	var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)

	start_turn_timer(def_time)

	

	var p1_data = GameManager.get_my_player_data() if GameManager.my_player_index == 1 else GameManager.get_opponent_player_data()

	var p2_data = GameManager.get_opponent_player_data() if GameManager.my_player_index == 1 else GameManager.get_my_player_data()

	var p1_n = p1_data.get("name", "میزبان")

	var p2_n = p2_data.get("name", "مهمان")

	

	if is_instance_valid(current_top_header):

		current_top_header.update_turn(turn, GameManager.my_player_index, p1_n, p2_n)

		

	if is_me and is_game_started:

		AudioManager.play_sound("start_turn")

func stop_timer() -> void:
	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):
		_turn_glow_tween.kill()
		_turn_glow_tween = null
	if p1_card and is_instance_valid(p1_card):
		p1_card.modulate = Color.WHITE
		p1_card.scale = Vector2.ONE
	if p2_card and is_instance_valid(p2_card):
		p2_card.modulate = Color.WHITE
		p2_card.scale = Vector2.ONE
	is_timer_active = false
	last_second_ticked = -1
	turn_time_left = 0.0
	turn_timer_bar.value = 0.0
	lbl_timer.text = "-- ثانیه"
	AudioManager.stop_sound("time")

func set_camera_mode_indicator(is_top_down: bool) -> void:
	if btn_cam_top and is_instance_valid(btn_cam_top):
		btn_cam_top.text = "3D" if is_top_down else "2D"
		btn_cam_top.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

func show_reaction(user_index: int, reaction_id: int) -> void:
	if is_instance_valid(current_top_header):
		current_top_header.show_reaction(user_index, reaction_id)

func show_surrender_notification(surrendered_gamer_id: int) -> void:
	is_game_finished = true
	stop_timer()
	
	if surrender_dialog and is_instance_valid(surrender_dialog):
		surrender_dialog.visible = false
		surrender_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	var my_idx = GameManager.my_player_index
	var is_me = GameManager.local_player_surrendered or (surrendered_gamer_id == my_idx)
	if is_me:
		GameManager.local_player_surrendered = true
		GameManager.opponent_player_surrendered = false
	else:
		GameManager.opponent_player_surrendered = true
		GameManager.local_player_surrendered = false
		
	var winner_idx = (2 if my_idx == 1 else 1) if is_me else my_idx
	
	if is_me:
		lbl_turn_banner.text = "🏳️ شما تسلیم شدید!"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		AudioManager.play_sound("lose")
		show_toast_hint("شما از ادامه مسابقه انصراف دادید.")
	else:
		lbl_turn_banner.text = "🏆 حریف تسلیم شد و پیروز شدید!"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
		AudioManager.play_sound("win")
		show_toast_hint("حریف تسلیم شد! تبریک، شما برنده این بازی شدید.")
		
	# Show result modal after 1.5s so player can review result and return to main menu
	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		show_game_result(winner_idx, GameManager.p1_score, GameManager.p2_score)
	)

func show_game_result(winner: int, p1_score: int, p2_score: int) -> void:
	is_game_finished = true
	stop_timer()
	var final_winner = winner
	if GameManager.local_player_surrendered:
		final_winner = 2 if GameManager.my_player_index == 1 else 1
	elif GameManager.opponent_player_surrendered:
		final_winner = GameManager.my_player_index
	result_dialog.show_result(final_winner, p1_score, p2_score)

func _update_audio_visual() -> void:
	if AudioManager.is_music_enabled:
		img_audio.texture = _sound_on_tex
	else:
		img_audio.texture = _sound_off_tex

func _exit_tree() -> void:
	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):
		_turn_glow_tween.kill()
		_turn_glow_tween = null

# Updates visibility of FekrBekr dedicated HUD action buttons
# Phase 1: Only Checkmark (✓) and Cross (✕) are visible
# Phase 2: All 4 buttons (✓, ✕, 🎯, 👥) are visible
func set_fekrbekr_hud_buttons(is_play_phase: bool) -> void:
	if GameManager.current_game_type != GameTypes.FEKRBEKR or not GameManager.is_game_active:
		if is_instance_valid(fekrbekr_actions):
			fekrbekr_actions.visible = false
		return
	if is_instance_valid(fekrbekr_actions):
		fekrbekr_actions.visible = true
	if is_instance_valid(btn_fekr_submit):
		btn_fekr_submit.visible = true
	if is_instance_valid(btn_fekr_clear):
		btn_fekr_clear.visible = true
	if is_instance_valid(btn_fekr_opp):
		btn_fekr_opp.visible = is_play_phase
	if is_instance_valid(btn_fekr_dual):
		btn_fekr_dual.visible = is_play_phase
