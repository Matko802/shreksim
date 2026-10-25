class_name SwampDirectionArrow
extends Control

var move_angle := 0.0
var moving := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func set_state(angle: float, is_moving: bool) -> void:
	move_angle = angle
	moving = is_moving
	queue_redraw()

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	var center := size * 0.5
	draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.42))
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
	if not moving:
		draw_circle(center, radius * 0.1, Color(1.0, 1.0, 1.0, 0.75))
		return
	var dir := Vector2.UP.rotated(move_angle)
	var tip := center + dir * radius * 0.62
	var back := center - dir * radius * 0.2
	var side := Vector2(-dir.y, dir.x) * radius * 0.28
	var points := PackedVector2Array([tip, back + side, back - side])
	draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(center, radius * 0.1, Color(1.0, 1.0, 1.0, 0.95))
