class_name CommonHUD
extends Control

# Reusable Warm Classic Parlor Shared HUD Controller (Godot 4 Mobile Portrait)
# Features:
# - Player Mode (opponents only: 1 horizontal pill, or 2-3 vertical pods)
# - Spectator Mode (all 2-4 players: 2-3 standard vertical, or 4 ultra-compact vertical)
# - Single compact 3-column TopRow (2D/3D Toggle | Dynamic PlayersContainer | Settings)
# - Top-left Spectator pill below 2D button & top-right stacked Chat/Emoji rail below Settings
# - Downward-and-inward opening Chat/Emoji popovers
# - Dual Turn Timer: radial TextureProgressBar on active pod vs slim local gold bar + pill + bottom glow
# - 100% empty & pass-through bottom area for game-specific controls (MOUSE_FILTER_IGNORE)

signal view_mode_toggled(is_2d: bool)
signal player_pod_clicked(player_id: String)
signal quick_chat_selected(message_index: int, message_text: String)
signal quick_emote_selected(emote_id: int, emote_texture: Texture2D)
signal audio_toggled(enabled: bool)
signal rules_requested()
signal surrender_requested()
signal leave_match_requested()

const TOP_BTN_SIZE := Vector2(40, 40)
const SOCIAL_BTN_SIZE := Vector2(38, 38)
const POD_SCENE_PATH := "res://scenes/games/base/player_pod.tscn"

const QUICK_CHATS_FA: Array[String] = [
	"عجب حرکتی!",
	"نوبت منه!",
	"برنده منم!",
	"عالی بازی کردی!",
	"بهتره تسلیم شی!",
	"شانس آوردی!",
]

const QUICK_CHATS_EN: Array[String] = [
	"Nice move!",
	"My turn!",
	"Victory is mine!",
	"Well played!",
	"Watch out!",
	"Lucky draw!",
]

@export var allow_spectator_social: bool = false
@export var local_player_id: String = ""
@export var locale_code: String = "fa" # "fa" (RTL Persian) | "en" (LTR English)

@onready var bottom_turn_glow: TextureRect = $BottomTurnGlow
@onready var safe_area_margin: MarginContainer = $SafeAreaMargin
@onready var top_row: HBoxContainer = $SafeAreaMargin/MainTopVBox/TopRow
@onready var btn_view_2d3d: Button = $SafeAreaMargin/MainTopVBox/TopRow/BtnView2D3D
@onready var img_view_2d3d: TextureRect = $SafeAreaMargin/MainTopVBox/TopRow/BtnView2D3D/Icon
@onready var players_container: HBoxContainer = $SafeAreaMargin/MainTopVBox/TopRow/PlayersContainer
@onready var btn_settings: Button = $SafeAreaMargin/MainTopVBox/TopRow/BtnSettings

@onready var local_turn_bar_wrap: MarginContainer = $SafeAreaMargin/MainTopVBox/LocalTurnBarWrap
@onready var local_turn_bar: ProgressBar = $SafeAreaMargin/MainTopVBox/LocalTurnBarWrap/LocalTurnVBox/LocalTurnProgressBar
@onready var local_turn_pill: PanelContainer = $SafeAreaMargin/MainTopVBox/LocalTurnBarWrap/LocalTurnVBox/LocalTurnPillCenter/LocalTurnPill
@onready var lbl_local_turn: Label = $SafeAreaMargin/MainTopVBox/LocalTurnBarWrap/LocalTurnVBox/LocalTurnPillCenter/LocalTurnPill/LblLocalTurn

@onready var edge_overlay: Control = $SafeAreaMargin/EdgeOverlay
@onready var spectator_pill: PanelContainer = $SafeAreaMargin/EdgeOverlay/SpectatorPill
@onready var lbl_spectator: Label = $SafeAreaMargin/EdgeOverlay/SpectatorPill/HBox/LblSpectator
@onready var social_rail: VBoxContainer = $SafeAreaMargin/EdgeOverlay/SocialRail
@onready var btn_chat: Button = $SafeAreaMargin/EdgeOverlay/SocialRail/BtnChat
@onready var btn_emoji: Button = $SafeAreaMargin/EdgeOverlay/SocialRail/BtnEmoji

@onready var emote_layer: Control = $EmoteLayer

@onready var picker_popover_backdrop: Button = $PickerPopoverBackdrop
@onready var picker_popover: PanelContainer = $PickerPopover
@onready var lbl_picker_title: Label = $PickerPopover/VBox/LblPickerTitle
@onready var picker_scroll: ScrollContainer = $PickerPopover/VBox/PickerScroll
@onready var picker_grid: GridContainer = $PickerPopover/VBox/PickerScroll/PickerGrid

@onready var settings_modal: Control = $SettingsModal
@onready var btn_backdrop_close: Button = $SettingsModal/BtnBackdropClose
@onready var modal_card: PanelContainer = $SettingsModal/ModalCard
@onready var lbl_game_title: Label = $SettingsModal/ModalCard/VBox/LblGameTitle
@onready var lbl_mode_meta: Label = $SettingsModal/ModalCard/VBox/LblModeMeta
@onready var btn_mute: Button = $SettingsModal/ModalCard/VBox/BtnMute
@onready var img_mute: TextureRect = $SettingsModal/ModalCard/VBox/BtnMute/Icon
@onready var btn_rules: Button = $SettingsModal/ModalCard/VBox/BtnRules
@onready var btn_leave_or_surrender: Button = $SettingsModal/ModalCard/VBox/BtnLeaveOrSurrender
@onready var img_leave_or_surrender: TextureRect = $SettingsModal/ModalCard/VBox/BtnLeaveOrSurrender/Icon
@onready var btn_resume: Button = $SettingsModal/ModalCard/VBox/BtnResume

static var _pod_scene: PackedScene = preload(POD_SCENE_PATH)
static var _tex_2d: Texture2D = preload("res://assets/images/badges/2d.png")
static var _tex_3d: Texture2D = preload("res://assets/images/badges/3d.png")
static var _tex_sound_on: Texture2D = preload("res://assets/images/badges/sound-on.png")
static var _tex_sound_off: Texture2D = preload("res://assets/images/badges/sound-off.png")
static var _tex_surrender: Texture2D = preload("res://assets/images/badges/surrender.png")
static var _tex_exit: Texture2D = preload("res://assets/images/badges/exit.png")

var _pods_by_id: Dictionary = {} # player_id (String) -> PlayerPod
var _is_spectator: bool = false
var _is_2d_mode: bool = false
var _is_local_turn: bool = false
var _active_player_id: String = ""
var _audio_enabled: bool = true
var _picker_mode: String = "" # "" | "chat" | "emoji"

var _safe_top: int = 16
var _safe_bottom: int = 14
var _safe_left: int = 10
var _safe_right: int = 10

var _glow_tween: Tween = null
var _emote_seqs: Dictionary = {}


func _ready() -> void:
	_detect_locale()
	_apply_theme_styles()
	_apply_safe_insets()
	_connect_signals()
	bottom_turn_glow.texture = HudTheme.make_bottom_edge_glow_texture()
	bottom_turn_glow.visible = false
	local_turn_bar_wrap.visible = false

	# Default preview payload so the scene renders cleanly standalone
	setup_hud([
		{"id": "local", "name": "شما", "counter": "۷", "is_local": true, "seat_index": 1},
		{"id": "opp_1", "name": "آرش", "counter": "۵", "seat_index": 2},
	], false)


func _detect_locale() -> void:
	var sys_loc: String = TranslationServer.get_locale()
	if sys_loc.begins_with("en"):
		locale_code = "en"
	elif sys_loc.begins_with("fa"):
		locale_code = "fa"


func _is_fa() -> bool:
	return locale_code != "en"


func _apply_theme_styles() -> void:
	HudTheme.apply_floating_button_style(btn_view_2d3d, false)
	HudTheme.apply_floating_button_style(btn_settings, false)
	btn_view_2d3d.custom_minimum_size = TOP_BTN_SIZE
	btn_settings.custom_minimum_size = TOP_BTN_SIZE

	HudTheme.apply_rail_button_style(btn_chat, false)
	HudTheme.apply_rail_button_style(btn_emoji, false)
	btn_chat.custom_minimum_size = SOCIAL_BTN_SIZE
	btn_emoji.custom_minimum_size = SOCIAL_BTN_SIZE

	spectator_pill.add_theme_stylebox_override("panel", HudTheme.make_spectator_pill_style())
	local_turn_bar.add_theme_stylebox_override("background", HudTheme.make_local_turn_bar_track_style())
	local_turn_bar.add_theme_stylebox_override("fill", HudTheme.make_local_turn_bar_fill_style(false))
	local_turn_pill.add_theme_stylebox_override("panel", HudTheme.make_local_turn_pill_style(false))

	picker_popover.add_theme_stylebox_override("panel", HudTheme.make_popover_panel_style())
	modal_card.add_theme_stylebox_override("panel", HudTheme.make_drawer_panel_style())

	HudTheme.apply_drawer_item_style(btn_mute, "default")
	HudTheme.apply_drawer_item_style(btn_rules, "default")
	HudTheme.apply_drawer_item_style(btn_leave_or_surrender, "danger")
	HudTheme.apply_drawer_item_style(btn_resume, "primary")

	HudTheme.configure_bidi_label(lbl_local_turn, false)
	HudTheme.configure_bidi_label(lbl_spectator, false)
	HudTheme.configure_bidi_label(lbl_picker_title, false)
	HudTheme.configure_bidi_label(lbl_game_title, false)
	HudTheme.configure_bidi_label(lbl_mode_meta, false)


func _apply_safe_insets() -> void:
	var insets: Dictionary = HudTheme.get_safe_insets(get_viewport())
	_safe_top = int(insets.get("top", 16))
	_safe_bottom = int(insets.get("bottom", 14))
	_safe_left = int(insets.get("left", 10))
	_safe_right = int(insets.get("right", 10))

	safe_area_margin.add_theme_constant_override("margin_top", _safe_top)
	safe_area_margin.add_theme_constant_override("margin_bottom", _safe_bottom)
	safe_area_margin.add_theme_constant_override("margin_left", _safe_left)
	safe_area_margin.add_theme_constant_override("margin_right", _safe_right)
	call_deferred("_sync_edge_positions")


func _sync_edge_positions() -> void:
	if not is_inside_tree():
		return
	var btn_2d_bottom: float = btn_view_2d3d.position.y + btn_view_2d3d.size.y
	spectator_pill.position = Vector2(0.0, btn_2d_bottom + 6.0)

	var btn_set_bottom: float = btn_settings.position.y + btn_settings.size.y
	var rail_x: float = maxf(0.0, edge_overlay.size.x - SOCIAL_BTN_SIZE.x - 1.0)
	social_rail.position = Vector2(rail_x, btn_set_bottom + 8.0)


func _connect_signals() -> void:
	btn_view_2d3d.pressed.connect(func() -> void:
		set_view_2d(not _is_2d_mode)
		view_mode_toggled.emit(_is_2d_mode)
	)
	btn_settings.pressed.connect(_open_settings_modal)
	btn_backdrop_close.pressed.connect(_close_settings_modal)
	btn_resume.pressed.connect(_close_settings_modal)

	btn_chat.pressed.connect(func() -> void:
		_toggle_picker_popover("chat", btn_chat)
	)
	btn_emoji.pressed.connect(func() -> void:
		_toggle_picker_popover("emoji", btn_emoji)
	)
	picker_popover_backdrop.pressed.connect(_close_picker_popover)

	btn_mute.pressed.connect(func() -> void:
		set_audio_enabled(not _audio_enabled)
		audio_toggled.emit(_audio_enabled)
	)
	btn_rules.pressed.connect(func() -> void:
		_close_settings_modal()
		rules_requested.emit()
	)
	btn_leave_or_surrender.pressed.connect(func() -> void:
		_close_settings_modal()
		if _is_spectator:
			leave_match_requested.emit()
		else:
			surrender_requested.emit()
	)

	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_apply_safe_insets()
	if picker_popover.visible and not _picker_mode.is_empty():
		var anchor: Button = btn_chat if _picker_mode == "chat" else btn_emoji
		_position_picker_downward_inward(anchor)


# --- Public Required API ---

func setup_hud(players_data: Array, is_spectator: bool = false) -> void:
	_is_spectator = is_spectator
	_clear_pods()

	# Filter out local player in Player Mode (Opponents Only); keep all in Spectator Mode
	var visible_players: Array[Dictionary] = []
	for raw in players_data:
		if not (raw is Dictionary):
			continue
		var p: Dictionary = raw as Dictionary
		var pid: String = str(p.get("id", p.get("player_id", "")))
		var is_local_entry: bool = bool(p.get("is_local", false)) or (not local_player_id.is_empty() and pid == local_player_id)
		if is_local_entry and not local_player_id.is_empty():
			pass
		elif is_local_entry and local_player_id.is_empty():
			local_player_id = pid
		if not is_spectator and is_local_entry:
			continue
		visible_players.append(p)

	var max_pods: int = 4 if is_spectator else 3
	if visible_players.size() > max_pods:
		visible_players.resize(max_pods)

	var pod_count: int = visible_players.size()
	var mode: PlayerPod.PodMode = PlayerPod.PodMode.VERTICAL_STANDARD
	if pod_count <= 1:
		mode = PlayerPod.PodMode.HORIZONTAL_PILL
		players_container.add_theme_constant_override("separation", 8)
	elif pod_count >= 4:
		mode = PlayerPod.PodMode.VERTICAL_COMPACT
		players_container.add_theme_constant_override("separation", 4)
	else:
		mode = PlayerPod.PodMode.VERTICAL_STANDARD
		players_container.add_theme_constant_override("separation", 8)

	for i in range(pod_count):
		var p_data: Dictionary = visible_players[i]
		var pod: PlayerPod = _pod_scene.instantiate() as PlayerPod
		players_container.add_child(pod)
		pod.setup_pod(p_data, mode, _is_fa())
		pod.pod_pressed.connect(func(clicked_id: String) -> void:
			player_pod_clicked.emit(clicked_id)
		)
		_pods_by_id[pod.player_id] = pod

	_refresh_spectator_and_locale_ui()
	call_deferred("_sync_edge_positions")


func update_player_counter(player_id: String, value: String) -> void:
	if not _pods_by_id.has(player_id):
		return
	var pod: PlayerPod = _pods_by_id[player_id] as PlayerPod
	if is_instance_valid(pod):
		pod.set_counter(value)


func set_active_turn(active_player_id: String, is_local_player: bool = false) -> void:
	_active_player_id = active_player_id
	# Spectators never see local player's bottom glow / turn bar
	_is_local_turn = (is_local_player and not _is_spectator)

	for pid in _pods_by_id.keys():
		var pod: PlayerPod = _pods_by_id[pid] as PlayerPod
		if is_instance_valid(pod):
			var pod_active: bool = (not _is_local_turn) and (str(pid) == active_player_id)
			pod.set_active_turn(pod_active)

	local_turn_bar_wrap.visible = _is_local_turn
	_set_bottom_glow_active(_is_local_turn)
	if _is_local_turn:
		local_turn_bar.value = 100.0
		_update_local_turn_visuals(15.0, 15.0, false)


func update_timer(seconds_left: float, max_seconds: float) -> void:
	if _is_local_turn:
		var safe_max: float = maxf(1.0, max_seconds)
		var pct: float = clampf((seconds_left / safe_max) * 100.0, 0.0, 100.0)
		var is_danger: bool = (seconds_left > 0.0 and seconds_left <= 4.0)
		local_turn_bar.value = pct
		_update_local_turn_visuals(seconds_left, max_seconds, is_danger)
		return

	if _pods_by_id.has(_active_player_id):
		var pod: PlayerPod = _pods_by_id[_active_player_id] as PlayerPod
		if is_instance_valid(pod):
			pod.update_ring_timer(seconds_left, max_seconds)


func show_emote(sender_id: String, emote_texture: Texture2D) -> void:
	_spawn_reaction_bubble(sender_id, emote_texture, false, 2.4)


# --- Auxiliary Public Controls ---

func show_chat_bubble(sender_id: String, message_text: String) -> void:
	_spawn_reaction_bubble(sender_id, message_text, true, 2.8)


func set_spectator_social_enabled(enabled: bool) -> void:
	allow_spectator_social = enabled
	_refresh_spectator_and_locale_ui()


func set_view_2d(is_2d: bool) -> void:
	_is_2d_mode = is_2d
	img_view_2d3d.texture = _tex_3d if is_2d else _tex_2d
	HudTheme.apply_floating_button_style(btn_view_2d3d, is_2d)


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	img_mute.texture = _tex_sound_on if enabled else _tex_sound_off
	if _is_fa():
		btn_mute.text = "صدا: روشن" if enabled else "صدا: خاموش"
	else:
		btn_mute.text = "Audio: On" if enabled else "Audio: Mute"


func set_locale(new_locale: String) -> void:
	locale_code = "en" if new_locale.begins_with("en") else "fa"
	_refresh_spectator_and_locale_ui()


func set_game_meta(game_title: String, meta_text: String) -> void:
	lbl_game_title.text = game_title
	lbl_mode_meta.text = meta_text


# --- Internal Helpers ---

func _clear_pods() -> void:
	for pod_v in _pods_by_id.values():
		var pod: Node = pod_v as Node
		if is_instance_valid(pod):
			pod.queue_free()
	_pods_by_id.clear()


func _refresh_spectator_and_locale_ui() -> void:
	spectator_pill.visible = _is_spectator
	var social_visible: bool = (not _is_spectator) or allow_spectator_social
	social_rail.visible = social_visible
	if not social_visible:
		_close_picker_popover()

	if _is_fa():
		lbl_spectator.text = "تماشاچی"
		btn_rules.text = "قوانین بازی"
		btn_resume.text = "ادامه"
		lbl_mode_meta.text = "حالت تماشاگر" if _is_spectator else "مسابقه زنده"
		if _is_spectator:
			btn_leave_or_surrender.text = "خروج از مسابقه"
			img_leave_or_surrender.texture = _tex_exit
			HudTheme.apply_drawer_item_style(btn_leave_or_surrender, "default")
		else:
			btn_leave_or_surrender.text = "تسلیم شدن"
			img_leave_or_surrender.texture = _tex_surrender
			HudTheme.apply_drawer_item_style(btn_leave_or_surrender, "danger")
	else:
		lbl_spectator.text = "Spectating"
		btn_rules.text = "Rules"
		btn_resume.text = "Resume"
		lbl_mode_meta.text = "Spectator Mode" if _is_spectator else "Live Match"
		if _is_spectator:
			btn_leave_or_surrender.text = "Leave Match"
			img_leave_or_surrender.texture = _tex_exit
			HudTheme.apply_drawer_item_style(btn_leave_or_surrender, "default")
		else:
			btn_leave_or_surrender.text = "Surrender"
			img_leave_or_surrender.texture = _tex_surrender
			HudTheme.apply_drawer_item_style(btn_leave_or_surrender, "danger")

	set_audio_enabled(_audio_enabled)


func _update_local_turn_visuals(seconds_left: float, _max_seconds: float, is_danger: bool) -> void:
	var sec_str: String = HudTheme.format_seconds(seconds_left, _is_fa())
	if _is_fa():
		lbl_local_turn.text = "نوبت شما • %s" % sec_str
	else:
		lbl_local_turn.text = "Your Turn • %s" % sec_str

	local_turn_bar.add_theme_stylebox_override("fill", HudTheme.make_local_turn_bar_fill_style(is_danger))
	local_turn_pill.add_theme_stylebox_override("panel", HudTheme.make_local_turn_pill_style(is_danger))
	lbl_local_turn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.84) if is_danger else HudTheme.COL_TEXT_GOLD)


func _set_bottom_glow_active(active: bool) -> void:
	if is_instance_valid(_glow_tween):
		_glow_tween.kill()
		_glow_tween = null
	bottom_turn_glow.visible = active
	if not active:
		bottom_turn_glow.modulate.a = 0.0
		return
	bottom_turn_glow.modulate.a = 0.72
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(bottom_turn_glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(bottom_turn_glow, "modulate:a", 0.58, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _spawn_reaction_bubble(sender_id: String, content: Variant, is_text: bool, hold_sec: float) -> void:
	var existing: Node = emote_layer.get_node_or_null("Emote_%s" % sender_id)
	if is_instance_valid(existing):
		existing.queue_free()

	var seq: int = int(_emote_seqs.get(sender_id, 0)) + 1
	_emote_seqs[sender_id] = seq

	var bubble := PanelContainer.new()
	bubble.name = "Emote_%s" % sender_id
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_stylebox_override("panel", HudTheme.make_emote_bubble_style(is_text))

	var b_size: Vector2 = Vector2(210.0, 56.0) if is_text else Vector2(74.0, 74.0)
	bubble.custom_minimum_size = b_size
	bubble.size = b_size

	if is_text:
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = str(content)
		lbl.add_theme_font_override("font", HudTheme.get_ui_font())
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_IVORY)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HudTheme.configure_bidi_label(lbl, false)
		bubble.add_child(lbl)
	elif content is Texture2D:
		var tex_rect := TextureRect.new()
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = content as Texture2D
		tex_rect.custom_minimum_size = Vector2(58.0, 58.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bubble.add_child(tex_rect)

	emote_layer.add_child(bubble)

	var vp_size: Vector2 = get_viewport_rect().size
	var min_x: float = float(_safe_left) + 42.0
	var max_x: float = maxf(min_x, vp_size.x - float(_safe_right) - 44.0 - b_size.x)
	var anchor_pos: Vector2 = Vector2((vp_size.x - b_size.x) * 0.5, float(_safe_top) + 92.0)

	if _pods_by_id.has(sender_id):
		var pod: PlayerPod = _pods_by_id[sender_id] as PlayerPod
		if is_instance_valid(pod):
			var pod_anchor: Vector2 = pod.get_emote_anchor_global_pos()
			anchor_pos.x = clampf(pod_anchor.x - (b_size.x * 0.5), min_x, max_x)
			anchor_pos.y = pod_anchor.y

	bubble.global_position = anchor_pos
	bubble.pivot_offset = Vector2(b_size.x * 0.5, 0.0)
	bubble.scale = Vector2(0.25, 0.25)
	bubble.modulate.a = 0.0

	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.06, 1.06), 0.18)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.14)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.10)

	await get_tree().create_timer(hold_sec).timeout
	if int(_emote_seqs.get(sender_id, 0)) != seq or not is_instance_valid(bubble):
		return
	var fade: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(bubble, "scale", Vector2(0.86, 0.86), 0.18)
	fade.parallel().tween_property(bubble, "modulate:a", 0.0, 0.20)
	await fade.finished
	if is_instance_valid(bubble):
		bubble.queue_free()


# --- Downward-and-Inward Popovers ---

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
	if is_chat:
		lbl_picker_title.text = "پیام سریع" if _is_fa() else "Quick Chat"
	else:
		lbl_picker_title.text = "ایموجی و استیکر" if _is_fa() else "Reactions"
	picker_grid.columns = 2 if is_chat else 4

	if is_chat:
		var chats: Array[String] = QUICK_CHATS_FA if _is_fa() else QUICK_CHATS_EN
		for i in range(chats.size()):
			var msg: String = chats[i]
			var chat_btn := Button.new()
			chat_btn.text = msg
			chat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chat_btn.custom_minimum_size = Vector2(0, 42)
			HudTheme.apply_drawer_item_style(chat_btn, "default")
			chat_btn.add_theme_font_size_override("font_size", 13)
			var captured_i: int = i
			chat_btn.pressed.connect(func() -> void:
				_close_picker_popover()
				quick_chat_selected.emit(captured_i, msg)
			)
			picker_grid.add_child(chat_btn)
	else:
		for r_id in range(1, 13):
			var icon_btn := Button.new()
			icon_btn.custom_minimum_size = Vector2(64, 64)
			HudTheme.apply_rail_button_style(icon_btn, false)
			var tex_rect := TextureRect.new()
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.offset_left = 7
			tex_rect.offset_top = 7
			tex_rect.offset_right = -7
			tex_rect.offset_bottom = -7
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path: String = "res://assets/icons/Reactions/%d.png" % r_id
			var loaded_tex: Texture2D = null
			if ResourceLoader.exists(icon_path):
				loaded_tex = load(icon_path) as Texture2D
				tex_rect.texture = loaded_tex
			icon_btn.add_child(tex_rect)
			var captured_id: int = r_id
			var captured_tex: Texture2D = loaded_tex
			icon_btn.pressed.connect(func() -> void:
				_close_picker_popover()
				quick_emote_selected.emit(captured_id, captured_tex)
			)
			picker_grid.add_child(icon_btn)

	picker_popover_backdrop.visible = true
	picker_popover.visible = true
	_position_picker_downward_inward(anchor_btn)
	picker_popover.modulate.a = 0.0
	picker_popover.scale = Vector2(0.86, 0.72)

	var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(picker_popover, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(picker_popover, "modulate:a", 1.0, 0.12)

	HudTheme.apply_rail_button_style(btn_chat, is_chat)
	HudTheme.apply_rail_button_style(btn_emoji, not is_chat)


func _position_picker_downward_inward(anchor_btn: Control) -> void:
	var is_chat: bool = (_picker_mode == "chat")
	var vp_size: Vector2 = get_viewport_rect().size
	var pop_w: float = clampf(vp_size.x - float(_safe_left) - float(_safe_right) - SOCIAL_BTN_SIZE.x - 24.0, 240.0, 324.0)
	var pop_h: float = 228.0 if is_chat else 276.0
	picker_scroll.custom_minimum_size = Vector2(0.0, pop_h - 54.0)

	var btn_rect: Rect2 = anchor_btn.get_global_rect()
	# Open INWARD (to the left of the right-edge social button) and DOWNWARD from its top edge
	var x: float = clampf(btn_rect.position.x - pop_w - 8.0, float(_safe_left), maxf(float(_safe_left), vp_size.x - pop_w - float(_safe_right)))
	var y: float = clampf(btn_rect.position.y, float(_safe_top), maxf(float(_safe_top), vp_size.y - pop_h - 16.0))
	picker_popover.position = Vector2(x, y)
	picker_popover.size = Vector2(pop_w, pop_h)
	picker_popover.pivot_offset = Vector2(pop_w, 18.0)


func _close_picker_popover() -> void:
	_picker_mode = ""
	picker_popover_backdrop.visible = false
	picker_popover.visible = false
	picker_popover.scale = Vector2.ONE
	picker_popover.modulate.a = 1.0
	HudTheme.apply_rail_button_style(btn_chat, false)
	HudTheme.apply_rail_button_style(btn_emoji, false)


func _open_settings_modal() -> void:
	_close_picker_popover()
	settings_modal.visible = true


func _close_settings_modal() -> void:
	settings_modal.visible = false
