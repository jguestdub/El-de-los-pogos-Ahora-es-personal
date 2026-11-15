class_name InputSetup
extends RefCounted

## Registra por código las acciones de entrada del juego, para no depender de
## editar project.godot a mano.
##
##   move_left / move_right : A / D o flechas  -> inclinar el pogo
##   charge                 : ESPACIO          -> mantener para cargar, soltar para saltar
##   restart                : R                -> volver al inicio
##   back_to_menu           : ESC              -> volver a la pantalla de título
##   dance                  : B                -> bailar (solo en el suelo)

## Acciones que, al pulsarse, cortan el baile y devuelven el modelo del pogo.
const GAME_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"charge", &"restart", &"back_to_menu"]


static func ensure() -> void:
	_add("move_left", [KEY_A, KEY_LEFT])
	_add("move_right", [KEY_D, KEY_RIGHT])
	_add("charge", [KEY_SPACE])
	_add("restart", [KEY_R])
	_add("back_to_menu", [KEY_ESCAPE])
	_add("dance", [KEY_B])


static func _add(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)
