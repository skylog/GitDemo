extends CanvasLayer

# Sprint 10: Live physics configurator. F1 toggle, F2/F3 presets.
# Builds all UI programmatically. Host-only in network play.
# Reference: GDD §13.

signal config_applied(config_json: String)

const MARIO_PRESET  := "res://resources/presets/mario_kart.tres"
const KRAFT_PRESET  := "res://resources/presets/kart_kraft.tres"

const _SLIDERS: Array = [
	{ "node": "AccelerationSlider",    "prop": "acceleration",             "min": 5.0,  "max": 40.0,  "step": 0.5   },
	{ "node": "BrakeForceSlider",      "prop": "brake_force",              "min": 5.0,  "max": 50.0,  "step": 0.5   },
	{ "node": "MaxSpeedSlider",        "prop": "max_speed",                "min": 10.0, "max": 40.0,  "step": 0.5   },
	{ "node": "SteeringSpeedSlider",   "prop": "steering_speed",           "min": 1.0,  "max": 6.0,   "step": 0.1   },
	{ "node": "MaxSteeringAngleSlider","prop": "max_steering_angle",       "min": 10.0, "max": 45.0,  "step": 1.0   },
	{ "node": "SteeringReturnSlider",  "prop": "steering_return_speed",    "min": 1.0,  "max": 10.0,  "step": 0.1   },
	{ "node": "DriftFactorSlider",     "prop": "drift_factor",             "min": 0.0,  "max": 1.0,   "step": 0.01  },
	{ "node": "DriftTractionSlider",   "prop": "drift_traction_loss",      "min": 0.0,  "max": 1.0,   "step": 0.01  },
	{ "node": "DriftThresholdSlider",  "prop": "drift_speed_threshold",    "min": 3.0,  "max": 20.0,  "step": 0.5   },
	{ "node": "GroundFrictionSlider",  "prop": "ground_friction",          "min": 0.1,  "max": 1.0,   "step": 0.01  },
	{ "node": "LateralFrictionSlider", "prop": "lateral_friction",         "min": 1.0,  "max": 20.0,  "step": 0.5   },
	{ "node": "AirResistanceSlider",   "prop": "air_resistance",           "min": 0.0,  "max": 0.1,   "step": 0.001 },
	{ "node": "GlideSpeedSlider",      "prop": "anim_glide_min_speed",     "min": 5.0,  "max": 25.0,  "step": 0.5   },
	{ "node": "PushFastSpeedSlider",   "prop": "anim_push_slow_max_speed", "min": 2.0,  "max": 15.0,  "step": 0.5   },
	{ "node": "CameraDistanceSlider",  "prop": "camera_distance",          "min": 3.0,  "max": 10.0,  "step": 0.1   },
	{ "node": "CameraHeightSlider",    "prop": "camera_height",            "min": 1.0,  "max": 5.0,   "step": 0.1   },
	{ "node": "CameraLagSlider",       "prop": "camera_rotation_lag",      "min": 0.0,  "max": 0.5,   "step": 0.01  },
]

var _config: KartConfig
var _karts: Array = []
var _vbox: VBoxContainer


func _ready() -> void:
	layer = 20
	_build_ui()
	hide()


func setup(p_config: KartConfig, p_karts: Array) -> void:
	_config = p_config
	_karts = p_karts
	_populate_sliders()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left    = 1.0
	panel.anchor_right   = 1.0
	panel.anchor_top     = 0.0
	panel.anchor_bottom  = 1.0
	panel.offset_left    = -400.0
	panel.offset_right   = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	var title := Label.new()
	title.text = "PHYSICS PANEL — F1 close | F2 Mario | F3 Kraft"
	title.add_theme_font_size_override("font_size", 13)
	_vbox.add_child(title)
	_vbox.add_child(HSeparator.new())

	for def in _SLIDERS:
		_add_slider_row(def)

	_vbox.add_child(HSeparator.new())
	_add_buttons()


func _add_slider_row(def: Dictionary) -> void:
	var row := HBoxContainer.new()
	_vbox.add_child(row)

	var lbl := Label.new()
	lbl.text = def["prop"]
	lbl.custom_minimum_size = Vector2(190, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.name = def["node"]
	slider.min_value = def["min"]
	slider.max_value = def["max"]
	slider.step = def["step"]
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.name = def["node"].replace("Slider", "ValueLabel")
	val_lbl.custom_minimum_size = Vector2(55, 0)
	val_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(val_lbl)


func _add_buttons() -> void:
	for pair in [
		["Apply All",   "_on_apply_all_pressed"],
		["Mario Kart",  "_on_preset_mario_pressed"],
		["Kart Kraft",  "_on_preset_kraft_pressed"],
		["Export JSON", "_on_export_pressed"],
	]:
		var btn := Button.new()
		btn.text = pair[0]
		btn.pressed.connect(Callable(self, pair[1]))
		_vbox.add_child(btn)


func _populate_sliders() -> void:
	if _config == null:
		return
	for def in _SLIDERS:
		var slider: HSlider = find_child(def["node"])
		if slider == null:
			continue
		slider.value = _config.get(def["prop"])
		if slider.value_changed.is_connected(_on_slider_changed):
			slider.value_changed.disconnect(_on_slider_changed)
		var prop: String = def["prop"]
		slider.value_changed.connect(func(val): _on_slider_changed(prop, val))
		_update_value_label(def["node"], slider.value)


func _on_slider_changed(property: String, value: float) -> void:
	if _config == null:
		return
	_config.set(property, value)
	for def in _SLIDERS:
		if def["prop"] == property:
			_update_value_label(def["node"], value)
			break


func _update_value_label(slider_node: String, value: float) -> void:
	var lbl: Label = find_child(slider_node.replace("Slider", "ValueLabel"))
	if lbl:
		lbl.text = "%.3f" % value


func _on_apply_all_pressed() -> void:
	if _config == null:
		return
	for kart in _karts:
		if is_instance_valid(kart):
			kart.config = _config.duplicate()
			kart._apply_config_to_camera()
	var json_str := _export_json()
	emit_signal("config_applied", json_str)
	print("[PhysicsPanel] applied to %d karts" % _karts.size())


func _on_preset_mario_pressed() -> void:
	_config = load(MARIO_PRESET).duplicate()
	_populate_sliders()


func _on_preset_kraft_pressed() -> void:
	_config = load(KRAFT_PRESET).duplicate()
	_populate_sliders()


func _on_export_pressed() -> void:
	print("[PhysicsPanel] ", _export_json())


func _export_json() -> String:
	if _config == null:
		return "{}"
	var data := {}
	for prop in _config.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[prop["name"]] = _config.get(prop["name"])
	return JSON.stringify(data, "\t")
