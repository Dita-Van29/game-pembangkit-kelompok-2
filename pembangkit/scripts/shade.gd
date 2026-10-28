class_name Shade
extends CharacterBody3D
## Monster yang dibangkitkan Mira. Mengikuti pemain, menyerang musuh terdekat.
## Tank punya Taunt, Striker punya Lunge (sesuai GDD bagian 10.5).

@export var data: EnemyData = null
var stage = null
var role: String = "striker"
var hp: int = 1
var max_hp: int = 1
var shield: int = 0
var dead: bool = false
var body_radius: float = 0.45

var _sprite: Sprite3D
var _aura: OmniLight3D
var _ring: MeshInstance3D
var _target = null
var _retarget_t: float = 0.0
var _atk_cd: float = 0.0
var _lunge_t: float = 0.0
var _lunge_cd: float = 2.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _taunt_cd: float = 4.0
var _knock: Vector3 = Vector3.ZERO
var _bob_t: float = 0.0
var _base_y: float = 1.0


func setup(d, st) -> void:
	data = d
	stage = st
	role = String(d.role)
	hp = int(d.shade_hp)
	max_hp = hp
	body_radius = float(d.body_radius)
	if GameState.shade_shield:
		shield = 4


func _ready() -> void:
	if data == null:
		return
	role = String(data.role)
	body_radius = float(data.body_radius)
	add_to_group("shades")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8
	collision_mask = 1
	_bob_t = randf() * 6.0

	_sprite = get_node_or_null("Sprite") as Sprite3D
	if _sprite == null:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = body_radius
		cap.height = maxf(1.0, body_radius * 2.4)
		cs.shape = cap
		cs.position = Vector3(0, cap.height * 0.5, 0)
		add_child(cs)
		# Sprite musuh asli diberi warna biru keunguan (pengganti shader Shade)
		_sprite = Util.make_sprite(data.sprite_path, data.sprite_height, false)
		_sprite.modulate = Color(0.55, 0.6, 1.5, 1.0)
		add_child(_sprite)
		_ring = Util.disk(self, body_radius * 1.5, Color(0.55, 0.4, 1.0, 0.55), true, 0.04)
		_aura = OmniLight3D.new()
		_aura.light_color = Color(0.5, 0.45, 1.0)
		_aura.light_energy = 1.0
		_aura.omni_range = 4.0
		_aura.position = Vector3(0, 1.0, 0)
		add_child(_aura)
	else:
		_ring = get_node_or_null("Ring") as MeshInstance3D
		_aura = get_node_or_null("Aura") as OmniLight3D
	_base_y = data.sprite_height * 0.5

	if Engine.is_editor_hint():
		return
	# Efek muncul
	_sprite.scale = Vector3(0.1, 0.1, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector3(1, 1, 1), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or stage == null or stage.player == null:
		return
	_bob_t += delta
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_taunt_cd = maxf(0.0, _taunt_cd - delta)
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)

	var pl = stage.player
	var to_p: Vector3 = pl.global_position - global_position
	to_p.y = 0.0
	var dist_p: float = to_p.length()
	if dist_p > 16.0:
		global_position = pl.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		return

	_retarget(delta, pl)
	if role == "tank":
		_try_taunt()

	var move: Vector3 = Vector3.ZERO
	var speed: float = float(data.shade_speed)

	if _lunge_t > 0.0:
		_lunge_t -= delta
		velocity = _lunge_dir * 15.0
		move_and_slide()
		if _lunge_t <= 0.0:
			_finish_lunge()
		_update_visual()
		return

	if _target != null and is_instance_valid(_target) and not _target.dead:
		var to_t: Vector3 = _target.global_position - global_position
		to_t.y = 0.0
		var dist_t: float = to_t.length()
		var reach: float = float(data.shade_attack_range) + float(_target.body_radius)
		if role == "striker" and _lunge_cd <= 0.0 and dist_t > 2.4 and dist_t < 6.0:
			_lunge_dir = to_t.normalized()
			_lunge_t = 0.22
			_lunge_cd = 5.0
		elif dist_t > reach * 0.85:
			move = to_t.normalized()
		if dist_t <= reach and _atk_cd <= 0.0:
			_attack(_target)
	else:
		# Ikut pemain dengan formasi melingkar
		var shades: Array = get_tree().get_nodes_in_group("shades")
		var idx: int = maxi(0, shades.find(self))
		var count: int = maxi(3, shades.size())
		var a: float = float(idx) * TAU / float(count) + PI * 0.5
		var desired: Vector3 = pl.global_position + Vector3(cos(a), 0.0, sin(a)) * 2.3
		var to_d: Vector3 = desired - global_position
		to_d.y = 0.0
		if to_d.length() > 0.6:
			move = to_d.normalized()
		speed += clampf(dist_p - 3.5, 0.0, 6.0) * 1.0

	velocity = move * speed + _knock
	move_and_slide()
	global_position.y = 0.0
	_update_visual()


func _retarget(delta: float, pl) -> void:
	_retarget_t -= delta
	if _retarget_t > 0.0:
		return
	_retarget_t = 0.25
	var best = null
	var best_d: float = 7.5
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = (e.global_position - global_position).length()
		var d_pl: float = (e.global_position - pl.global_position).length()
		if d < best_d and d_pl < 11.0:
			best_d = d
			best = e
	_target = best


func _attack(t) -> void:
	_atk_cd = float(data.shade_attack_cd)
	t.take_damage(int(data.shade_damage), global_position, 4.0)
	_sprite.scale = Vector3(1.25, 0.8, 1.0)


func _finish_lunge() -> void:
	var dmg: int = int(data.shade_damage)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		if (e.global_position - global_position).length() <= 2.0:
			e.take_damage(dmg, global_position, 5.0)
			if not e.dead:
				e.take_damage(dmg, global_position, 2.0)
			break
	Util.popup(stage.world, global_position + Vector3(0, 1.8, 0), "Lunge!", Color(0.7, 0.75, 1.0), 34)


func _try_taunt() -> void:
	if _taunt_cd > 0.0:
		return
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and (e.global_position - global_position).length() < 8.0:
			near.append(e)
	if near.is_empty():
		return
	for e in near:
		e.force_target(self, 3.0)
	_taunt_cd = 8.0
	Util.popup(stage.world, global_position + Vector3(0, 2.0, 0), "Taunt!", Color(0.8, 0.7, 1.0), 40)
	var ring := Util.disk(stage.world, 1.0, Color(0.6, 0.45, 1.0, 0.6), true, 0.05)
	ring.global_position = global_position + Vector3(0, 0.05, 0)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(5.0, 1.0, 5.0), 0.5)
	tw.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ring.queue_free)


func take_damage(amount: int, from_pos: Vector3 = Vector3.ZERO, kb: float = 4.0) -> void:
	if dead:
		return
	var left: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, left)
		shield -= absorbed
		left -= absorbed
	hp -= left
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * kb
	_sprite.modulate = Color(1.6, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(0.55, 0.6, 1.5, 1.0), 0.2)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("shades")
	collision_layer = 0
	if stage != null:
		stage.on_shade_died(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector3(0.1, 1.6, 1.0), 0.35)
	tw.tween_property(_sprite, "position:y", _base_y + 1.2, 0.35)
	tw.chain().tween_callback(queue_free)


func _update_visual() -> void:
	if _target != null and is_instance_valid(_target):
		var d: float = _target.global_position.x - global_position.x
		if absf(d) > 0.2:
			_sprite.flip_h = d < 0.0
	elif absf(velocity.x) > 0.3:
		_sprite.flip_h = velocity.x < 0.0
	# Melayang halus + kembali ke skala normal setelah menyerang
	_sprite.position.y = _base_y + 0.12 + sin(_bob_t * 4.0) * 0.08
	_sprite.scale = _sprite.scale.lerp(Vector3(1, 1, 1), 0.2)
	_aura.light_energy = 0.9 + sin(_bob_t * 5.0) * 0.2
