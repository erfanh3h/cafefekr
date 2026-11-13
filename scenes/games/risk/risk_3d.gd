extends BaseGameBoard

# ==============================================================================
# RISK STRIKE — CAFE FEKR 3D WAR-ROOM SCENE & GAMER-FRIENDLY MINIMAL HUD
# - True 3D tabletop gameplay on the global Cafe Fekr green felt table
# - Direct 3D interaction: Tap 3D Decks to draw, tap 3D Continents on the map to select
#   source & target (with 3D Tactical Attack Arc!), tap 3D Stations to target opponents,
#   and tap 3D Dice Arena to roll!
# - Zero button clutter: Replaces multi-row button walls with a single sleek Command Bar
#   and a compact `[-] +N [+]` reinforcement stepper during combat.
# ==============================================================================

const RiskMaterials = preload("res://scenes/games/risk/components/risk_materials.gd")
const Risk3DFactory = preload("res://scenes/games/risk/components/risk_3d_factory.gd")
const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const TAP_MAX_DRAG_PX: float = 22.0

# --- Authoritative Risk Match State ---
var game_state: String = "Draw" # Draw | SelectAction | AttackerArmy | DefenderArmy | Attack | GameOver
var continent_deck_count: int = 42
var strategy_deck_count: int = 40
var board_tokens: Array[String] = [
	"Asia", "Europe", "NorthAmerica", "Africa", "SouthAmerica", "Australia"
]
var active_player_indexes: Array[int] = [1, 2]
var total_players: int = 2
var _active_turn: int = 1
var _match_started: bool = false

# Public state per player index (1..4):
# { "continents": Dictionary(continent -> count), "strategies_count": int, "tokens": Array[String] }
var players_state: Dictionary = {
	1: {"continents": {}, "strategies_count": 0, "tokens": []},
	2: {"continents": {}, "strategies_count": 0, "tokens": []},
	3: {"continents": {}, "strategies_count": 0, "tokens": []},
	4: {"continents": {}, "strategies_count": 0, "tokens": []},
}

# Private local player hand state
var my_continents: Dictionary = {}
var my_strategies: Array[String] = []
var my_tokens: Array[String] = []
var expand_ignore_adjacency: bool = false

# Active Combat State
var active_attack: Dictionary = {}

# UI Selection State
var selected_hand_card_idx: int = -1
var selected_source_continent: String = ""
var selected_target_continent: String = ""
var selected_target_player: int = 0
var selected_strategy_name: String = ""
var selected_army_commit: int = 0
var _first_3d_deck_picked: String = ""
var _hand_entries: Array[Dictionary] = []

# --- 3D Scene References ---
var _mats: Dictionary = {}
var _board_root: Node3D
var _table_refs: Dictionary = {}
var _continent_nodes: Dictionary = {}
var _bridge_nodes: Dictionary = {}
var _station_nodes: Dictionary = {}
var _dice_nodes: Array[Node3D] = []
var _dice_arena_tween: Tween
var _attack_arc_root: Node3D
var _anim_clock: float = 0.0

var _rook_mesh: Mesh
var _knight_mesh: Mesh
var _king_mesh: Mesh
var _crown_mesh: Mesh

var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_is_down: bool = false

# --- Gamer-Friendly Minimal 2D HUD References ---
var _hud_layer: CanvasLayer
var _hud_root: Control
var _top_turn_lbl: Label
var _top_decks_lbl: Label
var _btn_zoom: Button
var _camera_zoom_mode: int = 0

var _command_dock_panel: PanelContainer
var _hand_cards_hbox: HBoxContainer
var _card_tray_count_lbl: Label
var _selection_info_lbl: Label
var _tactical_details_lbl: Label
var _action_buttons_row: HBoxContainer

var _combat_banner_panel: PanelContainer
var _combat_banner_lbl: Label

var _inspector_panel: PanelContainer
var _inspector_title_lbl: Label
var _opponent_quick_row: HBoxContainer
var _inspector_cards_vbox: VBoxContainer
var _inspected_player_filter: int = 0
var _inspected_continent_id: String = ""

var _log_panel: PanelContainer
var _log_vbox: VBoxContainer
var _battle_logs: Array[String] = []

var camera_distance: float = 2.52
var camera_pitch: float = -0.88

# ==============================================================================
# 1. INITIALIZATION & SCENE CONSTRUCTION
# ==============================================================================

func _init() -> void:
	# Immersive 3D Cafe Fekr Lounge perspective showing the room, chairs, and 3D War-Map
	camera_distance = 2.52
	camera_pitch = -0.88

func _ready() -> void:
	game_type = GameTypes.RISK
	_mats = RiskMaterials.create_palette()
	_load_3d_meshes()
	_detect_players_and_local_id()
	_build_3d_war_room()
	_build_floating_ui()
	_connect_signals()
	super._ready()

	_update_hud_visibility()
	_refresh_all_3d_and_hud()
	call_deferred("_enforce_camera_framing")

func _enforce_camera_framing() -> void:
	var table: Node = get_tree().get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		table = get_tree().root.find_child("CafeTable", true, false)
	if is_instance_valid(table):
		if "is_top_down_view" in table and table.is_top_down_view and table.has_method("set_top_down_view"):
			table.set_top_down_view(false, 0.35)
		if "target_distance" in table:
			table.target_distance = camera_distance
		if "target_pitch" in table:
			table.target_pitch = camera_pitch
		if "target_yaw" in table:
			table.target_yaw = 0.0
		if table.has_method("set_player_chair_count"):
			table.set_player_chair_count(total_players)
		elif table.has_method("set_player_seats_count"):
			table.set_player_seats_count(total_players)

func _exit_tree() -> void:
	if NetworkManager and NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.disconnect(_on_risk_event_received)
	if NetworkManager and NetworkManager.user_data_received.is_connected(_sync_private_user_data):
		NetworkManager.user_data_received.disconnect(_sync_private_user_data)
	if NetworkManager and NetworkManager.player_surrendered.is_connected(on_player_surrendered):
		NetworkManager.player_surrendered.disconnect(on_player_surrendered)
	if NetworkManager and NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)
	if is_instance_valid(_hud_root):
		_hud_root.queue_free()
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	super._exit_tree()

func _load_3d_meshes() -> void:
	if ResourceLoader.exists("res://assets/models/chess/rook.obj"):
		_rook_mesh = load("res://assets/models/chess/rook.obj")
	if ResourceLoader.exists("res://assets/models/chess/knight.obj"):
		_knight_mesh = load("res://assets/models/chess/knight.obj")
	if ResourceLoader.exists("res://assets/models/chess/king.obj"):
		_king_mesh = load("res://assets/models/chess/king.obj")
	if ResourceLoader.exists("res://assets/models/risk/crown.obj"):
		_crown_mesh = load("res://assets/models/risk/crown.obj")
	else:
		_crown_mesh = _king_mesh

func _detect_players_and_local_id() -> void:
	if GameManager.my_player_index >= 1 and GameManager.my_player_index <= 4:
		my_player_index = GameManager.my_player_index
	else:
		my_player_index = 1

	total_players = clampi(max(2, GameManager.match_players.size()), 2, 4)

	active_player_indexes.clear()
	for i: int in range(1, total_players + 1):
		active_player_indexes.append(i)

func _connect_signals() -> void:
	if NetworkManager and not NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.connect(_on_risk_event_received)
	if NetworkManager and not NetworkManager.user_data_received.is_connected(_sync_private_user_data):
		NetworkManager.user_data_received.connect(_sync_private_user_data)
	if NetworkManager and not NetworkManager.player_surrendered.is_connected(on_player_surrendered):
		NetworkManager.player_surrendered.connect(on_player_surrendered)
	if NetworkManager and not NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.connect(_on_internal_reconnect_data)

func _build_3d_war_room() -> void:
	if is_instance_valid(_board_root):
		_board_root.queue_free()

	_board_root = Node3D.new()
	_board_root.name = "RiskWarRoom3D"
	add_child(_board_root)

	# 1. Inlaid Map Frame, 3D Dice Arena & 3D Draw Decks on the Cafe Fekr Green Felt
	_table_refs = Risk3DFactory.build_tabletop_and_board_frame(_board_root, _mats, FontHekayat)

	# 2. Sea-Lane Adjacency Connectors
	_bridge_nodes = Risk3DFactory.build_sea_lane_bridges(_board_root, _mats)

	# 3. Six Sculpted 3D Continent Islands
	var continents_group: Node3D = Node3D.new()
	continents_group.name = "Continents3D"
	_board_root.add_child(continents_group)
	_continent_nodes.clear()
	for c_id: String in Risk3DFactory.CONTINENT_META.keys():
		_continent_nodes[c_id] = Risk3DFactory.build_continent_node(
			continents_group,
			c_id,
			_mats,
			FontHekayat,
			_rook_mesh,
			_knight_mesh,
			_king_mesh
		)

	# 4. 3D Tactical Attack Arc Container (Shows 3D arched arrow from source to target continent)
	_attack_arc_root = Node3D.new()
	_attack_arc_root.name = "TacticalAttackArc3D"
	_board_root.add_child(_attack_arc_root)

	# 5. 3D Commander Bastion Stations Around the Table
	_rebuild_player_stations_3d()

func _rebuild_player_stations_3d() -> void:
	if not is_instance_valid(_board_root):
		return
	var old_st: Node = _board_root.get_node_or_null("PlayerStations3D")
	if is_instance_valid(old_st):
		old_st.queue_free()

	var st_group: Node3D = Node3D.new()
	st_group.name = "PlayerStations3D"
	_board_root.add_child(st_group)
	_station_nodes.clear()

	var local_id: int = clampi(my_player_index, 1, 4)
	var opps: Array[int] = []
	for p: int in range(1, total_players + 1):
		if p != local_id:
			opps.append(p)

	var y_felt: float = 0.059
	# Local Commander Bastion on Bottom-Right Table Edge
	_station_nodes[local_id] = Risk3DFactory.build_player_station(
		st_group,
		local_id,
		Vector3(0.36, y_felt, 0.44),
		0.0,
		true,
		_mats,
		FontHekayat,
		_king_mesh
	)

	var opp_slots: Array[Dictionary] = []
	if opps.size() == 1:
		opp_slots = [
			{"pos": Vector3(0.0, y_felt, -0.44), "rot": 0.0},
		]
	elif opps.size() == 2:
		opp_slots = [
			{"pos": Vector3(-0.62, y_felt, -0.14), "rot": 0.0},
			{"pos": Vector3(0.62, y_felt, -0.14), "rot": 0.0},
		]
	else:
		opp_slots = [
			{"pos": Vector3(-0.62, y_felt, -0.14), "rot": 0.0},
			{"pos": Vector3(0.0, y_felt, -0.44), "rot": 0.0},
			{"pos": Vector3(0.62, y_felt, -0.14), "rot": 0.0},
		]

	for i: int in range(opps.size()):
		var p_idx: int = opps[i]
		var slot: Dictionary = opp_slots[min(i, opp_slots.size() - 1)]
		_station_nodes[p_idx] = Risk3DFactory.build_player_station(
			st_group,
			p_idx,
			slot["pos"],
			slot["rot"],
			false,
			_mats,
			FontHekayat,
			_king_mesh
		)

	var table: Node = get_tree().get_first_node_in_group("cafe_table")
	if is_instance_valid(table):
		if table.has_method("set_player_chair_count"):
			table.set_player_chair_count(total_players)
		elif table.has_method("set_player_seats_count"):
			table.set_player_seats_count(total_players)

func _rebuild_3d_attack_arc() -> void:
	if not is_instance_valid(_attack_arc_root):
		return
	for ch: Node in _attack_arc_root.get_children():
		ch.queue_free()

	var src_c: String = str(active_attack.get("source_continent", selected_source_continent))
	var tgt_c: String = str(active_attack.get("target_continent", selected_target_continent))
	if src_c == "" or tgt_c == "" or src_c == tgt_c:
		return
	if not Risk3DFactory.CONTINENT_META.has(src_c) or not Risk3DFactory.CONTINENT_META.has(tgt_c):
		return

	var p0: Vector3 = Risk3DFactory.CONTINENT_META[src_c]["pos"] + Vector3(0.0, 0.035, 0.0)
	var p2: Vector3 = Risk3DFactory.CONTINENT_META[tgt_c]["pos"] + Vector3(0.0, 0.035, 0.0)
	var p1: Vector3 = (p0 + p2) * 0.5 + Vector3(0.0, 0.12, 0.0)

	var seg_count: int = 12
	var prev_pt: Vector3 = p0
	for s: int in range(1, seg_count + 1):
		var t: float = float(s) / float(seg_count)
		var omt: float = 1.0 - t
		var pt: Vector3 = (omt * omt) * p0 + (2.0 * omt * t) * p1 + (t * t) * p2
		var seg_vec: Vector3 = pt - prev_pt
		var seg_len: float = seg_vec.length()
		if seg_len > 0.002:
			var seg_mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.012, 0.006, seg_len * 0.92)
			bm.material = _mats["glow_crimson"]
			seg_mi.mesh = bm
			var mid: Vector3 = (prev_pt + pt) * 0.5
			seg_mi.position = mid
			seg_mi.look_at_from_position(mid, pt, Vector3.UP)
			seg_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_attack_arc_root.add_child(seg_mi)
		prev_pt = pt

	# Target Impact Beacon Ring above Target Continent
	var beacon_mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.022
	cyl.height = 0.036
	cyl.radial_segments = 12
	cyl.material = _mats["glow_crimson"]
	beacon_mi.mesh = cyl
	beacon_mi.position = p2 + Vector3(0.0, 0.02, 0.0)
	beacon_mi.rotation_degrees.x = 180.0
	beacon_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attack_arc_root.add_child(beacon_mi)

# ==============================================================================
# 2. GAMER-FRIENDLY MINIMAL FLOATING HUD
# ==============================================================================

func _make_panel_style(
	bg: Color,
	border: Color,
	radius: int = 16,
	border_w: int = 2,
	pad_x: int = 12,
	pad_y: int = 8
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb

func _make_styled_button(
	text_str: String,
	bg_col: Color,
	border_col: Color,
	font_sz: int = 25,
	radius: int = 12,
	is_highlighted: bool = false
) -> Button:
	var btn: Button = Button.new()
	btn.text = text_str
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if FontHekayat:
		btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if is_highlighted else Color(0.95, 0.90, 0.78))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.95))

	var bw: int = 3 if is_highlighted else 2
	var normal_sb: StyleBoxFlat = _make_panel_style(bg_col, border_col, radius, bw, 12, 6)
	var hover_sb: StyleBoxFlat = _make_panel_style(bg_col.lightened(0.10), border_col.lightened(0.20), radius, bw, 12, 6)
	var pressed_sb: StyleBoxFlat = _make_panel_style(bg_col.darkened(0.12), border_col, radius, bw, 12, 6)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	return btn

func _build_floating_ui() -> void:
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_free()

	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 15
	_hud_layer.name = "RiskHUDLayer"
	add_child(_hud_layer)

	_hud_root = Control.new()
	_hud_root.name = "RiskHUDRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)

	# --- 1. Compact Floating Top Status Pill (y = 336..386) ---
	var top_strip: PanelContainer = PanelContainer.new()
	top_strip.name = "TopStatusStrip"
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_left = 40
	top_strip.offset_right = -40
	top_strip.offset_top = 336
	top_strip.offset_bottom = 386
	top_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	top_strip.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.06, 0.04, 0.86), Color(0.82, 0.65, 0.28, 0.72), 20, 1, 14, 4)
	)
	_hud_root.add_child(top_strip)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_strip.add_child(top_hbox)

	var btn_log: Button = _make_styled_button("📜", Color(0.16, 0.11, 0.07, 0.92), Color(0.70, 0.52, 0.24), 21, 10)
	btn_log.custom_minimum_size = Vector2(46, 36)
	btn_log.pressed.connect(_toggle_battle_log_panel)
	top_hbox.add_child(btn_log)

	var btn_inspect: Button = _make_styled_button("👁️ بازیکنان", Color(0.16, 0.11, 0.07, 0.92), Color(0.70, 0.52, 0.24), 21, 10)
	btn_inspect.custom_minimum_size = Vector2(106, 36)
	btn_inspect.pressed.connect(func() -> void: _toggle_opponent_inspector(0))
	top_hbox.add_child(btn_inspect)

	_btn_zoom = _make_styled_button("🔍 نما", Color(0.14, 0.18, 0.15, 0.92), Color(0.45, 0.74, 0.56), 21, 10)
	_btn_zoom.custom_minimum_size = Vector2(78, 36)
	_btn_zoom.pressed.connect(_toggle_camera_zoom)
	top_hbox.add_child(_btn_zoom)

	_top_decks_lbl = Label.new()
	_top_decks_lbl.text = "👑 ۰/۲  |  🗺️ ۴۲  |  ⚡ ۴۰"
	_top_decks_lbl.add_theme_font_override("font", FontHekayat)
	_top_decks_lbl.add_theme_font_size_override("font_size", 25)
	_top_decks_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66))
	top_hbox.add_child(_top_decks_lbl)

	_top_turn_lbl = Label.new()
	_top_turn_lbl.text = "در انتظار شروع..."
	_top_turn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_turn_lbl.add_theme_font_override("font", FontHekayat)
	_top_turn_lbl.add_theme_font_size_override("font_size", 26)
	_top_turn_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	top_hbox.add_child(_top_turn_lbl)

	# --- 2. Unified Sleek Bottom Command Dock (y = 1388..1756 — Leaves 3D Map Wide Open!) ---
	_command_dock_panel = PanelContainer.new()
	_command_dock_panel.name = "SleekCommandDock"
	_command_dock_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_command_dock_panel.offset_left = 16
	_command_dock_panel.offset_right = -16
	_command_dock_panel.offset_top = 1388
	_command_dock_panel.offset_bottom = 1756
	_command_dock_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_command_dock_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.07, 0.05, 0.035, 0.90), Color(0.84, 0.67, 0.28, 0.82), 22, 2, 14, 8)
	)
	_hud_root.add_child(_command_dock_panel)

	var dock_vbox: VBoxContainer = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 6)
	_command_dock_panel.add_child(dock_vbox)

	# Row A: Compact Card Hand Strip (148px)
	var hand_scroll: ScrollContainer = ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.custom_minimum_size = Vector2(0, 148)
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	dock_vbox.add_child(hand_scroll)

	_hand_cards_hbox = HBoxContainer.new()
	_hand_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_cards_hbox.add_theme_constant_override("separation", 10)
	_hand_cards_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.add_child(_hand_cards_hbox)

	# Row B: Full-Width Tactical Turn Detail & Guidance Banner
	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 118)
	detail_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.12, 0.085, 0.055, 0.95), Color(0.68, 0.52, 0.24, 0.72), 16, 1, 14, 8)
	)
	dock_vbox.add_child(detail_panel)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	detail_panel.add_child(info_vbox)

	var meta_hbox: HBoxContainer = HBoxContainer.new()
	meta_hbox.add_theme_constant_override("separation", 12)
	info_vbox.add_child(meta_hbox)

	_card_tray_count_lbl = Label.new()
	_card_tray_count_lbl.text = "🃏 دست شما: ۰ قاره | ۰ استراتژی"
	_card_tray_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card_tray_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_tray_count_lbl.add_theme_font_override("font", FontHekayat)
	_card_tray_count_lbl.add_theme_font_size_override("font_size", 21)
	_card_tray_count_lbl.add_theme_color_override("font_color", Color(0.86, 0.76, 0.54))
	meta_hbox.add_child(_card_tray_count_lbl)

	_selection_info_lbl = Label.new()
	_selection_info_lbl.text = "برای شروع نوبت از دسته‌های ۳بعدی روی میز کارت بکشید."
	_selection_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_selection_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_info_lbl.add_theme_font_override("font", FontHekayat)
	_selection_info_lbl.add_theme_font_size_override("font_size", 27)
	_selection_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.64))
	meta_hbox.add_child(_selection_info_lbl)

	_tactical_details_lbl = Label.new()
	_tactical_details_lbl.text = ""
	_tactical_details_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tactical_details_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tactical_details_lbl.add_theme_font_override("font", FontHekayat)
	_tactical_details_lbl.add_theme_font_size_override("font_size", 23)
	_tactical_details_lbl.add_theme_color_override("font_color", Color(0.93, 0.90, 0.82))
	info_vbox.add_child(_tactical_details_lbl)

	# Row C: Full-Width Contextual Action Controls Row
	var action_scroll: ScrollContainer = ScrollContainer.new()
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_scroll.custom_minimum_size = Vector2(0, 58)
	action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	dock_vbox.add_child(action_scroll)

	_action_buttons_row = HBoxContainer.new()
	_action_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_buttons_row.add_theme_constant_override("separation", 10)
	action_scroll.add_child(_action_buttons_row)

	# --- 3. Floating Combat Outcome Toast (y = 394..524, Auto-Hides) ---
	_combat_banner_panel = PanelContainer.new()
	_combat_banner_panel.name = "CombatOutcomeToast"
	_combat_banner_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_combat_banner_panel.offset_left = 36
	_combat_banner_panel.offset_right = -36
	_combat_banner_panel.offset_top = 394
	_combat_banner_panel.offset_bottom = 524
	_combat_banner_panel.visible = false
	_combat_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_banner_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.14, 0.05, 0.05, 0.96), Color(0.98, 0.78, 0.28, 0.96), 18, 2, 18, 10)
	)
	_hud_root.add_child(_combat_banner_panel)

	_combat_banner_lbl = Label.new()
	_combat_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_banner_lbl.add_theme_font_override("font", FontHekayat)
	_combat_banner_lbl.add_theme_font_size_override("font_size", 31)
	_combat_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_combat_banner_panel.add_child(_combat_banner_lbl)

	# --- 4. Modal Overlays: Player Cards Inspector & Battle Log ---
	_build_inspector_and_log_modals()

func _build_inspector_and_log_modals() -> void:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.name = "OpponentInspectorOverlay"
	_inspector_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inspector_panel.custom_minimum_size = Vector2(980, 840)
	_inspector_panel.offset_left = -490
	_inspector_panel.offset_right = 490
	_inspector_panel.offset_top = -450
	_inspector_panel.offset_bottom = 390
	_inspector_panel.visible = false
	_inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspector_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.055, 0.038, 0.98), Color(0.92, 0.74, 0.30, 0.96), 22, 3, 22, 18)
	)
	_hud_root.add_child(_inspector_panel)

	var ins_vbox: VBoxContainer = VBoxContainer.new()
	ins_vbox.add_theme_constant_override("separation", 12)
	_inspector_panel.add_child(ins_vbox)

	var ins_top: HBoxContainer = HBoxContainer.new()
	ins_vbox.add_child(ins_top)

	var btn_close_ins: Button = _make_styled_button("✖ بستن", Color(0.38, 0.12, 0.12), Color(0.90, 0.44, 0.38), 31, 12)
	btn_close_ins.custom_minimum_size = Vector2(136, 54)
	btn_close_ins.pressed.connect(func() -> void: _inspector_panel.visible = false)
	ins_top.add_child(btn_close_ins)

	_inspector_title_lbl = Label.new()
	_inspector_title_lbl.text = "👁️ وضعیت کارت‌ها و دارایی‌های بازیکنان"
	_inspector_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inspector_title_lbl.add_theme_font_override("font", FontHekayat)
	_inspector_title_lbl.add_theme_font_size_override("font_size", 40)
	_inspector_title_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56))
	ins_top.add_child(_inspector_title_lbl)

	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.custom_minimum_size = Vector2(0, 60)
	ins_vbox.add_child(filter_scroll)

	_opponent_quick_row = HBoxContainer.new()
	_opponent_quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_quick_row.alignment = BoxContainer.ALIGNMENT_END
	_opponent_quick_row.add_theme_constant_override("separation", 10)
	filter_scroll.add_child(_opponent_quick_row)

	var ins_scroll: ScrollContainer = ScrollContainer.new()
	ins_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ins_vbox.add_child(ins_scroll)

	_inspector_cards_vbox = VBoxContainer.new()
	_inspector_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_cards_vbox.add_theme_constant_override("separation", 14)
	ins_scroll.add_child(_inspector_cards_vbox)

	# Battle Log Overlay
	_log_panel = PanelContainer.new()
	_log_panel.name = "BattleLogOverlay"
	_log_panel.set_anchors_preset(Control.PRESET_CENTER)
	_log_panel.custom_minimum_size = Vector2(940, 720)
	_log_panel.offset_left = -470
	_log_panel.offset_right = 470
	_log_panel.offset_top = -380
	_log_panel.offset_bottom = 340
	_log_panel.visible = false
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.055, 0.038, 0.98), Color(0.90, 0.72, 0.28, 0.96), 22, 3, 22, 18)
	)
	_hud_root.add_child(_log_panel)

	var log_outer: VBoxContainer = VBoxContainer.new()
	log_outer.add_theme_constant_override("separation", 12)
	_log_panel.add_child(log_outer)

	var log_top: HBoxContainer = HBoxContainer.new()
	log_outer.add_child(log_top)

	var btn_close_log: Button = _make_styled_button("✖ بستن", Color(0.38, 0.12, 0.12), Color(0.90, 0.44, 0.38), 31, 12)
	btn_close_log.custom_minimum_size = Vector2(136, 54)
	btn_close_log.pressed.connect(func() -> void: _log_panel.visible = false)
	log_top.add_child(btn_close_log)

	var log_title: Label = Label.new()
	log_title.text = "📜 گزارش وقایع نبرد"
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	log_title.add_theme_font_override("font", FontHekayat)
	log_title.add_theme_font_size_override("font_size", 40)
	log_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56))
	log_top.add_child(log_title)

	var log_scroll: ScrollContainer = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_outer.add_child(log_scroll)

	_log_vbox = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_theme_constant_override("separation", 10)
	log_scroll.add_child(_log_vbox)

func _update_hud_visibility() -> void:
	if not is_instance_valid(_hud_root):
		return
	var tree: SceneTree = get_tree()
	var lobby_open: bool = false
	if tree:
		var base_hud: Node = tree.get_first_node_in_group("base_game_hud")
		if not is_instance_valid(base_hud):
			base_hud = tree.root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(base_hud):
			if _hud_root.get_parent() != base_hud:
				if _hud_root.get_parent():
					_hud_root.get_parent().remove_child(_hud_root)
				base_hud.add_child(_hud_root)
				var start_ov_node: Node = base_hud.get_node_or_null("StartGameOverlay")
				if is_instance_valid(start_ov_node):
					base_hud.move_child(_hud_root, start_ov_node.get_index())
				if is_instance_valid(_hud_layer):
					_hud_layer.queue_free()
					_hud_layer = null
			var s_ov: Control = base_hud.get_node_or_null("StartGameOverlay") as Control
			if is_instance_valid(s_ov) and s_ov.visible:
				lobby_open = true
			var r_dlg: Control = base_hud.get_node_or_null("GameResultDialog") as Control
			if is_instance_valid(r_dlg) and r_dlg.visible:
				lobby_open = true
	_hud_root.visible = (GameManager.is_game_active or _match_started) and not lobby_open

func _is_hud_overlay_blocking() -> bool:
	if not is_instance_valid(_hud_root) or not _hud_root.visible:
		return true
	if is_instance_valid(_inspector_panel) and _inspector_panel.visible:
		return true
	if is_instance_valid(_log_panel) and _log_panel.visible:
		return true
	return false

func _build_hand_card_widget(entry: Dictionary, card_idx: int, is_selected: bool) -> Control:
	var kind: String = str(entry.get("kind", "continent"))
	var cid: String = str(entry.get("id", ""))
	var count: int = _to_int(entry.get("count", 1), 1)

	var wrapper: Control = Control.new()
	wrapper.custom_minimum_size = Vector2(138, 144)
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(134, 134)
	card_panel.position = Vector2(2, 0 if is_selected else 8)
	card_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var accent_col: Color = Color(0.24, 0.56, 0.36)
	var title_txt: String = cid
	var sub_txt: String = ""
	var icon_txt: String = "🗺️"

	if kind == "continent":
		accent_col = RiskMaterials.CONTINENT_COLORS.get(cid, Color(0.24, 0.56, 0.36))
		title_txt = _continent_fa(cid)
		var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(cid, {}).get("domination", 4))
		var has_dom: bool = my_tokens.has(cid)
		icon_txt = "👑" if has_dom else "🗺️"
		if _is_my_turn() and game_state == "SelectAction" and cid == selected_source_continent:
			sub_txt = "🚩 مبدا انتخابی"
		elif has_dom:
			sub_txt = "👑 سلطه کامل"
		else:
			sub_txt = "سلطه: %s/%s" % [Risk3DFactory.fa_digits(count), Risk3DFactory.fa_digits(dom_req)]
	else:
		var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(cid, {})
		accent_col = sm.get("color", Color(0.76, 0.24, 0.24))
		title_txt = str(sm.get("fa", cid))
		sub_txt = str(sm.get("short", "استراتژی"))
		icon_txt = str(sm.get("icon", "⚡"))

	var card_bg: Color = Color(0.20, 0.14, 0.08, 0.98) if is_selected else Color(0.12, 0.09, 0.06, 0.96)
	var border_col: Color = Color(1.0, 0.88, 0.32) if is_selected else accent_col.lightened(0.20)
	var border_w: int = 3 if is_selected else 2

	card_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(card_bg, border_col, 14, border_w, 8, 6)
	)
	wrapper.add_child(card_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(vbox)

	var banner: PanelContainer = PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 36)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_sb: StyleBoxFlat = StyleBoxFlat.new()
	banner_sb.bg_color = accent_col.darkened(0.08)
	banner_sb.set_corner_radius_all(8)
	banner_sb.content_margin_left = 8
	banner_sb.content_margin_right = 8
	banner_sb.content_margin_top = 1
	banner_sb.content_margin_bottom = 1
	banner.add_theme_stylebox_override("panel", banner_sb)
	vbox.add_child(banner)

	var banner_hbox: HBoxContainer = HBoxContainer.new()
	banner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_hbox)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "×" + Risk3DFactory.fa_digits(count)
	badge_lbl.add_theme_font_override("font", FontHekayat)
	badge_lbl.add_theme_font_size_override("font_size", 34)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45) if count > 1 else Color(1.0, 0.98, 0.90))
	badge_lbl.add_theme_constant_override("outline_size", 5)
	badge_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.96))
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(badge_lbl)

	var ic_lbl: Label = Label.new()
	ic_lbl.text = icon_txt
	ic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ic_lbl.add_theme_font_size_override("font_size", 23)
	ic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(ic_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.text = title_txt
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 27)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72) if is_selected else Color(0.96, 0.93, 0.86))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = sub_txt
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.add_theme_font_override("font", FontHekayat)
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42) if is_selected else accent_col.lightened(0.45))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	var hit_btn: Button = Button.new()
	hit_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_btn.flat = true
	hit_btn.focus_mode = Control.FOCUS_NONE
	hit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var idx_copy: int = card_idx
	hit_btn.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		_on_hand_card_selected(idx_copy)
	)
	wrapper.add_child(hit_btn)

	return wrapper

# ==============================================================================
# 3. BASE_GAME_BOARD HOOKS & NETWORK SYNCHRONIZATION
# ==============================================================================

func setup_board(game_data: Dictionary) -> void:
	if game_data.has("gamers") and typeof(game_data["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(game_data["gamers"] as Array)
	_detect_players_and_local_id()
	var inner_data: Variant = game_data.get("game_data", game_data)
	if typeof(inner_data) == TYPE_DICTIONARY:
		_sync_full_game_data(inner_data as Dictionary)
	_update_hud_visibility()
	_refresh_all_3d_and_hud()

func on_player_surrendered(gamer_id: int) -> void:
	if players_state.has(gamer_id):
		players_state[gamer_id] = {"continents": {}, "strategies_count": 0, "tokens": []}
	_refresh_all_3d_and_hud()

func on_start_game() -> void:
	_match_started = true
	if game_state == "StartGame":
		game_state = "Draw"
	_update_hud_visibility()
	_refresh_all_3d_and_hud()

func on_turn_changed(turn: int, is_me: bool) -> void:
	_active_turn = turn
	is_my_turn = is_me
	if GameManager.is_game_active and turn > 0:
		_match_started = true
	_update_hud_visibility()
	_refresh_all_3d_and_hud()

func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	_detect_players_and_local_id()
	var g_data: Variant = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_sync_full_game_data(g_data as Dictionary)
	var u_data: Variant = payload.get("user_data", {})
	if typeof(u_data) == TYPE_DICTIONARY and not (u_data as Dictionary).is_empty():
		_sync_private_user_data(u_data as Dictionary)
	_update_hud_visibility()
	_refresh_all_3d_and_hud()

func on_roll_result(payload: Dictionary) -> void:
	_handle_combat_resolution_payload(payload)

func _on_risk_event_received(cmd_id: String, payload: Dictionary) -> void:
	if GameManager.my_player_index > 0:
		my_player_index = GameManager.my_player_index
	if cmd_id != Commands.User_Data and cmd_id != Commands.Game_Data:
		_match_started = true

	match cmd_id:
		Commands.User_Data:
			_sync_private_user_data(payload)
			_refresh_all_3d_and_hud()

		Commands.Draw_Card:
			_active_turn = _to_int(payload.get("turn", _active_turn))
			game_state = str(payload.get("game_state", "Draw"))
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			expand_ignore_adjacency = false
			active_attack.clear()
			selected_source_continent = ""
			selected_target_continent = ""
			selected_hand_card_idx = -1
			selected_strategy_name = ""
			_first_3d_deck_picked = ""
			_restart_hud_turn_timer()
			if _active_turn == my_player_index:
				AudioManager.sfx_bell()
			_append_battle_log("🔄 آغاز نوبت %s (فاز کشیدن کارت)" % _get_player_name(_active_turn))
			_update_hud_visibility()
			_refresh_all_3d_and_hud()

		Commands.Draw_Result:
			var gid: int = _to_int(payload.get("gamer_id", _active_turn))
			var dtype: int = _to_int(payload.get("draw_type", 1))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"] as Array)
			elif payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"] as Dictionary)
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"] as Array)
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			elif dtype == 1:
				continent_deck_count = max(0, continent_deck_count - 2)
			elif dtype == 3:
				continent_deck_count = max(0, continent_deck_count - 1)
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			elif dtype == 2:
				strategy_deck_count = max(0, strategy_deck_count - 2)
			elif dtype in [3, 4]:
				strategy_deck_count = max(0, strategy_deck_count - 1)
			game_state = str(payload.get("game_state", "SelectAction"))
			AudioManager.sfx_add_piece()
			_animate_deck_draw_pulse(dtype)
			_restart_hud_turn_timer()
			_append_battle_log("🃏 %s از دسته کارت کشید." % _get_player_name(gid))
			_refresh_all_3d_and_hud()
			_announce_token_events_and_victory(payload)

		Commands.Draw_Result_Private:
			if payload.has("new_user_data") and typeof(payload["new_user_data"]) == TYPE_DICTIONARY:
				_sync_private_user_data(payload["new_user_data"] as Dictionary)
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			_refresh_all_3d_and_hud()

		Commands.Declare_Attack:
			var atk_id: int = _to_int(payload.get("gamer_id", _active_turn))
			var def_id: int = _to_int(payload.get("target_index", 0))
			var src_c: String = str(payload.get("source_continent", ""))
			var tgt_c: String = str(payload.get("target_continent", ""))
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			game_state = str(payload.get("game_state", "AttackerArmy"))
			active_attack = {
				"attacker_id": atk_id,
				"defender_id": def_id,
				"source_continent": src_c,
				"target_continent": tgt_c,
				"attacker_army": 0,
				"defender_army": 0,
				"battle_started": false,
			}
			selected_army_commit = 0
			_restart_hud_turn_timer()
			_show_combat_toast("⚔️ اعلان حمله: %s از «%s» به «%s» (%s) یورش برد!" % [
				_get_player_name(atk_id),
				_continent_fa(src_c),
				_continent_fa(tgt_c),
				_get_player_name(def_id)
			])
			_append_battle_log("⚔️ %s از %s به %s (%s) حمله کرد." % [
				_get_player_name(atk_id), _continent_fa(src_c), _continent_fa(tgt_c), _get_player_name(def_id)
			])
			_refresh_all_3d_and_hud()

		Commands.AttackerArmy:
			var atk_id: int = _to_int(payload.get("gamer_id", active_attack.get("attacker_id", _active_turn)))
			var def_id: int = _to_int(payload.get("target_index", active_attack.get("defender_id", 0)))
			var committed: int = _to_int(payload.get("count", 0))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"] as Array)
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			active_attack["attacker_id"] = atk_id
			active_attack["defender_id"] = def_id
			active_attack["attacker_army"] = committed
			game_state = str(payload.get("game_state", "DefenderArmy"))
			selected_army_commit = 0
			_restart_hud_turn_timer()
			_show_combat_toast("🗡️ مهاجم %s کارت ارتش کمکی وارد نبرد کرد. نوبت تصمیم دفاعی %s!" % [
				Risk3DFactory.fa_digits(committed),
				_get_player_name(def_id)
			])
			_refresh_all_3d_and_hud()

		Commands.Attack, Commands.Cancel_Attack:
			_handle_combat_resolution_payload(payload)

		Commands.Strategy_Result:
			_handle_strategy_result_payload(payload)

		Commands.Pass_Turn:
			var gid: int = _to_int(payload.get("gamer_id", payload.get("gamer_index", _active_turn)))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"] as Array)
			elif payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"] as Dictionary)
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"] as Array)
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			active_attack.clear()
			_append_battle_log("⏭️ %s نوبت خود را به پایان رساند." % _get_player_name(gid))
			_refresh_all_3d_and_hud()

func _sync_full_game_data(g_data: Dictionary) -> void:
	if g_data.has("current_turn"):
		_active_turn = _to_int(g_data.get("current_turn", 1))
	if g_data.has("active_player_indexes") and typeof(g_data["active_player_indexes"]) == TYPE_ARRAY:
		active_player_indexes.clear()
		for idx: Variant in (g_data["active_player_indexes"] as Array):
			active_player_indexes.append(_to_int(idx))
		if active_player_indexes.size() >= 2:
			var max_idx: int = 2
			for idx: int in active_player_indexes:
				max_idx = max(max_idx, idx)
			if max_idx != total_players:
				total_players = clampi(max_idx, 2, 4)
				_rebuild_player_stations_3d()
	if g_data.has("continents"):
		continent_deck_count = _to_int(g_data.get("continents", continent_deck_count))
	if g_data.has("strategies"):
		strategy_deck_count = _to_int(g_data.get("strategies", strategy_deck_count))
	if g_data.has("tokens") and typeof(g_data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(g_data["tokens"] as Array)
	if g_data.has("game_state"):
		game_state = str(g_data.get("game_state", game_state))
	if g_data.has("players_data") and typeof(g_data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(g_data["players_data"] as Array)
	if g_data.has("active_attack"):
		if typeof(g_data["active_attack"]) == TYPE_DICTIONARY:
			active_attack = (g_data["active_attack"] as Dictionary).duplicate(true)
		else:
			active_attack.clear()

func _parse_board_tokens(raw_tokens: Array) -> void:
	board_tokens.clear()
	for t: Variant in raw_tokens:
		board_tokens.append(str(t))

func _parse_players_data_array(p_list: Array) -> void:
	for item: Variant in p_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item as Dictionary
		var p_idx: int = _to_int(d.get("index", 0))
		if p_idx >= 1 and p_idx <= 4:
			_apply_single_player_public_data(p_idx, d)

func _apply_single_player_public_data(p_idx: int, item: Dictionary) -> void:
	var c_dict: Dictionary = {}
	var raw_c: Variant = item.get("continents", {})
	if typeof(raw_c) == TYPE_DICTIONARY:
		var rc_d: Dictionary = raw_c as Dictionary
		for k: Variant in rc_d.keys():
			var cnt: int = _to_int(rc_d[k])
			if cnt > 0:
				c_dict[str(k)] = cnt

	var t_arr: Array = []
	var raw_t: Variant = item.get("tokens", [])
	if typeof(raw_t) == TYPE_ARRAY:
		for t: Variant in (raw_t as Array):
			t_arr.append(str(t))

	var s_cnt: int = _to_int(item.get("strategies_count", 0))
	if item.has("strategies") and typeof(item["strategies"]) == TYPE_ARRAY:
		s_cnt = (item["strategies"] as Array).size()

	players_state[p_idx] = {
		"continents": c_dict,
		"strategies_count": s_cnt,
		"tokens": t_arr,
	}

func _sync_private_user_data(u_data: Dictionary) -> void:
	var old_id: int = my_player_index
	if u_data.has("index"):
		var idx: int = _to_int(u_data.get("index", my_player_index))
		if idx >= 1 and idx <= 4:
			my_player_index = idx
			GameManager.my_player_index = idx
	if my_player_index != old_id:
		_rebuild_player_stations_3d()

	if u_data.has("continents") and typeof(u_data["continents"]) == TYPE_DICTIONARY:
		my_continents.clear()
		var uc_d: Dictionary = u_data["continents"] as Dictionary
		for k: Variant in uc_d.keys():
			var cnt: int = _to_int(uc_d[k])
			if cnt > 0:
				my_continents[str(k)] = cnt

	if u_data.has("strategies"):
		my_strategies.clear()
		var raw_s: Variant = u_data["strategies"]
		if typeof(raw_s) == TYPE_ARRAY:
			for s_name: Variant in (raw_s as Array):
				my_strategies.append(str(s_name))
		elif typeof(raw_s) == TYPE_DICTIONARY:
			var rs_d: Dictionary = raw_s as Dictionary
			for s_name: Variant in rs_d.keys():
				var c: int = _to_int(rs_d[s_name])
				for _i: int in range(c):
					my_strategies.append(str(s_name))

	if u_data.has("tokens") and typeof(u_data["tokens"]) == TYPE_ARRAY:
		my_tokens.clear()
		for t: Variant in (u_data["tokens"] as Array):
			my_tokens.append(str(t))

	var my_id: int = clampi(my_player_index, 1, 4)
	players_state[my_id] = {
		"continents": my_continents.duplicate(true),
		"strategies_count": my_strategies.size(),
		"tokens": my_tokens.duplicate(),
	}
	_rebuild_hand_entries()

func _rebuild_hand_entries() -> void:
	_hand_entries.clear()
	var c_keys: Array = my_continents.keys()
	c_keys.sort()
	for c_id: Variant in c_keys:
		var cnt: int = _to_int(my_continents[c_id])
		if cnt > 0:
			_hand_entries.append({"kind": "continent", "id": str(c_id), "count": cnt})

	var strat_counts: Dictionary = {}
	for s_name: String in my_strategies:
		strat_counts[s_name] = _to_int(strat_counts.get(s_name, 0)) + 1
	var s_keys: Array = strat_counts.keys()
	s_keys.sort()
	for sn: Variant in s_keys:
		_hand_entries.append({"kind": "strategy", "id": str(sn), "count": _to_int(strat_counts[sn])})

func _handle_combat_resolution_payload(data: Dictionary) -> void:
	if data.has("players_data") and typeof(data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(data["players_data"] as Array)
	if data.has("tokens") and typeof(data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(data["tokens"] as Array)
	if data.has("game_state"):
		game_state = str(data.get("game_state", "SelectAction"))
	else:
		game_state = "SelectAction"

	var canceled: bool = bool(data.get("canceled", false))
	var stopped: bool = bool(data.get("stopped", false))
	var atk_id: int = _to_int(data.get("attacker_id", active_attack.get("attacker_id", _active_turn)))
	var def_id: int = _to_int(data.get("defender_id", active_attack.get("defender_id", 0)))
	var src_c: String = str(data.get("source_continent", active_attack.get("source_continent", "")))
	var tgt_c: String = str(data.get("target_continent", active_attack.get("target_continent", "")))
	var battle_continues: bool = bool(data.get("battle_continues", false)) and (game_state == "Attack")

	var atk_loss: int = _to_int(data.get("attacker_losses", 0))
	var def_loss: int = _to_int(data.get("defender_losses", 0))
	var atk_c_loss: int = _to_int(data.get("attacker_continent_losses", atk_loss))
	var def_c_loss: int = _to_int(data.get("defender_continent_losses", def_loss))
	var returned_c_count: int = _to_int(data.get("returned_continents_count", atk_c_loss + def_c_loss))

	if data.has("continents"):
		continent_deck_count = _to_int(data.get("continents", continent_deck_count))
	elif returned_c_count > 0:
		continent_deck_count += returned_c_count
	if data.has("strategies"):
		strategy_deck_count = _to_int(data.get("strategies", strategy_deck_count))

	if battle_continues:
		active_attack = {
			"attacker_id": atk_id,
			"defender_id": def_id,
			"source_continent": src_c,
			"target_continent": tgt_c,
			"attacker_army": _to_int(data.get("attacker_army", 0)),
			"defender_army": _to_int(data.get("defender_army", 0)),
			"battle_started": true,
		}
	else:
		active_attack.clear()

	selected_source_continent = ""
	selected_target_continent = ""
	selected_army_commit = 0
	_restart_hud_turn_timer()

	if stopped:
		_show_combat_toast("⏹️ %s ادامه نبرد در «%s» را متوقف کرد." % [_get_player_name(atk_id), _continent_fa(tgt_c)])
		_append_battle_log("⏹️ %s ادامه حمله به %s را متوقف کرد." % [_get_player_name(atk_id), _continent_fa(tgt_c)])
		_refresh_all_3d_and_hud()
		return

	if canceled:
		_show_combat_toast("🛡️ مدافع (%s) با کارت «لغو تهاجم» حمله را متوقف کرد!" % _get_player_name(def_id))
		_append_battle_log("🛡️ %s حمله به %s را با کارت Cancel لغو کرد." % [_get_player_name(def_id), _continent_fa(tgt_c)])
		_refresh_all_3d_and_hud()
		return

	var atk_dice: Array = (data.get("attacker_dice", []) as Array) if typeof(data.get("attacker_dice", [])) == TYPE_ARRAY else []
	var def_dice: Array = (data.get("defender_dice", []) as Array) if typeof(data.get("defender_dice", [])) == TYPE_ARRAY else []
	var conquered: bool = bool(data.get("conquered", false))

	if not atk_dice.is_empty() or not def_dice.is_empty():
		_spawn_and_roll_3d_dice(atk_dice, def_dice)

	if atk_c_loss > 0:
		_animate_returned_continent_cards_to_table(src_c, atk_c_loss)
	if def_c_loss > 0:
		_animate_returned_continent_cards_to_table(tgt_c, def_c_loss)

	var atk_str: String = _format_dice_list(atk_dice)
	var def_str: String = _format_dice_list(def_dice)
	var msg: String = "🎲 نبرد در «%s» — تاس مهاجم: %s | تاس مدافع: %s\nتلفات مهاجم: %s | تلفات مدافع: %s" % [
		_continent_fa(tgt_c),
		atk_str,
		def_str,
		Risk3DFactory.fa_digits(atk_loss),
		Risk3DFactory.fa_digits(def_loss),
	]
	if returned_c_count > 0:
		msg += "  (♻️ %s کارت به دسته برگشت)" % Risk3DFactory.fa_digits(returned_c_count)
	if conquered:
		msg += "  🏆 قاره فتح شد!"
	_show_combat_toast(msg, 4.5)
	_append_battle_log("🎲 نبرد %s -> %s: تاس مهاجم %s، مدافع %s (تلفات %s/%s)" % [
		_continent_fa(src_c), _continent_fa(tgt_c), atk_str, def_str,
		Risk3DFactory.fa_digits(atk_loss), Risk3DFactory.fa_digits(def_loss)
	])
	_refresh_all_3d_and_hud()
	_announce_token_events_and_victory(data)

func _handle_strategy_result_payload(data: Dictionary) -> void:
	var gid: int = _to_int(data.get("gamer_id", _active_turn))
	var strat: String = str(data.get("strategy", ""))
	var tgt_id: int = _to_int(data.get("target_index", 0))
	if data.has("players_data") and typeof(data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(data["players_data"] as Array)
	if data.has("tokens") and typeof(data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(data["tokens"] as Array)
	if data.has("continents"):
		continent_deck_count = _to_int(data.get("continents", continent_deck_count))
	elif data.has("drawn_continents") and typeof(data["drawn_continents"]) == TYPE_ARRAY:
		continent_deck_count = max(0, continent_deck_count - (data["drawn_continents"] as Array).size())
	elif strat == "Destroy":
		continent_deck_count += 1
	if data.has("strategies"):
		strategy_deck_count = _to_int(data.get("strategies", strategy_deck_count))

	if data.has("game_state"):
		game_state = str(data["game_state"])

	if strat == "Expand" and gid == my_player_index:
		expand_ignore_adjacency = true

	if data.has("returned_continents") and typeof(data["returned_continents"]) == TYPE_ARRAY:
		for rc: Variant in (data["returned_continents"] as Array):
			_animate_returned_continent_cards_to_table(str(rc), 1)
	elif strat == "Destroy" and data.has("target_continent"):
		_animate_returned_continent_cards_to_table(str(data.get("target_continent", "")), 1)

	var strat_fa: String = str(Risk3DFactory.STRATEGY_META.get(strat, {}).get("fa", strat))
	var target_txt: String = (" علیه " + _get_player_name(tgt_id)) if tgt_id > 0 else ""
	_show_combat_toast("⚡ %s کارت استراتژی «%s»%s را بازی کرد!" % [_get_player_name(gid), strat_fa, target_txt])
	_append_battle_log("⚡ %s کارت «%s»%s را اجرا کرد." % [_get_player_name(gid), strat_fa, target_txt])

	selected_hand_card_idx = -1
	selected_strategy_name = ""
	selected_target_player = 0
	selected_target_continent = ""
	_refresh_all_3d_and_hud()
	_announce_token_events_and_victory(data)

func _announce_token_events_and_victory(data: Dictionary) -> void:
	var tok_msgs: Array[String] = []
	if data.has("token_events") and typeof(data["token_events"]) == TYPE_ARRAY:
		for ev: Variant in (data["token_events"] as Array):
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var ev_d: Dictionary = ev as Dictionary
			var ev_type: String = str(ev_d.get("type", ""))
			var c_id: String = str(ev_d.get("continent", ""))
			var c_fa: String = _continent_fa(c_id)
			var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
			var winner_p: int = _to_int(ev_d.get("winner", 0))
			if winner_p > 0 and ev_type in ["claimed_by_threshold", "stolen_by_threshold", "claimed_by_conquest", "stolen_by_conquest"]:
				var p_tok_cnt: int = (players_state.get(winner_p, {}).get("tokens", []) as Array).size()
				var line: String = "👑 %s با رسیدن به حد نصاب «%s» (%s کارت)، نشان سلطه این قاره را تصاحب کرد! (%s/۲)" % [
					_get_player_name(winner_p),
					c_fa,
					Risk3DFactory.fa_digits(dom_req),
					Risk3DFactory.fa_digits(p_tok_cnt),
				]
				tok_msgs.append(line)
				_append_battle_log(line)

	var is_fin: bool = bool(data.get("is_game_finished", false))
	var win_id: int = _to_int(data.get("winner", 0))
	if is_fin and win_id > 0:
		var win_toks: Array = players_state.get(win_id, {}).get("tokens", [])
		var tok_names: Array[String] = []
		for t: Variant in win_toks:
			tok_names.append(_continent_fa(str(t)))
		var toks_joined: String = " و ".join(tok_names) if not tok_names.is_empty() else "۲ قاره"
		var win_msg: String = "🏆 پایان بازی! %s با کسب ۲ نشان سلطه (%s) پیروز میدان شد!" % [
			_get_player_name(win_id),
			toks_joined,
		]
		_append_battle_log(win_msg)
		if is_instance_valid(_selection_info_lbl):
			_selection_info_lbl.text = win_msg
		_show_combat_toast(win_msg, 5.5)
	elif not tok_msgs.is_empty():
		_show_combat_toast("\n".join(tok_msgs), 4.6)

func _restart_hud_turn_timer() -> void:
	var hud: Node = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(30.0)

# ==============================================================================
# 4. 3D VISUAL REFRESH (CONTINENTS, STATIONS, DECKS, BRIDGES, ATTACK ARC)
# ==============================================================================

func _refresh_all_3d_and_hud() -> void:
	_rebuild_hand_entries()
	_refresh_3d_decks()
	_refresh_3d_continents_and_bridges()
	_rebuild_3d_attack_arc()
	_refresh_3d_player_stations()
	_refresh_top_header()
	_refresh_floating_hud()

func _refresh_3d_decks() -> void:
	var is_draw_phase: bool = (_is_my_turn() and game_state == "Draw")
	if _table_refs.has("continent_deck"):
		var cd: Dictionary = _table_refs["continent_deck"]
		cd["count_lbl"].text = Risk3DFactory.fa_digits(continent_deck_count)
		cd["glow"].visible = is_draw_phase
		if cd.has("title_lbl") and is_instance_valid(cd["title_lbl"]):
			var cd_title: String = "دسته قاره 🗺️"
			if is_draw_phase:
				if _first_3d_deck_picked == "continent":
					cd_title = "✅ انتخاب شد (۱/۲)"
				elif _first_3d_deck_picked == "strategy":
					cd_title = "🗺️ کارت دوم؟"
				else:
					cd_title = "🗺️ ضربه برای کشیدن"
			(cd["title_lbl"] as Label3D).text = cd_title
		var vis_layers: int = clampi(int(ceil(float(continent_deck_count) / 5.0)), 1, 8)
		var cd_layers: Array = cd["layers"]
		for i: int in range(cd_layers.size()):
			cd_layers[i].visible = (i < vis_layers and continent_deck_count > 0)

	if _table_refs.has("strategy_deck"):
		var sd: Dictionary = _table_refs["strategy_deck"]
		sd["count_lbl"].text = Risk3DFactory.fa_digits(strategy_deck_count)
		sd["glow"].visible = is_draw_phase
		if sd.has("title_lbl") and is_instance_valid(sd["title_lbl"]):
			var sd_title: String = "دسته استراتژی ⚡"
			if is_draw_phase:
				if _first_3d_deck_picked == "strategy":
					sd_title = "✅ انتخاب شد (۱/۲)"
				elif _first_3d_deck_picked == "continent":
					sd_title = "⚡ کارت دوم؟"
				else:
					sd_title = "⚡ ضربه برای کشیدن"
			(sd["title_lbl"] as Label3D).text = sd_title
		var vis_layers: int = clampi(int(ceil(float(strategy_deck_count) / 5.0)), 1, 8)
		var sd_layers: Array = sd["layers"]
		for i: int in range(sd_layers.size()):
			sd_layers[i].visible = (i < vis_layers and strategy_deck_count > 0)

func _get_continent_owner_player(c_id: String) -> int:
	for p_idx: int in range(1, total_players + 1):
		var p_toks: Array = players_state.get(p_idx, {}).get("tokens", [])
		if p_toks.has(c_id):
			return p_idx
	var best_p: int = 0
	var best_cnt: int = 0
	var tied: bool = false
	for p_idx: int in range(1, total_players + 1):
		var cnt: int = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		if cnt > best_cnt:
			best_cnt = cnt
			best_p = p_idx
			tied = false
		elif cnt > 0 and cnt == best_cnt:
			tied = true
	return best_p if (best_cnt > 0 and not tied) else 0

func _refresh_3d_continents_and_bridges() -> void:
	var focus_source: String = selected_source_continent if selected_source_continent != "" else _inspected_continent_id
	var valid_targets: Array[String] = _get_valid_attack_target_continents(selected_source_continent)
	var is_my_select_action: bool = (_is_my_turn() and game_state == "SelectAction")
	var is_my_destroy: bool = (is_my_select_action and selected_strategy_name == "Destroy")

	for c_id: String in _continent_nodes.keys():
		var c_ref: Dictionary = _continent_nodes[c_id]
		c_ref["token_node"].visible = board_tokens.has(c_id)

		var owner_p: int = _get_continent_owner_player(c_id)
		var bezel_mat: StandardMaterial3D = RiskMaterials.get_ownership_bezel_material(owner_p, _mats)
		if c_ref.has("ownership_bezel") and is_instance_valid(c_ref["ownership_bezel"]):
			(c_ref["ownership_bezel"] as MeshInstance3D).material_override = bezel_mat
		if c_ref.has("plaque_trim") and is_instance_valid(c_ref["plaque_trim"]):
			(c_ref["plaque_trim"] as MeshInstance3D).material_override = bezel_mat
		if c_ref.has("citadel") and is_instance_valid(c_ref["citadel"]):
			(c_ref["citadel"] as MeshInstance3D).material_override = bezel_mat if owner_p > 0 else _mats["parchment"]

		var garrisons: Dictionary = c_ref["garrisons"]
		var present_players: Array[int] = []
		for p_idx: int in [1, 2, 3, 4]:
			var g_ref: Dictionary = garrisons[p_idx]
			var p_conts: Dictionary = players_state.get(p_idx, {}).get("continents", {})
			var cnt: int = _to_int(p_conts.get(c_id, 0))
			if cnt > 0 and p_idx <= total_players:
				g_ref["node"].visible = true
				g_ref["label"].text = "×" + Risk3DFactory.fa_digits(cnt)
				var vis_discs: int = clampi(cnt, 1, 3)
				if g_ref.has("stack_discs"):
					var discs: Array = g_ref["stack_discs"]
					for d_i: int in range(discs.size()):
						discs[d_i].visible = (d_i < vis_discs)
				if g_ref.has("piece") and is_instance_valid(g_ref["piece"]):
					(g_ref["piece"] as Node3D).position.y = 0.003 + float(vis_discs) * 0.0052
				present_players.append(p_idx)
			else:
				g_ref["node"].visible = false

		if not present_players.is_empty():
			Risk3DFactory.layout_continent_garrisons(c_ref, present_players)

		var aura: MeshInstance3D = c_ref["aura"]
		var plateau: MeshInstance3D = c_ref["plateau"]
		var status_lbl: Label3D = c_ref.get("status_lbl", null)
		var is_atk_src: bool = (active_attack.get("source_continent", "") == c_id)
		var is_atk_tgt: bool = (active_attack.get("target_continent", "") == c_id)
		var is_highlighted: bool = false
		var tag_txt: String = ""
		var tag_col: Color = Color(1.0, 0.94, 0.72)

		var my_cnt: int = _to_int(my_continents.get(c_id, 0))
		var can_attack_from_here: bool = (my_cnt > 0 and not _get_valid_attack_target_continents(c_id).is_empty())

		if is_atk_src:
			aura.visible = true
			aura.material_override = _mats["glow_gold"]
			is_highlighted = true
			tag_txt = "⚔️ مبدا حمله"
			tag_col = Color(1.0, 0.90, 0.36)
		elif is_atk_tgt:
			aura.visible = true
			aura.material_override = _mats["glow_crimson"]
			is_highlighted = true
			tag_txt = "🎯 هدف نبرد"
			tag_col = Color(1.0, 0.56, 0.46)
		elif is_my_destroy:
			var opp_has_c: bool = (selected_target_player > 0 and _to_int(players_state.get(selected_target_player, {}).get("continents", {}).get(c_id, 0)) > 0)
			if c_id == selected_target_continent:
				aura.visible = true
				aura.material_override = _mats["glow_crimson"]
				is_highlighted = true
				tag_txt = "💥 هدف تخریب"
				tag_col = Color(1.0, 0.52, 0.46)
			elif opp_has_c:
				aura.visible = true
				aura.material_override = _mats["glow_emerald"]
				is_highlighted = true
				tag_txt = "💥 قابل تخریب"
				tag_col = Color(0.56, 0.98, 0.68)
			else:
				aura.visible = false
		elif is_my_select_action and selected_source_continent != "":
			if c_id == selected_source_continent and c_id != selected_target_continent:
				aura.visible = true
				aura.material_override = _mats["glow_gold"]
				is_highlighted = true
				tag_txt = "🚩 مبدا (×%s)" % Risk3DFactory.fa_digits(my_cnt)
				tag_col = Color(1.0, 0.90, 0.36)
			elif c_id == selected_target_continent:
				aura.visible = true
				aura.material_override = _mats["glow_crimson"]
				is_highlighted = true
				tag_txt = "🎯 هدف (%s)" % _format_continent_enemy_compact(c_id)
				tag_col = Color(1.0, 0.56, 0.46)
			elif valid_targets.has(c_id):
				aura.visible = true
				aura.material_override = _mats["glow_emerald"]
				is_highlighted = true
				tag_txt = "⚔️ هدف مجاز (%s)" % _format_continent_enemy_compact(c_id)
				tag_col = Color(0.52, 0.98, 0.68)
			else:
				aura.visible = false
		elif is_my_select_action and selected_strategy_name == "":
			if c_id == _inspected_continent_id:
				aura.visible = true
				aura.material_override = _mats["glow_gold"]
				is_highlighted = true
				tag_txt = "⚔️ مبدا مجاز (×%s)" % Risk3DFactory.fa_digits(my_cnt) if can_attack_from_here else "👁️ بازبینی"
				tag_col = Color(1.0, 0.90, 0.36)
			elif can_attack_from_here:
				aura.visible = true
				aura.material_override = _mats["glow_emerald"]
				is_highlighted = true
				tag_txt = "⚔️ مبدا مجاز (×%s)" % Risk3DFactory.fa_digits(my_cnt)
				tag_col = Color(0.52, 0.98, 0.68)
			elif my_cnt > 0:
				aura.visible = false
				tag_txt = "🛡️ بدون هدف مجاور"
				tag_col = Color(0.76, 0.82, 0.90)
			else:
				aura.visible = false
		elif c_id == _inspected_continent_id:
			aura.visible = true
			aura.material_override = _mats["glow_gold"]
			is_highlighted = true
			tag_txt = "👁️ %s" % _continent_fa(c_id)
			tag_col = Color(1.0, 0.92, 0.56)
		else:
			aura.visible = false

		if is_instance_valid(status_lbl):
			status_lbl.visible = (tag_txt != "")
			if tag_txt != "":
				status_lbl.text = tag_txt
				status_lbl.modulate = tag_col

		plateau.material_override = RiskMaterials.get_continent_material(c_id, is_highlighted)

	for pair_key: String in _bridge_nodes.keys():
		var b_node: Node = _bridge_nodes[pair_key]
		var highlight: bool = false
		if not active_attack.is_empty():
			var sc: String = str(active_attack.get("source_continent", ""))
			var tc: String = str(active_attack.get("target_continent", ""))
			if pair_key == (sc + "_" + tc) or pair_key == (tc + "_" + sc):
				highlight = true
		elif focus_source != "":
			if pair_key.begins_with(focus_source + "_") or pair_key.ends_with("_" + focus_source):
				highlight = true
		Risk3DFactory.set_bridge_material(b_node, _mats["bridge_active"] if highlight else _mats["bridge_idle"])

func _refresh_3d_player_stations() -> void:
	var needs_opp_target: bool = (selected_strategy_name in ["Bomb", "Destroy", "Spy"])

	for p_idx: int in _station_nodes.keys():
		var st_ref: Dictionary = _station_nodes[p_idx]
		var p_data: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
		var is_turn: bool = (_active_turn == p_idx)
		st_ref["active_glow"].visible = is_turn
		st_ref["commander_mi"].material_override = st_ref["f_mat_active"] if is_turn else st_ref["f_mat_idle"]
		st_ref["target_glow"].visible = (needs_opp_target and p_idx != my_player_index) or (selected_target_player == p_idx)

		Risk3DFactory.populate_station_assets_3d(st_ref, p_data, _mats, FontHekayat, _crown_mesh)

func _refresh_top_header() -> void:
	var hud: Node = get_tree().get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if not is_instance_valid(hud):
		return
	var header: Node = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
	if not is_instance_valid(header):
		return

	var t_counts: Array[int] = [0, 0, 0, 0]
	var c_counts: Array[int] = [0, 0, 0, 0]
	var s_counts: Array[int] = [0, 0, 0, 0]
	for idx: int in [1, 2, 3, 4]:
		var st: Dictionary = players_state.get(idx, {})
		t_counts[idx - 1] = (st.get("tokens", []) as Array).size()
		c_counts[idx - 1] = _sum_dict_values(st.get("continents", {}) as Dictionary)
		s_counts[idx - 1] = _to_int(st.get("strategies_count", 0))

	if header.has_method("update_risk_player_stats"):
		header.update_risk_player_stats(t_counts, c_counts, s_counts, GameManager.ludo_rank1, GameManager.ludo_rank2)
	elif header.has_method("update_risk_stats"):
		header.update_risk_stats(t_counts, c_counts, s_counts)

# ==============================================================================
# 5. GAMER-FRIENDLY MINIMAL HUD & CONTEXTUAL SINGLE-BAR ACTIONS
# ==============================================================================

func _refresh_floating_hud() -> void:
	_update_hud_visibility()
	if not is_instance_valid(_hud_root):
		return

	# 1. Update Compact Top Status Pill
	var my_tok_cnt: int = my_tokens.size()
	if is_instance_valid(_top_decks_lbl):
		_top_decks_lbl.text = "👑 %s/۲  |  🗺️ %s  |  ⚡ %s" % [
			Risk3DFactory.fa_digits(my_tok_cnt),
			Risk3DFactory.fa_digits(continent_deck_count),
			Risk3DFactory.fa_digits(strategy_deck_count),
		]
	if is_instance_valid(_top_turn_lbl):
		var expand_tag: String = " 🧭" if expand_ignore_adjacency else ""
		if _is_my_turn():
			_top_turn_lbl.text = "🟢 نوبت شما • %s%s" % [_phase_fa(game_state), expand_tag]
			_top_turn_lbl.add_theme_color_override("font_color", Color(0.52, 0.96, 0.66))
		else:
			_top_turn_lbl.text = "⏳ نوبت %s • %s" % [_get_player_name(_active_turn), _phase_fa(game_state)]
			_top_turn_lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.48))

	# 2. Populate Card Hand Strip
	if is_instance_valid(_hand_cards_hbox):
		for ch: Node in _hand_cards_hbox.get_children():
			ch.queue_free()

		var total_c_cards: int = _sum_dict_values(my_continents)
		var total_s_cards: int = my_strategies.size()
		if is_instance_valid(_card_tray_count_lbl):
			_card_tray_count_lbl.text = "🃏 دست شما: %s قاره  |  %s استراتژی" % [
				Risk3DFactory.fa_digits(total_c_cards),
				Risk3DFactory.fa_digits(total_s_cards),
			]

		for i: int in range(_hand_entries.size()):
			var entry: Dictionary = _hand_entries[i]
			var c_kind: String = str(entry["kind"])
			var c_id: String = str(entry["id"])
			var is_sel: bool = (i == selected_hand_card_idx) or (c_kind == "continent" and c_id == selected_source_continent) or (c_kind == "strategy" and c_id == selected_strategy_name)
			var card_widget: Control = _build_hand_card_widget(entry, i, is_sel)
			_hand_cards_hbox.add_child(card_widget)

		if _hand_entries.is_empty():
			var empty_lbl: Label = Label.new()
			empty_lbl.text = "هیچ کارتی در دست شما نیست — از دسته‌های ۳بعدی بالای میز کارت بکشید"
			empty_lbl.add_theme_font_override("font", FontHekayat)
			empty_lbl.add_theme_font_size_override("font_size", 26)
			empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62))
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_hand_cards_hbox.add_child(empty_lbl)

	# 3. Clear Single Action Row
	for ch: Node in _action_buttons_row.get_children():
		ch.queue_free()
	if is_instance_valid(_opponent_quick_row):
		for ch: Node in _opponent_quick_row.get_children():
			ch.queue_free()

	_populate_inspector_filter_chips()
	if is_instance_valid(_inspector_panel) and _inspector_panel.visible:
		_rebuild_inspector_cards_view(_inspected_player_filter)

	var def_id: int = _to_int(active_attack.get("defender_id", 0))
	var atk_id: int = _to_int(active_attack.get("attacker_id", _active_turn))

	# 4A. ONGOING MULTI-ROUND BATTLE PHASE (`Attack`)
	if game_state == "Attack":
		var src_c: String = str(active_attack.get("source_continent", ""))
		var tgt_c: String = str(active_attack.get("target_continent", ""))
		var src_fa: String = _continent_fa(src_c)
		var tgt_fa: String = _continent_fa(tgt_c)
		var atk_forces: int = _to_int(players_state.get(atk_id, {}).get("continents", {}).get(src_c, 0))
		var def_forces: int = _to_int(players_state.get(def_id, {}).get("continents", {}).get(tgt_c, 0))
		var atk_base_d: int = clampi(atk_forces, 1, 3)
		var def_base_d: int = clampi(def_forces, 1, 2)
		if atk_id == my_player_index:
			_selection_info_lbl.text = "🎲 ادامه نبرد: «%s» ⬅️ «%s» — پرتاب مجدد تاس یا توقف؟" % [src_fa, tgt_fa]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "نیروی باقی‌مانده شما در «%s»: ×%s (%s تاس پایه)  |  مدافع (%s در %s): ×%s (%s تاس پایه) — روی «پرتاب مجدد» یا سینی تاس ۳بعدی بزنید." % [
					src_fa,
					Risk3DFactory.fa_digits(atk_forces),
					Risk3DFactory.fa_digits(atk_base_d),
					_get_player_name(def_id),
					tgt_fa,
					Risk3DFactory.fa_digits(def_forces),
					Risk3DFactory.fa_digits(def_base_d),
				]

			var btn_roll_again: Button = _make_styled_button(
				"🎲 پرتاب مجدد تاس",
				Color(0.46, 0.14, 0.14, 0.98),
				Color(0.96, 0.48, 0.36),
				27,
				12,
				true
			)
			btn_roll_again.custom_minimum_size = Vector2(220, 50)
			btn_roll_again.pressed.connect(func() -> void:
				AudioManager.sfx_button()
				send_move(Commands.Attack, {})
			)
			_action_buttons_row.add_child(btn_roll_again)

			var btn_stop_atk: Button = _make_styled_button(
				"⏹️ توقف حمله",
				Color(0.22, 0.16, 0.12, 0.96),
				Color(0.78, 0.62, 0.34),
				26,
				12
			)
			btn_stop_atk.custom_minimum_size = Vector2(165, 50)
			btn_stop_atk.pressed.connect(func() -> void:
				AudioManager.sfx_button()
				send_move(Commands.Cancel_Attack, {"stop": true})
			)
			_action_buttons_row.add_child(btn_stop_atk)
		elif def_id == my_player_index:
			_selection_info_lbl.text = "🛡️ دفاع در «%s» — در انتظار پرتاب تاس %s" % [tgt_fa, _get_player_name(atk_id)]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "نیروی باقی‌مانده شما در «%s»: ×%s (%s تاس)  |  مهاجم (%s در %s): ×%s (%s تاس)" % [
					tgt_fa,
					Risk3DFactory.fa_digits(def_forces),
					Risk3DFactory.fa_digits(def_base_d),
					_get_player_name(atk_id),
					src_fa,
					Risk3DFactory.fa_digits(atk_forces),
					Risk3DFactory.fa_digits(atk_base_d),
				]
			if _count_my_strategy("Cancel") > 0:
				var btn_def_cancel: Button = _make_styled_button(
					"🛡️ لغو حمله (Cancel)",
					Color(0.14, 0.34, 0.42, 0.98),
					Color(0.38, 0.88, 0.96),
					26,
					12,
					true
				)
				btn_def_cancel.custom_minimum_size = Vector2(225, 50)
				btn_def_cancel.pressed.connect(func() -> void:
					AudioManager.sfx_button()
					send_move(Commands.Cancel_Attack, {})
				)
				_action_buttons_row.add_child(btn_def_cancel)
		else:
			_selection_info_lbl.text = "🎲 نبرد بین %s و %s در قاره «%s» ادامه دارد" % [
				_get_player_name(atk_id), _get_player_name(def_id), tgt_fa
			]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "مهاجم در «%s»: ×%s نیرو  |  مدافع در «%s»: ×%s نیرو" % [
					src_fa, Risk3DFactory.fa_digits(atk_forces), tgt_fa, Risk3DFactory.fa_digits(def_forces)
				]
		return

	# 4B. DEFENDER PHASE (`DefenderArmy`) — Compact `[-] +N [+]` Stepper + Detailed Dice Preview!
	if game_state == "DefenderArmy":
		var src_c: String = str(active_attack.get("source_continent", ""))
		var tgt_c: String = str(active_attack.get("target_continent", ""))
		var src_fa: String = _continent_fa(src_c)
		var tgt_fa: String = _continent_fa(tgt_c)
		var atk_extra: int = _to_int(active_attack.get("attacker_army", 0))
		var atk_forces: int = _to_int(players_state.get(atk_id, {}).get("continents", {}).get(src_c, 1))
		var atk_total_dice: int = clampi(atk_forces, 1, 3) + atk_extra
		if def_id == my_player_index:
			var my_army_cards: int = _count_my_strategy("Army")
			var has_cancel: bool = (_count_my_strategy("Cancel") > 0)
			var my_def_forces: int = _to_int(my_continents.get(tgt_c, 1))
			var base_def_dice: int = clampi(my_def_forces, 1, 2)
			var max_def_extra: int = max(0, 4 - base_def_dice)
			var allowed_def_army: int = min(my_army_cards, max_def_extra)
			selected_army_commit = clampi(selected_army_commit, 0, allowed_def_army)
			var total_def_dice: int = base_def_dice + selected_army_commit
			_selection_info_lbl.text = "🛡️ دفاع از «%s» در برابر %s — ارتش کمکی انتخاب کنید" % [tgt_fa, _get_player_name(atk_id)]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "مهاجم از «%s» با %s تاس (%s کمکی) حمله کرده | تاس دفاعی شما: %s پایه + %s کمکی = %s تاس (سقف ۴) | کارت ارتش در دست: %s" % [
					src_fa,
					Risk3DFactory.fa_digits(atk_total_dice),
					Risk3DFactory.fa_digits(atk_extra),
					Risk3DFactory.fa_digits(base_def_dice),
					Risk3DFactory.fa_digits(selected_army_commit),
					Risk3DFactory.fa_digits(total_def_dice),
					Risk3DFactory.fa_digits(my_army_cards),
				]

			if allowed_def_army > 0:
				_add_compact_army_stepper(allowed_def_army, "🛡️")

			var btn_defend: Button = _make_styled_button(
				"🎲 دفاع با %s تاس (+%s)" % [Risk3DFactory.fa_digits(total_def_dice), Risk3DFactory.fa_digits(selected_army_commit)],
				Color(0.14, 0.38, 0.22, 0.98),
				Color(0.42, 0.90, 0.58),
				27,
				12,
				true
			)
			btn_defend.custom_minimum_size = Vector2(225, 50)
			btn_defend.pressed.connect(func() -> void:
				AudioManager.sfx_button()
				send_move(Commands.DefenderArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_defend)

			if has_cancel:
				var btn_cancel_atk: Button = _make_styled_button(
					"🛡️ لغو حمله",
					Color(0.14, 0.34, 0.42, 0.98),
					Color(0.38, 0.88, 0.96),
					26,
					12,
					true
				)
				btn_cancel_atk.custom_minimum_size = Vector2(155, 50)
				btn_cancel_atk.pressed.connect(func() -> void:
					AudioManager.sfx_button()
					send_move(Commands.DefenderArmy, {"count": 0, "cancel": true})
				)
				_action_buttons_row.add_child(btn_cancel_atk)
		else:
			_selection_info_lbl.text = "⏳ در انتظار تصمیم دفاعی %s در قاره «%s»" % [_get_player_name(def_id), tgt_fa]
			if is_instance_valid(_tactical_details_lbl):
				var def_forces: int = _to_int(players_state.get(def_id, {}).get("continents", {}).get(tgt_c, 1))
				_tactical_details_lbl.text = "%s از «%s» با %s تاس (%s ارتش کمکی) به «%s» (×%s نیرو) حمله کرده است." % [
					_get_player_name(atk_id),
					src_fa,
					Risk3DFactory.fa_digits(atk_total_dice),
					Risk3DFactory.fa_digits(atk_extra),
					tgt_fa,
					Risk3DFactory.fa_digits(def_forces),
				]
		return

	# 5. ATTACKER REINFORCEMENT PHASE (`AttackerArmy`) — Compact `[-] +N [+]` Stepper + Full Dice Preview!
	if game_state == "AttackerArmy":
		var src_c: String = str(active_attack.get("source_continent", ""))
		var tgt_c: String = str(active_attack.get("target_continent", ""))
		var src_fa: String = _continent_fa(src_c)
		var tgt_fa: String = _continent_fa(tgt_c)
		var def_forces: int = _to_int(players_state.get(def_id, {}).get("continents", {}).get(tgt_c, 1))
		var def_base_dice: int = clampi(def_forces, 1, 2)
		if atk_id == my_player_index:
			var my_army_cards: int = _count_my_strategy("Army")
			var my_src_forces: int = _to_int(my_continents.get(src_c, 1))
			var base_atk_dice: int = clampi(my_src_forces, 1, 3)
			var max_atk_extra: int = max(0, 5 - base_atk_dice)
			var allowed_atk_army: int = min(my_army_cards, max_atk_extra)
			selected_army_commit = clampi(selected_army_commit, 0, allowed_atk_army)
			var total_atk_dice: int = base_atk_dice + selected_army_commit
			_selection_info_lbl.text = "⚔️ تقویت حمله: «%s» ⬅️ «%s» (%s)" % [src_fa, tgt_fa, _get_player_name(def_id)]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "تاس شما: %s پایه + %s کمکی = %s تاس (سقف ۵)  |  کارت ارتش در دست: %s  |  مدافع: ×%s نیرو (%s تاس پایه)" % [
					Risk3DFactory.fa_digits(base_atk_dice),
					Risk3DFactory.fa_digits(selected_army_commit),
					Risk3DFactory.fa_digits(total_atk_dice),
					Risk3DFactory.fa_digits(my_army_cards),
					Risk3DFactory.fa_digits(def_forces),
					Risk3DFactory.fa_digits(def_base_dice),
				]

			if allowed_atk_army > 0:
				_add_compact_army_stepper(allowed_atk_army, "⚔️")

			var btn_commit: Button = _make_styled_button(
				"⚔️ تایید %s تاس (+%s)" % [Risk3DFactory.fa_digits(total_atk_dice), Risk3DFactory.fa_digits(selected_army_commit)],
				Color(0.46, 0.14, 0.14, 0.98),
				Color(0.96, 0.48, 0.36),
				27,
				12,
				true
			)
			btn_commit.custom_minimum_size = Vector2(225, 50)
			btn_commit.pressed.connect(func() -> void:
				AudioManager.sfx_button()
				send_move(Commands.AttackerArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_commit)

			if _count_my_strategy("Canon") > 0:
				var btn_canon: Button = _make_styled_button(
					"🎯 توپخانه (+۱ تاس)",
					Color(0.36, 0.26, 0.08, 0.98),
					Color(0.96, 0.82, 0.28),
					25,
					12
				)
				btn_canon.custom_minimum_size = Vector2(175, 50)
				btn_canon.pressed.connect(func() -> void:
					AudioManager.sfx_button()
					send_move(Commands.Use_Strategy, {"strategy": "Canon"})
				)
				_action_buttons_row.add_child(btn_canon)
		else:
			_selection_info_lbl.text = "⏳ %s در حال تقویت حمله از «%s» به «%s» است" % [
				_get_player_name(atk_id), src_fa, tgt_fa
			]
			if is_instance_valid(_tactical_details_lbl):
				var atk_forces: int = _to_int(players_state.get(atk_id, {}).get("continents", {}).get(src_c, 1))
				_tactical_details_lbl.text = "نیروی مهاجم در «%s»: ×%s  |  مدافع (%s) در «%s»: ×%s نیرو" % [
					src_fa, Risk3DFactory.fa_digits(atk_forces), _get_player_name(def_id), tgt_fa, Risk3DFactory.fa_digits(def_forces)
				]
		return

	# 6. NOT MY TURN
	if not _is_my_turn():
		_selection_info_lbl.text = "⏳ نوبت فرماندهی %s • %s" % [_get_player_name(_active_turn), _phase_fa(game_state)]
		if is_instance_valid(_tactical_details_lbl):
			if _inspected_continent_id != "":
				_tactical_details_lbl.text = _build_continent_inspect_text(_inspected_continent_id)
			else:
				_tactical_details_lbl.text = "منتظر اقدام حریف بمانید. می‌توانید روی هر قاره ۳بعدی بزنید تا نیروها و حد نصاب سلطه آن را ببینید."
		return

	# 7. MY TURN - DRAW PHASE (`Draw`)
	if game_state == "Draw":
		if not _first_3d_deck_picked.is_empty():
			var first_fa: String = "قاره 🗺️" if _first_3d_deck_picked == "continent" else "استراتژی ⚡"
			_selection_info_lbl.text = "🃏 گام کشیدن کارت (۱ از ۲ انتخاب شد: %s) — دسته دوم را بزنید" % first_fa
		else:
			_selection_info_lbl.text = "🃏 گام اول نوبت شما • ۲ کارت از دسته‌ها بکشید"
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "موجودی دسته قاره: %s کارت | دسته استراتژی: %s کارت — ترکیب ۲ کارت را از دکمه‌ها یا دسته‌های ۳بعدی روی میز انتخاب کنید تا وارد فاز حمله شوید." % [
				Risk3DFactory.fa_digits(continent_deck_count),
				Risk3DFactory.fa_digits(strategy_deck_count),
			]

		var btn_d1: Button = _make_styled_button("🗺️ ۲ قاره", Color(0.12, 0.34, 0.22, 0.98), Color(0.38, 0.88, 0.56), 26, 12, true)
		btn_d1.custom_minimum_size = Vector2(150, 50)
		btn_d1.pressed.connect(func() -> void: _send_draw_card(1))
		_action_buttons_row.add_child(btn_d1)

		var btn_d3: Button = _make_styled_button("⚖️ ۱ قاره + ۱ استراتژی", Color(0.28, 0.22, 0.10, 0.98), Color(0.94, 0.78, 0.32), 26, 12, true)
		btn_d3.custom_minimum_size = Vector2(225, 50)
		btn_d3.pressed.connect(func() -> void: _send_draw_card(3))
		_action_buttons_row.add_child(btn_d3)

		var btn_d2: Button = _make_styled_button("⚡ ۲ استراتژی", Color(0.38, 0.14, 0.16, 0.98), Color(0.90, 0.44, 0.44), 26, 12, true)
		btn_d2.custom_minimum_size = Vector2(165, 50)
		btn_d2.pressed.connect(func() -> void: _send_draw_card(2))
		_action_buttons_row.add_child(btn_d2)
		return

	# 8. MY TURN - SELECT ACTION PHASE (`SelectAction`) — Clear Step-by-Step Source -> Target -> Attack Guidance!
	if selected_strategy_name != "":
		_populate_strategy_action_controls()
	elif selected_source_continent != "":
		_populate_attack_action_controls()
	else:
		_selection_info_lbl.text = "🚩 گام ۱ از ۳ • قاره مبدا حمله یا کارت استراتژی را انتخاب کنید"
		if is_instance_valid(_tactical_details_lbl):
			var summary_str: String = _build_my_continents_tactical_summary()
			if _inspected_continent_id != "" and _to_int(my_continents.get(_inspected_continent_id, 0)) <= 0:
				_tactical_details_lbl.text = _build_continent_inspect_text(_inspected_continent_id) + "\n" + summary_str
			else:
				_tactical_details_lbl.text = summary_str

	if selected_source_continent != "" or selected_strategy_name != "":
		var btn_clear: Button = _make_styled_button("✖ انصراف", Color(0.22, 0.14, 0.12, 0.94), Color(0.66, 0.48, 0.34), 25, 12)
		btn_clear.custom_minimum_size = Vector2(120, 50)
		btn_clear.pressed.connect(func() -> void:
			AudioManager.sfx_tap()
			selected_hand_card_idx = -1
			selected_source_continent = ""
			selected_target_continent = ""
			selected_strategy_name = ""
			_refresh_all_3d_and_hud()
		)
		_action_buttons_row.add_child(btn_clear)

	var btn_pass: Button = _make_styled_button("⏭️ پایان نوبت", Color(0.22, 0.16, 0.10, 0.95), Color(0.78, 0.62, 0.32), 26, 12)
	btn_pass.custom_minimum_size = Vector2(165, 50)
	btn_pass.pressed.connect(func() -> void:
		AudioManager.sfx_button()
		send_move(Commands.Pass_Turn, {})
	)
	_action_buttons_row.add_child(btn_pass)

func _add_compact_army_stepper(max_allowed: int, icon_str: String) -> void:
	var btn_minus: Button = _make_styled_button("−", Color(0.20, 0.14, 0.10, 0.95), Color(0.72, 0.56, 0.32), 28, 10)
	btn_minus.custom_minimum_size = Vector2(52, 50)
	btn_minus.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		selected_army_commit = max(0, selected_army_commit - 1)
		_refresh_floating_hud()
	)
	_action_buttons_row.add_child(btn_minus)

	var count_chip: Label = Label.new()
	count_chip.text = " %s +%s ارتش " % [icon_str, Risk3DFactory.fa_digits(selected_army_commit)]
	count_chip.add_theme_font_override("font", FontHekayat)
	count_chip.add_theme_font_size_override("font_size", 27)
	count_chip.add_theme_color_override("font_color", Color(1.0, 0.92, 0.46))
	_action_buttons_row.add_child(count_chip)

	var btn_plus: Button = _make_styled_button("+", Color(0.20, 0.14, 0.10, 0.95), Color(0.72, 0.56, 0.32), 28, 10)
	btn_plus.custom_minimum_size = Vector2(52, 50)
	btn_plus.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		selected_army_commit = min(max_allowed, selected_army_commit + 1)
		_refresh_floating_hud()
	)
	_action_buttons_row.add_child(btn_plus)

func _populate_attack_action_controls() -> void:
	var src_fa: String = _continent_fa(selected_source_continent)
	var my_cnt: int = _to_int(my_continents.get(selected_source_continent, 0))
	var my_base_dice: int = clampi(my_cnt, 1, 3)
	if selected_target_continent == "":
		var valid_targets: Array[String] = _get_valid_attack_target_continents(selected_source_continent)
		if valid_targets.is_empty():
			_selection_info_lbl.text = "🚩 مبدا «%s» (×%s نیرو) — دشمن هم‌مرزی برای حمله وجود ندارد" % [src_fa, Risk3DFactory.fa_digits(my_cnt)]
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "در قاره «%s» و قاره‌های هم‌مرز آن هیچ نیروی دشمنی نیست. قاره دیگری را برای حمله انتخاب کنید یا نوبت را پایان دهید." % src_fa
			return
		var target_desc_parts: Array[String] = []
		for tc: String in valid_targets:
			var t_name: String = _continent_fa(tc)
			if tc == selected_source_continent:
				t_name += " (همین قاره)"
			target_desc_parts.append("%s [%s]" % [t_name, _format_continent_enemy_compact(tc)])
			var btn_t: Button = _make_styled_button(
				"🎯 %s (%s)" % [_continent_fa(tc), _format_continent_enemy_compact(tc)],
				Color(0.12, 0.34, 0.22, 0.98),
				Color(0.42, 0.90, 0.56),
				25,
				12,
				true
			)
			btn_t.custom_minimum_size = Vector2(180, 50)
			var tc_copy: String = tc
			btn_t.pressed.connect(func() -> void:
				AudioManager.sfx_tap()
				_select_target_continent_for_attack(tc_copy)
			)
			_action_buttons_row.add_child(btn_t)
		_selection_info_lbl.text = "🎯 گام ۲ از ۳ • قاره هدف را برای حمله از «%s» انتخاب کنید" % src_fa
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "مبدا: «%s» (شما: ×%s نیرو • %s تاس پایه) | اهداف مجاز: %s — روی قاره سبز نقشه یا دکمه هدف زیر بزنید." % [
				src_fa,
				Risk3DFactory.fa_digits(my_cnt),
				Risk3DFactory.fa_digits(my_base_dice),
				" ، ".join(target_desc_parts),
			]
		return

	var tgt_fa: String = _continent_fa(selected_target_continent)
	var defenders: Array[int] = _get_defenders_on_continent(selected_target_continent)
	if defenders.is_empty():
		_selection_info_lbl.text = "در قاره «%s» نیروی دشمنی حضور ندارد." % tgt_fa
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "هدف دیگری را انتخاب کنید."
		return

	if selected_target_player == 0 or not defenders.has(selected_target_player):
		selected_target_player = defenders[0]

	var def_cnt: int = _to_int(players_state.get(selected_target_player, {}).get("continents", {}).get(selected_target_continent, 1))
	var def_base_dice: int = clampi(def_cnt, 1, 2)
	var same_tag: String = " (نبرد داخلی هم‌قاره)" if selected_target_continent == selected_source_continent else ""
	_selection_info_lbl.text = "⚔️ گام ۳ از ۳ • تایید حمله: «%s» ⬅️ «%s»%s" % [src_fa, tgt_fa, same_tag]
	if is_instance_valid(_tactical_details_lbl):
		var multi_note: String = " | چند حریف در این قاره هستند؛ حریف را با دکمه زیر تغییر دهید" if defenders.size() > 1 else ""
		_tactical_details_lbl.text = "مهاجم (شما در %s): ×%s نیرو (%s تاس پایه)  |  مدافع (%s در %s): ×%s نیرو (%s تاس پایه)%s" % [
			src_fa,
			Risk3DFactory.fa_digits(my_cnt),
			Risk3DFactory.fa_digits(my_base_dice),
			_get_player_name(selected_target_player),
			tgt_fa,
			Risk3DFactory.fa_digits(def_cnt),
			Risk3DFactory.fa_digits(def_base_dice),
			multi_note,
		]

	# If multiple defenders occupy the target continent, show a single compact cycle button instead of a row of buttons
	if defenders.size() > 1:
		var btn_cycle_def: Button = _make_styled_button(
			"🎯 حریف: %s ↻" % _get_player_name(selected_target_player),
			Color(0.28, 0.16, 0.10, 0.96),
			Color(0.96, 0.80, 0.28),
			25,
			12
		)
		btn_cycle_def.custom_minimum_size = Vector2(180, 50)
		btn_cycle_def.pressed.connect(func() -> void:
			AudioManager.sfx_tap()
			var cur_i: int = defenders.find(selected_target_player)
			selected_target_player = defenders[(cur_i + 1) % defenders.size()]
			_refresh_all_3d_and_hud()
		)
		_action_buttons_row.add_child(btn_cycle_def)

	var btn_atk: Button = _make_styled_button(
		"⚔️ شروع حمله به «%s»" % tgt_fa,
		Color(0.48, 0.14, 0.14, 0.98),
		Color(0.96, 0.50, 0.36),
		27,
		12,
		true
	)
	btn_atk.custom_minimum_size = Vector2(235, 50)
	btn_atk.pressed.connect(_send_declare_attack)
	_action_buttons_row.add_child(btn_atk)

func _populate_strategy_action_controls() -> void:
	var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(selected_strategy_name, {})
	var strat_fa: String = str(sm.get("fa", selected_strategy_name))
	var desc: String = str(sm.get("desc", ""))
	_selection_info_lbl.text = "⚡ کارت استراتژی «%s» انتخاب شد" % strat_fa
	if is_instance_valid(_tactical_details_lbl):
		_tactical_details_lbl.text = desc

	if bool(sm.get("combat_only", false)):
		_selection_info_lbl.text = "🛡️ کارت «%s» مخصوص زمان دفاع است" % strat_fa
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "این کارت فقط هنگام دفاع در برابر حمله حریف قابل استفاده است. %s" % desc
		return

	var needs_p: bool = bool(sm.get("needs_target_player", false))
	var needs_c: bool = bool(sm.get("needs_target_continent", false))

	if needs_p:
		var opps: Array[int] = _get_valid_opponent_targets_for_strategy(selected_strategy_name)
		if opps.is_empty():
			_selection_info_lbl.text = "⚡ «%s» — حریف واجد شرایطی یافت نشد" % strat_fa
			if is_instance_valid(_tactical_details_lbl):
				_tactical_details_lbl.text = "هیچ حریفی کارت واجد شرایط برای اجرای این استراتژی ندارد."
			return
		if selected_target_player == 0 or not opps.has(selected_target_player):
			selected_target_player = opps[0]

		var opp_st: Dictionary = players_state.get(selected_target_player, {})
		var opp_c_cnt: int = _sum_dict_values(opp_st.get("continents", {}) as Dictionary)
		var opp_s_cnt: int = _to_int(opp_st.get("strategies_count", 0))
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "%s | حریف انتخابی: %s (🗺️ %s قاره • ⚡ %s استراتژی)" % [
				desc,
				_get_player_name(selected_target_player),
				Risk3DFactory.fa_digits(opp_c_cnt),
				Risk3DFactory.fa_digits(opp_s_cnt),
			]

		if opps.size() > 1:
			var btn_cycle_opp: Button = _make_styled_button(
				"🎯 هدف: %s ↻" % _get_player_name(selected_target_player),
				Color(0.28, 0.16, 0.10, 0.96),
				Color(0.96, 0.80, 0.28),
				25,
				12
			)
			btn_cycle_opp.custom_minimum_size = Vector2(185, 50)
			btn_cycle_opp.pressed.connect(func() -> void:
				AudioManager.sfx_tap()
				var cur_i: int = opps.find(selected_target_player)
				selected_target_player = opps[(cur_i + 1) % opps.size()]
				selected_target_continent = ""
				_refresh_all_3d_and_hud()
			)
			_action_buttons_row.add_child(btn_cycle_opp)

	if needs_c and selected_target_player > 0:
		var opp_conts: Dictionary = players_state.get(selected_target_player, {}).get("continents", {})
		var valid_c: Array[String] = []
		for ck: Variant in opp_conts.keys():
			if _to_int(opp_conts[ck]) > 0:
				valid_c.append(str(ck))
		valid_c.sort()
		if valid_c.is_empty():
			_selection_info_lbl.text = "%s هیچ کارت قاره‌ای برای تخریب ندارد." % _get_player_name(selected_target_player)
			return
		if selected_target_continent == "" or not valid_c.has(selected_target_continent):
			selected_target_continent = valid_c[0]

		_selection_info_lbl.text = "💥 تخریب ۱ قاره از %s در «%s»" % [
			_get_player_name(selected_target_player),
			_continent_fa(selected_target_continent)
		]
		if is_instance_valid(_tactical_details_lbl):
			_tactical_details_lbl.text = "قاره هدف: «%s» (تعداد کارت حریف: ×%s) — برای تغییر، روی قاره‌های سبز روی میز بزنید. %s" % [
				_continent_fa(selected_target_continent),
				Risk3DFactory.fa_digits(_to_int(opp_conts.get(selected_target_continent, 0))),
				desc,
			]

	var btn_play: Button = _make_styled_button(
		"⚡ اجرای «%s»" % strat_fa,
		Color(0.14, 0.38, 0.22, 0.98),
		Color(0.42, 0.92, 0.58),
		27,
		12,
		true
	)
	btn_play.custom_minimum_size = Vector2(225, 50)
	btn_play.pressed.connect(_send_use_strategy)
	_action_buttons_row.add_child(btn_play)

# ==============================================================================
# 6. 3D RAYCAST INTERACTION (TABLE, CONTINENTS, DECKS, STATIONS, DICE ARENA)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _is_hud_overlay_blocking():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down_pos = event.position
			_pointer_is_down = true
		else:
			if _pointer_is_down and event.position.distance_to(_pointer_down_pos) <= TAP_MAX_DRAG_PX:
				_perform_3d_tabletop_raycast(event.position)
			_pointer_is_down = false
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down_pos = event.position
			_pointer_is_down = true
		else:
			if _pointer_is_down and event.position.distance_to(_pointer_down_pos) <= TAP_MAX_DRAG_PX:
				_perform_3d_tabletop_raycast(event.position)
			_pointer_is_down = false

func _perform_3d_tabletop_raycast(screen_pos: Vector2) -> void:
	if screen_pos.y >= 1386.0 or screen_pos.y <= 388.0:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * 12.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(query)

	if hit.is_empty() or not hit.has("collider"):
		return

	var col: Object = hit["collider"]
	if not (col is Node) or not col.has_meta("interact_type"):
		return

	var itype: String = str(col.get_meta("interact_type"))
	AudioManager.sfx_tap()
	match itype:
		"deck":
			var dtype_str: String = str(col.get_meta("deck_type"))
			_on_3d_deck_clicked(dtype_str)
		"continent":
			var c_id: String = str(col.get_meta("continent"))
			_on_3d_continent_clicked(c_id)
		"station":
			var p_idx: int = _to_int(col.get_meta("player_index"))
			_on_3d_station_clicked(p_idx)
		"dice_arena":
			_on_3d_dice_arena_clicked()

func _on_3d_dice_arena_clicked() -> void:
	var atk_id: int = _to_int(active_attack.get("attacker_id", _active_turn))
	var def_id: int = _to_int(active_attack.get("defender_id", 0))
	if game_state == "Attack" and atk_id == my_player_index:
		AudioManager.sfx_button()
		send_move(Commands.Attack, {})
	elif game_state == "AttackerArmy" and atk_id == my_player_index:
		AudioManager.sfx_button()
		send_move(Commands.AttackerArmy, {"count": selected_army_commit})
	elif game_state == "DefenderArmy" and def_id == my_player_index:
		AudioManager.sfx_button()
		send_move(Commands.DefenderArmy, {"count": selected_army_commit})

func _on_3d_deck_clicked(deck_type: String) -> void:
	if not _is_my_turn() or game_state != "Draw":
		show_hint("🃏 کشیدن کارت فقط در ابتدای نوبت شما (فاز کشیدن کارت) مجاز است.")
		return
	var pick: String = "continent" if deck_type == "continent" else "strategy"
	if _first_3d_deck_picked.is_empty():
		_first_3d_deck_picked = pick
		_refresh_floating_hud()
	else:
		var first: String = _first_3d_deck_picked
		_first_3d_deck_picked = ""
		var draw_type: int = 3
		if first == "continent" and pick == "continent":
			draw_type = 1
		elif first == "strategy" and pick == "strategy":
			draw_type = 2
		else:
			draw_type = 3
		_send_draw_card(draw_type)

func _on_hand_card_selected(card_idx: int) -> void:
	if card_idx < 0 or card_idx >= _hand_entries.size():
		return
	var entry: Dictionary = _hand_entries[card_idx]
	var kind: String = str(entry["kind"])
	var cid: String = str(entry["id"])

	if game_state == "Attack" and cid == "Army":
		show_hint("⚠️ پس از شروع نبرد، افزودن کارت ارتش کمکی جدید مجاز نیست!")
		return

	if not _is_my_turn() or game_state != "SelectAction":
		if kind == "continent":
			_inspect_continent_summary(cid)
			_refresh_all_3d_and_hud()
		else:
			var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(cid, {})
			show_hint("⚡ %s: %s" % [str(sm.get("fa", cid)), str(sm.get("desc", ""))])
		return

	if selected_hand_card_idx == card_idx:
		selected_hand_card_idx = -1
		selected_source_continent = ""
		selected_target_continent = ""
		selected_strategy_name = ""
		_inspected_continent_id = ""
	else:
		selected_hand_card_idx = card_idx
		if kind == "continent":
			selected_source_continent = cid
			selected_target_continent = ""
			selected_strategy_name = ""
			_inspected_continent_id = cid
		else:
			selected_strategy_name = cid
			selected_source_continent = ""
			selected_target_continent = ""

	_refresh_all_3d_and_hud()

func _on_3d_continent_clicked(c_id: String) -> void:
	_inspected_continent_id = c_id
	if _is_my_turn() and game_state == "SelectAction" and selected_strategy_name == "Destroy":
		if selected_target_player > 0:
			var opp_c: Dictionary = players_state.get(selected_target_player, {}).get("continents", {})
			if _to_int(opp_c.get(c_id, 0)) > 0:
				selected_target_continent = c_id
				_refresh_all_3d_and_hud()
				return

	if _is_my_turn() and game_state == "SelectAction":
		selected_strategy_name = ""
		selected_hand_card_idx = -1
		var valid_targets: Array[String] = _get_valid_attack_target_continents(selected_source_continent)
		if selected_source_continent != "" and valid_targets.has(c_id):
			# Gamer-friendly: If already selected as target, a second tap on the 3D target continent launches the attack!
			if selected_target_continent == c_id and selected_target_player > 0:
				_send_declare_attack()
				return
			_select_target_continent_for_attack(c_id)
			return
		elif _to_int(my_continents.get(c_id, 0)) > 0:
			selected_source_continent = c_id
			selected_target_continent = ""
			_refresh_all_3d_and_hud()
			return

	_inspect_continent_summary(c_id)
	_refresh_all_3d_and_hud()

func _select_target_continent_for_attack(c_id: String) -> void:
	selected_target_continent = c_id
	_inspected_continent_id = c_id
	var defs: Array[int] = _get_defenders_on_continent(c_id)
	if not defs.is_empty():
		selected_target_player = defs[0]
	_refresh_all_3d_and_hud()

func _on_3d_station_clicked(p_idx: int) -> void:
	if _is_my_turn() and game_state == "SelectAction" and selected_strategy_name in ["Bomb", "Destroy", "Spy"]:
		if p_idx != my_player_index:
			selected_target_player = p_idx
			_refresh_all_3d_and_hud()
			return
	_toggle_opponent_inspector(p_idx)

# ==============================================================================
# 7. COMMAND DISPATCHERS & GAME RULES HELPERS
# ==============================================================================

func _send_draw_card(draw_type: int) -> void:
	if not _is_my_turn() or game_state != "Draw":
		return
	AudioManager.sfx_button()
	_first_3d_deck_picked = ""
	send_move(Commands.Draw_Card, {"draw_type": draw_type})

func _send_declare_attack() -> void:
	if not _is_my_turn() or game_state != "SelectAction":
		return
	if selected_source_continent == "" or selected_target_continent == "" or selected_target_player <= 0:
		return
	AudioManager.sfx_button()
	send_move(Commands.Declare_Attack, {
		"source_continent": selected_source_continent,
		"target_continent": selected_target_continent,
		"target_index": selected_target_player,
	})

func _send_use_strategy() -> void:
	if not _is_my_turn() or game_state != "SelectAction" or selected_strategy_name == "":
		return
	var payload: Dictionary = {"strategy": selected_strategy_name}
	var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(selected_strategy_name, {})
	if bool(sm.get("needs_target_player", false)):
		if selected_target_player <= 0:
			return
		payload["target_index"] = selected_target_player
	if bool(sm.get("needs_target_continent", false)):
		if selected_target_continent == "":
			return
		payload["target_continent"] = selected_target_continent
	AudioManager.sfx_button()
	send_move(Commands.Use_Strategy, payload)

func _get_valid_attack_target_continents(src_c: String) -> Array[String]:
	var res: Array[String] = []
	if src_c == "" or _to_int(my_continents.get(src_c, 0)) <= 0:
		return res

	var candidates: Array = []
	if expand_ignore_adjacency:
		candidates = Risk3DFactory.CONTINENT_META.keys()
	else:
		candidates = (Risk3DFactory.CONTINENT_ADJACENCY.get(src_c, []) as Array).duplicate()
		if not candidates.has(src_c):
			candidates.append(src_c)

	for tc: Variant in candidates:
		var c_str: String = str(tc)
		if not _get_defenders_on_continent(c_str).is_empty():
			res.append(c_str)
	return res

func _get_defenders_on_continent(c_id: String) -> Array[int]:
	var defs: Array[int] = []
	for p_idx: int in range(1, total_players + 1):
		if p_idx == my_player_index:
			continue
		var p_conts: Dictionary = players_state.get(p_idx, {}).get("continents", {})
		if _to_int(p_conts.get(c_id, 0)) > 0:
			defs.append(p_idx)
	return defs

func _get_valid_opponent_targets_for_strategy(strat: String) -> Array[int]:
	var opps: Array[int] = []
	for p_idx: int in range(1, total_players + 1):
		if p_idx == my_player_index:
			continue
		var st: Dictionary = players_state.get(p_idx, {})
		var c_sum: int = _sum_dict_values(st.get("continents", {}) as Dictionary)
		var s_sum: int = _to_int(st.get("strategies_count", 0))
		if strat == "Destroy":
			if c_sum > 0:
				opps.append(p_idx)
		else:
			if c_sum > 0 or s_sum > 0:
				opps.append(p_idx)
	return opps

func _count_my_strategy(strat_name: String) -> int:
	var c: int = 0
	for s: String in my_strategies:
		if s == strat_name:
			c += 1
	return c

# ==============================================================================
# 8. 3D DICE ROLLING & TABLETOP ANIMATIONS
# ==============================================================================

func _spawn_and_roll_3d_dice(atk_dice: Array, def_dice: Array) -> void:
	if not _table_refs.has("dice_arena"):
		return
	var arena: Node3D = _table_refs["dice_arena"]
	for d: Node3D in _dice_nodes:
		if is_instance_valid(d):
			d.queue_free()
	_dice_nodes.clear()

	AudioManager.sfx_dice()
	arena.visible = true

	if _dice_arena_tween and _dice_arena_tween.is_valid():
		_dice_arena_tween.kill()
	_dice_arena_tween = create_tween()
	_dice_arena_tween.set_parallel(true)
	_dice_arena_tween.tween_property(
		arena,
		"position",
		Vector3(0.0, 0.125, -0.02),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dice_arena_tween.tween_property(
		arena,
		"scale",
		Vector3(1.18, 1.18, 1.18),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var total_atk: int = atk_dice.size()
	var atk_spacing: float = 0.084
	var atk_start_x: float = -float(max(0, total_atk - 1)) * atk_spacing * 0.5
	for i: int in range(total_atk):
		var val: int = _to_int(atk_dice[i], 1)
		var die: Node3D = Risk3DFactory.build_3d_die(true, _mats, FontHekayat, val)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos: Vector3 = Vector3(atk_start_x + float(i) * atk_spacing, 0.046, -0.048)
		_animate_single_3d_die(die, target_pos, val, float(i) * 0.06)

	var total_def: int = def_dice.size()
	var def_spacing: float = 0.088
	var def_start_x: float = -float(max(0, total_def - 1)) * def_spacing * 0.5
	for i: int in range(total_def):
		var val: int = _to_int(def_dice[i], 1)
		var die: Node3D = Risk3DFactory.build_3d_die(false, _mats, FontHekayat, val)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos: Vector3 = Vector3(def_start_x + float(i) * def_spacing, 0.046, 0.048)
		_animate_single_3d_die(die, target_pos, val, 0.08 + float(i) * 0.06)

	var return_tw: Tween = create_tween()
	return_tw.tween_interval(4.6)
	return_tw.tween_property(arena, "position", Vector3(0.0, 0.063, -0.435), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tw.parallel().tween_property(arena, "scale", Vector3(0.62, 0.62, 0.62), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tw.tween_callback(func() -> void:
		if is_instance_valid(arena):
			arena.visible = false
	)

func _animate_single_3d_die(die: Node3D, final_pos: Vector3, final_val: int, delay: float) -> void:
	die.position = final_pos + Vector3(randf_range(-0.04, 0.04), 0.22, randf_range(-0.03, 0.03))
	var cube_pivot: Node3D = die.get_node_or_null("CubePivot") as Node3D

	var final_rot: Vector3 = Risk3DFactory.get_die_rotation_for_value(final_val)
	if is_instance_valid(cube_pivot):
		cube_pivot.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
	else:
		die.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))

	var tw: Tween = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(die, "position", final_pos, 0.52).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(cube_pivot):
		tw.parallel().tween_property(
			cube_pivot,
			"rotation_degrees",
			final_rot + Vector3(720.0, 360.0, 0.0),
			0.50
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.parallel().tween_property(
			die,
			"rotation_degrees",
			final_rot + Vector3(720.0, 360.0, 0.0),
			0.50
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_deck_draw_pulse(draw_type: int) -> void:
	var targets: Array = []
	if draw_type in [1, 3] and _table_refs.has("continent_deck"):
		targets.append(_table_refs["continent_deck"]["stack"])
	if draw_type in [2, 3] and _table_refs.has("strategy_deck"):
		targets.append(_table_refs["strategy_deck"]["stack"])
	for st: Variant in targets:
		if is_instance_valid(st):
			var st_node: Node3D = st as Node3D
			var tw: Tween = create_tween()
			tw.tween_property(st_node, "scale", Vector3(1.12, 1.18, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(st_node, "scale", Vector3.ONE, 0.16)

func _animate_returned_continent_cards_to_table(from_continent_id: String, count: int) -> void:
	if count <= 0 or not is_inside_tree():
		return
	var start_pos: Vector3 = Vector3(0.0, 0.09, 0.0)
	if from_continent_id != "" and _continent_nodes.has(from_continent_id):
		start_pos = _continent_nodes[from_continent_id]["base_pos"] + Vector3(0.0, 0.09, 0.0)
	var end_pos: Vector3 = Vector3(-0.34, 0.09, -0.435)
	if _table_refs.has("continent_deck") and is_instance_valid(_table_refs["continent_deck"].get("root", null)):
		end_pos = _table_refs["continent_deck"]["root"].position + Vector3(0.0, 0.04, 0.0)

	var cards_to_fly: int = mini(count, 4)
	for i: int in range(cards_to_fly):
		var fly_card: Node3D = Node3D.new()
		fly_card.name = "ReturnedContinentCard_%d" % i
		var card_mesh: MeshInstance3D = MeshInstance3D.new()
		var b_mesh: BoxMesh = BoxMesh.new()
		b_mesh.size = Vector3(0.11, 0.006, 0.15)
		card_mesh.mesh = b_mesh
		card_mesh.material_override = _mats.get("continent_card_back", _mats.get("gold", null))
		fly_card.add_child(card_mesh)

		var rim_mesh: MeshInstance3D = MeshInstance3D.new()
		var r_box: BoxMesh = BoxMesh.new()
		r_box.size = Vector3(0.116, 0.004, 0.156)
		rim_mesh.mesh = r_box
		rim_mesh.material_override = _mats.get("gold", null)
		fly_card.add_child(rim_mesh)

		add_child(fly_card)
		fly_card.position = start_pos + Vector3(float(i) * 0.015, float(i) * 0.008, 0.0)
		var mid_pos: Vector3 = (start_pos + end_pos) * 0.5 + Vector3(0.0, 0.18, 0.0)
		var delay_s: float = float(i) * 0.09

		var tw: Tween = create_tween()
		if delay_s > 0.0:
			tw.tween_interval(delay_s)
		tw.tween_property(fly_card, "position", mid_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(fly_card, "rotation_degrees", Vector3(0.0, 180.0, 0.0), 0.24)
		tw.tween_property(fly_card, "position", end_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(fly_card, "rotation_degrees", Vector3(0.0, 360.0, 0.0), 0.24)
		tw.tween_callback(func() -> void:
			if is_instance_valid(fly_card):
				fly_card.queue_free()
			_animate_deck_draw_pulse(1)
			_refresh_3d_decks()
		)

func _process(delta: float) -> void:
	_anim_clock += delta
	_update_hud_visibility()

	for c_id: String in _continent_nodes.keys():
		var c_ref: Dictionary = _continent_nodes[c_id]
		var tok: Node3D = c_ref["token_node"]
		if is_instance_valid(tok) and tok.visible:
			tok.rotation.y = _anim_clock * 0.85

		var c_root: Node3D = c_ref["root"]
		if is_instance_valid(c_root):
			var base_p: Vector3 = c_ref["base_pos"]
			var is_elevated: bool = (c_id == selected_source_continent or c_id == selected_target_continent or active_attack.get("source_continent", "") == c_id or active_attack.get("target_continent", "") == c_id)
			var target_y: float = base_p.y + (0.012 if is_elevated else 0.0)
			c_root.position.y = lerpf(c_root.position.y, target_y, 10.0 * delta)

# ==============================================================================
# 9. INSPECTORS & LOG PANEL
# ==============================================================================

func _populate_inspector_filter_chips() -> void:
	if not is_instance_valid(_opponent_quick_row):
		return
	for ch: Node in _opponent_quick_row.get_children():
		ch.queue_free()

	var is_all: bool = (_inspected_player_filter == 0)
	var btn_all: Button = _make_styled_button(
		"👥 همه بازیکنان",
		Color(0.28, 0.20, 0.08, 0.96) if is_all else Color(0.14, 0.10, 0.07, 0.92),
		Color(0.98, 0.84, 0.30) if is_all else Color(0.56, 0.42, 0.24),
		30,
		10,
		is_all
	)
	btn_all.custom_minimum_size = Vector2(180, 52)
	btn_all.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		_inspected_player_filter = 0
		_populate_inspector_filter_chips()
		_rebuild_inspector_cards_view(0)
	)
	_opponent_quick_row.add_child(btn_all)

	for p_idx: int in range(1, total_players + 1):
		var st: Dictionary = players_state.get(p_idx, {})
		var t_cnt: int = (st.get("tokens", []) as Array).size()
		var c_cnt: int = _sum_dict_values(st.get("continents", {}) as Dictionary)
		var s_cnt: int = _to_int(st.get("strategies_count", 0))
		var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE)
		var is_sel: bool = (_inspected_player_filter == p_idx)
		var opp_btn: Button = _make_styled_button(
			"%s (👑%s | 🃏%s)" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(t_cnt), Risk3DFactory.fa_digits(c_cnt + s_cnt)],
			f_col.darkened(0.45) if is_sel else f_col.darkened(0.68),
			Color(0.98, 0.86, 0.32) if is_sel else f_col.lightened(0.18),
			30,
			10,
			is_sel
		)
		opp_btn.custom_minimum_size = Vector2(220, 52)
		var target_p: int = p_idx
		opp_btn.pressed.connect(func() -> void:
			AudioManager.sfx_tap()
			_inspected_player_filter = target_p
			_populate_inspector_filter_chips()
			_rebuild_inspector_cards_view(target_p)
		)
		_opponent_quick_row.add_child(opp_btn)

func _toggle_opponent_inspector(target_p: int = 0) -> void:
	if not is_instance_valid(_inspector_panel):
		return
	if _inspector_panel.visible and target_p == 0 and _inspected_player_filter == 0:
		_inspector_panel.visible = false
		return

	_inspected_player_filter = target_p
	_inspector_panel.visible = true
	if is_instance_valid(_log_panel):
		_log_panel.visible = false
	_inspector_title_lbl.text = "👁️ وضعیت کارت‌ها و دارایی‌های بازیکنان"
	_populate_inspector_filter_chips()
	_rebuild_inspector_cards_view(_inspected_player_filter)

func _rebuild_inspector_cards_view(target_p: int = 0) -> void:
	if not is_instance_valid(_inspector_cards_vbox):
		return
	for ch: Node in _inspector_cards_vbox.get_children():
		ch.queue_free()

	for p_idx: int in range(1, total_players + 1):
		if target_p > 0 and p_idx != target_p:
			continue
		var player_card_box: Control = _build_player_inspector_section(p_idx)
		_inspector_cards_vbox.add_child(player_card_box)

func _build_player_inspector_section(p_idx: int) -> Control:
	var st: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
	var p_name: String = _get_player_name(p_idx)
	var is_me: bool = (p_idx == my_player_index)
	var is_turn: bool = (_active_turn == p_idx)
	var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color(0.84, 0.68, 0.28))

	var section_panel: PanelContainer = PanelContainer.new()
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	section_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.12, 0.085, 0.058, 0.96),
			Color(0.98, 0.84, 0.32) if is_turn else f_col.lightened(0.12),
			16,
			2,
			14,
			10
		)
	)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	section_panel.add_child(vbox)

	var header_hbox: HBoxContainer = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(header_hbox)

	var toks: Array = st.get("tokens", [])
	var conts: Dictionary = st.get("continents", {})
	var total_c: int = _sum_dict_values(conts)
	var total_s: int = my_strategies.size() if is_me else _to_int(st.get("strategies_count", 0))

	var stats_lbl: Label = Label.new()
	stats_lbl.text = "👑 %s/۲ نشان سلطه   |   🗺️ %s کارت قاره   |   ⚡ %s کارت استراتژی" % [
		Risk3DFactory.fa_digits(toks.size()),
		Risk3DFactory.fa_digits(total_c),
		Risk3DFactory.fa_digits(total_s)
	]
	stats_lbl.add_theme_font_override("font", FontHekayat)
	stats_lbl.add_theme_font_size_override("font_size", 30)
	stats_lbl.add_theme_color_override("font_color", Color(0.95, 0.89, 0.74))
	header_hbox.add_child(stats_lbl)

	var name_lbl: Label = Label.new()
	var turn_badge: String = " • 🟢 نوبت فعال" if is_turn else ""
	var me_badge: String = " (شما)" if is_me else ""
	name_lbl.text = "🛡️ %s%s%s" % [p_name, me_badge, turn_badge]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", f_col.lightened(0.38))
	header_hbox.add_child(name_lbl)

	if not toks.is_empty():
		var tok_row: HBoxContainer = HBoxContainer.new()
		tok_row.alignment = BoxContainer.ALIGNMENT_END
		tok_row.add_theme_constant_override("separation", 8)
		vbox.add_child(tok_row)
		for t_id: Variant in toks:
			var c_str: String = str(t_id)
			var c_col: Color = RiskMaterials.CONTINENT_COLORS.get(c_str, Color(0.85, 0.68, 0.22))
			var tok_chip: PanelContainer = PanelContainer.new()
			tok_chip.add_theme_stylebox_override(
				"panel",
				_make_panel_style(c_col.darkened(0.45), Color(0.98, 0.84, 0.28), 10, 2, 12, 6)
			)
			var tl: Label = Label.new()
			tl.text = "👑 نشان سلطه %s" % _continent_fa(c_str)
			tl.add_theme_font_override("font", FontHekayat)
			tl.add_theme_font_size_override("font_size", 29)
			tl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
			tok_chip.add_child(tl)
			tok_row.add_child(tok_chip)

	var cards_scroll: ScrollContainer = ScrollContainer.new()
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.custom_minimum_size = Vector2(0, 190)
	cards_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(cards_scroll)

	var cards_hbox: HBoxContainer = HBoxContainer.new()
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.alignment = BoxContainer.ALIGNMENT_END
	cards_hbox.add_theme_constant_override("separation", 12)
	cards_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	cards_scroll.add_child(cards_hbox)

	var has_any_card: bool = false

	var c_keys: Array = conts.keys()
	c_keys.sort()
	for ck: Variant in c_keys:
		var c_id: String = str(ck)
		var cnt: int = _to_int(conts[ck])
		if cnt <= 0:
			continue
		has_any_card = true
		var c_col: Color = RiskMaterials.CONTINENT_COLORS.get(c_id, Color(0.24, 0.54, 0.36))
		var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
		var has_dom: bool = toks.has(c_id)
		var sub_str: String = ("👑 سلطه تصاحب شد (%s/%s)" if has_dom else "حد نصاب سلطه: %s/%s 👑") % [
			Risk3DFactory.fa_digits(cnt),
			Risk3DFactory.fa_digits(dom_req),
		]
		var card_ctrl: Control = _build_inspector_card_widget(
			"👑" if has_dom else "🗺️",
			_continent_fa(c_id),
			sub_str,
			cnt,
			c_col,
			false,
			p_idx,
			c_id
		)
		cards_hbox.add_child(card_ctrl)

	if is_me:
		var strat_counts: Dictionary = {}
		for s_name: String in my_strategies:
			strat_counts[s_name] = _to_int(strat_counts.get(s_name, 0)) + 1
		var s_keys: Array = strat_counts.keys()
		s_keys.sort()
		for sn: Variant in s_keys:
			has_any_card = true
			var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(str(sn), {})
			var s_col: Color = sm.get("color", Color(0.76, 0.24, 0.24))
			var s_icon: String = str(sm.get("icon", "⚡"))
			var s_title: String = str(sm.get("fa", sn))
			var s_sub: String = str(sm.get("short", "کارت استراتژی"))
			var card_ctrl: Control = _build_inspector_card_widget(
				s_icon,
				s_title,
				s_sub,
				_to_int(strat_counts[sn]),
				s_col,
				false,
				p_idx,
				""
			)
			cards_hbox.add_child(card_ctrl)
	else:
		if total_s > 0:
			has_any_card = true
			if total_s <= 5:
				for _i: int in range(total_s):
					var mystery_card: Control = _build_inspector_card_widget(
						"⚡",
						"کارت استراتژی",
						"مخفی در دست حریف",
						1,
						Color(0.56, 0.16, 0.22),
						true,
						p_idx,
						""
					)
					cards_hbox.add_child(mystery_card)
			else:
				var mystery_stack: Control = _build_inspector_card_widget(
					"⚡",
					"کارت استراتژی",
					"مخفی در دست حریف",
					total_s,
					Color(0.56, 0.16, 0.22),
					true,
					p_idx,
					""
				)
				cards_hbox.add_child(mystery_stack)

	if not has_any_card:
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "هیچ کارتی در دست این بازیکن نیست"
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", FontHekayat)
		empty_lbl.add_theme_font_size_override("font_size", 31)
		empty_lbl.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58))
		cards_hbox.add_child(empty_lbl)

	return section_panel

func _build_inspector_card_widget(
	icon_txt: String,
	title_txt: String,
	sub_txt: String,
	count: int,
	accent_col: Color,
	is_mystery_back: bool,
	owner_p_idx: int,
	continent_id: String
) -> Control:
	var card_panel: PanelContainer = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(168, 178)
	card_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_bg: Color = Color(0.17, 0.08, 0.10, 0.97) if is_mystery_back else Color(0.13, 0.095, 0.065, 0.97)
	var border_col: Color = Color(0.86, 0.66, 0.28) if is_mystery_back else accent_col.lightened(0.22)
	card_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(card_bg, border_col, 14, 2, 10, 8)
	)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(vbox)

	var banner: PanelContainer = PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 48)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_sb: StyleBoxFlat = StyleBoxFlat.new()
	banner_sb.bg_color = accent_col.darkened(0.10)
	banner_sb.set_corner_radius_all(8)
	banner_sb.content_margin_left = 8
	banner_sb.content_margin_right = 8
	banner_sb.content_margin_top = 2
	banner_sb.content_margin_bottom = 2
	banner.add_theme_stylebox_override("panel", banner_sb)
	vbox.add_child(banner)

	var banner_hbox: HBoxContainer = HBoxContainer.new()
	banner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_hbox)

	var badge_lbl: Label = Label.new()
	badge_lbl.text = "❓×" + Risk3DFactory.fa_digits(count) if is_mystery_back else "×" + Risk3DFactory.fa_digits(count)
	badge_lbl.add_theme_font_override("font", FontHekayat)
	badge_lbl.add_theme_font_size_override("font_size", 42)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.45) if count > 1 else Color(1.0, 0.98, 0.92))
	badge_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.96))
	badge_lbl.add_theme_constant_override("outline_size", 6)
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(badge_lbl)

	var ic_lbl: Label = Label.new()
	ic_lbl.text = icon_txt
	ic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ic_lbl.add_theme_font_size_override("font_size", 29)
	ic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(ic_lbl)

	var title_lbl: Label = Label.new()
	title_lbl.text = title_txt
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = sub_txt
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.add_theme_font_override("font", FontHekayat)
	sub_lbl.add_theme_font_size_override("font_size", 27)
	sub_lbl.add_theme_color_override("font_color", Color(0.94, 0.80, 0.48) if is_mystery_back else accent_col.lightened(0.42))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	if continent_id != "" and owner_p_idx != my_player_index:
		card_panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				if _is_my_turn() and game_state == "SelectAction" and selected_strategy_name == "Destroy":
					AudioManager.sfx_tap()
					selected_target_player = owner_p_idx
					selected_target_continent = continent_id
					_inspector_panel.visible = false
					_refresh_all_3d_and_hud()
		)

	return card_panel

func _toggle_camera_zoom() -> void:
	AudioManager.sfx_tap()
	_camera_zoom_mode = (_camera_zoom_mode + 1) % 3
	var table: Node = get_tree().get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		table = get_tree().root.find_child("CafeTable", true, false)

	if _camera_zoom_mode == 0:
		camera_distance = 2.52
		camera_pitch = -0.88
		if is_instance_valid(_btn_zoom):
			_btn_zoom.text = "🔍 نما"
		if is_instance_valid(table):
			if "is_top_down_view" in table and table.is_top_down_view and table.has_method("set_top_down_view"):
				table.set_top_down_view(false, 0.45)
			table.target_distance = camera_distance
			table.target_pitch = camera_pitch
			table.target_yaw = 0.0
	elif _camera_zoom_mode == 1:
		camera_distance = 2.98
		camera_pitch = -0.76
		if is_instance_valid(_btn_zoom):
			_btn_zoom.text = "🔍 سالن"
		if is_instance_valid(table):
			if "is_top_down_view" in table and table.is_top_down_view and table.has_method("set_top_down_view"):
				table.set_top_down_view(false, 0.45)
			table.target_distance = camera_distance
			table.target_pitch = camera_pitch
			table.target_yaw = 0.0
	else:
		if is_instance_valid(_btn_zoom):
			_btn_zoom.text = "🔍 بالا"
		if is_instance_valid(table) and table.has_method("set_top_down_view"):
			table.top_down_target_height = 2.48
			table.set_top_down_view(true, 0.45)

func _format_continent_enemy_compact(c_id: String) -> String:
	var defs: Array[int] = _get_defenders_on_continent(c_id)
	if defs.is_empty():
		return "خالی"
	var parts: Array[String] = []
	for p_idx: int in defs:
		var cnt: int = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		parts.append("%s ×%s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(cnt)])
	return "، ".join(parts)

func _build_my_continents_tactical_summary() -> String:
	var attack_ready: Array[String] = []
	var garrison_only: Array[String] = []
	for c_k: Variant in my_continents.keys():
		var c_id: String = str(c_k)
		var cnt: int = _to_int(my_continents[c_k])
		if cnt <= 0:
			continue
		var dice_n: int = clampi(cnt, 1, 3)
		var tgts: Array[String] = _get_valid_attack_target_continents(c_id)
		if tgts.is_empty():
			garrison_only.append("%s (×%s)" % [_continent_fa(c_id), Risk3DFactory.fa_digits(cnt)])
		else:
			attack_ready.append("%s (×%s • %s تاس • %s هدف)" % [
				_continent_fa(c_id),
				Risk3DFactory.fa_digits(cnt),
				Risk3DFactory.fa_digits(dice_n),
				Risk3DFactory.fa_digits(tgts.size()),
			])
	if not attack_ready.is_empty():
		var txt: String = "آماده حمله: %s — برای انتخاب مبدا، روی قاره سبز روی میز یا کارت دستتان بزنید." % " | ".join(attack_ready)
		if not garrison_only.is_empty():
			txt += " (بدون دشمن مجاور: %s)" % "، ".join(garrison_only)
		return txt
	if not garrison_only.is_empty():
		return "قاره‌های شما (%s) هم‌مرز با نیروی دشمن نیستند — می‌توانید کارت استراتژی بازی کنید یا پایان نوبت بزنید." % "، ".join(garrison_only)
	return "در حال حاضر هیچ قاره‌ای در اختیار ندارید — می‌توانید کارت استراتژی بازی کنید یا پایان نوبت بزنید."

func _build_continent_inspect_text(c_id: String) -> String:
	var c_fa: String = _continent_fa(c_id)
	var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
	var has_tok: bool = board_tokens.has(c_id)
	var parts: Array[String] = []
	for p_idx: int in range(1, total_players + 1):
		var cnt: int = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		if cnt > 0:
			parts.append("%s: ×%s/%s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(cnt), Risk3DFactory.fa_digits(dom_req)])
	var garrison_str: String = " | ".join(parts) if not parts.is_empty() else "بدون نیرو"
	var tok_str: String = "👑 سلطه: %s کارت (%s)" % [
		Risk3DFactory.fa_digits(dom_req),
		"موجود" if has_tok else "تصاحب شده"
	]
	return "🗺️ «%s» — %s — نیروها: %s" % [c_fa, tok_str, garrison_str]

func _inspect_continent_summary(c_id: String) -> void:
	_inspected_continent_id = c_id
	if is_instance_valid(_tactical_details_lbl):
		_tactical_details_lbl.text = _build_continent_inspect_text(c_id)

func _toggle_battle_log_panel() -> void:
	if is_instance_valid(_log_panel):
		_log_panel.visible = not _log_panel.visible
		if _log_panel.visible:
			if is_instance_valid(_inspector_panel):
				_inspector_panel.visible = false
			_rebuild_battle_log_view()

func _rebuild_battle_log_view() -> void:
	if not is_instance_valid(_log_vbox):
		return
	for ch: Node in _log_vbox.get_children():
		ch.queue_free()
	if _battle_logs.is_empty():
		var empty_l: Label = Label.new()
		empty_l.text = "هنوز واقعه‌ای در این نبرد ثبت نشده است."
		empty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_l.add_theme_font_override("font", FontHekayat)
		empty_l.add_theme_font_size_override("font_size", 32)
		empty_l.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
		_log_vbox.add_child(empty_l)
		return
	for line: String in _battle_logs:
		var l: Label = Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", FontHekayat)
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
		_log_vbox.add_child(l)

func _append_battle_log(entry: String) -> void:
	_battle_logs.push_front(entry)
	if _battle_logs.size() > 30:
		_battle_logs.pop_back()
	_rebuild_battle_log_view()

func _show_combat_toast(text: String, duration: float = 3.6) -> void:
	if not is_instance_valid(_combat_banner_panel) or not is_instance_valid(_combat_banner_lbl):
		return
	_combat_banner_lbl.text = text
	_combat_banner_panel.visible = true
	_combat_banner_panel.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_combat_banner_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_combat_banner_panel):
			_combat_banner_panel.visible = false
	)

# ==============================================================================
# 10. UTILITY HELPERS
# ==============================================================================

func _is_my_turn() -> bool:
	return _active_turn == my_player_index

func _get_player_name(p_idx: int) -> String:
	var d: Dictionary = GameManager.get_player_data_by_gamer_id(p_idx)
	var n: String = str(d.get("name", d.get("username", "")))
	if n.strip_edges() == "":
		return "فرمانده %s" % Risk3DFactory.fa_digits(p_idx)
	return n

func _continent_fa(c_id: String) -> String:
	return str(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("fa", c_id))

func _phase_fa(st: String) -> String:
	match st:
		"Draw":
			return "فاز کشیدن کارت"
		"SelectAction":
			return "فاز عملیات"
		"AttackerArmy":
			return "تقویت ارتش مهاجم"
		"DefenderArmy":
			return "تصمیم دفاعی"
		"Attack":
			return "ادامه نبرد"
	return "در حال بازی"

func _format_dice_list(arr: Array) -> String:
	if arr.is_empty():
		return "-"
	var die_icons: Array[String] = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	var parts: Array[String] = []
	for v: Variant in arr:
		var iv: int = clampi(_to_int(v, 1), 1, 6)
		parts.append("%s%s" % [die_icons[iv - 1], Risk3DFactory.fa_digits(iv)])
	return "[" + " ، ".join(parts) + "]"

func _sum_dict_values(d: Dictionary) -> int:
	var total: int = 0
	for k: Variant in d.keys():
		total += _to_int(d[k])
	return total

func _to_int(val: Variant, default_val: int = 0) -> int:
	if val == null:
		return default_val
	var t: int = typeof(val)
	if t == TYPE_INT:
		return int(val)
	if t == TYPE_FLOAT:
		return int(val)
	if t == TYPE_BOOL:
		return 1 if bool(val) else 0
	if t == TYPE_ARRAY:
		return (val as Array).size()
	if t == TYPE_DICTIONARY:
		return (val as Dictionary).size()
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		var st: String = str(val).strip_edges()
		if st.is_valid_int():
			return st.to_int()
		if st.is_valid_float():
			return int(st.to_float())
		return default_val
	return default_val
