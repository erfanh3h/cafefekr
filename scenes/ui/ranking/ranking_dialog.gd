extends PanelContainer

# Ranking Dialog Controller
# Mirrors RankingPage from Flutter & Social Leaderboards:
# Fetches top players (/ranking-by-score, /ranking-by-win), friends leaderboard, and clan leaderboard.

signal closed()
signal user_selected(user_data: Dictionary)

@onready var btn_tab_score: Button = $Margin/VBox/TabButtons/BtnByScore
@onready var btn_tab_win: Button = $Margin/VBox/TabButtons/BtnByWin
@onready var list_container: VBoxContainer = $Margin/VBox/Scroll/ListContainer
@onready var btn_close: Button = $Margin/VBox/BtnClose
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_loading: Label = $Margin/VBox/LblLoading

var current_tab: String = "score" # "score", "win", "friends", or "clans"
var btn_tab_friends: Button = null
var btn_tab_clans: Button = null

const _HEKAYAT_FONT = preload("res://assets/fonts/hekayat.ttf")
const _SCORE_ICON = preload("res://assets/images/badges/score.png")


func _ready() -> void:
	var tab_box: GridContainer = $Margin/VBox/TabButtons
	if is_instance_valid(tab_box):
		btn_tab_score.focus_mode = Control.FOCUS_NONE
		btn_tab_win.focus_mode = Control.FOCUS_NONE

		btn_tab_friends = Button.new()
		btn_tab_friends.text = "رتبه‌بندی دوستان"
		btn_tab_friends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tab_friends.custom_minimum_size = Vector2(0, 78)
		btn_tab_friends.add_theme_font_override("font", _HEKAYAT_FONT)
		btn_tab_friends.add_theme_font_size_override("font_size", 27)
		btn_tab_friends.focus_mode = Control.FOCUS_NONE
		btn_tab_friends.pressed.connect(func():
			AudioManager.sfx_tap()
			current_tab = "friends"
			_update_tab_styles()
			load_ranking()
		)
		tab_box.add_child(btn_tab_friends)

		btn_tab_clans = Button.new()
		btn_tab_clans.text = "کلن‌های برتر"
		btn_tab_clans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tab_clans.custom_minimum_size = Vector2(0, 78)
		btn_tab_clans.add_theme_font_override("font", _HEKAYAT_FONT)
		btn_tab_clans.add_theme_font_size_override("font_size", 27)
		btn_tab_clans.focus_mode = Control.FOCUS_NONE
		btn_tab_clans.pressed.connect(func():
			AudioManager.sfx_tap()
			current_tab = "clans"
			_update_tab_styles()
			load_ranking()
		)
		tab_box.add_child(btn_tab_clans)

	KenneyUI.style_button(btn_close, KenneyUI.COLOR_BLUE)
	_update_tab_styles()

	btn_tab_score.pressed.connect(func():
		AudioManager.sfx_tap()
		current_tab = "score"
		_update_tab_styles()
		load_ranking()
	)
	btn_tab_win.pressed.connect(func():
		AudioManager.sfx_tap()
		current_tab = "win"
		_update_tab_styles()
		load_ranking()
	)
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)


func _update_tab_styles() -> void:
	var map_btns: Dictionary = {
		"score": btn_tab_score,
		"win": btn_tab_win,
		"friends": btn_tab_friends,
		"clans": btn_tab_clans,
	}
	for k in map_btns.keys():
		var b: Button = map_btns[k]
		if not is_instance_valid(b):
			continue
		if current_tab == str(k):
			KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
			b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
		else:
			KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
			b.add_theme_color_override("font_color", Color(0.88, 0.83, 0.74, 0.90))


func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	load_ranking()


func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)


func load_ranking() -> void:
	for child in list_container.get_children():
		child.queue_free()

	lbl_loading.visible = true
	lbl_loading.text = "در حال بارگذاری رتبه‌بندی..."

	if current_tab == "score":
		NetworkManager.api.get_ranking_by_score(_on_ranking_received)
	elif current_tab == "win":
		NetworkManager.api.get_ranking_by_win(_on_ranking_received)
	elif current_tab == "friends":
		NetworkManager.api.get_social_leaderboard("friends", "", "", _on_ranking_received)
	elif current_tab == "clans":
		NetworkManager.api.get_social_leaderboard("clans", "", "", _on_ranking_received)


func _on_ranking_received(success: bool, _code: int, data: Variant) -> void:
	lbl_loading.visible = false
	if not success or typeof(data) != TYPE_DICTIONARY or not data.has("result"):
		lbl_loading.text = "خطا در دریافت اطلاعات رتبه‌بندی"
		lbl_loading.visible = true
		return

	var items: Array = data["result"] if typeof(data["result"]) == TYPE_ARRAY else []
	if items.is_empty():
		lbl_loading.text = "هنوز داده‌ای ثبت نشده است."
		lbl_loading.visible = true
		return

	var rank_idx: int = 0
	for i in range(items.size()):
		var item: Variant = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var username: String = ""
		var subtitle: String = ""
		var val_text: String = ""
		var img_id: int = 0
		var u_dict: Dictionary = {}

		if current_tab == "clans":
			var cname: String = str(d.get("name", "کلن"))
			var ctag: String = str(d.get("tag", ""))
			username = cname
			var c_score: int = int(d.get("clan_score", 0))
			var c_lvl: int = int(d.get("clan_level", 1))
			var c_mem: int = int(d.get("member_count", 1))
			subtitle = "[%s]  •  سطح %s  •  %s عضو" % [ctag, GameManager.to_fa_num(c_lvl), GameManager.to_fa_num(c_mem)] if not ctag.is_empty() else "سطح %s  •  %s عضو" % [GameManager.to_fa_num(c_lvl), GameManager.to_fa_num(c_mem)]
			val_text = GameManager.to_fa_num(c_score)
			img_id = int(d.get("emblem_id", 1))
			u_dict = d.duplicate()
		elif current_tab in ["score", "friends"]:
			var uid: String = str(d.get("_id", d.get("user_id", "")))
			if uid.begins_with("bot_") or uid.begins_with("test_bot"):
				continue
			username = str(d.get("username", "بی‌نام"))
			var raw_score: float = float(d.get("score", 0))
			val_text = GameManager.to_fa_num(int(round(raw_score)))
			img_id = int(d.get("image", 0))
			var item_xp: int = int(d.get("xp", d.get("user_xp", 0)))
			var item_lvl: int = GameManager.calculate_level(item_xp) if item_xp > 0 else int(d.get("level", 1))
			subtitle = "سطح %s" % GameManager.to_fa_num(item_lvl)
			u_dict = {
				"_id": uid,
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": int(round(raw_score)),
				"xp": item_xp,
				"level": item_lvl,
				"coin": int(d.get("coin", 0))
			}
		else:
			var u_data: Dictionary = d.get("user_data", {}) if typeof(d.get("user_data")) == TYPE_DICTIONARY else {}
			var uid: String = str(u_data.get("_id", d.get("user_id", "")))
			if uid.begins_with("bot_") or uid.begins_with("test_bot"):
				continue
			username = str(u_data.get("username", "بی‌نام"))
			var raw_win: float = float(d.get("win", 0))
			val_text = GameManager.to_fa_num(int(round(raw_win)))
			img_id = int(u_data.get("image", 0))
			var u_xp: int = int(u_data.get("xp", d.get("xp", 0)))
			var u_lvl: int = GameManager.calculate_level(u_xp) if u_xp > 0 else int(u_data.get("level", d.get("level", 1)))
			subtitle = "سطح %s" % GameManager.to_fa_num(u_lvl)
			u_dict = {
				"_id": uid,
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": int(round(float(u_data.get("score", 0)))),
				"win": int(round(raw_win)),
				"xp": u_xp,
				"level": u_lvl,
				"coin": int(u_data.get("coin", 0))
			}

		rank_idx += 1
		_create_rank_row(rank_idx, username, subtitle, val_text, img_id, u_dict)


func _create_rank_row(rank: int, username: String, subtitle: String, val_str: String, img_id: int, entry_dict: Dictionary) -> void:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 176)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.flat = false
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style_frame := CafeSocialTheme.create_frame_style(false, 54.0, 18.0)
	card.add_theme_stylebox_override("normal", style_frame)
	card.add_theme_stylebox_override("hover", style_frame)
	card.add_theme_stylebox_override("pressed", style_frame)
	card.add_theme_stylebox_override("focus", style_frame)
	card.add_theme_stylebox_override("disabled", style_frame)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 72)
	pad.add_theme_constant_override("margin_right", 72)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 22)
	card.add_child(pad)

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(row)

	# 1. Number / Rank (Far Right in RTL)
	var rank_frame := PanelContainer.new()
	rank_frame.custom_minimum_size = Vector2(68, 68)
	rank_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rf_style := StyleBoxFlat.new()
	rf_style.bg_color = Color(0.12, 0.08, 0.04, 0.88)
	rf_style.set_corner_radius_all(14)
	rank_frame.add_theme_stylebox_override("panel", rf_style)

	var rank_lbl := Label.new()
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	rank_lbl.add_theme_font_size_override("font_size", 42)
	rank_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	rank_lbl.add_theme_constant_override("shadow_outline_size", 3)
	if rank == 1:
		rank_lbl.text = "🥇"
	elif rank == 2:
		rank_lbl.text = "🥈"
	elif rank == 3:
		rank_lbl.text = "🥉"
	else:
		rank_lbl.text = GameManager.to_fa_num(rank)
		rank_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	rank_frame.add_child(rank_lbl)
	row.add_child(rank_frame)

	# 2. Avatar or Clan Emblem Plaque (Immediately to the left of Rank)
	var av_frame := PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(106, 106)
	av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(95, 95)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_frame.add_child(avatar)

	if current_tab == "clans":
		av_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		avatar.texture = CafeSocialTheme.get_clan_emblem_texture(img_id)
	else:
		var av_path: String = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(av_path):
			avatar.texture = load(av_path)
		var u_fid = GameManager.get_player_frame_id(entry_dict)
		CafeSocialTheme.apply_frame_to_container(av_frame, avatar, u_fid)
	row.add_child(av_frame)

	# 3. Name & Subtitle/Clan-Tag Column (strictly to the LEFT of avatar in RTL)
	var text_col := VBoxContainer.new()
	text_col.custom_minimum_size = Vector2(250, 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = username
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = false
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	name_lbl.add_theme_font_size_override("font_size", 40)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	name_lbl.add_theme_constant_override("shadow_outline_size", 4)
	text_col.add_child(name_lbl)

	if current_tab == "clans":
		var clan_tag: String = str(entry_dict.get("tag", ""))
		var mem_cnt: int = int(entry_dict.get("member_count", 1))
		var tag_lbl := Label.new()
		if not clan_tag.is_empty():
			if mem_cnt > 0:
				tag_lbl.text = "[%s]  •  %s عضو" % [clan_tag, GameManager.to_fa_num(mem_cnt)]
			else:
				tag_lbl.text = "[%s]" % clan_tag
		else:
			tag_lbl.text = "%s عضو" % GameManager.to_fa_num(mem_cnt)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_lbl.clip_text = false
		tag_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tag_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		tag_lbl.add_theme_font_size_override("font_size", 28)
		tag_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42, 1.0))
		tag_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		tag_lbl.add_theme_constant_override("shadow_outline_size", 3)
		text_col.add_child(tag_lbl)
	elif not subtitle.is_empty():
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_lbl.clip_text = false
		sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		sub_lbl.add_theme_font_size_override("font_size", 28)
		sub_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1.0))
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		sub_lbl.add_theme_constant_override("shadow_outline_size", 3)
		text_col.add_child(sub_lbl)

	# 4. Score or Wins Value (Far Left in RTL card)
	var val_box := HBoxContainer.new()
	val_box.alignment = BoxContainer.ALIGNMENT_CENTER
	val_box.add_theme_constant_override("separation", 6)
	val_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_box)

	if current_tab == "win":
		var val_lbl := Label.new()
		val_lbl.text = val_str
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		val_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		val_lbl.add_theme_font_size_override("font_size", 48)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38, 1.0))
		val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		val_lbl.add_theme_constant_override("shadow_outline_size", 4)
		val_box.add_child(val_lbl)
	else:
		# Score tab (and clans / friends): No icon, no shadow under text, font_size +2px (40)
		var val_lbl := Label.new()
		val_lbl.text = val_str
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		val_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		val_lbl.add_theme_font_size_override("font_size", 40)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		val_lbl.add_theme_constant_override("shadow_outline_size", 0)
		val_box.add_child(val_lbl)

	row.add_child(val_box)

	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll_node: ScrollContainer = $Margin/VBox/Scroll as ScrollContainer
	var drag_state := {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	var captured_tab: String = current_tab
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_node.scroll_vertical if is_instance_valid(scroll_node) else 0
			else:
				var was_dragging: bool = bool(drag_state["dragging"])
				var was_active: bool = bool(drag_state["active"])
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_rel: float = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_rel <= 14.0:
						AudioManager.sfx_button()
						ActionVFXManager.animate_button_pop(card)
						if captured_tab == "clans":
							var cid_tap: String = str(entry_dict.get("clan_id", entry_dict.get("_id", "")))
							CafeSocialTheme.show_clan_details_modal(self, cid_tap, entry_dict)
						else:
							user_selected.emit(entry_dict)
							var prof_dlg = get_tree().root.find_child("UserProfileDialog", true, false)
							if prof_dlg and prof_dlg.has_method("open_for_user"):
								prof_dlg.open_for_user(entry_dict, "رتبه %s کافه فکر" % GameManager.to_fa_num(rank))
		elif event is InputEventMouseMotion and bool(drag_state["active"]):
			var dy: float = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or bool(drag_state["dragging"]):
				drag_state["dragging"] = true
				if is_instance_valid(scroll_node):
					scroll_node.scroll_vertical = maxi(0, int(drag_state["start_scroll"]) - int(dy))
	)

	list_container.add_child(card)

