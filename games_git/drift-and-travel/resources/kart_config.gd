class_name KartConfig
extends Resource

# All physics, camera, and animation thresholds for a kart.
# Numeric values come from presets in resources/presets/*.tres — never hardcode.
# Reference: GDD §4. Layout matches the .tres files literally.

# --- ACCELERATION ---
@export var acceleration: float           # Forward force (N)
@export var brake_force: float            # Braking force (N)
@export var reverse_acceleration: float   # Reverse force (N)

# --- SPEED ---
@export var max_speed: float              # Max forward speed (m/s)
@export var max_reverse_speed: float      # Max reverse speed (m/s)

# --- STEERING ---
@export var steering_speed: float         # Steering angle change rate (rad/s)
@export var max_steering_angle: float     # Max wheel turn (degrees)
@export var steering_return_speed: float  # Return-to-center speed

# --- DRIFT ---
@export var drift_factor: float           # 0.0 = no drift, 1.0 = full ice
@export var drift_traction_loss: float    # Lateral friction multiplier when drifting
@export var drift_speed_threshold: float  # Min speed (m/s) required to drift

# --- FRICTION ---
@export var ground_friction: float        # Base friction coefficient
@export var lateral_friction: float       # Side friction (resists sliding)
@export var air_resistance: float         # Speed-dependent drag coefficient

# --- GRAVITY ---
@export var gravity_multiplier: float     # Multiplier on Godot default gravity (9.8 m/s²)

# --- CAMERA ---
@export var camera_distance: float        # SpringArm3D spring_length (m)
@export var camera_height: float          # SpringArm3D position.y offset (m)
@export var camera_lag: float             # Rotation lag factor (0.0=instant, 0.5=very slow)
@export var camera_rotation_lag: float    # Camera rotation lag

# --- ANIMATION THRESHOLDS ---
@export var anim_push_slow_max_speed: float
@export var anim_push_fast_min_speed: float
@export var anim_glide_min_speed: float
@export var anim_brake_speed_drop: float
