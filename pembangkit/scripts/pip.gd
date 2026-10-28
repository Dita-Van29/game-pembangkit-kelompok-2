class_name Pip
extends Node3D
## Pip, roh lentera pendamping. Mengikuti Mira, dan menunjuk arah ke area berikutnya.

var follow_target = null
var pointing: bool = false
var point_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _sprite: Sprite3D
var _light: OmniLight3D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite3D
	if _sprite == null:
		_sprite = Util.make_sprite("res://assets/sprites/pip.png", 1.0, false)
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.position = Vector3.ZERO
		add_child(_sprite)

		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.92, 0.6)
		_light.light_energy = 1.6
		_light.omni_range = 9.0
		add_child(_light)
	else:
		_light = get_node_or_null("Light") as OmniLight3D


func _process(delta: float) -> void:
	_t += delta
	if follow_target == null or not is_instance_valid(follow_target):
		return
	var base: Vector3 = follow_target.global_position
	var desired: Vector3 = base + Vector3(-1.1, 2.7, 0.3)
	if pointing:
		var dir: Vector3 = point_pos - base
		dir.y = 0.0
		var dist: float = dir.length()
		if dist > 0.5:
			desired = base + dir.normalized() * minf(4.0, dist) + Vector3(0, 2.4, 0)
	desired.y += sin(_t * 3.2) * 0.18
	global_position = global_position.lerp(desired, 1.0 - exp(-5.0 * delta))
	_light.light_energy = 1.5 + sin(_t * 7.0) * 0.2
	var s: float = 1.0 + sin(_t * 6.0) * 0.04
	_sprite.scale = Vector3(s, s, 1.0)
