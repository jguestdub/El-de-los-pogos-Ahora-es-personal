class_name Player
extends CharacterBody2D

## Pogo estilo "Pogostuck" / "Getting Over It".
##
## El pogo NUNCA rebota solo. Para saltar hay que:
##   1. Inclinar el pogo con A/D o las flechas (define la dirección del salto).
##   2. Mantener ESPACIO para cargar (más tiempo = salto más fuerte).
##   3. Soltar ESPACIO para saltar.
##
## En el aire se sigue inclinando el pogo (para llegar con el ángulo que
## quieras al siguiente salto) y hay un pequeño empujón lateral. Al chocar
## con paredes o techos se rebota; al caer en el suelo te quedas quieto
## (o te deslizas si es hielo).
##
## BAILE: con B (estando en el suelo y sin cargar) el pogo se sustituye por un
## bailarín 3D. El baile termina al pulsar cualquier otra acción del juego
## (A/D, ESPACIO, R, ESC), al reiniciar o si te caes de la plataforma.

signal launched(force: float)
signal landed(impact_speed: float)
signal dance_started
signal dance_ended

const GRAVITY := 1500.0
const TERMINAL_SPEED := 1900.0

## Velocidad de lanzamiento (px/s) sin carga y con carga completa.
const MIN_LAUNCH := 300.0
const MAX_LAUNCH := 1250.0
const CHARGE_TIME := 1.1

## Inclinación máxima del pogo respecto a la vertical y velocidad de giro.
const MAX_TILT := deg_to_rad(80.0)
const ROTATE_SPEED := 3.2

## Pequeño empujón horizontal permitido en el aire (px/s en total).
const NUDGE_ACCEL := 260.0
const NUDGE_MAX := 90.0

## Rebotes contra paredes / techos / pendientes empinadas.
const WALL_RESTITUTION := 0.5
const CEILING_RESTITUTION := 0.3
## Normal.y por debajo de este valor = suelo en el que se puede aterrizar.
const FLOOR_NORMAL_Y := -0.75

const SURFACES := {
	"normal": {"friction": 5000.0, "keep": 0.0},
	"ice": {"friction": 110.0, "keep": 0.9},
}

@export var start_position := Vector2(1000.0, -30.0)

var pogo_angle := 0.0
var charge := 0.0
var is_charging := false
var grounded := false
var floor_collider: Object = null
var jumps := 0
var dancing := false

var _nudge := 0.0
var _squash := 0.0
var _was_charge_held := false

@onready var _pivot: Node2D = $Pivot
@onready var _dust: CPUParticles2D = $Dust
@onready var _dancer: Dancer = $Dancer


func _ready() -> void:
	InputSetup.ensure()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	reset_to(start_position)


func _physics_process(delta: float) -> void:
	_update_dance_state()
	if not dancing:
		_handle_rotation(delta)
	if grounded:
		_ground_step(delta, not dancing)
	else:
		_air_step(delta)
	# Si el suelo desaparece bajo los pies (hielo, borde), se acaba el baile.
	if dancing and not grounded:
		stop_dance()
	_update_visual(delta)


# --------------------------------------------------------------------------
# Entrada
# --------------------------------------------------------------------------

func _handle_rotation(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(dir):
		pogo_angle = clampf(pogo_angle + dir * ROTATE_SPEED * delta, -MAX_TILT, MAX_TILT)


# --------------------------------------------------------------------------
# Baile
# --------------------------------------------------------------------------

func _update_dance_state() -> void:
	if dancing:
		for action in InputSetup.GAME_ACTIONS:
			if Input.is_action_just_pressed(action):
				stop_dance()
				return
	elif Input.is_action_just_pressed("dance") and can_dance():
		start_dance()


## Solo se puede bailar quieto en el suelo y sin estar cargando un salto.
func can_dance() -> bool:
	return grounded and not is_charging and not Input.is_action_pressed("charge")


func start_dance() -> void:
	if dancing:
		return
	dancing = true
	_pivot.visible = false
	_dancer.start()
	dance_started.emit()


func stop_dance() -> void:
	if not dancing:
		return
	dancing = false
	_pivot.visible = true
	_dancer.stop()
	dance_ended.emit()


# --------------------------------------------------------------------------
# En el suelo
# --------------------------------------------------------------------------

func _ground_step(delta: float, allow_charge := true) -> void:
	var surface := _surface_of(floor_collider)
	velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, float(surface["friction"]) * delta)

	var held := allow_charge and Input.is_action_pressed("charge")
	if held:
		is_charging = true
		charge = minf(charge + delta / CHARGE_TIME, 1.0)
	elif is_charging:
		# Soltó la tecla: ese es el único momento en que se puede saltar.
		launch(lerpf(MIN_LAUNCH, MAX_LAUNCH, charge), pogo_angle)
		return

	if absf(velocity.x) > 0.5:
		var hit := move_and_collide(Vector2(velocity.x * delta, 0.0))
		if hit:
			velocity.x = 0.0

	# ¿Seguimos pisando suelo? (si no, nos caemos del borde)
	if not test_move(global_transform, Vector2(0.0, 2.0)):
		grounded = false
		floor_collider = null
		is_charging = false
		charge = 0.0


# --------------------------------------------------------------------------
# En el aire
# --------------------------------------------------------------------------

func _air_step(delta: float) -> void:
	is_charging = false
	charge = 0.0

	velocity.y = minf(velocity.y + GRAVITY * delta, TERMINAL_SPEED)

	var dir := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(dir):
		var step := dir * NUDGE_ACCEL * delta
		var new_nudge := clampf(_nudge + step, -NUDGE_MAX, NUDGE_MAX)
		velocity.x += new_nudge - _nudge
		_nudge = new_nudge

	var hit := move_and_collide(velocity * delta)
	if hit == null:
		return

	var normal := hit.get_normal()
	if normal.y < FLOOR_NORMAL_Y and velocity.y > 0.0:
		_land(hit)
	elif normal.y > 0.75:
		velocity = velocity.bounce(normal) * CEILING_RESTITUTION
	else:
		velocity = velocity.bounce(normal) * WALL_RESTITUTION


func _land(hit: KinematicCollision2D) -> void:
	var impact := velocity.y
	floor_collider = hit.get_collider()
	grounded = true
	_nudge = 0.0
	var surface := _surface_of(floor_collider)
	velocity.x *= float(surface["keep"])
	velocity.y = 0.0
	# Si se mantiene ESPACIO al aterrizar, empieza a cargar enseguida.
	is_charging = false
	charge = 0.0
	_squash = clampf(impact / 1400.0, 0.1, 0.35)
	_puff(clampi(int(impact / 120.0), 3, 14))
	landed.emit(impact)


func _surface_of(body: Object) -> Dictionary:
	if body != null and body.has_meta("surface"):
		var key := String(body.get_meta("surface"))
		if SURFACES.has(key):
			return SURFACES[key]
	return SURFACES["normal"]


## Lanza al jugador. `force` en px/s, `angle` en radianes (0 = vertical).
func launch(force: float, angle: float) -> void:
	velocity = Vector2(sin(angle), -cos(angle)) * force
	grounded = false
	floor_collider = null
	is_charging = false
	charge = 0.0
	_nudge = 0.0
	jumps += 1
	_puff(6)
	launched.emit(force)


# --------------------------------------------------------------------------
# Visual
# --------------------------------------------------------------------------

func _update_visual(delta: float) -> void:
	_pivot.rotation = pogo_angle
	_squash = move_toward(_squash, 0.0, delta * 2.5)
	var compress := maxf(charge * 0.25, _squash)
	_pivot.scale = Vector2(1.0 + compress * 0.25, 1.0 - compress)


func _puff(count: int) -> void:
	_dust.position = Vector2(0.0, 30.0)
	_dust.amount = maxi(count, 1)
	_dust.restart()
	_dust.emitting = true


# --------------------------------------------------------------------------
# API pública
# --------------------------------------------------------------------------

## Teletransporta al jugador y borra todo el impulso.
func reset_to(target: Vector2) -> void:
	stop_dance()
	global_position = target
	velocity = Vector2.ZERO
	charge = 0.0
	is_charging = false
	grounded = false
	floor_collider = null
	pogo_angle = 0.0
	jumps = 0
	_nudge = 0.0
	_squash = 0.0
	if is_instance_valid(_pivot):
		_pivot.rotation = 0.0
		_pivot.scale = Vector2.ONE


## 0.0 a 1.0: cuánta fuerza hay almacenada ahora mismo.
func get_charge_ratio() -> float:
	return charge
