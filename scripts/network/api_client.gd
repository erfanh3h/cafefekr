class_name APIClient
extends Node

# REST API Client for kafehfekrserver (Port 5001)
signal request_completed(endpoint: String, success: bool, data: Variant)

var base_url: String = "http://192.168.1.2:5001"
var auth_token: String = ""

func set_base_url(url: String) -> void:
	base_url = url.rstrip("/")

func set_token(token: String) -> void:
	auth_token = token

# --- AUTH ENDPOINTS ---

func send_phone_code(phone: String, callback: Callable) -> void:
	var body = "phone=" + phone.uri_encode()
	_post_form("/enter", body, [], callback)

func verify_code(phone: String, code: String, device_id: String, callback: Callable) -> void:
	var body = "phone=%s&code=%s&device_id=%s" % [
		phone.uri_encode(),
		code.uri_encode(),
		device_id.uri_encode()
	]
	_post_form("/code", body, [], callback)

func complete_registration(username: String, rep_id: String = "", phone: String = "", callback: Callable = Callable()) -> void:
	var body = "username=" + username.uri_encode()
	if not rep_id.is_empty():
		body += "&rep_id=" + rep_id.uri_encode()
	if not phone.is_empty():
		body += "&phone=" + phone.uri_encode()
	_post_form("/complete-data", body, _get_auth_headers(), callback)

# --- USER ENDPOINTS ---

func get_my_data(callback: Callable) -> void:
	_http_get("/my-data", _get_auth_headers(), callback)

func update_username(new_username: String, callback: Callable) -> void:
	var body = "username=" + new_username.uri_encode()
	_post_form("/update-username", body, _get_auth_headers(), callback)

func update_avatar(image_id: int, callback: Callable) -> void:
	var body = "image=" + str(image_id)
	_post_form("/update-image", body, _get_auth_headers(), callback)

func get_ranking_by_score(callback: Callable) -> void:
	_http_get("/ranking-by-score", PackedStringArray(), callback)

func get_ranking_by_win(callback: Callable) -> void:
	_http_get("/ranking-by-win", PackedStringArray(), callback)

func get_config(callback: Callable) -> void:
	_http_get("/config", PackedStringArray(), callback)

func get_my_history(callback: Callable) -> void:
	_http_get("/my-history", _get_auth_headers(), callback)

func get_my_game_history(callback: Callable) -> void:
	_http_get("/my-game-history", _get_auth_headers(), callback)

func get_user_data(user_id: String, callback: Callable) -> void:
	_http_get("/user-data/%s" % user_id, PackedStringArray(), callback)

func claim_free_coin(callback: Callable) -> void:
	_http_get("/get-free-coin", _get_auth_headers(), callback)

# --- INTERNAL HELPERS ---

func _get_auth_headers() -> PackedStringArray:
	var headers = PackedStringArray()
	if not auth_token.is_empty():
		headers.append("Authorization: " + auth_token)
	return headers

func _http_get(endpoint: String, custom_headers: PackedStringArray, callback: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var success = (response_code >= 200 and response_code < 300)
		var json = JSON.new()
		var parsed_data = null
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed_data = json.data
			
		callback.call(success, response_code, parsed_data)
		http.queue_free()
	)
	
	var url = base_url + endpoint
	http.request(url, custom_headers, HTTPClient.METHOD_GET)

func _post_form(endpoint: String, body_str: String, custom_headers: PackedStringArray, callback: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = custom_headers.duplicate()
	headers.append("Content-Type: application/x-www-form-urlencoded")
	
	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var success = (response_code >= 200 and response_code < 300)
		var json = JSON.new()
		var parsed_data = null
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed_data = json.data
			
		callback.call(success, response_code, parsed_data)
		http.queue_free()
	)
	
	var url = base_url + endpoint
	http.request(url, headers, HTTPClient.METHOD_POST, body_str)

# --- SOCIAL, FRIENDS, PROFILES, CLANS, MESSAGES & NOTIFICATIONS ENDPOINTS ---

func _post_json(endpoint: String, payload: Dictionary, custom_headers: PackedStringArray, callback: Callable) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = custom_headers.duplicate()
	headers.append("Content-Type: application/json")
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		var success = (response_code >= 200 and response_code < 300)
		var json = JSON.new()
		var parsed_data = null
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed_data = json.data
		if callback.is_valid():
			callback.call(success, response_code, parsed_data)
		http.queue_free()
	)
	var url = base_url + endpoint
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

# Friends & Search
func search_social_players(query: String, callback: Callable) -> void:
	_http_get("/social/players/search?q=" + query.uri_encode(), _get_auth_headers(), callback)

func get_friends_list(callback: Callable) -> void:
	_http_get("/social/friends", _get_auth_headers(), callback)

func get_friend_requests(callback: Callable) -> void:
	_http_get("/social/friends/requests", _get_auth_headers(), callback)

func send_friend_request(to_user_id: String, message: String = "", callback: Callable = Callable()) -> void:
	_post_json("/social/friends/request", {"to_user_id": to_user_id, "message": message}, _get_auth_headers(), callback)

func respond_friend_request(request_id: String, action: String, callback: Callable = Callable()) -> void:
	_post_json("/social/friends/respond", {"request_id": request_id, "action": action}, _get_auth_headers(), callback)

func remove_friend(friend_id: String, callback: Callable = Callable()) -> void:
	_post_json("/social/friends/remove", {"friend_id": friend_id}, _get_auth_headers(), callback)

func get_social_discover(callback: Callable) -> void:
	_http_get("/social/friends/discover", _get_auth_headers(), callback)

# Public Profiles & Customization
func get_public_profile(user_id: String, callback: Callable) -> void:
	_http_get("/social/profile/" + user_id.uri_encode(), _get_auth_headers(), callback)

func customize_my_profile(payload: Dictionary, callback: Callable = Callable()) -> void:
	_post_json("/social/profile/customize", payload, _get_auth_headers(), callback)

# Moderation (Block & Report)
func get_blocked_players(callback: Callable) -> void:
	_http_get("/social/blocks", _get_auth_headers(), callback)

func block_player(target_user_id: String, reason: String = "", callback: Callable = Callable()) -> void:
	_post_json("/social/block", {"target_user_id": target_user_id, "reason": reason}, _get_auth_headers(), callback)

func unblock_player(target_user_id: String, callback: Callable = Callable()) -> void:
	_post_json("/social/unblock", {"target_user_id": target_user_id}, _get_auth_headers(), callback)

func report_social_target(target_type: String, target_id: String, reason: String, details: String = "", callback: Callable = Callable()) -> void:
	_post_json("/social/report", {"target_type": target_type, "target_id": target_id, "reason": reason, "details": details}, _get_auth_headers(), callback)

# Game Invitations
func get_game_invitations(callback: Callable) -> void:
	_http_get("/social/invitations", _get_auth_headers(), callback)

func send_game_invitation_rest(to_user_id: String, game_type: String = "Ludo", invite_mode: String = "direct_match", lobby_id: String = "", player_count: int = 2, callback: Callable = Callable()) -> void:
	_post_json("/social/invitations/send", {
		"to_user_id": to_user_id,
		"game_type": game_type,
		"invite_mode": invite_mode,
		"lobby_id": lobby_id,
		"player_count": player_count
	}, _get_auth_headers(), callback)

func respond_game_invitation_rest(invite_id: String, action: String, callback: Callable = Callable()) -> void:
	_post_json("/social/invitations/respond", {"invite_id": invite_id, "action": action}, _get_auth_headers(), callback)

# Social & Clan Leaderboards
func get_social_leaderboard(board_type: String = "global_score", game_type: String = "", clan_id: String = "", callback: Callable = Callable()) -> void:
	var q = "/social/leaderboards?board_type=" + board_type.uri_encode()
	if not game_type.is_empty():
		q += "&game_type=" + game_type.uri_encode()
	if not clan_id.is_empty():
		q += "&clan_id=" + clan_id.uri_encode()
	_http_get(q, _get_auth_headers(), callback)

# Clans / Guilds
func get_my_clan(callback: Callable) -> void:
	_http_get("/clans/my", _get_auth_headers(), callback)

func search_clans(query: String = "", join_type: String = "", sort_by: String = "clan_score", callback: Callable = Callable()) -> void:
	var q = "/clans/search?q=" + query.uri_encode() + "&join_type=" + join_type.uri_encode() + "&sort_by=" + sort_by.uri_encode()
	_http_get(q, _get_auth_headers(), callback)

func get_clan_details(clan_id: String, callback: Callable) -> void:
	_http_get("/clans/" + clan_id.uri_encode(), _get_auth_headers(), callback)

func create_clan(payload: Dictionary, callback: Callable) -> void:
	_post_json("/clans/create", payload, _get_auth_headers(), callback)

func join_or_request_clan(clan_id: String, message: String = "", callback: Callable = Callable()) -> void:
	_post_json("/clans/join", {"clan_id": clan_id, "message": message}, _get_auth_headers(), callback)

func respond_clan_join_request(request_id: String, action: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/requests/respond", {"request_id": request_id, "action": action}, _get_auth_headers(), callback)

func invite_to_clan(target_user_id: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/invite", {"target_user_id": target_user_id}, _get_auth_headers(), callback)

func respond_clan_invitation(invite_id: String, action: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/invitations/respond", {"invite_id": invite_id, "action": action}, _get_auth_headers(), callback)

func leave_clan(callback: Callable = Callable()) -> void:
	_post_json("/clans/leave", {}, _get_auth_headers(), callback)

func kick_clan_member(target_user_id: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/kick", {"target_user_id": target_user_id}, _get_auth_headers(), callback)

func change_clan_member_role(target_user_id: String, new_role: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/role", {"target_user_id": target_user_id, "new_role": new_role}, _get_auth_headers(), callback)

func transfer_clan_leadership(new_leader_id: String, callback: Callable = Callable()) -> void:
	_post_json("/clans/transfer-leadership", {"new_leader_id": new_leader_id}, _get_auth_headers(), callback)

func disband_clan(callback: Callable = Callable()) -> void:
	_post_json("/clans/disband", {}, _get_auth_headers(), callback)

func update_clan_settings(payload: Dictionary, callback: Callable = Callable()) -> void:
	_post_json("/clans/settings", payload, _get_auth_headers(), callback)

func create_clan_friendly_challenge(game_type: String = "Ludo", player_count: int = 2, callback: Callable = Callable()) -> void:
	_post_json("/clans/friendly-challenge", {"game_type": game_type, "player_count": player_count}, _get_auth_headers(), callback)

# Direct Messages & Clan Chat
func get_conversations_list(callback: Callable) -> void:
	_http_get("/messages/conversations", _get_auth_headers(), callback)

func get_direct_messages(partner_id: String, callback: Callable) -> void:
	_http_get("/messages/direct/" + partner_id.uri_encode(), _get_auth_headers(), callback)

func send_direct_message_rest(to_user_id: String, text: String, callback: Callable = Callable()) -> void:
	_post_json("/messages/direct/send", {"to_user_id": to_user_id, "text": text}, _get_auth_headers(), callback)

func get_clan_chat_history(clan_id: String = "", callback: Callable = Callable()) -> void:
	var q = "/messages/clan"
	if not clan_id.is_empty():
		q += "?clan_id=" + clan_id.uri_encode()
	_http_get(q, _get_auth_headers(), callback)

func send_clan_chat_rest(text: String, callback: Callable = Callable()) -> void:
	_post_json("/messages/clan/send", {"text": text}, _get_auth_headers(), callback)

func delete_clan_chat_message(message_id: String, callback: Callable = Callable()) -> void:
	_post_json("/messages/clan/delete", {"message_id": message_id}, _get_auth_headers(), callback)

# Social Notifications
func get_notifications_list(unread_only: bool = false, callback: Callable = Callable()) -> void:
	var q = "/notifications/list?unread_only=" + ("true" if unread_only else "false")
	_http_get(q, _get_auth_headers(), callback)

func mark_notification_read(notification_id: String, callback: Callable = Callable()) -> void:
	_post_json("/notifications/read", {"notification_id": notification_id}, _get_auth_headers(), callback)

func mark_all_notifications_read(callback: Callable = Callable()) -> void:
	_post_json("/notifications/read-all", {}, _get_auth_headers(), callback)

func update_notification_preferences(prefs: Dictionary, callback: Callable = Callable()) -> void:
	_post_json("/notifications/preferences", prefs, _get_auth_headers(), callback)
