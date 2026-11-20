extends RefCounted
## Ajudantes de desenho: formas arredondadas, rostinhos, mãos flutuantes redondas e a fonte do jogo.

const INK := Color("2a2140")

static var _sb: StyleBoxFlat
static var _font: Font

# Geometria do mapa atual (atualizada pelo stage.gd a cada quadro).
static var grounds: Array = [Rect2(340, 520, 600, 40)]   # chão sólido: topo = position.y
static var plats: Array = [                                # plataformas: {p, half, on}
	{"p": Vector2(440, 430), "half": 100.0, "on": true},
	{"p": Vector2(840, 430), "half": 100.0, "on": true},
	{"p": Vector2(640, 330), "half": 100.0, "on": true}]
static var respawn := Vector2(640, 100)
static var lava_danger := -1.0    # altura que a lava vai alcançar logo (-1 = sem perigo); a IA foge dela
static var grav := 1.0            # multiplicador da gravidade (Zona Lunar)
static var fric := 1.0            # multiplicador de atrito/aceleração no chão (gelo < 1)
static var pal: Dictionary = {}                            # paleta de cores do cenário


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Segoe UI Black", "Trebuchet MS", "Verdana"])
		f.font_weight = 700
		_font = f
	return _font


## Chão (ou plataforma) logo abaixo de um ponto; devolve a altura Y da superfície ou -1.
static func surface_below(x: float, y: float) -> float:
	var best := -1.0
	for g in grounds:
		var r: Rect2 = g
		if x > r.position.x and x < r.end.x and y <= r.position.y + 4.0 and (best < 0.0 or r.position.y < best):
			best = r.position.y
	for pl in plats:
		if not pl["on"]:
			continue
		var p: Vector2 = pl["p"]
		var top: float = p.y - 6.0
		if absf(x - p.x) < float(pl["half"]) and y <= top + 4.0 and (best < 0.0 or top < best):
			best = top
	return best


## Superfície mais próxima de um ponto (para a IA se recuperar): {x0, x1, y}.
static func nearest_surface(pos: Vector2) -> Dictionary:
	var best := {}
	var bd := 1e12
	var cands: Array = []
	for g in grounds:
		var r: Rect2 = g
		cands.append({"x0": r.position.x, "x1": r.end.x, "y": r.position.y})
	for pl in plats:
		if pl["on"]:
			var p: Vector2 = pl["p"]
			cands.append({"x0": p.x - float(pl["half"]), "x1": p.x + float(pl["half"]), "y": p.y - 6.0})
	for c in cands:
		var q := Vector2(clampf(pos.x, float(c["x0"]) + 15.0, float(c["x1"]) - 15.0), float(c["y"]))
		# superfícies acima custam mais (é mais difícil subir)
		var d := pos.distance_squared_to(q) + (maxf(pos.y - q.y, 0.0) ** 2) * 0.5
		# superfícies que a lava vai cobrir ficam por último
		if lava_danger > 0.0 and float(c["y"]) > lava_danger - 6.0:
			d += 1e9
		if d < bd:
			bd = d
			best = c
	return best


# ---------------------------------------------------------------- desenho em lote
# No renderer Compatibility cada draw_circle / draw_colored_polygon / draw_arc / draw_polyline / StyleBox
# vira UM draw call (~40 us cada). Já draw_line, draw_primitive, draw_multiline e draw_texture_rect_region
# são agrupados em lote. Por isso as formas abaixo usam um atlas de texturas (círculos AA + bloco branco)
# e primitivas em lote.

const _CIRC := [[128, 0, 0], [64, 132, 0], [32, 132, 68], [16, 170, 68]]   # [diâmetro, x, y] no atlas
const _WHITE := Rect2(134, 108, 2, 2)
static var _atlas: ImageTexture
static var _rings: Dictionary = {}


static func _build_atlas() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for c in _CIRC:
		var d: int = c[0]
		var rr := d / 2.0
		for y in d:
			for x in d:
				var dist := Vector2(x + 0.5 - rr, y + 0.5 - rr).length()
				img.set_pixel(c[1] + x, c[2] + y, Color(1, 1, 1, clampf(rr - dist, 0.0, 1.0)))
	for y in 6:
		for x in 6:
			img.set_pixel(132 + x, 106 + y, Color.WHITE)
	_atlas = ImageTexture.create_from_image(img)


static func _cidx(r: float) -> int:
	for i in range(_CIRC.size() - 1, -1, -1):
		if _CIRC[i][0] * 0.5 >= r:
			return i
	return 0


static func circ(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	if _atlas == null:
		_build_atlas()
	var c: Array = _CIRC[_cidx(r)]
	var d: float = c[0]
	ci.draw_texture_rect_region(_atlas, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), Rect2(c[1], c[2], d, d), col)


static func fill_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	if _atlas == null:
		_build_atlas()
	ci.draw_texture_rect_region(_atlas, r, _WHITE, col)


## Retângulo arredondado só com preenchimento (7 comandos em lote).
static func _rr(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0 or col.a <= 0.0:
		return
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	if rad < 0.75:
		fill_rect(ci, r, col)
		return
	if _atlas == null:
		_build_atlas()
	var c: Array = _CIRC[_cidx(rad)]
	var h: float = c[0] * 0.5
	var sx: float = c[1]
	var sy: float = c[2]
	var q := Vector2(h, h)
	var dq := Vector2(rad, rad)
	var e := r.end
	ci.draw_texture_rect_region(_atlas, Rect2(r.position, dq), Rect2(Vector2(sx, sy), q), col)
	ci.draw_texture_rect_region(_atlas, Rect2(Vector2(e.x - rad, r.position.y), dq), Rect2(Vector2(sx + h, sy), q), col)
	ci.draw_texture_rect_region(_atlas, Rect2(Vector2(r.position.x, e.y - rad), dq), Rect2(Vector2(sx, sy + h), q), col)
	ci.draw_texture_rect_region(_atlas, Rect2(e - dq, dq), Rect2(Vector2(sx + h, sy + h), q), col)
	ci.draw_texture_rect_region(_atlas, Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), _WHITE, col)
	if r.size.y - rad * 2.0 > 0.0:
		ci.draw_texture_rect_region(_atlas, Rect2(r.position.x, r.position.y + rad, rad, r.size.y - rad * 2.0), _WHITE, col)
		ci.draw_texture_rect_region(_atlas, Rect2(e.x - rad, r.position.y + rad, rad, r.size.y - rad * 2.0), _WHITE, col)


static func _ring_tex(rad: int, bw: float) -> ImageTexture:
	var key := rad * 1000 + int(bw * 4.0)
	if _rings.has(key):
		return _rings[key]
	var s := rad * 2
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var inner := maxf(float(rad) - bw, 0.0)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - rad, y + 0.5 - rad).length()
			var a := clampf(rad - d, 0.0, 1.0) * (1.0 - clampf(inner - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_rings[key] = t
	return t


## Contorno (anel) de retângulo arredondado.
static func _ring(ci: CanvasItem, r: Rect2, rad: float, bw: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var ri := roundi(rad)
	var e := r.end
	if ri >= 1:
		var t := _ring_tex(ri, bw)
		var q := Vector2(ri, ri)
		ci.draw_texture_rect_region(t, Rect2(r.position, q), Rect2(Vector2.ZERO, q), col)
		ci.draw_texture_rect_region(t, Rect2(Vector2(e.x - ri, r.position.y), q), Rect2(Vector2(ri, 0), q), col)
		ci.draw_texture_rect_region(t, Rect2(Vector2(r.position.x, e.y - ri), q), Rect2(Vector2(0, ri), q), col)
		ci.draw_texture_rect_region(t, Rect2(e - q, q), Rect2(q, q), col)
	var w := r.size.x - ri * 2.0
	var hh := r.size.y - ri * 2.0
	if w > 0.0:
		ci.draw_rect(Rect2(r.position.x + ri, r.position.y, w, bw), col)
		ci.draw_rect(Rect2(r.position.x + ri, e.y - bw, w, bw), col)
	if hh > 0.0:
		ci.draw_rect(Rect2(r.position.x, r.position.y + ri, bw, hh), col)
		ci.draw_rect(Rect2(e.x - bw, r.position.y + ri, bw, hh), col)


## Retângulo de cantos arredondados (com borda e brilho opcionais).
static func rrect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, border := Color(0, 0, 0, 0),
		bw := 0.0, shadow := 0, shadow_col := Color(0, 0, 0, 0.3), shadow_off := Vector2(0, 4)) -> void:
	radius = float(maxi(int(radius), 0))
	if shadow > 0:
		var sh := float(shadow)
		_rr(ci, Rect2(r.position + shadow_off - Vector2(sh, sh) * 0.9, r.size + Vector2(sh, sh) * 1.8), radius + sh * 0.9,
			Color(shadow_col, shadow_col.a * 0.3))
		_rr(ci, Rect2(r.position + shadow_off - Vector2(sh, sh) * 0.45, r.size + Vector2(sh, sh) * 0.9), radius + sh * 0.45,
			Color(shadow_col, shadow_col.a * 0.4))
	var b := float(int(bw))
	if b > 0.0 and border.a > 0.0:
		_rr(ci, Rect2(r.position + Vector2(b, b), r.size - Vector2(b, b) * 2.0), maxf(radius - b, 0.0), fill)
		_ring(ci, r, radius, b, border)
	else:
		_rr(ci, r, radius, fill)


static func ellipse(ci: CanvasItem, p: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_set_transform(p, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	circ(ci, Vector2.ZERO, rx, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Polígono preenchido (em lote, via triângulos).
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3 or col.a <= 0.0:
		return
	var cols := PackedColorArray([col, col, col])
	if n == 3:
		ci.draw_primitive(pts, cols, PackedVector2Array())
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		for i in range(1, n - 1):
			ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), cols, PackedVector2Array())
		return
	for i in range(0, idx.size(), 3):
		ci.draw_primitive(PackedVector2Array([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]]), cols, PackedVector2Array())


## Quadrilátero com cor por vértice (degradês).
static func grad_quad(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	ci.draw_primitive(pts, cols, PackedVector2Array())


## Polilinha: fina = segmentos em lote; grossa = faixa de quadriláteros (sem falhas nas juntas).
static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, _aa := true) -> void:
	var n := pts.size()
	if n < 2 or col.a <= 0.0:
		return
	if w <= 8.0:
		var seg := PackedVector2Array()
		seg.resize((n - 1) * 2)
		for i in n - 1:
			seg[i * 2] = pts[i]
			seg[i * 2 + 1] = pts[i + 1]
		ci.draw_multiline(seg, col, w, true)
		return
	var hw := w * 0.5
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d: Vector2
		if i == 0:
			d = pts[1] - pts[0]
		elif i == n - 1:
			d = pts[i] - pts[i - 1]
		else:
			d = pts[i + 1] - pts[i - 1]
		var nr := Vector2(-d.y, d.x).normalized() * hw
		left.append(pts[i] + nr)
		right.append(pts[i] - nr)
	var cols := PackedColorArray([col, col, col, col])
	for i in n - 1:
		ci.draw_primitive(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]), cols, PackedVector2Array())


static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float,
		_aa := true) -> void:
	if col.a <= 0.0 or r <= 0.0:
		return
	var pts := PackedVector2Array()
	pts.resize(n + 1)
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		pts[i] = c + Vector2(cos(a), sin(a)) * r
	polyline(ci, pts, col, w)


## Estrelinha de 4 pontas (4 "pipas" em lote).
static func sparkle(ci: CanvasItem, p: Vector2, s: float, col: Color, rot := 0.0) -> void:
	if col.a <= 0.0:
		return
	var cols := PackedColorArray([col, col, col, col])
	var ir := s * 0.28
	for k in 4:
		var a := rot + k * PI / 2.0
		var a0 := a - PI / 4.0
		var a1 := a + PI / 4.0
		ci.draw_primitive(PackedVector2Array([p, p + Vector2(cos(a0), sin(a0)) * ir, p + Vector2(cos(a), sin(a)) * s,
			p + Vector2(cos(a1), sin(a1)) * ir]), cols, PackedVector2Array())


## Mãozinha redonda flutuante (sem braço): luva macia com brilho.
## Mão: um mini-corpo igual à cabeça (cubo arredondado com borda e parte de cima clara).
static func hand(ci: CanvasItem, p: Vector2, r: float, col: Color, rim: Color, a := 1.0) -> void:
	var sz := Vector2(r * 2.15, r * 2.0)
	var rad := minf(sz.x, sz.y) * 0.46
	var rc := Rect2(p - sz / 2.0, sz)
	# corpo todo na cor escura (é a sombra interna), com contorno...
	rrect(ci, rc, rad, Color(col.darkened(0.2), a), Color(rim, a), 2.0)
	# ...e por cima a parte clara: topo com a mesma curva do contorno e cantos de baixo curvados
	var rr := maxf(rad - 2.0, 1.0)
	var x0 := rc.position.x + 2.0
	var x1 := rc.end.x - 2.0
	var y0 := rc.position.y + 2.0
	var cut := rc.position.y + sz.y * 0.68   # fundo da parte clara
	var cr := maxf(minf(rr * 0.85, cut - y0 - rr), 2.0)   # curvatura dos cantos de baixo (sem cruzar os de cima)
	var pts := PackedVector2Array()
	for k in 9:   # canto superior esquerdo
		var an := PI + float(k) * (PI * 0.5) / 8.0
		pts.append(Vector2(x0 + rr + cos(an) * rr, y0 + rr + sin(an) * rr))
	for k in 9:   # canto superior direito
		var an2 := PI * 1.5 + float(k) * (PI * 0.5) / 8.0
		pts.append(Vector2(x1 - rr + cos(an2) * rr, y0 + rr + sin(an2) * rr))
	for k in 9:   # canto inferior direito (da parte clara)
		var an3 := float(k) * (PI * 0.5) / 8.0
		pts.append(Vector2(x1 - cr + cos(an3) * cr, cut - cr + sin(an3) * cr))
	for k in 9:   # canto inferior esquerdo (da parte clara)
		var an4 := PI * 0.5 + float(k) * (PI * 0.5) / 8.0
		pts.append(Vector2(x0 + cr + cos(an4) * cr, cut - cr + sin(an4) * cr))
	poly(ci, pts, Color(col, a))


## Corpinho arredondado com rosto.
## mood: 0 normal, 1 machucado, 2 gritando, 3 tonto, 4 feliz, 5 decidido, 6 triste, 7 assustado,
## 8 surpreso, 9 convencido, 10 empolgado, 11 bravo.
## Todas as expressões seguem o estilo do rosto normal: mesmo olho (branco redondo, pupila com brilho,
## pálpebra da cor do corpo com risco), mesma posição e mesmos traços finos.
static func blob(ci: CanvasItem, c: Vector2, size: Vector2, col: Color, rim: Color, look: float,
		mood: int, blink: bool, gaze := Vector2.ZERO) -> void:
	var rad := minf(size.x, size.y) * 0.46
	var r := Rect2(c - size / 2.0, size)
	rrect(ci, r, rad, col.darkened(0.2), rim, 3.0)
	rrect(ci, Rect2(r.position + Vector2(3, 3), Vector2(size.x - 6.0, size.y * 0.7)), rad * 0.85, col)
	var s := size.x
	var ex := look * s * 0.09
	var ey := c.y - size.y * 0.06
	var sep := s * 0.2
	var er := s * 0.15
	var t := Time.get_ticks_msec() * 0.001
	for sd in [-1.0, 1.0]:
		var ep := Vector2(c.x + ex + sd * sep, ey)
		var inner: float = -sd                     # lado de dentro (perto do nariz)
		var pp := ep + Vector2(look * er * 0.35, er * 0.1) + gaze * er * 0.45   # pupila como no rosto normal
		match mood:
			0:   # normal
				if blink:
					ci.draw_line(ep + Vector2(-er, 0), ep + Vector2(er, 0), INK, 2.4, true)
				else:
					_eye_n(ci, ep, er, sd, pp, 0.68, col, 1.0, true, -0.71, 0.09)
			1:   # machucado: > <
				ci.draw_line(ep + Vector2(-er * inner, -er * 0.8), ep + Vector2(er * inner, 0), INK, 2.6, true)
				ci.draw_line(ep + Vector2(-er * inner, er * 0.8), ep + Vector2(er * inner, 0), INK, 2.6, true)
			2:   # gritando: olho aberto, sobrancelha para baixo
				_eye_n(ci, ep, er, sd, pp, 0.6, col)
				ci.draw_line(ep + Vector2(sd * er * 1.1, -er * 1.75), ep + Vector2(-sd * er * 1.0, -er * 1.15), INK, 2.8, true)
			3:   # tonto: espirais
				var sp := PackedVector2Array()
				for k in 14:
					var a: float = k * 0.62 + t * 7.0 * sd
					sp.append(ep + Vector2(cos(a), sin(a)) * (er * 0.1 + er * 0.065 * k))
				ci.draw_polyline(sp, INK, 2.0, true)
			4:   # feliz: ^ ^
				ci.draw_polyline(PackedVector2Array([ep + Vector2(-er, er * 0.35), ep + Vector2(0, -er * 0.55),
					ep + Vector2(er, er * 0.35)]), INK, 2.8, true)
			5:   # decidido: pálpebra mais baixa e sobrancelha reta
				_eye_n(ci, ep, er, sd, pp, 0.68, col, 1.0, true, -0.4, -0.15)
				ci.draw_line(ep + Vector2(sd * er * 1.15, -er * 1.4), ep + Vector2(-sd * er * 1.05, -er * 1.2), INK, 2.6, true)
			6:   # triste: pupila para baixo, pálpebra caída para fora, sobrancelha de dentro levantada
				_eye_n(ci, ep, er, sd, pp + Vector2(0, er * 0.22), 0.68, col, 1.0, true, -0.62, 0.35)
				ci.draw_line(ep + Vector2(inner * er * 1.0, -er * 1.85), ep + Vector2(-inner * er * 1.15, -er * 1.25), INK, 2.6, true)
			7:   # assustado: olho maior, pupila pequena tremendo, sobrancelha levantada
				var jit := Vector2(sin(t * 47.0), cos(t * 53.0)) * er * 0.06
				_eye_n(ci, ep, er, sd, ep + gaze * er * 0.3 + jit, 0.34, col, 1.18)
				ci.draw_line(ep + Vector2(inner * er * 1.0, -er * 2.05), ep + Vector2(-inner * er * 1.1, -er * 1.6), INK, 2.6, true)
			8:   # surpreso: olho maior, pupila menor, sobrancelha em arco no alto
				_eye_n(ci, ep, er, sd, ep + gaze * er * 0.35, 0.45, col, 1.12)
				ci.draw_polyline(PackedVector2Array([ep + Vector2(-er * 0.95, -er * 1.75), ep + Vector2(0, -er * 2.1),
					ep + Vector2(er * 0.95, -er * 1.75)]), INK, 2.4, true)
			9:   # convencido: pálpebra bem caída e uma sobrancelha levantada
				_eye_n(ci, ep, er, sd, pp + Vector2(0, er * 0.15), 0.68, col, 1.0, true, -0.08, 0.05)
				var raise := er * (0.45 if sd > 0.0 else 0.0)
				ci.draw_line(ep + Vector2(-er * 1.05, -er * 1.15 - raise), ep + Vector2(er * 1.05, -er * 1.35 - raise), INK, 2.6, true)
			10:   # empolgado: olho arregalado, pupila média e sobrancelha levantada para fora
				_eye_n(ci, ep, er, sd, ep + gaze * er * 0.3, 0.52, col, 1.15)
				ci.draw_line(ep + Vector2(inner * er * 0.9, -er * 1.6), ep + Vector2(-inner * er * 1.15, -er * 2.05), INK, 2.6, true)
			11:   # bravo: pálpebra inclinada para dentro e sobrancelha grossa em V
				_eye_n(ci, ep, er, sd, pp, 0.6, col, 1.0, true, -0.35, -0.6)
				ci.draw_line(ep + Vector2(sd * er * 1.2, -er * 1.75), ep + Vector2(-sd * er * 0.95, -er * 0.95), INK, 3.2, true)
	# boca (traço fino, como no rosto normal)
	var m := Vector2(c.x + ex * 0.9, c.y + size.y * 0.2)
	match mood:
		0:
			polyline(ci, PackedVector2Array([m + Vector2(-s * 0.09, 0.0), m + Vector2(0.0, s * 0.02), m + Vector2(s * 0.1, -s * 0.035)]), INK, 2.2)
		1:
			circ(ci, m + Vector2(0, 2), s * 0.07, INK)
		2:
			circ(ci, m + Vector2(0, 1), s * 0.095, INK)
		3:
			polyline(ci, PackedVector2Array([m + Vector2(-s * 0.09, 0), m + Vector2(-s * 0.03, s * 0.03), m + Vector2(s * 0.03, -s * 0.02),
				m + Vector2(s * 0.09, s * 0.02)]), INK, 2.2, true)
		4:
			var sw := s * 0.12
			ci.draw_polyline(PackedVector2Array([m + Vector2(-sw, 0), m + Vector2(-sw * 0.5, sw * 0.5),
				m + Vector2(0, sw * 0.65), m + Vector2(sw * 0.5, sw * 0.5), m + Vector2(sw, 0)]), INK, 2.4, true)
		5:
			ci.draw_line(m + Vector2(-s * 0.09, 1.0), m + Vector2(s * 0.09, 0.0), INK, 2.6, true)
		6:
			var tw := s * 0.09
			ci.draw_polyline(PackedVector2Array([m + Vector2(-tw, tw * 0.35), m + Vector2(-tw * 0.4, -tw * 0.1),
				m + Vector2(tw * 0.4, -tw * 0.1), m + Vector2(tw, tw * 0.35)]), INK, 2.4, true)
		7:
			var zz := s * 0.025
			ci.draw_polyline(PackedVector2Array([m + Vector2(-zz * 4, 0), m + Vector2(-zz * 2, zz * 1.2), m + Vector2(0, -zz),
				m + Vector2(zz * 2, zz * 1.2), m + Vector2(zz * 4, 0)]), INK, 2.2, true)
		8:
			circ(ci, m + Vector2(0, 2), s * 0.065, INK)
		9:
			ci.draw_polyline(PackedVector2Array([m + Vector2(-s * 0.09, s * 0.02), m + Vector2(0, s * 0.035),
				m + Vector2(s * 0.09, 0), m + Vector2(s * 0.12, -s * 0.035)]), INK, 2.4, true)
		10:
			var gw := s * 0.16   # sorrisão largo e reto em cima
			var gpts := PackedVector2Array([m + Vector2(-gw, -3)])
			for k in 9:
				var ga := PI * float(k) / 8.0
				gpts.append(m + Vector2(-cos(ga) * gw, -3.0 + sin(ga) * gw * 0.7))
			gpts.append(m + Vector2(gw, -3))
			poly(ci, gpts, INK)
		11:
			ci.draw_polyline(PackedVector2Array([m + Vector2(-s * 0.09, s * 0.025), m + Vector2(-s * 0.03, -s * 0.005),
				m + Vector2(s * 0.03, -s * 0.005), m + Vector2(s * 0.09, s * 0.025)]), INK, 2.6, true)   # boca fechada, emburrada
	_mood_fx(ci, c, size, mood, ex)


## Olho no estilo do rosto normal: branco redondo, pupila com brilho e (opcional) pálpebra da cor do corpo
## cortando o olho por cima, com um risco. lid_y = altura da pálpebra (em raios do olho, negativo = em cima);
## tilt > 0 deixa o lado de fora mais baixo, < 0 o lado de dentro mais baixo.
static func _eye_n(ci: CanvasItem, ep: Vector2, er: float, sd: float, pp: Vector2, pr: float, col: Color,
		wsc := 1.0, lid := false, lid_y := -0.71, tilt := 0.09) -> void:
	var ew := er * wsc
	circ(ci, ep, ew, Color.WHITE)
	circ(ci, pp, er * pr, INK)
	circ(ci, pp + Vector2(-er * 0.2, -er * 0.25) * (pr / 0.68), er * 0.22 * minf(pr / 0.68, 1.1), Color.WHITE)
	if lid:
		var lp := PackedVector2Array()
		for k in 24:
			var a := TAU * k / 24.0
			var lx := cos(a) * (ew + 0.7)
			var ly := sin(a) * (ew + 0.7)
			var ll := er * lid_y + er * tilt * (sd * lx) / (er * 1.4)
			lp.append(ep + Vector2(lx, minf(ly, ll)))
		poly(ci, lp, col)
		var xa := ew * 1.2
		ci.draw_line(ep + Vector2(sd * xa, er * lid_y + er * tilt * xa / (er * 1.4)),
			ep + Vector2(-sd * xa, er * lid_y - er * tilt * xa / (er * 1.4)), INK, 2.2, true)


## Detalhes que acompanham cada expressão (suor, estrelas, lágrimas, veia de raiva…).
static func _mood_fx(ci: CanvasItem, c: Vector2, size: Vector2, mood: int, ex := 0.0) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var s := size.x
	var u := s * 1.25
	var lw := maxf(s * 0.05, 1.6)
	var top := c.y - size.y * 0.5
	match mood:
		1:   # dor: estrelinhas de pancada
			for k in 2:
				var a := t * 7.0 + k * PI
				sparkle(ci, Vector2(c.x + s * 0.42 + cos(a) * s * 0.12, top + s * 0.02 + sin(a) * s * 0.06), u * 0.1, Color("fff3a0"), a)
		3:   # tontura: estrelas girando acima da cabeça
			for k in 3:
				var a := t * 4.5 + k * TAU / 3.0
				sparkle(ci, Vector2(c.x + cos(a) * s * 0.42, top - s * 0.12 + sin(a) * s * 0.1), u * 0.1, Color("ffe94a"), a)
		4:   # feliz: um coraçãozinho subindo de vez em quando
			var hy := fposmod(t * 24.0, 48.0)
			if hy < 34.0:
				var hp := Vector2(c.x + s * 0.5 + sin(t * 3.0) * 2.0, top - hy * 0.35)
				var ha := 1.0 - hy / 34.0
				circ(ci, hp + Vector2(-u * 0.03, 0), u * 0.035, Color(1, 0.4, 0.55, ha))
				circ(ci, hp + Vector2(u * 0.03, 0), u * 0.035, Color(1, 0.4, 0.55, ha))
				poly(ci, PackedVector2Array([hp + Vector2(-u * 0.064, u * 0.012), hp + Vector2(u * 0.064, u * 0.012),
					hp + Vector2(0, u * 0.085)]), Color(1, 0.4, 0.55, ha))
		6:   # lágrimas escorrendo dos olhos
			for sd in [-1.0, 1.0]:
				var tx: float = c.x + ex + sd * s * 0.2
				var ty0 := c.y - size.y * 0.05 + s * 0.12
				ci.draw_line(Vector2(tx, ty0), Vector2(tx, ty0 + s * 0.12), Color(0.55, 0.83, 1.0, 0.85), lw * 0.9, true)
				var dy := fposmod(t * 30.0 + (7.0 if sd > 0.0 else 0.0), 16.0)
				circ(ci, Vector2(tx, ty0 + s * 0.12 + dy), lw * 0.75, Color(0.55, 0.83, 1.0, 1.0 - dy / 16.0))
		7:   # gota de suor na têmpora
			var dp := Vector2(c.x + s * 0.4, top + s * 0.16 + fposmod(t * 16.0, 10.0))
			circ(ci, dp + Vector2(0, u * 0.03), u * 0.05, Color("8fd3ff"))
			poly(ci, PackedVector2Array([dp + Vector2(-u * 0.045, u * 0.02), dp + Vector2(0, -u * 0.08),
				dp + Vector2(u * 0.045, u * 0.02)]), Color("8fd3ff"))
		8:   # "!" acima da cabeça
			var bp := Vector2(c.x + s * 0.4, top - s * 0.3 + sin(t * 10.0) * 2.0)
			rrect(ci, Rect2(bp - Vector2(u * 0.04, 0), Vector2(u * 0.08, u * 0.2)), 3, Color("ffd23f"), INK, 2.0)
			circ(ci, bp + Vector2(0, u * 0.28), u * 0.05, INK)
			circ(ci, bp + Vector2(0, u * 0.28), u * 0.034, Color("ffd23f"))
		9:   # convencido: brilho rápido de vez em quando
			if fposmod(t, 2.4) < 0.25:
				sparkle(ci, Vector2(c.x + s * 0.42, top + s * 0.12), u * 0.11, Color(1, 1, 1, 0.95), t * 8.0)
		10:   # empolgado: riscos de energia saindo da cabeça
			var pul := 0.75 + 0.25 * sin(t * 18.0)
			for sd2 in [-1.0, 1.0]:
				var o := Vector2(c.x + sd2 * s * 0.5, top + s * 0.08)
				for k in 3:
					var a2: float = -PI * 0.5 + sd2 * (0.45 + k * 0.38)
					var d2 := Vector2(cos(a2), sin(a2))
					ci.draw_line(o + d2 * u * 0.08, o + d2 * u * (0.08 + 0.12 * pul), INK, lw, true)
		11:   # raiva: veia pulsando na testa
			var vp := Vector2(c.x - s * 0.3, top + s * 0.12)
			var pulse := 1.0 + 0.18 * sin(t * 16.0)
			for k in 4:
				var a3 := PI * 0.25 + k * PI * 0.5
				var d := Vector2(cos(a3), sin(a3))
				ci.draw_line(vp + d * u * 0.025 * pulse, vp + d * u * 0.075 * pulse, Color("ff2b2b"), lw, true)


## Bonequinho completo (corpo + duas mãos flutuantes) para menus.
static func mascot(ci: CanvasItem, pos: Vector2, size: float, col: Color, rim: Color, t: float,
		phase := 0.0, look := 1.0, mood := 0, bounce := 6.0, shadow := true) -> void:
	var hop := absf(sin(t * 3.0 + phase))
	var p := pos + Vector2(0, -hop * bounce)
	if shadow:
		ellipse(ci, pos + Vector2(0, size * 0.5 + 3.0), size * (0.5 - hop * 0.08), size * 0.12,
			Color(0, 0, 0, 0.22 - hop * 0.06))
	var sq := 0.07 * sin(t * 6.0 + phase * 2.0)
	ci.draw_set_transform(p + Vector2(0, size * 0.5), 0.0, Vector2(1.0 + sq, 1.0 - sq))
	var blink := fmod(t + phase, 3.6) > 3.48
	blob(ci, Vector2(0, -size * 0.5), Vector2(size, size), col, rim, look, mood, blink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var hr := clampf(size * 0.27, 7.0, 16.0)
	var hx := size * 0.5 + hr * 1.1
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	hand(ci, p + Vector2(-hx, 2.0 + sin(t * 3.0 + phase + 1.3) * 4.0), hr, col, rim)
	hand(ci, p + Vector2(hx, 2.0 + sin(t * 3.0 + phase + 2.9) * 4.0), hr, col, rim)
