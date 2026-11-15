extends SceneTree

## Bot de pruebas: repite, con la física REAL de Godot, el salto de referencia
## de cada plataforma (tools/recipes.json) y comprueba que aterriza donde debe.
##
## Uso:  godot --headless --path . -s res://tests/bot_test.gd

const MAX_FRAMES := 600


func _init() -> void:
	var level: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(level)
	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	process_frame.connect(_run.bind(player), CONNECT_ONE_SHOT)


func _run(player: Player) -> void:
	await physics_frame
	await physics_frame
	var recipes = JSON.parse_string(FileAccess.get_file_as_string("res://tools/recipes.json"))
	var ok := 0
	var fail := 0
	for r in recipes:
		var res := _try_hop(player, r)
		if res == "":
			ok += 1
		else:
			fail += 1
			print("FALLO ", r["src"], " -> ", r["dst"], ": ", res)
	print("RESULTADO: %d/%d saltos correctos, %d fallos" % [ok, recipes.size(), fail])
	quit(0 if fail == 0 else 1)


func _try_hop(player: Player, r: Dictionary) -> String:
	player.reset_to(Vector2(r["x"], float(r["src_top"]) - 31.0))
	for i in 30:
		player._physics_process(1.0 / 60.0)
		if player.grounded:
			break
	if not player.grounded:
		return "no aterriza en el origen"
	if player.floor_collider == null or str(player.floor_collider.name) != str(r["src"]):
		return "origen incorrecto (%s)" % [player.floor_collider.name if player.floor_collider else "nada"]
	player.pogo_angle = r["angle"]
	player.launch(r["force"], r["angle"])
	for i in MAX_FRAMES:
		player._physics_process(1.0 / 60.0)
		if player.grounded:
			var landed := str(player.floor_collider.name)
			if landed == str(r["dst"]):
				return ""
			return "aterrizó en %s" % landed
	return "nunca aterriza"
