extends CanvasLayer
class_name DebugMenu

const UPDATE_INTERVAL_USEC: int = 250000
const WINDOW_USEC: int = 5000000
const RING_SIZE: int = 2048
const HITCH_USEC: int = 100000

@onready var label: RichTextLabel = $Panel/MarginContainer/Label

var _static_lines: String = ""
var _frame_us: PackedInt64Array = PackedInt64Array()
var _frame_stamp: PackedInt64Array = PackedInt64Array()
var _ring_index: int = 0
var _last_frame_usec: int = 0
var _last_update_usec: int = 0
var _fps_window_start_usec: int = 0
var _fps_window_frames: int = 0
var _fps: float = 0.0
var _measuring: bool = false
var _gpu_ms: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame_us.resize(RING_SIZE)
	_frame_stamp.resize(RING_SIZE)
	_static_lines = _build_static_lines()
	SettingsBus.setting_changed.connect(_on_external_setting)
	_set_active(SettingsBus.debug_info_enabled)

func _exit_tree() -> void:
	_set_measuring(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.has_action("toggle_debug"):
			if event.is_action_pressed("toggle_debug"):
				_set_active(not visible)
		elif event.keycode == KEY_F3:
			_set_active(not visible)

func _on_external_setting(setting_name: StringName, value: Variant) -> void:
	if setting_name != &"debug_info_enabled":
		return
	_set_active(bool(value))

func _set_active(on: bool) -> void:
	visible = on
	set_process(on)
	_set_measuring(on)
	var now: int = Time.get_ticks_usec()
	_last_frame_usec = now
	_last_update_usec = now
	_fps_window_start_usec = now
	_fps_window_frames = 0
	_fps = 0.0
	_ring_index = 0
	_frame_us.fill(0)
	_frame_stamp.fill(0)

func _set_measuring(on: bool) -> void:
	if on == _measuring:
		return
	_measuring = on
	var vp := get_viewport()
	if vp == null:
		return
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), on)
	if not on:
		_gpu_ms = 0.0

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var frame_us: int = now - _last_frame_usec
	_last_frame_usec = now
	if frame_us > 0:
		_frame_us[_ring_index] = frame_us
		_frame_stamp[_ring_index] = now
		_ring_index = (_ring_index + 1) % RING_SIZE
		_fps_window_frames += 1
	var fps_elapsed: int = now - _fps_window_start_usec
	if fps_elapsed >= 1000000:
		_fps = float(_fps_window_frames) * 1000000.0 / float(fps_elapsed)
		_fps_window_frames = 0
		_fps_window_start_usec = now
	if now - _last_update_usec < UPDATE_INTERVAL_USEC:
		return
	_last_update_usec = now
	var cutoff: int = now - WINDOW_USEC
	var times: Array[int] = []
	var hitches: int = 0
	var hitch_cutoff: int = now - 1000000
	for i in RING_SIZE:
		if _frame_stamp[i] < cutoff:
			continue
		var t: int = _frame_us[i]
		times.append(t)
		if t >= HITCH_USEC and _frame_stamp[i] >= hitch_cutoff:
			hitches += 1
	times.sort()
	var count: int = times.size()
	var avg_ms: float = 0.0
	var max_ms: float = 0.0
	var low_1: float = 0.0
	var low_01: float = 0.0
	if count > 0:
		var total: int = 0
		for t in times:
			total += t
		avg_ms = float(total) / float(count) / 1000.0
		max_ms = float(times[count - 1]) / 1000.0
		low_1 = _low_fps(times, maxi(1, int(ceil(float(count) * 0.01))))
		low_01 = _low_fps(times, maxi(1, int(ceil(float(count) * 0.001))))
	if _measuring:
		var rid: RID = get_viewport().get_viewport_rid()
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if gpu > 0.0:
			_gpu_ms = gpu
	var render_cpu: float = RenderingServer.get_frame_setup_time_cpu()
	var engine_fps: float = Engine.get_frames_per_second()
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objs: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var proc_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var gpu_text: String = "n/a"
	if _gpu_ms > 0.0:
		gpu_text = "%.1f ms (%.1f FPS)" % [_gpu_ms, 1000.0 / _gpu_ms]
	var lines: PackedStringArray = PackedStringArray()
	lines.append(" Loop: %.1f FPS | Engine: %.0f | Frame avg: %.1f ms | Max: %.1f ms" % [_fps, engine_fps, avg_ms, max_ms])
	lines.append(" Hitches: %d/s | GPU: %s | Render CPU: %.2f ms" % [hitches, gpu_text, render_cpu])
	lines.append(" 1%% Low: %.1f FPS | 0.1%% Low: %.1f FPS" % [low_1, low_01])
	lines.append(" Draw: %d | Prims: %d k | Objs: %d | Proc max: %.2f ms | Phys: %.2f ms" % [draws, int(prims / 1000.0), objs, proc_ms, phys_ms])
	lines.append(_static_lines)
	label.text = "\n".join(lines)

func _low_fps(sorted_times: Array[int], count: int) -> float:
	var n: int = clampi(count, 1, sorted_times.size())
	var total: int = 0
	for i in range(sorted_times.size() - n, sorted_times.size()):
		total += sorted_times[i]
	var avg_us: float = float(total) / float(n)
	if avg_us <= 0.0:
		return 0.0
	return 1000000.0 / avg_us

func _build_static_lines() -> String:
	var rendering_method: String = str(RenderingServer.get_current_rendering_method())
	var info: Array = OS.get_video_adapter_driver_info()
	var rendering_driver: String = str(info[0]) if info.size() > 0 else "unknown"
	var gpu_name: String = "unknown"
	var gpu_vendor: String = "n/a"
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null:
		var dev_name: String = rd.get_device_name()
		if not dev_name.is_empty():
			gpu_name = dev_name
		var vendor: String = rd.get_device_vendor_name()
		if not vendor.is_empty():
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
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	var screen_text: String = "%dx%d" % [screen_size.x, screen_size.y]
	if refresh > 0.0:
		screen_text = "%s @ %.0f Hz" % [screen_text, refresh]
	var lines: PackedStringArray = PackedStringArray()
	lines.append(" Godot %s (%s)" % [engine_version, rendering_driver])
	lines.append(" Renderer: %s | Screen: %s | Cap: %d" % [rendering_method, screen_text, Engine.max_fps])
	lines.append(" OS: %s" % os_name)
	lines.append(" GPU: %s [%s]" % [gpu_name, gpu_vendor])
	lines.append(" CPU: %s (%d cores)" % [cpu_name, cpu_cores])
	return "\n".join(lines)
