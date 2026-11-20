extends Node

var main
var f := 0


func _ready() -> void:
	main = load("res://main.tscn").instantiate()
	add_child(main)


func _process(_d: float) -> void:
	f += 1
	match f:
		3:
			main.mode = "versus"
			main.cfg_humans = 2
			main.cfg_cpus = 2
			main.cfg_row = 2
			main.st = main.S.CONFIG
			main.mouse = Vector2(950, 460)
		8:
			main.slots = ["kb1", "j0"]
			main._start_select()
			main.entries[0].locked = true
			main.entries[1].locked = true
			main.entries[2].locked = true
			main.entries[3].locked = true
			main.mouse = Vector2(1100, 655)
			main.hover_cell = 6
		13:
			main.mode = "versus"
			main.st = main.S.TITLE
			main.mouse = Vector2(640, 380)
			main.title_sel = 1
		18:
			get_tree().quit()
