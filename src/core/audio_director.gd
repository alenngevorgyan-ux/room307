class_name AudioDirector
extends Node
## Placeholder audio, synthesized at runtime (no asset dependency): ambience beds per zone,
## music states as layered tonal loops, and short SFX. Buses: Ambience (READ low-pass), Music, SFX.

const RATE := 22050

var sfx: Dictionary = {}
var music_cache: Dictionary = {}
var amb_cache: Dictionary = {}
var amb_player: AudioStreamPlayer
var amb_player_b: AudioStreamPlayer
var music_player: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var music_state := ""
var amb_state := ""
var _pool: Array = []
var _zone_check := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 307
	amb_player = _player("Ambience")
	amb_player_b = _player("Ambience")
	music_player = _player("Music")
	music_player_b = _player("Music")
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 30.0
		add_child(p)
		_pool.append(p)
	_build_sfx()
	var B := get_node("/root/Bus")
	B.sfx_requested.connect(play_sfx)
	B.music_requested.connect(set_music)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ------------------------------------------------------------------ synthesis helpers

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _noise(dur: float, lp: float, amp: float, env_a: float = 0.002, env_d: float = -1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var k := clampf(lp / RATE * TAU, 0.001, 1.0)
	for i in n:
		y += (rng.randf_range(-1, 1) - y) * k
		var t := float(i) / RATE
		var e := 1.0
		if env_d > 0.0:
			e = minf(1.0, t / env_a) * exp(-t / env_d)
		out[i] = y * amp * e
	return out


func _tone(freq: float, dur: float, amp: float, decay: float, harm: float = 0.3) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var e := minf(1.0, t / 0.004) * exp(-t / decay)
		out[i] = (sin(TAU * freq * t) + harm * sin(TAU * freq * 2.0 * t) + harm * 0.4 * sin(TAU * freq * 3.0 * t)) * amp * e
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: int = 0) -> PackedFloat32Array:
	var out := a.duplicate()
	if out.size() < b.size() + offset:
		out.resize(b.size() + offset)
	for i in b.size():
		out[i + offset] += b[i]
	return out


func _build_sfx() -> void:
	sfx["pen"] = _wav(_noise(0.32, 5200, 0.35, 0.01, 0.12))
	sfx["step_walk"] = _wav(_noise(0.09, 400, 0.5, 0.002, 0.03))
	sfx["step_run"] = _wav(_noise(0.1, 700, 0.7, 0.002, 0.035))
	sfx["door_door"] = _wav(_mix(_noise(0.3, 260, 0.8, 0.003, 0.08), _tone(70, 0.3, 0.4, 0.1)))
	sfx["door_arch"] = _wav(_noise(0.2, 300, 0.25, 0.01, 0.08))
	sfx["door_stair"] = _wav(_mix(_noise(0.35, 900, 0.6, 0.003, 0.1), _tone(180, 0.35, 0.2, 0.12)))
	sfx["door_elevator"] = _wav(_mix(_tone(880, 0.9, 0.25, 0.5, 0.1), _tone(1320, 0.9, 0.12, 0.4, 0.0), 2600))
	sfx["door_swing"] = _wav(_noise(0.25, 500, 0.5, 0.01, 0.07))
	sfx["chime"] = _wav(_mix(_tone(1046, 0.8, 0.18, 0.35, 0.05), _tone(1568, 0.8, 0.1, 0.3, 0.0), 1500))
	sfx["ding"] = sfx["door_elevator"]
	sfx["deny"] = _wav(_tone(140, 0.25, 0.3, 0.12, 0.9))
	sfx["locked"] = _wav(_mix(_noise(0.15, 1400, 0.5, 0.002, 0.03), _noise(0.15, 1400, 0.5, 0.002, 0.03), 2400))
	sfx["sms"] = _wav(_mix(_tone(1318, 0.12, 0.2, 0.05, 0.0), _tone(1760, 0.14, 0.2, 0.06, 0.0), 2800))
	sfx["phone_tap"] = _wav(_tone(2000, 0.04, 0.12, 0.01, 0.0))
	sfx["ring"] = _wav(_mix(_tone(440, 1.0, 0.18, 0.9, 0.0), _tone(480, 1.0, 0.18, 0.9, 0.0)))
	sfx["vault"] = _wav(_noise(0.2, 600, 0.5, 0.01, 0.06))
	sfx["water_on"] = _wav(_noise(0.6, 6000, 0.3, 0.05, 0.4))
	sfx["window"] = _wav(_mix(_noise(0.4, 900, 0.4, 0.01, 0.12), _tone(110, 0.4, 0.2, 0.1)))
	sfx["glass"] = _wav(_mix(_tone(2637, 0.4, 0.15, 0.15, 0.0), _tone(3520, 0.4, 0.1, 0.1, 0.0), 300))
	sfx["paper"] = _wav(_noise(0.25, 4000, 0.25, 0.02, 0.08))
	sfx["keypad"] = _wav(_tone(1200, 0.08, 0.15, 0.04, 0.0))
	sfx["accept"] = _wav(_mix(_tone(900, 0.1, 0.15, 0.05, 0.0), _tone(1350, 0.15, 0.15, 0.07, 0.0), 1600))
	sfx["click"] = _wav(_noise(0.04, 3000, 0.5, 0.001, 0.01))
	sfx["impact"] = _wav(_mix(_noise(0.3, 350, 0.9, 0.002, 0.07), _tone(55, 0.3, 0.5, 0.1)))
	sfx["crash"] = _wav(_noise(0.8, 5000, 0.6, 0.005, 0.25))
	sfx["alarm"] = _wav(_alarm(1.2), true)
	sfx["car_alarm"] = _wav(_siren(1.6), true)
	sfx["latch"] = _wav(_mix(_noise(0.15, 1800, 0.7, 0.002, 0.04), _tone(220, 0.2, 0.3, 0.05)))
	sfx["breaker"] = _wav(_mix(_noise(0.25, 900, 0.9, 0.002, 0.05), _tone(60, 0.5, 0.4, 0.2)))
	sfx["foam"] = _wav(_noise(1.2, 7000, 0.4, 0.05, 0.8))
	sfx["radio"] = _wav(_noise(0.4, 3500, 0.35, 0.01, 0.2))
	sfx["engine"] = _wav(_mix(_tone(45, 1.5, 0.4, 2.0, 0.8), _noise(1.5, 200, 0.4, 0.2, 2.0)))
	sfx["cart"] = _wav(_noise(0.6, 1500, 0.35, 0.02, 0.3))
	sfx["lighter"] = _wav(_noise(0.15, 6000, 0.4, 0.002, 0.05))
	sfx["struggle"] = _wav(_noise(0.3, 500, 0.7, 0.01, 0.1))
	sfx["pour"] = _wav(_noise(0.9, 2500, 0.25, 0.1, 0.6))
	sfx["chain"] = _wav(_mix(_tone(1800, 0.3, 0.1, 0.08, 0.0), _noise(0.3, 4000, 0.3, 0.005, 0.1)))


func _alarm(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (0.22 if fmod(t * 950.0, 1.0) < 0.5 else -0.22) * (1.0 if fmod(t, 0.3) < 0.2 else 0.0)
	return out


func _siren(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 700.0 + 300.0 * sin(TAU * t * 2.5)
		ph += f / RATE
		out[i] = (0.2 if fmod(ph, 1.0) < 0.5 else -0.2)
	return out


# ------------------------------------------------------------------ playback

func play_sfx(id: String, pos: Variant = null) -> void:
	var s: AudioStream = sfx.get(id)
	if s == null:
		return
	if pos == null or not (pos is Vector3):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = s
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		if id in ["alarm", "car_alarm"]:
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(p): p.queue_free())
		return
	var pl: AudioStreamPlayer3D = _pool.pop_front()
	_pool.append(pl)
	pl.stream = s
	pl.global_position = pos
	pl.volume_db = -4.0 if id.begins_with("step") else 0.0
	pl.pitch_scale = rng.randf_range(0.92, 1.08) if id.begins_with("step") else 1.0
	pl.play()
	if id in ["alarm", "car_alarm"]:
		get_tree().create_timer(4.0).timeout.connect(func(): pl.stop())


func _process(delta: float) -> void:
	_zone_check -= delta
	if _zone_check > 0.0:
		return
	_zone_check = 0.5
	var E := get_node("/root/Episode")
	var amb := "silence"
	if Services.world:
		var zd: Dictionary = Services.world.zone_def(E.hero_zone)
		amb = String(zd.get("ambience", "room"))
		if E.flags.get("rain_stopped", false) and amb.begins_with("rain"):
			amb = "dawn"
		if E.hero_zone == "ROOM_307" and E.flags.get("window_closed", false):
			amb = "room"
	if amb != amb_state:
		amb_state = amb
		_crossfade(amb_player, amb_player_b, _ambience(amb), -6.0)
		var t := amb_player
		amb_player = amb_player_b
		amb_player_b = t


func _crossfade(old: AudioStreamPlayer, new: AudioStreamPlayer, stream: AudioStream, vol: float) -> void:
	new.stream = stream
	new.volume_db = -40.0
	if stream:
		new.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new, "volume_db", vol, 1.2)
	tw.tween_property(old, "volume_db", -40.0, 1.2)
	tw.chain().tween_callback(old.stop)


func _ambience(id: String) -> AudioStream:
	if amb_cache.has(id):
		return amb_cache[id]
	var s: PackedFloat32Array
	match id:
		"rain_window":
			s = _mix(_noise(4.0, 2500, 0.18), _noise(4.0, 300, 0.12))
		"rain_heavy":
			s = _mix(_noise(4.0, 4500, 0.32), _noise(4.0, 500, 0.2))
		"fountain":
			s = _mix(_noise(4.0, 1800, 0.12), _noise(4.0, 6000, 0.04))
		"hum":
			s = _mix(_tone(60, 4.0, 0.06, 1000.0, 0.5), _noise(4.0, 200, 0.06))
		"machines":
			s = _mix(_tone(90, 4.0, 0.07, 1000.0, 0.7), _noise(4.0, 900, 0.1))
		"dawn":
			s = _noise(4.0, 900, 0.04)
			for k in 6:
				s = _mix(s, _tone(rng.randf_range(2600, 3600), 0.18, 0.05, 0.06, 0.0), rng.randi_range(0, int(3.6 * RATE)))
		"silence":
			return null
		_:
			s = _noise(4.0, 250, 0.05)
	# crossfade loop seam
	var fade := int(0.25 * RATE)
	for i in fade:
		var w := float(i) / fade
		s[i] = s[i] * w + s[s.size() - fade + i] * (1.0 - w)
	s.resize(s.size() - fade)
	var w := _wav(s, true)
	amb_cache[id] = w
	return w


# ------------------------------------------------------------------ music

const MUSIC := {
	"BAR_AMBIENT": {"notes": [57, 60, 64, 67, 64, 60, 62, 65], "step": 0.55, "decay": 1.2, "amp": 0.11, "drone": 45},
	"TENSION_LOW": {"notes": [45, 46], "step": 2.0, "decay": 3.0, "amp": 0.08, "drone": 33},
	"CLIENT_THEME_SPARSE": {"notes": [48, 0, 55, 0, 51, 0, 0, 0], "step": 0.9, "decay": 2.5, "amp": 0.1, "drone": 36},
	"INVESTIGATE_MINIMAL": {"notes": [69, 0, 0, 72, 0, 0, 67, 0], "step": 0.45, "decay": 0.4, "amp": 0.08, "drone": 45},
	"HUB_EXPLORE": {"notes": [57, 0, 64, 0, 60, 0, 62, 0], "step": 0.5, "decay": 0.6, "amp": 0.08, "drone": 45},
	"TAIL_TENSION": {"notes": [45, 0, 46, 0], "step": 0.35, "decay": 0.25, "amp": 0.1, "drone": 33},
	"STEALTH_LOW": {"notes": [40, 0, 0, 41, 0, 0], "step": 0.4, "decay": 0.3, "amp": 0.1, "drone": 28},
	"THOMAS_SORROW": {"notes": [52, 55, 59, 64, 59, 55], "step": 0.75, "decay": 1.4, "amp": 0.1, "drone": 40},
	"CHASE_START": {"notes": [45, 45, 57, 45, 48, 45, 57, 45], "step": 0.18, "decay": 0.12, "amp": 0.14, "drone": 33},
	"CHASE_1": {"notes": [45, 45, 57, 45, 48, 45, 57, 45], "step": 0.2, "decay": 0.12, "amp": 0.13, "drone": 33},
	"CHASE_2": {"notes": [45, 57, 48, 57, 45, 57, 50, 57], "step": 0.17, "decay": 0.1, "amp": 0.14, "drone": 33},
	"CHASE_3": {"notes": [57, 60, 57, 63, 57, 60, 57, 64], "step": 0.14, "decay": 0.09, "amp": 0.15, "drone": 33},
	"DOUBT": {"notes": [69], "step": 3.0, "decay": 6.0, "amp": 0.06, "drone": 0},
	"MARA_THEME": {"notes": [57, 60, 64, 67, 63, 60, 62, 65], "step": 0.7, "decay": 1.5, "amp": 0.1, "drone": 45},
	"FINALE_STAGING": {"notes": [76, 0, 76, 0], "step": 0.5, "decay": 0.05, "amp": 0.06, "drone": 40},
	"FINALE_LIVE": {"notes": [52, 55, 59, 55, 53, 57, 60, 57], "step": 0.6, "decay": 1.2, "amp": 0.08, "drone": 40},
	"EPILOGUE": {"notes": [64, 0, 67, 0, 72, 0, 0, 0], "step": 0.9, "decay": 2.0, "amp": 0.08, "drone": 0},
}


func set_music(state: String) -> void:
	if state == music_state:
		return
	music_state = state
	var stream: AudioStream = null
	if state != "SILENCE" and MUSIC.has(state):
		stream = _music(state)
	_crossfade(music_player, music_player_b, stream, -8.0 + linear_to_db(Settings.music_volume))
	var t := music_player
	music_player = music_player_b
	music_player_b = t


func _music(state: String) -> AudioStream:
	if music_cache.has(state):
		return music_cache[state]
	var m: Dictionary = MUSIC[state]
	var notes: Array = m.notes
	var step := float(m.step)
	var total := step * notes.size()
	var n := int(total * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	if int(m.drone) > 0:
		var f := 440.0 * pow(2.0, (int(m.drone) - 69) / 12.0)
		for i in n:
			var t := float(i) / RATE
			s[i] = sin(TAU * f * t) * 0.05 + sin(TAU * f * 1.5 * t) * 0.02
	for k in notes.size():
		var note := int(notes[k])
		if note <= 0:
			continue
		var f := 440.0 * pow(2.0, (note - 69) / 12.0)
		var tone := _tone(f, minf(float(m.decay) * 3.0, total), float(m.amp), float(m.decay), 0.25)
		var off := int(k * step * RATE)
		for i in tone.size():
			s[(off + i) % n] += tone[i]
	var w := _wav(s, true)
	music_cache[state] = w
	return w
