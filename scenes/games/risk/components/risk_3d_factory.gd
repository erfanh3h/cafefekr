class_name Risk3DFactory
extends RefCounted

# ==============================================================================
# RISK STRIKE — CAFE FEKR 3D WAR-ROOM TABLETOP & SCULPTED CONTINENT BUILDER
# - Sits directly on the global Cafe Fekr green felt tabletop (no redundant outer table slab)
# - Sculpted multi-tier 3D Continent Islands with citadel keeps, garrison stacks & rotating crowns
# - Interactive 3D Continent & Strategy Decks + Interactive 3D Battle Dice Arena
# - Dynamic 3D Tactical Attack Arc between source and target continents
# ==============================================================================

const CONTINENT_META: Dictionary = {
	"NorthAmerica": {
		"fa": "آمریکای شمالی",
		"pos": Vector3(-0.38, 0.062, -0.18),
		"radius": 0.125,
		"domination": 6,
	},
	"Europe": {
		"fa": "اروپا",
		"pos": Vector3(0.00, 0.062, -0.20),
		"radius": 0.122,
		"domination": 5,
	},
	"Asia": {
		"fa": "آسیا",
		"pos": Vector3(0.38, 0.062, -0.18),
		"radius": 0.125,
		"domination": 8,
	},
	"SouthAmerica": {
		"fa": "آمریکای جنوبی",
		"pos": Vector3(-0.37, 0.062, 0.18),
		"radius": 0.122,
		"domination": 3,
	},
	"Africa": {
		"fa": "آفریقا",
		"pos": Vector3(0.00, 0.062, 0.20),
		"radius": 0.122,
		"domination": 4,
	},
	"Australia": {
		"fa": "اقیانوسیه",
		"pos": Vector3(0.37, 0.062, 0.18),
		"radius": 0.122,
		"domination": 3,
	},
}

const CONTINENT_ADJACENCY: Dictionary = {
	"NorthAmerica": ["SouthAmerica", "Europe", "Asia"],
	"SouthAmerica": ["NorthAmerica", "Africa"],
	"Europe": ["NorthAmerica", "Africa", "Asia"],
	"Africa": ["SouthAmerica", "Europe", "Asia"],
	"Asia": ["NorthAmerica", "Europe", "Africa", "Australia"],
	"Australia": ["Asia"],
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
	var s: String = str(input)
	var en: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var fa: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i: int in range(10):
		s = s.replace(en[i], fa[i])
	return s

static func build_tabletop_and_board_frame(parent: Node3D, mats: Dictionary, font: Font) -> Dictionary:
	var refs: Dictionary = {}
	var root: Node3D = Node3D.new()
	root.name = "TableAndBoardArchitecture"
	parent.add_child(root)
	refs["root"] = root

	var y_felt: float = 0.059

	# 1. Inlaid Brass & Mahogany War-Map Frame directly on the Cafe Fekr Green Felt
	var bezel_specs: Array[Dictionary] = [
		{"pos": Vector3(0.0, y_felt + 0.003, -0.355), "size": Vector3(1.12, 0.006, 0.014)},
		{"pos": Vector3(0.0, y_felt + 0.003, 0.365), "size": Vector3(1.12, 0.006, 0.014)},
		{"pos": Vector3(-0.555, y_felt + 0.003, 0.005), "size": Vector3(0.014, 0.006, 0.734)},
		{"pos": Vector3(0.555, y_felt + 0.003, 0.005), "size": Vector3(0.014, 0.006, 0.734)},
	]
	for bspec: Dictionary in bezel_specs:
		var bz_mi: MeshInstance3D = MeshInstance3D.new()
		var bz_bm: BoxMesh = BoxMesh.new()
		bz_bm.size = bspec["size"]
		bz_bm.material = mats["brass"]
		bz_mi.mesh = bz_bm
		bz_mi.position = bspec["pos"]
		bz_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bz_mi)

	# 4 Corner Brass Bolsters around the War-Map Perimeter
	for cx: float in [-0.555, 0.555]:
		for cz: float in [-0.355, 0.365]:
			var bolster: MeshInstance3D = MeshInstance3D.new()
			var bl_cyl: CylinderMesh = CylinderMesh.new()
			bl_cyl.top_radius = 0.018
			bl_cyl.bottom_radius = 0.022
			bl_cyl.height = 0.010
			bl_cyl.radial_segments = 12
			bl_cyl.material = mats["bronze"]
			bolster.mesh = bl_cyl
			bolster.position = Vector3(cx, y_felt + 0.005, cz)
			bolster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(bolster)

	# 2. Subtle Inlaid Cartography Latitude & Meridian Lines + Twin Brass Compass Roses on the Felt
	var grid_mat: Material = mats.get("ocean_line", mats["brass"])
	for gx: float in [-0.38, -0.19, 0.0, 0.19, 0.38]:
		var lon: MeshInstance3D = MeshInstance3D.new()
		var lon_bm: BoxMesh = BoxMesh.new()
		lon_bm.size = Vector3(0.0022, 0.0008, 0.70)
		lon_bm.material = grid_mat
		lon.mesh = lon_bm
		lon.position = Vector3(gx, y_felt + 0.001, 0.005)
		lon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lon)
	for gz: float in [-0.20, 0.0, 0.20]:
		var lat: MeshInstance3D = MeshInstance3D.new()
		var lat_bm: BoxMesh = BoxMesh.new()
		lat_bm.size = Vector3(1.09, 0.0008, 0.0022)
		lat_bm.material = grid_mat
		lat.mesh = lat_bm
		lat.position = Vector3(0.0, y_felt + 0.001, gz)
		lat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lat)

	_build_compass_rose_inlay(root, Vector3(-0.19, y_felt + 0.0015, 0.305), 0.038, mats)
	_build_compass_rose_inlay(root, Vector3(0.19, y_felt + 0.0015, 0.305), 0.038, mats)

	# 3. Interactive 3D Dice Rolling Tray (Appears in center during combat rolls, clickable to roll!)
	var dice_arena: Node3D = Node3D.new()
	dice_arena.name = "CentralDiceArena"
	dice_arena.position = Vector3(0.0, y_felt + 0.004, -0.435)
	dice_arena.scale = Vector3(0.62, 0.62, 0.62)
	dice_arena.visible = false
	root.add_child(dice_arena)
	refs["dice_arena"] = dice_arena

	var arena_rim: MeshInstance3D = MeshInstance3D.new()
	var ar_cyl: CylinderMesh = CylinderMesh.new()
	ar_cyl.top_radius = 0.148
	ar_cyl.bottom_radius = 0.158
	ar_cyl.height = 0.016
	ar_cyl.radial_segments = 20
	ar_cyl.material = mats["bronze"]
	arena_rim.mesh = ar_cyl
	arena_rim.position = Vector3(0.0, 0.008, 0.0)
	dice_arena.add_child(arena_rim)

	var arena_bed: MeshInstance3D = MeshInstance3D.new()
	var ab_cyl: CylinderMesh = CylinderMesh.new()
	ab_cyl.top_radius = 0.134
	ab_cyl.bottom_radius = 0.134
	ab_cyl.height = 0.018
	ab_cyl.radial_segments = 20
	ab_cyl.material = mats["emerald_velvet"]
	arena_bed.mesh = ab_cyl
	arena_bed.position = Vector3(0.0, 0.009, 0.0)
	dice_arena.add_child(arena_bed)

	var dice_light: OmniLight3D = OmniLight3D.new()
	dice_light.name = "DiceSpotlight"
	dice_light.light_color = Color(1.0, 0.95, 0.82)
	dice_light.light_energy = 1.15
	dice_light.omni_range = 0.65
	dice_light.position = Vector3(0.0, 0.24, 0.0)
	dice_arena.add_child(dice_light)

	var dice_area: Area3D = Area3D.new()
	dice_area.name = "DiceArenaHitArea"
	dice_area.set_meta("interact_type", "dice_arena")
	var dice_col: CollisionShape3D = CollisionShape3D.new()
	var dice_cyl: CylinderShape3D = CylinderShape3D.new()
	dice_cyl.radius = 0.16
	dice_cyl.height = 0.08
	dice_col.shape = dice_cyl
	dice_col.position = Vector3(0.0, 0.03, 0.0)
	dice_area.add_child(dice_col)
	dice_arena.add_child(dice_area)

	# 4. Left & Right Interactive 3D Draw Decks in the Upper Command Bay
	refs["continent_deck"] = _build_draw_deck(
		root,
		Vector3(-0.34, y_felt + 0.003, -0.435),
		"continent",
		"دسته قاره 🗺️",
		Color(0.12, 0.44, 0.28),
		mats,
		font
	)
	refs["strategy_deck"] = _build_draw_deck(
		root,
		Vector3(0.34, y_felt + 0.003, -0.435),
		"strategy",
		"دسته استراتژی ⚡",
		Color(0.54, 0.16, 0.18),
		mats,
		font
	)

	# 5. Subtle War-Room Props on Outer Flanks of the Felt (Field Cannon & Naval Spyglass)
	_build_war_room_surround_props(root, mats, y_felt)

	return refs

static func _build_compass_rose_inlay(parent: Node3D, pos: Vector3, radius: float, mats: Dictionary) -> void:
	var comp: Node3D = Node3D.new()
	comp.position = pos
	parent.add_child(comp)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius * 0.78
	torus.outer_radius = radius * 0.90
	torus.rings = 24
	torus.ring_segments = 8
	torus.material = mats.get("ocean_line", mats["brass"])
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	comp.add_child(ring)

	for rot_deg: float in [0.0, 45.0]:
		for axis: float in [0.0, 90.0]:
			var needle: MeshInstance3D = MeshInstance3D.new()
			var nb: BoxMesh = BoxMesh.new()
			nb.size = Vector3(radius * (1.7 if rot_deg == 0.0 else 1.25), 0.0009, 0.0032)
			nb.material = mats.get("ocean_line", mats["brass"])
			needle.mesh = nb
			needle.rotation_degrees.y = rot_deg + axis
			needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			comp.add_child(needle)

	var center_gem: MeshInstance3D = MeshInstance3D.new()
	var cg_cyl: CylinderMesh = CylinderMesh.new()
	cg_cyl.top_radius = radius * 0.16
	cg_cyl.bottom_radius = radius * 0.20
	cg_cyl.height = 0.0022
	cg_cyl.radial_segments = 12
	cg_cyl.material = mats["bronze"]
	center_gem.mesh = cg_cyl
	center_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	comp.add_child(center_gem)

static func _build_war_room_surround_props(parent: Node3D, mats: Dictionary, y_felt: float) -> void:
	var props: Node3D = Node3D.new()
	props.name = "WarRoomSurroundProps"
	parent.add_child(props)

	# Western Flank: Brass Naval Spyglass on the Felt
	var spy: Node3D = Node3D.new()
	spy.position = Vector3(-0.615, y_felt + 0.014, 0.24)
	spy.rotation_degrees.y = -28.0
	props.add_child(spy)
	var tube_specs: Array[Dictionary] = [
		{"z": -0.036, "r": 0.010, "h": 0.064, "m": "brass"},
		{"z": 0.012, "r": 0.0135, "h": 0.068, "m": "leather"},
		{"z": 0.058, "r": 0.0165, "h": 0.052, "m": "brass"},
	]
	for tspec: Dictionary in tube_specs:
		var seg: MeshInstance3D = MeshInstance3D.new()
		var sc: CylinderMesh = CylinderMesh.new()
		sc.top_radius = tspec["r"]
		sc.bottom_radius = tspec["r"]
		sc.height = tspec["h"]
		sc.radial_segments = 12
		sc.material = mats[tspec["m"]]
		seg.mesh = sc
		seg.position = Vector3(0.0, 0.0, tspec["z"])
		seg.rotation_degrees.x = 90.0
		spy.add_child(seg)

	# Eastern Flank: Miniature Brass & Iron Field Cannon
	var cannon: Node3D = Node3D.new()
	cannon.position = Vector3(0.615, y_felt + 0.002, 0.24)
	cannon.rotation_degrees.y = 68.0
	props.add_child(cannon)

	var carriage: MeshInstance3D = MeshInstance3D.new()
	var car_bm: BoxMesh = BoxMesh.new()
	car_bm.size = Vector3(0.034, 0.014, 0.082)
	car_bm.material = mats["dark_wood"]
	carriage.mesh = car_bm
	carriage.position = Vector3(0.0, 0.011, 0.0)
	cannon.add_child(carriage)

	for wx: float in [-0.022, 0.022]:
		var wheel: MeshInstance3D = MeshInstance3D.new()
		var w_c: CylinderMesh = CylinderMesh.new()
		w_c.top_radius = 0.019
		w_c.bottom_radius = 0.019
		w_c.height = 0.007
		w_c.radial_segments = 12
		w_c.material = mats["bronze"]
		wheel.mesh = w_c
		wheel.position = Vector3(wx, 0.019, 0.012)
		wheel.rotation_degrees.z = 90.0
		cannon.add_child(wheel)

	var barrel: MeshInstance3D = MeshInstance3D.new()
	var br_cyl: CylinderMesh = CylinderMesh.new()
	br_cyl.top_radius = 0.011
	br_cyl.bottom_radius = 0.016
	br_cyl.height = 0.110
	br_cyl.radial_segments = 14
	br_cyl.material = mats.get("iron", mats["charcoal"])
	barrel.mesh = br_cyl
	barrel.position = Vector3(0.0, 0.030, -0.010)
	barrel.rotation_degrees = Vector3(82.0, 0.0, 0.0)
	cannon.add_child(barrel)

static func _build_draw_deck(
	parent: Node3D,
	pos: Vector3,
	deck_type: String,
	title_fa: String,
	back_col: Color,
	mats: Dictionary,
	font: Font
) -> Dictionary:
	var deck_root: Node3D = Node3D.new()
	deck_root.name = "Deck_" + deck_type
	deck_root.position = pos
	parent.add_child(deck_root)

	var tray_mi: MeshInstance3D = MeshInstance3D.new()
	var tray_bm: BoxMesh = BoxMesh.new()
	tray_bm.size = Vector3(0.142, 0.006, 0.112)
	tray_bm.material = mats["bronze"]
	tray_mi.mesh = tray_bm
	tray_mi.position = Vector3(0.0, 0.003, 0.0)
	deck_root.add_child(tray_mi)

	var stack_node: Node3D = Node3D.new()
	stack_node.name = "CardStackVisual"
	deck_root.add_child(stack_node)

	var top_mat: StandardMaterial3D = StandardMaterial3D.new()
	top_mat.albedo_color = back_col
	top_mat.roughness = 0.34
	top_mat.metallic = 0.14

	var card_layers: Array = []
	for i: int in range(8):
		var layer_mi: MeshInstance3D = MeshInstance3D.new()
		var layer_bm: BoxMesh = BoxMesh.new()
		layer_bm.size = Vector3(0.124, 0.0024, 0.096)
		layer_bm.material = mats["parchment"] if i < 7 else top_mat
		layer_mi.mesh = layer_bm
		layer_mi.position = Vector3(0.0, 0.007 + float(i) * 0.0025, 0.0)
		stack_node.add_child(layer_mi)
		card_layers.append(layer_mi)

	var glow_mi: MeshInstance3D = MeshInstance3D.new()
	var glow_bm: BoxMesh = BoxMesh.new()
	glow_bm.size = Vector3(0.156, 0.004, 0.126)
	glow_bm.material = mats["glow_gold"]
	glow_mi.mesh = glow_bm
	glow_mi.position = Vector3(0.0, 0.0035, 0.0)
	glow_mi.visible = false
	deck_root.add_child(glow_mi)

	var count_lbl: Label3D = Label3D.new()
	count_lbl.text = "۴۲"
	if font:
		count_lbl.font = font
	count_lbl.font_size = 56
	count_lbl.pixel_size = 0.00125
	count_lbl.modulate = Color(1.0, 0.96, 0.62)
	count_lbl.outline_size = 14
	count_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.99)
	count_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	count_lbl.position = Vector3(0.0, 0.036, -0.002)
	deck_root.add_child(count_lbl)

	var title_lbl: Label3D = Label3D.new()
	title_lbl.text = title_fa
	if font:
		title_lbl.font = font
	title_lbl.font_size = 36
	title_lbl.pixel_size = 0.0011
	title_lbl.modulate = Color(0.98, 0.90, 0.68)
	title_lbl.outline_size = 10
	title_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	title_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	title_lbl.position = Vector3(0.0, 0.020, 0.072)
	deck_root.add_child(title_lbl)

	# Generous Hitbox for Direct 3D Deck Tapping
	var area: Area3D = Area3D.new()
	area.name = "DeckHitArea"
	area.set_meta("interact_type", "deck")
	area.set_meta("deck_type", deck_type)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(0.18, 0.08, 0.16)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.030, 0.0)
	area.add_child(col)
	deck_root.add_child(area)

	return {
		"root": deck_root,
		"stack": stack_node,
		"layers": card_layers,
		"glow": glow_mi,
		"count_lbl": count_lbl,
		"title_lbl": title_lbl,
	}

# ==============================================================================
# REGION CONNECTORS — THIN, SUBTLE, BEHIND REGIONS, NEVER CROSSING LABELS
# ==============================================================================

static func build_sea_lane_bridges(parent: Node3D, mats: Dictionary) -> Dictionary:
	var bridges: Dictionary = {}
	var bridges_root: Node3D = Node3D.new()
	bridges_root.name = "SeaLaneBridges"
	parent.add_child(bridges_root)

	var y_line: float = 0.0615
	var built_pairs: Dictionary = {}
	for c_a: String in CONTINENT_ADJACENCY.keys():
		for c_b: String in CONTINENT_ADJACENCY[c_a]:
			var pair_key: String = (c_a + "_" + c_b) if c_a < c_b else (c_b + "_" + c_a)
			if built_pairs.has(pair_key):
				continue
			built_pairs[pair_key] = true

			var pos_a: Vector3 = CONTINENT_META[c_a]["pos"]
			var pos_b: Vector3 = CONTINENT_META[c_b]["pos"]
			var rad_a: float = float(CONTINENT_META[c_a]["radius"])
			var rad_b: float = float(CONTINENT_META[c_b]["radius"])

			if pair_key == "Asia_NorthAmerica":
				var wrap_node: Node3D = Node3D.new()
				wrap_node.name = "Bridge_" + pair_key
				bridges_root.add_child(wrap_node)
				var z_north: float = -0.335

				var z_na_top: float = pos_a.z - rad_a - 0.012
				var len_l: float = absf(z_na_top - z_north)
				var seg_l: MeshInstance3D = MeshInstance3D.new()
				var bm_l: BoxMesh = BoxMesh.new()
				bm_l.size = Vector3(0.008, 0.0025, maxf(0.01, len_l))
				bm_l.material = mats["bridge_idle"]
				seg_l.mesh = bm_l
				seg_l.position = Vector3(pos_a.x, y_line, (z_na_top + z_north) * 0.5)
				seg_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_l)

				var z_as_top: float = pos_b.z - rad_b - 0.012
				var len_r: float = absf(z_as_top - z_north)
				var seg_r: MeshInstance3D = MeshInstance3D.new()
				var bm_r: BoxMesh = BoxMesh.new()
				bm_r.size = Vector3(0.008, 0.0025, maxf(0.01, len_r))
				bm_r.material = mats["bridge_idle"]
				seg_r.mesh = bm_r
				seg_r.position = Vector3(pos_b.x, y_line, (z_as_top + z_north) * 0.5)
				seg_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_r)

				var span_w: float = absf(pos_b.x - pos_a.x) + 0.008
				var seg_m: MeshInstance3D = MeshInstance3D.new()
				var bm_m: BoxMesh = BoxMesh.new()
				bm_m.size = Vector3(span_w, 0.0025, 0.008)
				bm_m.material = mats["bridge_idle"]
				seg_m.mesh = bm_m
				seg_m.position = Vector3((pos_a.x + pos_b.x) * 0.5, y_line, z_north)
				seg_m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_m)

				for sx: float in [pos_a.x, pos_b.x]:
					var stud: MeshInstance3D = MeshInstance3D.new()
					var st_cyl: CylinderMesh = CylinderMesh.new()
					st_cyl.top_radius = 0.0065
					st_cyl.bottom_radius = 0.0075
					st_cyl.height = 0.003
					st_cyl.radial_segments = 10
					st_cyl.material = mats["brass"]
					stud.mesh = st_cyl
					stud.position = Vector3(sx, y_line + 0.0006, z_north)
					wrap_node.add_child(stud)

				bridges[pair_key] = wrap_node
				continue

			var diff: Vector3 = pos_b - pos_a
			var dist: float = Vector2(diff.x, diff.z).length()
			var dir: Vector2 = Vector2(diff.x, diff.z).normalized()
			var start_trim: float = rad_a + 0.018
			var end_trim: float = rad_b + 0.018
			var seg_len: float = maxf(0.02, dist - (start_trim + end_trim))
			var p_start: Vector2 = Vector2(pos_a.x, pos_a.z) + dir * start_trim
			var p_end: Vector2 = Vector2(pos_b.x, pos_b.z) - dir * end_trim
			var mid_2d: Vector2 = (p_start + p_end) * 0.5
			var angle_y: float = atan2(diff.x, diff.z)

			var bridge_node: Node3D = Node3D.new()
			bridge_node.name = "Bridge_" + pair_key
			bridges_root.add_child(bridge_node)

			var bridge_mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.008, 0.0025, seg_len)
			bm.material = mats["bridge_idle"]
			bridge_mi.mesh = bm
			bridge_mi.position = Vector3(mid_2d.x, y_line, mid_2d.y)
			bridge_mi.rotation.y = angle_y
			bridge_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bridge_node.add_child(bridge_mi)

			for ep: Vector2 in [p_start, p_end]:
				var stud: MeshInstance3D = MeshInstance3D.new()
				var st_cyl: CylinderMesh = CylinderMesh.new()
				st_cyl.top_radius = 0.0065
				st_cyl.bottom_radius = 0.0075
				st_cyl.height = 0.0035
				st_cyl.radial_segments = 10
				st_cyl.material = mats["brass"]
				stud.mesh = st_cyl
				stud.position = Vector3(ep.x, y_line + 0.0006, ep.y)
				stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bridge_node.add_child(stud)

			bridges[pair_key] = bridge_node

	return bridges

static func set_bridge_material(bridge_obj: Node, mat: Material) -> void:
	if not is_instance_valid(bridge_obj):
		return
	if bridge_obj is MeshInstance3D:
		(bridge_obj as MeshInstance3D).material_override = mat
	for ch: Node in bridge_obj.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = mat

# ==============================================================================
# SIX SCULPTED 3D CONTINENT ISLANDS ON THE CAFE FEKR FELT
# ==============================================================================

static func build_continent_node(
	parent: Node3D,
	c_id: String,
	mats: Dictionary,
	font: Font,
	_rook_mesh: Mesh,
	knight_mesh: Mesh,
	_king_mesh: Mesh
) -> Dictionary:
	var meta: Dictionary = CONTINENT_META[c_id]
	var pos: Vector3 = meta["pos"]
	var rad: float = float(meta["radius"])
	var cont_mat: StandardMaterial3D = RiskMaterials.get_continent_material(c_id, false)

	var root: Node3D = Node3D.new()
	root.name = "Continent_" + c_id
	root.position = pos
	parent.add_child(root)

	# 1. Contact Shadow Plinth
	var shadow_plinth: MeshInstance3D = MeshInstance3D.new()
	var sp_cyl: CylinderMesh = CylinderMesh.new()
	sp_cyl.top_radius = rad + 0.013
	sp_cyl.bottom_radius = rad + 0.017
	sp_cyl.height = 0.006
	sp_cyl.radial_segments = 28
	sp_cyl.material = mats["charcoal"]
	shadow_plinth.mesh = sp_cyl
	shadow_plinth.position = Vector3(0.0, 0.003, 0.0)
	shadow_plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow_plinth)

	# 2. Ownership Indicator Border/Base
	var ownership_bezel: MeshInstance3D = MeshInstance3D.new()
	var bz_cyl: CylinderMesh = CylinderMesh.new()
	bz_cyl.top_radius = rad + 0.008
	bz_cyl.bottom_radius = rad + 0.011
	bz_cyl.height = 0.016
	bz_cyl.radial_segments = 28
	bz_cyl.material = mats["bronze"]
	ownership_bezel.mesh = bz_cyl
	ownership_bezel.position = Vector3(0.0, 0.008, 0.0)
	ownership_bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ownership_bezel)

	# 3. Sculpted Stepped Territory Plateau + Inner Brass Rim + Citadel Keep
	var plateau: MeshInstance3D = MeshInstance3D.new()
	var pl_cyl: CylinderMesh = CylinderMesh.new()
	pl_cyl.top_radius = rad
	pl_cyl.bottom_radius = rad + 0.003
	pl_cyl.height = 0.022
	pl_cyl.radial_segments = 28
	pl_cyl.material = cont_mat
	plateau.mesh = pl_cyl
	plateau.position = Vector3(0.0, 0.012, 0.0)
	plateau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plateau)

	var inner_rim: MeshInstance3D = MeshInstance3D.new()
	var ir_tor: TorusMesh = TorusMesh.new()
	ir_tor.inner_radius = rad - 0.006
	ir_tor.outer_radius = rad - 0.002
	ir_tor.rings = 28
	ir_tor.ring_segments = 8
	ir_tor.material = mats["bronze"]
	inner_rim.mesh = ir_tor
	inner_rim.position = Vector3(0.0, 0.023, 0.0)
	inner_rim.scale = Vector3(1.0, 0.35, 1.0)
	inner_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner_rim)

	var citadel_mi: MeshInstance3D = MeshInstance3D.new()
	if _rook_mesh:
		citadel_mi.mesh = _rook_mesh
		citadel_mi.scale = Vector3(0.26, 0.26, 0.26)
		citadel_mi.material_override = mats["parchment"]
		citadel_mi.position = Vector3(-rad * 0.56, 0.023, -rad * 0.42)
		citadel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(citadel_mi)

	# 4. Selection / Valid Target Glowing Halo Ring
	var aura_ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = rad + 0.009
	torus.outer_radius = rad + 0.020
	torus.rings = 28
	torus.ring_segments = 10
	torus.material = mats["glow_gold"]
	aura_ring.mesh = torus
	aura_ring.position = Vector3(0.0, 0.014, 0.0)
	aura_ring.visible = false
	root.add_child(aura_ring)

	# 5. Domination Token Coin + Miniature Golden 3D Crown at North Edge
	var token_node: Node3D = build_domination_token_3d(c_id, mats, _king_mesh, 0.88)
	token_node.position = Vector3(0.0, 0.025, -rad * 0.66)
	root.add_child(token_node)

	# 6. Clean Region Name Plaque at South Edge (Includes Domination Threshold e.g. "اروپا • ۵👑")
	var plaque_base: MeshInstance3D = MeshInstance3D.new()
	var pb_box: BoxMesh = BoxMesh.new()
	pb_box.size = Vector3(rad * 1.28, 0.007, 0.034)
	pb_box.material = mats["charcoal"]
	plaque_base.mesh = pb_box
	plaque_base.position = Vector3(0.0, 0.022, rad * 0.82)
	plaque_base.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_base)

	var plaque_trim: MeshInstance3D = MeshInstance3D.new()
	var pt_box: BoxMesh = BoxMesh.new()
	pt_box.size = Vector3(rad * 1.32, 0.005, 0.037)
	pt_box.material = mats["bronze"]
	plaque_trim.mesh = pt_box
	plaque_trim.position = Vector3(0.0, 0.0205, rad * 0.82)
	plaque_trim.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_trim)

	var dom_req: int = int(meta.get("domination", 4))
	var name_lbl: Label3D = Label3D.new()
	name_lbl.text = "%s (%s👑)" % [str(meta["fa"]), fa_digits(dom_req)]
	if font:
		name_lbl.font = font
	name_lbl.font_size = 38
	name_lbl.pixel_size = 0.00102
	name_lbl.modulate = Color(0.99, 0.96, 0.88)
	name_lbl.outline_size = 10
	name_lbl.outline_modulate = Color(0.03, 0.02, 0.01, 0.98)
	name_lbl.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	name_lbl.position = Vector3(0.0, 0.028, rad * 0.83)
	root.add_child(name_lbl)

	# 7. Stacked Player Unit Tokens + Readable Quantity Badge
	var default_slots: Dictionary = {
		1: Vector3(-0.044, 0.023, -0.006),
		2: Vector3(0.044, 0.023, -0.006),
		3: Vector3(-0.044, 0.023, -0.042),
		4: Vector3(0.044, 0.023, -0.042),
	}
	var garrisons: Dictionary = {}
	for p_idx: int in [1, 2, 3, 4]:
		var g_node: Node3D = Node3D.new()
		g_node.name = "Garrison_P%d" % p_idx
		g_node.position = default_slots[p_idx]
		g_node.visible = false
		root.add_child(g_node)

		var f_mat: StandardMaterial3D = RiskMaterials.get_faction_material(p_idx, false)

		var stack_discs: Array[MeshInstance3D] = []
		for s_i: int in range(3):
			var disc_mi: MeshInstance3D = MeshInstance3D.new()
			var disc_cyl: CylinderMesh = CylinderMesh.new()
			disc_cyl.top_radius = 0.019
			disc_cyl.bottom_radius = 0.020
			disc_cyl.height = 0.005
			disc_cyl.radial_segments = 18
			disc_cyl.material = f_mat
			disc_mi.mesh = disc_cyl
			disc_mi.position = Vector3(0.0, 0.0025 + float(s_i) * 0.0052, -0.008)
			g_node.add_child(disc_mi)
			stack_discs.append(disc_mi)

		var piece_mi: MeshInstance3D = MeshInstance3D.new()
		if knight_mesh:
			piece_mi.mesh = knight_mesh
			piece_mi.scale = Vector3(0.25, 0.25, 0.25)
			piece_mi.position = Vector3(0.0, 0.013, -0.008)
		else:
			var sc: SphereMesh = SphereMesh.new()
			sc.radius = 0.012
			sc.height = 0.024
			piece_mi.mesh = sc
			piece_mi.position = Vector3(0.0, 0.018, -0.008)
		piece_mi.material_override = f_mat
		g_node.add_child(piece_mi)

		var badge_bg: MeshInstance3D = MeshInstance3D.new()
		var bb_box: BoxMesh = BoxMesh.new()
		bb_box.size = Vector3(0.050, 0.005, 0.028)
		bb_box.material = mats["charcoal"]
		badge_bg.mesh = bb_box
		badge_bg.position = Vector3(0.0, 0.010, 0.024)
		badge_bg.rotation_degrees = Vector3(20.0, 0.0, 0.0)
		g_node.add_child(badge_bg)

		var cnt_lbl: Label3D = Label3D.new()
		cnt_lbl.text = "×۱"
		if font:
			cnt_lbl.font = font
		cnt_lbl.font_size = 48
		cnt_lbl.pixel_size = 0.00118
		cnt_lbl.modulate = RiskMaterials.FACTION_COLORS[p_idx].lightened(0.48)
		cnt_lbl.outline_size = 12
		cnt_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.99)
		cnt_lbl.rotation_degrees = Vector3(-70.0, 0.0, 0.0)
		cnt_lbl.position = Vector3(0.0, 0.016, 0.025)
		g_node.add_child(cnt_lbl)

		garrisons[p_idx] = {
			"node": g_node,
			"piece": piece_mi,
			"stack_discs": stack_discs,
			"label": cnt_lbl,
		}

	# 8. Generous Mobile-Friendly Raycast Area3D for Tapping the Region
	var area: Area3D = Area3D.new()
	area.name = "ContinentHitArea"
	area.set_meta("interact_type", "continent")
	area.set_meta("continent", c_id)
	var col: CollisionShape3D = CollisionShape3D.new()
	var cyl_shape: CylinderShape3D = CylinderShape3D.new()
	cyl_shape.radius = rad + 0.024
	cyl_shape.height = 0.095
	col.shape = cyl_shape
	col.position = Vector3(0.0, 0.032, 0.0)
	area.add_child(col)
	root.add_child(area)

	return {
		"root": root,
		"base_pos": pos,
		"plateau": plateau,
		"ownership_bezel": ownership_bezel,
		"plaque_trim": plaque_trim,
		"citadel": citadel_mi,
		"aura": aura_ring,
		"token_node": token_node,
		"name_lbl": name_lbl,
		"garrisons": garrisons,
	}

static func layout_continent_garrisons(c_ref: Dictionary, present_players: Array[int]) -> void:
	var garrisons: Dictionary = c_ref["garrisons"]
	var count: int = present_players.size()
	var positions: Array[Vector3] = []
	if count == 1:
		positions = [Vector3(0.0, 0.023, -0.004)]
	elif count == 2:
		positions = [
			Vector3(-0.044, 0.023, -0.004),
			Vector3(0.044, 0.023, -0.004),
		]
	elif count == 3:
		positions = [
			Vector3(-0.050, 0.023, 0.004),
			Vector3(0.0, 0.023, -0.032),
			Vector3(0.050, 0.023, 0.004),
		]
	else:
		positions = [
			Vector3(-0.048, 0.023, 0.008),
			Vector3(0.048, 0.023, 0.008),
			Vector3(-0.048, 0.023, -0.034),
			Vector3(0.048, 0.023, -0.034),
		]

	for i: int in range(present_players.size()):
		var p_idx: int = present_players[i]
		if garrisons.has(p_idx):
			var g_node: Node3D = garrisons[p_idx]["node"]
			g_node.position = positions[min(i, positions.size() - 1)]

static func build_domination_token_3d(
	c_id: String,
	mats: Dictionary,
	crown_mesh: Mesh,
	scale_mult: float = 1.0
) -> Node3D:
	var token: Node3D = Node3D.new()
	token.name = "DominationToken_" + c_id
	token.scale = Vector3.ONE * scale_mult

	var coin_mi: MeshInstance3D = MeshInstance3D.new()
	var coin_cyl: CylinderMesh = CylinderMesh.new()
	coin_cyl.top_radius = 0.019
	coin_cyl.bottom_radius = 0.021
	coin_cyl.height = 0.005
	coin_cyl.radial_segments = 18
	coin_cyl.material = mats["gold"]
	coin_mi.mesh = coin_cyl
	token.add_child(coin_mi)

	var jewel_mi: MeshInstance3D = MeshInstance3D.new()
	var jewel_cyl: CylinderMesh = CylinderMesh.new()
	jewel_cyl.top_radius = 0.013
	jewel_cyl.bottom_radius = 0.013
	jewel_cyl.height = 0.006
	jewel_cyl.radial_segments = 16
	jewel_cyl.material = RiskMaterials.get_continent_material(c_id, false)
	jewel_mi.mesh = jewel_cyl
	jewel_mi.position = Vector3(0.0, 0.001, 0.0)
	token.add_child(jewel_mi)

	if crown_mesh:
		var cr_mi: MeshInstance3D = MeshInstance3D.new()
		cr_mi.mesh = crown_mesh
		cr_mi.scale = Vector3(0.55, 0.65, 0.55)
		cr_mi.position = Vector3(0.0, 0.004, 0.0)
		cr_mi.material_override = mats["gold"]
		token.add_child(cr_mi)

	return token

# 3D Commander Bastion Stations Along Table Edges (Interactive + Crown Trophies + Card Stacks)
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
	var station: Node3D = Node3D.new()
	station.name = "PlayerStation_P%d" % p_idx
	station.position = pos
	station.rotation_degrees.y = rot_y_deg
	parent.add_child(station)

	var f_mat_idle: StandardMaterial3D = RiskMaterials.get_faction_material(p_idx, false)
	var f_mat_active: StandardMaterial3D = RiskMaterials.get_faction_material(p_idx, true)

	var plinth: MeshInstance3D = MeshInstance3D.new()
	var p_bm: BoxMesh = BoxMesh.new()
	p_bm.size = Vector3(0.24, 0.012, 0.105)
	p_bm.material = mats["charcoal"]
	plinth.mesh = p_bm
	plinth.position = Vector3(0.0, 0.006, 0.0)
	station.add_child(plinth)

	var rim: MeshInstance3D = MeshInstance3D.new()
	var r_bm: BoxMesh = BoxMesh.new()
	r_bm.size = Vector3(0.248, 0.005, 0.113)
	r_bm.material = f_mat_idle
	rim.mesh = r_bm
	rim.position = Vector3(0.0, 0.0025, 0.0)
	station.add_child(rim)

	var active_glow: MeshInstance3D = MeshInstance3D.new()
	var ag_bm: BoxMesh = BoxMesh.new()
	ag_bm.size = Vector3(0.262, 0.003, 0.128)
	ag_bm.material = mats["glow_gold"]
	active_glow.mesh = ag_bm
	active_glow.position = Vector3(0.0, 0.0015, 0.0)
	active_glow.visible = false
	station.add_child(active_glow)

	var target_glow: MeshInstance3D = MeshInstance3D.new()
	var tg_bm: BoxMesh = BoxMesh.new()
	tg_bm.size = Vector3(0.270, 0.004, 0.134)
	tg_bm.material = mats["glow_crimson"]
	target_glow.mesh = tg_bm
	target_glow.position = Vector3(0.0, 0.002, 0.0)
	target_glow.visible = false
	station.add_child(target_glow)

	var cmd_pad: MeshInstance3D = MeshInstance3D.new()
	var cp_cyl: CylinderMesh = CylinderMesh.new()
	cp_cyl.top_radius = 0.022
	cp_cyl.bottom_radius = 0.026
	cp_cyl.height = 0.005
	cp_cyl.radial_segments = 16
	cp_cyl.material = mats["brass"]
	cmd_pad.mesh = cp_cyl
	cmd_pad.position = Vector3(-0.080, 0.015, -0.004)
	station.add_child(cmd_pad)

	var commander_mi: MeshInstance3D = MeshInstance3D.new()
	if king_mesh:
		commander_mi.mesh = king_mesh
		commander_mi.scale = Vector3(0.40, 0.40, 0.40)
		commander_mi.position = Vector3(-0.080, 0.018, -0.004)
	else:
		var s_m: SphereMesh = SphereMesh.new()
		s_m.radius = 0.016
		s_m.height = 0.032
		commander_mi.mesh = s_m
		commander_mi.position = Vector3(-0.080, 0.032, -0.004)
	commander_mi.material_override = f_mat_idle
	station.add_child(commander_mi)

	for sx: float in [0.054, 0.094]:
		var sock: MeshInstance3D = MeshInstance3D.new()
		var sk_cyl: CylinderMesh = CylinderMesh.new()
		sk_cyl.top_radius = 0.015
		sk_cyl.bottom_radius = 0.017
		sk_cyl.height = 0.004
		sk_cyl.radial_segments = 14
		sk_cyl.material = mats["bronze"]
		sock.mesh = sk_cyl
		sock.position = Vector3(sx, 0.014, -0.012)
		station.add_child(sock)

	var assets_container: Node3D = Node3D.new()
	assets_container.name = "StationAssets"
	station.add_child(assets_container)

	var stats_lbl: Label3D = Label3D.new()
	stats_lbl.text = "👑۰  🃏۰"
	if font:
		stats_lbl.font = font
	stats_lbl.font_size = 34
	stats_lbl.pixel_size = 0.00095
	stats_lbl.modulate = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE).lightened(0.45)
	stats_lbl.outline_size = 10
	stats_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.98)
	stats_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	stats_lbl.position = Vector3(0.015, 0.018, 0.034)
	station.add_child(stats_lbl)

	var name_lbl: Label3D = Label3D.new()
	name_lbl.visible = false
	station.add_child(name_lbl)

	var area: Area3D = Area3D.new()
	area.name = "StationHitArea"
	area.set_meta("interact_type", "station")
	area.set_meta("player_index", p_idx)
	var col: CollisionShape3D = CollisionShape3D.new()
	var b_sh: BoxShape3D = BoxShape3D.new()
	b_sh.size = Vector3(0.28, 0.08, 0.14)
	col.shape = b_sh
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
		"base_w": 0.24,
	}

static func populate_station_assets_3d(
	station_ref: Dictionary,
	p_data: Dictionary,
	mats: Dictionary,
	_font: Font,
	crown_mesh: Mesh
) -> void:
	var container: Node3D = station_ref.get("assets_container", null)
	if not is_instance_valid(container):
		return
	for ch: Node in container.get_children():
		ch.queue_free()

	var tokens: Array = p_data.get("tokens", [])
	var conts: Dictionary = p_data.get("continents", {})
	var c_total: int = 0
	for k: Variant in conts.keys():
		c_total += int(conts[k])
	var s_total: int = int(p_data.get("strategies_count", 0))

	var stats_lbl: Label3D = station_ref.get("stats_lbl", null)
	if is_instance_valid(stats_lbl):
		stats_lbl.text = "👑%s  🗺️%s  ⚡%s" % [
			fa_digits(tokens.size()),
			fa_digits(c_total),
			fa_digits(s_total),
		]

	var crown_xs: Array[float] = [0.054, 0.094]
	for i: int in range(min(2, tokens.size())):
		var cr_mi: MeshInstance3D = MeshInstance3D.new()
		if crown_mesh:
			cr_mi.mesh = crown_mesh
			cr_mi.scale = Vector3(0.64, 0.70, 0.64)
		else:
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.012
			cyl.bottom_radius = 0.014
			cyl.height = 0.012
			cr_mi.mesh = cyl
		cr_mi.material_override = mats["gold"]
		cr_mi.position = Vector3(crown_xs[i], 0.016, -0.012)
		container.add_child(cr_mi)

	var c_layers: int = clampi(int(ceil(float(c_total) / 2.0)), 0, 5)
	for i: int in range(c_layers):
		var c_mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.034, 0.0025, 0.046)
		bm.material = mats.get("continent_card_back", mats["emerald_velvet"])
		c_mi.mesh = bm
		c_mi.position = Vector3(-0.026, 0.014 + float(i) * 0.0026, -0.010)
		container.add_child(c_mi)

	var s_layers: int = clampi(int(ceil(float(s_total) / 2.0)), 0, 5)
	for i: int in range(s_layers):
		var s_mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.034, 0.0025, 0.046)
		bm.material = mats.get("die_attacker", mats["crimson_wax"])
		s_mi.mesh = bm
		s_mi.position = Vector3(0.014, 0.014 + float(i) * 0.0026, -0.010)
		container.add_child(s_mi)

static func build_3d_die(is_attacker: bool, mats: Dictionary, font: Font = null, final_val: int = 1) -> Node3D:
	var die_root: Node3D = Node3D.new()
	die_root.name = "BattleDie3D"
	var s: float = 0.068
	var half: float = s * 0.5

	var cube_pivot: Node3D = Node3D.new()
	cube_pivot.name = "CubePivot"
	die_root.add_child(cube_pivot)

	var body_mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(s, s, s)
	bm.material = mats["die_attacker"] if is_attacker else mats["die_defender"]
	body_mi.mesh = bm
	cube_pivot.add_child(body_mi)

	for cx: float in [-half * 0.94, half * 0.94]:
		for cy: float in [-half * 0.94, half * 0.94]:
			for cz: float in [-half * 0.94, half * 0.94]:
				var stud_mi: MeshInstance3D = MeshInstance3D.new()
				var sm: SphereMesh = SphereMesh.new()
				sm.radius = 0.0064
				sm.height = 0.0128
				sm.material = mats["gold"] if is_attacker else mats["brass"]
				stud_mi.mesh = sm
				stud_mi.position = Vector3(cx, cy, cz)
				cube_pivot.add_child(stud_mi)

	var edge_t: float = 0.0046
	var edge_l: float = s * 0.94
	var trim_mat: Material = mats["gold"] if is_attacker else mats["brass"]
	for s1: float in [-half * 0.96, half * 0.96]:
		for s2: float in [-half * 0.96, half * 0.96]:
			var ex: MeshInstance3D = MeshInstance3D.new()
			var bx: BoxMesh = BoxMesh.new()
			bx.size = Vector3(edge_l, edge_t, edge_t)
			bx.material = trim_mat
			ex.mesh = bx
			ex.position = Vector3(0.0, s1, s2)
			cube_pivot.add_child(ex)

			var ey: MeshInstance3D = MeshInstance3D.new()
			var by: BoxMesh = BoxMesh.new()
			by.size = Vector3(edge_t, edge_l, edge_t)
			by.material = trim_mat
			ey.mesh = by
			ey.position = Vector3(s1, 0.0, s2)
			cube_pivot.add_child(ey)

			var ez: MeshInstance3D = MeshInstance3D.new()
			var bz: BoxMesh = BoxMesh.new()
			bz.size = Vector3(edge_t, edge_t, edge_l)
			bz.material = trim_mat
			ez.mesh = bz
			ez.position = Vector3(s1, s2, 0.0)
			cube_pivot.add_child(ez)

	var d: float = s * 0.265
	var face_pips: Dictionary = {
		Vector3(0, 1, 0): [Vector2(0, 0)],
		Vector3(0, -1, 0): [Vector2(-d, -d), Vector2(-d, 0), Vector2(-d, d), Vector2(d, -d), Vector2(d, 0), Vector2(d, d)],
		Vector3(0, 0, 1): [Vector2(-d, -d), Vector2(d, d)],
		Vector3(0, 0, -1): [Vector2(-d, -d), Vector2(d, -d), Vector2(0, 0), Vector2(-d, d), Vector2(d, d)],
		Vector3(1, 0, 0): [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)],
		Vector3(-1, 0, 0): [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
	}
	for normal: Vector3 in face_pips.keys():
		var is_one_face: bool = (normal == Vector3(0, 1, 0))
		for uv: Vector2 in face_pips[normal]:
			var pip_mi: MeshInstance3D = MeshInstance3D.new()
			var pm: SphereMesh = SphereMesh.new()
			pm.radius = 0.0086 if is_one_face else 0.0068
			pm.height = 0.0172 if is_one_face else 0.0136
			pm.material = mats["pip_ivory"]
			pip_mi.mesh = pm
			var p3: Vector3 = Vector3.ZERO
			if absf(normal.y) > 0.5:
				p3 = Vector3(uv.x, normal.y * (half + 0.0018), uv.y)
			elif absf(normal.z) > 0.5:
				p3 = Vector3(uv.x, uv.y, normal.z * (half + 0.0018))
			else:
				p3 = Vector3(normal.x * (half + 0.0018), uv.y, uv.x)
			pip_mi.position = p3
			cube_pivot.add_child(pip_mi)

	var badge_lbl: Label3D = make_label_3d(
		"%s %s" % ["⚔️" if is_attacker else "🛡️", fa_digits(clampi(final_val, 1, 6))],
		font,
		58,
		Color(1.0, 0.92, 0.46) if is_attacker else Color(0.58, 0.92, 1.0),
		0.0012
	)
	badge_lbl.name = "DieValueBadge"
	badge_lbl.position = Vector3(0.0, half + 0.042, 0.0)
	badge_lbl.outline_size = 18
	badge_lbl.visible = false
	die_root.add_child(badge_lbl)

	return die_root

static func make_label_3d(
	text_str: String,
	font: Font,
	font_sz: int = 44,
	col: Color = Color.WHITE,
	px_size: float = 0.0012
) -> Label3D:
	var lbl: Label3D = Label3D.new()
	lbl.text = text_str
	if font:
		lbl.font = font
	lbl.font_size = font_sz
	lbl.pixel_size = px_size
	lbl.modulate = col
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0.03, 0.02, 0.01, 0.98)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	return lbl

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
