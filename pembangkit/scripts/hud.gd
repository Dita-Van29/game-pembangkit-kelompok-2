extends CanvasLayer
## HUD lengkap yang dibangun lewat kode: portrait, hati HP, bar Soul Essence,
## penghitung musuh, slot Shade, bar skill, Soul Bank, dialog, banner,
## layar upgrade, game over, pause, dan stage clear.

signal _advance
signal upgrade_finished
signal _board_closed

## Identitas tim pengembang (urutan sama dengan posisi karakter di gambar, kiri -> kanan)
const DEV_TEAM := [
	{"name": "Ivan Pramudita Hanggara", "nim": "240533601485"},
	{"name": "Gilang Eka Saputra", "nim": "240533604298"},
	{"name": "Hafidz Qandis Fitrarobi", "nim": "240533600789"},
]
const DEV_IMAGE := "res://assets/sprites/dev_team.jpg"
const DEV_IMG_SIZE := Vector2(640, 430)

const UPGRADE_COST := 12

var player = null
var stage = null

var _root_margin: MarginContainer
var _hearts: Array = []
var _portrait: TextureRect
var _tex_portrait: Dictionary = {}
var _tex_heart: Dictionary = {}
var _ess_bar: ProgressBar
var _ess_label: Label
var _shard_label: Label
var _area_label: Label
var _counter_label: Label
var _wave_label: Label
var _tip_panel: PanelContainer
var _tip_label: Label
var _banner: Label
var _banner_tw: Tween
var _dialog_panel: PanelContainer
var _dlg_name: Label
var _dlg_text: Label
var _type_tween: Tween
var _typing: bool = false
var _dialog_open: bool = false
var _shade_slots: Array = []
var _skill_slots: Array = []
var _bank_label: Label
var _icon_cache: Dictionary = {}
var _blocking: bool = false

var _ov_gameover: Control
var _ov_pause: Control
var _ov_upgrade: Control
var _ov_clear: Control
var _ov_board: Control
var _up_options: Array = []
var _up_taken: Array = []
var _up_free_used: bool = false
var _up_buttons: Array = []
var _up_shard_label: Label
var _up_continue: Button
var _clear_stats: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	for e in ["normal", "hurt", "angry"]:
		_tex_portrait[e] = Util.load_tex("res://assets/sprites/portrait_mira_%s.png" % e)
	for k in ["full", "half", "empty"]:
		_tex_heart[k] = Util.load_tex("res://assets/sprites/heart_%s.png" % k)
	_build()


# ------------------------------------------------------------------ Helper UI
func _label(text: String, size: int = 18, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _style(bg: Color, border: Color, margin: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	return sb


func _panel(bg: Color = Color(0.07, 0.04, 0.13, 0.82), border: Color = Color(0.45, 0.35, 0.75, 1.0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(bg, border))
	return p


func _tex_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


func _fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ------------------------------------------------------------------ Build
func _build() -> void:
	# Vinyet ringan
	var vignette := ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.0, 0.9));\n\tCOLOR = vec4(0.02, 0.0, 0.06, smoothstep(0.38, 0.85, d) * 0.6);\n}\n"
	var shm := ShaderMaterial.new()
	shm.shader = sh
	vignette.material = shm
	add_child(vignette)
	_fill(vignette)

	_root_margin = MarginContainer.new()
	_root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_root_margin.add_theme_constant_override("margin_" + side, 14)
	add_child(_root_margin)
	_fill(_root_margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_margin.add_child(col)

	# ---------------- Baris atas
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)

	var left_panel := _panel()
	top.add_child(left_panel)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	left_panel.add_child(lrow)
	_portrait = _tex_rect(_tex_portrait["normal"], Vector2(88, 88))
	lrow.add_child(_portrait)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 4)
	lrow.add_child(lcol)
	lcol.add_child(_label("Mira", 20, Color(1.0, 0.7, 0.85)))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 2)
	lcol.add_child(hrow)
	for i in range(5):
		var h := _tex_rect(_tex_heart["full"], Vector2(30, 30))
		hrow.add_child(h)
		_hearts.append(h)
	_ess_bar = ProgressBar.new()
	_ess_bar.custom_minimum_size = Vector2(190, 16)
	_ess_bar.show_percentage = false
	_ess_bar.max_value = 100.0
	_ess_bar.add_theme_stylebox_override("background", _style(Color(0.1, 0.06, 0.18, 1), Color(0.3, 0.25, 0.5), 0.0))
	_ess_bar.add_theme_stylebox_override("fill", _style(Color(0.62, 0.38, 1.0, 1), Color(0.8, 0.6, 1.0), 0.0))
	lcol.add_child(_ess_bar)
	_ess_label = _label("Soul Essence 0/100", 14, Color(0.8, 0.7, 1.0))
	lcol.add_child(_ess_label)

	var center := VBoxContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(center)
	_area_label = _label("", 22, Color(1.0, 0.85, 0.55))
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_area_label)
	_counter_label = _label("", 20, Color(1, 1, 1))
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_counter_label)
	_wave_label = _label("", 15, Color(0.75, 0.75, 0.9))
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_wave_label)
	var tip_wrap := CenterContainer.new()
	tip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(tip_wrap)
	_tip_panel = _panel(Color(0.12, 0.08, 0.2, 0.9), Color(1.0, 0.85, 0.5))
	_tip_panel.visible = false
	tip_wrap.add_child(_tip_panel)
	_tip_label = _label("", 18, Color(1.0, 0.95, 0.75))
	_tip_panel.add_child(_tip_label)

	var right_panel := _panel()
	right_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(right_panel)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	right_panel.add_child(rrow)
	rrow.add_child(_tex_rect(Util.load_tex("res://assets/sprites/shard.png"), Vector2(26, 26)))
	_shard_label = _label("0", 22, Color(0.6, 0.95, 1.0))
	rrow.add_child(_shard_label)

	# ---------------- Spacer
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	# ---------------- Dialog
	var dwrap := CenterContainer.new()
	dwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(dwrap)
	_dialog_panel = _panel(Color(0.06, 0.03, 0.12, 0.94), Color(0.85, 0.7, 1.0))
	_dialog_panel.custom_minimum_size = Vector2(880, 0)
	_dialog_panel.visible = false
	dwrap.add_child(_dialog_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	_dialog_panel.add_child(dv)
	_dlg_name = _label("", 22, Color(1.0, 0.85, 0.6))
	dv.add_child(_dlg_name)
	_dlg_text = _label("", 20, Color.WHITE)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(840, 60)
	dv.add_child(_dlg_text)
	var hint := _label("[Klik / Enter / Spasi] lanjut", 14, Color(0.7, 0.7, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(hint)

	# ---------------- Baris bawah
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)

	var shade_panel := _panel()
	shade_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	shade_panel.custom_minimum_size = Vector2(330, 0)
	bottom.add_child(shade_panel)
	var sv := VBoxContainer.new()
	shade_panel.add_child(sv)
	sv.add_child(_label("Pasukan Shade", 14, Color(0.7, 0.75, 1.0)))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	sv.add_child(srow)
	for i in range(6):
		var slot := _make_shade_slot()
		srow.add_child(slot["root"])
		_shade_slots.append(slot)

	var mid_spacer := Control.new()
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(mid_spacer)

	var skill_panel := _panel()
	skill_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(skill_panel)
	var krow := HBoxContainer.new()
	krow.add_theme_constant_override("separation", 6)
	skill_panel.add_child(krow)
	var defs := [
		["KLIK", "Sabit", ""],
		["SPASI", "Dash", ""],
		["E", "Raise", "Stage 1"],
		["Q", "Command", "Stage 2"],
		["R", "Soul Link", "Stage 3"],
		["F", "Surge", "Stage 4"],
	]
	for d in defs:
		var s := _make_skill_slot(d[0], d[1], d[2])
		krow.add_child(s["root"])
		_skill_slots.append(s)

	var mid_spacer2 := Control.new()
	mid_spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(mid_spacer2)

	var bank_panel := _panel()
	bank_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bank_panel.custom_minimum_size = Vector2(330, 0)
	bottom.add_child(bank_panel)
	_bank_label = _label("", 15, Color(0.85, 0.9, 1.0))
	bank_panel.add_child(_bank_label)

	# ---------------- Banner tengah
	var bwrap := CenterContainer.new()
	bwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bwrap)
	_fill(bwrap)
	_banner = _label("", 44, Color.WHITE)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	bwrap.add_child(_banner)

	_build_overlays()


func _make_shade_slot() -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(60, 76)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _style(Color(0.1, 0.08, 0.2, 0.9), Color(0.4, 0.35, 0.7), 0.0))
	root.add_child(bg)
	_fill(bg)
	var icon := _tex_rect(null, Vector2(52, 48))
	root.add_child(icon)
	icon.position = Vector2(4, 4)
	icon.size = Vector2(52, 48)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(50, 6)
	bar.size = Vector2(50, 6)
	bar.position = Vector2(5, 56)
	bar.add_theme_stylebox_override("background", _style(Color(0.1, 0.05, 0.1, 1), Color(0, 0, 0, 0), 0.0))
	bar.add_theme_stylebox_override("fill", _style(Color(0.4, 0.9, 0.6, 1), Color(0, 0, 0, 0), 0.0))
	root.add_child(bar)
	var role := _label("", 12, Color(0.8, 0.85, 1.0))
	root.add_child(role)
	role.position = Vector2(4, 58)
	return {"root": root, "icon": icon, "bar": bar, "role": role}


func _make_skill_slot(key: String, skill_name: String, lock_text: String) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(76, 70)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.2, 0.92), Color(0.55, 0.45, 0.85), 0.0))
	root.add_child(bg)
	_fill(bg)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	_fill(vb)
	var kl := _label(key, 18, Color(1.0, 0.9, 0.5))
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(kl)
	var nl := _label(skill_name, 13, Color(0.9, 0.9, 1.0))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var ll := _label("", 11, Color(1.0, 0.6, 0.6))
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ll)
	var cd := ColorRect.new()
	cd.color = Color(0, 0, 0, 0.6)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cd)
	cd.anchor_left = 0.0
	cd.anchor_right = 1.0
	cd.anchor_bottom = 1.0
	cd.anchor_top = 1.0
	cd.offset_left = 0.0
	cd.offset_right = 0.0
	cd.offset_top = 0.0
	cd.offset_bottom = 0.0
	return {"root": root, "cd": cd, "lock_label": ll, "lock_text": lock_text}


func _build_overlays() -> void:
	# Game over
	_ov_gameover = _make_overlay()
	var gv := _overlay_box(_ov_gameover, Color(0.7, 0.2, 0.3))
	gv.add_child(_label("MIRA GUGUR", 48, Color(1.0, 0.4, 0.5)))
	gv.add_child(_label("Soul Bank-mu tetap tersimpan.", 18, Color(0.85, 0.85, 1.0)))
	var b1 := _button("Ulangi dari awal area")
	b1.pressed.connect(_on_retry)
	gv.add_child(b1)
	var b2 := _button("Menu Utama")
	b2.pressed.connect(_on_menu)
	gv.add_child(b2)

	# Pause
	_ov_pause = _make_overlay()
	var pv := _overlay_box(_ov_pause, Color(0.5, 0.4, 0.8))
	pv.add_child(_label("JEDA", 40, Color.WHITE))
	pv.add_child(_label("WASD gerak  |  Klik kiri serang  |  Spasi dash  |  E Raise\n1 / 2 / 3 panggil Shade dari Soul Bank  |  T tilt-shift  |  Esc jeda", 16, Color(0.8, 0.8, 0.95)))
	var b3 := _button("Lanjutkan")
	b3.pressed.connect(_toggle_pause)
	pv.add_child(b3)
	var b4 := _button("Menu Utama")
	b4.pressed.connect(_on_menu)
	pv.add_child(b4)

	# Papan Developer
	_build_dev_board()

	# Upgrade
	_ov_upgrade = _make_overlay()

	# Stage clear
	_ov_clear = _make_overlay()
	var cv := _overlay_box(_ov_clear, Color(1.0, 0.85, 0.5))
	cv.add_child(_label("STAGE 1 SELESAI", 46, Color(1.0, 0.88, 0.55)))
	cv.add_child(_label("Desa Lumen selamat... untuk sementara.", 18, Color(0.85, 0.85, 1.0)))
	_clear_stats = _label("", 18, Color(0.8, 0.95, 1.0))
	cv.add_child(_clear_stats)
	cv.add_child(_label("Stage 2: Hutan Bisikan - segera hadir", 20, Color(0.7, 1.0, 0.7)))
	var b5 := _button("Main lagi dari awal")
	b5.pressed.connect(_on_replay)
	cv.add_child(b5)
	var b6 := _button("Menu Utama")
	b6.pressed.connect(_on_menu)
	cv.add_child(b6)


func _build_dev_board() -> void:
	_ov_board = _make_overlay()
	var v := _overlay_box(_ov_board, Color(1.0, 0.85, 0.5))
	v.add_theme_constant_override("separation", 8)
	var title := _label("TIM PENGEMBANG", 30, Color(1.0, 0.88, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("Gravebound: Legion of the Fallen", 16, Color(0.8, 0.85, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_tex_rect(Util.load_tex(DEV_IMAGE), DEV_IMG_SIZE))

	# Tiga kolom sama lebar, sejajar dengan tiga karakter di gambar
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	v.add_child(row)
	for d in DEV_TEAM:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(DEV_IMG_SIZE.x / 3.0, 0.0)
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var n := _label(String(d["name"]), 16, Color(1.0, 0.95, 0.8))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(n)
		var nim := _label("NIM " + String(d["nim"]), 15, Color(0.7, 0.9, 1.0))
		nim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nim)

	var close := _button("Tutup  [E / Esc]")
	close.custom_minimum_size = Vector2(260, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close_dev_board)
	v.add_child(close)


## Tampilkan papan identitas developer; selesai saat pemain menutupnya.
func show_dev_board() -> void:
	_ov_board.visible = true
	await _board_closed


func _close_dev_board() -> void:
	if _ov_board.visible:
		_ov_board.visible = false
		_board_closed.emit()


func _make_overlay() -> Control:
	var ov := ColorRect.new()
	ov.color = Color(0.02, 0.0, 0.05, 0.78)
	ov.visible = false
	add_child(ov)
	_fill(ov)
	return ov


func _overlay_box(ov: Control, border: Color) -> VBoxContainer:
	var cc := CenterContainer.new()
	ov.add_child(cc)
	_fill(cc)
	var p := _panel(Color(0.07, 0.04, 0.13, 0.96), border)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	return v


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_font_size_override("font_size", 20)
	return b


# ------------------------------------------------------------------ Update
func _process(_delta: float) -> void:
	if player == null:
		return
	# Hati
	for i in range(_hearts.size()):
		var v: int = player.hp - i * 2
		var key: String = "full" if v >= 2 else ("half" if v == 1 else "empty")
		_hearts[i].texture = _tex_heart[key]
	# Portrait
	var expr: String = "normal"
	if player.state == Player.State.ATTACK:
		expr = "angry"
	elif player.hp <= 4:
		expr = "hurt"
	_portrait.texture = _tex_portrait[expr]
	# Essence
	_ess_bar.value = player.essence
	_ess_label.text = "Soul Essence %d/%d" % [int(player.essence), int(player.MAX_ESSENCE)]
	_shard_label.text = str(GameState.shards)

	_update_skills()
	_update_shades()
	_update_bank()


func _set_cd(slot: Dictionary, frac: float) -> void:
	var cd: ColorRect = slot["cd"]
	cd.anchor_top = 1.0 - clampf(frac, 0.0, 1.0)
	cd.offset_top = 0.0
	cd.offset_bottom = 0.0


func _update_skills() -> void:
	_set_cd(_skill_slots[0], 0.0)
	_set_cd(_skill_slots[1], player.dash_cd / 1.2)
	var raise_slot: Dictionary = _skill_slots[2]
	var unlocked: bool = player.can_raise
	raise_slot["root"].modulate = Color(1, 1, 1, 1) if unlocked else Color(0.5, 0.5, 0.55, 1)
	raise_slot["lock_label"].text = "" if unlocked else "terkunci"
	_set_cd(raise_slot, 0.0 if (unlocked and player.essence >= 10.0) else (0.0 if not unlocked else 0.45))
	for i in range(3, 6):
		var s: Dictionary = _skill_slots[i]
		s["root"].modulate = Color(0.45, 0.45, 0.5, 1)
		s["lock_label"].text = s["lock_text"]
		_set_cd(s, 0.0)


func _update_shades() -> void:
	var shades: Array = get_tree().get_nodes_in_group("shades")
	for i in range(_shade_slots.size()):
		var s: Dictionary = _shade_slots[i]
		var root: Control = s["root"]
		root.visible = i < GameState.shade_limit
		if not root.visible:
			continue
		if i < shades.size():
			var sh = shades[i]
			var path: String = sh.data.sprite_path
			if not _icon_cache.has(path):
				_icon_cache[path] = Util.load_tex(path)
			s["icon"].texture = _icon_cache[path]
			s["icon"].modulate = Color(0.7, 0.75, 1.4, 1.0)
			s["bar"].max_value = float(sh.max_hp)
			s["bar"].value = float(sh.hp)
			s["bar"].visible = true
			var r: String = sh.role
			s["role"].text = r.substr(0, 1).to_upper() + r.substr(1, 5)
		else:
			s["icon"].texture = null
			s["bar"].visible = false
			s["role"].text = "kosong"


func _update_bank() -> void:
	var lines: Array = ["Soul Bank  (tekan angka)"]
	if GameState.bank_order.is_empty():
		lines.append("(kosong - bangkitkan musuh dengan E)")
	else:
		var now: float = float(Time.get_ticks_msec()) / 1000.0
		for i in range(GameState.bank_order.size()):
			var id: String = GameState.bank_order[i]
			var nm: String = id
			var cost: int = 10
			if stage != null and stage.enemy_db.has(id):
				nm = stage.enemy_db[id].display_name
				cost = int(stage.enemy_db[id].raise_cost)
			var cdl: float = 0.0
			if stage != null and stage.shade_cd.has(id):
				cdl = maxf(0.0, float(stage.shade_cd[id]) - now)
			var extra: String = ""
			if cdl > 0.0:
				extra = "  (%.1fd)" % cdl
			lines.append("[%d] %s x%d  -%d%s" % [i + 1, nm, int(GameState.soul_bank[id]), cost, extra])
	_bank_label.text = "\n".join(lines)


# ------------------------------------------------------------------ API publik
func set_area(index: int, total: int, area_name: String) -> void:
	_area_label.text = "AREA %d/%d  -  %s" % [index, total, area_name]


func set_counter(done: int, total: int) -> void:
	_counter_label.text = "Bersihkan monster di area ini (%d/%d)" % [done, total]


func set_wave(w: int, total: int) -> void:
	_wave_label.text = "Gelombang %d/%d" % [w, total]


func clear_counter(msg: String) -> void:
	_counter_label.text = msg
	_wave_label.text = ""


func show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_panel.visible = true


func hide_tip() -> void:
	_tip_panel.visible = false


func show_banner(text: String, color: Color = Color.WHITE, seconds: float = 2.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tw.tween_interval(seconds)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


# --- Dialog ---
func say(speaker: String, text: String, color: Color = Color(1.0, 0.88, 0.65)) -> void:
	_dialog_open = true
	_dlg_name.text = speaker
	_dlg_name.add_theme_color_override("font_color", color)
	_dlg_text.text = text
	_dlg_text.visible_ratio = 0.0
	_dialog_panel.visible = true
	_typing = true
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_dlg_text, "visible_ratio", 1.0, maxf(0.3, float(text.length()) * 0.02))
	_type_tween.tween_callback(_on_typing_done)
	await _advance


func close_dialog() -> void:
	_dialog_open = false
	_dialog_panel.visible = false


func _on_typing_done() -> void:
	_typing = false


func _input(event: InputEvent) -> void:
	if _ov_board.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("advance") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close_dev_board()
		return
	if _dialog_open:
		var mb := event as InputEventMouseButton
		var clicked: bool = mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		if event.is_action_pressed("advance") or clicked:
			get_viewport().set_input_as_handled()
			if _typing:
				if _type_tween != null and _type_tween.is_valid():
					_type_tween.kill()
				_dlg_text.visible_ratio = 1.0
				_typing = false
			else:
				_advance.emit()
		return
	if event.is_action_pressed("pause") and not _blocking_overlay_open():
		_toggle_pause()


func _blocking_overlay_open() -> bool:
	return _ov_gameover.visible or _ov_upgrade.visible or _ov_clear.visible or _ov_board.visible


func _toggle_pause() -> void:
	_ov_pause.visible = not _ov_pause.visible
	get_tree().paused = _ov_pause.visible


# --- Game over / clear ---
func show_game_over() -> void:
	_ov_gameover.visible = true
	get_tree().paused = true


func show_stage_clear(stats: String) -> void:
	_clear_stats.text = stats
	_ov_clear.visible = true


func _on_retry() -> void:
	get_tree().paused = false
	stage.retry_area()


func _on_replay() -> void:
	get_tree().paused = false
	stage.replay_stage()


func _on_menu() -> void:
	get_tree().paused = false
	stage.go_title()


# --- Upgrade ---
func show_upgrades(options: Array) -> void:
	_up_options = options
	_up_taken = []
	_up_free_used = false
	_up_buttons = []
	for c in _ov_upgrade.get_children():
		c.queue_free()

	var cc := CenterContainer.new()
	_ov_upgrade.add_child(cc)
	_fill(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var title := _label("PILIH UPGRADE", 40, Color(1.0, 0.88, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := _label("Pilih 1 gratis. Sisanya bisa dibeli dengan Soul Shard.", 18, Color(0.85, 0.85, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_up_shard_label = _label("", 20, Color(0.6, 0.95, 1.0))
	_up_shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_up_shard_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var card := _panel(Color(0.09, 0.05, 0.17, 0.98), Color(0.7, 0.55, 1.0))
		row.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		var t := _label(String(opt["title"]), 22, Color(1.0, 0.9, 0.6))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(240, 0)
		cv.add_child(t)
		var d := _label(String(opt["desc"]), 16, Color(0.85, 0.9, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(240, 90)
		cv.add_child(d)
		var b := _button("")
		b.custom_minimum_size = Vector2(240, 44)
		b.pressed.connect(_on_upgrade_pick.bind(i))
		cv.add_child(b)
		_up_buttons.append(b)

	_up_continue = _button("Lanjut")
	_up_continue.disabled = true
	_up_continue.pressed.connect(_on_upgrade_continue)
	var cwrap := CenterContainer.new()
	cwrap.add_child(_up_continue)
	v.add_child(cwrap)

	_refresh_upgrade_cards()
	_ov_upgrade.visible = true
	get_tree().paused = true
	await upgrade_finished


func _refresh_upgrade_cards() -> void:
	_up_shard_label.text = "Soul Shard: %d" % GameState.shards
	for i in range(_up_buttons.size()):
		var b: Button = _up_buttons[i]
		if _up_taken.has(i):
			b.text = "Dimiliki"
			b.disabled = true
		elif not _up_free_used:
			b.text = "Pilih (gratis)"
			b.disabled = false
		else:
			b.text = "Beli (%d Shard)" % UPGRADE_COST
			b.disabled = GameState.shards < UPGRADE_COST
	_up_continue.disabled = not _up_free_used


func _on_upgrade_pick(i: int) -> void:
	if _up_taken.has(i):
		return
	if _up_free_used:
		if GameState.shards < UPGRADE_COST:
			return
		GameState.shards -= UPGRADE_COST
	else:
		_up_free_used = true
	_up_taken.append(i)
	stage.apply_upgrade(String(_up_options[i]["id"]))
	_refresh_upgrade_cards()


func _on_upgrade_continue() -> void:
	_ov_upgrade.visible = false
	get_tree().paused = false
	upgrade_finished.emit()
