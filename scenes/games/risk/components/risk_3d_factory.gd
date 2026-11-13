class_name Risk3DFactory
extends RefCounted

# ==============================================================================
# RISK STRIKE — SIMPLIFIED, HIGH-CLARITY 3D TABLETOP & REGION BUILDER
# Design Principle: ONE REGION = ONE CLEAR VISUAL UNIT
# ==============================================================================

const CONTINENT_META: Dictionary = {
	"NorthAmerica": {
		"fa": "آمریکای شمالی",
		"pos": Vector3(-0.39, 0.048, -0.22),
		"radius": 0.124,
		"domination": 6,
	},
	"Europe": {
		"fa": "اروپا",
		"pos": Vector3(0.00, 0.048, -0.24),
		"radius": 0.122,
		"domination": 5,
	},
	"Asia": {
		"fa": "آسیا",
		"pos": Vector3(0.39, 0.048, -0.22),
		"radius": 0.124,
		"domination": 8,
	},
	"SouthAmerica": {
		"fa": "آمریکای جنوبی",
		"pos": Vector3(-0.38, 0.048, 0.17),
		"radius": 0.122,
		"domination": 3,
	},
	"Africa": {
		"fa": "آفریقا",
		"pos": Vector3(0.00, 0.048, 0.19),
		"radius": 0.122,
		"domination": 4,
	},
	"Australia": {
		"fa": "اقیانوسیه",
		"pos": Vector3(0.38, 0.048, 0.17),
		"radius": 0.122,
		"domination": 3,
	},
}

# Exact original backend adjacency relationships (Entities/Games/Risk/Handlers/risk_attack_handler.py)
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

	# 1. Expanded Dark Walnut Command Tabletop Slab & Outer Brass Trim
	var table_slab = MeshInstance3D.new()
	var slab_box = BoxMesh.new()
	slab_box.size = Vector3(1.56, 0.024, 1.50)
	slab_box.material = mats["walnut"]
	table_slab.mesh = slab_box
	table_slab.position = Vector3(0.0, 0.012, -0.07)
	table_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(table_slab)

	var outer_trim_specs = [
		{"pos": Vector3(0.0, 0.0245, -0.812), "size": Vector3(1.56, 0.005, 0.016)},
		{"pos": Vector3(0.0, 0.0245, 0.672), "size": Vector3(1.56, 0.005, 0.016)},
		{"pos": Vector3(-0.772, 0.0245, -0.07), "size": Vector3(0.016, 0.005, 1.50)},
		{"pos": Vector3(0.772, 0.0245, -0.07), "size": Vector3(0.016, 0.005, 1.50)},
	]
	for ospec in outer_trim_specs:
		var ot_mi = MeshInstance3D.new()
		var ot_bm = BoxMesh.new()
		ot_bm.size = ospec["size"]
		ot_bm.material = mats["dark_wood"]
		ot_mi.mesh = ot_bm
		ot_mi.position = ospec["pos"]
		ot_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ot_mi)

	# Four Corner Brass Bolsters & Rivets on Outer Command Table
	for cx in [-0.748, 0.748]:
		for cz in [-0.788, 0.648]:
			var corner_plate = MeshInstance3D.new()
			var cp_box = BoxMesh.new()
			cp_box.size = Vector3(0.056, 0.005, 0.056)
			cp_box.material = mats["bronze"]
			corner_plate.mesh = cp_box
			corner_plate.position = Vector3(cx, 0.025, cz)
			corner_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(corner_plate)

			var rivet = MeshInstance3D.new()
			var rv_cyl = CylinderMesh.new()
			rv_cyl.top_radius = 0.0075
			rv_cyl.bottom_radius = 0.009
			rv_cyl.height = 0.006
			rv_cyl.radial_segments = 12
			rv_cyl.material = mats["brass"]
			rivet.mesh = rv_cyl
			rivet.position = Vector3(cx, 0.0285, cz)
			rivet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(rivet)

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
		{"pos": Vector3(0.0, 0.048, -0.590), "size": Vector3(1.16, 0.006, 0.012)},
		{"pos": Vector3(0.0, 0.048, 0.390), "size": Vector3(1.16, 0.006, 0.012)},
		{"pos": Vector3(-0.576, 0.048, -0.10), "size": Vector3(0.012, 0.006, 0.98)},
		{"pos": Vector3(0.576, 0.048, -0.10), "size": Vector3(0.012, 0.006, 0.98)},
		# Divider rail separating the Upper Deck Bay (z=-0.49) from the Central Map Arena
		{"pos": Vector3(0.0, 0.047, -0.395), "size": Vector3(1.14, 0.005, 0.008)},
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

	# Dark Emerald Green Baize Velvet Playing Bed
	var velvet_bed = MeshInstance3D.new()
	var vb_box = BoxMesh.new()
	vb_box.size = Vector3(1.14, 0.005, 0.77)
	vb_box.material = mats["emerald_velvet"]
	velvet_bed.mesh = vb_box
	velvet_bed.position = Vector3(0.0, 0.0445, -0.005)
	velvet_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(velvet_bed)

	# Subtle Inlaid Cartography Latitude & Meridian Lines + Ocean Compass Roses
	var grid_mat = mats.get("ocean_line", mats["brass"])
	for gx in [-0.38, -0.19, 0.0, 0.19, 0.38]:
		var lon = MeshInstance3D.new()
		var lon_bm = BoxMesh.new()
		lon_bm.size = Vector3(0.0022, 0.0008, 0.75)
		lon_bm.material = grid_mat
		lon.mesh = lon_bm
		lon.position = Vector3(gx, 0.0472, -0.005)
		lon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lon)
	for gz in [-0.24, -0.02, 0.20]:
		var lat = MeshInstance3D.new()
		var lat_bm = BoxMesh.new()
		lat_bm.size = Vector3(1.12, 0.0008, 0.0022)
		lat_bm.material = grid_mat
		lat.mesh = lat_bm
		lat.position = Vector3(0.0, 0.0472, gz)
		lat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lat)

	# Twin Brass Compass Rose Inlays in the Open Southern Ocean Bays (Completely clear of plaques!)
	_build_compass_rose_inlay(root, Vector3(-0.20, 0.0473, 0.322), 0.042, mats)
	_build_compass_rose_inlay(root, Vector3(0.20, 0.0473, 0.322), 0.042, mats)

	# Upper Recessed Leather Bay (Holds Continent Deck & Strategy Deck cleanly outside the map)
	var upper_bay = MeshInstance3D.new()
	var ub_box = BoxMesh.new()
	ub_box.size = Vector3(1.14, 0.005, 0.18)
	ub_box.material = mats["leather"]
	upper_bay.mesh = ub_box
	upper_bay.position = Vector3(0.0, 0.0445, -0.49)
	upper_bay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(upper_bay)

	# 3. Dedicated 3D Dice Rolling Tray (Hidden when idle so the board stays quiet; appears during combat rolls)
	var dice_arena = Node3D.new()
	dice_arena.name = "CentralDiceArena"
	dice_arena.position = Vector3(0.0, 0.048, -0.49)
	dice_arena.scale = Vector3(0.62, 0.62, 0.62)
	dice_arena.visible = false
	root.add_child(dice_arena)
	refs["dice_arena"] = dice_arena

	var arena_rim = MeshInstance3D.new()
	var ar_cyl = CylinderMesh.new()
	ar_cyl.top_radius = 0.148
	ar_cyl.bottom_radius = 0.158
	ar_cyl.height = 0.016
	ar_cyl.radial_segments = 18
	ar_cyl.material = mats["bronze"]
	arena_rim.mesh = ar_cyl
	arena_rim.position = Vector3(0.0, 0.008, 0.0)
	dice_arena.add_child(arena_rim)

	var arena_bed = MeshInstance3D.new()
	var ab_cyl = CylinderMesh.new()
	ab_cyl.top_radius = 0.134
	ab_cyl.bottom_radius = 0.134
	ab_cyl.height = 0.018
	ab_cyl.radial_segments = 18
	ab_cyl.material = mats["emerald_velvet"]
	arena_bed.mesh = ab_cyl
	arena_bed.position = Vector3(0.0, 0.009, 0.0)
	dice_arena.add_child(arena_bed)

	var dice_light = OmniLight3D.new()
	dice_light.name = "DiceSpotlight"
	dice_light.light_color = Color(1.0, 0.95, 0.82)
	dice_light.light_energy = 1.25
	dice_light.omni_range = 0.65
	dice_light.position = Vector3(0.0, 0.24, 0.0)
	dice_arena.add_child(dice_light)

	# 4. Left & Right 3D Draw Decks in the Upper Command Bay (Zero overlap with the 6 regions!)
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

	# 5. War-Room 3D Surround Props Around the Main Command Board (Left, Right & Lower Ledge)
	_build_war_room_surround_props(root, mats)

	return refs

static func _build_compass_rose_inlay(parent: Node3D, pos: Vector3, radius: float, mats: Dictionary) -> void:
	var comp = Node3D.new()
	comp.position = pos
	parent.add_child(comp)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radius * 0.78
	torus.outer_radius = radius * 0.90
	torus.rings = 24
	torus.ring_segments = 8
	torus.material = mats.get("ocean_line", mats["brass"])
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	comp.add_child(ring)

	for rot_deg in [0.0, 45.0]:
		for axis in [0.0, 90.0]:
			var needle = MeshInstance3D.new()
			var nb = BoxMesh.new()
			nb.size = Vector3(radius * (1.7 if rot_deg == 0.0 else 1.25), 0.0009, 0.0032)
			nb.material = mats.get("ocean_line", mats["brass"])
			needle.mesh = nb
			needle.rotation_degrees.y = rot_deg + axis
			needle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			comp.add_child(needle)

	var center_gem = MeshInstance3D.new()
	var cg_cyl = CylinderMesh.new()
	cg_cyl.top_radius = radius * 0.16
	cg_cyl.bottom_radius = radius * 0.20
	cg_cyl.height = 0.0022
	cg_cyl.radial_segments = 12
	cg_cyl.material = mats["bronze"]
	center_gem.mesh = cg_cyl
	center_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	comp.add_child(center_gem)

static func _build_war_room_surround_props(parent: Node3D, mats: Dictionary) -> void:
	var props = Node3D.new()
	props.name = "WarRoomSurroundProps"
	parent.add_child(props)

	# A. Western Flank (-0.685, 0.024, -0.10): Unrolled Tactical War Scroll + Crimson Wax Seal + Brass Spyglass
	var west_group = Node3D.new()
	west_group.name = "WestCartographyProps"
	west_group.position = Vector3(-0.685, 0.024, -0.06)
	props.add_child(west_group)

	var scroll_sheet = MeshInstance3D.new()
	var ss_box = BoxMesh.new()
	ss_box.size = Vector3(0.098, 0.0035, 0.148)
	ss_box.material = mats["parchment"]
	scroll_sheet.mesh = ss_box
	scroll_sheet.position = Vector3(0.0, 0.004, 0.0)
	scroll_sheet.rotation_degrees.y = 8.0
	west_group.add_child(scroll_sheet)

	for z_roll in [-0.072, 0.072]:
		var roll = MeshInstance3D.new()
		var r_cyl = CylinderMesh.new()
		r_cyl.top_radius = 0.010
		r_cyl.bottom_radius = 0.010
		r_cyl.height = 0.106
		r_cyl.radial_segments = 14
		r_cyl.material = mats["parchment"]
		roll.mesh = r_cyl
		roll.position = Vector3(0.0, 0.010, z_roll)
		roll.rotation_degrees = Vector3(0.0, 8.0, 90.0)
		west_group.add_child(roll)

	var wax = MeshInstance3D.new()
	var w_cyl = CylinderMesh.new()
	w_cyl.top_radius = 0.012
	w_cyl.bottom_radius = 0.014
	w_cyl.height = 0.004
	w_cyl.radial_segments = 12
	w_cyl.material = mats.get("crimson_wax", mats["die_attacker"])
	wax.mesh = w_cyl
	wax.position = Vector3(0.016, 0.008, 0.028)
	west_group.add_child(wax)

	# Brass Naval Spyglass beside the scroll
	var spy = Node3D.new()
	spy.position = Vector3(-0.008, 0.016, -0.175)
	spy.rotation_degrees.y = -24.0
	west_group.add_child(spy)
	var tube_specs = [
		{"z": -0.036, "r": 0.011, "h": 0.068, "m": "brass"},
		{"z": 0.014, "r": 0.0145, "h": 0.072, "m": "leather"},
		{"z": 0.064, "r": 0.0175, "h": 0.056, "m": "brass"},
	]
	for tspec in tube_specs:
		var seg = MeshInstance3D.new()
		var sc = CylinderMesh.new()
		sc.top_radius = tspec["r"]
		sc.bottom_radius = tspec["r"]
		sc.height = tspec["h"]
		sc.radial_segments = 14
		sc.material = mats[tspec["m"]]
		seg.mesh = sc
		seg.position = Vector3(0.0, 0.0, tspec["z"])
		seg.rotation_degrees.x = 90.0
		spy.add_child(seg)
	var lens = MeshInstance3D.new()
	var l_cyl = CylinderMesh.new()
	l_cyl.top_radius = 0.0145
	l_cyl.bottom_radius = 0.0145
	l_cyl.height = 0.004
	l_cyl.radial_segments = 14
	l_cyl.material = mats.get("glass", mats["glow_emerald"])
	lens.mesh = l_cyl
	lens.position = Vector3(0.0, 0.0, 0.092)
	lens.rotation_degrees.x = 90.0
	spy.add_child(lens)

	# B. Eastern Flank (0.685, 0.024, -0.08): Miniature Brass & Iron Field Cannon + Cannonballs
	var east_group = Node3D.new()
	east_group.name = "EastArtilleryProps"
	east_group.position = Vector3(0.685, 0.024, -0.06)
	props.add_child(east_group)

	var cannon = Node3D.new()
	cannon.position = Vector3(0.0, 0.0, -0.04)
	cannon.rotation_degrees.y = 74.0 # Aimed proudly toward the central map
	east_group.add_child(cannon)

	var carriage = MeshInstance3D.new()
	var car_bm = BoxMesh.new()
	car_bm.size = Vector3(0.036, 0.014, 0.086)
	car_bm.material = mats["dark_wood"]
	carriage.mesh = car_bm
	carriage.position = Vector3(0.0, 0.011, 0.0)
	cannon.add_child(carriage)

	for wx in [-0.024, 0.024]:
		var wheel = MeshInstance3D.new()
		var w_c = CylinderMesh.new()
		w_c.top_radius = 0.020
		w_c.bottom_radius = 0.020
		w_c.height = 0.008
		w_c.radial_segments = 14
		w_c.material = mats["bronze"]
		wheel.mesh = w_c
		wheel.position = Vector3(wx, 0.020, 0.014)
		wheel.rotation_degrees.z = 90.0
		cannon.add_child(wheel)

	var barrel = MeshInstance3D.new()
	var br_cyl = CylinderMesh.new()
	br_cyl.top_radius = 0.012
	br_cyl.bottom_radius = 0.017
	br_cyl.height = 0.118
	br_cyl.radial_segments = 16
	br_cyl.material = mats.get("iron", mats["charcoal"])
	barrel.mesh = br_cyl
	barrel.position = Vector3(0.0, 0.032, -0.010)
	barrel.rotation_degrees = Vector3(82.0, 0.0, 0.0)
	cannon.add_child(barrel)

	var muzzle = MeshInstance3D.new()
	var mz_tor = TorusMesh.new()
	mz_tor.inner_radius = 0.009
	mz_tor.outer_radius = 0.015
	mz_tor.rings = 14
	mz_tor.ring_segments = 8
	mz_tor.material = mats["brass"]
	muzzle.mesh = mz_tor
	muzzle.position = Vector3(0.0, 0.040, -0.066)
	muzzle.rotation_degrees.x = 82.0
	cannon.add_child(muzzle)

	# Stacked Iron Cannonball Pyramid beside the cannon
	var ball_positions = [
		Vector3(-0.014, 0.010, 0.11),
		Vector3(0.014, 0.010, 0.11),
		Vector3(0.0, 0.010, 0.135),
		Vector3(0.0, 0.028, 0.118),
	]
	for bp in ball_positions:
		var ball = MeshInstance3D.new()
		var bs = SphereMesh.new()
		bs.radius = 0.010
		bs.height = 0.020
		bs.material = mats.get("iron", mats["charcoal"])
		ball.mesh = bs
		ball.position = bp
		east_group.add_child(ball)

	# C. Bottom-Left Outer Ledge (-0.48, 0.024, 0.52): Warriors' Leather & Brass Dice Cup + 2 Ivory Dice + Supply Crates
	var sw_group = Node3D.new()
	sw_group.name = "SouthWestWarGear"
	sw_group.position = Vector3(-0.48, 0.024, 0.52)
	props.add_child(sw_group)

	var tray_base = MeshInstance3D.new()
	var tb_box = BoxMesh.new()
	tb_box.size = Vector3(0.24, 0.008, 0.12)
	tb_box.material = mats["charcoal"]
	tray_base.mesh = tb_box
	tray_base.position = Vector3(0.0, 0.004, 0.0)
	sw_group.add_child(tray_base)

	var cup = MeshInstance3D.new()
	var cup_cyl = CylinderMesh.new()
	cup_cyl.top_radius = 0.030
	cup_cyl.bottom_radius = 0.024
	cup_cyl.height = 0.062
	cup_cyl.radial_segments = 16
	cup_cyl.material = mats["leather"]
	cup.mesh = cup_cyl
	cup.position = Vector3(-0.062, 0.035, 0.0)
	sw_group.add_child(cup)

	var cup_lip = MeshInstance3D.new()
	var cl_tor = TorusMesh.new()
	cl_tor.inner_radius = 0.026
	cl_tor.outer_radius = 0.032
	cl_tor.rings = 16
	cl_tor.ring_segments = 8
	cl_tor.material = mats["brass"]
	cup_lip.mesh = cl_tor
	cup_lip.position = Vector3(-0.062, 0.065, 0.0)
	sw_group.add_child(cup_lip)

	for d_spec in [{"pos": Vector3(0.002, 0.017, -0.014), "ry": 18.0}, {"pos": Vector3(0.034, 0.017, 0.018), "ry": -32.0}]:
		var d_cube = MeshInstance3D.new()
		var d_bm = BoxMesh.new()
		d_bm.size = Vector3(0.022, 0.022, 0.022)
		d_bm.material = mats.get("ivory", mats["parchment"])
		d_cube.mesh = d_bm
		d_cube.position = d_spec["pos"]
		d_cube.rotation_degrees.y = d_spec["ry"]
		sw_group.add_child(d_cube)

	# Brass-bound wooden supply crate on right side of tray
	var crate = MeshInstance3D.new()
	var cr_bm = BoxMesh.new()
	cr_bm.size = Vector3(0.056, 0.032, 0.044)
	cr_bm.material = mats["dark_wood"]
	crate.mesh = cr_bm
	crate.position = Vector3(0.080, 0.024, -0.004)
	crate.rotation_degrees.y = -10.0
	sw_group.add_child(crate)

	var crate_band = MeshInstance3D.new()
	var cb_bm = BoxMesh.new()
	cb_bm.size = Vector3(0.058, 0.006, 0.046)
	cb_bm.material = mats["brass"]
	crate_band.mesh = cb_bm
	crate_band.position = Vector3(0.080, 0.030, -0.004)
	crate_band.rotation_degrees.y = -10.0
	sw_group.add_child(crate_band)

	# D. Top-Left & Top-Right Outer Corner Command Beacons (Balanced framing around top stations)
	for bx in [-0.695, 0.695]:
		var beacon = Node3D.new()
		beacon.position = Vector3(bx, 0.024, -0.70)
		props.add_child(beacon)
		var b_base = MeshInstance3D.new()
		var bb_cyl = CylinderMesh.new()
		bb_cyl.top_radius = 0.024
		bb_cyl.bottom_radius = 0.030
		bb_cyl.height = 0.012
		bb_cyl.radial_segments = 14
		bb_cyl.material = mats["bronze"]
		b_base.mesh = bb_cyl
		b_base.position = Vector3(0.0, 0.006, 0.0)
		beacon.add_child(b_base)
		var b_gem = MeshInstance3D.new()
		var bg_oct = SphereMesh.new()
		bg_oct.radius = 0.013
		bg_oct.height = 0.026
		bg_oct.material = mats["gold"]
		b_gem.mesh = bg_oct
		b_gem.position = Vector3(0.0, 0.022, 0.0)
		beacon.add_child(b_gem)

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

	var tray_mi = MeshInstance3D.new()
	var tray_bm = BoxMesh.new()
	tray_bm.size = Vector3(0.128, 0.005, 0.102)
	tray_bm.material = mats["bronze"]
	tray_mi.mesh = tray_bm
	tray_mi.position = Vector3(0.0, 0.0025, 0.0)
	deck_root.add_child(tray_mi)

	var stack_node = Node3D.new()
	stack_node.name = "CardStackVisual"
	deck_root.add_child(stack_node)

	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = back_col
	top_mat.roughness = 0.38
	top_mat.metallic = 0.12

	var card_layers: Array = []
	for i in range(8):
		var layer_mi = MeshInstance3D.new()
		var layer_bm = BoxMesh.new()
		layer_bm.size = Vector3(0.112, 0.0022, 0.088)
		layer_bm.material = mats["parchment"] if i < 7 else top_mat
		layer_mi.mesh = layer_bm
		layer_mi.position = Vector3(0.0, 0.006 + float(i) * 0.0023, 0.0)
		stack_node.add_child(layer_mi)
		card_layers.append(layer_mi)

	var glow_mi = MeshInstance3D.new()
	var glow_bm = BoxMesh.new()
	glow_bm.size = Vector3(0.138, 0.003, 0.112)
	glow_bm.material = mats["glow_gold"]
	glow_mi.mesh = glow_bm
	glow_mi.position = Vector3(0.0, 0.003, 0.0)
	glow_mi.visible = false
	deck_root.add_child(glow_mi)

	var count_lbl = Label3D.new()
	count_lbl.text = "۴۲"
	if font:
		count_lbl.font = font
	count_lbl.font_size = 54
	count_lbl.pixel_size = 0.00125
	count_lbl.modulate = Color(1.0, 0.96, 0.62)
	count_lbl.outline_size = 14
	count_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.99)
	count_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	count_lbl.position = Vector3(0.0, 0.032, -0.002)
	deck_root.add_child(count_lbl)

	var title_lbl = Label3D.new()
	title_lbl.text = title_fa
	if font:
		title_lbl.font = font
	title_lbl.font_size = 34
	title_lbl.pixel_size = 0.00108
	title_lbl.modulate = Color(0.94, 0.86, 0.64)
	title_lbl.outline_size = 10
	title_lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	title_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	title_lbl.position = Vector3(0.0, 0.018, 0.066)
	deck_root.add_child(title_lbl)

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
		"glow": glow_mi,
		"count_lbl": count_lbl,
	}

# ==============================================================================
# REGION CONNECTORS — THIN, SUBTLE, BEHIND REGIONS, NEVER CROSSING LABELS
# ==============================================================================

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
			var rad_a: float = float(CONTINENT_META[c_a]["radius"])
			var rad_b: float = float(CONTINENT_META[c_b]["radius"])

			# Special Case: Asia <-> NorthAmerica wraps along the northern perimeter behind Europe
			# so the connector line NEVER crosses over Europe!
			if pair_key == "Asia_NorthAmerica":
				var wrap_node = Node3D.new()
				wrap_node.name = "Bridge_" + pair_key
				bridges_root.add_child(wrap_node)
				var z_north: float = -0.368
				var y_line: float = 0.0478

				# Left riser from NorthAmerica north rim to z_north
				var z_na_top: float = pos_a.z - rad_a - 0.012
				var len_l: float = absf(z_na_top - z_north)
				var seg_l = MeshInstance3D.new()
				var bm_l = BoxMesh.new()
				bm_l.size = Vector3(0.0075, 0.0022, maxf(0.01, len_l))
				bm_l.material = mats["bridge_idle"]
				seg_l.mesh = bm_l
				seg_l.position = Vector3(pos_a.x, y_line, (z_na_top + z_north) * 0.5)
				seg_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_l)

				# Right riser from Asia north rim to z_north
				var z_as_top: float = pos_b.z - rad_b - 0.012
				var len_r: float = absf(z_as_top - z_north)
				var seg_r = MeshInstance3D.new()
				var bm_r = BoxMesh.new()
				bm_r.size = Vector3(0.0075, 0.0022, maxf(0.01, len_r))
				bm_r.material = mats["bridge_idle"]
				seg_r.mesh = bm_r
				seg_r.position = Vector3(pos_b.x, y_line, (z_as_top + z_north) * 0.5)
				seg_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_r)

				# Northern horizontal span behind Europe
				var span_w: float = absf(pos_b.x - pos_a.x) + 0.0075
				var seg_m = MeshInstance3D.new()
				var bm_m = BoxMesh.new()
				bm_m.size = Vector3(span_w, 0.0022, 0.0075)
				bm_m.material = mats["bridge_idle"]
				seg_m.mesh = bm_m
				seg_m.position = Vector3((pos_a.x + pos_b.x) * 0.5, y_line, z_north)
				seg_m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wrap_node.add_child(seg_m)

				for sx in [pos_a.x, pos_b.x]:
					var stud = MeshInstance3D.new()
					var st_cyl = CylinderMesh.new()
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

			var diff = pos_b - pos_a
			var dist = Vector2(diff.x, diff.z).length()
			var dir = Vector2(diff.x, diff.z).normalized()
			var start_trim = rad_a + 0.018
			var end_trim = rad_b + 0.018
			var seg_len = maxf(0.02, dist - (start_trim + end_trim))
			var p_start = Vector2(pos_a.x, pos_a.z) + dir * start_trim
			var p_end = Vector2(pos_b.x, pos_b.z) - dir * end_trim
			var mid_2d = (p_start + p_end) * 0.5
			var angle_y = atan2(diff.x, diff.z)

			var bridge_node = Node3D.new()
			bridge_node.name = "Bridge_" + pair_key
			bridges_root.add_child(bridge_node)

			var bridge_mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.0075, 0.0022, seg_len)
			bm.material = mats["bridge_idle"]
			bridge_mi.mesh = bm
			bridge_mi.position = Vector3(mid_2d.x, 0.0478, mid_2d.y)
			bridge_mi.rotation.y = angle_y
			bridge_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bridge_node.add_child(bridge_mi)

			for ep in [p_start, p_end]:
				var stud = MeshInstance3D.new()
				var st_cyl = CylinderMesh.new()
				st_cyl.top_radius = 0.0062
				st_cyl.bottom_radius = 0.0072
				st_cyl.height = 0.0032
				st_cyl.radial_segments = 10
				st_cyl.material = mats["brass"]
				stud.mesh = st_cyl
				stud.position = Vector3(ep.x, 0.0484, ep.y)
				stud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bridge_node.add_child(stud)

			bridges[pair_key] = bridge_node

	return bridges

static func set_bridge_material(bridge_obj: Node, mat: Material) -> void:
	if not is_instance_valid(bridge_obj):
		return
	if bridge_obj is MeshInstance3D:
		(bridge_obj as MeshInstance3D).material_override = mat
	for ch in bridge_obj.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = mat

# ==============================================================================
# SIX CLEAN 3D REGIONS — ONE REGION = ONE CLEAR VISUAL UNIT
# Contains ONLY:
# 1. Region Name (clean front plaque at south edge)
# 2. Ownership Indicator (colored region base bezel + small top-left ownership crest)
# 3. Main Unit / Stacked Token Representation + Small Quantity Badge
# 4. Small Domination Coin Status Icon at north edge
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
	var rad: float = meta["radius"]
	var cont_mat: StandardMaterial3D = RiskMaterials.get_continent_material(c_id, false)

	var root = Node3D.new()
	root.name = "Continent_" + c_id
	root.position = pos
	parent.add_child(root)

	# 1. Subtle Contact Shadow Plinth
	var shadow_plinth = MeshInstance3D.new()
	var sp_cyl = CylinderMesh.new()
	sp_cyl.top_radius = rad + 0.012
	sp_cyl.bottom_radius = rad + 0.016
	sp_cyl.height = 0.006
	sp_cyl.radial_segments = 28
	sp_cyl.material = mats["charcoal"]
	shadow_plinth.mesh = sp_cyl
	shadow_plinth.position = Vector3(0.0, 0.003, 0.0)
	shadow_plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow_plinth)

	# 2. Ownership Indicator Border/Base (Dynamically colored by controlling player or neutral bronze)
	var ownership_bezel = MeshInstance3D.new()
	var bz_cyl = CylinderMesh.new()
	bz_cyl.top_radius = rad + 0.007
	bz_cyl.bottom_radius = rad + 0.010
	bz_cyl.height = 0.015
	bz_cyl.radial_segments = 28
	bz_cyl.material = mats["bronze"]
	ownership_bezel.mesh = bz_cyl
	ownership_bezel.position = Vector3(0.0, 0.008, 0.0)
	ownership_bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ownership_bezel)

	# 3. Colored Territory Plateau + Subtle Bronze Inner Rim + Miniature Northwest Citadel Keep
	var plateau = MeshInstance3D.new()
	var pl_cyl = CylinderMesh.new()
	pl_cyl.top_radius = rad
	pl_cyl.bottom_radius = rad + 0.002
	pl_cyl.height = 0.020
	pl_cyl.radial_segments = 28
	pl_cyl.material = cont_mat
	plateau.mesh = pl_cyl
	plateau.position = Vector3(0.0, 0.011, 0.0)
	plateau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plateau)

	var inner_rim = MeshInstance3D.new()
	var ir_tor = TorusMesh.new()
	ir_tor.inner_radius = rad - 0.006
	ir_tor.outer_radius = rad - 0.002
	ir_tor.rings = 28
	ir_tor.ring_segments = 8
	ir_tor.material = mats["bronze"]
	inner_rim.mesh = ir_tor
	inner_rim.position = Vector3(0.0, 0.0212, 0.0)
	inner_rim.scale = Vector3(1.0, 0.35, 1.0)
	inner_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner_rim)

	var citadel_mi = MeshInstance3D.new()
	if _rook_mesh:
		citadel_mi.mesh = _rook_mesh
		citadel_mi.scale = Vector3(0.24, 0.24, 0.24)
		citadel_mi.material_override = mats["parchment"]
		citadel_mi.position = Vector3(-rad * 0.56, 0.021, -rad * 0.42)
		citadel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(citadel_mi)

	# 4. Tasteful Selection / Valid Target Outline Ring (Hidden unless selected or targeted)
	var aura_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = rad + 0.008
	torus.outer_radius = rad + 0.017
	torus.rings = 28
	torus.ring_segments = 10
	torus.material = mats["glow_gold"]
	aura_ring.mesh = torus
	aura_ring.position = Vector3(0.0, 0.012, 0.0)
	aura_ring.visible = false
	root.add_child(aura_ring)

	# 5. Domination Token Coin + Miniature Golden 3D Crown at North Edge
	var token_node = build_domination_token_3d(c_id, mats, _king_mesh, 0.85)
	token_node.position = Vector3(0.0, 0.023, -rad * 0.66)
	root.add_child(token_node)

	# 6. Single Clean Region Name Plaque at South Edge (ONLY the region name, never obscured!)
	var plaque_base = MeshInstance3D.new()
	var pb_box = BoxMesh.new()
	pb_box.size = Vector3(rad * 1.18, 0.007, 0.032)
	pb_box.material = mats["charcoal"]
	plaque_base.mesh = pb_box
	plaque_base.position = Vector3(0.0, 0.021, rad * 0.82)
	plaque_base.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_base)

	var plaque_trim = MeshInstance3D.new()
	var pt_box = BoxMesh.new()
	pt_box.size = Vector3(rad * 1.22, 0.005, 0.035)
	pt_box.material = mats["bronze"]
	plaque_trim.mesh = pt_box
	plaque_trim.position = Vector3(0.0, 0.0195, rad * 0.82)
	plaque_trim.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	root.add_child(plaque_trim)

	var name_lbl = Label3D.new()
	name_lbl.text = str(meta["fa"])
	if font:
		name_lbl.font = font
	name_lbl.font_size = 40
	name_lbl.pixel_size = 0.00104
	name_lbl.modulate = Color(0.98, 0.95, 0.88)
	name_lbl.outline_size = 10
	name_lbl.outline_modulate = Color(0.03, 0.02, 0.01, 0.98)
	name_lbl.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	name_lbl.position = Vector3(0.0, 0.026, rad * 0.83)
	root.add_child(name_lbl)

	# 7. Clean Stacked Player Unit Tokens + Small Readable Quantity Badge (Centered on Plateau)
	var default_slots = {
		1: Vector3(-0.044, 0.021, -0.006),
		2: Vector3(0.044, 0.021, -0.006),
		3: Vector3(-0.044, 0.021, -0.042),
		4: Vector3(0.044, 0.021, -0.042),
	}
	var garrisons: Dictionary = {}
	for p_idx in [1, 2, 3, 4]:
		var g_node = Node3D.new()
		g_node.name = "Garrison_P%d" % p_idx
		g_node.position = default_slots[p_idx]
		g_node.visible = false
		root.add_child(g_node)

		var f_mat = RiskMaterials.get_faction_material(p_idx, false)

		# Clean Stacked Ownership Discs (1 to 3 stacked discs representing unit volume cleanly)
		var stack_discs: Array[MeshInstance3D] = []
		for s_i in range(3):
			var disc_mi = MeshInstance3D.new()
			var disc_cyl = CylinderMesh.new()
			disc_cyl.top_radius = 0.018
			disc_cyl.bottom_radius = 0.019
			disc_cyl.height = 0.0045
			disc_cyl.radial_segments = 18
			disc_cyl.material = f_mat
			disc_mi.mesh = disc_cyl
			disc_mi.position = Vector3(0.0, 0.0025 + float(s_i) * 0.005, -0.008)
			g_node.add_child(disc_mi)
			stack_discs.append(disc_mi)

		# Consistent Miniature Unit Silhouette on Top of Stack
		var piece_mi = MeshInstance3D.new()
		if knight_mesh:
			piece_mi.mesh = knight_mesh
			piece_mi.scale = Vector3(0.24, 0.24, 0.24)
			piece_mi.position = Vector3(0.0, 0.012, -0.008)
		else:
			var sc = SphereMesh.new()
			sc.radius = 0.012
			sc.height = 0.024
			piece_mi.mesh = sc
			piece_mi.position = Vector3(0.0, 0.018, -0.008)
		piece_mi.material_override = f_mat
		g_node.add_child(piece_mi)

		# Small, High-Contrast Quantity Badge Pill Mounted cleanly in front of the unit stack
		var badge_bg = MeshInstance3D.new()
		var bb_box = BoxMesh.new()
		bb_box.size = Vector3(0.048, 0.005, 0.028)
		bb_box.material = mats["charcoal"]
		badge_bg.mesh = bb_box
		badge_bg.position = Vector3(0.0, 0.010, 0.024)
		badge_bg.rotation_degrees = Vector3(20.0, 0.0, 0.0)
		g_node.add_child(badge_bg)

		var cnt_lbl = Label3D.new()
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
	var area = Area3D.new()
	area.name = "ContinentHitArea"
	area.set_meta("interact_type", "continent")
	area.set_meta("continent", c_id)
	var col = CollisionShape3D.new()
	var cyl_shape = CylinderShape3D.new()
	cyl_shape.radius = rad + 0.020
	cyl_shape.height = 0.090
	col.shape = cyl_shape
	col.position = Vector3(0.0, 0.030, 0.0)
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

# Intelligently positions occupied garrisons inside the upper/center plateau so units NEVER touch the south name plaque
static func layout_continent_garrisons(c_ref: Dictionary, present_players: Array[int]) -> void:
	var garrisons: Dictionary = c_ref["garrisons"]
	var count = present_players.size()
	var positions: Array[Vector3] = []
	if count == 1:
		positions = [Vector3(0.0, 0.021, -0.004)]
	elif count == 2:
		positions = [
			Vector3(-0.044, 0.021, -0.004),
			Vector3(0.044, 0.021, -0.004),
		]
	elif count == 3:
		positions = [
			Vector3(-0.050, 0.021, 0.004),
			Vector3(0.0, 0.021, -0.032),
			Vector3(0.050, 0.021, 0.004),
		]
	else:
		positions = [
			Vector3(-0.048, 0.021, 0.008),
			Vector3(0.048, 0.021, 0.008),
			Vector3(-0.048, 0.021, -0.034),
			Vector3(0.048, 0.021, -0.034),
		]

	for i in range(present_players.size()):
		var p_idx: int = present_players[i]
		if garrisons.has(p_idx):
			var g_node: Node3D = garrisons[p_idx]["node"]
			g_node.position = positions[min(i, positions.size() - 1)]

# Golden Medallion + Crown Trophy for Domination Token Status
static func build_domination_token_3d(
	c_id: String,
	mats: Dictionary,
	crown_mesh: Mesh,
	scale_mult: float = 1.0
) -> Node3D:
	var token = Node3D.new()
	token.name = "DominationToken_" + c_id
	token.scale = Vector3.ONE * scale_mult

	var coin_mi = MeshInstance3D.new()
	var coin_cyl = CylinderMesh.new()
	coin_cyl.top_radius = 0.019
	coin_cyl.bottom_radius = 0.021
	coin_cyl.height = 0.005
	coin_cyl.radial_segments = 18
	coin_cyl.material = mats["gold"]
	coin_mi.mesh = coin_cyl
	token.add_child(coin_mi)

	var jewel_mi = MeshInstance3D.new()
	var jewel_cyl = CylinderMesh.new()
	jewel_cyl.top_radius = 0.013
	jewel_cyl.bottom_radius = 0.013
	jewel_cyl.height = 0.006
	jewel_cyl.radial_segments = 16
	jewel_cyl.material = RiskMaterials.get_continent_material(c_id, false)
	jewel_mi.mesh = jewel_cyl
	jewel_mi.position = Vector3(0.0, 0.001, 0.0)
	token.add_child(jewel_mi)

	if crown_mesh:
		var cr_mi = MeshInstance3D.new()
		cr_mi.mesh = crown_mesh
		cr_mi.scale = Vector3(0.55, 0.65, 0.55)
		cr_mi.position = Vector3(0.0, 0.004, 0.0)
		cr_mi.material_override = mats["gold"]
		token.add_child(cr_mi)

	return token

# 3D Commander Bastion Stations Along Outer Walnut Shelves (Interactive + Crown Trophies + Card Stacks)
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

	var f_mat_idle = RiskMaterials.get_faction_material(p_idx, false)
	var f_mat_active = RiskMaterials.get_faction_material(p_idx, true)

	# Stepped Walnut / Charcoal Pedestal + Brass Rim
	var plinth = MeshInstance3D.new()
	var p_bm = BoxMesh.new()
	p_bm.size = Vector3(0.25, 0.014, 0.115)
	p_bm.material = mats["charcoal"]
	plinth.mesh = p_bm
	plinth.position = Vector3(0.0, 0.007, 0.0)
	station.add_child(plinth)

	var rim = MeshInstance3D.new()
	var r_bm = BoxMesh.new()
	r_bm.size = Vector3(0.258, 0.006, 0.123)
	r_bm.material = f_mat_idle
	rim.mesh = r_bm
	rim.position = Vector3(0.0, 0.003, 0.0)
	station.add_child(rim)

	# Active Turn Glow Halo & Target Selection Glow Halo
	var active_glow = MeshInstance3D.new()
	var ag_bm = BoxMesh.new()
	ag_bm.size = Vector3(0.272, 0.003, 0.138)
	ag_bm.material = mats["glow_gold"]
	active_glow.mesh = ag_bm
	active_glow.position = Vector3(0.0, 0.0015, 0.0)
	active_glow.visible = false
	station.add_child(active_glow)

	var target_glow = MeshInstance3D.new()
	var tg_bm = BoxMesh.new()
	tg_bm.size = Vector3(0.280, 0.004, 0.144)
	tg_bm.material = mats["glow_crimson"]
	target_glow.mesh = tg_bm
	target_glow.position = Vector3(0.0, 0.002, 0.0)
	target_glow.visible = false
	station.add_child(target_glow)

	# Miniature Commander King Figure on Left Pedestal
	var cmd_pad = MeshInstance3D.new()
	var cp_cyl = CylinderMesh.new()
	cp_cyl.top_radius = 0.024
	cp_cyl.bottom_radius = 0.028
	cp_cyl.height = 0.006
	cp_cyl.radial_segments = 16
	cp_cyl.material = mats["brass"]
	cmd_pad.mesh = cp_cyl
	cmd_pad.position = Vector3(-0.084, 0.017, -0.004)
	station.add_child(cmd_pad)

	var commander_mi = MeshInstance3D.new()
	if king_mesh:
		commander_mi.mesh = king_mesh
		commander_mi.scale = Vector3(0.42, 0.42, 0.42)
		commander_mi.position = Vector3(-0.084, 0.020, -0.004)
	else:
		var s_m = SphereMesh.new()
		s_m.radius = 0.018
		s_m.height = 0.036
		commander_mi.mesh = s_m
		commander_mi.position = Vector3(-0.084, 0.034, -0.004)
	commander_mi.material_override = f_mat_idle
	station.add_child(commander_mi)

	# Two Crown Socket Pads (Center-Right)
	for sx in [0.056, 0.098]:
		var sock = MeshInstance3D.new()
		var sk_cyl = CylinderMesh.new()
		sk_cyl.top_radius = 0.016
		sk_cyl.bottom_radius = 0.018
		sk_cyl.height = 0.004
		sk_cyl.radial_segments = 14
		sk_cyl.material = mats["bronze"]
		sock.mesh = sk_cyl
		sock.position = Vector3(sx, 0.016, -0.014)
		station.add_child(sock)

	var assets_container = Node3D.new()
	assets_container.name = "StationAssets"
	station.add_child(assets_container)

	# Compact Front Stats Readout (No long player names so it never clips!)
	var stats_lbl = Label3D.new()
	stats_lbl.text = "👑۰  🃏۰"
	if font:
		stats_lbl.font = font
	stats_lbl.font_size = 34
	stats_lbl.pixel_size = 0.00095
	stats_lbl.modulate = RiskMaterials.FACTION_COLORS.get(p_idx, Color.WHITE).lightened(0.45)
	stats_lbl.outline_size = 10
	stats_lbl.outline_modulate = Color(0.02, 0.01, 0.01, 0.98)
	stats_lbl.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	stats_lbl.position = Vector3(0.015, 0.020, 0.036)
	station.add_child(stats_lbl)

	var name_lbl = Label3D.new()
	name_lbl.visible = false
	station.add_child(name_lbl)

	# Click Hitbox to Target or Inspect Player
	var area = Area3D.new()
	area.name = "StationHitArea"
	area.set_meta("interact_type", "station")
	area.set_meta("player_index", p_idx)
	var col = CollisionShape3D.new()
	var b_sh = BoxShape3D.new()
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
		"base_w": 0.25,
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
	for ch in container.get_children():
		ch.queue_free()

	var tokens: Array = p_data.get("tokens", [])
	var conts: Dictionary = p_data.get("continents", {})
	var c_total: int = 0
	for k in conts.keys():
		c_total += int(conts[k])
	var s_total: int = int(p_data.get("strategies_count", 0))

	var stats_lbl: Label3D = station_ref.get("stats_lbl", null)
	if is_instance_valid(stats_lbl):
		stats_lbl.text = "👑%s  🗺️%s  ⚡%s" % [
			fa_digits(tokens.size()),
			fa_digits(c_total),
			fa_digits(s_total),
		]

	# Populate captured golden 3D Crowns in sockets
	var crown_xs: Array = [0.056, 0.098]
	for i in range(min(2, tokens.size())):
		var cr_mi = MeshInstance3D.new()
		if crown_mesh:
			cr_mi.mesh = crown_mesh
			cr_mi.scale = Vector3(0.66, 0.72, 0.66)
		else:
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.012
			cyl.bottom_radius = 0.014
			cyl.height = 0.012
			cr_mi.mesh = cyl
		cr_mi.material_override = mats["gold"]
		cr_mi.position = Vector3(crown_xs[i], 0.018, -0.014)
		container.add_child(cr_mi)

	# Visual mini-stack of Continent & Strategy cards beside Commander Statue
	var c_layers = clampi(int(ceil(float(c_total) / 2.0)), 0, 5)
	for i in range(c_layers):
		var c_mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.036, 0.0025, 0.048)
		bm.material = mats.get("continent_card_back", mats["emerald_velvet"])
		c_mi.mesh = bm
		c_mi.position = Vector3(-0.028, 0.0155 + float(i) * 0.0027, -0.012)
		container.add_child(c_mi)

	var s_layers = clampi(int(ceil(float(s_total) / 2.0)), 0, 5)
	for i in range(s_layers):
		var s_mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.036, 0.0025, 0.048)
		bm.material = mats.get("die_attacker", mats["crimson_wax"])
		s_mi.mesh = bm
		s_mi.position = Vector3(0.014, 0.0155 + float(i) * 0.0027, -0.012)
		container.add_child(s_mi)

static func build_3d_die(is_attacker: bool, mats: Dictionary, font: Font = null, final_val: int = 1) -> Node3D:
	var die_root = Node3D.new()
	die_root.name = "BattleDie3D"
	var s: float = 0.068
	var half: float = s * 0.5

	var cube_pivot = Node3D.new()
	cube_pivot.name = "CubePivot"
	die_root.add_child(cube_pivot)

	var body_mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(s, s, s)
	bm.material = mats["die_attacker"] if is_attacker else mats["die_defender"]
	body_mi.mesh = bm
	cube_pivot.add_child(body_mi)

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

	var badge_lbl = make_label_3d(
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
	var lbl = Label3D.new()
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
