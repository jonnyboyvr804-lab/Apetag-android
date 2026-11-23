extends Node3D
# Builds the arena, spawns player + bots, runs the tag rules.

const ARENA := 60.0
const BOT_COUNT := 7

var player: Player
var actors: Array[Node3D] = []
var it_actor: Node3D
var tag_cooldown := 0.0
var score := 0.0
var label: Label
var overlay: ColorRect
var rng := RandomNumberGenerator.new()
var owner_btn: Button
var panel: PanelContainer
var panel_box: VBoxContainer
var toast: Label
var toast_t := 0.0

const CAVE_SPAWN := Vector3(0, 0.3, 44)
const WARDROBE_POS := Vector3(0, 0.3, 49)
const FURS := [
	["Brown", Color(0.33, 0.28, 0.22), Color(0.5, 0.47, 0.4)],
	["Black", Color(0.1, 0.1, 0.11), Color(0.22, 0.22, 0.24)],
	["Golden", Color(0.7, 0.5, 0.15), Color(0.85, 0.7, 0.3)],
	["Albino", Color(0.85, 0.85, 0.82), Color(0.95, 0.95, 0.92)],
	["Blue", Color(0.2, 0.3, 0.6), Color(0.35, 0.5, 0.8)],
]
const EYES := [
	["Amber", Color(1, 0.65, 0.1)],
	["Green", Color(0.2, 1, 0.3)],
	["Cyan", Color(0.2, 0.8, 1)],
	["Purple", Color(0.7, 0.3, 1)],
]
const HAT_NAMES := ["None", "Crown", "Top Hat", "Horns"]
var fur_idx := 0
var eye_idx := 0
var hat_idx := 0
var mannequin: Baboon
var touch_ui: TouchUI
var wardrobe_btn: Button
var wardrobe_dialog: PanelContainer
var players_open := false

func _ready() -> void:
	rng.seed = 7
	_build_world()
	_build_arena()
	_build_cave()
	player = Player.new()
	add_child(player)
	player.position = CAVE_SPAWN
	actors.append(player)
	for i in BOT_COUNT:
		var b := Bot.new()
		b.main = self
		b.label_name = "Bot %d" % (i + 1)
		b.cheater = (i == 2 or i == 4)
		add_child(b)
		var ang := TAU * i / BOT_COUNT
		b.position = Vector3(cos(ang) * 25.0, 10, sin(ang) * 25.0)
		actors.append(b)
	_build_ui()
	_set_it(actors[1])
	_setup_xr()

func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	body.add_child(mi)
	add_child(body)

func _cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	body.add_child(mi)
	add_child(body)

func _tree(pos: Vector2, height: float) -> void:
	var r := rng.randf_range(0.6, 1.0)
	_cylinder(Vector3(pos.x, height / 2.0, pos.y), r, height, Color(0.4, 0.27, 0.15))
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 3.0
	sph.height = 5.0
	canopy.mesh = sph
	canopy.position = Vector3(pos.x, height + 1.5, pos.y)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.5, 0.2)
	canopy.material_override = m
	add_child(canopy)

func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(ARENA * 2, 1, ARENA * 2), Color(0.25, 0.55, 0.25))
	# The stump: spawn hub in the middle of the forest
	_cylinder(Vector3(0, 0.5, 0), 3.0, 1.0, Color(0.55, 0.38, 0.2))
	# Tall walls so nobody can climb out
	for s in [-1.0, 1.0]:
		_box(Vector3(s * ARENA, 20, 0), Vector3(1, 40, ARENA * 2), Color(0.5, 0.5, 0.55))
		_box(Vector3(0, 20, s * ARENA), Vector3(ARENA * 2, 40, 1), Color(0.5, 0.5, 0.55))
	# Trees and rock pillars
	for i in 90:
		var sz := Vector3(rng.randf_range(2, 6), rng.randf_range(1.5, 9), rng.randf_range(2, 6))
		var p := Vector2(rng.randf_range(-ARENA + 4, ARENA - 4), rng.randf_range(-ARENA + 4, ARENA - 4))
		if p.length() < 7.0:
			continue
		if absf(p.x) < 16.0 and p.y > 28.0:
			continue
		if i % 2 == 0:
			_tree(p, sz.y + 3.0)
		else:
			_box(Vector3(p.x, sz.y / 2.0, p.y), sz, Color.from_hsv(rng.randf(), 0.4, 0.8))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(1, 0, 0, 0)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.position = Vector2(24, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 34)
	layer.add_child(label)
	var title := Label.new()
	title.text = "SCARY BABOON  -  by ENVER"
	title.add_theme_font_size_override("font_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -250
	title.offset_right = 250
	title.offset_top = 10
	layer.add_child(title)
	toast = Label.new()
	toast.position = Vector2(24, 70)
	toast.add_theme_font_size_override("font_size", 30)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast)
	touch_ui = TouchUI.new()
	touch_ui.player = player
	touch_ui.block_check = Callable(self, "_ui_blocked")
	layer.add_child(touch_ui)
	_build_owner_panel(layer)
	_build_id_ui(layer)
	_build_wardrobe_ui(layer)

func _set_it(a: Node3D) -> void:
	if it_actor:
		it_actor.call("set_it", false)
	it_actor = a
	a.call("set_it", true)
	tag_cooldown = 2.0

func _physics_process(delta: float) -> void:
	tag_cooldown -= delta
	if tag_all_on:
		for a in actors:
			if a != player:
				a.call("freeze", 0.5)
	if auto_ban_on:
		auto_ban_t -= delta
		if auto_ban_t <= 0.0:
			auto_ban_t = 1.0
			_ban_cheaters(false)
	if it_actor != player:
		score += delta
	if tag_cooldown <= 0.0:
		for a in actors:
			if a == it_actor:
				continue
			if a.global_position.distance_to(it_actor.global_position) < 1.6:
				_set_it(a)
				break
	for a in actors:
		var p := a.global_position
		if p.y < -10.0 or p.y > 45.0:
			a.global_position = CAVE_SPAWN if a == player else Vector3(0, 3, 0)
			a.set("velocity", Vector3.ZERO)
		else:
			var q := Vector3(clampf(p.x, -ARENA + 1.5, ARENA - 1.5), p.y, clampf(p.z, -ARENA + 1.5, ARENA - 1.5))
			if q != p:
				a.global_position = q

func _process(_delta: float) -> void:
	if it_actor == player:
		label.text = "YOU'RE IT! Tag someone!"
		overlay.color.a = 0.18
	else:
		label.text = "RUN!  Survived: %d s" % int(score)
		overlay.color.a = 0.0
	toast_t -= _delta
	toast.modulate.a = clampf(toast_t, 0.0, 1.0)
	var wd := player.global_position.distance_to(WARDROBE_POS)
	wardrobe_btn.visible = wd < 6.0 and not wardrobe_dialog.visible
	if wd > 8.0:
		wardrobe_dialog.visible = false

# ---------------- ID login + owner panel ----------------
# Build switch (the ID-test zip turns the panels off):
const OWNER_PANEL_ENABLED := true
const ID_SALT := "ape-tag-v1|"
# Only salted SHA-256 hashes are stored here, never the IDs themselves.
const ID_HASHES := {
	"a141e82287bd406a76d722c3385694eaa445c1655fea3d875e51d5d8e130795b": "Owner",
	"e536277b2707b6005c5eb08780277ab9a0527597e081fa29615e5a9ab874beaa": "Admin",
	"4ae1b4d27b7363f75febddc6f68f9307aed658a10787c62c720569237f22fea6": "Moderator",
}

var id_btn: Button
var id_dialog: PanelContainer
var id_edit: LineEdit
var id_status: Label
var role_label: Label
var role := ""
var current_id := ""
var fails := 0
var lock_until := 0
var speed_on := false
var speed_level := 2
var tag_all_on := false
var auto_ban_on := false
var auto_ban_t := 0.0

func _perm_text() -> String:
	match role:
		"Owner":
			return "everything: fly, speed, tag all, ban, respawn, reset score"
		"Admin":
			return "fly, speed boost, tag all"
		"Moderator":
			return "ban players / cheaters"
	return "none"

func _build_id_ui(layer: CanvasLayer) -> void:
	id_btn = Button.new()
	id_btn.text = "ID"
	id_btn.add_theme_font_size_override("font_size", 26)
	layer.add_child(id_btn)
	id_btn.anchor_left = 1.0
	id_btn.anchor_right = 1.0
	id_btn.offset_left = -290
	id_btn.offset_right = -16
	id_btn.offset_top = 16
	id_btn.offset_bottom = 76
	id_btn.pressed.connect(func() -> void: id_dialog.visible = not id_dialog.visible)

	role_label = Label.new()
	role_label.text = "Role: Guest"
	role_label.add_theme_font_size_override("font_size", 20)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.anchor_left = 0.5
	role_label.anchor_right = 0.5
	role_label.offset_left = -250
	role_label.offset_right = 250
	role_label.offset_top = 40
	layer.add_child(role_label)

	id_dialog = PanelContainer.new()
	id_dialog.visible = false
	layer.add_child(id_dialog)
	id_dialog.anchor_left = 0.5
	id_dialog.anchor_right = 0.5
	id_dialog.offset_left = -260
	id_dialog.offset_right = 260
	id_dialog.offset_top = 90
	var box := VBoxContainer.new()
	id_dialog.add_child(box)
	var title := Label.new()
	title.text = "Enter ID"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "Enter your ID"
	id_edit.secret = true
	id_edit.add_theme_font_size_override("font_size", 28)
	id_edit.custom_minimum_size = Vector2(0, 56)
	id_edit.text_submitted.connect(_login)
	box.add_child(id_edit)
	var show_id := CheckBox.new()
	show_id.text = "Show ID"
	show_id.add_theme_font_size_override("font_size", 22)
	show_id.toggled.connect(func(on: bool) -> void: id_edit.secret = not on)
	box.add_child(show_id)
	var row := HBoxContainer.new()
	box.add_child(row)
	for entry in [["Login", 0], ["Logout", 1], ["Close", 2]]:
		var b := Button.new()
		b.text = entry[0]
		b.add_theme_font_size_override("font_size", 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: int = entry[1]
		b.pressed.connect(func() -> void:
			if kind == 0:
				_login(id_edit.text)
			elif kind == 1:
				_logout()
			else:
				id_dialog.visible = false)
		row.add_child(b)
	id_status = Label.new()
	id_status.add_theme_font_size_override("font_size", 22)
	id_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(id_status)

func _normalize(raw: String) -> String:
	var out := ""
	for ch in raw.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

func _login(raw: String) -> void:
	var now := Time.get_ticks_msec()
	if now < lock_until:
		id_status.text = "Too many tries. Wait %d s" % ceili((lock_until - now) / 1000.0)
		return
	var key := _normalize(raw)
	var h := (ID_SALT + key).sha256_text()
	if ID_HASHES.has(h):
		fails = 0
		role = ID_HASHES[h]
		id_edit.text = ""
		id_status.text = "ID accepted: %s\nAccess: %s" % [role, _perm_text()]
		_toast("ID accepted: %s" % role)
		_apply_role()
		id_dialog.visible = false
		id_edit.release_focus()
		if owner_btn:
			panel.visible = true
			_refresh_panel()
	else:
		fails += 1
		if fails >= 5:
			fails = 0
			lock_until = now + 30000
			id_status.text = "Too many tries. Locked for 30 s"
		else:
			id_status.text = "Invalid ID"
		_toast("Invalid ID")

func _logout() -> void:
	role = ""
	current_id = ""
	id_status.text = "Logged out"
	_apply_role()

func _apply_role() -> void:
	if role == "":
		role_label.text = "Role: Guest"
		_reset_toggles()
	else:
		role_label.text = "Role: %s" % role
	if owner_btn:
		owner_btn.visible = role != ""
		owner_btn.text = "%s PANEL" % role.to_upper()
		if role == "":
			panel.visible = false
		elif panel.visible:
			_refresh_panel()

func _build_owner_panel(layer: CanvasLayer) -> void:
	owner_btn = Button.new()
	owner_btn.text = "OWNER"
	owner_btn.visible = false
	owner_btn.add_theme_font_size_override("font_size", 24)
	layer.add_child(owner_btn)
	owner_btn.anchor_left = 1.0
	owner_btn.anchor_right = 1.0
	owner_btn.offset_left = -290
	owner_btn.offset_right = -16
	owner_btn.offset_top = 86
	owner_btn.offset_bottom = 146
	owner_btn.pressed.connect(func() -> void:
		panel.visible = not panel.visible
		_refresh_panel())
	panel = PanelContainer.new()
	panel.visible = false
	layer.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.offset_left = 16
	panel.offset_right = 436
	panel.offset_top = 156
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(400, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(panel_box)

func _ui_blocked(pos: Vector2) -> bool:
	for c in [id_btn, id_dialog, owner_btn, panel, wardrobe_btn, wardrobe_dialog]:
		if c != null and c.visible and c.get_global_rect().has_point(pos):
			return true
	return false

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	panel_box.add_child(b)

func _refresh_panel() -> void:
	for c in panel_box.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "%s PANEL" % role.to_upper()
	head.add_theme_font_size_override("font_size", 32)
	panel_box.add_child(head)
	if not OWNER_PANEL_ENABLED:
		var info := Label.new()
		info.text = "TEST BUILD - preview only\nThis role would get:\n" + _perm_text()
		info.add_theme_font_size_override("font_size", 24)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(380, 0)
		panel_box.add_child(info)
		return
	match role:
		"Owner":
			_admin_controls()
			_mod_controls()
			_owner_controls()
		"Admin":
			_admin_controls()
		"Moderator":
			_mod_controls()

func _add_toggle(text: String, on: bool, cb: Callable) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.add_theme_font_size_override("font_size", 28)
	var refresh := func() -> void:
		b.text = "%s: %s" % [text, "ON" if b.button_pressed else "OFF"]
		b.modulate = Color(0.5, 1.0, 0.5) if b.button_pressed else Color.WHITE
	refresh.call()
	b.toggled.connect(func(v: bool) -> void:
		refresh.call()
		cb.call(v))
	panel_box.add_child(b)

func _apply_speed() -> void:
	player.speed_mult = float(speed_level) if speed_on else 1.0

func _set_speed(v: bool) -> void:
	speed_on = v
	_apply_speed()
	_toast("Speed boost x%d %s" % [speed_level, "ON" if v else "OFF"])

func _set_tag_all(v: bool) -> void:
	tag_all_on = v
	if not v:
		for a in actors:
			if a != player:
				a.call("freeze", 0.01)
	_toast("Tag All %s" % ("ON" if v else "OFF"))

func _set_auto_ban(v: bool) -> void:
	auto_ban_on = v
	auto_ban_t = 0.0
	_toast("Auto-ban %s" % ("ON" if v else "OFF"))

func _reset_toggles() -> void:
	player.flying = false
	speed_on = false
	_apply_speed()
	if tag_all_on:
		_set_tag_all(false)
	auto_ban_on = false

func _admin_controls() -> void:
	_add_toggle("Fly", player.flying, func(v: bool) -> void: player.flying = v)
	_add_toggle("Speed Boost", speed_on, _set_speed)
	var lrow := HBoxContainer.new()
	var ll := Label.new()
	ll.text = "Boost level"
	ll.add_theme_font_size_override("font_size", 26)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(ll)
	for lvl in [2, 3]:
		var lb := Button.new()
		lb.text = "x%d" % lvl
		lb.add_theme_font_size_override("font_size", 28)
		lb.pressed.connect(func() -> void:
			speed_level = lvl
			_apply_speed()
			_toast("Boost level x%d" % lvl))
		lrow.add_child(lb)
	panel_box.add_child(lrow)
	_add_toggle("Tag All", tag_all_on, _set_tag_all)

func _mod_controls() -> void:
	_add_toggle("Auto-Ban Cheaters", auto_ban_on, _set_auto_ban)
	_add_button("Ban All Cheaters", _ban_cheaters)
	_add_button("Players %s" % ("(hide)" if players_open else "(show)"), func() -> void:
		players_open = not players_open
		_refresh_panel())
	if not players_open:
		return
	for a in actors:
		if a == player:
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		var nm: String = a.get("label_name")
		var cheat: bool = a.get("cheater")
		l.text = nm + ("  [CHEATER]" if cheat else "")
		l.add_theme_font_size_override("font_size", 24)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var ban := Button.new()
		ban.text = "Ban"
		ban.add_theme_font_size_override("font_size", 24)
		ban.pressed.connect(_ban.bind(a))
		row.add_child(ban)
		panel_box.add_child(row)

func _owner_controls() -> void:
	_add_button("Respawn All", _respawn_all)
	_add_button("Reset Score", func() -> void:
		score = 0.0
		_toast("Score reset"))

func _respawn_all() -> void:
	var i := 0
	for a in actors:
		if a == player:
			a.global_position = CAVE_SPAWN
		else:
			var ang := TAU * i / maxi(actors.size() - 1, 1)
			a.global_position = Vector3(cos(ang) * 25.0, 3, sin(ang) * 25.0)
			i += 1
		a.set("velocity", Vector3.ZERO)
	_toast("Everyone respawned")

func _toast(text: String) -> void:
	toast.text = text
	toast_t = 3.0

func _tag_all() -> void:
	for a in actors:
		if a != player:
			a.call("freeze", 8.0)
	_toast("Tagged everyone!")

func _ban(a: Node3D) -> void:
	if a == player or not is_instance_valid(a):
		return
	var was_it := a == it_actor
	var nm: String = a.get("label_name")
	actors.erase(a)
	a.queue_free()
	if was_it:
		it_actor = null
		_set_it(actors[rng.randi() % actors.size()])
	_toast("Banned %s" % nm)
	_refresh_panel()

func _ban_cheaters(announce := true) -> void:
	var count := 0
	for a in actors.duplicate():
		if a != player and a.get("cheater"):
			_ban(a)
			count += 1
	if announce or count > 0:
		_toast("Banned %d cheater(s)" % count)

# ---------------- Cave spawn + wardrobe ----------------
func _deco_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)

func _build_cave() -> void:
	var rock := Color(0.34, 0.31, 0.29)
	_box(Vector3(-6.5, 3, 44), Vector3(1, 6, 15), rock)
	_box(Vector3(6.5, 3, 44), Vector3(1, 6, 15), rock)
	_box(Vector3(0, 3, 51.5), Vector3(14, 6, 1), rock)
	_box(Vector3(0, 6.5, 44), Vector3(14, 1, 15), rock)
	_box(Vector3(-4.5, 3, 36.5), Vector3(4, 6, 1), rock)
	_box(Vector3(4.5, 3, 36.5), Vector3(4, 6, 1), rock)
	# stalactites
	for i in 6:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.35
		cone.height = rng.randf_range(0.8, 1.6)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.rotation_degrees = Vector3(180, 0, 0)
		mi.position = Vector3(rng.randf_range(-5, 5), 6.0 - cone.height / 2.0, rng.randf_range(38, 50))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = rock
		mi.material_override = mat
		add_child(mi)
	# warm light inside
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.5, 44)
	light.omni_range = 18.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.75, 0.45)
	add_child(light)
	# wardrobe against the back wall
	_box(Vector3(0, 1.6, 50.4), Vector3(2.6, 3.2, 1.2), Color(0.4, 0.25, 0.12))
	_deco_box(Vector3(-0.65, 1.6, 49.77), Vector3(1.2, 2.9, 0.06), Color(0.55, 0.35, 0.18))
	_deco_box(Vector3(0.65, 1.6, 49.77), Vector3(1.2, 2.9, 0.06), Color(0.55, 0.35, 0.18))
	_deco_box(Vector3(0, 1.6, 49.75), Vector3(0.05, 3.0, 0.07), Color(0.1, 0.06, 0.03))
	_deco_box(Vector3(-0.15, 1.6, 49.72), Vector3(0.07, 0.45, 0.06), Color(1.0, 0.8, 0.2))
	_deco_box(Vector3(0.15, 1.6, 49.72), Vector3(0.07, 0.45, 0.06), Color(1.0, 0.8, 0.2))
	_deco_box(Vector3(0, 3.28, 49.75), Vector3(2.9, 0.15, 1.4), Color(0.3, 0.18, 0.08))
	# mannequin on a podium: shows your current outfit
	_cylinder(Vector3(-3.5, 0.1, 47), 1.0, 0.2, Color(0.4, 0.38, 0.36))
	mannequin = Baboon.new()
	add_child(mannequin)
	mannequin.position = Vector3(-3.5, 0.2, 47)
	mannequin.rotation.y = -0.8

func _set_fur(i: int) -> void:
	fur_idx = i
	_apply_outfit()

func _set_eye(i: int) -> void:
	eye_idx = i
	_apply_outfit()

func _set_hat_idx(i: int) -> void:
	hat_idx = i
	_apply_outfit()

func _apply_outfit() -> void:
	var f: Array = FURS[fur_idx]
	var e: Array = EYES[eye_idx]
	var fur_c: Color = f[1]
	var mane_c: Color = f[2]
	var eye_c: Color = e[1]
	player.apply_outfit(fur_c)
	mannequin.set_outfit(fur_c, mane_c, eye_c, hat_idx)

func _wardrobe_row(box: VBoxContainer, title: String, names: Array, current: int, cb: Callable) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 26)
	box.add_child(l)
	var row := HBoxContainer.new()
	box.add_child(row)
	var grp := ButtonGroup.new()
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = (i == current)
		b.add_theme_font_size_override("font_size", 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(cb.bind(i))
		row.add_child(b)

func _build_wardrobe_ui(layer: CanvasLayer) -> void:
	wardrobe_btn = Button.new()
	wardrobe_btn.text = "WARDROBE"
	wardrobe_btn.visible = false
	wardrobe_btn.add_theme_font_size_override("font_size", 30)
	layer.add_child(wardrobe_btn)
	wardrobe_btn.anchor_left = 0.5
	wardrobe_btn.anchor_right = 0.5
	wardrobe_btn.anchor_top = 1.0
	wardrobe_btn.anchor_bottom = 1.0
	wardrobe_btn.offset_left = -130
	wardrobe_btn.offset_right = 130
	wardrobe_btn.offset_top = -210
	wardrobe_btn.offset_bottom = -140
	wardrobe_btn.pressed.connect(func() -> void: wardrobe_dialog.visible = true)

	wardrobe_dialog = PanelContainer.new()
	wardrobe_dialog.visible = false
	layer.add_child(wardrobe_dialog)
	wardrobe_dialog.anchor_left = 0.5
	wardrobe_dialog.anchor_right = 0.5
	wardrobe_dialog.anchor_top = 0.5
	wardrobe_dialog.anchor_bottom = 0.5
	wardrobe_dialog.offset_left = -300
	wardrobe_dialog.offset_right = 300
	wardrobe_dialog.offset_top = -210
	var box := VBoxContainer.new()
	wardrobe_dialog.add_child(box)
	var title := Label.new()
	title.text = "WARDROBE"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	var fur_names: Array = []
	for f in FURS:
		fur_names.append(f[0])
	var eye_names: Array = []
	for e in EYES:
		eye_names.append(e[0])
	_wardrobe_row(box, "Fur", fur_names, fur_idx, _set_fur)
	_wardrobe_row(box, "Eyes", eye_names, eye_idx, _set_eye)
	_wardrobe_row(box, "Hat", HAT_NAMES, hat_idx, _set_hat_idx)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 28)
	close.pressed.connect(func() -> void: wardrobe_dialog.visible = false)
	box.add_child(close)

# ---------------- VR (Meta Quest / OpenXR) ----------------
func _setup_xr() -> void:
	var xr := XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized():
		return # no headset runtime -> normal touch game
	get_viewport().use_xr = true
	player.enable_vr()
	touch_ui.visible = false
