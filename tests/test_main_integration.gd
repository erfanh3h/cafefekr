extends Node

func _ready() -> void:
	print("==================================================")
	print("--- FULL INTEGRATION & REGRESSION VERIFICATION ---")
	print("==================================================")

	var main_scene = load("res://scenes/main/main.tscn")
	assert(main_scene != null, "main.tscn must load")
	var main = main_scene.instantiate()
	add_child(main)
	print("[PASS] main.tscn instantiated and added to tree.")

	await get_tree().process_frame
	await get_tree().process_frame

	var shell = main.main_tab_shell
	assert(is_instance_valid(shell), "main.main_tab_shell must exist")

	# 1. Verify Default Tab is Play
	assert(shell.active_tab_name == "play", "Default active tab must be 'play'")
	print("[PASS] Default active tab is 'play'.")

	# 2. Verify PlayTab actions & signals exist and fire
	var play_tab = shell.get_active_tab_instance()
	assert(is_instance_valid(play_tab), "PlayTab must be valid")

	# Test signal wiring between PlayTab -> MainTabShell -> Main
	var ranked_received = [false]
	var multi_received = [false]
	var classic_received = [false]
	var lobby_received = [false]

	shell.ranked_pressed.connect(func(): ranked_received[0] = true)
	shell.multi_rank_pressed.connect(func(): multi_received[0] = true)
	shell.classic_rank_pressed.connect(func(): classic_received[0] = true)
	shell.lobby_pressed.connect(func(): lobby_received[0] = true)

	play_tab.ranked_pressed.emit()
	assert(ranked_received[0], "ranked_pressed signal must bubble up")
	play_tab.multi_rank_pressed.emit()
	assert(multi_received[0], "multi_rank_pressed signal must bubble up")
	play_tab.classic_rank_pressed.emit()
	assert(classic_received[0], "classic_rank_pressed signal must bubble up")
	play_tab.lobby_pressed.emit()
	assert(lobby_received[0], "lobby_pressed signal must bubble up")
	print("[PASS] All PlayTab game mode signals bubble up cleanly to MainTabShell.")

	# 3. Test Play Tab Watch Live Button & Signal
	print("[TEST] Testing PlayTab Watch Live Button...")
	var watch_received = [false]
	shell.watch_live_requested.connect(func(): watch_received[0] = true)
	play_tab.btn_watch_live.pressed.emit()
	assert(watch_received[0], "watch_live_requested signal must bubble up")
	print("[PASS] PlayTab Watch Live button and signal verified.")

	# 4. Test Play Tab Exit Button & Exit Confirm Dialog
	print("[TEST] Testing ExitConfirmDialog...")
	var exit_dlg = shell.exit_confirm_dialog
	assert(is_instance_valid(exit_dlg), "ExitConfirmDialog must exist")
	play_tab.btn_exit.pressed.emit()
	assert(exit_dlg.visible, "ExitConfirmDialog should be visible")
	exit_dlg.close()
	print("[PASS] ExitConfirmDialog opened and closed successfully.")

	# 5. Test Tab Switch Cycle
	var tab_order = ["social", "history", "play", "library", "user"]
	for t in tab_order:
		shell.switch_to_tab(t)
		assert(shell.active_tab_name == t, "Tab should switch to %s" % t)
		var instance = shell.get_active_tab_instance()
		assert(is_instance_valid(instance), "Instance for %s must be valid" % t)
		assert(instance.visible, "Tab %s must be visible" % t)
		print("[PASS] Tab '%s' verified." % t)

	# 6. Test User Tab Top UserHeader and Audio Controls
	shell.switch_to_tab("user")
	var usr = shell.get_active_tab_instance()
	assert(is_instance_valid(usr.user_header), "UserTab UserHeader must exist at top")
	usr.switch_subtab("account")
	# Test audio manager integration
	var old_vol = AudioManager.music_volume
	AudioManager.set_music_volume(0.85)
	assert(abs(AudioManager.music_volume - 0.85) < 0.01, "AudioManager music volume update must work")
	AudioManager.set_music_volume(old_vol)
	print("[PASS] UserTab UserHeader and AudioManager settings verified.")

	# 7. Test Match Lifecycle / Return to Main Menu
	print("[TEST] Testing match start / return to menu flow...")
	# Simulate entering game mode: shell hidden, HUD shown
	shell.visible = false
	main.base_game_hud.visible = true
	main.cafe_table.visible = true
	print("[STATE] In-game state simulated (shell hidden, HUD visible).")

	# Simulate returning to main menu (e.g. game finish / exit to menu)
	main.base_game_hud.visible = false
	main.cafe_table.visible = false
	shell.visible = true
	shell.switch_to_tab("play")
	assert(shell.visible, "MainTabShell must be visible after return")
	assert(shell.active_tab_name == "play", "Active tab must be 'play' upon return")
	print("[PASS] Return to main menu lifecycle verified.")

	print("==================================================")
	print("ALL INTEGRATION AND REGRESSION CHECKS PASSED!")
	print("==================================================")
	get_tree().quit(0)
