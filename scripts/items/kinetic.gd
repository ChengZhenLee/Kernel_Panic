extends Node
## KINETIC CORE: damage scales with how fast you are moving (up to +70% at double speed).

var player
var last := Vector2.ZERO
var smooth := 0.0
var applied := 0.0


func _ready() -> void:
	player = get_parent()
	last = player.global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var speed: float = player.global_position.distance_to(last) / delta
	last = player.global_position
	smooth = lerpf(smooth, speed, minf(1.0, delta * 8.0))
	var bonus := clampf(smooth / 210.0, 0.0, 2.0) * 35.0
	if absf(bonus - applied) > 0.5:
		player.add_bonus("dmg", bonus - applied)
		applied = bonus
