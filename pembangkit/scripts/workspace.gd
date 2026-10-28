extends Node3D
## Workspace: etalase semua aset (karakter, musuh, bangunan, prop, dan level Stage 1).
## Buka scenes/Workspace.tscn di editor untuk melihatnya di viewport 3D,
## atau tekan F6 untuk menjalankannya dengan kamera bebas.
##
## Kontrol kamera: W/A/S/D gerak, Q/E turun/naik, Shift cepat,
## tahan klik kanan + gerakkan mouse untuk menengok, roda mouse = maju/mundur.

var _cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _look: bool = false


func _ready() -> void:
	_cam = $Camera3D
	_yaw = _cam.rotation.y
	_pitch = _cam.rotation.x


func _process(delta: float) -> void:
	var dir: Vector3 = Vector3.ZERO
	var b: Basis = _cam.global_transform.basis
	if Input.is_key_pressed(KEY_W):
		dir -= b.z
	if Input.is_key_pressed(KEY_S):
		dir += b.z
	if Input.is_key_pressed(KEY_A):
		dir -= b.x
	if Input.is_key_pressed(KEY_D):
		dir += b.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	var speed: float = 28.0 if Input.is_key_pressed(KEY_SHIFT) else 12.0
	if dir.length() > 0.0:
		_cam.global_position += dir.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_look = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look else Input.MOUSE_MODE_VISIBLE
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.global_position -= _cam.global_transform.basis.z * 2.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.global_position += _cam.global_transform.basis.z * 2.0
	var mm := event as InputEventMouseMotion
	if mm != null and _look:
		_yaw -= mm.relative.x * 0.003
		_pitch = clampf(_pitch - mm.relative.y * 0.003, -1.5, 1.5)
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)
