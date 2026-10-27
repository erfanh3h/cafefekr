extends PanelContainer

# Lobby Dialog Controller
# Mirrors Flutter's LobbyListBox & JoinedLobbyWidget:
# 1. Shows live list of active lobbies from server with 1-click join
# 2. Allows creating a new room with game type selection
# 3. Allows direct 6-char code joining
# 4. In-room ready status & match start coordination

signal closed()
signal match_ready(game_id: String, game_type: String)

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
@onready var input_room_name: LineEdit = $Margin/VBox/ViewCreate/InputRoomName
@onready var btn_select_game: Button = $Margin/VBox/ViewCreate/BtnSelectGame
@onready var lbl_selected_game: Label = $Margin/VBox/ViewCreate/BtnSelectGame/Margin/HBox/VBoxGameInfo/LblSelectedGame
@onready var selected_game_icon: TextureRect = $Margin/VBox/ViewCreate/BtnSelectGame/Margin/HBox/IconFrame/SelectedGameIcon
@onready var btn_create_confirm: Button = $Margin/VBox/ViewCreate/CreateButtonsRow/BtnCreateConfirm
@onready var btn_create_cancel: Button = $Margin/VBox/ViewCreate/CreateButtonsRow/BtnCreateCancel

# Game Select Modal (Flutter-style game cover picker)
@onready var game_select_modal: Control = $GameSelectModal
@onready var game_select_panel: PanelContainer = $GameSelectModal/Panel
@onready var btn_close_game_select: TextureButton = $GameSelectModal/Panel/ModalMargin/VBox/TopRow/BtnCloseGameSelect
@onready var scroll_games: ScrollContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames
@onready var game_grid: GridContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames/GameGrid
@onready var backdrop_game_select: ColorRect = $GameSelectModal/Backdrop

var selected_create_game_type: String = GameTypes.TIC_TAC_TOE

# View 3: Join by Code
@onready var view_join_code: VBoxContainer = $Margin/VBox/ViewJoinCode
@onready var input_join_code: LineEdit = $Margin/VBox/ViewJoinCode/InputJoinCode
@onready var btn_join_confirm: Button = $Margin/VBox/ViewJoinCode/JoinButtonsRow/BtnJoinConfirm
@onready var btn_join_cancel: Button = $Margin/VBox/ViewJoinCode/JoinButtonsRow/BtnJoinCancel

# View 4: Inside Lobby
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var view_inside: VBoxContainer = $Margin/VBox/ViewInside
@onready var lbl_room_id: Label = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HBox/CodePill/HBoxCode/LblRoomId
@onready var btn_copy_code: Button = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HBox/CodePill/HBoxCode/BtnCopyCode
@onready var lbl_game_name: Label = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HBox/VBoxGameInfo/LblGameName
@onready var inside_game_icon: TextureRect = $Margin/VBox/ViewInside/InsideHeaderCard/Margin/HBox/IconFrame/InsideGameIcon
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

# Game types
var available_games = [
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
	GameTypes.YATZY,
	GameTypes.LUDO,
	GameTypes.BATTLESHIP,
	GameTypes.FEKRBEKR,
	GameTypes.RPC,
	GameTypes.SUDOKU,
	GameTypes.BOXFOUR,
	GameTypes.MNUMBERS,
	GameTypes.MSWEEPER
]

var _btn_style = preload("res://assets/images/frames/button.png")
var _disc_style = preload("res://assets/images/frames/button5.png")

func _ready() -> void:
	# Authentic Kenney 3D Depth Buttons & Action Juice
	KenneyUI.style_button(btn_show_create, KenneyUI.COLOR_YELLOW)
	KenneyUI.style_button(btn_show_join_code, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_create_confirm, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_create_cancel, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_join_confirm, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_join_cancel, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_ready, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_leave_lobby, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_copy_code, KenneyUI.COLOR_BLUE)
	ActionVFXManager.apply_button_juice(btn_select_game, "tap_button")
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
	_on_room_name_changed(input_room_name.text)

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
	
	_update_selected_game_display()
	_setup_scroll_container_touch_drag(scroll_games)
	_setup_scroll_container_touch_drag(scroll_list)

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	active_lobby_id = ""
	active_lobby_creator_id = ""
	is_host = false
	is_ready = false
	current_lobby_queuers.clear()
	active_lobbies_data.clear()
	_switch_view(view_list)
	_update_lobbies_list()
	
	# Connect to /lobby namespace
	NetworkManager.socket.connect_namespace("/lobby", {"token": GameManager.token})
	if not NetworkManager.socket.event_received.is_connected(_on_lobby_event):
		NetworkManager.socket.event_received.connect(_on_lobby_event)
	
	# Initial fetch
	_request_lobbies()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		if active_lobby_id != "":
			_on_leave_lobby_pressed()
		NetworkManager.socket.disconnect_namespace("/lobby")
		if NetworkManager.socket.event_received.is_connected(_on_lobby_event):
			NetworkManager.socket.event_received.disconnect(_on_lobby_event)
		closed.emit()
	)

func close_immediate() -> void:
	visible = false
	if active_lobby_id != "":
		_on_leave_lobby_pressed()
	NetworkManager.socket.disconnect_namespace("/lobby")
	if NetworkManager.socket.event_received.is_connected(_on_lobby_event):
		NetworkManager.socket.event_received.disconnect(_on_lobby_event)
	closed.emit()

func _switch_view(target_view: Control) -> void:
	view_list.visible = (target_view == view_list)
	view_create.visible = (target_view == view_create)
	view_join_code.visible = (target_view == view_join_code)
	view_inside.visible = (target_view == view_inside)
	if is_instance_valid(game_select_modal):
		game_select_modal.visible = false
	lbl_status.text = ""
	
	if target_view == view_inside:
		lbl_title.text = "اتاق انتظار مسابقه"
		btn_refresh.visible = false
	elif target_view == view_create:
		lbl_title.text = "ساخت اتاق جدید"
		btn_refresh.visible = false
		_update_selected_game_display()
		_on_room_name_changed(input_room_name.text)
	elif target_view == view_join_code:
		lbl_title.text = "ورود با شناسه ۶ رقمی"
		btn_refresh.visible = false
	else:
		lbl_title.text = "اتاق‌های بازی آنلاین (لابی)"
		btn_refresh.visible = true

func _on_room_name_changed(new_text: String) -> void:
	var is_valid = not new_text.strip_edges().is_empty()
	btn_create_confirm.disabled = not is_valid
	if is_valid:
		btn_create_confirm.modulate = Color.WHITE
	else:
		btn_create_confirm.modulate = Color(0.65, 0.65, 0.65, 0.55)

func _update_selected_game_display() -> void:
	if not is_instance_valid(lbl_selected_game) or not is_instance_valid(selected_game_icon):
		return
	lbl_selected_game.text = GameTypes.get_display_name_fa(selected_create_game_type)
	var icon_path = "res://assets/images/games/%s.jpg" % selected_create_game_type.to_lower()
	if ResourceLoader.exists(icon_path):
		selected_game_icon.texture = load(icon_path)
	else:
		selected_game_icon.texture = load("res://assets/icons/General/lobby.png")

func _open_game_select_modal() -> void:
	game_select_modal.visible = true
	_populate_game_grid()
	
	var p_size = game_select_panel.size
	if p_size == Vector2.ZERO:
		p_size = Vector2(960, 1150)
	game_select_panel.pivot_offset = p_size / 2.0
	game_select_panel.scale = Vector2(0.92, 0.92)
	game_select_panel.modulate.a = 0.0
	
	var tw = game_select_panel.create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(game_select_panel, "modulate:a", 1.0, 0.15)

func _close_game_select_modal() -> void:
	var tw = game_select_panel.create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2(0.92, 0.92), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(game_select_panel, "modulate:a", 0.0, 0.14)
	tw.finished.connect(func():
		game_select_modal.visible = false
	)

func _populate_game_grid() -> void:
	for child in game_grid.get_children():
		child.queue_free()
	
	for g in available_games:
		var card = _create_game_card(g)
		game_grid.add_child(card)

func _create_game_card(g_type: String) -> Control:
	var is_selected = (g_type == selected_create_game_type)
	
	var card = Button.new()
	# 2 cards per row layout (width ~380px, height ~200px)
	card.custom_minimum_size = Vector2(380, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.pivot_offset = Vector2(190, 100)
	
	# Warm wooden mahogany card styling
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.22, 0.15, 0.1, 0.98)
	style_normal.set_corner_radius_all(18)
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(1.0, 0.88, 0.28, 1.0) if is_selected else Color(0.82, 0.68, 0.38, 0.85)
	style_normal.shadow_color = Color(1.0, 0.85, 0.25, 0.3) if is_selected else Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 10 if is_selected else 6
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.2, 0.13, 0.98)
	style_hover.set_corner_radius_all(18)
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(1.0, 0.94, 0.55, 1.0)
	style_hover.shadow_color = Color(1.0, 0.85, 0.2, 0.4)
	style_hover.shadow_size = 12
	style_hover.shadow_offset = Vector2(0, 5)
	
	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)
	
	# Warm underlay glow so transparent or dark areas look warm
	var bg_warmth = ColorRect.new()
	bg_warmth.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_warmth.color = Color(0.28, 0.18, 0.1, 0.95)
	bg_warmth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg_warmth)
	
	# Cover artwork (brightened and modulated for crisp contrast)
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.18, 1.12, 1.05)
	var icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	if ResourceLoader.exists(icon_path):
		img.texture = load(icon_path)
	else:
		img.texture = load("res://assets/icons/General/lobby.png")
	card.add_child(img)
	
	# Bottom title banner with gold separator line
	var banner = PanelContainer.new()
	banner.anchor_top = 0.68
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	b_style.border_width_top = 2
	b_style.border_color = Color(0.85, 0.7, 0.35, 0.75)
	b_style.corner_radius_bottom_left = 16
	b_style.corner_radius_bottom_right = 16
	banner.add_theme_stylebox_override("panel", b_style)
	
	var lbl = Label.new()
	lbl.text = GameTypes.get_display_name_fa(g_type)
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)
	
	# 2-player mode pill badge (top-left)
	var mode_pill = PanelContainer.new()
	mode_pill.position = Vector2(12, 12)
	mode_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.16, 0.1, 0.06, 0.85)
	p_style.border_width_left = 1
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.78, 0.62, 0.35, 0.8)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	mode_pill.add_theme_stylebox_override("panel", p_style)
	var mode_lbl = Label.new()
	mode_lbl.text = "۲ نفره"
	mode_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	mode_lbl.add_theme_font_size_override("font_size", 18)
	mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	mode_pill.add_child(mode_lbl)
	card.add_child(mode_pill)
	
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Smooth 60fps Viewport-Coordinate Drag Scrolling + Clean Tap Selection:
	# Uses exclusively viewport global mouse/touch position via InputEventMouseButton/Motion
	# (emulate_mouse_from_touch handles mobile touch seamlessly without local-coordinate oscillation or hover audio ticking).
	var drag_state = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_games.scroll_vertical
			else:
				var was_dragging = drag_state["dragging"]
				var was_active = drag_state["active"]
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_release = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_release <= 14.0:
						AudioManager.sfx_button()
						selected_create_game_type = g_type
						_update_selected_game_display()
						_close_game_select_modal()
		elif event is InputEventMouseMotion and drag_state["active"]:
			var dy = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or drag_state["dragging"]:
				drag_state["dragging"] = true
				scroll_games.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)
	
	return card

func _setup_scroll_container_touch_drag(sc: ScrollContainer) -> void:
	if not sc:
		return
	var sb = sc.get_v_scroll_bar()
	if sb:
		sb.custom_minimum_size = Vector2(16, 0)
	var state = {"down": false, "start_y": 0.0, "start_scroll": 0}
	sc.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				state["down"] = true
				state["start_y"] = get_viewport().get_mouse_position().y
				state["start_scroll"] = sc.scroll_vertical
			else:
				state["down"] = false
		elif event is InputEventMouseMotion and state["down"]:
			var delta_y = get_viewport().get_mouse_position().y - float(state["start_y"])
			sc.scroll_vertical = max(0, int(state["start_scroll"]) - int(delta_y))
	)
func _request_lobbies() -> void:
	lbl_status.text = "در حال بروزرسانی لیست اتاق‌ها..."
	var payload = {
		"id": Commands.Lobby_Request_Data,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _update_lobbies_list() -> void:
	for child in lobbies_container.get_children():
		child.queue_free()
	
	lbl_no_lobbies.visible = false
	
	if active_lobbies_data.is_empty():
		return
	
	for lobby in active_lobbies_data:
		var row = _create_lobby_row(lobby)
		lobbies_container.add_child(row)

func _create_lobby_row(lobby: Dictionary) -> PanelContainer:
	var lobby_id = lobby.get("lobby_id", "")
	var lobby_name = lobby.get("lobby_name", "اتاق بازی")
	var game_type = lobby.get("game_type", GameTypes.TIC_TAC_TOE)
	var q_len = lobby.get("queuers_length", len(lobby.get("queuers", [])))
	var max_count = lobby.get("lobby_count", 2)
	
	var row_panel = PanelContainer.new()
	var style = StyleBoxTexture.new()
	style.texture = _btn_style
	style.texture_margin_left = 25
	style.texture_margin_right = 25
	style.texture_margin_top = 18
	style.texture_margin_bottom = 18
	row_panel.add_theme_stylebox_override("panel", style)
	row_panel.custom_minimum_size = Vector2(0, 105)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	row_panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	
	# Join button (Kenney tactile button)
	var btn_join = Button.new()
	btn_join.text = "ورود"
	btn_join.custom_minimum_size = Vector2(130, 68)
	btn_join.add_theme_font_size_override("font_size", 26)
	KenneyUI.style_button(btn_join, KenneyUI.COLOR_GREEN)
	btn_join.pressed.connect(func():
		AudioManager.sfx_button()
		_join_lobby_by_id(lobby_id)
	)
	hbox.add_child(btn_join)
	
	# Player Count Badge
	var count_lbl = Label.new()
	count_lbl.text = "%d / %d" % [q_len, max_count]
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	count_lbl.add_theme_font_size_override("font_size", 26)
	hbox.add_child(count_lbl)
	
	# Room & Game Info
	var text_col = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = Label.new()
	name_lbl.text = lobby_name
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(name_lbl)
	
	var game_lbl = Label.new()
	game_lbl.text = GameTypes.get_display_name_fa(game_type)
	game_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.65))
	game_lbl.add_theme_font_size_override("font_size", 22)
	game_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(game_lbl)
	
	hbox.add_child(text_col)
	
	# Game Icon Thumbnail
	var icon_plate = TextureRect.new()
	icon_plate.custom_minimum_size = Vector2(68, 68)
	icon_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path = "res://assets/images/games/%s.jpg" % game_type.to_lower()
	if ResourceLoader.exists(icon_path):
		icon_plate.texture = load(icon_path)
	else:
		icon_plate.texture = load("res://assets/icons/General/lobby.png")
	hbox.add_child(icon_plate)
	
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row_state = {"down": false, "start_y": 0.0, "start_scroll": 0}
	row_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				row_state["down"] = true
				row_state["start_y"] = get_viewport().get_mouse_position().y
				row_state["start_scroll"] = scroll_list.scroll_vertical
			else:
				row_state["down"] = false
		elif event is InputEventMouseMotion and row_state["down"]:
			var delta_y = get_viewport().get_mouse_position().y - float(row_state["start_y"])
			scroll_list.scroll_vertical = max(0, int(row_state["start_scroll"]) - int(delta_y))
	)
	return row_panel

func _join_lobby_by_id(lobby_id: String) -> void:
	if lobby_id.is_empty():
		return
	lbl_status.text = "در حال پیوستن به اتاق %s..." % lobby_id
	var payload = {
		"id": Commands.Lobby_Join,
		"data": {"lobby_id": lobby_id}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_create_pressed() -> void:
	var r_name = input_room_name.text.strip_edges()
	if r_name.is_empty():
		return
	AudioManager.sfx_button()
	var g_type = selected_create_game_type
	
	lbl_status.text = "در حال ساخت اتاق..."
	var payload = {
		"id": Commands.Lobby_Create,
		"data": {
			"game_type": g_type,
			"lobby_name": r_name,
			"lobby_password": "",
			"lobby_count": 2
		}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_join_pressed() -> void:
	AudioManager.sfx_button()
	var code = input_join_code.text.strip_edges().to_upper()
	if code.is_empty():
		lbl_status.text = "لطفاً شناسه ۶ رقمی اتاق را وارد کنید."
		return
	_join_lobby_by_id(code)

func _show_inside_view(lobby_data: Dictionary) -> void:
	_switch_view(view_inside)
	active_lobby_id = lobby_data.get("lobby_id", "")
	active_lobby_creator_id = lobby_data.get("creator_id", "")
	lbl_room_id.text = "کد اتاق: " + active_lobby_id
	
	active_lobby_game_type = lobby_data.get("game_type", GameTypes.TIC_TAC_TOE)
	lbl_game_name.text = GameTypes.get_display_name_fa(active_lobby_game_type)
	
	if is_instance_valid(inside_game_icon):
		var icon_path = "res://assets/images/games/%s.jpg" % active_lobby_game_type.to_lower()
		if ResourceLoader.exists(icon_path):
			inside_game_icon.texture = load(icon_path)
		else:
			inside_game_icon.texture = load("res://assets/icons/General/lobby.png")
	
	is_host = (active_lobby_creator_id == GameManager.get_user_id())
	btn_start.visible = is_host
	btn_ready.visible = not is_host
	
	var q_list = lobby_data.get("queuers", [])
	_update_players_list(q_list)

func _update_players_list(queuers: Array) -> void:
	current_lobby_queuers = queuers
	for child in players_list.get_children():
		child.queue_free()
	
	var all_guests_ready = true
	var guests_count = 0
	
	for q in queuers:
		var q_uid = q.get("user_id", "")
		var is_this_creator = (q_uid == active_lobby_creator_id) if active_lobby_creator_id != "" else (q == queuers[0])
		var rdy = q.get("is_rdy", false)
		
		if not is_this_creator:
			guests_count += 1
			if not rdy:
				all_guests_ready = false
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 110)
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = Color(0.24, 0.16, 0.10, 0.96)
		c_style.set_corner_radius_all(18)
		c_style.set_border_width_all(2)
		if is_this_creator:
			c_style.border_color = Color(1.0, 0.84, 0.32, 0.95)
			c_style.shadow_color = Color(1.0, 0.8, 0.2, 0.2)
		elif rdy:
			c_style.border_color = Color(0.35, 0.92, 0.45, 0.9)
			c_style.shadow_color = Color(0.2, 0.8, 0.3, 0.2)
		else:
			c_style.border_color = Color(0.72, 0.6, 0.42, 0.7)
			c_style.shadow_color = Color(0, 0, 0, 0.35)
		c_style.shadow_size = 8
		c_style.shadow_offset = Vector2(0, 3)
		c_style.content_margin_left = 20
		c_style.content_margin_right = 20
		c_style.content_margin_top = 12
		c_style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", c_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 18)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Left side: Status badge / pill
		var badge_panel = PanelContainer.new()
		var badge_style = StyleBoxFlat.new()
		badge_style.set_corner_radius_all(12)
		badge_style.content_margin_left = 14
		badge_style.content_margin_right = 14
		badge_style.content_margin_top = 8
		badge_style.content_margin_bottom = 8
		badge_style.set_border_width_all(1)
		
		var rdy_lbl = Label.new()
		rdy_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		rdy_lbl.add_theme_font_size_override("font_size", 24)
		
		if is_this_creator:
			badge_style.bg_color = Color(0.35, 0.26, 0.08, 0.95)
			badge_style.border_color = Color(1.0, 0.85, 0.3, 0.95)
			rdy_lbl.text = "👑 میزبان اتاق"
			rdy_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		elif rdy:
			badge_style.bg_color = Color(0.08, 0.32, 0.14, 0.95)
			badge_style.border_color = Color(0.35, 0.95, 0.45, 0.95)
			rdy_lbl.text = "✅ آماده مسابقه"
			rdy_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		else:
			badge_style.bg_color = Color(0.2, 0.16, 0.12, 0.9)
			badge_style.border_color = Color(0.7, 0.6, 0.45, 0.6)
			rdy_lbl.text = "⏳ در حال آماده‌سازی"
			rdy_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
			
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		badge_panel.add_child(rdy_lbl)
		hbox.add_child(badge_panel)
		
		# Middle: Player name (prominent, no subtitle)
		var name_lbl = Label.new()
		name_lbl.text = q.get("name", q.get("username", "بازیکن"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		name_lbl.add_theme_font_size_override("font_size", 38)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		name_lbl.add_theme_constant_override("shadow_outline_size", 3)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(name_lbl)
		
		# Right side: Avatar
		var av_frame = PanelContainer.new()
		av_frame.custom_minimum_size = Vector2(80, 80)
		var av_style = StyleBoxFlat.new()
		av_style.bg_color = Color(0.16, 0.1, 0.06, 0.95)
		av_style.set_corner_radius_all(16)
		av_style.set_border_width_all(2)
		av_style.border_color = Color(1.0, 0.85, 0.35, 0.9) if is_this_creator else Color(0.8, 0.68, 0.45, 0.75)
		av_frame.add_theme_stylebox_override("panel", av_style)
		
		var avatar = TextureRect.new()
		avatar.custom_minimum_size = Vector2(72, 72)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var img_id = q.get("image", 0)
		var av_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(av_path):
			avatar.texture = load(av_path)
		else:
			avatar.texture = load("res://assets/icons/Avatars/0.png")
		av_frame.add_child(avatar)
		hbox.add_child(av_frame)
		
		card.add_child(hbox)
		players_list.add_child(card)
		
		# Local guest player ready button update
		if q_uid == GameManager.get_user_id() and not is_host:
			is_ready = rdy
			if is_ready:
				btn_ready.text = "آماده هستید"
				btn_ready.disabled = true
				KenneyUI.style_button(btn_ready, KenneyUI.COLOR_YELLOW)
			else:
				btn_ready.text = "اعلام آمادگی"
				btn_ready.disabled = false
				KenneyUI.style_button(btn_ready, KenneyUI.COLOR_GREEN)
	
	# Empty slot card if waiting for Player 2 (Pulsing fade in / fade out, NO plus icon)
	if queuers.size() < 2:
		var empty_card = PanelContainer.new()
		empty_card.custom_minimum_size = Vector2(0, 110)
		var emp_style = StyleBoxFlat.new()
		emp_style.bg_color = Color(0.18, 0.12, 0.08, 0.55)
		emp_style.set_corner_radius_all(18)
		emp_style.set_border_width_all(2)
		emp_style.border_color = Color(0.82, 0.68, 0.42, 0.65)
		emp_style.content_margin_left = 22
		emp_style.content_margin_right = 22
		emp_style.content_margin_top = 12
		emp_style.content_margin_bottom = 12
		empty_card.add_theme_stylebox_override("panel", emp_style)
		
		# Looping fade-in fade-out pulsing animation
		var pulse_tw = empty_card.create_tween().set_loops()
		pulse_tw.tween_property(empty_card, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(empty_card, "modulate:a", 0.95, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		var ehbox = HBoxContainer.new()
		ehbox.add_theme_constant_override("separation", 18)
		ehbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Left badge: "⏳ در انتظار..."
		var emp_badge = PanelContainer.new()
		var eb_style = StyleBoxFlat.new()
		eb_style.bg_color = Color(0.24, 0.16, 0.08, 0.8)
		eb_style.set_corner_radius_all(12)
		eb_style.content_margin_left = 14
		eb_style.content_margin_right = 14
		eb_style.content_margin_top = 8
		eb_style.content_margin_bottom = 8
		eb_style.set_border_width_all(1)
		eb_style.border_color = Color(0.8, 0.65, 0.35, 0.65)
		emp_badge.add_theme_stylebox_override("panel", eb_style)
		var emp_wait_lbl = Label.new()
		emp_wait_lbl.text = "⏳ در انتظار..."
		emp_wait_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		emp_wait_lbl.add_theme_font_size_override("font_size", 22)
		emp_wait_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 0.9))
		emp_badge.add_child(emp_wait_lbl)
		ehbox.add_child(emp_badge)
		
		# Middle / Right text (fills the row, NO plus icon)
		var evbox = VBoxContainer.new()
		evbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		evbox.add_theme_constant_override("separation", 2)
		evbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var elbl1 = Label.new()
		elbl1.text = "در انتظار پیوستن بازیکن دوم..."
		elbl1.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		elbl1.add_theme_font_size_override("font_size", 28)
		elbl1.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6, 0.95))
		elbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		evbox.add_child(elbl1)
		
		var elbl2 = Label.new()
		elbl2.text = "کد ۶ رقمی اتاق را برای دوستان خود ارسال کنید"
		elbl2.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		elbl2.add_theme_font_size_override("font_size", 20)
		elbl2.add_theme_color_override("font_color", Color(0.88, 0.82, 0.7, 0.8))
		elbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		evbox.add_child(elbl2)
		ehbox.add_child(evbox)
		
		empty_card.add_child(ehbox)
		players_list.add_child(empty_card)
	
	if is_host:
		if queuers.size() < 2:
			btn_start.disabled = true
			btn_start.text = "در انتظار بازیکن دوم..."
			btn_start.modulate = Color.WHITE
			KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREY)
			btn_start.add_theme_color_override("font_disabled_color", Color(0.88, 0.82, 0.72, 0.8))
		elif not all_guests_ready:
			btn_start.disabled = true
			btn_start.text = "در انتظار آمادگی حریف..."
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
		var q = current_lobby_queuers[i]
		if q.get("user_id") == user_id:
			q["is_rdy"] = true
			current_lobby_queuers[i] = q
			break
	_update_players_list(current_lobby_queuers)

func _on_ready_pressed() -> void:
	AudioManager.sfx_tap()
	if is_ready:
		return
	is_ready = true
	btn_ready.text = "آماده هستید"
	btn_ready.disabled = true
	KenneyUI.style_button(btn_ready, KenneyUI.COLOR_YELLOW)
	
	var payload = {
		"id": Commands.Lobby_Player_Ready,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_start_pressed() -> void:
	AudioManager.sfx_button()
	lbl_status.text = "در حال راه‌اندازی مسابقه..."
	var payload = {
		"id": Commands.Lobby_Start_Game,
		"data": {}
	}
	NetworkManager.socket.emit_event("/lobby", "user_command", payload)

func _on_leave_lobby_pressed() -> void:
	AudioManager.sfx_button()
	if active_lobby_id != "":
		var cmd = Commands.Lobby_Delete if is_host else Commands.Lobby_Quit
		var payload = {"id": cmd, "data": {}}
		NetworkManager.socket.emit_event("/lobby", "user_command", payload)
		active_lobby_id = ""
	_switch_view(view_list)
	_request_lobbies()

func _on_lobby_event(ns: String, event_name: String, data: Variant) -> void:
	if ns != "/lobby" or event_name != "command" or typeof(data) != TYPE_DICTIONARY:
		return
	
	var cmd_id = data.get("id", "")
	var payload = data.get("data", {})
	
	match cmd_id:
		Commands.Lobby_List:
			lbl_status.text = ""
			if typeof(payload) == TYPE_ARRAY:
				active_lobbies_data = payload
				_update_lobbies_list()
		
		Commands.Lobby_Created:
			if typeof(payload) == TYPE_DICTIONARY:
				# Add new lobby if not already in list
				var found = false
				for i in range(active_lobbies_data.size()):
					if active_lobbies_data[i].get("lobby_id") == payload.get("lobby_id"):
						found = true
						break
				if not found:
					active_lobbies_data.append(payload)
					_update_lobbies_list()
		
		Commands.Lobby_Data:
			if typeof(payload) == TYPE_DICTIONARY:
				_show_inside_view(payload)

		Commands.Lobby_Players_Update:
			if typeof(payload) == TYPE_DICTIONARY and payload.has("queuers"):
				_update_players_list(payload["queuers"])
			elif typeof(payload) == TYPE_DICTIONARY and payload.has("lobby_id"):
				# Global lobby count update
				var l_id = payload.get("lobby_id")
				var count = payload.get("count", 0)
				for i in range(active_lobbies_data.size() - 1, -1, -1):
					if active_lobbies_data[i].get("lobby_id") == l_id:
						if count == 0:
							active_lobbies_data.remove_at(i)
						else:
							active_lobbies_data[i]["queuers_length"] = count
						break
				_update_lobbies_list()

		Commands.Lobby_Player_Ready:
			if typeof(payload) == TYPE_DICTIONARY:
				var rdy_uid = payload.get("user_id", "")
				_mark_player_ready(rdy_uid)

		Commands.Lobby_Deleted:
			var del_id = payload.get("lobby_id", "")
			for i in range(active_lobbies_data.size() - 1, -1, -1):
				if active_lobbies_data[i].get("lobby_id") == del_id:
					active_lobbies_data.remove_at(i)
					break
			_update_lobbies_list()
			if active_lobby_id == del_id:
				active_lobby_id = ""
				_switch_view(view_list)

		Commands.Lobby_Full:
			lbl_status.text = "این اتاق پر شده است!"
			lbl_status.modulate = Color(1.0, 0.4, 0.4)

		Commands.Lobby_Not_Exists:
			lbl_status.text = "اتاق مورد نظر یافت نشد!"
			lbl_status.modulate = Color(1.0, 0.4, 0.4)

		Commands.Start_Game:
			# Host or server launched match!
			if typeof(payload) == TYPE_DICTIONARY and payload.has("game_id"):
				var game_id = payload["game_id"]
				var chosen_type = active_lobby_game_type
				if not current_lobby_queuers.is_empty():
					GameManager.set_match_gamers(current_lobby_queuers)
				GameManager.set_game_type(chosen_type)
				# Clear active_lobby_id so close() doesn't send Lobby_Delete or Lobby_Quit!
				active_lobby_id = ""
				close_immediate()
				match_ready.emit(game_id, chosen_type)
