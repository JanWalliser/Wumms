extends SceneTree

## Run this external script against --main-pack to verify packaged bytes, not source.
var failures := 0
var count := 0
var source_root := ""

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Expected absolute source project directory after --")
		quit(1)
		return
	source_root = arguments[0].trim_suffix("/")
	compare("project.godot")
	for directory in ["scripts","scenes","assets"]: compare_directory(directory)
	print("PACK BYTES: ",count," files compared, ",failures," mismatches")
	quit(0 if failures==0 else 1)

func compare(path: String) -> void:
	count += 1
	if not FileAccess.file_exists("res://"+path) or FileAccess.get_file_as_bytes("res://"+path)!=FileAccess.get_file_as_bytes(source_root+"/"+path):
		failures += 1
		push_error("Pack is missing or outdated: "+path)

func compare_directory(path: String) -> void:
	for file in DirAccess.get_files_at(source_root+"/"+path): compare(path+"/"+file)
	for directory in DirAccess.get_directories_at(source_root+"/"+path):
		if not directory.begins_with("."): compare_directory(path+"/"+directory)
