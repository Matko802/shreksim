extends Control

const GREEN := Color(0.0, 0.8, 0.27)
const DARK_GREEN := Color(0.0, 0.4, 0.13)

var music: AudioStreamPlayer
var meme: AudioStreamPlayer
var click: AudioStreamPlayer
var meow: AudioStreamPlayer
var playing_meme := false

@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var howto_panel: PanelContainer = %HowtoPanel
@onready var pages_label: Label = %PagesLabel
@onready var esc_label: Label = %EscLabel
@onready var remake_label: Label = $Card/Remake

var menu_time := 0.0

func _process(delta: float) -> void:
	menu_time += delta
	var pulse := 1.0 + 0.055 * sin(menu_time * 1.6)
	remake_label.pivot_offset = remake_label.size * 0.5
	remake_label.scale = Vector2(pulse, pulse)

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/sounds/music_title.ogg")
	music.finished.connect(func() -> void: music.play())
	add_child(music)
	music.play()

	meme = AudioStreamPlayer.new()
	meme.stream = load("res://assets/sounds/music_allstar.ogg")
	add_child(meme)

	click = AudioStreamPlayer.new()
	click.stream = load("res://assets/sounds/sfx_pop.ogg")
	add_child(click)

	meow = AudioStreamPlayer.new()
	meow.stream = load("res://assets/sounds/sfx_meow.ogg")
	add_child(meow)

	%BtnEight.pressed.connect(_start_eight)
	%BtnEndless.pressed.connect(_start_endless)
	%BtnOgre.pressed.connect(_show_enemy_panel)
	%BtnHowto.pressed.connect(_show_howto_panel)
	%BtnStats.pressed.connect(_show_stats_panel)
	%BtnQuit.pressed.connect(_quit)
	%TbShrek.pressed.connect(func() -> void: _pick_skin(GameState.EnemySkin.OG_SHREK))
	%TbTpose.pressed.connect(func() -> void: _pick_skin(GameState.EnemySkin.TPOSE))
	%TbBaby.pressed.connect(func() -> void: _pick_skin(GameState.EnemySkin.BABY))
	%TbSlender.pressed.connect(func() -> void: _pick_skin(GameState.EnemySkin.SLENDER))
	%BkEnemy.pressed.connect(func() -> void:
		click.play()
		enemy_panel.visible = false
	)
	%BkStats.pressed.connect(func() -> void:
		click.play()
		stats_panel.visible = false
	)
	%BkHowto.pressed.connect(func() -> void:
		click.play()
		howto_panel.visible = false
	)

func _pick_skin(skin: GameState.EnemySkin) -> void:
	GameState.skin = skin
	meow.play()
	enemy_panel.visible = false

func _show_howto_panel() -> void:
	click.play()
	howto_panel.visible = true

func _show_enemy_panel() -> void:
	click.play()
	enemy_panel.visible = true

func _show_stats_panel() -> void:
	click.play()
	pages_label.text = "Total onions collected: %d" % GameState.total_pages
	esc_label.text = "Total escapes: %d" % GameState.total_escapes
	%BestLabel.text = "Endless high score: %d" % GameState.best_endless
	stats_panel.visible = true

func _start_eight() -> void:
	GameState.game_type = "eight_pages"
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _start_endless() -> void:
	GameState.game_type = "endless"
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _quit() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_7:
			playing_meme = true
			music.stop()
			meme.play()
		elif event.keycode == KEY_ESCAPE:
			enemy_panel.visible = false
			stats_panel.visible = false
			howto_panel.visible = false
