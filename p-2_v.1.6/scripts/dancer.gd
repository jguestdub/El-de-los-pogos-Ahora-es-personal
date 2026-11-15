class_name Dancer
extends Node2D

## Bailarín 3D (voxel) que sustituye visualmente al pogo mientras el jugador baila.
##
## El modelo animado (assets/models/personaje_voxel_gangnam.glb) vive dentro de un
## SubViewport propio, con cámara ortogonal y fondo transparente. Ese viewport se
## muestra como un Sprite2D situado sobre los pies del jugador. Mientras no se baila
## el viewport no se renderiza (no cuesta nada).
##
## Para cambiar el baile: reemplaza el .glb por otro con una animación (o cambia el
## modelo del nodo Viewport/Model en player.tscn) y ajusta DISPLAY_HEIGHT.

## Altura del personaje en pantalla (px del mundo). El cuerpo del jugador mide 60.
const DISPLAY_HEIGHT := 64.0
## Altura del modelo en sus propias unidades (la cámara de Viewport/Camera lo encuadra).
const MODEL_HEIGHT := 7.6

@onready var _viewport: SubViewport = $Viewport
@onready var _sprite: Sprite2D = $Sprite
@onready var _model: Node = $Viewport/Model

var dancing := false
var _anim: AnimationPlayer
var _anim_name := ""


func _ready() -> void:
	visible = false
	_sprite.texture = _viewport.get_texture()
	_fit_sprite()
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for n in _anim.get_animation_list():
			if n != "RESET":
				_anim_name = n
				break
		if _anim_name != "":
			_anim.get_animation(_anim_name).loop_mode = Animation.LOOP_LINEAR
			# Una pasada previa para que la textura ya tenga el primer fotograma.
			_anim.play(_anim_name)
			_anim.seek(0.0, true)
			_anim.pause()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Escala el sprite para que el modelo mida DISPLAY_HEIGHT y sus pies queden en el
## origen de este nodo (que está a la altura de los pies del jugador).
func _fit_sprite() -> void:
	var cam := $Viewport/Camera as Camera3D
	var px_per_unit := float(_viewport.size.y) / cam.size
	var s := DISPLAY_HEIGHT / (MODEL_HEIGHT * px_per_unit)
	_sprite.scale = Vector2(s, s)
	# La cámara mira a la altura cam.position.y; los pies del modelo están en y = 0.
	_sprite.position = Vector2(0.0, -cam.position.y * px_per_unit * s)


## Empieza a bailar (la animación arranca siempre desde el principio).
func start() -> void:
	if dancing:
		return
	dancing = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _anim != null and _anim_name != "":
		_anim.play(_anim_name)
		_anim.seek(0.0, true)
	visible = true


## Deja de bailar y deja de renderizar el viewport.
func stop() -> void:
	if not dancing:
		return
	dancing = false
	visible = false
	if _anim != null:
		_anim.pause()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Segundos transcurridos de la animación (para pruebas).
func get_time() -> float:
	return _anim.current_animation_position if _anim != null else 0.0
