class_name FekrBekr3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# FekrBekr (Mastermind / فکر و بکر) 3D Board Implementation
# Cafe Fekr - Deluxe Royal Vault & 12-Row Mastermind Arena
#
# Key Features:
# 1. Non-Repeating 4-Color Rule (Phase 1 & Phase 2):
#    - Selecting or dragging a color physically moves the peg out of its palette
#      pedestal dish into the target slot (preventing duplicate colors).
#    - Removing a peg from a slot flies it back into its home palette dish.
# 2. Dual Input: Instant Parabolic Flight on Tap + Full 3D Drag & Drop with VFX:
#    - Tap a palette peg -> parabolic 3D arc flight into the next empty slot +
#      expanding golden shockwave ring VFX.
#    - Drag a palette peg (or a placed slot peg) -> elevated 3D floating peg
#      with glowing target ring, real-time slot magnetic highlight, and drop/swap.
# 3. Deluxe 3D Boards for Phase 1 (Secret Vault Tray) & Phase 2 (12-Row Arena):
#    - Sculpted walnut & obsidian decks, corner brass pillars, 3D Persian row
#      numbers (۱..۱۲), glowing active row frame, and top Mystery Code Vault.
# ==============================================================================

# --- Camera Tuning for Full 12-Row Board ---
@export var camera_distance: float = 3.38
@export var camera_pitch: float = -1.16

# --- Geometry Constants (Phase 2 Playing Board) ---
const BOARD_W: float = 0.68
const BOARD_L: float = 1.76
const BOARD_H: float = 0.030
const NUM_VISIBLE_ROWS: int = 12
const NUM_PEGS: int = 4

# Row distribution for 12 guess rows:
# Row 0 (bottom / 1st try) to Row 11 (top / 12th try)
const ROW_Z_BOTTOM: float = 0.37
const ROW_Z_TOP: float = -0.65

# Peg X offsets (center-left area, shifted slightly right to make room for 3D row numbers)
const ROW_NUM_X: float = -0.268
const PEG_X_OFFSETS = [-0.175, -0.085, 0.005, 0.095]

# Pin Pad (large, prominent 2x2 feedback pins on the right)
const PIN_DIVIDER_X: float = 0.150
const PIN_GRID_X: float = 0.218
const PIN_OFFSET: float = 0.020

# Active Input Row & Palette (Phase 2 bottom dock)
const ACTIVE_ROW_Z: float = 0.505
const PALETTE_ROW1_Z: float = 0.625
const PALETTE_ROW2_Z: float = 0.725
const PALETTE_X_OFFSETS = [-0.18, -0.06, 0.06, 0.18]

# --- Phase 1 Setup Tray Dimensions (Deluxe Royal Vault Tray) ---
const TRAY_W: float = 0.64
const TRAY_L: float = 0.56
const TRAY_H: float = 0.032
const TRAY_SECRET_Z: float = -0.105
const TRAY_PALETTE_R1_Z: float = 0.065
const TRAY_PALETTE_R2_Z: float = 0.175
const TRAY_SECRET_X_OFFSETS = [-0.18, -0.06, 0.06, 0.18]
const TRAY_PALETTE_X_OFFSETS = [-0.18, -0.06, 0.06, 0.18]

# --- Color Definitions (8 Unique Gemstone Marbles) ---
const COLOR_VALUES: Dictionary = {
	1: Color(0.94, 0.16, 0.20), # Red Ruby
	2: Color(0.18, 0.48, 0.96), # Blue Sapphire
	3: Color(0.16, 0.84, 0.34), # Emerald Green
	4: Color(0.98, 0.84, 0.14), # Amber Gold
	5: Color(0.70, 0.24, 0.90), # Amethyst Purple
	6: Color(0.98, 0.52, 0.12), # Carnelian Orange
	7: Color(0.12, 0.84, 0.90), # Turquoise Cyan
	8: Color(0.95, 0.95, 0.96), # Pearl White
}

const FA_DIGITS = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹", "۱۰", "۱۱", "۱۲"]

enum ViewMode { MY_BOARD, OPP_BOARD, DUAL }

# --- State ---
var is_play_phase: bool = false
var current_round_num: int = 0
var current_view_mode: ViewMode = ViewMode.MY_BOARD

# Phase 1 setup selection [c0, c1, c2, c3]
var phase1_selection: Array = [0, 0, 0, 0]
var is_my_board_set: bool = false
var my_secret_board: Array = [0, 0, 0, 0]

# Phase 2 active guess selection [c0, c1, c2, c3]
var active_selection: Array = [0, 0, 0, 0]
var is_revealed: bool = false

# History of guesses
var my_choices: Array = []
var my_results: Array = []
var opp_choices: Array = []
var opp_results: Array = []

# --- Node Hierarchy Roots ---
var phase1_root: Node3D = null
var phase2_root: Node3D = null
var my_board_root: Node3D = null
var opp_board_root: Node3D = null

# Phase 1 Nodes & Palette Tracking
var phase1_slot_nodes: Array[Node3D] = []
var phase1_slot_pieces: Array[MeshInstance3D] = []
var phase1_slot_rings: Array[MeshInstance3D] = []
var phase1_palette_pegs: Dictionary = {} # color_id -> MeshInstance3D
var phase1_palette_positions: Dictionary = {} # color_id -> Vector3 (local to phase1_root)

# Phase 2 Row Nodes & Palette Tracking
var my_row_containers: Array[Node3D] = []
var my_row_pin_nodes: Array[Array] = []
var my_row_labels: Array[Label3D] = []
var opp_row_containers: Array[Node3D] = []
var opp_row_pin_nodes: Array[Array] = []
var opp_row_labels: Array[Label3D] = []

# Active input slot nodes (Phase 2)
var active_slot_nodes: Array[Node3D] = []
var active_slot_pieces: Array[MeshInstance3D] = []
var active_slot_rings: Array[MeshInstance3D] = []
var phase2_palette_pegs: Dictionary = {} # color_id -> MeshInstance3D
var phase2_palette_positions: Dictionary = {} # color_id -> Vector3 (local to my_board_root)

# Pointers & Active Row Frames
var my_row_pointer: Node3D = null
var opp_row_pointer: Node3D = null
var my_active_row_frame: Node3D = null
var opp_active_row_frame: Node3D = null

# --- 3D Drag & Drop State ---
var is_dragging_piece: bool = false
var _pointer_down: bool = false
var _pointer_start_screen: Vector2 = Vector2.ZERO
var _drag_color_id: int = 0
var _drag_source_slot: int = -1 # -1 = from palette, 0..3 = from slot
var _hovered_slot_idx: int = -1
var _drag_peg_node: Node3D = null
var _drag_peg_mesh: MeshInstance3D = null
var _drag_halo_mesh: MeshInstance3D = null

# Font & Materials
var _game_font: Font = null
var mat_wood_base: StandardMaterial3D
var mat_wood_rim: StandardMaterial3D
var mat_slate_player: StandardMaterial3D
var mat_slate_opp: StandardMaterial3D
var mat_vault_recess: StandardMaterial3D
var mat_brass_trim: StandardMaterial3D
var mat_socket_rim: StandardMaterial3D
var mat_gold_ring: StandardMaterial3D
var mat_hover_ring: StandardMaterial3D
var mat_active_row_glow: StandardMaterial3D
var mat_hole_concave: StandardMaterial3D
var mat_pin_black: StandardMaterial3D
var mat_pin_white: StandardMaterial3D
var piece_materials: Dictionary = {}
var dish_ring_materials: Dictionary = {}

func _init() -> void:
	game_type = GameTypes.FEKRBEKR

# ==============================================================================
# 1. INITIALIZATION & MATERIALS
# ==============================================================================

func _ready() -> void:
	game_type = GameTypes.FEKRBEKR
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		_game_font = load("res://assets/fonts/hekayat.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Vazir.ttf"):
		_game_font = load("res://assets/fonts/Vazir.ttf")
	_init_materials()
	_build_scene_hierarchy()
	_build_drag_ghost()
	_connect_hud_signals()
	super._ready()
	set_phase(is_play_phase)

func _init_materials() -> void:
	# Royal Walnut Plinth with warm satin sheen
	mat_wood_base = StandardMaterial3D.new()
	mat_wood_base.albedo_color = Color(0.20, 0.11, 0.05)
	mat_wood_base.roughness = 0.38
	mat_wood_base.metallic = 0.08
	mat_wood_base.clearcoat_enabled = true
	mat_wood_base.clearcoat = 0.35

	mat_wood_rim = StandardMaterial3D.new()
	mat_wood_rim.albedo_color = Color(0.13, 0.07, 0.03)
	mat_wood_rim.roughness = 0.35

	# Player Slate (deep emerald-obsidian satin)
	mat_slate_player = StandardMaterial3D.new()
	mat_slate_player.albedo_color = Color(0.07, 0.10, 0.12)
	mat_slate_player.roughness = 0.28
	mat_slate_player.metallic = 0.12

	# Opponent Slate (royal midnight sapphire-graphite)
	mat_slate_opp = StandardMaterial3D.new()
	mat_slate_opp.albedo_color = Color(0.07, 0.08, 0.14)
	mat_slate_opp.roughness = 0.28
	mat_slate_opp.metallic = 0.12

	# Recessed Vault / Dock Panel Material
	mat_vault_recess = StandardMaterial3D.new()
	mat_vault_recess.albedo_color = Color(0.04, 0.05, 0.07)
	mat_vault_recess.roughness = 0.42
	mat_vault_recess.metallic = 0.18

	# Polished Imperial Brass Trim & Corner Pillars
	mat_brass_trim = StandardMaterial3D.new()
	mat_brass_trim.albedo_color = Color(0.90, 0.74, 0.32)
	mat_brass_trim.metallic = 0.92
	mat_brass_trim.roughness = 0.20

	# Machined Socket Rim
	mat_socket_rim = StandardMaterial3D.new()
	mat_socket_rim.albedo_color = Color(0.78, 0.63, 0.28)
	mat_socket_rim.metallic = 0.88
	mat_socket_rim.roughness = 0.25

	# Active Gold Ring (luminous emissive gold)
	mat_gold_ring = StandardMaterial3D.new()
	mat_gold_ring.albedo_color = Color(1.0, 0.86, 0.28)
	mat_gold_ring.metallic = 0.95
	mat_gold_ring.roughness = 0.16
	mat_gold_ring.emission_enabled = true
	mat_gold_ring.emission = Color(0.55, 0.42, 0.10)

	# Magnetic Hover Highlight Ring (radiant emerald-gold glow during drag)
	mat_hover_ring = StandardMaterial3D.new()
	mat_hover_ring.albedo_color = Color(0.45, 1.0, 0.65)
	mat_hover_ring.metallic = 0.90
	mat_hover_ring.roughness = 0.12
	mat_hover_ring.emission_enabled = true
	mat_hover_ring.emission = Color(0.25, 0.85, 0.45)

	# Active Row Frame Glow
	mat_active_row_glow = StandardMaterial3D.new()
	mat_active_row_glow.albedo_color = Color(1.0, 0.84, 0.28)
	mat_active_row_glow.metallic = 0.90
	mat_active_row_glow.roughness = 0.18
	mat_active_row_glow.emission_enabled = true
	mat_active_row_glow.emission = Color(0.65, 0.48, 0.12)

	# Concave socket hole interior
	mat_hole_concave = StandardMaterial3D.new()
	mat_hole_concave.albedo_color = Color(0.025, 0.028, 0.035)
	mat_hole_concave.roughness = 0.88

	# Feedback Pins: Glossy Jet-Black Obsidian & Porcelain Pearl White
	mat_pin_black = StandardMaterial3D.new()
	mat_pin_black.albedo_color = Color(0.02, 0.02, 0.02)
	mat_pin_black.roughness = 0.10
	mat_pin_black.metallic = 0.18
	mat_pin_black.clearcoat_enabled = true
	mat_pin_black.clearcoat = 0.85

	mat_pin_white = StandardMaterial3D.new()
	mat_pin_white.albedo_color = Color(0.98, 0.98, 0.96)
	mat_pin_white.roughness = 0.10
	mat_pin_white.metallic = 0.06
	mat_pin_white.clearcoat_enabled = true
	mat_pin_white.clearcoat = 0.85

	# 8 Pure 3D Colored Gemstone Marble Materials + Subtle Dish Indicator Rings
	for color_id in COLOR_VALUES.keys():
		var col: Color = COLOR_VALUES[color_id]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.08
		mat.metallic = 0.10
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.90
		mat.emission_enabled = true
		mat.emission = col * 0.12
		piece_materials[color_id] = mat

		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = col.lerp(Color(0.85, 0.72, 0.35), 0.35)
		ring_mat.roughness = 0.25
		ring_mat.metallic = 0.75
		ring_mat.emission_enabled = true
		ring_mat.emission = col * 0.18
		dish_ring_materials[color_id] = ring_mat

func _connect_hud_signals() -> void:
	# Signal connections are managed centrally by Main scene to prevent duplicate triggers
	pass

func _get_hud() -> Control:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud):
		return hud
	return null

# ==============================================================================
# 2. SCENE HIERARCHY SETUP
# ==============================================================================

func _build_scene_hierarchy() -> void:
	# Root for Phase 1 (Deluxe Royal Setup Vault Tray)
	phase1_root = Node3D.new()
	phase1_root.name = "Phase1Root"
	add_child(phase1_root)
	_build_phase1_tray(phase1_root)

	# Root for Phase 2 (12-Row Mastermind Arena)
	phase2_root = Node3D.new()
	phase2_root.name = "Phase2Root"
	add_child(phase2_root)

	my_board_root = Node3D.new()
	my_board_root.name = "MyBoard"
	phase2_root.add_child(my_board_root)
	_build_play_board(my_board_root, mat_slate_player, true)

	opp_board_root = Node3D.new()
	opp_board_root.name = "OpponentBoard"
	phase2_root.add_child(opp_board_root)
	_build_play_board(opp_board_root, mat_slate_opp, false)

	_apply_view_mode_positions(ViewMode.MY_BOARD, false)

func _build_drag_ghost() -> void:
	_drag_peg_node = Node3D.new()
	_drag_peg_node.name = "DragGhostPeg"
	_drag_peg_node.visible = false
	add_child(_drag_peg_node)

	_drag_peg_mesh = _create_piece_mesh(1)
	_drag_peg_mesh.scale = Vector3(1.26, 1.26, 1.26)
	_drag_peg_node.add_child(_drag_peg_mesh)

	_drag_halo_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.026
	torus.outer_radius = 0.034
	torus.rings = 24
	torus.ring_segments = 12
	_drag_halo_mesh.mesh = torus
	_drag_halo_mesh.material_override = mat_hover_ring
	_drag_halo_mesh.position = Vector3(0, -0.018, 0)
	_drag_peg_node.add_child(_drag_halo_mesh)

func set_phase(play_phase: bool) -> void:
	_cancel_active_drag()
	is_play_phase = play_phase
	var hud = _get_hud()
	if hud and hud.has_method("set_fekrbekr_hud_buttons"):
		hud.set_fekrbekr_hud_buttons(play_phase)
	if not is_instance_valid(phase1_root) or not is_instance_valid(phase2_root):
		return
	if not play_phase:
		phase1_root.visible = true
		phase2_root.visible = false
		_clear_phase1_selection()
	else:
		phase1_root.visible = false
		phase2_root.visible = true
		var active_r = current_round_num - 1 if current_round_num > 0 else 0
		_update_active_row_pointer(my_row_pointer, my_active_row_frame, my_row_labels, active_r)
		_sync_palette_visibility()

# ==============================================================================
# 3. PHASE 1: DELUXE ROYAL SETUP TRAY (SECRET CODE VAULT)
# ==============================================================================

func _build_phase1_tray(root: Node3D) -> void:
	# 1. Sculpted Stepped Royal Walnut Plinth
	var outer_plinth = MeshInstance3D.new()
	var outer_mesh = BoxMesh.new()
	outer_mesh.size = Vector3(TRAY_W + 0.06, TRAY_H * 0.65, TRAY_L + 0.06)
	outer_mesh.material = mat_wood_rim
	outer_plinth.mesh = outer_mesh
	outer_plinth.position = Vector3(0, -TRAY_H * 0.65, 0)
	root.add_child(outer_plinth)

	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(TRAY_W + 0.036, TRAY_H, TRAY_L + 0.036)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, -TRAY_H * 0.5, 0)
	root.add_child(plinth)

	# 2. Inset Emerald-Obsidian Playing Deck
	var slab = MeshInstance3D.new()
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(TRAY_W, 0.014, TRAY_L)
	slab_mesh.material = mat_slate_player
	slab.mesh = slab_mesh
	slab.position = Vector3(0, 0.007, 0)
	root.add_child(slab)

	# 3. Brass Perimeter Bezel & Sculpted Corner Pillars
	_create_bezel(root, TRAY_W, TRAY_L, 0.014)
	_create_corner_brackets(root, TRAY_W, TRAY_L, 0.014)

	# 4. Top Secret Code Vault Recessed Panel
	var vault_panel = MeshInstance3D.new()
	var vp_mesh = BoxMesh.new()
	vp_mesh.size = Vector3(TRAY_W - 0.06, 0.004, 0.175)
	vp_mesh.material = mat_vault_recess
	vault_panel.mesh = vp_mesh
	vault_panel.position = Vector3(0, 0.015, TRAY_SECRET_Z - 0.012)
	root.add_child(vault_panel)

	_create_zone_frame(root, Vector3(0, 0.017, TRAY_SECRET_Z - 0.012), TRAY_W - 0.056, 0.178, mat_gold_ring)

	var lbl_vault = _create_3d_label("🔐 رمز ۴ رنگ مخفی برای حریف", 26, Color(1.0, 0.88, 0.36))
	lbl_vault.position = Vector3(0, 0.019, TRAY_SECRET_Z - 0.072)
	root.add_child(lbl_vault)

	# 5. The 4 Secret Code Sockets (Crowned Golden Chalices with Number Badges)
	phase1_slot_nodes.clear()
	phase1_slot_pieces.clear()
	phase1_slot_rings.clear()
	for col in range(NUM_PEGS):
		var pos_x = TRAY_SECRET_X_OFFSETS[col]
		var sock_node = _create_chalice_socket_mesh(0.028, 0.009, mat_hole_concave, mat_gold_ring)
		sock_node.position = Vector3(pos_x, 0.016, TRAY_SECRET_Z + 0.012)
		root.add_child(sock_node)
		phase1_slot_nodes.append(sock_node)

		var hover_ring = _create_slot_hover_ring(0.032, 0.038)
		hover_ring.position = Vector3(pos_x, 0.018, TRAY_SECRET_Z + 0.012)
		root.add_child(hover_ring)
		phase1_slot_rings.append(hover_ring)

		var num_lbl = _create_3d_label(FA_DIGITS[col + 1], 20, Color(0.92, 0.78, 0.42))
		num_lbl.position = Vector3(pos_x, 0.019, TRAY_SECRET_Z - 0.032)
		root.add_child(num_lbl)

		var piece = _create_piece_mesh(1)
		piece.position = Vector3(pos_x, 0.036, TRAY_SECRET_Z + 0.012)
		piece.visible = false
		root.add_child(piece)
		phase1_slot_pieces.append(piece)

		_create_slot_interaction_area(root, Vector3(pos_x, 0.028, TRAY_SECRET_Z + 0.012), 0.034, col, true)

	# 6. Recessed Gemstone Palette Well (Bottom Zone)
	var pal_panel = MeshInstance3D.new()
	var pp_mesh = BoxMesh.new()
	pp_mesh.size = Vector3(TRAY_W - 0.06, 0.004, 0.255)
	pp_mesh.material = mat_vault_recess
	pal_panel.mesh = pp_mesh
	pal_panel.position = Vector3(0, 0.015, (TRAY_PALETTE_R1_Z + TRAY_PALETTE_R2_Z) * 0.5 - 0.008)
	root.add_child(pal_panel)

	_create_zone_frame(root, Vector3(0, 0.017, (TRAY_PALETTE_R1_Z + TRAY_PALETTE_R2_Z) * 0.5 - 0.008), TRAY_W - 0.056, 0.258, mat_brass_trim)

	var lbl_pal = _create_3d_label("🎨 مهره را لمس کنید یا به جایگاه بکشید", 21, Color(0.86, 0.82, 0.72))
	lbl_pal.position = Vector3(0, 0.019, TRAY_PALETTE_R1_Z - 0.062)
	root.add_child(lbl_pal)

	phase1_palette_pegs.clear()
	phase1_palette_positions.clear()
	_build_palette(
		root,
		TRAY_PALETTE_R1_Z,
		TRAY_PALETTE_R2_Z,
		TRAY_PALETTE_X_OFFSETS,
		0.016,
		phase1_palette_pegs,
		phase1_palette_positions,
		true
	)

func _on_phase1_color_selected(color_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or is_play_phase:
		return
	# Prevent duplicate colors across the 4 slots
	var existing_idx = phase1_selection.find(color_id)
	if existing_idx != -1:
		AudioManager.play_sound("tap_wrong")
		_pulse_slot_ring(phase1_slot_rings[existing_idx])
		show_hint("این رنگ در جایگاه %s قرار دارد؛ رنگ تکراری مجاز نیست." % FA_DIGITS[existing_idx + 1])
		return
	# Find next empty slot
	for i in range(4):
		if phase1_selection[i] == 0:
			var from_pos = phase1_palette_positions.get(color_id, phase1_slot_pieces[i].position)
			_place_color_in_slot(i, color_id, true, from_pos)
			return
	AudioManager.play_sound("tap_wrong")
	show_hint("همه ۴ جایگاه پر شده‌اند؛ برای تعویض، مهره را روی جایگاه بکشید یا لمس کنید.")

func _on_phase1_slot_clicked(col_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or is_play_phase:
		return
	var color_id = int(phase1_selection[col_idx])
	if color_id != 0:
		AudioManager.play_sound("tap")
		phase1_selection[col_idx] = 0
		_animate_slot_return_to_palette(phase1_root, phase1_slot_pieces[col_idx], color_id, phase1_palette_positions.get(color_id, Vector3.ZERO))
		_sync_palette_visibility()

func _clear_phase1_selection() -> void:
	phase1_selection = [0, 0, 0, 0]
	_update_phase1_slots()
	_sync_palette_visibility()

func _update_phase1_slots() -> void:
	if phase1_slot_pieces.size() < 4:
		return
	for i in range(4):
		var c_id = int(phase1_selection[i])
		var p_mesh = phase1_slot_pieces[i]
		if c_id > 0 and piece_materials.has(c_id):
			p_mesh.material_override = piece_materials[c_id]
			p_mesh.visible = true
			p_mesh.scale = Vector3.ONE
			p_mesh.position = Vector3(TRAY_SECRET_X_OFFSETS[i], 0.036, TRAY_SECRET_Z + 0.012)
		else:
			p_mesh.visible = false
	_sync_palette_visibility()

# ==============================================================================
# 4. PHASE 2: FULL 12-ROW MASTERMIND ARENA
# ==============================================================================

func _build_play_board(root: Node3D, slate_mat: Material, is_player_board: bool) -> void:
	# 1. Stepped Royal Walnut Plinth
	var outer_plinth = MeshInstance3D.new()
	var outer_mesh = BoxMesh.new()
	outer_mesh.size = Vector3(BOARD_W + 0.056, BOARD_H * 0.65, BOARD_L + 0.056)
	outer_mesh.material = mat_wood_rim
	outer_plinth.mesh = outer_mesh
	outer_plinth.position = Vector3(0, -BOARD_H * 0.65, 0)
	root.add_child(outer_plinth)

	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(BOARD_W + 0.036, BOARD_H, BOARD_L + 0.036)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, -BOARD_H * 0.5, 0)
	root.add_child(plinth)

	# 2. Inset Playing Deck
	var slab = MeshInstance3D.new()
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(BOARD_W, 0.014, BOARD_L)
	slab_mesh.material = slate_mat
	slab.mesh = slab_mesh
	slab.position = Vector3(0, 0.007, 0)
	root.add_child(slab)

	# 3. Perimeter Bezel & Sculpted Corner Pillars
	_create_bezel(root, BOARD_W, BOARD_L, 0.014)
	_create_corner_brackets(root, BOARD_W, BOARD_L, 0.014)

	# 4. Top Mystery Code Vault Header (z = -0.765)
	_build_top_mystery_vault_hood(root, is_player_board)

	# 5. Continuous Vertical Brass Channel Dividing Guess Pegs & 2x2 Feedback Pin Plaque
	var v_div = MeshInstance3D.new()
	var v_div_m = BoxMesh.new()
	v_div_m.size = Vector3(0.004, 0.005, (ROW_Z_BOTTOM - ROW_Z_TOP) + 0.09)
	v_div_m.material = mat_brass_trim
	v_div.mesh = v_div_m
	v_div.position = Vector3(PIN_DIVIDER_X, 0.016, (ROW_Z_BOTTOM + ROW_Z_TOP) * 0.5)
	root.add_child(v_div)

	if is_player_board:
		my_row_containers.clear()
		my_row_pin_nodes.clear()
		my_row_labels.clear()
		_build_12_rows(root, my_row_containers, my_row_pin_nodes, my_row_labels)

		my_row_pointer = _create_pointer_mesh()
		my_row_pointer.position = Vector3(-BOARD_W * 0.5 + 0.022, 0.018, _get_row_z(0))
		root.add_child(my_row_pointer)

		my_active_row_frame = _create_active_row_frame()
		my_active_row_frame.position = Vector3(0, 0.016, _get_row_z(0))
		root.add_child(my_active_row_frame)

		# Active Guess Input Dock (4 luminous gold chalice sockets)
		_build_active_input_row(root)

		# 8-Color Gemstone Palette Dock
		phase2_palette_pegs.clear()
		phase2_palette_positions.clear()
		_build_palette(
			root,
			PALETTE_ROW1_Z,
			PALETTE_ROW2_Z,
			PALETTE_X_OFFSETS,
			0.016,
			phase2_palette_pegs,
			phase2_palette_positions,
			false
		)
	else:
		opp_row_containers.clear()
		opp_row_pin_nodes.clear()
		opp_row_labels.clear()
		_build_12_rows(root, opp_row_containers, opp_row_pin_nodes, opp_row_labels)

		opp_row_pointer = _create_pointer_mesh()
		opp_row_pointer.position = Vector3(-BOARD_W * 0.5 + 0.022, 0.018, _get_row_z(0))
		root.add_child(opp_row_pointer)

		opp_active_row_frame = _create_active_row_frame()
		opp_active_row_frame.position = Vector3(0, 0.016, _get_row_z(0))
		root.add_child(opp_active_row_frame)

func _build_top_mystery_vault_hood(root: Node3D, is_player_board: bool) -> void:
	var hood_z = -0.768
	var hood = MeshInstance3D.new()
	var hood_m = BoxMesh.new()
	hood_m.size = Vector3(BOARD_W - 0.06, 0.010, 0.095)
	hood_m.material = mat_vault_recess
	hood.mesh = hood_m
	hood.position = Vector3(0, 0.016, hood_z)
	root.add_child(hood)

	_create_zone_frame(root, Vector3(0, 0.021, hood_z), BOARD_W - 0.056, 0.098, mat_gold_ring if is_player_board else mat_brass_trim)

	for col in range(NUM_PEGS):
		var px = PEG_X_OFFSETS[col]
		var badge = _create_chalice_socket_mesh(0.020, 0.005, mat_hole_concave, mat_gold_ring)
		badge.position = Vector3(px, 0.021, hood_z)
		root.add_child(badge)

		var q_lbl = _create_3d_label("؟", 24, Color(1.0, 0.86, 0.32))
		q_lbl.position = Vector3(px, 0.024, hood_z)
		root.add_child(q_lbl)

	var title_str = "🔐 رمز مخفی" if is_player_board else "🎯 صفحه حریف"
	var vault_lbl = _create_3d_label(title_str, 20, Color(0.95, 0.85, 0.45))
	vault_lbl.position = Vector3(PIN_GRID_X - 0.01, 0.023, hood_z)
	root.add_child(vault_lbl)

func _build_12_rows(root: Node3D, containers: Array[Node3D], pin_arrays: Array[Array], row_labels: Array[Label3D]) -> void:
	var pin_coords = [
		Vector2(-PIN_OFFSET, -PIN_OFFSET),
		Vector2(PIN_OFFSET, -PIN_OFFSET),
		Vector2(-PIN_OFFSET, PIN_OFFSET),
		Vector2(PIN_OFFSET, PIN_OFFSET)
	]

	var step = (ROW_Z_BOTTOM - ROW_Z_TOP) / float(NUM_VISIBLE_ROWS - 1)

	for r in range(NUM_VISIBLE_ROWS):
		var z_pos = _get_row_z(r)
		var row_node = Node3D.new()
		row_node.name = "Row_%d" % r
		row_node.position = Vector3(0, 0.014, z_pos)
		root.add_child(row_node)
		containers.append(row_node)

		# Dedicated container for guess pieces (keeps sockets & pins intact on refresh)
		var pieces_container = Node3D.new()
		pieces_container.name = "PiecesContainer"
		row_node.add_child(pieces_container)

		# 3D Row Number Badge (۱ .. ۱۲)
		var r_lbl = _create_3d_label(FA_DIGITS[r + 1], 21, Color(0.68, 0.62, 0.50))
		r_lbl.position = Vector3(ROW_NUM_X, 0.004, 0)
		row_node.add_child(r_lbl)
		row_labels.append(r_lbl)

		# Inlaid Brass Divider between rows
		if r < NUM_VISIBLE_ROWS - 1:
			var div = MeshInstance3D.new()
			var div_m = BoxMesh.new()
			div_m.size = Vector3(BOARD_W - 0.06, 0.0025, 0.0025)
			div_m.material = mat_brass_trim
			div.mesh = div_m
			div.position = Vector3(0, 0.002, -step * 0.5)
			row_node.add_child(div)

		# 4 Concave Peg Sockets
		for col in range(NUM_PEGS):
			var pos_x = PEG_X_OFFSETS[col]
			var sock = _create_chalice_socket_mesh(0.023, 0.007, mat_hole_concave, mat_socket_rim)
			sock.position = Vector3(pos_x, 0.002, 0)
			row_node.add_child(sock)

		# 2x2 Feedback Pin Plaque (Obsidian & Brass)
		var pad = MeshInstance3D.new()
		var pad_m = BoxMesh.new()
		pad_m.size = Vector3(0.084, 0.005, 0.076)
		pad_m.material = mat_hole_concave
		pad.mesh = pad_m
		pad.position = Vector3(PIN_GRID_X, 0.002, 0)
		row_node.add_child(pad)

		var pad_rim = MeshInstance3D.new()
		var pad_rim_m = BoxMesh.new()
		pad_rim_m.size = Vector3(0.088, 0.003, 0.080)
		pad_rim_m.material = mat_brass_trim
		pad_rim.mesh = pad_rim_m
		pad_rim.position = Vector3(PIN_GRID_X, 0.001, 0)
		row_node.add_child(pad_rim)

		var pins_for_row: Array = []
		for p_idx in range(4):
			var offset = pin_coords[p_idx]
			var pin_x = PIN_GRID_X + offset.x
			var pin_z = offset.y

			var p_sock = _create_chalice_socket_mesh(0.012, 0.004, mat_hole_concave, mat_brass_trim)
			p_sock.position = Vector3(pin_x, 0.004, pin_z)
			row_node.add_child(p_sock)

			var p_mesh = MeshInstance3D.new()
			var sph = SphereMesh.new()
			sph.radius = 0.0145
			sph.height = 0.018
			sph.material = mat_pin_black
			p_mesh.mesh = sph
			p_mesh.position = Vector3(pin_x, 0.015, pin_z)
			p_mesh.visible = false
			row_node.add_child(p_mesh)
			pins_for_row.append(p_mesh)

		pin_arrays.append(pins_for_row)

func _get_row_z(row_idx: int) -> float:
	var step = (ROW_Z_BOTTOM - ROW_Z_TOP) / float(NUM_VISIBLE_ROWS - 1)
	return ROW_Z_BOTTOM - (float(row_idx) * step)

func _build_active_input_row(root: Node3D) -> void:
	active_slot_nodes.clear()
	active_slot_pieces.clear()
	active_slot_rings.clear()

	# Recessed Input Dock Panel
	var dock_bg = MeshInstance3D.new()
	var dock_m = BoxMesh.new()
	dock_m.size = Vector3(BOARD_W - 0.06, 0.004, 0.092)
	dock_m.material = mat_vault_recess
	dock_bg.mesh = dock_m
	dock_bg.position = Vector3(0, 0.015, ACTIVE_ROW_Z)
	root.add_child(dock_bg)

	_create_zone_frame(root, Vector3(0, 0.017, ACTIVE_ROW_Z), BOARD_W - 0.056, 0.095, mat_gold_ring)

	var dock_lbl = _create_3d_label("حدس فعلی", 19, Color(1.0, 0.88, 0.36))
	dock_lbl.position = Vector3(PIN_GRID_X - 0.005, 0.019, ACTIVE_ROW_Z)
	root.add_child(dock_lbl)

	for col in range(NUM_PEGS):
		var pos_x = PEG_X_OFFSETS[col]
		var sock = _create_chalice_socket_mesh(0.026, 0.008, mat_hole_concave, mat_gold_ring)
		sock.position = Vector3(pos_x, 0.016, ACTIVE_ROW_Z)
		root.add_child(sock)
		active_slot_nodes.append(sock)

		var hover_ring = _create_slot_hover_ring(0.030, 0.036)
		hover_ring.position = Vector3(pos_x, 0.018, ACTIVE_ROW_Z)
		root.add_child(hover_ring)
		active_slot_rings.append(hover_ring)

		var piece = _create_piece_mesh(1)
		piece.position = Vector3(pos_x, 0.036, ACTIVE_ROW_Z)
		piece.visible = false
		root.add_child(piece)
		active_slot_pieces.append(piece)

		_create_slot_interaction_area(root, Vector3(pos_x, 0.028, ACTIVE_ROW_Z), 0.033, col, false)

func _build_palette(
	root: Node3D,
	r1_z: float,
	r2_z: float,
	x_offsets: Array,
	slab_y: float,
	pegs_dict: Dictionary,
	pos_dict: Dictionary,
	is_phase1: bool
) -> void:
	if not is_phase1:
		var pal_bg = MeshInstance3D.new()
		var pal_m = BoxMesh.new()
		pal_m.size = Vector3(BOARD_W - 0.06, 0.004, 0.215)
		pal_m.material = mat_vault_recess
		pal_bg.mesh = pal_m
		pal_bg.position = Vector3(0, 0.015, (r1_z + r2_z) * 0.5)
		root.add_child(pal_bg)
		_create_zone_frame(root, Vector3(0, 0.017, (r1_z + r2_z) * 0.5), BOARD_W - 0.056, 0.218, mat_brass_trim)

	for i in range(8):
		var color_id = i + 1
		var is_r1 = (i < 4)
		var col_idx = i if is_r1 else (i - 4)
		var p_x = x_offsets[col_idx]
		var p_z = r1_z if is_r1 else r2_z

		# Sculpted Brass Pedestal Dish with Concave Well
		var dish = _create_chalice_socket_mesh(0.026, 0.006, mat_hole_concave, mat_brass_trim)
		dish.position = Vector3(p_x, slab_y + 0.002, p_z)
		root.add_child(dish)

		# Subtle Color-Coded Inner Ring (so player sees which color belongs to this dish when peg is in a slot)
		var color_ring = MeshInstance3D.new()
		var cr_torus = TorusMesh.new()
		cr_torus.inner_radius = 0.015
		cr_torus.outer_radius = 0.020
		cr_torus.rings = 20
		cr_torus.ring_segments = 10
		color_ring.mesh = cr_torus
		color_ring.material_override = dish_ring_materials.get(color_id, mat_brass_trim)
		color_ring.position = Vector3(p_x, slab_y + 0.003, p_z)
		root.add_child(color_ring)

		# Physical Gemstone Peg sitting in the palette dish
		var peg_pos = Vector3(p_x, slab_y + 0.022, p_z)
		var piece = _create_piece_mesh(color_id)
		piece.position = peg_pos
		root.add_child(piece)

		pegs_dict[color_id] = piece
		pos_dict[color_id] = peg_pos

		# Interactive Area3D for both Click and Drag-and-Drop
		var area = Area3D.new()
		var col_shape = CollisionShape3D.new()
		var sph_shape = SphereShape3D.new()
		sph_shape.radius = 0.034
		col_shape.shape = sph_shape
		area.add_child(col_shape)
		area.position = peg_pos
		root.add_child(area)

		area.input_event.connect(func(_cam, ev, _pos, _norm, _idx):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				_on_palette_peg_pressed(color_id, is_phase1, ev.position)
			elif ev is InputEventScreenTouch and ev.pressed:
				_on_palette_peg_pressed(color_id, is_phase1, ev.position)
		)

func _create_slot_interaction_area(root: Node3D, pos: Vector3, radius: float, slot_idx: int, is_phase1: bool) -> void:
	var area = Area3D.new()
	var col_shape = CollisionShape3D.new()
	var sph = SphereShape3D.new()
	sph.radius = radius
	col_shape.shape = sph
	area.add_child(col_shape)
	area.position = pos
	root.add_child(area)

	area.input_event.connect(func(_cam, ev, _pos, _norm, _idx):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_on_slot_peg_pressed(slot_idx, is_phase1, ev.position)
		elif ev is InputEventScreenTouch and ev.pressed:
			_on_slot_peg_pressed(slot_idx, is_phase1, ev.position)
	)

# ==============================================================================
# 5. GEOMETRY & VFX HELPERS
# ==============================================================================

func _create_3d_label(text_str: String, font_px: int, col: Color) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = text_str
	if _game_font:
		lbl.font = _game_font
	lbl.font_size = font_px
	lbl.pixel_size = 0.0009
	lbl.modulate = col
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.88)
	lbl.outline_size = 6
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _create_zone_frame(root: Node3D, center_pos: Vector3, w: float, l: float, mat: Material) -> void:
	var frame_root = Node3D.new()
	frame_root.position = center_pos
	root.add_child(frame_root)

	var h_m = BoxMesh.new()
	h_m.size = Vector3(w, 0.003, 0.004)
	h_m.material = mat

	var v_m = BoxMesh.new()
	v_m.size = Vector3(0.004, 0.003, l)
	v_m.material = mat

	var top_b = MeshInstance3D.new()
	top_b.mesh = h_m
	top_b.position = Vector3(0, 0, -l * 0.5)
	frame_root.add_child(top_b)

	var bot_b = MeshInstance3D.new()
	bot_b.mesh = h_m
	bot_b.position = Vector3(0, 0, l * 0.5)
	frame_root.add_child(bot_b)

	var left_b = MeshInstance3D.new()
	left_b.mesh = v_m
	left_b.position = Vector3(-w * 0.5, 0, 0)
	frame_root.add_child(left_b)

	var right_b = MeshInstance3D.new()
	right_b.mesh = v_m
	right_b.position = Vector3(w * 0.5, 0, 0)
	frame_root.add_child(right_b)

func _create_active_row_frame() -> Node3D:
	var node = Node3D.new()
	var w = BOARD_W - 0.056
	var l = 0.082
	_create_zone_frame(node, Vector3.ZERO, w, l, mat_active_row_glow)
	return node

func _create_slot_hover_ring(inner_r: float, outer_r: float) -> MeshInstance3D:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 24
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = mat_hover_ring
	ring.visible = false
	return ring

func _create_bezel(root: Node3D, w: float, l: float, y_h: float) -> void:
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(w + 0.010, 0.014, 0.010)
	h_mesh.material = mat_brass_trim

	var v_mesh = BoxMesh.new()
	v_mesh.size = Vector3(0.010, 0.014, l + 0.010)
	v_mesh.material = mat_brass_trim

	var b_top = MeshInstance3D.new()
	b_top.mesh = h_mesh
	b_top.position = Vector3(0, y_h + 0.004, -l * 0.5)
	root.add_child(b_top)

	var b_bot = MeshInstance3D.new()
	b_bot.mesh = h_mesh
	b_bot.position = Vector3(0, y_h + 0.004, l * 0.5)
	root.add_child(b_bot)

	var b_left = MeshInstance3D.new()
	b_left.mesh = v_mesh
	b_left.position = Vector3(-w * 0.5, y_h + 0.004, 0)
	root.add_child(b_left)

	var b_right = MeshInstance3D.new()
	b_right.mesh = v_mesh
	b_right.position = Vector3(w * 0.5, y_h + 0.004, 0)
	root.add_child(b_right)

func _create_corner_brackets(root: Node3D, w: float, l: float, y_h: float) -> void:
	var offsets = [
		Vector3(-w * 0.5 + 0.014, y_h + 0.007, -l * 0.5 + 0.014),
		Vector3(w * 0.5 - 0.014, y_h + 0.007, -l * 0.5 + 0.014),
		Vector3(-w * 0.5 + 0.014, y_h + 0.007, l * 0.5 - 0.014),
		Vector3(w * 0.5 - 0.014, y_h + 0.007, l * 0.5 - 0.014)
	]
	for pos in offsets:
		var stud = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.016
		cyl.bottom_radius = 0.019
		cyl.height = 0.010
		cyl.material = mat_gold_ring
		stud.mesh = cyl
		stud.position = pos
		root.add_child(stud)

func _create_piece_mesh(color_id: int) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.0235
	sph.height = 0.0245
	sph.radial_segments = 32
	sph.rings = 16
	inst.mesh = sph
	inst.material_override = piece_materials.get(color_id, mat_pin_white)
	return inst

func _create_chalice_socket_mesh(radius: float, depth: float, concave_mat: Material, rim_mat: Material) -> Node3D:
	var root_node = Node3D.new()
	var hole = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.75
	cyl.height = depth
	cyl.radial_segments = 28
	hole.mesh = cyl
	hole.material_override = concave_mat
	hole.position = Vector3(0, -depth * 0.5, 0)
	root_node.add_child(hole)

	var rim = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius * 1.12
	torus.rings = 28
	torus.ring_segments = 12
	rim.mesh = torus
	rim.material_override = rim_mat
	rim.position = Vector3(0, 0.002, 0)
	root_node.add_child(rim)
	return root_node

func _create_pointer_mesh() -> Node3D:
	var node = Node3D.new()
	var ptr = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(0.030, 0.030, 0.016)
	prism.material = mat_gold_ring
	ptr.mesh = prism
	ptr.rotation_degrees = Vector3(0, 0, -90)
	node.add_child(ptr)
	return node

func _update_active_row_pointer(pointer: Node3D, frame: Node3D, labels: Array[Label3D], row_idx: int) -> void:
	var clamped_idx = clampi(row_idx, 0, NUM_VISIBLE_ROWS - 1)
	var target_z = _get_row_z(clamped_idx)
	if is_instance_valid(pointer):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pointer, "position:z", target_z, 0.32)
	if is_instance_valid(frame):
		var tw_f = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_f.tween_property(frame, "position:z", target_z, 0.32)
	for i in range(labels.size()):
		var lbl = labels[i]
		if not is_instance_valid(lbl):
			continue
		if i == clamped_idx:
			lbl.modulate = Color(1.0, 0.88, 0.30)
			lbl.scale = Vector3(1.22, 1.22, 1.22)
		elif i < clamped_idx:
			lbl.modulate = Color(0.55, 0.90, 0.65)
			lbl.scale = Vector3.ONE
		else:
			lbl.modulate = Color(0.65, 0.60, 0.50)
			lbl.scale = Vector3.ONE

# Spawns a 3D expanding golden shockwave ring at the target slot when a peg lands
func _spawn_3d_slot_vfx(parent_root: Node3D, slot_pos: Vector3, color_id: int) -> void:
	if not is_instance_valid(parent_root):
		return
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.020
	torus.outer_radius = 0.027
	torus.rings = 24
	torus.ring_segments = 10
	ring.mesh = torus

	var vfx_mat = StandardMaterial3D.new()
	vfx_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var base_col: Color = COLOR_VALUES.get(color_id, Color(1.0, 0.86, 0.3))
	vfx_mat.albedo_color = base_col.lerp(Color(1.0, 0.92, 0.45), 0.45)
	vfx_mat.emission_enabled = true
	vfx_mat.emission = vfx_mat.albedo_color * 1.4
	ring.material_override = vfx_mat
	ring.position = Vector3(slot_pos.x, slot_pos.y - 0.012, slot_pos.z)
	ring.scale = Vector3(0.75, 1.0, 0.75)
	parent_root.add_child(ring)

	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(1.85, 1.0, 1.85), 0.32)
	tw.tween_property(vfx_mat, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(ring.queue_free)

func _pulse_slot_ring(ring_mesh: MeshInstance3D) -> void:
	if not is_instance_valid(ring_mesh):
		return
	ring_mesh.visible = true
	ring_mesh.scale = Vector3(0.85, 1.0, 0.85)
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mesh, "scale", Vector3(1.30, 1.0, 1.30), 0.16)
	tw.tween_property(ring_mesh, "scale", Vector3.ONE, 0.14)
	tw.tween_callback(func():
		if is_instance_valid(ring_mesh) and not is_dragging_piece:
			ring_mesh.visible = false
	)

# Animates a peg flying along a parabolic 3D arc from start_pos to target slot
func _animate_slot_placement_from(parent_root: Node3D, piece_mesh: MeshInstance3D, color_id: int, start_local_pos: Vector3, target_local_pos: Vector3) -> void:
	if not is_instance_valid(piece_mesh):
		return
	piece_mesh.material_override = piece_materials.get(color_id, mat_pin_white)
	piece_mesh.visible = true
	piece_mesh.position = start_local_pos
	piece_mesh.scale = Vector3(0.85, 0.85, 0.85)

	var mid_pos = (start_local_pos + target_local_pos) * 0.5
	mid_pos.y = maxf(start_local_pos.y, target_local_pos.y) + 0.068

	var tw = create_tween()
	tw.tween_property(piece_mesh, "position", mid_pos, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(piece_mesh, "scale", Vector3(1.22, 1.22, 1.22), 0.13)
	tw.tween_property(piece_mesh, "position", target_local_pos, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(piece_mesh, "scale", Vector3.ONE, 0.15)
	tw.tween_callback(func():
		_spawn_3d_slot_vfx(parent_root, target_local_pos, color_id)
	)

# Animates a removed slot peg flying along a parabolic 3D arc back into its palette dish
func _animate_slot_return_to_palette(parent_root: Node3D, slot_piece_mesh: MeshInstance3D, color_id: int, palette_local_pos: Vector3) -> void:
	if not is_instance_valid(slot_piece_mesh):
		return
	var start_pos = slot_piece_mesh.position
	slot_piece_mesh.visible = false

	if not is_instance_valid(parent_root) or palette_local_pos == Vector3.ZERO:
		_sync_palette_visibility()
		return

	var fly_peg = _create_piece_mesh(color_id)
	fly_peg.position = start_pos
	parent_root.add_child(fly_peg)

	var mid_pos = (start_pos + palette_local_pos) * 0.5
	mid_pos.y = maxf(start_pos.y, palette_local_pos.y) + 0.055

	var tw = create_tween()
	tw.tween_property(fly_peg, "position", mid_pos, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fly_peg, "scale", Vector3(1.12, 1.12, 1.12), 0.11)
	tw.tween_property(fly_peg, "position", palette_local_pos, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fly_peg, "scale", Vector3.ONE, 0.13)
	tw.tween_callback(func():
		if is_instance_valid(fly_peg):
			fly_peg.queue_free()
		_sync_palette_visibility()
	)

# Synchronizes visibility of the 8 palette pegs so any color currently placed in the 4 slots is hidden from its palette dish
func _sync_palette_visibility() -> void:
	for c_id in range(1, 9):
		if phase1_palette_pegs.has(c_id) and is_instance_valid(phase1_palette_pegs[c_id]):
			var in_p1_slots = (c_id in phase1_selection)
			var dragging_this_p1 = (is_dragging_piece and not is_play_phase and _drag_color_id == c_id)
			phase1_palette_pegs[c_id].visible = (not in_p1_slots) and (not dragging_this_p1)
		if phase2_palette_pegs.has(c_id) and is_instance_valid(phase2_palette_pegs[c_id]):
			var in_p2_slots = (c_id in active_selection)
			var dragging_this_p2 = (is_dragging_piece and is_play_phase and _drag_color_id == c_id)
			phase2_palette_pegs[c_id].visible = (not in_p2_slots) and (not dragging_this_p2)

# ==============================================================================
# 6. UNIFIED SLOT PLACEMENT, TAP FLIGHT & 3D DRAG-AND-DROP
# ==============================================================================

func _place_color_in_slot(slot_idx: int, color_id: int, is_p1: bool, from_local_pos: Vector3) -> void:
	if slot_idx < 0 or slot_idx >= 4 or color_id <= 0:
		return
	var sel_arr: Array = phase1_selection if is_p1 else active_selection
	var slot_pieces: Array[MeshInstance3D] = phase1_slot_pieces if is_p1 else active_slot_pieces
	var parent_root: Node3D = phase1_root if is_p1 else my_board_root
	var pal_positions: Dictionary = phase1_palette_positions if is_p1 else phase2_palette_positions

	# If color_id is already in another slot, clear that other slot first
	var prev_slot = sel_arr.find(color_id)
	if prev_slot != -1 and prev_slot != slot_idx:
		sel_arr[prev_slot] = 0
		if prev_slot < slot_pieces.size() and is_instance_valid(slot_pieces[prev_slot]):
			slot_pieces[prev_slot].visible = false

	# If target slot already has a different color, return that old color to its palette dish
	var old_color = int(sel_arr[slot_idx])
	if old_color > 0 and old_color != color_id:
		if prev_slot != -1:
			# Swap the displaced color into the source slot!
			sel_arr[prev_slot] = old_color
			var swap_target_pos = _get_slot_local_pos(prev_slot, is_p1)
			var swap_start_pos = _get_slot_local_pos(slot_idx, is_p1)
			_animate_slot_placement_from(parent_root, slot_pieces[prev_slot], old_color, swap_start_pos, swap_target_pos)
		else:
			_animate_slot_return_to_palette(parent_root, slot_pieces[slot_idx], old_color, pal_positions.get(old_color, Vector3.ZERO))

	sel_arr[slot_idx] = color_id
	_sync_palette_visibility()
	AudioManager.play_sound("tap")

	var target_local_pos = _get_slot_local_pos(slot_idx, is_p1)
	_animate_slot_placement_from(parent_root, slot_pieces[slot_idx], color_id, from_local_pos, target_local_pos)

func _get_slot_local_pos(slot_idx: int, is_p1: bool) -> Vector3:
	if is_p1:
		return Vector3(TRAY_SECRET_X_OFFSETS[slot_idx], 0.036, TRAY_SECRET_Z + 0.012)
	return Vector3(PEG_X_OFFSETS[slot_idx], 0.036, ACTIVE_ROW_Z)

func _on_palette_peg_pressed(color_id: int, is_p1: bool, screen_pos: Vector2) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or (is_p1 and is_play_phase) or (not is_p1 and not is_play_phase):
		return
	if is_play_phase and current_view_mode != ViewMode.MY_BOARD:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)

	var sel_arr: Array = phase1_selection if is_p1 else active_selection
	if color_id in sel_arr:
		# Color is already placed in one of the 4 slots -> pulse that slot
		var idx = sel_arr.find(color_id)
		var rings = phase1_slot_rings if is_p1 else active_slot_rings
		if idx >= 0 and idx < rings.size():
			_pulse_slot_ring(rings[idx])
		AudioManager.play_sound("tap_wrong")
		show_hint("این رنگ در جایگاه %s قرار دارد؛ برای حذف روی مهره کلیک کنید." % FA_DIGITS[idx + 1])
		return

	_pointer_down = true
	_pointer_start_screen = screen_pos
	_drag_color_id = color_id
	_drag_source_slot = -1
	is_dragging_piece = false

func _on_slot_peg_pressed(slot_idx: int, is_p1: bool, screen_pos: Vector2) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or (is_p1 and is_play_phase) or (not is_p1 and not is_play_phase):
		return
	var sel_arr: Array = phase1_selection if is_p1 else active_selection
	var color_id = int(sel_arr[slot_idx])
	if color_id <= 0:
		return

	_pointer_down = true
	_pointer_start_screen = screen_pos
	_drag_color_id = color_id
	_drag_source_slot = slot_idx
	is_dragging_piece = false

func _unhandled_input(event: InputEvent) -> void:
	if not _pointer_down:
		return

	if event is InputEventMouseMotion:
		_handle_pointer_move(event.position)
		if is_dragging_piece:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_pointer_move(event.position)
		if is_dragging_piece:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_handle_pointer_release(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_pointer_release(event.position)
		get_viewport().set_input_as_handled()

func _handle_pointer_move(screen_pos: Vector2) -> void:
	if not _pointer_down or _drag_color_id <= 0:
		return
	if not is_dragging_piece:
		if screen_pos.distance_to(_pointer_start_screen) < 10.0:
			return
		# Transition into 3D Drag Mode!
		is_dragging_piece = true
		AudioManager.play_sound("tap")
		_drag_peg_mesh.material_override = piece_materials.get(_drag_color_id, mat_pin_white)
		_drag_peg_node.visible = true
		if _drag_source_slot >= 0:
			var slot_pieces = phase1_slot_pieces if not is_play_phase else active_slot_pieces
			if _drag_source_slot < slot_pieces.size() and is_instance_valid(slot_pieces[_drag_source_slot]):
				slot_pieces[_drag_source_slot].visible = false
		_sync_palette_visibility()

	var hit_world = _project_screen_to_board_plane(screen_pos)
	var local_root: Node3D = phase1_root if not is_play_phase else my_board_root
	if is_instance_valid(_drag_peg_node):
		_drag_peg_node.global_position = hit_world + Vector3(0, 0.045, 0)

	# Check magnetic proximity to the 4 target slots
	var best_slot = -1
	var best_dist = 0.085
	for i in range(4):
		var slot_local = _get_slot_local_pos(i, not is_play_phase)
		var slot_world = local_root.to_global(slot_local)
		var dist_2d = Vector2(hit_world.x - slot_world.x, hit_world.z - slot_world.z).length()
		if dist_2d < best_dist:
			best_dist = dist_2d
			best_slot = i

	if best_slot != _hovered_slot_idx:
		_hovered_slot_idx = best_slot
		_update_slot_hover_rings(not is_play_phase, _hovered_slot_idx)

func _handle_pointer_release(_screen_pos: Vector2) -> void:
	var was_dragging = is_dragging_piece
	var color_id = _drag_color_id
	var src_slot = _drag_source_slot
	var target_slot = _hovered_slot_idx
	var is_p1 = not is_play_phase

	_pointer_down = false
	is_dragging_piece = false
	_drag_color_id = 0
	_drag_source_slot = -1
	_hovered_slot_idx = -1
	_update_slot_hover_rings(is_p1, -1)

	var local_root: Node3D = phase1_root if is_p1 else my_board_root
	var drag_local_pos = local_root.to_local(_drag_peg_node.global_position) if is_instance_valid(_drag_peg_node) and is_instance_valid(local_root) else Vector3.ZERO
	if is_instance_valid(_drag_peg_node):
		_drag_peg_node.visible = false

	if not was_dragging:
		# Fast tap/click!
		if src_slot >= 0:
			if is_p1:
				_on_phase1_slot_clicked(src_slot)
			else:
				_on_active_slot_clicked(src_slot)
		else:
			if is_p1:
				_on_phase1_color_selected(color_id)
			else:
				_on_phase2_color_selected(color_id)
		return

	# Completed a 3D Drag-and-Drop!
	if target_slot >= 0 and target_slot < 4:
		_place_color_in_slot(target_slot, color_id, is_p1, drag_local_pos)
	else:
		# Dropped outside the 4 slots
		var pal_positions = phase1_palette_positions if is_p1 else phase2_palette_positions
		var slot_pieces = phase1_slot_pieces if is_p1 else active_slot_pieces
		var sel_arr = phase1_selection if is_p1 else active_selection
		if src_slot >= 0 and src_slot < 4:
			# Clear the source slot and fly the peg back to its palette dish
			sel_arr[src_slot] = 0
			AudioManager.play_sound("tap")
			slot_pieces[src_slot].position = drag_local_pos
			_animate_slot_return_to_palette(local_root, slot_pieces[src_slot], color_id, pal_positions.get(color_id, Vector3.ZERO))
		else:
			# Return dragged palette peg smoothly back to its palette dish
			var dummy = slot_pieces[0]
			var saved_pos = dummy.position
			var saved_vis = dummy.visible
			dummy.position = drag_local_pos
			_animate_slot_return_to_palette(local_root, dummy, color_id, pal_positions.get(color_id, Vector3.ZERO))
			dummy.position = saved_pos
			dummy.visible = saved_vis

func _cancel_active_drag() -> void:
	_pointer_down = false
	is_dragging_piece = false
	_drag_color_id = 0
	_drag_source_slot = -1
	_hovered_slot_idx = -1
	if is_instance_valid(_drag_peg_node):
		_drag_peg_node.visible = false
	_update_slot_hover_rings(true, -1)
	_update_slot_hover_rings(false, -1)
	_sync_palette_visibility()

func _update_slot_hover_rings(is_p1: bool, active_idx: int) -> void:
	var rings = phase1_slot_rings if is_p1 else active_slot_rings
	for i in range(rings.size()):
		var r = rings[i]
		if not is_instance_valid(r):
			continue
		if i == active_idx:
			r.visible = true
			r.scale = Vector3(1.24, 1.0, 1.24)
		else:
			r.visible = false
			r.scale = Vector3.ONE

func _project_screen_to_board_plane(screen_pos: Vector2) -> Vector3:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return global_position
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_dir = cam.project_ray_normal(screen_pos)
	var plane_y = global_position.y + 0.025
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		return hit
	return global_position

# ==============================================================================
# 7. PHASE 2 INPUT & SELECTION LOGIC
# ==============================================================================

func _on_phase2_color_selected(color_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or not is_play_phase:
		return
	if current_view_mode != ViewMode.MY_BOARD:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)
	# Prevent duplicate colors across the 4 slots
	var existing_idx = active_selection.find(color_id)
	if existing_idx != -1:
		AudioManager.play_sound("tap_wrong")
		_pulse_slot_ring(active_slot_rings[existing_idx])
		show_hint("این رنگ در جایگاه %s قرار دارد؛ رنگ تکراری مجاز نیست." % FA_DIGITS[existing_idx + 1])
		return
	for i in range(4):
		if active_selection[i] == 0:
			var from_pos = phase2_palette_positions.get(color_id, active_slot_pieces[i].position)
			_place_color_in_slot(i, color_id, false, from_pos)
			return
	AudioManager.play_sound("tap_wrong")
	show_hint("همه ۴ جایگاه حدس پر شده‌اند؛ برای ارسال دکمه تایید (✓) را بزنید.")

func _on_active_slot_clicked(col_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or not is_play_phase:
		return
	var color_id = int(active_selection[col_idx])
	if color_id != 0:
		AudioManager.play_sound("tap")
		active_selection[col_idx] = 0
		_animate_slot_return_to_palette(my_board_root, active_slot_pieces[col_idx], color_id, phase2_palette_positions.get(color_id, Vector3.ZERO))
		_sync_palette_visibility()

func _clear_current_selection() -> void:
	if not GameManager.is_game_active or is_board_locked:
		return
	_cancel_active_drag()
	if not is_play_phase:
		for i in range(4):
			var c_id = int(phase1_selection[i])
			if c_id > 0:
				phase1_selection[i] = 0
				_animate_slot_return_to_palette(phase1_root, phase1_slot_pieces[i], c_id, phase1_palette_positions.get(c_id, Vector3.ZERO))
		_clear_phase1_selection()
	else:
		for i in range(4):
			var c_id = int(active_selection[i])
			if c_id > 0:
				active_selection[i] = 0
				_animate_slot_return_to_palette(my_board_root, active_slot_pieces[i], c_id, phase2_palette_positions.get(c_id, Vector3.ZERO))
		active_selection = [0, 0, 0, 0]
		_update_active_slots()
	AudioManager.play_sound("tap")

func _update_active_slots() -> void:
	if active_slot_pieces.size() < 4:
		return
	for i in range(4):
		var c_id = int(active_selection[i])
		var p_mesh = active_slot_pieces[i]
		if c_id > 0 and piece_materials.has(c_id):
			p_mesh.material_override = piece_materials[c_id]
			p_mesh.visible = true
			p_mesh.scale = Vector3.ONE
			p_mesh.position = Vector3(PEG_X_OFFSETS[i], 0.036, ACTIVE_ROW_Z)
		else:
			p_mesh.visible = false
	_sync_palette_visibility()

# ==============================================================================
# 8. ACTION BUTTON HANDLERS (SUBMIT, CLEAR, VIEWS)
# ==============================================================================

func _on_hud_submit_pressed() -> void:
	_submit_selection()

func _on_hud_clear_pressed() -> void:
	_clear_current_selection()

func _on_hud_opponent_pressed() -> void:
	if not GameManager.is_game_active:
		return
	AudioManager.play_sound("tap_button")
	if current_view_mode == ViewMode.OPP_BOARD:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)
		show_hint("نمایش صفحه شما")
	else:
		_apply_view_mode_positions(ViewMode.OPP_BOARD, true)
		show_hint("نمایش حدس‌های حریف")

func _on_hud_dual_pressed() -> void:
	if not GameManager.is_game_active:
		return
	AudioManager.play_sound("tap_button")
	if current_view_mode == ViewMode.DUAL:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)
		show_hint("نمایش صفحه شما")
	else:
		_apply_view_mode_positions(ViewMode.DUAL, true)
		show_hint("نمایش همزمان هر دو صفحه")

func _submit_selection() -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked:
		return
	_cancel_active_drag()

	if not is_play_phase:
		# Phase 1: Submit Secret Board for Opponent
		for v in phase1_selection:
			if v <= 0:
				show_hint("لطفاً هر ۴ مهره رمز را انتخاب کنید.")
				AudioManager.play_sound("tap_wrong")
				return

		var uniq = []
		for v in phase1_selection:
			if v in uniq:
				show_hint("رنگ‌های رمز باید غیرتکراری باشند.")
				AudioManager.play_sound("tap_wrong")
				return
			uniq.append(v)

		set_board_locked(true)
		AudioManager.play_sound("tap_button")
		NetworkManager.send_save_board(phase1_selection)

		if is_instance_valid(phase1_root):
			phase1_root.visible = false

		var hud = _get_hud()
		if hud and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("🔐 رمز شما ثبت شد — در انتظار انتخاب رمز توسط حریف...")
	else:
		# Phase 2: Submit Guess for Active Row (non-repeating colors enforced!)
		for v in active_selection:
			if v <= 0:
				show_hint("لطفاً هر ۴ مهره حدس را در جایگاه قرار دهید.")
				AudioManager.play_sound("tap_wrong")
				return

		var uniq_guess = []
		for v in active_selection:
			if v in uniq_guess:
				show_hint("رنگ‌های انتخاب‌شده نباید تکراری باشند.")
				AudioManager.play_sound("tap_wrong")
				return
			uniq_guess.append(v)

		set_board_locked(true)
		AudioManager.play_sound("tap_button")
		NetworkManager.send_select_peace(active_selection)

		var hud = _get_hud()
		if hud and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("⏳ حدس شما ثبت شد — در انتظار ثبت حدس حریف...")

func _apply_view_mode_positions(mode: ViewMode, animate: bool = true) -> void:
	current_view_mode = mode
	var my_pos = Vector3.ZERO
	var opp_pos = Vector3.ZERO

	match mode:
		ViewMode.MY_BOARD:
			my_pos = Vector3.ZERO
			opp_pos = Vector3(3.0, 0, 0)
		ViewMode.OPP_BOARD:
			my_pos = Vector3(-3.0, 0, 0)
			opp_pos = Vector3.ZERO
		ViewMode.DUAL:
			my_pos = Vector3(-0.37, 0, 0)
			opp_pos = Vector3(0.37, 0, 0)

	if animate:
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(my_board_root, "position", my_pos, 0.42)
		tw.tween_property(opp_board_root, "position", opp_pos, 0.42)
	else:
		my_board_root.position = my_pos
		opp_board_root.position = opp_pos

# ==============================================================================
# 9. BASEGAMEBOARD VIRTUAL HOOKS
# ==============================================================================

func setup_board(_game_data: Dictionary) -> void:
	set_phase(false)
	current_round_num = 0
	set_board_locked(not GameManager.is_game_active)
	if GameManager.is_game_active:
		var hud = _get_hud()
		if hud and hud.has_method("set_setup_phase"):
			hud.set_setup_phase()

func on_start_game() -> void:
	set_phase(false)
	current_round_num = 0
	set_board_locked(false)
	var hud = _get_hud()
	if hud and hud.has_method("set_setup_phase"):
		hud.set_setup_phase()

func on_turn_changed(turn: int, _is_me: bool) -> void:
	if turn == 0:
		set_phase(false)
		current_round_num = 0
		set_board_locked(not GameManager.is_game_active)
		if GameManager.is_game_active:
			var hud = _get_hud()
			if hud and hud.has_method("set_setup_phase"):
				hud.set_setup_phase()
		return

	# Phase 2: Play Phase
	set_phase(true)
	current_round_num = turn
	set_board_locked(false)
	active_selection = [0, 0, 0, 0]
	_update_active_slots()
	_update_active_row_pointer(my_row_pointer, my_active_row_frame, my_row_labels, current_round_num - 1)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var guess_data: Array = []
	var result_data: Array = []

	if extra.has("data") and typeof(extra["data"]) == TYPE_ARRAY:
		guess_data = extra["data"]
	if extra.has("result") and typeof(extra["result"]) == TYPE_ARRAY:
		result_data = extra["result"]

	if guess_data.is_empty():
		return

	if user_id == my_player_index:
		my_choices.append(guess_data)
		my_results.append(result_data)
		var r_idx = my_choices.size() - 1
		_render_guess_row_on_board(my_row_containers, my_row_pin_nodes, r_idx, guess_data, result_data)

		var is_cracked = (result_data.size() == 4 and result_data[0] == 2 and result_data[1] == 2 and result_data[2] == 2 and result_data[3] == 2)
		if is_cracked:
			AudioManager.play_sound("win")
			show_hint("🎉 آفرین! رمز مخفی حریف را کشف کردید!")
	else:
		opp_choices.append(guess_data)
		opp_results.append(result_data)
		var r_idx = opp_choices.size() - 1
		_render_guess_row_on_board(opp_row_containers, opp_row_pin_nodes, r_idx, guess_data, result_data)
		_update_active_row_pointer(opp_row_pointer, opp_active_row_frame, opp_row_labels, r_idx)

func on_wait_time(time_sec: int) -> void:
	set_board_locked(true)
	var hud = _get_hud()
	if hud and hud.has_method("set_round_wait"):
		hud.set_round_wait(time_sec)

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) != TYPE_DICTIONARY:
		return

	is_play_phase = bool(g_data.get("is_play_phase", false))
	current_round_num = int(g_data.get("current_round", 1))

	if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
		my_secret_board = g_data["board"]
		is_my_board_set = (my_secret_board.size() == 4 and my_secret_board[0] != 0)

	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()

	var p1_c = g_data.get("player1_choices", [])
	var p1_r = g_data.get("player1_results", [])
	var p2_c = g_data.get("player2_choices", [])
	var p2_r = g_data.get("player2_results", [])

	if my_player_index == 1:
		my_choices = p1_c.duplicate()
		my_results = p1_r.duplicate()
		opp_choices = p2_c.duplicate()
		opp_results = p2_r.duplicate()
	else:
		my_choices = p2_c.duplicate()
		my_results = p2_r.duplicate()
		opp_choices = p1_c.duplicate()
		opp_results = p1_r.duplicate()

	set_phase(is_play_phase)
	_refresh_both_boards()
	var is_waiting = bool(g_data.get("is_turn_played", false)) if is_play_phase else bool(g_data.get("is_player_rdy", false))
	set_board_locked(is_waiting)
	var hud = _get_hud()
	if hud:
		if is_play_phase:
			if hud.has_method("update_turn"):
				hud.update_turn(max(1, current_round_num))
		else:
			if hud.has_method("set_setup_phase"):
				hud.set_setup_phase()
		if hud.has_method("set_fekrbekr_hud_buttons"):
			hud.set_fekrbekr_hud_buttons(is_play_phase)
		if is_waiting and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("⏳ حدس شما ثبت شده است — در انتظار حریف..." if is_play_phase else "🔐 رمز شما ثبت شده است — در انتظار حریف...")
	if not is_play_phase and is_waiting:
		if is_instance_valid(phase1_root):
			phase1_root.visible = false

# ==============================================================================
# 10. ROW RENDERING & RECONNECT SAFETY
# ==============================================================================

func _render_guess_row_on_board(containers: Array[Node3D], pin_arrays: Array[Array], row_idx: int, guess: Array, result: Array) -> void:
	if row_idx < 0 or row_idx >= NUM_VISIBLE_ROWS or row_idx >= containers.size():
		return

	var row_node = containers[row_idx]
	if not is_instance_valid(row_node):
		return

	var pc = row_node.get_node_or_null("PiecesContainer")
	if not pc:
		pc = Node3D.new()
		pc.name = "PiecesContainer"
		row_node.add_child(pc)

	for col in range(min(guess.size(), NUM_PEGS)):
		var color_val = int(guess[col])
		if color_val <= 0:
			continue

		var piece = _create_piece_mesh(color_val)
		piece.position = Vector3(PEG_X_OFFSETS[col], 0.050, 0)
		piece.scale = Vector3(0.5, 0.5, 0.5)
		pc.add_child(piece)

		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(piece, "position:y", 0.016, 0.20 + col * 0.03)
		tw.parallel().tween_property(piece, "scale", Vector3.ONE, 0.20 + col * 0.03)

	if row_idx < pin_arrays.size():
		var pin_nodes = pin_arrays[row_idx]
		for p_idx in range(min(result.size(), 4)):
			var r_val = int(result[p_idx])
			var pin = pin_nodes[p_idx]
			if not is_instance_valid(pin):
				continue

			if r_val == 0:
				pin.visible = false
				continue

			pin.material_override = mat_pin_black if r_val == 2 else mat_pin_white
			pin.visible = true
			pin.scale = Vector3.ZERO
			pin.position.y = 0.005

			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.18 + p_idx * 0.06)
			tw.parallel().tween_property(pin, "scale", Vector3.ONE, 0.16)
			tw.parallel().tween_property(pin, "position:y", 0.015, 0.16)

func _refresh_both_boards() -> void:
	for r in range(my_row_containers.size()):
		var row_node = my_row_containers[r]
		if is_instance_valid(row_node):
			var pc = row_node.get_node_or_null("PiecesContainer")
			if pc:
				for ch in pc.get_children():
					ch.queue_free()
		if r < my_row_pin_nodes.size():
			for p in my_row_pin_nodes[r]:
				if is_instance_valid(p):
					p.visible = false

	for r in range(min(my_choices.size(), NUM_VISIBLE_ROWS)):
		_render_guess_row_on_board(my_row_containers, my_row_pin_nodes, r, my_choices[r], my_results[r] if r < my_results.size() else [])

	for r in range(opp_row_containers.size()):
		var row_node = opp_row_containers[r]
		if is_instance_valid(row_node):
			var pc = row_node.get_node_or_null("PiecesContainer")
			if pc:
				for ch in pc.get_children():
					ch.queue_free()
		if r < opp_row_pin_nodes.size():
			for p in opp_row_pin_nodes[r]:
				if is_instance_valid(p):
					p.visible = false

	for r in range(min(opp_choices.size(), NUM_VISIBLE_ROWS)):
		_render_guess_row_on_board(opp_row_containers, opp_row_pin_nodes, r, opp_choices[r], opp_results[r] if r < opp_results.size() else [])

func reset_board() -> void:
	_cancel_active_drag()
	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()
	phase1_selection = [0, 0, 0, 0]
	active_selection = [0, 0, 0, 0]
	is_my_board_set = false
	is_revealed = false
	current_round_num = 0
	set_phase(false)
	_refresh_both_boards()
	_update_phase1_slots()
	_update_active_slots()

func on_round_finished(_payload: Variant) -> void:
	_cancel_active_drag()
	set_board_locked(true)

func on_new_round(round_num: int) -> void:
	_cancel_active_drag()
	current_round_num = round_num
	set_phase(true)
	set_board_locked(false)
	active_selection = [0, 0, 0, 0]
	_update_active_slots()
	_update_active_row_pointer(my_row_pointer, my_active_row_frame, my_row_labels, current_round_num - 1)

func cleanup_board() -> void:
	_cancel_active_drag()
	is_play_phase = false
	current_round_num = 0
	is_my_board_set = false
	is_revealed = false
	phase1_selection = [0, 0, 0, 0]
	active_selection = [0, 0, 0, 0]
	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()
	set_phase(false)
