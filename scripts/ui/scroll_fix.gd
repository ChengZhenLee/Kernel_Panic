extends Node
## Makes a ScrollContainer touch friendly: dragging anywhere scrolls (buttons and panels let drags pass through, also for
## content added later), and no scrollbar shows.

var scroll: ScrollContainer


static func apply(sc: ScrollContainer) -> void:
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 14
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	var f = load("res://scripts/ui/scroll_fix.gd").new()
	f.scroll = sc
	sc.add_child(f)
	f._pass_all(sc)


func _ready() -> void:
	get_tree().node_added.connect(_on_added)
	_pass_all(scroll)


func _on_added(n: Node) -> void:
	if is_instance_valid(scroll) and scroll.is_ancestor_of(n):
		_pass_one.call_deferred(n)


func _pass_all(root: Node) -> void:
	for c in root.get_children():
		_pass_one(c)
		_pass_all(c)


func _pass_one(c: Node) -> void:
	if is_instance_valid(c) and c is Control and not (c is ScrollContainer) and not (c is Range) and not (c is LineEdit) and c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
