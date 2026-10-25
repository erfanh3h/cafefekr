extends PanelContainer

# Login Dialog Controller
# Multi-step auth flow matching Flutter app:
# Step 1: Enter mobile number -> calls POST /enter, or enter as Guest
# Step 2: Enter SMS OTP code -> calls POST /code, saves token
# Step 3: Enter Username (Mandatory for new users, cannot proceed or dismiss without entering)

signal login_completed()
signal closed()

@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var lbl_status: Label = $Margin/VBox/LblStatus

# Step 1: Phone
@onready var step1_container: VBoxContainer = $Margin/VBox/Step1_Phone
@onready var input_phone: LineEdit = $Margin/VBox/Step1_Phone/InputPhone
@onready var btn_send_code: Button = $Margin/VBox/Step1_Phone/BtnSendCode
@onready var btn_guest_login: Button = $Margin/VBox/Step1_Phone/BtnGuestLogin

# Step 2: SMS Code
@onready var step2_container: VBoxContainer = $Margin/VBox/Step2_Code
@onready var lbl_step2_subtitle: Label = $Margin/VBox/Step2_Code/LblSubtitle
@onready var input_code: LineEdit = $Margin/VBox/Step2_Code/InputCode
@onready var btn_verify_code: Button = $Margin/VBox/Step2_Code/BtnVerifyCode
@onready var btn_back_phone: Button = $Margin/VBox/Step2_Code/BtnBackPhone

# Step 3: Username Setup
@onready var step3_container: VBoxContainer = $Margin/VBox/Step3_Username
@onready var input_username: LineEdit = $Margin/VBox/Step3_Username/InputUsername
@onready var input_rep_id: LineEdit = $Margin/VBox/Step3_Username/InputRepId
@onready var btn_submit_username: Button = $Margin/VBox/Step3_Username/BtnSubmitUsername

var current_phone: String = ""
var is_mandatory_username: bool = false

func _ready() -> void:
	KenneyUI.style_button(btn_send_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_verify_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_submit_username, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_back_phone, KenneyUI.COLOR_GREY)
	KenneyUI.style_button(btn_guest_login, KenneyUI.COLOR_BLUE)
	
	btn_send_code.pressed.connect(_on_send_code_pressed)
	btn_guest_login.pressed.connect(_on_guest_login_pressed)
	btn_verify_code.pressed.connect(_on_verify_code_pressed)
	btn_back_phone.pressed.connect(_show_step1)
	btn_submit_username.pressed.connect(_on_submit_username_pressed)
	
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	input_phone.text_submitted.connect(func(_t): _on_send_code_pressed())
	input_code.text_submitted.connect(func(_t): _on_verify_code_pressed())
	input_username.text_submitted.connect(func(_t): _on_submit_username_pressed())
	
	step1_container.visible = true
	step2_container.visible = false
	step3_container.visible = false

func open() -> void:
	is_mandatory_username = false
	btn_close_top.visible = true
	btn_guest_login.visible = true
	lbl_title.text = "ورود به کافه فکر"
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step1()

func open_for_username_completion() -> void:
	is_mandatory_username = true
	btn_close_top.visible = false
	lbl_title.text = "انتخاب نام کاربری"
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step3_username()

func open_for_phone_upgrade(reason: String = "") -> void:
	is_mandatory_username = false
	btn_close_top.visible = true
	btn_guest_login.visible = false # Already a guest; need phone
	lbl_title.text = "ثبت شماره موبایل"
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step1()
	if not reason.is_empty():
		lbl_status.text = reason
		lbl_status.modulate = Color(1.0, 0.85, 0.35)

func close() -> void:
	if is_mandatory_username:
		lbl_status.text = "برای ورود به بازی، لطفاً ابتدا نام کاربری خود را ثبت کنید."
		lbl_status.modulate = Color(1.0, 0.4, 0.4)
		AudioManager.sfx_tap()
		return
		
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		if is_mandatory_username:
			get_viewport().set_input_as_handled()
			lbl_status.text = "برای ادامه بازی، ثبت نام کاربری الزامی است."
			lbl_status.modulate = Color(1.0, 0.4, 0.4)
			AudioManager.sfx_tap()

func _safe_grab_focus(control: Control) -> void:
	if not is_instance_valid(control) or not visible:
		return
	# On mobile devices (Android/iOS), grabbing focus forces virtual keyboard open automatically on app startup.
	# Only grab focus on desktop platforms where hardware keyboards are present.
	if OS.get_name() not in ["Android", "iOS"]:
		control.grab_focus()

func _show_step1() -> void:
	step1_container.visible = true
	step2_container.visible = false
	step3_container.visible = false
	lbl_status.text = ""
	_safe_grab_focus(input_phone)

func _show_step2() -> void:
	step1_container.visible = false
	step2_container.visible = true
	step3_container.visible = false
	lbl_step2_subtitle.text = "کد ارسال شده به %s را وارد کنید:" % current_phone
	lbl_status.text = ""
	input_code.text = ""
	_safe_grab_focus(input_code)

func _show_step3_username() -> void:
	step1_container.visible = false
	step2_container.visible = false
	step3_container.visible = true
	lbl_status.text = ""
	input_username.text = ""
	_safe_grab_focus(input_username)

func _normalize_phone(raw: String) -> String:
	var phone = raw.strip_edges()
	if phone.begins_with("+98"):
		return "0" + phone.substr(3)
	elif phone.begins_with("09"):
		return phone
	elif phone.begins_with("9"):
		return "0" + phone
	return phone

func _on_send_code_pressed() -> void:
	var raw = input_phone.text.strip_edges()
	if raw.length() < 10:
		lbl_status.text = "لطفاً شماره موبایل معتبر وارد کنید (مثال: ۰۹۱۲۳۴۵۶۷۸۹)"
		lbl_status.modulate = Color(1.0, 0.4, 0.4)
		return
		
	current_phone = _normalize_phone(raw)
	lbl_status.text = "در حال ارسال کد تأیید..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)
	btn_send_code.disabled = true
	
	NetworkManager.api.send_phone_code(current_phone, func(success: bool, _code: int, data: Variant):
		btn_send_code.disabled = false
		if success:
			print("[Login] Code sent successfully to %s" % current_phone)
			_show_step2()
		else:
			var err_detail = "خطا در برقراری ارتباط با سرور. لطفاً اتصال اینترنت را بررسی کنید."
			if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
				err_detail = str(data["detail"])
			lbl_status.text = err_detail
			lbl_status.modulate = Color(1.0, 0.3, 0.3)
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
	var code_text = input_code.text.strip_edges()
	if code_text.is_empty():
		lbl_status.text = "لطفاً کد تأیید را وارد کنید."
		lbl_status.modulate = Color(1.0, 0.4, 0.4)
		return
		
	lbl_status.text = "در حال تأیید کد..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)
	btn_verify_code.disabled = true
	
	NetworkManager.api.verify_code(current_phone, code_text, GameManager.device_id, func(success: bool, _resp_code: int, data: Variant):
		btn_verify_code.disabled = false
		if success and typeof(data) == TYPE_DICTIONARY:
			var token = str(data.get("token", ""))
			var user_data = data.get("user_data", {})
			if typeof(user_data) != TYPE_DICTIONARY:
				user_data = {}
			user_data["phone"] = current_phone
			
			GameManager.set_session(token, user_data, true)
			
			var uname = str(user_data.get("username", user_data.get("name", ""))).strip_edges()
			if uname.is_empty() or uname == "Guest" or uname == "کاربر مهمان":
				# New user without a username! Must prompt for username before entering game
				print("[Login] New user registered without username. Demanding username in Step 3.")
				is_mandatory_username = true
				btn_close_top.visible = false
				lbl_title.text = "انتخاب نام کاربری"
				_show_step3_username()
			else:
				# Existing user with established username
				print("[Login] Existing user %s logged in successfully." % uname)
				ActionVFXManager.animate_dialog_close(self, null, func():
					closed.emit()
					login_completed.emit()
				)
		else:
			var err_msg = "کد وارد شده اشتباه یا منقضی شده است."
			if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
				err_msg = str(data["detail"])
			lbl_status.text = err_msg
			lbl_status.modulate = Color(1.0, 0.3, 0.3)
	)

func _on_submit_username_pressed() -> void:
	var uname = input_username.text.strip_edges()
	if uname.length() < 3:
		lbl_status.text = "نام کاربری باید حداقل ۳ حرف باشد."
		lbl_status.modulate = Color(1.0, 0.4, 0.4)
		return
		
	var rep_id = input_rep_id.text.strip_edges()
	lbl_status.text = "در حال ثبت نام کاربری..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)
	btn_submit_username.disabled = true
	
	var phone_to_send = current_phone if not current_phone.is_empty() else GameManager.get_phone()
	NetworkManager.api.complete_registration(uname, rep_id, phone_to_send, func(success: bool, resp_code: int, data: Variant):
		btn_submit_username.disabled = false
		if success:
			print("[Login] Username '%s' registered successfully!" % uname)
			GameManager.user_data["username"] = uname
			GameManager.user_data["name"] = uname
			GameManager.set_session(GameManager.token, GameManager.user_data, true)
			
			is_mandatory_username = false
			btn_close_top.visible = true
			
			ActionVFXManager.animate_dialog_close(self, null, func():
				closed.emit()
				login_completed.emit()
			)
		else:
			var err_msg = "خطا در ثبت نام کاربری. ممکن است این نام قبلاً انتخاب شده باشد."
			if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
				err_msg = str(data["detail"])
			elif resp_code == 0:
				err_msg = "عدم برقراری ارتباط با سرور. لطفاً اینترنت خود را بررسی کنید."
			lbl_status.text = err_msg
			lbl_status.modulate = Color(1.0, 0.3, 0.3)
	)
