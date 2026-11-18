class_name BaseGameBoard
extends Node3D

# BaseGameBoard
# Abstract base class for all Cafe Fekr 3D game boards (TicTacToe, Chess, Checkers, Backgammon, etc.)
# Mirrors BaseGameController from Flutter:
# Standardizes network command handling, turn management, physical interaction,
# move dispatching, board state synchronization, and round lifecycle.

signal invalid_move_attempted(reason: String)
signal move_played(move_data: Dictionary)
signal round_completed(winner_id: int, extra: Dictionary)

@export var game_type: String = GameTypes.TIC_TAC_TOE

var is_board_locked: bool = false
var is_my_turn: bool = false
var current_turn: int = 1
var my_player_index: int = 1

func _enter_tree() -> void:
	_connect_network_signals()

func _ready() -> void:
	sync_turn_state()

func _exit_tree() -> void:
	_disconnect_network_signals()
	cleanup_board()

func sync_turn_state() -> void:
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	if GameManager.is_spectating:
		is_my_turn = false
		is_board_locked = true
		on_turn_changed(current_turn, false)
		return
	if not GameManager.is_game_active:
		is_my_turn = false
		is_board_locked = true
		if game_type == GameTypes.FEKRBEKR:
			on_turn_changed(0, true)
		return
	if GameRegistry.is_simultaneous(game_type):
		is_my_turn = true
		is_board_locked = false
		on_turn_changed(current_turn, true)
		return
	is_my_turn = (current_turn == my_player_index)
	is_board_locked = not is_my_turn
	on_turn_changed(current_turn, is_my_turn)

# --- Network Signal Wiring ---

func _connect_network_signals() -> void:
	if not NetworkManager.turn_data_received.is_connected(_on_internal_turn_data):
		NetworkManager.turn_data_received.connect(_on_internal_turn_data)
	if not NetworkManager.roll_result_received.is_connected(_on_internal_roll_result):
		NetworkManager.roll_result_received.connect(_on_internal_roll_result)
	if not NetworkManager.out_of_move_received.is_connected(_on_internal_out_of_move):
		NetworkManager.out_of_move_received.connect(_on_internal_out_of_move)
	if not NetworkManager.turn_changed.is_connected(_on_internal_turn_changed):
		NetworkManager.turn_changed.connect(_on_internal_turn_changed)
	if not NetworkManager.piece_selected.is_connected(_on_internal_piece_selected):
		NetworkManager.piece_selected.connect(_on_internal_piece_selected)
	if not NetworkManager.piece_swapped.is_connected(_on_internal_piece_swapped):
		NetworkManager.piece_swapped.connect(_on_internal_piece_swapped)
	if not NetworkManager.piece_removed.is_connected(_on_internal_piece_removed):
		NetworkManager.piece_removed.connect(_on_internal_piece_removed)
	if not NetworkManager.select_remove_peace_received.is_connected(_on_internal_select_remove_peace):
		NetworkManager.select_remove_peace_received.connect(_on_internal_select_remove_peace)
	if not NetworkManager.round_finished.is_connected(_on_internal_round_finished):
		NetworkManager.round_finished.connect(_on_internal_round_finished)
	if not NetworkManager.new_turn_round_received.is_connected(_on_internal_new_turn_round):
		NetworkManager.new_turn_round_received.connect(_on_internal_new_turn_round)
	if not NetworkManager.finish_turn_round_received.is_connected(_on_internal_finish_turn_round):
		NetworkManager.finish_turn_round_received.connect(_on_internal_finish_turn_round)
	if not NetworkManager.new_round_started.is_connected(_on_internal_new_round):
		NetworkManager.new_round_started.connect(_on_internal_new_round)
	if not NetworkManager.game_finished.is_connected(_on_internal_game_finished):
		NetworkManager.game_finished.connect(_on_internal_game_finished)
	if not NetworkManager.game_data_received.is_connected(_on_internal_game_data):
		NetworkManager.game_data_received.connect(_on_internal_game_data)
	if not NetworkManager.wait_time_received.is_connected(_on_internal_wait_time):
		NetworkManager.wait_time_received.connect(_on_internal_wait_time)
	if not NetworkManager.start_game_received.is_connected(_on_internal_start_game):
		NetworkManager.start_game_received.connect(_on_internal_start_game)
	if not NetworkManager.start_game_data_received.is_connected(_on_internal_start_game_data):
		NetworkManager.start_game_data_received.connect(_on_internal_start_game_data)
	if not NetworkManager.wrong_solve_received.is_connected(_on_internal_wrong_solve):
		NetworkManager.wrong_solve_received.connect(_on_internal_wrong_solve)
	if not NetworkManager.select_peace_result_received.is_connected(_on_internal_select_peace_result):
		NetworkManager.select_peace_result_received.connect(_on_internal_select_peace_result)
	if not NetworkManager.mine_selected_received.is_connected(_on_internal_mine_selected):
		NetworkManager.mine_selected_received.connect(_on_internal_mine_selected)
	if not NetworkManager.select_mine_correct_received.is_connected(_on_internal_select_mine_correct):
		NetworkManager.select_mine_correct_received.connect(_on_internal_select_mine_correct)
	if not NetworkManager.select_mine_wrong_received.is_connected(_on_internal_select_mine_wrong):
		NetworkManager.select_mine_wrong_received.connect(_on_internal_select_mine_wrong)
	if not NetworkManager.player_score_received.is_connected(_on_internal_player_score):
		NetworkManager.player_score_received.connect(_on_internal_player_score)

func _disconnect_network_signals() -> void:
	if NetworkManager.turn_data_received.is_connected(_on_internal_turn_data):
		NetworkManager.turn_data_received.disconnect(_on_internal_turn_data)
	if NetworkManager.roll_result_received.is_connected(_on_internal_roll_result):
		NetworkManager.roll_result_received.disconnect(_on_internal_roll_result)
	if NetworkManager.out_of_move_received.is_connected(_on_internal_out_of_move):
		NetworkManager.out_of_move_received.disconnect(_on_internal_out_of_move)
	if NetworkManager.turn_changed.is_connected(_on_internal_turn_changed):
		NetworkManager.turn_changed.disconnect(_on_internal_turn_changed)
	if NetworkManager.piece_selected.is_connected(_on_internal_piece_selected):
		NetworkManager.piece_selected.disconnect(_on_internal_piece_selected)
	if NetworkManager.piece_swapped.is_connected(_on_internal_piece_swapped):
		NetworkManager.piece_swapped.disconnect(_on_internal_piece_swapped)
	if NetworkManager.piece_removed.is_connected(_on_internal_piece_removed):
		NetworkManager.piece_removed.disconnect(_on_internal_piece_removed)
	if NetworkManager.select_remove_peace_received.is_connected(_on_internal_select_remove_peace):
		NetworkManager.select_remove_peace_received.disconnect(_on_internal_select_remove_peace)
	if NetworkManager.round_finished.is_connected(_on_internal_round_finished):
		NetworkManager.round_finished.disconnect(_on_internal_round_finished)
	if NetworkManager.new_turn_round_received.is_connected(_on_internal_new_turn_round):
		NetworkManager.new_turn_round_received.disconnect(_on_internal_new_turn_round)
	if NetworkManager.finish_turn_round_received.is_connected(_on_internal_finish_turn_round):
		NetworkManager.finish_turn_round_received.disconnect(_on_internal_finish_turn_round)
	if NetworkManager.new_round_started.is_connected(_on_internal_new_round):
		NetworkManager.new_round_started.disconnect(_on_internal_new_round)
	if NetworkManager.game_finished.is_connected(_on_internal_game_finished):
		NetworkManager.game_finished.disconnect(_on_internal_game_finished)
	if NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)
	if NetworkManager.game_data_received.is_connected(_on_internal_game_data):
		NetworkManager.game_data_received.disconnect(_on_internal_game_data)
	if NetworkManager.wait_time_received.is_connected(_on_internal_wait_time):
		NetworkManager.wait_time_received.disconnect(_on_internal_wait_time)
	if NetworkManager.start_game_received.is_connected(_on_internal_start_game):
		NetworkManager.start_game_received.disconnect(_on_internal_start_game)
	if NetworkManager.start_game_data_received.is_connected(_on_internal_start_game_data):
		NetworkManager.start_game_data_received.disconnect(_on_internal_start_game_data)
	if NetworkManager.wrong_solve_received.is_connected(_on_internal_wrong_solve):
		NetworkManager.wrong_solve_received.disconnect(_on_internal_wrong_solve)
	if NetworkManager.select_peace_result_received.is_connected(_on_internal_select_peace_result):
		NetworkManager.select_peace_result_received.disconnect(_on_internal_select_peace_result)
	if NetworkManager.mine_selected_received.is_connected(_on_internal_mine_selected):
		NetworkManager.mine_selected_received.disconnect(_on_internal_mine_selected)
	if NetworkManager.select_mine_correct_received.is_connected(_on_internal_select_mine_correct):
		NetworkManager.select_mine_correct_received.disconnect(_on_internal_select_mine_correct)
	if NetworkManager.select_mine_wrong_received.is_connected(_on_internal_select_mine_wrong):
		NetworkManager.select_mine_wrong_received.disconnect(_on_internal_select_mine_wrong)
	if NetworkManager.player_score_received.is_connected(_on_internal_player_score):
		NetworkManager.player_score_received.disconnect(_on_internal_player_score)

# --- Internal Network Callbacks (Dispatches to Virtual Hooks) ---

func _on_internal_turn_data(payload: Dictionary) -> void:
	on_turn_data(payload)

func _on_internal_roll_result(payload: Dictionary) -> void:
	on_roll_result(payload)

func _on_internal_out_of_move(payload: Dictionary) -> void:
	on_out_of_move(payload)

func _on_internal_turn_changed(turn: int) -> void:
	current_turn = turn
	my_player_index = GameManager.my_player_index
	if GameManager.is_spectating:
		is_my_turn = false
		is_board_locked = true
		on_turn_changed(turn, false)
		return
	if GameRegistry.is_simultaneous(game_type):
		is_my_turn = true
		is_board_locked = false
		on_turn_changed(turn, true)
		return
	is_my_turn = (turn == my_player_index)
	is_board_locked = false
	on_turn_changed(turn, is_my_turn)

func _on_internal_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	on_piece_selected(user_id, target_peace, extra)

func _on_internal_piece_swapped(data: Dictionary) -> void:
	on_piece_swapped(data)

func _on_internal_piece_removed(data: Dictionary) -> void:
	on_piece_removed(data)

func _on_internal_select_remove_peace(remover_id: int) -> void:
	on_select_remove_peace(remover_id)

func _on_internal_new_turn_round() -> void:
	set_board_locked(GameManager.is_spectating)
	on_new_turn_round()

func _on_internal_finish_turn_round(data: Dictionary) -> void:
	set_board_locked(true)
	on_finish_turn_round(data)

func _on_internal_round_finished(payload: Variant) -> void:
	set_board_locked(true)
	on_round_finished(payload)

func _on_internal_new_round(round_num: int) -> void:
	reset_board()
	on_new_round(round_num)

func _on_internal_game_finished(_data: Dictionary) -> void:
	set_board_locked(true)

func _on_internal_reconnect_data(payload: Dictionary) -> void:
	GameManager.is_game_active = true
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", {})
	if GameManager.current_game_type == GameTypes.FEKRBEKR and typeof(g_data) == TYPE_DICTIONARY:
		var is_play_rec = bool(g_data.get("is_play_phase", false))
		var r_num = int(g_data.get("current_round", 1 if is_play_rec else 0))
		current_turn = max(1, r_num) if is_play_rec else 0
		GameManager.current_turn = current_turn
		GameManager.current_round = r_num
	elif GameManager.current_game_type == GameTypes.BATTLESHIP and typeof(g_data) == TYPE_DICTIONARY:
		var is_play_rec = bool(g_data.get("is_play_phase", false))
		current_turn = int(g_data.get("current_turn", 1)) if is_play_rec else 0
		GameManager.current_turn = current_turn
	elif GameManager.current_game_type == GameTypes.YATZY and typeof(g_data) == TYPE_DICTIONARY:
		var r_num = int(g_data.get("current_round", 1))
		current_turn = max(1, r_num)
		GameManager.current_turn = current_turn
		GameManager.current_round = r_num
	elif GameManager.current_game_type == GameTypes.QUIZ:
		var q_turn = int(g_data.get("current_turn", payload.get("current_turn", GameManager.current_turn))) if typeof(g_data) == TYPE_DICTIONARY else int(payload.get("current_turn", GameManager.current_turn))
		current_turn = max(1, q_turn)
		GameManager.current_turn = current_turn
		GameManager.current_round = current_turn
	elif typeof(g_data) == TYPE_DICTIONARY and g_data.has("current_turn"):
		current_turn = int(g_data["current_turn"])
		GameManager.current_turn = current_turn
	else:
		current_turn = GameManager.current_turn
	if GameManager.is_spectating:
		is_my_turn = false
		is_board_locked = true
	elif GameRegistry.is_simultaneous(GameManager.current_game_type):
		is_my_turn = true
		is_board_locked = false
	else:
		is_my_turn = (current_turn == my_player_index)
		is_board_locked = not is_my_turn
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board"):
			sync_board_state(g_data["board"])
		elif g_data.has("board_data"):
			sync_board_state(g_data["board_data"])
		elif g_data.has("lines_board"):
			sync_board_state(g_data["lines_board"])
		elif g_data.has("peaces"):
			sync_board_state(g_data["peaces"])
	on_turn_changed(current_turn, is_my_turn)
	on_reconnect_data(payload)

func _on_internal_game_data(payload: Dictionary) -> void:
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
	my_player_index = GameManager.my_player_index
	setup_board(payload)

func _on_internal_start_game() -> void:
	on_start_game()

func _on_internal_start_game_data(payload: Dictionary) -> void:
	on_start_game_data(payload)

func _on_internal_wrong_solve() -> void:
	on_wrong_solve()

func _on_internal_select_peace_result(payload: Dictionary) -> void:
	on_select_peace_result(payload)

func _on_internal_mine_selected(payload: Dictionary) -> void:
	on_mine_selected(payload)

func _on_internal_select_mine_correct(payload: Dictionary) -> void:
	on_select_mine_correct(payload)

func _on_internal_select_mine_wrong(payload: Dictionary) -> void:
	on_select_mine_wrong(payload)

func _on_internal_player_score(payload: Dictionary) -> void:
	on_player_score(payload)

func _on_internal_wait_time(time_sec: int) -> void:
	on_wait_time(time_sec)

# --- Public Helper Methods ---

func set_board_locked(locked: bool) -> void:
	is_board_locked = true if GameManager.is_spectating else locked

func send_move(command_id: String, payload: Variant) -> void:
	if GameManager.is_spectating:
		return
	NetworkManager.send_game_command(command_id, payload)
	move_played.emit({"command": command_id, "data": payload})

func show_hint(message: String) -> void:
	invalid_move_attempted.emit(message)

# --- Virtual Methods to Override in Concrete Game Implementations ---

func setup_board(_game_data: Dictionary) -> void:
	pass

func on_start_game() -> void:
	pass

func on_start_game_data(_payload: Dictionary) -> void:
	pass

func on_wrong_solve() -> void:
	pass

func on_select_peace_result(_payload: Dictionary) -> void:
	pass

func on_mine_selected(_payload: Dictionary) -> void:
	pass

func on_select_mine_correct(_payload: Dictionary) -> void:
	pass

func on_select_mine_wrong(_payload: Dictionary) -> void:
	pass

func on_player_score(_payload: Dictionary) -> void:
	pass

func on_wait_time(_time_sec: int) -> void:
	pass

func on_turn_data(_payload: Dictionary) -> void:
	pass
func on_roll_result(_payload: Dictionary) -> void:
	pass

func on_out_of_move(_payload: Dictionary) -> void:
	pass
func on_turn_changed(_turn: int, _is_me: bool) -> void:
	pass

func on_piece_selected(_user_id: int, _target_peace: int, _extra: Dictionary = {}) -> void:
	pass

func on_piece_swapped(_data: Dictionary) -> void:
	pass

func on_piece_removed(_data: Dictionary) -> void:
	pass

func on_select_remove_peace(_remover_id: int) -> void:
	pass

func on_new_turn_round() -> void:
	pass

func on_finish_turn_round(_data: Dictionary) -> void:
	pass

func on_round_finished(_payload: Variant) -> void:
	pass

func on_new_round(_round_num: int) -> void:
	pass

func on_reconnect_data(_payload: Dictionary) -> void:
	pass

func sync_board_state(_board_data: Variant) -> void:
	pass

func reset_board() -> void:
	pass

func cleanup_board() -> void:
	pass

# --- Shared Static 3D Mesh Baking Utility (Zero-regression draw-call reduction) ---

static func _collect_bake_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.visible and mi.mesh != null and not mi.has_meta("skip_bake"):
			out_list.append(mi)
	for ch: Node in node.get_children():
		_collect_bake_meshes(ch, out_list)

static func _rel_xform(leaf: Node3D, ancestor: Node3D) -> Transform3D:
	var xf: Transform3D = leaf.transform
	var p: Node = leaf.get_parent()
	while p != null and p != ancestor:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

static func bake_node_tree_to_mesh(branch_root: Node3D, merge_vertex_colors: bool = true) -> ArrayMesh:
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_bake_meshes(branch_root, mesh_nodes)
	if mesh_nodes.is_empty():
		return null

	var is_mobile: bool = OS.has_feature("mobile") or (OS.get_name() in ["Android", "iOS"])
	var buckets: Dictionary = {} # key -> {"mat": Material, "items": Array}
	var bucket_keys: Array[String] = []
	var vc_mats: Dictionary = {}

	for mi: MeshInstance3D in mesh_nodes:
		var m_res: Mesh = mi.mesh
		if m_res == null or m_res.get_surface_count() == 0:
			continue
		if is_mobile:
			if m_res is SphereMesh:
				var sp: SphereMesh = m_res as SphereMesh
				if sp.radial_segments > 14 or sp.rings > 7:
					sp.radial_segments = mini(sp.radial_segments, 12)
					sp.rings = mini(sp.rings, 6)
			elif m_res is CylinderMesh:
				var cy: CylinderMesh = m_res as CylinderMesh
				if cy.radial_segments > 16 or cy.rings > 1:
					cy.radial_segments = mini(cy.radial_segments, 14)
					cy.rings = 1
			elif m_res is TorusMesh:
				var to: TorusMesh = m_res as TorusMesh
				if to.rings > 18 or to.ring_segments > 10:
					to.rings = mini(to.rings, 16)
					to.ring_segments = mini(to.ring_segments, 8)

		var mat: Material = mi.material_override
		if mat == null:
			mat = m_res.surface_get_material(0)

		var b_key: String = "null"
		var b_mat: Material = mat
		var v_col: Color = Color.WHITE
		var use_vc: bool = false

		if merge_vertex_colors and mat is StandardMaterial3D:
			var sm: StandardMaterial3D = mat as StandardMaterial3D
			if sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and sm.albedo_texture == null and not sm.emission_enabled and not sm.rim_enabled:
				use_vc = true
				v_col = sm.albedo_color
				if sm.metallic >= 0.5:
					b_key = "vc_metal"
					if not vc_mats.has(b_key):
						var mm := StandardMaterial3D.new()
						mm.metallic = sm.metallic
						mm.roughness = sm.roughness
						mm.vertex_color_use_as_albedo = true
						mm.vertex_color_is_srgb = true
						vc_mats[b_key] = mm
					b_mat = vc_mats[b_key]
				else:
					b_key = "vc_solid"
					if not vc_mats.has(b_key):
						var ms := StandardMaterial3D.new()
						ms.metallic = sm.metallic
						ms.roughness = sm.roughness
						ms.vertex_color_use_as_albedo = true
						ms.vertex_color_is_srgb = true
						vc_mats[b_key] = ms
					b_mat = vc_mats[b_key]
			else:
				b_key = "raw_%d" % sm.get_instance_id()
		elif mat != null:
			b_key = "raw_%d" % mat.get_instance_id()

		if not buckets.has(b_key):
			buckets[b_key] = {"mat": b_mat, "use_vc": use_vc, "items": []}
			bucket_keys.append(b_key)
		(buckets[b_key]["items"] as Array).append({
			"mesh": m_res,
			"xform": _rel_xform(mi, branch_root),
			"color": v_col
		})

	var merged := ArrayMesh.new()
	for b_key: String in bucket_keys:
		var b_data: Dictionary = buckets[b_key]
		var bucket_mat: Material = b_data["mat"]
		var use_vc: bool = bool(b_data["use_vc"])
		var entries: Array = b_data["items"]

		var out_v := PackedVector3Array()
		var out_n := PackedVector3Array()
		var out_uv := PackedVector2Array()
		var out_c := PackedColorArray()
		var out_i := PackedInt32Array()

		for item_v in entries:
			var item: Dictionary = item_v
			var sub_mesh: Mesh = item["mesh"]
			var sub_xf: Transform3D = item["xform"]
			var v_col: Color = item["color"]

			for surf_i in range(sub_mesh.get_surface_count()):
				var src: Array = sub_mesh.surface_get_arrays(surf_i)
				if src.is_empty():
					continue
				var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
				var vc: int = sv.size()
				if vc == 0:
					continue
				var has_n: bool = src[Mesh.ARRAY_NORMAL] != null and (src[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == vc
				var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL] if has_n else PackedVector3Array()
				var has_uv: bool = src[Mesh.ARRAY_TEX_UV] != null and (src[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == vc
				var suv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV] if has_uv else PackedVector2Array()
				var si: PackedInt32Array = src[Mesh.ARRAY_INDEX] if src[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

				var det: float = sub_xf.basis.determinant()
				var nb: Basis = sub_xf.basis.inverse().transposed() if absf(det) > 1e-8 else Basis.IDENTITY
				var flip: bool = det < 0.0
				var base_off: int = out_v.size()

				for k in range(vc):
					out_v.append(sub_xf * sv[k])
					out_n.append((nb * sn[k]).normalized() if has_n else Vector3.UP)
					out_uv.append(suv[k] if has_uv else Vector2.ZERO)
					if use_vc:
						out_c.append(v_col)

				if si.is_empty():
					for ti in range(0, vc - 2, 3):
						if flip:
							out_i.append(base_off + ti)
							out_i.append(base_off + ti + 2)
							out_i.append(base_off + ti + 1)
						else:
							out_i.append(base_off + ti)
							out_i.append(base_off + ti + 1)
							out_i.append(base_off + ti + 2)
				else:
					if flip:
						for ti in range(0, si.size() - 2, 3):
							out_i.append(base_off + si[ti])
							out_i.append(base_off + si[ti + 2])
							out_i.append(base_off + si[ti + 1])
					else:
						for ii in si:
							out_i.append(base_off + ii)

		if out_v.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = out_v
		arr[Mesh.ARRAY_NORMAL] = out_n
		arr[Mesh.ARRAY_TEX_UV] = out_uv
		if use_vc:
			arr[Mesh.ARRAY_COLOR] = out_c
		arr[Mesh.ARRAY_INDEX] = out_i
		var s_idx: int = merged.get_surface_count()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if bucket_mat != null:
			merged.surface_set_material(s_idx, bucket_mat)

	return merged

static func bake_and_replace_static_meshes(branch_root: Node3D, baked_name: String = "BakedStaticMesh", merge_vertex_colors: bool = true) -> MeshInstance3D:
	var to_free: Array[MeshInstance3D] = []
	_collect_bake_meshes(branch_root, to_free)
	if to_free.is_empty():
		return null
	var merged: ArrayMesh = bake_node_tree_to_mesh(branch_root, merge_vertex_colors)
	if merged == null:
		return null
	for mi: MeshInstance3D in to_free:
		if is_instance_valid(mi):
			if mi.get_parent() != null:
				mi.get_parent().remove_child(mi)
			mi.queue_free()
	var baked_mi := MeshInstance3D.new()
	baked_mi.name = baked_name
	baked_mi.mesh = merged
	branch_root.add_child(baked_mi)
	return baked_mi
