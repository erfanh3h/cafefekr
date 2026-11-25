class_name MonopolyTutorialLesson
extends GameTutorialLesson

## Rich interactive Roopoly (روپولی) tutorial for the Library tab.
## Covers dice roll, buying property for Color Monopoly, building 3D houses,
## Chance card event, live Auction bidding, Mortgaging to pay Rent Debt,
## Incoming Trade offer, and escaping Jail (3 methods).

const BOARD_SCENE: PackedScene = preload("res://scenes/games/monopoly/tutorial_monopoly_3d.tscn")

var _phase: String = "" # "roll" | "buy" | "build" | "chance" | "auction" | "mortgage" | "debt_pay" | "trade" | "jail" | "done"


func get_game_type() -> String:
	return GameTypes.MONOPOLY


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var mono := board as TutorialMonopoly3D
	if not is_instance_valid(mono):
		return
	mono.tutorial_input_enabled = false
	mono.tutorial_rolled.connect(_on_rolled)
	mono.tutorial_property_decided.connect(_on_property_decided)
	mono.tutorial_house_built.connect(_on_house_built)
	mono.tutorial_chance_drawn.connect(_on_chance_drawn)
	mono.tutorial_auction_done.connect(_on_auction_done)
	mono.tutorial_mortgaged.connect(_on_mortgaged)
	mono.tutorial_debt_paid.connect(_on_debt_paid)
	mono.tutorial_trade_resolved.connect(_on_trade_resolved)
	mono.tutorial_jail_escaped.connect(_on_jail_escaped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"mono_welcome",
		"آموزش جامع روپولی (Roopoly)",
		"هدف روپولی تملک زمین‌های هم‌رنگ (انحصار)، ساخت خانه و هتل و ورشکست کردن رقبا با اجاره سنگینه! با عبور از «شروع» +۲۰۰$ می‌گیری و با تاس جفت دوباره می‌ندازی (۳ جفت پشت‌سرهم = زندان!)."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع بازی")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Roll
	var st_roll := TutorialStep.create(
		"mono_roll",
		"۱. پرتاب تاس و حرکت مهره",
		"ملک «مولوی» (قهوه‌ای) رو از قبل داری! دکمه «پرتاب تاس» رو بزن تا مهره‌ات روی نقشه حرکت کنه."
	)
	st_roll.with_badge("تمرین ۱ از ۹")
	st_roll.with_hint("دکمه «پرتاب تاس» رو بزن")
	st_roll.with_target(func(): return _get_action_btn(["پرتاب تاس", "تاس"]), 6.0, 14.0)
	st_roll.with_avoid_rect(func(): return _get_board_rect())
	st_roll.with_scrim_alpha(0.32)
	st_roll.with_interactive(true, false)
	st_roll.with_placement("top")
	st_roll.with_hooks(func(): _enter_phase("roll"))
	s.append(st_roll)

	# 2. Buy Property -> Color Monopoly
	var st_buy := TutorialStep.create(
		"mono_buy",
		"۲. خرید ملک و کامل کردن انحصار رنگ",
		"روی «بازار بزرگ ($۶۰)» فرود اومدی! با خریدش «انحصار قهوه‌ای» کامل می‌شه (اجاره ۲ برابر + اجازه ساخت خانه!). دکمه «خرید ملک ($۶۰)» رو بزن."
	)
	st_buy.with_badge("تمرین ۲ از ۹")
	st_buy.with_hint("دکمه «خرید ملک ($۶۰)» رو بزن")
	st_buy.with_target(func(): return _get_action_btn(["خرید ملک"]), 6.0, 14.0)
	st_buy.with_avoid_rect(func(): return _get_board_rect())
	st_buy.with_scrim_alpha(0.34)
	st_buy.with_interactive(true, false)
	st_buy.with_placement("top")
	st_buy.with_hooks(func(): _enter_phase("buy"))
	s.append(st_buy)

	# 3. Build 3D House
	var st_build := TutorialStep.create(
		"mono_build",
		"۳. ساخت‌وساز: خانه (🏠) و هتل (🏨)",
		"حالا هر دو ملک قهوه‌ای رو داری! «ساخت‌وساز» رو بزن و داخل پنل، «🏠 +خانه» رو لمس کن. (قانون: خانه‌ها مساوی روی هم‌رنگ‌ها ساخته می‌شن؛ ۴ خانه = ۱ هتل!)"
	)
	st_build.with_badge("تمرین ۳ از ۹")
	st_build.with_hint("«ساخت‌وساز» و سپس «🏠 +خانه» رو بزن")
	st_build.with_target(func(): return _get_build_target(), 6.0, 14.0)
	st_build.with_scrim_alpha(0.40)
	st_build.with_interactive(true, false)
	st_build.with_placement("top")
	st_build.with_hooks(func(): _enter_phase("build"))
	s.append(st_build)

	# 4. Chance Card
	var st_chance := TutorialStep.create(
		"mono_chance",
		"۴. خانه «کارت شانس» (🎲)",
		"دوباره «پرتاب تاس» رو بزن تا مهره‌ات به خانه «کارت شانس» برسه و ببینی کارت‌های شانس و صندوق شانس چطور جایزه یا مأموریت می‌دن!"
	)
	st_chance.with_badge("تمرین ۴ از ۹")
	st_chance.with_hint("دکمه «پرتاب تاس» رو بزن")
	st_chance.with_target(func(): return _get_action_btn(["پرتاب تاس", "تاس"]), 6.0, 14.0)
	st_chance.with_avoid_rect(func(): return _get_board_rect())
	st_chance.with_scrim_alpha(0.32)
	st_chance.with_interactive(true, false)
	st_chance.with_placement("top")
	st_chance.with_hooks(func(): _enter_phase("chance"))
	s.append(st_chance)

	# 5. Live Auction
	var st_auction := TutorialStep.create(
		"mono_auction",
		"۵. شرکت در مزایده (🔨)",
		"وقتی کسی ملکی رو نخره، ملک به مزایده می‌ره و حریف $۲۰ پیشنهاد داده! با زدن «پیشنهاد $۳۰» ملک «جردن» رو با قیمت عالی تصاحب کن!"
	)
	st_auction.with_badge("تمرین ۵ از ۹")
	st_auction.with_hint("دکمه «پیشنهاد $۳۰» رو بزن")
	st_auction.with_target(func(): return _get_action_btn(["پیشنهاد"]), 6.0, 14.0)
	st_auction.with_avoid_rect(func(): return _get_board_rect())
	st_auction.with_scrim_alpha(0.34)
	st_auction.with_interactive(true, false)
	st_auction.with_placement("top")
	st_auction.with_hooks(func(): _enter_phase("auction"))
	s.append(st_auction)

	# 6. Mortgage to Raise Cash
	var st_mortgage := TutorialStep.create(
		"mono_mortgage",
		"۶. کسری نقدینگی و رهن ملک (🏦)",
		"مهره‌ات روی «لاله‌زار» حریف رفت و $۱۵۰ بدهکار شدی، ولی فقط $۱۲۰ نقد داری! دکمه نارنجی «فروش / رهن املاک» رو بزن و یکی از املاکت رو به نصف قیمت رهن بده تا پول نقد جور بشه!"
	)
	st_mortgage.with_badge("تمرین ۶ از ۹")
	st_mortgage.with_hint("«فروش / رهن املاک» و سپس «🏦 رهن» رو بزن")
	st_mortgage.with_target(func(): return _get_mortgage_target(), 6.0, 14.0)
	st_mortgage.with_scrim_alpha(0.38)
	st_mortgage.with_interactive(true, false)
	st_mortgage.with_placement("top")
	st_mortgage.with_hooks(func(): _enter_phase("mortgage"))
	s.append(st_mortgage)

	# 7. Pay Debt
	var st_debt := TutorialStep.create(
		"mono_debt",
		"۷. تسویه کامل بدهی ($۱۵۰)",
		"عالی! با پولی که از رهن گرفتی، دکمه سبز «پرداخت بدهی ($۱۵۰)» فعال شد. (برای فک رهن بعداً باید ۱۰٪ سود بدی.) دکمه پرداخت بدهی رو بزن!"
	)
	st_debt.with_badge("تمرین ۷ از ۹")
	st_debt.with_hint("دکمه «پرداخت بدهی ($۱۵۰)» رو بزن")
	st_debt.with_target(func(): return _get_action_btn(["پرداخت بدهی"]), 6.0, 14.0)
	st_debt.with_avoid_rect(func(): return _get_board_rect())
	st_debt.with_scrim_alpha(0.34)
	st_debt.with_interactive(true, false)
	st_debt.with_placement("top")
	st_debt.with_hooks(func(): _enter_phase("debt_pay"))
	s.append(st_debt)

	# 8. Incoming Trade Offer
	var st_trade := TutorialStep.create(
		"mono_trade",
		"۸. معامله ملک و پول با حریف (🤝)",
		"حریف پیشنهاد معامله فرستاده: «بهارستان + $۶۰» در ازای «جردن»! معامله هوشمندانه کلید گرفتن انحصار رنگه. معامله رو قبول یا رد کن!"
	)
	st_trade.with_badge("تمرین ۸ از ۹")
	st_trade.with_hint("«قبول معامله» یا «رد معامله» رو بزن")
	st_trade.with_target(func(): return _get_trade_target(), 8.0, 16.0)
	st_trade.with_scrim_alpha(0.45)
	st_trade.with_interactive(true, false)
	st_trade.with_placement("top")
	st_trade.with_hooks(func(): _enter_phase("trade"))
	s.append(st_trade)

	# 9. Jail Escape (3 options)
	var st_jail := TutorialStep.create(
		"mono_jail",
		"۹. خروج از زندان (۳ روش واقعی)",
		"مهره‌ات توی زندانه! ۳ راه برای آزادی داری:\n۱) 🎲 تاس جفت (رایگان)  ۲) 💰 وثیقه $۵۰  ۳) 🎫 کارت آزادی.\nیکی از ۳ دکمه پایین رو بزن تا مهره‌ات آزاد بشه!"
	)
	st_jail.with_badge("تمرین ۹ از ۹")
	st_jail.with_hint("یکی از ۳ روش خروج از زندان رو بزن")
	st_jail.with_target(func(): return _get_actions_vbox(), 6.0, 14.0)
	st_jail.with_avoid_rect(func(): return _get_board_rect())
	st_jail.with_scrim_alpha(0.34)
	st_jail.with_interactive(true, false)
	st_jail.with_placement("top")
	st_jail.with_hooks(func(): _enter_phase("jail"))
	s.append(st_jail)

	# 10. Finish Dialog
	var st_done := TutorialStep.create(
		"mono_done",
		"پایان آموزش روپولی",
		"آفرین سرمایه‌دار! حالا پرتاب تاس، خرید و انحصار رنگ، ساخت خانه و هتل، کارت شانس، مزایده، رهن و پرداخت بدهی، معامله و خروج از زندان رو کاملاً بلدی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var mono := _board as TutorialMonopoly3D
	if not is_instance_valid(mono):
		return
	if p == "chance":
		mono.setup_chance_roll_scenario()
	elif p == "auction":
		mono.setup_auction_scenario()
	elif p == "mortgage":
		mono.setup_mortgage_debt_scenario()
	elif p == "trade":
		mono.setup_trade_scenario()
	elif p == "jail":
		mono.setup_jail_scenario()
	mono.tutorial_input_enabled = (p != "done")


func _advance_after(delay_sec: float) -> void:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		mono.tutorial_input_enabled = false
	if not is_instance_valid(_coordinator):
		return
	_coordinator.hide_overlay_temporarily()
	_coordinator.get_tree().create_timer(delay_sec).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _on_rolled(_dice: Array) -> void:
	if is_instance_valid(_coordinator) and _phase == "roll":
		_phase = "wait"
		_coordinator.show_hud_toast("🎲 ۱ + ۲ = ۳ — به بازار بزرگ رسیدی!")
		_advance_after(1.35)


func _on_property_decided(_act: String) -> void:
	if is_instance_valid(_coordinator) and _phase == "buy":
		_phase = "wait"
		_coordinator.show_hud_toast("✅ بازار بزرگ خریداری شد — انحصار قهوه‌ای کامل شد!")
		_advance_after(0.9)


func _on_house_built(_tid: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "build":
		_phase = "wait"
		_coordinator.show_hud_toast("🏠 اولین خانه سه‌بعدی روی نقشه ساخته شد!")
		_advance_after(0.9)


func _on_chance_drawn() -> void:
	if is_instance_valid(_coordinator) and _phase == "chance":
		_phase = "wait"
		_coordinator.show_hud_toast("🎲 کارت شانس: +$۱۰۰ جایزه گرفتی!")
		_advance_after(2.2)


func _on_auction_done() -> void:
	if is_instance_valid(_coordinator) and _phase == "auction":
		_phase = "wait"
		_coordinator.show_hud_toast("🔨 مزایده را بردی و جردن مال تو شد!")
		_advance_after(0.9)


func _on_mortgaged(_tid: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "mortgage":
		_phase = "wait"
		_coordinator.show_hud_toast("🏦 ملک رهن شد و پول نقد تامین گردید!")
		_advance_after(0.8)


func _on_debt_paid() -> void:
	if is_instance_valid(_coordinator) and _phase == "debt_pay":
		_phase = "wait"
		_coordinator.show_hud_toast("💳 بدهی $۱۵۰ تسویه شد!")
		_advance_after(0.9)


func _on_trade_resolved(act: String) -> void:
	if is_instance_valid(_coordinator) and _phase == "trade":
		_phase = "wait"
		_coordinator.show_hud_toast("🤝 معامله انجام شد!" if act == "accept" else "❌ پیشنهاد معامله رد شد.")
		_advance_after(0.9)


func _on_jail_escaped(_method: String) -> void:
	if is_instance_valid(_coordinator) and _phase == "jail":
		_phase = "wait"
		_coordinator.show_hud_toast("🔓 از زندان آزاد شدی!")
		_advance_after(1.3)


func _get_action_btn(keywords: Array[String]) -> Control:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_action_button_matching(keywords)
	return null


func _get_build_target() -> Control:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_build_target_control()
	return null


func _get_mortgage_target() -> Control:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_mortgage_target_control()
	return null


func _get_trade_target() -> Control:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_trade_target_control()
	return null


func _get_actions_vbox() -> Control:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_actions_vbox_control()
	return null


func _get_board_rect() -> Rect2:
	var mono := _board as TutorialMonopoly3D
	if is_instance_valid(mono):
		return mono.get_board_screen_rect()
	return Rect2()
