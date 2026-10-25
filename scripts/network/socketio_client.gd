class_name SocketIOClient
extends Node

# Signals
signal connected_to_server()
signal disconnected_from_server()
signal namespace_connected(ns: String)
signal namespace_disconnected(ns: String)
signal event_received(ns: String, event_name: String, data: Variant)

var ws: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var current_url: String = ""

# Engine.IO ping/pong timers
var ping_interval: float = 25.0
var ping_timeout: float = 20.0
var last_ping_time: float = 0.0

var connected_namespaces: Dictionary = {} # namespace -> bool
var pending_auth: Dictionary = {} # namespace -> auth_dict

func _ready() -> void:
	set_process(true)

func connect_to_host(host: String = "127.0.0.1", port: int = 5000, ssl: bool = false) -> Error:
	var protocol = "wss://" if ssl else "ws://"
	var url = "%s%s:%d/socket.io/?EIO=4&transport=websocket" % [protocol, host, port]
	return connect_url(url)

func connect_url(url: String) -> Error:
	current_url = url
	is_connected_to_server = false
	connected_namespaces.clear()
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
		ws = WebSocketPeer.new()
	var err = ws.connect_to_url(url)
	if err != OK:
		push_error("[SocketIO] Failed to connect to URL: %s, Error: %d" % [url, err])
	else:
		print("[SocketIO] Connecting to %s ..." % url)
	return err

func disconnect_from_host() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	is_connected_to_server = false
	connected_namespaces.clear()

func _process(delta: float) -> void:
	ws.poll()
	var state = ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var packet = ws.get_packet().get_string_from_utf8()
				_handle_packet(packet)
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if is_connected_to_server:
				is_connected_to_server = false
				connected_namespaces.clear()
				disconnected_from_server.emit()
				print("[SocketIO] Connection closed.")

func connect_namespace(ns: String, auth: Dictionary = {}) -> void:
	pending_auth[ns] = auth
	if is_connected_to_server:
		_send_namespace_connect(ns, auth)

func disconnect_namespace(ns: String) -> void:
	pending_auth.erase(ns)
	if connected_namespaces.has(ns):
		_send_packet("41" + ns + ",")
		connected_namespaces.erase(ns)
		namespace_disconnected.emit(ns)

func emit_event(ns: String, event_name: String, data: Variant = null) -> void:
	if not is_connected_to_server:
		push_warning("[SocketIO] Cannot emit %s, not connected." % event_name)
		return
	
	var payload_array = [event_name]
	if data != null:
		payload_array.append(data)
	
	var payload_str = JSON.stringify(payload_array)
	var packet = "42" + (ns + "," if ns != "/" else "") + payload_str
	_send_packet(packet)

func _send_namespace_connect(ns: String, auth: Dictionary = {}) -> void:
	var packet = "40" + ns + ","
	if not auth.is_empty():
		packet += JSON.stringify(auth)
	_send_packet(packet)

func _send_packet(text: String) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(text)

func _handle_packet(packet: String) -> void:
	if packet.is_empty():
		return
	
	var engine_type = packet.substr(0, 1)
	var body = packet.substr(1)

	match engine_type:
		"0": # Engine.IO Open / Handshake
			var json = JSON.new()
			if json.parse(body) == OK and typeof(json.data) == TYPE_DICTIONARY:
				var data = json.data
				ping_interval = data.get("pingInterval", 25000) / 1000.0
				ping_timeout = data.get("pingTimeout", 20000) / 1000.0
				is_connected_to_server = true
				connected_to_server.emit()
				print("[SocketIO] Connected. Handshake received. SID: %s" % data.get("sid", ""))
				
				# Connect any pending namespaces
				for ns in pending_auth.keys():
					_send_namespace_connect(ns, pending_auth[ns])

		"2": # Ping from server
			_send_packet("3") # Pong reply

		"3": # Pong reply from server
			pass

		"4": # Socket.IO packet
			_handle_socketio_packet(body)

func _handle_socketio_packet(body: String) -> void:
	if body.is_empty():
		return
	
	var sio_type = body.substr(0, 1)
	var remaining = body.substr(1)
	
	# Parse namespace if present (e.g., "/game,..." or "/queue,...")
	var ns = "/"
	if remaining.begins_with("/"):
		var comma_idx = remaining.find(",")
		if comma_idx != -1:
			ns = remaining.substr(0, comma_idx)
			remaining = remaining.substr(comma_idx + 1)
		else:
			ns = remaining
			remaining = ""

	match sio_type:
		"0": # Connect ACK for namespace
			connected_namespaces[ns] = true
			namespace_connected.emit(ns)
			print("[SocketIO] Namespace '%s' connected." % ns)

		"1": # Disconnect ACK for namespace
			connected_namespaces.erase(ns)
			namespace_disconnected.emit(ns)
			print("[SocketIO] Namespace '%s' disconnected." % ns)

		"2": # Event
			var json = JSON.new()
			if json.parse(remaining) == OK and typeof(json.data) == TYPE_ARRAY:
				var arr: Array = json.data
				if arr.size() > 0:
					var event_name: String = str(arr[0])
					var data: Variant = arr[1] if arr.size() > 1 else null
					event_received.emit(ns, event_name, data)

		"4": # Connect Error
			push_error("[SocketIO] Namespace '%s' connect error: %s" % [ns, remaining])
