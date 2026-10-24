extends StaticBody2D
class_name LootCrate

# LootCrate - Destructible container (Krawall-Karton / Beutekiste) scattered in alleys and corners.
# Pods have 100 HP and drop gold, health, vacuums or bombs; never experience.

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies") # Projectiles target group 'enemies'
	add_to_group("crates")
	collision_layer = 2 | 16 # Enemy hit layer (2) and obstacle layer (16)
	collision_mask = 0
	current_health = max_health
	if sprite:
		sprite.texture = AssetRegistry.get_crate_texture()

func receive_damage(amount: float, is_crit: bool, attacker: Node2D = null) -> bool:
	if is_broken or current_health <= 0.0:
		return false

	current_health -= amount
	DamageSystem.spawn_damage_number(global_position + Vector2(randf_range(-10, 10), -20), int(amount), is_crit)

	# Visual hit flash
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(2.0, 1.5, 1.2), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if current_health <= 0.0:
		_shatter(attacker)
		return true

	return false

func _shatter(attacker: Node2D) -> void:
	if is_broken:
		return
	is_broken = true
	QuestManager.notify_event("boxes_destroyed",1,true)
	AudioManager.play_sfx("explosion", 1.2)

	# Allowed drop types follow Swarm. Probabilities are project calibration;
	# exact original weights were not published in the available references.
	var roll := randf()
	var target_parent: Node2D = null
	var parent := get_parent()
	if parent is Node2D:
		target_parent = parent
	elif is_inside_tree() and get_tree().current_scene is Node2D:
		target_parent = get_tree().current_scene

	if target_parent:
		if roll < 0.70:
			DropManager.spawn_gold(target_parent, global_position, randi_range(5, 15))
		elif roll < 0.90:
			DropManager.spawn_health_pack(target_parent, global_position, 150)
		elif roll < 0.97:
			DropManager.spawn_special_pickup(target_parent, global_position, DropItem.ItemType.VACUUM)
		else:
			DropManager.spawn_special_pickup(target_parent, global_position, DropItem.ItemType.BOMB)

	queue_free()
