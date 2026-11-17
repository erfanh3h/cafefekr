extends Control

## Five-Item Antique Bottom Navigation for Cafe Fekr
## Tabs in exact order:
## 0: Social (دوستان)
## 1: History (سوابق)
## 2: Play (بازی) - Featured Center Tab & Default
## 3: Library (کتابخانه)
## 4: User (کاربر)

signal tab_selected(tab_name: String)

const TAB_NAMES = ["social", "history", "play", "library", "user"]

@onready var btn_social: Button = $PanelFrame/Margin/HBox/BtnSocial
@onready var btn_history: Button = $PanelFrame/Margin/HBox/BtnHistory
@onready var btn_play: Button = $PanelFrame/Margin/HBox/BtnPlay
@onready var btn_library: Button = $PanelFrame/Margin/HBox/BtnLibrary
@onready var btn_user: Button = $PanelFrame/Margin/HBox/BtnUser

@onready var badge_social: PanelContainer = $PanelFrame/Margin/HBox/BtnSocial/Badge
@onready var lbl_badge_social: Label = $PanelFrame/Margin/HBox/BtnSocial/Badge/LblCount

var current_tab: String = "play"
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	_tab_buttons = {
		"social": btn_social,
		"history": btn_history,
		"play": btn_play,
		"library": btn_library,
		"user": btn_user,
	}

	for t_name in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_name]
		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			_on_tab_pressed(t_name)
		)

	# Listen to social badges if available
	NetworkManager.social_notification_received.connect(func(_p): update_social_badge())
	NetworkManager.social_dm_received.connect(func(_p): update_social_badge())
	NetworkManager.social_init_received.connect(func(_p): update_social_badge())
	NetworkManager.social_badges_changed.connect(update_social_badge)

	select_tab("play", false)
	update_social_badge()


func _on_tab_pressed(tab_name: String) -> void:
	if current_tab == tab_name:
		return
	AudioManager.sfx_tap()
	select_tab(tab_name, true)


func select_tab(tab_name: String, emit_event: bool = true) -> void:
	if tab_name not in TAB_NAMES:
		return
	current_tab = tab_name

	for t_key in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_key]
		var is_sel = (t_key == current_tab)
		_style_tab_item(btn, t_key, is_sel)

	if emit_event:
		tab_selected.emit(current_tab)


func _style_tab_item(btn: Button, tab_name: String, is_selected: bool) -> void:
	var gem = btn.get_node_or_null("GemIndicator")
	var highlight = btn.get_node_or_null("GlowHighlight")
	var lbl = btn.get_node_or_null("VBox/Lbl") as Label
	var icon = btn.get_node_or_null("VBox/Icon") as TextureRect

	if is_instance_valid(gem):
		gem.visible = is_selected
	if is_instance_valid(highlight):
		highlight.visible = is_selected

	if is_instance_valid(lbl):
		if is_selected:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45, 1.0))
			lbl.add_theme_color_override("font_shadow_color", Color(0.9, 0.6, 0.1, 0.8))
			lbl.add_theme_constant_override("shadow_outline_size", 3)
		else:
			lbl.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62, 0.90))
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
			lbl.add_theme_constant_override("shadow_outline_size", 1)

	if is_instance_valid(icon):
		icon.pivot_offset = icon.custom_minimum_size / 2.0
		if is_selected:
			icon.modulate = Color(1.15, 1.10, 1.05, 1.0)
			# Animate gentle pulse
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(icon, "scale", Vector2(1.08, 1.08), 0.16)
		else:
			icon.modulate = Color(0.85, 0.82, 0.80, 0.88)
			icon.scale = Vector2(1.0, 1.0)


func update_social_badge() -> void:
	if not is_instance_valid(badge_social):
		return
	var total = NetworkManager.unread_dms_count + NetworkManager.incoming_friend_requests_count
	if total > 0:
		badge_social.visible = true
		lbl_badge_social.text = GameManager.to_fa_num(total)
	else:
		badge_social.visible = false
