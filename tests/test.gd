extends Node
# Teste temporário (headless), sem depender de teclas: tutoriais e IA.

var main


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(3)

	for kind in [1, 2]:
		print("== TUTORIAL ", kind)
		main.mode = "tutorial%d" % kind
		main.slots = ["kb1"]
		main._start_tutorial()
		await frames(5)
		var f = main.fighters[0]
		var d = main.fighters[1]
		var guard := 0
		while not main.tut.done and guard < 30:
			var idx: int = main.tut.idx
			var id: String = main.tut.steps[idx]["id"]
			# simula a ação do jogador para cada passo (sem teclado)
			match id:
				"move":
					f.global_position.x += 320.0
				"jump":
					f.jumps_used += 1
				"djump":
					f.air_jumps += 1
				"attack":
					d.percent += 3.0
				"dir":
					for s in ["ftilt", "utilt", "dtilt"]:
						f.used_slots[s] = int(f.used_slots.get(s, 0)) + 1
				"special":
					for s in ["b_neutral", "b_side"]:
						f.used_slots[s] = int(f.used_slots.get(s, 0)) + 1
				"grab":
					f.throw_count += 1
				"ko":
					d.ko_count += 1
				"air":
					for s in ["nair", "fair", "bair", "uair"]:
						f.used_slots[s] = int(f.used_slots.get(s, 0)) + 1
				"dash":
					f.used_slots["dash"] = int(f.used_slots.get("dash", 0)) + 1
				"drop":
					f.plat_drops += 1
				"counter":
					print("   (CPU do boneco ativa: ", d.ai != null, ")")
					f.counter_count += 1
				"charge":
					f.max_charge = 0.6
				"combo":
					d.combo_hits = 3
				"shield", "fastfall":
					main.tut.skip()  # depende de teclas reais; o roteiro só pula
				"recover":
					await frames(45)
					f.global_position = Vector2(640, 480)
					f.velocity = Vector2.ZERO
			await frames(8)
			await frames(90)
			guard += 1
			print("   ", id, " -> passo atual ", main.tut.idx, " (done=", main.tut.done, ")")
		print("tutorial ", kind, " concluido: ", main.tut.done)
		main._go_title()
		await frames(3)

	print("== IA: nivel 9 contra nivel 1 (mesmo personagem)")
	var wins := {"9": 0, "1": 0, "empate": 0}
	for round in 3:
		main.mode = "versus"
		main.entries = [
			{"kind": "cpu", "prefix": "", "label": "A", "color": Color.RED, "cursor": 0, "locked": true, "level": 9},
			{"kind": "cpu", "prefix": "", "label": "B", "color": Color.BLUE, "cursor": 0, "locked": true, "level": 1},
		]
		main._start_match()
		var t := 0
		while main.st == main.S.FIGHT and t < 60 * 90:
			await get_tree().physics_frame
			t += 1
		var a = main.fighters[0]
		var b = main.fighters[1]
		var w := "empate"
		if a.stocks > b.stocks:
			w = "9"
		elif b.stocks > a.stocks:
			w = "1"
		wins[w] += 1
		print("  rodada ", round, ": vidas Nv9=", a.stocks, " Nv1=", b.stocks, " tempo=", t / 60, "s  golpes Nv9=", a.used_slots, " Nv1=", b.used_slots.size(), " tipos")
	print("resultado: ", wins)

	print("== IA: personagens variados, nivel 5 x nivel 5 (20s cada)")
	for c in [1, 3, 5, 7, 9, 11, 13, 15]:
		main.mode = "versus"
		main.entries = [
			{"kind": "cpu", "prefix": "", "label": "A", "color": Color.RED, "cursor": c, "locked": true, "level": 5},
			{"kind": "cpu", "prefix": "", "label": "B", "color": Color.BLUE, "cursor": (c + 6) % 16, "locked": true, "level": 5},
		]
		main._start_match()
		var t := 0
		while main.st == main.S.FIGHT and t < 60 * 20:
			await get_tree().physics_frame
			t += 1
		var a = main.fighters[0]
		var b = main.fighters[1]
		print("  ", a.cdata.name, " x ", b.cdata.name, ": vidas ", a.stocks, " x ", b.stocks, "  golpes distintos ", a.used_slots.size(), "/", b.used_slots.size())
	print("== FIM")
	get_tree().quit()
