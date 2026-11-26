extends Node

func _assert_cond(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERTION FAILED: " + msg)
		print("[FAIL] " + msg)
		get_tree().quit(1)


func _collect_sublegible_controls(node: Node, out: Array[String]) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		var ctrl := node as Control
		if not (ctrl.has_meta(&"_resp_raw") and bool(ctrl.get_meta(&"_resp_raw"))):
			if (ctrl is Label) or (ctrl is Button) or (ctrl is LineEdit) or (ctrl is TextEdit):
				var fsz: int = ctrl.get_theme_font_size("font_size")
				if fsz > 0 and fsz < UITypography.ABSOLUTE_MIN_FONT_PX:
					out.append("%s (%s) font_size=%d" % [ctrl.get_path(), ctrl.get_class(), fsz])
			elif ctrl is RichTextLabel:
				var rfsz: int = ctrl.get_theme_font_size("normal_font_size")
				if rfsz > 0 and rfsz < UITypography.ABSOLUTE_MIN_FONT_PX:
					out.append("%s (RichTextLabel) font_size=%d" % [ctrl.get_path(), rfsz])
	elif node is Label3D:
		var lbl3d := node as Label3D
		var world_h: float = float(lbl3d.font_size) * lbl3d.pixel_size
		if world_h < 0.026:
			out.append("%s (Label3D) font_size=%d pixel_size=%.5f world_h=%.4f" % [lbl3d.get_path(), lbl3d.font_size, lbl3d.pixel_size, world_h])
	for ch in node.get_children():
		_collect_sublegible_controls(ch, out)


func _ready() -> void:
	print("==================================================")
	print("--- RESPONSIVE TYPOGRAPHY & LAYOUT TEST SUITE ---")
	print("==================================================")

	_assert_cond(ResponsiveUI != null, "ResponsiveUI autoload must exist")
	var theme_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	_assert_cond(theme_path == "res://resources/cafe_theme.tres", "Project custom theme must be cafe_theme.tres")

	# 1. Verify UITypography scale across multiple aspect ratios / viewports
	var viewports: Array[Vector2] = [
		Vector2(600, 1066),   # Compact phone
		Vector2(720, 1280),   # Standard 9:16
		Vector2(720, 1600),   # Tall 9:20
		Vector2(960, 1280),   # 3:4 Tablet
		Vector2(1280, 720),   # Landscape
	]
	for vp in viewports:
		UITypography.update_viewport_metrics(vp, 1.0)
		var f_scale: float = UITypography.get_font_scale()
		_assert_cond(f_scale >= 0.84 and f_scale <= 1.28, "Font scale in bounds for %s: %f" % [str(vp), f_scale])
		for role in UITypography.ROLE_SPECS.keys():
			var sz: int = UITypography.get_role_font_size(int(role))
			_assert_cond(sz >= UITypography.ABSOLUTE_MIN_FONT_PX, "Role %d >= 14px on %s (got %d)" % [int(role), str(vp), sz])
		var dlg_sz: Vector2 = UITypography.compute_dialog_size(680.0, 1180.0, vp)
		_assert_cond(dlg_sz.x <= vp.x and dlg_sz.y <= vp.y, "Dialog size %s must fit inside viewport %s" % [str(dlg_sz), str(vp)])
	UITypography.update_viewport_metrics(Vector2(720, 1280), 1.0)
	print("[PASS] UITypography scale & dialog bounds verified across 5 viewport aspect ratios.")

	# 2. Verify Main Scene + All Tabs & Dialogs
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	_assert_cond(main_scene != null, "main.tscn must load")
	var main := main_scene.instantiate()
	add_child(main)

	for t in ["social", "history", "play", "library", "user"]:
		main.main_tab_shell.switch_to_tab(t)
	for p in ["notifications", "match_history", "friends"]:
		main.main_tab_shell.open_subpage(p)
	main.main_tab_shell.switch_to_tab("play")

	await get_tree().process_frame
	await get_tree().process_frame

	var bad_nodes: Array[String] = []
	_collect_sublegible_controls(main, bad_nodes)
	_assert_cond(bad_nodes.is_empty(), "No sub-14px text in main + tabs + dialogs. Found: %s" % str(bad_nodes))
	print("[PASS] Main scene, all 5 tabs, 3 subpages, and all preloaded dialogs pass >= 14px legibility.")

	# 2b. Verify ClassicRankDialog start button & compact bottom frame margin
	var classic_dlg := (load("res://scenes/ui/classic_rank/classic_rank_dialog.tscn") as PackedScene).instantiate()
	add_child(classic_dlg)
	await get_tree().process_frame
	var outer_sb := classic_dlg.get_theme_stylebox("panel") as StyleBoxTexture
	_assert_cond(outer_sb != null and outer_sb.content_margin_bottom >= 40.0 and outer_sb.content_margin_bottom <= 48.0, "ClassicRankDialog outer bottom content margin clears frame (got %s)" % [str(outer_sb.content_margin_bottom if outer_sb else -1)])
	var start_btn: Button = classic_dlg.btn_start_game
	_assert_cond(is_instance_valid(start_btn), "ClassicRankDialog BtnStartGame must exist")
	_assert_cond(is_equal_approx(start_btn.custom_minimum_size.y, 100.0), "ClassicRankDialog start button height matches MultiRankDialog (got %.1f)" % start_btn.custom_minimum_size.y)
	var start_fsz: int = start_btn.get_theme_font_size("font_size")
	_assert_cond(start_fsz >= 21 and start_fsz <= 32, "ClassicRankDialog start button font_size in [21,32] (got %d)" % start_fsz)
	classic_dlg.queue_free()
	print("[PASS] ClassicRankDialog start button sizing and bottom margin verified.")

	# 2c. Verify LobbyDialog create lobby button has generous KenneyUI padding
	var lobby_dlg := (load("res://scenes/ui/lobby/lobby_dialog.tscn") as PackedScene).instantiate()
	add_child(lobby_dlg)
	await get_tree().process_frame
	var create_btn: Button = lobby_dlg.btn_show_create
	_assert_cond(is_instance_valid(create_btn), "LobbyDialog BtnShowCreate must exist")
	var create_sb := create_btn.get_theme_stylebox("normal")
	_assert_cond(create_sb != null and create_sb.content_margin_top >= 20.0 and create_sb.content_margin_bottom >= 20.0 and create_sb.content_margin_left >= 36.0, "LobbyDialog BtnShowCreate padding matches KenneyUI (got T=%.1f B=%.1f L=%.1f)" % [create_sb.content_margin_top if create_sb else 0.0, create_sb.content_margin_bottom if create_sb else 0.0, create_sb.content_margin_left if create_sb else 0.0])
	lobby_dlg.queue_free()
	print("[PASS] LobbyDialog create lobby button padding verified.")

	# 3. Verify CommonHUD, PlayerPod (all 3 modes), and TutorialCoachOverlay
	var common_hud := (load("res://scenes/games/base/common_hud.tscn") as PackedScene).instantiate()
	add_child(common_hud)
	common_hud.setup_hud([
		{"id": "p1", "name": "بازیکن اول", "counter": "۱۰", "seat_index": 1},
		{"id": "p2", "name": "بازیکن دوم", "counter": "۸", "seat_index": 2},
		{"id": "p3", "name": "Player Three", "counter": "۵", "seat_index": 3},
		{"id": "p4", "name": "آرش", "counter": "۱۲", "seat_index": 4},
	], true)

	var coach := TutorialCoachOverlay.new()
	add_child(coach)

	await get_tree().process_frame
	await get_tree().process_frame

	var bad_hud: Array[String] = []
	_collect_sublegible_controls(common_hud, bad_hud)
	_collect_sublegible_controls(coach, bad_hud)
	_assert_cond(bad_hud.is_empty(), "No sub-14px text in CommonHUD / PlayerPod / TutorialCoachOverlay. Found: %s" % str(bad_hud))
	print("[PASS] CommonHUD, 4-player PlayerPod, and TutorialCoachOverlay pass >= 14px legibility.")

	# 4. Verify All 25 3D Game Scenes + Custom Top Headers (2D >= 14px & Label3D >= 0.026 world_h)
	var all_games: Array[String] = [
		"res://scenes/games/backgammon/backgammon_3d.tscn",
		"res://scenes/games/battleship/battleship_3d.tscn",
		"res://scenes/games/boxfour/box_four_3d.tscn",
		"res://scenes/games/checkers/checkers_3d.tscn",
		"res://scenes/games/chess/chess_3d.tscn",
		"res://scenes/games/coup/coup_3d.tscn",
		"res://scenes/games/dotbox/dotbox_3d.tscn",
		"res://scenes/games/fekrbekr/fekrbekr_3d.tscn",
		"res://scenes/games/fourinrow/four_in_row_3d.tscn",
		"res://scenes/games/ludo/ludo_3d.tscn",
		"res://scenes/games/mill/mill_3d.tscn",
		"res://scenes/games/mnumbers/mnumbers_3d.tscn",
		"res://scenes/games/monopoly/monopoly_3d.tscn",
		"res://scenes/games/msweeper/msweeper_3d.tscn",
		"res://scenes/games/othello/othello_3d.tscn",
		"res://scenes/games/pentago/pentago_3d.tscn",
		"res://scenes/games/quiz/quiz_3d.tscn",
		"res://scenes/games/quoridor/quoridor_3d.tscn",
		"res://scenes/games/risk/risk_3d.tscn",
		"res://scenes/games/rpc/rpc_3d.tscn",
		"res://scenes/games/sudoku/sudoku_3d.tscn",
		"res://scenes/games/tictactoe/tictactoe_3d.tscn",
		"res://scenes/games/uno/uno_3d.tscn",
		"res://scenes/games/yatzy/yatzy_3d.tscn",
		"res://scenes/games/yinsh/yinsh_3d.tscn",
		"res://scenes/games/chess/chess_top_header.tscn",
		"res://scenes/games/quoridor/quoridor_top_header.tscn",
		"res://scenes/games/battleship/battleship_top_header.tscn",
		"res://scenes/games/fekrbekr/fekrbekr_top_header.tscn",
		"res://scenes/games/coup/coup_top_header.tscn",
		"res://scenes/games/ludo/ludo_top_header.tscn",
		"res://scenes/games/monopoly/monopoly_top_header.tscn",
		"res://scenes/games/quiz/quiz_top_header.tscn",
		"res://scenes/games/risk/risk_top_header.tscn",
		"res://scenes/games/uno/uno_top_header.tscn",
		"res://scenes/games/yatzy/yatzy_top_header.tscn",
	]
	for gp in all_games:
		var ps := load(gp) as PackedScene
		_assert_cond(ps != null, "Game scene must load: %s" % gp)
		var inst := ps.instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var bad_games: Array[String] = []
		_collect_sublegible_controls(inst, bad_games)
		_assert_cond(bad_games.is_empty(), "Sub-legible text in %s. Found: %s" % [gp, str(bad_games)])
		inst.queue_free()
		await get_tree().process_frame
	print("[PASS] All 25 game scenes and 11 top headers pass 2D >= 14px & 3D Label3D >= 0.026 legibility.")

	# 5. Verify ResponsiveUI dialog bounds clamping on narrow viewport
	var test_dlg := PanelContainer.new()
	ResponsiveUI.register_dialog(test_dlg, 660.0, 1160.0, 300.0, 240.0, true)
	add_child(test_dlg)
	var vp_now: Vector2 = ResponsiveUI.get_viewport_size()
	_assert_cond(test_dlg.custom_minimum_size.x <= vp_now.x and test_dlg.custom_minimum_size.y <= vp_now.y, "Registered dialog clamped inside viewport %s" % str(vp_now))
	print("[PASS] Registered dialog clamping verified.")

	print("==================================================")
	print("ALL RESPONSIVE TYPOGRAPHY & LAYOUT CHECKS PASSED!")
	print("==================================================")
	get_tree().quit(0)
