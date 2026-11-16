extends Control

## Antique Exit Confirmation Dialog
## Prevents accidental quits, asks user confirmation with Persian prompt,
## and gracefully quits application on Windows / Android when confirmed.

signal closed()
signal confirmed()

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var btn_confirm: Button = $CenterContainer/Panel/Margin/VBox/ButtonsRow/BtnConfirm
@onready var btn_cancel: Button = $CenterContainer/Panel/Margin/VBox/ButtonsRow/BtnCancel
@onready var backdrop: ColorRect = $Backdrop

func _ready() -> void:
	visible = false
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	KenneyUI.style_button(btn_confirm, KenneyUI.COLOR_RED)
	KenneyUI.style_button(btn_cancel, KenneyUI.COLOR_YELLOW)
	ActionVFXManager.apply_button_juice(btn_confirm, "tap_button")
	ActionVFXManager.apply_button_juice(btn_cancel, "tap_button")

	btn_cancel.pressed.connect(func():
		AudioManager.sfx_tap()
		close()
	)

	btn_confirm.pressed.connect(func():
		AudioManager.sfx_button()
		confirmed.emit()
		get_tree().quit()
	)

	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)


func open() -> void:
	visible = true
	ActionVFXManager.animate_dialog_open(panel, self, false)


func close() -> void:
	ActionVFXManager.animate_dialog_close(panel, self, func():
		visible = false
		closed.emit()
	)
