extends Node
# Teste (headless): valida as 60 conquistas, o desbloqueio por contador e uma partida com CPUs.

var main


func _fail(msg: String) -> void:
	print("FALHOU: ", msg)
	get_tree().quit(1)


func _ready() -> void:
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64
	var Ach = load("res://scripts/achievements.gd")
	var Art = load("res://scripts/art.gd")
	if Ach.LIST.size() != 60:
		return _fail("esperava 60 conquistas, tem %d" % Ach.LIST.size())
	var ids := {}
	for a in Ach.LIST:
		if ids.has(a["id"]):
			return _fail("id repetido " + a["id"])
		ids[a["id"]] = true
		var w: float = Art.font().get_string_size(a["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		if w > 316.0:
			return _fail("descrição larga demais (%d px): %s" % [w, a["name"]])
		var wn: float = Art.font().get_string_size(a["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		if wn > 250.0:
			return _fail("nome largo demais (%d px): %s" % [wn, a["name"]])
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().physics_frame
	# desbloqueio por contador, conjunto e máximo
	Ach.add("wins")
	Ach.set_max("combo_max", 12.0)
	for k in 8:
		Ach.mark("chars", k)
	for id in ["win1", "cmb5", "cmb10", "ch8"]:
		if not Ach.unlocked.has(id):
			return _fail("não desbloqueou " + id)
	if Ach.unlocked.has("cmb20") or Ach.unlocked.has("ch16"):
		return _fail("desbloqueou cedo demais")
	# partida de 25 s com 1 humano (sem controle) e 3 CPUs
	main.mode = "versus"
	main.stage_sel = 1
	main.cfg_mode = 0
	main.entries = [{"kind": "human", "prefix": "kb1", "label": "P1", "color": Color.WHITE, "cursor": 0, "locked": true, "level": 0}]
	for k in 3:
		main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": Color.WHITE,
			"cursor": k + 1, "locked": true, "level": 9})
	main._start_match()
	var t := 0
	while main.st == main.S.FIGHT and t < 60 * 25:
		await get_tree().physics_frame
		t += 1
	# telas
	main.title_sel = 4
	main._go_title()
	main._title_confirm()
	for i in 5:
		await get_tree().process_frame
	if main.st != main.S.ACH:
		return _fail("não abriu a tela de conquistas")
	main.ach_row = 13
	for i in 30:
		await get_tree().process_frame
	print("OK: 60 conquistas, desbloqueadas: ", Ach.count_unlocked(), " stats: ", Ach.stats.keys().size())
	get_tree().quit(0)
