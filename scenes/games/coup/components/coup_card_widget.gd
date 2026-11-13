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
		"color": Color(0.48, 0.18, 0.72),
		"accent": Color(0.86, 0.62, 1.00),
		"ability": "مالیات +۳🪙\nدفاع: کمک خارجی",
	},
	"assassin": {
		"name_fa": "آدم‌کش",
		"icon": "🗡️",
		"color": Color(0.58, 0.10, 0.18),
		"accent": Color(1.00, 0.52, 0.56),
		"ability": "ترور (-۳🪙)\nحذف کارت حریف",
	},
	"captain": {
		"name_fa": "کاپیتان",
		"icon": "⚓",
		"color": Color(0.10, 0.36, 0.74),
		"accent": Color(0.52, 0.84, 1.00),
		"ability": "سرقت +۲🪙\nدفاع: سرقت",
	},
	"ambassador": {
		"name_fa": "سفیر",
		"icon": "📜",
		"color": Color(0.11, 0.48, 0.28),
		"accent": Color(0.50, 0.96, 0.66),
		"ability": "مبادله کارت\nدفاع: سرقت",
	},
	"contessa": {
		"name_fa": "کنتس",
		"icon": "🛡️",
		"color": Color(0.68, 0.34, 0.08),
		"accent": Color(1.00, 0.78, 0.38),
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
	card_size: Vector2 = Vector2(126, 174)
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
		base_col = Color(0.18, 0.14, 0.14, 0.92)
		accent_col = Color(0.75, 0.38, 0.38, 0.85)

	_btn = Button.new()
	_btn.custom_minimum_size = card_size
	_btn.size = card_size
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_selectable else Control.CURSOR_ARROW

	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = base_col
	_card_style.set_corner_radius_all(16)
	_card_style.set_border_width_all(4 if is_selected else (3 if is_selectable else 2))
	if is_selected:
		_card_style.border_color = Color(0.32, 0.98, 0.58)
		_card_style.shadow_color = Color(0.28, 0.96, 0.55, 0.65)
		_card_style.shadow_size = 14
	elif is_selectable:
		_card_style.border_color = Color(1.0, 0.86, 0.28)
		_card_style.shadow_color = Color(1.0, 0.82, 0.22, 0.52)
		_card_style.shadow_size = 12
	elif is_revealed:
		_card_style.border_color = Color(0.65, 0.28, 0.28, 0.80)
		_card_style.shadow_color = Color(0, 0, 0, 0.45)
		_card_style.shadow_size = 5
	else:
		_card_style.border_color = Color(0.92, 0.78, 0.40, 0.92)
		_card_style.shadow_color = Color(0, 0, 0, 0.50)
		_card_style.shadow_size = 8
	_card_style.shadow_offset = Vector2(0, 4)

	var hover_style: StyleBoxFlat = _card_style.duplicate()
	if is_selectable:
		hover_style.bg_color = base_col.lightened(0.10)
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
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Inner crest medallion
	var crest_box: PanelContainer = PanelContainer.new()
	crest_box.custom_minimum_size = Vector2(54, 54)
	crest_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest_st: StyleBoxFlat = StyleBoxFlat.new()
	crest_st.bg_color = base_col.darkened(0.32)
	crest_st.border_color = accent_col
	crest_st.set_border_width_all(2)
	crest_st.set_corner_radius_all(27)
	crest_box.add_theme_stylebox_override("panel", crest_st)
	vbox.add_child(crest_box)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = "💀" if is_revealed else String(meta["icon"])
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_box.add_child(icon_lbl)

	# Persian Role Name
	var name_lbl: Label = Label.new()
	name_lbl.text = String(meta["name_fa"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 25 if card_size.x >= 120.0 else 22)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86) if not is_revealed else Color(0.82, 0.68, 0.68))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Ability summary or Revealed status
	var desc_lbl: Label = Label.new()
	desc_lbl.text = "🔥 حذف شد" if is_revealed else String(meta["ability"])
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", FontHekayat)
	desc_lbl.add_theme_font_size_override("font_size", 16 if card_size.x >= 120.0 else 15)
	desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.56, 0.56) if is_revealed else Color(0.95, 0.94, 0.88, 0.92))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	# Selection / Action badge
	if is_selected or is_selectable:
		_sel_badge = PanelContainer.new()
		_sel_badge.position = Vector2(6, 6)
		_sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_b: StyleBoxFlat = StyleBoxFlat.new()
		sb_b.bg_color = Color(0.18, 0.76, 0.36, 0.96) if is_selected else Color(0.86, 0.24, 0.24, 0.92)
		sb_b.border_color = Color.WHITE
		sb_b.set_border_width_all(1)
		sb_b.set_corner_radius_all(8)
		sb_b.content_margin_left = 6
		sb_b.content_margin_right = 6
		sb_b.content_margin_top = 1
		sb_b.content_margin_bottom = 1
		_sel_badge.add_theme_stylebox_override("panel", sb_b)
		var b_lbl: Label = Label.new()
		b_lbl.text = "✓ انتخاب" if is_selected else "لمس کنید"
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 15)
		b_lbl.add_theme_color_override("font_color", Color.WHITE)
		_sel_badge.add_child(b_lbl)
		add_child(_sel_badge)

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
