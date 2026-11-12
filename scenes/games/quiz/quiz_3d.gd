class_name Quiz3D
extends "res://scripts/games/base_game_board.gd"

# Quiz3D - Cafe Fekr Royal Trivia Game
# Complete 2-4 Player Quiz Experience:
# - Procedural 3D luxury walnut & brass table console with 4 player crystal pedestals
# - High-visibility 2D mobile CanvasLayer UI with large readable Persian typography
# - Simultaneous answering, secret lock-in indicators, and end-of-turn reveal with VFX
# - Scores: +1 for correct, -1 for wrong, 0 for timeout

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const OPTION_LETTERS: Array[String] = ["الف", "ب", "ج", "د"]
const OPTION_NUMBERS_FA: Array[String] = ["۱", "۲", "۳", "۴"]

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

# --- 3D Scene Elements ---
var stand_root: Node3D
var player_crystals: Dictionary = {} # gamer_id -> MeshInstance3D
var crystal_materials: Dictionary = {}

# --- 2D UI Elements (CanvasLayer) ---
var canvas_layer: CanvasLayer
var main_container: Control
var question_card: PanelContainer
var lbl_category: Label
var lbl_question: Label
var lbl_question_tag: Label
var options_container: VBoxContainer
var option_buttons: Array[Button] = []
var option_badges: Array[PanelContainer] = []
var option_labels: Array[Label] = []
var option_player_tags: Array[HBoxContainer] = []
var summary_panel: PanelContainer
var summary_vbox: VBoxContainer
var vfx_particles_container: Control

# --- Styles ---
var _style_card_bg: StyleBoxFlat
var _style_option_normal: StyleBoxFlat
var _style_option_hover: StyleBoxFlat
var _style_option_selected: StyleBoxFlat
var _style_option_correct: StyleBoxFlat
var _style_option_wrong: StyleBoxFlat

func _ready() -> void:
	game_type = GameTypes.QUIZ
	super._ready()
	_setup_styles()
	_build_3d_tabletop_stand()
	_build_2d_ui()
	if is_instance_valid(main_container):
		main_container.visible = false
	sync_turn_state()

func _exit_tree() -> void:
	if is_instance_valid(main_container):
		main_container.queue_free()
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	cleanup_board()
	super._exit_tree()

func sync_turn_state() -> void:
	# For Quiz (simultaneous game), skip super.sync_turn_state() to avoid
	# the base class calling on_turn_changed() which would create infinite recursion.
	# Instead, manually set the simultaneous-game state directly.
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	if not GameManager.is_game_active:
		is_my_turn = false
		is_board_locked = true
		return
	# Quiz is always simultaneous — all players can answer at once
	is_my_turn = true
	is_board_locked = false
	_match_started = true

func _process(_delta: float) -> void:
	_update_hud_visibility()

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

func _setup_styles() -> void:
	# Question Card Background
	_style_card_bg = StyleBoxFlat.new()
	_style_card_bg.bg_color = Color(0.12, 0.08, 0.06, 0.96)
	_style_card_bg.set_corner_radius_all(22)
	_style_card_bg.set_border_width_all(3)
	_style_card_bg.border_color = Color(0.85, 0.70, 0.35, 0.9)
	_style_card_bg.shadow_color = Color(0, 0, 0, 0.65)
	_style_card_bg.shadow_size = 10
	_style_card_bg.shadow_offset = Vector2(0, 4)
	_style_card_bg.content_margin_left = 32
	_style_card_bg.content_margin_right = 32
	_style_card_bg.content_margin_top = 24
	_style_card_bg.content_margin_bottom = 24

	# Option Normal Style
	_style_option_normal = StyleBoxFlat.new()
	_style_option_normal.bg_color = Color(0.18, 0.12, 0.08, 0.95)
	_style_option_normal.set_corner_radius_all(16)
	_style_option_normal.set_border_width_all(2)
	_style_option_normal.border_color = Color(0.65, 0.50, 0.28, 0.75)
	_style_option_normal.shadow_color = Color(0, 0, 0, 0.4)
	_style_option_normal.shadow_size = 4
	_style_option_normal.shadow_offset = Vector2(0, 2)
	_style_option_normal.content_margin_left = 20
	_style_option_normal.content_margin_right = 20
	_style_option_normal.content_margin_top = 16
	_style_option_normal.content_margin_bottom = 16

	# Option Hover Style
	_style_option_hover = _style_option_normal.duplicate()
	_style_option_hover.bg_color = Color(0.24, 0.16, 0.10, 0.98)
	_style_option_hover.border_color = Color(1.0, 0.88, 0.45, 1.0)
	_style_option_hover.shadow_color = Color(0.9, 0.75, 0.2, 0.35)

	# Option Selected (Locked in by me)
	_style_option_selected = _style_option_normal.duplicate()
	_style_option_selected.bg_color = Color(0.10, 0.22, 0.38, 0.98)
	_style_option_selected.set_border_width_all(4)
	_style_option_selected.border_color = Color(0.35, 0.80, 1.0, 1.0)
	_style_option_selected.shadow_color = Color(0.2, 0.65, 1.0, 0.55)

	# Option Correct (Emerald Glow)
	_style_option_correct = _style_option_normal.duplicate()
	_style_option_correct.bg_color = Color(0.08, 0.32, 0.15, 0.98)
	_style_option_correct.set_border_width_all(4)
	_style_option_correct.border_color = Color(0.35, 0.98, 0.52, 1.0)
	_style_option_correct.shadow_color = Color(0.2, 0.9, 0.4, 0.6)

	# Option Wrong (Ruby Glow)
	_style_option_wrong = _style_option_normal.duplicate()
	_style_option_wrong.bg_color = Color(0.32, 0.08, 0.10, 0.98)
	_style_option_wrong.set_border_width_all(3)
	_style_option_wrong.border_color = Color(1.0, 0.30, 0.35, 1.0)
	_style_option_wrong.shadow_color = Color(0.9, 0.2, 0.25, 0.5)

# --- 3D Tabletop Stand Construction ---
func _build_3d_tabletop_stand() -> void:
	stand_root = Node3D.new()
	stand_root.name = "StandRoot"
	add_child(stand_root)

	# Central Mahogany Console Base on Cafe Table
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(1.15, 0.08, 0.85)
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.22, 0.11, 0.06)
	base_mat.roughness = 0.35
	base_mat.metallic = 0.15
	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.material_override = base_mat
	base_inst.position = Vector3(0.0, 0.04, -0.05)
	stand_root.add_child(base_inst)

	# Inlaid Gold Border Frame
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(1.18, 0.02, 0.88)
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.85, 0.70, 0.25)
	gold_mat.metallic = 0.88
	gold_mat.roughness = 0.22
	var frame_inst = MeshInstance3D.new()
	frame_inst.mesh = frame_mesh
	frame_inst.material_override = gold_mat
	frame_inst.position = Vector3(0.0, 0.01, -0.05)
	stand_root.add_child(frame_inst)

	# Central Velvet Placard / Trivia Medallion
	var mat_mesh = BoxMesh.new()
	mat_mesh.size = Vector3(0.95, 0.015, 0.65)
	var mat_mat = StandardMaterial3D.new()
	mat_mat.albedo_color = Color(0.08, 0.07, 0.10)
	mat_mat.roughness = 0.85
	var mat_inst = MeshInstance3D.new()
	mat_inst.mesh = mat_mesh
	mat_inst.material_override = mat_mat
	mat_inst.position = Vector3(0.0, 0.085, -0.05)
	stand_root.add_child(mat_inst)

	# 4 Player Crystal Pedestals around the table console
	var pedestal_coords: Dictionary = {
		1: Vector3(-0.46, 0.10, 0.32),  # P1 Front-Left
		2: Vector3(0.46, 0.10, 0.32),   # P2 Front-Right
		3: Vector3(-0.46, 0.10, -0.42), # P3 Back-Left
		4: Vector3(0.46, 0.10, -0.42),  # P4 Back-Right
	}

	for gid in pedestal_coords.keys():
		var pos: Vector3 = pedestal_coords[gid]

		# Brass socket
		var sock_mesh = CylinderMesh.new()
		sock_mesh.top_radius = 0.065
		sock_mesh.bottom_radius = 0.075
		sock_mesh.height = 0.05
		var sock_inst = MeshInstance3D.new()
		sock_inst.mesh = sock_mesh
		sock_inst.material_override = gold_mat
		sock_inst.position = pos
		stand_root.add_child(sock_inst)

		# Glowing crystal sphere
		var sph_mesh = SphereMesh.new()
		sph_mesh.radius = 0.05
		sph_mesh.height = 0.10
		var sph_mat = StandardMaterial3D.new()
		var col: Color = FACTION_COLORS.get(gid, Color.WHITE)
		sph_mat.albedo_color = col.darkened(0.5)
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

# --- 2D UI Setup (CanvasLayer) ---
func _build_2d_ui() -> void:
	# Local fallback canvas layer with layer = 1 until reparented to BaseGameHUD
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1
	add_child(canvas_layer)

	main_container = Control.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.visible = false
	canvas_layer.add_child(main_container)

	# Centered Layout Box (Below MatchDetailsBox, above BottomBar)
	var content_box = VBoxContainer.new()
	content_box.name = "ContentBox"
	content_box.anchor_left = 0.5
	content_box.anchor_right = 0.5
	content_box.anchor_top = 0.5
	content_box.anchor_bottom = 0.5
	content_box.offset_left = -480.0
	content_box.offset_right = 480.0
	content_box.offset_top = -280.0
	content_box.offset_bottom = 440.0
	content_box.add_theme_constant_override("separation", 20)
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(content_box)

	# --- Question Card ---
	question_card = PanelContainer.new()
	question_card.name = "QuestionCard"
	question_card.custom_minimum_size = Vector2(960, 190)
	question_card.add_theme_stylebox_override("panel", _style_card_bg)
	question_card.mouse_filter = Control.MOUSE_FILTER_PASS
	content_box.add_child(question_card)

	var q_vbox = VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 12)
	question_card.add_child(q_vbox)

	# Header row of Question Card
	var q_header = HBoxContainer.new()
	q_vbox.add_child(q_header)

	lbl_category = Label.new()
	lbl_category.text = "💡 سوال اطلاعات عمومی"
	lbl_category.add_theme_font_override("font", FontHekayat)
	lbl_category.add_theme_font_size_override("font_size", 24)
	lbl_category.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	q_header.add_child(lbl_category)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_header.add_child(spacer)

	lbl_question_tag = Label.new()
	lbl_question_tag.text = "سوال ۱ از ۱۰"
	lbl_question_tag.add_theme_font_override("font", FontHekayat)
	lbl_question_tag.add_theme_font_size_override("font_size", 24)
	lbl_question_tag.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	q_header.add_child(lbl_question_tag)

	# Question Text Label (Large, crisp, readable Persian text)
	lbl_question = Label.new()
	lbl_question.name = "LblQuestion"
	lbl_question.text = "در حال بارگذاری سوال..."
	lbl_question.add_theme_font_override("font", FontHekayat)
	lbl_question.add_theme_font_size_override("font_size", 34)
	lbl_question.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	lbl_question.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl_question.add_theme_constant_override("shadow_offset_x", 1)
	lbl_question.add_theme_constant_override("shadow_offset_y", 2)
	lbl_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_vbox.add_child(lbl_question)

	# --- 4 Options Container ---
	options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.add_theme_constant_override("separation", 14)
	content_box.add_child(options_container)

	option_buttons.clear()
	option_badges.clear()
	option_labels.clear()
	option_player_tags.clear()

	for i in range(4):
		var opt_idx = i + 1
		var btn = Button.new()
		btn.name = "BtnOption%d" % opt_idx
		btn.custom_minimum_size = Vector2(960, 84)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.add_theme_stylebox_override("normal", _style_option_normal)
		btn.add_theme_stylebox_override("hover", _style_option_hover)
		btn.add_theme_stylebox_override("pressed", _style_option_selected)
		btn.add_theme_stylebox_override("disabled", _style_option_normal)

		var btn_hbox = HBoxContainer.new()
		btn_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_theme_constant_override("separation", 16)
		btn.add_child(btn_hbox)

		# Left side: indicators of players who selected this
		var p_tags = HBoxContainer.new()
		p_tags.name = "PlayerTags"
		p_tags.add_theme_constant_override("separation", 6)
		p_tags.alignment = BoxContainer.ALIGNMENT_BEGIN
		p_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_hbox.add_child(p_tags)

		var opt_spacer = Control.new()
		opt_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_hbox.add_child(opt_spacer)

		# Middle: Option Text
		var o_lbl = Label.new()
		o_lbl.name = "LblOptionText"
		o_lbl.text = "گزینه %d" % opt_idx
		o_lbl.add_theme_font_override("font", FontHekayat)
		o_lbl.add_theme_font_size_override("font_size", 30)
		o_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
		o_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		o_lbl.add_theme_constant_override("shadow_offset_x", 1)
		o_lbl.add_theme_constant_override("shadow_offset_y", 1)
		o_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		o_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn_hbox.add_child(o_lbl)

		# Right side: Option Letter Medallion (الف، ب، ج، د)
		var badge = PanelContainer.new()
		badge.custom_minimum_size = Vector2(46, 46)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.28, 0.18, 0.10, 0.95)
		b_style.set_corner_radius_all(23)
		b_style.set_border_width_all(2)
		b_style.border_color = Color(0.85, 0.70, 0.35, 1.0)
		badge.add_theme_stylebox_override("panel", b_style)
		var b_lbl = Label.new()
		b_lbl.text = OPTION_LETTERS[i]
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 26)
		b_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(b_lbl)
		btn_hbox.add_child(badge)

		btn.pressed.connect(func(): _on_option_pressed(opt_idx))
		options_container.add_child(btn)

		option_buttons.append(btn)
		option_badges.append(badge)
		option_labels.append(o_lbl)
		option_player_tags.append(p_tags)

	# --- Turn Summary Panel (Shown during 4s reveal window) ---
	summary_panel = PanelContainer.new()
	summary_panel.name = "SummaryPanel"
	summary_panel.visible = false
	summary_panel.add_theme_stylebox_override("panel", _style_card_bg)
	summary_vbox = VBoxContainer.new()
	summary_vbox.add_theme_constant_override("separation", 8)
	summary_panel.add_child(summary_vbox)
	content_box.add_child(summary_panel)

	# VFX Layer
	vfx_particles_container = Control.new()
	vfx_particles_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vfx_particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(vfx_particles_container)

# --- Option Click Handler ---
func _on_option_pressed(opt_idx: int) -> void:
	if is_board_locked or has_answered_this_turn or is_in_reveal_phase:
		return
	if not GameManager.is_game_active:
		return

	has_answered_this_turn = true
	selected_option_idx = opt_idx
	AudioManager.play_sound("add_peace")

	# Highlight my selected option locally
	_highlight_selected_button(opt_idx)
	_update_crystal_light(my_player_index, true)

	# Dispatch answer to server
	send_move(Commands.Select_Peace, {"option": opt_idx})

	# Update HUD banner to reassure the gamer
	_set_header_banner("✅ پاسخ شما ثبت شد — در انتظار پایان دور...", Color(0.4, 0.95, 0.6))

func _highlight_selected_button(opt_idx: int) -> void:
	for i in range(option_buttons.size()):
		var b = option_buttons[i]
		if (i + 1) == opt_idx:
			b.add_theme_stylebox_override("normal", _style_option_selected)
			b.add_theme_stylebox_override("hover", _style_option_selected)
		else:
			b.add_theme_stylebox_override("normal", _style_option_normal)
			b.add_theme_stylebox_override("hover", _style_option_hover)

# --- Server Signal Hooks ---
func on_start_game() -> void:
	_match_started = true
	super.on_start_game()

func on_turn_data(payload: Dictionary) -> void:
	_handle_new_question_turn(payload)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	# Quiz is simultaneous — all players are always active.
	# Do NOT call sync_turn_state() here; it would cause infinite recursion
	# because base_game_board.sync_turn_state() calls on_turn_changed() for
	# simultaneous games, which would re-enter sync_turn_state() forever.
	is_my_turn = true
	is_board_locked = false

func _handle_new_question_turn(payload: Dictionary) -> void:
	_match_started = true
	is_in_reveal_phase = false
	has_answered_this_turn = false
	selected_option_idx = 0
	set_board_locked(false)

	current_question_num = int(payload.get("turn", current_question_num))
	total_questions_count = int(payload.get("total_questions", 10))
	current_question_text = str(payload.get("question", ""))
	current_options = payload.get("options", [])
	if payload.has("scores") and typeof(payload["scores"]) == TYPE_DICTIONARY:
		player_scores = payload["scores"]
		_update_header_scores()

	# Reset player lock-in states
	for gid in player_locked_in.keys():
		player_locked_in[gid] = false
		_update_crystal_light(gid, false)

	# Update question UI
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

	# Update options UI
	for i in range(option_buttons.size()):
		var btn = option_buttons[i]
		var lbl = option_labels[i]
		var tags = option_player_tags[i]
		if i < current_options.size():
			btn.visible = true
			lbl.text = str(current_options[i])
			btn.disabled = false
			btn.add_theme_stylebox_override("normal", _style_option_normal)
			btn.add_theme_stylebox_override("hover", _style_option_hover)
			# Clear player tags
			for child in tags.get_children():
				child.queue_free()
		else:
			btn.visible = false

	if is_instance_valid(summary_panel):
		summary_panel.visible = false

	# Play round start sound
	AudioManager.play_sound("start_turn")
	_set_header_banner("🤔 پاسخ درست را انتخاب کنید", Color(1.0, 0.88, 0.45))
	_set_header_round_label(current_question_num, total_questions_count)

	# Pop-in tween for question card
	if is_instance_valid(question_card):
		question_card.scale = Vector2(0.96, 0.96)
		var tw = create_tween()
		tw.tween_property(question_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	# Broadcast from server that a player locked in their answer (option remains secret)
	player_locked_in[user_id] = true
	_update_crystal_light(user_id, true)

	if user_id != my_player_index:
		# Add a subtle "پاسخ داد" lock indicator next to player's avatar
		var _p_data = GameManager.get_player_data_by_gamer_id(user_id)
		# Header reaction / pulse can be triggered
		pass

func on_finish_turn_round(data: Dictionary) -> void:
	# End of turn reveal phase!
	is_in_reveal_phase = true
	set_board_locked(true)

	var correct_opt = int(data.get("correct_option", 0))
	var player_answers: Dictionary = data.get("player_answers", {})
	if data.has("scores") and typeof(data["scores"]) == TYPE_DICTIONARY:
		player_scores = data["scores"]

	# Highlight correct option in emerald and wrong options in red
	for i in range(option_buttons.size()):
		var opt_num = i + 1
		var btn = option_buttons[i]
		btn.disabled = true
		if opt_num == correct_opt:
			btn.add_theme_stylebox_override("normal", _style_option_correct)
			_trigger_correct_vfx(btn)
		elif opt_num == selected_option_idx:
			btn.add_theme_stylebox_override("normal", _style_option_wrong)
			_trigger_wrong_vfx(btn)
		else:
			btn.add_theme_stylebox_override("normal", _style_option_normal)

	# Display which player answered which option
	_display_player_answers(player_answers, correct_opt)

	# Update top header live scores
	_update_header_scores()

	# Audio feedback based on local result
	var my_result = player_answers.get(str(my_player_index), player_answers.get(my_player_index, {}))
	if typeof(my_result) == TYPE_DICTIONARY:
		var is_corr = bool(my_result.get("is_correct", false))
		var delta = int(my_result.get("score_delta", 0))
		if is_corr:
			AudioManager.play_sound("win")
			_set_header_banner("🎉 آفرین! پاسخ شما صحیح بود (+۱)", Color(0.35, 0.98, 0.52))
		elif delta < 0:
			AudioManager.play_sound("lose")
			_set_header_banner("❌ متأسفانه پاسخ نادرست بود (-۱)", Color(1.0, 0.35, 0.38))
		else:
			_set_header_banner("⏳ مهلت پاسخ پایان یافت (۰)", Color(0.85, 0.85, 0.85))

func _display_player_answers(player_answers: Dictionary, correct_opt: int) -> void:
	# Populate player answer tags next to the options
	for p_key in player_answers.keys():
		var p_info = player_answers[p_key]
		if typeof(p_info) != TYPE_DICTIONARY:
			continue
		var gid = int(p_info.get("gamer_id", p_key))
		var chosen_opt = int(p_info.get("option", 0))
		var is_corr = bool(p_info.get("is_correct", false))
		var delta = int(p_info.get("score_delta", 0))

		if 1 <= chosen_opt and chosen_opt <= option_player_tags.size():
			var tag_container = option_player_tags[chosen_opt - 1]
			var pill = _create_player_pill(gid, is_corr, delta)
			tag_container.add_child(pill)

	# Also show a comprehensive Turn Summary Card
	_build_turn_summary_card(player_answers, correct_opt)

func _get_player_name(gid: int) -> String:
	var p_data = GameManager.get_player_data_by_gamer_id(gid)
	return str(p_data.get("name", p_data.get("username", "بازیکن %d" % gid)))

func _create_player_pill(gid: int, is_corr: bool, delta: int) -> PanelContainer:
	var pill = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	var base_col: Color = FACTION_COLORS.get(gid, Color.WHITE)
	sb.bg_color = base_col.darkened(0.65)
	sb.border_color = base_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	pill.add_child(hbox)

	var name_lbl = Label.new()
	var p_name = _get_player_name(gid)
	name_lbl.text = p_name
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(name_lbl)

	var score_lbl = Label.new()
	score_lbl.text = ("+%s" % _fa_digits(delta)) if delta > 0 else (("-%s" % _fa_digits(abs(delta))) if delta < 0 else "۰")
	score_lbl.add_theme_font_override("font", FontHekayat)
	score_lbl.add_theme_font_size_override("font_size", 20)
	score_lbl.add_theme_color_override("font_color", Color(0.35, 0.98, 0.52) if is_corr else (Color(1.0, 0.35, 0.35) if delta < 0 else Color(0.8, 0.8, 0.8)))
	hbox.add_child(score_lbl)

	return pill

func _build_turn_summary_card(player_answers: Dictionary, correct_opt: int) -> void:
	if not is_instance_valid(summary_panel) or not is_instance_valid(summary_vbox):
		return
	for c in summary_vbox.get_children():
		c.queue_free()

	var title = Label.new()
	title.text = "📊 پاسخ‌های این دور (گزینه صحیح: %s)" % OPTION_LETTERS[clampi(correct_opt - 1, 0, 3)]
	title.add_theme_font_override("font", FontHekayat)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_vbox.add_child(title)

	var h_grid = HBoxContainer.new()
	h_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	h_grid.add_theme_constant_override("separation", 16)
	summary_vbox.add_child(h_grid)

	for p_key in player_answers.keys():
		var p_info = player_answers[p_key]
		if typeof(p_info) != TYPE_DICTIONARY:
			continue
		var gid = int(p_info.get("gamer_id", p_key))
		var chosen_opt = int(p_info.get("option", 0))
		var is_corr = bool(p_info.get("is_correct", false))
		var delta = int(p_info.get("score_delta", 0))
		var total = int(p_info.get("total_score", 0))

		var card = PanelContainer.new()
		var csb = StyleBoxFlat.new()
		var col = FACTION_COLORS.get(gid, Color.WHITE)
		csb.bg_color = Color(0.14, 0.10, 0.08, 0.95)
		csb.border_color = col
		csb.set_border_width_all(2)
		csb.set_corner_radius_all(12)
		csb.content_margin_left = 12
		csb.content_margin_right = 12
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)

		var cvbox = VBoxContainer.new()
		cvbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cvbox)

		var n_lbl = Label.new()
		n_lbl.text = _get_player_name(gid)
		n_lbl.add_theme_font_override("font", FontHekayat)
		n_lbl.add_theme_font_size_override("font_size", 20)
		n_lbl.add_theme_color_override("font_color", col.lightened(0.3))
		n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(n_lbl)

		var ans_lbl = Label.new()
		if chosen_opt > 0:
			ans_lbl.text = "گزینه %s %s" % [OPTION_LETTERS[clampi(chosen_opt - 1, 0, 3)], "✅" if is_corr else "❌"]
		else:
			ans_lbl.text = "بی‌پاسخ ⏱️"
		ans_lbl.add_theme_font_override("font", FontHekayat)
		ans_lbl.add_theme_font_size_override("font_size", 22)
		ans_lbl.add_theme_color_override("font_color", Color(0.35, 0.98, 0.52) if is_corr else (Color(1.0, 0.4, 0.4) if chosen_opt > 0 else Color(0.7, 0.7, 0.7)))
		ans_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(ans_lbl)

		var tot_lbl = Label.new()
		tot_lbl.text = "مجموع: %s" % _fa_digits(total)
		tot_lbl.add_theme_font_override("font", FontHekayat)
		tot_lbl.add_theme_font_size_override("font_size", 18)
		tot_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		tot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(tot_lbl)

		h_grid.add_child(card)

	summary_panel.visible = true
	summary_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(summary_panel, "modulate:a", 1.0, 0.3)

# --- Visual Effects ---
func _trigger_correct_vfx(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var tw = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.2)

	# Floating "+1" score popup
	_spawn_floating_text("+۱", btn.global_position + Vector2(btn.size.x * 0.5, 0), Color(0.35, 0.98, 0.52))

func _trigger_wrong_vfx(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var orig_pos = btn.position
	var tw = create_tween()
	for k in range(3):
		tw.tween_property(btn, "position:x", orig_pos.x + 8, 0.04)
		tw.tween_property(btn, "position:x", orig_pos.x - 8, 0.04)
	tw.tween_property(btn, "position:x", orig_pos.x, 0.04)

	# Floating "-1" score popup
	_spawn_floating_text("-۱", btn.global_position + Vector2(btn.size.x * 0.5, 0), Color(1.0, 0.35, 0.38))

func _spawn_floating_text(text: String, start_pos: Vector2, col: Color) -> void:
	if not is_instance_valid(vfx_particles_container):
		return
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = start_pos
	lbl.scale = Vector2(0.5, 0.5)
	vfx_particles_container.add_child(lbl)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", start_pos.y - 70.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_delay(0.5)
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
		header.update_scores(player_scores.get(1, 0), player_scores.get(2, 0))

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
	if payload.has("current_question") and typeof(payload["current_question"]) == TYPE_DICTIONARY:
		_handle_new_question_turn(payload["current_question"])
	elif payload.has("turn"):
		_handle_new_question_turn(payload)

	if payload.has("scores") and typeof(payload["scores"]) == TYPE_DICTIONARY:
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

func cleanup_board() -> void:
	if is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
	if is_instance_valid(stand_root):
		stand_root.queue_free()
