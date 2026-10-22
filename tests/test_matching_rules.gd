extends SceneTree
const Rules = preload("res://scripts/matching_rules.gd")
var checks := 0
var failures := 0
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var rules := Rules.new()
	for seed_value in range(80):
		rules.start(seed_value)
		check(rules.remaining == 80, "full board")
		check(rules.solution.size() == 40, "witness length")
		var initial := rules.board.duplicate()
		for pair in rules.solution:
			check(not rules.find_path(pair[0], pair[1]).is_empty(), "witness route")
			check(rules.remove_pair(pair[0], pair[1]).success, "witness removal")
		check(rules.remaining == 0, "cleared")
		rules.start(seed_value)
		check(rules.board == initial, "seed reproducibility")
		for i in range(12):
			var hint := rules.get_hint()
			if hint.is_empty():
				check(rules.shuffle_board(), "deadlock shuffle")
				hint = rules.get_hint()
			check(not hint.is_empty(), "live hint")
			rules.remove_pair(hint[0], hint[1])
		var before := rules.board.duplicate()
		var counts_before := before.duplicate()
		counts_before.sort()
		check(rules.shuffle_board(), "partial shuffle")
		var counts_after := rules.board.duplicate()
		counts_after.sort()
		check(counts_before == counts_after, "shuffle preserves types")
		for i in range(before.size()):
			check((before[i] == 0) == (rules.board[i] == 0), "shuffle preserves holes")
		for pair in rules.solution:
			check(rules.remove_pair(pair[0], pair[1]).success, "partial witness")
		check(rules.remaining == 0, "partial cleared")
	rules.rows = 2
	rules.cols = 3
	rules.board.assign([1, 2, 1, 2, 3, 3])
	rules.remaining = 6
	var path := rules.find_path(Vector2i(0,0), Vector2i(2,0))
	check(path.size() == 4, "outer ring route")
	check(path[1].y == -1, "top border used")
	check(rules.find_path(Vector2i(0,0), Vector2i(0,0)).is_empty(), "same cell illegal")
	check(rules.find_path(Vector2i(-1,0), Vector2i(0,0)).is_empty(), "empty illegal")
	check(rules.find_path(Vector2i(0,0), Vector2i(1,0)).is_empty(), "mismatch illegal")
	print("Matching rules: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
