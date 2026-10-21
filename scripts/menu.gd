extends Control

const GREEN := Color(0.0, 0.8, 0.27)
const DARK_GREEN := Color(0.0, 0.4, 0.13)
const RELEASE_API := "https://api.github.com/repos/Matko802/shreksim/releases/latest"

var music: AudioStreamPlayer
var meme: AudioStreamPlayer
var click: AudioStreamPlayer
var meow: AudioStreamPlayer
var playing_meme := false
var version_label: Label
var update_button: Button
var update_http: HTTPRequest
var update_page := ""

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
	_setup_version()
	_check_update()

func _setup_version() -> void:
	var ver := str(ProjectSettings.get_setting("application/config/version", "1.3.8"))
	version_label = Label.new()
	version_label.text = "v" + ver
	version_label.add_theme_font_size_override("font_size", 36)
	version_label.add_theme_color_override("font_color", DARK_GREEN)
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -420.0
	version_label.offset_top = -74.0
	version_label.offset_right = -18.0
	version_label.offset_bottom = -18.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(version_label)
	version_label.gui_input.connect(_on_version_input)
	update_button = Button.new()
	update_button.text = "UPDATE"
	update_button.add_theme_font_size_override("font_size", 30)
	update_button.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	var sb := StyleBoxFlat.new()
	sb.bg_color = DARK_GREEN
	sb.set_corner_radius_all(10)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = GREEN
	update_button.add_theme_stylebox_override("normal", sb)
	update_button.add_theme_stylebox_override("hover", sb_hover)
	update_button.add_theme_stylebox_override("pressed", sb_hover)
	update_button.add_theme_stylebox_override("focus", sb)
	update_button.anchor_left = 1.0
	update_button.anchor_top = 1.0
	update_button.anchor_right = 1.0
	update_button.anchor_bottom = 1.0
	update_button.offset_left = -680.0
	update_button.offset_top = -74.0
	update_button.offset_right = -440.0
	update_button.offset_bottom = -18.0
	update_button.visible = false
	update_button.pressed.connect(_on_update_pressed)
	add_child(update_button)

func _check_update() -> void:
	update_http = HTTPRequest.new()
	update_http.timeout = 6.0
	add_child(update_http)
	update_http.request_completed.connect(_on_update_check)
	update_http.request(RELEASE_API, ["Accept: application/vnd.github+json"])

func _on_update_check(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.is_empty():
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		return
	var tag := str(data.get("tag_name", ""))
	if tag == "" or not _tag_is_newer(tag):
		return
	update_page = "https://github.com/Matko802/shreksim/releases/tag/" + tag
	version_label.text = "v" + tag.lstrip("v") + " - tap to update"
	version_label.add_theme_color_override("font_color", GREEN)
	update_button.visible = true

func _on_update_pressed() -> void:
	if update_page == "":
		return
	click.play()
	OS.shell_open(update_page)

func _tag_is_newer(tag: String) -> bool:
	var cur := str(ProjectSettings.get_setting("application/config/version", "0.0.0")).lstrip("v").split(".")
	var nxt := tag.lstrip("v").split(".")
	for i in 3:
		var a := int(cur[i]) if i < cur.size() else 0
		var b := int(nxt[i]) if i < nxt.size() else 0
		if b > a:
			return true
		if b < a:
			return false
	return false

func _on_version_input(event: InputEvent) -> void:
	if update_page == "":
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		click.play()
		OS.shell_open(update_page)

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
