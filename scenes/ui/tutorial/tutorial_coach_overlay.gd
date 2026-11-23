class_name TutorialCoachOverlay
extends CanvasLayer

## Reusable Cafe Fekr Warm Parlor interactive Spotlight & Coach Card overlay.
## Uses a 4-panel dark dimmer scrim around a live spotlight cutout so touches
## inside the spotlight pass natively to Buttons or 3D boards with zero shader
## overhead and full cross-platform compatibility (Android/iOS/Desktop/Web).

signal next_pressed()
signal back_pressed()
signal target_area_tapped()

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

const SCRIM_COLOR: Color = Color(0.03, 0.015, 0.008, 0.78)
const CARD_BG_COLOR: Color = Color(0.145, 0.088, 0.052, 0.98)
const CARD_BORDER_COLOR: Color = Color(0.92, 0.74, 0.30, 0.96)
const GOLD_BRIGHT: Color = Color(1.0, 0.87, 0.42, 1.0)
const CREAM_TEXT: Color = Color(0.97, 0.93, 0.85, 1.0)
const MUTED_GOLD: Color = Color(0.84, 0.73, 0.54, 1.0)

const CARD_SAFE_MARGIN: float = 18.0
const CARD_GAP_FROM_TARGET: float = 22.0

var _root: Control = null
var _scrim_top: ColorRect = null
var _scrim_bottom: ColorRect = null
var _scrim_left: ColorRect = null
var _scrim_right: ColorRect = null
var _hole_blocker: Control = null

var _spotlight_ring: Panel = null
var _spotlight_outer_glow: Panel = null
var _ring_style: StyleBoxFlat = null
var _glow_style: StyleBoxFlat = null
var _pointer_lbl: Label = null

var _coach_card: PanelContainer = null
var _lbl_badge: Label = null
var _lbl_step_counter: Label = null
var _lbl_title: Label = null
var _lbl_body: Label = null
var _hint_chip: PanelContainer = null
var _lbl_hint: Label = null
var _nudge_lbl: Label = null
var _btn_row: HBoxContainer = null
var _btn_next: Button = null
var _btn_back: Button = null
var _dots_container: HBoxContainer = null

var _current_step: TutorialStep = null
var _has_target: bool = false
var _display_rect: Rect2 = Rect2()
var _target_rect: Rect2 = Rect2()
var _rect_initialized: bool = false
var _anim_time: float = 0.0
var _card_tween: Tween = null
var _nudge_tween: Tween = null


func _init() -> void:
	layer = 96


func _ready() -> void:
	_build_ui()
	visible = false
	set_process(false)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "TutorialOverlayRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 4-panel cutout scrim
	_scrim_top = _make_scrim_rect("ScrimTop")
	_scrim_bottom = _make_scrim_rect("ScrimBottom")
	_scrim_left = _make_scrim_rect("ScrimLeft")
	_scrim_right = _make_scrim_rect("ScrimRight")

	# Optional hole blocker when target interaction is not required
	_hole_blocker = Control.new()
	_hole_blocker.name = "HoleBlocker"
	_hole_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_hole_blocker.gui_input.connect(_on_hole_gui_input)
	_root.add_child(_hole_blocker)

	# Outer pulsing aura around spotlight
	_spotlight_outer_glow = Panel.new()
	_spotlight_outer_glow.name = "SpotlightOuterGlow"
	_spotlight_outer_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_style = StyleBoxFlat.new()
	_glow_style.bg_color = Color(0, 0, 0, 0)
	_glow_style.border_color = Color(1.0, 0.85, 0.35, 0.42)
	_glow_style.set_border_width_all(6)
	_glow_style.set_corner_radius_all(22)
	_spotlight_outer_glow.add_theme_stylebox_override("panel", _glow_style)
	_root.add_child(_spotlight_outer_glow)

	# Crisp golden spotlight frame
	_spotlight_ring = Panel.new()
	_spotlight_ring.name = "SpotlightRing"
	_spotlight_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_style = StyleBoxFlat.new()
	_ring_style.bg_color = Color(0, 0, 0, 0)
	_ring_style.border_color = GOLD_BRIGHT
	_ring_style.set_border_width_all(3)
	_ring_style.set_corner_radius_all(18)
	_spotlight_ring.add_theme_stylebox_override("panel", _ring_style)
	_root.add_child(_spotlight_ring)

	# Animated golden pointer chevron
	_pointer_lbl = Label.new()
	_pointer_lbl.name = "PointerArrow"
	_pointer_lbl.text = "▼"
	_pointer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pointer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pointer_lbl.custom_minimum_size = Vector2(44, 34)
	_pointer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_lbl.add_theme_font_override("font", FONT_VAZIR)
	_pointer_lbl.add_theme_font_size_override("font_size", 26)
	_pointer_lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	_pointer_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	_pointer_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_pointer_lbl.add_theme_constant_override("shadow_outline_size", 4)
	_root.add_child(_pointer_lbl)

	# Warm Classic Parlor RTL Coach Card
	_coach_card = PanelContainer.new()
	_coach_card.name = "CoachCard"
	_coach_card.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_coach_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = CARD_BG_COLOR
	card_style.border_color = CARD_BORDER_COLOR
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(22)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	card_style.shadow_size = 16
	card_style.shadow_offset = Vector2(0, 8)
	_coach_card.add_theme_stylebox_override("panel", card_style)
	_root.add_child(_coach_card)

	var vbox := VBoxContainer.new()
	vbox.layout_direction = Control.LAYOUT_DIRECTION_RTL
	vbox.add_theme_constant_override("separation", 10)
	_coach_card.add_child(vbox)

	# Top header row: Badge + Step Progress
	var header_row := HBoxContainer.new()
	header_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	var badge_panel := PanelContainer.new()
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.28, 0.19, 0.08, 0.95)
	badge_sb.border_color = Color(0.86, 0.68, 0.28, 0.85)
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(10)
	badge_sb.content_margin_left = 10
	badge_sb.content_margin_right = 10
	badge_sb.content_margin_top = 3
	badge_sb.content_margin_bottom = 3
	badge_panel.add_theme_stylebox_override("panel", badge_sb)
	header_row.add_child(badge_panel)

	_lbl_badge = Label.new()
	_lbl_badge.text = "آموزش کافه فکر"
	_lbl_badge.add_theme_font_override("font", FONT_VAZIR)
	_lbl_badge.add_theme_font_size_override("font_size", 13)
	_lbl_badge.add_theme_color_override("font_color", GOLD_BRIGHT)
	badge_panel.add_child(_lbl_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_lbl_step_counter = Label.new()
	_lbl_step_counter.text = ""
	_lbl_step_counter.add_theme_font_override("font", FONT_VAZIR)
	_lbl_step_counter.add_theme_font_size_override("font_size", 13)
	_lbl_step_counter.add_theme_color_override("font_color", MUTED_GOLD)
	header_row.add_child(_lbl_step_counter)

	# Title
	_lbl_title = Label.new()
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_title.add_theme_font_override("font", FONT_HEKAYAT)
	_lbl_title.add_theme_font_size_override("font_size", 26)
	_lbl_title.add_theme_color_override("font_color", GOLD_BRIGHT)
	_lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_title.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_title.add_theme_constant_override("shadow_outline_size", 2)
	vbox.add_child(_lbl_title)

	# Divider
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1.5)
	divider.color = Color(0.86, 0.68, 0.30, 0.32)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(divider)

	# Body
	_lbl_body = Label.new()
	_lbl_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_body.add_theme_font_override("font", FONT_VAZIR)
	_lbl_body.add_theme_font_size_override("font_size", 16)
	_lbl_body.add_theme_color_override("font_color", CREAM_TEXT)
	vbox.add_child(_lbl_body)

	# Interactive prompt chip
	_hint_chip = PanelContainer.new()
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0.10, 0.28, 0.17, 0.94)
	hint_sb.border_color = Color(0.42, 0.88, 0.56, 0.88)
	hint_sb.set_border_width_all(1)
	hint_sb.set_corner_radius_all(12)
	hint_sb.content_margin_left = 12
	hint_sb.content_margin_right = 12
	hint_sb.content_margin_top = 7
	hint_sb.content_margin_bottom = 7
	_hint_chip.add_theme_stylebox_override("panel", hint_sb)
	_hint_chip.visible = false
	vbox.add_child(_hint_chip)

	_lbl_hint = Label.new()
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_hint.add_theme_font_override("font", FONT_VAZIR)
	_lbl_hint.add_theme_font_size_override("font_size", 14)
	_lbl_hint.add_theme_color_override("font_color", Color(0.84, 1.0, 0.88, 1.0))
	_hint_chip.add_child(_lbl_hint)

	# Gentle inline nudge label (shown if user taps wrong spot)
	_nudge_lbl = Label.new()
	_nudge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nudge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nudge_lbl.add_theme_font_override("font", FONT_VAZIR)
	_nudge_lbl.add_theme_font_size_override("font_size", 13)
	_nudge_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42, 1.0))
	_nudge_lbl.visible = false
	vbox.add_child(_nudge_lbl)

	# Step progress dots
	_dots_container = HBoxContainer.new()
	_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_dots_container)

	# Action buttons row
	_btn_row = HBoxContainer.new()
	_btn_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_btn_row)

	_btn_next = Button.new()
	_btn_next.text = "بعدی"
	_btn_next.custom_minimum_size = Vector2(170, 50)
	_btn_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_next.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_next.add_theme_font_size_override("font_size", 22)
	KenneyUI.style_button(_btn_next, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(_btn_next, "tap_button")
	_btn_next.pressed.connect(func():
		AudioManager.sfx_button()
		next_pressed.emit()
	)
	_btn_row.add_child(_btn_next)

	_btn_back = Button.new()
	_btn_back.text = "قبلی"
	_btn_back.custom_minimum_size = Vector2(104, 50)
	_btn_back.add_theme_font_override("font", FONT_HEKAYAT)
	_btn_back.add_theme_font_size_override("font_size", 20)
	KenneyUI.style_button(_btn_back, KenneyUI.COLOR_GREY)
	ActionVFXManager.apply_button_juice(_btn_back, "tap_button")
	_btn_back.pressed.connect(func():
		AudioManager.sfx_tap()
		back_pressed.emit()
	)
	_btn_row.add_child(_btn_back)


func _make_scrim_rect(node_name: String) -> ColorRect:
	var cr := ColorRect.new()
	cr.name = node_name
	cr.color = SCRIM_COLOR
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	cr.gui_input.connect(_on_scrim_gui_input)
	_root.add_child(cr)
	return cr


func _on_scrim_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		if _current_step and _current_step.require_target_action:
			show_nudge("ابتدا بخش روشن‌شده را لمس کنید")


func _on_hole_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		target_area_tapped.emit()


func show_step(step: TutorialStep, step_index: int, total_steps: int, can_go_back: bool = false) -> void:
	_current_step = step
	_anim_time = 0.0
	visible = true
	set_process(true)

	# Populate text & progress
	_lbl_badge.text = step.badge_text if not step.badge_text.is_empty() else "آموزش کافه فکر"
	_lbl_step_counter.text = "مرحله %s از %s" % [_to_fa_digits(step_index + 1), _to_fa_digits(total_steps)]
	_lbl_title.text = step.title
	_lbl_body.text = step.body
	_nudge_lbl.visible = false

	_rebuild_progress_dots(step_index, total_steps)

	# Interaction mode
	var show_hint: bool = step.allow_target_passthrough and not step.interactive_hint.is_empty()
	_hint_chip.visible = show_hint
	if show_hint:
		_lbl_hint.text = step.interactive_hint

	var show_next: bool = (not step.require_target_action) or step.show_next_with_passthrough
	_btn_next.visible = show_next
	_btn_next.text = step.cta_text if not step.cta_text.is_empty() else "بعدی"
	_btn_back.visible = can_go_back and (not step.require_target_action)
	_btn_row.visible = _btn_next.visible or _btn_back.visible

	_hole_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE if step.allow_target_passthrough else Control.MOUSE_FILTER_STOP

	# Corner radius matching highlighted target
	var rad: int = int(clampf(step.corner_radius, 8.0, 36.0))
	_ring_style.set_corner_radius_all(rad)
	_glow_style.set_corner_radius_all(rad + 4)

	# Resolve target immediately so there's no 1-frame flash
	_update_target_rect(true)
	_layout_overlay()
	_animate_card_entrance()


func hide_overlay() -> void:
	_current_step = null
	_rect_initialized = false
	_has_target = false
	visible = false
	set_process(false)


func show_nudge(text: String) -> void:
	if not is_instance_valid(_nudge_lbl):
		return
	_nudge_lbl.text = text
	_nudge_lbl.visible = true
	_nudge_lbl.modulate.a = 1.0
	if _nudge_tween and _nudge_tween.is_valid():
		_nudge_tween.kill()
	_nudge_tween = create_tween()
	_nudge_tween.tween_interval(2.0)
	_nudge_tween.tween_property(_nudge_lbl, "modulate:a", 0.0, 0.35)
	_nudge_tween.tween_callback(func():
		if is_instance_valid(_nudge_lbl):
			_nudge_lbl.visible = false
	)


func _rebuild_progress_dots(active_index: int, total_steps: int) -> void:
	for child in _dots_container.get_children():
		child.queue_free()
	if total_steps <= 1 or total_steps > 16:
		_dots_container.visible = false
		return
	_dots_container.visible = true
	for i in range(total_steps):
		var dot := Panel.new()
		var is_active: bool = (i == active_index)
		var is_done: bool = (i < active_index)
		dot.custom_minimum_size = Vector2(18 if is_active else 7, 7)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		if is_active:
			sb.bg_color = GOLD_BRIGHT
		elif is_done:
			sb.bg_color = Color(0.45, 0.80, 0.52, 0.85)
		else:
			sb.bg_color = Color(0.55, 0.45, 0.34, 0.42)
		dot.add_theme_stylebox_override("panel", sb)
		_dots_container.add_child(dot)


func _animate_card_entrance() -> void:
	if not is_instance_valid(_coach_card):
		return
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	_coach_card.modulate.a = 0.0
	_coach_card.scale = Vector2(0.94, 0.94)
	_coach_card.pivot_offset = _coach_card.size * 0.5
	_card_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_property(_coach_card, "modulate:a", 1.0, 0.18)
	_card_tween.tween_property(_coach_card, "scale", Vector2.ONE, 0.24)


func _process(delta: float) -> void:
	if not visible or _current_step == null:
		return
	_anim_time += delta
	_update_target_rect(false, delta)
	_layout_overlay()
	_update_pulse_visuals()


func _resolve_raw_target_rect() -> Rect2:
	if _current_step == null or not _current_step.target_provider.is_valid():
		return Rect2()
	var res: Variant = _current_step.target_provider.call()
	if res == null:
		return Rect2()
	if res is Control:
		var ctrl: Control = res as Control
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree():
			return Rect2()
		var r: Rect2 = ctrl.get_global_rect()
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			return Rect2()
		return r
	if res is Rect2:
		var r2: Rect2 = res as Rect2
		if r2.size.x <= 1.0 or r2.size.y <= 1.0:
			return Rect2()
		return r2
	return Rect2()


func _update_target_rect(snap_immediately: bool, delta: float = 0.016) -> void:
	var raw: Rect2 = _resolve_raw_target_rect()
	if raw.size.x <= 1.0 or raw.size.y <= 1.0:
		_has_target = false
		_rect_initialized = false
		return

	var pad: float = _current_step.padding if _current_step != null else 10.0
	var vp_size: Vector2 = _get_viewport_size()
	var padded := Rect2(
		maxf(2.0, raw.position.x - pad),
		maxf(2.0, raw.position.y - pad),
		minf(vp_size.x - 4.0, raw.size.x + pad * 2.0),
		minf(vp_size.y - 4.0, raw.size.y + pad * 2.0)
	)
	padded.position.x = clampf(padded.position.x, 2.0, maxf(2.0, vp_size.x - padded.size.x - 2.0))
	padded.position.y = clampf(padded.position.y, 2.0, maxf(2.0, vp_size.y - padded.size.y - 2.0))

	_has_target = true
	_target_rect = padded
	if snap_immediately or not _rect_initialized:
		_display_rect = _target_rect
		_rect_initialized = true
	else:
		var t: float = clampf(delta * 16.0, 0.0, 1.0)
		_display_rect = Rect2(
			_display_rect.position.lerp(_target_rect.position, t),
			_display_rect.size.lerp(_target_rect.size, t)
		)


func _layout_overlay() -> void:
	var vp: Vector2 = _get_viewport_size()
	var card_w: float = clampf(vp.x - CARD_SAFE_MARGIN * 2.0, 300.0, 560.0)
	_coach_card.custom_minimum_size = Vector2(card_w, 0.0)
	_coach_card.size.x = card_w
	var card_h: float = maxf(_coach_card.get_combined_minimum_size().y, _coach_card.size.y)
	_coach_card.size = Vector2(card_w, card_h)
	_coach_card.pivot_offset = _coach_card.size * 0.5

	if not _has_target:
		# Full-screen scrim, centered card
		_scrim_top.position = Vector2.ZERO
		_scrim_top.size = vp
		_scrim_top.visible = true
		_scrim_bottom.visible = false
		_scrim_left.visible = false
		_scrim_right.visible = false
		_hole_blocker.visible = false
		_spotlight_ring.visible = false
		_spotlight_outer_glow.visible = false
		_pointer_lbl.visible = false

		_coach_card.position = Vector2(
			(vp.x - card_w) * 0.5,
			clampf((vp.y - card_h) * 0.5, CARD_SAFE_MARGIN, maxf(CARD_SAFE_MARGIN, vp.y - card_h - CARD_SAFE_MARGIN))
		)
		return

	var r: Rect2 = _display_rect
	var right_x: float = r.position.x + r.size.x
	var bottom_y: float = r.position.y + r.size.y

	# 4-panel spotlight cutout
	_scrim_top.visible = true
	_scrim_top.position = Vector2(0.0, 0.0)
	_scrim_top.size = Vector2(vp.x, maxf(0.0, r.position.y))

	_scrim_bottom.visible = true
	_scrim_bottom.position = Vector2(0.0, bottom_y)
	_scrim_bottom.size = Vector2(vp.x, maxf(0.0, vp.y - bottom_y))

	_scrim_left.visible = true
	_scrim_left.position = Vector2(0.0, r.position.y)
	_scrim_left.size = Vector2(maxf(0.0, r.position.x), r.size.y)

	_scrim_right.visible = true
	_scrim_right.position = Vector2(right_x, r.position.y)
	_scrim_right.size = Vector2(maxf(0.0, vp.x - right_x), r.size.y)

	_hole_blocker.visible = true
	_hole_blocker.position = r.position
	_hole_blocker.size = r.size

	# Spotlight ring & outer glow
	_spotlight_ring.visible = true
	_spotlight_ring.position = r.position
	_spotlight_ring.size = r.size

	_spotlight_outer_glow.visible = true
	_spotlight_outer_glow.position = r.position - Vector2(5.0, 5.0)
	_spotlight_outer_glow.size = r.size + Vector2(10.0, 10.0)

	# Smart card placement (never overlaps the spotlighted target)
	var placement: String = _current_step.card_placement if _current_step != null else "auto"
	var space_below: float = vp.y - bottom_y - CARD_SAFE_MARGIN
	var space_above: float = r.position.y - CARD_SAFE_MARGIN
	var place_below: bool = true

	if placement == "top":
		place_below = false
	elif placement == "bottom":
		place_below = true
	else:
		if space_below >= card_h + CARD_GAP_FROM_TARGET:
			place_below = true
		elif space_above >= card_h + CARD_GAP_FROM_TARGET:
			place_below = false
		else:
			place_below = (space_below >= space_above)

	var card_x: float = (vp.x - card_w) * 0.5
	var card_y: float = 0.0
	var bob: float = sin(_anim_time * 5.2) * 5.0
	var target_cx: float = clampf(r.position.x + r.size.x * 0.5, 32.0, vp.x - 32.0)

	_pointer_lbl.visible = true
	if place_below:
		card_y = clampf(bottom_y + CARD_GAP_FROM_TARGET + 10.0, CARD_SAFE_MARGIN, maxf(CARD_SAFE_MARGIN, vp.y - card_h - CARD_SAFE_MARGIN))
		_pointer_lbl.text = "▲"
		_pointer_lbl.position = Vector2(target_cx - 22.0, bottom_y + 2.0 + bob)
	else:
		card_y = clampf(r.position.y - card_h - CARD_GAP_FROM_TARGET - 10.0, CARD_SAFE_MARGIN, maxf(CARD_SAFE_MARGIN, vp.y - card_h - CARD_SAFE_MARGIN))
		_pointer_lbl.text = "▼"
		_pointer_lbl.position = Vector2(target_cx - 22.0, r.position.y - 36.0 - bob)

	_coach_card.position = Vector2(card_x, card_y)


func _update_pulse_visuals() -> void:
	if not _has_target:
		return
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.4)
	_glow_style.border_color = Color(1.0, 0.85, 0.35, lerpf(0.22, 0.65, pulse))
	_ring_style.border_color = Color(1.0, lerpf(0.80, 0.94, pulse), lerpf(0.32, 0.58, pulse), 1.0)
	if _hint_chip.visible:
		_hint_chip.modulate = Color(1.0, 1.0, 1.0, lerpf(0.82, 1.0, pulse))


func _get_viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	return Vector2(720.0, 1280.0)


static func _to_fa_digits(val: Variant) -> String:
	var s: String = str(val)
	var fa: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out: String = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out
