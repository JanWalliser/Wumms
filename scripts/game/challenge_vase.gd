extends LootCrate
signal objective_destroyed

func _ready() -> void:
	super._ready()
	remove_from_group("crates")
	collision_layer=2
	max_health=60
	current_health=max_health
	sprite.hide()

func _shatter(_attacker: Node2D) -> void:
	if is_broken: return
	is_broken=true
	objective_destroyed.emit()
	queue_free()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-16),Vector2(8,-16),Vector2(6,-7),Vector2(13,3),Vector2(9,15),Vector2(-9,15),Vector2(-13,3),Vector2(-6,-7)]),Color("55b9de"))
	draw_line(Vector2(-9,-16),Vector2(9,-16),Color("ffe49d"),3,true)
	draw_arc(Vector2.ZERO,8,0,PI,16,Color("fff1b2"),2,true)
