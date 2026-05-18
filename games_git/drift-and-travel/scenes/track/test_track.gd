extends Node3D

# Tags this track for CheckpointManager discovery, sets cp_index meta on each Area3D.
# Layout: square donut (outer 30×30, inner 22×22), corridor ≈4m wide.
# Direction: clockwise from CP0 → CP1 → CP2 → CP3 → CP4 → CP0.

func _ready() -> void:
	add_to_group("track")
	var checkpoints = $Checkpoints
	for i in checkpoints.get_child_count():
		checkpoints.get_child(i).set_meta("cp_index", i)
