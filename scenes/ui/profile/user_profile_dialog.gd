extends Control

# User Profile Dialog
# Shows detailed player profile (avatar, username, role, level, cups/score, coins, ID)
# Used both from main menu (user_header) and in-game HUD (tapping player avatars)

signal closed()
signal change_username_requested()

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var img_avatar: TextureRect = $CenterContainer/Panel/Margin/VBox/AvatarBox/Plaque/Avatar
@onready var lbl_username: Label = $CenterContainer/Panel/Margin/VBox/LblUsername
@onready var lbl_role: Label = $CenterContainer/Panel/Margin/VBox/LblRole
@onready var lbl_level: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/LevelCard/LevelVBox/LblLevel
@onready var lbl_score: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/ScoreCard/ScoreVBox/LblScore
@onready var coins_card: PanelContainer = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard
@onready var lbl_coins: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard/LblCoins
@onready var btn_copy_id: Button = $CenterContainer/Panel/Margin/VBox/UserIdBox/BtnCopyId
@onready var btn_close_top: TextureButton = $CenterContainer/Panel/Margin/VBox/TopRow/BtnCloseTop
@onready var scroll_stats: ScrollContainer = $CenterContainer/Panel/Margin/VBox/ScrollStats
@onready var lbl_stats_loading: Label = $CenterContainer/Panel/Margin/VBox/ScrollStats/StatsVBox/LblStatsLoading
@onready var games_history_container: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ScrollStats/StatsVBox/GamesHistoryContainer

var _current_user_id: String = ""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(btn_copy_id):
		btn_copy_id.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(btn_close_top):
		btn_close_top.focus_mode = Control.FOCUS_NONE
	coins_card.visible = false
	KenneyUI.style_button(btn_copy_id, KenneyUI.COLOR_BLUE)
	
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	$DimOverlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	
	btn_copy_id.pressed.connect(func():
		AudioManager.sfx_tap()
		if not _current_user_id.is_empty():
			DisplayServer.clipboard_set(_current_user_id)
			btn_copy_id.text = "کپی شد"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(btn_copy_id):
					btn_copy_id.text = "کپی شناسه"
			)
	)

func open_for_user(user_dict: Dictionary, role_text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	var uname = user_dict.get("name", user_dict.get("username", "بازیکن کافه فکر"))
	lbl_username.text = uname
	
	if role_text.is_empty():
		lbl_role.visible = false
	else:
		lbl_role.visible = true
		lbl_role.text = role_text
		if role_text.contains("قرمز") or role_text.contains("۱"):
			lbl_role.add_theme_color_override("font_color", Color(1.0, 0.45, 0.48))
		elif role_text.contains("آبی") or role_text.contains("۲"):
			lbl_role.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
		else:
			lbl_role.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
			
	var av_id = user_dict.get("image", user_dict.get("user_image", 0))
	var av_path = "res://assets/icons/Avatars/%d.png" % int(av_id)
	if ResourceLoader.exists(av_path):
		img_avatar.texture = load(av_path)
		
	var score_val = user_dict.get("score", user_dict.get("user_score", 0))
	lbl_score.text = GameManager.to_fa_num(int(score_val))
	
	var coin_val = user_dict.get("coin", user_dict.get("user_coin", user_dict.get("coins", 0)))
	lbl_coins.text = "💰 %s" % GameManager.to_fa_num(int(coin_val))
	
	var xp_val = int(float(user_dict.get("xp", user_dict.get("user_xp", 0))))
	var level_val = 1
	if xp_val > 0:
		level_val = GameManager.calculate_level(xp_val)
	else:
		level_val = int(user_dict.get("level", 1))
	lbl_level.text = GameManager.to_fa_num(level_val)
	
	_current_user_id = str(user_dict.get("_id", user_dict.get("id", user_dict.get("user_id", ""))))
	btn_copy_id.text = "📋 کپی شناسه"

	var is_self = (_current_user_id == str(GameManager.get_user_id()) or _current_user_id.is_empty())
	var vbox_root = $CenterContainer/Panel/Margin/VBox
	var btn_edit_name = vbox_root.get_node_or_null("BtnEditProfileUsername") as Button
	if is_self:
		if not is_instance_valid(btn_edit_name):
			btn_edit_name = Button.new()
			btn_edit_name.name = "BtnEditProfileUsername"
			btn_edit_name.text = "✏️ تغییر نام کاربری"
			btn_edit_name.custom_minimum_size = Vector2(340, 72)
			btn_edit_name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn_edit_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
			btn_edit_name.add_theme_font_size_override("font_size", 28)
			KenneyUI.style_button(btn_edit_name, KenneyUI.COLOR_YELLOW)
			btn_edit_name.pressed.connect(func():
				AudioManager.sfx_tap()
				close()
				change_username_requested.emit()
			)
			# Insert before ScrollStats if valid
			if is_instance_valid(scroll_stats):
				vbox_root.add_child(btn_edit_name)
				vbox_root.move_child(btn_edit_name, scroll_stats.get_index())
			else:
				vbox_root.add_child(btn_edit_name)
		btn_edit_name.visible = true
	elif is_instance_valid(btn_edit_name):
		btn_edit_name.visible = false

	# === Load Games History & Statistics for this player ===
	_load_player_history(user_dict)
	
	# Entrance VFX Animation
	ActionVFXManager.animate_dialog_open(panel, self, true)

func _load_player_history(user_dict: Dictionary) -> void:
	if not is_instance_valid(games_history_container):
		return

	for child in games_history_container.get_children():
		child.queue_free()

	if user_dict.has("history") and typeof(user_dict["history"]) == TYPE_DICTIONARY:
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		GamesHistoryViewHelper.populate_games_history(games_history_container, user_dict["history"])
		return

	if _current_user_id.is_empty() or _current_user_id.begins_with("bot_") or _current_user_id.begins_with("test_bot"):
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		GamesHistoryViewHelper.populate_games_history(games_history_container, {})
		return

	if is_instance_valid(lbl_stats_loading):
		lbl_stats_loading.visible = true
		lbl_stats_loading.text = "در حال دریافت آمار بازی‌ها..."

	var req_uid = _current_user_id
	NetworkManager.api.get_user_data(req_uid, func(success: bool, _code: int, data: Variant):
		if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
			return
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		if success and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res = data["result"]
			var hist_dict = {}
			if typeof(res) == TYPE_DICTIONARY and res.has("history") and typeof(res["history"]) == TYPE_DICTIONARY:
				hist_dict = res["history"]
			GamesHistoryViewHelper.populate_games_history(games_history_container, hist_dict)
		else:
			if is_instance_valid(lbl_stats_loading):
				lbl_stats_loading.text = "آمار بازی‌ها در دسترس نیست"
				lbl_stats_loading.visible = true
	)

func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(panel, self, func():
		visible = false
		closed.emit()
	)
