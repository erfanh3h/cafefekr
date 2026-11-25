class_name UNOTutorialLesson
extends GameTutorialLesson

## Interactive UNO (اونو) tutorial for the Library tab.
## Lets the player play EACH special card one by one (Skip, Reverse, +2, Wild, Wild +4),
## spotlights the Wild Color Picker modal when it opens, and finishes with the UNO! button.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/uno/tutorial_uno_3d.tscn")

var _phase: String = "" # "skip" | "reverse" | "draw2" | "wild" | "wild4" | "uno_btn" | "done"


func get_game_type() -> String:
	return GameTypes.UNO


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var uno := board as TutorialUNO3D
	if not is_instance_valid(uno):
		return
	uno.tutorial_input_enabled = false
	uno.tutorial_card_played.connect(_on_card_played)
	uno.tutorial_uno_called.connect(_on_uno_called)
	uno.tutorial_wild_picker_opened.connect(_on_wild_picker_opened)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"uno_welcome",
		"آموزش اونو (UNO)",
		"هدف اونو اینه که زودتر از بقیه کارت‌های دستت رو خالی کنی! هر کارتی بازی می‌کنی باید هم‌رنگ یا هم‌شماره/هم‌نمادِ کارت وسط میز باشه."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("بزن کارت‌ها رو امتحان کنیم!")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Skip
	var st_skip := TutorialStep.create(
		"uno_skip",
		"۱. کارت توقف (🚫 Skip)",
		"این کارت نوبت بازیکن بعدی رو می‌سوزونه! روی کارت قرمز «🚫 توقف» توی دستت بزن تا بازی بشه."
	)
	st_skip.with_badge("کارت ویژه ۱ از ۵")
	st_skip.with_hint("روی کارت قرمز توقف (🚫) لمس کن")
	st_skip.with_target(func(): return _get_hand_ctrl(), 8.0, 14.0)
	st_skip.with_scrim_alpha(0.70)
	st_skip.with_interactive(true, false)
	st_skip.with_placement("top")
	st_skip.with_hooks(func(): _enter_phase("skip"))
	s.append(st_skip)

	# 2. Reverse
	var st_rev := TutorialStep.create(
		"uno_reverse",
		"۲. کارت تغییر جهت (🔄 Reverse)",
		"جهت چرخش بازی رو برعکس می‌کنه (در بازی ۲ نفره مثل توقف نوبت حریف رو رد می‌کنه!). روی کارت «🔄 تغییر جهت» بزن."
	)
	st_rev.with_badge("کارت ویژه ۲ از ۵")
	st_rev.with_hint("روی کارت تغییر جهت (🔄) لمس کن")
	st_rev.with_target(func(): return _get_hand_ctrl(), 8.0, 14.0)
	st_rev.with_scrim_alpha(0.70)
	st_rev.with_interactive(true, false)
	st_rev.with_placement("top")
	st_rev.with_hooks(func(): _enter_phase("reverse"))
	s.append(st_rev)

	# 3. Draw +2
	var st_d2 := TutorialStep.create(
		"uno_draw2",
		"۳. کارت +۲ (Draw Two)",
		"نفر بعدی مجبوره ۲ کارت از دسته بکشه و نوبتش هم می‌سوزه! روی کارت «+۲» بزن."
	)
	st_d2.with_badge("کارت ویژه ۳ از ۵")
	st_d2.with_hint("روی کارت +۲ لمس کن")
	st_d2.with_target(func(): return _get_hand_ctrl(), 8.0, 14.0)
	st_d2.with_scrim_alpha(0.70)
	st_d2.with_interactive(true, false)
	st_d2.with_placement("top")
	st_d2.with_hooks(func(): _enter_phase("draw2"))
	s.append(st_d2)

	# 4. Wild
	var st_wild := TutorialStep.create(
		"uno_wild",
		"۴. کارت تغییر رنگ (🌈 Wild)",
		"این کارت رو می‌تونی روی هر رنگی بذاری و رنگ بازی رو عوض کنی! روی کارت تغییر رنگ (🌈) بزن و یک رنگ انتخاب کن."
	)
	st_wild.with_badge("کارت ویژه ۴ از ۵")
	st_wild.with_hint("روی کارت تغییر رنگ (🌈) لمس کن")
	st_wild.with_target(func(): return _get_hand_ctrl(), 8.0, 14.0)
	st_wild.with_scrim_alpha(0.70)
	st_wild.with_interactive(true, false)
	st_wild.with_placement("top")
	st_wild.with_hooks(func(): _enter_phase("wild"))
	s.append(st_wild)

	# 5. Wild +4
	var st_w4 := TutorialStep.create(
		"uno_wild4",
		"۵. کارت جوکر +۴ (Wild Draw 4)",
		"قوی‌ترین کارت اونو! هم رنگ رو عوض می‌کنه هم نفر بعدی ۴ کارت می‌کشه و نوبتش می‌سوزه. روی کارت «+۴» بزن!"
	)
	st_w4.with_badge("کارت ویژه ۵ از ۵")
	st_w4.with_hint("روی کارت +۴ لمس کن")
	st_w4.with_target(func(): return _get_hand_ctrl(), 8.0, 14.0)
	st_w4.with_scrim_alpha(0.70)
	st_w4.with_interactive(true, false)
	st_w4.with_placement("top")
	st_w4.with_hooks(func(): _enter_phase("wild_draw4"))
	s.append(st_w4)

	# 6. UNO! Bell on the 3D Board
	var st_uno := TutorialStep.create(
		"uno_call",
		"فقط ۱ کارت موند — زنگ UNO! روی میز رو بزن",
		"هر وقت فقط ۱ کارت توی دستت باقی موند، سریع روی زنگ طلایی «UNO!» روی میز (سمت راست) بزن تا جریمه نشی!"
	)
	st_uno.with_badge("قانون طلایی اونو")
	st_uno.with_hint("روی زنگ «🔥 UNO!» روی میز لمس کن")
	st_uno.with_target(func(): return _get_uno_bell_target(), 10.0, 18.0)
	st_uno.with_scrim_alpha(0.70)
	st_uno.with_interactive(true, false)
	st_uno.with_placement("top")
	st_uno.with_hooks(func(): _enter_phase("uno_btn"))
	s.append(st_uno)

	# 7. Finish Dialog
	var st_done := TutorialStep.create(
		"uno_done",
		"پایان آموزش اونو",
		"آفرین! حالا همه کارت‌های ویژه (توقف، تغییر جهت، +۲، تغییر رنگ، جوکر +۴) و دکمه UNO! رو بلدی و آماده‌ای برای بازی واقعی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var uno := _board as TutorialUNO3D
	if is_instance_valid(uno):
		uno.tutorial_input_enabled = true


func _on_wild_picker_opened() -> void:
	if not is_instance_valid(_coordinator):
		return
	var step_idx: int = 4 if _phase == "wild" else 5
	var st_pick := TutorialStep.create(
		"uno_pick_color",
		"انتخاب رنگ جدید!",
		"حالا یکی از ۴ رنگ (قرمز، آبی، سبز یا زرد) رو انتخاب کن تا رنگ بازی عوض بشه!"
	)
	st_pick.with_badge("انتخاب رنگ")
	st_pick.with_hint("روی یکی از ۴ رنگ لمس کن")
	st_pick.with_target(func(): return _get_wild_modal_ctrl(), 8.0, 18.0)
	st_pick.with_scrim_alpha(0.60)
	st_pick.with_interactive(true, false)
	st_pick.with_placement("bottom")
	_coordinator.show_custom_step(st_pick, step_idx, 8)


func _on_card_played(card: Dictionary) -> void:
	if not is_instance_valid(_coordinator):
		return
	var val: String = str(card.get("value", ""))
	if _phase in ["skip", "reverse", "draw2", "wild", "wild_draw4"]:
		_coordinator.show_hud_toast("عالی! کارت «%s» بازی شد!" % val)
		_coordinator.advance_lesson_step()


func _on_uno_called() -> void:
	if is_instance_valid(_coordinator) and _phase == "uno_btn":
		_coordinator.show_hud_toast("UNO! آفرین!")
		_coordinator.advance_lesson_step()


func _get_hand_ctrl() -> Control:
	var uno := _board as TutorialUNO3D
	if is_instance_valid(uno):
		return uno.get_hand_container()
	return null


func _get_wild_modal_ctrl() -> Control:
	var uno := _board as TutorialUNO3D
	if is_instance_valid(uno):
		return uno.get_wild_modal_control()
	return null


func _get_uno_btn() -> Control:
	var uno := _board as TutorialUNO3D
	if is_instance_valid(uno):
		return uno.get_uno_button()
	return null


func _get_uno_bell_target() -> Variant:
	var uno := _board as TutorialUNO3D
	if is_instance_valid(uno):
		var r: Rect2 = uno.get_uno_bell_rect()
		if r.size.x > 0.0:
			return r
		return uno.get_uno_button()
	return null
