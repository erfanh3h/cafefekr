class_name BoxFour3D
extends "res://scripts/games/base_game_board.gd"

# BoxFour 3D Board (چهارطرفه — Cafe Fekr Royal Tournament Edition)
# Exact 1:1 port of Flutter BoxFourController + Python Backend BoxFourGameClass & BoxFourGameSession.
# Features:
# - Luxury 3D 5x5 Recessed Persian Walnut, Obsidian & 24K Brushed Gold Fortress Arena
# - 25 Tactile 3D Multi-Tiered Pedestal Cells that physically elevate & transform color by owner:
#   * Neutral (0): Carved Alabaster & Smoked Slate Pedestal
#   * Player 1 (1 - Red): Imperial Ruby Crimson Lacquer Fortress with 24K Gold Bevel
#   * Player 2 (2 - Blue): Royal Sapphire Cobalt Lacquer Fortress with Platinum-Gold Bevel
# - 3D Charge Orbs & Embossed Persian Numerals (۱، ۲، ۳):
#   * Charge 1: Central glowing crystal dome + single gold ring + embossed ۱
#   * Charge 2: Twin crystal domes + double gold rings + embossed ۲
#   * Charge 3 (Critical): Triple crystal domes + 4-way cardinal brass-gold blast arrows (▲ ▼ ◄ ►)
#     + pulsing energy core + embossed ۳
# - Spectacular 4-Way Chain-Reaction Explosion VFX (spread_number):
#   * OmniLight3D blast flash, expanding 3D shockwave ring, and 4 parabolic 3D energy orbs
#     flying simultaneously to N/S/E/W orthogonal neighbors with chained secondary explosions!

const GRID_SIZE: int = 5
const MAX_CELLS: int = 25

# 4 Orthogonal Chain-Reaction Directions: (dc, dr) matching MOVE_DIRS in backend & Flutter
const MOVE_DIRS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(1, 0)
]

# Compact 5x5 footprint that fits cleanly inside the CafeTable play surface without overflow
var cell_size: float = 0.212
var cell_gap: float = 0.018
var cell_pitch: float = 0.230
var grid_span: float = 1.150 # 5 * 0.230

# --- Authoritative State (Matches BoxFourController & BoxFourGameClass 1:1) ---
# index = c_index * 5 + r_index, where r_index = index % 5 (X/col), c_index = index / 5 (Z/row)
var cell_values: Array[int] = []
var cell_owners: Array[int] = []
var last_played_index: int = -1

var player1_score: int = 1
var player2_score: int = 1

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _pulse_time: float = 0.0

# --- 3D Nodes & Caches ---
var cells_root: Node3D = null
var fx_root: Node3D = null
var cell_areas: Array[Area3D] = []
var cell_Roots: Array[Node3D] = []
var cell_cap_nodes: Array[Node3D] = []
var cell_cap_meshes: Array[MeshInstance3D] = []
var cell_rim_meshes: Array[MeshInstance3D] = []
var cell_legal_frames: Array[Node3D] = []
var cell_last_frames: Array[Node3D] = []
var cell_token_roots: Array[Node3D] = []
var cell_critical_roots: Array[Node3D] = []

# --- Luxury Procedural Materials ---
var mat_walnut_base: StandardMaterial3D
var mat_ebony_well: StandardMaterial3D
var mat_gold_frame: StandardMaterial3D
var mat_brass_inlay: StandardMaterial3D

var mat_cap_neutral_light: StandardMaterial3D
var mat_cap_neutral_dark: StandardMaterial3D
var mat_rim_neutral: StandardMaterial3D

var mat_cap_p1: StandardMaterial3D
var mat_rim_p1: StandardMaterial3D
var mat_orb_p1: StandardMaterial3D
var mat_orb_p1_critical: StandardMaterial3D

var mat_cap_p2: StandardMaterial3D
var mat_rim_p2: StandardMaterial3D
var mat_orb_p2: StandardMaterial3D
var mat_orb_p2_critical: StandardMaterial3D

var mat_legal_glow: StandardMaterial3D
var mat_last_move_gold: StandardMaterial3D
var mat_arrow_gold: StandardMaterial3D

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")

static func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out

func _init() -> void:
	game_type = GameTypes.BOXFOUR

func _ready() -> void:
	game_type = GameTypes.BOXFOUR
	add_to_group("board")
	_init_materials()
	_build_board_3d()
	_init_board_state()
	_refresh_all_cells_visual(false)
	_sync_hud_scores()
	super._ready()

func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse_scale = 1.0 + 0.065 * sin(_pulse_time * 5.2)
	var arrow_bob = 0.004 * sin(_pulse_time * 6.5)
	for i in range(MAX_CELLS):
		if i < cell_critical_roots.size() and is_instance_valid(cell_critical_roots[i]):
			var c_root = cell_critical_roots[i]
			if c_root.visible:
				c_root.scale = Vector3(pulse_scale, 1.0, pulse_scale)
				c_root.position.y = arrow_bob
		if i < cell_legal_frames.size() and is_instance_valid(cell_legal_frames[i]):
			var l_frame = cell_legal_frames[i]
			if l_frame.visible:
				var l_s = 1.0 + 0.025 * sin(_pulse_time * 4.4 + float(i) * 0.35)
				l_frame.scale = Vector3(l_s, 1.0, l_s)

func _init_materials() -> void:
	# 1. Board Plinth & Frame Materials
	mat_walnut_base = StandardMaterial3D.new()
	mat_walnut_base.albedo_color = Color(0.20, 0.11, 0.06)
	mat_walnut_base.metallic = 0.08
	mat_walnut_base.roughness = 0.34
	mat_walnut_base.clearcoat_enabled = true
	mat_walnut_base.clearcoat = 0.55
	mat_walnut_base.clearcoat_roughness = 0.22

	mat_ebony_well = StandardMaterial3D.new()
	mat_ebony_well.albedo_color = Color(0.09, 0.07, 0.06)
	mat_ebony_well.metallic = 0.18
	mat_ebony_well.roughness = 0.42

	mat_gold_frame = StandardMaterial3D.new()
	mat_gold_frame.albedo_color = Color(0.94, 0.78, 0.28)
	mat_gold_frame.metallic = 0.90
	mat_gold_frame.roughness = 0.22

	mat_brass_inlay = StandardMaterial3D.new()
	mat_brass_inlay.albedo_color = Color(0.82, 0.64, 0.22)
	mat_brass_inlay.metallic = 0.85
	mat_brass_inlay.roughness = 0.28

	# 2. Neutral Pedestal Materials (Alternating Warm Alabaster & Smoked Slate)
	mat_cap_neutral_light = StandardMaterial3D.new()
	mat_cap_neutral_light.albedo_color = Color(0.42, 0.35, 0.27)
	mat_cap_neutral_light.metallic = 0.10
	mat_cap_neutral_light.roughness = 0.36
	mat_cap_neutral_light.clearcoat_enabled = true
	mat_cap_neutral_light.clearcoat = 0.40

	mat_cap_neutral_dark = StandardMaterial3D.new()
	mat_cap_neutral_dark.albedo_color = Color(0.30, 0.24, 0.19)
	mat_cap_neutral_dark.metallic = 0.12
	mat_cap_neutral_dark.roughness = 0.38
	mat_cap_neutral_dark.clearcoat_enabled = true
	mat_cap_neutral_dark.clearcoat = 0.40

	mat_rim_neutral = StandardMaterial3D.new()
	mat_rim_neutral.albedo_color = Color(0.55, 0.44, 0.28)
	mat_rim_neutral.metallic = 0.55
	mat_rim_neutral.roughness = 0.34

	# 3. Player 1 (Red — Imperial Ruby Crimson)
	mat_cap_p1 = StandardMaterial3D.new()
	mat_cap_p1.albedo_color = Color(0.78, 0.12, 0.16)
	mat_cap_p1.metallic = 0.22
	mat_cap_p1.roughness = 0.20
	mat_cap_p1.clearcoat_enabled = true
	mat_cap_p1.clearcoat = 0.92
	mat_cap_p1.clearcoat_roughness = 0.10
	mat_cap_p1.emission_enabled = true
	mat_cap_p1.emission = Color(0.45, 0.04, 0.06)
	mat_cap_p1.emission_energy_multiplier = 0.38

	mat_rim_p1 = StandardMaterial3D.new()
	mat_rim_p1.albedo_color = Color(0.98, 0.78, 0.26)
	mat_rim_p1.metallic = 0.92
	mat_rim_p1.roughness = 0.18

	mat_orb_p1 = StandardMaterial3D.new()
	mat_orb_p1.albedo_color = Color(1.0, 0.24, 0.28)
	mat_orb_p1.metallic = 0.30
	mat_orb_p1.roughness = 0.14
	mat_orb_p1.clearcoat_enabled = true
	mat_orb_p1.clearcoat = 0.95
	mat_orb_p1.emission_enabled = true
	mat_orb_p1.emission = Color(0.95, 0.18, 0.22)
	mat_orb_p1.emission_energy_multiplier = 0.75

	mat_orb_p1_critical = StandardMaterial3D.new()
	mat_orb_p1_critical.albedo_color = Color(1.0, 0.52, 0.22)
	mat_orb_p1_critical.metallic = 0.35
	mat_orb_p1_critical.roughness = 0.12
	mat_orb_p1_critical.emission_enabled = true
	mat_orb_p1_critical.emission = Color(1.0, 0.36, 0.12)
	mat_orb_p1_critical.emission_energy_multiplier = 1.35

	# 4. Player 2 (Blue — Royal Sapphire Cobalt)
	mat_cap_p2 = StandardMaterial3D.new()
	mat_cap_p2.albedo_color = Color(0.11, 0.38, 0.82)
	mat_cap_p2.metallic = 0.24
	mat_cap_p2.roughness = 0.20
	mat_cap_p2.clearcoat_enabled = true
	mat_cap_p2.clearcoat = 0.92
	mat_cap_p2.clearcoat_roughness = 0.10
	mat_cap_p2.emission_enabled = true
	mat_cap_p2.emission = Color(0.04, 0.18, 0.50)
	mat_cap_p2.emission_energy_multiplier = 0.40

	mat_rim_p2 = StandardMaterial3D.new()
	mat_rim_p2.albedo_color = Color(0.86, 0.92, 1.0)
	mat_rim_p2.metallic = 0.92
	mat_rim_p2.roughness = 0.18

	mat_orb_p2 = StandardMaterial3D.new()
	mat_orb_p2.albedo_color = Color(0.22, 0.62, 1.0)
	mat_orb_p2.metallic = 0.30
	mat_orb_p2.roughness = 0.14
	mat_orb_p2.clearcoat_enabled = true
	mat_orb_p2.clearcoat = 0.95
	mat_orb_p2.emission_enabled = true
	mat_orb_p2.emission = Color(0.15, 0.52, 1.0)
	mat_orb_p2.emission_energy_multiplier = 0.78

	mat_orb_p2_critical = StandardMaterial3D.new()
	mat_orb_p2_critical.albedo_color = Color(0.35, 0.88, 1.0)
	mat_orb_p2_critical.metallic = 0.35
	mat_orb_p2_critical.roughness = 0.12
	mat_orb_p2_critical.emission_enabled = true
	mat_orb_p2_critical.emission = Color(0.22, 0.82, 1.0)
	mat_orb_p2_critical.emission_energy_multiplier = 1.35

	# 5. Legal & Last-Played Highlights
	mat_legal_glow = StandardMaterial3D.new()
	mat_legal_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_legal_glow.albedo_color = Color(0.32, 1.0, 0.58, 0.88)
	mat_legal_glow.emission_enabled = true
	mat_legal_glow.emission = Color(0.25, 0.96, 0.52)
	mat_legal_glow.emission_energy_multiplier = 1.45

	mat_last_move_gold = StandardMaterial3D.new()
	mat_last_move_gold.albedo_color = Color(1.0, 0.86, 0.22)
	mat_last_move_gold.metallic = 0.85
	mat_last_move_gold.roughness = 0.16
	mat_last_move_gold.emission_enabled = true
	mat_last_move_gold.emission = Color(1.0, 0.78, 0.18)
	mat_last_move_gold.emission_energy_multiplier = 1.15

	mat_arrow_gold = StandardMaterial3D.new()
	mat_arrow_gold.albedo_color = Color(1.0, 0.88, 0.32)
	mat_arrow_gold.metallic = 0.92
	mat_arrow_gold.roughness = 0.16
	mat_arrow_gold.emission_enabled = true
	mat_arrow_gold.emission = Color(1.0, 0.76, 0.20)
	mat_arrow_gold.emission_energy_multiplier = 0.95

func _cell_pos(c_idx: int, r_idx: int) -> Vector3:
	var x = (float(r_idx) - 2.0) * cell_pitch
	var z = (float(c_idx) - 2.0) * cell_pitch
	return Vector3(x, 0.0, z)

func _build_board_3d() -> void:
	for ch in get_children():
		ch.queue_free()

	cell_areas.clear()
	cell_Roots.clear()
	cell_cap_nodes.clear()
	cell_cap_meshes.clear()
	cell_rim_meshes.clear()
	cell_legal_frames.clear()
	cell_last_frames.clear()
	cell_token_roots.clear()
	cell_critical_roots.clear()

	var board_root = Node3D.new()
	board_root.name = "BoardStructure"
	add_child(board_root)

	# 1. Outer Tiered Royal Walnut Plinth (1.28 x 1.28)
	var outer_plinth = MeshInstance3D.new()
	var outer_box = BoxMesh.new()
	outer_box.size = Vector3(1.28, 0.036, 1.28)
	outer_plinth.mesh = outer_box
	outer_plinth.material_override = mat_walnut_base
	outer_plinth.position = Vector3(0.0, 0.018, 0.0)
	board_root.add_child(outer_plinth)

	# 2. Recessed Obsidian Well Floor
	var well_floor = MeshInstance3D.new()
	var well_box = BoxMesh.new()
	well_box.size = Vector3(1.18, 0.038, 1.18)
	well_floor.mesh = well_box
	well_floor.material_override = mat_ebony_well
	well_floor.position = Vector3(0.0, 0.020, 0.0)
	board_root.add_child(well_floor)

	# 3. Raised 24K Gold Perimeter Frame & 4 Raised Walnut Rim Walls
	var wall_len = 1.26
	var wall_thick = 0.042
	var wall_h = 0.052
	var wall_offset = 0.61
	var wall_configs = [
		Vector3(0.0, wall_h * 0.5, -wall_offset),
		Vector3(0.0, wall_h * 0.5, wall_offset),
		Vector3(-wall_offset, wall_h * 0.5, 0.0),
		Vector3(wall_offset, wall_h * 0.5, 0.0)
	]
	for w_i in range(4):
		var w_mesh = MeshInstance3D.new()
		var w_box = BoxMesh.new()
		if w_i < 2:
			w_box.size = Vector3(wall_len, wall_h, wall_thick)
		else:
			w_box.size = Vector3(wall_thick, wall_h, wall_len)
		w_mesh.mesh = w_box
		w_mesh.material_override = mat_walnut_base
		w_mesh.position = wall_configs[w_i]
		board_root.add_child(w_mesh)

		var trim_mesh = MeshInstance3D.new()
		var trim_box = BoxMesh.new()
		if w_i < 2:
			trim_box.size = Vector3(wall_len - 0.04, 0.008, 0.012)
		else:
			trim_box.size = Vector3(0.012, 0.008, wall_len - 0.04)
		trim_mesh.mesh = trim_box
		trim_mesh.material_override = mat_gold_frame
		trim_mesh.position = wall_configs[w_i] + Vector3(0.0, wall_h * 0.5 + 0.004, 0.0)
		board_root.add_child(trim_mesh)

	# 4. Four Corner Octagonal Brass Turrets with Ruby/Sapphire Finials
	for cx in [-0.61, 0.61]:
		for cz in [-0.61, 0.61]:
			var turret = MeshInstance3D.new()
			var t_cyl = CylinderMesh.new()
			t_cyl.top_radius = 0.036
			t_cyl.bottom_radius = 0.042
			t_cyl.height = 0.062
			t_cyl.radial_segments = 8
			turret.mesh = t_cyl
			turret.material_override = mat_gold_frame
			turret.position = Vector3(cx, 0.031, cz)
			board_root.add_child(turret)

			var gem = MeshInstance3D.new()
			var g_sph = SphereMesh.new()
			g_sph.radius = 0.018
			g_sph.height = 0.024
			gem.mesh = g_sph
			gem.material_override = mat_orb_p1 if (cx * cz < 0.0) else mat_orb_p2
			gem.position = Vector3(cx, 0.064, cz)
			board_root.add_child(gem)

	# 5. Inter-Cell Brass Conduit Channels (Visualizing the 4-Way Grid Links)
	for i in range(4):
		var offset = (float(i) - 1.5) * cell_pitch
		var h_line = MeshInstance3D.new()
		var h_box = BoxMesh.new()
		h_box.size = Vector3(grid_span - 0.04, 0.004, 0.006)
		h_line.mesh = h_box
		h_line.material_override = mat_brass_inlay
		h_line.position = Vector3(0.0, 0.040, offset)
		board_root.add_child(h_line)

		var v_line = MeshInstance3D.new()
		var v_box = BoxMesh.new()
		v_box.size = Vector3(0.006, 0.004, grid_span - 0.04)
		v_line.mesh = v_box
		v_line.material_override = mat_brass_inlay
		v_line.position = Vector3(offset, 0.040, 0.0)
		board_root.add_child(v_line)

	# 6. Build the 25 3D Pedestal Cells (5x5)
	cells_root = Node3D.new()
	cells_root.name = "CellsRoot"
	add_child(cells_root)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	add_child(fx_root)

	for idx in range(MAX_CELLS):
		var r_idx = idx % GRID_SIZE
		var c_idx = int(idx / GRID_SIZE)
		var pos = _cell_pos(c_idx, r_idx)

		var c_node = Node3D.new()
		c_node.name = "Cell_%d" % idx
		c_node.position = pos
		cells_root.add_child(c_node)
		cell_Roots.append(c_node)

		# Pedestal Lower Plinth
		var base_plinth = MeshInstance3D.new()
		var bp_box = BoxMesh.new()
		bp_box.size = Vector3(cell_size, 0.018, cell_size)
		base_plinth.mesh = bp_box
		base_plinth.material_override = mat_rim_neutral
		base_plinth.position = Vector3(0.0, 0.046, 0.0)
		c_node.add_child(base_plinth)
		cell_rim_meshes.append(base_plinth)

		# Animatable Upper Cap Node
		var cap_node = Node3D.new()
		cap_node.name = "CapNode"
		cap_node.position = Vector3(0.0, 0.062, 0.0)
		c_node.add_child(cap_node)
		cell_cap_nodes.append(cap_node)

		var cap_mesh = MeshInstance3D.new()
		var cm_box = BoxMesh.new()
		cm_box.size = Vector3(cell_size - 0.016, 0.022, cell_size - 0.016)
		cap_mesh.mesh = cm_box
		cap_mesh.material_override = mat_cap_neutral_light if ((r_idx + c_idx) % 2 == 0) else mat_cap_neutral_dark
		cap_node.add_child(cap_mesh)
		cell_cap_meshes.append(cap_mesh)

		# Recessed Inner Sanctum Ring on every tile
		var inner_ring = MeshInstance3D.new()
		var ir_torus = TorusMesh.new()
		ir_torus.inner_radius = 0.064
		ir_torus.outer_radius = 0.072
		ir_torus.rings = 24
		ir_torus.ring_segments = 12
		inner_ring.mesh = ir_torus
		inner_ring.material_override = mat_brass_inlay
		inner_ring.position = Vector3(0.0, 0.012, 0.0)
		cap_node.add_child(inner_ring)

		# Legal Move Selection Frame (Hollow 4-bar glowing emerald-gold frame)
		var legal_frame = _create_hollow_frame(cell_size - 0.008, 0.010, 0.008, mat_legal_glow)
		legal_frame.position = Vector3(0.0, 0.014, 0.0)
		legal_frame.visible = false
		cap_node.add_child(legal_frame)
		cell_legal_frames.append(legal_frame)

		# Last-Played Move Frame (Hollow 4-bar glowing 24K gold frame)
		var last_frame = _create_hollow_frame(cell_size + 0.004, 0.009, 0.010, mat_last_move_gold)
		last_frame.position = Vector3(0.0, 0.016, 0.0)
		last_frame.visible = false
		cap_node.add_child(last_frame)
		cell_last_frames.append(last_frame)

		# Token Root (Holds 3D Charge Orbs + 3D Numeral + Critical 4-Way Arrows)
		var token_root = Node3D.new()
		token_root.name = "TokenRoot"
		token_root.position = Vector3(0.0, 0.014, 0.0)
		cap_node.add_child(token_root)
		cell_token_roots.append(token_root)

		var crit_root = Node3D.new()
		crit_root.name = "CriticalRoot"
		crit_root.visible = false
		token_root.add_child(crit_root)
		cell_critical_roots.append(crit_root)

		# Physics Area3D for Click / Touch Input
		var area = Area3D.new()
		area.name = "Area_%d" % idx
		area.position = Vector3(0.0, 0.065, 0.0)
		var col = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(cell_size, 0.06, cell_size)
		col.shape = box_shape
		area.add_child(col)
		var bound_idx = idx
		area.input_event.connect(func(_cam, event, _pos, _normal, _shape_idx):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_cell_clicked(bound_idx)
			elif event is InputEventScreenTouch and event.pressed:
				_on_cell_clicked(bound_idx)
		)
		c_node.add_child(area)
		cell_areas.append(area)

func _create_hollow_frame(outer_span: float, bar_thickness: float, bar_height: float, mat: Material) -> Node3D:
	var root_mi = Node3D.new()
	var half = outer_span * 0.5 - bar_thickness * 0.5
	var configs = [
		[Vector3(outer_span, bar_height, bar_thickness), Vector3(0, 0, -half)],
		[Vector3(outer_span, bar_height, bar_thickness), Vector3(0, 0, half)],
		[Vector3(bar_thickness, bar_height, outer_span - bar_thickness * 2.0), Vector3(-half, 0, 0)],
		[Vector3(bar_thickness, bar_height, outer_span - bar_thickness * 2.0), Vector3(half, 0, 0)]
	]
	for cfg in configs:
		var bar = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = cfg[0]
		bar.mesh = bm
		bar.material_override = mat
		bar.position = cfg[1]
		root_mi.add_child(bar)
	return root_mi

func _unhandled_input(event: InputEvent) -> void:
	var is_press: bool = false
	var screen_pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_press = true
		screen_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
		screen_pos = event.position

	if not is_press:
		return

	var vp = get_viewport()
	if not vp:
		return
	var cam = vp.get_camera_3d()
	if not cam:
		return

	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_dir = cam.project_ray_normal(screen_pos)
	var board_plane = Plane(Vector3.UP, global_position.y + 0.068)
	var hit = board_plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return

	var local_hit = to_local(hit)
	var r_f = (local_hit.x / cell_pitch) + 2.5
	var c_f = (local_hit.z / cell_pitch) + 2.5
	if r_f >= 0.0 and r_f < float(GRID_SIZE) and c_f >= 0.0 and c_f < float(GRID_SIZE):
		var r_idx = clampi(int(floor(r_f)), 0, GRID_SIZE - 1)
		var c_idx = clampi(int(floor(c_f)), 0, GRID_SIZE - 1)
		var idx = c_idx * GRID_SIZE + r_idx
		_on_cell_clicked(idx)

# --- Authoritative State & Rules (1:1 with BoxFourGameClass & BoxFourController) ---

func _init_board_state() -> void:
	cell_values.resize(MAX_CELLS)
	cell_owners.resize(MAX_CELLS)
	for i in range(MAX_CELLS):
		cell_values[i] = 0
		cell_owners[i] = 0
	# Matches BoxFourGameClass.init_board() & BoxFourController.initPieces():
	# board[2][1] -> index 11 = (owner 1, value 3)
	# board[2][3] -> index 13 = (owner 2, value 3)
	cell_owners[11] = 1
	cell_values[11] = 3
	cell_owners[13] = 2
	cell_values[13] = 3
	last_played_index = -1
	player1_score = 1
	player2_score = 1

func _is_valid_coord(c_idx: int, r_idx: int) -> bool:
	return c_idx >= 0 and c_idx < GRID_SIZE and r_idx >= 0 and r_idx < GRID_SIZE

func _get_player_score(gamer_id: int) -> int:
	var count: int = 0
	for i in range(MAX_CELLS):
		if cell_owners[i] == gamer_id:
			count += 1
	return count

func _sync_hud_scores() -> void:
	player1_score = _get_player_score(1)
	player2_score = _get_player_score(2)
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var main_node = get_tree().current_scene
	if main_node and main_node.get("base_game_hud") and is_instance_valid(main_node.base_game_hud):
		main_node.base_game_hud.update_scores(player1_score, player2_score)

# --- Visual Rendering of 3D Pedestals, Charge Orbs, Numerals & 4-Way Arrows ---

func _refresh_all_cells_visual(animate: bool = false) -> void:
	for idx in range(MAX_CELLS):
		_update_single_cell_visual(idx, animate)
	_refresh_highlights()

func _refresh_highlights() -> void:
	var show_legal = GameManager.is_game_active and is_my_turn and not is_board_locked
	var my_id = GameManager.my_player_index
	for idx in range(MAX_CELLS):
		if idx < cell_legal_frames.size() and is_instance_valid(cell_legal_frames[idx]):
			cell_legal_frames[idx].visible = show_legal and (cell_owners[idx] == my_id)
		if idx < cell_last_frames.size() and is_instance_valid(cell_last_frames[idx]):
			cell_last_frames[idx].visible = (idx == last_played_index)

func _update_single_cell_visual(idx: int, animate: bool = false) -> void:
	if idx < 0 or idx >= MAX_CELLS or idx >= cell_cap_meshes.size():
		return

	var owner_id = cell_owners[idx]
	var val = cell_values[idx]
	var r_idx = idx % GRID_SIZE
	var c_idx = int(idx / GRID_SIZE)

	var cap_node = cell_cap_nodes[idx]
	var cap_mesh = cell_cap_meshes[idx]
	var rim_mesh = cell_rim_meshes[idx]
	var token_root = cell_token_roots[idx]

	# Clear previous dynamic children inside token_root except CriticalRoot
	var crit_root = cell_critical_roots[idx]
	crit_root.visible = false
	for ch in crit_root.get_children():
		crit_root.remove_child(ch)
		ch.queue_free()
	for ch in token_root.get_children():
		if ch != crit_root:
			token_root.remove_child(ch)
			ch.queue_free()

	var target_y: float = 0.062
	if owner_id == 1:
		cap_mesh.material_override = mat_cap_p1
		rim_mesh.material_override = mat_rim_p1
		target_y = 0.068 + float(val) * 0.004
	elif owner_id == 2:
		cap_mesh.material_override = mat_cap_p2
		rim_mesh.material_override = mat_rim_p2
		target_y = 0.068 + float(val) * 0.004
	else:
		cap_mesh.material_override = mat_cap_neutral_light if ((r_idx + c_idx) % 2 == 0) else mat_cap_neutral_dark
		rim_mesh.material_override = mat_rim_neutral
		target_y = 0.060

	if animate and is_inside_tree():
		var tw = cap_node.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cap_node, "position:y", target_y + 0.018, 0.11)
		tw.tween_property(cap_node, "position:y", target_y, 0.16)
	else:
		cap_node.position.y = target_y

	if val <= 0 or owner_id == 0:
		return

	var orb_mat = mat_orb_p1 if owner_id == 1 else mat_orb_p2
	var crit_mat = mat_orb_p1_critical if owner_id == 1 else mat_orb_p2_critical
	var ring_mat = mat_rim_p1 if owner_id == 1 else mat_rim_p2

	# 1. Sculpted 3D Fortress Token Base Pedestal
	var fort_base = MeshInstance3D.new()
	var fb_cyl = CylinderMesh.new()
	fb_cyl.top_radius = 0.064
	fb_cyl.bottom_radius = 0.072
	fb_cyl.height = 0.014 + float(val) * 0.004
	fb_cyl.radial_segments = 24
	fort_base.mesh = fb_cyl
	fort_base.material_override = ring_mat
	fort_base.position = Vector3(0.0, fb_cyl.height * 0.5, 0.0)
	token_root.add_child(fort_base)

	var inner_core = MeshInstance3D.new()
	var ic_cyl = CylinderMesh.new()
	ic_cyl.top_radius = 0.056
	ic_cyl.bottom_radius = 0.060
	ic_cyl.height = fb_cyl.height + 0.004
	ic_cyl.radial_segments = 24
	inner_core.mesh = ic_cyl
	inner_core.material_override = mat_cap_p1 if owner_id == 1 else mat_cap_p2
	inner_core.position = Vector3(0.0, ic_cyl.height * 0.5, 0.0)
	token_root.add_child(inner_core)

	# 2. 3D Charge Pip Orbs around the Rim (1, 2, or 3 Crystal Domes)
	var pip_offsets: Array[Vector3] = []
	if val == 1:
		pip_offsets = [Vector3(0.0, 0.0, -0.056)]
	elif val == 2:
		pip_offsets = [Vector3(-0.052, 0.0, -0.042), Vector3(0.052, 0.0, -0.042)]
	else:
		pip_offsets = [
			Vector3(0.0, 0.0, -0.060),
			Vector3(-0.054, 0.0, 0.036),
			Vector3(0.054, 0.0, 0.036)
		]

	for p_off in pip_offsets:
		var pip_mi = MeshInstance3D.new()
		var p_sph = SphereMesh.new()
		p_sph.radius = 0.015 if val < 3 else 0.017
		p_sph.height = p_sph.radius * 2.0
		pip_mi.mesh = p_sph
		pip_mi.material_override = crit_mat if val >= 3 else orb_mat
		pip_mi.position = p_off + Vector3(0.0, ic_cyl.height + 0.006, 0.0)
		token_root.add_child(pip_mi)

	# 3. High-Contrast 3D Embossed Persian Numeral (۱ / ۲ / ۳)
	var num_lbl = Label3D.new()
	num_lbl.font = _font_hekayat
	num_lbl.text = _fa_digits(val)
	num_lbl.font_size = 54 if val < 3 else 60
	num_lbl.pixel_size = 0.0019
	num_lbl.modulate = Color(1.0, 0.98, 0.90) if val < 3 else Color(1.0, 0.94, 0.52)
	num_lbl.outline_modulate = Color(0.18, 0.04, 0.04) if owner_id == 1 else Color(0.03, 0.08, 0.24)
	num_lbl.outline_size = 16
	num_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	num_lbl.position = Vector3(0.0, ic_cyl.height + 0.008, 0.006)
	token_root.add_child(num_lbl)

	# 4. Critical Charge = 3 -> 4-Way Cardinal Blast Arrows (▲ ▼ ◄ ►)
	if val >= 3:
		crit_root.visible = true
		var arrow_dirs = [
			[Vector3(0.0, 0.012, -0.082), Vector3(0.0, 0.0, 0.0)],
			[Vector3(0.0, 0.012, 0.082), Vector3(0.0, 180.0, 0.0)],
			[Vector3(-0.082, 0.012, 0.0), Vector3(0.0, 90.0, 0.0)],
			[Vector3(0.082, 0.012, 0.0), Vector3(0.0, -90.0, 0.0)]
		]
		for a_cfg in arrow_dirs:
			var arr = MeshInstance3D.new()
			var prism = PrismMesh.new()
			prism.size = Vector3(0.026, 0.022, 0.008)
			arr.mesh = prism
			arr.material_override = mat_arrow_gold
			arr.position = a_cfg[0]
			arr.rotation_degrees = Vector3(-90.0, a_cfg[1].y, 0.0)
			crit_root.add_child(arr)

	if animate and is_inside_tree():
		token_root.scale = Vector3(0.25, 0.25, 0.25)
		var tw_t = token_root.create_tween()
		tw_t.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw_t.tween_property(token_root, "scale", Vector3.ONE, 0.38)

# --- Move Execution & Chain-Reaction Explosion Logic ---

func _on_cell_clicked(idx: int) -> void:
	if idx < 0 or idx >= MAX_CELLS:
		return

	var frame_now = Engine.get_process_frames()
	var time_now = Time.get_ticks_msec() / 1000.0
	if frame_now == _last_click_frame or (time_now - last_click_time) < 0.18:
		return
	_last_click_frame = frame_now
	last_click_time = time_now

	if not GameManager.is_game_active:
		return

	if not is_my_turn or is_board_locked:
		AudioManager.play_sound("tap_wrong")
		show_hint("⏳ اکنون نوبت حرکت حریف است!")
		return

	var my_id = GameManager.my_player_index
	if cell_owners[idx] != my_id:
		AudioManager.play_sound("tap_wrong")
		_play_invalid_cell_shake(idx)
		if cell_owners[idx] == 0:
			show_hint("⚠️ فقط خانه‌های هم‌رنگ خودتان را می‌توانید تقویت کنید!")
		else:
			show_hint("⚠️ این خانه متعلق به حریف است! روی خانه‌های رنگ خودتان ضربه بزنید.")
		return

	# Valid move! Lock board for this turn and send Select_Peace
	is_board_locked = true
	_refresh_highlights()

	var r_index = idx % GRID_SIZE
	var c_index = int(idx / GRID_SIZE)
	send_move(Commands.Select_Peace, {"c_index": c_index, "r_index": r_index})

func _play_invalid_cell_shake(idx: int) -> void:
	if idx < 0 or idx >= cell_cap_nodes.size() or not is_inside_tree():
		return
	var cap = cell_cap_nodes[idx]
	var tw = cap.create_tween()
	tw.tween_property(cap, "position:x", 0.012, 0.04)
	tw.tween_property(cap, "position:x", -0.012, 0.04)
	tw.tween_property(cap, "position:x", 0.008, 0.04)
	tw.tween_property(cap, "position:x", 0.0, 0.04)

# Authoritative spread_number & submit_piece_for_user matching BoxFourGameClass 1:1,
# while recording explosion events by recursion depth for choreographed 3D VFX!
func _submit_piece_for_user(c_idx: int, r_idx: int, gamer_id: int) -> void:
	var idx = c_idx * GRID_SIZE + r_idx
	if idx < 0 or idx >= MAX_CELLS:
		return

	last_played_index = idx
	var explosion_events: Array[Dictionary] = []

	if cell_values[idx] < 3:
		cell_values[idx] += 1
		cell_owners[idx] = gamer_id
		AudioManager.play_sound("add_peace")
		_spawn_charge_ring_vfx(_cell_pos(c_idx, r_idx), gamer_id)
		_update_single_cell_visual(idx, true)
		_refresh_highlights()
		_sync_hud_scores()
		return

	# Value reached 4 -> Trigger 4-Way Chain Reaction!
	_spread_number_recursive(c_idx, r_idx, gamer_id, 0, explosion_events)
	_refresh_all_cells_visual(true)
	_sync_hud_scores()
	_play_chain_reaction_vfx(explosion_events, gamer_id)

func _spread_number_recursive(c_idx: int, r_idx: int, gamer_id: int, depth: int, events: Array[Dictionary]) -> void:
	var center_idx = c_idx * GRID_SIZE + r_idx
	cell_values[center_idx] = 0
	cell_owners[center_idx] = 0

	var targets: Array[Vector2i] = []
	for d in MOVE_DIRS:
		var ny = c_idx + d.x
		var nx = r_idx + d.y
		if _is_valid_coord(ny, nx):
			targets.append(Vector2i(ny, nx))

	events.append({
		"c": c_idx,
		"r": r_idx,
		"depth": depth,
		"targets": targets
	})

	for d in MOVE_DIRS:
		var ny = c_idx + d.x
		var nx = r_idx + d.y
		if _is_valid_coord(ny, nx):
			var n_idx = ny * GRID_SIZE + nx
			var cur_val = cell_values[n_idx]
			if cur_val < 3:
				cell_values[n_idx] = cur_val + 1
				cell_owners[n_idx] = gamer_id
			else:
				_spread_number_recursive(ny, nx, gamer_id, depth + 1, events)

func _spawn_charge_ring_vfx(world_pos: Vector3, gamer_id: int) -> void:
	if not is_inside_tree() or not is_instance_valid(fx_root):
		return
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.045
	torus.outer_radius = 0.058
	ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.32, 0.28, 0.90) if gamer_id == 1 else Color(0.28, 0.68, 1.0, 0.90)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.20) if gamer_id == 1 else Color(0.20, 0.58, 1.0)
	mat.emission_energy_multiplier = 1.6
	ring.material_override = mat
	ring.position = world_pos + Vector3(0.0, 0.085, 0.0)
	ring.scale = Vector3(0.5, 1.0, 0.5)
	fx_root.add_child(ring)

	var tw = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.55, 1.0, 1.55), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "position:y", world_pos.y + 0.135, 0.32)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.chain().tween_callback(ring.queue_free)

func _play_chain_reaction_vfx(events: Array[Dictionary], gamer_id: int) -> void:
	if not is_inside_tree() or not is_instance_valid(fx_root):
		return

	AudioManager.play_sound("correct")
	if events.size() > 1:
		AudioManager.play_sound("explode")

	for ev in events:
		var depth: int = int(ev.get("depth", 0))
		var c_idx: int = int(ev.get("c", 0))
		var r_idx: int = int(ev.get("r", 0))
		var targets: Array = ev.get("targets", [])
		var delay: float = float(depth) * 0.13

		if delay <= 0.001:
			_spawn_four_way_burst_vfx(c_idx, r_idx, targets, gamer_id)
		else:
			get_tree().create_timer(delay).timeout.connect(func():
				if is_inside_tree() and is_instance_valid(fx_root):
					AudioManager.play_sound("correct")
					_spawn_four_way_burst_vfx(c_idx, r_idx, targets, gamer_id)
			)

func _spawn_four_way_burst_vfx(c_idx: int, r_idx: int, targets: Array, gamer_id: int) -> void:
	if not is_inside_tree() or not is_instance_valid(fx_root):
		return

	var origin = _cell_pos(c_idx, r_idx) + Vector3(0.0, 0.095, 0.0)
	var burst_col = Color(1.0, 0.30, 0.22) if gamer_id == 1 else Color(0.24, 0.68, 1.0)

	# 1. Dynamic OmniLight3D Flash at Exploding Cell
	var light = OmniLight3D.new()
	light.light_color = burst_col
	light.light_energy = 4.2
	light.omni_range = 0.65
	light.position = origin + Vector3(0.0, 0.08, 0.0)
	fx_root.add_child(light)
	var tw_l = light.create_tween()
	tw_l.tween_property(light, "light_energy", 0.0, 0.34)
	tw_l.chain().tween_callback(light.queue_free)

	# 2. Expanding 3D Shockwave Torus Ring
	var wave = MeshInstance3D.new()
	var w_torus = TorusMesh.new()
	w_torus.inner_radius = 0.055
	w_torus.outer_radius = 0.075
	wave.mesh = w_torus
	var w_mat = StandardMaterial3D.new()
	w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w_mat.albedo_color = Color(burst_col.r, burst_col.g, burst_col.b, 0.95)
	w_mat.emission_enabled = true
	w_mat.emission = burst_col
	w_mat.emission_energy_multiplier = 2.2
	wave.material_override = w_mat
	wave.position = origin
	wave.scale = Vector3(0.4, 1.0, 0.4)
	fx_root.add_child(wave)

	var tw_w = wave.create_tween()
	tw_w.set_parallel(true)
	tw_w.tween_property(wave, "scale", Vector3(2.8, 1.0, 2.8), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_w.tween_property(w_mat, "albedo_color:a", 0.0, 0.32)
	tw_w.chain().tween_callback(wave.queue_free)

	# 3. Launch 4 Parabolic 3D Energy Orbs into Orthogonal Neighbors
	for t_coord in targets:
		var tc: int = t_coord.x
		var tr: int = t_coord.y
		var dest = _cell_pos(tc, tr) + Vector3(0.0, 0.095, 0.0)

		var orb = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.024
		sph.height = 0.048
		orb.mesh = sph
		orb.material_override = mat_orb_p1_critical if gamer_id == 1 else mat_orb_p2_critical
		orb.position = origin
		fx_root.add_child(orb)

		var mid = (origin + dest) * 0.5 + Vector3(0.0, 0.11, 0.0)
		var tw_o = orb.create_tween()
		tw_o.tween_property(orb, "position", mid, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_o.tween_property(orb, "position", dest, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_o.tween_callback(func():
			_spawn_charge_ring_vfx(Vector3(dest.x, 0.0, dest.z), gamer_id)
			orb.queue_free()
		)

# --- BaseGameBoard Network Hooks ---

func setup_board(_payload: Dictionary) -> void:
	_init_board_state()
	_refresh_all_cells_visual(false)
	_sync_hud_scores()

func reset_board() -> void:
	_init_board_state()
	_refresh_all_cells_visual(false)
	_sync_hud_scores()

func on_start_game() -> void:
	_refresh_highlights()
	_sync_hud_scores()

func on_turn_changed(turn: int, active_turn: bool) -> void:
	current_turn = turn
	is_my_turn = active_turn
	is_board_locked = not active_turn
	_refresh_highlights()

func on_piece_selected(user_id: int, target_index: int, extra: Dictionary = {}) -> void:
	var gamer_id = int(extra.get("gamer_id", user_id))
	var c_idx: int = -1
	var r_idx: int = -1
	if extra.has("c_index") and extra.has("r_index"):
		c_idx = int(extra["c_index"])
		r_idx = int(extra["r_index"])
	else:
		c_idx = int(target_index / GRID_SIZE)
		r_idx = target_index % GRID_SIZE

	if not _is_valid_coord(c_idx, r_idx):
		return

	_submit_piece_for_user(c_idx, r_idx, gamer_id)

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var arr: Array = board_data
	if arr.size() < MAX_CELLS:
		return

	for i in range(MAX_CELLS):
		var item = arr[i]
		if typeof(item) == TYPE_DICTIONARY:
			cell_values[i] = int(item.get("value", 0))
			cell_owners[i] = int(item.get("equipped_user", item.get("selected_user", 0)))
	_refresh_all_cells_visual(false)
	_sync_hud_scores()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
			sync_board_state(g_data["board"])
		if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
			player1_score = int(g_data["scores"][0])
			player2_score = int(g_data["scores"][1])
			GameManager.p1_score = player1_score
			GameManager.p2_score = player2_score
		if g_data.has("current_turn"):
			current_turn = int(g_data["current_turn"])
			is_my_turn = (current_turn == GameManager.my_player_index)
			is_board_locked = not is_my_turn
	_refresh_highlights()
	_sync_hud_scores()
