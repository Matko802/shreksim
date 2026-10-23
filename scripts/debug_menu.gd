extends CanvasLayer
class_name DebugMenu

const UPDATE_INTERVAL: float = 0.25
const FPS_HISTORY_SIZE: int = 1000

@onready var label: RichTextLabel = $Panel/MarginContainer/Label

var _static_lines: String = ""
var _accum: float = 0.0
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _frame_index: int = 0
var _frames_recorded: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame_times.resize(FPS_HISTORY_SIZE)
	set_process(false)
	_static_lines = _build_static_lines()
	SettingsBus.setting_changed.connect(_on_external_setting)
	visible = SettingsBus.debug_info_enabled

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var was_hidden: bool = not visible
		if InputMap.has_action("toggle_debug"):
			if event.is_action_pressed("toggle_debug"):
				visible = not visible
		elif event.keycode == KEY_F3:
			visible = not visible
		if visible and was_hidden:
			set_process(true)
		elif not visible and not was_hidden:
			set_process(false)

func _on_external_setting(setting_name: StringName, value: Variant) -> void:
	if setting_name != &"debug_info_enabled":
		return
	visible = bool(value)
	set_process(bool(value))

func _low_percent(count: int) -> float:
	if _frames_recorded <= 0:
		return 0.0
	var n: int = clampi(count, 1, _frames_recorded)
	var sorted: PackedFloat32Array = _frame_times.slice(0, _frames_recorded)
	sorted.sort()
	var total: float = 0.0
	for i in n:
		total += sorted[i]
	var avg_ms: float = (total / float(n)) * 1000.0
	return 1000.0 / avg_ms if avg_ms > 0.0 else 0.0

func _process(delta: float) -> void:
	_frame_times[_frame_index] = delta
	_frame_index = (_frame_index + 1) % FPS_HISTORY_SIZE
	_frames_recorded = mini(_frames_recorded + 1, FPS_HISTORY_SIZE)
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	var fps := Engine.get_frames_per_second()
	var latency_ms: float = delta * 1000.0
	var low_1: float = _low_percent(int(_frames_recorded / 100.0))
	var low_01: float = _low_percent(int(_frames_recorded / 1000.0))
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objs: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var proc_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_time: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var lines: PackedStringArray = PackedStringArray()
	lines.append(" FPS: %d | Latency: %.1f ms | 1%% Low: %.1f | 0.1%% Low: %.1f" % [fps, latency_ms, low_1, low_01])
	lines.append(" Draw: %d | Prims: %d k | Objs: %d | Proc: %.2f ms | Phys: %.2f ms" % [draws, prims / 1000, objs, proc_time, phys_time])
	lines.append(_static_lines)
	label.text = "\n".join(lines)

func _build_static_lines() -> String:
	var rendering_method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	var info: Array = OS.get_video_adapter_driver_info()
	var rendering_driver: String = str(info[0]) if info.size() > 0 else "unknown"
	var gpu_name: String = "unknown"
	var gpu_vendor: String = "n/a"
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null:
		var dev_name: String = rd.get_device_name()
		if dev_name.is_empty():
			gpu_name = "unknown"
		else:
			gpu_name = dev_name
		var vendor: String = rd.get_device_vendor_name()
		if vendor.is_empty():
			gpu_vendor = "n/a"
		else:
			gpu_vendor = vendor
	var os_name: String = OS.get_name()
	var os_distro: String = OS.get_distribution_name()
	if not os_distro.is_empty():
		os_name = "%s (%s)" % [os_name, os_distro]
	var cpu_name: String = OS.get_processor_name()
	if cpu_name.is_empty():
		cpu_name = "unknown"
	var cpu_cores: int = OS.get_processor_count()
	var vi: Dictionary = Engine.get_version_info()
	var engine_version: String = "%d.%d.%d" % [vi.get("major", 0), vi.get("minor", 0), vi.get("patch", 0)]
	var engine_status: String = str(vi.get("status", ""))
	if not engine_status.is_empty():
		engine_version = "%s-%s" % [engine_version, engine_status]
	var lines: PackedStringArray = PackedStringArray()
	lines.append(" Godot %s (%s)" % [engine_version, rendering_driver])
	lines.append(" Renderer: %s" % rendering_method)
	lines.append(" OS: %s" % os_name)
	lines.append(" GPU: %s [%s]" % [gpu_name, gpu_vendor])
	lines.append(" CPU: %s (%d cores)" % [cpu_name, cpu_cores])
	return "\n".join(lines)
