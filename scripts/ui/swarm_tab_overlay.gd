extends Control

const Icons = preload("res://scripts/ui/swarm_icons.gd")
const Rules = preload("res://scripts/progression/evolution_rules.gd")
var player: PlayerController
var selected_slot := 0
var recipes: PanelContainer
var stats: PanelContainer
var rows: VBoxContainer
var selectors: HBoxContainer
var headline: Label
var stat_labels: Dictionary = {}
var recipe_buttons: Array[Button] = []
var signature := ""
var clock := 0.0
var hud: Control

static func frame() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color=Color("081e26")
	skin.border_color=Color("a18c53")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(5)
	skin.content_margin_left=10
	skin.content_margin_right=10
	skin.content_margin_top=8
	skin.content_margin_bottom=8
	return skin

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=100
	resized.connect(layout_display)
	recipes=PanelContainer.new()
	recipes.name="EvolutionRecipes"
	recipes.add_theme_stylebox_override("panel",frame())
	add_child(recipes)
	var box := VBoxContainer.new()
	recipes.add_child(box)
	selectors=HBoxContainer.new()
	box.add_child(selectors)
	var title := Label.new()
	title.text="EVOLUTIONEN"
	title.add_theme_color_override("font_color",Color("e6d399"))
	box.add_child(title)
	var hint := Label.new()
	hint.text="Waffe 5 + Passive 1 + Karte"
	hint.add_theme_font_size_override("font_size",11)
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	rows=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	stats=PanelContainer.new()
	stats.name="CurrentStats"
	stats.add_theme_stylebox_override("panel",frame())
	add_child(stats)
	var values := VBoxContainer.new()
	values.add_theme_constant_override("separation",3)
	stats.add_child(values)
	headline=Label.new()
	headline.add_theme_color_override("font_color",Color("e6d399"))
	headline.add_theme_font_size_override("font_size",13)
	values.add_child(headline)
	for entry in [["damage","Schaden",126],["movement","Lauftempo",124],["haste","Fähigkeitstempo",127],["cooldown","Abklingzeitverkürzung",127],["crit","Kritische Treffer",125],["crit_damage","Kritischer Schaden",125],["health","Maximales Leben",121],["regen","Regeneration / 5 s",123],["armor","Rüstung",122],["projectiles","Zusatzgeschosse",130],["area","Flächengröße",129],["duration","Dauer",128],["pickup","Sammelradius",132],["xp","Erfahrung",131],["gold","Gold",28]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		var icon := TextureRect.new()
		icon.texture=Icons.texture(entry[2])
		icon.custom_minimum_size=Vector2(16,16)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text=entry[1]
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size",12)
		row.add_child(label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size",12)
		value.add_theme_color_override("font_color",Color("e1eedc"))
		row.add_child(value)
		values.add_child(row)
		stat_labels[entry[0]]=value
		row.tooltip_text=""
	hide()

func select_player(slot: int) -> void:
	selected_slot=slot
	signature=""
	refresh()
	layout_display()

func refresh() -> void:
	player=null
	for candidate in GameManager.active_player_nodes:
		if is_instance_valid(candidate) and candidate.player_slot_index==selected_slot: player=candidate
	if not is_instance_valid(player):
		for candidate in GameManager.active_player_nodes:
			if is_instance_valid(candidate):
				player=candidate
				selected_slot=player.player_slot_index
				break
	if not is_instance_valid(player): return
	var key := str(player.get_instance_id())
	for weapon in player.weapon_controller.equipped_weapons: key+="/"+weapon.weapon_id
	key+="/"+str(GameManager.active_player_nodes.size())
	if signature!=key:
		signature=key
		_rebuild_recipes()
	headline.text="P%d · %s" % [selected_slot+1,player.char_data.get("display_name","")]
	var snapshot := stat_snapshot(player)
	for id in stat_labels: stat_labels[id].text=snapshot[id]
	stat_labels["cooldown"].get_parent().tooltip_text="Fähigkeitstempo und zusätzliche Abklingzeitfaktoren gemeinsam. Ult-spezifische Boni und abweichende Waffenregeln stehen im jeweiligen Fähigkeitstext."
	stat_labels["movement"].get_parent().tooltip_text="Aktueller Bewegungswert einschließlich temporärer Boni. Die projektweite Kartenskalierung ist hier nicht eingerechnet."
	stat_labels["projectiles"].get_parent().tooltip_text="Zusätzliche Geschosse für skalierende Waffen, nicht die gesamte Salve jeder Waffe."
	for button in recipe_buttons:
		var weapon_id: String=button.get_meta("weapon","")
		if weapon_id.is_empty():
			var passive_id: String=button.get_meta("passive")
			var text: String=PassiveRegistry.get_passive_data(passive_id).get("display_name",passive_id)
			for id in Rules.passive_matches(player,passive_id): text+="\n\n"+Rules.weapon_recipe(player,id)
			button.tooltip_text=text
			button.modulate=Color.WHITE if int(player.passives.get(passive_id,0))>0 else Color(0.65,0.65,0.65)
		else:
			var state := Rules.weapon_state(player,weapon_id)
			button.tooltip_text=Rules.weapon_recipe(player,weapon_id)+"\n\nDie Passive bleibt erhalten; die Evolution belegt denselben Waffenplatz."
			button.modulate=Color("cba0ff") if state["evolved"] else (Color("8affaf") if state["ready"] else (Color.WHITE if state["rank"]>0 else Color(0.6,0.6,0.6)))

static func stat_snapshot(p: PlayerController) -> Dictionary:
	var cooldown_factor := 100.0/(100.0+maxf(-90,p.get_stat("ability_haste")))*p.get_stat("cooldown_multiplier",1)
	return {"damage":"%.0f%%" % (p.get_stat("damage_multiplier",1)*100),"movement":"%.0f" % p.get_stat("movement_speed"),"haste":"%.0f" % p.get_stat("ability_haste"),"cooldown":"%.1f%%" % ((1-cooldown_factor)*100),"crit":"%.0f%%" % (p.get_stat("crit_chance")*100),"crit_damage":"%.0f%%" % (p.get_stat("crit_damage",2)*100),"health":"%.0f" % p.get_stat("max_health"),"regen":"%.1f" % p.get_stat("health_regen"),"armor":"%.0f" % p.get_stat("armor"),"projectiles":"+%d" % p.get_stat("bonus_projectiles"),"area":"%.0f%%" % (p.get_stat("area_multiplier",1)*100),"duration":"%.0f%%" % (p.get_stat("duration_multiplier",1)*100),"pickup":"%.0f%%" % (p.get_stat("pickup_radius",100)/maxf(1,float(p.base_stats.get("pickup_radius",100)))*100),"xp":"%.0f%%" % (p.get_stat("exp_multiplier",1)*100),"gold":"%.0f%%" % (p.get_stat("gold_multiplier",1)*100)}

func _icon_button(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size=Vector2(30,30)
	button.icon=Icons.texture(index)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",28)
	button.focus_mode=Control.FOCUS_NONE
	button.mouse_default_cursor_shape=Control.CURSOR_HELP
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	return button

func _rebuild_recipes() -> void:
	for holder in [rows,selectors]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	recipe_buttons.clear()
	for candidate in GameManager.active_player_nodes:
		if not is_instance_valid(candidate): continue
		var button := Button.new()
		button.text="P%d" % [candidate.player_slot_index+1]
		button.focus_mode=Control.FOCUS_NONE
		button.modulate=ProfileManager.DEFAULT_PLAYER_COLORS[candidate.player_slot_index]
		button.pressed.connect(select_player.bind(candidate.player_slot_index))
		selectors.add_child(button)
	for passive_id in PassiveRegistry.passives:
		var weapons := Rules.passive_matches(player,passive_id)
		if weapons.is_empty(): continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",4)
		var passive := _icon_button(Icons.PASSIVES.get(passive_id,30))
		passive.set_meta("passive",passive_id)
		row.add_child(passive)
		recipe_buttons.append(passive)
		var separator := VSeparator.new()
		row.add_child(separator)
		for weapon_id in weapons:
			var weapon := _icon_button(Icons.WEAPONS.get(weapon_id,30))
			weapon.set_meta("weapon",weapon_id)
			weapon.set_meta("passive",passive_id)
			row.add_child(weapon)
			recipe_buttons.append(weapon)
		rows.add_child(row)

func layout_display() -> void:
	if not is_instance_valid(recipes): return
	var h := get_viewport_rect().size.y
	var left := 0.0
	if hud.players_hud_container.get_child_count()>0: left=hud.players_hud_container.get_child(0).get_global_rect().position.x
	var beside := left>=270 and h>=850
	recipes.position=Vector2(14,68)
	recipes.size=Vector2(230,minf(520,h-100 if beside else h-450))
	stats.size=Vector2(244,0)
	stats.reset_size()
	stats.position=Vector2(left-256 if beside else 14,h-stats.size.y-22)
	if not beside: recipes.size.y=maxf(140,minf(520,stats.position.y-recipes.position.y-12))

func _process(delta: float) -> void:
	if not visible: return
	clock+=delta
	if clock>=0.2:
		clock=0
		refresh()
		layout_display()
