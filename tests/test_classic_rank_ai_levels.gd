extends SceneTree

const GameRegistry = preload("res://scripts/games/game_registry.gd")

func _initialize() -> void:
	_run_tests()

func _run_tests() -> void:
	print("[TestClassicRankAILevels] Running Godot Classic Rank AI level tests...")

	# 1. Normalization & Default Level = 2
	assert(GameRegistry.DEFAULT_CLASSIC_AI_LEVEL == 2, "Default Classic AI level must be 2")
	assert(GameRegistry.normalize_classic_ai_level(null) == 2, "null must default to 2")
	assert(GameRegistry.normalize_classic_ai_level(99) == 2, "out-of-range must default to 2")
	assert(GameRegistry.normalize_classic_ai_level(1) == 1, "1 must stay 1")
	assert(GameRegistry.normalize_classic_ai_level("easy") == 1, "easy must normalize to 1")
	assert(GameRegistry.normalize_classic_ai_level(2) == 2, "2 must stay 2")
	assert(GameRegistry.normalize_classic_ai_level("medium") == 2, "medium must normalize to 2")
	assert(GameRegistry.normalize_classic_ai_level(3) == 3, "3 must stay 3")
	assert(GameRegistry.normalize_classic_ai_level("hard") == 3, "hard must normalize to 3")

	# 2. Rewards strictly increase with AI opponent level across all game difficulties
	for g_type in [GameTypes.TIC_TAC_TOE, GameTypes.FOURINROW, GameTypes.CHESS, GameTypes.RISK]:
		var r1: Dictionary = GameRegistry.get_classic_rank_rewards(g_type, true, false, 1)
		var r2: Dictionary = GameRegistry.get_classic_rank_rewards(g_type, true, false, 2)
		var r3: Dictionary = GameRegistry.get_classic_rank_rewards(g_type, true, false, 3)
		assert(int(r1["xp"]) < int(r2["xp"]) and int(r2["xp"]) < int(r3["xp"]), "Win XP must scale with AI level for %s" % g_type)
		assert(int(r1["coin"]) < int(r2["coin"]) and int(r2["coin"]) < int(r3["coin"]), "Win coin must scale with AI level for %s" % g_type)

	# 3. Verify exact values match backend/server table
	var chess_hard: Dictionary = GameRegistry.get_classic_rank_rewards(GameTypes.CHESS, true, false, 3)
	assert(int(chess_hard["xp"]) == 35 and int(chess_hard["coin"]) == 12, "Chess Hard AI win must give 35 XP, 12 coin")
	var ttt_med: Dictionary = GameRegistry.get_classic_rank_rewards(GameTypes.TIC_TAC_TOE, true, false, 2)
	assert(int(ttt_med["xp"]) == 10 and int(ttt_med["coin"]) == 4, "TicTacToe Medium AI win must give 10 XP, 4 coin")
	var ttt_easy: Dictionary = GameRegistry.get_classic_rank_rewards(GameTypes.TIC_TAC_TOE, true, false, 1)
	assert(int(ttt_easy["xp"]) == 6 and int(ttt_easy["coin"]) == 2, "TicTacToe Easy AI win must give 6 XP, 2 coin")

	# 4. Instantiate ClassicRankDialog scene & verify AI level selector + live preview + signal
	var dlg_scene: PackedScene = load("res://scenes/ui/classic_rank/classic_rank_dialog.tscn")
	assert(dlg_scene != null, "ClassicRankDialog scene must load cleanly")
	var dlg = dlg_scene.instantiate()
	get_root().add_child(dlg)
	await process_frame

	assert(dlg.selected_ai_level == 2, "Dialog must default to AI level 2")
	var captured: Array = []
	dlg.start_game_requested.connect(func(g_type: String, ai_lvl: int):
		captured.append({"game_type": g_type, "ai_level": ai_lvl})
	)

	# Switch to Level 3 (Hard) via button click
	var ai_row = dlg.get_node("InnerBezel/VBox/AiLevelTrack/AiLevelCol/AiLevelRow")
	assert(ai_row != null and ai_row.get_child_count() == 3, "AiLevelRow must have 3 AI level buttons")
	ai_row.get_child(0).pressed.emit() # First child in RTL order is Hard (3)
	assert(dlg.selected_ai_level == 3, "Clicking Hard button must select AI level 3")

	dlg._on_start_game_pressed()
	assert(captured.size() == 1 and int(captured[0]["ai_level"]) == 3, "Start game signal must emit selected AI level 3")

	dlg.queue_free()
	print("[TestClassicRankAILevels] ALL PASSED")
	quit(0)
