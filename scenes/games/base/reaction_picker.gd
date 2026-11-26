extends Control

# Reaction / Emote & Kori (Taunt) Popover Picker
# Opens downward from the top-right SubHeaderRail Chat / Emoji buttons.
# Supports both Sticker Reactions (IDs 1..44) and Persian Kori Taunts (IDs 101..178)

signal reaction_selected(reaction_id: int)

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var btn_backdrop_close: Button = $BtnBackdropClose
@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/Margin/VBox
@onready var lbl_title: Label = $Panel/Margin/VBox/HeaderRow/LblTitle
@onready var btn_close: Button = $Panel/Margin/VBox/HeaderRow/BtnClose
@onready var sticker_scroll: ScrollContainer = $Panel/Margin/VBox/StickerScroll
@onready var grid: GridContainer = $Panel/Margin/VBox/StickerScroll/Grid

const FONT_UI: FontFile = preload("res://assets/fonts/Vazir.ttf")

# Popular, expressive reaction IDs from assets/icons/Reactions (16 items for clean 4x4 layout)
const POPULAR_REACTIONS: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
]

# Complete Persian Kori (کری‌خوانی) list matching Flutter app_consts.dart (indices 0..77 -> reactionId 101..178)
const KORIS: Array[String] = [
	"شکست دیگه عادتت شده!",
	"عجب حرکت هوشمندانه‌ای بود!",
	"برنده فقط منم!",
	"بازی شروع نشده، تمومه!",
	"خیلی خوب بازی کردی!",
	"حریف من نیستی!",
	"بازم بردم!",
	"اون استراتژی عالی بود!",
	"قهرمان برگشته!",
	"این فقط تمرین بود!",
	"خوشم اومد از سبک بازیت!",
	"یه باخت دیگه تو کارنامت!",
	"بهتره تسلیم شی!",
	"آفرین!",
	"سریع‌تر از اینم می‌بازی؟",
	"حیف وقتی که گذاشتی!",
	"حرکتت واقعاً تحسین‌برانگیز بود!",
	"بهتره تمرین کنی!",
	"حالا یاد گرفتی؟",
	"ممنونم!",
	"راحت‌تر از این نبود!",
	"این فقط شروعشه!",
	"اون تاکتیک خیلی جالب بود!",
	"تو حتی نزدیک هم نشدی!",
	"پایانش همین بود؟",
	"این یکی رو عالی مدیریت کردی!",
	"بازم دیر کردی!",
	"این برد مال منه!",
	"ایده خوبی داشتی، بهش ادامه بده!",
	"مثل همیشه برنده!",
	"یک حرکت و تموم!",
	"این حرکت غیرمنتظره بود",
	"بازی رو یاد بگیر!",
	"بهترین بودن سخته!",
	"خیلی خوب مسیر بازی رو تغییر دادی!",
	"حریف من نیستی!",
	"دوباره باختی!",
	"این تاکتیکت واقعاً کارساز بود!",
	"تو از اول هم شانسی نداشتی!",
	"بردم، طبق معمول!",
	"پیشرفتت تو این بازی محسوسه!",
	"تسلیم شو، هنوز وقت داری!",
	"بازم ساده بردم!",
	"خیلی خوب کنترل کردی اوضاع رو!",
	"این فقط یه گرم کردن بود!",
	"قهرمان برگشت!",
	"اون تصمیم واقعاً درست بود!",
	"دیر رسیدی به بازی!",
	"بازی کردن با تو وقت تلف کردنه!",
	"حرکت نهایی‌ات خیلی قوی بود!",
	"با همین سرعت می‌بازی!",
	"یه کلاس درس دیگه برات بود!",
	"این راندو خیلی حرفه‌ای زدی!",
	"هنوز مونده تا به من برسی!",
	"فقط نگاه کن چطور برنده می‌شم!",
	"خیلی خوب بود!",
	"شروع نکرده باختی!",
	"پایان داستان تو همین‌جاست!",
	"عجب حرکت هوشمندانه‌ای!",
	"به همین سادگی!",
	"این فقط یک نمایش بود!",
	"عالی بازی کردی!",
	"پایان رو از الان می‌دونم!",
	"خسته نشدی از باختن؟",
	"به به!",
	"دوباره شانس داری، امتحان کن!",
	"فکر کنم هنوز نوبتت نشده!",
	"اون تاکتیک معرکه بود!",
	"بازی براتو تفریحه، برا من زندگیه!",
	"توی لیگ خودت بازی کن!",
	"چقد خوب دفاع کردی!",
	"این بود تمام توانت؟",
	"امروز روز تو نبود!",
	"بازی خفنی کردی!",
	"شاید دفعه بعد!",
	"باید تلاش بیشتری کنی!",
	"ایده فوق‌العاده‌ای بود!",
	"هنوز اول راحته!"
]

var _kori_scroll: ScrollContainer = null
var _kori_grid: GridContainer = null
var _pop_tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", HudTheme.make_popover_panel_style())
	HudTheme.apply_rail_button_style(btn_close, false)
	HudTheme.configure_bidi_label(lbl_title, false)
	btn_close.pressed.connect(close)
	btn_backdrop_close.pressed.connect(close)
	_build_grid()
	_build_kori_list()


func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var empty_style := StyleBoxEmpty.new()

	for r_id in POPULAR_REACTIONS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(74, 74)
		card.pivot_offset = Vector2(37, 37)
		card.add_theme_stylebox_override("panel", empty_style)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(74, 74)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var icon_path: String = "res://assets/icons/Reactions/%d.png" % r_id
		if ResourceLoader.exists(icon_path):
			btn.texture_normal = load(icon_path) as Texture2D

		card.add_child(btn)

		btn.mouse_entered.connect(func():
			var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2(1.14, 1.14), 0.12)
		)
		btn.mouse_exited.connect(func():
			var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, 0.1)
		)

		var chosen_id: int = r_id
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			reaction_selected.emit(chosen_id)
			close()
		)

		grid.add_child(card)


func _build_kori_list() -> void:
	if _kori_scroll and is_instance_valid(_kori_scroll):
		_kori_scroll.queue_free()
	_kori_scroll = ScrollContainer.new()
	_kori_scroll.name = "KoriScroll"
	_kori_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kori_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kori_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_kori_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_kori_scroll.visible = false

	_kori_grid = GridContainer.new()
	_kori_grid.columns = 2
	_kori_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kori_grid.add_theme_constant_override("h_separation", 8)
	_kori_grid.add_theme_constant_override("v_separation", 8)
	_kori_scroll.add_child(_kori_grid)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.14, 0.09, 0.05, 0.92)
	normal_style.set_border_width_all(1)
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.72, 0.54, 0.25, 0.78)
	normal_style.set_corner_radius_all(12)
	normal_style.content_margin_left = 10
	normal_style.content_margin_right = 10
	normal_style.content_margin_top = 4
	normal_style.content_margin_bottom = 4
	normal_style.shadow_color = Color(0, 0, 0, 0.30)
	normal_style.shadow_size = 3

	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.28, 0.18, 0.08, 0.96)
	hover_style.border_color = Color(1.0, 0.86, 0.35, 1.0)

	for idx in range(KORIS.size()):
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 46)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", normal_style)

		var lbl := Label.new()
		lbl.text = KORIS[idx]
		lbl.add_theme_font_override("font", FONT_UI)
		ResponsiveUI.apply_text(lbl, UITypography.Role.BODY_SM, {"min_px": 15, "max_px": 20, "wrap": true})
		lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		HudTheme.configure_bidi_label(lbl, false)
		card.add_child(lbl)

		var kori_id: int = idx + 101
		var drag_state: Dictionary = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					drag_state["active"] = true
					drag_state["dragging"] = false
					drag_state["start_y"] = get_viewport().get_mouse_position().y
					drag_state["start_scroll"] = _kori_scroll.scroll_vertical
					card.add_theme_stylebox_override("panel", hover_style)
				else:
					card.add_theme_stylebox_override("panel", normal_style)
					var was_dragging: bool = bool(drag_state["dragging"])
					var was_active: bool = bool(drag_state["active"])
					drag_state["active"] = false
					drag_state["dragging"] = false
					if was_active and not was_dragging:
						var dy_rel: float = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
						if dy_rel <= 14.0:
							AudioManager.sfx_tap()
							reaction_selected.emit(kori_id)
							close()
			elif event is InputEventMouseMotion and drag_state["active"]:
				var dy: float = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
				if absf(dy) > 12.0 or drag_state["dragging"]:
					drag_state["dragging"] = true
					card.add_theme_stylebox_override("panel", normal_style)
					_kori_scroll.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
		)
		_kori_grid.add_child(card)

	vbox.add_child(_kori_scroll)


func _open_downward(anchor_btn: Control) -> void:
	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
		_pop_tween = null

	var vp_size: Vector2 = get_viewport_rect().size
	var insets: Dictionary = HudTheme.get_safe_insets(get_viewport())
	var left_i: float = float(insets.get("left", 10))
	var right_i: float = float(insets.get("right", 10))
	var top_i: float = float(insets.get("top", 16))
	var bottom_i: float = float(insets.get("bottom", 14))

	var panel_w: float = clampf(vp_size.x - left_i - right_i - 8.0, 310.0, 396.0)
	var panel_h: float = clampf(vp_size.y * 0.36, 260.0, 360.0)

	var pos_x: float = vp_size.x - panel_w - right_i
	var pos_y: float = top_i + 148.0
	var pivot_x: float = panel_w - 28.0

	if is_instance_valid(anchor_btn):
		var btn_rect: Rect2 = anchor_btn.get_global_rect()
		pos_x = clampf(btn_rect.end.x - panel_w, left_i, maxf(left_i, vp_size.x - panel_w - right_i))
		pos_y = clampf(btn_rect.end.y + 8.0, top_i, maxf(top_i, vp_size.y - panel_h - bottom_i))
		pivot_x = clampf(btn_rect.get_center().x - pos_x, 20.0, panel_w - 20.0)

	panel.position = Vector2(pos_x, pos_y)
	panel.size = Vector2(panel_w, panel_h)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.pivot_offset = Vector2(pivot_x, 0.0)

	mouse_filter = Control.MOUSE_FILTER_STOP
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	dim_overlay.modulate.a = 0.0
	panel.scale = Vector2(0.90, 0.68)
	panel.modulate.a = 0.0

	_pop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(panel, "scale", Vector2.ONE, 0.18)
	_pop_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.14)
	_pop_tween.parallel().tween_property(dim_overlay, "modulate:a", 1.0, 0.14)


func open_stickers(anchor_btn: Control = null) -> void:
	if GameManager.chat_and_stickers_disabled:
		return
	if is_instance_valid(lbl_title):
		lbl_title.text = "😊 استیکرها و ایموجی‌ها"
	if is_instance_valid(sticker_scroll):
		sticker_scroll.visible = true
	if is_instance_valid(_kori_scroll):
		_kori_scroll.visible = false
	_open_downward(anchor_btn)


func open_koris(anchor_btn: Control = null) -> void:
	if GameManager.chat_and_stickers_disabled:
		return
	if is_instance_valid(lbl_title):
		lbl_title.text = "💬 کری‌خوانی سریع"
	if is_instance_valid(sticker_scroll):
		sticker_scroll.visible = false
	if is_instance_valid(_kori_scroll):
		_kori_scroll.visible = true
	_open_downward(anchor_btn)


func open() -> void:
	open_stickers(null)


func close() -> void:
	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
		_pop_tween = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not visible:
		return
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "scale", Vector2(0.94, 0.78), 0.12)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	tw.parallel().tween_property(dim_overlay, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		visible = false
		panel.scale = Vector2.ONE
		panel.modulate.a = 1.0
	)
