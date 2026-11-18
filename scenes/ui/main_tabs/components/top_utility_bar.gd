extends Control

## Top Utility Bar for Cafe Fekr Five-Tab Shell
## Provides persistent, accessible utilities: Exit, Watch Live, and Sound Settings.
## Styled with authentic antique bronze/gold frames and tactile button juice.

signal exit_requested()
signal watch_live_requested()
signal sound_settings_requested()

@onready var btn_exit: Button = $HBox/BtnExit
@onready var btn_watch_live: Button = $HBox/BtnWatchLive
@onready var btn_sound: Button = $HBox/BtnSound
@onready var icon_sound: TextureRect = $HBox/BtnSound/IconSound

const TEX_SOUND_ON = preload("res://assets/images/badges/sound-on.png")
const TEX_SOUND_OFF = preload("res://assets/images/badges/sound-off.png")

func _ready() -> void:
	ActionVFXManager.apply_button_juice(btn_exit, "tap_button")
	ActionVFXManager.apply_button_juice(btn_watch_live, "tap_button")
	ActionVFXManager.apply_button_juice(btn_sound, "tap_button")

	btn_exit.pressed.connect(func():
		AudioManager.sfx_button()
		exit_requested.emit()
	)

	btn_watch_live.pressed.connect(func():
		AudioManager.sfx_button()
		watch_live_requested.emit()
	)

	btn_sound.pressed.connect(func():
		AudioManager.sfx_tap()
		sound_settings_requested.emit()
	)

	update_sound_icon()


func update_sound_icon() -> void:
	if not is_instance_valid(icon_sound):
		return
	if AudioManager.is_sound_enabled or AudioManager.is_music_enabled:
		icon_sound.texture = TEX_SOUND_ON
	else:
		icon_sound.texture = TEX_SOUND_OFF
