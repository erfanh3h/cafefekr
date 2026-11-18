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


func update_ranked_state() -> void:
	# No extra overlays on cards - authentic clean frame
	pass
