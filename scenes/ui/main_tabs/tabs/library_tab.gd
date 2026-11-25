extends Control

## Cafe Fekr — Library Tab (Royal Persian Board-Game Encyclopedia)
## Browses all 25 board games with category filtering, instant search,
## rich thumbnails, narratives, complete rules, and gameplay instructions.

signal game_tutorial_requested(game_id: String)

const GameRegistry = preload("res://scripts/games/game_registry.gd")

@onready var grid_container: GridContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/Scroll/GridContainer
@onready var search_input: LineEdit = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/SearchRow/SearchInput
@onready var filter_row: HBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/FilterScroll/FilterHBox
@onready var browse_view: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView

@onready var detail_view: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView
@onready var detail_icon: TextureRect = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/Icon
@onready var detail_title: Label = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/TextCol/Title
@onready var detail_meta: Label = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/TextCol/Meta
@onready var content_scroll: ScrollContainer = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/ContentPanel/ContentScroll
@onready var content_vbox: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/ContentPanel/ContentScroll/Margin/ContentVBox
@onready var btn_back_library: TextureButton = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/BtnBack

var _game_docs: Dictionary = {}
var _selected_game_id: String = ""
var _current_filter: String = "all"
var _all_games_data: Array[Dictionary] = []
var _game_cards_built: bool = false
var _game_card_entries: Array[Dictionary] = []
var _game_icon_cache: Dictionary = {}
var _shared_card_style: StyleBoxTexture = null
var _shared_tut_btn_style: StyleBoxFlat = null
var _shared_section_style: StyleBoxFlat = null
var _tut_btn_tex: Texture2D = null
var _tut_btn_tex_loaded: bool = false

const CATEGORIES := [
	{"id": "all", "label": "همه (۲۵)"},
	{"id": "strategy", "label": "استراتژیک"},
	{"id": "classic", "label": "کلاسیک"},
	{"id": "logic", "label": "فکری و منطقی"},
	{"id": "party", "label": "دورهمی"},
	{"id": "multi", "label": "چند نفره"},
]

const CATEGORY_MAP := {
	"strategy": ["chess", "risk", "quoridor", "coup", "othello", "mill", "battleship"],
	"classic": ["backgammon", "checkers", "tictactoe", "fourinrow", "dotbox", "mill"],
	"logic": ["fekrbekr", "sudoku", "pentago", "yinsh", "msweeper", "mnumbers", "boxfour"],
	"party": ["ludo", "uno", "monopoly", "quiz", "yatzy", "rpc"],
	"multi": ["ludo", "risk", "uno", "monopoly", "coup", "quiz"]
}

func _ready() -> void:
	_load_game_docs()
	_init_games_list()
	_build_category_buttons()

	ActionVFXManager.apply_button_juice(btn_back_library, "tap_button")

	btn_back_library.pressed.connect(func():
		AudioManager.sfx_tap()
		show_browse_view()
	)

	search_input.text_changed.connect(func(_t):
		_populate_grid()
	)

	show_browse_view()


func _load_game_docs() -> void:
	var path = "res://scripts/games/game_docs.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var test_json_conv = JSON.new()
			var parse_err = test_json_conv.parse(file.get_as_text())
			if parse_err == OK and typeof(test_json_conv.data) == TYPE_DICTIONARY:
				_game_docs = test_json_conv.data


func _init_games_list() -> void:
	_all_games_data.clear()
	var keys = [
		"tictactoe", "chess", "backgammon", "checkers", "fourinrow",
		"othello", "mill", "dotbox", "pentago", "yatzy",
		"battleship", "ludo", "risk", "uno", "coup",
		"monopoly", "quiz", "sudoku", "yinsh", "quoridor",
		"rpc", "fekrbekr", "boxfour", "mnumbers", "msweeper"
	]

	for k in keys:
		var reg = GameRegistry.get_game_info(k)
		var name_fa = str(reg.get("name_fa", k))
		var icon_path = str(reg.get("icon", ""))
		var min_p = int(reg.get("min_players", 2))
		var max_p = int(reg.get("max_players", 2))
		var doc_d: Dictionary = _game_docs.get(k, {}) as Dictionary
		var narrative = str(doc_d.get("narrative", reg.get("narrative", "")))

		_all_games_data.append({
			"id": k,
			"name_fa": name_fa,
			"icon": icon_path,
			"min_players": min_p,
			"max_players": max_p,
			"narrative": narrative
		})


func _build_category_buttons() -> void:
	for c in filter_row.get_children():
		c.queue_free()

	for cat in CATEGORIES:
		var cid: String = cat["id"]
		var btn := Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(110, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(btn, "tap_button")

		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			_current_filter = cid
			_update_filter_button_styles()
			_populate_grid()
		)
		filter_row.add_child(btn)

	_update_filter_button_styles()
	_populate_grid()


func _update_filter_button_styles() -> void:
	for i in range(filter_row.get_child_count()):
		var b: Button = filter_row.get_child(i)
		var cid: String = CATEGORIES[i]["id"]
		CafeSocialTheme.style_parlor_tab_button(b, cid == _current_filter, 20)


func _get_cached_game_icon(game_id: String, icon_path: String) -> Texture2D:
	if _game_icon_cache.has(game_id):
		return _game_icon_cache[game_id] as Texture2D
	var tex: Texture2D = load(icon_path) as Texture2D if (not icon_path.is_empty() and ResourceLoader.exists(icon_path)) else CafeSocialTheme.get_game_thumb(game_id)
	_game_icon_cache[game_id] = tex
	return tex


func _ensure_grid_cards_built() -> void:
	if _game_cards_built:
		return
	for c in grid_container.get_children():
		c.queue_free()
	_game_card_entries.clear()
	for g in _all_games_data:
		var card: PanelContainer = _create_game_card(g)
		grid_container.add_child(card)
		_game_card_entries.append({
			"id": str(g["id"]),
			"name_fa": str(g["name_fa"]),
			"card": card,
			"tut_btn": card.get_meta("tut_btn", null)
		})
	_game_cards_built = true


func get_first_tutorial_button_control() -> Control:
	_ensure_grid_cards_built()
	for entry in _game_card_entries:
		var card: Control = entry.get("card") as Control
		var tb: Control = entry.get("tut_btn") as Control
		if is_instance_valid(card) and card.visible and is_instance_valid(tb) and tb.is_visible_in_tree():
			return tb
	return null


func _populate_grid() -> void:
	_ensure_grid_cards_built()

	var query: String = search_input.text.strip_edges()
	var allowed: Array = CATEGORY_MAP.get(_current_filter, []) if _current_filter != "all" else []

	for entry in _game_card_entries:
		var card: PanelContainer = entry["card"] as PanelContainer
		if not is_instance_valid(card):
			continue
		var gid: String = str(entry["id"])
		var name_fa: String = str(entry["name_fa"])
		var visible_match: bool = true
		if not query.is_empty() and query not in name_fa and query not in gid:
			visible_match = false
		elif _current_filter != "all" and gid not in allowed:
			visible_match = false
		card.visible = visible_match


func _create_game_card(g: Dictionary) -> PanelContainer:
	if _shared_card_style == null:
		_shared_card_style = CafeSocialTheme.create_item_frame_style(46.0, 14.0)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _shared_card_style)

	var has_tutorial: bool = GameTutorialRegistry.has_interactive_tutorial(g["id"])

	var click_btn := Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(click_btn, "tap_button")
	click_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		open_game_details(g["id"])
	)
	card.add_child(click_btn)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var icon_path = str(g["icon"])
	var icon_tex: Texture2D = _get_cached_game_icon(str(g["id"]), icon_path)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	if has_tutorial:
		var tut_btn := _create_tutorial_row_button(g["id"])
		hbox.add_child(tut_btn)
		card.set_meta("tut_btn", tut_btn)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(text_col)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.text = g["name_fa"]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(title_lbl)

	var p_str = "%s الی %s نفره" % [GameManager.to_fa_num(g["min_players"]), GameManager.to_fa_num(g["max_players"])] if g["min_players"] != g["max_players"] else "%s نفره" % GameManager.to_fa_num(g["min_players"])
	var meta_lbl := Label.new()
	meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	meta_lbl.add_theme_font_size_override("font_size", 17)
	meta_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_EMERALD_TEXT)
	meta_lbl.text = p_str
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(meta_lbl)

	var desc_lbl := Label.new()
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	desc_lbl.text = str(g["narrative"]).substr(0, 56) + "..."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(desc_lbl)

	# Icon
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(80, 80)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = icon_tex
	hbox.add_child(icon)

	return card


func _create_tutorial_row_button(game_id: String) -> PanelContainer:
	if _shared_tut_btn_style == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.09, 0.06, 0.92)
		sb.border_color = Color(0.78, 0.60, 0.28, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 4.0
		sb.content_margin_right = 4.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		_shared_tut_btn_style = sb
	if not _tut_btn_tex_loaded:
		_tut_btn_tex_loaded = true
		if ResourceLoader.exists("res://assets/images/game.png"):
			_tut_btn_tex = load("res://assets/images/game.png") as Texture2D

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(72, 72)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", _shared_tut_btn_style)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn, "tap_button")
	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		game_tutorial_requested.emit(game_id)
	)
	box.add_child(btn)

	var tut_icon := TextureRect.new()
	tut_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_icon.custom_minimum_size = Vector2(58, 58)
	tut_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tut_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tut_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if _tut_btn_tex != null:
		tut_icon.texture = _tut_btn_tex
	box.add_child(tut_icon)

	return box


func show_browse_view() -> void:
	browse_view.visible = true
	detail_view.visible = false


func open_game_details(game_id: String) -> void:
	_selected_game_id = game_id
	browse_view.visible = false
	detail_view.visible = true

	var reg = GameRegistry.get_game_info(game_id)
	var name_fa = str(reg.get("name_fa", game_id))
	var icon_path = str(reg.get("icon", ""))

	detail_title.text_direction = Control.TEXT_DIRECTION_RTL
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail_title.text = name_fa

	var p_str = "%s نفره" % GameManager.to_fa_num(reg.get("min_players", 2))
	if reg.get("min_players", 2) != reg.get("max_players", 2):
		p_str = "%s الی %s نفره" % [GameManager.to_fa_num(reg.get("min_players")), GameManager.to_fa_num(reg.get("max_players"))]
	var turn_sec: int = int(reg.get("turn_time", 30))
	var time_str := "%s دقیقه" % GameManager.to_fa_num(turn_sec / 60) if turn_sec >= 120 else "%s ثانیه" % GameManager.to_fa_num(turn_sec)
	var diff_fa: String = GameRegistry.get_difficulty_name_fa(game_id)
	detail_meta.text_direction = Control.TEXT_DIRECTION_RTL
	detail_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail_meta.text = "%s • سختی: %s • زمان: %s" % [p_str, diff_fa, time_str]

	detail_icon.texture = _get_cached_game_icon(game_id, icon_path)

	_render_game_guide()
	if is_instance_valid(content_scroll):
		content_scroll.scroll_vertical = 0


func _make_rtl_label(txt: String, font_res: Font, font_sz: int, col: Color, line_sp: int = 8) -> Label:
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# IMPORTANT: keep layout_direction LTR so Godot does NOT mirror HORIZONTAL_ALIGNMENT_RIGHT to the left!
	# text_direction = TEXT_DIRECTION_RTL + language = "fa" + RLM (\u200F) gives true Persian RTL flushed to right edge.
	lbl.layout_direction = Control.LAYOUT_DIRECTION_LTR
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.language = "fa"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", font_res)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("line_spacing", line_sp)
	lbl.text = "\u200F" + txt
	return lbl


func _make_section_card(title_txt: String, body_lines: Array[String]) -> PanelContainer:
	if _shared_section_style == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.09, 0.06, 0.88)
		sb.border_color = Color(0.70, 0.54, 0.28, 0.55)
		sb.set_border_width_all(1)
		sb.border_width_right = 4
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 12.0
		_shared_section_style = sb
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _shared_section_style)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	if not title_txt.is_empty():
		vb.add_child(_make_rtl_label(title_txt, CafeSocialTheme.FONT_TITLE, 22, Color(1.0, 0.86, 0.38), 4))

	if not body_lines.is_empty():
		var cleaned: Array[String] = []
		for l in body_lines:
			cleaned.append("\u200F" + l.replace("**", ""))
		var body_lbl := _make_rtl_label("", CafeSocialTheme.FONT_BODY, 18, Color(0.96, 0.93, 0.87), 9)
		body_lbl.text = "\n".join(cleaned)
		vb.add_child(body_lbl)

	return card


func _render_game_guide() -> void:
	if not is_instance_valid(content_vbox):
		return
	for ch in content_vbox.get_children():
		ch.queue_free()

	var doc_entry: Dictionary = _game_docs.get(_selected_game_id, {}) as Dictionary
	var guide_txt: String = str(doc_entry.get("guide", "")).strip_edges()
	var gameplay_txt: String = str(doc_entry.get("gameplay", "")).strip_edges()
	var parts: Array[String] = []
	if not guide_txt.is_empty():
		parts.append(guide_txt)
	if not gameplay_txt.is_empty():
		parts.append(gameplay_txt)
	var content: String = "\n\n".join(parts)
	if content.is_empty():
		content = "راهنمای کامل این بازی به زودی اضافه خواهد شد."

	var section_prefixes := ["🎯", "🧩", "📜", "📱", "💡", "🃏", "👑", "🪙", "⚡", "📊", "⚔️", "🏆"]
	var cur_title: String = ""
	var cur_lines: Array[String] = []

	for raw_l in content.split("\n"):
		var trimmed := raw_l.strip_edges()
		if trimmed.is_empty():
			continue

		var is_header := false
		for pref in section_prefixes:
			if trimmed.begins_with(pref):
				is_header = true
				break

		if is_header:
			if not cur_title.is_empty() or not cur_lines.is_empty():
				content_vbox.add_child(_make_section_card(cur_title, cur_lines))
			cur_title = trimmed.replace("**", "")
			cur_lines = []
		else:
			cur_lines.append(trimmed)

	if not cur_title.is_empty() or not cur_lines.is_empty():
		content_vbox.add_child(_make_section_card(cur_title, cur_lines))


func _style_doc_subtab(btn: Button, is_act: bool) -> void:
	CafeSocialTheme.style_parlor_tab_button(btn, is_act, 19)
