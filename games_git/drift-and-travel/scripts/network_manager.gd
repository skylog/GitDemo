extends Node

# Sprint 7: WebSocket relay client autoload.
# Protocol matches relay.js: create_room, join_room, broadcast, to_host.
# Reference: PRD §6.1 N1-N4, relay/relay.js.

const DEFAULT_RELAY := "ws://localhost:8080"

signal connected_to_relay
signal connection_failed
signal disconnected_from_relay
signal room_created(room_code: String)
signal room_joined(room_code: String, player_id: String)
signal join_failed(reason: String)
signal player_joined(player_id: String)
signal player_left(player_id: String)
signal host_disconnected
signal message_received(from: String, payload: Dictionary)

var relay_url: String = DEFAULT_RELAY
var player_name: String = ""
var room_code: String = ""
var player_id: String = ""
var is_host: bool = false
var players: Array[String] = []

var _ws: WebSocketPeer = WebSocketPeer.new()
var _ws_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
var _connected: bool = false


func _ready() -> void:
	print("[NetworkManager] autoload ready")


func connect_to_relay(url: String) -> void:
	_disconnect_ws()
	relay_url = url
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(relay_url)
	if err != OK:
		push_warning("[NetworkManager] connect_to_url error: %d" % err)
		emit_signal("connection_failed")
	print("[NetworkManager] connecting to %s" % relay_url)


func disconnect_from_relay() -> void:
	if _connected:
		_send({ "type": "leave_room" })
	_disconnect_ws()
	room_code = ""
	player_id = ""
	is_host = false
	players.clear()


func create_room(code: String, p_name: String) -> void:
	player_name = _sanitize_name(p_name)
	player_id = player_name
	room_code = code
	_send({ "type": "create_room", "roomCode": code, "playerId": player_name })


func join_room(code: String, p_name: String) -> void:
	player_name = _sanitize_name(p_name)
	player_id = player_name
	_send({ "type": "join_room", "roomCode": code, "playerId": player_name })


func broadcast(payload: Dictionary) -> void:
	_send({ "type": "broadcast", "payload": payload })


func send_to_host(payload: Dictionary) -> void:
	_send({ "type": "to_host", "payload": payload })


func _process(_delta: float) -> void:
	_ws.poll()
	var new_state := _ws.get_ready_state()
	if new_state != _ws_state:
		var prev := _ws_state
		_ws_state = new_state
		match new_state:
			WebSocketPeer.STATE_OPEN:
				_connected = true
				print("[NetworkManager] connected to relay")
				emit_signal("connected_to_relay")
			WebSocketPeer.STATE_CLOSED:
				if _connected:
					_connected = false
					print("[NetworkManager] disconnected from relay")
					emit_signal("disconnected_from_relay")
				elif prev == WebSocketPeer.STATE_CONNECTING:
					print("[NetworkManager] connection failed")
					emit_signal("connection_failed")

	while _ws.get_available_packet_count() > 0:
		var data := _ws.get_packet()
		var text := data.get_string_from_utf8()
		var msg = JSON.parse_string(text)
		if msg is Dictionary:
			_handle(msg)


func _handle(msg: Dictionary) -> void:
	match msg.get("type", ""):
		"room_created":
			is_host = true
			room_code = msg.get("roomCode", "")
			players = [player_name]
			print("[NetworkManager] room created: %s" % room_code)
			emit_signal("room_created", room_code)
		"room_joined":
			is_host = false
			room_code = msg.get("roomCode", "")
			player_id = msg.get("playerId", player_name)
			if player_id not in players:
				players.append(player_id)
			print("[NetworkManager] joined room: %s as %s" % [room_code, player_id])
			emit_signal("room_joined", room_code, player_id)
		"player_joined":
			var pid: String = msg.get("playerId", "")
			if pid not in players:
				players.append(pid)
			emit_signal("player_joined", pid)
		"player_left":
			var pid: String = msg.get("playerId", "")
			players.erase(pid)
			emit_signal("player_left", pid)
		"host_disconnected":
			emit_signal("host_disconnected")
		"broadcast":
			emit_signal("message_received", msg.get("from", ""), msg.get("payload", {}))
		"to_host":
			emit_signal("message_received", msg.get("from", ""), msg.get("payload", {}))
		"error":
			var err_code: String = msg.get("error", "")
			push_warning("[NetworkManager] relay error: %s" % err_code)
			if err_code in ["room_not_found", "room_exists"]:
				emit_signal("join_failed", err_code)


func _send(obj: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))


func _disconnect_ws() -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	_connected = false
	_ws_state = WebSocketPeer.STATE_CLOSED


# R13: trim nickname to 16 chars, strip leading/trailing whitespace.
func _sanitize_name(raw: String) -> String:
	var s := raw.strip_edges().left(16)
	return s if not s.is_empty() else "Player"


# R12: clamp incoming remote input to valid ranges so a modified client
# cannot inject out-of-range forces on the host.
func sanitize_input(input: Dictionary) -> Dictionary:
	return {
		"accel":      clampf(float(input.get("accel",      0.0)), 0.0,  1.0),
		"brake":      clampf(float(input.get("brake",      0.0)), 0.0,  1.0),
		"steer":      clampf(float(input.get("steer",      0.0)), -1.0, 1.0),
		"drift":      bool(input.get("drift",      false)),
		"use_powerup":bool(input.get("use_powerup", false)),
	}
