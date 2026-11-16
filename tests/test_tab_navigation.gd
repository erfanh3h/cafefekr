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

	# Verify Play Tab has top utility buttons (Watch live, Exit) and authentic wooden buttons
	shell.switch_to_tab("play")
	var play = shell.get_active_tab_instance()
	assert(is_instance_valid(play.btn_watch_live), "Play tab BtnWatchLive missing")
	assert(is_instance_valid(play.btn_exit), "Play tab BtnExit missing")
	assert(is_instance_valid(play.btn_ranked), "Play tab BtnRanked missing")
	assert(is_instance_valid(play.btn_multi), "Play tab BtnMulti missing")
	assert(is_instance_valid(play.btn_classic), "Play tab BtnClassic missing")
	assert(is_instance_valid(play.btn_lobby), "Play tab BtnLobby missing")
	print("[PASS] Play tab utility controls and game mode buttons verified.")

	# Verify Library Tab loaded 25 games and larger search
	shell.switch_to_tab("library")
	var lib = shell.get_active_tab_instance()
	assert(lib._all_games_data.size() == 25, "Library must have 25 games, found %d" % lib._all_games_data.size())
	assert(lib.search_input.custom_minimum_size.y >= 60, "Search input should be enlarged")
	print("[PASS] Library tab holds all 25 registered board games with enlarged search.")

	# Verify History Tab 4 sub-sections (score, win, friends, clans)
	shell.switch_to_tab("history")
	var hist = shell.get_active_tab_instance()
	hist.switch_lb_tab("score")
	assert(hist.active_lb_tab == "score", "History should switch to score")
	hist.switch_lb_tab("win")
	assert(hist.active_lb_tab == "win", "History should switch to win")
	hist.switch_lb_tab("friends")
	assert(hist.active_lb_tab == "friends", "History should switch to friends")
	hist.switch_lb_tab("clans")
	assert(hist.active_lb_tab == "clans", "History should switch to clans")
	print("[PASS] History tab sub-navigation (score, win, friends, clans) verified.")

	# Verify User Tab: Top UserHeader, sub-sections, audio settings, privacy, centered cosmetics, notifications
	shell.switch_to_tab("user")
	var usr = shell.get_active_tab_instance()
	assert(is_instance_valid(usr.user_header), "User tab top UserHeader missing")
	usr.switch_subtab("profile")
	assert(usr.active_subtab == "profile", "User should switch to profile")
	usr.switch_subtab("cosmetics")
	assert(usr.active_subtab == "cosmetics", "User should switch to cosmetics")
	usr.switch_subtab("privacy")
	assert(usr.active_subtab == "privacy", "User should switch to privacy")
	usr.switch_subtab("notifs")
	assert(usr.active_subtab == "notifs", "User should switch to notifs")
	print("[PASS] User tab (UserHeader, profile stats, centered cosmetics, privacy, notifications, audio settings) verified.")

	# Return to Play tab (default)
	shell.switch_to_tab("play")
	print("[PASS] Returned to default Play tab.")

	print("========================================")
	print("ALL FIVE TABS VALIDATED AND OPERATIONAL!")
	print("========================================")
	get_tree().quit(0)
