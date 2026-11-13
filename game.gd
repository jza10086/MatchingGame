extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
## One shared board: host serializes tile claims; only a shuffle invalidates unrelated claims.
const Rules: Script = preload("res://games/minigame/gp_matching/matching_rules.gd")
const Cursors: PackedScene = preload("res://games/assets/godot_party_default_ui/player_cursors.tscn")
const BoardView: Script = preload("res://games/minigame/gp_matching/board_3d.gd")
var rules: RefCounted = Rules.new()
var scores: Dictionary = {}
var hints: Dictionary = {}
var generation: int = 0
var end_msec: int = 0
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
		controls.text = api.i18n.text(&"hud.spectating")

func start_game() -> void:
	cursors.enabled = true
	if api.is_host():
		rules.start(api.get_seed())
		end_msec = api.net.host_time_msec() + roundi(float(settings.get("duration", 180)) * 1000.0)
		for player: Dictionary in players:
			scores[player.player_id] = 0
			hints[player.player_id] = int(settings.get("hints", 3))

func tick_game(delta: float) -> void:
	cursors.enabled = not api.input.input_blocked
	board_view.advance(delta)
	hint_age = maxf(0, hint_age - delta)
	if api.is_host() and (rules.remaining == 0 or elapsed >= float(settings.get("duration", 180))):
		finish_scores(scores, {}, [{"key": "score", "title": api.i18n.text(&"result.pairs"), "format": "integer"}])

func handle_action(id: String, data: Dictionary) -> void:
	if int(data.get("generation", -1)) != generation:
		return
	if data.get("kind") == "hint" and int(hints[id]) > 0:
		var send_error: Error = api.net.send_to_player(id, &"private_view", {"hint": rules.get_hint(), "generation": generation})
		if send_error != OK:
			# A rejected send must neither consume a hint nor leave the round accepting actions.
			party_stop(&"hint_send_failed")
			cursors.enabled = false
			var message: String = api.i18n.text(&"error.hint_send", {"error": error_string(send_error)})
			var fail_error: Error = api.fail("hint_send_failed", message)
			if fail_error != OK:
				push_error("%s (%s)" % [message, error_string(fail_error)])
			return
		hints[id] -= 1
		_send_change({"kind": "hint", "id": id, "hints": hints[id]})
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
			var changed: Dictionary = {"kind": "pair", "id": id, "score": scores[id], "cells": [a, b],
				"path": last_path, "color": path_color, "claim": claim_revision, "remaining": rules.remaining}
			if rules.remaining > 0 and rules.get_hint().is_empty():
				rules.shuffle_board()
				generation += 1
				changed["board"] = rules.board.duplicate()
			changed["generation"] = generation
			_send_change(changed)

func make_snapshot() -> Dictionary:
	return {"board": rules.board.duplicate(), "scores": scores.duplicate(), "hints": hints.duplicate(), "generation": generation, "remaining": rules.remaining, "time": maxf(0, float(settings.get("duration", 180)) - elapsed), "path": last_path, "color": path_color, "claim": claim_revision, "end_msec": end_msec}

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

## Initial layout uses publish once; subsequent reliable events contain only this action's result.
func _send_change(change: Dictionary) -> void:
	var error: Error = api.net.broadcast(&"matching/change", change)
	if error != OK:
		party_stop(&"publication_failed")
		api.fail("matching_change", error_string(error))

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic != &"matching/change":
		super._message(sender, topic, payload)
		return
	if not running or sender.peer_id != 1 or not payload is Dictionary or view.is_empty():
		return
	if not payload.get("id") is String or not view.scores.has(payload.id):
		return
	if payload.get("kind") == "hint":
		if not payload.get("hints") is int or payload.hints < 0:
			return
		view.hints[payload.id] = payload.hints
	elif payload.get("kind") == "pair":
		if not payload.get("claim") is int or payload.claim <= view.claim or not payload.get("cells") is Array or payload.cells.size() != 2:
			return
		if not payload.get("score") is int or not payload.get("remaining") is int or not payload.get("generation") is int or not payload.get("path") is Array or not payload.get("color") is Color:
			return
		for cell: Variant in payload.cells:
			if not cell is int or cell < 0 or cell >= 80:
				return
		if payload.has("board"):
			if not payload.board is Array or payload.board.size() != 80:
				return
			for cell: Variant in payload.board:
				if not cell is int or cell < 0 or cell > 10:
					return
			view.board = payload.board.duplicate()
		else:
			for cell: int in payload.cells:
				view.board[cell] = 0
		view.scores[payload.id] = payload.score
		for key: String in ["claim", "remaining", "generation", "path", "color"]:
			view[key] = payload[key]
	else:
		return
	render_game()
