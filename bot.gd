class_name Bot
extends CharacterBody3D
# Simple AI: if "it" it chases the nearest actor, otherwise it flees from "it".

var main
var is_it := false
var model: Baboon
var label_name := "Bot"
var cheater := false
var frozen := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = Baboon.new()
	add_child(model)
	if cheater:
		var tag := Label3D.new()
		tag.text = "CHEATER"
		tag.modulate = Color(1, 0.1, 0.1)
		tag.font_size = 72
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position = Vector3(0, 2.5, 0)
		add_child(tag)

func freeze(seconds: float) -> void:
	frozen = seconds
	model.set_it(true)

func set_it(v: bool) -> void:
	is_it = v
	if model:
		model.set_it(v)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := 5.5
	if is_it:
		var best: Node3D = null
		var bd: float = INF
		for a: Node3D in main.actors:
			if a == self:
				continue
			var d: float = global_position.distance_to(a.global_position)
			if d < bd:
				bd = d
				best = a
		if best:
			dir = best.global_position - global_position
		speed = 0.0 if main.tag_cooldown > 0.0 else 5.8
	else:
		var it: Node3D = main.it_actor
		var away := global_position - it.global_position
		if away.length() < 16.0:
			var center := Vector3(-global_position.x, 0, -global_position.z) * 0.04
			dir = away.normalized() + center
	if cheater:
		speed = 9.0
	if frozen > 0.0:
		frozen -= delta
		speed = 0.0
		dir = Vector3.ZERO
		if frozen <= 0.0:
			model.set_it(is_it)
	dir.y = 0
	dir = dir.normalized()
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(dir * speed, 25.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	if cheater:
		velocity.y = move_toward(velocity.y, (4.0 - global_position.y) * 2.0, 20.0 * delta)
	else:
		velocity.y -= 20.0 * delta
	if is_on_floor() and is_on_wall():
		velocity.y = 7.5
	move_and_slide()
	model.animate(Vector2(velocity.x, velocity.z).length(), delta)
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
