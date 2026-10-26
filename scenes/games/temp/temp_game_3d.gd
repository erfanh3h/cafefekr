class_name TempGame3D
extends "res://scripts/games/base_game_board.gd"

# Placeholder 3D Board for Coming-Soon Games in Cafe Fekr
# Renders an illuminated 3D artwork easel with Persian game title and status message.

const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")

var _anim_time: float = 0.0
var _stand: Node3D = null

func _ready() -> void:
	game_type = GameManager.current_game_type
	_build_temp_board()
	super._ready()

func _process(delta: float) -> void:
	_anim_time += delta * 1.8
	if is_instance_valid(_stand):
		_stand.position.y = 0.03 + sin(_anim_time) * 0.005

func _build_temp_board() -> void:
	var info = GameRegistry.get_game_info(game_type)
	var game_name_fa = info.get("name_fa", GameTypes.get_display_name_fa(game_type))
	var icon_path = str(info.get("icon", ""))

	# 1. Base Mahogany Plinth
	var base_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.10, 0.03, 0.90)
	base_mesh.mesh = box
	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.20, 0.12, 0.07)
	mat_wood.roughness = 0.40
	base_mesh.material_override = mat_wood
	base_mesh.position = Vector3(0, 0.015, 0)
	add_child(base_mesh)

	# 2. 24K Gold Trim Rim
	var trim_mesh = MeshInstance3D.new()
	var trim_box = BoxMesh.new()
	trim_box.size = Vector3(1.14, 0.012, 0.94)
	trim_mesh.mesh = trim_box
	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.92, 0.75, 0.25)
	mat_gold.metallic = 0.90
	mat_gold.roughness = 0.18
	trim_mesh.material_override = mat_gold
	trim_mesh.position = Vector3(0, 0.024, 0)
	add_child(trim_mesh)

	# 3. Inner Velvet Cushion
	var velvet_mesh = MeshInstance3D.new()
	var v_box = BoxMesh.new()
	v_box.size = Vector3(1.04, 0.010, 0.84)
	velvet_mesh.mesh = v_box
	var mat_velvet = StandardMaterial3D.new()
	mat_velvet.albedo_color = Color(0.08, 0.10, 0.15)
	mat_velvet.roughness = 0.85
	velvet_mesh.material_override = mat_velvet
	velvet_mesh.position = Vector3(0, 0.026, 0)
	add_child(velvet_mesh)

	# 4. Display Easel / Artwork Stand
	_stand = Node3D.new()
	_stand.name = "ArtworkStand"
	_stand.position = Vector3(0, 0.03, -0.05)
	add_child(_stand)

	var art_quad = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.48, 0.36)
	art_quad.mesh = quad

	var mat_art = StandardMaterial3D.new()
	mat_art.roughness = 0.30
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		mat_art.albedo_texture = load(icon_path)
	art_quad.material_override = mat_art
	art_quad.position = Vector3(0, 0.22, 0)
	art_quad.rotation_degrees = Vector3(-20, 0, 0)
	_stand.add_child(art_quad)

	# Gold Frame around Artwork
	var frame = MeshInstance3D.new()
	var frame_box = BoxMesh.new()
	frame_box.size = Vector3(0.51, 0.39, 0.015)
	frame.mesh = frame_box
	frame.material_override = mat_gold
	frame.position = Vector3(0, 0.22, -0.01)
	frame.rotation_degrees = Vector3(-20, 0, 0)
	_stand.add_child(frame)

	# 5. Persian 3D Game Title Label
	var title_lbl = Label3D.new()
	title_lbl.text = game_name_fa
	title_lbl.font = _FONT_FA
	title_lbl.font_size = 54
	title_lbl.pixel_size = 0.00085
	title_lbl.modulate = Color(1.0, 0.92, 0.65)
	title_lbl.outline_size = 5
	title_lbl.outline_modulate = Color(0.12, 0.06, 0.02)
	title_lbl.rotation_degrees = Vector3(-90, 0, 0)
	title_lbl.position = Vector3(0, 0.032, 0.22)
	add_child(title_lbl)

	# 6. Coming Soon Status Label
	var banner_lbl = Label3D.new()
	banner_lbl.text = "این بازی به زودی در کافه فکر فعال خواهد شد"
	banner_lbl.font = _FONT_FA
	banner_lbl.font_size = 30
	banner_lbl.pixel_size = 0.00075
	banner_lbl.modulate = Color(0.95, 0.75, 0.35)
	banner_lbl.outline_size = 3
	banner_lbl.outline_modulate = Color(0.10, 0.05, 0.02)
	banner_lbl.rotation_degrees = Vector3(-90, 0, 0)
	banner_lbl.position = Vector3(0, 0.032, 0.32)
	add_child(banner_lbl)

func setup_board(_game_data: Dictionary) -> void:
	pass

func on_new_round(_round_num: int) -> void:
	pass

func reset_board() -> void:
	pass

func cleanup_board() -> void:
	pass
