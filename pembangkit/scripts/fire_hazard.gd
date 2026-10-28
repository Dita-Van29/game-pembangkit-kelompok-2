class_name FireHazard
extends Node3D
## Api kecil di tanah (bahaya Stage 1). Melukai Mira dan Shade yang menyentuhnya.

@export var radius: float = 1.0
var _tick: float = 0.0
var _flames: Array = []
var _light: OmniLight3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("fire_hazards")
	_t = randf() * 10.0
	if get_node_or_null("Core") != null:
		for c in get_children():
			if c is MeshInstance3D and (String(c.name).begins_with("Flame") or String(c.name) == "Core"):
				_flames.append(c)
		_light = get_node_or_null("Light") as OmniLight3D
		return
	Util.disk(self, radius, Color(0.15, 0.05, 0.02, 0.55), false, 0.025)
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + randf() * 0.6
		var r: float = radius * 0.45 * (0.3 + float(i % 2))
		var h: float = randf_range(0.7, 1.2)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.28
		cm.height = h
		cone.mesh = cm
		cone.material_override = Util.mat(Color(1.0, 0.5, 0.12), true, false, true)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cone)
		cone.position = Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		_flames.append(cone)
	var core := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.0
	cm2.bottom_radius = 0.2
	cm2.height = 0.9
	core.mesh = cm2
	core.material_override = Util.mat(Color(1.0, 0.9, 0.4), true, false, true)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	core.position = Vector3(0, 0.45, 0)
	_flames.append(core)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 1.6
	_light.omni_range = 6.0
	_light.position = Vector3(0, 1.0, 0)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	for i in range(_flames.size()):
		var f: MeshInstance3D = _flames[i]
		var k: float = 1.0 + sin(_t * (9.0 + float(i) * 2.3) + float(i)) * 0.22
		f.scale = Vector3(k, 1.0 + (k - 1.0) * 1.8, k)
	_light.light_energy = 1.5 + sin(_t * 11.0) * 0.35 + sin(_t * 17.0) * 0.2


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _tick > 0.0:
		_tick -= delta
		return
	var hurt: bool = false
	var cands: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("shades")
	for c in cands:
		if not is_instance_valid(c) or c.dead:
			continue
		var d: Vector3 = c.global_position - global_position
		d.y = 0.0
		if d.length() < radius + 0.2:
			c.take_damage(1, global_position, 5.0)
			hurt = true
	if hurt:
		_tick = 0.9
