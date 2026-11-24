class_name PlayerPod
extends PanelContainer

# Reusable Warm Classic Parlor Player Pod for Cafe Fekr (Godot 4)
# Supports 3 automatic layout scales:
#   - HORIZONTAL_PILL (1 opponent in 2P Player Mode)
#   - VERTICAL_STANDARD (2-3 pods in 3-4P Player Mode or 2-3P Spectator Mode)
#   - VERTICAL_COMPACT (4 pods in 4P Spectator Mode on narrow portrait screens)

signal pod_pressed(player_id: String)

enum PodMode {
	HORIZONTAL_PILL,
	VERTICAL_STANDARD,
	VERTICAL_COMPACT,
}

@onready var pod_content: BoxContainer = $PodContent
@onready var avatar_ring_slot: Control = $PodContent/AvatarRingSlot
@onready var turn_ring: TextureProgressBar = $PodContent/AvatarRingSlot/TurnRing
@onready var avatar_mask: Panel = $PodContent/AvatarRingSlot/AvatarMask
@onready var lbl_initial: Label = $PodContent/AvatarRingSlot/AvatarMask/LblInitial
@onready var avatar_texture: TextureRect = $PodContent/AvatarRingSlot/AvatarMask/AvatarTexture
@onready var seat_dot: Panel = $PodContent/AvatarRingSlot/SeatDot
@onready var ring_timer_badge: PanelContainer = $PodContent/AvatarRingSlot/RingTimerBadge
@onready var lbl_ring_timer: Label = $PodContent/AvatarRingSlot/RingTimerBadge/LblRingTimer
@onready var name_label: Label = $PodContent/NameLabel
@onready var role_dot: Panel = $PodContent/RoleDot
@onready var counter_badge: PanelContainer = $PodContent/CounterBadge
@onready var lbl_counter: Label = $PodContent/CounterBadge/LblCounter
@onready var status_badge: PanelContainer = $PodContent/StatusBadge
@onready var lbl_status: Label = $PodContent/StatusBadge/LblStatus
@onready var btn_profile: Button = $BtnProfile

var player_id: String = ""
var seat_index: int = 1
var _mode: PodMode = PodMode.VERTICAL_STANDARD
var _is_active: bool = false
var _is_danger: bool = false
var _is_eliminated: bool = false
var _use_persian_digits: bool = true
var _seat_color: Color = HudTheme.COL_GOLD_ACTIVE


func _ready() -> void:
	_init_radial_ring()
	_configure_bidi()
	if is_instance_valid(btn_profile):
		btn_profile.pressed.connect(func() -> void:
			pod_pressed.emit(player_id)
		)


func _init_radial_ring() -> void:
	# Radial progress ring is superseded by the universal horizontal timer bar;
	# skip generating the unused 128x128 procedural ring texture on CPU.
	if is_instance_valid(turn_ring):
		turn_ring.visible = false
	if is_instance_valid(ring_timer_badge):
		ring_timer_badge.visible = false


func _configure_bidi() -> void:
	HudTheme.configure_bidi_label(name_label, false)
	name_label.justification_flags = TextServer.JUSTIFICATION_NONE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.visible = true
	HudTheme.configure_bidi_label(lbl_counter, false)
	HudTheme.configure_bidi_label(lbl_ring_timer, false)
	if is_instance_valid(lbl_status):
		HudTheme.configure_bidi_label(lbl_status, true)


func set_player_name(new_name: String) -> void:
	if not is_instance_valid(name_label):
		return
	var raw_name := new_name.strip_edges()
	if raw_name.is_empty():
		raw_name = "بازیکن %d" % seat_index
	name_label.text = raw_name
	name_label.visible = true
	if is_instance_valid(lbl_initial):
		lbl_initial.text = raw_name.substr(0, 1).to_upper()


func setup_pod(player_data: Dictionary, mode: PodMode, use_fa_digits: bool = true) -> void:
	_mode = mode
	_use_persian_digits = use_fa_digits

	player_id = str(player_data.get("id", player_data.get("player_id", str(player_data.get("index", 1)))))
	seat_index = int(player_data.get("seat_index", player_data.get("index", 1)))
	_is_eliminated = bool(player_data.get("eliminated", false))

	var raw_name: String = str(player_data.get("name", "بازیکن %d" % seat_index))
	name_label.text = raw_name
	name_label.visible = true
	lbl_initial.text = raw_name.substr(0, 1).to_upper() if not raw_name.is_empty() else "?"

	var av_val: Variant = player_data.get("avatar_texture", player_data.get("avatar", null))
	if av_val is Texture2D:
		avatar_texture.texture = av_val as Texture2D
		lbl_initial.visible = false
	elif av_val is String and not String(av_val).is_empty() and ResourceLoader.exists(String(av_val)):
		avatar_texture.texture = load(String(av_val)) as Texture2D
		lbl_initial.visible = (avatar_texture.texture == null)
	else:
		avatar_texture.texture = null
		lbl_initial.visible = true

	var col_val: Variant = player_data.get("color", null)
	if col_val is Color:
		_seat_color = col_val as Color
	elif col_val is String and not String(col_val).is_empty():
		_seat_color = Color.from_string(String(col_val), HudTheme.get_seat_accent(seat_index))
	else:
		_seat_color = HudTheme.get_seat_accent(seat_index)

	set_counter(str(player_data.get("counter", "")))
	set_status_badge(str(player_data.get("status", "")))
	_apply_mode_metrics()
	_apply_pod_styles()
	set_active_turn(false)


func _apply_mode_metrics() -> void:
	var av_size: float = 40.0
	var ring_size: float = 46.0
	var dot_size: float = 13.0
	var name_font_px: int = 13
	var counter_font_px: int = 13
	var timer_font_px: int = 10

	match _mode:
		PodMode.HORIZONTAL_PILL:
			pod_content.vertical = false
			pod_content.add_theme_constant_override("separation", 6)
			custom_minimum_size = Vector2(0.0, 48.0)
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			av_size = 40.0
			ring_size = 46.0
			dot_size = 13.0
			name_font_px = 15
			counter_font_px = 14
			timer_font_px = 10
			name_label.clip_text = false
			name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.justification_flags = TextServer.JUSTIFICATION_NONE
			name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			name_label.custom_minimum_size = Vector2(40.0, 0.0)
			name_label.visible = true
			if counter_badge.visible and not lbl_counter.text.strip_edges().is_empty():
				counter_badge.custom_minimum_size = Vector2(34.0, 24.0)
			else:
				counter_badge.visible = false
				counter_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(status_badge):
				if status_badge.visible and is_instance_valid(lbl_status) and not lbl_status.text.strip_edges().is_empty():
					status_badge.custom_minimum_size = Vector2(0, 24.0)
				else:
					status_badge.visible = false
					status_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(lbl_status):
				lbl_status.add_theme_font_size_override("font_size", 13)
			lbl_initial.add_theme_font_size_override("font_size", 17)
			role_dot.visible = false
			role_dot.custom_minimum_size = Vector2.ZERO
			seat_dot.visible = true

		PodMode.VERTICAL_STANDARD:
			pod_content.vertical = true
			pod_content.add_theme_constant_override("separation", 2)
			custom_minimum_size = Vector2(62.0, 72.0)
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			av_size = 40.0
			ring_size = 46.0
			dot_size = 12.0
			name_font_px = 12
			counter_font_px = 12
			timer_font_px = 10
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.custom_minimum_size = Vector2(56.0, 16.0)
			name_label.clip_text = true
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if counter_badge.visible and not lbl_counter.text.strip_edges().is_empty():
				counter_badge.custom_minimum_size = Vector2(30.0, 20.0)
			else:
				counter_badge.visible = false
				counter_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(status_badge):
				if status_badge.visible and is_instance_valid(lbl_status) and not lbl_status.text.strip_edges().is_empty():
					status_badge.custom_minimum_size = Vector2(0, 18.0)
				else:
					status_badge.visible = false
					status_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(lbl_status):
				lbl_status.add_theme_font_size_override("font_size", 11)
			lbl_initial.add_theme_font_size_override("font_size", 16)
			role_dot.visible = false
			role_dot.custom_minimum_size = Vector2.ZERO
			seat_dot.visible = true

		PodMode.VERTICAL_COMPACT:
			pod_content.vertical = true
			pod_content.add_theme_constant_override("separation", 2)
			custom_minimum_size = Vector2(52.0, 64.0)
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			av_size = 32.0
			ring_size = 38.0
			dot_size = 10.0
			name_font_px = 11
			counter_font_px = 11
			timer_font_px = 9
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.custom_minimum_size = Vector2(48.0, 14.0)
			name_label.clip_text = true
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if counter_badge.visible and not lbl_counter.text.strip_edges().is_empty():
				counter_badge.custom_minimum_size = Vector2(28.0, 18.0)
			else:
				counter_badge.visible = false
				counter_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(status_badge):
				if status_badge.visible and is_instance_valid(lbl_status) and not lbl_status.text.strip_edges().is_empty():
					status_badge.custom_minimum_size = Vector2(0, 16.0)
				else:
					status_badge.visible = false
					status_badge.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(lbl_status):
				lbl_status.add_theme_font_size_override("font_size", 10)
			lbl_initial.add_theme_font_size_override("font_size", 13)
			role_dot.visible = false
			role_dot.custom_minimum_size = Vector2.ZERO
			seat_dot.visible = true

	avatar_ring_slot.custom_minimum_size = Vector2(ring_size, ring_size)
	var av_radius: int = int(ceil(av_size * 0.5))
	var sb_mask := StyleBoxFlat.new()
	sb_mask.bg_color = Color(0.16, 0.105, 0.07, 0.96)
	sb_mask.border_color = Color(HudTheme.COL_GOLD_BRUSHED.r, HudTheme.COL_GOLD_BRUSHED.g, HudTheme.COL_GOLD_BRUSHED.b, 0.70)
	sb_mask.set_border_width_all(1)
	sb_mask.set_corner_radius_all(av_radius)
	avatar_mask.add_theme_stylebox_override("panel", sb_mask)

	seat_dot.custom_minimum_size = Vector2(dot_size, dot_size)
	seat_dot.offset_left = -dot_size
	seat_dot.offset_top = 0.0
	seat_dot.offset_right = 0.0
	seat_dot.offset_bottom = dot_size
	role_dot.custom_minimum_size = Vector2(dot_size, dot_size)
	var sb_dot := StyleBoxFlat.new()
	sb_dot.bg_color = _seat_color
	sb_dot.border_color = HudTheme.COL_WALNUT_DEEP
	sb_dot.set_border_width_all(2)
	sb_dot.set_corner_radius_all(int(ceil(dot_size * 0.5)))
	sb_dot.shadow_color = Color(0, 0, 0, 0.3)
	sb_dot.shadow_size = 2
	seat_dot.add_theme_stylebox_override("panel", sb_dot)
	role_dot.add_theme_stylebox_override("panel", sb_dot)

	name_label.add_theme_font_size_override("font_size", name_font_px)
	lbl_counter.add_theme_font_size_override("font_size", counter_font_px)
	lbl_ring_timer.add_theme_font_size_override("font_size", timer_font_px)

	var sb_counter: StyleBoxFlat = HudTheme.make_score_badge_style("normal")
	sb_counter.set_corner_radius_all(7 if _mode == PodMode.VERTICAL_COMPACT else 9)
	sb_counter.content_margin_left = 3 if _mode == PodMode.VERTICAL_COMPACT else 5
	sb_counter.content_margin_right = 3 if _mode == PodMode.VERTICAL_COMPACT else 5
	sb_counter.content_margin_top = 1
	sb_counter.content_margin_bottom = 1
	counter_badge.add_theme_stylebox_override("panel", sb_counter)


func _apply_pod_styles() -> void:
	if _is_eliminated:
		add_theme_stylebox_override("panel", HudTheme.make_disabled_card_style(_mode == PodMode.VERTICAL_COMPACT))
		modulate = Color(0.68, 0.64, 0.62, 0.78)
		return

	var radius: int = 22 if _mode == PodMode.HORIZONTAL_PILL else (12 if _mode == PodMode.VERTICAL_COMPACT else 16)
	var pad_h: int = 10 if _mode == PodMode.HORIZONTAL_PILL else (4 if _mode == PodMode.VERTICAL_COMPACT else 6)
	var pad_v: int = 5 if _mode == PodMode.HORIZONTAL_PILL else (4 if _mode == PodMode.VERTICAL_COMPACT else 5)
	add_theme_stylebox_override("panel", HudTheme.make_pod_style(_is_active, _is_danger, radius, pad_h, pad_v))
	modulate = Color.WHITE if _is_active else Color(0.90, 0.87, 0.83, 0.94)


func set_counter(value: String) -> void:
	if not is_instance_valid(counter_badge) or not is_instance_valid(lbl_counter):
		return
	var clean := value.strip_edges()
	if clean.is_empty():
		counter_badge.visible = false
		counter_badge.custom_minimum_size = Vector2.ZERO
		lbl_counter.text = ""
		return
	var min_w: float = 34.0 if _mode == PodMode.HORIZONTAL_PILL else (28.0 if _mode == PodMode.VERTICAL_COMPACT else 32.0)
	var min_h: float = 24.0 if _mode == PodMode.HORIZONTAL_PILL else (18.0 if _mode == PodMode.VERTICAL_COMPACT else 22.0)
	counter_badge.custom_minimum_size = Vector2(min_w, min_h)
	counter_badge.visible = true
	lbl_counter.text = HudTheme.fa_digits(clean) if _use_persian_digits else clean


func set_status_badge(text: String, color: Color = Color(-1, -1, -1)) -> void:
	if not is_instance_valid(status_badge) or not is_instance_valid(lbl_status):
		return
	var clean := text.strip_edges()
	if clean.is_empty():
		status_badge.visible = false
		status_badge.custom_minimum_size = Vector2.ZERO
		lbl_status.text = ""
		return
	var min_h: float = 24.0 if _mode == PodMode.HORIZONTAL_PILL else (16.0 if _mode == PodMode.VERTICAL_COMPACT else 20.0)
	status_badge.custom_minimum_size = Vector2(0.0, min_h)
	status_badge.visible = true
	lbl_status.text = HudTheme.fa_digits(clean) if _use_persian_digits else clean
	if color.r >= 0.0:
		lbl_status.add_theme_color_override("font_color", color)
	else:
		lbl_status.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)


func set_eliminated(eliminated: bool, reason: String = "") -> void:
	_is_eliminated = eliminated
	if eliminated and not reason.is_empty():
		set_counter(reason)
	_apply_pod_styles()


func set_active_turn(active: bool) -> void:
	_is_active = active
	if not active:
		_is_danger = false
	# Timer is universal horizontal bar; radial ring around avatar is completely removed
	turn_ring.visible = false
	ring_timer_badge.visible = false
	_apply_pod_styles()


func update_ring_timer(seconds_left: float, _max_seconds: float) -> void:
	# Keep radial ring suppressed — all timers handled by universal horizontal bar
	if turn_ring.visible:
		turn_ring.visible = false
	if ring_timer_badge.visible:
		ring_timer_badge.visible = false
	if not _is_active:
		return
	var danger: bool = (seconds_left > 0.0 and seconds_left <= 4.0)
	if danger != _is_danger:
		_is_danger = danger
		_apply_pod_styles()


func get_emote_anchor_global_pos() -> Vector2:
	var pod_rect: Rect2 = get_global_rect()
	return Vector2(pod_rect.get_center().x, pod_rect.end.y + 6.0)
