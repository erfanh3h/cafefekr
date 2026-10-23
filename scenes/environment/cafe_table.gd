extends Node3D

# 3D Café Table Controller
# Manages realistic physical café environment, camera orbit/tilt, and zoom controls.
# Provides seamless input handling: drag around board to orbit/tilt, pinch/wheel to zoom,
# double-tap to recenter, and smooth damped interpolation.

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer
@onready var table_lamp_light: OmniLight3D = $TableLampLight

var candle_light: OmniLight3D = null

# --- Camera Presets & Orbit Rig ---
const CAM_POS_MENU: Vector3 = Vector3(0.0, 2.0, 2.7)
const CAM_ROT_MENU: Vector3 = Vector3(-28.0, 0.0, 0.0)

# Target center point on the table (board center)
const TARGET_FOCUS: Vector3 = Vector3(0.0, 0.08, -0.04)

signal camera_mode_changed(is_top_down: bool)

# Zoom boundaries (distance from target in meters) - strictly bounded to table around board
const ZOOM_DEFAULT: float = 3.20
const ZOOM_MIN: float = 2.20
const ZOOM_MAX: float = 3.55

# Orbit angle limits (radians) - comfortable view of the board
const YAW_DEFAULT: float = 0.0
const YAW_MIN: float = -0.55 # -31.5 degrees
const YAW_MAX: float = 0.55  # +31.5 degrees

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
var current_board_node: Node3D = null

# Realistic Hands (No ugly bodies or chairs, only natural animated hands!)
const RealisticHandScript = preload("res://scenes/environment/realistic_hand.gd")

var enemy_hand: Node3D = null
var player_hand: Node3D = null

func _ready() -> void:
	add_to_group("cafe_table")
	if has_node("CafeProps/LanternGroup/CandleLight"):
		candle_light = get_node("CafeProps/LanternGroup/CandleLight")
		
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
		candle_light.light_energy = 0.65 + sin(_flicker_timer) * 0.08 + sin(_flicker_timer * 2.3) * 0.05

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

func _unhandled_input(event: InputEvent) -> void:
	if not is_board_view_active or is_transitioning:
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
			_mouse_pressed = false
			if not _is_dragging:
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
			target_pitch = clampf(target_pitch, PITCH_MIN, PITCH_MAX)

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
		_active_touches.erase(event.index)
		if _active_touches.size() < 2:
			_prev_pinch_dist = -1.0
		if _active_touches.is_empty():
			if not _is_dragging:
				_check_double_tap(event.position)
			_is_dragging = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
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
			target_pitch = clampf(target_pitch, PITCH_MIN, PITCH_MAX)

func _check_double_tap(pos: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time < 0.35 and pos.distance_to(_last_tap_pos) < 40.0:
		reset_camera_orbit()
		_last_tap_time = 0.0
	else:
		_last_tap_time = now
		_last_tap_pos = pos
