class_name Player
extends CharacterBody3D
# Gorilla-style movement adapted to touch:
#  - L / R hand buttons: reach and push off the floor (alternate hands for a speed combo)
#  - hold a hand next to a wall to climb it
#  - stick = walk, right side drag = look, J = jump

const GRAVITY := 20.0
const MAX_SPEED := 16.0
const WALK_SPEED := 5.5

var is_it := false
var move_input := Vector2.ZERO
var hands := [false, false]
var last_hand := -1
var last_push := -10.0
var combo := 0
var yaw := 0.0
var pitch := 0.0
var was_grabbing := false
var wall_normal := Vector3.ZERO
var head: Node3D
var cam: Camera3D
var flying := false
var vr_active := false
var xr_origin: XROrigin3D
var xr_cam: XRCamera3D
var xr_hands: Array = []
var hand_prev := [Vector3.ZERO, Vector3.ZERO]
var hand_has_prev := [false, false]
var jump_was := false
var outfit_fur := Baboon.FUR_NORMAL
var speed_mult := 1.0
var arm_pivots: Array[Node3D] = []
var hand_anim := [0.0, 0.0]
var fur_mat := StandardMaterial3D.new()

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 80
	head.add_child(cam)
	cam.current = true
	_make_arms()

func set_it(v: bool) -> void:
	is_it = v
	fur_mat.albedo_color = Baboon.FUR_IT if v else outfit_fur

func _make_arms() -> void:
	fur_mat.albedo_color = outfit_fur
	fur_mat.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.07)
	for side in 2:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.32 if side == 0 else 0.32, -0.32, -0.15)
		cam.add_child(pivot)
		var arm := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.07
		cm.height = 0.7
		arm.mesh = cm
		arm.material_override = fur_mat
		arm.rotation_degrees = Vector3(90, 0, 0)
		arm.position = Vector3(0, 0, -0.35)
		pivot.add_child(arm)
		var fist := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		fist.mesh = sm
		fist.material_override = dark
		fist.position = Vector3(0, 0, -0.72)
		pivot.add_child(fist)
		arm_pivots.append(pivot)

func apply_outfit(fur: Color) -> void:
	outfit_fur = fur
	if not is_it:
		fur_mat.albedo_color = fur

func enable_vr() -> void:
	vr_active = true
	cam.current = false
	for pv in arm_pivots:
		pv.visible = false
	xr_origin = XROrigin3D.new()
	add_child(xr_origin)
	xr_cam = XRCamera3D.new()
	xr_origin.add_child(xr_cam)
	xr_cam.current = true
	for side in ["left_hand", "right_hand"]:
		var c := XRController3D.new()
		c.tracker = side
		xr_origin.add_child(c)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		mi.mesh = sm
		mi.material_override = fur_mat
		c.add_child(mi)
		xr_hands.append(c)

func _hand_touching(pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.15
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# Real Gorilla-Tag style: swing your arms while a hand touches a surface to push yourself.
func _vr_physics(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var basis_o := xr_origin.global_transform.basis
	for i in xr_hands.size():
		var h: XRController3D = xr_hands[i]
		var rel: Vector3 = basis_o * h.position
		if hand_has_prev[i]:
			var hv: Vector3 = (hand_prev[i] - rel) / delta
			if hv.length() > 0.3 and _hand_touching(h.global_position):
				velocity = velocity.lerp(hv * 1.3 * speed_mult, 0.7)
		hand_prev[i] = rel
		hand_has_prev[i] = true
	var jump_now := false
	for h: XRController3D in xr_hands:
		if h.is_button_pressed("ax_button") or h.is_button_pressed("by_button"):
			jump_now = true
	if jump_now and not jump_was and is_on_floor():
		velocity.y = 8.0
	jump_was = jump_now
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	if velocity.length() > (MAX_SPEED * speed_mult) * 1.2:
		velocity = velocity.normalized() * (MAX_SPEED * speed_mult) * 1.2
	move_and_slide()

func look_delta(d: Vector2) -> void:
	yaw -= d.x * 0.004
	pitch = clampf(pitch - d.y * 0.004, -1.4, 1.4)
	rotation.y = yaw
	head.rotation.x = pitch

func jump() -> void:
	if is_on_floor():
		velocity.y = 8.0

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func hand_down(side: int) -> void:
	hands[side] = true
	var fwd := -head.global_transform.basis.z
	var o := head.global_position
	var wall := _ray(o, o + fwd * 1.2)
	if not wall.is_empty() and wall["normal"].y < 0.5:
		return # grabbing a wall -> climbing handled in physics
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var ground := _ray(o, o + (flat + Vector3.DOWN).normalized() * 2.6)
	if ground.is_empty():
		ground = _ray(o, o + Vector3.DOWN * 2.6)
	if ground.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if side != last_hand and now - last_push < 0.8:
		combo = mini(combo + 1, 6)
	else:
		combo = 0
	last_hand = side
	last_push = now
	var dir := flat + Vector3.UP * 0.3
	velocity += dir.normalized() * (5.0 + combo * 1.5) * speed_mult
	var h := Vector2(velocity.x, velocity.z)
	if h.length() > (MAX_SPEED * speed_mult):
		h = h.normalized() * (MAX_SPEED * speed_mult)
		velocity.x = h.x
		velocity.z = h.y

func hand_up(side: int) -> void:
	hands[side] = false

func _wall_grab() -> bool:
	if not (hands[0] or hands[1]):
		return false
	var o := global_position + Vector3(0, 1.2, 0)
	var fwd := -global_transform.basis.z
	var hit := _ray(o, o + fwd * 1.0)
	if hit.is_empty() or hit["normal"].y > 0.5:
		return false
	wall_normal = hit["normal"]
	return true

func _physics_process(delta: float) -> void:
	if vr_active:
		_vr_physics(delta)
		return
	for i in 2:
		hand_anim[i] = move_toward(hand_anim[i], 1.0 if hands[i] else 0.0, 8.0 * delta)
		arm_pivots[i].rotation.x = lerpf(0.15, -1.0, hand_anim[i])
	if flying:
		var w := head.global_transform.basis * Vector3(move_input.x, 0, move_input.y)
		velocity = velocity.move_toward(w * 14.0 * speed_mult, 50.0 * delta)
		was_grabbing = false
		move_and_slide()
		return
	var wish := global_transform.basis * Vector3(move_input.x, 0, move_input.y)
	var grabbing := _wall_grab()
	if grabbing:
		velocity.y = move_toward(velocity.y, 3.5, 40.0 * delta)
		velocity.x = move_toward(velocity.x, -wall_normal.x * 0.5, 20.0 * delta)
		velocity.z = move_toward(velocity.z, -wall_normal.z * 0.5, 20.0 * delta)
	else:
		velocity.y -= GRAVITY * delta
		if was_grabbing and (hands[0] or hands[1]):
			# mantle over the ledge
			var f := -global_transform.basis.z
			velocity = Vector3(f.x * 3.5, 5.0, f.z * 3.5)
		var h := Vector3(velocity.x, 0, velocity.z)
		if is_on_floor():
			if wish.length() > 0.05:
				h = h.move_toward(wish * (WALK_SPEED * speed_mult), 30.0 * delta)
			else:
				h = h.move_toward(Vector3.ZERO, 8.0 * delta)
		else:
			h += wish * 6.0 * delta
			if h.length() > (MAX_SPEED * speed_mult):
				h = h.normalized() * (MAX_SPEED * speed_mult)
		velocity.x = h.x
		velocity.z = h.z
	was_grabbing = grabbing
	if velocity.length() > (MAX_SPEED * speed_mult) * 1.2:
		velocity = velocity.normalized() * (MAX_SPEED * speed_mult) * 1.2
	move_and_slide()
