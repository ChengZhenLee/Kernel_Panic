extends Node2D
const FD = preload("res://scripts/fx/fd.gd")
## Hostile projectile fired by spyware and bosses.

var velocity := Vector2.ZERO
var damage := 10.0
var color := Color(1.0, 0.3, 0.4)
var life := 6.0
var radius := 7.0
var heavy := false   # fired by a boss (BLAST DOORS reduces it)
var player


func _ready() -> void:
	add_to_group("enemy_bullets")
	queue_redraw()   # the shape never changes: drawn once, the node transform moves it
	player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if Global.game and Global.game.time_stop > 0.0:
		return   # PAUSE ability
	position += velocity * delta
	life -= delta
	if life <= 0.0 or player == null:
		queue_free()
		return
	if Global.game and Global.game.arena != null and Global.game.arena.point_blocked(global_position):
		queue_free()   # shots stop at walls
		return
	if player.alive and global_position.distance_to(player.global_position) < radius + player.radius:
		player.take_damage(damage, null, heavy)
		queue_free()


func _draw() -> void:
	FD.circle(self, Vector2.ZERO, radius * 2.2, Color(color, 0.15))
	FD.circle(self, Vector2.ZERO, radius, color)
	FD.circle(self, Vector2.ZERO, radius * 0.45, Color.WHITE)
