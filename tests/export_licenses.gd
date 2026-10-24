extends SceneTree

func _init() -> void:
	var file = FileAccess.open("res://build/LICENSES_GODOT.txt",FileAccess.WRITE)
	if not file:
		quit(1)
		return
	file.store_string(Engine.get_license_text()+"\n\nThird-party notices\n\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(),"\t"))
	file.store_string("\n\nThird-party licenses\n\n")
	file.store_string(JSON.stringify(Engine.get_license_info(),"\t"))
	file.close()
	quit()
