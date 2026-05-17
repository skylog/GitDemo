extends Node

# Sprint 3: lap counting, position calc, respawn transform.
# Reference: GDD §10.2.

const TOTAL_LAPS: int = 3
const POSITION_UPDATE_INTERVAL: float = 0.5

var karts: Array = []
var finish_order: Array = []
var _pos_timer: float = 0.0
var _checkpoint_world_positions: Array[Vector3] = []

func _ready() -> void:
	print("[RaceManager] autoload ready, TOTAL_LAPS = ", TOTAL_LAPS)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.RACE_ACTIVE:
		return
	_pos_timer += delta
	if _pos_timer >= POSITION_UPDATE_INTERVAL:
		_pos_timer = 0.0
		_recalculate_positions()

func setup(p_karts: Array, p_checkpoint_positions: Array[Vector3]) -> void:
	karts = p_karts
	finish_order = []
	_checkpoint_world_positions = p_checkpoint_positions
	GameManager.karts = p_karts
	print("[RaceManager] setup with %d karts and %d checkpoints" % [karts.size(), _checkpoint_world_positions.size()])

func has_checkpoints() -> bool:
	return not _checkpoint_world_positions.is_empty()

func _recalculate_positions() -> void:
	var racing = karts.filter(func(k): return not k.is_finished)
	racing.sort_custom(func(a, b): return _kart_score(a) > _kart_score(b))
	for i in racing.size():
		racing[i].race_position = finish_order.size() + i + 1

func _kart_score(kart) -> float:
	var lap_score = kart.current_lap * 10000.0
	var cp_score = kart.next_checkpoint_index * 1000.0
	var dist_to_next = 0.0
	if _checkpoint_world_positions.size() > kart.next_checkpoint_index:
		var cp_pos = _checkpoint_world_positions[kart.next_checkpoint_index]
		dist_to_next = kart.global_position.distance_to(cp_pos)
	var dist_score = -dist_to_next
	return lap_score + cp_score + dist_score

func register_kart_finished(kart) -> void:
	kart.is_finished = true
	kart.is_frozen = true
	kart.race_position = finish_order.size() + 1
	finish_order.append(kart)
	print("[RaceManager] %s finished P%d in %.2fs" % [kart.player_name, kart.race_position, kart.total_race_time])
	GameManager.on_kart_finished(kart)

func remove_kart(p_name: String) -> void:
	var to_remove = null
	for k in karts:
		if k.player_name == p_name:
			to_remove = k
			break
	if to_remove == null:
		return
	karts.erase(to_remove)
	finish_order.erase(to_remove)
	GameManager.karts.erase(to_remove)
	print("[RaceManager] removed %s from race" % p_name)
	if karts.is_empty() or GameManager.current_state != GameManager.State.RACE_ACTIVE:
		return
	var still_racing = karts.filter(func(k): return not k.is_finished)
	if still_racing.is_empty():
		GameManager.set_state(GameManager.State.RACE_FINISHED)


func get_respawn_transform(kart) -> Transform3D:
	if _checkpoint_world_positions.is_empty():
		return Transform3D.IDENTITY
	var total = _checkpoint_world_positions.size()
	var prev_cp_index = (kart.next_checkpoint_index - 1 + total) % total
	var next_cp_index = kart.next_checkpoint_index
	var pos = _checkpoint_world_positions[prev_cp_index]
	var look_target = _checkpoint_world_positions[next_cp_index]
	var dir = (look_target - pos).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector3(1, 0, 0)
	var basis = Basis.looking_at(dir, Vector3.UP)
	return Transform3D(basis, pos)
