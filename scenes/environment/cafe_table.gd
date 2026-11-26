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

const ZOOM_DEFAULT: float = 2.92
const ZOOM_MIN: float = 1.95
const ZOOM_MAX: float = 4.50

const YAW_DEFAULT: float = 0.0
const YAW_MIN: float = -0.50
const YAW_MAX: float = 0.50

const PITCH_LOUNGE_REF: float = -0.34 # Wide establishing cafe lounge horizon angle (-19.5 deg)
const PITCH_DEFAULT: float = -1.14    # -65.3 degrees (Steep playable tabletop angle nearer 90 deg)
const PITCH_MIN: float = -1.420       # -81.4 degrees (Near top-down 3D board inspection angle)
const PITCH_MAX: float = -0.280       # -16.0 degrees (Panoramic lounge view)

# Cinematic Match Opening Approach (starts wide in the warm cafe parlor, then glides slowly into the desk)
const INTRO_START_DISTANCE: float = 3.85
const INTRO_START_PITCH: float = -0.34
const INTRO_START_YAW: float = 0.065
const INTRO_GLIDE_DURATION: float = 1.85

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
var _intro_glide_pending: bool = false
var _intro_glide_active: bool = false
var _intro_glide_played_for_board: bool = false
var _intro_glide_elapsed: float = 0.0
var _intro_start_pitch: float = INTRO_START_PITCH
var _intro_start_distance: float = INTRO_START_DISTANCE
var _intro_start_yaw: float = INTRO_START_YAW

func _kill_camera_tween() -> void:
	if _camera_tween and is_instance_valid(_camera_tween):
		_camera_tween.kill()
		_camera_tween = null
	_intro_glide_active = false

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
var _board_node_added_connected: bool = false
var _baked_bucket_mats: Dictionary = {}
var _window_vista_mat: StandardMaterial3D = null
var _last_window_view_idx: int = -1
var _carpet_mat: StandardMaterial3D = null
var _last_carpet_idx: int = -1
var _chair_style_meshes: Dictionary = {} # int style_idx -> ArrayMesh
var _last_chair_style_idx: int = -1

# Interactive Cafe Environment Props (Zero-Physics Ray-Sphere Picking + Tweens)
var _interactive_props: Array[Dictionary] = []
var _prop_tweens: Dictionary = {}
var _last_prop_interact_ms: int = 0
var _desk_lamp_shade_mat: StandardMaterial3D = null
var _left_lamp_shade_mat: StandardMaterial3D = null
var _right_lantern_glow_mat: StandardMaterial3D = null
var _desk_lamp_on: bool = true
var _left_lamp_on: bool = true
var _right_lantern_on: bool = true
var _window_door_left: Node3D = null
var _window_door_right: Node3D = null
var _window_doors_open: bool = false
var _khatam_lid_pivot: Node3D = null
var _khatam_box_open: bool = false
var _armillary_rings_pivot: Node3D = null
var _clock_hands_pivot: Node3D = null
var _samovar_teapot_pivot: Node3D = null
var _hero_book_pivot: Node3D = null
var _hero_book_pulled: bool = false

const WINDOW_VIEW_TEXTURES: Array[String] = [
	"persian_window_view.jpg",
	"persian_window_rain.jpg",
	"persian_window_garden.jpg",
	"persian_window_snow.jpg",
	"persian_window_sunset.jpg"
]

const CARPET_TEXTURES: Array[String] = [
	"persian_carpet.jpg",
	"persian_carpet_isfahan.jpg",
	"persian_carpet_tabriz.jpg",
	"persian_carpet_shiraz.jpg",
	"persian_carpet_kerman.jpg"
]

const CHAIR_STYLE_COUNT: int = 5


func _ready() -> void:
	add_to_group("cafe_table")
	_is_mobile_gpu = GameManager.is_mobile or OS.has_feature("mobile") or (OS.get_name() in ["Android", "iOS"])
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
		# Mobile GPU Optimization: disable secondary OmniLights & real-time shadow pass;
		# rely on single DirectionalLight + warm sky ambient for full visual richness at high FPS.
		if has_node("WallFillLight"):
			var wf: OmniLight3D = get_node("WallFillLight") as OmniLight3D
			if wf:
				wf.visible = false
		if has_node("TableLampLight"):
			var tl: OmniLight3D = get_node("TableLampLight") as OmniLight3D
			if tl:
				tl.visible = false
		if _side_lamp_light and is_instance_valid(_side_lamp_light):
			_side_lamp_light.visible = false
		if has_node("SunLight"):
			var sun_mob: DirectionalLight3D = get_node("SunLight") as DirectionalLight3D
			if sun_mob:
				sun_mob.shadow_enabled = false
				sun_mob.light_energy = 0.90
				sun_mob.light_specular = 0.16
				sun_mob.light_color = Color(1.0, 0.91, 0.78)
		if env_node and env_node.environment:
			env_node.environment.ambient_light_energy = 0.88
			env_node.environment.tonemap_exposure = 0.98

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
	if not visible or not is_inside_tree():
		return
	if _mouse_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_pressed = false
		_is_dragging = false

	# Periodically sync chair count with active match players (e.g. 2, 3, or 4 players)
	_chair_poll_timer += delta
	if _chair_poll_timer >= 1.0:
		_chair_poll_timer = 0.0
		var desired_chairs: int = _get_active_player_count()
		if desired_chairs != _current_chair_count:
			update_player_chairs(desired_chairs)

	if _intro_glide_active:
		_intro_glide_elapsed += delta

	if _intro_glide_pending:
		if not _is_start_overlay_covering_screen():
			play_desk_approach_intro(INTRO_GLIDE_DURATION)
		else:
			_menu_sway_time += delta * 0.28
			current_yaw = _intro_start_yaw + sin(_menu_sway_time) * 0.014
			current_pitch = _intro_start_pitch + cos(_menu_sway_time * 0.7) * 0.006
			current_distance = _intro_start_distance
			_apply_orbit_transform()

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

	if not is_board_view_active and not is_transitioning and not _intro_glide_pending:
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
	var t_lounge: float = clampf((pitch_rad - (-0.82)) / (PITCH_LOUNGE_REF - (-0.82)), 0.0, 1.0)
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
			if _is_mobile_gpu:
				tl.visible = false
			else:
				tl.light_specular = 0.0
				tl.light_energy = 0.45 if top_down else 0.84

	if has_node("SunLight"):
		var sun: DirectionalLight3D = get_node("SunLight") as DirectionalLight3D
		if sun:
			sun.light_specular = 0.05 if top_down else (0.16 if _is_mobile_gpu else 0.20)


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

func _is_start_overlay_covering_screen() -> bool:
	var parent_node: Node = get_parent()
	if not is_instance_valid(parent_node):
		return false
	var hud: Node = parent_node.get_node_or_null("CanvasLayer/BaseGameHUD")
	if not is_instance_valid(hud):
		return false
	var overlay: Control = hud.get_node_or_null("StartGameOverlay") as Control
	return is_instance_valid(overlay) and overlay.visible


func _resolve_board_camera_framing() -> Dictionary:
	var desired_pitch: float = PITCH_DEFAULT
	var desired_dist: float = ZOOM_DEFAULT
	var has_custom_dist: bool = false

	if current_board_node and is_instance_valid(current_board_node):
		if "camera_pitch" in current_board_node:
			var bp: float = float(current_board_node.get("camera_pitch"))
			if bp >= PITCH_MIN and bp <= PITCH_MAX:
				desired_pitch = bp
		if "camera_distance" in current_board_node:
			var bd: float = float(current_board_node.get("camera_distance"))
			if bd >= ZOOM_MIN and bd <= ZOOM_MAX:
				desired_dist = bd
				has_custom_dist = true

	# Add subtle framing cushion on extra-tall portrait screens (e.g. 9:19.5) so wide boards never clip horizontally
	var vp: Viewport = get_viewport()
	if vp and not has_custom_dist:
		var vp_size: Vector2 = vp.get_visible_rect().size
		if vp_size.y > 0.0:
			var aspect: float = vp_size.x / vp_size.y
			if aspect < 0.54:
				var extra_pull: float = clampf((0.54 - aspect) * 1.45, 0.0, 0.20)
				desired_dist += extra_pull

	desired_pitch = clampf(desired_pitch, _get_effective_pitch_min(), PITCH_MAX)
	desired_dist = clampf(desired_dist, ZOOM_MIN, ZOOM_MAX)
	return {"pitch": desired_pitch, "distance": desired_dist}


func _should_start_in_top_down_view() -> bool:
	if current_board_node and is_instance_valid(current_board_node):
		if "start_in_2d_view" in current_board_node:
			return bool(current_board_node.get("start_in_2d_view"))
	return false


func _resolve_top_down_height() -> float:
	var desired_h: float = TOP_DOWN_HEIGHT_DEFAULT
	if current_board_node and is_instance_valid(current_board_node):
		if "top_down_camera_height" in current_board_node:
			var bh: float = float(current_board_node.get("top_down_camera_height"))
			if bh >= TOP_DOWN_HEIGHT_MIN and bh <= TOP_DOWN_HEIGHT_MAX:
				desired_h = bh

	# Scale height proportionally on narrower portrait screens (aspect < 9:16) so wide boards stay fully visible
	var vp: Viewport = get_viewport()
	if vp:
		var vp_size: Vector2 = vp.get_visible_rect().size
		if vp_size.y > 0.0:
			var aspect: float = vp_size.x / vp_size.y
			if aspect < 0.5625:
				desired_h *= 0.5625 / maxf(aspect, 0.42)

	return clampf(desired_h, TOP_DOWN_HEIGHT_MIN, TOP_DOWN_HEIGHT_MAX)


func _apply_intro_glide_progress(t: float) -> void:
	# Smooth curved spherical dolly-in & downward tilt from the wide cafe parlor toward the gaming desk
	var s_pos: float = clampf(t, 0.0, 1.0)
	# Pitch tilts gently a touch later so you first glide closer across the warm lounge before settling onto the board
	var s_pitch: float = clampf(pow(s_pos, 0.92), 0.0, 1.0)
	current_distance = lerpf(_intro_start_distance, target_distance, s_pos)
	current_pitch = lerpf(_intro_start_pitch, target_pitch, s_pitch)
	current_yaw = lerpf(_intro_start_yaw, target_yaw, s_pos)
	_apply_orbit_transform()


func _cancel_intro_glide_for_user_input() -> void:
	if not _intro_glide_active:
		return
	_kill_camera_tween()
	is_transitioning = false
	is_board_view_active = true
	_intro_glide_pending = false
	target_distance = current_distance
	target_pitch = current_pitch
	target_yaw = current_yaw


func transition_to_menu_view(duration: float = 1.0) -> void:
	_kill_camera_tween()
	_intro_glide_pending = false
	_intro_glide_played_for_board = false
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


func transition_to_board_view(duration: float = INTRO_GLIDE_DURATION) -> void:
	_kill_camera_tween()
	set_menu_showcase_visible(false)
	update_player_chairs(_get_active_player_count())

	var framing: Dictionary = _resolve_board_camera_framing()
	target_pitch = float(framing["pitch"])
	target_distance = float(framing["distance"])
	target_yaw = YAW_DEFAULT

	var resolved_2d_h: float = _resolve_top_down_height()
	top_down_target_height = resolved_2d_h
	top_down_current_height = resolved_2d_h

	if _should_start_in_top_down_view():
		is_top_down_view = true
		_sync_2d_3d_visibility_and_lighting(true)
		if _lounge_backdrop_root and is_instance_valid(_lounge_backdrop_root):
			_lounge_backdrop_root.visible = true
		camera_mode_changed.emit(true)

		current_distance = target_distance
		current_pitch = target_pitch
		current_yaw = target_yaw
		camera.position = Vector3(TARGET_FOCUS.x, TARGET_FOCUS.y + top_down_current_height, TARGET_FOCUS.z)
		camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

		_intro_glide_pending = false
		_intro_glide_played_for_board = true
		_intro_glide_active = false
		is_board_view_active = true
		is_transitioning = false
		return

	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	camera_mode_changed.emit(is_top_down_view)

	# Establish the wide warm Cafe Parlor pose first so the camera always smoothly closes in toward the desk
	_intro_start_distance = maxf(INTRO_START_DISTANCE, target_distance + 0.72)
	_intro_start_pitch = INTRO_START_PITCH
	_intro_start_yaw = INTRO_START_YAW
	current_distance = _intro_start_distance
	current_pitch = _intro_start_pitch
	current_yaw = _intro_start_yaw
	_apply_orbit_transform()

	_intro_glide_played_for_board = false
	if _is_start_overlay_covering_screen():
		# Hold the atmospheric wide parlor shot behind the countdown dialog, then glide smoothly in when it reveals!
		_intro_glide_pending = true
		is_board_view_active = false
		is_transitioning = false
	else:
		_intro_glide_pending = false
		play_desk_approach_intro(duration)


func play_desk_approach_intro(duration: float = INTRO_GLIDE_DURATION) -> void:
	if _intro_glide_played_for_board and not _intro_glide_pending:
		return
	if is_top_down_view:
		_intro_glide_pending = false
		_intro_glide_played_for_board = true
		return

	_kill_camera_tween()
	_intro_glide_pending = false
	_intro_glide_played_for_board = true
	_intro_glide_active = true
	_intro_glide_elapsed = 0.0
	is_transitioning = true
	is_board_view_active = false

	# Capture current wide parlor pose as start; destination stays live on target_* so board overrides land seamlessly
	_intro_start_distance = current_distance
	_intro_start_pitch = current_pitch
	_intro_start_yaw = current_yaw

	var glide_dur: float = clampf(duration, 0.9, 2.6)
	_camera_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(_apply_intro_glide_progress, 0.0, 1.0, glide_dur)
	_camera_tween.tween_callback(func() -> void:
		current_distance = target_distance
		current_pitch = target_pitch
		current_yaw = target_yaw
		_apply_orbit_transform()
		_intro_glide_active = false
		is_board_view_active = true
		is_transitioning = false
		_camera_tween = null
	)


# --- Board Spawning & Lifecycle ---

func spawn_board(board_packed_scene: PackedScene) -> Node3D:
	clear_board()
	randomize_window_view()
	randomize_carpet()
	randomize_chair_style()
	set_menu_showcase_visible(false)
	is_top_down_view = false
	_sync_2d_3d_visibility_and_lighting(false)
	camera_mode_changed.emit(false)
	if board_packed_scene:
		current_board_node = board_packed_scene.instantiate() as Node3D
		board_container.add_child(current_board_node)
		if _is_mobile_gpu:
			_optimize_board_for_mobile(current_board_node)
			call_deferred("_optimize_board_for_mobile", current_board_node)
			_set_mobile_board_watcher_active(true)
		var g_type: String = ""
		if "game_type" in current_board_node:
			g_type = str(current_board_node.get("game_type"))
		if g_type == "":
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm and "current_game_type" in gm:
				g_type = str(gm.get("current_game_type"))
		populate_props_for_game(g_type)
		update_player_chairs(_get_active_player_count())
		transition_to_board_view(INTRO_GLIDE_DURATION)
	return current_board_node


func clear_board() -> void:
	_kill_camera_tween()
	_intro_glide_pending = false
	_intro_glide_played_for_board = false
	_set_mobile_board_watcher_active(false)
	if current_board_node and is_instance_valid(current_board_node):
		if current_board_node.has_method("_disconnect_network_signals"):
			current_board_node.call("_disconnect_network_signals")
		if current_board_node.has_method("cleanup_board"):
			current_board_node.call("cleanup_board")
		if current_board_node.get_parent():
			current_board_node.get_parent().remove_child(current_board_node)
		current_board_node.queue_free()
		current_board_node = null


func _exit_tree() -> void:
	_set_mobile_board_watcher_active(false)


func reset_table_state() -> void:
	_kill_camera_tween()
	_intro_glide_pending = false
	_intro_glide_played_for_board = false
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
	_intro_glide_pending = false
	_intro_glide_played_for_board = true
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
		var look_dir: Vector3 = focus - end_pos
		if look_dir.length_squared() > 1e-8:
			var look_basis: Basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)
			end_rot_deg = look_basis.get_euler() * (180.0 / PI)
		else:
			end_rot_deg = camera.rotation_degrees

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(camera, "position", end_pos, duration)
	_camera_tween.tween_property(camera, "rotation_degrees", end_rot_deg, duration)
	_camera_tween.chain().tween_callback(func() -> void:
		is_transitioning = false
		_camera_tween = null
		_sync_2d_3d_visibility_and_lighting(is_top_down_view)
	)


func reset_camera_orbit() -> void:
	top_down_target_height = _resolve_top_down_height()
	var framing: Dictionary = _resolve_board_camera_framing()
	target_yaw = YAW_DEFAULT
	target_pitch = float(framing["pitch"])
	target_distance = float(framing["distance"])


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
	if _intro_glide_active and _intro_glide_elapsed >= 0.25:
		if event is InputEventScreenDrag:
			var sd: InputEventScreenDrag = event as InputEventScreenDrag
			_cancel_intro_glide_for_user_input()
			_active_touches[sd.index] = sd.position
			if _active_touches.size() == 1:
				_drag_start_pos = sd.position
				_is_dragging = true
		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			_cancel_intro_glide_for_user_input()
			_mouse_pressed = true
			_mouse_start_pos = mm.position
			_is_dragging = true
		elif event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				_cancel_intro_glide_for_user_input()
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
			var was_clean_tap: bool = _mouse_pressed and not _is_dragging and event.position.distance_to(_mouse_start_pos) <= DRAG_THRESHOLD
			_mouse_pressed = false
			_is_dragging = false
			if was_clean_tap:
				_try_interact_with_cafe_prop(event.position)


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
		var was_single_tap: bool = (_active_touches.size() == 1 and not _is_dragging and event.position.distance_to(_drag_start_pos) <= DRAG_THRESHOLD)
		_active_touches.erase(event.index)
		if _active_touches.size() < 2:
			_prev_pinch_dist = -1.0
		if _active_touches.is_empty():
			_is_dragging = false
			if was_single_tap:
				_try_interact_with_cafe_prop(event.position)


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

func _set_mobile_board_watcher_active(active: bool) -> void:
	if not is_inside_tree():
		_board_node_added_connected = false
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	if active and _is_mobile_gpu:
		if not _board_node_added_connected:
			if not tree.node_added.is_connected(_on_tree_node_added):
				tree.node_added.connect(_on_tree_node_added)
			_board_node_added_connected = true
	else:
		if _board_node_added_connected or tree.node_added.is_connected(_on_tree_node_added):
			if tree.node_added.is_connected(_on_tree_node_added):
				tree.node_added.disconnect(_on_tree_node_added)
			_board_node_added_connected = false


func _on_tree_node_added(node: Node) -> void:
	if not _is_mobile_gpu or not is_instance_valid(board_container) or not is_instance_valid(current_board_node):
		return
	if not (node is GeometryInstance3D or node is Area3D):
		return
	if not board_container.is_ancestor_of(node):
		return
	_optimize_single_node_for_mobile(node)


func _optimize_single_node_for_mobile(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_meta("_mob_opt"):
		return
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null:
			call_deferred("_optimize_mesh_instance_deferred", mi)
		else:
			_optimize_primitive_mesh_for_mobile(mi.mesh)
			mi.set_meta("_mob_opt", true)
	elif node is Area3D:
		node.set_meta("_mob_opt", true)
		call_deferred("_optimize_area3d_deferred", node as Area3D)


func _optimize_mesh_instance_deferred(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi):
		return
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mi.mesh != null:
		_optimize_primitive_mesh_for_mobile(mi.mesh)
		mi.set_meta("_mob_opt", true)


func _optimize_area3d_deferred(area: Area3D) -> void:
	if not is_instance_valid(area):
		return
	# On touch mobile, disable automatic mouse-hover ray-picking on Area3Ds that don't handle input_event clicks.
	# Physics space intersect_ray() used by board _unhandled_input() is completely unaffected.
	if area.get_signal_connection_list("input_event").is_empty():
		area.input_ray_pickable = false


func _optimize_primitive_mesh_for_mobile(mesh_res: Mesh) -> void:
	if mesh_res is SphereMesh:
		var sm: SphereMesh = mesh_res as SphereMesh
		if sm.radial_segments > 14 or sm.rings > 7:
			sm.radial_segments = mini(sm.radial_segments, 12)
			sm.rings = mini(sm.rings, 6)
	elif mesh_res is CylinderMesh:
		var cm: CylinderMesh = mesh_res as CylinderMesh
		if cm.radial_segments > 16 or cm.rings > 1:
			cm.radial_segments = mini(cm.radial_segments, 14)
			cm.rings = 1
	elif mesh_res is TorusMesh:
		var tm: TorusMesh = mesh_res as TorusMesh
		if tm.rings > 18 or tm.ring_segments > 10:
			tm.rings = mini(tm.rings, 16)
			tm.ring_segments = mini(tm.ring_segments, 8)
	elif mesh_res is CapsuleMesh:
		var cap: CapsuleMesh = mesh_res as CapsuleMesh
		if cap.radial_segments > 14 or cap.rings > 4:
			cap.radial_segments = mini(cap.radial_segments, 12)
			cap.rings = mini(cap.rings, 4)


func _optimize_board_for_mobile(node: Node) -> void:
	if not _is_mobile_gpu or not is_instance_valid(node):
		return
	_optimize_single_node_for_mobile(node)
	for ch: Node in node.get_children():
		_optimize_board_for_mobile(ch)


func _collect_static_meshes_recursive(node: Node, root_ref: Node3D, out_list: Array[MeshInstance3D]) -> void:
	if node != root_ref and node.has_meta("skip_bake"):
		return
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


func _get_baked_bucket_info(mat: Material) -> Dictionary:
	if mat == null:
		return {"key": "null", "mat": null, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if not (mat is StandardMaterial3D):
		return {"key": "raw_%d" % mat.get_instance_id(), "mat": mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	var sm: StandardMaterial3D = mat as StandardMaterial3D
	if _window_vista_mat != null and sm == _window_vista_mat:
		return {"key": "window_vista", "mat": _window_vista_mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if _carpet_mat != null and sm == _carpet_mat:
		return {"key": "floor_carpet", "mat": _carpet_mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if _desk_lamp_shade_mat != null and sm == _desk_lamp_shade_mat:
		return {"key": "desk_lamp_shade", "mat": _desk_lamp_shade_mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if _left_lamp_shade_mat != null and sm == _left_lamp_shade_mat:
		return {"key": "left_lamp_shade", "mat": _left_lamp_shade_mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if _right_lantern_glow_mat != null and sm == _right_lantern_glow_mat:
		return {"key": "right_lantern_glow", "mat": _right_lantern_glow_mat, "color": Color.WHITE, "uv_scale": Vector2.ONE}
	if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return {"key": "raw_%d" % sm.get_instance_id(), "mat": sm, "color": Color.WHITE, "uv_scale": Vector2.ONE}

	if sm.albedo_texture != null and sm.emission_enabled:
		var k_tex_em: String = "vc_tex_em_%d" % sm.albedo_texture.get_instance_id()
		if not _baked_bucket_mats.has(k_tex_em):
			var bm_te: StandardMaterial3D = StandardMaterial3D.new()
			bm_te.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm_te.albedo_texture = sm.albedo_texture
			bm_te.vertex_color_use_as_albedo = true
			bm_te.vertex_color_is_srgb = true
			_baked_bucket_mats[k_tex_em] = bm_te
		return {
			"key": k_tex_em,
			"mat": _baked_bucket_mats[k_tex_em],
			"color": sm.albedo_color,
			"uv_scale": Vector2(sm.uv1_scale.x, sm.uv1_scale.y)
		}

	if sm.emission_enabled:
		var k_em: String = "vc_emissive"
		if not _baked_bucket_mats.has(k_em):
			var bm_em: StandardMaterial3D = StandardMaterial3D.new()
			bm_em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm_em.vertex_color_use_as_albedo = true
			bm_em.vertex_color_is_srgb = false
			_baked_bucket_mats[k_em] = bm_em
		var ca: Color = sm.albedo_color.srgb_to_linear()
		var ce: Color = sm.emission.srgb_to_linear()
		var em_e: float = sm.emission_energy_multiplier
		var hdr_col: Color = Color(
			ca.r * 0.42 + ce.r * em_e,
			ca.g * 0.42 + ce.g * em_e,
			ca.b * 0.42 + ce.b * em_e,
			1.0
		)
		return {"key": k_em, "mat": _baked_bucket_mats[k_em], "color": hdr_col, "uv_scale": Vector2.ONE}

	if sm.albedo_texture != null:
		var k_tex: String = "vc_tex_%d" % sm.albedo_texture.get_instance_id()
		if not _baked_bucket_mats.has(k_tex):
			var bm_tex: StandardMaterial3D = StandardMaterial3D.new()
			bm_tex.albedo_texture = sm.albedo_texture
			bm_tex.roughness = sm.roughness
			bm_tex.metallic = sm.metallic
			bm_tex.specular_mode = sm.specular_mode
			bm_tex.vertex_color_use_as_albedo = true
			bm_tex.vertex_color_is_srgb = true
			_baked_bucket_mats[k_tex] = bm_tex
		return {
			"key": k_tex,
			"mat": _baked_bucket_mats[k_tex],
			"color": sm.albedo_color,
			"uv_scale": Vector2(sm.uv1_scale.x, sm.uv1_scale.y)
		}

	if sm.metallic >= 0.5:
		var k_met: String = "vc_metal"
		if not _baked_bucket_mats.has(k_met):
			var bm_met: StandardMaterial3D = StandardMaterial3D.new()
			bm_met.roughness = 0.27
			bm_met.metallic = 0.84
			bm_met.vertex_color_use_as_albedo = true
			bm_met.vertex_color_is_srgb = true
			_baked_bucket_mats[k_met] = bm_met
		return {"key": k_met, "mat": _baked_bucket_mats[k_met], "color": sm.albedo_color, "uv_scale": Vector2.ONE}

	var k_sol: String = "vc_solid"
	if not _baked_bucket_mats.has(k_sol):
		var bm_sol: StandardMaterial3D = StandardMaterial3D.new()
		bm_sol.roughness = 0.52
		bm_sol.metallic = 0.02
		bm_sol.vertex_color_use_as_albedo = true
		bm_sol.vertex_color_is_srgb = true
		_baked_bucket_mats[k_sol] = bm_sol
	return {"key": k_sol, "mat": _baked_bucket_mats[k_sol], "color": sm.albedo_color, "uv_scale": Vector2.ONE}


func _bake_node_tree_to_array_mesh(branch_root: Node3D) -> ArrayMesh:
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_static_meshes_recursive(branch_root, branch_root, mesh_nodes)
	if mesh_nodes.is_empty():
		return null

	var buckets: Dictionary = {} # bucket_key -> {"mat": Material, "items": Array}
	var bucket_keys: Array[String] = []

	for mi: MeshInstance3D in mesh_nodes:
		var m_res: Mesh = mi.mesh
		if m_res == null or m_res.get_surface_count() == 0:
			continue
		var mat: Material = mi.material_override
		if mat == null:
			mat = m_res.surface_get_material(0)
		var b_info: Dictionary = _get_baked_bucket_info(mat)
		var b_key: String = b_info["key"] as String
		if not buckets.has(b_key):
			buckets[b_key] = {"mat": b_info["mat"], "items": []}
			bucket_keys.append(b_key)
		var rel_xf: Transform3D = _compute_relative_transform(mi, branch_root)
		var arr: Array = buckets[b_key]["items"] as Array
		arr.append({
			"mesh": m_res,
			"xform": rel_xf,
			"color": b_info["color"],
			"uv_scale": b_info["uv_scale"]
		})

	var merged: ArrayMesh = ArrayMesh.new()
	for b_key: String in bucket_keys:
		var b_data: Dictionary = buckets[b_key] as Dictionary
		var bucket_mat: Material = b_data["mat"] as Material
		var entries: Array = b_data["items"] as Array

		# Pass 1: Fetch surface arrays once and compute exact vertex/index counts for single-allocation baking
		var surf_jobs: Array = []
		var total_verts: int = 0
		var total_indices: int = 0
		for item_v: Variant in entries:
			var item: Dictionary = item_v as Dictionary
			var sub_mesh: Mesh = item["mesh"] as Mesh
			var src_arrays: Array = sub_mesh.surface_get_arrays(0)
			if src_arrays.is_empty():
				continue
			var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX]
			var v_count: int = src_verts.size()
			if v_count == 0:
				continue
			var src_idx: PackedInt32Array = src_arrays[Mesh.ARRAY_INDEX] if src_arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var i_count: int = src_idx.size() if not src_idx.is_empty() else (v_count - (v_count % 3))
			total_verts += v_count
			total_indices += i_count
			surf_jobs.append({
				"src": src_arrays,
				"verts": src_verts,
				"idx": src_idx,
				"v_count": v_count,
				"xf": item["xform"],
				"col": item["color"],
				"uv_sc": item["uv_scale"]
			})

		if total_verts == 0:
			continue

		# Pass 2: Pre-size all Packed*Arrays once and write by index
		var out_verts: PackedVector3Array = PackedVector3Array()
		var out_norms: PackedVector3Array = PackedVector3Array()
		var out_uvs: PackedVector2Array = PackedVector2Array()
		var out_colors: PackedColorArray = PackedColorArray()
		var out_indices: PackedInt32Array = PackedInt32Array()
		out_verts.resize(total_verts)
		out_norms.resize(total_verts)
		out_uvs.resize(total_verts)
		out_colors.resize(total_verts)
		out_indices.resize(total_indices)

		var v_cursor: int = 0
		var i_cursor: int = 0
		for job_v: Variant in surf_jobs:
			var job: Dictionary = job_v as Dictionary
			var src_arrays: Array = job["src"] as Array
			var src_verts: PackedVector3Array = job["verts"] as PackedVector3Array
			var src_idx: PackedInt32Array = job["idx"] as PackedInt32Array
			var v_count: int = int(job["v_count"])
			var sub_xf: Transform3D = job["xf"] as Transform3D
			var v_col: Color = job["col"] as Color
			var uv_sc: Vector2 = job["uv_sc"] as Vector2

			var has_norms: bool = src_arrays[Mesh.ARRAY_NORMAL] != null and (src_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == v_count
			var src_norms: PackedVector3Array = src_arrays[Mesh.ARRAY_NORMAL] if has_norms else PackedVector3Array()
			var has_uvs: bool = src_arrays[Mesh.ARRAY_TEX_UV] != null and (src_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == v_count
			var src_uvs: PackedVector2Array = src_arrays[Mesh.ARRAY_TEX_UV] if has_uvs else PackedVector2Array()

			var det: float = sub_xf.basis.determinant()
			var norm_basis: Basis = sub_xf.basis.inverse().transposed() if absf(det) > 1e-8 else Basis.IDENTITY
			var flip_winding: bool = det < 0.0
			var base_offset: int = v_cursor

			for vi: int in range(v_count):
				var w: int = base_offset + vi
				out_verts[w] = sub_xf * src_verts[vi]
				if has_norms:
					out_norms[w] = (norm_basis * src_norms[vi]).normalized()
				else:
					out_norms[w] = Vector3.UP
				if has_uvs:
					var uv0: Vector2 = src_uvs[vi]
					out_uvs[w] = Vector2(uv0.x * uv_sc.x, uv0.y * uv_sc.y)
				else:
					out_uvs[w] = Vector2.ZERO
				out_colors[w] = v_col
			v_cursor += v_count

			if src_idx.is_empty():
				for ti: int in range(0, v_count - 2, 3):
					out_indices[i_cursor] = base_offset + ti
					if flip_winding:
						out_indices[i_cursor + 1] = base_offset + ti + 2
						out_indices[i_cursor + 2] = base_offset + ti + 1
					else:
						out_indices[i_cursor + 1] = base_offset + ti + 1
						out_indices[i_cursor + 2] = base_offset + ti + 2
					i_cursor += 3
			else:
				var idx_count: int = src_idx.size()
				if flip_winding:
					for ti: int in range(0, idx_count - 2, 3):
						out_indices[i_cursor] = base_offset + src_idx[ti]
						out_indices[i_cursor + 1] = base_offset + src_idx[ti + 2]
						out_indices[i_cursor + 2] = base_offset + src_idx[ti + 1]
						i_cursor += 3
				else:
					for ii: int in range(idx_count):
						out_indices[i_cursor + ii] = base_offset + src_idx[ii]
					i_cursor += idx_count

		var surf_arrays: Array = []
		surf_arrays.resize(Mesh.ARRAY_MAX)
		surf_arrays[Mesh.ARRAY_VERTEX] = out_verts
		surf_arrays[Mesh.ARRAY_NORMAL] = out_norms
		surf_arrays[Mesh.ARRAY_TEX_UV] = out_uvs
		surf_arrays[Mesh.ARRAY_COLOR] = out_colors
		surf_arrays[Mesh.ARRAY_INDEX] = out_indices
		var surf_idx: int = merged.get_surface_count()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arrays)
		if bucket_mat != null:
			merged.surface_set_material(surf_idx, bucket_mat)

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


func _bake_interactive_prop_branch(prop_root: Node3D, baked_name: String) -> MeshInstance3D:
	var baked_mi: MeshInstance3D = _bake_static_branch_to_merged_mesh(prop_root, baked_name)
	prop_root.set_meta("skip_bake", true)
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


func _add_plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = size
	pm.material = mat
	mi.mesh = pm
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


func _load_cafe_tex(filename: String) -> Texture2D:
	var path: String = "res://assets/images/cafe_textures/" + filename
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func randomize_window_view() -> void:
	if _window_vista_mat == null or WINDOW_VIEW_TEXTURES.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var count: int = WINDOW_VIEW_TEXTURES.size()
	var idx: int = rng.randi_range(0, count - 1)
	if count > 1 and idx == _last_window_view_idx:
		idx = (idx + 1 + rng.randi_range(0, count - 2)) % count
	_last_window_view_idx = idx
	# Lazy-load ONLY the single selected window texture so mobile VRAM stays minimal (~1 texture in memory)
	var chosen_tex: Texture2D = _load_cafe_tex(WINDOW_VIEW_TEXTURES[idx])
	if chosen_tex == null and idx != 0:
		chosen_tex = _load_cafe_tex(WINDOW_VIEW_TEXTURES[0])
	_window_vista_mat.albedo_texture = chosen_tex
	var open_boost: Color = Color(1.02, 0.99, 0.95) if _window_doors_open else Color(0.92, 0.90, 0.86)
	_window_vista_mat.albedo_color = open_boost if chosen_tex != null else Color(0.26, 0.22, 0.40)


func randomize_carpet() -> void:
	if _carpet_mat == null or CARPET_TEXTURES.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var count: int = CARPET_TEXTURES.size()
	var idx: int = rng.randi_range(0, count - 1)
	if count > 1 and idx == _last_carpet_idx:
		idx = (idx + 1 + rng.randi_range(0, count - 2)) % count
	_last_carpet_idx = idx
	# Lazy-load ONLY the single selected Persian carpet texture so mobile VRAM stays minimal
	var chosen_tex: Texture2D = _load_cafe_tex(CARPET_TEXTURES[idx])
	if chosen_tex == null and idx != 0:
		chosen_tex = _load_cafe_tex(CARPET_TEXTURES[0])
	_carpet_mat.albedo_texture = chosen_tex
	_carpet_mat.albedo_color = Color(0.88, 0.85, 0.80) if chosen_tex != null else Color(0.48, 0.10, 0.11)


# ============================================================================
# SENIOR UI/UX INTERACTIVE CAFE PROPS (ZERO-PHYSICS RAY-SPHERE PICKING)
# ============================================================================

func _register_interactive_prop(prop_id: String, node: Node3D, local_offset: Vector3, radius: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	_interactive_props.append({
		"id": prop_id,
		"node": node,
		"offset": local_offset,
		"radius": radius,
		"base_pos": node.position,
		"base_rot": node.rotation_degrees,
		"base_scale": node.scale
	})


func _play_cafe_sfx(sound_name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sound"):
		am.call("play_sound", sound_name)


func _kill_prop_tween(prop_id: String) -> void:
	if _prop_tweens.has(prop_id):
		var old_tw: Variant = _prop_tweens[prop_id]
		if old_tw is Tween and is_instance_valid(old_tw as Tween):
			(old_tw as Tween).kill()
		_prop_tweens.erase(prop_id)


func _spawn_steam_puff(world_origin: Vector3, count: int = 3) -> void:
	if not _lounge_root or not is_instance_valid(_lounge_root):
		return
	var mat_steam: Material = _shared_mats.get("steam", null) as Material
	if mat_steam == null:
		return
	for i: int in range(count):
		var puff: MeshInstance3D = _add_sphere(_lounge_root, 0.015, 0.032, Vector3.ZERO, mat_steam, Vector3.ZERO, 8)
		puff.set_meta("skip_bake", true)
		var jitter: Vector3 = Vector3((float(i) - float(count - 1) * 0.5) * 0.016, float(i) * 0.012, sin(float(i) * 2.1) * 0.012)
		puff.global_position = world_origin + jitter
		puff.scale = Vector3(0.45, 0.45, 0.45)
		var target_pos: Vector3 = puff.position + Vector3(jitter.x * 1.9, 0.21 + float(i) * 0.04, jitter.z * 1.5)
		var tw: Tween = create_tween().set_parallel(true)
		var delay_s: float = float(i) * 0.09
		tw.tween_property(puff, "position", target_pos, 1.15).set_delay(delay_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3(1.55, 1.85, 1.55), 0.55).set_delay(delay_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3(0.02, 0.02, 0.02), 0.60).set_delay(delay_s + 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(puff):
				puff.queue_free()
		)


func _try_interact_with_cafe_prop(screen_pos: Vector2) -> bool:
	if not is_board_view_active or is_transitioning or is_top_down_view:
		return false
	if camera == null or not is_instance_valid(camera) or _interactive_props.is_empty():
		return false
	if _is_board_consuming_input():
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_prop_interact_ms < 120:
		return false

	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)

	# Protect active game board felt surface: never steal taps aimed at the playing surface!
	var board_hit_t: float = INF
	if absf(ray_dir.y) > 0.0001:
		var t_plane: float = (0.068 - ray_origin.y) / ray_dir.y
		if t_plane > 0.0:
			var p_hit: Vector3 = ray_origin + ray_dir * t_plane
			if absf(p_hit.x) <= 0.755 and absf(p_hit.z) <= 0.735:
				board_hit_t = t_plane

	var best_t: float = INF
	var best_entry: Dictionary = {}

	for entry: Dictionary in _interactive_props:
		var prop_node: Node3D = entry["node"] as Node3D
		if prop_node == null or not is_instance_valid(prop_node) or not prop_node.is_visible_in_tree():
			continue
		var world_center: Vector3 = prop_node.to_global(entry["offset"] as Vector3)
		var oc: Vector3 = world_center - ray_origin
		var proj: float = oc.dot(ray_dir)
		if proj <= 0.0:
			continue
		var r: float = float(entry["radius"])
		var perp_sq: float = oc.length_squared() - proj * proj
		if perp_sq <= r * r:
			var t_hit: float = proj - sqrt(maxf(0.0, r * r - perp_sq))
			if t_hit < board_hit_t and t_hit < best_t:
				best_t = t_hit
				best_entry = entry

	if best_entry.is_empty():
		return false

	_last_prop_interact_ms = now_ms
	_trigger_cafe_prop_interaction(best_entry)
	var vp: Viewport = get_viewport()
	if vp:
		vp.set_input_as_handled()
	return true


func _tween_tactile_squash_pulse(prop_id: String, node: Node3D, base_scale: Vector3, stretch_y: float = 1.09, squash_xz: float = 0.94) -> Tween:
	_kill_prop_tween(prop_id)
	var tw: Tween = create_tween()
	_prop_tweens[prop_id] = tw
	tw.tween_property(node, "scale", Vector3(base_scale.x * squash_xz, base_scale.y * stretch_y, base_scale.z * squash_xz), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3(base_scale.x * 1.03, base_scale.y * 0.97, base_scale.z * 1.03), 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", base_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


func _toggle_window_doors() -> void:
	_window_doors_open = not _window_doors_open
	_kill_prop_tween("window_doors")
	_play_cafe_sfx("tap_button")

	# Right-hand rule around +Y: left hinge swings -104 deg, right hinge swings +104 deg -> both open INWARD into the parlor!
	var left_target: float = -104.0 if _window_doors_open else 0.0
	var right_target: float = 104.0 if _window_doors_open else 0.0
	var dur: float = 0.62 if _window_doors_open else 0.48
	var trans_type: int = Tween.TRANS_BACK if _window_doors_open else Tween.TRANS_CUBIC
	var ease_type: int = Tween.EASE_OUT if _window_doors_open else Tween.EASE_IN_OUT

	var tw: Tween = create_tween().set_parallel(true)
	_prop_tweens["window_doors"] = tw
	if _window_door_left and is_instance_valid(_window_door_left):
		tw.tween_property(_window_door_left, "rotation_degrees:y", left_target, dur).set_trans(trans_type).set_ease(ease_type)
	if _window_door_right and is_instance_valid(_window_door_right):
		tw.tween_property(_window_door_right, "rotation_degrees:y", right_target, dur).set_delay(0.04).set_trans(trans_type).set_ease(ease_type)
	if _window_vista_mat != null:
		var target_vista: Color = Color(1.03, 1.00, 0.96) if _window_doors_open else Color(0.92, 0.90, 0.86)
		tw.tween_property(_window_vista_mat, "albedo_color", target_vista, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _toggle_lamp_material(prop_id: String, mat: StandardMaterial3D, is_on: bool, on_albedo: Color, on_emit: Color, on_energy: float, off_albedo: Color) -> void:
	if mat == null:
		return
	var mat_key: String = prop_id + "_mat"
	_kill_prop_tween(mat_key)
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_prop_tweens[mat_key] = tw
	tw.tween_property(mat, "albedo_color", on_albedo if is_on else off_albedo, 0.24)
	tw.tween_property(mat, "emission", on_emit if is_on else Color(0.06, 0.04, 0.02), 0.24)
	tw.tween_property(mat, "emission_energy_multiplier", on_energy if is_on else 0.04, 0.24)


func _trigger_cafe_prop_interaction(entry: Dictionary) -> void:
	var prop_id: String = entry["id"] as String
	var node: Node3D = entry["node"] as Node3D
	if node == null or not is_instance_valid(node):
		return
	var base_pos: Vector3 = entry["base_pos"] as Vector3
	var base_rot: Vector3 = entry["base_rot"] as Vector3
	var base_scale: Vector3 = entry["base_scale"] as Vector3

	match prop_id:
		"window_doors":
			_toggle_window_doors()

		"desk_abajour":
			_desk_lamp_on = not _desk_lamp_on
			_play_cafe_sfx("tap_button")
			_tween_tactile_squash_pulse(prop_id, node, base_scale, 1.08, 0.95)
			_toggle_lamp_material(
				prop_id, _desk_lamp_shade_mat, _desk_lamp_on,
				Color(0.96, 0.84, 0.60), Color(1.0, 0.75, 0.36), 1.28, Color(0.46, 0.38, 0.28)
			)
			if not _is_mobile_gpu and has_node("TableLampLight"):
				var tl: OmniLight3D = get_node("TableLampLight") as OmniLight3D
				if tl:
					var l_tw: Tween = create_tween()
					l_tw.tween_property(tl, "light_energy", 0.84 if _desk_lamp_on else 0.28, 0.24)

		"desk_hourglass":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("time")
			var tw_hg: Tween = create_tween()
			_prop_tweens[prop_id] = tw_hg
			var cur_z: float = node.rotation_degrees.z
			var next_z: float = cur_z + 180.0
			tw_hg.tween_property(node, "position:y", base_pos.y + 0.085, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_hg.tween_property(node, "rotation_degrees:z", next_z, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			tw_hg.tween_property(node, "position:y", base_pos.y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw_hg.tween_callback(func() -> void:
				if is_instance_valid(node):
					node.rotation_degrees.z = fmod(node.rotation_degrees.z, 360.0)
			)

		"desk_khatam_box":
			_khatam_box_open = not _khatam_box_open
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("move_peace")
			var tw_kb: Tween = create_tween().set_parallel(true)
			_prop_tweens[prop_id] = tw_kb
			if _khatam_lid_pivot and is_instance_valid(_khatam_lid_pivot):
				var lid_ang: float = -108.0 if _khatam_box_open else 0.0
				var t_trans: int = Tween.TRANS_BACK if _khatam_box_open else Tween.TRANS_BOUNCE
				tw_kb.tween_property(_khatam_lid_pivot, "rotation_degrees:x", lid_ang, 0.42).set_trans(t_trans).set_ease(Tween.EASE_OUT)
			tw_kb.tween_property(node, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.94, base_scale.z * 1.05), 0.10)
			tw_kb.chain().tween_property(node, "scale", base_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		"desk_tea_tray":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("bell")
			var tw_tea: Tween = create_tween()
			_prop_tweens[prop_id] = tw_tea
			tw_tea.tween_property(node, "position:y", base_pos.y + 0.016, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_tea.parallel().tween_property(node, "rotation_degrees:z", base_rot.z + 4.5, 0.10)
			tw_tea.tween_property(node, "position:y", base_pos.y, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_tea.parallel().tween_property(node, "rotation_degrees:z", base_rot.z - 3.0, 0.14)
			tw_tea.tween_property(node, "rotation_degrees:z", base_rot.z, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_spawn_steam_puff(node.to_global(Vector3(-0.026, 0.085, 0.014)), 3)

		"desk_ajil_dish":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("dice")
			var tw_aj: Tween = create_tween()
			_prop_tweens[prop_id] = tw_aj
			tw_aj.tween_property(node, "position:y", base_pos.y + 0.024, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_aj.parallel().tween_property(node, "rotation_degrees:y", node.rotation_degrees.y + 28.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_aj.tween_property(node, "position:y", base_pos.y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		"estante_armillary":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("bell")
			var tw_arm: Tween = create_tween().set_parallel(true)
			_prop_tweens[prop_id] = tw_arm
			if _armillary_rings_pivot and is_instance_valid(_armillary_rings_pivot):
				var cur_y: float = _armillary_rings_pivot.rotation_degrees.y
				var cur_z: float = _armillary_rings_pivot.rotation_degrees.z
				tw_arm.tween_property(_armillary_rings_pivot, "rotation_degrees:y", cur_y + 360.0, 1.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
				tw_arm.tween_property(_armillary_rings_pivot, "rotation_degrees:z", cur_z + 18.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw_arm.chain().tween_property(_armillary_rings_pivot, "rotation_degrees:z", cur_z, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			else:
				tw_arm.tween_property(node, "rotation_degrees:y", node.rotation_degrees.y + 360.0, 1.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

		"estante_clock":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("time")
			var tw_clk: Tween = create_tween()
			_prop_tweens[prop_id] = tw_clk
			if _clock_hands_pivot and is_instance_valid(_clock_hands_pivot):
				var h_tw: Tween = create_tween()
				h_tw.tween_property(_clock_hands_pivot, "rotation_degrees:z", _clock_hands_pivot.rotation_degrees.z - 360.0, 0.72).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tw_clk.tween_property(node, "position:y", base_pos.y + 0.018, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_clk.parallel().tween_property(node, "rotation_degrees:z", base_rot.z + 8.0, 0.08)
			tw_clk.tween_property(node, "rotation_degrees:z", base_rot.z - 8.0, 0.10)
			tw_clk.tween_property(node, "rotation_degrees:z", base_rot.z + 4.5, 0.09)
			tw_clk.tween_property(node, "position:y", base_pos.y, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw_clk.parallel().tween_property(node, "rotation_degrees:z", base_rot.z, 0.12)

		"estante_samovar":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("bell")
			var tw_sam: Tween = create_tween()
			_prop_tweens[prop_id] = tw_sam
			if _samovar_teapot_pivot and is_instance_valid(_samovar_teapot_pivot):
				var tp: Node3D = _samovar_teapot_pivot
				tw_sam.tween_property(tp, "position:y", 0.252, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw_sam.parallel().tween_property(tp, "rotation_degrees:z", 13.0, 0.08)
				tw_sam.tween_property(tp, "rotation_degrees:z", -11.0, 0.11)
				tw_sam.tween_property(tp, "rotation_degrees:z", 6.0, 0.10)
				tw_sam.tween_property(tp, "position:y", 0.235, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw_sam.parallel().tween_property(tp, "rotation_degrees:z", 0.0, 0.12)
			else:
				_tween_tactile_squash_pulse(prop_id, node, base_scale, 1.07, 0.96)
			_spawn_steam_puff(node.to_global(Vector3(0.0, 0.295, 0.0)), 4)

		"estante_bust":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("tap")
			var tw_b: Tween = create_tween()
			_prop_tweens[prop_id] = tw_b
			tw_b.tween_property(node, "rotation_degrees", base_rot + Vector3(11.0, 12.0, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_b.tween_property(node, "rotation_degrees", base_rot + Vector3(-4.0, -6.0, 0.0), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_b.tween_property(node, "rotation_degrees", base_rot, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		"estante_books":
			_hero_book_pulled = not _hero_book_pulled
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("move_peace")
			if _hero_book_pivot and is_instance_valid(_hero_book_pivot):
				var tw_bk: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_prop_tweens[prop_id] = tw_bk
				var target_z: float = 0.115 if _hero_book_pulled else 0.02
				var target_yaw: float = 11.5 if _hero_book_pulled else 1.5
				var target_pitch: float = -6.0 if _hero_book_pulled else 0.0
				tw_bk.tween_property(_hero_book_pivot, "position:z", target_z, 0.36)
				tw_bk.tween_property(_hero_book_pivot, "rotation_degrees:y", target_yaw, 0.36)
				tw_bk.tween_property(_hero_book_pivot, "rotation_degrees:x", target_pitch, 0.36)

		"estante_sign":
			_kill_prop_tween(prop_id)
			_play_cafe_sfx("bell")
			var tw_sg: Tween = create_tween()
			_prop_tweens[prop_id] = tw_sg
			tw_sg.tween_property(node, "scale", base_scale * 1.045, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_sg.parallel().tween_property(node, "rotation_degrees:x", base_rot.x - 5.5, 0.12)
			tw_sg.tween_property(node, "rotation_degrees:x", base_rot.x + 3.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_sg.parallel().tween_property(node, "scale", base_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_sg.tween_property(node, "rotation_degrees:x", base_rot.x, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		"left_table_lamp":
			_left_lamp_on = not _left_lamp_on
			_play_cafe_sfx("tap_button")
			_tween_tactile_squash_pulse(prop_id, node, base_scale, 1.07, 0.95)
			_toggle_lamp_material(
				prop_id, _left_lamp_shade_mat, _left_lamp_on,
				Color(0.96, 0.84, 0.62), Color(1.0, 0.76, 0.38), 1.32, Color(0.45, 0.37, 0.27)
			)

		"right_table_lantern":
			_right_lantern_on = not _right_lantern_on
			_play_cafe_sfx("tap_button")
			_kill_prop_tween(prop_id)
			var tw_rl: Tween = create_tween()
			_prop_tweens[prop_id] = tw_rl
			tw_rl.tween_property(node, "rotation_degrees:z", base_rot.z + 7.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_rl.tween_property(node, "rotation_degrees:z", base_rot.z - 5.0, 0.13)
			tw_rl.tween_property(node, "rotation_degrees:z", base_rot.z, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_toggle_lamp_material(
				prop_id, _right_lantern_glow_mat, _right_lantern_on,
				Color(0.98, 0.76, 0.34), Color(1.0, 0.70, 0.22), 1.55, Color(0.36, 0.28, 0.20)
			)


func _init_lounge_materials() -> void:
	var wood_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/images/background2.jpg"):
		wood_tex = load("res://assets/images/background2.jpg") as Texture2D

	# Lightweight mobile-optimized Persian craft & antique book textures (128-512px, VRAM-compressed)
	var tex_baize: Texture2D = _load_cafe_tex("parlor_baize_felt.jpg")
	var tex_minakari: Texture2D = _load_cafe_tex("persian_minakari.jpg")
	var tex_khatam: Texture2D = _load_cafe_tex("persian_khatam.jpg")
	var tex_termeh: Texture2D = _load_cafe_tex("persian_termeh.jpg")
	var tex_book_hafez: Texture2D = _load_cafe_tex("book_hafez_tazhib.jpg")
	var tex_book_shamseh: Texture2D = _load_cafe_tex("book_leather_shamseh.jpg")
	var tex_book_spine: Texture2D = _load_cafe_tex("book_spine_ornate.jpg")
	var tex_book_cloth: Texture2D = _load_cafe_tex("book_vintage_cloth.jpg")
	var tex_book_shahnameh: Texture2D = _load_cafe_tex("book_shahnameh_epic.jpg")
	var tex_book_abru: Texture2D = _load_cafe_tex("book_marbled_abru.jpg")
	var tex_book_golestan: Texture2D = _load_cafe_tex("book_golestan_floral.jpg")
	var tex_book_filigree: Texture2D = _load_cafe_tex("book_spine_filigree.jpg")
	var tex_chair_crimson: Texture2D = _load_cafe_tex("chair_velvet_crimson.jpg")
	var tex_chair_emerald: Texture2D = _load_cafe_tex("chair_velvet_emerald.jpg")
	var tex_chair_amber: Texture2D = _load_cafe_tex("chair_velvet_amber.jpg")
	var tex_chair_cobalt: Texture2D = _load_cafe_tex("chair_velvet_cobalt.jpg")
	var tex_chair_ruby: Texture2D = _load_cafe_tex("chair_termeh_ruby.jpg")

	# Mobile-friendly velvet-baize material (zero normal-map shader overhead, zero specular glare in 2D mode)
	var mat_baize: StandardMaterial3D = StandardMaterial3D.new()
	mat_baize.albedo_color = Color(0.11, 0.34, 0.19) if tex_baize != null else Color(0.08, 0.27, 0.15)
	if tex_baize != null:
		mat_baize.albedo_texture = tex_baize
		mat_baize.uv1_scale = Vector3(4.5, 4.5, 4.5)
	mat_baize.roughness = 0.90
	mat_baize.metallic = 0.0
	mat_baize.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mat_baize_border: StandardMaterial3D = StandardMaterial3D.new()
	mat_baize_border.albedo_color = Color(0.06, 0.21, 0.11) if tex_baize != null else Color(0.05, 0.19, 0.10)
	if tex_baize != null:
		mat_baize_border.albedo_texture = tex_baize
		mat_baize_border.uv1_scale = Vector3(4.0, 4.0, 4.0)
	mat_baize_border.roughness = 0.92
	mat_baize_border.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mat_walnut_polished: StandardMaterial3D = _make_mat(Color(0.54, 0.31, 0.16), 0.32, 0.04, wood_tex, Vector3(1.5, 1.5, 1.5))
	var mat_walnut_mid: StandardMaterial3D = _make_mat(Color(0.42, 0.24, 0.12), 0.38, 0.03, wood_tex, Vector3(1.8, 1.8, 1.8))
	var mat_walnut_dark: StandardMaterial3D = _make_mat(Color(0.28, 0.15, 0.08), 0.42, 0.02, wood_tex, Vector3(2.0, 2.0, 2.0))
	var mat_mahogany: StandardMaterial3D = _make_mat(Color(0.43, 0.19, 0.09), 0.34, 0.04, wood_tex, Vector3(1.4, 1.4, 1.4))
	var mat_ebony_wood: StandardMaterial3D = _make_mat(Color(0.16, 0.09, 0.05), 0.36, 0.04)

	var mat_brass: StandardMaterial3D = _make_mat(Color(0.94, 0.76, 0.34), 0.24, 0.86)
	var mat_aged_brass: StandardMaterial3D = _make_mat(Color(0.76, 0.58, 0.24), 0.34, 0.80)
	var mat_emerald_jade: StandardMaterial3D = _make_mat(Color(0.11, 0.42, 0.25), 0.24, 0.15)
	var mat_bulb_glow: StandardMaterial3D = _make_emissive_mat(Color(1.0, 0.94, 0.78), Color(1.0, 0.84, 0.48), 2.35, 0.15)
	var mat_lampshade_glow: StandardMaterial3D = _make_emissive_mat(Color(0.96, 0.84, 0.62), Color(1.0, 0.76, 0.38), 1.32, 0.44)
	_desk_lamp_shade_mat = _make_emissive_mat(Color(0.96, 0.84, 0.60), Color(1.0, 0.75, 0.36), 1.28, 0.40)
	_left_lamp_shade_mat = _make_emissive_mat(Color(0.96, 0.84, 0.62), Color(1.0, 0.76, 0.38), 1.32, 0.44)
	_right_lantern_glow_mat = _make_emissive_mat(Color(0.98, 0.76, 0.34), Color(1.0, 0.70, 0.22), 1.55, 0.22)
	var mat_abajour_shade: StandardMaterial3D = _desk_lamp_shade_mat

	# Mobile-optimized lightweight glass pane & diagonal reflection sheen for interactive hinged window doors
	var mat_window_glass: StandardMaterial3D = StandardMaterial3D.new()
	mat_window_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_window_glass.albedo_color = Color(0.84, 0.92, 1.0, 0.20)
	mat_window_glass.roughness = 0.08
	mat_window_glass.metallic = 0.14
	mat_window_glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_window_glass_glint: StandardMaterial3D = StandardMaterial3D.new()
	mat_window_glass_glint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_window_glass_glint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_window_glass_glint.albedo_color = Color(1.0, 0.97, 0.88, 0.11)
	mat_window_glass_glint.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_leather_green: StandardMaterial3D = _make_mat(Color(0.12, 0.26, 0.15), 0.40, 0.06)
	var mat_leather_green_dark: StandardMaterial3D = _make_mat(Color(0.07, 0.16, 0.09), 0.46, 0.04)
	var mat_velvet_curtain: StandardMaterial3D = _make_mat(Color(0.72, 0.28, 0.28) if tex_termeh != null else Color(0.50, 0.09, 0.11), 0.84, 0.02, tex_termeh, Vector3(1.2, 3.2, 1.0))
	mat_velvet_curtain.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mat_marble: StandardMaterial3D = _make_mat(Color(0.84, 0.79, 0.71), 0.34, 0.02)
	var mat_porcelain: StandardMaterial3D = _make_mat(Color(0.92, 0.88, 0.80), 0.18, 0.04)
	var mat_coffee_dark: StandardMaterial3D = _make_mat(Color(0.16, 0.07, 0.03), 0.10, 0.05)
	var mat_steam: StandardMaterial3D = _make_emissive_mat(Color(0.96, 0.92, 0.88), Color(0.90, 0.82, 0.72), 0.40, 0.80, 0.22)

	var mat_leaf_dark: StandardMaterial3D = _make_mat(Color(0.13, 0.33, 0.12), 0.44, 0.02)
	var mat_leaf_mid: StandardMaterial3D = _make_mat(Color(0.20, 0.44, 0.15), 0.40, 0.02)
	var mat_leaf_bright: StandardMaterial3D = _make_mat(Color(0.28, 0.52, 0.19), 0.38, 0.02)

	# Textured antique Persian book bindings (8 lightweight textures -> 22 distinct editions via vertex-color tinting!)
	var mat_book_red: StandardMaterial3D = _make_mat(Color(0.92, 0.34, 0.30) if tex_book_spine != null else Color(0.56, 0.13, 0.12), 0.48, 0.03, tex_book_spine, Vector3.ONE)
	var mat_book_green: StandardMaterial3D = _make_mat(Color(0.36, 0.72, 0.46) if tex_book_spine != null else Color(0.12, 0.34, 0.19), 0.48, 0.03, tex_book_spine, Vector3.ONE)
	var mat_book_navy: StandardMaterial3D = _make_mat(Color(0.36, 0.52, 0.86) if tex_book_spine != null else Color(0.13, 0.22, 0.40), 0.48, 0.03, tex_book_spine, Vector3.ONE)
	var mat_book_brown: StandardMaterial3D = _make_mat(Color(0.84, 0.62, 0.42) if tex_book_spine != null else Color(0.39, 0.21, 0.10), 0.50, 0.03, tex_book_spine, Vector3.ONE)
	var mat_book_ochre: StandardMaterial3D = _make_mat(Color(0.64, 0.43, 0.18), 0.48, 0.02)
	var mat_book_burgundy: StandardMaterial3D = _make_mat(Color(0.78, 0.28, 0.38) if tex_book_spine != null else Color(0.42, 0.10, 0.15), 0.48, 0.03, tex_book_spine, Vector3.ONE)
	var mat_book_hafez: StandardMaterial3D = _make_mat(Color(0.96, 0.94, 0.90) if tex_book_hafez != null else Color(0.16, 0.26, 0.52), 0.42, 0.06, tex_book_hafez, Vector3.ONE)
	var mat_book_shahnameh: StandardMaterial3D = _make_mat(Color(0.96, 0.94, 0.90) if tex_book_shahnameh != null else Color(0.56, 0.10, 0.12), 0.42, 0.06, tex_book_shahnameh, Vector3.ONE)
	var mat_book_golestan: StandardMaterial3D = _make_mat(Color(0.96, 0.95, 0.92) if tex_book_golestan != null else Color(0.08, 0.36, 0.32), 0.40, 0.05, tex_book_golestan, Vector3.ONE)
	var mat_book_abru_cobalt: StandardMaterial3D = _make_mat(Color(0.95, 0.94, 0.92) if tex_book_abru != null else Color(0.14, 0.36, 0.54), 0.56, 0.02, tex_book_abru, Vector3.ONE)
	var mat_book_abru_amber: StandardMaterial3D = _make_mat(Color(0.98, 0.84, 0.62) if tex_book_abru != null else Color(0.62, 0.46, 0.24), 0.56, 0.02, tex_book_abru, Vector3.ONE)
	var mat_book_shamseh_ruby: StandardMaterial3D = _make_mat(Color(0.80, 0.26, 0.26) if tex_book_shamseh != null else Color(0.54, 0.12, 0.12), 0.46, 0.05, tex_book_shamseh, Vector3.ONE)
	var mat_book_shamseh_emerald: StandardMaterial3D = _make_mat(Color(0.28, 0.64, 0.40) if tex_book_shamseh != null else Color(0.12, 0.36, 0.20), 0.46, 0.05, tex_book_shamseh, Vector3.ONE)
	var mat_book_shamseh_lapis: StandardMaterial3D = _make_mat(Color(0.30, 0.48, 0.82) if tex_book_shamseh != null else Color(0.14, 0.24, 0.46), 0.46, 0.05, tex_book_shamseh, Vector3.ONE)
	var mat_book_shamseh_tan: StandardMaterial3D = _make_mat(Color(0.96, 0.88, 0.74) if tex_book_shamseh != null else Color(0.66, 0.48, 0.24), 0.46, 0.05, tex_book_shamseh, Vector3.ONE)
	var mat_book_cloth_ochre: StandardMaterial3D = _make_mat(Color(0.92, 0.76, 0.44) if tex_book_cloth != null else Color(0.64, 0.46, 0.20), 0.72, 0.0, tex_book_cloth, Vector3.ONE)
	var mat_book_cloth_teal: StandardMaterial3D = _make_mat(Color(0.36, 0.70, 0.68) if tex_book_cloth != null else Color(0.14, 0.42, 0.44), 0.72, 0.0, tex_book_cloth, Vector3.ONE)
	var mat_book_cloth_crimson: StandardMaterial3D = _make_mat(Color(0.80, 0.28, 0.28) if tex_book_cloth != null else Color(0.52, 0.12, 0.14), 0.72, 0.0, tex_book_cloth, Vector3.ONE)
	var mat_book_cloth_olive: StandardMaterial3D = _make_mat(Color(0.58, 0.66, 0.40) if tex_book_cloth != null else Color(0.30, 0.38, 0.18), 0.72, 0.0, tex_book_cloth, Vector3.ONE)
	var mat_book_filigree_plum: StandardMaterial3D = _make_mat(Color(0.68, 0.30, 0.56) if tex_book_filigree != null else Color(0.36, 0.14, 0.30), 0.46, 0.05, tex_book_filigree, Vector3.ONE)
	var mat_book_filigree_saffron: StandardMaterial3D = _make_mat(Color(0.94, 0.72, 0.28) if tex_book_filigree != null else Color(0.72, 0.50, 0.16), 0.46, 0.05, tex_book_filigree, Vector3.ONE)
	var mat_book_filigree_copper: StandardMaterial3D = _make_mat(Color(0.84, 0.44, 0.26) if tex_book_filigree != null else Color(0.58, 0.26, 0.14), 0.46, 0.05, tex_book_filigree, Vector3.ONE)
	var mat_book_filigree_teal: StandardMaterial3D = _make_mat(Color(0.24, 0.62, 0.60) if tex_book_filigree != null else Color(0.12, 0.38, 0.38), 0.46, 0.05, tex_book_filigree, Vector3.ONE)
	var mat_book_filigree_ivory: StandardMaterial3D = _make_mat(Color(0.95, 0.90, 0.80) if tex_book_filigree != null else Color(0.78, 0.72, 0.60), 0.48, 0.04, tex_book_filigree, Vector3.ONE)
	var mat_book_pages: StandardMaterial3D = _make_mat(Color(0.84, 0.77, 0.65), 0.68, 0.0)

	# Persistent unshaded arched-window vista material (swapped randomly across 5 Persian views on each game!)
	_window_vista_mat = StandardMaterial3D.new()
	_window_vista_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_window_vista_mat.roughness = 0.85
	_window_vista_mat.albedo_color = Color(0.96, 0.94, 0.90)
	randomize_window_view()
	var mat_window_twilight_view: StandardMaterial3D = _window_vista_mat

	# Warm Persian parlor & craft accent materials (all baked into minimal shared texture/vertex-color surfaces!)
	var mat_rug_crimson: StandardMaterial3D = _make_mat(Color(0.48, 0.10, 0.11), 0.88, 0.0)
	var mat_rug_navy: StandardMaterial3D = _make_mat(Color(0.09, 0.14, 0.26), 0.88, 0.0)
	var mat_rug_gold: StandardMaterial3D = _make_mat(Color(0.78, 0.60, 0.24), 0.78, 0.04)
	var mat_rug_cream: StandardMaterial3D = _make_mat(Color(0.82, 0.74, 0.60), 0.86, 0.0)
	var mat_terracotta: StandardMaterial3D = _make_mat(Color(0.58, 0.27, 0.15), 0.54, 0.04)
	var mat_cream_plaster: StandardMaterial3D = _make_mat(Color(0.82, 0.74, 0.62), 0.76, 0.0)
	var mat_tea_amber: StandardMaterial3D = _make_emissive_mat(Color(0.76, 0.26, 0.05), Color(0.88, 0.32, 0.05), 0.72, 0.18)
	var mat_stained_amber: StandardMaterial3D = _make_emissive_mat(Color(0.98, 0.76, 0.34), Color(1.0, 0.70, 0.22), 1.55, 0.22)
	var mat_stained_emerald: StandardMaterial3D = _make_emissive_mat(Color(0.22, 0.70, 0.44), Color(0.18, 0.66, 0.38), 1.25, 0.24)
	var mat_stained_ruby: StandardMaterial3D = _make_emissive_mat(Color(0.88, 0.24, 0.22), Color(0.90, 0.20, 0.18), 1.30, 0.24)
	var mat_stained_cobalt: StandardMaterial3D = _make_emissive_mat(Color(0.18, 0.38, 0.84), Color(0.16, 0.36, 0.88), 1.30, 0.24)
	var mat_stained_turquoise: StandardMaterial3D = _make_emissive_mat(Color(0.14, 0.72, 0.76), Color(0.12, 0.70, 0.74), 1.28, 0.24)
	var mat_fairy_glow: StandardMaterial3D = _make_emissive_mat(Color(1.0, 0.90, 0.66), Color(1.0, 0.78, 0.36), 2.15, 0.12)
	var mat_cove_glow: StandardMaterial3D = _make_emissive_mat(Color(0.96, 0.80, 0.50), Color(1.0, 0.72, 0.28), 1.15, 0.30)

	# Authentic Persian craft pigments & textured materials (safe fallback to solid pigments if texture missing)
	var mat_persian_turquoise: StandardMaterial3D = _make_mat(Color(0.08, 0.56, 0.62), 0.28, 0.06)
	var mat_persian_cobalt: StandardMaterial3D = _make_mat(Color(0.11, 0.23, 0.54), 0.32, 0.06)
	var mat_persian_copper: StandardMaterial3D = _make_mat(Color(0.76, 0.37, 0.19), 0.30, 0.78)
	var mat_persian_saffron: StandardMaterial3D = _make_mat(Color(0.88, 0.64, 0.16), 0.42, 0.04)

	# Persistent Persian floor carpet material (swapped randomly across 5 regional carpets on each game!)
	_carpet_mat = StandardMaterial3D.new()
	_carpet_mat.roughness = 0.90
	_carpet_mat.metallic = 0.0
	_carpet_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_carpet_mat.albedo_color = Color(0.88, 0.85, 0.80)
	randomize_carpet()
	var mat_persian_carpet: StandardMaterial3D = _carpet_mat

	var mat_minakari_ceramic: StandardMaterial3D = _make_mat(Color(0.95, 0.97, 0.98) if tex_minakari != null else Color(0.08, 0.56, 0.62), 0.22, 0.05, tex_minakari, Vector3.ONE)
	var mat_khatam_inlay: StandardMaterial3D = _make_mat(Color(0.92, 0.88, 0.82) if tex_khatam != null else Color(0.68, 0.52, 0.24), 0.30, 0.08, tex_khatam, Vector3(1.2, 1.2, 1.2))
	var mat_termeh_fabric: StandardMaterial3D = _make_mat(Color(0.88, 0.84, 0.80) if tex_termeh != null else Color(0.48, 0.10, 0.11), 0.86, 0.0, tex_termeh, Vector3(1.4, 1.4, 1.4))
	mat_termeh_fabric.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# Rich textured upholstery materials for the 5 randomized 3D Persian parlor chairs
	var mat_chair_crimson: StandardMaterial3D = _make_mat(Color(0.96, 0.92, 0.90) if tex_chair_crimson != null else Color(0.48, 0.09, 0.12), 0.84, 0.02, tex_chair_crimson, Vector3(1.10, 1.10, 1.10))
	mat_chair_crimson.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mat_chair_emerald: StandardMaterial3D = _make_mat(Color(0.95, 0.96, 0.94) if tex_chair_emerald != null else Color(0.10, 0.32, 0.18), 0.82, 0.02, tex_chair_emerald, Vector3(1.10, 1.10, 1.10))
	mat_chair_emerald.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mat_chair_amber: StandardMaterial3D = _make_mat(Color(0.98, 0.95, 0.90) if tex_chair_amber != null else Color(0.68, 0.46, 0.16), 0.82, 0.02, tex_chair_amber, Vector3(1.10, 1.10, 1.10))
	mat_chair_amber.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mat_chair_cobalt: StandardMaterial3D = _make_mat(Color(0.95, 0.95, 0.98) if tex_chair_cobalt != null else Color(0.11, 0.22, 0.48), 0.82, 0.02, tex_chair_cobalt, Vector3(1.10, 1.10, 1.10))
	mat_chair_cobalt.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mat_chair_ruby: StandardMaterial3D = _make_mat(Color(0.96, 0.92, 0.90) if tex_chair_ruby != null else Color(0.52, 0.10, 0.14), 0.84, 0.02, tex_chair_ruby, Vector3(1.10, 1.10, 1.10))
	mat_chair_ruby.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mat_chair_crimson_trim: StandardMaterial3D = _make_mat(Color(0.32, 0.06, 0.08), 0.72, 0.03)
	var mat_chair_emerald_trim: StandardMaterial3D = _make_mat(Color(0.06, 0.20, 0.11), 0.72, 0.03)
	var mat_chair_amber_trim: StandardMaterial3D = _make_mat(Color(0.46, 0.28, 0.08), 0.72, 0.03)
	var mat_chair_cobalt_trim: StandardMaterial3D = _make_mat(Color(0.06, 0.12, 0.28), 0.72, 0.03)
	var mat_chair_ruby_trim: StandardMaterial3D = _make_mat(Color(0.34, 0.06, 0.08), 0.72, 0.03)

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
		"book_hafez": mat_book_hafez,
		"book_shahnameh": mat_book_shahnameh,
		"book_golestan": mat_book_golestan,
		"book_abru_cobalt": mat_book_abru_cobalt,
		"book_abru_amber": mat_book_abru_amber,
		"book_shamseh_ruby": mat_book_shamseh_ruby,
		"book_shamseh_emerald": mat_book_shamseh_emerald,
		"book_shamseh_lapis": mat_book_shamseh_lapis,
		"book_shamseh_tan": mat_book_shamseh_tan,
		"book_cloth_ochre": mat_book_cloth_ochre,
		"book_cloth_teal": mat_book_cloth_teal,
		"book_cloth_crimson": mat_book_cloth_crimson,
		"book_cloth_olive": mat_book_cloth_olive,
		"book_filigree_plum": mat_book_filigree_plum,
		"book_filigree_saffron": mat_book_filigree_saffron,
		"book_filigree_copper": mat_book_filigree_copper,
		"book_filigree_teal": mat_book_filigree_teal,
		"book_filigree_ivory": mat_book_filigree_ivory,
		"book_pages": mat_book_pages,
		"window_twilight_view": mat_window_twilight_view,
		"rug_crimson": mat_rug_crimson,
		"rug_navy": mat_rug_navy,
		"rug_gold": mat_rug_gold,
		"rug_cream": mat_rug_cream,
		"terracotta": mat_terracotta,
		"cream_plaster": mat_cream_plaster,
		"tea_amber": mat_tea_amber,
		"stained_amber": mat_stained_amber,
		"stained_emerald": mat_stained_emerald,
		"stained_ruby": mat_stained_ruby,
		"stained_cobalt": mat_stained_cobalt,
		"stained_turquoise": mat_stained_turquoise,
		"fairy_glow": mat_fairy_glow,
		"cove_glow": mat_cove_glow,
		"persian_turquoise": mat_persian_turquoise,
		"persian_cobalt": mat_persian_cobalt,
		"persian_copper": mat_persian_copper,
		"persian_saffron": mat_persian_saffron,
		"persian_carpet": mat_persian_carpet,
		"minakari_ceramic": mat_minakari_ceramic,
		"khatam_inlay": mat_khatam_inlay,
		"termeh_fabric": mat_termeh_fabric,
		"window_glass": mat_window_glass,
		"window_glass_glint": mat_window_glass_glint,
		"left_lamp_shade": _left_lamp_shade_mat,
		"right_lantern_glow": _right_lantern_glow_mat,
		"chair_crimson": mat_chair_crimson,
		"chair_emerald": mat_chair_emerald,
		"chair_amber": mat_chair_amber,
		"chair_cobalt": mat_chair_cobalt,
		"chair_ruby": mat_chair_ruby,
		"chair_crimson_trim": mat_chair_crimson_trim,
		"chair_emerald_trim": mat_chair_emerald_trim,
		"chair_amber_trim": mat_chair_amber_trim,
		"chair_cobalt_trim": mat_chair_cobalt_trim,
		"chair_ruby_trim": mat_chair_ruby_trim
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
	_interactive_props.clear()
	_prop_tweens.clear()
	_desk_lamp_on = true
	_left_lamp_on = true
	_right_lantern_on = true
	_window_doors_open = false
	_khatam_box_open = false
	_hero_book_pulled = false
	_window_door_left = null
	_window_door_right = null
	_khatam_lid_pivot = null
	_armillary_rings_pivot = null
	_clock_hands_pivot = null
	_samovar_teapot_pivot = null
	_hero_book_pivot = null

	# 1. Foreground Luxury Carved Walnut Gaming Table, Reusable Green Felt, Corner Desk Abajour & Tea Corner
	var table_root: Node3D = get_node_or_null("TableRoot") as Node3D
	if table_root:
		_build_foreground_gaming_table(table_root)
		_build_desk_abajour(table_root)

	# 1B. Warm Persian Parlor Rug & Corner Floor Props (visible in 3D, Steep Board & 2D Top-Down; 1 baked mesh)
	_build_floor_rug_and_corners(_lounge_root)

	# 2. Multi-Player Tufted Dark-Green Leather Club Chairs (2, 3, or 4 Players, Baked Shared ArrayMesh)
	_build_player_chairs_around_table(_chairs_root)

	# 3. Back 3-Bay Classical Walnut Library Bookcase, Cove Lights, Hanging Pendants, Fairy Garland, Art & Sign
	_build_back_bookcase_and_sign(_lounge_backdrop_root)

	# 4. Left Arched Golden-Hour Window (Stained Glass + City Skyline), Left Side Table, Brass Lamp & Club Chair
	_build_left_window_and_lounge(_lounge_backdrop_root)

	# 5. Right Crimson Velvet Curtain Drapery, Right Side Table, Steaming Teacup, Brass Lantern, Books & Plant
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

	# Shiraz Khatam-Kari marquetry inset panel on the front carved table apron
	_add_box(arena_frame, Vector3(1.06, 0.062, 0.025), Vector3(0.0, apron_y, apron_z + 0.025), _shared_mats["khatam_inlay"])

	# Cozy Persian Parlor Corner Props on Outer Walnut Rails (strictly outside felt |X|>0.78 or |Z|>0.76)
	_build_table_persian_tea_tray(arena_frame, Vector3(0.86, 0.084, -0.86))
	_build_table_brass_hourglass(arena_frame, Vector3(-0.52, 0.084, -0.87))
	_build_table_khatam_box(arena_frame, Vector3(0.48, 0.084, -0.88))
	_build_table_ajil_dish(arena_frame, Vector3(0.88, 0.084, -0.58))
	# Textured Persian Mina-Kari & Brass Corner Inlays on the Front-Left & Front-Right Walnut Corners
	for corner_s: float in [-1.0, 1.0]:
		var cx_in: float = corner_s * 0.88
		_add_box(arena_frame, Vector3(0.088, 0.003, 0.088), Vector3(cx_in, 0.085, 0.86), mat_aged_brass, Vector3(0.0, 45.0, 0.0))
		_add_plane(arena_frame, Vector2(0.068, 0.068), Vector3(cx_in, 0.0875, 0.86), _shared_mats["minakari_ceramic"], Vector3(0.0, 45.0, 0.0))

	# Bake all table frame moldings, corner scrolls, rosettes, legs & rail props into 1 single draw-call mesh!
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

	# Bake the Desk Abajour into a single multi-surface MeshInstance3D & register interactive lamp toggle
	_bake_interactive_prop_branch(abajour, "BakedDeskAbajourMesh")
	_register_interactive_prop("desk_abajour", abajour, Vector3(0.0, 0.18, 0.0), 0.17)


# ============================================================================
# 2. MULTI-PLAYER PERSIAN PARLOR CHAIRS (4 RANDOMIZED STYLES + GROUNDED BASES)
# ============================================================================

func _get_or_build_chair_style_mesh(style_idx: int) -> ArrayMesh:
	var idx: int = clampi(style_idx, 0, CHAIR_STYLE_COUNT - 1)
	if _chair_style_meshes.has(idx):
		var cached: ArrayMesh = _chair_style_meshes[idx] as ArrayMesh
		if cached != null:
			return cached
	var temp_chair: Node3D = Node3D.new()
	match idx:
		0:
			_populate_chair_style_0_chesterfield(temp_chair)
		1:
			_populate_chair_style_1_qajar_wingback(temp_chair)
		2:
			_populate_chair_style_2_isfahan_medallion(temp_chair)
		3:
			_populate_chair_style_3_orosi_lattice(temp_chair)
		4:
			_populate_chair_style_4_termeh_armchair(temp_chair)
	var baked: ArrayMesh = _bake_node_tree_to_array_mesh(temp_chair)
	temp_chair.free()
	if baked != null:
		_chair_style_meshes[idx] = baked
	return baked


func randomize_chair_style() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var idx: int = rng.randi_range(0, CHAIR_STYLE_COUNT - 1)
	if CHAIR_STYLE_COUNT > 1 and idx == _last_chair_style_idx:
		idx = (idx + 1 + rng.randi_range(0, CHAIR_STYLE_COUNT - 2)) % CHAIR_STYLE_COUNT
	_last_chair_style_idx = idx
	var chosen_mesh: ArrayMesh = _get_or_build_chair_style_mesh(idx)
	if chosen_mesh == null:
		return
	_chair_shared_mesh = chosen_mesh
	for ch_mi: MeshInstance3D in [_chair_north, _chair_south, _chair_west, _chair_east]:
		if ch_mi and is_instance_valid(ch_mi):
			ch_mi.mesh = _chair_shared_mesh


func _build_player_chairs_around_table(chairs_parent: Node3D) -> void:
	_chair_style_meshes.clear()
	_last_chair_style_idx = -1

	# 1. NORTH CHAIR (Opponent Side — Behind Table, Facing +Z; grounded flush at carpet y = -0.77)
	_chair_north = MeshInstance3D.new()
	_chair_north.name = "NorthOpponentChair"
	_chair_north.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_north.position = Vector3(0.0, 0.0, -1.42)
	_chair_north.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	chairs_parent.add_child(_chair_north)

	# 2. SOUTH CHAIR (My Side — Front of Table, Facing -Z)
	_chair_south = MeshInstance3D.new()
	_chair_south.name = "SouthPlayerChair"
	_chair_south.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_south.position = Vector3(0.0, -0.22, 1.22)
	_chair_south.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	chairs_parent.add_child(_chair_south)

	# 3. WEST CHAIR (Player 3 — Left Side of Table, Angled Toward Table Center; grounded flush at carpet)
	_chair_west = MeshInstance3D.new()
	_chair_west.name = "WestPlayerChair"
	_chair_west.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_west.position = Vector3(-1.38, -0.09, -0.15)
	_chair_west.rotation_degrees = Vector3(0.0, 75.0, 0.0)
	_chair_west.scale = Vector3(0.88, 0.88, 0.88)
	_chair_west.visible = false
	chairs_parent.add_child(_chair_west)

	# 4. EAST CHAIR (Player 4 — Right Side of Table, Angled Toward Table Center; grounded flush at carpet)
	_chair_east = MeshInstance3D.new()
	_chair_east.name = "EastPlayerChair"
	_chair_east.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chair_east.position = Vector3(1.38, -0.09, -0.15)
	_chair_east.rotation_degrees = Vector3(0.0, -75.0, 0.0)
	_chair_east.scale = Vector3(0.88, 0.88, 0.88)
	_chair_east.visible = false
	chairs_parent.add_child(_chair_east)

	randomize_chair_style()


func _add_grounded_chair_base(chair: Node3D, mat_wood_main: Material, mat_wood_dark: Material, mat_accent: Material, stretcher_style: int = 0) -> void:
	# Refined architectural parlor chair base descending cleanly from seat apron (y = -0.15) to carpet floor (y = -0.77)
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	# Sculpted Seat-Frame Apron with Recessed Molding & Rounded Front Corner Columns
	_add_box(chair, Vector3(0.74, 0.062, 0.42), Vector3(0.0, -0.172, 0.21), mat_wood_dark)
	_add_box(chair, Vector3(0.76, 0.016, 0.44), Vector3(0.0, -0.140, 0.21), mat_wood_main)
	_add_box(chair, Vector3(0.75, 0.014, 0.43), Vector3(0.0, -0.204, 0.21), mat_wood_main)
	# Subtle front & side inlay trim + center gilded medallion
	_add_box(chair, Vector3(0.50, 0.024, 0.012), Vector3(0.0, -0.172, 0.422), mat_accent)
	_add_box(chair, Vector3(0.012, 0.022, 0.28), Vector3(-0.372, -0.172, 0.21), mat_accent)
	_add_box(chair, Vector3(0.012, 0.022, 0.28), Vector3(0.372, -0.172, 0.21), mat_accent)
	_add_torus(chair, 0.012, 0.019, Vector3(0.0, -0.172, 0.428), mat_brass, Vector3(90.0, 0.0, 0.0), 10)

	# 4 Sleek Tapered Parlor Legs Grounded Flush on Carpet Floor (y = -0.77)
	var leg_specs: Array[Dictionary] = [
		{"x": -0.340, "z": 0.385, "rake_x": 3.2, "rake_z": -2.8},
		{"x": 0.340, "z": 0.385, "rake_x": 3.2, "rake_z": 2.8},
		{"x": -0.340, "z": 0.025, "rake_x": -4.0, "rake_z": -2.2},
		{"x": 0.340, "z": 0.025, "rake_x": -4.0, "rake_z": 2.2}
	]
	for spec: Dictionary in leg_specs:
		var lx: float = float(spec["x"])
		var lz: float = float(spec["z"])
		var rx: float = float(spec["rake_x"])
		var rz: float = float(spec["rake_z"])
		var foot_x: float = lx + sin(deg_to_rad(rz)) * 0.14
		var foot_z: float = lz + sin(deg_to_rad(rx)) * 0.16
		# Rounded carved upper knee capital (no clunky sharp cubes!)
		_add_cyl(chair, 0.030, 0.028, 0.072, Vector3(lx, -0.195, lz), mat_wood_main, Vector3.ZERO, 10)
		_add_torus(chair, 0.020, 0.031, Vector3(lx, -0.232, lz), mat_aged, Vector3.ZERO, 10)
		# Sleek upper-to-lower tapered leg shaft
		var mid_x: float = (lx + foot_x) * 0.5
		var mid_z: float = (lz + foot_z) * 0.5
		_add_cyl(chair, 0.026, 0.015, 0.50, Vector3(mid_x, -0.482, mid_z), mat_wood_dark, Vector3(rx, 0.0, rz), 10)
		# Subtle refined brass ankle collar near upper third
		var ring_t: float = 0.28
		_add_torus(chair, 0.015, 0.024, Vector3(lerpf(lx, foot_x, ring_t), -0.360, lerpf(lz, foot_z, ring_t)), mat_aged, Vector3.ZERO, 10)
		# Polished Antique-Brass Sabot Foot Cap Resting Flush at y = -0.77
		_add_cyl(chair, 0.017, 0.021, 0.046, Vector3(foot_x, -0.747, foot_z), mat_brass, Vector3.ZERO, 10)
		_add_torus(chair, 0.015, 0.021, Vector3(foot_x, -0.724, foot_z), mat_aged, Vector3.ZERO, 10)

	# Delicate Turned Structural Stretchers (y = -0.58)
	var st_y: float = -0.58
	if stretcher_style == 0 or stretcher_style == 2:
		# Classic H-Stretcher with Slim Turned Rods & Central Brass Rosette
		for side_s: float in [-1.0, 1.0]:
			_add_cyl(chair, 0.011, 0.011, 0.36, Vector3(side_s * 0.35, st_y, 0.205), mat_wood_main, Vector3(90.0, 0.0, 0.0), 8)
		_add_cyl(chair, 0.012, 0.012, 0.70, Vector3(0.0, st_y, 0.205), mat_wood_main, Vector3(0.0, 0.0, 90.0), 8)
		_add_sphere(chair, 0.020, 0.024, Vector3(0.0, st_y, 0.205), mat_aged, Vector3.ZERO, 8)
	else:
		# Graceful X-Stretcher Meeting at a Turned Brass Finial
		_add_cyl(chair, 0.011, 0.011, 0.76, Vector3(0.0, st_y, 0.205), mat_wood_main, Vector3(0.0, 27.0, 90.0), 8)
		_add_cyl(chair, 0.011, 0.011, 0.76, Vector3(0.0, st_y, 0.205), mat_wood_main, Vector3(0.0, -27.0, 90.0), 8)
		_add_sphere(chair, 0.022, 0.032, Vector3(0.0, st_y + 0.012, 0.205), mat_brass, Vector3.ZERO, 8)


func _populate_chair_style_0_chesterfield(chair: Node3D) -> void:
	# STYLE 0: Classic Emerald Diamond-Tufted Leather Chesterfield Parlor Chair (Textured Leather + Sculpted Walnut Arch)
	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_leather: Material = _shared_mats["chair_emerald"]
	var mat_trim: Material = _shared_mats["chair_emerald_trim"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	_add_grounded_chair_base(chair, mat_walnut_pol, mat_walnut_dark, mat_aged, 0)

	# Plush Rounded Waterfall Seat Cushion Wrapped in Diamond-Tufted Emerald Leather
	_add_box(chair, Vector3(0.72, 0.082, 0.39), Vector3(0.0, -0.092, 0.205), mat_trim)
	_add_box(chair, Vector3(0.68, 0.068, 0.36), Vector3(0.0, -0.052, 0.205), mat_leather)
	_add_cyl(chair, 0.040, 0.040, 0.68, Vector3(0.0, -0.068, 0.388), mat_leather, Vector3(0.0, 0.0, 90.0), 10)
	_add_cyl(chair, 0.010, 0.010, 0.72, Vector3(0.0, -0.126, 0.405), mat_aged, Vector3(0.0, 0.0, 90.0), 8)

	# Contoured Arched Chesterfield Backrest (Smooth Textured Cushion Panel — Zero Blocky Primitives!)
	_add_box(chair, Vector3(0.74, 0.42, 0.088), Vector3(0.0, 0.13, 0.004), mat_leather, Vector3(-6.0, 0.0, 0.0))
	_add_cyl(chair, 0.37, 0.37, 0.086, Vector3(0.0, 0.22, -0.008), mat_leather, Vector3(84.0, 0.0, 0.0), 18)
	# Soft padded leather bolsters on left/right inner edges
	for side_s: float in [-1.0, 1.0]:
		_add_cyl(chair, 0.044, 0.044, 0.42, Vector3(side_s * 0.36, 0.13, 0.006), mat_trim, Vector3(-6.0, 0.0, 0.0), 10)

	# Continuous 13-Segment Sculpted Carved-Walnut Crown Arch & Brass Nailhead Piping
	var arch_segs: int = 13
	for i: int in range(arch_segs):
		var t: float = float(i) / float(arch_segs - 1)
		var ang: float = lerpf(-1.35, 1.35, t)
		var ax: float = sin(ang) * 0.405
		var ay: float = 0.215 + cos(ang) * 0.375
		var rot_z: float = -rad_to_deg(ang)
		var az: float = -0.008 - (ay - 0.215) * 0.105
		_add_box(chair, Vector3(0.105, 0.046, 0.102), Vector3(ax, ay, az), mat_walnut_pol, Vector3(-6.0, 0.0, rot_z))
		if i % 2 == 0:
			var nx: float = sin(ang) * 0.372
			var ny: float = 0.215 + cos(ang) * 0.342
			_add_sphere(chair, 0.007, 0.009, Vector3(nx, ny, az + 0.052), mat_brass, Vector3.ZERO, 6)
			_add_sphere(chair, 0.007, 0.009, Vector3(nx, ny, az - 0.052), mat_aged, Vector3.ZERO, 6)
	# Subtle gilded crest scroll at top apex
	_add_torus(chair, 0.018, 0.032, Vector3(0.0, 0.605, -0.048), mat_aged, Vector3(84.0, 0.0, 0.0), 10)

	# Graceful Swept Walnut Side Stiles & Leather-Cuffed Armrests
	for side_s: float in [-1.0, 1.0]:
		_add_cyl(chair, 0.028, 0.030, 0.40, Vector3(side_s * 0.398, 0.06, 0.012), mat_walnut_pol, Vector3(-6.0, 0.0, 0.0), 10)
		# Curved walnut armrest rail + plush emerald leather arm pad
		_add_box(chair, Vector3(0.056, 0.032, 0.36), Vector3(side_s * 0.385, 0.035, 0.195), mat_walnut_pol, Vector3(3.5, side_s * -3.5, 0.0))
		_add_box(chair, Vector3(0.062, 0.026, 0.22), Vector3(side_s * 0.384, 0.058, 0.190), mat_leather, Vector3(3.5, side_s * -3.5, 0.0))
		_add_sphere(chair, 0.032, 0.036, Vector3(side_s * 0.372, 0.025, 0.370), mat_walnut_pol, Vector3.ZERO, 8)
		# Sleek turned front arm post connecting cleanly into seat corner
		_add_cyl(chair, 0.020, 0.024, 0.175, Vector3(side_s * 0.362, -0.065, 0.365), mat_walnut_dark, Vector3(6.0, 0.0, 0.0), 10)
		_add_torus(chair, 0.016, 0.024, Vector3(side_s * 0.362, -0.055, 0.365), mat_aged, Vector3.ZERO, 8)


func _populate_chair_style_1_qajar_wingback(chair: Node3D) -> void:
	# STYLE 1: Royal Qajar Crimson Velvet Damask Wingback Armchair (Seamless Curved Arch + Sculpted Wing Cheeks)
	var mat_mahogany: Material = _shared_mats["mahogany"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_velvet: Material = _shared_mats["chair_crimson"]
	var mat_trim: Material = _shared_mats["chair_crimson_trim"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	_add_grounded_chair_base(chair, mat_mahogany, mat_walnut_dark, mat_brass, 1)

	# Plush Rounded Crimson Damask Seat Cushion with Antique Gold Piping
	_add_box(chair, Vector3(0.72, 0.088, 0.40), Vector3(0.0, -0.090, 0.205), mat_trim)
	_add_box(chair, Vector3(0.68, 0.068, 0.36), Vector3(0.0, -0.048, 0.205), mat_velvet)
	_add_cyl(chair, 0.042, 0.042, 0.68, Vector3(0.0, -0.064, 0.390), mat_velvet, Vector3(0.0, 0.0, 90.0), 10)
	_add_box(chair, Vector3(0.73, 0.012, 0.415), Vector3(0.0, -0.132, 0.205), mat_aged)

	# Seamless Tall Sculpted Crimson Damask Backrest (Rounded Crown Silhouette — No Disconnected Cylinders!)
	_add_box(chair, Vector3(0.70, 0.48, 0.086), Vector3(0.0, 0.16, 0.002), mat_velvet, Vector3(-6.0, 0.0, 0.0))
	_add_cyl(chair, 0.35, 0.35, 0.084, Vector3(0.0, 0.36, -0.020), mat_velvet, Vector3(84.0, 0.0, 0.0), 18)

	# Smooth Continuous Mahogany Crown Arch Wrapping the Backrest
	var crown_segs: int = 11
	for i: int in range(crown_segs):
		var t: float = float(i) / float(crown_segs - 1)
		var ang: float = lerpf(-1.42, 1.42, t)
		var cx: float = sin(ang) * 0.380
		var cy: float = 0.360 + cos(ang) * 0.365
		var cz: float = -0.020 - (cy - 0.360) * 0.105
		_add_box(chair, Vector3(0.11, 0.042, 0.098), Vector3(cx, cy, cz), mat_mahogany, Vector3(-6.0, 0.0, -rad_to_deg(ang)))

	# Regal Persian Shamseh Brass Crest Medallion Perched Cleanly on Crown Apex
	_add_torus(chair, 0.022, 0.038, Vector3(0.0, 0.742, -0.060), mat_brass, Vector3(84.0, 0.0, 0.0), 12)
	_add_sphere(chair, 0.020, 0.026, Vector3(0.0, 0.742, -0.058), mat_trim, Vector3.ZERO, 8)
	_add_sphere(chair, 0.012, 0.026, Vector3(0.0, 0.785, -0.064), mat_brass, Vector3.ZERO, 8)

	# Gracefully Contoured Velvet Wing Cheeks, Brass Stud Piping & Rolled Velvet Armrests
	for side_s: float in [-1.0, 1.0]:
		# Mahogany vertical rear stiles
		_add_cyl(chair, 0.026, 0.028, 0.50, Vector3(side_s * 0.376, 0.14, 0.004), mat_mahogany, Vector3(-6.0, 0.0, 0.0), 10)
		# Tapered curved velvet wing cheek flowing smoothly from crown down into armrest
		_add_box(chair, Vector3(0.056, 0.34, 0.17), Vector3(side_s * 0.368, 0.25, 0.088), mat_velvet, Vector3(-6.0, side_s * -10.0, 0.0))
		_add_cyl(chair, 0.032, 0.026, 0.36, Vector3(side_s * 0.360, 0.25, 0.168), mat_trim, Vector3(-6.0, 0.0, 0.0), 10)
		# Delicate brass nailhead studs along front edge of each wing
		for s_i: int in range(5):
			_add_sphere(chair, 0.0065, 0.008, Vector3(side_s * 0.354, 0.12 + float(s_i) * 0.062, 0.194 - float(s_i) * 0.006), mat_brass, Vector3.ZERO, 6)
		# Plush rolled velvet armrests with carved mahogany scroll knuckles
		_add_cyl(chair, 0.042, 0.042, 0.34, Vector3(side_s * 0.368, 0.032, 0.215), mat_velvet, Vector3(90.0, 0.0, 0.0), 12)
		_add_torus(chair, 0.024, 0.042, Vector3(side_s * 0.368, 0.032, 0.382), mat_mahogany, Vector3(90.0, 0.0, 0.0), 10)
		_add_sphere(chair, 0.026, 0.026, Vector3(side_s * 0.368, 0.032, 0.388), mat_aged, Vector3.ZERO, 8)
		_add_box(chair, Vector3(0.048, 0.15, 0.32), Vector3(side_s * 0.366, -0.058, 0.205), mat_trim)


func _populate_chair_style_2_isfahan_medallion(chair: Node3D) -> void:
	# STYLE 2: Isfahan Peacock-Teal Brocade Oval Medallion Salon Chair (Proportioned Sculpted Frame + Floral Medallion Texture)
	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_teal: Material = _shared_mats["chair_cobalt"]
	var mat_trim: Material = _shared_mats["chair_cobalt_trim"]
	var mat_khatam: Material = _shared_mats["khatam_inlay"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	_add_grounded_chair_base(chair, mat_walnut_pol, mat_walnut_dark, mat_khatam, 2)

	# Contoured Rounded Brocade Seat Cushion with Antique Gold Piping
	_add_box(chair, Vector3(0.70, 0.076, 0.38), Vector3(0.0, -0.094, 0.205), mat_trim)
	_add_box(chair, Vector3(0.66, 0.064, 0.35), Vector3(0.0, -0.056, 0.205), mat_teal)
	_add_cyl(chair, 0.036, 0.036, 0.66, Vector3(0.0, -0.072, 0.382), mat_teal, Vector3(0.0, 0.0, 90.0), 10)
	_add_cyl(chair, 0.009, 0.009, 0.70, Vector3(0.0, -0.128, 0.398), mat_aged, Vector3(0.0, 0.0, 90.0), 8)

	# Gracefully Proportioned Vertical-Oval Medallion Backrest (Upholstered in Isfahan Peacock-Teal Brocade!)
	var med_y: float = 0.275
	var med_z: float = -0.012
	var med_node: Node3D = Node3D.new()
	med_node.position = Vector3(0.0, med_y, med_z)
	med_node.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	med_node.scale = Vector3(1.06, 1.18, 1.0)
	chair.add_child(med_node)

	# Textured cushioned brocade medallion disc (clean flat-domed profile — no weird bulgy sphere!)
	_add_cyl(med_node, 0.295, 0.295, 0.068, Vector3.ZERO, mat_teal, Vector3(90.0, 0.0, 0.0), 20)
	# Sleek beveled carved-walnut oval outer frame + delicate inner brass fillet ring
	_add_torus(med_node, 0.285, 0.330, Vector3.ZERO, mat_walnut_pol, Vector3(90.0, 0.0, 0.0), 20)
	_add_torus(med_node, 0.274, 0.288, Vector3(0.0, 0.0, 0.032), mat_brass, Vector3(90.0, 0.0, 0.0), 18)
	_add_torus(med_node, 0.274, 0.288, Vector3(0.0, 0.0, -0.032), mat_aged, Vector3(90.0, 0.0, 0.0), 18)
	# Refined Khatam-Kari crest ribbon atop the oval
	_add_box(med_node, Vector3(0.145, 0.048, 0.042), Vector3(0.0, 0.335, 0.0), mat_walnut_pol)
	_add_box(med_node, Vector3(0.110, 0.030, 0.048), Vector3(0.0, 0.335, 0.0), mat_khatam)
	_add_sphere(med_node, 0.015, 0.022, Vector3(0.0, 0.368, 0.0), mat_brass, Vector3.ZERO, 8)

	# Sculpted Lower Walnut Back-Support Posts Anchoring Medallion into Seat Frame
	for side_s: float in [-1.0, 1.0]:
		_add_cyl(chair, 0.022, 0.026, 0.24, Vector3(side_s * 0.26, -0.03, 0.018), mat_walnut_dark, Vector3(-6.0, 0.0, side_s * 16.0), 10)
		# Slender Curved Louis-Style Walnut Armrests with Padded Teal Brocade Cuffs
		_add_box(chair, Vector3(0.048, 0.028, 0.34), Vector3(side_s * 0.368, 0.040, 0.195), mat_walnut_pol, Vector3(4.0, side_s * -4.0, 0.0))
		_add_box(chair, Vector3(0.056, 0.024, 0.20), Vector3(side_s * 0.366, 0.062, 0.190), mat_teal, Vector3(4.0, side_s * -4.0, 0.0))
		_add_cyl(chair, 0.018, 0.022, 0.19, Vector3(side_s * 0.354, -0.058, 0.355), mat_walnut_pol, Vector3(12.0, 0.0, 0.0), 10)
		_add_sphere(chair, 0.024, 0.028, Vector3(side_s * 0.360, 0.032, 0.362), mat_brass, Vector3.ZERO, 8)


func _populate_chair_style_3_orosi_lattice(chair: Node3D) -> void:
	# STYLE 3: Warm Cognac Quilted-Leather & Carved Walnut Persian Salon Armchair (Sleek Crown Rail + Khatam Inlay)
	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_mid: Material = _shared_mats["walnut_mid"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_cognac: Material = _shared_mats["chair_amber"]
	var mat_trim: Material = _shared_mats["chair_amber_trim"]
	var mat_khatam: Material = _shared_mats["khatam_inlay"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	_add_grounded_chair_base(chair, mat_walnut_pol, mat_walnut_dark, mat_khatam, 3)

	# Plush Quilted Cognac Saddle-Leather Seat Cushion with Brass-Studded Skirt
	_add_box(chair, Vector3(0.72, 0.082, 0.39), Vector3(0.0, -0.092, 0.205), mat_trim)
	_add_box(chair, Vector3(0.68, 0.066, 0.36), Vector3(0.0, -0.052, 0.205), mat_cognac)
	_add_cyl(chair, 0.038, 0.038, 0.68, Vector3(0.0, -0.068, 0.386), mat_cognac, Vector3(0.0, 0.0, 90.0), 10)
	for b_i: int in range(-4, 5):
		_add_sphere(chair, 0.0065, 0.008, Vector3(float(b_i) * 0.075, -0.118, 0.402), mat_brass, Vector3.ZERO, 6)

	# Upholstered Quilted Cognac Backrest Inset Inside Carved Walnut Gallery Frame
	_add_box(chair, Vector3(0.66, 0.46, 0.074), Vector3(0.0, 0.23, -0.008), mat_cognac, Vector3(-6.0, 0.0, 0.0))
	_add_box(chair, Vector3(0.68, 0.022, 0.082), Vector3(0.0, 0.005, 0.016), mat_walnut_mid, Vector3(-6.0, 0.0, 0.0))

	# Clean Sculpted Side Stiles with Turned Antique-Brass Corner Finials
	for side_s: float in [-1.0, 1.0]:
		_add_cyl(chair, 0.026, 0.028, 0.64, Vector3(side_s * 0.355, 0.19, -0.004), mat_walnut_pol, Vector3(-6.0, 0.0, 0.0), 10)
		_add_torus(chair, 0.018, 0.030, Vector3(side_s * 0.355, 0.505, -0.038), mat_aged, Vector3(-6.0, 0.0, 0.0), 10)
		_add_sphere(chair, 0.024, 0.038, Vector3(side_s * 0.355, 0.535, -0.042), mat_brass, Vector3.ZERO, 8)
		# Sleek Carved Walnut Armrests with Quilted Cognac Leather Cuffs & Baluster Supports
		_add_box(chair, Vector3(0.056, 0.030, 0.36), Vector3(side_s * 0.372, 0.038, 0.195), mat_walnut_pol, Vector3(3.0, side_s * -3.0, 0.0))
		_add_box(chair, Vector3(0.062, 0.024, 0.22), Vector3(side_s * 0.370, 0.060, 0.190), mat_cognac, Vector3(3.0, side_s * -3.0, 0.0))
		_add_cyl(chair, 0.020, 0.024, 0.18, Vector3(side_s * 0.358, -0.062, 0.360), mat_walnut_mid, Vector3(6.0, 0.0, 0.0), 10)
		_add_torus(chair, 0.016, 0.024, Vector3(side_s * 0.358, -0.052, 0.360), mat_brass, Vector3.ZERO, 8)

	# Gracefully Arched Carved Walnut Crown Rail with Centered Khatam-Kari Inlay Panel
	var crest_segs: int = 9
	for ci: int in range(crest_segs):
		var ct: float = float(ci) / float(crest_segs - 1)
		var cang: float = lerpf(-0.88, 0.88, ct)
		var cx: float = sin(cang) * 0.43
		var cy: float = 0.23 + cos(cang) * 0.30
		var cz: float = -0.008 - (cy - 0.23) * 0.105
		_add_box(chair, Vector3(0.115, 0.048, 0.082), Vector3(cx, cy, cz), mat_walnut_pol, Vector3(-6.0, 0.0, -rad_to_deg(cang) * 0.58))
	_add_box(chair, Vector3(0.28, 0.032, 0.088), Vector3(0.0, 0.525, -0.038), mat_khatam, Vector3(-6.0, 0.0, 0.0))
	_add_torus(chair, 0.016, 0.026, Vector3(0.0, 0.525, 0.008), mat_brass, Vector3(84.0, 0.0, 0.0), 10)


func _populate_chair_style_4_termeh_armchair(chair: Node3D) -> void:
	# STYLE 4: Royal Yazd Termeh Silk Brocade & Turned Mahogany Parlor Armchair (Arched Crown + Turned Balusters)
	var mat_mahogany: Material = _shared_mats["mahogany"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_ruby: Material = _shared_mats["chair_ruby"]
	var mat_trim: Material = _shared_mats["chair_ruby_trim"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]

	_add_grounded_chair_base(chair, mat_mahogany, mat_walnut_dark, mat_brass, 0)

	# Plush Rounded Termeh Ruby Seat Cushion with Antique Gold Piping
	_add_box(chair, Vector3(0.72, 0.082, 0.39), Vector3(0.0, -0.092, 0.205), mat_trim)
	_add_box(chair, Vector3(0.68, 0.068, 0.36), Vector3(0.0, -0.052, 0.205), mat_ruby)
	_add_cyl(chair, 0.040, 0.040, 0.68, Vector3(0.0, -0.068, 0.388), mat_ruby, Vector3(0.0, 0.0, 90.0), 10)
	_add_cyl(chair, 0.010, 0.010, 0.72, Vector3(0.0, -0.126, 0.405), mat_aged, Vector3(0.0, 0.0, 90.0), 8)

	# Contoured Termeh Ruby Silk Brocade Backrest
	_add_box(chair, Vector3(0.72, 0.44, 0.084), Vector3(0.0, 0.14, 0.002), mat_ruby, Vector3(-6.0, 0.0, 0.0))
	_add_cyl(chair, 0.36, 0.36, 0.082, Vector3(0.0, 0.28, -0.014), mat_ruby, Vector3(84.0, 0.0, 0.0), 18)

	# Continuous Carved Mahogany Arch with Brass Finials
	var arch_segs: int = 11
	for i: int in range(arch_segs):
		var t: float = float(i) / float(arch_segs - 1)
		var ang: float = lerpf(-1.38, 1.38, t)
		var ax: float = sin(ang) * 0.395
		var ay: float = 0.280 + cos(ang) * 0.360
		var az: float = -0.014 - (ay - 0.280) * 0.105
		_add_box(chair, Vector3(0.11, 0.044, 0.096), Vector3(ax, ay, az), mat_mahogany, Vector3(-6.0, 0.0, -rad_to_deg(ang)))
		if i % 2 == 0:
			var nx: float = sin(ang) * 0.365
			var ny: float = 0.280 + cos(ang) * 0.330
			_add_sphere(chair, 0.007, 0.009, Vector3(nx, ny, az + 0.048), mat_brass, Vector3.ZERO, 6)

	_add_torus(chair, 0.020, 0.034, Vector3(0.0, 0.655, -0.052), mat_brass, Vector3(84.0, 0.0, 0.0), 10)
	_add_sphere(chair, 0.014, 0.024, Vector3(0.0, 0.690, -0.056), mat_aged, Vector3.ZERO, 8)

	# Swept Mahogany Stiles & Termeh Padded Armrests
	for side_s: float in [-1.0, 1.0]:
		_add_cyl(chair, 0.026, 0.028, 0.44, Vector3(side_s * 0.385, 0.08, 0.008), mat_mahogany, Vector3(-6.0, 0.0, 0.0), 10)
		_add_box(chair, Vector3(0.054, 0.030, 0.35), Vector3(side_s * 0.378, 0.036, 0.195), mat_mahogany, Vector3(3.5, side_s * -3.5, 0.0))
		_add_box(chair, Vector3(0.060, 0.024, 0.22), Vector3(side_s * 0.376, 0.058, 0.190), mat_ruby, Vector3(3.5, side_s * -3.5, 0.0))
		_add_sphere(chair, 0.030, 0.034, Vector3(side_s * 0.368, 0.025, 0.368), mat_mahogany, Vector3.ZERO, 8)
		_add_cyl(chair, 0.018, 0.022, 0.18, Vector3(side_s * 0.358, -0.062, 0.360), mat_walnut_dark, Vector3(6.0, 0.0, 0.0), 10)
		_add_torus(chair, 0.015, 0.022, Vector3(side_s * 0.358, -0.052, 0.360), mat_brass, Vector3.ZERO, 8)


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

	var center_stack_mats: Array[Material] = _pick_random_book_cover_mats(3)
	_build_horizontal_book(bc, Vector3(0.0, 0.582, 0.02), Vector3(0.32, 0.042, 0.20), center_stack_mats[0], 2.0)
	_build_horizontal_book(bc, Vector3(0.0, 0.624, 0.02), Vector3(0.28, 0.038, 0.18), center_stack_mats[1], -3.0)
	_hero_book_pivot = _build_horizontal_book(bc, Vector3(0.0, 0.660, 0.02), Vector3(0.24, 0.034, 0.16), center_stack_mats[2], 1.5)
	if _hero_book_pivot:
		_hero_book_pivot.name = "HeroEstanteBookPivot"
		_bake_interactive_prop_branch(_hero_book_pivot, "BakedHeroEstanteBookMesh")
		_register_interactive_prop("estante_books", _hero_book_pivot, Vector3.ZERO, 0.19)
	# Small brass finial figurine perched neatly beside the center book stack
	_add_cyl(bc, 0.022, 0.030, 0.018, Vector3(0.17, 0.570, 0.08), mat_brass, Vector3.ZERO, 10)
	_add_sphere(bc, 0.030, 0.038, Vector3(0.17, 0.596, 0.08), mat_brass, Vector3.ZERO, 10)
	_add_cyl(bc, 0.010, 0.018, 0.022, Vector3(0.17, 0.624, 0.08), mat_aged_brass, Vector3.ZERO, 10)
	_add_sphere(bc, 0.011, 0.018, Vector3(0.17, 0.642, 0.08), mat_brass, Vector3.ZERO, 8)

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

	# Warm Recessed Shelf Cove-Lights, Persian Brass Samovar, Overhead Stained-Glass Pendants, Fairy Garland & Framed Art
	_build_bookcase_cove_lights_and_decor(bc)

	# Bake the entire 3-Bay Bookcase, Books, Curios, Cove Lights, Pendants, Fairy Garland, Wall Art & Sconces into 1 MeshInstance3D!
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

	_bake_interactive_prop_branch(plaque, "BakedCafeFekrPlaqueMesh")
	_register_interactive_prop("estante_sign", plaque, Vector3(0.0, 0.0, 0.03), 0.36)


func _pick_random_book_cover_mats(count: int) -> Array[Material]:
	var pool: Array[Material] = [
		_shared_mats["book_hafez"],
		_shared_mats["book_shahnameh"],
		_shared_mats["book_golestan"],
		_shared_mats["book_abru_cobalt"],
		_shared_mats["book_abru_amber"],
		_shared_mats["book_shamseh_ruby"],
		_shared_mats["book_shamseh_emerald"],
		_shared_mats["book_shamseh_lapis"],
		_shared_mats["book_shamseh_tan"],
		_shared_mats["book_cloth_ochre"],
		_shared_mats["book_cloth_teal"],
		_shared_mats["book_cloth_crimson"],
		_shared_mats["book_cloth_olive"],
		_shared_mats["book_filigree_plum"],
		_shared_mats["book_filigree_saffron"],
		_shared_mats["book_filigree_copper"],
		_shared_mats["book_filigree_teal"],
		_shared_mats["book_filigree_ivory"]
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var n: int = pool.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Material = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var result: Array[Material] = []
	for k: int in range(count):
		result.append(pool[k % n])
	return result


func _populate_book_row(parent: Node3D, x_start: float, x_end: float, y_shelf: float, z_pos: float, count: int, h_min: float, h_max: float) -> void:
	var book_mats: Array[Material] = [
		_shared_mats["book_red"],
		_shared_mats["book_green"],
		_shared_mats["book_navy"],
		_shared_mats["book_brown"],
		_shared_mats["book_burgundy"],
		_shared_mats["book_cloth_ochre"],
		_shared_mats["book_cloth_teal"],
		_shared_mats["book_cloth_crimson"],
		_shared_mats["book_cloth_olive"],
		_shared_mats["book_shamseh_ruby"],
		_shared_mats["book_shamseh_emerald"],
		_shared_mats["book_shamseh_lapis"],
		_shared_mats["book_shamseh_tan"],
		_shared_mats["book_hafez"],
		_shared_mats["book_shahnameh"],
		_shared_mats["book_golestan"],
		_shared_mats["book_abru_cobalt"],
		_shared_mats["book_abru_amber"],
		_shared_mats["book_filigree_plum"],
		_shared_mats["book_filigree_saffron"],
		_shared_mats["book_filigree_copper"],
		_shared_mats["book_filigree_teal"],
		_shared_mats["book_filigree_ivory"]
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var mat_brass: Material = _shared_mats["aged_brass"]
	var total_w: float = x_end - x_start
	var step_x: float = total_w / float(maxi(count, 1))
	var prev_mat_idx: int = -1

	for i: int in range(count):
		var bx: float = x_start + (float(i) + 0.5) * step_x
		var bw: float = step_x * rng.randf_range(0.84, 0.92)
		var bh: float = lerpf(h_min, h_max, rng.randf())
		var bd: float = rng.randf_range(0.155, 0.195)
		var mat_idx: int = rng.randi_range(0, book_mats.size() - 1)
		if mat_idx == prev_mat_idx:
			mat_idx = (mat_idx + 1 + rng.randi_range(0, book_mats.size() - 2)) % book_mats.size()
		prev_mat_idx = mat_idx
		var b_mat: Material = book_mats[mat_idx]
		var tilt_z: float = 0.0
		if i == count - 1 and count >= 5:
			tilt_z = 7.5
		_add_box(parent, Vector3(bw, bh, bd), Vector3(bx, y_shelf + bh * 0.5, z_pos), b_mat, Vector3(0.0, 0.0, tilt_z))
		_add_box(parent, Vector3(bw * 0.92, 0.008, 0.006), Vector3(bx, y_shelf + bh * 0.78, z_pos + bd * 0.5 + 0.002), mat_brass, Vector3(0.0, 0.0, tilt_z))
		_add_box(parent, Vector3(bw * 0.92, 0.008, 0.006), Vector3(bx, y_shelf + bh * 0.24, z_pos + bd * 0.5 + 0.002), mat_brass, Vector3(0.0, 0.0, tilt_z))


func _build_horizontal_book(parent: Node3D, pos: Vector3, size: Vector3, mat_cover: Material, yaw_deg: float) -> Node3D:
	var b_node: Node3D = Node3D.new()
	b_node.position = pos
	b_node.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(b_node)
	_add_box(b_node, size, Vector3.ZERO, mat_cover)
	_add_box(b_node, Vector3(size.x * 0.94, size.y * 0.74, size.z * 0.92), Vector3(0.0, 0.0, 0.004), _shared_mats["book_pages"])
	_add_box(b_node, Vector3(size.x * 0.98, size.y, 0.012), Vector3(0.0, 0.0, size.z * 0.5), mat_cover)
	_add_box(b_node, Vector3(0.010, size.y * 0.92, 0.016), Vector3(-size.x * 0.30, 0.0, size.z * 0.5), _shared_mats["aged_brass"])
	_add_box(b_node, Vector3(0.010, size.y * 0.92, 0.016), Vector3(size.x * 0.30, 0.0, size.z * 0.5), _shared_mats["aged_brass"])
	return b_node


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
	var rings_pivot: Node3D = Node3D.new()
	rings_pivot.name = "ArmillaryRingsPivot"
	rings_pivot.position = Vector3(0.0, center_y, 0.0)
	arm.add_child(rings_pivot)
	_armillary_rings_pivot = rings_pivot

	_add_torus(rings_pivot, 0.145, 0.162, Vector3.ZERO, mat_brass, Vector3(90.0, 12.0, 0.0), 16)
	_add_torus(rings_pivot, 0.148, 0.164, Vector3.ZERO, mat_aged_brass, Vector3(8.0, 0.0, -18.0), 16)
	_add_torus(rings_pivot, 0.122, 0.142, Vector3.ZERO, mat_brass, Vector3(62.0, 28.0, 15.0), 14)
	_add_torus(rings_pivot, 0.118, 0.132, Vector3.ZERO, mat_aged_brass, Vector3(90.0, -52.0, 22.0), 14)
	_add_torus(rings_pivot, 0.095, 0.108, Vector3.ZERO, mat_brass, Vector3(35.0, 45.0, -25.0), 12)

	_add_sphere(rings_pivot, 0.074, 0.148, Vector3.ZERO, _shared_mats["book_ochre"], Vector3(0.0, 0.0, -23.5), 10)
	_add_torus(rings_pivot, 0.072, 0.078, Vector3.ZERO, mat_brass, Vector3(0.0, 0.0, -23.5), 12)
	_add_cyl(rings_pivot, 0.005, 0.005, 0.36, Vector3.ZERO, mat_brass, Vector3(0.0, 0.0, -23.5), 8)
	_add_sphere(rings_pivot, 0.014, 0.028, Vector3(0.068, 0.165, 0.0), mat_brass, Vector3.ZERO, 8)

	_bake_interactive_prop_branch(rings_pivot, "BakedArmillaryRingsMesh")
	_bake_interactive_prop_branch(arm, "BakedArmillaryBaseMesh")
	_register_interactive_prop("estante_armillary", arm, Vector3(0.0, 0.24, 0.0), 0.22)


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

	_bake_interactive_prop_branch(bust, "BakedMarbleBustMesh")
	_register_interactive_prop("estante_bust", bust, Vector3(0.0, 0.20, 0.0), 0.19)


func _build_vintage_shelf_clock(parent: Node3D, pos: Vector3, mat_brass: Material, mat_aged_brass: Material, mat_dial: Material, mat_dark: Material) -> void:
	var clk: Node3D = Node3D.new()
	clk.name = "VintageShelfClock"
	clk.position = pos
	parent.add_child(clk)

	_add_box(clk, Vector3(0.16, 0.026, 0.09), Vector3(0.0, 0.013, 0.0), mat_aged_brass)
	_add_cyl(clk, 0.088, 0.088, 0.075, Vector3(0.0, 0.105, 0.0), mat_aged_brass, Vector3(90.0, 0.0, 0.0), 16)
	_add_torus(clk, 0.078, 0.092, Vector3(0.0, 0.105, 0.038), mat_brass, Vector3(90.0, 0.0, 0.0), 16)
	_add_cyl(clk, 0.076, 0.076, 0.010, Vector3(0.0, 0.105, 0.036), mat_dial, Vector3(90.0, 0.0, 0.0), 16)
	_add_cyl(clk, 0.016, 0.024, 0.028, Vector3(0.0, 0.202, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_torus(clk, 0.022, 0.030, Vector3(0.0, 0.228, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 12)

	var hands_pivot: Node3D = Node3D.new()
	hands_pivot.name = "ClockHandsPivot"
	hands_pivot.position = Vector3(0.0, 0.105, 0.044)
	clk.add_child(hands_pivot)
	_clock_hands_pivot = hands_pivot
	_add_sphere(hands_pivot, 0.008, 0.012, Vector3.ZERO, mat_dark, Vector3.ZERO, 8)
	_add_box(hands_pivot, Vector3(0.006, 0.048, 0.006), Vector3(-0.012, 0.017, 0.0), mat_dark, Vector3(0.0, 0.0, 28.0))
	_add_box(hands_pivot, Vector3(0.005, 0.062, 0.006), Vector3(0.018, 0.013, 0.0), mat_dark, Vector3(0.0, 0.0, -48.0))

	_bake_interactive_prop_branch(hands_pivot, "BakedClockHandsMesh")
	_bake_interactive_prop_branch(clk, "BakedVintageClockMesh")
	_register_interactive_prop("estante_clock", clk, Vector3(0.0, 0.12, 0.02), 0.16)


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

	# Single 2-triangle unshaded Persian window vista (swapped randomly across 5 scenes per match!)
	_add_plane(win_root, Vector2(0.76, 1.50), Vector3(0.0, 0.01, -0.095), _shared_mats["window_twilight_view"], Vector3(90.0, 0.0, 0.0))

	# Upgraded Architectural Carved Walnut Casing, Deep Reveals, Sill & Corbel Brackets
	for side_s: float in [-1.0, 1.0]:
		# Outer carved jamb + inner stepped molding reveal + brass casing rosette
		_add_box(win_root, Vector3(0.072, 1.30, 0.135), Vector3(side_s * 0.405, -0.10, 0.0), mat_walnut_dark)
		_add_box(win_root, Vector3(0.028, 1.24, 0.155), Vector3(side_s * 0.368, -0.11, 0.012), mat_walnut_pol)
		_add_box(win_root, Vector3(0.014, 1.18, 0.012), Vector3(side_s * 0.415, -0.11, 0.070), mat_aged_brass)
		# Carved walnut sill corbel bracket underneath sill
		_add_box(win_root, Vector3(0.062, 0.082, 0.125), Vector3(side_s * 0.345, -0.822, 0.035), mat_walnut_mid)
		_add_sphere(win_root, 0.026, 0.032, Vector3(side_s * 0.345, -0.848, 0.088), mat_aged_brass, Vector3.ZERO, 8)
	# Deep Molded Walnut Window Sill & Brass Lip Inlay
	_add_box(win_root, Vector3(0.92, 0.056, 0.185), Vector3(0.0, -0.752, 0.030), mat_walnut_pol)
	_add_box(win_root, Vector3(0.88, 0.026, 0.155), Vector3(0.0, -0.785, 0.018), mat_walnut_dark)
	_add_box(win_root, Vector3(0.86, 0.008, 0.010), Vector3(0.0, -0.728, 0.118), mat_brass)
	# Carved Walnut & Brass Transom Bar Separating Upper Orosi Stained-Glass Arch from Hinged Casement Doors
	_add_box(win_root, Vector3(0.76, 0.044, 0.115), Vector3(0.0, 0.285, 0.012), mat_walnut_pol)
	_add_box(win_root, Vector3(0.74, 0.010, 0.012), Vector3(0.0, 0.285, 0.072), mat_aged_brass)
	# Subtle walnut arch spandrels masking the upper corners of the rectangular vista plane cleanly behind the arch
	_add_box(win_root, Vector3(0.30, 0.15, 0.095), Vector3(-0.35, 0.74, -0.02), mat_walnut_dark, Vector3(0.0, 0.0, 42.0))
	_add_box(win_root, Vector3(0.30, 0.15, 0.095), Vector3(0.35, 0.74, -0.02), mat_walnut_dark, Vector3(0.0, 0.0, -42.0))
	# Rich 11-Segment Arched Crown Molding + Inner Brass Arch Fillet + Apex Keystone
	for a_i: int in range(11):
		var at: float = float(a_i) / 10.0
		var aang: float = lerpf(-1.46, 1.46, at)
		var ax: float = sin(aang) * 0.402
		var ay: float = 0.415 + cos(aang) * 0.372
		var rot_z: float = -rad_to_deg(aang)
		_add_box(win_root, Vector3(0.125, 0.068, 0.140), Vector3(ax, ay, 0.004), mat_walnut_dark, Vector3(0.0, 0.0, rot_z))
		_add_box(win_root, Vector3(0.115, 0.020, 0.155), Vector3(sin(aang) * 0.370, 0.415 + cos(aang) * 0.340, 0.014), mat_walnut_pol, Vector3(0.0, 0.0, rot_z))
	_add_box(win_root, Vector3(0.078, 0.088, 0.162), Vector3(0.0, 0.790, 0.016), mat_walnut_pol)
	_add_box(win_root, Vector3(0.042, 0.042, 0.016), Vector3(0.0, 0.790, 0.096), mat_brass, Vector3(0.0, 0.0, 45.0))

	# Upper Fixed Transom Mullions ONLY (lower window opening stays 100% clear for the hinged glass doors!)
	for mx: float in [-0.18, 0.0, 0.18]:
		_add_box(win_root, Vector3(0.018, 0.44, 0.032), Vector3(mx, 0.51, 0.012), mat_walnut_dark)
	_add_box(win_root, Vector3(0.68, 0.018, 0.032), Vector3(0.0, 0.48, 0.012), mat_walnut_dark)

	# Glowing Stained-Glass Transom Diamonds Inside the Window Arch (0ms unshaded emissive)
	_build_window_stained_glass_transom(win_root)

	# Interactive Hinged Wooden & Translucent Glass Double Casement Doors (Tap Window to Swing Open/Closed!)
	_window_door_left = _build_window_casement_door(win_root, true)
	_window_door_right = _build_window_casement_door(win_root, false)
	_register_interactive_prop("window_doors", win_root, Vector3(0.0, -0.14, 0.06), 0.52)

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
	_add_cyl(lamp_l, 0.115, 0.225, 0.21, Vector3(0.0, shade_y, 0.0), _shared_mats["left_lamp_shade"], Vector3.ZERO, 18)
	_add_torus(lamp_l, 0.108, 0.120, Vector3(0.0, shade_y + 0.105, 0.0), mat_brass, Vector3.ZERO, 16)
	_add_torus(lamp_l, 0.218, 0.230, Vector3(0.0, shade_y - 0.105, 0.0), mat_brass, Vector3.ZERO, 18)
	_add_cyl(lamp_l, 0.008, 0.018, 0.036, Vector3(0.0, shade_y + 0.126, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_sphere(lamp_l, 0.014, 0.024, Vector3(0.0, shade_y + 0.148, 0.0), mat_brass, Vector3.ZERO, 8)
	_bake_interactive_prop_branch(lamp_l, "BakedLeftBrassLampMesh")
	_register_interactive_prop("left_table_lamp", lamp_l, Vector3(0.0, 0.26, 0.0), 0.23)

	# Isfahan Turquoise Mina-Kari Amphora Vase resting beside the Left Brass Lamp (baked into LeftLoungeMesh!)
	_build_minakari_vase(side_tbl_l, Vector3(-0.18, 0.14, 0.12))

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

	var side_stack_mats: Array[Material] = _pick_random_book_cover_mats(2)
	_build_horizontal_book(side_tbl_r, Vector3(0.09, 0.122, 0.08), Vector3(0.24, 0.044, 0.17), side_stack_mats[0], -16.0)
	_build_horizontal_book(side_tbl_r, Vector3(0.09, 0.164, 0.08), Vector3(0.22, 0.040, 0.16), side_stack_mats[1], -10.0)
	_build_potted_broadleaf_plant(side_tbl_r, Vector3(0.14, 0.10, -0.10), 1.0, true)
	_build_mini_brass_candle_lantern(side_tbl_r, Vector3(-0.14, 0.10, -0.11))

	# Traditional Persian Tar Lute leaning gracefully in the right corner (baked into RightLoungeMesh!)
	_build_persian_tar_instrument(right_area, Vector3(1.38, -0.76, -2.20))

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


# ============================================================================
# 6. MOBILE-OPTIMIZED BAKED PARLOR PROPS (RUG, PENDANTS, FAIRY LIGHTS, TEA)
# ============================================================================

func _build_table_persian_tea_tray(parent: Node3D, pos: Vector3) -> void:
	# Authentic Persian estekan tea glass + brass saucer + sugar bowl on back-right walnut corner
	var tray: Node3D = Node3D.new()
	tray.name = "PersianTeaTray"
	tray.position = pos
	tray.rotation_degrees = Vector3(0.0, -24.0, 0.0)
	parent.add_child(tray)

	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_porc: Material = _shared_mats["porcelain"]
	var mat_tea: Material = _shared_mats["tea_amber"]

	# Scalloped Brass Serving Tray
	_add_cyl(tray, 0.095, 0.088, 0.008, Vector3(0.0, 0.004, 0.0), mat_aged, Vector3.ZERO, 12)
	_add_torus(tray, 0.088, 0.098, Vector3(0.0, 0.010, 0.0), mat_brass, Vector3.ZERO, 12)

	# Estekan Tea Glass & Porcelain Saucer (left side of tray)
	var gx: float = -0.026
	var gz: float = 0.014
	_add_cyl(tray, 0.036, 0.024, 0.007, Vector3(gx, 0.012, gz), mat_porc, Vector3.ZERO, 10)
	_add_torus(tray, 0.032, 0.037, Vector3(gx, 0.016, gz), mat_brass, Vector3.ZERO, 10)
	# Waist-pinched Estekan glass filled with glowing amber Persian tea
	_add_cyl(tray, 0.019, 0.024, 0.026, Vector3(gx, 0.028, gz), mat_tea, Vector3.ZERO, 10)
	_add_cyl(tray, 0.025, 0.019, 0.030, Vector3(gx, 0.056, gz), mat_tea, Vector3.ZERO, 10)
	_add_torus(tray, 0.023, 0.026, Vector3(gx, 0.071, gz), mat_brass, Vector3.ZERO, 10)
	# Tiny brass teaspoon resting on saucer
	_add_box(tray, Vector3(0.038, 0.003, 0.007), Vector3(gx + 0.024, 0.017, gz + 0.018), mat_brass, Vector3(0.0, 32.0, 0.0))

	# Petite Brass Sugar Bowl (Ghand-dan) on right side of tray
	var sx: float = 0.038
	var sz: float = -0.020
	_add_cyl(tray, 0.018, 0.022, 0.010, Vector3(sx, 0.013, sz), mat_aged, Vector3.ZERO, 10)
	_add_sphere(tray, 0.026, 0.032, Vector3(sx, 0.032, sz), mat_brass, Vector3.ZERO, 10)
	_add_cyl(tray, 0.008, 0.020, 0.016, Vector3(sx, 0.050, sz), mat_aged, Vector3.ZERO, 10)
	_add_sphere(tray, 0.007, 0.010, Vector3(sx, 0.062, sz), mat_brass, Vector3.ZERO, 8)

	_bake_interactive_prop_branch(tray, "BakedPersianTeaTrayMesh")
	_register_interactive_prop("desk_tea_tray", tray, Vector3(0.0, 0.04, 0.0), 0.13)


func _build_table_brass_hourglass(parent: Node3D, pos: Vector3) -> void:
	# Classic antique brass sand timer resting on the far back-left walnut rail (centered at mid-height for crisp 180 deg flip!)
	var hg: Node3D = Node3D.new()
	hg.name = "BrassHourglass"
	hg.position = pos + Vector3(0.0, 0.058, 0.0)
	parent.add_child(hg)

	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_sand: Material = _shared_mats["stained_amber"]

	# Symmetric Bottom & Top Brass Caps
	_add_cyl(hg, 0.034, 0.038, 0.008, Vector3(0.0, -0.054, 0.0), mat_aged, Vector3.ZERO, 10)
	_add_cyl(hg, 0.038, 0.034, 0.008, Vector3(0.0, 0.054, 0.0), mat_aged, Vector3.ZERO, 10)
	# Twin Glass Bulbs with Warm Golden Sand
	_add_cyl(hg, 0.005, 0.025, 0.048, Vector3(0.0, -0.026, 0.0), mat_sand, Vector3.ZERO, 10)
	_add_cyl(hg, 0.025, 0.005, 0.048, Vector3(0.0, 0.026, 0.0), mat_sand, Vector3.ZERO, 10)
	# 3 Slender Vertical Brass Pillars
	for i: int in range(3):
		var ang: float = float(i) * (TAU / 3.0) + 0.4
		_add_cyl(hg, 0.003, 0.003, 0.104, Vector3(cos(ang) * 0.028, 0.0, sin(ang) * 0.028), mat_brass, Vector3.ZERO, 6)

	_bake_interactive_prop_branch(hg, "BakedBrassHourglassMesh")
	_register_interactive_prop("desk_hourglass", hg, Vector3.ZERO, 0.10)


func _build_floor_rug_and_corners(parent: Node3D) -> void:
	# Baked single-mesh floor ensemble: ornate Persian parlor carpet + corner floor lantern + terracotta planter.
	# Stays visible in 3D lounge, steep board angles, AND 2D top-down mode so the surrounding floor is never a dark void!
	var floor_grp: Node3D = Node3D.new()
	floor_grp.name = "FloorRugAndCorners3D"
	parent.add_child(floor_grp)

	var mat_crimson: Material = _shared_mats["rug_crimson"]
	var mat_navy: Material = _shared_mats["rug_navy"]
	var mat_gold: Material = _shared_mats["rug_gold"]
	var mat_cream: Material = _shared_mats["rug_cream"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_amber: Material = _shared_mats["stained_amber"]
	var mat_terra: Material = _shared_mats["terracotta"]

	var rug_y: float = -0.774

	# 1. Authentic Textured Kashan/Isfahan Persian Wool Carpet (only 2 top triangles via PlaneMesh!)
	_add_box(floor_grp, Vector3(3.52, 0.010, 3.06), Vector3(0.0, rug_y, -0.18), mat_navy)
	_add_plane(floor_grp, Vector2(3.46, 3.00), Vector3(0.0, rug_y + 0.0065, -0.18), _shared_mats["persian_carpet"])
	# Woven Cream Carpet Fringe Bands Along Left & Right Short Edges
	_add_box(floor_grp, Vector3(0.09, 0.007, 2.98), Vector3(-1.80, rug_y - 0.001, -0.18), mat_cream)
	_add_box(floor_grp, Vector3(0.09, 0.007, 2.98), Vector3(1.80, rug_y - 0.001, -0.18), mat_cream)

	# 2. Warm Glowing Persian Brass Floor Lantern (Back-Left Floor Corner)
	var fl_lan: Node3D = Node3D.new()
	fl_lan.position = Vector3(-1.32, rug_y + 0.008, -1.48)
	floor_grp.add_child(fl_lan)
	_add_cyl(fl_lan, 0.11, 0.13, 0.04, Vector3(0.0, 0.02, 0.0), mat_aged, Vector3.ZERO, 8)
	_add_cyl(fl_lan, 0.088, 0.095, 0.28, Vector3(0.0, 0.18, 0.0), mat_amber, Vector3.ZERO, 8)
	for rib_i: int in range(4):
		var rang: float = float(rib_i) * (PI * 0.5) + 0.4
		_add_box(fl_lan, Vector3(0.012, 0.30, 0.012), Vector3(cos(rang) * 0.096, 0.18, sin(rang) * 0.096), mat_brass)
	_add_cyl(fl_lan, 0.026, 0.115, 0.12, Vector3(0.0, 0.38, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_torus(fl_lan, 0.016, 0.024, Vector3(0.0, 0.46, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 10)

	# 3. Warm Glazed Terracotta Corner Floor Planter with Lush Foliage (Back-Right Floor Corner)
	var fl_pot: Node3D = Node3D.new()
	fl_pot.position = Vector3(1.36, rug_y + 0.008, -1.56)
	floor_grp.add_child(fl_pot)
	_add_cyl(fl_pot, 0.17, 0.12, 0.34, Vector3(0.0, 0.17, 0.0), mat_terra, Vector3.ZERO, 10)
	_add_torus(fl_pot, 0.155, 0.178, Vector3(0.0, 0.34, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_cyl(fl_pot, 0.155, 0.155, 0.016, Vector3(0.0, 0.33, 0.0), _shared_mats["walnut_dark"], Vector3.ZERO, 8)
	_build_potted_broadleaf_plant(fl_pot, Vector3(0.0, 0.34, 0.0), 1.38, false)

	# 4. Traditional Persian Brass & Turquoise Qalyan (Hookah) + Embroidered Termeh Poshti Bolsters
	_build_persian_qalyan(floor_grp, Vector3(1.26, rug_y + 0.010, -0.96))
	_build_persian_poshti(floor_grp, Vector3(-1.46, rug_y + 0.010, 0.28), 22.0)
	_build_persian_poshti(floor_grp, Vector3(1.46, rug_y + 0.010, 0.28), -22.0)

	_bake_static_branch_to_merged_mesh(floor_grp, "BakedFloorLoungeMesh")


func _build_bookcase_cove_lights_and_decor(bc: Node3D) -> void:
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_cove: Material = _shared_mats["cove_glow"]
	var mat_fairy: Material = _shared_mats["fairy_glow"]
	var mat_amber: Material = _shared_mats["stained_amber"]
	var mat_emerald: Material = _shared_mats["stained_emerald"]
	var mat_ruby: Material = _shared_mats["stained_ruby"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_cream: Material = _shared_mats["cream_plaster"]

	# 1. Recessed Warm Golden Cove-Light Strips (0ms unshaded emissive gallery backlight!)
	_add_box(bc, Vector3(1.22, 0.018, 0.025), Vector3(0.0, 1.505, -0.04), mat_cove)
	_add_box(bc, Vector3(1.18, 0.016, 0.020), Vector3(0.0, 0.508, -0.05), mat_cove)
	_add_box(bc, Vector3(0.44, 0.015, 0.020), Vector3(-0.96, 1.19, -0.04), mat_cove)
	_add_box(bc, Vector3(0.44, 0.015, 0.020), Vector3(0.96, 1.19, -0.04), mat_cove)
	# Soft Halo Rim Directly Behind the "کافه فکر / Cafe Fekr" Sign Plaque
	_add_box(bc, Vector3(1.20, 0.60, 0.012), Vector3(0.0, 1.14, 0.016), mat_cove)
	# Subtle Warm Wall Glow Discs Behind Both Brass Sconces (simulates soft wall wash at 0ms GPU cost!)
	for glow_s: float in [-1.0, 1.0]:
		_add_cyl(bc, 0.14, 0.14, 0.008, Vector3(glow_s * 0.98, 1.38, 0.10), mat_cove, Vector3(90.0, 0.0, 0.0), 12)

	# 2. Classic Persian Brass Samovar Centered Flush on the Open Center-Lower Shelf (Interactive Steaming Teapot!)
	var sam: Node3D = Node3D.new()
	sam.name = "PersianSamovar"
	sam.position = Vector3(0.0, 0.161, 0.04)
	bc.add_child(sam)
	_add_box(sam, Vector3(0.11, 0.018, 0.11), Vector3(0.0, 0.009, 0.0), mat_aged)
	_add_cyl(sam, 0.032, 0.048, 0.036, Vector3(0.0, 0.036, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_sphere(sam, 0.068, 0.125, Vector3(0.0, 0.112, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_cyl(sam, 0.038, 0.054, 0.055, Vector3(0.0, 0.192, 0.0), mat_aged, Vector3.ZERO, 10)
	_add_torus(sam, 0.034, 0.044, Vector3(0.0, 0.220, 0.0), mat_brass, Vector3.ZERO, 10)
	# Side Handles & Front Brass Tap
	_add_torus(sam, 0.014, 0.022, Vector3(-0.072, 0.124, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 8)
	_add_torus(sam, 0.014, 0.022, Vector3(0.072, 0.124, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 8)
	_add_cyl(sam, 0.006, 0.009, 0.038, Vector3(0.0, 0.094, 0.076), mat_brass, Vector3(90.0, 0.0, 0.0), 6)
	# Small porcelain teapot perched on its own pivot atop the Samovar crown (rattles & steams when tapped!)
	var teapot_piv: Node3D = Node3D.new()
	teapot_piv.name = "SamovarTeapotPivot"
	teapot_piv.position = Vector3(0.0, 0.235, 0.0)
	sam.add_child(teapot_piv)
	_samovar_teapot_pivot = teapot_piv
	_add_sphere(teapot_piv, 0.034, 0.044, Vector3(0.0, 0.017, 0.0), _shared_mats["porcelain"], Vector3.ZERO, 8)
	_add_sphere(teapot_piv, 0.010, 0.012, Vector3(0.0, 0.043, 0.0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(teapot_piv, 0.005, 0.008, 0.032, Vector3(0.034, 0.022, 0.0), _shared_mats["porcelain"], Vector3(0.0, 0.0, -42.0), 6)
	_bake_interactive_prop_branch(teapot_piv, "BakedSamovarTeapotMesh")
	_bake_interactive_prop_branch(sam, "BakedPersianSamovarMesh")
	_register_interactive_prop("estante_samovar", sam, Vector3(0.0, 0.15, 0.0), 0.18)

	# 2B. Isfahan Mina-Kari Turquoise Display Plate & Hammered Copper Persian Ewer Flanking the Samovar
	_build_minakari_display_plate(bc, Vector3(-0.22, 0.162, 0.05))
	_build_persian_copper_ewer(bc, Vector3(0.22, 0.162, 0.05))

	# 2C. Persian Haft-Rang Glazed Mina-Kari Tile Medallions Inset on the Inner Pilasters
	for tile_s: float in [-1.0, 1.0]:
		var tx: float = tile_s * 0.68
		_add_box(bc, Vector3(0.066, 0.066, 0.016), Vector3(tx, 1.04, 0.126), mat_aged, Vector3(0.0, 0.0, 45.0))
		_add_box(bc, Vector3(0.054, 0.054, 0.008), Vector3(tx, 1.04, 0.134), _shared_mats["minakari_ceramic"], Vector3(0.0, 0.0, 45.0))

	# 3. Two Overhead Hanging Brass & Stained-Glass Cafe Pendant Lanterns (Visible in Upper Lounge!)
	for pend_s: float in [-1.0, 1.0]:
		var pend: Node3D = Node3D.new()
		pend.position = Vector3(pend_s * 0.66, 1.60, 0.56)
		bc.add_child(pend)
		# Slender Ceiling Drop Rod
		_add_cyl(pend, 0.008, 0.008, 0.52, Vector3(0.0, 0.34, 0.0), mat_aged, Vector3.ZERO, 6)
		# Ornate Brass Dome Crown
		_add_cyl(pend, 0.026, 0.125, 0.078, Vector3(0.0, 0.098, 0.0), mat_brass, Vector3.ZERO, 10)
		_add_torus(pend, 0.118, 0.132, Vector3(0.0, 0.058, 0.0), mat_aged, Vector3.ZERO, 12)
		# Glowing Warm Amber Stained-Glass Lantern Body + Emerald Jewel Band
		_add_cyl(pend, 0.112, 0.088, 0.155, Vector3(0.0, -0.022, 0.0), mat_amber, Vector3.ZERO, 10)
		_add_cyl(pend, 0.106, 0.102, 0.032, Vector3(0.0, 0.020, 0.0), mat_emerald, Vector3.ZERO, 10)
		# Brass Filigree Lower Rim & Acorn Finial
		_add_torus(pend, 0.084, 0.096, Vector3(0.0, -0.100, 0.0), mat_brass, Vector3.ZERO, 10)
		_add_cyl(pend, 0.045, 0.010, 0.045, Vector3(0.0, -0.124, 0.0), mat_aged, Vector3.ZERO, 8)
		_add_sphere(pend, 0.014, 0.022, Vector3(0.0, -0.152, 0.0), mat_brass, Vector3.ZERO, 6)

	# 4. Warm Golden Cafe String Fairy Lights Draped Across the Bookcase Crown (Dual Scallop Catenary)
	var bulb_count: int = 11
	for b_i: int in range(bulb_count):
		var t: float = float(b_i) / float(bulb_count - 1)
		var bx: float = lerpf(-1.22, 1.22, t)
		# Graceful dual-arch sag across left & right spans
		var arch_t: float = absf(sin(t * PI * 2.0))
		var by: float = 1.76 - arch_t * 0.14
		var bz: float = 0.21 + arch_t * 0.05
		_add_cyl(bc, 0.005, 0.006, 0.016, Vector3(bx, by + 0.014, bz), mat_aged, Vector3.ZERO, 6)
		_add_sphere(bc, 0.020, 0.030, Vector3(bx, by - 0.004, bz), mat_fairy, Vector3.ZERO, 6)

	# 5. Two Gold-Framed Persian Tapestry & Haft-Rang Tile Artworks Flanking the Bookcase
	for art_s: float in [-1.0, 1.0]:
		var art: Node3D = Node3D.new()
		art.position = Vector3(art_s * 1.48, 1.24, 0.02)
		art.rotation_degrees = Vector3(0.0, art_s * -14.0, 0.0)
		bc.add_child(art)
		# Ornate Brass Frame + Cream Gallery Matte + Textured Persian Tapestry / Tile Artwork
		_add_box(art, Vector3(0.36, 0.48, 0.024), Vector3.ZERO, mat_aged)
		_add_box(art, Vector3(0.30, 0.42, 0.028), Vector3(0.0, 0.0, 0.004), mat_cream)
		var art_mat: Material = _shared_mats["minakari_ceramic"] if art_s < 0.0 else _shared_mats["termeh_fabric"]
		_add_plane(art, Vector2(0.24, 0.34), Vector3(0.0, 0.0, 0.020), art_mat, Vector3(90.0, 0.0, 0.0))
		# Tiny Brass Picture Light Bar Above Frame
		_add_cyl(art, 0.008, 0.008, 0.16, Vector3(0.0, 0.27, 0.045), mat_brass, Vector3(0.0, 0.0, 90.0), 6)
		_add_box(art, Vector3(0.14, 0.008, 0.010), Vector3(0.0, 0.262, 0.042), mat_cove)


func _build_window_casement_door(win_root: Node3D, is_left: bool) -> Node3D:
	# Mobile-optimized hinged walnut & translucent glass casement window door (1 single baked MeshInstance3D per leaf!)
	var dir: float = 1.0 if is_left else -1.0
	var door_piv: Node3D = Node3D.new()
	door_piv.name = "LeftWindowDoorPivot" if is_left else "RightWindowDoorPivot"
	door_piv.position = Vector3(-0.354 if is_left else 0.354, -0.22, 0.056)
	win_root.add_child(door_piv)

	var mat_walnut_pol: Material = _shared_mats["walnut_polished"]
	var mat_walnut_dark: Material = _shared_mats["walnut_dark"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_glass: Material = _shared_mats["window_glass"]
	var mat_glint: Material = _shared_mats["window_glass_glint"]

	var w: float = 0.352
	var h: float = 0.985
	var cx: float = dir * (w * 0.5)

	# Carved Walnut Sash Perimeter Frame (Outer Hinge Stile, Inner Meeting Stile, Top Rail, Deep Bottom Rail)
	_add_box(door_piv, Vector3(0.034, h, 0.030), Vector3(dir * 0.017, 0.0, 0.0), mat_walnut_pol)
	_add_box(door_piv, Vector3(0.030, h, 0.030), Vector3(dir * (w - 0.015), 0.0, 0.0), mat_walnut_pol)
	_add_box(door_piv, Vector3(w, 0.036, 0.030), Vector3(cx, h * 0.5 - 0.018, 0.0), mat_walnut_pol)
	_add_box(door_piv, Vector3(w, 0.054, 0.030), Vector3(cx, -h * 0.5 + 0.027, 0.0), mat_walnut_pol)
	# Subtle Brass Astragal Accent Along the Center Meeting Edge
	_add_box(door_piv, Vector3(0.008, h - 0.04, 0.034), Vector3(dir * (w - 0.004), 0.0, 0.002), mat_aged)

	# Fine Georgian / Persian Sash Muntins Creating 6 Crisp Glass Lites
	_add_box(door_piv, Vector3(0.014, h - 0.08, 0.018), Vector3(cx, 0.006, 0.0), mat_walnut_dark)
	_add_box(door_piv, Vector3(w - 0.06, 0.014, 0.018), Vector3(cx, 0.165, 0.0), mat_walnut_dark)
	_add_box(door_piv, Vector3(w - 0.06, 0.014, 0.018), Vector3(cx, -0.155, 0.0), mat_walnut_dark)

	# Translucent Window Glass Pane (Lightweight Alpha StandardMaterial3D — Zero Screen-Space Refraction Cost!)
	_add_box(door_piv, Vector3(w - 0.058, h - 0.082, 0.007), Vector3(cx, 0.008, 0.0), mat_glass)
	# Subtle Diagonal Specular Glass Reflection Sheen Strip for Crisp Mobile Readability
	_add_plane(door_piv, Vector2(0.042, 0.62), Vector3(cx - dir * 0.025, 0.04, 0.006), mat_glint, Vector3(90.0, 0.0, 24.0 * dir))

	# Twin Antique-Brass Barrel Hinges Along the Outer Pivot Edge
	for hy: float in [-0.34, 0.34]:
		_add_cyl(door_piv, 0.009, 0.009, 0.056, Vector3(0.0, hy, 0.016), mat_brass, Vector3.ZERO, 8)

	# Sculpted Antique-Brass Door Latch Backplate & Curved Handle Near Meeting Stile
	var hx: float = dir * (w - 0.022)
	_add_box(door_piv, Vector3(0.018, 0.095, 0.008), Vector3(hx, -0.02, 0.018), mat_aged)
	_add_cyl(door_piv, 0.007, 0.007, 0.024, Vector3(hx, -0.01, 0.028), mat_brass, Vector3(90.0, 0.0, 0.0), 8)
	_add_box(door_piv, Vector3(0.012, 0.052, 0.010), Vector3(hx - dir * 0.014, -0.032, 0.038), mat_brass, Vector3(0.0, 0.0, dir * 16.0))

	_bake_interactive_prop_branch(door_piv, "BakedLeftWindowDoorMesh" if is_left else "BakedRightWindowDoorMesh")
	return door_piv


func _build_window_stained_glass_transom(win_root: Node3D) -> void:
	# Persian Orosi stained-glass geometric diamond ornaments tucked inside the window arch (0ms unshaded emissive)
	var jewels: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.58, -0.02), "size": Vector3(0.11, 0.11, 0.016), "mat": _shared_mats["stained_amber"]},
		{"pos": Vector3(-0.18, 0.48, -0.02), "size": Vector3(0.085, 0.085, 0.016), "mat": _shared_mats["stained_emerald"]},
		{"pos": Vector3(0.18, 0.48, -0.02), "size": Vector3(0.085, 0.085, 0.016), "mat": _shared_mats["stained_ruby"]},
		{"pos": Vector3(-0.10, 0.36, -0.02), "size": Vector3(0.068, 0.068, 0.016), "mat": _shared_mats["stained_cobalt"]},
		{"pos": Vector3(0.10, 0.36, -0.02), "size": Vector3(0.068, 0.068, 0.016), "mat": _shared_mats["stained_turquoise"]}
	]
	for j: Dictionary in jewels:
		var j_pos: Vector3 = j["pos"] as Vector3
		var j_size: Vector3 = j["size"] as Vector3
		var j_mat: Material = j["mat"] as Material
		_add_box(win_root, j_size + Vector3(0.016, 0.016, -0.002), j_pos, _shared_mats["aged_brass"], Vector3(0.0, 0.0, 45.0))
		_add_box(win_root, j_size, j_pos + Vector3(0.0, 0.0, 0.004), j_mat, Vector3(0.0, 0.0, 45.0))


func _build_mini_brass_candle_lantern(parent: Node3D, pos: Vector3) -> void:
	# Warm glowing antique brass tabletop lantern on the right side table (Interactive Toggle ON/OFF!)
	var lan: Node3D = Node3D.new()
	lan.name = "RightTableLantern"
	lan.position = pos
	parent.add_child(lan)

	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_glow: Material = _shared_mats["right_lantern_glow"]

	_add_cyl(lan, 0.052, 0.060, 0.016, Vector3(0.0, 0.008, 0.0), mat_aged, Vector3.ZERO, 8)
	_add_cyl(lan, 0.042, 0.046, 0.115, Vector3(0.0, 0.074, 0.0), mat_glow, Vector3.ZERO, 8)
	for i: int in range(4):
		var ang: float = float(i) * (PI * 0.5) + 0.4
		_add_box(lan, Vector3(0.007, 0.122, 0.007), Vector3(cos(ang) * 0.046, 0.074, sin(ang) * 0.046), mat_brass)
	_add_cyl(lan, 0.014, 0.056, 0.048, Vector3(0.0, 0.156, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_torus(lan, 0.012, 0.018, Vector3(0.0, 0.190, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 8)

	_bake_interactive_prop_branch(lan, "BakedRightTableLanternMesh")
	_register_interactive_prop("right_table_lantern", lan, Vector3(0.0, 0.09, 0.0), 0.13)


# ============================================================================
# 7. AUTHENTIC PERSIAN PARLOR CRAFTS (MOBILE-OPTIMIZED BAKED & INTERACTIVE)
# ============================================================================

func _build_table_khatam_box(parent: Node3D, pos: Vector3) -> void:
	# Shiraz Khatam-Kari inlaid keepsake box on back-right walnut rail (Interactive Hinged Lid + Heirloom Jewel!)
	var bx: Node3D = Node3D.new()
	bx.name = "PersianKhatamBox"
	bx.position = pos
	bx.rotation_degrees = Vector3(0.0, -8.0, 0.0)
	parent.add_child(bx)

	var mat_khatam: Material = _shared_mats["khatam_inlay"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_aged: Material = _shared_mats["aged_brass"]
	var mat_velvet: Material = _shared_mats["velvet_curtain"]
	var mat_jewel: Material = _shared_mats["stained_emerald"]

	# Lower Keepsake Box Body + Velvet Cushion + Hidden Glowing Emerald Ring/Heirloom Inside!
	_add_box(bx, Vector3(0.126, 0.034, 0.088), Vector3(0.0, 0.017, 0.0), mat_khatam)
	_add_box(bx, Vector3(0.112, 0.008, 0.074), Vector3(0.0, 0.034, 0.0), mat_velvet)
	_add_torus(bx, 0.014, 0.020, Vector3(0.0, 0.040, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_sphere(bx, 0.012, 0.012, Vector3(0.0, 0.044, 0.0), mat_jewel, Vector3.ZERO, 8)
	_add_box(bx, Vector3(0.020, 0.012, 0.008), Vector3(0.0, 0.024, 0.046), mat_brass)

	# Rear-Hinged Khatam-Kari Lid Pivot (Swings Open Smoothly When Tapped!)
	var lid_piv: Node3D = Node3D.new()
	lid_piv.name = "KhatamLidPivot"
	lid_piv.position = Vector3(0.0, 0.035, -0.044)
	bx.add_child(lid_piv)
	_khatam_lid_pivot = lid_piv
	_add_box(lid_piv, Vector3(0.132, 0.012, 0.094), Vector3(0.0, 0.006, 0.044), mat_aged)
	_add_plane(lid_piv, Vector2(0.118, 0.080), Vector3(0.0, 0.013, 0.044), mat_khatam)
	_add_box(lid_piv, Vector3(0.016, 0.008, 0.008), Vector3(0.0, 0.005, 0.092), mat_brass)

	_bake_interactive_prop_branch(lid_piv, "BakedKhatamLidMesh")
	_bake_interactive_prop_branch(bx, "BakedKhatamBoxMesh")
	_register_interactive_prop("desk_khatam_box", bx, Vector3(0.0, 0.03, 0.0), 0.11)


func _build_table_ajil_dish(parent: Node3D, pos: Vector3) -> void:
	# Hammered brass footed dish of Persian pistachios & saffron Nabat resting beside the tea tray
	var dish: Node3D = Node3D.new()
	dish.name = "PersianAjilDish"
	dish.position = pos
	parent.add_child(dish)

	var mat_brass: Material = _shared_mats["brass"]
	var mat_copper: Material = _shared_mats["persian_copper"]
	var mat_saffron: Material = _shared_mats["persian_saffron"]
	var mat_pistachio: Material = _shared_mats["leaf_mid"]
	var mat_cream: Material = _shared_mats["rug_cream"]

	_add_cyl(dish, 0.022, 0.030, 0.014, Vector3(0.0, 0.007, 0.0), mat_copper, Vector3.ZERO, 8)
	_add_cyl(dish, 0.056, 0.028, 0.022, Vector3(0.0, 0.025, 0.0), mat_brass, Vector3.ZERO, 10)
	_add_torus(dish, 0.052, 0.059, Vector3(0.0, 0.036, 0.0), mat_copper, Vector3.ZERO, 10)
	# Small mound of pistachio nuts & golden saffron Nabat sticks
	_add_sphere(dish, 0.020, 0.016, Vector3(-0.014, 0.034, 0.006), mat_pistachio, Vector3.ZERO, 6)
	_add_sphere(dish, 0.018, 0.015, Vector3(0.015, 0.034, -0.008), mat_cream, Vector3.ZERO, 6)
	_add_box(dish, Vector3(0.044, 0.010, 0.010), Vector3(0.004, 0.041, 0.008), mat_saffron, Vector3(8.0, 26.0, -10.0))

	_bake_interactive_prop_branch(dish, "BakedPersianAjilDishMesh")
	_register_interactive_prop("desk_ajil_dish", dish, Vector3(0.0, 0.03, 0.0), 0.10)


func _build_persian_qalyan(parent: Node3D, pos: Vector3) -> void:
	# Traditional Persian brass & Mina-Kari turquoise glass Qalyan (hookah) on the carpet
	var q: Node3D = Node3D.new()
	q.name = "PersianQalyan"
	q.position = pos
	parent.add_child(q)

	var mat_mina: Material = _shared_mats["minakari_ceramic"]
	var mat_cobalt: Material = _shared_mats["persian_cobalt"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_copper: Material = _shared_mats["persian_copper"]
	var mat_terra: Material = _shared_mats["terracotta"]
	var mat_velvet: Material = _shared_mats["velvet_curtain"]
	var mat_ember: Material = _shared_mats["stained_ruby"]

	# Mina-Kari hand-painted turquoise crystal base & gold collar
	_add_cyl(q, 0.082, 0.098, 0.032, Vector3(0.0, 0.016, 0.0), mat_cobalt, Vector3.ZERO, 8)
	_add_sphere(q, 0.094, 0.170, Vector3(0.0, 0.115, 0.0), mat_mina, Vector3.ZERO, 8)
	_add_cyl(q, 0.036, 0.056, 0.068, Vector3(0.0, 0.215, 0.0), mat_mina, Vector3.ZERO, 8)
	_add_torus(q, 0.032, 0.044, Vector3(0.0, 0.252, 0.0), mat_brass, Vector3.ZERO, 8)
	# Turned brass stem, copper ash tray, terracotta Sari bowl & subtle glowing charcoal ember
	_add_cyl(q, 0.016, 0.022, 0.240, Vector3(0.0, 0.372, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_sphere(q, 0.028, 0.034, Vector3(0.0, 0.365, 0.0), mat_copper, Vector3.ZERO, 8)
	_add_cyl(q, 0.082, 0.034, 0.016, Vector3(0.0, 0.496, 0.0), mat_copper, Vector3.ZERO, 10)
	_add_cyl(q, 0.032, 0.020, 0.052, Vector3(0.0, 0.530, 0.0), mat_terra, Vector3.ZERO, 8)
	_add_sphere(q, 0.014, 0.012, Vector3(0.0, 0.560, 0.0), mat_ember, Vector3.ZERO, 6)
	# Coiled crimson velvet hose & brass mouthpiece tucked cleanly beside base
	_add_torus(q, 0.062, 0.074, Vector3(-0.068, 0.245, 0.035), mat_velvet, Vector3(14.0, 28.0, 72.0), 10)
	_add_cyl(q, 0.008, 0.012, 0.110, Vector3(-0.095, 0.315, 0.058), mat_brass, Vector3(12.0, 0.0, 22.0), 6)


func _build_persian_poshti(parent: Node3D, pos: Vector3, yaw_deg: float) -> void:
	# Traditional Yazd Termeh brocade Poshti floor bolster cushion (4 low-poly primitives!)
	var po: Node3D = Node3D.new()
	po.name = "PersianPoshti"
	po.position = pos
	po.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(po)

	var mat_termeh: Material = _shared_mats["termeh_fabric"]
	var mat_gold: Material = _shared_mats["rug_gold"]

	_add_box(po, Vector3(0.18, 0.28, 0.44), Vector3(0.0, 0.14, 0.0), mat_termeh, Vector3(0.0, 0.0, 10.0))
	_add_cyl(po, 0.088, 0.088, 0.44, Vector3(0.024, 0.275, 0.0), mat_termeh, Vector3(90.0, 0.0, 0.0), 8)
	for end_z: float in [-0.22, 0.22]:
		_add_box(po, Vector3(0.19, 0.29, 0.022), Vector3(0.0, 0.14, end_z), mat_gold, Vector3(0.0, 0.0, 10.0))


func _build_minakari_vase(parent: Node3D, pos: Vector3) -> void:
	# Isfahan turquoise & lapis Mina-Kari textured ceramic amphora vase (6 low-poly primitives)
	var v: Node3D = Node3D.new()
	v.name = "MinaKariVase"
	v.position = pos
	parent.add_child(v)

	var mat_mina: Material = _shared_mats["minakari_ceramic"]
	var mat_cobalt: Material = _shared_mats["persian_cobalt"]
	var mat_brass: Material = _shared_mats["brass"]

	_add_cyl(v, 0.028, 0.036, 0.020, Vector3(0.0, 0.010, 0.0), mat_brass, Vector3.ZERO, 8)
	_add_sphere(v, 0.058, 0.108, Vector3(0.0, 0.072, 0.0), mat_mina, Vector3.ZERO, 8)
	_add_torus(v, 0.048, 0.060, Vector3(0.0, 0.072, 0.0), mat_cobalt, Vector3.ZERO, 10)
	_add_cyl(v, 0.020, 0.030, 0.062, Vector3(0.0, 0.142, 0.0), mat_mina, Vector3.ZERO, 8)
	_add_cyl(v, 0.034, 0.020, 0.024, Vector3(0.0, 0.180, 0.0), mat_cobalt, Vector3.ZERO, 8)
	_add_torus(v, 0.030, 0.036, Vector3(0.0, 0.192, 0.0), mat_brass, Vector3.ZERO, 8)


func _build_minakari_display_plate(parent: Node3D, pos: Vector3) -> void:
	# Hand-painted Isfahan Mina-Kari textured ceramic plate displayed on a tiny walnut easel
	var pl: Node3D = Node3D.new()
	pl.name = "MinaKariDisplayPlate"
	pl.position = pos
	pl.rotation_degrees = Vector3(-16.0, 14.0, 0.0)
	parent.add_child(pl)

	var mat_mina: Material = _shared_mats["minakari_ceramic"]
	var mat_brass: Material = _shared_mats["brass"]
	var mat_walnut: Material = _shared_mats["walnut_dark"]

	_add_box(pl, Vector3(0.075, 0.014, 0.048), Vector3(0.0, 0.007, -0.012), mat_walnut)
	_add_cyl(pl, 0.078, 0.078, 0.010, Vector3(0.0, 0.088, 0.0), mat_mina, Vector3(90.0, 0.0, 0.0), 12)
	_add_torus(pl, 0.074, 0.082, Vector3(0.0, 0.088, 0.004), mat_brass, Vector3(90.0, 0.0, 0.0), 12)


func _build_persian_copper_ewer(parent: Node3D, pos: Vector3) -> void:
	# Hammered copper Persian Tong / Aftabeh ewer on the center bookcase shelf (6 low-poly primitives)
	var ew: Node3D = Node3D.new()
	ew.name = "PersianCopperEwer"
	ew.position = pos
	ew.rotation_degrees = Vector3(0.0, -22.0, 0.0)
	parent.add_child(ew)

	var mat_copper: Material = _shared_mats["persian_copper"]
	var mat_brass: Material = _shared_mats["brass"]

	_add_cyl(ew, 0.026, 0.036, 0.022, Vector3(0.0, 0.011, 0.0), mat_copper, Vector3.ZERO, 8)
	_add_sphere(ew, 0.050, 0.092, Vector3(0.0, 0.065, 0.0), mat_copper, Vector3.ZERO, 8)
	_add_cyl(ew, 0.016, 0.026, 0.082, Vector3(0.0, 0.140, 0.0), mat_copper, Vector3.ZERO, 8)
	_add_cyl(ew, 0.008, 0.020, 0.026, Vector3(0.0, 0.192, 0.0), mat_brass, Vector3.ZERO, 8)
	# Slender spout & curved brass handle
	_add_cyl(ew, 0.005, 0.010, 0.088, Vector3(0.052, 0.104, 0.0), mat_copper, Vector3(0.0, 0.0, -34.0), 6)
	_add_torus(ew, 0.024, 0.032, Vector3(-0.044, 0.110, 0.0), mat_brass, Vector3(90.0, 0.0, 0.0), 8)


func _build_persian_tar_instrument(parent: Node3D, pos: Vector3) -> void:
	# Traditional Persian Tar lute leaning in the right lounge corner (9 low-poly primitives)
	var tar: Node3D = Node3D.new()
	tar.name = "PersianTarLute"
	tar.position = pos
	tar.rotation_degrees = Vector3(-11.0, -28.0, 6.0)
	parent.add_child(tar)

	var mat_walnut: Material = _shared_mats["walnut_polished"]
	var mat_dark: Material = _shared_mats["walnut_dark"]
	var mat_skin: Material = _shared_mats["cream_plaster"]
	var mat_brass: Material = _shared_mats["brass"]

	# Iconic figure-8 mulberry wood double resonator bowl with light parchment face
	_add_sphere(tar, 0.115, 0.210, Vector3(0.0, 0.115, 0.0), mat_walnut, Vector3(0.0, 0.0, 0.0), 8)
	_add_sphere(tar, 0.084, 0.155, Vector3(0.0, 0.275, 0.0), mat_walnut, Vector3(0.0, 0.0, 0.0), 8)
	_add_cyl(tar, 0.088, 0.088, 0.012, Vector3(0.0, 0.115, 0.095), mat_skin, Vector3(90.0, 0.0, 0.0), 8)
	_add_cyl(tar, 0.064, 0.064, 0.012, Vector3(0.0, 0.275, 0.072), mat_skin, Vector3(90.0, 0.0, 0.0), 8)
	# Long slim walnut fretboard & bone nut / bridge accents
	_add_box(tar, Vector3(0.034, 0.56, 0.026), Vector3(0.0, 0.61, 0.02), mat_dark)
	_add_box(tar, Vector3(0.010, 0.54, 0.008), Vector3(0.0, 0.61, 0.034), mat_skin)
	_add_box(tar, Vector3(0.044, 0.13, 0.038), Vector3(0.0, 0.94, 0.015), mat_walnut)
	# Side wooden tuning pegs
	for peg_i: int in range(3):
		var py: float = 0.89 + float(peg_i) * 0.042
		_add_cyl(tar, 0.005, 0.005, 0.085, Vector3(0.0, py, 0.018), mat_brass, Vector3(0.0, 0.0, 90.0), 6)
