extends SceneTree

const Rules = preload("res://scripts/matching_rules.gd")
var checks := 0
var failures := 0
const DIRS = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

# Independent breadth-first search over (cell, direction, turns), including
# a one-cell empty border. Does not call production routing helpers.
func oracle(r, a: Vector2i, b: Vector2i) -> bool:
	if a == b or not inside(r,a) or not inside(r,b): return false
	if r.get_cell(a) == 0 or r.get_cell(a) != r.get_cell(b): return false
	var queue: Array = []
	var seen := {}
	for d in range(4):
		queue.append([a,d,0])
		seen[str(a)+":"+str(d)+":0"] = true
	var cursor := 0
	while cursor < queue.size():
		var state = queue[cursor]
		cursor += 1
		for d in range(4):
			var turns: int = state[2] + (0 if d == state[1] else 1)
			if turns > 2: continue
			var p: Vector2i = state[0] + DIRS[d]
			if p.x < -1 or p.x > r.cols or p.y < -1 or p.y > r.rows: continue
			if p == b: return true
			if inside(r,p) and r.get_cell(p) != 0: continue
			var key := str(p)+":"+str(d)+":"+str(turns)
			if not seen.has(key):
				seen[key] = true
				queue.append([p,d,turns])
	return false

func inside(r, p:Vector2i) -> bool:
	return p.x >= 0 and p.x < r.cols and p.y >= 0 and p.y < r.rows

func verify_path(r, a:Vector2i, b:Vector2i, path:Array) -> bool:
	if path.size() < 2 or path.size() > 4 or path.front() != a or path.back() != b: return false
	for i in range(1,path.size()):
		var delta:Vector2i = path[i] - path[i-1]
		if delta == Vector2i.ZERO or (delta.x != 0 and delta.y != 0): return false
		var step := Vector2i(signi(delta.x),signi(delta.y))
		var p:Vector2i = path[i-1]+step
		while true:
			if p.x < -1 or p.x > r.cols or p.y < -1 or p.y > r.rows: return false
			if p != a and p != b and inside(r,p) and r.get_cell(p) != 0: return false
			if p == path[i]: break
			p += step
	return true

func snapshot_counts(r) -> Dictionary:
	var result := {}
	for v in r.board:
		result[v] = result.get(v,0)+1
	return result

func random_routing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 728192
	for trial in range(48):
		var r = Rules.new()
		r.rows = 4
		r.cols = 5
		r.board.clear()
		for i in range(20): r.board.append(rng.randi_range(0,3))
		for n in range(28):
			var a := Vector2i(rng.randi_range(-1,5),rng.randi_range(-1,4))
			var b := Vector2i(rng.randi_range(-1,5),rng.randi_range(-1,4))
			var expected := oracle(r,a,b)
			var path:Array = r.find_path(a,b)
			check(not path.is_empty() == expected, "routing oracle mismatch trial%d %s->%s" % [trial,a,b])
			if not path.is_empty(): check(verify_path(r,a,b,path), "route contains blocked cell or invalid segment")
		# Compare every equal, nonempty pair on a compact randomized board.
		for i in range(20):
			for j in range(i+1,20):
				if r.board[i] == 0 or r.board[i] != r.board[j]: continue
				var a := Vector2i(i%5,i/5)
				var b := Vector2i(j%5,j/5)
				var path:Array = r.find_path(a,b)
				check(not path.is_empty() == oracle(r,a,b),"equal-pair oracle mismatch")
				if not path.is_empty(): check(verify_path(r,a,b,path),"invalid corner path")

func witness_and_shuffle() -> void:
	for seed_value in range(30):
		var r = Rules.new()
		r.start(seed_value)
		check(r.remaining == r.rows*r.cols,"initial remaining")
		check(r.solution.size()*2 == r.remaining,"full initial witness")
		var original_counts := snapshot_counts(r)
		for v in original_counts:
			check(v != 0 and original_counts[v]%2 == 0,"initial pairs only")
		var witness:Array = r.solution.duplicate(true)
		for pair in witness:
			check(oracle(r,pair[0],pair[1]),"initial witness step invalid")
			var before:int = r.remaining
			var hint:Array = r.get_hint()
			check(hint.size()==2 and oracle(r,hint[0],hint[1]),"hint invalid")
			var result:Dictionary = r.remove_pair(pair[0],pair[1])
			check(result.success and r.remaining == before-2,"witness removal fails")
		check(r.remaining==0 and r.get_hint().is_empty(),"empty board end state")
		r.start(seed_value+100)
		witness = r.solution.duplicate(true)
		for i in range(7): r.remove_pair(witness[i][0],witness[i][1])
		var counts := snapshot_counts(r)
		var occupied:Array = []
		for i in range(r.board.size()):
			if r.board[i] != 0: occupied.append(i)
		check(r.shuffle_board(),"shuffle failed")
		check(snapshot_counts(r)==counts,"shuffle changes tile multiset")
		var occupied_after:Array = []
		for i in range(r.board.size()):
			if r.board[i] != 0: occupied_after.append(i)
		check(occupied==occupied_after,"shuffle changes occupied pattern")
		witness = r.solution.duplicate(true)
		check(witness.size()*2==r.remaining,"shuffle lacks complete witness")
		for pair in witness:
			check(oracle(r,pair[0],pair[1]),"shuffle witness step invalid")
			r.remove_pair(pair[0],pair[1])
		check(r.remaining==0,"shuffle witness cannot clear board")

func targeted_routes() -> void:
	var r = Rules.new()
	r.rows = 5
	r.cols = 5
	r.board.resize(25)
	r.board.fill(9)
	for cell in [Vector2i(1,1),Vector2i(2,1),Vector2i(2,2),Vector2i(3,2),Vector2i(3,3)]:
		r.board[cell.y*5+cell.x] = 0
	r.board[6] = 1
	r.board[18] = 1
	check(r.find_path(Vector2i(1,1),Vector2i(3,3)).is_empty(),"three-turn corridor incorrectly accepted")
	r.board.fill(9)
	r.board[0] = 1
	r.board[4] = 1
	var path:Array = r.find_path(Vector2i(0,0),Vector2i(4,0))
	check(not path.is_empty() and verify_path(r,Vector2i(0,0),Vector2i(4,0),path),"outside-board two-turn path missing")
	check(path.size()==4,"blocked row should use exterior corners")
	r.board.fill(0)
	r.board[6] = 1
	r.board[18] = 1
	check(r.find_path(Vector2i(1,1),Vector2i(3,3)).size()==3,"one-turn clear path missing")
	r.board[18] = 2
	check(r.find_path(Vector2i(1,1),Vector2i(3,3)).is_empty(),"different tile types connected")
	var before:Array = r.board.duplicate()
	check(not r.shuffle_board() and r.board==before,"odd-count invalid shuffle changed board")

func invalid_mutations() -> void:
	var r = Rules.new()
	r.start(17)
	var prior:Array = r.board.duplicate()
	var remaining:int = r.remaining
	for pair in [[Vector2i.ZERO,Vector2i.ZERO],[Vector2i(-1,0),Vector2i.ZERO],[Vector2i(99,99),Vector2i.ZERO]]:
		check(not r.remove_pair(pair[0],pair[1]).success,"invalid move accepted")
		check(prior==r.board and remaining==r.remaining,"invalid move mutates state")

func _run() -> void:
	targeted_routes()
	random_routing()
	witness_and_shuffle()
	invalid_mutations()
	print("INDEPENDENT REVIEW: %d checks; %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
