class_name BattleShipTutorialLesson
extends GameTutorialLesson

## Interactive BattleShip (نبرد کشتی) tutorial for the Library tab.
## Covers:
##   1. Phase 1: Moving/rotating ships on defense board -> Submit Fleet
##   2. Phase 2: Shooting Enemy Radar -> Water Miss vs Direct Hit (Bonus Turn!)
##   3. Bottom Fleet Status Strip (ناوگان باقیمانده) & View Toggle buttons

const BOARD_SCENE: PackedScene = preload("res://scenes/games/battleship/tutorial_battleship_3d.tscn")

var _phase: String = "" # "move_ship" | "submit" | "fire_miss" | "fire_hit" | "done"


func get_game_type() -> String:
	return GameTypes.BATTLESHIP


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var bs := board as TutorialBattleShip3D
	if not is_instance_valid(bs):
		return
	bs.tutorial_input_enabled = false
	bs.tutorial_ship_moved.connect(_on_ship_moved)
	bs.tutorial_fleet_saved.connect(_on_fleet_saved)
	bs.tutorial_shot_fired.connect(_on_shot_fired)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"bs_welcome",
		"آموزش نبرد کشتی (BattleShip)",
		"نبرد کشتی ۲ مرحله داره: اول کشتی‌هات رو روی صفحه دفاعی می‌چینی، بعد به نوبت روی رادار حریف شلیک می‌کنی تا همه کشتی‌هاش رو غرق کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع مرحله ۱")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_move := TutorialStep.create(
		"bs_move_ship",
		"۱. جابه‌جایی و چرخش کشتی‌ها",
		"روی یکی از کشتی‌هات بزن تا انتخاب بشه (با زدن دوباره می‌چرخه!) و بعد روی یک خانه خالی لمس کن تا جاش عوض بشه. امتحانش کن و بعد «بعدی» رو بزن!"
	)
	st_move.with_badge("فاز ۱: چیدمان")
	st_move.with_cta("بعدی")
	st_move.with_hint("کشتی رو جابه‌جا کن یا بچرخون")
	st_move.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_move.with_avoid_rect(func(): return _get_board_rect())
	st_move.with_scrim_alpha(0.58)
	st_move.with_interactive(false, true)
	st_move.with_placement("auto")
	st_move.with_hooks(_enter_move_ship)
	s.append(st_move)

	var st_setup := TutorialStep.create(
		"bs_setup",
		"۲. ثبت نهایی ناوگان",
		"وقتی چیدمانت آماده شد، دکمه تایید سبز (✓) سمت راست رو بزن تا وارد فاز نبرد بشی!"
	)
	st_setup.with_badge("فاز ۱: ثبت ناوگان")
	st_setup.with_hint("دکمه تایید سبز سمت راست رو بزن")
	st_setup.with_target(func(): return _get_submit_btn(), 8.0, 16.0)
	st_setup.with_avoid_rect(func(): return _get_board_rect())
	st_setup.with_scrim_alpha(0.65)
	st_setup.with_interactive(true, false)
	st_setup.with_placement("auto")
	st_setup.with_hooks(_enter_setup)
	s.append(st_setup)

	var st_miss := TutorialStep.create(
		"bs_fire_miss",
		"۳. شلیک به رادار حریف (خطا)",
		"حالا نوبت شلیکه! روی یکی از خانه‌های رادار دشمن لمس کن. اگر کشتی نباشه، تیر به آب می‌خوره (نشانگر آبی) و نوبت به حریف می‌رسه."
	)
	st_miss.with_badge("فاز ۲: نبرد")
	st_miss.with_hint("روی یکی از خانه‌های رادار شلیک کن")
	st_miss.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_miss.with_avoid_rect(func(): return _get_board_rect())
	st_miss.with_scrim_alpha(0.58)
	st_miss.with_interactive(true, false)
	st_miss.with_placement("auto")
	st_miss.with_hooks(_enter_fire_miss)
	s.append(st_miss)

	var st_hit := TutorialStep.create(
		"bs_fire_hit",
		"۴. اصابت مستقیم به کشتی حریف!",
		"دوباره یک خانه دیگه روی رادار بزن! اگر به کشتی حریف بخوره (آتش و دود)، یک شلیک جایزه می‌گیری و نوار وضعیت کشتی‌های پایین صفحه وضعیت کشتی‌های غرق‌شده رو نشون می‌ده!"
	)
	st_hit.with_badge("فاز ۲: اصابت")
	st_hit.with_hint("یک خانه دیگه روی رادار بزن!")
	st_hit.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_hit.with_avoid_rect(func(): return _get_board_rect())
	st_hit.with_scrim_alpha(0.58)
	st_hit.with_interactive(true, false)
	st_hit.with_placement("auto")
	st_hit.with_hooks(_enter_fire_hit)
	s.append(st_hit)

	var st_done := TutorialStep.create(
		"bs_done",
		"نوار وضعیت ناوگان و پایان آموزش!",
		"این نوار پایین رادار، وضعیت کشتی‌های باقی‌مانده حریف رو نشون می‌ده. هرکی زودتر تمام کشتی‌های حریف رو غرق کنه برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_target(func(): return _get_fleet_bar_rect(), 8.0, 14.0)
	st_done.with_avoid_rect(func(): return _get_board_rect())
	st_done.with_placement("auto")
	st_done.with_scrim_alpha(0.68)
	s.append(st_done)

	return s


func _enter_move_ship() -> void:
	_phase = "move_ship"
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		bs.tutorial_input_enabled = true


func _on_ship_moved() -> void:
	if is_instance_valid(_coordinator) and _phase == "move_ship":
		_coordinator.show_hud_toast("عالی! می‌تونی با لمس دوباره کشتی، اون رو بچرخونی.")


func _enter_setup() -> void:
	_phase = "submit"
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		bs.tutorial_input_enabled = true


func _on_fleet_saved() -> void:
	if not is_instance_valid(_coordinator) or _phase != "submit":
		return
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		bs.tutorial_input_enabled = false
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("ناوگان ثبت شد! آماده شلیک...")
	_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _enter_fire_miss() -> void:
	_phase = "fire_miss"
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		bs.set_force_next_hit(false)
		bs.tutorial_input_enabled = true


func _enter_fire_hit() -> void:
	_phase = "fire_hit"
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		bs.set_force_next_hit(true)
		bs.tutorial_input_enabled = true


func _on_shot_fired(_cell_idx: int, is_hit: bool) -> void:
	if not is_instance_valid(_coordinator):
		return
	var bs := _board as TutorialBattleShip3D
	if _phase == "fire_miss" or _phase == "fire_hit":
		_phase = "wait"
		if is_instance_valid(bs):
			bs.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("اصابت مستقیم! شلیک جایزه!" if is_hit else "شلیک به آب! (نشانگر آبی)")
		_coordinator.get_tree().create_timer(1.4).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_submit_btn() -> Control:
	if is_instance_valid(_board):
		var hud: Node = _board.get_base_game_hud()
		if is_instance_valid(hud) and "btn_fekr_submit" in hud:
			return hud.get("btn_fekr_submit") as Control
	return null


func _get_fleet_bar_rect() -> Rect2:
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		return bs.get_fleet_status_rect()
	return Rect2()


func _get_board_rect() -> Rect2:
	var bs := _board as TutorialBattleShip3D
	if is_instance_valid(bs):
		return bs.get_board_screen_rect()
	return Rect2()
