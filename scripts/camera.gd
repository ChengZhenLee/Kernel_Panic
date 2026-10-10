extends Camera2D
## Smooth-follow camera with trauma-based screen shake.

var trauma := 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 9.0


func add_trauma(amount: float) -> void:
	if Global.screen_shake:
		trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)
	var s := trauma * trauma
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 26.0 * s


## Boss-kill push-in: eases the zoom in and back out over `secs` of REAL time (slow motion does not stretch it).
func push_in(amount: float, secs: float) -> void:
	var t := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "zoom", Vector2.ONE * (1.0 + amount), secs * 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "zoom", Vector2.ONE, secs * 0.65).set_ease(Tween.EASE_IN_OUT)
