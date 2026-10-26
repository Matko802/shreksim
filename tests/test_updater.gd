extends Node

var fails := 0

func _ready() -> void:
	var menu := (load("res://scripts/menu.gd") as Script).new() as Control
	menu.version_label = Label.new()
	menu.update_button = Button.new()
	_check(menu._tag_is_newer("v1.4.33"), "newer tag not detected")
	_check(not menu._tag_is_newer("v1.4.32"), "same tag flagged as newer")
	_check(not menu._tag_is_newer("v1.4.31"), "older tag flagged as newer")
	var tags := [
		{"name": "v1.4.30"},
		{"name": "v1.4.33"},
		{"name": "v1.4.32"},
		{"name": "v1.4.29-test"},
	]
	_check(menu._best_tag(tags) == "v1.4.33", "best tag %s" % menu._best_tag(tags))
	var releases := [
		{"name": "Swamp Horror Simulator 3D v1.4.34", "tag_name": "v1.4.34"},
		{"name": "Swamp Horror Simulator 3D v1.4.33", "tag_name": "v1.4.33"},
	]
	_check(menu._best_tag(releases) == "v1.4.34", "best release %s" % menu._best_tag(releases))
	var body := JSON.stringify(tags).to_utf8_buffer()
	_check(menu._consume_tag_list(HTTPRequest.RESULT_SUCCESS, 200, body), "tag list not consumed")
	_check(menu.update_button.visible, "update button hidden")
	_check(menu.version_label.text.contains("1.4.33"), "update label %s" % menu.version_label.text)
	_check(menu.update_page == menu.RELEASES_PAGE, "update page %s" % menu.update_page)
	menu.free()
	print("UPDATER FAILS=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		return
	fails += 1
	print("FAIL: ", message)
