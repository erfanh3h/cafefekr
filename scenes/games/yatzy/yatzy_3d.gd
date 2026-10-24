class_name Yatzy3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# Yatzy (پنج تاس / یاتزی) 3D Board Implementation
# Cafe Fekr - Royal Mahogany & Obsidian Scorecard + Emerald-Baize 3D Dice Arena
#
# Strict Port of Flutter YatzyController & Backend YatzyGameClass:
# - 12 Scorecard Categories (0..5: Simple Dice 1..6 | 6..11: 3x, 4x, Chance, Full House, Straight, Yatzy)
# - 5 Physical 3D Dice rolled by server on CurrentTurn (rolled_dice_time = 1 -> 2 re-rolls left)
# - Tapping a die toggles Hold/Lock (selected_indexes kept on server during RollDice)
# - Tapping an unselected category equips it (previewing live calculated score)
# - Clicking "🎲 تاس بریز" sends Commands.Roll_Dice {"selected_indexes": [...]}
# - Clicking "✅ ثبت امتیاز" sends Commands.Select_Peace {"index": equipped_index}
# ==============================================================================

@export var camera_distance: float = 3.22
@export var camera_pitch: float = -1.10

const BOARD_W: float = 1.24
const BOARD_L: float = 1.26
const BOARD_H: float = 0.034

const NUM_CATEGORIES: int = 12
const NUM_DICE: int = 5

const FA_DIGITS = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const CATEGORY_NAMES_FA: Array[String] = [
	"تاس ۱",
	"تاس ۲",
	"تاس ۳",
	"تاس ۴",
	"تاس ۵",
	"تاس ۶",
	"۳ تایی",
	"۴ تایی",
	"هر ترکیب",
	"فول هاوس",
	"ردیف بزرگ",
	"یاتزی",
]

const CATEGORY_GUIDES_FA: Array[String] = [
	"تاس ۱: مجموع تاس‌هایی که عدد ۱ را نشان می‌دهند",
	"تاس ۲: مجموع تاس‌هایی که عدد ۲ را نشان می‌دهند",
	"تاس ۳: مجموع تاس‌هایی که عدد ۳ را نشان می‌دهند",
	"تاس ۴: مجموع تاس‌هایی که عدد ۴ را نشان می‌دهند",
	"تاس ۵: مجموع تاس‌هایی که عدد ۵ را نشان می‌دهند",
	"تاس ۶: مجموع تاس‌هایی که عدد ۶ را نشان می‌دهند",
	"۳ تایی: حداقل ۳ تاس هم‌عدد (امتیاز = مجموع هر ۵ تاس)",
	"۴ تایی: حداقل ۴ تاس هم‌عدد (امتیاز = مجموع هر ۵ تاس)",
	"هر ترکیب (شانس): مجموع تمام ۵ تاس بدون شرط",
	"فول هاوس: ۳ تاس از یک عدد + ۲ تاس از عدد دیگر (۲۵ امتیاز)",
	"ردیف بزرگ: ۵ عدد متوالی ۱ تا ۵ یا ۲ تا ۶ (۴۰ امتیاز)",
	"یاتزی: هر ۵ تاس کاملاً هم‌عدد (۵۰ امتیاز)",
]

const CATEGORY_ICON_PATHS: Array[String] = [
	"res://assets/icons/General/dice1.png",
	"res://assets/icons/General/dice2.png",
	"res://assets/icons/General/dice3.png",
	"res://assets/icons/General/dice4.png",
	"res://assets/icons/General/dice5.png",
	"res://assets/icons/General/dice6.png",
	"res://assets/icons/General/yatzy3.png",
	"res://assets/icons/General/yatzy4.png",
	"res://assets/icons/General/yatzyq.png",
	"res://assets/icons/General/yatzy23.png",
	"res://assets/icons/General/yatzy15.png",
	"res://assets/icons/General/yatzy5.png",
]

# --- Game State ---
var p1_board: Array[Dictionary] = [] # [{is_selected: bool, score: int, calc: int, last_played: bool}]
var p2_board: Array[Dictionary] = []
var current_dices: Array[int] = [1, 2, 3, 4, 5]
var held_dice_indices: Array[int] = []
var equipped_index: int = 0
var remaining_rolls: int = 2
var is_round_played: bool = false
var is_rolling_dice: bool = false
var _last_interaction_time: float = -10.0

# --- 3D Nodes ---
var _game_font: Font = null
var _cat_row_nodes: Array[Dictionary] = []
var _dice_nodes: Array[Dictionary] = []
var _btn_roll_node: Dictionary = {}
var _btn_submit_node: Dictionary = {}
var _status_lbl_3d: Label3D = null
var _col_header_labels: Array[Label3D] = []

# --- Materials ---
var mat_wood_base: StandardMaterial3D
var mat_wood_rim: StandardMaterial3D
var mat_obsidian_bed: StandardMaterial3D
var mat_felt_tray: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_row_even: StandardMaterial3D
var mat_row_odd: StandardMaterial3D
var mat_cat_badge: StandardMaterial3D

var mat_cell_idle_my: StandardMaterial3D
var mat_cell_idle_opp: StandardMaterial3D
var mat_cell_equipped: StandardMaterial3D
var mat_cell_p1_locked: StandardMaterial3D
var mat_cell_p2_locked: StandardMaterial3D
var mat_last_played_ring: StandardMaterial3D

var mat_die_ivory: StandardMaterial3D
var mat_die_held_ivory: StandardMaterial3D
var mat_pip_dark: StandardMaterial3D
var mat_pip_red: StandardMaterial3D
var mat_die_lock_ring: StandardMaterial3D

var mat_btn_roll_active: StandardMaterial3D
var mat_btn_roll_disabled: StandardMaterial3D
var mat_btn_submit_active: StandardMaterial3D
var mat_btn_submit_disabled: StandardMaterial3D

func _init() -> void:
	game_type = GameTypes.YATZY

func is_interacting_with_piece() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	return (now - _last_interaction_time) < 0.25

func _mark_interaction() -> void:
	_last_interaction_time = Time.get_ticks_msec() / 1000.0

static func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += FA_DIGITS[int(ch)]
		else:
			out += ch
	return out

func _ready() -> void:
	game_type = GameTypes.YATZY
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		_game_font = load("res://assets/fonts/hekayat.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Vazir.ttf"):
		_game_font = load("res://assets/fonts/Vazir.ttf")

	_init_board_arrays()
	_init_materials()
	_build_3d_arena()
	super._ready()
	_recalculate_all_preview_scores()
	_refresh_visuals()

func _init_board_arrays() -> void:
	p1_board.clear()
	p2_board.clear()
	for i in range(NUM_CATEGORIES):
		p1_board.append({"is_selected": false, "score": 0, "calc": 0, "last_played": false})
		p2_board.append({"is_selected": false, "score": 0, "calc": 0, "last_played": false})

func _init_materials() -> void:
	mat_wood_base = StandardMaterial3D.new()
	mat_wood_base.albedo_color = Color(0.22, 0.11, 0.05)
	mat_wood_base.roughness = 0.36
	mat_wood_base.metallic = 0.08
	mat_wood_base.clearcoat_enabled = true
	mat_wood_base.clearcoat = 0.35

	mat_wood_rim = StandardMaterial3D.new()
	mat_wood_rim.albedo_color = Color(0.14, 0.07, 0.03)
	mat_wood_rim.roughness = 0.32

	mat_obsidian_bed = StandardMaterial3D.new()
	mat_obsidian_bed.albedo_color = Color(0.08, 0.08, 0.11)
	mat_obsidian_bed.roughness = 0.28
	mat_obsidian_bed.metallic = 0.15

	mat_felt_tray = StandardMaterial3D.new()
	mat_felt_tray.albedo_color = Color(0.07, 0.28, 0.16)
	mat_felt_tray.roughness = 0.85
	mat_felt_tray.metallic = 0.02

	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.92, 0.75, 0.28)
	mat_gold_trim.metallic = 0.88
	mat_gold_trim.roughness = 0.20

	mat_row_even = StandardMaterial3D.new()
	mat_row_even.albedo_color = Color(0.12, 0.11, 0.15)
	mat_row_even.roughness = 0.38

	mat_row_odd = StandardMaterial3D.new()
	mat_row_odd.albedo_color = Color(0.15, 0.14, 0.19)
	mat_row_odd.roughness = 0.38

	mat_cat_badge = StandardMaterial3D.new()
	mat_cat_badge.albedo_color = Color(0.92, 0.88, 0.78)
	mat_cat_badge.roughness = 0.35

	mat_cell_idle_my = StandardMaterial3D.new()
	mat_cell_idle_my.albedo_color = Color(0.22, 0.20, 0.26)
	mat_cell_idle_my.roughness = 0.32
	mat_cell_idle_my.metallic = 0.12

	mat_cell_idle_opp = StandardMaterial3D.new()
	mat_cell_idle_opp.albedo_color = Color(0.13, 0.13, 0.16)
	mat_cell_idle_opp.roughness = 0.45

	mat_cell_equipped = StandardMaterial3D.new()
	mat_cell_equipped.albedo_color = Color(0.14, 0.68, 0.36)
	mat_cell_equipped.roughness = 0.24
	mat_cell_equipped.metallic = 0.18
	mat_cell_equipped.emission_enabled = true
	mat_cell_equipped.emission = Color(0.10, 0.55, 0.26)
	mat_cell_equipped.emission_energy_multiplier = 0.55

	mat_cell_p1_locked = StandardMaterial3D.new()
	mat_cell_p1_locked.albedo_color = Color(0.76, 0.16, 0.20)
	mat_cell_p1_locked.roughness = 0.26
	mat_cell_p1_locked.metallic = 0.15
	mat_cell_p1_locked.clearcoat_enabled = true
	mat_cell_p1_locked.clearcoat = 0.45

	mat_cell_p2_locked = StandardMaterial3D.new()
	mat_cell_p2_locked.albedo_color = Color(0.15, 0.38, 0.78)
	mat_cell_p2_locked.roughness = 0.26
	mat_cell_p2_locked.metallic = 0.15
	mat_cell_p2_locked.clearcoat_enabled = true
	mat_cell_p2_locked.clearcoat = 0.45

	mat_last_played_ring = StandardMaterial3D.new()
	mat_last_played_ring.albedo_color = Color(1.0, 0.86, 0.24)
	mat_last_played_ring.emission_enabled = true
	mat_last_played_ring.emission = Color(1.0, 0.78, 0.18)
	mat_last_played_ring.emission_energy_multiplier = 0.9

	mat_die_ivory = StandardMaterial3D.new()
	mat_die_ivory.albedo_color = Color(0.97, 0.94, 0.88)
	mat_die_ivory.roughness = 0.18
	mat_die_ivory.clearcoat_enabled = true
	mat_die_ivory.clearcoat = 0.65

	mat_die_held_ivory = StandardMaterial3D.new()
	mat_die_held_ivory.albedo_color = Color(1.0, 0.94, 0.72)
	mat_die_held_ivory.roughness = 0.16
	mat_die_held_ivory.emission_enabled = true
	mat_die_held_ivory.emission = Color(0.85, 0.65, 0.15)
	mat_die_held_ivory.emission_energy_multiplier = 0.30

	mat_pip_dark = StandardMaterial3D.new()
	mat_pip_dark.albedo_color = Color(0.08, 0.06, 0.05)
	mat_pip_dark.roughness = 0.25

	mat_pip_red = StandardMaterial3D.new()
	mat_pip_red.albedo_color = Color(0.86, 0.14, 0.18)
	mat_pip_red.roughness = 0.22

	mat_die_lock_ring = StandardMaterial3D.new()
	mat_die_lock_ring.albedo_color = Color(1.0, 0.82, 0.22)
	mat_die_lock_ring.metallic = 0.85
	mat_die_lock_ring.roughness = 0.18
	mat_die_lock_ring.emission_enabled = true
	mat_die_lock_ring.emission = Color(1.0, 0.75, 0.15)
	mat_die_lock_ring.emission_energy_multiplier = 0.85

	mat_btn_roll_active = StandardMaterial3D.new()
	mat_btn_roll_active.albedo_color = Color(0.16, 0.44, 0.82)
	mat_btn_roll_active.roughness = 0.26
	mat_btn_roll_active.metallic = 0.18
	mat_btn_roll_active.emission_enabled = true
	mat_btn_roll_active.emission = Color(0.10, 0.30, 0.62)
	mat_btn_roll_active.emission_energy_multiplier = 0.35

	mat_btn_roll_disabled = StandardMaterial3D.new()
	mat_btn_roll_disabled.albedo_color = Color(0.22, 0.24, 0.28)
	mat_btn_roll_disabled.roughness = 0.55

	mat_btn_submit_active = StandardMaterial3D.new()
	mat_btn_submit_active.albedo_color = Color(0.14, 0.64, 0.32)
	mat_btn_submit_active.roughness = 0.26
	mat_btn_submit_active.metallic = 0.18
	mat_btn_submit_active.emission_enabled = true
	mat_btn_submit_active.emission = Color(0.08, 0.45, 0.20)
	mat_btn_submit_active.emission_energy_multiplier = 0.40

	mat_btn_submit_disabled = StandardMaterial3D.new()
	mat_btn_submit_disabled.albedo_color = Color(0.22, 0.24, 0.28)
	mat_btn_submit_disabled.roughness = 0.55

# ==============================================================================
# 3D ARENA CONSTRUCTION
# ==============================================================================

func _build_3d_arena() -> void:
	# 1. Outer Carved Walnut Plinth
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(BOARD_W, BOARD_H, BOARD_L)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, BOARD_H * 0.5, 0)
	add_child(plinth)

	# Outer Gold Inlay Trim Frame
	for border_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.004, -BOARD_L * 0.5 + 0.018), "size": Vector3(BOARD_W - 0.02, 0.008, 0.024)},
		{"pos": Vector3(0, BOARD_H + 0.004, BOARD_L * 0.5 - 0.018), "size": Vector3(BOARD_W - 0.02, 0.008, 0.024)},
		{"pos": Vector3(-BOARD_W * 0.5 + 0.018, BOARD_H + 0.004, 0), "size": Vector3(0.024, 0.008, BOARD_L - 0.02)},
		{"pos": Vector3(BOARD_W * 0.5 - 0.018, BOARD_H + 0.004, 0), "size": Vector3(0.024, 0.008, BOARD_L - 0.02)},
	]:
		var b_inst = MeshInstance3D.new()
		var b_box = BoxMesh.new()
		b_box.size = border_cfg["size"]
		b_box.material = mat_gold_trim
		b_inst.mesh = b_box
		b_inst.position = border_cfg["pos"]
		add_child(b_inst)

	# 4 Brass Corner Medallions
	for cx in [-BOARD_W * 0.5 + 0.032, BOARD_W * 0.5 - 0.032]:
		for cz in [-BOARD_L * 0.5 + 0.032, BOARD_L * 0.5 - 0.032]:
			var med = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.024
			cyl.bottom_radius = 0.028
			cyl.height = 0.012
			cyl.material = mat_gold_trim
			med.mesh = cyl
			med.position = Vector3(cx, BOARD_H + 0.006, cz)
			add_child(med)

	# 2. Upper Obsidian Scorecard Bed (Z = -0.57 to +0.11)
	var score_bed = MeshInstance3D.new()
	var sb_mesh = BoxMesh.new()
	sb_mesh.size = Vector3(1.16, 0.006, 0.68)
	sb_mesh.material = mat_obsidian_bed
	score_bed.mesh = sb_mesh
	score_bed.position = Vector3(0, BOARD_H + 0.003, -0.23)
	add_child(score_bed)

	# Center Brass Divider between Left Column (0..5) and Right Column (6..11)
	var col_div = MeshInstance3D.new()
	var cd_mesh = BoxMesh.new()
	cd_mesh.size = Vector3(0.012, 0.010, 0.66)
	cd_mesh.material = mat_gold_trim
	col_div.mesh = cd_mesh
	col_div.position = Vector3(0, BOARD_H + 0.006, -0.23)
	add_child(col_div)

	# Column Headers for Both Columns
	_col_header_labels.clear()
	for col_idx in range(2):
		var col_x = -0.285 if col_idx == 0 else 0.285
		var hdr_z = -0.535
		var lbl_p2 = _create_3d_label("🔵 بازیکن ۲", 22, Color(0.48, 0.82, 1.0))
		lbl_p2.position = Vector3(col_x - 0.175, BOARD_H + 0.012, hdr_z)
		add_child(lbl_p2)
		_col_header_labels.append(lbl_p2)

		var lbl_p1 = _create_3d_label("🔴 بازیکن ۱", 22, Color(1.0, 0.48, 0.52))
		lbl_p1.position = Vector3(col_x - 0.020, BOARD_H + 0.012, hdr_z)
		add_child(lbl_p1)
		_col_header_labels.append(lbl_p1)

		var lbl_cat = _create_3d_label("خانه امتیاز", 22, Color(0.96, 0.88, 0.65))
		lbl_cat.position = Vector3(col_x + 0.155, BOARD_H + 0.012, hdr_z)
		add_child(lbl_cat)

	# Build the 12 Category Rows (0..5 in Left Column, 6..11 in Right Column)
	_cat_row_nodes.clear()
	for idx in range(NUM_CATEGORIES):
		var col_idx = 0 if idx < 6 else 1
		var row_in_col = idx % 6
		var col_center_x = -0.285 if col_idx == 0 else 0.285
		var row_z = -0.465 + float(row_in_col) * 0.098
		var row_dict = _build_category_row(idx, col_center_x, row_z)
		_cat_row_nodes.append(row_dict)

	# 3. Middle Sunken Emerald-Baize 3D Dice Tray (Z = +0.14 to +0.43)
	var tray_bed = MeshInstance3D.new()
	var tb_mesh = BoxMesh.new()
	tb_mesh.size = Vector3(1.12, 0.006, 0.27)
	tb_mesh.material = mat_felt_tray
	tray_bed.mesh = tb_mesh
	tray_bed.position = Vector3(0, BOARD_H + 0.003, 0.285)
	add_child(tray_bed)

	# Brass Trim Around Dice Tray
	for t_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.008, 0.148), "size": Vector3(1.14, 0.012, 0.014)},
		{"pos": Vector3(0, BOARD_H + 0.008, 0.422), "size": Vector3(1.14, 0.012, 0.014)},
		{"pos": Vector3(-0.565, BOARD_H + 0.008, 0.285), "size": Vector3(0.014, 0.012, 0.28)},
		{"pos": Vector3(0.565, BOARD_H + 0.008, 0.285), "size": Vector3(0.014, 0.012, 0.28)},
	]:
		var rim = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = t_cfg["size"]
		r_box.material = mat_gold_trim
		rim.mesh = r_box
		rim.position = t_cfg["pos"]
		add_child(rim)

	# Tray Guidance Label (Top edge of felt tray)
	_status_lbl_3d = _create_3d_label("برای نگه داشتن هر تاس روی آن بزنید", 21, Color(0.95, 0.92, 0.78))
	_status_lbl_3d.position = Vector3(0, BOARD_H + 0.010, 0.178)
	add_child(_status_lbl_3d)

	# Build 5 Physical 3D Dice inside the Felt Tray
	_dice_nodes.clear()
	var dice_x_positions = [-0.40, -0.20, 0.0, 0.20, 0.40]
	for d_idx in range(NUM_DICE):
		var d_dict = _build_3d_die_slot(d_idx, Vector3(dice_x_positions[d_idx], BOARD_H + 0.006, 0.285))
		_dice_nodes.append(d_dict)

	# 4. Front 3D Control Console (Roll Dice & Submit Score Buttons at Z = +0.52)
	_btn_roll_node = _build_3d_action_button(
		"BtnRollDice",
		Vector3(-0.28, BOARD_H + 0.012, 0.52),
		Vector3(0.50, 0.022, 0.115),
		"🎲 تاس بریز (۲)",
		mat_btn_roll_active
	)
	_btn_submit_node = _build_3d_action_button(
		"BtnSubmitScore",
		Vector3(0.28, BOARD_H + 0.012, 0.52),
		Vector3(0.50, 0.022, 0.115),
		"✅ ثبت امتیاز",
		mat_btn_submit_active
	)

func _build_category_row(cat_idx: int, col_center_x: float, row_z: float) -> Dictionary:
	var row_root = Node3D.new()
	row_root.name = "CatRow_%d" % cat_idx
	row_root.position = Vector3(col_center_x, BOARD_H + 0.007, row_z)
	add_child(row_root)

	# Row background strip
	var bg_inst = MeshInstance3D.new()
	var bg_box = BoxMesh.new()
	bg_box.size = Vector3(0.54, 0.006, 0.086)
	bg_box.material = mat_row_even if (cat_idx % 2 == 0) else mat_row_odd
	bg_inst.mesh = bg_box
	row_root.add_child(bg_inst)

	# 1. Left Tile: Player 2 Score Cell (X = -0.175)
	var p2_cell = _build_score_cell_mesh(Vector3(-0.175, 0.005, 0), Vector3(0.135, 0.012, 0.074))
	row_root.add_child(p2_cell["root"])

	# 2. Middle Tile: Player 1 Score Cell (X = -0.020)
	var p1_cell = _build_score_cell_mesh(Vector3(-0.020, 0.005, 0), Vector3(0.135, 0.012, 0.074))
	row_root.add_child(p1_cell["root"])

	# 3. Right Tile: Category Icon & Persian Name Plaque (X = +0.155)
	var cat_plaque = MeshInstance3D.new()
	var cp_box = BoxMesh.new()
	cp_box.size = Vector3(0.19, 0.010, 0.074)
	cp_box.material = mat_cat_badge
	cat_plaque.mesh = cp_box
	cat_plaque.position = Vector3(0.155, 0.004, 0)
	row_root.add_child(cat_plaque)

	# Category Icon Sprite3D
	var icon_spr = Sprite3D.new()
	var icon_path = CATEGORY_ICON_PATHS[cat_idx]
	if ResourceLoader.exists(icon_path):
		icon_spr.texture = load(icon_path)
	icon_spr.pixel_size = 0.00055
	icon_spr.axis = Vector3.AXIS_Y
	icon_spr.modulate = Color(0.14, 0.09, 0.05, 1.0)
	icon_spr.position = Vector3(0.212, 0.011, 0)
	row_root.add_child(icon_spr)

	# Category Persian Title Label3D
	var cat_lbl = _create_3d_label(CATEGORY_NAMES_FA[cat_idx], 22, Color(0.15, 0.09, 0.04), false)
	cat_lbl.position = Vector3(0.125, 0.011, 0)
	row_root.add_child(cat_lbl)

	# Physics Area3D for clicking this category row (equips category)
	var row_area = Area3D.new()
	row_area.name = "AreaCat_%d" % cat_idx
	row_area.position = Vector3(-0.095, 0.010, 0)
	row_area.set_meta("hit_type", "category")
	row_area.set_meta("cat_index", cat_idx)
	var col_shape = CollisionShape3D.new()
	var box_s = BoxShape3D.new()
	box_s.size = Vector3(0.32, 0.035, 0.084)
	col_shape.shape = box_s
	row_area.add_child(col_shape)
	row_root.add_child(row_area)

	# Physics Area3D for clicking the category guide header on the right
	var guide_area = Area3D.new()
	guide_area.name = "AreaGuide_%d" % cat_idx
	guide_area.position = Vector3(0.155, 0.010, 0)
	guide_area.set_meta("hit_type", "guide")
	guide_area.set_meta("cat_index", cat_idx)
	var g_col = CollisionShape3D.new()
	var g_box = BoxShape3D.new()
	g_box.size = Vector3(0.19, 0.035, 0.084)
	g_col.shape = g_box
	guide_area.add_child(g_col)
	row_root.add_child(guide_area)

	return {
		"root": row_root,
		"p1": p1_cell,
		"p2": p2_cell,
		"cat_lbl": cat_lbl,
	}

func _build_score_cell_mesh(pos: Vector3, cell_size: Vector3) -> Dictionary:
	var root = Node3D.new()
	root.position = pos

	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = cell_size
	box.material = mat_cell_idle_my
	mesh_inst.mesh = box
	root.add_child(mesh_inst)

	# Highlight border frame (used when equipped or last played)
	var ring_inst = MeshInstance3D.new()
	var r_box = BoxMesh.new()
	r_box.size = cell_size + Vector3(0.010, -0.002, 0.010)
	r_box.material = mat_last_played_ring
	ring_inst.mesh = r_box
	ring_inst.visible = false
	root.add_child(ring_inst)

	var val_lbl = _create_3d_label("۰", 28, Color(1.0, 0.95, 0.82))
	val_lbl.position = Vector3(0, cell_size.y * 0.5 + 0.003, 0)
	root.add_child(val_lbl)

	return {
		"root": root,
		"mesh": mesh_inst,
		"ring": ring_inst,
		"label": val_lbl,
	}

func _build_3d_die_slot(d_idx: int, slot_pos: Vector3) -> Dictionary:
	var slot_root = Node3D.new()
	slot_root.name = "DieSlot_%d" % d_idx
	slot_root.position = slot_pos
	add_child(slot_root)

	# Golden Lock Ring Pedestal under held die
	var lock_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.048
	torus.outer_radius = 0.064
	torus.rings = 24
	torus.ring_segments = 24
	torus.material = mat_die_lock_ring
	lock_ring.mesh = torus
	lock_ring.position = Vector3(0, 0.004, -0.012)
	lock_ring.visible = false
	slot_root.add_child(lock_ring)

	# 3D Physical Die Cube with Pips on all 6 faces
	var die_pivot = Node3D.new()
	die_pivot.name = "DiePivot"
	die_pivot.position = Vector3(0, 0.042, -0.012)
	slot_root.add_child(die_pivot)

	var cube_inst = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	var die_s: float = 0.072
	cube_mesh.size = Vector3(die_s, die_s, die_s)
	cube_mesh.material = mat_die_ivory
	cube_inst.mesh = cube_mesh
	die_pivot.add_child(cube_inst)

	# Build 3D pips on all 6 faces of the cube
	_add_3d_die_pips(die_pivot, die_s * 0.5)

	# Front Badge below die showing Persian value & Hold status
	var val_lbl = _create_3d_label("۱", 24, Color(1.0, 0.94, 0.72))
	val_lbl.position = Vector3(0, 0.006, 0.078)
	slot_root.add_child(val_lbl)

	# Raycast hit area for toggling hold on this die
	var area = Area3D.new()
	area.name = "AreaDie_%d" % d_idx
	area.position = Vector3(0, 0.042, 0.01)
	area.set_meta("hit_type", "die")
	area.set_meta("die_index", d_idx)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.14, 0.10, 0.20)
	col.shape = shape
	area.add_child(col)
	slot_root.add_child(area)

	return {
		"root": slot_root,
		"pivot": die_pivot,
		"cube": cube_inst,
		"lock_ring": lock_ring,
		"label": val_lbl,
	}

func _add_3d_die_pips(die_pivot: Node3D, half_s: float) -> void:
	var o: float = half_s * 0.52
	# Standard opposing faces sum to 7:
	# +Y = 1, -Y = 6, +Z = 2, -Z = 5, +X = 3, -X = 4
	var face_configs = [
		# Face 1 (+Y)
		{"normal": Vector3.UP, "right": Vector3.RIGHT, "fwd": Vector3.BACK, "pips": [Vector2(0, 0)], "red": true},
		# Face 6 (-Y)
		{"normal": Vector3.DOWN, "right": Vector3.RIGHT, "fwd": Vector3.FORWARD, "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false},
		# Face 2 (+Z)
		{"normal": Vector3.BACK, "right": Vector3.RIGHT, "fwd": Vector3.DOWN, "pips": [
			Vector2(-o, -o), Vector2(o, o)
		], "red": false},
		# Face 5 (-Z)
		{"normal": Vector3.FORWARD, "right": Vector3.LEFT, "fwd": Vector3.DOWN, "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false},
		# Face 3 (+X)
		{"normal": Vector3.RIGHT, "right": Vector3.FORWARD, "fwd": Vector3.DOWN, "pips": [
			Vector2(-o, -o), Vector2(0, 0), Vector2(o, o)
		], "red": false},
		# Face 4 (-X)
		{"normal": Vector3.LEFT, "right": Vector3.BACK, "fwd": Vector3.DOWN, "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)
		], "red": false},
	]

	for fc in face_configs:
		var n: Vector3 = fc["normal"]
		var r: Vector3 = fc["right"]
		var f: Vector3 = fc["fwd"]
		var is_red: bool = fc["red"]
		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			var sph = SphereMesh.new()
			var rad = 0.0095 if is_red else 0.0072
			sph.radius = rad
			sph.height = rad * 0.9
			sph.material = mat_pip_red if is_red else mat_pip_dark
			pip.mesh = sph
			pip.position = n * (half_s + 0.0008) + r * p2.x + f * p2.y
			die_pivot.add_child(pip)

func _get_die_target_rotation(val: int) -> Vector3:
	# Rotates die_pivot so the face corresponding to `val` (1..6) points straight UP (+Y)
	match val:
		1: return Vector3(0.0, 0.0, 0.0)
		2: return Vector3(-PI * 0.5, 0.0, 0.0)
		3: return Vector3(0.0, 0.0, PI * 0.5)
		4: return Vector3(0.0, 0.0, -PI * 0.5)
		5: return Vector3(PI * 0.5, 0.0, 0.0)
		6: return Vector3(PI, 0.0, 0.0)
		_: return Vector3.ZERO

func _build_3d_action_button(btn_name: String, pos: Vector3, btn_size: Vector3, title_text: String, active_mat: StandardMaterial3D) -> Dictionary:
	var root = Node3D.new()
	root.name = btn_name
	root.position = pos
	add_child(root)

	# Brass Bezel Base
	var bezel = MeshInstance3D.new()
	var bz_box = BoxMesh.new()
	bz_box.size = btn_size + Vector3(0.016, -0.004, 0.016)
	bz_box.material = mat_gold_trim
	bezel.mesh = bz_box
	root.add_child(bezel)

	# Button Cap
	var cap = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = btn_size
	cap_box.material = active_mat
	cap.mesh = cap_box
	cap.position = Vector3(0, 0.004, 0)
	root.add_child(cap)

	var lbl = _create_3d_label(title_text, 25, Color(1.0, 0.98, 0.90))
	lbl.position = Vector3(0, btn_size.y * 0.5 + 0.007, 0)
	root.add_child(lbl)

	var area = Area3D.new()
	area.name = "Area_" + btn_name
	area.set_meta("hit_type", btn_name)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = btn_size + Vector3(0.02, 0.03, 0.02)
	col.shape = shape
	area.add_child(col)
	root.add_child(area)

	return {
		"root": root,
		"cap": cap,
		"label": lbl,
	}

func _create_3d_label(txt: String, f_size: int, col: Color, with_outline: bool = true) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = txt
	if _game_font:
		lbl.font = _game_font
	lbl.font_size = f_size
	lbl.pixel_size = 0.0012
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.outline_size = 12 if with_outline else 2
	lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.95) if with_outline else Color(1.0, 0.96, 0.88, 0.35)
	return lbl

# ==============================================================================
# EXACT SCORING ENGINE (Ported from YatzyController & YatzyGameClass)
# ==============================================================================

func _calculate_simple_dices(number: int) -> int:
	var s: int = 0
	for d in current_dices:
		if d == number:
			s += number
	return s

func _calculate_repeatness(number: int, count: int) -> bool:
	var cnt: int = 0
	for d in current_dices:
		if d == number:
			cnt += 1
	return cnt >= count

func _calculate_all_dices() -> int:
	var s: int = 0
	for d in current_dices:
		s += d
	return s

func _calculate_3times_repeat() -> int:
	for i in range(1, 7):
		if _calculate_repeatness(i, 3):
			return _calculate_all_dices()
	return 0

func _calculate_4times_repeat() -> int:
	for i in range(1, 7):
		if _calculate_repeatness(i, 4):
			return _calculate_all_dices()
	return 0

func _calculate_23_times_repeat() -> bool:
	var is3: bool = false
	var three_val: int = -1
	for i in range(1, 7):
		if _calculate_repeatness(i, 3):
			is3 = true
			three_val = i
			break
	if is3:
		for i in range(1, 7):
			if _calculate_repeatness(i, 2) and i != three_val:
				return true
	return false

func _calculate_15_exists() -> bool:
	var has_1_5 = (1 in current_dices) and (2 in current_dices) and (3 in current_dices) and (4 in current_dices) and (5 in current_dices)
	var has_2_6 = (2 in current_dices) and (3 in current_dices) and (4 in current_dices) and (5 in current_dices) and (6 in current_dices)
	return has_1_5 or has_2_6

func _calculate_5times_repeat() -> int:
	for i in range(1, 7):
		if _calculate_repeatness(i, 5):
			return 50
	return 0

func _calculate_category_score(cat_idx: int) -> int:
	match cat_idx:
		0: return _calculate_simple_dices(1)
		1: return _calculate_simple_dices(2)
		2: return _calculate_simple_dices(3)
		3: return _calculate_simple_dices(4)
		4: return _calculate_simple_dices(5)
		5: return _calculate_simple_dices(6)
		6: return _calculate_3times_repeat()
		7: return _calculate_4times_repeat()
		8: return _calculate_all_dices()
		9: return 25 if _calculate_23_times_repeat() else 0
		10: return 40 if _calculate_15_exists() else 0
		11: return _calculate_5times_repeat()
		_: return 0

func _recalculate_all_preview_scores() -> void:
	var my_arr = p1_board if my_player_index == 1 else p2_board
	for idx in range(NUM_CATEGORIES):
		var sc = _calculate_category_score(idx)
		my_arr[idx]["calc"] = sc
	if _calculate_5times_repeat() == 50 and GameManager.is_game_active and not is_round_played:
		AudioManager.play_sound("correct")

func _select_first_empty_index() -> void:
	var my_arr = p1_board if my_player_index == 1 else p2_board
	for i in range(NUM_CATEGORIES):
		if not bool(my_arr[i]["is_selected"]):
			equipped_index = i
			return
	equipped_index = 0

# ==============================================================================
# VISUAL REFRESH & DICE ANIMATIONS
# ==============================================================================

func _refresh_visuals() -> void:
	my_player_index = GameManager.my_player_index

	# Update column header labels to highlight which column is "شما"
	for c_idx in range(2):
		var base_i = c_idx * 2
		if base_i + 1 < _col_header_labels.size():
			var lbl_p2 = _col_header_labels[base_i]
			var lbl_p1 = _col_header_labels[base_i + 1]
			lbl_p2.text = "🔵 شما" if my_player_index == 2 else "🔵 حریف"
			lbl_p1.text = "🔴 شما" if my_player_index == 1 else "🔴 حریف"

	# 1. Refresh all 12 Category Rows
	for idx in range(NUM_CATEGORIES):
		if idx >= _cat_row_nodes.size():
			continue
		var row_ui = _cat_row_nodes[idx]
		_update_single_cell_ui(row_ui["p1"], p1_board[idx], 1, idx)
		_update_single_cell_ui(row_ui["p2"], p2_board[idx], 2, idx)

	# 2. Refresh 5 3D Dice slots
	for d_idx in range(NUM_DICE):
		if d_idx >= _dice_nodes.size():
			continue
		var d_ui = _dice_nodes[d_idx]
		var val = current_dices[d_idx] if d_idx < current_dices.size() else 1
		var is_held = d_idx in held_dice_indices
		d_ui["lock_ring"].visible = is_held
		(d_ui["cube"] as MeshInstance3D).material_override = mat_die_held_ivory if is_held else mat_die_ivory

		var d_lbl: Label3D = d_ui["label"]
		if is_held:
			d_lbl.text = "🔒 %s" % _fa_digits(val)
			d_lbl.modulate = Color(1.0, 0.88, 0.28)
		else:
			d_lbl.text = "🎲 %s" % _fa_digits(val)
			d_lbl.modulate = Color(0.95, 0.94, 0.88)

		if not is_rolling_dice:
			var target_y = 0.056 if is_held else 0.042
			d_ui["pivot"].position.y = target_y
			d_ui["pivot"].rotation = _get_die_target_rotation(val)

	# 3. Refresh Action Buttons & Status Guidance
	var can_act = GameManager.is_game_active and not is_round_played and not is_board_locked
	var can_roll = can_act and (remaining_rolls > 0) and not is_rolling_dice

	if _btn_roll_node.has("cap"):
		(_btn_roll_node["cap"] as MeshInstance3D).material_override = mat_btn_roll_active if can_roll else mat_btn_roll_disabled
		var roll_lbl: Label3D = _btn_roll_node["label"]
		if remaining_rolls > 0:
			roll_lbl.text = "🎲 تاس بریز (%s)" % _fa_digits(remaining_rolls)
			roll_lbl.modulate = Color(1.0, 0.98, 0.90) if can_roll else Color(0.65, 0.65, 0.68)
		else:
			roll_lbl.text = "🎲 تاسی نمانده (۰)"
			roll_lbl.modulate = Color(0.65, 0.65, 0.68)

	if _btn_submit_node.has("cap"):
		(_btn_submit_node["cap"] as MeshInstance3D).material_override = mat_btn_submit_active if can_act else mat_btn_submit_disabled
		var sub_lbl: Label3D = _btn_submit_node["label"]
		var my_arr = p1_board if my_player_index == 1 else p2_board
		var eq_name = CATEGORY_NAMES_FA[equipped_index] if (equipped_index >= 0 and equipped_index < NUM_CATEGORIES) else ""
		var eq_pts = int(my_arr[equipped_index]["calc"]) if (equipped_index >= 0 and equipped_index < my_arr.size()) else 0
		if is_round_played:
			sub_lbl.text = "⏳ منتظر حرکت حریف..."
			sub_lbl.modulate = Color(0.75, 0.85, 0.95)
		else:
			sub_lbl.text = "✅ ثبت (%s: %s)" % [eq_name, _fa_digits(eq_pts)]
			sub_lbl.modulate = Color(1.0, 0.98, 0.90) if can_act else Color(0.65, 0.65, 0.68)

	if is_instance_valid(_status_lbl_3d):
		if is_round_played:
			_status_lbl_3d.text = "⏳ امتیاز این دست شما ثبت شد — منتظر انتخاب حریف باشید..."
			_status_lbl_3d.modulate = Color(0.55, 0.90, 1.0)
		elif remaining_rolls > 0:
			_status_lbl_3d.text = "تاس‌های دلخواه را قفل کنید (🔒) یا خانه امتیاز را انتخاب و ثبت کنید"
			_status_lbl_3d.modulate = Color(0.98, 0.92, 0.72)
		else:
			_status_lbl_3d.text = "فرصت پرتاب تاس تمام شد — یک خانه را انتخاب و ثبت کنید"
			_status_lbl_3d.modulate = Color(1.0, 0.84, 0.42)

func _update_single_cell_ui(cell_ui: Dictionary, cell_data: Dictionary, player_num: int, cat_idx: int) -> void:
	var mesh_inst: MeshInstance3D = cell_ui["mesh"]
	var ring_inst: MeshInstance3D = cell_ui["ring"]
	var lbl: Label3D = cell_ui["label"]

	var is_sel = bool(cell_data["is_selected"])
	var is_last = bool(cell_data["last_played"])
	var is_my_col = (player_num == my_player_index)
	var is_equipped = (is_my_col and not is_sel and not is_round_played and equipped_index == cat_idx)

	if is_sel:
		mesh_inst.material_override = mat_cell_p1_locked if player_num == 1 else mat_cell_p2_locked
		ring_inst.visible = is_last
		lbl.text = _fa_digits(int(cell_data["score"]))
		lbl.modulate = Color(1.0, 0.98, 0.92)
	elif is_my_col:
		var preview_val = int(cell_data["calc"])
		if is_equipped:
			mesh_inst.material_override = mat_cell_equipped
			ring_inst.visible = true
			lbl.text = "✓ %s" % _fa_digits(preview_val)
			lbl.modulate = Color(1.0, 0.98, 0.78)
		else:
			mesh_inst.material_override = mat_cell_idle_my
			ring_inst.visible = false
			lbl.text = _fa_digits(preview_val) if not is_round_played else "۰"
			lbl.modulate = Color(1.0, 0.88, 0.38) if (preview_val > 0 and not is_round_played) else Color(0.65, 0.64, 0.68)
	else:
		mesh_inst.material_override = mat_cell_idle_opp
		ring_inst.visible = false
		lbl.text = "-"
		lbl.modulate = Color(0.50, 0.50, 0.55)

func _animate_dice_roll(only_unheld: bool = false) -> void:
	is_rolling_dice = true
	AudioManager.sfx_dice()

	for d_idx in range(NUM_DICE):
		if d_idx >= _dice_nodes.size():
			continue
		if only_unheld and (d_idx in held_dice_indices):
			continue
		var d_ui = _dice_nodes[d_idx]
		var pivot: Node3D = d_ui["pivot"]
		var val = current_dices[d_idx] if d_idx < current_dices.size() else 1
		var final_rot = _get_die_target_rotation(val)

		var spin_rot = final_rot + Vector3(TAU * 2.0, TAU * 1.0, TAU * 2.0)
		pivot.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "position:y", 0.135, 0.16)
		tw.parallel().tween_property(pivot, "rotation", spin_rot, 0.36)
		tw.tween_property(pivot, "position:y", 0.042, 0.20)
		tw.tween_callback(func():
			if is_instance_valid(pivot):
				pivot.rotation = final_rot
		)

	get_tree().create_timer(0.38).timeout.connect(func():
		if is_instance_valid(self):
			is_rolling_dice = false
			_refresh_visuals()
	)

# ==============================================================================
# INPUT HANDLING (3D Camera Raycasting)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_board_click(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_handle_board_click(event.position)

func _handle_board_click(screen_pos: Vector2) -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var cam = viewport.get_camera_3d()
	if not cam:
		return

	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 10.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result.get("collider")
	if not collider or not (collider is Area3D):
		return

	_mark_interaction()
	var hit_type = str(collider.get_meta("hit_type", ""))

	match hit_type:
		"guide":
			var g_idx = int(collider.get_meta("cat_index", 0))
			if g_idx >= 0 and g_idx < CATEGORY_GUIDES_FA.size():
				AudioManager.sfx_tap()
				show_hint("ℹ️ " + CATEGORY_GUIDES_FA[g_idx])
		"category":
			var c_idx = int(collider.get_meta("cat_index", 0))
			_on_category_clicked(c_idx)
		"die":
			var d_idx = int(collider.get_meta("die_index", 0))
			_on_die_clicked(d_idx)
		"BtnRollDice":
			_on_roll_button_clicked()
		"BtnSubmitScore":
			_on_submit_button_clicked()

func _on_category_clicked(cat_idx: int) -> void:
	if not GameManager.is_game_active:
		return
	if is_round_played:
		AudioManager.play_sound("miss_turn")
		show_hint("این دست را بازی کرده‌اید؛ منتظر حریف بمانید.")
		return
	var my_arr = p1_board if my_player_index == 1 else p2_board
	if cat_idx < 0 or cat_idx >= my_arr.size():
		return
	if bool(my_arr[cat_idx]["is_selected"]):
		AudioManager.play_sound("miss_turn")
		show_hint("این خانه قبلاً انتخاب شده است!")
		return

	if equipped_index != cat_idx:
		equipped_index = cat_idx
		AudioManager.sfx_tap()
		_refresh_visuals()
		var cell_node: Node3D = _cat_row_nodes[cat_idx]["p1" if my_player_index == 1 else "p2"]["root"]
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cell_node, "scale", Vector3(1.12, 1.12, 1.12), 0.12)
		tw.tween_property(cell_node, "scale", Vector3.ONE, 0.12)
	else:
		# Tapping an already-equipped category shows its score preview hint
		var pts = int(my_arr[cat_idx]["calc"])
		AudioManager.sfx_tap()
		show_hint("خانه «%s» انتخاب شد (%s امتیاز) — دکمه «ثبت» را بزنید" % [CATEGORY_NAMES_FA[cat_idx], _fa_digits(pts)])

func _on_die_clicked(die_idx: int) -> void:
	if not GameManager.is_game_active or is_round_played:
		return
	if die_idx < 0 or die_idx >= NUM_DICE:
		return

	AudioManager.sfx_tap()
	if die_idx in held_dice_indices:
		held_dice_indices.erase(die_idx)
	else:
		held_dice_indices.append(die_idx)

	_refresh_visuals()
	if die_idx < _dice_nodes.size():
		var pivot: Node3D = _dice_nodes[die_idx]["pivot"]
		var is_held = die_idx in held_dice_indices
		var target_y = 0.056 if is_held else 0.042
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "position:y", target_y, 0.14)

func _on_roll_button_clicked() -> void:
	if not GameManager.is_game_active:
		return
	if is_round_played:
		AudioManager.play_sound("miss_turn")
		show_hint("این دست را بازی کرده‌اید؛ منتظر حریف بمانید.")
		return
	if remaining_rolls <= 0:
		AudioManager.play_sound("miss_turn")
		show_hint("تاسی برای پرتاب مجدد باقی نمانده است!")
		return

	# Animate button press
	if _btn_roll_node.has("root"):
		var b_root: Node3D = _btn_roll_node["root"]
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.08)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.12)

	remaining_rolls -= 1
	_refresh_visuals()
	send_move(Commands.Roll_Dice, {"selected_indexes": held_dice_indices.duplicate()})

func _on_submit_button_clicked() -> void:
	if not GameManager.is_game_active:
		return
	if is_round_played:
		AudioManager.play_sound("miss_turn")
		show_hint("این دست را بازی کرده‌اید؛ منتظر حریف بمانید.")
		return

	var my_arr = p1_board if my_player_index == 1 else p2_board
	if equipped_index < 0 or equipped_index >= my_arr.size() or bool(my_arr[equipped_index]["is_selected"]):
		_select_first_empty_index()

	# Animate button press
	if _btn_submit_node.has("root"):
		var b_root: Node3D = _btn_submit_node["root"]
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.08)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.12)

	is_round_played = true
	var chosen_idx = equipped_index
	held_dice_indices.clear()
	AudioManager.sfx_add_piece()
	_refresh_visuals()

	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("set_waiting_opponent"):
		hud.set_waiting_opponent("امتیاز شما ثبت شد! در انتظار حریف...")

	send_move(Commands.Select_Peace, {"index": chosen_idx})

# ==============================================================================
# NETWORK HOOKS (BaseGameBoard Overrides)
# ==============================================================================

func on_turn_data(payload: Dictionary) -> void:
	if payload.has("dices") and typeof(payload["dices"]) == TYPE_ARRAY:
		var d_arr: Array = payload["dices"]
		current_dices.clear()
		for v in d_arr:
			current_dices.append(clampi(int(v), 1, 6))
		while current_dices.size() < NUM_DICE:
			current_dices.append(1)

	# Reset per-round state matching Flutter YatzyController.resetRound()
	for i in range(NUM_CATEGORIES):
		p1_board[i]["last_played"] = false
		p2_board[i]["last_played"] = false

	held_dice_indices.clear()
	remaining_rolls = 2
	is_round_played = false
	set_board_locked(false)
	_select_first_empty_index()
	_recalculate_all_preview_scores()
	_refresh_visuals()
	_animate_dice_roll(false)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	current_turn = turn
	set_board_locked(false)
	_refresh_visuals()

func on_roll_result(payload: Dictionary) -> void:
	if payload.has("dices") and typeof(payload["dices"]) == TYPE_ARRAY:
		var d_arr: Array = payload["dices"]
		current_dices.clear()
		for v in d_arr:
			current_dices.append(clampi(int(v), 1, 6))
		while current_dices.size() < NUM_DICE:
			current_dices.append(1)

	_recalculate_all_preview_scores()
	_refresh_visuals()
	_animate_dice_roll(true)

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var sel_idx = int(extra.get("selected_index", target_peace))
	var sc = int(extra.get("score", 0))
	var p1_tot = int(extra.get("player1_score", GameManager.p1_score))
	var p2_tot = int(extra.get("player2_score", GameManager.p2_score))

	if sel_idx >= 0 and sel_idx < NUM_CATEGORIES:
		if user_id == 1:
			for i in range(NUM_CATEGORIES):
				p1_board[i]["last_played"] = false
			p1_board[sel_idx]["is_selected"] = true
			p1_board[sel_idx]["score"] = sc
			p1_board[sel_idx]["last_played"] = true
		elif user_id == 2:
			for i in range(NUM_CATEGORIES):
				p2_board[i]["last_played"] = false
			p2_board[sel_idx]["is_selected"] = true
			p2_board[sel_idx]["score"] = sc
			p2_board[sel_idx]["last_played"] = true

	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("update_scores"):
		hud.update_scores(p1_tot, p2_tot)

	if user_id == my_player_index:
		is_round_played = true

	_refresh_visuals()

	# Spawn celebratory impact VFX on the scored cell
	if sel_idx >= 0 and sel_idx < _cat_row_nodes.size():
		var cell_dict = _cat_row_nodes[sel_idx]["p1" if user_id == 1 else "p2"]
		var cell_root: Node3D = cell_dict["root"]
		ActionVFXManager.spawn_piece_impact_vfx(self, cell_root.global_position - global_position, user_id)

func on_wait_time(time_sec: int) -> void:
	is_round_played = true
	set_board_locked(true)
	_refresh_visuals()
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("set_round_wait"):
		hud.set_round_wait(time_sec)

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) != TYPE_DICTIONARY:
		return

	var p1_b = g_data.get("player1_board", [])
	if typeof(p1_b) == TYPE_ARRAY:
		for i in range(min(NUM_CATEGORIES, p1_b.size())):
			if typeof(p1_b[i]) == TYPE_DICTIONARY:
				p1_board[i]["is_selected"] = bool(p1_b[i].get("is_selected", false))
				p1_board[i]["score"] = int(p1_b[i].get("score", 0))

	var p2_b = g_data.get("player2_board", [])
	if typeof(p2_b) == TYPE_ARRAY:
		for i in range(min(NUM_CATEGORIES, p2_b.size())):
			if typeof(p2_b[i]) == TYPE_DICTIONARY:
				p2_board[i]["is_selected"] = bool(p2_b[i].get("is_selected", false))
				p2_board[i]["score"] = int(p2_b[i].get("score", 0))

	is_round_played = bool(g_data.get("is_round_done", false))
	var rolled_times = int(g_data.get("rolled_dice_times", 1))
	remaining_rolls = clampi(3 - rolled_times, 0, 2)

	var d_arr = g_data.get("current_dices", [])
	if typeof(d_arr) == TYPE_ARRAY and not d_arr.is_empty():
		current_dices.clear()
		for v in d_arr:
			current_dices.append(clampi(int(v), 1, 6))
		while current_dices.size() < NUM_DICE:
			current_dices.append(1)

	var scores = g_data.get("scores", [0, 0])
	if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:
		var hud = get_tree().root.find_child("BaseGameHUD", true, false)
		if hud and hud.has_method("update_scores"):
			hud.update_scores(int(scores[0]), int(scores[1]))

	_recalculate_all_preview_scores()
	if not is_round_played:
		_select_first_empty_index()
	_refresh_visuals()

func reset_board() -> void:
	_init_board_arrays()
	current_dices = [1, 2, 3, 4, 5]
	held_dice_indices.clear()
	equipped_index = 0
	remaining_rolls = 2
	is_round_played = false
	is_rolling_dice = false
	_recalculate_all_preview_scores()
	_refresh_visuals()

func cleanup_board() -> void:
	is_rolling_dice = false
	held_dice_indices.clear()
