extends SceneTree

func _initialize() -> void:
	var probe = load("res://tests/lan_probe.gd").new()
	probe.name = "LanProbe"
	root.add_child.call_deferred(probe)
