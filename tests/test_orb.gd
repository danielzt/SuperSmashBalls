extends Node
# Teste (headless): Orbe de Poder — aura, golpe supremo no Y, dano alto no rival e chance crescente com o tempo.

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
		main.entries.append({"kind": "dummy", "prefix": "", "label": "C%d" % k, "color": Color.WHITE,
			"cursor": k, "locked": true, "level": 0})
	main._start_match()
	for i in 90:
		await get_tree().physics_frame
	var m = main.items
	var a = main.fighters[0]
	var b = main.fighters[1]
	a.ai = null
	b.global_position = a.global_position + Vector2(120, 0)
	a.facing = 1
	m.elapsed = 0.0
	var c0: float = m._orb_chance()
	m.elapsed = 120.0
	var c1: float = m._orb_chance()
	print("chance orbe: 0s=%.3f 120s=%.3f (cresce: %s)" % [c0, c1, c1 > c0])
	m.items.clear()
	m.items.append({"id": "orb", "x": a.global_position.x, "y": a.global_position.y + 20.0, "vy": 0.0, "age": 0.0})
	print("pegou orbe: ", m.pickup(a), " na mao: ", a.held_item)
	m.use("orb", a)
	a.held_item = ""
	print("aura (power_orb): ", a.power_orb)
	b.percent = 0.0
	a._begin_slot("super")
	print("super iniciado: ", a.cur_slot, " orb gasto: ", not a.power_orb)
	var peak := 0.0
	for i in 80:
		peak = maxf(peak, b.percent)
		await get_tree().physics_frame
	print("rival: stocks=%d pico_dano=%.1f%% ko_a=%d" % [b.stocks, peak, a.ko_count])
	get_tree().quit()
