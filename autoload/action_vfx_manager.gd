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
var _is_mobile: bool = false
var _shared_shockwave_quad: QuadMesh = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_mobile = OS.has_feature("mobile") or (OS.get_name() in ["Android", "iOS"])
	_shared_shockwave_quad = QuadMesh.new()
	_shared_shockwave_quad.size = Vector2(0.12, 0.12)
	set_process(false)
	_setup_ui_canvas()
	_init_touch_scrolling()

func _setup_ui_canvas() -> void:
	_ui_canvas_layer = CanvasLayer.new()
	_ui_canvas_layer.name = "ActionVFX_UILayer"
	_ui_canvas_layer.layer = 120 # Above all dialogs
	add_child(_ui_canvas_layer)

func _process(delta: float) -> void:
	if _is_shaking:
		if _shake_timer > 0.0:
			_shake_timer -= delta
			var progress = clampf(_shake_timer / maxf(_shake_duration, 0.001), 0.0, 1.0)
			var current_intensity = _shake_intensity * progress * progress
			
			if is_instance_valid(_camera):
				var phase = (_shake_duration - _shake_timer) * 42.0
				var offset_x = sin(phase) * current_intensity
				var offset_y = cos(phase * 1.3) * current_intensity * 0.5
				var offset_z = sin(phase * 0.7) * current_intensity * 0.35
				_camera.position = _cam_original_pos + Vector3(offset_x, offset_y, offset_z)
				_camera.rotation = _cam_original_rot
		else:
			_is_shaking = false
			_shake_intensity = 0.0
			set_process(false)
			if is_instance_valid(_camera):
				_camera.position = _cam_original_pos
				_camera.rotation = _cam_original_rot
	else:
		_shake_intensity = 0.0
		set_process(false)

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
		_shake_intensity = intensity
	else:
		_shake_intensity = max(_shake_intensity, intensity)
		
	_shake_duration = duration
	_shake_timer = duration
	_is_shaking = true
	set_process(true)

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
	shockwave.mesh = _shared_shockwave_quad
	shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var spark_count = 4 if _is_mobile else 8
	for i in range(spark_count):
		var p = Sprite3D.new()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	
	# Screen shake on regular piece placement/movement removed for smooth board experience
	
	# Cleanup VFX after animation finishes
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(vfx_root):
			vfx_root.queue_free()
	)

func play_piece_drop_vfx(parent_node: Node3D, pos: Vector3, color_or_id: Variant = null) -> void:
	if not is_instance_valid(parent_node) or not parent_node.is_inside_tree():
		return
	
	var vfx_root = Node3D.new()
	vfx_root.name = "PieceDropVFX_%d" % Time.get_ticks_msec()
	parent_node.add_child(vfx_root)
	vfx_root.global_position = pos
	
	var primary_color: Color = Color(1.0, 0.85, 0.35)
	if color_or_id is Color:
		primary_color = color_or_id
	elif color_or_id is int or color_or_id is float:
		primary_color = Color(1.0, 0.28, 0.32) if int(color_or_id) == 1 else Color(0.28, 0.65, 1.0)
	var glow_color: Color = primary_color.lightened(0.25)
	
	# Expanding Shockwave Ring
	var shockwave = MeshInstance3D.new()
	shockwave.mesh = _shared_shockwave_quad
	shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shockwave.rotation_degrees.x = -90.0
	shockwave.position.y = 0.005
	
	var shock_mat = StandardMaterial3D.new()
	shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if tex_circle_shockwave:
		shock_mat.albedo_texture = tex_circle_shockwave
	shock_mat.albedo_color = primary_color
	shockwave.material_override = shock_mat
	vfx_root.add_child(shockwave)
	
	var shock_tw = create_tween().set_parallel(true)
	shock_tw.tween_property(shockwave, "scale", Vector3(3.2, 3.2, 3.2), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shock_tw.tween_property(shock_mat, "albedo_color:a", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Starburst Sparkles
	var spark_count = 4 if _is_mobile else 6
	for i in range(spark_count):
		var p = Sprite3D.new()
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.texture = tex_sparkle if (i % 2 == 0 and tex_sparkle) else tex_spark
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.modulate = primary_color if (i % 2 == 0) else Color(1.0, 0.95, 0.75)
		p.scale = Vector3(0.04, 0.04, 0.04)
		p.position = Vector3(0, 0.02, 0)
		vfx_root.add_child(p)
		
		var angle = (float(i) / float(spark_count)) * TAU + randf_range(-0.2, 0.2)
		var dist = randf_range(0.12, 0.26)
		var height = randf_range(0.06, 0.20)
		var target_offset = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		
		var p_tw = create_tween().set_parallel(true)
		p_tw.tween_property(p, "position", target_offset, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tw.tween_property(p, "scale", Vector3.ZERO, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		p_tw.tween_property(p, "modulate:a", 0.0, 0.34)
	
	# Subtle Flash
	if tex_flare:
		var flash = Sprite3D.new()
		flash.texture = tex_flare
		flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flash.modulate = glow_color
		flash.scale = Vector3(0.08, 0.08, 0.08)
		flash.position = Vector3(0, 0.03, 0)
		vfx_root.add_child(flash)
		
		var f_tw = create_tween().set_parallel(true)
		f_tw.tween_property(flash, "scale", Vector3(0.22, 0.22, 0.22), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		f_tw.tween_property(flash, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(vfx_root):
			vfx_root.queue_free()
	)

func play_win_celebration_vfx(parent_node: Node3D, center_pos: Vector3, winner_id: int) -> void:
	spawn_victory_celebration(parent_node, center_pos, winner_id)

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
	var total_stars = 14
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
		
	# Screen shake removed from board victory celebration
	
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
	for i in range(4):
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


# ==============================================================================
# Universal 60fps Mobile Touch Drag Scrolling Framework for Android / Mobile
# Automatically detects all ScrollContainers in the application and enables
# fluid kinetic touch-drag scrolling even when child buttons/panels exist.
# ==============================================================================

var _registered_scrolls: Array[ScrollContainer] = []
var _touch_scroll_active: bool = false
var _touch_scroll_dragging: bool = false
var _touch_scroll_target: ScrollContainer = null
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_scroll_v: int = 0
var _touch_start_scroll_h: int = 0
var _touch_finger_id: int = -1
var _touch_is_screen_touch: bool = false
var _touch_velocity_samples: Array = []

func _init_touch_scrolling() -> void:
	get_tree().node_added.connect(_on_node_added_for_touch_scroll)
	call_deferred("_scan_existing_scroll_containers", get_tree().root)

func _scan_existing_scroll_containers(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is ScrollContainer:
		_register_scroll_container(node)
	for child in node.get_children():
		_scan_existing_scroll_containers(child)

func _on_node_added_for_touch_scroll(node: Node) -> void:
	if node is ScrollContainer:
		_register_scroll_container(node)

func _register_scroll_container(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc) or _registered_scrolls.has(sc):
		return
	_registered_scrolls.append(sc)
	sc.tree_exited.connect(func():
		_registered_scrolls.erase(sc)
		if _touch_scroll_target == sc:
			_touch_scroll_active = false
			_touch_scroll_dragging = false
			_touch_scroll_target = null
	)

func _find_scroll_container_at(pos: Vector2) -> ScrollContainer:
	var candidates: Array[ScrollContainer] = []
	for sc in _registered_scrolls:
		if is_instance_valid(sc) and sc.is_inside_tree() and sc.is_visible_in_tree():
			var r = sc.get_global_rect()
			if r.has_point(pos):
				var vbar = sc.get_v_scroll_bar()
				var hbar = sc.get_h_scroll_bar()
				var can_scroll_v = (sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED) and (vbar and vbar.max_value > sc.size.y + 2.0)
				var can_scroll_h = (sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED) and (hbar and hbar.max_value > sc.size.x + 2.0)
				if can_scroll_v or can_scroll_h:
					candidates.append(sc)
	
	if candidates.is_empty():
		return null
	
	var best: ScrollContainer = candidates[0]
	for i in range(1, candidates.size()):
		var c = candidates[i]
		if best.is_ancestor_of(c):
			best = c
		elif c.is_ancestor_of(best):
			pass
		elif (c.size.x * c.size.y) < (best.size.x * best.size.y):
			best = c
	return best

func _apply_touch_scroll_inertia() -> void:
	if not is_instance_valid(_touch_scroll_target) or _touch_velocity_samples.size() < 2:
		return
	var first_sample = _touch_velocity_samples[0]
	var last_sample = _touch_velocity_samples[-1]
	var dt = float(last_sample["time"] - first_sample["time"]) / 1000.0
	if dt <= 0.001 or dt > 0.35:
		return
	var vel_y = (last_sample["pos"].y - first_sample["pos"].y) / dt
	if absf(vel_y) < 100.0:
		return
	var vbar = _touch_scroll_target.get_v_scroll_bar()
	var max_v = vbar.max_value if vbar else 99999.0
	var current_scroll = _touch_scroll_target.scroll_vertical
	var target_scroll = clampi(int(current_scroll - vel_y * 0.28), 0, int(max_v))
	var tween = _touch_scroll_target.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_touch_scroll_target, "scroll_vertical", target_scroll, 0.42)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_is_screen_touch = true
		if event.pressed:
			if not _touch_scroll_active:
				var target = _find_scroll_container_at(event.position)
				if is_instance_valid(target):
					_touch_scroll_active = true
					_touch_scroll_dragging = false
					_touch_scroll_target = target
					_touch_finger_id = event.index
					_touch_start_pos = event.position
					_touch_start_scroll_v = target.scroll_vertical
					_touch_start_scroll_h = target.scroll_horizontal
					_touch_velocity_samples.clear()
					_touch_velocity_samples.append({"pos": event.position, "time": Time.get_ticks_msec()})
		else:
			if _touch_scroll_active and event.index == _touch_finger_id:
				if _touch_scroll_dragging:
					get_viewport().set_input_as_handled()
					_apply_touch_scroll_inertia()
				_touch_scroll_active = false
				_touch_scroll_dragging = false
				_touch_scroll_target = null
				_touch_finger_id = -1
				_touch_is_screen_touch = false

	elif event is InputEventScreenDrag:
		if _touch_scroll_active and event.index == _touch_finger_id:
			if is_instance_valid(_touch_scroll_target) and _touch_scroll_target.is_inside_tree() and _touch_scroll_target.is_visible_in_tree():
				var delta = event.position - _touch_start_pos
				if not _touch_scroll_dragging:
					if absf(delta.y) > 10.0 or absf(delta.x) > 10.0:
						_touch_scroll_dragging = true
				if _touch_scroll_dragging:
					if _touch_scroll_target.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
						var vbar = _touch_scroll_target.get_v_scroll_bar()
						var max_v = vbar.max_value if vbar else 99999.0
						_touch_scroll_target.scroll_vertical = clampi(int(_touch_start_scroll_v - delta.y), 0, int(max_v))
					if _touch_scroll_target.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
						var hbar = _touch_scroll_target.get_h_scroll_bar()
						var max_h = hbar.max_value if hbar else 99999.0
						_touch_scroll_target.scroll_horizontal = clampi(int(_touch_start_scroll_h - delta.x), 0, int(max_h))
					_touch_velocity_samples.append({"pos": event.position, "time": Time.get_ticks_msec()})
					if _touch_velocity_samples.size() > 5:
						_touch_velocity_samples.pop_front()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and not _touch_is_screen_touch:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not _touch_scroll_active:
					var target = _find_scroll_container_at(event.position)
					if is_instance_valid(target):
						_touch_scroll_active = true
						_touch_scroll_dragging = false
						_touch_scroll_target = target
						_touch_finger_id = 0
						_touch_start_pos = event.position
						_touch_start_scroll_v = target.scroll_vertical
						_touch_start_scroll_h = target.scroll_horizontal
						_touch_velocity_samples.clear()
						_touch_velocity_samples.append({"pos": event.position, "time": Time.get_ticks_msec()})
			else:
				if _touch_scroll_active and _touch_finger_id == 0:
					if _touch_scroll_dragging:
						get_viewport().set_input_as_handled()
						_apply_touch_scroll_inertia()
					_touch_scroll_active = false
					_touch_scroll_dragging = false
					_touch_scroll_target = null
					_touch_finger_id = -1

	elif event is InputEventMouseMotion and not _touch_is_screen_touch:
		if _touch_scroll_active and _touch_finger_id == 0:
			if is_instance_valid(_touch_scroll_target) and _touch_scroll_target.is_inside_tree() and _touch_scroll_target.is_visible_in_tree():
				var delta = event.position - _touch_start_pos
				if not _touch_scroll_dragging:
					if absf(delta.y) > 10.0 or absf(delta.x) > 10.0:
						_touch_scroll_dragging = true
				if _touch_scroll_dragging:
					if _touch_scroll_target.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
						var vbar = _touch_scroll_target.get_v_scroll_bar()
						var max_v = vbar.max_value if vbar else 99999.0
						_touch_scroll_target.scroll_vertical = clampi(int(_touch_start_scroll_v - delta.y), 0, int(max_v))
					if _touch_scroll_target.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
						var hbar = _touch_scroll_target.get_h_scroll_bar()
						var max_h = hbar.max_value if hbar else 99999.0
						_touch_scroll_target.scroll_horizontal = clampi(int(_touch_start_scroll_h - delta.x), 0, int(max_h))
					_touch_velocity_samples.append({"pos": event.position, "time": Time.get_ticks_msec()})
					if _touch_velocity_samples.size() > 5:
						_touch_velocity_samples.pop_front()
					get_viewport().set_input_as_handled()
