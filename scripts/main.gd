extends Control

const Rules = preload("res://scripts/matching_rules.gd")
const FONT = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const ICON_FILES = ["01_apple", "02_pear", "03_orange", "04_lemon", "05_grape", "06_berry", "07_cherry", "08_melon", "09_peach", "10_blueberry"]
var rules = Rules.new()
var buttons: Dictionary = {}
var selected = Vector2i(-1, -1)
var hint_cells: Array[Vector2i] = []
var route: Array[Vector2i] = []
var route_alpha = 0.0
var route_progress = 0.0
var busy = false
var generation = 0
var elapsed = 0.0
var matches = 0
var hints_used = 0
var shuffles_used = 0
var reduced_motion = false
var cell_size = 60.0
var origin = Vector2.ZERO
var board_panel: Panel
var status_label: Label
var count_label: Label
var time_label: Label
var subtitle: Label
var progress: ProgressBar
var restart_dialog: ConfirmationDialog
var win_panel: PanelContainer
var win_label: Label
var icon_textures: Array[Texture2D] = []
var effects: Control
var focus_cell = Vector2i.ZERO
var active_tweens: Array[Tween] = []
var title: Label
var help_label: Label
var hint_button: Button
var shuffle_button: Button
var restart_button: Button
var motion_button: CheckButton

func _ready() -> void:
	var theme_res = Theme.new()
	theme_res.default_font = FONT
	theme_res.default_font_size = 17
	theme = theme_res
	for file in ICON_FILES:
		icon_textures.append(load("res://assets/icons/" + file + ".svg"))
	_build_ui()
	resized.connect(_layout)
	_new_game()
	_layout()

func _style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 13) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _button(text_value: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = text_value
	b.add_theme_color_override("font_color", Color("426154"))
	b.add_theme_color_override("font_hover_color", Color("254735"))
	b.add_theme_stylebox_override("normal", _style(Color("e5eee5")))
	b.add_theme_stylebox_override("hover", _style(Color("d5e7d9")))
	b.add_theme_stylebox_override("pressed", _style(Color("c6ddce")))
	b.pressed.connect(action)
	add_child(b)
	return b

func _build_ui() -> void:
	title = _label("果园连线", 31, Color("2d5146"))
	subtitle = _label("ORCHARD  /  连连看", 12, Color("7d9486"))
	count_label = _label("", 23, Color("345749"))
	time_label = _label("", 17, Color("789081"))
	board_panel = Panel.new()
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_theme_stylebox_override("panel", _style(Color("e2ebe0"), Color("d4e0d2"), 1, 23))
	add_child(board_panel)
	effects = Control.new()
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.draw.connect(_draw_effects)
	effects.z_index = 10
	add_child(effects)
	status_label = _label("", 18, Color("476654"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = 40
	progress.add_theme_stylebox_override("background", _style(Color("dce7da"), Color.TRANSPARENT, 0, 5))
	progress.add_theme_stylebox_override("fill", _style(Color("83ad92"), Color.TRANSPARENT, 0, 5))
	for style_name in ["background", "fill"]:
		var progress_style: StyleBoxFlat = progress.get_theme_stylebox(style_name)
		progress_style.content_margin_left = 0
		progress_style.content_margin_right = 0
		progress_style.content_margin_top = 0
		progress_style.content_margin_bottom = 0
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	hint_button = _button("提示  H", _hint)
	shuffle_button = _button("洗牌  S", _shuffle)
	restart_button = _button("重新开始  R", _request_restart)
	motion_button = CheckButton.new()
	motion_button.text = "减少动态"
	motion_button.add_theme_color_override("font_color", Color("607b68"))
	motion_button.toggled.connect(func(value): reduced_motion = value)
	add_child(motion_button)
	help_label = _label("相同图案 · 最多转弯两次 · 可从棋盘外侧绕行", 14, Color("8b9c89"))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "重新开始？"
	restart_dialog.dialog_text = "当前进度将清空，生成一局新的果园。"
	restart_dialog.ok_button_text = "开始新局"
	restart_dialog.cancel_button_text = "继续这局"
	restart_dialog.confirmed.connect(_new_game)
	restart_dialog.canceled.connect(_check_deadlock, CONNECT_DEFERRED)
	add_child(restart_dialog)
	win_panel = PanelContainer.new()
	win_panel.add_theme_stylebox_override("panel", _style(Color("fbfcf5"), Color("a6c4a9"), 2, 22))
	win_panel.z_index = 20
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	win_panel.add_child(box)
	win_label = Label.new()
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 24)
	win_label.add_theme_color_override("font_color", Color("395b46"))
	box.add_child(win_label)
	var again = Button.new()
	again.text = "再来一局"
	again.pressed.connect(_new_game)
	box.add_child(again)
	add_child(win_panel)
	win_panel.hide()

func _layout() -> void:
	if not is_node_ready(): return
	var w = size.x
	var h = size.y
	title.position = Vector2(42, 24)
	subtitle.position = Vector2(44, 66)
	count_label.position = Vector2(w - 242, 29)
	time_label.position = Vector2(w - 242, 64)
	cell_size = minf((w - 104) / 12.0, (h - 240) / 10.0)
	origin = Vector2((w - rules.cols * cell_size) / 2.0, 112 + cell_size)
	board_panel.position = origin - Vector2.ONE * cell_size
	board_panel.size = Vector2((rules.cols + 2) * cell_size, (rules.rows + 2) * cell_size)
	effects.size = size
	for cell in buttons:
		var b: Button = buttons[cell]
		b.position = origin + Vector2(cell) * cell_size + Vector2(3, 3)
		b.size = Vector2.ONE * (cell_size - 6)
		b.pivot_offset = b.size / 2
		b.add_theme_constant_override("icon_max_width", int(cell_size - 18))
	status_label.position = Vector2(20, h - 120)
	status_label.size = Vector2(w - 40, 30)
	progress.position = Vector2(w / 2 - 240, h - 86)
	progress.size = Vector2(480, 5)
	hint_button.position = Vector2(w / 2 - 285, h - 68)
	hint_button.size = Vector2(110, 40)
	shuffle_button.position = Vector2(w / 2 - 163, h - 68)
	shuffle_button.size = Vector2(110, 40)
	restart_button.position = Vector2(w / 2 - 41, h - 68)
	restart_button.size = Vector2(158, 40)
	motion_button.position = Vector2(w / 2 + 130, h - 68)
	motion_button.size = Vector2(155, 40)
	help_label.position = Vector2(20, h - 25)
	help_label.size = Vector2(w - 40, 22)
	win_panel.position = Vector2(w / 2 - 200, h / 2 - 95)
	win_panel.size = Vector2(400, 190)
	queue_redraw()
	effects.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f5f5eb"))
	for i in range(9):
		var p = Vector2(28 + i * 23, size.y * 0.52 + sin(i * 0.8) * 75)
		draw_circle(p, 3 + i % 3, Color(0.71, 0.79, 0.65, 0.14))
		draw_circle(Vector2(size.x - p.x, size.y - p.y), 4, Color(0.71, 0.79, 0.65, 0.14))

func _draw_effects() -> void:
	if route.size() < 2 or route_alpha <= 0: return
	var points: Array[Vector2] = []
	var length = 0.0
	for cell in route: points.append(origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size)
	for i in range(points.size() - 1): length += points[i].distance_to(points[i + 1])
	var left = length * route_progress
	for i in range(points.size() - 1):
		var segment = points[i].distance_to(points[i + 1])
		if left <= 0: break
		var end = points[i].lerp(points[i + 1], minf(1.0, left / maxf(segment, 0.01)))
		effects.draw_line(points[i], end, Color(0.39, 0.68, 0.55, route_alpha * 0.18), 13, true)
		effects.draw_line(points[i], end, Color(0.23, 0.55, 0.40, route_alpha), 3.5, true)
		effects.draw_circle(end, 5, Color(0.39, 0.68, 0.49, route_alpha))
		left -= segment

func _cancel_effects() -> void:
	for tween in active_tweens:
		if tween.is_valid(): tween.kill()
	active_tweens.clear()

func _new_game() -> void:
	_cancel_effects()
	generation += 1
	busy = false
	route.clear()
	route_alpha = 0
	selected = Vector2i(-1, -1)
	hint_cells.clear()
	elapsed = 0
	matches = 0
	hints_used = 0
	shuffles_used = 0
	win_panel.hide()
	rules.start()
	_rebuild_tiles()
	status_label.text = "找一对相同的果实，连起这座小果园。"
	_update_hud()

func _rebuild_tiles() -> void:
	for b in buttons.values():
		remove_child(b)
		b.queue_free()
	buttons.clear()
	for y in range(rules.rows):
		for x in range(rules.cols):
			var cell = Vector2i(x, y)
			var value = rules.get_cell(cell)
			if value == 0: continue
			var b = Button.new()
			b.icon = icon_textures[(value - 1) % icon_textures.size()]
			b.expand_icon = true
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = ["苹果", "梨", "橙子", "柠檬", "葡萄", "草莓", "樱桃", "西瓜", "桃子", "蓝莓"][(value - 1) % 10]
			b.pressed.connect(_select_cell.bind(cell))
			b.mouse_entered.connect(func():
				if not busy and not reduced_motion: b.scale = Vector2.ONE * 1.04)
			b.mouse_exited.connect(func(): b.scale = Vector2.ONE)
			buttons[cell] = b
			add_child(b)
	_refresh_styles()
	_layout()

func _tile_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s = _style(bg, border, width, 10)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _refresh_styles() -> void:
	for cell in buttons:
		var b: Button = buttons[cell]
		var active: bool = cell == selected or cell in hint_cells
		b.add_theme_stylebox_override("normal", _tile_style(Color("fffbed") if active else Color("fcfcf5"), Color("75a890") if active else Color("d4dfce"), 3 if active else 1))
		b.add_theme_stylebox_override("hover", _tile_style(Color("fffdf2"), Color("a5bfa4"), 2))
		b.add_theme_stylebox_override("pressed", _tile_style(Color("e9f1df"), Color("75a890"), 3))

func _select_cell(cell: Vector2i) -> void:
	if busy or restart_dialog.visible or win_panel.visible or rules.get_cell(cell) == 0: return
	hint_cells.clear()
	route_alpha = 0
	if selected == cell:
		selected = Vector2i(-1, -1)
		_refresh_styles()
		return
	if selected.x < 0:
		selected = cell
		focus_cell = cell
		_refresh_styles()
		return
	var path: Array[Vector2i] = rules.find_path(selected, cell)
	if path.is_empty():
		selected = cell
		status_label.text = "这两颗暂时连不上，试试另一对。"
		_refresh_styles()
		return
	var first = selected
	selected = Vector2i(-1, -1)
	busy = true
	route = path
	route_alpha = 1
	route_progress = 0 if not reduced_motion else 1
	var token = generation
	var duration = 0.12 if reduced_motion else 0.40
	var tween = create_tween()
	active_tweens.append(tween)
	tween.tween_property(self, "route_progress", 1.0, duration * 0.55)
	if not reduced_motion:
		tween.tween_property(buttons[first], "scale", Vector2.ONE * 0.75, duration * 0.45)
		tween.parallel().tween_property(buttons[cell], "scale", Vector2.ONE * 0.75, duration * 0.45)
	else:
		tween.tween_interval(duration * 0.45)
	await tween.finished
	if token != generation or not is_inside_tree(): return
	var result = rules.remove_pair(first, cell)
	if not result.success:
		busy = false
		return
	matches += 1
	_rebuild_tiles()
	_update_hud()
	var fade = create_tween()
	active_tweens.append(fade)
	fade.tween_property(self, "route_alpha", 0.0, 0.08 if reduced_motion else 0.25)
	await fade.finished
	if token != generation or not is_inside_tree(): return
	busy = false
	if rules.remaining == 0:
		win_label.text = "果园收获完成！\n用时 %s · %d 对果实" % [_time_string(), matches]
		win_panel.show()
		status_label.text = "所有果实都找到了伙伴。"
	elif rules.get_hint().is_empty():
		_shuffle(true)
	else:
		status_label.text = "漂亮！继续寻找下一对。"

func _hint() -> void:
	if busy or restart_dialog.visible or win_panel.visible: return
	hint_cells = rules.get_hint()
	selected = Vector2i(-1, -1)
	if hint_cells.is_empty():
		_shuffle(true)
		return
	hints_used += 1
	route = rules.find_path(hint_cells[0], hint_cells[1])
	route_progress = 1
	route_alpha = 0.65
	status_label.text = "已点亮一对可消除的果实。"
	_refresh_styles()

func _shuffle(automatic: bool = false) -> void:
	if busy or restart_dialog.visible or win_panel.visible: return
	if rules.remaining == 0: return
	_cancel_effects()
	generation += 1
	selected = Vector2i(-1, -1)
	hint_cells.clear()
	route.clear()
	route_alpha = 0
	rules.shuffle_board()
	shuffles_used += 1
	_rebuild_tiles()
	status_label.text = "没有可连的果实，已自动重新排列。" if automatic else "果实重新排列，继续慢慢找。"

func _check_deadlock() -> void:
	if not busy and rules.remaining > 0 and rules.get_hint().is_empty():
		_shuffle(true)

func _request_restart() -> void:
	if restart_dialog.visible: return
	restart_dialog.popup_centered(Vector2i(410, 170))

func _time_string() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

func _update_hud() -> void:
	count_label.text = "%02d / 40 对已收获" % matches
	progress.value = matches
	time_label.text = _time_string() + "  ·  无时间限制"

func _process(delta: float) -> void:
	if not is_node_ready(): return
	if rules.remaining > 0 and not restart_dialog.visible: elapsed += delta
	_update_hud()
	effects.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if restart_dialog.visible: return
	match event.keycode:
		KEY_H: _hint()
		KEY_S: _shuffle()
		KEY_R: _request_restart()
		KEY_ESCAPE:
			if busy: return
			selected = Vector2i(-1, -1)
			hint_cells.clear()
			route_alpha = 0
			_refresh_styles()
		KEY_LEFT: focus_cell.x = posmod(focus_cell.x - 1, rules.cols)
		KEY_RIGHT: focus_cell.x = posmod(focus_cell.x + 1, rules.cols)
		KEY_UP: focus_cell.y = posmod(focus_cell.y - 1, rules.rows)
		KEY_DOWN: focus_cell.y = posmod(focus_cell.y + 1, rules.rows)
		KEY_ENTER, KEY_SPACE: _select_cell(focus_cell)
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		hint_cells.assign([focus_cell])
		_refresh_styles()
	get_viewport().set_input_as_handled()
