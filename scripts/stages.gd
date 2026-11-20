extends RefCounted
## Mapas (chão, plataformas e perigos) e paletas de cores do cenário.
##
## Cada mapa: name, hz_text (descrição do perigo), style (chão: island | grass | stone | metal),
## pstyle (plataformas: wood | metal | stone | rock), ground ([x0, x1, topo, espessura]),
## plats (ver _p), spawns (5 pontos de pé, da esquerda para a direita), respawn e hz (perigos).

const Art := preload("res://scripts/art.gd")

static var _stages: Array = []
static var _pals: Array = []


# ---------------------------------------------------------------- paletas

static func palettes() -> Array:
	if not _pals.is_empty():
		return _pals
	_pals = [
		_pal("Crepúsculo", ["0e1731", "24476b", "e8a46a"], ["e9eef5", "c9d3e0"], Color(0.8, 0.9, 1.0, 0.05), 1.0,
			[Color(0.4, 1.0, 0.8, 0.07), Color(0.5, 0.8, 1.0, 0.05)], Color(0.78, 0.86, 0.95, 0.32),
			["3b5f86", "2b4668", "1c3049"], ["33475f", "4fb58a", "6b4b52", "3f9a78", "57b894"], [0.09, 0.4],
			["2a3a52", "3a4f6c", "4a6385"], ["6b5545", "43342b"], ["43c682", "3fb878", "62dc93", "86f2ad"],
			["d9a86c", "7a5538", "f6d9a8"], ["5ef2e0", "ffb45e"], ["5a6b82", "2e3a4c", "8fa2bb"]),
		_pal("Dia ensolarado", ["3a7bd5", "7fc4f0", "fff1c9"], ["fff3a0", "ffe066"], Color(1.0, 0.95, 0.6, 0.08), 0.0,
			[Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)], Color(1, 1, 1, 0.75),
			["8ccf8a", "66b56f", "4a9a5a"], ["8a7a6a", "6fd07a", "7a5236", "3f9a4a", "66c06a"], [0.15, 0.15],
			["6b5a4a", "8a7560", "a89078"], ["8a6040", "5a3d28"], ["4fc35a", "4cbf5a", "7ee07a", "a8f59a"],
			["e0b070", "8a5a30", "ffe2b0"], ["7fe8ff", "ffd04a"], ["8a9ab0", "4a5668", "c0ccdb"]),
		_pal("Noite roxa", ["0c0618", "2e1550", "8a3a7a"], ["f2d8ff", "d0a8e8"], Color(0.9, 0.6, 1.0, 0.06), 1.0,
			[Color(1.0, 0.4, 0.9, 0.08), Color(0.6, 0.4, 1.0, 0.06)], Color(0.7, 0.55, 0.9, 0.25),
			["4a2f70", "352152", "221537"], ["3a2a55", "9a5ad0", "4a3050", "7a3ab0", "a066d8"], [0.8, 0.5],
			["2a1a40", "3d2860", "553a80"], ["4a3050", "2a1a30"], ["9a5ad0", "8a4ac8", "b070f0", "d4a8ff"],
			["b08a70", "5a3a40", "e8c8b0"], ["ff7af0", "7ac8ff"], ["4a4060", "2a2238", "7a6a9a"]),
		_pal("Inferno", ["1a0404", "4a0e0a", "ff6a2a"], ["ffb070", "e07040"], Color(1.0, 0.5, 0.2, 0.08), 0.3,
			[Color(1.0, 0.4, 0.1, 0.07), Color(1.0, 0.2, 0.1, 0.05)], Color(0.4, 0.2, 0.18, 0.45),
			["5a1e14", "3e140e", "260a08"], ["3a1a14", "a04020", "2a1410", "c0501a", "e07028"], [0.04, 0.8],
			["2a1210", "40201a", "5a2e24"], ["4a2418", "2a120c"], ["d05a20", "b8401a", "e86a2a", "ffb050"],
			["8a5a40", "3a2018", "c08a60"], ["ff5a3a", "ffd04a"], ["5a3a34", "2e1a16", "8a6058"]),
		_pal("Gelo", ["0a1a30", "2f6f9a", "cfefff"], ["ffffff", "d0e8f8"], Color(0.8, 0.95, 1.0, 0.07), 1.0,
			[Color(0.4, 1.0, 0.9, 0.1), Color(0.4, 0.7, 1.0, 0.08)], Color(0.9, 0.97, 1.0, 0.4),
			["8ab8d8", "6094b8", "3f6e90"], ["5a7a98", "e8f6ff", "4a5a6a", "bfe0f0", "e8f8ff"], [0.55, 0.15],
			["3a5a78", "5a7e9e", "7ea2c0"], ["6a8aa8", "3a5470"], ["bfe6f8", "cfeaf8", "eef8ff", "ffffff"],
			["a8c8e0", "4a6a88", "e8f6ff"], ["9af0ff", "c8b0ff"], ["7a92aa", "3e5266", "b8cede"]),
		_pal("Deserto", ["2a2050", "c87a5a", "ffd890"], ["fff0c0", "f0d090"], Color(1.0, 0.9, 0.6, 0.07), 0.6,
			[Color(1.0, 0.7, 0.4, 0.05), Color(1.0, 0.6, 0.5, 0.04)], Color(1.0, 0.85, 0.7, 0.3),
			["c08850", "a06a3a", "7a4a28"], ["9a6a40", "d8b060", "6a4a2a", "6a9a40", "8ab850"], [0.1, 0.5],
			["7a4a2a", "9a6438", "b88050"], ["a87040", "6a4020"], ["c8a050", "d8b060", "f0d088", "fff0b8"],
			["c89058", "6a4020", "f0c890"], ["5ae8c8", "ff8a4a"], ["9a7a5a", "5a4028", "c8a880"]),
		_pal("Tóxico", ["06140c", "163a22", "9ad050"], ["d8ffb0", "a8e080"], Color(0.6, 1.0, 0.4, 0.07), 0.7,
			[Color(0.5, 1.0, 0.3, 0.09), Color(0.8, 1.0, 0.3, 0.06)], Color(0.5, 0.7, 0.4, 0.3),
			["2f5a32", "22442a", "142c1a"], ["2a3a2a", "7ad040", "3a3020", "5aa030", "8ad040"], [0.25, 0.7],
			["1e2e22", "2e4232", "425a44"], ["3a3a24", "222214"], ["9aff40", "6ac030", "9ae040", "cfff70"],
			["9a8a50", "4a4020", "d0c080"], ["c8ff40", "ff5ad0"], ["4a5a48", "263024", "7a8e74"]),
		_pal("Sakura", ["3a2a5a", "d07aa0", "ffe2ec"], ["fff4f8", "f8d0e0"], Color(1.0, 0.85, 0.92, 0.08), 0.6,
			[Color(1.0, 0.7, 0.85, 0.07), Color(1.0, 0.85, 0.95, 0.05)], Color(1.0, 0.92, 0.96, 0.45),
			["c07aa0", "9a5a84", "6e3e64"], ["7a5a7a", "f0a0c0", "5a3a40", "f090b8", "ffc0d8"], [0.93, 0.35],
			["4a3450", "6a4c70", "8a6a90"], ["7a5050", "4a3030"], ["e888b0", "e080a8", "ffa8c8", "ffd8e8"],
			["e0b090", "7a4a40", "fff0d8"], ["ff9ad0", "fff0a0"], ["8a7090", "4a3a50", "c0a8c8"]),
	]
	return _pals


static func _pal(name: String, sky: Array, moon: Array, glow: Color, star_a: float, aurora: Array, cloud: Color,
		hills: Array, mini: Array, mote: Array, rock: Array, dirt: Array, grass: Array, plank: Array,
		crystal: Array, metal: Array) -> Dictionary:
	return {
		"name": name,
		"sky_top": Color(sky[0]), "sky_mid": Color(sky[1]), "sky_low": Color(sky[2]),
		"moon": Color(moon[0]), "moon_spot": Color(moon[1]), "moon_glow": glow, "star_a": star_a,
		"aurora1": aurora[0], "aurora2": aurora[1], "cloud": cloud,
		"hill1": Color(hills[0]), "hill2": Color(hills[1]), "hill3": Color(hills[2]),
		"mini_rock": Color(mini[0]), "mini_grass": Color(mini[1]), "trunk": Color(mini[2]),
		"leaf1": Color(mini[3]), "leaf2": Color(mini[4]), "mote_h": float(mote[0]), "mote_s": float(mote[1]),
		"rock1": Color(rock[0]), "rock2": Color(rock[1]), "rock3": Color(rock[2]),
		"dirt": Color(dirt[0]), "dirt_dark": Color(dirt[1]),
		"moss": Color(grass[0]), "grass1": Color(grass[1]), "grass2": Color(grass[2]), "grass3": Color(grass[3]),
		"plank": Color(plank[0]), "plank_dark": Color(plank[1]), "plank_light": Color(plank[2]),
		"crystal1": Color(crystal[0]), "crystal2": Color(crystal[1]),
		"metal1": Color(metal[0]), "metal2": Color(metal[1]), "metal3": Color(metal[2]),
	}


static func palette(i: int) -> Dictionary:
	return palettes()[clampi(i, 0, palettes().size() - 1)]


## Sorteia uma paleta: 30% de chance da original (Crepúsculo), senão uma das outras.
static func random_palette() -> int:
	if randf() < 0.3:
		return 0
	return 1 + randi() % (palettes().size() - 1)


# ---------------------------------------------------------------- mapas

static func count() -> int:
	return all().size()


static func get_stage(i: int) -> Dictionary:
	return all()[clampi(i, 0, count() - 1)]


static func _p(x: float, y: float, half: float, extra := {}) -> Dictionary:
	var d := {"x": x, "y": y, "half": half, "mx": 0.0, "my": 0.0, "sp": 0.0, "ph": 0.0, "crumble": false}
	d.merge(extra, true)
	return d


static func _row(xs: Array, y: float) -> Array:
	var out: Array = []
	for x in xs:
		out.append(Vector2(float(x), y))
	return out


static func all() -> Array:
	if not _stages.is_empty():
		return _stages
	var S: Array = []
	# 0 — o palco original, sem perigos
	S.append({"name": "Ilha do Crepúsculo", "hz_text": "Sem perigos: o palco clássico.",
		"style": "island", "pstyle": "wood",
		"ground": [[340, 940, 520, 40]],
		"plats": [_p(440, 430, 100), _p(840, 430, 100), _p(640, 330, 100)],
		"spawns": _row([430, 535, 640, 745, 850], 520), "respawn": Vector2(640, 100), "hz": []})
	# 1
	S.append({"name": "Serraria", "hz_text": "Serras circulares correm pelos trilhos. Pule por cima delas!",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "saw", "a": Vector2(320, 498), "b": Vector2(960, 498), "r": 24.0, "period": 8.0, "ph": 0.0},
			{"type": "saw", "a": Vector2(380, 252), "b": Vector2(900, 252), "r": 26.0, "period": 5.5, "ph": 1.4}]})
	# 2
	S.append({"name": "Vulcão", "hz_text": "A lava sobe de tempos em tempos e cobre as ilhas baixas. Encostou na lava, perdeu uma vida!",
		"style": "stone", "pstyle": "stone",
		"ground": [[290, 520, 500, 70], [580, 700, 460, 110], [760, 990, 500, 70]],
		"plats": [_p(420, 400, 70), _p(860, 400, 70), _p(640, 320, 90)],
		"spawns": [Vector2(360, 500), Vector2(450, 500), Vector2(640, 460), Vector2(830, 500), Vector2(920, 500)],
		"respawn": Vector2(640, 100),
		"hz": [{"type": "lava", "low": 650.0, "high": 478.0, "period": 18.0, "ph": 0.0}]})
	# 3
	S.append({"name": "Laboratório", "hz_text": "Lasers disparam em três alturas. A linha pisca antes do disparo.",
		"style": "metal", "pstyle": "metal",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(460, 420, 90), _p(820, 420, 90), _p(640, 320, 90)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "laser", "y": 492.0, "x0": 236.0, "x1": 1044.0, "period": 6.0, "ph": 2.0, "warn": 1.2, "on": 0.6},
			{"type": "laser", "y": 392.0, "x0": 236.0, "x1": 1044.0, "period": 6.0, "ph": 4.0, "warn": 1.2, "on": 0.6},
			{"type": "laser", "y": 292.0, "x0": 236.0, "x1": 1044.0, "period": 6.0, "ph": 3.0, "warn": 1.2, "on": 0.6}]})
	# 4
	S.append({"name": "Chuva de Meteoros", "hz_text": "Meteoros caem do céu. Fuja das marcas vermelhas no chão!",
		"style": "grass", "pstyle": "wood",
		"ground": [[330, 950, 520, 40]],
		"plats": [_p(430, 420, 90), _p(850, 420, 90), _p(640, 320, 90)],
		"spawns": _row([420, 530, 640, 750, 860], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "meteor", "every": 1.3, "x0": 300.0, "x1": 980.0, "acc": -1.0}]})
	# 5
	S.append({"name": "Pico dos Ventos", "hz_text": "Rajadas de vento empurram todos para um lado (mais forte no ar).",
		"style": "grass", "pstyle": "wood",
		"ground": [[460, 820, 520, 40]],
		"plats": [_p(300, 430, 80), _p(980, 430, 80), _p(640, 320, 100)],
		"spawns": [Vector2(300, 430), Vector2(520, 520), Vector2(640, 520), Vector2(760, 520), Vector2(980, 430)],
		"respawn": Vector2(640, 100),
		"hz": [{"type": "wind", "period": 10.0, "warn": 1.5, "dur": 4.0, "force": 160.0, "ph": 6.0}]})
	# 6
	S.append({"name": "Arquipélago Flutuante", "hz_text": "Não há chão! Só ilhas flutuantes que sobem, descem e deslizam.",
		"style": "grass", "pstyle": "rock",
		"ground": [],
		"plats": [_p(640, 490, 150, {"my": 14.0, "sp": 0.7}), _p(330, 400, 90, {"my": 60.0, "sp": 0.9}),
			_p(950, 400, 90, {"my": 60.0, "sp": 0.9, "ph": PI}), _p(640, 290, 110, {"mx": 170.0, "sp": 0.45})],
		"spawns": [Vector2(330, 400), Vector2(560, 490), Vector2(640, 490), Vector2(720, 490), Vector2(950, 400)],
		"respawn": Vector2(640, 140), "hz": []})
	# 7
	S.append({"name": "Estação de Trem", "hz_text": "Um trem cruza o chão a toda velocidade. Suba nas plataformas quando o sinal piscar!",
		"style": "stone", "pstyle": "metal",
		"ground": [[240, 1040, 520, 40]],
		"plats": [_p(440, 400, 100), _p(840, 400, 100), _p(640, 290, 100)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "train", "period": 13.0, "warn": 2.5, "speed": 1500.0, "len": 620.0, "y": 520.0, "h": 78.0,
			"ph": 7.0}]})
	# 8
	S.append({"name": "Fábrica", "hz_text": "Esteiras levam todos para o meio, onde prensas gigantes esmagam o chão.",
		"style": "metal", "pstyle": "metal",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(380, 390, 70), _p(900, 390, 70), _p(640, 300, 80)],
		"spawns": _row([360, 600, 640, 680, 920], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "conveyor", "x0": 330.0, "x1": 620.0, "y": 520.0, "v": 110.0},
			{"type": "conveyor", "x0": 660.0, "x1": 950.0, "y": 520.0, "v": -110.0},
			{"type": "crusher", "x": 500.0, "w": 96.0, "y": 520.0, "rest": 150.0, "period": 5.0, "ph": 0.0},
			{"type": "crusher", "x": 780.0, "w": 96.0, "y": 520.0, "rest": 150.0, "period": 5.0, "ph": 2.5}]})
	# 9
	S.append({"name": "Usina Elétrica", "hz_text": "Partes do chão ficam eletrificadas. Saia de cima quando faiscar!",
		"style": "metal", "pstyle": "metal",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(430, 410, 90), _p(850, 410, 90), _p(640, 310, 90)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "electric", "segs": [[330.0, 530.0], [540.0, 740.0], [750.0, 950.0]], "y": 520.0,
			"period": 3.4, "warn": 1.2, "on": 1.0, "ph": 2.3}]})
	# 10
	S.append({"name": "Ruínas Desmoronando", "hz_text": "Sem chão, e as plataformas desabam quando alguém pisa. Elas voltam depois.",
		"style": "stone", "pstyle": "stone",
		"ground": [],
		"plats": [_p(380, 500, 95, {"crumble": true}), _p(640, 500, 105, {"crumble": true}),
			_p(900, 500, 95, {"crumble": true}), _p(510, 385, 75, {"crumble": true}),
			_p(770, 385, 75, {"crumble": true}), _p(640, 270, 90, {"crumble": true})],
		"spawns": [Vector2(340, 500), Vector2(420, 500), Vector2(640, 500), Vector2(860, 500), Vector2(940, 500)],
		"respawn": Vector2(640, 120), "hz": []})
	# 11
	S.append({"name": "Templo do Pêndulo", "hz_text": "Dois pêndulos gigantes varrem o palco. Pule ou fique nas plataformas.",
		"style": "stone", "pstyle": "stone",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(400, 400, 80), _p(880, 400, 80), _p(640, 290, 90)],
		"spawns": _row([380, 520, 640, 760, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "pendulum", "pivot": Vector2(480, 20), "len": 440.0, "amp": 0.8, "period": 3.6, "r": 30.0,
				"ph": PI / 2.0},
			{"type": "pendulum", "pivot": Vector2(800, 20), "len": 440.0, "amp": 0.8, "period": 3.6, "r": 30.0,
				"ph": PI / 2.0}]})
	# 12
	S.append({"name": "Gêiseres", "hz_text": "Gêiseres jorram do chão e lançam todo mundo para o alto.",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(520, 400, 70), _p(760, 400, 70), _p(640, 280, 80)],
		"spawns": _row([340, 500, 640, 780, 940], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "geyser", "x": 400.0, "y": 520.0, "period": 6.0, "ph": 3.0, "warn": 1.3, "on": 1.3, "h": 420.0, "w": 56.0},
			{"type": "geyser", "x": 640.0, "y": 520.0, "period": 6.0, "ph": 5.0, "warn": 1.3, "on": 1.3, "h": 420.0, "w": 56.0},
			{"type": "geyser", "x": 880.0, "y": 520.0, "period": 6.0, "ph": 4.0, "warn": 1.3, "on": 1.3, "h": 420.0, "w": 56.0}]})
	# 13
	S.append({"name": "Forte dos Canhões", "hz_text": "Canhões nas torres atiram balas de ferro em duas alturas.",
		"style": "stone", "pstyle": "stone",
		"ground": [[360, 920, 520, 40]],
		"plats": [_p(480, 410, 80), _p(800, 410, 80), _p(640, 310, 90)],
		"spawns": _row([420, 530, 640, 750, 860], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "cannon", "pos": Vector2(150, 494), "dir": 1, "period": 4.0, "ph": 0.5, "speed": 520.0},
			{"type": "cannon", "pos": Vector2(1130, 494), "dir": -1, "period": 4.0, "ph": 2.5, "speed": 520.0},
			{"type": "cannon", "pos": Vector2(150, 380), "dir": 1, "period": 4.0, "ph": 1.5, "speed": 520.0},
			{"type": "cannon", "pos": Vector2(1130, 380), "dir": -1, "period": 4.0, "ph": 3.5, "speed": 520.0}]})
	# 14
	S.append({"name": "Buraco Negro", "hz_text": "Um buraco negro surge no céu e puxa todos para ele. Há um abismo no meio do palco.",
		"style": "stone", "pstyle": "metal",
		"ground": [[320, 580, 520, 40], [700, 960, 520, 40]],
		"plats": [_p(450, 400, 90), _p(830, 400, 90), _p(640, 300, 70)],
		"spawns": _row([360, 450, 540, 740, 900], 520), "respawn": Vector2(640, 220),
		"hz": [{"type": "vortex", "pos": Vector2(640, 130), "period": 11.0, "warn": 1.5, "on": 4.5, "pull": 200.0,
			"r": 650.0, "core": 42.0, "ph": 7.0}]})
	# 15
	S.append({"name": "Caverna de Espinhos", "hz_text": "Estalactites caem do teto e o fosso do meio é cheio de espinhos.",
		"style": "stone", "pstyle": "stone",
		"ground": [[300, 520, 480, 90], [760, 980, 480, 90], [520, 760, 545, 40]],
		"plats": [_p(640, 410, 80), _p(410, 360, 70), _p(870, 360, 70)],
		"spawns": [Vector2(360, 480), Vector2(450, 480), Vector2(640, 410), Vector2(830, 480), Vector2(920, 480)],
		"respawn": Vector2(640, 100),
		"hz": [{"type": "stalactite", "every": 1.8, "x0": 310.0, "x1": 970.0, "acc": -1.0},
			{"type": "spikes", "x0": 520.0, "x1": 760.0, "y": 545.0}]})
	# 16
	S.append({"name": "Roda Gigante", "hz_text": "Plataformas giram em volta de um eixo com lâminas. Não encoste no meio!",
		"style": "metal", "pstyle": "metal",
		"ground": [[440, 840, 520, 40]],
		"plats": [_p(640, 330, 60, {"mx": 150.0, "my": 150.0, "sp": 0.5, "ph": 0.0, "circ": true}),
			_p(640, 330, 60, {"mx": 150.0, "my": 150.0, "sp": 0.5, "ph": PI / 2.0, "circ": true}),
			_p(640, 330, 60, {"mx": 150.0, "my": 150.0, "sp": 0.5, "ph": PI, "circ": true}),
			_p(640, 330, 60, {"mx": 150.0, "my": 150.0, "sp": 0.5, "ph": PI * 1.5, "circ": true})],
		"spawns": _row([480, 560, 640, 720, 800], 520), "respawn": Vector2(520, 100),
		"hz": [{"type": "hub", "pos": Vector2(640, 330), "r": 28.0, "orbit": 150.0}]})
	# 17
	S.append({"name": "Campo Minado", "hz_text": "Minas surgem no chão e explodem quando alguém encosta (ou sozinhas, depois de 3 s).",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "mines", "every": 1.4, "x0": 330.0, "x1": 950.0, "acc": 0.0}]})
	# 18
	S.append({"name": "Tornado", "hz_text": "Um tornado varre o palco e arremessa quem estiver no caminho. Corra dele!",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "tornado", "x0": 380.0, "x1": 900.0, "y": 520.0, "period": 12.0, "warn": 1.5, "dur": 7.0,
			"ph": 10.0}]})
	# 19
	S.append({"name": "Avalanche", "hz_text": "Bolas de neve rolam pelo chão, crescem e derrubam todo mundo. Pule por cima!",
		"style": "stone", "pstyle": "rock",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "snowball", "every": 3.6, "x0": 320.0, "x1": 960.0, "y": 520.0, "speed": 330.0, "acc": 1.5}]})
	# 20
	S.append({"name": "Tempestade", "hz_text": "Raios caem do céu, quase sempre em cima de alguém. A marca amarela avisa!",
		"style": "stone", "pstyle": "stone",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "lightning", "every": 2.0, "x0": 340.0, "x1": 940.0, "acc": 0.0}]})
	# 21
	S.append({"name": "Maré Alta", "hz_text": "A maré sobe e desce: na água você boia e a correnteza te leva para o lado.",
		"style": "grass", "pstyle": "wood",
		"ground": [[360, 920, 520, 40]],
		"plats": [_p(420, 400, 80), _p(860, 400, 80), _p(640, 290, 90)],
		"spawns": _row([420, 530, 640, 750, 860], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "tide", "low": 720.0, "high": 440.0, "period": 18.0, "current": 90.0, "ph": 0.0}]})
	# 22
	S.append({"name": "Fliperama", "hz_text": "Bumpers gigantes lançam quem encostar neles, como num pinball.",
		"style": "metal", "pstyle": "metal",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(300, 420, 70), _p(980, 420, 70)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "bumper", "pos": Vector2(480, 400), "amp": Vector2(0, 50), "period": 4.0, "ph": 0.0, "r": 32.0, "pow": 560.0},
			{"type": "bumper", "pos": Vector2(800, 400), "amp": Vector2(0, 50), "period": 4.0, "ph": PI, "r": 32.0, "pow": 560.0},
			{"type": "bumper", "pos": Vector2(640, 280), "amp": Vector2(140, 0), "period": 5.0, "ph": 0.0, "r": 30.0, "pow": 560.0}]})
	# 23
	S.append({"name": "Lago Congelado", "hz_text": "O chão é de gelo: você escorrega e demora a parar. Estalactites de gelo caem do teto.",
		"style": "stone", "pstyle": "rock",
		"ground": [[310, 970, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([390, 515, 640, 765, 890], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "ice", "fric": 0.3}, {"type": "stalactite", "every": 2.3, "x0": 330.0, "x1": 950.0, "acc": 0.0}]})
	# 24
	S.append({"name": "Zona Lunar", "hz_text": "A gravidade some por alguns segundos: todos flutuam e os pulos ficam enormes. Meteoros caem.",
		"style": "stone", "pstyle": "rock",
		"ground": [[320, 960, 520, 40]],
		"plats": [_p(430, 420, 90), _p(850, 420, 90), _p(640, 310, 90), _p(640, 190, 70)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "gravity", "period": 10.0, "warn": 1.2, "dur": 5.0, "mult": 0.3, "ph": 8.0},
			{"type": "meteor", "every": 2.4, "x0": 300.0, "x1": 980.0, "acc": -1.0}]})
	# 25
	S.append({"name": "Tabuleiro Instável", "hz_text": "Blocos do chão piscam em vermelho e somem por uns segundos. Fique de olho onde pisa!",
		"style": "stone", "pstyle": "stone",
		"ground": [[340, 462, 520, 40], [458, 582, 520, 40], [578, 702, 520, 40], [698, 822, 520, 40], [818, 940, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "vanish", "period": 6.0, "warn": 1.3, "off": 2.4, "ph": 0.0}]})
	# 26
	S.append({"name": "Farol", "hz_text": "Um feixe de luz mortal gira em volta do farol, como uma barra de fogo. Pule por cima!",
		"style": "stone", "pstyle": "stone",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(400, 400, 80), _p(880, 400, 80), _p(640, 230, 80)],
		"spawns": _row([360, 470, 640, 810, 920], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "sweeper", "pos": Vector2(640, 470), "len": 430.0, "speed": 1.4, "ph": 3.2}]})
	# 27
	S.append({"name": "Câmara de Esmagamento", "hz_text": "Paredes de espinhos se fecham dos dois lados. Corra para o meio quando o aviso piscar!",
		"style": "metal", "pstyle": "metal",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 400, 80), _p(830, 400, 80), _p(640, 290, 80)],
		"spawns": _row([420, 530, 640, 750, 860], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "walls", "lx": 250.0, "rx": 1030.0, "depth": 150.0, "period": 11.0, "ph": 3.5}]})
	# 28
	S.append({"name": "Portais", "hz_text": "Portais azul e laranja teletransportam quem passar por eles, no chão e no ar.",
		"style": "metal", "pstyle": "metal",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(640, 410, 100), _p(400, 350, 70), _p(880, 350, 70)],
		"spawns": _row([430, 535, 640, 745, 850], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "portal", "a": Vector2(345, 470), "b": Vector2(935, 470), "r": 50.0},
			{"type": "portal", "a": Vector2(520, 280), "b": Vector2(760, 280), "r": 50.0}]})
	# 29
	S.append({"name": "Parque de Molas", "hz_text": "Molas no chão lançam você para o alto. Cuidado com as estalactites lá em cima!",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(520, 300, 80), _p(760, 300, 80)],
		"spawns": _row([390, 520, 640, 760, 890], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "spring", "x": 400.0, "y": 520.0, "w": 56.0, "power": 1050.0},
			{"type": "spring", "x": 640.0, "y": 520.0, "w": 56.0, "power": 1050.0},
			{"type": "spring", "x": 880.0, "y": 520.0, "w": 56.0, "power": 1050.0},
			{"type": "stalactite", "every": 2.6, "x0": 330.0, "x1": 950.0, "acc": 0.0}]})
	# 30
	S.append({"name": "Elevadores", "hz_text": "Plataformas sobem e descem sem parar e serras patrulham os lados do chão central.",
		"style": "metal", "pstyle": "metal",
		"ground": [[540, 740, 520, 40]],
		"plats": [_p(380, 360, 60, {"my": 160.0, "sp": 0.8}), _p(900, 360, 60, {"my": 160.0, "sp": 0.8, "ph": PI}),
			_p(640, 300, 80)],
		"spawns": _row([560, 600, 640, 680, 720], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "saw", "a": Vector2(460, 200), "b": Vector2(460, 480), "r": 24.0, "period": 4.5, "ph": 0.0},
			{"type": "saw", "a": Vector2(820, 200), "b": Vector2(820, 480), "r": 24.0, "period": 4.5, "ph": PI}]})
	# 31
	S.append({"name": "Terra dos Gigantes", "hz_text": "Um pé gigante pisa no chão e manda uma onda de choque para os lados. Pule a onda!",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "stomp", "every": 3.2, "x0": 340.0, "x1": 940.0, "acc": 0.5}]})
	# 32
	S.append({"name": "Pântano Tóxico", "hz_text": "Um poço de ácido separa as margens e o vento empurra para ele. O ácido te cospe de volta.",
		"style": "grass", "pstyle": "wood",
		"ground": [[290, 500, 520, 40], [780, 990, 520, 40]],
		"plats": [_p(640, 430, 90), _p(420, 390, 70), _p(860, 390, 70)],
		"spawns": [Vector2(340, 520), Vector2(430, 520), Vector2(640, 424), Vector2(850, 520), Vector2(940, 520)],
		"respawn": Vector2(640, 100),
		"hz": [{"type": "acid", "x0": 500.0, "x1": 780.0, "y": 548.0},
			{"type": "wind", "period": 9.0, "warn": 1.5, "dur": 3.5, "force": 150.0, "ph": 6.0}]})
	# 33
	S.append({"name": "Sistema Solar", "hz_text": "Um sol queima no centro e planetas giram em órbitas. O mais distante raspa o chão.",
		"style": "metal", "pstyle": "metal",
		"ground": [[340, 940, 520, 40]],
		"plats": [_p(430, 420, 80), _p(850, 420, 80), _p(640, 340, 70)],
		"spawns": _row([400, 520, 640, 760, 880], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "orbiter", "pos": Vector2(640, 220), "orbit": 0.0, "r": 28.0, "speed": 0.0, "ph": 0.0},
			{"type": "orbiter", "pos": Vector2(640, 220), "orbit": 130.0, "r": 16.0, "speed": 1.4, "ph": 0.0, "col": "7fb8d8"},
			{"type": "orbiter", "pos": Vector2(640, 220), "orbit": 210.0, "r": 20.0, "speed": -0.9, "ph": 2.0, "col": "e8884a"},
			{"type": "orbiter", "pos": Vector2(640, 220), "orbit": 290.0, "r": 15.0, "speed": 0.6, "ph": 4.0, "col": "9a7ad0"}]})
	# 34
	S.append({"name": "Dutos de Ar", "hz_text": "Ventiladores criam correntes de ar que te levam para o alto, direto para a serra lá em cima!",
		"style": "metal", "pstyle": "metal",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(640, 330, 100), _p(640, 190, 70)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "fan", "x": 430.0, "w": 90.0, "y": 520.0, "h": 380.0, "lift": 420.0},
			{"type": "fan", "x": 850.0, "w": 90.0, "y": 520.0, "h": 380.0, "lift": 420.0},
			{"type": "saw", "a": Vector2(330, 215), "b": Vector2(950, 215), "r": 26.0, "period": 7.0, "ph": 0.0}]})
	# 35
	S.append({"name": "Rio de Fogo", "hz_text": "Ilhas num mar de lava: cair é morte na hora. Bolas de fogo pulam da lava em arco!",
		"style": "stone", "pstyle": "stone",
		"ground": [[290, 470, 520, 40], [580, 700, 520, 40], [810, 990, 520, 40]],
		"plats": [_p(385, 400, 70), _p(640, 360, 70), _p(895, 400, 70)],
		"spawns": [Vector2(340, 520), Vector2(420, 520), Vector2(640, 520), Vector2(860, 520), Vector2(940, 520)],
		"respawn": Vector2(640, 100),
		"hz": [{"type": "lavapit", "x0": -100.0, "x1": 1380.0, "y": 560.0},
			{"type": "fireball", "x0": 480.0, "x1": 800.0, "y": 560.0, "every": 1.7, "acc": 0.0}]})
	# 36
	S.append({"name": "Maremoto", "hz_text": "Uma onda gigante varre o chão de ponta a ponta. Suba nas plataformas altas quando o aviso piscar!",
		"style": "grass", "pstyle": "wood",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 340, 90), _p(830, 340, 90), _p(640, 240, 80)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "bigwave", "period": 12.0, "warn": 2.0, "speed": 650.0, "y": 520.0, "h": 150.0, "ph": 9.0}]})
	# 37
	S.append({"name": "Teia de Aranha", "hz_text": "Teias atrasam seus passos e aranhas descem do teto em fios. Cuidado com a cabeça!",
		"style": "stone", "pstyle": "stone",
		"ground": [[300, 980, 520, 40]],
		"plats": [_p(450, 410, 90), _p(830, 410, 90), _p(640, 300, 90)],
		"spawns": _row([380, 510, 640, 770, 900], 520), "respawn": Vector2(640, 100),
		"hz": [{"type": "web", "x0": 340.0, "x1": 520.0, "y0": 420.0, "y1": 520.0},
			{"type": "web", "x0": 760.0, "x1": 940.0, "y0": 420.0, "y1": 520.0},
			{"type": "spider", "x": 430.0, "top": 110.0, "reach": 492.0, "period": 5.0, "ph": 0.0, "r": 20.0},
			{"type": "spider", "x": 640.0, "top": 110.0, "reach": 492.0, "period": 5.0, "ph": 1.7, "r": 20.0},
			{"type": "spider", "x": 850.0, "top": 110.0, "reach": 492.0, "period": 5.0, "ph": 3.4, "r": 20.0}]})
	# 38 — procedural: um mapa novo (chão, plataformas e perigos) é gerado a cada partida
	S.append(_gen())
	_stages = S
	return _stages


# ---------------------------------------------------------------- mapa procedural

static func is_proc(i: int) -> bool:
	return bool(get_stage(i).get("proc", false))


## Gera de novo o mapa procedural (o último da lista). Chamado quando uma partida começa nele.
static func regenerate() -> void:
	all()[count() - 1] = _gen()


const HZ_NAMES := {"saw": "Serra", "laser": "Laser", "meteor": "Meteoros", "wind": "Vento", "geyser": "Gêiser",
	"conveyor": "Esteira", "electric": "Choque", "cannon": "Canhões", "mines": "Minas", "lightning": "Raios",
	"snowball": "Neve", "bumper": "Bumper", "pendulum": "Pêndulo", "stalactite": "Estalactites", "stomp": "Pé gigante",
	"orbiter": "Órbitas", "vortex": "Buraco negro", "tornado": "Tornado", "walls": "Paredes", "gravity": "Gravidade",
	"sweeper": "Farol", "spring": "Molas"}


static func _gen() -> Dictionary:
	var rg := RandomNumberGenerator.new()
	rg.randomize()
	var layout := rg.randi() % 4        # 0 chão largo | 1 duas ilhas | 2 sem chão | 3 chão estreito
	var style: String = ["grass", "stone", "metal"][rg.randi() % 3]
	var pstyle: String = ["wood", "metal", "stone", "rock"][rg.randi() % 4]
	var ground: Array = []
	var plats: Array = []
	var spawns: Array = []
	var gx0 := 640.0
	var gx1 := 640.0
	match layout:
		0, 3:
			var w := float(rg.randi_range(480, 680)) if layout == 0 else float(rg.randi_range(300, 380))
			gx0 = 640.0 - w / 2.0
			gx1 = 640.0 + w / 2.0
			ground.append([gx0, gx1, 520, 40])
			for k in 5:
				spawns.append(Vector2(lerpf(gx0 + 40.0, gx1 - 40.0, k / 4.0), 520.0))
		1:
			var g := float(rg.randi_range(110, 190))
			var w1 := float(rg.randi_range(170, 250))
			var w2 := float(rg.randi_range(170, 250))
			gx0 = 640.0 - g / 2.0 - w1
			gx1 = 640.0 + g / 2.0 + w2
			ground.append([gx0, 640.0 - g / 2.0, 520, 40])
			ground.append([640.0 + g / 2.0, gx1, 520, 40])
			plats.append(_p(640.0, 430.0, 100))
			spawns = [Vector2(gx0 + 40.0, 520.0), Vector2(gx0 + w1 - 40.0, 520.0), Vector2(640.0, 424.0),
				Vector2(gx1 - w2 + 40.0, 520.0), Vector2(gx1 - 40.0, 520.0)]
		2:
			plats.append(_p(400.0, 500.0, 100, {"my": float(rg.randi_range(0, 25)), "sp": rg.randf_range(0.6, 1.0)}))
			plats.append(_p(640.0, 490.0, 110))
			plats.append(_p(880.0, 500.0, 100, {"my": float(rg.randi_range(0, 25)), "sp": rg.randf_range(0.6, 1.0),
				"ph": PI}))
			gx0 = 300.0
			gx1 = 980.0
			spawns = [Vector2(400, 494), Vector2(450, 494), Vector2(640, 484), Vector2(850, 494), Vector2(900, 494)]
	# plataformas extras sorteadas (sem sobrepor)
	var want := rg.randi_range(2, 4)
	var tries := 0
	while want > 0 and tries < 40:
		tries += 1
		var half := float(rg.randi_range(60, 100))
		var px := float(rg.randi_range(310, 970))
		var py := float(rg.randi_range(250, 420))
		var ok := true
		for q in plats:
			if absf(px - float(q["x"])) < half + float(q["half"]) + 30.0 and absf(py - float(q["y"])) < 70.0:
				ok = false
		if ok:
			var ex := {}
			if rg.randf() < 0.3:
				ex = {"mx": float(rg.randi_range(50, 130)), "sp": rg.randf_range(0.5, 0.9), "ph": rg.randf() * TAU}
			plats.append(_p(px, py, half, ex))
			want -= 1
	# perigos: 2 (às vezes 3) sorteados de um conjunto adequado ao tipo de mapa
	var pool: Array = ["saw", "laser", "meteor", "wind", "geyser", "conveyor", "electric", "cannon", "mines",
		"lightning", "snowball", "pendulum", "stalactite", "stomp", "bumper", "orbiter"]
	if layout == 2:
		pool = ["meteor", "wind", "lightning", "cannon", "vortex", "bumper", "orbiter", "stalactite", "saw_air"]
	var nh := 2 + (1 if rg.randf() < 0.25 else 0)
	var picks: Array = []
	var hz: Array = []
	while picks.size() < nh:
		var id: String = pool[rg.randi() % pool.size()]
		if picks.has(id):
			continue
		picks.append(id)
		hz.append_array(_gen_hz(id, gx0, gx1, rg))
	var names: Array = []
	for id in picks:
		names.append(String(HZ_NAMES.get(id, "Serra")))
	return {"name": "Procedural", "proc": true,
		"hz_text": "Gerado do zero a cada partida: chão, plataformas e perigos sorteados. Agora: %s." % " + ".join(names),
		"style": style, "pstyle": pstyle, "ground": ground, "plats": plats, "spawns": spawns,
		"respawn": Vector2(640, 100), "hz": hz}


static func _gen_hz(id: String, gx0: float, gx1: float, rg: RandomNumberGenerator) -> Array:
	var gy := 520.0
	match id:
		"saw":
			return [{"type": "saw", "a": Vector2(gx0 - 20.0, gy - 22.0), "b": Vector2(gx1 + 20.0, gy - 22.0), "r": 24.0,
				"period": rg.randf_range(5.0, 8.0), "ph": rg.randf() * 6.0}]
		"saw_air":
			return [{"type": "saw", "a": Vector2(330.0, 330.0), "b": Vector2(950.0, 330.0), "r": 26.0,
				"period": rg.randf_range(5.0, 7.0), "ph": rg.randf() * 6.0}]
		"laser":
			return [{"type": "laser", "y": gy - 28.0, "x0": gx0 - 80.0, "x1": gx1 + 80.0, "period": 6.0,
				"ph": rg.randf() * 6.0, "warn": 1.2, "on": 0.6}]
		"meteor":
			return [{"type": "meteor", "every": rg.randf_range(1.3, 2.0), "x0": 300.0, "x1": 980.0, "acc": -1.0}]
		"wind":
			return [{"type": "wind", "period": 10.0, "warn": 1.5, "dur": 4.0, "force": 150.0, "ph": 6.0}]
		"geyser":
			var out: Array = []
			for k in 2:
				out.append({"type": "geyser", "x": rg.randf_range(gx0 + 40.0, gx1 - 40.0), "y": gy, "period": 6.0,
					"ph": rg.randf() * 6.0, "warn": 1.3, "on": 1.3, "h": 420.0, "w": 56.0})
			return out
		"conveyor":
			return [{"type": "conveyor", "x0": gx0, "x1": gx1, "y": gy, "v": 100.0 * (1.0 if rg.randf() < 0.5 else -1.0)}]
		"electric":
			var m1 := lerpf(gx0, gx1, 1.0 / 3.0)
			var m2 := lerpf(gx0, gx1, 2.0 / 3.0)
			return [{"type": "electric", "segs": [[gx0, m1 - 5.0], [m1 + 5.0, m2 - 5.0], [m2 + 5.0, gx1]], "y": gy,
				"period": 3.4, "warn": 1.2, "on": 1.0, "ph": 2.3}]
		"cannon":
			return [{"type": "cannon", "pos": Vector2(150, 494), "dir": 1, "period": 4.5, "ph": rg.randf() * 4.0, "speed": 500.0},
				{"type": "cannon", "pos": Vector2(1130, 494), "dir": -1, "period": 4.5, "ph": rg.randf() * 4.0, "speed": 500.0}]
		"mines":
			return [{"type": "mines", "every": 1.5, "x0": gx0 + 10.0, "x1": gx1 - 10.0, "acc": 0.0}]
		"lightning":
			return [{"type": "lightning", "every": 2.2, "x0": gx0, "x1": gx1, "acc": 0.0}]
		"snowball":
			return [{"type": "snowball", "every": 4.0, "x0": gx0 + 10.0, "x1": gx1 - 10.0, "y": gy, "speed": 320.0, "acc": 1.5}]
		"pendulum":
			return [{"type": "pendulum", "pivot": Vector2(640, 20), "len": 440.0, "amp": 0.8, "period": 3.6, "r": 30.0,
				"ph": PI / 2.0}]
		"stalactite":
			return [{"type": "stalactite", "every": 2.0, "x0": 330.0, "x1": 950.0, "acc": 0.0}]
		"stomp":
			return [{"type": "stomp", "every": 3.4, "x0": gx0 + 20.0, "x1": gx1 - 20.0, "acc": 0.5}]
		"bumper":
			return [{"type": "bumper", "pos": Vector2(640, 380), "amp": Vector2(130, 0), "period": 5.0, "ph": 0.0,
				"r": 30.0, "pow": 560.0}]
		"orbiter":
			return [{"type": "orbiter", "pos": Vector2(640, 260), "orbit": 170.0, "r": 18.0, "speed": 1.3, "ph": 0.0, "col": "e8884a"},
				{"type": "orbiter", "pos": Vector2(640, 260), "orbit": 240.0, "r": 15.0, "speed": -1.0, "ph": 2.0, "col": "7fb8d8"}]
		"vortex":
			return [{"type": "vortex", "pos": Vector2(640, 130), "period": 11.0, "warn": 1.5, "on": 4.5, "pull": 200.0,
				"r": 650.0, "core": 42.0, "ph": 7.0}]
	return []


## Índices dos pontos de nascimento para n lutadores (entre os 5 do mapa).
static func spawn_points(i: int, n: int) -> Array:
	var sp: Array = get_stage(i)["spawns"]
	var idx: Array = [0, 4]
	match n:
		1:
			idx = [2]
		3:
			idx = [0, 2, 4]
		4:
			idx = [0, 1, 3, 4]
		5, 6:
			idx = [0, 1, 2, 3, 4]
	var out: Array = []
	for k in idx:
		out.append(sp[k])
	if n >= 6:   # sexto lutador: ao lado do ponto central
		out.append(sp[2] + Vector2(46, 0))
	return out


# ---------------------------------------------------------------- miniatura (tela de mapas)

static func preview(ci: CanvasItem, r: Rect2, i: int, tt: float) -> void:
	var s := get_stage(i)
	var world := Rect2(120, 0, 1040, 640)
	var k := minf(r.size.x / world.size.x, r.size.y / world.size.y)
	var off := r.position + (r.size - world.size * k) / 2.0 - world.position * k
	var top := Color("16264a")
	var low := Color("3b4f7a")
	Art.grad_quad(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, low, low]))
	var gcol := Color("62dc93")
	match String(s["style"]):
		"stone":
			gcol = Color("8a96ab")
		"metal":
			gcol = Color("9fb3cc")
	# perigos de fundo
	for h in s["hz"]:
		match String(h["type"]):
			"lava":
				var y: float = h["high"]
				ci.draw_rect(Rect2(off + Vector2(world.position.x, y) * k, Vector2(world.size.x, 640.0 - y) * k),
					Color(1.0, 0.35, 0.1, 0.55))
			"vortex":
				var c: Vector2 = off + (h["pos"] as Vector2) * k
				circ(ci, c, 70.0 * k, Color(0.6, 0.3, 1.0, 0.35))
				circ(ci, c, 34.0 * k, Color(0.05, 0.0, 0.1))
			"geyser":
				var gx: float = h["x"]
				var gy: float = h["y"]
				ci.draw_rect(Rect2(off + Vector2(gx - 22.0, gy - float(h["h"])) * k, Vector2(44.0, float(h["h"])) * k),
					Color(0.6, 0.85, 1.0, 0.5))
	for g in s["ground"]:
		var gr := Rect2(off + Vector2(float(g[0]), float(g[2])) * k, Vector2(float(g[1]) - float(g[0]), float(g[3])) * k)
		ci.draw_rect(gr, gcol.darkened(0.45))
		ci.draw_rect(Rect2(gr.position, Vector2(gr.size.x, maxf(3.0, 12.0 * k))), gcol)
	for pd in s["plats"]:
		var y := float(pd["y"]) + float(pd["my"]) * sin(tt * float(pd["sp"]) + float(pd["ph"]))
		var pw := tt * float(pd["sp"]) + float(pd["ph"])
		var x := float(pd["x"]) + float(pd["mx"]) * (cos(pw) if pd.get("circ", false) else sin(pw))
		var hw: float = pd["half"]
		ci.draw_line(off + Vector2(x - hw, y) * k, off + Vector2(x + hw, y) * k,
			Color("8a96ab") if pd["crumble"] else Color("e0b070"), maxf(3.0, 12.0 * k))
	# perigos da frente
	var red := Color(1.0, 0.3, 0.25)
	for h in s["hz"]:
		match String(h["type"]):
			"saw":
				var a: Vector2 = off + (h["a"] as Vector2) * k
				var b: Vector2 = off + (h["b"] as Vector2) * k
				ci.draw_line(a, b, Color(0, 0, 0, 0.4), 2.0)
				circ(ci, a.lerp(b, 0.5 + 0.5 * sin(tt * 1.2 + float(h["ph"]))), float(h["r"]) * k + 2.0, Color("dfe6ee"))
			"laser":
				ci.draw_line(off + Vector2(float(h["x0"]), float(h["y"])) * k, off + Vector2(float(h["x1"]), float(h["y"])) * k,
					red, 2.0)
			"meteor", "stalactite":
				for q in 3:
					var mx := lerpf(float(h["x0"]), float(h["x1"]), (q + 0.5) / 3.0)
					var my := fposmod(tt * 160.0 + q * 140.0, 480.0)
					circ(ci, off + Vector2(mx, my) * k, 4.0, Color(1.0, 0.6, 0.2) if h["type"] == "meteor" else Color("c9d3e0"))
			"wind":
				for q in 3:
					var p := off + Vector2(500.0 + q * 140.0, 200.0 + q * 70.0) * k
					ci.draw_line(p, p + Vector2(18, 0), Color(1, 1, 1, 0.8), 2.0)
					ci.draw_line(p + Vector2(18, 0), p + Vector2(12, -4), Color(1, 1, 1, 0.8), 2.0)
					ci.draw_line(p + Vector2(18, 0), p + Vector2(12, 4), Color(1, 1, 1, 0.8), 2.0)
			"train":
				var tx := world.position.x + fposmod(tt * 300.0, world.size.x - float(h["len"]) * 0.6)
				ci.draw_rect(Rect2(off + Vector2(tx, float(h["y"]) - float(h["h"])) * k, Vector2(float(h["len"]) * 0.6, float(h["h"])) * k),
					Color("c8553d"))
			"crusher":
				var cx: float = h["x"]
				var cy := lerpf(float(h["rest"]), float(h["y"]), 0.5 + 0.5 * sin(tt * 2.0 + float(h["ph"])))
				ci.draw_rect(Rect2(off + Vector2(cx - 48.0, cy - 90.0) * k, Vector2(96.0, 90.0) * k), Color("6a7a8e"))
			"conveyor", "electric":
				var yy: float = h["y"]
				var x0: float = h["x0"] if h.has("x0") else 330.0
				var x1: float = h["x1"] if h.has("x1") else 950.0
				ci.draw_line(off + Vector2(x0, yy - 4.0) * k, off + Vector2(x1, yy - 4.0) * k,
					Color(1.0, 0.85, 0.2) if h["type"] == "conveyor" else Color(0.5, 0.9, 1.0), 2.0)
			"pendulum":
				var a2 := float(h["amp"]) * sin(tt * TAU / float(h["period"]) + float(h["ph"]))
				var pv: Vector2 = h["pivot"]
				var bp := pv + Vector2(sin(a2), cos(a2)) * float(h["len"])
				ci.draw_line(off + pv * k, off + bp * k, Color(0.8, 0.7, 0.5), 1.5)
				circ(ci, off + bp * k, float(h["r"]) * k, Color("4a4a58"))
			"cannon":
				var cp: Vector2 = h["pos"]
				circ(ci, off + cp * k, 6.0, Color("2a2a34"))
				var bx := fposmod(tt * 200.0 + float(h["ph"]) * 100.0, 900.0)
				circ(ci, off + (cp + Vector2(int(h["dir"]) * bx, 0.0)) * k, 3.0, Color("1a1a20"))
			"spikes":
				var sx0: float = h["x0"]
				var sx1: float = h["x1"]
				var n := 8
				for q in n:
					var bx0 := lerpf(sx0, sx1, float(q) / n)
					var bx1 := lerpf(sx0, sx1, float(q + 1) / n)
					Art.poly(ci, PackedVector2Array([off + Vector2(bx0, float(h["y"])) * k,
						off + Vector2(bx1, float(h["y"])) * k, off + Vector2((bx0 + bx1) / 2.0, float(h["y"]) - 22.0) * k]),
						Color("e8eef5"))
			"hub":
				circ(ci, off + (h["pos"] as Vector2) * k, float(h["r"]) * k + 3.0, Color("c9d3df"))
			"mines":
				for q in 3:
					circ(ci, off + Vector2(lerpf(float(h["x0"]), float(h["x1"]), (q + 0.5) / 3.0), 512.0) * k, 3.5, Color("e74c3c"))
			"tornado":
				var tx2 := lerpf(float(h["x0"]), float(h["x1"]), 0.5 - 0.5 * cos(tt * 1.2))
				for q in 6:
					ci.draw_line(off + Vector2(tx2 - 12.0 - q * 6.0, 520.0 - q * 55.0) * k,
						off + Vector2(tx2 + 12.0 + q * 6.0, 520.0 - q * 55.0) * k, Color(0.85, 0.9, 0.95, 0.8), 2.0)
			"snowball":
				circ(ci, off + Vector2(lerpf(float(h["x0"]), float(h["x1"]), fposmod(tt * 0.35, 1.0)), 500.0) * k, 6.0, Color.WHITE)
			"lightning":
				var lx := lerpf(float(h["x0"]), float(h["x1"]), fposmod(tt * 0.4, 1.0))
				ci.draw_line(off + Vector2(lx, 0.0) * k, off + Vector2(lx, 520.0) * k, Color(1, 0.95, 0.4), 2.0)
			"tide":
				var ty := lerpf(float(h["low"]), float(h["high"]), 0.5 - 0.5 * cos(tt * 0.8))
				ci.draw_rect(Rect2(off + Vector2(world.position.x, ty) * k, Vector2(world.size.x, 640.0 - ty) * k),
					Color(0.2, 0.55, 0.95, 0.5))
			"bumper":
				var w2 := tt * TAU / float(h["period"]) + float(h["ph"])
				circ(ci, off + ((h["pos"] as Vector2) + (h["amp"] as Vector2) * sin(w2)) * k, float(h["r"]) * k + 2.0, Color("ff4fa8"))
			"ice":
				for g in s["ground"]:
					ci.draw_rect(Rect2(off + Vector2(float(g[0]), float(g[2])) * k, Vector2(float(g[1]) - float(g[0]), 6.0 * k * 2.0)),
						Color(0.85, 0.97, 1.0, 0.8))
			"gravity":
				for q in 4:
					circ(ci, off + Vector2(400.0 + q * 150.0, fposmod(500.0 - tt * 60.0 - q * 90.0, 420.0) + 80.0) * k, 3.0, Color(1, 1, 1, 0.7))
			"vanish":
				var g0: Array = s["ground"][1]
				ci.draw_rect(Rect2(off + Vector2(float(g0[0]), float(g0[2])) * k, Vector2(float(g0[1]) - float(g0[0]), 12.0) * k),
					Color(0.1, 0.12, 0.2))
			"sweeper":
				var sa := tt * float(h["speed"]) + float(h["ph"])
				var sp0: Vector2 = h["pos"]
				ci.draw_line(off + sp0 * k, off + (sp0 + Vector2(cos(sa), sin(sa)) * float(h["len"])) * k, Color(1, 0.95, 0.5), 3.0)
			"walls":
				var dd := 120.0 * (0.5 - 0.5 * cos(tt * 1.5))
				ci.draw_rect(Rect2(off + Vector2(120.0, 40.0) * k, Vector2(float(h["lx"]) - 120.0 + dd, 600.0) * k), Color("6a7a8e"))
				ci.draw_rect(Rect2(off + Vector2(float(h["rx"]) - dd, 40.0) * k, Vector2(1160.0 - float(h["rx"]) + dd, 600.0) * k), Color("6a7a8e"))
			"portal":
				circ(ci, off + (h["a"] as Vector2) * k, 5.0, Color("4fb8ff"))
				circ(ci, off + (h["b"] as Vector2) * k, 5.0, Color("ff9a3c"))
			"spring":
				var spx: float = h["x"]
				ci.draw_rect(Rect2(off + Vector2(spx - 22.0, float(h["y"]) - 22.0) * k, Vector2(44.0, 22.0) * k), Color("e74c3c"))
			"acid":
				var ay: float = h["y"]
				ci.draw_rect(Rect2(off + Vector2(float(h["x0"]), ay) * k, Vector2(float(h["x1"]) - float(h["x0"]), 640.0 - ay) * k),
					Color(0.5, 0.95, 0.2, 0.8))
			"stomp":
				var fx6 := lerpf(float(h["x0"]), float(h["x1"]), 0.5 + 0.4 * sin(tt * 1.3))
				ci.draw_rect(Rect2(off + Vector2(fx6 - 60.0, 380.0 + 60.0 * sin(tt * 2.6)) * k, Vector2(120.0, 70.0) * k), Color("d49a62"))
			"orbiter":
				var oa := tt * float(h["speed"]) + float(h["ph"])
				var op: Vector2 = (h["pos"] as Vector2) + Vector2(cos(oa), sin(oa)) * float(h["orbit"])
				circ(ci, off + op * k, float(h["r"]) * k + 2.0, Color("ffd04a") if float(h["orbit"]) <= 0.0 else Color(String(h.get("col", "7fb8d8"))))
			"fan":
				ci.draw_rect(Rect2(off + Vector2(float(h["x"]) - float(h["w"]) / 2.0, float(h["y"]) - float(h["h"])) * k,
					Vector2(float(h["w"]), float(h["h"])) * k), Color(0.8, 0.95, 1.0, 0.3))
			"lavapit":
				var lpy: float = h["y"]
				ci.draw_rect(Rect2(off + Vector2(world.position.x, lpy) * k, Vector2(world.size.x, 640.0 - lpy) * k),
					Color(1.0, 0.35, 0.1, 0.85))
			"fireball":
				for q in 2:
					circ(ci, off + Vector2(lerpf(float(h["x0"]), float(h["x1"]), 0.3 + q * 0.4),
						float(h["y"]) - 60.0 - 40.0 * absf(sin(tt * 2.0 + q))) * k, 3.5, Color("ffb347"))
			"bigwave":
				var wx := world.position.x + fposmod(tt * 260.0, world.size.x - 280.0)
				ci.draw_rect(Rect2(off + Vector2(wx, float(h["y"]) - float(h["h"])) * k, Vector2(280.0, float(h["h"])) * k),
					Color(0.2, 0.55, 0.95, 0.85))
			"spider":
				var spy := lerpf(float(h["top"]), float(h["reach"]), 0.5 - 0.5 * cos(tt * 1.3 + float(h["ph"])))
				ci.draw_line(off + Vector2(float(h["x"]), 0.0) * k, off + Vector2(float(h["x"]), spy) * k, Color(1, 1, 1, 0.6), 1.0)
				circ(ci, off + Vector2(float(h["x"]), spy) * k, 4.0, Color("2a1a3a"))
			"web":
				ci.draw_rect(Rect2(off + Vector2(float(h["x0"]), float(h["y0"])) * k,
					Vector2(float(h["x1"]) - float(h["x0"]), float(h["y1"]) - float(h["y0"])) * k), Color(1, 1, 1, 0.25))


static func circ(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	Art.circ(ci, p, r, col)
