class_name RiskMaterials
extends RefCounted

# ==============================================================================
# RISK STRIKE — PBR MATERIAL PALETTE (ANTIQUE WALNUT, EMERALD BAIZE & BRASS)
# ==============================================================================

const CONTINENT_COLORS: Dictionary = {
	"Asia": Color(0.14, 0.64, 0.38),         # Deep Imperial Jade
	"NorthAmerica": Color(0.86, 0.62, 0.18), # Antique Amber Gold
	"Europe": Color(0.20, 0.48, 0.84),       # Royal Prussian Blue
	"Africa": Color(0.82, 0.38, 0.18),       # Burnished Terracotta
	"Australia": Color(0.62, 0.28, 0.76),    # Royal Amethyst
	"SouthAmerica": Color(0.44, 0.72, 0.22)  # Amazon Emerald-Olive
}

const FACTION_COLORS: Dictionary = {
	1: Color(0.90, 0.20, 0.24), # Player 1: Imperial Crimson
	2: Color(0.20, 0.58, 0.96), # Player 2: Royal Sapphire
	3: Color(0.18, 0.80, 0.40), # Player 3: EmeraldJade
	4: Color(0.96, 0.76, 0.18)  # Player 4: Sovereign Gold
}

static func create_palette() -> Dictionary:
	var mats: Dictionary = {}

	# Rich Dark Walnut Wood
	var walnut = StandardMaterial3D.new()
	walnut.albedo_color = Color(0.16, 0.09, 0.05)
	walnut.roughness = 0.34
	walnut.metallic = 0.06
	mats["walnut"] = walnut

	# Carved Mahogany / Dark Wood Trim
	var dark_wood = StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.10, 0.055, 0.03)
	dark_wood.roughness = 0.42
	dark_wood.metallic = 0.05
	mats["dark_wood"] = dark_wood

	# Dark Emerald Green Baize Velvet (Central Board Bed)
	var emerald_velvet = StandardMaterial3D.new()
	emerald_velvet.albedo_color = Color(0.05, 0.20, 0.13)
	emerald_velvet.roughness = 0.82
	emerald_velvet.metallic = 0.04
	mats["emerald_velvet"] = emerald_velvet

	# Deep Leather Inlay (Card Rack & Dice Arena Bed)
	var leather = StandardMaterial3D.new()
	leather.albedo_color = Color(0.13, 0.075, 0.05)
	leather.roughness = 0.62
	leather.metallic = 0.08
	mats["leather"] = leather

	# Brushed Antique Brass / Bronze
	var brass = StandardMaterial3D.new()
	brass.albedo_color = Color(0.86, 0.70, 0.28)
	brass.metallic = 0.88
	brass.roughness = 0.22
	mats["brass"] = brass

	# Antique Bronze (Darker Metallic for Nameplates & Borders)
	var bronze = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.64, 0.46, 0.22)
	bronze.metallic = 0.82
	bronze.roughness = 0.28
	mats["bronze"] = bronze

	# Sovereign Gold (Domination Tokens & Crowns)
	var gold = StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.85, 0.24)
	gold.metallic = 0.94
	gold.roughness = 0.15
	gold.emission_enabled = true
	gold.emission = Color(0.95, 0.72, 0.14)
	gold.emission_energy_multiplier = 0.40
	mats["gold"] = gold

	# Illuminated Golden Selection Aura
	var glow_gold = StandardMaterial3D.new()
	glow_gold.albedo_color = Color(1.0, 0.88, 0.32, 0.94)
	glow_gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_gold.emission_enabled = true
	glow_gold.emission = Color(1.0, 0.82, 0.22)
	glow_gold.emission_energy_multiplier = 2.1
	mats["glow_gold"] = glow_gold

	# Illuminated Emerald Ready / Valid Target Aura
	var glow_emerald = StandardMaterial3D.new()
	glow_emerald.albedo_color = Color(0.28, 0.98, 0.54, 0.92)
	glow_emerald.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_emerald.emission_enabled = true
	glow_emerald.emission = Color(0.20, 0.90, 0.45)
	glow_emerald.emission_energy_multiplier = 1.9
	mats["glow_emerald"] = glow_emerald

	# Illuminated Crimson Target Attack Aura
	var glow_crimson = StandardMaterial3D.new()
	glow_crimson.albedo_color = Color(1.0, 0.26, 0.24, 0.94)
	glow_crimson.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_crimson.emission_enabled = true
	glow_crimson.emission = Color(1.0, 0.20, 0.18)
	glow_crimson.emission_energy_multiplier = 2.2
	mats["glow_crimson"] = glow_crimson

	# Cream Antique Parchment (Card Core & Castle Keeps)
	var parchment = StandardMaterial3D.new()
	parchment.albedo_color = Color(0.95, 0.90, 0.79)
	parchment.roughness = 0.58
	mats["parchment"] = parchment

	# Sea-Lane Bridges (Idle & Highlighted)
	var bridge_idle = StandardMaterial3D.new()
	bridge_idle.albedo_color = Color(0.84, 0.70, 0.36, 0.48)
	bridge_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_idle.emission_enabled = true
	bridge_idle.emission = Color(0.76, 0.60, 0.24)
	bridge_idle.emission_energy_multiplier = 0.35
	mats["bridge_idle"] = bridge_idle

	var bridge_active = StandardMaterial3D.new()
	bridge_active.albedo_color = Color(1.0, 0.42, 0.20, 0.96)
	bridge_active.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_active.emission_enabled = true
	bridge_active.emission = Color(1.0, 0.38, 0.14)
	bridge_active.emission_energy_multiplier = 2.4
	mats["bridge_active"] = bridge_active

	# 3D Battle Dice Materials (Attacker Crimson & Defender Obsidian)
	var die_attacker = StandardMaterial3D.new()
	die_attacker.albedo_color = Color(0.84, 0.12, 0.16)
	die_attacker.roughness = 0.18
	die_attacker.metallic = 0.16
	mats["die_attacker"] = die_attacker

	var die_defender = StandardMaterial3D.new()
	die_defender.albedo_color = Color(0.14, 0.16, 0.22)
	die_defender.roughness = 0.20
	die_defender.metallic = 0.28
	mats["die_defender"] = die_defender

	var pip_ivory = StandardMaterial3D.new()
	pip_ivory.albedo_color = Color(0.98, 0.96, 0.90)
	pip_ivory.emission_enabled = true
	pip_ivory.emission = Color(0.96, 0.92, 0.82)
	pip_ivory.emission_energy_multiplier = 0.35
	mats["pip_ivory"] = pip_ivory

	return mats
