extends SceneTree

## Captura el baile con render real (xvfb-run + --rendering-driver opengl3).
## Uso: xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tests/dance_screenshot_test.gd -- /ruta/salida

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_run.bind(main), CONNECT_ONE_SHOT)


func _run(main: Node) -> void:
	var out := "/tmp/dance_shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var player: Player = main.get_node("Player")
	main.get_node("UI").visible = false
	for i in 90:
		await physics_frame
	await process_frame
	_shot(player, out, "0_pogo")
	Input.action_press("dance")
	await physics_frame
	Input.action_release("dance")
	var times := [0.3, 2.0, 4.0, 6.0, 8.5, 9.5, 10.5]
	var t := 0.0
	var k := 1
	for target in times:
		while player.get_node("Dancer").get_time() < target:
			await process_frame
		await process_frame
		_shot(player, out, "%d_baile_%.1f" % [k, target])
		k += 1
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	Input.action_release("move_right")
	await process_frame
	await process_frame
	_shot(player, out, "%d_pogo_de_nuevo" % k)
	quit(0)


func _shot(player: Player, out: String, name: String) -> void:
	var img := root.get_texture().get_image()
	# Posición del jugador en píxeles de la ventana.
	var p: Vector2 = root.get_final_transform() * player.get_global_transform_with_canvas().origin
	var half := 60
	var x := clampi(int(p.x) - half, 0, img.get_width() - 2 * half)
	var y := clampi(int(p.y) - half - 10, 0, img.get_height() - 2 * half)
	img.get_region(Rect2i(x, y, 2 * half, 2 * half)).save_png("%s/%s.png" % [out, name])
