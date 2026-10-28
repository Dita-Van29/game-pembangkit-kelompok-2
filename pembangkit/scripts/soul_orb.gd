class_name SoulOrb
extends Node3D
## Soul Orb yang ditinggalkan musuh mati. Pemain menekan E di dekatnya untuk Raise.

const LIFETIME := 6.0

@export var data: EnemyData = null
@export var forced: bool = false      # true = Raise pertama (skrip tutorial), pasti berhasil dan tidak hilang
var consumed: bool = false

var _life: float = LIFETIME
var _t: float = 0.0
var _sprite: Sprite3D
var _light: OmniLight3D
var _prompt: Label3D


func _ready() -> void:
	add_to_group("soul_orbs")
	_t = randf() * 6.0
	_sprite = get_node_or_null("Sprite") as Sprite3D
	if _sprite == null:
		_sprite = Util.make_sprite("res://assets/sprites/soul_orb.png", 0.9, false)
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.position = Vector3(0, 0.9, 0)
		_sprite.modulate = Color(1.2, 1.2, 1.6, 1.0)
		add_child(_sprite)

		_light = OmniLight3D.new()
		_light.light_color = Color(0.55, 0.7, 1.0)
		_light.light_energy = 1.4
		_light.omni_range = 5.0
		_light.position = Vector3(0, 1.0, 0)
		add_child(_light)

		_prompt = Label3D.new()
		_prompt.font_size = 40
		_prompt.pixel_size = 0.008
		_prompt.outline_size = 12
		_prompt.outline_modulate = Color(0.05, 0.02, 0.1, 1.0)
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.no_depth_test = true
		_prompt.position = Vector3(0, 2.0, 0)
		_prompt.visible = false
		add_child(_prompt)
	else:
		_light = get_node_or_null("Light") as OmniLight3D
		_prompt = get_node_or_null("Prompt") as Label3D

	if Engine.is_editor_hint():
		return
	_sprite.scale = Vector3(0.1, 0.1, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector3(1, 1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or consumed:
		return
	_t += delta
	_sprite.position.y = 0.9 + sin(_t * 3.0) * 0.12
	if not forced:
		_life -= delta
		if _life <= 0.0:
			_expire()
			return
		if _life < 1.8:
			_sprite.visible = int(_life * 8.0) % 2 == 0
	# Petunjuk tombol saat pemain dekat
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.can_raise:
		var d: float = (player.global_position - global_position).length()
		if d <= player.RAISE_RANGE:
			_prompt.visible = true
			var pct: int = int(round(player.raise_chance(data) * 100.0))
			if forced:
				_prompt.text = "[E] RAISE"
			else:
				_prompt.text = "[E] Raise  %d Essence  %d%%" % [int(data.raise_cost), pct]
		else:
			_prompt.visible = false
	else:
		_prompt.visible = false


func consume() -> void:
	if consumed:
		return
	consumed = true
	remove_from_group("soul_orbs")
	_prompt.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector3(2.0, 2.0, 1.0), 0.3)
	tw.tween_property(_light, "light_energy", 3.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _expire() -> void:
	consumed = true
	remove_from_group("soul_orbs")
	_prompt.visible = false
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector3(0.05, 0.05, 1.0), 0.25)
	tw.tween_callback(queue_free)
