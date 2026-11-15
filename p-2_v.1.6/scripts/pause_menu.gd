extends CanvasLayer

## Menú de pausa (ESC). Pausa el juego y deja ajustar el volumen general, el de la
## música y el del "Narrador" (función futura; ya controla su bus de audio).
## Se construye por código; sigue funcionando con el árbol en pausa.

const Settings := preload("res://scripts/game_settings.gd")

signal restart_requested

var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_build()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("back_to_menu"):
		if visible:
			close()
		else:
			open()


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	Settings.save()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	box.add_child(title)

	_add_slider(box, "Volumen general", Settings.master, func(v: float) -> void:
		Settings.master = v
		Settings.apply())
	_add_slider(box, "Música", Settings.music, func(v: float) -> void:
		Settings.music = v
		Settings.apply())
	_add_slider(box, "Narrador (próximamente)", Settings.narrator, func(v: float) -> void:
		Settings.narrator = v
		Settings.apply())

	box.add_child(HSeparator.new())

	_resume_button = _add_button(box, "Continuar", close)
	_add_button(box, "Reiniciar desde el inicio", func() -> void:
		close()
		restart_requested.emit())
	_add_button(box, "Volver al menú", func() -> void:
		Settings.save()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn"))

	var hint := Label.new()
	hint.text = "↑ ↓ moverse    ← → ajustar volumen    ESC: continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.65)
	box.add_child(hint)


func _add_slider(parent: Control, title: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(250, 0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = value * 100.0
	slider.custom_minimum_size = Vector2(300, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = "%d%%" % int(slider.value)
	value_label.custom_minimum_size = Vector2(58, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 20)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v)
		on_change.call(v / 100.0))


func _add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button
