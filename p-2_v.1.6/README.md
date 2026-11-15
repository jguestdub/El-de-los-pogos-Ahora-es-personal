# POGO CLIMB

Juego de escalada con pogo (estilo *Pogostuck* / *Getting Over It*). Godot 4.6, GL Compatibility.

## Controles

| Tecla | Acción |
|---|---|
| **A / D** o **← →** | Inclinar el pogo (define la dirección del salto) |
| **ESPACIO** (mantener y soltar) | Cargar y saltar. **El pogo no rebota solo** |
| **B** | Bailar (solo en el suelo y sin cargar un salto) |
| **R** | Volver al último checkpoint (en la zona 1 o tras ganar: reinicia desde abajo) |
| **ESC** | Menú de pausa (volumen general, música, "Narrador", reiniciar, volver al menú) |
| **F1 – F8** | Atajo de prueba: ir al inicio de cada zona |

Chocar con paredes y techos rebota; en el suelo te quedas quieto (en hielo te deslizas).
Hay un checkpoint al inicio de cada zona (una bandera en su plataforma inicial; se activa al aterrizar ahí). Los diablillos patrullan algunas plataformas, sin salirse de ellas; su color y tamaño cambian según la zona.

## El baile

Con **B** el pogo se sustituye por un bailarín 3D (`assets/models/personaje_voxel_gangnam.glb`,
animación en bucle) y vuelve el modelo del pogo en cuanto pulses cualquier otra acción
(**A/D, ESPACIO, R, ESC**), reinicies, vuelvas a un checkpoint o te caigas de la plataforma.
Pulsar B otra vez mientras bailas no hace nada.

Cómo está hecho: `scripts/dancer.gd` + el nodo `Dancer` de `scenes/player.tscn`. El modelo vive
en un `SubViewport` con cámara ortogonal y fondo transparente, que se muestra como un `Sprite2D`
sobre los pies del jugador (solo se renderiza mientras se baila). Para usar otro baile cambia
el modelo `Dancer/Viewport/Model` por otro `.glb` con animación y ajusta `MODEL_HEIGHT` y la
cámara. Pruebas: `tests/dance_test.gd`.

## El nivel

8 zonas, ~1200 m de altura, 237 plataformas en la ruta principal + repisas extra:
Pradera → Bosque → Cavernas → Hielo → Ruinas → Volcán → Cielo → Cima.

El nivel (`scenes/level.tscn`) y `scripts/level_info.gd` están **generados** por
`tools/generate_level.py` simulando la misma física del jugador, así que cada salto
de la ruta principal tiene una ventana real de (carga, ángulo) que funciona.

```bash
python3 tools/generate_level.py [semilla]   # tarda unos minutos; requiere numpy y Pillow
```

Puedes abrir `level.tscn` en el editor y mover/borrar plataformas a mano; solo ten en
cuenta que regenerar lo sobrescribe. Las plataformas de hielo llevan
`metadata/surface = "ice"`.

## Enemigos y checkpoints

- `scripts/enemy_spawner.gd` coloca diablillos (~20 % de las plataformas anchas, nunca dos seguidas ni más de 7 vacías seguidas) con semilla fija. Estilo por zona en `ZONE_STYLE`.
- `scripts/enemy.gd`: patrulla dentro de los límites de la plataforma; empuja al jugador (sin retroceso; si lo lleva hasta el borde lo saca de la plataforma) y muere si le pisas la cabeza; reaparecen ~30 s después por un portal.
- Sprites por zona en `assets/enemies/zoneN_{right,left}.png`, generados con `python3 tools/make_enemy_sprites.py` a partir de `devil_run_*.png`.
- `scripts/checkpoint_flag.gd` + lógica en `main.gd`: banderas y tecla R.

## Zona de inicio

Tras la pantalla de carga (ESPACIO) se elige la zona donde empezar. R reinicia la partida
en esa zona (si ya estás en su checkpoint inicial) y los checkpoints anteriores no cuentan.
Para cambiar de zona: ESC → Volver al menú.

## Pausa y volúmenes

`scripts/pause_menu.gd` + `scripts/game_settings.gd`. Buses de audio creados por código:
`Master` (general), `Music` (soundtrack) y `Narrator` (reservado para la función futura:
cuando añadas el narrador, pon sus `AudioStreamPlayer` en el bus `Narrator`). Los volúmenes se
guardan en `user://settings.cfg`.

## Enemigos: muerte y reaparición

Al pisar a un enemigo suena `assets/sfx/enemy_death.mp3` (igual para todas las zonas) y ~30 s
después (`RESPAWN_MIN/MAX` en `enemy_spawner.gd`) reaparece en el mismo sitio saliendo de un
portal (`assets/effects/portal.png`, generado con `tools/make_portal_sprite.py`).

## Música

Un tema por zona en `assets/music/*.mp3` (en bucle mientras estás en la zona; cambia al entrar en otra, también si vuelves a caer a una anterior). Lista en `MUSIC_PATHS` de `main.gd`.

## Ajustar la sensación del pogo

Todo está en las constantes de `scripts/player.gd` (gravedad, fuerza mínima/máxima,
tiempo de carga, inclinación máxima, rebotes...). Si cambias la física, copia los
mismos valores arriba de `tools/generate_level.py` y regenera el nivel.

## Pruebas automáticas

```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/bot_test.gd        # repite cada salto de la ruta con la física real
godot --headless --path . -s res://tests/gameplay_test.gd   # el pogo no rebota solo, carga, inclinación...
```
