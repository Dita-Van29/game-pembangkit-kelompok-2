extends Node3D
## Layar judul. Scene ini berisi seluruh level + karakter sebagai latar 3D
## (terlihat di editor 3D sebelum game dijalankan), dengan menu 2D di depannya.

var _pip: TextureRect
var _t: float = 0.0
var _controls_panel: PanelContainer
var _cam: Camera3D
var _cam_base: Vector3 = Vector3.ZERO


func _ready() -> void:
	_cam = get_node_or_null("Camera3D") as Camera3D
	if _cam != null:
		_cam_base = _cam.global_position

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Redupkan latar 3D + cahaya ungu lembut di belakang judul
	var glow := ColorRect.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5, 0.42));\n\tfloat a = 0.55 + smoothstep(0.0, 0.7, d) * 0.3;\n\tCOLOR = vec4(mix(vec3(0.18, 0.1, 0.35), vec3(0.02, 0.01, 0.06), smoothstep(0.0, 0.6, d)), a * 0.75);\n}\n"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	glow.material = sm
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	_pip = TextureRect.new()
	_pip.texture = Util.load_tex("res://assets/sprites/pip.png")
	_pip.custom_minimum_size = Vector2(96, 96)
	_pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(_pip)

	v.add_child(_label("GRAVEBOUND", 72, Color(0.95, 0.85, 1.0)))
	v.add_child(_label("Legion of the Fallen", 30, Color(0.75, 0.6, 1.0)))
	v.add_child(_label("Stage 1  -  Desa Lumen", 20, Color(1.0, 0.85, 0.55)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap)

	var b1 := _button("Mulai Stage 1")
	b1.pressed.connect(_on_start)
	v.add_child(b1)
	var b2 := _button("Kontrol")
	b2.pressed.connect(_on_controls)
	v.add_child(b2)
	var b3 := _button("Keluar")
	b3.pressed.connect(_on_quit)
	v.add_child(b3)

	_controls_panel = PanelContainer.new()
	_controls_panel.visible = false
	var cl := _label("WASD / Panah  -  Bergerak\nKlik kiri / J  -  Serang sabit (combo 3 pukulan, bidik dengan mouse)\nSpasi / K  -  Dash Bayangan (kebal sesaat)\nE  -  Raise (bangkitkan Soul Orb)\n1 / 2 / 3  -  Panggil Shade dari Soul Bank\nT  -  Tilt-shift on/off     Esc  -  Jeda", 18, Color(0.9, 0.9, 1.0))
	_controls_panel.add_child(cl)
	v.add_child(_controls_panel)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 50)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _process(delta: float) -> void:
	_t += delta
	if _pip != null:
		_pip.modulate = Color(1, 1, 1, 0.85 + sin(_t * 3.0) * 0.15)
		_pip.pivot_offset = _pip.size * 0.5
		_pip.rotation = sin(_t * 1.6) * 0.08
	if _cam != null:
		_cam.global_position = _cam_base + Vector3(sin(_t * 0.25) * 2.5, 0.0, 0.0)


func _on_start() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/Stage1.tscn")


func _on_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_quit() -> void:
	get_tree().quit()
