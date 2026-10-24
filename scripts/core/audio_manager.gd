extends Node

# AudioManager - Dynamic procedural sound synthesis and SFX management
# Produces instant, responsive sound effects for all actions without requiring external audio files,
# while supporting custom audio files if placed in res://assets/audio/

var last_sound: Dictionary = {}
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.25
var music_player: AudioStreamPlayer

var _sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 16
var _pool_index := 0

var _synthesized_streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		master_volume = clampf(float(settings.get_value("audio","master",1)),0,1)
		sfx_volume = clampf(float(settings.get_value("audio","sfx",0.8)),0,1)
		music_volume = clampf(float(settings.get_value("audio","music",0.25)),0,1)
		if settings.get_value("video","fullscreen",false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		if settings.has_section("input"):
			for action in settings.get_section_keys("input"):
				if not InputMap.has_action(action): continue
				InputMap.action_erase_events(action)
				for event in settings.get_value("input",action,[]):
					if event is InputEvent: InputMap.action_add_event(action,event)
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_pregenerate_sounds()
	music_player = AudioStreamPlayer.new()
	music_player.stream = _create_music()
	music_player.volume_db = linear_to_db(maxf(0.0001,master_volume*music_volume))
	add_child(music_player)
	if DisplayServer.get_name() != "headless": music_player.play()

func play_sfx(event_id: String, pitch_scale: float = 1.0) -> void:
	var now = Time.get_ticks_msec()
	if event_id in ["shoot","coin","hit","crit"] and now-int(last_sound.get(event_id,-1000)) < 60: return
	last_sound[event_id] = now
	var network = get_node_or_null("/root/NetworkManager")
	if network and network.hosting and network.in_run: network.relay_sound(event_id, pitch_scale)
	if sfx_volume <= 0.001:
		return

	var stream: AudioStream = null
	var custom_path := "res://assets/audio/%s.wav" % event_id
	if ResourceLoader.exists(custom_path):
		stream = load(custom_path)
	elif _synthesized_streams.has(event_id):
		stream = _synthesized_streams[event_id]

	if stream:
		var player := _sfx_players[_pool_index]
		_pool_index = (_pool_index + 1) % POOL_SIZE
		player.stream = stream
		player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
		player.volume_db = linear_to_db(sfx_volume * master_volume)
		player.play()

func _pregenerate_sounds() -> void:
	_synthesized_streams["shoot"] = _create_laser_stream(880.0, 320.0, 0.08)
	_synthesized_streams["hit"] = _create_hit_stream(0.06)
	_synthesized_streams["crit"] = _create_crit_stream(0.15)
	_synthesized_streams["explosion"] = _create_explosion_stream(0.25)
	_synthesized_streams["coin"] = _create_arpeggio_stream([987.0, 1318.0], 0.12)
	_synthesized_streams["heal"] = _create_arpeggio_stream([523.0, 659.0, 783.0], 0.2)
	_synthesized_streams["level_up"] = _create_arpeggio_stream([523.0, 659.0, 783.0, 1046.0], 0.35)
	_synthesized_streams["evolve"] = _create_arpeggio_stream([440.0, 554.0, 659.0, 880.0, 1108.0], 0.6)
	_synthesized_streams["boss_spawn"] = _create_boss_warning_stream(0.8)
	_synthesized_streams["death"] = _create_death_stream(0.4)
	_synthesized_streams["revive"] = _create_arpeggio_stream([330.0, 440.0, 550.0, 660.0], 0.3)
	_synthesized_streams["card"] = _create_arpeggio_stream([784.0, 1174.0], 0.15)

func _create_laser_stream(start_freq: float, end_freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var freq := lerpf(start_freq, end_freq, progress)
		var env := 1.0 - progress
		var sample := sin(TAU * freq * t) * env
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_hit_stream(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var env := (1.0 - progress) * (1.0 - progress)
		var sample := (randf() * 2.0 - 1.0) * 0.7 * env + sin(TAU * 120.0 * t) * 0.3 * env
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_crit_stream(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var env := (1.0 - progress)
		var s1 := sin(TAU * 1200.0 * t) * 0.6
		var s2 := sin(TAU * 2400.0 * t) * 0.4
		var sample := (s1 + s2) * env
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_explosion_stream(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var env := 1.0 - progress
		var noise := (randf() * 2.0 - 1.0)
		var low_thud := sin(TAU * (80.0 * (1.0 - progress * 0.5)) * t)
		var sample := (noise * 0.75 + low_thud * 0.25) * env
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_arpeggio_stream(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	var step_time := duration / float(freqs.size())

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var idx := mini(int(t / step_time), freqs.size() - 1)
		var freq: float = freqs[idx]
		var sub_t := fmod(t, step_time)
		var env := 1.0 - (sub_t / step_time) * 0.5
		var sample := sin(TAU * freq * t) * env * 0.8
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_boss_warning_stream(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var siren := 160.0 + sin(t * 15.0) * 40.0
		var env := 1.0 - (progress * 0.3)
		var sample := sin(TAU * siren * t) * env * 0.8
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _create_death_stream(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var progress := t / duration
		var freq := lerpf(400.0, 80.0, progress)
		var env := 1.0 - progress
		var sample := (sin(TAU * freq * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * env
		var val := int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))
		data[i] = val

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

func _process(_delta: float) -> void:
	if music_player: music_player.volume_db = linear_to_db(maxf(0.0001,master_volume*music_volume))

func _create_music() -> AudioStreamWAV:
	# An original quiet eight-second arcade loop, independent of reference-game assets.
	var rate = 22050
	var data = PackedByteArray()
	data.resize(rate*8)
	var notes = [261.63,329.63,392.0,523.25,220.0,261.63,329.63,440.0,174.61,220.0,261.63,349.23,196.0,246.94,293.66,392.0]
	for i in range(data.size()):
		var time = float(i)/rate
		var beat = int(time*2)%notes.size()
		var phase = fmod(time,0.5)/0.5
		var envelope = sin(PI*phase)*0.16
		var sample = sin(TAU*notes[beat]*time)*envelope+sin(TAU*notes[beat]*0.25*time)*envelope*0.4
		data[i] = int(clampf(sample*127+128,0,255))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size()
	return stream

func _exit_tree() -> void:
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	for player in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
