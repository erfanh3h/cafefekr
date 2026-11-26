extends Control

## Five-Item Antique Bottom Navigation for Cafe Fekr
## Tabs in exact order:
## 0: Social / Clan (اتحاد)
## 1: History / Leaderboard (برترین‌ها)
## 2: Play (بازی) - Center Tab & Default
## 3: Library (کتابخانه)
## 4: User (کاربر)

signal tab_selected(tab_name: String)

const TAB_NAMES: Array[String] = ["social", "history", "play", "library", "user"]
const COL_LABEL_ACTIVE: Color = Color("#FFD86B")
const COL_LABEL_INACTIVE: Color = Color("#BCA98E")

@onready var btn_social: Button = $PanelFrame/Margin/HBox/BtnSocial
@onready var btn_history: Button = $PanelFrame/Margin/HBox/BtnHistory
@onready var btn_play: Button = $PanelFrame/Margin/HBox/BtnPlay
@onready var btn_library: Button = $PanelFrame/Margin/HBox/BtnLibrary
@onready var btn_user: Button = $PanelFrame/Margin/HBox/BtnUser

@onready var badge_social: PanelContainer = $PanelFrame/Margin/HBox/BtnSocial/Badge
@onready var lbl_badge_social: Label = $PanelFrame/Margin/HBox/BtnSocial/Badge/LblCount

var current_tab: String = "play"
var has_subpage_open: bool = false
var _clan_badge_count: int = 0
var _tab_buttons: Dictionary = {}
var _tab_tweens: Dictionary = {}


func _ready() -> void:
	_tab_buttons = {
		"social": btn_social,
		"history": btn_history,
		"play": btn_play,
		"library": btn_library,
		"user": btn_user,
	}

	for t_name: Variant in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_name] as Button
		ActionVFXManager.apply_button_juice(btn, "tap_button")
		var captured_name: String = str(t_name)
		btn.pressed.connect(func():
			_on_tab_pressed(captured_name)
		)

	select_tab("play", false)
	update_social_badge()
	if ResponsiveUI != null and not ResponsiveUI.layout_changed.is_connected(_on_responsive_layout_changed):
		ResponsiveUI.layout_changed.connect(_on_responsive_layout_changed)
	resized.connect(_sync_responsive_nav)
	call_deferred("_sync_responsive_nav")


func _on_responsive_layout_changed(_metrics: Dictionary) -> void:
	_sync_responsive_nav()


func _sync_responsive_nav() -> void:
	var is_short: bool = UITypography.is_short_height()
	var insets: Dictionary = ResponsiveUI.get_safe_insets() if ResponsiveUI != null else {"bottom": 14}
	var extra_bottom: float = maxf(0.0, float(int(insets.get("bottom", 14)) - 14) * 0.45)
	custom_minimum_size.y = (148.0 if is_short else 164.0) + extra_bottom

	var tab_w: float = (size.x - 64.0) / maxf(1.0, float(_tab_buttons.size()))
	for t_key: Variant in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_key] as Button
		if not is_instance_valid(btn):
			continue
		var lbl: Label = btn.get_node_or_null("VBox/Lbl") as Label
		if is_instance_valid(lbl):
			ResponsiveUI.apply_text(lbl, UITypography.Role.TITLE_SM, {"min_px": 16, "max_px": 25})
			if tab_w > 40.0:
				UITypography.fit_label_to_width(lbl, tab_w - 8.0, 23, 16)
	if is_instance_valid(lbl_badge_social):
		ResponsiveUI.apply_text(lbl_badge_social, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 20})


func _on_tab_pressed(tab_name: String) -> void:
	if current_tab == tab_name and not has_subpage_open:
		return
	AudioManager.sfx_tap()
	select_tab(tab_name, true)


func select_tab(tab_name: String, emit_event: bool = true) -> void:
	if tab_name not in TAB_NAMES:
		return
	has_subpage_open = false
	current_tab = tab_name

	for t_key: Variant in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_key] as Button
		var is_sel: bool = (str(t_key) == current_tab)
		_style_tab_item(btn, str(t_key), is_sel)

	if emit_event:
		tab_selected.emit(current_tab)


func set_subpage_active(active: bool) -> void:
	has_subpage_open = active
	for t_key: Variant in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t_key] as Button
		var is_sel: bool = (not active) and (str(t_key) == current_tab)
		_style_tab_item(btn, str(t_key), is_sel)


func set_clan_badge(count: int) -> void:
	_clan_badge_count = max(0, count)
	update_social_badge()


func _style_tab_item(btn: Button, tab_name: String, is_selected: bool) -> void:
	if not is_instance_valid(btn):
		return

	var gem: Control = btn.get_node_or_null("GemIndicator") as Control
	var highlight: Control = btn.get_node_or_null("GlowHighlight") as Control
	var lbl: Label = btn.get_node_or_null("VBox/Lbl") as Label
	var icon: TextureRect = btn.get_node_or_null("VBox/IconSlot/Icon") as TextureRect
	if icon == null:
		icon = btn.get_node_or_null("VBox/Icon") as TextureRect

	if _tab_tweens.has(tab_name):
		var old_tw: Tween = _tab_tweens[tab_name] as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()

	if is_instance_valid(gem):
		gem.visible = is_selected

	if is_instance_valid(highlight):
		highlight.visible = is_selected
		highlight.modulate.a = 0.0

	if is_instance_valid(lbl):
		if is_selected:
			lbl.add_theme_color_override("font_color", COL_LABEL_ACTIVE)
			lbl.add_theme_color_override("font_shadow_color", Color(0.12, 0.05, 0.01, 0.96))
			lbl.add_theme_constant_override("shadow_offset_x", 0)
			lbl.add_theme_constant_override("shadow_offset_y", 2)
			lbl.add_theme_constant_override("shadow_outline_size", 2)
		else:
			lbl.add_theme_color_override("font_color", COL_LABEL_INACTIVE)
			lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
			lbl.add_theme_constant_override("shadow_offset_x", 0)
			lbl.add_theme_constant_override("shadow_offset_y", 1)
			lbl.add_theme_constant_override("shadow_outline_size", 1)

	if is_instance_valid(icon):
		icon.pivot_offset = icon.custom_minimum_size * 0.5
		if is_inside_tree():
			var tw: Tween = create_tween().set_parallel(true)
			_tab_tweens[tab_name] = tw
			if is_selected:
				tw.tween_property(icon, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(icon, "modulate", Color(1.08, 1.05, 0.98, 1.0), 0.16)
				if is_instance_valid(highlight):
					tw.tween_property(highlight, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			else:
				tw.tween_property(icon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 0.8), 0.14)
		else:
			if is_selected:
				icon.scale = Vector2(1.12, 1.12)
				icon.modulate = Color(1.08, 1.05, 0.98, 1.0)
				if is_instance_valid(highlight):
					highlight.modulate.a = 1.0
			else:
				icon.scale = Vector2.ONE
				icon.modulate = Color(1.0, 1.0, 1.0, 0.8)


func update_social_badge() -> void:
	if not is_instance_valid(badge_social):
		return
	if _clan_badge_count > 0:
		badge_social.visible = true
		lbl_badge_social.text = "۹۹+" if _clan_badge_count > 99 else GameManager.to_fa_num(_clan_badge_count)
	else:
		badge_social.visible = false
