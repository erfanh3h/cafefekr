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

var current_tab: String = "score" # "score" or "win"

func _ready() -> void:
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
	# Active tab must be light (Kenney Yellow) and inactive tab dark (Kenney Grey)
	if current_tab == "score":
		KenneyUI.style_button(btn_tab_score, KenneyUI.COLOR_YELLOW)
		btn_tab_score.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))
		KenneyUI.style_button(btn_tab_win, KenneyUI.COLOR_GREY)
		btn_tab_win.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	else:
		KenneyUI.style_button(btn_tab_score, KenneyUI.COLOR_GREY)
		btn_tab_score.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
		KenneyUI.style_button(btn_tab_win, KenneyUI.COLOR_YELLOW)
		btn_tab_win.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))

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
	else:
		NetworkManager.api.get_ranking_by_win(_on_ranking_received)

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
	
	for i in range(items.size()):
		var item = items[i]
		var username = ""
		var val_text = ""
		var img_id = 0
		var u_dict = {}
		
		if current_tab == "score":
			username = item.get("username", "بی‌نام")
			var raw_score = float(item.get("score", 0))
			val_text = "%d امتیاز" % int(round(raw_score))
			img_id = int(item.get("image", 0))
			u_dict = {
				"_id": str(item.get("_id", item.get("user_id", ""))),
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": int(round(raw_score)),
				"level": int(item.get("level", 1)),
				"coin": int(item.get("coin", 0))
			}
		else:
			var u_data = item.get("user_data", {})
			username = u_data.get("username", "بی‌نام")
			var raw_win = float(item.get("win", 0))
			val_text = "%d برد" % int(round(raw_win))
			img_id = int(u_data.get("image", 0))
			u_dict = {
				"_id": str(u_data.get("_id", item.get("user_id", ""))),
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": int(round(float(u_data.get("score", 0)))),
				"win": int(round(raw_win)),
				"level": int(u_data.get("level", 1)),
				"coin": int(u_data.get("coin", 0))
			}
		
		_create_rank_row(i + 1, username, val_text, img_id, u_dict)

func _create_rank_row(rank: int, username: String, val_str: String, img_id: int, user_dict: Dictionary) -> void:
	# Clearly separated, tactile player card
	var card = Button.new()
	card.custom_minimum_size = Vector2(0, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.flat = true
	card.pivot_offset = Vector2(400, 50)
	
	# Distinct style depending on rank tier for separation and polish
	var style_normal = StyleBoxFlat.new()
	style_normal.set_corner_radius_all(18)
	style_normal.content_margin_left = 22
	style_normal.content_margin_right = 22
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10
	
	if rank == 1:
		style_normal.bg_color = Color(0.28, 0.18, 0.08, 0.95)
		style_normal.border_color = Color(1.0, 0.85, 0.25, 1.0)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(1.0, 0.82, 0.2, 0.35)
		style_normal.shadow_size = 10
	elif rank == 2:
		style_normal.bg_color = Color(0.22, 0.17, 0.14, 0.95)
		style_normal.border_color = Color(0.88, 0.92, 0.98, 0.95)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(0.8, 0.88, 1.0, 0.25)
		style_normal.shadow_size = 8
	elif rank == 3:
		style_normal.bg_color = Color(0.24, 0.16, 0.1, 0.95)
		style_normal.border_color = Color(0.9, 0.62, 0.38, 0.95)
		style_normal.set_border_width_all(3)
		style_normal.shadow_color = Color(0.85, 0.55, 0.3, 0.25)
		style_normal.shadow_size = 7
	else:
		style_normal.bg_color = Color(0.16, 0.1, 0.06, 0.9)
		style_normal.border_color = Color(0.58, 0.45, 0.3, 0.8)
		style_normal.set_border_width_all(2)
		style_normal.shadow_color = Color(0, 0, 0, 0.5)
		style_normal.shadow_size = 6
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.32, 0.22, 0.14, 0.98)
	style_hover.set_corner_radius_all(18)
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(1.0, 0.92, 0.5, 1.0)
	style_hover.shadow_color = Color(1.0, 0.85, 0.25, 0.4)
	style_hover.shadow_size = 12
	style_hover.shadow_offset = Vector2(0, 5)
	style_hover.content_margin_left = 22
	style_hover.content_margin_right = 22
	style_hover.content_margin_top = 10
	style_hover.content_margin_bottom = 10
	
	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)
	
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 1. Rank Medal / Number Badge (large)
	var rank_frame = PanelContainer.new()
	rank_frame.custom_minimum_size = Vector2(60, 60)
	rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rf_style = StyleBoxFlat.new()
	rf_style.bg_color = Color(0.1, 0.06, 0.03, 0.75)
	rf_style.set_corner_radius_all(14)
	rank_frame.add_theme_stylebox_override("panel", rf_style)
	
	var rank_lbl = Label.new()
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	rank_lbl.add_theme_font_size_override("font_size", 34)
	if rank == 1:
		rank_lbl.text = "🥇"
	elif rank == 2:
		rank_lbl.text = "🥈"
	elif rank == 3:
		rank_lbl.text = "🥉"
	else:
		rank_lbl.text = str(rank)
		rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.84, 0.74))
	rank_frame.add_child(rank_lbl)
	row.add_child(rank_frame)
	
	# 2. Player Avatar (large 76x76 with rounded frame)
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(76, 76)
	av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color(0.1, 0.07, 0.04, 0.9)
	f_style.set_corner_radius_all(14)
	f_style.set_border_width_all(2)
	f_style.border_color = Color(1.0, 0.82, 0.35, 0.85)
	av_frame.add_theme_stylebox_override("panel", f_style)
	
	var avatar = TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av_path = "res://assets/icons/Avatars/%d.png" % img_id
	if ResourceLoader.exists(av_path):
		avatar.texture = load(av_path)
	av_frame.add_child(avatar)
	row.add_child(av_frame)
	
	# 3. Username (large font 32px)
	var name_lbl = Label.new()
	name_lbl.text = username
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_outline_size", 3)
	row.add_child(name_lbl)
	
	# 4. Score / Wins Value (large font 32px)
	var val_lbl = Label.new()
	val_lbl.text = val_str
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	val_lbl.add_theme_font_size_override("font_size", 32)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	val_lbl.add_theme_constant_override("shadow_outline_size", 3)
	row.add_child(val_lbl)
	
	card.add_child(row)
	
	# Tap interaction: opens UserProfileDialog
	card.mouse_entered.connect(func():
		AudioManager.sfx_tap()
		var tw = card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		var tw = card.create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.1)
	)
	card.pressed.connect(func():
		AudioManager.sfx_button()
		ActionVFXManager.animate_button_pop(card)
		user_selected.emit(user_dict)
		var prof_dlg = get_tree().root.find_child("UserProfileDialog", true, false)
		if prof_dlg and prof_dlg.has_method("open_for_user"):
			prof_dlg.open_for_user(user_dict, "رتبه %d کافه فکر" % rank)
	)
	
	list_container.add_child(card)
