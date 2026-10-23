extends PanelContainer

# Login Dialog Controller
# Two-step auth flow matching Flutter app:
# Step 1: Enter mobile number -> calls POST /enter
# Step 2: Enter SMS OTP code -> calls POST /code, saves token, auto-restores on future launches

signal login_completed()
signal closed()

@onready var step1_container: VBoxContainer = $Margin/VBox/Step1_Phone
@onready var step2_container: VBoxContainer = $Margin/VBox/Step2_Code

@onready var input_phone: LineEdit = $Margin/VBox/Step1_Phone/InputPhone
@onready var btn_send_code: Button = $Margin/VBox/Step1_Phone/BtnSendCode

@onready var lbl_step2_subtitle: Label = $Margin/VBox/Step2_Code/LblSubtitle
@onready var input_code: LineEdit = $Margin/VBox/Step2_Code/InputCode
@onready var btn_verify_code: Button = $Margin/VBox/Step2_Code/BtnVerifyCode
@onready var btn_back_phone: Button = $Margin/VBox/Step2_Code/BtnBackPhone

@onready var lbl_status: Label = $Margin/VBox/LblStatus
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop

var current_phone: String = ""

func _ready() -> void:
	KenneyUI.style_button(btn_send_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_verify_code, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_back_phone, KenneyUI.COLOR_GREY)
	
	btn_send_code.pressed.connect(_on_send_code_pressed)
	btn_verify_code.pressed.connect(_on_verify_code_pressed)
	btn_back_phone.pressed.connect(_show_step1)
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	input_phone.text_submitted.connect(func(_t): _on_send_code_pressed())
	input_code.text_submitted.connect(func(_t): _on_verify_code_pressed())
	
	_show_step1()

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	_show_step1()
	input_phone.grab_focus()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func _show_step1() -> void:
	step1_container.visible = true
	step2_container.visible = false
	lbl_status.text = ""
	input_phone.grab_focus()

func _show_step2() -> void:
	step1_container.visible = false
	step2_container.visible = true
	lbl_step2_subtitle.text = "کد ارسال شده به %s را وارد کنید:" % current_phone
	lbl_status.text = ""
	input_code.text = ""
	input_code.grab_focus()

func _normalize_phone(raw: String) -> String:
	var phone = raw.strip_edges()
	# Standardize to 09... or +98...
	if phone.begins_with("+98"):
		return phone
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
	lbl_status.text = "در حال ارسال کد..."
	lbl_status.modulate = Color(1.0, 0.85, 0.3)
	btn_send_code.disabled = true
	
	NetworkManager.api.send_phone_code(current_phone, func(success: bool, code: int, data: Variant):
		btn_send_code.disabled = false
		if success:
			print("[Login] Code sent successfully to %s" % current_phone)
			_show_step2()
		else:
			var err_detail = "خطا در برقراری ارتباط با سرور"
			if typeof(data) == TYPE_DICTIONARY and data.has("detail"):
				err_detail = str(data["detail"])
			lbl_status.text = err_detail
			lbl_status.modulate = Color(1.0, 0.3, 0.3)
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
	
	NetworkManager.api.verify_code(current_phone, code_text, GameManager.device_id, func(success: bool, resp_code: int, data: Variant):
		btn_verify_code.disabled = false
		if success and typeof(data) == TYPE_DICTIONARY:
			var token = data.get("token", "")
			var user_data = data.get("user_data", {})
			
			# Save session locally so user stays logged in permanently
			GameManager.set_session(token, user_data, true)
			print("[Login] Logged in successfully! Welcome %s" % GameManager.get_username())
			
			ActionVFXManager.animate_dialog_close(self, null, func():
				closed.emit()
				login_completed.emit()
			)
		else:
			lbl_status.text = "کد وارد شده اشتباه یا منقضی شده است."
			lbl_status.modulate = Color(1.0, 0.3, 0.3)
	)
