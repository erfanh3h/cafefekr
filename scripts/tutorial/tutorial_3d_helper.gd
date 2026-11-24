class_name Tutorial3DHelper
extends RefCounted

## Shared 3D tutorial utilities for all inherited Tutorial<Game>3D boards:
## - Golden pulsing beacon material & torus ring creation
## - 3D-to-2D viewport projection for TutorialCoachOverlay spotlights
## - Board bounding-box screen rect calculation for avoid_rect


static func create_beacon_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.28, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.80, 0.18)
	mat.emission_energy_multiplier = 2.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mat.metallic = 0.4
	return mat


static func spawn_ring_beacon(
	parent_node: Node3D,
	inner_radius: float,
	outer_radius: float,
	y_offset: float,
	mat: StandardMaterial3D,
	beacon_name: String = "TutorialBeacon"
) -> MeshInstance3D:
	if not is_instance_valid(parent_node):
		return null
	var ring := MeshInstance3D.new()
	ring.name = beacon_name
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 24
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0.0, y_offset, 0.0)
	parent_node.add_child(ring)
	return ring


static func animate_beacons(
	beacon_nodes: Dictionary,
	beacon_mat: StandardMaterial3D,
	pulse_time: float,
	base_y: float = 0.042,
	amp_y: float = 0.010
) -> void:
	var s: float = 1.0 + 0.09 * sin(pulse_time * 5.2)
	var y_off: float = base_y + amp_y * sin(pulse_time * 5.2)
	if beacon_mat != null:
		beacon_mat.emission_energy_multiplier = 2.1 + 0.9 * sin(pulse_time * 5.2)
	for k in beacon_nodes.keys():
		var ring: MeshInstance3D = beacon_nodes[k] as MeshInstance3D
		if is_instance_valid(ring):
			ring.scale = Vector3(s, 1.0, s)
			ring.position.y = y_off


static func project_world_box_rect(
	viewport: Viewport,
	center_world: Vector3,
	half_x: float,
	half_z: float,
	min_px: float = 48.0
) -> Rect2:
	if viewport == null:
		return Rect2()
	var cam: Camera3D = viewport.get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		return Rect2()
	if cam.is_position_behind(center_world):
		return Rect2()

	var corners: Array[Vector3] = [
		center_world + Vector3(-half_x, 0.0, -half_z),
		center_world + Vector3(half_x, 0.0, -half_z),
		center_world + Vector3(half_x, 0.0, half_z),
		center_world + Vector3(-half_x, 0.0, half_z)
	]

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pt in corners:
		if cam.is_position_behind(pt):
			return Rect2()
		var sp: Vector2 = cam.unproject_position(pt)
		min_p.x = minf(min_p.x, sp.x)
		min_p.y = minf(min_p.y, sp.y)
		max_p.x = maxf(max_p.x, sp.x)
		max_p.y = maxf(max_p.y, sp.y)

	var rect_size: Vector2 = max_p - min_p
	if rect_size.x < min_px:
		var cx: float = (min_p.x + max_p.x) * 0.5
		min_p.x = cx - (min_px * 0.5)
		rect_size.x = min_px
	if rect_size.y < min_px:
		var cy: float = (min_p.y + max_p.y) * 0.5
		min_p.y = cy - (min_px * 0.5)
		rect_size.y = min_px
	return Rect2(min_p, rect_size)


static func get_board_bounds_rect(
	viewport: Viewport,
	board_global_pos: Vector3,
	half_extent: float,
	y_offset: float = 0.04
) -> Rect2:
	var center_w: Vector3 = board_global_pos + Vector3(0.0, y_offset, 0.0)
	var r: Rect2 = project_world_box_rect(viewport, center_w, half_extent, half_extent, 12.0)
	if r.size.x <= 12.0 or r.size.y <= 12.0:
		return Rect2()
	return r
