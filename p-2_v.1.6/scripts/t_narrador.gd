
extends Label

@onready var narrador: AudioStreamPlayer = $Narrador

var frases = [
	[0.0, "¿Empezar? Lo hago todos los días, ¿no?"],
	[3.5, "Espera... creo que sé a qué te refieres."],
	[7.0, "Sí, sí lo es."],
	[9.5, "Empezar de nuevo no es un botón que se pulsa una vez."],
	[14.0, "Es levantarse después de haber borrado sin querer el trabajo de toda la noche,"],
	[20.0, "o volver a casa por la billetera que se quedó sobre la mesa."],
	[25.0, "Es ver la ruleta girar y girar, y aun así quedarte mirando cómo cae,"],
	[31.0, "como cuando tiras por todo al rojo, y termina cayendo negro."],
	[36.0, "Es manchar la camisa limpia antes de la fiesta y reírte, porque ya no queda de otra."],
	[43.0, "Es tragarse el orgullo cuando el amigo tenía razón."],
	[47.0, "Empezar es solo el primer paso."],
	[50.0, "Es aceptar que ya hubo un antes."],
	[53.5, "Si hoy ya has tenido suficiente, lo comprendo."],
	[57.0, "Lárgate y ponte aquí cuando cuando te arriesgues, aquí estoy."],
	[62.0, "Me acompañarás en este viaje, si vas a descansar no vengas,"],
	[68.0, "un solo error te costará todo."],
	[72.0, "Créeme, ya lo he vivido de primera mano."]
]

var frase_actual = -1


func _ready():
	text = ""
	narrador.finished.connect(_al_terminar)
	narrador.play()


func _process(_delta):
	if not narrador.playing:
		return

	var tiempo = narrador.get_playback_position()

	for i in range(frases.size()):
		if tiempo >= frases[i][0]:
			if frase_actual != i:
				frase_actual = i
				text = frases[i][1]


func _al_terminar():
	text = ""
	frase_actual = -1
