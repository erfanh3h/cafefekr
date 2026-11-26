class_name UITypography
extends RefCounted

## Cafe Fekr — Centralized Responsive Typography & Layout Metrics
## Provides semantic text roles, minimum legibility floors, viewport-aware scaling,
## safe-area calculation, dialog sizing, and BiDi/RTL typography utilities.

const BASE_VIEWPORT := Vector2(720.0, 1280.0)
const ABSOLUTE_MIN_FONT_PX: int = 14
const COMPACT_MIN_FONT_PX: int = 14
const STANDARD_MIN_FONT_PX: int = 15

const FONT_DISPLAY: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_UI: FontFile = preload("res://assets/fonts/Vazir.ttf")

enum Role {
	DISPLAY_XL,
	DISPLAY,
	TITLE_LG,
	TITLE,
	TITLE_SM,
	SUBTITLE,
	BODY_LG,
	BODY,
	BODY_SM,
	CAPTION,
	MICRO,
	BUTTON_HERO,
	BUTTON_LG,
	BUTTON_MD,
	BUTTON_SM,
	INPUT,
}

# { Role: [base_px, min_px, max_px, use_display_font] }
const ROLE_SPECS: Dictionary = {
	Role.DISPLAY_XL: [46, 34, 64, true],
	Role.DISPLAY: [36, 28, 48, true],
	Role.TITLE_LG: [32, 24, 42, true],
	Role.TITLE: [27, 21, 36, true],
	Role.TITLE_SM: [23, 18, 30, true],
	Role.SUBTITLE: [20, 17, 26, false],
	Role.BODY_LG: [22, 18, 28, false],
	Role.BODY: [19, 16, 24, false],
	Role.BODY_SM: [17, 15, 22, false],
	Role.CAPTION: [16, 14, 20, false],
	Role.MICRO: [15, 14, 18, false],
	Role.BUTTON_HERO: [30, 24, 38, true],
	Role.BUTTON_LG: [25, 20, 32, true],
	Role.BUTTON_MD: [21, 17, 26, false],
	Role.BUTTON_SM: [18, 15, 22, false],
	Role.INPUT: [22, 18, 28, false],
}

static var _cached_viewport_size: Vector2 = BASE_VIEWPORT
static var _cached_font_scale: float = 1.0
static var _cached_ui_scale: float = 1.0
static var _user_text_scale: float = 1.0


static func update_viewport_metrics(vp_size: Vector2, user_scale: float = _user_text_scale) -> void:
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	_cached_viewport_size = vp_size
	_user_text_scale = clampf(user_scale, 0.90, 1.20)

	var w_ratio: float = vp_size.x / BASE_VIEWPORT.x
	var h_ratio: float = vp_size.y / BASE_VIEWPORT.y
	var min_ratio: float = minf(w_ratio, h_ratio)

	# On narrower viewports (< 720px logical), gently scale down so labels don't overflow.
	# On standard portrait phones (720x1280..1600), keep 1.0 baseline.
	# On wider tablets/desktop (>= 760px), gently scale up so text never looks tiny.
	var base_font_scale: float = 1.0
	if min_ratio < 0.99:
		base_font_scale = clampf(min_ratio, 0.85, 1.0)
	elif vp_size.x > 760.0:
		base_font_scale = clampf(1.0 + (minf(w_ratio, 1.60) - 1.0) * 0.22, 1.0, 1.15)

	_cached_font_scale = clampf(base_font_scale * _user_text_scale, 0.84, 1.28)
	_cached_ui_scale = clampf(min_ratio, 0.85, 1.18) if min_ratio < 1.0 else clampf(1.0 + (minf(w_ratio, 1.50) - 1.0) * 0.20, 1.0, 1.14)


static func get_viewport_size() -> Vector2:
	return _cached_viewport_size


static func get_font_scale() -> float:
	return _cached_font_scale


static func get_ui_scale() -> float:
	return _cached_ui_scale


static func is_compact_width() -> bool:
	return _cached_viewport_size.x < 680.0


static func is_short_height() -> bool:
	return _cached_viewport_size.y < 1180.0


static func is_wide_screen() -> bool:
	return (_cached_viewport_size.x / maxf(1.0, _cached_viewport_size.y)) >= 0.72


static func is_tall_screen() -> bool:
	return (_cached_viewport_size.x / maxf(1.0, _cached_viewport_size.y)) <= 0.50


static func get_role_font_size(role: int, custom_min: int = -1, custom_max: int = -1) -> int:
	var spec: Array = ROLE_SPECS.get(role, [19, 16, 24, false])
	var base_px: int = int(spec[0])
	var min_px: int = custom_min if custom_min > 0 else int(spec[1])
	var max_px: int = custom_max if custom_max > 0 else int(spec[2])
	return clampi(int(round(float(base_px) * _cached_font_scale)), min_px, max_px)


static func normalize_raw_px(raw_px: int) -> int:
	if raw_px <= 11:
		return 14
	if raw_px == 12:
		return 15
	if raw_px <= 14:
		return 16
	if raw_px == 15:
		return 17
	return raw_px


static func scale_px(base_px: int, min_px: int = STANDARD_MIN_FONT_PX, max_px: int = 72) -> int:
	var normalized: int = normalize_raw_px(base_px)
	var effective_min: int = maxi(ABSOLUTE_MIN_FONT_PX, min_px)
	var effective_max: int = maxi(effective_min, max_px)
	return clampi(int(round(float(normalized) * _cached_font_scale)), effective_min, effective_max)


static func scale_space(base_space: float, min_space: float = 0.0, max_space: float = 9999.0) -> float:
	return clampf(round(base_space * _cached_ui_scale), min_space, max_space)


static func get_role_font(role: int) -> FontFile:
	var spec: Array = ROLE_SPECS.get(role, [19, 16, 24, false])
	return FONT_DISPLAY if bool(spec[3]) else FONT_UI


static func get_safe_insets(viewport: Viewport = null) -> Dictionary:
	var result := {"top": 14, "bottom": 14, "left": 12, "right": 12}
	if viewport == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			viewport = tree.root
	if viewport == null:
		return result
	var vp_rect := viewport.get_visible_rect()
	if vp_rect.size.x <= 0.0 or vp_rect.size.y <= 0.0:
		return result
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return result
	var safe_rect := DisplayServer.get_display_safe_area()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return result
	var scale_x: float = vp_rect.size.x / float(screen_size.x)
	var scale_y: float = vp_rect.size.y / float(screen_size.y)
	var top_px := int(ceil(float(safe_rect.position.y) * scale_y))
	var bottom_raw := int(ceil(float(screen_size.y - safe_rect.end.y) * scale_y))
	var left_px := int(ceil(float(safe_rect.position.x) * scale_x))
	var right_px := int(ceil(float(screen_size.x - safe_rect.end.x) * scale_x))
	result["top"] = clampi(maxi(14, top_px + 6), 14, 56)
	result["bottom"] = clampi(maxi(14, bottom_raw + 6), 14, 48)
	result["left"] = clampi(maxi(10, left_px + 8), 10, 32)
	result["right"] = clampi(maxi(10, right_px + 8), 10, 32)
	return result


static func compute_dialog_size(pref_w: float, pref_h: float, vp_size: Vector2 = Vector2.ZERO, insets: Dictionary = {}, min_w: float = 300.0, min_h: float = 220.0) -> Vector2:
	var vs: Vector2 = vp_size if vp_size.x > 1.0 and vp_size.y > 1.0 else _cached_viewport_size
	var left_pad: float = float(insets.get("left", 12)) + 12.0
	var right_pad: float = float(insets.get("right", 12)) + 12.0
	var top_pad: float = float(insets.get("top", 14)) + 14.0
	var bottom_pad: float = float(insets.get("bottom", 14)) + 14.0
	var avail_w: float = maxf(min_w, vs.x - left_pad - right_pad)
	var avail_h: float = maxf(min_h, vs.y - top_pad - bottom_pad)
	# On wide tablet/desktop viewports, cap modal width sensibly so lines stay readable
	var max_readable_w: float = maxf(pref_w, minf(vs.x * 0.88, 760.0))
	var target_w: float = clampf(pref_w * _cached_ui_scale, min_w, minf(avail_w, max_readable_w))
	var target_h: float = clampf(pref_h * _cached_ui_scale, min_h, avail_h)
	return Vector2(round(target_w), round(target_h))


static func configure_bidi(ctrl: Control, clip_ellipsis: bool = false, wrap: bool = false) -> void:
	if not is_instance_valid(ctrl):
		return
	if ctrl is Label:
		var lbl := ctrl as Label
		if lbl.text_direction == Control.TEXT_DIRECTION_INHERITED:
			lbl.text_direction = Control.TEXT_DIRECTION_AUTO
		if wrap:
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif clip_ellipsis:
			lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			lbl.clip_text = true
			lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	elif ctrl is RichTextLabel:
		var rtl := ctrl as RichTextLabel
		if rtl.text_direction == Control.TEXT_DIRECTION_INHERITED:
			rtl.text_direction = Control.TEXT_DIRECTION_AUTO
	elif ctrl is LineEdit:
		var le := ctrl as LineEdit
		if le.text_direction == Control.TEXT_DIRECTION_INHERITED:
			le.text_direction = Control.TEXT_DIRECTION_AUTO
	elif ctrl is TextEdit:
		var te := ctrl as TextEdit
		if te.text_direction == Control.TEXT_DIRECTION_INHERITED:
			te.text_direction = Control.TEXT_DIRECTION_AUTO


static func apply_text(ctrl: Control, role: int, options: Dictionary = {}) -> void:
	if not is_instance_valid(ctrl):
		return
	var custom_min: int = int(options.get("min_px", -1))
	var custom_max: int = int(options.get("max_px", -1))
	var px: int = get_role_font_size(role, custom_min, custom_max)

	ctrl.set_meta(&"_resp_role", role)
	if custom_min > 0:
		ctrl.set_meta(&"_resp_min_px", custom_min)
	if custom_max > 0:
		ctrl.set_meta(&"_resp_max_px", custom_max)
	ctrl.set_meta(&"_resp_managed", true)

	if bool(options.get("set_font", false)):
		var f: FontFile = options.get("font", null) as FontFile
		if f == null:
			f = get_role_font(role)
		ctrl.add_theme_font_override("font", f)

	if ctrl is RichTextLabel:
		ctrl.add_theme_font_size_override("normal_font_size", px)
		ctrl.add_theme_font_size_override("bold_font_size", px + 2)
		ctrl.add_theme_font_size_override("italics_font_size", px)
	else:
		ctrl.add_theme_font_size_override("font_size", px)

	var wrap: bool = bool(options.get("wrap", false))
	var ellipsis: bool = bool(options.get("ellipsis", false))
	if options.has("wrap") or options.has("ellipsis"):
		configure_bidi(ctrl, ellipsis, wrap)
	else:
		configure_bidi(ctrl, false, false)


static func fit_label_to_width(lbl: Label, max_width: float, base_px: int, min_px: int = ABSOLUTE_MIN_FONT_PX) -> int:
	if not is_instance_valid(lbl):
		return base_px
	var scaled_base: int = scale_px(base_px, min_px)
	var effective_min: int = clampi(min_px, ABSOLUTE_MIN_FONT_PX, scaled_base)
	var font: Font = lbl.get_theme_font("font")
	if font == null or max_width <= 8.0 or lbl.text.is_empty():
		lbl.add_theme_font_size_override("font_size", scaled_base)
		return scaled_base
	var chosen: int = scaled_base
	while chosen > effective_min:
		var w: float = font.get_string_size(lbl.text, lbl.horizontal_alignment, -1, chosen).x
		if w <= max_width:
			break
		chosen -= 1
	lbl.add_theme_font_size_override("font_size", chosen)
	return chosen
