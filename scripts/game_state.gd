extends Node

enum EnemySkin { SLENDER, OG_SHREK, TPOSE, BABY }

const SKIN_PATHS := {
	EnemySkin.SLENDER: "res://assets/images/enemies/enemy_slenderman.png",
	EnemySkin.OG_SHREK: "res://assets/images/enemies/enemy_ogshrek.png",
	EnemySkin.TPOSE: "res://assets/images/enemies/enemy_tpose.png",
	EnemySkin.BABY: "res://assets/images/enemies/enemy_babyshrek.png",
}
const SAVE_PATH := "user://swampsim_stats.cfg"

var game_type := "eight_pages"
var skin := EnemySkin.OG_SHREK
var total_pages := 0
var total_escapes := 0
var best_endless := 0

func _ready() -> void:
	load_stats()

func load_stats() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		total_pages = int(cfg.get_value("stats", "pages", 0))
		total_escapes = int(cfg.get_value("stats", "escapes", 0))
		best_endless = int(cfg.get_value("stats", "best_endless", 0))

func save_stats() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "pages", total_pages)
	cfg.set_value("stats", "escapes", total_escapes)
	cfg.set_value("stats", "best_endless", best_endless)
	cfg.save(SAVE_PATH)

func skin_texture() -> Texture2D:
	return load(SKIN_PATHS[skin])
