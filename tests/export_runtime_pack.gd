extends SceneTree

## Portable development pack using the installed editor binary as game runtime.
## Does not require editor UI/theme initialization or release export templates.
var packer := PCKPacker.new()
var count := 0
var classes: Array[Dictionary] = []
var class_regex := RegEx.new()
var base_regex := RegEx.new()

func _initialize() -> void:
	class_regex.compile("(?m)^class_name\\s+(\\w+)")
	base_regex.compile("(?m)^extends\\s+(\\w+)")
	var error := packer.pck_start("res://build/WUMMS.pck")
	if error != OK:
		push_error("Cannot create development pack: "+str(error))
		quit(1)
		return
	if not add_file("project.godot"):
		return
	for directory in ["scripts","scenes","assets"]:
		if not add_directory(directory):
			return
	# Generate type metadata from source so this also works with no editor cache.
	classes.sort_custom(func(a: Dictionary,b: Dictionary): return str(a["class"])<str(b["class"]))
	var class_cache := ConfigFile.new()
	class_cache.set_value("","list",classes)
	var generated_path := "res://output/repair/runtime_global_script_class_cache.cfg"
	if class_cache.save(generated_path)!=OK or packer.add_file("res://.godot/global_script_class_cache.cfg",generated_path)!=OK:
		push_error("Cannot generate runtime script type metadata")
		quit(1)
		return
	count += 1
	if FileAccess.file_exists("res://.godot/uid_cache.bin") and not add_file(".godot/uid_cache.bin"):
		return
	if packer.flush() != OK:
		push_error("Cannot finalize development pack")
		quit(1)
		return
	print("RUNTIME PACK COMPLETE: ",count," files")
	quit()

func add_file(path: String) -> bool:
	var error := packer.add_file("res://"+path,"res://"+path)
	if error != OK:
		push_error("Cannot pack "+path+": "+str(error))
		quit(1)
		return false
	count += 1
	if path.ends_with(".gd"):
		var source := FileAccess.get_file_as_string("res://"+path)
		var named := class_regex.search(source)
		var base := base_regex.search(source)
		if named and base:
			classes.append({"base":StringName(base.get_string(1)),"class":StringName(named.get_string(1)),"icon":"","is_abstract":false,"is_tool":false,"language":&"GDScript","path":"res://"+path})
	return true

func add_directory(path: String) -> bool:
	for file in DirAccess.get_files_at("res://"+path):
		if not add_file(path+"/"+file): return false
	for child in DirAccess.get_directories_at("res://"+path):
		if not child.begins_with(".") and not add_directory(path+"/"+child): return false
	return true
