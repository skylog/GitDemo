extends Node

# Sprint 9: Race sync + Disconnect handling.
# Adds to Sprint 8: results broadcast, player_left kart removal.
# Gate: 4-player full match, client dropout does not break others.
# Main Scene = res://scenes/_sprint9_test.tscn, F5.
# Requires: cd relay && npm install && node relay.js

const KART_SCENE := preload("res://scenes/kart/kart.tscn")
const MARIO      := preload("res://resources/presets/mario_kart.tres")

const STATE_HZ := 20.0
const INPUT_HZ := 30.0

var _karts: Dictionary = {}   # player_name -> Kart
var _local_kart: Kart = null
var _is_host: bool = false
var _state_timer: float = 0.0
var _input_timer: float = 0.0


func _ready() -> void:
	$CountdownUI.countdown_finished.connect(GameManager.on_countdown_finished)
	NetworkManager.host_disconnected.connect(GameManager.go_to_menu)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.message_received.connect(_on_net_msg)
	GameManager.state_changed.connect(_on_state)
	GameManager.set_state(GameManager.State.MENU)
	print("[Sprint9Test] ready")


func _on_state(state: int) -> void:
	match state:
		GameManager.State.RACE_COUNTDOWN:
			_spawn_karts()
			$HUD.setup(_local_kart, NetworkManager.player_name, _karts.values())
			$CountdownUI.start()
		GameManager.State.RESULTS:
			$ResultsUI.show_results(RaceManager.finish_order)
			if _is_host:
				var names: Array = []
				for k in RaceManager.finish_order:
					names.append(k.player_name)
				NetworkManager.broadcast({
					"type": "race_state",
					"state": "results",
					"finish_order": names
				})


func _spawn_karts() -> void:
	_is_host = NetworkManager.is_host
	_karts.clear()
	for child in $KartsRoot.get_children():
		child.queue_free()

	CheckpointManager.bind_track()
	var cp_positions: Array[Vector3] = []
	for cp in $TestTrack.get_node("Checkpoints").get_children():
		cp_positions.append(cp.global_position)

	var spawns := $TestTrack.get_node("SpawnPoints").get_children()
	var idx := 0
	var all_karts: Array = []
	for pid in NetworkManager.players:
		var kart: Kart = KART_SCENE.instantiate()
		$KartsRoot.add_child(kart)
		kart.setup(idx + 1, pid, MARIO.duplicate())
		if idx < spawns.size():
			kart.global_transform = spawns[idx].global_transform
		idx += 1
		kart.is_interpolated = (pid != NetworkManager.player_name) and not _is_host
		_karts[pid] = kart
		all_karts.append(kart)

	RaceManager.setup(all_karts, cp_positions)
	_local_kart = _karts.get(NetworkManager.player_name)
	print("[Sprint9Test] spawned %d karts, host=%s" % [all_karts.size(), str(_is_host)])


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.RACE_ACTIVE:
		return
	if _is_host:
		_state_timer += delta
		if _state_timer >= 1.0 / STATE_HZ:
			_state_timer = 0.0
			_broadcast_state()
	else:
		_input_timer += delta
		if _input_timer >= 1.0 / INPUT_HZ:
			_input_timer = 0.0
			NetworkManager.send_to_host({
				"type":  "input_tick",
				"input": InputManager.get_input()
			})


func _broadcast_state() -> void:
	var states: Array = []
	for pid in _karts:
		states.append(_karts[pid].get_network_state())
	NetworkManager.broadcast({ "type": "state_tick", "karts": states })


func _on_player_left(pid: String) -> void:
	print("[Sprint9Test] player left: %s" % pid)
	if not _karts.has(pid):
		return
	var kart: Kart = _karts[pid]
	_karts.erase(pid)
	if _is_host:
		RaceManager.remove_kart(pid)
	kart.queue_free()


func _on_net_msg(from: String, payload: Dictionary) -> void:
	match payload.get("type", ""):
		"state_tick":
			if not _is_host:
				for s in payload.get("karts", []):
					var pid: String = s.get("id", "")
					if pid != NetworkManager.player_name and _karts.has(pid):
						_karts[pid].apply_network_state(s)
		"input_tick":
			if _is_host and _karts.has(from):
				_karts[from].apply_remote_input(payload.get("input", {}))
		"race_state":
			if not _is_host:
				_apply_race_state(payload)


func _apply_race_state(payload: Dictionary) -> void:
	if payload.get("state", "") == "results":
		var names: Array = payload.get("finish_order", [])
		var ordered: Array = []
		for n in names:
			if _karts.has(n):
				ordered.append(_karts[n])
		RaceManager.finish_order = ordered
		GameManager.set_state(GameManager.State.RESULTS)
