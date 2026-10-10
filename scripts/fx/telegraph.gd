extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## Telegraphed ground slam: a red circle fills up, then damages the player if still inside.

var radius := 100.0
var delay := 1.0
var damage := 20.0
var color := Color(1.0, 0.25, 0.25)
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if t < delay:
		return
	var game = Global.game
	if game:
		game.ring(global_position, color, radius, 0.35, 10.0)
		game.burst(global_position, color, 20, 320.0, 5.0, 0.4)
		game.shake(0.2)
	Sfx.play("explode", 1.3, -4.0)
	var p = get_tree().get_first_node_in_group("player")
	if p and p.alive and p.global_position.distance_to(global_position) < radius + p.radius:
		p.take_damage(damage)
	queue_free()


func _draw() -> void:
	var k := clampf(t / delay, 0.0, 1.0)
	FD.circle(self, Vector2.ZERO, radius, Color(color, 0.08 + 0.12 * k))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color, 0.8), 3.0)
	FD.circle(self, Vector2.ZERO, radius * k, Color(color, 0.25))
