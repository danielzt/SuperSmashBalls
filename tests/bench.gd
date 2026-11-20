extends Node
# Benchmark de FPS por mapa (precisa de janela).
# Uso: Godot --path . res://tests/bench.tscn -- [mapas separados por vírgula]
var main

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.mode = "versus"
	main.entries = []
	for k in 4:
		main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": [Color("e74c3c"), Color("3498db"), Color("2ecc71"), Color("f1c40f")][k],
			"cursor": k * 5, "locked": true, "level": 3})
	var Stages = load("res://scripts/stages.gd")
	var args := OS.get_cmdline_user_args()
	var list: Array = []
	if args.size() > 0:
		for s in args[0].split(","):
			list.append(int(s))
	else:
		for s in Stages.count():
			list.append(s)
	# título
	await _measure("title")
	for s in list:
		main.stage_sel = s + 1
		main._start_match()
		for i in 30:
			await get_tree().process_frame
		await _measure("stage_%02d" % s)
	get_tree().quit()

func _measure(name: String) -> void:
	var n := 240
	var t0 := Time.get_ticks_usec()
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var objs := 0.0
	for i in n:
		await get_tree().process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var dt := (Time.get_ticks_usec() - t0) / 1e6
	print("%s: fps=%.0f  process=%.2fms phys=%.2fms draws=%.0f objs=%.0f" % [name, n / dt, proc / n * 1000.0, phys / n * 1000.0, draws / n, objs / n])
