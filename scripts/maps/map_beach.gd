extends MapBase

# Map 4: Badestrand des Verderbens (The Beachhead)
# Feature: Brühe des Grauens (Deadly Rising Ocean Flood during Aatrox Phase 2)

var is_flooding: bool = false
var flood_water_y: float = 1200.0
var flood_target_y: float = 0.0
var flood_damage_timer: float = 0.0

func _ready() -> void:
	map_id = "map_beach"
	boss_id = "boss_aatrox"
	super._ready()

func start_rising_flood() -> void:
	is_flooding = true
	AudioManager.play_sfx("boss_spawn", 0.9)

func _process(delta: float) -> void:
	if is_flooding:
		flood_water_y = move_toward(flood_water_y, flood_target_y, 20.0 * delta)
		flood_damage_timer += delta

		if flood_damage_timer >= 1.0:
			flood_damage_timer = 0.0
			var players := get_tree().get_nodes_in_group("players")
			for p in players:
				if is_instance_valid(p) and not p.is_downed:
					if p.global_position.y >= flood_water_y:
						DamageSystem.apply_damage({},p,30,false,null,"true")

		queue_redraw()

func _draw() -> void:
	if is_flooding:
		var rect := Rect2(Vector2(-1920, flood_water_y), Vector2(3840, 1920 - flood_water_y))
		draw_rect(rect, Color(0.1, 0.15, 0.35, 0.65))
		draw_line(Vector2(-1920, flood_water_y), Vector2(1920, flood_water_y), Color(0.8, 0.2, 0.2, 0.9), 4.0)
