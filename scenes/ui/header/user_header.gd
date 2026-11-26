extends MarginContainer

# User Header Component
# Redesigned Cafe Fekr Top Player Profile Bar (2-Tier Ornate Parlor Layout):
# - Tier 1: Score crest (left), username + edit + copyable ID (middle-right), framed avatar (right)
# - Tier 2: Full-width aspect-locked exp_bar.png with level centered in the left medallion
#   and emerald XP progress fill + readable XP ratio seated cleanly inside the recessed trough.

signal store_requested()
signal profile_requested()
signal login_requested()
signal change_username_requested()

const EXP_BAR_ASPECT: float = 1024.0 / 144.0
const EXP_TROUGH_HEIGHT_RATIO: float = 0.660 - 0.333
const EXP_TROUGH_WIDTH_RATIO: float = 0.935 - 0.180

@onready var avatar_frame: Control = $PanelFrame/ContentMargin/VBoxMain/TopRow/AvatarFrame
@onready var avatar_rect: TextureRect = $PanelFrame/ContentMargin/VBoxMain/TopRow/AvatarFrame/AvatarBtn/AvatarTexture
@onready var avatar_btn: TextureButton = $PanelFrame/ContentMargin/VBoxMain/TopRow/AvatarFrame/AvatarBtn
@onready var top_identity_row: HBoxContainer = $PanelFrame/ContentMargin/VBoxMain/TopRow/UserCol/TopIdentityRow
@onready var lbl_username: Label = $PanelFrame/ContentMargin/VBoxMain/TopRow/UserCol/TopIdentityRow/Username
@onready var btn_edit_username: Button = $PanelFrame/ContentMargin/VBoxMain/TopRow/UserCol/TopIdentityRow/BtnEditUsername
@onready var btn_user_id: Button = $PanelFrame/ContentMargin/VBoxMain/TopRow/UserCol/BottomIdRow/UserIdBtn

@onready var coin_badge: HBoxContainer = $PanelFrame/ContentMargin/VBoxMain/TopRow/CoinBadge
@onready var sep1: VSeparator = $PanelFrame/ContentMargin/VBoxMain/TopRow/Sep1
@onready var lbl_coins: Label = $PanelFrame/ContentMargin/VBoxMain/TopRow/CoinBadge/CoinsLabel
@onready var btn_coins_add: TextureButton = $PanelFrame/ContentMargin/VBoxMain/TopRow/CoinBadge/BtnAddCoins
@onready var lbl_score: Label = $PanelFrame/ContentMargin/VBoxMain/TopRow/ScoreCard/ScoreBadge/ScoreLabel

@onready var xp_row: CenterContainer = $PanelFrame/ContentMargin/VBoxMain/XpRow
@onready var xp_container: Control = $PanelFrame/ContentMargin/VBoxMain/XpRow/XpContainer
@onready var lbl_level: Label = $PanelFrame/ContentMargin/VBoxMain/XpRow/XpContainer/LevelBadge/LevelLabel
@onready var xp_bar: ProgressBar = $PanelFrame/ContentMargin/VBoxMain/XpRow/XpContainer/XpBar
@onready var lbl_xp_value: Label = $PanelFrame/ContentMargin/VBoxMain/XpRow/XpContainer/XpValueLabel

var _is_copy_feedback_active: bool = false
var _last_progress_pct: float = 0.0
var _last_level_text: String = "۱"


func _ready() -> void:
	coin_badge.visible = false
	sep1.visible = false

	ActionVFXManager.apply_button_juice(avatar_btn, "tap_button")
	ActionVFXManager.apply_button_juice(btn_user_id, "tap_button")
	if is_instance_valid(btn_edit_username):
		ActionVFXManager.apply_button_juice(btn_edit_username, "tap_button")
		btn_edit_username.pressed.connect(func():
			AudioManager.sfx_tap()
			change_username_requested.emit()
		)

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
	if GameManager.has_signal("user_data_updated"):
		GameManager.user_data_updated.connect(func(_u): update_ui())

	if is_instance_valid(top_identity_row):
		top_identity_row.resized.connect(_sync_username_layout)
	if is_instance_valid(xp_row):
		xp_row.resized.connect(_sync_exp_bar_layout)

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

	# Instant local session check if not yet marked as logged in
	if not GameManager.is_logged_in:
		var saved_tok = GameManager.load_saved_token()
		var saved_usr = GameManager.load_saved_user_data()
		if not saved_tok.is_empty() and not saved_usr.is_empty():
			GameManager.token = saved_tok
			GameManager.user_data = saved_usr
			GameManager.is_logged_in = true

	if GameManager.is_logged_in:
		lbl_username.text = GameManager.get_username()
		lbl_coins.text = _fa_num(GameManager.get_coins())
		lbl_score.text = _fa_num(GameManager.get_score())

		var uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", ""))).strip_edges()
		if not _is_copy_feedback_active:
			if GameManager.is_guest:
				btn_user_id.text = "🔑 ثبت شماره موبایل"
			elif not uid.is_empty():
				btn_user_id.text = "📋 شناسه: " + uid.substr(0, 8)
			else:
				btn_user_id.text = "📋 شناسه: ----"

		var xp = GameManager.get_xp()
		var lvl_info = GameManager.get_level_info(xp)
		var level = int(lvl_info.get("level", 1))
		var next_base = int(lvl_info.get("next_level_exp", 60))
		var progress_pct = clampf(float(lvl_info.get("progress", 0.0)) * 100.0, 0.0, 100.0)

		_last_level_text = _fa_num(level)
		_last_progress_pct = progress_pct
		lbl_level.text = _last_level_text

		if is_instance_valid(xp_bar):
			xp_bar.min_value = 0.0
			xp_bar.max_value = 100.0
			xp_bar.step = 0.01
			xp_bar.value = progress_pct

		if is_instance_valid(lbl_xp_value):
			lbl_xp_value.text = "\u200E%s / %s XP\u200E" % [_fa_num(xp), _fa_num(next_base)]

		var img_id = int(GameManager.user_data.get("image", 0))
		var frame_id = GameManager.get_frame_id()
		var avatar_path = "res://assets/icons/Avatars/%d.png" % img_id
		if ResourceLoader.exists(avatar_path):
			avatar_rect.texture = load(avatar_path)
		CafeSocialTheme.apply_frame_to_container(avatar_frame, avatar_rect, frame_id)
	else:
		lbl_username.text = "کاربر کافه فکر"
		if not _is_copy_feedback_active:
			btn_user_id.text = "🔑 ورود / ثبت شماره"
		lbl_coins.text = "۰"
		lbl_score.text = "۰"
		_last_level_text = "۱"
		_last_progress_pct = 0.0
		lbl_level.text = _last_level_text
		if is_instance_valid(xp_bar):
			xp_bar.min_value = 0.0
			xp_bar.max_value = 100.0
			xp_bar.step = 0.01
			xp_bar.value = 0.0
		if is_instance_valid(lbl_xp_value):
			lbl_xp_value.text = "\u200E۰ / ۶۰ XP\u200E"
		CafeSocialTheme.apply_frame_to_container(avatar_frame, avatar_rect, 1)

	call_deferred("_sync_username_layout")
	call_deferred("_sync_exp_bar_layout")


func _sync_exp_bar_layout() -> void:
	if not is_instance_valid(xp_row) or not is_instance_valid(xp_container):
		return

	var avail_w: float = xp_row.size.x
	if avail_w <= 1.0:
		avail_w = 440.0

	# Preserve exact native exp_bar.png aspect ratio (1024x144 = 7.111:1) so the
	# left circular medallion stays a true circle and trough rails never distort.
	var max_w: float = minf(avail_w, 468.0)
	var target_h: float = clampf(round(max_w / EXP_BAR_ASPECT), 44.0, 64.0)
	var target_w: float = round(target_h * EXP_BAR_ASPECT)
	if target_w > avail_w and avail_w > 120.0:
		target_w = floor(avail_w)
		target_h = maxf(38.0, round(target_w / EXP_BAR_ASPECT))

	if not xp_container.custom_minimum_size.is_equal_approx(Vector2(target_w, target_h)):
		xp_container.custom_minimum_size = Vector2(target_w, target_h)

	var trough_h: float = target_h * EXP_TROUGH_HEIGHT_RATIO
	var trough_w: float = target_w * EXP_TROUGH_WIDTH_RATIO

	# Fit level numeral cleanly inside the circular left medallion
	if is_instance_valid(lbl_level):
		var digit_count: int = _last_level_text.length()
		var scale_factor: float = 0.36 if digit_count <= 2 else 0.28
		var lvl_font_sz: int = clampi(int(round(target_h * scale_factor)), 15, 26)
		lbl_level.set_meta(&"_resp_managed", true)
		lbl_level.add_theme_font_size_override("font_size", lvl_font_sz)

	# Fit XP text crisply inside the dark recessed trough
	if is_instance_valid(lbl_xp_value):
		var xp_font_sz: int = clampi(int(round(trough_h * 0.78)), 14, 18)
		lbl_xp_value.set_meta(&"_resp_managed", true)
		lbl_xp_value.add_theme_font_size_override("font_size", xp_font_sz)

	_apply_xp_fill_style(trough_w, trough_h, _last_progress_pct / 100.0)


func _apply_xp_fill_style(trough_w: float, trough_h: float, ratio: float) -> void:
	if not is_instance_valid(xp_bar):
		return
	if ratio <= 0.002:
		xp_bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		return

	var pill_r: int = maxi(3, int(round(trough_h * 0.5)))
	var fill_px: float = trough_w * clampf(ratio, 0.0, 1.0)
	var right_r: int = mini(pill_r, maxi(2, int(round(fill_px * 0.45))))
	var left_r: int = mini(3, right_r)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.78, 0.42, 0.98)
	sb.border_width_top = 1
	sb.border_color = Color(0.62, 1.0, 0.74, 0.75)
	sb.corner_radius_top_left = left_r
	sb.corner_radius_bottom_left = left_r
	sb.corner_radius_top_right = right_r
	sb.corner_radius_bottom_right = right_r
	xp_bar.add_theme_stylebox_override("fill", sb)


func _sync_username_layout() -> void:
	if not is_instance_valid(lbl_username) or not is_instance_valid(top_identity_row):
		return
	var row_w: float = top_identity_row.size.x
	var edit_w: float = 38.0
	if is_instance_valid(btn_edit_username) and btn_edit_username.visible:
		edit_w = maxf(btn_edit_username.custom_minimum_size.x, btn_edit_username.size.x) + 8.0
	var max_lbl_w: float = maxf(48.0, row_w - edit_w)
	var font: Font = lbl_username.get_theme_font("font")
	var font_sz: int = lbl_username.get_theme_font_size("font_size")
	var text_w: float = 0.0
	if font != null:
		text_w = font.get_string_size(lbl_username.text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_sz).x
	if row_w > 0.0 and text_w > max_lbl_w:
		lbl_username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_username.set_meta(&"_resp_managed", true)
		UITypography.fit_label_to_width(lbl_username, max_lbl_w, 26, 17)
		lbl_username.clip_text = true
		lbl_username.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_username.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		lbl_username.size_flags_horizontal = Control.SIZE_SHRINK_END
		lbl_username.clip_text = false
		lbl_username.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


static func _total_exp_to_level(level: int, _base: int = 20) -> int:
	return GameManager.total_exp_to_level(level)


static func _calculate_level(exp: int, _base: int = 20) -> int:
	return GameManager.calculate_level(exp)


static func _calculate_exp_percent(exp: int, _base: int = 20) -> float:
	return GameManager.calculate_exp_percent(exp)
