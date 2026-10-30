extends SubViewportContainer
## Ambiente in 3D. Le tessere non sono 200 modelli: ci sono solo cinque diorami di habitat fatti con
## Meshy (foresta, montagna, prateria, zona umida, fiume). Ogni tessera è divisa in sei spicchi, uno per
## lato; gli spicchi consecutivi dello stesso habitat diventano un'unica copia del diorama, ritagliata
## da uno shader sull'esagono e sull'arco giusto. Così una tessera foresta/fiume è mezzo diorama di
## foresta più mezzo di fiume, una chiave di volta è un diorama intero, e le tessere Landmarks a tre
## habitat sono tre spicchi. Gli animali e i Landmark sono miniature Meshy.
## Comandi: trascina col sinistro per ruotare, col destro per spostare, rotella per lo zoom;
## clic per scegliere, clic destro (senza trascinare) per ruotare la tessera.

signal cell_clicked(cell: Vector2i)
signal cell_hovered(cell)
signal rotate_requested(step: int)

const D = preload("res://scripts/data/cs_data.gd")
const SQ3 := 1.7320508
const RW := 1.0          # raggio di una tessera (mondo)
const BASE_H := 0.10     # spessore della base della tessera
const CLIP_SHADER := preload("res://scripts/ui/terrain_clip.gdshader")
const VIVO_SHADER := preload("res://scripts/ui/vivo.gdshader")

## Animali in movimento (senza scheletro): il nodo si muove nel _process, ali e coda nello shader.
var animated := true
var _anims: Array = []           # [nodo, tipo, posizione base, rotazione base, fase]
var _t := 0.0
## Leggera tinta per riconoscere a colpo d'occhio praterie (gialle) e zone umide (verdi).
const TINT := {"prateria": Vector3(1.12, 0.98, 0.55), "zona_umida": Vector3(0.78, 1.0, 0.62), "fiume": Vector3(0.9, 1.0, 1.05)}

var env: Dictionary = {}
var targets: Array = []
var target_kind := ""
var ghost := {}
var ghost_animal := ""
var last_cell = null
var hover = null
var pcolor := Color.WHITE

var vp: SubViewport
var cam: Camera3D
var root3: Node3D
var tiles_node: Node3D
var marks_node: Node3D
var ghost_node: Node3D
var _built := {}         # cella -> [firma, nodo]
var yaw := 0.0
var pitch := 58.0
var dist := 9.0
var target := Vector3.ZERO
var _drag := 0
var _drag_from := Vector2.ZERO
var _moved := 0.0
var _auto := true
var _fitted_n := -1

static var _models := {}  # nome -> {scene, tex, aabb, ground}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	add_child(vp)
	root3 = Node3D.new()
	vp.add_child(root3)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0e3a20")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#fff4e0")
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = e
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.8
	sun.light_color = Color("#fff1d6")
	sun.shadow_enabled = true
	root3.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_energy = 0.18
	fill.light_color = Color("#cfe6ff")
	root3.add_child(fill)
	# tavolo: un grande disco color carta
	var ground := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 40.0
	cyl.bottom_radius = 40.0
	cyl.height = 0.05
	cyl.radial_segments = 64
	ground.mesh = cyl
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = UI.tex("res://assets/misc/panno.webp")
	gm.albedo_color = Color(0.62, 0.66, 0.62)
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3(0.45, 0.45, 0.45)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.03
	root3.add_child(ground)
	tiles_node = Node3D.new()
	root3.add_child(tiles_node)
	marks_node = Node3D.new()
	root3.add_child(marks_node)
	ghost_node = Node3D.new()
	root3.add_child(ghost_node)
	cam = Camera3D.new()
	cam.fov = 40.0
	root3.add_child(cam)
	_update_cam()


# ------------------------------------------------------------------ modelli

static func model(name: String) -> Dictionary:
	if _models.has(name):
		return _models[name]
	var sc: PackedScene = load("res://assets/models/%s.glb" % name)
	var inst := sc.instantiate()
	var mi := _find_mesh(inst)
	var info := {"scene": sc, "tex": null, "aabb": AABB(), "ground": 0.0, "xf": Transform3D.IDENTITY}
	if mi != null:
		var mat = mi.get_active_material(0)
		if mat is BaseMaterial3D:
			info["tex"] = mat.albedo_texture
		info["xf"] = _global_xf(mi, inst)
		var mesh: Mesh = mi.mesh
		var arr := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var xf: Transform3D = info["xf"]
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := -mn
		var ups := []
		for i in verts.size():
			var v := xf * verts[i]
			mn = mn.min(v)
			mx = mx.max(v)
			if i < norms.size() and (xf.basis * norms[i]).normalized().y > 0.85:
				ups.append(v.y)
		info["aabb"] = AABB(mn, mx - mn)
		if not ups.is_empty():
			ups.sort()
			info["ground"] = ups[int(ups.size() * 0.12)]
		else:
			info["ground"] = mn.y
	inst.free()
	_models[name] = info
	return info


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _find_mesh(c)
		if m != null:
			return m
	return null


static func _global_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root and p is Node3D:
		xf = p.transform * xf
		p = p.get_parent()
	return xf


## Diorama di habitat sulla tessera, ritagliato sull'esagono e sull'arco [a0, a0+span] (radianti).
func _terrain(h: String, center: Vector3, a0: float, span: float) -> Node3D:
	var info := model(h)
	var inst: Node3D = info["scene"].instantiate()
	var bb: AABB = info["aabb"]
	var s := maxf(SQ3 * RW / maxf(bb.size.x, 0.001), 2.0 * RW / maxf(bb.size.z, 0.001)) * 1.06
	var sy := s * 0.75
	var holder := Node3D.new()
	holder.add_child(inst)
	# il centro del diorama sul centro della tessera, il «terreno» del diorama sulla base
	var c := bb.get_center()
	inst.transform = Transform3D(Basis.from_scale(Vector3(s, sy, s)), Vector3(-c.x * s, -float(info["ground"]) * sy, -c.z * s))
	holder.position = center + Vector3(0, BASE_H, 0)
	var mat := ShaderMaterial.new()
	mat.shader = CLIP_SHADER
	mat.set_shader_parameter("albedo_tex", info["tex"])
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("radius", RW * 0.985)
	mat.set_shader_parameter("a0", a0)
	mat.set_shader_parameter("span", span)
	mat.set_shader_parameter("ground", BASE_H - 0.005)
	mat.set_shader_parameter("tint", TINT.get(h, Vector3.ONE))
	_apply_mat(inst, mat)
	return holder


static func _apply_mat(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		_apply_mat(c, mat)


## Miniatura (animale o Landmark) alta `height`, appoggiata in p.
func _mini(name: String, p: Vector3, height: float, yaw_deg: float, lift := 0.0) -> Node3D:
	var info := model(name)
	var inst: Node3D = info["scene"].instantiate()
	var bb: AABB = info["aabb"]
	var s := height / maxf(maxf(bb.size.y, bb.size.x * 0.8), 0.001)
	var holder := Node3D.new()
	holder.add_child(inst)
	var c := bb.get_center()
	inst.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-c.x * s, -bb.position.y * s, -c.z * s))
	holder.position = p + Vector3(0, lift, 0)
	holder.rotation_degrees.y = yaw_deg
	return holder


# ------------------------------------------------------------------ geometria

func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(RW * SQ3 * (c.x + c.y / 2.0), 0.0, RW * 1.5 * c.y)


func _hex_mesh(r: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for k in 6:
		var a := deg_to_rad(-90 + 60 * k)
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for k in 6:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 6]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, h, 0))
		st.add_vertex(b + Vector3(0, h, 0))
		st.add_vertex(a + Vector3(0, h, 0))
		var n := ((a + b) / 2.0).normalized()
		st.set_normal(n)
		st.add_vertex(a)
		st.add_vertex(a + Vector3(0, h, 0))
		st.add_vertex(b)
		st.add_vertex(b)
		st.add_vertex(a + Vector3(0, h, 0))
		st.add_vertex(b + Vector3(0, h, 0))
	return st.commit()


static var _hex_cache := {}
static var _base_cache := {}
static var _bmat: StandardMaterial3D

## Colore della base sotto ogni habitat (un po' più scuro del diorama).
const BASE_COL := {"foresta": "#2f5a2c", "montagna": "#7d8186", "prateria": "#c9a43a", "zona_umida": "#4f9c8c", "fiume": "#2c8fc4"}


func _base_mat() -> StandardMaterial3D:
	if _bmat == null:
		_bmat = StandardMaterial3D.new()
		_bmat.vertex_color_use_as_albedo = true
		_bmat.roughness = 0.95
		_bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _bmat


## Prisma esagonale: in cima sei spicchi colorati come i lati (spicchio d attorno alla direzione 60°·d),
## fianchi color terra.
func _base_mesh(world: Array) -> ArrayMesh:
	var key := ",".join(world)
	if _base_cache.has(key):
		return _base_cache[key]
	var r := RW * 0.985
	var h := BASE_H
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corner := func(k: int) -> Vector3:
		var a := deg_to_rad(-90.0 + 60.0 * k)
		return Vector3(cos(a) * r, 0, sin(a) * r)
	for d in 6:
		# il lato d (direzione 60°·d) sta fra gli angoli d+1 e d+2 (angoli a -90° + 60°·k)
		var a: Vector3 = corner.call(d + 1)
		var b: Vector3 = corner.call(d + 2)
		var col := Color(BASE_COL.get(world[d], "#5b4632"))
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, h, 0))
		st.add_vertex(b + Vector3(0, h, 0))
		st.add_vertex(a + Vector3(0, h, 0))
		var side := Color("#4a3826")
		st.set_color(side)
		st.set_normal(((a + b) / 2.0).normalized())
		for v in [a, a + Vector3(0, h, 0), b, b, a + Vector3(0, h, 0), b + Vector3(0, h, 0)]:
			st.add_vertex(v)
	var m := st.commit()
	_base_cache[key] = m
	return m


func _hex(r: float, h: float) -> ArrayMesh:
	var k := "%.3f_%.3f" % [r, h]
	if not _hex_cache.has(k):
		_hex_cache[k] = _hex_mesh(r, h)
	return _hex_cache[k]


func _plain_mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ------------------------------------------------------------------ costruzione

func set_env(e: Dictionary, keep_view := true) -> void:
	var changed_env: bool = not is_same(e, env)
	env = e
	_sync_tiles()
	if not keep_view or changed_env or (_auto and env.size() + targets.size() != _fitted_n):
		fit()
	refresh_marks()


func fit() -> void:
	if env.is_empty():
		return
	_auto = true
	_fitted_n = env.size() + targets.size()
	var mn := Vector3(1e9, 0, 1e9)
	var mx := -mn
	for c in env.keys() + targets:
		var p := cell_pos(c)
		mn = Vector3(minf(mn.x, p.x), 0, minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), 0, maxf(mx.z, p.z))
	target = (mn + mx) / 2.0
	var aspect := size.x / maxf(size.y, 1.0) if size.y > 0 else 1.4
	var span := maxf((mx.x - mn.x) / maxf(aspect, 0.6), (mx.z - mn.z) * 1.15) + 2.6
	dist = clampf(span * 1.2, 5.0, 45.0)
	_update_cam()


func _sig(c: Dictionary) -> String:
	return "%s|%d|%s|%s" % [c["id"], c["rot"], c["a"], c["lm"]]


func _sync_tiles() -> void:
	for cell in _built.keys():
		if not env.has(cell) or _built[cell][0] != _sig(env[cell]):
			_built[cell][1].queue_free()
			_built.erase(cell)
	for cell in env:
		if _built.has(cell):
			continue
		var n := _build_tile(env[cell], cell_pos(cell), cell)
		tiles_node.add_child(n)
		_built[cell] = [_sig(env[cell]), n]


func _build_tile(c: Dictionary, p: Vector3, cell) -> Node3D:
	var node := Node3D.new()
	var info := D.tile_info(c["id"])
	var e: Array = info["e"]
	var rot := int(c["rot"])
	# base esagonale: colore dell'habitat principale, bordo scuro
	# spicchi: habitat per lato nel mondo (lato d → e[d - rot])
	var world := []
	for d in 6:
		world.append(e[posmod(d - rot, 6)])
	# base piena: ogni spicchio del colore del suo habitat, così sotto il diorama non resta mai un buco
	var base := MeshInstance3D.new()
	base.mesh = _base_mesh(world)
	base.position = p
	base.material_override = _base_mat()
	node.add_child(base)
	var runs := _runs(world)
	for r in runs:
		var a0 := deg_to_rad(60.0 * r[1] - 30.0)
		var span := deg_to_rad(60.0 * r[2]) if r[2] < 6 else TAU + 1.0
		node.add_child(_terrain(r[0], p, a0, span))
	# animale, Landmark oppure gli animali possibili come gettoni piatti
	var top := p + Vector3(0, BASE_H, 0)
	var h := hash(str(cell))
	if c["lm"] != "":
		node.add_child(_mini("lm_" + c["lm"], top, 0.9, float(h % 360)))
	elif c["a"] != "":
		node.add_child(_animal(c["a"], top, float(h % 360)))
	else:
		var ws: Array = info["w"]
		for i in ws.size():
			var sp := Sprite3D.new()
			sp.texture = UI.token_tex(ws[i])
			sp.pixel_size = 0.34 / 200.0
			sp.double_sided = true
			sp.shaded = false
			sp.no_depth_test = false
			var off := Vector3.ZERO
			if ws.size() > 1:
				var a := TAU * i / ws.size() - PI / 2
				off = Vector3(cos(a), 0, sin(a)) * 0.2
			sp.position = top + Vector3(0, 0.5, 0) + off * 1.4
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.pixel_size = 0.42 / 200.0
			node.add_child(sp)
		if info["k"]:
			var cone := Sprite3D.new()
			cone.texture = UI.token_tex("natura")
			cone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			cone.pixel_size = 0.18 / 160.0
			cone.shaded = false
			cone.position = top + Vector3(0.24, 0.42, 0.0)
			node.add_child(cone)
	return node


func _animal(a: String, top: Vector3, yaw_deg: float, live := true) -> Node3D:
	var n: Node3D
	match a:
		"orso":
			n = _mini("orso", top, 0.75, yaw_deg)
		"alce":
			n = _mini("alce", top, 0.95, yaw_deg)
		"salmone":
			n = _mini("salmone", top, 0.3, yaw_deg, 0.08)
		"falco":
			n = _mini("falco", top, 0.95, yaw_deg, 0.45)
		_:
			n = _mini("volpe", top, 0.7, yaw_deg)
	if live and animated:
		var ph := float(hash(str(top)) % 1000) / 1000.0 * TAU
		if a == "falco":
			_apply_vivo(n, "falco", 1, 0.32, 5.5, ph)
		elif a == "salmone":
			_apply_vivo(n, "salmone", 2, 0.35, 9.0, ph, top.y + 0.01)
		_anims.append([n, a, n.position, n.rotation, ph])
	return n


func _apply_vivo(holder: Node3D, name: String, mode: int, amp: float, speed: float, ph: float, floor_y := -100.0) -> void:
	var info := model(name)
	var bb: AABB = info["aabb"]
	var mat := ShaderMaterial.new()
	mat.shader = VIVO_SHADER
	mat.set_shader_parameter("albedo_tex", info["tex"])
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("half_w", bb.size.x / 2.0 if mode == 1 else bb.size.z / 2.0)
	mat.set_shader_parameter("amp", amp)
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("phase", ph)
	mat.set_shader_parameter("floor_y", floor_y)
	_apply_mat(holder, mat)


## Movimenti di ogni animale: l'orso dondola e si alza ogni tanto, l'alce bruca, la volpe si guarda
## intorno e saltella, il falco volteggia sopra la tessera, il salmone salta fuori dall'acqua.
## Accende o spegne i movimenti: le tessere si ricostruiscono con le miniature ferme o animate.
func set_animated(v: bool) -> void:
	if v == animated:
		return
	animated = v
	for cell in _built.keys():
		_built[cell][1].queue_free()
	_built.clear()
	_anims.clear()
	_sync_tiles()
	refresh_marks()


func _process(delta: float) -> void:
	if not animated or not is_visible_in_tree() or _anims.is_empty():
		return
	_t += delta
	var alive := []
	for an in _anims:
		var n: Node3D = an[0]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		alive.append(an)
		var p0: Vector3 = an[2]
		var r0: Vector3 = an[3]
		var t := _t + float(an[4]) * 3.0
		match str(an[1]):
			"orso":
				n.rotation = r0 + Vector3(0, sin(t * 0.6) * 0.18, sin(t * 1.3) * 0.04)
				var up := maxf(0.0, sin(t * 0.35) - 0.85) / 0.15   # ogni tanto si alza sulle zampe
				n.rotation.x = r0.x - up * 0.35
				n.position = p0 + Vector3(0, up * 0.08, 0)
			"alce":
				var graze := smoothstep(0.3, 0.9, sin(t * 0.45))   # abbassa la testa a brucare
				n.rotation = r0 + Vector3(graze * 0.22, sin(t * 0.25) * 0.25, 0)
				n.position = p0 + Vector3(0, -graze * 0.03, 0)
			"volpe":
				var look := sin(t * 0.9) * 0.6 + sin(t * 2.3) * 0.15
				var hop := maxf(0.0, sin(t * 1.7)) if sin(t * 0.3) > 0.6 else 0.0
				n.rotation = r0 + Vector3(0, look, 0)
				n.position = p0 + Vector3(0, hop * 0.12, 0)
			"falco":
				var a := t * 0.7
				n.position = p0 + Vector3(cos(a) * 0.28, 0.1 + sin(t * 1.4) * 0.06, sin(a) * 0.28)
				n.rotation = Vector3(0, -a, sin(t * 0.7) * 0.15)
			"salmone":
				# nuota in superficie, si tuffa sparendo sotto la tessera e riappare con un salto
				var cyc := fmod(t, 6.0) / 6.0
				var y := 0.0
				var pitch := 0.0
				if cyc < 0.45:
					y = sin(t * 2.0) * 0.02
				elif cyc < 0.6:
					var d := (cyc - 0.45) / 0.15            # tuffo: punta in giù e scende sotto la tessera
					pitch = d * 1.1
					y = -d * d * 0.75 + sin(d * PI) * 0.08
				elif cyc < 0.72:
					y = -0.75                                # sott'acqua: non si vede
					pitch = 1.1
				else:
					var j := (cyc - 0.72) / 0.28             # salto: esce da sotto, arco in aria, ricade
					y = lerpf(-0.75, 0.0, j) + sin(j * PI) * 0.6
					pitch = lerpf(-1.0, 0.5, j) * (1.0 - j * j) 
				n.position = p0 + Vector3(0, y, 0)
				n.rotation = r0 + Vector3(pitch, 0, 0)
	_anims = alive


## Sequenze di lati consecutivi dello stesso habitat: [[habitat, primo lato, quanti], ...]
func _runs(world: Array) -> Array:
	var allsame := true
	for d in 6:
		if world[d] != world[0]:
			allsame = false
	if allsame:
		return [[world[0], 0, 6]]
	# parte da un cambio di habitat
	var start := 0
	for d in 6:
		if world[d] != world[posmod(d - 1, 6)]:
			start = d
			break
	var out := []
	var k := 0
	while k < 6:
		var d := (start + k) % 6
		var h: String = world[d]
		var n := 1
		while k + n < 6 and world[(start + k + n) % 6] == h:
			n += 1
		out.append([h, d, n])
		k += n
	return out


func refresh_marks() -> void:
	for ch in marks_node.get_children():
		ch.queue_free()
	for ch in ghost_node.get_children():
		ch.queue_free()
	for c in targets:
		var m := MeshInstance3D.new()
		var p := cell_pos(c)
		if target_kind == "tile":
			m.mesh = _hex(RW * 0.93, 0.02)
			m.material_override = _plain_mat(Color(UI.CREAM, 0.45 if c != hover else 0.85), true)
			m.position = p + Vector3(0, 0.005, 0)
		else:
			m.mesh = _ring_mesh()
			var gm := _plain_mat(Color(UI.GOLD, 0.95), true)
			gm.no_depth_test = true
			gm.render_priority = 10
			m.material_override = gm
			m.position = p + Vector3(0, BASE_H + 0.3, 0)
		marks_node.add_child(m)
		if target_kind == "token" and c == hover and ghost_animal != "":
			var g := _animal(ghost_animal, p + Vector3(0, BASE_H, 0), 20.0, false)
			marks_node.add_child(g)
	if last_cell != null and env.has(last_cell) and ghost.is_empty() and target_kind != "token":
		var m := MeshInstance3D.new()
		m.mesh = _ring_mesh()
		m.material_override = _plain_mat(Color(pcolor, 0.9), true)
		m.position = cell_pos(last_cell) + Vector3(0, BASE_H + 0.02, 0)
		marks_node.add_child(m)
	if not ghost.is_empty():
		var g := _build_tile({"id": ghost["id"], "rot": ghost["rot"], "a": "", "lm": ""}, cell_pos(ghost["cell"]), ghost["cell"])
		g.position.y = 0.25
		ghost_node.add_child(g)
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh()
		ring.material_override = _plain_mat(UI.GOLD, true)
		ring.position = cell_pos(ghost["cell"]) + Vector3(0, 0.02, 0)
		ghost_node.add_child(ring)


static var _ring: ArrayMesh


func _ring_mesh() -> ArrayMesh:
	if _ring != null:
		return _ring
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r1 := RW * 0.99
	var r0 := RW * 0.88
	for k in 6:
		var a := deg_to_rad(-90 + 60 * k)
		var b := deg_to_rad(-90 + 60 * (k + 1))
		var A1 := Vector3(cos(a) * r1, 0, sin(a) * r1)
		var B1 := Vector3(cos(b) * r1, 0, sin(b) * r1)
		var A0 := Vector3(cos(a) * r0, 0, sin(a) * r0)
		var B0 := Vector3(cos(b) * r0, 0, sin(b) * r0)
		st.set_normal(Vector3.UP)
		for v in [A0, B1, A1, A0, B0, B1]:
			st.add_vertex(v)
	_ring = st.commit()
	return _ring


# ------------------------------------------------------------------ camera e input

func _update_cam() -> void:
	if cam == null:
		return
	var p := deg_to_rad(pitch)
	var y := deg_to_rad(yaw)
	var off := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func _ground_at(sp: Vector2) -> Variant:
	if cam == null:
		return null
	var scale := Vector2(vp.size) / size if size.x > 0 else Vector2.ONE
	var from := cam.project_ray_origin(sp * scale)
	var dir := cam.project_ray_normal(sp * scale)
	if absf(dir.y) < 1e-4:
		return null
	var t := -(from.y - BASE_H * 0.5) / dir.y
	if t < 0:
		return null
	return from + dir * t


func cell_at_screen(sp: Vector2) -> Variant:
	var w = _ground_at(sp)
	if w == null:
		return null
	var x: float = w.x / RW
	var z: float = w.z / RW
	var q := SQ3 / 3.0 * x - z / 3.0
	var r := 2.0 / 3.0 * z
	var cx := q
	var cz := r
	var cy := -cx - cz
	var rx := roundf(cx)
	var ry := roundf(cy)
	var rz := roundf(cz)
	var dx := absf(rx - cx)
	var dy := absf(ry - cy)
	var dz := absf(rz - cz)
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
			dist = maxf(3.0, dist / 1.1)
			_auto = false
			_update_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = minf(60.0, dist * 1.1)
			_auto = false
			_update_cam()
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if ev.pressed:
				_drag = ev.button_index
				_drag_from = ev.position
				_moved = 0.0
			else:
				if _moved < 8.0:
					var c = cell_at_screen(ev.position)
					if ev.button_index == MOUSE_BUTTON_LEFT and c != null:
						cell_clicked.emit(c)
					elif ev.button_index == MOUSE_BUTTON_RIGHT:
						rotate_requested.emit(1)
				_drag = 0
	elif ev is InputEventMouseMotion:
		if _drag != 0:
			_moved += ev.relative.length()
			if _moved >= 8.0:
				_auto = false
				if _drag == MOUSE_BUTTON_LEFT:
					yaw -= ev.relative.x * 0.35
					pitch = clampf(pitch + ev.relative.y * 0.25, 22.0, 88.0)
				else:
					var y := deg_to_rad(yaw)
					var right := Vector3(cos(y), 0, -sin(y))
					var fwd := Vector3(sin(y), 0, cos(y))
					target -= (right * ev.relative.x - fwd * ev.relative.y) * dist * 0.0016
				_update_cam()
		else:
			var c = cell_at_screen(ev.position)
			if c != hover:
				hover = c
				cell_hovered.emit(c)
				if not targets.is_empty():
					refresh_marks()
	elif ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 3.0, 60.0)
		_update_cam()
	elif ev is InputEventPanGesture:
		yaw -= ev.delta.x * 2.0
		pitch = clampf(pitch + ev.delta.y * 2.0, 22.0, 88.0)
		_update_cam()
