extends Node3D
## STAGE 1 - DESA LUMEN (Tutorial)
## 3 area: Halaman Desa -> Kebun Desa -> Gerbang Desa.
## Musuh: Slime Lumut, Tikus Gerogot. Mengajarkan gerak, serangan, dash, lalu Raise pertama.

const HudScript := preload("res://scripts/hud.gd")

const ENEMY_IDS := ["slime_lumut", "tikus_gerogot"]
const AREA_SPACING := 34.0     # jarak antar pusat area
const HW := 13.0               # setengah lebar area (sumbu X)
const HD := 9.0                # setengah kedalaman area (sumbu Z)
const GATE_HALF := 3.0         # setengah lebar gerbang/lorong
const CORRIDOR_LEN := 8.0
const CAM_OFFSET := Vector3(0.0, 14.9, 12.5)
const SHADE_RECALL_COOLDOWN := 4.0
const AREA_NAMES := ["Halaman Desa", "Kebun Desa", "Gerbang Desa"]

# Tiap area: daftar gelombang. Tiap gelombang: [[id_musuh, jumlah], ...]
const AREA_WAVES := [
	[ [["slime_lumut", 1]],
	  [["tikus_gerogot", 2], ["slime_lumut", 1]],
	  [["tikus_gerogot", 2]] ],
	[ [["slime_lumut", 2], ["tikus_gerogot", 2]],
	  [["slime_lumut", 1], ["tikus_gerogot", 3]] ],
	[ [["tikus_gerogot", 3], ["slime_lumut", 2]],
	  [["slime_lumut", 2], ["tikus_gerogot", 3]] ],
]

const UPGRADES := [
	{"id": "tether", "title": "Soul Tether +1", "desc": "Peluang Raise naik +5% untuk semua musuh."},
	{"id": "limit", "title": "Batas Shade +1", "desc": "Pasukan aktif bertambah satu Shade (maksimal 6)."},
	{"id": "scythe", "title": "Sabit Tajam", "desc": "Setiap pukulan serangan dasar +2 damage."},
	{"id": "essence", "title": "Soul Essence Mengalir", "desc": "Soul Essence terisi 25% lebih cepat."},
	{"id": "shield", "title": "Perisai Shade", "desc": "Setiap Shade mendapat perisai ekstra 4 HP."},
]

signal tick
signal enemy_down
signal raise_resolved

var player = null
var pip = null
var hud = null
var cam: Camera3D = null
var world: Node3D = null      # wadah entitas dinamis (musuh, shade, efek)
var level: Node3D = null      # wadah geometri level
var enemy_db: Dictionary = {}
var shade_cd: Dictionary = {}

var current_area: int = 0
var area_total: int = 0
var area_kills: int = 0
var alive_enemies: int = 0
var total_kills: int = 0
var total_raised: int = 0
var tutorial_active: bool = false
var tutorial_orb_made: bool = false

var cam_shake: float = 0.0
var tiltshift_on: bool = true
var gates: Array = []
var dev_sign = null           # papan developer (muncul setelah Area 1 selesai)
var _board_open: bool = false
var fire_spots: Array = []
var bram_pos: Vector3 = Vector3(-10.0, 0.0, 1.0)

var _t: float = 0.0
var _cam_attr: CameraAttributesPractical
var _arrow: MeshInstance3D = null
var _arrow_x: float = 0.0


# ================================================================== Setup
func _ready() -> void:
	add_to_group("stage")
	for id in ENEMY_IDS:
		var d = load("res://data/enemies/%s.tres" % id)
		if d == null:
			d = EnemyData.new()
			d.id = id
		enemy_db[id] = d

	# Level (bangunan, pagar, gerbang, prop, pohon) adalah scene statis:
	# scenes/levels/Stage1Level.tscn, bisa dilihat dan diedit di editor 3D.
	level = $Level
	world = $World
	# Contoh musuh/Shade/orb di scene hanya untuk preview editor -> buang saat game jalan
	var preview: Node = get_node_or_null("PreviewOnly")
	if preview != null:
		remove_child(preview)
		preview.queue_free()
	_collect_level_nodes()
	_setup_dev_sign()

	_build_environment()
	_spawn_player()
	_build_camera()
	_build_hud()
	_run_stage()


func _collect_level_nodes() -> void:
	for i in range(3):
		var g: Node = level.get_node("Gates/Gate%d" % i)
		var mist: MeshInstance3D = g.get_node("Mist")
		# material kabut diduplikat agar tiap gerbang bisa memudar sendiri-sendiri
		mist.material_override = mist.material_override.duplicate()
		gates.append({"body": g.get_node("Body"), "pivot": g.get_node("Pivot"), "mist": mist})
	for f in get_tree().get_nodes_in_group("fire_hazards"):
		fire_spots.append(Vector3(f.global_position.x, 0.0, f.global_position.z))
	for l in get_tree().get_nodes_in_group("flicker"):
		l.set_meta("base", l.light_energy)
		l.set_meta("ph", randf() * 6.28)


func _setup_dev_sign() -> void:
	dev_sign = get_tree().get_first_node_in_group("dev_sign")
	if dev_sign == null:
		return
	dev_sign.interacted.connect(_on_dev_sign_interacted)
	# Tersembunyi sampai Area 1 selesai. Jika mengulang dari area 2/3, Area 1 sudah pernah
	# dibersihkan -> papan langsung ada.
	dev_sign.set_enabled(GameState.restart_area >= 1)


func _reveal_dev_sign() -> void:
	await _wait(0.9)
	dev_sign.reveal()
	Util.popup(world, dev_sign.global_position + Vector3(0, 3.6, 0), "Papan Developer - tekan E", Color(0.8, 1.0, 0.9), 40)


func _on_dev_sign_interacted() -> void:
	if _board_open or alive_enemies > 0 or player.locked or player.dead:
		return
	_board_open = true
	player.locked = true
	await hud.show_dev_board()
	await _unlock_player()
	_board_open = false


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.75)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.12, 0.24)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.68, 1.0)
	moon.light_energy = 0.95
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
	add_child(moon)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.5
	cam.far = 160.0
	cam.rotation_degrees = Vector3(-50.0, 0.0, 0.0)
	add_child(cam)
	cam.global_position = player.global_position + CAM_OFFSET
	cam.make_current()

	# Tilt-shift sederhana: blur dekat (bawah layar) dan jauh (atas layar)
	_cam_attr = CameraAttributesPractical.new()
	_cam_attr.dof_blur_amount = 0.08
	_cam_attr.dof_blur_far_distance = 23.0
	_cam_attr.dof_blur_far_transition = 8.0
	_cam_attr.dof_blur_near_distance = 17.0
	_cam_attr.dof_blur_near_transition = 4.0
	cam.attributes = _cam_attr
	_apply_tiltshift()


func _apply_tiltshift() -> void:
	_cam_attr.dof_blur_far_enabled = tiltshift_on
	_cam_attr.dof_blur_near_enabled = tiltshift_on


func _build_hud() -> void:
	hud = HudScript.new()
	hud.player = player
	hud.stage = self
	add_child(hud)


func _spawn_player() -> void:
	player = $Mira
	player.stage = self
	var cx: float = float(GameState.restart_area) * AREA_SPACING
	player.global_position = Vector3(cx - 9.0, 0.0, 3.0)
	player.can_raise = GameState.tutorial_done
	player.died.connect(_on_player_died)
	player.raised.connect(_on_player_raised)

	pip = $Pip
	pip.follow_target = player
	pip.global_position = player.global_position + Vector3(-1.1, 2.7, 0.3)
	pip.visible = GameState.intro_done


# ================================================================== Loop
func _process(delta: float) -> void:
	_t += delta
	tick.emit()
	if player == null or cam == null:
		return

	var target: Vector3 = player.global_position + CAM_OFFSET
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-7.0 * delta))
	if cam_shake > 0.01:
		cam.h_offset = randf_range(-1.0, 1.0) * cam_shake * 0.35
		cam.v_offset = randf_range(-1.0, 1.0) * cam_shake * 0.35
		cam_shake = lerpf(cam_shake, 0.0, 10.0 * delta)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

	for l in get_tree().get_nodes_in_group("flicker"):
		var base: float = float(l.get_meta("base"))
		var ph: float = float(l.get_meta("ph"))
		l.light_energy = base * (0.9 + 0.1 * sin(_t * 13.0 + ph) + 0.07 * sin(_t * 29.0 + ph * 2.0))

	if _arrow != null:
		_arrow.position.x = _arrow_x + sin(_t * 4.0) * 0.45
		_arrow.position.y = 3.2 + sin(_t * 2.0) * 0.15


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tiltshift"):
		tiltshift_on = not tiltshift_on
		_apply_tiltshift()
		Util.popup(world, player.global_position + Vector3(0, 2.8, 0), "Tilt-shift: %s" % ("ON" if tiltshift_on else "OFF"), Color(0.8, 0.9, 1.0), 36)


func shake(amount: float) -> void:
	cam_shake = maxf(cam_shake, amount)


# ================================================================== Async helpers
func _wait(sec: float) -> void:
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = sec
	add_child(tm)
	tm.start()
	await tm.timeout
	tm.queue_free()


func _wait_cond(cond: Callable, timeout: float = 0.0) -> void:
	var t: float = 0.0
	while not cond.call():
		await tick
		t += get_process_delta_time()
		if timeout > 0.0 and t >= timeout:
			return


func _wait_until_clear() -> void:
	while alive_enemies > 0:
		await enemy_down


func _unlock_player() -> void:
	await _wait(0.25)
	player.locked = false


# ================================================================== Alur stage
func _run_stage() -> void:
	if not GameState.intro_done:
		await _intro()
	for i in range(GameState.restart_area, 3):
		await _run_area(i)
	await _stage_clear()


func _intro() -> void:
	player.locked = true
	hud.show_banner("STAGE 1  -  DESA LUMEN", Color(1.0, 0.82, 0.5), 2.6)
	await _wait(1.8)
	await hud.say("Narator", "Malam di Desa Lumen. Segel Rift retak, dan monster-monster membanjiri desa...", Color(0.75, 0.8, 1.0))
	await hud.say("Old Bram", "Mira... uhuk... jangan diam saja, Nak. Mereka datang dari Rift di bawah Mahkota Tua.", Color(0.85, 0.8, 0.6))
	await hud.say("Old Bram", "Ambil lentera ini. Namanya Pip. Dia akan menuntunmu.", Color(0.85, 0.8, 0.6))
	pip.visible = true
	pip.global_position = bram_pos + Vector3(0, 2.0, 0)
	await hud.say("Pip", "Halo, Mira! Aku Pip. Cahayaku akan menunjukkan jalan ke area berikutnya!", Color(1.0, 0.95, 0.55))
	await hud.say("Old Bram", "Pergilah ke Mahkota Tua dan tutup Rift sebelum fajar ketiga. Tapi bersihkan desa ini dulu... Hati-hati!", Color(0.85, 0.8, 0.6))
	hud.close_dialog()
	GameState.intro_done = true
	await _unlock_player()


func _run_area(i: int) -> void:
	current_area = i
	var waves: Array = AREA_WAVES[i]
	area_total = 0
	for w in waves:
		for g in w:
			area_total += int(g[1])
	area_kills = 0
	alive_enemies = 0
	hud.set_area(i + 1, 3, AREA_NAMES[i])
	hud.set_counter(0, area_total)
	hud.set_wave(0, waves.size())
	hud.show_banner("Area %d: %s" % [i + 1, AREA_NAMES[i]], Color(1.0, 0.85, 0.55), 2.0)
	await _wait(2.0)

	for wi in range(waves.size()):
		hud.set_wave(wi + 1, waves.size())
		if wi > 0:
			hud.show_banner("Gelombang %d/%d" % [wi + 1, waves.size()], Color(1.0, 0.6, 0.5), 1.4)
			await _wait(1.2)
		if i == 0 and wi == 0 and not GameState.tutorial_done:
			await _tutorial_first_wave()
		else:
			await _spawn_wave(waves[wi], i)
			await _wait_until_clear()
		if wi < waves.size() - 1:
			await _wait(2.5)
	await _finish_area(i)


func _spawn_wave(groups: Array, area: int) -> void:
	var total: int = 0
	for g in groups:
		total += int(g[1])
	alive_enemies += total
	for g in groups:
		for k in range(int(g[1])):
			spawn_enemy(String(g[0]), _pick_spawn(area))
			await _wait(0.35)


func _tutorial_first_wave() -> void:
	tutorial_active = true
	hud.show_tip("WASD  -  bergerak")
	var has_moved: Callable = func(): return player.moved_total >= 5.0
	await _wait_cond(has_moved, 15.0)

	hud.show_tip("KLIK KIRI  -  serang dengan sabit (combo 3 pukulan). Bidik dengan mouse.")
	await _wait(1.0)
	alive_enemies += 1
	spawn_enemy("slime_lumut", _pick_spawn(0))
	var no_enemy: Callable = func(): return alive_enemies <= 0
	await _wait_cond(no_enemy, 5.0)
	if alive_enemies > 0:
		hud.show_tip("SPASI  -  Dash (kebal sesaat). Hindari serangan bergaris merah!")
		await _wait_until_clear()
	hud.hide_tip()

	# Raise pertama (dipaksa lewat skrip cerita)
	await _wait(0.6)
	player.locked = true
	await hud.say("Pip", "Tunggu, Mira! Jiwa monster itu belum pergi... Lihat, ada Soul Orb di sana!", Color(1.0, 0.95, 0.55))
	await hud.say("Mira", "Cahaya apa ini...? Tanganku terasa hangat.", Color(1.0, 0.7, 0.85))
	hud.close_dialog()
	await _unlock_player()
	player.can_raise = true
	hud.show_banner("Kemampuan baru: RAISE", Color(0.7, 0.85, 1.0), 2.8)
	hud.show_tip("Dekati Soul Orb, lalu tekan E untuk membangkitkannya")
	await raise_resolved
	hud.hide_tip()

	player.locked = true
	await _wait(0.8)
	await hud.say("Old Bram", "Soul Tether... kekuatan Gravekeeper pertama! Ia bangkit di dalam dirimu, Mira.", Color(0.85, 0.8, 0.6))
	await hud.say("Mira", "Dia... berdiri di sisiku?", Color(1.0, 0.7, 0.85))
	await hud.say("Pip", "Shade-mu akan ikut bertarung. Ayo bersihkan desa ini bersama-sama!", Color(1.0, 0.95, 0.55))
	hud.close_dialog()
	GameState.tutorial_done = true
	tutorial_active = false
	await _unlock_player()


func _finish_area(i: int) -> void:
	hud.show_banner("Area dibersihkan!", Color(0.7, 1.0, 0.8), 2.2)
	hud.clear_counter("Area bersih - gerbang terbuka!")
	player.heal(2)
	var gx: float = float(i) * AREA_SPACING + HW
	_open_gate_anim(i)
	if i == 0 and dev_sign != null:
		_reveal_dev_sign()
	_show_arrow(gx)
	pip.pointing = true
	pip.point_pos = Vector3(gx + 8.0, 0.0, 0.0)
	hud.show_tip("Ikuti cahaya Pip  >>>")
	var cross_x: float = gx + CORRIDOR_LEN + 3.0 if i < 2 else gx + 5.0
	var crossed: Callable = func(): return player.global_position.x >= cross_x
	await _wait_cond(crossed)
	pip.pointing = false
	hud.hide_tip()
	_hide_arrow()


func _stage_clear() -> void:
	player.locked = true
	hud.clear_counter("")
	hud.set_area(3, 3, "Desa Lumen aman")
	hud.show_banner("STAGE 1 SELESAI", Color(1.0, 0.88, 0.55), 2.6)
	await _wait(2.6)
	await hud.say("Pip", "Kita berhasil, Mira! Tapi Rift masih terbuka... Hutan Bisikan menunggu di depan.", Color(1.0, 0.95, 0.55))
	hud.close_dialog()
	await hud.show_upgrades(_pick_upgrades())
	GameState.stages_cleared = maxi(GameState.stages_cleared, 1)
	GameState.save_game()
	var stats: String = "Musuh dikalahkan: %d    Shade dibangkitkan: %d\nSoul Shard: %d    Jenis di Soul Bank: %d" % [total_kills, total_raised, GameState.shards, GameState.bank_order.size()]
	hud.show_stage_clear(stats)


func _pick_upgrades() -> Array:
	var pool: Array = UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)


func apply_upgrade(id: String) -> void:
	match id:
		"tether":
			GameState.tether_level += 1
		"limit":
			GameState.shade_limit = mini(6, GameState.shade_limit + 1)
		"scythe":
			GameState.attack_bonus += 2
		"essence":
			GameState.essence_bonus += 0.25
		"shield":
			GameState.shade_shield = true


# ================================================================== Musuh, Shade, Orb
func _pick_spawn(area: int) -> Vector3:
	var cx: float = float(area) * AREA_SPACING
	for attempt in range(25):
		var p := Vector3(cx + randf_range(1.0, 11.0), 0.0, randf_range(-4.5, 5.5))
		var ok: bool = true
		for f in fire_spots:
			if p.distance_to(f) < 2.4:
				ok = false
		for e in get_tree().get_nodes_in_group("enemies"):
			if p.distance_to(e.global_position) < 1.5:
				ok = false
		if player != null and p.distance_to(player.global_position) < 5.5:
			ok = false
		if ok:
			return p
	return Vector3(cx + 9.0, 0.0, 0.0)


func spawn_enemy(id: String, pos: Vector3) -> void:
	var e := Enemy.new()
	e.setup(enemy_db[id], self)
	world.add_child(e)
	e.global_position = Vector3(pos.x, 0.0, pos.z)
	_fx_ring(pos, Color(0.75, 0.3, 1.0, 0.85), 0.4, 1.9, 0.6)


func on_enemy_died(e) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	area_kills += 1
	total_kills += 1
	hud.set_counter(area_kills, area_total)
	player.add_essence(float(e.data.essence_reward))
	GameState.shards += int(e.data.shard_reward)
	var forced: bool = false
	if tutorial_active and not tutorial_orb_made:
		forced = true
		tutorial_orb_made = true
	_add_orb(e.data, e.global_position, forced)
	enemy_down.emit()


func _add_orb(data, pos: Vector3, forced: bool) -> void:
	if float(data.raise_chance) <= 0.0:
		return
	var o := SoulOrb.new()
	o.data = data
	o.forced = forced
	world.add_child(o)
	o.global_position = Vector3(pos.x, 0.0, pos.z)


func spawn_shade(data, pos: Vector3) -> void:
	var s := Shade.new()
	s.setup(data, self)
	world.add_child(s)
	s.global_position = Vector3(pos.x, 0.0, pos.z)
	_fx_ring(pos, Color(0.6, 0.5, 1.0, 0.85), 0.5, 2.4, 0.5)


func shade_count() -> int:
	return get_tree().get_nodes_in_group("shades").size()


func on_shade_died(shade) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	shade_cd[shade.data.id] = now + SHADE_RECALL_COOLDOWN
	Util.popup(world, shade.global_position + Vector3(0, 2.2, 0), "Kembali ke Soul Bank", Color(0.75, 0.7, 1.0), 34)


func try_summon(idx: int) -> void:
	var above: Vector3 = player.global_position + Vector3(0, 2.7, 0)
	if idx >= GameState.bank_order.size():
		Util.popup(world, above, "Slot Soul Bank kosong", Color(0.75, 0.75, 0.85))
		return
	var id: String = GameState.bank_order[idx]
	var data = enemy_db[id]
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if shade_cd.has(id) and float(shade_cd[id]) > now:
		Util.popup(world, above, "Belum siap...", Color(0.8, 0.8, 0.9))
		return
	if shade_count() >= GameState.shade_limit:
		Util.popup(world, above, "Pasukan penuh!", Color(1.0, 0.7, 0.4))
		return
	if player.essence < float(data.raise_cost):
		Util.popup(world, above, "Soul Essence kurang", Color(1.0, 0.5, 0.5))
		return
	player.essence -= float(data.raise_cost)
	var p: Vector3 = player.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(1.0, 2.0))
	spawn_shade(data, p)
	Util.popup(world, above, "Dipanggil: %s" % data.display_name, Color(0.7, 0.85, 1.0), 38)


func _on_player_raised(success: bool, _data) -> void:
	if success:
		total_raised += 1
	raise_resolved.emit()


func _on_player_died() -> void:
	GameState.restart_area = current_area
	hud.show_banner("Mira gugur...", Color(1.0, 0.4, 0.5), 2.0)
	await _wait(1.6)
	hud.show_game_over()


func retry_area() -> void:
	GameState.restart_area = current_area
	get_tree().reload_current_scene()


func replay_stage() -> void:
	GameState.new_game()
	get_tree().reload_current_scene()


func go_title() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ================================================================== Efek
func _fx_ring(pos: Vector3, color: Color, from_r: float, to_r: float, time: float) -> void:
	var d := Util.disk(world, 1.0, color, true, 0.06)
	d.global_position = Vector3(pos.x, 0.06, pos.z)
	d.scale = Vector3(from_r, 1.0, from_r)
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "scale", Vector3(to_r, 1.0, to_r), time)
	tw.tween_property(d.material_override, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(d.queue_free)


func fx_raise_cast(pos: Vector3) -> void:
	_fx_ring(pos, Color(0.5, 0.6, 1.0, 0.9), 0.5, 3.2, 0.55)
	var col := Util.cyl_mesh(world, 0.7, 0.7, 5.0, Vector3(pos.x, 2.5, pos.z), Color.WHITE)
	var m := Util.mat(Color(0.55, 0.5, 1.0, 0.55), true, true, true)
	col.material_override = m
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := col.create_tween()
	tw.set_parallel(true)
	tw.tween_property(col, "scale", Vector3(0.15, 1.0, 0.15), 0.55)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(col.queue_free)


func fx_raise_fail(pos: Vector3) -> void:
	_fx_ring(pos, Color(1.0, 0.25, 0.35, 0.9), 0.4, 2.4, 0.5)


func _show_arrow(gate_x: float) -> void:
	_hide_arrow()
	_arrow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.55
	cm.height = 1.4
	_arrow.mesh = cm
	_arrow.material_override = Util.mat(Color(1.0, 0.85, 0.35), true, false, true)
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	level.add_child(_arrow)
	_arrow_x = gate_x - 1.0
	_arrow.position = Vector3(_arrow_x, 3.2, 0.0)


func _hide_arrow() -> void:
	if _arrow != null:
		_arrow.queue_free()
		_arrow = null


func _open_gate_anim(i: int) -> void:
	var g: Dictionary = gates[i]
	if is_instance_valid(g["body"]):
		g["body"].queue_free()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(g["pivot"], "rotation:z", -PI * 0.5, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(g["mist"].material_override, "albedo_color:a", 0.0, 0.8)
	tw.chain().tween_callback(g["mist"].queue_free)
