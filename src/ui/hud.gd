class_name HUD
extends CanvasLayer
## Minimal, diegetic-leaning UI (ASSET_MANIFEST §8): subtitles, chips, context prompt, hints,
## threads, phone, READ vignette + reticle, fades, letterbox, struggle prompt, edge indicator,
## title cards, captions (3D), pause menu. Never freezes play except the pause menu.

const VERB_ICON := {"PRESS": "▲", "DEFLECT": "↺", "BLUFF": "◆", "PROVOKE": "✶", "CALM": "○", "RELEASE": "→",
	"LIE": "◆", "TRUTH": "○", "SILENCE": "…", "ACT": "●", "ASK": "?", "": "·"}
const SPEAKER_COLORS := {"hero": Color(0.85, 0.85, 0.8), "adrian": Color(0.55, 0.7, 1.0), "mara": Color(1.0, 0.5, 0.45),
	"thomas": Color(0.85, 0.65, 0.4), "daniel": Color(0.75, 0.75, 0.78), "eva": Color(1.0, 0.85, 0.3),
	"nico": Color(0.5, 0.9, 0.55), "lina": Color(0.6, 0.85, 1.0), "pavel": Color(0.7, 0.7, 0.7),
	"hale": Color(0.95, 0.6, 0.3), "selin": Color(0.95, 0.5, 0.8), "kai": Color(0.6, 0.95, 0.85),
	"jules": Color(0.8, 0.8, 0.5), "brody": Color(0.9, 0.35, 0.3), "sato": Color(0.95, 0.45, 0.4),
	"voice": Color(0.8, 0.8, 0.9), "pa": Color(0.7, 0.8, 0.9)}

var root: Control
var subtitle: RichTextLabel
var chip_box: HBoxContainer
var chip_bar: ProgressBar
var prompt_label: Label
var prompt_bar: ProgressBar
var hint_label: Label
var threads_label: RichTextLabel
var items_label: Label
var fade_rect: ColorRect
var vignette: ColorRect
var reticle: Control
var letter_top: ColorRect
var letter_bot: ColorRect
var title_label: Label
var sub_title_label: Label
var struggle: Label
var edge: Label
var phone: PhoneUI
var pause_menu: Control
var toast: Label

var _sub_t := 0.0
var _hint_t := 0.0
var _chips_t := 0.0
var _chips_total := 1.0
var _chips_on := false
var _title_t := 0.0
var _toast_t := 0.0
var _threads_expanded := false
var _q_held := 0.0
var read_on := false
var read_focus := 0.0
var reticle_pos := Vector2.ZERO
var _sub_queue: Array = []
var _vig := 0.0


func _ready() -> void:
	Services.hud = self
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build()
	var B := get_node("/root/Bus")
	B.line_started.connect(_on_line)
	B.chips_shown.connect(_on_chips)
	B.chips_cleared.connect(_on_chips_cleared)
	B.hint_requested.connect(show_hint)
	B.caption_shown.connect(_on_caption)
	B.thread_offered.connect(func(t: String): _flash_threads())
	B.thread_pinned.connect(func(t: String): get_node("/root/Bus").sfx_requested.emit("chime", null))
	B.phone_message.connect(_on_phone_msg)
	B.fade_requested.connect(func(d: float): fade(d, true); get_tree().create_timer(d, true, false, true).timeout.connect(func(): fade(d, false)))


func _exit_tree() -> void:
	if Services.hud == self:
		Services.hud = null


func _label(size: int, c: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	# READ vignette
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.25, 0.75, length(uv * vec2(1.25, 1.0)));
	COLOR = vec4(0.02, 0.02, 0.03, v * 0.85 * amount);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vignette.material = mat
	root.add_child(vignette)
	reticle = Control.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.draw.connect(_draw_reticle)
	root.add_child(reticle)
	# letterbox
	letter_top = ColorRect.new()
	letter_top.color = Color.BLACK
	letter_top.anchor_right = 1.0
	letter_top.offset_bottom = 0
	letter_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(letter_top)
	letter_bot = ColorRect.new()
	letter_bot.color = Color.BLACK
	letter_bot.anchor_top = 1.0
	letter_bot.anchor_right = 1.0
	letter_bot.anchor_bottom = 1.0
	letter_bot.offset_top = 0
	letter_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(letter_bot)
	# subtitles
	subtitle = RichTextLabel.new()
	subtitle.bbcode_enabled = true
	subtitle.fit_content = true
	subtitle.scroll_active = false
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.anchor_left = 0.15
	subtitle.anchor_right = 0.85
	subtitle.anchor_top = 1.0
	subtitle.anchor_bottom = 1.0
	subtitle.offset_top = -150
	subtitle.offset_bottom = -95
	subtitle.add_theme_font_size_override("normal_font_size", 22)
	subtitle.add_theme_font_size_override("bold_font_size", 22)
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	subtitle.add_theme_constant_override("outline_size", 7)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	# chips
	chip_box = HBoxContainer.new()
	chip_box.anchor_left = 0.5
	chip_box.anchor_right = 0.5
	chip_box.anchor_top = 1.0
	chip_box.anchor_bottom = 1.0
	chip_box.offset_left = -440
	chip_box.offset_right = 440
	chip_box.offset_top = -84
	chip_box.offset_bottom = -44
	chip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_box.add_theme_constant_override("separation", 12)
	chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chip_box)
	chip_bar = ProgressBar.new()
	chip_bar.show_percentage = false
	chip_bar.anchor_left = 0.5
	chip_bar.anchor_right = 0.5
	chip_bar.anchor_top = 1.0
	chip_bar.anchor_bottom = 1.0
	chip_bar.offset_left = -160
	chip_bar.offset_right = 160
	chip_bar.offset_top = -38
	chip_bar.offset_bottom = -34
	chip_bar.max_value = 1.0
	chip_bar.visible = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.85, 0.6, 0.85)
	chip_bar.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(1, 1, 1, 0.12)
	chip_bar.add_theme_stylebox_override("background", bgs)
	chip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chip_bar)
	# context prompt
	prompt_label = _label(17, Color(1, 0.92, 0.75))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size = Vector2(360, 26)
	root.add_child(prompt_label)
	prompt_bar = ProgressBar.new()
	prompt_bar.show_percentage = false
	prompt_bar.max_value = 1.0
	prompt_bar.size = Vector2(120, 5)
	prompt_bar.visible = false
	prompt_bar.add_theme_stylebox_override("fill", fill)
	prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_bar)
	# hint
	hint_label = _label(18, Color(0.95, 0.95, 0.9, 0.9))
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -300
	hint_label.offset_right = 300
	hint_label.offset_top = -200
	hint_label.offset_bottom = -170
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	# threads
	threads_label = RichTextLabel.new()
	threads_label.bbcode_enabled = true
	threads_label.fit_content = true
	threads_label.scroll_active = false
	threads_label.position = Vector2(18, 14)
	threads_label.size = Vector2(520, 200)
	threads_label.add_theme_font_size_override("normal_font_size", 15)
	threads_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	threads_label.add_theme_constant_override("outline_size", 5)
	threads_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(threads_label)
	items_label = _label(14, Color(0.8, 0.85, 0.9, 0.8))
	items_label.anchor_left = 1.0
	items_label.anchor_right = 1.0
	items_label.offset_left = -420
	items_label.offset_right = -18
	items_label.offset_top = 14
	items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(items_label)
	# struggle + edge + toast
	struggle = _label(30, Color(1, 0.5, 0.4))
	struggle.anchor_left = 0.5
	struggle.anchor_right = 0.5
	struggle.anchor_top = 0.5
	struggle.offset_left = -250
	struggle.offset_right = 250
	struggle.offset_top = 60
	struggle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	struggle.visible = false
	root.add_child(struggle)
	edge = _label(34, Color(1, 0.2, 0.15))
	edge.visible = false
	root.add_child(edge)
	toast = _label(16, Color(0.9, 0.95, 1.0))
	toast.anchor_left = 1.0
	toast.anchor_right = 1.0
	toast.offset_left = -420
	toast.offset_right = -18
	toast.offset_top = 40
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(toast)
	# title
	title_label = _label(54, Color(0.95, 0.92, 0.85))
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = -500
	title_label.offset_right = 500
	title_label.offset_top = -60
	title_label.offset_bottom = 10
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate.a = 0.0
	root.add_child(title_label)
	sub_title_label = _label(22, Color(0.8, 0.8, 0.8))
	sub_title_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_title_label.offset_left = -500
	sub_title_label.offset_right = 500
	sub_title_label.offset_top = 14
	sub_title_label.offset_bottom = 50
	sub_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_title_label.modulate.a = 0.0
	root.add_child(sub_title_label)
	# phone
	phone = PhoneUI.new()
	root.add_child(phone)
	# fade on top
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	_build_pause()


# ================================================================== frame

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05) if not get_tree().paused else delta
	if _sub_t > 0.0:
		_sub_t -= rd
		if _sub_t <= 0.0:
			subtitle.text = ""
	if _hint_t > 0.0:
		_hint_t -= rd
		hint_label.modulate.a = clampf(_hint_t / 0.5, 0, 1)
	if _toast_t > 0.0:
		_toast_t -= rd
		toast.modulate.a = clampf(_toast_t / 0.6, 0, 1)
	if _title_t > 0.0:
		_title_t -= rd
		var a := clampf(_title_t / 0.8, 0, 1)
		title_label.modulate.a = a
		sub_title_label.modulate.a = a
	if _chips_on and _chips_total > 0.0:
		_chips_t -= delta   # game time (READ slows the timeout too)
		chip_bar.value = clampf(_chips_t / _chips_total, 0, 1)
	_update_prompt()
	_update_threads(rd)
	_update_items()
	_vig = move_toward(_vig, 1.0 if read_on else 0.0, rd * 5.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("amount", _vig)
	reticle.queue_redraw()


func _update_prompt() -> void:
	var hero: PlayerController = Services.hero
	var cam := get_viewport().get_camera_3d()
	if hero == null or cam == null or hero.target == null or phone.visible:
		prompt_label.visible = false
		prompt_bar.visible = false
		return
	var t: Node3D = hero.target
	var p := t.global_position + Vector3(0, 1.0 if hero.target_kind != "npc" else 2.0, 0)
	if hero.target_kind == "interact":
		p = t.global_position + Vector3(0, 0.45, 0)
	if not cam.is_position_in_frustum(p):
		prompt_label.visible = false
		return
	var sp := cam.unproject_position(p)
	prompt_label.text = hero.target_prompt()
	prompt_label.visible = prompt_label.text != ""
	prompt_label.position = sp - Vector2(180, 30)
	var hp := hero.hold_progress()
	prompt_bar.visible = hp > 0.0
	prompt_bar.value = hp
	prompt_bar.position = sp - Vector2(60, 2)


func _update_threads(rd: float) -> void:
	var E := get_node("/root/Episode")
	var D := get_node("/root/Data")
	if Input.is_action_pressed("threads") and not phone.visible:
		_q_held += rd
	else:
		if _q_held > 0.0 and _q_held < 0.35:
			_pin_next()
		_q_held = 0.0
	_threads_expanded = _q_held >= 0.35
	var t := ""
	for tid in E.threads_pinned:
		t += "[color=#f2e6c8]— %s[/color]\n" % D.threads.get(tid, {}).get("text", tid)
	for tid in E.threads_struck:
		if _threads_expanded:
			t += "[color=#777777][s]%s[/s][/color]\n" % D.threads.get(tid, {}).get("text", tid)
	if not E.threads_available.is_empty():
		var first: String = E.threads_available[0]
		t += "[color=#b8c8d8][i]%s[/i]   [Q] закрепить[/color]\n" % D.threads.get(first, {}).get("text", first)
		if _threads_expanded:
			for i in range(1, E.threads_available.size()):
				var tid: String = E.threads_available[i]
				t += "[color=#8898a8][i]%s[/i][/color]\n" % D.threads.get(tid, {}).get("text", tid)
	threads_label.text = t


func _pin_next() -> void:
	var E := get_node("/root/Episode")
	if E.threads_available.is_empty():
		return
	E.pin_thread(E.threads_available[0])


func _flash_threads() -> void:
	threads_label.modulate = Color(1.4, 1.3, 1.0)
	var tw := create_tween()
	tw.tween_property(threads_label, "modulate", Color.WHITE, 1.2)


func _update_items() -> void:
	var E := get_node("/root/Episode")
	var D := get_node("/root/Data")
	var names: Array = []
	for it in E.items:
		if E.items[it] == "hero" and not D.items.get(it, {}).get("hidden", false):
			names.append(String(D.items.get(it, {}).get("short", it)))
	items_label.text = "  ·  ".join(names)


# ================================================================== subtitles / chips

func _on_line(speaker: String, text: String, dur: float) -> void:
	var D := get_node("/root/Data")
	var c: Color = SPEAKER_COLORS.get(speaker, Color(0.85, 0.85, 0.85))
	var who: String = D.npc_display(speaker)
	if speaker == "hero":
		subtitle.text = "[center][color=#%s]%s[/color][/center]" % [c.to_html(false), text]
	else:
		subtitle.text = "[center][b][color=#%s]%s:[/color][/b] %s[/center]" % [c.to_html(false), who, text]
	subtitle.add_theme_font_size_override("normal_font_size", int(22 * Settings.subtitle_scale))
	subtitle.add_theme_font_size_override("bold_font_size", int(22 * Settings.subtitle_scale))
	_sub_t = dur + 0.15


func _on_chips(_xid: String, chips: Array, timeout: float) -> void:
	for c in chip_box.get_children():
		c.queue_free()
	var i := 1
	for ch in chips:
		var b := Button.new()
		b.text = "%d  %s %s" % [i, VERB_ICON.get(String(ch.verb), "·"), ch.label]
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.1, 0.82)
		sb.border_color = Color(0.95, 0.85, 0.6, 0.7)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate()
		sbh.bg_color = Color(0.2, 0.18, 0.14, 0.9)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var idx := i - 1
		b.pressed.connect(func(): if Services.conversation: Services.conversation.choose(idx))
		chip_box.add_child(b)
		i += 1
	_chips_on = true
	_chips_total = timeout
	_chips_t = timeout
	chip_bar.visible = timeout > 0.0
	chip_bar.value = 1.0


func _on_chips_cleared() -> void:
	for c in chip_box.get_children():
		c.queue_free()
	_chips_on = false
	chip_bar.visible = false


# ================================================================== misc

func show_hint(text: String, dur: float = 3.0) -> void:
	hint_label.text = text
	_hint_t = dur
	hint_label.modulate.a = 1.0


func show_toast(text: String, dur: float = 4.0) -> void:
	toast.text = text
	_toast_t = dur
	toast.modulate.a = 1.0


func show_title(t: String, sub: String = "", dur: float = 4.0) -> void:
	title_label.text = t
	sub_title_label.text = sub
	_title_t = dur
	title_label.modulate.a = 1.0
	sub_title_label.modulate.a = 1.0


func fade(dur: float, to_black: bool) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(fade_rect, "color:a", 1.0 if to_black else 0.0, dur)


func set_fade(a: float) -> void:
	fade_rect.color.a = a


func letterbox(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(letter_top, "offset_bottom", 70.0 if on else 0.0, 0.4)
	tw.tween_property(letter_bot, "offset_top", -70.0 if on else 0.0, 0.4)


func set_struggle(text: String) -> void:
	struggle.text = text
	struggle.visible = text != ""


func set_edge(on: bool, screen_pos: Vector2 = Vector2.ZERO, glyph: String = "›") -> void:
	edge.visible = on
	if on:
		edge.text = glyph
		edge.position = screen_pos


func _on_caption(_obs: String, text: String, pos: Vector3) -> void:
	if Services.world == null:
		return
	var c := Caption3D.new()
	Services.world.add_child(c)
	c.show_caption(text, pos)


func _on_phone_msg(from: String, text: String) -> void:
	var D := get_node("/root/Data")
	show_toast("✉ %s: %s" % [D.npc_display(from) if from != "unknown" else "Неизвестный", text], 5.0)
	get_node("/root/Bus").sfx_requested.emit("sms", null)


func set_read_active(on: bool) -> void:
	read_on = on
	if not on:
		read_focus = 0.0


func set_read_focus(pos: Vector2, progress: float) -> void:
	reticle_pos = pos
	read_focus = progress


func _draw_reticle() -> void:
	if not read_on:
		return
	var r := 18.0
	reticle.draw_arc(reticle_pos, r, 0, TAU, 40, Color(0.95, 0.92, 0.8, 0.75), 1.5, true)
	if read_focus > 0.0:
		reticle.draw_arc(reticle_pos, r + 5, -PI / 2, -PI / 2 + TAU * clampf(read_focus, 0, 1), 40, Color(1, 0.85, 0.5, 0.95), 2.5, true)
	if Settings.read_assist and Services.read:
		var cam := get_viewport().get_camera_3d()
		if cam and Services.hero:
			for n in get_tree().get_nodes_in_group("observables"):
				var o := n as Observable
				if o and o.readable() and o.global_position.distance_to(Services.hero.global_position) <= o.max_distance and cam.is_position_in_frustum(o.global_position):
					reticle.draw_circle(cam.unproject_position(o.global_position), 3.0, Color(1, 1, 1, 0.18 + 0.1 * sin(Time.get_ticks_msec() / 200.0)))


# ================================================================== pause

func _build_pause() -> void:
	pause_menu = PanelContainer.new()
	pause_menu.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu.offset_left = -170
	pause_menu.offset_right = 170
	pause_menu.offset_top = -150
	pause_menu.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	pause_menu.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_menu.add_child(v)
	var t := _label(26)
	t.text = "Пауза"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := Button.new()
	resume.text = "Продолжить"
	resume.pressed.connect(toggle_pause)
	v.add_child(resume)
	var assist := CheckButton.new()
	assist.text = "Подсказки READ"
	assist.button_pressed = Settings.read_assist
	assist.toggled.connect(func(on: bool): Settings.read_assist = on)
	v.add_child(assist)
	var subs := HSlider.new()
	subs.min_value = 0.8
	subs.max_value = 1.6
	subs.step = 0.1
	subs.value = Settings.subtitle_scale
	subs.value_changed.connect(func(x: float): Settings.subtitle_scale = x)
	var sl := _label(14)
	sl.text = "Размер субтитров"
	v.add_child(sl)
	v.add_child(subs)
	var save := Button.new()
	save.text = "Сохранить чекпойнт"
	save.pressed.connect(func(): get_node("/root/Episode").save_game(); show_toast("Сохранено", 2.0))
	v.add_child(save)
	var quit := Button.new()
	quit.text = "Выйти"
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	pause_menu.visible = false
	root.add_child(pause_menu)


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_menu.visible = p
	if p:
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if phone.visible:
			phone.close()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("phone") and not get_tree().paused:
		phone.toggle()
		get_viewport().set_input_as_handled()
