extends MarginContainer

## Compact User Header for Cafe Fekr Five-Tab Shell
## Streamlined ~110px height persistent player identity bar.
## Displays: Avatar medallion, Username, Level badge + XP progress capsule,
## and Coins / Score pills.
## Tapping the header navigates smoothly to the User tab.

signal header_clicked()
signal profile_requested()
signal store_requested()
signal login_requested()
signal change_username_requested()

@onready var avatar_rect: TextureRect = $Frame/Margin/HBox/AvatarBtn/AvatarTexture
@onready var avatar_btn: TextureButton = $Frame/Margin/HBox/AvatarBtn
@onready var lbl_username: Label = $Frame/Margin/HBox/IdentityCol/TopRow/LblUsername
@onready var lbl_level: Label = $Frame/Margin/HBox/IdentityCol/BottomRow/LevelPill/LblLevel
@onready var xp_bar: ProgressBar = $Frame/Margin/HBox/IdentityCol/BottomRow/XpContainer/XpBar
@onready var lbl_xp: Label = $Frame/Margin/HBox/IdentityCol/BottomRow/XpContainer/LblXp
@onready var lbl_coins: Label = $Frame/Margin/HBox/BadgesCol/CoinPill/HBoxCoin/LblCoins
@onready var btn_add_coins: TextureButton = $Frame/Margin/HBox/BadgesCol/CoinPill/HBoxCoin/BtnAddCoins
@onready var lbl_score: Label = $Frame/Margin/HBox/BadgesCol/ScorePill/HBoxScore/LblScore
@onready var whole_bar_btn: Button = $Frame/WholeBarBtn

const DEFAULT_AVATAR = preload("res://assets/icons/Avatars/0.png")

func _ready() -> void:
	ActionVFXManager.apply_button_juice(avatar_btn, "tap_button")
	ActionVFXManager.apply_button_juice(btn_add_coins, "tap_button")

	avatar_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		header_clicked.emit()
		profile_requested.emit()
	)

	whole_bar_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		header_clicked.emit()
		profile_requested.emit()
	)

	btn_add_coins.pressed.connect(func():
		AudioManager.sfx_button()
		store_requested.emit()
	)

	GameManager.user_logged_in.connect(func(_u): update_ui())
	GameManager.user_logged_out.connect(func(): update_ui())
	if GameManager.has_signal("user_data_updated"):
		GameManager.user_data_updated.connect(func(_u): update_ui())

	if ResponsiveUI != null and not ResponsiveUI.layout_changed.is_connected(_on_responsive_layout_changed):
		ResponsiveUI.layout_changed.connect(_on_responsive_layout_changed)
	resized.connect(_sync_responsive_typography)
	update_ui()
	call_deferred("_sync_responsive_typography")


func _on_responsive_layout_changed(_metrics: Dictionary) -> void:
	_sync_responsive_typography()


func _sync_responsive_typography() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(lbl_username):
		ResponsiveUI.apply_text(lbl_username, UITypography.Role.TITLE_SM, {"min_px": 18, "max_px": 28, "ellipsis": true})
		var avail_w: float = maxf(80.0, lbl_username.size.x)
		if avail_w > 80.0:
			UITypography.fit_label_to_width(lbl_username, avail_w, 24, 17)
	if is_instance_valid(lbl_level):
		ResponsiveUI.apply_text(lbl_level, UITypography.Role.BODY_SM, {"min_px": 15, "max_px": 21})
	if is_instance_valid(lbl_xp):
		ResponsiveUI.apply_text(lbl_xp, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	if is_instance_valid(lbl_coins):
		ResponsiveUI.apply_text(lbl_coins, UITypography.Role.SUBTITLE, {"min_px": 17, "max_px": 24})
	if is_instance_valid(lbl_score):
		ResponsiveUI.apply_text(lbl_score, UITypography.Role.SUBTITLE, {"min_px": 17, "max_px": 24})


func update_ui() -> void:
	if not is_inside_tree() or not is_instance_valid(lbl_username) or not is_instance_valid(lbl_coins):
		return
	if not GameManager.is_logged_in:
		var saved_tok = GameManager.load_saved_token()
		var saved_usr = GameManager.load_saved_user_data()
		if not saved_tok.is_empty() and not saved_usr.is_empty():
			GameManager.token = saved_tok
			GameManager.user_data = saved_usr
			GameManager.is_logged_in = true

	if GameManager.is_logged_in:
		lbl_username.text = GameManager.get_username()
		lbl_coins.text = GameManager.to_fa_num(GameManager.get_coins())
		lbl_score.text = GameManager.to_fa_num(GameManager.get_score())

		var xp = GameManager.get_xp()
		var lvl_info = GameManager.get_level_info(xp)
		var level = int(lvl_info.get("level", 1))
		var next_base = int(lvl_info.get("next_level_exp", 60))
		var progress_pct = float(lvl_info.get("progress", 0.0)) * 100.0

		lbl_level.text = "سطح %s" % GameManager.to_fa_num(level)
		if is_instance_valid(xp_bar):
			xp_bar.min_value = 0.0
			xp_bar.max_value = 100.0
			xp_bar.value = progress_pct
		if is_instance_valid(lbl_xp):
			lbl_xp.text = "\u200E%s/%s\u200E" % [GameManager.to_fa_num(xp), GameManager.to_fa_num(next_base)]

		var img_id = int(GameManager.user_data.get("image", 0))
		var frame_id = GameManager.get_frame_id()
		var avatar_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path)
		else:
			avatar_rect.texture = DEFAULT_AVATAR
		CafeSocialTheme.apply_frame_to_container(avatar_btn, avatar_rect, frame_id)
	else:
		lbl_username.text = "کاربر کافه فکر"
		lbl_coins.text = "۰"
		lbl_score.text = "۰"
		lbl_level.text = "سطح ۱"
		if is_instance_valid(xp_bar):
			xp_bar.value = 0.0
		if is_instance_valid(lbl_xp):
			lbl_xp.text = "۰/۶۰"
		avatar_rect.texture = DEFAULT_AVATAR
		CafeSocialTheme.apply_frame_to_container(avatar_btn, avatar_rect, 1)
