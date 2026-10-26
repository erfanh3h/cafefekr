class_name RPC3D
extends "res://scripts/games/base_game_board.gd"

# Deluxe Royal 3D Rock-Paper-Scissors (سنگ کاغذ قیچی) Arena Board
# 100% logic & payload parity with:
# - kafehfekrbackend/Controllers/GameSession/rpc_game_session.py
# - kafehfekrbackend/Entities/Games/RPC/__init__.py
# - kafehfekr/lib/Feature/RPC/Controllers/rpc_controller.dart
#
# Rules & Mechanics:
# - Match: Best of 3 Rounds (RPC_Round_Count = 3, first to 2 round wins).
# - Each Round: Up to 5 Turn-Rounds (RPC_Turn_Round_Count = 5, first to 3 turn-round wins).
# - Turn-Round Time: 7.0 seconds simultaneous choice.
# - Selections: "rock" (سنگ), "paper" (کاغذ), "cutter" (قیچی).

const DRAG_THRESHOLD: float = 14.0
const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")

enum RPCType {
	ROCK,
	PAPER,
	CUTTER
}

# State Variables
var current_round_num: int = 1
var current_turn_round_num: int = 1
var p1_turn_round_score: int = 0
var p2_turn_round_score: int = 0
var p1_match_score: int = 0
var p2_match_score: int = 0
var my_selected_choice: String = ""
var is_choice_confirmed: bool = false

# Interactive Pedestals & Visual Nodes
var pedestals: Dictionary = {}         # "rock", "paper", "cutter" -> Node3D
var pedestal_areas: Dictionary = {}    # "rock", "paper", "cutter" -> Area3D
var pedestal_objects: Dictionary = {}  # "rock", "paper", "cutter" -> Node3D
var selection_halos: Dictionary = {}         # "rock", "paper", "cutter" -> MeshInstance3D
var selection_aura_rings: Dictionary = {}    # "rock", "paper", "cutter" -> MeshInstance3D
var selection_light_pillars: Dictionary = {} # "rock", "paper", "cutter" -> MeshInstance3D
var hover_rings: Dictionary = {}             # "rock", "paper", "cutter" -> MeshInstance3D

# Arena & Combatant Nodes
var arena_center: Node3D = null
var clash_container: Node3D = null
var p1_clash_node: Node3D = null
var p2_clash_node: Node3D = null

# Turn-Round Score Sockets (5 pips per player)
var p1_sockets: Array[MeshInstance3D] = []
var p1_gems: Array[MeshInstance3D] = []
var p2_sockets: Array[MeshInstance3D] = []
var p2_gems: Array[MeshInstance3D] = []
var lbl_turn_round_status: Label3D = null

# Input & Hover Tracking
var hovered_choice: String = ""
var _press_screen_pos: Vector2 = Vector2.ZERO
var _is_pointer_down: bool = false
var _last_click_time: float = 0.0
var _press_down_time: float = 0.0
var _anim_time: float = 0.0
var _active_tweens: Array[Tween] = []

# Procedural Materials
var mat_felt_base: StandardMaterial3D
var mat_mahogany_dark: StandardMaterial3D
var mat_walnut_frame: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_arena_velvet: StandardMaterial3D
var mat_pedestal_velvet: StandardMaterial3D
var mat_pedestal_hover: StandardMaterial3D
var mat_selected_halo: StandardMaterial3D
var mat_ruby_gem: StandardMaterial3D
var mat_ruby_lit: StandardMaterial3D
var mat_sapphire_gem: StandardMaterial3D
var mat_sapphire_lit: StandardMaterial3D
var mat_socket_unlit: StandardMaterial3D

# Physical Object Materials
var mat_rock_obsidian: StandardMaterial3D
var mat_rock_crystal_p1: StandardMaterial3D
var mat_rock_crystal_p2: StandardMaterial3D
var mat_paper_parchment: StandardMaterial3D
var mat_paper_gold_leaf: StandardMaterial3D
var mat_paper_seal_p1: StandardMaterial3D
var mat_paper_seal_p2: StandardMaterial3D
var mat_scissors_damascus: StandardMaterial3D
var mat_scissors_edge: StandardMaterial3D
var mat_scissors_handle_p1: StandardMaterial3D
var mat_scissors_handle_p2: StandardMaterial3D
var mat_paper_ink: StandardMaterial3D
var mat_selected_halo_p1: StandardMaterial3D
var mat_selected_halo_p2: StandardMaterial3D
var mat_selected_light_pillar_p1: StandardMaterial3D
var mat_selected_light_pillar_p2: StandardMaterial3D
var mat_digest_rune: StandardMaterial3D
var mat_slash_beam: StandardMaterial3D

func _ready() -> void:
	game_type = GameTypes.RPC
	_setup_materials()
	_build_board_architecture()
	_build_center_arena()
	_build_selection_pedestals()
	_build_score_trackers()
	super._ready()

func _process(delta: float) -> void:
	_anim_time += delta * 3.5

	# Gentle idle floating bob and rotation on pedestal objects
	for k in pedestal_objects.keys():
		var obj = pedestal_objects[k]
		if is_instance_valid(obj):
			var is_selected: bool = (k == my_selected_choice)
			if is_selected:
				obj.position.y = 0.082 + sin(_anim_time * 2.2) * 0.008
				obj.rotation_degrees.y += delta * 35.0
			else:
				obj.position.y = 0.050 + sin(_anim_time * 1.5 + (0.0 if k == "rock" else (1.8 if k == "paper" else 3.6))) * 0.003
				obj.rotation_degrees.y = 0.0

	# Pulsing and rotating selection halos and light pillars
	for k in selection_halos.keys():
		var halo = selection_halos[k]
		if is_instance_valid(halo) and halo.visible:
			var s: float = 1.0 + sin(_anim_time * 2.0) * 0.06
			halo.scale = Vector3(s, 1.0, s)
			halo.rotation_degrees.y += delta * 45.0

	for k in selection_aura_rings.keys():
		var aura = selection_aura_rings[k]
		if is_instance_valid(aura) and aura.visible:
			var s_a: float = 1.0 + sin(_anim_time * 2.0 + 1.2) * 0.08
			aura.scale = Vector3(s_a, 1.0, s_a)
			aura.rotation_degrees.y -= delta * 30.0

	for k in selection_light_pillars.keys():
		var pillar = selection_light_pillars[k]
		if is_instance_valid(pillar) and pillar.visible:
			var s_p: float = 1.0 + sin(_anim_time * 3.0) * 0.04
			pillar.scale = Vector3(s_p, 1.0, s_p)

# --- Materials Setup ---

func _setup_materials() -> void:
	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.06, 0.16, 0.09)
	mat_felt_base.roughness = 0.95

	mat_mahogany_dark = StandardMaterial3D.new()
	mat_mahogany_dark.albedo_color = Color(0.15, 0.08, 0.05)
	mat_mahogany_dark.metallic = 0.04
	mat_mahogany_dark.roughness = 0.38
	mat_mahogany_dark.clearcoat_enabled = true
	mat_mahogany_dark.clearcoat = 0.60

	mat_walnut_frame = StandardMaterial3D.new()
	mat_walnut_frame.albedo_color = Color(0.24, 0.14, 0.08)
	mat_walnut_frame.metallic = 0.05
	mat_walnut_frame.roughness = 0.32
	mat_walnut_frame.clearcoat_enabled = true
	mat_walnut_frame.clearcoat = 0.68

	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.96, 0.80, 0.28)
	mat_gold_trim.metallic = 0.94
	mat_gold_trim.roughness = 0.18
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.88
	mat_gold_trim.emission_enabled = true
	mat_gold_trim.emission = Color(0.32, 0.24, 0.06)

	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.92, 0.95, 1.0)
	mat_platinum_trim.metallic = 0.95
	mat_platinum_trim.roughness = 0.14
	mat_platinum_trim.clearcoat_enabled = true
	mat_platinum_trim.clearcoat = 0.90

	mat_arena_velvet = StandardMaterial3D.new()
	mat_arena_velvet.albedo_color = Color(0.07, 0.09, 0.14)
	mat_arena_velvet.roughness = 0.80

	mat_pedestal_velvet = StandardMaterial3D.new()
	mat_pedestal_velvet.albedo_color = Color(0.12, 0.14, 0.20)
	mat_pedestal_velvet.roughness = 0.70

	mat_pedestal_hover = StandardMaterial3D.new()
	mat_pedestal_hover.albedo_color = Color(1.0, 0.90, 0.45)
	mat_pedestal_hover.metallic = 0.85
	mat_pedestal_hover.roughness = 0.16
	mat_pedestal_hover.emission_enabled = true
	mat_pedestal_hover.emission = Color(0.96, 0.78, 0.22)
	mat_pedestal_hover.emission_energy_multiplier = 0.85

	mat_selected_halo = StandardMaterial3D.new()
	mat_selected_halo.albedo_color = Color(1.0, 0.92, 0.35)
	mat_selected_halo.metallic = 0.90
	mat_selected_halo.roughness = 0.12
	mat_selected_halo.emission_enabled = true
	mat_selected_halo.emission = Color(1.0, 0.84, 0.20)
	mat_selected_halo.emission_energy_multiplier = 1.6

	# Score Gem Materials
	mat_socket_unlit = StandardMaterial3D.new()
	mat_socket_unlit.albedo_color = Color(0.18, 0.18, 0.20)
	mat_socket_unlit.metallic = 0.40
	mat_socket_unlit.roughness = 0.60

	mat_ruby_gem = StandardMaterial3D.new()
	mat_ruby_gem.albedo_color = Color(0.65, 0.08, 0.12)
	mat_ruby_gem.metallic = 0.10
	mat_ruby_gem.roughness = 0.20

	mat_ruby_lit = StandardMaterial3D.new()
	mat_ruby_lit.albedo_color = Color(1.0, 0.20, 0.25)
	mat_ruby_lit.metallic = 0.25
	mat_ruby_lit.roughness = 0.10
	mat_ruby_lit.emission_enabled = true
	mat_ruby_lit.emission = Color(1.0, 0.15, 0.22)
	mat_ruby_lit.emission_energy_multiplier = 2.2

	mat_sapphire_gem = StandardMaterial3D.new()
	mat_sapphire_gem.albedo_color = Color(0.08, 0.22, 0.65)
	mat_sapphire_gem.metallic = 0.10
	mat_sapphire_gem.roughness = 0.20

	mat_sapphire_lit = StandardMaterial3D.new()
	mat_sapphire_lit.albedo_color = Color(0.20, 0.55, 1.0)
	mat_sapphire_lit.metallic = 0.25
	mat_sapphire_lit.roughness = 0.10
	mat_sapphire_lit.emission_enabled = true
	mat_sapphire_lit.emission = Color(0.18, 0.50, 1.0)
	mat_sapphire_lit.emission_energy_multiplier = 2.2

	# Physical 3D Object Materials
	# Rock: Dark Obsidian Mineral
	mat_rock_obsidian = StandardMaterial3D.new()
	mat_rock_obsidian.albedo_color = Color(0.14, 0.15, 0.18)
	mat_rock_obsidian.metallic = 0.25
	mat_rock_obsidian.roughness = 0.48

	mat_rock_crystal_p1 = StandardMaterial3D.new()
	mat_rock_crystal_p1.albedo_color = Color(0.85, 0.12, 0.18)
	mat_rock_crystal_p1.metallic = 0.30
	mat_rock_crystal_p1.roughness = 0.15
	mat_rock_crystal_p1.emission_enabled = true
	mat_rock_crystal_p1.emission = Color(0.80, 0.10, 0.15)
	mat_rock_crystal_p1.emission_energy_multiplier = 0.85

	mat_rock_crystal_p2 = StandardMaterial3D.new()
	mat_rock_crystal_p2.albedo_color = Color(0.12, 0.45, 0.90)
	mat_rock_crystal_p2.metallic = 0.30
	mat_rock_crystal_p2.roughness = 0.15
	mat_rock_crystal_p2.emission_enabled = true
	mat_rock_crystal_p2.emission = Color(0.10, 0.40, 0.85)
	mat_rock_crystal_p2.emission_energy_multiplier = 0.85

	# Paper: Antique Illuminated Parchment
	mat_paper_parchment = StandardMaterial3D.new()
	mat_paper_parchment.albedo_color = Color(0.95, 0.90, 0.78)
	mat_paper_parchment.roughness = 0.55

	mat_paper_gold_leaf = StandardMaterial3D.new()
	mat_paper_gold_leaf.albedo_color = Color(0.96, 0.82, 0.32)
	mat_paper_gold_leaf.metallic = 0.90
	mat_paper_gold_leaf.roughness = 0.20
	mat_paper_gold_leaf.emission_enabled = true
	mat_paper_gold_leaf.emission = Color(0.35, 0.28, 0.08)

	mat_paper_seal_p1 = StandardMaterial3D.new()
	mat_paper_seal_p1.albedo_color = Color(0.72, 0.10, 0.14)
	mat_paper_seal_p1.roughness = 0.30

	mat_paper_seal_p2 = StandardMaterial3D.new()
	mat_paper_seal_p2.albedo_color = Color(0.10, 0.30, 0.72)
	mat_paper_seal_p2.roughness = 0.30

	# Scissors: Damascus Steel & Royal Filigree Handles
	mat_scissors_damascus = StandardMaterial3D.new()
	mat_scissors_damascus.albedo_color = Color(0.90, 0.92, 0.96)
	mat_scissors_damascus.metallic = 0.96
	mat_scissors_damascus.roughness = 0.12
	mat_scissors_damascus.clearcoat_enabled = true
	mat_scissors_damascus.clearcoat = 0.95

	mat_scissors_handle_p1 = StandardMaterial3D.new()
	mat_scissors_handle_p1.albedo_color = Color(0.85, 0.65, 0.22)
	mat_scissors_handle_p1.metallic = 0.88
	mat_scissors_handle_p1.roughness = 0.22

	mat_scissors_handle_p2 = StandardMaterial3D.new()
	mat_scissors_handle_p2.albedo_color = Color(0.75, 0.82, 0.95)
	mat_scissors_handle_p2.metallic = 0.92
	mat_scissors_handle_p2.roughness = 0.18

	# Scissors Razor Edge (Chrome Mirror)
	mat_scissors_edge = StandardMaterial3D.new()
	mat_scissors_edge.albedo_color = Color(0.98, 0.99, 1.0)
	mat_scissors_edge.metallic = 0.99
	mat_scissors_edge.roughness = 0.04
	mat_scissors_edge.clearcoat_enabled = true
	mat_scissors_edge.clearcoat = 1.0

	# Persian Gilded Ink for Calligraphy Lines
	mat_paper_ink = StandardMaterial3D.new()
	mat_paper_ink.albedo_color = Color(0.28, 0.18, 0.08)
	mat_paper_ink.roughness = 0.85
	mat_paper_ink.metallic = 0.12

	# Color-Specific Selection Halos
	mat_selected_halo_p1 = StandardMaterial3D.new()
	mat_selected_halo_p1.albedo_color = Color(1.0, 0.22, 0.28)
	mat_selected_halo_p1.metallic = 0.85
	mat_selected_halo_p1.roughness = 0.15
	mat_selected_halo_p1.emission_enabled = true
	mat_selected_halo_p1.emission = Color(1.0, 0.18, 0.24)
	mat_selected_halo_p1.emission_energy_multiplier = 2.4

	mat_selected_halo_p2 = StandardMaterial3D.new()
	mat_selected_halo_p2.albedo_color = Color(0.20, 0.60, 1.0)
	mat_selected_halo_p2.metallic = 0.85
	mat_selected_halo_p2.roughness = 0.15
	mat_selected_halo_p2.emission_enabled = true
	mat_selected_halo_p2.emission = Color(0.18, 0.55, 1.0)
	mat_selected_halo_p2.emission_energy_multiplier = 2.4

	# Ascending Light Pillar Materials
	mat_selected_light_pillar_p1 = StandardMaterial3D.new()
	mat_selected_light_pillar_p1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_selected_light_pillar_p1.albedo_color = Color(1.0, 0.25, 0.30, 0.24)
	mat_selected_light_pillar_p1.emission_enabled = true
	mat_selected_light_pillar_p1.emission = Color(1.0, 0.18, 0.22)
	mat_selected_light_pillar_p1.emission_energy_multiplier = 1.6
	mat_selected_light_pillar_p1.cull_mode = BaseMaterial3D.CULL_DISABLED

	mat_selected_light_pillar_p2 = StandardMaterial3D.new()
	mat_selected_light_pillar_p2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_selected_light_pillar_p2.albedo_color = Color(0.22, 0.60, 1.0, 0.24)
	mat_selected_light_pillar_p2.emission_enabled = true
	mat_selected_light_pillar_p2.emission = Color(0.18, 0.50, 1.0)
	mat_selected_light_pillar_p2.emission_energy_multiplier = 1.6
	mat_selected_light_pillar_p2.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Mystic Digestion Talisman Rune Material
	mat_digest_rune = StandardMaterial3D.new()
	mat_digest_rune.albedo_color = Color(0.35, 1.0, 0.55)
	mat_digest_rune.metallic = 0.50
	mat_digest_rune.roughness = 0.20
	mat_digest_rune.emission_enabled = true
	mat_digest_rune.emission = Color(0.30, 1.0, 0.50)
	mat_digest_rune.emission_energy_multiplier = 3.0

	# Slash Beam VFX Material
	mat_slash_beam = StandardMaterial3D.new()
	mat_slash_beam.albedo_color = Color(1.0, 0.95, 0.45)
	mat_slash_beam.metallic = 0.90
	mat_slash_beam.roughness = 0.10
	mat_slash_beam.emission_enabled = true
	mat_slash_beam.emission = Color(1.0, 0.88, 0.25)
	mat_slash_beam.emission_energy_multiplier = 2.5

# --- 3D Architecture & Dueling Arena ---

func _build_board_architecture() -> void:
	var arch = Node3D.new()
	arch.name = "BoardArchitecture"
	add_child(arch)

	# Felt Base Pad
	var felt = MeshInstance3D.new()
	var felt_box = BoxMesh.new()
	felt_box.size = Vector3(1.38, 0.010, 1.22)
	felt.mesh = felt_box
	felt.material_override = mat_felt_base
	felt.position = Vector3(0, -0.024, 0)
	arch.add_child(felt)

func _build_center_arena() -> void:
	arena_center = Node3D.new()
	arena_center.name = "DuelingArenaCenter"
	arena_center.position = Vector3(0, 0.040, -0.14)
	add_child(arena_center)

	# Raised Circular Dueling Platform
	var dais = MeshInstance3D.new()
	var dais_cyl = CylinderMesh.new()
	dais_cyl.top_radius = 0.29
	dais_cyl.bottom_radius = 0.31
	dais_cyl.height = 0.022
	dais_cyl.radial_segments = 36
	dais.mesh = dais_cyl
	dais.material_override = mat_mahogany_dark
	dais.position = Vector3(0, 0.011, 0)
	arena_center.add_child(dais)

	# 24K Gold Dais Trim Ring
	var trim = MeshInstance3D.new()
	var trim_torus = TorusMesh.new()
	trim_torus.inner_radius = 0.28
	trim_torus.outer_radius = 0.305
	trim_torus.rings = 36
	trim_torus.ring_segments = 14
	trim.mesh = trim_torus
	trim.material_override = mat_gold_trim
	trim.position = Vector3(0, 0.022, 0)
	arena_center.add_child(trim)

	# Inner Celestial Velvet Circle
	var velvet = MeshInstance3D.new()
	var velvet_cyl = CylinderMesh.new()
	velvet_cyl.top_radius = 0.275
	velvet_cyl.bottom_radius = 0.275
	velvet_cyl.height = 0.006
	velvet_cyl.radial_segments = 32
	velvet.mesh = velvet_cyl
	velvet.material_override = mat_arena_velvet
	velvet.position = Vector3(0, 0.023, 0)
	arena_center.add_child(velvet)

	# 8 Inlaid Golden Starburst Rays
	for i in range(8):
		var angle: float = float(i) * (TAU / 8.0)
		var ray = MeshInstance3D.new()
		var ray_box = BoxMesh.new()
		ray_box.size = Vector3(0.005, 0.002, 0.24)
		ray.mesh = ray_box
		ray.material_override = mat_gold_trim
		ray.position = Vector3(sin(angle) * 0.13, 0.0265, cos(angle) * 0.13)
		ray.rotation = Vector3(0, angle, 0)
		arena_center.add_child(ray)

	clash_container = Node3D.new()
	clash_container.name = "ClashContainer"
	arena_center.add_child(clash_container)

# --- 3D Selection Pedestals & Interactive Objects ---

func _build_selection_pedestals() -> void:
	pedestals.clear()
	pedestal_areas.clear()
	pedestal_objects.clear()
	selection_halos.clear()
	selection_aura_rings.clear()
	selection_light_pillars.clear()
	hover_rings.clear()

	var choices = [
		{"type": "rock", "name_fa": "سنگ", "x": -0.38},
		{"type": "paper", "name_fa": "کاغذ", "x": 0.0},
		{"type": "cutter", "name_fa": "قیچی", "x": 0.38}
	]

	var ped_group = Node3D.new()
	ped_group.name = "SelectionPedestalsGroup"
	ped_group.position = Vector3(0, 0.040, 0.28)
	add_child(ped_group)

	for ch in choices:
		var c_type: String = ch["type"]
		var c_name: String = ch["name_fa"]
		var px: float = ch["x"]

		var ped = Node3D.new()
		ped.name = "Pedestal_" + c_type
		ped.position = Vector3(px, 0, 0)
		ped_group.add_child(ped)
		pedestals[c_type] = ped

		# Octagonal / Circular Carved Walnut Pedestal Base
		var base_mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.135
		cyl.bottom_radius = 0.148
		cyl.height = 0.034
		cyl.radial_segments = 28
		base_mesh.mesh = cyl
		base_mesh.material_override = mat_walnut_frame
		base_mesh.position = Vector3(0, 0.017, 0)
		ped.add_child(base_mesh)

		# 24K Gold Trim Rim
		var rim = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.130
		torus.outer_radius = 0.144
		torus.rings = 28
		rim.mesh = torus
		rim.material_override = mat_gold_trim
		rim.position = Vector3(0, 0.034, 0)
		ped.add_child(rim)

		# Velvet Cushion Top
		var cushion = MeshInstance3D.new()
		var c_cyl = CylinderMesh.new()
		c_cyl.top_radius = 0.126
		c_cyl.bottom_radius = 0.126
		c_cyl.height = 0.008
		c_cyl.radial_segments = 24
		cushion.mesh = c_cyl
		cushion.material_override = mat_pedestal_velvet
		cushion.position = Vector3(0, 0.035, 0)
		ped.add_child(cushion)

		# Target Hover Ring (illuminates on mouse hover)
		var h_ring = MeshInstance3D.new()
		var hr_torus = TorusMesh.new()
		hr_torus.inner_radius = 0.116
		hr_torus.outer_radius = 0.128
		hr_torus.rings = 24
		h_ring.mesh = hr_torus
		h_ring.material_override = mat_pedestal_hover
		h_ring.position = Vector3(0, 0.0395, 0)
		h_ring.visible = false
		ped.add_child(h_ring)
		hover_rings[c_type] = h_ring

		# Selected Halo Ring (pulses around selected object)
		var s_halo = MeshInstance3D.new()
		var sh_torus = TorusMesh.new()
		sh_torus.inner_radius = 0.122
		sh_torus.outer_radius = 0.136
		sh_torus.rings = 28
		s_halo.mesh = sh_torus
		s_halo.material_override = mat_selected_halo_p1
		s_halo.position = Vector3(0, 0.040, 0)
		s_halo.visible = false
		ped.add_child(s_halo)
		selection_halos[c_type] = s_halo

		# Concentric Inner Selection Aura Ring
		var s_aura = MeshInstance3D.new()
		var sa_torus = TorusMesh.new()
		sa_torus.inner_radius = 0.098
		sa_torus.outer_radius = 0.114
		sa_torus.rings = 24
		s_aura.mesh = sa_torus
		s_aura.material_override = mat_selected_halo_p1
		s_aura.position = Vector3(0, 0.038, 0)
		s_aura.visible = false
		ped.add_child(s_aura)
		selection_aura_rings[c_type] = s_aura

		# Ascending Pillar of Light (radiant column in player color)
		var s_pillar = MeshInstance3D.new()
		var sp_cyl = CylinderMesh.new()
		sp_cyl.top_radius = 0.116
		sp_cyl.bottom_radius = 0.128
		sp_cyl.height = 0.38
		sp_cyl.radial_segments = 24
		sp_cyl.cap_top = false
		sp_cyl.cap_bottom = false
		s_pillar.mesh = sp_cyl
		s_pillar.material_override = mat_selected_light_pillar_p1
		s_pillar.position = Vector3(0, 0.22, 0)
		s_pillar.visible = false
		ped.add_child(s_pillar)
		selection_light_pillars[c_type] = s_pillar

		# 3D Persian Label ("سنگ", "کاغذ", "قیچی")
		var lbl = Label3D.new()
		lbl.text = c_name
		lbl.font = _FONT_FA
		lbl.font_size = 46
		lbl.pixel_size = 0.0008
		lbl.modulate = Color(1.0, 0.92, 0.70)
		lbl.outline_size = 4
		lbl.outline_modulate = Color(0.12, 0.06, 0.02)
		lbl.rotation_degrees = Vector3(-90, 0, 0)
		lbl.position = Vector3(0, 0.041, 0.170)
		ped.add_child(lbl)

		# The Physical 3D Object Resting on Pedestal
		var obj = _create_object_by_type(c_type, my_player_index if my_player_index in [1, 2] else 1)
		obj.name = "Object_" + c_type
		obj.position = Vector3(0, 0.050, 0)
		ped.add_child(obj)
		pedestal_objects[c_type] = obj

		# Interactive Area3D Hitbox for Clicking/Hovering
		var area = Area3D.new()
		area.name = "PedestalArea_" + c_type
		area.set_meta("rpc_type", c_type)
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 1
		var col = CollisionShape3D.new()
		var c_shape = CylinderShape3D.new()
		c_shape.radius = 0.18
		c_shape.height = 0.35
		col.shape = c_shape
		col.position = Vector3(0, 0.14, 0)
		area.add_child(col)
		ped.add_child(area)
		pedestal_areas[c_type] = area

# --- Score Trackers & Status Labels ---

func _build_score_trackers() -> void:
	p1_sockets.clear()
	p1_gems.clear()
	p2_sockets.clear()
	p2_gems.clear()

	var tracker_group = Node3D.new()
	tracker_group.name = "ScoreTrackersGroup"
	tracker_group.position = Vector3(0, 0.040, -0.42)
	add_child(tracker_group)

	# 1. Player 1 (Red) Turn-Round Sockets (5 pips on Left)
	for i in range(5):
		var sx: float = -0.46 + float(i) * 0.065
		var sock = MeshInstance3D.new()
		var sc = CylinderMesh.new()
		sc.top_radius = 0.024
		sc.bottom_radius = 0.026
		sc.height = 0.014
		sock.mesh = sc
		sock.material_override = mat_gold_trim
		sock.position = Vector3(sx, 0.007, 0)
		tracker_group.add_child(sock)
		p1_sockets.append(sock)

		var gem = MeshInstance3D.new()
		var gc = SphereMesh.new()
		gc.radius = 0.016
		gc.height = 0.018
		gem.mesh = gc
		gem.material_override = mat_socket_unlit
		gem.position = Vector3(sx, 0.016, 0)
		tracker_group.add_child(gem)
		p1_gems.append(gem)

	# 2. Player 2 (Blue) Turn-Round Sockets (5 pips on Right)
	for i in range(5):
		var sx: float = 0.20 + float(i) * 0.065
		var sock = MeshInstance3D.new()
		var sc = CylinderMesh.new()
		sc.top_radius = 0.024
		sc.bottom_radius = 0.026
		sc.height = 0.014
		sock.mesh = sc
		sock.material_override = mat_platinum_trim
		sock.position = Vector3(sx, 0.007, 0)
		tracker_group.add_child(sock)
		p2_sockets.append(sock)

		var gem = MeshInstance3D.new()
		var gc = SphereMesh.new()
		gc.radius = 0.016
		gc.height = 0.018
		gem.mesh = gc
		gem.material_override = mat_socket_unlit
		gem.position = Vector3(sx, 0.016, 0)
		tracker_group.add_child(gem)
		p2_gems.append(gem)

	# Center Turn-Round Progress Label ("دست ۱ از ۵")
	lbl_turn_round_status = Label3D.new()
	lbl_turn_round_status.text = "دست %s از ۵" % _fa_digits(1)
	lbl_turn_round_status.font = _FONT_FA
	lbl_turn_round_status.font_size = 38
	lbl_turn_round_status.pixel_size = 0.00075
	lbl_turn_round_status.modulate = Color(1.0, 0.88, 0.45)
	lbl_turn_round_status.outline_size = 4
	lbl_turn_round_status.outline_modulate = Color(0.10, 0.05, 0.02)
	lbl_turn_round_status.rotation_degrees = Vector3(-90, 0, 0)
	lbl_turn_round_status.position = Vector3(0, 0.020, 0)
	tracker_group.add_child(lbl_turn_round_status)

func _update_score_trackers() -> void:
	for i in range(5):
		if i < p1_gems.size() and is_instance_valid(p1_gems[i]):
			p1_gems[i].material_override = mat_ruby_lit if (i < p1_turn_round_score) else mat_socket_unlit
		if i < p2_gems.size() and is_instance_valid(p2_gems[i]):
			p2_gems[i].material_override = mat_sapphire_lit if (i < p2_turn_round_score) else mat_socket_unlit
	if is_instance_valid(lbl_turn_round_status):
		lbl_turn_round_status.text = "دست %s از ۵" % _fa_digits(clamp(current_turn_round_num, 1, 5))

# --- Procedural 3D Model Constructors for Rock, Paper, Scissors ---

func _create_object_by_type(choice_type: String, gamer_id: int) -> Node3D:
	match choice_type:
		"rock":
			return _create_rock_node(gamer_id)
		"paper":
			return _create_paper_node(gamer_id)
		"cutter":
			return _create_scissors_node(gamer_id)
		_:
			return _create_rock_node(gamer_id)

func _create_rock_node(gamer_id: int) -> Node3D:
	var rock = Node3D.new()

	# 1. Main Obsidian Polyhedral Boulder
	var body = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.068
	sphere.height = 0.115
	sphere.radial_segments = 14
	sphere.rings = 8
	body.mesh = sphere
	body.material_override = mat_rock_obsidian
	body.position = Vector3(0, 0.055, 0)
	rock.add_child(body)

	# 2. Glowing Geode Crystalline Clusters
	var mat_crystal = mat_rock_crystal_p1 if gamer_id == 1 else mat_rock_crystal_p2
	for ang in [0.4, 2.2, 4.3]:
		var crystal = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(0.026, 0.046, 0.026)
		crystal.mesh = prism
		crystal.material_override = mat_crystal
		crystal.position = Vector3(cos(ang) * 0.044, 0.065, sin(ang) * 0.044)
		crystal.rotation = Vector3(0.2, ang, 0.3)
		rock.add_child(crystal)

	# 3. 24K Gold Inlaid Runic Band
	var band = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.055
	torus.outer_radius = 0.066
	torus.rings = 20
	band.mesh = torus
	band.material_override = mat_gold_trim if gamer_id == 1 else mat_platinum_trim
	band.position = Vector3(0, 0.052, 0)
	band.rotation_degrees = Vector3(18, 25, 0)
	rock.add_child(band)

	return rock

func _create_paper_node(gamer_id: int) -> Node3D:
	var paper = Node3D.new()
	var seal_mat = mat_paper_seal_p1 if gamer_id == 1 else mat_paper_seal_p2
	var trim_mat = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. LEFT HALF of the Illuminated Manuscript Scroll
	var left_half = Node3D.new()
	left_half.name = "LeftHalf"
	paper.add_child(left_half)

	# Left parchment sheet body
	var left_sheet = MeshInstance3D.new()
	var left_box = BoxMesh.new()
	left_box.size = Vector3(0.068, 0.005, 0.164)
	left_sheet.mesh = left_box
	left_sheet.material_override = mat_paper_parchment
	left_sheet.position = Vector3(-0.034, 0.052, 0)
	left_half.add_child(left_sheet)

	# Gold Leaf Filigree Border on Left Outer Edge
	var left_border = MeshInstance3D.new()
	var lb_box = BoxMesh.new()
	lb_box.size = Vector3(0.006, 0.006, 0.166)
	left_border.mesh = lb_box
	left_border.material_override = mat_paper_gold_leaf
	left_border.position = Vector3(-0.066, 0.0525, 0)
	left_half.add_child(left_border)

	# Top and Bottom Gold Trim Strips (Left)
	for z_end in [-0.080, 0.080]:
		var strip = MeshInstance3D.new()
		var s_box = BoxMesh.new()
	s_box.size = Vector3(0.068, 0.006, 0.006)
		strip.mesh = s_box
		strip.material_override = mat_paper_gold_leaf
		strip.position = Vector3(-0.034, 0.0525, z_end)
		left_half.add_child(strip)

	# Persian Calligraphy Ink Lines on Left Page
	for l_z in [-0.050, -0.025, 0.0, 0.025, 0.050]:
		var ink_line = MeshInstance3D.new()
		var il_box = BoxMesh.new()
	il_box.size = Vector3(0.046, 0.002, 0.0035)
		ink_line.mesh = il_box
		ink_line.material_override = mat_paper_ink
		ink_line.position = Vector3(-0.034, 0.055, l_z)
		left_half.add_child(ink_line)

	# Left Turned Walnut Spindle Rod
	var left_rod = MeshInstance3D.new()
	var l_cyl = CylinderMesh.new()
	l_cyl.top_radius = 0.008
	l_cyl.bottom_radius = 0.008
	l_cyl.height = 0.190
	left_rod.mesh = l_cyl
	left_rod.material_override = mat_walnut_frame
	left_rod.position = Vector3(-0.071, 0.053, 0)
	left_rod.rotation_degrees = Vector3(90, 0, 0)
	left_half.add_child(left_rod)

	# Left Gilded Spindle Finials
	for z_finial in [-0.098, 0.098]:
		var finial = MeshInstance3D.new()
		var f_sph = SphereMesh.new()
		f_sph.radius = 0.012
		f_sph.height = 0.022
		finial.mesh = f_sph
		finial.material_override = trim_mat
		finial.position = Vector3(-0.071, 0.053, z_finial)
		left_half.add_child(finial)

	# Left Half of Imperial Wax Seal Medallion
	var left_seal = MeshInstance3D.new()
	var ls_cyl = CylinderMesh.new()
	ls_cyl.top_radius = 0.018
	ls_cyl.bottom_radius = 0.018
	ls_cyl.height = 0.008
	left_seal.mesh = ls_cyl
	left_seal.material_override = seal_mat
	left_seal.position = Vector3(-0.009, 0.057, 0.005)
	left_half.add_child(left_seal)

	# Left Cascading Silk Ribbon
	var left_ribbon = MeshInstance3D.new()
	var lr_box = BoxMesh.new()
	lr_box.size = Vector3(0.010, 0.003, 0.040)
	left_ribbon.mesh = lr_box
	left_ribbon.material_override = seal_mat
	left_ribbon.position = Vector3(-0.016, 0.055, 0.026)
	left_ribbon.rotation_degrees = Vector3(0, -18, 0)
	left_half.add_child(left_ribbon)

	# 2. RIGHT HALF of the Illuminated Manuscript Scroll
	var right_half = Node3D.new()
	right_half.name = "RightHalf"
	paper.add_child(right_half)

	# Right parchment sheet body
	var right_sheet = MeshInstance3D.new()
	var right_box = BoxMesh.new()
	right_box.size = Vector3(0.068, 0.005, 0.164)
	right_sheet.mesh = right_box
	right_sheet.material_override = mat_paper_parchment
	right_sheet.position = Vector3(0.034, 0.052, 0)
	right_half.add_child(right_sheet)

	# Gold Leaf Filigree Border on Right Outer Edge
	var right_border = MeshInstance3D.new()
	var rb_box = BoxMesh.new()
	rb_box.size = Vector3(0.006, 0.006, 0.166)
	right_border.mesh = rb_box
	right_border.material_override = mat_paper_gold_leaf
	right_border.position = Vector3(0.066, 0.0525, 0)
	right_half.add_child(right_border)

	# Top and Bottom Gold Trim Strips (Right)
	for z_end in [-0.080, 0.080]:
		var strip = MeshInstance3D.new()
		var s_box = BoxMesh.new()
	s_box.size = Vector3(0.068, 0.006, 0.006)
		strip.mesh = s_box
		strip.material_override = mat_paper_gold_leaf
		strip.position = Vector3(0.034, 0.0525, z_end)
		right_half.add_child(strip)

	# Persian Calligraphy Ink Lines on Right Page
	for l_z in [-0.050, -0.025, 0.0, 0.025, 0.050]:
		var ink_line = MeshInstance3D.new()
		var il_box = BoxMesh.new()
	il_box.size = Vector3(0.046, 0.002, 0.0035)
		ink_line.mesh = il_box
		ink_line.material_override = mat_paper_ink
		ink_line.position = Vector3(0.034, 0.055, l_z)
		right_half.add_child(ink_line)

	# Right Turned Walnut Spindle Rod
	var right_rod = MeshInstance3D.new()
	var r_cyl = CylinderMesh.new()
	r_cyl.top_radius = 0.008
	r_cyl.bottom_radius = 0.008
	r_cyl.height = 0.190
	right_rod.mesh = r_cyl
	right_rod.material_override = mat_walnut_frame
	right_rod.position = Vector3(0.071, 0.053, 0)
	right_rod.rotation_degrees = Vector3(90, 0, 0)
	right_half.add_child(right_rod)

	# Right Gilded Spindle Finials
	for z_finial in [-0.098, 0.098]:
		var finial = MeshInstance3D.new()
		var f_sph = SphereMesh.new()
		f_sph.radius = 0.012
		f_sph.height = 0.022
		finial.mesh = f_sph
		finial.material_override = trim_mat
		finial.position = Vector3(0.071, 0.053, z_finial)
		right_half.add_child(finial)

	# Right Half of Imperial Wax Seal Medallion
	var right_seal = MeshInstance3D.new()
	var rs_cyl = CylinderMesh.new()
	rs_cyl.top_radius = 0.018
	rs_cyl.bottom_radius = 0.018
	rs_cyl.height = 0.008
	right_seal.mesh = rs_cyl
	right_seal.material_override = seal_mat
	right_seal.position = Vector3(0.009, 0.057, 0.005)
	right_half.add_child(right_seal)

	# Right Cascading Silk Ribbon
	var right_ribbon = MeshInstance3D.new()
	var rr_box = BoxMesh.new()
	rr_box.size = Vector3(0.010, 0.003, 0.040)
	right_ribbon.mesh = rr_box
	right_ribbon.material_override = seal_mat
	right_ribbon.position = Vector3(0.016, 0.055, 0.026)
	right_ribbon.rotation_degrees = Vector3(0, 18, 0)
	right_half.add_child(right_ribbon)

	return paper

func _create_scissors_node(gamer_id: int) -> Node3D:
	var shears = Node3D.new()
	var mat_handle = mat_scissors_handle_p1 if gamer_id == 1 else mat_scissors_handle_p2
	var trim_mat = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. Left Blade & Royal Handle (BladeLeft)
	var left_half = Node3D.new()
	left_half.name = "BladeLeft"
	shears.add_child(left_half)

	# Damascus Steel Tapered Blade
	var b_left = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.015, 0.005, 0.132)
	b_left.mesh = b_box
	b_left.material_override = mat_scissors_damascus
	b_left.position = Vector3(-0.013, 0.050, -0.054)
	b_left.rotation_degrees = Vector3(0, -11, 0)
	left_half.add_child(b_left)

	# Mirror-Polished Chrome Razor Cutting Bevel Edge
	var edge_left = MeshInstance3D.new()
	var e_box = BoxMesh.new()
	e_box.size = Vector3(0.003, 0.004, 0.128)
	edge_left.mesh = e_box
	edge_left.material_override = mat_scissors_edge
	edge_left.position = Vector3(-0.006, 0.050, -0.054)
	edge_left.rotation_degrees = Vector3(0, -11, 0)
	left_half.add_child(edge_left)

	# Left Shank Arm
	var shank_left = MeshInstance3D.new()
	var s_cyl = CylinderMesh.new()
	s_cyl.top_radius = 0.006
	s_cyl.bottom_radius = 0.007
	s_cyl.height = 0.046
	shank_left.mesh = s_cyl
	shank_left.material_override = trim_mat
	shank_left.position = Vector3(-0.020, 0.050, 0.024)
	shank_left.rotation_degrees = Vector3(90, 20, 0)
	left_half.add_child(shank_left)

	# Left Royal Enamelled Bow Finger Ring
	var h_left = MeshInstance3D.new()
	var h_torus = TorusMesh.new()
	h_torus.inner_radius = 0.020
	h_torus.outer_radius = 0.032
	h_torus.rings = 28
	h_left.mesh = h_torus
	h_left.material_override = mat_handle
	h_left.position = Vector3(-0.038, 0.050, 0.060)
	h_left.rotation_degrees = Vector3(0, 0, 90)
	left_half.add_child(h_left)

	# Left Finger Rest Tang / Spur
	var tang_left = MeshInstance3D.new()
	var t_prism = PrismMesh.new()
	t_prism.size = Vector3(0.008, 0.022, 0.008)
	tang_left.mesh = t_prism
	tang_left.material_override = trim_mat
	tang_left.position = Vector3(-0.052, 0.050, 0.088)
	tang_left.rotation_degrees = Vector3(180, 30, 0)
	left_half.add_child(tang_left)

	# 2. Right Blade & Royal Handle (BladeRight)
	var right_half = Node3D.new()
	right_half.name = "BladeRight"
	shears.add_child(right_half)

	# Damascus Steel Tapered Blade
	var b_right = MeshInstance3D.new()
	b_right.mesh = b_box
	b_right.material_override = mat_scissors_damascus
	b_right.position = Vector3(0.013, 0.052, -0.054)
	b_right.rotation_degrees = Vector3(0, 11, 0)
	right_half.add_child(b_right)

	# Mirror-Polished Chrome Razor Cutting Bevel Edge
	var edge_right = MeshInstance3D.new()
	edge_right.mesh = e_box
	edge_right.material_override = mat_scissors_edge
	edge_right.position = Vector3(0.006, 0.052, -0.054)
	edge_right.rotation_degrees = Vector3(0, 11, 0)
	right_half.add_child(edge_right)

	# Right Shank Arm
	var shank_right = MeshInstance3D.new()
	shank_right.mesh = s_cyl
	shank_right.material_override = trim_mat
	shank_right.position = Vector3(0.020, 0.052, 0.024)
	shank_right.rotation_degrees = Vector3(90, -20, 0)
	right_half.add_child(shank_right)

	# Right Royal Enamelled Bow Finger Ring
	var h_right = MeshInstance3D.new()
	h_right.mesh = h_torus
	h_right.material_override = mat_handle
	h_right.position = Vector3(0.038, 0.050, 0.060)
	h_right.rotation_degrees = Vector3(0, 0, 90)
	right_half.add_child(h_right)

	# 3. Central Gold Pivot Joint & Gemstone Bolt (PivotJoint)
	var pivot_node = Node3D.new()
	pivot_node.name = "PivotJoint"
	shears.add_child(pivot_node)

	var pivot = MeshInstance3D.new()
	var p_cyl = CylinderMesh.new()
	p_cyl.top_radius = 0.015
	p_cyl.bottom_radius = 0.015
	p_cyl.height = 0.014
	pivot.mesh = p_cyl
	pivot.material_override = trim_mat
	pivot.position = Vector3(0, 0.051, 0)
	pivot_node.add_child(pivot)

	var jewel = MeshInstance3D.new()
	var j_sph = SphereMesh.new()
	j_sph.radius = 0.010
	j_sph.height = 0.015
	jewel.mesh = j_sph
	jewel.material_override = mat_ruby_gem if gamer_id == 1 else mat_sapphire_gem
	jewel.position = Vector3(0, 0.059, 0)
	pivot_node.add_child(jewel)

	var washer = MeshInstance3D.new()
	var w_torus = TorusMesh.new()
	w_torus.inner_radius = 0.014
	w_torus.outer_radius = 0.019
	w_torus.rings = 20
	washer.mesh = w_torus
	washer.material_override = trim_mat
	washer.position = Vector3(0, 0.046, 0)
	pivot_node.add_child(washer)

	return shears

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		_clear_hover()
		return

	if event is InputEventMouseMotion:
		_handle_pointer_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_pointer_down = true
			_press_screen_pos = event.position
			_press_down_time = Time.get_ticks_msec() / 1000.0
			_handle_pointer_hover(event.position)
		else:
			if _is_pointer_down:
				_is_pointer_down = false
				var dist = _press_screen_pos.distance_to(event.position)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _press_down_time
				if dist <= 28.0 and elapsed < 0.8:
					_handle_pointer_tap(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_pointer_down = true
			_press_screen_pos = event.position
			_press_down_time = Time.get_ticks_msec() / 1000.0
			_handle_pointer_hover(event.position)
		else:
			if _is_pointer_down:
				_is_pointer_down = false
				var dist = _press_screen_pos.distance_to(event.position)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _press_down_time
				if dist <= 28.0 and elapsed < 0.8:
					_handle_pointer_tap(event.position)

func _raycast_choice_at(screen_pos: Vector2) -> String:
	var viewport = get_viewport()
	if not viewport:
		return ""
	var cam = viewport.get_camera_3d()
	if not cam:
		return ""
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 12.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var col_obj = result["collider"]
		if col_obj and col_obj.has_meta("rpc_type"):
			return str(col_obj.get_meta("rpc_type"))
	return ""

func _handle_pointer_hover(screen_pos: Vector2) -> void:
	var choice = _raycast_choice_at(screen_pos)
	if choice == hovered_choice:
		return
	hovered_choice = choice
	_update_hover_visuals()

func _clear_hover() -> void:
	if hovered_choice.is_empty():
		return
	hovered_choice = ""
	_update_hover_visuals()

func _update_hover_visuals() -> void:
	for k in hover_rings.keys():
		var hr = hover_rings[k]
		if is_instance_valid(hr):
			hr.visible = (k == hovered_choice and not is_board_locked)

func _handle_pointer_tap(screen_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_click_time < 0.20:
		return
	var choice = _raycast_choice_at(screen_pos)
	if choice.is_empty():
		return
	_select_choice(choice)

func _select_choice(choice: String) -> void:
	if is_board_locked or not GameManager.is_game_active:
		return
	_last_click_time = Time.get_ticks_msec() / 1000.0
	my_selected_choice = choice
	is_choice_confirmed = true
	AudioManager.play_sound("tap")

	var p_idx: int = my_player_index if my_player_index in [1, 2] else 1
	var halo_mat = mat_selected_halo_p1 if p_idx == 1 else mat_selected_halo_p2
	var pillar_mat = mat_selected_light_pillar_p1 if p_idx == 1 else mat_selected_light_pillar_p2
	var p_color = Color(1.0, 0.22, 0.28) if p_idx == 1 else Color(0.20, 0.60, 1.0)

	# Update Selection Halos, Auras, and Pillars with player color
	for k in selection_halos.keys():
		var halo = selection_halos[k]
		if is_instance_valid(halo):
			halo.material_override = halo_mat
			halo.visible = (k == choice)
	for k in selection_aura_rings.keys():
		var aura = selection_aura_rings[k]
		if is_instance_valid(aura):
			aura.material_override = halo_mat
			aura.visible = (k == choice)
	for k in selection_light_pillars.keys():
		var pillar = selection_light_pillars[k]
		if is_instance_valid(pillar):
			pillar.material_override = pillar_mat
			pillar.visible = (k == choice)

	# Rich Radial Burst VFX at pedestal upon selection
	if pedestals.has(choice) and is_instance_valid(pedestals[choice]):
		_spawn_selection_burst(pedestals[choice].global_position + Vector3(0, 0.045, 0), p_color)

	# Tactile pop-lift animation on selected object
	if pedestal_objects.has(choice) and is_instance_valid(pedestal_objects[choice]):
		var obj = pedestal_objects[choice]
		var tw = _create_tracked_tween()
		tw.tween_property(obj, "scale", Vector3(1.32, 1.32, 1.32), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(obj, "scale", Vector3.ONE, 0.14)

	# Update HUD banner in real-time
	var choice_names = {"rock": "سنگ", "paper": "کاغذ", "cutter": "قیچی"}
	var c_fa = choice_names.get(choice, choice)
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud) and hud.has_method("set_custom_banner"):
		hud.set_custom_banner("✅ انتخاب شما: %s (می‌توانید تغییر دهید)" % c_fa)

	# 1:1 with Flutter RPCController.acceptSelection():
	send_move(Commands.Select_Peace, choice)

# --- BaseGameBoard Lifecycle & RPC Hooks ---
func setup_board(_game_data: Dictionary) -> void:
	reset_board()

func on_new_turn_round() -> void:
	# Unlock board and prepare next turn-round
	set_board_locked(false)
	is_choice_confirmed = false
	my_selected_choice = ""
	for k in selection_halos.keys():
		if is_instance_valid(selection_halos[k]):
			selection_halos[k].visible = false
	for k in selection_aura_rings.keys():
		if is_instance_valid(selection_aura_rings[k]):
			selection_aura_rings[k].visible = false
	for k in selection_light_pillars.keys():
		if is_instance_valid(selection_light_pillars[k]):
			selection_light_pillars[k].visible = false
	_clear_clash_nodes()
	_update_score_trackers()

func on_finish_turn_round(data: Dictionary) -> void:
	# Both players' choices revealed! Play dramatic clash in arena.
	set_board_locked(true)
	_clear_hover()

	var turn_winner = int(data.get("Winner", 0))
	var p1_sel = str(data.get("P1_selection", "rock")).to_lower()
	var p2_sel = str(data.get("P2_selection", "rock")).to_lower()

	# Update internal turn-round scores (1:1 with backend check_turn_round_winner)
	if turn_winner == 1:
		p1_turn_round_score += 1
	elif turn_winner == 2:
		p2_turn_round_score += 1

	if current_turn_round_num < 5:
		current_turn_round_num += 1

	_play_clash_sequence(p1_sel, p2_sel, turn_winner)

func on_round_finished(payload: Variant) -> void:
	set_board_locked(true)
	var round_winner = int(payload.get("Winner", payload.get("winner", 0))) if typeof(payload) == TYPE_DICTIONARY else int(payload)

	# Update match total scores
	if round_winner == 1:
		p1_match_score += 1
	elif round_winner == 2:
		p2_match_score += 1

	# Reset turn-round score pips for next round
	p1_turn_round_score = 0
	p2_turn_round_score = 0
	current_turn_round_num = 1
	current_round_num += 1

	# Celebration VFX
	var my_idx = GameManager.my_player_index
	if round_winner == my_idx:
		AudioManager.play_sound("win")
		ActionVFXManager.play_win_celebration_vfx(self, arena_center.global_position, my_idx)
	elif round_winner > 0:
		AudioManager.play_sound("lose")
	else:
		AudioManager.play_sound("draw")

	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			_update_score_trackers()
	)

func on_new_round(_round_num: int) -> void:
	reset_board()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("round_scores") and typeof(g_data["round_scores"]) == TYPE_ARRAY:
			var rs = g_data["round_scores"]
			if rs.size() >= 2:
				p1_turn_round_score = int(rs[0])
				p2_turn_round_score = int(rs[1])
		if g_data.has("total_scores") and typeof(g_data["total_scores"]) == TYPE_ARRAY:
			var ts = g_data["total_scores"]
			if ts.size() >= 2:
				p1_match_score = int(ts[0])
				p2_match_score = int(ts[1])
		current_round_num = int(g_data.get("current_round", 1))
		current_turn_round_num = int(g_data.get("current_turn__round", 1))

	_update_score_trackers()

func reset_board() -> void:
	_clear_hover()
	_kill_all_tweens()
	_clear_clash_nodes()
	p1_turn_round_score = 0
	p2_turn_round_score = 0
	is_choice_confirmed = false
	my_selected_choice = "rock"
	var p_idx: int = my_player_index if my_player_index in [1, 2] else 1
	var halo_mat = mat_selected_halo_p1 if p_idx == 1 else mat_selected_halo_p2
	var pillar_mat = mat_selected_light_pillar_p1 if p_idx == 1 else mat_selected_light_pillar_p2
	for k in selection_halos.keys():
		if is_instance_valid(selection_halos[k]):
			selection_halos[k].material_override = halo_mat
			selection_halos[k].visible = (k == "rock")
	for k in selection_aura_rings.keys():
		if is_instance_valid(selection_aura_rings[k]):
			selection_aura_rings[k].material_override = halo_mat
			selection_aura_rings[k].visible = (k == "rock")
	for k in selection_light_pillars.keys():
		if is_instance_valid(selection_light_pillars[k]):
			selection_light_pillars[k].material_override = pillar_mat
			selection_light_pillars[k].visible = (k == "rock")
	_update_score_trackers()

func cleanup_board() -> void:
	_kill_all_tweens()
	_clear_clash_nodes()

# --- Clash Sequence & Cinematic VFX ---

func _clear_clash_nodes() -> void:
	if is_instance_valid(clash_container):
		for child in clash_container.get_children():
			child.queue_free()
	p1_clash_node = null
	p2_clash_node = null

func _play_clash_sequence(p1_sel: String, p2_sel: String, winner_id: int) -> void:
	_clear_clash_nodes()

	# Spawn P1's object on Left and P2's object on Right
	p1_clash_node = _create_object_by_type(p1_sel, 1)
	p1_clash_node.position = Vector3(-0.24, 0.16, 0.0)
	p1_clash_node.scale = Vector3(0.1, 0.1, 0.1)
	clash_container.add_child(p1_clash_node)

	p2_clash_node = _create_object_by_type(p2_sel, 2)
	p2_clash_node.position = Vector3(0.24, 0.16, 0.0)
	p2_clash_node.scale = Vector3(0.1, 0.1, 0.1)
	clash_container.add_child(p2_clash_node)

	AudioManager.play_sound("move_peace")

	# 1. Entrance: Fly into arena and scale up
	var tw = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p1_clash_node, "scale", Vector3(1.3, 1.3, 1.3), 0.35)
	tw.tween_property(p2_clash_node, "scale", Vector3(1.3, 1.3, 1.3), 0.35)

	# 2. Anticipation: Pull back slightly
	var tw2 = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw2.tween_property(p1_clash_node, "position:x", -0.28, 0.20).set_delay(0.38)
	tw2.tween_property(p2_clash_node, "position:x", 0.28, 0.20).set_delay(0.38)

	# 3. THE CLASH: Rush together to center
	var tw3 = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw3.tween_property(p1_clash_node, "position:x", -0.04, 0.14).set_delay(0.58)
	tw3.tween_property(p2_clash_node, "position:x", 0.04, 0.14).set_delay(0.58)

	# 4. Impact Resolution based on outcome
	tw3.chain().tween_callback(func():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_resolve_clash_impact(p1_sel, p2_sel, winner_id)
	)

func _resolve_clash_impact(p1_sel: String, p2_sel: String, winner_id: int) -> void:
	if not is_instance_valid(p1_clash_node) or not is_instance_valid(p2_clash_node):
		return

	var center_world = arena_center.global_position + Vector3(0, 0.18, 0)

	if winner_id == 0:
		# DRAW: Clash and bounce back with dual shockwaves
		AudioManager.play_sound("hit")
		var tw = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p1_clash_node, "position:x", -0.16, 0.22)
		tw.tween_property(p2_clash_node, "position:x", 0.16, 0.22)
		_spawn_clash_ring(center_world, Color(1.0, 0.90, 0.40))
		_spawn_clash_ring(center_world + Vector3(0, 0.02, 0), Color(0.9, 0.95, 1.0))
	else:
		var winning_node = p1_clash_node if winner_id == 1 else p2_clash_node
		var losing_node = p2_clash_node if winner_id == 1 else p1_clash_node
		var win_color = Color(1.0, 0.25, 0.30) if winner_id == 1 else Color(0.28, 0.65, 1.0)
		var win_sel = p1_sel if winner_id == 1 else p2_sel
		var lose_sel = p2_sel if winner_id == 1 else p1_sel

		if win_sel == "rock" and lose_sel == "cutter":
			# 1. Rock SMASHES and BREAKS Scissors into flying pieces!
			_play_rock_smash_scissors_vfx(center_world, winning_node, losing_node, winner_id, win_color)
		elif win_sel == "cutter" and lose_sel == "paper":
			# 2. Scissors SNIPS and CUTS Paper scroll into two separate halves!
			_play_scissors_cut_paper_vfx(center_world, winning_node, losing_node, winner_id, win_color)
		elif win_sel == "paper" and lose_sel == "rock":
			# 3. Paper scroll ENFOLDS and DIGESTS Rock into itself!
			_play_paper_digest_rock_vfx(center_world, winning_node, losing_node, winner_id, win_color)

		# Winning halo on victor
		_spawn_victory_halo(winning_node, win_color)

	_update_score_trackers()

# --- 1. Clash VFX: Rock Smashes Scissors (Physical Fracture & Break) ---
func _play_rock_smash_scissors_vfx(center_world: Vector3, winning_node: Node3D, losing_node: Node3D, winner_id: int, win_color: Color) -> void:
	# Heavy camera shake & impact SFX
	ActionVFXManager.shake_camera(0.12, 0.50)
	AudioManager.play_sound("hit")
	AudioManager.play_sound("add_peace")

	# Dual expanding shockwaves
	_spawn_clash_ring(center_world, win_color)
	_spawn_clash_ring(center_world + Vector3(0, 0.02, 0), Color(1.0, 0.90, 0.35))

	# Flying physical stone debris shards & metallic fracture sparks
	_spawn_stone_debris(center_world)
	_spawn_metallic_sparks(center_world)
	ActionVFXManager.play_piece_drop_vfx(self, center_world, win_color)

	# Rock meteor crushing movement: heavy squash on impact, then elastic rebound
	var tw_rock = _create_tracked_tween()
	tw_rock.tween_property(winning_node, "position:y", 0.40, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_rock.parallel().tween_property(winning_node, "rotation_degrees:x", -25.0, 0.12)
	tw_rock.chain().tween_property(winning_node, "position:y", 0.07, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_rock.parallel().tween_property(winning_node, "scale", Vector3(1.50, 0.70, 1.50), 0.06)
	tw_rock.parallel().tween_property(winning_node, "rotation_degrees:x", 0.0, 0.06)
	tw_rock.chain().tween_property(winning_node, "position:y", 0.14, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_rock.parallel().tween_property(winning_node, "scale", Vector3(1.25, 1.25, 1.25), 0.12)

	# Scissors Physical Destruction:
	# 1. Pivot joint snaps off and pops upward spinning
	if losing_node.has_node("PivotJoint"):
		var pivot = losing_node.get_node("PivotJoint")
		var tw_p = _create_tracked_tween()
		tw_p.tween_property(pivot, "position", pivot.position + Vector3(randf_range(-0.04, 0.04), 0.32, randf_range(0.12, 0.24)), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_p.parallel().tween_property(pivot, "rotation_degrees", Vector3(540, 720, 360), 0.45)
		tw_p.chain().tween_property(pivot, "position:y", -0.05, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_p.parallel().tween_property(pivot, "scale", Vector3.ZERO, 0.22)

	# 2. BladeLeft snaps, spins 920 deg, rockets towards left boundary
	if losing_node.has_node("BladeLeft"):
		var bl = losing_node.get_node("BladeLeft")
		var tw_bl = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_bl.tween_property(bl, "position", bl.position + Vector3(-0.36, -0.04, 0.15), 0.42)
		tw_bl.tween_property(bl, "rotation_degrees:z", -920.0, 0.42)
		tw_bl.tween_property(bl, "rotation_degrees:x", 75.0, 0.42)
		tw_bl.tween_property(bl, "scale", Vector3(0.35, 0.35, 0.35), 0.42)

	# 3. BladeRight snaps, spins -920 deg, rockets towards right boundary
	if losing_node.has_node("BladeRight"):
		var br = losing_node.get_node("BladeRight")
		var tw_br = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_br.tween_property(br, "position", br.position + Vector3(0.36, -0.04, 0.15), 0.42)
		tw_br.tween_property(br, "rotation_degrees:z", 920.0, 0.42)
		tw_br.tween_property(br, "rotation_degrees:x", -75.0, 0.42)
		tw_br.tween_property(br, "scale", Vector3(0.35, 0.35, 0.35), 0.42)

	# Fallback for unexpected hierarchy
	if not losing_node.has_node("BladeLeft") and not losing_node.has_node("BladeRight"):
		var tw_scissors = _create_tracked_tween().set_parallel(true)
		var knockback_dir = 0.34 if winner_id == 1 else -0.34
		tw_scissors.tween_property(losing_node, "position", losing_node.position + Vector3(knockback_dir, -0.06, 0.12), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_scissors.tween_property(losing_node, "rotation_degrees:z", 720.0 if winner_id == 1 else -720.0, 0.42)
		tw_scissors.tween_property(losing_node, "scale", Vector3(0.35, 0.35, 0.35), 0.42)

# --- 2. Clash VFX: Scissors Cuts Paper (Physical Severance & Flutter) ---
func _play_scissors_cut_paper_vfx(center_world: Vector3, winning_node: Node3D, losing_node: Node3D, winner_id: int, win_color: Color) -> void:
	# 1. Scissors Open Blades and Lunge Forward
	var bl: Node3D = winning_node.get_node_or_null("BladeLeft")
	var br: Node3D = winning_node.get_node_or_null("BladeRight")

	if is_instance_valid(bl) and is_instance_valid(br):
		var tw_open = _create_tracked_tween().set_parallel(true)
		tw_open.tween_property(bl, "rotation_degrees:y", -32.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_open.tween_property(br, "rotation_degrees:y", 32.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Shears thrust forward to center
	var tw_thrust = _create_tracked_tween()
	tw_thrust.tween_property(winning_node, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. SNIP SHUT & SLICE!
	tw_thrust.chain().tween_callback(func():
		AudioManager.play_sound("hit")
		AudioManager.play_sound("move_peace")
		ActionVFXManager.shake_camera(0.07, 0.30)
		_spawn_slash_arc(center_world)
		_spawn_clash_ring(center_world, win_color)
		_spawn_paper_cut_fragments(center_world)
	)

	if is_instance_valid(bl) and is_instance_valid(br):
		var tw_snip = _create_tracked_tween().set_parallel(true)
		tw_snip.tween_property(bl, "rotation_degrees:y", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.16)
		tw_snip.tween_property(br, "rotation_degrees:y", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.16)

	# 4. Paper scroll physically severs into LeftHalf and RightHalf
	var p_left: Node3D = losing_node.get_node_or_null("LeftHalf")
	var p_right: Node3D = losing_node.get_node_or_null("RightHalf")

	if is_instance_valid(p_left) and is_instance_valid(p_right):
		var tw_cut = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Left half separates left, tilts and drifts down
		tw_cut.tween_property(p_left, "position", Vector3(-0.18, -0.015, 0.04), 0.48).set_delay(0.17)
		tw_cut.tween_property(p_left, "rotation_degrees", Vector3(18.0, -28.0, -42.0), 0.48).set_delay(0.17)
		tw_cut.tween_property(p_left, "scale", Vector3(0.5, 0.5, 0.5), 0.48).set_delay(0.17)
		# Right half separates right, tilts and drifts down
		tw_cut.tween_property(p_right, "position", Vector3(0.18, -0.015, 0.04), 0.48).set_delay(0.17)
		tw_cut.tween_property(p_right, "rotation_degrees", Vector3(18.0, 28.0, 42.0), 0.48).set_delay(0.17)
		tw_cut.tween_property(p_right, "scale", Vector3(0.5, 0.5, 0.5), 0.48).set_delay(0.17)
	else:
		var tw_lose = _create_tracked_tween().set_parallel(true)
		tw_lose.tween_property(losing_node, "position:y", 0.04, 0.38).set_delay(0.17)
		tw_lose.tween_property(losing_node, "rotation_degrees:x", 75.0, 0.38).set_delay(0.17)
		tw_lose.tween_property(losing_node, "scale", Vector3(0.2, 0.2, 0.2), 0.38).set_delay(0.17)

	# 5. Winning scissors victory snip flourish
	var tw_flourish = _create_tracked_tween()
	tw_flourish.tween_property(winning_node, "position", Vector3(0, 0.18, 0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	tw_flourish.parallel().tween_property(winning_node, "scale", Vector3(1.4, 1.4, 1.4), 0.25)

# --- 3. Clash VFX: Paper Digests Rock (Absorption & Talisman Cocoon) ---
func _play_paper_digest_rock_vfx(center_world: Vector3, winning_node: Node3D, losing_node: Node3D, winner_id: int, win_color: Color) -> void:
	AudioManager.play_sound("move_peace")
	AudioManager.play_sound("tap")

	# 1. Paper scroll ascends majestically above the rock
	var tw_scroll = _create_tracked_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_scroll.tween_property(winning_node, "position", Vector3(0, 0.28, 0), 0.35)
	tw_scroll.tween_property(winning_node, "scale", Vector3(1.55, 1.55, 1.55), 0.35)
	tw_scroll.tween_property(winning_node, "rotation_degrees:x", 25.0, 0.35)

	# 2. Mystic Talisman Digestion Runes illuminate beneath rock
	_spawn_digestion_runes(arena_center.global_position + Vector3(0, 0.026, 0), win_color)

	# 3. Glowing parchment ribbons wrap around rock
	_spawn_digest_wrapping_ribbons(center_world)

	# 4. Rock trembles and is absorbed/digested into the parchment cocoon
	var tw_rock = _create_tracked_tween()
	for s in range(4):
		tw_rock.tween_property(losing_node, "position:x", randf_range(-0.015, 0.015), 0.04)
	# Rock shrinks and ascends directly into scroll center
	tw_rock.chain().tween_property(losing_node, "position:y", 0.26, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_rock.parallel().tween_property(losing_node, "scale", Vector3(0.04, 0.04, 0.04), 0.35)
	tw_rock.chain().tween_callback(func():
		AudioManager.play_sound("add_peace")
		ActionVFXManager.shake_camera(0.06, 0.30)
		_spawn_digest_motes(center_world + Vector3(0, 0.12, 0))
		_spawn_clash_ring(center_world + Vector3(0, 0.12, 0), Color(0.35, 1.0, 0.55))
		if is_instance_valid(losing_node):
			losing_node.visible = false
	)

	# 5. Enchanted Scroll seals shut triumphantly
	tw_scroll.chain().tween_property(winning_node, "scale", Vector3(1.35, 1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_scroll.parallel().tween_property(winning_node, "position:y", 0.18, 0.18)

# --- Procedural VFX Mesh Generators ---
func _spawn_selection_burst(world_pos: Vector3, player_color: Color) -> void:
	var burst_root = Node3D.new()
	add_child(burst_root)
	burst_root.global_position = world_pos

	# Expanding Ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.11
	torus.rings = 24
	ring.mesh = torus
	var mat_ring = StandardMaterial3D.new()
	mat_ring.albedo_color = player_color
	mat_ring.emission_enabled = true
	mat_ring.emission = player_color
	mat_ring.emission_energy_multiplier = 3.2
	ring.material_override = mat_ring
	burst_root.add_child(ring)

	var tw_ring = _create_tracked_tween().set_parallel(true)
	tw_ring.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(mat_ring, "albedo_color:a", 0.0, 0.30)

	# 10 Rising Radiant Sparks
	for i in range(10):
		var spark = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.007
		sph.height = 0.014
		spark.mesh = sph
		spark.material_override = mat_ring
		burst_root.add_child(spark)

		var angle: float = float(i) * (TAU / 10.0)
		var dist: float = randf_range(0.08, 0.16)
		var end_pos = Vector3(cos(angle) * dist, randf_range(0.12, 0.28), sin(angle) * dist)
		var tw_sp = _create_tracked_tween()
		tw_sp.tween_property(spark, "position", end_pos, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_sp.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.32)

	get_tree().create_timer(0.40).timeout.connect(burst_root.queue_free)

func _spawn_paper_cut_fragments(world_pos: Vector3) -> void:
	var root = Node3D.new()
	arena_center.add_child(root)
	root.global_position = world_pos

	for i in range(16):
		var scrap = MeshInstance3D.new()
		var box = BoxMesh.new()
		var sx = randf_range(0.015, 0.032)
		var sz = randf_range(0.015, 0.032)
		box.size = Vector3(sx, 0.002, sz)
		scrap.mesh = box
		scrap.material_override = mat_paper_parchment if (i % 2 == 0) else mat_paper_gold_leaf
		root.add_child(scrap)

		var angle = randf_range(0, TAU)
		var dist = randf_range(0.12, 0.36)
		var peak_y = randf_range(0.14, 0.32)
		var mid_pos = Vector3(cos(angle) * dist * 0.5, peak_y, sin(angle) * dist * 0.5)
		var end_pos = Vector3(cos(angle) * dist, -0.04, sin(angle) * dist)

		var tw = _create_tracked_tween()
		tw.tween_property(scrap, "position", mid_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(scrap, "rotation_degrees", Vector3(randf_range(-360, 360), randf_range(-360, 360), randf_range(-360, 360)), 0.65)
		tw.chain().tween_property(scrap, "position", end_pos, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(scrap, "scale", Vector3.ZERO, 0.45)

	get_tree().create_timer(0.70).timeout.connect(root.queue_free)

func _spawn_digestion_runes(world_pos: Vector3, tint: Color) -> void:
	var rune_root = Node3D.new()
	arena_center.add_child(rune_root)
	rune_root.global_position = world_pos

	# Outer Runic Circle
	var circle = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.18
	torus.rings = 28
	circle.mesh = torus
	circle.material_override = mat_digest_rune
	rune_root.add_child(circle)

	# 6 Radial Talisman Glyph Boxes
	for i in range(6):
		var angle: float = float(i) * (TAU / 6.0)
		var glyph = MeshInstance3D.new()
		var g_box = BoxMesh.new()
		g_box.size = Vector3(0.012, 0.003, 0.045)
		glyph.mesh = g_box
		glyph.material_override = mat_digest_rune
		glyph.position = Vector3(cos(angle) * 0.17, 0.002, sin(angle) * 0.17)
		glyph.rotation = Vector3(0, -angle, 0)
		rune_root.add_child(glyph)

	var tw = _create_tracked_tween().set_parallel(true)
	tw.tween_property(rune_root, "scale", Vector3(1.3, 1.0, 1.3), 0.60)
	tw.tween_property(rune_root, "rotation_degrees:y", 90.0, 0.60)
	tw.chain().tween_property(rune_root, "scale", Vector3.ZERO, 0.20)
	tw.chain().tween_callback(rune_root.queue_free)

func _spawn_digest_wrapping_ribbons(world_pos: Vector3) -> void:
	var ribbon_root = Node3D.new()
	arena_center.add_child(ribbon_root)
	ribbon_root.global_position = world_pos

	for i in range(3):
		var rib = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.075 + float(i) * 0.015
		torus.outer_radius = 0.088 + float(i) * 0.015
		torus.rings = 24
		rib.mesh = torus
		rib.material_override = mat_paper_gold_leaf
		rib.rotation_degrees = Vector3(randf_range(-35, 35), float(i) * 60.0, randf_range(-35, 35))
		ribbon_root.add_child(rib)

		var tw = _create_tracked_tween().set_parallel(true)
		tw.tween_property(rib, "rotation_degrees:y", rib.rotation_degrees.y + 360.0, 0.55)
		tw.tween_property(rib, "position:y", 0.10 + float(i) * 0.04, 0.55)
		tw.chain().tween_property(rib, "scale", Vector3.ZERO, 0.18)

	get_tree().create_timer(0.75).timeout.connect(ribbon_root.queue_free)

func _spawn_digest_motes(world_pos: Vector3) -> void:
	var mote_root = Node3D.new()
	arena_center.add_child(mote_root)
	mote_root.global_position = world_pos

	for i in range(14):
		var mote = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.009
		sph.height = 0.018
		mote.mesh = sph
		mote.material_override = mat_digest_rune if (i % 2 == 0) else mat_paper_gold_leaf
		mote_root.add_child(mote)

		var angle = randf_range(0, TAU)
		var dist = randf_range(0.08, 0.28)
		var end_pos = Vector3(cos(angle) * dist, randf_range(0.10, 0.35), sin(angle) * dist)
		var tw = _create_tracked_tween()
		tw.tween_property(mote, "position", end_pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mote, "scale", Vector3.ZERO, 0.38)

	get_tree().create_timer(0.45).timeout.connect(mote_root.queue_free)

func _spawn_stone_debris(world_pos: Vector3) -> void:
	var debris_root = Node3D.new()
	arena_center.add_child(debris_root)
	debris_root.global_position = world_pos
	for i in range(14):
		var shard = MeshInstance3D.new()
		var prism = PrismMesh.new()
		var s_size = randf_range(0.018, 0.038)
		prism.size = Vector3(s_size, s_size * 1.4, s_size * 0.8)
		shard.mesh = prism
		shard.material_override = mat_rock_obsidian
		shard.rotation_degrees = Vector3(randf_range(-180, 180), randf_range(-180, 180), randf_range(-180, 180))
		debris_root.add_child(shard)
		var angle = randf_range(0, TAU)
		var dist = randf_range(0.18, 0.42)
		var peak_y = randf_range(0.22, 0.48)
		var end_pos = Vector3(cos(angle) * dist, -0.10, sin(angle) * dist)
		var mid_pos = Vector3(cos(angle) * dist * 0.5, peak_y, sin(angle) * dist * 0.5)
		var tw = _create_tracked_tween()
		tw.tween_property(shard, "position", mid_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "rotation_degrees", shard.rotation_degrees + Vector3(randf_range(-360, 360), randf_range(-360, 360), 0), 0.55)
		tw.chain().tween_property(shard, "position", end_pos, 0.33).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.33)
	get_tree().create_timer(0.65).timeout.connect(debris_root.queue_free)

func _spawn_metallic_sparks(world_pos: Vector3) -> void:
	var sparks_root = Node3D.new()
	arena_center.add_child(sparks_root)
	sparks_root.global_position = world_pos
	for i in range(12):
		var spark = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.007
		sphere.height = 0.014
		spark.mesh = sphere
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.90, 0.40)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.25)
		mat.emission_energy_multiplier = 4.0
		spark.material_override = mat
		sparks_root.add_child(spark)
		var angle = randf_range(0, TAU)
		var dist = randf_range(0.15, 0.38)
		var peak_y = randf_range(0.15, 0.35)
		var end_pos = Vector3(cos(angle) * dist, -0.05, sin(angle) * dist)
		var tw = _create_tracked_tween()
		tw.tween_property(spark, "position", Vector3(cos(angle) * dist * 0.5, peak_y, sin(angle) * dist * 0.5), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(spark, "position", end_pos, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.24)
	get_tree().create_timer(0.5).timeout.connect(sparks_root.queue_free)

func _spawn_clash_ring(world_pos: Vector3, tint: Color) -> void:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.04
	torus.outer_radius = 0.07
	torus.rings = 24
	ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 2.0
	ring.material_override = mat
	arena_center.add_child(ring)
	ring.global_position = world_pos
	var tw = _create_tracked_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.2, 3.2, 3.2), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_slash_arc(world_pos: Vector3) -> void:
	var slash = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.008
	cyl.height = 0.36
	slash.mesh = cyl
	slash.material_override = mat_slash_beam
	arena_center.add_child(slash)
	slash.global_position = world_pos
	slash.rotation_degrees = Vector3(45, 0, 45)
	slash.scale = Vector3(1.0, 0.05, 1.0)
	var tw = _create_tracked_tween()
	tw.tween_property(slash, "scale", Vector3(1.2, 1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slash, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(slash.queue_free)

func _spawn_victory_halo(parent_node: Node3D, tint: Color) -> void:
	var halo = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.10
	torus.rings = 24
	halo.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 2.4
	halo.material_override = mat
	halo.position = Vector3(0, 0.06, 0)
	parent_node.add_child(halo)
	var tw = _create_tracked_tween().set_loops(3)
	tw.tween_property(halo, "scale", Vector3(1.15, 1.15, 1.15), 0.22)
	tw.tween_property(halo, "scale", Vector3.ONE, 0.22)

func _create_tracked_tween() -> Tween:
	var tw = create_tween()
	_active_tweens.append(tw)
	return tw

func _kill_all_tweens() -> void:
	for tw in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()

func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(str(i), fa[i])
	return s
