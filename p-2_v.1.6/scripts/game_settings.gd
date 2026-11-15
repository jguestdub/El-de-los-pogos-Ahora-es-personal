extends RefCounted

## Ajustes compartidos entre escenas (zona de inicio y volúmenes), con guardado
## en user://settings.cfg. Crea los buses de audio "Music" y "Narrator" por código.
##
##   Master   : volumen general (efectos incluidos)
##   Music    : soundtrack de las zonas
##   Narrator : reservado para la futura función "Narrador"

const SAVE_PATH := "user://settings.cfg"
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_NARRATOR := "Narrator"

## Zona (0..7) donde empieza la partida; la elige la pantalla de título.
static var start_zone := 0
## Volúmenes lineales 0.0 .. 1.0
static var master := 1.0
static var music := 1.0
static var narrator := 1.0

static var _ready_done := false


static func ensure() -> void:
	if _ready_done:
		return
	_ready_done = true
	for bus_name in [BUS_MUSIC, BUS_NARRATOR]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
	_load()
	apply()


static func apply() -> void:
	_set_bus(BUS_MASTER, master)
	_set_bus(BUS_MUSIC, music)
	_set_bus(BUS_NARRATOR, narrator)


static func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var silent := linear <= 0.001
	AudioServer.set_bus_mute(idx, silent)
	AudioServer.set_bus_volume_db(idx, -80.0 if silent else linear_to_db(linear))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "narrator", narrator)
	cfg.save(SAVE_PATH)


static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	narrator = clampf(float(cfg.get_value("audio", "narrator", 1.0)), 0.0, 1.0)
