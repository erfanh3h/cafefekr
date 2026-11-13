class_name CoupCardWidget
extends Control

# CoupCardWidget - Ornate Persian Royal Court Influence Card Widget
# Supports:
# - Live private player hand display (active vs revealed/lost)
# - Interactive sacrifice mode (lose_influence)
# - Interactive Ambassador Exchange selection mode

signal card_clicked(card_index: int, card_data: Dictionary, widget: Control)

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const ROLE_META: Dictionary = {
	"duke": {
		"name_fa": "دوک",
		"icon": "👑",
		"color": Color(0.46, 0.17, 0.70),
		"accent": Color(0.88, 0.66, 1.00),
		"ability": "مالیات +۳🪙\nدفاع: کمک خارجی",
	},
	"assassin": {
		"name_fa": "آدم‌کش",
		"icon": "🗡️",
		"color": Color(0.56, 0.10, 0.18),
		"accent": Color(1.00, 0.54, 0.58),
		"ability": "ترور (-۳🪙)\nحذف کارت حریف",
	},
	"captain": {
		"name_fa": "کاپیتان",
		"icon": "⚓",
		"color": Color(0.10, 0.34, 0.72),
		"accent": Color(0.54, 0.86, 1.00),
		"ability": "سرقت +۲🪙\nدفاع: سرقت",
	},
	"ambassador": {
		"name_fa": "سفیر",
		"icon": "📜",
		"color": Color(0.11, 0.46, 0.27),
		"accent": Color(0.52, 0.96, 0.68),
		"ability": "مبادله کارت\nدفاع: سرقت",
	},
	"contessa": {
		"name_fa": "کنتس",
		"icon": "🛡️",
		"color": Color(0.66, 0.33, 0.08),
		"accent": Color(1.00, 0.80, 0.40),
		"ability": "دفاع در برابر\nحمله آدم‌کش",
	},
}

var card_index: int = 0
var card_data: Dictionary = {}
var role_id: String = "duke"
var is_revealed: bool = false
var is_selectable: bool = false
var is_selected: bool = false

var _btn: Button
var _card_style: StyleBoxFlat
var _sel_badge: PanelContainer

func setup_card(
	p_index: int,
	p_data: Dictionary,
	p_selectable: bool = false,
	p_selected: bool = false,
	card_size: Vector2 = Vector2(158, 228)
) -> void:
	card_index = p_index
	card_data = p_data.duplicate(true)
	role_id = String(p_data.get("role", "duke")).to_lower()
	is_revealed = bool(p_data.get("revealed", false))
	is_selectable = p_selectable and (not is_revealed)
	is_selected = p_selected

	custom_minimum_size = card_size
	size = card_size
	_build_ui(card_size)

func _build_ui(card_size: Vector2) -> void:
	for ch: Node in get_children():
		ch.queue_free()

	var meta: Dictionary = ROLE_META.get(role_id, ROLE_META["duke"])
	var base_col: Color = meta["color"]
	var accent_col: Color = meta["accent"]
	if is_revealed:
		base_col = Color(0.16, 0.13, 0.13, 0.94)
		accent_col = Color(0.78, 0.38, 0.38, 0.88)

	var is_large: bool = card_size.x >= 166.0
	var is_medium: bool = card_size.x >= 145.0

	_btn = Button.new()
	_btn.custom_minimum_size = card_size
	_btn.size = card_size
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_selectable else Control.CURSOR_ARROW

	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = base_col
	_card_style.set_corner_radius_all(18)
	_card_style.set_border_width_all(4 if is_selected else (4 if is_selectable else 2))
	if is_selected:
		_card_style.border_color = Color(0.32, 0.98, 0.58)
		_card_style.shadow_color = Color(0.28, 0.96, 0.55, 0.70)
		_card_style.shadow_size = 16
	elif is_selectable:
		_card_style.border_color = Color(1.0, 0.86, 0.28)
		_card_style.shadow_color = Color(1.0, 0.82, 0.22, 0.58)
		_card_style.shadow_size = 14
	elif is_revealed:
		_card_style.border_color = Color(0.70, 0.30, 0.30, 0.85)
		_card_style.shadow_color = Color(0, 0, 0, 0.45)
		_card_style.shadow_size = 6
	else:
		_card_style.border_color = accent_col
		_card_style.shadow_color = Color(0, 0, 0, 0.55)
		_card_style.shadow_size = 10
	_card_style.shadow_offset = Vector2(0, 4)

	var hover_style: StyleBoxFlat = _card_style.duplicate()
	if is_selectable:
		hover_style.bg_color = base_col.lightened(0.12)
	_btn.add_theme_stylebox_override("normal", _card_style)
	_btn.add_theme_stylebox_override("hover", hover_style)
	_btn.add_theme_stylebox_override("pressed", _card_style)
	_btn.pressed.connect(func() -> void:
		if is_selectable:
			card_clicked.emit(card_index, card_data, self)
	)
	add_child(_btn)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Inner crest medallion
	var crest_sz: float = 64.0 if is_large else (58.0 if is_medium else 50.0)
	var crest_box: PanelContainer = PanelContainer.new()
	crest_box.custom_minimum_size = Vector2(crest_sz, crest_sz)
	crest_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest_st: StyleBoxFlat = StyleBoxFlat.new()
	crest_st.bg_color = base_col.darkened(0.36)
	crest_st.border_color = accent_col
	crest_st.set_border_width_all(2)
	crest_st.set_corner_radius_all(int(crest_sz * 0.5))
	crest_box.add_theme_stylebox_override("panel", crest_st)
	vbox.add_child(crest_box)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = "💀" if is_revealed else String(meta["icon"])
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 34 if is_large else (31 if is_medium else 26))
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_box.add_child(icon_lbl)

	# Persian Role Name
	var name_lbl: Label = Label.new()
	name_lbl.text = String(meta["name_fa"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 33 if is_large else (30 if is_medium else 25))
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if not is_revealed else Color(0.86, 0.70, 0.70))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Dark recessed ability box for crisp contrast
	var ability_box: PanelContainer = PanelContainer.new()
	ability_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ab_st: StyleBoxFlat = StyleBoxFlat.new()
	ab_st.bg_color = Color(0.04, 0.04, 0.06, 0.48) if not is_revealed else Color(0.28, 0.08, 0.08, 0.55)
	ab_st.set_corner_radius_all(10)
	ab_st.content_margin_left = 6
	ab_st.content_margin_right = 6
	ab_st.content_margin_top = 4
	ab_st.content_margin_bottom = 4
	ability_box.add_theme_stylebox_override("panel", ab_st)
	vbox.add_child(ability_box)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "🔥 حذف شد" if is_revealed else String(meta["ability"])
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", FontHekayat)
	desc_lbl.add_theme_font_size_override("font_size", 22 if is_large else (20 if is_medium else 18))
	desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62) if is_revealed else Color(0.98, 0.96, 0.90))
	desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	desc_lbl.add_theme_constant_override("outline_size", 2)
	desc_lbl.add_theme_constant_override("line_spacing", -2)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_box.add_child(desc_lbl)

	# Selection / Action badge cleanly placed at bottom inside vbox (never overlaps icon/name)
	if is_selected or is_selectable:
		_sel_badge = PanelContainer.new()
		_sel_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_b: StyleBoxFlat = StyleBoxFlat.new()
		sb_b.bg_color = Color(0.16, 0.72, 0.34, 0.98) if is_selected else Color(0.86, 0.22, 0.22, 0.96)
		sb_b.border_color = Color(0.98, 0.98, 0.90)
		sb_b.set_border_width_all(2)
		sb_b.set_corner_radius_all(10)
		sb_b.content_margin_left = 10
		sb_b.content_margin_right = 10
		sb_b.content_margin_top = 2
		sb_b.content_margin_bottom = 2
		_sel_badge.add_theme_stylebox_override("panel", sb_b)
		var b_lbl: Label = Label.new()
		b_lbl.text = "✓ انتخاب شد" if is_selected else "👆 لمس کنید"
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 20 if is_medium else 18)
		b_lbl.add_theme_color_override("font_color", Color.WHITE)
		b_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		b_lbl.add_theme_constant_override("outline_size", 2)
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sel_badge.add_child(b_lbl)
		vbox.add_child(_sel_badge)

static func get_role_name_fa(role: String) -> String:
	var r: String = role.to_lower()
	if ROLE_META.has(r):
		return String(ROLE_META[r]["name_fa"])
	return role

static func get_role_color(role: String) -> Color:
	var r: String = role.to_lower()
	if ROLE_META.has(r):
		return ROLE_META[r]["color"]
	return Color(0.45, 0.25, 0.65)

static func to_fa_digits(input_str: String) -> String:
	var eng: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var per: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var res: String = input_str
	for i: int in range(10):
		res = res.replace(eng[i], per[i])
	return res
