extends SceneTree

## Pruebas de la lógica del baile (B) sin render.
## Uso:  godot --headless --path . -s res://tests/dance_test.gd

var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FALLA ", msg)
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String, frames := 2) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(1)


func _new_player() -> Player:
	var p: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	p.reset_to(Vector2(50000, 40))
	return p


func _run() -> void:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000, 40)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(50000, 100)
	root.add_child(floor_body)
	var p := _new_player()
	await _frames(30)
	var pivot: Node2D = p.get_node("Pivot")
	var dancer: Dancer = p.get_node("Dancer")

	print("== B inicia el baile")
	_check(p.grounded and not p.dancing, "en el suelo, sin bailar")
	_check(InputMap.has_action("dance"), "la acción 'dance' existe")
	await _tap("dance")
	_check(p.dancing, "B en el suelo empieza el baile")
	_check(not pivot.visible and dancer.visible, "se cambia el modelo: pogo oculto, bailarín visible")
	var x0 := p.global_position
	await _frames(40)
	_check(p.dancing and p.global_position.distance_to(x0) < 0.5, "sigue bailando quieto sin pulsar nada")
	_check(dancer.get_time() > 0.3, "la animación avanza (%.2f s)" % dancer.get_time())
	await _tap("dance")
	_check(p.dancing, "pulsar B otra vez no corta el baile")

	print("== otras teclas devuelven el pogo")
	for action in ["move_right", "move_left", "charge", "restart"]:
		if not p.dancing:
			await _tap("dance")
		_check(p.dancing, "(%s) bailando antes" % action)
		Input.action_press(action)
		await _frames(2)
		_check(not p.dancing, "(%s) corta el baile" % action)
		_check(pivot.visible and not dancer.visible, "(%s) vuelve el modelo del pogo" % action)
		Input.action_release(action)
		await _frames(3)
		if action == "charge":
			# soltar ESPACIO tras cortar el baile = salta (el baile no lo bloquea)
			await _frames(1)
			_check(p.jumps >= 1, "(charge) al soltar, el pogo salta con normalidad")
			for i in 400:
				await physics_frame
				if p.grounded:
					break
	_check(p.grounded, "aterriza de nuevo")

	print("== restricciones")
	Input.action_press("charge")
	await _frames(10)
	await _tap("dance")
	_check(not p.dancing, "no baila mientras carga un salto")
	Input.action_release("charge")
	await _frames(3)
	for i in 400:
		await physics_frame
		if p.grounded:
			break
	Input.action_press("charge")
	await _frames(25)
	Input.action_release("charge")
	await _frames(4)
	_check(not p.grounded, "está en el aire")
	await _tap("dance")
	_check(not p.dancing, "no baila en el aire")
	for i in 600:
		await physics_frame
		if p.grounded:
			break
	_check(p.grounded, "aterriza")

	print("== cortes por otras causas")
	await _tap("dance")
	_check(p.dancing, "baila")
	p.reset_to(Vector2(50000, 40))
	_check(not p.dancing and pivot.visible, "reset_to (R / checkpoint / F1-F8) corta el baile")
	await _frames(30)
	await _tap("dance")
	_check(p.dancing, "baila otra vez")
	# Se desliza fuera de la plataforma: sin suelo bajo los pies.
	p.global_position.y -= 120.0
	p.grounded = false
	await _frames(2)
	_check(not p.dancing and pivot.visible, "si pierde el suelo, corta el baile")
	for i in 300:
		await physics_frame
		if p.grounded:
			break
	await _frames(5)

	print("== signals")
	var started := [0]
	var ended := [0]
	p.dance_started.connect(func() -> void: started[0] += 1)
	p.dance_ended.connect(func() -> void: ended[0] += 1)
	await _tap("dance")
	await _tap("move_left")
	_check(started[0] == 1 and ended[0] == 1, "señales dance_started / dance_ended")

	print("RESULTADO: %s" % ["TODO OK" if _fails == 0 else "%d fallos" % _fails])
	quit(0 if _fails == 0 else 1)
