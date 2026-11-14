extends PanelContainer

# Ranking Dialog Controller
# Mirrors RankingPage from Flutter:
# Fetches top players from /ranking-by-score and /ranking-by-win

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

func _ready() -> void:
	var tab_box = $Margin/VBox/TabButtons
	if is_instance_valid(tab_box):
		btn_tab_friends = Button.new()
		btn_tab_friends.text = "👥 دوستان"
		btn_tab_friends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tab_friends.custom_minimum_size = btn_tab_score.custom_minimum_size
		btn_tab_friends.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		btn_tab_friends.add_theme_font_size_override("font_size", 26)
		btn_tab_friends.focus_mode = Control.FOCUS_NONE
		btn_tab_friends.pressed.connect(func():
			AudioManager.sfx_tap()
			current_tab = "friends"
			_update_tab_styles()
			load_ranking()
		)
		tab_box.add_child(btn_tab_friends)

		btn_tab_clans = Button.new()
		btn_tab_clans.text = "🛡️ کلن‌ها"
		btn_tab_clans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_tab_clans.custom_minimum_size = btn_tab_score.custom_minimum_size
		btn_tab_clans.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		btn_tab_clans.add_theme_font_size_override("font_size", 26)
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
	var map_btns = {
		"score": btn_tab_score,
		"win": btn_tab_win,
		"friends": btn_tab_friends,
		"clans": btn_tab_clans
	}
	for k in map_btns.keys():
		var b: Button = map_btns[k]
		if not is_instance_valid(b):
			continue
		if current_tab == k:
			KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
			b.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))
		else:
			KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
			b.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	load_ranking()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func load_ranking() -> void:
	# Clear list
	for child in list_container.get_children():
		child.queue_free()
	
	lbl_loading.visible = true
	lbl_loading.text = "در حال بارگذاری رتبه‌بندی..."
	
	# Do NOT disable the active button (prevents Godot from rendering it dark)
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
	
	var items: Array = data["result"]
	if items.is_empty():
		lbl_loading.text = "هنوز داده‌ای ثبت نشده است."
		lbl_loading.visible = true
		return
	
	var rank_idx = 0
	for i in range(items.size()):
		var item = items[i]
		var username = ""
		var val_text = ""
		var img_id = 0
		var u_dict = {}
		
		if current_tab == "clans":
			username = "🛡️ %s [%s]" % [str(item.get("name", "کلن")), str(item.get("tag", ""))]
			var c_score = int(item.get("clan_score", 0))
			val_text = GameManager.to_fa_num(c_score)
			img_id = int(item.get("emblem_id", 1))
			u_dict = {"_id": "", "username": username, "score": c_score, "image": img_id, "level": int(item.get("clan_level", 1))}
		elif current_tab in ["score", "friends"]:
			var uid = str(item.get("_id", item.get("user_id", "")))
			if uid.begins_with("bot_") or uid.begins_with("test_bot"):
				continue
			username = item.get("username", "بی‌نام")
			var raw_score = float(item.get("score", 0))
			val_text = GameManager.to_fa_num(int(round(raw_score)))
			img_id = int(item.get("image", 0))
			var item_xp = int(item.get("xp", item.get("user_xp", 0)))
			var item_lvl = GameManager.calculate_level(item_xp) if item_xp > 0 else int(item.get("level", 1))
			u_dict = {
				"_id": uid,
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": int(round(raw_score)),
				"xp": item_xp,
				"level": item_lvl,
				"coin": int(item.get("coin", 0))
			}
		else:
			var u_data = item.get("user_data", {})
			var uid = str(u_data.get("_id", item.get("user_id", "")))
			if uid.begins_with("bot_") or uid.begins_with("test_bot"):
				continue
			username = u_data.get("username", "بی‌نام")
			var raw_win = float(item.get("win", 0))
			val_text = GameManager.to_fa_num(int(round(raw_win)))
			img_id = int(u_data.get("image", 0))
			var u_xp = int(u_data.get("xp", item.get("xp", 0)))
			var u_lvl = GameManager.calculate_level(u_xp) if u_xp > 0 else int(u_data.get("level", item.get("level", 1)))
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
		_create_rank_row(rank_idx, username, val_text, img_id, u_dict)

func _create_rank_row(rank: int, username: String, val_str: String, img_id: int, user_dict: Dictionary) -> void:
	# Clearly separated, tactile player card
	var card = Button.new()
	# Narrower width (~700px), taller height (142px)
	card.custom_minimum_size = Vector2(700, 142)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.flat = true
	card.pivot_offset = Vector2(350, 71)
	
	# Distinct style depending on rank tier for separation and polish (smooth performance)
	var style_normal = StyleBoxFlat.new()
	style_normal.set_corner_radius_all(18)
	style_normal.content_margin_left = 24
	style_normal.content_margin_right = 24
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	style_normal.shadow_size = 2
	style_normal.shadow_offset = Vector2(0, 2)
	
	if rank == 1:
		style_normal.bg_color = Color(0.28, 0.18, 0.08, 0.95)
		style_normal.border_color = Color(1.0, 0.85, 0.25, 1.0)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(1.0, 0.82, 0.2, 0.35)
	elif rank == 2:
		style_normal.bg_color = Color(0.22, 0.17, 0.14, 0.95)
		style_normal.border_color = Color(0.88, 0.92, 0.98, 0.95)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(0.8, 0.88, 1.0, 0.25)
	elif rank == 3:
		style_normal.bg_color = Color(0.24, 0.16, 0.1, 0.95)
		style_normal.border_color = Color(0.9, 0.62, 0.38, 0.95)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(0.85, 0.55, 0.3, 0.25)
	else:
		style_normal.bg_color = Color(0.16, 0.1, 0.06, 0.9)
		style_normal.border_color = Color(0.58, 0.45, 0.3, 0.8)
		style_normal.set_border_width_all(2)
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.32, 0.22, 0.14, 0.98)
	style_hover.set_corner_radius_all(18)
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(1.0, 0.92, 0.5, 1.0)
	style_hover.shadow_color = Color(1.0, 0.85, 0.25, 0.4)
	style_hover.shadow_size = 2
	style_hover.shadow_offset = Vector2(0, 2)
	style_hover.content_margin_left = 24
	style_hover.content_margin_right = 24
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	
	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)
	
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 1. Rank Medal / Number Badge (large font 42px)
	var rank_frame = PanelContainer.new()
	rank_frame.custom_minimum_size = Vector2(72, 72)
	rank_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rf_style = StyleBoxFlat.new()
	rf_style.bg_color = Color(0.1, 0.06, 0.03, 0.75)
	rf_style.set_corner_radius_all(16)
	rank_frame.add_theme_stylebox_override("panel", rf_style)
	
	var rank_lbl = Label.new()
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	rank_lbl.add_theme_font_size_override("font_size", 42)
	if rank == 1:
		rank_lbl.text = "🥇"
	elif rank == 2:
		rank_lbl.text = "🥈"
	elif rank == 3:
		rank_lbl.text = "🥉"
	else:
		rank_lbl.text = GameManager.to_fa_num(rank)
		rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.84, 0.74))
	rank_frame.add_child(rank_lbl)
	row.add_child(rank_frame)
	
	# 2. Player Avatar (strictly square: equal width/height & square corners)
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(96, 96)
	av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_frame.clip_contents = true
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color(0.1, 0.07, 0.04, 0.9)
	f_style.set_corner_radius_all(0)
	f_style.set_border_width_all(2)
	f_style.border_color = Color(1.0, 0.82, 0.35, 0.85)
	av_frame.add_theme_stylebox_override("panel", f_style)
	
	var avatar = TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.custom_minimum_size = Vector2(92, 92)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if current_tab == "clans":
		avatar.texture = CafeSocialTheme.get_clan_emblem_texture(img_id)
	else:
		var av_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(av_path):
			avatar.texture = load(av_path)
	av_frame.add_child(avatar)
	row.add_child(av_frame)
	
	# 3. Username (increased font size: 38px)
	var name_lbl = Label.new()
	name_lbl.text = username
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_outline_size", 3)
	row.add_child(name_lbl)
	
	# 4. Score or Wins Value (NO level badge shown in either tab)
	var val_box = VBoxContainer.new()
	val_box.custom_minimum_size = Vector2(90, 0)
	val_box.add_theme_constant_override("separation", 2)
	val_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	if current_tab == "score":
		var sc_icon = TextureRect.new()
		sc_icon.texture = preload("res://assets/images/badges/score.png")
		sc_icon.custom_minimum_size = Vector2(52, 58)
		sc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sc_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sc_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sc_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		val_box.add_child(sc_icon)
		
		var val_lbl = Label.new()
		val_lbl.text = val_str
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		val_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		val_lbl.add_theme_font_size_override("font_size", 36)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		val_lbl.add_theme_constant_override("shadow_outline_size", 3)
		
		var sc_pill = StyleBoxFlat.new()
		sc_pill.bg_color = Color(0.10, 0.06, 0.03, 0.94)
		sc_pill.border_color = Color(0.85, 0.68, 0.28, 0.88)
		sc_pill.set_border_width_all(1)
		sc_pill.set_corner_radius_all(10)
		sc_pill.content_margin_left = 14
		sc_pill.content_margin_right = 14
		sc_pill.content_margin_top = 2
		sc_pill.content_margin_bottom = 2
		val_lbl.add_theme_stylebox_override("normal", sc_pill)
		val_box.add_child(val_lbl)
	else:
		# In "by win" tab: ONLY a number of wins with bigger font size must show
		var val_lbl = Label.new()
		val_lbl.text = val_str
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		val_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		val_lbl.add_theme_font_size_override("font_size", 50)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38, 1.0))
		val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		val_lbl.add_theme_constant_override("shadow_outline_size", 4)
		val_box.add_child(val_lbl)
	
	row.add_child(val_box)
	
	card.add_child(row)
	
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll_node = $Margin/VBox/Scroll as ScrollContainer
	var drag_state = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_node.scroll_vertical if is_instance_valid(scroll_node) else 0
			else:
				var was_dragging = drag_state["dragging"]
				var was_active = drag_state["active"]
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_rel = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_rel <= 14.0:
						AudioManager.sfx_button()
						ActionVFXManager.animate_button_pop(card)
						user_selected.emit(user_dict)
						var prof_dlg = get_tree().root.find_child("UserProfileDialog", true, false)
						if prof_dlg and prof_dlg.has_method("open_for_user"):
							prof_dlg.open_for_user(user_dict, "رتبه %d کافه فکر" % rank)
		elif event is InputEventMouseMotion and drag_state["active"]:
			var dy = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or drag_state["dragging"]:
				drag_state["dragging"] = true
				if is_instance_valid(scroll_node):
					scroll_node.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)
	
	list_container.add_child(card)
