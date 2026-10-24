extends RefCounted

# StatusEffectSystem - Handles timed status effects: Bleed, Burn, Freeze, Stun, Slow, Invulnerability

class_name StatusEffectSystem

# Dictionary of active effects:
# effect_name -> { "duration": float, "power": float, "tick_timer": float, "source": Node2D }
var _active_effects: Dictionary = {}
var host_entity: Node2D = null

func _init(entity: Node2D = null) -> void:
	host_entity = entity

func apply_effect(effect_name: String, duration: float, power: float = 1.0, source: Node2D = null) -> void:
	if _active_effects.has(effect_name):
		# Refresh duration if new duration is longer
		_active_effects[effect_name]["duration"] = maxf(_active_effects[effect_name]["duration"], duration)
		if power >= float(_active_effects[effect_name]["power"]):
			_active_effects[effect_name]["power"] = power
			_active_effects[effect_name]["source"] = source
	else:
		_active_effects[effect_name] = {
			"duration": duration,
			"power": power,
			"tick_timer": 0.0,
			"source": source
		}

func update(delta: float) -> void:
	var expired_keys: Array[String] = []

	for effect_name in _active_effects.keys():
		var data: Dictionary = _active_effects[effect_name]
		data["duration"] -= delta

		# Tick damage effects (Bleed, Burn)
		if effect_name == "bleed" or effect_name == "burn":
			data["tick_timer"] += maxf(0.0, minf(delta,float(data["duration"])+delta))
			while data["tick_timer"] >= 0.5: # Tick every 0.5s
				data["tick_timer"] -= 0.5
				var tick_dmg := float(data["power"])
				if host_entity and host_entity.has_method("take_hit"):
					var source = data.get("source", null)
					var stats = {"damage_multiplier":source.get_stat("damage_multiplier",1),"status":effect_name} if is_instance_valid(source) and source.has_method("get_stat") else {"status":effect_name}
					DamageSystem.apply_damage(stats,host_entity,tick_dmg,false,source if is_instance_valid(source) else null,"physical",1)
					if host_entity.current_health <= 0: break

		if data["duration"] <= 0.0:
			expired_keys.append(effect_name)

	for key in expired_keys:
		_active_effects.erase(key)

func has_effect(effect_name: String) -> bool:
	return _active_effects.has(effect_name)

func is_stunned_or_frozen() -> bool:
	return has_effect("stun") or has_effect("freeze")

func get_speed_multiplier() -> float:
	if is_stunned_or_frozen():
		return 0.0
	if has_effect("slow"):
		var slow_power: float = float(_active_effects["slow"].get("power", 0.3))
		return maxf(0.1, 1.0 - slow_power)
	return 1.3 if has_effect("haste") else 1.0

func is_invulnerable() -> bool:
	return has_effect("invulnerable")

func is_untargetable() -> bool:
	return has_effect("untargetable")

func clear_all() -> void:
	_active_effects.clear()

func effect_power(name: String) -> float:
	return float(_active_effects.get(name,{}).get("power",0))
