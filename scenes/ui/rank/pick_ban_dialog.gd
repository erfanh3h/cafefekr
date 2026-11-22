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
@onready var status_panel: PanelContainer = $Margin/VBox/Header/StatusPanel
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
@onready var p1_score: Label = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/P1ScoreBox/P1Score
@onready var p1_role: Label = $Margin/VBox/PlayersStrip/P1Card/MarginP1/HBoxP1/VBoxP1/P1Role

@onready var lbl_vs: Label = $Margin/VBox/PlayersStrip/CenterVS/LblVS
@onready var lbl_series: Label = $Margin/VBox/PlayersStrip/CenterVS/LblSeries

@onready var p2_card: PanelContainer = $Margin/VBox/PlayersStrip/P2Card
@onready var p2_avatar: TextureRect = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/P2Avatar
@onready var p2_name: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/VBoxP2/P2Name
@onready var p2_score: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/P2ScoreBox/P2Score
@onready var p2_role: Label = $Margin/VBox/PlayersStrip/P2Card/MarginP2/HBoxP2/VBoxP2/P2Role

# Timeline
@onready var scroll_timeline: ScrollContainer = $Margin/VBox/TimelinePanel/MarginTimeline/VBoxTimeline/ScrollTimeline
@onready var hbox_timeline: HBoxContainer = $Margin/VBox/TimelinePanel/MarginTimeline/VBoxTimeline/ScrollTimeline/HBoxTimeline

# System Bans
@onready var lbl_sys_ban1: Label = $Margin/VBox/SystemBansStrip/SysBanChip1/Margin/LblSysBan1
@onready var lbl_sys_ban2: Label = $Margin/VBox/SystemBansStrip/SysBanChip2/Margin/LblSysBan2
@onready var lbl_sys_ban3: Label = $Margin/VBox/SystemBansStrip/SysBanChip3/Margin/LblSysBan3

# Games Grid
@onready var scroll_games: ScrollContainer = $Margin/VBox/GamesScroll
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
var system_ban_nodes: Array = [] # 3 system-removed game cards at the start of top header
var reconnect_timeout_timer: Timer = null
var game_finished_modal: Control = null
var draft_showcase_overlay: Control = null
var _timeline_pulse_tween: Tween = null

const TWO_PLAYER_GAMES = [
	"TicTacToe", "RPC", "DotBox", "MNumbers", "MSweeper",
	"FekrBekr", "Yatzy", "Pentago", "FourInRow", "Sudoku",
	"BattleShip", "BoxFour", "Yinsh", "Chess", "Checkers",
	"Othello", "Mill", "BackGammon", "Quiz", "Quoridor"
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
	if is_instance_valid(scroll_games):
		scroll_games.resized.connect(_on_games_scroll_resized)
		var v_sb = scroll_games.get_v_scroll_bar()
		if v_sb:
			v_sb.custom_minimum_size = Vector2(12, 0)
	_connect_network_signals()
	set_process(false)

var _last_timer_sec: int = -1
var _last_dc_sec: int = -1

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
		
	if is_timer_active:
		turn_time_left = max(0.0, turn_time_left - delta)
		turn_timer_bar.value = (turn_time_left / maxf(0.1, turn_total_time)) * 100.0
		var sec_int := int(ceil(turn_time_left))
		if sec_int != _last_timer_sec:
			_last_timer_sec = sec_int
			lbl_turn_timer.text = "⏳ %s ثانیه" % _fa_num(sec_int)
			if sec_int <= 5:
				turn_timer_bar.modulate = Color(1.0, 0.35, 0.35)
				lbl_turn_timer.modulate = Color(1.0, 0.35, 0.35)
				if sec_int > 0 and is_my_turn:
					AudioManager.play_sound("time")
			elif sec_int <= 10:
				turn_timer_bar.modulate = Color(1.0, 0.85, 0.35)
				lbl_turn_timer.modulate = Color(1.0, 0.85, 0.35)
			else:
				turn_timer_bar.modulate = Color(0.35, 0.95, 0.45)
				lbl_turn_timer.modulate = Color(0.35, 0.95, 0.45)

	if is_dc_active:
		dc_time_left = max(0.0, dc_time_left - delta)
		var dc_int := int(ceil(dc_time_left))
		if dc_int != _last_dc_sec:
			_last_dc_sec = dc_int
			lbl_dc_timer.text = "%s ثانیه" % _fa_num(dc_int)
		if dc_time_left <= 0:
			is_dc_active = false
			disconnect_banner.visible = false

func is_match_active() -> bool:
	return GameManager.is_game_active or not GameManager.active_game_id.is_empty() or not GameManager.get_open_game_id().is_empty()

func _connect_network_signals() -> void:
	NetworkManager.pre_game_started.connect(func(_id, _q):
		system_banned.clear()
	)
	NetworkManager.system_banned_games_received.connect(_on_system_banned_games_received)
	NetworkManager.select_game_turn.connect(_on_select_game_turn)
	NetworkManager.selected_game_received.connect(_on_selected_game_received)
	NetworkManager.queue_game_canceled.connect(_on_game_canceled)
	NetworkManager.queue_game_finished.connect(_on_queue_game_finished)
	NetworkManager.queue_start_game_received.connect(_on_queue_start_game_received)

# ==============================================================================
# OPEN / INITIALIZATION
# ==============================================================================

func _is_mobile() -> bool:
	return GameManager.is_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func open(p_pre_game_id: String, queuers: Array) -> void:
	set_process(true)
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
		
	var cached_sys_bans = system_banned.duplicate()
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
	if not cached_sys_bans.is_empty():
		_on_system_banned_games_received(cached_sys_bans)
	
	lbl_status.text = "در حال تحلیل و حذف ۳ بازی توسط سیستم کافه‌فکر..."
	lbl_status.modulate = Color(1.0, 0.88, 0.45)
	lbl_selected_game.text = "بازی انتخاب‌شده: —"
	btn_confirm.disabled = true
	btn_confirm.text = "در انتظار شروع درفت..."
	
	AudioManager.play_queue_music()
	_start_timer(5.0)
	
	visible = true
	call_deferred("_on_games_scroll_resized")
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
	call_deferred("_on_games_scroll_resized")
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
	set_process(true)
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
	
	AudioManager.play_queue_music()
	_update_timeline_active_step(turn_index)
	_update_turn_ui()
	_start_timer(rem_time)
	
	visible = true
	call_deferred("_on_games_scroll_resized")
	modulate.a = 1.0

# ==============================================================================
# UI BUILDERS
# ==============================================================================

func _fa_num(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(str(i), fa[i])
	return s

func _resolve_player_score(p_dict: Dictionary, player_idx: int) -> int:
	if p_dict.has("score") and p_dict["score"] != null:
		return int(p_dict["score"])
	if p_dict.has("user_score") and p_dict["user_score"] != null:
		return int(p_dict["user_score"])
	if player_idx == my_player_index:
		return int(GameManager.get_score())
	return 1000

func _apply_avatar_frame_safe(avatar_rect: TextureRect, frame_id: int, slot_sz: float = 52.0) -> void:
	if not is_instance_valid(avatar_rect):
		return
	var p := avatar_rect.get_parent()
	var slot: Control = null
	if p is Control and p.name.ends_with("_AvatarSlot"):
		slot = p as Control
	elif p is Container:
		var idx := avatar_rect.get_index()
		slot = Control.new()
		slot.name = avatar_rect.name + "_AvatarSlot"
		slot.custom_minimum_size = Vector2(slot_sz, slot_sz)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(slot)
		p.move_child(slot, idx)
		p.remove_child(avatar_rect)
		slot.add_child(avatar_rect)
		avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		slot = p as Control if p is Control else avatar_rect
	CafeSocialTheme.apply_frame_to_container(slot, avatar_rect, frame_id)


func _setup_player_strip() -> void:
	# P1
	var p1_uname = str(p1_data.get("name", p1_data.get("username", "بازیکن ۱")))
	var p1_s = _resolve_player_score(p1_data, 1)
	var p1_img = int(p1_data.get("image", p1_data.get("user_image", p1_data.get("avatar", 0))))
	p1_name.text = p1_uname
	p1_score.text = _fa_num(p1_s)
	p1_avatar.texture = _load_avatar_texture(p1_img)
	var p1_fid = GameManager.get_player_frame_id(p1_data)
	_apply_avatar_frame_safe(p1_avatar, p1_fid, 52.0)
	if my_player_index == 1:
		p1_role.text = "شما"
		p1_role.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	else:
		p1_role.text = "حریف"
		p1_role.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
		
	# P2
	var p2_uname = str(p2_data.get("name", p2_data.get("username", "بازیکن ۲")))
	var p2_s = _resolve_player_score(p2_data, 2)
	var p2_img = int(p2_data.get("image", p2_data.get("user_image", p2_data.get("avatar", 1))))
	p2_name.text = p2_uname
	p2_score.text = _fa_num(p2_s)
	p2_avatar.texture = _load_avatar_texture(p2_img)
	var p2_fid = GameManager.get_player_frame_id(p2_data)
	_apply_avatar_frame_safe(p2_avatar, p2_fid, 52.0)
	if my_player_index == 2:
		p2_role.text = "شما"
		p2_role.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	else:
		p2_role.text = "حریف"
		p2_role.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
		
	lbl_series.text = "۳ بازی"

func _get_step_actor_label(owner_idx: int, _t_type: String) -> String:
	if owner_idx == 0:
		return "قرعه سیستم"
	var is_me = (owner_idx == my_player_index)
	return "نوبت شما" if is_me else "نوبت حریف"

func _build_timeline() -> void:
	if _timeline_pulse_tween and _timeline_pulse_tween.is_valid():
		_timeline_pulse_tween.kill()
	for child in hbox_timeline.get_children():
		child.queue_free()
	timeline_nodes.clear()
	system_ban_nodes.clear()
	
	# Compact 2-tier Timeline (reclaims ~80px for the 3-column game grid!):
	# Tier 1: Slim 32px System-Banned games chip bar
	# Tier 2: Single clean 7-step Draft Row (Ban1, Ban2, Pick1, Pick2, Ban3, Ban4, System Pick)
	var rows_vbox = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 6)
	rows_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_timeline.add_child(rows_vbox)
	
	# Tier 1: Slim System Bans Strip
	var sys_strip = HBoxContainer.new()
	sys_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_strip.add_theme_constant_override("separation", 5)
	sys_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	rows_vbox.add_child(sys_strip)

	var sys_title_lbl = Label.new()
	sys_title_lbl.text = "🚫 حذف سیستم:"
	sys_title_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	sys_title_lbl.add_theme_font_size_override("font_size", 15)
	sys_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62))
	sys_strip.add_child(sys_title_lbl)

	for s_idx in range(3):
		var sys_box = PanelContainer.new()
		sys_box.custom_minimum_size = Vector2(0, 30)
		sys_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sys_sb = StyleBoxFlat.new()
		sys_sb.bg_color = Color(0.20, 0.06, 0.06, 0.88)
		sys_sb.set_border_width_all(1)
		sys_sb.border_color = Color(0.85, 0.28, 0.28, 0.82)
		sys_sb.set_corner_radius_all(8)
		sys_sb.content_margin_left = 6
		sys_sb.content_margin_right = 6
		sys_sb.content_margin_top = 2
		sys_sb.content_margin_bottom = 2
		sys_box.add_theme_stylebox_override("panel", sys_sb)

		var sys_row = HBoxContainer.new()
		sys_row.alignment = BoxContainer.ALIGNMENT_CENTER
		sys_row.add_theme_constant_override("separation", 4)
		sys_box.add_child(sys_row)

		var sys_img = TextureRect.new()
		sys_img.custom_minimum_size = Vector2(22, 22)
		sys_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sys_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sys_img.texture = _load_game_texture("tictactoe")
		sys_img.modulate = Color(0.45, 0.30, 0.30, 0.28)
		sys_row.add_child(sys_img)

		var sys_name = Label.new()
		sys_name.text = "..."
		sys_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sys_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		sys_name.add_theme_font_size_override("font_size", 14)
		sys_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sys_name.clip_text = true
		sys_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sys_name.modulate = Color(1.0, 0.78, 0.78)
		sys_row.add_child(sys_name)

		sys_strip.add_child(sys_box)
		system_ban_nodes.append({
			"box": sys_box,
			"style": sys_sb,
			"frame": null,
			"frame_style": null,
			"img": sys_img,
			"ban_overlay": null,
			"name_lbl": sys_name,
			"tag_lbl": null,
			"chip_style": null
		})

	# Tier 2: Single Linear 7-Step Draft Row
	var row_steps = HBoxContainer.new()
	row_steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_steps.add_theme_constant_override("separation", 4)
	row_steps.alignment = BoxContainer.ALIGNMENT_CENTER
	rows_vbox.add_child(row_steps)
	
	for i in range(TIMELINE_CONFIG.size()):
		var cfg = TIMELINE_CONFIG[i]
		var t_num = int(cfg["turn"])
		var t_type = str(cfg["type"]) # "ban", "pick", "sys_pick"
		var t_owner = int(cfg["owner"]) # 1, 2, 0 (sys)
		
		var node_box = PanelContainer.new()
		node_box.custom_minimum_size = Vector2(0, 84)
		node_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.07, 0.05, 0.80)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.50, 0.38, 0.22, 0.78)
		sb.set_corner_radius_all(10)
		node_box.add_theme_stylebox_override("panel", sb)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 3)
		margin.add_theme_constant_override("margin_top", 3)
		margin.add_theme_constant_override("margin_right", 3)
		margin.add_theme_constant_override("margin_bottom", 3)
		node_box.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		margin.add_child(vbox)
		
		# Top Action Pill
		var chip_panel = PanelContainer.new()
		chip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip_sb = StyleBoxFlat.new()
		chip_sb.set_corner_radius_all(5)
		chip_sb.set_border_width_all(1)
		chip_sb.content_margin_left = 2
		chip_sb.content_margin_right = 2
		chip_sb.content_margin_top = 1
		chip_sb.content_margin_bottom = 1
		
		var lbl_tag = Label.new()
		lbl_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_tag.clip_text = true
		lbl_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_tag.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		lbl_tag.add_theme_font_size_override("font_size", 13)
		lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if t_type == "ban":
			lbl_tag.text = "حذف"
			chip_sb.bg_color = Color(0.32, 0.08, 0.08, 0.90)
			chip_sb.border_color = Color(0.90, 0.32, 0.32, 0.85)
			lbl_tag.modulate = Color(1.0, 0.62, 0.62)
		elif t_type == "sys_pick":
			lbl_tag.text = "بازی ۳"
			chip_sb.bg_color = Color(0.34, 0.24, 0.06, 0.90)
			chip_sb.border_color = Color(1.0, 0.84, 0.28, 0.90)
			lbl_tag.modulate = Color(1.0, 0.88, 0.35)
		else:
			lbl_tag.text = ("بازی ۱" if t_num == 3 else "بازی ۲")
			chip_sb.bg_color = Color(0.08, 0.28, 0.14, 0.90)
			chip_sb.border_color = Color(0.32, 0.92, 0.52, 0.90)
			lbl_tag.modulate = Color(0.45, 0.98, 0.62)
			
		chip_panel.add_theme_stylebox_override("panel", chip_sb)
		chip_panel.add_child(lbl_tag)
		vbox.add_child(chip_panel)
		
		# Center Icon Box (36x36)
		var frame = PanelContainer.new()
		frame.custom_minimum_size = Vector2(36, 36)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var frame_sb = StyleBoxFlat.new()
		frame_sb.bg_color = Color(0.05, 0.03, 0.02, 0.90)
		frame_sb.set_border_width_all(1)
		frame_sb.border_color = Color(0.42, 0.32, 0.20, 0.80)
		frame_sb.set_corner_radius_all(7)
		frame.add_theme_stylebox_override("panel", frame_sb)
		
		var img_rect = TextureRect.new()
		img_rect.custom_minimum_size = Vector2(32, 32)
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_rect.texture = _load_game_texture("tictactoe")
		img_rect.modulate = Color(0.35, 0.35, 0.35, 0.18)
		frame.add_child(img_rect)
		
		var ban_overlay = Label.new()
		ban_overlay.text = "✕"
		ban_overlay.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		ban_overlay.add_theme_font_size_override("font_size", 20)
		ban_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ban_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ban_overlay.modulate = Color(1.0, 0.2, 0.2, 0.0)
		frame.add_child(ban_overlay)
		
		vbox.add_child(frame)
		
		# Bottom Actor / Game Name Label
		var lbl_name = Label.new()
		lbl_name.text = "شما" if t_owner == my_player_index else ("سیستم" if t_owner == 0 else "حریف")
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		lbl_name.add_theme_font_size_override("font_size", 13)
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.clip_text = true
		lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if t_owner == my_player_index:
			lbl_name.modulate = Color(0.45, 0.92, 1.0)
		elif t_owner == 0:
			lbl_name.modulate = Color(1.0, 0.88, 0.45)
		else:
			lbl_name.modulate = Color(0.95, 0.72, 0.65)
		vbox.add_child(lbl_name)
		
		row_steps.add_child(node_box)
		
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
			"arrow": null,
			"config": cfg,
			"completed": false
		}

func _calculate_game_card_height() -> float:
	var total_w := 660.0
	if is_instance_valid(scroll_games) and scroll_games.size.x > 100.0:
		total_w = scroll_games.size.x - 24.0
	elif is_instance_valid(games_grid) and games_grid.size.x > 100.0:
		total_w = games_grid.size.x
	var cols: int = maxi(2, games_grid.columns if is_instance_valid(games_grid) else 3)
	var cell_w := floor((total_w - float((cols - 1) * 10)) / float(cols))
	return clampf(cell_w, 130.0, 230.0)

func _on_games_scroll_resized() -> void:
	var h := _calculate_game_card_height()
	for card in game_card_nodes.values():
		if is_instance_valid(card):
			card.custom_minimum_size = Vector2(0, h)
			card.pivot_offset = Vector2(card.size.x / 2.0, h / 2.0)

func _build_games_grid() -> void:
	for child in games_grid.get_children():
		child.queue_free()
	game_card_nodes.clear()
	games_grid.columns = 3
	
	var initial_h := _calculate_game_card_height()
	for g_type in TWO_PLAYER_GAMES:
		var card = _create_game_card(g_type, initial_h)
		games_grid.add_child(card)
		game_card_nodes[g_type] = card
	call_deferred("_on_games_scroll_resized")

func _create_game_card(g_type: String, initial_h: float = 260.0) -> PanelContainer:
	# 2 games per row with dynamic 1:1 square aspect ratio matching classic_rank_dialog
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, initial_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.pivot_offset = Vector2(initial_h / 2.0, initial_h / 2.0)
	
	card.item_rect_changed.connect(func():
		var w = card.size.x
		if w > 80.0:
			var target_h = floor(w)
			if absf(card.custom_minimum_size.y - target_h) > 2.0:
				card.set_deferred("custom_minimum_size", Vector2(0, target_h))
				card.pivot_offset = Vector2(w / 2.0, target_h / 2.0)
	)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(18)
	sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", sb)
	
	var card_body = Control.new()
	card_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_body)
	
	# 1. Cover artwork (clean 1:1, no dark shadow or backdrop)
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.12, 1.08, 1.02)
	img.texture = _load_game_texture(g_type)
	card_body.add_child(img)
	
	# 2. Ban Cross Overlay (hidden until banned)
	var ban_mark = Label.new()
	ban_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	ban_mark.text = "✕"
	ban_mark.visible = false
	ban_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban_mark.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	ban_mark.add_theme_font_size_override("font_size", 64)
	ban_mark.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22, 0.92))
	ban_mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	ban_mark.add_theme_constant_override("shadow_outline_size", 5)
	card_body.add_child(ban_mark)
	
	# 3. Bottom Difficulty Ribbon Banner with Persian Game Name (matching classic_rank_dialog)
	var name_banner = PanelContainer.new()
	name_banner.anchor_top = 0.72
	name_banner.anchor_right = 1.0
	name_banner.anchor_bottom = 1.0
	name_banner.offset_left = 3.0
	name_banner.offset_right = -3.0
	name_banner.offset_bottom = -3.0
	name_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(g_type, 26.0, 3.0))
	card_body.add_child(name_banner)
	
	var lbl_name = Label.new()
	lbl_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.clip_text = true
	lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_name.text = GameTypes.get_display_name_fa(g_type)
	lbl_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_name.add_theme_font_size_override("font_size", 19)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl_name.add_theme_constant_override("shadow_outline_size", 2)
	name_banner.add_child(lbl_name)
	
	# 4. Top-Right Selection / Picked / Banned Badge (hidden when idle)
	var sel_corner = PanelContainer.new()
	sel_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_corner.visible = false
	sel_corner.anchors_preset = Control.PRESET_TOP_RIGHT
	sel_corner.anchor_left = 1.0
	sel_corner.anchor_right = 1.0
	sel_corner.offset_left = -104
	sel_corner.offset_top = 6
	sel_corner.offset_right = -6
	sel_corner.offset_bottom = 36
	var sel_corner_sb = StyleBoxFlat.new()
	sel_corner_sb.bg_color = Color(0.12, 0.72, 0.34, 0.96)
	sel_corner_sb.set_border_width_all(2)
	sel_corner_sb.border_color = Color(1, 1, 1, 0.92)
	sel_corner_sb.set_corner_radius_all(8)
	sel_corner_sb.content_margin_left = 5
	sel_corner_sb.content_margin_right = 5
	sel_corner.add_theme_stylebox_override("panel", sel_corner_sb)
	
	var lbl_sel_corner = Label.new()
	lbl_sel_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_sel_corner.text = "✓ انتخاب"
	lbl_sel_corner.clip_text = true
	lbl_sel_corner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_sel_corner.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_sel_corner.add_theme_font_size_override("font_size", 15)
	lbl_sel_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sel_corner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sel_corner.add_theme_color_override("font_color", Color(1, 1, 1))
	sel_corner.add_child(lbl_sel_corner)
	card_body.add_child(sel_corner)
	
	# 5. Full-Card Touch/Click Button with Smooth Viewport-Coordinate Drag Scrolling
	var btn_tap = Button.new()
	btn_tap.flat = true
	btn_tap.focus_mode = Control.FOCUS_NONE
	btn_tap.mouse_filter = Control.MOUSE_FILTER_PASS
	btn_tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var drag_state = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	btn_tap.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_games.scroll_vertical if is_instance_valid(scroll_games) else 0
			else:
				var was_dragging = drag_state["dragging"]
				var was_active = drag_state["active"]
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_release = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_release <= 14.0:
						_on_game_card_pressed(g_type)
		elif event is InputEventMouseMotion and drag_state["active"]:
			var dy = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or drag_state["dragging"]:
				drag_state["dragging"] = true
				if is_instance_valid(scroll_games):
					scroll_games.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)
	card_body.add_child(btn_tap)
	
	card.set_meta("game_type", g_type)
	card.set_meta("style", sb)
	card.set_meta("name_lbl", lbl_name)
	card.set_meta("sel_corner", sel_corner)
	card.set_meta("sel_corner_style", sel_corner_sb)
	card.set_meta("sel_corner_lbl", lbl_sel_corner)
	card.set_meta("ban_mark", ban_mark)
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
	
	# Double-tap on already selected card confirms immediately!
	if currently_selected_card_game == game_type and not btn_confirm.disabled:
		_on_confirm_pressed()
		return
		
	AudioManager.play_sound("tap_button")
	currently_selected_card_game = game_type
	_refresh_available_cards_visuals()
	
	var is_ban_turn = turn_index in [1, 2, 5, 6]
	var fa_title = GameTypes.get_display_name_fa(game_type)
	if is_ban_turn:
		btn_confirm.text = "🚫 تایید حذف «%s»" % fa_title
	else:
		btn_confirm.text = "🎯 تایید انتخاب «%s»" % fa_title
	btn_confirm.disabled = false

func _refresh_available_cards_visuals() -> void:
	var is_ban_turn = turn_index in [1, 2, 5, 6]
	for g in game_card_nodes.keys():
		var c: PanelContainer = game_card_nodes[g]
		var sb: StyleBoxFlat = c.get_meta("style")
		var name_lbl: Label = c.get_meta("name_lbl")
		var sel_corner: PanelContainer = c.get_meta("sel_corner")
		var sel_corner_sb: StyleBoxFlat = c.get_meta("sel_corner_style")
		var sel_corner_lbl: Label = c.get_meta("sel_corner_lbl")
		var st = str(c.get_meta("state", ""))
		if st != "available":
			continue
		c.pivot_offset = c.size * 0.5
		if g == currently_selected_card_game:
			sel_corner.visible = true
			if is_ban_turn:
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Color(1.0, 0.35, 0.25, 1.0)
				sb.set_border_width_all(4)
				sb.shadow_size = 0
				sel_corner_sb.bg_color = Color(0.88, 0.18, 0.15, 0.98)
				sel_corner_lbl.text = "✕ حذف"
				name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.80))
			else:
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Color(0.25, 0.98, 0.55, 1.0)
				sb.set_border_width_all(4)
				sb.shadow_size = 0
				sel_corner_sb.bg_color = Color(0.12, 0.72, 0.34, 0.98)
				sel_corner_lbl.text = "✓ انتخاب"
				name_lbl.add_theme_color_override("font_color", Color(0.88, 1.0, 0.92))
			var tw = create_tween()
			tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			sel_corner.visible = false
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(0)
			sb.shadow_size = 0
			name_lbl.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
			c.scale = Vector2.ONE
func _on_confirm_pressed() -> void:
	if not is_my_turn or currently_selected_card_game.is_empty():
		return
		
	btn_confirm.disabled = true
	btn_confirm.text = "در حال ارسال انتخاب..."
	AudioManager.play_sound("tap_button")
	
	print("[PickBan] User confirmed selection: %s for turn %d" % [currently_selected_card_game, turn_index])
	NetworkManager.send_pre_game_select(pre_game_id, currently_selected_card_game)

func _update_timeline_active_step(active_step_num: int) -> void:
	if _timeline_pulse_tween and _timeline_pulse_tween.is_valid():
		_timeline_pulse_tween.kill()
	for t_num in timeline_nodes.keys():
		var node_data = timeline_nodes[t_num]
		var sb: StyleBoxFlat = node_data["style"]
		var frame_sb: StyleBoxFlat = node_data.get("frame_style")
		var node_box: PanelContainer = node_data["box"]
		var cfg = node_data["config"]
		var is_comp = bool(node_data["completed"])
		node_box.modulate = Color(1, 1, 1, 1)
		
		if is_comp:
			continue
			
		if t_num == active_step_num:
			var t_type = str(cfg.get("type", "pick"))
			var active_col = Color(1.0, 0.42, 0.32, 1.0) if t_type == "ban" else Color(1.0, 0.85, 0.25, 1.0)
			sb.border_color = active_col
			sb.set_border_width_all(4)
			sb.bg_color = Color(0.26, 0.10, 0.08, 0.98) if t_type == "ban" else Color(0.24, 0.16, 0.08, 0.98)
			sb.shadow_color = Color(active_col.r, active_col.g, active_col.b, 0.45)
			sb.shadow_size = 0 if _is_mobile() else 12
			
			if frame_sb:
				frame_sb.border_color = active_col
				frame_sb.set_border_width_all(3)
			
			var name_lbl: Label = node_data["name_lbl"]
			var t_owner = int(cfg.get("owner", 0))
			if t_owner == my_player_index:
				name_lbl.text = "⚡ نوبت شما"
				name_lbl.modulate = Color(0.4, 0.98, 1.0)
			else:
				name_lbl.text = "⏳ حریف..."
				name_lbl.modulate = Color(1.0, 0.88, 0.3)
			
			var img: TextureRect = node_data["img"]
			img.modulate = Color(0.85, 0.85, 0.85, 0.55)
			
			# Smooth pulse animation on active step (skipped on mobile to reduce GPU redraws)
			if not _is_mobile():
				_timeline_pulse_tween = create_tween().set_loops()
				_timeline_pulse_tween.tween_property(node_box, "modulate", Color(1.14, 1.14, 1.14), 0.5)
				_timeline_pulse_tween.tween_property(node_box, "modulate", Color(1.0, 1.0, 1.0), 0.5)
			
			# Ensure active node is scrolled into view
			if is_instance_valid(scroll_timeline):
				scroll_timeline.ensure_control_visible(node_box)
		else:
			sb.border_color = Color(0.40, 0.30, 0.18, 0.6)
			sb.set_border_width_all(2)
			sb.bg_color = Color(0.12, 0.08, 0.06, 0.92)
			sb.shadow_color = Color(0, 0, 0, 0.4)
			sb.shadow_size = 0 if _is_mobile() else 4
			if frame_sb:
				frame_sb.border_color = Color(0.35, 0.25, 0.16, 0.6)
				frame_sb.set_border_width_all(2)
			var img: TextureRect = node_data["img"]
			img.modulate = Color(0.4, 0.4, 0.4, 0.22)

func _apply_game_selection(step_num: int, game_type: String) -> void:
	if not timeline_nodes.has(step_num):
		return
		
	var node_data = timeline_nodes[step_num]
	node_data["completed"] = true
	var node_box: PanelContainer = node_data["box"]
	node_box.modulate = Color(1, 1, 1, 1)
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
	var t_owner = int(cfg.get("owner", 0))
	
	img.texture = _load_game_texture(game_type)
	name_lbl.text = GameTypes.get_display_name_fa(game_type)
	name_lbl.modulate = Color(1, 1, 1)
	
	if is_instance_valid(arrow):
		arrow.modulate = Color(1.0, 0.85, 0.35, 1.0)
	
	var actor_short = "شما" if t_owner == my_player_index else "حریف"
	var mobile_mode := _is_mobile()
	if t_type == "ban":
		sb.border_color = Color(0.95, 0.25, 0.25, 0.95)
		sb.set_border_width_all(3)
		sb.bg_color = Color(0.24, 0.06, 0.06, 0.96)
		sb.shadow_color = Color(0.85, 0.15, 0.15, 0.4)
		sb.shadow_size = 0 if mobile_mode else 8
		
		if frame_sb:
			frame_sb.border_color = Color(0.90, 0.20, 0.20, 0.95)
			frame_sb.bg_color = Color(0.20, 0.04, 0.04, 0.95)
		
		img.modulate = Color(0.65, 0.35, 0.35, 0.85)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1.0, 0.25, 0.25, 0.95)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.45, 0.08, 0.08, 0.95)
			chip_sb.border_color = Color(1.0, 0.3, 0.3, 1.0)
		tag_lbl.text = "حذف %s" % actor_short
		tag_lbl.modulate = Color(1.0, 0.55, 0.55)
		_mark_card_banned(game_type, "حذف %s" % actor_short)
	elif t_type == "sys_pick":
		sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
		sb.set_border_width_all(4)
		sb.bg_color = Color(0.22, 0.16, 0.06, 0.96)
		sb.shadow_color = Color(1.0, 0.85, 0.2, 0.45)
		sb.shadow_size = 0 if mobile_mode else 10
		
		if frame_sb:
			frame_sb.border_color = Color(1.0, 0.85, 0.25, 1.0)
			frame_sb.bg_color = Color(0.14, 0.10, 0.04, 0.95)
		
		img.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1, 1, 1, 0.0)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.40, 0.30, 0.08, 0.95)
			chip_sb.border_color = Color(1.0, 0.88, 0.3, 1.0)
		tag_lbl.text = "بازی ۳"
		tag_lbl.modulate = Color(1.0, 0.88, 0.3)
		_mark_card_picked(game_type, "بازی ۳ (سیستم)")
	else:
		var p_label = "بازی ۱ (%s)" % actor_short if step_num == 3 else "بازی ۲ (%s)" % actor_short
		sb.border_color = Color(0.25, 0.95, 0.55, 1.0)
		sb.set_border_width_all(4)
		sb.bg_color = Color(0.06, 0.20, 0.12, 0.96)
		sb.shadow_color = Color(0.25, 0.95, 0.5, 0.45)
		sb.shadow_size = 0 if mobile_mode else 10
		
		if frame_sb:
			frame_sb.border_color = Color(0.25, 0.95, 0.55, 1.0)
			frame_sb.bg_color = Color(0.04, 0.12, 0.08, 0.95)
		
		img.modulate = Color(1, 1, 1, 1)
		if is_instance_valid(ban_overlay):
			ban_overlay.modulate = Color(1, 1, 1, 0.0)
		
		if chip_sb:
			chip_sb.bg_color = Color(0.08, 0.35, 0.18, 0.95)
			chip_sb.border_color = Color(0.35, 0.95, 0.55, 1.0)
		tag_lbl.text = "بازی ۱" if step_num == 3 else "بازی ۲"
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
		tw_tl.tween_property(node_box, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_tl.tween_property(node_box, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# 2. Game Card Punch Scale & Slamming VFX Stamp
	if not game_card_nodes.has(game_type):
		return
		
	var card: Control = game_card_nodes[game_type]
	card.pivot_offset = card.size * 0.5
	
	var tw_card = create_tween()
	tw_card.tween_property(card, "scale", Vector2(1.08, 1.08), 0.10)
	tw_card.tween_property(card, "scale", Vector2(1.0, 1.0), 0.16)
	
	# Animated Impact Stamp Badge (PanelContainer + Label so border/bg/shadow actually render!)
	var stamp = PanelContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.custom_minimum_size = Vector2(156, 44)
	stamp.size = Vector2(156, 44)
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
	stamp_sb.content_margin_left = 10
	stamp_sb.content_margin_right = 10
	stamp_sb.content_margin_top = 4
	stamp_sb.content_margin_bottom = 4
	if not _is_mobile():
		stamp_sb.shadow_color = Color(0, 0, 0, 0.55)
		stamp_sb.shadow_size = 8
	stamp.add_theme_stylebox_override("panel", stamp_sb)
	
	var stamp_lbl = Label.new()
	stamp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_lbl.text = "🚫 حذف شد" if t_type == "ban" else ("🎯 انتخاب شد" if t_type == "pick" else "🎲 انتخاب سیستم")
	stamp_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	stamp_lbl.add_theme_font_size_override("font_size", 20)
	stamp_lbl.add_theme_color_override("font_color", Color.WHITE)
	stamp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(stamp_lbl)
	
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
		AudioManager.play_sound("remove_peace")
	else:
		AudioManager.play_sound("add_peace")

func _mark_card_banned(game_type: String, reason: String) -> void:
	if not game_card_nodes.has(game_type):
		return
	var card: PanelContainer = game_card_nodes[game_type]
	card.set_meta("state", "banned")
	card.scale = Vector2.ONE
	var sel_corner: PanelContainer = card.get_meta("sel_corner")
	var sel_corner_sb: StyleBoxFlat = card.get_meta("sel_corner_style")
	var sel_corner_lbl: Label = card.get_meta("sel_corner_lbl")
	if is_instance_valid(sel_corner):
		sel_corner.visible = true
		sel_corner_sb.bg_color = Color(0.62, 0.12, 0.12, 0.94)
		sel_corner_sb.border_color = Color(1.0, 0.45, 0.45, 0.90)
		sel_corner_lbl.text = reason.replace("🚫 ", "")
	var ban_mark: Label = card.get_meta("ban_mark", null)
	if is_instance_valid(ban_mark):
		ban_mark.visible = true
	var sb: StyleBoxFlat = card.get_meta("style")
	sb.border_color = Color(0.78, 0.22, 0.22, 0.88)
	sb.set_border_width_all(3)
	sb.bg_color = Color(0, 0, 0, 0)
	sb.shadow_size = 0
	var img: TextureRect = card.get_meta("img")
	img.modulate = Color(0.38, 0.30, 0.30, 0.55)
	card.modulate = Color(0.76, 0.72, 0.72, 0.82)
	var btn: Button = card.get_meta("btn")
	btn.disabled = true
	# Auto-sink banned cards to bottom so available games stay right at the top!
	if is_instance_valid(games_grid) and card.get_parent() == games_grid:
		games_grid.move_child(card, games_grid.get_child_count() - 1)

func _mark_card_picked(game_type: String, series_title: String) -> void:
	if not game_card_nodes.has(game_type):
		return
	var card: PanelContainer = game_card_nodes[game_type]
	card.set_meta("state", "picked")
	card.scale = Vector2.ONE
	var sel_corner: PanelContainer = card.get_meta("sel_corner")
	var sel_corner_sb: StyleBoxFlat = card.get_meta("sel_corner_style")
	var sel_corner_lbl: Label = card.get_meta("sel_corner_lbl")
	if is_instance_valid(sel_corner):
		sel_corner.visible = true
		sel_corner_sb.bg_color = Color(0.14, 0.68, 0.34, 0.96)
		sel_corner_sb.border_color = Color(0.75, 1.0, 0.85, 0.95)
		sel_corner_lbl.text = series_title.replace("🎯 ", "").replace("🎲 ", "")
	var sb: StyleBoxFlat = card.get_meta("style")
	sb.border_color = Color(0.28, 0.95, 0.55, 0.98)
	sb.set_border_width_all(4)
	sb.bg_color = Color(0, 0, 0, 0)
	sb.shadow_size = 0
	var btn: Button = card.get_meta("btn")
	btn.disabled = true
	if is_instance_valid(games_grid) and card.get_parent() == games_grid:
		games_grid.move_child(card, games_grid.get_child_count() - 1)

# ==============================================================================
# NETWORK EVENT HANDLERS
# ==============================================================================

func _on_system_banned_games_received(banned_games: Array) -> void:
	print("[PickBan] System banned 3 games: %s" % str(banned_games))
	system_banned = banned_games.duplicate()
	
	for idx in range(min(3, system_banned.size())):
		var g_str = str(system_banned[idx])
		var fa_name = GameTypes.get_display_name_fa(g_str)
		if idx == 0:
			lbl_sys_ban1.text = "🚫 %s" % fa_name
		elif idx == 1:
			lbl_sys_ban2.text = "🚫 %s" % fa_name
		elif idx == 2:
			lbl_sys_ban3.text = "🚫 %s" % fa_name
		_mark_card_banned(g_str, "حذف سیستم")
		
		if idx < system_ban_nodes.size():
			var s_node = system_ban_nodes[idx]
			var s_box: Control = s_node["box"]
			var s_sb: StyleBoxFlat = s_node["style"]
			var s_frame_sb = s_node.get("frame_style", null)
			var s_img: TextureRect = s_node["img"]
			var s_ban_ov = s_node.get("ban_overlay", null)
			var s_name_lbl: Label = s_node["name_lbl"]
			var s_tag_lbl = s_node.get("tag_lbl", null)
			
			s_sb.border_color = Color(0.95, 0.28, 0.28, 0.95)
			s_sb.set_border_width_all(2)
			s_sb.bg_color = Color(0.28, 0.07, 0.07, 0.94)
			
			if s_frame_sb is StyleBoxFlat:
				s_frame_sb.border_color = Color(0.92, 0.22, 0.22, 0.95)
				s_frame_sb.bg_color = Color(0.18, 0.04, 0.04, 0.92)
			
			s_img.texture = _load_game_texture(g_str)
			s_img.modulate = Color(0.92, 0.72, 0.72, 0.95)
			if is_instance_valid(s_ban_ov):
				s_ban_ov.modulate = Color(1.0, 0.25, 0.25, 0.96)
			s_name_lbl.text = fa_name
			s_name_lbl.modulate = Color(1.0, 0.90, 0.90)
			if is_instance_valid(s_tag_lbl):
				s_tag_lbl.text = "حذف %s" % _fa_num(idx + 1)
				s_tag_lbl.modulate = Color(1.0, 0.55, 0.55)
			
			s_box.pivot_offset = s_box.size * 0.5
			var tw_s = create_tween()
			tw_s.tween_property(s_box, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_s.tween_property(s_box, "scale", Vector2(1.0, 1.0), 0.16)
		
	for g in system_banned:
		if available_games.has(g):
			available_games.remove_at(available_games.find(g))
			
	AudioManager.play_sound("remove_peace")
	_start_timer(5.0)
	lbl_status.text = "🚫 ۳ بازی توسط سیستم حذف شد! آغاز نوبت‌های حذف و انتخاب..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)

func _on_select_game_turn(active_user_id: String) -> void:
	turn_index += 1
	active_turn_user_id = active_user_id
	is_my_turn = (active_user_id == my_user_id)
	currently_selected_card_game = ""
	lbl_selected_game.text = "بازی انتخاب‌شده: —"
	lbl_selected_game.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
	
	_update_timeline_active_step(turn_index)
	_update_turn_ui()
	_refresh_available_cards_visuals()
	_start_timer(20.0)

func _update_turn_ui() -> void:
	var is_ban_turn = turn_index in [1, 2, 5, 6]
	var sp_sb := StyleBoxFlat.new()
	sp_sb.set_border_width_all(2)
	sp_sb.set_corner_radius_all(14)
	
	if is_my_turn:
		AudioManager.play_sound("start_turn")
		if is_instance_valid(games_grid):
			games_grid.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if is_ban_turn:
			sp_sb.bg_color = Color(0.32, 0.08, 0.08, 0.95)
			sp_sb.border_color = Color(1.0, 0.38, 0.32, 0.98)
			lbl_status.text = "🚫 نوبت شما: یک بازی را حذف کنید"
			lbl_status.modulate = Color(1.0, 0.82, 0.78)
			btn_confirm.text = "🚫 یک بازی برای حذف انتخاب کنید"
			KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_RED)
		else:
			sp_sb.bg_color = Color(0.08, 0.28, 0.14, 0.95)
			sp_sb.border_color = Color(0.35, 0.96, 0.56, 0.98)
			lbl_status.text = "🎯 نوبت شما: بازی مسابقه را انتخاب کنید"
			lbl_status.modulate = Color(0.84, 1.0, 0.88)
			btn_confirm.text = "🎯 یک بازی برای مسابقه انتخاب کنید"
			KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_GREEN)
		btn_confirm.disabled = true
	else:
		sp_sb.bg_color = Color(0.15, 0.10, 0.06, 0.92)
		sp_sb.border_color = Color(0.78, 0.62, 0.28, 0.88)
		if is_instance_valid(games_grid):
			games_grid.modulate = Color(0.74, 0.74, 0.78, 0.86)
		var opp_name = str(p2_data.get("name", p2_data.get("username", "حریف"))) if my_player_index == 1 else str(p1_data.get("name", p1_data.get("username", "حریف")))
		var action_str = "حذف یک بازی" if is_ban_turn else "انتخاب بازی مسابقه"
		lbl_status.text = "⏳ نوبت %s: در حال %s..." % [opp_name, action_str]
		lbl_status.modulate = Color(1.0, 0.86, 0.38)
		btn_confirm.text = "⏳ منتظر انتخاب %s..." % opp_name
		btn_confirm.disabled = true
	if is_instance_valid(status_panel):
		status_panel.add_theme_stylebox_override("panel", sp_sb)
		
	# Highlight active player card
	var active_p_num = 1 if active_turn_user_id == str(p1_data.get("user_id", "")) else 2
	_highlight_active_player(active_p_num)

func _highlight_active_player(p_num: int) -> void:
	var sb1: StyleBoxFlat = p1_card.get_theme_stylebox("panel")
	var sb2: StyleBoxFlat = p2_card.get_theme_stylebox("panel")
	if not sb1 or not sb2:
		return
		
	if p_num == 1:
		sb1.border_color = Color(1.0, 0.84, 0.2, 1.0)
		sb1.set_border_width_all(4)
		sb2.border_color = Color(0.5, 0.38, 0.22, 0.8)
		sb2.set_border_width_all(3)
	else:
		sb2.border_color = Color(1.0, 0.84, 0.2, 1.0)
		sb2.set_border_width_all(4)
		sb1.border_color = Color(0.5, 0.38, 0.22, 0.8)
		sb1.set_border_width_all(3)

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
	
	# Transition immediately into the Start Game dialog with zero blank fade gap
	if is_instance_valid(draft_showcase_overlay):
		draft_showcase_overlay.queue_free()
		draft_showcase_overlay = null
	modulate.a = 1.0
	visible = false
	pick_ban_finished.emit(game_id, first_game)

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
	bg.color = Color(0.02, 0.02, 0.01, 1.0)
	overlay.add_child(bg)
	
	var bg_tex = TextureRect.new()
	bg_tex.anchors_preset = Control.PRESET_FULL_RECT
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.texture = preload("res://assets/images/pick-ban.png")
	bg_tex.modulate = Color(1, 1, 1, 0.78)
	overlay.add_child(bg_tex)
	
	var outer_margin = MarginContainer.new()
	outer_margin.anchors_preset = Control.PRESET_FULL_RECT
	outer_margin.anchor_right = 1.0
	outer_margin.anchor_bottom = 1.0
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_top", 40)
	outer_margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(outer_margin)
	
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb = StyleBoxTexture.new()
	sb.texture = preload("res://assets/images/frames/dialog_tall.png")
	sb.texture_margin_left = 40.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 60.0
	panel.add_theme_stylebox_override("panel", sb)
	outer_margin.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Header
	var lbl_h = Label.new()
	lbl_h.text = "👑 قرعه‌کشی و انتخاب بازی‌ها تکمیل شد! 👑"
	lbl_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_h.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_h.add_theme_font_size_override("font_size", 26)
	lbl_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_h.modulate = Color(1.0, 0.88, 0.3)
	vbox.add_child(lbl_h)
	
	var lbl_sub = Label.new()
	lbl_sub.text = "ترتیب ۳ بازی مسابقه رنک (بهترین از ۳):"
	lbl_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_sub.add_theme_font_size_override("font_size", 20)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.modulate = Color(0.85, 0.78, 0.65)
	vbox.add_child(lbl_sub)
	
	# 3 Game Cards Row
	var hbox_games = HBoxContainer.new()
	hbox_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_games.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_games.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox_games)
	
	var g1 = p1_picked if not p1_picked.is_empty() else "TicTacToe"
	var g2 = p2_picked if not p2_picked.is_empty() else "Chess"
	var g3 = system_picked if not system_picked.is_empty() else "Sudoku"
	var p1_uname = "شما" if my_player_index == 1 else str(p1_data.get("name", p1_data.get("username", "بازیکن ۱")))
	var p2_uname = "شما" if my_player_index == 2 else str(p2_data.get("name", p2_data.get("username", "بازیکن ۲")))
	
	var games_list = [
		{"title": "🎯 بازی ۱ (%s)" % p1_uname, "game": g1, "accent": Color(0.28, 0.95, 0.55)},
		{"title": "🎯 بازی ۲ (%s)" % p2_uname, "game": g2, "accent": Color(0.35, 0.82, 1.0)},
		{"title": "🎲 بازی ۳ (سیستم)", "game": g3, "accent": Color(1.0, 0.85, 0.30)}
	]
	
	for g_info in games_list:
		var g_card = PanelContainer.new()
		g_card.custom_minimum_size = Vector2(0, 250)
		g_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_sb = StyleBoxFlat.new()
		c_sb.bg_color = Color(0.18, 0.12, 0.08, 0.96)
		c_sb.border_color = g_info["accent"]
		c_sb.set_border_width_all(3)
		c_sb.set_corner_radius_all(16)
		g_card.add_theme_stylebox_override("panel", c_sb)
		
		var c_margin = MarginContainer.new()
		c_margin.add_theme_constant_override("margin_left", 6)
		c_margin.add_theme_constant_override("margin_top", 8)
		c_margin.add_theme_constant_override("margin_right", 6)
		c_margin.add_theme_constant_override("margin_bottom", 8)
		g_card.add_child(c_margin)
		
		var c_vbox = VBoxContainer.new()
		c_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		c_vbox.add_theme_constant_override("separation", 6)
		c_margin.add_child(c_vbox)
		
		var c_tag = Label.new()
		c_tag.text = g_info["title"]
		c_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_tag.clip_text = true
		c_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c_tag.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		c_tag.add_theme_font_size_override("font_size", 16)
		c_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_tag.modulate = g_info["accent"]
		c_vbox.add_child(c_tag)
		
		var c_img = TextureRect.new()
		c_img.custom_minimum_size = Vector2(0, 145)
		c_img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		c_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_img.texture = _load_game_texture(str(g_info["game"]))
		c_vbox.add_child(c_img)
		
		var c_name_banner = PanelContainer.new()
		c_name_banner.custom_minimum_size = Vector2(0, 44)
		c_name_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(str(g_info["game"]), 24.0, 4.0))
		c_vbox.add_child(c_name_banner)
		
		var c_name = Label.new()
		c_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_name.clip_text = true
		c_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		c_name.text = GameTypes.get_display_name_fa(str(g_info["game"]))
		c_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		c_name.add_theme_font_size_override("font_size", 18)
		c_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c_name.modulate = Color(1, 1, 1)
		c_name_banner.add_child(c_name)
		
		hbox_games.add_child(g_card)
		
	# Live 4-second Countdown Label
	var lbl_loading = Label.new()
	lbl_loading.text = "⚡ ورود به بازی اول تا ۴ ثانیه دیگر..."
	lbl_loading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_loading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_loading.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_loading.add_theme_font_size_override("font_size", 26)
	lbl_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_loading.modulate = Color(0.35, 0.95, 0.55)
	vbox.add_child(lbl_loading)
	
	add_child(overlay)
	draft_showcase_overlay = overlay
	
	# Entrance punch animation + live countdown ticks
	overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.25)
	for sec_left in [3, 2, 1]:
		tw.tween_interval(1.0)
		tw.tween_callback(func():
			if is_instance_valid(lbl_loading):
				var fa_digits = ["۰", "۱", "۲", "۳", "۴"]
				lbl_loading.text = "⚡ ورود به بازی اول تا %s ثانیه دیگر..." % fa_digits[sec_left]
		)

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
	call_deferred("_on_games_scroll_resized")
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
	
	# Responsive Center Panel Container
	var outer_margin = MarginContainer.new()
	outer_margin.anchors_preset = Control.PRESET_FULL_RECT
	outer_margin.anchor_right = 1.0
	outer_margin.anchor_bottom = 1.0
	outer_margin.add_theme_constant_override("margin_left", 32)
	outer_margin.add_theme_constant_override("margin_right", 32)
	outer_margin.add_theme_constant_override("margin_top", 40)
	outer_margin.add_theme_constant_override("margin_bottom", 40)
	overlay.add_child(outer_margin)
	
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb = StyleBoxTexture.new()
	sb.texture = preload("res://assets/images/frames/dialog.png")
	sb.texture_margin_left = 44.0
	sb.texture_margin_top = 80.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_bottom = 80.0
	panel.add_theme_stylebox_override("panel", sb)
	outer_margin.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Icon & Title
	var lbl_modal_title = Label.new()
	lbl_modal_title.text = "⚠️ وضعیت مسابقه"
	lbl_modal_title.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_modal_title.add_theme_font_size_override("font_size", 28)
	lbl_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_modal_title.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(lbl_modal_title)
	
	# Body Message
	var lbl_msg = Label.new()
	lbl_msg.text = message
	lbl_msg.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_msg.add_theme_font_size_override("font_size", 22)
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
	btn_return.custom_minimum_size = Vector2(260, 68)
	btn_return.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	btn_return.add_theme_font_size_override("font_size", 24)
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
	AudioManager.play_theme_music()
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
	set_process(true)
	disconnect_banner.visible = true
	lbl_disconnect.text = "⚠️ ارتباط حریف قطع شد. زمان انتظار برای اتصال مجدد:"
	lbl_dc_timer.text = "%s ثانیه" % _fa_num(wait_time)
	_last_dc_sec = wait_time
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
	turn_total_time = maxf(0.1, seconds)
	_last_timer_sec = -1
	is_timer_active = true
	set_process(true)
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
	var path_png = "res://assets/images/games/%s.png" % clean
	if ResourceLoader.exists(path_png):
		return load(path_png)
	var path = "res://assets/images/games/%s.jpg" % clean
	if ResourceLoader.exists(path):
		return load(path)
	var fallback = "res://assets/images/games/tictactoe.jpg"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null
