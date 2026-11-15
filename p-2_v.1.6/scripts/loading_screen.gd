extends Control

## Title / loading screen. Fills a progress bar, waits for Space and then lets the
## player choose the zone to start in (the choice goes to GameSettings.start_zone).

const Settings := preload("res://scripts/game_settings.gd")
const LevelInfo := preload("res://scripts/level_info.gd")

const NEXT_SCENE := "res://scenes/main.tscn"
const LOAD_TIME := 1.6

@onready var _progress: ProgressBar = $Center/VBox/Progress
@onready var _status: Label = $Center/VBox/Status
@onready var _prompt: Label = $Center/VBox/Prompt

var _elapsed := 0.0
var _is_ready := false
var _started := false
var _selecting := false


func _ready() -> void:
	Settings.ensure()
	_prompt.visible = false


func _process(delta: float) -> void:
	_elapsed += delta
	var ratio := clampf(_elapsed / LOAD_TIME, 0.0, 1.0)
	_progress.value = ratio * 100.0

	if ratio >= 1.0 and not _is_ready:
		_finish_loading()

	if _is_ready and not _selecting and Input.is_action_just_pressed("ui_accept"):
		_open_zone_select()


func _finish_loading() -> void:
	_is_ready = true
	_status.text = "LISTO"
	_prompt.visible = true
	var tween := create_tween().set_loops()
	tween.tween_property(_prompt, "modulate:a", 0.25, 0.6)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.6)


## Cuadrícula de zonas (4x2): flechas / ratón + ESPACIO o ENTER.
func _open_zone_select() -> void:
	_selecting = true
	_status.visible = false
	_progress.visible = false
	_prompt.visible = false

	var vbox: VBoxContainer = $Center/VBox
	var title := Label.new()
	title.text = "ELIGE LA ZONA DONDE EMPEZAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	var buttons: Array[Button] = []
	for i in range(LevelInfo.ZONES.size()):
		var button := Button.new()
		button.text = "%d · %s" % [i + 1, LevelInfo.ZONES[i]["name"]]
		button.custom_minimum_size = Vector2(190, 56)
		button.add_theme_font_size_override("font_size", 22)
		var tint: Color = LevelInfo.ZONES[i]["color"]
		button.add_theme_color_override("font_color", tint.lightened(0.25))
		button.add_theme_color_override("font_hover_color", tint.lightened(0.5))
		button.add_theme_color_override("font_focus_color", tint.lightened(0.5))
		button.pressed.connect(start_game.bind(i))
		grid.add_child(button)
		buttons.append(button)

	var hint := Label.new()
	hint.text = "Flechas o ratón para elegir · ESPACIO / ENTER para confirmar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.65)
	vbox.add_child(hint)

	# Pequeña espera para que el ESPACIO que abrió esta pantalla no elija una zona.
	var first := clampi(Settings.start_zone, 0, buttons.size() - 1)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: buttons[first].grab_focus())


func start_game(zone := 0) -> void:
	if _started:
		return
	_started = true
	Settings.start_zone = zone
	get_tree().change_scene_to_file(NEXT_SCENE)
