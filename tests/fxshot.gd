extends Node
# Captura dos efeitos de golpe. Uso: Godot --path . res://tests/fxshot.tscn -- <pasta>
var main


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image().get_region(Rect2i(470, 400, 240, 135))
	im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	im.save_png(out.path_join(name + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	main = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 5:
		await get_tree().process_frame
	main.mode = "versus"
	main.entries = []
	for k in 2:
		main.entries.append({"kind": "cpu", "prefix": "", "label": "C%d" % k, "color": [Color("e74c3c"), Color("3498db")][k],
			"cursor": [5, 8][k], "locked": true, "level": 1})
	main.stage_sel = 1
	main._start_match()
	for i in 200:
		await get_tree().process_frame
	var a = main.fighters[0]
	var b = main.fighters[1]
	a.set_physics_process(false)
	b.set_physics_process(false)
	for slot in ["jab", "ftilt", "utilt", "b_neutral", "b_side"]:
		a.global_position = Vector2(560, 495)
		b.global_position = Vector2(615, 495)
		a.facing = 1
		b.facing = -1
		b.invincible = 0.0
		b.percent = 30.0
		b.velocity = Vector2.ZERO
		b.hitstun = 0.0
		b.shielding = false
		b.shield_hp = 0.0
		var m: Dictionary = a._moves().get(slot, {})
		if m.is_empty():
			continue
		a._start(m, slot)
		var st0: float = 0.0
		for s0 in m["steps"]:
			if String(s0["type"]) in ["hit", "proj"]:
				st0 = float(s0["t"])
				break
		for i in 60:
			if a.cur_move.is_empty():
				break
			a.anim_t += 0.016
			a._update_attack(0.016, true)
			a.queue_redraw()
			await get_tree().process_frame
			if i == 3 and slot == "jab":
				print(slot, " t=", a.attack_t, " steps=", m["steps"], " pct=", b.percent)
			if absf(a.attack_t - (st0 + 0.02)) < 0.009 or absf(a.attack_t - (st0 + 0.06)) < 0.009:
				await _shot(out, "%s_%d" % [slot, int((a.attack_t - st0) * 1000)])
		print(slot, " b.pct=", b.percent, " b.pos=", b.global_position, " resp=", b.respawn_t, " a=", a.cdata["name"] if a.cdata.has("name") else "")
		a._end_move()
	get_tree().quit()
