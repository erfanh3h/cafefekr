extends PanelContainer

# Pick & Ban Drafting Scene (Vertical Portrait Layout) for Main Rank competitive mode.
# Features:
# - Designed for 1080x1920 portrait mobile view.
# - High-visibility Header with Title, Status Banner, and Countdown Timer.
# - Players Matchup strip (P1 vs P2) with Avatars, Ratings, and Roles.
# - Interactive 7-Step Selection Timeline showing live progress and picks/bans.
# - System Bans Bar displaying the 3 automatically removed games.
# - 3-Column Vertical Game Selection Grid with smooth scrolling and high-res art.
# - Bottom Action Bar with selected game title and dynamic Confirm button.
# - Full Disconnect / Reconnect recovery handling and animated indicators.

signal pick_ban_finished(game_id: String, first_game: String)
signal pick_ban_cancelled()

const GameRegistry = preload("res://scripts/games/game_registry.gd")
const KenneyUI = preload("res://scenes/ui/kenney_ui_helper.gd")

# Nodes
@onready var lbl_title: Label = $Margin/VBox/Header/TopRow/LblTitle
@onready var lbl_subtitle: Label = $Margin/VBox/Header/LblSubtitle
@onready var lbl_status: Label = $Margin/VBox/Header/StatusPanel/MarginStatus/HBoxStatus/LblStatus
@onready var lbl_turn_timer: Label = $Margin/VBox/Header/StatusPanel/MarginStatus/HBoxStatus/LblTurnTimer
@onready var turn_timer_bar: ProgressBar = $Margin/VBox/Header/TurnTimerBar

# Disconnect Banner
@onready var disconnect_banner: PanelContainer = $Margin/VBox/Header/DisconnectBanner
@onready var lbl_disconnect: Label = $Margin/VBox/Header/DisconnectBanner/MarginDc/HBoxDc/LblDisconnect
@onready var lbl_dc_timer: Label = $Margin/VBox/Header/DisconnectBanner/MarginDc/HBoxDc/LblDcTimer

# Players Strip
@onready var p1_card: PanelContainer = $Margin/VBox/PlayersStrip/P1Card
@onready var p1_avatar: TextureRect = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/P1Avatar
@onready var p1_name: Label = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/VBoxP1/P1Name
@onready var p1_score: Label = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/VBoxP1/P1Score
@onready var p1_role: Label = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/VBoxP1/P1Role

@onready var lbl_vs: Label = $Margin/VBox/PlayersStrip/CenterVS/LblVS
@onready var lbl_series: Label = $Margin/VBox/PlayersStrip/CenterVS/LblSeries

@onready var p2_card: PanelContainer = $Margin/VBox/PlayersStrip/P2Card
@onready var p2_avatar: TextureRect = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/P2Avatar
@onready var p2_name: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/VBoxP2/P2Name
@onready var p2_score: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/VBoxP2/P2Score
@onready var p2_role: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/VBoxP2/P2Role

# Timeline
@onready var scroll_timeline: ScrollContainer = $Margin/VBox/TimelinePanel/MarginTimeline/VBoxTimeline/ScrollTimeline
@onready var hbox_timeline: HBoxContainer = $Margin/VBox/TimelinePanel/MarginTimeline/VBoxTimeline/ScrollTimeline/HBoxTimeline

# System Bans
@onready var lbl_sys_ban1: Label = $Margin/VBox/SystemBansStrip/SysBanChip1/Margin/LblSysBan1
@onready var lbl_sys_ban2: Label = $Margin/VBox/SystemBansStrip/SysBanChip2/Margin/LblSysBan2
@onready var lbl_sys_ban3: Label = $Margin/VBox/SystemBansStrip/SysBanChip3/Margin/LblSysBan3

# Games Grid
@onready var games_grid: GridContainer = $Margin/VBox/GamesScroll/MarginGrid/GamesGrid

# Bottom Bar
@onready var lbl_selected_game: Label = $Margin/VBox/BottomBar/LblSelectedGame
@onready var btn_confirm: Button = $Margin/VBox/BottomBar/BtnConfirm

# State
var pre_game_id: String = ""
var my_user_id: String = ""
var my_player_index: int = 1 # 1 or 2
var p1_data: Dictionary = {}
var p2_data: Dictionary = {}

var turn_index: int = 0 # 1 to 7
var active_turn_user_id: String = ""
var is_my_turn: bool = false
var turn_time_left: float = 20.0
var turn_total_time: float = 20.0
var is_timer_active: bool = false
var dc_time_left: float = 0.0
var is_dc_active: bool = false

var available_games: Array = []
var system_banned: Array = []
var p1_banned: Array = []
var p2_banned: Array = []
var p1_picked: String = ""
var p2_picked: String = ""
var system_picked: String = ""

var currently_selected_card_game: String = ""
var game_card_nodes: Dictionary = {} # game_type -> PanelContainer
var timeline_nodes: Dictionary = {} # turn_num (1..7) -> Dictionary of subnodes
var reconnect_timeout_timer: Timer = null
var game_finished_modal: Control = null
var draft_showcase_overlay: Control = null

const TWO_PLAYER_GAMES = [
	"TicTacToe", "RPC", "DotBox", "MNumbers", "MSweeper",
	"FekrBekr", "Yatzy", "Pentago", "FourInRow", "Sudoku",
	"BattleShip", "BoxFour", "Yinsh", "Chess", "Checkers",
	"Othello", "Mill", "BackGammon"
]

const TIMELINE_CONFIG = [
	{"turn": 1, "owner": 1, "type": "ban", "label": "بن ۱", "actor": "بازیکن ۱"},
	{"turn": 2, "owner": 2, "type": "ban", "label": "بن ۱", "actor": "بازیکن ۲"},
	{"turn": 3, "owner": 1, "type": "pick", "label": "بازی ۱", "actor": "پیک ب ۱"},
	{"turn": 4, "owner": 2, "type": "pick", "label": "بازی ۲", "actor": "پیک ب ۲"},
	{"turn": 5, "owner": 1, "type": "ban", "label": "بن ۲", "actor": "بازیکن ۱"},
	{"turn": 6, "owner": 2, "type": "ban", "label": "بن ۲", "actor": "بازیکن ۲"},
	{"turn": 7, "owner": 0, "type": "sys_pick", "label": "بازی ۳", "actor": "سیستم"}
]

func _ready() -> void:
	KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_GREEN)
	btn_confirm.pressed.connect(_on_confirm_pressed)
	btn_confirm.disabled = true
	_connect_network_signals()

func _process(delta: float) -> void:
	if not visible:
		return
		
	if is_timer_active:
		turn_time_left = max(0.0, turn_time_left - delta)
		turn_timer_bar.value = (turn_time_left / turn_total_time) * 100.0
		lbl_turn_timer.text = "⏳ %d ثانیه" % int(ceil(turn_time_left))
		
		if turn_time_left <= 5.0:
			turn_timer_bar.modulate = Color(1.0, 0.35, 0.35)
			lbl_turn_timer.modulate = Color(1.0, 0.35, 0.35)
		elif turn_time_left <= 10.0:
			turn_timer_bar.modulate = Color(1.0, 0.85, 0.35)
			lbl_turn_timer.modulate = Color(1.0, 0.85, 0.35)
		else:
			turn_timer_bar.modulate = Color(0.35, 0.95, 0.45)
			lbl_turn_timer.modulate = Color(0.35, 0.95, 0.45)

	if is_dc_active:
		dc_time_left = max(0.0, dc_time_left - delta)
		lbl_dc_timer.text = "%ds" % int(ceil(dc_time_left))
		if dc_time_left <= 0:
			is_dc_active = false
			disconnect_banner.visible = false

func is_match_active() -> bool:
	return GameManager.is_game_active or not GameManager.active_game_id.is_empty() or not GameManager.get_open_game_id().is_empty()

func _connect_network_signals() -> void:
	NetworkManager.system_banned_games_received.connect(_on_system_banned_games_received)
	NetworkManager.select_game_turn.connect(_on_select_game_turn)
	NetworkManager.selected_game_received.connect(_on_selected_game_received)
	NetworkManager.queue_game_canceled.connect(_on_game_canceled)
	NetworkManager.queue_game_finished.connect(_on_queue_game_finished)
	NetworkManager.queue_start_game_received.connect(_on_queue_start_game_received)

# ==============================================================================
# OPEN / INITIALIZATION
# ==============================================================================

func open(p_pre_game_id: String, queuers: Array) -> void:
	if is_match_active():
		print("[PickBan] Suppressed open(): Game match is already active.")
		visible = false
		return
	pre_game_id = p_pre_game_id
	my_user_id = str(GameManager.get_user_id())
	turn_index = 0
	currently_selected_card_game = ""
	is_dc_active = false
	disconnect_banner.visible = false
	
	available_games.clear()
	for g in TWO_PLAYER_GAMES:
		available_games.append(g)
		
	system_banned.clear()
	p1_banned.clear()
	p2_banned.clear()
	p1_picked = ""
	p2_picked = ""
	system_picked = ""
	
	if queuers.size() >= 2:
		p1_data = queuers[0]
		p2_data = queuers[1]
	else:
		p1_data = {"user_id": my_user_id, "name": GameManager.get_username(), "image": GameManager.get_avatar_id(), "score": GameManager.get_score()}
		p2_data = {"user_id": "opponent", "name": "حریف", "image": 1, "score": 1000}
		
	if str(p1_data.get("user_id", "")) == my_user_id:
		my_player_index = 1
	else:
		my_player_index = 2
		
	_setup_player_strip()
	_build_timeline()
	_build_games_grid()
	
	lbl_status.text = "در حال تحلیل و حذف ۳ بازی توسط سیستم کافه‌فکر..."
	lbl_status.modulate = Color(1.0, 0.88, 0.45)
	lbl_selected_game.text = "بازی انتخاب‌شده: —"
	btn_confirm.disabled = true
	btn_confirm.text = "در انتظار شروع درفت..."
	
	_start_timer(5.0)
	
	visible = true
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.28)

func show_reconnecting_state(p_pre_game_id: String) -> void:
	if is_match_active():
		print("[PickBan] Suppressed show_reconnecting_state(): Game match is already active.")
		visible = false
		return
	pre_game_id = p_pre_game_id
	my_user_id = str(GameManager.get_user_id())
	visible = true
	modulate.a = 1.0
	lbl_status.text = "در حال بازیابی وضعیت درفت مسابقه از سرور..."
	lbl_status.modulate = Color(0.4, 0.9, 1.0)
	btn_confirm.disabled = true
	btn_confirm.text = "در حال اتصال مجدد..."
	
	# Start 6-second fallback timer: if server never answers with reconnect_data, the draft has ended!
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
	reconnect_timeout_timer = Timer.new()
	reconnect_timeout_timer.wait_time = 6.0
	reconnect_timeout_timer.one_shot = true
	reconnect_timeout_timer.timeout.connect(func():
		print("[PickBan] Reconnect timeout reached. Game or draft has finished on server.")
		show_game_finished_dialog("این بازی به پایان رسیده است.")
	)
	add_child(reconnect_timeout_timer)
	reconnect_timeout_timer.start()

func open_from_reconnect(data: Dictionary) -> void:
	if is_match_active():
		print("[PickBan] Suppressed open_from_reconnect(): Game match is already active.")
		visible = false
		return
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
		reconnect_timeout_timer = null
		
	pre_game_id = str(data.get("pre_game_id", pre_game_id))
	my_user_id = str(GameManager.get_user_id())
	currently_selected_card_game = ""
	is_dc_active = false
	disconnect_banner.visible = false
	
	available_games.clear()
	for g in TWO_PLAYER_GAMES:
		available_games.append(g)
		
	var queuers = data.get("queuers", []) as Array
	if queuers.size() >= 2:
		p1_data = queuers[0]
		p2_data = queuers[1]
	else:
		p1_data = {"user_id": my_user_id, "name": GameManager.get_username(), "image": GameManager.get_avatar_id(), "score": GameManager.get_score()}
		p2_data = {"user_id": "opponent", "name": "حریف", "image": 1, "score": 1000}
		
	if str(p1_data.get("user_id", "")) == my_user_id:
		my_player_index = 1
	else:
		my_player_index = 2
		
	_setup_player_strip()
	_build_timeline()
	_build_games_grid()
	
	# Apply system bans
	var sys_bans = data.get("pre_bans", []) as Array
	if not sys_bans.is_empty():
		_on_system_banned_games_received(sys_bans)
		
	# Apply past turn history
	var turn_hist = data.get("turn_history", {}) as Dictionary
	for turn_key in turn_hist.keys():
		var t_idx = int(turn_key)
		var g_type = str(turn_hist[turn_key])
		_apply_game_selection(t_idx, g_type)
		
	# Set active turn
	var cur_turn_idx = int(data.get("active_index", 1))
	var active_uid = str(data.get("active_user_id", ""))
	var rem_time = float(data.get("timer_value", 20))
	
	turn_index = cur_turn_idx
	active_turn_user_id = active_uid
	is_my_turn = (active_uid == my_user_id)
	
	_update_timeline_active_step(turn_index)
	_update_turn_ui()
	_start_timer(rem_time)
	
	visible = true
	modulate.a = 1.0

# ==============================================================================
# UI BUILDERS
# ==============================================================================

func _setup_player_strip() -> void:
	# P1
	var p1_uname = str(p1_data.get("name", p1_data.get("username", "بازیکن ۱")))
	var p1_s = int(p1_data.get("score", 1200))
	var p1_img = int(p1_data.get("image", p1_data.get("user_image", p1_data.get("avatar", 0))))
	p1_name.text = p1_uname
	p1_score.text = "امتیاز: %d" % p1_s
	p1_avatar.texture = _load_avatar_texture(p1_img)
	if my_player_index == 1:
		p1_role.text = "بازیکن ۱ (شما)"
		p1_role.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
	else:
		p1_role.text = "بازیکن ۱"
		p1_role.add_theme_color_override("font_color", Color(0.85, 0.75, 0.60))
		
	# P2
	var p2_uname = str(p2_data.get("name", p2_data.get("username", "بازیکن ۲")))
	var p2_s = int(p2_data.get("score", 1150))
	var p2_img = int(p2_data.get("image", p2_data.get("user_image", p2_data.get("avatar", 1))))
	p2_name.text = p2_uname
	p2_score.text = "امتیاز: %d" % p2_s
	p2_avatar.texture = _load_avatar_texture(p2_img)
	if my_player_index == 2:
		p2_role.text = "بازیکن ۲ (شما)"
		p2_role.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
	else:
		p2_role.text = "بازیکن ۲ (حریف)"
		p2_role.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		
	lbl_series.text = "دست ۱/۳"

func _build_timeline() -> void:
	for child in hbox_timeline.get_children():
		child.queue_free()
	timeline_nodes.clear()
	
	for i in range(TIMELINE_CONFIG.size()):
		var cfg = TIMELINE_CONFIG[i]
		var t_num = int(cfg["turn"])
		var t_type = str(cfg["type"]) # "ban", "pick", "sys_pick"
		var t_owner = int(cfg["owner"]) # 1, 2, 0 (sys)
		
		# 1. Main Step Card Container
		var node_box = PanelContainer.new()
		node_box.custom_minimum_size = Vector2(215, 285)
		node_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.08, 0.06, 0.95)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.48, 0.36, 0.22, 0.85)
		sb.set_corner_radius_all(16)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 6
		node_box.add_theme_stylebox_override("panel", sb)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		node_box.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)
		
		# Top header row: Step badge & Action chip
		var hbox_top = HBoxContainer.new()
		hbox_top.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox_top.add_theme_constant_override("separation", 6)
		vbox.add_child(hbox_top)
		
		var lbl_num = Label.new()
		lbl_num.text = "#%d" % t_num
		lbl_num.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		lbl_num.add_theme_font_size_override("font_size", 26)
		lbl_num.modulate = Color(1.0, 0.88, 0.5)
		hbox_top.add_child(lbl_num)
		
		var spacer_t = Control.new()
		spacer_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox_top.add_child(spacer_t)
		
		# Action Tag Chip
		var chip_panel = PanelContainer.new()
		var chip_sb = StyleBoxFlat.new()
		chip_sb.set_corner_radius_all(8)
		chip_sb.set_border_width_all(1)
		
		var lbl_tag = Label.new()
		lbl_tag.text = str(cfg["label"])
		lbl_tag.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		lbl_tag.add_theme_font_size_override("font_size", 22)
		
		if t_type == "ban":
			chip_sb.bg_color = Color(0.35, 0.08, 0.08, 0.85)
			chip_sb.border_color = Color(0.95, 0.35, 0.35, 0.9)
			lbl_tag.modulate = Color(1.0, 0.45, 0.45)
		elif t_type == "sys_pick":
			chip_sb.bg_color = Color(0.35, 0.25, 0.05, 0.85)
			chip_sb.border_color = Color(1.0, 0.85, 0.3, 0.9)
			lbl_tag.modulate = Color(1.0, 0.88, 0.35)
		else:
			chip_sb.bg_color = Color(0.08, 0.28, 0.15, 0.85)
			chip_sb.border_color = Color(0.35, 0.95, 0.55, 0.9)
			lbl_tag.modulate = Color(0.4, 0.95, 0.6)
			
		chip_panel.add_theme_stylebox_override("panel", chip_sb)
		var chip_margin = MarginContainer.new()
		chip_margin.add_theme_constant_override("margin_left", 8)
		chip_margin.add_theme_constant_override("margin_top", 2)
		chip_margin.add_theme_constant_override("margin_right", 8)
		chip_margin.add_theme_constant_override("margin_bottom", 2)
		chip_panel.add_child(chip_margin)
		chip_margin.add_child(lbl_tag)
		hbox_top.add_child(chip_panel)
		
		# Center Thumbnail Frame
		var frame = PanelContainer.new()
		frame.custom_minimum_size = Vector2(136, 136)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var frame_sb = StyleBoxFlat.new()
		frame_sb.bg_color = Color(0.05, 0.03, 0.02, 0.9)
		frame_sb.set_border_width_all(2)
		frame_sb.border_color = Color(0.40, 0.30, 0.18, 0.8)
		frame_sb.set_corner_radius_all(12)
		frame.add_theme_stylebox_override("panel", frame_sb)
		
		var img_rect = TextureRect.new()
		img_rect.custom_minimum_size = Vector2(132, 132)
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img_rect.texture = _load_game_texture("tictactoe")
		img_rect.modulate = Color(0.4, 0.4, 0.4, 0.25)
		frame.add_child(img_rect)
		
		# Ban Stamp Overlay (hidden until banned)
		var ban_overlay = Label.new()
		ban_overlay.text = "✖"
		ban_overlay.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		ban_overlay.add_theme_font_size_override("font_size", 54)
		ban_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ban_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ban_overlay.modulate = Color(1.0, 0.2, 0.2, 0.0)
		frame.add_child(ban_overlay)
		
		vbox.add_child(frame)
		
		# Bottom Label: Actor / Chosen Game
		var lbl_name = Label.new()
		lbl_name.text = str(cfg["actor"])
		lbl_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		lbl_name.add_theme_font_size_override("font_size", 24)
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.clip_text = true
		lbl_name.modulate = Color(0.85, 0.80, 0.70)
		vbox.add_child(lbl_name)
		
		hbox_timeline.add_child(node_box)
		
		# Sleek Connecting Chevron Arrow between cards (1..6)
		var arrow_lbl: Label = null
		if i < TIMELINE_CONFIG.size() - 1:
			var arrow_box = CenterContainer.new()
			arrow_box.custom_minimum_size = Vector2(26, 0)
			arrow_lbl = Label.new()
			arrow_lbl.text = "❯"
			arrow_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
			arrow_lbl.add_theme_font_size_override("font_size", 34)
			arrow_lbl.modulate = Color(0.55, 0.42, 0.24, 0.75)
			arrow_box.add_child(arrow_lbl)
			hbox_timeline.add_child(arrow_box)
		
		timeline_nodes[t_num] = {
			"box": node_box,
			"style": sb,
			"frame": frame,
			"frame_style": frame_sb,
			"img": img_rect,
			"ban_overlay": ban_overlay,
			"name_lbl": lbl_name,
			"tag_lbl": lbl_tag,
			"chip_panel": chip_panel,
			"chip_style": chip_sb,
			"arrow": arrow_lbl,
			"config": cfg,
			"completed": false
		}

func _build_games_grid() -> void:
	for child in games_grid.get_children():
		child.queue_free()
	game_card_nodes.clear()
	
	for g_type in TWO_PLAYER_GAMES:
		var card = _create_game_card(g_type)
		games_grid.add_child(card)
		game_card_nodes[g_type] = card

func _create_game_card(g_type: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(310, 285)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.07, 0.95)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.48, 0.36, 0.22, 0.85)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	card.add_theme_stylebox_override("panel", sb)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	
	# Game Artwork
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(0, 195)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.texture = _load_game_texture(g_type)
	vbox.add_child(img)
	
	# Bottom info strip
	var hbox_info = HBoxContainer.new()
	hbox_info.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox_info)
	
	var lbl_name = Label.new()
	lbl_name.text = GameTypes.get_display_name_fa(g_type)
	lbl_name.theme = load("res://themes/main_theme.tres") if ResourceLoader.exists("res://themes/main_theme.tres") else null
	lbl_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_name.add_theme_font_size_override("font_size", 25)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	hbox_info.add_child(lbl_name)
	
	# Status Badge
	var lbl_badge = Label.new()
	lbl_badge.text = "قابل انتخاب"
	lbl_badge.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_badge.add_theme_font_size_override("font_size", 17)
	lbl_badge.modulate = Color(0.4, 0.9, 0.5)
	vbox.add_child(lbl_badge)
	lbl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Transparent Click Button
	var btn_tap = Button.new()
	btn_tap.flat = true
	btn_tap.anchors_preset = Control.PRESET_FULL_RECT
	btn_tap.anchor_right = 1.0
	btn_tap.anchor_bottom = 1.0
	btn_tap.pressed.connect(_on_game_card_pressed.bind(g_type))
	card.add_child(btn_tap)
	
	card.set_meta("game_type", g_type)
	card.set_meta("style", sb)
	card.set_meta("badge", lbl_badge)
	card.set_meta("img", img)
	card.set_meta("btn", btn_tap)
	card.set_meta("state", "available")
	
	return card

# ==============================================================================
# CARD INTERACTIONS & TIMELINE UPDATES
# ==============================================================================

func _on_game_card_pressed(game_type: String) -> void:
	if not is_my_turn:
		return
	if not game_card_nodes.has(game_type):
		return
		
	var card = game_card_nodes[game_type]
	if str(card.get_meta("state", "")) != "available":
		return
		
	AudioManager.play_sound("tap_button")
	currently_selected_card_game = game_type
	
	# Refresh borders for all cards
	for g in game_card_nodes.keys():
		var c = game_card_nodes[g]
		var sb: StyleBoxFlat = c.get_meta("style")
		var st = str(c.get_meta("state", ""))
		if st == "available":
			if g == currently_selected_card_game:
				sb.border_color = Color(1.0, 0.84, 0.2, 1.0) # Golden selection glow
				sb.border_width_left = 4
				sb.border_width_top = 4
				sb.border_width_right = 4
				sb.border_width_bottom = 4
				var b_lbl: Label = c.get_meta("badge")
				b_lbl.text = "✓ آماده تایید"
				b_lbl.modulate = Color(1.0, 0.85, 0.2)
				
				# Punch scale tween
				var tw = create_tween()
				tw.tween_property(c, "scale", Vector2(1.04, 1.04), 0.08)
				tw.tween_property(c, "scale", Vector2(1.0, 1.0), 0.08)
			else:
				sb.border_color = Color(0.48, 0.36, 0.22, 0.85)
				sb.border_width_left = 3
				sb.border_width_top = 3
				sb.border_width_right = 3
				sb.border_width_bottom = 3
				var b_lbl: Label = c.get_meta("badge")
				b_lbl.text = "قابل انتخاب"
				b_lbl.modulate = Color(0.4, 0.9, 0.5)

	lbl_selected_game.text = "بازی انتخاب‌شده: %s" % GameTypes.get_display_name_fa(game_type)
	btn_confirm.disabled = false

func _on_confirm_pressed() -> void:
	if not is_my_turn or currently_selected_card_game.is_empty():
		return
		
	btn_confirm.disabled = true
	btn_confirm.text = "در حال ارسال انتخاب..."
	AudioManager.play_sound("tap_button")
	
	print("[PickBan] User confirmed selection: %s for turn %d" % [currently_selected_card_game, turn_index])
	NetworkManager.send_pre_game_select(pre_game_id, currently_selected_card_game)

func _update_timeline_active_step(active_step_num: int) -> void:
	for t_num in timeline_nodes.keys():
		var node_data = timeline_nodes[t_num]
		var sb: StyleBoxFlat = node_data["style"]
		var frame_sb: StyleBoxFlat = node_data.get("frame_style")
		var node_box: PanelContainer = node_data["box"]
		var cfg = node_data["config"]
		var is_comp = bool(node_data["completed"])
		
		if is_comp:
			continue
			
		if t_num == active_step_num:
			# Active glowing step!
			sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
			sb.set_border_width_all(4)
			sb.bg_color = Color(0.24, 0.16, 0.08, 0.98)
			sb.shadow_color = Color(1.0, 0.85, 0.2, 0.45)
			sb.shadow_size = 14
			
			if frame_sb:
				frame_sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
				frame_sb.set_border_width_all(3)
			
			var name_lbl: Label = node_data["name_lbl"]
			name_lbl.text = "⏳ در حال درفت..."
			name_lbl.modulate = Color(1.0, 0.88, 0.3)
			
			var img: TextureRect = node_data["img"]
			img.modulate = Color(0.85, 0.85, 0.85, 0.55)
			
			# Pulse animation
			var tw = create_tween().set_loops(4)
			tw.tween_property(node_box, "modulate", Color(1.15, 1.15, 1.15), 0.45)
			tw.tween_property(node_box, "modulate", Color(1.0, 1.0, 1.0), 0.45)
			
			# Ensure active node is scrolled into view
			if is_instance_valid(scroll_timeline):
				scroll_timeline.ensure_control_visible(node_box)
		else:
			sb.border_color = Color(0.40, 0.30, 0.18, 0.6)
			sb.set_border_width_all(2)
			sb.bg_color = Color(0.12, 0.08, 0.06, 0.92)
			sb.shadow_color = Color(0, 0, 0, 0.4)
			sb.shadow_size = 4
			if frame_sb:
				frame_sb.border_color = Color(0.35, 0.25, 0.16, 0.6)
				frame_sb.set_border_width_all(2)
			var img: TextureRect = node_data["img"]
			img.modulate = Color(0.4, 0.4, 0.4, 0.25)

func _apply_game_selection(step_num: int, game_type: String) -> void:
	if not timeline_nodes.has(step_num):
		return
		
	var node_data = timeline_nodes[step_num]
	node_data["completed"] = true
	var sb: StyleBoxFlat = node_data["style"]
	var frame_sb: StyleBoxFlat = node_data.get("frame_style")
	var img: TextureRect = node_data["img"]
	var ban_overlay: Label = node_data.get("ban_overlay")
	var name_lbl: Label = node_data["name_lbl"]
	var tag_lbl: Label = node_data["tag_lbl"]
	var chip_sb: StyleBoxFlat = node_data.get("chip_style")
	var arrow: Label = node_data.get("arrow")
	var cfg = node_data["config"]
	var t_type = str(cfg["type"])
	
	img.texture = _load_game_texture(game_type)
	name_lbl.text = GameTypes.get_display_name_fa(game_type)
	name_lbl.modulate = Color(1, 1, 1)
	
	if is_instance_valid(arrow):
		arrow.modulate = Color(1.0, 0.85, 0.35, 1.0)
	
	if t_type == "ban":
		sb.border_color = Color(0.95, 0.25, 0.25, 0.95)
		sb.set_border_width_all(3)
		sb.bg_color = Color(0.24, 0.06, 0.06, 0.96)
		sb.shadow_color = Color(0.85, 0.15, 0.15, 0.4)
		sb.shadow_size = 10
		
		if frame_sb:
			frame_sb.border_color = Color(0.90, 0.20, 0.20, 0.95)
			frame_sb.bg_color = Color(0.20, 0.04, 0.04, 0.95)
		
		img.modulate = Color(0.65, 0.35, 0.35, 0.85)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1.0, 0.25, 0.25, 0.95)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.45, 0.08, 0.08, 0.95)
			chip_sb.border_color = Color(1.0, 0.3, 0.3, 1.0)
		tag_lbl.text = "🚫 بن شد"
		tag_lbl.modulate = Color(1.0, 0.4, 0.4)
		_mark_card_banned(game_type, "🚫 حذف توسط بازیکن")
	elif t_type == "sys_pick":
		sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
		sb.set_border_width_all(4)
		sb.bg_color = Color(0.22, 0.16, 0.06, 0.96)
		sb.shadow_color = Color(1.0, 0.85, 0.2, 0.45)
		sb.shadow_size = 12
		
		if frame_sb:
			frame_sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
			frame_sb.bg_color = Color(0.14, 0.10, 0.04, 0.95)
		
		img.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1, 1, 1, 0.0)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.40, 0.30, 0.08, 0.95)
			chip_sb.border_color = Color(1.0, 0.88, 0.3, 1.0)
		tag_lbl.text = "🎲 بازی ۳ (سیستم)"
		tag_lbl.modulate = Color(1.0, 0.88, 0.3)
		_mark_card_picked(game_type, "🎲 بازی ۳ (سیستم)")
	else:
		var p_label = "🎯 بازی ۱" if step_num == 3 else "🎯 بازی ۲"
		sb.border_color = Color(0.25, 0.95, 0.55, 1.0)
		sb.set_border_width_all(4)
		sb.bg_color = Color(0.06, 0.20, 0.12, 0.96)
		sb.shadow_color = Color(0.25, 0.95, 0.5, 0.45)
		sb.shadow_size = 12
		
		if frame_sb:
			frame_sb.border_color = Color(0.25, 0.95, 0.55, 1.0)
			frame_sb.bg_color = Color(0.04, 0.12, 0.08, 0.95)
		
		img.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1, 1, 1, 0.0)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.08, 0.35, 0.18, 0.95)
			chip_sb.border_color = Color(0.35, 0.95, 0.55, 1.0)
		tag_lbl.text = p_label
		tag_lbl.modulate = Color(0.35, 0.95, 0.6)
		_mark_card_picked(game_type, p_label)
		
	if available_games.has(game_type):
		available_games.remove_at(available_games.find(game_type))
		
	_play_selection_vfx(game_type, t_type, step_num)

func _play_selection_vfx(game_type: String, t_type: String, step_num: int) -> void:
	# 1. Timeline Node Glow and Scale Bounce
	if timeline_nodes.has(step_num):
		var node_box: Control = timeline_nodes[step_num]["box"]
		node_box.pivot_offset = node_box.size * 0.5
		var tw_tl = create_tween()
		tw_tl.tween_property(node_box, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_tl.tween_property(node_box, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# 2. Game Card Punch Scale & Slamming VFX Stamp
	if not game_card_nodes.has(game_type):
		return
		
	var card: Control = game_card_nodes[game_type]
	card.pivot_offset = card.size * 0.5
	
	var tw_card = create_tween()
	tw_card.tween_property(card, "scale", Vector2(1.10, 1.10), 0.10)
	tw_card.tween_property(card, "scale", Vector2(1.0, 1.0), 0.16)
	
	# Animated Impact Stamp Badge
	var stamp = Label.new()
	stamp.text = "🚫 BAN شد" if t_type == "ban" else ("🎯 انتخاب شد" if t_type == "pick" else "🎲 انتخاب سیستم")
	stamp.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	stamp.add_theme_font_size_override("font_size", 28)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.custom_minimum_size = Vector2(210, 62)
	stamp.size = Vector2(210, 62)
	stamp.position = (card.size - stamp.size) * 0.5
	stamp.pivot_offset = stamp.size * 0.5
	
	var stamp_sb = StyleBoxFlat.new()
	if t_type == "ban":
		stamp_sb.bg_color = Color(0.85, 0.12, 0.12, 0.96)
		stamp_sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
	else:
		stamp_sb.bg_color = Color(0.12, 0.75, 0.35, 0.96)
		stamp_sb.border_color = Color(1.0, 0.90, 0.30, 1.0)
	stamp_sb.set_border_width_all(3)
	stamp_sb.set_corner_radius_all(12)
	stamp_sb.shadow_color = Color(0, 0, 0, 0.65)
	stamp_sb.shadow_size = 10
	stamp.add_theme_stylebox_override("panel", stamp_sb)
	
	card.add_child(stamp)
	
	stamp.scale = Vector2(2.4, 2.4)
	stamp.rotation = -0.18 if t_type == "ban" else 0.14
	stamp.modulate.a = 0.0
	
	var tw_stamp = create_tween()
	tw_stamp.tween_property(stamp, "modulate:a", 1.0, 0.06)
	tw_stamp.parallel().tween_property(stamp, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_stamp.tween_interval(0.65)
	tw_stamp.tween_property(stamp, "modulate:a", 0.0, 0.25)
	tw_stamp.tween_callback(func():
		if is_instance_valid(stamp):
			stamp.queue_free()
	)
	
	if t_type == "ban":
		AudioManager.play_sound("countdown")
	else:
		AudioManager.play_sound("win")

func _mark_card_banned(game_type: String, reason: String) -> void:
	if not game_card_nodes.has(game_type):
		return
	var card = game_card_nodes[game_type]
	card.set_meta("state", "banned")
	var sb: StyleBoxFlat = card.get_meta("style")
	sb.border_color = Color(0.7, 0.2, 0.2, 0.8)
	sb.bg_color = Color(0.15, 0.05, 0.05, 0.9)
	var badge: Label = card.get_meta("badge")
	badge.text = reason
	badge.modulate = Color(1.0, 0.35, 0.35)
	var img: TextureRect = card.get_meta("img")
	img.modulate = Color(0.4, 0.4, 0.4, 0.6)
	var btn: Button = card.get_meta("btn")
	btn.disabled = true

func _mark_card_picked(game_type: String, series_title: String) -> void:
	if not game_card_nodes.has(game_type):
		return
	var card = game_card_nodes[game_type]
	card.set_meta("state", "picked")
	var sb: StyleBoxFlat = card.get_meta("style")
	sb.border_color = Color(0.25, 0.9, 0.5, 0.95)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.bg_color = Color(0.08, 0.18, 0.12, 0.95)
	var badge: Label = card.get_meta("badge")
	badge.text = series_title
	badge.modulate = Color(0.35, 0.95, 0.6)
	var btn: Button = card.get_meta("btn")
	btn.disabled = true

# ==============================================================================
# NETWORK EVENT HANDLERS
# ==============================================================================

func _on_system_banned_games_received(banned_games: Array) -> void:
	print("[PickBan] System banned 3 games: %s" % str(banned_games))
	system_banned = banned_games.duplicate()
	
	if system_banned.size() > 0:
		lbl_sys_ban1.text = "🚫 %s" % GameTypes.get_display_name_fa(str(system_banned[0]))
		_mark_card_banned(str(system_banned[0]), "🚫 حذف خودکار سیستم")
	if system_banned.size() > 1:
		lbl_sys_ban2.text = "🚫 %s" % GameTypes.get_display_name_fa(str(system_banned[1]))
		_mark_card_banned(str(system_banned[1]), "🚫 حذف خودکار سیستم")
	if system_banned.size() > 2:
		lbl_sys_ban3.text = "🚫 %s" % GameTypes.get_display_name_fa(str(system_banned[2]))
		_mark_card_banned(str(system_banned[2]), "🚫 حذف خودکار سیستم")
		
	for g in system_banned:
		if available_games.has(g):
			available_games.remove_at(available_games.find(g))
			
	lbl_status.text = "سیستم ۳ بازی را حذف کرد. آغاز نوبت‌های بن و پیک بازیکنان..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)

func _on_select_game_turn(active_user_id: String) -> void:
	turn_index += 1
	active_turn_user_id = active_user_id
	is_my_turn = (active_user_id == my_user_id)
	currently_selected_card_game = ""
	lbl_selected_game.text = "بازی انتخاب‌شده: —"
	
	_update_timeline_active_step(turn_index)
	_update_turn_ui()
	_start_timer(20.0)

func _update_turn_ui() -> void:
	var is_ban_turn = turn_index in [1, 2, 5, 6]
	var action_fa = "حذف کنید (BAN)" if is_ban_turn else "انتخاب کنید (PICK)"
	
	if is_my_turn:
		AudioManager.play_sound("countdown")
		if is_ban_turn:
			lbl_status.text = "🚫 نوبت شماست: یک بازی را برای حذف انتخاب کنید (BAN)"
			lbl_status.modulate = Color(1.0, 0.45, 0.45)
			btn_confirm.text = "🚫 تایید حذف این بازی"
			KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_RED)
		else:
			lbl_status.text = "🎯 نوبت شماست: بازی مورد نظر برای مسابقه را انتخاب کنید (PICK)"
			lbl_status.modulate = Color(0.35, 0.95, 0.55)
			btn_confirm.text = "🎯 تایید انتخاب برای مسابقه"
			KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_GREEN)
		btn_confirm.disabled = true
	else:
		var opp_name = str(p2_data.get("name", "حریف")) if my_player_index == 1 else str(p1_data.get("name", "حریف"))
		lbl_status.text = "⏳ نوبت %s: در حال تفکر و انتخاب..." % opp_name
		lbl_status.modulate = Color(1.0, 0.84, 0.3)
		btn_confirm.text = "در انتظار نوبت حریف..."
		KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_GREY)
		btn_confirm.disabled = true
		
	# Highlight active player card
	var active_p_num = 1 if turn_index in [1, 3, 5] else 2
	_highlight_active_player(active_p_num)

func _highlight_active_player(p_num: int) -> void:
	var sb1: StyleBoxFlat = p1_card.get_theme_stylebox("panel")
	var sb2: StyleBoxFlat = p2_card.get_theme_stylebox("panel")
	if not sb1 or not sb2:
		return
		
	if p_num == 1:
		sb1.border_color = Color(1.0, 0.84, 0.2, 1.0)
		sb1.border_width_left = 4
		sb1.border_width_top = 4
		sb1.border_width_right = 4
		sb1.border_width_bottom = 4
		sb2.border_color = Color(0.5, 0.38, 0.22, 0.8)
		sb2.border_width_left = 3
		sb2.border_width_top = 3
		sb2.border_width_right = 3
		sb2.border_width_bottom = 3
	else:
		sb2.border_color = Color(1.0, 0.84, 0.2, 1.0)
		sb2.border_width_left = 4
		sb2.border_width_top = 4
		sb2.border_width_right = 4
		sb2.border_width_bottom = 4
		sb1.border_color = Color(0.5, 0.38, 0.22, 0.8)
		sb1.border_width_left = 3
		sb1.border_width_top = 3
		sb1.border_width_right = 3
		sb1.border_width_bottom = 3

func _on_selected_game_received(active_index: int, game_type: String) -> void:
	print("[PickBan] Turn %d result: %s" % [active_index, game_type])
	_apply_game_selection(active_index, game_type)
	
	if active_index == 3:
		p1_picked = game_type
	elif active_index == 4:
		p2_picked = game_type
	elif active_index == 7:
		system_picked = game_type
		lbl_status.text = "✅ تمام مراحل درفت تکمیل شد! در حال آماده‌سازی بازی اول..."
		lbl_status.modulate = Color(0.35, 0.95, 0.55)
		_show_draft_complete_transition()

func _on_queue_start_game_received(game_id: String) -> void:
	print("[PickBan] Server Start_Game received on /queue. Match Game ID: %s. Leaving Pick & Ban..." % game_id)
	_stop_timer()
	if not game_id.is_empty():
		GameManager.set_active_game(game_id)
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
		reconnect_timeout_timer = null
		
	var first_game = p1_picked if not p1_picked.is_empty() else (available_games[0] if not available_games.is_empty() else "TicTacToe")
	
	# Smooth fade out transition directly into 3D gameplay
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func():
		if is_instance_valid(draft_showcase_overlay):
			draft_showcase_overlay.queue_free()
			draft_showcase_overlay = null
		visible = false
		pick_ban_finished.emit(game_id, first_game)
	)

func _show_draft_complete_transition() -> void:
	if is_instance_valid(draft_showcase_overlay):
		return
		
	AudioManager.play_sound("win")
	
	var overlay = Control.new()
	overlay.name = "DraftShowcaseOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	
	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.06, 0.04, 0.03, 0.96)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 840)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.06, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.25, 0.95)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Header
	var lbl_h = Label.new()
	lbl_h.text = "👑 درفت مسابقه تکمیل شد! 👑"
	lbl_h.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_h.add_theme_font_size_override("font_size", 40)
	lbl_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_h.modulate = Color(1.0, 0.88, 0.3)
	vbox.add_child(lbl_h)
	
	var lbl_sub = Label.new()
	lbl_sub.text = "سری مسابقات ۳ بازی نهایی (Best of 3):"
	lbl_sub.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_sub.add_theme_font_size_override("font_size", 26)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.modulate = Color(0.85, 0.78, 0.65)
	vbox.add_child(lbl_sub)
	
	# 3 Game Cards Row
	var hbox_games = HBoxContainer.new()
	hbox_games.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_games.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox_games)
	
	var g1 = p1_picked if not p1_picked.is_empty() else "TicTacToe"
	var g2 = p2_picked if not p2_picked.is_empty() else "Chess"
	var g3 = system_picked if not system_picked.is_empty() else "Sudoku"
	
	var games_list = [
		{"title": "🎯 بازی ۱ (پیک ب ۱)", "game": g1},
		{"title": "🎯 بازی ۲ (پیک ب ۲)", "game": g2},
		{"title": "🎲 بازی ۳ (پیک سیستم)", "game": g3}
	]
	
	for g_info in games_list:
		var g_card = PanelContainer.new()
		g_card.custom_minimum_size = Vector2(280, 360)
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.18, 0.12, 0.08, 0.95)
		c_sb.border_color = Color(0.65, 0.50, 0.28, 0.9)
		c_sb.set_border_width_all(3)
		c_sb.set_corner_radius_all(16)
		g_card.add_theme_stylebox_override("panel", c_sb)
		
		var c_margin = MarginContainer.new()
		c_margin.add_theme_constant_override("margin_left", 12)
		c_margin.add_theme_constant_override("margin_top", 14)
		c_margin.add_theme_constant_override("margin_right", 12)
		c_margin.add_theme_constant_override("margin_bottom", 14)
		g_card.add_child(c_margin)
		
		var c_vbox = VBoxContainer.new()
		c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		c_vbox.add_theme_constant_override("separation", 10)
		c_margin.add_child(c_vbox)
		
		var c_tag = Label.new()
		c_tag.text = g_info["title"]
		c_tag.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		c_tag.add_theme_font_size_override("font_size", 20)
		c_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_tag.modulate = Color(1.0, 0.85, 0.35)
		c_vbox.add_child(c_tag)
		
		var c_img = TextureRect.new()
		c_img.custom_minimum_size = Vector2(240, 200)
		c_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		c_img.texture = _load_game_texture(str(g_info["game"]))
		c_vbox.add_child(c_img)
		
		var c_name = Label.new()
		c_name.text = GameTypes.get_display_name_fa(str(g_info["game"]))
		c_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		c_name.add_theme_font_size_override("font_size", 24)
		c_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_name.modulate = Color(1, 1, 1)
		c_vbox.add_child(c_name)
		
		hbox_games.add_child(g_card)
		
	# Loading / Transition Status
	var lbl_loading = Label.new()
	lbl_loading.text = "⚡ در حال راه‌اندازی راند اول مسابقه..."
	lbl_loading.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_loading.add_theme_font_size_override("font_size", 28)
	lbl_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_loading.modulate = Color(0.35, 0.95, 0.55)
	vbox.add_child(lbl_loading)
	
	add_child(overlay)
	draft_showcase_overlay = overlay
	
	# Entrance punch animation
	overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.28)

func _on_start_game_received() -> void:
	# In-game Start_Game signal is ignored by Pick & Ban (only /queue Start_Game controls draft)
	pass

func _on_queue_game_finished() -> void:
	print("[PickBan] Game_Finished received on /queue. Showing finished notice...")
	_stop_timer()
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
		reconnect_timeout_timer = null
	show_game_finished_dialog("این بازی به پایان رسیده است.")

func _on_game_canceled() -> void:
	print("[PickBan] Match draft cancelled.")
	_stop_timer()
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
		reconnect_timeout_timer = null
	show_game_finished_dialog("مسابقه توسط سرور یا حریف لغو گردید.")

func show_game_finished_dialog(message: String = "این بازی به پایان رسیده است.") -> void:
	if is_match_active():
		print("[PickBan] Suppressed show_game_finished_dialog(): Game match is already active.")
		visible = false
		return
	_stop_timer()
	if is_instance_valid(reconnect_timeout_timer):
		reconnect_timeout_timer.stop()
		reconnect_timeout_timer.queue_free()
		reconnect_timeout_timer = null
		
	if is_instance_valid(game_finished_modal):
		game_finished_modal.queue_free()
		game_finished_modal = null
		
	visible = true
	modulate.a = 1.0
	
	# Full-screen modal overlay
	var overlay = Control.new()
	overlay.name = "GameFinishedModal"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	
	# Backdrop Dim
	var bg_dim = ColorRect.new()
	bg_dim.anchors_preset = Control.PRESET_FULL_RECT
	bg_dim.anchor_right = 1.0
	bg_dim.anchor_bottom = 1.0
	bg_dim.color = Color(0.04, 0.02, 0.02, 0.88)
	overlay.add_child(bg_dim)
	
	# Center Panel Container
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 420)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.07, 0.98)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.85, 0.40, 0.25, 0.95)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Icon & Title
	var lbl_modal_title = Label.new()
	lbl_modal_title.text = "⚠️ وضعیت مسابقه"
	lbl_modal_title.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_modal_title.add_theme_font_size_override("font_size", 34)
	lbl_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_modal_title.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(lbl_modal_title)
	
	# Body Message
	var lbl_msg = Label.new()
	lbl_msg.text = message
	lbl_msg.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_msg.add_theme_font_size_override("font_size", 26)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.modulate = Color(1.0, 0.92, 0.85)
	vbox.add_child(lbl_msg)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Action Button: Return to Menu
	var btn_return = Button.new()
	btn_return.text = "بازگشت به منوی اصلی"
	btn_return.custom_minimum_size = Vector2(340, 72)
	btn_return.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	btn_return.add_theme_font_size_override("font_size", 28)
	KenneyUI.style_button(btn_return, KenneyUI.COLOR_GREEN)
	btn_return.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_return.pressed.connect(_on_modal_close_pressed)
	vbox.add_child(btn_return)
	
	add_child(overlay)
	game_finished_modal = overlay
	
	# Entrance punch animation
	overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)

func _on_modal_close_pressed() -> void:
	AudioManager.play_sound("tap_button")
	if is_instance_valid(game_finished_modal):
		game_finished_modal.queue_free()
		game_finished_modal = null
	
	GameManager.clear_open_pre_game_id()
	GameManager.clear_open_game_id()
	NetworkManager.leave_matchmaking_queue()
	
	visible = false
	pick_ban_cancelled.emit()

# ==============================================================================
# DISCONNECT / RECONNECT HANDLING
# ==============================================================================

func show_opponent_disconnected(user_id: String, wait_time: int) -> void:
	print("[PickBan] Opponent disconnected (%s). Pausing draft for %ds..." % [user_id, wait_time])
	is_timer_active = false
	dc_time_left = float(wait_time)
	is_dc_active = true
	disconnect_banner.visible = true
	lbl_disconnect.text = "⚠️ ارتباط حریف قطع شد. زمان انتظار برای اتصال مجدد:"
	lbl_dc_timer.text = "%ds" % wait_time
	btn_confirm.disabled = true

func show_opponent_reconnected(user_id: String, remaining_time: int) -> void:
	print("[PickBan] Opponent reconnected (%s). Resuming draft with %ds..." % [user_id, remaining_time])
	is_dc_active = false
	disconnect_banner.visible = true
	lbl_disconnect.text = "✅ حریف مجدداً متصل شد! ادامه درفت..."
	lbl_disconnect.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	lbl_dc_timer.text = ""
	
	_start_timer(float(remaining_time))
	
	var tw = create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func():
		disconnect_banner.visible = false
		lbl_disconnect.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	)

# ==============================================================================
# HELPERS
# ==============================================================================

func _start_timer(seconds: float) -> void:
	turn_time_left = seconds
	turn_total_time = seconds
	is_timer_active = true
	turn_timer_bar.value = 100.0

func _stop_timer() -> void:
	is_timer_active = false

func _load_avatar_texture(avatar_id: int) -> Texture2D:
	var path = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(path):
		return load(path)
	var fallback = "res://assets/icons/Avatars/0.png"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null

func _load_game_texture(game_type: String) -> Texture2D:
	var clean = game_type.to_lower().strip_edges()
	var path = "res://assets/images/games/%s.jpg" % clean
	if ResourceLoader.exists(path):
		return load(path)
	var fallback = "res://assets/images/games/tictactoe.jpg"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null
