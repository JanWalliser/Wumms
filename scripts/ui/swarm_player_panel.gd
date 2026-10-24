extends Control

const Icons = preload("res://scripts/ui/swarm_icons.gd")
const Evolution = preload("res://scripts/progression/evolution_rules.gd")
var player: PlayerController
var _frame: Texture2D
var _hover: Array[Dictionary] = []

func _ready() -> void:
	_frame = load("res://assets/ui/swarm/hud-frame.res")
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(_delta: float) -> void:
	queue_redraw()

func _label(text: String, at: Vector2, font_size: int, color := Color.WHITE, width := -1.0) -> void:
	var scale_factor := maxf(0.1,size.x/640.0)
	var readable_size := roundi(maxf(10.0,font_size*scale_factor)/scale_factor)
	draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_CENTER if width>0 else HORIZONTAL_ALIGNMENT_LEFT,width,readable_size,color)

func _icon(index: int, rect: Rect2, hint: String, level: int = 0, tint := Color.WHITE) -> void:
	draw_texture_rect(Icons.texture(index),rect,false,tint)
	_hover.append({"rect":rect,"hint":hint})
	if level>0:
		for rank in mini(level,5):
			draw_rect(Rect2(rect.position+Vector2(rank*(rect.size.x/5.0),rect.size.y-3),Vector2(rect.size.x/5.0-1,3)),Color("e2c880"))

func _draw() -> void:
	if not is_instance_valid(player) or _frame == null: return
	_hover.clear()
	var s := size.x/640.0
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*s)
	# Crop transparent padding only. The complete circular portrait housing remains intact.
	draw_texture_rect_region(_frame,Rect2(0,32,640,141.44),Rect2(0,112,2172,480))
	var color: Color = ProfileManager.DEFAULT_PLAYER_COLORS[player.player_slot_index%4]
	draw_texture_rect(AssetRegistry.get_character_texture(player.character_id),Rect2(28,56,88,88),false,Color(0.5,0.5,0.5) if player.is_downed else Color.WHITE)
	draw_arc(Vector2(72,100),53,0,TAU,48,color,2,true)
	_label("P%d  %s" % [player.player_slot_index+1,player.char_data.get("display_name", "")],Vector2(148,48),13,color)
	draw_circle(Vector2(72,154),12,Color("101d25"))
	_label(str(GameManager.team_level),Vector2(60,159),12,Color("f0d697"),24)
	for i in 2:
		var cd: float = player.ability_e_cd if i==0 else player.ability_r_cd
		var locked: bool = GameManager.team_level < (3 if i==0 else 6)
		var rect := Rect2(148+i*64,62,50,50)
		var abilities: Array = [Icons.JINX_E,Icons.JINX_R] if player.character_id=="jankz" else Icons.CHARACTER_ABILITIES.get(player.character_id,[32,33])
		_icon(abilities[i],rect,player.char_data.get("ability_e" if i==0 else "ability_r",{}).get("name", ""))
		if locked or cd>0:
			draw_rect(rect,Color(0,0,0,0.65))
			_label(str(3 if i==0 else 6) if locked else "%.0f" % ceilf(cd),rect.position+Vector2(0,33),19,Color.WHITE,50)
		_label("E" if i==0 else "R",rect.position+Vector2(34,48),10)
	for i in 5:
		var rect := Rect2(276+i*64,62,50,50)
		draw_rect(rect,Color("08171e"))
		draw_rect(rect,Color("496169"),false,1)
		if player.weapon_controller and i<player.weapon_controller.equipped_weapons.size():
			var weapon = player.weapon_controller.equipped_weapons[i]
			var state := Evolution.weapon_state(player,weapon.weapon_id)
			_icon(Icons.WEAPONS.get(weapon.weapon_id,0),rect,Evolution.weapon_recipe(player,weapon.weapon_id)+"\n\n"+weapon.stat_summary(),weapon.level,Color(1.1,0.9,1.3) if weapon.is_evolved else Color.WHITE)
			var badge_color := Color("bd8bff") if state["evolved"] else (Color("70f4a1") if state["ready"] else Color("e0b864"))
			if state["ready"] or state["evolved"]: draw_rect(rect.grow(2),badge_color,false,2)
			var badge := "E" if state["evolved"] else ("!" if state["ready"] else ("P" if state["rank"]>=5 else "5"))
			draw_circle(rect.position+Vector2(43,7),9,Color("091820"))
			_label(badge,rect.position+Vector2(34,12),12,badge_color,18)
			if not state["evolved"]:
				draw_texture_rect(Icons.texture(Icons.PASSIVES.get(state["passive"],30)),Rect2(rect.position+Vector2(34,30),Vector2(16,16)),false,Color.WHITE if state["passive_rank"]>=1 else Color(0.5,0.5,0.5))
	var hp_ratio := clampf(player.current_health/maxf(1,player.get_stat("max_health")),0,1)
	draw_rect(Rect2(148,120,434,14),Color("071712"))
	draw_rect(Rect2(148,120,434*hp_ratio,14),Color("309a67"))
	_label("%d / %d" % [player.current_health,player.get_stat("max_health")],Vector2(148,131),11,Color.WHITE,434)
	if player.current_shield>0:
		draw_rect(Rect2(148,136,434*minf(1,player.current_shield/player.get_stat("max_health")),4),Color("58c9ed"))
	var index := 0
	for id in player.passives:
		_icon(Icons.PASSIVES.get(id,30),Rect2(276+index*31,0,26,26),Evolution.passive_tooltip(player,id),player.passives[id])
		index+=1
	for slot in range(player.passives.size(),6):
		var rect := Rect2(276+slot*31,0,26,26)
		draw_rect(rect,Color("08171e"))
		if slot>=player.max_passive_slots:
			_icon(34,rect,"Passivplatz durch Ziele freischalten",0,Color(0.6,0.6,0.7))
		else:
			draw_rect(rect,Color("496169"),false,1)
	for i in player.augments.size():
		_icon(Icons.AUGMENTS.get(player.augments[i],30),Rect2(148+i*31,0,26,26),AugmentRegistry.get_augment_data(player.augments[i]).get("display_name",player.augments[i]))
	if player.is_downed:
		_label("WIEDERBELEBUNG  %.0fs" % player.auto_respawn_timer,Vector2(148,157),14,Color("f7b582"))
	else:
		_label("+%.1f/s" % (player.get_stat("health_regen")/5.0),Vector2(148,154),11,Color("76cda0"))
	if player.character_id=="jankz":
		_icon(Icons.JINX_PASSIVE,Rect2(229,144,17,17),"Aufgedreht: 70 Kills oder ein Elite-Kill")
		var active := player.is_jinx_excited()
		var remaining := player.jinx_passive_remaining()
		var ratio := remaining/8.0 if active else float(player.jinx_kills)/70.0
		var tint := Color("ff94dc") if active else Color("73dce8")
		draw_rect(Rect2(250,146,332,13),Color("091a25"))
		draw_rect(Rect2(250,146,332*clampf(ratio,0,1),13),Color(tint,0.4))
		_label("AUFGEDREHT! %.1fs · +150 Tempo" % remaining if active else "AUFGEDREHT  %d/70 · Elite sofort" % player.jinx_kills,Vector2(250,157),11,tint,332)
		_hover.append({"rect":Rect2(250,145,332,16),"hint":"70 eigene Gegnerkills oder ein Elite-Kill: 8 Sekunden +150 Fähigkeitstempo und abklingender Laufbonus. Erneute Auslösung erneuert die Dauer; Boni stapeln sich nicht."})
	else:
		var passive: Dictionary = player.char_data.get("passive",{})
		var passive_icons: Array = Icons.CHARACTER_ABILITIES.get(player.character_id,[32,33,30])
		_icon(passive_icons[2],Rect2(229,144,17,17),str(passive.get("name",""))+"\n"+str(passive.get("desc","")))
		_label(player.passive_hud_text(),Vector2(250,157),11,Color("d8c69a"),332)

	draw_set_transform(Vector2.ZERO)

func _get_tooltip(at_position: Vector2) -> String:
	var logical := at_position / (size.x/640.0)
	for item in _hover:
		if item["rect"].has_point(logical): return item["hint"]
	return "TAB: Werte und Ausrüstung"

