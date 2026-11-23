extends PanelContainer

# Lobby Dialog Controller
# Mirrors Flutter's LobbyListBox & JoinedLobbyWidget:
# 1. Shows live list of active lobbies from server with 1-click join
# 2. Allows creating a new room with game type selection, capacity & privacy settings
# 3. Allows direct 6-char code joining
# 4. In-room ready status & match start coordination

signal closed()
signal match_ready(game_id: String, game_type: String)

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

# Top Bar
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var btn_refresh: TextureButton = $Margin/VBox/TopRow/BtnRefresh
@onready var lbl_status: Label = $Margin/VBox/LblStatus

# View 1: Active Lobbies List
@onready var view_list: VBoxContainer = $Margin/VBox/ViewList
@onready var scroll_list: ScrollContainer = $Margin/VBox/ViewList/ScrollList
@onready var btn_show_create: Button = $Margin/VBox/ViewList/ActionsRow/BtnShowCreate
@onready var btn_show_join_code: Button = $Margin/VBox/ViewList/ActionsRow/BtnShowJoinCode
@onready var lobbies_container: VBoxContainer = $Margin/VBox/ViewList/ScrollList/LobbiesContainer
@onready var lbl_no_lobbies: Label = $Margin/VBox/ViewList/LblNoLobbies

# View 2: Create Lobby
@onready var view_create: VBoxContainer = $Margin/VBox/ViewCreate
@onready var create_scroll: ScrollContainer = $Margin/VBox/ViewCreate/CreateScroll
@onready var create_form_vbox: VBoxContainer = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox
@onready var btn_select_game: Button = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/BtnSelectGame
@onready var lbl_selected_game: Label = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/BtnSelectGame/Margin/HBox/VBoxGameInfo/LblSelectedGame
@onready var lbl_selected_game_meta: Label = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/BtnSelectGame/Margin/HBox/VBoxGameInfo/LblSelectedGameMeta
@onready var selected_game_icon: TextureRect = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/BtnSelectGame/Margin/HBox/IconFrame/SelectedGameIcon
@onready var btn_quick_name: Button = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/RoomSettingsCard/SettingsVBox/NameLabelRow/BtnQuickName
@onready var input_room_name: LineEdit = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/RoomSettingsCard/SettingsVBox/InputRoomName
@onready var privacy_badge: PanelContainer = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/RoomSettingsCard/SettingsVBox/PwdLabelRow/PrivacyBadge
@onready var lbl_privacy_badge: Label = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/RoomSettingsCard/SettingsVBox/PwdLabelRow/PrivacyBadge/LblPrivacyBadge
@onready var input_room_password: LineEdit = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/RoomSettingsCard/SettingsVBox/InputRoomPassword
@onready var lbl_create_hint: Label = $Margin/VBox/ViewCreate/CreateScroll/CreateFormVBox/LblCreateHint
@onready var btn_create_confirm: Button = $Margin/VBox/ViewCreate/CreateButtonsRow/BtnCreateConfirm
@onready var btn_create_cancel: Button = $Margin/VBox/ViewCreate/CreateButtonsRow/BtnCreateCancel

# Game Select Modal
@onready var game_select_modal: Control = $GameSelectModal
@onready var game_select_panel: PanelContainer = $GameSelectModal/Panel
@onready var btn_close_game_select: TextureButton = $GameSelectModal/Panel/ModalMargin/VBox/TopRow/BtnCloseGameSelect
@onready var scroll_games: ScrollContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames
@onready var game_grid: GridContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames/GameGrid
@onready var backdrop_game_select: ColorRect = $GameSelectModal/Backdrop

var selected_create_game_type: String = GameTypes.TIC_TAC_TOE
var selected_create_player_count: int = 2
var player_count_container: PanelContainer = null
var _player_count_buttons: Dictionary = {}

# View 3: Join by Code
@onready var view_join_code: VBoxContainer = $Margin/VBox/ViewJoinCode
@onready var input_join_code: LineEdit = $Margin/VBox/ViewJoinCode/JoinCodeCard/JoinVBox/InputJoinCode
@onready var btn_join_confirm: Button = $Margin/VBox/ViewJoinCode/JoinButtonsRow/BtnJoinConfirm
@onready var btn_join_cancel: Button = $Margin/VBox/ViewJoinCode/JoinButtonsRow/BtnJoinCancel

# View 4: Inside Lobby
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var view_inside: VBoxContainer = $Margin/VBox/ViewInside
@onready var lbl_room_id: Label = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HeaderVBox/CodePill/HBoxCode/LblRoomId
@onready var btn_copy_code: Button = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HeaderVBox/CodePill/HBoxCode/BtnCopyCode
@onready var lbl_game_name: Label = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HeaderVBox/GameRow/VBoxGameInfo/LblGameName
@onready var inside_game_icon: TextureRect = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HeaderVBox/GameRow/IconFrame/InsideGameIcon
@onready var players_scroll: ScrollContainer = $Margin/VBox/ViewInside/PlayersScroll
@onready var players_list: VBoxContainer = $Margin/VBox/ViewInside/PlayersScroll/PlayersList
@onready var btn_ready: Button = $Margin/VBox/ViewInside/InsideButtonsRow/BtnReady
@onready var btn_start: Button = $Margin/VBox/ViewInside/InsideButtonsRow/BtnStart
@onready var btn_leave_lobby: Button = $Margin/VBox/ViewInside/InsideButtonsRow/BtnLeaveLobby

var active_lobby_id: String = ""
var active_lobby_creator_id: String = ""
var is_host: bool = false
var is_ready: bool = false
var current_lobby_queuers: Array = []
var active_lobbies_data: Array = []
var active_lobby_game_type: String = GameTypes.TIC_TAC_TOE
var active_lobby_max_players: int = 2
var _lobbies_loaded_once: bool = false

# Game types
var available_games: Array[String] = [
	GameTypes.TIC_TAC_TOE,
	GameTypes.CHESS,
	GameTypes.BACKGAMMON,
	GameTypes.CHECKERS,
	GameTypes.FOURINROW,
	GameTypes.OTHELLO,
	GameTypes.MILL,
	GameTypes.DOTBOX,
	GameTypes.PENTAGO,
	GameTypes.YINSH,
	GameTypes.QUORIDOR,
	GameTypes.YATZY,
	GameTypes.LUDO,
	GameTypes.RISK,
	GameTypes.UNO,
	GameTypes.COUP,
	GameTypes.MONOPOLY,
	GameTypes.QUIZ,
	GameTypes.BATTLESHIP,
	GameTypes.FEKRBEKR,
	GameTypes.RPC,
	GameTypes.SUDOKU,
	GameTypes.BOXFOUR,
	GameTypes.MNUMBERS,
	GameTypes.MSWEEPER
]

const MULTI_PLAYER_GAMES: Array[String] = [
	GameTypes.LUDO,
	GameTypes.RISK,
	GameTypes.UNO,
	GameTypes.QUIZ,
	GameTypes.COUP,
	GameTypes.MONOPOLY
]

func _is_mobile() -> bool:
	return GameManager.is_mobile

func _ready() -> void:
	CafeSocialTheme.style_parlor_tab_button(btn_show_create, true, 22, false, 24.0, 12.0)
	btn_show_create.custom_minimum_size = Vector2(0, 58)
	CafeSocialTheme.style_parlor_tab_button(btn_show_join_code, false, 22, false, 24.0, 12.0)
	btn_show_join_code.custom_minimum_size = Vector2(0, 58)
	KenneyUI.style_button(btn_create_confirm, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_create_cancel, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_join_confirm, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_join_cancel, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_ready, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_leave_lobby, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_copy_code, KenneyUI.COLOR_BLUE)

	ActionVFXManager.apply_button_juice(btn_select_game, "tap_button")
	ActionVFXManager.apply_button_juice(btn_quick_name, "tap_button")
	ActionVFXManager.apply_button_juice(btn_copy_code, "tap_button")
	ActionVFXManager.apply_button_juice(btn_show_create, "tap_button")
	ActionVFXManager.apply_button_juice(btn_show_join_code, "tap_button")
	ActionVFXManager.apply_button_juice(btn_create_confirm, "tap_button")
	ActionVFXManager.apply_button_juice(btn_create_cancel, "tap_button")
	ActionVFXManager.apply_button_juice(btn_join_confirm, "tap_button")
	ActionVFXManager.apply_button_juice(btn_join_cancel, "tap_button")
	ActionVFXManager.apply_button_juice(btn_ready, "tap_button")
	ActionVFXManager.apply_button_juice(btn_start, "tap_button")
	ActionVFXManager.apply_button_juice(btn_leave_lobby, "tap_button")

	input_room_name.text_changed.connect(_on_room_name_changed)
	input_room_password.text_changed.connect(_on_room_password_changed)
	btn_quick_name.pressed.connect(_on_quick_name_pressed)
	_on_room_name_changed(input_room_name.text)
	_on_room_password_changed(input_room_password.text)

	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)

	btn_refresh.pressed.connect(func():
		AudioManager.sfx_tap()
		_request_lobbies()
	)

	btn_show_create.pressed.connect(func():
		AudioManager.sfx_button()
		_switch_view(view_create)
	)

	btn_show_join_code.pressed.connect(func():
		AudioManager.sfx_button()
		_switch_view(view_join_code)
	)

	btn_create_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		_switch_view(view_list)
	)

	btn_join_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		_switch_view(view_list)
	)

	btn_create_confirm.pressed.connect(_on_create_pressed)
	btn_join_confirm.pressed.connect(_on_join_pressed)
	btn_ready.pressed.connect(_on_ready_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	btn_leave_lobby.pressed.connect(_on_leave_lobby_pressed)

	btn_copy_code.pressed.connect(func():
		AudioManager.sfx_tap()
		if active_lobby_id != "":
			DisplayServer.clipboard_set(active_lobby_id)
			btn_copy_code.text = "کپی شد"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(btn_copy_code):
					btn_copy_code.text = "کپی کد"
			)
	)

	btn_select_game.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_game_select_modal()
	)

	btn_close_game_select.pressed.connect(func():
		AudioManager.sfx_tap()
		_close_game_select_modal()
	)

	backdrop_game_select.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			_close_game_select_modal()
	)

	_build_player_count_selector()
	_update_selected_game_display()
	_setup_scroll_container_touch_drag(scroll_games)
	_setup_scroll_container_touch_drag(scroll_list)
	_setup_scroll_container_touch_drag(players_scroll)
	_setup_scroll_container_touch_drag(create_scroll)

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	active_lobby_id = ""
	active_lobby_creator_id = ""
	is_host = false
	is_ready = false
	_lobbies_loaded_once = false
	current_lobby_queuers.clear()
	active_lobbies_data.clear()
	_switch_view(view_list)
	_update_lobbies_list()

	if not NetworkManager.socket.event_received.is_connected(_on_lobby_event):
		NetworkManager.socket.event_received.connect(_on_lobby_event)
	if not NetworkManager.socket.namespace_connected.is_connected(_on_lobby_namespace_connected):
		NetworkManager.socket.namespace_connected.connect(_on_lobby_namespace_connected)
	NetworkManager.socket.connect_namespace("/lobby", {"token": GameManager.token})

	if NetworkManager.socket.connected_namespaces.has("/lobby"):
		_request_lobbies()

func _on_lobby_namespace_connected(ns: String) -> void:
	if ns == "/lobby" and visible:
		_request_lobbies()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		if active_lobby_id != "":
			_on_leave_lobby_pressed()
		NetworkManager.socket.disconnect_namespace("/lobby")
		if NetworkManager.socket.event_received.is_connected(_on_lobby_event):
			NetworkManager.socket.event_received.disconnect(_on_lobby_event)
		if NetworkManager.socket.namespace_connected.is_connected(_on_lobby_namespace_connected):
			NetworkManager.socket.namespace_connected.disconnect(_on_lobby_namespace_connected)
		closed.emit()
	)

func close_immediate() -> void:
	visible = false
	if active_lobby_id != "":
		_on_leave_lobby_pressed()
	NetworkManager.socket.disconnect_namespace("/lobby")
	if NetworkManager.socket.event_received.is_connected(_on_lobby_event):
		NetworkManager.socket.event_received.disconnect(_on_lobby_event)
	if NetworkManager.socket.namespace_connected.is_connected(_on_lobby_namespace_connected):
		NetworkManager.socket.namespace_connected.disconnect(_on_lobby_namespace_connected)
	closed.emit()

func _switch_view(target_view: Control) -> void:
	view_list.visible = (target_view == view_list)
	view_create.visible = (target_view == view_create)
	view_join_code.visible = (target_view == view_join_code)
	view_inside.visible = (target_view == view_inside)
	if is_instance_valid(game_select_modal):
		game_select_modal.visible = false
	lbl_status.text = ""
	lbl_status.modulate = Color.WHITE

	if target_view == view_inside:
		lbl_title.text = "اتاق انتظار مسابقه"
		btn_refresh.visible = false
	elif target_view == view_create:
		lbl_title.text = "ساخت اتاق جدید"
		btn_refresh.visible = false
		_update_selected_game_display()
		_on_room_name_changed(input_room_name.text)
		_on_room_password_changed(input_room_password.text)
	elif target_view == view_join_code:
		lbl_title.text = "ورود با شناسه ۶ رقمی"
		btn_refresh.visible = false
	else:
		lbl_title.text = "اتاق‌های بازی آنلاین (لابی)"
		btn_refresh.visible = true

func _on_quick_name_pressed() -> void:
	AudioManager.sfx_tap()
	var uname: String = str(GameManager.user_data.get("name", GameManager.user_data.get("username", ""))).strip_edges()
	if uname.is_empty():
		input_room_name.text = "اتاق دوستانه کافه"
	else:
		input_room_name.text = ("اتاق %s" % uname).substr(0, 28)
	_on_room_name_changed(input_room_name.text)

func _on_room_name_changed(new_text: String) -> void:
	var is_valid: bool = not new_text.strip_edges().is_empty()
	btn_create_confirm.disabled = not is_valid
	if is_valid:
		btn_create_confirm.modulate = Color.WHITE
		if is_instance_valid(lbl_create_hint):
			lbl_create_hint.text = "اتاق آماده ساخت است — روی «ایجاد اتاق» بزنید."
			lbl_create_hint.add_theme_color_override("font_color", Color(0.55, 0.94, 0.66, 0.96))
	else:
		btn_create_confirm.modulate = Color(0.65, 0.65, 0.65, 0.55)
		if is_instance_valid(lbl_create_hint):
			lbl_create_hint.text = "برای فعال شدن دکمه ایجاد، یک نام برای اتاق وارد کنید."
			lbl_create_hint.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42, 0.92))

func _on_room_password_changed(new_text: String) -> void:
	if not is_instance_valid(privacy_badge) or not is_instance_valid(lbl_privacy_badge):
		return
	var has_pwd: bool = not new_text.strip_edges().is_empty()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	if has_pwd:
		sb.bg_color = Color(0.30, 0.21, 0.08, 0.95)
		sb.border_color = Color(0.96, 0.78, 0.30, 0.9)
		lbl_privacy_badge.text = "خصوصی — دارای رمز"
		lbl_privacy_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44, 1.0))
	else:
		sb.bg_color = Color(0.10, 0.26, 0.16, 0.92)
		sb.border_color = Color(0.36, 0.80, 0.50, 0.85)
		lbl_privacy_badge.text = "عمومی — ورود آزاد"
		lbl_privacy_badge.add_theme_color_override("font_color", Color(0.55, 0.95, 0.68, 1.0))
	privacy_badge.add_theme_stylebox_override("panel", sb)

func _build_player_count_selector() -> void:
	if not is_instance_valid(create_form_vbox) or is_instance_valid(player_count_container):
		return
	player_count_container = PanelContainer.new()
	player_count_container.name = "PlayerCountSelector"
	player_count_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.09, 0.05, 0.95)
	sb.border_color = Color(0.64, 0.49, 0.26, 0.78)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	player_count_container.add_theme_stylebox_override("panel", sb)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_count_container.add_child(vbox)

	var hdr_row: HBoxContainer = HBoxContainer.new()
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hdr_row)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "قابل تغییر تا قبل از ساخت"
	sub_lbl.add_theme_font_override("font", FONT_VAZIR)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.76, 0.68, 0.56, 0.9))
	hdr_row.add_child(sub_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.text = "ظرفیت اتاق (تعداد بازیکنان)"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hdr_row.add_child(title_lbl)

	var btns_row: HBoxContainer = HBoxContainer.new()
	btns_row.add_theme_constant_override("separation", 10)
	btns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btns_row)

	var labels: Dictionary = {2: "۲ نفره", 3: "۳ نفره", 4: "۴ نفره"}
	for cnt in [2, 3, 4]:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = str(labels[cnt])
		btn.add_theme_font_override("font", FONT_HEKAYAT)
		btn.add_theme_font_size_override("font_size", 21)
		var chosen_cnt: int = cnt
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_create_player_count = chosen_cnt
			_refresh_player_count_buttons()
		)
		btns_row.add_child(btn)
		_player_count_buttons[cnt] = btn

	create_form_vbox.add_child(player_count_container)
	var btn_idx: int = btn_select_game.get_index()
	create_form_vbox.move_child(player_count_container, btn_idx + 1)
	_refresh_player_count_buttons()

func _refresh_player_count_buttons() -> void:
	for cnt in _player_count_buttons.keys():
		var btn: Button = _player_count_buttons[cnt] as Button
		if not is_instance_valid(btn):
			continue
		var is_sel: bool = (int(cnt) == selected_create_player_count)
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = Color(0.16, 0.44, 0.22, 0.98) if is_sel else Color(0.10, 0.06, 0.04, 0.92)
		st.border_color = Color(0.98, 0.84, 0.34, 1.0) if is_sel else Color(0.52, 0.40, 0.24, 0.72)
		st.set_border_width_all(2 if is_sel else 1)
		st.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)
		btn.add_theme_stylebox_override("pressed", st)
		btn.add_theme_stylebox_override("focus", st)
		btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86) if is_sel else Color(0.84, 0.76, 0.64))

func _update_selected_game_display() -> void:
	if not is_instance_valid(lbl_selected_game) or not is_instance_valid(selected_game_icon):
		return
	lbl_selected_game.text = GameTypes.get_display_name_fa(selected_create_game_type)
	selected_game_icon.texture = _get_game_texture(selected_create_game_type)

	var is_multi: bool = (selected_create_game_type in MULTI_PLAYER_GAMES)
	if is_instance_valid(lbl_selected_game_meta):
		var diff_fa: String = GameRegistry.get_difficulty_name_fa(selected_create_game_type)
		var cap_fa: String = "۲ تا ۴ نفره" if is_multi else "۲ نفره"
		lbl_selected_game_meta.text = "%s  •  سطح %s" % [cap_fa, diff_fa]

	if is_instance_valid(player_count_container):
		player_count_container.visible = is_multi
		if not is_multi:
			selected_create_player_count = 2
		_refresh_player_count_buttons()

var _game_cards: Dictionary = {}
var _cached_game_textures: Dictionary = {}

func _get_game_texture(g_type: String) -> Texture2D:
	if _cached_game_textures.has(g_type):
		return _cached_game_textures[g_type] as Texture2D
	var icon_path: String = "res://assets/images/games/%s.png" % g_type.to_lower()
	if not ResourceLoader.exists(icon_path):
		icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path)
	if not tex:
		for ext in ["png", "jpg"]:
			var raw_path: String = ProjectSettings.globalize_path("res://assets/images/games/%s.%s" % [g_type.to_lower(), ext])
			if FileAccess.file_exists(raw_path):
				var img: Image = Image.load_from_file(raw_path)
				if img and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
					break
	if not tex:
		tex = load("res://assets/icons/General/lobby.png")
	_cached_game_textures[g_type] = tex
	return tex

func _open_game_select_modal() -> void:
	game_select_modal.top_level = true
	game_select_modal.z_index = 40
	game_select_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_select_modal.visible = true
	if _game_cards.is_empty():
		_populate_game_grid()
	else:
		_update_game_grid_selection()

	var p_size: Vector2 = game_select_panel.size
	if p_size == Vector2.ZERO:
		p_size = Vector2(660, 1100)
	game_select_panel.pivot_offset = p_size / 2.0
	game_select_panel.scale = Vector2(0.94, 0.94)
	game_select_panel.modulate.a = 0.0

	var tw: Tween = game_select_panel.create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(game_select_panel, "modulate:a", 1.0, 0.15)
	call_deferred("_on_game_grid_scroll_resized")

func _close_game_select_modal() -> void:
	var tw: Tween = game_select_panel.create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2(0.94, 0.94), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(game_select_panel, "modulate:a", 0.0, 0.14)
	tw.finished.connect(func():
		if is_instance_valid(game_select_modal):
			game_select_modal.visible = false
	)

func _update_game_grid_selection() -> void:
	for g in _game_cards:
		var card: Button = _game_cards[g] as Button
		if is_instance_valid(card):
			var is_selected: bool = (str(g) == selected_create_game_type)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0.98, 0.84, 0.25, 0.12) if is_selected else Color(0, 0, 0, 0)
			sb.set_corner_radius_all(16)
			sb.set_border_width_all(3 if is_selected else 0)
			sb.border_color = Color(1.0, 0.90, 0.35, 1.0)
			sb.shadow_color = Color(1.0, 0.85, 0.20, 0.45)
			sb.shadow_size = (6 if is_selected else 0) if not _is_mobile() else 0
			card.add_theme_stylebox_override("normal", sb)

			var badge: Control = card.get_node_or_null("SelectionBadge") as Control
			if is_instance_valid(badge):
				if is_selected and not badge.visible:
					badge.visible = true
					badge.scale = Vector2(0.5, 0.5)
					var tw: Tween = badge.create_tween()
					tw.tween_property(badge, "scale", Vector2(1.18, 1.18), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tw.tween_property(badge, "scale", Vector2.ONE, 0.08)
				elif not is_selected:
					badge.visible = false
			if is_selected:
				var tw_c: Tween = card.create_tween()
				tw_c.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08)
				tw_c.tween_property(card, "scale", Vector2.ONE, 0.10)

func _calculate_game_card_height() -> float:
	var total_w: float = 560.0
	if is_instance_valid(scroll_games) and scroll_games.size.x > 100.0:
		total_w = scroll_games.size.x - 14.0
	elif is_instance_valid(game_grid) and game_grid.size.x > 100.0:
		total_w = game_grid.size.x
	var cell_w: float = floor((total_w - 12.0) / 2.0)
	return maxf(160.0, cell_w)

func _populate_game_grid() -> void:
	game_grid.columns = 2
	for child in game_grid.get_children():
		child.queue_free()
	_game_cards.clear()

	var initial_h: float = _calculate_game_card_height()
	for g in available_games:
		var card: Control = _create_game_card(g, initial_h)
		game_grid.add_child(card)
		_game_cards[g] = card

	if not scroll_games.resized.is_connected(_on_game_grid_scroll_resized):
		scroll_games.resized.connect(_on_game_grid_scroll_resized)

func _on_game_grid_scroll_resized() -> void:
	var h: float = _calculate_game_card_height()
	for card_val in _game_cards.values():
		var card: Control = card_val as Control
		if is_instance_valid(card):
			card.custom_minimum_size = Vector2(0, h)
			card.pivot_offset = Vector2(card.size.x / 2.0, h / 2.0)

func _create_game_card(g_type: String, initial_h: float = 260.0) -> Control:
	var is_selected: bool = (g_type == selected_create_game_type)

	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(0, initial_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.pivot_offset = Vector2(initial_h / 2.0, initial_h / 2.0)

	card.item_rect_changed.connect(func():
		var w: float = card.size.x
		if w > 80.0:
			var target_h: float = floor(w)
			if absf(card.custom_minimum_size.y - target_h) > 2.0:
				card.set_deferred("custom_minimum_size", Vector2(0, target_h))
				card.pivot_offset = Vector2(w / 2.0, target_h / 2.0)
	)

	var style_normal: StyleBoxFlat = StyleBoxFlat.new()
	style_normal.bg_color = Color(0, 0, 0, 0)
	style_normal.set_corner_radius_all(16)
	style_normal.set_border_width_all(3 if is_selected else 0)
	style_normal.border_color = Color(1.0, 0.90, 0.35, 1.0)
	style_normal.shadow_size = 0

	var style_hover: StyleBoxFlat = StyleBoxFlat.new()
	style_hover.bg_color = Color(0, 0, 0, 0)
	style_hover.set_corner_radius_all(16)
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(1.0, 0.94, 0.55, 0.9)
	style_hover.shadow_size = 0

	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)

	var img: TextureRect = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.12, 1.08, 1.02)
	img.texture = _get_game_texture(g_type)
	card.add_child(img)

	var sel_badge: PanelContainer = PanelContainer.new()
	sel_badge.name = "SelectionBadge"
	sel_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sel_badge.offset_left = -40.0
	sel_badge.offset_top = 8.0
	sel_badge.offset_right = -10.0
	sel_badge.offset_bottom = 38.0
	sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.pivot_offset = Vector2(15.0, 15.0)
	var badge_sb: StyleBoxFlat = StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.98, 0.82, 0.25, 0.98)
	badge_sb.border_color = Color(0.18, 0.12, 0.04, 0.95)
	badge_sb.set_border_width_all(2)
	badge_sb.set_corner_radius_all(15)
	badge_sb.shadow_color = Color(0, 0, 0, 0.40)
	badge_sb.shadow_size = 0 if _is_mobile() else 3
	sel_badge.add_theme_stylebox_override("panel", badge_sb)
	sel_badge.visible = is_selected

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "✓"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	badge_lbl.add_theme_font_size_override("font_size", 20)
	badge_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02, 1.0))
	sel_badge.add_child(badge_lbl)
	card.add_child(sel_badge)

	var banner: PanelContainer = PanelContainer.new()
	banner.anchor_top = 0.74
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = 4.0
	banner.offset_right = -4.0
	banner.offset_bottom = -4.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(g_type, 36.0, 4.0))

	var lbl: Label = Label.new()
	lbl.text = GameTypes.get_display_name_fa(g_type)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_override("font", FONT_HEKAYAT)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)

	var mode_pill: PanelContainer = PanelContainer.new()
	mode_pill.position = Vector2(10, 10)
	mode_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(0.12, 0.08, 0.04, 0.90)
	p_style.set_border_width_all(1)
	p_style.border_color = Color(0.84, 0.67, 0.32, 0.85)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 8.0
	p_style.content_margin_right = 8.0
	p_style.content_margin_top = 3.0
	p_style.content_margin_bottom = 3.0
	mode_pill.add_theme_stylebox_override("panel", p_style)
	var mode_lbl: Label = Label.new()
	mode_lbl.text = "۲ تا ۴ نفره" if (g_type in MULTI_PLAYER_GAMES) else "۲ نفره"
	mode_lbl.add_theme_font_override("font", FONT_VAZIR)
	mode_lbl.add_theme_font_size_override("font_size", 13)
	mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	mode_pill.add_child(mode_lbl)
	card.add_child(mode_pill)

	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var drag_state: Dictionary = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_games.scroll_vertical
			else:
				var was_dragging: bool = bool(drag_state["dragging"])
				var was_active: bool = bool(drag_state["active"])
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_release: float = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_release <= 14.0:
						AudioManager.sfx_button()
						selected_create_game_type = g_type
						_update_selected_game_display()
						_close_game_select_modal()
		elif event is InputEventMouseMotion and bool(drag_state["active"]):
			var dy: float = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or bool(drag_state["dragging"]):
				drag_state["dragging"] = true
				scroll_games.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)

	return card

func _setup_scroll_container_touch_drag(sc: ScrollContainer) -> void:
	if not sc:
		return
	var sb: VScrollBar = sc.get_v_scroll_bar()
	if sb:
		sb.custom_minimum_size = Vector2(12, 0)
	var state: Dictionary = {"down": false, "start_y": 0.0, "start_scroll": 0}
	sc.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				state["down"] = true
				state["start_y"] = get_viewport().get_mouse_position().y
				state["start_scroll"] = sc.scroll_vertical
			else:
				state["down"] = false
		elif event is InputEventMouseMotion and bool(state["down"]):
			var delta_y: float = get_viewport().get_mouse_position().y - float(state["start_y"])
			sc.scroll_vertical = max(0, int(state["start_scroll"]) - int(delta_y))
	)

func _request_lobbies() -> void:
	lbl_status.text = "در حال بروزرسانی لیست اتاق‌ها..."
	lbl_status.modulate = Color.WHITE
	var payload: Dictionary = {
		"id": Commands.Lobby_Request_Data,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _update_lobbies_list() -> void:
	for child in lobbies_container.get_children():
		child.queue_free()

	if active_lobbies_data.is_empty():
		lbl_no_lobbies.visible = _lobbies_loaded_once
		lbl_no_lobbies.text = "در حال حاضر اتاق فعالی وجود ندارد.\nمی‌توانید یک اتاق جدید بسازید یا با شناسه ۶ رقمی وارد شوید."
		return

	lbl_no_lobbies.visible = false
	for lobby_val in active_lobbies_data:
		if typeof(lobby_val) == TYPE_DICTIONARY:
			var row: PanelContainer = _create_lobby_row(lobby_val as Dictionary)
			lobbies_container.add_child(row)

func _create_lobby_row(lobby: Dictionary) -> PanelContainer:
	var lobby_id: String = str(lobby.get("lobby_id", ""))
	var lobby_name: String = str(lobby.get("lobby_name", "اتاق بازی"))
	var game_type: String = str(lobby.get("game_type", GameTypes.TIC_TAC_TOE))
	var q_arr: Array = lobby.get("queuers", []) if typeof(lobby.get("queuers")) == TYPE_ARRAY else []
	var q_len: int = int(lobby.get("queuers_length", q_arr.size()))
	var max_count: int = max(2, int(lobby.get("lobby_count", 2)))
	var has_pwd: bool = bool(lobby.get("has_password", false))
	var is_full: bool = q_len >= max_count

	var row_panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.10, 0.06, 0.96)
	style.border_color = Color(0.72, 0.56, 0.28, 0.85) if not is_full else Color(0.45, 0.36, 0.24, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 0 if _is_mobile() else 4
	style.shadow_offset = Vector2(0, 2)
	row_panel.add_theme_stylebox_override("panel", style)
	row_panel.custom_minimum_size = Vector2(0, 96)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row_panel.add_child(hbox)

	# Join CTA
	var btn_join: Button = Button.new()
	btn_join.text = "تکمیل" if is_full else "ورود"
	btn_join.disabled = is_full
	btn_join.custom_minimum_size = Vector2(88, 50)
	btn_join.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_join.add_theme_font_override("font", FONT_HEKAYAT)
	btn_join.add_theme_font_size_override("font_size", 20)
	KenneyUI.style_button(btn_join, KenneyUI.COLOR_GREY if is_full else KenneyUI.COLOR_GREEN)
	btn_join.pressed.connect(func():
		AudioManager.sfx_button()
		if has_pwd:
			_prompt_lobby_password(lobby_id)
		else:
			_join_lobby_by_id(lobby_id)
	)
	hbox.add_child(btn_join)

	# Capacity pill
	var cap_pill: PanelContainer = PanelContainer.new()
	cap_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cap_sb: StyleBoxFlat = StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.11, 0.07, 0.04, 0.94)
	cap_sb.border_color = Color(0.84, 0.67, 0.32, 0.78)
	cap_sb.set_border_width_all(1)
	cap_sb.set_corner_radius_all(10)
	cap_sb.content_margin_left = 9.0
	cap_sb.content_margin_right = 9.0
	cap_sb.content_margin_top = 4.0
	cap_sb.content_margin_bottom = 4.0
	cap_pill.add_theme_stylebox_override("panel", cap_sb)

	var count_lbl: Label = Label.new()
	count_lbl.text = "%s / %s" % [GameManager.to_fa_num(q_len), GameManager.to_fa_num(max_count)]
	count_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	count_lbl.add_theme_font_size_override("font_size", 19)
	cap_pill.add_child(count_lbl)
	hbox.add_child(cap_pill)

	# Room & Game Info
	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 3)

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 6)
	text_col.add_child(name_row)

	if has_pwd:
		var lock_pill: PanelContainer = CafeSocialTheme.make_badge_pill(
			"خصوصی",
			Color(1.0, 0.86, 0.42),
			Color(0.28, 0.19, 0.06, 0.95),
			Color(0.92, 0.74, 0.28, 0.85),
			13
		)
		name_row.add_child(lock_pill)

	var name_lbl: Label = Label.new()
	name_lbl.text = lobby_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(name_lbl)

	var game_lbl: Label = Label.new()
	game_lbl.text = GameTypes.get_display_name_fa(game_type)
	game_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_lbl.clip_text = true
	game_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	game_lbl.add_theme_font_override("font", FONT_VAZIR)
	game_lbl.add_theme_color_override("font_color", Color(0.84, 0.76, 0.62))
	game_lbl.add_theme_font_size_override("font_size", 15)
	game_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(game_lbl)

	hbox.add_child(text_col)

	# Framed Game Icon Thumbnail
	var icon_frame: PanelContainer = PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(64, 64)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var if_sb: StyleBoxFlat = StyleBoxFlat.new()
	if_sb.bg_color = Color(0.08, 0.05, 0.03, 1.0)
	if_sb.border_color = Color(0.80, 0.62, 0.28, 0.82)
	if_sb.set_border_width_all(1)
	if_sb.set_corner_radius_all(12)
	if_sb.content_margin_left = 3.0
	if_sb.content_margin_right = 3.0
	if_sb.content_margin_top = 3.0
	if_sb.content_margin_bottom = 3.0
	icon_frame.add_theme_stylebox_override("panel", if_sb)

	var icon_plate: TextureRect = TextureRect.new()
	icon_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_plate.texture = _get_game_texture(game_type)
	icon_frame.add_child(icon_plate)
	hbox.add_child(icon_frame)

	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row_state: Dictionary = {"down": false, "start_y": 0.0, "start_scroll": 0}
	row_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				row_state["down"] = true
				row_state["start_y"] = get_viewport().get_mouse_position().y
				row_state["start_scroll"] = scroll_list.scroll_vertical
			else:
				row_state["down"] = false
		elif event is InputEventMouseMotion and bool(row_state["down"]):
			var delta_y: float = get_viewport().get_mouse_position().y - float(row_state["start_y"])
			scroll_list.scroll_vertical = max(0, int(row_state["start_scroll"]) - int(delta_y))
	)
	return row_panel

var _password_modal: Control = null
var _target_lobby_id_for_pwd: String = ""

func _prompt_lobby_password(lobby_id: String) -> void:
	_target_lobby_id_for_pwd = lobby_id
	if not _password_modal or not is_instance_valid(_password_modal):
		_build_password_modal()

	var input_pwd: LineEdit = _password_modal.find_child("InputLobbyPassword", true, false) as LineEdit
	if is_instance_valid(input_pwd):
		input_pwd.text = ""
	_password_modal.visible = true
	var panel: Control = _password_modal.find_child("Panel", true, false) as Control
	if panel:
		ActionVFXManager.animate_dialog_open(panel, _password_modal, true)

func _build_password_modal() -> void:
	_password_modal = Control.new()
	_password_modal.name = "PasswordModal"
	_password_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_password_modal.z_index = 85

	var bd: ColorRect = ColorRect.new()
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	bd.color = Color(0.04, 0.02, 0.01, 0.85)
	bd.mouse_filter = Control.MOUSE_FILTER_STOP
	_password_modal.add_child(bd)

	var outer_m: MarginContainer = MarginContainer.new()
	outer_m.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_m.add_theme_constant_override("margin_left", 24)
	outer_m.add_theme_constant_override("margin_right", 24)
	outer_m.add_theme_constant_override("margin_top", 24)
	outer_m.add_theme_constant_override("margin_bottom", 24)
	_password_modal.add_child(outer_m)

	var vcenter: VBoxContainer = VBoxContainer.new()
	vcenter.alignment = BoxContainer.ALIGNMENT_CENTER
	vcenter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vcenter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_m.add_child(vcenter)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.86, 0.68, 0.30, 0.94)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 0 if _is_mobile() else 14
	sb.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", sb)
	vcenter.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "ورود به اتاق خصوصی"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FONT_HEKAYAT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_outline_size", 2)
	vbox.add_child(title)

	var desc: Label = Label.new()
	desc.text = "برای ورود به این اتاق، رمز عبور آن را وارد کنید:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_override("font", FONT_VAZIR)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	vbox.add_child(desc)

	var input_pwd: LineEdit = LineEdit.new()
	input_pwd.name = "InputLobbyPassword"
	input_pwd.custom_minimum_size = Vector2(0, 58)
	input_pwd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_pwd.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_pwd.placeholder_text = "رمز عبور اتاق..."
	input_pwd.max_length = 20
	input_pwd.add_theme_font_override("font", FONT_HEKAYAT)
	input_pwd.add_theme_font_size_override("font_size", 22)
	input_pwd.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	var in_st: StyleBoxFlat = StyleBoxFlat.new()
	in_st.bg_color = Color(0.08, 0.05, 0.03, 0.96)
	in_st.border_color = Color(0.60, 0.46, 0.26, 0.88)
	in_st.set_border_width_all(2)
	in_st.set_corner_radius_all(14)
	in_st.content_margin_left = 14.0
	in_st.content_margin_right = 14.0
	var in_focus: StyleBoxFlat = in_st.duplicate() as StyleBoxFlat
	in_focus.border_color = Color(0.98, 0.82, 0.34, 1.0)
	input_pwd.add_theme_stylebox_override("normal", in_st)
	input_pwd.add_theme_stylebox_override("focus", in_focus)
	vbox.add_child(input_pwd)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var btn_ok: Button = Button.new()
	btn_ok.text = "ورود"
	btn_ok.custom_minimum_size = Vector2(0, 56)
	btn_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ok.add_theme_font_override("font", FONT_HEKAYAT)
	btn_ok.add_theme_font_size_override("font_size", 22)
	KenneyUI.style_button(btn_ok, KenneyUI.COLOR_GREEN)
	btn_row.add_child(btn_ok)

	var btn_cancel: Button = Button.new()
	btn_cancel.text = "انصراف"
	btn_cancel.custom_minimum_size = Vector2(0, 56)
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.add_theme_font_override("font", FONT_HEKAYAT)
	btn_cancel.add_theme_font_size_override("font_size", 22)
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_GREY)
	btn_row.add_child(btn_cancel)

	btn_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		_password_modal.visible = false
	)

	btn_ok.pressed.connect(func():
		var pwd: String = input_pwd.text.strip_edges()
		AudioManager.sfx_button()
		_password_modal.visible = false
		_join_lobby_by_id(_target_lobby_id_for_pwd, pwd)
	)

	add_child(_password_modal)

func _join_lobby_by_id(lobby_id: String, password: String = "") -> void:
	if lobby_id.is_empty():
		return
	lbl_status.text = "در حال پیوستن به اتاق %s..." % lobby_id
	lbl_status.modulate = Color.WHITE
	var payload: Dictionary = {
		"id": Commands.Lobby_Join,
		"data": {
			"lobby_id": lobby_id,
			"lobby_password": password,
			"password": password
		}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_create_pressed() -> void:
	var r_name: String = input_room_name.text.strip_edges()
	if r_name.is_empty():
		return
	AudioManager.sfx_button()
	var g_type: String = selected_create_game_type
	var r_pwd: String = input_room_password.text.strip_edges() if is_instance_valid(input_room_password) else ""

	lbl_status.text = "در حال ساخت اتاق..."
	lbl_status.modulate = Color.WHITE
	var l_count: int = selected_create_player_count if (g_type in MULTI_PLAYER_GAMES) else 2
	var payload: Dictionary = {
		"id": Commands.Lobby_Create,
		"data": {
			"game_type": g_type,
			"lobby_name": r_name,
			"lobby_password": r_pwd,
			"password": r_pwd,
			"lobby_count": l_count
		}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_join_pressed() -> void:
	AudioManager.sfx_button()
	var code: String = input_join_code.text.strip_edges().to_upper()
	if code.is_empty():
		lbl_status.text = "لطفاً شناسه ۶ رقمی اتاق را وارد کنید."
		lbl_status.modulate = Color(1.0, 0.55, 0.45)
		return
	_join_lobby_by_id(code)

func _show_inside_view(lobby_data: Dictionary) -> void:
	_switch_view(view_inside)
	active_lobby_id = str(lobby_data.get("lobby_id", ""))
	active_lobby_creator_id = str(lobby_data.get("creator_id", ""))
	lbl_room_id.text = "کد اتاق: " + active_lobby_id

	active_lobby_game_type = str(lobby_data.get("game_type", GameTypes.TIC_TAC_TOE))
	active_lobby_max_players = max(2, int(lobby_data.get("lobby_count", 2)))
	if active_lobby_max_players > 2:
		lbl_game_name.text = "%s (%s نفره)" % [GameTypes.get_display_name_fa(active_lobby_game_type), GameManager.to_fa_num(active_lobby_max_players)]
	else:
		lbl_game_name.text = GameTypes.get_display_name_fa(active_lobby_game_type)

	if is_instance_valid(inside_game_icon):
		inside_game_icon.texture = _get_game_texture(active_lobby_game_type)

	is_host = (active_lobby_creator_id == GameManager.get_user_id())
	btn_start.visible = is_host
	btn_ready.visible = not is_host

	var q_list: Array = lobby_data.get("queuers", []) if typeof(lobby_data.get("queuers")) == TYPE_ARRAY else []
	_update_players_list(q_list)

func _update_players_list(queuers: Array) -> void:
	current_lobby_queuers = queuers
	for child in players_list.get_children():
		child.queue_free()

	var all_guests_ready: bool = true

	for q_val in queuers:
		if typeof(q_val) != TYPE_DICTIONARY:
			continue
		var q: Dictionary = q_val as Dictionary
		var q_uid: String = str(q.get("user_id", ""))
		var is_this_creator: bool = (q_uid == active_lobby_creator_id) if active_lobby_creator_id != "" else (q_val == queuers[0])
		var rdy: bool = bool(q.get("is_rdy", false))

		if not is_this_creator and not rdy:
			all_guests_ready = false

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 92)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_style: StyleBoxFlat = StyleBoxFlat.new()
		c_style.bg_color = Color(0.18, 0.11, 0.07, 0.96)
		c_style.set_corner_radius_all(16)
		c_style.set_border_width_all(2)
		if is_this_creator:
			c_style.border_color = Color(0.96, 0.80, 0.30, 0.95)
			c_style.shadow_color = Color(1.0, 0.8, 0.2, 0.16)
		elif rdy:
			c_style.border_color = Color(0.35, 0.88, 0.48, 0.90)
			c_style.shadow_color = Color(0.2, 0.8, 0.3, 0.16)
		else:
			c_style.border_color = Color(0.62, 0.49, 0.32, 0.72)
			c_style.shadow_color = Color(0, 0, 0, 0.30)
		c_style.shadow_size = 0 if _is_mobile() else 4
		c_style.shadow_offset = Vector2(0, 2)
		c_style.content_margin_left = 12.0
		c_style.content_margin_right = 12.0
		c_style.content_margin_top = 8.0
		c_style.content_margin_bottom = 8.0
		card.add_theme_stylebox_override("panel", c_style)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# Host Kick button
		if is_host and not is_this_creator:
			var btn_kick: Button = Button.new()
			btn_kick.text = "اخراج"
			btn_kick.custom_minimum_size = Vector2(78, 46)
			btn_kick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn_kick.add_theme_font_override("font", FONT_HEKAYAT)
			btn_kick.add_theme_font_size_override("font_size", 18)
			KenneyUI.style_button(btn_kick, KenneyUI.COLOR_RED)
			btn_kick.pressed.connect(func():
				_kick_player(q_uid)
			)
			hbox.add_child(btn_kick)

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_col.alignment = BoxContainer.ALIGNMENT_CENTER
		info_col.add_theme_constant_override("separation", 4)

		var name_lbl: Label = Label.new()
		name_lbl.text = str(q.get("name", q.get("username", "بازیکن")))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_override("font", FONT_HEKAYAT)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_lbl.add_theme_constant_override("shadow_outline_size", 2)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_col.add_child(name_lbl)

		var badge_panel: PanelContainer = PanelContainer.new()
		badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		var badge_style: StyleBoxFlat = StyleBoxFlat.new()
		badge_style.set_corner_radius_all(10)
		badge_style.content_margin_left = 10.0
		badge_style.content_margin_right = 10.0
		badge_style.content_margin_top = 3.0
		badge_style.content_margin_bottom = 3.0
		badge_style.set_border_width_all(1)

		var rdy_lbl: Label = Label.new()
		rdy_lbl.add_theme_font_override("font", FONT_VAZIR)
		rdy_lbl.add_theme_font_size_override("font_size", 14)

		if is_this_creator:
			badge_style.bg_color = Color(0.32, 0.23, 0.07, 0.95)
			badge_style.border_color = Color(0.96, 0.80, 0.28, 0.95)
			rdy_lbl.text = "میزبان اتاق"
			rdy_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		elif rdy:
			badge_style.bg_color = Color(0.09, 0.30, 0.15, 0.95)
			badge_style.border_color = Color(0.36, 0.88, 0.50, 0.95)
			rdy_lbl.text = "آماده مسابقه ✓"
			rdy_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.68))
		else:
			badge_style.bg_color = Color(0.20, 0.15, 0.10, 0.92)
			badge_style.border_color = Color(0.65, 0.55, 0.40, 0.65)
			rdy_lbl.text = "در حال آماده‌سازی"
			rdy_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))

		badge_panel.add_theme_stylebox_override("panel", badge_style)
		badge_panel.add_child(rdy_lbl)
		info_col.add_child(badge_panel)
		hbox.add_child(info_col)

		# Right side: Avatar
		var av_frame: PanelContainer = PanelContainer.new()
		av_frame.custom_minimum_size = Vector2(64, 64)
		av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var av_style: StyleBoxFlat = StyleBoxFlat.new()
		av_style.bg_color = Color(0.14, 0.09, 0.05, 0.95)
		av_style.set_corner_radius_all(14)
		av_style.set_border_width_all(2)
		av_style.border_color = Color(0.96, 0.80, 0.30, 0.9) if is_this_creator else Color(0.76, 0.62, 0.38, 0.78)
		av_frame.add_theme_stylebox_override("panel", av_style)

		var avatar: TextureRect = TextureRect.new()
		avatar.custom_minimum_size = Vector2(56, 56)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var img_id: int = int(q.get("image", 0))
		var q_fid: int = GameManager.get_player_frame_id(q)
		var av_path: String = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(av_path):
			avatar.texture = load(av_path)
		else:
			avatar.texture = load("res://assets/icons/Avatars/0.png")
		av_frame.add_child(avatar)
		CafeSocialTheme.apply_frame_to_container(av_frame, avatar, q_fid)
		hbox.add_child(av_frame)

		card.add_child(hbox)
		players_list.add_child(card)

		if q_uid == GameManager.get_user_id() and not is_host:
			is_ready = rdy
			if is_ready:
				btn_ready.text = "آماده هستید ✓"
				btn_ready.disabled = true
				KenneyUI.style_button(btn_ready, KenneyUI.COLOR_YELLOW)
			else:
				btn_ready.text = "اعلام آمادگی"
				btn_ready.disabled = false
				KenneyUI.style_button(btn_ready, KenneyUI.COLOR_GREEN)

	# Empty slot cards for remaining player seats
	var seat_names: Array[String] = ["اول", "دوم", "سوم", "چهارم"]
	for slot_idx in range(queuers.size(), active_lobby_max_players):
		var empty_card: PanelContainer = PanelContainer.new()
		empty_card.custom_minimum_size = Vector2(0, 82)
		empty_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var emp_style: StyleBoxFlat = StyleBoxFlat.new()
		emp_style.bg_color = Color(0.14, 0.09, 0.06, 0.62)
		emp_style.set_corner_radius_all(16)
		emp_style.set_border_width_all(1)
		emp_style.border_color = Color(0.75, 0.60, 0.34, 0.58)
		emp_style.content_margin_left = 12.0
		emp_style.content_margin_right = 12.0
		emp_style.content_margin_top = 8.0
		emp_style.content_margin_bottom = 8.0
		empty_card.add_theme_stylebox_override("panel", emp_style)

		var pulse_tw: Tween = empty_card.create_tween().set_loops()
		pulse_tw.tween_property(empty_card, "modulate:a", 0.45, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(empty_card, "modulate:a", 0.95, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		var ehbox: HBoxContainer = HBoxContainer.new()
		ehbox.add_theme_constant_override("separation", 10)
		ehbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var emp_badge: PanelContainer = CafeSocialTheme.make_badge_pill(
			"در انتظار",
			Color(1.0, 0.88, 0.52),
			Color(0.22, 0.15, 0.07, 0.88),
			Color(0.76, 0.60, 0.30, 0.65),
			14
		)
		emp_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ehbox.add_child(emp_badge)

		var evbox: VBoxContainer = VBoxContainer.new()
		evbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		evbox.add_theme_constant_override("separation", 2)
		evbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var seat_word: String = seat_names[clampi(slot_idx, 0, seat_names.size() - 1)]
		var elbl1: Label = Label.new()
		elbl1.text = "در انتظار پیوستن بازیکن %s..." % seat_word
		elbl1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elbl1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elbl1.add_theme_font_override("font", FONT_HEKAYAT)
		elbl1.add_theme_font_size_override("font_size", 21)
		elbl1.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58, 0.95))
		elbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		evbox.add_child(elbl1)

		var elbl2: Label = Label.new()
		elbl2.text = "کد ۶ رقمی اتاق را برای دوستانتان بفرستید"
		elbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elbl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elbl2.add_theme_font_override("font", FONT_VAZIR)
		elbl2.add_theme_font_size_override("font_size", 14)
		elbl2.add_theme_color_override("font_color", Color(0.84, 0.77, 0.66, 0.82))
		elbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		evbox.add_child(elbl2)
		ehbox.add_child(evbox)

		empty_card.add_child(ehbox)
		players_list.add_child(empty_card)

	if is_host:
		if queuers.size() < active_lobby_max_players:
			btn_start.disabled = true
			if active_lobby_max_players > 2:
				btn_start.text = "تکمیل ظرفیت (%s/%s)..." % [GameManager.to_fa_num(queuers.size()), GameManager.to_fa_num(active_lobby_max_players)]
			else:
				btn_start.text = "در انتظار بازیکن دوم..."
			btn_start.modulate = Color.WHITE
			KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREY)
			btn_start.add_theme_color_override("font_disabled_color", Color(0.88, 0.82, 0.72, 0.85))
		elif not all_guests_ready:
			btn_start.disabled = true
			btn_start.text = "در انتظار آمادگی بازیکنان..." if active_lobby_max_players > 2 else "در انتظار آمادگی حریف..."
			btn_start.modulate = Color.WHITE
			KenneyUI.style_button(btn_start, KenneyUI.COLOR_YELLOW)
			btn_start.add_theme_color_override("font_disabled_color", Color(0.2, 0.15, 0.05, 0.95))
		else:
			btn_start.disabled = false
			btn_start.text = "شروع مسابقه"
			btn_start.modulate = Color.WHITE
			KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREEN)
			btn_start.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _mark_player_ready(user_id: String) -> void:
	for i in range(current_lobby_queuers.size()):
		var q: Variant = current_lobby_queuers[i]
		if typeof(q) == TYPE_DICTIONARY and str((q as Dictionary).get("user_id", "")) == user_id:
			(q as Dictionary)["is_rdy"] = true
			current_lobby_queuers[i] = q
			break
	_update_players_list(current_lobby_queuers)

func _on_ready_pressed() -> void:
	AudioManager.sfx_tap()
	if is_ready:
		return
	is_ready = true
	btn_ready.text = "آماده هستید ✓"
	btn_ready.disabled = true
	KenneyUI.style_button(btn_ready, KenneyUI.COLOR_YELLOW)

	var payload: Dictionary = {
		"id": Commands.Lobby_Player_Ready,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_start_pressed() -> void:
	AudioManager.sfx_button()
	lbl_status.text = "در حال راه‌اندازی مسابقه..."
	lbl_status.modulate = Color.WHITE
	var payload: Dictionary = {
		"id": Commands.Lobby_Start_Game,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_leave_lobby_pressed() -> void:
	AudioManager.sfx_button()
	if active_lobby_id != "":
		var cmd: String = Commands.Lobby_Delete if is_host else Commands.Lobby_Quit
		var payload: Dictionary = {"id": cmd, "data": {}}
		NetworkManager.socket.emit_event("/lobby", "user_command", payload)
		active_lobby_id = ""
	_switch_view(view_list)
	_request_lobbies()

func _on_lobby_event(ns: String, event_name: String, data: Variant) -> void:
	if ns != "/lobby" or event_name != "command" or typeof(data) != TYPE_DICTIONARY:
		return

	var d: Dictionary = data as Dictionary
	var cmd_id: String = str(d.get("id", ""))
	var payload: Variant = d.get("data", {})

	match cmd_id:
		Commands.Lobby_List:
			lbl_status.text = ""
			_lobbies_loaded_once = true
			if typeof(payload) == TYPE_ARRAY:
				active_lobbies_data = payload as Array
				_update_lobbies_list()

		Commands.Lobby_Created:
			if typeof(payload) == TYPE_DICTIONARY:
				var p_dict: Dictionary = payload as Dictionary
				var found: bool = false
				for i in range(active_lobbies_data.size()):
					if typeof(active_lobbies_data[i]) == TYPE_DICTIONARY and str((active_lobbies_data[i] as Dictionary).get("lobby_id", "")) == str(p_dict.get("lobby_id", "")):
						found = true
						break
				if not found:
					active_lobbies_data.append(p_dict)
					_update_lobbies_list()

		Commands.Lobby_Data:
			if typeof(payload) == TYPE_DICTIONARY:
				_show_inside_view(payload as Dictionary)

		Commands.Lobby_Players_Update:
			if typeof(payload) == TYPE_DICTIONARY:
				var p_dict: Dictionary = payload as Dictionary
				if p_dict.has("queuers") and typeof(p_dict["queuers"]) == TYPE_ARRAY:
					_update_players_list(p_dict["queuers"] as Array)
				elif p_dict.has("lobby_id"):
					var l_id: String = str(p_dict.get("lobby_id", ""))
					var count: int = int(p_dict.get("count", 0))
					for i in range(active_lobbies_data.size() - 1, -1, -1):
						if typeof(active_lobbies_data[i]) == TYPE_DICTIONARY and str((active_lobbies_data[i] as Dictionary).get("lobby_id", "")) == l_id:
							if count == 0:
								active_lobbies_data.remove_at(i)
							else:
								(active_lobbies_data[i] as Dictionary)["queuers_length"] = count
							break
					_update_lobbies_list()

		Commands.Lobby_Player_Ready:
			if typeof(payload) == TYPE_DICTIONARY:
				var rdy_uid: String = str((payload as Dictionary).get("user_id", ""))
				_mark_player_ready(rdy_uid)

		Commands.Lobby_Deleted:
			var del_id: String = str((payload as Dictionary).get("lobby_id", "")) if typeof(payload) == TYPE_DICTIONARY else ""
			for i in range(active_lobbies_data.size() - 1, -1, -1):
				if typeof(active_lobbies_data[i]) == TYPE_DICTIONARY and str((active_lobbies_data[i] as Dictionary).get("lobby_id", "")) == del_id:
					active_lobbies_data.remove_at(i)
					break
			_update_lobbies_list()
			if active_lobby_id == del_id:
				active_lobby_id = ""
				_switch_view(view_list)

		Commands.Lobby_Full:
			lbl_status.text = "این اتاق پر شده است!"
			lbl_status.modulate = Color(1.0, 0.48, 0.45)

		Commands.Lobby_Not_Exists:
			lbl_status.text = "اتاق مورد نظر یافت نشد!"
			lbl_status.modulate = Color(1.0, 0.48, 0.45)

		Commands.Lobby_Wrong_Password:
			lbl_status.text = "رمز عبور اتاق اشتباه است!"
			lbl_status.modulate = Color(1.0, 0.48, 0.45)
			var wrong_id: String = str((payload as Dictionary).get("lobby_id", "")) if typeof(payload) == TYPE_DICTIONARY else ""
			if not wrong_id.is_empty():
				_prompt_lobby_password(wrong_id)

		Commands.Lobby_Kick:
			active_lobby_id = ""
			_switch_view(view_list)
			lbl_status.text = "شما توسط میزبان از اتاق اخراج شدید."
			lbl_status.modulate = Color(1.0, 0.48, 0.45)
			_request_lobbies()

		Commands.Start_Game:
			if typeof(payload) == TYPE_DICTIONARY and (payload as Dictionary).has("game_id"):
				var game_id: String = str((payload as Dictionary)["game_id"])
				var chosen_type: String = active_lobby_game_type
				if not current_lobby_queuers.is_empty():
					GameManager.set_match_gamers(current_lobby_queuers)
				GameManager.set_game_type(chosen_type)
				active_lobby_id = ""
				close_immediate()
				match_ready.emit(game_id, chosen_type)

func _kick_player(target_user_id: String) -> void:
	AudioManager.sfx_button()
	var payload: Dictionary = {
		"id": Commands.Lobby_Kick,
		"data": {
			"user_id": target_user_id
		}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)
