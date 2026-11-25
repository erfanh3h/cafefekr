extends Control

## Cafe Fekr — Play Tab (Core Gaming Arena)
## Authentic antique framed buttons (1v1 Ranked, Multi-Rank, Classic, Lobby)
## and top bar controls: Watch Live (left) + History, Friends, Notifications, Exit (right).

signal ranked_pressed()
signal multi_rank_pressed()
signal classic_rank_pressed()
signal lobby_pressed()
signal watch_live_requested()
signal exit_requested()
signal history_page_requested()
signal friends_page_requested()
signal notifications_page_requested()

@onready var btn_watch_live: Button = $Scroll/Content/TopBarRow/HBox/BtnWatchLive
@onready var btn_history: Button = $Scroll/Content/TopBarRow/HBox/RightActions/BtnHistory
@onready var btn_friends: Button = $Scroll/Content/TopBarRow/HBox/RightActions/BtnFriends
@onready var btn_notifications: Button = $Scroll/Content/TopBarRow/HBox/RightActions/BtnNotifications
@onready var btn_exit: Button = $Scroll/Content/TopBarRow/HBox/RightActions/BtnExit

@onready var badge_friends: PanelContainer = $Scroll/Content/TopBarRow/HBox/RightActions/BtnFriends/Badge
@onready var lbl_badge_friends: Label = $Scroll/Content/TopBarRow/HBox/RightActions/BtnFriends/Badge/LblCount
@onready var badge_notifications: PanelContainer = $Scroll/Content/TopBarRow/HBox/RightActions/BtnNotifications/Badge
@onready var lbl_badge_notifications: Label = $Scroll/Content/TopBarRow/HBox/RightActions/BtnNotifications/Badge/LblCount

const MYKET_URL: String = "https://myket.ir/app/kafeh.fekr.classic"
const BAZAAR_URL: String = "https://cafebazaar.ir/app/kafeh.fekr.classic"

@onready var btn_ranked: Button = $Scroll/Content/CardsContainer/BtnRanked
@onready var btn_multi: Button = $Scroll/Content/CardsContainer/BtnMultiRank
@onready var btn_classic: Button = $Scroll/Content/CardsContainer/BtnClassicRank
@onready var btn_lobby: Button = $Scroll/Content/CardsContainer/BtnLobby

@onready var platform_links_frame: PanelContainer = $PlatformLinksFrame
@onready var btn_bazaar: Button = $PlatformLinksFrame/HBox/BtnBazaar
@onready var btn_myket: Button = $PlatformLinksFrame/HBox/BtnMyket
@onready var btn_windows: Button = $PlatformLinksFrame/HBox/BtnWindows
@onready var lbl_version: Label = $LblVersion


func _ready() -> void:
	ActionVFXManager.apply_button_juice(btn_watch_live, "tap_button")
	ActionVFXManager.apply_button_juice(btn_history, "tap_button")
	ActionVFXManager.apply_button_juice(btn_friends, "tap_button")
	ActionVFXManager.apply_button_juice(btn_notifications, "tap_button")
	ActionVFXManager.apply_button_juice(btn_exit, "tap_button")
	ActionVFXManager.apply_button_juice(btn_ranked, "tap_button")
	ActionVFXManager.apply_button_juice(btn_multi, "tap_button")
	ActionVFXManager.apply_button_juice(btn_classic, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lobby, "tap_button")
	ActionVFXManager.apply_button_juice(btn_bazaar, "tap_button")
	ActionVFXManager.apply_button_juice(btn_myket, "tap_button")
	ActionVFXManager.apply_button_juice(btn_windows, "tap_button")

	btn_watch_live.pressed.connect(func():
		AudioManager.sfx_tap()
		watch_live_requested.emit()
	)

	btn_history.pressed.connect(func():
		AudioManager.sfx_tap()
		history_page_requested.emit()
	)

	btn_friends.pressed.connect(func():
		AudioManager.sfx_tap()
		friends_page_requested.emit()
	)

	btn_notifications.pressed.connect(func():
		AudioManager.sfx_tap()
		notifications_page_requested.emit()
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

	btn_bazaar.pressed.connect(func():
		AudioManager.sfx_tap()
		OS.shell_open(BAZAAR_URL)
	)

	btn_myket.pressed.connect(func():
		AudioManager.sfx_tap()
		OS.shell_open(MYKET_URL)
	)

	btn_windows.pressed.connect(func():
		AudioManager.sfx_tap()
		if not GameManager.windows_link.is_empty():
			OS.shell_open(GameManager.windows_link)
		else:
			NetworkManager.fetch_server_config(func(success: bool, _cfg: Dictionary):
				if success and not GameManager.windows_link.is_empty():
					OS.shell_open(GameManager.windows_link)
			)
	)

	NetworkManager.social_badges_changed.connect(update_top_badges)
	NetworkManager.social_init_received.connect(func(_p: Dictionary): update_top_badges())
	NetworkManager.social_dm_received.connect(func(_p: Dictionary): update_top_badges())
	NetworkManager.social_notification_received.connect(func(_p: Dictionary): update_top_badges())
	GameManager.server_config_updated.connect(func(_cfg: Dictionary): _update_platform_links_visibility())

	_ensure_social_connected()
	update_top_badges()
	_update_platform_links_visibility()
	_update_version_label()


func _update_version_label() -> void:
	if is_instance_valid(lbl_version):
		lbl_version.text = "نسخه " + GameManager.to_fa_num(GameManager.get_app_version())


func _update_platform_links_visibility() -> void:
	if not is_instance_valid(platform_links_frame):
		return
	var os_name: String = OS.get_name()
	if os_name == "Android":
		platform_links_frame.visible = true
		btn_windows.visible = true
		btn_bazaar.visible = false
		btn_myket.visible = false
	elif os_name == "Windows":
		platform_links_frame.visible = true
		btn_windows.visible = false
		btn_bazaar.visible = true
		btn_myket.visible = true
	else:
		platform_links_frame.visible = false


func _ensure_social_connected() -> void:
	if NetworkManager.is_online and not NetworkManager.is_social_connected and GameManager.is_logged_in and not GameManager.token.is_empty():
		NetworkManager.connect_social_namespace()


func update_top_badges() -> void:
	if is_instance_valid(badge_friends) and is_instance_valid(lbl_badge_friends):
		var friends_total: int = NetworkManager.unread_dms_count + NetworkManager.incoming_friend_requests_count
		if friends_total > 0:
			badge_friends.visible = true
			lbl_badge_friends.text = "۹۹+" if friends_total > 99 else GameManager.to_fa_num(friends_total)
		else:
			badge_friends.visible = false

	if is_instance_valid(badge_notifications) and is_instance_valid(lbl_badge_notifications):
		var notif_total: int = NetworkManager.unread_notifications_count
		if notif_total > 0:
			badge_notifications.visible = true
			lbl_badge_notifications.text = "۹۹+" if notif_total > 99 else GameManager.to_fa_num(notif_total)
		else:
			badge_notifications.visible = false


func update_ranked_state() -> void:
	_ensure_social_connected()
	update_top_badges()
