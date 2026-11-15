extends Node2D

## Bandera de checkpoint: gris hasta que se activa, luego del color de la zona.
## El origen del nodo es la base del mástil.

var active := false:
	set(value):
		active = value
		queue_redraw()

var zone_color := Color.WHITE


func _draw() -> void:
	var pole := Color(0.85, 0.85, 0.9) if active else Color(0.5, 0.5, 0.55)
	var cloth := zone_color if active else Color(0.35, 0.35, 0.4)
	draw_rect(Rect2(-3.0, -90.0, 6.0, 90.0), pole)
	draw_circle(Vector2(0.0, -92.0), 5.0, pole)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, -86.0), Vector2(48.0, -72.0), Vector2(3.0, -58.0),
	]), cloth)
	draw_polyline(PackedVector2Array([
		Vector2(3.0, -86.0), Vector2(48.0, -72.0), Vector2(3.0, -58.0),
	]), Color(0, 0, 0, 0.6), 2.0)
