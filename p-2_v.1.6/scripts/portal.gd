extends Node2D

## Portal de reaparición: se abre, emite `opened` (en ese momento el spawner crea al
## enemigo) y se cierra solo. Hoja de sprites: assets/effects/portal.png (8 frames
## de 128x128, generada con tools/make_portal_sprite.py).

signal opened

const FRAMES := 8
const FRAME_SIZE := 128.0
const FPS := 14.0

var _sprite: Sprite2D
var _anim := 0.0


## `center`: dónde se abre (mundo). `size_px`: diámetro aproximado en pantalla.
func setup(texture: Texture2D, center: Vector2, size_px: float) -> void:
	global_position = center
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = FRAMES
	_sprite.scale = Vector2.ONE * (size_px / FRAME_SIZE)
	add_child(_sprite)

	modulate.a = 0.0
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4)
	tw.chain().tween_callback(opened.emit)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_anim += delta * FPS
	_sprite.frame = int(_anim) % FRAMES
