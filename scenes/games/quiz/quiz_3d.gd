class_name Quiz3D
extends "res://scripts/games/base_game_board.gd"

# Quiz3D - Cafe Fekr Royal Trivia Game
# Complete 2-4 Player Quiz Experience:
# - Procedural 3D luxury walnut & brass table console with 4 player crystal pedestals
# - Responsive safe-area 2D mobile CanvasLayer UI (strictly bounded between TopHeader & BottomBar)
# - Live 2-4 player lock-in status strip, rich Persian typography, and full reveal/VFX feedback
# - Scores: +1 for correct, -1 for wrong, 0 for timeout

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const OPTION_LETTERS: Array[String] = ["الف", "ب", "ج", "د"]

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.25, 0.30), # Ruby Red
	2: Color(0.25, 0.65, 1.00), # Sapphire Blue
	3: Color(0.22, 0.88, 0.44), # Emerald Green
	4: Color(1.00, 0.80, 0.18), # Sunburst Yellow
}

# --- State ---
var current_question_num: int = 1
var total_questions_count: int = 10
var current_question_text: String = ""
var current_options: Array = []
var selected_option_idx: int = 0
var has_answered_this_turn: bool = false
var is_in_reveal_phase: bool = false
var player_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var player_locked_in: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _match_started: bool = false
var _reveal_timer_tween: Tween = null
var _reveal_remaining: float = 0.0

# --- 3D Scene Elements ---
var stand_root: Node3D
var center_medallion: MeshInstance3D
var center_medallion_mat: StandardMaterial3D
var player_crystals: Dictionary = {} # gamer_id -> MeshInstance3D
var crystal_materials: Dictionary = {}

# --- 2D UI Elements ---
var canvas_layer: CanvasLayer
var main_container: Control
var safe_margin: MarginContainer
var scroll_container: ScrollContainer
var content_box: VBoxContainer

var player_status_row: HBoxContainer
var player_status_chips: Dictionary = {} # gid -> Dictionary of chip refs

var question_card: PanelContainer
var lbl_category: Label
var lbl_question: Label
var lbl_question_tag: Label
var question_progress_bar: ProgressBar

var status_banner_card: PanelContainer
var lbl_status_banner: Label
var reveal_progress_bar: ProgressBar

var options_container: VBoxContainer
var option_cards: Array[PanelContainer] = []
var option_buttons: Array[Button] = []
var option_badges: Array[PanelContainer] = []
var option_badge_labels: Array[Label] = []
var option_labels: Array[Label] = []
var option_player_tags: Array[HBoxContainer] = []
var option_hovered: Array[bool] = [false, false, false, false]

var vfx_particles_container: Control

# --- Styles ---
var _style_card_bg: StyleBoxFlat
var _style_category_pill: StyleBoxFlat
var _style_counter_pill: StyleBoxFlat
var _style_option_normal: StyleBoxFlat
var _style_option_hover: StyleBoxFlat
var _style_option_selected: StyleBoxFlat
var _style_option_correct: StyleBoxFlat
var _style_option_wrong: StyleBoxFlat
var _style_option_dimmed: StyleBoxFlat
var _style_badge_normal: StyleBoxFlat
var _style_badge_selected: StyleBoxFlat
var _style_badge_correct: StyleBoxFlat
var _style_badge_wrong: StyleBoxFlat
var _style_banner_locked: StyleBoxFlat
var _style_banner_correct: StyleBoxFlat
var _style_banner_wrong: StyleBoxFlat
var _style_banner_timeout: StyleBoxFlat

func _ready() -> void:
	game_type = GameTypes.QUIZ
	super._ready()
	_setup_styles()
	_build_3d_tabletop_stand()
	_build_2d_ui()
	if is_instance_valid(main_container):
		main_container.visible = false
	sync_turn_state()
	_refresh_player_status_strip()

func _exit_tree() -> void:
	if _reveal_timer_tween and _reveal_timer_tween.is_valid():
		_reveal_timer_tween.kill()
		_reveal_timer_tween = null
	if is_instance_valid(main_container):
		main_container.queue_free()
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	cleanup_board()
	super._exit_tree()

func sync_turn_state() -> void:
	# For Quiz (simultaneous game), skip super.sync_turn_state() to avoid
	# the base class calling on_turn_changed() which would create infinite recursion.
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	if not GameManager.is_game_active:
		is_my_turn = false
		is_board_locked = true
		return
	is_my_turn = true
	is_board_locked = false
	_match_started = true

func _process(delta: float) -> void:
	_update_hud_visibility()
	_update_responsive_margins()
	if is_instance_valid(center_medallion):
		center_medallion.rotate_y(delta * (1.2 if is_in_reveal_phase else 0.35))

func _is_hud_overlay_blocking() -> bool:
	if not _match_started or not GameManager.is_game_active:
		return true
	var tree = get_tree()
	if not tree:
		return false
	var hud = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		if "is_start_overlay_dismissed" in hud and not hud.is_start_overlay_dismissed:
			return true
		var start_ov = hud.get_node_or_null("StartGameOverlay")
		if is_instance_valid(start_ov) and start_ov.visible:
			return true
		var res_dlg = hud.get_node_or_null("GameResultDialog")
		if is_instance_valid(res_dlg) and res_dlg.visible:
			return true
		var surr_dlg = hud.get_node_or_null("SurrenderDialog")
		if is_instance_valid(surr_dlg) and surr_dlg.visible:
			return true
		var pause_dlg = hud.get_node_or_null("DisconnectPauseDialog")
		if is_instance_valid(pause_dlg) and pause_dlg.visible:
			return true
	return false

func _update_hud_visibility() -> void:
	if not is_instance_valid(main_container):
		return
	var tree = get_tree()
	if tree:
		var hud = tree.get_first_node_in_group("base_game_hud")
		if not is_instance_valid(hud):
			hud = tree.root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud) and main_container.get_parent() != hud:
			if main_container.get_parent():
				main_container.get_parent().remove_child(main_container)
			hud.add_child(main_container)
			var start_ov = hud.get_node_or_null("StartGameOverlay")
			if is_instance_valid(start_ov):
				hud.move_child(main_container, start_ov.get_index())
			if is_instance_valid(canvas_layer):
				canvas_layer.queue_free()
				canvas_layer = null
	var should_show = not _is_hud_overlay_blocking()
	if main_container.visible != should_show:
		main_container.visible = should_show

func _update_responsive_margins() -> void:
	if not is_instance_valid(safe_margin) or not is_instance_valid(main_container):
		return
	var total_w = main_container.size.x
	if total_w <= 0.0:
		return
	var target_max_w = 992.0
	var side_pad = maxf(36.0, (total_w - target_max_w) * 0.5)
	if absf(float(safe_margin.get_theme_constant("margin_left")) - side_pad) > 2.0:
		safe_margin.add_theme_constant_override("margin_left", int(side_pad))
		safe_margin.add_theme_constant_override("margin_right", int(side_pad))

func _setup_styles() -> void:
	# Question Card Background (Deep Royal Walnut & Brass Trim)
	_style_card_bg = StyleBoxFlat.new()
	_style_card_bg.bg_color = Color(0.10, 0.07, 0.05, 0.96)
	_style_card_bg.set_corner_radius_all(24)
	_style_card_bg.set_border_width_all(3)
	_style_card_bg.border_width_bottom = 6
	_style_card_bg.border_color = Color(0.88, 0.72, 0.34, 0.92)
	_style_card_bg.shadow_color = Color(0, 0, 0, 0.65)
	_style_card_bg.shadow_size = 14
	_style_card_bg.shadow_offset = Vector2(0, 6)
	_style_card_bg.content_margin_left = 26
	_style_card_bg.content_margin_right = 26
	_style_card_bg.content_margin_top = 20
	_style_card_bg.content_margin_bottom = 22

	_style_category_pill = StyleBoxFlat.new()
	_style_category_pill.bg_color = Color(0.24, 0.15, 0.06, 0.95)
	_style_category_pill.border_color = Color(0.92, 0.75, 0.32, 0.85)
	_style_category_pill.set_border_width_all(1)
	_style_category_pill.set_corner_radius_all(14)
	_style_category_pill.content_margin_left = 14
	_style_category_pill.content_margin_right = 14
	_style_category_pill.content_margin_top = 5
	_style_category_pill.content_margin_bottom = 5

	_style_counter_pill = StyleBoxFlat.new()
	_style_counter_pill.bg_color = Color(0.09, 0.17, 0.28, 0.95)
	_style_counter_pill.border_color = Color(0.40, 0.75, 0.98, 0.85)
	_style_counter_pill.set_border_width_all(1)
	_style_counter_pill.set_corner_radius_all(14)
	_style_counter_pill.content_margin_left = 14
	_style_counter_pill.content_margin_right = 14
	_style_counter_pill.content_margin_top = 5
	_style_counter_pill.content_margin_bottom = 5

	# Option Card Styles
	_style_option_normal = StyleBoxFlat.new()
	_style_option_normal.bg_color = Color(0.15, 0.10, 0.07, 0.95)
	_style_option_normal.set_corner_radius_all(18)
	_style_option_normal.set_border_width_all(2)
	_style_option_normal.border_width_bottom = 4
	_style_option_normal.border_color = Color(0.66, 0.52, 0.28, 0.78)
	_style_option_normal.shadow_color = Color(0, 0, 0, 0.45)
	_style_option_normal.shadow_size = 6
	_style_option_normal.shadow_offset = Vector2(0, 3)

	_style_option_hover = _style_option_normal.duplicate()
	_style_option_hover.bg_color = Color(0.22, 0.14, 0.09, 0.98)
	_style_option_hover.border_color = Color(1.0, 0.86, 0.40, 1.0)
	_style_option_hover.shadow_color = Color(0.95, 0.78, 0.25, 0.35)
	_style_option_hover.shadow_size = 10

	_style_option_selected = _style_option_normal.duplicate()
	_style_option_selected.bg_color = Color(0.08, 0.20, 0.36, 0.98)
	_style_option_selected.set_border_width_all(3)
	_style_option_selected.border_width_bottom = 5
	_style_option_selected.border_color = Color(0.36, 0.82, 1.0, 1.0)
	_style_option_selected.shadow_color = Color(0.20, 0.65, 1.0, 0.50)
	_style_option_selected.shadow_size = 12

	_style_option_correct = _style_option_normal.duplicate()
	_style_option_correct.bg_color = Color(0.07, 0.29, 0.14, 0.98)
	_style_option_correct.set_border_width_all(3)
	_style_option_correct.border_width_bottom = 5
	_style_option_correct.border_color = Color(0.35, 0.98, 0.54, 1.0)
	_style_option_correct.shadow_color = Color(0.20, 0.90, 0.42, 0.58)
	_style_option_correct.shadow_size = 14

	_style_option_wrong = _style_option_normal.duplicate()
	_style_option_wrong.bg_color = Color(0.30, 0.07, 0.09, 0.98)
	_style_option_wrong.set_border_width_all(3)
	_style_option_wrong.border_width_bottom = 5
	_style_option_wrong.border_color = Color(1.0, 0.32, 0.36, 1.0)
	_style_option_wrong.shadow_color = Color(0.95, 0.20, 0.25, 0.50)
	_style_option_wrong.shadow_size = 12

	_style_option_dimmed = _style_option_normal.duplicate()
	_style_option_dimmed.bg_color = Color(0.10, 0.07, 0.05, 0.72)
	_style_option_dimmed.border_color = Color(0.35, 0.28, 0.18, 0.45)
	_style_option_dimmed.shadow_size = 2

	# Option Letter Medallion Badges
	_style_badge_normal = StyleBoxFlat.new()
	_style_badge_normal.bg_color = Color(0.26, 0.16, 0.09, 0.98)
	_style_badge_normal.set_corner_radius_all(26)
	_style_badge_normal.set_border_width_all(2)
	_style_badge_normal.border_color = Color(0.88, 0.72, 0.34, 1.0)

	_style_badge_selected = _style_badge_normal.duplicate()
	_style_badge_selected.bg_color = Color(0.14, 0.44, 0.76, 0.98)
	_style_badge_selected.border_color = Color(0.55, 0.90, 1.0, 1.0)

	_style_badge_correct = _style_badge_normal.duplicate()
	_style_badge_correct.bg_color = Color(0.12, 0.62, 0.28, 0.98)
	_style_badge_correct.border_color = Color(0.50, 1.0, 0.65, 1.0)

	_style_badge_wrong = _style_badge_normal.duplicate()
	_style_badge_wrong.bg_color = Color(0.68, 0.14, 0.18, 0.98)
	_style_badge_wrong.border_color = Color(1.0, 0.55, 0.55, 1.0)

	# Status / Reveal Banner Styles
	_style_banner_locked = StyleBoxFlat.new()
	_style_banner_locked.bg_color = Color(0.08, 0.18, 0.30, 0.95)
	_style_banner_locked.border_color = Color(0.36, 0.80, 1.0, 0.92)
	_style_banner_locked.set_border_width_all(2)
	_style_banner_locked.set_corner_radius_all(16)
	_style_banner_locked.content_margin_left = 18
	_style_banner_locked.content_margin_right = 18
	_style_banner_locked.content_margin_top = 10
	_style_banner_locked.content_margin_bottom = 10

	_style_banner_correct = _style_banner_locked.duplicate()
	_style_banner_correct.bg_color = Color(0.07, 0.28, 0.14, 0.97)
	_style_banner_correct.border_color = Color(0.35, 0.98, 0.54, 1.0)

	_style_banner_wrong = _style_banner_locked.duplicate()
	_style_banner_wrong.bg_color = Color(0.28, 0.08, 0.10, 0.97)
	_style_banner_wrong.border_color = Color(1.0, 0.36, 0.40, 1.0)

	_style_banner_timeout = _style_banner_locked.duplicate()
	_style_banner_timeout.bg_color = Color(0.16, 0.13, 0.09, 0.96)
	_style_banner_timeout.border_color = Color(0.86, 0.72, 0.36, 0.90)

# --- 3D Tabletop Stand Construction ---
func _build_3d_tabletop_stand() -> void:
	stand_root = Node3D.new()
	stand_root.name = "StandRoot"
	add_child(stand_root)

	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.86, 0.70, 0.26)
	gold_mat.metallic = 0.88
	gold_mat.roughness = 0.22

	# Central Mahogany Console Base on Cafe Table
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(1.15, 0.08, 0.85)
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.20, 0.10, 0.055)
	base_mat.roughness = 0.34
	base_mat.metallic = 0.15
	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.material_override = base_mat
	base_inst.position = Vector3(0.0, 0.04, -0.05)
	stand_root.add_child(base_inst)

	# Inlaid Gold Border Frame
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(1.19, 0.02, 0.89)
	var frame_inst = MeshInstance3D.new()
	frame_inst.mesh = frame_mesh
	frame_inst.material_override = gold_mat
	frame_inst.position = Vector3(0.0, 0.01, -0.05)
	stand_root.add_child(frame_inst)

	# Central Emerald Velvet Placard
	var mat_mesh = BoxMesh.new()
	mat_mesh.size = Vector3(0.95, 0.015, 0.65)
	var mat_mat = StandardMaterial3D.new()
	mat_mat.albedo_color = Color(0.05, 0.16, 0.11)
	mat_mat.roughness = 0.88
	var mat_inst = MeshInstance3D.new()
	mat_inst.mesh = mat_mesh
	mat_inst.material_override = mat_mat
	mat_inst.position = Vector3(0.0, 0.085, -0.05)
	stand_root.add_child(mat_inst)

	# Floating Rotating Golden Brass Ring Medallion in Center
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = 0.14
	torus_mesh.outer_radius = 0.175
	center_medallion_mat = StandardMaterial3D.new()
	center_medallion_mat.albedo_color = Color(0.92, 0.76, 0.30)
	center_medallion_mat.metallic = 0.90
	center_medallion_mat.roughness = 0.20
	center_medallion_mat.emission_enabled = true
	center_medallion_mat.emission = Color(0.75, 0.55, 0.15)
	center_medallion_mat.emission_energy_multiplier = 0.45
	center_medallion = MeshInstance3D.new()
	center_medallion.mesh = torus_mesh
	center_medallion.material_override = center_medallion_mat
	center_medallion.position = Vector3(0.0, 0.11, -0.05)
	stand_root.add_child(center_medallion)

	# 4 Player Crystal Pedestals around the table console
	var pedestal_coords: Dictionary = {
		1: Vector3(-0.46, 0.10, 0.32),  # P1 Front-Left
		2: Vector3(0.46, 0.10, 0.32),   # P2 Front-Right
		3: Vector3(-0.46, 0.10, -0.42), # P3 Back-Left
		4: Vector3(0.46, 0.10, -0.42),  # P4 Back-Right
	}

	for gid in pedestal_coords.keys():
		var pos: Vector3 = pedestal_coords[gid]

		var sock_mesh = CylinderMesh.new()
		sock_mesh.top_radius = 0.065
		sock_mesh.bottom_radius = 0.075
		sock_mesh.height = 0.05
		var sock_inst = MeshInstance3D.new()
		sock_inst.mesh = sock_mesh
		sock_inst.material_override = gold_mat
		sock_inst.position = pos
		stand_root.add_child(sock_inst)

		var sph_mesh = SphereMesh.new()
		sph_mesh.radius = 0.05
		sph_mesh.height = 0.10
		var sph_mat = StandardMaterial3D.new()
		var col: Color = FACTION_COLORS.get(gid, Color.WHITE)
		sph_mat.albedo_color = col.darkened(0.45)
		sph_mat.roughness = 0.15
		sph_mat.metallic = 0.4
		sph_mat.emission_enabled = true
		sph_mat.emission = col.darkened(0.7)
		sph_mat.emission_energy_multiplier = 0.5

		var sph_inst = MeshInstance3D.new()
		sph_inst.mesh = sph_mesh
		sph_inst.material_override = sph_mat
		sph_inst.position = pos + Vector3(0.0, 0.055, 0.0)
		stand_root.add_child(sph_inst)

		player_crystals[gid] = sph_inst
		crystal_materials[gid] = sph_mat

# --- 2D UI Setup ---
func _build_2d_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1
	add_child(canvas_layer)

	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.visible = false
	canvas_layer.add_child(main_container)

	# Strictly bounded Safe-Area Container between TopHeaderSlot (~308px) & BottomBar (154px)
	safe_margin = MarginContainer.new()
	safe_margin.name = "SafeAreaMargin"
	safe_margin.anchor_left = 0.0
	safe_margin.anchor_right = 1.0
	safe_margin.anchor_top = 0.0
	safe_margin.anchor_bottom = 1.0
	safe_margin.offset_top = 314.0
	safe_margin.offset_bottom = -168.0
	safe_margin.add_theme_constant_override("margin_left", 44)
	safe_margin.add_theme_constant_override("margin_right", 44)
	safe_margin.add_theme_constant_override("margin_top", 8)
	safe_margin.add_theme_constant_override("margin_bottom", 8)
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(safe_margin)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "QuizScroll"
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	safe_margin.add_child(scroll_container)

	content_box = VBoxContainer.new()
	content_box.name = "ContentBox"
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.add_theme_constant_override("separation", 16)
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.add_child(content_box)

	# --- 1. Live Player Status Strip (2-4 Players Lock-In & Turn Result) ---
	player_status_row = HBoxContainer.new()
	player_status_row.name = "PlayerStatusRow"
	player_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_status_row.add_theme_constant_override("separation", 10)
	player_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(player_status_row)

	# --- 2. Question Card ---
	question_card = PanelContainer.new()
	question_card.name = "QuestionCard"
	question_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	question_card.custom_minimum_size = Vector2(0, 176)
	question_card.add_theme_stylebox_override("panel", _style_card_bg)
	question_card.mouse_filter = Control.MOUSE_FILTER_PASS
	content_box.add_child(question_card)

	var q_vbox = VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 12)
	q_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	question_card.add_child(q_vbox)

	# Header Row: Category Pill + Question Counter Pill
	var q_header = HBoxContainer.new()
	q_header.add_theme_constant_override("separation", 12)
	q_vbox.add_child(q_header)

	var cat_pill = PanelContainer.new()
	cat_pill.add_theme_stylebox_override("panel", _style_category_pill)
	q_header.add_child(cat_pill)

	lbl_category = Label.new()
	lbl_category.text = "💡 اطلاعات عمومی"
	lbl_category.add_theme_font_override("font", FontHekayat)
	lbl_category.add_theme_font_size_override("font_size", 24)
	lbl_category.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	cat_pill.add_child(lbl_category)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_header.add_child(spacer)

	var cnt_pill = PanelContainer.new()
	cnt_pill.add_theme_stylebox_override("panel", _style_counter_pill)
	q_header.add_child(cnt_pill)

	lbl_question_tag = Label.new()
	lbl_question_tag.text = "سوال ۱ از ۱۰"
	lbl_question_tag.add_theme_font_override("font", FontHekayat)
	lbl_question_tag.add_theme_font_size_override("font_size", 24)
	lbl_question_tag.add_theme_color_override("font_color", Color(0.82, 0.93, 1.0))
	cnt_pill.add_child(lbl_question_tag)

	# Subtle Question Progress Line
	question_progress_bar = ProgressBar.new()
	question_progress_bar.custom_minimum_size = Vector2(0, 6)
	question_progress_bar.show_percentage = false
	question_progress_bar.min_value = 0.0
	question_progress_bar.max_value = 100.0
	question_progress_bar.value = 10.0
	var sb_q_bg = StyleBoxFlat.new()
	sb_q_bg.bg_color = Color(0.22, 0.16, 0.10, 0.75)
	sb_q_bg.set_corner_radius_all(3)
	var sb_q_fill = StyleBoxFlat.new()
	sb_q_fill.bg_color = Color(0.95, 0.76, 0.28, 0.95)
	sb_q_fill.set_corner_radius_all(3)
	question_progress_bar.add_theme_stylebox_override("background", sb_q_bg)
	question_progress_bar.add_theme_stylebox_override("fill", sb_q_fill)
	q_vbox.add_child(question_progress_bar)

	# Question Text Label
	lbl_question = Label.new()
	lbl_question.name = "LblQuestion"
	lbl_question.text = "در حال بارگذاری سوال..."
	lbl_question.add_theme_font_override("font", FontHekayat)
	lbl_question.add_theme_font_size_override("font_size", 35)
	lbl_question.add_theme_constant_override("line_spacing", 6)
	lbl_question.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	lbl_question.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	lbl_question.add_theme_constant_override("shadow_offset_x", 1)
	lbl_question.add_theme_constant_override("shadow_offset_y", 2)
	lbl_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_vbox.add_child(lbl_question)

	# --- 3. Compact Status / Reveal Banner Card ---
	status_banner_card = PanelContainer.new()
	status_banner_card.name = "StatusBannerCard"
	status_banner_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_banner_card.visible = false
	status_banner_card.add_theme_stylebox_override("panel", _style_banner_locked)
	status_banner_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(status_banner_card)

	var st_vbox = VBoxContainer.new()
	st_vbox.add_theme_constant_override("separation", 6)
	status_banner_card.add_child(st_vbox)

	lbl_status_banner = Label.new()
	lbl_status_banner.text = ""
	lbl_status_banner.add_theme_font_override("font", FontHekayat)
	lbl_status_banner.add_theme_font_size_override("font_size", 25)
	lbl_status_banner.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	lbl_status_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st_vbox.add_child(lbl_status_banner)

	reveal_progress_bar = ProgressBar.new()
	reveal_progress_bar.custom_minimum_size = Vector2(0, 5)
	reveal_progress_bar.show_percentage = false
	reveal_progress_bar.visible = false
	reveal_progress_bar.min_value = 0.0
	reveal_progress_bar.max_value = 100.0
	reveal_progress_bar.value = 100.0
	var sb_rev_bg = StyleBoxFlat.new()
	sb_rev_bg.bg_color = Color(0.05, 0.04, 0.03, 0.70)
	sb_rev_bg.set_corner_radius_all(3)
	var sb_rev_fill = StyleBoxFlat.new()
	sb_rev_fill.bg_color = Color(1.0, 0.84, 0.32, 0.95)
	sb_rev_fill.set_corner_radius_all(3)
	reveal_progress_bar.add_theme_stylebox_override("background", sb_rev_bg)
	reveal_progress_bar.add_theme_stylebox_override("fill", sb_rev_fill)
	st_vbox.add_child(reveal_progress_bar)

	# --- 4. Four Interactive Option Cards ---
	options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.add_theme_constant_override("separation", 13)
	options_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(options_container)

	option_cards.clear()
	option_buttons.clear()
	option_badges.clear()
	option_badge_labels.clear()
	option_labels.clear()
	option_player_tags.clear()

	var empty_sb = StyleBoxEmpty.new()

	for i in range(4):
		var opt_idx = i + 1

		var card = PanelContainer.new()
		card.name = "OptionCard%d" % opt_idx
		card.visible = false
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 88)
		card.add_theme_stylebox_override("panel", _style_option_normal)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		options_container.add_child(card)

		var margin = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(margin)

		var btn_hbox = HBoxContainer.new()
		btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_theme_constant_override("separation", 14)
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(btn_hbox)

		# Left side: player answer pills or "انتخاب شما" badge
		var p_tags = HBoxContainer.new()
		p_tags.name = "PlayerTags"
		p_tags.add_theme_constant_override("separation", 6)
		p_tags.alignment = BoxContainer.ALIGNMENT_BEGIN
		p_tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_child(p_tags)

		# Middle: Expanding & Smart-Wrapping Persian Option Text
		var o_lbl = Label.new()
		o_lbl.name = "LblOptionText"
		o_lbl.text = "گزینه %d" % opt_idx
		o_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		o_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o_lbl.add_theme_font_override("font", FontHekayat)
		o_lbl.add_theme_font_size_override("font_size", 30)
		o_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90))
		o_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
		o_lbl.add_theme_constant_override("shadow_offset_x", 1)
		o_lbl.add_theme_constant_override("shadow_offset_y", 2)
		o_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		o_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn_hbox.add_child(o_lbl)

		# Right side: Circular Letter Medallion (الف، ب، ج، د)
		var badge = PanelContainer.new()
		badge.custom_minimum_size = Vector2(52, 52)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _style_badge_normal)
		var b_lbl = Label.new()
		b_lbl.text = OPTION_LETTERS[i]
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 26)
		b_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(b_lbl)
		btn_hbox.add_child(badge)

		# Invisible Click Hitbox Overlay (lets PanelContainer styleboxes & auto-height shine)
		var btn = Button.new()
		btn.name = "BtnOption%d" % opt_idx
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			btn.add_theme_stylebox_override(state_name, empty_sb)
		card.add_child(btn)

		var idx_capture = i
		var opt_capture = opt_idx
		btn.pressed.connect(func(): _on_option_pressed(opt_capture))
		btn.mouse_entered.connect(func(): _on_option_hover(idx_capture, true))
		btn.mouse_exited.connect(func(): _on_option_hover(idx_capture, false))
		btn.button_down.connect(func(): _on_option_press_anim(idx_capture, true))
		btn.button_up.connect(func(): _on_option_press_anim(idx_capture, false))

		option_cards.append(card)
		option_buttons.append(btn)
		option_badges.append(badge)
		option_badge_labels.append(b_lbl)
		option_labels.append(o_lbl)
		option_player_tags.append(p_tags)

	# VFX Layer
	vfx_particles_container = Control.new()
	vfx_particles_container.name = "QuizVFXLayer"
	vfx_particles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vfx_particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(vfx_particles_container)

func _on_option_hover(idx: int, hovered: bool) -> void:
	if idx < 0 or idx >= option_cards.size():
		return
	option_hovered[idx] = hovered
	if is_board_locked or has_answered_this_turn or is_in_reveal_phase:
		return
	var card = option_cards[idx]
	card.add_theme_stylebox_override("panel", _style_option_hover if hovered else _style_option_normal)
	card.pivot_offset = card.size * 0.5
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(1.015, 1.015) if hovered else Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_option_press_anim(idx: int, down: bool) -> void:
	if idx < 0 or idx >= option_cards.size():
		return
	if is_board_locked or has_answered_this_turn or is_in_reveal_phase:
		return
	var card = option_cards[idx]
	card.pivot_offset = card.size * 0.5
	var target_s = Vector2(0.975, 0.975) if down else (Vector2(1.015, 1.015) if option_hovered[idx] else Vector2.ONE)
	var tw = create_tween()
	tw.tween_property(card, "scale", target_s, 0.07)

# --- Live Player Status Strip (2-4 Players) ---
func _get_total_players() -> int:
	return clampi(max(2, GameManager.match_players.size()), 2, 4)

func _refresh_player_status_strip() -> void:
	if not is_instance_valid(player_status_row):
		return
	var total_p = _get_total_players()
	if player_status_chips.size() != total_p:
		for c in player_status_row.get_children():
			c.queue_free()
		player_status_chips.clear()
		for gid in range(1, total_p + 1):
			var chip = _create_status_chip(gid)
			player_status_row.add_child(chip["panel"])
			player_status_chips[gid] = chip

	for gid in player_status_chips.keys():
		_update_status_chip(gid, false, false, 0, 0)

func _create_status_chip(gid: int) -> Dictionary:
	var col: Color = FACTION_COLORS.get(gid, Color.WHITE)
	var is_me = (gid == my_player_index)

	var panel = PanelContainer.new()
	panel.name = "StatusChip%d" % gid
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 56)

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.06, 0.90)
	sb.border_color = col.lightened(0.15) if is_me else Color(col.r, col.g, col.b, 0.55)
	sb.set_border_width_all(2 if is_me else 1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var dot = Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d_sb = StyleBoxFlat.new()
	d_sb.bg_color = col
	d_sb.set_corner_radius_all(6)
	dot.add_theme_stylebox_override("panel", d_sb)
	hbox.add_child(dot)

	var name_lbl = Label.new()
	name_lbl.text = _get_player_name(gid)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	var state_lbl = Label.new()
	state_lbl.text = "⏳"
	state_lbl.add_theme_font_override("font", FontHekayat)
	state_lbl.add_theme_font_size_override("font_size", 20)
	state_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(state_lbl)

	return {
		"panel": panel,
		"style": sb,
		"name": name_lbl,
		"state": state_lbl,
		"color": col,
	}

func _update_status_chip(gid: int, is_locked: bool, reveal: bool, chosen_opt: int, delta: int) -> void:
	if not player_status_chips.has(gid):
		return
	var chip: Dictionary = player_status_chips[gid]
	var panel: PanelContainer = chip["panel"]
	var sb: StyleBoxFlat = chip["style"]
	var name_lbl: Label = chip["name"]
	var state_lbl: Label = chip["state"]
	var col: Color = chip["color"]
	if not is_instance_valid(panel):
		return

	name_lbl.text = _get_player_name(gid)

	if reveal:
		var opt_tag = (" (%s)" % OPTION_LETTERS[clampi(chosen_opt - 1, 0, 3)]) if chosen_opt >= 1 and chosen_opt <= 4 else ""
		if delta > 0:
			sb.bg_color = Color(0.06, 0.25, 0.12, 0.95)
			sb.border_color = Color(0.35, 0.98, 0.54, 1.0)
			state_lbl.text = "✅ +۱%s" % opt_tag
			state_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62))
		elif delta < 0:
			sb.bg_color = Color(0.26, 0.06, 0.08, 0.95)
			sb.border_color = Color(1.0, 0.36, 0.40, 1.0)
			state_lbl.text = "❌ -۱%s" % opt_tag
			state_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.50))
		else:
			sb.bg_color = Color(0.13, 0.11, 0.09, 0.90)
			sb.border_color = Color(0.55, 0.50, 0.45, 0.70)
			state_lbl.text = "⏱️ ۰"
			state_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	elif is_locked:
		sb.bg_color = Color(0.08, 0.20, 0.30, 0.95)
		sb.border_color = Color(0.36, 0.84, 1.0, 0.95)
		state_lbl.text = "🔒 ثبت شد"
		state_lbl.add_theme_color_override("font_color", Color(0.52, 0.92, 1.0))
	else:
		var is_me = (gid == my_player_index)
		sb.bg_color = Color(0.11, 0.08, 0.06, 0.90)
		sb.border_color = col.lightened(0.15) if is_me else Color(col.r, col.g, col.b, 0.55)
		state_lbl.text = "⏳"
		state_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))

	panel.add_theme_stylebox_override("panel", sb)

# --- Option Click Handler ---
func _on_option_pressed(opt_idx: int) -> void:
	if is_board_locked or has_answered_this_turn or is_in_reveal_phase:
		return
	if not GameManager.is_game_active:
		return

	has_answered_this_turn = true
	selected_option_idx = opt_idx
	player_locked_in[my_player_index] = true
	AudioManager.play_sound("add_peace")

	_highlight_selected_button(opt_idx)
	_update_crystal_light(my_player_index, true)
	_update_status_chip(my_player_index, true, false, 0, 0)
	_set_header_player_answered(my_player_index, true)

	# Show inline confirmation pill
	if is_instance_valid(status_banner_card) and is_instance_valid(lbl_status_banner):
		status_banner_card.add_theme_stylebox_override("panel", _style_banner_locked)
		var letter = OPTION_LETTERS[clampi(opt_idx - 1, 0, 3)]
		lbl_status_banner.text = "🔒 پاسخ شما (گزینه «%s») ثبت شد — منتظر سایر بازیکنان..." % letter
		lbl_status_banner.add_theme_color_override("font_color", Color(0.58, 0.92, 1.0))
		if is_instance_valid(reveal_progress_bar):
			reveal_progress_bar.visible = false
		status_banner_card.visible = true
		status_banner_card.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(status_banner_card, "modulate:a", 1.0, 0.18)

	# Dispatch answer to server
	send_move(Commands.Select_Peace, {"option": opt_idx})
	_set_header_banner("🔒 پاسخ شما ثبت شد — منتظر پایان زمان...", Color(0.42, 0.95, 0.65))

func _highlight_selected_button(opt_idx: int) -> void:
	for i in range(option_cards.size()):
		var card = option_cards[i]
		var btn = option_buttons[i]
		var badge = option_badges[i]
		var b_lbl = option_badge_labels[i]
		var tags = option_player_tags[i]

		btn.disabled = true
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		for child in tags.get_children():
			child.queue_free()

		if (i + 1) == opt_idx:
			card.add_theme_stylebox_override("panel", _style_option_selected)
			card.modulate = Color.WHITE
			badge.add_theme_stylebox_override("panel", _style_badge_selected)
			b_lbl.add_theme_color_override("font_color", Color.WHITE)
			tags.add_child(_create_simple_tag("🔒 انتخاب شما", Color(0.14, 0.42, 0.72, 0.95), Color(0.50, 0.88, 1.0)))
			card.pivot_offset = card.size * 0.5
			var tw = create_tween()
			tw.tween_property(card, "scale", Vector2(1.025, 1.025), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, 0.12)
		else:
			card.add_theme_stylebox_override("panel", _style_option_dimmed)
			card.modulate = Color(1, 1, 1, 0.78)
			card.scale = Vector2.ONE
			badge.add_theme_stylebox_override("panel", _style_badge_normal)
			b_lbl.add_theme_color_override("font_color", Color(0.85, 0.76, 0.55))

func _create_simple_tag(txt: String, bg_col: Color, border_col: Color) -> PanelContainer:
	var pill = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	pill.add_child(lbl)
	return pill

# --- Server Signal Hooks ---
func setup_board(_game_data: Dictionary) -> void:
	_refresh_player_status_strip()

func on_start_game() -> void:
	_match_started = true
	_refresh_player_status_strip()
	super.on_start_game()

func on_turn_data(payload: Dictionary) -> void:
	_handle_new_question_turn(payload)

func on_turn_changed(_turn: int, _is_me: bool) -> void:
	# Quiz is simultaneous — all players are always active.
	is_my_turn = true
	is_board_locked = false

func _handle_new_question_turn(payload: Dictionary) -> void:
	if _reveal_timer_tween and _reveal_timer_tween.is_valid():
		_reveal_timer_tween.kill()
		_reveal_timer_tween = null

	_match_started = true
	is_in_reveal_phase = false
	has_answered_this_turn = false
	selected_option_idx = 0
	set_board_locked(false)

	current_question_num = int(payload.get("turn", current_question_num))
	total_questions_count = max(1, int(payload.get("total_questions", 10)))
	current_question_text = str(payload.get("question", ""))
	current_options = payload.get("options", [])

	if payload.has("scores") and typeof(payload["scores"]) == TYPE_DICTIONARY:
		player_scores = payload["scores"]
		_update_header_scores()

	_refresh_player_status_strip()
	_clear_header_answered_states()

	for gid in player_locked_in.keys():
		player_locked_in[gid] = false
		_update_crystal_light(gid, false)
	for gid in player_status_chips.keys():
		_update_status_chip(gid, false, false, 0, 0)

	if is_instance_valid(center_medallion_mat):
		center_medallion_mat.emission = Color(0.75, 0.55, 0.15)
		center_medallion_mat.emission_energy_multiplier = 0.45

	# Update Question Card
	if is_instance_valid(lbl_category):
		var cat_name = str(payload.get("category_title", "")).strip_edges()
		if cat_name.is_empty():
			cat_name = "اطلاعات عمومی"
		if not cat_name.begins_with("💡") and not ("🎥" in cat_name or "📺" in cat_name or "🖋" in cat_name or "🎧" in cat_name or "🗿" in cat_name or "🔠" in cat_name or "📡" in cat_name or "🔬" in cat_name or "🎨" in cat_name or "📚" in cat_name or "🏓" in cat_name or "🤓" in cat_name or "📖" in cat_name):
			lbl_category.text = "💡 " + cat_name
		else:
			lbl_category.text = cat_name

	if is_instance_valid(lbl_question):
		lbl_question.text = current_question_text
	if is_instance_valid(lbl_question_tag):
		lbl_question_tag.text = "سوال %s از %s" % [_fa_digits(current_question_num), _fa_digits(total_questions_count)]
	if is_instance_valid(question_progress_bar):
		var pct = clampf((float(current_question_num) / float(total_questions_count)) * 100.0, 0.0, 100.0)
		var p_tw = create_tween()
		p_tw.tween_property(question_progress_bar, "value", pct, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_instance_valid(status_banner_card):
		status_banner_card.visible = false
	if is_instance_valid(reveal_progress_bar):
		reveal_progress_bar.visible = false

	# Reset Options UI
	for i in range(option_cards.size()):
		var card = option_cards[i]
		var btn = option_buttons[i]
		var badge = option_badges[i]
		var b_lbl = option_badge_labels[i]
		var lbl = option_labels[i]
		var tags = option_player_tags[i]
		option_hovered[i] = false

		if i < current_options.size():
			card.visible = true
			card.modulate = Color.WHITE
			card.scale = Vector2.ONE
			card.rotation_degrees = 0.0
			card.add_theme_stylebox_override("panel", _style_option_normal)
			badge.add_theme_stylebox_override("panel", _style_badge_normal)
			b_lbl.text = OPTION_LETTERS[i]
			b_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
			lbl.text = str(current_options[i])
			btn.disabled = false
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			for child in tags.get_children():
				child.queue_free()
		else:
			card.visible = false

	# Scroll back to top gently if needed
	if is_instance_valid(scroll_container):
		scroll_container.scroll_vertical = 0

	AudioManager.play_sound("start_turn")
	call_deferred("_sync_header_for_question", current_question_num, total_questions_count)

	# Smooth card entrance animation
	if is_instance_valid(question_card):
		question_card.pivot_offset = question_card.size * 0.5
		question_card.scale = Vector2(0.96, 0.96)
		question_card.modulate.a = 0.85
		var tw = create_tween().set_parallel(true)
		tw.tween_property(question_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(question_card, "modulate:a", 1.0, 0.18)

func _sync_header_for_question(q_num: int, q_total: int) -> void:
	if is_in_reveal_phase or has_answered_this_turn:
		return
	_set_header_banner("🤔 گزینه درست را انتخاب کنید", Color(1.0, 0.90, 0.45))
	_set_header_round_label(q_num, q_total)

func on_piece_selected(user_id: int, _target_peace: int, _extra: Dictionary = {}) -> void:
	# Broadcast from server that a player locked in their answer (option remains secret)
	player_locked_in[user_id] = true
	_update_crystal_light(user_id, true)
	_update_status_chip(user_id, true, false, 0, 0)
	_set_header_player_answered(user_id, true)

	if player_status_chips.has(user_id):
		var p_panel: Control = player_status_chips[user_id].get("panel")
		if is_instance_valid(p_panel):
			p_panel.pivot_offset = p_panel.size * 0.5
			var tw = create_tween()
			tw.tween_property(p_panel, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(p_panel, "scale", Vector2.ONE, 0.14)

func on_finish_turn_round(data: Dictionary) -> void:
	is_in_reveal_phase = true
	set_board_locked(true)

	var correct_opt = int(data.get("correct_option", 0))
	var player_answers: Dictionary = data.get("player_answers", {})
	if data.has("scores") and typeof(data["scores"]) == TYPE_DICTIONARY:
		player_scores = data["scores"]

	if is_instance_valid(center_medallion_mat):
		center_medallion_mat.emission = Color(0.25, 0.95, 0.50)
		center_medallion_mat.emission_energy_multiplier = 2.0

	# Style Option Cards accurately for Reveal
	for i in range(option_cards.size()):
		var opt_num = i + 1
		var card = option_cards[i]
		var btn = option_buttons[i]
		var badge = option_badges[i]
		var b_lbl = option_badge_labels[i]
		var tags = option_player_tags[i]

		btn.disabled = true
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		for child in tags.get_children():
			child.queue_free()

		if opt_num == correct_opt:
			card.add_theme_stylebox_override("panel", _style_option_correct)
			card.modulate = Color.WHITE
			badge.add_theme_stylebox_override("panel", _style_badge_correct)
			b_lbl.text = "✓"
			b_lbl.add_theme_color_override("font_color", Color.WHITE)
			_trigger_correct_vfx(card)
		elif opt_num == selected_option_idx:
			card.add_theme_stylebox_override("panel", _style_option_wrong)
			card.modulate = Color.WHITE
			badge.add_theme_stylebox_override("panel", _style_badge_wrong)
			b_lbl.text = "✕"
			b_lbl.add_theme_color_override("font_color", Color.WHITE)
			_trigger_wrong_vfx(card)
		else:
			card.add_theme_stylebox_override("panel", _style_option_dimmed)
			card.modulate = Color(1, 1, 1, 0.65)
			badge.add_theme_stylebox_override("panel", _style_badge_normal)
			b_lbl.text = OPTION_LETTERS[i]
			b_lbl.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48))

	_display_player_answers(player_answers, correct_opt)
	_update_header_scores()

	# Audio + Status Banner feedback based on local result
	var my_result = player_answers.get(str(my_player_index), player_answers.get(my_player_index, {}))
	var correct_letter = OPTION_LETTERS[clampi(correct_opt - 1, 0, 3)]
	var is_corr = bool(my_result.get("is_correct", false)) if typeof(my_result) == TYPE_DICTIONARY else false
	var delta = int(my_result.get("score_delta", 0)) if typeof(my_result) == TYPE_DICTIONARY else 0

	if is_corr:
		AudioManager.play_sound("win")
		_set_header_banner("🎉 آفرین! پاسخ شما صحیح بود (+۱)", Color(0.35, 0.98, 0.52))
		_show_reveal_banner("🎉 آفرین! پاسخ درست بود (+۱ امتیاز)  •  گزینه صحیح: «%s»" % correct_letter, _style_banner_correct, Color(0.62, 1.0, 0.72))
	elif delta < 0:
		AudioManager.play_sound("lose")
		_set_header_banner("❌ متأسفانه پاسخ نادرست بود (-۱)", Color(1.0, 0.35, 0.38))
		_show_reveal_banner("❌ پاسخ نادرست بود (-۱ امتیاز)  •  گزینه صحیح: «%s»" % correct_letter, _style_banner_wrong, Color(1.0, 0.68, 0.68))
	else:
		_set_header_banner("⏳ مهلت پاسخ پایان یافت (۰)", Color(0.85, 0.85, 0.85))
		_show_reveal_banner("⏱️ زمان پاسخ‌گویی تمام شد (۰ امتیاز)  •  گزینه صحیح: «%s»" % correct_letter, _style_banner_timeout, Color(1.0, 0.90, 0.62))

func _show_reveal_banner(msg: String, sb: StyleBoxFlat, txt_col: Color) -> void:
	if not is_instance_valid(status_banner_card) or not is_instance_valid(lbl_status_banner):
		return
	status_banner_card.add_theme_stylebox_override("panel", sb)
	lbl_status_banner.text = msg
	lbl_status_banner.add_theme_color_override("font_color", txt_col)
	status_banner_card.visible = true
	status_banner_card.modulate.a = 0.0

	if _reveal_timer_tween and _reveal_timer_tween.is_valid():
		_reveal_timer_tween.kill()

	if is_instance_valid(reveal_progress_bar):
		reveal_progress_bar.visible = true
		reveal_progress_bar.value = 100.0
		_reveal_timer_tween = create_tween()
		_reveal_timer_tween.tween_property(reveal_progress_bar, "value", 0.0, 3.8)

	var fade_tw = create_tween()
	fade_tw.tween_property(status_banner_card, "modulate:a", 1.0, 0.20)

func _display_player_answers(player_answers: Dictionary, _correct_opt: int) -> void:
	for p_key in player_answers.keys():
		var p_info = player_answers[p_key]
		if typeof(p_info) != TYPE_DICTIONARY:
			continue
		var gid = int(p_info.get("gamer_id", p_key))
		var chosen_opt = int(p_info.get("option", 0))
		var is_corr = bool(p_info.get("is_correct", false))
		var delta = int(p_info.get("score_delta", 0))

		_update_status_chip(gid, true, true, chosen_opt, delta)

		if 1 <= chosen_opt and chosen_opt <= option_player_tags.size():
			var tag_container = option_player_tags[chosen_opt - 1]
			var pill = _create_player_pill(gid, is_corr, delta)
			tag_container.add_child(pill)

func _get_player_name(gid: int) -> String:
	var p_data = GameManager.get_player_data_by_gamer_id(gid)
	return str(p_data.get("name", p_data.get("username", "بازیکن %s" % _fa_digits(gid))))

func _create_player_pill(gid: int, is_corr: bool, delta: int) -> PanelContainer:
	var pill = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	var base_col: Color = FACTION_COLORS.get(gid, Color.WHITE)
	sb.bg_color = base_col.darkened(0.68)
	sb.border_color = base_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	pill.add_child(hbox)

	var name_lbl = Label.new()
	name_lbl.text = _get_player_name(gid)
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_lbl)

	var score_lbl = Label.new()
	score_lbl.text = ("+%s" % _fa_digits(delta)) if delta > 0 else (("-%s" % _fa_digits(abs(delta))) if delta < 0 else "۰")
	score_lbl.add_theme_font_override("font", FontHekayat)
	score_lbl.add_theme_font_size_override("font_size", 19)
	score_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62) if is_corr else (Color(1.0, 0.45, 0.45) if delta < 0 else Color(0.85, 0.85, 0.85)))
	hbox.add_child(score_lbl)

	return pill

# --- Visual Effects ---
func _trigger_correct_vfx(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw = create_tween()
	tw.tween_property(card, "scale", Vector2(1.035, 1.035), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18)

	var vfx_origin = card.global_position + Vector2(card.size.x * 0.5, 12.0)
	_spawn_floating_text("+۱", vfx_origin, Color(0.35, 0.98, 0.52))

func _trigger_wrong_vfx(card: Control) -> void:
	if not is_instance_valid(card):
		return
	# Gentle rotational shake around center pivot (safe inside VBoxContainer without layout fight)
	card.pivot_offset = card.size * 0.5
	var tw = create_tween()
	tw.tween_property(card, "rotation_degrees", 1.4, 0.045)
	tw.tween_property(card, "rotation_degrees", -1.4, 0.045)
	tw.tween_property(card, "rotation_degrees", 0.9, 0.04)
	tw.tween_property(card, "rotation_degrees", -0.9, 0.04)
	tw.tween_property(card, "rotation_degrees", 0.0, 0.04)

	var vfx_origin = card.global_position + Vector2(card.size.x * 0.5, 12.0)
	_spawn_floating_text("-۱", vfx_origin, Color(1.0, 0.35, 0.38))

func _spawn_floating_text(text: String, global_pos: Vector2, col: Color) -> void:
	if not is_instance_valid(vfx_particles_container):
		return
	var local_pos = global_pos - vfx_particles_container.global_position
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", 46)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.custom_minimum_size = Vector2(90, 56)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.pivot_offset = Vector2(45, 28)
	lbl.position = local_pos - lbl.pivot_offset
	lbl.scale = Vector2(0.5, 0.5)
	vfx_particles_container.add_child(lbl)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 68.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.22, 1.22), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.38).set_delay(0.48)
	tw.chain().tween_callback(lbl.queue_free)

func _update_crystal_light(gid: int, is_active: bool) -> void:
	if not crystal_materials.has(gid):
		return
	var mat: StandardMaterial3D = crystal_materials[gid]
	var col: Color = FACTION_COLORS.get(gid, Color.WHITE)
	var tw = create_tween()
	if is_active:
		tw.tween_property(mat, "emission_energy_multiplier", 3.5, 0.2)
		tw.tween_property(mat, "emission", col, 0.2)
	else:
		tw.tween_property(mat, "emission_energy_multiplier", 0.5, 0.3)
		tw.tween_property(mat, "emission", col.darkened(0.7), 0.3)

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
	if payload.has("game_data") and typeof(payload["game_data"]) == TYPE_DICTIONARY:
		src = payload["game_data"]

	if src.has("current_question") and typeof(src["current_question"]) == TYPE_DICTIONARY:
		_handle_new_question_turn(src["current_question"])
	elif payload.has("current_question") and typeof(payload["current_question"]) == TYPE_DICTIONARY:
		_handle_new_question_turn(payload["current_question"])
	elif src.has("question") or src.has("turn"):
		_handle_new_question_turn(src)

	if src.has("scores") and typeof(src["scores"]) == TYPE_DICTIONARY:
		player_scores = src["scores"]
		_update_header_scores()
	elif payload.has("scores") and typeof(payload["scores"]) == TYPE_DICTIONARY:
		player_scores = payload["scores"]
		_update_header_scores()

func reset_board() -> void:
	current_question_num = 1
	has_answered_this_turn = false
	is_in_reveal_phase = false
	selected_option_idx = 0
	player_scores = {1: 0, 2: 0, 3: 0, 4: 0}
	for gid in player_locked_in.keys():
		player_locked_in[gid] = false
		_update_crystal_light(gid, false)
		_update_status_chip(gid, false, false, 0, 0)
	_clear_header_answered_states()

func cleanup_board() -> void:
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	if is_instance_valid(stand_root):
		stand_root.queue_free()
