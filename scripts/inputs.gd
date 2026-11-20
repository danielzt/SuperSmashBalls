extends Node
## Controles por DISPOSITIVO (não por jogador): "kb1", "kb2" e "j0".."j7" (controles).
## Na tela de conexão, cada jogador entra apertando ATAQUE no seu dispositivo.
## Xbox e PlayStation usam o mesmo mapeamento no Godot:
## A/Xis = pular, X/Quadrado = ataque, B/Bolinha = especial, LB/RB/L1/R1 e gatilhos = escudo.
## Ações globais: "start" (Enter / Start) e "menu_back" (Esc / Select).

const ACTIONS := ["left", "right", "up", "down", "jump", "attack", "special", "ult", "shield"]

var prefixes: Array = ["kb1", "kb2"]


func _ready() -> void:
	for d in 8:
		prefixes.append("j%d" % d)
	for pf in prefixes:
		_setup(pf)
	_add_action("start", 0.5)
	_add_key("start", KEY_ENTER, true)
	_add_key("start", KEY_KP_ENTER, true)
	_add_action("menu_back", 0.5)
	_add_key("menu_back", KEY_ESCAPE, true)
	for d in 8:
		_add_button("start", d, JOY_BUTTON_START)
		_add_button("menu_back", d, JOY_BUTTON_BACK)


func name_of(pf: String) -> String:
	if pf.begins_with("kb"):
		return "Teclado " + pf.substr(2)
	if pf.begins_with("j"):
		return "Controle " + str(int(pf.substr(1)) + 1)
	return "—"


## Nomes dos botões do dispositivo, para os textos do tutorial.
func hints(pf: String) -> Dictionary:
	if pf == "kb1":
		return {"mov": "A / D", "jump": "ESPAÇO ou W", "atk": "F", "spc": "G", "ult": "T", "shd": "H",
			"up": "W", "down": "S"}
	if pf == "kb2":
		return {"mov": "SETAS ESQ/DIR", "jump": "M (ou Num 0)", "atk": "VÍRGULA (,)", "spc": "PONTO (.)", "ult": "BARRA (/)",
			"shd": "PONTO-E-VÍRGULA (;)", "up": "SETA CIMA", "down": "SETA BAIXO"}
	return {"mov": "ANALÓGICO", "jump": "A / XIS", "atk": "X / QUADRADO",
		"spc": "B / BOLINHA", "ult": "Y / TRIÂNGULO", "shd": "LB / RB (L1 / R1)", "up": "ANALÓGICO PARA CIMA",
		"down": "ANALÓGICO PARA BAIXO"}


func held(pf: String, a: String) -> bool:
	return pf != "" and Input.is_action_pressed(pf + "_" + a)


func just(pf: String, a: String) -> bool:
	return pf != "" and Input.is_action_just_pressed(pf + "_" + a)


## Primeiro dispositivo que acabou de apertar a ação (ou "").
func any_just(a: String) -> String:
	for pf in prefixes:
		if Input.is_action_just_pressed(pf + "_" + a):
			return pf
	return ""


func _setup(pf: String) -> void:
	for a in ACTIONS:
		_add_action(pf + "_" + a, 0.4)
	if pf.begins_with("j"):
		var dev := int(pf.substr(1))
		_add_axis(pf + "_left", dev, JOY_AXIS_LEFT_X, -1.0)
		_add_axis(pf + "_right", dev, JOY_AXIS_LEFT_X, 1.0)
		_add_axis(pf + "_up", dev, JOY_AXIS_LEFT_Y, -1.0)
		_add_axis(pf + "_down", dev, JOY_AXIS_LEFT_Y, 1.0)
		_add_button(pf + "_left", dev, JOY_BUTTON_DPAD_LEFT)
		_add_button(pf + "_right", dev, JOY_BUTTON_DPAD_RIGHT)
		_add_button(pf + "_up", dev, JOY_BUTTON_DPAD_UP)
		_add_button(pf + "_down", dev, JOY_BUTTON_DPAD_DOWN)
		_add_button(pf + "_jump", dev, JOY_BUTTON_A)
		_add_button(pf + "_ult", dev, JOY_BUTTON_Y)
		_add_button(pf + "_attack", dev, JOY_BUTTON_X)
		_add_button(pf + "_special", dev, JOY_BUTTON_B)
		_add_button(pf + "_shield", dev, JOY_BUTTON_LEFT_SHOULDER)
		_add_button(pf + "_shield", dev, JOY_BUTTON_RIGHT_SHOULDER)
		_add_axis(pf + "_shield", dev, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_add_axis(pf + "_shield", dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	elif pf == "kb1":
		_add_key(pf + "_left", KEY_A)
		_add_key(pf + "_right", KEY_D)
		_add_key(pf + "_up", KEY_W)
		_add_key(pf + "_down", KEY_S)
		_add_key(pf + "_jump", KEY_SPACE)
		_add_key(pf + "_attack", KEY_F)
		_add_key(pf + "_special", KEY_G)
		_add_key(pf + "_ult", KEY_T)
		_add_key(pf + "_shield", KEY_H)
	elif pf == "kb2":
		_add_key(pf + "_left", KEY_LEFT, true)
		_add_key(pf + "_right", KEY_RIGHT, true)
		_add_key(pf + "_up", KEY_UP, true)
		_add_key(pf + "_down", KEY_DOWN, true)
		_add_key(pf + "_jump", KEY_M, true)
		_add_key(pf + "_attack", KEY_COMMA, true)
		_add_key(pf + "_special", KEY_PERIOD, true)
		_add_key(pf + "_ult", KEY_SLASH, true)
		_add_key(pf + "_shield", KEY_SEMICOLON, true)
		# alternativa pelo teclado numérico
		_add_key(pf + "_jump", KEY_KP_0, true)
		_add_key(pf + "_attack", KEY_KP_1, true)
		_add_key(pf + "_special", KEY_KP_2, true)
		_add_key(pf + "_ult", KEY_KP_4, true)
		_add_key(pf + "_shield", KEY_KP_3, true)


func _add_action(n: String, deadzone: float) -> void:
	if not InputMap.has_action(n):
		InputMap.add_action(n, deadzone)


func _add_key(action: String, key: Key, logical := false) -> void:
	var e := InputEventKey.new()
	if logical:
		e.keycode = key
	else:
		e.physical_keycode = key
	InputMap.action_add_event(action, e)


func _add_button(action: String, dev: int, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = button
	InputMap.action_add_event(action, e)


func _add_axis(action: String, dev: int, axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)
