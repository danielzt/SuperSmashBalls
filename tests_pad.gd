extends Node

var main


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func tap(a: String) -> void:
	Input.action_press(a)
	await frames(6)
	Input.action_release(a)
	await frames(6)


func _ready() -> void:
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(4)
	print("TITLE(0): ", main.st)
	await tap("j0_attack")  # VERSUS
	print("CONFIG(1): ", main.st, " linha=", main.cfg_row)
	for i in 3:
		await tap("j0_down")
	print("linha apos 3x baixo (esperado 3 = barra de botoes): ", main.cfg_row, " foco=", main._focused_index())
	await tap("j0_right")
	print("foco no botao 1 (VOLTAR): ", main.btn_focus)
	await tap("j0_left")
	await tap("j0_attack")  # CONTINUAR
	print("CONNECT(2): ", main.st)
	await tap("j0_special")  # voltar com B
	print("B voltou ao titulo (0): ", main.st)
	await tap("j0_attack")
	for i in 3:
		await tap("j0_down")
	await tap("j0_attack")  # CONTINUAR
	await tap("j0_attack")  # conecta o controle 1
	await frames(80)
	print("SELECT(3): ", main.st, " humanos=", main.slots)
	await tap("j0_attack")  # P1 confirma (cursor 0)
	await tap("j0_attack")  # CPU confirma
	print("travados: ", main.entries.map(func(e): return e.locked))
	# desfaz com B e confirma de novo
	await tap("j0_special")
	await tap("j0_attack")
	print("travados: ", main.entries.map(func(e): return e.locked), " botoes=", main._buttons().map(func(b): return b.id))
	# ainda sem entrada ativa travada? vai ate a barra de botoes: baixo x4 -> ALEATORIO -> barra
	main.entries[1]["locked"] = false
	main.entries[1]["cursor"] = 12
	await tap("j0_down")  # cursor da CPU: 12 -> ALEATORIO
	print("cursor CPU (esperado 16): ", main.entries[1]["cursor"])
	await tap("j0_down")  # barra de botoes
	print("foco na barra (sel_btn): ", main.sel_btn, " botoes: ", main._buttons().map(func(b): return b.text))
	await tap("j0_left")
	print("sel_btn apos esquerda: ", main.sel_btn)
	await tap("j0_up")
	print("cima sai da barra (esperado -1): ", main.sel_btn)
	main.entries[1]["cursor"] = 16
	main._lock_entry(1)
	print("todos travados: ", main._all_locked(), " botoes: ", main._buttons().map(func(b): return b.id))
	await tap("j0_down")
	print("foco (esperado ultimo = fight): ", main.sel_btn)
	await tap("j0_attack")
	print("FIGHT(4): ", main.st, " lutadores=", main.fighters.size())
	# fim da partida: botoes
	main.st = main.S.OVER
	main.btn_focus = 0
	await frames(3)
	await tap("j0_down")
	print("OVER foco (esperado 1 = MENU): ", main.btn_focus)
	await tap("j0_attack")
	print("MENU -> titulo (0): ", main.st)
	get_tree().quit()
