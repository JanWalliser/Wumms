extends RefCounted

# Screen-sized vector frames stay readable when the shared camera fits a team.
static func ratio(current: float, maximum: float) -> float:
	return clampf(current/maxf(1.0,maximum),0,1)

static func _begin(item: Node2D, anchor: Vector2) -> void:
	var canvas_scale := item.get_global_transform_with_canvas().get_scale().abs()
	item.draw_set_transform(anchor,0,Vector2(1.0/maxf(0.01,canvas_scale.x),1.0/maxf(0.01,canvas_scale.y)))

static func player(item: Node2D, anchor: Vector2, level: int, current: float, maximum: float, shield: float, passive: float, active: bool, downed: bool) -> void:
	_begin(item,anchor)
	item.draw_rect(Rect2(-63,-20,126,20),Color("091a21"))
	item.draw_rect(Rect2(-63,-20,126,20),Color("789b9c"),false,1)
	item.draw_rect(Rect2(-61,-18,20,16),Color("123345"))
	item.draw_string(ThemeDB.fallback_font,Vector2(-61,-5),str(level),HORIZONTAL_ALIGNMENT_CENTER,20,12,Color("e7f5df"))
	item.draw_rect(Rect2(-38,-16,98,11),Color("071408"))
	item.draw_rect(Rect2(-38,-16,98*ratio(current,maximum),11),Color("727777") if downed else Color("63bf3b"))
	for index in range(1,10):
		item.draw_line(Vector2(-38+index*9.8,-16),Vector2(-38+index*9.8,-5),Color(0,0,0,0.35),1)
	if shield>0: item.draw_rect(Rect2(-38,-4,98*ratio(shield,maximum),2),Color("78d3ef"))
	if passive>=0:
		item.draw_rect(Rect2(-38,2,98,3),Color("071a25"))
		item.draw_rect(Rect2(-38,2,98*clampf(passive,0,1),3),Color("ff94dc") if active else Color("73dce8"))
	item.draw_set_transform(Vector2.ZERO)

static func boss(item: Node2D, anchor: Vector2, current: float, maximum: float) -> void:
	var screen := Rect2(Vector2.ZERO,item.get_viewport_rect().size)
	var sprite: Sprite2D=item.sprite
	if not screen.intersects(sprite.get_global_transform_with_canvas()*sprite.get_rect()): return
	var transform := item.get_global_transform_with_canvas()
	var visible_anchor := transform*anchor
	visible_anchor=visible_anchor.clamp(Vector2(98,46),screen.end-Vector2(98,8))
	anchor=transform.affine_inverse()*visible_anchor
	_begin(item,anchor)
	var frame := PackedVector2Array([Vector2(-94,-17),Vector2(-88,-22),Vector2(88,-22),Vector2(94,-17),Vector2(90,-1),Vector2(6,-1),Vector2(0,4),Vector2(-6,-1),Vector2(-90,-1)])
	item.draw_colored_polygon(frame,Color("a78d4a"))
	item.draw_rect(Rect2(-88,-18,176,13),Color("090d12"))
	item.draw_rect(Rect2(-86,-16,172*ratio(current,maximum),9),Color("cf3438"))
	item.draw_string_outline(ThemeDB.fallback_font,Vector2(-70,-27),str(ceili(maxf(0,current))),HORIZONTAL_ALIGNMENT_CENTER,140,13,3,Color("060d16"))
	item.draw_string(ThemeDB.fallback_font,Vector2(-70,-27),str(ceili(maxf(0,current))),HORIZONTAL_ALIGNMENT_CENTER,140,13,Color("fff1cc"))
	item.draw_set_transform(Vector2.ZERO)
