extends Control

## Cafe Fekr — Play Tab (Core Gaming Arena)
## Features:
## 1. Hero Featured Mode: 1v1 Ranked Duel (رقابت دو نفره آنلاین)
## 2. 4-Player Multiplayer Mode (رقابت چند نفره آنلاین)
## 3. Classic AI & XP Practice Mode (رنک کلاسیک)
## 4. Friendly 6-Digit Custom Room Lobby (اتاق دوستانه)

signal ranked_pressed()
signal multi_rank_pressed()
signal classic_rank_pressed()
signal lobby_pressed()

@onready var btn_ranked: Button = $Scroll/Content/RankedHeroCard/BtnRankedAction
@onready var ranked_card_btn: Button = $Scroll/Content/RankedHeroCard/CardClickArea
@onready var lbl_ranked_title: Label = $Scroll/Content/RankedHeroCard/Margin/VBox/HeaderRow/TitleCol/LblTitle
@onready var lbl_ranked_desc: Label = $Scroll/Content/RankedHeroCard/Margin/VBox/HeaderRow/TitleCol/LblDesc
@onready var ranked_lock_container: VBoxContainer = $Scroll/Content/RankedHeroCard/Margin/VBox/LockContainer
@onready var ranked_lock_bar: ProgressBar = $Scroll/Content/RankedHeroCard/Margin/VBox/LockContainer/LockBar
@onready var lbl_ranked_lock: Label = $Scroll/Content/RankedHeroCard/Margin/VBox/LockContainer/LblLock

@onready var btn_multi: Button = $Scroll/Content/SecondaryModes/CardMulti/Margin/HBox/BtnAction
@onready var card_multi_btn: Button = $Scroll/Content/SecondaryModes/CardMulti/CardClickArea

@onready var btn_classic: Button = $Scroll/Content/SecondaryModes/CardClassic/Margin/HBox/BtnAction
@onready var card_classic_btn: Button = $Scroll/Content/SecondaryModes/CardClassic/CardClickArea

@onready var btn_lobby: Button = $Scroll/Content/SecondaryModes/CardLobby/Margin/HBox/BtnAction
@onready var card_lobby_btn: Button = $Scroll/Content/SecondaryModes/CardLobby/CardClickArea

func _ready() -> void:
	KenneyUI.style_button(btn_ranked, KenneyUI.COLOR_YELLOW)
	KenneyUI.style_button(btn_multi, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_classic, KenneyUI.COLOR_GREEN)
	KenneyUI.style_button(btn_lobby, KenneyUI.COLOR_WOOD)

	ActionVFXManager.apply_button_juice(btn_ranked, "tap_button")
	ActionVFXManager.apply_button_juice(btn_multi, "tap_button")
	ActionVFXManager.apply_button_juice(btn_classic, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lobby, "tap_button")

	var trigger_ranked = func():
		AudioManager.sfx_button()
		ranked_pressed.emit()
	btn_ranked.pressed.connect(trigger_ranked)
	ranked_card_btn.pressed.connect(trigger_ranked)

	var trigger_multi = func():
		AudioManager.sfx_button()
		multi_rank_pressed.emit()
	btn_multi.pressed.connect(trigger_multi)
	card_multi_btn.pressed.connect(trigger_multi)

	var trigger_classic = func():
		AudioManager.sfx_button()
		classic_rank_pressed.emit()
	btn_classic.pressed.connect(trigger_classic)
	card_classic_btn.pressed.connect(trigger_classic)

	var trigger_lobby = func():
		AudioManager.sfx_button()
		lobby_pressed.emit()
	btn_lobby.pressed.connect(trigger_lobby)
	card_lobby_btn.pressed.connect(trigger_lobby)

	GameManager.user_logged_in.connect(func(_u): update_ranked_state())
	GameManager.user_logged_out.connect(func(): update_ranked_state())
	GameManager.game_finished.connect(func(_w): update_ranked_state())
	if GameManager.has_signal("user_data_updated"):
		GameManager.user_data_updated.connect(func(_u): update_ranked_state())

	update_ranked_state()


func update_ranked_state() -> void:
	if not is_instance_valid(lbl_ranked_title):
		return

	if not GameManager.is_queue_open:
		lbl_ranked_title.text = "⛔ رقابت دو نفره آنلاین (بسته است)"
		lbl_ranked_desc.text = "صف مسابقات رده‌بندی در حال حاضر موقتاً بسته است."
		btn_ranked.text = "صف غیرفعال"
		btn_ranked.disabled = true
		ranked_lock_container.visible = false
		return

	btn_ranked.disabled = false
	var is_unlocked = GameManager.is_ranked_unlocked()
	if is_unlocked:
		lbl_ranked_title.text = "رقابت دو نفره آنلاین"
		lbl_ranked_desc.text = "دوئل نفس‌گیر تن‌به‌تن، کسب کاپ و صعود به صدر جدول قهرمانان"
		btn_ranked.text = "جستجوی حریف"
		ranked_lock_container.visible = false
	else:
		var prog = GameManager.get_ranked_unlock_progress()
		lbl_ranked_title.text = "🔒 رقابت دو نفره آنلاین"
		lbl_ranked_desc.text = "قفل است • بازگشایی پس از رسیدن به سطح ۳"
		btn_ranked.text = "مشاهده پیش‌نیاز"
		ranked_lock_container.visible = true
		var cur_xp = float(prog.get("current_xp", 0))
		var tgt_xp = float(prog.get("target_xp", 180))
		ranked_lock_bar.min_value = 0.0
		ranked_lock_bar.max_value = tgt_xp
		ranked_lock_bar.value = cur_xp
		lbl_ranked_lock.text = "%s / %s XP" % [GameManager.to_fa_num(int(cur_xp)), GameManager.to_fa_num(int(tgt_xp))]
