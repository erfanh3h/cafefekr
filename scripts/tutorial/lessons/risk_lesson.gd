class_name RiskTutorialLesson
extends GameTutorialLesson

## Senior-player interactive Risk Strike (ریسک استرایک) tutorial for the Library tab.
## Covers:
## 1. Drawing cards (3 real options)
## 2. All 8 Tactic/Strategy cards & using one interactively
## 3. Complete Attack flow: Declare Attack -> AttackerArmy (Army shields / Canon +1 / max 3 dice) -> Attack (Reroll / Stop / Conquer)
## 4. Complete Defense flow: DefenderArmy (max 2 dice, ties to defender, Army shields / Canon +1) -> Mid-battle Cancel Attack
## 5. Pass Turn (+1 free Strategy bonus) & Domination Coin victory

const BOARD_SCENE: PackedScene = preload("res://scenes/games/risk/tutorial_risk_3d.tscn")

var _phase: String = "" # "draw" | "tactics_view" | "tactic" | "attack_declare" | "atk_commit" | "atk_reroll" | "def_commit" | "def_react" | "pass" | "done"


func get_game_type() -> String:
	return GameTypes.RISK


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var rsk := board as TutorialRisk3D
	if not is_instance_valid(rsk):
		return
	rsk.tutorial_input_enabled = false
	rsk.tutorial_cards_drawn.connect(_on_cards_drawn)
	rsk.tutorial_strategy_used.connect(_on_strategy_used)
	rsk.tutorial_attack_declared.connect(_on_attack_declared)
	rsk.tutorial_attacker_committed.connect(_on_attacker_committed)
	rsk.tutorial_battle_resolved.connect(_on_battle_resolved)
	rsk.tutorial_defender_committed.connect(_on_defender_committed)
	rsk.tutorial_defense_stopped.connect(_on_defense_stopped)
	rsk.tutorial_turn_passed.connect(_on_turn_passed)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"risk_welcome",
		"آموزش حرفه‌ای ریسک استرایک (Risk Strike)",
		"هدف بازی گرفتن ۲ «سکه تسلط» (یا حذف رقبا) است! با جمع کردن کارت‌های هم‌قاره (آسیا ۸، اروپا ۵، آفریقا ۴، استرالیا/آمریکای جنوبی ۳) سکه اون قاره رو تصاحب می‌کنی."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع نوبت")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Interactive: Draw cards from 3 options
	var st_draw := TutorialStep.create(
		"risk_draw",
		"۱. کشیدن کارت در شروع نوبت",
		"اول هر نوبت از نوار پایین کارت بکش: «۲ کارت قاره»، «۲ استراتژی» یا «۱ قاره + ۱ استراتژی». یکی رو انتخاب کن!"
	)
	st_draw.with_badge("تمرین ۱ از ۷")
	st_draw.with_hint("یکی از ۳ دکمه کشیدن کارت رو بزن")
	st_draw.with_target(func(): return _get_action_row_ctrl(), 8.0, 14.0)
	st_draw.with_scrim_alpha(0.68)
	st_draw.with_interactive(true, false)
	st_draw.with_placement("top")
	st_draw.with_hooks(func(): _enter_phase("draw"))
	s.append(st_draw)

	# 2. Interactive Attack Part 1: Declare Attack (immediately after Draw!)
	var st_atk := TutorialStep.create(
		"risk_attack",
		"۲. شروع حمله: انتخاب مبدأ و هدف روی نقشه",
		"روی یکی از قاره‌های خودت (مثلاً آسیا روی نقشه یا کارت دستت) بزن، بعد روی قاره همسایه حریف (اروپا / آمریکای شمالی) روی نقشه بزن و حمله رو شروع کن!"
	)
	st_atk.with_badge("تمرین ۲ از ۷ — حمله (۱)")
	st_atk.with_hint("قاره مبدأ و سپس قاره هدف حریف رو روی نقشه لمس کن")
	st_atk.with_target(func(): return _get_board_and_dock_rect(), 8.0, 14.0)
	st_atk.with_scrim_alpha(0.55)
	st_atk.with_interactive(true, false)
	st_atk.with_placement("top")
	st_atk.with_hooks(func(): _enter_phase("attack_declare"))
	s.append(st_atk)

	# 6. Interactive Attack Part 2: Commit Army & Canon (AttackerArmy)
	var st_atk_commit := TutorialStep.create(
		"risk_atk_commit",
		"۳. تقویت تهاجم: ارتش کمکی (⚔️) و توپخانه (🎯)",
		"در حمله حداکثر ۳ تاس می‌ریزی. ترفند حرفه‌ای: کارت «ارتش تهاجمی» هم تاس رو به ۳ می‌رسونه هم مثل سپر اول از دست می‌ره تا کارت قاره‌ات نسوزه! «توپخانه (+۱)» هم +۱ به بالاترین تاست می‌ده. آماده شدی «شروع نبرد» رو بزن!"
	)
	st_atk_commit.with_badge("تمرین ۳ از ۷ — حمله (۲)")
	st_atk_commit.with_hint("ارتش/توپخانه رو تنظیم کن و «شروع نبرد» رو بزن")
	st_atk_commit.with_target(func(): return _get_dock_ctrl(), 8.0, 14.0)
	st_atk_commit.with_scrim_alpha(0.60)
	st_atk_commit.with_interactive(true, false)
	st_atk_commit.with_placement("top")
	st_atk_commit.with_hooks(func(): _enter_phase("atk_commit"))
	s.append(st_atk_commit)

	# 7. Interactive Attack Part 3: Multi-round Attack Reroll / Stop (Attack)
	var st_atk_reroll := TutorialStep.create(
		"risk_atk_reroll",
		"۴. موج دوم نبرد: پاکسازی قاره و ریسک تاس!",
		"تاس دور اول ریخته شد و ۱ کارت قاره از دست حریف پرید! یادت باشه: هر تاس برنده ۱ کارت قاره از حریف می‌زنه (و با پاکسازی کامل، قاره‌اش رو تصاحب می‌کنی)، ولی اگر تاس رو ببازی و سپر «ارتش» نداشته باشی کارت قاره خودت می‌سوزه! «پرتاب مجدد» رو بزن تا کار رو تموم کنی."
	)
	st_atk_reroll.with_badge("تمرین ۴ از ۷ — حمله (۳)")
	st_atk_reroll.with_hint("«پرتاب مجدد» (یا توقف حمله) رو بزن")
	st_atk_reroll.with_target(func(): return _get_dock_ctrl(), 8.0, 14.0)
	st_atk_reroll.with_scrim_alpha(0.60)
	st_atk_reroll.with_interactive(true, false)
	st_atk_reroll.with_placement("top")
	st_atk_reroll.with_hooks(func(): _enter_phase("atk_reroll"))
	s.append(st_atk_reroll)

	# 8. Interactive Defense Part 1: DefenderArmy
	var st_def_commit := TutorialStep.create(
		"risk_def_commit",
		"۵. نوبت دفاع تو! (سقف ۲ تاس + تساوی به نفع مدافع)",
		"حالا حریف به آسیای تو حمله کرده! حواست باشه اگر تاس‌ها رو ببازی، کارت قاره آسیا رو از دست می‌دی (مگر «ارتش دفاعی» سپر بشه!). خوشبختانه در دفاع سقف ۲ تاس داری و در عدد مساوی همیشه «مدافع» برنده‌ست و مهاجم کارت قاره‌اش رو می‌بازه! دکمه «دفاع» رو بزن."
	)
	st_def_commit.with_badge("تمرین ۵ از ۷ — دفاع (۱)")
	st_def_commit.with_hint("ارتش/توپخانه دفاعی بگذار و «دفاع» رو بزن")
	st_def_commit.with_target(func(): return _get_dock_ctrl(), 8.0, 14.0)
	st_def_commit.with_scrim_alpha(0.60)
	st_def_commit.with_interactive(true, false)
	st_def_commit.with_placement("top")
	st_def_commit.with_hooks(func(): _enter_phase("def_commit"))
	s.append(st_def_commit)

	# 9. Interactive Defense Part 2: Mid-battle Cancel Attack!
	var st_def_react := TutorialStep.create(
		"risk_def_react",
		"۶. دفاع حرفه‌ای وسط نبرد: کارت لغو تهاجم (🛡️)",
		"موج اول رو با تساوی بُردی و حریف هنوز می‌خواد حمله رو ادامه بده! به‌عنوان مدافع می‌تونی همین وسط نبرد کارت «لغو حمله» رو بزنی تا حمله فوری و بدون تلفات متوقف بشه. دکمه «لغو حمله» رو بزن!"
	)
	st_def_react.with_badge("تمرین ۶ از ۷ — دفاع (۲)")
	st_def_react.with_hint("دکمه «لغو حمله» (یا کارت لغو) رو بزن")
	st_def_react.with_target(func(): return _get_dock_ctrl(), 8.0, 14.0)
	st_def_react.with_scrim_alpha(0.60)
	st_def_react.with_interactive(true, false)
	st_def_react.with_placement("top")
	st_def_react.with_hooks(func(): _enter_phase("def_react"))
	s.append(st_def_react)

	# 10. Interactive Pass Turn
	var st_pass := TutorialStep.create(
		"risk_pass",
		"۷. پایان نوبت و جایزه استراتژی +۱",
		"نکته حرفه‌ای: اگر توی نوبتت حمله نکنی و «پایان نوبت» رو بزنی، ۱ کارت تاکتیک رایگان جایزه می‌گیری! دکمه «پایان نوبت (+۱ کارت)» رو امتحان کن."
	)
	st_pass.with_badge("تمرین ۷ از ۷")
	st_pass.with_hint("دکمه «پایان نوبت» رو لمس کن")
	st_pass.with_target(func(): return _get_action_row_ctrl(), 8.0, 14.0)
	st_pass.with_scrim_alpha(0.62)
	st_pass.with_interactive(true, false)
	st_pass.with_placement("top")
	st_pass.with_hooks(func(): _enter_phase("pass"))
	s.append(st_pass)

	# 11. Finish Dialog
	var st_done := TutorialStep.create(
		"risk_done",
		"پایان آموزش ریسک استرایک",
		"آفرین فرمانده! حالا کشیدن کارت، ۸ کارت تاکتیک، حمله چندمرحله‌ای با ارتش کمکی و توپخانه، و دفاع حرفه‌ای با قانون تساوی و لغو حمله رو کاملاً بلدی. اولین نفر با ۲ سکه تسلط برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var rsk := _board as TutorialRisk3D
	if not is_instance_valid(rsk):
		return
	rsk.tutorial_input_enabled = (p != "tactics_view" and p != "done")
	if p in ["tactics_view", "tactic"]:
		rsk.ensure_tactic_cards_visible()
	elif p == "attack_declare":
		rsk.prepare_attack_scenario()
	elif p == "def_commit":
		rsk.start_enemy_attack_scenario()
	elif p == "pass":
		rsk.prepare_pass_turn_state()


func _advance_after_delay(delay_sec: float = 0.9) -> void:
	var rsk := _board as TutorialRisk3D
	if is_instance_valid(rsk):
		rsk.tutorial_input_enabled = false
	if not is_instance_valid(_coordinator):
		return
	_coordinator.hide_overlay_temporarily()
	_coordinator.get_tree().create_timer(delay_sec).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _on_cards_drawn(_dt: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "draw":
		_phase = "wait"
		_coordinator.show_hud_toast("کارت‌ها به دستت اضافه شدن!")
		_coordinator.advance_lesson_step()


func _on_strategy_used(strat_name: String) -> void:
	if is_instance_valid(_coordinator) and _phase == "tactic":
		_phase = "wait"
		_coordinator.show_hud_toast("آفرین! کارت «%s» اجرا شد!" % strat_name)
		_advance_after_delay(0.9)


func _on_attack_declared() -> void:
	if is_instance_valid(_coordinator) and _phase == "attack_declare":
		_phase = "wait"
		_coordinator.show_hud_toast("حمله اعلام شد! حالا ارتش کمکی و توپخانه رو آماده کن.")
		_coordinator.advance_lesson_step()


func _on_attacker_committed(_count: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "atk_commit":
		_phase = "wait"
		_coordinator.show_hud_toast("تاس موج اول ریخته شد! حریف ۱ نیرو از دست داد.")
		_advance_after_delay(1.4)


func _on_battle_resolved(conquered: bool) -> void:
	if is_instance_valid(_coordinator) and _phase == "atk_reroll":
		_phase = "wait"
		_coordinator.show_hud_toast("🏆 قاره حریف پاکسازی شد و کارت قاره‌اش رو گرفتی!" if conquered else "⏹️ حمله را با احتیاط متوقف کردی!")
		_advance_after_delay(1.5)


func _on_defender_committed(_count: int, canceled: bool) -> void:
	if not is_instance_valid(_coordinator) or _phase != "def_commit":
		return
	_phase = "wait"
	if canceled:
		# Player used Cancel immediately in DefenderArmy -> skip mid-battle cancel step cleanly
		_coordinator.show_hud_toast("🛡️ حمله دشمن را همان ابتدا با «لغو تهاجم» خنثی کردی!")
		var rsk := _board as TutorialRisk3D
		if is_instance_valid(rsk):
			rsk.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
				_coordinator.advance_lesson_step()
		)
	else:
		_coordinator.show_hud_toast("🛡️ با تساوی و دفاع قدرتمند موج اول را دفع کردی!")
		_advance_after_delay(1.4)


func _on_defense_stopped() -> void:
	if is_instance_valid(_coordinator) and _phase == "def_react":
		_phase = "wait"
		_coordinator.show_hud_toast("🛡️ عالی! حمله دشمن وسط نبرد لغو شد!")
		_advance_after_delay(1.1)


func _on_turn_passed() -> void:
	if is_instance_valid(_coordinator) and _phase == "pass":
		_phase = "wait"
		_coordinator.show_hud_toast("⏭️ نوبت پایان یافت (+۱ کارت استراتژی جایزه)!")
		_advance_after_delay(0.9)


func _get_hand_ctrl() -> Control:
	var rsk := _board as TutorialRisk3D
	if is_instance_valid(rsk):
		return rsk.get_hand_strip_control()
	return null


func _get_action_row_ctrl() -> Control:
	var rsk := _board as TutorialRisk3D
	if is_instance_valid(rsk):
		return rsk.get_action_row_control()
	return null


func _get_dock_ctrl() -> Control:
	var rsk := _board as TutorialRisk3D
	if is_instance_valid(rsk):
		return rsk.get_hud_dock_control()
	return null


func _get_board_and_dock_rect() -> Variant:
	var rsk := _board as TutorialRisk3D
	if not is_instance_valid(rsk):
		return null
	var dock: Control = rsk.get_hud_dock_control()
	var board_r: Rect2 = rsk.get_board_screen_rect()
	if is_instance_valid(dock):
		var dock_r: Rect2 = dock.get_global_rect()
		if board_r.size.x > 0.0 and dock_r.size.x > 0.0:
			return board_r.merge(dock_r)
		return dock
	return board_r
