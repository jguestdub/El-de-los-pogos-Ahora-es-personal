extends RefCounted

## GENERADO por tools/generate_level.py -- no editar a mano.

const WIDTH := 2000.0
const START_POS := Vector2(1000.0, -30.0)
const GROUND_Y := 0.0
const PX_PER_M := 32.0
const SUMMIT_Y := -38313.7
const TOP_Y := -39400.0

## y_bottom / y_top en coordenadas del mundo (y negativa = más alto).
const ZONES := [
	{"name": "PRADERA", "y_bottom": 0.0, "y_top": -4800.0, "spawn": Vector2(1000.0, -30.0), "color": Color(0.30, 0.65, 0.28)},
	{"name": "BOSQUE", "y_bottom": -4800.0, "y_top": -9600.0, "spawn": Vector2(409.3, -4835.9), "color": Color(0.22, 0.52, 0.24)},
	{"name": "CAVERNAS", "y_bottom": -9600.0, "y_top": -14400.0, "spawn": Vector2(1364.2, -9652.0), "color": Color(0.42, 0.42, 0.55)},
	{"name": "HIELO", "y_bottom": -14400.0, "y_top": -19200.0, "spawn": Vector2(829.8, -14465.0), "color": Color(0.90, 0.97, 1.00)},
	{"name": "RUINAS", "y_bottom": -19200.0, "y_top": -24000.0, "spawn": Vector2(1714.3, -19323.0), "color": Color(0.62, 0.55, 0.42)},
	{"name": "VOLCAN", "y_bottom": -24000.0, "y_top": -28800.0, "spawn": Vector2(697.6, -24118.6), "color": Color(0.85, 0.35, 0.12)},
	{"name": "CIELO", "y_bottom": -28800.0, "y_top": -33600.0, "spawn": Vector2(1407.2, -28888.9), "color": Color(0.93, 0.97, 1.00)},
	{"name": "CIMA", "y_bottom": -33600.0, "y_top": -38400.0, "spawn": Vector2(743.2, -33725.1), "color": Color(0.95, 0.85, 0.40)},
]
