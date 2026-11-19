class_name CommonHUD
extends Control

# Reusable Warm Classic Parlor Shared HUD Controller for Cafe Fekr (Godot 4)
# Portrait HUD with 100% unobstructed bottom space for game-specific controls,
# Split Sub-Header Rail (Left: 2D/3D, Center: Open Spacer, Right: Chat + Emoji),
# in-card right-aligned turn timer, 14x14px seat accent dot, inward-shifted emotes,
# and downward-opening popovers.

signal player_profile_clicked(player_index: int)
signal chat_pressed()
signal emote_pressed()
signal quick_chat_selected(message_index: int, message_text: String)
signal quick_emote_selected(emote_id: int)
signal camera_mode_toggled()
signal camera_zoom_in()
signal camera_zoom_out()
signal camera_reset()
signal audio_toggled(enabled: bool)
signal game_info_requested()
signal surrender_requested()

const CARD_HEIGHT_2P := 84.0
const CARD_HEIGHT_MULTI := 68.0
const RAIL_BUTTON_SIZE := Vector2(42, 42)
const RAIL_GAP := 10.0

const QUICK_CHATS: Array[String] = [
	"عجب حرکتی!",
	"نوبت منه!",
	"برنده منم!",
	"عالی بازی کردی!",
	"بهتره تسلیم شی!",
	"شانس آوردی!",
]

@onready var top_safe_margin: MarginContainer = $TopSafeMargin
@onready var players_row1: HBoxContainer = $TopSafeMargin/TopVBox/PlayersBlock/PlayersRow1
@onready var players_row2: HBoxContainer = $TopSafeMargin/TopVBox/PlayersBlock/PlayersRow2
@onready var menu_column: VBoxContainer = $TopSafeMargin/TopVBox/PlayersBlock/PlayersRow1/MenuColumn
@onready var btn_settings: Button = $TopSafeMargin/TopVBox/PlayersBlock/PlayersRow1/MenuColumn/BtnSettings
@onready var row2_spacer: Control = $TopSafeMargin/TopVBox/PlayersBlock/PlayersRow2/Row2Spacer

@onready var sub_header_rail: HBoxContainer = $TopSafeMargin/TopVBox/SubHeaderRail
@onready var btn_camera_toggle: Button = $TopSafeMargin/TopVBox/SubHeaderRail/BtnCameraToggle
@onready var img_camera_toggle: TextureRect = $TopSafeMargin/TopVBox/SubHeaderRail/BtnCameraToggle/Icon
@onready var btn_chat: Button = $TopSafeMargin/TopVBox/SubHeaderRail/RightActionGroup/BtnChat
@onready var btn_emote: Button = $TopSafeMargin/TopVBox/SubHeaderRail/RightActionGroup/BtnEmote

@onready var turn_status_toast: PanelContainer = $TurnStatusToast
@onready var lbl_turn_toast: Label = $TurnStatusToast/LblTurnToast
@onready var emote_layer: Control = $EmoteLayer

@onready var camera_popover_backdrop: Button = $CameraPopoverBackdrop
@onready var camera_popover: PanelContainer = $CameraPopover
@onready var btn_cam_2d3d: Button = $CameraPopover/HBox/BtnCam2D3D
@onready var img_cam_2d3d: TextureRect = $CameraPopover/HBox/BtnCam2D3D/Icon
@onready var btn_zoom_in: Button = $CameraPopover/HBox/BtnZoomIn
@onready var btn_zoom_out: Button = $CameraPopover/HBox/BtnZoomOut
@onready var btn_cam_reset: Button = $CameraPopover/HBox/BtnCamReset

@onready var picker_popover_backdrop: Button = $PickerPopoverBackdrop
@onready var picker_popover: PanelContainer = $PickerPopover
@onready var lbl_picker_title: Label = $PickerPopover/VBox/LblPickerTitle
@onready var picker_scroll: ScrollContainer = $PickerPopover/VBox/PickerScroll
@onready var picker_grid: GridContainer = $PickerPopover/VBox/PickerScroll/PickerGrid

@onready var settings_drawer: Control = $SettingsDrawer
@onready var drawer_card: PanelContainer = $SettingsDrawer/DrawerCard
@onready var btn_backdrop_close: Button = $SettingsDrawer/BtnBackdropClose
@onready var lbl_game_title: Label = $SettingsDrawer/DrawerCard/VBox/LblGameTitle
@onready var lbl_round_meta: Label = $SettingsDrawer/DrawerCard/VBox/LblRoundMeta
@onready var btn_audio_toggle: Button = $SettingsDrawer/DrawerCard/VBox/BtnAudioToggle
@onready var img_audio_toggle: TextureRect = $SettingsDrawer/DrawerCard/VBox/BtnAudioToggle/Icon
@onready var btn_game_info: Button = $SettingsDrawer/DrawerCard/VBox/BtnGameInfo
@onready var btn_surrender: Button = $SettingsDrawer/DrawerCard/VBox/BtnSurrender
@onready var btn_resume: Button = $SettingsDrawer/DrawerCard/VBox/BtnResume

static var _tex_2d: Texture2D = preload("res://assets/images/badges/2d.png")
static var _tex_3d: Texture2D = preload("res://assets/images/badges/3d.png")
static var _tex_sound_on: Texture2D = preload("res://assets/images/badges/sound-on.png")
static var _tex_sound_off: Texture2D = preload("res://assets/images/badges/sound-off.png")

var _cards: Dictionary = {} # player_index (1..4) -> Dictionary of controls
var _active_players: Array = [1]
var _player_count: int = 2
var _audio_enabled: bool = true
var _camera_popover_open: bool = false
var _picker_mode: String = "" # "" | "chat" | "emote"
var _safe_top: int = 16
var _safe_left: int = 10
var _safe_right: int = 10
var _toast_seq: int = 0
var _toast_tween: Tween = null
var _emote_seqs: Dictionary = {}


func _ready() -> void:
	_apply_theme_styles()
	_apply_safe_insets()
	_connect_signals()
	setup_players([
		{"index": 1, "name": "بازیکن ۱", "counter": 0},
		{"index": 2, "name": "بازیکن ۲", "counter": 0},
	])


func _apply_theme_styles() -> void:
	turn_status_toast.add_theme_stylebox_override("panel", HudTheme.make_turn_toast_style())
	camera_popover.add_theme_stylebox_override("panel", HudTheme.make_popover_panel_style())
	picker_popover.add_theme_stylebox_override("panel", HudTheme.make_popover_panel_style())
	drawer_card.add_theme_stylebox_override("panel", HudTheme.make_drawer_panel_style())

	HudTheme.apply_floating_button_style(btn_settings, false)
	HudTheme.apply_rail_button_style(btn_camera_toggle, false)
	HudTheme.apply_rail_button_style(btn_chat, false)
	HudTheme.apply_rail_button_style(btn_emote, false)
	btn_camera_toggle.custom_minimum_size = RAIL_BUTTON_SIZE
	btn_chat.custom_minimum_size = RAIL_BUTTON_SIZE
	btn_emote.custom_minimum_size = RAIL_BUTTON_SIZE

	HudTheme.apply_floating_button_style(btn_cam_2d3d, false)
	HudTheme.apply_floating_button_style(btn_zoom_in, false)
	HudTheme.apply_floating_button_style(btn_zoom_out, false)
	HudTheme.apply_floating_button_style(btn_cam_reset, false)

	HudTheme.apply_drawer_item_style(btn_audio_toggle, "default")
	HudTheme.apply_drawer_item_style(btn_game_info, "default")
	HudTheme.apply_drawer_item_style(btn_surrender, "danger")
	HudTheme.apply_drawer_item_style(btn_resume, "primary")
	HudTheme.configure_bidi_label(lbl_turn_toast, false)
	HudTheme.configure_bidi_label(lbl_picker_title, false)


func _apply_safe_insets() -> void:
	var insets: Dictionary = HudTheme.get_safe_insets(get_viewport())
	_safe_top = int(insets.get("top", 16))
	_safe_left = int(insets.get("left", 10))
	_safe_right = int(insets.get("right", 10))

	top_safe_margin.add_theme_constant_override("margin_top", _safe_top)
	top_safe_margin.add_theme_constant_override("margin_left", _safe_left)
	top_safe_margin.add_theme_constant_override("margin_right", _safe_right)
	_sync_top_footprint()


func _sync_top_footprint() -> void:
	var is_multi: bool = _player_count > 2
	var cards_h: float = (CARD_HEIGHT_MULTI * 2.0 + 6.0) if is_multi else CARD_HEIGHT_2P
	var rail_h: float = RAIL_BUTTON_SIZE.y
	var total_h: float = float(_safe_top) + cards_h + RAIL_GAP + rail_h + 6.0
	top_safe_margin.offset_bottom = clampf(total_h, 166.0, 260.0 if is_multi else 206.0)
	# Center TurnStatusToast inside the open middle area of SubHeaderRail
	var toast_y: float = float(_safe_top) + cards_h + RAIL_GAP + 4.0
	turn_status_toast.offset_top = toast_y
	turn_status_toast.offset_bottom = toast_y + 34.0


func _connect_signals() -> void:
	btn_settings.pressed.connect(_open_settings_drawer)
	btn_backdrop_close.pressed.connect(_close_settings_drawer)
	btn_resume.pressed.connect(_close_settings_drawer)

	btn_camera_toggle.pressed.connect(func():
		_close_picker_popover()
		if _camera_popover_open:
			_close_camera_popover()
		else:
			_open_camera_popover()
	)
	camera_popover_backdrop.pressed.connect(_close_camera_popover)

	btn_cam_2d3d.pressed.connect(func(): camera_mode_toggled.emit())
	btn_zoom_in.pressed.connect(func(): camera_zoom_in.emit())
	btn_zoom_out.pressed.connect(func(): camera_zoom_out.emit())
	btn_cam_reset.pressed.connect(func(): camera_reset.emit())

	btn_chat.pressed.connect(func():
		_close_camera_popover()
		chat_pressed.emit()
		_toggle_picker_popover("chat", btn_chat)
	)
	btn_emote.pressed.connect(func():
		_close_camera_popover()
		emote_pressed.emit()
		_toggle_picker_popover("emote", btn_emote)
	)
	picker_popover_backdrop.pressed.connect(_close_picker_popover)

	btn_audio_toggle.pressed.connect(func():
		set_audio_enabled(not _audio_enabled)
		audio_toggled.emit(_audio_enabled)
	)
	btn_game_info.pressed.connect(func():
		_close_settings_drawer()
		game_info_requested.emit()
	)
	btn_surrender.pressed.connect(func():
		_close_settings_drawer()
		surrender_requested.emit()
	)


func setup_players(players: Array) -> void:
	for bundle in _cards.values():
		var c: Control = bundle.get("card", null)
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()

	_player_count = clampi(players.size(), 2, 4)
	var is_multi: bool = _player_count > 2
	players_row2.visible = is_multi

	for i in range(_player_count):
		var p_data: Dictionary = players[i]
		var idx: int = int(p_data.get("index", i + 1))
		var card_bundle: Dictionary = _create_player_card(idx, p_data, is_multi)
		var target_row: HBoxContainer = players_row1 if i < 2 else players_row2
		target_row.add_child(card_bundle["card"])
		if target_row == players_row1:
			target_row.move_child(menu_column, target_row.get_child_count() - 1)
		else:
			target_row.move_child(row2_spacer, target_row.get_child_count() - 1)
		_cards[idx] = card_bundle

	_sync_top_footprint()
	set_active_player(int(players[0].get("index", 1)))


func _create_player_card(idx: int, p_data: Dictionary, compact: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.name = "PlayerCard%d" % idx
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT_MULTI if compact else CARD_HEIGHT_2P)
	card.add_theme_stylebox_override("panel", HudTheme.make_player_card_style(false, false, compact))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6 if compact else 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(hbox)

	var av_sz: Vector2 = Vector2(46, 46) if compact else Vector2(56, 56)
	var av_container := Control.new()
	av_container.custom_minimum_size = av_sz
	av_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(av_container)

	var av_tex := TextureRect.new()
	av_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	av_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if p_data.get("avatar_texture") is Texture2D:
		av_tex.texture = p_data["avatar_texture"]
	av_container.add_child(av_tex)

	# 14x14px seat accent dot with 2px dark walnut border at avatar corner
	var seat_dot := Panel.new()
	seat_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat_dot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	seat_dot.offset_left = -15
	seat_dot.offset_top = -15
	seat_dot.offset_right = -1
	seat_dot.offset_bottom = -1
	var sb_dot := StyleBoxFlat.new()
	sb_dot.bg_color = HudTheme.get_seat_accent(idx)
	sb_dot.border_color = HudTheme.COL_WALNUT_DEEP
	sb_dot.set_border_width_all(2)
	sb_dot.set_corner_radius_all(7)
	seat_dot.add_theme_stylebox_override("panel", sb_dot)
	av_container.add_child(seat_dot)

	var btn_prof := Button.new()
	btn_prof.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_prof.flat = true
	btn_prof.focus_mode = Control.FOCUS_NONE
	btn_prof.pressed.connect(func(): player_profile_clicked.emit(idx))
	av_container.add_child(btn_prof)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.add_theme_constant_override("separation", 2)
	hbox.add_child(info_box)

	var lbl_name := Label.new()
	lbl_name.text = str(p_data.get("name", "بازیکن %d" % idx))
	lbl_name.add_theme_font_override("font", HudTheme.get_ui_font())
	lbl_name.add_theme_font_size_override("font_size", 16 if compact else 18)
	lbl_name.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
	HudTheme.configure_bidi_label(lbl_name, true)
	info_box.add_child(lbl_name)

	var lbl_sub := Label.new()
	lbl_sub.visible = false
	lbl_sub.add_theme_font_override("font", HudTheme.get_ui_font())
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)
	lbl_sub.add_theme_stylebox_override("normal", HudTheme.make_status_pill_style(HudTheme.get_seat_accent(idx), 0.78))
	HudTheme.configure_bidi_label(lbl_sub, true)
	info_box.add_child(lbl_sub)

	var counter_badge := PanelContainer.new()
	counter_badge.custom_minimum_size = Vector2(36, 36) if compact else Vector2(40, 40)
	counter_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counter_badge.add_theme_stylebox_override("panel", HudTheme.make_score_badge_style("normal"))
	hbox.add_child(counter_badge)

	var lbl_counter := Label.new()
	lbl_counter.text = HudTheme.fa_digits(p_data.get("counter", 0))
	lbl_counter.add_theme_font_override("font", HudTheme.get_display_font())
	lbl_counter.add_theme_font_size_override("font_size", 24 if compact else 28)
	lbl_counter.add_theme_color_override("font_color", HudTheme.COL_TEXT_GOLD)
	lbl_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter_badge.add_child(lbl_counter)

	# In-card timer badge positioned inside the right side of the player card (vertically centered)
	var timer_chip := Label.new()
	timer_chip.name = "CardTimerChip"
	timer_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_chip.visible = false
	timer_chip.custom_minimum_size = Vector2(34, 24)
	timer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_chip.add_theme_font_override("font", HudTheme.get_ui_font())
	timer_chip.add_theme_font_size_override("font_size", 11)
	timer_chip.add_theme_color_override("font_color", HudTheme.COL_TEXT_GOLD)
	timer_chip.add_theme_stylebox_override("normal", HudTheme.make_timer_chip_style(false))
	timer_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(timer_chip)

	# Integrated bottom-edge progress timer inside CardChromeOverlay
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(overlay)

	var timer_fill: StyleBoxFlat = HudTheme.make_card_timer_fill_style(HudTheme.COL_GOLD_ACTIVE)
	var timer_bar := ProgressBar.new()
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar.show_percentage = false
	timer_bar.value = 100.0
	timer_bar.visible = false
	timer_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	timer_bar.offset_left = -4.0
	timer_bar.offset_right = 4.0
	timer_bar.offset_top = 2.0
	timer_bar.offset_bottom = 8.0
	timer_bar.add_theme_stylebox_override("background", HudTheme.make_card_timer_track_style())
	timer_bar.add_theme_stylebox_override("fill", timer_fill)
	overlay.add_child(timer_bar)

	return {
		"card": card,
		"avatar_container": av_container,
		"avatar": av_tex,
		"name": lbl_name,
		"sub": lbl_sub,
		"counter": lbl_counter,
		"counter_badge": counter_badge,
		"timer_bar": timer_bar,
		"timer_fill": timer_fill,
		"timer_chip": timer_chip,
	}


func set_active_player(player_index: int, prompt_text: String = "") -> void:
	set_simultaneous_active([player_index], prompt_text)


func set_simultaneous_active(indices: Array, prompt_text: String = "") -> void:
	_active_players = indices.duplicate()
	var compact: bool = _player_count > 2
	for idx in _cards.keys():
		var b: Dictionary = _cards[idx]
		var is_act: bool = _active_players.has(idx)
		(b["card"] as PanelContainer).add_theme_stylebox_override("panel", HudTheme.make_player_card_style(is_act, false, compact))
		(b["card"] as Control).modulate = Color.WHITE if is_act else Color(0.88, 0.85, 0.82, 0.94)
		(b["timer_bar"] as ProgressBar).visible = is_act
		(b["timer_chip"] as Label).visible = is_act and not (b["timer_chip"] as Label).text.is_empty()
	if not prompt_text.is_empty():
		show_turn_prompt(prompt_text)


func update_timer(remaining_sec: float, total_sec: float) -> void:
	var pct: float = clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
	var is_danger: bool = (remaining_sec <= 4.0 and remaining_sec > 0.0)
	var sec_text: String = "%s″" % HudTheme.fa_digits(maxi(0, int(ceil(remaining_sec))))
	var compact: bool = _player_count > 2
	for idx in _cards.keys():
		var b: Dictionary = _cards[idx]
		var is_act: bool = _active_players.has(idx)
		(b["timer_bar"] as ProgressBar).visible = is_act
		(b["timer_chip"] as Label).visible = is_act
		if is_act:
			(b["timer_bar"] as ProgressBar).value = pct
			(b["timer_fill"] as StyleBoxFlat).bg_color = HudTheme.COL_DANGER if is_danger else HudTheme.COL_GOLD_ACTIVE
			var t_chip: Label = b["timer_chip"] as Label
			t_chip.text = sec_text
			t_chip.add_theme_stylebox_override("normal", HudTheme.make_timer_chip_style(is_danger))
			t_chip.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82) if is_danger else HudTheme.COL_TEXT_GOLD)
			(b["card"] as PanelContainer).add_theme_stylebox_override("panel", HudTheme.make_player_card_style(true, is_danger, compact))


func update_counter(player_index: int, value: Variant, sub_status: String = "") -> void:
	if not _cards.has(player_index):
		return
	var b: Dictionary = _cards[player_index]
	(b["counter"] as Label).text = HudTheme.fa_digits(value)
	var lbl_sub: Label = b["sub"]
	lbl_sub.text = sub_status
	lbl_sub.visible = not sub_status.strip_edges().is_empty()


func show_turn_prompt(text: String, accent: Color = HudTheme.COL_TEXT_GOLD, persistent: bool = false, hold_sec: float = 1.8) -> void:
	_toast_seq += 1
	var my_seq: int = _toast_seq
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
		_toast_tween = null
	lbl_turn_toast.text = text
	lbl_turn_toast.add_theme_color_override("font_color", accent)
	turn_status_toast.visible = true
	turn_status_toast.modulate.a = 0.0
	_toast_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(turn_status_toast, "modulate:a", 1.0, 0.16)
	if not persistent:
		_toast_tween.tween_interval(hold_sec)
		_toast_tween.tween_property(turn_status_toast, "modulate:a", 0.0, 0.28)
		_toast_tween.tween_callback(func():
			if _toast_seq == my_seq and is_instance_valid(turn_status_toast):
				turn_status_toast.visible = false
		)


func show_emote(player_index: int, content: Variant, is_text: bool = false, hold_sec: float = 2.4) -> void:
	if not _cards.has(player_index):
		return
	var b: Dictionary = _cards[player_index]
	var card: Control = b["card"]
	var av_cont: Control = b["avatar_container"]

	var existing: Node = emote_layer.get_node_or_null("EmoteP%d" % player_index)
	if is_instance_valid(existing):
		existing.queue_free()

	var seq: int = int(_emote_seqs.get(player_index, 0)) + 1
	_emote_seqs[player_index] = seq

	var bubble := PanelContainer.new()
	bubble.name = "EmoteP%d" % player_index
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", HudTheme.make_emote_bubble_style(is_text))

	var vp_size: Vector2 = get_viewport_rect().size
	var vp_w: float = vp_size.x
	var max_text_w: float = clampf(vp_w - 196.0, 180.0, 276.0)
	var b_size: Vector2 = Vector2(max_text_w, 66.0) if is_text else Vector2(88.0, 88.0)
	bubble.custom_minimum_size = b_size
	bubble.size = b_size

	if is_text:
		var lbl := Label.new()
		lbl.text = str(content)
		lbl.add_theme_font_override("font", HudTheme.get_ui_font())
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HudTheme.configure_bidi_label(lbl, false)
		bubble.add_child(lbl)
	elif content is Texture2D:
		var tex_rect := TextureRect.new()
		tex_rect.texture = content
		tex_rect.custom_minimum_size = Vector2(70, 70)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bubble.add_child(tex_rect)

	emote_layer.add_child(bubble)

	# Anchor below player's avatar/card bottom edge AND offset inward toward horizontal center
	# so bubbles never collide with the Left (2D) or Right (Chat / Emoji) SubHeaderRail buttons.
	var card_rect: Rect2 = card.get_global_rect()
	var av_rect: Rect2 = av_cont.get_global_rect()
	var av_center_x: float = av_rect.get_center().x
	var is_left_seat: bool = av_center_x < (vp_w * 0.5)
	var left_clear: float = float(_safe_left) + RAIL_BUTTON_SIZE.x + 12.0
	var right_clear: float = float(_safe_right) + (RAIL_BUTTON_SIZE.x * 2.0 + 8.0) + 12.0
	var center_x: float = av_center_x + (40.0 if is_left_seat else -40.0)
	var min_x: float = left_clear
	var max_x: float = maxf(min_x, vp_w - right_clear - b_size.x)
	var anchor_x: float = clampf(center_x - b_size.x * 0.5, min_x, max_x)
	var anchor_y: float = maxf(card_rect.end.y, av_rect.end.y) + RAIL_GAP
	if is_text and (vp_w - left_clear - right_clear) < (b_size.x + 8.0):
		anchor_x = clampf((vp_w - b_size.x) * 0.5, 12.0, maxf(12.0, vp_w - b_size.x - 12.0))
		anchor_y = maxf(card_rect.end.y, av_rect.end.y) + RAIL_GAP + RAIL_BUTTON_SIZE.y + 6.0

	bubble.global_position = Vector2(anchor_x, anchor_y)
	bubble.pivot_offset = b_size * 0.5
	bubble.scale = Vector2(0.25, 0.25)
	bubble.modulate.a = 0.0

	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.06, 1.06), 0.18)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.14)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.10)

	await get_tree().create_timer(hold_sec).timeout
	if int(_emote_seqs.get(player_index, 0)) != seq or not is_instance_valid(bubble):
		return
	var fade: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(bubble, "scale", Vector2(0.88, 0.88), 0.20)
	fade.parallel().tween_property(bubble, "modulate:a", 0.0, 0.22)
	await fade.finished
	if is_instance_valid(bubble):
		bubble.queue_free()


func set_camera_mode(is_top_down: bool) -> void:
	var tex: Texture2D = _tex_3d if is_top_down else _tex_2d
	img_cam_2d3d.texture = tex
	img_camera_toggle.texture = tex


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	img_audio_toggle.texture = _tex_sound_on if enabled else _tex_sound_off
	btn_audio_toggle.text = "صدا و موسیقی: روشن" if enabled else "صدا و موسیقی: خاموش"


func set_spectator_mode(enabled: bool) -> void:
	btn_chat.visible = not enabled
	btn_emote.visible = not enabled
	btn_surrender.visible = not enabled


func set_game_meta(game_title: String, round_text: String) -> void:
	lbl_game_title.text = game_title
	lbl_round_meta.text = round_text


func _position_popover_below(panel: Control, anchor_btn: Control, panel_w: float, panel_h: float, align_right: bool) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var btn_rect: Rect2 = anchor_btn.get_global_rect()
	var x: float = (btn_rect.end.x - panel_w) if align_right else btn_rect.position.x
	x = clampf(x, float(_safe_left), maxf(float(_safe_left), vp_size.x - panel_w - float(_safe_right)))
	var y: float = clampf(btn_rect.end.y + 8.0, float(_safe_top), maxf(float(_safe_top), vp_size.y - panel_h - 16.0))
	panel.position = Vector2(x, y)
	panel.size = Vector2(panel_w, panel_h)
	panel.pivot_offset = Vector2(clampf(btn_rect.get_center().x - x, 16.0, panel_w - 16.0), 0.0)


func _open_camera_popover() -> void:
	_camera_popover_open = true
	camera_popover_backdrop.visible = true
	camera_popover.visible = true
	var pop_w: float = 224.0
	var pop_h: float = 64.0
	_position_popover_below(camera_popover, btn_camera_toggle, pop_w, pop_h, false)
	camera_popover.modulate.a = 0.0
	camera_popover.scale = Vector2(0.88, 0.72)
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera_popover, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(camera_popover, "modulate:a", 1.0, 0.12)
	HudTheme.apply_rail_button_style(btn_camera_toggle, true)


func _close_camera_popover() -> void:
	_camera_popover_open = false
	camera_popover_backdrop.visible = false
	camera_popover.visible = false
	camera_popover.scale = Vector2.ONE
	camera_popover.modulate.a = 1.0
	HudTheme.apply_rail_button_style(btn_camera_toggle, false)


func _toggle_picker_popover(mode: String, anchor_btn: Button) -> void:
	if _picker_mode == mode and picker_popover.visible:
		_close_picker_popover()
		return
	_open_picker_popover(mode, anchor_btn)


func _open_picker_popover(mode: String, anchor_btn: Button) -> void:
	_picker_mode = mode
	for ch in picker_grid.get_children():
		ch.queue_free()

	var is_chat: bool = (mode == "chat")
	lbl_picker_title.text = "💬 پیام‌های سریع" if is_chat else "😊 استیکر و ایموجی"
	picker_grid.columns = 2 if is_chat else 4

	if is_chat:
		for i in range(QUICK_CHATS.size()):
			var msg: String = QUICK_CHATS[i]
			var chat_btn := Button.new()
			chat_btn.text = msg
			chat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chat_btn.custom_minimum_size = Vector2(0, 44)
			HudTheme.apply_drawer_item_style(chat_btn, "default")
			chat_btn.add_theme_font_size_override("font_size", 14)
			var captured_i: int = i
			chat_btn.pressed.connect(func():
				_close_picker_popover()
				quick_chat_selected.emit(captured_i, msg)
			)
			picker_grid.add_child(chat_btn)
	else:
		for r_id in range(1, 13):
			var icon_btn := Button.new()
			icon_btn.custom_minimum_size = Vector2(68, 68)
			HudTheme.apply_rail_button_style(icon_btn, false)
			var tex_rect := TextureRect.new()
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.offset_left = 8
			tex_rect.offset_top = 8
			tex_rect.offset_right = -8
			tex_rect.offset_bottom = -8
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path: String = "res://assets/icons/Reactions/%d.png" % r_id
			if ResourceLoader.exists(icon_path):
				tex_rect.texture = load(icon_path) as Texture2D
			icon_btn.add_child(tex_rect)
			var captured_id: int = r_id
			icon_btn.pressed.connect(func():
				_close_picker_popover()
				quick_emote_selected.emit(captured_id)
			)
			picker_grid.add_child(icon_btn)

	var vp_w: float = get_viewport_rect().size.x
	var pop_w: float = clampf(vp_w - 28.0, 290.0, 344.0)
	var pop_h: float = 236.0 if is_chat else 292.0
	picker_scroll.custom_minimum_size = Vector2(0, pop_h - 56.0)
	picker_popover_backdrop.visible = true
	picker_popover.visible = true
	_position_popover_below(picker_popover, anchor_btn, pop_w, pop_h, true)
	picker_popover.modulate.a = 0.0
	picker_popover.scale = Vector2(0.90, 0.72)
	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(picker_popover, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(picker_popover, "modulate:a", 1.0, 0.12)
	HudTheme.apply_rail_button_style(btn_chat, is_chat)
	HudTheme.apply_rail_button_style(btn_emote, not is_chat)


func _close_picker_popover() -> void:
	_picker_mode = ""
	picker_popover_backdrop.visible = false
	picker_popover.visible = false
	picker_popover.scale = Vector2.ONE
	picker_popover.modulate.a = 1.0
	HudTheme.apply_rail_button_style(btn_chat, false)
	HudTheme.apply_rail_button_style(btn_emote, false)


func _open_settings_drawer() -> void:
	_close_camera_popover()
	_close_picker_popover()
	settings_drawer.visible = true


func _close_settings_drawer() -> void:
	settings_drawer.visible = false
