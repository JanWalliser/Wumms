extends MapBase

# Map 3: Untergrund-Laberatorium (Subterranean Lab)
# Feature: Tiefkühl-Tofu-Torpedo (Freeze Platforms)

var pad_positions: Array[Vector2] = [Vector2(-400, 0), Vector2(400, 0)]
var pad_charges: Array[float] = [0.0, 0.0]
var pad_cooldowns: Array[float] = [0.0, 0.0]
var pad_radius: float = 110.0

func _ready() -> void:
	map_id = "map_lab"
	boss_id = "boss_belveth"
	super._ready()

func _process(delta: float) -> void:
	for i in range(pad_positions.size()):
		if pad_cooldowns[i] > 0.0:
			pad_cooldowns[i] -= delta
			continue

		var p_pos := pad_positions[i]
		var player_on_pad := false
		var players := get_tree().get_nodes_in_group("players")
		for p in players:
			if is_instance_valid(p) and not p.is_downed:
				if p.global_position.distance_to(p_pos) <= pad_radius:
					player_on_pad = true
					break

		if player_on_pad:
			pad_charges[i] += 50.0 * delta
			if pad_charges[i] >= 100.0:
				_activate_freeze_pad(i)
		else:
			pad_charges[i] = maxf(0.0, pad_charges[i] - 25.0 * delta)

	queue_redraw()

func _activate_freeze_pad(pad_idx: int) -> void:
	pad_charges[pad_idx] = 0.0
	pad_cooldowns[pad_idx] = 40.0
	var pos := pad_positions[pad_idx]

	AudioManager.play_sfx("card", 0.8)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= 650.0:
			if e.has_method("apply_status_effect"):
				QuestManager.notify_event("lab_enemy_frozen",1)
				e.apply_status_effect("freeze", 4.0, 1.0, null)
				e.take_hit(120.0, false, null)

func _draw() -> void:
	for i in range(pad_positions.size()):
		var pos := pad_positions[i]
		draw_string(ThemeDB.fallback_font,pos+Vector2(-90,-140),"Frost: %.0fs" % pad_cooldowns[i] if pad_cooldowns[i]>0 else "Frost: %.0f%%" % pad_charges[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
		var col := Color(0.4, 0.85, 1.0, 0.35)
		if pad_cooldowns[i] > 0.0:
			col = Color(0.3, 0.4, 0.5, 0.2)
		elif pad_charges[i] > 0.0:
			col = Color(0.6, 0.95, 1.0, 0.4 + (pad_charges[i] / 100.0) * 0.4)

		draw_circle(pos, pad_radius, col)
		draw_arc(pos, pad_radius, 0, TAU, 32, Color(0.5, 0.9, 1.0, 0.8), 3.0)
