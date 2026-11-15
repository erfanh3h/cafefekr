extends Node

func _ready() -> void:
	print("========================================")
	print("--- CAFE FEKR FIVE-TAB REDESIGN TEST ---")
	print("========================================")

	# Verify autoloads
	print("[CHECK] GameManager exists: ", GameManager != null)
	print("[CHECK] AudioManager exists: ", AudioManager != null)
	print("[CHECK] ActionVFXManager exists: ", ActionVFXManager != null)

	var shell_scene = load("res://scenes/ui/main_tabs/main_tab_shell.tscn")
	if not shell_scene:
		print("FAILED: Could not load main_tab_shell.tscn")
		get_tree().quit(1)
		return

	var shell = shell_scene.instantiate()
	add_child(shell)
	print("[PASS] MainTabShell instantiated successfully.")

	# Verify Top Utility Bar
	assert(is_instance_valid(shell.top_utility_bar), "TopUtilityBar missing")
	print("[PASS] TopUtilityBar is valid.")

	# Verify Compact User Header
	assert(is_instance_valid(shell.compact_user_header), "CompactUserHeader missing")
	shell.compact_user_header.update_ui()
	print("[PASS] CompactUserHeader is valid and update_ui() succeeded.")

	# Verify Bottom Navigation
	assert(is_instance_valid(shell.bottom_navigation), "BottomNavigation missing")
	print("[PASS] BottomNavigation is valid.")

	# Test switching to all 5 tabs
	var tabs = ["social", "history", "play", "library", "user"]
	for t in tabs:
		shell.switch_to_tab(t)
		var act = shell.get_active_tab_instance()
		assert(is_instance_valid(act), "Tab instance for %s is null" % t)
		assert(act.visible, "Tab %s should be visible" % t)
		print("[PASS] Tab '%s' activated and verified." % t)

	# Verify Library Tab loaded 25 games
	shell.switch_to_tab("library")
	var lib = shell.get_active_tab_instance()
	assert(lib._all_games_data.size() == 25, "Library must have 25 games, found %d" % lib._all_games_data.size())
	print("[PASS] Library tab holds all 25 registered board games.")

	# Verify History Tab sub-sections
	shell.switch_to_tab("history")
	var hist = shell.get_active_tab_instance()
	hist.switch_section("stats")
	assert(hist.active_section == "stats", "History should switch to stats")
	hist.switch_section("leaderboard")
	assert(hist.active_section == "leaderboard", "History should switch to leaderboard")
	print("[PASS] History tab sub-navigation verified.")

	# Verify User Tab sub-sections
	shell.switch_to_tab("user")
	var usr = shell.get_active_tab_instance()
	usr.switch_subtab("cosmetics")
	assert(usr.active_subtab == "cosmetics", "User should switch to cosmetics")
	usr.switch_subtab("privacy")
	assert(usr.active_subtab == "privacy", "User should switch to privacy")
	usr.switch_subtab("wallet")
	assert(usr.active_subtab == "wallet", "User should switch to wallet")
	usr.switch_subtab("account")
	assert(usr.active_subtab == "account", "User should switch to account")
	print("[PASS] User tab sub-navigation verified.")

	# Return to Play tab (default)
	shell.switch_to_tab("play")
	var play = shell.get_active_tab_instance()
	assert(is_instance_valid(play), "Play tab valid")
	print("[PASS] Returned to Play tab.")

	print("========================================")
	print("ALL FIVE TABS VALIDATED AND OPERATIONAL!")
	print("========================================")
	get_tree().quit(0)
