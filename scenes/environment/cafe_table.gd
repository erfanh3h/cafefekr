extends Node3D

signal camera_mode_changed(is_top_down: bool)

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer
@onready var candle_light: OmniLight3D = null

# Camera Presets
const CAM_POS_MENU: Vector3 = Vector3(0.0, 2.0, 2.7)
const CAM_ROT_MENU: Vector3 = Vector3(-28.0, 0.0, 0.0)

# Orbit & Zoom Configuration for Board View (Centered & Portrait-Friendly)
# Portrait aspect ratio (1080x1920) has a narrow horizontal FOV (~29.4 deg at V-FOV 50).
# Distance 3.20 guarantees a 1.3m wide 3D board + outer frame + side trays fit 100% inside the screen width!
const TARGET_FOCUS: Vector3 = Vector3(0.0, 0.08, 0.0)
const ZOOM_DEFAULT: float = 3.20
const ZOOM_MIN: float = 2.40
const ZOOM_MAX: float = 4.20

const YAW_DEFAULT: float = 0.0
const YAW_MIN: float = -0.55        # -31.5 degrees (Tighter yaw so board corners never clip horizontally)
const YAW_MAX: float = 0.55         # +31.5 degrees

const PITCH_DEFAULT: float = -0.733 # -42.0 degrees
const PITCH_MIN: float = -1.100     # -63.0 degrees
const PITCH_MAX: float = -0.580     # -33.2 degrees

# Sensitivity
const SENSITIVITY_YAW: float = 0.0035
const SENSITIVITY_PITCH: float = 0.0028
const SENSITIVITY_PINCH: float = 0.0035
const DRAG_THRESHOLD: float = 12.0

# Dynamic State
var is_board_view_active: bool = false
var is_transitioning: bool = false
var is_top_down_view: bool = false
var _camera_tween: Tween = null

func _kill_camera_tween() -> void:
	if _camera_tween and is_instance_valid(_camera_tween):
		_camera_tween.kill()
		_camera_tween = null

# Top-Down 2D Camera Heights (Meters above board center in portrait with FOV 50 deg)
# - Min (2.75m): Max zoom in -> full 1.30m board is 100% visible with safe padding on left and right!
# - Default (3.60m): Balanced view with comfortable wooden cafe table border around board
# - Max (5.20m): Max zoom out -> wide far view showing board, cafe table, and surrounding cafe environment
const TOP_DOWN_HEIGHT_DEFAULT: float = 3.60
const TOP_DOWN_HEIGHT_MIN: float = 2.75
const TOP_DOWN_HEIGHT_MAX: float = 5.20
const TOP_DOWN_ZOOM_STEP: float = 0.50
var top_down_target_height: float = TOP_DOWN_HEIGHT_DEFAULT
var top_down_current_height: float = TOP_DOWN_HEIGHT_DEFAULT

var target_distance: float = ZOOM_DEFAULT
var current_distance: float = ZOOM_DEFAULT
var target_yaw: float = YAW_DEFAULT
var current_yaw: float = YAW_DEFAULT
var target_pitch: float = PITCH_DEFAULT
var current_pitch: float = PITCH_DEFAULT

# Input tracking
var _is_dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _mouse_pressed: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _active_touches: Dictionary = {} # index -> Vector2
var _prev_pinch_dist: float = -1.0
var _last_tap_time: float = 0.0
var _last_tap_pos: Vector2 = Vector2.ZERO

# Atmosphere
var _flicker_timer: float = 0.0
var _flame_mesh: MeshInstance3D = null
var _flame_halo_mesh: MeshInstance3D = null
var current_board_node: Node3D = null

# Realistic Hands (No ugly bodies or chairs, only natural animated hands!)
const RealisticHandScript = preload("res://scenes/environment/realistic_hand.gd")
var enemy_hand: Node3D = null
var player_hand: Node3D = null

func _ready() -> void:
	add_to_group("cafe_table")
	if has_node("CafeProps/LanternGroup/CandleLight"):
		candle_light = get_node("CafeProps/LanternGroup/CandleLight")
	if has_node("CafeProps/CoffeeCupGroup"):
		get_node("CafeProps/CoffeeCupGroup").visible = false

	_build_luxury_game_environment()

	# Enemy Realistic Hand (comes in from opponent's side)
	enemy_hand = RealisticHandScript.new()
	enemy_hand.is_enemy = true
	enemy_hand.name = "EnemyHand"
	add_child(enemy_hand)

	# Player Realistic Hand (comes in from player's side)
	player_hand = RealisticHandScript.new()
	player_hand.is_enemy = false
	player_hand.name = "PlayerHand"
	add_child(player_hand)

	update_hand_colors()
	transition_to_menu_view(0.1)

func _process(delta: float) -> void:
	if is_board_view_active and not is_transitioning:
		if is_top_down_view:
			top_down_current_height = lerp(top_down_current_height, top_down_target_height, 10.0 * delta)
			camera.position = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_current_height, TARGET_FOCUS.z)
			camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		else:
			# Smooth spring dampening towards target yaw, pitch, and distance
			current_yaw = lerp(current_yaw, target_yaw, 10.0 * delta)
			current_pitch = lerp(current_pitch, target_pitch, 10.0 * delta)
			current_distance = lerp(current_distance, target_distance, 10.0 * delta)
			_apply_orbit_transform()

	# Cozy candlelight flickering
	if candle_light:
		_flicker_timer += delta * 5.5
		var pulse = sin(_flicker_timer) * 0.08 + sin(_flicker_timer * 2.3) * 0.05
		candle_light.light_energy = 0.72 + pulse
		if _flame_mesh and is_instance_valid(_flame_mesh):
			var s = 1.0 + pulse * 0.65
			_flame_mesh.scale = Vector3(1.0 - pulse * 0.25, s, 1.0 - pulse * 0.25)
		if _flame_halo_mesh and is_instance_valid(_flame_halo_mesh):
			var hs = 1.0 + pulse * 0.85
			_flame_halo_mesh.scale = Vector3(hs, hs, hs)

func _apply_orbit_transform() -> void:
	var cos_pitch = cos(-current_pitch)
	var sin_pitch = sin(-current_pitch)

	var cam_x = TARGET_FOCUS.x + current_distance * sin(current_yaw) * cos_pitch
	var cam_y = TARGET_FOCUS.y + current_distance * sin_pitch
	var cam_z = TARGET_FOCUS.z + current_distance * cos(current_yaw) * cos_pitch

	camera.position = Vector3(cam_x, cam_y, cam_z)
	camera.look_at(TARGET_FOCUS, Vector3.UP)

# --- Transitions ---

func transition_to_menu_view(duration: float = 1.0) -> void:
	_kill_camera_tween()
	is_board_view_active = false
	is_transitioning = true
	is_top_down_view = false
	camera_mode_changed.emit(false)
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", CAM_POS_MENU, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", CAM_ROT_MENU, duration)
	_camera_tween.chain().tween_callback(func():
		is_transitioning = false
		_camera_tween = null
	)

func transition_to_board_view(duration: float = 1.2) -> void:
	_kill_camera_tween()
	is_transitioning = true
	is_top_down_view = false
	camera_mode_changed.emit(false)
	var use_pitch = PITCH_DEFAULT
	var use_dist = ZOOM_DEFAULT
	if current_board_node:
		if "camera_pitch" in current_board_node:
			use_pitch = current_board_node.camera_pitch
		if "camera_distance" in current_board_node:
			use_dist = current_board_node.camera_distance
	target_distance = use_dist
	current_distance = use_dist
	target_yaw = YAW_DEFAULT
	current_yaw = YAW_DEFAULT
	target_pitch = use_pitch
	current_pitch = use_pitch

	var cos_pitch = cos(-use_pitch)
	var sin_pitch = sin(-use_pitch)
	var end_x = TARGET_FOCUS.x + use_dist * sin(YAW_DEFAULT) * cos_pitch
	var end_y = TARGET_FOCUS.y + use_dist * sin_pitch
	var end_z = TARGET_FOCUS.z + use_dist * cos(YAW_DEFAULT) * cos_pitch
	var end_pos = Vector3(end_x, end_y, end_z)

	# Compute target rotation
	var temp_cam = Camera3D.new()
	add_child(temp_cam)
	temp_cam.position = end_pos
	temp_cam.look_at(TARGET_FOCUS, Vector3.UP)
	var end_rot_deg = temp_cam.rotation_degrees
	temp_cam.queue_free()

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", end_pos, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", end_rot_deg, duration)
	_camera_tween.chain().tween_callback(func():
		is_board_view_active = true
		is_transitioning = false
		_camera_tween = null
	)

# --- Board Spawning & Lifecycle ---

func spawn_board(board_packed_scene: PackedScene) -> Node3D:
	clear_board()
	update_hand_colors()
	is_top_down_view = false
	camera_mode_changed.emit(false)
	if board_packed_scene:
		current_board_node = board_packed_scene.instantiate()
		board_container.add_child(current_board_node)
		if GameManager.current_game_type == GameTypes.TIC_TAC_TOE:
			if player_hand and is_instance_valid(player_hand):
				player_hand.visible = false
			if enemy_hand and is_instance_valid(enemy_hand):
				enemy_hand.visible = false
		transition_to_board_view(1.2)
	return current_board_node

func clear_board() -> void:
	_kill_camera_tween()
	if current_board_node and is_instance_valid(current_board_node):
		if current_board_node.has_method("cleanup_board"):
			current_board_node.cleanup_board()
		current_board_node.queue_free()
		current_board_node = null

func reset_table_state() -> void:
	_kill_camera_tween()
	is_board_view_active = false
	is_transitioning = false
	is_top_down_view = false
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	top_down_current_height = TOP_DOWN_HEIGHT_DEFAULT
	target_distance = ZOOM_DEFAULT
	current_distance = ZOOM_DEFAULT
	target_yaw = YAW_DEFAULT
	current_yaw = YAW_DEFAULT
	target_pitch = PITCH_DEFAULT
	current_pitch = PITCH_DEFAULT
	camera_mode_changed.emit(false)
	set_opponent_thinking(false)

# --- Public Camera Control API (for HUD or Gestures) ---

func toggle_top_down_view() -> void:
	set_top_down_view(not is_top_down_view)

func set_top_down_view(enabled: bool, duration: float = 0.55) -> void:
	if is_top_down_view == enabled:
		return
	_kill_camera_tween()
	is_top_down_view = enabled
	camera_mode_changed.emit(is_top_down_view)
	is_transitioning = true

	var end_pos = Vector3.ZERO
	var end_rot_deg = Vector3.ZERO

	if is_top_down_view:
		top_down_current_height = top_down_target_height
		end_pos = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_target_height, TARGET_FOCUS.z)
		end_rot_deg = Vector3(-90.0, 0.0, 0.0)
	else:
		var cos_pitch = cos(-target_pitch)
		var sin_pitch = sin(-target_pitch)
		var end_x = TARGET_FOCUS.x + target_distance * sin(target_yaw) * cos_pitch
		var end_y = TARGET_FOCUS.y + target_distance * sin_pitch
		var end_z = TARGET_FOCUS.z + target_distance * cos(target_yaw) * cos_pitch
		end_pos = Vector3(end_x, end_y, end_z)

		var temp_cam = Camera3D.new()
		add_child(temp_cam)
		temp_cam.position = end_pos
		temp_cam.look_at(TARGET_FOCUS, Vector3.UP)
		end_rot_deg = temp_cam.rotation_degrees
		temp_cam.queue_free()

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", end_pos, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", end_rot_deg, duration)
	_camera_tween.chain().tween_callback(func():
		is_transitioning = false
		_camera_tween = null
	)

func reset_camera_orbit() -> void:
	if is_top_down_view:
		set_top_down_view(false, 0.5)
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	target_yaw = YAW_DEFAULT
	var def_pitch = PITCH_DEFAULT
	var def_dist = ZOOM_DEFAULT
	if current_board_node:
		if "camera_pitch" in current_board_node:
			def_pitch = current_board_node.camera_pitch
		if "camera_distance" in current_board_node:
			def_dist = current_board_node.camera_distance
	target_pitch = def_pitch
	target_distance = def_dist

func zoom_in(step: float = 0.28) -> void:
	if is_top_down_view:
		top_down_target_height = clampf(top_down_target_height - TOP_DOWN_ZOOM_STEP, TOP_DOWN_HEIGHT_MIN, TOP_DOWN_HEIGHT_MAX)
	else:
		target_distance = clampf(target_distance - step, ZOOM_MIN, ZOOM_MAX)

func zoom_out(step: float = 0.28) -> void:
	if is_top_down_view:
		top_down_target_height = clampf(top_down_target_height + TOP_DOWN_ZOOM_STEP, TOP_DOWN_HEIGHT_MIN, TOP_DOWN_HEIGHT_MAX)
	else:
		target_distance = clampf(target_distance + step, ZOOM_MIN, ZOOM_MAX)

# --- Realistic Hand Piece Placement ---

func update_opponent_avatar(_avatar_id: int) -> void:
	pass

func update_hand_colors() -> void:
	var my_idx = GameManager.my_player_index
	# Player 1 is Red, Player 2 is Blue
	var player_col = RealisticHandScript.COLOR_RED_CLOTH if my_idx == 1 else RealisticHandScript.COLOR_BLUE_CLOTH
	var enemy_col = RealisticHandScript.COLOR_BLUE_CLOTH if my_idx == 1 else RealisticHandScript.COLOR_RED_CLOTH
	if player_hand and is_instance_valid(player_hand):
		player_hand.set_cloth_color(player_col)
	if enemy_hand and is_instance_valid(enemy_hand):
		enemy_hand.set_cloth_color(enemy_col)

func set_opponent_thinking(_thinking: bool) -> void:
	pass

func play_opponent_reaction() -> void:
	pass

func animate_place_piece(user_id: int, target_world_pos: Vector3, piece_node: Node3D, on_dropped: Callable) -> void:
	if GameManager.current_game_type == GameTypes.TIC_TAC_TOE:
		if player_hand and is_instance_valid(player_hand):
			player_hand.visible = false
		if enemy_hand and is_instance_valid(enemy_hand):
			enemy_hand.visible = false
		if on_dropped.is_valid():
			on_dropped.call()
		return
	update_hand_colors()
	if user_id == GameManager.my_player_index:
		if player_hand and is_instance_valid(player_hand):
			player_hand.play_place_piece(target_world_pos, piece_node, on_dropped)
		else:
			if on_dropped.is_valid():
				on_dropped.call()
	else:
		if enemy_hand and is_instance_valid(enemy_hand):
			enemy_hand.play_place_piece(target_world_pos, piece_node, on_dropped)
		else:
			if on_dropped.is_valid():
				on_dropped.call()

# --- Input Handling for Orbit & Zoom ---

func _is_board_consuming_input() -> bool:
	if not current_board_node or not is_instance_valid(current_board_node):
		return false
	if current_board_node.has_method("is_interacting_with_piece") and current_board_node.is_interacting_with_piece():
		return true
	if "is_dragging_piece" in current_board_node and current_board_node.is_dragging_piece:
		return true
	return false

func _get_effective_pitch_min() -> float:
	var p_min = PITCH_MIN
	if current_board_node and is_instance_valid(current_board_node) and "camera_pitch" in current_board_node:
		p_min = minf(p_min, float(current_board_node.camera_pitch) - 0.05)
	return p_min

func _unhandled_input(event: InputEvent) -> void:
	if not is_board_view_active or is_transitioning:
		return
	if _is_board_consuming_input():
		_mouse_pressed = false
		_is_dragging = false
		_active_touches.clear()
		_prev_pinch_dist = -1.0
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_in(0.25)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_out(0.25)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_pressed = true
			_mouse_start_pos = event.position
			_is_dragging = false
		else:
			var was_pressed = _mouse_pressed
			_mouse_pressed = false
			if was_pressed and not _is_dragging:
				_check_double_tap(event.position)
			_is_dragging = false

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _mouse_pressed:
		if not _is_dragging:
			if event.position.distance_to(_mouse_start_pos) > DRAG_THRESHOLD:
				_is_dragging = true
		if _is_dragging:
			if is_top_down_view:
				is_top_down_view = false
				camera_mode_changed.emit(false)
			target_yaw -= event.relative.x * SENSITIVITY_YAW
			target_pitch -= event.relative.y * SENSITIVITY_PITCH
			target_yaw = clampf(target_yaw, YAW_MIN, YAW_MAX)
			target_pitch = clampf(target_pitch, _get_effective_pitch_min(), PITCH_MAX)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_active_touches[event.index] = event.position
		if _active_touches.size() == 1:
			_drag_start_pos = event.position
			_is_dragging = false
		elif _active_touches.size() == 2:
			var pts = _active_touches.values()
			_prev_pinch_dist = pts[0].distance_to(pts[1])
	else:
		var had_touch = _active_touches.has(event.index)
		_active_touches.erase(event.index)
		if _active_touches.size() < 2:
			_prev_pinch_dist = -1.0
		if _active_touches.is_empty():
			if had_touch and not _is_dragging:
				_check_double_tap(event.position)
			_is_dragging = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		return
	_active_touches[event.index] = event.position
	if _active_touches.size() >= 2:
		var pts = _active_touches.values()
		var current_dist = pts[0].distance_to(pts[1])
		if _prev_pinch_dist > 0.0:
			var delta_dist = current_dist - _prev_pinch_dist
			if is_top_down_view:
				top_down_target_height = clampf(top_down_target_height - delta_dist * 0.0055, TOP_DOWN_HEIGHT_MIN, TOP_DOWN_HEIGHT_MAX)
			else:
				target_distance = clampf(target_distance - delta_dist * SENSITIVITY_PINCH, ZOOM_MIN, ZOOM_MAX)
		_prev_pinch_dist = current_dist
	else:
		if not _is_dragging:
			if event.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
				_is_dragging = true
		if _is_dragging:
			if is_top_down_view:
				is_top_down_view = false
				camera_mode_changed.emit(false)
			target_yaw -= event.relative.x * SENSITIVITY_YAW
			target_pitch -= event.relative.y * SENSITIVITY_PITCH
			target_yaw = clampf(target_yaw, YAW_MIN, YAW_MAX)
			target_pitch = clampf(target_pitch, _get_effective_pitch_min(), PITCH_MAX)

func _check_double_tap(pos: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time < 0.35 and pos.distance_to(_last_tap_pos) < 40.0:
		reset_camera_orbit()
		_last_tap_time = 0.0
	else:
		_last_tap_time = now
		_last_tap_pos = pos

# ============================================================================
# LUXURY 3D BOARD-GAME CAFE TABLE & RECOGNIZABLE PROPS BUILDER
# ============================================================================

func _make_mat(albedo: Color, rough: float = 0.4, metal: float = 0.0, clearcoat: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if clearcoat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = clearcoat
		m.clearcoat_roughness = 0.12
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 24) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _add_sphere(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _add_torus(parent: Node3D, inner_r: float, outer_r: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	tm.rings = 24
	tm.ring_segments = 16
	tm.material = mat
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

func _build_luxury_game_environment() -> void:
	var props_root = get_node_or_null("CafeProps")
	if not props_root:
		props_root = Node3D.new()
		props_root.name = "CafeProps"
		add_child(props_root)

	# Shared Crafted Materials
	var mat_brass = _make_mat(Color(0.90, 0.73, 0.28), 0.22, 0.88, 0.35)
	var mat_aged_brass = _make_mat(Color(0.74, 0.56, 0.20), 0.34, 0.82)
	var mat_copper = _make_mat(Color(0.84, 0.48, 0.28), 0.26, 0.85)
	var mat_silver = _make_mat(Color(0.86, 0.88, 0.92), 0.20, 0.90)
	var mat_dark_walnut = _make_mat(Color(0.20, 0.11, 0.06), 0.36, 0.04, 0.45)
	var mat_mahogany = _make_mat(Color(0.34, 0.16, 0.08), 0.32, 0.05, 0.55)
	var mat_ebony = _make_mat(Color(0.11, 0.09, 0.08), 0.28, 0.12, 0.40)
	var mat_baize_emerald = _make_mat(Color(0.08, 0.21, 0.16), 0.86, 0.0)
	var mat_baize_crimson = _make_mat(Color(0.46, 0.09, 0.11), 0.82, 0.0)
	var mat_leather_dark = _make_mat(Color(0.22, 0.12, 0.07), 0.55, 0.05)
	var mat_leather_saddle = _make_mat(Color(0.42, 0.23, 0.11), 0.52, 0.04)
	var mat_ivory = _make_mat(Color(0.97, 0.94, 0.86), 0.18, 0.02, 0.65)
	var mat_porcelain = _make_mat(Color(0.96, 0.95, 0.92), 0.12, 0.02, 0.90)
	var mat_porcelain_blue = _make_mat(Color(0.16, 0.34, 0.64), 0.16, 0.05, 0.85)
	var mat_paper_cream = _make_mat(Color(0.95, 0.91, 0.81), 0.72, 0.0)
	var mat_ruby = _make_mat(Color(0.78, 0.12, 0.18), 0.18, 0.15, 0.80)
	var mat_sapphire = _make_mat(Color(0.14, 0.36, 0.82), 0.18, 0.15, 0.80)
	var mat_emerald_gem = _make_mat(Color(0.12, 0.62, 0.36), 0.18, 0.15, 0.80)

	var mat_clear_glass = StandardMaterial3D.new()
	mat_clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_clear_glass.albedo_color = Color(0.94, 0.97, 1.0, 0.30)
	mat_clear_glass.roughness = 0.06
	mat_clear_glass.metallic = 0.10
	mat_clear_glass.clearcoat_enabled = true
	mat_clear_glass.clearcoat = 1.0

	var mat_amber_glass = StandardMaterial3D.new()
	mat_amber_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_amber_glass.albedo_color = Color(1.0, 0.84, 0.48, 0.34)
	mat_amber_glass.roughness = 0.08
	mat_amber_glass.clearcoat_enabled = true
	mat_amber_glass.clearcoat = 0.9

	var mat_persian_tea = StandardMaterial3D.new()
	mat_persian_tea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_persian_tea.albedo_color = Color(0.58, 0.09, 0.03, 0.88)
	mat_persian_tea.roughness = 0.05
	mat_persian_tea.clearcoat_enabled = true
	mat_persian_tea.clearcoat = 1.0

	var mat_amber_glow = StandardMaterial3D.new()
	mat_amber_glow.albedo_color = Color(1.0, 0.82, 0.32)
	mat_amber_glow.emission_enabled = true
	mat_amber_glow.emission = Color(1.0, 0.72, 0.22)
	mat_amber_glow.emission_energy_multiplier = 2.4

	# 1. GRAND INLAID GAMING TABLE ARENA SURFACE
	_build_inlaid_table_arena(mat_dark_walnut, mat_mahogany, mat_brass, mat_aged_brass, mat_baize_emerald, mat_amber_glow)

	# 2. MOROCCAN / PERSIAN FILIGREE BRASS LANTERN (Upper-Left Arena Corner)
	_upgrade_lantern_prop(mat_brass, mat_aged_brass, mat_amber_glass, mat_ivory, mat_amber_glow)

	# 3. TRADITIONAL PERSIAN TEA SERVICE ON HAMMERED BRASS TRAY (Upper-Right Arena Corner)
	_build_persian_tea_service(props_root, Vector3(0.66, 0.063, -1.12), mat_brass, mat_aged_brass, mat_porcelain, mat_porcelain_blue, mat_clear_glass, mat_persian_tea, mat_ivory)

	# 4. STITCHED LEATHER DICE CUP & 3 SCULPTED IVORY 6-SIDED DICE WITH REAL 3D PIPS (Upper-Center-Left)
	_build_dice_cup_and_dice(props_root, Vector3(-0.30, 0.063, -1.14), mat_leather_dark, mat_brass, mat_baize_crimson, mat_ivory, mat_ebony, mat_ruby)

	# 5. ANTIQUE BRASS & WALNUT MATCH HOURGLASS / SAND TIMER (Upper-Center-Right)
	_build_brass_hourglass(props_root, Vector3(0.28, 0.063, -1.14), mat_dark_walnut, mat_brass, mat_clear_glass, mat_amber_glow)

	# 6. ROYAL VELVET GAMING TOKEN BOWL & STACKED GOLD/GEM MATCH COINS (Front-Left Arena Corner)
	_build_token_bowl_and_coins(props_root, Vector3(-0.64, 0.063, 1.06), mat_mahogany, mat_brass, mat_silver, mat_baize_crimson, mat_ruby, mat_sapphire, mat_emerald_gem)

	# 7. LEATHER MATCH SCOREBOOK & BRASS FOUNTAIN PEN (Front-Right Arena Corner)
	_build_scorebook_and_pen(props_root, Vector3(0.64, 0.063, 1.06), mat_leather_saddle, mat_brass, mat_paper_cream, mat_ebony, mat_ruby)

	# 8. GOLDEN CHAMPION TROPHY & VINTAGE POCKET CHRONOMETER (Left & Right Table Wings)
	_build_champion_trophy(props_root, Vector3(-1.04, 0.063, -0.16), mat_dark_walnut, mat_ivory, mat_brass, mat_ruby)
	_build_pocket_chronometer(props_root, Vector3(1.04, 0.063, 0.14), mat_brass, mat_aged_brass, mat_porcelain, mat_ebony, mat_clear_glass)


func _build_inlaid_table_arena(mat_walnut: Material, mat_mahogany: Material, mat_brass: Material, mat_aged_brass: Material, mat_baize: Material, mat_glow: Material) -> void:
	var table_root = get_node_or_null("TableRoot")
	if not table_root:
		return

	# Upgrade existing TableMat to a full-size royal emerald-charcoal gaming baize
	if table_root.has_node("TableMat"):
		var tm_node: MeshInstance3D = table_root.get_node("TableMat")
		var bm = BoxMesh.new()
		bm.size = Vector3(1.84, 0.006, 1.94)
		bm.material = mat_baize
		tm_node.mesh = bm
		tm_node.position = Vector3(0.0, 0.062, 0.0)

	var arena_frame = Node3D.new()
	arena_frame.name = "LuxuryArenaFrame"
	table_root.add_child(arena_frame)

	var y_base: float = 0.064
	var half_x: float = 0.93
	var half_z: float = 0.98
	var bar_w: float = 0.048
	var bar_h: float = 0.012

	# Inner gold-thread pinstripe frame on the gaming felt
	_add_box(arena_frame, Vector3(1.76, 0.002, 0.008), Vector3(0.0, 0.0655, -0.92), mat_aged_brass)
	_add_box(arena_frame, Vector3(1.76, 0.002, 0.008), Vector3(0.0, 0.0655, 0.92), mat_aged_brass)
	_add_box(arena_frame, Vector3(0.008, 0.002, 1.84), Vector3(-0.88, 0.0655, 0.0), mat_aged_brass)
	_add_box(arena_frame, Vector3(0.008, 0.002, 1.84), Vector3(0.88, 0.0655, 0.0), mat_aged_brass)

	# Carved mahogany & brass arena border rails surrounding the central gaming zone
	_add_box(arena_frame, Vector3(half_x * 2.0 + bar_w, bar_h, bar_w), Vector3(0.0, y_base + bar_h * 0.5, -half_z), mat_mahogany)
	_add_box(arena_frame, Vector3(half_x * 2.0 + bar_w, bar_h, bar_w), Vector3(0.0, y_base + bar_h * 0.5, half_z), mat_mahogany)
	_add_box(arena_frame, Vector3(bar_w, bar_h, half_z * 2.0 - bar_w), Vector3(-half_x, y_base + bar_h * 0.5, 0.0), mat_mahogany)
	_add_box(arena_frame, Vector3(bar_w, bar_h, half_z * 2.0 - bar_w), Vector3(half_x, y_base + bar_h * 0.5, 0.0), mat_mahogany)

	# Top brushed-brass inlay strips on the mahogany rails
	_add_box(arena_frame, Vector3(half_x * 2.0, 0.003, 0.012), Vector3(0.0, y_base + bar_h + 0.001, -half_z), mat_brass)
	_add_box(arena_frame, Vector3(half_x * 2.0, 0.003, 0.012), Vector3(0.0, y_base + bar_h + 0.001, half_z), mat_brass)
	_add_box(arena_frame, Vector3(0.012, 0.003, half_z * 2.0), Vector3(-half_x, y_base + bar_h + 0.001, 0.0), mat_brass)
	_add_box(arena_frame, Vector3(0.012, 0.003, half_z * 2.0), Vector3(half_x, y_base + bar_h + 0.001, 0.0), mat_brass)

	# 4 Corner Brass Medallions + 4 Cardinal Brass Rosettes
	var corners = [
		Vector3(-half_x, y_base, -half_z),
		Vector3(half_x, y_base, -half_z),
		Vector3(-half_x, y_base, half_z),
		Vector3(half_x, y_base, half_z)
	]
	for c_pos in corners:
		_add_cyl(arena_frame, 0.042, 0.046, 0.016, c_pos + Vector3(0, 0.008, 0), mat_brass, Vector3.ZERO, 8)
		_add_cyl(arena_frame, 0.026, 0.028, 0.019, c_pos + Vector3(0, 0.0095, 0), mat_walnut, Vector3.ZERO, 8)
		_add_sphere(arena_frame, 0.011, 0.010, c_pos + Vector3(0, 0.019, 0), mat_glow)

	var cardinals = [
		Vector3(0.0, y_base, -half_z),
		Vector3(0.0, y_base, half_z),
		Vector3(-half_x, y_base, 0.0),
		Vector3(half_x, y_base, 0.0)
	]
	for m_pos in cardinals:
		_add_cyl(arena_frame, 0.024, 0.026, 0.015, m_pos + Vector3(0, 0.0075, 0), mat_brass, Vector3.ZERO, 16)
		_add_sphere(arena_frame, 0.008, 0.008, m_pos + Vector3(0, 0.015, 0), mat_glow)

	# Outer Table Perimeter Molding & Brass Inlay Frame (at ±1.42m so wide camera views look rich)
	var outer_r: float = 1.42
	var outer_w: float = 0.022
	_add_box(arena_frame, Vector3(outer_r * 2.0, 0.005, outer_w), Vector3(0.0, 0.0625, -outer_r), mat_aged_brass)
	_add_box(arena_frame, Vector3(outer_r * 2.0, 0.005, outer_w), Vector3(0.0, 0.0625, outer_r), mat_aged_brass)
	_add_box(arena_frame, Vector3(outer_w, 0.005, outer_r * 2.0), Vector3(-outer_r, 0.0625, 0.0), mat_aged_brass)
	_add_box(arena_frame, Vector3(outer_w, 0.005, outer_r * 2.0), Vector3(outer_r, 0.0625, 0.0), mat_aged_brass)


func _upgrade_lantern_prop(mat_brass: Material, mat_aged_brass: Material, mat_amber_glass: Material, mat_wax: Material, mat_flame: Material) -> void:
	var lantern = get_node_or_null("CafeProps/LanternGroup")
	if not lantern:
		return

	# Position in Upper-Left Arena Corner so it is 100% visible in portrait 3D & 2D views
	lantern.position = Vector3(-0.68, 0.063, -1.12)

	# Hide simple placeholder meshes so we can replace with ornate Moroccan/Persian lantern geometry
	if lantern.has_node("LanternBase"):
		lantern.get_node("LanternBase").visible = false
	if lantern.has_node("LanternGlass"):
		lantern.get_node("LanternGlass").visible = false
	if lantern.has_node("Flame"):
		_flame_mesh = lantern.get_node("Flame")
		_flame_mesh.position = Vector3(0.0, 0.145, 0.0)

	# Coaster / Engraved Brass Under-Plate
	_add_cyl(lantern, 0.125, 0.135, 0.010, Vector3(0, 0.005, 0), mat_aged_brass, Vector3.ZERO, 8)
	# Stepped Hexagonal Brass Base
	_add_cyl(lantern, 0.095, 0.112, 0.024, Vector3(0, 0.022, 0), mat_brass, Vector3.ZERO, 6)
	_add_torus(lantern, 0.082, 0.096, Vector3(0, 0.035, 0), mat_brass)

	# Inner Cream Wax Pillar Candle + Wick
	_add_cyl(lantern, 0.034, 0.036, 0.085, Vector3(0, 0.076, 0), mat_wax, Vector3.ZERO, 18)
	_add_cyl(lantern, 0.003, 0.003, 0.016, Vector3(0, 0.124, 0), mat_aged_brass, Vector3.ZERO, 8)

	# Soft Glowing Flame Halo
	var mat_halo = StandardMaterial3D.new()
	mat_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo.albedo_color = Color(1.0, 0.65, 0.18, 0.32)
	mat_halo.emission_enabled = true
	mat_halo.emission = Color(1.0, 0.58, 0.12)
	mat_halo.emission_energy_multiplier = 2.2
	_flame_halo_mesh = _add_sphere(lantern, 0.038, 0.075, Vector3(0, 0.145, 0), mat_halo)

	# Hexagonal Blown Amber Glass Cylinder
	_add_cyl(lantern, 0.084, 0.076, 0.175, Vector3(0, 0.122, 0), mat_amber_glass, Vector3.ZERO, 6)

	# 6 Filigree Brass Cage Pillars around the glass
	for i in range(6):
		var angle = float(i) * PI / 3.0 + PI / 6.0
		var r = 0.088
		var px = cos(angle) * r
		var pz = sin(angle) * r
		_add_cyl(lantern, 0.0055, 0.0055, 0.185, Vector3(px, 0.124, pz), mat_brass, Vector3.ZERO, 8)
		# Small decorative finial spheres above each pillar
		_add_sphere(lantern, 0.009, 0.018, Vector3(px, 0.226, pz), mat_brass)

	# Upper Gallery Ring & Pierced Brass Dome Cap
	_add_cyl(lantern, 0.096, 0.092, 0.016, Vector3(0, 0.214, 0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(lantern, 0.048, 0.090, 0.052, Vector3(0, 0.248, 0), mat_aged_brass, Vector3.ZERO, 6)
	_add_cyl(lantern, 0.008, 0.046, 0.038, Vector3(0, 0.292, 0), mat_brass, Vector3.ZERO, 6)
	_add_sphere(lantern, 0.014, 0.028, Vector3(0, 0.316, 0), mat_brass)
	# Top Hanging Ring
	_add_torus(lantern, 0.014, 0.022, Vector3(0, 0.338, 0), mat_brass, Vector3(90, 0, 0))


func _build_persian_tea_service(parent: Node3D, pos: Vector3, mat_brass: Material, mat_aged_brass: Material, mat_porcelain: Material, mat_blue: Material, mat_glass: Material, mat_tea: Material, mat_sugar: Material) -> void:
	var tea_group = Node3D.new()
	tea_group.name = "PersianTeaService"
	tea_group.position = pos
	tea_group.rotation_degrees = Vector3(0, -18.0, 0)
	parent.add_child(tea_group)

	# 1. Engraved Hammered Brass Tray (سینی برنجی)
	_add_cyl(tea_group, 0.185, 0.175, 0.008, Vector3(0, 0.004, 0), mat_aged_brass, Vector3.ZERO, 32)
	_add_cyl(tea_group, 0.165, 0.165, 0.009, Vector3(0, 0.005, 0), mat_brass, Vector3.ZERO, 32)
	_add_torus(tea_group, 0.172, 0.186, Vector3(0, 0.011, 0), mat_brass)
	# Brass Tray Side Handles
	_add_torus(tea_group, 0.018, 0.026, Vector3(-0.192, 0.014, 0), mat_brass, Vector3(0, 0, 20))
	_add_torus(tea_group, 0.018, 0.026, Vector3(0.192, 0.014, 0), mat_brass, Vector3(0, 0, -20))

	# 2. Hand-Painted Porcelain Teapot (قوری چینی گل‌سرخی / آبی) on Left of Tray
	var pot = Node3D.new()
	pot.position = Vector3(-0.058, 0.009, -0.028)
	pot.rotation_degrees = Vector3(0, 28.0, 0)
	tea_group.add_child(pot)
	# Teapot Foot & Plump Belly
	_add_cyl(pot, 0.044, 0.048, 0.014, Vector3(0, 0.007, 0), mat_brass, Vector3.ZERO, 20)
	_add_sphere(pot, 0.068, 0.115, Vector3(0, 0.062, 0), mat_porcelain)
	# Royal Blue Decorative Waist Band & Gold Rim
	_add_torus(pot, 0.056, 0.069, Vector3(0, 0.064, 0), mat_blue)
	_add_torus(pot, 0.036, 0.044, Vector3(0, 0.112, 0), mat_brass)
	# Domed Lid & Gold Finial
	_add_sphere(pot, 0.038, 0.036, Vector3(0, 0.120, 0), mat_porcelain)
	_add_sphere(pot, 0.011, 0.022, Vector3(0, 0.142, 0), mat_brass)
	# Curved Teapot Handle
	_add_torus(pot, 0.022, 0.032, Vector3(-0.066, 0.070, 0), mat_porcelain, Vector3(90, 0, 0))
	# Angled Pouring Spout
	_add_cyl(pot, 0.009, 0.020, 0.072, Vector3(0.068, 0.076, 0), mat_porcelain, Vector3(0, 0, -42), 14)
	_add_torus(pot, 0.007, 0.011, Vector3(0.092, 0.100, 0), mat_brass, Vector3(0, 0, -42))

	# 3. Waisted Persian Tea Glass (استکان کمرباریک) in Filigree Brass Holder on Right-Front of Tray
	var istikan = Node3D.new()
	istikan.position = Vector3(0.068, 0.009, 0.042)
	tea_group.add_child(istikan)
	# Porcelain & Gold Saucer (نعلبکی)
	_add_cyl(istikan, 0.054, 0.034, 0.010, Vector3(0, 0.005, 0), mat_porcelain, Vector3.ZERO, 24)
	_add_torus(istikan, 0.046, 0.054, Vector3(0, 0.010, 0), mat_brass)
	# Filigree Brass Cup Holder Base & Handle
	_add_cyl(istikan, 0.030, 0.025, 0.036, Vector3(0, 0.028, 0), mat_brass, Vector3.ZERO, 16)
	_add_torus(istikan, 0.014, 0.020, Vector3(0.034, 0.042, 0), mat_brass, Vector3(90, 0, 0))
	# Waisted Glass (Lower bulb + narrow waist + flared upper rim)
	_add_cyl(istikan, 0.022, 0.026, 0.036, Vector3(0, 0.032, 0), mat_glass, Vector3.ZERO, 20)
	_add_cyl(istikan, 0.031, 0.022, 0.044, Vector3(0, 0.072, 0), mat_glass, Vector3.ZERO, 20)
	_add_torus(istikan, 0.028, 0.032, Vector3(0, 0.094, 0), mat_brass)
	# Crimson-Amber Persian Tea Fill Inside
	_add_cyl(istikan, 0.021, 0.024, 0.032, Vector3(0, 0.031, 0), mat_tea, Vector3.ZERO, 18)
	_add_cyl(istikan, 0.028, 0.021, 0.034, Vector3(0, 0.064, 0), mat_tea, Vector3.ZERO, 18)
	# Miniature Golden Tea Spoon on Saucer
	_add_box(istikan, Vector3(0.056, 0.002, 0.005), Vector3(-0.012, 0.012, 0.034), mat_brass, Vector3(0, 22, 0))
	_add_sphere(istikan, 0.008, 0.004, Vector3(0.014, 0.012, 0.024), mat_brass)

	# 4. Brass Sugar Bowl with Sugar Cubes (قندان برنجی و حبه‌های قند) on Right-Back of Tray
	var qandan = Node3D.new()
	qandan.position = Vector3(0.064, 0.009, -0.058)
	tea_group.add_child(qandan)
	_add_cyl(qandan, 0.026, 0.034, 0.014, Vector3(0, 0.007, 0), mat_brass, Vector3.ZERO, 18)
	_add_sphere(qandan, 0.040, 0.048, Vector3(0, 0.032, 0), mat_brass)
	_add_torus(qandan, 0.032, 0.038, Vector3(0, 0.046, 0), mat_aged_brass)
	# Sugar cubes heaped inside
	_add_box(qandan, Vector3(0.016, 0.014, 0.016), Vector3(-0.008, 0.052, -0.004), mat_sugar, Vector3(8, 15, -6))
	_add_box(qandan, Vector3(0.016, 0.014, 0.016), Vector3(0.010, 0.053, 0.005), mat_sugar, Vector3(-10, 35, 12))
	_add_box(qandan, Vector3(0.015, 0.014, 0.015), Vector3(0.0, 0.062, -0.002), mat_sugar, Vector3(14, -20, 5))


func _build_dice_cup_and_dice(parent: Node3D, pos: Vector3, mat_leather: Material, mat_brass: Material, mat_felt: Material, mat_ivory: Material, mat_pip_dark: Material, mat_pip_red: Material) -> void:
	var dice_group = Node3D.new()
	dice_group.name = "DiceCupAndDice"
	dice_group.position = pos
	parent.add_child(dice_group)

	# 1. Stitched Leather Dice Shaker Cup with Brass Rings & Crimson Felt Interior
	var cup = Node3D.new()
	cup.position = Vector3(-0.055, 0.0, -0.015)
	cup.rotation_degrees = Vector3(6.0, 18.0, -8.0)
	dice_group.add_child(cup)
	_add_cyl(cup, 0.044, 0.036, 0.105, Vector3(0, 0.0525, 0), mat_leather, Vector3.ZERO, 24)
	# Brass Ribs
	_add_torus(cup, 0.034, 0.039, Vector3(0, 0.014, 0), mat_brass)
	_add_torus(cup, 0.038, 0.043, Vector3(0, 0.054, 0), mat_brass)
	_add_torus(cup, 0.041, 0.046, Vector3(0, 0.098, 0), mat_brass)
	# Inner Crimson Velvet Top Opening
	_add_cyl(cup, 0.039, 0.037, 0.008, Vector3(0, 0.102, 0), mat_felt, Vector3.ZERO, 20)

	# 2. Three Sculpted Ivory 6-Sided Game Dice with Real 3D Pips
	_create_single_die(dice_group, Vector3(0.032, 0.022, 0.024), Vector3(0, 24.0, 0), 0.042, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)
	_create_single_die(dice_group, Vector3(0.088, 0.022, -0.014), Vector3(90.0, -32.0, 0), 0.040, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)
	_create_single_die(dice_group, Vector3(0.018, 0.020, -0.042), Vector3(0, 62.0, 90.0), 0.038, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)


func _create_single_die(parent: Node3D, pos: Vector3, rot_deg: Vector3, s: float, mat_ivory: Material, mat_brass: Material, mat_dark: Material, mat_red: Material) -> void:
	var die = Node3D.new()
	die.position = pos
	die.rotation_degrees = rot_deg
	parent.add_child(die)

	# Inner brass core slightly wider on corners + 3 overlapping ivory boxes for beveled-cube look
	_add_box(die, Vector3(s * 0.94, s * 0.94, s * 0.94), Vector3.ZERO, mat_brass)
	_add_box(die, Vector3(s, s * 0.88, s * 0.88), Vector3.ZERO, mat_ivory)
	_add_box(die, Vector3(s * 0.88, s, s * 0.88), Vector3.ZERO, mat_ivory)
	_add_box(die, Vector3(s * 0.88, s * 0.88, s), Vector3.ZERO, mat_ivory)

	var h: float = s * 0.502
	var d: float = s * 0.24
	var pr: float = s * 0.095

	# Top Face (+Y): 1 Red Bullseye Pip (Traditional Asian/Persian High-Roll Ace)
	_add_sphere(die, pr * 1.35, pr * 0.7, Vector3(0, h, 0), mat_red)

	# Bottom Face (-Y): 6 Pips
	for px in [-d, d]:
		for pz in [-d, 0.0, d]:
			_add_sphere(die, pr, pr * 0.6, Vector3(px, -h, pz), mat_dark)

	# Front Face (+Z): 5 Pips
	for offset in [Vector2(0, 0), Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]:
		_add_sphere(die, pr, pr * 0.6, Vector3(offset.x, offset.y, h), mat_dark)

	# Back Face (-Z): 2 Pips
	for offset in [Vector2(-d, -d), Vector2(d, d)]:
		_add_sphere(die, pr, pr * 0.6, Vector3(offset.x, offset.y, -h), mat_dark)

	# Right Face (+X): 4 Red Pips
	for offset in [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]:
		_add_sphere(die, pr, pr * 0.6, Vector3(h, offset.x, offset.y), mat_red)

	# Left Face (-X): 3 Pips
	for offset in [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)]:
		_add_sphere(die, pr, pr * 0.6, Vector3(-h, offset.x, offset.y), mat_dark)


func _build_brass_hourglass(parent: Node3D, pos: Vector3, mat_walnut: Material, mat_brass: Material, mat_glass: Material, mat_sand: Material) -> void:
	var hg = Node3D.new()
	hg.name = "BrassHourglass"
	hg.position = pos
	hg.rotation_degrees = Vector3(0, 15.0, 0)
	parent.add_child(hg)

	# Hexagonal Walnut & Brass Base Plate
	_add_cyl(hg, 0.074, 0.080, 0.014, Vector3(0, 0.007, 0), mat_walnut, Vector3.ZERO, 6)
	_add_cyl(hg, 0.066, 0.070, 0.006, Vector3(0, 0.017, 0), mat_brass, Vector3.ZERO, 6)

	# Hexagonal Walnut & Brass Top Plate
	_add_cyl(hg, 0.070, 0.066, 0.006, Vector3(0, 0.193, 0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(hg, 0.080, 0.074, 0.014, Vector3(0, 0.203, 0), mat_walnut, Vector3.ZERO, 6)

	# 4 Turned Brass Baluster Rods
	for i in range(4):
		var ang = float(i) * PI * 0.5 + PI * 0.25
		var rx = cos(ang) * 0.056
		var rz = sin(ang) * 0.056
		_add_cyl(hg, 0.005, 0.005, 0.176, Vector3(rx, 0.105, rz), mat_brass, Vector3.ZERO, 10)
		_add_sphere(hg, 0.009, 0.016, Vector3(rx, 0.105, rz), mat_brass)
		_add_sphere(hg, 0.009, 0.014, Vector3(rx, 0.214, rz), mat_brass)

	# Lower & Upper Glass Bulbs + Brass Center Waist Ring
	_add_cyl(hg, 0.010, 0.046, 0.082, Vector3(0, 0.061, 0), mat_glass, Vector3.ZERO, 20)
	_add_cyl(hg, 0.046, 0.010, 0.082, Vector3(0, 0.149, 0), mat_glass, Vector3.ZERO, 20)
	_add_torus(hg, 0.011, 0.018, Vector3(0, 0.105, 0), mat_brass)

	# Golden Sand Mound in Bottom Bulb + Remaining Sand in Top Bulb + Thin Falling Sand Stream
	_add_cyl(hg, 0.006, 0.040, 0.042, Vector3(0, 0.041, 0), mat_sand, Vector3.ZERO, 18)
	_add_cyl(hg, 0.032, 0.008, 0.034, Vector3(0, 0.126, 0), mat_sand, Vector3.ZERO, 18)
	_add_cyl(hg, 0.002, 0.002, 0.068, Vector3(0, 0.075, 0), mat_sand, Vector3.ZERO, 8)


func _build_token_bowl_and_coins(parent: Node3D, pos: Vector3, mat_wood: Material, mat_gold: Material, mat_silver: Material, mat_felt: Material, mat_ruby: Material, mat_sapphire: Material, mat_emerald: Material) -> void:
	var bowl_group = Node3D.new()
	bowl_group.name = "GamingTokenBowl"
	bowl_group.position = pos
	parent.add_child(bowl_group)

	# Carved Mahogany & Brass Dish with Crimson Velvet Lining
	_add_cyl(bowl_group, 0.108, 0.084, 0.028, Vector3(0, 0.014, 0), mat_wood, Vector3.ZERO, 28)
	_add_torus(bowl_group, 0.098, 0.110, Vector3(0, 0.028, 0), mat_gold)
	_add_cyl(bowl_group, 0.094, 0.082, 0.006, Vector3(0, 0.026, 0), mat_felt, Vector3.ZERO, 24)

	# Stacked Gold, Silver & Jeweled Match Coins inside the dish
	var stacks = [
		{"pos": Vector3(-0.036, 0.030, -0.020), "count": 6, "mat": mat_gold, "gem": mat_ruby},
		{"pos": Vector3(0.034, 0.030, -0.022), "count": 5, "mat": mat_silver, "gem": mat_sapphire},
		{"pos": Vector3(0.0, 0.030, 0.032), "count": 4, "mat": mat_gold, "gem": mat_emerald}
	]
	for st in stacks:
		var base_p: Vector3 = st["pos"]
		var cnt: int = st["count"]
		for i in range(cnt):
			var c_pos = base_p + Vector3((i % 2) * 0.002, float(i) * 0.0065, ((i + 1) % 2) * 0.002)
			_add_cyl(bowl_group, 0.024, 0.024, 0.006, c_pos, st["mat"], Vector3.ZERO, 20)
			_add_cyl(bowl_group, 0.015, 0.015, 0.0066, c_pos, st["gem"], Vector3.ZERO, 16)

	# Two extra Gold Match Coins resting on the table beside the bowl
	_add_cyl(bowl_group, 0.025, 0.025, 0.006, Vector3(0.132, 0.003, 0.028), mat_gold, Vector3.ZERO, 20)
	_add_cyl(bowl_group, 0.016, 0.016, 0.0066, Vector3(0.132, 0.003, 0.028), mat_ruby, Vector3.ZERO, 16)
	_add_cyl(bowl_group, 0.025, 0.025, 0.006, Vector3(0.152, 0.009, 0.012), mat_gold, Vector3(12, 25, -14), 20)


func _build_scorebook_and_pen(parent: Node3D, pos: Vector3, mat_leather: Material, mat_brass: Material, mat_paper: Material, mat_ebony: Material, mat_ribbon: Material) -> void:
	var book_group = Node3D.new()
	book_group.name = "MatchScorebook"
	book_group.position = pos
	book_group.rotation_degrees = Vector3(0, -22.0, 0)
	parent.add_child(book_group)

	# Leather-bound Cover + Spine + Brass Corner Protectors
	_add_box(book_group, Vector3(0.175, 0.012, 0.225), Vector3(0, 0.006, 0), mat_leather)
	_add_cyl(book_group, 0.010, 0.010, 0.225, Vector3(-0.088, 0.011, 0), mat_leather, Vector3(90, 0, 0), 14)
	# Cream Ruled Pages Block
	_add_box(book_group, Vector3(0.158, 0.010, 0.208), Vector3(0.004, 0.014, 0), mat_paper)
	# Gold Foil Border & Ruled Lines on Top Page
	_add_box(book_group, Vector3(0.132, 0.0015, 0.005), Vector3(0.004, 0.0195, -0.072), mat_brass)
	_add_box(book_group, Vector3(0.132, 0.0015, 0.004), Vector3(0.004, 0.0195, -0.032), mat_brass)
	_add_box(book_group, Vector3(0.132, 0.0015, 0.004), Vector3(0.004, 0.0195, 0.008), mat_brass)
	_add_box(book_group, Vector3(0.132, 0.0015, 0.004), Vector3(0.004, 0.0195, 0.048), mat_brass)
	_add_box(book_group, Vector3(0.004, 0.0015, 0.160), Vector3(0.004, 0.0195, -0.008), mat_brass)
	# Crimson Ribbon Bookmark
	_add_box(book_group, Vector3(0.014, 0.003, 0.048), Vector3(0.022, 0.004, 0.125), mat_ribbon, Vector3(0, 14, 0))

	# Brass & Ebony Fountain Pen resting diagonally on the scorebook
	var pen = Node3D.new()
	pen.position = Vector3(0.018, 0.027, 0.012)
	pen.rotation_degrees = Vector3(0, 36.0, 0)
	book_group.add_child(pen)
	_add_cyl(pen, 0.0065, 0.0055, 0.145, Vector3(0, 0, 0), mat_ebony, Vector3(90, 0, 0), 14)
	_add_cyl(pen, 0.0072, 0.0072, 0.014, Vector3(0, 0, -0.022), mat_brass, Vector3(90, 0, 0), 14)
	# Gold Fountain Nib
	_add_cyl(pen, 0.001, 0.0055, 0.026, Vector3(0, 0, -0.084), mat_brass, Vector3(-90, 0, 0), 8)


func _build_champion_trophy(parent: Node3D, pos: Vector3, mat_walnut: Material, mat_marble: Material, mat_gold: Material, mat_ruby: Material) -> void:
	var trophy = Node3D.new()
	trophy.name = "ChampionTrophy"
	trophy.position = pos
	trophy.rotation_degrees = Vector3(0, 25.0, 0)
	parent.add_child(trophy)

	# Stepped Walnut & Ivory-Marble Plinth
	_add_cyl(trophy, 0.068, 0.076, 0.020, Vector3(0, 0.010, 0), mat_walnut, Vector3.ZERO, 8)
	_add_cyl(trophy, 0.052, 0.058, 0.026, Vector3(0, 0.033, 0), mat_marble, Vector3.ZERO, 16)
	_add_torus(trophy, 0.046, 0.054, Vector3(0, 0.048, 0), mat_gold)

	# Sculpted Gold Stem & Chalice Cup
	_add_cyl(trophy, 0.014, 0.032, 0.048, Vector3(0, 0.070, 0), mat_gold, Vector3.ZERO, 16)
	_add_sphere(trophy, 0.020, 0.028, Vector3(0, 0.092, 0), mat_gold)
	_add_cyl(trophy, 0.056, 0.022, 0.078, Vector3(0, 0.138, 0), mat_gold, Vector3.ZERO, 24)
	_add_torus(trophy, 0.050, 0.058, Vector3(0, 0.178, 0), mat_gold)
	# Dual Trophy Handles
	_add_torus(trophy, 0.020, 0.027, Vector3(-0.054, 0.142, 0), mat_gold, Vector3(90, 0, 0))
	_add_torus(trophy, 0.020, 0.027, Vector3(0.054, 0.142, 0), mat_gold, Vector3(90, 0, 0))
	# Ruby Emblem on Front
	_add_sphere(trophy, 0.012, 0.018, Vector3(0, 0.142, 0.042), mat_ruby)


func _build_pocket_chronometer(parent: Node3D, pos: Vector3, mat_gold: Material, mat_aged_brass: Material, mat_dial: Material, mat_hands: Material, mat_glass: Material) -> void:
	var watch = Node3D.new()
	watch.name = "PocketChronometer"
	watch.position = pos
	watch.rotation_degrees = Vector3(0, -28.0, 0)
	parent.add_child(watch)

	# Pocket Watch Gold Case & Dial
	_add_cyl(watch, 0.062, 0.066, 0.018, Vector3(0, 0.009, 0), mat_gold, Vector3.ZERO, 28)
	_add_torus(watch, 0.054, 0.064, Vector3(0, 0.018, 0), mat_gold)
	_add_cyl(watch, 0.052, 0.052, 0.004, Vector3(0, 0.018, 0), mat_dial, Vector3.ZERO, 24)

	# Clock Hands & 12 Hour Markers
	_add_box(watch, Vector3(0.004, 0.002, 0.036), Vector3(0, 0.021, -0.012), mat_hands, Vector3(0, 25, 0))
	_add_box(watch, Vector3(0.005, 0.002, 0.024), Vector3(0.008, 0.021, 0.004), mat_hands, Vector3(0, -65, 0))
	_add_sphere(watch, 0.005, 0.005, Vector3(0, 0.021, 0), mat_gold)
	for i in range(12):
		var a = float(i) * PI / 6.0
		_add_box(watch, Vector3(0.003, 0.0015, 0.007), Vector3(sin(a) * 0.043, 0.0205, cos(a) * 0.043), mat_aged_brass, Vector3(0, -rad_to_deg(a), 0))

	# Domed Watch Crystal Glass
	_add_sphere(watch, 0.052, 0.014, Vector3(0, 0.020, 0), mat_glass)
	# Winding Crown & Bow Ring at Top (-Z)
	_add_cyl(watch, 0.010, 0.010, 0.016, Vector3(0, 0.010, -0.070), mat_gold, Vector3(90, 0, 0), 12)
	_add_torus(watch, 0.014, 0.019, Vector3(0, 0.010, -0.084), mat_gold)
