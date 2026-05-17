class_name Kart
extends RigidBody3D

# Sprint 2 base + Sprint 3 respawn integration with RaceManager.
# No animation (Sprint 7), no network (Sprint 8).
# Reference: GDD §5–6.

# --- CONFIG ---
var config: KartConfig
var player_id: int = 1
var player_name: String = "Player"

# --- CACHED NODE REFS ---
var _camera_arm: SpringArm3D
var _respawn_timer: Timer
var _name_label: Label3D
var _raycasts: Array[RayCast3D]

# --- PHYSICS STATE ---
var current_speed: float = 0.0
var steering_angle: float = 0.0
var is_grounded: bool = false
var is_drifting: bool = false
var drift_direction: int = 0
var prev_speed: float = 0.0

# --- INPUT ---
var input_accel: float = 0.0
var input_brake: float = 0.0
var input_steer: float = 0.0
var input_drift: bool = false
var input_use_powerup: bool = false

# --- RACE STATE ---
var current_lap: int = 0
var next_checkpoint_index: int = 0
var race_position: int = 1
var lap_times: Array[float] = []
var current_lap_time: float = 0.0
var total_race_time: float = 0.0
var is_finished: bool = false
var is_frozen: bool = false

# --- NETWORK (Sprint 8) ---
# is_interpolated = true on client for remote karts (no local physics, lerp from state_tick).
var is_interpolated: bool = false
var _net_input: Dictionary = {}
var _net_states: Array = []
const _NET_INTERP_DELAY := 0.1

# --- HUD CACHE ---
var speed_kmh: int = 0

# --- STUCK DETECTION ---
var _stuck_timer: float = 0.0
const STUCK_THRESHOLD_SPEED: float = 0.1
const STUCK_THRESHOLD_TIME: float = 5.0

func _ready() -> void:
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	can_sleep = false

	_camera_arm = $CameraArm
	_respawn_timer = $RespawnTimer
	_name_label = $NameLabel
	_raycasts = [$RaycastFL, $RaycastFR, $RaycastRL, $RaycastRR]

	_respawn_timer.timeout.connect(_on_respawn_timeout)
	_name_label.text = player_name

	if config == null:
		config = load("res://resources/presets/mario_kart.tres") as KartConfig
	_apply_config_to_camera()

func setup(p_id: int, p_name: String, p_config: KartConfig) -> void:
	player_id = p_id
	player_name = p_name
	config = p_config
	_name_label.text = p_name
	_apply_config_to_camera()

func _apply_config_to_camera() -> void:
	if _camera_arm == null or config == null:
		return
	_camera_arm.spring_length = config.camera_distance
	_camera_arm.position = Vector3(0, config.camera_height, 0)

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_race_timers(delta)
	speed_kmh = int(abs(current_speed) * 3.6)

func _update_camera(delta: float) -> void:
	var lag = 1.0 - config.camera_rotation_lag
	_camera_arm.global_rotation.y = lerp_angle(
		_camera_arm.global_rotation.y,
		global_rotation.y,
		lag * delta * 10.0
	)

func _update_race_timers(delta: float) -> void:
	if is_frozen or is_finished:
		return
	current_lap_time += delta
	total_race_time += delta

func _physics_process(delta: float) -> void:
	if is_frozen:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	if is_interpolated:
		_interpolate_network(delta)
		return

	_read_input()
	_check_grounded()
	_apply_gravity(delta)

	if is_grounded:
		_apply_steering(delta)
		_apply_acceleration(delta)
		_apply_drift(delta)
		_apply_lateral_friction(delta)
		_apply_ground_friction(delta)

	_apply_air_resistance()
	_clamp_speed()

	prev_speed = current_speed
	current_speed = -linear_velocity.dot(global_transform.basis.z)

	_check_fell_off_track()
	_check_stuck(delta)

func _read_input() -> void:
	if not _net_input.is_empty():
		input_accel = float(_net_input.get("accel", 0.0))
		input_brake = float(_net_input.get("brake", 0.0))
		input_steer = float(_net_input.get("steer", 0.0))
		input_drift = bool(_net_input.get("drift", false))
		input_use_powerup = bool(_net_input.get("use_powerup", false))
		return
	var state := InputManager.get_input()
	input_accel = state["accel"]
	input_brake = state["brake"]
	input_steer = state["steer"]
	input_drift = state["drift"]
	input_use_powerup = state["use_powerup"]

func _check_grounded() -> void:
	var hits = 0
	for ray in _raycasts:
		if ray.is_colliding():
			hits += 1
	is_grounded = hits >= 2

func _apply_gravity(_delta: float) -> void:
	if not is_grounded:
		apply_central_force(Vector3.DOWN * 9.8 * config.gravity_multiplier * mass)

func _apply_steering(delta: float) -> void:
	var target_angle = input_steer * deg_to_rad(config.max_steering_angle)
	if is_drifting:
		target_angle *= 1.3
	if abs(input_steer) > 0.05:
		steering_angle = move_toward(steering_angle, target_angle, config.steering_speed * delta)
	else:
		steering_angle = move_toward(steering_angle, 0.0, config.steering_return_speed * delta)
	var turn_amount = current_speed * steering_angle * 0.5
	apply_torque(Vector3(0, -turn_amount, 0))

func _apply_acceleration(_delta: float) -> void:
	var forward = -global_transform.basis.z
	if input_accel > 0.0 and current_speed < config.max_speed:
		apply_central_force(forward * config.acceleration * input_accel)
	if input_brake > 0.0:
		if current_speed > 0.5:
			apply_central_force(-forward * config.brake_force * input_brake)
		elif current_speed > -config.max_reverse_speed:
			apply_central_force(-forward * config.reverse_acceleration * input_brake)

func _apply_drift(_delta: float) -> void:
	var speed = abs(current_speed)
	if input_drift and speed > config.drift_speed_threshold and not is_drifting:
		is_drifting = true
		drift_direction = int(sign(input_steer)) if abs(input_steer) > 0.2 else 1
	if not input_drift:
		is_drifting = false
		drift_direction = 0

func _apply_lateral_friction(_delta: float) -> void:
	var right = global_transform.basis.x
	var lateral_vel = linear_velocity.dot(right)
	var friction = config.lateral_friction
	if is_drifting:
		friction *= (1.0 - config.drift_traction_loss)
	apply_central_force(-right * lateral_vel * friction)

func _apply_ground_friction(_delta: float) -> void:
	if input_accel < 0.05 and input_brake < 0.05:
		var friction_force = -linear_velocity * config.ground_friction * mass
		friction_force.y = 0.0
		apply_central_force(friction_force)

func _apply_air_resistance() -> void:
	var speed = linear_velocity.length()
	apply_central_force(-linear_velocity * config.air_resistance * speed)

func _clamp_speed() -> void:
	var speed = linear_velocity.length()
	if speed > config.max_speed:
		linear_velocity = linear_velocity.normalized() * config.max_speed

func _check_fell_off_track() -> void:
	if global_position.y < -5.0 and _respawn_timer.is_stopped():
		trigger_respawn()

func _check_stuck(delta: float) -> void:
	if abs(current_speed) < STUCK_THRESHOLD_SPEED and not is_frozen:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_THRESHOLD_TIME:
			_stuck_timer = 0.0
			trigger_respawn()
	else:
		_stuck_timer = 0.0

func trigger_respawn() -> void:
	is_frozen = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_respawn_timer.start()

func _on_respawn_timeout() -> void:
	if RaceManager.has_checkpoints():
		var spawn_transform = RaceManager.get_respawn_transform(self)
		global_position = spawn_transform.origin + Vector3(0, 0.5, 0)
		global_rotation = spawn_transform.basis.get_euler()
	else:
		global_position = Vector3(global_position.x, 1.0, global_position.z)
	is_frozen = false

# ── Sprint 8: network sync ───────────────────────────────────────────────────

func get_network_state() -> Dictionary:
	return {
		"id":            player_name,
		"pos":           [global_position.x, global_position.y, global_position.z],
		"rot":           [global_rotation.x, global_rotation.y, global_rotation.z],
		"vel":           [linear_velocity.x, linear_velocity.y, linear_velocity.z],
		"speed_kmh":     speed_kmh,
		"current_lap":   current_lap,
		"race_position": race_position,
		"next_cp":       next_checkpoint_index,
		"is_finished":   is_finished,
		"total_time":    total_race_time,
	}

func apply_network_state(state: Dictionary) -> void:
	var p := state.get("pos", [0, 0, 0])
	var r := state.get("rot", [0, 0, 0])
	var v := state.get("vel", [0, 0, 0])
	_net_states.append({
		"pos": Vector3(p[0], p[1], p[2]),
		"rot": Vector3(r[0], r[1], r[2]),
		"vel": Vector3(v[0], v[1], v[2]),
		"t":   Time.get_ticks_msec() * 0.001,
	})
	if _net_states.size() > 4:
		_net_states.pop_front()
	speed_kmh             = state.get("speed_kmh",     speed_kmh)
	current_lap           = state.get("current_lap",   current_lap)
	race_position         = state.get("race_position", race_position)
	next_checkpoint_index = state.get("next_cp",       next_checkpoint_index)
	is_finished           = state.get("is_finished",   is_finished)
	total_race_time       = state.get("total_time",    total_race_time)

func apply_remote_input(input: Dictionary) -> void:
	_net_input = input

func _interpolate_network(_delta: float) -> void:
	if _net_states.is_empty():
		return
	if _net_states.size() == 1:
		global_position = _net_states[0]["pos"]
		global_rotation = _net_states[0]["rot"]
		return
	var now := Time.get_ticks_msec() * 0.001 - _NET_INTERP_DELAY
	var s0: Dictionary = _net_states[0]
	var s1: Dictionary = _net_states[-1]
	for i in range(_net_states.size() - 1):
		if _net_states[i + 1]["t"] >= now:
			s0 = _net_states[i]
			s1 = _net_states[i + 1]
			break
	var dt := s1["t"] - s0["t"]
	var alpha := 0.0 if dt < 0.001 else clamp((now - s0["t"]) / dt, 0.0, 1.0)
	global_position = s0["pos"].lerp(s1["pos"], alpha)
	global_rotation = s0["rot"].lerp(s1["rot"], alpha)
	linear_velocity = s0["vel"].lerp(s1["vel"], alpha)
