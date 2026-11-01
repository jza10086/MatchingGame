extends RefCounted
## Classic tile linking. Coordinates are (column, row); a one-cell exterior ring is legal.

var rows: int = 8
var cols: int = 10
var board: Array[int] = []
var remaining: int = 0
var solution: Array = []
var generation_seed: int = 0
var _rng: Variant = RandomNumberGenerator.new()

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
		generation_seed = int(_rng.seed)
	else:
		generation_seed = seed_value
		_rng.seed = seed_value
	board.clear()
	board.resize(rows * cols)
	board.fill(1)
	remaining = board.size()
	if remaining % 2 != 0:
		board[board.size() - 1] = 0
		remaining -= 1
	var values: Array[int] = []
	for i: Variant in range(remaining / 2):
		values.append(i % 10 + 1)
	_assign_solvable(values)

func get_cell(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return 0
	var index: Variant = cell.y * cols + cell.x
	return board[index] if index < board.size() else 0

func _inside_ring(cell: Vector2i) -> bool:
	return cell.x >= -1 and cell.x <= cols and cell.y >= -1 and cell.y <= rows

func _segment_clear(a: Vector2i, b: Vector2i) -> bool:
	if not _inside_ring(a) or not _inside_ring(b):
		return false
	if a.x != b.x and a.y != b.y:
		return false
	if a == b:
		return true
	var step: Variant = Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var current: Variant = a + step
	while current != b:
		if get_cell(current) != 0:
			return false
		current += step
	return true

func _compress(points: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for point: Variant in points:
		if not result.is_empty() and result.back() == point:
			continue
		if result.size() >= 2:
			var a: Vector2i = result[result.size() - 2]
			var b: Vector2i = result.back()
			if (a.x == b.x and b.x == point.x) or (a.y == b.y and b.y == point.y):
				result.pop_back()
		result.append(point)
	return result

func _geometric_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if a == b:
		return []
	if (a.x == b.x or a.y == b.y) and _segment_clear(a, b):
		return [a, b]
	for corner: Variant in [Vector2i(a.x, b.y), Vector2i(b.x, a.y)]:
		if get_cell(corner) == 0 and _segment_clear(a, corner) and _segment_clear(corner, b):
			return _compress([a, corner, b])
	# Horizontal / vertical middle segments enumerate every legal two-turn route.
	for x: Variant in range(-1, cols + 1):
		var c: Variant = Vector2i(x, a.y)
		var d: Variant = Vector2i(x, b.y)
		if (c == a or get_cell(c) == 0) and (d == b or get_cell(d) == 0):
			if _segment_clear(a, c) and _segment_clear(c, d) and _segment_clear(d, b):
				return _compress([a, c, d, b])
	for y: Variant in range(-1, rows + 1):
		var c: Variant = Vector2i(a.x, y)
		var d: Variant = Vector2i(b.x, y)
		if (c == a or get_cell(c) == 0) and (d == b or get_cell(d) == 0):
			if _segment_clear(a, c) and _segment_clear(c, d) and _segment_clear(d, b):
				return _compress([a, c, d, b])
	return []

func find_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if get_cell(a) == 0 or get_cell(a) != get_cell(b):
		return []
	return _geometric_path(a, b)

func get_hint() -> Array[Vector2i]:
	var cells: Variant = _occupied_cells()
	for i: Variant in range(cells.size()):
		for j: Variant in range(i + 1, cells.size()):
			if get_cell(cells[i]) == get_cell(cells[j]) and not find_path(cells[i], cells[j]).is_empty():
				return [cells[i], cells[j]]
	return []

func remove_pair(a: Vector2i, b: Vector2i) -> Dictionary:
	var path: Variant = find_path(a, b)
	if path.is_empty():
		return {"success": false, "path": path, "remaining": remaining, "won": remaining == 0}
	board[a.y * cols + a.x] = 0
	board[b.y * cols + b.x] = 0
	remaining -= 2
	return {"success": true, "path": path, "remaining": remaining, "won": remaining == 0}

func _occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: Variant in range(rows):
		for x: Variant in range(cols):
			if get_cell(Vector2i(x, y)) != 0:
				cells.append(Vector2i(x, y))
	return cells

func _shuffle(array: Array) -> void:
	for i: Variant in range(array.size() - 1, 0, -1):
		var j: Variant = _rng.randi_range(0, i)
		var temporary: Variant = array[i]
		array[i] = array[j]
		array[j] = temporary

func _assign_solvable(pair_values: Array[int]) -> bool:
	var saved_board: Variant = board.duplicate()
	var cells: Variant = _occupied_cells()
	var pairs: Array = []
	while cells.size() >= 2:
		_shuffle(cells)
		var found: Variant = false
		for i: Variant in range(cells.size()):
			for j: Variant in range(i + 1, cells.size()):
				if not _geometric_path(cells[i], cells[j]).is_empty():
					var a: Variant = cells[i]
					var b: Variant = cells[j]
					pairs.append([a, b])
					board[a.y * cols + a.x] = 0
					board[b.y * cols + b.x] = 0
					cells.remove_at(j)
					cells.remove_at(i)
					found = true
					break
			if found:
				break
		if not found:
			board = saved_board
			return false
	_shuffle(pair_values)
	for i: Variant in range(pairs.size()):
		for cell: Variant in pairs[i]:
			board[cell.y * cols + cell.x] = pair_values[i]
	solution = pairs
	return true

func shuffle_board() -> bool:
	var counts: Dictionary = {}
	for value: Variant in board:
		if value != 0:
			counts[value] = int(counts.get(value, 0)) + 1
	var values: Array[int] = []
	for value: Variant in counts:
		if int(counts[value]) % 2 != 0:
			return false
		for i: Variant in range(int(counts[value]) / 2):
			values.append(int(value))
	return _assign_solvable(values)
