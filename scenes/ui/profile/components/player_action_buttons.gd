class_name PlayerActionButtons
extends VBoxContainer

## Cafe Fekr — Player Social Interactions Component
## Features circular icon buttons for primary actions:
## 1. Add Friend (add_friend.png)
## 2. Private Chat (chat.png)
## 3. Invite Game (game.png)
## 4. More Actions Toggle (بیشتر ▾)
##
## And expandable drawer for secondary actions:
## Invite to Clan, Spectate Live, Block Player, Report Player

signal add_friend_pressed()
signal accept_friend_pressed()
signal private_message_pressed()
signal invite_to_game_pressed()
signal invite_to_clan_pressed()
signal spectate_live_pressed()
signal block_player_pressed()
signal report_player_pressed()

const TEX_ADD_FRIEND = preload("res://assets/images/add_friend.png")
const TEX_CHAT = preload("res://assets/images/chat.png")
const TEX_GAME = preload("res://assets/images/game.png")

var _primary_row: HBoxContainer
var _btn_friend: TextureButton
var _btn_message: TextureButton
var _btn_game_invite: TextureButton
var _btn_more: Button

var _more_panel: PanelContainer
var _more_row: HBoxContainer
var _btn_clan_invite: Button
var _btn_spectate: Button
var _btn_block: Button
var _btn_report: Button

var _current_relationship: String = "none"


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build_ui()


func _build_ui() -> void:
	# Primary Actions Centered Row
	_primary_row = HBoxContainer.new()
	_primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_primary_row.add_theme_constant_override("separation", 14)
	add_child(_primary_row)

	# 1. Add Friend Icon Button
	_btn_friend = _create_icon_button(TEX_ADD_FRIEND)
	_btn_friend.pressed.connect(func():
		AudioManager.sfx_button()
		if _current_relationship == "request_received":
			accept_friend_pressed.emit()
		else:
			add_friend_pressed.emit()
	)
	_primary_row.add_child(_btn_friend)

	# 2. Private Chat Icon Button
	_btn_message = _create_icon_button(TEX_CHAT)
	_btn_message.pressed.connect(func():
		AudioManager.sfx_tap()
		private_message_pressed.emit()
	)
	_primary_row.add_child(_btn_message)

	# 3. Invite Game Icon Button
	_btn_game_invite = _create_icon_button(TEX_GAME)
	_btn_game_invite.pressed.connect(func():
		AudioManager.sfx_tap()
		invite_to_game_pressed.emit()
	)
	_primary_row.add_child(_btn_game_invite)

	# 4. More Actions Toggle Button
	_btn_more = CafeSocialTheme.make_button("بیشتر ▾", "muted", Vector2(88, 52), 18)
	_btn_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_more.pressed.connect(func():
		AudioManager.sfx_tap()
		_more_panel.visible = not _more_panel.visible
		_btn_more.text = "بیشتر ▴" if _more_panel.visible else "بیشتر ▾"
	)
	_primary_row.add_child(_btn_more)

	# Secondary Actions Drawer (More Actions)
	_more_panel = PanelContainer.new()
	_more_panel.visible = false
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color(0.12, 0.08, 0.05, 0.96)
	mb.border_color = Color(0.48, 0.36, 0.20, 0.75)
	mb.set_border_width_all(1)
	mb.set_corner_radius_all(12)
	mb.content_margin_left = 10.0
	mb.content_margin_right = 10.0
	mb.content_margin_top = 8.0
	mb.content_margin_bottom = 8.0
	_more_panel.add_theme_stylebox_override("panel", mb)
	add_child(_more_panel)

	_more_row = HBoxContainer.new()
	_more_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more_row.add_theme_constant_override("separation", 6)
	_more_panel.add_child(_more_row)

	# Invite to Clan (Bronze)
	_btn_clan_invite = CafeSocialTheme.make_button("دعوت کلن", "bronze", Vector2(0, 42), 17)
	_btn_clan_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_clan_invite.pressed.connect(func():
		AudioManager.sfx_tap()
		invite_to_clan_pressed.emit()
	)
	_more_row.add_child(_btn_clan_invite)

	# Spectate Live (Emerald)
	_btn_spectate = CafeSocialTheme.make_button("تماشای زنده", "emerald", Vector2(0, 42), 17)
	_btn_spectate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_spectate.visible = false
	_btn_spectate.pressed.connect(func():
		AudioManager.sfx_button()
		spectate_live_pressed.emit()
	)
	_more_row.add_child(_btn_spectate)

	# Block Player (Muted Neutral/Danger)
	_btn_block = CafeSocialTheme.make_button("مسدود کردن", "muted", Vector2(0, 42), 17)
	_btn_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_block.pressed.connect(func():
		AudioManager.sfx_tap()
		block_player_pressed.emit()
	)
	_more_row.add_child(_btn_block)

	# Report Player (Crimson Destructive)
	_btn_report = CafeSocialTheme.make_button("گزارش تخلف", "crimson", Vector2(0, 42), 17)
	_btn_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_report.pressed.connect(func():
		AudioManager.sfx_tap()
		report_player_pressed.emit()
	)
	_more_row.add_child(_btn_report)


func _create_icon_button(tex: Texture2D) -> TextureButton:
	var b := TextureButton.new()
	b.custom_minimum_size = Vector2(58, 58)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_normal = tex
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b


func _set_icon_btn_disabled(btn: TextureButton, is_disabled: bool) -> void:
	btn.disabled = is_disabled
	btn.modulate = Color(0.48, 0.48, 0.48, 0.50) if is_disabled else Color(1.0, 1.0, 1.0, 1.0)
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND


func setup(
	relationship: String = "none",
	is_self: bool = false,
	is_clanmate: bool = false,
	is_in_game: bool = false,
	can_dm: bool = true,
	can_invite_game: bool = true
) -> void:
	_current_relationship = relationship

	if is_self:
		# When inspecting self, all action buttons must be present but disabled
		_set_icon_btn_disabled(_btn_friend, true)
		_set_icon_btn_disabled(_btn_message, true)
		_set_icon_btn_disabled(_btn_game_invite, true)
		_btn_clan_invite.disabled = true
		_btn_clan_invite.text = "دعوت کلن"
		_btn_spectate.visible = false
		_btn_block.disabled = true
		_btn_report.disabled = true
		return

	# 1. Friend Button State
	if relationship == "friend":
		_set_icon_btn_disabled(_btn_friend, true)
	elif relationship == "request_sent":
		_set_icon_btn_disabled(_btn_friend, true)
	else:
		_set_icon_btn_disabled(_btn_friend, false)

	# 2. Chat & Game Invite
	_set_icon_btn_disabled(_btn_message, not can_dm)
	_set_icon_btn_disabled(_btn_game_invite, not can_invite_game)

	# 3. Clan Invite (Disabled if already clanmate)
	if is_clanmate:
		_btn_clan_invite.disabled = true
		_btn_clan_invite.text = "هم‌کلنی شما"
	else:
		_btn_clan_invite.disabled = false
		_btn_clan_invite.text = "دعوت کلن"

	# 4. Spectate Live
	_btn_spectate.visible = is_in_game

	# 5. Block & Report
	_btn_block.disabled = false
	_btn_report.disabled = false
