class_name Baboon
extends Node3D
# Scary baboon built from primitives. Faces -Z (Godot forward).

const FUR_NORMAL := Color(0.33, 0.28, 0.22)
const MANE_NORMAL := Color(0.5, 0.47, 0.4)
const FUR_IT := Color(0.45, 0.1, 0.08)
const MANE_IT := Color(0.3, 0.05, 0.05)

var fur := StandardMaterial3D.new()
var mane := StandardMaterial3D.new()
var eyes := StandardMaterial3D.new()
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var t := 0.0
var base_fur := FUR_NORMAL
var base_mane := MANE_NORMAL
var base_eye := Color(1, 0.65, 0.1)
var hat_id := 0
var hat_root: Node3D
var worn_it := false

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	return c

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _limb(pos: Vector3, r: float, length: float, dark: Material) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	body.add_child(p)
	_part(p, _capsule(r, length), fur, Vector3(0, -length * 0.5 + 0.1, 0))
	_part(p, _sphere(r * 1.4), dark, Vector3(0, -length + 0.1, 0))
	return p

func _ready() -> void:
	fur.albedo_color = base_fur
	fur.roughness = 1.0
	mane.albedo_color = base_mane
	mane.roughness = 1.0
	eyes.albedo_color = base_eye
	eyes.emission_enabled = true
	eyes.emission = base_eye
	eyes.emission_energy_multiplier = 3.0
	var dark := _mat(Color(0.08, 0.06, 0.07))
	var nose := _mat(Color(0.35, 0.12, 0.2))
	var tooth := _mat(Color(0.95, 0.93, 0.8))
	var mouth := _mat(Color(0.5, 0.05, 0.05))

	body = Node3D.new()
	add_child(body)
	# hunched torso + shoulder mane
	_part(body, _sphere(0.5), fur, Vector3(0, 1.0, 0.1), Vector3(25, 0, 0), Vector3(0.9, 1.0, 1.1))
	_part(body, _sphere(0.5), mane, Vector3(0, 1.3, -0.15), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
	# head, ears, snout, nose
	_part(body, _sphere(0.28), fur, Vector3(0, 1.45, -0.5))
	_part(body, _sphere(0.07), dark, Vector3(-0.27, 1.5, -0.45))
	_part(body, _sphere(0.07), dark, Vector3(0.27, 1.5, -0.45))
	_part(body, _capsule(0.16, 0.6), dark, Vector3(0, 1.38, -0.82), Vector3(90, 0, 0))
	_part(body, _sphere(0.12), nose, Vector3(0, 1.4, -1.12))
	# heavy brow, glowing eyes
	_part(body, _box(Vector3(0.5, 0.07, 0.15)), dark, Vector3(0, 1.57, -0.72))
	_part(body, _sphere(0.05), eyes, Vector3(-0.12, 1.49, -0.74))
	_part(body, _sphere(0.05), eyes, Vector3(0.12, 1.49, -0.74))
	# open snarl with fangs
	_part(body, _box(Vector3(0.22, 0.03, 0.5)), mouth, Vector3(0, 1.235, -0.85))
	_part(body, _cone(0.03, 0.14), tooth, Vector3(-0.09, 1.27, -1.0), Vector3(180, 0, 0))
	_part(body, _cone(0.03, 0.14), tooth, Vector3(0.09, 1.27, -1.0), Vector3(180, 0, 0))
	# limbs: long knuckle-walking arms, shorter legs, tail
	arm_l = _limb(Vector3(-0.55, 1.25, -0.05), 0.12, 1.2, dark)
	arm_r = _limb(Vector3(0.55, 1.25, -0.05), 0.12, 1.2, dark)
	leg_l = _limb(Vector3(-0.25, 0.75, 0.2), 0.14, 0.8, dark)
	leg_r = _limb(Vector3(0.25, 0.75, 0.2), 0.14, 0.8, dark)
	_part(body, _capsule(0.05, 0.5), fur, Vector3(0, 0.95, 0.7), Vector3(60, 0, 0))
	_set_hat(hat_id)

func set_it(v: bool) -> void:
	worn_it = v
	fur.albedo_color = FUR_IT if v else base_fur
	mane.albedo_color = MANE_IT if v else base_mane
	var col := Color(1, 0.05, 0.0) if v else base_eye
	eyes.albedo_color = col
	eyes.emission = col
	eyes.emission_energy_multiplier = 6.0 if v else 3.0

func set_outfit(fur_c: Color, mane_c: Color, eye_c: Color, hat: int) -> void:
	base_fur = fur_c
	base_mane = mane_c
	base_eye = eye_c
	hat_id = hat
	set_it(worn_it)
	_set_hat(hat)

func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c

func _set_hat(h: int) -> void:
	if hat_root:
		hat_root.queue_free()
	hat_root = Node3D.new()
	hat_root.position = Vector3(0, 1.72, -0.5)
	body.add_child(hat_root)
	match h:
		1: # crown
			var gold := _mat(Color(1.0, 0.8, 0.1))
			_part(hat_root, _cyl(0.22, 0.12), gold, Vector3(0, 0.02, 0))
			for i in 5:
				var ang := TAU * i / 5.0
				_part(hat_root, _cone(0.05, 0.16), gold, Vector3(cos(ang) * 0.2, 0.15, sin(ang) * 0.2))
		2: # top hat
			var black := _mat(Color(0.05, 0.05, 0.06))
			_part(hat_root, _cyl(0.34, 0.03), black, Vector3(0, 0, 0))
			_part(hat_root, _cyl(0.2, 0.36), black, Vector3(0, 0.19, 0))
			_part(hat_root, _cyl(0.205, 0.07), _mat(Color(0.7, 0.05, 0.05)), Vector3(0, 0.06, 0))
		3: # horns
			var bone := _mat(Color(0.92, 0.9, 0.8))
			_part(hat_root, _cone(0.06, 0.4), bone, Vector3(-0.2, 0.1, 0), Vector3(0, 0, 25))
			_part(hat_root, _cone(0.06, 0.4), bone, Vector3(0.2, 0.1, 0), Vector3(0, 0, -25))

func animate(speed: float, delta: float) -> void:
	t += delta * (4.0 + speed * 1.2)
	var k := clampf(speed / 6.0, 0.0, 1.0)
	arm_l.rotation.x = sin(t) * 0.7 * k - 0.15
	arm_r.rotation.x = -sin(t) * 0.7 * k - 0.15
	leg_l.rotation.x = -sin(t) * 0.6 * k
	leg_r.rotation.x = sin(t) * 0.6 * k
	body.position.y = absf(sin(t)) * 0.08 * k
	body.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.015
