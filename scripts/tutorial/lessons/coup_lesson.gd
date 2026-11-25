class_name CoupTutorialLesson
extends GameTutorialLesson

## Deep, interactive Coup (کودتا) tutorial for the Library tab.
## Covers hidden cards, interactive Duke Tax (+3), Assassin (-3),
## Captain/Ambassador, Bluffing & Challenging, and Coup (-7).

const BOARD_SCENE: PackedScene = preload("res://scenes/games/coup/tutorial_coup_3d.tscn")

var _phase: String = "" # "act_1" | "act_2" | "act_3" | "react_challenge" | "react_block" | "done"


func get_game_type() -> String:
	return GameTypes.COUP


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var cp := board as TutorialCoup3D
	if not is_instance_valid(cp):
		return
	cp.tutorial_input_enabled = false
	cp.tutorial_action_chosen.connect(_on_action_chosen)
	cp.tutorial_reaction_chosen.connect(_on_reaction_chosen)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"coup_welcome",
		"آموزش کودتا (Coup)",
		"در کودتا هر بازیکن با ۲ کارت شخصیت پنهان و ۲ سکه شروع می‌کنه. بازی بر پایه «بلوف زدن» و حدس دست حریفه! آخرین بازیکنی که حداقل ۱ کارت زنده داشته باشه برنده‌ست."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("ببینیم کارت‌ها چین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# Spotlight player cards
	var st_my_cards := TutorialStep.create(
		"coup_my_cards",
		"کارت‌های پنهان و سکه‌های تو",
		"این ۲ کارت فقط برای خودت دیده می‌شن (دوک و آدمکش). ولی توی کودتا می‌تونی نقش کارتی که نداری رو هم ادعا کنی و بلوف بزنی!"
	)
	st_my_cards.with_badge("دست و سکه")
	st_my_cards.with_cta("بعدی")
	st_my_cards.with_target(func(): return _get_my_cards(), 8.0, 14.0)
	st_my_cards.with_scrim_alpha(0.72)
	st_my_cards.with_placement("top")
	s.append(st_my_cards)

	# Interactive 1: Duke Tax (+3 -> 7 coins!)
	var st_act1 := TutorialStep.create(
		"coup_act_1",
		"۱. دوک (👑 Duke) و حرکت‌های پایه",
		"• درآمد (+۱) و کمک خارجی (+۲) برای همه هستن.\n• 👑 دوک: +۳ سکه مالیات می‌گیره و جلوی کمک خارجی رو می‌بنده!\nدکمه «مالیات (+۳)» رو بزن تا سکه‌هات به ۷ برسه!"
	)
	st_act1.with_badge("تمرین ۱ از ۵")
	st_act1.with_hint("دکمه مالیات (+۳) یا درآمد رو بزن")
	st_act1.with_target(func(): return _get_action_btn(["مالیات"]), 6.0, 14.0)
	st_act1.with_scrim_alpha(0.65)
	st_act1.with_interactive(true, false)
	st_act1.with_placement("top")
	st_act1.with_hooks(func(): _enter_phase("act_1"))
	s.append(st_act1)

	# Interactive 2: Assassin & Contessa
	var st_act2 := TutorialStep.create(
		"coup_act_2",
		"۲. آدمکش (🗡️) و کنتس (🛡️)",
		"• 🗡️ آدمکش: با ۳ سکه ۱ کارت حریف رو ترور می‌کنه.\n• 🛡️ کنتس: تنها کارتیه که می‌تونه جلوی ترور آدمکش رو بگیره!\nدکمه «ترور (-۳)» (یا هر حرکت دلخواه) رو امتحان کن."
	)
	st_act2.with_badge("تمرین ۲ از ۵")
	st_act2.with_hint("یک دکمه نقش از نوار پایین لمس کن")
	st_act2.with_target(func(): return _get_action_btn(["ترور"]), 6.0, 14.0)
	st_act2.with_scrim_alpha(0.65)
	st_act2.with_interactive(true, false)
	st_act2.with_placement("top")
	st_act2.with_hooks(func(): _enter_phase("act_2"))
	s.append(st_act2)

	# Interactive 3: Captain & Ambassador
	var st_act3 := TutorialStep.create(
		"coup_act_3",
		"۳. کاپیتان (⚓) و سفیر (🎭)",
		"• ⚓ کاپیتان: ۲ سکه از حریف می‌دزده و جلوی دزدی رو می‌گیره.\n• 🎭 سفیر: ۲ کارت از دسته می‌بینه و با دستش عوض می‌کنه + جلوی دزدی رو می‌گیره.\nیکی از این حرکت‌ها رو بزن (حتی اگه کارتاش رو نداری = بلوف!)."
	)
	st_act3.with_badge("تمرین ۳ از ۵")
	st_act3.with_hint("سرقت یا تعویض سفیر رو امتحان کن")
	st_act3.with_target(func(): return _get_action_btn(["سرقت"]), 6.0, 14.0)
	st_act3.with_scrim_alpha(0.65)
	st_act3.with_interactive(true, false)
	st_act3.with_placement("top")
	st_act3.with_hooks(func(): _enter_phase("act_3"))
	s.append(st_act3)

	# Interactive 4: Reaction to Enemy Bluff (Challenge!)
	var st_react_chal := TutorialStep.create(
		"coup_react_challenge",
		"۴. واکنش به حرکت حریف: چالش (⚡ بلوف!)",
		"الان نوبت حریفه و ادعا کرده «دوک» داره (+۳ سکه مالیات)! اگه شک داری بلوف می‌زنه، دکمه «⚡ بلوف! (چالش)» رو بزن (یا «قبول» رو بزن)."
	)
	st_react_chal.with_badge("تمرین ۴ از ۵")
	st_react_chal.with_hint("دکمه «⚡ بلوف! (چالش)» رو بزن")
	st_react_chal.with_target(func(): return _get_action_btn(["چالش", "بلوف"]), 6.0, 14.0)
	st_react_chal.with_scrim_alpha(0.65)
	st_react_chal.with_interactive(true, false)
	st_react_chal.with_placement("top")
	st_react_chal.with_hooks(func(): _enter_phase("react_challenge"))
	s.append(st_react_chal)

	# Interactive 5: Reaction to Enemy Attack (Block!)
	var st_react_blk := TutorialStep.create(
		"coup_react_block",
		"۵. دفاع در برابر حمله حریف (🛡️ کنتس)",
		"حریف می‌خواد با آدمکش بهت حمله کنه! حتی اگه کنتس نداری می‌تونی با بلوف جلوی ترور رو بگیری. دکمه «🛡️ دفاع کنتس» رو بزن!"
	)
	st_react_blk.with_badge("تمرین ۵ از ۵")
	st_react_blk.with_hint("دکمه «🛡️ دفاع کنتس» رو لمس کن")
	st_react_blk.with_target(func(): return _get_action_btn(["دفاع"]), 6.0, 14.0)
	st_react_blk.with_scrim_alpha(0.65)
	st_react_blk.with_interactive(true, false)
	st_react_blk.with_placement("top")
	st_react_blk.with_hooks(func(): _enter_phase("react_block"))
	s.append(st_react_blk)

	# Bluff, Challenge, Coup & Roles button
	var st_done := TutorialStep.create(
		"coup_done",
		"چالش، کودتا و راهنمای نقش‌ها",
		"• اگر حریف بلوف بزنه می‌تونی «چالش» بدی (دروغگو ۱ کارت می‌سوزونه؛ اگه راست گفته باشه چالش‌دهنده می‌سوزونه!).\n• با ۷ سکه «کودتا» بزن (غیرقابل دفاع) و در ۱۰ سکه اجباریه.\nدکمه «نقش‌ها» این بالا همیشه کمکت می‌کنه!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_target(func(): return _get_roles_btn(), 8.0, 14.0)
	st_done.with_scrim_alpha(0.72)
	st_done.with_placement("bottom")
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var cp := _board as TutorialCoup3D
	if is_instance_valid(cp):
		if p == "react_challenge":
			cp.trigger_enemy_bluff_duke()
		elif p == "react_block":
			cp.trigger_enemy_assassinate()
		cp.tutorial_input_enabled = true


func _on_reaction_chosen(cmd: String, _detail: String) -> void:
	if not is_instance_valid(_coordinator):
		return
	var cp := _board as TutorialCoup3D
	if _phase in ["react_challenge", "react_block"]:
		_phase = "wait"
		if is_instance_valid(cp):
			cp.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		var msg: String = "چالش زدی! اگه حریف بلوف زده باشه ۱ کارت می‌سوزونه!" if cmd == Commands.Coup_Challenge else ("با دفاع کنتس جلوی ترور رو گرفتی!" if cmd == Commands.Coup_Block else "حرکت حریف رو قبول کردی!")
		_coordinator.show_hud_toast(msg)
		_coordinator.get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_action_chosen(act: String) -> void:
	if not is_instance_valid(_coordinator):
		return
	var cp := _board as TutorialCoup3D
	if _phase in ["act_1", "act_2", "act_3"]:
		_phase = "wait"
		if is_instance_valid(cp):
			cp.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("عالی! حرکت «%s» انجام شد!" % act)
		_coordinator.get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_action_btn(keywords: Array[String]) -> Control:
	var cp := _board as TutorialCoup3D
	if is_instance_valid(cp):
		return cp.get_action_button_matching(keywords)
	return null


func _get_actions_dock() -> Control:
	var cp := _board as TutorialCoup3D
	if is_instance_valid(cp):
		return cp.get_actions_dock_control()
	return null


func _get_my_cards() -> Control:
	var cp := _board as TutorialCoup3D
	if is_instance_valid(cp):
		return cp.get_my_cards_control()
	return null


func _get_roles_btn() -> Control:
	var cp := _board as TutorialCoup3D
	if is_instance_valid(cp):
		return cp.get_roles_button()
	return null
