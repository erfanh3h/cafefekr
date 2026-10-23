extends PanelContainer

# Queue Dialog Controller
# Mirrors QueuePage from Flutter:
# Displays search spinner, elapsed time, plays queue.mp3, and handles match finding

signal queue_cancelled()
signal match_ready(game_id: String, game_type: String)

@onready var lbl_timer: Label = $Margin/VBox/LblTimer
@onready var lbl_status: Label = $Margin/VBox/LblStatus
@onready var btn_cancel: Button = $Margin/VBox/BtnCancel
@onready var spinner: Control = $Margin/VBox/SpinnerContainer/Spinner

var elapsed_seconds: int = 0
var timer_active: bool = false
var search_timer: Timer

func _ready() -> void:
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_RED)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	
	search_timer = Timer.new()
	search_timer.wait_time = 1.0
	search_timer.timeout.connect(_on_timer_tick)
	add_child(search_timer)
	
	NetworkManager.game_match_found.connect(_on_match_found)

func _process(delta: float) -> void:
	if visible and spinner:
		spinner.rotation += delta * 2.5

func start_queue() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	elapsed_seconds = 0
	timer_active = true
	_update_timer_label()
	
	lbl_status.text = "در حال جستجوی حریف..."
	lbl_status.modulate = Color(1.0, 0.9, 0.4)
	
	search_timer.start()
	AudioManager.play_queue_music()
	
	NetworkManager.join_matchmaking_queue()

func stop_queue() -> void:
	timer_active = false
	search_timer.stop()
	AudioManager.play_theme_music()
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

func _on_match_found(game_id: String) -> void:
	if not timer_active:
		return
	timer_active = false
	search_timer.stop()
	lbl_status.text = "حریف پیدا شد! ورود به میز..."
	lbl_status.modulate = Color(0.2, 0.9, 0.4)
	
	AudioManager.sfx_queue_found()
	AudioManager.stop_music()
	
	# Delay slightly for audio & visual feedback
	await get_tree().create_timer(1.2).timeout
	visible = false
	match_ready.emit(game_id, GameTypes.TIC_TAC_TOE)
