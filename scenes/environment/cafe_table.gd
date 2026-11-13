extends Node3D

signal camera_mode_changed(is_top_down: bool)

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer
@onready var candle_light: OmniLight3D = null

# Camera Presets (3D Cafe Fekr Game Lounge Perspective)
const CAM_POS_MENU: Vector3 = Vector3(0.0, 1.44, 2.82)
const CAM_ROT_MENU: Vector3 = Vector3(-22.0, 0.0, 0.0)

# Focus points:
# - TARGET_FOCUS: Exact center of the active game board on the green felt tabletop.
# - LOUNGE_FOCUS: Slightly elevated focal point used at lounge angles so the board sits in the
#   lower half of the portrait frame while the 3D Cafe Fekr Game Lounge fills the upper half.
const TARGET_FOCUS: Vector3 = Vector3(0.0, 0.08, 0.0)
const LOUNGE_FOCUS: Vector3 = Vector3(0.0, 0.30, 0.0)

const ZOOM_DEFAULT: float = 3.04
const ZOOM_MIN: float = 1.95
const ZOOM_MAX: float = 4.50

const YAW_DEFAULT: float = 0.0
const YAW_MIN: float = -0.50
const YAW_MAX: float = 0.50

const PITCH_DEFAULT: float = -0.385 # -22.0 degrees (Signature Cafe Fekr Game Lounge angle)
const PITCH_MIN: float = -1.160     # -66.5 degrees (Steep board inspection angle)
const PITCH_MAX: float = -0.280     # -16.0 degrees (Panoramic lounge view)

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
var _is_mobile_gpu: bool = false

func _kill_camera_tween() -> void:
	if _camera_tween and is_instance_valid(_camera_tween):
		_camera_tween.kill()
		_camera_tween = null

# Top-Down 2D Camera Heights (Meters above board center in portrait)
const TOP_DOWN_HEIGHT_DEFAULT: float = 3.45
const TOP_DOWN_HEIGHT_MIN: float = 2.30
const TOP_DOWN_HEIGHT_MAX: float = 5.00
const TOP_DOWN_ZOOM_STEP: float = 0.42
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
var _active_touches: Dictionary = {}
var _prev_pinch_dist: float = -1.0
var _last_tap_time: float = 0.0
var _last_tap_pos: Vector2 = Vector2.ZERO

# Active Board, Lounge Backdrop, Dynamic Player Chairs & Animation State
var current_board_node: Node3D = null
var _lounge_root: Node3D = null
var _lounge_backdrop_root: Node3D = null
var _chairs_root: Node3D = null
var _chair_shared_mesh: ArrayMesh = null
var _chair_north: MeshInstance3D = null # Opponent 1 (Back)
var _chair_south: MeshInstance3D = null # Local Player (Front / My Side)
var _chair_west: MeshInstance3D = null  # Player 3 (Left Side)
var _chair_east: MeshInstance3D = null  # Player 4 (Right Side)
var _current_chair_count: int = 0
var _chair_poll_timer: float = 0.0

var _dynamic_props_root: Node3D = null
var _menu_showcase_root: Node3D = null
var _shared_mats: Dictionary = {}

var _menu_sway_time: float = 0.0
var _menu_parallax_target: Vector2 = Vector2.ZERO
var _menu_parallax_current: Vector2 = Vector2.ZERO

var _steam_wisps: Array[MeshInstance3D] = []
var _steam_base_positions: Array[Vector3] = []
var _steam_phases: Array[float] = []
var _lounge_anim_time: float = 0.0
var _steam_step_accum: float = 0.0
var _side_lamp_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("cafe_table")
	_is_mobile_gpu = OS.has_feature("mobile") or (OS.get_name() in ["Android", "iOS"])
	if camera:
		camera.fov = 54.0

	_build_luxury_game_environment()
	_build_menu_showcase()
	update_player_chairs(2)

	var env_node: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		env_node.environment.glow_enabled = false

	if has_node("SunLight"):
		var sun: DirectionalLight3D = get_node("SunLight") as DirectionalLight3D
		if sun:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 6.0
			sun.shadow_blur = 0.2

	if _is_mobile_gpu:
		# Mobile GPU Optimization: disable secondary OmniLights and rely on DirectionalLight + ambient sky
		if has_node("WallFillLight"):
			var wf: OmniLight3D = get_node("WallFillLight") as OmniLight3D
			if wf:
				wf.visible = false
		if has_node("TableLampLight"):
			var tl: OmniLight3D = get_node("TableLampLight") as OmniLight3D
			if tl:
				tl.light_energy = 0.55
				tl.light_specular = 0.0
		if _side_lamp_light and is_instance_valid(_side_lamp_light):
			_side_lamp_light.visible = false
		if has_node("SunLight"):
			var sun_mob: DirectionalLight3D = get_node("SunLight") as DirectionalLight3D
			if sun_mob:
				sun_mob.light_energy = 0.78
				sun_mob.light_specular = 0.18
				sun_mob.light_color = Color(1.0, 0.93, 0.82)

	var static_paths: Array[String] = [
		"FloorMesh", "WallMesh", "WallWainscot",
		"TableRoot/TableMesh", "TableRoot/TableRim", "TableRoot/TableMat",
		"TableRoot/TablePedestal", "TableRoot/Foot1", "TableRoot/Foot2"
	]
	for m_path: String in static_paths:
		if has_node(m_path):
			var n: Node = get_node(m_path)
			if n is GeometryInstance3D:
				(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	transition_to_menu_view(0.1)


func _process(delta: float) -> void:
	if _mouse_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_pressed = false
		_is_dragging = false

	# Periodically sync chair count with active match players (e.g. 2, 3, or 4 players)
	_chair_poll_timer += delta
	if _chair_poll_timer >= 0.35:
		_chair_poll_timer = 0.0
		var desired_chairs: int = _get_active_player_count()
		if desired_chairs != _current_chair_count:
			update_player_chairs(desired_chairs)

	if is_board_view_active and not is_transitioning:
		if is_top_down_view:
			if absf(top_down_current_height - top_down_target_height) > 0.001:
				top_down_current_height = lerpf(top_down_current_height, top_down_target_height, 10.0 * delta)
				camera.position = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_current_height, TARGET_FOCUS.z)
				camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		else:
			if absf(current_yaw - target_yaw) > 0.002 or absf(current_pitch - target_pitch) > 0.002 or absf(current_distance - target_distance) > 0.002:
				current_yaw = lerpf(current_yaw, target_yaw, 10.0 * delta)
				current_pitch = lerpf(current_pitch, target_pitch, 10.0 * delta)
				current_distance = lerpf(current_distance, target_distance, 10.0 * delta)
				_apply_orbit_transform()

	if not is_board_view_active and not is_transitioning:
		_menu_sway_time += delta * 0.35
		var sway_x: float = sin(_menu_sway_time) * 0.035
		var sway_y: float = cos(_menu_sway_time * 0.65) * 0.018
		_menu_parallax_current = _menu_parallax_current.lerp(_menu_parallax_target, 5.0 * delta)
		camera.position = CAM_POS_MENU + Vector3(sway_x + _menu_parallax_current.x, sway_y + _menu_parallax_current.y, 0.0)
		camera.look_at(LOUNGE_FOCUS, Vector3.UP)

	# Animate rising porcelain teacup steam wisps only in 3D view (throttled for mobile efficiency)
	if not is_top_down_view and not _steam_wisps.is_empty():
		_lounge_anim_time += delta
		_steam_step_accum += delta
		if not _is_mobile_gpu or _steam_step_accum >= 0.045:
			_steam_step_accum = 0.0
			for i: int in range(_steam_wisps.size()):
				var wisp: MeshInstance3D = _steam_wisps[i]
				if not is_instance_valid(wisp):
					continue
				var base_p: Vector3 = _steam_base_positions[i]
				var phase: float = _steam_phases[i]
				var cyc: float = fmod(_lounge_anim_time * 0.40 + phase, 1.0)
				var rise_y: float = cyc * 0.20
				var curl_x: float = sin(_lounge_anim_time * 1.7 + phase * 6.28) * (0.007 + cyc * 0.015)
				var curl_z: float = cos(_lounge_anim_time * 1.3 + phase * 6.28) * (0.005 + cyc * 0.010)
				wisp.position = base_p + Vector3(curl_x, rise_y, curl_z)
				var s_xy: float = 0.75 + cyc * 0.90
				var s_y: float = 0.85 + sin(cyc * PI) * 0.60
				wisp.scale = Vector3(s_xy, s_y, s_xy)


func _get_orbit_focus_for_pitch(pitch_rad: float) -> Vector3:
	var t_lounge: float = clampf((pitch_rad - (-0.88)) / (PITCH_DEFAULT - (-0.88)), 0.0, 1.0)
	return TARGET_FOCUS.lerp(LOUNGE_FOCUS, t_lounge)


func _apply_orbit_transform() -> void:
	var focus: Vector3 = _get_orbit_focus_for_pitch(current_pitch)
	var cos_pitch: float = cos(-current_pitch)
	var sin_pitch: float = sin(-current_pitch)

	var cam_x: float = focus.x + current_distance * sin(current_yaw) * cos_pitch
	var cam_y: float = focus.y + current_distance * sin_pitch
	var cam_z: float = focus.z + current_distance * cos(current_yaw) * cos_pitch

	camera.position = Vector3(cam_x, cam_y, cam_z)
	camera.look_at(focus, Vector3.UP)


func _sync_2d_3d_visibility_and_lighting(top_down: bool) -> void:
	# In 2D Top-Down mode:
	# 1. Hide distant wall/bookcase backdrop outside the top-down frustum to maximize mobile FPS.
	# 2. Keep lighting completely even and glare-free so the board is 100% crisp and easy to read.
	if _lounge_backdrop_root and is_instance_valid(_lounge_backdrop_root):
		_lounge_backdrop_root.visible = not top_down
	var wall_m: Node3D = get_node_or_null("WallMesh") as Node3D
	if wall_m:
		wall_m.visible = not top_down
	var wain_m: Node3D = get_node_or_null("WallWainscot") as Node3D
	if wain_m:
		wain_m.visible = not top_down

	if has_node("TableLampLight"):
		var tl: OmniLight3D = get_node("TableLampLight") as OmniLight3D
		if tl:
			tl.light_specular = 0.0
			if top_down:
				tl.light_energy = 0.35 if _is_mobile_gpu else 0.45
			else:
				tl.light_energy = 0.55 if _is_mobile_gpu else 0.82

	if has_node("SunLight"):
		var sun: DirectionalLight3D = get_node("SunLight") as DirectionalLight3D
		if sun:
			sun.light_specular = 0.05 if top_down else (0.18 if _is_mobile_gpu else 0.25)


# --- Dynamic Player Chairs Management (2, 3, or 4 Players) ---

func _get_active_player_count() -> int:
	var count: int = 2
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and "match_players" in gm:
		var mp: Variant = gm.get("match_players")
		if typeof(mp) == TYPE_ARRAY:
			var arr_sz: int = (mp as Array).size()
			if arr_sz >= 2:
				count = arr_sz
	if current_board_node and is_instance_valid(current_board_node):
		if "total_players" in current_board_node:
			var tp: int = int(current_board_node.get("total_players"))
			if tp > count:
				count = tp
		elif "player_count" in current_board_node:
			var pc: int = int(current_board_node.get("player_count"))
			if pc > count:
				count = pc
	return clampi(count, 2, 4)


func set_player_chair_count(count: int) -> void:
	update_player_chairs(count)


func update_player_chairs(player_count: int = -1) -> void:
	var count: int = player_count if player_count >= 2 else _get_active_player_count()
	count = clampi(count, 2, 4)
	_current_chair_count = count

	# North (Opponent) and South (My Side) are always present for 2+ players
	if _chair_north and is_instance_valid(_chair_north):
		_chair_north.visible = true
	if _chair_south and is_instance_valid(_chair_south):
		_chair_south.visible = true
	# West (Left Side) appears for 3 or 4 players
	if _chair_west and is_instance_valid(_chair_west):
		_chair_west.visible = (count >= 3)
	# East (Right Side) appears for 4 players
	if _chair_east and is_instance_valid(_chair_east):
		_chair_east.visible = (count >= 4)


# --- Camera Transitions ---

func transition_to_menu_view(duration: float = 1.0) -> void:
	_kill_camera_tween()
	is_board_view_active = false
	set_menu_showcase_visible(true)
	is_transitioning = true
	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	camera_mode_changed.emit(false)
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", CAM_POS_MENU, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", CAM_ROT_MENU, duration)
	_camera_tween.chain().tween_callback(func() -> void:
		is_transitioning = false
		_camera_tween = null
	)


func transition_to_board_view(duration: float = 1.1) -> void:
	_kill_camera_tween()
	is_transitioning = true
	set_menu_showcase_visible(false)
	update_player_chairs(_get_active_player_count())

	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	top_down_current_height = TOP_DOWN_HEIGHT_DEFAULT
	camera_mode_changed.emit(is_top_down_view)

	var use_pitch: float = PITCH_DEFAULT
	var use_dist: float = ZOOM_DEFAULT
	target_distance = use_dist
	current_distance = use_dist
	target_yaw = YAW_DEFAULT
	current_yaw = YAW_DEFAULT
	target_pitch = use_pitch
	current_pitch = use_pitch

	var focus: Vector3 = _get_orbit_focus_for_pitch(target_pitch)
	var cos_pitch: float = cos(-target_pitch)
	var sin_pitch: float = sin(-target_pitch)
	var end_pos: Vector3 = Vector3(
		focus.x + target_distance * sin(target_yaw) * cos_pitch,
		focus.y + target_distance * sin_pitch,
		focus.z + target_distance * cos(target_yaw) * cos_pitch
	)
	var temp_cam: Camera3D = Camera3D.new()
	add_child(temp_cam)
	temp_cam.position = end_pos
	temp_cam.look_at(focus, Vector3.UP)
	var end_rot_deg: Vector3 = temp_cam.rotation_degrees
	temp_cam.queue_free()

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", end_pos, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", end_rot_deg, duration)
	_camera_tween.chain().tween_callback(func() -> void:
		is_board_view_active = true
		is_transitioning = false
		_camera_tween = null
	)


# --- Board Spawning & Lifecycle ---

func spawn_board(board_packed_scene: PackedScene) -> Node3D:
	clear_board()
	set_menu_showcase_visible(false)
	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	camera_mode_changed.emit(false)
	if board_packed_scene:
		current_board_node = board_packed_scene.instantiate() as Node3D
		_optimize_board_for_mobile(current_board_node)
		board_container.add_child(current_board_node)
		var g_type: String = ""
		if "game_type" in current_board_node:
			g_type = str(current_board_node.get("game_type"))
		if g_type == "":
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm and "current_game_type" in gm:
				g_type = str(gm.get("current_game_type"))
		populate_props_for_game(g_type)
		update_player_chairs(_get_active_player_count())
		transition_to_board_view(1.0)
	return current_board_node


func clear_board() -> void:
	_kill_camera_tween()
	if current_board_node and is_instance_valid(current_board_node):
		if current_board_node.has_method("_disconnect_network_signals"):
			current_board_node.call("_disconnect_network_signals")
		if current_board_node.has_method("cleanup_board"):
			current_board_node.call("cleanup_board")
		if current_board_node.get_parent():
			current_board_node.get_parent().remove_child(current_board_node)
		current_board_node.queue_free()
		current_board_node = null


func reset_table_state() -> void:
	_kill_camera_tween()
	is_board_view_active = false
	is_transitioning = false
	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	top_down_current_height = TOP_DOWN_HEIGHT_DEFAULT
	target_distance = ZOOM_DEFAULT
	current_distance = ZOOM_DEFAULT
	target_yaw = YAW_DEFAULT
	current_yaw = YAW_DEFAULT
	target_pitch = PITCH_DEFAULT
	current_pitch = PITCH_DEFAULT
	update_player_chairs(2)
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
	if not is_top_down_view:
		_sync_2d_3d_visibility_and_lighting(false)
	else:
		# Soften lighting immediately so top-down transition has zero glare
		_sync_2d_3d_visibility_and_lighting(true)
		if _lounge_backdrop_root and is_instance_valid(_lounge_backdrop_root):
			_lounge_backdrop_root.visible = true

	camera_mode_changed.emit(is_top_down_view)
	is_transitioning = true

	var end_pos: Vector3 = Vector3.ZERO
	var end_rot_deg: Vector3 = Vector3.ZERO

	if is_top_down_view:
		top_down_current_height = top_down_target_height
		end_pos = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_target_height, TARGET_FOCUS.z)
		end_rot_deg = Vector3(-90.0, 0.0, 0.0)
	else:
		var focus: Vector3 = _get_orbit_focus_for_pitch(target_pitch)
		var cos_pitch: float = cos(-target_pitch)
		var sin_pitch: float = sin(-target_pitch)
		end_pos = Vector3(
			focus.x + target_distance * sin(target_yaw) * cos_pitch,
			focus.y + target_distance * sin_pitch,
			focus.z + target_distance * cos(target_yaw) * cos_pitch
		)
		var temp_cam: Camera3D = Camera3D.new()
		add_child(temp_cam)
		temp_cam.position = end_pos
		temp_cam.look_at(focus, Vector3.UP)
		end_rot_deg = temp_cam.rotation_degrees
		temp_cam.queue_free()

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", end_pos, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", end_rot_deg, duration)
	_camera_tween.chain().tween_callback(func() -> void:
		is_transitioning = false
		_camera_tween = null
		_sync_2d_3d_visibility_and_lighting(is_top_down_view)
	)


func reset_camera_orbit() -> void:
	top_down_target_height = TOP_DOWN_HEIGHT_DEFAULT
	target_yaw = YAW_DEFAULT
	target_pitch = PITCH_DEFAULT
	target_distance = ZOOM_DEFAULT


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


# --- Table Callbacks ---

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

func populate_props_for_game(_game_type: String = "") -> void:
	pass

func set_menu_parallax(normalized_offset: Vector2) -> void:
	_menu_parallax_target = Vector2(normalized_offset.x * 0.10, -normalized_offset.y * 0.06)

func set_menu_showcase_visible(_vis: bool) -> void:
	if _menu_showcase_root and is_instance_valid(_menu_showcase_root):
		_menu_showcase_root.visible = false

func _build_menu_showcase() -> void:
	if _menu_showcase_root and is_instance_valid(_menu_showcase_root):
		_menu_showcase_root.queue_free()
		_menu_showcase_root = null


# --- Input Handling for Orbit & Zoom ---

func _is_board_consuming_input() -> bool:
	if not current_board_node or not is_instance_valid(current_board_node):
		return false
	if current_board_node.has_method("is_interacting_with_piece") and bool(current_board_node.call("is_interacting_with_piece")):
		return true
	if "is_dragging_piece" in current_board_node and bool(current_board_node.get("is_dragging_piece")):
		return true
	return false


func _get_effective_pitch_min() -> float:
	var p_min: float = PITCH_MIN
	if current_board_node and is_instance_valid(current_board_node) and "camera_pitch" in current_board_node:
		p_min = minf(p_min, float(current_board_node.get("camera_pitch")) - 0.05)
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
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


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
			_is_dragging = false


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
			var pts: Array = _active_touches.values()
			var p0: Vector2 = pts[0] as Vector2
			var p1: Vector2 = pts[1] as Vector2
			_prev_pinch_dist = p0.distance_to(p1)
	else:
		_active_touches.erase(event.index)
		if _active_touches.size() < 2:
			_prev_pinch_dist = -1.0
		if _active_touches.is_empty():
			_is_dragging = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		return
	_active_touches[event.index] = event.position
	if _active_touches.size() >= 2:
		var pts: Array = _active_touches.values()
		var p0: Vector2 = pts[0] as Vector2
		var p1: Vector2 = pts[1] as Vector2
		var current_dist: float = p0.distance_to(p1)
		if _prev_pinch_dist > 0.0:
			var delta_dist: float = current_dist - _prev_pinch_dist
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


# ============================================================================
# MOBILE-OPTIMIZED 3D "CAFE FEKR GAME LOUNGE" ENVIRONMENT BUILDER
# ============================================================================

func _optimize_board_for_mobile(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh is SphereMesh:
			var sm: SphereMesh = mi.mesh as SphereMesh
			if sm.radial_segments > 18:
				sm.radial_segments = 14
				sm.rings = 7
		elif mi.mesh is CylinderMesh:
			var cm: CylinderMesh = mi.mesh as CylinderMesh
			if cm.radial_segments > 20:
				cm.radial_segments = 16
				cm.rings = 1
		elif mi.mesh is TorusMesh:
			var tm: TorusMesh = mi.mesh as TorusMesh
			if tm.rings > 20:
				tm.rings = 16
				tm.ring_segments = 8
	for ch: Node in node.get_children():
		_optimize_board_for_mobile(ch)


func _collect_static_meshes_recursive(node: Node, root_ref: Node3D, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.visible and mi.mesh != null and not mi.has_meta("skip_bake"):
			out_list.append(mi)
	for ch: Node in node.get_children():
		_collect_static_meshes_recursive(ch, root_ref, out_list)


func _compute_relative_transform(leaf: Node3D, ancestor: Node3D) -> Transform3D:
	var xf: Transform3D = leaf.transform
	var p: Node = leaf.get_parent()
	while p != null and p != ancestor:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _bake_node_tree_to_array_mesh(branch_root: Node3D) -> ArrayMesh:
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_static_meshes_recursive(branch_root, branch_root, mesh_nodes)
	if mesh_nodes.is_empty():
		return null

	var buckets: Dictionary = {} # Material -> Array[Dictionary]
	var mat_keys: Array[Material] = []

	for mi: MeshInstance3D in mesh_nodes:
		var m_res: Mesh = mi.mesh
		if m_res == null or m_res.get_surface_count() == 0:
			continue
		var mat: Material = mi.material_override
		if mat == null:
			mat = m_res.surface_get_material(0)
		if not buckets.has(mat):
			buckets[mat] = []
			mat_keys.append(mat)
		var rel_xf: Transform3D = _compute_relative_transform(mi, branch_root)
		var arr: Array = buckets[mat] as Array
		arr.append({"mesh": m_res, "xform": rel_xf})

	var merged: ArrayMesh = ArrayMesh.new()
	for mat_k: Material in mat_keys:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if mat_k != null:
			st.set_material(mat_k)
		var entries: Array = buckets[mat_k] as Array
		for item_v: Variant in entries:
			var item: Dictionary = item_v as Dictionary
			var sub_mesh: Mesh = item["mesh"] as Mesh
			var sub_xf: Transform3D = item["xform"] as Transform3D
			st.append_from(sub_mesh, 0, sub_xf)
		st.commit(merged)

	for mi_free: MeshInstance3D in mesh_nodes:
		if is_instance_valid(mi_free):
			mi_free.queue_free()

	return merged


func _bake_static_branch_to_merged_mesh(branch_root: Node3D, baked_name: String = "BakedStaticMesh") -> MeshInstance3D:
	var merged: ArrayMesh = _bake_node_tree_to_array_mesh(branch_root)
	if merged == null:
		return null
	var baked_mi: MeshInstance3D = MeshInstance3D.new()
	baked_mi.name = baked_name
	baked_mi.mesh = merged
	baked_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	branch_root.add_child(baked_mi)
	return baked_mi


func _make_mat(albedo: Color, rough: float = 0.4, metal: float = 0.0, tex: Texture2D = null, uv_scale: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv_scale
	return m


func _make_emissive_mat(albedo: Color, emit_col: Color, energy: float = 2.0, rough: float = 0.35, alpha: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	if alpha < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	m.roughness = rough
	m.emission_enabled = true
	m.emission = emit_col
	m.emission_energy_multiplier = energy
	return m


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 12) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = clampi(segs, 6, 20)
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _add_sphere(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 10) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = h
	sm.radial_segments = clampi(segs, 8, 16)
	sm.rings = clampi(segs / 2, 4, 8)
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _add_torus(parent: Node3D, inner_r: float, outer_r: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, rings: int = 14) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	tm.rings = clampi(rings, 8, 20)
	tm.ring_segments = 6
	tm.material = mat
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _init_lounge_materials() -> void:
	var wood_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/images/background2.png"):
		wood_tex = load("res://assets/images/background2.png") as Texture2D

	# Mobile-friendly velvet-baize material (zero normal-map shader overhead, zero specular glare in 2D mode)
	var mat_baize: StandardMaterial3D = StandardMaterial3D.new()
	mat_baize.albedo_color = Color(0.08, 0.27, 0.15)
	mat_baize.roughness = 0.90
	mat_baize.metallic = 0.0
	mat_baize.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mat_baize_border: StandardMaterial3D = StandardMaterial3D.new()
	mat_baize_border.albedo_color = Color(0.05, 0.19, 0.10)
	mat_baize_border.roughness = 0.92
	mat_baize_border.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mat_walnut_polished: StandardMaterial3D = _make_mat(Color(0.58, 0.33, 0.16), 0.30, 0.04, wood_tex, Vector3(1.5, 1.5, 1.5))
	var mat_walnut_mid: StandardMaterial3D = _make_mat(Color(0.45, 0.24, 0.11), 0.36, 0.03, wood_tex, Vector3(1.8, 1.8, 1.8))
	var mat_walnut_dark: StandardMaterial3D = _make_mat(Color(0.28, 0.14, 0.06), 0.40, 0.02, wood_tex, Vector3(2.0, 2.0, 2.0))
	var mat_mahogany: StandardMaterial3D = _make_mat(Color(0.42, 0.18, 0.08), 0.32, 0.04, wood_tex, Vector3(1.4, 1.4, 1.4))
	var mat_ebony_wood: StandardMaterial3D = _make_mat(Color(0.14, 0.08, 0.04), 0.34, 0.04)

	var mat_brass: StandardMaterial3D = _make_mat(Color(0.94, 0.76, 0.32), 0.24, 0.86)
	var mat_aged_brass: StandardMaterial3D = _make_mat(Color(0.76, 0.57, 0.22), 0.34, 0.80)
	var mat_emerald_jade: StandardMaterial3D = _make_mat(Color(0.10, 0.42, 0.24), 0.22, 0.15)
	var mat_bulb_glow: StandardMaterial3D = _make_emissive_mat(Color(1.0, 0.95, 0.82), Color(1.0, 0.86, 0.52), 2.80, 0.15)
	var mat_lampshade_glow: StandardMaterial3D = _make_emissive_mat(Color(0.98, 0.89, 0.68), Color(1.0, 0.80, 0.42), 1.40, 0.48)
	var mat_abajour_shade: StandardMaterial3D = _make_emissive_mat(Color(0.99, 0.90, 0.66), Color(1.0, 0.78, 0.38), 1.35, 0.42)

	var mat_leather_green: StandardMaterial3D = _make_mat(Color(0.10, 0.21, 0.11), 0.38, 0.06)
	var mat_leather_green_dark: StandardMaterial3D = _make_mat(Color(0.06, 0.13, 0.07), 0.46, 0.04)
	var mat_velvet_curtain: StandardMaterial3D = _make_mat(Color(0.48, 0.06, 0.08), 0.78, 0.02)
	var mat_marble: StandardMaterial3D = _make_mat(Color(0.92, 0.87, 0.79), 0.34, 0.02)
	var mat_porcelain: StandardMaterial3D = _make_mat(Color(0.96, 0.93, 0.86), 0.16, 0.04)
	var mat_coffee_dark: StandardMaterial3D = _make_mat(Color(0.14, 0.06, 0.02), 0.10, 0.05)
	var mat_steam: StandardMaterial3D = _make_emissive_mat(Color(0.96, 0.95, 0.94), Color(0.88, 0.84, 0.78), 0.42, 0.80, 0.22)

	var mat_leaf_dark: StandardMaterial3D = _make_mat(Color(0.12, 0.31, 0.10), 0.42, 0.02)
	var mat_leaf_mid: StandardMaterial3D = _make_mat(Color(0.19, 0.44, 0.14), 0.38, 0.02)
	var mat_leaf_bright: StandardMaterial3D = _make_mat(Color(0.27, 0.54, 0.18), 0.36, 0.02)

	var mat_book_red: StandardMaterial3D = _make_mat(Color(0.56, 0.11, 0.10), 0.48, 0.02)
	var mat_book_green: StandardMaterial3D = _make_mat(Color(0.11, 0.32, 0.18), 0.48, 0.02)
	var mat_book_navy: StandardMaterial3D = _make_mat(Color(0.12, 0.20, 0.38), 0.48, 0.02)
	var mat_book_brown: StandardMaterial3D = _make_mat(Color(0.38, 0.20, 0.09), 0.50, 0.02)
	var mat_book_ochre: StandardMaterial3D = _make_mat(Color(0.64, 0.42, 0.16), 0.48, 0.02)
	var mat_book_burgundy: StandardMaterial3D = _make_mat(Color(0.38, 0.08, 0.12), 0.48, 0.02)
	var mat_book_pages: StandardMaterial3D = _make_mat(Color(0.90, 0.84, 0.70), 0.68, 0.0)

	var mat_sky_top: StandardMaterial3D = _make_emissive_mat(Color(0.10, 0.16, 0.38), Color(0.12, 0.20, 0.48), 1.15, 0.90)
	var mat_sky_mid: StandardMaterial3D = _make_emissive_mat(Color(0.22, 0.30, 0.54), Color(0.26, 0.35, 0.62), 1.20, 0.90)
	var mat_sky_horizon: StandardMaterial3D = _make_emissive_mat(Color(0.64, 0.48, 0.34), Color(0.76, 0.56, 0.36), 1.25, 0.90)
	var mat_city_stone: StandardMaterial3D = _make_mat(Color(0.22, 0.18, 0.20), 0.65, 0.05)
	var mat_window_glow: StandardMaterial3D = _make_emissive_mat(Color(1.0, 0.86, 0.48), Color(1.0, 0.78, 0.32), 2.40, 0.20)

	_shared_mats = {
		"baize_emerald": mat_baize,
		"baize_border": mat_baize_border,
		"walnut_polished": mat_walnut_polished,
		"walnut_mid": mat_walnut_mid,
		"walnut_dark": mat_walnut_dark,
		"mahogany": mat_mahogany,
		"ebony": mat_ebony_wood,
		"brass": mat_brass,
		"aged_brass": mat_aged_brass,
		"emerald_jade": mat_emerald_jade,
		"bulb_glow": mat_bulb_glow,
		"lampshade_glow": mat_lampshade_glow,
		"abajour_shade": mat_abajour_shade,
		"leather_green": mat_leather_green,
		"leather_green_dark": mat_leather_green_dark,
		"velvet_curtain": mat_velvet_curtain,
		"marble": mat_marble,
		"porcelain": mat_porcelain,
		"coffee": mat_coffee_dark,
		"steam": mat_steam,
		"leaf_dark": mat_leaf_dark,
		"leaf_mid": mat_leaf_mid,
		"leaf_bright": mat_leaf_bright,
		"book_red": mat_book_red,
		"book_green": mat_book_green,
		"book_navy": mat_book_navy,
		"book_brown": mat_book_brown,
		"book_ochre": mat_book_ochre,
		"book_burgundy": mat_book_burgundy,
		"book_pages": mat_book_pages,
		"sky_top": mat_sky_top,
		"sky_mid": mat_sky_mid,
		"sky_horizon": mat_sky_horizon,
		"city_stone": mat_city_stone,
		"window_glow": mat_window_glow
	}


func _build_luxury_game_environment() -> void:
	_init_lounge_materials()

	var props_root: Node3D = get_node_or_null("CafeProps") as Node3D
	if not props_root:
		props_root = Node3D.new()
		props_root.name = "CafeProps"
		add_child(props_root)

	for ch: Node in props_root.get_children():
		ch.queue_free()

	_lounge_root = Node3D.new()
	_lounge_root.name = "CafeFekrLounge3D"
	props_root.add_child(_lounge_root)

	# Separate container for player chairs around the table (visible in both 3D & 2D views)
	_chairs_root = Node3D.new()
	_chairs_root.name = "PlayerChairs3D"
	_lounge_root.add_child(_chairs_root)

	# Backdrop container for room walls, bookcase, side tables, window & curtains (culled in 2D top-down mode for mobile speed)
	_lounge_backdrop_root = Node3D.new()
	_lounge_backdrop_root.name = "LoungeBackdrop3D"
	_lounge_root.add_child(_lounge_backdrop_root)

	_steam_wisps.clear()
	_steam_base_positions.clear()
	_steam_phases.clear()

	# 1. Foreground Luxury Carved Walnut Gaming Table, Reusable Green Felt & Corner Desk Abajour
	var table_root: Node3D = get_node_or_null("TableRoot") as Node3D
	if table_root:
		_build_foreground_gaming_table(table_root)
		_build_desk_abajour(table_root)

	# 2. Multi-Player Tufted Dark-Green Leather Club Chairs (2, 3, or 4 Players, Baked Shared ArrayMesh)
	_build_player_chairs_around_table(_chairs_root)

	# 3. Back 3-Bay Classical Walnut Library Bookcase, Curios, Sconces & "کافه فکر / Cafe Fekr" Sign
	_build_back_bookcase_and_sign(_lounge_backdrop_root)

	# 4. Left Arched Twilight Window (City Skyline), Left Side Table, Brass Lamp & Club Chair
	_build_left_window_and_lounge(_lounge_backdrop_root)

	# 5. Right Crimson Velvet Curtain Drapery, Right Side Table, Steaming Teacup, Books & Plant
	_build_right_curtain_and_side_table(_lounge_backdrop_root)


# ============================================================================
# 1. FOREGROUND CARVED WALNUT GAMING TABLE & DESK ABAJOUR
# ============================================================================

func _build_foreground_gaming_table(table_root: Node3D) -> void:
	var mat_baize: Material = _shared_mats["baize_emerald"]
	var mat_baize_border: Material = _shared_mats["baize_border"]
	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_mid: Material = _shared_mats["walnut_mid"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged_brass: Material = _shared_mats["aged_brass"]

	if table_root.has_node("TableMat"):
		var tm_node: MeshInstance3D = table_root.get_node("TableMat") as MeshInstance3D
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.56, 0.008, 1.52)
		bm.material = mat_baize
		tm_node.mesh = bm
		tm_node.position = Vector3(0.0, 0.062, 0.0)

	if table_root.has_node("TableMesh"):
		var t_mesh: MeshInstance3D = table_root.get_node("TableMesh") as MeshInstance3D
		var bm_top: BoxMesh = BoxMesh.new()
		bm_top.size = Vector3(1.96, 0.065, 1.88)
		bm_top.material = mat_walnut_dark
		t_mesh.mesh = bm_top
		t_mesh.position = Vector3(0.0, 0.025, 0.0)

	if table_root.has_node("TableRim"):
		var t_rim: MeshInstance3D = table_root.get_node("TableRim") as MeshInstance3D
		t_rim.visible = false

	var old_frame: Node = table_root.get_node_or_null("LuxuryArenaFrame")
	if old_frame:
		old_frame.queue_free()

	var arena_frame: Node3D = Node3D.new()
	arena_frame.name = "LuxuryArenaFrame"
	table_root.add_child(arena_frame)

	# Recessed dark-emerald felt border channel around the edge of the playing surface
	var felt_half_x: float = 0.76
	var felt_half_z: float = 0.74
	_add_box(arena_frame, Vector3(felt_half_x * 2.0, 0.002, 0.028), Vector3(0.0, 0.0655, -felt_half_z), mat_baize_border)
	_add_box(arena_frame, Vector3(felt_half_x * 2.0, 0.002, 0.028), Vector3(0.0, 0.0655, felt_half_z), mat_baize_border)
	_add_box(arena_frame, Vector3(0.028, 0.002, felt_half_z * 2.0), Vector3(-felt_half_x, 0.0655, 0.0), mat_baize_border)
	_add_box(arena_frame, Vector3(0.028, 0.002, felt_half_z * 2.0), Vector3(felt_half_x, 0.0655, 0.0), mat_baize_border)

	# Inner stepped mahogany/brass fillet molding framing the green felt
	var inner_x: float = 0.78
	var inner_z: float = 0.76
	_add_box(arena_frame, Vector3(inner_x * 2.0 + 0.04, 0.014, 0.024), Vector3(0.0, 0.069, -inner_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(inner_x * 2.0 + 0.04, 0.014, 0.024), Vector3(0.0, 0.069, inner_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.024, 0.014, inner_z * 2.0), Vector3(-inner_x, 0.069, 0.0), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.024, 0.014, inner_z * 2.0), Vector3(inner_x, 0.069, 0.0), mat_walnut_dark)

	# Fine antique-gold pinstripe along the inner wooden lip
	_add_box(arena_frame, Vector3(inner_x * 2.0, 0.003, 0.006), Vector3(0.0, 0.0765, -inner_z + 0.008), mat_aged_brass)
	_add_box(arena_frame, Vector3(inner_x * 2.0, 0.003, 0.006), Vector3(0.0, 0.0765, inner_z - 0.008), mat_aged_brass)
	_add_box(arena_frame, Vector3(0.006, 0.003, inner_z * 2.0), Vector3(-inner_x + 0.008, 0.0765, 0.0), mat_aged_brass)
	_add_box(arena_frame, Vector3(0.006, 0.003, inner_z * 2.0), Vector3(inner_x - 0.008, 0.0765, 0.0), mat_aged_brass)

	# Wide Polished Walnut Top Rails
	var rail_w: float = 0.21
	var rail_h: float = 0.022
	var rail_y: float = 0.073
	var rail_cx: float = inner_x + rail_w * 0.5
	var rail_cz: float = inner_z + rail_w * 0.5
	var full_w: float = (inner_x + rail_w) * 2.0
	var full_d: float = (inner_z + rail_w) * 2.0

	_add_box(arena_frame, Vector3(full_w, rail_h, rail_w), Vector3(0.0, rail_y, -rail_cz), mat_walnut_pol)
	_add_box(arena_frame, Vector3(full_w, rail_h, rail_w), Vector3(0.0, rail_y, rail_cz), mat_walnut_pol)
	_add_box(arena_frame, Vector3(rail_w, rail_h, inner_z * 2.0), Vector3(-rail_cx, rail_y, 0.0), mat_walnut_pol)
	_add_box(arena_frame, Vector3(rail_w, rail_h, inner_z * 2.0), Vector3(rail_cx, rail_y, 0.0), mat_walnut_pol)

	# Molded Outer Bullnose Lip & Recessed Groove on the Walnut Rails
	var groove_x: float = inner_x + rail_w * 0.76
	var groove_z: float = inner_z + rail_w * 0.76
	_add_box(arena_frame, Vector3(groove_x * 2.0, 0.004, 0.010), Vector3(0.0, 0.0845, -groove_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(groove_x * 2.0, 0.004, 0.010), Vector3(0.0, 0.0845, groove_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.010, 0.004, groove_z * 2.0), Vector3(-groove_x, 0.0845, 0.0), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.010, 0.004, groove_z * 2.0), Vector3(groove_x, 0.0845, 0.0), mat_walnut_dark)

	# Outer Stepped Ogee Rim Overhang
	_add_box(arena_frame, Vector3(full_w + 0.06, 0.028, 0.032), Vector3(0.0, 0.056, -(inner_z + rail_w + 0.01)), mat_walnut_mid)
	_add_box(arena_frame, Vector3(full_w + 0.06, 0.028, 0.032), Vector3(0.0, 0.056, (inner_z + rail_w + 0.01)), mat_walnut_mid)
	_add_box(arena_frame, Vector3(0.032, 0.028, full_d + 0.06), Vector3(-(inner_x + rail_w + 0.01), 0.056, 0.0), mat_walnut_mid)
	_add_box(arena_frame, Vector3(0.032, 0.028, full_d + 0.06), Vector3((inner_x + rail_w + 0.01), 0.056, 0.0), mat_walnut_mid)

	# 4 Ornate Sculpted Gold/Brass Corner Scroll Appliques at the 4 Inner Corners of the Felt Frame
	_build_table_corner_scroll(arena_frame, Vector3(-0.73, 0.072, -0.71), 1.0, 1.0, mat_brass, mat_aged_brass)
	_build_table_corner_scroll(arena_frame, Vector3(0.73, 0.072, -0.71), -1.0, 1.0, mat_brass, mat_aged_brass)
	_build_table_corner_scroll(arena_frame, Vector3(-0.65, 0.072, 0.71), 1.0, -1.0, mat_brass, mat_aged_brass)
	_build_table_corner_scroll(arena_frame, Vector3(0.65, 0.072, 0.71), -1.0, -1.0, mat_brass, mat_aged_brass)

	# Carved Front & Side Table Apron with Molded Panels & Corner Rosette Blocks
	var apron_y: float = -0.075
	var apron_h: float = 0.17
	var apron_z: float = 0.93
	var apron_x: float = 0.95

	_add_box(arena_frame, Vector3(1.88, apron_h, 0.045), Vector3(0.0, apron_y, apron_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(1.88, apron_h, 0.045), Vector3(0.0, apron_y, -apron_z), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.045, apron_h, 1.82), Vector3(-apron_x, apron_y, 0.0), mat_walnut_dark)
	_add_box(arena_frame, Vector3(0.045, apron_h, 1.82), Vector3(apron_x, apron_y, 0.0), mat_walnut_dark)

	_add_box(arena_frame, Vector3(1.16, 0.10, 0.018), Vector3(0.0, apron_y, apron_z + 0.022), mat_walnut_mid)
	_add_box(arena_frame, Vector3(1.10, 0.07, 0.022), Vector3(0.0, apron_y, apron_z + 0.024), mat_walnut_dark)
	_add_box(arena_frame, Vector3(1.92, 0.022, 0.058), Vector3(0.0, apron_y + 0.078, apron_z), mat_walnut_mid)
	_add_box(arena_frame, Vector3(1.92, 0.024, 0.062), Vector3(0.0, apron_y - 0.078, apron_z), mat_walnut_mid)

	for side_sign: float in [-1.0, 1.0]:
		var rx: float = side_sign * 0.65
		var rz: float = apron_z + 0.025
		_add_box(arena_frame, Vector3(0.16, 0.15, 0.028), Vector3(rx, apron_y, rz), mat_walnut_mid)
		_add_box(arena_frame, Vector3(0.125, 0.115, 0.032), Vector3(rx, apron_y, rz + 0.003), mat_walnut_dark)
		_add_sphere(arena_frame, 0.018, 0.016, Vector3(rx, apron_y, rz + 0.020), mat_aged_brass)
		for p_i: int in range(8):
			var ang: float = float(p_i) * PI * 0.25
			var px: float = rx + cos(ang) * 0.032
			var py: float = apron_y + sin(ang) * 0.032
			_add_sphere(arena_frame, 0.013, 0.012, Vector3(px, py, rz + 0.018), mat_walnut_pol)

	for lx_sign: float in [-1.0, 1.0]:
		for lz_sign: float in [-1.0, 1.0]:
			var leg_x: float = lx_sign * 0.84
			var leg_z: float = lz_sign * 0.84
			_add_cyl(arena_frame, 0.068, 0.052, 0.64, Vector3(leg_x, -0.46, leg_z), mat_walnut_dark, Vector3.ZERO, 12)
			_add_sphere(arena_frame, 0.078, 0.095, Vector3(leg_x, -0.26, leg_z), mat_walnut_mid)

	# Bake all table frame moldings, corner scrolls, rosettes, and legs into 1 single draw-call mesh!
	_bake_static_branch_to_merged_mesh(arena_frame, "BakedTableFrameMesh")


func _build_table_corner_scroll(parent: Node3D, corner_pos: Vector3, dir_x: float, dir_z: float, mat_brass: Material, mat_aged_brass: Material) -> void:
	var scroll_root: Node3D = Node3D.new()
	scroll_root.position = corner_pos
	parent.add_child(scroll_root)

	_add_cyl(scroll_root, 0.034, 0.040, 0.012, Vector3(0.0, 0.006, 0.0), mat_aged_brass, Vector3.ZERO, 10)
	_add_sphere(scroll_root, 0.024, 0.018, Vector3(0.0, 0.010, 0.0), mat_brass)
	_add_torus(scroll_root, 0.024, 0.034, Vector3(0.0, 0.008, 0.0), mat_brass)
	_add_sphere(scroll_root, 0.018, 0.014, Vector3(dir_x * 0.026, 0.009, dir_z * 0.026), mat_brass)

	for step_i: int in range(1, 5):
		var t: float = float(step_i)
		var sx: float = dir_x * (0.028 + t * 0.026)
		var sz: float = -dir_z * (0.006 - sin(t * 0.8) * 0.010)
		var r_s: float = 0.020 - t * 0.003
		_add_sphere(scroll_root, r_s, 0.013, Vector3(sx, 0.008, sz), mat_brass)
	_add_torus(scroll_root, 0.014, 0.022, Vector3(dir_x * 0.075, 0.008, -dir_z * 0.012), mat_brass)
	_add_torus(scroll_root, 0.010, 0.016, Vector3(dir_x * 0.125, 0.008, dir_z * 0.006), mat_aged_brass)

	for step_j: int in range(1, 5):
		var tj: float = float(step_j)
		var sz_j: float = dir_z * (0.028 + tj * 0.026)
		var sx_j: float = -dir_x * (0.006 - sin(tj * 0.8) * 0.010)
		var r_sj: float = 0.020 - tj * 0.003
		_add_sphere(scroll_root, r_sj, 0.013, Vector3(sx_j, 0.008, sz_j), mat_brass)
	_add_torus(scroll_root, 0.014, 0.022, Vector3(-dir_x * 0.012, 0.008, dir_z * 0.075), mat_brass)
	_add_torus(scroll_root, 0.010, 0.016, Vector3(dir_x * 0.006, 0.008, dir_z * 0.125), mat_aged_brass)


func _build_desk_abajour(table_root: Node3D) -> void:
	var old_abajour: Node = table_root.get_node_or_null("DeskAbajour")
	if old_abajour:
		old_abajour.queue_free()

	# Positioned on the upper-left polished walnut rail corner of the gaming desk,
	# completely outside the central green felt playing surface so it never blocks any game board!
	var abajour: Node3D = Node3D.new()
	abajour.name = "DeskAbajour"
	abajour.position = Vector3(-0.76, 0.084, -0.82)
	table_root.add_child(abajour)

	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged_brass: Material = _shared_mats["aged_brass"]
	var mat_jade: Material = _shared_mats["emerald_jade"]
	var mat_shade: Material = _shared_mats["abajour_shade"]
	var mat_bulb: Material = _shared_mats["bulb_glow"]
	var mat_baize: Material = _shared_mats["baize_border"]

	# Protective Emerald Felt Coaster Pad & Stepped Antique Brass Plinth
	_add_cyl(abajour, 0.078, 0.082, 0.005, Vector3(0.0, 0.0025, 0.0), mat_baize, Vector3.ZERO, 14)
	_add_cyl(abajour, 0.068, 0.076, 0.016, Vector3(0.0, 0.012, 0.0), mat_aged_brass, Vector3.ZERO, 16)
	_add_cyl(abajour, 0.048, 0.064, 0.018, Vector3(0.0, 0.028, 0.0), mat_brass, Vector3.ZERO, 16)
	_add_torus(abajour, 0.036, 0.048, Vector3(0.0, 0.038, 0.0), mat_brass, Vector3.ZERO, 14)

	# Turned Emerald-Jade & Gadrooned Brass Column Stem
	_add_sphere(abajour, 0.042, 0.062, Vector3(0.0, 0.072, 0.0), mat_jade, Vector3.ZERO, 14)
	_add_torus(abajour, 0.032, 0.044, Vector3(0.0, 0.072, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_cyl(abajour, 0.018, 0.024, 0.075, Vector3(0.0, 0.132, 0.0), mat_brass, Vector3.ZERO, 12)
	_add_sphere(abajour, 0.024, 0.030, Vector3(0.0, 0.168, 0.0), mat_aged_brass, Vector3.ZERO, 12)

	# Twin Delicate Brass Pull-Chains with Acorn Finials Beneath the Shade
	for chain_s: float in [-1.0, 1.0]:
		var cx: float = chain_s * 0.034
		_add_cyl(abajour, 0.0025, 0.0025, 0.052, Vector3(cx, 0.155, 0.012), mat_brass, Vector3.ZERO, 6)
		_add_sphere(abajour, 0.0065, 0.012, Vector3(cx, 0.126, 0.012), mat_brass, Vector3.ZERO, 8)

	# Warm Glowing Bulb Core & Classic Pleated Empire Silk Abajour Shade
	var shade_y: float = 0.228
	_add_sphere(abajour, 0.026, 0.042, Vector3(0.0, shade_y - 0.02, 0.0), mat_bulb, Vector3.ZERO, 10)
	_add_cyl(abajour, 0.066, 0.132, 0.128, Vector3(0.0, shade_y, 0.0), mat_shade, Vector3.ZERO, 20)

	# Upper & Lower Braided Brass Shade Rims + Decorative Ribs + Crown Finial
	_add_torus(abajour, 0.062, 0.070, Vector3(0.0, shade_y + 0.064, 0.0), mat_brass, Vector3.ZERO, 18)
	_add_torus(abajour, 0.128, 0.136, Vector3(0.0, shade_y - 0.064, 0.0), mat_brass, Vector3.ZERO, 20)
	_add_cyl(abajour, 0.006, 0.014, 0.026, Vector3(0.0, shade_y + 0.078, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_sphere(abajour, 0.010, 0.018, Vector3(0.0, shade_y + 0.095, 0.0), mat_brass, Vector3.ZERO, 10)

	# Bake the Desk Abajour into a single multi-surface MeshInstance3D
	_bake_static_branch_to_merged_mesh(abajour, "BakedDeskAbajourMesh")


# ============================================================================
# 2. MULTI-PLAYER TUFTED DARK-GREEN LEATHER CHAIRS (2, 3, OR 4 PLAYERS)
# ============================================================================

func _build_player_chairs_around_table(chairs_parent: Node3D) -> void:
	# Build one detailed chair template and bake it into a single shared ArrayMesh
	# so rendering 2, 3, or 4 chairs around the table uses only 1 MeshInstance3D per chair!
	var temp_chair: Node3D = Node3D.new()
	_populate_tufted_chair_geometry(temp_chair)
	_chair_shared_mesh = _bake_node_tree_to_array_mesh(temp_chair)
	temp_chair.free()

	if _chair_shared_mesh == null:
		return

	# 1. NORTH CHAIR (Opponent Side — Behind Table, Facing +Z)
	_chair_north = MeshInstance3D.new()
	_chair_north.name = "NorthOpponentChair"
	_chair_north.mesh = _chair_shared_mesh
	_chair_north.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_north.position = Vector3(0.0, 0.0, -1.42)
	_chair_north.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	chairs_parent.add_child(_chair_north)

	# 2. SOUTH CHAIR (My Side — Front of Table, Facing -Z)
	# Positioned at Z = +1.22, Y = -0.22 so its arched walnut crest rail, brass nailhead studs,
	# and upper diamond-tufted green leather backrest are visible in both 3D & 2D views without blocking the board!
	_chair_south = MeshInstance3D.new()
	_chair_south.name = "SouthPlayerChair"
	_chair_south.mesh = _chair_shared_mesh
	_chair_south.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_south.position = Vector3(0.0, -0.22, 1.22)
	_chair_south.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	chairs_parent.add_child(_chair_south)

	# 3. WEST CHAIR (Player 3 — Left Side of Table, Angled Toward Table Center)
	_chair_west = MeshInstance3D.new()
	_chair_west.name = "WestPlayerChair"
	_chair_west.mesh = _chair_shared_mesh
	_chair_west.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_west.position = Vector3(-0.92, -0.05, -0.40)
	_chair_west.rotation_degrees = Vector3(0.0, 68.0, 0.0)
	_chair_west.scale = Vector3(0.88, 0.88, 0.88)
	_chair_west.visible = false
	chairs_parent.add_child(_chair_west)

	# 4. EAST CHAIR (Player 4 — Right Side of Table, Angled Toward Table Center)
	_chair_east = MeshInstance3D.new()
	_chair_east.name = "EastPlayerChair"
	_chair_east.mesh = _chair_shared_mesh
	_chair_east.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_east.position = Vector3(0.92, -0.05, -0.40)
	_chair_east.rotation_degrees = Vector3(0.0, -68.0, 0.0)
	_chair_east.scale = Vector3(0.88, 0.88, 0.88)
	_chair_east.visible = false
	chairs_parent.add_child(_chair_east)


func _populate_tufted_chair_geometry(chair: Node3D) -> void:
	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_leather: Material = _shared_mats["leather_green"]
	var mat_leather_dark: Material = _shared_mats["leather_green_dark"]
	var mat_brass: Material = _shared_mats["brass"]

	# Main Curved Leather Backrest Shell & Seat Cushion
	_add_box(chair, Vector3(0.82, 0.54, 0.085), Vector3(0.0, 0.16, 0.0), mat_leather_dark, Vector3(-5.0, 0.0, 0.0))
	_add_cyl(chair, 0.41, 0.41, 0.085, Vector3(0.0, 0.22, 0.0), mat_leather_dark, Vector3(85.0, 0.0, 0.0), 18)
	_add_box(chair, Vector3(0.80, 0.12, 0.44), Vector3(0.0, -0.12, 0.22), mat_leather_dark)
	_add_box(chair, Vector3(0.74, 0.08, 0.40), Vector3(0.0, -0.06, 0.22), mat_leather)

	# Diamond-Tufted Padded Green Leather Cushion Puffs (both front & back of backrest so South chair looks rich from behind too!)
	var row_ys: Array[float] = [0.36, 0.25, 0.14, 0.03]
	for r_idx: int in range(row_ys.size()):
		var ry: float = row_ys[r_idx]
		var cols: int = 5 if (r_idx % 2 == 0) else 4
		var spacing: float = 0.145
		var start_x: float = -float(cols - 1) * spacing * 0.5
		for c_idx: int in range(cols):
			var cx: float = start_x + float(c_idx) * spacing
			var arch_drop: float = (cx * cx) * 0.28
			var py: float = ry - arch_drop
			var pz: float = 0.040 + (0.20 - absf(py - 0.20)) * 0.045
			_add_box(chair, Vector3(0.105, 0.105, 0.056), Vector3(cx, py, 0.0), mat_leather, Vector3(-5.0, 0.0, 45.0))
			_add_sphere(chair, 0.062, 0.048, Vector3(cx, py, pz + 0.010), mat_leather, Vector3(90.0, 0.0, 0.0), 10)
			_add_sphere(chair, 0.058, 0.042, Vector3(cx, py, -0.038), mat_leather, Vector3(90.0, 0.0, 0.0), 10)
			if r_idx < 3 and c_idx < cols - 1:
				var bx: float = cx + spacing * 0.5
				var by: float = py - spacing * 0.38
				_add_sphere(chair, 0.008, 0.008, Vector3(bx, by, pz + 0.026), mat_brass, Vector3.ZERO, 8)
				_add_sphere(chair, 0.008, 0.008, Vector3(bx, by, -0.048), mat_brass, Vector3.ZERO, 8)

	# Carved Arched Walnut Crest Rail & Side Stiles
	var arch_segs: int = 9
	for i: int in range(arch_segs):
		var t: float = float(i) / float(arch_segs - 1)
		var ang: float = lerpf(-1.12, 1.12, t)
		var ax: float = sin(ang) * 0.47
		var ay: float = 0.12 + cos(ang) * 0.34
		var rot_z: float = -rad_to_deg(ang) * 0.72
		_add_box(chair, Vector3(0.13, 0.048, 0.092), Vector3(ax, ay, 0.005), mat_walnut_pol, Vector3(-5.0, 0.0, rot_z))
		var nx: float = sin(ang) * 0.42
		var ny: float = 0.11 + cos(ang) * 0.30
		_add_sphere(chair, 0.0075, 0.012, Vector3(nx, ny, 0.054), mat_brass, Vector3.ZERO, 8)
		_add_sphere(chair, 0.0075, 0.012, Vector3(nx, ny, -0.046), mat_brass, Vector3.ZERO, 8)

	# Scrolled Walnut Ear Knuckles, Side Posts & Curved Armrests
	for side_s: float in [-1.0, 1.0]:
		_add_sphere(chair, 0.046, 0.072, Vector3(side_s * 0.45, 0.31, 0.01), mat_walnut_pol, Vector3.ZERO, 10)
		_add_torus(chair, 0.026, 0.044, Vector3(side_s * 0.45, 0.31, 0.02), mat_walnut_pol, Vector3(90.0, 0.0, 0.0), 12)
		_add_box(chair, Vector3(0.056, 0.42, 0.088), Vector3(side_s * 0.43, 0.10, 0.005), mat_walnut_pol, Vector3(-5.0, 0.0, side_s * -4.0))
		for n_idx: int in range(6):
			var n_y: float = -0.04 + float(n_idx) * 0.056
			var n_x: float = side_s * (0.39 + float(n_idx) * 0.003)
			_add_sphere(chair, 0.0075, 0.012, Vector3(n_x, n_y, 0.054), mat_brass, Vector3.ZERO, 8)
		_add_box(chair, Vector3(0.062, 0.040, 0.36), Vector3(side_s * 0.46, 0.02, 0.18), mat_walnut_pol, Vector3(4.0, side_s * -6.0, 0.0))
		_add_sphere(chair, 0.036, 0.046, Vector3(side_s * 0.44, 0.01, 0.35), mat_walnut_pol, Vector3.ZERO, 10)
		_add_cyl(chair, 0.024, 0.020, 0.22, Vector3(side_s * 0.44, -0.09, 0.32), mat_walnut_dark, Vector3.ZERO, 10)


# ============================================================================
# 3. BACK 3-BAY CLASSICAL LIBRARY BOOKCASE, SCONCES & "کافه فکر" SIGN
# ============================================================================

func _build_back_bookcase_and_sign(parent: Node3D) -> void:
	var bc: Node3D = Node3D.new()
	bc.name = "BackBookcase3D"
	bc.position = Vector3(0.0, 0.0, -2.38)
	parent.add_child(bc)

	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_mid: Material = _shared_mats["walnut_mid"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_mahogany: Material = _shared_mats["mahogany"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged_brass: Material = _shared_mats["aged_brass"]
	var mat_shade: Material = _shared_mats["lampshade_glow"]

	# Back Wood Paneling Wall
	_add_box(bc, Vector3(3.40, 2.90, 0.06), Vector3(0.0, 0.65, -0.14), mat_walnut_dark)

	# 4 Fluted Vertical Bookcase Pilasters
	var pilaster_xs: Array[float] = [-1.24, -0.68, 0.68, 1.24]
	for px: float in pilaster_xs:
		_add_box(bc, Vector3(0.085, 2.75, 0.24), Vector3(px, 0.60, 0.0), mat_walnut_mid)
		_add_box(bc, Vector3(0.105, 0.08, 0.27), Vector3(px, 1.52, 0.01), mat_walnut_pol)
		_add_box(bc, Vector3(0.105, 0.06, 0.26), Vector3(px, 0.54, 0.01), mat_walnut_pol)
		if absf(px) < 0.9:
			_add_box(bc, Vector3(0.036, 0.22, 0.03), Vector3(px, 1.38, 0.125), mat_aged_brass)

	for side_s: float in [-1.0, 1.0]:
		_add_box(bc, Vector3(0.16, 2.75, 0.22), Vector3(side_s * 1.34, 0.60, 0.02), mat_walnut_mid)

	# Full-Width Upper Attic Bookshelf & Crown Cornice
	_add_box(bc, Vector3(2.85, 0.045, 0.28), Vector3(0.0, 1.54, 0.02), mat_walnut_pol)
	_add_box(bc, Vector3(2.92, 0.065, 0.32), Vector3(0.0, 1.86, 0.04), mat_walnut_pol)
	_populate_book_row(bc, -1.16, -0.72, 1.565, -0.02, 7, 0.21, 0.25)
	_populate_book_row(bc, -0.60, 0.60, 1.565, -0.02, 18, 0.21, 0.26)
	_populate_book_row(bc, 0.72, 1.16, 1.565, -0.02, 7, 0.21, 0.25)

	# Center Bay: Ornate Scalloped "کافه فکر / Cafe Fekr" Sign Plaque
	_build_cafe_fekr_plaque(bc, Vector3(0.0, 1.14, 0.04), mat_mahogany, mat_walnut_dark, mat_brass, mat_aged_brass)

	# Center Bay Shelves
	_add_box(bc, Vector3(1.30, 0.042, 0.26), Vector3(0.0, 0.54, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(1.30, 0.042, 0.26), Vector3(0.0, 0.14, 0.01), mat_walnut_pol)
	_populate_book_row(bc, -0.61, -0.20, 0.562, 0.0, 8, 0.20, 0.25)
	_populate_book_row(bc, 0.20, 0.61, 0.562, 0.0, 8, 0.20, 0.25)

	_build_horizontal_book(bc, Vector3(0.0, 0.582, 0.02), Vector3(0.32, 0.042, 0.20), _shared_mats["book_brown"], 2.0)
	_build_horizontal_book(bc, Vector3(0.0, 0.624, 0.02), Vector3(0.28, 0.038, 0.18), _shared_mats["book_red"], -3.0)
	_build_horizontal_book(bc, Vector3(0.0, 0.660, 0.02), Vector3(0.24, 0.034, 0.16), _shared_mats["book_green"], 1.5)
	_add_cyl(bc, 0.028, 0.038, 0.022, Vector3(0.02, 0.688, 0.03), mat_brass, Vector3.ZERO, 10)
	_add_sphere(bc, 0.042, 0.052, Vector3(0.02, 0.718, 0.03), mat_brass, Vector3.ZERO, 10)
	_add_cyl(bc, 0.012, 0.024, 0.028, Vector3(0.02, 0.752, 0.03), mat_aged_brass, Vector3.ZERO, 10)
	_add_sphere(bc, 0.014, 0.022, Vector3(0.02, 0.772, 0.03), mat_brass, Vector3.ZERO, 8)

	_populate_book_row(bc, -0.61, -0.32, 0.162, 0.0, 5, 0.20, 0.24)
	_populate_book_row(bc, 0.32, 0.61, 0.162, 0.0, 5, 0.20, 0.24)

	# Left Bookcase Bay
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(-0.96, 1.22, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(-0.96, 0.64, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(-0.96, 0.28, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(-0.96, -0.08, 0.01), mat_walnut_pol)
	_populate_book_row(bc, -1.17, -0.78, 1.24, 0.0, 7, 0.19, 0.23)
	_build_trailing_ivy_vine(bc, Vector3(-0.73, 1.26, 0.11), 0.50, -1.0)
	_build_armillary_sphere(bc, Vector3(-0.94, 0.66, 0.04), mat_brass, mat_aged_brass, mat_walnut_dark)
	_populate_book_row(bc, -1.17, -0.76, 0.30, 0.0, 7, 0.19, 0.23)
	_populate_book_row(bc, -1.17, -0.76, -0.06, 0.0, 7, 0.19, 0.23)

	# Right Bookcase Bay
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(0.96, 1.22, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(0.96, 0.78, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(0.96, 0.42, 0.01), mat_walnut_pol)
	_add_box(bc, Vector3(0.50, 0.038, 0.25), Vector3(0.96, 0.06, 0.01), mat_walnut_pol)
	_populate_book_row(bc, 0.78, 1.17, 1.24, 0.0, 7, 0.19, 0.23)
	_build_marble_portrait_bust(bc, Vector3(0.94, 0.80, 0.04), _shared_mats["marble"])
	_build_trailing_ivy_vine(bc, Vector3(1.06, 0.82, 0.11), 0.44, 1.0)
	_populate_book_row(bc, 0.74, 0.88, 0.44, 0.0, 3, 0.22, 0.25)
	_build_vintage_shelf_clock(bc, Vector3(1.01, 0.44, 0.04), mat_brass, mat_aged_brass, _shared_mats["porcelain"], mat_walnut_dark)
	_populate_book_row(bc, 0.75, 1.17, 0.08, 0.0, 7, 0.19, 0.23)

	# Two Symmetrical Brass Wall Sconces Mounted on the Outer Pilasters
	for sconce_s: float in [-1.0, 1.0]:
		var sc: Node3D = Node3D.new()
		sc.position = Vector3(sconce_s * 0.98, 1.32, 0.12)
		bc.add_child(sc)
		_add_cyl(sc, 0.036, 0.036, 0.018, Vector3(0.0, -0.08, -0.04), mat_brass, Vector3(90.0, 0.0, 0.0), 12)
		_add_sphere(sc, 0.022, 0.055, Vector3(0.0, -0.12, -0.03), mat_aged_brass, Vector3.ZERO, 10)
		_add_torus(sc, 0.024, 0.034, Vector3(0.0, -0.09, 0.01), mat_brass, Vector3(0.0, 90.0, 0.0), 10)
		_add_cyl(sc, 0.032, 0.018, 0.022, Vector3(0.0, -0.045, 0.04), mat_brass, Vector3.ZERO, 12)
		_add_cyl(sc, 0.012, 0.012, 0.045, Vector3(0.0, -0.015, 0.04), mat_aged_brass, Vector3.ZERO, 8)
		_add_cyl(sc, 0.052, 0.092, 0.135, Vector3(0.0, 0.065, 0.04), mat_shade, Vector3.ZERO, 14)
		_add_torus(sc, 0.048, 0.056, Vector3(0.0, 0.132, 0.04), mat_brass, Vector3.ZERO, 14)
		_add_torus(sc, 0.088, 0.096, Vector3(0.0, -0.002, 0.04), mat_brass, Vector3.ZERO, 14)

	# Bake the entire 3-Bay Bookcase, Books, Armillary Sphere, Bust, Clock, Ivy & Sconces into 1 MeshInstance3D!
	_bake_static_branch_to_merged_mesh(bc, "BakedBookcaseMesh")


func _build_cafe_fekr_plaque(parent: Node3D, pos: Vector3, mat_mahogany: Material, mat_walnut_dark: Material, mat_brass: Material, mat_aged_brass: Material) -> void:
	var plaque: Node3D = Node3D.new()
	plaque.name = "CafeFekrPlaque"
	plaque.position = pos
	parent.add_child(plaque)

	_add_box(plaque, Vector3(1.16, 0.56, 0.036), Vector3(0.0, 0.0, 0.0), mat_walnut_dark)
	_add_box(plaque, Vector3(1.08, 0.50, 0.046), Vector3(0.0, 0.0, 0.008), mat_mahogany)
	_add_cyl(plaque, 0.34, 0.34, 0.046, Vector3(0.0, 0.12, 0.008), mat_mahogany, Vector3(90.0, 0.0, 0.0), 18)
	_add_cyl(plaque, 0.24, 0.24, 0.044, Vector3(0.0, -0.10, 0.006), mat_mahogany, Vector3(90.0, 0.0, 0.0), 16)

	var fw: float = 1.10
	var fh: float = 0.50
	var arch_pts: int = 9
	for i: int in range(arch_pts):
		var t: float = float(i) / float(arch_pts - 1)
		var ang: float = lerpf(-0.95, 0.95, t)
		var ax: float = sin(ang) * 0.38
		var ay: float = 0.06 + cos(ang) * 0.26
		var rz: float = -rad_to_deg(ang) * 0.65
		_add_box(plaque, Vector3(0.11, 0.022, 0.022), Vector3(ax, ay, 0.028), mat_brass, Vector3(0.0, 0.0, rz))
		_add_box(plaque, Vector3(0.10, 0.012, 0.024), Vector3(ax * 0.94, ay - 0.022, 0.030), mat_aged_brass, Vector3(0.0, 0.0, rz))

	_add_box(plaque, Vector3(0.24, 0.022, 0.022), Vector3(-0.42, 0.22, 0.028), mat_brass)
	_add_box(plaque, Vector3(0.24, 0.022, 0.022), Vector3(0.42, 0.22, 0.028), mat_brass)
	_add_box(plaque, Vector3(fw * 0.86, 0.022, 0.022), Vector3(0.0, -0.25, 0.028), mat_brass)
	_add_box(plaque, Vector3(fw * 0.80, 0.012, 0.024), Vector3(0.0, -0.225, 0.030), mat_aged_brass)
	_add_box(plaque, Vector3(0.022, fh * 0.86, 0.022), Vector3(-0.54, -0.01, 0.028), mat_brass)
	_add_box(plaque, Vector3(0.022, fh * 0.86, 0.022), Vector3(0.54, -0.01, 0.028), mat_brass)
	_add_box(plaque, Vector3(0.012, fh * 0.78, 0.024), Vector3(-0.515, -0.01, 0.030), mat_aged_brass)
	_add_box(plaque, Vector3(0.012, fh * 0.78, 0.024), Vector3(0.515, -0.01, 0.030), mat_aged_brass)

	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_add_torus(plaque, 0.022, 0.034, Vector3(sx * 0.51, sy * 0.21, 0.028), mat_brass, Vector3(90.0, 0.0, 0.0), 12)
			_add_sphere(plaque, 0.016, 0.016, Vector3(sx * 0.54, sy * 0.24, 0.030), mat_brass, Vector3.ZERO, 8)

	# 3D Sculpted Golden Steaming Coffee Cup Emblem
	var cup_emblem: Node3D = Node3D.new()
	cup_emblem.position = Vector3(0.0, 0.175, 0.036)
	plaque.add_child(cup_emblem)
	_add_box(cup_emblem, Vector3(0.135, 0.012, 0.016), Vector3(0.0, -0.036, 0.0), mat_brass)
	_add_cyl(cup_emblem, 0.048, 0.068, 0.012, Vector3(0.0, -0.030, 0.0), mat_brass, Vector3.ZERO, 12)
	_add_cyl(cup_emblem, 0.042, 0.028, 0.056, Vector3(0.0, 0.002, 0.0), mat_brass, Vector3.ZERO, 12)
	_add_torus(cup_emblem, 0.012, 0.020, Vector3(0.044, 0.004, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 10)
	for w_i: int in range(-1, 2):
		var wx: float = float(w_i) * 0.020
		var wh: float = 0.042 if w_i == 0 else 0.032
		_add_box(cup_emblem, Vector3(0.007, wh, 0.012), Vector3(wx, 0.054, 0.0), mat_brass, Vector3(0.0, 0.0, float(w_i) * -12.0))

	var font_fa: FontFile = null
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		font_fa = load("res://assets/fonts/hekayat.ttf") as FontFile
	var font_en: FontFile = null
	if ResourceLoader.exists("res://assets/fonts/Vazir.ttf"):
		font_en = load("res://assets/fonts/Vazir.ttf") as FontFile

	var lbl_fa_shadow: Label3D = Label3D.new()
	lbl_fa_shadow.text = "کافه فکر"
	if font_fa:
		lbl_fa_shadow.font = font_fa
	lbl_fa_shadow.font_size = 126
	lbl_fa_shadow.pixel_size = 0.0019
	lbl_fa_shadow.modulate = Color(0.14, 0.06, 0.02, 1.0)
	lbl_fa_shadow.outline_size = 18
	lbl_fa_shadow.outline_modulate = Color(0.10, 0.04, 0.01, 1.0)
	lbl_fa_shadow.position = Vector3(0.006, 0.005, 0.035)
	plaque.add_child(lbl_fa_shadow)

	var lbl_fa: Label3D = Label3D.new()
	lbl_fa.text = "کافه فکر"
	if font_fa:
		lbl_fa.font = font_fa
	lbl_fa.font_size = 126
	lbl_fa.pixel_size = 0.0019
	lbl_fa.modulate = Color(0.98, 0.83, 0.44, 1.0)
	lbl_fa.outline_size = 14
	lbl_fa.outline_modulate = Color(0.28, 0.14, 0.04, 1.0)
	lbl_fa.position = Vector3(0.0, 0.012, 0.044)
	plaque.add_child(lbl_fa)

	var lbl_en: Label3D = Label3D.new()
	lbl_en.text = "Cafe Fekr"
	if font_en:
		lbl_en.font = font_en
	lbl_en.font_size = 64
	lbl_en.pixel_size = 0.0018
	lbl_en.modulate = Color(0.94, 0.77, 0.38, 1.0)
	lbl_en.outline_size = 12
	lbl_en.outline_modulate = Color(0.18, 0.08, 0.02, 1.0)
	lbl_en.position = Vector3(0.0, -0.145, 0.044)
	plaque.add_child(lbl_en)


func _populate_book_row(parent: Node3D, x_start: float, x_end: float, y_shelf: float, z_pos: float, count: int, h_min: float, h_max: float) -> void:
	var book_mats: Array[Material] = [
		_shared_mats["book_red"],
		_shared_mats["book_green"],
		_shared_mats["book_navy"],
		_shared_mats["book_brown"],
		_shared_mats["book_ochre"],
		_shared_mats["book_burgundy"]
	]
	var mat_brass: Material = _shared_mats["aged_brass"]
	var total_w: float = x_end - x_start
	var step_x: float = total_w / float(maxi(count, 1))

	for i: int in range(count):
		var bx: float = x_start + (float(i) + 0.5) * step_x
		var bw: float = step_x * 0.88
		var bh: float = lerpf(h_min, h_max, float((i * 7 + 3) % 11) / 10.0)
		var bd: float = 0.16 + float((i * 5) % 4) * 0.012
		var b_mat: Material = book_mats[(i * 3 + int(absf(x_start * 10.0))) % book_mats.size()]
		var tilt_z: float = 0.0
		if i == count - 1 and count >= 5:
			tilt_z = 7.5
		_add_box(parent, Vector3(bw, bh, bd), Vector3(bx, y_shelf + bh * 0.5, z_pos), b_mat, Vector3(0.0, 0.0, tilt_z))
		_add_box(parent, Vector3(bw * 0.92, 0.008, 0.006), Vector3(bx, y_shelf + bh * 0.78, z_pos + bd * 0.5 + 0.002), mat_brass, Vector3(0.0, 0.0, tilt_z))
		_add_box(parent, Vector3(bw * 0.92, 0.008, 0.006), Vector3(bx, y_shelf + bh * 0.24, z_pos + bd * 0.5 + 0.002), mat_brass, Vector3(0.0, 0.0, tilt_z))


func _build_horizontal_book(parent: Node3D, pos: Vector3, size: Vector3, mat_cover: Material, yaw_deg: float) -> void:
	var b_node: Node3D = Node3D.new()
	b_node.position = pos
	b_node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(b_node)
	_add_box(b_node, size, Vector3.ZERO, mat_cover)
	_add_box(b_node, Vector3(size.x * 0.94, size.y * 0.74, size.z * 0.92), Vector3(0.0, 0.0, 0.004), _shared_mats["book_pages"])
	_add_box(b_node, Vector3(size.x * 0.98, size.y, 0.012), Vector3(0.0, 0.0, size.z * 0.5), mat_cover)
	_add_box(b_node, Vector3(0.010, size.y * 0.92, 0.016), Vector3(-size.x * 0.30, 0.0, size.z * 0.5), _shared_mats["aged_brass"])
	_add_box(b_node, Vector3(0.010, size.y * 0.92, 0.016), Vector3(size.x * 0.30, 0.0, size.z * 0.5), _shared_mats["aged_brass"])


func _build_armillary_sphere(parent: Node3D, pos: Vector3, mat_brass: Material, mat_aged_brass: Material, mat_wood: Material) -> void:
	var arm: Node3D = Node3D.new()
	arm.name = "BrassArmillarySphere"
	arm.position = pos
	parent.add_child(arm)

	_add_cyl(arm, 0.085, 0.105, 0.022, Vector3(0.0, 0.011, 0.0), mat_wood, Vector3.ZERO, 12)
	_add_cyl(arm, 0.055, 0.078, 0.024, Vector3(0.0, 0.032, 0.0), mat_brass, Vector3.ZERO, 12)
	_add_cyl(arm, 0.018, 0.026, 0.085, Vector3(0.0, 0.082, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_sphere(arm, 0.028, 0.036, Vector3(0.0, 0.075, 0.0), mat_aged_brass, Vector3.ZERO, 10)

	var center_y: float = 0.255
	_add_torus(arm, 0.145, 0.162, Vector3(0.0, center_y, 0.0), mat_brass, Vector3(90.0, 12.0, 0.0), 18)
	_add_torus(arm, 0.148, 0.164, Vector3(0.0, center_y, 0.0), mat_aged_brass, Vector3(8.0, 0.0, -18.0), 18)
	_add_torus(arm, 0.122, 0.142, Vector3(0.0, center_y, 0.0), mat_brass, Vector3(62.0, 28.0, 15.0), 16)
	_add_torus(arm, 0.118, 0.132, Vector3(0.0, center_y, 0.0), mat_aged_brass, Vector3(90.0, -52.0, 22.0), 16)
	_add_torus(arm, 0.095, 0.108, Vector3(0.0, center_y, 0.0), mat_brass, Vector3(35.0, 45.0, -25.0), 14)

	_add_sphere(arm, 0.074, 0.148, Vector3(0.0, center_y, 0.0), _shared_mats["book_ochre"], Vector3(0.0, 0.0, -23.5), 12)
	_add_torus(arm, 0.072, 0.078, Vector3(0.0, center_y, 0.0), mat_brass, Vector3(0.0, 0.0, -23.5), 14)
	_add_cyl(arm, 0.005, 0.005, 0.36, Vector3(0.0, center_y, 0.0), mat_brass, Vector3(0.0, 0.0, -23.5), 8)
	_add_sphere(arm, 0.014, 0.028, Vector3(0.068, center_y + 0.165, 0.0), mat_brass, Vector3.ZERO, 8)


func _build_marble_portrait_bust(parent: Node3D, pos: Vector3, mat_marble: Material) -> void:
	var bust: Node3D = Node3D.new()
	bust.name = "ClassicalMarbleBust"
	bust.position = pos
	bust.rotation_degrees = Vector3(0.0, -12.0, 0.0)
	parent.add_child(bust)

	_add_box(bust, Vector3(0.12, 0.024, 0.11), Vector3(0.0, 0.012, 0.0), mat_marble)
	_add_cyl(bust, 0.042, 0.056, 0.036, Vector3(0.0, 0.042, 0.0), mat_marble, Vector3.ZERO, 12)
	_add_torus(bust, 0.036, 0.048, Vector3(0.0, 0.060, 0.0), mat_marble, Vector3.ZERO, 12)

	_add_sphere(bust, 0.115, 0.125, Vector3(0.0, 0.118, 0.0), mat_marble, Vector3(0.0, 0.0, 90.0), 12)
	_add_box(bust, Vector3(0.18, 0.095, 0.095), Vector3(0.0, 0.115, 0.0), mat_marble)
	_add_torus(bust, 0.065, 0.082, Vector3(0.01, 0.125, 0.025), mat_marble, Vector3(55.0, -18.0, 20.0), 12)
	_add_torus(bust, 0.052, 0.068, Vector3(-0.01, 0.142, 0.028), mat_marble, Vector3(62.0, 15.0, -15.0), 12)

	_add_cyl(bust, 0.034, 0.038, 0.065, Vector3(0.0, 0.185, 0.0), mat_marble, Vector3(4.0, 0.0, 0.0), 10)
	_add_sphere(bust, 0.064, 0.148, Vector3(0.0, 0.258, 0.008), mat_marble, Vector3(6.0, -6.0, 0.0), 12)
	_add_box(bust, Vector3(0.062, 0.016, 0.026), Vector3(0.0, 0.278, 0.056), mat_marble, Vector3(0.0, -6.0, 0.0))
	_add_box(bust, Vector3(0.016, 0.042, 0.028), Vector3(-0.003, 0.256, 0.064), mat_marble, Vector3(-12.0, -6.0, 0.0))
	_add_sphere(bust, 0.026, 0.038, Vector3(-0.002, 0.214, 0.048), mat_marble, Vector3.ZERO, 8)

	var curl_offsets: Array[Vector3] = [
		Vector3(0.0, 0.322, 0.018), Vector3(-0.038, 0.312, 0.024), Vector3(0.038, 0.312, 0.024),
		Vector3(-0.056, 0.285, 0.012), Vector3(0.056, 0.285, 0.012), Vector3(0.0, 0.326, -0.022),
		Vector3(-0.048, 0.296, -0.025), Vector3(0.048, 0.296, -0.025)
	]
	for c_off: Vector3 in curl_offsets:
		_add_sphere(bust, 0.024, 0.044, c_off, mat_marble, Vector3.ZERO, 8)


func _build_vintage_shelf_clock(parent: Node3D, pos: Vector3, mat_brass: Material, mat_aged_brass: Material, mat_dial: Material, mat_dark: Material) -> void:
	var clk: Node3D = Node3D.new()
	clk.name = "VintageShelfClock"
	clk.position = pos
	parent.add_child(clk)

	_add_box(clk, Vector3(0.16, 0.026, 0.09), Vector3(0.0, 0.013, 0.0), mat_aged_brass)
	_add_cyl(clk, 0.088, 0.088, 0.075, Vector3(0.0, 0.105, 0.0), mat_aged_brass, Vector3(90.0, 0.0, 0.0), 16)
	_add_torus(clk, 0.078, 0.092, Vector3(0.0, 0.105, 0.038), mat_brass, Vector3(90.0, 0.0, 0.0), 16)
	_add_cyl(clk, 0.076, 0.076, 0.010, Vector3(0.0, 0.105, 0.036), mat_dial, Vector3(90.0, 0.0, 0.0), 16)
	_add_sphere(clk, 0.008, 0.012, Vector3(0.0, 0.105, 0.044), mat_dark, Vector3.ZERO, 8)
	_add_box(clk, Vector3(0.006, 0.048, 0.006), Vector3(-0.012, 0.122, 0.044), mat_dark, Vector3(0.0, 0.0, 28.0))
	_add_box(clk, Vector3(0.005, 0.062, 0.006), Vector3(0.018, 0.118, 0.044), mat_dark, Vector3(0.0, 0.0, -48.0))
	_add_cyl(clk, 0.016, 0.024, 0.028, Vector3(0.0, 0.202, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_torus(clk, 0.022, 0.030, Vector3(0.0, 0.228, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 12)


func _build_trailing_ivy_vine(parent: Node3D, top_pos: Vector3, length: float, side_dir: float) -> void:
	var vine: Node3D = Node3D.new()
	vine.position = top_pos
	parent.add_child(vine)

	var leaf_mats: Array[Material] = [
		_shared_mats["leaf_dark"],
		_shared_mats["leaf_mid"],
		_shared_mats["leaf_bright"]
	]

	for c_i: int in range(7):
		var ang: float = float(c_i) * 0.89
		var lx: float = cos(ang) * 0.052
		var ly: float = sin(ang * 1.7) * 0.032 + 0.02
		var lz: float = sin(ang) * 0.032
		var l_mat: Material = leaf_mats[c_i % leaf_mats.size()]
		_add_sphere(vine, 0.032, 0.014, Vector3(lx, ly, lz), l_mat, Vector3(25.0, ang * 40.0, side_dir * 18.0), 8)

	for s_idx: int in range(3):
		var s_x_off: float = (float(s_idx) - 1.0) * 0.048
		var s_len: float = length * (1.0 - float(s_idx) * 0.18)
		var leaf_count: int = 6 - s_idx
		for l_idx: int in range(leaf_count):
			var t: float = float(l_idx) / float(maxi(leaf_count - 1, 1))
			var vy: float = -t * s_len
			var vx: float = s_x_off + sin(t * 5.2 + float(s_idx)) * 0.028
			var vz: float = 0.015 + cos(t * 4.0) * 0.014
			var r_leaf: float = lerpf(0.030, 0.018, t)
			var mat_l: Material = leaf_mats[(l_idx + s_idx) % leaf_mats.size()]
			var tilt_x: float = 35.0 + float((l_idx * 13) % 25)
			var tilt_z: float = float((l_idx % 2) * 2 - 1) * 28.0
			_add_sphere(vine, r_leaf, 0.010, Vector3(vx, vy, vz), mat_l, Vector3(tilt_x, 0.0, tilt_z), 8)


# ============================================================================
# 4. LEFT ARCHED TWILIGHT WINDOW, SIDE TABLE, BRASS LAMP & LEATHER CLUB CHAIR
# ============================================================================

func _build_left_window_and_lounge(parent: Node3D) -> void:
	var left_area: Node3D = Node3D.new()
	left_area.name = "LeftLoungeArea3D"
	parent.add_child(left_area)

	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_mid: Material = _shared_mats["walnut_mid"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged_brass: Material = _shared_mats["aged_brass"]

	var win_root: Node3D = Node3D.new()
	win_root.name = "LeftArchedWindow"
	win_root.position = Vector3(-1.32, 0.96, -1.88)
	win_root.rotation_degrees = Vector3(0.0, 28.0, 0.0)
	left_area.add_child(win_root)

	_add_box(win_root, Vector3(0.84, 0.56, 0.02), Vector3(0.0, 0.48, -0.18), _shared_mats["sky_top"])
	_add_box(win_root, Vector3(0.84, 0.52, 0.02), Vector3(0.0, -0.02, -0.18), _shared_mats["sky_mid"])
	_add_box(win_root, Vector3(0.84, 0.52, 0.02), Vector3(0.0, -0.50, -0.18), _shared_mats["sky_horizon"])

	var mat_stone: Material = _shared_mats["city_stone"]
	var mat_win_glow: Material = _shared_mats["window_glow"]
	_add_box(win_root, Vector3(0.24, 0.65, 0.08), Vector3(-0.18, -0.32, -0.12), mat_stone)
	_add_sphere(win_root, 0.11, 0.18, Vector3(-0.18, 0.04, -0.12), mat_stone, Vector3.ZERO, 10)
	_add_cyl(win_root, 0.008, 0.018, 0.09, Vector3(-0.18, 0.16, -0.12), mat_stone, Vector3.ZERO, 8)
	_add_box(win_root, Vector3(0.28, 0.72, 0.09), Vector3(0.14, -0.28, -0.11), mat_stone)
	_add_sphere(win_root, 0.12, 0.16, Vector3(0.14, 0.12, -0.11), mat_stone, Vector3.ZERO, 10)
	_add_cyl(win_root, 0.045, 0.032, 0.08, Vector3(-0.04, 0.44, -0.08), mat_stone, Vector3.ZERO, 8)
	_add_sphere(win_root, 0.048, 0.065, Vector3(-0.04, 0.49, -0.08), mat_stone, Vector3.ZERO, 8)
	_add_sphere(win_root, 0.024, 0.036, Vector3(-0.04, 0.43, -0.07), mat_win_glow, Vector3.ZERO, 8)

	for wy_idx: int in range(5):
		var wy: float = -0.52 + float(wy_idx) * 0.115
		for wx_pos: float in [-0.24, -0.14, 0.04, 0.14, 0.23]:
			_add_box(win_root, Vector3(0.034, 0.056, 0.015), Vector3(wx_pos, wy, -0.062), mat_win_glow)

	_add_box(win_root, Vector3(0.065, 1.32, 0.12), Vector3(-0.39, -0.12, 0.0), mat_walnut_dark)
	_add_box(win_root, Vector3(0.065, 1.32, 0.12), Vector3(0.39, -0.12, 0.0), mat_walnut_dark)
	_add_box(win_root, Vector3(0.84, 0.07, 0.14), Vector3(0.0, -0.76, 0.01), mat_walnut_pol)
	for a_i: int in range(7):
		var at: float = float(a_i) / 6.0
		var aang: float = lerpf(-1.45, 1.45, at)
		var ax: float = sin(aang) * 0.39
		var ay: float = 0.42 + cos(aang) * 0.36
		_add_box(win_root, Vector3(0.16, 0.065, 0.12), Vector3(ax, ay, 0.0), mat_walnut_dark, Vector3(0.0, 0.0, -rad_to_deg(aang)))

	for mx: float in [-0.19, 0.0, 0.19]:
		_add_box(win_root, Vector3(0.020, 1.24, 0.035), Vector3(mx, -0.10, 0.02), mat_walnut_dark)
	for my: float in [-0.52, -0.26, 0.0, 0.26, 0.44]:
		_add_box(win_root, Vector3(0.76, 0.020, 0.035), Vector3(0.0, my, 0.02), mat_walnut_dark)

	_build_potted_broadleaf_plant(left_area, Vector3(-1.14, 0.18, -1.56), 0.85, false)

	# Left Round Carved Walnut Side Table & Glowing Brass Table Lamp
	var side_tbl_l: Node3D = Node3D.new()
	side_tbl_l.name = "LeftSideTable"
	side_tbl_l.position = Vector3(-0.88, 0.0, -1.42)
	left_area.add_child(side_tbl_l)

	_add_cyl(side_tbl_l, 0.34, 0.34, 0.028, Vector3(0.0, 0.126, 0.0), mat_walnut_pol, Vector3.ZERO, 18)
	_add_torus(side_tbl_l, 0.32, 0.348, Vector3(0.0, 0.128, 0.0), mat_walnut_mid, Vector3.ZERO, 18)
	_add_cyl(side_tbl_l, 0.30, 0.30, 0.095, Vector3(0.0, 0.065, 0.0), mat_walnut_dark, Vector3.ZERO, 16)
	_add_torus(side_tbl_l, 0.285, 0.312, Vector3(0.0, 0.020, 0.0), mat_walnut_mid, Vector3.ZERO, 16)
	for l_ang: float in [-0.7, 0.0, 0.7]:
		var lx: float = sin(l_ang) * 0.22
		var lz: float = cos(l_ang) * 0.22
		_add_cyl(side_tbl_l, 0.036, 0.026, 0.42, Vector3(lx, -0.20, lz), mat_walnut_mid, Vector3.ZERO, 10)
		_add_sphere(side_tbl_l, 0.046, 0.062, Vector3(lx, -0.06, lz), mat_walnut_pol, Vector3.ZERO, 8)

	var lamp_l: Node3D = Node3D.new()
	lamp_l.name = "LeftBrassTableLamp"
	lamp_l.position = Vector3(0.02, 0.14, 0.02)
	side_tbl_l.add_child(lamp_l)

	_add_cyl(lamp_l, 0.092, 0.112, 0.022, Vector3(0.0, 0.011, 0.0), mat_aged_brass, Vector3.ZERO, 14)
	_add_cyl(lamp_l, 0.068, 0.088, 0.024, Vector3(0.0, 0.032, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_torus(lamp_l, 0.048, 0.066, Vector3(0.0, 0.052, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_sphere(lamp_l, 0.082, 0.125, Vector3(0.0, 0.118, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_torus(lamp_l, 0.055, 0.078, Vector3(0.0, 0.122, 0.0), mat_aged_brass, Vector3.ZERO, 14)
	_add_cyl(lamp_l, 0.028, 0.046, 0.085, Vector3(0.0, 0.202, 0.0), mat_brass, Vector3.ZERO, 12)
	_add_sphere(lamp_l, 0.036, 0.042, Vector3(0.0, 0.248, 0.0), mat_brass, Vector3.ZERO, 10)

	var shade_y: float = 0.345
	_add_cyl(lamp_l, 0.115, 0.225, 0.21, Vector3(0.0, shade_y, 0.0), _shared_mats["lampshade_glow"], Vector3.ZERO, 18)
	_add_torus(lamp_l, 0.108, 0.120, Vector3(0.0, shade_y + 0.105, 0.0), mat_brass, Vector3.ZERO, 16)
	_add_torus(lamp_l, 0.218, 0.230, Vector3(0.0, shade_y - 0.105, 0.0), mat_brass, Vector3.ZERO, 18)
	_add_cyl(lamp_l, 0.008, 0.018, 0.036, Vector3(0.0, shade_y + 0.126, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_sphere(lamp_l, 0.014, 0.024, Vector3(0.0, shade_y + 0.148, 0.0), mat_brass, Vector3.ZERO, 8)

	# Foreground-Left Rolled-Arm Dark Green Leather Club Armchair
	var club_chair: Node3D = Node3D.new()
	club_chair.name = "LeftLeatherClubChair"
	club_chair.position = Vector3(-1.08, 0.0, -0.96)
	club_chair.rotation_degrees = Vector3(0.0, 26.0, 0.0)
	left_area.add_child(club_chair)

	var mat_leather: Material = _shared_mats["leather_green"]
	var mat_leather_dark: Material = _shared_mats["leather_green_dark"]
	_add_cyl(club_chair, 0.13, 0.13, 0.46, Vector3(0.0, 0.24, 0.0), mat_leather, Vector3(90.0, 0.0, 0.0), 14)
	_add_sphere(club_chair, 0.135, 0.26, Vector3(0.0, 0.24, 0.22), mat_leather_dark, Vector3(90.0, 0.0, 0.0), 12)
	_add_torus(club_chair, 0.085, 0.132, Vector3(0.0, 0.24, 0.23), mat_leather, Vector3(90.0, 0.0, 0.0), 14)
	for n_i: int in range(8):
		var nang: float = float(n_i) * 0.785
		var nr: float = 0.095
		_add_sphere(club_chair, 0.007, 0.010, Vector3(cos(nang) * nr, 0.24 + sin(nang) * nr, 0.265), mat_brass, Vector3.ZERO, 8)
	_add_box(club_chair, Vector3(0.38, 0.18, 0.48), Vector3(0.04, 0.04, 0.04), mat_leather_dark)
	_add_sphere(club_chair, 0.18, 0.16, Vector3(0.06, 0.08, 0.22), mat_leather, Vector3.ZERO, 10)

	# Bake the entire Left Lounge Area (window, skyline, side table, lamp, club chair) into 1 MeshInstance3D!
	_bake_static_branch_to_merged_mesh(left_area, "BakedLeftLoungeMesh")


# ============================================================================
# 5. RIGHT CRIMSON VELVET CURTAIN, SIDE TABLE, STEAMING TEACUP, BOOKS & PLANT
# ============================================================================

func _build_right_curtain_and_side_table(parent: Node3D) -> void:
	var right_area: Node3D = Node3D.new()
	right_area.name = "RightLoungeArea3D"
	parent.add_child(right_area)

	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_mid: Material = _shared_mats["walnut_mid"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_velvet: Material = _shared_mats["velvet_curtain"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged_brass: Material = _shared_mats["aged_brass"]
	var mat_porcelain: Material = _shared_mats["porcelain"]

	var curtain: Node3D = Node3D.new()
	curtain.name = "RightCrimsonCurtain"
	curtain.position = Vector3(1.20, 1.05, -1.78)
	curtain.rotation_degrees = Vector3(0.0, -24.0, 5.5)
	right_area.add_child(curtain)

	for f_idx: int in range(6):
		var fx: float = float(f_idx) * 0.052 - 0.12
		var fz: float = sin(float(f_idx) * 1.4) * 0.025
		var fr: float = 0.042 + float(f_idx % 2) * 0.008
		_add_cyl(curtain, fr * 0.85, fr * 1.15, 1.75, Vector3(fx, 0.0, fz), mat_velvet, Vector3(0.0, 0.0, float(f_idx - 2) * 1.8), 10)
	_add_torus(curtain, 0.11, 0.135, Vector3(0.02, -0.38, 0.02), mat_brass, Vector3(12.0, 0.0, -15.0), 12)

	var side_tbl_r: Node3D = Node3D.new()
	side_tbl_r.name = "RightSideTable"
	side_tbl_r.position = Vector3(0.88, 0.0, -1.32)
	right_area.add_child(side_tbl_r)

	_add_cyl(side_tbl_r, 0.35, 0.35, 0.028, Vector3(0.0, 0.086, 0.0), mat_walnut_pol, Vector3.ZERO, 18)
	_add_torus(side_tbl_r, 0.33, 0.358, Vector3(0.0, 0.088, 0.0), mat_walnut_mid, Vector3.ZERO, 18)
	_add_cyl(side_tbl_r, 0.31, 0.31, 0.11, Vector3(0.0, 0.018, 0.0), mat_walnut_dark, Vector3.ZERO, 16)
	_add_torus(side_tbl_r, 0.295, 0.322, Vector3(0.0, -0.035, 0.0), mat_walnut_mid, Vector3.ZERO, 16)
	for p_ang_deg: float in [-55.0, -18.0, 18.0]:
		var pang: float = deg_to_rad(p_ang_deg)
		var px: float = sin(pang) * 0.312
		var pz: float = cos(pang) * 0.312
		_add_box(side_tbl_r, Vector3(0.12, 0.075, 0.016), Vector3(px, 0.018, pz), mat_walnut_mid, Vector3(0.0, p_ang_deg, 0.0))
		_add_sphere(side_tbl_r, 0.018, 0.018, Vector3(px * 1.02, 0.018, pz * 1.02), mat_aged_brass, Vector3.ZERO, 8)

	var teacup_grp: Node3D = Node3D.new()
	teacup_grp.name = "RightSteamingTeacup"
	teacup_grp.position = Vector3(-0.12, 0.10, 0.06)
	side_tbl_r.add_child(teacup_grp)

	_add_cyl(teacup_grp, 0.072, 0.044, 0.012, Vector3(0.0, 0.006, 0.0), mat_porcelain, Vector3.ZERO, 14)
	_add_torus(teacup_grp, 0.066, 0.074, Vector3(0.0, 0.012, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_cyl(teacup_grp, 0.050, 0.032, 0.064, Vector3(0.0, 0.042, 0.0), mat_porcelain, Vector3.ZERO, 14)
	_add_cyl(teacup_grp, 0.047, 0.042, 0.018, Vector3(0.0, 0.054, 0.0), mat_aged_brass, Vector3.ZERO, 14)
	_add_torus(teacup_grp, 0.046, 0.052, Vector3(0.0, 0.074, 0.0), mat_brass, Vector3.ZERO, 14)
	_add_torus(teacup_grp, 0.014, 0.022, Vector3(0.052, 0.046, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 10)
	_add_cyl(teacup_grp, 0.045, 0.045, 0.004, Vector3(0.0, 0.068, 0.0), _shared_mats["coffee"], Vector3.ZERO, 12)

	_build_horizontal_book(side_tbl_r, Vector3(0.09, 0.122, 0.08), Vector3(0.24, 0.044, 0.17), _shared_mats["book_green"], -16.0)
	_build_horizontal_book(side_tbl_r, Vector3(0.09, 0.164, 0.08), Vector3(0.22, 0.040, 0.16), _shared_mats["book_brown"], -10.0)
	_build_potted_broadleaf_plant(side_tbl_r, Vector3(0.14, 0.10, -0.10), 1.0, true)

	# Bake all static meshes of RightLoungeArea3D into 1 MeshInstance3D BEFORE adding dynamic steam wisps!
	_bake_static_branch_to_merged_mesh(right_area, "BakedRightLoungeMesh")

	# Add 4 lightweight animated rising 3D steam wisps above the teacup (marked skip_bake)
	var steam_root: Node3D = Node3D.new()
	steam_root.name = "TeacupSteamRoot"
	steam_root.position = Vector3(0.76, 0.10, -1.26)
	right_area.add_child(steam_root)

	var mat_steam: Material = _shared_mats["steam"]
	for s_i: int in range(4):
		var phase: float = float(s_i) / 4.0
		var base_pos: Vector3 = Vector3((float(s_i % 2) - 0.5) * 0.012, 0.088 + float(s_i) * 0.016, 0.0)
		var wisp: MeshInstance3D = _add_sphere(steam_root, 0.018, 0.042, base_pos, mat_steam, Vector3.ZERO, 8)
		wisp.set_meta("skip_bake", true)
		_steam_wisps.append(wisp)
		_steam_base_positions.append(base_pos)
		_steam_phases.append(phase)


func _build_potted_broadleaf_plant(parent: Node3D, pos: Vector3, scale_f: float, include_pot: bool) -> void:
	var plant: Node3D = Node3D.new()
	plant.position = pos
	plant.scale = Vector3.ONE * scale_f
	parent.add_child(plant)

	var base_y: float = 0.0
	if include_pot:
		_add_cyl(plant, 0.092, 0.068, 0.15, Vector3(0.0, 0.075, 0.0), _shared_mats["aged_brass"], Vector3.ZERO, 12)
		_add_torus(plant, 0.084, 0.096, Vector3(0.0, 0.15, 0.0), _shared_mats["brass"], Vector3.ZERO, 12)
		_add_cyl(plant, 0.084, 0.084, 0.012, Vector3(0.0, 0.145, 0.0), _shared_mats["walnut_dark"], Vector3.ZERO, 10)
		base_y = 0.15

	var leaf_mats: Array[Material] = [
		_shared_mats["leaf_dark"],
		_shared_mats["leaf_mid"],
		_shared_mats["leaf_bright"]
	]

	var leaf_specs: Array[Dictionary] = [
		{"pos": Vector3(-0.08, 0.12, 0.04), "rot": Vector3(28.0, 35.0, 42.0), "r": 0.065},
		{"pos": Vector3(0.08, 0.14, 0.05), "rot": Vector3(32.0, -30.0, -38.0), "r": 0.068},
		{"pos": Vector3(0.0, 0.18, 0.08), "rot": Vector3(42.0, 0.0, 8.0), "r": 0.072},
		{"pos": Vector3(-0.11, 0.22, -0.02), "rot": Vector3(18.0, 55.0, 48.0), "r": 0.074},
		{"pos": Vector3(0.10, 0.24, -0.01), "rot": Vector3(20.0, -48.0, -42.0), "r": 0.070},
		{"pos": Vector3(-0.04, 0.28, 0.04), "rot": Vector3(25.0, 18.0, 22.0), "r": 0.075},
		{"pos": Vector3(0.05, 0.30, 0.03), "rot": Vector3(22.0, -15.0, -24.0), "r": 0.072},
		{"pos": Vector3(0.0, 0.35, -0.02), "rot": Vector3(12.0, 5.0, 4.0), "r": 0.068}
	]

	for i: int in range(leaf_specs.size()):
		var spec: Dictionary = leaf_specs[i]
		var l_pos: Vector3 = (spec["pos"] as Vector3) + Vector3(0.0, base_y, 0.0)
		var l_rot: Vector3 = spec["rot"] as Vector3
		var l_r: float = float(spec["r"])
		var l_mat: Material = leaf_mats[i % leaf_mats.size()]
		_add_cyl(plant, 0.004, 0.006, l_pos.y - base_y, Vector3(l_pos.x * 0.45, base_y + (l_pos.y - base_y) * 0.5, l_pos.z * 0.45), _shared_mats["leaf_dark"], l_rot * 0.35, 6)
		var leaf_mi: MeshInstance3D = _add_sphere(plant, l_r, 0.014, l_pos, l_mat, l_rot, 8)
		leaf_mi.scale = Vector3(0.72, 1.0, 1.35)
