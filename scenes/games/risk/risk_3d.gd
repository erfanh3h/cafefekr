class_name Risk3D
extends BaseGameBoard

# ==============================================================================
# RISK STRIKE (ریسک استرایک) - PREMIUM 3D TABLETOP ENVIRONMENT FOR GODOT 4
# ==============================================================================
# Connects the antique walnut & emerald baize 3D tabletop environment,
# 3D central board, 3D player stations, 3D interactive cards, and 3D dice
# strictly to the existing Python backend protocol (`risk_game_session.py`).

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

# Camera Defaults for CafeTable (Elevated Three-Quarter Tabletop Perspective)
@export var default_three_quarter_view: bool = true
@export var camera_pitch: float = -0.89   # ~ -51 deg elevated three-quarter tabletop perspective
@export var camera_distance: float = 3.08 # Frames the entire walnut table, central board, player stations & 3D card rack

# Shared 3D Meshes & PBR Materials
var _mats: Dictionary = {}
var _rook_mesh: Mesh = null
var _knight_mesh: Mesh = null
var _king_mesh: Mesh = null
var _crown_mesh: Mesh = null

# 3D Scene Graph References
var _table_refs: Dictionary = {}
var _continent_nodes: Dictionary = {} # continent_id -> Dictionary from Risk3DFactory
var _bridge_nodes: Dictionary = {}    # "ContA_ContB" -> MeshInstance3D
var _station_nodes: Dictionary = {}   # player_idx (1..4) -> Dictionary from Risk3DFactory
var _hand_rack_root: Node3D = null
var _hand_card_nodes: Array = []      # Array of Dictionaries from Risk3DFactory.build_3d_card
var _dice_nodes: Array = []           # Active 3D Dice inside _table_refs["dice_arena"]

# Authoritative Backend Game State
var total_players: int = 2
var active_player_indexes: Array = [1, 2]
var _active_turn: int = 1
var game_state: String = "Draw" # "StartGame", "Draw", "SelectAction", "AttackerArmy", "DefenderArmy"
var continent_deck_count: int = 42
var strategy_deck_count: int = 40
var board_tokens: Array = ["Asia", "NorthAmerica", "Europe", "Africa", "Australia", "SouthAmerica"]

# Public Per-Player Data: player_idx (1..4) -> {"continents": Dictionary, "strategies_count": int, "tokens": Array}
var players_state: Dictionary = {
	1: {"continents": {}, "strategies_count": 0, "tokens": []},
	2: {"continents": {}, "strategies_count": 0, "tokens": []},
	3: {"continents": {}, "strategies_count": 0, "tokens": []},
	4: {"continents": {}, "strategies_count": 0, "tokens": []},
}

# Local Player Private Hand Data (`UserData`)
var my_continents: Dictionary = {} # continent_id -> int count
var my_strategies: Array = []      # Array[String] of strategy card names in hand
var my_tokens: Array = []          # Array[String] of conquered continent token names

# Active Combat State (`active_attack`)
var active_attack: Dictionary = {} # {"attacker_id", "defender_id", "source_continent", "target_continent", "attacker_army", "defender_army"}
var expand_ignore_adjacency: bool = false

# Interactive Selection State (for 3D Board & 3D Cards)
var selected_source_continent: String = ""
var selected_target_continent: String = ""
var selected_target_player: int = 0
var selected_hand_card_idx: int = -1
var selected_strategy_name: String = ""
var selected_army_commit: int = 0
var hovered_card_idx: int = -1
var _first_3d_deck_picked: String = ""

# Match Lifecycle & Animation Clock
var _match_started: bool = false
var _anim_clock: float = 0.0
var _battle_logs: Array[String] = []

# Raycast Click Tracking
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_is_down: bool = false
const TAP_MAX_DRAG_PX: float = 16.0

# Floating UI Layer & HUD References (Parented inside BaseGameHUD below StartGameOverlay)
var _fallback_canvas: CanvasLayer = null
var _hud_root: Control = null
var _opponent_quick_row: HBoxContainer = null
var _phase_banner_lbl: Label = null
var _selection_info_lbl: Label = null
var _sub_scroll: ScrollContainer = null
var _action_buttons_row: HBoxContainer = null
var _sub_options_row: HBoxContainer = null
var _hand_filter_bar: HBoxContainer = null
var _combat_banner_panel: PanelContainer = null
var _combat_banner_lbl: Label = null
var _inspector_panel: PanelContainer = null
var _inspector_title_lbl: Label = null
var _inspector_body_lbl: Label = null
var _log_panel: PanelContainer = null
var _log_vbox: VBoxContainer = null

func _ready() -> void:
	game_type = GameTypes.RISK
	_mats = RiskMaterials.create_palette()
	_load_3d_meshes()
	_detect_players_and_local_id()
	_build_3d_tabletop_world()
	_build_floating_ui()

	if not NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.connect(_on_risk_event_received)

	super._ready()
	_update_hud_visibility()
	_refresh_all_3d_and_hud()

func cleanup_board() -> void:
	if NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.disconnect(_on_risk_event_received)
	if is_instance_valid(_hud_root):
		_hud_root.queue_free()
		_hud_root = null
	if is_instance_valid(_fallback_canvas):
		_fallback_canvas.queue_free()
		_fallback_canvas = null

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
	if GameManager.my_player_index > 0:
		my_player_index = GameManager.my_player_index
	else:
		my_player_index = 1
	total_players = clampi(max(2, GameManager.match_players.size()), 2, 4)
	active_player_indexes.clear()
	for i in range(1, total_players + 1):
		active_player_indexes.append(i)

# Ensures the Risk controller UI and 3D Hand Rack are NEVER shown during StartGameOverlay or GameResultDialog
func _is_hud_overlay_blocking() -> bool:
	if not _match_started or not GameManager.is_game_active:
		return true
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		if "is_start_overlay_dismissed" in hud and not bool(hud.is_start_overlay_dismissed):
			return true
		var start_ov = hud.get_node_or_null("StartGameOverlay") as Control
		if is_instance_valid(start_ov) and start_ov.visible:
			return true
		var res_dlg = hud.get_node_or_null("GameResultDialog") as Control
		if is_instance_valid(res_dlg) and res_dlg.visible:
			return true
	return false

func _update_hud_visibility() -> void:
	if not is_instance_valid(_hud_root):
		return
	if is_instance_valid(_fallback_canvas) and _hud_root.get_parent() == _fallback_canvas:
		var hud = get_tree().root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud):
			_hud_root.reparent(hud)
			var start_ov = hud.get_node_or_null("StartGameOverlay")
			if is_instance_valid(start_ov):
				hud.move_child(_hud_root, start_ov.get_index())

	var should_show = not _is_hud_overlay_blocking()
	if _hud_root.visible != should_show:
		_hud_root.visible = should_show
	if is_instance_valid(_hand_rack_root):
		_hand_rack_root.visible = should_show

# ==============================================================================
# 1. 3D TABLETOP WORLD CONSTRUCTION
# ==============================================================================

func _build_3d_tabletop_world() -> void:
	# 1. Main Walnut Table Surround, Mahogany Board Frame, Emerald Velvet Bed, Decks & Dice Arena
	_table_refs = Risk3DFactory.build_tabletop_and_board_frame(self, _mats, FontHekayat)

	# 2. Sea-Lane Bridges between Connected Continents
	_bridge_nodes = Risk3DFactory.build_sea_lane_bridges(self, _mats)

	# 3. 6 Raised 3D Continents on the Central Board
	_continent_nodes.clear()
	for c_id in Risk3DFactory.CONTINENT_META.keys():
		_continent_nodes[c_id] = Risk3DFactory.build_continent_node(
			self,
			c_id,
			_mats,
			FontHekayat,
			_rook_mesh,
			_knight_mesh,
			_crown_mesh
		)

	# 4. 3D Player Stations Around the Table
	_rebuild_player_stations_3d()

	# 5. Local Player's Tilted 3D Card Rack (Positioned at z=+0.48 so it sits clearly above the command panel)
	_hand_rack_root = Node3D.new()
	_hand_rack_root.name = "LocalPlayerCardRack3D"
	_hand_rack_root.position = Vector3(0.0, 0.095, 0.48)
	_hand_rack_root.rotation_degrees = Vector3(34.0, 0.0, 0.0) # Tilted towards the elevated 3/4 camera for clear reading
	add_child(_hand_rack_root)

	var ledge_mi = MeshInstance3D.new()
	var ledge_bm = BoxMesh.new()
	ledge_bm.size = Vector3(1.10, 0.014, 0.045)
	ledge_bm.material = _mats["mahogany"]
	ledge_mi.mesh = ledge_bm
	ledge_mi.position = Vector3(0.0, -0.052, 0.036)
	_hand_rack_root.add_child(ledge_mi)

func _rebuild_player_stations_3d() -> void:
	for k in _station_nodes.keys():
		var st = _station_nodes[k]
		if st.has("root") and is_instance_valid(st["root"]):
			st["root"].queue_free()
	_station_nodes.clear()

	var my_id = clampi(my_player_index, 1, 4)
	var opponents: Array[int] = []
	for idx in range(1, total_players + 1):
		if idx != my_id:
			opponents.append(idx)

	# Local Player Station at Near Side of Central Board
	_station_nodes[my_id] = Risk3DFactory.build_player_station(
		self,
		my_id,
		Vector3(0.0, 0.026, 0.35),
		0.0,
		true,
		_mats,
		FontHekayat,
		_king_mesh
	)

	# Opponent Stations Around Top/Sides of Table
	var opp_positions: Array = []
	if opponents.size() == 1:
		opp_positions = [Vector3(0.0, 0.026, -0.54)]
	elif opponents.size() == 2:
		opp_positions = [Vector3(-0.34, 0.026, -0.54), Vector3(0.34, 0.026, -0.54)]
	else:
		opp_positions = [
			Vector3(-0.42, 0.026, -0.54),
			Vector3(0.0, 0.026, -0.55),
			Vector3(0.42, 0.026, -0.54),
		]

	for i in range(opponents.size()):
		var opp_id: int = opponents[i]
		var pos: Vector3 = opp_positions[min(i, opp_positions.size() - 1)]
		_station_nodes[opp_id] = Risk3DFactory.build_player_station(
			self,
			opp_id,
			pos,
			0.0,
			false,
			_mats,
			FontHekayat,
			_king_mesh
		)

# ==============================================================================
# 2. RESTRUCTURED FLOATING TABLETOP HUD (ZERO OVERLAP WITH BOTTOM 8 BUTTONS)
# ==============================================================================
# Screen Layout (1080x1920):
# - 0 .. 335px: BaseGameHUD TopHeader (Player cards, crowns, timer)
# - 340 .. 412px: Top Tactical Strip (Opponent cards inspector, Battle log, Opponent chips)
# - 415 .. 1445px: Unobstructed 3D Tabletop, Central Board, Stations & 3D Hand Rack
# - 1450 .. 1750px: Elevated Command Panel (sits cleanly ABOVE BaseGameHUD's BottomBar!)
# - 1766 .. 1920px: BaseGameHUD BottomBar (the 8 standard game scene buttons)

func _build_floating_ui() -> void:
	_fallback_canvas = CanvasLayer.new()
	_fallback_canvas.layer = 5
	add_child(_fallback_canvas)

	_hud_root = Control.new()
	_hud_root.name = "RiskTabletopHUD"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.visible = false
	_fallback_canvas.add_child(_hud_root)

	# 1. Top Tactical Bar (Right below TopHeader: y = 340..410px)
	var top_bar = HBoxContainer.new()
	top_bar.anchor_left = 0.025
	top_bar.anchor_right = 0.975
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 340.0
	top_bar.offset_bottom = 408.0
	top_bar.alignment = BoxContainer.ALIGNMENT_END
	top_bar.add_theme_constant_override("separation", 10)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_bar)

	var opp_scroll = ScrollContainer.new()
	opp_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opp_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	top_bar.add_child(opp_scroll)

	_opponent_quick_row = HBoxContainer.new()
	_opponent_quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_quick_row.add_theme_constant_override("separation", 8)
	opp_scroll.add_child(_opponent_quick_row)

	var btn_opponents = _make_bronze_button("👁️ کارت‌های حریفان", Color(0.12, 0.26, 0.18, 0.95), Color(0.42, 0.92, 0.60), 26)
	btn_opponents.custom_minimum_size = Vector2(220, 60)
	btn_opponents.pressed.connect(func():
		AudioManager.sfx_button()
		_toggle_opponent_inspector(0)
	)
	top_bar.add_child(btn_opponents)

	var btn_log = _make_bronze_button("📜 گزارش نبرد", Color(0.20, 0.14, 0.08, 0.95), Color(0.90, 0.72, 0.32), 26)
	btn_log.custom_minimum_size = Vector2(180, 60)
	btn_log.pressed.connect(func():
		AudioManager.sfx_button()
		_toggle_battle_log_panel()
	)
	top_bar.add_child(btn_log)

	# 2. Floating Combat Resolution Toast Banner (y = 420..540px)
	_combat_banner_panel = PanelContainer.new()
	_combat_banner_panel.anchor_left = 0.05
	_combat_banner_panel.anchor_right = 0.95
	_combat_banner_panel.anchor_top = 0.0
	_combat_banner_panel.anchor_bottom = 0.0
	_combat_banner_panel.offset_top = 418.0
	_combat_banner_panel.offset_bottom = 548.0
	_combat_banner_panel.visible = false
	_combat_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_banner_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.07, 0.05, 0.95), Color(0.98, 0.76, 0.26), 18, 3))
	_hud_root.add_child(_combat_banner_panel)

	_combat_banner_lbl = Label.new()
	_combat_banner_lbl.add_theme_font_override("font", FontHekayat)
	_combat_banner_lbl.add_theme_font_size_override("font_size", 30)
	_combat_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_combat_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_banner_panel.add_child(_combat_banner_lbl)

	# 3. Opponent Station & Public Cards Inspector Modal
	_inspector_panel = PanelContainer.new()
	_inspector_panel.anchor_left = 0.05
	_inspector_panel.anchor_right = 0.95
	_inspector_panel.anchor_top = 0.24
	_inspector_panel.anchor_bottom = 0.62
	_inspector_panel.visible = false
	_inspector_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.07, 0.05, 0.97), Color(0.92, 0.74, 0.30), 20, 3))
	_hud_root.add_child(_inspector_panel)

	var insp_vbox = VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 12)
	_inspector_panel.add_child(insp_vbox)

	var insp_header = HBoxContainer.new()
	insp_vbox.add_child(insp_header)

	var btn_close_insp = _make_bronze_button("✖ بستن", Color(0.40, 0.12, 0.12, 0.95), Color(0.98, 0.45, 0.45), 25)
	btn_close_insp.custom_minimum_size = Vector2(130, 52)
	btn_close_insp.pressed.connect(func(): _inspector_panel.visible = false)
	insp_header.add_child(btn_close_insp)

	_inspector_title_lbl = Label.new()
	_inspector_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inspector_title_lbl.add_theme_font_override("font", FontHekayat)
	_inspector_title_lbl.add_theme_font_size_override("font_size", 32)
	_inspector_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	insp_header.add_child(_inspector_title_lbl)

	var insp_scroll = ScrollContainer.new()
	insp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp_vbox.add_child(insp_scroll)

	_inspector_body_lbl = Label.new()
	_inspector_body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inspector_body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_inspector_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_body_lbl.add_theme_font_override("font", FontHekayat)
	_inspector_body_lbl.add_theme_font_size_override("font_size", 28)
	_inspector_body_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	insp_scroll.add_child(_inspector_body_lbl)

	# 4. Battle Log Floating Drawer
	_log_panel = PanelContainer.new()
	_log_panel.anchor_left = 0.05
	_log_panel.anchor_right = 0.95
	_log_panel.anchor_top = 0.24
	_log_panel.anchor_bottom = 0.62
	_log_panel.visible = false
	_log_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.09, 0.06, 0.04, 0.97), Color(0.86, 0.70, 0.30), 20, 3))
	_hud_root.add_child(_log_panel)

	var log_outer = VBoxContainer.new()
	log_outer.add_theme_constant_override("separation", 10)
	_log_panel.add_child(log_outer)

	var log_top = HBoxContainer.new()
	log_outer.add_child(log_top)
	var btn_close_log = _make_bronze_button("✖ بستن", Color(0.40, 0.12, 0.12, 0.95), Color(0.98, 0.45, 0.45), 25)
	btn_close_log.custom_minimum_size = Vector2(130, 52)
	btn_close_log.pressed.connect(func(): _log_panel.visible = false)
	log_top.add_child(btn_close_log)

	var log_title = Label.new()
	log_title.text = "📜 وقایع‌نگار فرماندهی"
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	log_title.add_theme_font_override("font", FontHekayat)
	log_title.add_theme_font_size_override("font_size", 32)
	log_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	log_top.add_child(log_title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_outer.add_child(scroll)
	_log_vbox = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_log_vbox)

	# 5. Elevated Tactical Command Panel (Docked cleanly ABOVE the bottom 8 buttons of BaseGameHUD!)
	# BaseGameHUD BottomBar occupies offset_top = -154.0 .. 0.0.
	# Placing our command dock at offset_bottom = -168.0 guarantees ZERO overlap with the 8 bottom buttons!
	var command_dock = PanelContainer.new()
	command_dock.name = "ElevatedCommandDock"
	command_dock.anchor_left = 0.02
	command_dock.anchor_right = 0.98
	command_dock.anchor_top = 1.0
	command_dock.anchor_bottom = 1.0
	command_dock.offset_top = -468.0
	command_dock.offset_bottom = -168.0
	command_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	command_dock.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.07, 0.05, 0.93), Color(0.88, 0.70, 0.30), 22, 3))
	_hud_root.add_child(command_dock)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 8)
	command_dock.add_child(dock_vbox)

	_phase_banner_lbl = Label.new()
	_phase_banner_lbl.add_theme_font_override("font", FontHekayat)
	_phase_banner_lbl.add_theme_font_size_override("font_size", 32)
	_phase_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52))
	_phase_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock_vbox.add_child(_phase_banner_lbl)

	_selection_info_lbl = Label.new()
	_selection_info_lbl.add_theme_font_override("font", FontHekayat)
	_selection_info_lbl.add_theme_font_size_override("font_size", 26)
	_selection_info_lbl.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	_selection_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock_vbox.add_child(_selection_info_lbl)

	_sub_scroll = ScrollContainer.new()
	_sub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sub_scroll.custom_minimum_size = Vector2(0, 58)
	_sub_scroll.visible = false
	dock_vbox.add_child(_sub_scroll)

	_sub_options_row = HBoxContainer.new()
	_sub_options_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_options_row.add_theme_constant_override("separation", 10)
	_sub_scroll.add_child(_sub_options_row)

	var act_scroll = ScrollContainer.new()
	act_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_scroll.custom_minimum_size = Vector2(0, 66)
	dock_vbox.add_child(act_scroll)

	_action_buttons_row = HBoxContainer.new()
	_action_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_buttons_row.add_theme_constant_override("separation", 12)
	act_scroll.add_child(_action_buttons_row)

	var hand_scroll = ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size = Vector2(0, 56)
	dock_vbox.add_child(hand_scroll)

	_hand_filter_bar = HBoxContainer.new()
	_hand_filter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_filter_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_filter_bar.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(_hand_filter_bar)

func _make_panel_style(bg: Color, border: Color, radius: int = 16, border_w: int = 2) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 10
	return sb

func _make_bronze_button(text: String, bg: Color, border: Color, font_sz: int = 26) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	var sb_norm = _make_panel_style(bg, border, 14, 2)
	var sb_hover = _make_panel_style(bg.lightened(0.14), border.lightened(0.20), 14, 2)
	var sb_press = _make_panel_style(bg.darkened(0.15), border, 14, 2)
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)
	return btn

# ==============================================================================
# 3. BASE_GAME_BOARD HOOKS & NETWORK SYNCHRONIZATION
# ==============================================================================

func setup_board(game_data: Dictionary) -> void:
	_detect_players_and_local_id()
	_sync_full_game_data(game_data)
	_update_hud_visibility()
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
	var g_data = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_sync_full_game_data(g_data)
	var u_data = payload.get("user_data", {})
	if typeof(u_data) == TYPE_DICTIONARY and not u_data.is_empty():
		_sync_private_user_data(u_data)
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
			var gid = _to_int(payload.get("gamer_id", _active_turn))
			var dtype = _to_int(payload.get("draw_type", 1))
			if payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"])
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"])
			game_state = str(payload.get("game_state", "SelectAction"))
			AudioManager.sfx_add_piece()
			_animate_deck_draw_pulse(dtype)
			_restart_hud_turn_timer()
			_append_battle_log("🃏 %s از دسته کارت کشید." % _get_player_name(gid))
			_refresh_all_3d_and_hud()

		Commands.Draw_Result_Private:
			if payload.has("new_user_data") and typeof(payload["new_user_data"]) == TYPE_DICTIONARY:
				_sync_private_user_data(payload["new_user_data"])
			_refresh_all_3d_and_hud()

		Commands.Declare_Attack:
			var atk_id = _to_int(payload.get("gamer_id", _active_turn))
			var def_id = _to_int(payload.get("target_index", 0))
			var src_c = str(payload.get("source_continent", ""))
			var tgt_c = str(payload.get("target_continent", ""))
			game_state = str(payload.get("game_state", "AttackerArmy"))
			active_attack = {
				"attacker_id": atk_id,
				"defender_id": def_id,
				"source_continent": src_c,
				"target_continent": tgt_c,
				"attacker_army": 0,
				"defender_army": 0,
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
			var atk_id = _to_int(payload.get("gamer_id", active_attack.get("attacker_id", _active_turn)))
			var def_id = _to_int(payload.get("target_index", active_attack.get("defender_id", 0)))
			var committed = _to_int(payload.get("count", 0))
			active_attack["attacker_id"] = atk_id
			active_attack["defender_id"] = def_id
			active_attack["attacker_army"] = committed
			game_state = str(payload.get("game_state", "DefenderArmy"))
			selected_army_commit = 0
			_restart_hud_turn_timer()
			_show_combat_toast("🗡️ مهاجم %s کارت ارتش کمکی وارد نبرد کرد. اکنون نوبت تصمیم مدافع (%s) است!" % [
				Risk3DFactory.fa_digits(committed),
				_get_player_name(def_id)
			])
			_refresh_all_3d_and_hud()

		Commands.Attack, Commands.Cancel_Attack:
			_handle_combat_resolution_payload(payload)

		Commands.Strategy_Result:
			_handle_strategy_result_payload(payload)

		Commands.Pass_Turn:
			var gid = _to_int(payload.get("gamer_id", payload.get("gamer_index", _active_turn)))
			if payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"])
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"])
			_append_battle_log("⏭️ %s نوبت خود را به پایان رساند." % _get_player_name(gid))
			_refresh_all_3d_and_hud()

func _sync_full_game_data(g_data: Dictionary) -> void:
	if g_data.has("current_turn"):
		_active_turn = _to_int(g_data.get("current_turn", 1))
	if g_data.has("active_player_indexes") and typeof(g_data["active_player_indexes"]) == TYPE_ARRAY:
		active_player_indexes.clear()
		for idx in g_data["active_player_indexes"]:
			active_player_indexes.append(_to_int(idx))
		if active_player_indexes.size() >= 2:
			var max_idx = 2
			for idx in active_player_indexes:
				max_idx = max(max_idx, idx)
			if max_idx != total_players:
				total_players = clampi(max_idx, 2, 4)
				_rebuild_player_stations_3d()
	if g_data.has("continents"):
		continent_deck_count = _to_int(g_data.get("continents", continent_deck_count))
	if g_data.has("strategies"):
		strategy_deck_count = _to_int(g_data.get("strategies", strategy_deck_count))
	if g_data.has("tokens") and typeof(g_data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(g_data["tokens"])
	if g_data.has("game_state"):
		game_state = str(g_data.get("game_state", game_state))
	if g_data.has("players_data") and typeof(g_data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(g_data["players_data"])
	if g_data.has("active_attack"):
		if typeof(g_data["active_attack"]) == TYPE_DICTIONARY:
			active_attack = g_data["active_attack"].duplicate(true)
		else:
			active_attack.clear()

func _parse_board_tokens(raw_tokens: Array) -> void:
	board_tokens.clear()
	for t in raw_tokens:
		board_tokens.append(str(t))

func _parse_players_data_array(p_list: Array) -> void:
	for item in p_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var p_idx = _to_int(item.get("index", 0))
		if p_idx >= 1 and p_idx <= 4:
			_apply_single_player_public_data(p_idx, item)

func _apply_single_player_public_data(p_idx: int, item: Dictionary) -> void:
	var c_dict: Dictionary = {}
	var raw_c = item.get("continents", {})
	if typeof(raw_c) == TYPE_DICTIONARY:
		for k in raw_c.keys():
			var cnt = _to_int(raw_c[k])
			if cnt > 0:
				c_dict[str(k)] = cnt

	var t_arr: Array = []
	var raw_t = item.get("tokens", [])
	if typeof(raw_t) == TYPE_ARRAY:
		for t in raw_t:
			t_arr.append(str(t))

	var s_cnt: int = _to_int(item.get("strategies_count", 0))
	if item.has("strategies") and typeof(item["strategies"]) == TYPE_ARRAY:
		s_cnt = item["strategies"].size()

	players_state[p_idx] = {
		"continents": c_dict,
		"strategies_count": s_cnt,
		"tokens": t_arr,
	}

func _sync_private_user_data(u_data: Dictionary) -> void:
	var old_id = my_player_index
	if u_data.has("index"):
		var idx = _to_int(u_data.get("index", my_player_index))
		if idx >= 1 and idx <= 4:
			my_player_index = idx
			GameManager.my_player_index = idx
	if my_player_index != old_id:
		_rebuild_player_stations_3d()

	if u_data.has("continents") and typeof(u_data["continents"]) == TYPE_DICTIONARY:
		my_continents.clear()
		for k in u_data["continents"].keys():
			var cnt = _to_int(u_data["continents"][k])
			if cnt > 0:
				my_continents[str(k)] = cnt

	if u_data.has("strategies"):
		my_strategies.clear()
		var raw_s = u_data["strategies"]
		if typeof(raw_s) == TYPE_ARRAY:
			for s_name in raw_s:
				my_strategies.append(str(s_name))
		elif typeof(raw_s) == TYPE_DICTIONARY:
			for s_name in raw_s.keys():
				var c = _to_int(raw_s[s_name])
				for _i in range(c):
					my_strategies.append(str(s_name))

	if u_data.has("tokens") and typeof(u_data["tokens"]) == TYPE_ARRAY:
		my_tokens.clear()
		for t in u_data["tokens"]:
			my_tokens.append(str(t))

	var my_id = clampi(my_player_index, 1, 4)
	players_state[my_id] = {
		"continents": my_continents.duplicate(true),
		"strategies_count": my_strategies.size(),
		"tokens": my_tokens.duplicate(),
	}
	_rebuild_3d_hand_rack()

func _handle_combat_resolution_payload(data: Dictionary) -> void:
	if data.has("players_data") and typeof(data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(data["players_data"])
	if data.has("tokens") and typeof(data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(data["tokens"])
	if data.has("game_state"):
		game_state = str(data.get("game_state", "SelectAction"))
	else:
		game_state = "SelectAction"

	var canceled = bool(data.get("canceled", false))
	var atk_id = _to_int(data.get("attacker_id", active_attack.get("attacker_id", _active_turn)))
	var def_id = _to_int(data.get("defender_id", active_attack.get("defender_id", 0)))
	var src_c = str(data.get("source_continent", active_attack.get("source_continent", "")))
	var tgt_c = str(data.get("target_continent", active_attack.get("target_continent", "")))

	active_attack.clear()
	selected_source_continent = ""
	selected_target_continent = ""
	selected_army_commit = 0
	_restart_hud_turn_timer()

	if canceled:
		_show_combat_toast("🛡️ مدافع (%s) با کارت «لغو تهاجم» حمله را متوقف کرد!" % _get_player_name(def_id))
		_append_battle_log("🛡️ %s حمله به %s را با کارت Cancel لغو کرد." % [_get_player_name(def_id), _continent_fa(tgt_c)])
		_refresh_all_3d_and_hud()
		return

	var atk_dice: Array = data.get("attacker_dice", []) if typeof(data.get("attacker_dice", [])) == TYPE_ARRAY else []
	var def_dice: Array = data.get("defender_dice", []) if typeof(data.get("defender_dice", [])) == TYPE_ARRAY else []
	var atk_loss = _to_int(data.get("attacker_losses", 0))
	var def_loss = _to_int(data.get("defender_losses", 0))
	var conquered = bool(data.get("conquered", false))

	if not atk_dice.is_empty() or not def_dice.is_empty():
		_spawn_and_roll_3d_dice(atk_dice, def_dice)

	var atk_str = _format_dice_list(atk_dice)
	var def_str = _format_dice_list(def_dice)
	var msg = "🎲 نتیجه نبرد در «%s»:\nتاس مهاجم (%s): %s | تاس مدافع (%s): %s\nتلفات مهاجم: %s | تلفات مدافع: %s" % [
		_continent_fa(tgt_c),
		_get_player_name(atk_id),
		atk_str,
		_get_player_name(def_id),
		def_str,
		Risk3DFactory.fa_digits(atk_loss),
		Risk3DFactory.fa_digits(def_loss),
	]
	if conquered:
		msg += "  🏆 قاره فتح شد!"
	_show_combat_toast(msg, 5.2)
	_append_battle_log("🎲 نبرد %s -> %s: تاس مهاجم %s، مدافع %s (تلفات %s/%s)" % [
		_continent_fa(src_c), _continent_fa(tgt_c), atk_str, def_str,
		Risk3DFactory.fa_digits(atk_loss), Risk3DFactory.fa_digits(def_loss)
	])
	_refresh_all_3d_and_hud()

func _handle_strategy_result_payload(data: Dictionary) -> void:
	var gid = _to_int(data.get("gamer_id", _active_turn))
	var strat = str(data.get("strategy", ""))
	var tgt_id = _to_int(data.get("target_index", 0))
	if data.has("players_data") and typeof(data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(data["players_data"])
	if data.has("tokens") and typeof(data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(data["tokens"])
	if data.has("game_state"):
		game_state = str(data["game_state"])

	if strat == "Expand" and gid == my_player_index:
		expand_ignore_adjacency = true

	var strat_fa = Risk3DFactory.STRATEGY_META.get(strat, {}).get("fa", strat)
	var target_txt = (" علیه " + _get_player_name(tgt_id)) if tgt_id > 0 else ""
	_show_combat_toast("⚡ %s کارت استراتژی «%s»%s را بازی کرد!" % [_get_player_name(gid), strat_fa, target_txt])
	_append_battle_log("⚡ %s کارت «%s»%s را اجرا کرد." % [_get_player_name(gid), strat_fa, target_txt])

	selected_hand_card_idx = -1
	selected_strategy_name = ""
	selected_target_player = 0
	selected_target_continent = ""
	_refresh_all_3d_and_hud()

func _restart_hud_turn_timer() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(30.0)

# ==============================================================================
# 4. 3D VISUAL REFRESH (CONTINENTS, STATIONS, DECKS, BRIDGES, 3D HAND RACK)
# ==============================================================================

func _refresh_all_3d_and_hud() -> void:
	_refresh_3d_decks()
	_refresh_3d_continents_and_bridges()
	_refresh_3d_player_stations()
	_refresh_top_header()
	_refresh_floating_hud()

func _refresh_3d_decks() -> void:
	if _table_refs.has("continent_deck"):
		var cd = _table_refs["continent_deck"]
		cd["count_lbl"].text = Risk3DFactory.fa_digits(continent_deck_count)
		cd["glow"].visible = (_is_my_turn() and game_state == "Draw")
		var vis_layers = clampi(int(ceil(float(continent_deck_count) / 4.0)), 1, 10)
		for i in range(cd["layers"].size()):
			cd["layers"][i].visible = (i < vis_layers and continent_deck_count > 0)

	if _table_refs.has("strategy_deck"):
		var sd = _table_refs["strategy_deck"]
		sd["count_lbl"].text = Risk3DFactory.fa_digits(strategy_deck_count)
		sd["glow"].visible = (_is_my_turn() and game_state == "Draw")
		var vis_layers = clampi(int(ceil(float(strategy_deck_count) / 4.0)), 1, 10)
		for i in range(sd["layers"].size()):
			sd["layers"][i].visible = (i < vis_layers and strategy_deck_count > 0)

func _refresh_3d_continents_and_bridges() -> void:
	var valid_targets: Array[String] = _get_valid_attack_target_continents(selected_source_continent)

	for c_id in _continent_nodes.keys():
		var c_ref: Dictionary = _continent_nodes[c_id]
		c_ref["token_node"].visible = board_tokens.has(c_id)

		var garrisons: Dictionary = c_ref["garrisons"]
		for p_idx in [1, 2, 3, 4]:
			var g_ref: Dictionary = garrisons[p_idx]
			var p_conts: Dictionary = players_state.get(p_idx, {}).get("continents", {})
			var cnt: int = _to_int(p_conts.get(c_id, 0))
			if cnt > 0 and p_idx <= total_players:
				g_ref["node"].visible = true
				g_ref["label"].text = "×" + Risk3DFactory.fa_digits(cnt)
			else:
				g_ref["node"].visible = false

		var aura: MeshInstance3D = c_ref["aura"]
		var is_atk_src = (active_attack.get("source_continent", "") == c_id)
		var is_atk_tgt = (active_attack.get("target_continent", "") == c_id)
		if is_atk_src or c_id == selected_source_continent:
			aura.visible = true
			aura.material_override = _mats["glow_gold"]
		elif is_atk_tgt or c_id == selected_target_continent:
			aura.visible = true
			aura.material_override = _mats["glow_crimson"]
		elif valid_targets.has(c_id):
			aura.visible = true
			aura.material_override = _mats["glow_emerald"]
		else:
			aura.visible = false

	for pair_key in _bridge_nodes.keys():
		var b_mi: MeshInstance3D = _bridge_nodes[pair_key]
		var highlight: bool = false
		if not active_attack.is_empty():
			var sc = str(active_attack.get("source_continent", ""))
			var tc = str(active_attack.get("target_continent", ""))
			if pair_key == (sc + "_" + tc) or pair_key == (tc + "_" + sc):
				highlight = true
		elif selected_source_continent != "":
			if pair_key.begins_with(selected_source_continent + "_") or pair_key.ends_with("_" + selected_source_continent):
				highlight = true
		b_mi.material_override = _mats["bridge_active"] if highlight else _mats["bridge_idle"]

func _refresh_3d_player_stations() -> void:
	var needs_opp_target: bool = (selected_strategy_name in ["Bomb", "Destroy", "Spy"])

	for p_idx in _station_nodes.keys():
		var st_ref: Dictionary = _station_nodes[p_idx]
		var p_data: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
		var c_total: int = _sum_dict_values(p_data.get("continents", {}))
		var s_total: int = _to_int(p_data.get("strategies_count", 0))
		var t_total: int = (p_data.get("tokens", []) as Array).size()

		var p_name = _get_player_name(p_idx)
		st_ref["name_lbl"].text = ("%s (شما)" % p_name) if p_idx == my_player_index else p_name
		st_ref["stats_lbl"].text = "👑%s  🗺️%s  🃏%s" % [
			Risk3DFactory.fa_digits(t_total),
			Risk3DFactory.fa_digits(c_total),
			Risk3DFactory.fa_digits(s_total),
		]

		var is_turn = (_active_turn == p_idx)
		st_ref["active_glow"].visible = is_turn
		st_ref["commander_mi"].material_override = st_ref["f_mat_active"] if is_turn else st_ref["f_mat_idle"]
		st_ref["target_glow"].visible = (needs_opp_target and p_idx != my_player_index) or (selected_target_player == p_idx)

		Risk3DFactory.populate_station_assets_3d(st_ref, p_data, _mats, FontHekayat, _crown_mesh)

func _rebuild_3d_hand_rack() -> void:
	if not is_instance_valid(_hand_rack_root):
		return
	for child in _hand_rack_root.get_children():
		if child.name.begins_with("Card3D_"):
			child.queue_free()
	_hand_card_nodes.clear()

	var entries: Array = []
	var c_keys = my_continents.keys()
	c_keys.sort()
	for c_id in c_keys:
		var cnt = _to_int(my_continents[c_id])
		if cnt > 0:
			entries.append({"kind": "continent", "id": str(c_id), "count": cnt})

	var strat_counts: Dictionary = {}
	for s_name in my_strategies:
		var sn = str(s_name)
		strat_counts[sn] = _to_int(strat_counts.get(sn, 0)) + 1
	var s_keys = strat_counts.keys()
	s_keys.sort()
	for sn in s_keys:
		entries.append({"kind": "strategy", "id": str(sn), "count": _to_int(strat_counts[sn])})

	var total_cards = entries.size()
	if total_cards == 0:
		return

	var max_span: float = 0.92
	var step_x: float = minf(0.140, max_span / float(max(1, total_cards - 1))) if total_cards > 1 else 0.0

	for i in range(total_cards):
		var item = entries[i]
		var card_ref = Risk3DFactory.build_3d_card(
			item["kind"],
			item["id"],
			item["count"],
			i,
			_mats,
			FontHekayat,
			_rook_mesh,
			_knight_mesh
		)
		var offset_idx = float(i) - float(total_cards - 1) * 0.5
		var bx = offset_idx * step_x
		var by = -absf(offset_idx) * 0.004
		var bz = float(i) * 0.0015
		var brot = Vector3(0.0, -offset_idx * 2.8, 0.0)

		card_ref["base_pos"] = Vector3(bx, by, bz)
		card_ref["base_rot"] = brot
		var c_node: Node3D = card_ref["root"]
		c_node.position = card_ref["base_pos"]
		c_node.rotation_degrees = card_ref["base_rot"]
		_hand_rack_root.add_child(c_node)
		_hand_card_nodes.append(card_ref)

	_update_3d_hand_selection_visuals()

func _update_3d_hand_selection_visuals() -> void:
	for i in range(_hand_card_nodes.size()):
		var c_ref: Dictionary = _hand_card_nodes[i]
		var c_node: Node3D = c_ref["root"]
		if not is_instance_valid(c_node):
			continue
		var is_sel: bool = (i == selected_hand_card_idx) or (c_ref["card_kind"] == "continent" and c_ref["card_id"] == selected_source_continent) or (c_ref["card_kind"] == "strategy" and c_ref["card_id"] == selected_strategy_name)
		var is_hov: bool = (i == hovered_card_idx)
		c_ref["glow"].visible = is_sel or is_hov

		var target_pos: Vector3 = c_ref["base_pos"]
		if is_sel:
			target_pos += Vector3(0.0, 0.042, 0.028)
		elif is_hov:
			target_pos += Vector3(0.0, 0.020, 0.014)
		c_node.position = c_node.position.lerp(target_pos, 0.35)

func _refresh_top_header() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if not is_instance_valid(hud):
		return
	var header = hud.get_node_or_null("TopHeader")
	if not is_instance_valid(header):
		return

	var t_counts = [0, 0, 0, 0]
	var c_counts = [0, 0, 0, 0]
	var s_counts = [0, 0, 0, 0]
	for idx in [1, 2, 3, 4]:
		var st = players_state.get(idx, {})
		t_counts[idx - 1] = (st.get("tokens", []) as Array).size()
		c_counts[idx - 1] = _sum_dict_values(st.get("continents", {}))
		s_counts[idx - 1] = _to_int(st.get("strategies_count", 0))

	if header.has_method("update_risk_player_stats"):
		header.update_risk_player_stats(t_counts, c_counts, s_counts)
	elif header.has_method("update_risk_stats"):
		header.update_risk_stats(t_counts, c_counts, s_counts)

# ==============================================================================
# 5. CONTEXTUAL FLOATING HUD & LEGAL ACTIONS
# ==============================================================================

func _refresh_floating_hud() -> void:
	_update_hud_visibility()
	if not is_instance_valid(_hud_root):
		return

	for ch in _action_buttons_row.get_children():
		ch.queue_free()
	for ch in _sub_options_row.get_children():
		ch.queue_free()
	for ch in _hand_filter_bar.get_children():
		ch.queue_free()
	if is_instance_valid(_opponent_quick_row):
		for ch in _opponent_quick_row.get_children():
			ch.queue_free()

	# 1. Populate Top Opponent Quick Status Chips
	if is_instance_valid(_opponent_quick_row):
		for p_idx in range(1, total_players + 1):
			if p_idx == my_player_index:
				continue
			var st: Dictionary = players_state.get(p_idx, {})
			var t_cnt: int = (st.get("tokens", []) as Array).size()
			var s_cnt: int = _to_int(st.get("strategies_count", 0))
			var conts: Dictionary = st.get("continents", {})
			var c_parts: Array[String] = []
			for ck in conts.keys():
				var cnt = _to_int(conts[ck])
				if cnt > 0:
					c_parts.append("%s×%s" % [_continent_fa(str(ck)), Risk3DFactory.fa_digits(cnt)])
			var c_summary = "، ".join(c_parts) if not c_parts.is_empty() else "بدون قاره"
			var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE)
			var opp_btn = _make_bronze_button(
				"%s (👑%s | 🃏%s): %s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(t_cnt), Risk3DFactory.fa_digits(s_cnt), c_summary],
				f_col.darkened(0.65),
				f_col.lightened(0.20),
				23
			)
			opp_btn.custom_minimum_size = Vector2(210, 56)
			var target_p = p_idx
			opp_btn.pressed.connect(func():
				AudioManager.sfx_tap()
				_on_3d_station_clicked(target_p)
			)
			_opponent_quick_row.add_child(opp_btn)

	# 2. Populate Quick Hand Strip Mirror
	for i in range(_hand_card_nodes.size()):
		var c_ref: Dictionary = _hand_card_nodes[i]
		var c_kind: String = c_ref["card_kind"]
		var c_id: String = c_ref["card_id"]
		var cnt: int = c_ref["count"]
		var title_fa: String = _continent_fa(c_id) if c_kind == "continent" else Risk3DFactory.STRATEGY_META.get(c_id, {}).get("fa", c_id)
		var icon_prefix: String = "🗺️ " if c_kind == "continent" else "⚡ "
		var is_sel: bool = (i == selected_hand_card_idx) or (c_kind == "continent" and c_id == selected_source_continent) or (c_kind == "strategy" and c_id == selected_strategy_name)
		var bg_col = Color(0.32, 0.24, 0.08, 0.98) if is_sel else (Color(0.10, 0.26, 0.18, 0.92) if c_kind == "continent" else Color(0.28, 0.12, 0.14, 0.92))
		var brd_col = Color(1.0, 0.88, 0.32) if is_sel else (Color(0.38, 0.86, 0.56) if c_kind == "continent" else Color(0.92, 0.45, 0.45))
		var chip = _make_bronze_button("%s%s ×%s" % [icon_prefix, title_fa, Risk3DFactory.fa_digits(cnt)], bg_col, brd_col, 25)
		chip.custom_minimum_size = Vector2(175, 52)
		var card_idx = i
		chip.pressed.connect(func():
			AudioManager.sfx_tap()
			_on_3d_hand_card_clicked(card_idx)
		)
		_hand_filter_bar.add_child(chip)

	var def_id = _to_int(active_attack.get("defender_id", 0))
	var atk_id = _to_int(active_attack.get("attacker_id", _active_turn))

	# 3. DEFENDER PHASE (`DefenderArmy`)
	if game_state == "DefenderArmy":
		var src_fa = _continent_fa(str(active_attack.get("source_continent", "")))
		var tgt_fa = _continent_fa(str(active_attack.get("target_continent", "")))
		if def_id == my_player_index:
			var my_army_cards = _count_my_strategy("Army")
			var has_cancel = (_count_my_strategy("Cancel") > 0)
			var base_def_dice = clampi(_to_int(my_continents.get(str(active_attack.get("target_continent", "")), 1)), 1, 2)
			_phase_banner_lbl.text = "🛡️ دفاع در برابر حمله به «%s»! (تاس پایه دفاع: %s)" % [tgt_fa, Risk3DFactory.fa_digits(base_def_dice)]
			_selection_info_lbl.text = "مهاجم %s کارت ارتش کمکی بازی کرده است. تعداد کارت ارتش کمکی دفاع یا لغو حمله را انتخاب کنید:" % Risk3DFactory.fa_digits(_to_int(active_attack.get("attacker_army", 0)))

			for c in range(my_army_cards + 1):
				var is_picked = (selected_army_commit == c)
				var b = _make_bronze_button(
					"🛡️ +%s ارتش کمکی" % Risk3DFactory.fa_digits(c),
					Color(0.28, 0.22, 0.08, 0.96) if is_picked else Color(0.14, 0.12, 0.10, 0.92),
					Color(1.0, 0.86, 0.28) if is_picked else Color(0.68, 0.56, 0.36),
					26
				)
				b.custom_minimum_size = Vector2(180, 54)
				var count_val = c
				b.pressed.connect(func():
					AudioManager.sfx_tap()
					selected_army_commit = count_val
					_refresh_floating_hud()
				)
				_sub_options_row.add_child(b)

			var btn_defend = _make_bronze_button(
				"🎲 تایید دفاع و پرتاب تاس (%s ارتش کمکی)" % Risk3DFactory.fa_digits(selected_army_commit),
				Color(0.14, 0.40, 0.22, 0.98),
				Color(0.45, 0.96, 0.60),
				28
			)
			btn_defend.custom_minimum_size = Vector2(360, 62)
			btn_defend.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.DefenderArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_defend)

			if has_cancel:
				var btn_cancel_atk = _make_bronze_button(
					"🛡️ لغو کامل حمله (کارت Cancel)",
					Color(0.14, 0.36, 0.44, 0.98),
					Color(0.38, 0.94, 1.0),
					28
				)
				btn_cancel_atk.custom_minimum_size = Vector2(310, 62)
				btn_cancel_atk.pressed.connect(func():
					AudioManager.sfx_button()
					send_move(Commands.DefenderArmy, {"count": 0, "cancel": true})
				)
				_action_buttons_row.add_child(btn_cancel_atk)
		else:
			_phase_banner_lbl.text = "⏳ در انتظار تصمیم دفاعی %s در قاره «%s»..." % [_get_player_name(def_id), tgt_fa]
			_selection_info_lbl.text = "حمله از «%s» به «%s» در جریان است." % [src_fa, tgt_fa]
		_update_sub_scroll_visibility()
		return

	# 4. ATTACKER REINFORCEMENT PHASE (`AttackerArmy`)
	if game_state == "AttackerArmy":
		var src_fa = _continent_fa(str(active_attack.get("source_continent", "")))
		var tgt_fa = _continent_fa(str(active_attack.get("target_continent", "")))
		if atk_id == my_player_index:
			var my_army_cards = _count_my_strategy("Army")
			var base_atk_dice = clampi(_to_int(my_continents.get(str(active_attack.get("source_continent", "")), 1)), 1, 3)
			_phase_banner_lbl.text = "⚔️ تقویت ارتش مهاجم از «%s» به «%s» (تاس پایه: %s)" % [src_fa, tgt_fa, Risk3DFactory.fa_digits(base_atk_dice)]
			_selection_info_lbl.text = "تعداد کارت «ارتش کمکی» برای افزودن تاس به این حمله را انتخاب کنید:"

			for c in range(my_army_cards + 1):
				var is_picked = (selected_army_commit == c)
				var b = _make_bronze_button(
					"⚔️ +%s ارتش کمکی" % Risk3DFactory.fa_digits(c),
					Color(0.34, 0.16, 0.08, 0.96) if is_picked else Color(0.14, 0.12, 0.10, 0.92),
					Color(1.0, 0.84, 0.28) if is_picked else Color(0.68, 0.56, 0.36),
					26
				)
				b.custom_minimum_size = Vector2(180, 54)
				var count_val = c
				b.pressed.connect(func():
					AudioManager.sfx_tap()
					selected_army_commit = count_val
					_refresh_floating_hud()
				)
				_sub_options_row.add_child(b)

			var btn_commit = _make_bronze_button(
				"⚔️ تایید ارتش مهاجم (+%s تاس)" % Risk3DFactory.fa_digits(selected_army_commit),
				Color(0.48, 0.14, 0.14, 0.98),
				Color(1.0, 0.50, 0.38),
				28
			)
			btn_commit.custom_minimum_size = Vector2(340, 62)
			btn_commit.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.AttackerArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_commit)

			if _count_my_strategy("Canon") > 0:
				var btn_canon = _make_bronze_button(
					"💣 شلیک توپخانه (+۱ به بالاترین تاس)",
					Color(0.38, 0.28, 0.08, 0.98),
					Color(1.0, 0.86, 0.28),
					27
				)
				btn_canon.custom_minimum_size = Vector2(320, 62)
				btn_canon.pressed.connect(func():
					AudioManager.sfx_button()
					send_move(Commands.Use_Strategy, {"strategy": "Canon"})
				)
				_action_buttons_row.add_child(btn_canon)
		else:
			_phase_banner_lbl.text = "⏳ %s در حال انتخاب ارتش کمکی برای حمله به «%s» است..." % [_get_player_name(atk_id), tgt_fa]
			_selection_info_lbl.text = "حمله از «%s» به «%s»." % [src_fa, tgt_fa]
		_update_sub_scroll_visibility()
		return

	# 5. NOT MY TURN
	if not _is_my_turn():
		_phase_banner_lbl.text = "⏳ نوبت فرماندهی %s (%s)" % [_get_player_name(_active_turn), _phase_fa(game_state)]
		_selection_info_lbl.text = "می‌توانید روی قاره‌ها یا ایستگاه سه بعدی حریفان روی میز کلیک کنید تا جزئیات آن‌ها را بررسی کنید."
		_update_sub_scroll_visibility()
		return

	# 6. MY TURN - DRAW PHASE (`Draw`)
	if game_state == "Draw":
		_phase_banner_lbl.text = "🃏 فاز کشیدن کارت: روی دسته‌های کارت روی میز کلیک کنید یا ترکیب دلخواه را انتخاب نمایید:"
		if not _first_3d_deck_picked.is_empty():
			var first_fa = "قاره 🗺️" if _first_3d_deck_picked == "continent" else "استراتژی ⚡"
			_selection_info_lbl.text = "✅ کارت اول (%s) انتخاب شد؛ اکنون روی دسته دوم کلیک کنید!" % first_fa
		else:
			_selection_info_lbl.text = "هر نوبت با دریافت ۲ کارت آغاز می‌شود (قاره، استراتژی، یا ترکیبی)."

		var btn_d1 = _make_bronze_button("🗺️ ۲ کارت قاره", Color(0.12, 0.36, 0.22, 0.98), Color(0.40, 0.94, 0.60), 28)
		btn_d1.custom_minimum_size = Vector2(235, 62)
		btn_d1.pressed.connect(func(): _send_draw_card(1))
		_action_buttons_row.add_child(btn_d1)

		var btn_d3 = _make_bronze_button("⚖️ ۱ قاره + ۱ استراتژی", Color(0.30, 0.24, 0.10, 0.98), Color(0.98, 0.84, 0.34), 28)
		btn_d3.custom_minimum_size = Vector2(280, 62)
		btn_d3.pressed.connect(func(): _send_draw_card(3))
		_action_buttons_row.add_child(btn_d3)

		var btn_d2 = _make_bronze_button("⚡ ۲ کارت استراتژی", Color(0.40, 0.14, 0.16, 0.98), Color(0.96, 0.46, 0.46), 28)
		btn_d2.custom_minimum_size = Vector2(255, 62)
		btn_d2.pressed.connect(func(): _send_draw_card(2))
		_action_buttons_row.add_child(btn_d2)
		_update_sub_scroll_visibility()
		return

	# 7. MY TURN - SELECT ACTION PHASE (`SelectAction`)
	_phase_banner_lbl.text = "⚔️ فاز عملیات تاکتیکی: یک قاره خودی یا یک کارت استراتژی سه بعدی را انتخاب کنید"
	if selected_strategy_name != "":
		_populate_strategy_action_controls()
	elif selected_source_continent != "":
		_populate_attack_action_controls()
	else:
		_selection_info_lbl.text = "برای حمله، روی یکی از قاره‌های خود روی تخته سه‌بعدی کلیک کنید؛ یا کارت استراتژی بازی کنید."

	var btn_pass = _make_bronze_button("⏭️ پایان نوبت", Color(0.24, 0.18, 0.10, 0.96), Color(0.88, 0.70, 0.36), 28)
	btn_pass.custom_minimum_size = Vector2(210, 62)
	btn_pass.pressed.connect(func():
		AudioManager.sfx_button()
		send_move(Commands.Pass_Turn, {})
	)
	_action_buttons_row.add_child(btn_pass)
	_update_sub_scroll_visibility()

func _update_sub_scroll_visibility() -> void:
	if is_instance_valid(_sub_scroll) and is_instance_valid(_sub_options_row):
		_sub_scroll.visible = (_sub_options_row.get_child_count() > 0)

func _populate_attack_action_controls() -> void:
	var src_fa = _continent_fa(selected_source_continent)
	var my_cnt = _to_int(my_continents.get(selected_source_continent, 0))
	if selected_target_continent == "":
		_selection_info_lbl.text = "قاره مبدا: «%s» (%s کارت). اکنون روی یکی از قاره‌های هدف (حلقه‌های سبز روی تخته) کلیک کنید." % [
			src_fa, Risk3DFactory.fa_digits(my_cnt)
		]
		var valid_targets = _get_valid_attack_target_continents(selected_source_continent)
		for tc in valid_targets:
			var b_t = _make_bronze_button("🎯 حمله به %s" % _continent_fa(tc), Color(0.14, 0.32, 0.20, 0.96), Color(0.44, 0.94, 0.60), 26)
			b_t.custom_minimum_size = Vector2(195, 54)
			var target_c = tc
			b_t.pressed.connect(func():
				AudioManager.sfx_tap()
				_select_target_continent_for_attack(target_c)
			)
			_sub_options_row.add_child(b_t)
		return

	var tgt_fa = _continent_fa(selected_target_continent)
	var defenders = _get_defenders_on_continent(selected_target_continent)
	if defenders.is_empty():
		_selection_info_lbl.text = "در قاره «%s» هیچ نیروی دشمنی حضور ندارد. قاره دیگری را هدف بگیرید." % tgt_fa
		return

	if selected_target_player == 0 or not defenders.has(selected_target_player):
		selected_target_player = defenders[0]

	_selection_info_lbl.text = "آماده حمله از «%s» به «%s» علیه %s!" % [
		src_fa, tgt_fa, _get_player_name(selected_target_player)
	]

	if defenders.size() > 1:
		for d_id in defenders:
			var is_sel = (selected_target_player == d_id)
			var b_d = _make_bronze_button(
				"🎯 %s" % _get_player_name(d_id),
				Color(0.38, 0.16, 0.12, 0.96) if is_sel else Color(0.16, 0.12, 0.10, 0.92),
				Color(1.0, 0.84, 0.28) if is_sel else Color(0.70, 0.56, 0.36),
				26
			)
			b_d.custom_minimum_size = Vector2(180, 54)
			var def_p = d_id
			b_d.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_target_player = def_p
				_refresh_all_3d_and_hud()
			)
			_sub_options_row.add_child(b_d)

	var btn_atk = _make_bronze_button(
		"⚔️ اعلان حمله به «%s» (%s)" % [tgt_fa, _get_player_name(selected_target_player)],
		Color(0.52, 0.14, 0.14, 0.98),
		Color(1.0, 0.54, 0.38),
		28
	)
	btn_atk.custom_minimum_size = Vector2(340, 62)
	btn_atk.pressed.connect(_send_declare_attack)
	_action_buttons_row.add_child(btn_atk)

func _populate_strategy_action_controls() -> void:
	var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(selected_strategy_name, {})
	var strat_fa = sm.get("fa", selected_strategy_name)
	var desc = sm.get("desc", "")
	_selection_info_lbl.text = "⚡ کارت «%s»: %s" % [strat_fa, desc]

	if bool(sm.get("combat_only", false)):
		_selection_info_lbl.text = "🛡️ کارت «%s» فقط در زمان دفاع در برابر حمله دشمن قابل استفاده است." % strat_fa
		return

	var needs_p = bool(sm.get("needs_target_player", false))
	var needs_c = bool(sm.get("needs_target_continent", false))

	if needs_p:
		var opps = _get_valid_opponent_targets_for_strategy(selected_strategy_name)
		if opps.is_empty():
			_selection_info_lbl.text = "هیچ حریفی کارت واجد شرایط برای اجرای «%s» ندارد." % strat_fa
			return
		if selected_target_player == 0 or not opps.has(selected_target_player):
			selected_target_player = opps[0]

		for op_id in opps:
			var is_sel = (selected_target_player == op_id)
			var b_op = _make_bronze_button(
				"🎯 حریف: %s" % _get_player_name(op_id),
				Color(0.38, 0.16, 0.12, 0.96) if is_sel else Color(0.16, 0.12, 0.10, 0.92),
				Color(1.0, 0.84, 0.28) if is_sel else Color(0.68, 0.52, 0.32),
				26
			)
			b_op.custom_minimum_size = Vector2(185, 54)
			var target_p = op_id
			b_op.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_target_player = target_p
				selected_target_continent = ""
				_refresh_all_3d_and_hud()
			)
			_sub_options_row.add_child(b_op)

	if needs_c and selected_target_player > 0:
		var opp_conts: Dictionary = players_state.get(selected_target_player, {}).get("continents", {})
		var valid_c: Array[String] = []
		for ck in opp_conts.keys():
			if _to_int(opp_conts[ck]) > 0:
				valid_c.append(str(ck))
		valid_c.sort()
		if valid_c.is_empty():
			_selection_info_lbl.text = "%s هیچ کارت قاره‌ای برای تخریب ندارد." % _get_player_name(selected_target_player)
			return
		if selected_target_continent == "" or not valid_c.has(selected_target_continent):
			selected_target_continent = valid_c[0]

		for ck in valid_c:
			var is_c_sel = (selected_target_continent == ck)
			var b_c = _make_bronze_button(
				"🗺️ %s" % _continent_fa(ck),
				Color(0.34, 0.14, 0.20, 0.96) if is_c_sel else Color(0.14, 0.14, 0.14, 0.92),
				Color(1.0, 0.78, 0.30) if is_c_sel else Color(0.60, 0.50, 0.35),
				26
			)
			b_c.custom_minimum_size = Vector2(175, 54)
			var c_val = ck
			b_c.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_target_continent = c_val
				_refresh_all_3d_and_hud()
			)
			_sub_options_row.add_child(b_c)

	var btn_play = _make_bronze_button(
		"⚡ اجرای کارت «%s»" % strat_fa,
		Color(0.16, 0.40, 0.24, 0.98),
		Color(0.46, 0.96, 0.62),
		28
	)
	btn_play.custom_minimum_size = Vector2(290, 62)
	btn_play.pressed.connect(_send_use_strategy)
	_action_buttons_row.add_child(btn_play)

# ==============================================================================
# 6. 3D RAYCAST INTERACTION (TABLE, CONTINENTS, CARDS, DECKS, STATIONS)
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
				_perform_3d_tabletop_raycast(event.position, true)
			_pointer_is_down = false
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down_pos = event.position
			_pointer_is_down = true
		else:
			if _pointer_is_down and event.position.distance_to(_pointer_down_pos) <= TAP_MAX_DRAG_PX:
				_perform_3d_tabletop_raycast(event.position, true)
			_pointer_is_down = false
	elif event is InputEventMouseMotion:
		_perform_3d_tabletop_raycast(event.position, false)

func _perform_3d_tabletop_raycast(screen_pos: Vector2, is_click: bool) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 12.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit = space.intersect_ray(query)

	if hit.is_empty() or not hit.has("collider"):
		if not is_click and hovered_card_idx != -1:
			hovered_card_idx = -1
			_update_3d_hand_selection_visuals()
		return

	var col: Object = hit["collider"]
	if not (col is Node) or not col.has_meta("interact_type"):
		return

	var itype = str(col.get_meta("interact_type"))
	if not is_click:
		if itype == "hand_card":
			var h_idx = _to_int(col.get_meta("hand_idx"))
			if h_idx != hovered_card_idx:
				hovered_card_idx = h_idx
				_update_3d_hand_selection_visuals()
		elif hovered_card_idx != -1:
			hovered_card_idx = -1
			_update_3d_hand_selection_visuals()
		return

	AudioManager.sfx_tap()
	match itype:
		"deck":
			var dtype_str = str(col.get_meta("deck_type"))
			_on_3d_deck_clicked(dtype_str)
		"hand_card":
			var c_idx = _to_int(col.get_meta("hand_idx"))
			_on_3d_hand_card_clicked(c_idx)
		"continent":
			var c_id = str(col.get_meta("continent"))
			_on_3d_continent_clicked(c_id)
		"station":
			var p_idx = _to_int(col.get_meta("player_index"))
			_on_3d_station_clicked(p_idx)

func _on_3d_deck_clicked(deck_type: String) -> void:
	if not _is_my_turn() or game_state != "Draw":
		show_hint("🃏 کشیدن کارت فقط در ابتدای نوبت شما (فاز کشیدن کارت) مجاز است.")
		return
	var pick = "continent" if deck_type == "continent" else "strategy"
	if _first_3d_deck_picked.is_empty():
		_first_3d_deck_picked = pick
		_refresh_floating_hud()
	else:
		var first = _first_3d_deck_picked
		_first_3d_deck_picked = ""
		var draw_type = 3
		if first == "continent" and pick == "continent":
			draw_type = 1
		elif first == "strategy" and pick == "strategy":
			draw_type = 2
		else:
			draw_type = 3
		_send_draw_card(draw_type)

func _on_3d_hand_card_clicked(card_idx: int) -> void:
	if card_idx < 0 or card_idx >= _hand_card_nodes.size():
		return
	var c_ref: Dictionary = _hand_card_nodes[card_idx]
	var kind: String = c_ref["card_kind"]
	var cid: String = c_ref["card_id"]

	if selected_hand_card_idx == card_idx:
		selected_hand_card_idx = -1
		selected_source_continent = ""
		selected_target_continent = ""
		selected_strategy_name = ""
	else:
		selected_hand_card_idx = card_idx
		if kind == "continent":
			selected_source_continent = cid
			selected_target_continent = ""
			selected_strategy_name = ""
		else:
			selected_strategy_name = cid
			selected_source_continent = ""
			selected_target_continent = ""

	_refresh_all_3d_and_hud()

func _on_3d_continent_clicked(c_id: String) -> void:
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
		var valid_targets = _get_valid_attack_target_continents(selected_source_continent)
		if selected_source_continent != "" and valid_targets.has(c_id):
			_select_target_continent_for_attack(c_id)
			return
		elif _to_int(my_continents.get(c_id, 0)) > 0:
			selected_source_continent = c_id
			selected_target_continent = ""
			_refresh_all_3d_and_hud()
			return

	_inspect_continent_summary(c_id)

func _select_target_continent_for_attack(c_id: String) -> void:
	selected_target_continent = c_id
	var defs = _get_defenders_on_continent(c_id)
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
		candidates = Risk3DFactory.CONTINENT_ADJACENCY.get(src_c, []).duplicate()
		if not candidates.has(src_c):
			candidates.append(src_c)

	for tc in candidates:
		var c_str = str(tc)
		if not _get_defenders_on_continent(c_str).is_empty():
			res.append(c_str)
	return res

func _get_defenders_on_continent(c_id: String) -> Array[int]:
	var defs: Array[int] = []
	for p_idx in range(1, total_players + 1):
		if p_idx == my_player_index:
			continue
		var p_conts: Dictionary = players_state.get(p_idx, {}).get("continents", {})
		if _to_int(p_conts.get(c_id, 0)) > 0:
			defs.append(p_idx)
	return defs

func _get_valid_opponent_targets_for_strategy(strat: String) -> Array[int]:
	var opps: Array[int] = []
	for p_idx in range(1, total_players + 1):
		if p_idx == my_player_index:
			continue
		var st = players_state.get(p_idx, {})
		var c_sum = _sum_dict_values(st.get("continents", {}))
		var s_sum = _to_int(st.get("strategies_count", 0))
		if strat == "Destroy":
			if c_sum > 0:
				opps.append(p_idx)
		else:
			if c_sum > 0 or s_sum > 0:
				opps.append(p_idx)
	return opps

func _count_my_strategy(strat_name: String) -> int:
	var c: int = 0
	for s in my_strategies:
		if str(s) == strat_name:
			c += 1
	return c

# ==============================================================================
# 8. 3D DICE ROLLING & TABLETOP ANIMATIONS
# ==============================================================================

func _spawn_and_roll_3d_dice(atk_dice: Array, def_dice: Array) -> void:
	if not _table_refs.has("dice_arena"):
		return
	var arena: Node3D = _table_refs["dice_arena"]
	for d in _dice_nodes:
		if is_instance_valid(d):
			d.queue_free()
	_dice_nodes.clear()

	AudioManager.sfx_dice()

	var total_atk = atk_dice.size()
	for i in range(total_atk):
		var val = _to_int(atk_dice[i], 1)
		var die = Risk3DFactory.build_3d_die(true, _mats)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos = Vector3(-0.042 + float(i) * 0.038, 0.032, -0.024)
		_animate_single_3d_die(die, target_pos, val, float(i) * 0.06)

	var total_def = def_dice.size()
	for i in range(total_def):
		var val = _to_int(def_dice[i], 1)
		var die = Risk3DFactory.build_3d_die(false, _mats)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos = Vector3(-0.024 + float(i) * 0.042, 0.032, 0.026)
		_animate_single_3d_die(die, target_pos, val, 0.08 + float(i) * 0.06)

func _animate_single_3d_die(die: Node3D, final_pos: Vector3, final_val: int, delay: float) -> void:
	die.position = final_pos + Vector3(randf_range(-0.04, 0.04), 0.18, randf_range(-0.03, 0.03))
	die.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
	var final_rot = Risk3DFactory.get_die_rotation_for_value(final_val)
	var tw = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(die, "position", final_pos, 0.52).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(
		die,
		"rotation_degrees",
		final_rot + Vector3(360.0, 360.0, 0.0),
		0.50
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_deck_draw_pulse(draw_type: int) -> void:
	var targets: Array = []
	if draw_type in [1, 3] and _table_refs.has("continent_deck"):
		targets.append(_table_refs["continent_deck"]["stack"])
	if draw_type in [2, 3] and _table_refs.has("strategy_deck"):
		targets.append(_table_refs["strategy_deck"]["stack"])
	for st in targets:
		if is_instance_valid(st):
			var tw = create_tween()
			tw.tween_property(st, "scale", Vector3(1.14, 1.22, 1.14), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(st, "scale", Vector3.ONE, 0.18)

func _process(delta: float) -> void:
	_anim_clock += delta
	_update_hud_visibility()

	for c_id in _continent_nodes.keys():
		var tok: Node3D = _continent_nodes[c_id]["token_node"]
		if is_instance_valid(tok) and tok.visible:
			tok.rotation.y = _anim_clock * 1.1
			tok.position.y = 0.070 + sin(_anim_clock * 2.4) * 0.004

# ==============================================================================
# 9. INSPECTORS & LOG PANEL
# ==============================================================================

func _toggle_opponent_inspector(target_p: int = 0) -> void:
	if not is_instance_valid(_inspector_panel):
		return
	if _inspector_panel.visible and target_p == 0:
		_inspector_panel.visible = false
		return

	_inspector_panel.visible = true
	_log_panel.visible = false
	_inspector_title_lbl.text = "👁️ وضعیت ایستگاه‌ها و کارت‌های بازیکنان روی میز"

	var lines: Array[String] = []
	for p_idx in range(1, total_players + 1):
		if target_p > 0 and p_idx != target_p:
			continue
		var st: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
		var p_name = _get_player_name(p_idx)
		var tag = " (شما)" if p_idx == my_player_index else ""
		var toks: Array = st.get("tokens", [])
		var tok_names: Array[String] = []
		for t in toks:
			tok_names.append(_continent_fa(str(t)))
		var tok_str = "، ".join(tok_names) if not tok_names.is_empty() else "ندارد"

		var conts: Dictionary = st.get("continents", {})
		var c_parts: Array[String] = []
		for ck in conts.keys():
			var cnt = _to_int(conts[ck])
			if cnt > 0:
				c_parts.append("%s (×%s)" % [_continent_fa(str(ck)), Risk3DFactory.fa_digits(cnt)])
		var c_str = "، ".join(c_parts) if not c_parts.is_empty() else "بدون کارت قاره"
		var s_cnt = _to_int(st.get("strategies_count", 0))

		lines.append("🔹 %s%s:\n   👑 نشان‌های سلطه (%s/۲): %s\n   🗺️ کارت‌های قاره (رو): %s\n   🃏 کارت‌های استراتژی در دست (مخفی): %s کارت" % [
			p_name, tag, Risk3DFactory.fa_digits(toks.size()), tok_str, c_str, Risk3DFactory.fa_digits(s_cnt)
		])

	_inspector_body_lbl.text = "\n\n".join(lines)

func _inspect_continent_summary(c_id: String) -> void:
	var c_fa = _continent_fa(c_id)
	var has_tok = board_tokens.has(c_id)
	var parts: Array[String] = []
	for p_idx in range(1, total_players + 1):
		var cnt = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		if cnt > 0:
			parts.append("%s: ×%s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(cnt)])
	var garrison_str = " | ".join(parts) if not parts.is_empty() else "بدون نیرو"
	var tok_str = "👑 نشان سلطه روی قاره موجود است" if has_tok else "نشان سلطه تصاحب شده است"
	if is_instance_valid(_selection_info_lbl):
		_selection_info_lbl.text = "🗺️ قاره «%s» — %s — نیروها: %s" % [c_fa, tok_str, garrison_str]

func _toggle_battle_log_panel() -> void:
	if is_instance_valid(_log_panel):
		_log_panel.visible = not _log_panel.visible
		if _log_panel.visible and is_instance_valid(_inspector_panel):
			_inspector_panel.visible = false

func _append_battle_log(entry: String) -> void:
	_battle_logs.push_front(entry)
	if _battle_logs.size() > 30:
		_battle_logs.pop_back()
	if not is_instance_valid(_log_vbox):
		return
	for ch in _log_vbox.get_children():
		ch.queue_free()
	for line in _battle_logs:
		var l = Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", FontHekayat)
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
		_log_vbox.add_child(l)

func _show_combat_toast(text: String, duration: float = 3.8) -> void:
	if not is_instance_valid(_combat_banner_panel) or not is_instance_valid(_combat_banner_lbl):
		return
	_combat_banner_lbl.text = text
	_combat_banner_panel.visible = true
	_combat_banner_panel.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_combat_banner_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(_combat_banner_panel):
			_combat_banner_panel.visible = false
	)

# ==============================================================================
# 10. UTILITY HELPERS
# ==============================================================================

func _is_my_turn() -> bool:
	return _active_turn == my_player_index

func _get_player_name(p_idx: int) -> String:
	var d = GameManager.get_player_data_by_gamer_id(p_idx)
	var n = str(d.get("name", d.get("username", "")))
	if n.strip_edges() == "":
		return "فرمانده %s" % Risk3DFactory.fa_digits(p_idx)
	return n

func _continent_fa(c_id: String) -> String:
	return Risk3DFactory.CONTINENT_META.get(c_id, {}).get("fa", c_id)

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
	return "در حال بازی"

func _format_dice_list(arr: Array) -> String:
	if arr.is_empty():
		return "-"
	var parts: Array[String] = []
	for v in arr:
		parts.append(Risk3DFactory.fa_digits(_to_int(v)))
	return "[" + "، ".join(parts) + "]"

func _sum_dict_values(d: Dictionary) -> int:
	var total: int = 0
	for k in d.keys():
		total += _to_int(d[k])
	return total

func _to_int(val: Variant, default_val: int = 0) -> int:
	if val == null:
		return default_val
	var t = typeof(val)
	if t == TYPE_INT:
		return val
	if t == TYPE_FLOAT:
		return int(val)
	if t == TYPE_BOOL:
		return 1 if val else 0
	if t == TYPE_ARRAY:
		return (val as Array).size()
	if t == TYPE_DICTIONARY:
		return (val as Dictionary).size()
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		var st = str(val).strip_edges()
		if st.is_valid_int():
			return st.to_int()
		if st.is_valid_float():
			return int(st.to_float())
		return default_val
	return default_val
