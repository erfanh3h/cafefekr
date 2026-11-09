class_name Risk3D
extends BaseGameBoard

# ==============================================================================
# RISK STRIKE (ریسک استرایک) - REDESIGNED 3D TABLETOP & UI FOR GODOT 4
# ==============================================================================
# Strictly preserves top player headers and bottom 8 buttons of BaseGameHUD.
# Redesigns the central gameplay area with:
# 1. Spacious, raised 3D board centerpiece with non-overlapping territory plaques.
# 2. Dedicated horizontal scrollable Card Hand Tray with tactile card widgets & elevation.
# 3. Sleek, compact Contextual Action Panel docked cleanly above the bottom 8 buttons.

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

# Camera Defaults for CafeTable (Elevated Three-Quarter Tabletop Perspective)
@export var default_three_quarter_view: bool = true
@export var camera_pitch: float = -1.08    # ~ -62 deg elevated tabletop perspective for crisp, non-overlapping regions
@export var camera_distance: float = 2.60  # Optimal portrait mobile framing of the 6 regions

# Shared 3D Meshes & PBR Materials
var _mats: Dictionary = {}
var _rook_mesh: Mesh = null
var _knight_mesh: Mesh = null
var _king_mesh: Mesh = null
var _crown_mesh: Mesh = null

# 3D Scene Graph References
var _table_refs: Dictionary = {}
var _continent_nodes: Dictionary = {} # continent_id -> Dictionary from Risk3DFactory
var _bridge_nodes: Dictionary = {}    # "ContA_ContB" -> Node (MeshInstance3D or Node3D)
var _station_nodes: Dictionary = {}   # player_idx (1..4) -> Dictionary from Risk3DFactory
var _dice_nodes: Array = []           # Active 3D Dice inside _table_refs["dice_arena"]

# Authoritative Backend Game State
var total_players: int = 2
var active_player_indexes: Array = [1, 2]
var _active_turn: int = 1
var game_state: String = "Draw" # "StartGame", "Draw", "SelectAction", "AttackerArmy", "DefenderArmy", "Attack"
var continent_deck_count: int = 42
var strategy_deck_count: int = 38
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
var _hand_entries: Array = []      # Unified ordered hand items: {"kind": "continent"|"strategy", "id": String, "count": int}

# Active Combat State (`active_attack`)
var active_attack: Dictionary = {} # {"attacker_id", "defender_id", "source_continent", "target_continent", "attacker_army", "defender_army"}
var expand_ignore_adjacency: bool = false

# Interactive Selection State
var selected_source_continent: String = ""
var selected_target_continent: String = ""
var selected_target_player: int = 0
var selected_hand_card_idx: int = -1
var selected_strategy_name: String = ""
var selected_army_commit: int = 0
var _first_3d_deck_picked: String = ""
var _inspected_continent_id: String = ""
var _is_zoomed_in: bool = false

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
var _top_turn_lbl: Label = null
var _top_decks_lbl: Label = null
var _btn_zoom: Button = null
var _region_inspector_panel: PanelContainer = null
var _region_inspector_title_lbl: Label = null
var _region_inspector_detail_lbl: Label = null
var _opponent_quick_row: HBoxContainer = null
var _card_tray_panel: PanelContainer = null
var _card_tray_count_lbl: Label = null
var _card_preview_lbl: Label = null
var _hand_cards_hbox: HBoxContainer = null
var _phase_banner_lbl: Label = null
var _selection_info_lbl: Label = null
var _sub_scroll: ScrollContainer = null
var _action_buttons_row: HBoxContainer = null
var _sub_options_row: HBoxContainer = null
var _combat_banner_panel: PanelContainer = null
var _combat_banner_lbl: Label = null
var _inspector_panel: PanelContainer = null
var _inspector_title_lbl: Label = null
var _inspector_cards_vbox: VBoxContainer = null
var _inspected_player_filter: int = 0
var _dice_arena_tween: Tween = null
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

# Ensures the Risk HUD is NEVER shown during StartGameOverlay or GameResultDialog
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

# ==============================================================================
# 1. 3D TABLETOP WORLD CONSTRUCTION (CLEAN, SPACIOUS BOARD CENTERPIECE)
# ==============================================================================

func _build_3d_tabletop_world() -> void:
	# Position the 3D board slightly north so it sits squarely in the upper-middle viewport (y = 408..1355px)
	position = Vector3(0.0, 0.0, -0.05)

	# 1. Main Walnut Table Surround, Mahogany Board Frame, Emerald Velvet Bed, Upper Decks & Dice Arena
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

	# 4. Compact 3D Faction Token Pedestals on Outer Frame Corners (Zero text clutter!)
	_rebuild_player_stations_3d()

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

	# Local Player Token Pedestal on Bottom-Right Board Rim
	_station_nodes[my_id] = Risk3DFactory.build_player_station(
		self,
		my_id,
		Vector3(0.46, 0.046, 0.34),
		0.0,
		true,
		_mats,
		FontHekayat,
		_king_mesh
	)

	# Opponent Token Pedestals Along Outer Top Rim
	var opp_positions: Array = [
		Vector3(-0.48, 0.046, -0.64),
		Vector3(0.0, 0.046, -0.64),
		Vector3(0.48, 0.046, -0.64),
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
# 2. REDESIGNED TABLETOP UI (STRICT BOUNDARIES: BETWEEN TOP HEADER & BOTTOM 8 BUTTONS)
# ==============================================================================
# Portrait 1080x1920 Vertical Budget:
# - y = 0 .. 335px:    [UNTOUCHED] BaseGameHUD TopHeader (Player profile headers)
# - y = 340 .. 398px:  Compact Status & Utility Strip (Turn/Phase, Deck counts, Opponent Cards & Log buttons)
# - y = 402 .. 1358px: Unobstructed 3D Game Board Centerpiece (956px tall central playfield!)
# - y = 1362 .. 1572px: Dedicated Card Hand Tray (Horizontally scrollable 3D-styled tabletop cards)
# - y = 1580 .. 1756px: Compact Contextual Action Panel (1-line guide + legal action buttons)
# - y = 1766 .. 1920px: [UNTOUCHED] BaseGameHUD BottomBar (The 8 existing buttons)

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

	# --------------------------------------------------------------------------
	# A. COMPACT TOP STATUS & UTILITY STRIP (y = 340 .. 398px)
	# --------------------------------------------------------------------------
	var top_strip = PanelContainer.new()
	top_strip.name = "TopStatusStrip"
	top_strip.anchor_left = 0.025
	top_strip.anchor_right = 0.975
	top_strip.anchor_top = 0.0
	top_strip.anchor_bottom = 0.0
	top_strip.offset_top = 340.0
	top_strip.offset_bottom = 398.0
	top_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	top_strip.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.09, 0.06, 0.04, 0.90), Color(0.58, 0.42, 0.22, 0.85), 14, 1, 12, 6)
	)
	_hud_root.add_child(top_strip)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_strip.add_child(top_hbox)

	var btn_log = _make_styled_button(
		"📜 گزارش",
		Color(0.16, 0.11, 0.07, 0.95),
		Color(0.68, 0.52, 0.26),
		24,
		10
	)
	btn_log.custom_minimum_size = Vector2(124, 44)
	btn_log.pressed.connect(func():
		AudioManager.sfx_button()
		_toggle_battle_log_panel()
	)
	top_hbox.add_child(btn_log)

	var btn_opponents = _make_styled_button(
		"👁️ وضعیت بازیکنان",
		Color(0.10, 0.22, 0.16, 0.95),
		Color(0.38, 0.76, 0.52),
		24,
		10
	)
	btn_opponents.custom_minimum_size = Vector2(168, 44)
	btn_opponents.pressed.connect(func():
		AudioManager.sfx_button()
		_toggle_opponent_inspector(0)
	)
	top_hbox.add_child(btn_opponents)

	_btn_zoom = _make_styled_button(
		"🔍 زوم",
		Color(0.14, 0.12, 0.08, 0.95),
		Color(0.72, 0.56, 0.28),
		23,
		10
	)
	_btn_zoom.custom_minimum_size = Vector2(92, 44)
	_btn_zoom.pressed.connect(_toggle_camera_zoom)
	top_hbox.add_child(_btn_zoom)

	_top_decks_lbl = Label.new()
	_top_decks_lbl.text = "👑 ۰/۲  |  🗺️ ۴۲  |  ⚡ ۳۸"
	_top_decks_lbl.add_theme_font_override("font", FontHekayat)
	_top_decks_lbl.add_theme_font_size_override("font_size", 26)
	_top_decks_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.74))
	_top_decks_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(_top_decks_lbl)

	_top_turn_lbl = Label.new()
	_top_turn_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_turn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_turn_lbl.add_theme_font_override("font", FontHekayat)
	_top_turn_lbl.add_theme_font_size_override("font_size", 25)
	_top_turn_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.48))
	top_hbox.add_child(_top_turn_lbl)

	# --------------------------------------------------------------------------
	# A2. COMPACT SELECTED REGION CONTEXTUAL INSPECTOR OUTSIDE THE MAIN BOARD
	# (y = 402 .. 456px — Appears ONLY when a region is selected; hidden otherwise)
	# --------------------------------------------------------------------------
	_region_inspector_panel = PanelContainer.new()
	_region_inspector_panel.name = "SelectedRegionInspector"
	_region_inspector_panel.anchor_left = 0.03
	_region_inspector_panel.anchor_right = 0.97
	_region_inspector_panel.anchor_top = 0.0
	_region_inspector_panel.anchor_bottom = 0.0
	_region_inspector_panel.offset_top = 402.0
	_region_inspector_panel.offset_bottom = 456.0
	_region_inspector_panel.visible = false
	_region_inspector_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_region_inspector_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.06, 0.04, 0.94), Color(0.84, 0.66, 0.28, 0.92), 12, 1, 12, 4)
	)
	_hud_root.add_child(_region_inspector_panel)

	var reg_hbox = HBoxContainer.new()
	reg_hbox.add_theme_constant_override("separation", 10)
	reg_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_region_inspector_panel.add_child(reg_hbox)

	var btn_dismiss_reg = _make_styled_button(
		"✖",
		Color(0.24, 0.12, 0.10, 0.92),
		Color(0.72, 0.44, 0.34),
		22,
		8
	)
	btn_dismiss_reg.custom_minimum_size = Vector2(40, 38)
	btn_dismiss_reg.pressed.connect(func():
		AudioManager.sfx_tap()
		_inspected_continent_id = ""
		selected_source_continent = ""
		selected_target_continent = ""
		selected_hand_card_idx = -1
		_refresh_all_3d_and_hud()
	)
	reg_hbox.add_child(btn_dismiss_reg)

	_region_inspector_detail_lbl = Label.new()
	_region_inspector_detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_inspector_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_inspector_detail_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_region_inspector_detail_lbl.clip_text = true
	_region_inspector_detail_lbl.add_theme_font_override("font", FontHekayat)
	_region_inspector_detail_lbl.add_theme_font_size_override("font_size", 23)
	_region_inspector_detail_lbl.add_theme_color_override("font_color", Color(0.95, 0.91, 0.80))
	reg_hbox.add_child(_region_inspector_detail_lbl)

	_region_inspector_title_lbl = Label.new()
	_region_inspector_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_region_inspector_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_region_inspector_title_lbl.add_theme_font_override("font", FontHekayat)
	_region_inspector_title_lbl.add_theme_font_size_override("font_size", 26)
	_region_inspector_title_lbl.add_theme_color_override("font_color", Color(0.99, 0.88, 0.46))
	reg_hbox.add_child(_region_inspector_title_lbl)

	# --------------------------------------------------------------------------
	# B. FLOATING COMBAT RESOLUTION TOAST BANNER (y = 460 .. 560px)
	# --------------------------------------------------------------------------
	_combat_banner_panel = PanelContainer.new()
	_combat_banner_panel.anchor_left = 0.06
	_combat_banner_panel.anchor_right = 0.94
	_combat_banner_panel.anchor_top = 0.0
	_combat_banner_panel.anchor_bottom = 0.0
	_combat_banner_panel.offset_top = 460.0
	_combat_banner_panel.offset_bottom = 560.0
	_combat_banner_panel.visible = false
	_combat_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_banner_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.11, 0.07, 0.05, 0.95), Color(0.88, 0.68, 0.26), 16, 2, 16, 8)
	)
	_hud_root.add_child(_combat_banner_panel)

	_combat_banner_lbl = Label.new()
	_combat_banner_lbl.add_theme_font_override("font", FontHekayat)
	_combat_banner_lbl.add_theme_font_size_override("font_size", 28)
	_combat_banner_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	_combat_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_banner_panel.add_child(_combat_banner_lbl)

	# --------------------------------------------------------------------------
	# C. EXPANDABLE MODAL: PLAYERS CARDS & ASSETS VISUAL SHOWCASE (وضعیت بازیکنان)
	# --------------------------------------------------------------------------
	_inspector_panel = PanelContainer.new()
	_inspector_panel.anchor_left = 0.035
	_inspector_panel.anchor_right = 0.965
	_inspector_panel.anchor_top = 0.21
	_inspector_panel.anchor_bottom = 0.71
	_inspector_panel.visible = false
	_inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspector_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.055, 0.038, 0.98), Color(0.84, 0.66, 0.28), 20, 2, 16, 12)
	)
	_hud_root.add_child(_inspector_panel)

	var insp_vbox = VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 10)
	_inspector_panel.add_child(insp_vbox)

	var insp_header = HBoxContainer.new()
	insp_vbox.add_child(insp_header)

	var btn_close_insp = _make_styled_button("✖ بستن", Color(0.36, 0.12, 0.12, 0.95), Color(0.88, 0.40, 0.40), 25, 10)
	btn_close_insp.custom_minimum_size = Vector2(116, 46)
	btn_close_insp.pressed.connect(func(): _inspector_panel.visible = false)
	insp_header.add_child(btn_close_insp)

	_inspector_title_lbl = Label.new()
	_inspector_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inspector_title_lbl.add_theme_font_override("font", FontHekayat)
	_inspector_title_lbl.add_theme_font_size_override("font_size", 30)
	_inspector_title_lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.42))
	insp_header.add_child(_inspector_title_lbl)

	# Quick Player Filter Tabs inside Inspector
	var opp_chip_scroll = ScrollContainer.new()
	opp_chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opp_chip_scroll.custom_minimum_size = Vector2(0, 50)
	opp_chip_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	insp_vbox.add_child(opp_chip_scroll)

	_opponent_quick_row = HBoxContainer.new()
	_opponent_quick_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_quick_row.alignment = BoxContainer.ALIGNMENT_END
	_opponent_quick_row.add_theme_constant_override("separation", 8)
	opp_chip_scroll.add_child(_opponent_quick_row)

	var insp_scroll = ScrollContainer.new()
	insp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	insp_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	insp_vbox.add_child(insp_scroll)

	_inspector_cards_vbox = VBoxContainer.new()
	_inspector_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_cards_vbox.add_theme_constant_override("separation", 14)
	_inspector_cards_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	insp_scroll.add_child(_inspector_cards_vbox)

	# --------------------------------------------------------------------------
	# D. EXPANDABLE MODAL: BATTLE LOG DRAWER
	# --------------------------------------------------------------------------
	_log_panel = PanelContainer.new()
	_log_panel.anchor_left = 0.05
	_log_panel.anchor_right = 0.95
	_log_panel.anchor_top = 0.23
	_log_panel.anchor_bottom = 0.64
	_log_panel.visible = false
	_log_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.09, 0.06, 0.04, 0.97), Color(0.78, 0.60, 0.26), 18, 2, 18, 14)
	)
	_hud_root.add_child(_log_panel)

	var log_outer = VBoxContainer.new()
	log_outer.add_theme_constant_override("separation", 10)
	_log_panel.add_child(log_outer)

	var log_top = HBoxContainer.new()
	log_outer.add_child(log_top)
	var btn_close_log = _make_styled_button("✖ بستن", Color(0.36, 0.12, 0.12, 0.95), Color(0.88, 0.40, 0.40), 25, 10)
	btn_close_log.custom_minimum_size = Vector2(116, 46)
	btn_close_log.pressed.connect(func(): _log_panel.visible = false)
	log_top.add_child(btn_close_log)

	var log_title = Label.new()
	log_title.text = "📜 وقایع‌نگار فرماندهی"
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	log_title.add_theme_font_override("font", FontHekayat)
	log_title.add_theme_font_size_override("font_size", 30)
	log_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.42))
	log_top.add_child(log_title)

	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_outer.add_child(log_scroll)
	_log_vbox = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_theme_constant_override("separation", 6)
	log_scroll.add_child(_log_vbox)

	# --------------------------------------------------------------------------
	# E. DEDICATED CARD HAND TRAY (y = 1362 .. 1572px -> offset_top = -558 .. -348)
	# --------------------------------------------------------------------------
	_card_tray_panel = PanelContainer.new()
	_card_tray_panel.name = "DedicatedCardHandTray"
	_card_tray_panel.anchor_left = 0.02
	_card_tray_panel.anchor_right = 0.98
	_card_tray_panel.anchor_top = 1.0
	_card_tray_panel.anchor_bottom = 1.0
	_card_tray_panel.offset_top = -556.0
	_card_tray_panel.offset_bottom = -348.0
	_card_tray_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.08, 0.055, 0.038, 0.91), Color(0.54, 0.39, 0.20, 0.88), 18, 2, 14, 8)
	)
	_hud_root.add_child(_card_tray_panel)

	var tray_vbox = VBoxContainer.new()
	tray_vbox.add_theme_constant_override("separation", 4)
	_card_tray_panel.add_child(tray_vbox)

	# Tray Header Bar (Card preview on left, Hand summary on right)
	var tray_header = HBoxContainer.new()
	tray_header.add_theme_constant_override("separation", 10)
	tray_vbox.add_child(tray_header)

	_card_preview_lbl = Label.new()
	_card_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card_preview_lbl.add_theme_font_override("font", FontHekayat)
	_card_preview_lbl.add_theme_font_size_override("font_size", 24)
	_card_preview_lbl.add_theme_color_override("font_color", Color(0.94, 0.86, 0.62))
	_card_preview_lbl.text = "برای انتخاب قاره یا اجرای استراتژی، روی کارت ضربه بزنید"
	tray_header.add_child(_card_preview_lbl)

	_card_tray_count_lbl = Label.new()
	_card_tray_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card_tray_count_lbl.add_theme_font_override("font", FontHekayat)
	_card_tray_count_lbl.add_theme_font_size_override("font_size", 28)
	_card_tray_count_lbl.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84))
	_card_tray_count_lbl.text = "🃏 دست کارت‌ها (۰)"
	tray_header.add_child(_card_tray_count_lbl)

	# Horizontally Scrollable Tabletop Card Row
	var hand_scroll = ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.custom_minimum_size = Vector2(0, 158)
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	tray_vbox.add_child(hand_scroll)

	_hand_cards_hbox = HBoxContainer.new()
	_hand_cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_cards_hbox.add_theme_constant_override("separation", 12)
	_hand_cards_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.add_child(_hand_cards_hbox)

	# --------------------------------------------------------------------------
	# F. COMPACT CONTEXTUAL ACTION PANEL (y = 1580 .. 1756px -> offset_top = -340 .. -164)
	# Strictly above BaseGameHUD BottomBar (offset_top = -154 .. 0)!
	# --------------------------------------------------------------------------
	var command_dock = PanelContainer.new()
	command_dock.name = "ContextualActionPanel"
	command_dock.anchor_left = 0.02
	command_dock.anchor_right = 0.98
	command_dock.anchor_top = 1.0
	command_dock.anchor_bottom = 1.0
	command_dock.offset_top = -340.0
	command_dock.offset_bottom = -164.0
	command_dock.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.10, 0.065, 0.045, 0.95), Color(0.76, 0.58, 0.26), 18, 2, 16, 8)
	)
	_hud_root.add_child(command_dock)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 4)
	dock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	command_dock.add_child(dock_vbox)

	_phase_banner_lbl = Label.new()
	_phase_banner_lbl.add_theme_font_override("font", FontHekayat)
	_phase_banner_lbl.add_theme_font_size_override("font_size", 28)
	_phase_banner_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.54))
	_phase_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_lbl.clip_text = true
	dock_vbox.add_child(_phase_banner_lbl)

	_selection_info_lbl = Label.new()
	_selection_info_lbl.add_theme_font_override("font", FontHekayat)
	_selection_info_lbl.add_theme_font_size_override("font_size", 23)
	_selection_info_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_selection_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_info_lbl.clip_text = true
	dock_vbox.add_child(_selection_info_lbl)

	_sub_scroll = ScrollContainer.new()
	_sub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sub_scroll.custom_minimum_size = Vector2(0, 48)
	_sub_scroll.visible = false
	_sub_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	dock_vbox.add_child(_sub_scroll)

	_sub_options_row = HBoxContainer.new()
	_sub_options_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_options_row.add_theme_constant_override("separation", 10)
	_sub_options_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_sub_scroll.add_child(_sub_options_row)

	var act_scroll = ScrollContainer.new()
	act_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	act_scroll.custom_minimum_size = Vector2(0, 58)
	act_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	dock_vbox.add_child(act_scroll)

	_action_buttons_row = HBoxContainer.new()
	_action_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_buttons_row.add_theme_constant_override("separation", 12)
	_action_buttons_row.mouse_filter = Control.MOUSE_FILTER_PASS
	act_scroll.add_child(_action_buttons_row)

func _make_panel_style(
	bg: Color,
	border: Color,
	radius: int = 16,
	border_w: int = 2,
	pad_x: int = 14,
	pad_y: int = 8
) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	sb.shadow_size = 8
	return sb

func _make_styled_button(
	text: String,
	bg: Color,
	border: Color,
	font_sz: int = 27,
	radius: int = 12,
	is_primary: bool = false
) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(0.99, 0.96, 0.88))
	var bw = 2 if is_primary else 1
	var sb_norm = _make_panel_style(bg, border, radius, bw, 14, 6)
	var sb_hover = _make_panel_style(bg.lightened(0.12), border.lightened(0.18), radius, bw, 14, 6)
	var sb_press = _make_panel_style(bg.darkened(0.14), border, radius, bw, 14, 6)
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)
	return btn

# Builds a crafted tabletop card widget inside the Dedicated Card Hand Tray
func _build_hand_card_widget(entry: Dictionary, card_idx: int, is_selected: bool) -> Control:
	var kind: String = str(entry.get("kind", "continent"))
	var cid: String = str(entry.get("id", ""))
	var count: int = _to_int(entry.get("count", 1))

	var wrapper = MarginContainer.new()
	wrapper.custom_minimum_size = Vector2(146, 154)
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	# Smooth vertical elevation when selected (0px top margin when raised vs 12px when resting)
	wrapper.add_theme_constant_override("margin_top", 0 if is_selected else 12)
	wrapper.add_theme_constant_override("margin_bottom", 12 if is_selected else 0)

	var accent_col: Color = Color(0.24, 0.54, 0.36)
	var icon_txt: String = "🏰"
	var title_txt: String = cid
	var sub_txt: String = ""
	if kind == "continent":
		accent_col = RiskMaterials.CONTINENT_COLORS.get(cid, Color(0.24, 0.54, 0.36))
		var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(cid, {}).get("domination", 4))
		var has_dom: bool = my_tokens.has(cid)
		icon_txt = "👑" if has_dom else "🗺️"
		title_txt = _continent_fa(cid)
		if has_dom:
			sub_txt = "👑 سلطه شما (%s/%s)" % [Risk3DFactory.fa_digits(count), Risk3DFactory.fa_digits(dom_req)]
		else:
			sub_txt = "👑 حد نصاب: %s/%s" % [Risk3DFactory.fa_digits(count), Risk3DFactory.fa_digits(dom_req)]
	else:
		var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(cid, {})
		accent_col = sm.get("color", Color(0.76, 0.24, 0.24))
		icon_txt = str(sm.get("icon", "⚡"))
		title_txt = str(sm.get("fa", cid))
		sub_txt = str(sm.get("short", "استراتژی"))

	var card_bg = Color(0.16, 0.12, 0.08, 0.98) if is_selected else Color(0.11, 0.08, 0.055, 0.95)
	var border_col = Color(0.98, 0.84, 0.30) if is_selected else accent_col.lightened(0.15)
	var border_w = 3 if is_selected else 1

	var card_btn = Button.new()
	card_btn.focus_mode = Control.FOCUS_NONE
	card_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_norm = _make_panel_style(card_bg, border_col, 14, border_w, 8, 6)
	var sb_hover = _make_panel_style(card_bg.lightened(0.08), border_col.lightened(0.15), 14, border_w, 8, 6)
	var sb_press = _make_panel_style(card_bg.darkened(0.10), border_col, 14, border_w, 8, 6)
	card_btn.add_theme_stylebox_override("normal", sb_norm)
	card_btn.add_theme_stylebox_override("hover", sb_hover)
	card_btn.add_theme_stylebox_override("pressed", sb_press)
	card_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		_on_hand_card_selected(card_idx)
	)
	wrapper.add_child(card_btn)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(vbox)

	# Colored Top Banner Strip with Large, Bold Card Count Badge
	var banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.custom_minimum_size = Vector2(0, 42)
	var banner_sb = StyleBoxFlat.new()
	banner_sb.bg_color = accent_col.darkened(0.12)
	banner_sb.set_corner_radius_all(9)
	banner_sb.content_margin_left = 8
	banner_sb.content_margin_right = 8
	banner_sb.content_margin_top = 2
	banner_sb.content_margin_bottom = 2
	banner.add_theme_stylebox_override("panel", banner_sb)
	vbox.add_child(banner)

	var banner_hbox = HBoxContainer.new()
	banner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_hbox)

	var badge_lbl = Label.new()
	badge_lbl.text = "×" + Risk3DFactory.fa_digits(count)
	badge_lbl.add_theme_font_override("font", FontHekayat)
	badge_lbl.add_theme_font_size_override("font_size", 36)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45) if count > 1 else Color(1.0, 0.98, 0.90))
	badge_lbl.add_theme_constant_override("outline_size", 6)
	badge_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.96))
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(badge_lbl)

	var ic_lbl = Label.new()
	ic_lbl.text = icon_txt
	ic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ic_lbl.add_theme_font_size_override("font_size", 26)
	ic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(ic_lbl)

	# Card Title
	var title_lbl = Label.new()
	title_lbl.text = title_txt
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72) if is_selected else Color(0.96, 0.93, 0.86))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	# Card Subtitle / Short Effect
	var sub_lbl = Label.new()
	sub_lbl.text = sub_txt
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.add_theme_font_override("font", FontHekayat)
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", accent_col.lightened(0.42))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	return wrapper

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
			var gid = _to_int(payload.get("gamer_id", _active_turn))
			var dtype = _to_int(payload.get("draw_type", 1))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"])
			elif payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"])
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"])
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
				_sync_private_user_data(payload["new_user_data"])
			if payload.has("continents"):
				continent_deck_count = _to_int(payload.get("continents", continent_deck_count))
			if payload.has("strategies"):
				strategy_deck_count = _to_int(payload.get("strategies", strategy_deck_count))
			_refresh_all_3d_and_hud()

		Commands.Declare_Attack:
			var atk_id = _to_int(payload.get("gamer_id", _active_turn))
			var def_id = _to_int(payload.get("target_index", 0))
			var src_c = str(payload.get("source_continent", ""))
			var tgt_c = str(payload.get("target_continent", ""))
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
			var atk_id = _to_int(payload.get("gamer_id", active_attack.get("attacker_id", _active_turn)))
			var def_id = _to_int(payload.get("target_index", active_attack.get("defender_id", 0)))
			var committed = _to_int(payload.get("count", 0))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"])
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
			var gid = _to_int(payload.get("gamer_id", payload.get("gamer_index", _active_turn)))
			if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
				_parse_players_data_array(payload["players_data"])
			elif payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				_apply_single_player_public_data(gid, payload["new_data"])
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				_parse_board_tokens(payload["tokens"])
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
	_rebuild_hand_entries()

func _rebuild_hand_entries() -> void:
	_hand_entries.clear()
	var c_keys = my_continents.keys()
	c_keys.sort()
	for c_id in c_keys:
		var cnt = _to_int(my_continents[c_id])
		if cnt > 0:
			_hand_entries.append({"kind": "continent", "id": str(c_id), "count": cnt})

	var strat_counts: Dictionary = {}
	for s_name in my_strategies:
		var sn = str(s_name)
		strat_counts[sn] = _to_int(strat_counts.get(sn, 0)) + 1
	var s_keys = strat_counts.keys()
	s_keys.sort()
	for sn in s_keys:
		_hand_entries.append({"kind": "strategy", "id": str(sn), "count": _to_int(strat_counts[sn])})

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
	var stopped = bool(data.get("stopped", false))
	var atk_id = _to_int(data.get("attacker_id", active_attack.get("attacker_id", _active_turn)))
	var def_id = _to_int(data.get("defender_id", active_attack.get("defender_id", 0)))
	var src_c = str(data.get("source_continent", active_attack.get("source_continent", "")))
	var tgt_c = str(data.get("target_continent", active_attack.get("target_continent", "")))
	var battle_continues = bool(data.get("battle_continues", false)) and (game_state == "Attack")

	var atk_loss = _to_int(data.get("attacker_losses", 0))
	var def_loss = _to_int(data.get("defender_losses", 0))
	var atk_c_loss = _to_int(data.get("attacker_continent_losses", atk_loss))
	var def_c_loss = _to_int(data.get("defender_continent_losses", def_loss))
	var returned_c_count = _to_int(data.get("returned_continents_count", atk_c_loss + def_c_loss))

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

	var atk_dice: Array = data.get("attacker_dice", []) if typeof(data.get("attacker_dice", [])) == TYPE_ARRAY else []
	var def_dice: Array = data.get("defender_dice", []) if typeof(data.get("defender_dice", [])) == TYPE_ARRAY else []
	var conquered = bool(data.get("conquered", false))

	if not atk_dice.is_empty() or not def_dice.is_empty():
		_spawn_and_roll_3d_dice(atk_dice, def_dice)

	# Visually return lost Continent (قاره) cards from the battlefield back to the center of the table!
	if atk_c_loss > 0:
		_animate_returned_continent_cards_to_table(src_c, atk_c_loss)
	if def_c_loss > 0:
		_animate_returned_continent_cards_to_table(tgt_c, def_c_loss)

	var atk_str = _format_dice_list(atk_dice)
	var def_str = _format_dice_list(def_dice)
	var msg = "🎲 نبرد در «%s» — تاس مهاجم: %s | تاس مدافع: %s\nتلفات مهاجم: %s | تلفات مدافع: %s" % [
		_continent_fa(tgt_c),
		atk_str,
		def_str,
		Risk3DFactory.fa_digits(atk_loss),
		Risk3DFactory.fa_digits(def_loss),
	]
	if returned_c_count > 0:
		msg += "  (♻️ %s کارت قاره به مرکز میز برگشت)" % Risk3DFactory.fa_digits(returned_c_count)
	if conquered:
		msg += "  🏆 قاره فتح شد!"
	_show_combat_toast(msg, 4.8)
	_append_battle_log("🎲 نبرد %s -> %s: تاس مهاجم %s، مدافع %s (تلفات %s/%s)" % [
		_continent_fa(src_c), _continent_fa(tgt_c), atk_str, def_str,
		Risk3DFactory.fa_digits(atk_loss), Risk3DFactory.fa_digits(def_loss)
	])
	_refresh_all_3d_and_hud()
	_announce_token_events_and_victory(data)

func _handle_strategy_result_payload(data: Dictionary) -> void:
	var gid = _to_int(data.get("gamer_id", _active_turn))
	var strat = str(data.get("strategy", ""))
	var tgt_id = _to_int(data.get("target_index", 0))
	if data.has("players_data") and typeof(data["players_data"]) == TYPE_ARRAY:
		_parse_players_data_array(data["players_data"])
	if data.has("tokens") and typeof(data["tokens"]) == TYPE_ARRAY:
		_parse_board_tokens(data["tokens"])
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

	# If Destroy or Bomb removed a Continent card, animate it returning to the center of the table!
	if data.has("returned_continents") and typeof(data["returned_continents"]) == TYPE_ARRAY:
		for rc in data["returned_continents"]:
			_animate_returned_continent_cards_to_table(str(rc), 1)
	elif strat == "Destroy" and data.has("target_continent"):
		_animate_returned_continent_cards_to_table(str(data.get("target_continent", "")), 1)

	var strat_fa = Risk3DFactory.STRATEGY_META.get(strat, {}).get("fa", strat)
	var target_txt = (" علیه " + _get_player_name(tgt_id)) if tgt_id > 0 else ""
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
		for ev in data["token_events"]:
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var ev_type = str(ev.get("type", ""))
			var c_id = str(ev.get("continent", ""))
			var c_fa = _continent_fa(c_id)
			var dom_req = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
			var winner_p = _to_int(ev.get("winner", 0))
			if winner_p > 0 and ev_type in ["claimed_by_threshold", "stolen_by_threshold", "claimed_by_conquest", "stolen_by_conquest"]:
				var p_tok_cnt = (players_state.get(winner_p, {}).get("tokens", []) as Array).size()
				var line = "👑 %s با رسیدن به حد نصاب «%s» (%s کارت)، نشان سلطه این قاره را تصاحب کرد! (%s/۲)" % [
					_get_player_name(winner_p),
					c_fa,
					Risk3DFactory.fa_digits(dom_req),
					Risk3DFactory.fa_digits(p_tok_cnt),
				]
				tok_msgs.append(line)
				_append_battle_log(line)

	var is_fin = bool(data.get("is_game_finished", false))
	var win_id = _to_int(data.get("winner", 0))
	if is_fin and win_id > 0:
		var win_toks: Array = players_state.get(win_id, {}).get("tokens", [])
		var tok_names: Array[String] = []
		for t in win_toks:
			tok_names.append(_continent_fa(str(t)))
		var toks_joined = " و ".join(tok_names) if not tok_names.is_empty() else "۲ قاره"
		var win_msg = "🏆 پایان بازی! %s با کسب ۲ نشان سلطه (%s) پیروز میدان شد!" % [
			_get_player_name(win_id),
			toks_joined,
		]
		_append_battle_log(win_msg)
		if is_instance_valid(_phase_banner_lbl):
			_phase_banner_lbl.text = win_msg
		if is_instance_valid(_selection_info_lbl):
			_selection_info_lbl.text = "شرط پیروزی طبق کتابچه قوانین: کسب ۲ نشان سلطه قاره‌ها (👑 ۲/۲)"
		_show_combat_toast(win_msg, 5.5)
	elif not tok_msgs.is_empty():
		_show_combat_toast("\n".join(tok_msgs), 4.6)

func _restart_hud_turn_timer() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(30.0)

# ==============================================================================
# 4. 3D VISUAL REFRESH (CONTINENTS, STATIONS, DECKS, BRIDGES)
# ==============================================================================

func _refresh_all_3d_and_hud() -> void:
	_rebuild_hand_entries()
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
		var vis_layers = clampi(int(ceil(float(continent_deck_count) / 5.0)), 1, 8)
		for i in range(cd["layers"].size()):
			cd["layers"][i].visible = (i < vis_layers and continent_deck_count > 0)

	if _table_refs.has("strategy_deck"):
		var sd = _table_refs["strategy_deck"]
		sd["count_lbl"].text = Risk3DFactory.fa_digits(strategy_deck_count)
		sd["glow"].visible = (_is_my_turn() and game_state == "Draw")
		var vis_layers = clampi(int(ceil(float(strategy_deck_count) / 5.0)), 1, 8)
		for i in range(sd["layers"].size()):
			sd["layers"][i].visible = (i < vis_layers and strategy_deck_count > 0)

func _get_continent_owner_player(c_id: String) -> int:
	# 1. If a player holds the Domination Coin for this continent, they are the sovereign owner
	for p_idx in range(1, total_players + 1):
		var p_toks: Array = players_state.get(p_idx, {}).get("tokens", [])
		if p_toks.has(c_id):
			return p_idx
	# 2. Otherwise, if a single player has the strictly largest unit count on this continent, show their ownership border
	var best_p: int = 0
	var best_cnt: int = 0
	var tied: bool = false
	for p_idx in range(1, total_players + 1):
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

	for c_id in _continent_nodes.keys():
		var c_ref: Dictionary = _continent_nodes[c_id]
		c_ref["token_node"].visible = board_tokens.has(c_id)

		# Update Ownership Border & Plaque Trim Color
		var owner_p: int = _get_continent_owner_player(c_id)
		var bezel_mat: StandardMaterial3D = RiskMaterials.get_ownership_bezel_material(owner_p, _mats)
		if c_ref.has("ownership_bezel") and is_instance_valid(c_ref["ownership_bezel"]):
			(c_ref["ownership_bezel"] as MeshInstance3D).material_override = bezel_mat
		if c_ref.has("plaque_trim") and is_instance_valid(c_ref["plaque_trim"]):
			(c_ref["plaque_trim"] as MeshInstance3D).material_override = bezel_mat

		var garrisons: Dictionary = c_ref["garrisons"]
		var present_players: Array[int] = []
		for p_idx in [1, 2, 3, 4]:
			var g_ref: Dictionary = garrisons[p_idx]
			var p_conts: Dictionary = players_state.get(p_idx, {}).get("continents", {})
			var cnt: int = _to_int(p_conts.get(c_id, 0))
			if cnt > 0 and p_idx <= total_players:
				g_ref["node"].visible = true
				g_ref["label"].text = "×" + Risk3DFactory.fa_digits(cnt)
				# Show 1..3 stacked discs proportional to unit count
				var vis_discs: int = clampi(cnt, 1, 3)
				if g_ref.has("stack_discs"):
					var discs: Array = g_ref["stack_discs"]
					for d_i in range(discs.size()):
						discs[d_i].visible = (d_i < vis_discs)
				if g_ref.has("piece") and is_instance_valid(g_ref["piece"]):
					(g_ref["piece"] as Node3D).position.y = 0.003 + float(vis_discs) * 0.005
				present_players.append(p_idx)
			else:
				g_ref["node"].visible = false

		if not present_players.is_empty():
			Risk3DFactory.layout_continent_garrisons(c_ref, present_players)

		var aura: MeshInstance3D = c_ref["aura"]
		var plateau: MeshInstance3D = c_ref["plateau"]
		var is_atk_src = (active_attack.get("source_continent", "") == c_id)
		var is_atk_tgt = (active_attack.get("target_continent", "") == c_id)
		var is_highlighted = false
		if is_atk_src or c_id == selected_source_continent or c_id == _inspected_continent_id:
			aura.visible = true
			aura.material_override = _mats["glow_gold"]
			is_highlighted = true
		elif is_atk_tgt or c_id == selected_target_continent:
			aura.visible = true
			aura.material_override = _mats["glow_crimson"]
			is_highlighted = true
		elif valid_targets.has(c_id):
			aura.visible = true
			aura.material_override = _mats["glow_emerald"]
			is_highlighted = true
		else:
			aura.visible = false
		plateau.material_override = RiskMaterials.get_continent_material(c_id, is_highlighted)

	for pair_key in _bridge_nodes.keys():
		var b_node: Node = _bridge_nodes[pair_key]
		var highlight: bool = false
		if not active_attack.is_empty():
			var sc = str(active_attack.get("source_continent", ""))
			var tc = str(active_attack.get("target_continent", ""))
			if pair_key == (sc + "_" + tc) or pair_key == (tc + "_" + sc):
				highlight = true
		elif focus_source != "":
			if pair_key.begins_with(focus_source + "_") or pair_key.ends_with("_" + focus_source):
				highlight = true
		Risk3DFactory.set_bridge_material(b_node, _mats["bridge_active"] if highlight else _mats["bridge_idle"])

func _refresh_3d_player_stations() -> void:
	var needs_opp_target: bool = (selected_strategy_name in ["Bomb", "Destroy", "Spy"])

	for p_idx in _station_nodes.keys():
		var st_ref: Dictionary = _station_nodes[p_idx]
		var p_data: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
		var is_turn = (_active_turn == p_idx)
		st_ref["active_glow"].visible = is_turn
		st_ref["commander_mi"].material_override = st_ref["f_mat_active"] if is_turn else st_ref["f_mat_idle"]
		st_ref["target_glow"].visible = (needs_opp_target and p_idx != my_player_index) or (selected_target_player == p_idx)

		Risk3DFactory.populate_station_assets_3d(st_ref, p_data, _mats, FontHekayat, _crown_mesh)

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
# 5. CONTEXTUAL FLOATING HUD, DEDICATED CARD HAND TRAY & LEGAL ACTIONS
# ==============================================================================

func _refresh_floating_hud() -> void:
	_update_hud_visibility()
	if not is_instance_valid(_hud_root):
		return

	# 1. Update Top Status & Utility Strip
	var my_tok_cnt = my_tokens.size()
	if is_instance_valid(_top_decks_lbl):
		_top_decks_lbl.text = "👑 %s/۲   |   🗺️ %s   |   ⚡ %s" % [
			Risk3DFactory.fa_digits(my_tok_cnt),
			Risk3DFactory.fa_digits(continent_deck_count),
			Risk3DFactory.fa_digits(strategy_deck_count),
		]
	if is_instance_valid(_top_turn_lbl):
		if _is_my_turn():
			_top_turn_lbl.text = "🟢 نوبت شما • %s" % _phase_fa(game_state)
			_top_turn_lbl.add_theme_color_override("font_color", Color(0.52, 0.96, 0.66))
		else:
			_top_turn_lbl.text = "⏳ نوبت %s • %s" % [_get_player_name(_active_turn), _phase_fa(game_state)]
			_top_turn_lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.48))

	# 1B. Update Compact Selected Region Contextual Inspector (Outside the Board)
	_refresh_selected_region_inspector()

	# 2. Populate Dedicated Card Hand Tray
	if is_instance_valid(_hand_cards_hbox):
		for ch in _hand_cards_hbox.get_children():
			ch.queue_free()

		var total_c_cards = _sum_dict_values(my_continents)
		var total_s_cards = my_strategies.size()
		if is_instance_valid(_card_tray_count_lbl):
			_card_tray_count_lbl.text = "🃏 دست شما: %s قاره  |  %s استراتژی" % [
				Risk3DFactory.fa_digits(total_c_cards),
				Risk3DFactory.fa_digits(total_s_cards),
			]

		var preview_str = "برای انتخاب قاره مبدا یا اجرای استراتژی، روی کارت ضربه بزنید"
		for i in range(_hand_entries.size()):
			var entry: Dictionary = _hand_entries[i]
			var c_kind: String = str(entry["kind"])
			var c_id: String = str(entry["id"])
			var is_sel: bool = (i == selected_hand_card_idx) or (c_kind == "continent" and c_id == selected_source_continent) or (c_kind == "strategy" and c_id == selected_strategy_name)
			if is_sel:
				if c_kind == "continent":
					preview_str = "🗺️ قاره «%s» انتخاب شد (%s نیرو) — قاره هدف را روی تخته انتخاب کنید" % [
						_continent_fa(c_id), Risk3DFactory.fa_digits(_to_int(entry["count"]))
					]
				else:
					var sm = Risk3DFactory.STRATEGY_META.get(c_id, {})
					preview_str = "⚡ %s: %s" % [str(sm.get("fa", c_id)), str(sm.get("desc", ""))]
			var card_widget = _build_hand_card_widget(entry, i, is_sel)
			_hand_cards_hbox.add_child(card_widget)

		if _hand_entries.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "هیچ کارتی در دست شما نیست — در ابتدای نوبت از دسته‌های بالا کارت بکشید"
			empty_lbl.add_theme_font_override("font", FontHekayat)
			empty_lbl.add_theme_font_size_override("font_size", 24)
			empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62))
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_hand_cards_hbox.add_child(empty_lbl)

		if is_instance_valid(_card_preview_lbl):
			_card_preview_lbl.text = preview_str

	# 3. Clear Contextual Action Panel Rows
	for ch in _action_buttons_row.get_children():
		ch.queue_free()
	for ch in _sub_options_row.get_children():
		ch.queue_free()
	if is_instance_valid(_opponent_quick_row):
		for ch in _opponent_quick_row.get_children():
			ch.queue_free()

	# Populate Player Filter Tabs inside Inspector Modal (and refresh open inspector card view)
	_populate_inspector_filter_chips()
	if is_instance_valid(_inspector_panel) and _inspector_panel.visible:
		_rebuild_inspector_cards_view(_inspected_player_filter)

	var def_id = _to_int(active_attack.get("defender_id", 0))
	var atk_id = _to_int(active_attack.get("attacker_id", _active_turn))

	# 4A. ONGOING MULTI-ROUND BATTLE PHASE (`Attack` — No new Army cards allowed once attack starts!)
	if game_state == "Attack":
		var src_fa = _continent_fa(str(active_attack.get("source_continent", "")))
		var tgt_fa = _continent_fa(str(active_attack.get("target_continent", "")))
		if atk_id == my_player_index:
			_phase_banner_lbl.text = "🎲 ادامه نبرد از «%s» به «%s» (افزودن ارتش کمکی جدید بسته شد)" % [src_fa, tgt_fa]
			_selection_info_lbl.text = "پس از شروع نبرد، بازیکنان دیگر نمی‌توانند کارت ارتش کمکی جدید اضافه کنند. ادامه نبرد یا توقف؟"

			var btn_roll_again = _make_styled_button(
				"🎲 ادامه نبرد و پرتاب مجدد تاس",
				Color(0.46, 0.14, 0.14, 0.98),
				Color(0.96, 0.48, 0.36),
				28,
				12,
				true
			)
			btn_roll_again.custom_minimum_size = Vector2(310, 54)
			btn_roll_again.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.Attack, {})
			)
			_action_buttons_row.add_child(btn_roll_again)

			var btn_stop_atk = _make_styled_button(
				"⏹️ توقف حمله",
				Color(0.22, 0.16, 0.12, 0.96),
				Color(0.78, 0.62, 0.34),
				27,
				12
			)
			btn_stop_atk.custom_minimum_size = Vector2(185, 54)
			btn_stop_atk.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.Cancel_Attack, {"stop": true})
			)
			_action_buttons_row.add_child(btn_stop_atk)
		elif def_id == my_player_index:
			_phase_banner_lbl.text = "🛡️ نبرد در قاره «%s» ادامه دارد (بدون امکان افزودن ارتش کمکی جدید)" % tgt_fa
			_selection_info_lbl.text = "در انتظار تصمیم %s برای پرتاب مجدد تاس یا توقف حمله..." % _get_player_name(atk_id)
			if _count_my_strategy("Cancel") > 0:
				var btn_def_cancel = _make_styled_button(
					"🛡️ لغو کامل حمله (Cancel)",
					Color(0.14, 0.34, 0.42, 0.98),
					Color(0.38, 0.88, 0.96),
					27,
					12,
					true
				)
				btn_def_cancel.custom_minimum_size = Vector2(260, 54)
				btn_def_cancel.pressed.connect(func():
					AudioManager.sfx_button()
					send_move(Commands.Cancel_Attack, {})
				)
				_action_buttons_row.add_child(btn_def_cancel)
		else:
			_phase_banner_lbl.text = "🎲 نبرد بین %s و %s در قاره «%s» ادامه دارد..." % [
				_get_player_name(atk_id), _get_player_name(def_id), tgt_fa
			]
			_selection_info_lbl.text = "پس از شروع حمله، افزودن کارت ارتش کمکی جدید مجاز نیست."
		_update_sub_scroll_visibility()
		return

	# 4B. DEFENDER PHASE (`DefenderArmy` — Only before dice rolling starts)
	if game_state == "DefenderArmy":
		var src_fa = _continent_fa(str(active_attack.get("source_continent", "")))
		var tgt_fa = _continent_fa(str(active_attack.get("target_continent", "")))
		if def_id == my_player_index:
			var my_army_cards = _count_my_strategy("Army")
			var has_cancel = (_count_my_strategy("Cancel") > 0)
			var base_def_dice = clampi(_to_int(my_continents.get(str(active_attack.get("target_continent", "")), 1)), 1, 2)
			var max_def_extra = max(0, 4 - base_def_dice)
			var allowed_def_army = min(my_army_cards, max_def_extra)
			_phase_banner_lbl.text = "🛡️ دفاع از قاره «%s» (تاس پایه دفاع: %s)" % [tgt_fa, Risk3DFactory.fa_digits(base_def_dice)]
			_selection_info_lbl.text = "پیش از شروع پرتاب تاس، تعداد کارت ارتش کمکی دفاع یا لغو حمله را انتخاب کنید:"

			for c in range(allowed_def_army + 1):
				var is_picked = (selected_army_commit == c)
				var b = _make_styled_button(
					"🛡️ +%s ارتش کمکی" % Risk3DFactory.fa_digits(c),
					Color(0.28, 0.22, 0.08, 0.96) if is_picked else Color(0.14, 0.12, 0.10, 0.92),
					Color(0.98, 0.84, 0.28) if is_picked else Color(0.58, 0.46, 0.30),
					25,
					10,
					is_picked
				)
				b.custom_minimum_size = Vector2(158, 44)
				var count_val = c
				b.pressed.connect(func():
					AudioManager.sfx_tap()
					selected_army_commit = count_val
					_refresh_floating_hud()
				)
				_sub_options_row.add_child(b)

			var btn_defend = _make_styled_button(
				"🎲 تایید دفاع و شروع نبرد (+%s)" % Risk3DFactory.fa_digits(selected_army_commit),
				Color(0.14, 0.38, 0.22, 0.98),
				Color(0.42, 0.90, 0.58),
				28,
				12,
				true
			)
			btn_defend.custom_minimum_size = Vector2(310, 54)
			btn_defend.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.DefenderArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_defend)

			if has_cancel:
				var btn_cancel_atk = _make_styled_button(
					"🛡️ لغو کامل حمله (Cancel)",
					Color(0.14, 0.34, 0.42, 0.98),
					Color(0.38, 0.88, 0.96),
					27,
					12,
					true
				)
				btn_cancel_atk.custom_minimum_size = Vector2(260, 54)
				btn_cancel_atk.pressed.connect(func():
					AudioManager.sfx_button()
					send_move(Commands.DefenderArmy, {"count": 0, "cancel": true})
				)
				_action_buttons_row.add_child(btn_cancel_atk)
		else:
			_phase_banner_lbl.text = "⏳ در انتظار تصمیم دفاعی %s در قاره «%s»..." % [_get_player_name(def_id), tgt_fa]
			_selection_info_lbl.text = "نبرد از «%s» به «%s» در آستانه شروع است." % [src_fa, tgt_fa]
		_update_sub_scroll_visibility()
		return

	# 5. ATTACKER REINFORCEMENT PHASE (`AttackerArmy` — Only before dice rolling starts)
	if game_state == "AttackerArmy":
		var src_fa = _continent_fa(str(active_attack.get("source_continent", "")))
		var tgt_fa = _continent_fa(str(active_attack.get("target_continent", "")))
		if atk_id == my_player_index:
			var my_army_cards = _count_my_strategy("Army")
			var base_atk_dice = clampi(_to_int(my_continents.get(str(active_attack.get("source_continent", "")), 1)), 1, 3)
			var max_atk_extra = max(0, 5 - base_atk_dice)
			var allowed_atk_army = min(my_army_cards, max_atk_extra)
			_phase_banner_lbl.text = "⚔️ تقویت حمله از «%s» به «%s» (تاس پایه: %s)" % [src_fa, tgt_fa, Risk3DFactory.fa_digits(base_atk_dice)]
			_selection_info_lbl.text = "پیش از شروع نبرد، تعداد کارت «ارتش کمکی» را انتخاب کنید (پس از شروع نبرد قابل افزودن نیست):"

			for c in range(allowed_atk_army + 1):
				var is_picked = (selected_army_commit == c)
				var b = _make_styled_button(
					"⚔️ +%s ارتش کمکی" % Risk3DFactory.fa_digits(c),
					Color(0.34, 0.16, 0.08, 0.96) if is_picked else Color(0.14, 0.12, 0.10, 0.92),
					Color(0.98, 0.82, 0.28) if is_picked else Color(0.58, 0.46, 0.30),
					25,
					10,
					is_picked
				)
				b.custom_minimum_size = Vector2(158, 44)
				var count_val = c
				b.pressed.connect(func():
					AudioManager.sfx_tap()
					selected_army_commit = count_val
					_refresh_floating_hud()
				)
				_sub_options_row.add_child(b)

			var btn_commit = _make_styled_button(
				"⚔️ تایید ارتش مهاجم (+%s تاس)" % Risk3DFactory.fa_digits(selected_army_commit),
				Color(0.46, 0.14, 0.14, 0.98),
				Color(0.96, 0.48, 0.36),
				28,
				12,
				true
			)
			btn_commit.custom_minimum_size = Vector2(300, 54)
			btn_commit.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.AttackerArmy, {"count": selected_army_commit})
			)
			_action_buttons_row.add_child(btn_commit)

			if _count_my_strategy("Canon") > 0:
				var btn_canon = _make_styled_button(
					"🎯 توپخانه (+۱ به بالاترین تاس)",
					Color(0.36, 0.26, 0.08, 0.98),
					Color(0.96, 0.82, 0.28),
					26,
					12
				)
				btn_canon.custom_minimum_size = Vector2(270, 54)
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

	# 6. NOT MY TURN
	if not _is_my_turn():
		_phase_banner_lbl.text = "⏳ نوبت فرماندهی %s (%s)" % [_get_player_name(_active_turn), _phase_fa(game_state)]
		_selection_info_lbl.text = "روی هر قاره روی تخته کلیک کنید تا وضعیت نیروهای مستقر در آن را ببینید."
		_update_sub_scroll_visibility()
		return

	# 7. MY TURN - DRAW PHASE (`Draw`)
	if game_state == "Draw":
		_phase_banner_lbl.text = "🃏 فاز کشیدن کارت: ۲ کارت از دسته‌های قاره یا استراتژی دریافت کنید"
		if not _first_3d_deck_picked.is_empty():
			var first_fa = "قاره 🗺️" if _first_3d_deck_picked == "continent" else "استراتژی ⚡"
			_selection_info_lbl.text = "✅ کارت اول (%s) انتخاب شد؛ اکنون دسته دوم را انتخاب کنید!" % first_fa
		else:
			_selection_info_lbl.text = "می‌توانید روی دسته‌های بالای تخته بزنید یا یکی از گزینه‌های زیر را انتخاب کنید:"

		var btn_d1 = _make_styled_button("🗺️ ۲ کارت قاره", Color(0.12, 0.34, 0.22, 0.98), Color(0.38, 0.88, 0.56), 27, 12, true)
		btn_d1.custom_minimum_size = Vector2(215, 54)
		btn_d1.pressed.connect(func(): _send_draw_card(1))
		_action_buttons_row.add_child(btn_d1)

		var btn_d3 = _make_styled_button("⚖️ ۱ قاره + ۱ استراتژی", Color(0.28, 0.22, 0.10, 0.98), Color(0.94, 0.78, 0.32), 27, 12, true)
		btn_d3.custom_minimum_size = Vector2(250, 54)
		btn_d3.pressed.connect(func(): _send_draw_card(3))
		_action_buttons_row.add_child(btn_d3)

		var btn_d2 = _make_styled_button("⚡ ۲ کارت استراتژی", Color(0.38, 0.14, 0.16, 0.98), Color(0.90, 0.44, 0.44), 27, 12, true)
		btn_d2.custom_minimum_size = Vector2(225, 54)
		btn_d2.pressed.connect(func(): _send_draw_card(2))
		_action_buttons_row.add_child(btn_d2)
		_update_sub_scroll_visibility()
		return

	# 8. MY TURN - SELECT ACTION PHASE (`SelectAction`)
	_phase_banner_lbl.text = "⚔️ فاز عملیات: قاره خودی را برای حمله یا کارت استراتژی را برای اجرا انتخاب کنید"
	if selected_strategy_name != "":
		_populate_strategy_action_controls()
	elif selected_source_continent != "":
		_populate_attack_action_controls()
	else:
		_selection_info_lbl.text = "روی یکی از قاره‌های خود روی تخته یا کارت‌های دستتان ضربه بزنید."

	if selected_source_continent != "" or selected_strategy_name != "":
		var btn_clear = _make_styled_button("✖ لغو انتخاب", Color(0.20, 0.14, 0.12, 0.94), Color(0.62, 0.46, 0.34), 25, 12)
		btn_clear.custom_minimum_size = Vector2(145, 54)
		btn_clear.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_hand_card_idx = -1
			selected_source_continent = ""
			selected_target_continent = ""
			selected_strategy_name = ""
			_refresh_all_3d_and_hud()
		)
		_action_buttons_row.add_child(btn_clear)

	var btn_pass = _make_styled_button("⏭️ پایان نوبت", Color(0.22, 0.16, 0.10, 0.95), Color(0.78, 0.62, 0.32), 27, 12)
	btn_pass.custom_minimum_size = Vector2(185, 54)
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
		var valid_targets = _get_valid_attack_target_continents(selected_source_continent)
		if valid_targets.is_empty():
			_selection_info_lbl.text = "هیچ نیروی دشمنی در قاره‌های هم‌مرز با «%s» حضور ندارد." % src_fa
			return
		_selection_info_lbl.text = "مبدا حمله: «%s» (%s نیرو) — قاره هدف را روی تخته یا از دکمه‌های زیر انتخاب کنید:" % [
			src_fa, Risk3DFactory.fa_digits(my_cnt)
		]
		for tc in valid_targets:
			var b_t = _make_styled_button("🎯 %s" % _continent_fa(tc), Color(0.12, 0.30, 0.18, 0.96), Color(0.40, 0.88, 0.56), 25, 10)
			b_t.custom_minimum_size = Vector2(165, 44)
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
		_selection_info_lbl.text = "در قاره «%s» نیروی دشمنی حضور ندارد." % tgt_fa
		return

	if selected_target_player == 0 or not defenders.has(selected_target_player):
		selected_target_player = defenders[0]

	_selection_info_lbl.text = "آماده یورش از «%s» به «%s» علیه %s!" % [
		src_fa, tgt_fa, _get_player_name(selected_target_player)
	]

	if defenders.size() > 1:
		for d_id in defenders:
			var is_sel = (selected_target_player == d_id)
			var b_d = _make_styled_button(
				"🎯 %s" % _get_player_name(d_id),
				Color(0.36, 0.16, 0.12, 0.96) if is_sel else Color(0.15, 0.12, 0.10, 0.92),
				Color(0.98, 0.82, 0.28) if is_sel else Color(0.62, 0.50, 0.32),
				25,
				10,
				is_sel
			)
			b_d.custom_minimum_size = Vector2(165, 44)
			var def_p = d_id
			b_d.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_target_player = def_p
				_refresh_all_3d_and_hud()
			)
			_sub_options_row.add_child(b_d)

	var btn_atk = _make_styled_button(
		"⚔️ اعلان حمله به «%s» (%s)" % [tgt_fa, _get_player_name(selected_target_player)],
		Color(0.48, 0.14, 0.14, 0.98),
		Color(0.96, 0.50, 0.36),
		28,
		12,
		true
	)
	btn_atk.custom_minimum_size = Vector2(310, 54)
	btn_atk.pressed.connect(_send_declare_attack)
	_action_buttons_row.add_child(btn_atk)

func _populate_strategy_action_controls() -> void:
	var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(selected_strategy_name, {})
	var strat_fa = str(sm.get("fa", selected_strategy_name))
	var desc = str(sm.get("desc", ""))
	_selection_info_lbl.text = "⚡ «%s»: %s" % [strat_fa, desc]

	if bool(sm.get("combat_only", false)):
		_selection_info_lbl.text = "🛡️ کارت «%s» فقط هنگام دفاع در برابر حمله حریف قابل استفاده است." % strat_fa
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
			var b_op = _make_styled_button(
				"🎯 %s" % _get_player_name(op_id),
				Color(0.36, 0.16, 0.12, 0.96) if is_sel else Color(0.15, 0.12, 0.10, 0.92),
				Color(0.98, 0.82, 0.28) if is_sel else Color(0.62, 0.48, 0.30),
				25,
				10,
				is_sel
			)
			b_op.custom_minimum_size = Vector2(168, 44)
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
			var b_c = _make_styled_button(
				"🗺️ %s" % _continent_fa(ck),
				Color(0.32, 0.14, 0.20, 0.96) if is_c_sel else Color(0.14, 0.13, 0.13, 0.92),
				Color(0.98, 0.78, 0.30) if is_c_sel else Color(0.56, 0.46, 0.32),
				25,
				10,
				is_c_sel
			)
			b_c.custom_minimum_size = Vector2(160, 44)
			var c_val = ck
			b_c.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_target_continent = c_val
				_refresh_all_3d_and_hud()
			)
			_sub_options_row.add_child(b_c)

	var btn_play = _make_styled_button(
		"⚡ اجرای «%s»" % strat_fa,
		Color(0.14, 0.38, 0.22, 0.98),
		Color(0.42, 0.92, 0.58),
		28,
		12,
		true
	)
	btn_play.custom_minimum_size = Vector2(260, 54)
	btn_play.pressed.connect(_send_use_strategy)
	_action_buttons_row.add_child(btn_play)

# ==============================================================================
# 6. 3D RAYCAST INTERACTION (TABLE, CONTINENTS, DECKS, STATIONS)
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
	# Ignore taps inside the bottom Card Tray / Contextual Action Panel or Top Strip
	if screen_pos.y >= 1358.0 or screen_pos.y <= 400.0:
		return
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
		return

	var col: Object = hit["collider"]
	if not (col is Node) or not col.has_meta("interact_type"):
		return

	var itype = str(col.get_meta("interact_type"))
	AudioManager.sfx_tap()
	match itype:
		"deck":
			var dtype_str = str(col.get_meta("deck_type"))
			_on_3d_deck_clicked(dtype_str)
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

func _on_hand_card_selected(card_idx: int) -> void:
	if card_idx < 0 or card_idx >= _hand_entries.size():
		return
	var entry: Dictionary = _hand_entries[card_idx]
	var kind: String = str(entry["kind"])
	var cid: String = str(entry["id"])

	if game_state == "Attack" and cid == "Army":
		show_hint("⚠️ پس از شروع نبرد، افزودن کارت ارتش کمکی جدید مجاز نیست!")
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
	_refresh_all_3d_and_hud()

func _select_target_continent_for_attack(c_id: String) -> void:
	selected_target_continent = c_id
	_inspected_continent_id = c_id
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
	arena.visible = true

	# Elevate & scale the 3D Dice Arena to the center-front stage of the board during combat!
	if _dice_arena_tween and _dice_arena_tween.is_valid():
		_dice_arena_tween.kill()
	_dice_arena_tween = create_tween()
	_dice_arena_tween.set_parallel(true)
	_dice_arena_tween.tween_property(
		arena,
		"position",
		Vector3(0.0, 0.115, -0.02),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dice_arena_tween.tween_property(
		arena,
		"scale",
		Vector3(1.18, 1.18, 1.18),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var total_atk = atk_dice.size()
	var atk_spacing: float = 0.084
	var atk_start_x: float = -float(max(0, total_atk - 1)) * atk_spacing * 0.5
	for i in range(total_atk):
		var val = _to_int(atk_dice[i], 1)
		var die = Risk3DFactory.build_3d_die(true, _mats, FontHekayat, val)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos = Vector3(atk_start_x + float(i) * atk_spacing, 0.046, -0.048)
		_animate_single_3d_die(die, target_pos, val, float(i) * 0.06)

	var total_def = def_dice.size()
	var def_spacing: float = 0.088
	var def_start_x: float = -float(max(0, total_def - 1)) * def_spacing * 0.5
	for i in range(total_def):
		var val = _to_int(def_dice[i], 1)
		var die = Risk3DFactory.build_3d_die(false, _mats, FontHekayat, val)
		arena.add_child(die)
		_dice_nodes.append(die)
		var target_pos = Vector3(def_start_x + float(i) * def_spacing, 0.046, 0.048)
		_animate_single_3d_die(die, target_pos, val, 0.08 + float(i) * 0.06)

	# Smoothly return and hide the Dice Arena after the player inspects the roll
	var return_tw = create_tween()
	return_tw.tween_interval(4.8)
	return_tw.tween_property(arena, "position", Vector3(0.0, 0.048, -0.49), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tw.parallel().tween_property(arena, "scale", Vector3(0.62, 0.62, 0.62), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tw.tween_callback(func():
		if is_instance_valid(arena):
			arena.visible = false
	)

func _animate_single_3d_die(die: Node3D, final_pos: Vector3, final_val: int, delay: float) -> void:
	die.position = final_pos + Vector3(randf_range(-0.04, 0.04), 0.22, randf_range(-0.03, 0.03))
	var cube_pivot: Node3D = die.get_node_or_null("CubePivot") as Node3D
	var badge_lbl: Label3D = die.get_node_or_null("DieValueBadge") as Label3D
	if is_instance_valid(badge_lbl):
		badge_lbl.visible = false
		badge_lbl.scale = Vector3.ZERO

	var final_rot = Risk3DFactory.get_die_rotation_for_value(final_val)
	if is_instance_valid(cube_pivot):
		cube_pivot.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
	else:
		die.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))

	var tw = create_tween()
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

	# Pop in the floating Persian numeral badge right above the landed die
	tw.tween_callback(func():
		if is_instance_valid(badge_lbl):
			badge_lbl.visible = true
			var b_tw = create_tween()
			b_tw.tween_property(badge_lbl, "scale", Vector3(1.18, 1.18, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			b_tw.tween_property(badge_lbl, "scale", Vector3(1.0, 1.0, 1.0), 0.10)
	)


func _animate_deck_draw_pulse(draw_type: int) -> void:
	var targets: Array = []
	if draw_type in [1, 3] and _table_refs.has("continent_deck"):
		targets.append(_table_refs["continent_deck"]["stack"])
	if draw_type in [2, 3] and _table_refs.has("strategy_deck"):
		targets.append(_table_refs["strategy_deck"]["stack"])
	for st in targets:
		if is_instance_valid(st):
			var tw = create_tween()
			tw.tween_property(st, "scale", Vector3(1.12, 1.18, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(st, "scale", Vector3.ONE, 0.16)


func _animate_returned_continent_cards_to_table(from_continent_id: String, count: int) -> void:
	if count <= 0 or not is_inside_tree():
		return
	var start_pos := Vector3(0.0, 0.08, 0.0)
	if from_continent_id != "" and _continent_nodes.has(from_continent_id):
		start_pos = _continent_nodes[from_continent_id]["base_pos"] + Vector3(0.0, 0.09, 0.0)
	var end_pos := Vector3(-0.34, 0.09, -0.49)
	if _table_refs.has("continent_deck") and is_instance_valid(_table_refs["continent_deck"].get("root", null)):
		end_pos = _table_refs["continent_deck"]["root"].position + Vector3(0.0, 0.04, 0.0)

	var cards_to_fly: int = mini(count, 4)
	for i in range(cards_to_fly):
		var fly_card = Node3D.new()
		fly_card.name = "ReturnedContinentCard_%d" % i
		var card_mesh = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(0.11, 0.006, 0.15)
		card_mesh.mesh = b_mesh
		card_mesh.material_override = _mats.get("continent_card_back", _mats.get("gold", null))
		fly_card.add_child(card_mesh)

		var rim_mesh = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = Vector3(0.116, 0.004, 0.156)
		rim_mesh.mesh = r_box
		rim_mesh.material_override = _mats.get("gold", null)
		fly_card.add_child(rim_mesh)

		add_child(fly_card)
		fly_card.position = start_pos + Vector3(float(i) * 0.015, float(i) * 0.008, 0.0)
		var mid_pos = (start_pos + end_pos) * 0.5 + Vector3(0.0, 0.18, 0.0)
		var delay_s: float = float(i) * 0.09

		var tw = create_tween()
		if delay_s > 0.0:
			tw.tween_interval(delay_s)
		tw.tween_property(fly_card, "position", mid_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(fly_card, "rotation_degrees", Vector3(0.0, 180.0, 0.0), 0.24)
		tw.tween_property(fly_card, "position", end_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(fly_card, "rotation_degrees", Vector3(0.0, 360.0, 0.0), 0.24)
		tw.tween_callback(func():
			if is_instance_valid(fly_card):
				fly_card.queue_free()
			_animate_deck_draw_pulse(1)
			_refresh_3d_decks()
		)

func _process(delta: float) -> void:
	_anim_clock += delta
	_update_hud_visibility()

	for c_id in _continent_nodes.keys():
		var c_ref: Dictionary = _continent_nodes[c_id]
		var tok: Node3D = c_ref["token_node"]
		if is_instance_valid(tok) and tok.visible:
			tok.rotation.y = _anim_clock * 0.85

		# Gentle territory elevation when selected as source or target
		var c_root: Node3D = c_ref["root"]
		if is_instance_valid(c_root):
			var base_p: Vector3 = c_ref["base_pos"]
			var is_elevated = (c_id == selected_source_continent or c_id == selected_target_continent or active_attack.get("source_continent", "") == c_id or active_attack.get("target_continent", "") == c_id)
			var target_y = base_p.y + (0.012 if is_elevated else 0.0)
			c_root.position.y = lerpf(c_root.position.y, target_y, 10.0 * delta)

# ==============================================================================
# 9. INSPECTORS & LOG PANEL
# ==============================================================================

func _populate_inspector_filter_chips() -> void:
	if not is_instance_valid(_opponent_quick_row):
		return
	for ch in _opponent_quick_row.get_children():
		ch.queue_free()

	var is_all = (_inspected_player_filter == 0)
	var btn_all = _make_styled_button(
		"👥 همه بازیکنان",
		Color(0.28, 0.20, 0.08, 0.96) if is_all else Color(0.14, 0.10, 0.07, 0.92),
		Color(0.98, 0.84, 0.30) if is_all else Color(0.56, 0.42, 0.24),
		23,
		10,
		is_all
	)
	btn_all.custom_minimum_size = Vector2(150, 42)
	btn_all.pressed.connect(func():
		AudioManager.sfx_tap()
		_inspected_player_filter = 0
		_populate_inspector_filter_chips()
		_rebuild_inspector_cards_view(0)
	)
	_opponent_quick_row.add_child(btn_all)

	for p_idx in range(1, total_players + 1):
		var st: Dictionary = players_state.get(p_idx, {})
		var t_cnt: int = (st.get("tokens", []) as Array).size()
		var c_cnt: int = _sum_dict_values(st.get("continents", {}))
		var s_cnt: int = _to_int(st.get("strategies_count", 0))
		var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE)
		var is_sel: bool = (_inspected_player_filter == p_idx)
		var opp_btn = _make_styled_button(
			"%s (👑%s | 🃏%s)" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(t_cnt), Risk3DFactory.fa_digits(c_cnt + s_cnt)],
			f_col.darkened(0.45) if is_sel else f_col.darkened(0.68),
			Color(0.98, 0.86, 0.32) if is_sel else f_col.lightened(0.18),
			23,
			10,
			is_sel
		)
		opp_btn.custom_minimum_size = Vector2(184, 42)
		var target_p = p_idx
		opp_btn.pressed.connect(func():
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
	for ch in _inspector_cards_vbox.get_children():
		ch.queue_free()

	for p_idx in range(1, total_players + 1):
		if target_p > 0 and p_idx != target_p:
			continue
		var player_card_box = _build_player_inspector_section(p_idx)
		_inspector_cards_vbox.add_child(player_card_box)

func _build_player_inspector_section(p_idx: int) -> Control:
	var st: Dictionary = players_state.get(p_idx, {"continents": {}, "strategies_count": 0, "tokens": []})
	var p_name: String = _get_player_name(p_idx)
	var is_me: bool = (p_idx == my_player_index)
	var is_turn: bool = (_active_turn == p_idx)
	var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color(0.84, 0.68, 0.28))

	var section_panel = PanelContainer.new()
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

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	section_panel.add_child(vbox)

	# 1. Player Header Strip (Stats summary on left, Player Name & Turn badge on right)
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(header_hbox)

	var toks: Array = st.get("tokens", [])
	var conts: Dictionary = st.get("continents", {})
	var total_c: int = _sum_dict_values(conts)
	var total_s: int = my_strategies.size() if is_me else _to_int(st.get("strategies_count", 0))

	var stats_lbl = Label.new()
	stats_lbl.text = "👑 %s/۲ نشان سلطه   |   🗺️ %s کارت قاره   |   ⚡ %s کارت استراتژی" % [
		Risk3DFactory.fa_digits(toks.size()),
		Risk3DFactory.fa_digits(total_c),
		Risk3DFactory.fa_digits(total_s)
	]
	stats_lbl.add_theme_font_override("font", FontHekayat)
	stats_lbl.add_theme_font_size_override("font_size", 23)
	stats_lbl.add_theme_color_override("font_color", Color(0.95, 0.89, 0.74))
	header_hbox.add_child(stats_lbl)

	var name_lbl = Label.new()
	var turn_badge = " • 🟢 نوبت فعال" if is_turn else ""
	var me_badge = " (شما)" if is_me else ""
	name_lbl.text = "🛡️ %s%s%s" % [p_name, me_badge, turn_badge]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 27)
	name_lbl.add_theme_color_override("font_color", f_col.lightened(0.38))
	header_hbox.add_child(name_lbl)

	# 2. Domination Tokens Row (if player owns any conquered continent tokens)
	if not toks.is_empty():
		var tok_row = HBoxContainer.new()
		tok_row.alignment = BoxContainer.ALIGNMENT_END
		tok_row.add_theme_constant_override("separation", 8)
		vbox.add_child(tok_row)
		for t_id in toks:
			var c_str = str(t_id)
			var c_col: Color = RiskMaterials.CONTINENT_COLORS.get(c_str, Color(0.85, 0.68, 0.22))
			var tok_chip = PanelContainer.new()
			tok_chip.add_theme_stylebox_override(
				"panel",
				_make_panel_style(c_col.darkened(0.45), Color(0.98, 0.84, 0.28), 10, 2, 10, 4)
			)
			var tl = Label.new()
			tl.text = "👑 نشان سلطه %s" % _continent_fa(c_str)
			tl.add_theme_font_override("font", FontHekayat)
			tl.add_theme_font_size_override("font_size", 22)
			tl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
			tok_chip.add_child(tl)
			tok_row.add_child(tok_chip)

	# 3. Horizontally Scrollable Visual Card View Tray for this Player
	var cards_scroll = ScrollContainer.new()
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.custom_minimum_size = Vector2(0, 156)
	cards_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(cards_scroll)

	var cards_hbox = HBoxContainer.new()
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_hbox.alignment = BoxContainer.ALIGNMENT_END
	cards_hbox.add_theme_constant_override("separation", 10)
	cards_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	cards_scroll.add_child(cards_hbox)

	var has_any_card: bool = false

	# 3A. Public Face-Up Continent Cards (Visible as rich tabletop cards for EVERY player)
	var c_keys = conts.keys()
	c_keys.sort()
	for ck in c_keys:
		var c_id = str(ck)
		var cnt = _to_int(conts[ck])
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
		var card_ctrl = _build_inspector_card_widget(
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

	# 3B. Strategy Cards (Face-Up for Local Player; Ornate Mystery Strategy Card View for Opponents)
	if is_me:
		var strat_counts: Dictionary = {}
		for s_name in my_strategies:
			var sn = str(s_name)
			strat_counts[sn] = _to_int(strat_counts.get(sn, 0)) + 1
		var s_keys = strat_counts.keys()
		s_keys.sort()
		for sn in s_keys:
			has_any_card = true
			var sm: Dictionary = Risk3DFactory.STRATEGY_META.get(str(sn), {})
			var s_col: Color = sm.get("color", Color(0.76, 0.24, 0.24))
			var s_icon: String = str(sm.get("icon", "⚡"))
			var s_title: String = str(sm.get("fa", sn))
			var s_sub: String = str(sm.get("short", "کارت استراتژی"))
			var card_ctrl = _build_inspector_card_widget(
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
			# Show individual visual face-down Strategy Cards (up to 5 cards, or grouped if more)
			if total_s <= 5:
				for _i in range(total_s):
					var mystery_card = _build_inspector_card_widget(
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
				var mystery_stack = _build_inspector_card_widget(
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
		var empty_lbl = Label.new()
		empty_lbl.text = "هیچ کارتی در دست این بازیکن نیست"
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", FontHekayat)
		empty_lbl.add_theme_font_size_override("font_size", 24)
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
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(138, 146)
	card_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var card_bg = Color(0.17, 0.08, 0.10, 0.97) if is_mystery_back else Color(0.13, 0.095, 0.065, 0.97)
	var border_col = Color(0.86, 0.66, 0.28) if is_mystery_back else accent_col.lightened(0.22)
	card_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(card_bg, border_col, 14, 2, 8, 6)
	)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(vbox)

	# Colored Top Banner Strip with Icon & Count Badge
	var banner = PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 42)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_sb = StyleBoxFlat.new()
	banner_sb.bg_color = accent_col.darkened(0.10)
	banner_sb.set_corner_radius_all(8)
	banner_sb.content_margin_left = 8
	banner_sb.content_margin_right = 8
	banner_sb.content_margin_top = 2
	banner_sb.content_margin_bottom = 2
	banner.add_theme_stylebox_override("panel", banner_sb)
	vbox.add_child(banner)

	var banner_hbox = HBoxContainer.new()
	banner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_hbox)

	var badge_lbl = Label.new()
	badge_lbl.text = "❓×" + Risk3DFactory.fa_digits(count) if is_mystery_back else "×" + Risk3DFactory.fa_digits(count)
	badge_lbl.add_theme_font_override("font", FontHekayat)
	badge_lbl.add_theme_font_size_override("font_size", 34)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.45) if count > 1 else Color(1.0, 0.98, 0.92))
	badge_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.96))
	badge_lbl.add_theme_constant_override("outline_size", 6)
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(badge_lbl)

	var ic_lbl = Label.new()
	ic_lbl.text = icon_txt
	ic_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ic_lbl.add_theme_font_size_override("font_size", 24)
	ic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(ic_lbl)

	# Card Title
	var title_lbl = Label.new()
	title_lbl.text = title_txt
	title_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 27)
	title_lbl.add_theme_color_override("font_color", Color(0.99, 0.95, 0.84))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	# Card Subtitle
	var sub_lbl = Label.new()
	sub_lbl.text = sub_txt
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.add_theme_font_override("font", FontHekayat)
	sub_lbl.add_theme_font_size_override("font_size", 21)
	sub_lbl.add_theme_color_override("font_color", Color(0.94, 0.80, 0.48) if is_mystery_back else accent_col.lightened(0.42))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	# Allow tapping an opponent's continent card in the inspector to select it as a target when using Destroy/Attack
	if continent_id != "" and owner_p_idx != my_player_index:
		card_panel.gui_input.connect(func(ev: InputEvent):
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
	_is_zoomed_in = not _is_zoomed_in
	if is_instance_valid(_btn_zoom):
		_btn_zoom.text = "🔍 نمای کلی" if _is_zoomed_in else "🔍 زوم"
	var table = get_tree().root.find_child("CafeTable", true, false)
	if is_instance_valid(table):
		if _is_zoomed_in and table.has_method("zoom_in"):
			table.zoom_in(0.36)
		elif not _is_zoomed_in and table.has_method("reset_camera_orbit"):
			table.reset_camera_orbit()

func _get_active_inspected_continent() -> String:
	if selected_target_continent != "":
		return selected_target_continent
	if selected_source_continent != "":
		return selected_source_continent
	if _inspected_continent_id != "":
		return _inspected_continent_id
	if not active_attack.is_empty():
		return str(active_attack.get("target_continent", active_attack.get("source_continent", "")))
	return ""

func _refresh_selected_region_inspector() -> void:
	if not is_instance_valid(_region_inspector_panel):
		return
	var c_id: String = _get_active_inspected_continent()
	if c_id == "" or not Risk3DFactory.CONTINENT_META.has(c_id):
		_region_inspector_panel.visible = false
		return

	_region_inspector_panel.visible = true
	var c_fa: String = _continent_fa(c_id)
	var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
	var owner_p: int = _get_continent_owner_player(c_id)
	var owner_str: String = _get_player_name(owner_p) if owner_p > 0 else "بدون مالک"

	var tok_owner: int = 0
	for p_idx in range(1, total_players + 1):
		if (players_state.get(p_idx, {}).get("tokens", []) as Array).has(c_id):
			tok_owner = p_idx
			break
	var dom_str: String = ("👑 سلطه: %s" % _get_player_name(tok_owner)) if tok_owner > 0 else ("👑 حد نصاب: %s کارت" % Risk3DFactory.fa_digits(dom_req))

	var unit_parts: Array[String] = []
	for p_idx in range(1, total_players + 1):
		var cnt = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		if cnt > 0:
			unit_parts.append("%s ×%s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(cnt)])
	var units_str: String = " ، ".join(unit_parts) if not unit_parts.is_empty() else "خالی"

	var status_str: String = "بررسی منطقه"
	if c_id == selected_source_continent:
		status_str = "⚔️ مبدا حمله"
	elif c_id == selected_target_continent:
		status_str = "🎯 هدف حمله"
	elif _get_valid_attack_target_continents(selected_source_continent).has(c_id):
		status_str = "🟢 قابل حمله"

	if is_instance_valid(_region_inspector_title_lbl):
		_region_inspector_title_lbl.text = "🗺️ %s" % c_fa
		var c_col: Color = RiskMaterials.CONTINENT_COLORS.get(c_id, Color(0.98, 0.88, 0.46)).lightened(0.35)
		_region_inspector_title_lbl.add_theme_color_override("font_color", c_col)

	if is_instance_valid(_region_inspector_detail_lbl):
		_region_inspector_detail_lbl.text = "مالک: %s  |  ⚔️ نیروها: %s  |  %s  |  %s" % [
			owner_str,
			units_str,
			dom_str,
			status_str,
		]

func _inspect_continent_summary(c_id: String) -> void:
	_inspected_continent_id = c_id
	_refresh_selected_region_inspector()
	var c_fa = _continent_fa(c_id)
	var dom_req: int = int(Risk3DFactory.CONTINENT_META.get(c_id, {}).get("domination", 4))
	var has_tok = board_tokens.has(c_id)
	var parts: Array[String] = []
	for p_idx in range(1, total_players + 1):
		var cnt = _to_int(players_state.get(p_idx, {}).get("continents", {}).get(c_id, 0))
		if cnt > 0:
			parts.append("%s: ×%s/%s" % [_get_player_name(p_idx), Risk3DFactory.fa_digits(cnt), Risk3DFactory.fa_digits(dom_req)])
	var garrison_str = " | ".join(parts) if not parts.is_empty() else "بدون نیرو"
	var tok_str = "👑 حد نصاب سلطه: %s کارت (%s)" % [
		Risk3DFactory.fa_digits(dom_req),
		"موجود روی تخته" if has_tok else "تصاحب شده"
	]
	if is_instance_valid(_selection_info_lbl):
		_selection_info_lbl.text = "🗺️ «%s» — %s — نیروها: %s" % [c_fa, tok_str, garrison_str]

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
		l.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
		_log_vbox.add_child(l)

func _show_combat_toast(text: String, duration: float = 3.6) -> void:
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
		"Attack":
			return "ادامه نبرد"
	return "در حال بازی"

func _format_dice_list(arr: Array) -> String:
	if arr.is_empty():
		return "-"
	var die_icons = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
	var parts: Array[String] = []
	for v in arr:
		var iv = clampi(_to_int(v, 1), 1, 6)
		parts.append("%s%s" % [die_icons[iv - 1], Risk3DFactory.fa_digits(iv)])
	return "[" + " ، ".join(parts) + "]"

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
