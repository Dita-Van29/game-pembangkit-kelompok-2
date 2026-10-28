class_name Player
extends CharacterBody3D
## Mira: gerak 8 arah, combo sabit 3 pukulan, Dash Bayangan, Raise.

signal raised(success: bool, data)
signal attacked
signal died

enum State { NORMAL, ATTACK, DASH, CAST, HURT, DEAD }

const WALK_SPEED := 6.2
const DASH_SPEED := 17.0
const DASH_TIME := 0.2
const DASH_IFRAME := 0.25
const DASH_COOLDOWN := 1.2
const MAX_ESSENCE := 100.0
const RAISE_RANGE := 3.4
const ATTACK_TIME := 0.30
const COMBO_DMG := [10, 10, 15]

var stage = null
var max_hp: int = 10          # 10 = 5 hati penuh (1 hati = 2 HP)
var hp: int = 10
var essence: float = 30.0
var locked: bool = false      # true saat dialog / cutscene
var can_raise: bool = false   # dibuka lewat tutorial
var dead: bool = false
var state: int = State.NORMAL
var facing: Vector3 = Vector3(0, 0, 1)
var body_radius: float = 0.4

var moved_total: float = 0.0
var attacks_done: int = 0
var dash_cd: float = 0.0

var _sprite: Sprite3D
var _tex_front: Texture2D
var _tex_back: Texture2D
var _tex_side: Texture2D
var _timer: float = 0.0
var _hit_delay: float = 0.0
var _hit_pending: bool = false
var _combo_index: int = 0
var _combo_reset: float = 0.0
var _attack_buffer: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _afterimage_t: float = 0.0
var _hurt_inv: float = 0.0
var _dash_inv: float = 0.0
var _knock: Vector3 = Vector3.ZERO
var _walk_t: float = 0.0
var _cast_pos: Vector3 = Vector3.ZERO
var _cast_ok: bool = false
var _cast_data = null
var _attack_lunge: Vector3 = Vector3.ZERO
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1

	_tex_front = Util.load_tex("res://assets/sprites/mira_front.png")
	_tex_back = Util.load_tex("res://assets/sprites/mira_back.png")
	_tex_side = Util.load_tex("res://assets/sprites/mira_side.png")
	_sprite = get_node_or_null("Sprite") as Sprite3D
	if _sprite == null:
		# Dibangun lewat kode hanya jika scene tidak membawa node visual sendiri
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.6
		cs.shape = cap
		cs.position = Vector3(0, 0.9, 0)
		add_child(cs)
		_sprite = Util.make_sprite("res://assets/sprites/mira_front.png", 2.1)
		add_child(_sprite)
		Util.blob_shadow(self, 0.6)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.8, 0.55)
		_light.light_energy = 1.1
		_light.omni_range = 8.0
		_light.position = Vector3(0, 2.4, 0.6)
		add_child(_light)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or dead or stage == null:
		return
	dash_cd = maxf(0.0, dash_cd - delta)
	_hurt_inv = maxf(0.0, _hurt_inv - delta)
	_dash_inv = maxf(0.0, _dash_inv - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)

	if Input.is_action_just_pressed("attack") and not locked:
		_attack_buffer = 0.25
	if not locked:
		if Input.is_action_just_pressed("dash"):
			_try_dash()
		if Input.is_action_just_pressed("raise") and not _near_dev_sign():
			try_raise()
		if Input.is_action_just_pressed("summon_1"):
			_summon(0)
		if Input.is_action_just_pressed("summon_2"):
			_summon(1)
		if Input.is_action_just_pressed("summon_3"):
			_summon(2)

	match state:
		State.NORMAL:
			_state_normal(delta)
		State.ATTACK:
			_state_attack(delta)
		State.DASH:
			_state_dash(delta)
		State.CAST:
			_state_cast(delta)
		State.HURT:
			_timer -= delta
			velocity = _knock
			move_and_slide()
			if _timer <= 0.0:
				state = State.NORMAL

	_update_sprite(delta)


# ------------------------------------------------------------------ States
func _input_dir() -> Vector3:
	if locked:
		return Vector3.ZERO
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y)


func _state_normal(delta: float) -> void:
	_combo_reset -= delta
	if _combo_reset <= 0.0:
		_combo_index = 0
	var dir: Vector3 = _input_dir()
	if dir.length() > 0.1:
		facing = dir.normalized()
		_walk_t += delta
	velocity = dir * WALK_SPEED + _knock
	var before: Vector3 = global_position
	move_and_slide()
	moved_total += (global_position - before).length()
	if _attack_buffer > 0.0 and not locked:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACK
	_attack_buffer = 0.0
	var aim: Vector3 = _mouse_aim_dir()
	if aim != Vector3.ZERO:
		facing = aim
	elif _input_dir() != Vector3.ZERO:
		facing = _input_dir().normalized()
	_timer = ATTACK_TIME
	_hit_delay = 0.08
	_hit_pending = true
	_attack_lunge = facing * 3.5
	var idx: int = _combo_index
	_combo_index = (_combo_index + 1) % 3
	_combo_reset = 0.8
	attacks_done += 1
	_spawn_slash(idx)
	attacked.emit()


func _state_attack(delta: float) -> void:
	_timer -= delta
	_hit_delay -= delta
	if _hit_pending and _hit_delay <= 0.0:
		_hit_pending = false
		var idx: int = (_combo_index + 2) % 3   # indeks pukulan yang sedang berjalan
		_apply_attack_hit(idx)
	_attack_lunge = _attack_lunge.move_toward(Vector3.ZERO, 20.0 * delta)
	velocity = _attack_lunge + _knock
	move_and_slide()
	if _timer <= 0.0:
		if _attack_buffer > 0.0 and not locked:
			_start_attack()
		else:
			state = State.NORMAL


func _apply_attack_hit(idx: int) -> void:
	var dmg: int = int(COMBO_DMG[idx]) + GameState.attack_bonus
	var reach: float = 2.4 if idx < 2 else 3.1
	var half_angle: float = 58.0 if idx < 2 else 115.0
	var min_dot: float = cos(deg_to_rad(half_angle))
	var kb: float = 5.0 if idx < 2 else 9.0
	var hit_any: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > reach + e.body_radius:
			continue
		if dist > 0.05 and facing.dot(to / dist) < min_dot:
			continue
		e.take_damage(dmg, global_position, kb)
		hit_any = true
	if hit_any and stage != null:
		stage.shake(0.12 if idx < 2 else 0.25)


func _try_dash() -> void:
	if dash_cd > 0.0 or state == State.DEAD or state == State.CAST:
		return
	var dir: Vector3 = _input_dir()
	if dir == Vector3.ZERO:
		dir = facing
	_dash_dir = dir.normalized()
	facing = _dash_dir
	_hit_pending = false
	_attack_buffer = 0.0
	state = State.DASH
	_timer = DASH_TIME
	dash_cd = DASH_COOLDOWN
	_dash_inv = DASH_IFRAME
	_afterimage_t = 0.0


func _state_dash(delta: float) -> void:
	_timer -= delta
	_afterimage_t -= delta
	if _afterimage_t <= 0.0:
		_afterimage_t = 0.035
		_spawn_afterimage()
	velocity = _dash_dir * DASH_SPEED
	var before: Vector3 = global_position
	move_and_slide()
	moved_total += (global_position - before).length()
	if _timer <= 0.0:
		state = State.NORMAL


func _state_cast(delta: float) -> void:
	_timer -= delta
	velocity = Vector3.ZERO
	move_and_slide()
	if _timer <= 0.0:
		_finish_raise()
		state = State.NORMAL


# ------------------------------------------------------------------ Raise
func raise_chance(data) -> float:
	var c: float = float(data.raise_chance) + 0.05 * float(GameState.tether_level - 1)
	return clampf(c, 0.05, 0.95)


func nearest_orb():
	var best = null
	var best_d: float = RAISE_RANGE
	for o in get_tree().get_nodes_in_group("soul_orbs"):
		if not is_instance_valid(o) or o.consumed:
			continue
		var d: float = (o.global_position - global_position).length()
		if d <= best_d:
			best_d = d
			best = o
	return best


func _near_dev_sign() -> bool:
	for s in get_tree().get_nodes_in_group("dev_sign"):
		if s.can_interact():
			return true
	return false


func try_raise() -> void:
	if not can_raise or state == State.DEAD or state == State.CAST or state == State.DASH:
		return
	var orb = nearest_orb()
	if orb == null:
		_say("Tidak ada Soul Orb di dekatmu", Color(0.75, 0.75, 0.85))
		return
	var data = orb.data
	var cost: int = int(data.raise_cost)
	if essence < float(cost):
		_say("Soul Essence kurang (%d)" % cost, Color(1.0, 0.5, 0.5))
		return
	if stage != null and stage.shade_count() >= GameState.shade_limit:
		_say("Pasukan penuh!", Color(1.0, 0.7, 0.4))
		return
	essence -= float(cost)
	_cast_ok = orb.forced or randf() < raise_chance(data)
	_cast_data = data
	_cast_pos = orb.global_position
	orb.consume()
	state = State.CAST
	_timer = 0.55
	facing = (_cast_pos - global_position)
	facing.y = 0.0
	if facing.length() < 0.01:
		facing = Vector3(0, 0, 1)
	facing = facing.normalized()
	if stage != null:
		stage.fx_raise_cast(_cast_pos)


func _finish_raise() -> void:
	if _cast_ok:
		GameState.bank_add(_cast_data.id)
		if stage != null:
			stage.spawn_shade(_cast_data, _cast_pos)
		_say("RAISE BERHASIL!", Color(0.6, 1.0, 0.9), 56)
	else:
		_say("Gagal... jiwanya lenyap", Color(1.0, 0.45, 0.55), 48)
		if stage != null:
			stage.fx_raise_fail(_cast_pos)
	raised.emit(_cast_ok, _cast_data)


func _summon(idx: int) -> void:
	if stage != null and not dead and state != State.CAST:
		stage.try_summon(idx)


# ------------------------------------------------------------------ Damage & resource
func is_invulnerable() -> bool:
	return _hurt_inv > 0.0 or _dash_inv > 0.0


func take_damage(amount: int, from_pos: Vector3 = Vector3.ZERO, knockback: float = 6.0) -> void:
	if dead or is_invulnerable():
		return
	hp = maxi(0, hp - amount)
	_hurt_inv = 0.9
	var away: Vector3 = global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * knockback
	_flash(Color(1.0, 0.35, 0.35))
	if stage != null:
		stage.shake(0.35)
	if hp <= 0:
		_die()
		return
	state = State.HURT
	_timer = 0.16
	_hit_pending = false


func heal(amount: int) -> void:
	if dead:
		return
	hp = mini(max_hp, hp + amount)
	if stage != null:
		Util.popup(stage.world, global_position + Vector3(0, 2.6, 0), "+HP", Color(1.0, 0.5, 0.65))


func add_essence(amount: float) -> void:
	essence = minf(MAX_ESSENCE, essence + amount * (1.0 + GameState.essence_bonus))


func revive_full() -> void:
	dead = false
	hp = max_hp
	state = State.NORMAL
	essence = maxf(essence, 30.0)


func _die() -> void:
	dead = true
	state = State.DEAD
	velocity = Vector3.ZERO
	_sprite.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector3(1.3, 0.2, 1.0), 0.4)
	tw.tween_property(_sprite, "position:y", 0.25, 0.4)
	died.emit()


func _say(text: String, color: Color, size: int = 44) -> void:
	if stage != null:
		Util.popup(stage.world, global_position + Vector3(0, 2.7, 0), text, color, size)


func _flash(color: Color) -> void:
	_sprite.modulate = color
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.2)


# ------------------------------------------------------------------ Visual
func _mouse_aim_dir() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mp: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mp)
	var dir: Vector3 = cam.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return Vector3.ZERO
	var t: float = (0.0 - from.y) / dir.y
	if t < 0.0:
		return Vector3.ZERO
	var hit: Vector3 = from + dir * t
	var d: Vector3 = hit - global_position
	d.y = 0.0
	if d.length() < 0.2:
		return Vector3.ZERO
	return d.normalized()


func _spawn_slash(idx: int) -> void:
	if stage == null:
		return
	var reach: float = 2.4 if idx < 2 else 3.1
	var arc: float = 120.0 if idx < 2 else 230.0
	var mi := MeshInstance3D.new()
	mi.mesh = Util.make_arc_mesh(reach * 0.45, reach, arc)
	var m := Util.mat(Color(0.95, 0.65, 1.0, 0.85), true, true, true)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.world.add_child(mi)
	mi.global_position = global_position + Vector3(0, 0.25, 0)
	mi.rotation.y = Util.yaw_from_dir(facing)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)


func _spawn_afterimage() -> void:
	if stage == null:
		return
	var s := Util.make_sprite("res://assets/sprites/mira_front.png", 2.1, false)
	s.texture = _sprite.texture
	s.flip_h = _sprite.flip_h
	s.modulate = Color(0.55, 0.4, 1.0, 0.8)
	stage.world.add_child(s)
	s.global_position = global_position + Vector3(0, 1.05, 0)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.45, 0.22)
	tw.tween_callback(s.queue_free)


func _update_sprite(delta: float) -> void:
	var f: Vector3 = facing
	if absf(f.z) > absf(f.x) * 1.2:
		_sprite.texture = _tex_front if f.z > 0.0 else _tex_back
		_sprite.flip_h = false
	else:
		_sprite.texture = _tex_side
		_sprite.flip_h = f.x < 0.0

	var base_y: float = 2.1 * 0.5
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.5 and state == State.NORMAL
	if state == State.DEAD:
		_sprite.position.y = base_y * 0.2
	elif moving:
		var w: float = sin(_walk_t * 16.0)
		_sprite.position.y = base_y + absf(w) * 0.07
		_sprite.scale = Vector3(1.0 - 0.04 * absf(w), 1.0 + 0.05 * absf(w), 1.0)
	elif state == State.CAST:
		_sprite.position.y = base_y + 0.12
		_sprite.scale = Vector3(1.0, 1.05, 1.0)
	elif state == State.ATTACK:
		_sprite.scale = Vector3(1.1, 0.92, 1.0)
		_sprite.position.y = base_y
	else:
		var idle: float = sin(Time.get_ticks_msec() * 0.004) * 0.02
		_sprite.position.y = base_y + idle
		_sprite.scale = Vector3(1.0, 1.0, 1.0)

	# Kedip saat kebal setelah terkena serangan
	if _hurt_inv > 0.0 and state != State.DEAD:
		_sprite.visible = int(_hurt_inv * 20.0) % 2 == 0
	else:
		_sprite.visible = true
