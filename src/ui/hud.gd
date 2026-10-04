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
var subtitle: Label              # the spoken text (max ~2 lines; longer lines are paged)
var sub_name: Label              # speaker label above it: «НИКО», «НЕЗНАКОМЕЦ», «ЭЛ»
var sub_box: VBoxContainer
var sub_band: ColorRect          # soft dark band behind subtitles (readability on any background)
var chip_box: HBoxContainer
var chip_bar: ProgressBar
var prompt_box: HBoxContainer    # [E] поговорить · what
var prompt_key: Label
var prompt_key_panel: PanelContainer
var prompt_label: Label
var prompt_what: Label
var prompt_bar: ProgressBar
var obj_box: VBoxContainer       # the one current objective (top-left)
var obj_text: Label
var obj_sub: Label
var obj_accent: ColorRect
var opening: VBoxContainer       # THE VESPER / 02:17
var opening_tween: Tween
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
var _sub_queue: Array = []       # remaining pages of the current line: [{name, text, dur, thought}]
var _sub_cur: Dictionary = {}
var _band_a := 0.0
var _vig := 0.0
var _obj_id := ""
var _obj_t := 0.0                # seconds since the objective changed (bright, then settles)
var _obj_poll := 0.0
const SUB_WIDTH_FRAC := 0.62
const SUB_SIZE := 24
const TEXT_COLOR := Color(0.97, 0.95, 0.9)
const THOUGHT_COLOR := Color(0.86, 0.84, 0.78)


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
	B.thought_requested.connect(show_thought)
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
	# subtitles: bottom of the screen only — speaker label line + at most ~2 lines of text
	sub_band = ColorRect.new()
	sub_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_band.anchor_left = 0.1
	sub_band.anchor_right = 0.9
	sub_band.anchor_top = 1.0
	sub_band.anchor_bottom = 1.0
	sub_band.offset_top = -214
	sub_band.offset_bottom = -88
	var bsh := Shader.new()
	bsh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float x = 1.0 - smoothstep(0.18, 0.5, abs(UV.x - 0.5));
	float y = 1.0 - smoothstep(0.22, 0.5, abs(UV.y - 0.5));
	COLOR = vec4(0.015, 0.014, 0.018, 0.62 * x * y * amount);
}"""
	var bmat := ShaderMaterial.new()
	bmat.shader = bsh
	sub_band.material = bmat
	root.add_child(sub_band)
	sub_box = VBoxContainer.new()
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_box.anchor_left = 0.5 - SUB_WIDTH_FRAC / 2.0
	sub_box.anchor_right = 0.5 + SUB_WIDTH_FRAC / 2.0
	sub_box.anchor_top = 1.0
	sub_box.anchor_bottom = 1.0
	sub_box.offset_top = -200
	sub_box.offset_bottom = -100
	sub_box.alignment = BoxContainer.ALIGNMENT_END
	sub_box.add_theme_constant_override("separation", 2)
	root.add_child(sub_box)
	sub_name = _label(14, Color(0.85, 0.8, 0.7))
	sub_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nf := FontVariation.new()
	nf.base_font = ThemeDB.fallback_font
	nf.spacing_glyph = 3
	nf.variation_embolden = 0.6
	sub_name.add_theme_font_override("font", nf)
	sub_name.add_theme_constant_override("outline_size", 4)
	sub_box.add_child(sub_name)
	subtitle = _label(SUB_SIZE, TEXT_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	subtitle.add_theme_constant_override("line_spacing", 2)
	sub_box.add_child(subtitle)
	sub_box.visible = false
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
	# context prompt: a small key cap + a lower-case verb («E  поговорить»), never a name
	prompt_box = HBoxContainer.new()
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_theme_constant_override("separation", 8)
	prompt_box.visible = false
	root.add_child(prompt_box)
	prompt_key_panel = PanelContainer.new()
	prompt_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.93, 0.89, 0.8, 0.92)
	ksb.set_corner_radius_all(4)
	ksb.content_margin_left = 7
	ksb.content_margin_right = 7
	ksb.content_margin_top = 1
	ksb.content_margin_bottom = 2
	prompt_key_panel.add_theme_stylebox_override("panel", ksb)
	prompt_box.add_child(prompt_key_panel)
	prompt_key = Label.new()
	prompt_key.add_theme_font_size_override("font_size", 14)
	prompt_key.add_theme_color_override("font_color", Color(0.08, 0.07, 0.06))
	prompt_key_panel.add_child(prompt_key)
	prompt_label = _label(17, Color(0.97, 0.94, 0.86))
	prompt_label.add_theme_constant_override("outline_size", 5)
	prompt_box.add_child(prompt_label)
	prompt_what = _label(15, Color(0.8, 0.78, 0.72, 0.85))
	prompt_what.add_theme_constant_override("outline_size", 5)
	prompt_box.add_child(prompt_what)
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
	# (tutorial / system hints sit at the top centre, clear of the subtitle area)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -360
	hint_label.offset_right = 360
	hint_label.offset_top = 22
	hint_label.offset_bottom = 50
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate.a = 0.0
	root.add_child(hint_label)
	# the one current objective (top-left): bright when it changes, then it settles
	obj_box = VBoxContainer.new()
	obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_box.position = Vector2(30, 20)
	obj_box.size = Vector2(560, 60)
	obj_box.add_theme_constant_override("separation", 0)
	obj_box.modulate.a = 0.0
	root.add_child(obj_box)
	obj_text = _label(19, Color(0.96, 0.92, 0.82))
	obj_text.add_theme_constant_override("outline_size", 5)
	obj_box.add_child(obj_text)
	obj_sub = _label(15, Color(0.78, 0.76, 0.7))
	obj_sub.add_theme_constant_override("outline_size", 4)
	obj_box.add_child(obj_sub)
	obj_accent = ColorRect.new()
	obj_accent.color = Color(0.78, 0.62, 0.36, 0.85)
	obj_accent.position = Vector2(18, 25)
	obj_accent.size = Vector2(2, 20)
	obj_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_accent.modulate.a = 0.0
	root.add_child(obj_accent)
	# opening card (THE VESPER / 02:17)
	opening = VBoxContainer.new()
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opening.anchor_left = 0.0
	opening.anchor_top = 1.0
	opening.anchor_bottom = 1.0
	opening.offset_left = 64
	opening.offset_top = -250
	opening.offset_bottom = -150
	opening.add_theme_constant_override("separation", 2)
	opening.modulate.a = 0.0
	root.add_child(opening)
	var o1 := _label(40, Color(0.93, 0.88, 0.78))
	var of := FontVariation.new()
	of.base_font = ThemeDB.fallback_font
	of.spacing_glyph = 9
	o1.add_theme_font_override("font", of)
	o1.add_theme_constant_override("outline_size", 0)
	o1.name = "Place"
	opening.add_child(o1)
	var o2 := _label(22, Color(0.78, 0.8, 0.86))
	o2.add_theme_font_override("font", of)
	o2.add_theme_constant_override("outline_size", 0)
	o2.name = "Time"
	opening.add_child(o2)
	# threads
	threads_label = RichTextLabel.new()
	threads_label.bbcode_enabled = true
	threads_label.fit_content = true
	threads_label.scroll_active = false
	threads_label.position = Vector2(30, 76)
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
			_next_page()
	_band_a = move_toward(_band_a, 1.0 if sub_box.visible else 0.0, rd * 6.0)
	(sub_band.material as ShaderMaterial).set_shader_parameter("amount", _band_a)
	_update_objective(rd)
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
	var parts: Dictionary = hero.target_prompt_parts() if hero else {}
	# hidden while choosing what to say: the chips are the only prompt then
	if hero == null or cam == null or parts.is_empty() or phone.visible or _chips_on or letter_top.offset_bottom > 1.0:
		prompt_box.visible = false
		prompt_bar.visible = false
		return
	var p: Vector3
	if parts.get("at_hero", false) or hero.target == null:
		p = hero.global_position + Vector3(0, 1.0, 0) + hero.facing * 0.6
	else:
		var t: Node3D = hero.target
		match hero.target_kind:
			"interact": p = t.global_position + Vector3(0, 0.45, 0)
			"npc": p = t.global_position + Vector3(0, 1.15, 0)   # chest height: clear of the face
			_: p = t.global_position + Vector3(0, 1.0, 0)
	if not cam.is_position_in_frustum(p):
		prompt_box.visible = false
		prompt_bar.visible = false
		return
	var key := String(parts.get("key", ""))
	prompt_key.text = key
	prompt_key_panel.visible = key != ""
	prompt_label.text = String(parts.get("verb", ""))
	prompt_label.modulate.a = 1.0 if key != "" else 0.7
	prompt_what.text = String(parts.get("what", ""))
	prompt_what.visible = prompt_what.text != ""
	prompt_box.visible = true
	prompt_box.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(p) + Vector2(18, -prompt_box.size.y / 2.0)
	# keep it on screen and above the subtitle area so it never covers what is being said
	sp.x = clampf(sp.x, 16.0, vp.x - prompt_box.size.x - 16.0)
	sp.y = clampf(sp.y, 90.0, vp.y - 236.0)
	prompt_box.position = sp
	var hp := hero.hold_progress()
	prompt_bar.visible = hp > 0.0
	prompt_bar.value = hp
	prompt_bar.position = sp + Vector2(0, prompt_box.size.y + 3)


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

## Bottom-screen subtitle (playtest findings 6–7):
##   НИКО
##   Да уж. Только не ты.
## The speaker label is the only place a name ever appears; unknown speakers read «НЕЗНАКОМЕЦ»
## (SpeakerNames). Text longer than two lines is split into pages timed by length.
func _on_line(speaker: String, text: String, dur: float) -> void:
	_show_sub(SpeakerNames.label(speaker), _name_color(speaker), text, dur, false)


## Ambient bark from a nearby NPC; never interrupts a line that is playing.
func show_bark(speaker: String, text: String, dur: float) -> void:
	if sub_box.visible and _sub_t > 0.3:
		return
	_show_sub(SpeakerNames.label(speaker), _name_color(speaker), text, dur, false)


## Level-3 hint: EL thinking (italic, no name, quieter).
func show_thought(text: String, dur: float = 3.5) -> void:
	if sub_box.visible and _sub_t > 0.3:
		return
	_show_sub("", Color.WHITE, text, dur, true)


func subtitle_busy() -> bool:
	return sub_box.visible and _sub_t > 0.0


func _name_color(speaker: String) -> Color:
	var c: Color = SPEAKER_COLORS.get(speaker, Color(0.85, 0.85, 0.85))
	return c.lerp(Color(0.86, 0.82, 0.74), 0.55)   # a hint of identity, not a colour code


func _show_sub(who: String, col: Color, text: String, dur: float, thought: bool) -> void:
	var size := int(SUB_SIZE * Settings.subtitle_scale)
	var width := get_viewport().get_visible_rect().size.x * SUB_WIDTH_FRAC
	var pages := paginate(text, ThemeDB.fallback_font, size, width)
	var total := 0
	for p in pages:
		total += String(p).length()
	_sub_queue = []
	for p in pages:
		var share := float(String(p).length()) / float(maxi(total, 1))
		_sub_queue.append({"name": who, "col": col, "text": p, "dur": maxf(1.3, dur * share), "thought": thought})
	_next_page()


func _next_page() -> void:
	if _sub_queue.is_empty():
		sub_box.visible = false
		subtitle.text = ""
		_sub_cur = {}
		return
	_sub_cur = _sub_queue.pop_front()
	var size := int(SUB_SIZE * Settings.subtitle_scale)
	subtitle.add_theme_font_size_override("font_size", size)
	subtitle.text = String(_sub_cur.text)
	sub_name.text = String(_sub_cur.name)
	sub_name.visible = sub_name.text != ""
	sub_name.add_theme_color_override("font_color", _sub_cur.col)
	var thought: bool = _sub_cur.thought
	subtitle.add_theme_color_override("font_color", THOUGHT_COLOR if thought else TEXT_COLOR)
	if thought:
		subtitle.add_theme_font_override("font", _italic_font())
	else:
		subtitle.remove_theme_font_override("font")
	sub_box.visible = true
	_sub_t = float(_sub_cur.dur) + (0.15 if _sub_queue.is_empty() else 0.0)


var _italic: FontVariation = null


func _italic_font() -> Font:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = ThemeDB.fallback_font
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.18, 1), Vector2.ZERO)
	return _italic


## Splits text into pages of at most `max_lines` wrapped lines at `width`, preferring sentence ends.
static func paginate(text: String, font: Font, size: int, width: float, max_lines: int = 2) -> Array:
	if _lines(text, font, size, width) <= max_lines:
		return [text]
	var pages: Array = []
	var cur := ""
	for s in _sentences(text):
		var t: String = s if cur == "" else cur + " " + s
		if _lines(t, font, size, width) <= max_lines:
			cur = t
			continue
		if cur != "":
			pages.append(cur)
		cur = s
		while _lines(cur, font, size, width) > max_lines:
			var words := cur.split(" ")
			var head := ""
			var i := 0
			while i < words.size() and _lines((head + " " + words[i]).strip_edges(), font, size, width) <= max_lines:
				head = (head + " " + words[i]).strip_edges()
				i += 1
			if head == "":
				break
			pages.append(head)
			cur = " ".join(words.slice(i))
	if cur != "":
		pages.append(cur)
	return pages


static func _lines(text: String, font: Font, size: int, width: float) -> int:
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
	return int(round(h / font.get_height(size)))


static func _sentences(text: String) -> Array:
	var out: Array = []
	var cur := ""
	for i in text.length():
		cur += text[i]
		var nxt := text[i + 1] if i + 1 < text.length() else " "
		if text[i] in [".", "?", "!", "…"] and nxt == " ":
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


# ================================================================== objective / opening

func _update_objective(rd: float) -> void:
	_obj_poll -= rd
	if _obj_poll <= 0.0:
		_obj_poll = 0.25
		var o := Objectives.current()
		var id := String(o.get("id", ""))
		if id != _obj_id:
			_obj_id = id
			_obj_t = 0.0
			obj_text.text = String(o.get("text", ""))
			obj_sub.text = String(o.get("sub", ""))
			obj_sub.visible = obj_sub.text != ""
			if id != "":
				get_node("/root/Bus").sfx_requested.emit("chime", null)
	_obj_t += rd
	var target := 0.0
	if _obj_id != "" and not phone.visible:
		# bright for a few seconds after it changes, then a quiet reminder; dimmer during cines
		target = 1.0 if _obj_t < 7.0 else 0.58
		if letter_top.offset_bottom > 1.0:
			target = 0.0 if _obj_t >= 7.0 else 0.85
	var a := move_toward(obj_box.modulate.a, target, rd * (2.5 if target > obj_box.modulate.a else 0.8))
	obj_box.modulate.a = a
	obj_accent.modulate.a = a
	obj_box.position.x = 30.0 + 10.0 * (1.0 - clampf(_obj_t / 0.6, 0.0, 1.0))


func show_opening(place: String, time: String, hold: float = 4.0) -> void:
	(opening.get_node("Place") as Label).text = place
	(opening.get_node("Time") as Label).text = time
	if opening_tween:
		opening_tween.kill()
	var tw := create_tween()
	opening_tween = tw
	tw.set_ignore_time_scale(true)
	tw.tween_property(opening, "modulate:a", 1.0, 1.4).set_delay(0.6)
	tw.tween_interval(hold)
	tw.tween_property(opening, "modulate:a", 0.0, 1.6)


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
	pause_menu.offset_top = -190
	pause_menu.offset_bottom = 190
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
	var cont := Button.new()
	cont.text = "Загрузить последний чекпоинт"
	cont.pressed.connect(func():
		toggle_pause()
		if Services.scenes and Services.scenes.has_method("restart_episode"):
			Services.scenes.restart_episode(true))
	v.add_child(cont)
	var restart := Button.new()
	restart.text = "Начать эпизод заново"
	restart.pressed.connect(func():
		toggle_pause()
		if Services.scenes and Services.scenes.has_method("restart_episode"):
			Services.scenes.restart_episode(false))
	v.add_child(restart)
	if OS.get_name() != "Web":
		var logs := Button.new()
		logs.text = "Папка с логами плейтеста"
		logs.pressed.connect(func():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
			OS.shell_open(ProjectSettings.globalize_path("user://playtest")))
		v.add_child(logs)
	var quit := Button.new()
	quit.text = "Выйти"
	quit.pressed.connect(func(): get_tree().quit())
	if OS.get_name() == "Web":
		quit.text = "Выйти (закройте вкладку)"
		quit.disabled = true
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
