extends Node
## IDLE LOOP: standing still ramps up cooldown reduction (up to 40%). Moving drains it quickly.

var player
var last := Vector2.ZERO
var idle := 0.0
var applied := 0.0


func _ready() -> void:
	player = get_parent()
	last = player.global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var speed: float = player.global_position.distance_to(last) / delta
	last = player.global_position
	if speed < 25.0:
		idle = minf(idle + delta, 4.0)
	else:
		idle = maxf(0.0, idle - delta * 6.0)
	var bonus := minf(40.0, idle * 12.0)
	if absf(bonus - applied) > 0.25:
		player.add_bonus("haste", bonus - applied)
		applied = bonus
