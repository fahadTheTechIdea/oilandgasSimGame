extends CanvasLayer
## Management-style HUD: resource chips, build panel, inspector, objective,
## minimap and toasts. Built entirely in code.

signal tool_selected(kind: String)
signal bulldoze_selected()
signal loan_requested()
signal speed_selected(mult: float)
signal difficulty_selected(money: float)
signal victory_dismissed()
signal run_selected(kind: String, id: int)
signal help_toggled(open: bool)
signal minimap_target(cell: Vector2i)
signal restart_requested()
signal unit_action(action: String)

const ACCENT := Color(0.90, 0.72, 0.16)
const TEXT := Color(0.92, 0.94, 0.90)
const MUTED := Color(0.64, 0.69, 0.61)
const GOOD := Color(0.56, 0.86, 0.52)
const BAD := Color(0.94, 0.47, 0.40)
const PANEL_BG := Color(0.065, 0.082, 0.062, 0.92)
const PANEL_LINE := Color(0.30, 0.35, 0.26)


class Minimap extends Control:
	signal cell_clicked(cell: Vector2i)
	var cells: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.07, 0.05))
		var s := size.x / 44.0
		for c in cells:
			var col: Color = c[2]
			draw_rect(Rect2(float(c[0]) * s, float(c[1]) * s, maxf(s, 1.6), maxf(s, 1.6)), col)
		draw_rect(Rect2(Vector2.ZERO, size), PANEL_LINE, false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var s := size.x / 44.0
				var cx := clampi(int(mb.position.x / s), 0, 43)
				var cy := clampi(int(mb.position.y / s), 0, 43)
				cell_clicked.emit(Vector2i(cx, cy))
				accept_event()


var chips: Dictionary = {}
var objective_label: Label
var network_label: Label
var inspector_title: Label
var inspector_body: Label
var toast_label: Label
var hint_label: Label
var minimap: Minimap
var tool_buttons: Dictionary = {}
var costs: Dictionary = {}
var _entries: Array = []
var _fleet: Dictionary = {}
var _victory_root: Control
var _game_over_root: Control
var _help_root: Control
var _root: Control
var _runs_box: VBoxContainer
var _runs_title: Label
var _runs_sig := ""
var _build_list: VBoxContainer
var _build_filter := ""
var _unit_panel: PanelContainer
var _unit_title: Label
var _unit_actions: HBoxContainer

var _toast_time: float = 0.0
var _cash: float = 0.0


func _ready() -> void:
	layer = 10
	_build()


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time, 0.0, 1.0)
		if _toast_time <= 0.0:
			toast_label.visible = false


# --------------------------------------------------------------------------- #
# construction
# --------------------------------------------------------------------------- #

func _panel(alpha: float = 0.92, textured: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	if textured:
		var tex: Texture2D = load("res://assets/textures/ui_panel.png")
		if tex != null:
			var st := StyleBoxTexture.new()
			st.texture = tex
			st.texture_margin_left = 30
			st.texture_margin_right = 30
			st.texture_margin_top = 30
			st.texture_margin_bottom = 30
			st.content_margin_left = 12
			st.content_margin_right = 12
			st.content_margin_top = 9
			st.content_margin_bottom = 9
			p.add_theme_stylebox_override("panel", st)
			return p
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, alpha)
	sb.border_color = PANEL_LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


var icons: Array = []


func _build_icons() -> void:
	var sheet: Texture2D = load("res://assets/textures/ui_icons.png")
	if sheet == null:
		return
	var img: Image = sheet.get_image()
	if img == null:
		return
	var cw := int(img.get_width() / 4)
	var ch := int(img.get_height() / 2)
	var side := mini(cw, ch)
	for row in 2:
		for col in 4:
			var r := Rect2i(col * cw, row * ch + int((ch - side) * 0.5), side, side)
			var sub := img.get_region(r)
			sub.resize(28, 28, Image.INTERPOLATE_LANCZOS)
			icons.append(ImageTexture.create_from_image(sub))


func _button(text: String, w: float = 196.0, h: float = 40.0, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	if icon != null:
		b.icon = icon
		b.expand_icon = true
	return b


## Per-structure icon by convention: assets/icons/<id>.png, with the old atlas
## icon_index kept as a fallback.
func _entry_icon(e) -> Texture2D:
	var tex := _load_texture(e.icon_path)
	if tex != null:
		return tex
	var idx := int(e.icon_index)
	if idx >= 0 and idx < icons.size():
		return icons[idx]
	return null


func _load_texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func _add_tool_button(list: VBoxContainer, e) -> void:
	var b := _button("", 196, 38, _entry_icon(e))
	var kind: String = e.id
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		tool_selected.emit(kind)
	)
	list.add_child(b)
	tool_buttons[kind] = {"btn": b, "key": e.hotkey, "name": e.display_name}


func _on_build_filter_changed(text: String) -> void:
	_build_filter = text
	_populate_build()


func _entry_category(e) -> String:
	var cat := String(e.category)
	return "OTHER" if cat == "" else cat


func _build_matches(e, needle: String) -> bool:
	if not e.buildable:
		return false
	if needle == "":
		return true
	return String(e.display_name).to_lower().contains(needle) \
		or String(e.id).to_lower().contains(needle)


## Rebuilds the build list from the catalogue, grouped by first-seen category.
## The bulldoze button lives outside the list, so it survives every filter.
func _populate_build() -> void:
	if _build_list == null:
		return
	for child in _build_list.get_children():
		_build_list.remove_child(child)
		child.queue_free()
	var stale: Array = []
	for k in tool_buttons.keys():
		if k != "bulldoze":
			stale.append(k)
	for k in stale:
		tool_buttons.erase(k)
	var needle := _build_filter.strip_edges().to_lower()
	var cats: Array[String] = []
	for e in _entries:
		if not _build_matches(e, needle):
			continue
		var cat := _entry_category(e)
		if not (cat in cats):
			cats.append(cat)
	if cats.is_empty():
		_build_list.add_child(_label("no matches", 11, MUTED))
		return
	var priority := {"FLEET": 0, "UPSTREAM": 1, "STORAGE": 2, "PROCESSING": 3,
		"REFINING": 4, "INFRASTRUCTURE": 5, "BASE": 6, "OTHER": 7}
	cats.sort_custom(func(a: String, b: String) -> bool:
		return int(priority.get(a, 9)) < int(priority.get(b, 9)))
	for cat in cats:
		_build_list.add_child(HSeparator.new())
		_build_list.add_child(_label(cat.to_upper(), 10, MUTED))
		for e in _entries:
			if _entry_category(e) == cat and _build_matches(e, needle):
				_add_tool_button(_build_list, e)


func _chip(caption: String) -> Label:
	var p := _panel(0.75, false)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	p.add_child(vb)
	var cap := _label(caption.to_upper(), 9, MUTED)
	vb.add_child(cap)
	var val := _label("—", 15, TEXT)
	vb.add_child(val)
	var host := HBoxContainer.new()
	host.add_child(p)
	_chip_host.add_child(host)
	return val


var _chip_host: HBoxContainer


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root
	_build_icons()

	# ---- top bar ----------------------------------------------------------- #
	var top := _panel(0.9)
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top.add_child(top_row)

	var brand := _label("OILFIELD TYCOON", 15, ACCENT)
	top_row.add_child(brand)
	var vsep := VSeparator.new()
	top_row.add_child(vsep)

	_chip_host = HBoxContainer.new()
	_chip_host.add_theme_constant_override("separation", 6)
	top_row.add_child(_chip_host)

	chips["cash"] = _chip("Cash")
	chips["income"] = _chip("Income")
	chips["crude"] = _chip("Crude")
	chips["gas"] = _chip("Gas")
	chips["clock"] = _chip("Date / Weather")
	chips["clock"].add_theme_font_size_override("font_size", 12)
	chips["price"] = _chip("Price")
	chips["debt"] = _chip("Debt")
	chips["value"] = _chip("Value")

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var loan := _button("Loan +$100k", 132, 34)
	loan.pressed.connect(func() -> void: loan_requested.emit())
	top_row.add_child(loan)

	for spec in [["1×", 1.0], ["2×", 2.0], ["4×", 4.0], ["8×", 8.0]]:
		var b := _button(spec[0], 42, 34)
		var mult: float = spec[1]
		b.pressed.connect(func() -> void: speed_selected.emit(mult))
		top_row.add_child(b)

	# ---- build panel (left) ------------------------------------------------ #
	var build := _panel()
	build.position = Vector2(12, 78)
	build.custom_minimum_size = Vector2(220, 0)
	build.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(build)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	build.add_child(vb)
	vb.add_child(_label("BUILD", 10, MUTED))
	var filter_box := LineEdit.new()
	filter_box.placeholder_text = "filter structures"
	filter_box.custom_minimum_size = Vector2(196, 26)
	filter_box.add_theme_font_size_override("font_size", 12)
	filter_box.text_changed.connect(_on_build_filter_changed)
	vb.add_child(filter_box)

	# The list scrolls, so the catalogue can grow without redesigning the panel.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(196, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_build_list = list
	_populate_build()

	vb.add_child(HSeparator.new())
	var bd := _button("X · Bulldoze", 196, 34, _load_texture("res://assets/icons/bulldoze.png"))
	bd.pressed.connect(func() -> void:
		Sfx.play("click")
		bulldoze_selected.emit()
	)
	vb.add_child(bd)
	tool_buttons["bulldoze"] = {"btn": bd, "key": "X", "name": "Bulldoze"}

	# ---- unit action bar (bottom center) ---------------------------------- #
	var up := _panel(0.9)
	up.anchor_left = 0.5
	up.anchor_right = 0.5
	up.anchor_top = 1.0
	up.anchor_bottom = 1.0
	up.offset_left = -288
	up.offset_right = 288
	up.offset_top = -184
	up.offset_bottom = -116
	up.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(up)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 4)
	up.add_child(uv)
	_unit_title = _label("", 12, ACCENT)
	_unit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uv.add_child(_unit_title)
	_unit_actions = HBoxContainer.new()
	_unit_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_unit_actions.add_theme_constant_override("separation", 6)
	uv.add_child(_unit_actions)
	_unit_panel = up
	up.visible = false

	# ---- inspector (right) ------------------------------------------------- #
	var insp := _panel()
	insp.anchor_left = 1.0
	insp.anchor_right = 1.0
	insp.offset_left = -338
	insp.offset_right = -12
	insp.offset_top = 78
	insp.custom_minimum_size = Vector2(326, 0)
	insp.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(insp)

	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 6)
	insp.add_child(ivb)
	inspector_title = _label("Nothing selected", 15, TEXT)
	ivb.add_child(inspector_title)
	inspector_body = _label("Hover a building to inspect it.", 12, MUTED)
	inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body.custom_minimum_size = Vector2(300, 90)
	ivb.add_child(inspector_body)

	# ---- network manager (right, between inspector and minimap) ----------- #
	var runs := _panel(0.85)
	runs.anchor_left = 1.0
	runs.anchor_right = 1.0
	runs.anchor_bottom = 1.0
	runs.offset_left = -338
	runs.offset_right = -12
	runs.offset_top = 360
	runs.offset_bottom = -206
	runs.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(runs)

	var rvb := VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 4)
	runs.add_child(rvb)
	_runs_title = _label("NETWORKS", 10, MUTED)
	rvb.add_child(_runs_title)
	var runs_scroll := ScrollContainer.new()
	runs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	runs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rvb.add_child(runs_scroll)
	_runs_box = VBoxContainer.new()
	_runs_box.add_theme_constant_override("separation", 3)
	_runs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	runs_scroll.add_child(_runs_box)
	rvb.add_child(_label("F = fleet · F6 transfer · F7 demolish · click to focus", 9, MUTED))

	# ---- minimap (bottom right) ------------------------------------------- #
	var mm_panel := _panel(0.85)
	mm_panel.anchor_left = 1.0
	mm_panel.anchor_right = 1.0
	mm_panel.anchor_top = 1.0
	mm_panel.anchor_bottom = 1.0
	mm_panel.offset_left = -190
	mm_panel.offset_right = -12
	mm_panel.offset_top = -190
	mm_panel.offset_bottom = -12
	mm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mm_panel)

	var mmv := VBoxContainer.new()
	mmv.add_theme_constant_override("separation", 4)
	mm_panel.add_child(mmv)
	mmv.add_child(_label("LEASE MAP", 9, MUTED))
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(154, 154)
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.cell_clicked.connect(func(c: Vector2i) -> void: minimap_target.emit(c))
	mmv.add_child(minimap)

	# ---- objective + toast ------------------------------------------------- #
	objective_label = _label("", 13, GOOD)
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.offset_top = 76
	objective_label.offset_bottom = 100
	objective_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(objective_label)

	toast_label = _label("", 15, Color(1, 0.88, 0.45))
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.offset_top = 104
	toast_label.offset_bottom = 128
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false
	root.add_child(toast_label)

	hint_label = _label("", 11, MUTED)
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = 12
	hint_label.offset_top = -32
	hint_label.offset_bottom = -10
	root.add_child(hint_label)

	network_label = _label("", 11, MUTED)
	network_label.anchor_top = 1.0
	network_label.anchor_bottom = 1.0
	network_label.offset_left = 12
	network_label.offset_top = -74
	network_label.offset_bottom = -34
	root.add_child(network_label)


# --------------------------------------------------------------------------- #
# api
# --------------------------------------------------------------------------- #

func register_catalogue(entries: Array) -> void:
	_entries = entries
	for e in entries:
		costs[e.id] = float(e.cost)
	_refresh_buttons()


func set_tool(kind: String) -> void:
	for k in tool_buttons:
		var b: Button = tool_buttons[k]["btn"]
		b.self_modulate = ACCENT if k == kind else Color(1, 1, 1)
	_refresh_buttons()


func _short_money(v: float) -> String:
	if v >= 1000000.0:
		return "$%.1fM" % (v / 1000000.0)
	if v >= 1000.0:
		return "$%dk" % int(round(v / 1000.0))
	return "$%d" % int(v)


func _refresh_buttons() -> void:
	for k in tool_buttons:
		if not costs.has(k):
			continue
		var b: Button = tool_buttons[k]["btn"]
		var t: Dictionary = tool_buttons[k]
		var key: String = String(t["key"])
		var prefix := "%s · " % key if key != "" else ""
		var suffix := ""
		if _fleet.has(k):
			suffix = "   ×%d" % int(_fleet[k])
		b.text = "%s%s   %s%s" % [prefix, t["name"], _short_money(costs[k]), suffix]
		b.modulate = Color(1, 1, 1) if _cash >= costs[k] else Color(0.62, 0.62, 0.58)
	if tool_buttons.has("bulldoze"):
		var bd: Button = tool_buttons["bulldoze"]["btn"]
		bd.text = "X · Bulldoze"


func update_stats(d: Dictionary) -> void:
	_cash = float(d.get("cash", 0.0))
	_fleet = d.get("fleet", {})
	chips["cash"].text = "$%s" % fmt_num(_cash)
	chips["cash"].add_theme_color_override("font_color", BAD if _cash < 0.0 else TEXT)
	var flow: float = float(d.get("income", 0.0))
	chips["income"].text = "%s$%s/s" % ["+" if flow >= 0.0 else "-", fmt_num(absf(flow))]
	chips["income"].add_theme_color_override("font_color", GOOD if flow >= 0.0 else BAD)
	chips["crude"].text = "%s / %s" % [fmt_num(float(d.get("crude", 0.0))), fmt_num(float(d.get("capacity", 0.0)))]
	chips["gas"].text = "%.1f u/s" % float(d.get("gas", 0.0))
	chips["gas"].add_theme_color_override("font_color",
		BAD if float(d.get("venting", 0.0)) > 0.0 else TEXT)
	chips["clock"].text = String(d.get("clock", "—"))
	var weather_color: Color = d.get("weather_color", TEXT)
	chips["clock"].add_theme_color_override("font_color", weather_color)
	chips["price"].text = "$%.1f" % float(d.get("price", 0.0))
	chips["debt"].text = "$%s" % fmt_num(float(d.get("debt", 0.0)))
	var value := float(d.get("value", 0.0))
	chips["value"].text = "$%s" % fmt_num(value)
	chips["value"].add_theme_color_override("font_color",
		GOOD if value >= 1000000.0 else (BAD if value < 0.0 else TEXT))
	_refresh_buttons()


func set_objective(text: String) -> void:
	objective_label.text = text


func set_network(text: String) -> void:
	network_label.text = text


## Action bar for the selected agent unit. Rebuilt only when the selection or
## job changes, so it is safe to call on every selection update.
func set_unit_actions(job: String, title: String, visible: bool) -> void:
	if _unit_panel == null:
		return
	_unit_panel.visible = visible
	if not visible:
		return
	_unit_title.text = title.to_upper()
	for c in _unit_actions.get_children():
		_unit_actions.remove_child(c)
		c.queue_free()
	_add_unit_action("move", "Move")
	match job:
		"seismic":
			_add_unit_action("survey", "Survey")
		"prep":
			_add_unit_action("prepare", "Prepare site")
			_add_unit_action("flatten", "Flatten")
		"hauler":
			_add_unit_action("haul", "Haul")
	_add_unit_action("stop", "Stop")
	_add_unit_action("deselect", "Deselect")


func _add_unit_action(action: String, text: String) -> void:
	var b := _button(text, 104, 30)
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		unit_action.emit(action)
	)
	_unit_actions.add_child(b)


## Live list of every pipe run and street network. Rebuilt only when the text
## changes, so it is cheap to call every frame.
func set_runs(rows: Array) -> void:
	if _runs_box == null:
		return
	var parts: Array[String] = []
	for r in rows:
		parts.append("%s:%d:%s" % [String(r.kind), int(r.id), String(r.text)])
	var sig := "|".join(parts)
	if sig == _runs_sig:
		return
	_runs_sig = sig
	var alerts := 0
	for r in rows:
		if bool(r.alert):
			alerts += 1
	if _runs_title != null:
		_runs_title.text = "NETWORKS" + (
			" · %d alert%s" % [alerts, "" if alerts == 1 else "s"] if alerts > 0 else "")
		_runs_title.add_theme_color_override("font_color",
			Color(1.0, 0.55, 0.4) if alerts > 0 else MUTED)
	for child in _runs_box.get_children():
		child.queue_free()
	for r in rows:
		var kind := String(r.kind)
		var rid := int(r.id)
		var b := _button(String(r.text), 296, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			run_selected.emit(kind, rid)
		)
		var col := Color(0.78, 0.92, 0.72)
		if bool(r.get("selected", false)):
			col = Color(1.0, 0.90, 0.55)
		elif float(r.ratio) >= 0.9:
			col = Color(1.0, 0.58, 0.42)
		elif float(r.ratio) >= 0.6:
			col = Color(1.0, 0.86, 0.48)
		b.add_theme_color_override("font_color", col)
		_runs_box.add_child(b)


## Field manual overlay (H). Explains the two networks and the management keys.
func toggle_help() -> void:
	if _help_root != null:
		_help_root.queue_free()
		_help_root = null
		help_toggled.emit(false)
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.70)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var card := _panel()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -340
	card.offset_right = 340
	card.offset_top = -320
	card.offset_bottom = 320
	dim.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var title := _label("FIELD MANUAL", 24, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var body := _label(
		"UNITS — buy them in FLEET; they launch from the Field Base.\n" +
		"Click a unit to select. LEFT-click moves it. RIGHT-click sends it to the\n" +
		"spot to do its job (survey / prepare site / haul). Progress shows above\n" +
		"the unit and at the site; a ✓ marks a finished job.\n\n" +
		"SURVEY — Seismic Vehicle reveals deposits in a 7-cell radius.\n" +
		"DRILL — Pumpjack [1] on a revealed deposit.\n" +
		"FLATTEN — Bulldozer → Flatten, then click a 3×3 area to level it.\n" +
		"HAUL — Fuel Tanker loops well → base → sale; tanks/refineries pay more.\n\n" +
		"BUILDING — placing a structure reserves the site. Select a Mobile Crane and\n" +
		"right-click the site to assign the build; different cranes build in parallel.\n\n" +
		"PIPELINES — ports are E / N / W; the south side is the motor/access side.\n" +
		"Drag from a green port strip to a tank or refinery. Tanks bridge runs;\n" +
		"a run with no storage sells nothing. Capacity is 2.0 + 0.5/cell bbl/s;\n" +
		"pumps, compressors and manifolds raise it.\n\n" +
		"STREETS — a road only counts when its network serves 2+ sites.\n" +
		"Logistics = 2.0 + 0.5/cell + assigned fleet; over capacity throttles output.\n\n" +
		"CAMERA — C toggles classic isometric / 3D orbit; wheel zooms.\n" +
		"MANAGEMENT — NETWORKS lists every run and street; click a row to focus.\n" +
		"Click the minimap to jump · F6 transfer · F7 demolish · Tab heat-map.\n" +
		"F5 save · F9 load · Space pause · X bulldoze (drag).", 13, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(610, 0)
	vb.add_child(body)
	var close := _button("Close (H)", 180, 36)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		_help_root.queue_free()
		_help_root = null
		help_toggled.emit(false)
	)
	vb.add_child(close)
	_help_root = dim
	help_toggled.emit(true)


func is_help_open() -> bool:
	return _help_root != null


func show_game_over(summary: String) -> void:
	if _game_over_root != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var card := _panel()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = -160
	card.offset_bottom = 160
	dim.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var title := _label("LEASE FORECLOSED", 24, BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var body := _label(summary, 13, TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(440, 0)
	vb.add_child(body)
	var restart := _button("Restart", 170, 36)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void:
		_game_over_root = null
		restart_requested.emit()
	)
	vb.add_child(restart)
	_game_over_root = dim


func clear_game_over() -> void:
	if _game_over_root != null:
		_game_over_root.queue_free()
		_game_over_root = null


func show_victory(summary: String) -> void:
	if _victory_root != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var card := _panel()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -230
	card.offset_right = 230
	card.offset_top = -150
	card.offset_bottom = 150
	dim.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var title := _label("LEASE SECURED", 26, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := _label("Company value over $1,000,000", 13, TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var body := _label(summary, 12, MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	var keep := _button("Keep playing", 170, 36)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.pressed.connect(func() -> void:
		dim.queue_free()
		_victory_root = null
		victory_dismissed.emit()
	)
	vb.add_child(keep)
	var new_lease := _button("New lease", 170, 36)
	new_lease.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_lease.pressed.connect(func() -> void:
		_victory_root = null
		restart_requested.emit()
	)
	vb.add_child(new_lease)
	_victory_root = dim


func clear_victory() -> void:
	if _victory_root != null:
		_victory_root.queue_free()
		_victory_root = null


func set_inspector(title: String, body: String) -> void:
	inspector_title.text = title
	inspector_body.text = body


func set_minimap(cells: Array) -> void:
	minimap.cells = cells
	minimap.queue_redraw()


func set_hint(text: String) -> void:
	hint_label.text = text


var start_overlay: Control


func show_start_overlay() -> void:
	if start_overlay != null:
		return
	start_overlay = Control.new()
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_overlay)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/textures/ui_title.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	start_overlay.add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(dim)

	var p := _panel(0.98)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	start_overlay.add_child(p)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	p.add_child(vb)

	var t := _label("OILFIELD TYCOON", 28, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := _label("Survey · Drill · Pipe · Store · Refine · Sell", 13, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var rules := _label(
		"Start at the Field Base. Launch a Seismic Vehicle to find oil.\n" +
		"Send a Bulldozer to prepare a site, then drill a Pumpjack.\n" +
		"A Fuel Tanker hauls crude to the base; pipes and refineries pay more.\n" +
		"Roads must serve 2+ sites · pipelines have a capacity · R rotates ports.\n" +
		"Reach $1,000,000 company value to secure the lease.",
		12, TEXT)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rules)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for spec in [["Easy · $500k", 500000.0], ["Normal · $300k", 300000.0], ["Hard · $150k", 150000.0]]:
		var b := _button(spec[0], 132, 40)
		var money: float = spec[1]
		b.pressed.connect(func() -> void:
			difficulty_selected.emit(money)
		)
		row.add_child(b)

	var hint := _label("WASD pan · wheel zoom · Q/E rotate · R rotate structure · F5 save · F9 load · X bulldoze", 11, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)


func hide_start_overlay() -> void:
	if start_overlay != null:
		start_overlay.queue_free()
		start_overlay = null


func toast(msg: String, color: Color = Color(1, 0.86, 0.4)) -> void:
	toast_label.text = msg
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate = Color(1, 1, 1, 1)
	toast_label.visible = true
	_toast_time = 3.4


func fmt_num(v: float) -> String:
	var neg := v < 0.0
	var s := str(int(round(absf(v))))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out
