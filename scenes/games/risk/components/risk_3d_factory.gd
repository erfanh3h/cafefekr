class_name Risk3DFactory
extends RefCounted

# ==============================================================================
# RISK STRIKE — PREMIUM 3D TABLETOP & BOARD COMPONENT BUILDER
# Clean, spacious, non-overlapping 3D architecture for mobile portrait view
# ==============================================================================

const CONTINENT_META: Dictionary = {
	"NorthAmerica": {
		"fa": "آمریکای شمالی",
		"pos": Vector3(-0.37, 0.048, -0.23),
		"radius": 0.136,
	},
	"Europe": {
		"fa": "اروپا",
		"pos": Vector3(0.00, 0.048, -0.25),
		"radius": 0.132,
	},
	"Asia": {
		"fa": "آسیا",
		"pos": Vector3(0.37, 0.048, -0.23),
		"radius": 0.136,
	},
	"SouthAmerica": {
		"fa": "آمریکای جنوبی",
		"pos": Vector3(-0.36, 0.048, 0.15),
		"radius": 0.132,
	},
	"Africa": {
		"fa": "آفریقا",
		"pos": Vector3(0.00, 0.048, 0.17),
		"radius": 0.132,
	},
	"Australia": {
		"fa": "اقیانوسیه",
		"pos": Vector3(0.36, 0.048, 0.15),
		"radius": 0.132,
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
		"icon": "⚔️",
		"short": "+۱ تاس نبرد / ۱ قاره",
		"desc": "در نبرد +۱ تاس اضافه می‌دهد، یا خارج از نبرد ۱ کارت قاره می‌کشد.",
		"color": Color(0.82, 0.24, 0.22),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Backup": {
		"fa": "پشتیبانی لجستیک",
		"icon": "📦",
		"short": "دریافت ۲ کارت قاره",
		"desc": "فوراً ۲ کارت قاره از دسته به دست شما اضافه می‌کند.",
		"color": Color(0.20, 0.56, 0.82),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Expand": {
		"fa": "پیشروی سریع",
		"icon": "🧭",
		"short": "۱ قاره + حمله آزاد",
		"desc": "۱ کارت قاره می‌کشد و تا پایان نوبت محدودیت هم‌مرزی قاره‌ها را برمی‌دارد.",
		"color": Color(0.18, 0.66, 0.42),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Bomb": {
		"fa": "بمباران تاکتیکی",
		"icon": "💣",
		"short": "حذف ۲ استراتژی حریف",
		"desc": "تا ۲ کارت استراتژی (یا ۱ کارت قاره) از دست حریف انتخابی حذف می‌کند.",
		"color": Color(0.86, 0.44, 0.16),
		"needs_target_player": true,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Destroy": {
		"fa": "تخریب پایگاه",
		"icon": "💥",
		"short": "حذف ۱ کارت قاره حریف",
		"desc": "۱ کارت قاره مشخص از قاره‌های حریف انتخابی را نابود می‌کند.",
		"color": Color(0.78, 0.20, 0.34),
		"needs_target_player": true,
		"needs_target_continent": true,
		"combat_only": false,
	},
	"Spy": {
		"fa": "جاسوس نفوذی",
		"icon": "🕵️",
		"short": "سرقت ۱ کارت از حریف",
		"desc": "۱ کارت تصادفی از دست حریف انتخابی سرقت کرده و به دست شما می‌دهد.",
		"color": Color(0.54, 0.28, 0.78),
		"needs_target_player": true,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Canon": {
		"fa": "توپخانه سنگین",
		"icon": "🎯",
		"short": "+۱ به بالاترین تاس",
		"desc": "به بالاترین تاس شما در نبرد فعلی یا نبرد بعدی +۱ امتیاز اضافه می‌کند.",
		"color": Color(0.84, 0.64, 0.18),
		"needs_target_player": false,
		"needs_target_continent": false,
		"combat_only": false,
	},
	"Cancel": {
		"fa": "لغو تهاجم",
		"icon": "🛡️",
		"short": "لغو کامل حمله دشمن",
		"desc": "در زمان دفاع، حمله فعلی دشمن را فوراً لغو و بدون تلفات متوقف می‌کند.",
		"color": Color(0.20, 0.68, 0.74),
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

	# 1. Rich Dark Walnut Outer Tabletop Surface
	var table_slab = MeshInstance3D.new()
	var slab_box = BoxMesh.new()
	slab_box.size = Vector3(1.42, 0.024, 1.38)
	slab_box.material = mats["walnut"]
	table_slab.mesh = slab_box
	table_slab.position = Vector3(0.0, 0.012, -0.08)
	table_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(table_slab)

	# 2. Central Raised Physical Game Board (Walnut & Mahogany Plinth + Emerald Baize)
	var board_shadow = MeshInstance3D.new()
	var bs_box = BoxMesh.new()
	bs_box.size = Vector3(1.22, 0.012, 1.04)
	bs_box.material = mats["charcoal"]
	board_shadow.mesh = bs_box
	board_shadow.position = Vector3(0.0, 0.022, -0.10)
	board_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board_shadow)

	var board_frame = MeshInstance3D.new()
	var bf_box = BoxMesh.new()
	bf_box.size = Vector3(1.18, 0.032, 1.00)
	bf_box.material = mats["mahogany"]
	board_frame.mesh = bf_box
	board_frame.position = Vector3(0.0, 0.030, -0.10)
	board_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board_frame)

	# Muted Antique Brass Outer Moulding Around the Raised Board
	var bezel_specs = [
		{"pos": Vector3(0.0, 0.048, -0.590), "size": Vector3(1.16, 0.008, 0.016)},
		{"pos": Vector3(0.0, 0.048, 0.390), "size": Vector3(1.16, 0.008, 0.016)},
		{"pos": Vector3(-0.576, 0.048, -0.10), "size": Vector3(0.016, 0.008, 0.98)},
		{"pos": Vector3(0.576, 0.048, -0.10), "size": Vector3(0.016, 0.008, 0.98)},
		# Divider rail separating the Upper Deck/Dice Bay (z=-0.48) from the Map Arena (z=-0.04)
		{"pos": Vector3(0.0, 0.048, -0.392), "size": Vector3(1.14, 0.007, 0.012)},
	]
	for bspec in bezel_specs:
		var bz_mi = MeshInstance3D.new()
		var bz_bm = BoxMesh.new()
		bz_bm.size = bspec["size"]
		bz_bm.material = mats["brass"]
		bz_mi.mesh = bz_bm
		bz_mi.position = bspec["pos"]
		bz_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bz_mi)

	# 4 Corner Brass Medallions on the Raised Board Frame
	for cx in [-0.572, 0.572]:
		for cz in [-0.586, 0.386]:
			var c_mi = MeshInstance3D.new()
			var c_cyl = CylinderMesh.new()
			c_cyl.top_radius = 0.020
			c_cyl.bottom_radius = 0.023
			c_cyl.height = 0.012
			c_cyl.radial_segments = 16
			c_cyl.material = mats["brass"]
			c_mi.mesh = c_cyl
			c_mi.position = Vector3(cx, 0.049, cz)
			c_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(c_mi)

	# Dark Emerald Green Baize Velvet Playing Bed (Map Area)
	var velvet_bed = MeshInstance3D.new()
	var vb_box = BoxMesh.new()
	vb_box.size = Vector3(1.13, 0.006, 0.76)
	vb_box.material = mats["emerald_velvet"]
	velvet_bed.mesh = vb_box
	velvet_bed.position = Vector3(0.0, 0.045, -0.005)
	velvet_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(velvet_bed)

	# Upper Recessed Leather Command Bay (Holds Continent Deck, Dice Arena, Strategy Deck cleanly above the map!)
	var upper_bay = MeshInstance3D.new()
	var ub_box = BoxMesh.new()
	ub_box.size = Vector3(1.13, 0.005, 0.18)
	ub_box.material = mats["leather"]
	upper_bay.mesh = ub_box
	upper_bay.position = Vector3(0.0, 0.045, -0.49)
	upper_bay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(upper_bay)

	# Subtle Engraved Brass Compass Ring on the Emerald Map Bed
	for ring_r in [0.18, 0.32]:
		var ring_mi = MeshInstance3D.new()
		var ring_torus = TorusMesh.new()
		ring_torus.inner_radius = ring_r
		ring_torus.outer_radius = ring_r + 0.003
		ring_torus.rings = 28
		ring_torus.ring_segments = 10
		ring_torus.material = mats["bronze"]
		ring_mi.mesh = ring_torus
		ring_mi.position = Vector3(0.0, 0.048, -0.04)
		ring_mi.scale = Vector3(1.38, 1.0, 0.92)
		ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring_mi)

	# 3. Dedicated 3D Octagonal Leather & Brass Dice Rolling Tray (Centered in Upper Bay at z=-0.49)
	var dice_arena = Node3D.new()
	dice_arena.name = "CentralDiceArena"
	dice_arena.position = Vector3(0.0, 0.048, -0.49)
	dice_arena.scale = Vector3(0.62, 0.62, 0.62)
	root.add_child(dice_arena)
	refs["dice_arena"] = dice_arena

	var arena_rim = MeshInstance3D.new()
	var ar_cyl = CylinderMesh.new()
	ar_cyl.top_radius = 0.148
	ar_cyl.bottom_radius = 0.158
	ar_cyl.height = 0.018
	ar_cyl.radial_segments = 16
	ar_cyl.material = mats["bronze"]
	arena_rim.mesh = ar_cyl
	arena_rim.position = Vector3(0.0, 0.009, 0.0)
	dice_arena.add_child(arena_rim)

	var arena_gold_lip = MeshInstance3D.new()
	var ag_cyl = CylinderMesh.new()
	ag_cyl.top_radius = 0.138
	ag_cyl.bottom_radius = 0.140
	ag_cyl.height = 0.019
	ag_cyl.radial_segments = 16
	ag_cyl.material = mats["brass"]
	arena_gold_lip.mesh = ag_cyl
	arena_gold_lip.position = Vector3(0.0, 0.0095, 0.0)
	dice_arena.add_child(arena_gold_lip)

	var arena_bed = MeshInstance3D.new()
	var ab_cyl = CylinderMesh.new()
	ab_cyl.top_radius = 0.130
	ab_cyl.bottom_radius = 0.130
	ab_cyl.height = 0.020
	ab_cyl.radial_segments = 16
	ab_cyl.material = mats["emerald_velvet"]
	arena_bed.mesh = ab_cyl
	arena_bed.position = Vector3(0.0, 0.010, 0.0)
	dice_arena.add_child(arena_bed)

	var dice_light = OmniLight3D.new()
	dice_light.name = "DiceSpotlight"
	dice_light.light_color = Color(1.0, 0.95, 0.82)
	dice_light.light_energy = 1.35
	dice_light.omni_range = 0.65
	dice_light.position = Vector3(0.0, 0.24, 0.0)
	dice_arena.add_child(dice_light)

	# 4. Left & Right 3D Draw Decks in the Upper Command Bay (Zero overlap with continents!)
	refs["continent_deck"] = _build_draw_deck(
		root,
		Vector3(-0.36, 0.048, -0.49),
		"continent",
		"دسته قاره",
		Color(0.12, 0.44, 0.28),
		mats,
		font
	)
	refs["strategy_deck"] = _build_draw_deck(
		root,
		Vector3(0.36, 0.048, -0.49),
		"strategy",
		"دسته استراتژی",
		Color(0.50, 0.16, 0.18),
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

	# Brass Card Shoe Base
	var tray_mi = MeshInstance3D.new()
	var tray_bm = BoxMesh.new()
	tray_bm.size = Vector3(0.130, 0.006, 0.106)
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
	for i in range(8):
		var layer_mi = MeshInstance3D.new()
		var layer_bm = BoxMesh.new()
		layer_bm.size = Vector3(0.114, 0.0024, 0.090)
		layer_bm.material = mats["parchment"] if i < 7 else top_mat
		layer_mi.mesh = layer_bm
		layer_mi.position = Vector3(0.0, 0.007 + float(i) * 0.0025, 0.0)
		stack_node.add_child(layer_mi)
		card_layers.append(layer_mi)

	# Subtle Brass Medallion on Top Card
	var crest_mi = MeshInstance3D.new()
	var crest_cyl = CylinderMesh.new()
	crest_cyl.top_radius = 0.018
	crest_cyl.bottom_radius = 0.018
	crest_cyl.height = 0.003
	crest_cyl.radial_segments = 16
	crest_cyl.material = mats["gold"]
	crest_mi.mesh = crest_cyl
	crest_mi.position = Vector3(-0.026, 0.028, 0.0)
	stack_node.add_child(crest_mi)

	# Restrained Selection / Draw Ready Glow Frame
	var glow_mi = MeshInstance3D.new()
	var glow_bm = BoxMesh.new()
	glow_bm.size = Vector3(0.142, 0.004, 0.118)
	glow_bm.material = mats["glow_gold"]
	glow_mi.mesh = glow_bm
	glow_mi.position = Vector3(0.0, 0.004, 0.0)
	glow_mi.visible = false
	deck_root.add_child(glow_mi)

	# Flat-Tilted Count Badge on Top of Deck (Never floats into other labels)
	var count_lbl = Label3D.new()
	count_lbl.text = "۴۲"
	if font:
		count_lbl.font = font
	count_lbl.font_size = 38
	count_lbl.pixel_size = 0.00105
	count_lbl.modulate = Color(0.98, 0.94, 0.82)
	count_lbl.outline_size = 10
	count_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	count_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	count_lbl.position = Vector3(0.018, 0.032, -0.004)
	deck_root.add_child(count_lbl)

	var title_lbl = Label3D.new()
	title_lbl.text = title_fa
	if font:
		title_lbl.font = font
	title_lbl.font_size = 28
	title_lbl.pixel_size = 0.0010
	title_lbl.modulate = Color(0.94, 0.84, 0.56)
	title_lbl.outline_size = 8
	title_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	title_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	title_lbl.position = Vector3(0.0, 0.018, 0.068)
	deck_root.add_child(title_lbl)

	# Interactive Area3D for clicking the 3D Deck directly
	var area = Area3D.new()
	area.name = "DeckHitArea"
	area.set_meta("interact_type", "deck")
	area.set_meta("deck_type", deck_type)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.15, 0.06, 0.13)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.025, 0.0)
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
			bm.size = Vector3(0.012, 0.004, maxf(0.04, dist - 0.25))
			bm.material = mats["bridge_idle"]
			bridge_mi.mesh = bm
			bridge_mi.position = Vector3(mid.x, 0.049, mid.z)
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
	var cont_mat: StandardMaterial3D = RiskMaterials.get_continent_material(c_id, false)

	var root = Node3D.new()
	root.name = "Continent_" + c_id
	root.position = pos
	parent.add_child(root)

	# 1. Dark Charcoal Contact Shadow Plinth
	var shadow_plinth = MeshInstance3D.new()
	var sp_cyl = CylinderMesh.new()
	sp_cyl.top_radius = rad + 0.013
	sp_cyl.bottom_radius = rad + 0.017
	sp_cyl.height = 0.008
	sp_cyl.radial_segments = 28
	sp_cyl.material = mats["charcoal"]
	shadow_plinth.mesh = sp_cyl
	shadow_plinth.position = Vector3(0.0, 0.004, 0.0)
	shadow_plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow_plinth)

	# 2. Warm Antique Bronze Stepped Rim
	var base_bezel = MeshInstance3D.new()
	var bz_cyl = CylinderMesh.new()
	bz_cyl.top_radius = rad + 0.006
	bz_cyl.bottom_radius = rad + 0.011
	bz_cyl.height = 0.015
	bz_cyl.radial_segments = 28
	bz_cyl.material = mats["bronze"]
	base_bezel.mesh = bz_cyl
	base_bezel.position = Vector3(0.0, 0.008, 0.0)
	base_bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(base_bezel)

	# 3. Raised Colored Territory Plateau
	var plateau = MeshInstance3D.new()
	var pl_cyl = CylinderMesh.new()
	pl_cyl.top_radius = rad
	pl_cyl.bottom_radius = rad + 0.003
	pl_cyl.height = 0.022
	pl_cyl.radial_segments = 28
	pl_cyl.material = cont_mat
	plateau.mesh = pl_cyl
	plateau.position = Vector3(0.0, 0.012, 0.0)
	plateau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plateau)

	# Subtle Inner Brass Inlay Ring on Plateau Top
	var inner_ring = MeshInstance3D.new()
	var ir_torus = TorusMesh.new()
	ir_torus.inner_radius = rad - 0.010
	ir_torus.outer_radius = rad - 0.006
	ir_torus.rings = 28
	ir_torus.ring_segments = 10
	ir_torus.material = mats["brass"]
	inner_ring.mesh = ir_torus
	inner_ring.position = Vector3(0.0, 0.023, 0.0)
	inner_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner_ring)

	# 4. Restrained Selection / Valid Target / Attack Ring
	var aura_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = rad + 0.008
	torus.outer_radius = rad + 0.020
	torus.rings = 28
	torus.ring_segments = 10
	torus.material = mats["glow_gold"]
	aura_ring.mesh = torus
	aura_ring.position = Vector3(0.0, 0.014, 0.0)
	aura_ring.visible = false
	root.add_child(aura_ring)

	# 5. Compact Sculpted Citadel Keep at North-Center of Territory
	var citadel = Node3D.new()
	citadel.name = "CitadelKeep"
	citadel.position = Vector3(-0.032, 0.023, -rad * 0.46)
	root.add_child(citadel)

	if rook_mesh:
		var keep_mi = MeshInstance3D.new()
		keep_mi.mesh = rook_mesh
		keep_mi.material_override = mats["parchment"]
		keep_mi.scale = Vector3(0.28, 0.28, 0.28)
		citadel.add_child(keep_mi)
	else:
		var fallback_keep = MeshInstance3D.new()
		var fk_cyl = CylinderMesh.new()
		fk_cyl.top_radius = 0.015
		fk_cyl.bottom_radius = 0.018
		fk_cyl.height = 0.030
		fk_cyl.material = mats["parchment"]
		fallback_keep.mesh = fk_cyl
		fallback_keep.position = Vector3(0.0, 0.015, 0.0)
		citadel.add_child(fallback_keep)

	# 6. Dedicated Domination Coin Socket at North-Right of Territory
	var token_socket = MeshInstance3D.new()
	var ts_cyl = CylinderMesh.new()
	ts_cyl.top_radius = 0.024
	ts_cyl.bottom_radius = 0.026
	ts_cyl.height = 0.004
	ts_cyl.radial_segments = 18
	ts_cyl.material = mats["charcoal"]
	token_socket.mesh = ts_cyl
	token_socket.position = Vector3(0.032, 0.023, -rad * 0.46)
	root.add_child(token_socket)

	var token_node = build_domination_token_3d(c_id, mats, king_mesh, 0.90)
	token_node.position = Vector3(0.032, 0.028, -rad * 0.46)
	root.add_child(token_node)

	# 7. Dedicated Front Name Plaque (Mounted on South Edge — NEVER overlaps pieces!)
	var plaque_base = MeshInstance3D.new()
	var pb_box = BoxMesh.new()
	pb_box.size = Vector3(rad * 1.32, 0.008, 0.036)
	pb_box.material = mats["charcoal"]
	plaque_base.mesh = pb_box
	plaque_base.position = Vector3(0.0, 0.022, rad * 0.78)
	plaque_base.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_base)

	var plaque_trim = MeshInstance3D.new()
	var pt_box = BoxMesh.new()
	pt_box.size = Vector3(rad * 1.36, 0.006, 0.040)
	pt_box.material = mats["bronze"]
	plaque_trim.mesh = pt_box
	plaque_trim.position = Vector3(0.0, 0.020, rad * 0.78)
	plaque_trim.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_trim)

	var name_lbl = Label3D.new()
	name_lbl.text = meta["fa"]
	if font:
		name_lbl.font = font
	name_lbl.font_size = 38
	name_lbl.pixel_size = 0.00105
	name_lbl.modulate = Color(0.98, 0.95, 0.86)
	name_lbl.outline_size = 10
	name_lbl.outline_modulate = Color(0.03, 0.02, 0.01, 0.98)
	name_lbl.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	name_lbl.position = Vector3(0.0, 0.028, rad * 0.79)
	root.add_child(name_lbl)

	# 8. Four Faction Garrison Nodes (Dynamically arranged via layout_continent_garrisons)
	var default_slots = {
		1: Vector3(-0.052, 0.023, 0.010),
		2: Vector3(0.052, 0.023, 0.010),
		3: Vector3(-0.052, 0.023, -0.036),
		4: Vector3(0.052, 0.023, -0.036),
	}
	var garrisons: Dictionary = {}
	for p_idx in [1, 2, 3, 4]:
		var g_node = Node3D.new()
		g_node.name = "Garrison_P%d" % p_idx
		g_node.position = default_slots[p_idx]
		g_node.visible = false
		root.add_child(g_node)

		var f_mat = RiskMaterials.get_faction_material(p_idx, false)

		var ped_mi = MeshInstance3D.new()
		var ped_cyl = CylinderMesh.new()
		ped_cyl.top_radius = 0.020
		ped_cyl.bottom_radius = 0.023
		ped_cyl.height = 0.007
		ped_cyl.radial_segments = 16
		ped_cyl.material = mats["brass"]
		ped_mi.mesh = ped_cyl
		ped_mi.position = Vector3(0.0, 0.0035, 0.0)
		g_node.add_child(ped_mi)

		var piece_mi = MeshInstance3D.new()
		if knight_mesh:
			piece_mi.mesh = knight_mesh
			piece_mi.scale = Vector3(0.30, 0.30, 0.30)
			piece_mi.position = Vector3(0.0, 0.007, 0.0)
		else:
			var sc = SphereMesh.new()
			sc.radius = 0.014
			sc.height = 0.028
			piece_mi.mesh = sc
			piece_mi.position = Vector3(0.0, 0.018, 0.0)
		piece_mi.material_override = f_mat
		g_node.add_child(piece_mi)

		# Small Dark Charcoal Badge Pill Behind Quantity Number
		var badge_bg = MeshInstance3D.new()
		var bb_box = BoxMesh.new()
		bb_box.size = Vector3(0.044, 0.005, 0.028)
		bb_box.material = mats["charcoal"]
		badge_bg.mesh = bb_box
		badge_bg.position = Vector3(0.0, 0.012, 0.028)
		badge_bg.rotation_degrees = Vector3(22.0, 0.0, 0.0)
		g_node.add_child(badge_bg)

		var cnt_lbl = Label3D.new()
		cnt_lbl.text = "×۱"
		if font:
			cnt_lbl.font = font
		cnt_lbl.font_size = 36
		cnt_lbl.pixel_size = 0.00105
		cnt_lbl.modulate = RiskMaterials.FACTION_COLORS[p_idx].lightened(0.38)
		cnt_lbl.outline_size = 9
		cnt_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.99)
		cnt_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
		cnt_lbl.position = Vector3(0.0, 0.018, 0.029)
		g_node.add_child(cnt_lbl)

		garrisons[p_idx] = {
			"node": g_node,
			"piece": piece_mi,
			"label": cnt_lbl,
		}

	# 9. Raycast Area3D for Continent Selection & Attack Targeting
	var area = Area3D.new()
	area.name = "ContinentHitArea"
	area.set_meta("interact_type", "continent")
	area.set_meta("continent", c_id)
	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = rad + 0.018
	cyl_shape.height = 0.090
	col.shape = cyl_shape
	col.position = Vector3(0.0, 0.032, 0.0)
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

# Intelligently positions occupied garrisons on a continent so pieces & badges never overlap
static func layout_continent_garrisons(c_ref: Dictionary, present_players: Array[int]) -> void:
	var garrisons: Dictionary = c_ref["garrisons"]
	var count = present_players.size()
	var positions: Array[Vector3] = []
	if count == 1:
		positions = [Vector3(0.0, 0.023, 0.008)]
	elif count == 2:
		positions = [
			Vector3(-0.048, 0.023, 0.008),
			Vector3(0.048, 0.023, 0.008),
		]
	elif count == 3:
		positions = [
			Vector3(-0.058, 0.023, 0.014),
			Vector3(0.0, 0.023, -0.010),
			Vector3(0.058, 0.023, 0.014),
		]
	else:
		positions = [
			Vector3(-0.056, 0.023, 0.020),
			Vector3(0.056, 0.023, 0.020),
			Vector3(-0.056, 0.023, -0.022),
			Vector3(0.056, 0.023, -0.022),
		]

	for i in range(present_players.size()):
		var p_idx: int = present_players[i]
		if garrisons.has(p_idx):
			var g_node: Node3D = garrisons[p_idx]["node"]
			g_node.position = positions[min(i, positions.size() - 1)]

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
	coin_cyl.top_radius = 0.020
	coin_cyl.bottom_radius = 0.022
	coin_cyl.height = 0.006
	coin_cyl.radial_segments = 20
	coin_cyl.material = mats["gold"]
	coin_mi.mesh = coin_cyl
	token.add_child(coin_mi)

	var jewel_mi = MeshInstance3D.new()
	var jewel_cyl = CylinderMesh.new()
	jewel_cyl.top_radius = 0.015
	jewel_cyl.bottom_radius = 0.015
	jewel_cyl.height = 0.007
	jewel_cyl.radial_segments = 18
	jewel_cyl.material = RiskMaterials.get_continent_material(c_id, false)
	jewel_mi.mesh = jewel_cyl
	jewel_mi.position = Vector3(0.0, 0.001, 0.0)
	token.add_child(jewel_mi)

	if king_mesh:
		var crown_mi = MeshInstance3D.new()
		crown_mi.mesh = king_mesh
		crown_mi.material_override = mats["gold"]
		crown_mi.scale = Vector3(0.18, 0.16, 0.18)
		crown_mi.position = Vector3(0.0, 0.004, 0.0)
		token.add_child(crown_mi)

	return token

# Compact, Clutter-Free 3D Faction Crest Pedestals (No overlapping floating text billboards!)
static func build_player_station(
	parent: Node3D,
	p_idx: int,
	pos: Vector3,
	rot_y_deg: float,
	is_local: bool,
	mats: Dictionary,
	_font: Font,
	king_mesh: Mesh
) -> Dictionary:
	var station = Node3D.new()
	station.name = "PlayerStation_P%d" % p_idx
	station.position = pos
	station.rotation_degrees.y = rot_y_deg
	parent.add_child(station)

	var f_mat_idle = RiskMaterials.get_faction_material(p_idx, false)
	var f_mat_active = RiskMaterials.get_faction_material(p_idx, true)

	var base_w: float = 0.16
	var base_d: float = 0.08

	var wood_base = MeshInstance3D.new()
	var wb_box = BoxMesh.new()
	wb_box.size = Vector3(base_w, 0.012, base_d)
	wb_box.material = mats["mahogany"]
	wood_base.mesh = wb_box
	wood_base.position = Vector3(0.0, 0.006, 0.0)
	station.add_child(wood_base)

	var active_glow = MeshInstance3D.new()
	var ag_box = BoxMesh.new()
	ag_box.size = Vector3(base_w + 0.012, 0.004, base_d + 0.012)
	ag_box.material = mats["glow_gold"]
	active_glow.mesh = ag_box
	active_glow.position = Vector3(0.0, 0.003, 0.0)
	active_glow.visible = false
	station.add_child(active_glow)

	var target_glow = MeshInstance3D.new()
	var tg_box = BoxMesh.new()
	tg_box.size = Vector3(base_w + 0.018, 0.006, base_d + 0.018)
	tg_box.material = mats["glow_crimson"]
	target_glow.mesh = tg_box
	target_glow.position = Vector3(0.0, 0.004, 0.0)
	target_glow.visible = false
	station.add_child(target_glow)

	var commander_mi = MeshInstance3D.new()
	if king_mesh:
		commander_mi.mesh = king_mesh
		commander_mi.scale = Vector3(0.28, 0.28, 0.28)
	else:
		var cm_cyl = CylinderMesh.new()
		cm_cyl.top_radius = 0.012
		cm_cyl.bottom_radius = 0.015
		cm_cyl.height = 0.032
		commander_mi.mesh = cm_cyl
	commander_mi.material_override = f_mat_idle
	commander_mi.position = Vector3(-0.042, 0.012, 0.0)
	station.add_child(commander_mi)

	var assets_container = Node3D.new()
	assets_container.name = "StationAssets3D"
	assets_container.position = Vector3(0.010, 0.013, 0.0)
	station.add_child(assets_container)

	# Kept as hidden dummy labels for backwards-compatibility if referenced
	var name_lbl = Label3D.new()
	name_lbl.visible = false
	station.add_child(name_lbl)

	var stats_lbl = Label3D.new()
	stats_lbl.visible = false
	station.add_child(stats_lbl)

	var area = Area3D.new()
	area.name = "StationHitArea"
	area.set_meta("interact_type", "station")
	area.set_meta("player_index", p_idx)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(base_w + 0.02, 0.06, base_d + 0.02)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.025, 0.0)
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
	_font: Font,
	king_mesh: Mesh
) -> void:
	var container: Node3D = station_ref["assets_container"]
	for child in container.get_children():
		child.queue_free()

	var tokens: Array = p_data.get("tokens", [])
	for i in range(tokens.size()):
		var c_id = str(tokens[i])
		var tok = build_domination_token_3d(c_id, mats, king_mesh, 0.78)
		tok.position = Vector3(float(i) * 0.038, 0.004, 0.0)
		container.add_child(tok)

static func build_3d_die(is_attacker: bool, mats: Dictionary, font: Font = null, final_val: int = 1) -> Node3D:
	var die_root = Node3D.new()
	die_root.name = "BattleDie3D"
	# 2x larger linear size (8x larger volume) so dice are bold and unmistakable
	var s: float = 0.068
	var half: float = s * 0.5

	# Rotate this inner pivot for the 3D die cube & pips so the floating badge above stays upright
	var cube_pivot = Node3D.new()
	cube_pivot.name = "CubePivot"
	die_root.add_child(cube_pivot)

	var body_mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(s, s, s)
	bm.material = mats["die_attacker"] if is_attacker else mats["die_defender"]
	body_mi.mesh = bm
	cube_pivot.add_child(body_mi)

	# Sculpted Brass Corner Studs
	for cx in [-half * 0.94, half * 0.94]:
		for cy in [-half * 0.94, half * 0.94]:
			for cz in [-half * 0.94, half * 0.94]:
				var stud_mi = MeshInstance3D.new()
				var sm = SphereMesh.new()
				sm.radius = 0.0064
				sm.height = 0.0128
				sm.material = mats["gold"] if is_attacker else mats["brass"]
				stud_mi.mesh = sm
				stud_mi.position = Vector3(cx, cy, cz)
				cube_pivot.add_child(stud_mi)

	# 12 Brass Edge Bevel Bars for crisp 3D cube definition
	var edge_t: float = 0.0046
	var edge_l: float = s * 0.94
	var trim_mat = mats["gold"] if is_attacker else mats["brass"]
	for s1 in [-half * 0.96, half * 0.96]:
		for s2 in [-half * 0.96, half * 0.96]:
			var ex = MeshInstance3D.new()
			var bx = BoxMesh.new()
			bx.size = Vector3(edge_l, edge_t, edge_t)
			bx.material = trim_mat
			ex.mesh = bx
			ex.position = Vector3(0.0, s1, s2)
			cube_pivot.add_child(ex)

			var ey = MeshInstance3D.new()
			var by = BoxMesh.new()
			by.size = Vector3(edge_t, edge_l, edge_t)
			by.material = trim_mat
			ey.mesh = by
			ey.position = Vector3(s1, 0.0, s2)
			cube_pivot.add_child(ey)

			var ez = MeshInstance3D.new()
			var bz = BoxMesh.new()
			bz.size = Vector3(edge_t, edge_t, edge_l)
			bz.material = trim_mat
			ez.mesh = bz
			ez.position = Vector3(s1, s2, 0.0)
			cube_pivot.add_child(ez)

	# High-Contrast Raised Ivory Pips with Gold Collar Rings
	var d: float = s * 0.265
	var face_pips = {
		Vector3(0, 1, 0): [Vector2(0, 0)],
		Vector3(0, -1, 0): [Vector2(-d, -d), Vector2(-d, 0), Vector2(-d, d), Vector2(d, -d), Vector2(d, 0), Vector2(d, d)],
		Vector3(0, 0, 1): [Vector2(-d, -d), Vector2(d, d)],
		Vector3(0, 0, -1): [Vector2(-d, -d), Vector2(d, -d), Vector2(0, 0), Vector2(-d, d), Vector2(d, d)],
		Vector3(1, 0, 0): [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)],
		Vector3(-1, 0, 0): [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
	}
	for normal in face_pips.keys():
		var is_one_face = (normal == Vector3(0, 1, 0))
		for uv in face_pips[normal]:
			var pip_mi = MeshInstance3D.new()
			var pm = SphereMesh.new()
			pm.radius = 0.0086 if is_one_face else 0.0068
			pm.height = 0.0172 if is_one_face else 0.0136
			pm.material = mats["pip_ivory"]
			pip_mi.mesh = pm
			var p3 = Vector3.ZERO
			if absf(normal.y) > 0.5:
				p3 = Vector3(uv.x, normal.y * (half + 0.0018), uv.y)
			elif absf(normal.z) > 0.5:
				p3 = Vector3(uv.x, uv.y, normal.z * (half + 0.0018))
			else:
				p3 = Vector3(normal.x * (half + 0.0018), uv.y, uv.x)
			pip_mi.position = p3
			cube_pivot.add_child(pip_mi)

	# Floating High-Contrast Value Badge above each die (pops in on landing)
	var badge_lbl = make_label_3d(
		"%s %s" % ["⚔️" if is_attacker else "🛡️", fa_digits(clampi(final_val, 1, 6))],
		font,
		56,
		Color(1.0, 0.92, 0.46) if is_attacker else Color(0.58, 0.92, 1.0),
		0.0012
	)
	badge_lbl.name = "DieValueBadge"
	badge_lbl.position = Vector3(0.0, half + 0.042, 0.0)
	badge_lbl.outline_size = 18
	badge_lbl.visible = false
	die_root.add_child(badge_lbl)

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
