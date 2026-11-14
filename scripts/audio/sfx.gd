extends RefCounted
## Sound effects and music. A real file at res://audio/<name>.ogg / .wav / .mp3 always wins;
## otherwise a tiny synthesizer builds the sound once (cached), so the game has audio without assets.
## Music is synthesized on a worker thread and starts when ready.
## Buses "Music" and "SFX" are created on first use (volumes come from settings.gd).

const RATE := 22050
const AUDIO_DIR := "res://audio/"
const LOOPS := ["engine", "engine_ev", "ambience", "music_menu", "music_city"]

static var _cache := {}
static var _music: AudioStreamPlayer
static var _music_name := ""
static var _rng := RandomNumberGenerator.new()


static func ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


static func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	for ext: String in ["ogg", "wav", "mp3"]:
		var path := AUDIO_DIR + name + "." + ext
		if ResourceLoader.exists(path):
			_cache[name] = load(path)
			return _cache[name]
	_cache[name] = _wav(_synth(name), name in LOOPS)
	return _cache[name]


## One-shot sound; positional when `pos` is a Vector3. Keeps playing while the game is paused.
static func play(owner: Node, name: String, pos = null, volume_db := 0.0, pitch := 1.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	ensure_buses()
	var player: Node
	if pos is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = stream(name)
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.unit_size = 8.0
		p3.max_distance = 70.0
		p3.bus = "SFX"
		p3.position = pos
		p3.finished.connect(p3.queue_free)
		player = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream(name)
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.bus = "SFX"
		p2.finished.connect(p2.queue_free)
		player = p2
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var parent: Node = owner.get_tree().current_scene if owner.get_tree().current_scene != null else owner
	parent.add_child(player)
	player.play()


## Looping music track for the current scene (same name keeps playing).
static func music(owner: Node, name: String, volume_db := -6.0) -> void:
	ensure_buses()
	if _music == null or not is_instance_valid(_music) or not _music.is_inside_tree():
		_music = AudioStreamPlayer.new()
		_music.bus = "Music"
		_music.process_mode = Node.PROCESS_MODE_ALWAYS
		owner.add_child(_music)
	elif _music_name == name:
		return
	_music_name = name
	_music.volume_db = volume_db
	if _cache.has(name):
		_music.stream = _cache[name]
		_music.play()
		return
	var player := _music
	var path := ""
	for ext: String in ["ogg", "wav", "mp3"]:
		if path.is_empty() and ResourceLoader.exists(AUDIO_DIR + name + "." + ext):
			path = AUDIO_DIR + name + "." + ext
	if not path.is_empty():
		_cache[name] = load(path)
		player.stream = _cache[name]
		player.play()
		return
	# Synthesize off the main thread; only the finished stream touches shared state.
	WorkerThreadPool.add_task(func():
		var s := _wav(_synth(name), true)
		(func():
			_cache[name] = s
			if is_instance_valid(player) and _music_name == name:
				player.stream = s
				player.play()).call_deferred())


# --- Synthesis --------------------------------------------------------------------------------

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Adds a decaying tone (sine with a few harmonics) starting at `at` seconds.
static func _tone(b: PackedFloat32Array, at: float, freq: float, length: float, amp: float, decay: float, harmonics := 1, sweep := 0.0) -> void:
	var start := int(at * RATE)
	var n := int(length * RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= b.size():
			break
		var t := float(i) / RATE
		var f := freq + sweep * t / length
		phase += TAU * f / RATE
		var v := 0.0
		for h in harmonics:
			v += sin(phase * (h + 1)) / (h + 1)
		var env := exp(-decay * t) * minf(1.0, t * 400.0)
		b[idx] += v * amp * env


static func _noise(b: PackedFloat32Array, at: float, length: float, amp: float, decay: float, smooth := 0.0) -> void:
	var start := int(at * RATE)
	var lp := 0.0
	for i in int(length * RATE):
		var idx := start + i
		if idx >= b.size():
			break
		var t := float(i) / RATE
		lp = lerpf(_rng.randf_range(-1.0, 1.0), lp, smooth)
		b[idx] += lp * amp * exp(-decay * t) * minf(1.0, t * 600.0)


static func _synth(name: String) -> PackedFloat32Array:
	if not name.begins_with("music"):
		_rng.seed = hash(name)
	var b: PackedFloat32Array
	match name:
		"hit":
			b = _buf(0.18)
			_noise(b, 0, 0.18, 0.6, 35.0, 0.3)
			_tone(b, 0, 140.0, 0.18, 0.7, 25.0, 2, -60.0)
		"hit_heavy":
			b = _buf(0.4)
			_noise(b, 0, 0.4, 0.7, 14.0, 0.6)
			_tone(b, 0, 90.0, 0.4, 0.9, 10.0, 3, -50.0)
			_noise(b, 0, 0.03, 0.6, 80.0)
		"whoosh":
			b = _buf(0.3)
			var lp := 0.0
			for i in b.size():
				var t := float(i) / b.size()
				lp = lerpf(_rng.randf_range(-1.0, 1.0), lp, 0.85 - 0.4 * t)
				b[i] = lp * sin(PI * t) * 0.5
		"block":
			b = _buf(0.5)
			for f in [520.0, 1170.0, 1830.0, 2750.0]:
				_tone(b, 0, f, 0.5, 0.25, 9.0 + f * 0.004)
			_noise(b, 0, 0.04, 0.5, 60.0)
		"parry":
			b = _buf(0.9)
			for f in [1320.0, 1980.0, 2640.0, 3960.0]:
				_tone(b, 0, f, 0.9, 0.2, 4.0)
			_tone(b, 0.06, 2640.0, 0.8, 0.15, 5.0)
			_noise(b, 0, 0.05, 0.4, 50.0)
		"step":
			b = _buf(0.08)
			_noise(b, 0, 0.08, 0.6, 55.0, 0.8)
		"ui_move":
			b = _buf(0.06)
			_tone(b, 0, 880.0, 0.06, 0.3, 50.0)
		"ui_confirm":
			b = _buf(0.25)
			_tone(b, 0, 660.0, 0.12, 0.3, 18.0, 2)
			_tone(b, 0.08, 990.0, 0.17, 0.3, 14.0, 2)
		"ui_back":
			b = _buf(0.22)
			_tone(b, 0, 660.0, 0.1, 0.3, 18.0, 2)
			_tone(b, 0.08, 440.0, 0.14, 0.3, 14.0, 2)
		"purchase":
			b = _buf(0.5)
			_tone(b, 0, 1318.5, 0.2, 0.3, 12.0, 3)
			_tone(b, 0.09, 1760.0, 0.4, 0.3, 7.0, 3)
		"notify":
			b = _buf(0.6)
			_tone(b, 0, 1046.5, 0.25, 0.3, 9.0)
			_tone(b, 0, 1568.0, 0.25, 0.15, 9.0)
			_tone(b, 0.18, 1318.5, 0.4, 0.3, 7.0)
			_tone(b, 0.18, 1975.5, 0.4, 0.15, 7.0)
		"pickup":
			b = _buf(0.45)
			for k in 3:
				_tone(b, k * 0.07, [784.0, 987.8, 1318.5][k], 0.3, 0.25, 10.0, 2)
		"heal":
			b = _buf(0.5)
			_tone(b, 0, 420.0, 0.5, 0.3, 5.0, 2, 500.0)
			_tone(b, 0.1, 840.0, 0.4, 0.15, 6.0, 1, 600.0)
		"charge":
			b = _buf(0.45)
			_tone(b, 0, 180.0, 0.45, 0.35, 1.5, 4, 700.0)
			_noise(b, 0, 0.45, 0.15, 2.0, 0.5)
		"door":
			b = _buf(0.3)
			_tone(b, 0, 95.0, 0.3, 0.6, 18.0, 3)
			_noise(b, 0.02, 0.05, 0.4, 70.0)
		"horn":
			b = _buf(0.45)
			for f in [392.0, 494.0]:
				_tone(b, 0, f, 0.45, 0.25, 2.0, 5)
		"engine":
			b = _buf(1.0)
			_tone(b, 0, 55.0, 1.0, 0.45, 0.0, 6)
			_tone(b, 0, 110.0, 1.0, 0.15, 0.0, 3)
			_noise(b, 0, 1.0, 0.12, 0.0, 0.9)
			_fade_loop(b)
		"engine_ev":
			b = _buf(1.0)
			_tone(b, 0, 220.0, 1.0, 0.25, 0.0)
			_tone(b, 0, 660.0, 1.0, 0.08, 0.0)
			_noise(b, 0, 1.0, 0.04, 0.0, 0.95)
			_fade_loop(b)
		"ambience":
			b = _buf(8.0)
			_noise(b, 0, 8.0, 0.35, 0.0, 0.985)
			for k in 6:
				var at := _rng.randf_range(0.2, 7.4)
				for c in 3:
					_tone(b, at + c * 0.09, _rng.randf_range(2600.0, 3400.0), 0.07, 0.05, 30.0, 1, 600.0)
			_fade_loop(b)
		"music_menu":
			b = _song([[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], 4.0, false)
		"music_city":
			b = _song([[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]], 60.0 / 85.0 * 4.0, true)
		_:
			b = _buf(0.1)
			_tone(b, 0, 440.0, 0.1, 0.2, 30.0)
	return b


## Smooths the loop seam.
static func _fade_loop(b: PackedFloat32Array) -> void:
	var n := mini(int(0.02 * RATE), b.size() / 4)
	for i in n:
		var k := float(i) / n
		var j := b.size() - n + i
		b[j] = lerpf(b[j], b[i], k)


## Soft pad chords (MIDI notes) with a gentle bell arpeggio; `beat` adds a lo-fi kick and hat.
static func _song(chords: Array, bar: float, beat: bool) -> PackedFloat32Array:
	var b := _buf(bar * chords.size())
	for c in chords.size():
		var at := c * bar
		for note in chords[c]:
			var f := 440.0 * pow(2.0, (note - 69) / 12.0)
			_pad(b, at, bar, f, 0.07)
			_pad(b, at, bar, f * 1.003, 0.05)
		for k in 8:
			var note: int = chords[c][k % chords[c].size()] + 12 * (1 + (k / 4) % 2)
			_tone(b, at + k * bar / 8.0, 440.0 * pow(2.0, (note - 69) / 12.0), bar / 4.0, 0.06, 6.0, 2)
		if beat:
			for k in 4:
				_tone(b, at + k * bar / 4.0, 70.0, 0.25, 0.35, 16.0, 1, -40.0)
				_noise(b, at + k * bar / 4.0 + bar / 8.0, 0.05, 0.06, 70.0)
	_fade_loop(b)
	return b


static func _pad(b: PackedFloat32Array, at: float, length: float, freq: float, amp: float) -> void:
	var start := int(at * RATE)
	var n := int(length * RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= b.size():
			break
		phase += TAU * freq / RATE
		var t := float(i) / n
		var env := minf(t * 6.0, 1.0) * minf((1.0 - t) * 6.0, 1.0)
		b[idx] += (sin(phase) + 0.3 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)) * amp * env
