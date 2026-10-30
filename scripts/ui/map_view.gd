extends Control
## Ambiente di un giocatore in 2D: tessere esagonali (immagini del modulo, ruotate), animali,
## Landmark, celle evidenziate e tessera «fantasma» durante il piazzamento.
## Trascina per spostare, rotella per lo zoom; clic su una cella → cell_clicked; tasto destro → rotate.

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell)
signal rotate_requested(step: int)

const D = preload("res://scripts/data/cs_data.gd")
const SQ3 := 1.7320508

var env: Dictionary = {}
var targets: Array = []          # celle selezionabili
var target_kind := ""            # "tile" / "token"
var ghost := {}                  # {cell, id, rot}
var ghost_animal := ""           # animale da posare (anteprima)
var last_cell = null
var hover = null
var pcolor := Color.WHITE
var zoom := 1.0
var pan := Vector2.ZERO
var base_r := 62.0
var _drag := false
var _drag_from := Vector2.ZERO
var _moved := 0.0
var _auto := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


var _fitted_n := -1


func set_env(e: Dictionary, keep_view := true) -> void:
	var changed_env: bool = not is_same(e, env)
	env = e
	if not keep_view or changed_env or (_auto and env.size() + targets.size() != _fitted_n):
		fit()
	queue_redraw()


func fit() -> void:
	if env.is_empty() or size.x < 10:
		return
	_fitted_n = env.size() + targets.size()
	var mn := Vector2(1e9, 1e9)
	var mx := -mn
	var cells: Array = env.keys() + targets
	for c in cells:
		var p := _axial(c, 1.0)
		mn = mn.min(p)
		mx = mx.max(p)
	var span := (mx - mn) + Vector2(SQ3 * 1.6, 3.2)
	zoom = clampf(minf(size.x / (span.x * base_r), size.y / (span.y * base_r)), 0.35, 1.6)
	pan = -((mn + mx) / 2.0) * base_r * zoom
	_auto = true
	queue_redraw()


func R() -> float:
	return base_r * zoom


func _axial(c: Vector2i, r: float) -> Vector2:
	return Vector2(r * SQ3 * (c.x + c.y / 2.0), r * 1.5 * c.y)


func cell_center(c: Vector2i) -> Vector2:
	return size / 2.0 + pan + _axial(c, R())


func cell_at(p: Vector2) -> Vector2i:
	var v := (p - size / 2.0 - pan) / R()
	var q := (SQ3 / 3.0 * v.x - 1.0 / 3.0 * v.y)
	var r := (2.0 / 3.0 * v.y)
	var x := q
	var z := r
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_zoom_at(ev.position, 1.12)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_zoom_at(ev.position, 1.0 / 1.12)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			rotate_requested.emit(1)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_drag = true
				_drag_from = ev.position
				_moved = 0.0
			else:
				_drag = false
				if _moved < 8.0:
					cell_clicked.emit(cell_at(ev.position))
	elif ev is InputEventMouseMotion:
		if _drag:
			_moved += ev.relative.length()
			if _moved >= 8.0:
				pan += ev.relative
				_auto = false
				queue_redraw()
		var c := cell_at(ev.position)
		if c != hover:
			hover = c
			cell_hovered.emit(c)
			queue_redraw()
	elif ev is InputEventMagnifyGesture:
		_zoom_at(ev.position, ev.factor)
	elif ev is InputEventPanGesture:
		pan -= ev.delta * 12.0
		_auto = false
		queue_redraw()


func _zoom_at(p: Vector2, f: float) -> void:
	var nz := clampf(zoom * f, 0.3, 2.6)
	var k := nz / zoom
	pan = (pan + size / 2.0 - p) * k + p - size / 2.0
	zoom = nz
	_auto = false
	queue_redraw()


func _draw() -> void:
	var r := R()
	# griglia leggera attorno all'ambiente
	for c in env:
		_draw_tile(env[c], cell_center(c), r, 1.0)
	# celle selezionabili
	for c in targets:
		var p := cell_center(c)
		if target_kind == "tile":
			var pts := UI.hex_points(p, r * 0.96)
			draw_colored_polygon(pts, Color(1, 1, 1, 0.07 if c != hover else 0.2))
			pts.append(pts[0])
			draw_polyline(pts, Color(UI.CREAM, 0.6), 2.0)
		else:
			var pts := UI.hex_points(p, r * 0.97)
			pts.append(pts[0])
			draw_polyline(pts, Color(UI.GOLD, 0.95), maxf(3.0, r * 0.07))
			if c == hover and ghost_animal != "":
				var t := UI.token_tex(ghost_animal)
				var s := r * 0.95
				draw_texture_rect(t, Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), false, Color(1, 1, 1, 0.75))
	# tessera fantasma
	if not ghost.is_empty():
		var p := cell_center(ghost["cell"])
		_draw_tile({"id": ghost["id"], "rot": ghost["rot"], "a": "", "lm": ""}, p, r, 0.85)
		var pts := UI.hex_points(p, r)
		pts.append(pts[0])
		draw_polyline(pts, UI.GOLD, maxf(3.0, r * 0.06))
	# ultima tessera posata
	if last_cell != null and env.has(last_cell) and ghost.is_empty():
		var pts := UI.hex_points(cell_center(last_cell), r * 0.99)
		pts.append(pts[0])
		draw_polyline(pts, Color(pcolor, 0.9), maxf(2.0, r * 0.045))


func _draw_tile(c: Dictionary, p: Vector2, r: float, alpha: float) -> void:
	var t := UI.tile_tex(c["id"])
	var w := r * SQ3
	var h := r * 2.0
	draw_set_transform(p, deg_to_rad(60.0 * int(c["rot"])), Vector2.ONE)
	draw_texture_rect(t, Rect2(-w / 2, -h / 2, w, h), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if c["lm"] != "":
		var s := r * 1.05
		draw_circle(p, s * 0.52, Color(1, 1, 1, 0.85))
		draw_texture_rect(UI.token_tex("lm_" + c["lm"]), Rect2(p - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84), false)
	elif c["a"] != "":
		var s := r * 1.0
		draw_circle(p + Vector2(0, r * 0.04), s * 0.5, Color(0, 0, 0, 0.35))
		draw_texture_rect(UI.token_tex(c["a"]), Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), false)
