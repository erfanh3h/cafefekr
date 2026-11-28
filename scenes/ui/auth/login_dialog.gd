extends PanelContainer

# Login & New-Player Onboarding Dialog Controller
# 3-Step Parlor Flow:
# Step 1: Mobile number entry (with Persian/Arabic digit normalization + live validation) -> POST /enter
# Step 2: 4-Digit visual OTP verification + 60s resend countdown + quick edit phone -> POST /code
# Step 3: Mandatory username selection + collapsible optional referral code -> POST /complete-data

signal login_completed()
signal closed()

const RESEND_COOLDOWN_SEC: int = 60

# Header & Stepper
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_title: Label = $Margin/VBox/TopRow/BrandCenter/LblTitle
@onready var lbl_tagline: Label = $Margin/VBox/TopRow/BrandCenter/LblTagline
@onready var step_pill_1: PanelContainer = $Margin/VBox/StepperRow/StepPill1
@onready var lbl_step_1: Label = $Margin/VBox/StepperRow/StepPill1/LblStep1
@onready var step_pill_2: PanelContainer = $Margin/VBox/StepperRow/StepPill2
@onready var lbl_step_2: Label = $Margin/VBox/StepperRow/StepPill2/LblStep2
@onready var step_pill_3: PanelContainer = $Margin/VBox/StepperRow/StepPill3
@onready var lbl_step_3: Label = $Margin/VBox/StepperRow/StepPill3/LblStep3
@onready var conn_1: ColorRect = $Margin/VBox/StepperRow/Connector1
@onready var conn_2: ColorRect = $Margin/VBox/StepperRow/Connector2
@onready var status_banner: PanelContainer = $Margin/VBox/StatusBanner
@onready var lbl_status: Label = $Margin/VBox/StatusBanner/LblStatus

# Step 1: Phone
@onready var step1_container: VBoxContainer = $Margin/VBox/Step1_Phone
@onready var phone_card: PanelContainer = $Margin/VBox/Step1_Phone/PhoneCard
@onready var lbl_phone_badge: Label = $Margin/VBox/Step1_Phone/PhoneCard/CardVBox/LabelRow/LblPhoneBadge
@onready var input_phone: LineEdit = $Margin/VBox/Step1_Phone/PhoneCard/CardVBox/InputPhone
@onready var btn_send_code: Button = $Margin/VBox/Step1_Phone/BtnSendCode
@onready var or_separator: HBoxContainer = $Margin/VBox/Step1_Phone/OrSeparator
@onready var btn_guest_login: Button = $Margin/VBox/Step1_Phone/BtnGuestLogin

# Step 2: SMS Code
@onready var step2_container: VBoxContainer = $Margin/VBox/Step2_Code
@onready var lbl_step2_subtitle: Label = $Margin/VBox/Step2_Code/PhoneSummaryPill/PillHBox/LblSubtitle
@onready var btn_back_phone: Button = $Margin/VBox/Step2_Code/PhoneSummaryPill/PillHBox/BtnBackPhone
@onready var otp_card: PanelContainer = $Margin/VBox/Step2_Code/OtpCard
@onready var input_code: LineEdit = $Margin/VBox/Step2_Code/OtpCard/OtpVBox/OtpStage/InputCode
@onready var otp_slot_0: PanelContainer = $Margin/VBox/Step2_Code/OtpCard/OtpVBox/OtpStage/OtpSlotsRow/Slot0
@onready var otp_slot_1: PanelContainer = $Margin/VBox/Step2_Code/OtpCard/OtpVBox/OtpStage/OtpSlotsRow/Slot1
@onready var otp_slot_2: PanelContainer = $Margin/VBox/Step2_Code/OtpCard/OtpVBox/OtpStage/OtpSlotsRow/Slot2
@onready var otp_slot_3: PanelContainer = $Margin/VBox/Step2_Code/OtpCard/OtpVBox/OtpStage/OtpSlotsRow/Slot3
@onready var btn_verify_code: Button = $Margin/VBox/Step2_Code/BtnVerifyCode
@onready var btn_resend_code: Button = $Margin/VBox/Step2_Code/BtnResendCode

# Step 3: Username Setup
@onready var step3_container: VBoxContainer = $Margin/VBox/Step3_Username
@onready var username_card: PanelContainer = $Margin/VBox/Step3_Username/UsernameCard
@onready var lbl_char_count: Label = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/LabelRow/LblCharCount
@onready var input_username: LineEdit = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/InputUsername
@onready var lbl_username_hint: Label = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/LblUsernameHint
@onready var btn_toggle_referral: Button = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/BtnToggleReferral
@onready var referral_box: VBoxContainer = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/ReferralBox
@onready var input_rep_id: LineEdit = $Margin/VBox/Step3_Username/UsernameCard/CardVBox/ReferralBox/InputRepId
@onready var btn_submit_username: Button = $Margin/VBox/Step3_Username/BtnSubmitUsername

var current_phone: String = ""
var is_mandatory_username: bool = false

var _otp_slots: Array[PanelContainer] = []
var _resend_seconds_left: int = 0
var _resend_timer: Timer = null
var _is_sending_code: bool = false
var _is_verifying_code: bool = false
var _is_submitting_username: bool = false
var _otp_prefilled: bool = false


func _ready() -> void:
	_otp_slots = [otp_slot_0, otp_slot_1, otp_slot_2, otp_slot_3]

	KenneyUI.style_button(btn_send_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_verify_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_submit_username, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_guest_login, KenneyUI.COLOR_BLUE)

	ActionVFXManager.apply_button_juice(btn_send_code, "tap_button")
	ActionVFXManager.apply_button_juice(btn_verify_code, "tap_button")
	ActionVFXManager.apply_button_juice(btn_submit_username, "tap_button")
	ActionVFXManager.apply_button_juice(btn_back_phone, "tap_button")
	ActionVFXManager.apply_button_juice(btn_resend_code, "tap_button")
	ActionVFXManager.apply_button_juice(btn_toggle_referral, "tap_button")

	btn_send_code.pressed.connect(_on_send_code_pressed)
	btn_guest_login.pressed.connect(_on_guest_login_pressed)
	btn_verify_code.pressed.connect(_on_verify_code_pressed)
	btn_back_phone.pressed.connect(func():
		AudioManager.sfx_tap()
		_show_step1()
	)
	btn_resend_code.pressed.connect(_on_resend_code_pressed)
	btn_submit_username.pressed.connect(_on_submit_username_pressed)
	btn_toggle_referral.pressed.connect(_on_toggle_referral_pressed)

	btn_close_top.visible = false
	btn_guest_login.visible = false
	or_separator.visible = false

	input_phone.text_changed.connect(_on_phone_text_changed)
	input_phone.text_submitted.connect(func(_t: String): _on_send_code_pressed())

	input_code.text_changed.connect(_on_code_text_changed)
	input_code.focus_entered.connect(_refresh_otp_slots)
	input_code.focus_exited.connect(_refresh_otp_slots)
	input_code.text_submitted.connect(func(_t: String): _on_verify_code_pressed())

	input_username.text_changed.connect(_on_username_text_changed)
	input_username.text_submitted.connect(func(_t: String): _on_submit_username_pressed())
	input_rep_id.text_submitted.connect(func(_t: String): _on_submit_username_pressed())

	_resend_timer = Timer.new()
	_resend_timer.wait_time = 1.0
	_resend_timer.one_shot = false
	_resend_timer.timeout.connect(_on_resend_tick)
	add_child(_resend_timer)

	if get_viewport():
		get_viewport().size_changed.connect(_clamp_dialog_bounds)
	_clamp_dialog_bounds()

	step1_container.visible = true
	step2_container.visible = false
	step3_container.visible = false
	_update_stepper(1)
	_on_phone_text_changed(input_phone.text)
	_on_username_text_changed(input_username.text)
	_refresh_otp_slots()


func _clamp_dialog_bounds() -> void:
	if ResponsiveUI != null:
		ResponsiveUI.fit_dialog(self, 616.0, 560.0, 320.0, 320.0, true)
		_recenter_vertical()
		return
	var vp: Viewport = get_viewport()
	if not is_instance_valid(vp):
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0.0:
		return
	var target_w: float = clampf(vp_size.x - 40.0, 320.0, 616.0)
	custom_minimum_size.x = target_w
	offset_left = -target_w * 0.5
	offset_right = target_w * 0.5
	call_deferred("_recenter_vertical")


func _recenter_vertical() -> void:
	if not is_instance_valid(self):
		return
	var min_size: Vector2 = get_combined_minimum_size()
	var h: float = min_size.y
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		var vp_h: float = vp.get_visible_rect().size.y
		if vp_h > 0.0:
			h = minf(h, minf(560.0, vp_h - 40.0))
	h = clampf(h, 320.0, 580.0)
	offset_top = -h * 0.5
	offset_bottom = h * 0.5
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, h * 0.5)


func open() -> void:
	is_mandatory_username = false
	btn_close_top.visible = false
	btn_guest_login.visible = false
	or_separator.visible = false
	lbl_title.text = "به کافه فکر خوش آمدید"
	lbl_tagline.text = "با شماره موبایل وارد شوید تا امتیاز و پیشرفت شما همیشه محفوظ بماند"
	_clamp_dialog_bounds()
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step1()


func open_for_username_completion() -> void:
	is_mandatory_username = true
	btn_close_top.visible = false
	lbl_title.text = "انتخاب نام کاربری"
	lbl_tagline.text = "یک نام ماندگار برای حضور در میزهای رقابت و جدول امتیازات بسازید"
	_clamp_dialog_bounds()
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step3_username()


func open_for_phone_upgrade(reason: String = "") -> void:
	is_mandatory_username = false
	btn_close_top.visible = false
	btn_guest_login.visible = false
	or_separator.visible = false
	lbl_title.text = "ثبت شماره موبایل"
	lbl_tagline.text = "حساب کاربری خود را دائمی کنید تا در تمام رقابت‌های آنلاین شرکت کنید"
	_clamp_dialog_bounds()
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step1()
	if not reason.is_empty():
		_set_status(reason, "warn")


func close() -> void:
	if is_mandatory_username or not GameManager.is_logged_in or GameManager.is_guest or not GameManager.has_phone() or not GameManager.has_username():
		_set_status("برای ورود به بازی، لطفاً ابتدا شماره موبایل و نام کاربری خود را ثبت کنید.", "error")
		_shake_node(self)
		AudioManager.sfx_tap()
		return

	_stop_resend_countdown()
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		get_viewport().set_input_as_handled()


func _safe_grab_focus(control: Control) -> void:
	if not is_instance_valid(control) or not visible:
		return
	if OS.get_name() not in ["Android", "iOS"]:
		control.grab_focus()


# ==============================================================================
# STEP TRANSITIONS & STEPPER INDICATOR
# ==============================================================================

func _animate_step_in(container: Control) -> void:
	container.modulate.a = 0.0
	var tw: Tween = container.create_tween()
	tw.tween_property(container, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	call_deferred("_recenter_vertical")


func _update_stepper(active_step: int) -> void:
	var pills: Array[PanelContainer] = [step_pill_1, step_pill_2, step_pill_3]
	var labels: Array[Label] = [lbl_step_1, lbl_step_2, lbl_step_3]
	var titles: Array[String] = ["موبایل", "کد تأیید", "نام کاربری"]
	var nums: Array[String] = ["۱", "۲", "۳"]

	for i in range(3):
		var step_idx: int = i + 1
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 5.0
		sb.content_margin_bottom = 5.0

		if step_idx < active_step:
			# Completed step
			sb.bg_color = Color(0.10, 0.26, 0.16, 0.94)
			sb.border_color = Color(0.36, 0.80, 0.50, 0.88)
			labels[i].text = "✓ %s" % titles[i]
			labels[i].add_theme_color_override("font_color", Color(0.56, 0.95, 0.68, 1.0))
		elif step_idx == active_step:
			# Active step
			sb.bg_color = Color(0.28, 0.20, 0.08, 0.96)
			sb.border_color = Color(0.98, 0.82, 0.34, 0.98)
			labels[i].text = "%s. %s" % [nums[i], titles[i]]
			labels[i].add_theme_color_override("font_color", Color(1.0, 0.92, 0.54, 1.0))
		else:
			# Upcoming step
			sb.bg_color = Color(0.14, 0.09, 0.05, 0.86)
			sb.border_color = Color(0.45, 0.35, 0.20, 0.55)
			labels[i].text = "%s. %s" % [nums[i], titles[i]]
			labels[i].add_theme_color_override("font_color", Color(0.68, 0.61, 0.50, 0.85))
		pills[i].add_theme_stylebox_override("panel", sb)

	conn_1.color = Color(0.36, 0.82, 0.50, 0.85) if active_step >= 2 else Color(0.55, 0.43, 0.25, 0.42)
	conn_2.color = Color(0.36, 0.82, 0.50, 0.85) if active_step >= 3 else Color(0.55, 0.43, 0.25, 0.42)


func _show_step1() -> void:
	_stop_resend_countdown()
	step1_container.visible = true
	step2_container.visible = false
	step3_container.visible = false
	_update_stepper(1)
	if lbl_title.text == "تأیید شماره موبایل" or lbl_title.text == "انتخاب نام کاربری":
		lbl_title.text = "به کافه فکر خوش آمدید"
	lbl_tagline.text = "با شماره موبایل وارد شوید تا امتیاز و پیشرفت شما همیشه محفوظ بماند"
	_clear_status()
	_on_phone_text_changed(input_phone.text)
	_animate_step_in(step1_container)
	_safe_grab_focus(input_phone)


func _show_step2() -> void:
	step1_container.visible = false
	step2_container.visible = true
	step3_container.visible = false
	_update_stepper(2)
	lbl_title.text = "تأیید شماره موبایل"
	lbl_tagline.text = "کد ۴ رقمی پیامک‌شده را در کادر زیر وارد کنید"
	lbl_step2_subtitle.text_direction = Control.TEXT_DIRECTION_RTL
	lbl_step2_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var pretty_phone: String = _format_phone_fa(current_phone)
	if current_phone == "09131234567" or current_phone.ends_with("1234567"):
		lbl_step2_subtitle.text = "حساب آزمایشی: %s" % pretty_phone
		_otp_prefilled = true
		input_code.text = "1234"
		_set_status("کد آزمایشی ۱۲۳۴ به صورت خودکار تنظیم شد.", "success")
	else:
		lbl_step2_subtitle.text = "ارسال شد به %s" % pretty_phone
		_otp_prefilled = false
		input_code.text = ""
		_clear_status()

	_start_resend_countdown(RESEND_COOLDOWN_SEC)
	_refresh_otp_slots()
	_update_verify_button_state()
	_animate_step_in(step2_container)
	_safe_grab_focus(input_code)


func _show_step3_username() -> void:
	_stop_resend_countdown()
	step1_container.visible = false
	step2_container.visible = false
	step3_container.visible = true
	_update_stepper(3)
	lbl_title.text = "ساخت هویت بازیکنی"
	lbl_tagline.text = "یک نام ماندگار برای حضور در میزهای رقابت و جدول امتیازات انتخاب کنید"
	_clear_status()
	input_username.text = ""
	input_rep_id.text = ""
	referral_box.visible = false
	btn_toggle_referral.text = "کد معرف دارید؟ (اختیاری) ▾"
	_on_username_text_changed("")
	_animate_step_in(step3_container)
	_safe_grab_focus(input_username)


# ==============================================================================
# INPUT NORMALIZATION & LIVE VALIDATION
# ==============================================================================

func _to_ascii_digits(raw: String) -> String:
	var fa_digits: PackedStringArray = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var ar_digits: PackedStringArray = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
	var out: String = raw
	for i in range(10):
		out = out.replace(fa_digits[i], str(i))
		out = out.replace(ar_digits[i], str(i))
	return out


func _normalize_phone(raw: String) -> String:
	var cleaned: String = _to_ascii_digits(raw).strip_edges()
	cleaned = cleaned.replace(" ", "").replace("-", "").replace("\u200c", "")
	if cleaned.begins_with("+98"):
		cleaned = "0" + cleaned.substr(3)
	elif cleaned.begins_with("0098"):
		cleaned = "0" + cleaned.substr(4)
	elif cleaned.begins_with("98") and cleaned.length() == 12:
		cleaned = "0" + cleaned.substr(2)
	elif cleaned.begins_with("9") and cleaned.length() == 10:
		cleaned = "0" + cleaned
	return cleaned


func _is_valid_iran_phone(normalized: String) -> bool:
	if normalized.length() != 11 or not normalized.begins_with("09"):
		return false
	for i in range(normalized.length()):
		var ch: String = normalized.substr(i, 1)
		if ch < "0" or ch > "9":
			return false
	return true


func _format_phone_fa(normalized: String) -> String:
	var fa: String = GameManager.to_fa_num(normalized)
	if fa.length() == 11:
		return "\u2066%s %s %s\u2069" % [fa.substr(0, 4), fa.substr(4, 3), fa.substr(7, 4)]
	return "\u2066%s\u2069" % fa


func _on_phone_text_changed(new_text: String) -> void:
	var norm: String = _normalize_phone(new_text)
	var valid: bool = _is_valid_iran_phone(norm)
	if valid:
		lbl_phone_badge.text = "شماره معتبر است ✓"
		lbl_phone_badge.add_theme_color_override("font_color", Color(0.52, 0.94, 0.65, 1.0))
	elif norm.is_empty():
		lbl_phone_badge.text = "۱۱ رقم با ۰۹"
		lbl_phone_badge.add_theme_color_override("font_color", Color(0.78, 0.70, 0.56, 0.9))
	else:
		lbl_phone_badge.text = "%s / ۱۱ رقم" % GameManager.to_fa_num(norm.length())
		lbl_phone_badge.add_theme_color_override("font_color", Color(0.98, 0.80, 0.36, 0.95))

	if not _is_sending_code:
		btn_send_code.disabled = not valid
		btn_send_code.modulate = Color.WHITE if valid else Color(0.70, 0.70, 0.70, 0.62)


func _on_code_text_changed(new_text: String) -> void:
	var ascii_only: String = _to_ascii_digits(new_text)
	var digits_only: String = ""
	for i in range(ascii_only.length()):
		var ch: String = ascii_only.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits_only += ch
			if digits_only.length() >= 4:
				break
	if digits_only != new_text:
		input_code.text = digits_only
		input_code.caret_column = digits_only.length()

	_refresh_otp_slots()
	_update_verify_button_state()

	# Smooth auto-submit once the user manually completes all 4 digits
	if digits_only.length() == 4 and not _otp_prefilled and not _is_verifying_code and step2_container.visible:
		get_tree().create_timer(0.18).timeout.connect(func():
			if is_instance_valid(self) and step2_container.visible and not _is_verifying_code:
				if _to_ascii_digits(input_code.text).strip_edges().length() == 4:
					_on_verify_code_pressed()
		)
	if digits_only.length() < 4:
		_otp_prefilled = false


func _refresh_otp_slots() -> void:
	var digits: String = _to_ascii_digits(input_code.text)
	var active_idx: int = mini(digits.length(), 3)
	var has_focus: bool = input_code.has_focus()

	for i in range(_otp_slots.size()):
		var slot: PanelContainer = _otp_slots[i]
		if not is_instance_valid(slot):
			continue
		var lbl: Label = slot.get_node_or_null("Digit") as Label
		var is_filled: bool = i < digits.length()
		var is_active: bool = (i == active_idx and has_focus and not is_filled) or (i == 3 and digits.length() == 4 and has_focus)

		if is_instance_valid(lbl):
			if is_filled:
				lbl.text = GameManager.to_fa_num(digits.substr(i, 1))
				lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
			else:
				lbl.text = "•"
				lbl.add_theme_color_override("font_color", Color(0.55, 0.46, 0.34, 0.45))

		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		if is_active:
			sb.bg_color = Color(0.15, 0.10, 0.05, 0.98)
			sb.border_color = Color(1.0, 0.86, 0.36, 1.0)
			sb.shadow_color = Color(1.0, 0.82, 0.30, 0.25)
			sb.shadow_size = 0 if ResponsiveUI.is_mobile() else 6
		elif is_filled:
			sb.bg_color = Color(0.12, 0.18, 0.11, 0.96)
			sb.border_color = Color(0.42, 0.84, 0.52, 0.90)
		else:
			sb.bg_color = Color(0.08, 0.05, 0.03, 0.96)
			sb.border_color = Color(0.56, 0.43, 0.24, 0.78)
		slot.add_theme_stylebox_override("panel", sb)


func _update_verify_button_state() -> void:
	if _is_verifying_code:
		return
	var ready_to_verify: bool = _to_ascii_digits(input_code.text).strip_edges().length() == 4
	btn_verify_code.disabled = not ready_to_verify
	btn_verify_code.modulate = Color.WHITE if ready_to_verify else Color(0.70, 0.70, 0.70, 0.62)


func _on_username_text_changed(new_text: String) -> void:
	var trimmed: String = new_text.strip_edges()
	var length: int = trimmed.length()
	var valid: bool = length >= 3

	lbl_char_count.text = "%s / ۳۰" % GameManager.to_fa_num(length)
	if valid:
		lbl_char_count.add_theme_color_override("font_color", Color(0.52, 0.94, 0.65, 1.0))
		lbl_username_hint.text = "نام کاربری معتبر و آماده ثبت است ✓"
		lbl_username_hint.add_theme_color_override("font_color", Color(0.52, 0.94, 0.65, 0.96))
	else:
		lbl_char_count.add_theme_color_override("font_color", Color(0.76, 0.68, 0.56, 0.9))
		lbl_username_hint.text = "حداقل ۳ کاراکتر — این نام در مسابقات و جدول رده‌بندی نمایش داده می‌شود."
		lbl_username_hint.add_theme_color_override("font_color", Color(0.78, 0.71, 0.58, 0.92))

	if not _is_submitting_username:
		btn_submit_username.disabled = not valid
		btn_submit_username.modulate = Color.WHITE if valid else Color(0.70, 0.70, 0.70, 0.62)


func _on_toggle_referral_pressed() -> void:
	AudioManager.sfx_tap()
	referral_box.visible = not referral_box.visible
	btn_toggle_referral.text = "بستن بخش کد معرف ▲" if referral_box.visible else "کد معرف دارید؟ (اختیاری) ▾"
	call_deferred("_recenter_vertical")
	if referral_box.visible:
		_safe_grab_focus(input_rep_id)


# ==============================================================================
# RESEND COUNTDOWN TIMER
# ==============================================================================

func _start_resend_countdown(seconds: int) -> void:
	_resend_seconds_left = seconds
	_update_resend_button_ui()
	if is_instance_valid(_resend_timer):
		_resend_timer.start()


func _stop_resend_countdown() -> void:
	if is_instance_valid(_resend_timer):
		_resend_timer.stop()
	_resend_seconds_left = 0


func _on_resend_tick() -> void:
	_resend_seconds_left = maxi(0, _resend_seconds_left - 1)
	_update_resend_button_ui()
	if _resend_seconds_left <= 0 and is_instance_valid(_resend_timer):
		_resend_timer.stop()


func _update_resend_button_ui() -> void:
	if not is_instance_valid(btn_resend_code):
		return
	if _resend_seconds_left > 0:
		btn_resend_code.disabled = true
		btn_resend_code.text = "ارسال مجدد کد تا %s ثانیه دیگر" % GameManager.to_fa_num(_resend_seconds_left)
	else:
		btn_resend_code.disabled = false
		btn_resend_code.text = "ارسال مجدد کد تأیید"


func _on_resend_code_pressed() -> void:
	if _resend_seconds_left > 0 or _is_sending_code or current_phone.is_empty():
		return
	AudioManager.sfx_tap()
	_is_sending_code = true
	btn_resend_code.disabled = true
	btn_resend_code.text = "در حال ارسال مجدد..."
	_set_status("در حال ارسال مجدد کد تأیید...", "warn")

	NetworkManager.api.send_phone_code(current_phone, func(success: bool, _code: int, data: Variant):
		_is_sending_code = false
		if not is_instance_valid(self):
			return
		if success:
			_set_status("کد تأیید جدید برای شماره شما ارسال شد ✓", "success")
			_start_resend_countdown(RESEND_COOLDOWN_SEC)
		else:
			var err_detail: String = "ارسال مجدد ناموفق بود. لطفاً دوباره تلاش کنید."
			if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("detail"):
				err_detail = str((data as Dictionary)["detail"])
			_set_status(err_detail, "error")
			_update_resend_button_ui()
	)


# ==============================================================================
# STATUS BANNER & MICRO-FEEDBACK
# ==============================================================================

func _clear_status() -> void:
	if is_instance_valid(status_banner):
		status_banner.visible = false
	if is_instance_valid(lbl_status):
		lbl_status.text = ""
	call_deferred("_recenter_vertical")


func _set_status(msg: String, kind: String = "info") -> void:
	if msg.is_empty():
		_clear_status()
		return
	lbl_status.text = msg
	lbl_status.add_theme_font_size_override("font_size", 13)
	status_banner.visible = true
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0

	if kind == "error":
		sb.bg_color = Color(0.28, 0.10, 0.10, 0.94)
		sb.border_color = Color(0.88, 0.36, 0.34, 0.88)
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.68, 0.66, 1.0))
	elif kind == "success":
		sb.bg_color = Color(0.10, 0.27, 0.16, 0.94)
		sb.border_color = Color(0.36, 0.82, 0.50, 0.88)
		lbl_status.add_theme_color_override("font_color", Color(0.60, 0.96, 0.72, 1.0))
	else:
		sb.bg_color = Color(0.26, 0.19, 0.08, 0.94)
		sb.border_color = Color(0.92, 0.74, 0.32, 0.86)
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55, 1.0))

	status_banner.add_theme_stylebox_override("panel", sb)
	call_deferred("_recenter_vertical")


func _shake_node(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var orig_x: float = target.position.x
	var tw: Tween = target.create_tween()
	tw.tween_property(target, "position:x", orig_x - 8.0, 0.045)
	tw.tween_property(target, "position:x", orig_x + 8.0, 0.055)
	tw.tween_property(target, "position:x", orig_x - 5.0, 0.045)
	tw.tween_property(target, "position:x", orig_x, 0.045)


# ==============================================================================
# AUTH API ACTIONS
# ==============================================================================

func _on_send_code_pressed() -> void:
	if _is_sending_code:
		return
	var norm_phone: String = _normalize_phone(input_phone.text)
	if not _is_valid_iran_phone(norm_phone):
		AudioManager.sfx_tap()
		_set_status("لطفاً شماره موبایل معتبر ۱۱ رقمی وارد کنید (مثال: ۰۹۱۲۳۴۵۶۷۸۹)", "error")
		_shake_node(phone_card)
		return

	AudioManager.sfx_button()
	current_phone = norm_phone
	_is_sending_code = true
	btn_send_code.disabled = true
	btn_send_code.text = "در حال ارسال کد..."
	_set_status("در حال ارسال کد تأیید پیامکی...", "warn")

	NetworkManager.api.send_phone_code(current_phone, func(success: bool, _code: int, data: Variant):
		_is_sending_code = false
		if not is_instance_valid(self):
			return
		btn_send_code.text = "دریافت کد تأیید"
		_on_phone_text_changed(input_phone.text)
		if success:
			print("[Login] Code sent successfully to %s" % current_phone)
			_show_step2()
		else:
			var err_detail: String = "خطا در برقراری ارتباط با سرور. لطفاً اتصال اینترنت را بررسی کنید."
			if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("detail"):
				err_detail = str((data as Dictionary)["detail"])
			_set_status(err_detail, "error")
			_shake_node(phone_card)
	)


func _on_guest_login_pressed() -> void:
	AudioManager.sfx_button()
	print("[Login] User chose Guest login.")
	GameManager.start_guest_session()
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
		login_completed.emit()
	)


func _on_verify_code_pressed() -> void:
	if _is_verifying_code:
		return
	var code_text: String = _to_ascii_digits(input_code.text).strip_edges()
	if code_text.length() < 4:
		AudioManager.sfx_tap()
		_set_status("لطفاً کد تأیید ۴ رقمی را کامل وارد کنید.", "error")
		_shake_node(otp_card)
		return

	AudioManager.sfx_button()
	_is_verifying_code = true
	btn_verify_code.disabled = true
	btn_verify_code.text = "در حال بررسی کد..."
	_set_status("در حال تأیید کد...", "warn")

	NetworkManager.api.verify_code(current_phone, code_text, GameManager.device_id, func(success: bool, _resp_code: int, data: Variant):
		_is_verifying_code = false
		if not is_instance_valid(self):
			return
		btn_verify_code.text = "تأیید و ورود به بازی"
		_update_verify_button_state()
		if success and typeof(data) == TYPE_DICTIONARY:
			var d: Dictionary = data as Dictionary
			var token: String = str(d.get("token", ""))
			var raw_user: Variant = d.get("user_data", {})
			var user_data: Dictionary = raw_user as Dictionary if typeof(raw_user) == TYPE_DICTIONARY else {}
			user_data["phone"] = current_phone

			GameManager.set_session(token, user_data, true)

			var uname: String = str(user_data.get("username", user_data.get("name", ""))).strip_edges()
			if uname.is_empty() or uname == "Guest" or uname == "کاربر مهمان":
				print("[Login] New user registered without username. Demanding username in Step 3.")
				is_mandatory_username = true
				btn_close_top.visible = false
				_show_step3_username()
			else:
				print("[Login] Existing user %s logged in successfully." % uname)
				_stop_resend_countdown()
				ActionVFXManager.animate_dialog_close(self, null, func():
					closed.emit()
					login_completed.emit()
				)
		else:
			var err_msg: String = "کد وارد شده اشتباه یا منقضی شده است."
			if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("detail"):
				err_msg = str((data as Dictionary)["detail"])
			_set_status(err_msg, "error")
			_shake_node(otp_card)
	)


func _on_submit_username_pressed() -> void:
	if _is_submitting_username:
		return
	var uname: String = input_username.text.strip_edges()
	if uname.length() < 3:
		AudioManager.sfx_tap()
		_set_status("نام کاربری باید حداقل ۳ کاراکتر باشد.", "error")
		_shake_node(username_card)
		return

	AudioManager.sfx_button()
	var rep_id: String = _to_ascii_digits(input_rep_id.text).strip_edges().to_upper()
	_is_submitting_username = true
	btn_submit_username.disabled = true
	btn_submit_username.text = "در حال ثبت اطلاعات..."
	_set_status("در حال ثبت نام کاربری...", "warn")

	var phone_to_send: String = current_phone if not current_phone.is_empty() else GameManager.get_phone()
	NetworkManager.api.complete_registration(uname, rep_id, phone_to_send, func(success: bool, resp_code: int, data: Variant):
		_is_submitting_username = false
		if not is_instance_valid(self):
			return
		btn_submit_username.text = "ثبت نام و شروع بازی"
		_on_username_text_changed(input_username.text)
		if success:
			print("[Login] Username '%s' registered successfully!" % uname)
			GameManager.user_data["username"] = uname
			GameManager.user_data["name"] = uname
			GameManager.set_session(GameManager.token, GameManager.user_data, true)

			is_mandatory_username = false
			btn_close_top.visible = false

			ActionVFXManager.animate_dialog_close(self, null, func():
				closed.emit()
				login_completed.emit()
			)
		else:
			var err_msg: String = "خطا در ثبت نام کاربری. ممکن است این نام قبلاً انتخاب شده باشد."
			if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("detail"):
				err_msg = str((data as Dictionary)["detail"])
			elif resp_code == 0:
				err_msg = "عدم برقراری ارتباط با سرور. لطفاً اینترنت خود را بررسی کنید."
			_set_status(err_msg, "error")
			_shake_node(username_card)
	)
