extends Control

# Lobby - 4-player couch co-op lobby for selecting profiles, devices, characters, map, and difficulty

@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var map_option: OptionButton = $BottomPanel/VBoxContainer/OptionsRow/MapOption
@onready var difficulty_option: OptionButton = $BottomPanel/VBoxContainer/OptionsRow/DifficultyOption
@onready var start_button: Button = $BottomPanel/VBoxContainer/ButtonsRow/StartButton
@onready var back_button: Button = $BottomPanel/VBoxContainer/ButtonsRow/BackButton

const Progression = preload("res://scripts/progression/warehouse_progression.gd")
var map_ids: Array[String] = Progression.MAP_IDS.duplicate()
var diff_ids: Array[String] = ["story", "hard", "extreme"]
var lan_status: Label
var lan_ip: LineEdit
var lan_port: SpinBox
var lan_host: Button
var lan_join: Button
var lan_leave: Button

func _ready() -> void:
	Input.joy_connection_changed.connect(func(_device,_connected): _rebuild_slots_ui())
	_init_options()
	_build_lan_ui()
	_rebuild_slots_ui()
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	ProfileManager.player_slots_changed.connect(_on_slots_changed)
	_update_start_button()
	_refresh_unlocks()
	back_button.grab_focus()
	NetworkManager.session_changed.connect(_network_changed)
	NetworkManager.status_changed.connect(func(message): lan_status.text = message)
	_network_changed()

func _init_options() -> void:
	map_option.clear()
	map_option.add_item("Karte 1: Warenhaus-Wahnsinn", 0)
	map_option.tooltip_text="Diese Ausgabe enthält Warenhaus-Wahnsinn für 1–4 Spieler lokal oder per LAN."
	map_option.select(0)

	difficulty_option.clear()
	difficulty_option.add_item("Kartoffel-Kindergarten (Story)", 0)
	difficulty_option.add_item("Aua-Akademie (Hard)", 1)
	difficulty_option.add_item("Warum-tun-wir-uns-das-an?! (Extreme)", 2)
	difficulty_option.select(0)

func _rebuild_slots_ui() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	for i in range(4):
		var slot_panel := _create_slot_panel(i)
		slots_container.add_child(slot_panel)

func _create_slot_panel(slot_idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 480)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var slot_data := ProfileManager.player_slots[slot_idx]
	var p_col: Color = ProfileManager.DEFAULT_PLAYER_COLORS[slot_idx]

	# Slot Title
	var title := Label.new()
	title.text = "SPIELER-SLOT %d" % (slot_idx + 1)
	if NetworkManager.is_client() and slot_idx == NetworkManager.local_slot: title.text += " · DU"
	elif NetworkManager.hosting and not NetworkManager.owns_slot(slot_idx): title.text += " · LAN"
	title.modulate = p_col
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)

	# Active checkbox
	var active_chk := CheckBox.new()
	active_chk.text = "Slot Aktivieren"
	active_chk.button_pressed = slot_data["active"]
	active_chk.disabled = (slot_idx == 0) or NetworkManager.enabled # LAN assigns remote slots automatically
	active_chk.toggled.connect(func(toggled):
		ProfileManager.set_slot_active(slot_idx, toggled)
	)
	vb.add_child(active_chk)

	if not slot_data["active"]:
		var inactive_lbl := Label.new()
		inactive_lbl.text = "Slot Inaktiv"
		inactive_lbl.modulate = Color(0.5, 0.5, 0.5)
		inactive_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(inactive_lbl)
		return panel

	# Profile selection
	var prof_lbl := Label.new()
	prof_lbl.text = "Profil:"
	vb.add_child(prof_lbl)

	var prof_opt := OptionButton.new()
	var profiles := SaveManager.list_profile_ids()
	if NetworkManager.enabled and (NetworkManager.is_client() or not NetworkManager.owns_slot(slot_idx)):
		profiles.assign([slot_data["profile_id"]])
		prof_opt.disabled = true
	for p_i in range(profiles.size()):
		var p_id := profiles[p_i]
		var p_data := SaveManager.load_profile(p_id)
		prof_opt.add_item("%s | %d Gold" % [p_data.get("name", "Spieler"), int(p_data.get("gold",0))], p_i)
		if p_id == slot_data["profile_id"]:
			prof_opt.select(p_i)
	prof_opt.item_selected.connect(func(sel_idx):
		if sel_idx >= 0 and sel_idx < profiles.size():
			ProfileManager.set_player_profile(slot_idx, profiles[sel_idx])
	)
	vb.add_child(prof_opt)

	# Device selection
	var dev_lbl := Label.new()
	dev_lbl.text = "Eingabegerät:"
	vb.add_child(dev_lbl)

	var dev_opt := OptionButton.new()
	if NetworkManager.enabled and (NetworkManager.is_client() or not NetworkManager.owns_slot(slot_idx)):
		dev_opt.add_item("Tastatur & Maus an deinem PC" if slot_idx == NetworkManager.local_slot else "LAN-Spieler")
		dev_opt.disabled = true
		vb.add_child(dev_opt)
	else:
		_fill_devices(dev_opt, slot_idx, slot_data)
		vb.add_child(dev_opt)

	# Character selection
	var char_lbl := Label.new()
	char_lbl.text = "Charakter:"
	vb.add_child(char_lbl)

	var char_opt := OptionButton.new()
	char_opt.disabled = NetworkManager.enabled and not NetworkManager.owns_slot(slot_idx)
	var profile: Dictionary = slot_data.get("profile_data", {})
	var unlocked_chars: Array = profile.get("unlocked_characters", ["jankz"])
	for c_i in range(unlocked_chars.size()):
		var c_id: String = unlocked_chars[c_i]
		var c_data := CharacterRegistry.get_character_data(c_id)
		char_opt.add_item("%s (%s)" % [c_data.get("display_name", c_id), c_data.get("title", "")], c_i)
		if c_id == slot_data["character_id"]: char_opt.select(c_i)
	char_opt.item_selected.connect(func(sel):
		if sel >= 0 and sel < unlocked_chars.size():
			if NetworkManager.is_client(): NetworkManager.request_slot("character_id", unlocked_chars[sel])
			else: ProfileManager.set_slot_character(slot_idx, unlocked_chars[sel]))
	vb.add_child(char_opt)
	var ready_chk := CheckBox.new()
	ready_chk.text = "Bereit!"
	ready_chk.button_pressed = slot_data["is_ready"]
	ready_chk.disabled = NetworkManager.enabled and not NetworkManager.owns_slot(slot_idx)
	ready_chk.toggled.connect(func(is_rdy):
		if NetworkManager.is_client(): NetworkManager.request_slot("is_ready", is_rdy)
		else: ProfileManager.set_slot_ready(slot_idx, is_rdy)
		_update_start_button())
	vb.add_child(ready_chk)
	return panel

func _fill_devices(dev_opt: OptionButton, slot_idx: int, slot_data: Dictionary) -> void:
	var devices: Array = [-1]
	for device in Input.get_connected_joypads(): devices.append(device)
	if not devices.has(slot_data["device_id"]): devices.append(slot_data["device_id"])
	for device in devices:
		dev_opt.add_item("Tastatur & Maus" if device == -1 else ("Gamepad %d: %s" % [device,Input.get_joy_name(device)] if Input.get_connected_joypads().has(device) else "Gamepad %d (nicht verbunden)" % device))
	dev_opt.select(devices.find(slot_data["device_id"]))
	dev_opt.item_selected.connect(func(sel): ProfileManager.set_slot_device(slot_idx,devices[sel]))


func _on_slots_changed() -> void:
	back_button.call_deferred("grab_focus")
	_refresh_unlocks()
	_rebuild_slots_ui()
	_update_start_button()

func _update_start_button() -> void:
	start_button.disabled = NetworkManager.is_client() or not ProfileManager.are_all_active_slots_ready()
	start_button.text = "HOST STARTET DIE RUNDE" if NetworkManager.is_client() else "RUN STARTEN"

func _on_start_pressed() -> void:
	if start_button.disabled: return
	var profile = SaveManager.load_profile(ProfileManager.player_slots[0]["profile_id"])
	if not profile.get("unlocked_maps",[]).has(map_ids[map_option.selected]) or not profile.get("unlocked_difficulties",[]).has(diff_ids[difficulty_option.selected]):
		start_button.text = "Karte/Schwierigkeit noch gesperrt"
		return
	var devices: Dictionary = {}
	for slot in ProfileManager.player_slots:
		if not slot["active"]: continue
		var device = slot["device_id"]
		if NetworkManager.hosting and device <= -100: continue
		if devices.has(device) or (device >= 0 and not Input.get_connected_joypads().has(device)):
			start_button.text = "Bitte jedem Spieler ein eigenes verbundenes Gerät zuweisen"
			return
		devices[device] = true
	start_button.disabled = true
	var m_idx := clampi(map_option.selected, 0, map_ids.size() - 1)
	var d_idx := clampi(difficulty_option.selected, 0, diff_ids.size() - 1)
	var sel_map: String = map_ids[m_idx]
	var sel_diff: String = diff_ids[d_idx]

	for s in ProfileManager.player_slots:
		if s["active"]:
			s["is_ready"] = true

	if NetworkManager.hosting:
		NetworkManager.start_run(sel_map, sel_diff)
		return
	GameManager.start_new_run(sel_map, sel_diff)
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func _on_back_pressed() -> void:
	AudioManager.play_sfx("coin")
	NetworkManager.leave()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _refresh_unlocks() -> void:
	var profile = SaveManager.load_profile(ProfileManager.player_slots[0]["profile_id"])
	for i in range(map_ids.size()):
		map_option.set_item_disabled(i,not profile.get("unlocked_maps",[]).has(map_ids[i]))
	for i in range(diff_ids.size()):
		difficulty_option.set_item_disabled(i,not profile.get("unlocked_difficulties",[]).has(diff_ids[i]))
		difficulty_option.set_item_tooltip(i,Progression.difficulty_hint(diff_ids[i]))
	difficulty_option.tooltip_text="Story: sofort · Hard: Sieg im Warenhaus · Extreme: Sieg auf Hard. Freischaltungen gelten nach dem Hostprofil."
	if map_option.is_item_disabled(map_option.selected): map_option.select(0)
	if difficulty_option.is_item_disabled(difficulty_option.selected): difficulty_option.select(0)

func _build_lan_ui() -> void:
	$Header.text = "SPIELER-LOBBY · LOKAL / LAN"
	var panel := VBoxContainer.new()
	panel.name = "LAN"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 110
	panel.offset_left = 80
	panel.offset_right = -80
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	lan_host = Button.new()
	lan_host.text = "LAN HOSTEN"
	lan_host.pressed.connect(func(): NetworkManager.host(int(lan_port.value)))
	row.add_child(lan_host)
	lan_ip = LineEdit.new()
	lan_ip.placeholder_text = "Host-IP, z. B. 192.168.178.20"
	lan_ip.custom_minimum_size.x = 370
	row.add_child(lan_ip)
	lan_port = SpinBox.new()
	lan_port.min_value = 1
	lan_port.max_value = 65535
	lan_port.value = NetworkManager.PORT
	lan_port.tooltip_text = "UDP-Port · auf beiden PCs identisch"
	row.add_child(lan_port)
	lan_join = Button.new()
	lan_join.text = "PER IP BEITRETEN"
	lan_join.pressed.connect(func(): NetworkManager.join(lan_ip.text, int(lan_port.value)))
	lan_ip.text_submitted.connect(func(_value): NetworkManager.join(lan_ip.text, int(lan_port.value)))
	row.add_child(lan_join)
	lan_leave = Button.new()
	lan_leave.text = "LAN TRENNEN"
	lan_leave.pressed.connect(func(): NetworkManager.leave())
	row.add_child(lan_leave)
	lan_status = Label.new()
	lan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lan_status)
	var hint := Label.new()
	hint.text = "Gleiches LAN/WLAN · gleicher Build · Windows-Firewall: Spiel im privaten Netzwerk zulassen."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

func _network_changed() -> void:
	lan_status.text = NetworkManager.status
	lan_host.disabled = NetworkManager.enabled
	lan_join.disabled = NetworkManager.enabled
	lan_leave.disabled = not NetworkManager.enabled
	lan_ip.editable = not NetworkManager.enabled
	lan_port.editable = not NetworkManager.enabled
	map_option.disabled = NetworkManager.is_client()
	difficulty_option.disabled = NetworkManager.is_client()
	_rebuild_slots_ui()
	_update_start_button()
