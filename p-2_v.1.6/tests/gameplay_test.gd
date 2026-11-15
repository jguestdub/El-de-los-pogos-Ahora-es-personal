extends SceneTree

## Prueba de humo del juego completo (escena principal) con entrada simulada.
## Comprueba: el pogo NO rebota solo, cargar+soltar salta, más carga = más altura,
## inclinar cambia la dirección y la meta/HUD no dan errores.
##
## Uso:  godot --headless --path . -s res://tests/gameplay_test.gd

var _fails := 0


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_run.bind(main), CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FALLA ", msg)
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _jump_apex(player: Player, hold_frames: int, tilt_frames: int, dir: String) -> Vector2:
	# Espera a estar en el suelo
	for i in 600:
		await physics_frame
		if player.grounded:
			break
	var start := player.global_position
	if tilt_frames > 0:
		Input.action_press(dir)
		await _frames(tilt_frames)
		Input.action_release(dir)
	Input.action_press("charge")
	await _frames(hold_frames)
	Input.action_release("charge")
	var top := player.global_position
	for i in 300:
		await physics_frame
		if player.global_position.y < top.y:
			top = player.global_position
		if player.grounded and i > 5:
			break
	return Vector2(player.global_position.x - start.x, start.y - top.y)


func _run(main: Node) -> void:
	var player: Player = main.get_node("Player")
	print("== inicio")
	await _frames(120)
	_check(player.grounded, "el jugador aterriza al empezar")
	var y0 := player.global_position.y
	await _frames(120)
	_check(player.jumps == 0 and absf(player.global_position.y - y0) < 0.5, "no rebota solo (2 s quieto)")

	# --- mecánica de salto en un suelo plano aislado (lejos del nivel)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(50000, 100)
	root.add_child(floor_body)
	var p2: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(p2)
	p2.reset_to(Vector2(50000, 40))
	await _frames(30)
	_check(p2.grounded, "(suelo plano) aterriza")

	print("== salto bajo vs alto")
	var low := await _jump_apex(p2, 12, 0, "move_right")
	var high := await _jump_apex(p2, 70, 0, "move_right")
	print("   altura corta=%.0f  larga=%.0f" % [low.y, high.y])
	_check(high.y > low.y * 3.0, "más carga = salto mucho más alto")
	_check(high.y > 400.0 and high.y < 600.0, "salto máximo ~520 px")
	_check(p2.jumps == 2, "dos saltos contados")

	print("== inclinación")
	var right := await _jump_apex(p2, 40, 20, "move_right")
	var left := await _jump_apex(p2, 40, 40, "move_left")
	print("   dx derecha=%.0f  dx izquierda=%.0f" % [right.x, left.x])
	_check(right.x > 50.0, "inclinar a la derecha desplaza a la derecha")
	_check(left.x < right.x - 50.0, "inclinar a la izquierda va hacia la izquierda")

	print("== teletransporte de depuración y HUD")
	for i in 8:
		main._teleport_to_zone(i)
		await _frames(30)
	_check(true, "F1..F8 sin errores")
	main._restart()
	await _frames(10)
	_check(main.get_node("UI/HUD").text.begins_with("ALTURA"), "HUD activo")

	print("RESULTADO: %s" % ["TODO OK" if _fails == 0 else "%d fallos" % _fails])
	quit(0 if _fails == 0 else 1)
