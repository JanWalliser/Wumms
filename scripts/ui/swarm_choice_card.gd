extends Button

const Icons = preload("res://scripts/ui/swarm_icons.gd")
var choice: Dictionary = {}
var compact := false
var selected := false
var _skin: NinePatchRect
var _icon: TextureRect
var _focus: Panel

static func describe_choice(option: Dictionary, player: PlayerController) -> String:
	var id: String = option.get("id", "")
	if option.get("type", "") in ["new_passive","passive_upgrade"]:
		var increments := {"max_health":[150," HP"],"armor":[8," Rüstung"],"health_regen":[4," HP / 5 s"],"movement_speed":[9," % Tempo"],"crit_chance":[8," % Krit"],"damage":[10," % Schaden"],"ability_haste":[10," Fähigkeitstempo"],"duration":[12," % Dauer"],"area_size":[11," % Fläche"],"exp_gain":[10," % XP"],"pickup_radius":[35," % Sammelradius"]}
		var before: int = player.passives.get(id,0)
		if increments.has(id):
			var units := 100.0 if id in ["movement_speed","crit_chance","damage","duration","area_size","exp_gain","pickup_radius"] else 1.0
			return "+%d → +%d%s" % [roundi(PassiveRegistry.get_bonus(id,before)*units),roundi(PassiveRegistry.get_bonus(id,before+1)*units),increments[id][1]]
		if id == "projectile_count":
			return "+%d → +%d Geschosse" % [PassiveRegistry.get_bonus(id,before),PassiveRegistry.get_bonus(id,before+1)]
	if option.get("type", "") in ["new_weapon","weapon_upgrade","evolution"]:
		var data := WeaponRegistry.get_weapon_data(id)
		var level := player.weapon_controller.get_weapon_level(id)
		var rank := clampi(level,0,4)
		var next_weapon := WeaponInstance.new(id,player)
		next_weapon.level=mini(5,level+1)
		if option.get("type", "") == "evolution":
			next_weapon.is_evolved=true
			return "%s: %.1f\nAbklingzeit: %.2f s\nAnzahl: %d" % [next_weapon.damage_label(),next_weapon.get_hit_damage()*player.get_stat("damage_multiplier",1),next_weapon.get_effective_cooldown(),next_weapon.get_projectiles()]
		var damages: Array = data.get("base_damage",[0,0,0,0,0])
		var cooldowns: Array = data.get("base_cooldown",[1,1,1,1,1])
		var projectiles: Array = data.get("base_projectiles",[1,1,1,1,1])
		if id=="weapon_meow_meow":
			var old_weapon := WeaponInstance.new(id,player)
			old_weapon.level=maxi(1,level)
			return "Salve: %.0f → %.0f Schaden\nGeschossgruppen: %d → %d\nAbklingzeit: %.2f s" % [old_weapon.get_damage()*old_weapon.get_projectiles()*player.get_stat("damage_multiplier",1),next_weapon.get_damage()*next_weapon.get_projectiles()*player.get_stat("damage_multiplier",1),old_weapon.get_projectiles(),next_weapon.get_projectiles(),next_weapon.get_effective_cooldown()]
		if level>0:
			var current_weapon := WeaponInstance.new(id,player)
			current_weapon.level=level
			return "%s: %.1f → %.1f\nAbklingzeit: %.2f → %.2f s\nAnzahl: %d → %d" % [next_weapon.damage_label(),current_weapon.get_hit_damage()*player.get_stat("damage_multiplier",1),next_weapon.get_hit_damage()*player.get_stat("damage_multiplier",1),current_weapon.get_effective_cooldown(),next_weapon.get_effective_cooldown(),current_weapon.get_projectiles(),next_weapon.get_projectiles()]
		return "%s: %.1f\nAbklingzeit: %.2f s\nAnzahl: %d" % [next_weapon.damage_label(),next_weapon.get_hit_damage()*player.get_stat("damage_multiplier",1),next_weapon.get_effective_cooldown(),next_weapon.get_projectiles()]
	return option.get("desc", "")

func _ready() -> void:
	text = choice.get("title", "")
	tooltip_text = "%s\n%s\n\nTAB: Evolutionen und aktuelle Werte" % [choice.get("title",""),choice.get("desc","")]
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	_skin = NinePatchRect.new()
	_skin.texture = load("res://assets/ui/swarm/choice-card.res")
	_skin.patch_margin_left = 120
	_skin.patch_margin_right = 120
	_skin.patch_margin_top = 140
	_skin.patch_margin_bottom = 140
	_skin.scale = Vector2.ONE*0.25
	_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skin)
	_icon = TextureRect.new()
	_icon.texture = Icons.texture(Icons.choice_index(choice))
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_add_label("Tag",str(choice.get("sub","NEU")),14,Color("c8a3ff"))
	_add_label("Title",str(choice.get("title","")),20,Color("f6ebd0"))
	_add_label("Description",str(choice.get("desc","")),16,Color("d4dce5"))
	_add_label("Recipe","",14,Color("edcf8f"))
	$Recipe.hide()
	_focus = Panel.new()
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus.add_theme_stylebox_override("panel",_focus_style())
	_focus.visible = selected
	add_child(_focus)
	resized.connect(_layout)
	_layout()

func _add_label(id: String, content: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.name = id
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if id=="Title": label.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
	label.max_lines_visible = 1 if id=="Tag" else (2 if id=="Title" else 3)
	if id=="Recipe" and not compact: label.max_lines_visible=5
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _layout() -> void:
	if not is_instance_valid(_skin): return
	_skin.size = size*4.0
	_skin.visible=not (compact and size.y<130)
	_focus.position = Vector2(4,4)
	_focus.size = size-Vector2(8,8)
	if compact:
		var h := minf(1.0,size.y/180.0)
		$Title.add_theme_font_size_override("font_size",maxi(11,roundi(16*h)))
		$Description.add_theme_font_size_override("font_size",maxi(10,roundi(12*h)))
		$Recipe.add_theme_font_size_override("font_size",10)
		$Tag.add_theme_font_size_override("font_size",maxi(10,roundi(14*h)))
		_icon.position = Vector2(24,40)*h
		_icon.size = Vector2(64,64)*h
		$Tag.position = Vector2(105,25)*h
		$Tag.size = Vector2(size.x-130*h,18*h)
		$Title.position = Vector2(105,47)*h
		$Title.size = Vector2(size.x-130*h,32*h)
		$Description.position = Vector2(105,82)*h
		$Description.size = Vector2(size.x-130*h,28*h)
		$Recipe.position = Vector2(24,104)*h
		$Recipe.size = Vector2(size.x-48*h,38*h)
		if size.y<130:
			$Tag.hide()
			_icon.position=Vector2(12,12)
			_icon.size=Vector2(42,42)
			$Title.position=Vector2(66,8)
			$Title.size=Vector2(size.x-78,24)
			$Title.add_theme_font_size_override("font_size",12)
			$Description.position=Vector2(66,34)
			$Description.size=Vector2(size.x-78,18)
			$Recipe.position=Vector2(12,58)
			$Recipe.size=Vector2(size.x-24,maxf(0,size.y-64))
	else:
		$Recipe.add_theme_font_size_override("font_size",11 if size.x<240 else 14)
		_icon.position = Vector2(size.x*0.28,size.y*0.17)
		_icon.size = Vector2.ONE*size.x*0.44
		$Tag.position = Vector2(size.x*0.12,size.y*0.07)
		$Tag.size = Vector2(size.x*0.76,30)
		$Title.position = Vector2(size.x*0.12,size.y*0.44)
		$Title.size = Vector2(size.x*0.76,size.y*0.12)
		$Description.position = Vector2(size.x*0.13,size.y*0.57)
		$Description.size = Vector2(size.x*0.74,size.y*0.16)
		$Recipe.position = Vector2(size.x*0.12,size.y*0.75)
		$Recipe.size = Vector2(size.x*0.76,size.y*0.20)
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(_skin): _skin.modulate = Color(1.15,1.2,1.25) if value else Color.WHITE
	if is_instance_valid(_focus): _focus.visible = value
	queue_redraw()

func _draw() -> void:
	if compact and size.y<130:
		var background := StyleBoxFlat.new()
		background.bg_color=Color("101428")
		background.border_color=Color("a565ee")
		background.set_border_width_all(2)
		background.set_corner_radius_all(12)
		draw_style_box(background,Rect2(Vector2.ZERO,size))
	if selected:
		var inset := 6.0
		draw_style_box(_focus_style(),Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2))

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(3)
	style.border_color = Color("85fff2")
	style.set_corner_radius_all(20)
	return style
