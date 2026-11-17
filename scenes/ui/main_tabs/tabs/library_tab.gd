extends Control

## Cafe Fekr — Library Tab (Royal Persian Board-Game Encyclopedia)
## Browses all 25 board games with category filtering, instant search,
## rich thumbnails, narratives, complete rules, and gameplay instructions.

const GameRegistry = preload("res://scripts/games/game_registry.gd")

@onready var grid_container: GridContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/Scroll/GridContainer
@onready var search_input: LineEdit = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/SearchRow/SearchInput
@onready var filter_row: HBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView/FilterScroll/FilterHBox
@onready var browse_view: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/BrowseView

@onready var detail_view: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView
@onready var detail_icon: TextureRect = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/Icon
@onready var detail_title: Label = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/TextCol/Title
@onready var detail_meta: Label = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/HeaderCard/Margin/HBox/TextCol/Meta
@onready var detail_body: RichTextLabel = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/ContentScroll/Margin/BodyText
@onready var btn_tab_overview: Button = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/SubTabs/BtnOverview
@onready var btn_tab_guide: Button = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/SubTabs/BtnGuide
@onready var btn_back_library: Button = $OuterMargin/MainPanel/InnerMargin/VBox/DetailView/BtnBack

var _game_docs: Dictionary = {}
var _selected_game_id: String = ""
var _selected_doc_tab: String = "overview" # "overview" | "rules" | "guide"
var _current_filter: String = "all"
var _all_games_data: Array[Dictionary] = []

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

	KenneyUI.style_button(btn_back_library, KenneyUI.COLOR_YELLOW)
	ActionVFXManager.apply_button_juice(btn_back_library, "tap_button")
	ActionVFXManager.apply_button_juice(btn_tab_overview, "tap_button")
	ActionVFXManager.apply_button_juice(btn_tab_guide, "tap_button")

	btn_back_library.pressed.connect(func():
		AudioManager.sfx_tap()
		show_browse_view()
	)

	btn_tab_overview.pressed.connect(func():
		AudioManager.sfx_tap()
		_switch_doc_tab("overview")
	)
	btn_tab_guide.pressed.connect(func():
		AudioManager.sfx_tap()
		_switch_doc_tab("guide")
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
		var narrative = str(reg.get("narrative", ""))

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
		if cid == _current_filter:
			KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
			b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
		else:
			KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
			b.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))


func _populate_grid() -> void:
	for c in grid_container.get_children():
		c.queue_free()

	var query = search_input.text.strip_edges()

	for g in _all_games_data:
		var gid: String = g["id"]
		var name_fa: String = g["name_fa"]

		if not query.is_empty() and query not in name_fa and query not in gid:
			continue

		if _current_filter != "all":
			var allowed = CATEGORY_MAP.get(_current_filter, [])
			if gid not in allowed:
				continue

		var card = _create_game_card(g)
		grid_container.add_child(card)


func _create_game_card(g: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))

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

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

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
	var icon_path = str(g["icon"])
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.texture = CafeSocialTheme.get_game_thumb(g["id"])
	hbox.add_child(icon)

	return card


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
	detail_meta.text_direction = Control.TEXT_DIRECTION_RTL
	detail_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail_meta.text = "%s • زمان هر نوبت: %s ثانیه" % [p_str, GameManager.to_fa_num(int(reg.get("turn_time", 30)))]

	if ResourceLoader.exists(icon_path):
		detail_icon.texture = load(icon_path)
	else:
		detail_icon.texture = CafeSocialTheme.get_game_thumb(game_id)

	_switch_doc_tab("overview")


func _switch_doc_tab(t_name: String) -> void:
	_selected_doc_tab = t_name
	_style_doc_subtab(btn_tab_overview, t_name == "overview")
	_style_doc_subtab(btn_tab_guide, t_name == "guide")

	var doc_entry = _game_docs.get(_selected_game_id, {})
	var content = ""

	match t_name:
		"overview":
			content = str(doc_entry.get("overview", doc_entry.get("narrative", "")))
			if content.is_empty():
				var reg = GameRegistry.get_game_info(_selected_game_id)
				content = str(reg.get("narrative", "معرفی این بازی به زودی تکمیل خواهد شد."))
		"guide":
			content = str(doc_entry.get("gameplay", doc_entry.get("guide", "راهنما و ترفندهای پیروزی: حرکت‌های هوشمندانه و دقت در انتخاب مهره‌ها باعث پیروزی شما خواهد شد.")))

	detail_body.text_direction = Control.TEXT_DIRECTION_RTL
	var lines = content.split("\n")
	var formatted_lines: Array = []
	for l in lines:
		var trimmed = l.strip_edges()
		if trimmed.is_empty():
			formatted_lines.append("")
		else:
			formatted_lines.append("[right]%s[/right]" % trimmed)
	detail_body.text = "\n".join(formatted_lines)


func _style_doc_subtab(btn: Button, is_act: bool) -> void:
	if is_act:
		KenneyUI.style_button(btn, KenneyUI.COLOR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
	else:
		KenneyUI.style_button(btn, KenneyUI.COLOR_GREY)
		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))
