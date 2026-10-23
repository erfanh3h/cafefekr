class_name KenneyUI
extends RefCounted

## KenneyUI / CafeUI Helper
## Creates authentic tactile game-like UI elements with Cafe Fekr wooden frames
## High-contrast typography and juiced button interactions.

const COLOR_BLUE = "blue"
const COLOR_RED = "red"
const COLOR_GREEN = "green"
const COLOR_YELLOW = "yellow"
const COLOR_GREY = "grey"
const COLOR_WOOD = "wood"

# Cache styleboxes so we don't recreate textures on every call
static var _style_cache: Dictionary = {}
static var _wood_tex = preload("res://assets/images/frames/button.png")
static var _font_hekayat = preload("res://assets/fonts/hekayat.ttf")

static func get_button_style(color: String = "wood", state: String = "normal") -> StyleBoxTexture:
	var key = "%s_%s" % [color.to_lower(), state]
	if _style_cache.has(key):
		return _style_cache[key]
		
	var sb = StyleBoxTexture.new()
	sb.texture = _wood_tex
	sb.texture_margin_left = 36.0
	sb.texture_margin_top = 22.0
	sb.texture_margin_right = 36.0
	sb.texture_margin_bottom = 26.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	
	# Determine base tint from color while keeping authentic warm wooden grain.
	# Note: button.png is a rich orange-brown wood texture, so multiplying by low-red tints
	# (like pure blue/green) would crush the red channel into dark muddy charcoal.
	var base_tint = Color(1.0, 1.0, 1.0, 1.0)
	var c_lower = color.to_lower()
	if c_lower == COLOR_RED:
		base_tint = Color(1.0, 0.62, 0.58, 1.0) # Warm crimson-rosewood tint
	elif c_lower == COLOR_GREEN:
		base_tint = Color(0.82, 1.08, 0.78, 1.0) # Warm sage-amber wood tint
	elif c_lower == COLOR_BLUE:
		base_tint = Color(0.92, 0.96, 1.08, 1.0) # Crisp cool-walnut wood tint
	elif c_lower == COLOR_YELLOW:
		base_tint = Color(1.06, 0.98, 0.82, 1.0) # Warm golden-honey wood tint
	elif c_lower == COLOR_GREY:
		base_tint = Color(0.92, 0.88, 0.84, 1.0) # Soft weathered-oak wood tint
	else:
		base_tint = Color(1.0, 1.0, 1.0, 1.0) # Authentic natural wood
		
	if state == "pressed":
		sb.modulate_color = base_tint * Color(0.85, 0.82, 0.78, 1.0)
		sb.content_margin_left = 32.0
		sb.content_margin_right = 32.0
		sb.content_margin_top = 19.0 # Tactile 3px depress shift
		sb.content_margin_bottom = 13.0
	elif state == "hover":
		sb.modulate_color = base_tint * Color(1.14, 1.10, 1.04, 1.0) # Subtle warm highlight
		sb.content_margin_left = 32.0
		sb.content_margin_right = 32.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
	elif state == "disabled":
		sb.modulate_color = base_tint * Color(0.55, 0.52, 0.5, 0.7)
		sb.content_margin_left = 32.0
		sb.content_margin_right = 32.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
	else: # normal
		sb.modulate_color = base_tint
		sb.content_margin_left = 32.0
		sb.content_margin_right = 32.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
		
	_style_cache[key] = sb
	return sb

static func style_button(btn: BaseButton, color: String = "wood", sound: String = "tap_button") -> void:
	if not is_instance_valid(btn):
		return
		
	var st_norm = get_button_style(color, "normal")
	var st_press = get_button_style(color, "pressed")
	var st_hover = get_button_style(color, "hover")
	var st_dis = get_button_style(color, "disabled")
	
	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_press)
	btn.add_theme_stylebox_override("focus", st_hover)
	btn.add_theme_stylebox_override("disabled", st_dis)
	
	# Font styling: Persian Hekayat font
	if _font_hekayat:
		btn.add_theme_font_override("font", _font_hekayat)
		
	# Generous, thumb-friendly font sizing & touch target view
	var cur_size = btn.get_theme_font_size("font_size")
	if cur_size < 28:
		btn.add_theme_font_size_override("font_size", 28)
		
	if btn.custom_minimum_size.y < 70 and btn.custom_minimum_size.y > 0 and btn.custom_minimum_size.x > 90:
		btn.custom_minimum_size.y = 76
	elif btn.custom_minimum_size.y == 0:
		btn.custom_minimum_size.y = 76
		
	# High-Contrast Color Harmony for Authentic Wooden Background (UX Art of Coloring)
	# Crisp warm ivory / light bone white text
	btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.82, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.92, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.68, 0.65, 0.62, 0.6))
	
	# Deep rich dark espresso shadow & outline for razor-sharp legibility against wood
	btn.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.02, 0.95))
	btn.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_theme_constant_override("shadow_offset_x", 0)
	btn.add_theme_constant_override("shadow_outline_size", 2)
	btn.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02, 0.95))
	btn.add_theme_constant_override("outline_size", 2)
	
	ActionVFXManager.apply_button_juice(btn, sound)

# Creates an arcade / board-game style panel with chunky borders and rich shadow
static func create_card_style(border_col: Color, bg_col: Color, corner: int = 18, border_w: int = 4) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
