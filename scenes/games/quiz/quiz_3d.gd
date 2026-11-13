class_name Quiz3D
extends "res://scripts/games/base_game_board.gd"

# Quiz3D - Cafe Fekr Royal 3D Tabletop Trivia Board
# Pure 3D board architecture using native Godot 4 Label3D & PBR meshes (zero SubViewport/CanvasLayer bugs):
# - Carved mahogany, brushed brass & emerald velvet tabletop console within [-0.64..+0.64] x [-0.67..+0.67]
# - 10 physical brass & glowing jewel progress sockets along the upper crown bar
# - Inclined walnut-and-brass 3D Question Lectern with large, pure-white unshaded Label3D text
# - 4 large physical 3D interactive Answer Keycaps (الف، ب، ج، د) with pure-white unshaded Label3D text
# - 2-4 physical 3D Player Crystal Pedestals & nameplates with live lock-in beacons & reveal answer pucks
# - Full 1:1 protocol sync with kafehfekrbackend/Controllers/GameSession/quiz_game_session.py

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")
const DRAG_THRESHOLD: float = 16.0
const OPTION_LETTERS: Array[String] = ["الف", "ب", "ج", "د"]

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.25, 0.30), # Ruby Red
	2: Color(0.25, 0.65, 1.00), # Sapphire Blue
	3: Color(0.22, 0.88, 0.44), # Emerald Green
	4: Color(1.00, 0.80, 0.18), # Sunburst Yellow
}

const KEYCAP_COORDS: Array[Vector3] = [
	Vector3(0.298, 0.052, 0.105),   # Option 1 (الف) - Top-Right (RTL)
	Vector3(-0.298, 0.052, 0.105),  # Option 2 (ب)   - Top-Left
	Vector3(0.298, 0.052, 0.375),   # Option 3 (ج)   - Bottom-Right
	Vector3(-0.298, 0.052, 0.375),  # Option 4 (د)   - Bottom-Left
]

const FACE_COL_DEFAULT: Color = Color(0.065, 0.045, 0.032)
const FACE_COL_HOVER: Color = Color(0.120, 0.082, 0.052)
const FACE_COL_SELECTED: Color = Color(0.06, 0.19, 0.36)
const FACE_COL_DIMMED: Color = Color(0.05, 0.038, 0.030)
const FACE_COL_CORRECT: Color = Color(0.05, 0.26, 0.12)
const FACE_COL_WRONG: Color = Color(0.28, 0.05, 0.07)

# --- Game State ---
var current_question_num: int = 1
var total_questions_count: int = 10
var current_question_text: String = ""
var current_category_title: String = ""
var current_options: Array = []
var selected_option_idx: int = 0
var has_answered_this_turn: bool = false
var is_in_reveal_phase: bool = false
var player_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var player_locked_in: Dictionary = {1: false, 2: false, 3: false, 4: false}
var surrendered_players: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _match_started: bool = false
var _requested_gamer_id_sync: bool = false

# --- Lectern Status & 3D Reveal Progress Bar ---
var _lectern_status_text: String = "⏳ گزینه درست را روی کلیدهای پایین لمس کنید"
var _lectern_status_color: Color = Color(1.0, 0.92, 0.58)
var _lectern_show_reveal_bar: bool = false
var _reveal_timer_tween: Tween = null
var _reveal_tween_pct: float = 0.0:
	set(v):
		_reveal_tween_pct = clampf(v, 0.0, 100.0)
		if is_instance_valid(_lectern_reveal_bar_fill):
			var ratio = clampf(_reveal_tween_pct / 100.0, 0.001, 1.0)
			_lectern_reveal_bar_fill.scale.x = ratio

# --- Input Tracking (Single-Source Camera Raycasting) ---
var hovered_option_idx: int = 0
var _is_pointer_down: bool = false
var _press_screen_pos: Vector2 = Vector2.ZERO
var _press_down_time: float = 0.0
var _last_click_time: float = 0.0
var _anim_time: float = 0.0
var _active_tweens: Array[Tween] = []

# --- Shared Procedural PBR Materials ---
var _mat_mahogany: StandardMaterial3D
var _mat_walnut: StandardMaterial3D
var _mat_brass: StandardMaterial3D
var _mat_emerald_felt: StandardMaterial3D
var _mat_obsidian_slate: StandardMaterial3D
var _mat_socket_bronze: StandardMaterial3D
var _mat_gem_unlit: StandardMaterial3D
var _mat_gem_done: StandardMaterial3D
var _mat_gem_active: StandardMaterial3D

# --- 3D Board Scene References ---
var stand_root: Node3D
var center_medallion: MeshInstance3D
var center_medallion_mat: StandardMaterial3D
var lbl_crown_counter: Label3D
var progress_gems: Array[MeshInstance3D] = []

# --- 3D Question Lectern (Pure Label3D) ---
var lectern_root: Node3D
var _lectern_cat_lbl: Label3D
var _lectern_cnt_lbl: Label3D
var _lectern_q_lbl: Label3D
var _lectern_status_lbl: Label3D
var _lectern_reveal_bar_bg: MeshInstance3D
var _lectern_reveal_bar_fill: MeshInstance3D

# --- 4 Physical 3D Keycaps (Pure Label3D) ---
var keycap_nodes: Array[Node3D] = []
var keycap_rim_mats: Array[StandardMaterial3D] = []
var keycap_face_mats: Array[StandardMaterial3D] = []
var keycap_hover_rings: Array[MeshInstance3D] = []
var keycap_badge_mats: Array[StandardMaterial3D] = []
var keycap_badge_labels: Array[Label3D] = []
var keycap_text_labels: Array[Label3D] = []
var keycap_token_anchors: Array[Node3D] = []
var keycap_areas: Array[Area3D] = []
var _spawned_answer_tokens: Array[Node3D] = []

# --- 2-4 Physical 3D Player Pedestals ---
var pedestals_container: Node3D
var player_pedestal_nodes: Dictionary = {}   # gid -> Node3D
var player_crystals: Dictionary = {}         # gid -> MeshInstance3D
var crystal_materials: Dictionary = {}       # gid -> StandardMaterial3D
var crystal_halos: Dictionary = {}           # gid -> MeshInstance3D
var player_nameplates: Dictionary = {}       # gid -> Label3D
var player_status_3d: Dictionary = {}        # gid -> Label3D
var _built_pedestal_count: int = 0

func _ready() -> void:
	game_type = GameTypes.QUIZ
	_setup_materials()
	_build_3d_board()
	super._ready()
	sync_turn_state()
	_rebuild_player_pedestals()
	_refresh_lectern_labels()

func _exit_tree() -> void:
	_kill_all_tweens()
	if _reveal_timer_tween and _reveal_timer_tween.is_valid():
		_reveal_timer_tween.kill()
		_reveal_timer_tween = null
	cleanup_board()
	super._exit_tree()

func _process(delta: float) -> void:
	_anim_time += delta * 2.8
	if is_instance_valid(center_medallion):
		center_medallion.rotate_y(delta * (1.5 if is_in_reveal_phase else 0.45))

	for gid in player_crystals.keys():
		var crys: MeshInstance3D = player_crystals[gid]
		if is_instance_valid(crys):
			var is_locked: bool = bool(player_locked_in.get(gid, false))
			crys.rotate_y(delta * (2.6 if is_locked else 0.7))
			crys.position.y = 0.062 + sin(_anim_time + float(gid) * 1.1) * (0.006 if is_locked else 0.0025)

		var halo = crystal_halos.get(gid)
		if is_instance_valid(halo) and halo.visible:
			var sc = 1.0 + sin(_anim_time * 2.2) * 0.09
			halo.scale = Vector3(sc, 1.0, sc)

# --- Turn & Network Sync ---
func _needs_gamer_id_sync() -> bool:
	if GameManager.match_players.is_empty():
		return true
	for p in GameManager.match_players:
		if typeof(p) == TYPE_DICTIONARY and int(p.get("gamer_id", 0)) <= 0:
			return true
	return false

func _trigger_silent_gamer_id_sync() -> void:
	if _requested_gamer_id_sync or not GameManager.is_game_active:
		return
	if not _needs_gamer_id_sync():
		return
	_requested_gamer_id_sync = true
	NetworkManager.silent_quiz_sync_pending = true
	NetworkManager.send_game_command("RequestReconnectData", {})

func sync_turn_state() -> void:
	# Simultaneous game: skip super.sync_turn_state() to prevent on_turn_changed infinite recursion
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	if not GameManager.is_game_active:
		is_my_turn = false
		is_board_locked = true
		return
	_match_started = true
	is_my_turn = true
	is_board_locked = is_in_reveal_phase or has_answered_this_turn
	_trigger_silent_gamer_id_sync()
	_rebuild_player_pedestals()
	_refresh_pedestals_text_and_lights()

func _sync_hud_scores() -> void:
	var s1 = _get_score_for_gid(1)
	var s2 = _get_score_for_gid(2)
	GameManager.p1_score = s1
	GameManager.p2_score = s2
	_update_header_scores()

# --- Materials ---
func _setup_materials() -> void:
	_mat_mahogany = StandardMaterial3D.new()
	_mat_mahogany.albedo_color = Color(0.16, 0.085, 0.05)
	_mat_mahogany.roughness = 0.36
	_mat_mahogany.metallic = 0.06

	_mat_walnut = StandardMaterial3D.new()
	_mat_walnut.albedo_color = Color(0.24, 0.135, 0.075)
	_mat_walnut.roughness = 0.32
	_mat_walnut.metallic = 0.05

	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.86, 0.69, 0.28)
	_mat_brass.metallic = 0.88
	_mat_brass.roughness = 0.24

	_mat_emerald_felt = StandardMaterial3D.new()
	_mat_emerald_felt.albedo_color = Color(0.055, 0.165, 0.11)
	_mat_emerald_felt.roughness = 0.92

	_mat_obsidian_slate = StandardMaterial3D.new()
	_mat_obsidian_slate.albedo_color = Color(0.055, 0.038, 0.028)
	_mat_obsidian_slate.roughness = 0.62
	_mat_obsidian_slate.metallic = 0.04

	_mat_socket_bronze = StandardMaterial3D.new()
	_mat_socket_bronze.albedo_color = Color(0.32, 0.24, 0.13)
	_mat_socket_bronze.metallic = 0.75
	_mat_socket_bronze.roughness = 0.35

	_mat_gem_unlit = StandardMaterial3D.new()
	_mat_gem_unlit.albedo_color = Color(0.16, 0.14, 0.12)
	_mat_gem_unlit.roughness = 0.40
	_mat_gem_unlit.metallic = 0.20

	_mat_gem_done = StandardMaterial3D.new()
	_mat_gem_done.albedo_color = Color(0.20, 0.84, 0.45)
	_mat_gem_done.roughness = 0.18
	_mat_gem_done.metallic = 0.35
	_mat_gem_done.emission_enabled = true
	_mat_gem_done.emission = Color(0.15, 0.72, 0.38)
	_mat_gem_done.emission_energy_multiplier = 1.2

	_mat_gem_active = StandardMaterial3D.new()
	_mat_gem_active.albedo_color = Color(1.0, 0.86, 0.28)
	_mat_gem_active.roughness = 0.12
	_mat_gem_active.metallic = 0.45
	_mat_gem_active.emission_enabled = true
	_mat_gem_active.emission = Color(1.0, 0.78, 0.20)
	_mat_gem_active.emission_energy_multiplier = 2.6

# --- 3D Tabletop Board Construction ---
func _build_3d_board() -> void:
	stand_root = Node3D.new()
	stand_root.name = "StandRoot"
	add_child(stand_root)

	# 1. Brass Outer Trim Base (1.28 x 1.34 footprint strictly within cafe_table safe zone)
	var rim_mesh = BoxMesh.new()
	rim_mesh.size = Vector3(1.28, 0.016, 1.34)
	var rim_inst = MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.material_override = _mat_brass
	rim_inst.position = Vector3(0.0, 0.008, 0.0)
	stand_root.add_child(rim_inst)

	# 2. Carved Mahogany Board Chassis
	var chassis_mesh = BoxMesh.new()
	chassis_mesh.size = Vector3(1.24, 0.036, 1.30)
	var chassis_inst = MeshInstance3D.new()
	chassis_inst.mesh = chassis_mesh
	chassis_inst.material_override = _mat_mahogany
	chassis_inst.position = Vector3(0.0, 0.022, 0.0)
	stand_root.add_child(chassis_inst)

	# 3. Recessed Emerald Velvet Felt Playing Bed
	var felt_mesh = BoxMesh.new()
	felt_mesh.size = Vector3(1.16, 0.012, 1.20)
	var felt_inst = MeshInstance3D.new()
	felt_inst.mesh = felt_mesh
	felt_inst.material_override = _mat_emerald_felt
	felt_inst.position = Vector3(0.0, 0.038, 0.0)
	stand_root.add_child(felt_inst)

	# 4. Corner Brass Bolsters
	var corner_mesh = CylinderMesh.new()
	corner_mesh.top_radius = 0.022
	corner_mesh.bottom_radius = 0.028
	corner_mesh.height = 0.018
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bolster = MeshInstance3D.new()
			bolster.mesh = corner_mesh
			bolster.material_override = _mat_brass
			bolster.position = Vector3(sx * 0.59, 0.044, sz * 0.61)
			stand_root.add_child(bolster)

	# 5. Top Crown Bar (10 Question Progress Sockets + Center Rotating Medallion)
	_build_top_crown_bar()

	# 6. Inclined 3D Walnut & Brass Question Lectern (Pure White Label3D)
	_build_question_lectern()

	# 7. Four Larger Physical 3D Interactive Answer Keycaps (الف، ب، ج، د)
	_build_answer_keycaps()

	# 8. Dynamic 2-4 Player Crystal Pedestals Container
	pedestals_container = Node3D.new()
	pedestals_container.name = "PlayerPedestals"
	stand_root.add_child(pedestals_container)

func _build_top_crown_bar() -> void:
	var crown = Node3D.new()
	crown.name = "TopCrownBar"
	crown.position = Vector3(0.0, 0.045, -0.585)
	stand_root.add_child(crown)

	var rail_mesh = BoxMesh.new()
	rail_mesh.size = Vector3(0.78, 0.018, 0.076)
	var rail = MeshInstance3D.new()
	rail.mesh = rail_mesh
	rail.material_override = _mat_walnut
	crown.add_child(rail)

	var rail_trim = BoxMesh.new()
	rail_trim.size = Vector3(0.80, 0.008, 0.084)
	var trim_inst = MeshInstance3D.new()
	trim_inst.mesh = rail_trim
	trim_inst.material_override = _mat_brass
	trim_inst.position = Vector3(0.0, -0.004, 0.0)
	crown.add_child(trim_inst)

	# Rotating Golden Medallion at Crown Center
	var torus = TorusMesh.new()
	torus.inner_radius = 0.020
	torus.outer_radius = 0.028
	center_medallion_mat = StandardMaterial3D.new()
	center_medallion_mat.albedo_color = Color(0.94, 0.78, 0.30)
	center_medallion_mat.metallic = 0.90
	center_medallion_mat.roughness = 0.18
	center_medallion_mat.emission_enabled = true
	center_medallion_mat.emission = Color(0.75, 0.56, 0.16)
	center_medallion_mat.emission_energy_multiplier = 0.55

	center_medallion = MeshInstance3D.new()
	center_medallion.mesh = torus
	center_medallion.material_override = center_medallion_mat
	center_medallion.position = Vector3(0.0, 0.026, -0.032)
	center_medallion.rotation_degrees.x = 70.0
	crown.add_child(center_medallion)

	# 10 Physical Brass Sockets & Gems across the Crown Bar
	progress_gems.clear()
	var sock_mesh = CylinderMesh.new()
	sock_mesh.top_radius = 0.015
	sock_mesh.bottom_radius = 0.018
	sock_mesh.height = 0.010

	var gem_mesh = SphereMesh.new()
	gem_mesh.radius = 0.011
	gem_mesh.height = 0.016
	gem_mesh.radial_segments = 10
	gem_mesh.rings = 6

	for i in range(10):
		var x_pos = -0.315 + float(i) * 0.070
		var sock = MeshInstance3D.new()
		sock.mesh = sock_mesh
		sock.material_override = _mat_socket_bronze
		sock.position = Vector3(x_pos, 0.010, 0.014)
		crown.add_child(sock)

		var gem = MeshInstance3D.new()
		gem.mesh = gem_mesh
		gem.material_override = _mat_gem_unlit
		gem.position = Vector3(x_pos, 0.017, 0.014)
		crown.add_child(gem)
		progress_gems.append(gem)

	lbl_crown_counter = Label3D.new()
	lbl_crown_counter.text = "سوال ۱ از ۱۰"
	lbl_crown_counter.font = FontHekayat
	lbl_crown_counter.font_size = 44
	lbl_crown_counter.pixel_size = 0.00120
	lbl_crown_counter.modulate = Color.WHITE
	lbl_crown_counter.outline_modulate = Color(0.03, 0.02, 0.01, 1.0)
	lbl_crown_counter.outline_size = 10
	lbl_crown_counter.shaded = false
	lbl_crown_counter.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl_crown_counter.position = Vector3(0.0, 0.015, -0.020)
	crown.add_child(lbl_crown_counter)

func _build_question_lectern() -> void:
	# Sculpted Lectern Placement (tall 0.44m tablet, clean clearance from crown & keycaps)
	lectern_root = Node3D.new()
	lectern_root.name = "QuestionLectern"
	lectern_root.position = Vector3(0.0, 0.058, -0.265)
	lectern_root.rotation_degrees = Vector3(5.0, 0.0, 0.0)
	stand_root.add_child(lectern_root)

	# Carved Walnut Lectern Body
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(1.18, 0.038, 0.44)
	var slab = MeshInstance3D.new()
	slab.mesh = slab_mesh
	slab.material_override = _mat_walnut
	lectern_root.add_child(slab)

	# Recessed Dark Obsidian Slate Tablet (high contrast against pure white Label3D)
	var slate_mesh = BoxMesh.new()
	slate_mesh.size = Vector3(1.13, 0.006, 0.39)
	var slate = MeshInstance3D.new()
	slate.mesh = slate_mesh
	slate.material_override = _mat_obsidian_slate
	slate.position = Vector3(0.0, 0.0195, 0.0)
	lectern_root.add_child(slate)

	# Raised Brushed Brass Bezel Rim (4 Bars)
	var w_bar = BoxMesh.new()
	w_bar.size = Vector3(1.20, 0.016, 0.022)
	for sz in [-1.0, 1.0]:
		var bar = MeshInstance3D.new()
		bar.mesh = w_bar
		bar.material_override = _mat_brass
		bar.position = Vector3(0.0, 0.019, sz * 0.212)
		lectern_root.add_child(bar)

	var h_bar = BoxMesh.new()
	h_bar.size = Vector3(0.022, 0.016, 0.445)
	for sx in [-1.0, 1.0]:
		var bar = MeshInstance3D.new()
		bar.mesh = h_bar
		bar.material_override = _mat_brass
		bar.position = Vector3(sx * 0.590, 0.019, 0.0)
		lectern_root.add_child(bar)

	# Brass Header Divider Strip inside Lectern
	var div_mesh = BoxMesh.new()
	div_mesh.size = Vector3(1.06, 0.003, 0.005)
	var div_bar = MeshInstance3D.new()
	div_bar.mesh = div_mesh
	div_bar.material_override = _mat_brass
	div_bar.position = Vector3(0.0, 0.023, -0.118)
	lectern_root.add_child(div_bar)

	# Question Counter Label3D (Left Top inside Lectern)
	_lectern_cnt_lbl = Label3D.new()
	_lectern_cnt_lbl.text = "سوال ۱ از ۱۰"
	_lectern_cnt_lbl.font = FontHekayat
	_lectern_cnt_lbl.font_size = 42
	_lectern_cnt_lbl.pixel_size = 0.00112
	_lectern_cnt_lbl.modulate = Color(0.75, 0.94, 1.0)
	_lectern_cnt_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 1.0)
	_lectern_cnt_lbl.outline_size = 10
	_lectern_cnt_lbl.shaded = false
	_lectern_cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lectern_cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lectern_cnt_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_lectern_cnt_lbl.position = Vector3(-0.34, 0.026, -0.156)
	lectern_root.add_child(_lectern_cnt_lbl)

	# Category Label3D (Right Top inside Lectern)
	_lectern_cat_lbl = Label3D.new()
	_lectern_cat_lbl.text = "✨ پرسش مسابقه"
	_lectern_cat_lbl.font = FontHekayat
	_lectern_cat_lbl.font_size = 42
	_lectern_cat_lbl.pixel_size = 0.00112
	_lectern_cat_lbl.modulate = Color(1.0, 0.90, 0.48)
	_lectern_cat_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 1.0)
	_lectern_cat_lbl.outline_size = 10
	_lectern_cat_lbl.shaded = false
	_lectern_cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lectern_cat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lectern_cat_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_lectern_cat_lbl.position = Vector3(0.32, 0.026, -0.156)
	lectern_root.add_child(_lectern_cat_lbl)

	# Main Question Body Label3D (Pure White, Large, Unshaded, Word-Wrapped)
	_lectern_q_lbl = Label3D.new()
	_lectern_q_lbl.text = "در حال بارگذاری سوال..."
	_lectern_q_lbl.font = FontHekayat
	_lectern_q_lbl.font_size = 66
	_lectern_q_lbl.pixel_size = 0.00138
	_lectern_q_lbl.width = 760.0
	_lectern_q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lectern_q_lbl.text_direction = TextServer.DIRECTION_AUTO
	_lectern_q_lbl.line_spacing = 6.0
	_lectern_q_lbl.modulate = Color.WHITE
	_lectern_q_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 1.0)
	_lectern_q_lbl.outline_size = 15
	_lectern_q_lbl.shaded = false
	_lectern_q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lectern_q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lectern_q_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_lectern_q_lbl.position = Vector3(0.0, 0.027, -0.008)
	lectern_root.add_child(_lectern_q_lbl)

	# Lectern Bottom Status Strip
	_lectern_status_lbl = Label3D.new()
	_lectern_status_lbl.text = _lectern_status_text
	_lectern_status_lbl.font = FontHekayat
	_lectern_status_lbl.font_size = 38
	_lectern_status_lbl.pixel_size = 0.00105
	_lectern_status_lbl.width = 980.0
	_lectern_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lectern_status_lbl.text_direction = TextServer.DIRECTION_AUTO
	_lectern_status_lbl.modulate = _lectern_status_color
	_lectern_status_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 1.0)
	_lectern_status_lbl.outline_size = 10
	_lectern_status_lbl.shaded = false
	_lectern_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lectern_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lectern_status_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_lectern_status_lbl.position = Vector3(0.0, 0.026, 0.142)
	lectern_root.add_child(_lectern_status_lbl)

	# 3D Golden Reveal Countdown Progress Bar
	var bar_bg_mesh = BoxMesh.new()
	bar_bg_mesh.size = Vector3(1.02, 0.004, 0.014)
	var bar_bg_mat = StandardMaterial3D.new()
	bar_bg_mat.albedo_color = Color(0.14, 0.10, 0.07)
	bar_bg_mat.roughness = 0.6

	_lectern_reveal_bar_bg = MeshInstance3D.new()
	_lectern_reveal_bar_bg.mesh = bar_bg_mesh
	_lectern_reveal_bar_bg.material_override = bar_bg_mat
	_lectern_reveal_bar_bg.position = Vector3(0.0, 0.024, 0.178)
	_lectern_reveal_bar_bg.visible = false
	lectern_root.add_child(_lectern_reveal_bar_bg)

	var bar_fill_mesh = BoxMesh.new()
	bar_fill_mesh.size = Vector3(1.00, 0.005, 0.010)
	var bar_fill_mat = StandardMaterial3D.new()
	bar_fill_mat.albedo_color = Color(1.0, 0.85, 0.30)
	bar_fill_mat.emission_enabled = true
	bar_fill_mat.emission = Color(1.0, 0.82, 0.25)
	bar_fill_mat.emission_energy_multiplier = 1.6

	_lectern_reveal_bar_fill = MeshInstance3D.new()
	_lectern_reveal_bar_fill.mesh = bar_fill_mesh
	_lectern_reveal_bar_fill.material_override = bar_fill_mat
	_lectern_reveal_bar_fill.position = Vector3(0.0, 0.025, 0.178)
	_lectern_reveal_bar_fill.visible = false
	lectern_root.add_child(_lectern_reveal_bar_fill)

func _build_answer_keycaps() -> void:
	keycap_nodes.clear()
	keycap_rim_mats.clear()
	keycap_face_mats.clear()
	keycap_hover_rings.clear()
	keycap_badge_mats.clear()
	keycap_badge_labels.clear()
	keycap_text_labels.clear()
	keycap_token_anchors.clear()
	keycap_areas.clear()

	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.562, 0.034, 0.238)

	var face_mesh = BoxMesh.new()
	face_mesh.size = Vector3(0.530, 0.006, 0.206)

	var rim_mesh = BoxMesh.new()
	rim_mesh.size = Vector3(0.580, 0.018, 0.256)

	var badge_mesh = CylinderMesh.new()
	badge_mesh.top_radius = 0.029
	badge_mesh.bottom_radius = 0.033
	badge_mesh.height = 0.016

	var hover_mesh = BoxMesh.new()
	hover_mesh.size = Vector3(0.596, 0.008, 0.270)
	var hover_mat = StandardMaterial3D.new()
	hover_mat.albedo_color = Color(1.0, 0.85, 0.30, 0.85)
	hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hover_mat.emission_enabled = true
	hover_mat.emission = Color(1.0, 0.82, 0.25)
	hover_mat.emission_energy_multiplier = 1.9

	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(0.57, 0.12, 0.25)

	for i in range(4):
		var opt_idx: int = i + 1
		var cap = Node3D.new()
		cap.name = "AnswerKeycap%d" % opt_idx
		cap.position = KEYCAP_COORDS[i]
		cap.rotation_degrees = Vector3(4.5, 0.0, 0.0)
		stand_root.add_child(cap)
		keycap_nodes.append(cap)

		# Metallic Status Collar Rim
		var r_mat = StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.84, 0.67, 0.28)
		r_mat.metallic = 0.86
		r_mat.roughness = 0.24
		keycap_rim_mats.append(r_mat)

		var rim = MeshInstance3D.new()
		rim.mesh = rim_mesh
		rim.material_override = r_mat
		rim.position = Vector3(0.0, -0.004, 0.0)
		cap.add_child(rim)

		# Subtle Hover Highlight Plate
		var h_ring = MeshInstance3D.new()
		h_ring.mesh = hover_mesh
		h_ring.material_override = hover_mat
		h_ring.position = Vector3(0.0, -0.009, 0.0)
		h_ring.visible = false
		cap.add_child(h_ring)
		keycap_hover_rings.append(h_ring)

		# Walnut Keycap Body
		var body = MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = _mat_walnut
		cap.add_child(body)

		# Dark Inlaid Slate Face Plate (High contrast for pure white option text)
		var f_mat = StandardMaterial3D.new()
		f_mat.albedo_color = FACE_COL_DEFAULT
		f_mat.roughness = 0.62
		f_mat.metallic = 0.04
		keycap_face_mats.append(f_mat)

		var face_plate = MeshInstance3D.new()
		face_plate.mesh = face_mesh
		face_plate.material_override = f_mat
		face_plate.position = Vector3(0.0, 0.018, 0.0)
		cap.add_child(face_plate)

		# Pure White Large Unshaded Label3D for Option Text
		var o_lbl = Label3D.new()
		o_lbl.text = "گزینه %s" % OPTION_LETTERS[i]
		o_lbl.font = FontHekayat
		o_lbl.font_size = 58
		o_lbl.pixel_size = 0.00128
		o_lbl.width = 330.0
		o_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o_lbl.text_direction = TextServer.DIRECTION_AUTO
		o_lbl.line_spacing = 4.0
		o_lbl.modulate = Color.WHITE
		o_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 1.0)
		o_lbl.outline_size = 14
		o_lbl.shaded = false
		o_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		o_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		o_lbl.position = Vector3(-0.042, 0.025, 0.0)
		cap.add_child(o_lbl)
		keycap_text_labels.append(o_lbl)

		# Raised 3D Letter Medallion on Right Side of Keycap
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = Color(0.24, 0.15, 0.08)
		b_mat.metallic = 0.45
		b_mat.roughness = 0.28
		keycap_badge_mats.append(b_mat)

		var b_cyl = MeshInstance3D.new()
		b_cyl.mesh = badge_mesh
		b_cyl.material_override = b_mat
		b_cyl.position = Vector3(0.226, 0.024, 0.0)
		cap.add_child(b_cyl)

		var b_lbl = Label3D.new()
		b_lbl.text = OPTION_LETTERS[i]
		b_lbl.font = FontHekayat
		b_lbl.font_size = 54
		b_lbl.pixel_size = 0.00095
		b_lbl.modulate = Color.WHITE
		b_lbl.outline_modulate = Color(0.03, 0.015, 0.01, 1.0)
		b_lbl.outline_size = 10
		b_lbl.shaded = false
		b_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		b_lbl.position = Vector3(0.226, 0.034, 0.0)
		cap.add_child(b_lbl)
		keycap_badge_labels.append(b_lbl)

		# Token Anchor for Lock Seal & Reveal Player Pucks
		var anchor = Node3D.new()
		anchor.name = "TokenAnchor"
		anchor.position = Vector3(-0.205, 0.024, 0.076)
		cap.add_child(anchor)
		keycap_token_anchors.append(anchor)

		# Raycast Area3D Collider (input via _unhandled_input ONLY)
		var area = Area3D.new()
		area.name = "AreaOption%d" % opt_idx
		area.set_meta("option_idx", opt_idx)
		area.input_ray_pickable = true
		var cs = CollisionShape3D.new()
		cs.shape = col_shape
		cs.position = Vector3(0.0, 0.02, 0.0)
		area.add_child(cs)
		cap.add_child(area)
		keycap_areas.append(area)

# --- 2-4 Player Crystal Pedestals ---
func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)

func _rebuild_player_pedestals() -> void:
	if not is_instance_valid(pedestals_container):
		return
	var total_p: int = _get_total_players()
	if _built_pedestal_count != total_p:
		for child in pedestals_container.get_children():
			child.queue_free()
		player_pedestal_nodes.clear()
		player_crystals.clear()
		crystal_materials.clear()
		crystal_halos.clear()
		player_nameplates.clear()
		player_status_3d.clear()
		_built_pedestal_count = total_p

		var coords_2p: Dictionary = {
			1: Vector3(-0.34, 0.045, 0.580),
			2: Vector3(0.34, 0.045, 0.580),
		}
		var coords_4p: Dictionary = {
			1: Vector3(-0.34, 0.045, 0.580),
			2: Vector3(0.34, 0.045, 0.580),
			3: Vector3(-0.505, 0.045, -0.585),
			4: Vector3(0.505, 0.045, -0.585),
		}
		var coords = coords_2p if total_p <= 2 else coords_4p

		var sock_mesh = CylinderMesh.new()
		sock_mesh.top_radius = 0.036
		sock_mesh.bottom_radius = 0.044
		sock_mesh.height = 0.022

		var crystal_mesh = SphereMesh.new()
		crystal_mesh.radius = 0.030
		crystal_mesh.height = 0.068
		crystal_mesh.radial_segments = 6
		crystal_mesh.rings = 2

		var halo_mesh = TorusMesh.new()
		halo_mesh.inner_radius = 0.038
		halo_mesh.outer_radius = 0.048
		halo_mesh.rings = 20

		for gid in range(1, total_p + 1):
			var pos: Vector3 = coords.get(gid, Vector3.ZERO)
			var col: Color = FACTION_COLORS.get(gid, Color.WHITE)

			var ped = Node3D.new()
			ped.name = "PedestalP%d" % gid
			ped.position = pos
			pedestals_container.add_child(ped)
			player_pedestal_nodes[gid] = ped

			var sock = MeshInstance3D.new()
			sock.mesh = sock_mesh
			sock.material_override = _mat_brass
			sock.position = Vector3(0.0, 0.011, 0.0)
			ped.add_child(sock)

			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = col.darkened(0.35)
			c_mat.metallic = 0.45
			c_mat.roughness = 0.14
			c_mat.emission_enabled = true
			c_mat.emission = col.darkened(0.65)
			c_mat.emission_energy_multiplier = 0.45

			var crys = MeshInstance3D.new()
			crys.mesh = crystal_mesh
			crys.material_override = c_mat
			crys.position = Vector3(0.0, 0.062, 0.0)
			ped.add_child(crys)

			var h_mat = StandardMaterial3D.new()
			h_mat.albedo_color = col
			h_mat.emission_enabled = true
			h_mat.emission = col
			h_mat.emission_energy_multiplier = 2.4

			var halo = MeshInstance3D.new()
			halo.mesh = halo_mesh
			halo.material_override = h_mat
			halo.position = Vector3(0.0, 0.022, 0.0)
			halo.visible = false
			ped.add_child(halo)

			var lbl_name = Label3D.new()
			lbl_name.font = FontHekayat
			lbl_name.font_size = 38
			lbl_name.pixel_size = 0.00112
			lbl_name.modulate = Color.WHITE
			lbl_name.outline_modulate = Color(0.03, 0.015, 0.01, 1.0)
			lbl_name.outline_size = 9
			lbl_name.shaded = false
			lbl_name.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			var text_x_offset: float = 0.15 if gid == 1 else -0.15
			if total_p > 2 and gid >= 3:
				text_x_offset = 0.0
			var text_z_offset: float = 0.016 if gid <= 2 else 0.052
			lbl_name.position = Vector3(text_x_offset, 0.016, text_z_offset - 0.018)
			ped.add_child(lbl_name)

			var lbl_st = Label3D.new()
			lbl_st.font = FontHekayat
			lbl_st.font_size = 34
			lbl_st.pixel_size = 0.00108
			lbl_st.modulate = Color(1.0, 0.92, 0.62)
			lbl_st.outline_modulate = Color(0.03, 0.015, 0.01, 1.0)
			lbl_st.outline_size = 8
			lbl_st.shaded = false
			lbl_st.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			lbl_st.position = Vector3(text_x_offset, 0.016, text_z_offset + 0.024)
			ped.add_child(lbl_st)

			player_crystals[gid] = crys
			crystal_materials[gid] = c_mat
			crystal_halos[gid] = halo
			player_nameplates[gid] = lbl_name
			player_status_3d[gid] = lbl_st

	_refresh_pedestals_text_and_lights()

func _refresh_pedestals_text_and_lights() -> void:
	for gid in player_nameplates.keys():
		var lbl_name: Label3D = player_nameplates[gid]
		if is_instance_valid(lbl_name):
			var p_name = _short_name(_get_player_name(gid))
			lbl_name.text = ("%s (شما)" % p_name) if gid == my_player_index else p_name
		if bool(surrendered_players.get(gid, false)):
			_update_crystal_light(gid, false)
			_set_pedestal_status(gid, "🏳️ انصراف", Color(1.0, 0.45, 0.45))
			continue
		var locked = bool(player_locked_in.get(gid, false))
		_update_crystal_light(gid, locked)
		if not is_in_reveal_phase:
			_set_pedestal_status(gid, "🔒 ثبت شد" if locked else "⏳ آماده", Color(0.45, 0.95, 1.0) if locked else Color(1.0, 0.92, 0.62))

func _set_pedestal_status(gid: int, text: String, col: Color) -> void:
	var lbl = player_status_3d.get(gid)
	if is_instance_valid(lbl):
		lbl.text = text
		lbl.modulate = col

# --- Single-Source Input Raycasting ---
func _is_hud_overlay_blocking() -> bool:
	if not _match_started or not GameManager.is_game_active:
		return true
	var hud = _get_active_hud()
	if is_instance_valid(hud):
		if "is_start_overlay_dismissed" in hud and not hud.is_start_overlay_dismissed:
			return true
		for dlg_name in ["StartGameOverlay", "GameResultDialog", "SurrenderDialog", "DisconnectPauseDialog", "UserProfileDialog", "ReactionPicker"]:
			var dlg = hud.get_node_or_null(dlg_name)
			if is_instance_valid(dlg) and dlg.visible:
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if _is_hud_overlay_blocking() or is_board_locked or has_answered_this_turn or is_in_reveal_phase:
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
		elif _is_pointer_down:
			_is_pointer_down = false
			var dist = _press_screen_pos.distance_to(event.position)
			var elapsed = (Time.get_ticks_msec() / 1000.0) - _press_down_time
			if dist <= DRAG_THRESHOLD and elapsed < 0.75:
				_handle_pointer_tap(event.position)
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_is_pointer_down = true
			_press_screen_pos = event.position
			_press_down_time = Time.get_ticks_msec() / 1000.0
			_handle_pointer_hover(event.position)
		elif _is_pointer_down:
			_is_pointer_down = false
			var dist = _press_screen_pos.distance_to(event.position)
			var elapsed = (Time.get_ticks_msec() / 1000.0) - _press_down_time
			if dist <= DRAG_THRESHOLD and elapsed < 0.75:
				_handle_pointer_tap(event.position)

func _raycast_option_at(screen_pos: Vector2) -> int:
	var vp = get_viewport()
	if not vp:
		return 0
	var cam = vp.get_camera_3d()
	if not cam:
		return 0
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 14.0
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return 0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var col_obj = result["collider"]
		if col_obj and col_obj.has_meta("option_idx"):
			var idx = int(col_obj.get_meta("option_idx"))
			if idx >= 1 and idx <= current_options.size():
				return idx
	return 0

func _handle_pointer_hover(screen_pos: Vector2) -> void:
	var opt = _raycast_option_at(screen_pos)
	if opt == hovered_option_idx:
		return
	hovered_option_idx = opt
	for i in range(4):
		var is_h = (i + 1 == hovered_option_idx and not is_board_locked and not has_answered_this_turn and not is_in_reveal_phase)
		if i < keycap_hover_rings.size() and is_instance_valid(keycap_hover_rings[i]):
			keycap_hover_rings[i].visible = is_h
		if i < keycap_face_mats.size() and not has_answered_this_turn and not is_in_reveal_phase:
			keycap_face_mats[i].albedo_color = FACE_COL_HOVER if is_h else FACE_COL_DEFAULT
		if i < keycap_nodes.size() and is_instance_valid(keycap_nodes[i]) and not has_answered_this_turn and not is_in_reveal_phase:
			keycap_nodes[i].position.y = KEYCAP_COORDS[i].y + (0.008 if is_h else 0.0)

func _clear_hover() -> void:
	if hovered_option_idx == 0:
		return
	hovered_option_idx = 0
	for i in range(4):
		if i < keycap_hover_rings.size() and is_instance_valid(keycap_hover_rings[i]):
			keycap_hover_rings[i].visible = false
		if i < keycap_face_mats.size() and not has_answered_this_turn and not is_in_reveal_phase:
			keycap_face_mats[i].albedo_color = FACE_COL_DEFAULT
		if i < keycap_nodes.size() and is_instance_valid(keycap_nodes[i]) and not has_answered_this_turn and not is_in_reveal_phase:
			keycap_nodes[i].position.y = KEYCAP_COORDS[i].y

func _handle_pointer_tap(screen_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_click_time < 0.25:
		return
	var opt = _raycast_option_at(screen_pos)
	if opt <= 0 or opt > current_options.size():
		return
	_last_click_time = now
	_select_option(opt)

# --- Local Player Selection ---
func _select_option(opt_idx: int) -> void:
	if is_board_locked or has_answered_this_turn or is_in_reveal_phase or not GameManager.is_game_active:
		return

	has_answered_this_turn = true
	selected_option_idx = opt_idx
	set_board_locked(true)
	_clear_hover()
	player_locked_in[my_player_index] = true
	AudioManager.play_sound("add_peace")

	_style_keycaps_selected(opt_idx)
	_spawn_local_lock_seal(opt_idx)
	_update_crystal_light(my_player_index, true)
	_set_pedestal_status(my_player_index, "🔒 ثبت شد", Color(0.45, 0.95, 1.0))

	var letter = OPTION_LETTERS[clampi(opt_idx - 1, 0, 3)]
	_lectern_status_text = "🔒 انتخاب شما («%s») ثبت شد — در انتظار سایر بازیکنان..." % letter
	_lectern_status_color = Color(0.55, 0.92, 1.0)
	_lectern_show_reveal_bar = false
	_refresh_lectern_labels()

	_set_header_local_answered(true)
	send_move(Commands.Select_Peace, {"option": opt_idx})

func _style_keycaps_selected(opt_idx: int) -> void:
	for i in range(4):
		var is_sel = ((i + 1) == opt_idx)
		var cap = keycap_nodes[i]
		var r_mat = keycap_rim_mats[i]
		var f_mat = keycap_face_mats[i]
		var b_mat = keycap_badge_mats[i]
		var b_lbl = keycap_badge_labels[i]
		var t_lbl = keycap_text_labels[i]

		if is_sel:
			r_mat.albedo_color = Color(0.32, 0.80, 1.0)
			r_mat.emission_enabled = true
			r_mat.emission = Color(0.24, 0.72, 1.0)
			r_mat.emission_energy_multiplier = 2.0
			f_mat.albedo_color = FACE_COL_SELECTED
			b_mat.albedo_color = Color(0.14, 0.44, 0.78)
			b_lbl.modulate = Color.WHITE
			t_lbl.modulate = Color.WHITE
			var tw = _create_tracked_tween()
			tw.tween_property(cap, "position:y", KEYCAP_COORDS[i].y - 0.008, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(cap, "position:y", KEYCAP_COORDS[i].y + 0.004, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			r_mat.albedo_color = Color(0.32, 0.26, 0.16)
			r_mat.emission_enabled = false
			f_mat.albedo_color = FACE_COL_DIMMED
			b_mat.albedo_color = Color(0.16, 0.11, 0.07)
			b_lbl.modulate = Color(0.85, 0.82, 0.76)
			t_lbl.modulate = Color(0.82, 0.82, 0.82)
			cap.position.y = KEYCAP_COORDS[i].y - 0.003

func _spawn_local_lock_seal(opt_idx: int) -> void:
	_clear_answer_tokens()
	var idx = opt_idx - 1
	if idx < 0 or idx >= keycap_token_anchors.size():
		return
	var anchor = keycap_token_anchors[idx]
	var seal = _create_token_chip(my_player_index, "انتخاب شما", Color(0.55, 0.92, 1.0), true)
	anchor.add_child(seal)
	_spawned_answer_tokens.append(seal)
	seal.position = Vector3(0.0, 0.09, 0.0)
	seal.scale = Vector3(0.4, 0.4, 0.4)
	var tw = _create_tracked_tween().set_parallel(true)
	tw.tween_property(seal, "position:y", 0.010, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(seal, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Server Signal Hooks ---
func setup_board(_game_data: Dictionary) -> void:
	_rebuild_player_pedestals()
	_trigger_silent_gamer_id_sync()

func on_start_game() -> void:
	_match_started = true
	_rebuild_player_pedestals()
	_trigger_silent_gamer_id_sync()
	_refresh_lectern_labels()
	super.on_start_game()

func on_turn_data(payload: Dictionary) -> void:
	_handle_new_question_turn(payload, false)

func on_turn_changed(_turn: int, _is_me: bool) -> void:
	is_my_turn = true
	is_board_locked = is_in_reveal_phase or has_answered_this_turn

func _handle_new_question_turn(payload: Dictionary, preserve_if_same_turn: bool = false) -> void:
	var incoming_turn = int(payload.get("turn", payload.get("current_turn", current_question_num)))
	var same_active_turn: bool = preserve_if_same_turn and incoming_turn == current_question_num and not is_in_reveal_phase and has_answered_this_turn

	if not same_active_turn:
		if _reveal_timer_tween and _reveal_timer_tween.is_valid():
			_reveal_timer_tween.kill()
			_reveal_timer_tween = null
		_clear_answer_tokens()
		is_in_reveal_phase = false
		has_answered_this_turn = false
		selected_option_idx = 0
		set_board_locked(false)
		_clear_header_answered_states()
		for gid in player_locked_in.keys():
			player_locked_in[gid] = false

	_match_started = true
	my_player_index = GameManager.my_player_index
	current_question_num = max(1, incoming_turn)
	total_questions_count = max(1, int(payload.get("total_questions", 10)))
	current_question_text = str(payload.get("question", ""))
	current_options = payload.get("options", [])
	current_category_title = str(payload.get("category_title", "")).strip_edges()

	if payload.has("scores") and typeof(payload["scores"]) == TYPE_DICTIONARY:
		player_scores = payload["scores"]
		_sync_hud_scores()

	_trigger_silent_gamer_id_sync()
	_rebuild_player_pedestals()
	_refresh_pedestals_text_and_lights()
	_update_progress_gems()

	if is_instance_valid(center_medallion_mat):
		center_medallion_mat.emission = Color(0.75, 0.56, 0.16)
		center_medallion_mat.emission_energy_multiplier = 0.55
	if is_instance_valid(lbl_crown_counter):
		lbl_crown_counter.text = "سوال %s از %s" % [_fa_digits(current_question_num), _fa_digits(total_questions_count)]

	if not same_active_turn:
		_lectern_status_text = "⏳ گزینه درست را روی کلیدهای پایین لمس کنید"
		_lectern_status_color = Color(1.0, 0.92, 0.58)
		_lectern_show_reveal_bar = false
		_reset_keycaps_for_question()
	else:
		_refresh_option_texts_only()

	_refresh_lectern_labels()
	call_deferred("_sync_header_for_question", current_question_num, total_questions_count)

func _reset_keycaps_for_question() -> void:
	for i in range(4):
		var cap = keycap_nodes[i]
		var r_mat = keycap_rim_mats[i]
		var f_mat = keycap_face_mats[i]
		var b_mat = keycap_badge_mats[i]
		var b_lbl = keycap_badge_labels[i]
		var lbl = keycap_text_labels[i]
		var area = keycap_areas[i]

		var has_opt = (i < current_options.size())
		cap.visible = has_opt
		area.monitoring = has_opt
		area.input_ray_pickable = has_opt
		keycap_hover_rings[i].visible = false

		if has_opt:
			var opt_text = str(current_options[i])
			lbl.text = opt_text
			lbl.font_size = _fit_option_font_size(opt_text)
			lbl.modulate = Color.WHITE
			r_mat.albedo_color = Color(0.84, 0.67, 0.28)
			r_mat.emission_enabled = false
			f_mat.albedo_color = FACE_COL_DEFAULT
			b_mat.albedo_color = Color(0.24, 0.15, 0.08)
			b_lbl.text = OPTION_LETTERS[i]
			b_lbl.modulate = Color.WHITE
			cap.position = KEYCAP_COORDS[i] + Vector3(0.0, 0.016, 0.0)
			var tw = _create_tracked_tween()
			tw.tween_property(cap, "position:y", KEYCAP_COORDS[i].y, 0.20 + float(i) * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_option_texts_only() -> void:
	for i in range(min(4, current_options.size())):
		var opt_text = str(current_options[i])
		keycap_text_labels[i].text = opt_text
		keycap_text_labels[i].font_size = _fit_option_font_size(opt_text)
		keycap_text_labels[i].modulate = Color.WHITE

func _sync_header_for_question(q_num: int, q_total: int) -> void:
	if is_in_reveal_phase:
		return
	_set_header_round_label(q_num, q_total)
	if has_answered_this_turn:
		_set_header_local_answered(true)
	else:
		_set_header_banner("🤔 گزینه درست را روی میز انتخاب کنید", Color(1.0, 0.90, 0.45))

func on_player_surrendered(gamer_id: int) -> void:
	if gamer_id <= 0:
		return
	surrendered_players[gamer_id] = true
	player_locked_in[gamer_id] = false
	_update_crystal_light(gamer_id, false)
	_set_pedestal_status(gamer_id, "🏳️ انصراف", Color(1.0, 0.45, 0.45))
	_set_header_player_surrendered(gamer_id)

func on_piece_selected(user_id: int, _target_peace: int, _extra: Dictionary = {}) -> void:
	# Server notifies which gamer_id locked an answer (never exposes chosen option)
	if user_id <= 0:
		return
	player_locked_in[user_id] = true
	_update_crystal_light(user_id, true)
	_set_pedestal_status(user_id, "🔒 ثبت شد", Color(0.45, 0.95, 1.0))
	_set_header_player_answered(user_id, true)

	# Defense in depth: if server says my_player_index locked in before user tapped, our gamer_id must have shuffled
	if user_id == my_player_index and not has_answered_this_turn:
		_trigger_silent_gamer_id_sync()

func on_finish_turn_round(data: Dictionary) -> void:
	_apply_finish_turn_round(data, true)

func _apply_finish_turn_round(data: Dictionary, play_sfx: bool = true) -> void:
	is_in_reveal_phase = true
	set_board_locked(true)
	_clear_hover()
	my_player_index = GameManager.my_player_index

	var correct_opt = int(data.get("correct_option", 0))
	var player_answers: Dictionary = data.get("player_answers", {}) if typeof(data.get("player_answers", {})) == TYPE_DICTIONARY else {}
	if data.has("scores") and typeof(data["scores"]) == TYPE_DICTIONARY:
		player_scores = data["scores"]
		_sync_hud_scores()

	var cat = str(data.get("category_title", "")).strip_edges()
	if not cat.is_empty():
		current_category_title = cat

	if is_instance_valid(center_medallion_mat):
		center_medallion_mat.emission = Color(0.25, 0.95, 0.50)
		center_medallion_mat.emission_energy_multiplier = 2.0

	_clear_answer_tokens()

	# Style 3D Keycaps for Reveal (keep answer text pure white & prominent)
	for i in range(4):
		var opt_num = i + 1
		var cap = keycap_nodes[i]
		if not cap.visible:
			continue
		var r_mat = keycap_rim_mats[i]
		var f_mat = keycap_face_mats[i]
		var b_mat = keycap_badge_mats[i]
		var b_lbl = keycap_badge_labels[i]
		var t_lbl = keycap_text_labels[i]

		if opt_num == correct_opt:
			r_mat.albedo_color = Color(0.28, 0.98, 0.50)
			r_mat.emission_enabled = true
			r_mat.emission = Color(0.22, 0.92, 0.44)
			r_mat.emission_energy_multiplier = 2.4
			f_mat.albedo_color = FACE_COL_CORRECT
			b_mat.albedo_color = Color(0.10, 0.60, 0.26)
			b_lbl.text = "✓"
			b_lbl.modulate = Color.WHITE
			t_lbl.modulate = Color.WHITE
			var tw = _create_tracked_tween()
			tw.tween_property(cap, "position:y", KEYCAP_COORDS[i].y + 0.018, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_spawn_3d_ring_burst(cap.global_position + Vector3(0.0, 0.025, 0.0), Color(0.30, 0.98, 0.52))
			_spawn_floating_3d_text("+۱", cap.global_position + Vector3(0.0, 0.06, 0.0), Color(0.35, 0.98, 0.55))
		elif opt_num == selected_option_idx:
			r_mat.albedo_color = Color(1.0, 0.30, 0.34)
			r_mat.emission_enabled = true
			r_mat.emission = Color(0.95, 0.22, 0.26)
			r_mat.emission_energy_multiplier = 2.0
			f_mat.albedo_color = FACE_COL_WRONG
			b_mat.albedo_color = Color(0.68, 0.14, 0.18)
			b_lbl.text = "✕"
			b_lbl.modulate = Color.WHITE
			t_lbl.modulate = Color.WHITE
			var tw = _create_tracked_tween()
			tw.tween_property(cap, "position:x", KEYCAP_COORDS[i].x + 0.014, 0.045)
			tw.tween_property(cap, "position:x", KEYCAP_COORDS[i].x - 0.014, 0.045)
			tw.tween_property(cap, "position:x", KEYCAP_COORDS[i].x + 0.008, 0.04)
			tw.tween_property(cap, "position:x", KEYCAP_COORDS[i].x, 0.04)
			_spawn_floating_3d_text("-۱", cap.global_position + Vector3(0.0, 0.06, 0.0), Color(1.0, 0.36, 0.38))
		else:
			r_mat.albedo_color = Color(0.28, 0.24, 0.18)
			r_mat.emission_enabled = false
			f_mat.albedo_color = FACE_COL_DIMMED
			b_mat.albedo_color = Color(0.14, 0.11, 0.08)
			b_lbl.modulate = Color(0.85, 0.82, 0.76)
			t_lbl.modulate = Color(0.88, 0.88, 0.88)
			cap.position.y = KEYCAP_COORDS[i].y - 0.004

	# Place physical 3D player answer pucks on chosen keycaps & update 3D pedestals
	var opt_slot_counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
	for p_key in player_answers.keys():
		var p_info = player_answers[p_key]
		if typeof(p_info) != TYPE_DICTIONARY:
			continue
		var gid = int(p_info.get("gamer_id", p_key))
		var chosen_opt = int(p_info.get("option", 0))
		var is_corr = bool(p_info.get("is_correct", false))
		var delta = int(p_info.get("score_delta", 0))

		if delta > 0:
			_set_pedestal_status(gid, "✅ +۱", Color(0.40, 1.0, 0.58))
		elif delta < 0:
			_set_pedestal_status(gid, "❌ -۱", Color(1.0, 0.44, 0.46))
		else:
			_set_pedestal_status(gid, "⏱️ ۰", Color(0.85, 0.85, 0.88))

		if chosen_opt >= 1 and chosen_opt <= 4:
			var anchor = keycap_token_anchors[chosen_opt - 1]
			var slot_i = int(opt_slot_counts.get(chosen_opt, 0))
			opt_slot_counts[chosen_opt] = slot_i + 1
			var d_str = "+۱" if delta > 0 else ("-۱" if delta < 0 else "۰")
			var chip_lbl = "%s (%s)" % [_short_name(_get_player_name(gid), 8), d_str]
			var col = Color(0.45, 1.0, 0.62) if is_corr else Color(1.0, 0.45, 0.48)
			var chip = _create_token_chip(gid, chip_lbl, col, false)
			anchor.add_child(chip)
			_spawned_answer_tokens.append(chip)
			var target_x = float(slot_i) * 0.088
			chip.position = Vector3(target_x, 0.085, 0.0)
			var tw = _create_tracked_tween()
			tw.tween_property(chip, "position:y", 0.010, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Local result audio & 3D lectern reveal banner
	var my_result = player_answers.get(str(my_player_index), player_answers.get(my_player_index, {}))
	var correct_letter = OPTION_LETTERS[clampi(correct_opt - 1, 0, 3)]
	var my_corr = bool(my_result.get("is_correct", false)) if typeof(my_result) == TYPE_DICTIONARY else false
	var my_delta = int(my_result.get("score_delta", 0)) if typeof(my_result) == TYPE_DICTIONARY else 0

	if my_corr:
		if play_sfx:
			AudioManager.play_sound("win")
		_lectern_status_text = "🎉 آفرین! پاسخ درست بود (+۱) • گزینه صحیح: «%s»" % correct_letter
		_lectern_status_color = Color(0.48, 1.0, 0.66)
		_set_header_banner("🎉 آفرین! پاسخ شما صحیح بود (+۱)", Color(0.35, 0.98, 0.52))
	elif my_delta < 0:
		if play_sfx:
			AudioManager.play_sound("lose")
		_lectern_status_text = "❌ پاسخ نادرست بود (-۱) • گزینه صحیح: «%s»" % correct_letter
		_lectern_status_color = Color(1.0, 0.52, 0.54)
		_set_header_banner("❌ متأسفانه پاسخ نادرست بود (-۱)", Color(1.0, 0.35, 0.38))
	else:
		_lectern_status_text = "⏱️ مهلت تمام شد (۰) • گزینه صحیح: «%s»" % correct_letter
		_lectern_status_color = Color(1.0, 0.92, 0.58)
		_set_header_banner("⏳ مهلت پاسخ پایان یافت (۰)", Color(0.90, 0.90, 0.90))

	_lectern_show_reveal_bar = true
	_refresh_lectern_labels()

	if _reveal_timer_tween and _reveal_timer_tween.is_valid():
		_reveal_timer_tween.kill()
	_reveal_tween_pct = 100.0
	_reveal_timer_tween = create_tween()
	_reveal_timer_tween.tween_property(self, "_reveal_tween_pct", 0.0, 3.8)

# --- 3D Token & VFX Helpers ---
func _create_token_chip(gid: int, label_text: String, text_col: Color, is_seal: bool) -> Node3D:
	var holder = Node3D.new()
	var f_col: Color = FACTION_COLORS.get(gid, Color(0.25, 0.72, 1.0))

	var base_cyl = CylinderMesh.new()
	base_cyl.top_radius = 0.022 if is_seal else 0.018
	base_cyl.bottom_radius = 0.025 if is_seal else 0.021
	base_cyl.height = 0.012
	var chip_mat = StandardMaterial3D.new()
	chip_mat.albedo_color = f_col
	chip_mat.metallic = 0.35
	chip_mat.roughness = 0.22
	chip_mat.emission_enabled = true
	chip_mat.emission = f_col
	chip_mat.emission_energy_multiplier = 0.9 if is_seal else 0.7

	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_cyl
	base_inst.material_override = chip_mat
	holder.add_child(base_inst)

	var ring = TorusMesh.new()
	ring.inner_radius = 0.020 if is_seal else 0.016
	ring.outer_radius = 0.025 if is_seal else 0.021
	var ring_inst = MeshInstance3D.new()
	ring_inst.mesh = ring
	ring_inst.material_override = _mat_brass
	ring_inst.position = Vector3(0.0, 0.006, 0.0)
	holder.add_child(ring_inst)

	var lbl = Label3D.new()
	lbl.text = label_text
	lbl.font = FontHekayat
	lbl.font_size = 32
	lbl.pixel_size = 0.00105
	lbl.modulate = text_col
	lbl.outline_modulate = Color(0.03, 0.015, 0.01, 1.0)
	lbl.outline_size = 8
	lbl.shaded = false
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.0, 0.018, -0.032)
	holder.add_child(lbl)

	return holder

func _clear_answer_tokens() -> void:
	for t in _spawned_answer_tokens:
		if is_instance_valid(t):
			t.queue_free()
	_spawned_answer_tokens.clear()

func _spawn_3d_ring_burst(world_pos: Vector3, col: Color) -> void:
	if not is_instance_valid(stand_root):
		return
	var torus = TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.10
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.6

	var ring = MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	stand_root.add_child(ring)
	ring.global_position = world_pos
	ring.scale = Vector3(0.5, 1.0, 0.5)

	var tw = _create_tracked_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_floating_3d_text(text: String, world_pos: Vector3, col: Color) -> void:
	if not is_instance_valid(stand_root):
		return
	var lbl = Label3D.new()
	lbl.text = text
	lbl.font = FontHekayat
	lbl.font_size = 76
	lbl.pixel_size = 0.00145
	lbl.modulate = col
	lbl.outline_modulate = Color(0.03, 0.015, 0.01, 1.0)
	lbl.outline_size = 10
	lbl.shaded = false
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stand_root.add_child(lbl)
	lbl.global_position = world_pos

	var tw = _create_tracked_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position:y", world_pos.y + 0.16, 0.95).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(0.50)
	tw.chain().tween_callback(lbl.queue_free)

# --- Progress Gems, Pedestal Lights & 3D Lectern Labels ---
func _update_progress_gems() -> void:
	for i in range(progress_gems.size()):
		var gem = progress_gems[i]
		if not is_instance_valid(gem):
			continue
		var q_idx = i + 1
		gem.visible = (q_idx <= total_questions_count)
		if q_idx < current_question_num:
			gem.material_override = _mat_gem_done
			gem.scale = Vector3.ONE
		elif q_idx == current_question_num:
			gem.material_override = _mat_gem_active
			gem.scale = Vector3(1.32, 1.32, 1.32)
		else:
			gem.material_override = _mat_gem_unlit
			gem.scale = Vector3(0.85, 0.85, 0.85)

func _update_crystal_light(gid: int, is_active: bool) -> void:
	if not crystal_materials.has(gid):
		return
	var mat: StandardMaterial3D = crystal_materials[gid]
	var col: Color = FACTION_COLORS.get(gid, Color.WHITE)
	var halo = crystal_halos.get(gid)
	if is_instance_valid(halo):
		halo.visible = is_active
	var tw = _create_tracked_tween().set_parallel(true)
	if is_active:
		tw.tween_property(mat, "albedo_color", col.lightened(0.25), 0.18)
		tw.tween_property(mat, "emission", col, 0.18)
		tw.tween_property(mat, "emission_energy_multiplier", 3.4, 0.18)
	else:
		tw.tween_property(mat, "albedo_color", col.darkened(0.35), 0.25)
		tw.tween_property(mat, "emission", col.darkened(0.65), 0.25)
		tw.tween_property(mat, "emission_energy_multiplier", 0.45, 0.25)

func _refresh_lectern_labels() -> void:
	var cat_display: String = current_category_title
	if cat_display.is_empty():
		cat_display = "✨ پرسش مسابقه"
	elif not ("🎥" in cat_display or "📺" in cat_display or "🖋" in cat_display or "🎧" in cat_display or "🗿" in cat_display or "🔠" in cat_display or "📡" in cat_display or "🔬" in cat_display or "🎨" in cat_display or "📚" in cat_display or "🏓" in cat_display or "🤓" in cat_display or "📖" in cat_display or "💡" in cat_display):
		cat_display = "💡 " + cat_display

	if is_instance_valid(_lectern_cat_lbl):
		_lectern_cat_lbl.text = cat_display
	if is_instance_valid(_lectern_cnt_lbl):
		_lectern_cnt_lbl.text = "سوال %s از %s" % [_fa_digits(current_question_num), _fa_digits(total_questions_count)]
	if is_instance_valid(_lectern_q_lbl):
		var q_str = current_question_text if not current_question_text.is_empty() else "در حال بارگذاری سوال..."
		_lectern_q_lbl.text = q_str
		_lectern_q_lbl.modulate = Color.WHITE
		var l_len = q_str.length()
		_lectern_q_lbl.font_size = 66 if l_len <= 46 else (56 if l_len <= 90 else 48)
	if is_instance_valid(_lectern_status_lbl):
		_lectern_status_lbl.text = _lectern_status_text
		_lectern_status_lbl.modulate = _lectern_status_color
	if is_instance_valid(_lectern_reveal_bar_bg):
		_lectern_reveal_bar_bg.visible = _lectern_show_reveal_bar
	if is_instance_valid(_lectern_reveal_bar_fill):
		_lectern_reveal_bar_fill.visible = _lectern_show_reveal_bar

func _fit_option_font_size(text: String) -> int:
	var n = text.length()
	if n <= 14:
		return 58
	elif n <= 26:
		return 48
	return 40

func _short_name(s: String, max_len: int = 12) -> String:
	var trimmed = s.strip_edges()
	if trimmed.length() <= max_len:
		return trimmed
	return trimmed.substr(0, max_len - 1) + "…"

func _get_player_name(gid: int) -> String:
	var p_data = GameManager.get_player_data_by_gamer_id(gid)
	return str(p_data.get("name", p_data.get("username", "بازیکن %s" % _fa_digits(gid))))

# --- Header Communication Helpers ---
func _update_header_scores() -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if not is_instance_valid(header):
		return
	if header.has_method("update_quiz_scores"):
		header.update_quiz_scores(player_scores)
	elif header.has_method("update_scores"):
		header.update_scores(_get_score_for_gid(1), _get_score_for_gid(2))

func _get_score_for_gid(gid: int) -> int:
	if player_scores.has(gid):
		return int(player_scores[gid])
	if player_scores.has(str(gid)):
		return int(player_scores[str(gid)])
	return 0

func _set_header_banner(text: String, col: Color = Color(1.0, 0.88, 0.45)) -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if not is_instance_valid(header):
		return
	if header.has_method("set_quiz_turn_banner"):
		header.set_quiz_turn_banner(text, col)
	elif is_instance_valid(header.get("lbl_turn_banner")):
		header.lbl_turn_banner.text = text
		header.lbl_turn_banner.add_theme_color_override("font_color", col)

func _set_header_local_answered(answered: bool) -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if is_instance_valid(header) and header.has_method("set_local_answered"):
		header.set_local_answered(answered)

func _set_header_round_label(turn_num: int, total: int) -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if not is_instance_valid(header):
		return
	if header.has_method("set_question_number"):
		header.set_question_number(turn_num, total)
	elif is_instance_valid(header.get("lbl_round")):
		header.lbl_round.text = "سوال %s از %s" % [_fa_digits(turn_num), _fa_digits(total)]

func _set_header_player_surrendered(gid: int) -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if is_instance_valid(header) and header.has_method("set_player_surrendered"):
		header.set_player_surrendered(gid)

func _set_header_player_answered(gid: int, answered: bool) -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if is_instance_valid(header) and header.has_method("set_player_answered"):
		header.set_player_answered(gid, answered)

func _clear_header_answered_states() -> void:
	var hud = _get_active_hud()
	if not is_instance_valid(hud):
		return
	var header = hud.get("current_top_header")
	if is_instance_valid(header) and header.has_method("clear_answered_states"):
		header.clear_answered_states()

func _get_active_hud() -> Node:
	var tree = get_tree()
	if not tree:
		return null
	var hud = tree.get_first_node_in_group("base_game_hud")
	if is_instance_valid(hud):
		return hud
	return tree.root.find_child("BaseGameHUD", true, false)

func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa_map = {"0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴", "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"}
	for k in fa_map.keys():
		s = s.replace(k, fa_map[k])
	return s

# --- Reconnection ---
func on_reconnect_data(payload: Dictionary) -> void:
	var src: Dictionary = payload
	var gd = payload.get("game_data", {})
	if typeof(gd) == TYPE_DICTIONARY and not gd.is_empty():
		src = gd

	my_player_index = GameManager.my_player_index
	if src.has("scores") and typeof(src["scores"]) == TYPE_DICTIONARY:
		player_scores = src["scores"]
		_sync_hud_scores()

	if src.has("current_question") and typeof(src["current_question"]) == TYPE_DICTIONARY:
		_handle_new_question_turn(src["current_question"], true)
	elif payload.has("current_question") and typeof(payload["current_question"]) == TYPE_DICTIONARY:
		_handle_new_question_turn(payload["current_question"], true)
	elif src.has("question") or src.has("turn"):
		_handle_new_question_turn(src, true)

	# Restore surrendered players list
	var surr_list = src.get("surrendered_players", [])
	if typeof(surr_list) == TYPE_ARRAY:
		for g_val in surr_list:
			var sgid = int(g_val)
			if sgid > 0:
				on_player_surrendered(sgid)

	# Restore players who already locked in their answer this question
	var ans_list = src.get("answered_players", [])
	if typeof(ans_list) == TYPE_ARRAY:
		for g_val in ans_list:
			var agid = int(g_val)
			if agid > 0:
				player_locked_in[agid] = true
				_update_crystal_light(agid, true)
				_set_pedestal_status(agid, "🔒 ثبت شد", Color(0.45, 0.95, 1.0))
				_set_header_player_answered(agid, true)

	var round_finished = bool(src.get("is_turn_round_finished", payload.get("is_turn_round_finished", false)))
	var my_opt = int(src.get("my_option", 0))

	# Restore reveal state if server is currently inside the 4s Finish_Turn_Round sleep window
	if round_finished:
		if my_opt >= 1 and my_opt <= 4:
			selected_option_idx = my_opt
			has_answered_this_turn = true
		var last_res = src.get("last_turn_results", {})
		if typeof(last_res) == TYPE_DICTIONARY and not last_res.is_empty():
			_apply_finish_turn_round(last_res, false)
	elif my_opt >= 1 and my_opt <= 4 and not has_answered_this_turn:
		# Restore local player's hidden locked choice if reconnecting mid-question
		has_answered_this_turn = true
		selected_option_idx = my_opt
		set_board_locked(true)
		player_locked_in[my_player_index] = true
		_style_keycaps_selected(my_opt)
		_spawn_local_lock_seal(my_opt)
		var letter = OPTION_LETTERS[clampi(my_opt - 1, 0, 3)]
		_lectern_status_text = "🔒 انتخاب شما («%s») ثبت شد — در انتظار سایر بازیکنان..." % letter
		_lectern_status_color = Color(0.55, 0.92, 1.0)
		_lectern_show_reveal_bar = false
		_refresh_lectern_labels()

	_rebuild_player_pedestals()
	_refresh_pedestals_text_and_lights()
	if has_answered_this_turn and not is_in_reveal_phase:
		_set_header_local_answered(true)

# --- Cleanup & Reset ---
func _create_tracked_tween() -> Tween:
	var tw = create_tween()
	_active_tweens.append(tw)
	return tw

func _kill_all_tweens() -> void:
	for tw in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()

func reset_board() -> void:
	_kill_all_tweens()
	_clear_answer_tokens()
	current_question_num = 1
	has_answered_this_turn = false
	is_in_reveal_phase = false
	selected_option_idx = 0
	player_scores = {1: 0, 2: 0, 3: 0, 4: 0}
	surrendered_players = {1: false, 2: false, 3: false, 4: false}
	for gid in player_locked_in.keys():
		player_locked_in[gid] = false
	_clear_header_answered_states()
	_rebuild_player_pedestals()
	_refresh_pedestals_text_and_lights()

func cleanup_board() -> void:
	_kill_all_tweens()
	_clear_answer_tokens()
	if is_instance_valid(stand_root):
		stand_root.queue_free()
