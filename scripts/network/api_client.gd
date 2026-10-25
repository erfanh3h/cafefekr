class_name APIClient
extends Node

# REST API Client for kafehfekrserver (Port 5001)
signal request_completed(endpoint: String, success: bool, data: Variant)

var base_url: String = "http://127.0.0.1:5001"
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

func get_my_history(callback: Callable) -> void:
	_http_get("/my-history", _get_auth_headers(), callback)

func get_my_game_history(callback: Callable) -> void:
	_http_get("/my-game-history", _get_auth_headers(), callback)

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
