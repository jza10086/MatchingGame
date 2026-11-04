extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## One shared board: host serializes tile claims; only a shuffle invalidates unrelated claims.
const Rules: Script = preload("res://games/minigame/godot_party_default_matching_game/matching_rules.gd")
const Cursors: PackedScene = preload("res://games/protocols/godot_party_default_protocol/player_cursors.tscn")
const BoardView: Script = preload("res://games/minigame/godot_party_default_matching_game/board_3d.gd")
var rules: RefCounted = Rules.new()
var scores: Dictionary = {}
var hints: Dictionary = {}
var generation: int = 0
var selected: int = -1
var selected_value: int = 0
var selected_generation: int = -1
@onready var board_view: BoardView = %Board
@onready var controls: Label = %Controls
var last_path: Array = []
var path_color: Color = Color.WHITE
var claim_revision: int = 0
var rendered_claim: int = -1
var rendered_generation: int = 0
var hint_cells: Array = []
var hint_age: float = 0.0
@onready var board_area: Control = %BoardArea
var cursors: Control

func build_game() -> void:
	board_area.gui_input.connect(_board_input)
	board_area.resized.connect(_frame_board)
	board_area.item_rect_changed.connect(_frame_board)
	_frame_board.call_deferred()
	cursors = Cursors.instantiate()
	cursors.setup(api)
	cursors.enabled = false
	board_area.add_child(cursors)
	_update_controls()

## Use the protocol's existing graphics scope on the same viewport as the HUD.
func godot_party_graphics_targets() -> Dictionary:
	return {"world": board_view.world, "sun": board_view.sun, "materials_root": board_view.models}

func _frame_board() -> void:
	board_view.frame_surface(board_area.get_global_rect())

func _board_input(event: InputEvent) -> void:
	if not running or api.input.input_blocked or not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			var index: int = board_view.pick(board_area.get_global_transform_with_canvas() * event.position)
			if index >= 0:
				_select(index)
		MOUSE_BUTTON_RIGHT:
			selected = -1
			render_game()
		MOUSE_BUTTON_MIDDLE:
			if not local_id.is_empty() and int(view.hints.get(local_id, 0)) > 0:
				send_action({"kind": "hint", "generation": generation})
	board_area.accept_event()

func _update_controls() -> void:
	var remaining_hints: int = 0 if view.is_empty() else int(view.hints.get(local_id, 0))
	controls.text = api.i18n.text(&"hud.controls", {"hints": remaining_hints})
	if local_id.is_empty():
		controls.text = "观战中\nEsc：菜单"

func start_game() -> void:
	cursors.enabled = true
	if api.is_host():
		rules.start(api.get_seed())
		for player: Dictionary in players:
			scores[player.player_id] = 0
			hints[player.player_id] = int(settings.get("hints", 3))

func tick_game(delta: float) -> void:
	cursors.enabled = not api.input.input_blocked
	board_view.advance(delta)
	hint_age = maxf(0, hint_age - delta)
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
	var changed_generation: bool = rendered_generation != int(view.generation)
	generation = view.generation
	rendered_generation = generation
	if changed_generation or (selected >= 0 and (view.board[selected] == 0 or int(view.board[selected]) != selected_value)):
		selected = -1
	if int(view.claim) != rendered_claim:
		rendered_claim = view.claim
		last_path = view.path
		path_color = view.color
		board_view.show_path(last_path, path_color)
	if changed_generation:
		hint_cells.clear()
		hint_age = 0.0
		board_view.clear_path()
	board_view.show_board(view.board, selected, hint_cells if hint_age > 0.0 else [])
	_update_controls()

func _select(index: int) -> void:
	if not running or local_id.is_empty() or view.is_empty() or int(view.board[index]) == 0:
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
	render_game()
