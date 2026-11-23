class_name TouchUI
extends Control
# Multi-touch controls: floating stick (left), look drag (right), L/R/J buttons.

var player: Player
var block_check := Callable()
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var look_id := -1
var btn_ids := {} # touch index -> "L" / "R" / "J"
const BTN_R := 75.0
const STICK_R := 100.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _center(n: String) -> Vector2:
	match n:
		"L": return Vector2(size.x - 380, size.y - 120)
		"R": return Vector2(size.x - 170, size.y - 120)
	return Vector2(size.x - 275, size.y - 290)

func _press(id: int, pos: Vector2) -> void:
	if block_check.is_valid() and block_check.call(pos):
		return
	for n in ["L", "R", "J"]:
		if pos.distance_to(_center(n)) < BTN_R + 15.0:
			btn_ids[id] = n
			match n:
				"L": player.hand_down(0)
				"R": player.hand_down(1)
				"J": player.jump()
			queue_redraw()
			return
	if pos.x < size.x * 0.4 and stick_id == -1:
		stick_id = id
		stick_origin = pos
		stick_vec = Vector2.ZERO
	elif look_id == -1:
		look_id = id
	queue_redraw()

func _release(id: int) -> void:
	if id == stick_id:
		stick_id = -1
		stick_vec = Vector2.ZERO
		player.move_input = Vector2.ZERO
	elif id == look_id:
		look_id = -1
	elif btn_ids.has(id):
		match btn_ids[id]:
			"L": player.hand_up(0)
			"R": player.hand_up(1)
		btn_ids.erase(id)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_vec = ((event.position - stick_origin) / STICK_R).limit_length(1.0)
			player.move_input = stick_vec
		elif event.index == look_id:
			player.look_delta(event.relative)
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for n in ["L", "R", "J"]:
		var down: bool = btn_ids.values().has(n)
		var c := _center(n)
		draw_circle(c, BTN_R, Color(1, 1, 1, 0.35 if down else 0.15))
		draw_arc(c, BTN_R, 0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)
		draw_string(font, c + Vector2(-10, 12), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 36)
	if stick_id != -1:
		draw_circle(stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		draw_circle(stick_origin + stick_vec * STICK_R, 40, Color(1, 1, 1, 0.4))
