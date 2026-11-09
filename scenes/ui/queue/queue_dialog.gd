extends PanelContainer

# Queue Dialog Controller
# Displays search spinner, elapsed time, plays queue.mp3,
# handles match finding and Accept/Reject confirmation phase before Pre-Game.

signal queue_cancelled()
signal match_ready(game_id: String, game_type: String)
signal pre_game_ready(pre_game_id: String, queuers: Array)

@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_timer: Label = $Margin/VBox/LblTimer
@onready var lbl_status: Label = $Margin/VBox/LblStatus
@onready var btn_cancel: Button = $Margin/VBox/BtnCancel
@onready var spinner_container: Control = $Margin/VBox/SpinnerContainer
@onready var spinner: Control = $Margin/VBox/SpinnerContainer/Spinner

var elapsed_seconds: int = 0
var timer_active: bool = false
var search_timer: Timer

# Accept / Reject confirmation controls
var accept_container: HBoxContainer
var btn_accept: Button
var btn_reject: Button
var accept_countdown: int = 10
var accept_timer: Timer
var is_accept_phase: bool = false
var is_multi_rank_mode: bool = false
var _multi_rank_game_type: String = ""

static func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_RED)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_cancel.visible = false
	if is_instance_valid(btn_close_top):
		btn_close_top.pressed.connect(_on_cancel_pressed)
	
	search_timer = Timer.new()
	search_timer.wait_time = 1.0
	search_timer.timeout.connect(_on_timer_tick)
	add_child(search_timer)
	
	accept_timer = Timer.new()
	accept_timer.wait_time = 1.0
	accept_timer.timeout.connect(_on_accept_tick)
	add_child(accept_timer)
	
	_setup_accept_ui()
	
	NetworkManager.game_match_found.connect(_on_match_found)
	NetworkManager.queue_accept_game_received.connect(_on_accept_game_received)
	NetworkManager.pre_game_started.connect(_on_pre_game_started)
	NetworkManager.queue_game_canceled.connect(_on_game_canceled)
	NetworkManager.multi_rank_queue_status.connect(_on_multi_rank_queue_status)
	NetworkManager.multi_rank_match_ready.connect(_on_multi_rank_match_ready)
	NetworkManager.ranked_locked_received.connect(func(_data):
		stop_queue()
	)

func _setup_accept_ui() -> void:
	accept_container = HBoxContainer.new()
	accept_container.name = "AcceptContainer"
	accept_container.alignment = BoxContainer.ALIGNMENT_CENTER
	accept_container.add_theme_constant_override("separation", 24)
	accept_container.visible = false
	
	# Accept Button (Green)
	btn_accept = Button.new()
	btn_accept.text = "آماده‌ام"
	btn_accept.custom_minimum_size = Vector2(250, 96)
	btn_accept.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	btn_accept.add_theme_font_size_override("font_size", 28)
	KenneyUI.style_button(btn_accept, KenneyUI.COLOR_GREEN)
	btn_accept.pressed.connect(_on_accept_pressed)
	accept_container.add_child(btn_accept)
	
	# Reject Button (Red)
	btn_reject = Button.new()
	btn_reject.text = "انصراف"
	btn_reject.custom_minimum_size = Vector2(250, 96)
	btn_reject.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	btn_reject.add_theme_font_size_override("font_size", 28)
	KenneyUI.style_button(btn_reject, KenneyUI.COLOR_RED)
	btn_reject.pressed.connect(_on_reject_pressed)
	accept_container.add_child(btn_reject)
	
	$Margin/VBox.add_child(accept_container)

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if spinner and not is_accept_phase:
		spinner.rotation += delta * 2.5

func start_queue(requested_game_type: String = "") -> void:
	is_multi_rank_mode = false
	_multi_rank_game_type = ""
	set_process(true)
	ActionVFXManager.animate_dialog_open(self, null, true)
	elapsed_seconds = 0
	timer_active = true
	is_accept_phase = false
	
	lbl_title.text = "جستجوی حریف آنلاین"
	spinner_container.visible = true
	btn_cancel.visible = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = true
	accept_container.visible = false
	btn_accept.disabled = false
	btn_reject.disabled = false
	
	_update_timer_label()
	
	if not requested_game_type.is_empty():
		GameManager.set_game_type(requested_game_type)
		var g_info = GameRegistry.get_game_info(requested_game_type)
		var g_name = g_info.get("name_fa", requested_game_type)
		lbl_status.text = "در حال جستجوی حریف برای %s..." % g_name
		lbl_status.modulate = Color(1.0, 0.94, 0.55)
		search_timer.start()
		AudioManager.play_queue_music()
		NetworkManager.join_matchmaking_queue(requested_game_type)
	else:
		lbl_status.text = "در حال جستجوی حریف در رده‌بندی..."
		lbl_status.modulate = Color(1.0, 0.9, 0.4)
		search_timer.start()
		AudioManager.play_queue_music()
		NetworkManager.join_matchmaking_queue()

func start_multi_rank_queue(requested_game_type: String) -> void:
	var norm_type = GameRegistry.normalize_type(requested_game_type)
	is_multi_rank_mode = true
	_multi_rank_game_type = norm_type
	GameManager.set_game_type(norm_type)
	set_process(true)
	ActionVFXManager.animate_dialog_open(self, null, true)
	elapsed_seconds = 0
	timer_active = true
	is_accept_phase = false

	var g_info = GameRegistry.get_game_info(norm_type)
	var g_name = g_info.get("name_fa", norm_type)
	lbl_title.text = "صف رنک چهارنفره (%s)" % g_name
	spinner_container.visible = true
	btn_cancel.visible = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = true
	accept_container.visible = false
	btn_accept.disabled = false
	btn_reject.disabled = false

	_update_timer_label()
	lbl_status.text = "در انتظار تکمیل ظرفیت ۴ بازیکن (%s): ۱ از ۴ نفر..." % g_name
	lbl_status.modulate = Color(1.0, 0.94, 0.55)
	search_timer.start()
	AudioManager.play_queue_music()
	NetworkManager.join_multi_rank_queue(norm_type)

func _on_multi_rank_queue_status(queuers_count: int, required_count: int, game_type: String, _queuers: Array) -> void:
	if not is_multi_rank_mode or not timer_active:
		return
	var norm_type = GameRegistry.normalize_type(game_type if not game_type.is_empty() else _multi_rank_game_type)
	var g_info = GameRegistry.get_game_info(norm_type)
	var g_name = g_info.get("name_fa", norm_type)
	lbl_status.text = "در انتظار تکمیل ظرفیت (%s): %s از %s بازیکن..." % [g_name, _fa_digits(max(1, queuers_count)), _fa_digits(max(4, required_count))]
	lbl_status.modulate = Color(0.45, 0.95, 0.65) if queuers_count >= 2 else Color(1.0, 0.94, 0.55)

func _on_multi_rank_match_ready(_game_id: String, _game_type: String) -> void:
	if not is_multi_rank_mode:
		return
	timer_active = false
	is_accept_phase = false
	search_timer.stop()
	accept_timer.stop()
	lbl_title.text = "⚡ ظرفیت تکمیل شد! (۴ از ۴) ⚡"
	lbl_status.text = "هر ۴ بازیکن آماده هستند! ورود به میز مسابقه..."
	lbl_status.modulate = Color(0.25, 0.95, 0.48)
	AudioManager.sfx_queue_found()
	AudioManager.stop_music()
	await get_tree().create_timer(0.45).timeout
	visible = false

func stop_queue() -> void:
	var was_multi = is_multi_rank_mode
	is_multi_rank_mode = false
	timer_active = false
	is_accept_phase = false
	search_timer.stop()
	accept_timer.stop()
	AudioManager.play_theme_music()
	if was_multi:
		NetworkManager.leave_multi_rank_queue()
	else:
		NetworkManager.leave_matchmaking_queue()
	queue_cancelled.emit()
	ActionVFXManager.animate_dialog_close(self, null, func():
		visible = false
	)

func _on_timer_tick() -> void:
	elapsed_seconds += 1
	_update_timer_label()

func _update_timer_label() -> void:
	var mins = elapsed_seconds / 60
	var secs = elapsed_seconds % 60
	lbl_timer.text = "%02d:%02d" % [mins, secs]

func _on_cancel_pressed() -> void:
	AudioManager.sfx_button()
	stop_queue()

func _on_accept_game_received() -> void:
	# Server notified both players that a match was found; require Accept/Reject confirmation
	search_timer.stop()
	is_accept_phase = true
	
	AudioManager.sfx_queue_found()
	AudioManager.play_queue_music()
	
	lbl_title.text = "⚡ حریف پیدا شد! ⚡"
	lbl_status.text = "آماده شروع بازی هستی؟"
	lbl_status.modulate = Color(0.3, 0.95, 0.45)
	
	spinner_container.visible = false
	btn_cancel.visible = false
	if is_instance_valid(btn_close_top):
		btn_close_top.visible = false
	accept_container.visible = true
	btn_accept.disabled = false
	btn_reject.disabled = false
	
	accept_countdown = 15
	lbl_timer.text = "%d ثانیه" % accept_countdown
	accept_timer.start()

func _on_accept_tick() -> void:
	accept_countdown -= 1
	lbl_timer.text = "%d ثانیه" % max(0, accept_countdown)
	if accept_countdown <= 0:
		accept_timer.stop()
		# Timeout: auto-reject
		_on_reject_pressed()

func _on_accept_pressed() -> void:
	AudioManager.sfx_button()
	btn_accept.disabled = true
	btn_reject.disabled = true
	lbl_status.text = "در انتظار تأیید حریف..."
	lbl_status.modulate = Color(1.0, 0.88, 0.45)
	NetworkManager.send_queue_accept()

func _on_reject_pressed() -> void:
	AudioManager.sfx_button()
	accept_timer.stop()
	NetworkManager.send_queue_reject()
	stop_queue()

func _on_pre_game_started(pre_game_id: String, queuers: Array) -> void:
	# Both accepted! Transition to Pick & Ban scene
	accept_timer.stop()
	timer_active = false
	is_accept_phase = false
	
	lbl_status.text = "ورود به مرحله انتخاب و حذف بازی‌ها..."
	lbl_status.modulate = Color(0.3, 0.95, 0.5)
	
	await get_tree().create_timer(0.5).timeout
	visible = false
	pre_game_ready.emit(pre_game_id, queuers)

func _on_game_canceled() -> void:
	accept_timer.stop()
	search_timer.stop()
	lbl_status.text = "مسابقه لغو شد."
	lbl_status.modulate = Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(1.2).timeout
	stop_queue()

func _on_match_found(game_id: String) -> void:
	if not timer_active and not is_accept_phase:
		return
	timer_active = false
	is_accept_phase = false
	search_timer.stop()
	accept_timer.stop()
	lbl_status.text = "حریف پیدا شد! ورود به میز..."
	lbl_status.modulate = Color(0.2, 0.9, 0.4)
	
	AudioManager.sfx_queue_found()
	AudioManager.stop_music()
	
	await get_tree().create_timer(1.0).timeout
	visible = false
	match_ready.emit(game_id, GameTypes.TIC_TAC_TOE)
