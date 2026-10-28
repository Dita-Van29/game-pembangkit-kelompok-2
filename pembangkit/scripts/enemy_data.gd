@tool
class_name EnemyData
extends Resource
## Data satu jenis musuh. Untuk menambah musuh baru cukup duplikat salah satu
## file .tres di res://data/enemies/ lalu ubah angkanya, dan daftarkan id-nya
## di ENEMY_IDS pada scripts/stage_1.gd.

@export var id: String = "musuh"
@export var display_name: String = "Musuh"
@export var tier: String = "biasa"          # biasa / elite / miniboss / boss
@export var role: String = "striker"        # tank / striker / ranged / support

# --- Sebagai musuh ---
@export var max_hp: int = 20
@export var speed: float = 3.0
@export var damage: int = 1                 # 1 = setengah hati
@export var trigger_range: float = 2.0      # jarak mulai menyerang
@export var windup: float = 0.4             # waktu telegraph (garis merah)
@export var lunge_speed: float = 8.0
@export var lunge_time: float = 0.25
@export var recover_time: float = 0.6
@export var retreat: bool = false           # mundur setelah menyerang
@export var hit_radius: float = 0.8
@export var body_radius: float = 0.5

# --- Raise ---
@export var raise_cost: int = 10
@export var raise_chance: float = 0.7
@export var essence_reward: int = 10
@export var shard_reward: int = 1

# --- Tampilan ---
@export var sprite_path: String = "res://assets/sprites/slime_lumut.png"
@export var sprite_height: float = 1.9

# --- Sebagai Shade ---
@export var shade_hp: int = 25
@export var shade_damage: int = 5
@export var shade_attack_cd: float = 1.0
@export var shade_attack_range: float = 1.6
@export var shade_speed: float = 3.5
