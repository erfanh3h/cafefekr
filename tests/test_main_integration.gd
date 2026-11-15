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

	# 3. Test Top Utility Bar - Watch Live
	print("[TEST] Testing TopUtilityBar Watch Live...")
	var watch_received = [false]
	shell.watch_live_requested.connect(func(): watch_received[0] = true)
	shell.top_utility_bar.watch_live_requested.emit()
	assert(watch_received[0], "watch_live_pressed signal must bubble up")
	print("[PASS] TopUtilityBar Watch Live signal verified.")

	# 4. Test Top Utility Bar - Sound Settings Popup
	print("[TEST] Testing SoundSettingsPopup...")
	var sound_popup = shell.sound_settings_popup
	assert(is_instance_valid(sound_popup), "SoundSettingsPopup must exist")
	shell.top_utility_bar.sound_settings_requested.emit()
	assert(sound_popup.visible, "SoundSettingsPopup should be visible")
	sound_popup.close()
	print("[PASS] SoundSettingsPopup opened and closed successfully.")

	# 5. Test Exit Dialog
	print("[TEST] Testing ExitConfirmDialog...")
	var exit_dlg = shell.exit_confirm_dialog
	assert(is_instance_valid(exit_dlg), "ExitConfirmDialog must exist")
	shell.top_utility_bar.exit_requested.emit()
	assert(exit_dlg.visible, "ExitConfirmDialog should be visible")
	exit_dlg.close()
	print("[PASS] ExitConfirmDialog opened and closed successfully.")

	# 6. Test CompactUserHeader click -> switches to User tab
	print("[TEST] Testing Header click to User tab...")
	shell.switch_to_tab("play")
	shell.compact_user_header.header_clicked.emit()
	assert(shell.active_tab_name == "user", "Clicking header must navigate to User tab")
	print("[PASS] Header click successfully navigated to User tab.")

	# 7. Test Tab Switch Cycle
	var tab_order = ["social", "history", "play", "library", "user"]
	for t in tab_order:
		shell.switch_to_tab(t)
		assert(shell.active_tab_name == t, "Tab should switch to %s" % t)
		var instance = shell.get_active_tab_instance()
		assert(is_instance_valid(instance), "Instance for %s must be valid" % t)
		assert(instance.visible, "Tab %s must be visible" % t)
		print("[PASS] Tab '%s' verified." % t)

	# 8. Test Match Lifecycle / Return to Main Menu
	print("[TEST] Testing match start / return to menu flow...")
	# Simulate entering game mode: shell hidden, HUD shown
	shell.visible = false
	main.base_game_hud.visible = true
	main.cafe_table.visible = true
	print("[STATE] In-game state simulated (shell hidden, HUD visible).")

	# Simulate returning to main menu (e.g. game finish / exit to menu)
	main._on_leave_game_pressed()
	assert(shell.visible, "MainTabShell must be visible after returning to menu")
	assert(not main.base_game_hud.visible, "HUD must be hidden")
	assert(not main.cafe_table.visible, "Cafe table must be hidden")
	print("[PASS] Returning to main menu cleanly restores MainTabShell.")

	print("==================================================")
	print("ALL 8 VERIFICATION GATES PASSED WITH ZERO ERRORS!")
	print("==================================================")
	get_tree().quit(0)
