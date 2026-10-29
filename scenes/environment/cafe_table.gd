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
var is_top_down_view: bool = true
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
var _lantern_flare_boost: float = 0.0
var _flame_mesh: MeshInstance3D = null
var _flame_halo_mesh: MeshInstance3D = null
var current_board_node: Node3D = null

# Interactive Table Props State & References
var _prop_animating: Dictionary = {}
var _last_prop_tap_sec: float = 0.0

var _lantern_node: Node3D = null
var _tea_group_node: Node3D = null
var _tea_pot_node: Node3D = null
var _tea_istikan_node: Node3D = null
var _tea_spoon_pivot: Node3D = null
var _tea_liquid_top: MeshInstance3D = null
var _tea_pour_stream: MeshInstance3D = null
var _tea_qandan_node: Node3D = null

var _dice_group_node: Node3D = null
var _dice_cup_node: Node3D = null
var _dice_nodes: Array = []
var _dice_rest_positions: Array = []
var _dice_rest_rotations: Array = []

var _hourglass_group_node: Node3D = null
var _hourglass_pivot: Node3D = null
var _hourglass_sand_a: MeshInstance3D = null
var _hourglass_sand_b: MeshInstance3D = null
var _hourglass_stream: MeshInstance3D = null
var _hourglass_flipped: bool = false

var _token_bowl_node: Node3D = null
var _token_coin_nodes: Array = []
var _token_coin_rest_pos: Array = []
var _token_coin_rest_rot: Array = []

var _scorebook_node: Node3D = null
var _scorebook_pen: Node3D = null
var _scorebook_pen_rest_pos: Vector3 = Vector3.ZERO
var _scorebook_pen_rest_rot: Vector3 = Vector3.ZERO
var _scorebook_ink_strokes: Array = []

var _trophy_node: Node3D = null
var _trophy_ruby_mesh: MeshInstance3D = null

var _chronometer_node: Node3D = null
var _watch_minute_pivot: Node3D = null
var _watch_hour_pivot: Node3D = null
var _watch_crown_node: Node3D = null



func _ready() -> void:
	add_to_group("cafe_table")
	if has_node("CafeProps/LanternGroup/CandleLight"):
		candle_light = get_node("CafeProps/LanternGroup/CandleLight")
	if has_node("CafeProps/CoffeeCupGroup"):
		get_node("CafeProps/CoffeeCupGroup").visible = false

	_build_luxury_game_environment()

	# Mobile GPU Optimization (e.g. Samsung Galaxy M32 with Mali-G52 GPU):
	# Turn off multi-pass ping-pong glow bloom and optimize shadow passes for 60fps mobile gameplay
	if OS.get_name() in ["Android", "iOS"]:
		var env_node = get_node_or_null("WorldEnvironment")
		if env_node and env_node.environment:
			env_node.environment.glow_enabled = false
		if has_node("SunLight"):
			var sun: DirectionalLight3D = get_node("SunLight")
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.shadow_blur = 0.5


	transition_to_menu_view(0.1)

func _process(delta: float) -> void:
	if _mouse_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_pressed = false
		_is_dragging = false
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
		candle_light.light_energy = 0.72 + pulse + _lantern_flare_boost
		if _flame_mesh and is_instance_valid(_flame_mesh):
			var s = 1.0 + pulse * 0.65 + _lantern_flare_boost * 0.45
			_flame_mesh.scale = Vector3(1.0 - pulse * 0.20, s, 1.0 - pulse * 0.20)
		if _flame_halo_mesh and is_instance_valid(_flame_halo_mesh):
			var hs = 1.0 + pulse * 0.85 + _lantern_flare_boost * 0.75
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
	is_top_down_view = true
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	top_down_current_height = TOP_DOWN_HEIGHT_DEFAULT
	camera_mode_changed.emit(true)
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

	var end_pos = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_target_height, TARGET_FOCUS.z)
	var end_rot_deg = Vector3(-90.0, 0.0, 0.0)

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
	is_top_down_view = true
	camera_mode_changed.emit(true)
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

# --- Table Callbacks (3D Hands Removed per Game Scene Rules) ---

func update_opponent_avatar(_avatar_id: int) -> void:
	pass

func update_hand_colors() -> void:
	pass

func set_opponent_thinking(_thinking: bool) -> void:
	pass

func play_opponent_reaction() -> void:
	pass

func animate_place_piece(_user_id: int, _target_world_pos: Vector3, _piece_node: Node3D, on_dropped: Callable) -> void:
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
			var was_tap = (_mouse_pressed and not _is_dragging and event.position.distance_to(_mouse_start_pos) <= DRAG_THRESHOLD)
			_mouse_pressed = false
			_is_dragging = false
			if was_tap:
				_try_trigger_prop_at_screen_pos(event.position)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if is_top_down_view:
		return
	if _mouse_pressed:
		if not _is_dragging:
			if event.position.distance_to(_mouse_start_pos) > DRAG_THRESHOLD:
				_is_dragging = true
		if _is_dragging:
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
		var was_tap = (_active_touches.size() == 1 and not _is_dragging and event.position.distance_to(_drag_start_pos) <= DRAG_THRESHOLD)
		_active_touches.erase(event.index)
		if _active_touches.size() < 2:
			_prev_pinch_dist = -1.0
		if _active_touches.is_empty():
			_is_dragging = false
		if was_tap:
			_try_trigger_prop_at_screen_pos(event.position)

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
		if is_top_down_view:
			return
		if not _is_dragging:
			if event.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
				_is_dragging = true
		if _is_dragging:
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


func _upgrade_lantern_prop(mat_brass: Material, mat_aged_brass: Material, mat_amber_glass: Material, mat_wax: Material, _mat_flame: Material) -> void:
	var lantern = get_node_or_null("CafeProps/LanternGroup")
	if not lantern:
		return
	_lantern_node = lantern

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
	_tea_group_node = tea_group

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
	_tea_pot_node = pot
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
	_tea_istikan_node = istikan
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
	_tea_liquid_top = _add_cyl(istikan, 0.028, 0.021, 0.034, Vector3(0, 0.064, 0), mat_tea, Vector3.ZERO, 18)
	# Miniature Golden Tea Spoon on Saucer (wrapped in pivot for stirring animation)
	_tea_spoon_pivot = Node3D.new()
	_tea_spoon_pivot.position = Vector3.ZERO
	istikan.add_child(_tea_spoon_pivot)
	_add_box(_tea_spoon_pivot, Vector3(0.056, 0.002, 0.005), Vector3(-0.012, 0.012, 0.034), mat_brass, Vector3(0, 22, 0))
	_add_sphere(_tea_spoon_pivot, 0.008, 0.004, Vector3(0.014, 0.012, 0.024), mat_brass)

	# Hidden Pouring Tea Stream above the Istikan
	_tea_pour_stream = _add_cyl(istikan, 0.0035, 0.0022, 0.095, Vector3(0.0, 0.115, 0.0), mat_tea, Vector3(0, 0, 10), 12)
	_tea_pour_stream.visible = false

	# 4. Brass Sugar Bowl with Sugar Cubes (قندان برنجی و حبه‌های قند) on Right-Back of Tray
	var qandan = Node3D.new()
	qandan.position = Vector3(0.064, 0.009, -0.058)
	tea_group.add_child(qandan)
	_tea_qandan_node = qandan
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
	_dice_group_node = dice_group

	# 1. Stitched Leather Dice Shaker Cup with Brass Rings & Crimson Felt Interior
	var cup = Node3D.new()
	cup.position = Vector3(-0.055, 0.0, -0.015)
	cup.rotation_degrees = Vector3(6.0, 18.0, -8.0)
	dice_group.add_child(cup)
	_dice_cup_node = cup
	_add_cyl(cup, 0.044, 0.036, 0.105, Vector3(0, 0.0525, 0), mat_leather, Vector3.ZERO, 24)
	# Brass Ribs
	_add_torus(cup, 0.034, 0.039, Vector3(0, 0.014, 0), mat_brass)
	_add_torus(cup, 0.038, 0.043, Vector3(0, 0.054, 0), mat_brass)
	_add_torus(cup, 0.041, 0.046, Vector3(0, 0.098, 0), mat_brass)
	# Inner Crimson Velvet Top Opening
	_add_cyl(cup, 0.039, 0.037, 0.008, Vector3(0, 0.102, 0), mat_felt, Vector3.ZERO, 20)

	# 2. Three Sculpted Ivory 6-Sided Game Dice with Real 3D Pips
	_dice_nodes.clear()
	_dice_rest_positions.clear()
	_dice_rest_rotations.clear()
	var d1 = _create_single_die(dice_group, Vector3(0.032, 0.022, 0.024), Vector3(0, 24.0, 0), 0.042, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)
	var d2 = _create_single_die(dice_group, Vector3(0.088, 0.022, -0.014), Vector3(90.0, -32.0, 0), 0.040, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)
	var d3 = _create_single_die(dice_group, Vector3(0.018, 0.020, -0.042), Vector3(0, 62.0, 90.0), 0.038, mat_ivory, mat_brass, mat_pip_dark, mat_pip_red)
	for d_node in [d1, d2, d3]:
		_dice_nodes.append(d_node)
		_dice_rest_positions.append(d_node.position)
		_dice_rest_rotations.append(d_node.rotation_degrees)


func _create_single_die(parent: Node3D, pos: Vector3, rot_deg: Vector3, s: float, mat_ivory: Material, mat_brass: Material, mat_dark: Material, mat_red: Material) -> Node3D:
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
	return die


func _build_brass_hourglass(parent: Node3D, pos: Vector3, mat_walnut: Material, mat_brass: Material, mat_glass: Material, mat_sand: Material) -> void:
	var hg = Node3D.new()
	hg.name = "BrassHourglass"
	hg.position = pos
	hg.rotation_degrees = Vector3(0, 15.0, 0)
	parent.add_child(hg)
	_hourglass_group_node = hg

	# Center pivot at the waist (Y = 0.105) so lifting and flipping 180 degrees rotates around the exact center
	var pivot = Node3D.new()
	pivot.name = "HourglassPivot"
	pivot.position = Vector3(0, 0.105, 0)
	hg.add_child(pivot)
	_hourglass_pivot = pivot

	var wy: float = -0.105

	# Hexagonal Walnut & Brass Base Plate
	_add_cyl(pivot, 0.074, 0.080, 0.014, Vector3(0, 0.007 + wy, 0), mat_walnut, Vector3.ZERO, 6)
	_add_cyl(pivot, 0.066, 0.070, 0.006, Vector3(0, 0.017 + wy, 0), mat_brass, Vector3.ZERO, 6)

	# Hexagonal Walnut & Brass Top Plate
	_add_cyl(pivot, 0.070, 0.066, 0.006, Vector3(0, 0.193 + wy, 0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(pivot, 0.080, 0.074, 0.014, Vector3(0, 0.203 + wy, 0), mat_walnut, Vector3.ZERO, 6)

	# 4 Turned Brass Baluster Rods
	for i in range(4):
		var ang = float(i) * PI * 0.5 + PI * 0.25
		var rx = cos(ang) * 0.056
		var rz = sin(ang) * 0.056
		_add_cyl(pivot, 0.005, 0.005, 0.176, Vector3(rx, 0.105 + wy, rz), mat_brass, Vector3.ZERO, 10)
		_add_sphere(pivot, 0.009, 0.014, Vector3(rx, -0.004 + wy, rz), mat_brass)
		_add_sphere(pivot, 0.009, 0.016, Vector3(rx, 0.105 + wy, rz), mat_brass)
		_add_sphere(pivot, 0.009, 0.014, Vector3(rx, 0.214 + wy, rz), mat_brass)

	# Lower & Upper Glass Bulbs + Brass Center Waist Ring
	_add_cyl(pivot, 0.010, 0.046, 0.082, Vector3(0, 0.061 + wy, 0), mat_glass, Vector3.ZERO, 20)
	_add_cyl(pivot, 0.046, 0.010, 0.082, Vector3(0, 0.149 + wy, 0), mat_glass, Vector3.ZERO, 20)
	_add_torus(pivot, 0.011, 0.018, Vector3(0, 0.0, 0), mat_brass)

	# Golden Sand Mounds in Both Bulbs + Falling Sand Stream across the waist
	_hourglass_sand_a = _add_cyl(pivot, 0.010, 0.040, 0.044, Vector3(0, -0.062, 0), mat_sand, Vector3.ZERO, 18)
	_hourglass_sand_b = _add_cyl(pivot, 0.040, 0.010, 0.044, Vector3(0, 0.062, 0), mat_sand, Vector3.ZERO, 18)
	_hourglass_sand_b.scale = Vector3(0.75, 0.65, 0.75)
	_hourglass_stream = _add_cyl(pivot, 0.0025, 0.0025, 0.110, Vector3(0, 0.0, 0), mat_sand, Vector3.ZERO, 8)


func _build_token_bowl_and_coins(parent: Node3D, pos: Vector3, mat_wood: Material, mat_gold: Material, mat_silver: Material, mat_felt: Material, mat_ruby: Material, mat_sapphire: Material, mat_emerald: Material) -> void:
	var bowl_group = Node3D.new()
	bowl_group.name = "GamingTokenBowl"
	bowl_group.position = pos
	parent.add_child(bowl_group)
	_token_bowl_node = bowl_group

	# Carved Mahogany & Brass Dish with Crimson Velvet Lining
	_add_cyl(bowl_group, 0.108, 0.084, 0.028, Vector3(0, 0.014, 0), mat_wood, Vector3.ZERO, 28)
	_add_torus(bowl_group, 0.098, 0.110, Vector3(0, 0.028, 0), mat_gold)
	_add_cyl(bowl_group, 0.094, 0.082, 0.006, Vector3(0, 0.026, 0), mat_felt, Vector3.ZERO, 24)

	_token_coin_nodes.clear()
	_token_coin_rest_pos.clear()
	_token_coin_rest_rot.clear()

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
			var coin_wrap = Node3D.new()
			coin_wrap.position = c_pos
			bowl_group.add_child(coin_wrap)
			_add_cyl(coin_wrap, 0.024, 0.024, 0.006, Vector3.ZERO, st["mat"], Vector3.ZERO, 20)
			_add_cyl(coin_wrap, 0.015, 0.015, 0.0066, Vector3.ZERO, st["gem"], Vector3.ZERO, 16)
			_token_coin_nodes.append(coin_wrap)
			_token_coin_rest_pos.append(c_pos)
			_token_coin_rest_rot.append(Vector3.ZERO)

	# Two extra Gold Match Coins resting on the table beside the bowl
	var loose1 = Node3D.new()
	loose1.position = Vector3(0.132, 0.003, 0.028)
	bowl_group.add_child(loose1)
	_add_cyl(loose1, 0.025, 0.025, 0.006, Vector3.ZERO, mat_gold, Vector3.ZERO, 20)
	_add_cyl(loose1, 0.016, 0.016, 0.0066, Vector3.ZERO, mat_ruby, Vector3.ZERO, 16)
	_token_coin_nodes.append(loose1)
	_token_coin_rest_pos.append(loose1.position)
	_token_coin_rest_rot.append(Vector3.ZERO)

	var loose2 = Node3D.new()
	loose2.position = Vector3(0.152, 0.009, 0.012)
	loose2.rotation_degrees = Vector3(12, 25, -14)
	bowl_group.add_child(loose2)
	_add_cyl(loose2, 0.025, 0.025, 0.006, Vector3.ZERO, mat_gold, Vector3.ZERO, 20)
	_add_cyl(loose2, 0.016, 0.016, 0.0066, Vector3.ZERO, mat_emerald, Vector3.ZERO, 16)
	_token_coin_nodes.append(loose2)
	_token_coin_rest_pos.append(loose2.position)
	_token_coin_rest_rot.append(loose2.rotation_degrees)


func _build_scorebook_and_pen(parent: Node3D, pos: Vector3, mat_leather: Material, mat_brass: Material, mat_paper: Material, mat_ebony: Material, mat_ribbon: Material) -> void:
	var book_group = Node3D.new()
	book_group.name = "MatchScorebook"
	book_group.position = pos
	book_group.rotation_degrees = Vector3(0, -22.0, 0)
	parent.add_child(book_group)
	_scorebook_node = book_group

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
	_add_box(book_group, Vector3(0.132, 0.0015, 0.004), Vector3(0.004, 0.0195, 0.084), mat_brass)
	_add_box(book_group, Vector3(0.004, 0.0015, 0.160), Vector3(0.004, 0.0195, -0.008), mat_brass)
	# Crimson Ribbon Bookmark
	_add_box(book_group, Vector3(0.014, 0.003, 0.048), Vector3(0.022, 0.004, 0.125), mat_ribbon, Vector3(0, 14, 0))

	# Pre-build calligraphic ink word strokes along the 3 ruled rows (hidden until user taps note!)
	_scorebook_ink_strokes.clear()
	var mat_ink = StandardMaterial3D.new()
	mat_ink.albedo_color = Color(0.10, 0.16, 0.36)
	mat_ink.roughness = 0.25
	mat_ink.emission_enabled = true
	mat_ink.emission = Color(0.18, 0.28, 0.62)
	mat_ink.emission_energy_multiplier = 0.65

	var row_zs = [-0.052, -0.012, 0.028]
	var word_xs = [0.046, 0.018, -0.012, -0.040]
	for r_idx in range(row_zs.size()):
		var rz: float = row_zs[r_idx]
		for w_idx in range(word_xs.size()):
			var wx: float = word_xs[w_idx]
			var stroke_group = Node3D.new()
			stroke_group.position = Vector3(wx, 0.0202, rz)
			stroke_group.scale = Vector3(0.001, 1.0, 1.0)
			stroke_group.visible = false
			book_group.add_child(stroke_group)

			# Main cursive Persian-style word baseline + ascender/flourish + nuqta dots
			var w_len = 0.020 if (w_idx % 2 == 0) else 0.016
			_add_box(stroke_group, Vector3(w_len, 0.0016, 0.0034), Vector3(0, 0, 0.001), mat_ink, Vector3(0, -8.0 if (w_idx % 2 == 0) else 6.0, 0))
			_add_box(stroke_group, Vector3(0.0032, 0.0016, 0.0095), Vector3(w_len * 0.35, 0, -0.0035), mat_ink, Vector3(0, 12.0, 0))
			_add_sphere(stroke_group, 0.0020, 0.0016, Vector3(-0.003, 0.0005, -0.0055 if (r_idx + w_idx) % 2 == 0 else 0.0055), mat_ink)
			if (r_idx + w_idx) % 2 == 1:
				_add_sphere(stroke_group, 0.0018, 0.0016, Vector3(0.002, 0.0005, -0.0055), mat_ink)
			_scorebook_ink_strokes.append(stroke_group)

	# Brass & Ebony Fountain Pen with origin at the Gold Nib Tip so it traces the exact strokes on paper
	var pen = Node3D.new()
	_scorebook_pen_rest_pos = Vector3(-0.038, 0.027, -0.065)
	_scorebook_pen_rest_rot = Vector3(0, 36.0, 0)
	pen.position = _scorebook_pen_rest_pos
	pen.rotation_degrees = _scorebook_pen_rest_rot
	book_group.add_child(pen)
	_scorebook_pen = pen

	var pen_visual = Node3D.new()
	pen_visual.position = Vector3(0, 0, 0.095)
	pen.add_child(pen_visual)
	_add_cyl(pen_visual, 0.0065, 0.0055, 0.145, Vector3(0, 0, 0), mat_ebony, Vector3(90, 0, 0), 14)
	_add_cyl(pen_visual, 0.0072, 0.0072, 0.014, Vector3(0, 0, -0.022), mat_brass, Vector3(90, 0, 0), 14)
	_add_box(pen_visual, Vector3(0.0025, 0.003, 0.048), Vector3(0, 0.007, 0.032), mat_brass)
	# Gold Fountain Nib (tip reaches local Z = -0.095 of pen_visual, which is (0,0,0) of pen!)
	_add_cyl(pen_visual, 0.001, 0.0055, 0.026, Vector3(0, 0, -0.082), mat_brass, Vector3(-90, 0, 0), 8)


func _build_champion_trophy(parent: Node3D, pos: Vector3, mat_walnut: Material, mat_marble: Material, mat_gold: Material, mat_ruby: Material) -> void:
	var trophy = Node3D.new()
	trophy.name = "ChampionTrophy"
	trophy.position = pos
	trophy.rotation_degrees = Vector3(0, 25.0, 0)
	parent.add_child(trophy)
	_trophy_node = trophy

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
	_trophy_ruby_mesh = _add_sphere(trophy, 0.012, 0.018, Vector3(0, 0.142, 0.042), mat_ruby)


func _build_pocket_chronometer(parent: Node3D, pos: Vector3, mat_gold: Material, mat_aged_brass: Material, mat_dial: Material, mat_hands: Material, mat_glass: Material) -> void:
	var watch = Node3D.new()
	watch.name = "PocketChronometer"
	watch.position = pos
	watch.rotation_degrees = Vector3(0, -28.0, 0)
	parent.add_child(watch)
	_chronometer_node = watch

	# Pocket Watch Gold Case & Dial
	_add_cyl(watch, 0.062, 0.066, 0.018, Vector3(0, 0.009, 0), mat_gold, Vector3.ZERO, 28)
	_add_torus(watch, 0.054, 0.064, Vector3(0, 0.018, 0), mat_gold)
	_add_cyl(watch, 0.052, 0.052, 0.004, Vector3(0, 0.018, 0), mat_dial, Vector3.ZERO, 24)

	# Clock Hands wrapped in center pivots at (0, 0.021, 0) so they rotate cleanly around the dial pin
	_watch_minute_pivot = Node3D.new()
	_watch_minute_pivot.position = Vector3(0, 0.021, 0)
	_watch_minute_pivot.rotation_degrees = Vector3(0, 25.0, 0)
	watch.add_child(_watch_minute_pivot)
	_add_box(_watch_minute_pivot, Vector3(0.004, 0.002, 0.038), Vector3(0, 0, -0.015), mat_hands)

	_watch_hour_pivot = Node3D.new()
	_watch_hour_pivot.position = Vector3(0, 0.021, 0)
	_watch_hour_pivot.rotation_degrees = Vector3(0, -65.0, 0)
	watch.add_child(_watch_hour_pivot)
	_add_box(_watch_hour_pivot, Vector3(0.005, 0.002, 0.026), Vector3(0, 0, -0.010), mat_hands)

	_add_sphere(watch, 0.005, 0.005, Vector3(0, 0.021, 0), mat_gold)
	for i in range(12):
		var a = float(i) * PI / 6.0
		_add_box(watch, Vector3(0.003, 0.0015, 0.007), Vector3(sin(a) * 0.043, 0.0205, cos(a) * 0.043), mat_aged_brass, Vector3(0, -rad_to_deg(a), 0))

	# Domed Watch Crystal Glass
	_add_sphere(watch, 0.052, 0.014, Vector3(0, 0.020, 0), mat_glass)
	# Winding Crown & Bow Ring at Top (-Z)
	_watch_crown_node = Node3D.new()
	_watch_crown_node.position = Vector3(0, 0.010, -0.070)
	watch.add_child(_watch_crown_node)
	_add_cyl(_watch_crown_node, 0.010, 0.010, 0.016, Vector3.ZERO, mat_gold, Vector3(90, 0, 0), 12)
	_add_torus(watch, 0.014, 0.019, Vector3(0, 0.010, -0.084), mat_gold)


# ============================================================================
# INTERACTIVE TABLE PROPS TAP DETECTION & 3D ANIMATIONS
# ============================================================================

func _play_prop_sfx(sound_name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound"):
		am.play_sound(sound_name)


func _is_gui_blocking_at(screen_pos: Vector2) -> bool:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if not hud:
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node:
			hud = main_node.get_node_or_null("UILayer/GameHUD")
	if not hud or not hud.visible:
		return false
	for modal_name in ["StartGameOverlay", "DisconnectPauseDialog", "SurrenderDialog", "RoundFinishBanner", "ReactionPicker", "GameResultDialog", "UserProfileDialog"]:
		var node = hud.get_node_or_null(modal_name)
		if node and node is Control and node.visible:
			return true
	for bar_name in ["BottomBar", "TopHeaderSlot"]:
		var bar = hud.get_node_or_null(bar_name)
		if bar and bar is Control and bar.visible and bar.get_global_rect().has_point(screen_pos):
			return true
	return false


func _try_trigger_prop_at_screen_pos(screen_pos: Vector2) -> bool:
	if not is_board_view_active or is_transitioning or not camera:
		return false
	var now_sec = Time.get_ticks_msec() / 1000.0
	if now_sec - _last_prop_tap_sec < 0.12:
		return false
	if _is_gui_blocking_at(screen_pos):
		return false

	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)

	# Intersect table prop plane (Y = 0.095)
	var prop_plane = Plane(Vector3.UP, 0.095)
	var plane_hit = prop_plane.intersects_ray(ray_origin, ray_dir)
	if plane_hit == null:
		return false

	# Ignore taps inside the central board arena so we never interfere with game boards
	if absf(plane_hit.x) < 0.84 and absf(plane_hit.z) < 0.88:
		return false

	var props_list = [
		{"id": "scorebook", "node": _scorebook_node, "radius": 0.21, "y_off": 0.03},
		{"id": "hourglass", "node": _hourglass_group_node, "radius": 0.19, "y_off": 0.10},
		{"id": "dice", "node": _dice_group_node, "radius": 0.20, "y_off": 0.05},
		{"id": "tea", "node": _tea_group_node, "radius": 0.23, "y_off": 0.06},
		{"id": "lantern", "node": _lantern_node, "radius": 0.21, "y_off": 0.12},
		{"id": "tokens", "node": _token_bowl_node, "radius": 0.21, "y_off": 0.04},
		{"id": "trophy", "node": _trophy_node, "radius": 0.19, "y_off": 0.09},
		{"id": "chronometer", "node": _chronometer_node, "radius": 0.18, "y_off": 0.03}
	]

	var best_id: String = ""
	var best_dist: float = 999.0

	for p in props_list:
		var node: Node3D = p["node"]
		if not node or not is_instance_valid(node):
			continue
		var p_pos = node.global_position
		var dist_xz = Vector2(plane_hit.x - p_pos.x, plane_hit.z - p_pos.z).length()

		# Also measure 3D ray distance to prop center so tall props in 3D orbit view are effortless to tap
		var center_3d = p_pos + Vector3(0.0, float(p["y_off"]), 0.0)
		var to_c = center_3d - ray_origin
		var t = maxf(0.0, to_c.dot(ray_dir))
		var closest = ray_origin + ray_dir * t
		var dist_ray = Vector2(closest.x - center_3d.x, closest.z - center_3d.z).length()

		var d = minf(dist_xz, dist_ray)
		if d <= float(p["radius"]) and d < best_dist:
			best_dist = d
			best_id = p["id"]

	if best_id == "":
		return false

	_last_prop_tap_sec = now_sec
	_trigger_prop_animation(best_id)
	return true


func _trigger_prop_animation(prop_id: String) -> void:
	if _prop_animating.get(prop_id, false):
		return
	match prop_id:
		"scorebook":
			_animate_scorebook()
		"hourglass":
			_animate_hourglass()
		"dice":
			_animate_dice()
		"tea":
			_animate_tea_service()
		"lantern":
			_animate_lantern()
		"tokens":
			_animate_token_bowl()
		"trophy":
			_animate_trophy()
		"chronometer":
			_animate_chronometer()


func _spawn_prop_sparkle_burst(parent: Node3D, local_center: Vector3, color: Color, count: int = 6, spread: float = 0.09, rise: float = 0.09) -> void:
	if not parent or not is_instance_valid(parent):
		return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.6

	for i in range(count):
		var ang = float(i) * TAU / float(count) + randf_range(-0.25, 0.25)
		var sp = _add_sphere(parent, 0.007, 0.014, local_center, mat)
		var target_p = local_center + Vector3(cos(ang) * spread, rise + randf_range(0.0, 0.04), sin(ang) * spread)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(sp, "position", target_p, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3(0.05, 0.05, 0.05), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(sp.queue_free)


func _spawn_prop_pulse_ring(parent: Node3D, local_center: Vector3, color: Color, max_scale: float = 2.2) -> void:
	if not parent or not is_instance_valid(parent):
		return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 2.2

	var ring = _add_torus(parent, 0.032, 0.040, local_center, mat)
	ring.scale = Vector3(0.35, 1.0, 0.35)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(max_scale, 1.0, max_scale), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.48)
	tw.chain().tween_callback(ring.queue_free)


# 1. MATCH SCOREBOOK & FOUNTAIN PEN: Pen lifts up and writes fake calligraphic text across the ruled lines!
func _animate_scorebook() -> void:
	if not _scorebook_node or not _scorebook_pen:
		return
	_prop_animating["scorebook"] = true
	_play_prop_sfx("tap")
	_spawn_prop_pulse_ring(_scorebook_node, Vector3(0.0, 0.022, 0.0), Color(0.95, 0.78, 0.28), 2.4)

	# Reset all fake text strokes before starting to write
	for st in _scorebook_ink_strokes:
		if is_instance_valid(st):
			st.visible = false
			st.scale = Vector3(0.001, 1.0, 1.0)

	var tw = create_tween()
	var write_rot_a = Vector3(-54.0, 18.0, -14.0)
	var write_rot_b = Vector3(-50.0, 24.0, -6.0)

	# Lift fountain pen into upright writing posture above the first word on Row 1
	var first_pos = _scorebook_ink_strokes[0].position if _scorebook_ink_strokes.size() > 0 else Vector3(0.046, 0.021, -0.052)
	tw.tween_property(_scorebook_pen, "position", first_pos + Vector3(0.0, 0.045, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_scorebook_pen, "rotation_degrees", write_rot_a, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Write each word stroke across the 3 ruled lines with realistic nib scribble oscillations
	for idx in range(_scorebook_ink_strokes.size()):
		var stroke_node: Node3D = _scorebook_ink_strokes[idx]
		var w_pos: Vector3 = stroke_node.position
		var is_new_line: bool = (idx > 0 and idx % 4 == 0)

		if is_new_line:
			# Lift pen slightly to hop to the start of the next ruled line
			tw.tween_property(_scorebook_pen, "position", w_pos + Vector3(0.010, 0.028, 0.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Touch nib down at start of word
		tw.tween_property(_scorebook_pen, "position", w_pos + Vector3(0.008, 0.002, 0.003), 0.05)
		tw.tween_callback(func():
			if is_instance_valid(stroke_node):
				stroke_node.visible = true
				var st_tw = create_tween()
				st_tw.tween_property(stroke_node, "scale", Vector3(1.0, 1.0, 1.0), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if idx % 3 == 0:
				_play_prop_sfx("move_peace")
		)
		# Rapid cursive scribble motion across the word
		tw.tween_property(_scorebook_pen, "position", w_pos + Vector3(-0.002, 0.005, -0.004), 0.055)
		tw.parallel().tween_property(_scorebook_pen, "rotation_degrees", write_rot_b, 0.055)
		tw.tween_property(_scorebook_pen, "position", w_pos + Vector3(-0.010, 0.002, 0.002), 0.055)
		tw.parallel().tween_property(_scorebook_pen, "rotation_degrees", write_rot_a, 0.055)

	# Flourish twirl in the air and settle back to rest on the scorebook
	tw.tween_callback(func():
		_play_prop_sfx("add_peace")
		_spawn_prop_sparkle_burst(_scorebook_node, Vector3(0.0, 0.035, -0.01), Color(1.0, 0.84, 0.32), 6, 0.08, 0.06)
	)
	tw.tween_property(_scorebook_pen, "position", _scorebook_pen_rest_pos + Vector3(0.0, 0.065, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_scorebook_pen, "rotation_degrees", _scorebook_pen_rest_rot + Vector3(0.0, 360.0, 0.0), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_scorebook_pen, "position", _scorebook_pen_rest_pos, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Keep fake text visible on the note for 1.6s, then fade out cleanly
	tw.tween_interval(1.6)
	tw.tween_callback(func():
		for st in _scorebook_ink_strokes:
			if is_instance_valid(st):
				var fade_tw = create_tween()
				fade_tw.tween_property(st, "scale", Vector3(0.001, 1.0, 0.001), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fade_tw.chain().tween_callback(func():
					if is_instance_valid(st):
						st.visible = false
				)
		_scorebook_pen.rotation_degrees = _scorebook_pen_rest_rot
		_prop_animating["scorebook"] = false
	)


# 2. BRASS HOURGLASS / SAND WATCH: Rises up, flips 180 degrees upside down, lands, and reverses sand flow!
func _animate_hourglass() -> void:
	if not _hourglass_group_node or not _hourglass_pivot:
		return
	_prop_animating["hourglass"] = true
	_play_prop_sfx("time")
	_spawn_prop_pulse_ring(_hourglass_group_node, Vector3(0.0, 0.015, 0.0), Color(1.0, 0.78, 0.25), 2.3)

	_hourglass_flipped = not _hourglass_flipped
	var target_rot_x: float = 180.0 if _hourglass_flipped else 360.0

	var tw = create_tween()
	# Lift hourglass up
	tw.tween_property(_hourglass_pivot, "position:y", 0.255, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Flip 180 degrees around waist while suspended in mid-air
	tw.tween_property(_hourglass_pivot, "rotation_degrees:x", target_rot_x, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_callback(func():
		_spawn_prop_sparkle_burst(_hourglass_group_node, Vector3(0.0, 0.22, 0.0), Color(1.0, 0.82, 0.30), 7, 0.10, 0.05)
	)
	# Set back down onto the table with a tactile bounce
	tw.tween_property(_hourglass_pivot, "position:y", 0.105, 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_play_prop_sfx("tap")
		if not _hourglass_flipped:
			_hourglass_pivot.rotation_degrees.x = 0.0
		# Animate sand draining from the new top bulb into the new bottom bulb
		if is_instance_valid(_hourglass_stream) and is_instance_valid(_hourglass_sand_a) and is_instance_valid(_hourglass_sand_b):
			_hourglass_stream.visible = true
			_hourglass_stream.scale = Vector3(1.4, 1.0, 1.4)
			var top_sand = _hourglass_sand_a if _hourglass_flipped else _hourglass_sand_b
			var bot_sand = _hourglass_sand_b if _hourglass_flipped else _hourglass_sand_a
			top_sand.scale = Vector3(1.0, 1.0, 1.0)
			bot_sand.scale = Vector3(0.45, 0.35, 0.45)

			var sand_tw = create_tween().set_parallel(true)
			sand_tw.tween_property(top_sand, "scale", Vector3(0.65, 0.55, 0.65), 1.15).set_trans(Tween.TRANS_SINE)
			sand_tw.tween_property(bot_sand, "scale", Vector3(1.05, 1.05, 1.05), 1.15).set_trans(Tween.TRANS_SINE)
			sand_tw.tween_property(_hourglass_stream, "scale", Vector3(0.8, 1.0, 0.8), 1.15)
			sand_tw.chain().tween_callback(func():
				_prop_animating["hourglass"] = false
			)
		else:
			_prop_animating["hourglass"] = false
	)


# 3. LEATHER DICE CUP & 3 IVORY DICE: Cup shakes vigorously and all 3 dice tumble & roll new faces!
func _animate_dice() -> void:
	if not _dice_group_node or not _dice_cup_node:
		return
	_prop_animating["dice"] = true
	_play_prop_sfx("dice")
	_spawn_prop_pulse_ring(_dice_group_node, Vector3(0.02, 0.01, 0.0), Color(0.98, 0.88, 0.65), 2.4)

	var cup_rest_pos = Vector3(-0.055, 0.0, -0.015)
	var cup_rest_rot = Vector3(6.0, 18.0, -8.0)

	# Shake the leather dice cup
	var cup_tw = create_tween()
	cup_tw.tween_property(_dice_cup_node, "position", cup_rest_pos + Vector3(0.0, 0.11, 0.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cup_tw.parallel().tween_property(_dice_cup_node, "rotation_degrees", Vector3(-22.0, 35.0, 26.0), 0.12)
	cup_tw.tween_property(_dice_cup_node, "rotation_degrees", Vector3(24.0, -18.0, -28.0), 0.11)
	cup_tw.tween_property(_dice_cup_node, "rotation_degrees", Vector3(-18.0, 28.0, 22.0), 0.11)
	cup_tw.tween_property(_dice_cup_node, "rotation_degrees", cup_rest_rot, 0.16)
	cup_tw.parallel().tween_property(_dice_cup_node, "position", cup_rest_pos, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Tumble & bounce the 3 sculpted ivory dice onto random 90-degree faces
	var face_angles = [0.0, 90.0, 180.0, 270.0]
	for i in range(_dice_nodes.size()):
		var die: Node3D = _dice_nodes[i]
		if not is_instance_valid(die):
			continue
		var r_pos: Vector3 = _dice_rest_positions[i]
		var jitter_x = randf_range(-0.014, 0.014)
		var jitter_z = randf_range(-0.014, 0.014)
		var land_pos = Vector3(r_pos.x + jitter_x, r_pos.y, r_pos.z + jitter_z)
		var end_rot = Vector3(
			face_angles[randi() % 4] + 360.0,
			randf_range(-75.0, 75.0) + 360.0,
			face_angles[randi() % 4] + 360.0
		)

		var d_tw = create_tween()
		d_tw.tween_interval(float(i) * 0.045)
		d_tw.tween_property(die, "position", land_pos + Vector3(0.0, 0.14 + float(i) * 0.02, 0.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		d_tw.parallel().tween_property(die, "rotation_degrees", end_rot * 0.65, 0.24)
		d_tw.tween_property(die, "position", land_pos, 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		d_tw.parallel().tween_property(die, "rotation_degrees", end_rot, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if i == _dice_nodes.size() - 1:
			d_tw.tween_callback(func():
				for d_n in _dice_nodes:
					if is_instance_valid(d_n):
						d_n.rotation_degrees = Vector3(
							fmod(d_n.rotation_degrees.x, 360.0),
							fmod(d_n.rotation_degrees.y, 360.0),
							fmod(d_n.rotation_degrees.z, 360.0)
						)
				_spawn_prop_sparkle_burst(_dice_group_node, Vector3(0.045, 0.03, -0.01), Color(1.0, 0.86, 0.38), 6, 0.08, 0.06)
				_prop_animating["dice"] = false
			)


# 4. PERSIAN TEA SERVICE: Sugar cube hops into glass, teapot lifts & pours crimson tea, spoon stirs, steam rises!
func _animate_tea_service() -> void:
	if not _tea_group_node or not _tea_pot_node or not _tea_istikan_node:
		return
	_prop_animating["tea"] = true
	_play_prop_sfx("tap_button")
	_spawn_prop_pulse_ring(_tea_group_node, Vector3(0.0, 0.015, 0.0), Color(0.95, 0.62, 0.22), 2.5)

	var pot_rest_pos = Vector3(-0.058, 0.009, -0.028)
	var pot_rest_rot = Vector3(0.0, 28.0, 0.0)

	# Spawn a sugar cube hopping from the qandan into the istikan tea glass
	var mat_sugar = _make_mat(Color(0.97, 0.95, 0.90), 0.22, 0.0)
	var flying_sugar = _add_box(_tea_group_node, Vector3(0.015, 0.013, 0.015), Vector3(0.064, 0.068, -0.058), mat_sugar)
	var sug_tw = create_tween()
	sug_tw.tween_property(flying_sugar, "position", Vector3(0.066, 0.165, -0.008), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sug_tw.parallel().tween_property(flying_sugar, "rotation_degrees", Vector3(180.0, 90.0, 45.0), 0.18)
	sug_tw.tween_property(flying_sugar, "position", Vector3(0.068, 0.075, 0.042), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sug_tw.tween_callback(func():
		if is_instance_valid(flying_sugar):
			flying_sugar.queue_free()
		_play_prop_sfx("add_peace")
	)

	# Lift porcelain teapot, tilt over glass, pour crimson tea stream, and stir spoon
	var tw = create_tween()
	tw.tween_property(_tea_pot_node, "position", Vector3(-0.018, 0.118, 0.018), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_tea_pot_node, "rotation_degrees", Vector3(0.0, -24.0, -38.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(_tea_pour_stream):
			_tea_pour_stream.visible = true
		if is_instance_valid(_tea_spoon_pivot):
			var sp_tw = create_tween()
			sp_tw.tween_property(_tea_spoon_pivot, "rotation_degrees:y", 360.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			sp_tw.chain().tween_callback(func():
				if is_instance_valid(_tea_spoon_pivot):
					_tea_spoon_pivot.rotation_degrees.y = 0.0
			)
		# Spawn rising fragrant steam puffs above the istikan glass
		var mat_steam = StandardMaterial3D.new()
		mat_steam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_steam.albedo_color = Color(1.0, 0.96, 0.88, 0.52)
		mat_steam.emission_enabled = true
		mat_steam.emission = Color(1.0, 0.88, 0.68)
		mat_steam.emission_energy_multiplier = 0.8
		for s_i in range(4):
			var puff = _add_sphere(_tea_istikan_node, 0.014, 0.022, Vector3(randf_range(-0.01, 0.01), 0.10 + float(s_i) * 0.015, randf_range(-0.01, 0.01)), mat_steam)
			var p_tw = create_tween().set_parallel(true)
			p_tw.tween_property(puff, "position:y", 0.24 + float(s_i) * 0.03, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			p_tw.tween_property(puff, "scale", Vector3(2.2, 2.2, 2.2), 0.75)
			p_tw.chain().tween_callback(puff.queue_free)
	)
	tw.tween_interval(0.52)
	tw.tween_callback(func():
		if is_instance_valid(_tea_pour_stream):
			_tea_pour_stream.visible = false
		_play_prop_sfx("bell")
	)
	tw.tween_property(_tea_pot_node, "position", pot_rest_pos, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_tea_pot_node, "rotation_degrees", pot_rest_rot, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_prop_animating["tea"] = false
	)


# 5. MOROCCAN / PERSIAN FILIGREE BRASS LANTERN: Sways gently, flares warm golden light, and releases rising fireflies!
func _animate_lantern() -> void:
	if not _lantern_node:
		return
	_prop_animating["lantern"] = true
	_play_prop_sfx("bell")
	_spawn_prop_pulse_ring(_lantern_node, Vector3(0.0, 0.02, 0.0), Color(1.0, 0.72, 0.18), 2.5)
	_spawn_prop_sparkle_burst(_lantern_node, Vector3(0.0, 0.26, 0.0), Color(1.0, 0.78, 0.22), 8, 0.12, 0.16)

	var base_pos = Vector3(-0.68, 0.063, -1.12)
	var flare_tw = create_tween()
	flare_tw.tween_property(self, "_lantern_flare_boost", 1.35, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flare_tw.tween_property(self, "_lantern_flare_boost", 0.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tw = create_tween()
	tw.tween_property(_lantern_node, "position:y", base_pos.y + 0.055, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_lantern_node, "rotation_degrees", Vector3(8.0, 0.0, 14.0), 0.16)
	tw.tween_property(_lantern_node, "rotation_degrees", Vector3(-7.0, 0.0, -12.0), 0.18)
	tw.tween_property(_lantern_node, "rotation_degrees", Vector3(4.0, 0.0, 7.0), 0.16)
	tw.tween_property(_lantern_node, "rotation_degrees", Vector3.ZERO, 0.18)
	tw.parallel().tween_property(_lantern_node, "position:y", base_pos.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_prop_animating["lantern"] = false
	)


# 6. GAMING TOKEN BOWL & COINS: Cascading fountain wave of flipping gold, silver, and jeweled coins!
func _animate_token_bowl() -> void:
	if not _token_bowl_node or _token_coin_nodes.is_empty():
		return
	_prop_animating["tokens"] = true
	_play_prop_sfx("bell")
	_spawn_prop_pulse_ring(_token_bowl_node, Vector3(0.0, 0.025, 0.0), Color(1.0, 0.84, 0.28), 2.4)
	_spawn_prop_sparkle_burst(_token_bowl_node, Vector3(0.0, 0.06, 0.0), Color(1.0, 0.86, 0.32), 7, 0.11, 0.10)

	for i in range(_token_coin_nodes.size()):
		var coin: Node3D = _token_coin_nodes[i]
		if not is_instance_valid(coin):
			continue
		var r_pos: Vector3 = _token_coin_rest_pos[i]
		var r_rot: Vector3 = _token_coin_rest_rot[i]
		var c_tw = create_tween()
		c_tw.tween_interval(float(i) * 0.022)
		c_tw.tween_property(coin, "position:y", r_pos.y + 0.095 + float(i % 4) * 0.018, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		c_tw.parallel().tween_property(coin, "rotation_degrees:x", r_rot.x + 360.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		c_tw.tween_property(coin, "position:y", r_pos.y, 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if i == _token_coin_nodes.size() - 1:
			c_tw.tween_callback(func():
				_play_prop_sfx("add_peace")
				for j in range(_token_coin_nodes.size()):
					var c_n: Node3D = _token_coin_nodes[j]
					if is_instance_valid(c_n):
						c_n.position = _token_coin_rest_pos[j]
						c_n.rotation_degrees = _token_coin_rest_rot[j]
				_prop_animating["tokens"] = false
			)


# 7. GOLDEN CHAMPION TROPHY: Victory levitation, 360-degree celebratory spin, ruby flash, and golden star burst!
func _animate_trophy() -> void:
	if not _trophy_node:
		return
	_prop_animating["trophy"] = true
	_play_prop_sfx("correct")
	_spawn_prop_pulse_ring(_trophy_node, Vector3(0.0, 0.02, 0.0), Color(1.0, 0.85, 0.24), 2.5)
	_spawn_prop_sparkle_burst(_trophy_node, Vector3(0.0, 0.16, 0.0), Color(1.0, 0.86, 0.28), 8, 0.12, 0.12)

	var base_pos = Vector3(-1.04, 0.063, -0.16)
	var base_rot = Vector3(0.0, 25.0, 0.0)

	var tw = create_tween()
	tw.tween_property(_trophy_node, "position:y", base_pos.y + 0.135, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_trophy_node, "rotation_degrees", Vector3(-10.0, base_rot.y + 360.0, 8.0), 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_trophy_node, "position:y", base_pos.y, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_trophy_node, "rotation_degrees", base_rot + Vector3(0.0, 360.0, 0.0), 0.24)
	tw.tween_callback(func():
		_trophy_node.rotation_degrees = base_rot
		_prop_animating["trophy"] = false
	)


# 8. VINTAGE POCKET CHRONOMETER: Winding crown press, mechanical vibration hop, and rapid spinning clock hands!
func _animate_chronometer() -> void:
	if not _chronometer_node or not _watch_minute_pivot or not _watch_hour_pivot:
		return
	_prop_animating["chronometer"] = true
	_play_prop_sfx("time")
	_spawn_prop_pulse_ring(_chronometer_node, Vector3(0.0, 0.022, 0.0), Color(1.0, 0.88, 0.42), 2.2)

	var base_pos = Vector3(1.04, 0.063, 0.14)
	var base_rot = Vector3(0.0, -28.0, 0.0)

	# Depress winding crown
	if is_instance_valid(_watch_crown_node):
		var cr_tw = create_tween()
		cr_tw.tween_property(_watch_crown_node, "position:z", -0.064, 0.08)
		cr_tw.tween_property(_watch_crown_node, "position:z", -0.070, 0.12)

	# Spin minute hand 2 full revolutions and hour hand 60 degrees
	var min_start = _watch_minute_pivot.rotation_degrees.y
	var hr_start = _watch_hour_pivot.rotation_degrees.y
	var hands_tw = create_tween().set_parallel(true)
	hands_tw.tween_property(_watch_minute_pivot, "rotation_degrees:y", min_start - 720.0, 0.68).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hands_tw.tween_property(_watch_hour_pivot, "rotation_degrees:y", hr_start - 60.0, 0.68).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Mechanical watch buzz & hop
	var tw = create_tween()
	tw.tween_property(_chronometer_node, "position:y", base_pos.y + 0.055, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_chronometer_node, "rotation_degrees:z", 11.0, 0.07)
	tw.tween_property(_chronometer_node, "rotation_degrees:z", -11.0, 0.07)
	tw.tween_property(_chronometer_node, "rotation_degrees:z", 9.0, 0.07)
	tw.tween_property(_chronometer_node, "rotation_degrees:z", -9.0, 0.07)
	tw.tween_property(_chronometer_node, "rotation_degrees", base_rot, 0.12)
	tw.parallel().tween_property(_chronometer_node, "position:y", base_pos.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.22)
	tw.tween_callback(func():
		_watch_minute_pivot.rotation_degrees.y = fmod(_watch_minute_pivot.rotation_degrees.y, 360.0)
		_watch_hour_pivot.rotation_degrees.y = fmod(_watch_hour_pivot.rotation_degrees.y, 360.0)
		_spawn_prop_sparkle_burst(_chronometer_node, Vector3(0.0, 0.03, 0.0), Color(1.0, 0.88, 0.36), 5, 0.07, 0.05)
		_prop_animating["chronometer"] = false
	)
