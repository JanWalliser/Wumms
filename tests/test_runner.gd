extends SceneTree

# Initialize autoloads before compiling game-dependent test scenes.
func _init() -> void:
	call_deferred("_launch")

func _launch() -> void:
	change_scene_to_file("res://tests/data_suite.tscn")
