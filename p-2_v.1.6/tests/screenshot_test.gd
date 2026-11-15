extends SceneTree

## Toma capturas de cada zona (necesita render: xvfb-run + --rendering-driver opengl3).
## Uso: xvfb-run -a godot --path . -s res://tests/screenshot_test.gd -- /ruta/salida

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_run.bind(main), CONNECT_ONE_SHOT)


func _run(main: Node) -> void:
	var out := "/tmp/shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in 8:
		main._teleport_to_zone(i)
		for f in 45:
			await physics_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/zona_%d.png" % [out, i + 1])
	quit(0)
