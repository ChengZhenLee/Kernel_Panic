extends SceneTree
## Headless check: announcements play their full length while hit/kill sounds spam the pool.
func _initialize() -> void:
	await process_frame
	var sfx = root.get_node("Sfx")
	var keys := ["warning_incoming_boss", "incoming_elite", "incoming_swarm", "incoming_new_enemy", "boss_defeated"]
	var t0 := Time.get_ticks_msec()
	var started := {}
	var ok := true
	for k in keys:
		sfx.announce(k)
	print("queue after 5 announces (max 3 waiting): ", sfx.ann_queue)
	var spam := 0
	var seen := ""
	while sfx.ann_current != "" and Time.get_ticks_msec() - t0 < 30000:
		for i in 6:
			sfx.play("hit", 1.0, 0.0, 0.0); sfx.play("kill", 1.0, 0.0, 0.0); spam += 2
		if sfx.ann_current != seen:
			seen = sfx.ann_current
			started[seen] = Time.get_ticks_msec()
			print("start ", seen, " len=", snapped(sfx.streams["an_" + seen].get_length(), 0.01), " duck=", sfx.duck_db)
		await process_frame
	print("spam calls: ", spam, " total ms: ", Time.get_ticks_msec() - t0, " duck after: ", sfx.duck_db)
	quit()
