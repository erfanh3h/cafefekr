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



# --- Split Sub-Header Rail, Camera Popover & Top-Corner Menu Drawer ---

@onready var sub_header_rail: HBoxContainer = $SubHeaderRail
@onready var btn_camera_menu: Button = $SubHeaderRail/BtnCameraMenu
@onready var img_camera_menu: TextureRect = $SubHeaderRail/BtnCameraMenu/Icon
@onready var btn_kori: Button = $SubHeaderRail/RightGroup/BtnKori
@onready var btn_reactions: Button = $SubHeaderRail/RightGroup/BtnReactions

@onready var camera_popover_backdrop: Button = $CameraPopoverBackdrop
@onready var camera_popover: PanelContainer = $CameraPopover
@onready var btn_zoom_in: Button = $CameraPopover/HBox/BtnZoomIn
@onready var btn_zoom_out: Button = $CameraPopover/HBox/BtnZoomOut
@onready var btn_cam_top: Button = $CameraPopover/HBox/BtnCamTop
@onready var img_cam_top: TextureRect = $CameraPopover/HBox/BtnCamTop/Icon
@onready var btn_cam_reset: Button = $CameraPopover/HBox/BtnCamReset

@onready var game_menu_drawer: Control = $GameMenuDrawer
@onready var btn_menu_dimmer_close: Button = $GameMenuDrawer/BtnDimmerClose
@onready var menu_view: VBoxContainer = $GameMenuDrawer/Card/MenuView
@onready var rules_view: VBoxContainer = $GameMenuDrawer/Card/RulesView
@onready var lbl_menu_game_title: Label = $GameMenuDrawer/Card/MenuView/HeaderBox/LblMenuGameTitle
@onready var lbl_menu_round_info: Label = $GameMenuDrawer/Card/MenuView/HeaderBox/LblMenuRoundInfo
@onready var btn_audio: Button = $GameMenuDrawer/Card/MenuView/BtnAudio
@onready var img_audio: TextureRect = $GameMenuDrawer/Card/MenuView/BtnAudio/Icon
@onready var btn_game_info: Button = $GameMenuDrawer/Card/MenuView/BtnGameInfo
@onready var btn_surrender: Button = $GameMenuDrawer/Card/MenuView/BtnSurrender
@onready var btn_toggle_chat: Button = $GameMenuDrawer/Card/MenuView/BtnToggleChat
@onready var img_toggle_chat: TextureRect = $GameMenuDrawer/Card/MenuView/BtnToggleChat/Icon
@onready var btn_close_menu: Button = $GameMenuDrawer/Card/MenuView/BtnCloseMenu
@onready var btn_rules_back: Button = $GameMenuDrawer/Card/RulesView/RulesHeader/BtnRulesBack
@onready var lbl_rules_title: Label = $GameMenuDrawer/Card/RulesView/RulesHeader/LblRulesTitle
@onready var lbl_rules_body: Label = $GameMenuDrawer/Card/RulesView/RulesScroll/LblRulesBody

var _last_reaction_sent_msec: int = -10000
var _camera_popover_open: bool = false
var _safe_bottom_inset: int = 12
static var _game_docs_cache: Dictionary = {}



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

var is_wait_timer_mode: bool = false

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



# Audio and Camera Badges
var _sound_on_tex: Texture2D = preload("res://assets/images/badges/sound-on.png")
var _sound_off_tex: Texture2D = preload("res://assets/images/badges/sound-off.png")
var _cam_3d_tex: Texture2D = preload("res://assets/images/badges/3d.png")
var _cam_2d_tex: Texture2D = preload("res://assets/images/badges/2d.png")



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

		if current_top_header.has_signal("player_profile_clicked"):

			current_top_header.player_profile_clicked.connect(func(idx: int): _show_player_profile(idx))

		if current_top_header.has_signal("menu_requested"):

			current_top_header.menu_requested.connect(_open_game_menu_drawer)

		if current_top_header.has_signal("header_height_changed"):

			current_top_header.header_height_changed.connect(_on_header_height_changed)

		if current_top_header.has_signal("view_mode_toggled"):
			current_top_header.view_mode_toggled.connect(func(_is_2d: bool):
				top_view_requested.emit()
			)

		if current_top_header.has_signal("chat_pressed"):
			current_top_header.chat_pressed.connect(func(anchor: Button):
				if GameManager.is_spectating:
					return
				_close_camera_popover()
				if not GameManager.is_game_active:
					show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
					return
				AudioManager.sfx_button()
				reaction_picker.open_koris(anchor)
			)

		if current_top_header.has_signal("emoji_pressed"):
			current_top_header.emoji_pressed.connect(func(anchor: Button):
				if GameManager.is_spectating:
					return
				_close_camera_popover()
				if not GameManager.is_game_active:
					show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
					return
				AudioManager.sfx_button()
				reaction_picker.open_stickers(anchor)
			)

		_on_header_height_changed(current_top_header.offset_bottom)



func _on_header_height_changed(new_height: float) -> void:
	var clamped_h: float = maxf(68.0, new_height)
	if is_instance_valid(top_header_slot):
		top_header_slot.offset_bottom = clamped_h
	if is_instance_valid(sub_header_rail):
		sub_header_rail.visible = false
		sub_header_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_overlay_open() -> bool:
	if is_instance_valid(game_menu_drawer) and game_menu_drawer.visible:
		return true
	if is_instance_valid(camera_popover) and camera_popover.visible:
		return true
	if is_instance_valid(reaction_picker) and reaction_picker.visible:
		return true
	return false


func _apply_bottom_safe_insets() -> void:
	var insets: Dictionary = HudTheme.get_safe_insets(get_viewport())
	_safe_bottom_inset = int(insets.get("bottom", 14))
	if is_instance_valid(fekrbekr_actions):
		fekrbekr_actions.offset_bottom = -_safe_bottom_inset
		fekrbekr_actions.offset_top = -_safe_bottom_inset - 64.0
	if is_instance_valid(sub_header_rail):
		sub_header_rail.visible = false
		sub_header_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:

	_ensure_top_header_for_current_game()

	_setup_card_styles()

	_setup_connections()

	_apply_bottom_safe_insets()

	if is_instance_valid(sub_header_rail):
		sub_header_rail.visible = false
		sub_header_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(lbl_timer):
		lbl_timer.visible = false
		lbl_timer.text = ""

	surrender_dialog.visible = false

	start_overlay.visible = false

	round_finish_banner.visible = false

	_close_camera_popover()

	_close_game_menu_drawer()

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

	if is_instance_valid(lbl_timer):
		lbl_timer.text = ""
		lbl_timer.visible = false

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

		if turn_time_left <= 3.0 and turn_time_left > 0.0 and not is_wait_timer_mode:

			if sec != last_second_ticked:

				last_second_ticked = sec

				if is_start_overlay_dismissed and not is_countdown_running and (GameManager.is_my_turn or not GameManager.is_game_active) and not is_game_finished and not is_round_finished:

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

	# Style compact Warm Classic Parlor SubHeaderRail buttons (42x42 thumb-friendly targets)
	var rail_btns: Array = [btn_camera_menu, btn_kori, btn_reactions]
	for b in rail_btns:
		if not is_instance_valid(b):
			continue
		HudTheme.apply_rail_button_style(b, false)
		b.custom_minimum_size = Vector2(42, 42)
		b.text = ""
		b.pivot_offset = b.custom_minimum_size * 0.5
		ActionVFXManager.apply_button_juice(b, "tap_button")

	# Style collapsible camera popover actions
	var cam_btns: Array = [btn_cam_top, btn_zoom_in, btn_zoom_out, btn_cam_reset]
	for cb in cam_btns:
		if not is_instance_valid(cb):
			continue
		HudTheme.apply_floating_button_style(cb, false)
		cb.custom_minimum_size = Vector2(44, 44)
		cb.text = ""
		cb.pivot_offset = cb.custom_minimum_size * 0.5
		ActionVFXManager.apply_button_juice(cb, "tap_button")

	# Style top-corner Menu Drawer items
	HudTheme.apply_drawer_item_style(btn_audio, "default")
	HudTheme.apply_drawer_item_style(btn_game_info, "default")
	HudTheme.apply_drawer_item_style(btn_surrender, "danger")
	if is_instance_valid(btn_toggle_chat):
		_update_chat_toggle_button_visuals()
		btn_toggle_chat.pressed.connect(func():
			AudioManager.sfx_button()
			GameManager.set_chat_and_stickers_disabled(not GameManager.chat_and_stickers_disabled)
			_update_chat_toggle_button_visuals()
		)
	HudTheme.apply_drawer_item_style(btn_close_menu, "primary")
	HudTheme.apply_drawer_item_style(btn_rules_back, "default")
	HudTheme.configure_bidi_label(lbl_rules_body, false)

	if is_instance_valid(btn_camera_menu):
		btn_camera_menu.pressed.connect(func():
			AudioManager.sfx_tap()
			_toggle_camera_popover()
		)
	if is_instance_valid(camera_popover_backdrop):
		camera_popover_backdrop.pressed.connect(_close_camera_popover)
	if is_instance_valid(btn_menu_dimmer_close):
		btn_menu_dimmer_close.pressed.connect(_close_game_menu_drawer)
	if is_instance_valid(btn_close_menu):
		btn_close_menu.pressed.connect(func():
			AudioManager.sfx_tap()
			_close_game_menu_drawer()
		)
	if is_instance_valid(btn_game_info):
		btn_game_info.pressed.connect(func():
			AudioManager.sfx_tap()
			_show_menu_rules()
		)
	if is_instance_valid(btn_rules_back):
		btn_rules_back.pressed.connect(func():
			AudioManager.sfx_tap()
			if is_instance_valid(rules_view):
				rules_view.visible = false
			if is_instance_valid(menu_view):
				menu_view.visible = true
		)

	KenneyUI.style_button(btn_confirm_surrender, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_cancel_surrender, KenneyUI.COLOR_GREY)

	btn_surrender.pressed.connect(func():
		if GameManager.is_spectating:
			return
		_close_game_menu_drawer()
		if not GameManager.is_game_active:
			show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
			return
		AudioManager.sfx_button()
		_open_surrender_dialog()
	)

	btn_confirm_surrender.pressed.connect(func():
		if GameManager.is_spectating:
			return
		AudioManager.sfx_button()
		_close_surrender_dialog()
		surrender_requested.emit()
	)

	btn_cancel_surrender.pressed.connect(func():
		AudioManager.sfx_button()
		_close_surrender_dialog()
	)

	if is_instance_valid(btn_kori):
		btn_kori.pressed.connect(func():
			if GameManager.is_spectating:
				return
			_close_camera_popover()
			if not GameManager.is_game_active:
				show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
				return
			AudioManager.sfx_button()
			reaction_picker.open_koris(btn_kori)
		)

	btn_reactions.pressed.connect(func():
		if GameManager.is_spectating:
			return
		_close_camera_popover()
		if not GameManager.is_game_active:
			show_toast_hint("لطفاً تا شروع مسابقه صبر کنید...")
			return
		AudioManager.sfx_button()
		reaction_picker.open_stickers(btn_reactions)
	)

	btn_audio.pressed.connect(func():
		var new_state = not AudioManager.is_music_enabled
		AudioManager.set_music_enabled(new_state)
		AudioManager.set_sound_enabled(new_state)
		AudioManager.sfx_tap()
		_update_audio_visual()
	)

	

	# Style FekrBekr / Battleship bottom action dock buttons like Monopoly
	if is_instance_valid(btn_fekr_submit):
		_style_monopoly_action_button(btn_fekr_submit, Color(0.12, 0.44, 0.24, 0.96), Color(0.92, 0.74, 0.30, 0.95), true)
		_style_monopoly_action_button(btn_fekr_clear, Color(0.38, 0.16, 0.16, 0.96), Color(0.85, 0.55, 0.55, 0.90), false)
		_style_monopoly_action_button(btn_fekr_opp, Color(0.16, 0.24, 0.38, 0.96), Color(0.55, 0.75, 1.0, 0.90), false)
		_style_monopoly_action_button(btn_fekr_dual, Color(0.24, 0.18, 0.32, 0.96), Color(0.78, 0.62, 0.95, 0.90), false)

		var fekr_btns = [btn_fekr_submit, btn_fekr_clear, btn_fekr_opp, btn_fekr_dual]
		for b in fekr_btns:
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

		if GameManager.is_spectating:
			return

		var now_ms = Time.get_ticks_msec()

		if now_ms - _last_reaction_sent_msec < 3000:

			show_toast_hint("لطفاً چند ثانیه صبر کنید...")

			return

		_last_reaction_sent_msec = now_ms

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
	if not GameManager.is_game_active or is_countdown_running or not is_start_overlay_dismissed or not is_game_started:
		print("[HUD] Profile popup suppressed during game start / countdown.")
		return
	if is_instance_valid(start_overlay) and start_overlay.visible:
		print("[HUD] Profile popup suppressed: start overlay is visible.")
		return

	AudioManager.sfx_tap()

	var my_idx = GameManager.my_player_index

	var p_data = GameManager.get_player_data_by_gamer_id(player_index)

	var side_tag = "(تماشای زنده)" if GameManager.is_spectating else ("(شما)" if player_index == my_idx else "(حریف)")

	var role_str = ""

	if player_index == 1:

		if p_data.is_empty():

			p_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()

		if GameManager.current_game_type == GameTypes.FEKRBEKR:

			role_str = "🔐 بازیکن ۱ — طراح و کاشف رمز %s" % side_tag

		elif GameManager.current_game_type == GameTypes.CHESS:

			role_str = "🔴 بازیکن ۱ — ارتش قرمز %s" % side_tag

		else:

			role_str = "🔴 بازیکن ۱ — مهره قرمز %s" % side_tag

	elif player_index == 2:

		if p_data.is_empty():

			p_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()

		if GameManager.current_game_type == GameTypes.FEKRBEKR:

			role_str = "🔐 بازیکن ۲ — طراح و کاشف رمز %s" % side_tag

		elif GameManager.current_game_type == GameTypes.CHESS:

			role_str = "🔵 بازیکن ۲ — ارتش آبی %s" % side_tag

		else:

			role_str = "🔵 بازیکن ۲ — مهره آبی %s" % side_tag

	elif player_index == 3:

		role_str = "🟢 بازیکن ۳ — مهره سبز %s" % side_tag

	elif player_index == 4:

		role_str = "🟡 بازیکن ۴ — مهره زرد %s" % side_tag

	user_profile_dialog.open_for_user(p_data, role_str)



func _open_surrender_dialog() -> void:

	ActionVFXManager.animate_dialog_open(surrender_card, surrender_dialog, true)



func _close_surrender_dialog() -> void:

	ActionVFXManager.animate_dialog_close(surrender_card, surrender_dialog)



var _surrender_handled: bool = false

var _result_shown: bool = false

var _surrender_result_tween: Tween = null

var _last_reconnect_remaining_time: float = -1.0



func _ensure_clean_white_fekr_icons() -> void:

	# Guarantees FekrBekr Clear and Dual icons render as crisp white on transparent background

	# even if local .godot/imported/*.ctex cache was generated from older icon files.

	var clear_icon = btn_fekr_clear.get_node_or_null("Icon") as TextureRect if is_instance_valid(btn_fekr_clear) else null

	if clear_icon and clear_icon.texture:

		var img = clear_icon.texture.get_image()

		if img and not img.is_empty():

			img.decompress()

			img.convert(Image.FORMAT_RGBA8)

			for y in range(img.get_height()):

				for x in range(img.get_width()):

					var c = img.get_pixel(x, y)

					if c.a > 0.01:

						img.set_pixel(x, y, Color(1.0, 1.0, 1.0, c.a))

			clear_icon.texture = ImageTexture.create_from_image(img)

	var dual_icon = btn_fekr_dual.get_node_or_null("Icon") as TextureRect if is_instance_valid(btn_fekr_dual) else null

	if dual_icon and dual_icon.texture:

		var img2 = dual_icon.texture.get_image()

		if img2 and not img2.is_empty():

			img2.decompress()

			img2.convert(Image.FORMAT_RGBA8)

			for y in range(img2.get_height()):

				for x in range(img2.get_width()):

					var c2 = img2.get_pixel(x, y)

					var lum = (c2.r + c2.g + c2.b) / 3.0

					if c2.a < 0.08 or lum <= 0.30:

						img2.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))

					else:

						var alpha_out = clampf((lum - 0.30) / 0.32, 0.0, 1.0) * c2.a

						img2.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha_out))

			dual_icon.texture = ImageTexture.create_from_image(img2)



func _toggle_camera_popover() -> void:
	if _camera_popover_open:
		_close_camera_popover()
	else:
		_open_camera_popover()


func _open_camera_popover() -> void:
	_camera_popover_open = true
	if is_instance_valid(reaction_picker) and reaction_picker.visible:
		reaction_picker.close()
	if is_instance_valid(camera_popover_backdrop):
		camera_popover_backdrop.visible = true
	if is_instance_valid(camera_popover):
		var insets: Dictionary = HudTheme.get_safe_insets(get_viewport())
		var vp_size: Vector2 = get_viewport_rect().size
		var pop_w: float = 224.0
		var pop_h: float = 64.0
		var pos_x: float = float(insets.get("left", 10))
		var pos_y: float = 206.0
		if is_instance_valid(btn_camera_menu):
			var btn_rect: Rect2 = btn_camera_menu.get_global_rect()
			pos_x = clampf(btn_rect.position.x, float(insets.get("left", 10)), maxf(10.0, vp_size.x - pop_w - float(insets.get("right", 10))))
			pos_y = clampf(btn_rect.end.y + 8.0, float(insets.get("top", 16)), maxf(16.0, vp_size.y - pop_h - float(insets.get("bottom", 14))))
		camera_popover.position = Vector2(pos_x, pos_y)
		camera_popover.size = Vector2(pop_w, pop_h)
		camera_popover.pivot_offset = Vector2(21.0, 0.0)
		camera_popover.visible = true
		camera_popover.modulate.a = 0.0
		camera_popover.scale = Vector2(0.88, 0.72)
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(camera_popover, "scale", Vector2.ONE, 0.16)
		tw.parallel().tween_property(camera_popover, "modulate:a", 1.0, 0.12)
	if is_instance_valid(btn_camera_menu):
		HudTheme.apply_rail_button_style(btn_camera_menu, true)


func _close_camera_popover() -> void:
	_camera_popover_open = false
	if is_instance_valid(camera_popover_backdrop):
		camera_popover_backdrop.visible = false
	if is_instance_valid(camera_popover):
		camera_popover.visible = false
		camera_popover.scale = Vector2.ONE
		camera_popover.modulate.a = 1.0
	if is_instance_valid(btn_camera_menu):
		HudTheme.apply_rail_button_style(btn_camera_menu, false)


func _open_game_menu_drawer() -> void:
	_close_camera_popover()
	if not is_instance_valid(game_menu_drawer):
		return
	var g_info: Dictionary = GameRegistry.get_game_info(GameManager.current_game_type)
	if is_instance_valid(lbl_menu_game_title):
		lbl_menu_game_title.text = str(g_info.get("name_fa", "کافه فکر"))
	if is_instance_valid(lbl_menu_round_info):
		var r_txt: String = lbl_round.text if is_instance_valid(lbl_round) else ""
		lbl_menu_round_info.text = r_txt if not r_txt.is_empty() else "مسابقه آنلاین"
	if is_instance_valid(btn_surrender):
		btn_surrender.visible = not GameManager.is_spectating
	if is_instance_valid(menu_view):
		menu_view.visible = true
	if is_instance_valid(rules_view):
		rules_view.visible = false
	_update_audio_visual()
	_update_chat_toggle_button_visuals()
	game_menu_drawer.visible = true
	var card := game_menu_drawer.get_node_or_null("Card") as Control
	if is_instance_valid(card):
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.92, 0.92)
		card.modulate.a = 0.0
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.18)
		tw.parallel().tween_property(card, "modulate:a", 1.0, 0.14)


func _close_game_menu_drawer() -> void:
	if is_instance_valid(game_menu_drawer):
		game_menu_drawer.visible = false
	if is_instance_valid(menu_view):
		menu_view.visible = true
	if is_instance_valid(rules_view):
		rules_view.visible = false


func _update_chat_toggle_button_visuals() -> void:
	if not is_instance_valid(btn_toggle_chat):
		return
	var dis := GameManager.chat_and_stickers_disabled
	btn_toggle_chat.text = "چت و استیکر: غیرفعال" if dis else "چت و استیکر: فعال"
	if is_instance_valid(img_toggle_chat):
		img_toggle_chat.modulate = Color(0.6, 0.6, 0.6, 0.5) if dis else Color.WHITE
	HudTheme.apply_drawer_item_style(btn_toggle_chat, "danger" if dis else "default")
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_chat_and_stickers_enabled"):
		current_top_header.set_chat_and_stickers_enabled(not dis)


func _show_menu_rules() -> void:
	if is_instance_valid(menu_view):
		menu_view.visible = false
	if is_instance_valid(rules_view):
		rules_view.visible = true
	var g_info: Dictionary = GameRegistry.get_game_info(GameManager.current_game_type)
	if is_instance_valid(lbl_rules_title):
		lbl_rules_title.text = "راهنمای %s" % str(g_info.get("name_fa", "بازی"))
	if is_instance_valid(lbl_rules_body):
		lbl_rules_body.text = _load_game_rules_text(GameManager.current_game_type)


func _load_game_rules_text(game_type: String) -> String:
	if _game_docs_cache.is_empty() and FileAccess.file_exists("res://scripts/games/game_docs.json"):
		var f := FileAccess.open("res://scripts/games/game_docs.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_game_docs_cache = parsed
	var key := game_type.to_lower()
	var doc: Dictionary = _game_docs_cache.get(key, {})
	if doc.is_empty():
		return "قوانین این بازی به‌زودی تکمیل خواهد شد. از رقابت در کافه فکر لذت ببرید!"
	var sections: Array[String] = []
	var guide := str(doc.get("guide", "")).strip_edges()
	var gameplay := str(doc.get("gameplay", "")).strip_edges()
	var narrative := str(doc.get("narrative", "")).strip_edges()
	if not guide.is_empty():
		sections.append("📜 آشنایی و هدف بازی:\n" + guide)
	if not gameplay.is_empty():
		sections.append("♟️ نحوه انجام بازی:\n" + gameplay)
	if sections.is_empty() and not narrative.is_empty():
		sections.append(narrative)
	return "\n\n".join(sections)


func set_spectator_mode(enabled: bool) -> void:
	if is_instance_valid(btn_surrender):
		btn_surrender.visible = not enabled
	if is_instance_valid(btn_kori):
		btn_kori.visible = not enabled
	if is_instance_valid(btn_reactions):
		btn_reactions.visible = not enabled
	if enabled:
		set_fekrbekr_hud_buttons(false)
		if is_instance_valid(reaction_picker):
			reaction_picker.visible = false
			reaction_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(surrender_dialog):
			surrender_dialog.visible = false

func reset_for_new_match(keep_start_overlay: bool = false) -> void:

	set_fekrbekr_hud_buttons(false)
	set_spectator_mode(GameManager.is_spectating)
	_close_camera_popover()
	_close_game_menu_drawer()

	_surrender_handled = false

	_result_shown = false

	_last_reconnect_remaining_time = -1.0

	if _surrender_result_tween and _surrender_result_tween.is_valid():

		_surrender_result_tween.kill()

		_surrender_result_tween = null

	_countdown_run_id += 1
	is_start_overlay_dismissed = false

	is_countdown_running = false

	is_game_started = false

	is_game_finished = false

	is_round_finished = false

	is_timer_active = false

	is_wait_timer_mode = false

	turn_duration = GameRegistry.get_turn_time(GameManager.current_game_type)

	turn_time_left = turn_duration

	last_second_ticked = -1

	if keep_start_overlay:
		_show_start_overlay_immediately()
	else:
		_kill_overlay_tweens()
		start_overlay.visible = false

		start_overlay.modulate.a = 1.0

		intro_card.modulate.a = 1.0

		intro_card.scale = Vector2.ONE

		start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if start_overlay.has_node("Dimmer"):

			start_overlay.get_node("Dimmer").mouse_filter = Control.MOUSE_FILTER_IGNORE

		if intro_card:

			intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_camera_mode_indicator(true)

	_last_reaction_sent_msec = -10000

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

	if is_instance_valid(user_profile_dialog):
		user_profile_dialog.visible = false
		user_profile_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if reaction_picker and is_instance_valid(reaction_picker):

		reaction_picker.visible = false

		reaction_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if result_dialog and is_instance_valid(result_dialog):

		if result_dialog.has_method("close_immediate"):

			result_dialog.close_immediate()

		else:

			result_dialog.visible = false

			result_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE

	intro_p1_role.visible = true

	intro_p2_role.visible = true

	if not is_countdown_running:

		intro_countdown_lbl.text = "⏳"

		intro_countdown_lbl.add_theme_font_size_override("font_size", 56)

	_ensure_top_header_for_current_game()

	if is_instance_valid(current_top_header):

		current_top_header.reset_header()

	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):

		_turn_glow_tween.kill()

		_turn_glow_tween = null



var _intro_extra_cols: Dictionary = {}



func _ensure_intro_extra_col(idx: int) -> Dictionary:

	if _intro_extra_cols.has(idx) and is_instance_valid(_intro_extra_cols[idx].get("box")):

		return _intro_extra_cols[idx]

	var vs_box = get_node_or_null("StartGameOverlay/Card/VBox/VSBox") as HBoxContainer

	if not vs_box:

		return {}

	var col = VBoxContainer.new()

	col.name = "IntroP%d" % idx

	col.add_theme_constant_override("separation", 8)

	col.alignment = BoxContainer.ALIGNMENT_CENTER

	

	var av = TextureRect.new()

	av.name = "Avatar"

	av.custom_minimum_size = Vector2(104, 104)

	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	col.add_child(av)

	

	var nm = Label.new()

	nm.name = "Name"

	nm.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))

	nm.add_theme_font_size_override("font_size", 30)

	nm.add_theme_color_override("font_color", Color(1.0, 0.90, 0.80, 1.0))

	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	col.add_child(nm)

	

	var rl = Label.new()

	rl.name = "Role"

	rl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))

	rl.add_theme_font_size_override("font_size", 26)

	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	col.add_child(rl)

	

	vs_box.add_child(col)

	var info = {"box": col, "avatar": av, "name": nm, "role": rl}

	_intro_extra_cols[idx] = info

	return info



func _sync_multiplayer_intro_columns() -> void:

	var vs_box = get_node_or_null("StartGameOverlay/Card/VBox/VSBox") as HBoxContainer

	var vs_lbl = get_node_or_null("StartGameOverlay/Card/VBox/VSBox/VSLabel") as Label

	if not vs_box:

		return

	var total_p = GameManager.match_players.size()

	if total_p <= 2:

		vs_box.add_theme_constant_override("separation", 40)

		if is_instance_valid(vs_lbl):

			vs_lbl.visible = true

		if is_instance_valid(intro_p1_avatar):

			intro_p1_avatar.custom_minimum_size = Vector2(120, 120)

		if is_instance_valid(intro_p2_avatar):

			intro_p2_avatar.custom_minimum_size = Vector2(120, 120)

		for idx in [3, 4]:

			if _intro_extra_cols.has(idx) and is_instance_valid(_intro_extra_cols[idx].get("box")):

				_intro_extra_cols[idx]["box"].visible = false

		return

	

	vs_box.add_theme_constant_override("separation", 24 if total_p == 3 else 18)

	if is_instance_valid(vs_lbl):

		vs_lbl.visible = false

	if is_instance_valid(intro_p1_avatar):

		intro_p1_avatar.custom_minimum_size = Vector2(104, 104)

	if is_instance_valid(intro_p2_avatar):

		intro_p2_avatar.custom_minimum_size = Vector2(104, 104)

	

	for idx in [3, 4]:

		var col_info = _ensure_intro_extra_col(idx)

		if col_info.is_empty():

			continue

		if idx <= total_p:

			col_info["box"].visible = true

			var p_data = GameManager.get_player_data_by_gamer_id(idx)

			var p_name = str(p_data.get("name", p_data.get("username", "بازیکن %d" % idx)))

			col_info["name"].text = p_name

			var av_id = int(p_data.get("image", p_data.get("user_image", 0)))
			var p_fid = GameManager.get_player_frame_id(p_data)

			var tex = BaseTopHeaderClass._get_cached_avatar(av_id)

			if tex:

				col_info["avatar"].texture = tex
			var av_ctrl: TextureRect = col_info["avatar"]
			if is_instance_valid(av_ctrl):
				av_ctrl.custom_minimum_size = Vector2(106, 106)
				var av_p = av_ctrl.get_parent()
				CafeSocialTheme.apply_frame_to_container(av_p if av_p is Control else av_ctrl, av_ctrl, p_fid)

			if idx == 3:

				col_info["role"].text = "🟢 مهره سبز"

				col_info["role"].add_theme_color_override("font_color", Color(0.32, 0.92, 0.48))

			else:

				col_info["role"].text = "🟡 مهره زرد"

				col_info["role"].add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))

		else:

			col_info["box"].visible = false



func setup_match(game_title: String = "تیک تاک تو", mode_title: String = "لابی دوستانه") -> void:

	visible = true

	if is_instance_valid(user_profile_dialog):
		user_profile_dialog.visible = false
		user_profile_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_fekrbekr_hud_buttons(false)
	set_spectator_mode(GameManager.is_spectating)

	_ensure_top_header_for_current_game()



	if intro_cafe_title:

		intro_cafe_title.text = mode_title

	if intro_game_title:

		intro_game_title.text = game_title

	intro_p1_role.visible = true

	intro_p2_role.visible = true

	if not is_countdown_running:

		intro_countdown_lbl.text = "⏳"

		intro_countdown_lbl.add_theme_font_size_override("font_size", 56)

	

	var my_idx = GameManager.my_player_index

	var is_multi = GameManager.match_players.size() > 2

	var p1_data = GameManager.get_player_data_by_gamer_id(1) if is_multi else (GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data())

	var p2_data = GameManager.get_player_data_by_gamer_id(2) if is_multi else (GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data())

	

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

	

	_sync_multiplayer_intro_columns()

	var av1_id = int(p1_data.get("image", p1_data.get("user_image", 0)))
	var p1_fid = GameManager.get_player_frame_id(p1_data)
	var tex1 = BaseTopHeaderClass._get_cached_avatar(av1_id)
	if is_instance_valid(intro_p1_avatar):
		if tex1:
			intro_p1_avatar.texture = tex1
		var p1_p = intro_p1_avatar.get_parent()
		CafeSocialTheme.apply_frame_to_container(p1_p if p1_p is Control else intro_p1_avatar, intro_p1_avatar, p1_fid)

	var av2_id = int(p2_data.get("image", p2_data.get("user_image", 0)))
	var p2_fid = GameManager.get_player_frame_id(p2_data)
	var tex2 = BaseTopHeaderClass._get_cached_avatar(av2_id)
	if is_instance_valid(intro_p2_avatar):
		if tex2:
			intro_p2_avatar.texture = tex2
		var p2_p = intro_p2_avatar.get_parent()
		CafeSocialTheme.apply_frame_to_container(p2_p if p2_p is Control else intro_p2_avatar, intro_p2_avatar, p2_fid)



	# Initial clean state before game actually starts

	is_game_finished = false

	is_game_started = false

	is_timer_active = false

	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):

		_turn_glow_tween.kill()

		_turn_glow_tween = null


func refresh_players_only() -> void:
	var my_idx = GameManager.my_player_index
	var is_multi = GameManager.match_players.size() > 2
	var p1_data = GameManager.get_player_data_by_gamer_id(1) if is_multi else (GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data())
	var p2_data = GameManager.get_player_data_by_gamer_id(2) if is_multi else (GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data())
	if is_instance_valid(current_top_header):
		current_top_header.setup_players(p1_data, p2_data, my_idx)
		if current_top_header.has_method("set_profile_clicks_enabled"):
			current_top_header.set_profile_clicks_enabled(is_game_started)



func update_not_played_turns(gamer_id: int, count: int) -> void:

	if is_instance_valid(current_top_header) and current_top_header.has_method("update_not_played_turns"):

		current_top_header.update_not_played_turns(gamer_id, count)

	var cafe_table = get_parent()
	if cafe_table and "current_board_node" in cafe_table and is_instance_valid(cafe_table.current_board_node):
		var b_node = cafe_table.current_board_node
		if b_node.has_method("on_not_played_turns_updated"):
			b_node.on_not_played_turns_updated(gamer_id, count)

	var max_turns: int = max(2, GameRegistry.get_max_missed_turns(GameManager.current_game_type))

	# Warnings & Sound Juice
	if count > 0:

		if gamer_id == GameManager.my_player_index:

			AudioManager.play_sound("bell")

			if count < max_turns:

				show_toast_hint("⚠️ نوبت شما سپری شد! در صورت عدم حرکت در %s نوبت، بازنده خواهید شد (خطای %s از %s)" % [_fa_digits(max_turns), _fa_digits(count), _fa_digits(max_turns)])

			else:

				show_toast_hint("🚨 اخطار نهایی! عدم حرکت در %s نوبت پیاپی منجر به باخت فنی شد." % _fa_digits(max_turns))

		else:

			if count < max_turns:

				show_toast_hint("⚠️ حریف در زمان مجاز حرکت نکرد (خطای %s از %s)" % [_fa_digits(count), _fa_digits(max_turns)])

			else:

				show_toast_hint("⚠️ حریف به دلیل عدم حرکت در %s نوبت پیاپی بازنده اعلام شد." % _fa_digits(max_turns))



var _countdown_pulse_tween: Tween = null
var _countdown_run_id: int = 0



func _start_loading_pulse() -> void:

	_stop_loading_pulse()

	if not intro_countdown_lbl or not is_instance_valid(intro_countdown_lbl):

		return

	intro_countdown_lbl.custom_minimum_size = Vector2(360, 130)

	intro_countdown_lbl.pivot_offset = Vector2(180, 65)

	intro_countdown_lbl.scale = Vector2.ONE

	_loading_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_loading_pulse_tween.tween_property(intro_countdown_lbl, "scale", Vector2(1.12, 1.12), 0.55)

	_loading_pulse_tween.tween_property(intro_countdown_lbl, "scale", Vector2(0.94, 0.94), 0.55)



func _stop_loading_pulse() -> void:

	if _loading_pulse_tween and _loading_pulse_tween.is_valid():

		_loading_pulse_tween.kill()

		_loading_pulse_tween = null

	if _countdown_pulse_tween and _countdown_pulse_tween.is_valid():

		_countdown_pulse_tween.kill()

		_countdown_pulse_tween = null

	if intro_countdown_lbl and is_instance_valid(intro_countdown_lbl):

		intro_countdown_lbl.custom_minimum_size = Vector2(360, 130)

		intro_countdown_lbl.pivot_offset = Vector2(180, 65)

		intro_countdown_lbl.scale = Vector2.ONE



func _kill_overlay_tweens() -> void:
	for ctrl in [start_overlay, intro_card]:
		if is_instance_valid(ctrl) and ctrl.has_meta("_vfx_tween"):
			var old_tw: Variant = ctrl.get_meta("_vfx_tween")
			if old_tw is Tween and old_tw.is_valid():
				old_tw.kill()
			ctrl.remove_meta("_vfx_tween")


func _show_start_overlay_immediately() -> void:
	_kill_overlay_tweens()
	if is_instance_valid(start_overlay):
		start_overlay.visible = true
		start_overlay.modulate.a = 1.0
		start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if start_overlay.has_node("Dimmer"):
			start_overlay.get_node("Dimmer").mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(intro_card):
		intro_card.visible = true
		intro_card.modulate.a = 1.0
		intro_card.scale = Vector2.ONE
		intro_card.mouse_filter = Control.MOUSE_FILTER_STOP


# Shows the initial match connection loading overlay

func show_match_loading(status_text: String = "در حال آماده‌سازی میز مسابقه و همگام‌سازی بازیکنان...", immediate: bool = false) -> void:

	if is_start_overlay_dismissed or is_game_started:

		return

	is_game_finished = false

	is_game_started = false

	is_timer_active = false

	is_countdown_running = false

	lbl_turn_banner.text = "بازی درحال آغاز است"

	lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if is_instance_valid(lbl_timer):
		lbl_timer.text = ""
		lbl_timer.visible = false

	turn_timer_bar.value = 100.0

	

	intro_status_lbl.text = status_text

	intro_countdown_lbl.custom_minimum_size = Vector2(360, 130)

	intro_countdown_lbl.pivot_offset = Vector2(180, 65)

	intro_countdown_lbl.text = "⏳"

	intro_countdown_lbl.add_theme_font_size_override("font_size", 56)

	intro_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))

	intro_p1_role.visible = true

	intro_p2_role.visible = true

	

	_start_loading_pulse()

	

	if immediate:
		_show_start_overlay_immediately()
	elif not start_overlay.visible:

		ActionVFXManager.animate_dialog_open(intro_card, start_overlay, true)



func set_overlay_status(status_text: String) -> void:

	intro_status_lbl.text = status_text



# Ignore server Game_Play_Time elapsed counter ticks when local play_start_countdown is already running

func update_start_countdown_time(_sec: int) -> void:

	return



# Plays synchronized pre-game loading countdown

func play_start_countdown(on_finished: Callable = Callable(), total_seconds: int = 5, immediate: bool = true) -> void:
	if is_start_overlay_dismissed or is_game_started or GameManager.is_game_active:
		if on_finished.is_valid():
			on_finished.call()
		return
	if is_countdown_running:
		if on_finished.is_valid():
			on_finished.call()
		return

	_countdown_run_id += 1
	var my_run_id: int = _countdown_run_id
	is_countdown_running = true
	is_game_started = false
	is_timer_active = false
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_stop_loading_pulse()
	intro_countdown_lbl.add_theme_font_size_override("font_size", 98)
	if immediate or start_overlay.visible:
		_show_start_overlay_immediately()
	else:
		start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if immediate:
		intro_p1_role.modulate.a = 1.0
		intro_p2_role.modulate.a = 1.0
	else:
		intro_p1_role.modulate.a = 0.0
		intro_p2_role.modulate.a = 0.0
		var tw_roles = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_roles.tween_property(intro_p1_role, "modulate:a", 1.0, 0.4)
		tw_roles.tween_property(intro_p2_role, "modulate:a", 1.0, 0.4)

	for i in range(total_seconds, 0, -1):
		if my_run_id != _countdown_run_id or not start_overlay.visible or is_start_overlay_dismissed:
			return
		intro_countdown_lbl.text = "%d" % i
		_pulse_countdown_label()
		AudioManager.play_sound("time")
		await get_tree().create_timer(1.0).timeout

	if my_run_id != _countdown_run_id:
		return

	if start_overlay.visible and not is_start_overlay_dismissed:
		intro_countdown_lbl.text = "شروع!"
		intro_countdown_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		_pulse_countdown_label()
		AudioManager.play_sound("bell")
		await get_tree().create_timer(0.4).timeout
		if my_run_id != _countdown_run_id:
			return
		force_dismiss_start_overlay()
	else:
		force_dismiss_start_overlay()

	is_countdown_running = false
	if on_finished.is_valid():
		on_finished.call()


# Guarantees the loading overlay is dismissed as soon as the intro countdown finishes or match becomes active

func force_dismiss_start_overlay(emit_finished: bool = true) -> void:
	_countdown_run_id += 1
	_stop_loading_pulse()
	var was_visible: bool = is_instance_valid(start_overlay) and start_overlay.visible
	is_start_overlay_dismissed = true
	is_countdown_running = false
	if is_instance_valid(start_overlay):
		start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if start_overlay.has_node("Dimmer"):
			start_overlay.get_node("Dimmer").mouse_filter = Control.MOUSE_FILTER_IGNORE
	if intro_card:
		intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if was_visible:
		var table_node: Node = get_tree().get_first_node_in_group("cafe_table")
		if is_instance_valid(table_node) and table_node.has_method("play_desk_approach_intro"):
			table_node.call("play_desk_approach_intro")
		ActionVFXManager.animate_dialog_close(intro_card, start_overlay, func():
			if is_instance_valid(start_overlay):
				start_overlay.visible = false
			if emit_finished:
				start_countdown_finished.emit()
		)
	else:
		if is_instance_valid(start_overlay):
			start_overlay.visible = false
		var table_node2: Node = get_tree().get_first_node_in_group("cafe_table")
		if is_instance_valid(table_node2) and table_node2.has_method("play_desk_approach_intro"):
			table_node2.call("play_desk_approach_intro")
		if emit_finished:
			start_countdown_finished.emit()
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_profile_clicks_enabled"):
		current_top_header.set_profile_clicks_enabled(true)
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

	if not intro_countdown_lbl or not is_instance_valid(intro_countdown_lbl):

		return

	if _countdown_pulse_tween and _countdown_pulse_tween.is_valid():

		_countdown_pulse_tween.kill()

	intro_countdown_lbl.custom_minimum_size = Vector2(360, 130)

	intro_countdown_lbl.pivot_offset = Vector2(180, 65)

	intro_countdown_lbl.scale = Vector2(1.16, 1.16)

	_countdown_pulse_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_countdown_pulse_tween.tween_property(intro_countdown_lbl, "scale", Vector2.ONE, 0.20)



# Shows between-rounds banner dialog (like Flutter's showFinishRoundDialog)

func stop_round_timer() -> void:

	is_round_finished = true

	is_timer_active = false

	last_second_ticked = -1

	turn_time_left = 0.0

	turn_timer_bar.value = 0.0

	lbl_timer.text = "-- ثانیه"

	if is_instance_valid(current_top_header) and current_top_header.has_method("update_timer"):
		current_top_header.update_timer(0.0, max(1.0, turn_duration), 0)

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



func show_game_transition_banner(game_num: int, winner_idx: int, p1_s: int, p2_s: int, next_game_name: String, countdown_time: int = 20) -> void:

	stop_timer()

	stop_round_timer()

	is_round_finished = true

	round_finish_title.text = "🏆 پایان بازی %d از ۳" % game_num

	round_finish_score.text = "📊 نتیجه مسابقه: %d - %d  |  شروع بازی بعدی: %s (در %d ثانیه)..." % [p1_s, p2_s, next_game_name, countdown_time]

	

	var my_idx = GameManager.my_player_index

	var p1_data = GameManager.get_my_player_data() if my_idx == 1 else GameManager.get_opponent_player_data()

	var p2_data = GameManager.get_opponent_player_data() if my_idx == 1 else GameManager.get_my_player_data()

	var p1_user = p1_data.get("name", p1_data.get("username", "بازیکن ۱"))

	var p2_user = p2_data.get("name", p2_data.get("username", "بازیکن ۲"))

	

	if winner_idx == 0:

		round_finish_desc.text = "🤝 این بازی مساوی شد!"

		round_finish_desc.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))

		AudioManager.play_sound("draw")

	elif winner_idx == 1:

		if my_idx == 1:

			round_finish_desc.text = "🎉 تبریک! شما برنده این بازی شدید (%s)" % p1_user

			round_finish_desc.add_theme_color_override("font_color", Color(0.38, 0.95, 0.50))

		else:

			round_finish_desc.text = "🔴 برنده این بازی: %s" % p1_user

			round_finish_desc.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

		AudioManager.play_sound("win" if my_idx == 1 else "lose")

	elif winner_idx == 2:

		if my_idx == 2:

			round_finish_desc.text = "🎉 تبریک! شما برنده این بازی شدید (%s)" % p2_user

			round_finish_desc.add_theme_color_override("font_color", Color(0.38, 0.95, 0.50))

		else:

			round_finish_desc.text = "🔵 برنده این بازی: %s" % p2_user

			round_finish_desc.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))

		AudioManager.play_sound("win" if my_idx == 2 else "lose")

		

	ActionVFXManager.animate_dialog_open(round_finish_card, round_finish_banner, true, false)



func update_transition_countdown(time_left: int, next_game_name: String, p1_s: int, p2_s: int) -> void:

	if round_finish_banner and round_finish_banner.visible:

		round_finish_score.text = "📊 نتیجه مسابقه: %d - %d  |  شروع بازی بعدی: %s (در %d ثانیه)..." % [p1_s, p2_s, next_game_name, time_left]



func hide_game_transition_banner() -> void:

	hide_round_finish_banner()



# Shows auto-pause overlay when a user disconnects

func show_pause_dialog(wait_time: int, reason_text: String = "") -> void:

	is_pause_active = true

	_last_pause_sec_ticked = -1

	var actual_time = wait_time if wait_time > 0 else 60

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



func pause_turn_timer() -> void:

	is_timer_active = false

	AudioManager.stop_sound("time")



func resume_timer_on_user_reconnected(remaining_time: int) -> void:

	var max_time = GameRegistry.get_turn_time(GameManager.current_game_type)

	turn_duration = max_time

	if remaining_time > 0:

		_last_reconnect_remaining_time = float(remaining_time)

		turn_time_left = clampf(float(remaining_time), 1.0, max_time)

	elif turn_time_left <= 0.0:

		turn_time_left = max_time

	is_game_started = true

	is_start_overlay_dismissed = true

	is_round_finished = false

	is_pause_active = false

	is_wait_timer_mode = false

	is_timer_active = true

	last_second_ticked = -1

	if is_instance_valid(current_top_header):

		current_top_header._last_displayed_sec = -1

		current_top_header.update_timer(turn_time_left, turn_duration, GameManager.current_turn)

	var sec = int(ceil(turn_time_left))

	if is_instance_valid(lbl_timer):

		lbl_timer.text = ""
		lbl_timer.visible = false

	if is_instance_valid(turn_timer_bar):

		turn_timer_bar.value = (turn_time_left / maxf(1.0, turn_duration)) * 100.0



func sync_reconnect_timer(payload: Dictionary) -> void:

	var max_time = GameRegistry.get_turn_time(GameManager.current_game_type)
	var is_quiz_payload: bool = (GameManager.current_game_type == GameTypes.QUIZ or str(payload.get("game_type", "")).to_lower() == "quiz" or payload.has("current_question"))
	var is_quiz_wait: bool = is_quiz_payload and bool(payload.get("is_turn_round_finished", false))

	if GameManager.current_game_type == GameTypes.BATTLESHIP:

		var gd = payload.get("game_data", {})

		if typeof(gd) == TYPE_DICTIONARY and not bool(gd.get("is_play_phase", false)):

			max_time = 60.0

	elif is_quiz_wait:

		max_time = 4.0

	turn_duration = max_time

	var timer_data = payload.get("timer_data", {})

	if typeof(timer_data) == TYPE_DICTIONARY and timer_data.has("time") and float(timer_data.get("time", 0)) > 0.0:

		var elapsed = float(timer_data.get("time", 0))

		turn_time_left = clampf(max_time - elapsed, 1.0, max_time)

	elif is_quiz_payload and payload.has("time") and float(payload.get("time", 0)) > 0.0:

		# Quiz backend sends direct remaining seconds at top level "time"
		turn_time_left = clampf(float(payload.get("time", max_time)), 1.0, max_time)

	elif _last_reconnect_remaining_time > 0.0:

		turn_time_left = clampf(_last_reconnect_remaining_time, 1.0, max_time)

	else:

		turn_time_left = max_time

	_last_reconnect_remaining_time = -1.0

	is_game_started = true

	is_start_overlay_dismissed = true

	is_round_finished = false

	is_pause_active = false

	is_wait_timer_mode = is_quiz_wait

	is_timer_active = true

	last_second_ticked = -1

	if is_instance_valid(current_top_header):

		current_top_header._last_displayed_sec = -1

		current_top_header.update_timer(turn_time_left, turn_duration, GameManager.current_turn)

	var sec = int(ceil(turn_time_left))

	if is_instance_valid(lbl_timer):

		lbl_timer.text = ""
		lbl_timer.visible = false

	if is_instance_valid(turn_timer_bar):

		turn_timer_bar.value = (turn_time_left / maxf(1.0, turn_duration)) * 100.0



# Handles full game reconnect data payload (re-syncs gamers, round, scores, turn, and timer)

func handle_reconnect_data(payload: Dictionary, show_toast: bool = true) -> void:

	visible = true

	_surrender_handled = false

	_result_shown = false

	hide_pause_dialog()

	force_dismiss_start_overlay(false)

	

	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:

		GameManager.set_match_gamers(payload["gamers"])

		if show_toast:
			setup_match(GameManager.get_game_display_name(), "مسابقه زنده")
		else:
			refresh_players_only()

		

	GameManager.is_game_active = true

	is_game_started = true

	is_round_finished = false

	is_game_finished = false

	force_dismiss_start_overlay(false)

	if pause_dialog and is_instance_valid(pause_dialog):

		hide_pause_dialog()

	var game_data = payload.get("game_data", {})
	var is_quiz_reconnect = (GameManager.current_game_type == GameTypes.QUIZ or str(payload.get("game_type", "")).to_lower() == "quiz" or payload.has("current_question"))

	if is_quiz_reconnect:

		var q_src = game_data if (typeof(game_data) == TYPE_DICTIONARY and not game_data.is_empty()) else payload
		var q_scores = q_src.get("scores", {})
		if typeof(q_scores) == TYPE_DICTIONARY:
			var s1 = int(q_scores.get(1, q_scores.get("1", 0)))
			var s2 = int(q_scores.get(2, q_scores.get("2", 0)))
			update_scores(s1, s2)
			if is_instance_valid(current_top_header) and current_top_header.has_method("update_quiz_scores"):
				current_top_header.update_quiz_scores(q_scores)
		elif typeof(q_scores) == TYPE_ARRAY and (q_scores as Array).size() >= 2:
			update_scores(int(q_scores[0]), int(q_scores[1]))
		var q_turn = max(1, int(q_src.get("current_turn", GameManager.current_turn)))
		var q_total = max(1, int(q_src.get("total_questions", 10)))
		if is_instance_valid(current_top_header) and current_top_header.has_method("set_question_number"):
			current_top_header.set_question_number(q_turn, q_total)
		if not bool(q_src.get("is_turn_round_finished", false)):
			update_turn(q_turn)

	elif typeof(game_data) == TYPE_DICTIONARY:

		var scores = game_data.get("scores", [0, 0])

		if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:

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

		elif GameManager.current_game_type == GameTypes.BATTLESHIP:

			var is_play_rec = bool(game_data.get("is_play_phase", false))

			var is_waiting = bool(game_data.get("is_player_rdy", false))

			if is_play_rec:

				var b_turn = int(game_data.get("current_turn", 1))

				update_turn(max(1, b_turn))

			else:

				set_setup_phase()

			set_fekrbekr_hud_buttons(is_play_rec)

			if not is_play_rec and is_waiting:

				set_waiting_opponent("ناوگان شما ثبت شد. در انتظار حریف...")

		elif GameManager.current_game_type == GameTypes.YATZY:

			update_turn(max(1, r_num))

			if bool(game_data.get("is_round_done", false)):

				set_waiting_opponent("امتیاز شما ثبت شد! در انتظار حریف...")

		else:

			var turn = int(game_data.get("current_turn", 1))

			update_turn(turn)

		

	sync_reconnect_timer(payload)

	if show_toast:
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

	if is_instance_valid(result_dialog) and result_dialog.has_method("update_scores"):

		result_dialog.update_scores(p1_s, p2_s)



func hide_turn_banner() -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = ""
	if is_instance_valid(current_top_header):
		if is_instance_valid(current_top_header.lbl_turn_banner):
			current_top_header.lbl_turn_banner.text = ""
		if current_top_header.has_method("hide_turn_toast"):
			current_top_header.hide_turn_toast()

func set_custom_banner(msg: String, color: Color = Color(1.0, 0.90, 0.45)) -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = msg
		lbl_turn_banner.add_theme_color_override("font_color", color)
	if is_instance_valid(current_top_header):
		if is_instance_valid(current_top_header.lbl_turn_banner):
			current_top_header.lbl_turn_banner.text = msg
			current_top_header.lbl_turn_banner.add_theme_color_override("font_color", color)
		if current_top_header.has_method("show_turn_toast"):
			current_top_header.show_turn_toast(msg, color, false, 2.2)



func start_turn_timer(duration: float, custom_banner: String = "") -> void:

	if is_game_finished:

		return

	turn_duration = duration

	turn_time_left = duration

	last_second_ticked = -1

	is_wait_timer_mode = false

	is_timer_active = true

	is_game_started = true

	if is_instance_valid(current_top_header) and current_top_header.has_method("set_profile_clicks_enabled"):
		current_top_header.set_profile_clicks_enabled(true)

	var banner = custom_banner

	if banner.is_empty() and GameRegistry.is_simultaneous(GameManager.current_game_type):

		if GameManager.current_game_type == GameTypes.RPC:

			banner = "سنگ، کاغذ یا قیچی را انتخاب کنید!"

		elif GameManager.current_game_type == GameTypes.SUDOKU:

			banner = "جدول سودوکو را با اعداد ۱ تا ۹ تکمیل کنید"

		elif GameManager.current_game_type == GameTypes.MSWEEPER:

			banner = "خانه‌های امن را باز کنید و ۱۰ مین را پرچم‌گذاری نمایید"

		elif GameManager.current_game_type == GameTypes.QUIZ:

			banner = "🤔 گزینه درست را روی میز انتخاب کنید"

		else:

			banner = "انتخاب خود را مشخص کنید"

	if not banner.is_empty():

		set_custom_banner(banner, Color(1.0, 0.90, 0.45))

	if is_instance_valid(current_top_header):

		current_top_header.update_timer(turn_time_left, turn_duration, GameManager.current_turn)



func start_wait_timer(wait_sec: int, msg: String = "") -> void:

	if is_game_finished:

		return

	var banner_text = msg if not msg.is_empty() else ("بازی درحال آغاز است" if not GameManager.is_game_active else "⏳ آماده‌سازی مرحله بعدی...")

	turn_duration = float(wait_sec)

	turn_time_left = float(wait_sec)

	last_second_ticked = -1

	is_wait_timer_mode = true

	is_timer_active = true

	is_game_started = true

	if is_instance_valid(current_top_header):

		if msg.is_empty() and current_top_header.has_method("set_round_wait"):

			current_top_header.set_round_wait(wait_sec)

		current_top_header.update_timer(turn_time_left, turn_duration, 0)

	set_custom_banner(banner_text, Color(1.0, 0.88, 0.45))



func start_pre_game_countdown(wait_sec: int = 5) -> void:

	if is_game_finished or GameManager.is_game_active:

		return

	set_fekrbekr_hud_buttons(false)

	if is_start_overlay_dismissed and not is_countdown_running:

		start_wait_timer(wait_sec, "بازی درحال آغاز است")



func set_setup_phase() -> void:

	set_fekrbekr_hud_buttons(false)

	if is_instance_valid(current_top_header) and current_top_header.has_method("set_setup_phase"):

		current_top_header.set_setup_phase()

	var def_time = 60.0 if GameManager.current_game_type == GameTypes.BATTLESHIP else GameRegistry.get_turn_time(GameManager.current_game_type)

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

	var is_me = (turn == GameManager.my_player_index) if not GameRegistry.is_simultaneous(GameManager.current_game_type) else true

	

	# Current_Turn signal proves match is actively running!

	if not is_countdown_running:

		force_dismiss_start_overlay(false)



	hide_round_finish_banner()



	



	var def_time = GameRegistry.get_turn_time(GameManager.current_game_type)



	start_turn_timer(def_time)



	



	var is_multi = GameManager.match_players.size() > 2

	var p1_data = GameManager.get_player_data_by_gamer_id(1) if is_multi else (GameManager.get_my_player_data() if GameManager.my_player_index == 1 else GameManager.get_opponent_player_data())

	var p2_data = GameManager.get_player_data_by_gamer_id(2) if is_multi else (GameManager.get_opponent_player_data() if GameManager.my_player_index == 1 else GameManager.get_my_player_data())

	var p1_n = str(p1_data.get("name", p1_data.get("username", "میزبان")))

	var p2_n = str(p2_data.get("name", p2_data.get("username", "مهمان")))

	if is_instance_valid(current_top_header):

		current_top_header.update_turn(turn, GameManager.my_player_index, p1_n, p2_n)

	if is_me and is_game_started:

		AudioManager.play_sound("start_turn")


func set_player_disabled(player_idx: int, disabled: bool, reason_text: String = "خارج شد") -> void:
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_player_disabled"):
		current_top_header.set_player_disabled(player_idx, disabled, reason_text)



func stop_timer() -> void:

	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):

		_turn_glow_tween.kill()

		_turn_glow_tween = null

	if p1_card and is_instance_valid(p1_card):
		if not (is_instance_valid(current_top_header) and current_top_header.has_method("is_player_disabled") and current_top_header.is_player_disabled(1)):
			p1_card.modulate = Color.WHITE
			p1_card.scale = Vector2.ONE

	if p2_card and is_instance_valid(p2_card):
		if not (is_instance_valid(current_top_header) and current_top_header.has_method("is_player_disabled") and current_top_header.is_player_disabled(2)):
			p2_card.modulate = Color.WHITE
			p2_card.scale = Vector2.ONE

	is_timer_active = false

	last_second_ticked = -1

	turn_time_left = 0.0

	turn_timer_bar.value = 0.0

	if is_instance_valid(lbl_timer):
		lbl_timer.text = ""
		lbl_timer.visible = false

	if is_instance_valid(current_top_header) and current_top_header.has_method("update_timer"):
		current_top_header.update_timer(0.0, max(1.0, turn_duration), 0)

	AudioManager.stop_sound("time")



func set_camera_mode_indicator(is_top_down: bool) -> void:
	if is_instance_valid(current_top_header) and current_top_header.has_method("set_camera_mode_indicator"):
		current_top_header.set_camera_mode_indicator(is_top_down)
	var target_tex: Texture2D = _cam_3d_tex if is_top_down else _cam_2d_tex
	if btn_cam_top and is_instance_valid(btn_cam_top):
		btn_cam_top.text = ""
		if img_cam_top and is_instance_valid(img_cam_top):
			img_cam_top.texture = target_tex
	if is_instance_valid(img_camera_menu):
		img_camera_menu.texture = target_tex



func show_reaction(user_index: int, reaction_id: int) -> void:

	if is_instance_valid(current_top_header):

		current_top_header.show_reaction(user_index, reaction_id)



func show_surrender_notification(surrendered_gamer_id: int) -> void:

	if _surrender_handled or _result_shown:

		return

	_surrender_handled = true

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

		

	# In ranked series (multi-game), surrender forfeits ONLY current game, moving to next game if available!

	var is_ranked_series = (GameManager.current_match_mode == "ranked")

	if is_ranked_series:

		print("[HUD] Ranked series: player surrendered current round. Awaiting transition to next game...")

		return



	# Show result modal after 1.5s if not already shown by server Finish_Game command (for single-game modes)

	if _surrender_result_tween and _surrender_result_tween.is_valid():

		_surrender_result_tween.kill()

	_surrender_result_tween = create_tween()

	_surrender_result_tween.tween_interval(1.5)

	_surrender_result_tween.tween_callback(func():

		show_game_result(winner_idx, GameManager.p1_score, GameManager.p2_score)

	)



func show_game_result(winner: int, p1_score: int, p2_score: int, xp_earned: int = 0, coin_earned: int = 0, score_earned: int = 0) -> void:

	if _result_shown:

		if (xp_earned > 0 or coin_earned > 0 or score_earned != 0) and is_instance_valid(result_dialog) and result_dialog.has_method("update_xp"):

			result_dialog.update_xp(xp_earned, coin_earned, score_earned)

		return

	_result_shown = true

	if _surrender_result_tween and _surrender_result_tween.is_valid():

		_surrender_result_tween.kill()

		_surrender_result_tween = null

	is_game_finished = true

	stop_timer()

	var final_winner = winner

	if GameManager.local_player_surrendered:

		final_winner = 2 if GameManager.my_player_index == 1 else 1

	elif GameManager.opponent_player_surrendered:

		final_winner = GameManager.my_player_index

	elif not is_pause_active and GameManager.get_player_not_played_turns(1) < 2 and GameManager.get_player_not_played_turns(2) < 2:

		if GameManager.current_game_type in [GameTypes.DOTBOX, GameTypes.OTHELLO, GameTypes.MNUMBERS, GameTypes.BATTLESHIP, GameTypes.YATZY, GameTypes.RPC, GameTypes.TIC_TAC_TOE, GameTypes.MSWEEPER, GameTypes.BOXFOUR]:

			if p1_score > p2_score:

				final_winner = 1

			elif p2_score > p1_score:

				final_winner = 2

	var is_friendly = (xp_earned <= 0 and coin_earned <= 0 and score_earned == 0)

	AudioManager.play_theme_music()
	result_dialog.show_result(final_winner, p1_score, p2_score, is_friendly, xp_earned, coin_earned, score_earned)



func _update_audio_visual() -> void:
	var audio_on: bool = bool(AudioManager.is_music_enabled)
	if is_instance_valid(img_audio):
		img_audio.texture = _sound_on_tex if audio_on else _sound_off_tex
	if is_instance_valid(btn_audio):
		btn_audio.text = "صدا و موسیقی: روشن" if audio_on else "صدا و موسیقی: خاموش"



func _exit_tree() -> void:

	if _turn_glow_tween and is_instance_valid(_turn_glow_tween):

		_turn_glow_tween.kill()

		_turn_glow_tween = null



# Updates visibility of FekrBekr dedicated HUD action buttons

# Phase 1: Only Checkmark (✓) and Cross (✕) are visible

# Phase 2: All 4 buttons (✓, ✕, 🎯, 👥) are visible

var _bs_ship_row: HBoxContainer = null
var _bs_ship_buttons: Dictionary = {}

func _style_monopoly_action_button(btn: Button, bg_col: Color, border_col: Color, is_primary: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	var bw: int = 3 if is_primary else 2
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = bg_col
	normal_sb.border_color = Color(1.0, 0.92, 0.42, 0.98) if is_primary else border_col
	normal_sb.set_border_width_all(bw)
	normal_sb.set_corner_radius_all(14)
	normal_sb.shadow_color = Color(0, 0, 0, 0.45)
	normal_sb.shadow_size = 4
	normal_sb.content_margin_left = 10
	normal_sb.content_margin_right = 10
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6

	var hover_sb = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg_col.lightened(0.12)
	hover_sb.border_color = normal_sb.border_color.lightened(0.18)

	var pressed_sb = normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = bg_col.darkened(0.12)

	var disabled_sb = StyleBoxFlat.new()
	disabled_sb.bg_color = Color(0.14, 0.13, 0.16, 0.78)
	disabled_sb.border_color = Color(0.36, 0.34, 0.38, 0.50)
	disabled_sb.set_border_width_all(1)
	disabled_sb.set_corner_radius_all(14)
	disabled_sb.content_margin_left = 10
	disabled_sb.content_margin_right = 10
	disabled_sb.content_margin_top = 6
	disabled_sb.content_margin_bottom = 6

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	btn.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	btn.add_theme_font_size_override("font_size", 24 if is_primary else 22)
	btn.add_theme_color_override("font_color", Color.WHITE if is_primary else Color(0.96, 0.94, 0.90))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.95))
	btn.add_theme_constant_override("outline_size", 3)
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _build_battleship_ship_row() -> void:
	if not is_instance_valid(fekrbekr_actions):
		return
	if is_instance_valid(_bs_ship_row):
		return

	_bs_ship_row = HBoxContainer.new()
	_bs_ship_row.name = "BattleshipShipRow"
	_bs_ship_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bs_ship_row.offset_left = 0.0
	_bs_ship_row.offset_right = 0.0
	_bs_ship_row.offset_top = 0.0
	_bs_ship_row.offset_bottom = 54.0
	_bs_ship_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bs_ship_row.add_theme_constant_override("separation", 10)
	_bs_ship_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bs_ship_row.visible = false
	fekrbekr_actions.add_child(_bs_ship_row)

	var ship_specs = [
		{"len": 5, "txt": "🚢 ناو ۵"},
		{"len": 4, "txt": "🚢 ناو ۴"},
		{"len": 3, "txt": "🚢 ناو ۳"},
		{"len": 2, "txt": "🚢 ناو ۲"}
	]
	for spec in ship_specs:
		var s_len = int(spec["len"])
		var btn = Button.new()
		btn.text = spec["txt"]
		btn.custom_minimum_size = Vector2(96.0, 46.0)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_style_monopoly_action_button(btn, Color(0.12, 0.28, 0.44, 0.96), Color(0.48, 0.78, 1.0, 0.90), false)
		btn.add_theme_font_size_override("font_size", 18)
		btn.clip_text = false
		btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			var board = get_tree().get_first_node_in_group("battleship_board")
			if is_instance_valid(board) and board.has_method("select_or_rotate_ship"):
				board.select_or_rotate_ship(s_len)
		)
		_bs_ship_row.add_child(btn)
		_bs_ship_buttons[s_len] = btn

func set_fekrbekr_hud_buttons(is_play_phase: bool) -> void:
	if not (GameManager.current_game_type in [GameTypes.FEKRBEKR, GameTypes.BATTLESHIP]) or not GameManager.is_game_active:
		if is_instance_valid(fekrbekr_actions):
			fekrbekr_actions.visible = false
		return
	if is_instance_valid(fekrbekr_actions):
		fekrbekr_actions.visible = true

	var is_bs: bool = (GameManager.current_game_type == GameTypes.BATTLESHIP)
	var is_bs_phase1: bool = (is_bs and not is_play_phase)

	if is_bs_phase1:
		_build_battleship_ship_row()
		if is_instance_valid(_bs_ship_row):
			_bs_ship_row.visible = true
		if is_instance_valid(fekrbekr_actions):
			fekrbekr_actions.offset_top = -_safe_bottom_inset - 130.0
		var vbox = fekrbekr_actions.get_node_or_null("VBox") as Control
		if is_instance_valid(vbox):
			vbox.offset_top = 56.0
			vbox.offset_bottom = 120.0
	else:
		if is_instance_valid(_bs_ship_row):
			_bs_ship_row.visible = false
		if is_instance_valid(fekrbekr_actions):
			fekrbekr_actions.offset_top = -_safe_bottom_inset - 64.0
		var vbox = fekrbekr_actions.get_node_or_null("VBox") as Control
		if is_instance_valid(vbox):
			vbox.offset_top = 0.0
			vbox.offset_bottom = 0.0

	if is_instance_valid(btn_fekr_submit):
		btn_fekr_submit.visible = (not is_play_phase) if is_bs else true
		if not is_bs:
			btn_fekr_submit.text = "✅ ثبت حدس" if is_play_phase else "✅ ثبت رمز"
		else:
			btn_fekr_submit.text = "✅ تأیید چیدمان"
	if is_instance_valid(btn_fekr_clear):
		btn_fekr_clear.visible = (not is_play_phase) if is_bs else true
		if not is_bs:
			btn_fekr_clear.text = "✕ پاک کردن"
		else:
			btn_fekr_clear.text = "🎲 چیدمان خودکار"
	if is_instance_valid(btn_fekr_opp):
		btn_fekr_opp.visible = is_play_phase
		btn_fekr_opp.text = "🎯 میدان نبرد" if is_bs else "🎯 صفحه حریف"
	if is_instance_valid(btn_fekr_dual):
		btn_fekr_dual.visible = is_play_phase
		btn_fekr_dual.text = "👥 نمای همزمان" if is_bs else "👥 نمای دوطرفه"

	# Sizing & Font sizing:
	if not is_play_phase:
		# Phase 1: Center with padding, no stretched width, comfortable font & icons
		for btn in [btn_fekr_submit, btn_fekr_clear]:
			if is_instance_valid(btn):
				btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				btn.custom_minimum_size = Vector2(195.0, 54.0)
				btn.add_theme_font_size_override("font_size", 20)
				btn.clip_text = false
				btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	else:
		# Phase 2: Larger text & icons, comfortable sizing
		for btn in [btn_fekr_submit, btn_fekr_clear, btn_fekr_opp, btn_fekr_dual]:
			if is_instance_valid(btn):
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.custom_minimum_size = Vector2(120.0, 54.0)
				btn.add_theme_font_size_override("font_size", 22)

static func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out
