class_name CoupTable3D
extends Node3D

# CoupTable3D - Royal Coup Tabletop Scene on the Cafe Fekr Green Felt Table
# - Sits harmoniously on the Cafe Fekr tabletop (y_base = 0.059)
# - Walnut & Brass Royal Court Arena Ring with Crimson/Gold inlays
# - 3D Court Deck Shoe ("دیوان دربار") + 3D Treasury Coin Vault ("خزانه سکه")
# - 3D Phase Beacon Crystal Pedestal indicating action / challenge / block / choice phase
# - 3D Opponent Influence Stations around the table (strictly 1, 2, or 3 seats matching total players)
#   with upright hidden cards, face-up revealed/lost role cards, gold coin stacks, and clickable target rings

signal seat_clicked(seat_slot: int)

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")
const CoupCardWidgetScript = preload("res://scenes/games/coup/components/coup_card_widget.gd")

const FACTION_COLORS: Dictionary = {
	1: Color(0.95, 0.28, 0.34),
	2: Color(0.28, 0.68, 1.00),
	3: Color(0.24, 0.88, 0.48),
	4: Color(1.00, 0.80, 0.22),
}

var _deck_root: Node3D
var _deck_stack_body: MeshInstance3D
var _deck_top_card: Node3D
var _deck_count_lbl: Label3D

var _treasury_root: Node3D
var _treasury_coins: Array[MeshInstance3D] = []

var _phase_crystal: MeshInstance3D
var _phase_halo_ring: MeshInstance3D
var _phase_gem_mat: StandardMaterial3D
var _phase_name_3d: Label3D

var _opponent_stations: Dictionary = {} # seat_slot (1=Top, 2=Left, 3=Right) -> Node3D
var _target_rings: Dictionary = {} # seat_slot -> MeshInstance3D
var _targetable_slots: Dictionary = {} # seat_slot -> bool
var _anim_time: float = 0.0

func _ready() -> void:
	_build_tabletop()

func _process(delta: float) -> void:
	_anim_time += delta

	if is_instance_valid(_phase_crystal):
		_phase_crystal.rotate_y(delta * 1.35)
		_phase_crystal.position.y = 0.044 + sin(_anim_time * 2.8) * 0.004

	if is_instance_valid(_phase_halo_ring):
		var sc: float = 1.0 + sin(_anim_time * 3.2) * 0.06
		_phase_halo_ring.scale = Vector3(sc, 1.0, sc)

	for s_slot: int in _target_rings.keys():
		var ring: MeshInstance3D = _target_rings[s_slot]
		if is_instance_valid(ring) and ring.visible:
			var pulse: float = 1.0 + sin(_anim_time * 6.0) * 0.08
			ring.scale = Vector3(pulse, 1.0, pulse)

func _create_label_3d(txt: String, f_size: int = 34, col: Color = Color.WHITE, p_size: float = 0.0011) -> Label3D:
	var lbl: Label3D = Label3D.new()
	lbl.font = FontHekayat
	lbl.text = txt
	lbl.font_size = f_size
	lbl.pixel_size = p_size
	lbl.modulate = col
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.03, 0.03, 0.05, 0.96)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 20) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_torus(parent: Node3D, inner_r: float, outer_r: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	tm.rings = 28
	tm.ring_segments = 10
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_tabletop() -> void:
	var y_base: float = 0.059

	var mat_walnut: StandardMaterial3D = StandardMaterial3D.new()
	mat_walnut.albedo_color = Color(0.15, 0.08, 0.045)
	mat_walnut.roughness = 0.30
	mat_walnut.metallic = 0.06

	var mat_mahogany: StandardMaterial3D = StandardMaterial3D.new()
	mat_mahogany.albedo_color = Color(0.24, 0.10, 0.06)
	mat_mahogany.roughness = 0.28
	mat_mahogany.metallic = 0.08

	var mat_crimson_velvet: StandardMaterial3D = StandardMaterial3D.new()
	mat_crimson_velvet.albedo_color = Color(0.24, 0.05, 0.07)
	mat_crimson_velvet.roughness = 0.85

	var mat_gold: StandardMaterial3D = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.92, 0.74, 0.24)
	mat_gold.metallic = 0.86
	mat_gold.roughness = 0.20

	var mat_aged_brass: StandardMaterial3D = StandardMaterial3D.new()
	mat_aged_brass.albedo_color = Color(0.62, 0.46, 0.18)
	mat_aged_brass.metallic = 0.78
	mat_aged_brass.roughness = 0.32

	var mat_paper: StandardMaterial3D = StandardMaterial3D.new()
	mat_paper.albedo_color = Color(0.94, 0.90, 0.82)
	mat_paper.roughness = 0.44

	var mat_card_back: StandardMaterial3D = StandardMaterial3D.new()
	mat_card_back.albedo_color = Color(0.09, 0.08, 0.12)
	mat_card_back.roughness = 0.26

	var mat_shadow: StandardMaterial3D = StandardMaterial3D.new()
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	mat_shadow.roughness = 1.0

	# 1. Royal Court Center Arena Ring
	var ring_center: Vector3 = Vector3(0.0, y_base + 0.002, -0.02)
	_add_cyl(self, 0.345, 0.355, 0.003, ring_center, mat_crimson_velvet, Vector3.ZERO, 36)
	_add_torus(self, 0.342, 0.356, ring_center + Vector3(0.0, 0.002, 0.0), mat_mahogany)
	_add_torus(self, 0.332, 0.340, ring_center + Vector3(0.0, 0.003, 0.0), mat_aged_brass)
	_add_torus(self, 0.240, 0.246, ring_center + Vector3(0.0, 0.003, 0.0), mat_aged_brass)

	var crest_lbl: Label3D = _create_label_3d("👑 دیوان کودتا", 30, Color(0.98, 0.86, 0.46, 0.90), 0.00105)
	crest_lbl.position = Vector3(0.0, y_base + 0.006, -0.20)
	crest_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(crest_lbl)

	# 2. Court Deck (Center-Left)
	_deck_root = Node3D.new()
	_deck_root.position = Vector3(-0.145, y_base + 0.003, -0.02)
	_deck_root.rotation_degrees = Vector3(0.0, 5.0, 0.0)
	add_child(_deck_root)

	_add_box(_deck_root, Vector3(0.186, 0.006, 0.258), Vector3(0.0, 0.002, 0.0), mat_walnut)
	_add_box(_deck_root, Vector3(0.174, 0.003, 0.246), Vector3(0.0, 0.005, 0.0), mat_crimson_velvet)
	_add_box(_deck_root, Vector3(0.170, 0.001, 0.240), Vector3(0.005, 0.0045, 0.005), mat_shadow)
	for cx: float in [-0.086, 0.086]:
		for cz: float in [-0.122, 0.122]:
			_add_box(_deck_root, Vector3(0.020, 0.008, 0.020), Vector3(cx, 0.005, cz), mat_gold)

	_deck_stack_body = _add_box(_deck_root, Vector3(0.152, 0.030, 0.222), Vector3(0.0, 0.020, 0.0), mat_paper)
	_deck_top_card = Node3D.new()
	_deck_top_card.position = Vector3(0.0, 0.037, 0.0)
	_deck_root.add_child(_deck_top_card)

	_add_box(_deck_top_card, Vector3(0.154, 0.003, 0.224), Vector3.ZERO, mat_gold)
	_add_box(_deck_top_card, Vector3(0.142, 0.0035, 0.212), Vector3(0.0, 0.0005, 0.0), mat_card_back)
	_add_torus(_deck_top_card, 0.036, 0.042, Vector3(0.0, 0.0025, 0.0), mat_gold)

	var coup_logo: Label3D = _create_label_3d("COUP", 36, Color(1.0, 0.86, 0.32), 0.0011)
	coup_logo.position = Vector3(0.0, 0.004, 0.0)
	coup_logo.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_deck_top_card.add_child(coup_logo)

	_deck_count_lbl = _create_label_3d("۷ کارت دربار", 24, Color(0.98, 0.94, 0.84), 0.0010)
	_deck_count_lbl.position = Vector3(0.0, 0.007, 0.152)
	_deck_count_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_deck_root.add_child(_deck_count_lbl)

	# 3. Treasury Coin Vault (Center-Right)
	_treasury_root = Node3D.new()
	_treasury_root.position = Vector3(0.135, y_base + 0.003, -0.02)
	add_child(_treasury_root)

	_add_cyl(_treasury_root, 0.095, 0.082, 0.014, Vector3(0.0, 0.007, 0.0), mat_walnut, Vector3.ZERO, 24)
	_add_cyl(_treasury_root, 0.084, 0.084, 0.004, Vector3(0.0, 0.013, 0.0), mat_crimson_velvet, Vector3.ZERO, 24)
	_add_torus(_treasury_root, 0.086, 0.096, Vector3(0.0, 0.015, 0.0), mat_gold)

	var coin_piles: Array[Vector3] = [
		Vector3(-0.028, 0.017, -0.022),
		Vector3(0.026, 0.017, -0.018),
		Vector3(-0.020, 0.017, 0.026),
		Vector3(0.024, 0.017, 0.024),
		Vector3(0.0, 0.017, 0.0),
	]
	_treasury_coins.clear()
	for p: Vector3 in coin_piles:
		for h_i: int in range(5):
			var c_mesh: MeshInstance3D = _add_cyl(
				_treasury_root,
				0.017,
				0.017,
				0.0045,
				p + Vector3(0.0, float(h_i) * 0.005, 0.0),
				mat_gold,
				Vector3.ZERO,
				16
			)
			_treasury_coins.append(c_mesh)

	var tr_lbl: Label3D = _create_label_3d("خزانه سکه", 24, Color(1.0, 0.88, 0.45), 0.0010)
	tr_lbl.position = Vector3(0.0, 0.012, 0.122)
	tr_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_treasury_root.add_child(tr_lbl)

	# 4. Phase Beacon Crystal (Front-Center)
	var beacon_root: Node3D = Node3D.new()
	beacon_root.position = Vector3(0.0, y_base + 0.003, 0.195)
	add_child(beacon_root)

	_add_cyl(beacon_root, 0.056, 0.062, 0.009, Vector3(0.0, 0.0045, 0.0), mat_walnut, Vector3.ZERO, 8)
	_add_cyl(beacon_root, 0.048, 0.052, 0.009, Vector3(0.0, 0.011, 0.0), mat_gold, Vector3.ZERO, 8)

	_phase_gem_mat = StandardMaterial3D.new()
	_phase_gem_mat.albedo_color = Color(0.28, 0.92, 0.56)
	_phase_gem_mat.roughness = 0.16
	_phase_gem_mat.metallic = 0.25
	_phase_gem_mat.emission_enabled = true
	_phase_gem_mat.emission = Color(0.28, 0.92, 0.56)
	_phase_gem_mat.emission_energy_multiplier = 1.25

	_phase_halo_ring = _add_torus(beacon_root, 0.036, 0.044, Vector3(0.0, 0.017, 0.0), _phase_gem_mat)

	_phase_crystal = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.026
	sm.height = 0.054
	sm.radial_segments = 6
	sm.rings = 2
	_phase_crystal.mesh = sm
	_phase_crystal.position = Vector3(0.0, 0.044, 0.0)
	_phase_crystal.material_override = _phase_gem_mat
	beacon_root.add_child(_phase_crystal)

	_phase_name_3d = _create_label_3d("نوبت اقدام", 26, Color(0.95, 0.98, 0.92), 0.0010)
	_phase_name_3d.position = Vector3(0.0, 0.014, 0.078)
	_phase_name_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	beacon_root.add_child(_phase_name_3d)

	# 5. Opponent Seats (1 = Top, 2 = Left, 3 = Right)
	var opp_slots: Dictionary = {
		1: {"pos": Vector3(0.0, y_base + 0.003, -0.375), "rot_y": 0.0},
		2: {"pos": Vector3(-0.465, y_base + 0.003, -0.145), "rot_y": -62.0},
		3: {"pos": Vector3(0.465, y_base + 0.003, -0.145), "rot_y": 62.0},
	}
	for s_idx: int in opp_slots.keys():
		var cfg: Dictionary = opp_slots[s_idx]
		var holder: Node3D = Node3D.new()
		holder.position = cfg["pos"]
		holder.rotation_degrees = Vector3(0.0, float(cfg["rot_y"]), 0.0)
		holder.visible = false
		add_child(holder)
		_opponent_stations[s_idx] = holder

func update_table_state(phase: String, deck_rem: int) -> void:
	# 1. Court Deck visual thickness
	if is_instance_valid(_deck_count_lbl):
		_deck_count_lbl.text = "%s کارت دربار" % CoupCardWidgetScript.to_fa_digits(str(max(0, deck_rem)))
	var ratio: float = clampf(float(deck_rem) / 15.0, 0.25, 1.0)
	var h: float = 0.030 * ratio
	if is_instance_valid(_deck_stack_body):
		_deck_stack_body.scale.y = ratio
		_deck_stack_body.position.y = 0.005 + h * 0.5
	if is_instance_valid(_deck_top_card):
		_deck_top_card.position.y = h + 0.007

	# 2. Phase Crystal Color & Label
	var p_col: Color = Color(0.28, 0.92, 0.56)
	var p_txt: String = "نوبت اقدام"
	match phase:
		"challenge_action", "challenge_block":
			p_col = Color(1.0, 0.42, 0.24)
			p_txt = "فرصت چالش"
		"block_action":
			p_col = Color(0.32, 0.72, 1.0)
			p_txt = "فرصت دفاع"
		"lose_influence":
			p_col = Color(0.95, 0.22, 0.30)
			p_txt = "حذف نفوذ"
		"exchange":
			p_col = Color(0.22, 0.88, 0.48)
			p_txt = "مبادله سفیر"
		"finished":
			p_col = Color(1.0, 0.84, 0.28)
			p_txt = "پایان بازی"
	if _phase_gem_mat:
		_phase_gem_mat.albedo_color = p_col
		_phase_gem_mat.emission = p_col
	if is_instance_valid(_phase_name_3d):
		_phase_name_3d.text = p_txt
		_phase_name_3d.modulate = p_col.lightened(0.38)

func update_opponent_stations(seat_data: Dictionary, active_seat: int) -> void:
	_target_rings.clear()
	_targetable_slots.clear()

	var rack_wood: StandardMaterial3D = StandardMaterial3D.new()
	rack_wood.albedo_color = Color(0.18, 0.09, 0.05)
	rack_wood.roughness = 0.32

	var mat_gold: StandardMaterial3D = StandardMaterial3D.new()
	mat_gold.albedo_color = Color(0.92, 0.74, 0.24)
	mat_gold.metallic = 0.84
	mat_gold.roughness = 0.22

	var mat_card_back: StandardMaterial3D = StandardMaterial3D.new()
	mat_card_back.albedo_color = Color(0.10, 0.09, 0.14)
	mat_card_back.roughness = 0.26

	var mat_dead_back: StandardMaterial3D = StandardMaterial3D.new()
	mat_dead_back.albedo_color = Color(0.24, 0.14, 0.14)
	mat_dead_back.roughness = 0.42

	for s_idx: int in _opponent_stations.keys():
		var holder: Node3D = _opponent_stations[s_idx]
		for ch: Node in holder.get_children():
			holder.remove_child(ch)
			ch.queue_free()

		if not seat_data.has(s_idx):
			holder.visible = false
			continue

		holder.visible = true
		var info: Dictionary = seat_data[s_idx]
		var gid: int = int(info.get("gamer_id", 2))
		var p_name: String = String(info.get("name", "حریف"))
		var coins: int = int(info.get("coins", 0))
		var alive: bool = bool(info.get("alive", true))
		var alive_cards: int = int(info.get("alive_cards", 0))
		var cards: Array = info.get("cards", []) if typeof(info.get("cards")) == TYPE_ARRAY else []
		var is_targetable: bool = bool(info.get("targetable", false))
		var is_pending_loss: bool = bool(info.get("pending_loss", false))
		var is_turn: bool = (active_seat == s_idx) and alive
		var f_col: Color = FACTION_COLORS.get(gid, Color(0.8, 0.8, 0.8))

		_targetable_slots[s_idx] = is_targetable

		# 1. Base Stand + Beacon Trim
		_add_box(holder, Vector3(0.23, 0.010, 0.068), Vector3(0.0, 0.005, 0.0), rack_wood)

		var trim_mat: StandardMaterial3D = StandardMaterial3D.new()
		if is_targetable:
			trim_mat.albedo_color = Color(1.0, 0.30, 0.22)
			trim_mat.emission_enabled = true
			trim_mat.emission = Color(1.0, 0.24, 0.16)
			trim_mat.emission_energy_multiplier = 2.0
		elif is_pending_loss:
			trim_mat.albedo_color = Color(1.0, 0.65, 0.20)
			trim_mat.emission_enabled = true
			trim_mat.emission = Color(1.0, 0.55, 0.12)
			trim_mat.emission_energy_multiplier = 1.8
		elif is_turn:
			trim_mat.albedo_color = f_col
			trim_mat.emission_enabled = true
			trim_mat.emission = f_col
			trim_mat.emission_energy_multiplier = 1.65
		else:
			trim_mat.albedo_color = Color(0.62, 0.48, 0.22) if alive else Color(0.28, 0.20, 0.20)
			trim_mat.metallic = 0.72
			trim_mat.roughness = 0.30
		_add_box(holder, Vector3(0.242, 0.004, 0.076), Vector3(0.0, 0.001, 0.0), trim_mat)

		# Targetable Pulsing Torus Ring
		if is_targetable:
			var t_mat: StandardMaterial3D = StandardMaterial3D.new()
			t_mat.albedo_color = Color(1.0, 0.82, 0.22)
			t_mat.emission_enabled = true
			t_mat.emission = Color(1.0, 0.32, 0.18)
			t_mat.emission_energy_multiplier = 2.2
			var t_ring: MeshInstance3D = _add_torus(holder, 0.135, 0.148, Vector3(0.0, 0.004, 0.015), t_mat)
			_target_rings[s_idx] = t_ring

		# 2. Player's 2 Influence Cards (Hidden upright OR Revealed face-up role)
		for c_i: int in range(min(2, cards.size())):
			var c_dict: Dictionary = cards[c_i] if typeof(cards[c_i]) == TYPE_DICTIONARY else {}
			var rev: bool = bool(c_dict.get("revealed", false))
			var x_off: float = -0.048 if c_i == 0 else 0.048

			if not rev:
				var c_piv: Node3D = Node3D.new()
				c_piv.position = Vector3(x_off, 0.050, 0.0)
				c_piv.rotation_degrees = Vector3(-16.0, 0.0, 4.0 if c_i == 0 else -4.0)
				holder.add_child(c_piv)

				_add_box(c_piv, Vector3(0.072, 0.102, 0.003), Vector3.ZERO, mat_gold)
				_add_box(c_piv, Vector3(0.065, 0.094, 0.0035), Vector3(0.0, 0.0, 0.0004), mat_card_back)
				_add_box(c_piv, Vector3(0.030, 0.044, 0.004), Vector3(0.0, 0.0, 0.0006), trim_mat)
			else:
				var role_str: String = String(c_dict.get("role", ""))
				var role_col: Color = CoupCardWidgetScript.get_role_color(role_str)
				var role_mat: StandardMaterial3D = StandardMaterial3D.new()
				role_mat.albedo_color = role_col.darkened(0.25)
				role_mat.roughness = 0.35

				var flat_piv: Node3D = Node3D.new()
				flat_piv.position = Vector3(x_off, 0.013, 0.046)
				holder.add_child(flat_piv)

				_add_box(flat_piv, Vector3(0.072, 0.003, 0.098), Vector3.ZERO, mat_dead_back)
				_add_box(flat_piv, Vector3(0.064, 0.0036, 0.090), Vector3(0.0, 0.0005, 0.0), role_mat)

				var r_lbl: Label3D = _create_label_3d("💀 " + CoupCardWidgetScript.get_role_name_fa(role_str), 22, Color(1.0, 0.78, 0.78), 0.00095)
				r_lbl.position = Vector3(0.0, 0.004, 0.0)
				r_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
				flat_piv.add_child(r_lbl)

		# 3. 3D Gold Coin Stack next to opponent rack
		if alive and coins > 0:
			var vis_coins: int = clampi(coins, 1, 10)
			for ci: int in range(vis_coins):
				var col_idx: int = ci / 5
				var row_idx: int = ci % 5
				var cx: float = 0.145 + float(col_idx) * 0.028
				var cy: float = 0.006 + float(row_idx) * 0.005
				_add_cyl(holder, 0.013, 0.013, 0.004, Vector3(cx, cy, 0.010), mat_gold, Vector3.ZERO, 12)

		# 4. Floating Seat Nameplate (Billboards cleanly above cards)
		var hearts: String = "♥".repeat(max(0, alive_cards)) if alive else "💀"
		var badge_txt: String = "%s • 🪙%s • %s" % [p_name, CoupCardWidgetScript.to_fa_digits(str(coins)), hearts]
		if not alive:
			badge_txt = "💀 %s (حذف شد)" % p_name
		elif is_targetable:
			badge_txt = "🎯 انتخاب هدف: " + badge_txt
		elif is_turn:
			badge_txt = "🟢 " + badge_txt

		var badge_col: Color = Color(1.0, 0.45, 0.40) if not alive else (
			Color(1.0, 0.88, 0.25) if is_targetable else (
				Color(0.46, 0.98, 0.66) if is_turn else Color(0.96, 0.92, 0.80)
			)
		)
		var seat_lbl: Label3D = _create_label_3d(badge_txt, 30, badge_col, 0.0011)
		seat_lbl.position = Vector3(0.0, 0.125, 0.0)
		seat_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		seat_lbl.no_depth_test = true
		holder.add_child(seat_lbl)

		# 5. Clickable Collider for Target Selection
		if is_targetable:
			var body: StaticBody3D = StaticBody3D.new()
			var col_s: CollisionShape3D = CollisionShape3D.new()
			var b_sh: BoxShape3D = BoxShape3D.new()
			b_sh.size = Vector3(0.28, 0.14, 0.18)
			col_s.shape = b_sh
			col_s.position = Vector3(0.0, 0.055, 0.01)
			body.add_child(col_s)
			var clicked_slot: int = s_idx
			body.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _idx: int) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					seat_clicked.emit(clicked_slot)
			)
			holder.add_child(body)
