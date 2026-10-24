extends RefCounted
class_name SwarmBalance

## Reference-backed values and explicitly labelled clone calibrations.
static var _data: Dictionary = {}
static var _progression_tuning: Dictionary = {}

static func progression_tuning() -> Dictionary:
	if _progression_tuning.is_empty():
		_progression_tuning=JSON.parse_string(FileAccess.get_file_as_string("res://assets/balance/progression-tuning.json"))
	return _progression_tuning

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/balance/swarm-14.16.json"))
	return _data

static func apply(section: String, id: String, original: Dictionary) -> Dictionary:
	var result := original.duplicate(true)
	result.merge(data().get(section, {}).get(id, {}), true)
	return result
