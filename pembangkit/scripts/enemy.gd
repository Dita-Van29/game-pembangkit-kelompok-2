class_name Enemy
extends CharacterBody3D
## Musuh generik berbasis EnemyData: mengejar, telegraph (garis merah), terjang, lalu pulih.

enum S { SPAWN, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

@export var data: EnemyData = null
var stage = null
var hp: int = 1
var max_hp: int = 1
var dead: bool = false
var body_radius: float = 0.5
var state: int = S.SPAWN

var _timer: float = 0.0
var _target = null
var _retarget_t: float = 0.0
var _forced_target = null
var _forced_t: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _lunge_hit: bool = false
var _knock: Vector3 = Vector3.ZERO
var _stun: float = 0.0
var _attack_cd: float = 0.0
var _walk_t: float = 0.0
var _sprite: Sprite3D
var _telegraph: Node3D
var _telegraph_mat: StandardMaterial3D
var _bar_bg: Sprite3D
var _bar_fg: Sprite3D
var _base_y: float = 1.0


func setup(d, st) -> void:
	data = d
	stage = st
	hp = int(d.max_hp)
	max_hp = hp
	body_radius = float(d.body_radius)


func _ready() -> void:
	if data == null:
		return
	body_radius = float(data.body_radius)
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	_walk_t = randf() * 10.0

	_sprite = get_node_or_null("Sprite") as Sprite3D
	if _sprite == null:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = body_radius
		cap.height = maxf(1.0, body_radius * 2.4)
		cs.shape = cap
		cs.position = Vector3(0, cap.height * 0.5, 0)
		add_child(cs)
		_sprite = Util.make_sprite(data.sprite_path, data.sprite_height)
		add_child(_sprite)
		Util.blob_shadow(self, body_radius * 1.3)
	_base_y = data.sprite_height * 0.5

	# Telegraph: kotak merah memanjang searah terjangan
	_telegraph = Node3D.new()
	add_child(_telegraph)
	var length: float = float(data.lunge_speed) * float(data.lunge_time) + float(data.hit_radius)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(data.hit_radius) * 2.0, 0.03, length)
	mi.mesh = bm
	_telegraph_mat = Util.mat(Color(1.0, 0.15, 0.15, 0.4), true, true, true)
	mi.material_override = _telegraph_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.05, -length * 0.5)
	_telegraph.add_child(mi)
	_telegraph.visible = false

	# Bar HP kecil (muncul setelah kena serangan)
	var wt: Texture2D = Util.white_tex()
	_bar_bg = _make_bar(wt, Color(0.1, 0.05, 0.1, 0.9), 10)
	_bar_fg = _make_bar(wt, Color(0.9, 0.2, 0.3, 1.0), 11)
	_bar_bg.visible = false
	_bar_fg.visible = false

	if Engine.is_editor_hint():
		return
	# Muncul dari retakan: membesar dari nol
	_sprite.scale = Vector3(0.05, 0.05, 1.0)
	state = S.SPAWN
	_timer = 0.55
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector3(1, 1, 1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_bar(tex: Texture2D, color: Color, prio: int) -> Sprite3D:
	var b := Sprite3D.new()
	b.texture = tex
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.shaded = false
	b.no_depth_test = true
	b.render_priority = prio
	b.centered = false
	b.pixel_size = 0.06
	b.modulate = color
	b.position = Vector3(-0.48, float(data.sprite_height) * 0.78, 0.0)
	add_child(b)
	return b


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or stage == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_forced_t -= delta
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)

	if _stun > 0.0:
		_stun -= delta
		velocity = _knock
		move_and_slide()
		_update_visual(delta)
		return

	match state:
		S.SPAWN:
			_timer -= delta
			velocity = Vector3.ZERO
			if _timer <= 0.0:
				state = S.CHASE
		S.CHASE:
			_do_chase(delta)
		S.WINDUP:
			_timer -= delta
			velocity = _knock
			move_and_slide()
			if _telegraph_mat != null:
				var k: float = 1.0 - clampf(_timer / maxf(0.01, float(data.windup)), 0.0, 1.0)
				_telegraph_mat.albedo_color.a = 0.25 + 0.5 * k
			if _timer <= 0.0:
				_telegraph.visible = false
				state = S.LUNGE
				_timer = float(data.lunge_time)
				_lunge_hit = false
		S.LUNGE:
			_timer -= delta
			velocity = _lunge_dir * float(data.lunge_speed) + _knock * 0.3
			move_and_slide()
			if not _lunge_hit:
				_check_lunge_hit()
			if _timer <= 0.0:
				state = S.RECOVER
				_timer = float(data.recover_time)
		S.RECOVER:
			_timer -= delta
			if data.retreat:
				velocity = -_lunge_dir * float(data.speed) * 1.1 + _knock
			else:
				velocity = _knock
			move_and_slide()
			if _timer <= 0.0:
				_attack_cd = 0.2
				state = S.CHASE

	_update_visual(delta)


func _do_chase(delta: float) -> void:
	_retarget(delta)
	if _target == null:
		velocity = _knock
		move_and_slide()
		return
	var to: Vector3 = _target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist <= float(data.trigger_range) and _attack_cd <= 0.0:
		_begin_windup(to)
		return
	var move_dir: Vector3 = Vector3.ZERO
	if dist > 0.9:
		move_dir = to / maxf(dist, 0.001)
	velocity = move_dir * float(data.speed) + _separation() * 1.5 + _knock
	_walk_t += delta
	move_and_slide()
	global_position.y = 0.0


func _begin_windup(to: Vector3) -> void:
	state = S.WINDUP
	_timer = float(data.windup)
	if to.length() > 0.01:
		_lunge_dir = to.normalized()
	_telegraph.rotation.y = Util.yaw_from_dir(_lunge_dir)
	_telegraph.visible = true
	if _telegraph_mat != null:
		_telegraph_mat.albedo_color.a = 0.25


func _check_lunge_hit() -> void:
	var cands: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("shades")
	for c in cands:
		if not is_instance_valid(c) or c.dead:
			continue
		var d: Vector3 = c.global_position - global_position
		d.y = 0.0
		if d.length() <= float(data.hit_radius) + float(c.body_radius):
			c.take_damage(int(data.damage), global_position, 6.0)
			_lunge_hit = true
			return


func _retarget(delta: float) -> void:
	if _target != null and not is_instance_valid(_target):
		_target = null
		_retarget_t = 0.0
	_retarget_t -= delta
	if _retarget_t > 0.0:
		return
	_retarget_t = 0.3
	var best = null
	var best_score: float = 1.0e9
	var cands: Array = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("shades")
	for c in cands:
		if not is_instance_valid(c) or c.dead:
			continue
		var d: float = (c.global_position - global_position).length()
		var score: float = d
		if c.is_in_group("shades"):
			score = d * 0.85
			if c.role == "tank":
				score = d * 0.6
		if _forced_t > 0.0 and c == _forced_target:
			score = -1.0
		if score < best_score:
			best_score = score
			best = c
	_target = best


func force_target(t, seconds: float) -> void:
	_forced_target = t
	_forced_t = seconds
	_retarget_t = 0.0


func _separation() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0.0
		var l: float = d.length()
		if l < 1.0 and l > 0.001:
			push += d / l * (1.0 - l)
	return push * 3.0


# ------------------------------------------------------------------ Damage
func take_damage(amount: int, from_pos: Vector3 = Vector3.ZERO, kb: float = 5.0) -> void:
	if dead or state == S.SPAWN:
		return
	hp -= amount
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * kb
	_stun = 0.12
	if state == S.WINDUP:
		state = S.CHASE
		_telegraph.visible = false
		_attack_cd = 0.5
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.18)
	if stage != null:
		Util.popup(stage.world, global_position + Vector3(0, float(data.sprite_height) * 0.8, 0), str(amount), Color(1.0, 0.95, 0.6), 36)
	_bar_bg.visible = true
	_bar_fg.visible = true
	_bar_fg.scale.x = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	state = S.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	velocity = Vector3.ZERO
	_telegraph.visible = false
	_bar_bg.visible = false
	_bar_fg.visible = false
	if stage != null:
		stage.on_enemy_died(self)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector3(1.4, 0.05, 1.0), 0.25)
	tw.tween_property(_sprite, "position:y", 0.05, 0.25)
	tw.chain().tween_callback(queue_free)


# ------------------------------------------------------------------ Visual
func _update_visual(delta: float) -> void:
	if state == S.SPAWN or dead:
		return
	var face: Vector3 = velocity
	if _target != null and is_instance_valid(_target):
		face = _target.global_position - global_position
	if state == S.LUNGE or state == S.WINDUP:
		face = _lunge_dir
	if absf(face.x) > 0.15:
		_sprite.flip_h = face.x < 0.0

	if state == S.WINDUP:
		# merunduk sebelum menerjang
		_sprite.scale = Vector3(1.15, 0.8, 1.0)
		_sprite.position.y = _base_y * 0.9
	elif state == S.LUNGE:
		_sprite.scale = Vector3(0.9, 1.15, 1.0)
		_sprite.position.y = _base_y + 0.15
	else:
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.4
		if moving:
			var w: float = sin(_walk_t * (float(data.speed) * 2.6))
			_sprite.position.y = _base_y + absf(w) * 0.09
			_sprite.scale = Vector3(1.0 + 0.05 * w, 1.0 - 0.06 * w, 1.0)
		else:
			_sprite.position.y = _base_y
			_sprite.scale = Vector3(1, 1, 1)
