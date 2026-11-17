class_name PlayerActionButtons
extends VBoxContainer

## Cafe Fekr — Player Social Interactions Component
## Features 4 circular icon buttons for primary actions:
## 1. Add Friend (add_friend.png)
## 2. Private Chat (chat.png) — disabled unless friends
## 3. Report Player (report.png)
## 4. Block Player (block.png)

signal add_friend_pressed()
signal accept_friend_pressed()
signal private_message_pressed()
signal report_player_pressed()
signal block_player_pressed()

const TEX_ADD_FRIEND = preload("res://assets/images/add_friend.png")
const TEX_CHAT = preload("res://assets/images/chat.png")
const TEX_REPORT = preload("res://assets/images/report.png")
const TEX_BLOCK = preload("res://assets/images/block.png")

var _primary_row: HBoxContainer
var _btn_friend: TextureButton
var _btn_message: TextureButton
var _btn_report: TextureButton
var _btn_block: TextureButton

var _current_relationship: String = "none"


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	_build_ui()


func _build_ui() -> void:
	# Primary Actions Centered Row
	_primary_row = HBoxContainer.new()
	_primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_primary_row.add_theme_constant_override("separation", 14)
	add_child(_primary_row)

	# 1. Add Friend Icon Button
	_btn_friend = _create_icon_button(TEX_ADD_FRIEND, "افزودن به دوستان")
	_btn_friend.pressed.connect(func():
		AudioManager.sfx_button()
		if _current_relationship == "request_received":
			accept_friend_pressed.emit()
		else:
			add_friend_pressed.emit()
	)
	_primary_row.add_child(_btn_friend)

	# 2. Private Chat Icon Button (Only available for friends)
	_btn_message = _create_icon_button(TEX_CHAT, "گفتگوی خصوصی")
	_btn_message.pressed.connect(func():
		if _current_relationship != "friend":
			return
		AudioManager.sfx_tap()
		private_message_pressed.emit()
	)
	_primary_row.add_child(_btn_message)

	# 3. Report Player Icon Button (Gold Medallion with !)
	_btn_report = _create_icon_button(TEX_REPORT, "گزارش تخلف")
	_btn_report.pressed.connect(func():
		AudioManager.sfx_tap()
		report_player_pressed.emit()
	)
	_primary_row.add_child(_btn_report)

	# 4. Block Player Icon Button (Gold Medallion with Block Sign)
	_btn_block = _create_icon_button(TEX_BLOCK, "مسدود کردن بازیکن")
	_btn_block.pressed.connect(func():
		AudioManager.sfx_tap()
		block_player_pressed.emit()
	)
	_primary_row.add_child(_btn_block)


func _create_icon_button(tex: Texture2D, tip: String = "") -> TextureButton:
	var b := TextureButton.new()
	b.custom_minimum_size = Vector2(58, 58)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_normal = tex
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not tip.is_empty():
		b.tooltip_text = tip
	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


func _set_icon_btn_disabled(btn: TextureButton, is_disabled: bool) -> void:
	btn.disabled = is_disabled
	btn.modulate = Color(0.48, 0.48, 0.48, 0.45) if is_disabled else Color(1.0, 1.0, 1.0, 1.0)
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND


func setup(
	relationship: String = "none",
	is_self: bool = false,
	_is_clanmate: bool = false,
	_is_in_game: bool = false,
	can_dm: bool = true,
	_can_invite_game: bool = true
) -> void:
	_current_relationship = relationship

	if is_self:
		# When inspecting self, all action buttons must be present but disabled
		_set_icon_btn_disabled(_btn_friend, true)
		_set_icon_btn_disabled(_btn_message, true)
		_set_icon_btn_disabled(_btn_report, true)
		_set_icon_btn_disabled(_btn_block, true)
		return

	# 1. Friend Button State
	if relationship == "friend" or relationship == "request_sent":
		_set_icon_btn_disabled(_btn_friend, true)
	else:
		_set_icon_btn_disabled(_btn_friend, false)

	# 2. Chat Button State: MUST be disabled until user becomes a friend!
	var chat_enabled := (relationship == "friend" and can_dm)
	_set_icon_btn_disabled(_btn_message, not chat_enabled)

	# 3. Report & Block (always available for other players)
	_set_icon_btn_disabled(_btn_report, false)
	_set_icon_btn_disabled(_btn_block, false)
