class_name UnoOpponentSeat
extends PanelContainer

# UnoOpponentSeat - Compact, Premium Opponent Table Seat Pod
# Displays Avatar, Player Name, Remaining Cards Count, Miniature Card-Back Fan,
# Active Turn Highlight, and UNO! Alert without cluttering the central playing area.

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")
static var _avatar_cache: Dictionary = {}

var player_id: int = 0
var seat_slot: int = 1 # 1=Top, 2=Left, 3=Right
var card_count: int = 7
var is_active_turn: bool = false

var _panel_style: StyleBoxFlat
var _avatar_frame_style: StyleBoxFlat
var _avatar_rect: TextureRect
var _name_label: Label
var _turn_tag: Label
var _count_badge_style: StyleBoxFlat
var _count_label: Label
var _mini_fan_ctrl: MiniCardFanControl

class MiniCardFanControl extends Control:
	var count: int = 7
	var is_uno: bool = false

	func _ready() -> void:
		custom_minimum_size = Vector2(54, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var vis = clampi(count, 0, 7)
		if vis <= 0:
			return
		var center_x = size.x * 0.5
		var base_y = size.y * 0.56
		for i in range(vis):
			var norm = float(i) - float(vis - 1) * 0.5
			var cx = center_x + norm * 5.2
			var cy = base_y + absf(norm) * 1.1
			var rect = Rect2(Vector2(cx - 8.0, cy - 11.0), Vector2(16.0, 22.0))
			draw_rect(rect, Color.WHITE, true)
			var inner = rect.grow(-1.5)
			draw_rect(inner, Color(0.88, 0.16, 0.19) if is_uno else Color(0.11, 0.12, 0.16), true)
			draw_circle(inner.get_center(), 4.2, Color(0.90, 0.18, 0.20) if not is_uno else Color(1.0, 0.86, 0.22))

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(228, 72)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.08, 0.11, 0.10, 0.92)
	_panel_style.border_color = Color(0.78, 0.64, 0.32, 0.48)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(18)
	_panel_style.shadow_color = Color(0, 0, 0, 0.38)
	_panel_style.shadow_size = 8
	_panel_style.content_margin_left = 10
	_panel_style.content_margin_right = 10
	_panel_style.content_margin_top = 6
	_panel_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", _panel_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# 1. Avatar Medallion
	var av_panel = PanelContainer.new()
	av_panel.custom_minimum_size = Vector2(52, 52)
	av_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_frame_style = StyleBoxFlat.new()
	_avatar_frame_style.bg_color = Color(0.14, 0.16, 0.18)
	_avatar_frame_style.border_color = Color(0.84, 0.68, 0.32, 0.75)
	_avatar_frame_style.set_border_width_all(2)
	_avatar_frame_style.set_corner_radius_all(14)
	_avatar_frame_style.content_margin_left = 3
	_avatar_frame_style.content_margin_right = 3
	_avatar_frame_style.content_margin_top = 3
	_avatar_frame_style.content_margin_bottom = 3
	av_panel.add_theme_stylebox_override("panel", _avatar_frame_style)
	hbox.add_child(av_panel)

	_avatar_rect = TextureRect.new()
	_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_panel.add_child(_avatar_rect)

	# 2. Name & Turn Status Column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.text = "حریف"
	_name_label.clip_text = true
	_name_label.add_theme_font_override("font", FontHekayat)
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	info_vbox.add_child(_name_label)

	_turn_tag = Label.new()
	_turn_tag.text = "در انتظار نوبت"
	_turn_tag.add_theme_font_override("font", FontHekayat)
	_turn_tag.add_theme_font_size_override("font_size", 14)
	_turn_tag.add_theme_color_override("font_color", Color(0.68, 0.76, 0.72))
	info_vbox.add_child(_turn_tag)

	# 3. Miniature Card-Back Fan + Remaining Count Badge
	_mini_fan_ctrl = MiniCardFanControl.new()
	hbox.add_child(_mini_fan_ctrl)

	var count_panel = PanelContainer.new()
	count_panel.custom_minimum_size = Vector2(46, 46)
	count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_badge_style = StyleBoxFlat.new()
	_count_badge_style.bg_color = Color(0.12, 0.16, 0.22, 0.96)
	_count_badge_style.border_color = Color(0.88, 0.74, 0.36, 0.85)
	_count_badge_style.set_border_width_all(2)
	_count_badge_style.set_corner_radius_all(12)
	count_panel.add_theme_stylebox_override("panel", _count_badge_style)
	hbox.add_child(count_panel)

	_count_label = Label.new()
	_count_label.text = "۷"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_override("font", FontHekayat)
	_count_label.add_theme_font_size_override("font_size", 24)
	_count_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	count_panel.add_child(_count_label)

func update_opponent(pid: int, p_name: String, avatar_id: int, cards_left: int, active_turn: bool, rank_place: int = 0) -> void:
	player_id = pid
	card_count = cards_left
	is_active_turn = active_turn

	if is_instance_valid(_name_label):
		_name_label.text = p_name

	if is_instance_valid(_avatar_rect):
		var tex = _get_avatar_texture(avatar_id)
		if tex:
			_avatar_rect.texture = tex

	if is_instance_valid(_mini_fan_ctrl):
		_mini_fan_ctrl.count = cards_left
		_mini_fan_ctrl.is_uno = (cards_left == 1)
		_mini_fan_ctrl.queue_redraw()

	if is_instance_valid(_count_label):
		if rank_place == 1 or cards_left == 0:
			_count_label.text = "👑"
		elif rank_place == 2:
			_count_label.text = "🥈"
		elif cards_left == 1:
			_count_label.text = "🔥۱"
		else:
			_count_label.text = UnoCardWidget.to_fa_digits(str(cards_left))

	if is_instance_valid(_turn_tag):
		if rank_place == 1 or cards_left == 0:
			_turn_tag.text = "تمام کرد!"
			_turn_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif cards_left == 1:
			_turn_tag.text = "🔥 تک‌کارت (UNO!)"
			_turn_tag.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
		elif active_turn:
			_turn_tag.text = "🟢 نوبت بازی"
			_turn_tag.add_theme_color_override("font_color", Color(0.42, 0.98, 0.62))
		else:
			_turn_tag.text = "%s کارت باقی‌مانده" % UnoCardWidget.to_fa_digits(str(cards_left))
			_turn_tag.add_theme_color_override("font_color", Color(0.68, 0.76, 0.72))

	if active_turn:
		_panel_style.bg_color = Color(0.07, 0.20, 0.14, 0.96)
		_panel_style.border_color = Color(0.38, 0.96, 0.58, 1.0)
		_panel_style.set_border_width_all(3)
		_panel_style.shadow_color = Color(0.20, 0.90, 0.48, 0.42)
		_panel_style.shadow_size = 12
		_avatar_frame_style.border_color = Color(0.38, 0.96, 0.58, 1.0)
	elif cards_left == 1:
		_panel_style.bg_color = Color(0.22, 0.08, 0.09, 0.95)
		_panel_style.border_color = Color(0.96, 0.32, 0.32, 0.95)
		_panel_style.set_border_width_all(2)
		_panel_style.shadow_color = Color(0.95, 0.22, 0.22, 0.35)
		_panel_style.shadow_size = 10
		_avatar_frame_style.border_color = Color(0.96, 0.32, 0.32, 0.95)
	else:
		_panel_style.bg_color = Color(0.08, 0.11, 0.10, 0.88)
		_panel_style.border_color = Color(0.78, 0.64, 0.32, 0.42)
		_panel_style.set_border_width_all(2)
		_panel_style.shadow_color = Color(0, 0, 0, 0.35)
		_panel_style.shadow_size = 6
		_avatar_frame_style.border_color = Color(0.84, 0.68, 0.32, 0.65)

func get_card_origin_global_pos() -> Vector2:
	if is_instance_valid(_mini_fan_ctrl):
		return _mini_fan_ctrl.global_position + _mini_fan_ctrl.size * 0.5
	return global_position + size * 0.5

static func _get_avatar_texture(av_id: int) -> Texture2D:
	var safe_id = clampi(av_id, 0, 30)
	if _avatar_cache.has(safe_id):
		return _avatar_cache[safe_id]
	var path = "res://assets/icons/Avatars/%d.png" % safe_id
	if ResourceLoader.exists(path):
		var tex = load(path)
		_avatar_cache[safe_id] = tex
		return tex
	if ResourceLoader.exists("res://assets/icons/Avatars/0.png"):
		var fallback = load("res://assets/icons/Avatars/0.png")
		_avatar_cache[safe_id] = fallback
		return fallback
	return null
