extends Control

# User Profile Dialog
# Shows detailed player profile (avatar, username, role, level, cups/score, coins, ID)
# Used both from main menu (user_header) and in-game HUD (tapping player avatars)

signal closed()

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var img_avatar: TextureRect = $CenterContainer/Panel/Margin/VBox/AvatarBox/Plaque/Avatar
@onready var lbl_username: Label = $CenterContainer/Panel/Margin/VBox/LblUsername
@onready var lbl_role: Label = $CenterContainer/Panel/Margin/VBox/LblRole
@onready var lbl_level: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/LevelCard/LblLevel
@onready var lbl_score: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/ScoreCard/LblScore
@onready var coins_card: PanelContainer = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard
@onready var lbl_coins: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard/LblCoins
@onready var btn_copy_id: Button = $CenterContainer/Panel/Margin/VBox/UserIdBox/BtnCopyId
@onready var btn_close_top: TextureButton = $CenterContainer/Panel/Margin/VBox/TopRow/BtnCloseTop

var _current_user_id: String = ""

func _ready() -> void:
	visible = false
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
	lbl_score.text = "امتیاز: %d" % int(score_val)
	
	var coin_val = user_dict.get("coin", user_dict.get("user_coin", user_dict.get("coins", 0)))
	lbl_coins.text = "💰 سکه‌ها: %d" % int(coin_val)
	
	var xp_val = user_dict.get("xp", 0)
	var level_val = 1
	if xp_val > 0:
		level_val = int(floor(xp_val / 100.0)) + 1
	else:
		level_val = int(user_dict.get("level", 1))
	lbl_level.text = "⭐ سطح (Level): %d" % level_val
	
	_current_user_id = str(user_dict.get("_id", user_dict.get("id", user_dict.get("user_id", ""))))
	btn_copy_id.text = "📋 کپی شناسه"
	
	# Entrance VFX Animation
	ActionVFXManager.animate_dialog_open(panel, self, true)

func close() -> void:
	ActionVFXManager.animate_dialog_close(panel, self, func():
		closed.emit()
	)
