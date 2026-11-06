class_name Risk3D
extends BaseGameBoard

# ==============================================================================
# Risk Strike 3D ("ریسک استرایک" — Cafe Fekr Grand War-Room Edition)
# Supports 2, 3, or 4 Players (Lobby & Classic Rank)
# Faithful implementation of the official tabletop game Risk Strike:
# - 6 Sculpted 3D Continent Citadels on a Royal Walnut & Brass Naval War-Table
# - 3D Multi-Turret Fortresses, Rotating Golden Domination Crowns, & Faction Troops
# - 3D Center Battle Dice Arena (Up to 3 Crimson Attacker Dice vs 2 Sapphire Defender Dice)
# - Gamer-Friendly Persian Tactical Command Deck for Rally Draw, Strategy Cards,
#   Continent Attack Selection, Army Reinforcements, and Ceasefire (Cancel) Defense
# - Immediate Victory upon capturing 2 Continent Domination Tokens (👑 2/2)
# ==============================================================================

@export var camera_distance: float = 2.65
@export var camera_pitch: float = -0.86

const SURFACE_Y: float = 0.036
const FA_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const CONTINENT_ORDER: Array[String] = [
	"NorthAmerica",
	"Europe",
	"Asia",
	"SouthAmerica",
	"Africa",
	"Australia",
]

const CONTINENT_NAMES_FA: Dictionary = {
	"Asia": "آسیا",
	"NorthAmerica": "آمریکای شمالی",
	"Europe": "اروپا",
	"Africa": "آفریقا",
	"Australia": "استرالیا",
	"SouthAmerica": "آمریکای جنوبی",
}

const CONTINENT_SHORT_FA: Dictionary = {
	"Asia": "آسیا",
	"NorthAmerica": "آ.شمالی",
	"Europe": "اروپا",
	"Africa": "آفریقا",
	"Australia": "استرالیا",
	"SouthAmerica": "آ.جنوبی",
}

const CONTINENT_COLORS: Dictionary = {
	"NorthAmerica": Color(0.92, 0.68, 0.18), # Amber Gold
	"SouthAmerica": Color(0.88, 0.30, 0.25), # Coral Crimson
	"Europe": Color(0.24, 0.54, 0.94),       # Royal Cobalt
	"Africa": Color(0.84, 0.46, 0.18),       # Terracotta Bronze
	"Asia": Color(0.18, 0.76, 0.44),         # Emerald Jade
	"Australia": Color(0.68, 0.34, 0.88),    # Amethyst Purple
}

const CONTINENT_POSITIONS_3D: Dictionary = {
	"NorthAmerica": Vector3(-0.35, SURFACE_Y, -0.18),
	"SouthAmerica": Vector3(-0.30, SURFACE_Y,  0.19),
	"Europe":       Vector3(-0.01, SURFACE_Y, -0.22),
	"Africa":       Vector3( 0.01, SURFACE_Y,  0.17),
	"Asia":         Vector3( 0.33, SURFACE_Y, -0.17),
	"Australia":    Vector3( 0.35, SURFACE_Y,  0.20),
}

const CONTINENT_ADJACENCY: Dictionary = {
	"Asia": ["Asia", "Australia", "Europe", "Africa", "NorthAmerica"],
	"Australia": ["Australia", "Asia"],
	"Europe": ["Europe", "Asia", "NorthAmerica", "Africa"],
	"Africa": ["Africa", "Europe", "Asia", "SouthAmerica"],
	"NorthAmerica": ["NorthAmerica", "SouthAmerica", "Europe", "Asia"],
	"SouthAmerica": ["SouthAmerica", "NorthAmerica", "Africa"],
}

const STRATEGY_INFO: Dictionary = {
	"Army": {
		"name_fa": "سرباز کمکی",
		"icon": "⚔️",
		"desc": "افزودن ۱ تاس در نبرد یا دریافت ۱ کارت قاره در مرحله عملیات",
		"color": Color(0.88, 0.30, 0.26)
	},
	"Backup": {
		"name_fa": "پشتیبانی",
		"icon": "📦",
		"desc": "دریافت فوری ۲ کارت تاکتیک جدید از دسته کارت‌ها",
		"color": Color(0.22, 0.68, 0.95)
	},
	"Bomb": {
		"name_fa": "بمباران",
		"icon": "💣",
		"desc": "حذف تصادفی ۲ کارت تاکتیک از دست یکی از حریفان",
		"color": Color(0.92, 0.48, 0.16)
	},
	"Destroy": {
		"name_fa": "تخریب قاره",
		"icon": "💥",
		"desc": "حذف ۱ کارت قاره به انتخاب شما از یکی از حریفان",
		"color": Color(0.95, 0.24, 0.32)
	},
	"Cancel": {
		"name_fa": "آتش‌بس",
		"icon": "🕊️",
		"desc": "لغو فوری حمله اعلام‌شده علیه قاره شما (در زمان دفاع)",
		"color": Color(0.26, 0.85, 0.56)
	},
	"Canon": {
		"name_fa": "توپخانه",
		"icon": "🎯",
		"desc": "افزودن ۱+ واحد به بزرگ‌ترین تاس شما در نبرد",
		"color": Color(0.95, 0.78, 0.22)
	},
	"Expand": {
		"name_fa": "گسترش مرز",
		"icon": "🚀",
		"desc": "امکان حمله به هر قاره بدون محدودیت هم‌مرزی در این نوبت",
		"color": Color(0.72, 0.38, 0.96)
	},
	"Spy": {
		"name_fa": "جاسوس",
		"icon": "🕵️",
		"desc": "سرقت تصادفی ۱ کارت تاکتیک از دست یکی از حریفان",
		"color": Color(0.28, 0.82, 0.82)
	},
}

const FACTION_COLORS: Dictionary = {
	1: Color(0.94, 0.22, 0.26), # P1: Crimson Red
	2: Color(0.20, 0.56, 0.98), # P2: Sapphire Blue
	3: Color(0.18, 0.82, 0.40), # P3: Emerald Green
	4: Color(0.98, 0.78, 0.16), # P4: Imperial Gold
}

const FACTION_NAMES_FA: Dictionary = {
	1: "قرمز",
	2: "آبی",
	3: "سبز",
	4: "زرد",
}

const FACTION_DOTS: Dictionary = {
	1: "🔴",
	2: "🔵",
	3: "🟢",
	4: "🟡",
}

# Authoritative Match State
var players_count: int = 2
var active_player_indexes: Array = [1, 2]
var game_state_str: String = "StartGame"
var unowned_tokens: Array = ["Asia", "NorthAmerica", "Europe", "Africa", "Australia", "SouthAmerica"]
var remaining_continents_deck: int = 36
var remaining_strategies_deck: int = 31
var rank1_player: int = 0
var rank2_player: int = 0

# Public player states: gamer_id (1..4) -> {"continents": Dictionary, "strategies": int, "tokens": Array}
var players_public: Dictionary = {}

# Local player's private hand
var my_continents: Dictionary = {
	"Asia": 0,
	"NorthAmerica": 0,
	"Europe": 0,
	"Africa": 0,
	"Australia": 0,
	"SouthAmerica": 0,
}
var my_strategies: Array = [] # Array of strategy names (e.g. ["Army", "Backup"])
var my_tokens: Array = []

# Active Combat State
var active_attack: Dictionary = {} # {"attacker_id", "defender_id", "source_continent", "target_continent", "attacker_army", "defender_army"}
var selected_source_continent: String = ""
var selected_army_commit: int = 0
var ignore_adjacency_this_turn: bool = false
var attacked_this_turn: bool = false
var _action_cooldown_until: float = 0.0

# 3D Scene Nodes
var _board_root: Node3D = null
var _continents_root: Node3D = null
var _routes_root: Node3D = null
var _troops_root: Node3D = null
var _dice_root: Node3D = null
var _vfx_root: Node3D = null

var _continent_plateaus: Dictionary = {}       # c_name -> MeshInstance3D
var _continent_halo_rings: Dictionary = {}     # c_name -> MeshInstance3D
var _continent_crowns: Dictionary = {}         # c_name -> Node3D
var _continent_owner_badges: Dictionary = {}   # c_name -> Label3D
var _route_meshes: Array = []                  # Array of Dictionary {c1, c2, mesh, mat}
var _deck_continent_lbl: Label3D = null
var _deck_strategy_lbl: Label3D = null
var _attacker_dice_nodes: Array[Node3D] = []
var _defender_dice_nodes: Array[Node3D] = []
var _pulse_time: float = 0.0

# Shared 3D Materials
var _mat_wood_dark: StandardMaterial3D
var _mat_wood_trim: StandardMaterial3D
var _mat_ocean_slate: StandardMaterial3D
var _mat_brass_gold: StandardMaterial3D
var _mat_stone_citadel: StandardMaterial3D
var _mat_faction_enamel: Dictionary = {}
var _mat_die_attacker: StandardMaterial3D
var _mat_die_defender: StandardMaterial3D
var _mat_pip_light: StandardMaterial3D
var _mat_pip_gold: StandardMaterial3D

# 2D Tactical UI Nodes
var _ui_layer: CanvasLayer = null
var _ui_root: Control = null
var _top_continent_strip: HBoxContainer = null
var _continent_Strip_buttons: Dictionary = {}
var _battle_banner_panel: PanelContainer = null
var _battle_banner_lbl: Label = null
var _bottom_dock: PanelContainer = null
var _lbl_phase_status: Label = null
var _lbl_my_tokens: Label = null
var _phase_actions_row: HBoxContainer = null
var _my_continents_row: HBoxContainer = null
var _my_strategies_scroll: ScrollContainer = null
var _my_strategies_row: HBoxContainer = null
var _target_modal_overlay: Control = null
var _target_modal_title: Label = null
var _target_modal_list: VBoxContainer = null

# Pointer raycast tracking
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_is_down: bool = false
var _font_hekayat: Font = null

static func _fa_int(val: int) -> String:
	var s = str(abs(val))
	var out = ""
	for i in range(s.length()):
		var code = s.unicode_at(i) - 48
		if code >= 0 and code <= 9:
			out += FA_DIGITS[code]
		else:
			out += s[i]
	return out

func _ready() -> void:
	game_type = GameTypes.RISK
	_font_hekayat = preload("res://assets/fonts/hekayat.ttf")
	super._ready()

	if NetworkManager.has_signal("risk_event_received"):
		if not NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
			NetworkManager.risk_event_received.connect(_on_risk_event_received)
	if NetworkManager.has_signal("user_data_received"):
		if not NetworkManager.user_data_received.is_connected(_on_user_data_received):
			NetworkManager.user_data_received.connect(_on_user_data_received)

	_init_default_state(max(2, GameManager.match_players.size()))
	_init_materials()
	_build_war_table_3d()
	_build_adjacency_routes_3d()
	_build_continents_3d()
	_build_decks_and_dice_arena_3d()
	_build_tactical_ui()
	_refresh_all_visuals()

func _exit_tree() -> void:
	if NetworkManager.has_signal("risk_event_received"):
		if NetworkManager.risk_event_received.is_connected(_on_risk_event_received):
			NetworkManager.risk_event_received.disconnect(_on_risk_event_received)
	if NetworkManager.has_signal("user_data_received"):
		if NetworkManager.user_data_received.is_connected(_on_user_data_received):
			NetworkManager.user_data_received.disconnect(_on_user_data_received)
	if is_instance_valid(_ui_layer):
		_ui_layer.queue_free()
	super._exit_tree()

func _process(delta: float) -> void:
	_pulse_time += delta
	# Rotate floating Domination Crowns and pulse active continent halo rings
	for c_name in _continent_crowns.keys():
		var crown_node = _continent_crowns[c_name] as Node3D
		if is_instance_valid(crown_node):
			crown_node.rotation.y += delta * 1.15
			crown_node.position.y = 0.118 + sin(_pulse_time * 2.4 + float(c_name.hash() % 10)) * 0.005

	for c_name in _continent_halo_rings.keys():
		var ring = _continent_halo_rings[c_name] as MeshInstance3D
		if is_instance_valid(ring) and ring.visible:
			var s = 1.0 + 0.06 * sin(_pulse_time * 5.0)
			ring.scale = Vector3(s, 1.0, s)

func _init_default_state(p_count: int) -> void:
	players_count = clampi(p_count, 2, 4)
	active_player_indexes.clear()
	players_public.clear()
	for i in range(1, players_count + 1):
		active_player_indexes.append(i)
		players_public[i] = {
			"index": i,
			"continents": {
				"Asia": 0,
				"NorthAmerica": 0,
				"Europe": 0,
				"Africa": 0,
				"Australia": 0,
				"SouthAmerica": 0,
			},
			"strategies": 3 if i == 1 else 4,
			"tokens": [],
		}
	for c in CONTINENT_ORDER:
		my_continents[c] = 0
	my_strategies.clear()
	my_tokens.clear()
	active_attack.clear()
	selected_source_continent = ""
	selected_army_commit = 0
	ignore_adjacency_this_turn = false
	attacked_this_turn = false

func _init_materials() -> void:
	_mat_wood_dark = StandardMaterial3D.new()
	_mat_wood_dark.albedo_color = Color(0.16, 0.09, 0.05)
	_mat_wood_dark.roughness = 0.40
	_mat_wood_dark.metallic = 0.08

	_mat_wood_trim = StandardMaterial3D.new()
	_mat_wood_trim.albedo_color = Color(0.28, 0.16, 0.09)
	_mat_wood_trim.roughness = 0.34
	_mat_wood_trim.metallic = 0.12

	_mat_ocean_slate = StandardMaterial3D.new()
	_mat_ocean_slate.albedo_color = Color(0.05, 0.13, 0.21)
	_mat_ocean_slate.roughness = 0.72
	_mat_ocean_slate.metallic = 0.08

	_mat_brass_gold = StandardMaterial3D.new()
	_mat_brass_gold.albedo_color = Color(0.95, 0.79, 0.32)
	_mat_brass_gold.metallic = 0.82
	_mat_brass_gold.roughness = 0.22

	_mat_stone_citadel = StandardMaterial3D.new()
	_mat_stone_citadel.albedo_color = Color(0.76, 0.73, 0.67)
	_mat_stone_citadel.roughness = 0.55
	_mat_stone_citadel.metallic = 0.10

	for f_id in FACTION_COLORS.keys():
		var col: Color = FACTION_COLORS[f_id]
		var m_fac = StandardMaterial3D.new()
		m_fac.albedo_color = col
		m_fac.roughness = 0.22
		m_fac.metallic = 0.28
		m_fac.emission_enabled = true
		m_fac.emission = col * 0.22
		_mat_faction_enamel[f_id] = m_fac

	_mat_die_attacker = StandardMaterial3D.new()
	_mat_die_attacker.albedo_color = Color(0.86, 0.14, 0.18)
	_mat_die_attacker.roughness = 0.16
	_mat_die_attacker.metallic = 0.15

	_mat_die_defender = StandardMaterial3D.new()
	_mat_die_defender.albedo_color = Color(0.14, 0.44, 0.88)
	_mat_die_defender.roughness = 0.16
	_mat_die_defender.metallic = 0.15

	_mat_pip_light = StandardMaterial3D.new()
	_mat_pip_light.albedo_color = Color(0.98, 0.96, 0.90)
	_mat_pip_light.roughness = 0.12

	_mat_pip_gold = StandardMaterial3D.new()
	_mat_pip_gold.albedo_color = Color(1.0, 0.86, 0.32)
	_mat_pip_gold.metallic = 0.75
	_mat_pip_gold.roughness = 0.18

# ==============================================================================
# 3D WAR-TABLE, CONTINENT CITADELS, TROOPS & DICE ARENA
# ==============================================================================

func _build_war_table_3d() -> void:
	if is_instance_valid(_board_root):
		_board_root.queue_free()
	_board_root = Node3D.new()
	_board_root.name = "RiskWarTableRoot"
	add_child(_board_root)

	_routes_root = Node3D.new()
	_routes_root.name = "RoutesRoot"
	_board_root.add_child(_routes_root)

	_continents_root = Node3D.new()
	_continents_root.name = "ContinentsRoot"
	_board_root.add_child(_continents_root)

	_troops_root = Node3D.new()
	_troops_root.name = "TroopsRoot"
	_board_root.add_child(_troops_root)

	_dice_root = Node3D.new()
	_dice_root.name = "DiceRoot"
	_board_root.add_child(_dice_root)

	_vfx_root = Node3D.new()
	_vfx_root.name = "VFXRoot"
	_board_root.add_child(_vfx_root)

	# 1. Outer Royal Walnut Cabinet Base (1.28m x 0.96m)
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(1.28, 0.036, 0.96)
	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.material_override = _mat_wood_dark
	base_inst.position = Vector3(0.0, 0.018, 0.0)
	_board_root.add_child(base_inst)

	# 2. Ocean Slate Map Inlay
	var ocean_mesh = BoxMesh.new()
	ocean_mesh.size = Vector3(1.18, 0.006, 0.86)
	var ocean_inst = MeshInstance3D.new()
	ocean_inst.mesh = ocean_mesh
	ocean_inst.material_override = _mat_ocean_slate
	ocean_inst.position = Vector3(0.0, SURFACE_Y - 0.002, 0.0)
	_board_root.add_child(ocean_inst)

	# 3. Raised Walnut & Brass Bezel Frame Rails
	var rails = [
		{"pos": Vector3(0.0, SURFACE_Y + 0.008, -0.455), "size": Vector3(1.26, 0.022, 0.045)},
		{"pos": Vector3(0.0, SURFACE_Y + 0.008,  0.455), "size": Vector3(1.26, 0.022, 0.045)},
		{"pos": Vector3(-0.615, SURFACE_Y + 0.008, 0.0), "size": Vector3(0.045, 0.022, 0.95)},
		{"pos": Vector3( 0.615, SURFACE_Y + 0.008, 0.0), "size": Vector3(0.045, 0.022, 0.95)},
	]
	for r in rails:
		var rm = BoxMesh.new()
		rm.size = r["size"]
		var ri = MeshInstance3D.new()
		ri.mesh = rm
		ri.material_override = _mat_wood_trim
		ri.position = r["pos"]
		_board_root.add_child(ri)

		var bm = BoxMesh.new()
		bm.size = Vector3(r["size"].x * 0.98, 0.004, r["size"].z * 0.35)
		var bi = MeshInstance3D.new()
		bi.mesh = bm
		bi.material_override = _mat_brass_gold
		bi.position = r["pos"] + Vector3(0.0, 0.012, 0.0)
		_board_root.add_child(bi)

	# 4. Subtle Naval Map Grid Lines (Latitude & Longitude Brass Inlays)
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.22, 0.42, 0.58, 0.45)
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for gz in [-0.26, 0.0, 0.26]:
		var gm = BoxMesh.new()
		gm.size = Vector3(1.14, 0.001, 0.003)
		var gi = MeshInstance3D.new()
		gi.mesh = gm
		gi.material_override = grid_mat
		gi.position = Vector3(0.0, SURFACE_Y + 0.001, gz)
		_board_root.add_child(gi)
	for gx in [-0.36, 0.0, 0.36]:
		var gm2 = BoxMesh.new()
		gm2.size = Vector3(0.003, 0.001, 0.82)
		var gi2 = MeshInstance3D.new()
		gi2.mesh = gm2
		gi2.material_override = grid_mat
		gi2.position = Vector3(gx, SURFACE_Y + 0.001, 0.0)
		_board_root.add_child(gi2)

func _build_adjacency_routes_3d() -> void:
	_route_meshes.clear()
	var pairs_seen: Dictionary = {}
	for c1 in CONTINENT_ADJACENCY.keys():
		var neighbors: Array = CONTINENT_ADJACENCY[c1]
		for c2 in neighbors:
			if c1 == c2:
				continue
			var key = (c1 + "_" + c2) if c1 < c2 else (c2 + "_" + c1)
			if pairs_seen.has(key):
				continue
			pairs_seen[key] = true

			var p1: Vector3 = CONTINENT_POSITIONS_3D.get(c1, Vector3.ZERO)
			var p2: Vector3 = CONTINENT_POSITIONS_3D.get(c2, Vector3.ZERO)
			var diff = p2 - p1
			var dist = diff.length()
			var mid = (p1 + p2) * 0.5
			var angle = atan2(diff.x, diff.z)

			var r_mat = StandardMaterial3D.new()
			r_mat.albedo_color = Color(0.85, 0.72, 0.35, 0.65)
			r_mat.emission_enabled = true
			r_mat.emission = Color(0.85, 0.68, 0.24) * 0.35
			r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			var bridge_mesh = BoxMesh.new()
			bridge_mesh.size = Vector3(0.010, 0.002, max(0.04, dist - 0.18))
			var bridge_inst = MeshInstance3D.new()
			bridge_inst.mesh = bridge_mesh
			bridge_inst.material_override = r_mat
			bridge_inst.position = Vector3(mid.x, SURFACE_Y + 0.002, mid.z)
			bridge_inst.rotation.y = angle
			_routes_root.add_child(bridge_inst)

			_route_meshes.append({
				"c1": c1,
				"c2": c2,
				"mesh": bridge_inst,
				"mat": r_mat,
			})

	# Wrap-around Pacific Sea-Lane indicator (NorthAmerica <-> Asia)
	for side_x in [-0.52, 0.52]:
		var pac_mesh = CylinderMesh.new()
		pac_mesh.top_radius = 0.016
		pac_mesh.bottom_radius = 0.016
		pac_mesh.height = 0.004
		var pac_inst = MeshInstance3D.new()
		pac_inst.mesh = pac_mesh
		pac_inst.material_override = _mat_brass_gold
		pac_inst.position = Vector3(side_x, SURFACE_Y + 0.003, -0.18)
		_routes_root.add_child(pac_inst)

func _build_continents_3d() -> void:
	_continent_plateaus.clear()
	_continent_halo_rings.clear()
	_continent_crowns.clear()
	_continent_owner_badges.clear()

	for c_name in CONTINENT_ORDER:
		var pos: Vector3 = CONTINENT_POSITIONS_3D[c_name]
		var col: Color = CONTINENT_COLORS[c_name]

		var c_root = Node3D.new()
		c_root.name = "Continent_" + c_name
		c_root.position = pos
		_continents_root.add_child(c_root)

		# 1. Stepped Sculpted Continent Landmass Plateau
		var mat_land = StandardMaterial3D.new()
		mat_land.albedo_color = col.darkened(0.18)
		mat_land.roughness = 0.48
		mat_land.metallic = 0.12

		var mat_top = StandardMaterial3D.new()
		mat_top.albedo_color = col
		mat_top.roughness = 0.36
		mat_top.metallic = 0.15
		mat_top.emission_enabled = true
		mat_top.emission = col * 0.14

		var base_cyl = CylinderMesh.new()
		base_cyl.top_radius = 0.132
		base_cyl.bottom_radius = 0.146
		base_cyl.height = 0.018
		base_cyl.radial_segments = 8
		var base_inst = MeshInstance3D.new()
		base_inst.mesh = base_cyl
		base_inst.material_override = mat_land
		base_inst.position = Vector3(0.0, 0.009, 0.0)
		c_root.add_child(base_inst)

		var upper_cyl = CylinderMesh.new()
		upper_cyl.top_radius = 0.116
		upper_cyl.bottom_radius = 0.126
		upper_cyl.height = 0.014
		upper_cyl.radial_segments = 8
		var upper_inst = MeshInstance3D.new()
		upper_inst.mesh = upper_cyl
		upper_inst.material_override = mat_top
		upper_inst.position = Vector3(0.0, 0.024, 0.0)
		c_root.add_child(upper_inst)
		_continent_plateaus[c_name] = upper_inst

		# 2. Sculpted 3D Citadel Keep at the center of the continent
		var citadel = _create_3d_citadel_model(col)
		citadel.position = Vector3(0.0, 0.031, -0.012)
		c_root.add_child(citadel)

		# 3. Floating 3D Domination Crown Monument above the Citadel
		var crown = _create_3d_domination_crown()
		crown.position = Vector3(0.0, 0.118, -0.012)
		c_root.add_child(crown)
		_continent_crowns[c_name] = crown

		# 4. Interactive Selection / Target Halo Ring
		var halo_mat = StandardMaterial3D.new()
		halo_mat.albedo_color = Color(1.0, 0.90, 0.28, 0.92)
		halo_mat.emission_enabled = true
		halo_mat.emission = Color(1.0, 0.85, 0.20) * 1.8
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var torus = TorusMesh.new()
		torus.inner_radius = 0.138
		torus.outer_radius = 0.154
		torus.rings = 24
		torus.ring_segments = 12
		var halo_inst = MeshInstance3D.new()
		halo_inst.mesh = torus
		halo_inst.material_override = halo_mat
		halo_inst.position = Vector3(0.0, 0.006, 0.0)
		halo_inst.visible = false
		c_root.add_child(halo_inst)
		_continent_halo_rings[c_name] = halo_inst

		# 5. 3D Persian Continent Banner & Domination Status Label
		var lbl_name = Label3D.new()
		lbl_name.font = _font_hekayat
		lbl_name.text = CONTINENT_NAMES_FA.get(c_name, c_name)
		lbl_name.font_size = 42
		lbl_name.pixel_size = 0.0011
		lbl_name.modulate = Color(1.0, 0.97, 0.88)
		lbl_name.outline_modulate = Color(0.05, 0.03, 0.01, 0.98)
		lbl_name.outline_size = 10
		lbl_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl_name.no_depth_test = true
		lbl_name.position = Vector3(0.0, 0.165, 0.03)
		c_root.add_child(lbl_name)

		var lbl_owner = Label3D.new()
		lbl_owner.font = _font_hekayat
		lbl_owner.text = "👑 آزاد"
		lbl_owner.font_size = 32
		lbl_owner.pixel_size = 0.0010
		lbl_owner.modulate = Color(1.0, 0.88, 0.42)
		lbl_owner.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
		lbl_owner.outline_size = 8
		lbl_owner.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl_owner.no_depth_test = true
		lbl_owner.position = Vector3(0.0, 0.132, 0.03)
		c_root.add_child(lbl_owner)
		_continent_owner_badges[c_name] = lbl_owner

func _create_3d_citadel_model(accent_col: Color) -> Node3D:
	var root = Node3D.new()

	# Central Keep Tower
	var keep_mesh = BoxMesh.new()
	keep_mesh.size = Vector3(0.046, 0.042, 0.046)
	var keep_inst = MeshInstance3D.new()
	keep_inst.mesh = keep_mesh
	keep_inst.material_override = _mat_stone_citadel
	keep_inst.position = Vector3(0.0, 0.021, 0.0)
	root.add_child(keep_inst)

	# Keep Gold Roof Spire
	var roof_mesh = CylinderMesh.new()
	roof_mesh.top_radius = 0.002
	roof_mesh.bottom_radius = 0.032
	roof_mesh.height = 0.026
	roof_mesh.radial_segments = 4
	var roof_inst = MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = accent_col.darkened(0.1)
	roof_mat.metallic = 0.35
	roof_mat.roughness = 0.28
	roof_inst.material_override = roof_mat
	roof_inst.position = Vector3(0.0, 0.055, 0.0)
	roof_inst.rotation.y = PI * 0.25
	root.add_child(roof_inst)

	# 4 Corner Bastion Turrets
	var offsets = [
		Vector3(-0.026, 0.016, -0.026),
		Vector3( 0.026, 0.016, -0.026),
		Vector3(-0.026, 0.016,  0.026),
		Vector3( 0.026, 0.016,  0.026),
	]
	for off in offsets:
		var tur_mesh = CylinderMesh.new()
		tur_mesh.top_radius = 0.011
		tur_mesh.bottom_radius = 0.013
		tur_mesh.height = 0.032
		tur_mesh.radial_segments = 10
		var tur_inst = MeshInstance3D.new()
		tur_inst.mesh = tur_mesh
		tur_inst.material_override = _mat_stone_citadel
		tur_inst.position = off
		root.add_child(tur_inst)

		var cap_mesh = CylinderMesh.new()
		cap_mesh.top_radius = 0.013
		cap_mesh.bottom_radius = 0.012
		cap_mesh.height = 0.005
		cap_mesh.radial_segments = 10
		var cap_inst = MeshInstance3D.new()
		cap_inst.mesh = cap_mesh
		cap_inst.material_override = _mat_brass_gold
		cap_inst.position = off + Vector3(0.0, 0.018, 0.0)
		root.add_child(cap_inst)

	return root

func _create_3d_domination_crown() -> Node3D:
	var crown_root = Node3D.new()
	var crown_mat = _mat_brass_gold.duplicate() as StandardMaterial3D
	crown_mat.emission_enabled = true
	crown_mat.emission = Color(1.0, 0.82, 0.24) * 0.35
	crown_root.set_meta("crown_mat", crown_mat)

	var band_mesh = TorusMesh.new()
	band_mesh.inner_radius = 0.015
	band_mesh.outer_radius = 0.021
	band_mesh.rings = 16
	band_mesh.ring_segments = 10
	var band_inst = MeshInstance3D.new()
	band_inst.mesh = band_mesh
	band_inst.material_override = crown_mat
	crown_root.add_child(band_inst)

	for i in range(6):
		var ang = float(i) * TAU / 6.0
		var spike = CylinderMesh.new()
		spike.top_radius = 0.0015
		spike.bottom_radius = 0.005
		spike.height = 0.016
		var sp_inst = MeshInstance3D.new()
		sp_inst.mesh = spike
		sp_inst.material_override = crown_mat
		sp_inst.position = Vector3(cos(ang) * 0.017, 0.009, sin(ang) * 0.017)
		crown_root.add_child(sp_inst)

	return crown_root

func _build_decks_and_dice_arena_3d() -> void:
	# 1. Left Table Stack: Continent Deck
	var c_deck_pos = Vector3(-0.54, SURFACE_Y + 0.012, 0.0)
	var c_deck_mesh = BoxMesh.new()
	c_deck_mesh.size = Vector3(0.068, 0.024, 0.096)
	var c_deck_inst = MeshInstance3D.new()
	c_deck_inst.mesh = c_deck_mesh
	var c_deck_mat = StandardMaterial3D.new()
	c_deck_mat.albedo_color = Color(0.16, 0.48, 0.34)
	c_deck_mat.roughness = 0.32
	c_deck_inst.material_override = c_deck_mat
	c_deck_inst.position = c_deck_pos
	_board_root.add_child(c_deck_inst)

	_deck_continent_lbl = Label3D.new()
	_deck_continent_lbl.font = _font_hekayat
	_deck_continent_lbl.text = "🗺️ ۳۶"
	_deck_continent_lbl.font_size = 32
	_deck_continent_lbl.pixel_size = 0.0010
	_deck_continent_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_deck_continent_lbl.no_depth_test = true
	_deck_continent_lbl.position = c_deck_pos + Vector3(0.0, 0.045, 0.0)
	_board_root.add_child(_deck_continent_lbl)

	# 2. Right Table Stack: Strategy / Tactic Deck
	var s_deck_pos = Vector3(0.54, SURFACE_Y + 0.012, 0.0)
	var s_deck_mesh = BoxMesh.new()
	s_deck_mesh.size = Vector3(0.068, 0.024, 0.096)
	var s_deck_inst = MeshInstance3D.new()
	s_deck_inst.mesh = s_deck_mesh
	var s_deck_mat = StandardMaterial3D.new()
	s_deck_mat.albedo_color = Color(0.56, 0.16, 0.22)
	s_deck_mat.roughness = 0.32
	s_deck_inst.material_override = s_deck_mat
	s_deck_inst.position = s_deck_pos
	_board_root.add_child(s_deck_inst)

	_deck_strategy_lbl = Label3D.new()
	_deck_strategy_lbl.font = _font_hekayat
	_deck_strategy_lbl.text = "🃏 ۳۱"
	_deck_strategy_lbl.font_size = 32
	_deck_strategy_lbl.pixel_size = 0.0010
	_deck_strategy_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_deck_strategy_lbl.no_depth_test = true
	_deck_strategy_lbl.position = s_deck_pos + Vector3(0.0, 0.045, 0.0)
	_board_root.add_child(_deck_strategy_lbl)

	# 3. Center Brass Compass Battle Ring
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.095
	ring_mesh.outer_radius = 0.106
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 12
	var ring_inst = MeshInstance3D.new()
	ring_inst.mesh = ring_mesh
	ring_inst.material_override = _mat_brass_gold
	ring_inst.position = Vector3(0.0, SURFACE_Y + 0.003, -0.01)
	_board_root.add_child(ring_inst)

func _create_3d_battle_die(is_attacker: bool, value: int) -> Node3D:
	var die_root = Node3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.042, 0.042, 0.042)
	var inst = MeshInstance3D.new()
	inst.mesh = box
	inst.material_override = _mat_die_attacker if is_attacker else _mat_die_defender
	die_root.add_child(inst)

	# Top face pips showing rolled value (1..6+)
	var lbl = Label3D.new()
	lbl.font = _font_hekayat
	lbl.text = _fa_int(clampi(value, 1, 9))
	lbl.font_size = 44
	lbl.pixel_size = 0.0010
	lbl.modulate = Color(1.0, 0.96, 0.84)
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	lbl.outline_size = 8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 0.036, 0.0)
	die_root.add_child(lbl)
	return die_root

func _animate_3d_battle_dice(atk_dice: Array, def_dice: Array) -> void:
	for child in _dice_root.get_children():
		child.queue_free()
	_attacker_dice_nodes.clear()
	_defender_dice_nodes.clear()

	AudioManager.play_sound("dice")

	for i in range(atk_dice.size()):
		var val = int(atk_dice[i])
		var d_node = _create_3d_battle_die(true, val)
		var target_pos = Vector3(-0.048, SURFACE_Y + 0.025, -0.055 + float(i) * 0.052)
		d_node.position = target_pos + Vector3(-0.12, 0.16, 0.0)
		d_node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		_dice_root.add_child(d_node)
		_attacker_dice_nodes.append(d_node)

		var tw = create_tween().set_parallel(true)
		tw.tween_property(d_node, "position", target_pos, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(d_node, "rotation", Vector3.ZERO, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for j in range(def_dice.size()):
		var val_d = int(def_dice[j])
		var d_node2 = _create_3d_battle_die(false, val_d)
		var target_pos2 = Vector3(0.048, SURFACE_Y + 0.025, -0.030 + float(j) * 0.052)
		d_node2.position = target_pos2 + Vector3(0.12, 0.16, 0.0)
		d_node2.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		_dice_root.add_child(d_node2)
		_defender_dice_nodes.append(d_node2)

		var tw2 = create_tween().set_parallel(true)
		tw2.tween_property(d_node2, "position", target_pos2, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw2.tween_property(d_node2, "rotation", Vector3.ZERO, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _rebuild_continent_troops_3d() -> void:
	if not is_instance_valid(_troops_root):
		return
	for child in _troops_root.get_children():
		child.queue_free()

	# Garrison slot offsets around each continent plateau for Players 1..4
	var slot_offsets = {
		1: Vector3(-0.072, 0.032,  0.056),
		2: Vector3( 0.072, 0.032,  0.056),
		3: Vector3(-0.078, 0.032, -0.048),
		4: Vector3( 0.078, 0.032, -0.048),
	}

	var knight_mesh: Mesh = null
	if ResourceLoader.exists("res://assets/models/chess/knight.obj"):
		knight_mesh = load("res://assets/models/chess/knight.obj") as Mesh

	for c_name in CONTINENT_ORDER:
		var c_pos: Vector3 = CONTINENT_POSITIONS_3D[c_name]
		for pid in range(1, players_count + 1):
			var cnt: int = _get_player_continent_count(pid, c_name)
			if cnt <= 0:
				continue
			var g_pos = c_pos + slot_offsets.get(pid, Vector3.ZERO)
			var troop_node = Node3D.new()
			troop_node.position = g_pos
			_troops_root.add_child(troop_node)

			var f_mat: StandardMaterial3D = _mat_faction_enamel.get(pid, _mat_brass_gold)

			# Pedestal base
			var ped = CylinderMesh.new()
			ped.top_radius = 0.022
			ped.bottom_radius = 0.025
			ped.height = 0.008
			var ped_inst = MeshInstance3D.new()
			ped_inst.mesh = ped
			ped_inst.material_override = _mat_brass_gold
			ped_inst.position = Vector3(0.0, 0.004, 0.0)
			troop_node.add_child(ped_inst)

			if cnt >= 3:
				# Sculpted 3D Artillery Cannon for strongholds (3+ Continent cards)
				var carriage = BoxMesh.new()
				carriage.size = Vector3(0.024, 0.014, 0.032)
				var car_inst = MeshInstance3D.new()
				car_inst.mesh = carriage
				car_inst.material_override = f_mat
				car_inst.position = Vector3(0.0, 0.015, 0.0)
				troop_node.add_child(car_inst)

				var barrel = CylinderMesh.new()
				barrel.top_radius = 0.006
				barrel.bottom_radius = 0.009
				barrel.height = 0.038
				var bar_inst = MeshInstance3D.new()
				bar_inst.mesh = barrel
				bar_inst.material_override = _mat_brass_gold
				bar_inst.position = Vector3(0.0, 0.024, 0.008)
				bar_inst.rotation.x = deg_to_rad(62.0)
				troop_node.add_child(bar_inst)
			elif knight_mesh != null:
				# Use genuine 3D Staunton Cavalry horse miniature scaled for war-table
				var kn_inst = MeshInstance3D.new()
				kn_inst.mesh = knight_mesh
				kn_inst.material_override = f_mat
				kn_inst.scale = Vector3(0.32, 0.32, 0.32)
				kn_inst.position = Vector3(0.0, 0.008, 0.0)
				troop_node.add_child(kn_inst)
			else:
				var body = CylinderMesh.new()
				body.top_radius = 0.010
				body.bottom_radius = 0.015
				body.height = 0.028
				var b_inst = MeshInstance3D.new()
				b_inst.mesh = body
				b_inst.material_override = f_mat
				b_inst.position = Vector3(0.0, 0.022, 0.0)
				troop_node.add_child(b_inst)

			# Floating Faction Count Badge (e.g. "🔴۲")
			var lbl = Label3D.new()
			lbl.font = _font_hekayat
			lbl.text = "%s%s" % [FACTION_DOTS.get(pid, ""), _fa_int(cnt)]
			lbl.font_size = 34
			lbl.pixel_size = 0.00095
			lbl.modulate = FACTION_COLORS.get(pid, Color.WHITE).lightened(0.30)
			lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.98)
			lbl.outline_size = 8
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.position = Vector3(0.0, 0.056, 0.0)
			troop_node.add_child(lbl)

# ==============================================================================
# 2D GAMER-FRIENDLY TACTICAL COMMAND UI (PORTRAIT 1080x1920)
# ==============================================================================

func _build_tactical_ui() -> void:
	if is_instance_valid(_ui_layer):
		_ui_layer.queue_free()

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "RiskTacticalUILayer"
	_ui_layer.layer = 15
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.name = "RiskUIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_ui_root)

	# 1. Top Continent Domination Bar (below RiskTopHeader)
	var top_bar_panel = PanelContainer.new()
	top_bar_panel.anchor_left = 0.02
	top_bar_panel.anchor_right = 0.98
	top_bar_panel.anchor_top = 0.0
	top_bar_panel.anchor_bottom = 0.0
	top_bar_panel.offset_top = 292.0
	top_bar_panel.offset_bottom = 382.0
	top_bar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var st_top = StyleBoxFlat.new()
	st_top.bg_color = Color(0.10, 0.07, 0.04, 0.92)
	st_top.border_color = Color(0.82, 0.66, 0.32, 0.85)
	st_top.set_border_width_all(2)
	st_top.set_corner_radius_all(14)
	st_top.content_margin_left = 8
	st_top.content_margin_right = 8
	st_top.content_margin_top = 6
	st_top.content_margin_bottom = 6
	top_bar_panel.add_theme_stylebox_override("panel", st_top)
	_ui_root.add_child(top_bar_panel)

	_top_continent_strip = HBoxContainer.new()
	_top_continent_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_continent_strip.add_theme_constant_override("separation", 6)
	top_bar_panel.add_child(_top_continent_strip)

	_continent_Strip_buttons.clear()
	for c_name in CONTINENT_ORDER:
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 74)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _font_hekayat)
		btn.add_theme_font_size_override("font_size", 20)
		var c_key = c_name
		btn.pressed.connect(func(): _on_continent_clicked(c_key))
		_top_continent_strip.add_child(btn)
		_continent_Strip_buttons[c_name] = btn

	# 2. Battle & Event Notification Banner (below Top Continent Strip)
	_battle_banner_panel = PanelContainer.new()
	_battle_banner_panel.anchor_left = 0.05
	_battle_banner_panel.anchor_right = 0.95
	_battle_banner_panel.anchor_top = 0.0
	_battle_banner_panel.anchor_bottom = 0.0
	_battle_banner_panel.offset_top = 392.0
	_battle_banner_panel.offset_bottom = 456.0
	_battle_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_ban = StyleBoxFlat.new()
	st_ban.bg_color = Color(0.14, 0.09, 0.05, 0.94)
	st_ban.border_color = Color(0.95, 0.78, 0.30, 0.90)
	st_ban.set_border_width_all(2)
	st_ban.set_corner_radius_all(12)
	st_ban.content_margin_left = 14
	st_ban.content_margin_right = 14
	st_ban.content_margin_top = 6
	st_ban.content_margin_bottom = 6
	_battle_banner_panel.add_theme_stylebox_override("panel", st_ban)
	_ui_root.add_child(_battle_banner_panel)

	_battle_banner_lbl = Label.new()
	_battle_banner_lbl.add_theme_font_override("font", _font_hekayat)
	_battle_banner_lbl.add_theme_font_size_override("font_size", 24)
	_battle_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	_battle_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_battle_banner_lbl.text = "⚔️ هدف بازی: کسب ۲ نشان سلطه قاره‌ها (👑 ۲/۲)"
	_battle_banner_panel.add_child(_battle_banner_lbl)

	# 3. Bottom Tactical Command Dock (Docked cleanly above BaseGameHUD's bottom bar)
	_bottom_dock = PanelContainer.new()
	_bottom_dock.anchor_left = 0.015
	_bottom_dock.anchor_right = 0.985
	_bottom_dock.anchor_top = 1.0
	_bottom_dock.anchor_bottom = 1.0
	_bottom_dock.offset_top = -540.0
	_bottom_dock.offset_bottom = -136.0
	_bottom_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var st_dock = StyleBoxFlat.new()
	st_dock.bg_color = Color(0.11, 0.07, 0.04, 0.96)
	st_dock.border_color = Color(0.88, 0.72, 0.34, 0.95)
	st_dock.set_border_width_all(3)
	st_dock.set_corner_radius_all(20)
	st_dock.shadow_color = Color(0, 0, 0, 0.65)
	st_dock.shadow_size = 10
	st_dock.content_margin_left = 14
	st_dock.content_margin_right = 14
	st_dock.content_margin_top = 10
	st_dock.content_margin_bottom = 10
	_bottom_dock.add_theme_stylebox_override("panel", st_dock)
	_ui_root.add_child(_bottom_dock)

	var dock_vbox = VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 8)
	_bottom_dock.add_child(dock_vbox)

	# Row A: Status & My Domination Tokens Header
	var status_hbox = HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 12)
	dock_vbox.add_child(status_hbox)

	_lbl_my_tokens = Label.new()
	_lbl_my_tokens.add_theme_font_override("font", _font_hekayat)
	_lbl_my_tokens.add_theme_font_size_override("font_size", 24)
	_lbl_my_tokens.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_lbl_my_tokens.text = "👑 نشان‌های شما: ۰/۲"
	status_hbox.add_child(_lbl_my_tokens)

	_lbl_phase_status = Label.new()
	_lbl_phase_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_phase_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_phase_status.add_theme_font_override("font", _font_hekayat)
	_lbl_phase_status.add_theme_font_size_override("font_size", 25)
	_lbl_phase_status.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_lbl_phase_status.text = "در انتظار شروع نوبت..."
	status_hbox.add_child(_lbl_phase_status)

	# Row B: Context-Sensitive Phase Action Buttons (Draw / Attack / Army Commit / Defense)
	var action_panel = PanelContainer.new()
	action_panel.custom_minimum_size = Vector2(0, 88)
	var st_act = StyleBoxFlat.new()
	st_act.bg_color = Color(0.16, 0.11, 0.07, 0.95)
	st_act.border_color = Color(0.65, 0.50, 0.25, 0.70)
	st_act.set_border_width_all(1)
	st_act.set_corner_radius_all(14)
	st_act.content_margin_left = 10
	st_act.content_margin_right = 10
	st_act.content_margin_top = 6
	st_act.content_margin_bottom = 6
	action_panel.add_theme_stylebox_override("panel", st_act)
	dock_vbox.add_child(action_panel)

	var action_scroll = ScrollContainer.new()
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_panel.add_child(action_scroll)

	_phase_actions_row = HBoxContainer.new()
	_phase_actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phase_actions_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phase_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_actions_row.add_theme_constant_override("separation", 10)
	action_scroll.add_child(_phase_actions_row)

	# Row C: My Continent Cards (Tap to select Attack Source)
	var lbl_my_c = Label.new()
	lbl_my_c.add_theme_font_override("font", _font_hekayat)
	lbl_my_c.add_theme_font_size_override("font_size", 20)
	lbl_my_c.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	lbl_my_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_my_c.text = "🗺️ کارت‌های قاره شما (برای حمله لمس کنید):"
	dock_vbox.add_child(lbl_my_c)

	_my_continents_row = HBoxContainer.new()
	_my_continents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_continents_row.add_theme_constant_override("separation", 6)
	dock_vbox.add_child(_my_continents_row)

	# Row D: My Strategy / Tactic Cards Hand
	var lbl_my_s = Label.new()
	lbl_my_s.add_theme_font_override("font", _font_hekayat)
	lbl_my_s.add_theme_font_size_override("font_size", 20)
	lbl_my_s.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	lbl_my_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_my_s.text = "🃏 کارت‌های تاکتیکی دست شما (برای استفاده لمس کنید):"
	dock_vbox.add_child(lbl_my_s)

	_my_strategies_scroll = ScrollContainer.new()
	_my_strategies_scroll.custom_minimum_size = Vector2(0, 92)
	_my_strategies_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_my_strategies_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dock_vbox.add_child(_my_strategies_scroll)

	_my_strategies_row = HBoxContainer.new()
	_my_strategies_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_strategies_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_strategies_row.add_theme_constant_override("separation", 8)
	_my_strategies_scroll.add_child(_my_strategies_row)

	# 4. Target Selection Modal Overlay (for Destroy / Bomb / Spy)
	_build_target_selection_modal()

func _build_target_selection_modal() -> void:
	_target_modal_overlay = Control.new()
	_target_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_modal_overlay.visible = false
	_ui_root.add_child(_target_modal_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.02, 0.01, 0.78)
	_target_modal_overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_modal_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 460)
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.98)
	st.border_color = Color(0.95, 0.78, 0.32, 0.98)
	st.set_border_width_all(3)
	st.set_corner_radius_all(22)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 20
	st.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_target_modal_title = Label.new()
	_target_modal_title.add_theme_font_override("font", _font_hekayat)
	_target_modal_title.add_theme_font_size_override("font_size", 32)
	_target_modal_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	_target_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_target_modal_title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 290)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_target_modal_list = VBoxContainer.new()
	_target_modal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_modal_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_target_modal_list)

	var btn_cancel = Button.new()
	btn_cancel.text = "انصراف"
	btn_cancel.custom_minimum_size = Vector2(220, 64)
	btn_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_cancel.add_theme_font_override("font", _font_hekayat)
	btn_cancel.add_theme_font_size_override("font_size", 26)
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_RED)
	btn_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		_target_modal_overlay.visible = false
	)
	vbox.add_child(btn_cancel)

# ==============================================================================
# STATE HELPERS & UI REFRESH
# ==============================================================================

func _get_player_continent_count(gamer_id: int, c_name: String) -> int:
	if gamer_id == GameManager.my_player_index and my_continents.has(c_name):
		return int(my_continents.get(c_name, 0))
	if players_public.has(gamer_id):
		var c_dict = players_public[gamer_id].get("continents", {})
		if typeof(c_dict) == TYPE_DICTIONARY:
			return int(c_dict.get(c_name, 0))
	return 0

func _get_player_total_continents(gamer_id: int) -> int:
	var total: int = 0
	for c_name in CONTINENT_ORDER:
		total += _get_player_continent_count(gamer_id, c_name)
	return total

func _get_player_strategy_count(gamer_id: int) -> int:
	if gamer_id == GameManager.my_player_index:
		return my_strategies.size()
	if players_public.has(gamer_id):
		var s_val = players_public[gamer_id].get("strategies", 0)
		if typeof(s_val) == TYPE_ARRAY:
			return (s_val as Array).size()
		return int(s_val)
	return 0

func _get_player_tokens(gamer_id: int) -> Array:
	if players_public.has(gamer_id):
		var t_arr = players_public[gamer_id].get("tokens", [])
		if typeof(t_arr) == TYPE_ARRAY:
			return t_arr
	if gamer_id == GameManager.my_player_index:
		return my_tokens
	return []

func _find_continent_token_owner(c_name: String) -> int:
	for pid in range(1, players_count + 1):
		var t_arr = _get_player_tokens(pid)
		if t_arr.has(c_name):
			return pid
	return 0

func _count_my_strategy(strat_name: String) -> int:
	var cnt: int = 0
	for s in my_strategies:
		if str(s) == strat_name:
			cnt += 1
	return cnt

func _are_continents_adjacent(c1: String, c2: String) -> bool:
	if ignore_adjacency_this_turn:
		return true
	var adj: Array = CONTINENT_ADJACENCY.get(c1, [])
	return adj.has(c2)

func _get_player_display_name(gamer_id: int) -> String:
	var p_data = GameManager.get_player_data_by_gamer_id(gamer_id)
	var nm = str(p_data.get("name", p_data.get("username", "")))
	if nm.is_empty():
		return "بازیکن %s" % _fa_int(gamer_id)
	return nm

func _style_tactical_button(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb_n = StyleBoxFlat.new()
	sb_n.bg_color = bg_col
	sb_n.border_color = border_col
	sb_n.set_border_width_all(2)
	sb_n.set_corner_radius_all(12)
	sb_n.content_margin_left = 12
	sb_n.content_margin_right = 12
	sb_n.content_margin_top = 6
	sb_n.content_margin_bottom = 6

	var sb_h = sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg_col.lightened(0.14)
	sb_h.border_color = border_col.lightened(0.20)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_stylebox_override("focus", sb_n)
	btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))

func _refresh_all_visuals() -> void:
	_rebuild_continent_troops_3d()
	_refresh_3d_continents_and_routes()
	_refresh_top_continent_strip()
	_refresh_my_continents_bar()
	_refresh_my_strategies_bar()
	_refresh_phase_actions_bar()
	_sync_top_header_stats()

func _refresh_3d_continents_and_routes() -> void:
	if is_instance_valid(_deck_continent_lbl):
		_deck_continent_lbl.text = "🗺️ %s" % _fa_int(remaining_continents_deck)
	if is_instance_valid(_deck_strategy_lbl):
		_deck_strategy_lbl.text = "🃏 %s" % _fa_int(remaining_strategies_deck)

	for c_name in CONTINENT_ORDER:
		var owner_id = _find_continent_token_owner(c_name)
		var lbl_owner = _continent_owner_badges.get(c_name, null) as Label3D
		var crown_node = _continent_crowns.get(c_name, null) as Node3D
		if is_instance_valid(lbl_owner):
			if owner_id > 0:
				var o_tag = "شما" if owner_id == GameManager.my_player_index else ("ب" + _fa_int(owner_id))
				lbl_owner.text = "👑 %s %s" % [FACTION_DOTS.get(owner_id, ""), o_tag]
				lbl_owner.modulate = FACTION_COLORS.get(owner_id, Color.GOLD).lightened(0.25)
			else:
				lbl_owner.text = "👑 آزاد"
				lbl_owner.modulate = Color(0.95, 0.86, 0.55, 0.85)

		if is_instance_valid(crown_node) and crown_node.has_meta("crown_mat"):
			var c_mat = crown_node.get_meta("crown_mat") as StandardMaterial3D
			if owner_id > 0:
				var f_col: Color = FACTION_COLORS.get(owner_id, Color.GOLD)
				c_mat.albedo_color = f_col.lightened(0.15)
				c_mat.emission = f_col * 0.65
			else:
				c_mat.albedo_color = Color(0.95, 0.79, 0.32)
				c_mat.emission = Color(1.0, 0.82, 0.24) * 0.25

		var halo = _continent_halo_rings.get(c_name, null) as MeshInstance3D
		if is_instance_valid(halo):
			var is_src = (selected_source_continent == c_name)
			var is_atk_tgt = (str(active_attack.get("target_continent", "")) == c_name)
			var is_valid_tgt = false
			if not selected_source_continent.is_empty() and _are_continents_adjacent(selected_source_continent, c_name):
				for pid in active_player_indexes:
					if int(pid) != GameManager.my_player_index and _get_player_continent_count(int(pid), c_name) > 0:
						is_valid_tgt = true
						break
			halo.visible = is_src or is_atk_tgt or is_valid_tgt
			var h_mat = halo.material_override as StandardMaterial3D
			if h_mat:
				if is_src:
					h_mat.albedo_color = Color(0.25, 0.98, 0.55, 0.95)
					h_mat.emission = Color(0.20, 0.95, 0.45) * 1.8
				elif is_atk_tgt or is_valid_tgt:
					h_mat.albedo_color = Color(1.0, 0.32, 0.28, 0.95)
					h_mat.emission = Color(1.0, 0.25, 0.20) * 1.8

	for route in _route_meshes:
		var r_mat = route["mat"] as StandardMaterial3D
		var c1 = str(route["c1"])
		var c2 = str(route["c2"])
		if not selected_source_continent.is_empty() and (c1 == selected_source_continent or c2 == selected_source_continent):
			r_mat.albedo_color = Color(1.0, 0.88, 0.28, 0.95)
			r_mat.emission = Color(1.0, 0.78, 0.18) * 1.2
		else:
			r_mat.albedo_color = Color(0.85, 0.72, 0.35, 0.55)
			r_mat.emission = Color(0.85, 0.68, 0.24) * 0.28

func _refresh_top_continent_strip() -> void:
	for c_name in CONTINENT_ORDER:
		var btn = _continent_Strip_buttons.get(c_name, null) as Button
		if not is_instance_valid(btn):
			continue
		var owner_id = _find_continent_token_owner(c_name)
		var crown_str = "👑%s" % FACTION_DOTS.get(owner_id, "") if owner_id > 0 else "⚪"
		var counts_parts: Array[String] = []
		for pid in range(1, players_count + 1):
			var cnt = _get_player_continent_count(pid, c_name)
			if cnt > 0:
				counts_parts.append("%s%s" % [FACTION_DOTS.get(pid, ""), _fa_int(cnt)])
		var counts_str = " ".join(counts_parts) if not counts_parts.is_empty() else "خالی"
		btn.text = "%s %s\n%s" % [crown_str, CONTINENT_SHORT_FA.get(c_name, c_name), counts_str]

		var c_col: Color = CONTINENT_COLORS.get(c_name, Color.GRAY)
		var is_sel = (selected_source_continent == c_name)
		var bg = c_col.darkened(0.55) if is_sel else Color(0.16, 0.11, 0.08, 0.94)
		var brd = Color(0.30, 1.0, 0.55) if is_sel else c_col.lightened(0.15)
		_style_tactical_button(btn, bg, brd)

func _refresh_my_continents_bar() -> void:
	if not is_instance_valid(_my_continents_row):
		return
	for child in _my_continents_row.get_children():
		child.queue_free()

	var my_idx = GameManager.my_player_index
	var can_select_source = (current_turn == my_idx and game_state_str in ["SelectAction", "DrawResult", "ActionResult"])

	for c_name in CONTINENT_ORDER:
		var cnt = _get_player_continent_count(my_idx, c_name)
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 66)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _font_hekayat)
		btn.add_theme_font_size_override("font_size", 21)

		var has_tok = _find_continent_token_owner(c_name) == my_idx
		var tok_prefix = "👑 " if has_tok else ""
		btn.text = "%s%s\n×%s" % [tok_prefix, CONTINENT_SHORT_FA.get(c_name, c_name), _fa_int(cnt)]

		var c_col: Color = CONTINENT_COLORS.get(c_name, Color.GRAY)
		var is_sel = (selected_source_continent == c_name)
		if is_sel:
			_style_tactical_button(btn, Color(0.12, 0.48, 0.24), Color(0.35, 1.0, 0.55))
		elif cnt > 0:
			_style_tactical_button(btn, c_col.darkened(0.62), c_col.lightened(0.18))
		else:
			_style_tactical_button(btn, Color(0.14, 0.10, 0.08, 0.65), Color(0.38, 0.30, 0.22, 0.45))
			btn.modulate = Color(0.72, 0.70, 0.68, 0.78)

		var c_key = c_name
		btn.pressed.connect(func():
			if cnt <= 0:
				AudioManager.sfx_tap()
				show_hint("شما در قاره %s کارتی ندارید!" % CONTINENT_NAMES_FA.get(c_key, c_key))
				return
			if not can_select_source:
				AudioManager.sfx_tap()
				return
			AudioManager.sfx_tap()
			if selected_source_continent == c_key:
				selected_source_continent = ""
			else:
				selected_source_continent = c_key
			_refresh_all_visuals()
		)
		_my_continents_row.add_child(btn)

func _refresh_my_strategies_bar() -> void:
	if not is_instance_valid(_my_strategies_row):
		return
	for child in _my_strategies_row.get_children():
		child.queue_free()

	# Group strategy cards by type with counts for a clean, scannable hand
	var counts_by_type: Dictionary = {}
	for s in my_strategies:
		var s_name = str(s)
		counts_by_type[s_name] = int(counts_by_type.get(s_name, 0)) + 1

	if counts_by_type.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.add_theme_font_override("font", _font_hekayat)
		empty_lbl.add_theme_font_size_override("font_size", 22)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
		empty_lbl.text = "کارت تاکتیکی در دست ندارید"
		_my_strategies_row.add_child(empty_lbl)
		return

	for s_name in counts_by_type.keys():
		var cnt: int = int(counts_by_type[s_name])
		var info: Dictionary = STRATEGY_INFO.get(s_name, {"name_fa": s_name, "icon": "🃏", "desc": "", "color": Color(0.8, 0.6, 0.3)})
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(185, 80)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _font_hekayat)
		btn.add_theme_font_size_override("font_size", 21)
		btn.tooltip_text = str(info.get("desc", ""))
		btn.text = "%s %s (×%s)\n%s" % [
			str(info.get("icon", "🃏")),
			str(info.get("name_fa", s_name)),
			_fa_int(cnt),
			_short_strategy_hint(s_name)
		]
		var col: Color = info.get("color", Color(0.8, 0.6, 0.3))
		_style_tactical_button(btn, col.darkened(0.64), col.lightened(0.18))
		var strat_key = s_name
		btn.pressed.connect(func(): _on_strategy_card_clicked(strat_key))
		_my_strategies_row.add_child(btn)

func _short_strategy_hint(s_name: String) -> String:
	match s_name:
		"Army": return "+۱ تاس / +۱ قاره"
		"Backup": return "+۲ کارت تاکتیک"
		"Bomb": return "حذف ۲ تاکتیک حریف"
		"Destroy": return "حذف ۱ قاره حریف"
		"Cancel": return "لغو فوری حمله"
		"Canon": return "+۱ به تاس بزرگ"
		"Expand": return "حمله بدون مرز"
		"Spy": return "سرقت ۱ تاکتیک"
		_: return ""

func _refresh_phase_actions_bar() -> void:
	if not is_instance_valid(_phase_actions_row):
		return
	for child in _phase_actions_row.get_children():
		child.queue_free()

	var my_idx = GameManager.my_player_index
	var my_tok_cnt = _get_player_tokens(my_idx).size()
	if is_instance_valid(_lbl_my_tokens):
		_lbl_my_tokens.text = "👑 نشان‌های سلطه شما: %s/۲" % _fa_int(my_tok_cnt)

	var is_my_turn = (current_turn == my_idx)
	var def_id = int(active_attack.get("defender_id", 0))
	var atk_id = int(active_attack.get("attacker_id", current_turn))

	# Case 1: I am the Defender in `DefenderArmy` phase!
	if game_state_str == "DefenderArmy" and def_id == my_idx:
		var src_fa = CONTINENT_NAMES_FA.get(str(active_attack.get("source_continent", "")), "")
		var tgt_fa = CONTINENT_NAMES_FA.get(str(active_attack.get("target_continent", "")), "")
		var atk_army = int(active_attack.get("attacker_army", 0))
		_lbl_phase_status.text = "🛡️ دفاع فوری! حمله به %s از %s (سرباز کمکی مهاجم: %s)" % [tgt_fa, src_fa, _fa_int(atk_army)]
		_lbl_phase_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))

		var max_army = _count_my_strategy("Army")
		selected_army_commit = clampi(selected_army_commit, 0, max_army)

		for c_val in range(max_army + 1):
			var b_cnt = Button.new()
			b_cnt.custom_minimum_size = Vector2(120, 68)
			b_cnt.focus_mode = Control.FOCUS_NONE
			b_cnt.add_theme_font_override("font", _font_hekayat)
			b_cnt.add_theme_font_size_override("font_size", 22)
			b_cnt.text = "🛡️ +%s سرباز" % _fa_int(c_val) if c_val > 0 else "🛡️ بدون سرباز"
			var sel_col = Color(0.16, 0.52, 0.88) if selected_army_commit == c_val else Color(0.18, 0.14, 0.10)
			var brd_col = Color(0.45, 0.88, 1.0) if selected_army_commit == c_val else Color(0.55, 0.45, 0.30)
			_style_tactical_button(b_cnt, sel_col, brd_col)
			var chosen_c = c_val
			b_cnt.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_army_commit = chosen_c
				_refresh_phase_actions_bar()
			)
			_phase_actions_row.add_child(b_cnt)

		var btn_defend = Button.new()
		btn_defend.custom_minimum_size = Vector2(230, 70)
		btn_defend.focus_mode = Control.FOCUS_NONE
		btn_defend.add_theme_font_override("font", _font_hekayat)
		btn_defend.add_theme_font_size_override("font_size", 25)
		btn_defend.text = "🎲 دفاع و پرتاب تاس"
		_style_tactical_button(btn_defend, Color(0.14, 0.58, 0.30), Color(0.38, 0.98, 0.56))
		btn_defend.pressed.connect(func():
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			send_move(Commands.DefenderArmy, {"count": selected_army_commit, "cancel": false})
			selected_army_commit = 0
		)
		_phase_actions_row.add_child(btn_defend)

		if _count_my_strategy("Cancel") > 0:
			var btn_cancel_atk = Button.new()
			btn_cancel_atk.custom_minimum_size = Vector2(240, 70)
			btn_cancel_atk.focus_mode = Control.FOCUS_NONE
			btn_cancel_atk.add_theme_font_override("font", _font_hekayat)
			btn_cancel_atk.add_theme_font_size_override("font_size", 24)
			btn_cancel_atk.text = "🕊️ کارت آتش‌بس (لغو حمله)"
			_style_tactical_button(btn_cancel_atk, Color(0.68, 0.46, 0.10), Color(1.0, 0.88, 0.32))
			btn_cancel_atk.pressed.connect(func():
				if not _can_send_action():
					return
				AudioManager.sfx_button()
				send_move(Commands.DefenderArmy, {"count": 0, "cancel": true})
			)
			_phase_actions_row.add_child(btn_cancel_atk)
		return

	# Case 2: Waiting for another player's defense or turn
	if game_state_str == "DefenderArmy" and def_id != my_idx:
		var def_name = _get_player_display_name(def_id)
		_lbl_phase_status.text = "⏳ در انتظار تصمیم دفاعی %s..." % def_name
		_lbl_phase_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
		var wait_lbl = Label.new()
		wait_lbl.add_theme_font_override("font", _font_hekayat)
		wait_lbl.add_theme_font_size_override("font_size", 24)
		wait_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
		wait_lbl.text = "⚔️ %s در حال انتخاب تعداد سرباز کمکی یا کارت آتش‌بس برای دفاع است..." % def_name
		_phase_actions_row.add_child(wait_lbl)
		return

	if not is_my_turn:
		var turn_name = _get_player_display_name(current_turn)
		_lbl_phase_status.text = "⏳ نوبت فرماندهی %s" % turn_name
		_lbl_phase_status.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
		var opp_lbl = Label.new()
		opp_lbl.add_theme_font_override("font", _font_hekayat)
		opp_lbl.add_theme_font_size_override("font_size", 24)
		opp_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
		opp_lbl.text = "در انتظار حرکت %s... (در صورت حمله به قاره شما، پنل دفاع فعال می‌شود)" % turn_name
		_phase_actions_row.add_child(opp_lbl)
		return

	# Case 3: My Turn — Phase 1: DRAW (`StartGame` or `Draw`)
	if game_state_str in ["StartGame", "Draw"]:
		_lbl_phase_status.text = "🎴 مرحله ۱: دریافت ۲ کارت آغاز نوبت (یکی را انتخاب کنید)"
		_lbl_phase_status.add_theme_color_override("font_color", Color(0.42, 0.98, 0.62))

		var draw_options = [
			{"type": 1, "label": "🗺️ ۲ کارت قاره", "col": Color(0.14, 0.56, 0.34), "brd": Color(0.38, 0.98, 0.62)},
			{"type": 3, "label": "⚡ ۱ قاره + ۱ تاکتیک", "col": Color(0.62, 0.44, 0.12), "brd": Color(1.0, 0.86, 0.32)},
			{"type": 2, "label": "🃏 ۲ کارت تاکتیک", "col": Color(0.54, 0.18, 0.28), "brd": Color(0.98, 0.46, 0.58)},
		]
		for opt in draw_options:
			var btn_d = Button.new()
			btn_d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_d.custom_minimum_size = Vector2(260, 70)
			btn_d.focus_mode = Control.FOCUS_NONE
			btn_d.add_theme_font_override("font", _font_hekayat)
			btn_d.add_theme_font_size_override("font_size", 25)
			btn_d.text = str(opt["label"])
			_style_tactical_button(btn_d, opt["col"], opt["brd"])
			var d_type: int = int(opt["type"])
			btn_d.pressed.connect(func():
				if not _can_send_action():
					return
				AudioManager.sfx_button()
				send_move(Commands.Draw_Card, {"draw_type": d_type})
			)
			_phase_actions_row.add_child(btn_d)
		return

	# Case 4: My Turn — Phase 3: `AttackerArmy` (Committing Army cards to declared attack)
	if game_state_str in ["DeclareAttack", "AttackerArmy"] and atk_id == my_idx:
		var src_fa2 = CONTINENT_NAMES_FA.get(str(active_attack.get("source_continent", "")), "")
		var tgt_fa2 = CONTINENT_NAMES_FA.get(str(active_attack.get("target_continent", "")), "")
		_lbl_phase_status.text = "⚔️ تقویت حمله از %s به %s: تعداد سرباز کمکی را مشخص کنید" % [src_fa2, tgt_fa2]
		_lbl_phase_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))

		var max_atk_army = _count_my_strategy("Army")
		selected_army_commit = clampi(selected_army_commit, 0, max_atk_army)

		for c_val2 in range(max_atk_army + 1):
			var b_atk = Button.new()
			b_atk.custom_minimum_size = Vector2(130, 68)
			b_atk.focus_mode = Control.FOCUS_NONE
			b_atk.add_theme_font_override("font", _font_hekayat)
			b_atk.add_theme_font_size_override("font_size", 22)
			b_atk.text = "⚔️ +%s سرباز" % _fa_int(c_val2) if c_val2 > 0 else "⚔️ بدون سرباز"
			var sel_c = Color(0.68, 0.22, 0.18) if selected_army_commit == c_val2 else Color(0.18, 0.14, 0.10)
			var brd_c = Color(1.0, 0.52, 0.42) if selected_army_commit == c_val2 else Color(0.55, 0.45, 0.30)
			_style_tactical_button(b_atk, sel_c, brd_c)
			var chosen_a = c_val2
			b_atk.pressed.connect(func():
				AudioManager.sfx_tap()
				selected_army_commit = chosen_a
				_refresh_phase_actions_bar()
			)
			_phase_actions_row.add_child(b_atk)

		var btn_commit = Button.new()
		btn_commit.custom_minimum_size = Vector2(250, 70)
		btn_commit.focus_mode = Control.FOCUS_NONE
		btn_commit.add_theme_font_override("font", _font_hekayat)
		btn_commit.add_theme_font_size_override("font_size", 25)
		btn_commit.text = "🎲 تایید لشکر و حمله!"
		_style_tactical_button(btn_commit, Color(0.16, 0.62, 0.30), Color(0.42, 1.0, 0.58))
		btn_commit.pressed.connect(func():
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			send_move(Commands.AttackerArmy, {"count": selected_army_commit})
			selected_army_commit = 0
		)
		_phase_actions_row.add_child(btn_commit)
		return

	# Case 5: My Turn — Phase 2: `SelectAction` (Declare Attack, Play Strategy Cards, or Pass Turn)
	var expand_tag = " (🚀 گسترش مرز فعال)" if ignore_adjacency_this_turn else ""
	_lbl_phase_status.text = "⚔️ مرحله ۲: عملیات و حمله%s" % expand_tag
	_lbl_phase_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.52))

	# Auto-select a source continent if none selected or current has 0 cards
	if selected_source_continent.is_empty() or _get_player_continent_count(my_idx, selected_source_continent) <= 0:
		selected_source_continent = ""
		for c_try in CONTINENT_ORDER:
			if _get_player_continent_count(my_idx, c_try) > 0:
				selected_source_continent = c_try
				break

	if not selected_source_continent.is_empty():
		var src_name_fa = CONTINENT_SHORT_FA.get(selected_source_continent, selected_source_continent)
		for tgt_c in CONTINENT_ORDER:
			if not _are_continents_adjacent(selected_source_continent, tgt_c):
				continue
			for pid in active_player_indexes:
				var opp_id = int(pid)
				if opp_id == my_idx:
					continue
				var opp_cnt = _get_player_continent_count(opp_id, tgt_c)
				if opp_cnt <= 0:
					continue
				var btn_atk_target = Button.new()
				btn_atk_target.custom_minimum_size = Vector2(235, 68)
				btn_atk_target.focus_mode = Control.FOCUS_NONE
				btn_atk_target.add_theme_font_override("font", _font_hekayat)
				btn_atk_target.add_theme_font_size_override("font_size", 21)
				var tgt_fa3 = CONTINENT_SHORT_FA.get(tgt_c, tgt_c)
				btn_atk_target.text = "⚔️ حمله از %s به %s\n%s ب%s (×%s)" % [
					src_name_fa,
					tgt_fa3,
					FACTION_DOTS.get(opp_id, ""),
					_fa_int(opp_id),
					_fa_int(opp_cnt)
				]
				_style_tactical_button(btn_atk_target, Color(0.62, 0.16, 0.16), Color(1.0, 0.48, 0.38))
				var s_c = selected_source_continent
				var t_c = tgt_c
				var t_p = opp_id
				btn_atk_target.pressed.connect(func():
					if not _can_send_action():
						return
					AudioManager.sfx_button()
					attacked_this_turn = true
					send_move(Commands.Declare_Attack, {
						"source_continent": s_c,
						"target_continent": t_c,
						"target_index": t_p,
					})
				)
				_phase_actions_row.add_child(btn_atk_target)

	# Pass Turn Button (always available in SelectAction)
	var btn_pass = Button.new()
	btn_pass.custom_minimum_size = Vector2(220, 68)
	btn_pass.focus_mode = Control.FOCUS_NONE
	btn_pass.add_theme_font_override("font", _font_hekayat)
	btn_pass.add_theme_font_size_override("font_size", 22)
	if not attacked_this_turn:
		btn_pass.text = "⏭️ پایان نوبت\n(🎁 +۱ کارت تاکتیک)"
	else:
		btn_pass.text = "⏭️ پایان نوبت"
	_style_tactical_button(btn_pass, Color(0.24, 0.32, 0.46), Color(0.58, 0.76, 0.98))
	btn_pass.pressed.connect(func():
		if not _can_send_action():
			return
		AudioManager.sfx_button()
		send_move(Commands.Pass_Turn, {})
	)
	_phase_actions_row.add_child(btn_pass)

# ==============================================================================
# INTERACTIVE STRATEGY CARDS & CONTINENT CLICKS
# ==============================================================================

func _can_send_action() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	if now < _action_cooldown_until:
		return false
	_action_cooldown_until = now + 0.32
	return true

func _on_continent_clicked(c_name: String) -> void:
	AudioManager.sfx_tap()
	var my_idx = GameManager.my_player_index
	if current_turn != my_idx or not (game_state_str in ["SelectAction", "DrawResult", "ActionResult"]):
		var owner_id = _find_continent_token_owner(c_name)
		var owner_txt = "آزاد" if owner_id == 0 else _get_player_display_name(owner_id)
		show_hint("قاره %s | صاحب نشان سلطه: %s" % [CONTINENT_NAMES_FA.get(c_name, c_name), owner_txt])
		return

	# If player has cards in c_name and taps it when no source is selected (or taps same source), toggle source
	var my_cnt = _get_player_continent_count(my_idx, c_name)
	if selected_source_continent.is_empty() or selected_source_continent == c_name:
		if my_cnt > 0:
			selected_source_continent = "" if selected_source_continent == c_name else c_name
			_refresh_all_visuals()
		else:
			show_hint("برای شروع حمله ابتدا یکی از قاره‌های خود را انتخاب کنید.")
		return

	# If a source continent is already selected and c_name is an adjacent continent held by an opponent, attack it
	if _are_continents_adjacent(selected_source_continent, c_name):
		var target_opponents: Array[int] = []
		for pid in active_player_indexes:
			var opp_id = int(pid)
			if opp_id != my_idx and _get_player_continent_count(opp_id, c_name) > 0:
				target_opponents.append(opp_id)
		if target_opponents.size() == 1:
			if not _can_send_action():
				return
			attacked_this_turn = true
			send_move(Commands.Declare_Attack, {
				"source_continent": selected_source_continent,
				"target_continent": c_name,
				"target_index": target_opponents[0],
			})
			return
		elif target_opponents.size() > 1:
			_open_attack_opponent_picker(selected_source_continent, c_name, target_opponents)
			return

	# Otherwise switch source continent if player has cards in c_name
	if my_cnt > 0:
		selected_source_continent = c_name
		_refresh_all_visuals()
	else:
		show_hint("قاره %s با %s هم‌مرز نیست یا حریفی در آن حضور ندارد." % [
			CONTINENT_NAMES_FA.get(c_name, c_name),
			CONTINENT_NAMES_FA.get(selected_source_continent, selected_source_continent)
		])

func _open_attack_opponent_picker(src_c: String, tgt_c: String, opponents: Array[int]) -> void:
	for child in _target_modal_list.get_children():
		child.queue_free()
	_target_modal_title.text = "⚔️ انتخاب حریف برای حمله در قاره %s" % CONTINENT_NAMES_FA.get(tgt_c, tgt_c)
	for opp_id in opponents:
		var cnt = _get_player_continent_count(opp_id, tgt_c)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 68)
		btn.add_theme_font_override("font", _font_hekayat)
		btn.add_theme_font_size_override("font_size", 25)
		btn.text = "%s حمله به %s (دارای %s کارت در %s)" % [
			FACTION_DOTS.get(opp_id, ""),
			_get_player_display_name(opp_id),
			_fa_int(cnt),
			CONTINENT_NAMES_FA.get(tgt_c, tgt_c)
		]
		_style_tactical_button(btn, Color(0.62, 0.16, 0.16), Color(1.0, 0.48, 0.38))
		var target_p = opp_id
		btn.pressed.connect(func():
			_target_modal_overlay.visible = false
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			attacked_this_turn = true
			send_move(Commands.Declare_Attack, {
				"source_continent": src_c,
				"target_continent": tgt_c,
				"target_index": target_p,
			})
		)
		_target_modal_list.add_child(btn)
	_target_modal_overlay.visible = true

func _on_strategy_card_clicked(strat_name: String) -> void:
	var my_idx = GameManager.my_player_index
	var def_id = int(active_attack.get("defender_id", 0))

	# Defender can play Cancel or Canon during defense
	if game_state_str == "DefenderArmy" and def_id == my_idx:
		if strat_name == "Cancel":
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			send_move(Commands.DefenderArmy, {"count": 0, "cancel": true})
			return
		elif strat_name == "Canon":
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			send_move(Commands.Use_Strategy, {"strategy": "Canon"})
			return
		elif strat_name == "Army":
			AudioManager.sfx_tap()
			show_hint("از دکمه‌های +سرباز در نوار دفاع برای افزودن کارت سرباز کمکی استفاده کنید.")
			return
		else:
			AudioManager.sfx_tap()
			show_hint("در زمان دفاع فقط کارت آتش‌بس، توپخانه یا سرباز کمکی قابل استفاده است.")
			return

	if current_turn != my_idx:
		AudioManager.sfx_tap()
		show_hint("فقط در نوبت خود می‌توانید کارت‌های تاکتیکی بازی کنید!")
		return

	if game_state_str in ["StartGame", "Draw"]:
		AudioManager.sfx_tap()
		show_hint("ابتدا ۲ کارت آغاز نوبت خود را دریافت کنید!")
		return

	if strat_name == "Cancel":
		AudioManager.sfx_tap()
		show_hint("کارت آتش‌بس (🕊️) زمانی که حریف به شما حمله کند برای لغو حمله استفاده می‌شود.")
		return

	if strat_name in ["Backup", "Expand", "Canon", "Army"]:
		if not _can_send_action():
			return
		AudioManager.sfx_button()
		send_move(Commands.Use_Strategy, {"strategy": strat_name})
		return

	if strat_name == "Destroy":
		_open_destroy_target_modal()
		return

	if strat_name in ["Bomb", "Spy"]:
		_open_opponent_strategy_target_modal(strat_name)
		return

func _open_destroy_target_modal() -> void:
	for child in _target_modal_list.get_children():
		child.queue_free()
	_target_modal_title.text = "💥 تخریب قاره: یک قاره از حریف را برای حذف انتخاب کنید"
	var my_idx = GameManager.my_player_index
	var count_options: int = 0

	for pid in active_player_indexes:
		var opp_id = int(pid)
		if opp_id == my_idx:
			continue
		for c_name in CONTINENT_ORDER:
			var cnt = _get_player_continent_count(opp_id, c_name)
			if cnt <= 0:
				continue
			count_options += 1
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(0, 66)
			btn.add_theme_font_override("font", _font_hekayat)
			btn.add_theme_font_size_override("font_size", 24)
			btn.text = "💥 حذف ۱ کارت %s از %s %s (دارای %s کارت)" % [
				CONTINENT_NAMES_FA.get(c_name, c_name),
				FACTION_DOTS.get(opp_id, ""),
				_get_player_display_name(opp_id),
				_fa_int(cnt)
			]
			_style_tactical_button(btn, Color(0.58, 0.16, 0.22), Color(0.98, 0.42, 0.48))
			var t_p = opp_id
			var t_c = c_name
			btn.pressed.connect(func():
				_target_modal_overlay.visible = false
				if not _can_send_action():
					return
				AudioManager.sfx_button()
				send_move(Commands.Use_Strategy, {
					"strategy": "Destroy",
					"target_index": t_p,
					"target_continent": t_c,
				})
			)
			_target_modal_list.add_child(btn)

	if count_options == 0:
		show_hint("هیچ حریفی کارت قاره برای تخریب ندارد!")
		return
	_target_modal_overlay.visible = true

func _open_opponent_strategy_target_modal(strat_name: String) -> void:
	var my_idx = GameManager.my_player_index
	var valid_opps: Array[int] = []
	for pid in active_player_indexes:
		var opp_id = int(pid)
		if opp_id != my_idx and _get_player_strategy_count(opp_id) > 0:
			valid_opps.append(opp_id)

	if valid_opps.is_empty():
		AudioManager.sfx_tap()
		show_hint("هیچ حریفی کارت تاکتیکی در دست ندارد!")
		return

	if valid_opps.size() == 1:
		if not _can_send_action():
			return
		AudioManager.sfx_button()
		send_move(Commands.Use_Strategy, {
			"strategy": strat_name,
			"target_index": valid_opps[0],
		})
		return

	for child in _target_modal_list.get_children():
		child.queue_free()
	var title_fa = "💣 بمباران (حذف ۲ کارت تاکتیک حریف)" if strat_name == "Bomb" else "🕵️ جاسوس (سرقت ۱ کارت تاکتیک از حریف)"
	_target_modal_title.text = title_fa

	for opp_id in valid_opps:
		var s_cnt = _get_player_strategy_count(opp_id)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 66)
		btn.add_theme_font_override("font", _font_hekayat)
		btn.add_theme_font_size_override("font_size", 24)
		btn.text = "%s %s (دارای %s کارت تاکتیک)" % [
			FACTION_DOTS.get(opp_id, ""),
			_get_player_display_name(opp_id),
			_fa_int(s_cnt)
		]
		_style_tactical_button(btn, Color(0.22, 0.36, 0.56), Color(0.55, 0.82, 1.0))
		var t_p = opp_id
		btn.pressed.connect(func():
			_target_modal_overlay.visible = false
			if not _can_send_action():
				return
			AudioManager.sfx_button()
			send_move(Commands.Use_Strategy, {
				"strategy": strat_name,
				"target_index": t_p,
			})
		)
		_target_modal_list.add_child(btn)

	_target_modal_overlay.visible = true

# ==============================================================================
# SERVER COMMAND & NETWORK EVENT HANDLERS
# ==============================================================================

func _apply_public_game_data(g_data: Dictionary) -> void:
	if g_data.has("current_turn"):
		current_turn = int(g_data["current_turn"])
		GameManager.current_turn = current_turn
	if g_data.has("active_player_indexes") and typeof(g_data["active_player_indexes"]) == TYPE_ARRAY:
		active_player_indexes = (g_data["active_player_indexes"] as Array).duplicate()
	if g_data.has("game_state"):
		game_state_str = str(g_data["game_state"])
	if g_data.has("tokens") and typeof(g_data["tokens"]) == TYPE_ARRAY:
		unowned_tokens = (g_data["tokens"] as Array).duplicate()
	if g_data.has("continents"):
		remaining_continents_deck = int(g_data["continents"])
	if g_data.has("strategies"):
		remaining_strategies_deck = int(g_data["strategies"])
	if g_data.has("rank1") and g_data["rank1"] != null:
		rank1_player = int(g_data["rank1"])
		GameManager.ludo_rank1 = rank1_player
	if g_data.has("rank2") and g_data["rank2"] != null:
		rank2_player = int(g_data["rank2"])
		GameManager.ludo_rank2 = rank2_player

	if g_data.has("players_data") and typeof(g_data["players_data"]) == TYPE_ARRAY:
		var p_arr: Array = g_data["players_data"]
		players_count = clampi(max(2, p_arr.size()), 2, 4)
		for item in p_arr:
			if typeof(item) == TYPE_DICTIONARY:
				var p_idx = int(item.get("index", 1))
				players_public[p_idx] = item.duplicate(true)

	if g_data.has("active_attack") and typeof(g_data["active_attack"]) == TYPE_DICTIONARY:
		active_attack = (g_data["active_attack"] as Dictionary).duplicate(true)
	elif game_state_str in ["StartGame", "Draw", "SelectAction"]:
		active_attack.clear()

func _on_user_data_received(payload: Dictionary) -> void:
	if payload.has("continents") and typeof(payload["continents"]) == TYPE_DICTIONARY:
		var c_dict: Dictionary = payload["continents"]
		for c_name in CONTINENT_ORDER:
			my_continents[c_name] = int(c_dict.get(c_name, 0))
	if payload.has("strategies") and typeof(payload["strategies"]) == TYPE_ARRAY:
		my_strategies = (payload["strategies"] as Array).duplicate()
	if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
		my_tokens = (payload["tokens"] as Array).duplicate()
	if payload.has("index"):
		var idx = int(payload["index"])
		if players_public.has(idx):
			players_public[idx]["continents"] = my_continents.duplicate()
			players_public[idx]["strategies"] = my_strategies.size()
			players_public[idx]["tokens"] = my_tokens.duplicate()
	_refresh_all_visuals()

func _on_risk_event_received(cmd_id: String, payload: Dictionary) -> void:
	match cmd_id:
		Commands.User_Data:
			_on_user_data_received(payload)

		Commands.Draw_Card:
			var new_turn = int(payload.get("turn", current_turn))
			current_turn = new_turn
			GameManager.current_turn = new_turn
			game_state_str = str(payload.get("game_state", "Draw"))
			active_attack.clear()
			selected_army_commit = 0
			ignore_adjacency_this_turn = false
			attacked_this_turn = false
			_set_battle_banner("🎴 نوبت %s — مرحله دریافت ۲ کارت آغاز نوبت" % _get_player_display_name(current_turn))
			_restart_hud_turn_timer(30.0)
			_refresh_all_visuals()

		Commands.Draw_Result:
			var g_id = int(payload.get("gamer_id", current_turn))
			var d_type = int(payload.get("draw_type", 3))
			if payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				players_public[g_id] = (payload["new_data"] as Dictionary).duplicate(true)
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				unowned_tokens = (payload["tokens"] as Array).duplicate()
			game_state_str = str(payload.get("game_state", "SelectAction"))
			var d_desc = "۲ کارت قاره" if d_type == 1 else ("۲ کارت تاکتیک" if d_type == 2 else "۱ قاره + ۱ تاکتیک")
			_set_battle_banner("📥 %s «%s» دریافت کرد" % [_get_player_display_name(g_id), d_desc])
			AudioManager.play_sound("add_peace")
			_restart_hud_turn_timer(30.0)
			_refresh_all_visuals()

		Commands.Draw_Result_Private:
			if payload.has("new_user_data") and typeof(payload["new_user_data"]) == TYPE_DICTIONARY:
				_on_user_data_received(payload["new_user_data"])

		Commands.Declare_Attack:
			var atk_id = int(payload.get("gamer_id", current_turn))
			var src_c = str(payload.get("source_continent", ""))
			var tgt_c = str(payload.get("target_continent", ""))
			var tgt_id = int(payload.get("target_index", 0))
			game_state_str = str(payload.get("game_state", "AttackerArmy"))
			active_attack = {
				"attacker_id": atk_id,
				"defender_id": tgt_id,
				"source_continent": src_c,
				"target_continent": tgt_c,
				"attacker_army": 0,
				"defender_army": 0,
			}
			selected_army_commit = 0
			AudioManager.play_sound("move_peace")
			_set_battle_banner("⚔️ %s از %s به %s (%s) اعلام حمله کرد!" % [
				_get_player_display_name(atk_id),
				CONTINENT_NAMES_FA.get(src_c, src_c),
				CONTINENT_NAMES_FA.get(tgt_c, tgt_c),
				_get_player_display_name(tgt_id)
			])
			_restart_hud_turn_timer(30.0)
			_refresh_all_visuals()

		Commands.AttackerArmy:
			var atk_id2 = int(payload.get("gamer_id", current_turn))
			var cnt_a = int(payload.get("count", 0))
			var tgt_id2 = int(payload.get("target_index", active_attack.get("defender_id", 0)))
			game_state_str = str(payload.get("game_state", "DefenderArmy"))
			active_attack["attacker_army"] = cnt_a
			active_attack["defender_id"] = tgt_id2
			selected_army_commit = 0
			if tgt_id2 == GameManager.my_player_index:
				AudioManager.play_sound("bell")
				show_hint("🛡️ به قاره شما حمله شده است! تصمیم دفاعی خود را انتخاب کنید.")
			_set_battle_banner("⚔️ %s با +%s سرباز کمکی آماده نبرد شد! در انتظار دفاع %s..." % [
				_get_player_display_name(atk_id2),
				_fa_int(cnt_a),
				_get_player_display_name(tgt_id2)
			])
			_restart_hud_turn_timer(30.0)
			_refresh_all_visuals()

		Commands.Attack:
			_handle_battle_resolution(payload)

		Commands.Strategy_Result:
			_handle_strategy_result(payload)

		Commands.Pass_Turn:
			var p_id = int(payload.get("gamer_id", current_turn))
			if payload.has("new_data") and typeof(payload["new_data"]) == TYPE_DICTIONARY:
				players_public[p_id] = (payload["new_data"] as Dictionary).duplicate(true)
			if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
				unowned_tokens = (payload["tokens"] as Array).duplicate()
			active_attack.clear()
			selected_source_continent = ""
			_refresh_all_visuals()

func _handle_battle_resolution(payload: Dictionary) -> void:
	if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
		for item in payload["players_data"]:
			if typeof(item) == TYPE_DICTIONARY:
				var p_idx = int(item.get("index", 1))
				players_public[p_idx] = item.duplicate(true)
	if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
		unowned_tokens = (payload["tokens"] as Array).duplicate()
	if payload.has("game_state"):
		game_state_str = str(payload["game_state"])
	else:
		game_state_str = "SelectAction"

	var canceled = bool(payload.get("canceled", false))
	var tgt_c = str(payload.get("target_continent", active_attack.get("target_continent", "")))
	var tgt_fa = CONTINENT_NAMES_FA.get(tgt_c, tgt_c)

	if canceled:
		AudioManager.play_sound("correct")
		_set_battle_banner("🕊️ آتش‌بس! مدافع با کارت آتش‌بس حمله به قاره %s را لغو کرد!" % tgt_fa)
		active_attack.clear()
		_restart_hud_turn_timer(30.0)
		_refresh_all_visuals()
		return

	var atk_dice: Array = payload.get("attacker_dice", []) if typeof(payload.get("attacker_dice")) == TYPE_ARRAY else []
	var def_dice: Array = payload.get("defender_dice", []) if typeof(payload.get("defender_dice")) == TYPE_ARRAY else []
	var atk_loss = int(payload.get("attacker_losses", 0))
	var def_loss = int(payload.get("defender_losses", 0))
	var conquered = bool(payload.get("conquered", false))

	_animate_3d_battle_dice(atk_dice, def_dice)
	AudioManager.play_sound("hit")

	var atk_str_arr: Array[String] = []
	for d in atk_dice:
		atk_str_arr.append(_fa_int(int(d)))
	var def_str_arr: Array[String] = []
	for d2 in def_dice:
		def_str_arr.append(_fa_int(int(d2)))

	var summary = "🎲 تاس مهاجم [%s] ⚔️ مدافع [%s] | تلفات مهاجم: %s، مدافع: %s" % [
		"، ".join(atk_str_arr),
		"، ".join(def_str_arr),
		_fa_int(atk_loss),
		_fa_int(def_loss)
	]
	if conquered:
		summary += " | 👑 فتح %s!" % tgt_fa
		AudioManager.play_sound("bell")

	_set_battle_banner(summary)
	active_attack.clear()
	_restart_hud_turn_timer(30.0)
	_refresh_all_visuals()

func _handle_strategy_result(payload: Dictionary) -> void:
	if payload.has("players_data") and typeof(payload["players_data"]) == TYPE_ARRAY:
		for item in payload["players_data"]:
			if typeof(item) == TYPE_DICTIONARY:
				var p_idx = int(item.get("index", 1))
				players_public[p_idx] = item.duplicate(true)
	if payload.has("tokens") and typeof(payload["tokens"]) == TYPE_ARRAY:
		unowned_tokens = (payload["tokens"] as Array).duplicate()
	if payload.has("game_state"):
		game_state_str = str(payload["game_state"])

	var g_id = int(payload.get("gamer_id", current_turn))
	var strat = str(payload.get("strategy", ""))
	var info: Dictionary = STRATEGY_INFO.get(strat, {"name_fa": strat, "icon": "🃏"})
	var actor_name = _get_player_display_name(g_id)

	if strat == "Expand" and g_id == GameManager.my_player_index:
		ignore_adjacency_this_turn = true

	var msg = "%s %s از کارت «%s» استفاده کرد!" % [
		str(info.get("icon", "🃏")),
		actor_name,
		str(info.get("name_fa", strat))
	]
	if payload.has("destroyed_continent"):
		var dc = CONTINENT_NAMES_FA.get(str(payload["destroyed_continent"]), str(payload["destroyed_continent"]))
		msg += " (تخریب ۱ کارت از قاره %s)" % dc
		AudioManager.play_sound("explode")
	else:
		AudioManager.play_sound("move_peace")

	_set_battle_banner(msg)
	_refresh_all_visuals()

func _set_battle_banner(text: String) -> void:
	if is_instance_valid(_battle_banner_lbl):
		_battle_banner_lbl.text = text

func _restart_hud_turn_timer(seconds: float = 30.0) -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud) and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(seconds)

func _sync_top_header_stats() -> void:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if not hud or not is_instance_valid(hud):
		return
	var top_hdr = hud.get("current_top_header")
	if top_hdr and is_instance_valid(top_hdr) and top_hdr.has_method("update_risk_player_stats"):
		var t_counts: Array = []
		var c_counts: Array = []
		var s_counts: Array = []
		for pid in range(1, 5):
			t_counts.append(_get_player_tokens(pid).size())
			c_counts.append(_get_player_total_continents(pid))
			s_counts.append(_get_player_strategy_count(pid))
		top_hdr.update_risk_player_stats(t_counts, c_counts, s_counts, rank1_player, rank2_player)

# ==============================================================================
# BASEGAMEBOARD LIFECYCLE OVERRIDES & 3D RAYCAST INPUT
# ==============================================================================

func setup_board(game_data: Dictionary) -> void:
	var g_list = game_data.get("gamers", GameManager.match_players)
	if typeof(g_list) == TYPE_ARRAY and g_list.size() >= 2:
		players_count = clampi(g_list.size(), 2, 4)
	var inner = game_data.get("game_data", game_data)
	if typeof(inner) == TYPE_DICTIONARY:
		_apply_public_game_data(inner)
	_refresh_all_visuals()

func on_turn_changed(turn: int, _is_me: bool) -> void:
	current_turn = turn
	_refresh_all_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_list = payload.get("gamers", GameManager.match_players)
	if typeof(g_list) == TYPE_ARRAY and g_list.size() >= 2:
		players_count = clampi(g_list.size(), 2, 4)
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_public_game_data(g_data)
	_refresh_all_visuals()

func on_player_surrendered(gamer_id: int) -> void:
	if active_player_indexes.has(gamer_id):
		active_player_indexes.erase(gamer_id)
	if players_public.has(gamer_id):
		players_public[gamer_id]["continents"] = {}
		players_public[gamer_id]["strategies"] = 0
		players_public[gamer_id]["tokens"] = []
	_refresh_all_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down_pos = event.position
			_pointer_is_down = true
		else:
			if _pointer_is_down:
				_pointer_is_down = false
				if event.position.distance_to(_pointer_down_pos) <= 18.0:
					_handle_3d_table_tap(event.position)

func _handle_3d_table_tap(screen_pos: Vector2) -> void:
	var vp = get_viewport()
	if not vp:
		return
	var cam = vp.get_camera_3d()
	if not cam:
		return
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_dir = cam.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.0001:
		return
	var t = (SURFACE_Y + 0.02 - ray_origin.y) / ray_dir.y
	if t <= 0.0:
		return
	var hit_pt = ray_origin + ray_dir * t
	var local_pt = to_local(hit_pt)

	var best_continent: String = ""
	var best_dist: float = 0.165
	for c_name in CONTINENT_ORDER:
		var c_pos: Vector3 = CONTINENT_POSITIONS_3D[c_name]
		var d = Vector2(local_pt.x - c_pos.x, local_pt.z - c_pos.z).length()
		if d < best_dist:
			best_dist = d
			best_continent = c_name

	if not best_continent.is_empty():
		_on_continent_clicked(best_continent)
