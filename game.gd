extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## One shared board: host serializes tile claims; only a shuffle invalidates unrelated claims.
const Rules: Script = preload("res://games/minigame/godot_party_default_matching_game/matching_rules.gd")
const Cursors: Script = preload("res://games/protocols/godot_party_default_protocol/player_cursors.gd")
const ICONS: Array[String] = ["01_apple", "02_pear", "03_orange", "04_lemon", "05_grape", "06_berry", "07_cherry", "08_melon", "09_peach", "10_blueberry"]
var rules: RefCounted = Rules.new()
var scores: Dictionary = {}
var hints: Dictionary = {}
var generation: int = 0
var selected: int = -1
var selected_value: int = 0
var selected_generation: int = -1
var grid: GridContainer
var tiles: Array[Button] = []
var hint_button: Button
var notice: Label
var last_path: Array = []
var path_age: float = 0.0
var path_color: Color = Color.WHITE
var claim_revision: int = 0
var rendered_claim: int = -1
var hint_cells: Array = []
var hint_age: float = 0.0
var board_area: Control
var effects: Control

func build_game() -> void:
	heading.text = "果园连线 · 共享棋盘"
	footer.text = "点击两个同类水果 · 最多两次转弯 · 主机先收到的有效配对得分 · 同分并列"
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(center)
	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(880, 720)
	center.add_child(board_area)
	grid = GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(40, 40)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	board_area.add_child(grid)
	for index: int in 80:
		var tile: Button = Button.new()
		tile.custom_minimum_size = Vector2(76, 76)
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.pressed.connect(_select.bind(index))
		grid.add_child(tile)
		tiles.append(tile)
	effects = Control.new()
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.draw.connect(_draw_path)
	board_area.add_child(effects)
	var cursors: Control = Cursors.new()
	cursors.setup(api)
	board_area.add_child(cursors)
	hint_button = button(sidebar, "提示", func() -> void: send_action({"kind": "hint", "generation": generation}))
	notice = label(sidebar, "无解时自动重排，不扣次数", 20)

func start_game() -> void:
	if api.is_host():
		rules.start(api.get_seed())
		for player: Dictionary in players:
			scores[player.player_id] = 0
			hints[player.player_id] = int(settings.get("hints", 3))

func tick_game(delta: float) -> void:
	path_age = maxf(0, path_age - delta)
	hint_age = maxf(0, hint_age - delta)
	effects.queue_redraw()
	if api.is_host() and (rules.remaining == 0 or elapsed >= float(settings.get("duration", 180))):
		finish_scores(scores, {}, [{"key": "score", "title": "消除对数", "format": "integer"}])

func handle_action(id: String, data: Dictionary) -> void:
	if int(data.get("generation", -1)) != generation:
		return
	if data.get("kind") == "hint" and int(hints[id]) > 0:
		hints[id] -= 1
		api.net.send_to_player(id, &"private_view", {"hint": rules.get_hint(), "generation": generation})
	elif data.get("kind") == "pair":
		if not data.get("a") is int or not data.get("b") is int or not data.get("value") is int:
			return
		var a: int = data.a
		var b: int = data.b
		if a < 0 or a >= 80 or b < 0 or b >= 80 or a == b or rules.board[a] != data.value or rules.board[b] != data.value:
			return
		var result: Dictionary = rules.remove_pair(Vector2i(a % 10, a / 10), Vector2i(b % 10, b / 10))
		if result.success:
			scores[id] += 1
			claim_revision += 1
			last_path = result.path
			path_color = player_color(id)
			if rules.remaining > 0 and rules.get_hint().is_empty():
				rules.shuffle_board()
				generation += 1
			publish()

func make_snapshot() -> Dictionary:
	return {"board": rules.board.duplicate(), "scores": scores.duplicate(), "hints": hints.duplicate(), "generation": generation, "remaining": rules.remaining, "time": maxf(0, float(settings.get("duration", 180)) - elapsed), "path": last_path, "color": path_color, "claim": claim_revision}

func render_game() -> void:
	if view.is_empty():
		return
	var changed_generation: bool = generation != int(view.generation)
	generation = view.generation
	if changed_generation or (selected >= 0 and (view.board[selected] == 0 or int(view.board[selected]) != selected_value)):
		selected = -1
	if int(view.claim) != rendered_claim:
		rendered_claim = view.claim
		last_path = view.path
		path_color = view.color
		path_age = 0.65
	for index: int in tiles.size():
		var value: int = view.board[index]
		tiles[index].icon = load("res://games/minigame/godot_party_default_matching_game/assets/icons/" + ICONS[value - 1] + ".svg") if value > 0 else null
		tiles[index].disabled = value == 0 or local_id.is_empty()
		tiles[index].modulate = Color("#9ce6ba") if index == selected else (Color("#ffe28a") if hint_age > 0 and Vector2i(index % 10, index / 10) in hint_cells else Color.WHITE)
	status.text = "剩余 %d 秒 · %d 对 · %s" % [ceili(view.time), int(view.remaining) / 2, "观战中" if local_id.is_empty() else "抢先找到可连接的水果"]
	var lines: PackedStringArray = []
	for player: Dictionary in players:
		lines.append("%s  %d 对" % [player.name, view.scores.get(player.player_id, 0)])
	standings.text = "\n".join(lines)
	hint_button.text = "提示（%d）" % int(view.hints.get(local_id, 0))
	hint_button.disabled = local_id.is_empty() or int(view.hints.get(local_id, 0)) <= 0
	if changed_generation:
		notice.text = "棋盘无解，已自动重排"

func _select(index: int) -> void:
	if not running or view.is_empty():
		return
	if selected < 0 or selected == index:
		selected = index if selected != index else -1
		selected_value = int(view.board[index])
		selected_generation = generation
	else:
		send_action({"kind": "pair", "a": selected, "b": index, "value": selected_value, "generation": selected_generation})
		selected = -1
	render_game()

func receive_private(data: Dictionary) -> void:
	if int(data.get("generation", -1)) != generation:
		return
	hint_cells = data.get("hint", [])
	hint_age = 2.0
	for cell: Vector2i in hint_cells:
		tiles[cell.y * 10 + cell.x].modulate = Color("#ffe28a")
	notice.text = "提示的两个水果已标亮；其他玩家仍可抢先消除"

func _draw_path() -> void:
	if path_age <= 0 or last_path.size() < 2:
		return
	var points: PackedVector2Array = []
	for cell: Vector2i in last_path:
		points.append(Vector2(78, 78) + Vector2(cell) * 80)
	effects.draw_polyline(points, Color(path_color, path_age / 0.65), 5, true)
