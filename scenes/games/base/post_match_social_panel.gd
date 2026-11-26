class_name PostMatchSocialPanel
extends VBoxContainer

# Warm Classic Parlor Post-Match Social & Rivalry Component
# Mounted inside GameResultDialog (Lobby/Normal/Direct Invite) and RankedBreakoutDialog (finished 1v1 Ranked).
# Strictly hidden for bot matches (ClassicRank / bot_* / test_bot*), tutorials, spectators, and >2P matches.

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")
const GameRegistry = preload("res://scripts/games/game_registry.gd")
const KenneyUI = preload("res://scenes/ui/kenney_ui_helper.gd")

const SWITCHABLE_2P_GAMES: Array[String] = [
	GameTypes.CHESS,
	GameTypes.BACKGAMMON,
	GameTypes.CHECKERS,
	GameTypes.QUORIDOR,
	GameTypes.OTHELLO,
	GameTypes.FOURINROW,
	GameTypes.MILL,
	GameTypes.PENTAGO,
	GameTypes.YINSH,
	GameTypes.DOTBOX,
	GameTypes.TIC_TAC_TOE,
	GameTypes.BATTLESHIP,
	GameTypes.FEKRBEKR,
	GameTypes.YATZY,
	GameTypes.LUDO,
	GameTypes.UNO,
	GameTypes.COUP,
	GameTypes.MONOPOLY,
	GameTypes.RISK,
	GameTypes.QUIZ,
	GameTypes.RPC,
	GameTypes.BOXFOUR,
	GameTypes.MNUMBERS,
	GameTypes.MSWEEPER,
	GameTypes.SUDOKU,
]

# State
var _game_id: String = ""
var _current_game_type: String = ""
var _opponent_user_id: String = ""
var _opponent_username: String = "حریف"
var _opponent_image: int = 0
var _opponent_frame: int = 1
var _friend_status: String = "none" # "friends" | "outgoing_pending" | "incoming_pending" | "blocked" | "none"
var _incoming_request_id: String = ""
var _friend_request_busy: bool = false
var _opponent_left: bool = false
var _leave_notified: bool = false
var _is_configured_active: bool = false

# Live offer timer state
var _offer_mode: String = "" # "" | "waiting_rematch" | "incoming_rematch" | "waiting_switch" | "incoming_switch" | "notice"
var _offer_time_left: float = 0.0
var _offer_max_time: float = 15.0
var _offer_last_sec: int = -1
var _offer_from_name: String = ""
var _offer_target_game: String = ""

# Cached styles
var _sb_rival_card: StyleBoxFlat
var _sb_offer_waiting: StyleBoxFlat
var _sb_offer_incoming: StyleBoxFlat
var _sb_offer_notice: StyleBoxFlat
var _sb_picker_panel: StyleBoxFlat
var _sb_game_tile: StyleBoxFlat
var _sb_game_tile_hover: StyleBoxFlat
var _sb_arch_badge: StyleBoxFlat
var _sb_bar_bg: StyleBoxFlat
var _sb_bar_fill_gold: StyleBoxFlat
var _sb_bar_fill_emerald: StyleBoxFlat

# UI Nodes
var _rival_card: PanelContainer
var _opp_avatar_slot: Control
var _opp_avatar: TextureRect
var _lbl_opp_name: Label
var _arch_rival_badge: PanelContainer
var _lbl_rivalry_score: Label
var _btn_add_friend: Button

var _offer_banner: PanelContainer
var _lbl_offer_text: Label
var _offer_progress: ProgressBar
var _offer_btn_row: HBoxContainer
var _btn_offer_accept: Button
var _btn_offer_decline: Button

var _actions_row: HBoxContainer
var _btn_rematch: Button
var _btn_switch_game: Button

var _switch_picker_panel: PanelContainer
var _switch_grid: GridContainer
var _picker_built_for_game: String = ""


func _is_mobile() -> bool:
	return GameManager.is_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	visible = false
	set_process(false)
	_init_styles()
	_build_ui()
	_connect_network_signals()


func _exit_tree() -> void:
	_disconnect_network_signals()


func _init_styles() -> void:
	var mobile_mode: bool = _is_mobile()

	_sb_rival_card = StyleBoxFlat.new()
	_sb_rival_card.bg_color = Color(0.145, 0.092, 0.055, 0.96)
	_sb_rival_card.border_color = Color(0.84, 0.66, 0.28, 0.78)
	_sb_rival_card.border_width_left = 1
	_sb_rival_card.border_width_top = 2
	_sb_rival_card.border_width_right = 1
	_sb_rival_card.border_width_bottom = 2
	_sb_rival_card.set_corner_radius_all(14)
	_sb_rival_card.content_margin_left = 10.0
	_sb_rival_card.content_margin_right = 10.0
	_sb_rival_card.content_margin_top = 8.0
	_sb_rival_card.content_margin_bottom = 8.0
	if not mobile_mode:
		_sb_rival_card.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
		_sb_rival_card.shadow_size = 5
		_sb_rival_card.shadow_offset = Vector2(0, 2)

	_sb_offer_waiting = StyleBoxFlat.new()
	_sb_offer_waiting.bg_color = Color(0.17, 0.12, 0.05, 0.96)
	_sb_offer_waiting.border_color = Color(0.95, 0.78, 0.32, 0.88)
	_sb_offer_waiting.set_border_width_all(2)
	_sb_offer_waiting.set_corner_radius_all(14)
	_sb_offer_waiting.content_margin_left = 12.0
	_sb_offer_waiting.content_margin_right = 12.0
	_sb_offer_waiting.content_margin_top = 8.0
	_sb_offer_waiting.content_margin_bottom = 8.0

	_sb_offer_incoming = StyleBoxFlat.new()
	_sb_offer_incoming.bg_color = Color(0.10, 0.22, 0.14, 0.97)
	_sb_offer_incoming.border_color = Color(0.42, 0.95, 0.56, 0.96)
	_sb_offer_incoming.set_border_width_all(2)
	_sb_offer_incoming.set_corner_radius_all(14)
	_sb_offer_incoming.content_margin_left = 12.0
	_sb_offer_incoming.content_margin_right = 12.0
	_sb_offer_incoming.content_margin_top = 9.0
	_sb_offer_incoming.content_margin_bottom = 9.0
	if not mobile_mode:
		_sb_offer_incoming.shadow_color = Color(0.25, 0.88, 0.45, 0.28)
		_sb_offer_incoming.shadow_size = 8

	_sb_offer_notice = StyleBoxFlat.new()
	_sb_offer_notice.bg_color = Color(0.16, 0.11, 0.08, 0.92)
	_sb_offer_notice.border_color = Color(0.62, 0.48, 0.32, 0.68)
	_sb_offer_notice.set_border_width_all(1)
	_sb_offer_notice.set_corner_radius_all(12)
	_sb_offer_notice.content_margin_left = 10.0
	_sb_offer_notice.content_margin_right = 10.0
	_sb_offer_notice.content_margin_top = 6.0
	_sb_offer_notice.content_margin_bottom = 6.0

	_sb_picker_panel = StyleBoxFlat.new()
	_sb_picker_panel.bg_color = Color(0.11, 0.072, 0.044, 0.98)
	_sb_picker_panel.border_color = Color(0.84, 0.67, 0.30, 0.85)
	_sb_picker_panel.set_border_width_all(2)
	_sb_picker_panel.set_corner_radius_all(14)
	_sb_picker_panel.content_margin_left = 8.0
	_sb_picker_panel.content_margin_right = 8.0
	_sb_picker_panel.content_margin_top = 8.0
	_sb_picker_panel.content_margin_bottom = 8.0

	_sb_game_tile = StyleBoxFlat.new()
	_sb_game_tile.bg_color = Color(0.18, 0.115, 0.07, 0.95)
	_sb_game_tile.border_color = Color(0.58, 0.44, 0.24, 0.72)
	_sb_game_tile.set_border_width_all(1)
	_sb_game_tile.set_corner_radius_all(11)
	_sb_game_tile.content_margin_left = 6.0
	_sb_game_tile.content_margin_right = 6.0
	_sb_game_tile.content_margin_top = 6.0
	_sb_game_tile.content_margin_bottom = 6.0

	_sb_game_tile_hover = StyleBoxFlat.new()
	_sb_game_tile_hover.bg_color = Color(0.26, 0.17, 0.09, 0.98)
	_sb_game_tile_hover.border_color = Color(1.0, 0.84, 0.34, 0.96)
	_sb_game_tile_hover.set_border_width_all(2)
	_sb_game_tile_hover.set_corner_radius_all(11)
	_sb_game_tile_hover.content_margin_left = 6.0
	_sb_game_tile_hover.content_margin_right = 6.0
	_sb_game_tile_hover.content_margin_top = 6.0
	_sb_game_tile_hover.content_margin_bottom = 6.0

	_sb_arch_badge = StyleBoxFlat.new()
	_sb_arch_badge.bg_color = Color(0.32, 0.19, 0.04, 0.96)
	_sb_arch_badge.border_color = Color(1.0, 0.82, 0.28, 0.95)
	_sb_arch_badge.set_border_width_all(1)
	_sb_arch_badge.set_corner_radius_all(8)
	_sb_arch_badge.content_margin_left = 7.0
	_sb_arch_badge.content_margin_right = 7.0
	_sb_arch_badge.content_margin_top = 2.0
	_sb_arch_badge.content_margin_bottom = 2.0

	_sb_bar_bg = StyleBoxFlat.new()
	_sb_bar_bg.bg_color = Color(0.08, 0.05, 0.03, 0.90)
	_sb_bar_bg.set_corner_radius_all(4)

	_sb_bar_fill_gold = StyleBoxFlat.new()
	_sb_bar_fill_gold.bg_color = Color(0.96, 0.78, 0.28, 0.98)
	_sb_bar_fill_gold.set_corner_radius_all(4)

	_sb_bar_fill_emerald = StyleBoxFlat.new()
	_sb_bar_fill_emerald.bg_color = Color(0.34, 0.92, 0.52, 0.98)
	_sb_bar_fill_emerald.set_corner_radius_all(4)


func _build_ui() -> void:
	# 1. Compact Opponent & Head-to-Head Rival Card
	_rival_card = PanelContainer.new()
	_rival_card.name = "RivalCard"
	_rival_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rival_card.add_theme_stylebox_override("panel", _sb_rival_card)
	add_child(_rival_card)

	var rival_row := HBoxContainer.new()
	rival_row.add_theme_constant_override("separation", 10)
	rival_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rival_card.add_child(rival_row)

	# Left: One-Tap Add Friend button (DISABLED when already friends!)
	_btn_add_friend = Button.new()
	_btn_add_friend.name = "BtnAddFriend"
	_btn_add_friend.text = "+ افزودن دوست"
	_btn_add_friend.custom_minimum_size = Vector2(126, 42)
	_btn_add_friend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_add_friend.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_add_friend.add_theme_font_size_override("font_size", 17)
	_btn_add_friend.pressed.connect(_on_add_friend_pressed)
	rival_row.add_child(_btn_add_friend)

	# Center: Opponent name + Arch-Rival badge + Head-to-Head score
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 3)
	rival_row.add_child(info_col)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 6)
	info_col.add_child(name_row)

	_arch_rival_badge = PanelContainer.new()
	_arch_rival_badge.visible = false
	_arch_rival_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arch_rival_badge.add_theme_stylebox_override("panel", _sb_arch_badge)
	var arch_lbl := Label.new()
	arch_lbl.text = "🔥 رقیب دیرینه"
	arch_lbl.add_theme_font_override("font", FONT_VAZIR)
	arch_lbl.add_theme_font_size_override("font_size", 11)
	arch_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.48))
	_arch_rival_badge.add_child(arch_lbl)
	name_row.add_child(_arch_rival_badge)

	_lbl_opp_name = Label.new()
	_lbl_opp_name.text = "حریف"
	_lbl_opp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_opp_name.clip_text = true
	_lbl_opp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_opp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_opp_name.add_theme_font_override("font", FONT_HEKAYAT)
	_lbl_opp_name.add_theme_font_size_override("font_size", 19)
	_lbl_opp_name.add_theme_color_override("font_color", Color(0.99, 0.96, 0.90))
	name_row.add_child(_lbl_opp_name)

	_lbl_rivalry_score = Label.new()
	_lbl_rivalry_score.text = "⚔️ اولین تقابل شما"
	_lbl_rivalry_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_rivalry_score.clip_text = true
	_lbl_rivalry_score.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_rivalry_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_rivalry_score.add_theme_font_override("font", FONT_VAZIR)
	_lbl_rivalry_score.add_theme_font_size_override("font_size", 13)
	_lbl_rivalry_score.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	info_col.add_child(_lbl_rivalry_score)

	# Right: Framed Opponent Avatar
	_opp_avatar_slot = Control.new()
	_opp_avatar_slot.custom_minimum_size = Vector2(46, 46)
	_opp_avatar_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rival_row.add_child(_opp_avatar_slot)

	_opp_avatar = TextureRect.new()
	_opp_avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opp_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_opp_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_opp_avatar_slot.add_child(_opp_avatar)

	# 2. Live Interactive Rematch / Switch-Game Offer Banner
	_offer_banner = PanelContainer.new()
	_offer_banner.name = "OfferBanner"
	_offer_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_banner.visible = false
	add_child(_offer_banner)

	var offer_vbox := VBoxContainer.new()
	offer_vbox.add_theme_constant_override("separation", 6)
	_offer_banner.add_child(offer_vbox)

	_lbl_offer_text = Label.new()
	_lbl_offer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_offer_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_offer_text.add_theme_font_override("font", FONT_HEKAYAT)
	_lbl_offer_text.add_theme_font_size_override("font_size", 18)
	_lbl_offer_text.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	offer_vbox.add_child(_lbl_offer_text)

	_offer_progress = ProgressBar.new()
	_offer_progress.custom_minimum_size = Vector2(0, 7)
	_offer_progress.show_percentage = false
	_offer_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_progress.add_theme_stylebox_override("background", _sb_bar_bg)
	_offer_progress.add_theme_stylebox_override("fill", _sb_bar_fill_gold)
	offer_vbox.add_child(_offer_progress)

	_offer_btn_row = HBoxContainer.new()
	_offer_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_offer_btn_row.add_theme_constant_override("separation", 8)
	offer_vbox.add_child(_offer_btn_row)

	_btn_offer_decline = Button.new()
	_btn_offer_decline.text = "رد"
	_btn_offer_decline.custom_minimum_size = Vector2(104, 42)
	_btn_offer_decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_offer_decline.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_offer_decline.add_theme_font_size_override("font_size", 18)
	KenneyUI.style_button(_btn_offer_decline, KenneyUI.COLOR_RED)
	_btn_offer_decline.pressed.connect(_on_offer_decline_pressed)
	_offer_btn_row.add_child(_btn_offer_decline)

	_btn_offer_accept = Button.new()
	_btn_offer_accept.text = "قبول و شروع"
	_btn_offer_accept.custom_minimum_size = Vector2(150, 42)
	_btn_offer_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_offer_accept.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_offer_accept.add_theme_font_size_override("font_size", 19)
	KenneyUI.style_button(_btn_offer_accept, KenneyUI.COLOR_GREEN)
	_btn_offer_accept.pressed.connect(_on_offer_accept_pressed)
	_offer_btn_row.add_child(_btn_offer_accept)

	# 3. Primary Post-Match Action Row (Switch Game Together + Rematch)
	_actions_row = HBoxContainer.new()
	_actions_row.name = "PostMatchActionsRow"
	_actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_row.add_theme_constant_override("separation", 8)
	add_child(_actions_row)

	_btn_switch_game = Button.new()
	_btn_switch_game.name = "BtnSwitchGame"
	_btn_switch_game.text = "🎲 بازی دیگر با هم"
	_btn_switch_game.custom_minimum_size = Vector2(0, 50)
	_btn_switch_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_switch_game.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_switch_game.add_theme_font_size_override("font_size", 19)
	KenneyUI.style_button(_btn_switch_game, KenneyUI.COLOR_BLUE)
	_btn_switch_game.pressed.connect(_on_switch_game_toggle_pressed)
	_actions_row.add_child(_btn_switch_game)

	_btn_rematch = Button.new()
	_btn_rematch.name = "BtnRematch"
	_btn_rematch.text = "⚔️ بازی مجدد"
	_btn_rematch.custom_minimum_size = Vector2(0, 50)
	_btn_rematch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_rematch.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_rematch.add_theme_font_size_override("font_size", 20)
	KenneyUI.style_button(_btn_rematch, KenneyUI.COLOR_GREEN)
	_btn_rematch.pressed.connect(_on_rematch_pressed)
	_actions_row.add_child(_btn_rematch)

	# 4. Inline Compact 2-Player Game Switch Picker
	_switch_picker_panel = PanelContainer.new()
	_switch_picker_panel.name = "SwitchGamePickerPanel"
	_switch_picker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_switch_picker_panel.visible = false
	_switch_picker_panel.add_theme_stylebox_override("panel", _sb_picker_panel)
	add_child(_switch_picker_panel)

	var picker_vbox := VBoxContainer.new()
	picker_vbox.add_theme_constant_override("separation", 6)
	_switch_picker_panel.add_child(picker_vbox)

	var picker_hdr := HBoxContainer.new()
	picker_hdr.add_theme_constant_override("separation", 6)
	picker_vbox.add_child(picker_hdr)

	var btn_close_picker := Button.new()
	btn_close_picker.text = "بستن"
	btn_close_picker.custom_minimum_size = Vector2(64, 30)
	btn_close_picker.add_theme_font_override("font", FONT_VAZIR)
	btn_close_picker.add_theme_font_size_override("font_size", 12)
	KenneyUI.style_button(btn_close_picker, KenneyUI.COLOR_GREY)
	btn_close_picker.pressed.connect(func():
		AudioManager.sfx_tap()
		_switch_picker_panel.visible = false
	)
	picker_hdr.add_child(btn_close_picker)

	var picker_title := Label.new()
	picker_title.text = "بازی بعدی را انتخاب کنید:"
	picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	picker_title.add_theme_font_override("font", FONT_HEKAYAT)
	picker_title.add_theme_font_size_override("font_size", 17)
	picker_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	picker_hdr.add_child(picker_title)

	var picker_scroll := ScrollContainer.new()
	picker_scroll.custom_minimum_size = Vector2(0, 158)
	picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_vbox.add_child(picker_scroll)

	_switch_grid = GridContainer.new()
	_switch_grid.columns = 3
	_switch_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_switch_grid.add_theme_constant_override("h_separation", 6)
	_switch_grid.add_theme_constant_override("v_separation", 6)
	picker_scroll.add_child(_switch_grid)


func _connect_network_signals() -> void:
	if not NetworkManager.rematch_offered.is_connected(_on_rematch_offered):
		NetworkManager.rematch_offered.connect(_on_rematch_offered)
	if not NetworkManager.rematch_state_changed.is_connected(_on_rematch_state_changed):
		NetworkManager.rematch_state_changed.connect(_on_rematch_state_changed)
	if not NetworkManager.rematch_declined.is_connected(_on_rematch_declined):
		NetworkManager.rematch_declined.connect(_on_rematch_declined)
	if not NetworkManager.switch_game_offered.is_connected(_on_switch_game_offered):
		NetworkManager.switch_game_offered.connect(_on_switch_game_offered)
	if not NetworkManager.switch_game_state_changed.is_connected(_on_switch_game_state_changed):
		NetworkManager.switch_game_state_changed.connect(_on_switch_game_state_changed)
	if not NetworkManager.switch_game_declined.is_connected(_on_switch_game_declined):
		NetworkManager.switch_game_declined.connect(_on_switch_game_declined)


func _disconnect_network_signals() -> void:
	if NetworkManager.rematch_offered.is_connected(_on_rematch_offered):
		NetworkManager.rematch_offered.disconnect(_on_rematch_offered)
	if NetworkManager.rematch_state_changed.is_connected(_on_rematch_state_changed):
		NetworkManager.rematch_state_changed.disconnect(_on_rematch_state_changed)
	if NetworkManager.rematch_declined.is_connected(_on_rematch_declined):
		NetworkManager.rematch_declined.disconnect(_on_rematch_declined)
	if NetworkManager.switch_game_offered.is_connected(_on_switch_game_offered):
		NetworkManager.switch_game_offered.disconnect(_on_switch_game_offered)
	if NetworkManager.switch_game_state_changed.is_connected(_on_switch_game_state_changed):
		NetworkManager.switch_game_state_changed.disconnect(_on_switch_game_state_changed)
	if NetworkManager.switch_game_declined.is_connected(_on_switch_game_declined):
		NetworkManager.switch_game_declined.disconnect(_on_switch_game_declined)


func configure(post_match_data: Dictionary) -> bool:
	reset_and_hide()

	# Strict bot / tutorial / spectator / >2P exclusion
	if GameManager.is_bot_match() or GameManager.match_players.size() != 2:
		return false
	if post_match_data.is_empty():
		return false
	if bool(post_match_data.get("is_bot_match", false)) or not bool(post_match_data.get("eligible", false)):
		return false

	var opp_uid: String = str(post_match_data.get("opponent_user_id", "")).strip_edges()
	var my_uid: String = str(GameManager.get_user_id()).strip_edges()
	if opp_uid.is_empty() or opp_uid == my_uid or GameManager.is_bot_user_id(opp_uid):
		return false

	_game_id = str(post_match_data.get("game_id", GameManager.active_game_id)).strip_edges()
	_current_game_type = str(post_match_data.get("game_type", GameManager.current_game_type)).strip_edges()
	_opponent_user_id = opp_uid
	_opponent_username = str(post_match_data.get("opponent_username", "حریف")).strip_edges()
	if _opponent_username.is_empty():
		_opponent_username = "حریف"
	_opponent_image = int(post_match_data.get("opponent_image", 0))
	_opponent_frame = int(post_match_data.get("opponent_profile_frame", 1))
	_friend_status = str(post_match_data.get("friend_status", "none")).strip_edges()
	_incoming_request_id = str(post_match_data.get("incoming_request_id", "")).strip_edges()
	_friend_request_busy = false
	_opponent_left = false
	_leave_notified = false
	_is_configured_active = true

	_lbl_opp_name.text = _opponent_username
	_opp_avatar.texture = _load_avatar(_opponent_image)
	CafeSocialTheme.apply_frame_to_container(_opp_avatar_slot, _opp_avatar, _opponent_frame)

	_apply_rivalry_stats(
		int(post_match_data.get("my_wins", 0)),
		int(post_match_data.get("opp_wins", 0)),
		int(post_match_data.get("draws", 0)),
		int(post_match_data.get("total_matches", 0)),
		bool(post_match_data.get("is_arch_rival", false))
	)
	_apply_friend_button_state()
	_rebuild_switch_picker()
	_set_actions_enabled(not _game_id.is_empty())

	visible = true

	# Refresh rivalry/friend state in background if backend payload had minimal defaults
	if not post_match_data.has("friend_status") and NetworkManager.api != null:
		NetworkManager.api.get_rivalry(_opponent_user_id, _on_rivalry_api_loaded)
	return true


func _on_rivalry_api_loaded(success: bool, resp: Variant) -> void:
	if not _is_configured_active or not success or typeof(resp) != TYPE_DICTIONARY:
		return
	var res: Variant = resp.get("result", resp)
	if typeof(res) != TYPE_DICTIONARY:
		return
	var d: Dictionary = res as Dictionary
	if bool(d.get("is_bot", false)):
		reset_and_hide()
		return
	_friend_status = str(d.get("friend_status", _friend_status))
	_incoming_request_id = str(d.get("incoming_request_id", _incoming_request_id))
	_apply_rivalry_stats(
		int(d.get("my_wins", 0)),
		int(d.get("opp_wins", 0)),
		int(d.get("draws", 0)),
		int(d.get("total_matches", 0)),
		bool(d.get("is_arch_rival", false))
	)
	_apply_friend_button_state()


func _apply_rivalry_stats(my_wins: int, opp_wins: int, draws: int, total_matches: int, is_arch_rival: bool) -> void:
	if is_instance_valid(_arch_rival_badge):
		_arch_rival_badge.visible = is_arch_rival or (total_matches >= 5)
	if not is_instance_valid(_lbl_rivalry_score):
		return
	if total_matches <= 0:
		_lbl_rivalry_score.text = "⚔️ آمار تقابل: اولین بازی با هم"
	else:
		var base_txt: String = "⚔️ آمار با حریف: شما %s — %s حریف" % [
			GameManager.to_fa_num(my_wins),
			GameManager.to_fa_num(opp_wins)
		]
		if draws > 0:
			base_txt += " (%s مساوی)" % GameManager.to_fa_num(draws)
		_lbl_rivalry_score.text = base_txt


func _apply_friend_button_state() -> void:
	if not is_instance_valid(_btn_add_friend):
		return
	_btn_add_friend.visible = true
	_btn_add_friend.modulate = Color.WHITE

	match _friend_status:
		"friends":
			# User requirement: If opponent is already a friend, Add Friend button MUST be disabled.
			_btn_add_friend.text = "دوست هستید ✓"
			_btn_add_friend.disabled = true
			_btn_add_friend.focus_mode = Control.FOCUS_NONE
			KenneyUI.style_button(_btn_add_friend, KenneyUI.COLOR_GREY)
			_btn_add_friend.modulate = Color(0.82, 0.92, 0.84, 0.78)
		"outgoing_pending":
			_btn_add_friend.text = "درخواست ارسال شد"
			_btn_add_friend.disabled = true
			_btn_add_friend.focus_mode = Control.FOCUS_NONE
			KenneyUI.style_button(_btn_add_friend, KenneyUI.COLOR_GREY)
			_btn_add_friend.modulate = Color(0.88, 0.86, 0.80, 0.80)
		"incoming_pending":
			_btn_add_friend.text = "قبول دوستی ✓"
			_btn_add_friend.disabled = _friend_request_busy
			_btn_add_friend.focus_mode = Control.FOCUS_ALL
			KenneyUI.style_button(_btn_add_friend, KenneyUI.COLOR_GREEN)
		"blocked", "bot", "self":
			_btn_add_friend.visible = false
			_btn_add_friend.disabled = true
		_:
			_btn_add_friend.text = "+ افزودن دوست"
			_btn_add_friend.disabled = _friend_request_busy
			_btn_add_friend.focus_mode = Control.FOCUS_ALL
			KenneyUI.style_button(_btn_add_friend, KenneyUI.COLOR_YELLOW)


func _on_add_friend_pressed() -> void:
	if _friend_request_busy or _opponent_user_id.is_empty():
		return
	if _friend_status in ["friends", "outgoing_pending", "blocked", "bot", "self"]:
		return
	AudioManager.sfx_button()
	_friend_request_busy = true
	_btn_add_friend.disabled = true
	_btn_add_friend.text = "در حال ارسال..."

	if _friend_status == "incoming_pending" and not _incoming_request_id.is_empty():
		NetworkManager.api.respond_friend_request(_incoming_request_id, "accept", func(ok: bool, _resp: Variant):
			_friend_request_busy = false
			if ok:
				_friend_status = "friends"
				AudioManager.sfx_tap()
			_apply_friend_button_state()
		)
	else:
		NetworkManager.api.send_friend_request(_opponent_user_id, "", func(ok: bool, resp: Variant):
			_friend_request_busy = false
			if ok:
				var status_str: String = ""
				if typeof(resp) == TYPE_DICTIONARY:
					var res: Variant = resp.get("result", resp)
					if typeof(res) == TYPE_DICTIONARY:
						status_str = str(res.get("status", ""))
				_friend_status = "friends" if status_str == "accepted" else "outgoing_pending"
				AudioManager.sfx_tap()
			_apply_friend_button_state()
		)


func _rebuild_switch_picker() -> void:
	if not is_instance_valid(_switch_grid):
		return
	if _picker_built_for_game == _current_game_type and _switch_grid.get_child_count() > 0:
		return
	_picker_built_for_game = _current_game_type
	for ch in _switch_grid.get_children():
		ch.queue_free()

	var cur_low: String = _current_game_type.to_lower()
	for gt in SWITCHABLE_2P_GAMES:
		if gt.to_lower() == cur_low:
			continue
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(0, 68)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("normal", _sb_game_tile)
		tile.add_theme_stylebox_override("hover", _sb_game_tile_hover)
		tile.add_theme_stylebox_override("pressed", _sb_game_tile_hover)
		tile.add_theme_stylebox_override("focus", _sb_game_tile_hover)

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 3)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(vb)

		var thumb := TextureRect.new()
		thumb.texture = CafeSocialTheme.get_game_thumb(gt)
		thumb.custom_minimum_size = Vector2(34, 34)
		thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(thumb)

		var lbl := Label.new()
		lbl.text = GameRegistry.get_display_name_fa(gt)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_override("font", FONT_VAZIR)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)

		var picked_gt: String = gt
		tile.pressed.connect(func():
			_on_switch_game_selected(picked_gt)
		)
		_switch_grid.add_child(tile)


func _set_actions_enabled(enabled: bool) -> void:
	var can_use: bool = enabled and not _opponent_left and not _game_id.is_empty()
	if is_instance_valid(_btn_rematch):
		_btn_rematch.disabled = not can_use
		_btn_rematch.modulate = Color.WHITE if can_use else Color(0.65, 0.65, 0.65, 0.65)
	if is_instance_valid(_btn_switch_game):
		_btn_switch_game.disabled = not can_use
		_btn_switch_game.modulate = Color.WHITE if can_use else Color(0.65, 0.65, 0.65, 0.65)


func _on_rematch_pressed() -> void:
	if _opponent_left or _game_id.is_empty():
		return
	AudioManager.sfx_button()
	_switch_picker_panel.visible = false
	NetworkManager.send_rematch_request(_game_id)
	_enter_offer_state("waiting_rematch", 15.0, "", _current_game_type)


func _on_switch_game_toggle_pressed() -> void:
	if _opponent_left or _game_id.is_empty():
		return
	AudioManager.sfx_tap()
	_switch_picker_panel.visible = not _switch_picker_panel.visible


func _on_switch_game_selected(target_gt: String) -> void:
	if _opponent_left or _game_id.is_empty():
		return
	AudioManager.sfx_button()
	_switch_picker_panel.visible = false
	NetworkManager.send_switch_game_request(_game_id, target_gt, false)
	_enter_offer_state("waiting_switch", 20.0, "", target_gt)


func _on_offer_accept_pressed() -> void:
	if _game_id.is_empty():
		return
	AudioManager.sfx_button()
	if _offer_mode == "incoming_rematch":
		NetworkManager.send_rematch_respond(_game_id, "accept")
	elif _offer_mode == "incoming_switch":
		NetworkManager.send_switch_game_respond(_game_id, "accept")
	_btn_offer_accept.disabled = true
	_btn_offer_decline.disabled = true
	_lbl_offer_text.text = "✨ در حال آماده‌سازی میز مسابقه..."


func _on_offer_decline_pressed() -> void:
	if _game_id.is_empty():
		return
	AudioManager.sfx_tap()
	if _offer_mode == "waiting_rematch":
		NetworkManager.send_rematch_respond(_game_id, "cancel")
	elif _offer_mode == "incoming_rematch":
		NetworkManager.send_rematch_respond(_game_id, "decline")
	elif _offer_mode == "waiting_switch":
		NetworkManager.send_switch_game_respond(_game_id, "cancel")
	elif _offer_mode == "incoming_switch":
		NetworkManager.send_switch_game_respond(_game_id, "decline")
	_clear_offer_banner()


func _matches_session(payload: Dictionary) -> bool:
	if not _is_configured_active or not visible:
		return false
	var gid: String = str(payload.get("game_id", "")).strip_edges()
	return gid.is_empty() or _game_id.is_empty() or gid == _game_id


func _on_rematch_offered(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	var from_name: String = str(payload.get("from_username", _opponent_username))
	var t_sec: float = float(max(3, int(payload.get("timeout", 15))))
	AudioManager.play_sound("bell")
	_switch_picker_panel.visible = false
	_enter_offer_state("incoming_rematch", t_sec, from_name, str(payload.get("game_type", _current_game_type)))


func _on_rematch_state_changed(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	if str(payload.get("status", "")) == "waiting":
		var t_sec: float = float(max(1, int(payload.get("timeout", 15))))
		_enter_offer_state("waiting_rematch", t_sec, "", str(payload.get("game_type", _current_game_type)))


func _on_rematch_declined(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	_handle_offer_closed(payload)


func _on_switch_game_offered(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	var from_name: String = str(payload.get("from_username", _opponent_username))
	var target_gt: String = str(payload.get("target_game_type", ""))
	var t_sec: float = float(max(3, int(payload.get("timeout", 20))))
	AudioManager.play_sound("bell")
	_switch_picker_panel.visible = false
	_enter_offer_state("incoming_switch", t_sec, from_name, target_gt)


func _on_switch_game_state_changed(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	if str(payload.get("status", "")) == "waiting":
		var t_sec: float = float(max(1, int(payload.get("timeout", 20))))
		_enter_offer_state("waiting_switch", t_sec, "", str(payload.get("target_game_type", "")))


func _on_switch_game_declined(payload: Dictionary) -> void:
	if not _matches_session(payload):
		return
	_handle_offer_closed(payload)


func _handle_offer_closed(payload: Dictionary) -> void:
	var reason: String = str(payload.get("reason", ""))
	var msg: String = str(payload.get("message", "")).strip_edges()
	if reason == "opponent_left":
		_opponent_left = true
		_switch_picker_panel.visible = false
		_set_actions_enabled(false)
		if msg.is_empty():
			msg = "حریف صفحه پایان مسابقه را ترک کرد."
		_show_notice(msg)
		return
	if reason == "cancelled" and str(payload.get("by_user_id", "")) == str(GameManager.get_user_id()):
		_clear_offer_banner()
		return
	if msg.is_empty():
		if reason == "timeout":
			msg = "زمان پاسخ به درخواست به پایان رسید."
		else:
			msg = "درخواست پذیرفته نشد."
	_show_notice(msg)


func _enter_offer_state(mode: String, timeout_sec: float, from_name: String, target_gt: String) -> void:
	_offer_mode = mode
	_offer_max_time = maxf(1.0, timeout_sec)
	_offer_time_left = _offer_max_time
	_offer_last_sec = -1
	_offer_from_name = from_name if not from_name.is_empty() else _opponent_username
	_offer_target_game = target_gt

	_offer_banner.visible = true
	_offer_progress.visible = true
	_offer_progress.max_value = _offer_max_time
	_offer_progress.value = _offer_time_left
	_offer_btn_row.visible = true
	_btn_offer_accept.disabled = false
	_btn_offer_decline.disabled = false

	if mode == "waiting_rematch" or mode == "waiting_switch":
		_offer_banner.add_theme_stylebox_override("panel", _sb_offer_waiting)
		_offer_progress.add_theme_stylebox_override("fill", _sb_bar_fill_gold)
		_btn_offer_accept.visible = false
		_btn_offer_decline.visible = true
		_btn_offer_decline.text = "لغو درخواست"
		_actions_row.visible = false
	else:
		_offer_banner.add_theme_stylebox_override("panel", _sb_offer_incoming)
		_offer_progress.add_theme_stylebox_override("fill", _sb_bar_fill_emerald)
		_btn_offer_accept.visible = true
		_btn_offer_accept.text = "قبول و شروع"
		_btn_offer_decline.visible = true
		_btn_offer_decline.text = "رد"
		_actions_row.visible = false

	_refresh_offer_label()
	set_process(true)


func _show_notice(text: String) -> void:
	_offer_mode = "notice"
	set_process(false)
	_offer_banner.visible = true
	_offer_banner.add_theme_stylebox_override("panel", _sb_offer_notice)
	_lbl_offer_text.text = text
	_offer_progress.visible = false
	_offer_btn_row.visible = false
	_actions_row.visible = not _opponent_left
	_set_actions_enabled(not _opponent_left)


func _clear_offer_banner() -> void:
	_offer_mode = ""
	set_process(false)
	if is_instance_valid(_offer_banner):
		_offer_banner.visible = false
	if is_instance_valid(_actions_row):
		_actions_row.visible = not _opponent_left
	_set_actions_enabled(not _opponent_left)


func _refresh_offer_label() -> void:
	var sec_str: String = GameManager.to_fa_num(maxi(0, int(ceil(_offer_time_left))))
	var gt_fa: String = GameRegistry.get_display_name_fa(_offer_target_game) if not _offer_target_game.is_empty() else ""
	match _offer_mode:
		"waiting_rematch":
			_lbl_offer_text.text = "⏳ در انتظار تایید حریف برای بازی مجدد... (%s ثانیه)" % sec_str
		"waiting_switch":
			_lbl_offer_text.text = "⏳ در انتظار تایید حریف برای بازی «%s»... (%s ثانیه)" % [gt_fa, sec_str]
		"incoming_rematch":
			_lbl_offer_text.text = "⚔️ %s درخواست بازی مجدد داد! (%s ثانیه)" % [_offer_from_name, sec_str]
		"incoming_switch":
			_lbl_offer_text.text = "🎲 %s پیشنهاد بازی «%s» را داد! (%s ثانیه)" % [_offer_from_name, gt_fa, sec_str]


func _process(delta: float) -> void:
	if not visible or _offer_mode.is_empty() or _offer_mode == "notice":
		set_process(false)
		return
	_offer_time_left = maxf(0.0, _offer_time_left - delta)
	if is_instance_valid(_offer_progress):
		_offer_progress.value = _offer_time_left
	var sec_int: int = int(ceil(_offer_time_left))
	if sec_int != _offer_last_sec:
		_offer_last_sec = sec_int
		_refresh_offer_label()
	if _offer_time_left <= 0.0:
		set_process(false)
		_show_notice("زمان پاسخ به درخواست به پایان رسید.")


func notify_leave_if_active() -> void:
	if _is_configured_active and not _leave_notified and not _game_id.is_empty():
		_leave_notified = true
		NetworkManager.send_post_match_leave(_game_id)


func reset_and_hide() -> void:
	_is_configured_active = false
	_offer_mode = ""
	_offer_time_left = 0.0
	_opponent_left = false
	_friend_request_busy = false
	set_process(false)
	visible = false
	if is_instance_valid(_offer_banner):
		_offer_banner.visible = false
	if is_instance_valid(_switch_picker_panel):
		_switch_picker_panel.visible = false
	if is_instance_valid(_actions_row):
		_actions_row.visible = true


func _load_avatar(avatar_id: int) -> Texture2D:
	var path: String = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(path):
		return load(path)
	var fallback: String = "res://assets/icons/Avatars/0.png"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null
