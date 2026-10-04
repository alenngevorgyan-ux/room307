class_name PhoneUI
extends PanelContainer
## The hero's phone (Tab). Does not pause the world. Shows messages plus whatever phone actions
## are available right now (data/ep01/phone.json): invitations, photo, map, texting Adrian.
## Entry: {tab, label, requires, actions, once, group}; using one entry of a group consumes the group.

var list: VBoxContainer
var header: Label
var _cursor := 0
var _entries: Array = []


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380
	offset_right = -24
	offset_top = -250
	offset_bottom = 250
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.06, 0.95)
	sb.border_color = Color(0.4, 0.42, 0.48)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	v.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	if Services.hero:
		Services.hero.set_lock("phone", true)
	_cursor = 0
	refresh()
	get_node("/root/Bus").player_decision.emit("phone")


func close() -> void:
	visible = false
	if Services.hero:
		Services.hero.set_lock("phone", false)


func available_entries() -> Array:
	var E := get_node("/root/Episode")
	var D := get_node("/root/Data")
	var out: Array = []
	var ids: Array = D.phone.keys()
	ids.sort_custom(func(a, b): return int(D.phone[a].get("order", 50)) < int(D.phone[b].get("order", 50)))
	for id in ids:
		var e: Dictionary = D.phone[id]
		if e.get("once", false) and E.flags.get("phone:" + id, false):
			continue
		if e.has("group") and E.flags.get("phone_group:" + String(e.group), false):
			continue
		if not Conditions.check(e.get("requires"), E):
			continue
		var c := e.duplicate()
		c["id"] = id
		out.append(c)
	return out


func use_entry(id: String) -> void:
	var E := get_node("/root/Episode")
	var e: Dictionary = get_node("/root/Data").phone.get(id, {})
	if e.is_empty():
		return
	E.flags["phone:" + id] = true
	if e.has("group"):
		E.flags["phone_group:" + String(e.group)] = true
	ActionRunner.run(e.get("actions", []), {"source": id})
	get_node("/root/Bus").player_decision.emit("phone_action")
	get_node("/root/Bus").sfx_requested.emit("phone_tap", null)
	refresh()


func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var E := get_node("/root/Episode")
	var D := get_node("/root/Data")
	_entries = available_entries()
	header.text = "☰ Телефон   [↑↓ Enter]   Tab — закрыть"
	var tabs := {"contacts": "Контакты", "camera": "Камера", "map": "Карта", "msg": "Сообщения"}
	var last_tab := ""
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var tab := String(e.get("tab", "contacts"))
		if tab != last_tab:
			var tl := Label.new()
			tl.text = tabs.get(tab, tab).to_upper()
			tl.add_theme_font_size_override("font_size", 12)
			tl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
			list.add_child(tl)
			last_tab = tab
		var b := Button.new()
		b.text = ("› " if i == _cursor else "  ") + String(e.label)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var id := String(e.id)
		b.pressed.connect(func(): use_entry(id))
		list.add_child(b)
	if E.flags.get("map_photo", false):
		var m := Label.new()
		m.text = String(D.phone.get("_map_text", "КАРТА: крыша (курилка) · служебная лестница · погрузка"))
		m.add_theme_font_size_override("font_size", 13)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(m)
	var ml := Label.new()
	ml.text = "СООБЩЕНИЯ"
	ml.add_theme_font_size_override("font_size", 12)
	ml.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	list.add_child(ml)
	var log: Array = E.phone_log
	for i in range(log.size() - 1, maxi(-1, log.size() - 9), -1):
		var msg: Dictionary = log[i]
		var l := Label.new()
		l.text = "%s: %s" % [D.npc_display(msg.from) if msg.from != "unknown" else "Неизвестный", msg.text]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 13)
		l.custom_minimum_size = Vector2(300, 0)
		list.add_child(l)
	if log.is_empty():
		var l := Label.new()
		l.text = "—"
		list.add_child(l)


func _process(_d: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("phone_down"):
		_cursor = mini(_cursor + 1, maxi(0, _entries.size() - 1))
		refresh()
	elif Input.is_action_just_pressed("phone_up"):
		_cursor = maxi(0, _cursor - 1)
		refresh()
	elif Input.is_action_just_pressed("phone_ok") and _cursor < _entries.size():
		use_entry(String(_entries[_cursor].id))
