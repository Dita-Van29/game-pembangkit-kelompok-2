extends Node3D
## Papan Developer: muncul setelah Area 1 selesai (dekat gerbang). Dekati papan,
## tekan E untuk membuka papan identitas tim pengembang (ditampilkan oleh HUD).

signal interacted

var enabled: bool = false
var _near: bool = false
var _player = null
var _t: float = 0.0
var _prompt: Label3D
var _zone: Area3D
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("dev_sign")
	_prompt = get_node_or_null("Prompt") as Label3D
	_zone = get_node_or_null("Zone") as Area3D
	_shape = get_node_or_null("Body/Shape") as CollisionShape3D
	if Engine.is_editor_hint():
		return
	if _zone != null:
		_zone.body_entered.connect(_on_enter)
		_zone.body_exited.connect(_on_exit)
	# Papan selalu terlihat (editor, Workspace). Stage1 yang menyembunyikannya sampai Area 1 selesai.


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if _shape != null:
		_shape.set_deferred("disabled", not on)
	if _zone != null:
		_zone.set_deferred("monitoring", on)
	if not on:
		_near = false
	_refresh_prompt()


## Munculkan papan dengan animasi "pop".
func reveal() -> void:
	set_enabled(true)
	scale = Vector3(0.01, 0.01, 0.01)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## true bila papan aktif dan Mira berdiri di dekatnya (E dipakai untuk membaca, bukan Raise).
func can_interact() -> bool:
	return enabled and _near


func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body
		_near = true
		_refresh_prompt()


func _on_exit(body: Node) -> void:
	if body.is_in_group("player"):
		_near = false
		_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt != null:
		_prompt.visible = enabled and _near


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	_t += delta
	if _prompt != null and _prompt.visible:
		_prompt.position.y = 3.5 + sin(_t * 3.0) * 0.08
	if _near and _player != null and not _player.locked and Input.is_action_just_pressed("interact"):
		interacted.emit()
