extends Node

var fails := 0

func _ready() -> void:
	var menu := (load("res://scripts/menu.gd") as Script).new() as Control
	menu.version_label = Label.new()
	menu.version_label.text = "v1.4.33"
	menu.add_child(menu.version_label)
	menu.update_button = Button.new()
	menu.add_child(menu.update_button)
	_check(menu._tag_is_newer("v1.4.34"), "newer tag not detected")
	_check(not menu._tag_is_newer("v1.4.33"), "same tag flagged as newer")
	_check(not menu._tag_is_newer("v1.4.32"), "older tag flagged as newer")
	var tags := [
		{"name": "v1.4.31"},
		{"name": "v1.4.34"},
		{"name": "v1.4.33"},
		{"name": "v1.4.30-test"},
	]
	_check(menu._best_tag(tags) == "v1.4.34", "best tag %s" % menu._best_tag(tags))
	var releases := [
		{"name": "Swamp Horror Simulator 3D v1.4.35", "tag_name": "v1.4.35"},
		{"name": "Swamp Horror Simulator 3D v1.4.34", "tag_name": "v1.4.34"},
	]
	_check(menu._best_tag(releases) == "v1.4.35", "best release %s" % menu._best_tag(releases))
	var body := JSON.stringify(tags).to_utf8_buffer()
	_check(menu._consume_tag_list(HTTPRequest.RESULT_SUCCESS, 200, body), "tag list not consumed")
	_check(menu.update_button.visible, "update button hidden")
	_check(menu.update_button.text == menu.tr("UPDATE AVAILABLE"), "update button text %s" % menu.update_button.text)
	_check(menu.version_label.text == "v1.4.33", "version label changed to %s" % menu.version_label.text)
	_check(menu.update_page == menu.RELEASES_PAGE, "update page %s" % menu.update_page)
	menu.free()
	var fresh := (load("res://scripts/menu.gd") as Script).new() as Control
	var box := VBoxContainer.new()
	box.name = "ButtonBox"
	fresh.add_child(box)
	fresh._setup_version()
	_check(fresh.update_button.get_parent() == box, "update button not in menu button box")
	_check(not fresh.update_button.visible, "update button visible before update")
	_check(fresh.update_button.text == fresh.tr("UPDATE AVAILABLE"), "update button default text %s" % fresh.update_button.text)
	fresh._show_update("v1.4.34")
	_check(fresh.update_button.visible, "update button not shown")
	_check(fresh.update_button.tooltip_text == "v1.4.34", "update tooltip %s" % fresh.update_button.tooltip_text)
	fresh.free()
	print("UPDATER FAILS=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		return
	fails += 1
	print("FAIL: ", message)
