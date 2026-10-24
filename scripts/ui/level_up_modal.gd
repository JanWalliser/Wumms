extends Control

# LevelUpModal - Synchronized multiplayer level-up and access card selection modal

class_name LevelUpModal

const ChoiceCard = preload("res://scripts/ui/swarm_choice_card.gd")

@onready var columns_container: HBoxContainer = $CenterContainer/Panel/VBoxContainer/ColumnsContainer
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel

var keyboard_override := -1
var network_choices: Dictionary = {}
var rerolls: Dictionary = {}
var event_id := -1
var analog_latched: Dictionary = {}
var reroll_button: Button
var is_access_card: bool = false
var player_choices_data: Dictionary = {} # player_idx -> Array[Dictionary]
var player_focus_indices: Dictionary = {} # player_idx -> int (0..2)
var player_panels: Dictionary = {} # player_idx -> VBoxContainer
var player_buttons: Dictionary = {} # player_idx -> Array[Button]
var player_excluded_ids: Dictionary = {} # player_idx -> Array of previously offered choice IDs for current event

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	GameManager.selection_requested.connect(_on_selection_requested)

func _on_level_up_triggered(lvl: int) -> void:
	is_access_card = false
	title_label.text = "LEVEL-UP! (TEAM STUFE %d)" % lvl
	_open_modal()

func _on_access_card_triggered() -> void:
	is_access_card = true
	title_label.text = "ZUTRITTS-ZWIEBACK EINGESAMMELT!"
	_open_modal()

func _open_modal() -> void:
	show()
	_rebuild_columns()

func _rebuild_columns() -> void:
	for child in columns_container.get_children():
		columns_container.remove_child(child)
		child.queue_free()

	player_choices_data.clear()
	player_focus_indices.clear()
	player_panels.clear()
	player_buttons.clear()
	player_excluded_ids.clear()

	var active_players := GameManager.active_player_nodes
	for p in active_players:
		if is_instance_valid(p):
			var idx: int = p.player_slot_index
			if NetworkManager.is_client() and not network_choices.has(idx): continue
			var choices: Array[Dictionary] = []
			if NetworkManager.is_client(): choices.assign(network_choices[idx])
			else: choices = LevelUpManager.augment_choices(p) if GameManager.current_selection.get("type", "") == "augment" else LevelUpManager.generate_choices_for_player(p, is_access_card)
			player_choices_data[idx] = choices
			player_focus_indices[idx] = 0

			var col := _create_player_column(p, choices)
			columns_container.add_child(col)
			player_panels[idx] = col

	_update_card_focus()

func _create_player_column(player: PlayerController, choices: Array[Dictionary]) -> VBoxContainer:
	var col := VBoxContainer.new()
	var count := maxi(1,GameManager.active_player_nodes.size())
	var layout := _card_layout(count,choices.size())
	var grid: bool=layout["grid"]
	var compact: bool=layout["compact"]
	var card_width: float=layout["width"]
	var card_height: float=layout["height"]
	col.custom_minimum_size = Vector2((card_width+12)*3 if grid else (card_width if compact else (card_width+12)*choices.size()),0)
	$CenterContainer/Panel.custom_minimum_size = Vector2.ZERO
	$CenterContainer/Panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	col.add_theme_constant_override("separation", 14)

	var p_color: Color = ProfileManager.DEFAULT_PLAYER_COLORS[player.player_slot_index % 4]

	# Header label
	var header := Label.new()
	header.text = "SPIELER %d: %s" % [player.player_slot_index + 1, player.char_data.get("display_name", "")]
	header.modulate = p_color
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	header.clip_text=true
	col.add_child(header)

	var p_idx := player.player_slot_index
	player_buttons[p_idx] = []

	var holder: Container = GridContainer.new() if grid else BoxContainer.new()
	if not grid: (holder as BoxContainer).vertical=compact
	if grid:
		(holder as GridContainer).columns=3
		holder.add_theme_constant_override("h_separation",12)
		holder.add_theme_constant_override("v_separation",12)
	holder.add_theme_constant_override("separation",12)
	col.add_child(holder)
	# Keep the same event/slot guards; only the presentation changes.
	for i in range(choices.size()):
		var choice := choices[i]
		var card := ChoiceCard.new()
		card.choice = choice.duplicate(true)
		card.choice["desc"] = ChoiceCard.describe_choice(choice,player)
		card.choice["recipe"] = preload("res://scripts/progression/evolution_rules.gd").choice_recipe(player,choice)
		card.choice["evolution_ready"] = choice.get("type","")=="evolution"
		card.compact = compact
		card.custom_minimum_size = Vector2(card_width,card_height)
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.focus_mode = Control.FOCUS_NONE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var card_idx := i
		var card_event = event_id

		card.pressed.connect(func():
			_confirm_selection(p_idx, card_idx, card_event)
		)

		card.mouse_entered.connect(func():
			if player_choices_data.has(p_idx):
				player_focus_indices[p_idx] = card_idx
				_update_card_focus()
		)

		holder.add_child(card)
		player_buttons[p_idx].append(card)

	# Three rerolls per player and run are available from the start by user request.
	if not rerolls.has(p_idx): rerolls[p_idx] = 3
	var button = Button.new()
	button.name="RerollButton"
	button.text = "Neu generieren (%d/3) · R / X" % rerolls[p_idx]
	button.custom_minimum_size=Vector2(0,44)
	button.add_theme_font_size_override("font_size",12 if compact else 16)
	button.tooltip_text="Drei Nutzungen pro Spieler und Run. Neue Auswahl ohne eine Karte zu wählen."
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = rerolls[p_idx] <= 0
	var reroll_event = event_id
	button.pressed.connect(func(): _reroll(p_idx,reroll_event))
	col.add_child(button)
	return col

func _update_card_focus() -> void:
	for p_idx in player_choices_data.keys():
		if not player_buttons.has(p_idx):
			continue
		var btns: Array = player_buttons[p_idx]
		var cur_focus: int = int(player_focus_indices.get(p_idx, 0))
		var choices: Array = player_choices_data.get(p_idx, [])
		for i in range(btns.size()):
			var btn: Button = btns[i]
			if not is_instance_valid(btn) or i >= choices.size():
				continue
			var choice: Dictionary = choices[i]
			var is_selected := (i == cur_focus)
			btn.set_selected(is_selected)

func _move_focus(player_idx: int, dir: int) -> void:
	if not player_choices_data.has(player_idx):
		return
	var count: int = player_choices_data[player_idx].size()
	if count <= 0:
		return
	var cur: int = int(player_focus_indices.get(player_idx, 0))
	player_focus_indices[player_idx] = posmod(cur + dir, count)
	AudioManager.play_sfx("coin", 1.4)
	_update_card_focus()

func _input(event: InputEvent) -> void:
	if not visible or player_choices_data.is_empty():
		return

	if not NetworkManager.is_client() and event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_F2 and event.keycode <= KEY_F5:
		keyboard_override = event.keycode-KEY_F2
		get_viewport().set_input_as_handled()
		return
	# Keyboard navigation for Keyboard slot (device_id == -1)
	var kb_slot := -1
	for slot_idx in player_choices_data.keys():
		if slot_idx < ProfileManager.player_slots.size():
			if ProfileManager.player_slots[slot_idx]["device_id"] == -1:
				kb_slot = slot_idx
				break
	if keyboard_override >= 0: kb_slot = keyboard_override
	if kb_slot == -1 and player_choices_data.has(0):
		kb_slot = 0
	if NetworkManager.is_client(): kb_slot = NetworkManager.local_slot

	if kb_slot != -1 and player_choices_data.has(kb_slot):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				_reroll(kb_slot,event_id)
				get_viewport().set_input_as_handled()
				return
			# Number keys 1, 2, 3 direct selection
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				_confirm_selection(kb_slot, 0)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				_confirm_selection(kb_slot, 1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
				_confirm_selection(kb_slot, 2)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode in [KEY_4,KEY_KP_4,KEY_5,KEY_KP_5]:
				var direct_index := 3 if event.keycode in [KEY_4,KEY_KP_4] else 4
				if direct_index<player_choices_data[kb_slot].size(): _confirm_selection(kb_slot,direct_index)
				get_viewport().set_input_as_handled()
				return
			# Navigation with W/S or Up/Down
			elif event.keycode == KEY_W or event.keycode == KEY_UP:
				_move_focus(kb_slot, -1)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
				_move_focus(kb_slot, 1)
				get_viewport().set_input_as_handled()
				return
			# Confirm with Enter, Space, or E
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E:
				var sel_idx: int = int(player_focus_indices.get(kb_slot, 0))
				_confirm_selection(kb_slot, sel_idx)
				get_viewport().set_input_as_handled()
				return

	# Gamepad buttons navigation
	if event is InputEventJoypadButton and event.pressed:
		var joy_device := event.device
		for slot_idx in player_choices_data.keys():
			if slot_idx < ProfileManager.player_slots.size():
				if ProfileManager.player_slots[slot_idx]["device_id"] == joy_device:
					if event.button_index == JOY_BUTTON_X:
						_reroll(slot_idx,event_id)
						get_viewport().set_input_as_handled()
						return
					if event.button_index == JOY_BUTTON_DPAD_UP:
						_move_focus(slot_idx, -1)
						get_viewport().set_input_as_handled()
						return
					elif event.button_index == JOY_BUTTON_DPAD_DOWN:
						_move_focus(slot_idx, 1)
						get_viewport().set_input_as_handled()
						return
					elif event.button_index == JOY_BUTTON_A:
						var sel_idx: int = int(player_focus_indices.get(slot_idx, 0))
						_confirm_selection(slot_idx, sel_idx)
						get_viewport().set_input_as_handled()
						return

	# Gamepad analog stick navigation
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.3:
			analog_latched.erase(event.device)
			return
		if absf(event.axis_value) <= 0.6 or analog_latched.has(event.device): return
		analog_latched[event.device] = true
		var joy_device := event.device
		if event.axis == JOY_AXIS_LEFT_Y:
			for slot_idx in player_choices_data.keys():
				if slot_idx < ProfileManager.player_slots.size():
					if ProfileManager.player_slots[slot_idx]["device_id"] == joy_device:
						var dir := -1 if event.axis_value < 0.0 else 1
						_move_focus(slot_idx, dir)
						get_viewport().set_input_as_handled()
						return

func _confirm_selection(player_idx: int, choice_idx: int, expected_event: int = -1) -> void:
	if NetworkManager.is_client():
		NetworkManager.choose(player_idx, choice_idx, event_id)
		return
	if expected_event >= 0 and expected_event != event_id: return
	if GameManager.current_selection.get("id", -2) != event_id or not player_choices_data.has(player_idx):
		return

	var choices: Array[Dictionary] = player_choices_data[player_idx]
	if choice_idx >= 0 and choice_idx < choices.size():
		var chosen := choices[choice_idx]
		# Find player controller
		for p in GameManager.active_player_nodes:
			if is_instance_valid(p) and p.player_slot_index == player_idx:
				if not LevelUpManager.apply_choice_to_player(p, chosen): return
				break

	# Disable column
	if player_panels.has(player_idx):
		var panel: VBoxContainer = player_panels[player_idx]
		for button in player_buttons.get(player_idx,[]):
			button.disabled = true
		var done_label := Label.new()
		done_label.text = "BEREIT!"
		done_label.modulate = Color.GREEN
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(done_label)

	player_choices_data.erase(player_idx)
	player_focus_indices.erase(player_idx)
	player_buttons.erase(player_idx)
	GameManager.player_completed_level_up_selection(player_idx,event_id)

	if player_choices_data.is_empty():
		hide()
	else:
		_update_card_focus()

func _on_selection_requested(event: Dictionary) -> void:
	event_id = event["id"]
	is_access_card = event["type"] == "card"
	title_label.text = "ZUTRITTS-ZWIEBACK" if is_access_card else ("MIEZI-BELOHNUNG" if event["type"] == "augment" else "TEAM STUFE %d" % event["level"])
	title_label.tooltip_text = "F2–F5: Spieler mit Tastatur übernehmen · 1–5 / A: Auswählen · Stufe 5 + Passive Stufe 1 + Zugangskarte"
	_open_modal()

func _process(_delta: float) -> void:
	if GameManager.run_finalized: hide()
	if visible: _fit_tab_layout()

func _reroll(idx: int, expected: int = -1) -> void:
	if NetworkManager.is_client():
		NetworkManager.choose(idx, 0, event_id, true)
		return
	if expected >= 0 and expected != event_id: return
	if not player_choices_data.has(idx) or int(rerolls.get(idx, 0)) <= 0: return
	rerolls[idx] -= 1

	if not player_excluded_ids.has(idx):
		player_excluded_ids[idx] = []
	for c in player_choices_data.get(idx, []):
		if c is Dictionary and c.has("id"):
			var cid: String = c["id"]
			if not player_excluded_ids[idx].has(cid):
				player_excluded_ids[idx].append(cid)
			var typed_id: String = c.get("type", "") + ":" + cid
			if not player_excluded_ids[idx].has(typed_id):
				player_excluded_ids[idx].append(typed_id)

	var exclude_list: Array = player_excluded_ids.get(idx, [])
	for p in GameManager.active_player_nodes:
		if p.player_slot_index != idx: continue
		var choices = LevelUpManager.augment_choices(p, exclude_list) if GameManager.current_selection.get("type", "") == "augment" else LevelUpManager.generate_choices_for_player(p, is_access_card, exclude_list)
		var old = player_panels[idx]
		var place = old.get_index()
		columns_container.remove_child(old)
		old.queue_free()
		player_choices_data[idx] = choices
		player_focus_indices[idx] = 0
		var column = _create_player_column(p, choices)
		columns_container.add_child(column)
		columns_container.move_child(column, place)
		player_panels[idx] = column
		_update_card_focus()

var _tab_layout_key := ""

func show_network_selection(data: Dictionary) -> void:
	var event: Dictionary = data["event"]
	if event.is_empty():
		hide()
		return
	event_id = event["id"]
	network_choices = data["choices"].duplicate(true)
	rerolls.assign(data["rerolls"])
	is_access_card = event["type"] == "card"
	title_label.text = "ZUTRITTS-ZWIEBACK" if is_access_card else ("MIEZI-BELOHNUNG" if event["type"] == "augment" else "TEAM STUFE %d" % event["level"])
	title_label.tooltip_text = "Dein Spieler: %d · 1–5: wählen · R: neu würfeln" % (NetworkManager.local_slot + 1)
	_open_modal()
	for slot in player_buttons:
		if slot == NetworkManager.local_slot: continue
		for button in player_buttons[slot]: button.disabled = true
		player_panels[slot].get_node("RerollButton").disabled = true

func _tab_reserve() -> float:
	var hud = get_tree().get_first_node_in_group("game_hud")
	return 268.0 if is_instance_valid(hud) and is_instance_valid(hud.tab_overlay) and hud.tab_overlay.visible else 0.0

func _card_layout(count: int, choice_count: int) -> Dictionary:
	var reserve := _tab_reserve()
	var viewport_size := get_viewport_rect().size
	viewport_size.x-=reserve
	var grid := count==1 and choice_count>3
	var compact := count>=3 or choice_count>3 or (reserve>0 and count>=2 and viewport_size.x/count<700)
	var width := minf(300 if count==1 else 240,(viewport_size.x-160)/float(count*maxi(3,choice_count))-20)
	var height := minf(500,viewport_size.y-260)
	if compact:
		width=minf(360,(viewport_size.x-160)/count-24)
		height=minf(160,(viewport_size.y-260)/maxi(3,choice_count))
	if grid:
		width=minf(360,(viewport_size.x-160)/3.0-20)
		height=minf(180,(viewport_size.y-260)/2.0)
	return {"grid":grid,"compact":compact,"width":maxf(90,width),"height":height}

func _fit_tab_layout() -> void:
	var reserve := _tab_reserve()
	var key := str(get_viewport_rect().size)+":"+str(reserve)+":"+str(event_id)+":"+str(player_buttons.keys())
	for slot in player_buttons: key+=":"+str(player_buttons[slot].size())
	if key==_tab_layout_key: return
	_tab_layout_key=key
	$CenterContainer.offset_left=reserve
	var count := maxi(1,GameManager.active_player_nodes.size())
	for slot in player_buttons:
		var buttons: Array=player_buttons[slot]
		var layout := _card_layout(count,buttons.size())
		var width: float=layout["width"]
		var height: float=layout["height"]
		var column: VBoxContainer=player_panels[slot]
		column.get_node("RerollButton").add_theme_font_size_override("font_size",12 if width<260 else 16)
		column.custom_minimum_size=Vector2((width+12)*3 if layout["grid"] else (width if layout["compact"] else (width+12)*buttons.size()),0)
		var holder: Container=buttons[0].get_parent() if not buttons.is_empty() else null
		if holder is BoxContainer:
			(holder as BoxContainer).vertical=layout["compact"]
		for card in buttons:
			card.compact=layout["compact"]
			card.custom_minimum_size=Vector2(width,height)
			card.get_node("Tag").show()
			card.get_node("Title").add_theme_font_size_override("font_size",20)
			card.get_node("Description").add_theme_font_size_override("font_size",16)
			card._layout()
