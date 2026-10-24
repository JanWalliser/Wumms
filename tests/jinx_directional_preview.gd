extends Node2D

const Animator = preload("res://scripts/characters/actor_animator.gd")
const FX = preload("res://scripts/combat/animated_fx.gd")
var actors: Array = []

func _ready() -> void:
	AudioManager.music_player.stop()
	AudioManager.sfx_volume=0
	RenderingServer.set_default_clear_color(Color("101c29"))
	for direction in 8:
		var label := Label.new()
		label.text=["Rechts","Rechts unten","Unten","Links unten","Links","Links oben","Oben","Rechts oben"][direction]
		label.position=Vector2(direction*235+35,10)
		add_child(label)
		for frame in 4:
			var sprite := Sprite2D.new()
			add_child(sprite)
			sprite.position=Vector2(120+direction*235,230+frame*220)
			var animation := Animator.new()
			animation.setup(sprite,"jankz",4)
			# setup sets the visual foot offset; move the actor's frame to its grid cell.
			var center := Vector2(120+direction*235,215+frame*220)
			animation.base_position=center
			animation.attack(Vector2.from_angle(direction*PI/4))
			animation.fire_clock=frame/24.0
			animation.update(0,false,Vector2.ZERO)
			actors.append(animation)
	queue_redraw()
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false,1.0/60)
	get_viewport().get_texture().get_image().save_png("res://output/swarm-ui/jinx-eight-directions-muzzle.png")
	actors.clear()
	for child in get_children(): child.queue_free()
	Animator.cache.clear()
	FX.frames=null
	FX.jinx_frames=null
	for frame in 3: await get_tree().process_frame
	get_tree().quit()

func _draw() -> void:
	for actor in actors:
		var muzzle: Vector2 = actor.muzzle_position()
		draw_set_transform(muzzle,actor.fire_direction.angle(),Vector2.ONE)
		FX.draw(self,"jinx_muzzle",actor.fire_clock,Vector2.ZERO,Vector2.ONE*22)
		for index in 3:
			FX.draw(self,"jinx_round",actor.fire_clock+index*0.015,Vector2(35-index*2,(index-1)*3),Vector2(18,11))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		draw_circle(muzzle,3,Color.GREEN)
		draw_line(muzzle,muzzle+actor.fire_direction*25,Color.YELLOW,2)
