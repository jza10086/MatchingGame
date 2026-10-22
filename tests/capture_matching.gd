extends SceneTree
var app
var output := ""
func _initialize(): call_deferred("run")
func snap(label: String):
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var img=root.get_texture().get_image()
	print("CAPTURE ",label," ",img.get_size()," result=",img.save_png(output.path_join(label+".png")))
func outer_pair() -> Array:
	var cells=app.rules._occupied_cells()
	for a in cells:
		for b in cells:
			if a==b: continue
			var path=app.rules.find_path(a,b)
			for c in path:
				if c.x<0 or c.y<0 or c.x>=app.rules.cols or c.y>=app.rules.rows: return [a,b]
	return app.rules.get_hint()
func run():
	output=OS.get_environment("CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.rules.start(2026)
	app._rebuild_tiles()
	await snap("01-full-board")
	var pair=outer_pair()
	app.hint_cells.assign(pair)
	app.route=app.rules.find_path(pair[0],pair[1])
	app.route_alpha=.9
	app.route_progress=1
	await snap("02-outer-route")
	root.size=Vector2i(960,640)
	await snap("03-small-route")
	root.size=Vector2i(1920,1080)
	await snap("04-large-route")
	root.size=Vector2i(960,640)
	app.route_alpha=0
	await create_timer(.3).timeout
	var images=[]
	var stamps=[]
	var start=Time.get_ticks_msec()
	for n in 3:
		pair=outer_pair() if n==0 else app.rules.get_hint()
		app._select_cell(pair[0])
		await create_timer(.18).timeout
		app._select_cell(pair[1])
		var until=Time.get_ticks_msec()+1100
		while Time.get_ticks_msec()<until:
			await RenderingServer.frame_post_draw
			images.append(root.get_texture().get_image())
			stamps.append({"frame":images.size()-1,"ms":Time.get_ticks_msec()-start})
			await create_timer(.066).timeout
	var d=output.path_join("match-frames")
	DirAccess.make_dir_recursive_absolute(d)
	for i in images.size(): images[i].save_png(d.path_join("frame-%04d.png"%i))
	FileAccess.open(d.path_join("timing.json"),FileAccess.WRITE).store_string(JSON.stringify(stamps))
	print("MOTION frames=",images.size()," remaining=",app.rules.remaining)
	root.size=Vector2i(1280,800)
	await snap("05-after-matches")
	app.queue_free()
	await process_frame
	print("CAPTURE_DONE")
	quit()
