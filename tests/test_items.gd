extends Node
# Teste (headless): cada item pode ser pego perto, mas não de longe, e usado/jogado em seguida.

func _ready() -> void:
	Engine.time_scale = 4.0
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().physics_frame
	main.mode = "versus"
	main.stage_sel = 1
	main.entries = []
	for k in 2:
		main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": Color.WHITE,
			"cursor": k, "locked": true, "level": 5})
	main._start_match()
	for i in 5:
		await get_tree().physics_frame
	var f = main.fighters[0]
	f.ai = null
	var m = main.items
	var ok := 0
	# longe: não pega
	m.items.clear()
	m.items.append({"id": "heal", "x": f.global_position.x + 400.0, "y": f.global_position.y + 20.0, "vy": 0.0, "age": 0.0})
	print("longe -> pickup=", m.pickup(f), " (esperado false)")
	for id in m.TYPES.keys():
		m.items.clear()
		f.held_item = ""
		f.percent = 50.0
		m.items.append({"id": id, "x": f.global_position.x, "y": f.global_position.y + 20.0, "vy": 0.0, "age": 0.0})
		var got: bool = m.pickup(f)
		var held: bool = f.held_item == id
		m.use(id, f)
		f.held_item = ""
		await get_tree().physics_frame
		print("%-10s pegou=%s na_mao=%s usou=ok" % [id, got, held])
		if got and held:
			ok += 1
	print("itens ok %d/%d" % [ok, m.TYPES.size()])
	get_tree().quit()
