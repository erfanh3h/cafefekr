class_name Risk3DFactory
extends RefCounted

# Premium 3D Tabletop Geometry & Component Builder for Risk Strike
# Builds the antique walnut table border, central board, raised 3D continents,
# 3D player stations around the table, 3D cards, 3D domination tokens, and 3D dice.

const CONTINENT_META: Dictionary = {
	"Asia": {
		"fa": "آسیا",
		"pos": Vector3(0.35, 0.048, -0.23),
		"radius": 0.132,
	},
	"NorthAmerica": {
		"fa": "آمریکای شمالی",
		"pos": Vector3(-0.35, 0.048, -0.23),
		"radius": 0.132,
	},
	"Europe": {
		"fa": "اروپا",
		"pos": Vector3(0.00, 0.048, -0.26),
		"radius": 0.126,
	},
	"Africa": {
		"fa": "آفریقا",
		"pos": Vector3(0.00, 0.048, 0.14),
		"radius": 0.126,
	},
	"Australia": {
		"fa": "اقیانوسیه",
		"pos": Vector3(0.35, 0.048, 0.12),
		"radius": 0.124,
	},
	"SouthAmerica": {
		"fa": "آمریکای جنوبی",
		"pos": Vector3(-0.35, 0.048, 0.12),
		"radius": 0.124,
	},
}

const CONTINENT_ADJACENCY: Dictionary = {
	"NorthAmerica": ["SouthAmerica", "Europe", "Asia"],
	"SouthAmerica": ["NorthAmerica", "Africa"],
	"Europe": ["NorthAmerica", "Africa", "Asia"],
	"Africa": ["SouthAmerica", "Europe", "Asia", "Australia"],
	"Asia": ["NorthAmerica", "Europe", "Africa", "Australia"],
	"Australia": ["Asia", "Africa"],
}

const STRATEGY_META: Dictionary = {
	"Army": {
		"fa": "ارتش کمکی",
		"short": "+۱ تاس نبرد / ۱ قاره",
		"desc": "در نبرد +۱ تاس اضافه می‌دهد، یا خارج از نبرد ۱ کارت قاره می‌کشد.",
		"color": Color(0.88, 0.24, 0.22),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Backup": {
		"fa": "پشتیبانی لجستیک",
		"short": "دریافت ۲ کارت قاره",
		"desc": "فوراً ۲ کارت قاره از دسته به دست شما اضافه می‌کند.",
		"color": Color(0.20, 0.66, 0.92),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Expand": {
		"fa": "پیشروی سریع",
		"short": "۱ قاره + حمله آزاد",
		"desc": "۱ کارت قاره می‌کشد و تا پایان نوبت محدودیت هم‌مرزی قاره‌ها را برمی‌دارد.",
		"color": Color(0.22, 0.80, 0.46),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Bomb": {
		"fa": "بمباران تاکتیکی",
		"short": "حذف ۲ استراتژی حریف",
		"desc": "تا ۲ کارت استراتژی (یا ۱ کارت قاره) از دست حریف انتخابی حذف می‌کند.",
		"color": Color(0.95, 0.46, 0.16),
		"needs_target_player": true,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Destroy": {
		"fa": "تخریب پایگاه",
		"short": "حذف ۱ کارت قاره حریف",
		"desc": "۱ کارت قاره مشخص از قاره‌های حریف انتخابی را نابود می‌کند.",
		"color": Color(0.84, 0.18, 0.34),
		"needs_target_player": true,
		"needs_target_continent": true,
		"combat_only": false,
	},
	"Spy": {
		"fa": "جاسوس نفوذی",
		"short": "سرقت ۱ کارت از حریف",
		"desc": "۱ کارت تصادفی از دست حریف انتخابی سرقت کرده و به دست شما می‌دهد.",
		"color": Color(0.62, 0.32, 0.90),
		"needs_target_player": true,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Canon": {
		"fa": "توپخانه سنگین",
		"short": "+۱ به بالاترین تاس",
		"desc": "به بالاترین تاس شما در نبرد فعلی یا نبرد بعدی +۱ امتیاز اضافه می‌کند.",
		"color": Color(0.92, 0.72, 0.18),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Cancel": {
		"fa": "لغو تهاجم",
		"short": "لغو کامل حمله دشمن",
		"desc": "در زمان دفاع، حمله فعلی دشمن را فوراً لغو و بدون تلفات متوقف می‌کند.",
		"color": Color(0.24, 0.84, 0.88),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": true,
	},
}

static func fa_digits(input: Variant) -> String:
	var s = str(input)
	var en = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(en[i], fa[i])
	return s

static func build_tabletop_and_board_frame(parent: Node3D, mats: Dictionary, font: Font) -> Dictionary:
	var refs: Dictionary = {}
	var root = Node3D.new()
	root.name = "TableAndBoardArchitecture"
	parent.add_child(root)
	refs["root"] = root

	# 1. Rich Dark Walnut Outer Tabletop Surface Surround
	var table_slab = MeshInstance3D.new()
	var slab_box = BoxMesh.new()
	slab_box.size = Vector3(1.56, 0.026, 1.56)
	slab_box.material = mats["walnut"]
	table_slab.mesh = slab_box
	table_slab.position = Vector3(0.0, 0.013, 0.0)
	table_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(table_slab)

	# Carved Outer Mahogany Moulding Rails + Antique Brass Trim
	var rail_specs = [
		{"pos": Vector3(0.0, 0.032, -0.765), "size": Vector3(1.58, 0.022, 0.036)},
		{"pos": Vector3(0.0, 0.032, 0.765), "size": Vector3(1.58, 0.022, 0.036)},
		{"pos": Vector3(-0.772, 0.032, 0.0), "size": Vector3(0.036, 0.022, 1.50)},
		{"pos": Vector3(0.772, 0.032, 0.0), "size": Vector3(0.036, 0.022, 1.50)},
	]
	for spec in rail_specs:
		var r_mi = MeshInstance3D.new()
		var r_bm = BoxMesh.new()
		r_bm.size = spec["size"]
		r_bm.material = mats["mahogany"]
		r_mi.mesh = r_bm
		r_mi.position = spec["pos"]
		r_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(r_mi)

		var b_mi = MeshInstance3D.new()
		var b_bm = BoxMesh.new()
		b_bm.size = Vector3(spec["size"].x * 0.98, 0.004, spec["size"].z * 0.98)
		b_bm.material = mats["brass"]
		b_mi.mesh = b_bm
		b_mi.position = spec["pos"] + Vector3(0.0, 0.012, 0.0)
		b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b_mi)

	# 4 Decorative Brass Corner Medallions on Table Corners
	for cx in [-0.76, 0.76]:
		for cz in [-0.755, 0.755]:
			var c_mi = MeshInstance3D.new()
			var c_cyl = CylinderMesh.new()
			c_cyl.top_radius = 0.028
			c_cyl.bottom_radius = 0.032
			c_cyl.height = 0.028
			c_cyl.radial_segments = 20
			c_cyl.material = mats["brass"]
			c_mi.mesh = c_cyl
			c_mi.position = Vector3(cx, 0.033, cz)
			root.add_child(c_mi)

	# 2. Central Raised Physical Game Board (Placed physically on top of the walnut table)
	var board_frame = MeshInstance3D.new()
	var bf_box = BoxMesh.new()
	bf_box.size = Vector3(1.12, 0.034, 0.78)
	bf_box.material = mats["mahogany"]
	board_frame.mesh = bf_box
	board_frame.position = Vector3(0.0, 0.030, -0.05)
	root.add_child(board_frame)

	# Brushed Brass Inner Frame Bezel around the Central Board
	var bezel_specs = [
		{"pos": Vector3(0.0, 0.049, -0.430), "size": Vector3(1.08, 0.008, 0.018)},
		{"pos": Vector3(0.0, 0.049, 0.330), "size": Vector3(1.08, 0.008, 0.018)},
		{"pos": Vector3(-0.532, 0.049, -0.05), "size": Vector3(0.018, 0.008, 0.74)},
		{"pos": Vector3(0.532, 0.049, -0.05), "size": Vector3(0.018, 0.008, 0.74)},
	]
	for bspec in bezel_specs:
		var bz_mi = MeshInstance3D.new()
		var bz_bm = BoxMesh.new()
		bz_bm.size = bspec["size"]
		bz_bm.material = mats["brass"]
		bz_mi.mesh = bz_bm
		bz_mi.position = bspec["pos"]
		root.add_child(bz_mi)

	# Dark Emerald Green Baize Velvet Playing Surface
	var velvet_bed = MeshInstance3D.new()
	var vb_box = BoxMesh.new()
	vb_box.size = Vector3(1.05, 0.006, 0.72)
	vb_box.material = mats["emerald_velvet"]
	velvet_bed.mesh = vb_box
	velvet_bed.position = Vector3(0.0, 0.046, -0.05)
	velvet_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(velvet_bed)

	# Engraved Brass World Latitude / Longitude Rings on the Emerald Board Bed
	for ring_r in [0.16, 0.29]:
		var ring_mi = MeshInstance3D.new()
		var ring_torus = TorusMesh.new()
		ring_torus.inner_radius = ring_r
		ring_torus.outer_radius = ring_r + 0.004
		ring_torus.rings = 32
		ring_torus.ring_segments = 12
		ring_torus.material = mats["bronze"]
		ring_mi.mesh = ring_torus
		ring_mi.position = Vector3(0.0, 0.049, -0.05)
		ring_mi.scale = Vector3(1.35, 1.0, 1.0)
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring_mi)

	# 3. Central 3D Octagonal Leather & Brass Dice Arena (Center of the Board)
	var dice_arena = Node3D.new()
	dice_arena.name = "CentralDiceArena"
	dice_arena.position = Vector3(0.0, 0.050, -0.05)
	root.add_child(dice_arena)
	refs["dice_arena"] = dice_arena

	var arena_rim = MeshInstance3D.new()
	var ar_cyl = CylinderMesh.new()
	ar_cyl.top_radius = 0.095
	ar_cyl.bottom_radius = 0.102
	ar_cyl.height = 0.014
	ar_cyl.radial_segments = 8
	ar_cyl.material = mats["brass"]
	arena_rim.mesh = ar_cyl
	arena_rim.position = Vector3(0.0, 0.007, 0.0)
	dice_arena.add_child(arena_rim)

	var arena_bed = MeshInstance3D.new()
	var ab_cyl = CylinderMesh.new()
	ab_cyl.top_radius = 0.084
	ab_cyl.bottom_radius = 0.084
	ab_cyl.height = 0.016
	ab_cyl.radial_segments = 8
	ab_cyl.material = mats["leather"]
	arena_bed.mesh = ab_cyl
	arena_bed.position = Vector3(0.0, 0.0075, 0.0)
	dice_arena.add_child(arena_bed)

	var arena_lbl = Label3D.new()
	arena_lbl.text = "⚔️ میدان تاس"
	if font:
		arena_lbl.font = font
	arena_lbl.font_size = 38
	arena_lbl.pixel_size = 0.0012
	arena_lbl.modulate = Color(1.0, 0.88, 0.50, 0.96)
	arena_lbl.outline_size = 9
	arena_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	arena_lbl.rotation_degrees = Vector3(-78.0, 0.0, 0.0)
	arena_lbl.position = Vector3(0.0, 0.022, 0.068)
	dice_arena.add_child(arena_lbl)

	# 4. Left & Right 3D Draw Decks on the Board
	refs["continent_deck"] = _build_draw_deck(
		root,
		Vector3(-0.18, 0.050, -0.05),
		"continent",
		"🗺️ دسته قاره",
		Color(0.12, 0.46, 0.30),
		mats,
		font
	)
	refs["strategy_deck"] = _build_draw_deck(
		root,
		Vector3(0.18, 0.050, -0.05),
		"strategy",
		"⚡ دسته استراتژی",
		Color(0.54, 0.16, 0.18),
		mats,
		font
	)

	return refs

static func _build_draw_deck(
	parent: Node3D,
	pos: Vector3,
	deck_type: String,
	title_fa: String,
	back_col: Color,
	mats: Dictionary,
	font: Font
) -> Dictionary:
	var deck_root = Node3D.new()
	deck_root.name = "Deck_" + deck_type
	deck_root.position = pos
	parent.add_child(deck_root)

	# Brass Card Shoe / Tray Base
	var tray_mi = MeshInstance3D.new()
	var tray_bm = BoxMesh.new()
	tray_bm.size = Vector3(0.104, 0.006, 0.138)
	tray_bm.material = mats["bronze"]
	tray_mi.mesh = tray_bm
	tray_mi.position = Vector3(0.0, 0.003, 0.0)
	deck_root.add_child(tray_mi)

	# Layered 3D Card Stack
	var stack_node = Node3D.new()
	stack_node.name = "CardStackVisual"
	deck_root.add_child(stack_node)

	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = back_col
	top_mat.roughness = 0.36
	top_mat.metallic = 0.14

	var card_layers: Array = []
	for i in range(10):
		var layer_mi = MeshInstance3D.new()
		var layer_bm = BoxMesh.new()
		layer_bm.size = Vector3(0.090, 0.0026, 0.122)
		layer_bm.material = mats["parchment"] if i < 9 else top_mat
		layer_mi.mesh = layer_bm
		layer_mi.position = Vector3(0.0, 0.008 + float(i) * 0.0028, 0.0)
		stack_node.add_child(layer_mi)
		card_layers.append(layer_mi)

	# Brass Filigree Frame on Top Card
	var crest_mi = MeshInstance3D.new()
	var crest_cyl = CylinderMesh.new()
	crest_cyl.top_radius = 0.022
	crest_cyl.bottom_radius = 0.022
	crest_cyl.height = 0.003
	crest_cyl.radial_segments = 16
	crest_cyl.material = mats["gold"]
	crest_mi.mesh = crest_cyl
	crest_mi.position = Vector3(0.0, 0.036, -0.012)
	stack_node.add_child(crest_mi)

	# Selection / Draw Ready Glow Frame
	var glow_mi = MeshInstance3D.new()
	var glow_bm = BoxMesh.new()
	glow_bm.size = Vector3(0.114, 0.004, 0.148)
	glow_bm.material = mats["glow_gold"]
	glow_mi.mesh = glow_bm
	glow_mi.position = Vector3(0.0, 0.004, 0.0)
	glow_mi.visible = false
	deck_root.add_child(glow_mi)

	# Large, Readable Live Count Label3D
	var count_lbl = Label3D.new()
	count_lbl.text = "۴۲"
	if font:
		count_lbl.font = font
	count_lbl.font_size = 54
	count_lbl.pixel_size = 0.00135
	count_lbl.modulate = Color(1.0, 0.96, 0.80)
	count_lbl.outline_size = 11
	count_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	count_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	count_lbl.position = Vector3(0.0, 0.068, 0.0)
	deck_root.add_child(count_lbl)

	var title_lbl = Label3D.new()
	title_lbl.text = title_fa
	if font:
		title_lbl.font = font
	title_lbl.font_size = 38
	title_lbl.pixel_size = 0.00125
	title_lbl.modulate = Color(1.0, 0.90, 0.56)
	title_lbl.outline_size = 9
	title_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	title_lbl.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	title_lbl.position = Vector3(0.0, 0.018, 0.088)
	deck_root.add_child(title_lbl)

	# Interactive Area3D for clicking the 3D Deck directly
	var area = Area3D.new()
	area.name = "DeckHitArea"
	area.set_meta("interact_type", "deck")
	area.set_meta("deck_type", deck_type)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.12, 0.07, 0.16)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.030, 0.0)
	area.add_child(col)
	deck_root.add_child(area)

	return {
		"root": deck_root,
		"stack": stack_node,
		"layers": card_layers,
		"crest": crest_mi,
		"glow": glow_mi,
		"count_lbl": count_lbl,
	}

static func build_sea_lane_bridges(parent: Node3D, mats: Dictionary) -> Dictionary:
	var bridges: Dictionary = {}
	var bridges_root = Node3D.new()
	bridges_root.name = "SeaLaneBridges"
	parent.add_child(bridges_root)

	var built_pairs: Dictionary = {}
	for c_a in CONTINENT_ADJACENCY.keys():
		for c_b in CONTINENT_ADJACENCY[c_a]:
			var pair_key = (c_a + "_" + c_b) if c_a < c_b else (c_b + "_" + c_a)
			if built_pairs.has(pair_key):
				continue
			built_pairs[pair_key] = true
			var pos_a: Vector3 = CONTINENT_META[c_a]["pos"]
			var pos_b: Vector3 = CONTINENT_META[c_b]["pos"]
			var mid = (pos_a + pos_b) * 0.5
			var diff = pos_b - pos_a
			var dist = Vector2(diff.x, diff.z).length()
			var angle_y = atan2(diff.x, diff.z)

			var bridge_mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.014, 0.004, maxf(0.04, dist - 0.22))
			bm.material = mats["bridge_idle"]
			bridge_mi.mesh = bm
			bridge_mi.position = Vector3(mid.x, 0.051, mid.z)
			bridge_mi.rotation.y = angle_y
			bridge_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bridges_root.add_child(bridge_mi)
			bridges[pair_key] = bridge_mi

	return bridges

static func build_continent_node(
	parent: Node3D,
	c_id: String,
	mats: Dictionary,
	font: Font,
	rook_mesh: Mesh,
	knight_mesh: Mesh,
	king_mesh: Mesh
) -> Dictionary:
	var meta: Dictionary = CONTINENT_META[c_id]
	var pos: Vector3 = meta["pos"]
	var rad: float = meta["radius"]
	var cont_mat: StandardMaterial3D = RiskMaterials.get_continent_material(c_id)

	var root = Node3D.new()
	root.name = "Continent_" + c_id
	root.position = pos
	parent.add_child(root)

	# 1. Outer Brass Bezel Platform
	var base_bezel = MeshInstance3D.new()
	var bz_cyl = CylinderMesh.new()
	bz_cyl.top_radius = rad + 0.008
	bz_cyl.bottom_radius = rad + 0.014
	bz_cyl.height = 0.014
	bz_cyl.radial_segments = 32
	bz_cyl.material = mats["bronze"]
	base_bezel.mesh = bz_cyl
	base_bezel.position = Vector3(0.0, 0.007, 0.0)
	root.add_child(base_bezel)

	# 2. Raised Continent Colored Territory Plateau
	var plateau = MeshInstance3D.new()
	var pl_cyl = CylinderMesh.new()
	pl_cyl.top_radius = rad
	pl_cyl.bottom_radius = rad + 0.004
	pl_cyl.height = 0.018
	pl_cyl.radial_segments = 32
	pl_cyl.material = cont_mat
	plateau.mesh = pl_cyl
	plateau.position = Vector3(0.0, 0.010, 0.0)
	root.add_child(plateau)

	# 3. Selection / Valid Target / Attack Aura Ring (TorusMesh)
	var aura_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = rad + 0.009
	torus.outer_radius = rad + 0.024
	torus.rings = 32
	torus.ring_segments = 12
	torus.material = mats["glow_gold"]
	aura_ring.mesh = torus
	aura_ring.position = Vector3(0.0, 0.015, 0.0)
	aura_ring.visible = false
	root.add_child(aura_ring)

	# 4. Central 3D Citadel / Fortress Keep
	var citadel = Node3D.new()
	citadel.name = "CitadelKeep"
	citadel.position = Vector3(0.0, 0.019, -0.015)
	root.add_child(citadel)

	if rook_mesh:
		var keep_mi = MeshInstance3D.new()
		keep_mi.mesh = rook_mesh
		keep_mi.material_override = mats["parchment"]
		keep_mi.scale = Vector3(0.42, 0.42, 0.42)
		citadel.add_child(keep_mi)
	else:
		var fallback_keep = MeshInstance3D.new()
		var fk_cyl = CylinderMesh.new()
		fk_cyl.top_radius = 0.022
		fk_cyl.bottom_radius = 0.026
		fk_cyl.height = 0.045
		fk_cyl.material = mats["parchment"]
		fallback_keep.mesh = fk_cyl
		fallback_keep.position = Vector3(0.0, 0.022, 0.0)
		citadel.add_child(fallback_keep)

	# 5. Unclaimed 3D Continent Domination Token (Gold Medallion + Crown on Pedestal)
	var token_node = build_domination_token_3d(c_id, mats, king_mesh, 1.05)
	token_node.position = Vector3(0.0, 0.070, -0.015)
	root.add_child(token_node)

	# 6. Large Bold Persian Continent Nameplate (Front of Citadel)
	var name_lbl = Label3D.new()
	name_lbl.text = meta["fa"]
	if font:
		name_lbl.font = font
	name_lbl.font_size = 46
	name_lbl.pixel_size = 0.00135
	name_lbl.modulate = Color(1.0, 0.97, 0.86)
	name_lbl.outline_size = 11
	name_lbl.outline_modulate = Color(0.03, 0.02, 0.01, 0.98)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.position = Vector3(0.0, 0.036, rad * 0.72)
	root.add_child(name_lbl)

	# 7. Four Faction Garrison Slots Around the Citadel (for Players 1..4)
	var slot_offsets = {
		1: Vector3(-0.064, 0.020, 0.026),
		2: Vector3(0.064, 0.020, 0.026),
		3: Vector3(-0.064, 0.020, -0.050),
		4: Vector3(0.064, 0.020, -0.050),
	}
	var garrisons: Dictionary = {}
	for p_idx in [1, 2, 3, 4]:
		var g_node = Node3D.new()
		g_node.name = "Garrison_P%d" % p_idx
		g_node.position = slot_offsets[p_idx]
		g_node.visible = false
		root.add_child(g_node)

		var f_mat = RiskMaterials.get_faction_material(p_idx, false)

		var ped_mi = MeshInstance3D.new()
		var ped_cyl = CylinderMesh.new()
		ped_cyl.top_radius = 0.023
		ped_cyl.bottom_radius = 0.026
		ped_cyl.height = 0.008
		ped_cyl.radial_segments = 16
		ped_cyl.material = mats["brass"]
		ped_mi.mesh = ped_cyl
		ped_mi.position = Vector3(0.0, 0.004, 0.0)
		g_node.add_child(ped_mi)

		var piece_mi = MeshInstance3D.new()
		if knight_mesh:
			piece_mi.mesh = knight_mesh
			piece_mi.scale = Vector3(0.35, 0.35, 0.35)
			piece_mi.position = Vector3(0.0, 0.008, 0.0)
		else:
			var sc = SphereMesh.new()
			sc.radius = 0.016
			sc.height = 0.032
			piece_mi.mesh = sc
			piece_mi.position = Vector3(0.0, 0.020, 0.0)
		piece_mi.material_override = f_mat
		g_node.add_child(piece_mi)

		# Large Card Count Badge Above Faction Piece
		var cnt_lbl = Label3D.new()
		cnt_lbl.text = "×۱"
		if font:
			cnt_lbl.font = font
		cnt_lbl.font_size = 48
		cnt_lbl.pixel_size = 0.00135
		cnt_lbl.modulate = RiskMaterials.FACTION_COLORS[p_idx].lightened(0.36)
		cnt_lbl.outline_size = 11
		cnt_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.99)
		cnt_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cnt_lbl.position = Vector3(0.0, 0.076, 0.0)
		g_node.add_child(cnt_lbl)

		garrisons[p_idx] = {
			"node": g_node,
			"piece": piece_mi,
			"label": cnt_lbl,
		}

	# 8. Raycast Area3D for Continent Selection & Attack Targeting
	var area = Area3D.new()
	area.name = "ContinentHitArea"
	area.set_meta("interact_type", "continent")
	area.set_meta("continent", c_id)
	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = rad + 0.018
	cyl_shape.height = 0.095
	col.shape = cyl_shape
	col.position = Vector3(0.0, 0.035, 0.0)
	area.add_child(col)
	root.add_child(area)

	return {
		"root": root,
		"base_pos": pos,
		"plateau": plateau,
		"aura": aura_ring,
		"citadel": citadel,
		"token_node": token_node,
		"name_lbl": name_lbl,
		"garrisons": garrisons,
	}

static func build_domination_token_3d(
	c_id: String,
	mats: Dictionary,
	king_mesh: Mesh,
	scale_mult: float = 1.0
) -> Node3D:
	var token = Node3D.new()
	token.name = "DominationToken_" + c_id
	token.scale = Vector3.ONE * scale_mult

	var coin_mi = MeshInstance3D.new()
	var coin_cyl = CylinderMesh.new()
	coin_cyl.top_radius = 0.022
	coin_cyl.bottom_radius = 0.024
	coin_cyl.height = 0.007
	coin_cyl.radial_segments = 24
	coin_cyl.material = mats["gold"]
	coin_mi.mesh = coin_cyl
	token.add_child(coin_mi)

	var jewel_mi = MeshInstance3D.new()
	var jewel_cyl = CylinderMesh.new()
	jewel_cyl.top_radius = 0.017
	jewel_cyl.bottom_radius = 0.017
	jewel_cyl.height = 0.008
	jewel_cyl.radial_segments = 20
	jewel_cyl.material = RiskMaterials.get_continent_material(c_id)
	jewel_mi.mesh = jewel_cyl
	jewel_mi.position = Vector3(0.0, 0.001, 0.0)
	token.add_child(jewel_mi)

	if king_mesh:
		var crown_mi = MeshInstance3D.new()
		crown_mi.mesh = king_mesh
		crown_mi.material_override = mats["gold"]
		crown_mi.scale = Vector3(0.22, 0.20, 0.22)
		crown_mi.position = Vector3(0.0, 0.004, 0.0)
		token.add_child(crown_mi)

	return token

static func build_player_station(
	parent: Node3D,
	p_idx: int,
	pos: Vector3,
	rot_y_deg: float,
	is_local: bool,
	mats: Dictionary,
	font: Font,
	king_mesh: Mesh
) -> Dictionary:
	var station = Node3D.new()
	station.name = "PlayerStation_P%d" % p_idx
	station.position = pos
	station.rotation_degrees.y = rot_y_deg
	parent.add_child(station)

	var f_col: Color = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE)
	var f_mat_idle = RiskMaterials.get_faction_material(p_idx, false)
	var f_mat_active = RiskMaterials.get_faction_material(p_idx, true)

	var base_w: float = 0.44 if is_local else 0.36
	var base_d: float = 0.13 if is_local else 0.17

	var wood_base = MeshInstance3D.new()
	var wb_box = BoxMesh.new()
	wb_box.size = Vector3(base_w, 0.016, base_d)
	wb_box.material = mats["mahogany"]
	wood_base.mesh = wb_box
	wood_base.position = Vector3(0.0, 0.008, 0.0)
	station.add_child(wood_base)

	var leather_top = MeshInstance3D.new()
	var lt_box = BoxMesh.new()
	lt_box.size = Vector3(base_w - 0.020, 0.004, base_d - 0.020)
	lt_box.material = mats["leather"]
	leather_top.mesh = lt_box
	leather_top.position = Vector3(0.0, 0.017, 0.0)
	station.add_child(leather_top)

	var active_glow = MeshInstance3D.new()
	var ag_box = BoxMesh.new()
	ag_box.size = Vector3(base_w + 0.018, 0.006, base_d + 0.018)
	ag_box.material = mats["glow_gold"]
	active_glow.mesh = ag_box
	active_glow.position = Vector3(0.0, 0.004, 0.0)
	active_glow.visible = false
	station.add_child(active_glow)

	var target_glow = MeshInstance3D.new()
	var tg_box = BoxMesh.new()
	tg_box.size = Vector3(base_w + 0.026, 0.008, base_d + 0.026)
	tg_box.material = mats["glow_crimson"]
	target_glow.mesh = tg_box
	target_glow.position = Vector3(0.0, 0.006, 0.0)
	target_glow.visible = false
	station.add_child(target_glow)

	var nameplate = MeshInstance3D.new()
	var np_box = BoxMesh.new()
	np_box.size = Vector3(base_w * 0.72, 0.018, 0.032)
	np_box.material = mats["bronze"]
	nameplate.mesh = np_box
	nameplate.position = Vector3(0.0, 0.024, base_d * 0.36)
	station.add_child(nameplate)

	var name_lbl = Label3D.new()
	name_lbl.text = "فرمانده %s" % fa_digits(p_idx)
	if font:
		name_lbl.font = font
	name_lbl.font_size = 42
	name_lbl.pixel_size = 0.00125
	name_lbl.modulate = f_col.lightened(0.35)
	name_lbl.outline_size = 10
	name_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.98)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.position = Vector3(0.0, 0.078, base_d * 0.34)
	station.add_child(name_lbl)

	var stats_lbl = Label3D.new()
	stats_lbl.text = "👑۰  🗺️۰  🃏۰"
	if font:
		stats_lbl.font = font
	stats_lbl.font_size = 36
	stats_lbl.pixel_size = 0.00125
	stats_lbl.modulate = Color(1.0, 0.96, 0.80)
	stats_lbl.outline_size = 9
	stats_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.98)
	stats_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stats_lbl.position = Vector3(0.0, 0.044, base_d * 0.34)
	station.add_child(stats_lbl)

	var commander_mi = MeshInstance3D.new()
	if king_mesh:
		commander_mi.mesh = king_mesh
		commander_mi.scale = Vector3(0.38, 0.38, 0.38)
	else:
		var cm_cyl = CylinderMesh.new()
		cm_cyl.top_radius = 0.014
		cm_cyl.bottom_radius = 0.018
		cm_cyl.height = 0.045
		commander_mi.mesh = cm_cyl
	commander_mi.material_override = f_mat_idle
	commander_mi.position = Vector3(-base_w * 0.40, 0.019, 0.0)
	station.add_child(commander_mi)

	var assets_container = Node3D.new()
	assets_container.name = "StationAssets3D"
	assets_container.position = Vector3(0.0, 0.020, -0.012)
	station.add_child(assets_container)

	var area = Area3D.new()
	area.name = "StationHitArea"
	area.set_meta("interact_type", "station")
	area.set_meta("player_index", p_idx)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(base_w + 0.02, 0.08, base_d + 0.02)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.035, 0.0)
	area.add_child(col)
	station.add_child(area)

	return {
		"root": station,
		"active_glow": active_glow,
		"target_glow": target_glow,
		"name_lbl": name_lbl,
		"stats_lbl": stats_lbl,
		"commander_mi": commander_mi,
		"f_mat_idle": f_mat_idle,
		"f_mat_active": f_mat_active,
		"assets_container": assets_container,
		"is_local": is_local,
		"base_w": base_w,
	}

static func populate_station_assets_3d(
	station_ref: Dictionary,
	p_data: Dictionary,
	mats: Dictionary,
	font: Font,
	king_mesh: Mesh
) -> void:
	var container: Node3D = station_ref["assets_container"]
	for child in container.get_children():
		child.queue_free()

	var is_local: bool = station_ref["is_local"]
	var tokens: Array = p_data.get("tokens", [])
	var continents: Dictionary = p_data.get("continents", {})
	var strat_count: int = int(p_data.get("strategies_count", 0))

	for i in range(tokens.size()):
		var c_id = str(tokens[i])
		var tok = build_domination_token_3d(c_id, mats, king_mesh, 0.88)
		tok.position = Vector3(0.11 + float(i) * 0.046, 0.005, 0.015)
		container.add_child(tok)

	if not is_local:
		var c_keys: Array = []
		for k in continents.keys():
			if int(continents[k]) > 0:
				c_keys.append(str(k))
		c_keys.sort()

		for i in range(c_keys.size()):
			var c_id: String = c_keys[i]
			var cnt: int = int(continents[c_id])
			var mini_card = Node3D.new()
			mini_card.position = Vector3(-0.088 + float(i) * 0.038, 0.004, -0.018)
			container.add_child(mini_card)

			for layer in range(min(cnt, 4)):
				var c_mi = MeshInstance3D.new()
				var c_bm = BoxMesh.new()
				c_bm.size = Vector3(0.032, 0.003, 0.044)
				c_bm.material = RiskMaterials.get_continent_material(c_id)
				c_mi.mesh = c_bm
				c_mi.position = Vector3(0.0, float(layer) * 0.0035, 0.0)
				mini_card.add_child(c_mi)

			var badge = Label3D.new()
			badge.text = "%s×%s" % [CONTINENT_META.get(c_id, {}).get("fa", c_id).substr(0, 3), fa_digits(cnt)]
			if font:
				badge.font = font
			badge.font_size = 32
			badge.pixel_size = 0.00115
			badge.modulate = Color(1.0, 0.96, 0.84)
			badge.outline_size = 8
			badge.outline_modulate = Color(0.02, 0.01, 0.01, 0.98)
			badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			badge.position = Vector3(0.0, 0.030, 0.0)
			mini_card.add_child(badge)

		var fan_root = Node3D.new()
		fan_root.position = Vector3(0.055, 0.006, -0.022)
		container.add_child(fan_root)

		var back_mat = StandardMaterial3D.new()
		back_mat.albedo_color = Color(0.46, 0.14, 0.16)
		back_mat.roughness = 0.35

		var show_fan = min(strat_count, 6)
		for i in range(show_fan):
			var f_mi = MeshInstance3D.new()
			var f_bm = BoxMesh.new()
			f_bm.size = Vector3(0.028, 0.0025, 0.040)
			f_bm.material = back_mat
			f_mi.mesh = f_bm
			var spread = (float(i) - float(show_fan - 1) * 0.5)
			f_mi.position = Vector3(spread * 0.009, float(i) * 0.002, 0.0)
			f_mi.rotation_degrees.y = -spread * 8.0
			fan_root.add_child(f_mi)

static func build_3d_card(
	card_kind: String,
	card_id: String,
	count: int,
	hand_idx: int,
	mats: Dictionary,
	font: Font,
	rook_mesh: Mesh,
	knight_mesh: Mesh
) -> Dictionary:
	var card_root = Node3D.new()
	card_root.name = "Card3D_%s_%s_%d" % [card_kind, card_id, hand_idx]

	var card_w: float = 0.132
	var card_h: float = 0.184
	var card_t: float = 0.0060

	# 1. Brushed Brass Outer Frame
	var frame_mi = MeshInstance3D.new()
	var frame_bm = BoxMesh.new()
	frame_bm.size = Vector3(card_w, card_t, card_h)
	frame_bm.material = mats["brass"]
	frame_mi.mesh = frame_bm
	card_root.add_child(frame_mi)

	# 2. Cream Parchment Inner Core
	var face_mi = MeshInstance3D.new()
	var face_bm = BoxMesh.new()
	face_bm.size = Vector3(card_w - 0.010, card_t + 0.001, card_h - 0.010)
	face_bm.material = mats["parchment"]
	face_mi.mesh = face_bm
	card_root.add_child(face_mi)

	# 3. Colored Header Banner & 3D Raised Medallion
	var banner_col: Color = Color(0.25, 0.55, 0.35)
	var title_text: String = card_id
	var sub_text: String = ""
	if card_kind == "continent":
		banner_col = RiskMaterials.CONTINENT_COLORS.get(card_id, Color(0.25, 0.65, 0.45))
		title_text = CONTINENT_META.get(card_id, {}).get("fa", card_id)
		sub_text = "قاره (×%s)" % fa_digits(count)
	else:
		var sm = STRATEGY_META.get(card_id, {})
		banner_col = sm.get("color", Color(0.78, 0.25, 0.25))
		title_text = sm.get("fa", card_id)
		sub_text = sm.get("short", "استراتژی")

	var banner_mat = StandardMaterial3D.new()
	banner_mat.albedo_color = banner_col
	banner_mat.roughness = 0.32
	banner_mat.metallic = 0.18

	var banner_mi = MeshInstance3D.new()
	var banner_bm = BoxMesh.new()
	banner_bm.size = Vector3(card_w - 0.016, 0.002, card_h * 0.40)
	banner_bm.material = banner_mat
	banner_mi.mesh = banner_bm
	banner_mi.position = Vector3(0.0, card_t * 0.55, -card_h * 0.19)
	card_root.add_child(banner_mi)

	# 3D Raised Emblem on the Card Face
	var emblem_mi = MeshInstance3D.new()
	if card_kind == "continent" and rook_mesh:
		emblem_mi.mesh = rook_mesh
		emblem_mi.scale = Vector3(0.19, 0.08, 0.19)
		emblem_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	elif knight_mesh:
		emblem_mi.mesh = knight_mesh
		emblem_mi.scale = Vector3(0.19, 0.08, 0.19)
		emblem_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	else:
		var ec = CylinderMesh.new()
		ec.top_radius = 0.018
		ec.bottom_radius = 0.020
		ec.height = 0.004
		emblem_mi.mesh = ec
	emblem_mi.material_override = mats["gold"]
	emblem_mi.position = Vector3(0.0, card_t * 0.65, -card_h * 0.19)
	card_root.add_child(emblem_mi)

	# 4. Large, High-Contrast Persian Labels on the 3D Card Face
	var title_lbl = Label3D.new()
	title_lbl.text = title_text
	if font:
		title_lbl.font = font
	title_lbl.font_size = 38
	title_lbl.pixel_size = 0.00105
	title_lbl.modulate = Color(0.12, 0.07, 0.03)
	title_lbl.outline_size = 4
	title_lbl.outline_modulate = Color(1.0, 0.97, 0.90, 0.92)
	title_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	title_lbl.position = Vector3(0.0, card_t * 0.68, card_h * 0.13)
	card_root.add_child(title_lbl)

	var sub_lbl = Label3D.new()
	sub_lbl.text = sub_text
	if font:
		sub_lbl.font = font
	sub_lbl.font_size = 28
	sub_lbl.pixel_size = 0.0010
	sub_lbl.modulate = banner_col.darkened(0.32)
	sub_lbl.outline_size = 3
	sub_lbl.outline_modulate = Color(1.0, 0.97, 0.90, 0.85)
	sub_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sub_lbl.position = Vector3(0.0, card_t * 0.68, card_h * 0.31)
	card_root.add_child(sub_lbl)

	if count > 1:
		var badge_lbl = Label3D.new()
		badge_lbl.text = "×" + fa_digits(count)
		if font:
			badge_lbl.font = font
		badge_lbl.font_size = 42
		badge_lbl.pixel_size = 0.0011
		badge_lbl.modulate = Color(1.0, 0.94, 0.38)
		badge_lbl.outline_size = 9
		badge_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.99)
		badge_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		badge_lbl.position = Vector3(card_w * 0.30, card_t * 0.74, -card_h * 0.34)
		card_root.add_child(badge_lbl)

	# 5. Glowing Selection Aura Around Card
	var glow_mi = MeshInstance3D.new()
	var glow_bm = BoxMesh.new()
	glow_bm.size = Vector3(card_w + 0.014, card_t * 0.8, card_h + 0.014)
	glow_bm.material = mats["glow_gold"]
	glow_mi.mesh = glow_bm
	glow_mi.visible = false
	card_root.add_child(glow_mi)

	# 6. Raycast Area3D for Card Hover & Selection
	var area = Area3D.new()
	area.name = "CardHitArea"
	area.set_meta("interact_type", "hand_card")
	area.set_meta("card_kind", card_kind)
	area.set_meta("card_id", card_id)
	area.set_meta("hand_idx", hand_idx)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(card_w + 0.008, 0.026, card_h + 0.008)
	col.shape = box_shape
	area.add_child(col)
	card_root.add_child(area)

	return {
		"root": card_root,
		"glow": glow_mi,
		"card_kind": card_kind,
		"card_id": card_id,
		"count": count,
		"hand_idx": hand_idx,
		"base_pos": Vector3.ZERO,
		"base_rot": Vector3.ZERO,
	}

static func build_3d_die(is_attacker: bool, mats: Dictionary) -> Node3D:
	var die_root = Node3D.new()
	die_root.name = "BattleDie3D"
	var s: float = 0.036
	var half: float = s * 0.5

	var body_mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(s, s, s)
	bm.material = mats["die_attacker"] if is_attacker else mats["die_defender"]
	body_mi.mesh = bm
	die_root.add_child(body_mi)

	for cx in [-half * 0.92, half * 0.92]:
		for cy in [-half * 0.92, half * 0.92]:
			for cz in [-half * 0.92, half * 0.92]:
				var stud_mi = MeshInstance3D.new()
				var sm = SphereMesh.new()
				sm.radius = 0.0034
				sm.height = 0.0068
				sm.material = mats["brass"]
				stud_mi.mesh = sm
				stud_mi.position = Vector3(cx, cy, cz)
				die_root.add_child(stud_mi)

	var d: float = s * 0.26
	var face_pips = {
		Vector3(0, 1, 0): [Vector2(0, 0)],
		Vector3(0, -1, 0): [Vector2(-d, -d), Vector2(-d, 0), Vector2(-d, d), Vector2(d, -d), Vector2(d, 0), Vector2(d, d)],
		Vector3(0, 0, 1): [Vector2(-d, -d), Vector2(d, d)],
		Vector3(0, 0, -1): [Vector2(-d, -d), Vector2(d, -d), Vector2(0, 0), Vector2(-d, d), Vector2(d, d)],
		Vector3(1, 0, 0): [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)],
		Vector3(-1, 0, 0): [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
	}
	for normal in face_pips.keys():
		for uv in face_pips[normal]:
			var pip_mi = MeshInstance3D.new()
			var pm = SphereMesh.new()
			pm.radius = 0.0032
			pm.height = 0.0064
			pm.material = mats["pip_ivory"]
			pip_mi.mesh = pm
			var p3 = Vector3.ZERO
			if absf(normal.y) > 0.5:
				p3 = Vector3(uv.x, normal.y * (half + 0.0008), uv.y)
			elif absf(normal.z) > 0.5:
				p3 = Vector3(uv.x, uv.y, normal.z * (half + 0.0008))
			else:
				p3 = Vector3(normal.x * (half + 0.0008), uv.y, uv.x)
			pip_mi.position = p3
			die_root.add_child(pip_mi)

	return die_root

static func get_die_rotation_for_value(val: int) -> Vector3:
	match clampi(val, 1, 6):
		1:
			return Vector3(0.0, 0.0, 0.0)
		2:
			return Vector3(-90.0, 0.0, 0.0)
		3:
			return Vector3(0.0, 0.0, 90.0)
		4:
			return Vector3(0.0, 0.0, -90.0)
		5:
			return Vector3(90.0, 0.0, 0.0)
		6:
			return Vector3(180.0, 0.0, 0.0)
	return Vector3.ZERO
