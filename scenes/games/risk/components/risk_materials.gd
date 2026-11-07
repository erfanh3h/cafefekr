class_name RiskMaterials
extends RefCounted

# ==============================================================================
# RISK STRIKE — REFINED TABLETOP PBR PALETTE
# Deep Walnut, Dark Emerald Baize, Muted Antique Gold, Warm Bronze & Charcoal
# ==============================================================================

const CONTINENT_COLORS: Dictionary = {
	"Asia": Color(0.14, 0.50, 0.34),         # Deep Imperial Jade
	"NorthAmerica": Color(0.76, 0.54, 0.18), # Antique Amber Ochre
	"Europe": Color(0.18, 0.40, 0.68),       # Royal Prussian Blue
	"Africa": Color(0.70, 0.32, 0.18),       # Burnished Terracotta
	"Australia": Color(0.50, 0.26, 0.62),    # Regal Amethyst
	"SouthAmerica": Color(0.36, 0.56, 0.22)  # Olive Emerald
}

const FACTION_COLORS: Dictionary = {
	1: Color(0.84, 0.20, 0.22), # Player 1: Imperial Crimson
	2: Color(0.20, 0.54, 0.88), # Player 2: Royal Sapphire
	3: Color(0.18, 0.72, 0.42), # Player 3: Sovereign Emerald
	4: Color(0.88, 0.68, 0.20)  # Player 4: Antique Gold
}

static var _continent_mat_cache: Dictionary = {}
static var _faction_mat_cache: Dictionary = {}

static func create_palette() -> Dictionary:
	var mats: Dictionary = {}

	# Deep Dark Walnut Wood
	var walnut = StandardMaterial3D.new()
	walnut.albedo_color = Color(0.15, 0.085, 0.05)
	walnut.roughness = 0.34
	walnut.metallic = 0.06
	mats["walnut"] = walnut

	# Carved Dark Mahogany Trim
	var dark_wood = StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.10, 0.055, 0.032)
	dark_wood.roughness = 0.38
	dark_wood.metallic = 0.05
	mats["dark_wood"] = dark_wood
	mats["mahogany"] = dark_wood

	# Dark Charcoal Slate (Shadow Plinths & Name Plaques)
	var charcoal = StandardMaterial3D.new()
	charcoal.albedo_color = Color(0.08, 0.085, 0.095)
	charcoal.roughness = 0.52
	charcoal.metallic = 0.14
	mats["charcoal"] = charcoal

	# Dark Emerald Green Baize Velvet (Central Board Playing Bed)
	var emerald_velvet = StandardMaterial3D.new()
	emerald_velvet.albedo_color = Color(0.045, 0.175, 0.115)
	emerald_velvet.roughness = 0.84
	emerald_velvet.metallic = 0.02
	mats["emerald_velvet"] = emerald_velvet

	# Deep Espresso Leather Inlay (Dice Arena & Card Shoes)
	var leather = StandardMaterial3D.new()
	leather.albedo_color = Color(0.12, 0.07, 0.045)
	leather.roughness = 0.60
	leather.metallic = 0.06
	mats["leather"] = leather

	# Muted Antique Gold / Brushed Brass
	var brass = StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.64, 0.28)
	brass.metallic = 0.84
	brass.roughness = 0.24
	mats["brass"] = brass

	# Warm Antique Bronze (Continent Bezels & Plaques)
	var bronze = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.58, 0.41, 0.20)
	bronze.metallic = 0.80
	bronze.roughness = 0.30
	mats["bronze"] = bronze

	# Sovereign Gold (Domination Coins & Crowns — Subtle Warm Lustre)
	var gold = StandardMaterial3D.new()
	gold.albedo_color = Color(0.94, 0.78, 0.26)
	gold.metallic = 0.90
	gold.roughness = 0.18
	gold.emission_enabled = true
	gold.emission = Color(0.85, 0.64, 0.14)
	gold.emission_energy_multiplier = 0.22
	mats["gold"] = gold

	# Restrained Golden Selection Ring
	var glow_gold = StandardMaterial3D.new()
	glow_gold.albedo_color = Color(0.96, 0.80, 0.28, 0.92)
	glow_gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_gold.emission_enabled = true
	glow_gold.emission = Color(0.92, 0.74, 0.20)
	glow_gold.emission_energy_multiplier = 1.25
	mats["glow_gold"] = glow_gold

	# Restrained Emerald Valid Target Ring
	var glow_emerald = StandardMaterial3D.new()
	glow_emerald.albedo_color = Color(0.24, 0.86, 0.50, 0.90)
	glow_emerald.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_emerald.emission_enabled = true
	glow_emerald.emission = Color(0.18, 0.78, 0.42)
	glow_emerald.emission_energy_multiplier = 1.20
	mats["glow_emerald"] = glow_emerald

	# Restrained Crimson Attack Target Ring
	var glow_crimson = StandardMaterial3D.new()
	glow_crimson.albedo_color = Color(0.92, 0.26, 0.24, 0.92)
	glow_crimson.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_crimson.emission_enabled = true
	glow_crimson.emission = Color(0.88, 0.20, 0.18)
	glow_crimson.emission_energy_multiplier = 1.35
	mats["glow_crimson"] = glow_crimson

	# Soft Cream Parchment (Citadel Keeps & Card Cores)
	var parchment = StandardMaterial3D.new()
	parchment.albedo_color = Color(0.93, 0.88, 0.78)
	parchment.roughness = 0.56
	mats["parchment"] = parchment

	# Sea-Lane Bridges (Idle & Active)
	var bridge_idle = StandardMaterial3D.new()
	bridge_idle.albedo_color = Color(0.74, 0.58, 0.28, 0.62)
	bridge_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_idle.metallic = 0.65
	bridge_idle.roughness = 0.32
	mats["bridge_idle"] = bridge_idle

	var bridge_active = StandardMaterial3D.new()
	bridge_active.albedo_color = Color(0.96, 0.46, 0.20, 0.95)
	bridge_active.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_active.emission_enabled = true
	bridge_active.emission = Color(0.94, 0.38, 0.14)
	bridge_active.emission_energy_multiplier = 1.40
	mats["bridge_active"] = bridge_active

	# 3D Battle Dice Materials (High-Contrast Attacker Ruby-Crimson & Defender Royal Cobalt-Obsidian)
	var die_attacker = StandardMaterial3D.new()
	die_attacker.albedo_color = Color(0.88, 0.14, 0.16)
	die_attacker.roughness = 0.18
	die_attacker.metallic = 0.18
	die_attacker.emission_enabled = true
	die_attacker.emission = Color(0.75, 0.10, 0.12)
	die_attacker.emission_energy_multiplier = 0.28
	mats["die_attacker"] = die_attacker

	var die_defender = StandardMaterial3D.new()
	die_defender.albedo_color = Color(0.14, 0.34, 0.68)
	die_defender.roughness = 0.20
	die_defender.metallic = 0.26
	die_defender.emission_enabled = true
	die_defender.emission = Color(0.10, 0.28, 0.58)
	die_defender.emission_energy_multiplier = 0.26
	mats["die_defender"] = die_defender

	var pip_ivory = StandardMaterial3D.new()
	pip_ivory.albedo_color = Color(1.0, 0.98, 0.92)
	pip_ivory.roughness = 0.12
	pip_ivory.emission_enabled = true
	pip_ivory.emission = Color(1.0, 0.96, 0.84)
	pip_ivory.emission_energy_multiplier = 0.65
	mats["pip_ivory"] = pip_ivory

	return mats

static func get_continent_material(c_id: String, is_highlighted: bool = false) -> StandardMaterial3D:
	var key = "%s_%s" % [c_id, "hi" if is_highlighted else "lo"]
	if _continent_mat_cache.has(key) and is_instance_valid(_continent_mat_cache[key]):
		return _continent_mat_cache[key]
	var base_col: Color = CONTINENT_COLORS.get(c_id, Color(0.26, 0.48, 0.36))
	var col: Color = base_col.lightened(0.14) if is_highlighted else base_col
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.38 if is_highlighted else 0.46
	mat.metallic = 0.14
	if is_highlighted:
		mat.emission_enabled = true
		mat.emission = base_col
		mat.emission_energy_multiplier = 0.28
	_continent_mat_cache[key] = mat
	return mat

static func get_faction_material(p_idx: int, is_active: bool = false) -> StandardMaterial3D:
	var cache_key = "%d_%s" % [p_idx, "act" if is_active else "idl"]
	if _faction_mat_cache.has(cache_key) and is_instance_valid(_faction_mat_cache[cache_key]):
		return _faction_mat_cache[cache_key]
	var col: Color = FACTION_COLORS.get(p_idx, Color(0.82, 0.82, 0.82))
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col.lightened(0.10) if is_active else col
	mat.metallic = 0.62
	mat.roughness = 0.24 if is_active else 0.30
	if is_active:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.30
	_faction_mat_cache[cache_key] = mat
	return mat
