extends Node2D

## Gestor del juego: cámara, HUD, zonas, tiempo y meta.
##
## Hay un checkpoint al inicio de cada zona (se activa al llegar a su plataforma
## inicial). R te devuelve al último checkpoint; en la zona 1 (o tras ganar)
## reinicia la partida. ESC abre el menú de pausa (volúmenes, reiniciar, volver al menú).
## Atajos de prueba:  F1..F8 te llevan al inicio de cada zona.

const LevelInfo := preload("res://scripts/level_info.gd")
const CAMERA_ZOOM := 0.8
const CAMERA_LOOK_UP := 40.0
const FOOT_OFFSET := 30.0
const DEBUG_KEYS := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8]
const EnemySpawner := preload("res://scripts/enemy_spawner.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Settings := preload("res://scripts/game_settings.gd")
const CheckpointFlag := preload("res://scripts/checkpoint_flag.gd")
## El checkpoint se activa al estar sobre una plataforma a esta altura (px) o menos
## por debajo del punto de aparición de la zona (las repisas inferiores quedan fuera).
const CHECKPOINT_TOLERANCE := 20.0
## Soundtrack por zona (mismo orden que LevelInfo.ZONES). Suena en bucle mientras
## el jugador está en la zona y cambia al entrar en otra, subiendo o bajando.
const MUSIC_PATHS := [
	"res://assets/music/pradera.mp3",
	"res://assets/music/bosque.mp3",
	"res://assets/music/cavernas.mp3",
	"res://assets/music/hielo.mp3",
	"res://assets/music/ruinas.mp3",
	"res://assets/music/volcan.mp3",
	"res://assets/music/cielo.mp3",
	"res://assets/music/cima.mp3",
]
const MUSIC_SILENT_DB := -40.0

@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _goal: Area2D = $Level/Goal
@onready var _hud: Label = $UI/HUD
@onready var _charge_bar: ProgressBar = $UI/ChargeBar
@onready var _banner: Label = $UI/ZoneBanner
@onready var _hint: Label = $UI/Hint
@onready var _win_panel: Control = $UI/WinPanel
@onready var _win_label: Label = $UI/WinPanel/Margin/WinLabel

var _best_height := 0.0
var _time := 0.0
var _running := false
var _won := false
var _zone_idx := -1
var _banner_tween: Tween
var _checkpoint_idx := 0
var _flags: Array = []
var _checkpoint_label: Label
var _checkpoint_tween: Tween
var _music: AudioStreamPlayer
var _music_streams: Array = []
var _music_idx := -1
var _music_tween: Tween
var _start_zone := 0


func _ready() -> void:
	InputSetup.ensure()
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.limit_left = 0
	_camera.limit_right = int(LevelInfo.WIDTH)
	_camera.limit_top = int(LevelInfo.TOP_Y)
	_camera.limit_bottom = 160
	_camera.offset = Vector2(0.0, -CAMERA_LOOK_UP)
	_goal.body_entered.connect(_on_goal_body_entered)
	Settings.ensure()
	_start_zone = clampi(Settings.start_zone, 0, LevelInfo.ZONES.size() - 1)
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_restart)
	_make_checkpoint_label()
	_setup_music()
	_build_world_extras()
	_restart()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var idx := DEBUG_KEYS.find(key.physical_keycode)
	if idx >= 0 and idx < LevelInfo.ZONES.size():
		_teleport_to_zone(idx)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_respawn()

	_camera.global_position = _player.global_position

	var height := _height_m(_player.global_position.y)
	_best_height = maxf(_best_height, height)

	if not _running and not _won and _player.jumps > 0:
		_running = true
	if _running and not _won:
		_time += delta

	_update_zone()
	_update_checkpoint()
	_hint.visible = _player.jumps < 3 and not _won
	_charge_bar.value = _player.get_charge_ratio() * 100.0
	_update_hud(height)


func _height_m(player_y: float) -> float:
	return maxf(0.0, (LevelInfo.GROUND_Y - (player_y + FOOT_OFFSET)) / LevelInfo.PX_PER_M)


func _update_zone() -> void:
	var y := _player.global_position.y
	var idx := 0
	# La zona activa es la más alta cuya base ya se superó (con margen para su plataforma inicial).
	for i in range(LevelInfo.ZONES.size() - 1, -1, -1):
		if y <= float(LevelInfo.ZONES[i]["y_bottom"]) + 200.0:
			idx = i
			break
	if idx != _zone_idx:
		_zone_idx = idx
		_play_zone_music(idx)
		_show_banner("ZONA %d · %s" % [idx + 1, LevelInfo.ZONES[idx]["name"]])


func _update_hud(height: float) -> void:
	var zone_name: String = LevelInfo.ZONES[maxi(_zone_idx, 0)]["name"]
	var minutes := int(_time) / 60
	var seconds := int(_time) % 60
	var checkpoint_name: String = LevelInfo.ZONES[_checkpoint_idx]["name"]
	_hud.text = "ALTURA: %d m   (máx %d m)\nZONA: %s\nTIEMPO: %02d:%02d\nSALTOS: %d\nCHECKPOINT: %s" % [
		int(height), int(_best_height), zone_name, minutes, seconds, _player.jumps, checkpoint_name
	]


func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _setup_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = &"Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS   # sigue sonando en pausa (para oír los sliders)
	add_child(_music)
	for path: String in MUSIC_PATHS:
		var stream := load(path) as AudioStream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_music_streams.append(stream)


## Cambia el tema de la zona `idx` con un pequeño fundido (no hace nada si ya suena).
func _play_zone_music(idx: int) -> void:
	if idx == _music_idx or idx >= _music_streams.size():
		return
	var stream: AudioStream = _music_streams[idx]
	if stream == null:
		return
	_music_idx = idx
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", MUSIC_SILENT_DB, 0.35)
	_music_tween.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = MUSIC_SILENT_DB
		_music.play())
	_music_tween.tween_property(_music, "volume_db", 0.0, 0.6)


## Enemigos en las plataformas y banderas de checkpoint (van detrás del jugador).
func _build_world_extras() -> void:
	var spawner: Node2D = EnemySpawner.new()
	spawner.name = "Enemies"
	add_child(spawner)
	move_child(spawner, _player.get_index())
	spawner.call("build", $Level/Terrain, _player)

	var flags_root := Node2D.new()
	flags_root.name = "Checkpoints"
	add_child(flags_root)
	move_child(flags_root, _player.get_index())
	var positions: Array[Vector2] = spawner.flag_positions
	for i in range(positions.size()):
		var flag: Node2D = CheckpointFlag.new()
		flag.position = positions[i]
		flag.set("zone_color", LevelInfo.ZONES[i]["color"])
		flags_root.add_child(flag)
		_flags.append(flag)


func _make_checkpoint_label() -> void:
	_checkpoint_label = Label.new()
	_checkpoint_label.anchor_left = 0.5
	_checkpoint_label.anchor_right = 0.5
	_checkpoint_label.offset_left = -300.0
	_checkpoint_label.offset_right = 300.0
	_checkpoint_label.offset_top = 132.0
	_checkpoint_label.offset_bottom = 172.0
	_checkpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_checkpoint_label.add_theme_font_size_override("font_size", 26)
	_checkpoint_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	_checkpoint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_checkpoint_label.add_theme_constant_override("outline_size", 8)
	_checkpoint_label.modulate.a = 0.0
	$UI.add_child(_checkpoint_label)


## Activa el checkpoint de la zona `idx` y lo anuncia en pantalla.
func _activate_checkpoint(idx: int) -> void:
	_checkpoint_idx = idx
	_refresh_flags()
	_checkpoint_label.text = "CHECKPOINT · ZONA %d  (R para volver aquí)" % (idx + 1)
	if _checkpoint_tween:
		_checkpoint_tween.kill()
	_checkpoint_label.modulate.a = 0.0
	_checkpoint_tween = create_tween()
	_checkpoint_tween.tween_property(_checkpoint_label, "modulate:a", 1.0, 0.3)
	_checkpoint_tween.tween_interval(2.2)
	_checkpoint_tween.tween_property(_checkpoint_label, "modulate:a", 0.0, 0.8)


func _refresh_flags() -> void:
	for i in range(_flags.size()):
		_flags[i].set("active", i == _checkpoint_idx)


func _update_checkpoint() -> void:
	if not _player.grounded:
		return
	var y := _player.global_position.y
	for i in range(LevelInfo.ZONES.size() - 1, _checkpoint_idx, -1):
		var spawn: Vector2 = LevelInfo.ZONES[i]["spawn"]
		if y <= spawn.y + CHECKPOINT_TOLERANCE:
			_activate_checkpoint(i)
			return


## R: vuelve al último checkpoint (conserva tiempo, altura máxima y saltos).
## En la zona de inicio, o después de ganar, reinicia la partida completa.
func _respawn() -> void:
	if _won or _checkpoint_idx == _start_zone:
		_restart()
		return
	var spawn: Vector2 = LevelInfo.ZONES[_checkpoint_idx]["spawn"]
	var jumps := _player.jumps
	_player.reset_to(spawn)
	_player.jumps = jumps
	_zone_idx = -1
	_camera.global_position = spawn
	_camera.reset_smoothing()


func _restart() -> void:
	_checkpoint_idx = _start_zone
	_refresh_flags()
	_player.reset_to(LevelInfo.ZONES[_start_zone]["spawn"])
	_best_height = 0.0
	_time = 0.0
	_running = false
	_won = false
	_zone_idx = -1
	_win_panel.visible = false
	_camera.global_position = _player.global_position
	_camera.reset_smoothing()


func _teleport_to_zone(idx: int) -> void:
	var spawn: Vector2 = LevelInfo.ZONES[idx]["spawn"]
	_player.reset_to(spawn)
	_checkpoint_idx = idx
	_refresh_flags()
	_camera.global_position = spawn
	_camera.reset_smoothing()


func _on_goal_body_entered(body: Node2D) -> void:
	if _won or body != _player:
		return
	_won = true
	var minutes := int(_time) / 60
	var seconds := int(_time) % 60
	_win_label.text = "¡LLEGASTE A LA CIMA!\n\nTiempo: %02d:%02d\nSaltos: %d\n\nR: volver a empezar    ESC: pausa" % [
		minutes, seconds, _player.jumps
	]
	_win_panel.visible = true
