extends Node
# Captura de tela de cada mapa (precisa de janela, não roda em --headless).
# Uso: Godot --path . res://tests/capture.tscn -- <pasta de saída>

var main
const T := [0.0, 1.0, 14.0, 5.5, 6.0, 6.0, 2.0, 9.0, 3.6, 2.6, 1.0, 1.0, 2.6, 3.0, 7.0, 4.0, 1.0, 4.0, 5.5, 7.0, 3.1, 9.0, 1.0, 3.0, 5.0, 2.0, 2.0, 7.2, 1.0, 3.0, 2.0, 2.0, 5.0, 3.0, 2.0, 4.0, 6.2, 2.5, 3.0]


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.mode = "versus"
	main.entries = []
	for k in 3:
		main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": [Color("e74c3c"), Color("3498db"), Color("2ecc71")][k],
			"cursor": k * 5, "locked": true, "level": 1})
	main.stage_sel = 39
	main._go_stage()
	for i in 10:
		await get_tree().process_frame
	await _shot(out, "select")
	var Stages = load("res://scripts/stages.gd")
	for s in range(34, Stages.count()):
		main.stage_sel = s + 1
		main._start_match()
		main.stage.t = T[s]
		for i in 50:
			await get_tree().process_frame
		await _shot(out, "stage_%02d" % s)
	get_tree().quit()
