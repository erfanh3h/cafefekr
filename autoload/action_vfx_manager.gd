extends Node

## ActionVFXManager
## Centralized VFX and Action Juice framework inspired by Rokojori Action Library
## Handles screen shakes, 3D particle bursts, squash & stretch, impact shockwaves, and UI juice.

# Particle texture preloads from Kenney Particle Pack
var tex_circle_shockwave = preload("res://assets/particles/circle_05.png")
var tex_sparkle = preload("res://assets/particles/magic_03.png")
var tex_star = preload("res://assets/particles/star_01.png")
var tex_flare = preload("res://assets/particles/flare_01.png")
var tex_spark = preload("res://assets/particles/spark_01.png")
var tex_smoke = preload("res://assets/particles/smoke_01.png")

# Screen shake state
var _camera: Camera3D = null
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _cam_original_pos: Vector3 = Vector3.ZERO
var _cam_original_rot: Vector3 = Vector3.ZERO
var _is_shaking: bool = false

# 2D UI Particle Layer
var _ui_canvas_layer: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui_canvas()

func _setup_ui_canvas() -> void:
	_ui_canvas_layer = CanvasLayer.new()
	_ui_canvas_layer.name = "ActionVFX_UILayer"
	_ui_canvas_layer.layer = 120 # Above all dialogs
	add_child(_ui_canvas_layer)

func _process(delta: float) -> void:
	if _is_shaking:
		if _shake_timer > 0.0:
			_shake_timer -= delta
			var progress = _shake_timer / _shake_duration
			var current_intensity = _shake_intensity * progress
			
			if is_instance_valid(_camera):
				var offset_x = randf_range(-current_intensity, current_intensity)
				var offset_y = randf_range(-current_intensity, current_intensity) * 0.7
				var offset_z = randf_range(-current_intensity, current_intensity) * 0.5
				_camera.position = _cam_original_pos + Vector3(offset_x, offset_y, offset_z)
				
				var rot_x = randf_range(-current_intensity, current_intensity) * 0.4
				var rot_y = randf_range(-current_intensity, current_intensity) * 0.4
				_camera.rotation = _cam_original_rot + Vector3(rot_x, rot_y, 0.0)
		else:
			_is_shaking = false
			if is_instance_valid(_camera):
				_camera.position = _cam_original_pos
				_camera.rotation = _cam_original_rot

# --- 1. SCREEN / CAMERA SHAKE ACTION ---

func shake_camera(intensity: float = 0.045, duration: float = 0.22, target_cam: Camera3D = null) -> void:
	if target_cam:
		_camera = target_cam
	else:
		_camera = get_viewport().get_camera_3d()
		
	if not is_instance_valid(_camera):
		return
		
	if not _is_shaking:
		_cam_original_pos = _camera.position
		_cam_original_rot = _camera.rotation
		
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = duration
	_shake_timer = duration
	_is_shaking = true

# --- 2. 3D PIECE IMPACT & SHOCKWAVE VFX (Rokojori / Kenney Style) ---

func spawn_piece_impact_vfx(parent_node: Node3D, pos: Vector3, player_id: int) -> void:
	var vfx_root = Node3D.new()
	vfx_root.name = "ImpactVFX_%d" % Time.get_ticks_msec()
	vfx_root.position = pos
	parent_node.add_child(vfx_root)
	
	# Theme colors matching Red (P1) and Blue (P2)
	var primary_color = Color(1.0, 0.28, 0.32) if player_id == 1 else Color(0.28, 0.65, 1.0)
	var glow_color = Color(1.0, 0.5, 0.55) if player_id == 1 else Color(0.55, 0.85, 1.0)
	
	# A. Expanding Shockwave Ring on Board Surface
	var shockwave = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	shockwave.mesh = quad
	shockwave.rotation_degrees.x = -90.0 # Lay flat on board
	shockwave.position.y = 0.005 # Just above surface
	
	var shock_mat = StandardMaterial3D.new()
	shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shock_mat.albedo_texture = tex_circle_shockwave
	shock_mat.albedo_color = primary_color
	shockwave.material_override = shock_mat
	vfx_root.add_child(shockwave)
	
	# Animate shockwave expanding and fading out
	var shock_tw = create_tween().set_parallel(true)
	shock_tw.tween_property(shockwave, "scale", Vector3(3.4, 3.4, 3.4), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shock_tw.tween_property(shock_mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# B. Starburst Sparkle Particles
	var spark_count = 14
	for i in range(spark_count):
		var p = Sprite3D.new()
		p.texture = tex_sparkle if (i % 2 == 0) else tex_spark
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.modulate = primary_color if (i % 3 != 0) else Color(1.0, 0.95, 0.75)
		p.scale = Vector3(0.045, 0.045, 0.045)
		p.position = Vector3(0, 0.02, 0)
		vfx_root.add_child(p)
		
		var angle = (float(i) / float(spark_count)) * TAU + randf_range(-0.2, 0.2)
		var dist = randf_range(0.15, 0.32)
		var height = randf_range(0.08, 0.28)
		var target_pos = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		
		var p_tw = create_tween().set_parallel(true)
		p_tw.tween_property(p, "position", target_pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.tween_property(p, "scale", Vector3.ZERO, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		p_tw.tween_property(p, "modulate:a", 0.0, 0.38)
	
	# C. Subtle Central Impact Flash
	var flash = Sprite3D.new()
	flash.texture = tex_flare
	flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash.modulate = glow_color
	flash.scale = Vector3(0.08, 0.08, 0.08)
	flash.position = Vector3(0, 0.04, 0)
	vfx_root.add_child(flash)
	
	var f_tw = create_tween().set_parallel(true)
	f_tw.tween_property(flash, "scale", Vector3(0.24, 0.24, 0.24), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	f_tw.tween_property(flash, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Subtle camera shake on impact
	shake_camera(0.038, 0.18)
	
	# Cleanup VFX after animation finishes
	get_tree().create_timer(0.5).timeout.connect(vfx_root.queue_free)

# --- 3. JUICY PIECE LANDING (Squash & Stretch Action) ---

func animate_piece_drop(piece_node: Node3D, target_y: float, on_landed: Callable = Callable()) -> void:
	if not is_instance_valid(piece_node):
		return
		
	piece_node.position.y = target_y + 0.42
	piece_node.scale = Vector3(0.75, 1.35, 0.75) # Stretched while falling
	
	var drop_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_tw.tween_property(piece_node, "position:y", target_y, 0.18)
	drop_tw.parallel().tween_property(piece_node, "scale", Vector3(1.0, 1.0, 1.0), 0.18)
	
	drop_tw.finished.connect(func():
		if not is_instance_valid(piece_node):
			return
		if on_landed.is_valid():
			on_landed.call()
			
		# Squash upon hitting the board
		var bounce_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		piece_node.scale = Vector3(1.28, 0.68, 1.28) # Squash
		bounce_tw.tween_property(piece_node, "scale", Vector3(0.92, 1.15, 0.92), 0.1) # Rebound stretch
		bounce_tw.tween_property(piece_node, "scale", Vector3.ONE, 0.16) # Settle
	)

# --- 4. VICTORY CELEBRATION VFX (Stars & Confetti Shower) ---

func spawn_victory_celebration(parent_node: Node3D, center_pos: Vector3, winner_id: int) -> void:
	var win_root = Node3D.new()
	win_root.name = "VictoryCelebration_%d" % Time.get_ticks_msec()
	win_root.position = center_pos + Vector3(0, 0.05, 0)
	parent_node.add_child(win_root)
	
	var star_colors = [
		Color(1.0, 0.85, 0.2), # Gold
		Color(1.0, 0.35, 0.35) if winner_id == 1 else Color(0.35, 0.75, 1.0), # Winner color
		Color(1.0, 0.95, 0.7), # Pale Diamond
		Color(0.4, 0.95, 0.5)  # Emerald
	]
	
	# Spawn bursting stars fountain
	var total_stars = 28
	for i in range(total_stars):
		var star = Sprite3D.new()
		star.texture = tex_star if (i % 2 == 0) else tex_sparkle
		star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		star.modulate = star_colors[i % star_colors.size()]
		var init_scale = randf_range(0.045, 0.08)
		star.scale = Vector3(init_scale, init_scale, init_scale)
		star.position = Vector3(randf_range(-0.15, 0.15), 0.05, randf_range(-0.15, 0.15))
		win_root.add_child(star)
		
		# Launch upward in arc, then gently flutter down
		var launch_x = randf_range(-0.6, 0.6)
		var launch_z = randf_range(-0.6, 0.6)
		var peak_y = randf_range(0.45, 0.85)
		
		var s_tw = create_tween()
		# Rise
		s_tw.tween_property(star, "position", Vector3(launch_x * 0.5, peak_y, launch_z * 0.5), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		s_tw.parallel().tween_property(star, "rotation_degrees:z", randf_range(-180, 180), 0.42)
		# Fall
		s_tw.chain().tween_property(star, "position", Vector3(launch_x, 0.02, launch_z), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		s_tw.parallel().tween_property(star, "scale", Vector3.ZERO, 0.55)
		s_tw.parallel().tween_property(star, "modulate:a", 0.0, 0.55)
		
	# Victorious screen shake
	shake_camera(0.07, 0.45)
	
	# Cleanup
	get_tree().create_timer(1.6).timeout.connect(win_root.queue_free)

# --- 5. 2D UI TACTILE CLICK JUICE (Kenney / Rokojori UI Action) ---

func apply_button_juice(btn: BaseButton, click_sound: String = "tap_button") -> void:
	if not is_instance_valid(btn):
		return
		
	btn.pivot_offset = btn.size / 2.0
	
	btn.mouse_entered.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)
	)
	
	btn.mouse_exited.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)
	
	btn.button_down.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
		if not click_sound.is_empty():
			AudioManager.play_sound(click_sound)
	)
	
	btn.button_up.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)
	)
	
	btn.pressed.connect(func():
		spawn_ui_click_burst(btn.get_global_mouse_position())
	)

func animate_button_pop(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(1.06, 1.06), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.08)

func spawn_ui_click_burst(screen_pos: Vector2, tint_color: Color = Color(1.0, 0.88, 0.35)) -> void:
	if not is_instance_valid(_ui_canvas_layer):
		return
		
	var burst_root = Control.new()
	burst_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_root.position = screen_pos
	_ui_canvas_layer.add_child(burst_root)
	
	# Small cluster of 6 tiny popping sparkles
	for i in range(6):
		var star = TextureRect.new()
		star.texture = tex_sparkle
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(20, 20)
		star.size = Vector2(20, 20)
		star.pivot_offset = Vector2(10, 10)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = tint_color if (i % 2 == 0) else Color(1.0, 1.0, 1.0)
		burst_root.add_child(star)
		
		var angle = (float(i) / 6.0) * TAU + randf_range(-0.3, 0.3)
		var dist = randf_range(28.0, 52.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * dist
		
		var tw = create_tween().set_parallel(true)
		tw.tween_property(star, "position", target_offset, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(star, "modulate:a", 0.0, 0.28)
		
	get_tree().create_timer(0.4).timeout.connect(burst_root.queue_free)

# --- 6. 2D DIALOG JUICE & VFX ---

func _kill_control_tween(node: Control) -> void:
	if is_instance_valid(node) and node.has_meta("_vfx_tween"):
		var prev_tw = node.get_meta("_vfx_tween")
		if prev_tw and prev_tw is Tween and prev_tw.is_valid():
			prev_tw.kill()
		node.remove_meta("_vfx_tween")

func animate_dialog_open(card_node: Control, overlay_node: Control = null, with_sparkles: bool = true, play_sfx: bool = true) -> void:
	if not is_instance_valid(card_node):
		return
		
	if play_sfx:
		AudioManager.sfx_dialog()
		
	if is_instance_valid(overlay_node):
		_kill_control_tween(overlay_node)
		overlay_node.visible = true
		overlay_node.modulate.a = 0.0
		var o_tw = overlay_node.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		o_tw.tween_property(overlay_node, "modulate:a", 1.0, 0.18)
		overlay_node.set_meta("_vfx_tween", o_tw)
		
	_kill_control_tween(card_node)
	card_node.visible = true
	card_node.scale = Vector2(0.82, 0.82)
	card_node.modulate.a = 0.0
	card_node.pivot_offset = card_node.size / 2.0
	
	var tw = card_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_node, "scale", Vector2.ONE, 0.24)
	tw.tween_property(card_node, "modulate:a", 1.0, 0.16)
	card_node.set_meta("_vfx_tween", tw)
	
	if with_sparkles:
		card_node.get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(card_node) and card_node.visible:
				spawn_dialog_sparkle_burst(card_node.global_position + card_node.size / 2.0)
		)

func animate_dialog_close(card_node: Control, overlay_node: Control = null, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(card_node):
		if on_complete.is_valid():
			on_complete.call()
		return
		
	_kill_control_tween(card_node)
	card_node.pivot_offset = card_node.size / 2.0
	var tw = card_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card_node, "scale", Vector2(0.84, 0.84), 0.14)
	tw.tween_property(card_node, "modulate:a", 0.0, 0.14)
	card_node.set_meta("_vfx_tween", tw)
	
	if is_instance_valid(overlay_node):
		_kill_control_tween(overlay_node)
		var o_tw = overlay_node.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		o_tw.tween_property(overlay_node, "modulate:a", 0.0, 0.14)
		overlay_node.set_meta("_vfx_tween", o_tw)
		
	await tw.finished
	if is_instance_valid(card_node):
		card_node.visible = false
	if is_instance_valid(overlay_node):
		overlay_node.visible = false
	if on_complete.is_valid():
		on_complete.call()

func spawn_dialog_sparkle_burst(center_pos: Vector2) -> void:
	if not is_instance_valid(_ui_canvas_layer):
		return
		
	var burst_root = Control.new()
	burst_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_root.position = center_pos
	_ui_canvas_layer.add_child(burst_root)
	
	var colors = [
		Color(1.0, 0.9, 0.4),
		Color(1.0, 0.65, 0.2),
		Color(0.4, 0.85, 1.0),
		Color(1.0, 1.0, 1.0)
	]
	
	for i in range(12):
		var star = TextureRect.new()
		star.texture = tex_star
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(28, 28)
		star.size = Vector2(28, 28)
		star.pivot_offset = Vector2(14, 14)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = colors[i % colors.size()]
		burst_root.add_child(star)
		
		var angle = (float(i) / 12.0) * TAU + randf_range(-0.2, 0.2)
		var dist = randf_range(140.0, 280.0)
		var target_offset = Vector2(cos(angle), sin(angle)) * dist
		
		var tw = burst_root.create_tween().set_parallel(true)
		tw.tween_property(star, "position", target_offset, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "rotation_degrees", randf_range(-180, 180), 0.45)
		tw.tween_property(star, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(star, "modulate:a", 0.0, 0.45)
		
	get_tree().create_timer(0.55).timeout.connect(burst_root.queue_free)
