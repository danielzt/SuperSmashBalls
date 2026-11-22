extends Node
# Captura (precisa de janela): itens/orbe, aura e golpe supremo. Uso: -- <pasta de saída>

func _shot(out: String, name: String, region := Rect2i(), scale := 1) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if region.size.x > 0:
		img = img.get_region(region)
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))


func _phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	await _phys(3)
	main.mode = "versus"
	main.stage_sel = 1
	main.entries = []
	for k in 2:
		main.entries.append({"kind": "dummy", "prefix": "", "label": "D%d" % k, "color": [Color("e74c3c"), Color("3498db")][k],
			"cursor": k * 5, "locked": true, "level": 0})
	main._start_match()
	await _phys(120)
	var m = main.items
	m.running = false   # congela o sorteio; itens colocados à mão
	var a = main.fighters[0]
	var b = main.fighters[1]
	a.global_position = Vector2(380, a.global_position.y)
	b.global_position = Vector2(800, b.global_position.y)
	a.facing = 1
	b.facing = -1
	var gy: float = a.global_position.y + a.body.y * 0.5
	m.items.clear()
	var ids := ["orb", "spikeball", "bomb", "star", "heal"]
	for i in ids.size():
		m.items.append({"id": ids[i], "x": 500.0 + i * 46.0, "y": gy + 1.0, "vy": 0.0, "age": 0.0})
	m.set_physics_process(false)
	m.queue_redraw()
	await _phys(4)
	m.queue_redraw()
	await _phys(2)
	await _shot(out, "1_itens", Rect2i(330, 380, 460, 180), 2)
	# orbe em close-up
	await _shot(out, "2_orbe_closeup", Rect2i(465, 465, 70, 70), 8)
	m.items.clear()
	m.use("orb", a)
	await _phys(20)
	await _shot(out, "3_aura", Rect2i(250, 360, 300, 200), 3)
	await _shot(out, "3b_aura_closeup", Rect2i(325, 420, 130, 130), 6)
	# golpe supremo
	a._begin_slot("super")
	await _phys(12)
	await _shot(out, "4_super_carga", Rect2i(250, 380, 400, 190), 3)
	await _phys(14)
	await _shot(out, "5_super_explosao", Rect2i(250, 380, 640, 190), 2)
	await _phys(10)
	await _shot(out, "6_super_onda", Rect2i(250, 380, 900, 190), 1)
	get_tree().quit()
