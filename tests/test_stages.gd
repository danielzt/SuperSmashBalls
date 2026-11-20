extends Node
# Teste (headless): cada mapa com 4 CPUs por 25 s; mostra vidas, dano e se os perigos acertaram.

var main


func _ready() -> void:
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().physics_frame
	var Stages = load("res://scripts/stages.gd")
	var order: Array = range(Stages.count())
	for extra in 7:
		order.append(Stages.count() - 1)   # o procedural roda várias vezes (layouts diferentes)
	for s in order:
		main.mode = "versus"
		main.stage_sel = s + 1
		main.entries = []
		for k in 4:
			main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": Color.WHITE,
				"cursor": (s * 3 + k * 5) % 16, "locked": true, "level": 7})
		main._start_match()
		var t := 0
		while main.st == main.S.FIGHT and t < 60 * 25:
			await get_tree().physics_frame
			t += 1
		var info := []
		var total_pct := 0.0
		for f in main.fighters:
			info.append("%d/%d%%" % [f.stocks, int(f.percent)])
			total_pct += f.percent
		print("%2d %-22s %-15s t=%2ds  %s  cds=%d objs=%d  %s" % [s, Stages.get_stage(s)["name"],
			main.Art.pal["name"], t / 60, " ".join(info), main.stage.cds.size(), main.stage.objs.size(), String(Stages.get_stage(s)["hz_text"]).right(40) if Stages.is_proc(s) else ""])
	main._go_title()
	print("== FIM")
	get_tree().quit()
