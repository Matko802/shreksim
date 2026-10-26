extends Control

const GREEN := Color(0.0, 0.8, 0.27)
const DARK_GREEN := Color(0.0, 0.4, 0.13)
const RELEASES_API := "https://api.github.com/repos/Matko802/shreksim/releases?per_page=30"
const TAGS_API := "https://api.github.com/repos/Matko802/shreksim/tags?per_page=30"
const RELEASES_PAGE := "https://github.com/Matko802/shreksim/releases"
const RELEASE_ATOM := "https://github.com/Matko802/shreksim/releases.atom"
const API_HEADERS := ["Accept: application/vnd.github+json", "User-Agent: SwampSim"]
const UPDATE_URLS := [TAGS_API, RELEASES_API, RELEASE_ATOM]

var music: AudioStreamPlayer
var meme: AudioStreamPlayer
var click: AudioStreamPlayer
var meow: AudioStreamPlayer
var playing_meme := false
var version_label: Label
var update_button: Button
var update_http: HTTPRequest
var update_page := ""
var update_stage := 0

@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var howto_panel: PanelContainer = %HowtoPanel
@onready var lang_option: OptionButton = %LangOption
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
	_setup_lang_option()
	_setup_version()
	_check_update()

func _setup_lang_option() -> void:
	for entry in SettingsBus.LANGUAGES:
		lang_option.add_item(entry[1])
	lang_option.selected = SettingsBus.language_index()
	lang_option.item_selected.connect(func(idx: int) -> void:
		click.play()
		SettingsBus.set_language(SettingsBus.LANGUAGES[idx][0])
	)

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
	update_button.text = tr("UPDATE AVAILABLE")
	update_button.add_theme_font_size_override("font_size", 30)
	update_button.add_theme_color_override("font_color", Color(0.02, 0.12, 0.04))
	var sb := StyleBoxFlat.new()
	sb.bg_color = GREEN
	sb.set_corner_radius_all(8)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.25, 1.0, 0.45)
	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.0, 0.6, 0.2)
	update_button.add_theme_stylebox_override("normal", sb)
	update_button.add_theme_stylebox_override("hover", sb_hover)
	update_button.add_theme_stylebox_override("pressed", sb_pressed)
	update_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	update_button.visible = false
	update_button.pressed.connect(_on_update_pressed)
	var box := get_node_or_null("ButtonBox") as VBoxContainer
	if box != null:
		box.add_child(update_button)
		box.move_child(update_button, 0)
	else:
		add_child(update_button)

func _show_update(tag: String) -> void:
	update_page = RELEASES_PAGE
	update_button.text = tr("UPDATE AVAILABLE")
	update_button.tooltip_text = "v" + tag.lstrip("v")
	update_button.visible = true
	version_label.add_theme_color_override("font_color", GREEN)

func _check_update() -> void:
	update_stage = 0
	_start_update_request()

func _start_update_request() -> void:
	if update_stage >= UPDATE_URLS.size():
		return
	if update_http != null and is_instance_valid(update_http):
		update_http.queue_free()
	update_http = HTTPRequest.new()
	update_http.timeout = 10.0
	add_child(update_http)
	update_http.request_completed.connect(_on_update_response)
	var err := update_http.request(str(UPDATE_URLS[update_stage]), API_HEADERS)
	if err != OK:
		_next_update_stage()

func _next_update_stage() -> void:
	update_stage += 1
	_start_update_request()

func _on_update_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var handled := false
	if update_stage < 2:
		handled = _consume_tag_list(result, code, body)
	else:
		handled = _consume_atom(result, code, body)
	if not handled:
		_next_update_stage()

func _consume_tag_list(result: int, code: int, body: PackedByteArray) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.is_empty():
		return false
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array):
		return false
	var best := _best_tag(data as Array)
	if best != "" and _tag_is_newer(best):
		_show_update(best)
	return true

func _best_tag(items: Array) -> String:
	var best := ""
	for item in items:
		if not (item is Dictionary):
			continue
		var data := item as Dictionary
		var tag := str(data.get("tag_name", data.get("name", "")))
		if not _is_release_tag(tag):
			continue
		if best == "" or _tag_newer_than(tag, best):
			best = tag
	return best

func _consume_atom(result: int, code: int, body: PackedByteArray) -> bool:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.is_empty():
		return false
	var regex := RegEx.new()
	regex.compile("releases/tag/v(\\d+\\.\\d+\\.\\d+)")
	var best := ""
	for m in regex.search_all(body.get_string_from_utf8()):
		var tag := "v" + m.get_string(1)
		if best == "" or _tag_newer_than(tag, best):
			best = tag
	if best != "" and _tag_is_newer(best):
		_show_update(best)
	return true

func _on_update_pressed() -> void:
	click.play()
	OS.shell_open(update_page if update_page != "" else RELEASES_PAGE)

func _current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

func _is_release_tag(tag: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[vV]?\\d+\\.\\d+\\.\\d+$")
	return regex.search(tag) != null

func _version_parts(tag: String) -> Array[int]:
	var parts: Array[int] = [0, 0, 0]
	var regex := RegEx.new()
	regex.compile("^[vV]?(\\d+)\\.(\\d+)\\.(\\d+)")
	var m := regex.search(tag)
	if m != null:
		for i in 3:
			parts[i] = int(m.get_string(i + 1))
	return parts

func _tag_newer_than(tag: String, other: String) -> bool:
	var a := _version_parts(tag)
	var b := _version_parts(other)
	for i in 3:
		if a[i] > b[i]:
			return true
		if a[i] < b[i]:
			return false
	return false

func _tag_is_newer(tag: String) -> bool:
	return _tag_newer_than(tag, _current_version())

func _on_version_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		click.play()
		OS.shell_open(update_page if update_page != "" else RELEASES_PAGE)

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
	pages_label.text = tr("Total onions collected: %d") % GameState.total_pages
	esc_label.text = tr("Total escapes: %d") % GameState.total_escapes
	%BestLabel.text = tr("Endless high score: %d") % GameState.best_endless
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
