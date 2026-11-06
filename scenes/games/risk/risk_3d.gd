class_name Risk3D
extends BaseGameBoard

# ==============================================================================
# RISK STRIKE 3D — ROYAL COMMAND TABLE, 3D SELECTABLE CARDS & GUIDED HUD
# ==============================================================================
# Fixes & Upgrades:
# 1. Zero UI overlap during Pre-Game Start Countdown or End-Game Result Dialog:
#    - UI root is parented inside BaseGameHUD below StartGameOverlay and remains
#      strictly hidden until the match countdown finishes (on_start_game / active turn).
# 2. True 3D Selectable Cards in Hand + 3D Selectable Draw Decks:
#    - Continent Cards in hand are rendered as 3D sculpted cards with stacked thickness,
#      miniature 3D citadel relief, gold count badges, and smooth 3D hover/select elevation.
#    - Strategy Cards in hand are rendered as 3D tactical cards with custom 3D emblems
#      (Bomb, Cannon, Crown, Shield, Spyglass, Swords, Banner) and readiness indicator gems.
#    - 3D Continent & Strategy Draw Decks on the table can also be tapped directly in 3D.
# 3. Always-Visible Enemy Cards Bar + Full Visual Enemy Cards Inspector Modal:
#    - Live opponent strip shows every opponent's visible Continent Cards, Crowns (👑),
#      and Strategy Card count (🃏) at a glance, plus a 1-tap "👁️ کارت‌های حریفان" modal.
# 4. Step-by-Step Guided Phase Banner & Compact Contextual Command Bar:
#    - Uncluttered 1-step-at-a-time controls that guide the player clearly in Persian.
# ==============================================================================

const ALL_CONTINENTS: Array[String] = [
	"NorthAmerica",
	"Europe",
	"Asia",
	"SouthAmerica",
	"Africa",
	"Australia"
]

const CONTINENT_NAMES_FA: Dictionary = {
	"Asia": "آسیا",
	"NorthAmerica": "آمریکای شمالی",
	"Europe": "اروپا",
	"Africa": "آفریقا",
	"Australia": "استرالیا",
	"SouthAmerica": "آمریکای جنوبی"
}

const CONTINENT_ADJACENCY: Dictionary = {
	"Asia": ["Australia", "Europe", "Africa", "NorthAmerica"],
	"Australia": ["Asia"],
	"Europe": ["Asia", "NorthAmerica", "Africa"],
	"Africa": ["Europe", "Asia", "SouthAmerica"],
	"SouthAmerica": ["NorthAmerica", "Africa"],
	"NorthAmerica": ["Europe", "Asia", "SouthAmerica"]
}

const CONTINENT_COLORS: Dictionary = {
	"Asia": Color(0.16, 0.72, 0.44),         # Jade Emerald
	"NorthAmerica": Color(0.92, 0.68, 0.20), # Imperial Amber Gold
	"Europe": Color(0.24, 0.56, 0.94),       # Royal Cobalt Blue
	"Africa": Color(0.90, 0.44, 0.20),       # Terracotta Sun
	"Australia": Color(0.72, 0.34, 0.88),    # Amethyst Violet
	"SouthAmerica": Color(0.52, 0.80, 0.24)  # Amazon Chartreuse
}

# Upper half of 3D table (-0.48 to +0.06 Z) so lower half (+0.38 to +0.72 Z) holds 3D Hand Cards
const CONTINENT_POSITIONS_3D: Dictionary = {
	"NorthAmerica": Vector3(-0.37, 0.052, -0.44),
	"Europe":       Vector3( 0.00, 0.052, -0.48),
	"Asia":         Vector3( 0.37, 0.052, -0.42),
	"SouthAmerica": Vector3(-0.35, 0.052,  0.04),
	"Africa":       Vector3( 0.00, 0.052,  0.02),
	"Australia":    Vector3( 0.36, 0.052,  0.05)
}

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.24, 0.28), # Player 1: Ruby Red
	2: Color(0.22, 0.64, 1.00), # Player 2: Sapphire Blue
	3: Color(0.20, 0.86, 0.42), # Player 3: Emerald Green
	4: Color(1.00, 0.80, 0.18)  # Player 4: Sunburst Gold
}

const FACTION_DOTS: Dictionary = {
	1: "🔴",
	2: "🔵",
	3: "🟢",
	4: "🟡"
}

const STRATEGY_INFO: Dictionary = {
	"Backup": {
		"name_fa": "پشتیبانی",
		"short_fa": "+۱ کارت قاره",
		"icon": "🛡️",
		"desc": "یک قاره که در دست دارید را انتخاب کنید و ۱ کارت دیگر از همان قاره دریافت کنید.",
		"phases": ["Draw", "Attack", "AttackArmy"]
	},
	"Expand": {
		"name_fa": "پیشروی",
		"short_fa": "کارت از دسته قاره",
		"icon": "🗺️",
		"desc": "بالاترین کارت دسته قاره‌ها را برمی‌دارید؛ اگر از آن قاره داشته باشید، ۲ کارت می‌گیرید!",
		"phases": ["Draw", "Attack"]
	},
	"Destroy": {
		"name_fa": "تخریب",
		"short_fa": "حذف قاره ضعیف",
		"icon": "⚡",
		"desc": "از هر بازیکن یک کارت قاره که فقط ۱ عدد از آن دارد حذف می‌شود.",
		"phases": ["Draw", "Attack"]
	},
	"Bomb": {
		"name_fa": "بمباران",
		"short_fa": "حذف ۱ کارت قاره حریف",
		"icon": "💣",
		"desc": "یک بازیکن حریف و یکی از قاره‌های او را انتخاب کنید تا ۱ کارت از آن قاره بسوزد.",
		"phases": ["Draw", "Attack"]
	},
	"Target": {
		"name_fa": "فتح تاج",
		"short_fa": "دریافت ۱ تاج طلایی",
		"icon": "👑",
		"desc": "اگر در این نوبت در یک حمله پیروز شده باشید، بلافاصله ۱ تاج سلطه دریافت می‌کنید!",
		"phases": ["Draw", "Attack"]
	},
	"Insurgence": {
		"name_fa": "کودتا",
		"short_fa": "ربودن تاج حریف",
		"icon": "🔥",
		"desc": "اگر تمام کارت‌های یک قاره حریف را در نبرد نابود کرده باشید، ۱ تاج از او می‌ربایید!",
		"phases": ["Draw", "Attack"]
	},
	"Spy": {
		"name_fa": "جاسوس",
		"short_fa": "دیدن و حذف استراتژی",
		"icon": "🕵️",
		"desc": "کارت‌های استراتژی یک حریف را ببینید و یکی از آن‌ها را نابود کنید.",
		"phases": ["Draw", "Attack"]
	},
	"Canon": {
		"name_fa": "توپخانه",
		"short_fa": "+۱ به تاس در نبرد",
		"icon": "💥",
		"desc": "در نبرد جاری، ۱ واحد به بالاترین تاس شما (در حمله یا دفاع) اضافه می‌کند.",
		"phases": ["DeclareAttack", "AttackArmy", "DefenderArmy", "QuestArmy"]
	},
	"Cancel": {
		"name_fa": "آتش‌بس",
		"short_fa": "لغو کامل حمله حریف",
		"icon": "🕊️",
		"desc": "وقتی حریف به شما حمله می‌کند، نبرد را فوراً لغو کرده و حمله را متوقف می‌سازد.",
		"phases": ["DefenderArmy", "QuestArmy"]
	},
	"Army": {
		"name_fa": "لشکرکشی",
		"short_fa": "تعویض قاره با دسته",
		"icon": "⚔️",
		"desc": "در نبرد، یکی از قاره‌های خود را به دسته برگردانید تا ۲ کارت قاره جدید بکشید.",
		"phases": ["DeclareAttack", "AttackArmy", "DefenderArmy", "QuestArmy"]
	}
}

# --- Match & Game State ---
var _font_hekayat: Font = preload("res://assets/fonts/hekayat.ttf")
var _crown_mesh: Mesh = null

var _match_started: bool = false
var _player_count: int = 2
var _active_turn: int = 1
var _game_phase: String = "Draw" # "Draw", "Attack", "AttackArmy", "DefenderArmy", "QuestArmy"

# Public state of all players (1-indexed in UI, stored 0-indexed in arrays)
var _tokens: Array = [0, 0, 0, 0]
var _all_continents: Array = [{}, {}, {}, {}]
var _strategy_counts: Array = [0, 0, 0, 0]
var _my_strategies: Dictionary = {}
var _revealed_enemy_strategies: Dictionary = {} # p_idx (1..4) -> Dictionary of revealed strategies

# Combat & Selection State
var _selected_my_continent: String = ""
var _selected_target_continent: String = ""
var _selected_target_defender: int = 0
var _selected_strategy_card: String = ""
var _first_3d_deck_picked: String = "" # "" or "continent" or "strategy" for 2-click 3D deck drawing
var _current_battle_attacker: int = 0
var _current_battle_defender: int = 0
var _current_battle_attacker_continent: String = ""
var _current_battle_target_continent: String = ""
var _current_battle_attacker_army: int = 1
var _won_attack_this_turn: bool = false
var _eliminated_continent_this_turn: bool = false

# --- 3D Scene Nodes ---
var _board_root: Node3D = null
var _continents_root: Node3D = null
var _bridges_root: Node3D = null
var _crowns_root: Node3D = null
var _decks_root: Node3D = null
var _dice_arena_root: Node3D = null
var _hand_3d_root: Node3D = null

var _continent_nodes: Dictionary = {} # continent -> Dictionary of 3D node refs
var _bridge_meshes: Dictionary = {}   # "ContA_ContB" -> MeshInstance3D
var _player_crown_nodes: Dictionary = {} # player_idx (1..4) -> Array[Node3D]
var _attacker_dice_nodes: Array[Node3D] = []
var _defender_dice_nodes: Array[Node3D] = []
var _dice_result_lbl_3d: Label3D = null
var _deck_continent_node: Node3D = null
var _deck_strategy_node: Node3D = null
var _deck_continent_hint_3d: Label3D = null
var _deck_strategy_hint_3d: Label3D = null

var _hand_continent_cards_3d: Dictionary = {} # continent -> Node3D
var _hand_strategy_cards_3d: Dictionary = {}  # strategy -> Node3D

var _pulse_time: float = 0.0
var _shared_mats: Dictionary = {}

# --- 2D Guided HUD Nodes (Parented inside BaseGameHUD below StartGameOverlay) ---
var _fallback_canvas: CanvasLayer = null
var _ui_root: Control = null

# Top Opponent Cards Strip & Phase Step Guide
var _opponent_strip_box: HBoxContainer = null
var _btn_enemy_inspector: Button = null
var _step_badge_lbl: Label = null
var _step_guide_lbl: Label = null
var _battle_feed_lbl: Label = null

# Bottom Compact Contextual Command Bar
var _bottom_panel: PanelContainer = null
var _action_title_lbl: Label = null
var _action_buttons_row: HBoxContainer = null

# Modals (Enemy Cards Inspector & Strategy Target Picker)
var _enemy_modal_backdrop: ColorRect = null
var _enemy_modal_panel: PanelContainer = null
var _enemy_modal_body: VBoxContainer = null

var _target_modal_backdrop: ColorRect = null
var _target_modal_panel: PanelContainer = null
var _target_modal_title: Label = null
var _target_modal_sub: Label = null
var _target_modal_body: VBoxContainer = null

# ==============================================================================
# LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	game_type = GameTypes.RISK
	if ResourceLoader.exists("res://assets/models/risk/crown.obj"):
		_crown_mesh = load("res://assets/models/risk/crown.obj")
	_init_shared_materials()
	_init_default_state()
	_build_3d_war_table()
	_build_2d_command_hud()
	# Connect Risk-specific network events
	if not NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.connect(_on_risk_event_received)
	super._ready()
	# Keep HUD hidden until the 5s pre-game start countdown finishes
	_update_hud_visibility()
	_refresh_all_visuals()

func cleanup_board() -> void:
	if NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
		NetworkManager.risk_event_received.disconnect(_on_risk_event_received)
	if is_instance_valid(_ui_root):
		_ui_root.queue_free()
		_ui_root = null
	if is_instance_valid(_fallback_canvas):
		_fallback_canvas.queue_free()
		_fallback_canvas = null

func _init_default_state() -> void:
	_player_count = clampi(GameManager.match_players.size(), 2, 4)
	_tokens = []
	_all_continents = []
	_strategy_counts = []
	for i in range(_player_count):
		_tokens.append(0)
		var c_dict: Dictionary = {}
		for c in ALL_CONTINENTS:
			c_dict[c] = 0
		_all_continents.append(c_dict)
		_strategy_counts.append(0)
	_my_strategies.clear()
	_revealed_enemy_strategies.clear()
	for s_key in STRATEGY_INFO.keys():
		_my_strategies[s_key] = 0

func _process(delta: float) -> void:
	_pulse_time += delta
	_update_hud_visibility()

	# Rotate golden domination crowns smoothly
	for p_idx in _player_crown_nodes.keys():
		var arr: Array = _player_crown_nodes[p_idx]
		for c_i in range(arr.size()):
			var c_node: Node3D = arr[c_i]
			if is_instance_valid(c_node) and c_node.visible:
				c_node.rotation.y += delta * 1.35
				c_node.position.y = 0.095 + sin(_pulse_time * 2.6 + float(p_idx + c_i)) * 0.008

	# Pulse active continent selection & valid attack targets on the 3D map
	for cont in _continent_nodes.keys():
		var info: Dictionary = _continent_nodes[cont]
		var ring: MeshInstance3D = info.get("select_ring", null)
		var target_badge: Label3D = info.get("target_badge", null)
		if is_instance_valid(ring) and ring.visible:
			var sc = 1.0 + sin(_pulse_time * 5.2) * 0.075
			ring.scale = Vector3(sc, 1.0, sc)
		if is_instance_valid(target_badge) and target_badge.visible:
			target_badge.position.y = 0.25 + sin(_pulse_time * 5.5) * 0.018

	# Bounce 3D draw decks when it is our turn to draw
	var is_my_draw: bool = (_match_started and _active_turn == my_player_index and _game_phase == "Draw")
	if is_instance_valid(_deck_continent_node):
		var target_y = 0.055 + (abs(sin(_pulse_time * 4.2)) * 0.022 if is_my_draw else 0.0)
		_deck_continent_node.position.y = lerpf(_deck_continent_node.position.y, target_y, delta * 10.0)
	if is_instance_valid(_deck_strategy_node):
		var target_y2 = 0.055 + (abs(cos(_pulse_time * 4.2)) * 0.022 if is_my_draw else 0.0)
		_deck_strategy_node.position.y = lerpf(_deck_strategy_node.position.y, target_y2, delta * 10.0)

# Ensures the Risk controller UI is NEVER shown during StartGameOverlay or GameResultDialog
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
	if not is_instance_valid(_ui_root):
		return
	# Re-parent into BaseGameHUD below StartGameOverlay if needed
	if is_instance_valid(_fallback_canvas) and _ui_root.get_parent() == _fallback_canvas:
		var hud = get_tree().root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud):
			_ui_root.reparent(hud)
			var start_ov = hud.get_node_or_null("StartGameOverlay")
			if is_instance_valid(start_ov):
				hud.move_child(_ui_root, start_ov.get_index())
	var should_show = not _is_hud_overlay_blocking()
	if _ui_root.visible != should_show:
		_ui_root.visible = should_show
	if is_instance_valid(_hand_3d_root):
		_hand_3d_root.visible = should_show

# ==============================================================================
# 3D MATERIALS & PROCEDURAL GEOMETRY
# ==============================================================================

func _init_shared_materials() -> void:
	var mat_walnut = StandardMaterial3D.new()
	mat_walnut.albedo_color = Color(0.18, 0.10, 0.05)
	mat_walnut.roughness = 0.40
	mat_walnut.metallic = 0.08
	_shared_mats["walnut"] = mat_walnut

	var mat_brass = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.92, 0.76, 0.30)
	mat_brass.metallic = 0.86
	mat_brass.roughness = 0.22
	_shared_mats["brass"] = mat_brass

	var mat_ocean = StandardMaterial3D.new()
	mat_ocean.albedo_color = Color(0.06, 0.15, 0.25)
	mat_ocean.roughness = 0.26
	mat_ocean.metallic = 0.18
	_shared_mats["ocean"] = mat_ocean

	var mat_parchment = StandardMaterial3D.new()
	mat_parchment.albedo_color = Color(0.95, 0.90, 0.78)
	mat_parchment.roughness = 0.65
	_shared_mats["parchment"] = mat_parchment

	var mat_obsidian = StandardMaterial3D.new()
	mat_obsidian.albedo_color = Color(0.12, 0.09, 0.14)
	mat_obsidian.roughness = 0.32
	mat_obsidian.metallic = 0.25
	_shared_mats["obsidian"] = mat_obsidian

	var mat_crown_gold = StandardMaterial3D.new()
	mat_crown_gold.albedo_color = Color(1.0, 0.85, 0.22)
	mat_crown_gold.metallic = 0.92
	mat_crown_gold.roughness = 0.16
	mat_crown_gold.emission_enabled = true
	mat_crown_gold.emission = Color(0.95, 0.72, 0.12)
	mat_crown_gold.emission_energy_multiplier = 0.45
	_shared_mats["crown_gold"] = mat_crown_gold

	var mat_bridge_idle = StandardMaterial3D.new()
	mat_bridge_idle.albedo_color = Color(0.82, 0.70, 0.36, 0.45)
	mat_bridge_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_bridge_idle.emission_enabled = true
	mat_bridge_idle.emission = Color(0.75, 0.60, 0.25)
	mat_bridge_idle.emission_energy_multiplier = 0.35
	_shared_mats["bridge_idle"] = mat_bridge_idle

	var mat_bridge_active = StandardMaterial3D.new()
	mat_bridge_active.albedo_color = Color(1.0, 0.38, 0.22, 0.95)
	mat_bridge_active.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_bridge_active.emission_enabled = true
	mat_bridge_active.emission = Color(1.0, 0.42, 0.15)
	mat_bridge_active.emission_energy_multiplier = 2.2
	_shared_mats["bridge_active"] = mat_bridge_active

	var mat_die_red = StandardMaterial3D.new()
	mat_die_red.albedo_color = Color(0.88, 0.14, 0.18)
	mat_die_red.roughness = 0.20
	mat_die_red.metallic = 0.15
	_shared_mats["die_red"] = mat_die_red

	var mat_die_black = StandardMaterial3D.new()
	mat_die_black.albedo_color = Color(0.14, 0.16, 0.22)
	mat_die_black.roughness = 0.22
	mat_die_black.metallic = 0.28
	_shared_mats["die_black"] = mat_die_black

	var mat_pip_white = StandardMaterial3D.new()
	mat_pip_white.albedo_color = Color(0.98, 0.96, 0.90)
	mat_pip_white.emission_enabled = true
	mat_pip_white.emission = Color(0.95, 0.92, 0.82)
	mat_pip_white.emission_energy_multiplier = 0.35
	_shared_mats["pip_white"] = mat_pip_white

func _build_3d_war_table() -> void:
	if is_instance_valid(_board_root):
		_board_root.queue_free()
	_board_root = Node3D.new()
	_board_root.name = "RiskWarTableRoot"
	add_child(_board_root)

	# 1. Outer Royal Walnut War-Table Frame (Covers both Map and 3D Card Rack)
	var base_box = BoxMesh.new()
	base_box.size = Vector3(1.26, 0.044, 1.56)
	base_box.material = _shared_mats["walnut"]
	var base_mi = MeshInstance3D.new()
	base_mi.mesh = base_box
	base_mi.position = Vector3(0.0, 0.022, 0.06)
	_board_root.add_child(base_mi)

	# 2. Inner Deep Naval Map Table Surface (Upper Section)
	var ocean_box = BoxMesh.new()
	ocean_box.size = Vector3(1.16, 0.010, 0.90)
	ocean_box.material = _shared_mats["ocean"]
	var ocean_mi = MeshInstance3D.new()
	ocean_mi.mesh = ocean_box
	ocean_mi.position = Vector3(0.0, 0.046, -0.20)
	_board_root.add_child(ocean_mi)

	# Divider Brass Rail between Map and Commander's 3D Card Tray
	var divider_box = BoxMesh.new()
	divider_box.size = Vector3(1.18, 0.024, 0.022)
	divider_box.material = _shared_mats["brass"]
	var divider_mi = MeshInstance3D.new()
	divider_mi.mesh = divider_box
	divider_mi.position = Vector3(0.0, 0.052, 0.25)
	_board_root.add_child(divider_mi)

	# 3. Commander's Velvet 3D Card Rack Surface (Lower Section: Z = +0.26 to +0.82)
	var tray_mat = StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.11, 0.07, 0.05)
	tray_mat.roughness = 0.75
	var tray_box = BoxMesh.new()
	tray_box.size = Vector3(1.16, 0.010, 0.54)
	tray_box.material = tray_mat
	var tray_mi = MeshInstance3D.new()
	tray_mi.mesh = tray_box
	tray_mi.position = Vector3(0.0, 0.046, 0.53)
	_board_root.add_child(tray_mi)

	# 3D Labels on the Card Rack so the player knows which row is Continent Cards vs Strategy Cards
	var lbl_cont_row = Label3D.new()
	lbl_cont_row.font = _font_hekayat
	lbl_cont_row.font_size = 24
	lbl_cont_row.pixel_size = 0.0011
	lbl_cont_row.text = "🗺️ کارت‌های قاره شما (برای حمله یا انتخاب روی کارت بزنید)"
	lbl_cont_row.modulate = Color(1.0, 0.90, 0.55)
	lbl_cont_row.outline_size = 6
	lbl_cont_row.position = Vector3(0.0, 0.056, 0.29)
	lbl_cont_row.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
	_board_root.add_child(lbl_cont_row)

	var lbl_strat_row = Label3D.new()
	lbl_strat_row.font = _font_hekayat
	lbl_strat_row.font_size = 24
	lbl_strat_row.pixel_size = 0.0011
	lbl_strat_row.text = "🃏 کارت‌های استراتژی شما (برای مشاهده و اجرا روی کارت بزنید)"
	lbl_strat_row.modulate = Color(0.95, 0.78, 0.98)
	lbl_strat_row.outline_size = 6
	lbl_strat_row.position = Vector3(0.0, 0.056, 0.56)
	lbl_strat_row.rotation_degrees = Vector3(-65.0, 0.0, 0.0)
	_board_root.add_child(lbl_strat_row)

	# 4. Sea-Lane Adjacency Bridges
	_bridges_root = Node3D.new()
	_bridges_root.name = "SeaLaneBridges"
	_board_root.add_child(_bridges_root)
	_build_sea_lane_bridges()

	# 5. Six 3D Continent Citadels
	_continents_root = Node3D.new()
	_continents_root.name = "ContinentsRoot"
	_board_root.add_child(_continents_root)
	_build_3d_continents()

	# 6. Center Battle Dice Arena & Selectable 3D Draw Decks
	_decks_root = Node3D.new()
	_decks_root.name = "CardDecksRoot"
	_board_root.add_child(_decks_root)
	_build_3d_card_decks()

	_dice_arena_root = Node3D.new()
	_dice_arena_root.name = "DiceArenaRoot"
	_board_root.add_child(_dice_arena_root)
	_build_3d_dice_arena()

	# 7. Rotating 3D Golden Domination Crowns
	_crowns_root = Node3D.new()
	_crowns_root.name = "DominationCrownsRoot"
	_board_root.add_child(_crowns_root)
	_build_3d_domination_crowns()

	# 8. Player's Interactive 3D Hand Cards Root
	_hand_3d_root = Node3D.new()
	_hand_3d_root.name = "Hand3DCardsRoot"
	_board_root.add_child(_hand_3d_root)

func _build_sea_lane_bridges() -> void:
	_bridge_meshes.clear()
	var pairs = [
		["NorthAmerica", "Europe"],
		["NorthAmerica", "Asia"],
		["NorthAmerica", "SouthAmerica"],
		["Europe", "Asia"],
		["Europe", "Africa"],
		["Asia", "Africa"],
		["Asia", "Australia"],
		["SouthAmerica", "Africa"]
	]
	for pair in pairs:
		var c1: String = pair[0]
		var c2: String = pair[1]
		var p1: Vector3 = CONTINENT_POSITIONS_3D[c1]
		var p2: Vector3 = CONTINENT_POSITIONS_3D[c2]
		var mid = (p1 + p2) * 0.5
		mid.y = 0.052
		var dist = p1.distance_to(p2)
		var angle = atan2(p2.x - p1.x, p2.z - p1.z)

		var bm = BoxMesh.new()
		bm.size = Vector3(0.018, 0.005, maxf(0.05, dist - 0.18))
		bm.material = _shared_mats["bridge_idle"]
		var mi = MeshInstance3D.new()
		mi.mesh = bm
		mi.position = mid
		mi.rotation = Vector3(0.0, angle, 0.0)
		_bridges_root.add_child(mi)
		_bridge_meshes[c1 + "_" + c2] = mi
		_bridge_meshes[c2 + "_" + c1] = mi

func _build_3d_continents() -> void:
	_continent_nodes.clear()
	for cont in ALL_CONTINENTS:
		var pos: Vector3 = CONTINENT_POSITIONS_3D[cont]
		var col: Color = CONTINENT_COLORS[cont]

		var root = Node3D.new()
		root.name = "Continent_" + cont
		root.position = pos
		_continents_root.add_child(root)

		# Hexagonal Pedestal Island
		var mat_ped = StandardMaterial3D.new()
		mat_ped.albedo_color = col.darkened(0.22)
		mat_ped.roughness = 0.36
		mat_ped.metallic = 0.18

		var ped_cyl = CylinderMesh.new()
		ped_cyl.top_radius = 0.125
		ped_cyl.bottom_radius = 0.142
		ped_cyl.height = 0.032
		ped_cyl.radial_segments = 6
		ped_cyl.material = mat_ped
		var ped_mi = MeshInstance3D.new()
		ped_mi.mesh = ped_cyl
		ped_mi.position = Vector3(0.0, 0.016, 0.0)
		root.add_child(ped_mi)

		# Top Cap Plate
		var mat_cap = StandardMaterial3D.new()
		mat_cap.albedo_color = col
		mat_cap.roughness = 0.28
		mat_cap.metallic = 0.12
		var cap_cyl = CylinderMesh.new()
		cap_cyl.top_radius = 0.112
		cap_cyl.bottom_radius = 0.118
		cap_cyl.height = 0.010
		cap_cyl.radial_segments = 6
		cap_cyl.material = mat_cap
		var cap_mi = MeshInstance3D.new()
		cap_mi.mesh = cap_cyl
		cap_mi.position = Vector3(0.0, 0.035, 0.0)
		root.add_child(cap_mi)

		# Central 3D Citadel Keep + 4 Corner Turrets
		var keep_node = Node3D.new()
		keep_node.position = Vector3(0.0, 0.040, 0.0)
		root.add_child(keep_node)

		var keep_box = BoxMesh.new()
		keep_box.size = Vector3(0.056, 0.042, 0.056)
		keep_box.material = _shared_mats["parchment"]
		var keep_mi = MeshInstance3D.new()
		keep_mi.mesh = keep_box
		keep_mi.position = Vector3(0.0, 0.021, 0.0)
		keep_node.add_child(keep_mi)

		for tx in [-0.026, 0.026]:
			for tz in [-0.026, 0.026]:
				var t_cyl = CylinderMesh.new()
				t_cyl.top_radius = 0.010
				t_cyl.bottom_radius = 0.012
				t_cyl.height = 0.054
				t_cyl.radial_segments = 10
				t_cyl.material = _shared_mats["brass"]
				var t_mi = MeshInstance3D.new()
				t_mi.mesh = t_cyl
				t_mi.position = Vector3(tx, 0.027, tz)
				keep_node.add_child(t_mi)

		# Glowing Selection & Target Ring
		var mat_ring = StandardMaterial3D.new()
		mat_ring.albedo_color = Color(1.0, 0.88, 0.28, 0.92)
		mat_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_ring.emission_enabled = true
		mat_ring.emission = Color(1.0, 0.82, 0.20)
		mat_ring.emission_energy_multiplier = 2.4
		var torus = TorusMesh.new()
		torus.inner_radius = 0.132
		torus.outer_radius = 0.150
		torus.material = mat_ring
		var ring_mi = MeshInstance3D.new()
		ring_mi.mesh = torus
		ring_mi.position = Vector3(0.0, 0.015, 0.0)
		ring_mi.visible = false
		root.add_child(ring_mi)

		# 3D Continent Persian Name Label
		var lbl_name = Label3D.new()
		lbl_name.font = _font_hekayat
		lbl_name.font_size = 34
		lbl_name.pixel_size = 0.0012
		lbl_name.text = CONTINENT_NAMES_FA.get(cont, cont)
		lbl_name.modulate = Color(1.0, 0.96, 0.84)
		lbl_name.outline_size = 8
		lbl_name.outline_modulate = Color(0.05, 0.03, 0.02, 0.96)
		lbl_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl_name.position = Vector3(0.0, 0.18, 0.0)
		root.add_child(lbl_name)

		# 3D Troop Breakdown Label (Shows both My Troops & Enemy Troops on this continent!)
		var lbl_counts = Label3D.new()
		lbl_counts.font = _font_hekayat
		lbl_counts.font_size = 26
		lbl_counts.pixel_size = 0.0011
		lbl_counts.text = ""
		lbl_counts.modulate = Color(1.0, 0.92, 0.55)
		lbl_counts.outline_size = 7
		lbl_counts.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
		lbl_counts.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl_counts.position = Vector3(0.0, 0.125, 0.0)
		root.add_child(lbl_counts)

		# Floating Target Reticle Badge ("🎯 حمله به این قاره")
		var lbl_target = Label3D.new()
		lbl_target.font = _font_hekayat
		lbl_target.font_size = 28
		lbl_target.pixel_size = 0.0012
		lbl_target.text = "🎯 هدف قابل حمله (بزنید)"
		lbl_target.modulate = Color(1.0, 0.38, 0.32)
		lbl_target.outline_size = 8
		lbl_target.outline_modulate = Color(0.0, 0.0, 0.0, 0.98)
		lbl_target.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl_target.position = Vector3(0.0, 0.25, 0.0)
		lbl_target.visible = false
		root.add_child(lbl_target)

		# Container for 3D Faction Troop Miniatures
		var troops_holder = Node3D.new()
		troops_holder.name = "TroopsHolder"
		troops_holder.position = Vector3(0.0, 0.042, 0.0)
		root.add_child(troops_holder)

		# StaticBody3D for direct 3D tap/raycast
		var sb = StaticBody3D.new()
		sb.name = "HitBox_" + cont
		sb.set_meta("continent", cont)
		var cs = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		cyl_shape.radius = 0.155
		cyl_shape.height = 0.16
		cs.shape = cyl_shape
		cs.position = Vector3(0.0, 0.06, 0.0)
		sb.add_child(cs)
		root.add_child(sb)

		_continent_nodes[cont] = {
			"root": root,
			"select_ring": ring_mi,
			"ring_mat": mat_ring,
			"lbl_name": lbl_name,
			"lbl_counts": lbl_counts,
			"target_badge": lbl_target,
			"troops_holder": troops_holder
		}

func _build_3d_card_decks() -> void:
	# Left Deck: Selectable 3D Continent Deck
	_deck_continent_node = _create_3d_deck_stack(
		Vector3(-0.46, 0.055, -0.18),
		Color(0.16, 0.56, 0.38),
		"🗺️ دسته قاره",
		"deck_continent"
	)
	_decks_root.add_child(_deck_continent_node)
	_deck_continent_hint_3d = _deck_continent_node.get_node_or_null("DeckHint") as Label3D

	# Right Deck: Selectable 3D Strategy Deck
	_deck_strategy_node = _create_3d_deck_stack(
		Vector3(0.46, 0.055, -0.18),
		Color(0.68, 0.18, 0.26),
		"🃏 دسته استراتژی",
		"deck_strategy"
	)
	_decks_root.add_child(_deck_strategy_node)
	_deck_strategy_hint_3d = _deck_strategy_node.get_node_or_null("DeckHint") as Label3D

func _create_3d_deck_stack(pos: Vector3, deck_color: Color, label_fa: String, meta_type: String) -> Node3D:
	var root = Node3D.new()
	root.position = pos

	var mat_top = StandardMaterial3D.new()
	mat_top.albedo_color = deck_color
	mat_top.roughness = 0.30
	mat_top.metallic = 0.22

	for i in range(5):
		var card_box = BoxMesh.new()
		card_box.size = Vector3(0.14, 0.007, 0.19)
		card_box.material = mat_top if i == 4 else _shared_mats["parchment"]
		var mi = MeshInstance3D.new()
		mi.mesh = card_box
		mi.position = Vector3(0.0, float(i) * 0.0075, 0.0)
		root.add_child(mi)

	var trim_box = BoxMesh.new()
	trim_box.size = Vector3(0.148, 0.004, 0.198)
	trim_box.material = _shared_mats["brass"]
	var trim_mi = MeshInstance3D.new()
	trim_mi.mesh = trim_box
	trim_mi.position = Vector3(0.0, 0.034, 0.0)
	root.add_child(trim_mi)

	var lbl = Label3D.new()
	lbl.font = _font_hekayat
	lbl.font_size = 24
	lbl.pixel_size = 0.0011
	lbl.text = label_fa
	lbl.modulate = Color(1.0, 0.92, 0.65)
	lbl.outline_size = 6
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 0.095, 0.0)
	root.add_child(lbl)

	var hint_lbl = Label3D.new()
	hint_lbl.name = "DeckHint"
	hint_lbl.font = _font_hekayat
	hint_lbl.font_size = 22
	hint_lbl.pixel_size = 0.0011
	hint_lbl.text = "👇 برای کشیدن کارت بزنید"
	hint_lbl.modulate = Color(0.45, 1.0, 0.58)
	hint_lbl.outline_size = 6
	hint_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_lbl.position = Vector3(0.0, 0.14, 0.0)
	hint_lbl.visible = false
	root.add_child(hint_lbl)

	# StaticBody3D so the player can tap the 3D deck directly!
	var sb = StaticBody3D.new()
	sb.set_meta("deck_type", meta_type)
	var cs = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.17, 0.10, 0.22)
	cs.shape = box_shape
	cs.position = Vector3(0.0, 0.04, 0.0)
	sb.add_child(cs)
	root.add_child(sb)

	return root

func _build_3d_dice_arena() -> void:
	_attacker_dice_nodes.clear()
	_defender_dice_nodes.clear()

	var tray = CylinderMesh.new()
	tray.top_radius = 0.155
	tray.bottom_radius = 0.165
	tray.height = 0.014
	tray.radial_segments = 24
	tray.material = _shared_mats["brass"]
	var tray_mi = MeshInstance3D.new()
	tray_mi.mesh = tray
	tray_mi.position = Vector3(0.0, 0.052, -0.18)
	_dice_arena_root.add_child(tray_mi)

	var inner = CylinderMesh.new()
	inner.top_radius = 0.140
	inner.bottom_radius = 0.140
	inner.height = 0.016
	inner.radial_segments = 24
	var mat_crimson = StandardMaterial3D.new()
	mat_crimson.albedo_color = Color(0.28, 0.06, 0.08)
	mat_crimson.roughness = 0.72
	inner.material = mat_crimson
	var inner_mi = MeshInstance3D.new()
	inner_mi.mesh = inner
	inner_mi.position = Vector3(0.0, 0.054, -0.18)
	_dice_arena_root.add_child(inner_mi)

	# 3 Red Attacker Dice & 2 Black Defender Dice
	for i in range(3):
		var die_node = _create_3d_battle_die(_shared_mats["die_red"])
		die_node.position = Vector3(-0.075 + float(i) * 0.075, 0.088, -0.215)
		die_node.visible = false
		_dice_arena_root.add_child(die_node)
		_attacker_dice_nodes.append(die_node)

	for i in range(2):
		var die_node = _create_3d_battle_die(_shared_mats["die_black"])
		die_node.position = Vector3(-0.042 + float(i) * 0.084, 0.088, -0.145)
		die_node.visible = false
		_dice_arena_root.add_child(die_node)
		_defender_dice_nodes.append(die_node)

	# Floating 3D Dice Battle Summary Label
	_dice_result_lbl_3d = Label3D.new()
	_dice_result_lbl_3d.font = _font_hekayat
	_dice_result_lbl_3d.font_size = 28
	_dice_result_lbl_3d.pixel_size = 0.0012
	_dice_result_lbl_3d.text = ""
	_dice_result_lbl_3d.modulate = Color(1.0, 0.94, 0.55)
	_dice_result_lbl_3d.outline_size = 8
	_dice_result_lbl_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dice_result_lbl_3d.position = Vector3(0.0, 0.18, -0.18)
	_dice_result_lbl_3d.visible = false
	_dice_arena_root.add_child(_dice_result_lbl_3d)

func _create_3d_battle_die(mat_body: Material) -> Node3D:
	var root = Node3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.048, 0.048, 0.048)
	bm.material = mat_body
	var mi = MeshInstance3D.new()
	mi.mesh = bm
	root.add_child(mi)

	# Floating number label above each die so its rolled value is 100% legible
	var val_lbl = Label3D.new()
	val_lbl.name = "DieValueLabel"
	val_lbl.font = _font_hekayat
	val_lbl.font_size = 32
	val_lbl.pixel_size = 0.0012
	val_lbl.text = "۶"
	val_lbl.modulate = Color(1.0, 0.96, 0.80)
	val_lbl.outline_size = 7
	val_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	val_lbl.position = Vector3(0.0, 0.048, 0.0)
	root.add_child(val_lbl)
	return root

func _build_3d_domination_crowns() -> void:
	_player_crown_nodes.clear()
	var crown_anchors: Dictionary = {
		1: [Vector3(-0.54, 0.095,  0.18), Vector3(-0.45, 0.095,  0.18)],
		2: [Vector3( 0.45, 0.095, -0.58), Vector3( 0.54, 0.095, -0.58)],
		3: [Vector3(-0.54, 0.095, -0.58), Vector3(-0.45, 0.095, -0.58)],
		4: [Vector3( 0.45, 0.095,  0.18), Vector3( 0.54, 0.095,  0.18)]
	}
	for p_idx in [1, 2, 3, 4]:
		var arr: Array[Node3D] = []
		var positions: Array = crown_anchors[p_idx]
		for slot_i in range(2):
			var c_holder = Node3D.new()
			c_holder.position = positions[slot_i]
			c_holder.visible = false
			if _crown_mesh:
				var mi = MeshInstance3D.new()
				mi.mesh = _crown_mesh
				mi.material_override = _shared_mats["crown_gold"]
				mi.scale = Vector3(0.60, 0.60, 0.60)
				c_holder.add_child(mi)
			_crowns_root.add_child(c_holder)
			arr.append(c_holder)
		_player_crown_nodes[p_idx] = arr

# ==============================================================================
# 3D SELECTABLE HAND CARDS (CONTINENT CARDS & STRATEGY CARDS)
# ==============================================================================

func _rebuild_3d_hand_cards() -> void:
	if not is_instance_valid(_hand_3d_root):
		return
	for child in _hand_3d_root.get_children():
		child.queue_free()
	_hand_continent_cards_3d.clear()
	_hand_strategy_cards_3d.clear()

	var my_idx_0 = clampi(my_player_index - 1, 0, _all_continents.size() - 1)
	var my_conts: Dictionary = _all_continents[my_idx_0] if my_idx_0 < _all_continents.size() else {}

	# 1. Build 3D Continent Cards in Row 1 (Z = +0.42)
	var owned_continents: Array[String] = []
	for cont in ALL_CONTINENTS:
		if int(my_conts.get(cont, 0)) > 0:
			owned_continents.append(cont)

	var c_total = owned_continents.size()
	var c_spacing = minf(0.185, 1.02 / maxf(1.0, float(c_total)))
	var c_start_x = -float(c_total - 1) * c_spacing * 0.5

	for i in range(c_total):
		var cont: String = owned_continents[i]
		var cnt: int = int(my_conts.get(cont, 0))
		var is_sel: bool = (_selected_my_continent == cont)
		var card_x = c_start_x + float(i) * c_spacing
		var card_node = _create_3d_continent_card(cont, cnt, is_sel)
		card_node.position = Vector3(card_x, 0.135 if is_sel else 0.082, 0.39 if is_sel else 0.42)
		card_node.rotation_degrees = Vector3(-42.0 if is_sel else -52.0, 0.0, 0.0)
		if is_sel:
			card_node.scale = Vector3(1.14, 1.14, 1.14)
		_hand_3d_root.add_child(card_node)
		_hand_continent_cards_3d[cont] = card_node

	# 2. Build 3D Strategy Cards in Row 2 (Z = +0.69)
	var owned_strategies: Array[String] = []
	for s_key in STRATEGY_INFO.keys():
		if int(_my_strategies.get(s_key, 0)) > 0:
			owned_strategies.append(s_key)

	var s_total = owned_strategies.size()
	var s_spacing = minf(0.175, 1.04 / maxf(1.0, float(s_total)))
	var s_start_x = -float(s_total - 1) * s_spacing * 0.5

	for i in range(s_total):
		var s_key: String = owned_strategies[i]
		var s_cnt: int = int(_my_strategies.get(s_key, 0))
		var is_sel: bool = (_selected_strategy_card == s_key)
		var is_playable: bool = _can_play_strategy_now(s_key)
		var card_x = s_start_x + float(i) * s_spacing
		var s_node = _create_3d_strategy_card(s_key, s_cnt, is_sel, is_playable)
		s_node.position = Vector3(card_x, 0.145 if is_sel else 0.086, 0.65 if is_sel else 0.69)
		s_node.rotation_degrees = Vector3(-40.0 if is_sel else -50.0, 0.0, 0.0)
		if is_sel:
			s_node.scale = Vector3(1.16, 1.16, 1.16)
		_hand_3d_root.add_child(s_node)
		_hand_strategy_cards_3d[s_key] = s_node

func _create_3d_continent_card(cont: String, count: int, is_selected: bool) -> Node3D:
	var root = Node3D.new()
	root.name = "Card3D_" + cont
	var col: Color = CONTINENT_COLORS.get(cont, Color(0.3, 0.6, 0.9))

	# Stacked card thickness underneath if player owns multiple cards of this continent
	var stack_layers = clampi(count, 1, 4)
	for l_i in range(stack_layers - 1):
		var under_box = BoxMesh.new()
		under_box.size = Vector3(0.156, 0.006, 0.210)
		under_box.material = _shared_mats["parchment"]
		var under_mi = MeshInstance3D.new()
		under_mi.mesh = under_box
		under_mi.position = Vector3(0.0, -float(l_i + 1) * 0.007, 0.0)
		root.add_child(under_mi)

	# Outer Gilded Frame (Glows bright gold when selected)
	var mat_frame = StandardMaterial3D.new()
	if is_selected:
		mat_frame.albedo_color = Color(1.0, 0.92, 0.35)
		mat_frame.emission_enabled = true
		mat_frame.emission = Color(1.0, 0.82, 0.20)
		mat_frame.emission_energy_multiplier = 1.8
	else:
		mat_frame.albedo_color = Color(0.85, 0.68, 0.28)
	mat_frame.metallic = 0.80
	mat_frame.roughness = 0.24

	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(0.162, 0.010, 0.216)
	frame_box.material = mat_frame
	var frame_mi = MeshInstance3D.new()
	frame_mi.mesh = frame_box
	root.add_child(frame_mi)

	# Inner Colored Continent Face
	var mat_face = StandardMaterial3D.new()
	mat_face.albedo_color = col.darkened(0.18)
	mat_face.roughness = 0.35
	var face_box = BoxMesh.new()
	face_box.size = Vector3(0.146, 0.012, 0.198)
	face_box.material = mat_face
	var face_mi = MeshInstance3D.new()
	face_mi.mesh = face_box
	face_mi.position = Vector3(0.0, 0.002, 0.0)
	root.add_child(face_mi)

	# 3D Sculpted Miniature Citadel Emblem on the Card Center
	var mini_keep = CylinderMesh.new()
	mini_keep.top_radius = 0.022
	mini_keep.bottom_radius = 0.026
	mini_keep.height = 0.018
	mini_keep.radial_segments = 6
	mini_keep.material = _shared_mats["parchment"]
	var keep_mi = MeshInstance3D.new()
	keep_mi.mesh = mini_keep
	keep_mi.position = Vector3(0.0, 0.014, -0.015)
	root.add_child(keep_mi)

	# 3D Gold Count Medallion on Top-Right of Card
	var badge_cyl = CylinderMesh.new()
	badge_cyl.top_radius = 0.024
	badge_cyl.bottom_radius = 0.024
	badge_cyl.height = 0.014
	badge_cyl.radial_segments = 16
	badge_cyl.material = _shared_mats["crown_gold"]
	var badge_mi = MeshInstance3D.new()
	badge_mi.mesh = badge_cyl
	badge_mi.position = Vector3(0.052, 0.012, -0.072)
	root.add_child(badge_mi)

	var lbl_cnt = Label3D.new()
	lbl_cnt.font = _font_hekayat
	lbl_cnt.font_size = 28
	lbl_cnt.pixel_size = 0.0011
	lbl_cnt.text = "×%s" % _fa_digits(count)
	lbl_cnt.modulate = Color(0.10, 0.06, 0.02)
	lbl_cnt.outline_size = 3
	lbl_cnt.outline_modulate = Color(1.0, 0.95, 0.75)
	lbl_cnt.position = Vector3(0.052, 0.022, -0.072)
	lbl_cnt.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl_cnt)

	# Continent Persian Title on Card Face
	var lbl_title = Label3D.new()
	lbl_title.font = _font_hekayat
	lbl_title.font_size = 26
	lbl_title.pixel_size = 0.0011
	lbl_title.text = CONTINENT_NAMES_FA.get(cont, cont)
	lbl_title.modulate = Color(1.0, 0.98, 0.90)
	lbl_title.outline_size = 7
	lbl_title.outline_modulate = Color(0.04, 0.02, 0.01, 0.96)
	lbl_title.position = Vector3(0.0, 0.016, 0.042)
	lbl_title.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl_title)

	var lbl_sub = Label3D.new()
	lbl_sub.font = _font_hekayat
	lbl_sub.font_size = 21
	lbl_sub.pixel_size = 0.0011
	lbl_sub.text = "⚔️ %s لشکر" % _fa_digits(count)
	lbl_sub.modulate = Color(1.0, 0.90, 0.48)
	lbl_sub.outline_size = 5
	lbl_sub.position = Vector3(0.0, 0.016, 0.078)
	lbl_sub.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl_sub)

	# StaticBody3D for direct 3D card selection
	var sb = StaticBody3D.new()
	sb.set_meta("card_continent", cont)
	var cs = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.17, 0.04, 0.225)
	cs.shape = box_shape
	sb.add_child(cs)
	root.add_child(sb)

	return root

func _create_3d_strategy_card(s_key: String, count: int, is_selected: bool, is_playable: bool) -> Node3D:
	var root = Node3D.new()
	root.name = "Card3DStrat_" + s_key
	var info: Dictionary = STRATEGY_INFO.get(s_key, {})

	# Outer Frame (Glows emerald/gold if playable or selected)
	var mat_frame = StandardMaterial3D.new()
	if is_selected:
		mat_frame.albedo_color = Color(1.0, 0.92, 0.32)
		mat_frame.emission_enabled = true
		mat_frame.emission = Color(1.0, 0.85, 0.22)
		mat_frame.emission_energy_multiplier = 2.0
	elif is_playable:
		mat_frame.albedo_color = Color(0.32, 0.95, 0.55)
		mat_frame.emission_enabled = true
		mat_frame.emission = Color(0.20, 0.85, 0.42)
		mat_frame.emission_energy_multiplier = 0.95
	else:
		mat_frame.albedo_color = Color(0.62, 0.48, 0.25)
	mat_frame.metallic = 0.78
	mat_frame.roughness = 0.26

	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(0.156, 0.010, 0.208)
	frame_box.material = mat_frame
	var frame_mi = MeshInstance3D.new()
	frame_mi.mesh = frame_box
	root.add_child(frame_mi)

	# Inner Obsidian & Crimson Card Face
	var mat_face = StandardMaterial3D.new()
	mat_face.albedo_color = Color(0.24, 0.08, 0.14) if is_playable else Color(0.15, 0.10, 0.14)
	mat_face.roughness = 0.36
	var face_box = BoxMesh.new()
	face_box.size = Vector3(0.140, 0.012, 0.192)
	face_box.material = mat_face
	var face_mi = MeshInstance3D.new()
	face_mi.mesh = face_box
	face_mi.position = Vector3(0.0, 0.002, 0.0)
	root.add_child(face_mi)

	# 3D Sculpted Emblem on Strategy Card Face
	var emblem_node = _build_strategy_3d_emblem(s_key)
	emblem_node.position = Vector3(0.0, 0.014, -0.020)
	root.add_child(emblem_node)

	# Count Badge (Top Right)
	if count > 1:
		var lbl_cnt = Label3D.new()
		lbl_cnt.font = _font_hekayat
		lbl_cnt.font_size = 24
		lbl_cnt.pixel_size = 0.0011
		lbl_cnt.text = "×%s" % _fa_digits(count)
		lbl_cnt.modulate = Color(1.0, 0.90, 0.38)
		lbl_cnt.outline_size = 6
		lbl_cnt.position = Vector3(0.048, 0.018, -0.070)
		lbl_cnt.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		root.add_child(lbl_cnt)

	# Strategy Persian Name & Short Effect on Card Face
	var lbl_title = Label3D.new()
	lbl_title.font = _font_hekayat
	lbl_title.font_size = 26
	lbl_title.pixel_size = 0.0011
	lbl_title.text = str(info.get("name_fa", s_key))
	lbl_title.modulate = Color(1.0, 0.96, 0.86)
	lbl_title.outline_size = 7
	lbl_title.position = Vector3(0.0, 0.016, 0.036)
	lbl_title.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl_title)

	var lbl_short = Label3D.new()
	lbl_short.font = _font_hekayat
	lbl_short.font_size = 19
	lbl_short.pixel_size = 0.00105
	lbl_short.text = str(info.get("short_fa", ""))
	lbl_short.modulate = Color(0.48, 1.0, 0.62) if is_playable else Color(0.82, 0.76, 0.70)
	lbl_short.outline_size = 5
	lbl_short.position = Vector3(0.0, 0.016, 0.072)
	lbl_short.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl_short)

	# StaticBody3D for direct 3D tap/raycast
	var sb = StaticBody3D.new()
	sb.set_meta("card_strategy", s_key)
	var cs = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.165, 0.04, 0.215)
	cs.shape = box_shape
	sb.add_child(cs)
	root.add_child(sb)

	return root

func _build_strategy_3d_emblem(s_key: String) -> Node3D:
	var n = Node3D.new()
	match s_key:
		"Target", "Insurgence":
			if _crown_mesh:
				var mi = MeshInstance3D.new()
				mi.mesh = _crown_mesh
				mi.material_override = _shared_mats["crown_gold"]
				mi.scale = Vector3(0.28, 0.28, 0.28)
				n.add_child(mi)
		"Bomb":
			var sph = SphereMesh.new()
			sph.radius = 0.020
			sph.height = 0.040
			sph.material = _shared_mats["die_red"]
			var mi = MeshInstance3D.new()
			mi.mesh = sph
			n.add_child(mi)
		"Canon":
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.010
			cyl.bottom_radius = 0.014
			cyl.height = 0.044
			cyl.material = _shared_mats["brass"]
			var mi = MeshInstance3D.new()
			mi.mesh = cyl
			mi.rotation_degrees = Vector3(0.0, 0.0, 65.0)
			n.add_child(mi)
		_:
			var gem = CylinderMesh.new()
			gem.top_radius = 0.020
			gem.bottom_radius = 0.020
			gem.height = 0.010
			gem.radial_segments = 6
			gem.material = _shared_mats["crown_gold"]
			var mi = MeshInstance3D.new()
			mi.mesh = gem
			n.add_child(mi)
	return n

# ==============================================================================
# 2D GUIDED COMMAND HUD & ENEMY CARDS INSPECTOR
# ==============================================================================

func _build_2d_command_hud() -> void:
	_ui_root = Control.new()
	_ui_root.name = "RiskCommandHUD"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.visible = false

	# Parent directly inside BaseGameHUD below StartGameOverlay so modals are ALWAYS on top!
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		hud.add_child(_ui_root)
		var start_ov = hud.get_node_or_null("StartGameOverlay")
		if is_instance_valid(start_ov):
			hud.move_child(_ui_root, start_ov.get_index())
	else:
		_fallback_canvas = CanvasLayer.new()
		_fallback_canvas.layer = 0
		add_child(_fallback_canvas)
		_fallback_canvas.add_child(_ui_root)

	# --------------------------------------------------------------------------
	# 1. TOP COMPACT BAR (Opponent Visible Cards Strip + Guided Step Banner)
	# --------------------------------------------------------------------------
	var top_container = VBoxContainer.new()
	top_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_container.offset_left = 18.0
	top_container.offset_right = -18.0
	top_container.offset_top = 382.0
	top_container.offset_bottom = 548.0
	top_container.add_theme_constant_override("separation", 6)
	top_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(top_container)

	# Row A: Live Opponent Cards Strip + "👁️ کارت‌های حریفان" Button
	var opp_panel = PanelContainer.new()
	var opp_sb = StyleBoxFlat.new()
	opp_sb.bg_color = Color(0.08, 0.05, 0.03, 0.92)
	opp_sb.border_color = Color(0.85, 0.68, 0.28, 0.85)
	opp_sb.set_border_width_all(2)
	opp_sb.set_corner_radius_all(14)
	opp_sb.content_margin_left = 12
	opp_sb.content_margin_right = 12
	opp_sb.content_margin_top = 6
	opp_sb.content_margin_bottom = 6
	opp_panel.add_theme_stylebox_override("panel", opp_sb)
	top_container.add_child(opp_panel)

	var opp_outer_row = HBoxContainer.new()
	opp_outer_row.add_theme_constant_override("separation", 10)
	opp_panel.add_child(opp_outer_row)

	_btn_enemy_inspector = _make_styled_button(
		"👁️ کارت‌های حریفان",
		Color(0.18, 0.36, 0.62, 0.98),
		Color(0.45, 0.78, 1.0, 0.95),
		22
	)
	_btn_enemy_inspector.custom_minimum_size = Vector2(185, 48)
	_btn_enemy_inspector.pressed.connect(func():
		AudioManager.sfx_button()
		_open_enemy_cards_modal()
	)
	opp_outer_row.add_child(_btn_enemy_inspector)

	var opp_scroll = ScrollContainer.new()
	opp_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	opp_scroll.custom_minimum_size = Vector2(0, 48)
	opp_outer_row.add_child(opp_scroll)

	_opponent_strip_box = HBoxContainer.new()
	_opponent_strip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_strip_box.alignment = BoxContainer.ALIGNMENT_END
	_opponent_strip_box.add_theme_constant_override("separation", 8)
	opp_scroll.add_child(_opponent_strip_box)

	# Row B: Guided Step-by-Step Banner
	var step_panel = PanelContainer.new()
	step_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var step_sb = StyleBoxFlat.new()
	step_sb.bg_color = Color(0.12, 0.08, 0.04, 0.90)
	step_sb.border_color = Color(0.95, 0.78, 0.32, 0.80)
	step_sb.set_border_width_all(2)
	step_sb.set_corner_radius_all(14)
	step_sb.content_margin_left = 14
	step_sb.content_margin_right = 14
	step_sb.content_margin_top = 6
	step_sb.content_margin_bottom = 6
	step_panel.add_theme_stylebox_override("panel", step_sb)
	top_container.add_child(step_panel)

	var step_vbox = VBoxContainer.new()
	step_vbox.add_theme_constant_override("separation", 2)
	step_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_panel.add_child(step_vbox)

	var step_top_row = HBoxContainer.new()
	step_top_row.add_theme_constant_override("separation", 10)
	step_vbox.add_child(step_top_row)

	_battle_feed_lbl = Label.new()
	_battle_feed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_feed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_battle_feed_lbl.add_theme_font_override("font", _font_hekayat)
	_battle_feed_lbl.add_theme_font_size_override("font_size", 22)
	_battle_feed_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.68))
	_battle_feed_lbl.text = "👑 هدف پیروزی: کسب ۲ تاج سلطه"
	step_top_row.add_child(_battle_feed_lbl)

	_step_badge_lbl = Label.new()
	_step_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_badge_lbl.add_theme_font_override("font", _font_hekayat)
	_step_badge_lbl.add_theme_font_size_override("font_size", 24)
	_step_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_step_badge_lbl.text = "مرحله ۱ از ۳: دریافت کارت"
	step_top_row.add_child(_step_badge_lbl)

	_step_guide_lbl = Label.new()
	_step_guide_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step_guide_lbl.add_theme_font_override("font", _font_hekayat)
	_step_guide_lbl.add_theme_font_size_override("font_size", 25)
	_step_guide_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
	_step_guide_lbl.text = ""
	step_vbox.add_child(_step_guide_lbl)

	# --------------------------------------------------------------------------
	# 2. BOTTOM COMPACT CONTEXTUAL COMMAND BAR (Only 148px tall above BottomBar)
	# --------------------------------------------------------------------------
	_bottom_panel = PanelContainer.new()
	_bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.offset_left = 18.0
	_bottom_panel.offset_right = -18.0
	_bottom_panel.offset_top = -308.0
	_bottom_panel.offset_bottom = -160.0

	var dock_sb = StyleBoxFlat.new()
	dock_sb.bg_color = Color(0.10, 0.06, 0.04, 0.95)
	dock_sb.border_color = Color(0.92, 0.74, 0.30, 0.92)
	dock_sb.set_border_width_all(2)
	dock_sb.set_corner_radius_all(18)
	dock_sb.shadow_color = Color(0, 0, 0, 0.65)
	dock_sb.shadow_size = 12
	dock_sb.content_margin_left = 16
	dock_sb.content_margin_right = 16
	dock_sb.content_margin_top = 8
	dock_sb.content_margin_bottom = 8
	_bottom_panel.add_theme_stylebox_override("panel", dock_sb)
	_ui_root.add_child(_bottom_panel)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_vbox.add_theme_constant_override("separation", 6)
	_bottom_panel.add_child(dock_vbox)

	_action_title_lbl = Label.new()
	_action_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_title_lbl.add_theme_font_override("font", _font_hekayat)
	_action_title_lbl.add_theme_font_size_override("font_size", 24)
	_action_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	dock_vbox.add_child(_action_title_lbl)

	var btn_scroll = ScrollContainer.new()
	btn_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	btn_scroll.custom_minimum_size = Vector2(0, 68)
	dock_vbox.add_child(btn_scroll)

	_action_buttons_row = HBoxContainer.new()
	_action_buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_buttons_row.add_theme_constant_override("separation", 10)
	btn_scroll.add_child(_action_buttons_row)

	# --------------------------------------------------------------------------
	# 3. ENEMY CARDS INSPECTOR MODAL ("👁️ وضعیت کارت‌های حریفان")
	# --------------------------------------------------------------------------
	_build_enemy_cards_modal()

	# --------------------------------------------------------------------------
	# 4. STRATEGY TARGET PICKER MODAL
	# --------------------------------------------------------------------------
	_build_strategy_target_modal()

func _build_enemy_cards_modal() -> void:
	_enemy_modal_backdrop = ColorRect.new()
	_enemy_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_enemy_modal_backdrop.color = Color(0, 0, 0, 0.74)
	_enemy_modal_backdrop.visible = false
	_ui_root.add_child(_enemy_modal_backdrop)

	_enemy_modal_panel = PanelContainer.new()
	_enemy_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_enemy_modal_panel.custom_minimum_size = Vector2(920, 760)
	_enemy_modal_panel.offset_left = -460.0
	_enemy_modal_panel.offset_right = 460.0
	_enemy_modal_panel.offset_top = -380.0
	_enemy_modal_panel.offset_bottom = 380.0

	var m_sb = StyleBoxFlat.new()
	m_sb.bg_color = Color(0.11, 0.07, 0.04, 0.98)
	m_sb.border_color = Color(0.95, 0.78, 0.32, 0.98)
	m_sb.set_border_width_all(3)
	m_sb.set_corner_radius_all(24)
	m_sb.content_margin_left = 24
	m_sb.content_margin_right = 24
	m_sb.content_margin_top = 20
	m_sb.content_margin_bottom = 20
	_enemy_modal_panel.add_theme_stylebox_override("panel", m_sb)
	_enemy_modal_backdrop.add_child(_enemy_modal_panel)

	var m_vbox = VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 14)
	_enemy_modal_panel.add_child(m_vbox)

	var header_lbl = Label.new()
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_override("font", _font_hekayat)
	header_lbl.add_theme_font_size_override("font_size", 36)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	header_lbl.text = "👁️ وضعیت کارت‌های قاره و تاج‌های همه بازیکنان"
	m_vbox.add_child(header_lbl)

	var sub_lbl = Label.new()
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", _font_hekayat)
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	sub_lbl.text = "کارت‌های قاره همه بازیکنان عمومی و قابل مشاهده است؛ کارت‌های استراتژی تا زمان اجرا مخفی هستند."
	m_vbox.add_child(sub_lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(scroll)

	_enemy_modal_body = VBoxContainer.new()
	_enemy_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_modal_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_enemy_modal_body)

	var btn_close = _make_styled_button("بستن پنجره", Color(0.55, 0.18, 0.18), Color(0.95, 0.45, 0.45), 28)
	btn_close.custom_minimum_size = Vector2(260, 62)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		_enemy_modal_backdrop.visible = false
	)
	m_vbox.add_child(btn_close)

func _open_enemy_cards_modal() -> void:
	if not is_instance_valid(_enemy_modal_body):
		return
	for child in _enemy_modal_body.get_children():
		child.queue_free()

	for p_idx in range(1, _player_count + 1):
		var is_me: bool = (p_idx == my_player_index)
		var p_card = PanelContainer.new()
		var p_sb = StyleBoxFlat.new()
		var f_col: Color = FACTION_COLORS.get(p_idx, Color.WHITE)
		p_sb.bg_color = Color(0.16, 0.11, 0.07, 0.96)
		p_sb.border_color = f_col
		p_sb.set_border_width_all(2)
		p_sb.set_corner_radius_all(16)
		p_sb.content_margin_left = 16
		p_sb.content_margin_right = 16
		p_sb.content_margin_top = 12
		p_sb.content_margin_bottom = 12
		p_card.add_theme_stylebox_override("panel", p_sb)
		_enemy_modal_body.add_child(p_card)

		var p_vbox = VBoxContainer.new()
		p_vbox.add_theme_constant_override("separation", 10)
		p_card.add_child(p_vbox)

		var t_cnt = int(_tokens[p_idx - 1]) if (p_idx - 1) < _tokens.size() else 0
		var s_cnt = int(_strategy_counts[p_idx - 1]) if (p_idx - 1) < _strategy_counts.size() else 0

		var top_row = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 14)
		p_vbox.add_child(top_row)

		var crown_lbl = Label.new()
		crown_lbl.add_theme_font_override("font", _font_hekayat)
		crown_lbl.add_theme_font_size_override("font_size", 26)
		crown_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.32))
		crown_lbl.text = "👑 تاج سلطه: %s از ۲  |  🃏 کارت استراتژی مخفی: %s" % [_fa_digits(t_cnt), _fa_digits(s_cnt)]
		top_row.add_child(crown_lbl)

		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.add_theme_font_override("font", _font_hekayat)
		name_lbl.add_theme_font_size_override("font_size", 28)
		name_lbl.add_theme_color_override("font_color", f_col.lightened(0.25))
		name_lbl.text = "%s %s %s" % [
			FACTION_DOTS.get(p_idx, ""),
			_get_player_name(p_idx),
			"(شما)" if is_me else "(حریف)"
		]
		top_row.add_child(name_lbl)

		# Visible Continent Cards Row
		var cont_row = HBoxContainer.new()
		cont_row.alignment = BoxContainer.ALIGNMENT_END
		cont_row.add_theme_constant_override("separation", 8)
		p_vbox.add_child(cont_row)

		var p_conts: Dictionary = _all_continents[p_idx - 1] if (p_idx - 1) < _all_continents.size() else {}
		var any_cont = false
		for cont in ALL_CONTINENTS:
			var cnt = int(p_conts.get(cont, 0))
			if cnt <= 0:
				continue
			any_cont = true
			var c_badge = PanelContainer.new()
			var c_col: Color = CONTINENT_COLORS.get(cont, Color.WHITE)
			var cb_sb = StyleBoxFlat.new()
			cb_sb.bg_color = c_col.darkened(0.45)
			cb_sb.border_color = c_col.lightened(0.22)
			cb_sb.set_border_width_all(2)
			cb_sb.set_corner_radius_all(12)
			cb_sb.content_margin_left = 12
			cb_sb.content_margin_right = 12
			cb_sb.content_margin_top = 6
			cb_sb.content_margin_bottom = 6
			c_badge.add_theme_stylebox_override("panel", cb_sb)

			var c_lbl = Label.new()
			c_lbl.add_theme_font_override("font", _font_hekayat)
			c_lbl.add_theme_font_size_override("font_size", 24)
			c_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
			c_lbl.text = "🗺️ %s ×%s" % [CONTINENT_NAMES_FA.get(cont, cont), _fa_digits(cnt)]
			c_badge.add_child(c_lbl)
			cont_row.add_child(c_badge)

		if not any_cont:
			var empty_lbl = Label.new()
			empty_lbl.add_theme_font_override("font", _font_hekayat)
			empty_lbl.add_theme_font_size_override("font_size", 23)
			empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.62))
			empty_lbl.text = "بدون کارت قاره"
			cont_row.add_child(empty_lbl)

		# If Spy revealed any enemy strategy cards, show them!
		if not is_me and _revealed_enemy_strategies.has(p_idx):
			var rev_dict: Dictionary = _revealed_enemy_strategies[p_idx]
			var rev_parts: Array[String] = []
			for sk in rev_dict.keys():
				if int(rev_dict[sk]) > 0:
					var s_info = STRATEGY_INFO.get(sk, {})
					rev_parts.append("%s ×%s" % [s_info.get("name_fa", sk), _fa_digits(int(rev_dict[sk]))])
			if not rev_parts.is_empty():
				var rev_lbl = Label.new()
				rev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				rev_lbl.add_theme_font_override("font", _font_hekayat)
				rev_lbl.add_theme_font_size_override("font_size", 23)
				rev_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
				rev_lbl.text = "🕵️ کارت‌های استراتژی لو رفته: " + " ، ".join(rev_parts)
				p_vbox.add_child(rev_lbl)

	_enemy_modal_backdrop.visible = true

func _build_strategy_target_modal() -> void:
	_target_modal_backdrop = ColorRect.new()
	_target_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_modal_backdrop.color = Color(0, 0, 0, 0.72)
	_target_modal_backdrop.visible = false
	_ui_root.add_child(_target_modal_backdrop)

	_target_modal_panel = PanelContainer.new()
	_target_modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_target_modal_panel.custom_minimum_size = Vector2(820, 560)
	_target_modal_panel.offset_left = -410.0
	_target_modal_panel.offset_right = 410.0
	_target_modal_panel.offset_top = -280.0
	_target_modal_panel.offset_bottom = 280.0

	var m_sb = StyleBoxFlat.new()
	m_sb.bg_color = Color(0.12, 0.07, 0.04, 0.98)
	m_sb.border_color = Color(0.95, 0.78, 0.32, 0.98)
	m_sb.set_border_width_all(3)
	m_sb.set_corner_radius_all(22)
	m_sb.content_margin_left = 24
	m_sb.content_margin_right = 24
	m_sb.content_margin_top = 20
	m_sb.content_margin_bottom = 20
	_target_modal_panel.add_theme_stylebox_override("panel", m_sb)
	_target_modal_backdrop.add_child(_target_modal_panel)

	var m_vbox = VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 14)
	_target_modal_panel.add_child(m_vbox)

	_target_modal_title = Label.new()
	_target_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_modal_title.add_theme_font_override("font", _font_hekayat)
	_target_modal_title.add_theme_font_size_override("font_size", 34)
	_target_modal_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	m_vbox.add_child(_target_modal_title)

	_target_modal_sub = Label.new()
	_target_modal_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_modal_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_modal_sub.add_theme_font_override("font", _font_hekayat)
	_target_modal_sub.add_theme_font_size_override("font_size", 25)
	_target_modal_sub.add_theme_color_override("font_color", Color(0.92, 0.86, 0.76))
	m_vbox.add_child(_target_modal_sub)

	var m_scroll = ScrollContainer.new()
	m_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_vbox.add_child(m_scroll)

	_target_modal_body = VBoxContainer.new()
	_target_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_modal_body.add_theme_constant_override("separation", 10)
	m_scroll.add_child(_target_modal_body)

	var btn_cancel = _make_styled_button("انصراف", Color(0.55, 0.16, 0.16), Color(0.95, 0.42, 0.42), 26)
	btn_cancel.custom_minimum_size = Vector2(220, 58)
	btn_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_cancel.pressed.connect(func():
		AudioManager.sfx_button()
		_target_modal_backdrop.visible = false
	)
	m_vbox.add_child(btn_cancel)

func _make_styled_button(text_str: String, bg_col: Color, border_col: Color, font_sz: int = 24) -> Button:
	var btn = Button.new()
	btn.text = text_str
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", _font_hekayat)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))

	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = bg_col
	sb_n.border_color = border_col
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(14)
	sb_n.content_margin_left = 16
	sb_n.content_margin_right = 16
	sb_n.content_margin_top = 8
	sb_n.content_margin_bottom = 8

	var sb_h = sb_n.duplicate()
	sb_h.bg_color = bg_col.lightened(0.14)
	sb_h.border_color = border_col.lightened(0.22)

	var sb_p = sb_n.duplicate()
	sb_p.bg_color = bg_col.darkened(0.15)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	return btn

# ==============================================================================
# 3D RAYCAST INTERACTION (CONTINENTS, 3D CARDS IN HAND & 3D DRAW DECKS)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _is_hud_overlay_blocking():
		return
	if is_instance_valid(_enemy_modal_backdrop) and _enemy_modal_backdrop.visible:
		return
	if is_instance_valid(_target_modal_backdrop) and _target_modal_backdrop.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_3d_pointer_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_3d_pointer_tap(event.position)

func _handle_3d_pointer_tap(screen_pos: Vector2) -> void:
	var vp = get_viewport()
	if not vp:
		return
	var cam = vp.get_camera_3d()
	if not cam:
		return
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 12.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result.get("collider")
	if not is_instance_valid(collider):
		return

	# 1. Tapped a 3D Continent Card in Player's Hand
	if collider.has_meta("card_continent"):
		var cont: String = str(collider.get_meta("card_continent"))
		_on_my_3d_continent_card_tapped(cont)
		return

	# 2. Tapped a 3D Strategy Card in Player's Hand
	if collider.has_meta("card_strategy"):
		var s_key: String = str(collider.get_meta("card_strategy"))
		_on_my_3d_strategy_card_tapped(s_key)
		return

	# 3. Tapped a 3D Draw Deck on the Table
	if collider.has_meta("deck_type"):
		var deck_type: String = str(collider.get_meta("deck_type"))
		_on_3d_deck_tapped(deck_type)
		return

	# 4. Tapped a 3D Continent Citadel on the War-Table Map
	if collider.has_meta("continent"):
		var cont_map: String = str(collider.get_meta("continent"))
		_on_3d_map_continent_tapped(cont_map)
		return

func _on_my_3d_continent_card_tapped(cont: String) -> void:
	AudioManager.sfx_tap()
	_selected_strategy_card = ""
	if _active_turn != my_player_index:
		show_hint("⏳ اکنون نوبت شما نیست.")
		return
	if _game_phase == "Draw":
		show_hint("🎴 ابتدا ۲ کارت ابتدای نوبت خود را دریافت کنید!")
		return
	if _game_phase != "Attack":
		return

	if _selected_my_continent == cont:
		_selected_my_continent = ""
		_selected_target_continent = ""
		_selected_target_defender = 0
	else:
		_selected_my_continent = cont
		_selected_target_continent = ""
		_selected_target_defender = 0
	_refresh_all_visuals()

func _on_my_3d_strategy_card_tapped(s_key: String) -> void:
	AudioManager.sfx_tap()
	if _selected_strategy_card == s_key:
		_selected_strategy_card = ""
	else:
		_selected_strategy_card = s_key
	_refresh_all_visuals()

func _on_3d_deck_tapped(deck_type: String) -> void:
	if _active_turn != my_player_index or _game_phase != "Draw":
		show_hint("🃏 کشیدن کارت فقط در مرحله ۱ (ابتدای نوبت شما) مجاز است.")
		return
	AudioManager.sfx_tap()
	var pick = "continent" if deck_type == "deck_continent" else "strategy"
	if _first_3d_deck_picked.is_empty():
		_first_3d_deck_picked = pick
		var pick_fa = "قاره 🗺️" if pick == "continent" else "استراتژی 🃏"
		show_hint("✅ کارت اول (%s) انتخاب شد؛ حالا روی دسته دوم بزنید!" % pick_fa)
		_refresh_all_visuals()
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
		send_move(Commands.Draw_Card, {"draw_type": draw_type})

func _on_3d_map_continent_tapped(cont: String) -> void:
	AudioManager.sfx_tap()
	if _active_turn != my_player_index or _game_phase != "Attack":
		return
	_selected_strategy_card = ""
	var my_conts = _get_my_continents_dict()
	var my_cnt = int(my_conts.get(cont, 0))

	# If nothing selected yet and we own this continent -> select it as source
	if _selected_my_continent.is_empty():
		if my_cnt > 0:
			_selected_my_continent = cont
			_selected_target_continent = ""
			_selected_target_defender = 0
			_refresh_all_visuals()
		else:
			show_hint("🗺️ ابتدا یکی از قاره‌های خودتان را برای شروع حمله انتخاب کنید.")
		return

	# Clicking the already-selected source continent deselects it
	if cont == _selected_my_continent:
		_selected_my_continent = ""
		_selected_target_continent = ""
		_selected_target_defender = 0
		_refresh_all_visuals()
		return

	# Check if cont is adjacent to _selected_my_continent and has an enemy owner
	var adj: Array = CONTINENT_ADJACENCY.get(_selected_my_continent, [])
	var defenders = _get_defenders_with_continent(cont)
	if cont in adj and not defenders.is_empty():
		_selected_target_continent = cont
		_selected_target_defender = defenders[0]
		_refresh_all_visuals()
		return

	# Otherwise if the player tapped another of their own continents, switch source continent
	if my_cnt > 0:
		_selected_my_continent = cont
		_selected_target_continent = ""
		_selected_target_defender = 0
		_refresh_all_visuals()
	else:
		show_hint("⚠️ قاره «%s» با «%s» هم‌مرز نیست یا هیچ حریفی در آن کارت ندارد." % [
			CONTINENT_NAMES_FA.get(cont, cont),
			CONTINENT_NAMES_FA.get(_selected_my_continent, _selected_my_continent)
		])

# ==============================================================================
# SERVER COMMAND & STATE SYNCHRONIZATION
# ==============================================================================

func on_start_game() -> void:
	_match_started = true
	_update_hud_visibility()
	_refresh_all_visuals()

func on_game_data(payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		_player_count = clampi((payload["gamers"] as Array).size(), 2, 4)
		_init_default_state()
	_refresh_all_visuals()

func on_turn_changed(turn: int, is_me: bool) -> void:
	_active_turn = turn
	is_my_turn = is_me
	if GameManager.is_game_active and turn > 0:
		_match_started = true
	_refresh_all_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_public_state_snapshot(g_data)
		if g_data.has("my_strategies") and typeof(g_data["my_strategies"]) == TYPE_DICTIONARY:
			_my_strategies = (g_data["my_strategies"] as Dictionary).duplicate()
		if g_data.has("turn"):
			_active_turn = int(g_data["turn"])
		if g_data.has("game_state"):
			_game_phase = str(g_data["game_state"])
		if g_data.has("attacker"):
			_current_battle_attacker = int(g_data["attacker"])
		if g_data.has("defender"):
			_current_battle_defender = int(g_data["defender"])
		if g_data.has("attacker_continent"):
			_current_battle_attacker_continent = str(g_data["attacker_continent"])
		if g_data.has("target_continent"):
			_current_battle_target_continent = str(g_data["target_continent"])
		if g_data.has("attacker_army"):
			_current_battle_attacker_army = int(g_data["attacker_army"])
	_update_hud_visibility()
	_refresh_all_visuals()

func _on_risk_event_received(cmd_id: String, payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	if cmd_id != Commands.User_Data and cmd_id != Commands.Game_Data:
		_match_started = true
	_apply_public_state_snapshot(payload)

	match cmd_id:
		Commands.User_Data:
			if payload.has("index"):
				var idx = int(payload["index"])
				if idx > 0:
					my_player_index = idx
			if payload.has("strategies") and typeof(payload["strategies"]) == TYPE_DICTIONARY:
				_my_strategies = (payload["strategies"] as Dictionary).duplicate()
			if payload.has("continents") and typeof(payload["continents"]) == TYPE_DICTIONARY:
				var p0 = clampi(my_player_index - 1, 0, 3)
				while _all_continents.size() <= p0:
					_all_continents.append({})
				_all_continents[p0] = (payload["continents"] as Dictionary).duplicate()
			if payload.has("tokens"):
				var p0 = clampi(my_player_index - 1, 0, 3)
				while _tokens.size() <= p0:
					_tokens.append(0)
				_tokens[p0] = int(payload["tokens"])

		Commands.Draw_Card:
			_active_turn = int(payload.get("turn", _active_turn))
			_game_phase = str(payload.get("game_state", "Draw"))
			_selected_my_continent = ""
			_selected_target_continent = ""
			_selected_target_defender = 0
			_selected_strategy_card = ""
			_first_3d_deck_picked = ""
			_won_attack_this_turn = false
			_eliminated_continent_this_turn = false
			_hide_battle_dice()
			_restart_hud_turn_timer()
			if _active_turn == my_player_index:
				AudioManager.play_sound("bell")

		Commands.Draw_Result_Private:
			if payload.has("my_strategies") and typeof(payload["my_strategies"]) == TYPE_DICTIONARY:
				_my_strategies = (payload["my_strategies"] as Dictionary).duplicate()
			if payload.has("my_continents") and typeof(payload["my_continents"]) == TYPE_DICTIONARY:
				var p0 = clampi(my_player_index - 1, 0, 3)
				if p0 < _all_continents.size():
					_all_continents[p0] = (payload["my_continents"] as Dictionary).duplicate()

		Commands.Draw_Result:
			_active_turn = int(payload.get("turn", _active_turn))
			_game_phase = str(payload.get("game_state", "Attack"))
			var dr_user = int(payload.get("user", _active_turn))
			var drawn_c: Array = payload.get("drawn_continents", []) if typeof(payload.get("drawn_continents", [])) == TYPE_ARRAY else []
			var s_drawn = int(payload.get("strategy_drawn_count", 0))
			_set_battle_feed_text(_format_draw_feed(dr_user, drawn_c, s_drawn))
			AudioManager.play_sound("add_peace")
			_restart_hud_turn_timer()

		Commands.Declare_Attack:
			_current_battle_attacker = int(payload.get("attacker", _active_turn))
			_current_battle_defender = int(payload.get("defender", 0))
			_current_battle_attacker_continent = str(payload.get("attacker_continent", ""))
			_current_battle_target_continent = str(payload.get("target_continent", ""))
			_game_phase = "AttackArmy"
			_set_battle_feed_text("⚔️ %s از «%s» به «%s» (%s) حمله کرد!" % [
				_get_player_name(_current_battle_attacker),
				CONTINENT_NAMES_FA.get(_current_battle_attacker_continent, _current_battle_attacker_continent),
				CONTINENT_NAMES_FA.get(_current_battle_target_continent, _current_battle_target_continent),
				_get_player_name(_current_battle_defender)
			])
			_restart_hud_turn_timer()

		Commands.AttackerArmy:
			_current_battle_attacker = int(payload.get("attacker", _current_battle_attacker))
			_current_battle_defender = int(payload.get("defender", _current_battle_defender))
			_current_battle_attacker_army = int(payload.get("attacker_army", 1))
			_game_phase = "DefenderArmy"
			_set_battle_feed_text("🎲 %s با %s لشکر وارد میدان شد! منتظر واکنش %s..." % [
				_get_player_name(_current_battle_attacker),
				_fa_digits(_current_battle_attacker_army),
				_get_player_name(_current_battle_defender)
			])

		Commands.QuestArmy:
			_current_battle_attacker = int(payload.get("attacker", _current_battle_attacker))
			_current_battle_defender = int(payload.get("defender", my_player_index))
			_current_battle_attacker_continent = str(payload.get("attacker_continent", _current_battle_attacker_continent))
			_current_battle_target_continent = str(payload.get("target_continent", _current_battle_target_continent))
			_current_battle_attacker_army = int(payload.get("attacker_army", 1))
			_game_phase = "QuestArmy"
			if _current_battle_defender == my_player_index:
				AudioManager.play_sound("bell")
			_restart_hud_turn_timer()

		Commands.DefenderArmy:
			var d_army = int(payload.get("defender_army", 1))
			_set_battle_feed_text("🛡️ %s با %s لشکر دفاع می‌کند!" % [
				_get_player_name(_current_battle_defender),
				_fa_digits(d_army)
			])

		Commands.Cancel_Attack:
			_active_turn = int(payload.get("turn", _active_turn))
			_game_phase = str(payload.get("game_state", "Attack"))
			var c_by = int(payload.get("canceled_by", _current_battle_defender))
			_set_battle_feed_text("🕊️ %s با کارت «آتش‌بس» حمله را متوقف کرد!" % _get_player_name(c_by))
			_hide_battle_dice()
			_restart_hud_turn_timer()

		Commands.Attack:
			_active_turn = int(payload.get("turn", _active_turn))
			_game_phase = str(payload.get("game_state", "Attack"))
			var a_dices: Array = payload.get("attacker_dices", []) if typeof(payload.get("attacker_dices", [])) == TYPE_ARRAY else []
			var d_dices: Array = payload.get("defender_dices", []) if typeof(payload.get("defender_dices", [])) == TYPE_ARRAY else []
			var a_losses = int(payload.get("attacker_losses", 0))
			var d_losses = int(payload.get("defender_losses", 0))
			var captured = bool(payload.get("captured", false))
			var def_elim = bool(payload.get("defender_continent_eliminated", false))

			if _current_battle_attacker == my_player_index and (d_losses > 0 or captured):
				_won_attack_this_turn = true
			if _current_battle_attacker == my_player_index and def_elim:
				_eliminated_continent_this_turn = true

			_animate_3d_battle_dice(a_dices, d_dices, a_losses, d_losses, captured)
			_selected_my_continent = ""
			_selected_target_continent = ""
			_selected_target_defender = 0
			_restart_hud_turn_timer()

		Commands.Strategy_Result:
			var s_user = int(payload.get("user", _active_turn))
			var s_card = str(payload.get("strategy", ""))
			if payload.has("game_state"):
				_game_phase = str(payload["game_state"])
			# Record revealed enemy strategy cards if Spy was used
			if s_card == "Spy" and payload.has("target_strategies") and typeof(payload["target_strategies"]) == TYPE_DICTIONARY:
				var t_p = int(payload.get("target_player", 0))
				if t_p > 0:
					_revealed_enemy_strategies[t_p] = (payload["target_strategies"] as Dictionary).duplicate()
			var s_info = STRATEGY_INFO.get(s_card, {})
			var s_name_fa = str(s_info.get("name_fa", s_card))
			_set_battle_feed_text("🃏 %s کارت استراتژی «%s» را اجرا کرد!" % [_get_player_name(s_user), s_name_fa])
			AudioManager.play_sound("add_peace")

		Commands.Pass_Turn:
			_active_turn = int(payload.get("turn", _active_turn))
			var awarded_to = int(payload.get("token_awarded_to", 0))
			if awarded_to > 0:
				_set_battle_feed_text("👑 %s به دلیل تسلط بر ۴ قاره، ۱ تاج سلطه دریافت کرد!" % _get_player_name(awarded_to))
				AudioManager.play_sound("win")

	_update_hud_visibility()
	_refresh_all_visuals()

func _apply_public_state_snapshot(payload: Dictionary) -> void:
	if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
		_tokens = (payload["tokens"] as Array).duplicate()
		_player_count = max(_player_count, _tokens.size())
	if payload.has("all_continents") and typeof(payload["all_continents"]) == TYPE_ARRAY:
		_all_continents = (payload["all_continents"] as Array).duplicate()
		_player_count = max(_player_count, _all_continents.size())
	elif payload.has("continents") and typeof(payload["continents"]) == TYPE_ARRAY:
		_all_continents = (payload["continents"] as Array).duplicate()
		_player_count = max(_player_count, _all_continents.size())
	if payload.has("strategies_count") and typeof(payload["strategies_count"]) == TYPE_ARRAY:
		_strategy_counts = (payload["strategies_count"] as Array).duplicate()
	elif payload.has("strategies") and typeof(payload["strategies"]) == TYPE_ARRAY:
		var s_arr: Array = payload["strategies"]
		_strategy_counts.clear()
		for item in s_arr:
			if typeof(item) == TYPE_DICTIONARY:
				var sum_s = 0
				for v in (item as Dictionary).values():
					sum_s += int(v)
				_strategy_counts.append(sum_s)
				if _strategy_counts.size() == my_player_index:
					_my_strategies = (item as Dictionary).duplicate()
			else:
				_strategy_counts.append(int(item))
	_sync_top_header_stats()

func _sync_top_header_stats() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if is_instance_valid(header) and header.has_method("update_risk_stats"):
		var cont_totals: Array = []
		for i in range(_player_count):
			var d: Dictionary = _all_continents[i] if i < _all_continents.size() and typeof(_all_continents[i]) == TYPE_DICTIONARY else {}
			var sum_c = 0
			for v in d.values():
				sum_c += int(v)
			cont_totals.append(sum_c)
		header.update_risk_stats(_tokens, cont_totals, _strategy_counts)

func _restart_hud_turn_timer() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(30.0)

# ==============================================================================
# VISUAL REFRESH (3D MAP, 3D HAND CARDS, ENEMY STRIP & GUIDED ACTION BAR)
# ==============================================================================

func _refresh_all_visuals() -> void:
	_refresh_3d_continents_and_troops()
	_refresh_3d_sea_lane_bridges()
	_refresh_3d_crowns()
	_rebuild_3d_hand_cards()
	_refresh_opponent_strip()
	_refresh_guided_step_and_actions()

func _refresh_3d_continents_and_troops() -> void:
	var adj_from_sel: Array = CONTINENT_ADJACENCY.get(_selected_my_continent, []) if not _selected_my_continent.is_empty() else []
	var is_my_attack_phase: bool = (_active_turn == my_player_index and _game_phase == "Attack")

	for cont in ALL_CONTINENTS:
		if not _continent_nodes.has(cont):
			continue
		var info: Dictionary = _continent_nodes[cont]
		var ring: MeshInstance3D = info["select_ring"]
		var ring_mat: StandardMaterial3D = info["ring_mat"]
		var lbl_counts: Label3D = info["lbl_counts"]
		var target_badge: Label3D = info["target_badge"]
		var troops_holder: Node3D = info["troops_holder"]

		for ch in troops_holder.get_children():
			ch.queue_free()

		var parts: Array[String] = []
		var active_players_in_cont: Array[int] = []
		for p_i in range(_player_count):
			var d: Dictionary = _all_continents[p_i] if p_i < _all_continents.size() and typeof(_all_continents[p_i]) == TYPE_DICTIONARY else {}
			var cnt = int(d.get(cont, 0))
			if cnt > 0:
				var p_num = p_i + 1
				var tag = "شما" if p_num == my_player_index else ("حریف" if _player_count == 2 else ("ب" + _fa_digits(p_num)))
				parts.append("%s%s:%s" % [FACTION_DOTS.get(p_num, ""), tag, _fa_digits(cnt)])
				active_players_in_cont.append(p_num)

		if parts.is_empty():
			lbl_counts.text = "خالی"
			lbl_counts.modulate = Color(0.72, 0.72, 0.72, 0.80)
		else:
			lbl_counts.text = " | ".join(parts)
			lbl_counts.modulate = Color(1.0, 0.94, 0.58)

		# Spawn 3D Faction Troop Miniatures around the citadel
		for idx_slot in range(active_players_in_cont.size()):
			var p_num = active_players_in_cont[idx_slot]
			var d: Dictionary = _all_continents[p_num - 1]
			var cnt = int(d.get(cont, 0))
			var angle = float(idx_slot) * (TAU / maxf(1.0, float(active_players_in_cont.size()))) - 0.6
			var radius = 0.068
			var t_pos = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			var pawn = _create_3d_faction_troop(p_num, cnt)
			pawn.position = t_pos
			troops_holder.add_child(pawn)

		# Highlight source continent or valid adjacent enemy target continents
		var defenders = _get_defenders_with_continent(cont)
		var is_valid_target: bool = (is_my_attack_phase and not _selected_my_continent.is_empty() and cont in adj_from_sel and not defenders.is_empty())

		if cont == _selected_my_continent:
			ring.visible = true
			ring_mat.albedo_color = Color(0.28, 1.0, 0.48, 0.95)
			ring_mat.emission = Color(0.20, 0.95, 0.40)
			target_badge.visible = false
		elif cont == _selected_target_continent:
			ring.visible = true
			ring_mat.albedo_color = Color(1.0, 0.22, 0.22, 0.98)
			ring_mat.emission = Color(1.0, 0.18, 0.18)
			target_badge.visible = true
			target_badge.text = "⚔️ هدف انتخاب‌شده"
		elif is_valid_target:
			ring.visible = true
			ring_mat.albedo_color = Color(1.0, 0.78, 0.22, 0.92)
			ring_mat.emission = Color(1.0, 0.68, 0.15)
			target_badge.visible = true
			target_badge.text = "🎯 هدف قابل حمله (بزنید)"
		else:
			ring.visible = false
			target_badge.visible = false

func _create_3d_faction_troop(player_num: int, count: int) -> Node3D:
	var root = Node3D.new()
	var col: Color = FACTION_COLORS.get(player_num, Color.WHITE)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.25
	mat.metallic = 0.22

	var stacks = clampi(count, 1, 3)
	for s_i in range(stacks):
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.017
		cyl.bottom_radius = 0.020
		cyl.height = 0.012
		cyl.radial_segments = 14
		cyl.material = mat
		var mi = MeshInstance3D.new()
		mi.mesh = cyl
		mi.position = Vector3(0.0, float(s_i) * 0.013 + 0.006, 0.0)
		root.add_child(mi)

	var head = SphereMesh.new()
	head.radius = 0.013
	head.height = 0.026
	head.material = mat
	var h_mi = MeshInstance3D.new()
	h_mi.mesh = head
	h_mi.position = Vector3(0.0, float(stacks) * 0.013 + 0.010, 0.0)
	root.add_child(h_mi)
	return root

func _refresh_3d_sea_lane_bridges() -> void:
	for k in _bridge_meshes.keys():
		var mi: MeshInstance3D = _bridge_meshes[k]
		if is_instance_valid(mi):
			mi.material_override = _shared_mats["bridge_idle"]
	if not _selected_my_continent.is_empty():
		var adj: Array = CONTINENT_ADJACENCY.get(_selected_my_continent, [])
		for target_c in adj:
			var key = _selected_my_continent + "_" + str(target_c)
			if _bridge_meshes.has(key):
				var mi: MeshInstance3D = _bridge_meshes[key]
				if is_instance_valid(mi):
					mi.material_override = _shared_mats["bridge_active"]

func _refresh_3d_crowns() -> void:
	for p_idx in [1, 2, 3, 4]:
		if not _player_crown_nodes.has(p_idx):
			continue
		var t_cnt = int(_tokens[p_idx - 1]) if (p_idx - 1) < _tokens.size() else 0
		var arr: Array = _player_crown_nodes[p_idx]
		for slot_i in range(arr.size()):
			var c_node: Node3D = arr[slot_i]
			if is_instance_valid(c_node):
				c_node.visible = (p_idx <= _player_count and slot_i < t_cnt)

# Live Opponent Cards Strip at Top (Shows Opponent Continent Cards right on screen!)
func _refresh_opponent_strip() -> void:
	if not is_instance_valid(_opponent_strip_box):
		return
	for ch in _opponent_strip_box.get_children():
		ch.queue_free()

	for p_idx in range(1, _player_count + 1):
		if p_idx == my_player_index:
			continue
		var p_conts: Dictionary = _all_continents[p_idx - 1] if (p_idx - 1) < _all_continents.size() else {}
		var t_cnt = int(_tokens[p_idx - 1]) if (p_idx - 1) < _tokens.size() else 0
		var s_cnt = int(_strategy_counts[p_idx - 1]) if (p_idx - 1) < _strategy_counts.size() else 0

		var cont_parts: Array[String] = []
		for c in ALL_CONTINENTS:
			var cnt = int(p_conts.get(c, 0))
			if cnt > 0:
				cont_parts.append("%s×%s" % [CONTINENT_NAMES_FA.get(c, c), _fa_digits(cnt)])

		var cont_summary = " ، ".join(cont_parts) if not cont_parts.is_empty() else "بدون قاره"
		var btn_text = "%s %s (👑%s | 🃏%s): %s" % [
			FACTION_DOTS.get(p_idx, ""),
			_get_player_name(p_idx),
			_fa_digits(t_cnt),
			_fa_digits(s_cnt),
			cont_summary
		]
		var f_col: Color = FACTION_COLORS.get(p_idx, Color.WHITE)
		var opp_btn = _make_styled_button(btn_text, f_col.darkened(0.62), f_col.lightened(0.15), 21)
		opp_btn.pressed.connect(func():
			AudioManager.sfx_button()
			_open_enemy_cards_modal()
		)
		_opponent_strip_box.add_child(opp_btn)

func _refresh_guided_step_and_actions() -> void:
	if not is_instance_valid(_action_buttons_row):
		return
	for ch in _action_buttons_row.get_children():
		ch.queue_free()

	var is_my_draw: bool = (_active_turn == my_player_index and _game_phase == "Draw")
	if is_instance_valid(_deck_continent_hint_3d):
		_deck_continent_hint_3d.visible = is_my_draw
	if is_instance_valid(_deck_strategy_hint_3d):
		_deck_strategy_hint_3d.visible = is_my_draw

	# CASE 1: Urgent Defense Phase (Even when _active_turn is the attacker!)
	if (_game_phase in ["DefenderArmy", "QuestArmy"]) and _current_battle_defender == my_player_index:
		_step_badge_lbl.text = "🛡️ فاز دفاع فوری شما!"
		_step_guide_lbl.text = "%s از «%s» با %s لشکر به «%s» شما حمله کرده است!" % [
			_get_player_name(_current_battle_attacker),
			CONTINENT_NAMES_FA.get(_current_battle_attacker_continent, _current_battle_attacker_continent),
			_fa_digits(_current_battle_attacker_army),
			CONTINENT_NAMES_FA.get(_current_battle_target_continent, _current_battle_target_continent)
		]
		_action_title_lbl.text = "🛡️ واکنش دفاعی خود را انتخاب کنید (حداکثر ۲ لشکر یا کارت آتش‌بس):"

		var my_conts = _get_my_continents_dict()
		var max_def = clampi(min(2, int(my_conts.get(_current_battle_target_continent, 1))), 1, 2)
		for army_cnt in range(1, max_def + 1):
			var d_icons = "🛡️".repeat(army_cnt)
			var btn_def = _make_styled_button(
				"%s دفاع با %s لشکر (%s تاس)" % [d_icons, _fa_digits(army_cnt), _fa_digits(army_cnt)],
				Color(0.14, 0.42, 0.72),
				Color(0.42, 0.78, 1.0),
				25
			)
			var chosen_d = army_cnt
			btn_def.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.DefenderArmy, {"defender_army": chosen_d})
			)
			_action_buttons_row.add_child(btn_def)

		if int(_my_strategies.get("Cancel", 0)) > 0:
			var btn_cancel = _make_styled_button(
				"🕊️ کارت آتش‌بس (لغو کامل حمله)",
				Color(0.16, 0.56, 0.32),
				Color(0.45, 0.96, 0.62),
				25
			)
			btn_cancel.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.Cancel_Attack, {})
			)
			_action_buttons_row.add_child(btn_cancel)

		if int(_my_strategies.get("Canon", 0)) > 0:
			var btn_canon = _make_styled_button(
				"💥 کارت توپخانه (+۱ به تاس دفاع)",
				Color(0.62, 0.34, 0.12),
				Color(1.0, 0.76, 0.30),
				24
			)
			btn_canon.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.Use_Strategy, {"strategy": "Canon"})
			)
			_action_buttons_row.add_child(btn_canon)
		return

	# CASE 2: A 3D Strategy Card is currently selected for inspection/play
	if not _selected_strategy_card.is_empty():
		var s_key = _selected_strategy_card
		var info: Dictionary = STRATEGY_INFO.get(s_key, {})
		var s_name_fa = str(info.get("name_fa", s_key))
		var s_desc = str(info.get("desc", ""))
		var can_play = _can_play_strategy_now(s_key)

		_step_badge_lbl.text = "🃏 کارت استراتژی: «%s»" % s_name_fa
		_step_guide_lbl.text = s_desc
		_action_title_lbl.text = "🃏 %s — %s" % [s_name_fa, s_desc]

		if can_play:
			var btn_play = _make_styled_button(
				"⚡ اجرای کارت «%s»" % s_name_fa,
				Color(0.16, 0.56, 0.28),
				Color(0.45, 0.98, 0.60),
				26
			)
			btn_play.pressed.connect(func():
				AudioManager.sfx_button()
				_execute_strategy_card(s_key)
			)
			_action_buttons_row.add_child(btn_play)
		else:
			var lbl_wait = Label.new()
			lbl_wait.add_theme_font_override("font", _font_hekayat)
			lbl_wait.add_theme_font_size_override("font_size", 23)
			lbl_wait.add_theme_color_override("font_color", Color(1.0, 0.68, 0.42))
			lbl_wait.text = "⏳ این کارت در این لحظه قابل اجرا نیست."
			_action_buttons_row.add_child(lbl_wait)

		var btn_back = _make_styled_button("بستن کارت", Color(0.42, 0.22, 0.18), Color(0.85, 0.55, 0.45), 24)
		btn_back.pressed.connect(func():
			AudioManager.sfx_tap()
			_selected_strategy_card = ""
			_refresh_all_visuals()
		)
		_action_buttons_row.add_child(btn_back)
		return

	# CASE 3: Not My Turn
	if _active_turn != my_player_index:
		var active_name = _get_player_name(_active_turn)
		_step_badge_lbl.text = "⏳ نوبت %s" % active_name
		_step_guide_lbl.text = "منتظر تصمیم %s باشید. می‌توانید کارت‌های حریفان یا کارت‌های سه‌بعدی خود را بررسی کنید." % active_name
		_action_title_lbl.text = "⏳ نوبت فرماندهی %s است..." % active_name

		var btn_inspect = _make_styled_button(
			"👁️ مشاهده کارت‌های حریفان",
			Color(0.18, 0.36, 0.62),
			Color(0.48, 0.80, 1.0),
			24
		)
		btn_inspect.pressed.connect(func():
			AudioManager.sfx_button()
			_open_enemy_cards_modal()
		)
		_action_buttons_row.add_child(btn_inspect)
		return

	# CASE 4: My Turn — Step 1: Rally Draw Phase ("Draw")
	if _game_phase == "Draw":
		_step_badge_lbl.text = "مرحله ۱ از ۳: دریافت ۲ کارت"
		_step_guide_lbl.text = "ترکیب ۲ کارت ورودی این نوبت را از دکمه‌های زیر انتخاب کنید (یا روی دسته‌های کارت سه‌بعدی بزنید):"
		_action_title_lbl.text = "🎴 دریافت نیرو — ۲ کارت خود را انتخاب کنید:"

		var btn_d1 = _make_styled_button("🗺️+🗺️  ۲ کارت قاره", Color(0.14, 0.48, 0.30), Color(0.38, 0.92, 0.58), 25)
		btn_d1.pressed.connect(func():
			AudioManager.sfx_button()
			send_move(Commands.Draw_Card, {"draw_type": 1})
		)
		_action_buttons_row.add_child(btn_d1)

		var btn_d3 = _make_styled_button("🗺️+🃏  ۱ قاره + ۱ استراتژی", Color(0.52, 0.36, 0.12), Color(0.98, 0.78, 0.30), 25)
		btn_d3.pressed.connect(func():
			AudioManager.sfx_button()
			send_move(Commands.Draw_Card, {"draw_type": 3})
		)
		_action_buttons_row.add_child(btn_d3)

		var btn_d2 = _make_styled_button("🃏+🃏  ۲ کارت استراتژی", Color(0.46, 0.16, 0.34), Color(0.95, 0.45, 0.72), 25)
		btn_d2.pressed.connect(func():
			AudioManager.sfx_button()
			send_move(Commands.Draw_Card, {"draw_type": 2})
		)
		_action_buttons_row.add_child(btn_d2)
		return

	# CASE 5: My Turn — Step 2: Attack / Strategy Phase ("Attack")
	if _game_phase == "Attack":
		_step_badge_lbl.text = "مرحله ۲ از ۳: انتخاب قاره و حمله"

		if _selected_my_continent.is_empty():
			_step_guide_lbl.text = "👇 روی یکی از «کارت‌های قاره سه‌بعدی» خود در پایین میز (یا قلعه قاره‌تان روی نقشه) بزنید تا قاره مهاجم انتخاب شود."
			_action_title_lbl.text = "⚔️ قاره مهاجم را از روی کارت‌های سه‌بعدی خود انتخاب کنید یا نوبت را پایان دهید:"

			var btn_enemies = _make_styled_button(
				"👁️ کارت‌های حریفان",
				Color(0.18, 0.36, 0.62),
				Color(0.48, 0.80, 1.0),
				24
			)
			btn_enemies.pressed.connect(func():
				AudioManager.sfx_button()
				_open_enemy_cards_modal()
			)
			_action_buttons_row.add_child(btn_enemies)

			var btn_pass = _make_styled_button(
				"⏭️ پایان نوبت (بررسی دریافت تاج 👑)",
				Color(0.48, 0.28, 0.14),
				Color(0.95, 0.68, 0.32),
				25
			)
			btn_pass.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.Pass_Turn, {})
			)
			_action_buttons_row.add_child(btn_pass)
			return

		# A source continent IS selected -> show 1-tap attack buttons for every adjacent enemy continent!
		var src_fa = CONTINENT_NAMES_FA.get(_selected_my_continent, _selected_my_continent)
		var adj_list: Array = CONTINENT_ADJACENCY.get(_selected_my_continent, [])
		_step_guide_lbl.text = "✅ قاره مهاجم: «%s» — حالا قاره هدف را روی نقشه سه‌بعدی یا از دکمه‌های زیر انتخاب کنید:" % src_fa
		_action_title_lbl.text = "⚔️ حمله از «%s» به کدام قاره هم‌مرز حریف؟" % src_fa

		var any_target_btn = false
		for t_cont in adj_list:
			var defs = _get_defenders_with_continent(t_cont)
			for def_idx in defs:
				any_target_btn = true
				var def_conts: Dictionary = _all_continents[def_idx - 1]
				var def_cnt = int(def_conts.get(t_cont, 0))
				var t_fa = CONTINENT_NAMES_FA.get(t_cont, t_cont)
				var btn_atk = _make_styled_button(
					"⚔️ حمله به %s (%s - %s کارت)" % [t_fa, _get_player_name(def_idx), _fa_digits(def_cnt)],
					Color(0.68, 0.16, 0.18),
					Color(1.0, 0.48, 0.42),
					24
				)
				var chosen_src = _selected_my_continent
				var chosen_tgt = t_cont
				var chosen_def = def_idx
				btn_atk.pressed.connect(func():
					AudioManager.sfx_button()
					send_move(Commands.Declare_Attack, {
						"attacker_continent": chosen_src,
						"target_continent": chosen_tgt,
						"defender": chosen_def
					})
				)
				_action_buttons_row.add_child(btn_atk)

		if not any_target_btn:
			var lbl_no = Label.new()
			lbl_no.add_theme_font_override("font", _font_hekayat)
			lbl_no.add_theme_font_size_override("font_size", 23)
			lbl_no.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42))
			lbl_no.text = "هیچ حریفی در قاره‌های هم‌مرز «%s» کارت ندارد!" % src_fa
			_action_buttons_row.add_child(lbl_no)

		var btn_change = _make_styled_button("تغییر قاره", Color(0.32, 0.25, 0.20), Color(0.78, 0.65, 0.50), 23)
		btn_change.pressed.connect(func():
			AudioManager.sfx_tap()
			_selected_my_continent = ""
			_selected_target_continent = ""
			_refresh_all_visuals()
		)
		_action_buttons_row.add_child(btn_change)

		var btn_pass2 = _make_styled_button("⏭️ پایان نوبت", Color(0.48, 0.28, 0.14), Color(0.95, 0.68, 0.32), 23)
		btn_pass2.pressed.connect(func():
			AudioManager.sfx_button()
			send_move(Commands.Pass_Turn, {})
		)
		_action_buttons_row.add_child(btn_pass2)
		return

	# CASE 6: My Turn — Step 3: Attacker Army Commitment ("AttackArmy")
	if _game_phase == "AttackArmy":
		_step_badge_lbl.text = "مرحله ۳ از ۳: اعزام لشکر و پرتاب تاس"
		_step_guide_lbl.text = "مشخص کنید با چند لشکر (تاس حمله) از «%s» به «%s» حمله می‌کنید:" % [
			CONTINENT_NAMES_FA.get(_current_battle_attacker_continent, _current_battle_attacker_continent),
			CONTINENT_NAMES_FA.get(_current_battle_target_continent, _current_battle_target_continent)
		]
		_action_title_lbl.text = "🎲 تعداد لشکر (تاس‌های حمله) را انتخاب کنید:"

		var my_conts = _get_my_continents_dict()
		var max_atk = clampi(min(3, int(my_conts.get(_current_battle_attacker_continent, 1))), 1, 3)
		for army_cnt in range(1, max_atk + 1):
			var dice_icons = "🎲".repeat(army_cnt)
			var btn_army = _make_styled_button(
				"%s حمله با %s لشکر (%s تاس)" % [dice_icons, _fa_digits(army_cnt), _fa_digits(army_cnt)],
				Color(0.68, 0.16, 0.18),
				Color(1.0, 0.50, 0.42),
				25
			)
			var chosen_a = army_cnt
			btn_army.pressed.connect(func():
				AudioManager.sfx_button()
				send_move(Commands.AttackerArmy, {"attacker_army": chosen_a})
			)
			_action_buttons_row.add_child(btn_army)
		return

	# CASE 7: Waiting for Defender to Respond
	_step_badge_lbl.text = "🎲 در انتظار واکنش مدافع..."
	_step_guide_lbl.text = "منتظر تصمیم دفاعی %s در برابر حمله شما..." % _get_player_name(_current_battle_defender)
	_action_title_lbl.text = "⏳ در انتظار انتخاب لشکر مدافع (%s)..." % _get_player_name(_current_battle_defender)

# ==============================================================================
# STRATEGY CARD EXECUTION & TARGET SELECTION
# ==============================================================================

func _can_play_strategy_now(s_key: String) -> bool:
	if int(_my_strategies.get(s_key, 0)) <= 0:
		return false
	# Defender can play Cancel / Canon / Army during DefenderArmy / QuestArmy
	if (_game_phase in ["DefenderArmy", "QuestArmy"]) and _current_battle_defender == my_player_index:
		return s_key in ["Cancel", "Canon", "Army"]
	if _active_turn != my_player_index:
		return false
	var info: Dictionary = STRATEGY_INFO.get(s_key, {})
	var phases: Array = info.get("phases", [])
	if not (_game_phase in phases):
		return false
	if s_key == "Target" and not _won_attack_this_turn:
		return false
	if s_key == "Insurgence" and not _eliminated_continent_this_turn:
		return false
	if s_key in ["Backup", "Army"] and _get_my_owned_continents_list().is_empty():
		return false
	return true

func _execute_strategy_card(s_key: String) -> void:
	_selected_strategy_card = ""
	match s_key:
		"Expand", "Destroy", "Target", "Canon":
			send_move(Commands.Use_Strategy, {"strategy": s_key})
		"Cancel":
			send_move(Commands.Cancel_Attack, {})
		"Backup", "Army":
			_open_my_continent_picker_for_strategy(s_key)
		"Bomb":
			_open_enemy_continent_picker_for_bomb()
		"Spy":
			_open_enemy_player_picker_for_strategy("Spy", "🕵️ کارت جاسوس — انتخاب حریف", "یکی از حریفان را که کارت استراتژی دارد انتخاب کنید:")
		"Insurgence":
			_open_enemy_player_picker_for_strategy("Insurgence", "🔥 کارت کودتا — ربودن تاج", "حریفی که تاج سلطه دارد را انتخاب کنید:")
	_refresh_all_visuals()

func _open_my_continent_picker_for_strategy(s_key: String) -> void:
	for ch in _target_modal_body.get_children():
		ch.queue_free()
	var s_info = STRATEGY_INFO.get(s_key, {})
	_target_modal_title.text = "🃏 اجرای کارت «%s»" % s_info.get("name_fa", s_key)
	_target_modal_sub.text = "یکی از قاره‌های خود را انتخاب کنید:"

	var my_conts = _get_my_continents_dict()
	for cont in ALL_CONTINENTS:
		var cnt = int(my_conts.get(cont, 0))
		if cnt <= 0:
			continue
		var btn = _make_styled_button(
			"🗺️ %s (دارای %s کارت)" % [CONTINENT_NAMES_FA.get(cont, cont), _fa_digits(cnt)],
			CONTINENT_COLORS.get(cont, Color.BLUE).darkened(0.38),
			CONTINENT_COLORS.get(cont, Color.BLUE).lightened(0.22),
			26
		)
		var c_choice = cont
		btn.pressed.connect(func():
			AudioManager.sfx_button()
			_target_modal_backdrop.visible = false
			send_move(Commands.Use_Strategy, {"strategy": s_key, "continent": c_choice})
		)
		_target_modal_body.add_child(btn)
	_target_modal_backdrop.visible = true

func _open_enemy_continent_picker_for_bomb() -> void:
	for ch in _target_modal_body.get_children():
		ch.queue_free()
	_target_modal_title.text = "💣 کارت بمباران — انتخاب قاره حریف"
	_target_modal_sub.text = "قاره و حریف مورد نظر برای حذف ۱ کارت قاره را انتخاب کنید:"

	var count_targets = 0
	for p_idx in range(1, _player_count + 1):
		if p_idx == my_player_index:
			continue
		var p_conts: Dictionary = _all_continents[p_idx - 1] if (p_idx - 1) < _all_continents.size() else {}
		for cont in ALL_CONTINENTS:
			var cnt = int(p_conts.get(cont, 0))
			if cnt <= 0:
				continue
			count_targets += 1
			var btn = _make_styled_button(
				"💣 %s — قاره %s (%s کارت)" % [_get_player_name(p_idx), CONTINENT_NAMES_FA.get(cont, cont), _fa_digits(cnt)],
				Color(0.55, 0.16, 0.18),
				Color(1.0, 0.48, 0.42),
				25
			)
			var target_p = p_idx
			var target_c = cont
			btn.pressed.connect(func():
				AudioManager.sfx_button()
				_target_modal_backdrop.visible = false
				send_move(Commands.Use_Strategy, {
					"strategy": "Bomb",
					"target_player": target_p,
					"target_continent": target_c
				})
			)
			_target_modal_body.add_child(btn)

	if count_targets == 0:
		show_hint("هیچ‌یک از حریفان کارت قاره‌ای در دست ندارند!")
		return
	_target_modal_backdrop.visible = true

func _open_enemy_player_picker_for_strategy(s_key: String, title_str: String, sub_str: String) -> void:
	for ch in _target_modal_body.get_children():
		ch.queue_free()
	_target_modal_title.text = title_str
	_target_modal_sub.text = sub_str

	var valid_count = 0
	for p_idx in range(1, _player_count + 1):
		if p_idx == my_player_index:
			continue
		var s_cnt = int(_strategy_counts[p_idx - 1]) if (p_idx - 1) < _strategy_counts.size() else 0
		var t_cnt = int(_tokens[p_idx - 1]) if (p_idx - 1) < _tokens.size() else 0
		if s_key == "Spy" and s_cnt <= 0:
			continue
		if s_key == "Insurgence" and t_cnt <= 0:
			continue
		valid_count += 1
		var btn = _make_styled_button(
			"%s %s (👑%s | 🃏%s)" % [FACTION_DOTS.get(p_idx, ""), _get_player_name(p_idx), _fa_digits(t_cnt), _fa_digits(s_cnt)],
			Color(0.24, 0.36, 0.58),
			Color(0.52, 0.78, 1.0),
			26
		)
		var chosen_p = p_idx
		btn.pressed.connect(func():
			AudioManager.sfx_button()
			_target_modal_backdrop.visible = false
			send_move(Commands.Use_Strategy, {"strategy": s_key, "target_player": chosen_p})
		)
		_target_modal_body.add_child(btn)

	if valid_count == 0:
		show_hint("هیچ حریفی شرایط اجرای این کارت را ندارد!")
		return
	_target_modal_backdrop.visible = true

# ==============================================================================
# 3D BATTLE DICE ANIMATION & HELPERS
# ==============================================================================

func _animate_3d_battle_dice(a_dices: Array, d_dices: Array, a_losses: int, d_losses: int, captured: bool) -> void:
	AudioManager.play_sound("dice")
	for i in range(3):
		var d_node = _attacker_dice_nodes[i]
		if i < a_dices.size():
			d_node.visible = true
			var val = int(a_dices[i])
			var v_lbl = d_node.get_node_or_null("DieValueLabel") as Label3D
			if is_instance_valid(v_lbl):
				v_lbl.text = "🎲" + _fa_digits(val)
			var tw = create_tween()
			tw.tween_property(d_node, "position:y", 0.19, 0.14)
			tw.parallel().tween_property(d_node, "rotation_degrees", Vector3(360.0, 180.0, 0.0), 0.26)
			tw.tween_property(d_node, "position:y", 0.088, 0.14)
		else:
			d_node.visible = false

	for i in range(2):
		var d_node = _defender_dice_nodes[i]
		if i < d_dices.size():
			d_node.visible = true
			var val = int(d_dices[i])
			var v_lbl = d_node.get_node_or_null("DieValueLabel") as Label3D
			if is_instance_valid(v_lbl):
				v_lbl.text = "🛡️" + _fa_digits(val)
			var tw = create_tween()
			tw.tween_property(d_node, "position:y", 0.18, 0.14)
			tw.parallel().tween_property(d_node, "rotation_degrees", Vector3(-360.0, -180.0, 0.0), 0.26)
			tw.tween_property(d_node, "position:y", 0.088, 0.14)
		else:
			d_node.visible = false

	var a_str_arr: Array[String] = []
	for v in a_dices:
		a_str_arr.append(_fa_digits(v))
	var d_str_arr: Array[String] = []
	for v in d_dices:
		d_str_arr.append(_fa_digits(v))

	if is_instance_valid(_dice_result_lbl_3d):
		_dice_result_lbl_3d.visible = true
		_dice_result_lbl_3d.text = "⚔️ [%s] در برابر 🛡️ [%s]" % ["-".join(a_str_arr), "-".join(d_str_arr)]

	var summary = "🎲 حمله [%s] مقابل دفاع [%s] ← تلفات مهاجم:%s | مدافع:%s" % [
		" ، ".join(a_str_arr),
		" ، ".join(d_str_arr),
		_fa_digits(a_losses),
		_fa_digits(d_losses)
	]
	if captured:
		summary += " (🏳️ فتح قاره!)"
	_set_battle_feed_text(summary)

func _hide_battle_dice() -> void:
	for d in _attacker_dice_nodes:
		if is_instance_valid(d):
			d.visible = false
	for d in _defender_dice_nodes:
		if is_instance_valid(d):
			d.visible = false
	if is_instance_valid(_dice_result_lbl_3d):
		_dice_result_lbl_3d.visible = false

func _get_my_continents_dict() -> Dictionary:
	var p0 = clampi(my_player_index - 1, 0, _all_continents.size() - 1)
	if p0 >= 0 and p0 < _all_continents.size() and typeof(_all_continents[p0]) == TYPE_DICTIONARY:
		return _all_continents[p0]
	return {}

func _get_my_owned_continents_list() -> Array[String]:
	var res: Array[String] = []
	var d = _get_my_continents_dict()
	for c in ALL_CONTINENTS:
		if int(d.get(c, 0)) > 0:
			res.append(c)
	return res

func _get_defenders_with_continent(cont: String) -> Array[int]:
	var res: Array[int] = []
	for p_i in range(_player_count):
		var p_num = p_i + 1
		if p_num == my_player_index:
			continue
		var d: Dictionary = _all_continents[p_i] if p_i < _all_continents.size() and typeof(_all_continents[p_i]) == TYPE_DICTIONARY else {}
		if int(d.get(cont, 0)) > 0:
			res.append(p_num)
	return res

func _get_player_name(p_idx: int) -> String:
	var p_data = GameManager.get_player_data_by_gamer_id(p_idx)
	var p_name = str(p_data.get("name", p_data.get("username", "")))
	if p_name.is_empty():
		return "بازیکن %s" % _fa_digits(p_idx)
	return p_name

func _format_draw_feed(user_idx: int, drawn_continents: Array, strat_count: int) -> String:
	var u_name = _get_player_name(user_idx)
	var parts: Array[String] = []
	for c in drawn_continents:
		parts.append("قاره «%s»" % CONTINENT_NAMES_FA.get(str(c), str(c)))
	if strat_count > 0:
		parts.append("%s کارت استراتژی" % _fa_digits(strat_count))
	if parts.is_empty():
		return "🎴 %s کارت کشید." % u_name
	return "🎴 %s دریافت کرد: %s" % [u_name, " + ".join(parts)]

func _set_battle_feed_text(msg: String) -> void:
	if is_instance_valid(_battle_feed_lbl):
		_battle_feed_lbl.text = msg

func show_hint(msg: String) -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("show_toast_hint"):
		hud.show_toast_hint(msg)

func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var en = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(en[i], fa[i])
	return s
