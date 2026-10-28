extends Node
## Autoload "GameState": menyimpan progres antar-stage (Soul Bank, upgrade,
## Soul Shard) dan mendaftarkan semua tombol input lewat kode.

const SAVE_PATH := "user://gravebound_save.json"

# --- Progres run ---
var soul_bank: Dictionary = {}      # id musuh -> jumlah yang pernah berhasil di-Raise
var bank_order: Array = []          # urutan id agar bisa dipanggil lewat tombol 1, 2, ...
var shards: int = 0
var tether_level: int = 1           # tiap level: peluang Raise +5%
var shade_limit: int = 3
var attack_bonus: int = 0
var essence_bonus: float = 0.0      # 0.25 = isi Essence 25% lebih cepat
var shade_shield: bool = false
var stages_cleared: int = 0
var mira_fallen: bool = false       # disiapkan untuk update cerita berikutnya

# --- Status sesi (tidak disimpan) ---
var restart_area: int = 0
var intro_done: bool = false
var tutorial_done: bool = false


func _ready() -> void:
	_register_inputs()


func new_game() -> void:
	soul_bank = {}
	bank_order = []
	shards = 0
	tether_level = 1
	shade_limit = 3
	attack_bonus = 0
	essence_bonus = 0.0
	shade_shield = false
	stages_cleared = 0
	mira_fallen = false
	restart_area = 0
	intro_done = false
	tutorial_done = false


func bank_add(id: String) -> void:
	if soul_bank.has(id):
		soul_bank[id] = int(soul_bank[id]) + 1
	else:
		soul_bank[id] = 1
		bank_order.append(id)


func save_game() -> void:
	var data := {
		"soul_bank": soul_bank,
		"bank_order": bank_order,
		"shards": shards,
		"tether_level": tether_level,
		"shade_limit": shade_limit,
		"attack_bonus": attack_bonus,
		"essence_bonus": essence_bonus,
		"shade_shield": shade_shield,
		"stages_cleared": stages_cleared,
		"mira_fallen": mira_fallen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal menyimpan: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> void:
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	soul_bank = parsed.get("soul_bank", {})
	bank_order = parsed.get("bank_order", [])
	shards = int(parsed.get("shards", 0))
	tether_level = int(parsed.get("tether_level", 1))
	shade_limit = int(parsed.get("shade_limit", 3))
	attack_bonus = int(parsed.get("attack_bonus", 0))
	essence_bonus = float(parsed.get("essence_bonus", 0.0))
	shade_shield = bool(parsed.get("shade_shield", false))
	stages_cleared = int(parsed.get("stages_cleared", 0))
	mira_fallen = bool(parsed.get("mira_fallen", false))


# ------------------------------------------------------------------ Input
func _register_inputs() -> void:
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("move_up", KEY_W)
	_key("move_up", KEY_UP)
	_key("move_down", KEY_S)
	_key("move_down", KEY_DOWN)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_key("attack", KEY_J)
	_key("dash", KEY_SPACE)
	_key("dash", KEY_K)
	_key("raise", KEY_E)
	_key("interact", KEY_E)
	_key("command", KEY_Q)
	_key("soul_link", KEY_R)
	_key("surge", KEY_F)
	_key("summon_1", KEY_1)
	_key("summon_2", KEY_2)
	_key("summon_3", KEY_3)
	_key("advance", KEY_ENTER)
	_key("advance", KEY_KP_ENTER)
	_key("advance", KEY_SPACE)
	_key("advance", KEY_E)
	_key("pause", KEY_ESCAPE)
	_key("toggle_tiltshift", KEY_T)


func _key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
