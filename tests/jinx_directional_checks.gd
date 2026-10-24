extends RefCounted

const Animator = preload("res://scripts/characters/actor_animator.gd")
const FX = preload("res://scripts/combat/animated_fx.gd")

static func run(player: Node2D, suite: Node) -> void:
	var anim = player.visual_animator
	var origin: Vector2 = player.global_position
	for index in 8:
		var direction := Vector2.from_angle(index*PI/4)
		anim.recoil=0
		anim.update(0.12,true,direction)
		suite.check(anim.facing_sector==index and anim.animation=="walk_"+Animator.DIRECTIONS[index],"walk follows actual movement in sector "+str(index))
		var held: String = anim.animation
		anim.update(0.1,false,Vector2.ZERO)
		suite.check(anim.animation==held.replace("walk_","idle_"),"stopping keeps the last direction "+str(index))
		for frame in 4:
			anim.recoil=0
			var muzzle: Vector2 = player.begin_primary_shot(direction)
			anim.fire_clock=frame/24.0
			anim.update(0,false,Vector2.ZERO)
			suite.check(anim.animation=="shoot_"+Animator.DIRECTIONS[index] and anim.frame_index==frame,"separate shooting pose for direction/frame "+str(index)+"/"+str(frame))
			muzzle=anim.muzzle_position()
			var projected_offset: Vector2=(muzzle-origin)*preload("res://scripts/maps/world_projection.gd").ground_scale()
			suite.check(muzzle.is_finite() and projected_offset.length()>1 and projected_offset.length()<63,"muzzle is on the enlarged painted weapon, not actor center")
			var gun := WeaponInstance.new("weapon_meow_meow",player)
			var target := origin+direction*300
			gun._queue_shot(0,direction,20,1,700,0.4,"meow",{"aim_point":target})
			var shots: Array = suite.owned_projectiles(player)
			var shot = shots.back()
			suite.check(shot.initial_pos.is_equal_approx(anim.muzzle_position()),"automatic projectile starts at current muzzle")
			suite.check(shot.direction.is_equal_approx((target-shot.initial_pos).normalized()),"aim compensates muzzle offset")
			suite.check(shot.damage==20 and gun.get_projectiles()==3,"visual bullets do not multiply damage or projectile count")
			suite.clear_combat()
	anim.recoil=0
	anim.update(0,true,Vector2.UP)
	anim.attack(Vector2.LEFT)
	suite.check(anim.facing_sector==4 and anim.animation=="shoot_e" and player.sprite.flip_h,"shooting direction overrides movement while firing")
	anim.update(0.2,true,Vector2.UP)
	suite.check(anim.facing_sector==6 and anim.animation=="walk_n","movement facing resumes after shooting")
	var clock: float = anim.fire_clock
	anim.attack(Vector2.RIGHT)
	clock=anim.fire_clock
	anim.update(1,false,Vector2.ZERO,true)
	suite.check(anim.fire_clock==clock and anim.recoil==0.14,"stun cannot advance the firing animation")
	for kind in ["jinx_round","jinx_muzzle","jinx_hit"]:
		suite.check(FX.texture(kind,0)!=FX.texture(kind,0.05),"unique automatic attack animation "+kind)
	anim.recoil=0
	anim.update(0,false,Vector2.RIGHT)
