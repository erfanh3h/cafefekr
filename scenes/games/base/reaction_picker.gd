extends Control

# Reaction / Emote & Kori (Taunt) Picker
# Supports both Sticker Reactions (IDs 1..44) and Persian Kori Taunts (IDs 101..178)

signal reaction_selected(reaction_id: int)

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var vbox: VBoxContainer = $CenterContainer/Panel/Margin/VBox
@onready var lbl_title: Label = $CenterContainer/Panel/Margin/VBox/LblTitle
@onready var grid: GridContainer = $CenterContainer/Panel/Margin/VBox/Grid
@onready var btn_close: Button = $CenterContainer/Panel/Margin/VBox/BtnClose

const FONT_FA = preload("res://assets/fonts/hekayat.ttf")

# Popular, expressive reaction IDs from assets/icons/Reactions (16 items for clean 4x4 layout)
const POPULAR_REACTIONS: Array[int] = [
	1, 2, 3, 4, 6, 7, 8, 10, 11, 14, 15, 18, 20, 22, 27, 36
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

func _ready() -> void:
	visible = false
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_GREY)
	btn_close.pressed.connect(close)
	_build_grid()
	_build_kori_list()

func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
		
	for r_id in POPULAR_REACTIONS:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 110)
		card.pivot_offset = Vector2(55, 55)
		
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.13, 0.08, 0.05, 0.82)
		normal_style.set_border_width_all(2)
		normal_style.border_color = Color(0.48, 0.36, 0.22, 0.85)
		normal_style.set_corner_radius_all(16)
		normal_style.shadow_color = Color(0, 0, 0, 0.4)
		normal_style.shadow_size = 4
		card.add_theme_stylebox_override("panel", normal_style)
		
		var hover_style = normal_style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
		hover_style.bg_color = Color(0.25, 0.16, 0.08, 0.95)
		hover_style.shadow_size = 8
		
		var btn = TextureButton.new()
		btn.custom_minimum_size = Vector2(96, 96)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		var icon_path = "res://assets/icons/Reactions/%d.png" % r_id
		if ResourceLoader.exists(icon_path):
			btn.texture_normal = load(icon_path)
			
		card.add_child(btn)
		
		btn.mouse_entered.connect(func():
			card.add_theme_stylebox_override("panel", hover_style)
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2(1.12, 1.12), 0.1)
		)
		btn.mouse_exited.connect(func():
			card.add_theme_stylebox_override("panel", normal_style)
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, 0.1)
		)
		
		var chosen_id = r_id
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
	_kori_scroll.custom_minimum_size = Vector2(720, 500)
	_kori_scroll.visible = false

	_kori_grid = GridContainer.new()
	_kori_grid.columns = 2
	_kori_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kori_grid.add_theme_constant_override("h_separation", 14)
	_kori_grid.add_theme_constant_override("v_separation", 12)
	_kori_scroll.add_child(_kori_grid)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.14, 0.09, 0.05, 0.90)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.72, 0.54, 0.25, 0.85)
	normal_style.set_corner_radius_all(14)
	normal_style.content_margin_left = 14
	normal_style.content_margin_right = 14
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	normal_style.shadow_color = Color(0, 0, 0, 0.35)
	normal_style.shadow_size = 4

	var hover_style = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.28, 0.18, 0.08, 0.96)
	hover_style.border_color = Color(1.0, 0.86, 0.35, 1.0)

	for idx in range(KORIS.size()):
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(335, 82)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", normal_style)

		var lbl = Label.new()
		lbl.text = KORIS[idx]
		lbl.add_theme_font_override("font", FONT_FA)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lbl)

		var kori_id = idx + 101
		var touch_state = {"down": false, "pos": Vector2.ZERO, "dragged": false, "last_ms": 0}
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenDrag:
				touch_state["dragged"] = true
				_kori_scroll.scroll_vertical -= int(event.relative.y)
			elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				if event.position.distance_to(touch_state["pos"]) > 14.0:
					touch_state["dragged"] = true
					_kori_scroll.scroll_vertical -= int(event.relative.y)
			elif event is InputEventScreenTouch:
				if event.pressed:
					touch_state["down"] = true
					touch_state["pos"] = event.position
					touch_state["dragged"] = false
					card.add_theme_stylebox_override("panel", hover_style)
				else:
					card.add_theme_stylebox_override("panel", normal_style)
					if touch_state["down"] and not touch_state["dragged"] and event.position.distance_to(touch_state["pos"]) <= 18.0:
						var now_ms = Time.get_ticks_msec()
						if now_ms - int(touch_state["last_ms"]) > 250:
							touch_state["last_ms"] = now_ms
							AudioManager.sfx_tap()
							reaction_selected.emit(kori_id)
							close()
					touch_state["down"] = false
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					touch_state["down"] = true
					touch_state["pos"] = event.position
					touch_state["dragged"] = false
					card.add_theme_stylebox_override("panel", hover_style)
				else:
					card.add_theme_stylebox_override("panel", normal_style)
					if touch_state["down"] and not touch_state["dragged"] and event.position.distance_to(touch_state["pos"]) <= 18.0:
						var now_ms = Time.get_ticks_msec()
						if now_ms - int(touch_state["last_ms"]) > 250:
							touch_state["last_ms"] = now_ms
							AudioManager.sfx_tap()
							reaction_selected.emit(kori_id)
							close()
					touch_state["down"] = false
		)
		_kori_grid.add_child(card)

	vbox.add_child(_kori_scroll)
	vbox.move_child(_kori_scroll, grid.get_index())

func open_stickers() -> void:
	if is_instance_valid(lbl_title):
		lbl_title.text = "استیکرها و ایموجی‌ها"
	if is_instance_valid(grid):
		grid.visible = true
	if is_instance_valid(_kori_scroll):
		_kori_scroll.visible = false
	ActionVFXManager.animate_dialog_open(panel, self, true)

func open_koris() -> void:
	if is_instance_valid(lbl_title):
		lbl_title.text = "💬 کری‌خوانی"
	if is_instance_valid(grid):
		grid.visible = false
	if is_instance_valid(_kori_scroll):
		_kori_scroll.visible = true
	ActionVFXManager.animate_dialog_open(panel, self, true)

func open() -> void:
	open_stickers()

func close() -> void:
	ActionVFXManager.animate_dialog_close(panel, self)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
