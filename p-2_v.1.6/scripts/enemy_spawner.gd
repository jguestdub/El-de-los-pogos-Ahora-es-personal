extends Node2D

## Coloca diablillos de vez en cuando sobre las plataformas del nivel, con el
## aspecto (color) y tamaño de la zona donde está cada plataforma, y devuelve
## dónde poner la bandera de checkpoint de cada zona.
##
## Es determinista (misma semilla = mismos enemigos), así que la ruta es
## siempre la misma. Los enemigos empujan al jugador y mueren si les pisa la
## cabeza (ver enemy.gd) con un sonido; reaparecen ~30 s después por un portal.

const LevelInfo := preload("res://scripts/level_info.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const PortalScript := preload("res://scripts/portal.gd")
const PORTAL_TEXTURE := "res://assets/effects/portal.png"
const DEATH_SOUND := "res://assets/sfx/enemy_death.mp3"

## Reaparición: segundos (mín, máx) desde que muere hasta que se abre el portal.
const RESPAWN_MIN := 26.0
const RESPAWN_MAX := 34.0

const SEED := 20260514
## Probabilidad de que una plataforma apta tenga enemigo.
const SPAWN_CHANCE := 0.22
## Como mucho este número de plataformas aptas seguidas sin enemigo.
const MAX_GAP := 7
const MIN_PLATFORM_WIDTH := 190.0
const MAX_PLATFORM_HEIGHT := 60.0

## Multiplicador general de velocidad de patrulla.
const SPEED_MULT := 1.9

## Por zona: escala del sprite (forma/tamaño) y velocidad de patrulla (px/s).
const ZONE_STYLE := [
	{"scale": 1.5, "speed": 45.0},   # 1 Pradera
	{"scale": 1.5, "speed": 40.0},   # 2 Bosque
	{"scale": 2.0, "speed": 35.0},   # 3 Cavernas (grandes y lentos)
	{"scale": 1.5, "speed": 70.0},   # 4 Hielo (más pequeños y rápidos)
	{"scale": 2.0, "speed": 50.0},   # 5 Ruinas
	{"scale": 2.0, "speed": 60.0},   # 6 Volcán
	{"scale": 1.5, "speed": 65.0},   # 7 Cielo
	{"scale": 2.0, "speed": 55.0},   # 8 Cima
]

## Posición de la bandera de cada zona (sobre su plataforma inicial).
var flag_positions: Array[Vector2] = []

var _player: CharacterBody2D
var _death_stream: AudioStream
var _portal_texture: Texture2D
var _respawn_rng := RandomNumberGenerator.new()
## Pendientes de reaparecer: {"time": segundos restantes, "data": Dictionary, "x": float}
var _pending: Array[Dictionary] = []


func build(terrain: Node, player: CharacterBody2D) -> void:
	_player = player
	_respawn_rng.randomize()
	_death_stream = load(DEATH_SOUND) as AudioStream
	_portal_texture = load(PORTAL_TEXTURE) as Texture2D
	var platforms := _collect_platforms(terrain)
	var spawn_platforms := _find_spawn_platforms(platforms)
	_compute_flag_positions(spawn_platforms)

	# De abajo hacia arriba, para poder evitar enemigos en plataformas consecutivas.
	platforms.sort_custom(func(a: StaticBody2D, b: StaticBody2D) -> bool: return a.position.y > b.position.y)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var since_last := 99
	var count := 0
	for plat: StaticBody2D in platforms:
		since_last += 1
		if spawn_platforms.has(plat):
			continue
		# Nunca en dos plataformas seguidas, pero tampoco tramos largos sin enemigos.
		if since_last < 2 or (rng.randf() >= SPAWN_CHANCE and since_last < MAX_GAP):
			continue
		var size := _platform_size(plat)
		var zone_idx := _zone_of(plat.position.y)
		var style: Dictionary = ZONE_STYLE[zone_idx]
		var sprite_scale: float = style["scale"]
		# Mitad del ancho visible del sprite (~32 px) más un pequeño margen.
		var margin := 16.0 * sprite_scale + 8.0
		var min_x := plat.position.x - size.x * 0.5 + margin
		var max_x := plat.position.x + size.x * 0.5 - margin
		if max_x - min_x < 20.0:
			continue
		var data := {
			"zone_idx": zone_idx,
			"top": Vector2(plat.position.x, plat.position.y - size.y * 0.5),
			"min_x": min_x,
			"max_x": max_x,
			"speed": float(style["speed"]) * SPEED_MULT,
			"scale": sprite_scale,
			"seed": rng.randi(),
		}
		_spawn_enemy(data, NAN, false)
		since_last = 0
		count += 1


func _spawn_enemy(data: Dictionary, start_x: float, emerge: bool) -> void:
	var enemy: Node2D = EnemyScript.new()
	add_child(enemy)
	enemy.call("setup", data, _player, start_x, emerge)


## Lo llama enemy.gd al morir: suena el efecto y se programa la reaparición.
func on_enemy_died(data: Dictionary, x: float) -> void:
	_play_death_sound()
	_pending.append({"time": _respawn_rng.randf_range(RESPAWN_MIN, RESPAWN_MAX), "data": data, "x": x})


func _process(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i]["time"] = float(_pending[i]["time"]) - delta
		if float(_pending[i]["time"]) <= 0.0:
			var item: Dictionary = _pending[i]
			_pending.remove_at(i)
			_open_portal(item["data"], float(item["x"]))


## Abre el portal donde murió; cuando está abierto sale el enemigo.
func _open_portal(data: Dictionary, x: float) -> void:
	var s: float = data["scale"]
	var top: Vector2 = data["top"]
	var fresh := data.duplicate()
	fresh["seed"] = _respawn_rng.randi()
	if _portal_texture == null:
		_spawn_enemy(fresh, x, false)
		return
	var portal: Node2D = PortalScript.new()
	add_child(portal)
	portal.call("setup", _portal_texture, Vector2(x, top.y - 24.0 * s), 80.0 * s)
	portal.connect("opened", func() -> void: _spawn_enemy(fresh, x, true))


func _play_death_sound() -> void:
	if _death_stream == null:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _death_stream
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


# --------------------------------------------------------------------------

func _collect_platforms(terrain: Node) -> Array[StaticBody2D]:
	var result: Array[StaticBody2D] = []
	var rx := RegEx.new()
	rx.compile("^[PL][0-9]+$")   # P### = ruta principal, L### = repisas extra
	for child in terrain.get_children():
		var body := child as StaticBody2D
		if body == null or rx.search(String(body.name)) == null:
			continue
		var size := _platform_size(body)
		if size.x < MIN_PLATFORM_WIDTH or size.y > MAX_PLATFORM_HEIGHT:
			continue
		result.append(body)
	return result


func _platform_size(body: Node) -> Vector2:
	var shape_node := body.get_node_or_null("Shape") as CollisionShape2D
	if shape_node != null:
		var rect := shape_node.shape as RectangleShape2D
		if rect != null:
			return rect.size
	return Vector2.ZERO


func _zone_of(y: float) -> int:
	for i in range(LevelInfo.ZONES.size() - 1, -1, -1):
		if y <= float(LevelInfo.ZONES[i]["y_bottom"]):
			return i
	return 0


## Plataforma sobre la que cae el jugador al aparecer en cada zona (1..7).
func _find_spawn_platforms(platforms: Array[StaticBody2D]) -> Array[StaticBody2D]:
	var result: Array[StaticBody2D] = []
	for i in range(1, LevelInfo.ZONES.size()):
		var spawn: Vector2 = LevelInfo.ZONES[i]["spawn"]
		var best: StaticBody2D = null
		var best_dy := 1e9
		for plat in platforms:
			var size := _platform_size(plat)
			var top_y := plat.position.y - size.y * 0.5
			var dy := top_y - (spawn.y + 30.0)
			if absf(plat.position.x - spawn.x) <= size.x * 0.5 and dy >= -5.0 and dy < best_dy and dy < 60.0:
				best = plat
				best_dy = dy
		if best != null:
			result.append(best)
	return result


func _compute_flag_positions(spawn_platforms: Array[StaticBody2D]) -> void:
	flag_positions.clear()
	# Zona 1: suelo, a la izquierda del punto de inicio.
	flag_positions.append(Vector2(LevelInfo.START_POS.x - 220.0, LevelInfo.GROUND_Y))
	for i in range(1, LevelInfo.ZONES.size()):
		var spawn: Vector2 = LevelInfo.ZONES[i]["spawn"]
		var pos := Vector2(spawn.x, spawn.y + 30.0)
		if i - 1 < spawn_platforms.size():
			var plat := spawn_platforms[i - 1]
			var size := _platform_size(plat)
			# En el extremo de la plataforma opuesto al punto de aparición.
			var side := 1.0 if spawn.x < plat.position.x else -1.0
			pos = Vector2(plat.position.x + side * (size.x * 0.5 - 35.0), plat.position.y - size.y * 0.5)
		flag_positions.append(pos)
