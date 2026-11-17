class_name PlayerActionButtons
extends VBoxContainer

## Cafe Fekr — Player Social Interactions Component
## Organizes primary and secondary player actions:
## Primary: Add Friend, Private Message, Invite to Game, More Actions
## Secondary: Invite to Clan, Spectate Live, Block Player, Report Player

signal add_friend_pressed()
signal accept_friend_pressed()
signal private_message_pressed()
signal invite_to_game_pressed()
signal invite_to_clan_pressed()
signal spectate_live_pressed()
signal block_player_pressed()
signal report_player_pressed()

var _primary_row: HBoxContainer
var _btn_friend: Control
var _btn_message: Button
var _btn_game_invite: Button
var _btn_more: Button

var _more_panel: PanelContainer
var _more_row: HBoxContainer
var _btn_clan_invite: Button
var _btn_spectate: Button
var _btn_block: Button
var _btn_report: Button


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build_ui()


func _build_ui() -> void:
	# Primary Actions Row
	_primary_row = HBoxContainer.new()
	_primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_row.add_theme_constant_override("separation", 8)
	add_child(_primary_row)

	# 1. Friend action placeholder (swapped in setup)
	_btn_friend = Control.new()
	_btn_friend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_row.add_child(_btn_friend)

	# 2. Private Message (Sapphire Blue Accent)
	_btn_message = CafeSocialTheme.make_button("پیام خصوصی", "sapphire", Vector2(0, 48), 20)
	_btn_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_message.pressed.connect(func():
		AudioManager.sfx_tap()
		private_message_pressed.emit()
	)
	_primary_row.add_child(_btn_message)

	# 3. Invite to Game (Gold Accent)
	_btn_game_invite = CafeSocialTheme.make_button("دعوت بازی", "gold", Vector2(0, 48), 20)
	_btn_game_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_game_invite.pressed.connect(func():
		AudioManager.sfx_tap()
		invite_to_game_pressed.emit()
	)
	_primary_row.add_child(_btn_game_invite)

	# 4. More Actions Toggle (Bronze/Muted)
	_btn_more = CafeSocialTheme.make_button("بیشتر ▾", "muted", Vector2(80, 48), 19)
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
	_btn_clan_invite = CafeSocialTheme.make_button("دعوت کلن", "bronze", Vector2(0, 42), 18)
	_btn_clan_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_clan_invite.pressed.connect(func():
		AudioManager.sfx_tap()
		invite_to_clan_pressed.emit()
	)
	_more_row.add_child(_btn_clan_invite)

	# Spectate Live (Emerald)
	_btn_spectate = CafeSocialTheme.make_button("تماشای زنده", "emerald", Vector2(0, 42), 18)
	_btn_spectate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_spectate.visible = false
	_btn_spectate.pressed.connect(func():
		AudioManager.sfx_button()
		spectate_live_pressed.emit()
	)
	_more_row.add_child(_btn_spectate)

	# Block Player (Muted Neutral/Danger)
	_btn_block = CafeSocialTheme.make_button("مسدود کردن", "muted", Vector2(0, 42), 18)
	_btn_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_block.pressed.connect(func():
		AudioManager.sfx_tap()
		block_player_pressed.emit()
	)
	_more_row.add_child(_btn_block)

	# Report Player (Crimson Destructive)
	_btn_report = CafeSocialTheme.make_button("گزارش تخلف", "crimson", Vector2(0, 42), 18)
	_btn_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_report.pressed.connect(func():
		AudioManager.sfx_tap()
		report_player_pressed.emit()
	)
	_more_row.add_child(_btn_report)


func setup(
	relationship: String = "none",
	is_in_game: bool = false,
	can_dm: bool = true,
	can_invite_game: bool = true,
	can_invite_clan: bool = true
) -> void:
	# 1. Setup Relationship Button
	for c in _btn_friend.get_children():
		c.queue_free()

	match relationship:
		"friend":
			var p_fr := CafeSocialTheme.make_badge_pill("✓ دوست شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 19)
			p_fr.set_anchors_preset(Control.PRESET_FULL_RECT)
			p_fr.custom_minimum_size = Vector2(0, 48)
			_btn_friend.add_child(p_fr)
		"request_sent":
			var p_sent := CafeSocialTheme.make_badge_pill("درخواست ارسال شد", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 18)
			p_sent.set_anchors_preset(Control.PRESET_FULL_RECT)
			p_sent.custom_minimum_size = Vector2(0, 48)
			_btn_friend.add_child(p_sent)
		"request_received":
			var b_acc := CafeSocialTheme.make_friend_button("accept", "پذیرش دوستی", Vector2(0, 48))
			b_acc.set_anchors_preset(Control.PRESET_FULL_RECT)
			b_acc.pressed.connect(func():
				AudioManager.sfx_button()
				accept_friend_pressed.emit()
			)
			_btn_friend.add_child(b_acc)
		_:
			var b_add := CafeSocialTheme.make_friend_button("add", "افزودن دوست", Vector2(0, 48))
			b_add.set_anchors_preset(Control.PRESET_FULL_RECT)
			b_add.pressed.connect(func():
				AudioManager.sfx_button()
				add_friend_pressed.emit()
			)
			_btn_friend.add_child(b_add)

	# 2. Control visibility based on state
	_btn_message.visible = can_dm
	_btn_game_invite.visible = can_invite_game
	_btn_clan_invite.visible = can_invite_clan
	_btn_spectate.visible = is_in_game
