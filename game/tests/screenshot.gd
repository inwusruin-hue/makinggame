## Plays the game automatically for a while and saves a screenshot.
## Run: xvfb-run -s "-screen 0 1600x900x24" godot --path game --rendering-driver opengl3 -s tests/screenshot.gd -- out.png 40
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var seconds := float(args[1]) if args.size() > 1 else 30.0
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var frames := int(seconds * 60)
	for i in frames:
		if i > 90 and i % 14 == 0:
			main.drop()
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
