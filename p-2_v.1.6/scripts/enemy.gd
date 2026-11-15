extends Node2D

## Diablillo que patrulla una plataforma y nunca sale de ella.
##
##  - Si el jugador se mete en su camino lo EMPUJA de lado (sin retroceso ni
##    rebote, sin atravesar paredes). Si lo empuja hasta el borde de la
##    plataforma, sigue empujándolo hasta sacarlo de ella (cae).
##  - Si el jugador cae sobre su cabeza, el diablillo muere (suena el efecto) y el
##    spawner lo hace reaparecer, por un portal, ~30 s después en la misma plataforma.
##
## El spawner (enemy_spawner.gd) llama a setup() justo después de crearlo.
## Las hojas de sprites son recoloreadas por zona (tools/make_enemy_sprites.py):
##   assets/enemies/zone{1..8}_{right,left}.png  -> 6 frames de 48x48.

const FRAME_SIZE := 48
const FRAMES := 6
const ANIM_FPS := 8.0

## Hitbox del cuerpo (sin escalar) y mitad del collider del jugador (26x60).
const HIT_SIZE := Vector2(30.0, 30.0)
const PLAYER_HALF := Vector2(13.0, 30.0)
## Si los pies del jugador, en el frame anterior, estaban a esta distancia o
## menos por debajo de la cabeza (o por encima), cuenta como pisotón.
const STOMP_MARGIN := 8.0
## Al llegar al borde con el jugador delante: velocidad (px/s) y duración máxima
## (s) del empuje para sacarlo de la plataforma, y holgura para detectar contacto.
const EJECT_SPEED := 260.0
const EJECT_TIME := 1.0
const TOUCH_SLACK := 4.0

var _sprite: Sprite2D
var _tex_right: Texture2D
var _tex_left: Texture2D
var _min_x := 0.0
var _max_x := 0.0
var _speed := 50.0
var _dir := 1.0
var _pause := 0.0
var _anim := 0.0
var _rng := RandomNumberGenerator.new()
var _player: CharacterBody2D
var _scale := 1.0
var _dead := false
var _active := true   # false mientras sale del portal (sin hitbox ni movimiento)
var _data: Dictionary = {}
var _eject_dir := 0.0
var _eject_left := 0.0


## `data` lo prepara el spawner: zone_idx (0..7), top (superficie de la plataforma),
## min_x / max_x (límites del paseo, con margen), speed, scale y seed.
## `start_x`: dónde aparece (NAN = al azar). `emerge`: sale creciendo de un portal.
func setup(data: Dictionary, player: CharacterBody2D, start_x := NAN, emerge := false) -> void:
	_data = data
	var zone_idx: int = data["zone_idx"]
	var top: Vector2 = data["top"]
	var min_x: float = data["min_x"]
	var max_x: float = data["max_x"]
	var sprite_scale: float = data["scale"]
	_player = player
	_scale = sprite_scale
	_rng.seed = int(data["seed"])
	_min_x = min_x
	_max_x = max_x
	_speed = float(data["speed"])
	_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_anim = _rng.randf() * FRAMES

	var zone := zone_idx + 1
	_tex_right = load("res://assets/enemies/zone%d_right.png" % zone) as Texture2D
	_tex_left = load("res://assets/enemies/zone%d_left.png" % zone) as Texture2D
	if _tex_right == null or _tex_left == null:
		push_warning("Enemy: faltan los sprites de la zona %d" % zone)
		queue_free()
		return

	_sprite = Sprite2D.new()
	_sprite.texture = _tex_right if _dir > 0.0 else _tex_left
	_sprite.hframes = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	# El borde inferior del frame (48 px) queda justo sobre la plataforma.
	_sprite.position = Vector2(0.0, -FRAME_SIZE * 0.5 * sprite_scale)
	add_child(_sprite)

	var x := start_x if not is_nan(start_x) else _rng.randf_range(min_x, max_x)
	global_position = Vector2(clampf(x, min_x, max_x), top.y)

	if emerge:
		_active = false
		var target_scale := _sprite.scale
		var target_y := _sprite.position.y
		_sprite.scale = target_scale * 0.1
		_sprite.position.y = target_y * 0.1
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_sprite, "scale", target_scale, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "position:y", target_y, 0.45)
		tw.chain().tween_callback(func() -> void: _active = true)


func _process(delta: float) -> void:
	if _sprite == null:
		return

	_anim += delta * ANIM_FPS
	_sprite.frame = int(_anim) % FRAMES

	if not _active:
		return
	if _pause > 0.0:
		_pause -= delta
		return

	var x := global_position.x + _dir * _speed * delta
	if x >= _max_x:
		x = _max_x
		_turn()
	elif x <= _min_x:
		x = _min_x
		_turn()
	global_position.x = x


func _physics_process(delta: float) -> void:
	if _dead or not _active or _sprite == null or _player == null:
		return
	var half := HIT_SIZE * 0.5 * _scale
	var center := global_position + Vector2(0.0, -half.y)
	var p := _player.global_position
	var dx := p.x - center.x
	var overlap_x := PLAYER_HALF.x + half.x - absf(dx)
	var overlap_y := PLAYER_HALF.y + half.y - absf(p.y - center.y)

	# Sacar al jugador de la plataforma: sigue empujando hasta que se cae.
	if _eject_left > 0.0:
		_eject_left -= delta
		if _eject_dir != 0.0 and _player.get("grounded") == true:
			_player.move_and_collide(Vector2(_eject_dir * EJECT_SPEED * delta, 0.0))
		else:
			_eject_left = 0.0
			_eject_dir = 0.0

	if overlap_y <= 0.0 or overlap_x + TOUCH_SLACK <= 0.0:
		return

	# En el borde de su paseo con el jugador pegado delante: empieza a sacarlo.
	var edge_side := signf(dx)
	if edge_side == 0.0:
		edge_side = _dir
	var at_limit := (edge_side > 0.0 and global_position.x >= _max_x - 1.0) \
		or (edge_side < 0.0 and global_position.x <= _min_x + 1.0)
	if at_limit and _eject_left <= 0.0 and _player.get("grounded") == true:
		_eject_dir = edge_side
		_eject_left = EJECT_TIME
		_pause = maxf(_pause, EJECT_TIME + 0.3)

	if overlap_x <= 0.0:
		return

	# Pisotón: el jugador viene cayendo y sus pies estaban por encima de la cabeza.
	var head_y := center.y - half.y
	var feet_before := p.y + PLAYER_HALF.y - _player.velocity.y * delta
	if _player.velocity.y > 0.0 and feet_before <= head_y + STOMP_MARGIN:
		_die()
		return

	# Empujón: saca al jugador de la hitbox hacia el lado en que está, sin tocar
	# su velocidad (no hay retroceso). move_and_collide respeta las paredes.
	var side := signf(dx)
	if side == 0.0:
		side = _dir
	_player.move_and_collide(Vector2(side * overlap_x, 0.0))


func _die() -> void:
	_dead = true
	set_process(false)
	var parent := get_parent()
	if parent != null and parent.has_method("on_enemy_died"):
		parent.call("on_enemy_died", _data, global_position.x)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale:y", 0.05, 0.15)
	tw.tween_property(_sprite, "position:y", -1.0, 0.15)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _turn() -> void:
	_dir = -_dir
	_sprite.texture = _tex_right if _dir > 0.0 else _tex_left
	# A veces se detiene un momento en el borde.
	if _rng.randf() < 0.4:
		_pause = _rng.randf_range(0.5, 1.6)
