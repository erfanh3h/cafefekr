extends Control

## Sound Settings Popup for Cafe Fekr Top Utility Bar
## Features independent volume sliders and mute toggles for Music and SFX.
## Direct integration with AudioManager and persistent settings.

signal closed()

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var slider_music: HSlider = $CenterContainer/Panel/Margin/VBox/MusicRow/HBox/SliderMusic
@onready var check_music: CheckButton = $CenterContainer/Panel/Margin/VBox/MusicRow/HBox/CheckMusic
@onready var lbl_music_pct: Label = $CenterContainer/Panel/Margin/VBox/MusicRow/HBox/LblMusicPct
@onready var slider_sfx: HSlider = $CenterContainer/Panel/Margin/VBox/SfxRow/HBox/SliderSfx
@onready var check_sfx: CheckButton = $CenterContainer/Panel/Margin/VBox/SfxRow/HBox/CheckSfx
@onready var lbl_sfx_pct: Label = $CenterContainer/Panel/Margin/VBox/SfxRow/HBox/LblSfxPct
@onready var btn_close: Button = $CenterContainer/Panel/Margin/VBox/BtnClose
@onready var backdrop: ColorRect = $Backdrop

var _suppress_events: bool = false

func _ready() -> void:
	visible = false
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_YELLOW)
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")

	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)

	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)

	slider_music.value_changed.connect(_on_music_slider_changed)
	check_music.toggled.connect(_on_music_toggled)
	slider_sfx.value_changed.connect(_on_sfx_slider_changed)
	check_sfx.toggled.connect(_on_sfx_toggled)


func open() -> void:
	_suppress_events = true
	var m_vol = int(round(AudioManager.music_volume * 100.0))
	var s_vol = int(round(AudioManager.sfx_volume * 100.0))
	slider_music.value = m_vol
	lbl_music_pct.text = "%s%%" % GameManager.to_fa_num(m_vol)
	check_music.button_pressed = AudioManager.is_music_enabled
	slider_music.editable = AudioManager.is_music_enabled

	slider_sfx.value = s_vol
	lbl_sfx_pct.text = "%s%%" % GameManager.to_fa_num(s_vol)
	check_sfx.button_pressed = AudioManager.is_sound_enabled
	slider_sfx.editable = AudioManager.is_sound_enabled
	_suppress_events = false

	visible = true
	ActionVFXManager.animate_dialog_open(panel, self, false)


func close() -> void:
	ActionVFXManager.animate_dialog_close(panel, self, func():
		visible = false
		closed.emit()
	)


func _on_music_slider_changed(val: float) -> void:
	if _suppress_events:
		return
	lbl_music_pct.text = "%s%%" % GameManager.to_fa_num(int(val))
	AudioManager.set_music_volume(val / 100.0)


func _on_music_toggled(pressed: bool) -> void:
	if _suppress_events:
		return
	slider_music.editable = pressed
	AudioManager.set_music_enabled(pressed)


func _on_sfx_slider_changed(val: float) -> void:
	if _suppress_events:
		return
	lbl_sfx_pct.text = "%s%%" % GameManager.to_fa_num(int(val))
	AudioManager.set_sfx_volume(val / 100.0)


func _on_sfx_toggled(pressed: bool) -> void:
	if _suppress_events:
		return
	slider_sfx.editable = pressed
	AudioManager.set_sound_enabled(pressed)
	if pressed:
		AudioManager.sfx_tap()
