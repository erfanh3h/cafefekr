class_name TutorialCoachOverlay
extends CanvasLayer

## Reusable Cafe Fekr Warm Parlor interactive Spotlight & Coach Card overlay.
## - Styled with the authentic `res://assets/images/frames/dialog.png` 9-slice frame.
## - Uses a 4-panel dark dimmer scrim around a live spotlight cutout so touches
##   inside the spotlight pass natively to Buttons or 3D boards.
## - Strictly compact content-fitted height (never stretches vertically) and
##   avoid-rect aware positioning so top HUD buttons and the 3D game board stay
##   100% visible and unobstructed.

signal next_pressed()
signal back_pressed()
signal target_area_tapped()

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")
const DIALOG_FRAME_TEX: Texture2D = preload("res://assets/images/frames/dialog.png")

const SCRIM_RGB: Color = Color(0.03, 0.015, 0.008, 1.0)
const GOLD_BRIGHT: Color = Color(1.0, 0.88, 0.45, 1.0)
const CREAM_TEXT: Color = Color(0.96, 0.92, 0.84, 1.0)
const MUTED_GOLD: Color = Color(0.84, 0.74, 0.55, 1.0)

const CARD_SAFE_MARGIN: float = 16.0
const CARD_GAP_FROM_TARGET: float = 34.0
const CARD_GAP_FROM_AVOID: float = 16.0
const DIALOG_CONTENT_PAD_X: float = 44.0
const DIALOG_CONTENT_PAD_TOP: float = 86.0
const DIALOG_CONTENT_PAD_BOTTOM: float = 80.0

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
var _card_vbox: VBoxContainer = null
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
	_glow_style.border_color = Color(1.0, 0.85, 0.35, 0.45)
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

	# Authentic Cafe Fekr `dialog.png` 9-slice Coach Card
	_coach_card = PanelContainer.new()
	_coach_card.name = "CoachCard"
	_coach_card.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_coach_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_coach_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_coach_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := StyleBoxTexture.new()
	card_style.texture = DIALOG_FRAME_TEX
	card_style.texture_margin_left = 44.0
	card_style.texture_margin_top = 80.0
	card_style.texture_margin_right = 44.0
	card_style.texture_margin_bottom = 80.0
	card_style.content_margin_left = DIALOG_CONTENT_PAD_X
	card_style.content_margin_right = DIALOG_CONTENT_PAD_X
	card_style.content_margin_top = DIALOG_CONTENT_PAD_TOP
	card_style.content_margin_bottom = DIALOG_CONTENT_PAD_BOTTOM
	_coach_card.add_theme_stylebox_override("panel", card_style)
	_root.add_child(_coach_card)

	_card_vbox = VBoxContainer.new()
	_card_vbox.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_card_vbox.add_theme_constant_override("separation", 8)
	_coach_card.add_child(_card_vbox)

	# Top header row: Badge + Step Progress
	var header_row := HBoxContainer.new()
	header_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	header_row.add_theme_constant_override("separation", 8)
	_card_vbox.add_child(header_row)

	var badge_panel := PanelContainer.new()
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.18, 0.13, 0.06, 0.92)
	badge_sb.border_color = Color(0.86, 0.68, 0.28, 0.85)
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(10)
	badge_sb.content_margin_left = 10
	badge_sb.content_margin_right = 10
	badge_sb.content_margin_top = 2
	badge_sb.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_sb)
	header_row.add_child(badge_panel)

	_lbl_badge = Label.new()
	_lbl_badge.text = "آموزش کافه فکر"
	_lbl_badge.add_theme_font_override("font", FONT_VAZIR)
	_lbl_badge.add_theme_font_size_override("font_size", 12)
	_lbl_badge.add_theme_color_override("font_color", GOLD_BRIGHT)
	badge_panel.add_child(_lbl_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_lbl_step_counter = Label.new()
	_lbl_step_counter.text = ""
	_lbl_step_counter.add_theme_font_override("font", FONT_VAZIR)
	_lbl_step_counter.add_theme_font_size_override("font_size", 12)
	_lbl_step_counter.add_theme_color_override("font_color", MUTED_GOLD)
	header_row.add_child(_lbl_step_counter)

	# Title
	_lbl_title = Label.new()
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_title.add_theme_font_override("font", FONT_HEKAYAT)
	_lbl_title.add_theme_font_size_override("font_size", 24)
	_lbl_title.add_theme_color_override("font_color", GOLD_BRIGHT)
	_lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_title.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_title.add_theme_constant_override("shadow_outline_size", 2)
	_card_vbox.add_child(_lbl_title)

	# Subtle Gold Divider
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1.5)
	divider.color = Color(0.86, 0.68, 0.30, 0.35)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_vbox.add_child(divider)

	# Body
	_lbl_body = Label.new()
	_lbl_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_body.add_theme_font_override("font", FONT_VAZIR)
	_lbl_body.add_theme_font_size_override("font_size", 15)
	_lbl_body.add_theme_color_override("font_color", CREAM_TEXT)
	_card_vbox.add_child(_lbl_body)

	# Interactive prompt chip
	_hint_chip = PanelContainer.new()
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0.08, 0.28, 0.16, 0.94)
	hint_sb.border_color = Color(0.45, 0.90, 0.58, 0.88)
	hint_sb.set_border_width_all(1)
	hint_sb.set_corner_radius_all(10)
	hint_sb.content_margin_left = 10
	hint_sb.content_margin_right = 10
	hint_sb.content_margin_top = 6
	hint_sb.content_margin_bottom = 6
	_hint_chip.add_theme_stylebox_override("panel", hint_sb)
	_hint_chip.visible = false
	_card_vbox.add_child(_hint_chip)

	_lbl_hint = Label.new()
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_hint.add_theme_font_override("font", FONT_VAZIR)
	_lbl_hint.add_theme_font_size_override("font_size", 13)
	_lbl_hint.add_theme_color_override("font_color", Color(0.86, 1.0, 0.90, 1.0))
	_hint_chip.add_child(_lbl_hint)

	# Gentle inline nudge label (shown if user taps wrong spot)
	_nudge_lbl = Label.new()
	_nudge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nudge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nudge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nudge_lbl.add_theme_font_override("font", FONT_VAZIR)
	_nudge_lbl.add_theme_font_size_override("font_size", 13)
	_nudge_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42, 1.0))
	_nudge_lbl.visible = false
	_card_vbox.add_child(_nudge_lbl)

	# Step progress dots
	_dots_container = HBoxContainer.new()
	_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_container.add_theme_constant_override("separation", 6)
	_card_vbox.add_child(_dots_container)

	# Action buttons row
	_btn_row = HBoxContainer.new()
	_btn_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("separation", 12)
	_card_vbox.add_child(_btn_row)

	_btn_next = Button.new()
	_btn_next.text = "بعدی"
	_btn_next.custom_minimum_size = Vector2(160, 48)
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
	_btn_back.custom_minimum_size = Vector2(100, 48)
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
	cr.color = Color(SCRIM_RGB.r, SCRIM_RGB.g, SCRIM_RGB.b, 0.62)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	cr.gui_input.connect(_on_scrim_gui_input)
	_root.add_child(cr)
	return cr


func _apply_scrim_alpha(alpha: float) -> void:
	var col := Color(SCRIM_RGB.r, SCRIM_RGB.g, SCRIM_RGB.b, clampf(alpha, 0.0, 0.90))
	_scrim_top.color = col
	_scrim_bottom.color = col
	_scrim_left.color = col
	_scrim_right.color = col


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

	_apply_scrim_alpha(step.scrim_alpha)

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

	# Resolve target immediately and re-layout after deferred text wrapping pass
	_update_target_rect(true)
	_layout_overlay()
	call_deferred("_deferred_relayout")
	_animate_card_entrance()


func _deferred_relayout() -> void:
	if not visible or _current_step == null:
		return
	_update_target_rect(true)
	_layout_overlay()


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
			sb.bg_color = Color(0.45, 0.85, 0.54, 0.90)
		else:
			sb.bg_color = Color(0.55, 0.45, 0.34, 0.45)
		dot.add_theme_stylebox_override("panel", sb)
		_dots_container.add_child(dot)


func _animate_card_entrance() -> void:
	if not is_instance_valid(_coach_card):
		return
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	_coach_card.modulate.a = 0.0
	_coach_card.scale = Vector2(0.92, 0.92)
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


func _resolve_rect_from_callable(provider: Callable) -> Rect2:
	if not provider.is_valid():
		return Rect2()
	var res: Variant = provider.call()
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
	if _current_step == null:
		_has_target = false
		_rect_initialized = false
		return
	var raw: Rect2 = _resolve_rect_from_callable(_current_step.target_provider)
	if raw.size.x <= 1.0 or raw.size.y <= 1.0:
		_has_target = false
		_rect_initialized = false
		return

	var pad: float = _current_step.padding
	var vp_size: Vector2 = _get_viewport_size()
	var left: float = clampf(raw.position.x - pad, 2.0, vp_size.x - 4.0)
	var top: float = clampf(raw.position.y - pad, 2.0, vp_size.y - 4.0)
	var right: float = clampf(raw.position.x + raw.size.x + pad, left + 16.0, vp_size.x - 2.0)
	var bottom: float = clampf(raw.position.y + raw.size.y + pad, top + 16.0, vp_size.y - 2.0)
	var padded := Rect2(left, top, right - left, bottom - top)

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


func _fit_coach_card_size(vp: Vector2) -> Vector2:
	var card_w: float = clampf(vp.x - 36.0, 320.0, 600.0)
	var inner_w: float = maxf(200.0, card_w - (DIALOG_CONTENT_PAD_X * 2.0))
	var hint_w: float = maxf(160.0, inner_w - 24.0)

	# Give autowrapped Labels an explicit horizontal width before measuring so
	# Godot 4 calculates accurate wrapped line height even on frame 0.
	if not is_equal_approx(_lbl_title.custom_minimum_size.x, inner_w):
		_lbl_title.custom_minimum_size = Vector2(inner_w, 0.0)
	if _lbl_title.size.x < inner_w - 2.0:
		_lbl_title.size.x = inner_w
	if not is_equal_approx(_lbl_body.custom_minimum_size.x, inner_w):
		_lbl_body.custom_minimum_size = Vector2(inner_w, 0.0)
	if _lbl_body.size.x < inner_w - 2.0:
		_lbl_body.size.x = inner_w
	if not is_equal_approx(_lbl_hint.custom_minimum_size.x, hint_w):
		_lbl_hint.custom_minimum_size = Vector2(hint_w, 0.0)
	if _lbl_hint.size.x < hint_w - 2.0:
		_lbl_hint.size.x = hint_w
	if not is_equal_approx(_nudge_lbl.custom_minimum_size.x, inner_w):
		_nudge_lbl.custom_minimum_size = Vector2(inner_w, 0.0)
	if _nudge_lbl.size.x < inner_w - 2.0:
		_nudge_lbl.size.x = inner_w

	if not is_equal_approx(_coach_card.custom_minimum_size.x, card_w) or _coach_card.custom_minimum_size.y != 0.0:
		_coach_card.custom_minimum_size = Vector2(card_w, 0.0)

	# PanelContainer.get_combined_minimum_size() depends only on stylebox + child min sizes,
	# never latching stale _coach_card.size.y.
	var content_min_h: float = _coach_card.get_combined_minimum_size().y
	var max_card_h: float = minf(vp.y * 0.48, 520.0)
	var card_h: float = clampf(content_min_h, 240.0, max_card_h)
	var target_sz := Vector2(card_w, card_h)

	if not _coach_card.size.is_equal_approx(target_sz):
		_coach_card.size = target_sz
		_coach_card.pivot_offset = target_sz * 0.5
	return target_sz


func _layout_overlay() -> void:
	var vp: Vector2 = _get_viewport_size()
	var card_sz: Vector2 = _fit_coach_card_size(vp)
	var card_w: float = card_sz.x
	var card_h: float = card_sz.y
	var card_x: float = (vp.x - card_w) * 0.5

	if not _has_target:
		# Full-screen scrim, compact centered dialog.png modal
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
			card_x,
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

	# Determine the full protected obstacle zone (spotlight target merged with optional avoid_rect,
	# e.g., full top HUD bar or full 3D game board) so the coach dialog NEVER covers them.
	var obstacle: Rect2 = r
	var has_avoid: bool = false
	if _current_step != null and _current_step.avoid_rect_provider.is_valid():
		var avoid_r: Rect2 = _resolve_rect_from_callable(_current_step.avoid_rect_provider)
		if avoid_r.size.x > 1.0 and avoid_r.size.y > 1.0:
			obstacle = obstacle.merge(avoid_r)
			has_avoid = true

	var placement: String = _current_step.card_placement if _current_step != null else "auto"
	var obs_top: float = obstacle.position.y
	var obs_bottom: float = obstacle.position.y + obstacle.size.y
	var gap: float = CARD_GAP_FROM_AVOID if has_avoid else CARD_GAP_FROM_TARGET

	var space_below: float = vp.y - obs_bottom - CARD_SAFE_MARGIN
	var space_above: float = obs_top - CARD_SAFE_MARGIN
	var place_below: bool = true

	if placement == "top":
		place_below = not (space_above >= card_h + gap or space_above >= space_below)
	elif placement == "bottom":
		place_below = (space_below >= card_h + gap or space_below >= space_above)
	else:
		if space_below >= card_h + gap:
			place_below = true
		elif space_above >= card_h + gap:
			place_below = false
		else:
			place_below = (space_below >= space_above)

	var card_y: float = 0.0
	if place_below:
		var desired_y: float = maxf(obs_bottom + gap, bottom_y + CARD_GAP_FROM_TARGET)
		card_y = clampf(desired_y, CARD_SAFE_MARGIN, maxf(CARD_SAFE_MARGIN, vp.y - card_h - CARD_SAFE_MARGIN))
	else:
		var desired_y_top: float = minf(obs_top - card_h - gap, r.position.y - card_h - CARD_GAP_FROM_TARGET)
		card_y = clampf(desired_y_top, CARD_SAFE_MARGIN, maxf(CARD_SAFE_MARGIN, vp.y - card_h - CARD_SAFE_MARGIN))

	_coach_card.position = Vector2(card_x, card_y)

	# Position animated pointer chevron right beside the highlighted target, pointing toward it
	var bob: float = sin(_anim_time * 5.2) * 5.0
	var target_cx: float = clampf(r.position.x + r.size.x * 0.5, 32.0, vp.x - 32.0)
	var card_center_y: float = card_y + card_h * 0.5
	var target_center_y: float = r.position.y + r.size.y * 0.5

	_pointer_lbl.visible = true
	if card_center_y >= target_center_y:
		_pointer_lbl.text = "▲"
		_pointer_lbl.position = Vector2(target_cx - 22.0, clampf(bottom_y + 2.0 + bob, 4.0, vp.y - 38.0))
	else:
		_pointer_lbl.text = "▼"
		_pointer_lbl.position = Vector2(target_cx - 22.0, clampf(r.position.y - 36.0 - bob, 4.0, vp.y - 38.0))


func _update_pulse_visuals() -> void:
	if not _has_target:
		return
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.4)
	_glow_style.border_color = Color(1.0, 0.85, 0.35, lerpf(0.24, 0.68, pulse))
	_ring_style.border_color = Color(1.0, lerpf(0.80, 0.94, pulse), lerpf(0.32, 0.58, pulse), 1.0)
	if _hint_chip.visible:
		_hint_chip.modulate = Color(1.0, 1.0, 1.0, lerpf(0.84, 1.0, pulse))


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
