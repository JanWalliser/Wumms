extends Area2D

# DropItem - Collectible pickups: EXP Gems, Gold, Health, Access Cards, Vacuum, Bombs

class_name DropItem

const ACCESS_CARD_WIDTH := 160.0
const ACCESS_CARD_AURA_RADIUS := 150.0
const BOMB_RADIUS := 600.0*0.2 # Original reference radius converted to this game's world units.

enum ItemType {
	EXP_ORB,
	GOLD,
	HEALTH_PACK,
	ACCESS_CARD,
	VACUUM,
	BOMB
}

@export var item_type: ItemType = ItemType.EXP_ORB
@export var value: int = 5

var collected := false
var target_player: Node2D = null
var magnet_speed: float = 300.0
var is_attracted: bool = false
var attraction_reason := "Aufnahme"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	collision_layer = 8 # Pickups layer
	collision_mask = 1  # Players layer
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_visuals()

func setup(type: ItemType, val: int = 5) -> void:
	item_type = type
	value = val
	_update_visuals()

func _update_visuals() -> void:
	if not sprite:
		return
	if item_type==ItemType.ACCESS_CARD and not collected:
		add_to_group("access_cards")
	else:
		remove_from_group("access_cards")
	queue_redraw()
	var tex_id := "exp_orb"
	match item_type:
		ItemType.EXP_ORB: tex_id = "exp_orb"
		ItemType.GOLD: tex_id = "gold"
		ItemType.HEALTH_PACK: tex_id = "health_pack"
		ItemType.ACCESS_CARD: tex_id = "access_card"
		ItemType.VACUUM: tex_id = "vacuum"
		ItemType.BOMB: tex_id = "bomb"
	sprite.texture = AssetRegistry.get_pickup_texture(tex_id)
	sprite.visible = item_type!=ItemType.BOMB
	if item_type == ItemType.ACCESS_CARD:
		sprite.texture = load("res://assets/ui/swarm/access-card.res")
		sprite.scale = Vector2.ONE * ACCESS_CARD_WIDTH / sprite.texture.get_width()
	elif item_type == ItemType.EXP_ORB:
		sprite.texture = AssetRegistry.get_pickup_texture("exp_orb_gold" if value>=20 else ("exp_orb_purple" if value>=4 else "exp_orb_blue"))
		sprite.scale = Vector2.ONE * 0.55
		sprite.modulate = Color.WHITE
	else:
		sprite.scale = Vector2.ONE * 0.65
		sprite.modulate = Color.WHITE
	sprite.scale.y/=preload("res://scripts/maps/world_projection.gd").ground_scale().y

func _draw() -> void:
	if item_type==ItemType.BOMB and not collected:
		draw_circle(Vector2.ZERO,19,Color("ffd36a",0.12))
		draw_arc(Vector2.ZERO,14,0,TAU,32,Color("ffd36a"),1.5,true)
		var mine := preload("res://scripts/combat/weapon_visuals.gd").companion_texture("mine")
		if mine!=null: draw_texture_rect(mine,Rect2(-12,-12,24,24),false)
		return
	if item_type!=ItemType.ACCESS_CARD or collected: return
	# Soft overlapping disks form a broad golden glow beneath the card artwork.
	for layer in range(24,0,-1):
		var fraction := float(layer)/24.0
		draw_circle(Vector2.ZERO,ACCESS_CARD_AURA_RADIUS*fraction,Color(1.0,0.82,0.18,0.016*(1.0-fraction*0.85)),true,-1.0,true)
	draw_arc(Vector2.ZERO,ACCESS_CARD_AURA_RADIUS*0.62,0,TAU,64,Color(1,0.85,0.3,0.18),1.5,true)

func _physics_process(delta: float) -> void:
	if collected: return
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return
	if is_attracted and is_instance_valid(target_player):
		magnet_speed += 800.0 * delta
		# Clamp travel to the target: accelerating pickups must never overshoot and
		# oscillate around the player indefinitely, especially after a long vacuum pull.
		global_position = global_position.move_toward(target_player.global_position,magnet_speed*delta)
		if global_position.distance_to(target_player.global_position) < 25.0:
			_collect(target_player)

func start_attraction(player: Node2D, reason: String = "Aufnahme") -> void:
	if collected or not is_instance_valid(player) or player.is_downed: return
	if is_attracted and is_instance_valid(target_player) and not target_player.is_downed: return
	target_player = player
	is_attracted = true
	attraction_reason = reason

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		_collect(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitboxes"):
		_collect(area.get_parent())

func _collect(player: Node2D) -> void:
	if collected or GameManager.run_finalized or not is_instance_valid(player) or player.is_downed: return
	collected = true
	# Commit removal before callbacks: explosions can trigger level-ups or destroy
	# targets while the pickup is being consumed. No stale drawing may follow us.
	is_attracted=false
	hide()
	set_physics_process(false)
	queue_free()
	remove_from_group("access_cards")
	set_deferred("monitoring", false)
	match item_type:
		ItemType.EXP_ORB:
			var exp_mult := 1.0
			if player and player.has_method("get_stat"):
				exp_mult = player.get_stat("exp_multiplier", 1.0)
			# Team bonus lives here, not in StatCalculator: apply it exactly once,
			# including when the collector owns it or several teammates have it.
			for teammate in GameManager.active_player_nodes:
				if is_instance_valid(teammate) and teammate.augments.has("augment_experienced_fighter"):
					exp_mult *= 1.1
					break
			if player.augments.has("augment_experienced_fighter"):
				var stacks := int(player.get_meta("xp_fanatic_stacks",0)) if player.temp_buffs.has("xp_fanatic") else 0
				stacks+=1
				player.set_meta("xp_fanatic_stacks",stacks)
				player.apply_temporary_buff("xp_fanatic",4,{"damage_pct":stacks*0.02,"speed_pct":stacks*0.02})
			var total = value*exp_mult+GameManager.exp_carry
			var earned = floori(total)
			GameManager.exp_carry = total-earned
			GameManager.add_team_exp(earned)
			GameManager.experience_collected.emit(earned,attraction_reason)

		ItemType.GOLD:
			var gold_mult := 1.0
			if player and player.has_method("get_stat"):
				gold_mult = player.get_stat("gold_multiplier", 1.0)
			var total = value*gold_mult+GameManager.gold_carry
			var final_val = floori(total)
			GameManager.gold_carry = total-final_val
			GameManager.team_gold_earned += final_val
			if player.augments.has("augment_hoarder"): player.heal(player.get_stat("max_health")*0.005*final_val)
			AudioManager.play_sfx("coin")

		ItemType.HEALTH_PACK:
			for teammate in GameManager.active_player_nodes:
				if is_instance_valid(teammate) and not teammate.is_downed:
					teammate.heal(teammate.get_stat("max_health") * 0.20)
					if teammate.augments.has("augment_regenerative_tissue"):
						var tissue: float = float(teammate.get_meta("tissue_regen",0))+5
						teammate.set_meta("tissue_regen",tissue)
						teammate.apply_temporary_buff("tissue",99999,{"health_regen":tissue})
			AudioManager.play_sfx("heal")

		ItemType.ACCESS_CARD:
			for i in range(value): GameManager.trigger_access_card()

		ItemType.VACUUM:
			QuestManager.notify_event("vacuums_collected",1,true)
			AudioManager.play_sfx("card")
			player.set_meta("vacuum_until",GameManager.game_time+6.0*player.get_stat("duration_multiplier",1.0))
			# Attract both XP and gold, including new drops during the six-second effect.
			var items := get_tree().get_nodes_in_group("pickups")
			for it in items:
				if is_instance_valid(it) and it.item_type in [ItemType.EXP_ORB,ItemType.GOLD]:
					it.start_attraction(player,"Magnet")

		ItemType.BOMB:
			AudioManager.play_sfx("explosion")
			RuntimeEffect.spawn(get_parent(),player,global_position,{"visual":"impact","weapon_id":"pickup_bomb","radius":BOMB_RADIUS,"damage":0,"duration":0.45,"scale_area":false,"scale_duration":false})
			# A local sea-mine pickup, not a map-wide kill/XP cheat.
			var enemies := get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy is Enemy and not enemy.is_boss and not enemy.is_queued_for_deletion() and enemy.global_position.distance_to(global_position)<=BOMB_RADIUS:
					enemy.take_hit(9999.0, true, player)
