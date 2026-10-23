extends Node3D

# Realistic Organic 3D Hand Controller
# Replaces boxy artificial hands with an anatomically sculpted, smooth organic human hand.
# Uses smooth CapsuleMeshes and spherical joints for rounded fingers, fleshy palm contour,
# and authentic pinch-grasp gesture.

@export var is_enemy: bool = false

const COLOR_RED_CLOTH = Color(0.72, 0.16, 0.20) # Rich crimson velvet/fabric
const COLOR_BLUE_CLOTH = Color(0.16, 0.40, 0.82) # Vibrant royal sapphire fabric

var mat_cuff: StandardMaterial3D = null

func set_cloth_color(color: Color) -> void:
	if mat_cuff:
		mat_cuff.albedo_color = color

var hand_root: Node3D
var palm_root: Node3D
var thumb_root: Node3D
var thumb_tip: Node3D
var index_root: Node3D
var index_tip: Node3D
var middle_root: Node3D
var ring_root: Node3D
var pinky_root: Node3D

var is_animating: bool = false

func _ready() -> void:
	_build_organic_human_hand()
	visible = false

func _build_organic_human_hand() -> void:
	hand_root = Node3D.new()
	hand_root.name = "HumanHandModel"
	add_child(hand_root)
	
	# --- Authentic Organic Materials ---
	var mat_skin = StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.87, 0.73, 0.61) # Warm natural skin tone
	mat_skin.roughness = 0.52 # Soft diffuse skin (NOT shiny plastic!)
	mat_skin.rim_enabled = true
	mat_skin.rim = 0.45
	mat_skin.rim_tint = 0.70 # Warm peach subsurface scattering on silhouettes
	
	var mat_nail = StandardMaterial3D.new()
	mat_nail.albedo_color = Color(0.93, 0.82, 0.78)
	mat_nail.roughness = 0.28
	mat_nail.clearcoat_enabled = true
	mat_nail.clearcoat = 0.4
	
	mat_cuff = StandardMaterial3D.new()
	mat_cuff.albedo_color = COLOR_BLUE_CLOTH if is_enemy else COLOR_RED_CLOTH
	mat_cuff.roughness = 0.8
	
	var mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.92, 0.76, 0.28) # Gold watch / cufflink
	mat_metal.metallic = 0.9
	mat_metal.roughness = 0.22

	# --- Forearm & Sleeve ---
	var forearm = MeshInstance3D.new()
	var cyl_arm = CylinderMesh.new()
	cyl_arm.top_radius = 0.048
	cyl_arm.bottom_radius = 0.062
	cyl_arm.height = 0.36
	cyl_arm.radial_segments = 20
	cyl_arm.material = mat_cuff
	forearm.mesh = cyl_arm
	forearm.rotation_degrees.x = 90.0
	forearm.position = Vector3(0.0, 0.022, 0.20)
	hand_root.add_child(forearm)
	
	# Fabric Cuff Hem
	var cuff_hem = MeshInstance3D.new()
	var torus_hem = TorusMesh.new()
	torus_hem.inner_radius = 0.046
	torus_hem.outer_radius = 0.054
	torus_hem.rings = 24
	torus_hem.ring_segments = 20
	torus_hem.material = mat_cuff
	cuff_hem.mesh = torus_hem
	cuff_hem.rotation_degrees.x = 90.0
	cuff_hem.position = Vector3(0.0, 0.022, 0.04)
	hand_root.add_child(cuff_hem)
	
	# Watch / Cufflink
	var watch = MeshInstance3D.new()
	var cyl_w = CylinderMesh.new()
	cyl_w.top_radius = 0.051
	cyl_w.bottom_radius = 0.051
	cyl_w.height = 0.02
	cyl_w.radial_segments = 24
	cyl_w.material = mat_metal
	watch.mesh = cyl_w
	watch.rotation_degrees.x = 90.0
	watch.position = Vector3(0.0, 0.022, 0.045)
	hand_root.add_child(watch)
	
	# Wrist Joint
	var wrist = MeshInstance3D.new()
	var sph_wrist = SphereMesh.new()
	sph_wrist.radius = 0.040
	sph_wrist.height = 0.048
	sph_wrist.radial_segments = 20
	sph_wrist.rings = 10
	sph_wrist.material = mat_skin
	wrist.mesh = sph_wrist
	wrist.position = Vector3(0.0, 0.016, 0.01)
	wrist.scale = Vector3(1.15, 0.65, 0.9)
	hand_root.add_child(wrist)
	
	# --- Palm Structure (Smooth Fleshy Contour) ---
	palm_root = Node3D.new()
	palm_root.name = "Palm"
	palm_root.position = Vector3(0.0, 0.014, -0.055)
	hand_root.add_child(palm_root)
	
	# Central Palm Body
	var palm_mesh = MeshInstance3D.new()
	var cap_palm = CapsuleMesh.new()
	cap_palm.radius = 0.026
	cap_palm.height = 0.088
	cap_palm.radial_segments = 20
	cap_palm.rings = 6
	cap_palm.material = mat_skin
	palm_mesh.mesh = cap_palm
	palm_mesh.rotation_degrees = Vector3(90.0, 0.0, 90.0)
	palm_mesh.scale = Vector3(0.85, 1.0, 0.75)
	palm_root.add_child(palm_mesh)
	
	# Fleshy Thenar Eminence (Thumb Ball Cushion)
	var thenar = MeshInstance3D.new()
	var sph_thenar = SphereMesh.new()
	sph_thenar.radius = 0.026
	sph_thenar.height = 0.048
	sph_thenar.radial_segments = 16
	sph_thenar.rings = 8
	sph_thenar.material = mat_skin
	thenar.mesh = sph_thenar
	thenar.position = Vector3(-0.032, -0.006, 0.015)
	thenar.scale = Vector3(1.0, 0.8, 1.3)
	palm_root.add_child(thenar)
	
	# Hypothenar Cushion (Outer palm edge)
	var hypothenar = MeshInstance3D.new()
	hypothenar.mesh = sph_thenar
	hypothenar.position = Vector3(0.034, -0.005, 0.01)
	hypothenar.scale = Vector3(0.8, 0.75, 1.2)
	palm_root.add_child(hypothenar)

	# --- 5 Organic Fingers with Smooth Capsules and Knuckle Spheres ---
	
	# 1. THUMB (Opposed inward to pinch game piece)
	thumb_root = Node3D.new()
	thumb_root.position = Vector3(-0.040, -0.002, -0.032)
	thumb_root.rotation_degrees = Vector3(-10.0, -38.0, -28.0)
	hand_root.add_child(thumb_root)
	
	var thumb_mcp = _create_knuckle_sphere(0.015, mat_skin)
	thumb_root.add_child(thumb_mcp)
	
	var thumb_p1 = _create_smooth_phalanx(0.0135, 0.038, mat_skin)
	thumb_p1.position = Vector3(0.0, -0.005, -0.018)
	thumb_root.add_child(thumb_p1)
	
	thumb_tip = Node3D.new()
	thumb_tip.position = Vector3(0.004, -0.012, -0.036)
	thumb_tip.rotation_degrees = Vector3(28.0, 10.0, 0.0)
	thumb_root.add_child(thumb_tip)
	
	var thumb_pip = _create_knuckle_sphere(0.0125, mat_skin)
	thumb_tip.add_child(thumb_pip)
	
	var thumb_p2 = _create_smooth_phalanx(0.0118, 0.032, mat_skin)
	thumb_p2.position = Vector3(0.0, 0.0, -0.014)
	thumb_tip.add_child(thumb_p2)
	
	var th_nail = _create_fingernail(0.012, 0.014, mat_nail)
	th_nail.position = Vector3(0.0, 0.007, -0.022)
	th_nail.rotation_degrees.x = -15.0
	thumb_tip.add_child(th_nail)

	# 2. INDEX FINGER (Forefinger - curving down to meet thumb in pinch)
	index_root = Node3D.new()
	index_root.position = Vector3(-0.032, 0.015, -0.098)
	index_root.rotation_degrees = Vector3(36.0, -8.0, 0.0)
	hand_root.add_child(index_root)
	
	var idx_mcp = _create_knuckle_sphere(0.014, mat_skin)
	index_root.add_child(idx_mcp)
	
	var idx_p1 = _create_smooth_phalanx(0.0125, 0.040, mat_skin)
	idx_p1.position = Vector3(0.0, 0.0, -0.020)
	index_root.add_child(idx_p1)
	
	index_tip = Node3D.new()
	index_tip.position = Vector3(0.0, -0.014, -0.040)
	index_tip.rotation_degrees = Vector3(34.0, 0.0, 0.0)
	index_root.add_child(index_tip)
	
	var idx_pip = _create_knuckle_sphere(0.0118, mat_skin)
	index_tip.add_child(idx_pip)
	
	var idx_p2 = _create_smooth_phalanx(0.0110, 0.034, mat_skin)
	idx_p2.position = Vector3(0.0, 0.0, -0.016)
	index_tip.add_child(idx_p2)
	
	var idx_nail = _create_fingernail(0.011, 0.013, mat_nail)
	idx_nail.position = Vector3(0.0, 0.007, -0.024)
	index_tip.add_child(idx_nail)

	# 3. MIDDLE FINGER (Supporting piece from side)
	middle_root = Node3D.new()
	middle_root.position = Vector3(-0.010, 0.015, -0.100)
	middle_root.rotation_degrees = Vector3(40.0, 2.0, 0.0)
	hand_root.add_child(middle_root)
	
	var mid_mcp = _create_knuckle_sphere(0.0145, mat_skin)
	middle_root.add_child(mid_mcp)
	
	var mid_p1 = _create_smooth_phalanx(0.0130, 0.044, mat_skin)
	mid_p1.position = Vector3(0.0, 0.0, -0.022)
	middle_root.add_child(mid_p1)
	
	var mid_tip = Node3D.new()
	mid_tip.position = Vector3(0.0, -0.015, -0.044)
	mid_tip.rotation_degrees = Vector3(36.0, 0.0, 0.0)
	middle_root.add_child(mid_tip)
	
	var mid_pip = _create_knuckle_sphere(0.0122, mat_skin)
	mid_tip.add_child(mid_pip)
	
	var mid_p2 = _create_smooth_phalanx(0.0115, 0.036, mat_skin)
	mid_p2.position = Vector3(0.0, 0.0, -0.017)
	mid_tip.add_child(mid_p2)
	
	var mid_nail = _create_fingernail(0.0115, 0.014, mat_nail)
	mid_nail.position = Vector3(0.0, 0.007, -0.025)
	mid_tip.add_child(mid_nail)

	# 4. RING FINGER (Curled naturally into palm)
	ring_root = Node3D.new()
	ring_root.position = Vector3(0.013, 0.014, -0.096)
	ring_root.rotation_degrees = Vector3(54.0, 8.0, 0.0)
	hand_root.add_child(ring_root)
	
	var ring_mcp = _create_knuckle_sphere(0.0135, mat_skin)
	ring_root.add_child(ring_mcp)
	
	var ring_p1 = _create_smooth_phalanx(0.0120, 0.038, mat_skin)
	ring_p1.position = Vector3(0.0, 0.0, -0.019)
	ring_root.add_child(ring_p1)
	
	var ring_tip = Node3D.new()
	ring_tip.position = Vector3(0.0, -0.015, -0.038)
	ring_tip.rotation_degrees = Vector3(44.0, 0.0, 0.0)
	ring_root.add_child(ring_tip)
	
	var ring_pip = _create_knuckle_sphere(0.0112, mat_skin)
	ring_tip.add_child(ring_pip)
	
	var ring_p2 = _create_smooth_phalanx(0.0105, 0.030, mat_skin)
	ring_p2.position = Vector3(0.0, 0.0, -0.015)
	ring_tip.add_child(ring_p2)
	
	var ring_nail = _create_fingernail(0.0105, 0.012, mat_nail)
	ring_nail.position = Vector3(0.0, 0.007, -0.021)
	ring_tip.add_child(ring_nail)

	# 5. PINKY FINGER (Gracefully curled)
	pinky_root = Node3D.new()
	pinky_root.position = Vector3(0.034, 0.012, -0.090)
	pinky_root.rotation_degrees = Vector3(62.0, 14.0, 0.0)
	hand_root.add_child(pinky_root)
	
	var pnk_mcp = _create_knuckle_sphere(0.0125, mat_skin)
	pinky_root.add_child(pnk_mcp)
	
	var pnk_p1 = _create_smooth_phalanx(0.0108, 0.032, mat_skin)
	pnk_p1.position = Vector3(0.0, 0.0, -0.016)
	pinky_root.add_child(pnk_p1)
	
	var pnk_tip = Node3D.new()
	pnk_tip.position = Vector3(0.0, -0.015, -0.032)
	pnk_tip.rotation_degrees = Vector3(48.0, 0.0, 0.0)
	pinky_root.add_child(pnk_tip)
	
	var pnk_pip = _create_knuckle_sphere(0.0100, mat_skin)
	pnk_tip.add_child(pnk_pip)
	
	var pnk_p2 = _create_smooth_phalanx(0.0095, 0.025, mat_skin)
	pnk_p2.position = Vector3(0.0, 0.0, -0.012)
	pnk_tip.add_child(pnk_p2)
	
	var pnk_nail = _create_fingernail(0.0095, 0.011, mat_nail)
	pnk_nail.position = Vector3(0.0, 0.006, -0.018)
	pnk_tip.add_child(pnk_nail)

# --- Helper Mesh Builders ---

func _create_smooth_phalanx(radius: float, length: float, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = radius
	cap.height = length
	cap.radial_segments = 16
	cap.rings = 4
	cap.material = mat
	inst.mesh = cap
	inst.rotation_degrees.x = 90.0
	return inst

func _create_knuckle_sphere(radius: float, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 14
	sph.rings = 6
	sph.material = mat
	inst.mesh = sph
	return inst

func _create_fingernail(width: float, length: float, mat: Material) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(width, 0.003, length)
	box.material = mat
	inst.mesh = box
	return inst

# --- Natural Piece Placement Animation ---

func play_place_piece(target_world_pos: Vector3, piece_node: Node3D, on_dropped: Callable) -> void:
	is_animating = true
	visible = true
	
	var start_pos = Vector3.ZERO
	var start_rot = Vector3.ZERO
	var hover_rot = Vector3.ZERO
	
	if is_enemy:
		start_pos = Vector3(target_world_pos.x * 0.4 + 0.10, 0.26, -1.05)
		start_rot = Vector3(-16.0, 180.0, 4.0)
		hover_rot = Vector3(-8.0, 180.0, 0.0)
	else:
		start_pos = Vector3(target_world_pos.x * 0.4 + 0.12, 0.22, 1.15)
		start_rot = Vector3(16.0, 0.0, -4.0)
		hover_rot = Vector3(8.0, 0.0, 0.0)
		
	global_position = start_pos
	global_rotation_degrees = start_rot
	
	var hover_pos = Vector3(target_world_pos.x, target_world_pos.y + 0.15, target_world_pos.z)
	var touch_pos = Vector3(target_world_pos.x, target_world_pos.y + 0.034, target_world_pos.z)
	
	if piece_node:
		piece_node.global_position = hover_pos
		piece_node.visible = true
		
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 1. Sweep in to hover right above the cell
	tw.tween_property(self, "global_position", hover_pos, 0.24)
	tw.parallel().tween_property(self, "global_rotation_degrees", hover_rot, 0.24)
	if piece_node:
		tw.parallel().tween_property(piece_node, "global_position", hover_pos, 0.24)
		
	# 2. Lower firmly onto cell
	tw.chain().tween_property(self, "global_position", touch_pos, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if piece_node:
		tw.parallel().tween_property(piece_node, "global_position", target_world_pos, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
	# 3. Touchdown callback + fingers release piece
	tw.chain().tween_callback(func():
		_open_fingers_release()
		if on_dropped.is_valid():
			on_dropped.call()
	)
	
	# 4. Lift and glide back off-screen
	var lift_pos = touch_pos + Vector3(0.0, 0.12, -0.12 if is_enemy else 0.12)
	tw.tween_property(self, "global_position", lift_pos, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "global_position", start_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "global_rotation_degrees", start_rot, 0.25)
	
	tw.chain().tween_callback(func():
		_close_fingers_grip()
		visible = false
		is_animating = false
	)

func _open_fingers_release() -> void:
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(thumb_root, "rotation_degrees:y", -20.0, 0.08)
	tw.tween_property(index_root, "rotation_degrees:x", 24.0, 0.08)

func _close_fingers_grip() -> void:
	thumb_root.rotation_degrees = Vector3(-10.0, -38.0, -28.0)
	index_root.rotation_degrees = Vector3(36.0, -8.0, 0.0)