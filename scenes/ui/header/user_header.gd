extends MarginContainer

# User Header Component
# Mirrors GlobalUserDataHeader from Flutter app:
# Displays avatar in wooden medallion, username, user ID, connection status (Online/Offline/Guest), level, XP bar, coins, score.

signal store_requested()
signal profile_requested()

@onready var avatar_rect: TextureRect = $PanelFrame/ContentMargin/HBoxMain/AvatarFrame/AvatarBtn/AvatarTexture
@onready var avatar_btn: TextureButton = $PanelFrame/ContentMargin/HBoxMain/AvatarFrame/AvatarBtn
@onready var lbl_username: Label = $PanelFrame/ContentMargin/HBoxMain/UserCol/Username
@onready var btn_user_id: Button = $PanelFrame/ContentMargin/HBoxMain/UserCol/UserIdBtn
@onready var lbl_status: Label = $PanelFrame/ContentMargin/HBoxMain/UserCol/StatusRow/LblStatus

@onready var coin_badge: HBoxContainer = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge
@onready var sep1: VSeparator = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/Sep1
@onready var lbl_coins: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge/CoinsLabel
@onready var btn_coins_add: TextureButton = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge/BtnAddCoins
@onready var lbl_score: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/ScoreBadge/ScoreLabel
@onready var lbl_level: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/LevelBadge/LevelLabel
@onready var xp_bar: ProgressBar = $PanelFrame/ContentMargin/HBoxMain/StatsCol/XpBar

func _ready() -> void:
	coin_badge.visible = false
	sep1.visible = false
	
	btn_coins_add.pressed.connect(func():
		AudioManager.sfx_button()
		store_requested.emit()
	)
	
	avatar_btn.pressed.connect(func():
		AudioManager.sfx_button()
		profile_requested.emit()
	)
	
	btn_user_id.pressed.connect(func():
		AudioManager.sfx_tap()
		var uid = GameManager.user_data.get("_id", GameManager.user_data.get("id", ""))
		if uid != "":
			DisplayServer.clipboard_set(str(uid))
			btn_user_id.text = "کپی شد"
			get_tree().create_timer(1.5).timeout.connect(func():
				if GameManager.is_guest:
					btn_user_id.text = "مهمان (بدون شماره)"
				else:
					btn_user_id.text = "شناسه: " + str(uid).substr(0, 8)
			)
	)
	
	GameManager.user_logged_in.connect(func(_u): update_ui())
	GameManager.user_logged_out.connect(func(): update_ui())
	NetworkManager.connection_status_changed.connect(func(_connected: bool): update_ui())
	
	update_ui()

func update_ui() -> void:
	var is_online = NetworkManager.is_online
	
	if GameManager.is_logged_in:
		lbl_username.text = GameManager.get_username()
		lbl_coins.text = str(GameManager.get_coins())
		lbl_score.text = str(GameManager.get_score())
		
		var uid = GameManager.user_data.get("_id", GameManager.user_data.get("id", ""))
		if GameManager.is_guest:
			btn_user_id.text = "مهمان (بدون شماره)"
		elif uid != "":
			btn_user_id.text = "شناسه: " + str(uid).substr(0, 8)
		else:
			btn_user_id.text = "شناسه: ----"
			
		var xp = int(GameManager.user_data.get("xp", 0))
		var level = _calculate_level(xp)
		lbl_level.text = "سطح %d" % (level + 1)
		xp_bar.value = _calculate_exp_percent(xp) * 100.0
		
		var img_id = GameManager.user_data.get("image", 0)
		var avatar_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path)
	else:
		lbl_username.text = "کاربر مهمان"
		btn_user_id.text = "برای ثبت رکورد وارد شوید"
		lbl_coins.text = "0"
		lbl_score.text = "0"
		lbl_level.text = "سطح ۱"
		xp_bar.value = 0.0
		
	if is_instance_valid(lbl_status):
		if is_online:
			if GameManager.is_guest:
				lbl_status.text = "🟢 مهمان"
				lbl_status.modulate = Color(0.4, 0.9, 0.5)
			else:
				lbl_status.text = "🟢 آنلاین"
				lbl_status.modulate = Color(0.35, 1.0, 0.45)
		else:
			lbl_status.text = "🔴 آفلاین"
			lbl_status.modulate = Color(1.0, 0.35, 0.35)

static func _total_exp_to_level(level: int, base: int = 20) -> int:
	return int(base * (level * level))

static func _calculate_level(exp: int, base: int = 20) -> int:
	if exp < base:
		return 0
	var level = 1
	while _total_exp_to_level(level + 1, base) <= exp:
		level += 1
	return level

static func _calculate_exp_percent(exp: int, base: int = 20) -> float:
	var level = _calculate_level(exp, base)
	var current_level_exp = _total_exp_to_level(level, base)
	var next_level_exp = _total_exp_to_level(level + 1, base)
	var exp_in_level = exp - current_level_exp
	var needed = next_level_exp - current_level_exp
	if needed <= 0:
		return 1.0
	return clampf(float(exp_in_level) / float(needed), 0.05, 1.0)
