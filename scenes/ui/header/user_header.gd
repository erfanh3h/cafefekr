extends MarginContainer

# User Header Component
# Redesigned Cafe Fekr Top Player Profile Bar:
# Displays avatar in golden wooden medallion, large readable username,
# interactive copyable User ID badge, trophy score capsule, level capsule,
# and XP progression bar with Persian numerals.

signal store_requested()
signal profile_requested()
signal login_requested()

@onready var avatar_rect: TextureRect = $PanelFrame/ContentMargin/HBoxMain/AvatarFrame/AvatarBtn/AvatarTexture
@onready var avatar_btn: TextureButton = $PanelFrame/ContentMargin/HBoxMain/AvatarFrame/AvatarBtn
@onready var lbl_username: Label = $PanelFrame/ContentMargin/HBoxMain/UserCol/TopIdentityRow/Username
@onready var btn_user_id: Button = $PanelFrame/ContentMargin/HBoxMain/UserCol/BottomIdRow/UserIdBtn

@onready var coin_badge: HBoxContainer = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge
@onready var sep1: VSeparator = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/Sep1
@onready var lbl_coins: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge/CoinsLabel
@onready var btn_coins_add: TextureButton = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/CoinBadge/BtnAddCoins
@onready var lbl_score: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/ScoreCard/ScoreBadge/ScoreLabel
@onready var lbl_level: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/BadgesRow/LevelCard/LevelBadge/LevelLabel
@onready var xp_bar: ProgressBar = $PanelFrame/ContentMargin/HBoxMain/StatsCol/XpContainer/XpBar
@onready var lbl_xp_value: Label = $PanelFrame/ContentMargin/HBoxMain/StatsCol/XpContainer/XpValueLabel

var _is_copy_feedback_active: bool = false

func _ready() -> void:
	coin_badge.visible = false
	sep1.visible = false

	ActionVFXManager.apply_button_juice(avatar_btn, "tap_button")
	ActionVFXManager.apply_button_juice(btn_user_id, "tap_button")

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
		if not GameManager.is_logged_in or GameManager.is_guest or not GameManager.has_phone():
			login_requested.emit()
			return
		var uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", ""))).strip_edges()
		if not uid.is_empty():
			DisplayServer.clipboard_set(uid)
			_is_copy_feedback_active = true
			btn_user_id.text = "✓ شناسه کپی شد!"
			btn_user_id.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58, 1.0))
			get_tree().create_timer(1.5).timeout.connect(func():
				_is_copy_feedback_active = false
				if is_instance_valid(self):
					update_ui()
			)
	)

	GameManager.user_logged_in.connect(func(_u): update_ui())
	GameManager.user_logged_out.connect(func(): update_ui())

	update_ui()

static func _fa_num(val: Variant) -> String:
	var s = str(val)
	var fa_digits = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for i in range(s.length()):
		var code = s.unicode_at(i)
		if code >= 48 and code <= 57:
			out += fa_digits[code - 48]
		else:
			out += s[i]
	return out

func update_ui() -> void:
	if not _is_copy_feedback_active and is_instance_valid(btn_user_id):
		btn_user_id.add_theme_color_override("font_color", Color(0.96, 0.88, 0.72, 1.0))

	if GameManager.is_logged_in:
		lbl_username.text = GameManager.get_username()
		lbl_coins.text = _fa_num(GameManager.get_coins())
		lbl_score.text = "%s امتیاز" % _fa_num(GameManager.get_score())

		var uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", ""))).strip_edges()
		if not _is_copy_feedback_active:
			if GameManager.is_guest:
				btn_user_id.text = "🔑 ثبت شماره موبایل"
			elif not uid.is_empty():
				btn_user_id.text = "📋 شناسه: " + uid.substr(0, 8)
			else:
				btn_user_id.text = "📋 شناسه: ----"

		var xp = int(GameManager.user_data.get("xp", 0))
		var lvl_info = GameManager.get_level_info(xp)
		var level = int(lvl_info.get("level", 1))
		var exp_in_lvl = int(lvl_info.get("exp_in_level", 0))
		var exp_needed = int(lvl_info.get("exp_needed", 60))
		var pct_int = int(lvl_info.get("percent_int", 0))

		lbl_level.text = "سطح %s" % _fa_num(level)
		xp_bar.value = float(lvl_info.get("progress", 0.0)) * 100.0
		if is_instance_valid(lbl_xp_value):
			lbl_xp_value.text = "تجربه: %s / %s (%s٪)" % [_fa_num(exp_in_lvl), _fa_num(exp_needed), _fa_num(pct_int)]

		var img_id = int(GameManager.user_data.get("image", 0))
		var avatar_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path)
	else:
		lbl_username.text = "کاربر مهمان"
		if not _is_copy_feedback_active:
			btn_user_id.text = "🔑 ورود / ثبت شماره"
		lbl_coins.text = "۰"
		lbl_score.text = "۰ امتیاز"
		lbl_level.text = "سطح ۱"
		xp_bar.value = 0.0
		if is_instance_valid(lbl_xp_value):
			lbl_xp_value.text = "تجربه: ۰ / ۶۰ (۰٪)"

static func _total_exp_to_level(level: int, _base: int = 20) -> int:
	return GameManager.total_exp_to_level(level)

static func _calculate_level(exp: int, _base: int = 20) -> int:
	return GameManager.calculate_level(exp)

static func _calculate_exp_percent(exp: int, _base: int = 20) -> float:
	return GameManager.calculate_exp_percent(exp)
