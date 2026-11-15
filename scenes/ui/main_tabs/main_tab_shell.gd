extends Control

## Cafe Fekr — Master Five-Tab Application Shell
## Integrates:
## 1. Top Utility Bar (Exit, Watch Live, Sound Settings)
## 2. Compact Persistent User Header (~110px)
## 3. Persistent 5-Tab Content Area (Social, History, Play, Library, User)
## 4. Bottom Tab Navigation (Gold/Walnut/Emerald with reactive states)
## 5. Dynamic Background Crossfading for each dedicated tab artwork

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

@onready var bg_rect: TextureRect = $BackgroundLayer/BgRect
@onready var bg_rect_fade: TextureRect = $BackgroundLayer/BgRectFade
var top_utility_bar = null
var compact_user_header = null
@onready var tab_content_container: MarginContainer = $MainVBox/TabContentContainer
@onready var bottom_navigation = $MainVBox/BottomNavigation

@onready var sound_settings_popup = $OverlayLayer/SoundSettingsPopup
@onready var exit_confirm_dialog = $OverlayLayer/ExitConfirmDialog

const BG_MAP := {
	"social": preload("res://assets/images/tabs/social_bg.jpg"),
	"history": preload("res://assets/images/tabs/history_bg.jpg"),
	"play": preload("res://assets/images/menu_bg.jpg"),
	"library": preload("res://assets/images/tabs/library_bg.jpg"),
	"user": preload("res://assets/images/tabs/user_bg.jpg")
}

const TAB_SCENES := {
	"social": preload("res://scenes/ui/main_tabs/tabs/social_tab.tscn"),
	"history": preload("res://scenes/ui/main_tabs/tabs/history_tab.tscn"),
	"play": preload("res://scenes/ui/main_tabs/tabs/play_tab.tscn"),
	"library": preload("res://scenes/ui/main_tabs/tabs/library_tab.tscn"),
	"user": preload("res://scenes/ui/main_tabs/tabs/user_tab.tscn")
}

const BG_SHADER = preload("res://scenes/ui/main_tabs/shaders/tab_bg_color_grade.gdshader")

const BG_CONFIG := {
	"play": {
		"saturation": 0.85,
		"brightness": 0.88,
		"tint": Color(0.10, 0.06, 0.03, 0.20),
		"vignette": 0.25
	},
	"social": {
		"saturation": 0.36,
		"brightness": 0.52,
		"tint": Color(0.10, 0.06, 0.03, 0.45),
		"vignette": 0.38
	},
	"history": {
		"saturation": 0.36,
		"brightness": 0.52,
		"tint": Color(0.10, 0.06, 0.03, 0.45),
		"vignette": 0.38
	},
	"library": {
		"saturation": 0.36,
		"brightness": 0.52,
		"tint": Color(0.10, 0.06, 0.03, 0.45),
		"vignette": 0.38
	},
	"user": {
		"saturation": 0.36,
		"brightness": 0.52,
		"tint": Color(0.10, 0.06, 0.03, 0.45),
		"vignette": 0.38
	}
}

var _cached_tabs: Dictionary = {}
var current_tab_name: String = ""
var active_tab_name: String:
	get: return current_tab_name
var _bg_tween: Tween = null

func _ready() -> void:
	# Wire Bottom Navigation
	bottom_navigation.tab_selected.connect(func(t_name: String):
		switch_to_tab(t_name)
	)

	# Apply initial background color grading
	_apply_bg_shader(bg_rect, BG_CONFIG["play"])
	_apply_bg_shader(bg_rect_fade, BG_CONFIG["play"])

	# Enter Play tab by default
	switch_to_tab("play")


func switch_to_tab(tab_name: String) -> void:
	if tab_name not in BG_MAP:
		tab_name = "play"

	if current_tab_name == tab_name and _cached_tabs.has(tab_name):
		return

	var old_tab_name = current_tab_name
	current_tab_name = tab_name

	# Update bottom navigation button state if needed
	if bottom_navigation.current_tab != tab_name:
		bottom_navigation.select_tab(tab_name, false)

	# 1. Smooth Background Crossfade
	_crossfade_background(BG_MAP[tab_name], tab_name)

	# 2. Swap Tab Content cleanly (preserving cached states)
	for t_key in _cached_tabs.keys():
		var node: Control = _cached_tabs[t_key]
		if is_instance_valid(node):
			node.visible = (t_key == tab_name)

	if not _cached_tabs.has(tab_name):
		var scene: PackedScene = TAB_SCENES[tab_name]
		var tab_instance: Control = scene.instantiate()
		tab_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_content_container.add_child(tab_instance)
		_cached_tabs[tab_name] = tab_instance
		_wire_tab_signals(tab_name, tab_instance)
	else:
		_cached_tabs[tab_name].visible = true

	# Trigger state refreshes where appropriate
	if tab_name == "play" and _cached_tabs.has("play"):
		_cached_tabs["play"].update_ranked_state()
	elif tab_name == "user" and _cached_tabs.has("user"):
		_cached_tabs["user"].refresh_all()


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
		"social":
			tab_inst.spectate_match_requested.connect(func(gid: String, gtype: String):
				spectate_match_requested.emit(gid, gtype)
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


func _apply_bg_shader(rect: TextureRect, cfg: Dictionary) -> void:
	if not is_instance_valid(rect):
		return
	if rect.material == null or not (rect.material is ShaderMaterial):
		var mat = ShaderMaterial.new()
		mat.shader = BG_SHADER
		rect.material = mat
	var sm = rect.material as ShaderMaterial
	sm.set_shader_parameter("saturation", cfg.get("saturation", 0.5))
	sm.set_shader_parameter("brightness", cfg.get("brightness", 0.6))
	sm.set_shader_parameter("contrast", 1.05)
	sm.set_shader_parameter("tint_color", cfg.get("tint", Color(0.1, 0.06, 0.03, 0.4)))
	sm.set_shader_parameter("vignette_strength", cfg.get("vignette", 0.35))


func _crossfade_background(target_tex: Texture2D, tab_name: String = "play") -> void:
	if not is_instance_valid(bg_rect) or not is_instance_valid(bg_rect_fade):
		return
	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()

	var cfg: Dictionary = BG_CONFIG.get(tab_name, BG_CONFIG["play"])
	_apply_bg_shader(bg_rect_fade, cfg)
	bg_rect_fade.texture = target_tex
	bg_rect_fade.modulate.a = 0.0
	bg_rect_fade.visible = true

	_bg_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_property(bg_rect_fade, "modulate:a", 1.0, 0.28)
	_bg_tween.tween_callback(func():
		bg_rect.texture = target_tex
		_apply_bg_shader(bg_rect, cfg)
		bg_rect_fade.modulate.a = 0.0
		bg_rect_fade.visible = false
	)


func update_ranked_button_state() -> void:
	if _cached_tabs.has("play") and is_instance_valid(_cached_tabs["play"]):
		_cached_tabs["play"].update_ranked_state()


func update_user_header() -> void:
	if is_instance_valid(compact_user_header):
		compact_user_header.update_ui()
	if _cached_tabs.has("user") and is_instance_valid(_cached_tabs["user"]):
		_cached_tabs["user"].refresh_all()


func open_tab(t_name: String) -> void:
	switch_to_tab(t_name)


func get_active_tab_instance() -> Control:
	return _cached_tabs.get(current_tab_name, null)
