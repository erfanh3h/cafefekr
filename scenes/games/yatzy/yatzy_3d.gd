class_name Yatzy3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# Yatzy (یاتزی) 3D Board Implementation — Cafe Fekr
#
# Rectangular Portrait 3D Arena (1.06m x 1.68m) featuring:
#   1. Sleek Rectangular Carved Walnut, Brass & Obsidian Board proportioned
#      for Cafe Fekr's portrait table camera.
#   2. 3D Sculpted Category Cards (خانه امتیاز) with internal brass divider:
#      - Right compartment: 3D miniature sculpture on golden pedestal
#        (beveled 3D mini-dice for 1..6, 3D gem clusters/crown for 6..11).
#      - Left compartment: Cleanly fitted Persian category name that never
#        overflows its card frame.
#   3. Precision-Molded 3D Luxury Dice with flush enamel pips on all 6 faces
#      and a framed 3D numeral plaque below each die well.
#   4. Exact Server Protocol:
#      - Roll_Dice: {"selected_indexes": [0..4]}
#      - Select_Peace: {"index": 0..11}
# ==============================================================================

# --- Camera Tuning for Rectangular Portrait Board (1.06m x 1.68m) ---
@export var camera_distance: float = 3.28
@export var camera_pitch: float = -1.14

# --- Rectangular Board Geometry Constants ---
const BOARD_W: float = 1.06
const BOARD_L: float = 1.68
const BOARD_H: float = 0.030

const NUM_CATEGORIES: int = 12
const NUM_DICE: int = 5
const DIE_SIZE: float = 0.086

const FA_DIGITS = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const CATEGORY_NAMES_FA: Array[String] = [
	"یک‌ها",
	"دوها",
	"سه‌ها",
	"چهارها",
	"پنج‌ها",
	"شش‌ها",
	"سه‌تایی",
	"چهارتایی",
	"شانس",
	"فول‌هاوس",
	"ردیف بزرگ",
	"یاتزی",
]

const CATEGORY_GUIDES_FA: Array[String] = [
	"یک‌ها: مجموع تاس‌هایی که عدد ۱ دارند (۱ تا ۵ امتیاز)",
	"دوها: مجموع تاس‌هایی که عدد ۲ دارند (۲ تا ۱۰ امتیاز)",
	"سه‌ها: مجموع تاس‌هایی که عدد ۳ دارند (۳ تا ۱۵ امتیاز)",
	"چهارها: مجموع تاس‌هایی که عدد ۴ دارند (۴ تا ۲۰ امتیاز)",
	"پنج‌ها: مجموع تاس‌هایی که عدد ۵ دارند (۵ تا ۲۵ امتیاز)",
	"شش‌ها: مجموع تاس‌هایی که عدد ۶ دارند (۶ تا ۳۰ امتیاز)",
	"سه‌تایی: حداقل ۳ تاس هم‌عدد — مجموع هر ۵ تاس",
	"چهارتایی: حداقل ۴ تاس هم‌عدد — مجموع هر ۵ تاس",
	"شانس: مجموع تمام ۵ تاس بدون هیچ شرطی",
	"فول‌هاوس: ۳ تاس از یک عدد + ۲ تاس از عدد دیگر (۲۵ امتیاز)",
	"ردیف بزرگ: ۵ عدد متوالی ۱ تا ۵ یا ۲ تا ۶ (۴۰ امتیاز)",
	"یاتزی: هر ۵ تاس کاملاً هم‌عدد باشند (۵۰ امتیاز طلایی!)",
]

# --- Match & Turn State ---
var current_dices: Array[int] = [1, 2, 3, 4, 5]
var held_dice_indices: Array[int] = []
var remaining_rolls: int = 2
var equipped_index: int = 0
var is_round_played: bool = false
var is_rolling_dice: bool = false

# Each entry: {"score": 0, "calc": 0, "is_selected": false, "last_played": false}
var p1_board: Array[Dictionary] = []
var p2_board: Array[Dictionary] = []

# --- Materials ---
var mat_wood_base: StandardMaterial3D
var mat_wood_rim: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_obsidian_bed: StandardMaterial3D
var mat_felt_tray: StandardMaterial3D
var mat_felt_well: StandardMaterial3D

var mat_cat_card_bg: StandardMaterial3D
var mat_cell_idle_my: StandardMaterial3D
var mat_cell_idle_opp: StandardMaterial3D
var mat_cell_equipped: StandardMaterial3D
var mat_cell_p1_locked: StandardMaterial3D
var mat_cell_p2_locked: StandardMaterial3D
var mat_cell_last_ring: StandardMaterial3D

var mat_die_ivory: StandardMaterial3D
var mat_die_chamfer: StandardMaterial3D
var mat_die_held_ivory: StandardMaterial3D
var mat_die_held_chamfer: StandardMaterial3D
var mat_pip_dark: StandardMaterial3D
var mat_pip_red: StandardMaterial3D
var mat_die_lock_ring: StandardMaterial3D
var mat_die_badge_idle: StandardMaterial3D
var mat_die_badge_held: StandardMaterial3D

var mat_emblem_ruby: StandardMaterial3D
var mat_emblem_sapphire: StandardMaterial3D
var mat_emblem_emerald: StandardMaterial3D
var mat_emblem_amethyst: StandardMaterial3D
var mat_emblem_amber: StandardMaterial3D

var mat_btn_roll_active: StandardMaterial3D
var mat_btn_roll_disabled: StandardMaterial3D
var mat_btn_submit_active: StandardMaterial3D
var mat_btn_submit_disabled: StandardMaterial3D

var _game_font: Font = null

# --- Scene Node References ---
var _cat_row_nodes: Array[Dictionary] = []
var _dice_nodes: Array[Dictionary] = []
var _btn_roll_node: Dictionary = {}
var _btn_submit_node: Dictionary = {}
var _status_lbl_3d: Label3D = null
var _col_header_labels: Array[Label3D] = []

var _last_interaction_msec: int = 0

func _init() -> void:
	game_type = GameTypes.YATZY

func _ready() -> void:
	game_type = GameTypes.YATZY
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		_game_font = load("res://assets/fonts/hekayat.ttf")
	init_board()
	super._ready()
	_hide_hands_for_yatzy()

func _hide_hands_for_yatzy() -> void:
	var tbl = get_tree().get_first_node_in_group("cafe_table")
	if tbl:
		if "player_hand" in tbl and is_instance_valid(tbl.player_hand):
			tbl.player_hand.visible = false
		if "enemy_hand" in tbl and is_instance_valid(tbl.enemy_hand):
			tbl.enemy_hand.visible = false

func is_interacting_with_piece() -> bool:
	return (Time.get_ticks_msec() - _last_interaction_msec) < 280

func _mark_interaction() -> void:
	_last_interaction_msec = Time.get_ticks_msec()

# ==============================================================================
# PERSIAN DIGITS HELPER
# ==============================================================================

func _fa_digits(val: Variant) -> String:
	var s := str(val)
	var out := ""
	for i in range(s.length()):
		var ch := s.unicode_at(i)
		if ch >= 48 and ch <= 57:
			out += FA_DIGITS[ch - 48]
		else:
			out += s[i]
	return out

# ==============================================================================
# INITIALIZATION & MATERIALS
# ==============================================================================

func init_board() -> void:
	_init_board_arrays()
	_init_materials()
	_build_3d_arena()
	_recalculate_preview_scores()
	_refresh_visuals()

func _init_board_arrays() -> void:
	p1_board.clear()
	p2_board.clear()
	for i in range(NUM_CATEGORIES):
		p1_board.append({
			"score": 0,
			"calc": 0,
			"is_selected": false,
			"last_played": false,
		})
		p2_board.append({
			"score": 0,
			"calc": 0,
			"is_selected": false,
			"last_played": false,
		})
	current_dices = [1, 2, 3, 4, 5]
	held_dice_indices.clear()
	remaining_rolls = 2
	equipped_index = 0
	is_round_played = false
	is_rolling_dice = false

func _init_materials() -> void:
	mat_wood_base = StandardMaterial3D.new()
	mat_wood_base.albedo_color = Color(0.18, 0.10, 0.05)
	mat_wood_base.roughness = 0.34
	mat_wood_base.metallic = 0.05
	mat_wood_base.clearcoat_enabled = true
	mat_wood_base.clearcoat = 0.45

	mat_wood_rim = StandardMaterial3D.new()
	mat_wood_rim.albedo_color = Color(0.28, 0.14, 0.07)
	mat_wood_rim.roughness = 0.30
	mat_wood_rim.metallic = 0.06
	mat_wood_rim.clearcoat_enabled = true
	mat_wood_rim.clearcoat = 0.55

	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.92, 0.74, 0.26)
	mat_gold_trim.metallic = 0.88
	mat_gold_trim.roughness = 0.20

	mat_obsidian_bed = StandardMaterial3D.new()
	mat_obsidian_bed.albedo_color = Color(0.08, 0.09, 0.12)
	mat_obsidian_bed.roughness = 0.26
	mat_obsidian_bed.metallic = 0.18

	mat_felt_tray = StandardMaterial3D.new()
	mat_felt_tray.albedo_color = Color(0.06, 0.25, 0.16)
	mat_felt_tray.roughness = 0.86
	mat_felt_tray.metallic = 0.0

	mat_felt_well = StandardMaterial3D.new()
	mat_felt_well.albedo_color = Color(0.04, 0.16, 0.11)
	mat_felt_well.roughness = 0.90

	mat_cat_card_bg = StandardMaterial3D.new()
	mat_cat_card_bg.albedo_color = Color(0.15, 0.12, 0.10)
	mat_cat_card_bg.roughness = 0.34
	mat_cat_card_bg.metallic = 0.12

	# Scorecard Cells
	mat_cell_idle_my = StandardMaterial3D.new()
	mat_cell_idle_my.albedo_color = Color(0.15, 0.17, 0.23)
	mat_cell_idle_my.roughness = 0.36
	mat_cell_idle_my.metallic = 0.12

	mat_cell_idle_opp = StandardMaterial3D.new()
	mat_cell_idle_opp.albedo_color = Color(0.11, 0.12, 0.16)
	mat_cell_idle_opp.roughness = 0.45
	mat_cell_idle_opp.metallic = 0.08

	mat_cell_equipped = StandardMaterial3D.new()
	mat_cell_equipped.albedo_color = Color(0.88, 0.66, 0.14)
	mat_cell_equipped.roughness = 0.22
	mat_cell_equipped.metallic = 0.45
	mat_cell_equipped.emission_enabled = true
	mat_cell_equipped.emission = Color(0.95, 0.72, 0.18)
	mat_cell_equipped.emission_energy_multiplier = 0.55

	mat_cell_p1_locked = StandardMaterial3D.new()
	mat_cell_p1_locked.albedo_color = Color(0.68, 0.14, 0.18)
	mat_cell_p1_locked.roughness = 0.28
	mat_cell_p1_locked.metallic = 0.20

	mat_cell_p2_locked = StandardMaterial3D.new()
	mat_cell_p2_locked.albedo_color = Color(0.14, 0.38, 0.74)
	mat_cell_p2_locked.roughness = 0.28
	mat_cell_p2_locked.metallic = 0.20

	mat_cell_last_ring = StandardMaterial3D.new()
	mat_cell_last_ring.albedo_color = Color(1.0, 0.86, 0.28)
	mat_cell_last_ring.metallic = 0.85
	mat_cell_last_ring.roughness = 0.18
	mat_cell_last_ring.emission_enabled = true
	mat_cell_last_ring.emission = Color(1.0, 0.80, 0.20)
	mat_cell_last_ring.emission_energy_multiplier = 0.80

	# Luxury 3D Dice Materials
	mat_die_ivory = StandardMaterial3D.new()
	mat_die_ivory.albedo_color = Color(0.99, 0.97, 0.93)
	mat_die_ivory.roughness = 0.12
	mat_die_ivory.metallic = 0.02
	mat_die_ivory.clearcoat_enabled = true
	mat_die_ivory.clearcoat = 0.90
	mat_die_ivory.clearcoat_roughness = 0.06

	mat_die_chamfer = StandardMaterial3D.new()
	mat_die_chamfer.albedo_color = Color(0.94, 0.90, 0.80)
	mat_die_chamfer.roughness = 0.18
	mat_die_chamfer.metallic = 0.10
	mat_die_chamfer.clearcoat_enabled = true
	mat_die_chamfer.clearcoat = 0.75

	mat_die_held_ivory = StandardMaterial3D.new()
	mat_die_held_ivory.albedo_color = Color(1.0, 0.97, 0.86)
	mat_die_held_ivory.roughness = 0.10
	mat_die_held_ivory.metallic = 0.08
	mat_die_held_ivory.clearcoat_enabled = true
	mat_die_held_ivory.clearcoat = 0.95
	mat_die_held_ivory.emission_enabled = true
	mat_die_held_ivory.emission = Color(0.95, 0.75, 0.20)
	mat_die_held_ivory.emission_energy_multiplier = 0.18

	mat_die_held_chamfer = StandardMaterial3D.new()
	mat_die_held_chamfer.albedo_color = Color(0.98, 0.78, 0.22)
	mat_die_held_chamfer.metallic = 0.82
	mat_die_held_chamfer.roughness = 0.16
	mat_die_held_chamfer.emission_enabled = true
	mat_die_held_chamfer.emission = Color(0.96, 0.74, 0.16)
	mat_die_held_chamfer.emission_energy_multiplier = 0.40

	mat_pip_dark = StandardMaterial3D.new()
	mat_pip_dark.albedo_color = Color(0.05, 0.06, 0.10)
	mat_pip_dark.roughness = 0.14
	mat_pip_dark.metallic = 0.20
	mat_pip_dark.clearcoat_enabled = true
	mat_pip_dark.clearcoat = 0.85

	mat_pip_red = StandardMaterial3D.new()
	mat_pip_red.albedo_color = Color(0.88, 0.10, 0.15)
	mat_pip_red.roughness = 0.14
	mat_pip_red.metallic = 0.18
	mat_pip_red.clearcoat_enabled = true
	mat_pip_red.clearcoat = 0.90
	mat_pip_red.emission_enabled = true
	mat_pip_red.emission = Color(0.75, 0.08, 0.12)
	mat_pip_red.emission_energy_multiplier = 0.20

	mat_die_lock_ring = StandardMaterial3D.new()
	mat_die_lock_ring.albedo_color = Color(1.0, 0.82, 0.20)
	mat_die_lock_ring.metallic = 0.90
	mat_die_lock_ring.roughness = 0.16
	mat_die_lock_ring.emission_enabled = true
	mat_die_lock_ring.emission = Color(1.0, 0.76, 0.14)
	mat_die_lock_ring.emission_energy_multiplier = 0.75

	mat_die_badge_idle = StandardMaterial3D.new()
	mat_die_badge_idle.albedo_color = Color(0.12, 0.15, 0.20)
	mat_die_badge_idle.roughness = 0.32
	mat_die_badge_idle.metallic = 0.20

	mat_die_badge_held = StandardMaterial3D.new()
	mat_die_badge_held.albedo_color = Color(0.76, 0.54, 0.10)
	mat_die_badge_held.roughness = 0.22
	mat_die_badge_held.metallic = 0.55
	mat_die_badge_held.emission_enabled = true
	mat_die_badge_held.emission = Color(0.95, 0.70, 0.15)
	mat_die_badge_held.emission_energy_multiplier = 0.45

	# 3D Category Emblem Gemstone Materials
	mat_emblem_ruby = StandardMaterial3D.new()
	mat_emblem_ruby.albedo_color = Color(0.92, 0.16, 0.22)
	mat_emblem_ruby.roughness = 0.16
	mat_emblem_ruby.metallic = 0.20
	mat_emblem_ruby.clearcoat_enabled = true
	mat_emblem_ruby.clearcoat = 0.85

	mat_emblem_sapphire = StandardMaterial3D.new()
	mat_emblem_sapphire.albedo_color = Color(0.18, 0.52, 0.96)
	mat_emblem_sapphire.roughness = 0.16
	mat_emblem_sapphire.metallic = 0.20
	mat_emblem_sapphire.clearcoat_enabled = true
	mat_emblem_sapphire.clearcoat = 0.85

	mat_emblem_emerald = StandardMaterial3D.new()
	mat_emblem_emerald.albedo_color = Color(0.14, 0.82, 0.42)
	mat_emblem_emerald.roughness = 0.16
	mat_emblem_emerald.metallic = 0.20
	mat_emblem_emerald.clearcoat_enabled = true
	mat_emblem_emerald.clearcoat = 0.85

	mat_emblem_amethyst = StandardMaterial3D.new()
	mat_emblem_amethyst.albedo_color = Color(0.72, 0.28, 0.94)
	mat_emblem_amethyst.roughness = 0.16
	mat_emblem_amethyst.metallic = 0.20
	mat_emblem_amethyst.clearcoat_enabled = true
	mat_emblem_amethyst.clearcoat = 0.85

	mat_emblem_amber = StandardMaterial3D.new()
	mat_emblem_amber.albedo_color = Color(0.98, 0.64, 0.12)
	mat_emblem_amber.roughness = 0.16
	mat_emblem_amber.metallic = 0.25
	mat_emblem_amber.clearcoat_enabled = true
	mat_emblem_amber.clearcoat = 0.85

	# Action Buttons
	mat_btn_roll_active = StandardMaterial3D.new()
	mat_btn_roll_active.albedo_color = Color(0.14, 0.44, 0.86)
	mat_btn_roll_active.roughness = 0.24
	mat_btn_roll_active.metallic = 0.20
	mat_btn_roll_active.emission_enabled = true
	mat_btn_roll_active.emission = Color(0.10, 0.32, 0.68)
	mat_btn_roll_active.emission_energy_multiplier = 0.40

	mat_btn_roll_disabled = StandardMaterial3D.new()
	mat_btn_roll_disabled.albedo_color = Color(0.22, 0.24, 0.28)
	mat_btn_roll_disabled.roughness = 0.55

	mat_btn_submit_active = StandardMaterial3D.new()
	mat_btn_submit_active.albedo_color = Color(0.14, 0.66, 0.34)
	mat_btn_submit_active.roughness = 0.24
	mat_btn_submit_active.metallic = 0.20
	mat_btn_submit_active.emission_enabled = true
	mat_btn_submit_active.emission = Color(0.08, 0.48, 0.22)
	mat_btn_submit_active.emission_energy_multiplier = 0.45

	mat_btn_submit_disabled = StandardMaterial3D.new()
	mat_btn_submit_disabled.albedo_color = Color(0.22, 0.24, 0.28)
	mat_btn_submit_disabled.roughness = 0.55

# ==============================================================================
# 3D RECTANGULAR ARENA CONSTRUCTION (1.06m x 1.68m)
# ==============================================================================

func _build_3d_arena() -> void:
	# 1. Outer Carved Walnut Rectangular Plinth (1.06m wide x 1.68m long)
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(BOARD_W, BOARD_H, BOARD_L)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, BOARD_H * 0.5, 0)
	add_child(plinth)

	# Raised Mahogany Outer Frame Border
	for rim_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.006, -BOARD_L * 0.5 + 0.018), "size": Vector3(BOARD_W, 0.012, 0.036)},
		{"pos": Vector3(0, BOARD_H + 0.006, BOARD_L * 0.5 - 0.018), "size": Vector3(BOARD_W, 0.012, 0.036)},
		{"pos": Vector3(-BOARD_W * 0.5 + 0.018, BOARD_H + 0.006, 0), "size": Vector3(0.036, 0.012, BOARD_L - 0.072)},
		{"pos": Vector3(BOARD_W * 0.5 - 0.018, BOARD_H + 0.006, 0), "size": Vector3(0.036, 0.012, BOARD_L - 0.072)},
	]:
		var r_inst = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = rim_cfg["size"]
		r_box.material = mat_wood_rim
		r_inst.mesh = r_box
		r_inst.position = rim_cfg["pos"]
		add_child(r_inst)

	# Inner Gold Filigree Inlay Frame
	for border_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.013, -BOARD_L * 0.5 + 0.028), "size": Vector3(BOARD_W - 0.04, 0.004, 0.010)},
		{"pos": Vector3(0, BOARD_H + 0.013, BOARD_L * 0.5 - 0.028), "size": Vector3(BOARD_W - 0.04, 0.004, 0.010)},
		{"pos": Vector3(-BOARD_W * 0.5 + 0.028, BOARD_H + 0.013, 0), "size": Vector3(0.010, 0.004, BOARD_L - 0.056)},
		{"pos": Vector3(BOARD_W * 0.5 - 0.028, BOARD_H + 0.013, 0), "size": Vector3(0.010, 0.004, BOARD_L - 0.056)},
	]:
		var b_inst = MeshInstance3D.new()
		var b_box = BoxMesh.new()
		b_box.size = border_cfg["size"]
		b_box.material = mat_gold_trim
		b_inst.mesh = b_box
		b_inst.position = border_cfg["pos"]
		add_child(b_inst)

	# 4 Brass Corner Medallions
	for cx in [-BOARD_W * 0.5 + 0.028, BOARD_W * 0.5 - 0.028]:
		for cz in [-BOARD_L * 0.5 + 0.028, BOARD_L * 0.5 - 0.028]:
			var med = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.022
			cyl.bottom_radius = 0.026
			cyl.height = 0.016
			cyl.material = mat_gold_trim
			med.mesh = cyl
			med.position = Vector3(cx, BOARD_H + 0.008, cz)
			add_child(med)

	# 2. Upper Obsidian Scorecard Bed (Z = -0.79 to +0.18, width = 0.99m, length = 0.97m)
	var score_bed = MeshInstance3D.new()
	var sb_mesh = BoxMesh.new()
	sb_mesh.size = Vector3(0.99, 0.006, 0.97)
	sb_mesh.material = mat_obsidian_bed
	score_bed.mesh = sb_mesh
	score_bed.position = Vector3(0, BOARD_H + 0.003, -0.305)
	add_child(score_bed)

	# Center Brass Divider between Left Column (0..5) and Right Column (6..11)
	var col_div = MeshInstance3D.new()
	var cd_mesh = BoxMesh.new()
	cd_mesh.size = Vector3(0.010, 0.012, 0.95)
	cd_mesh.material = mat_gold_trim
	col_div.mesh = cd_mesh
	col_div.position = Vector3(0, BOARD_H + 0.006, -0.305)
	add_child(col_div)

	# Column Headers for Both Columns
	_col_header_labels.clear()
	for col_idx in range(2):
		var col_x = -0.248 if col_idx == 0 else 0.248
		var hdr_z = -0.742
		var lbl_p2 = _create_3d_label("🔵 حریف", 24, Color(0.52, 0.84, 1.0))
		lbl_p2.position = Vector3(col_x - 0.180, BOARD_H + 0.014, hdr_z)
		add_child(lbl_p2)
		_col_header_labels.append(lbl_p2)

		var lbl_p1 = _create_3d_label("🔴 شما", 24, Color(1.0, 0.52, 0.56))
		lbl_p1.position = Vector3(col_x - 0.082, BOARD_H + 0.014, hdr_z)
		add_child(lbl_p1)
		_col_header_labels.append(lbl_p1)

		var lbl_cat = _create_3d_label("خانه امتیاز", 24, Color(0.98, 0.88, 0.58))
		lbl_cat.position = Vector3(col_x + 0.100, BOARD_H + 0.014, hdr_z)
		add_child(lbl_cat)

	# Build the 12 Category Rows (0..5 in Left Column, 6..11 in Right Column)
	_cat_row_nodes.clear()
	for idx in range(NUM_CATEGORIES):
		var col_idx = 0 if idx < 6 else 1
		var row_in_col = idx % 6
		var col_center_x = -0.248 if col_idx == 0 else 0.248
		var row_z = -0.635 + float(row_in_col) * 0.146
		var row_dict = _build_category_row(idx, col_center_x, row_z)
		_cat_row_nodes.append(row_dict)

	# 3. Recessed Emerald Baize 3D Dice Rolling Arena (Z = +0.21 to +0.58)
	var tray_center_z: float = 0.395
	var tray_w: float = 0.96
	var tray_l: float = 0.36

	var felt_bed = MeshInstance3D.new()
	var fb_mesh = BoxMesh.new()
	fb_mesh.size = Vector3(tray_w, 0.008, tray_l)
	fb_mesh.material = mat_felt_tray
	felt_bed.mesh = fb_mesh
	felt_bed.position = Vector3(0, BOARD_H + 0.004, tray_center_z)
	add_child(felt_bed)

	# Carved Mahogany & Brass Walls around the Dice Tray
	for wall_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.016, tray_center_z - tray_l * 0.5), "size": Vector3(tray_w + 0.02, 0.026, 0.018)},
		{"pos": Vector3(0, BOARD_H + 0.016, tray_center_z + tray_l * 0.5), "size": Vector3(tray_w + 0.02, 0.026, 0.018)},
		{"pos": Vector3(-tray_w * 0.5, BOARD_H + 0.016, tray_center_z), "size": Vector3(0.018, 0.026, tray_l)},
		{"pos": Vector3(tray_w * 0.5, BOARD_H + 0.016, tray_center_z), "size": Vector3(0.018, 0.026, tray_l)},
	]:
		var w_inst = MeshInstance3D.new()
		var w_box = BoxMesh.new()
		w_box.size = wall_cfg["size"]
		w_box.material = mat_wood_rim
		w_inst.mesh = w_box
		w_inst.position = wall_cfg["pos"]
		add_child(w_inst)

		var trim_inst = MeshInstance3D.new()
		var trim_box = BoxMesh.new()
		trim_box.size = Vector3(wall_cfg["size"].x * 0.98, 0.004, wall_cfg["size"].z * 0.65)
		trim_box.material = mat_gold_trim
		trim_inst.mesh = trim_box
		trim_inst.position = wall_cfg["pos"] + Vector3(0, 0.014, 0)
		add_child(trim_inst)

	# Status / Guidance Label inside the Top Rim of the Dice Tray
	_status_lbl_3d = _create_3d_label("تاس‌ها را لمس کنید تا برای پرتاب بعدی قفل شوند", 23, Color(0.98, 0.92, 0.72))
	_status_lbl_3d.position = Vector3(0, BOARD_H + 0.016, 0.252)
	add_child(_status_lbl_3d)

	# Build the 5 Physical Luxury 3D Dice inside the Tray
	_dice_nodes.clear()
	var dice_x_positions = [-0.35, -0.175, 0.0, 0.175, 0.35]
	for d_idx in range(NUM_DICE):
		var d_node = _build_single_3d_die(d_idx, Vector3(dice_x_positions[d_idx], BOARD_H + 0.010, 0.376))
		_dice_nodes.append(d_node)

	# 4. Lower 3D Tactile Action Buttons Dock (Z = +0.695)
	_btn_roll_node = _build_3d_action_button(
		"BtnRollDice",
		Vector3(0.242, BOARD_H + 0.016, 0.695),
		Vector3(0.45, 0.032, 0.132),
		"🎲 تاس بریز (۲)",
		mat_btn_roll_active
	)
	_btn_submit_node = _build_3d_action_button(
		"BtnSubmitScore",
		Vector3(-0.242, BOARD_H + 0.016, 0.695),
		Vector3(0.45, 0.032, 0.132),
		"✅ ثبت امتیاز",
		mat_btn_submit_active
	)

# ==============================================================================
# 3D SCULPTED CATEGORY ROW (خانه امتیاز) BUILDER — NO TEXT OVERFLOW
# ==============================================================================

func _build_category_row(cat_idx: int, col_x: float, row_z: float) -> Dictionary:
	var row_root = Node3D.new()
	row_root.name = "CategoryRow_%d" % cat_idx
	row_root.position = Vector3(col_x, BOARD_H + 0.008, row_z)
	add_child(row_root)

	# 1. Opponent / Player 2 Score Plaque (x = -0.180, width = 0.088m)
	var p2_cell = _build_score_cell_plaque(row_root, Vector3(-0.180, 0, 0), 2, cat_idx)

	# 2. My / Player 1 Score Plaque (x = -0.082, width = 0.088m)
	var p1_cell = _build_score_cell_plaque(row_root, Vector3(-0.082, 0, 0), 1, cat_idx)

	# 3. Wide 3D Category Card (خانه امتیاز) on the right side of the row (x = +0.100, width = 0.244m)
	var cat_card = Node3D.new()
	cat_card.position = Vector3(0.100, 0, 0)
	row_root.add_child(cat_card)

	# Category Card Outer Gold Rim (0.244m wide x 0.122m tall)
	var card_rim = MeshInstance3D.new()
	var cr_box = BoxMesh.new()
	cr_box.size = Vector3(0.244, 0.008, 0.122)
	cr_box.material = mat_gold_trim
	card_rim.mesh = cr_box
	card_rim.position = Vector3(0, 0.002, 0)
	cat_card.add_child(card_rim)

	# Category Card Dark Walnut-Obsidian Inner Face (0.236m wide x 0.114m tall)
	var card_bg = MeshInstance3D.new()
	var cb_box = BoxMesh.new()
	cb_box.size = Vector3(0.236, 0.012, 0.114)
	cb_box.material = mat_cat_card_bg
	card_bg.mesh = cb_box
	card_bg.position = Vector3(0, 0.005, 0)
	cat_card.add_child(card_bg)

	# Internal Vertical Brass Divider separating Text Compartment (-0.118..+0.042) & 3D Emblem (+0.042..+0.118)
	var inner_div = MeshInstance3D.new()
	var id_box = BoxMesh.new()
	id_box.size = Vector3(0.004, 0.014, 0.110)
	id_box.material = mat_gold_trim
	inner_div.mesh = id_box
	inner_div.position = Vector3(0.042, 0.006, 0)
	cat_card.add_child(inner_div)

	# 3D Sculpted Category Emblem in the right compartment (x = +0.080)
	var emblem_root = Node3D.new()
	emblem_root.position = Vector3(0.080, 0.012, 0)
	cat_card.add_child(emblem_root)
	_build_3d_category_emblem(emblem_root, cat_idx)

	# Cleanly Proportioned Persian Category Name centered in the 0.160m left compartment (x = -0.038)
	var cat_name_str: String = CATEGORY_NAMES_FA[cat_idx]
	var cat_font_size: int = 21 if cat_name_str.length() >= 7 else 24
	var cat_lbl = _create_3d_label(cat_name_str, cat_font_size, Color(0.98, 0.94, 0.84))
	cat_lbl.position = Vector3(-0.038, 0.016, 0.0)
	cat_card.add_child(cat_lbl)

	# Clickable Area3D on the 3D Emblem (shows Persian scoring guide hint)
	var guide_area = Area3D.new()
	guide_area.name = "GuideArea_%d" % cat_idx
	guide_area.set_meta("hit_type", "guide")
	guide_area.set_meta("cat_index", cat_idx)
	var guide_col = CollisionShape3D.new()
	var guide_shape = BoxShape3D.new()
	guide_shape.size = Vector3(0.076, 0.04, 0.120)
	guide_col.shape = guide_shape
	guide_area.add_child(guide_col)
	guide_area.position = Vector3(0.180, 0.015, 0)
	row_root.add_child(guide_area)

	# Clickable Area3D covering Score Plaques & Category Name to equip this category
	var row_area = Area3D.new()
	row_area.name = "SelectArea_%d" % cat_idx
	row_area.set_meta("hit_type", "category")
	row_area.set_meta("cat_index", cat_idx)
	var row_col = CollisionShape3D.new()
	var row_shape = BoxShape3D.new()
	row_shape.size = Vector3(0.365, 0.04, 0.124)
	row_col.shape = row_shape
	row_area.add_child(row_col)
	row_area.position = Vector3(-0.048, 0.015, 0)
	row_root.add_child(row_area)

	return {
		"root": row_root,
		"p1": p1_cell,
		"p2": p2_cell,
		"cat_label": cat_lbl,
	}

func _build_3d_category_emblem(parent: Node3D, cat_idx: int) -> void:
	# Golden Circular Medallion Pedestal beneath every 3D category sculpture
	var ped = MeshInstance3D.new()
	var ped_cyl = CylinderMesh.new()
	ped_cyl.top_radius = 0.028
	ped_cyl.bottom_radius = 0.031
	ped_cyl.height = 0.005
	ped_cyl.material = mat_gold_trim
	ped.mesh = ped_cyl
	ped.position = Vector3(0, 0.0025, 0)
	parent.add_child(ped)

	if cat_idx >= 0 and cat_idx <= 5:
		# Categories 0..5 (Faces 1..6): 3D Miniature Beveled Die Tile with 3D Pips
		var face_num: int = cat_idx + 1
		var tile_chamfer = MeshInstance3D.new()
		var tc_box = BoxMesh.new()
		tc_box.size = Vector3(0.044, 0.010, 0.044)
		tc_box.material = mat_die_chamfer
		tile_chamfer.mesh = tc_box
		tile_chamfer.position = Vector3(0, 0.008, 0)
		parent.add_child(tile_chamfer)

		var tile_top = MeshInstance3D.new()
		var tt_box = BoxMesh.new()
		tt_box.size = Vector3(0.039, 0.012, 0.039)
		tt_box.material = mat_die_ivory
		tile_top.mesh = tt_box
		tile_top.position = Vector3(0, 0.009, 0)
		parent.add_child(tile_top)

		var pip_mats = [
			mat_pip_red,
			mat_emblem_sapphire,
			mat_emblem_emerald,
			mat_emblem_amethyst,
			mat_emblem_amber,
			mat_emblem_ruby,
		]
		var p_mat = pip_mats[cat_idx]
		var o: float = 0.011
		var pip_coords: Array = []
		match face_num:
			1: pip_coords = [Vector2(0, 0)]
			2: pip_coords = [Vector2(-o, -o), Vector2(o, o)]
			3: pip_coords = [Vector2(-o, -o), Vector2(0, 0), Vector2(o, o)]
			4: pip_coords = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)]
			5: pip_coords = [Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)]
			6: pip_coords = [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)]

		for p2 in pip_coords:
			var pip = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			var r_val = 0.0055 if face_num == 1 else 0.0038
			cyl.top_radius = r_val
			cyl.bottom_radius = r_val
			cyl.height = 0.003
			cyl.material = p_mat
			pip.mesh = cyl
			pip.position = Vector3(p2.x, 0.016, p2.y)
			parent.add_child(pip)

	elif cat_idx == 6:
		# سه‌تایی (Three of a Kind): 3D Triangle Cluster of 3 Sapphire Mini-Cubes
		var offsets_3 = [Vector3(0, 0.011, -0.011), Vector3(-0.012, 0.011, 0.010), Vector3(0.012, 0.011, 0.010)]
		for pos in offsets_3:
			var c = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.017, 0.014, 0.017)
			bm.material = mat_emblem_sapphire
			c.mesh = bm
			c.position = pos
			parent.add_child(c)

	elif cat_idx == 7:
		# چهارتایی (Four of a Kind): 2x2 3D Cluster of 4 Amethyst Mini-Cubes
		var offsets_4 = [
			Vector3(-0.011, 0.011, -0.011), Vector3(0.011, 0.011, -0.011),
			Vector3(-0.011, 0.011, 0.011), Vector3(0.011, 0.011, 0.011)
		]
		for pos in offsets_4:
			var c = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.016, 0.014, 0.016)
			bm.material = mat_emblem_amethyst
			c.mesh = bm
			c.position = pos
			parent.add_child(c)

	elif cat_idx == 8:
		# شانس (Chance): 3D Faceted Emerald Crystal
		var gem = MeshInstance3D.new()
		var gm = SphereMesh.new()
		gm.radius = 0.017
		gm.height = 0.022
		gm.radial_segments = 6
		gm.rings = 3
		gm.material = mat_emblem_emerald
		gem.mesh = gm
		gem.position = Vector3(0, 0.012, 0)
		parent.add_child(gem)

	elif cat_idx == 9:
		# فول‌هاوس (Full House 3+2): 3 Ruby Cubes + 2 Sapphire Cubes
		for i in range(3):
			var c3 = MeshInstance3D.new()
			var b3 = BoxMesh.new()
			b3.size = Vector3(0.013, 0.013, 0.013)
			b3.material = mat_emblem_ruby
			c3.mesh = b3
			c3.position = Vector3(-0.014 + float(i) * 0.014, 0.011, -0.009)
			parent.add_child(c3)
		for j in range(2):
			var c2 = MeshInstance3D.new()
			var b2 = BoxMesh.new()
			b2.size = Vector3(0.014, 0.013, 0.014)
			b2.material = mat_emblem_sapphire
			c2.mesh = b2
			c2.position = Vector3(-0.008 + float(j) * 0.016, 0.011, 0.010)
			parent.add_child(c2)

	elif cat_idx == 10:
		# ردیف بزرگ (Large Straight 1..5): 5 Ascending 3D Golden Staircase Columns
		for step_i in range(5):
			var bar = MeshInstance3D.new()
			var bm = BoxMesh.new()
			var h_bar = 0.007 + float(step_i) * 0.003
			var z_len = 0.013 + float(step_i) * 0.005
			bm.size = Vector3(0.007, h_bar, z_len)
			bm.material = mat_emblem_amber if step_i % 2 == 0 else mat_gold_trim
			bar.mesh = bm
			bar.position = Vector3(-0.016 + float(step_i) * 0.008, 0.005 + h_bar * 0.5, 0.010 - z_len * 0.5)
			parent.add_child(bar)

	elif cat_idx == 11:
		# یاتزی (Yatzy 50 pts): 3D Royal Golden Crown with Ruby Center Gem
		var crown_base = MeshInstance3D.new()
		var cb_cyl = CylinderMesh.new()
		cb_cyl.top_radius = 0.020
		cb_cyl.bottom_radius = 0.017
		cb_cyl.height = 0.012
		cb_cyl.radial_segments = 8
		cb_cyl.material = mat_die_held_chamfer
		crown_base.mesh = cb_cyl
		crown_base.position = Vector3(0, 0.010, 0)
		parent.add_child(crown_base)

		var ruby_orb = MeshInstance3D.new()
		var ro_sph = SphereMesh.new()
		ro_sph.radius = 0.009
		ro_sph.height = 0.015
		ro_sph.material = mat_pip_red
		ruby_orb.mesh = ro_sph
		ruby_orb.position = Vector3(0, 0.018, 0)
		parent.add_child(ruby_orb)

func _build_score_cell_plaque(parent: Node3D, pos: Vector3, player_num: int, _cat_idx: int) -> Dictionary:
	var cell_root = Node3D.new()
	cell_root.position = pos
	parent.add_child(cell_root)

	# Selection / Last-Played Gold Border Frame
	var ring_inst = MeshInstance3D.new()
	var ring_box = BoxMesh.new()
	ring_box.size = Vector3(0.092, 0.010, 0.122)
	ring_box.material = mat_cell_last_ring
	ring_inst.mesh = ring_box
	ring_inst.position = Vector3(0, 0.004, 0)
	ring_inst.visible = false
	cell_root.add_child(ring_inst)

	# Main Cell Plaque Mesh
	var cell_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.084, 0.014, 0.114)
	box.material = mat_cell_idle_my if player_num == 1 else mat_cell_idle_opp
	cell_mesh.mesh = box
	cell_mesh.position = Vector3(0, 0.007, 0)
	cell_root.add_child(cell_mesh)

	# Clean Persian Score Value Label that fits comfortably inside the 0.084m plaque
	var score_lbl = _create_3d_label("۰", 28, Color(0.95, 0.92, 0.82))
	score_lbl.position = Vector3(0, 0.017, 0)
	cell_root.add_child(score_lbl)

	return {
		"root": cell_root,
		"mesh": cell_mesh,
		"ring": ring_inst,
		"label": score_lbl,
	}

# ==============================================================================
# PRECISION-MOLDED LUXURY 3D DICE & FRAMED NUMBER BADGES
# ==============================================================================

func _build_single_3d_die(die_idx: int, slot_pos: Vector3) -> Dictionary:
	var slot_root = Node3D.new()
	slot_root.name = "DieSlot_%d" % die_idx
	slot_root.position = slot_pos
	add_child(slot_root)

	# 1. Carved Velvet & Brass Dice Well Pedestal
	var well_rim = MeshInstance3D.new()
	var wr_cyl = CylinderMesh.new()
	wr_cyl.top_radius = 0.058
	wr_cyl.bottom_radius = 0.062
	wr_cyl.height = 0.005
	wr_cyl.material = mat_gold_trim
	well_rim.mesh = wr_cyl
	well_rim.position = Vector3(0, 0.0025, 0)
	slot_root.add_child(well_rim)

	var well_bed = MeshInstance3D.new()
	var wb_cyl = CylinderMesh.new()
	wb_cyl.top_radius = 0.053
	wb_cyl.bottom_radius = 0.053
	wb_cyl.height = 0.006
	wb_cyl.material = mat_felt_well
	well_bed.mesh = wb_cyl
	well_bed.position = Vector3(0, 0.0035, 0)
	slot_root.add_child(well_bed)

	# 2. Glowing Gold Lock Ring Pedestal (Visible when die is Held / Locked)
	var lock_ring = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.062
	cyl.bottom_radius = 0.066
	cyl.height = 0.012
	cyl.material = mat_die_lock_ring
	lock_ring.mesh = cyl
	lock_ring.position = Vector3(0, 0.006, 0)
	lock_ring.visible = false
	slot_root.add_child(lock_ring)

	# 3. 3D Die Pivot (Rotates so top face matches current_dices[die_idx])
	var die_pivot = Node3D.new()
	die_pivot.name = "DiePivot"
	die_pivot.position = Vector3(0, 0.050, 0)
	slot_root.add_child(die_pivot)

	# Smooth Chamfered Inner Core
	var chamfer_core = MeshInstance3D.new()
	var core_box = BoxMesh.new()
	core_box.size = Vector3(DIE_SIZE * 0.94, DIE_SIZE * 0.94, DIE_SIZE * 0.94)
	core_box.material = mat_die_chamfer
	chamfer_core.mesh = core_box
	die_pivot.add_child(chamfer_core)

	# 3 Overlapping Beveled Face Slabs (X, Y, Z) forming a rounded-edge casino die
	var face_meshes: Array[MeshInstance3D] = []
	for slab_size in [
		Vector3(DIE_SIZE, DIE_SIZE * 0.86, DIE_SIZE * 0.86),
		Vector3(DIE_SIZE * 0.86, DIE_SIZE, DIE_SIZE * 0.86),
		Vector3(DIE_SIZE * 0.86, DIE_SIZE * 0.86, DIE_SIZE),
	]:
		var slab_inst = MeshInstance3D.new()
		var slab_box = BoxMesh.new()
		slab_box.size = slab_size
		slab_box.material = mat_die_ivory
		slab_inst.mesh = slab_box
		die_pivot.add_child(slab_inst)
		face_meshes.append(slab_inst)

	# Precision-Spaced Flush Enamel Pips on all 6 faces
	_add_3d_die_pips(die_pivot, DIE_SIZE * 0.5)

	# 4. Framed 3D Brass & Obsidian Numeral Plaque in front of each die well
	var badge_rim = MeshInstance3D.new()
	var br_box = BoxMesh.new()
	br_box.size = Vector3(0.112, 0.006, 0.052)
	br_box.material = mat_gold_trim
	badge_rim.mesh = br_box
	badge_rim.position = Vector3(0, 0.004, 0.112)
	slot_root.add_child(badge_rim)

	var badge_cap = MeshInstance3D.new()
	var bc_box = BoxMesh.new()
	bc_box.size = Vector3(0.104, 0.009, 0.044)
	bc_box.material = mat_die_badge_idle
	badge_cap.mesh = bc_box
	badge_cap.position = Vector3(0, 0.006, 0.112)
	slot_root.add_child(badge_cap)

	var val_lbl = _create_3d_label("۱", 26, Color(1.0, 0.96, 0.86))
	val_lbl.position = Vector3(0, 0.013, 0.112)
	slot_root.add_child(val_lbl)

	# 5. Clickable Area3D for Holding / Unholding this Die
	var die_area = Area3D.new()
	die_area.name = "DieArea_%d" % die_idx
	die_area.set_meta("hit_type", "die")
	die_area.set_meta("die_index", die_idx)
	var die_col = CollisionShape3D.new()
	var die_shape = BoxShape3D.new()
	die_shape.size = Vector3(0.155, 0.14, 0.22)
	die_col.shape = die_shape
	die_area.add_child(die_col)
	die_area.position = Vector3(0, 0.05, 0.03)
	slot_root.add_child(die_area)

	return {
		"slot": slot_root,
		"pivot": die_pivot,
		"chamfer": chamfer_core,
		"slabs": face_meshes,
		"lock_ring": lock_ring,
		"badge_cap": badge_cap,
		"label": val_lbl,
	}

func _add_3d_die_pips(die_pivot: Node3D, half_s: float) -> void:
	var o: float = half_s * 0.54
	# Opposing faces sum to 7:
	# +Y = 1 (Ruby), -Y = 6, +Z = 2, -Z = 5, +X = 3, -X = 4 (Ruby)
	var face_configs = [
		# Face 1 (+Y)
		{"normal": Vector3.UP, "right": Vector3.RIGHT, "fwd": Vector3.BACK, "rot_deg": Vector3(0, 0, 0), "pips": [Vector2(0, 0)], "red": true, "big": true},
		# Face 6 (-Y)
		{"normal": Vector3.DOWN, "right": Vector3.RIGHT, "fwd": Vector3.FORWARD, "rot_deg": Vector3(0, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		# Face 2 (+Z)
		{"normal": Vector3.BACK, "right": Vector3.RIGHT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, o)
		], "red": false, "big": false},
		# Face 5 (-Z)
		{"normal": Vector3.FORWARD, "right": Vector3.LEFT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		# Face 3 (+X)
		{"normal": Vector3.RIGHT, "right": Vector3.FORWARD, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [
			Vector2(-o, -o), Vector2(0, 0), Vector2(o, o)
		], "red": false, "big": false},
		# Face 4 (-X)
		{"normal": Vector3.LEFT, "right": Vector3.BACK, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)
		], "red": true, "big": false},
	]

	for fc in face_configs:
		var n: Vector3 = fc["normal"]
		var r: Vector3 = fc["right"]
		var f: Vector3 = fc["fwd"]
		var rot_d: Vector3 = fc["rot_deg"]
		var is_red: bool = fc["red"]
		var is_big: bool = fc["big"]
		var rad: float = 0.0108 if is_big else 0.0068

		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = rad
			cyl.bottom_radius = rad
			cyl.height = 0.0022
			cyl.radial_segments = 18
			cyl.material = mat_pip_red if is_red else mat_pip_dark
			pip.mesh = cyl
			pip.rotation_degrees = rot_d
			pip.position = n * (half_s + 0.0005) + r * p2.x + f * p2.y
			die_pivot.add_child(pip)

func _get_die_target_rotation(val: int) -> Vector3:
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
	bz_box.size = btn_size + Vector3(0.018, -0.004, 0.018)
	bz_box.material = mat_gold_trim
	bezel.mesh = bz_box
	root.add_child(bezel)

	# Button Cap
	var cap = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = btn_size
	cap_box.material = active_mat
	cap.mesh = cap_box
	cap.position = Vector3(0, 0.005, 0)
	root.add_child(cap)

	var lbl = _create_3d_label(title_text, 27, Color(1.0, 0.98, 0.90))
	lbl.position = Vector3(0, btn_size.y * 0.5 + 0.008, 0)
	root.add_child(lbl)

	var area = Area3D.new()
	area.name = "Area_" + btn_name
	area.set_meta("hit_type", btn_name)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = btn_size + Vector3(0.02, 0.04, 0.02)
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
	lbl.pixel_size = 0.00125
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.outline_size = 10 if with_outline else 2
	lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.96) if with_outline else Color(1.0, 0.96, 0.88, 0.35)
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
	if not is3:
		return false
	for i in range(1, 7):
		if i != three_val and _calculate_repeatness(i, 2):
			return true
	return false

func _calculate_sorted() -> bool:
	var has_1_to_5 = (1 in current_dices) and (2 in current_dices) and (3 in current_dices) and (4 in current_dices) and (5 in current_dices)
	var has_2_to_6 = (2 in current_dices) and (3 in current_dices) and (4 in current_dices) and (5 in current_dices) and (6 in current_dices)
	return has_1_to_5 or has_2_to_6

func _calculate_all_same() -> bool:
	for i in range(1, 7):
		if _calculate_repeatness(i, 5):
			return true
	return false

func _calculate_category_score(cat_index: int) -> int:
	match cat_index:
		0, 1, 2, 3, 4, 5:
			return _calculate_simple_dices(cat_index + 1)
		6:
			return _calculate_3times_repeat()
		7:
			return _calculate_4times_repeat()
		8:
			return _calculate_all_dices()
		9:
			return 25 if _calculate_23_times_repeat() else 0
		10:
			return 40 if _calculate_sorted() else 0
		11:
			return 50 if _calculate_all_same() else 0
		_:
			return 0

func _recalculate_preview_scores() -> void:
	var my_arr = p1_board if my_player_index == 1 else p2_board
	for i in range(NUM_CATEGORIES):
		if not my_arr[i]["is_selected"]:
			my_arr[i]["calc"] = _calculate_category_score(i)

func _auto_equip_best_available_category() -> void:
	var my_arr = p1_board if my_player_index == 1 else p2_board
	var best_idx: int = -1
	var best_val: int = -1
	for i in range(NUM_CATEGORIES):
		if not my_arr[i]["is_selected"]:
			var c_val = int(my_arr[i]["calc"])
			if c_val > best_val:
				best_val = c_val
				best_idx = i
	if best_idx != -1:
		equipped_index = best_idx

# ==============================================================================
# VISUAL REFRESH & 3D DICE ANIMATIONS
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

	# 2. Refresh 5 Luxury 3D Dice slots & Framed Number Badges
	for d_idx in range(NUM_DICE):
		if d_idx >= _dice_nodes.size():
			continue
		var d_ui = _dice_nodes[d_idx]
		var val = current_dices[d_idx] if d_idx < current_dices.size() else 1
		var is_held = d_idx in held_dice_indices
		d_ui["lock_ring"].visible = is_held
		(d_ui["chamfer"] as MeshInstance3D).material_override = mat_die_held_chamfer if is_held else mat_die_chamfer
		for slab in d_ui["slabs"]:
			(slab as MeshInstance3D).material_override = mat_die_held_ivory if is_held else mat_die_ivory

		if d_ui.has("badge_cap"):
			(d_ui["badge_cap"] as MeshInstance3D).material_override = mat_die_badge_held if is_held else mat_die_badge_idle

		var d_lbl: Label3D = d_ui["label"]
		if is_held:
			d_lbl.text = "قفل %s" % _fa_digits(val)
			d_lbl.modulate = Color(1.0, 0.98, 0.78)
		else:
			d_lbl.text = _fa_digits(val)
			d_lbl.modulate = Color(1.0, 0.96, 0.88)

		if not is_rolling_dice:
			var target_y = 0.064 if is_held else 0.050
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
			sub_lbl.text = "✅ ثبت %s (%s)" % [eq_name, _fa_digits(eq_pts)]
			sub_lbl.modulate = Color(1.0, 0.98, 0.90) if can_act else Color(0.65, 0.65, 0.68)

	if is_instance_valid(_status_lbl_3d):
		if is_round_played:
			_status_lbl_3d.text = "⏳ امتیاز این دست شما ثبت شد — منتظر انتخاب حریف باشید..."
			_status_lbl_3d.modulate = Color(0.55, 0.90, 1.0)
		elif remaining_rolls > 0:
			_status_lbl_3d.text = "تاس‌های دلخواه را قفل کنید یا خانه امتیاز را انتخاب و ثبت کنید"
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
			lbl.text = _fa_digits(preview_val)
			lbl.modulate = Color(1.0, 0.98, 0.82)
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
		tw.tween_property(pivot, "position:y", 0.155, 0.16)
		tw.parallel().tween_property(pivot, "rotation", spin_rot, 0.36)
		tw.tween_property(pivot, "position:y", 0.050, 0.20)
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
		var target_y = 0.064 if is_held else 0.050
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

	if _btn_roll_node.has("root"):
		var b_root: Node3D = _btn_roll_node["root"]
		var tw = create_tween()
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.07)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.10)

	remaining_rolls -= 1
	var kept: Array[int] = held_dice_indices.duplicate()
	_refresh_visuals()
	send_move(Commands.Roll_Dice, {"selected_indexes": kept})

func _on_submit_button_clicked() -> void:
	if not GameManager.is_game_active:
		return
	if is_round_played:
		AudioManager.play_sound("miss_turn")
		show_hint("این دست را بازی کرده‌اید؛ منتظر حریف بمانید.")
		return
	var my_arr = p1_board if my_player_index == 1 else p2_board
	if equipped_index < 0 or equipped_index >= my_arr.size():
		return
	if bool(my_arr[equipped_index]["is_selected"]):
		AudioManager.play_sound("miss_turn")
		show_hint("لطفاً یک خانه خالی انتخاب کنید!")
		return

	if _btn_submit_node.has("root"):
		var b_root: Node3D = _btn_submit_node["root"]
		var tw = create_tween()
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.07)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.10)

	AudioManager.play_sound("add_peace")
	is_round_played = true
	held_dice_indices.clear()
	_refresh_visuals()
	# Backend YatzyGameClass.recieve_data expects data = {"index": equipped_index}
	send_move(Commands.Select_Peace, {"index": equipped_index})

# ==============================================================================
# SERVER COMMAND HANDLERS (Simultaneous Turn, RollResult, PeaceSelected, Reconnect)
# ==============================================================================

func on_turn_data(payload: Dictionary) -> void:
	_hide_hands_for_yatzy()
	my_player_index = GameManager.my_player_index

	var dices_raw = payload.get("dices", [])
	if dices_raw is Array and dices_raw.size() >= NUM_DICE:
		current_dices.clear()
		for i in range(NUM_DICE):
			current_dices.append(clampi(int(dices_raw[i]), 1, 6))

	held_dice_indices.clear()
	remaining_rolls = 2
	is_round_played = false
	set_board_locked(false)

	_recalculate_preview_scores()
	_auto_equip_best_available_category()
	_animate_dice_roll(false)
	_refresh_visuals()

func on_roll_result(payload: Dictionary) -> void:
	var dices_raw = payload.get("dices", [])
	if dices_raw is Array and dices_raw.size() >= NUM_DICE:
		current_dices.clear()
		for i in range(NUM_DICE):
			current_dices.append(clampi(int(dices_raw[i]), 1, 6))

	_recalculate_preview_scores()
	var my_arr = p1_board if my_player_index == 1 else p2_board
	if equipped_index < 0 or equipped_index >= my_arr.size() or bool(my_arr[equipped_index]["is_selected"]):
		_auto_equip_best_available_category()

	_animate_dice_roll(true)
	_refresh_visuals()

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	my_player_index = GameManager.my_player_index
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

	GameManager.p1_score = p1_tot
	GameManager.p2_score = p2_tot
	GameManager.scores_updated.emit(p1_tot, p2_tot)
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("update_scores"):
		hud.update_scores(p1_tot, p2_tot)

	if user_id == my_player_index:
		is_round_played = true
		held_dice_indices.clear()
		AudioManager.play_sound("add_peace")
	else:
		AudioManager.play_sound("move_peace")
		var opp_name = GameManager.p2_name if user_id == 2 else GameManager.p1_name
		if sel_idx >= 0 and sel_idx < CATEGORY_NAMES_FA.size():
			show_hint("🎲 %s خانه «%s» (%s امتیاز) را ثبت کرد" % [opp_name, CATEGORY_NAMES_FA[sel_idx], _fa_digits(sc)])

	_refresh_visuals()

	if sel_idx >= 0 and sel_idx < _cat_row_nodes.size():
		var cell_key = "p1" if user_id == 1 else "p2"
		var cell_node: Node3D = _cat_row_nodes[sel_idx][cell_key]["root"]
		ActionVFXManager.spawn_piece_impact_vfx(self, cell_node.global_position - global_position, user_id)
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cell_node, "scale", Vector3(1.16, 1.16, 1.16), 0.14)
		tw.tween_property(cell_node, "scale", Vector3.ONE, 0.14)

func on_wait_time(time_sec: int) -> void:
	is_round_played = true
	set_board_locked(true)
	_refresh_visuals()
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("set_round_wait"):
		hud.set_round_wait(time_sec)

func on_reconnect_data(payload: Dictionary) -> void:
	_hide_hands_for_yatzy()
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", payload)
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

	var d_arr = g_data.get("current_dices", g_data.get("dices", []))
	if typeof(d_arr) == TYPE_ARRAY and not d_arr.is_empty():
		current_dices.clear()
		for v in d_arr:
			current_dices.append(clampi(int(v), 1, 6))
		while current_dices.size() < NUM_DICE:
			current_dices.append(1)

	var scores = g_data.get("scores", [])
	if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:
		GameManager.p1_score = int(scores[0])
		GameManager.p2_score = int(scores[1])
		GameManager.scores_updated.emit(GameManager.p1_score, GameManager.p2_score)
		var hud = get_tree().root.find_child("BaseGameHUD", true, false)
		if hud and hud.has_method("update_scores"):
			hud.update_scores(int(scores[0]), int(scores[1]))

	_recalculate_preview_scores()
	if not is_round_played:
		_auto_equip_best_available_category()
	_refresh_visuals()

func reset_board() -> void:
	_init_board_arrays()
	_recalculate_preview_scores()
	_refresh_visuals()

func cleanup_board() -> void:
	super.cleanup_board()
	held_dice_indices.clear()
	is_rolling_dice = false
