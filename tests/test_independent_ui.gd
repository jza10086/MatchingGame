extends SceneTree
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func check(ok:bool, label:String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run():
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for dimensions in [Vector2(960,640),Vector2(1920,1080)]:
		scene.size = dimensions
		scene._layout()
		await process_frame
		check(scene.buttons.size()==80,"80 initial tiles")
		for cell in scene.buttons:
			var rect:Rect2 = scene.buttons[cell].get_rect()
			check(Rect2(Vector2.ZERO,dimensions).encloses(rect),"tile outside screen")
		check(scene.board_panel.get_rect().end.y<=scene.status_label.position.y,"board overlaps status")
		check(scene.motion_button.get_rect().end.x<dimensions.x,"controls outside screen")
	scene._hint()
	check(scene.hint_cells.size()==2 and not scene.route.is_empty(),"hint route not shown")
	var pair:Array = scene.rules.get_hint()
	scene._select_cell(pair[0])
	scene._select_cell(pair[1])
	check(scene.busy,"match should be animated")
	var before:Array = scene.rules.board.duplicate()
	scene._select_cell(pair[0])
	scene._shuffle()
	scene._hint()
	check(scene.rules.board==before,"busy input changed board")
	scene._new_game()
	before = scene.rules.board.duplicate()
	await create_timer(.8).timeout
	check(scene.rules.board==before and scene.rules.remaining==80 and scene.matches==0,"stale match modifies restarted game")
	pair = scene.rules.get_hint()
	scene._select_cell(pair[0]); scene._select_cell(pair[1])
	await create_timer(.45).timeout
	check(scene.rules.remaining==78,"match did not remove pair")
	scene._new_game()
	scene._hint()
	await create_timer(.3).timeout
	check(scene.route_alpha>0.5,"old fade hides new-game hint")
	# Removing the only pair leaves a crossed square and must auto-shuffle.
	scene.rules.rows=3; scene.rules.cols=2
	scene.rules.board.assign([3,3,1,2,2,1]); scene.rules.remaining=6
	scene._rebuild_tiles(); scene.reduced_motion=true
	var prior_shuffles:int=scene.shuffles_used
	scene._select_cell(Vector2i(0,0)); scene._select_cell(Vector2i(1,0))
	await create_timer(.4).timeout
	check(scene.rules.remaining==4 and scene.shuffles_used==prior_shuffles+1 and not scene.rules.get_hint().is_empty(),"last available pair did not auto-recover deadlock")
	# Deadlock fixture with crossed unique pairs, then recover through hint.
	scene.rules.rows=2; scene.rules.cols=2
	scene.rules.board.assign([1,2,2,1]); scene.rules.remaining=4
	scene._rebuild_tiles()
	check(scene.rules.get_hint().is_empty(),"deadlock fixture must have no move")
	scene._request_restart()
	await process_frame
	check(scene.restart_dialog.visible,"restart dialog missing")
	var paused_elapsed:float=scene.elapsed
	scene._hint(); scene._shuffle(); scene._select_cell(Vector2i.ZERO)
	await create_timer(.1).timeout
	check(scene.elapsed==paused_elapsed and scene.rules.get_hint().is_empty(),"dialog fails to pause input/timer")
	scene.restart_dialog.get_cancel_button().emit_signal("pressed")
	await process_frame
	check(not scene.restart_dialog.visible,"cancel button failed to hide dialog")
	check(not scene.rules.get_hint().is_empty(),"cancel restart failed to recover pending deadlock")
	scene.rules.board.assign([1,2,2,1]); scene.rules.remaining=4
	scene._rebuild_tiles()
	scene._hint()
	check(not scene.rules.get_hint().is_empty(),"hint did not recover deadlock")
	# Victory through the actual asynchronous UI path.
	scene.rules.board.assign([1,1,0,0]); scene.rules.remaining=2
	scene._rebuild_tiles(); scene.reduced_motion=true
	scene._select_cell(Vector2i(0,0)); scene._select_cell(Vector2i(1,0))
	await create_timer(.4).timeout
	check(scene.rules.remaining==0 and scene.win_panel.visible and not scene.busy,"victory flow failed")
	print("INDEPENDENT UI: %d checks; %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
