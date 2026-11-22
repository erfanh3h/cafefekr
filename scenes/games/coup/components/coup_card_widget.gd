class_name CoupCardWidget
extends Control

# CoupCardWidget - Royal Court Influence Card Component
# Supports two responsive layouts:
# - Compact Horizontal Shelf Mode (card_size.y <= 130): sleek bottom-dock card for 720px portrait
# - Tall Portrait Card Mode (card_size.y > 130): Spotlight Sacrifice & Ambassador Exchange modal

signal card_clicked(card_index: int, card_data: Dictionary, widget: Control)

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const ROLE_META: Dictionary = {
	"duke": {
		"name_fa": "دوک",
		"icon": "👑",
		"color": Color(0.46, 0.17, 0.70),
		"accent": Color(0.88, 0.66, 1.00),
		"ability": "مالیات +۳🪙 • دفاع: کمک",
		"ability_tall": "مالیات +۳🪙\nدفاع: کمک خارجی",
	},
	"assassin": {
		"name_fa": "آدم‌کش",
		"icon": "🗡️",
		"color": Color(0.56, 0.10, 0.18),
		"accent": Color(1.00, 0.54, 0.58),
		"ability": "ترور -۳🪙 • حذف کارت",
		"ability_tall": "ترور (-۳🪙)\nحذف کارت حریف",
	},
	"captain": {
		"name_fa": "کاپیتان",
		"icon": "⚓",
		"color": Color(0.10, 0.34, 0.72),
		"accent": Color(0.54, 0.86, 1.00),
		"ability": "سرقت +۲🪙 • دفاع: سرقت",
		"ability_tall": "سرقت +۲🪙\nدفاع: سرقت",
	},
	"ambassador": {
		"name_fa": "سفیر",
		"icon": "📜",
		"color": Color(0.11, 0.46, 0.27),
		"accent": Color(0.52, 0.96, 0.68),
		"ability": "مبادله کارت • دفاع: سرقت",
		"ability_tall": "مبادله کارت\nدفاع: سرقت",
	},
	"contessa": {
		"name_fa": "کنتس",
		"icon": "🛡️",
		"color": Color(0.66, 0.33, 0.08),
		"accent": Color(1.00, 0.80, 0.40),
		"ability": "دفاع در برابر آدم‌کش",
		"ability_tall": "دفاع در برابر\nحمله آدم‌کش",
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
	card_size: Vector2 = Vector2(150, 210)
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
		base_col = Color(0.15, 0.12, 0.12, 0.92)
		accent_col = Color(0.75, 0.34, 0.34, 0.85)

	var is_compact_horizontal: bool = (card_size.y <= 130.0)
	if is_compact_horizontal:
		custom_minimum_size = Vector2(120.0, card_size.y)

	_btn = Button.new()
	_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_selectable else Control.CURSOR_ARROW

	var is_mobile: bool = GameManager.is_mobile or OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = base_col
	_card_style.set_corner_radius_all(15 if is_compact_horizontal else 18)
	_card_style.set_border_width_all(3 if (is_selected or is_selectable) else 2)
	if is_selected:
		_card_style.border_color = Color(0.32, 0.98, 0.58)
		if not is_mobile:
			_card_style.shadow_color = Color(0.28, 0.96, 0.55, 0.65)
			_card_style.shadow_size = 10
	elif is_selectable:
		_card_style.border_color = Color(1.0, 0.86, 0.28)
		if not is_mobile:
			_card_style.shadow_color = Color(1.0, 0.82, 0.22, 0.55)
			_card_style.shadow_size = 9
	elif is_revealed:
		_card_style.border_color = Color(0.68, 0.28, 0.28, 0.80)
		if not is_mobile:
			_card_style.shadow_color = Color(0, 0, 0, 0.40)
			_card_style.shadow_size = 4
	else:
		_card_style.border_color = accent_col
		if not is_mobile:
			_card_style.shadow_color = Color(0, 0, 0, 0.45)
			_card_style.shadow_size = 6
	if not is_mobile:
		_card_style.shadow_offset = Vector2(0, 2)

	var hover_style: StyleBoxFlat = _card_style.duplicate()
	if is_selectable:
		hover_style.bg_color = base_col.lightened(0.14)
	_btn.add_theme_stylebox_override("normal", _card_style)
	_btn.add_theme_stylebox_override("hover", hover_style)
	_btn.add_theme_stylebox_override("pressed", _card_style)
	_btn.pressed.connect(func() -> void:
		if is_selectable:
			card_clicked.emit(card_index, card_data, self)
	)
	add_child(_btn)

	if is_compact_horizontal:
		_build_compact_horizontal_body(meta, base_col, accent_col)
	else:
		_build_tall_portrait_body(card_size, meta, base_col, accent_col)

func _build_compact_horizontal_body(meta: Dictionary, base_col: Color, accent_col: Color) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	# Left/Expanding Text Info (RTL right-aligned)
	var text_vb: VBoxContainer = VBoxContainer.new()
	text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vb.add_theme_constant_override("separation", 2)
	text_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vb)

	var name_lbl: Label = Label.new()
	name_lbl.text = String(meta["name_fa"]) + (" (سوخت)" if is_revealed else "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if not is_revealed else Color(0.86, 0.66, 0.66))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vb.add_child(name_lbl)

	var ab_lbl: Label = Label.new()
	ab_lbl.text = "🔥 از دست رفت" if is_revealed else String(meta["ability"])
	ab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ab_lbl.clip_text = true
	ab_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ab_lbl.add_theme_font_override("font", FontHekayat)
	ab_lbl.add_theme_font_size_override("font_size", 18)
	ab_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62) if is_revealed else Color(0.96, 0.94, 0.86, 0.94))
	ab_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.84))
	ab_lbl.add_theme_constant_override("outline_size", 2)
	ab_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vb.add_child(ab_lbl)

	# Right Crest Medallion
	var crest_box: PanelContainer = PanelContainer.new()
	crest_box.custom_minimum_size = Vector2(50, 50)
	crest_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest_st: StyleBoxFlat = StyleBoxFlat.new()
	crest_st.bg_color = base_col.darkened(0.38)
	crest_st.border_color = accent_col
	crest_st.set_border_width_all(2)
	crest_st.set_corner_radius_all(25)
	crest_box.add_theme_stylebox_override("panel", crest_st)
	hbox.add_child(crest_box)

	var icon_lbl: Label = Label.new()
	icon_lbl.text = "💀" if is_revealed else String(meta["icon"])
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 26)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_box.add_child(icon_lbl)

func _build_tall_portrait_body(card_size: Vector2, meta: Dictionary, base_col: Color, accent_col: Color) -> void:
	var is_large: bool = card_size.x >= 162.0
	var is_medium: bool = card_size.x >= 136.0

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
	var crest_sz: float = 56.0 if is_large else (48.0 if is_medium else 42.0)
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
	icon_lbl.add_theme_font_size_override("font_size", 28 if is_large else (24 if is_medium else 22))
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest_box.add_child(icon_lbl)

	# Persian Role Name
	var name_lbl: Label = Label.new()
	name_lbl.text = String(meta["name_fa"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", FontHekayat)
	name_lbl.add_theme_font_size_override("font_size", 26 if is_large else (23 if is_medium else 20))
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88) if not is_revealed else Color(0.86, 0.70, 0.70))
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Dark recessed ability box for crisp contrast
	var ability_box: PanelContainer = PanelContainer.new()
	ability_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ab_st: StyleBoxFlat = StyleBoxFlat.new()
	ab_st.bg_color = Color(0.04, 0.04, 0.06, 0.50) if not is_revealed else Color(0.28, 0.08, 0.08, 0.55)
	ab_st.set_corner_radius_all(10)
	ab_st.content_margin_left = 5
	ab_st.content_margin_right = 5
	ab_st.content_margin_top = 4
	ab_st.content_margin_bottom = 4
	ability_box.add_theme_stylebox_override("panel", ab_st)
	vbox.add_child(ability_box)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "🔥 حذف شد" if is_revealed else String(meta["ability_tall"])
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", FontHekayat)
	desc_lbl.add_theme_font_size_override("font_size", 17 if is_large else (15 if is_medium else 14))
	desc_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62) if is_revealed else Color(0.98, 0.96, 0.90))
	desc_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	desc_lbl.add_theme_constant_override("outline_size", 2)
	desc_lbl.add_theme_constant_override("line_spacing", -2)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_box.add_child(desc_lbl)

	# Selection / Action badge cleanly placed at bottom inside vbox
	if is_selected or is_selectable:
		_sel_badge = PanelContainer.new()
		_sel_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_b: StyleBoxFlat = StyleBoxFlat.new()
		sb_b.bg_color = Color(0.16, 0.72, 0.34, 0.98) if is_selected else Color(0.86, 0.22, 0.22, 0.96)
		sb_b.border_color = Color(0.98, 0.98, 0.90)
		sb_b.set_border_width_all(2)
		sb_b.set_corner_radius_all(10)
		sb_b.content_margin_left = 9
		sb_b.content_margin_right = 9
		sb_b.content_margin_top = 2
		sb_b.content_margin_bottom = 2
		_sel_badge.add_theme_stylebox_override("panel", sb_b)
		var b_lbl: Label = Label.new()
		b_lbl.text = "✓ انتخاب شد" if is_selected else "👆 انتخاب"
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 16 if is_medium else 15)
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
