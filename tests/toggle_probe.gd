extends Node

func _ready() -> void:
	var fails := 0
	var pause := (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pause)
	await get_tree().process_frame
	var check := pause.get_node("%DebugCheck") as CheckButton
	if check == null:
		print("FAIL debug check missing")
		fails += 1
	else:
		check.set_pressed(true)
		if not SettingsBus.debug_info_enabled:
			print("FAIL settings flag not set")
			fails += 1
		check.set_pressed(false)
		if SettingsBus.debug_info_enabled:
			print("FAIL settings flag not cleared")
			fails += 1
	await get_tree().process_frame
	var dbg := (load("res://scenes/debug_menu.tscn") as PackedScene).instantiate()
	add_child(dbg)
	await get_tree().process_frame
	if dbg.visible:
		print("FAIL debug menu visible by default")
		fails += 1
	SettingsBus.set_debug_info(true)
	if not dbg.visible or not dbg.is_processing():
		print("FAIL debug menu did not activate")
		fails += 1
	SettingsBus.set_debug_info(false)
	if dbg.visible:
		print("FAIL debug menu did not deactivate")
		fails += 1
	if dbg.label.text.is_empty():
		print("FAIL debug label empty")
		fails += 1
	print("TOGGLE FAILS=", fails)
	get_tree().quit(fails)
