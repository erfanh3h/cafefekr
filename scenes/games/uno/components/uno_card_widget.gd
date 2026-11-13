class_name UnoCardWidget
extends Control

# UnoCardWidget - Authentic, High-Readability Mobile UNO Card Component
# Supports:
# - Authentic UNO colors (Red, Yellow, Green, Blue, and Black for Wild / Wild +4)
# - Classic white inner oval & 4-color Wild emblem
# - Smooth raised + enlarged selection state with outline
# - Playable vs Non-Playable visual hierarchy
# - Integrated "▶ بازی" quick-confirm action pill when selected & playable

signal card_tapped(card_uid: int, card_data: Dictionary, widget: Control)
signal card_play_confirmed(card_uid: int, card_data: Dictionary, widget: Control)

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const UNO_COLORS: Dictionary = {
	"red": Color(0.90, 0.16, 0.19),
	"yellow": Color(0.95, 0.76, 0.07),
	"green": Color(0.13, 0.69, 0.31),
	"blue": Color(0.11, 0.46, 0.92),
	"wild": Color(0.10, 0.11, 0.14)
}

var card_data: Dictionary = {}
var card_uid: int = -1
var card_color: String = "red"
var card_value: String = "0"
var is_playable: bool = false
var is_selected: bool = false
var is_my_turn_active: bool = false

var _card_face: Button
var _card_style: StyleBoxFlat
var _play_badge: Button
var _status_tag: PanelContainer
var _status_label: Label
var _anim_tween: Tween

class WildColorOval extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c = size * 0.5
		var r = minf(size.x, size.y) * 0.42
		if r <= 2.0:
			return
		draw_circle(c, r + 2.5, Color.WHITE)
		var cols = [
			Color(0.90, 0.16, 0.19), # Red
			Color(0.11, 0.46, 0.92), # Blue
			Color(0.95, 0.76, 0.07), # Yellow
			Color(0.13, 0.69, 0.31)  # Green
		]
		for q in range(4):
			var a0 = float(q) * PI * 0.5
			var a1 = a0 + PI * 0.5
			var pts = PackedVector2Array([c])
			for s in range(9):
				var a = lerpf(a0, a1, float(s) / 8.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, cols[q])

func setup_card(data: Dictionary, playable: bool, selected: bool, my_turn: bool) -> void:
	card_data = data.duplicate(true)
	card_uid = int(data.get("uid", -1))
	card_color = String(data.get("color", "red"))
	card_value = String(data.get("value", "0"))
	if card_value in ["wild", "wild_draw4"]:
		card_color = "wild"
	is_playable = playable
	is_selected = selected
	is_my_turn_active = my_turn
	_build_ui()
	_apply_visual_state(false)

func _build_ui() -> void:
	for ch in get_children():
		ch.queue_free()

	custom_minimum_size = Vector2(130, 214)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Floating Action / Status Pill above raised card
	_play_badge = Button.new()
	_play_badge.custom_minimum_size = Vector2(118, 34)
	_play_badge.position = Vector2(6, 0)
	_play_badge.focus_mode = Control.FOCUS_NONE
	_play_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_badge.add_theme_font_override("font", FontHekayat)
	_play_badge.add_theme_font_size_override("font_size", 21)
	_play_badge.add_theme_color_override("font_color", Color(0.06, 0.12, 0.08))
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color(0.32, 0.96, 0.56)
	pb_style.border_color = Color.WHITE
	pb_style.set_border_width_all(2)
	pb_style.set_corner_radius_all(12)
	pb_style.shadow_color = Color(0, 0, 0, 0.45)
	pb_style.shadow_size = 6
	_play_badge.add_theme_stylebox_override("normal", pb_style)
	_play_badge.add_theme_stylebox_override("hover", pb_style)
	_play_badge.add_theme_stylebox_override("pressed", pb_style)
	_play_badge.text = "▶ بازی کن"
	_play_badge.visible = false
	_play_badge.pressed.connect(func():
		card_play_confirmed.emit(card_uid, card_data, self)
	)
	add_child(_play_badge)

	_status_tag = PanelContainer.new()
	_status_tag.custom_minimum_size = Vector2(114, 28)
	_status_tag.position = Vector2(8, 4)
	_status_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_style = StyleBoxFlat.new()
	st_style.bg_color = Color(0.14, 0.15, 0.20, 0.94)
	st_style.border_color = Color(0.95, 0.42, 0.42, 0.85)
	st_style.set_border_width_all(1)
	st_style.set_corner_radius_all(10)
	_status_tag.add_theme_stylebox_override("panel", st_style)
	_status_tag.visible = false
	add_child(_status_tag)

	_status_label = Label.new()
	_status_label.text = "غیرقابل بازی"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", FontHekayat)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72))
	_status_tag.add_child(_status_label)

	# 2. Main UNO Card Body
	_card_face = Button.new()
	_card_face.custom_minimum_size = Vector2(122, 172)
	_card_face.size = Vector2(122, 172)
	_card_face.position = Vector2(4, 38)
	_card_face.pivot_offset = Vector2(61, 86)
	_card_face.focus_mode = Control.FOCUS_NONE
	_card_face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var base_col: Color = UNO_COLORS.get(card_color, UNO_COLORS["red"])
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = base_col
	_card_style.set_corner_radius_all(18)
	_card_style.set_border_width_all(5)
	_card_style.border_color = Color(0.98, 0.98, 0.98)
	_card_style.shadow_color = Color(0, 0, 0, 0.42)
	_card_style.shadow_size = 8
	_card_style.shadow_offset = Vector2(0, 4)

	_card_face.add_theme_stylebox_override("normal", _card_style)
	_card_face.add_theme_stylebox_override("hover", _card_style)
	_card_face.add_theme_stylebox_override("pressed", _card_style)
	_card_face.pressed.connect(_on_card_face_pressed)
	add_child(_card_face)

	# Inner Card Layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_face.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Top-Left Corner Symbol
	var top_corner = Label.new()
	top_corner.text = format_corner_symbol(card_value)
	top_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_corner.add_theme_font_override("font", FontHekayat)
	top_corner.add_theme_font_size_override("font_size", 25)
	top_corner.add_theme_color_override("font_color", Color.WHITE if card_color != "yellow" else Color(0.14, 0.12, 0.05))
	top_corner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65) if card_color != "yellow" else Color(1, 1, 1, 0.4))
	top_corner.add_theme_constant_override("outline_size", 3)
	top_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_corner)

	# Center White Oval Container
	var center_oval = PanelContainer.new()
	center_oval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_oval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var oval_style = StyleBoxFlat.new()
	oval_style.bg_color = Color(0.99, 0.99, 0.99, 0.96) if card_color != "wild" else Color(0.18, 0.19, 0.24, 0.98)
	oval_style.set_corner_radius_all(36)
	oval_style.set_border_width_all(2)
	oval_style.border_color = Color(1.0, 1.0, 1.0, 0.85) if card_color == "wild" else base_col.darkened(0.15)
	center_oval.add_theme_stylebox_override("panel", oval_style)
	vbox.add_child(center_oval)

	if card_value == "wild":
		var w_oval = WildColorOval.new()
		w_oval.set_anchors_preset(Control.PRESET_FULL_RECT)
		center_oval.add_child(w_oval)
	elif card_value == "wild_draw4":
		var w_stack = Control.new()
		w_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
		w_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_oval.add_child(w_stack)
		var w_bg = WildColorOval.new()
		w_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		w_bg.modulate = Color(1, 1, 1, 0.38)
		w_stack.add_child(w_bg)
		var lbl4 = Label.new()
		lbl4.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl4.text = "+۴"
		lbl4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl4.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl4.add_theme_font_override("font", FontHekayat)
		lbl4.add_theme_font_size_override("font_size", 45)
		lbl4.add_theme_color_override("font_color", Color.WHITE)
		lbl4.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
		lbl4.add_theme_constant_override("outline_size", 6)
		w_stack.add_child(lbl4)
	else:
		var center_lbl = Label.new()
		center_lbl.text = format_center_symbol(card_value)
		center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center_lbl.add_theme_font_override("font", FontHekayat)
		center_lbl.add_theme_font_size_override("font_size", 47 if card_value.length() <= 2 else 37)
		var txt_col = base_col.darkened(0.08) if card_color != "yellow" else Color(0.78, 0.54, 0.02)
		center_lbl.add_theme_color_override("font_color", txt_col)
		center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_oval.add_child(center_lbl)

	# Bottom Subtitle / Right Corner
	var bot_row = HBoxContainer.new()
	bot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bot_row)

	var sub_lbl = Label.new()
	sub_lbl.text = format_subtitle(card_value)
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_lbl.add_theme_font_override("font", FontHekayat)
	sub_lbl.add_theme_font_size_override("font_size", 17)
	sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.92) if card_color != "yellow" else Color(0.14, 0.12, 0.05))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_row.add_child(sub_lbl)

	var bot_corner = Label.new()
	bot_corner.text = format_corner_symbol(card_value)
	bot_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bot_corner.add_theme_font_override("font", FontHekayat)
	bot_corner.add_theme_font_size_override("font_size", 21)
	bot_corner.add_theme_color_override("font_color", Color.WHITE if card_color != "yellow" else Color(0.14, 0.12, 0.05))
	bot_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_row.add_child(bot_corner)

func set_selected_state(selected: bool, animate: bool = true) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	_apply_visual_state(animate)

func _apply_visual_state(animate: bool) -> void:
	if not is_instance_valid(_card_face):
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	var target_y: float = 38.0
	var target_scale: Vector2 = Vector2.ONE
	var target_modulate: Color = Color.WHITE

	if is_selected:
		target_y = 10.0
		target_scale = Vector2(1.09, 1.09)
		_card_style.set_border_width_all(6)
		_card_style.border_color = Color(0.42, 0.98, 0.64) if is_playable else Color(1.0, 0.50, 0.50)
		_card_style.shadow_color = Color(0.32, 0.96, 0.58, 0.60) if is_playable else Color(0, 0, 0, 0.55)
		_card_style.shadow_size = 16
		_play_badge.visible = is_playable and is_my_turn_active
		_status_tag.visible = (not is_playable) and is_my_turn_active
	else:
		_play_badge.visible = false
		_status_tag.visible = false
		if is_playable and is_my_turn_active:
			target_y = 22.0
			target_scale = Vector2(1.02, 1.02)
			_card_style.set_border_width_all(6)
			_card_style.border_color = Color(1.0, 0.92, 0.36)
			_card_style.shadow_color = Color(1.0, 0.88, 0.25, 0.52)
			_card_style.shadow_size = 12
		elif is_my_turn_active:
			target_y = 44.0
			target_scale = Vector2(0.96, 0.96)
			target_modulate = Color(0.58, 0.60, 0.66, 0.90)
			_card_style.set_border_width_all(4)
			_card_style.border_color = Color(0.84, 0.84, 0.88, 0.62)
			_card_style.shadow_size = 4
		else:
			target_y = 36.0
			target_modulate = Color(0.90, 0.92, 0.94, 0.96)
			_card_style.set_border_width_all(4)
			_card_style.border_color = Color(0.96, 0.96, 0.96, 0.88)
			_card_style.shadow_size = 6

	if animate and is_inside_tree():
		_anim_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_property(_card_face, "position:y", target_y, 0.17)
		_anim_tween.tween_property(_card_face, "scale", target_scale, 0.17)
		_anim_tween.tween_property(_card_face, "modulate", target_modulate, 0.14)
	else:
		_card_face.position.y = target_y
		_card_face.scale = target_scale
		_card_face.modulate = target_modulate

func _on_card_face_pressed() -> void:
	if is_selected and is_playable and is_my_turn_active:
		card_play_confirmed.emit(card_uid, card_data, self)
	else:
		card_tapped.emit(card_uid, card_data, self)

static func format_center_symbol(value: String) -> String:
	match value:
		"skip":
			return "🚫"
		"reverse":
			return "⇄"
		"draw2":
			return "+۲"
		"wild":
			return "WILD"
		"wild_draw4":
			return "+۴"
		_:
			return to_fa_digits(value)

static func format_corner_symbol(value: String) -> String:
	match value:
		"skip":
			return "⊘"
		"reverse":
			return "⇄"
		"draw2":
			return "+۲"
		"wild":
			return "★"
		"wild_draw4":
			return "+۴"
		_:
			return to_fa_digits(value)

static func format_subtitle(value: String) -> String:
	match value:
		"skip":
			return "پرش"
		"reverse":
			return "برعکس"
		"draw2":
			return "+۲ جریمه"
		"wild":
			return "تغییر رنگ"
		"wild_draw4":
			return "آزاد +۴"
		_:
			return ""

static func to_fa_digits(input_str: String) -> String:
	var eng = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var per = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var res = input_str
	for i in range(10):
		res = res.replace(eng[i], per[i])
	return res
