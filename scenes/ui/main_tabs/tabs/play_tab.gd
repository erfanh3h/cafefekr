extends Control

## Cafe Fekr — Play Tab (Core Gaming Arena)
## Restored authentic antique framed buttons (1v1 Ranked, Multi-Rank, Classic, Lobby)
## and prominent Watch Live & Exit top controls.

signal ranked_pressed()
signal multi_rank_pressed()
signal classic_rank_pressed()
signal lobby_pressed()
signal watch_live_requested()
signal exit_requested()

@onready var btn_watch_live: Button = $Scroll/Content/TopBarRow/HBox/BtnWatchLive
@onready var live_badge: PanelContainer = $Scroll/Content/TopBarRow/HBox/BtnWatchLive/LiveBadge
@onready var lbl_live_badge: Label = $Scroll/Content/TopBarRow/HBox/BtnWatchLive/LiveBadge/LblBadge
@onready var btn_exit: Button = $Scroll/Content/TopBarRow/HBox/BtnExit

@onready var btn_ranked: Button = $Scroll/Content/CardsContainer/BtnRanked
@onready var btn_multi: Button = $Scroll/Content/CardsContainer/BtnMultiRank
@onready var btn_classic: Button = $Scroll/Content/CardsContainer/BtnClassicRank
@onready var btn_lobby: Button = $Scroll/Content/CardsContainer/BtnLobby

func _ready() -> void:
	ActionVFXManager.apply_button_juice(btn_watch_live, "tap_button")
	ActionVFXManager.apply_button_juice(btn_exit, "tap_button")
	ActionVFXManager.apply_button_juice(btn_ranked, "tap_button")
	ActionVFXManager.apply_button_juice(btn_multi, "tap_button")
	ActionVFXManager.apply_button_juice(btn_classic, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lobby, "tap_button")

	btn_watch_live.pressed.connect(func():
		AudioManager.sfx_tap()
		watch_live_requested.emit()
	)

	btn_exit.pressed.connect(func():
		AudioManager.sfx_button()
		exit_requested.emit()
	)

	btn_ranked.pressed.connect(func():
		AudioManager.sfx_button()
		ranked_pressed.emit()
	)

	btn_multi.pressed.connect(func():
		AudioManager.sfx_button()
		multi_rank_pressed.emit()
	)

	btn_classic.pressed.connect(func():
		AudioManager.sfx_button()
		classic_rank_pressed.emit()
	)

	btn_lobby.pressed.connect(func():
		AudioManager.sfx_button()
		lobby_pressed.emit()
	)

	_check_live_games()


func _check_live_games() -> void:
	if not GameManager.is_logged_in:
		return
	NetworkManager.api.get_live_spectator_games("all", "", "", "", 1, 20, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(live_badge) or not is_instance_valid(lbl_live_badge):
			return
		var count: int = 0
		if ok and typeof(data) == TYPE_DICTIONARY:
			var res: Variant = data.get("result", null)
			if typeof(res) == TYPE_DICTIONARY:
				var res_dict: Dictionary = res
				var arr: Array = res_dict.get("items", res_dict.get("games", [])) if typeof(res_dict.get("items", res_dict.get("games", []))) == TYPE_ARRAY else []
				count = int(res_dict.get("total", arr.size()))
			elif typeof(res) == TYPE_ARRAY:
				count = (res as Array).size()
		if count > 0:
			live_badge.visible = true
			lbl_live_badge.text = GameManager.to_fa_num(count)
		else:
			live_badge.visible = false
	)


func update_ranked_state() -> void:
	# No extra overlays on cards - authentic clean frame
	pass
