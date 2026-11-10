class_name UnoVFXLayer
extends Control

# UnoVFXLayer - Polished Card Flight Animations, Special Card Effects & Contextual Toast
# Implements Sections 6, 7 & 8 of the UNO Redesign Specification:
# - Smooth flying card animations (Hand -> Discard, Opponent -> Discard, Draw Pile -> Hand/Opponent)
# - Restrained, high-clarity Special Card Effect callouts (Reverse, Skip, +2, Wild, +4, UNO!)
# - Auto-dismissing contextual event notification pill (never permanently clutters the screen)

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

var _toast_panel: PanelContainer
var _toast_style: StyleBoxFlat
var _toast_label: Label
var _toast_tween: Tween

var _special_badge_panel: PanelContainer
var _special_badge_style: StyleBoxFlat
var _special_badge_label: Label
var _special_tween: Tween

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_overlays()

func _build_overlays() -> void:
	# 1. Contextual Auto-Dismissing Event Toast (Centered above central playing area)
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -260.0
	_toast_panel.offset_right = 260.0
	_toast_panel.offset_top = 492.0
	_toast_panel.offset_bottom = 538.0
	_toast_panel.pivot_offset = Vector2(260.0, 23.0)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false

	_toast_style = StyleBoxFlat.new()
	_toast_style.bg_color = Color(0.06, 0.10, 0.08, 0.94)
	_toast_style.border_color = Color(0.86, 0.72, 0.34, 0.88)
	_toast_style.set_border_width_all(2)
	_toast_style.set_corner_radius_all(22)
	_toast_style.shadow_color = Color(0, 0, 0, 0.45)
	_toast_style.shadow_size = 10
	_toast_style.content_margin_left = 18
	_toast_style.content_margin_right = 18
	_toast_style.content_margin_top = 6
	_toast_style.content_margin_bottom = 6
	_toast_panel.add_theme_stylebox_override("panel", _toast_style)
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_override("font", FontHekayat)
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_toast_panel.add_child(_toast_label)

	# 2. Special Card Effect Callout Badge (Appears briefly above the center piles, never covering active card)
	_special_badge_panel = PanelContainer.new()
	_special_badge_panel.set_anchors_preset(Control.PRESET_CENTER)
	_special_badge_panel.offset_left = -165.0
	_special_badge_panel.offset_right = 165.0
	_special_badge_panel.offset_top = -230.0
	_special_badge_panel.offset_bottom = -168.0
	_special_badge_panel.pivot_offset = Vector2(165.0, 31.0)
	_special_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_badge_panel.visible = false

	_special_badge_style = StyleBoxFlat.new()
	_special_badge_style.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	_special_badge_style.border_color = Color(1.0, 0.86, 0.28)
	_special_badge_style.set_border_width_all(3)
	_special_badge_style.set_corner_radius_all(28)
	_special_badge_style.shadow_color = Color(0, 0, 0, 0.55)
	_special_badge_style.shadow_size = 14
	_special_badge_style.content_margin_left = 20
	_special_badge_style.content_margin_right = 20
	_special_badge_style.content_margin_top = 8
	_special_badge_style.content_margin_bottom = 8
	_special_badge_panel.add_theme_stylebox_override("panel", _special_badge_style)
	add_child(_special_badge_panel)

	_special_badge_label = Label.new()
	_special_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_special_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_special_badge_label.add_theme_font_override("font", FontHekayat)
	_special_badge_label.add_theme_font_size_override("font_size", 31)
	_special_badge_label.add_theme_color_override("font_color", Color.WHITE)
	_special_badge_panel.add_child(_special_badge_label)

func show_contextual_toast(message: String, accent_col: Color = Color(0.86, 0.72, 0.34), duration: float = 2.1) -> void:
	if not is_instance_valid(_toast_panel):
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_label.text = message
	_toast_style.border_color = accent_col
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.scale = Vector2(0.88, 0.88)

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(_toast_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(func():
		if is_instance_valid(_toast_panel):
			_toast_panel.visible = false
	)

func play_special_effect_badge(title_text: String, badge_col: Color, duration: float = 1.45) -> void:
	if not is_instance_valid(_special_badge_panel):
		return
	if _special_tween and _special_tween.is_valid():
		_special_tween.kill()

	_special_badge_label.text = title_text
	_special_badge_style.bg_color = badge_col.darkened(0.42)
	_special_badge_style.border_color = badge_col.lightened(0.35)
	_special_badge_panel.visible = true
	_special_badge_panel.modulate.a = 0.0
	_special_badge_panel.scale = Vector2(0.55, 0.55)

	_special_tween = create_tween()
	_special_tween.tween_property(_special_badge_panel, "modulate:a", 1.0, 0.14)
	_special_tween.parallel().tween_property(_special_badge_panel, "scale", Vector2(1.08, 1.08), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_special_tween.tween_property(_special_badge_panel, "scale", Vector2.ONE, 0.10)
	_special_tween.tween_interval(duration)
	_special_tween.tween_property(_special_badge_panel, "modulate:a", 0.0, 0.22)
	_special_tween.parallel().tween_property(_special_badge_panel, "scale", Vector2(0.85, 0.85), 0.22)
	_special_tween.tween_callback(func():
		if is_instance_valid(_special_badge_panel):
			_special_badge_panel.visible = false
	)

func animate_card_flight(from_global: Vector2, to_global: Vector2, card_data: Dictionary, face_up: bool = true, duration: float = 0.28) -> void:
	var flyer = PanelContainer.new()
	flyer.custom_minimum_size = Vector2(88, 126)
	flyer.size = Vector2(88, 126)
	flyer.pivot_offset = Vector2(44, 63)
	flyer.global_position = from_global - Vector2(44, 63)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var c_col_key = String(card_data.get("color", "red"))
	var c_val_str = String(card_data.get("value", "0"))
	if c_val_str in ["wild", "wild_draw4"]:
		c_col_key = "wild"

	var st = StyleBoxFlat.new()
	st.bg_color = UnoCardWidget.UNO_COLORS.get(c_col_key, Color(0.90, 0.16, 0.19)) if face_up else Color(0.10, 0.11, 0.14)
	st.border_color = Color.WHITE
	st.set_border_width_all(4)
	st.set_corner_radius_all(14)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 10
	flyer.add_theme_stylebox_override("panel", st)

	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", 31 if face_up else 27)
	lbl.add_theme_color_override("font_color", Color.WHITE if face_up else Color(1.0, 0.86, 0.20))
	lbl.text = UnoCardWidget.format_center_symbol(c_val_str) if face_up else "UNO"
	flyer.add_child(lbl)
	add_child(flyer)

	flyer.scale = Vector2(0.85, 0.85)
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(flyer, "global_position", to_global - Vector2(44, 63), duration)
	tw.tween_property(flyer, "scale", Vector2(1.0, 1.0), duration * 0.6)
	tw.tween_property(flyer, "rotation_degrees", randf_range(-12.0, 12.0), duration)
	tw.chain().tween_callback(flyer.queue_free)

func animate_penalty_cards(from_global: Vector2, to_global: Vector2, count: int) -> void:
	var clamped = clampi(count, 1, 4)
	for i in range(clamped):
		var delay = float(i) * 0.08
		get_tree().create_timer(delay).timeout.connect(func():
			if is_inside_tree():
				animate_card_flight(from_global, to_global, {}, false, 0.28)
		)
