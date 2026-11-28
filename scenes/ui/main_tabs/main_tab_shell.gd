extends Control

## Cafe Fekr — Master Five-Tab Application Shell
## Integrates:
## 1. Persistent 5-Tab Content Area (Clan/اتحاد, Leaderboard/برترین‌ها, Play/بازی, Library/کتابخانه, User/کاربر)
## 2. Dedicated Top-Right Sub-Pages opened from PlayTab (Notifications, Match History, Friends)
## 3. Bottom Tab Navigation (Gold/Walnut/Emerald with reactive states)
## 4. Dynamic Background Crossfading for each dedicated tab and sub-page artwork

signal exit_requested()
signal watch_live_requested()
signal sound_settings_requested()
signal header_clicked()
signal store_requested()
signal login_requested()
signal change_username_requested()
signal phone_upgrade_requested()
signal logout_confirmed()

signal ranked_pressed()
signal multi_rank_pressed()
signal classic_rank_pressed()
signal lobby_pressed()
signal spectate_match_requested(game_id: String, game_type: String)
signal game_tutorial_requested(game_id: String)

@onready var bg_rect: TextureRect = $BackgroundLayer/BgRect
@onready var bg_rect_fade: TextureRect = $BackgroundLayer/BgRectFade
var top_utility_bar: Variant = null
var compact_user_header: Variant = null
@onready var tab_content_container: MarginContainer = $MainVBox/TabContentContainer
@onready var bottom_navigation: Control = $MainVBox/BottomNavigation

@onready var sound_settings_popup: Variant = $OverlayLayer/SoundSettingsPopup
@onready var exit_confirm_dialog: Variant = $OverlayLayer/ExitConfirmDialog

const BG_MAP: Dictionary = {
	"social": preload("res://assets/images/tabs/social_bg_graded.jpg"),
	"history": preload("res://assets/images/tabs/history_bg_graded.jpg"),
	"play": preload("res://assets/images/tabs/play_bg_graded.jpg"),
	"library": preload("res://assets/images/tabs/library_bg_graded.jpg"),
	"user": preload("res://assets/images/tabs/user_bg_graded.jpg")
}

const TAB_SCENES: Dictionary = {
	"social": preload("res://scenes/ui/main_tabs/tabs/social_tab.tscn"),
	"history": preload("res://scenes/ui/main_tabs/tabs/history_tab.tscn"),
	"play": preload("res://scenes/ui/main_tabs/tabs/play_tab.tscn"),
	"library": preload("res://scenes/ui/main_tabs/tabs/library_tab.tscn"),
	"user": preload("res://scenes/ui/main_tabs/tabs/user_tab.tscn")
}

const SUBPAGE_SCENES: Dictionary = {
	"notifications": preload("res://scenes/ui/main_tabs/pages/notifications_page.tscn"),
	"match_history": preload("res://scenes/ui/main_tabs/pages/match_history_page.tscn"),
	"friends": preload("res://scenes/ui/main_tabs/pages/friends_page.tscn")
}

const SUBPAGE_BG_KEY: Dictionary = {
	"notifications": "user",
	"match_history": "user",
	"friends": "social"
}

var _cached_tabs: Dictionary = {}
var _cached_subpages: Dictionary = {}
var current_tab_name: String = ""
var current_subpage_name: String = ""
var _subpage_return_tab: String = "play"
var active_tab_name: String:
	get: return current_tab_name
var _bg_tween: Tween = null
var _current_bg_key: String = ""
var _sparkles_node: CPUParticles2D = null
var _sparkles_paused_by_modal: bool = false


func _ready() -> void:
	bottom_navigation.tab_selected.connect(func(t_name: String):
		switch_to_tab(t_name)
	)

	bg_rect.material = null
	bg_rect_fade.material = null
	bg_rect.texture = BG_MAP["play"]
	bg_rect_fade.modulate.a = 0.0
	bg_rect_fade.visible = false
	_current_bg_key = "play"

	if has_node("BackgroundLayer/Sparkles"):
		_sparkles_node = get_node("BackgroundLayer/Sparkles") as CPUParticles2D
		if is_instance_valid(_sparkles_node) and GameManager.is_mobile:
			_sparkles_node.amount = 6
			_sparkles_node.lifetime = 3.0

	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

	if ResponsiveUI != null and not ResponsiveUI.layout_changed.is_connected(_on_responsive_layout_changed):
		ResponsiveUI.layout_changed.connect(_on_responsive_layout_changed)
	_sync_responsive_shell()

	switch_to_tab("play")


func _on_responsive_layout_changed(_metrics: Dictionary) -> void:
	_sync_responsive_shell()


func _sync_responsive_shell() -> void:
	var insets: Dictionary = ResponsiveUI.get_safe_insets() if ResponsiveUI != null else {"top": 14, "bottom": 14, "left": 12, "right": 12}
	if is_instance_valid(tab_content_container):
		var top_pad: int = maxi(0, int(insets.get("top", 14)) - 10)
		var side_pad: int = maxi(0, int(insets.get("left", 12)) - 12)
		tab_content_container.add_theme_constant_override("margin_top", top_pad)
		tab_content_container.add_theme_constant_override("margin_left", side_pad)
		tab_content_container.add_theme_constant_override("margin_right", side_pad)
	if is_instance_valid(_sparkles_node):
		var vp_sz: Vector2 = ResponsiveUI.get_viewport_size() if ResponsiveUI != null else Vector2(720, 1280)
		_sparkles_node.position = vp_sz * 0.5
		_sparkles_node.emission_rect_extents = vp_sz * 0.48


func _on_visibility_changed() -> void:
	_sync_sparkles_emitting()


func set_sparkles_paused(paused: bool) -> void:
	_sparkles_paused_by_modal = paused
	_sync_sparkles_emitting()


func _sync_sparkles_emitting() -> void:
	if is_instance_valid(_sparkles_node):
		_sparkles_node.emitting = is_visible_in_tree() and not _sparkles_paused_by_modal


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if visible and not current_subpage_name.is_empty():
			close_subpage()


func switch_to_tab(tab_name: String) -> void:
	if tab_name not in BG_MAP:
		tab_name = "play"

	var was_in_subpage: bool = not current_subpage_name.is_empty()
	if not was_in_subpage and current_tab_name == tab_name and _cached_tabs.has(tab_name):
		return

	# Close any active sub-page first
	if was_in_subpage:
		for p_key: Variant in _cached_subpages.keys():
			var p_node: Control = _cached_subpages[p_key] as Control
			if is_instance_valid(p_node):
				p_node.visible = false
		current_subpage_name = ""

	current_tab_name = tab_name

	# Update bottom navigation button state
	if bottom_navigation.current_tab != tab_name or bottom_navigation.has_subpage_open:
		bottom_navigation.select_tab(tab_name, false)

	# 1. Smooth Background Crossfade
	_crossfade_background(BG_MAP[tab_name], tab_name)

	# 2. Swap Tab Content cleanly (preserving cached states)
	for t_key: Variant in _cached_tabs.keys():
		var node: Control = _cached_tabs[t_key] as Control
		if is_instance_valid(node):
			node.visible = (str(t_key) == tab_name)

	if not _cached_tabs.has(tab_name):
		var scene: PackedScene = TAB_SCENES[tab_name] as PackedScene
		var tab_instance: Control = scene.instantiate() as Control
		tab_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_content_container.add_child(tab_instance)
		ResponsiveUI.strip_mobile_shadows(tab_instance)
		_cached_tabs[tab_name] = tab_instance
		_wire_tab_signals(tab_name, tab_instance)
	else:
		(_cached_tabs[tab_name] as Control).visible = true

	# Trigger state refreshes where appropriate
	if tab_name == "play" and _cached_tabs.has("play"):
		_cached_tabs["play"].update_ranked_state()
	elif tab_name == "user" and _cached_tabs.has("user"):
		_cached_tabs["user"].refresh_all()
	elif tab_name == "social" and _cached_tabs.has("social"):
		_cached_tabs["social"].refresh_my_clan_data(false)


func open_subpage(page_name: String) -> Control:
	if page_name not in SUBPAGE_SCENES:
		return null

	if current_subpage_name.is_empty():
		_subpage_return_tab = current_tab_name if not current_tab_name.is_empty() else "play"

	current_subpage_name = page_name
	if bottom_navigation.has_method("set_subpage_active"):
		bottom_navigation.set_subpage_active(true)

	# 1. Crossfade background to match requested artwork (Profile bg for Notifications/History, Social bg for Friends)
	var bg_key: String = str(SUBPAGE_BG_KEY.get(page_name, "user"))
	_crossfade_background(BG_MAP[bg_key], bg_key)

	# 2. Hide all main tabs and other sub-pages
	for t_key: Variant in _cached_tabs.keys():
		var t_node: Control = _cached_tabs[t_key] as Control
		if is_instance_valid(t_node):
			t_node.visible = false

	for p_key: Variant in _cached_subpages.keys():
		var p_node: Control = _cached_subpages[p_key] as Control
		if is_instance_valid(p_node):
			p_node.visible = (str(p_key) == page_name)

	# 3. Instantiate or reuse cached sub-page
	var page_inst: Control = null
	if not _cached_subpages.has(page_name):
		var scene: PackedScene = SUBPAGE_SCENES[page_name] as PackedScene
		page_inst = scene.instantiate() as Control
		page_inst.set_anchors_preset(Control.PRESET_FULL_RECT)
		page_inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_content_container.add_child(page_inst)
		ResponsiveUI.strip_mobile_shadows(page_inst)
		_cached_subpages[page_name] = page_inst
		_wire_subpage_signals(page_name, page_inst)
	else:
		page_inst = _cached_subpages[page_name] as Control
		page_inst.visible = true
		if page_inst.has_method("refresh_all"):
			page_inst.refresh_all()

	return page_inst


func close_subpage() -> void:
	if current_subpage_name.is_empty():
		return
	var target_tab: String = _subpage_return_tab if not _subpage_return_tab.is_empty() else "play"
	switch_to_tab(target_tab)


func open_direct_message_with(user_id: String, username: String) -> void:
	var friends_page: Control = open_subpage("friends")
	if is_instance_valid(friends_page) and friends_page.has_method("open_direct_message_with"):
		friends_page.open_direct_message_with(user_id, username)


func _wire_tab_signals(tab_name: String, tab_inst: Control) -> void:
	match tab_name:
		"play":
			tab_inst.ranked_pressed.connect(func(): ranked_pressed.emit())
			tab_inst.multi_rank_pressed.connect(func(): multi_rank_pressed.emit())
			tab_inst.classic_rank_pressed.connect(func(): classic_rank_pressed.emit())
			tab_inst.lobby_pressed.connect(func(): lobby_pressed.emit())
			if tab_inst.has_signal("watch_live_requested"):
				tab_inst.watch_live_requested.connect(func(): watch_live_requested.emit())
			if tab_inst.has_signal("exit_requested"):
				tab_inst.exit_requested.connect(func(): exit_confirm_dialog.open())
			if tab_inst.has_signal("notifications_page_requested"):
				tab_inst.notifications_page_requested.connect(func(): open_subpage("notifications"))
			if tab_inst.has_signal("history_page_requested"):
				tab_inst.history_page_requested.connect(func(): open_subpage("match_history"))
			if tab_inst.has_signal("friends_page_requested"):
				tab_inst.friends_page_requested.connect(func(): open_subpage("friends"))
		"social":
			tab_inst.spectate_match_requested.connect(func(gid: String, gtype: String):
				spectate_match_requested.emit(gid, gtype)
			)
			if tab_inst.has_signal("open_dm_requested"):
				tab_inst.open_dm_requested.connect(func(uid: String, uname: String):
					open_direct_message_with(uid, uname)
				)
			if tab_inst.has_signal("clan_badge_changed"):
				tab_inst.clan_badge_changed.connect(func(cnt: int):
					if bottom_navigation.has_method("set_clan_badge"):
						bottom_navigation.set_clan_badge(cnt)
				)
		"user":
			tab_inst.change_username_requested.connect(func(): change_username_requested.emit())
			tab_inst.phone_upgrade_requested.connect(func(): phone_upgrade_requested.emit())
			if tab_inst.has_signal("store_requested"):
				tab_inst.store_requested.connect(func(): store_requested.emit())
			if tab_inst.has_signal("login_requested"):
				tab_inst.login_requested.connect(func(): login_requested.emit())
			tab_inst.logout_confirmed.connect(func():
				logout_confirmed.emit()
			)
		"history":
			tab_inst.user_profile_requested.connect(func(u_dict: Dictionary):
				UserProfileDialog.show_user(u_dict, "", self)
			)
		"library":
			if tab_inst.has_signal("game_tutorial_requested"):
				tab_inst.game_tutorial_requested.connect(func(gid: String):
					game_tutorial_requested.emit(gid)
				)


func _wire_subpage_signals(_page_name: String, page_inst: Control) -> void:
	if page_inst.has_signal("back_requested"):
		page_inst.back_requested.connect(func():
			close_subpage()
		)
	if page_inst.has_signal("open_dm_requested"):
		page_inst.open_dm_requested.connect(func(uid: String, uname: String):
			open_direct_message_with(uid, uname)
		)
	if page_inst.has_signal("spectate_match_requested"):
		page_inst.spectate_match_requested.connect(func(gid: String, gtype: String):
			spectate_match_requested.emit(gid, gtype)
		)


func _crossfade_background(target_tex: Texture2D, tab_name: String = "play") -> void:
	if not is_instance_valid(bg_rect) or not is_instance_valid(bg_rect_fade):
		return
	if _current_bg_key == tab_name and bg_rect.texture == target_tex and not bg_rect_fade.visible:
		return
	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()

	_current_bg_key = tab_name
	bg_rect_fade.texture = target_tex
	bg_rect_fade.modulate.a = 0.0
	bg_rect_fade.visible = true

	_bg_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_property(bg_rect_fade, "modulate:a", 1.0, 0.28)
	_bg_tween.tween_callback(func():
		bg_rect.texture = target_tex
		bg_rect_fade.modulate.a = 0.0
		bg_rect_fade.visible = false
	)


func update_ranked_button_state() -> void:
	if _cached_tabs.has("play") and is_instance_valid(_cached_tabs["play"]):
		_cached_tabs["play"].update_ranked_state()


func update_user_header() -> void:
	if is_instance_valid(compact_user_header):
		compact_user_header.update_ui()
	if _cached_tabs.has("play") and is_instance_valid(_cached_tabs["play"]):
		_cached_tabs["play"].update_ranked_state()
	if _cached_tabs.has("user") and is_instance_valid(_cached_tabs["user"]):
		_cached_tabs["user"].refresh_all()


func open_tab(t_name: String) -> void:
	switch_to_tab(t_name)


func get_active_tab_instance() -> Control:
	if not current_subpage_name.is_empty():
		return _cached_subpages.get(current_subpage_name, null) as Control
	return _cached_tabs.get(current_tab_name, null) as Control


func get_tab_instance(tab_name: String) -> Control:
	return _cached_tabs.get(tab_name, null) as Control

