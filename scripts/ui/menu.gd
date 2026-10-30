extends Control
## Menu principale: giocatori (1-6, persona o IA), carte fauna, moduli dell'espansione Landmarks,
## velocità dell'IA, vista 2D/3D e gioco online.

const D = preload("res://scripts/data/cs_data.gd")
const MODES := ["Persona", "IA facile", "IA normale", "IA difficile"]
const CARD_MODES := ["A (prima partita)", "A–D a caso", "A–G a caso", "Scelte"]

var main
var page: Control
var np := 2
var modes := []                 # per posto: 0..3
var names := []
var speed := 1
var card_mode := 1
var chosen := {}                # animale -> lettera o "?"
var lm_tiles := 1
var lm_module := 0
var view3d := 1
var msg: Label
var seats_box: VBoxContainer
var cards_box: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: Dictionary = main.menu_state
	if not st.is_empty():
		np = st["np"]
		modes = st["modes"].duplicate()
		names = st["names"].duplicate()
		speed = st["speed"]
		card_mode = st["card_mode"]
		chosen = st["chosen"].duplicate()
		lm_tiles = st["lm_tiles"]
		lm_module = st["lm_module"]
		view3d = st["view3d"]
	while modes.size() < 6:
		modes.append(0 if modes.is_empty() else 2)
	while names.size() < 6:
		names.append(D.PLAYER_COLOR_NAMES[names.size()])
	for a in D.ANIMALS:
		if not chosen.has(a):
			chosen[a] = "A"
	_background()
	page = Control.new()
	page.size = Vector2(1920, 1080)
	add_child(page)
	_center.call_deferred()
	get_viewport().size_changed.connect(_center)

	var cover := UI.icon_rect(UI.tex("res://assets/misc/copertina.webp"), Vector2(820, 820))
	cover.position = Vector2(40, 60)
	page.add_child(cover)
	var tag := UI.italic("Foreste, montagne, praterie, zone umide e fiumi del Pacifico nord-occidentale:\ncostruisci il tuo angolo di natura e popolalo di animali.", 22, UI.WOOD)
	tag.position = Vector2(40, 900)
	tag.size = Vector2(820, 70)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(tag)

	var right := PanelContainer.new()
	right.position = Vector2(900, 40)
	right.custom_minimum_size = Vector2(980, 800)
	page.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	rv.add_child(UI.heading("Chi gioca", 30))
	rv.add_child(_segmented("Giocatori", ["1", "2", "3", "4", "5", "6"], np - 1, func(k):
		np = k + 1
		if np > 4:
			lm_tiles = 1
		msg.text = ""
		_refresh_seats(), 70))
	seats_box = VBoxContainer.new()
	seats_box.add_theme_constant_override("separation", 6)
	rv.add_child(seats_box)
	rv.add_child(HSeparator.new())
	rv.add_child(UI.heading("Carte fauna", 26))
	rv.add_child(_segmented("Carte", CARD_MODES, card_mode, func(k):
		card_mode = k
		_refresh_cards(), 180))
	cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 10)
	rv.add_child(cards_box)
	rv.add_child(HSeparator.new())
	rv.add_child(UI.heading("Landmarks e opzioni", 26))
	var on_tiles := func(k):
		lm_tiles = k
		msg.text = "Con 5 o 6 giocatori servono le tessere Landmarks." if (k == 0 and np > 4) else ""
	var t1 := _segmented("Tessere", ["Solo base", "Con le tessere Landmarks"], lm_tiles, on_tiles, 330)
	t1.tooltip_text = "Le 45 tessere dell'espansione (con le chiavi di volta a più habitat) si mescolano a quelle base."
	rv.add_child(t1)
	var on_mod := func(k): lm_module = k
	var t2 := _segmented("Landmark", ["No", "Segnalini e carte Landmark"], lm_module, on_mod, 330)
	t2.tooltip_text = "Chi allarga un corridoio a 5 o più tessere può posarvi un Landmark e prendere una carta punteggio."
	rv.add_child(t2)
	rv.add_child(_segmented("Velocità IA", ["Lenta", "Normale", "Veloce", "Istantanea"], speed, func(k): speed = k, 160))
	rv.add_child(_segmented("Vista", ["2D: le tessere", "3D: miniature e diorami"], view3d, func(k): view3d = k, 330))

	msg = UI.label("", 22, UI.RED, UI.font_bold)
	msg.position = Vector2(900, 1000)
	page.add_child(msg)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.position = Vector2(900, 880)
	page.add_child(btns)
	var b_start := _big_button("Inizia la partita", 420, true)
	b_start.pressed.connect(_on_start)
	btns.add_child(b_start)
	var b_rules := _big_button("Regole", 200)
	b_rules.pressed.connect(func():
		_store()
		main.show_rules())
	btns.add_child(b_rules)
	var b_online := _big_button("Gioca online", 300)
	b_online.pressed.connect(_online_panel)
	btns.add_child(b_online)
	if not OS.has_feature("web"):
		var b_quit := _big_button("Esci", 140)
		b_quit.pressed.connect(func(): get_tree().quit())
		page.add_child(b_quit)
		b_quit.position = Vector2(1740, 980)
	var credits := UI.label("Cascadia © Randy Flynn · illustrazioni di Beth Sobel · Flatout Games / AEG · versione digitale per uso personale · F11 schermo intero", 16, UI.MUTED)
	credits.position = Vector2(40, 1046)
	page.add_child(credits)
	_refresh_seats()
	_refresh_cards()
	if not main.lobby.is_empty():
		_online_panel.call_deferred()


func _background() -> void:
	var bg := ColorRect.new()
	bg.color = UI.PAPER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(UI.WOOD, 0.22))
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.45)
	grad.fill_to = Vector2(1.1, 1.1)
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _center() -> void:
	var vs := get_viewport_rect().size
	var k := minf(vs.x / 1920.0, vs.y / 1080.0)
	page.scale = Vector2(k, k) if k < 1.0 else Vector2.ONE
	page.position = ((vs - page.size * page.scale) * 0.5).floor()
	page.position.y = maxf(0.0, page.position.y)


func _store() -> void:
	main.menu_state = {"np": np, "modes": modes.duplicate(), "names": names.duplicate(), "speed": speed,
		"card_mode": card_mode, "chosen": chosen.duplicate(), "lm_tiles": lm_tiles, "lm_module": lm_module, "view3d": view3d}


func _refresh_seats() -> void:
	for c in seats_box.get_children():
		c.queue_free()
	var compact := np > 3
	var holder: Container = seats_box
	if compact:
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 6)
		seats_box.add_child(g)
		holder = g
	for i in np:
		var col := UI.pcol(i)
		var row := PanelContainer.new()
		var sb := UI.panel_style(Color(col, 0.13), Color(col, 0.8), 2, 8)
		sb.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", sb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var chip := ColorRect.new()
		chip.color = col
		chip.custom_minimum_size = Vector2(12, 40)
		hb.add_child(chip)
		var le := LineEdit.new()
		le.text = names[i]
		le.max_length = 20
		le.custom_minimum_size = Vector2(230 if compact else 260, 40)
		le.add_theme_font_size_override("font_size", 20)
		var ii := i
		le.text_changed.connect(func(t): names[ii] = t)
		hb.add_child(le)
		if compact:
			var ob := OptionButton.new()
			for m in MODES:
				ob.add_item(m)
			ob.selected = modes[i]
			ob.custom_minimum_size = Vector2(190, 40)
			ob.item_selected.connect(func(k): modes[ii] = k)
			hb.add_child(ob)
		else:
			for m in MODES.size():
				var b := Button.new()
				b.text = MODES[m]
				b.custom_minimum_size = Vector2(150, 42)
				b.add_theme_font_size_override("font_size", 18)
				if modes[i] == m:
					UI.primary(b)
				var mm := m
				b.pressed.connect(func():
					modes[ii] = mm
					msg.text = ""
					_refresh_seats())
				hb.add_child(b)
		holder.add_child(row)


func _refresh_cards() -> void:
	for c in cards_box.get_children():
		c.queue_free()
	if card_mode != 3:
		var t := UI.italic(["Le carte A di ogni animale: consigliate per la prima partita.",
			"Una carta a caso fra A, B, C e D per ogni animale (il gioco base).",
			"Una carta a caso fra A e G: comprese le carte E, F e G di Landmarks."][card_mode], 19)
		cards_box.add_child(t)
		return
	for a in D.ANIMALS:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		var tr := TextureRect.new()
		tr.texture = UI.card_tex("%s_%s" % [a, chosen[a]]) if chosen[a] != "?" else UI.token_tex(a)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(170, 92)
		vb.add_child(tr)
		var ob := OptionButton.new()
		for l in ["?", "A", "B", "C", "D", "E", "F", "G"]:
			ob.add_item(("%s %s" % [D.ANI_NAME[a], l]) if l != "?" else "%s a caso" % D.ANI_NAME[a])
		ob.selected = "?ABCDEFG".find(chosen[a])
		ob.custom_minimum_size = Vector2(170, 36)
		var aa: String = a
		ob.item_selected.connect(func(k):
			chosen[aa] = "?ABCDEFG"[k]
			_refresh_cards())
		vb.add_child(ob)
		cards_box.add_child(vb)


func _segmented(label_text: String, items: Array, cur: int, cb: Callable, w := 200) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var l := UI.label(label_text, 21, UI.WOOD, UI.font_bold)
	l.custom_minimum_size = Vector2(150, 0)
	hb.add_child(l)
	var btns := []
	for k in range(items.size()):
		var b := Button.new()
		b.text = items[k]
		b.custom_minimum_size = Vector2(w, 42)
		b.add_theme_font_size_override("font_size", 18)
		hb.add_child(b)
		btns.append(b)
	var paint := func(sel: int):
		for k in range(btns.size()):
			if k == sel:
				UI.primary(btns[k])
			else:
				for s in ["normal", "hover", "pressed"]:
					btns[k].remove_theme_stylebox_override(s)
				for s in ["font_color", "font_hover_color", "font_pressed_color"]:
					btns[k].remove_theme_color_override(s)
	for k in range(btns.size()):
		btns[k].pressed.connect(func():
			cb.call(k)
			paint.call(k))
	paint.call(cur)
	return hb


func _big_button(text: String, w: float, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 74)
	b.add_theme_font_override("font", UI.font_semi)
	b.add_theme_font_size_override("font_size", 30)
	if primary:
		UI.primary(b)
	return b


## Configurazione scelta nel menu (anche quella che, online, viaggia agli altri).
func _config() -> Dictionary:
	var seats := []
	for i in np:
		var m: int = modes[i]
		var nm: String = str(names[i]).strip_edges()
		if nm == "":
			nm = D.PLAYER_COLOR_NAMES[i]
		seats.append({"name": nm, "ai": m != 0, "level": maxi(0, m - 1)})
	var speeds := [1.2, 0.6, 0.2, 0.0]
	var cards := {}
	var pool := "ABCD"
	match card_mode:
		0:
			for a in D.ANIMALS:
				cards[a] = "A"
		1:
			pool = "ABCD"
		2:
			pool = "ABCDEFG"
		3:
			cards = chosen.duplicate()
			pool = "ABCDEFG"
	return {"seats": seats, "ai_delay": speeds[speed], "cards": cards, "card_pool": pool,
		"lm_tiles": lm_tiles == 1 or np > 4, "lm_module": lm_module == 1, "view3d": view3d == 1}


func _on_start() -> void:
	if np > 4 and lm_tiles == 0:
		lm_tiles = 1
	_store()
	main.start_game(_config())


# =================================================================== online

var on_panel: Control
var on_name: LineEdit
var on_code: LineEdit
var on_lbl: Label
var on_start: Button


func _online_panel() -> void:
	if is_instance_valid(on_panel):
		on_panel.queue_free()
	on_panel = Control.new()
	on_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(on_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.07, 0.04, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	on_panel.add_child(shade)
	var box := PanelContainer.new()
	box.position = page.position + Vector2(560, 130) * page.scale
	box.scale = page.scale
	box.custom_minimum_size = Vector2(800, 0)
	on_panel.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	vb.add_child(UI.heading("Gioca online", 40))
	var info := UI.label("Chi crea la stanza sceglie prima nel menu giocatori e opzioni: i posti su PERSONA diventano i posti per gli amici (il primo è il suo). Gli amici entrano con il codice. I posti rimasti liberi li gioca l'IA.", 20, UI.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(760, 0)
	vb.add_child(info)
	var ses: Dictionary = main.get_net().load_session()
	on_name = _line("Il tuo nome", 20)
	on_name.text = str(ses.get("name", ""))
	vb.add_child(on_name)
	var b_create := UI.button("Crea una stanza", 0, 60, 24)
	b_create.pressed.connect(_online_create)
	vb.add_child(b_create)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	on_code = _line("Codice", 4)
	on_code.custom_minimum_size.x = 220
	on_code.text_changed.connect(func(t):
		on_code.text = t.to_upper()
		on_code.caret_column = t.length())
	row.add_child(on_code)
	var b_join := UI.button("Entra", 200, 60, 24)
	b_join.pressed.connect(_online_join)
	row.add_child(b_join)
	vb.add_child(row)
	on_lbl = UI.label("", 21, UI.INK)
	on_lbl.custom_minimum_size = Vector2(760, 120)
	on_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(on_lbl)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	on_start = _big_button("Inizia online", 420, true)
	on_start.pressed.connect(_online_start)
	on_start.visible = main.lobby.get("role", "") == "host"
	row2.add_child(on_start)
	var b_close := _big_button("Indietro", 300)
	b_close.pressed.connect(func(): on_panel.queue_free())
	row2.add_child(b_close)
	vb.add_child(row2)
	if not main.lobby.is_empty():
		on_code.text = main.lobby["code"]
		on_lbl.text = "Stanza %s…" % main.lobby["code"]
	elif str(ses.get("room", "")) != "":
		on_code.text = str(ses["room"])
		on_lbl.text = "Eri nella stanza %s: premi Entra per rientrare." % ses["room"]


func _line(ph: String, maxlen: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = maxlen
	le.custom_minimum_size = Vector2(0, 60)
	le.add_theme_font_size_override("font_size", 28)
	return le


func _say(t: String) -> void:
	if is_instance_valid(on_lbl):
		on_lbl.text = t


func _seat_label(i: int) -> String:
	return D.PLAYER_COLOR_NAMES[i]


func _seats_text(room: Dictionary) -> String:
	var seats := Net._as_dict(room.get("seats", {}))
	var parts := []
	for idx in room.get("open", []):
		var k := str(int(idx))
		var who := str(seats[k].get("name", "?")) if seats.has(k) and seats[k] is Dictionary else "libero"
		parts.append("%s: %s" % [_seat_label(int(idx)), who])
	return ", ".join(parts)


func _online_create() -> void:
	var nm := on_name.text.strip_edges()
	if nm == "":
		_say("Scrivi il tuo nome.")
		return
	var seats := []
	var list: Array = _config()["seats"]
	for i in list.size():
		if not list[i]["ai"]:
			seats.append(i)
	if seats.size() < 2:
		_say("Metti su PERSONA almeno due posti: il primo è il tuo, gli altri sono per gli amici.")
		return
	_store()
	_say("Creo la stanza…")
	var net: Net = main.get_net()
	var code := await net.create_room(nm, seats)
	if code == "":
		_say("Non riesco a creare la stanza.\n%s" % net.last_error)
		return
	main.lobby = {"role": "host", "code": code, "seat": seats[0]}
	net.remember_room(code, seats[0])
	net._save({"name": nm})
	if is_instance_valid(on_code):
		on_code.text = code
	if is_instance_valid(on_start):
		on_start.visible = true
	_lobby_poll(code)


func _online_join() -> void:
	var code := on_code.text.strip_edges().to_upper()
	var nm := on_name.text.strip_edges()
	if nm == "" or code.length() != 4:
		_say("Scrivi il tuo nome e il codice di 4 lettere.")
		return
	_say("Entro nella stanza %s…" % code)
	var net: Net = main.get_net()
	var seat := await net.join_room(code, nm)
	if seat == -2:
		_say("Stanza %s non trovata, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""])
		return
	if seat == -1:
		_say("Nella stanza %s non ci sono posti liberi." % code)
		return
	var room: Dictionary = net.last_room
	main.lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") in ["playing", "over"] and room.has("game"):
		_say("Rientro nella partita della stanza %s…" % code)
		_begin(room["game"], true)
		return
	if is_instance_valid(on_start):
		on_start.visible = main.lobby["role"] == "host"
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and main.lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or main.lobby.get("code", "") != code:
			return
		if room.is_empty():
			_say("La stanza %s non esiste più." % code)
			main.lobby = {}
			return
		if main.lobby["role"] == "host":
			_say("Stanza [ %s ]: dai il codice ai tuoi amici.\nPosti: %s.\nQuando ci siete tutti premi Inizia online: i posti liberi li gioca l'IA." % [code, _seats_text(room)])
		else:
			if room.get("status", "") == "playing" and room.has("game"):
				_begin(room["game"], false)
				return
			_say("Sei nella stanza [ %s ] (posto: %s).\nAspetta che chi l'ha creata avvii la partita." % [code, _seat_label(int(main.lobby["seat"]))])
		await get_tree().create_timer(2.0).timeout


## Chi ha creato la stanza avvia: giocatori, opzioni e seme valgono per tutti.
func _online_start() -> void:
	var code: String = main.lobby["code"]
	var net: Net = main.get_net()
	var room := await net.room(code)
	if room.is_empty():
		_say("La stanza %s non esiste più." % code)
		main.lobby = {}
		return
	var seats_db := Net._as_dict(room.get("seats", {}))
	var cfg := _config()
	var my_seat := int(main.lobby["seat"])
	if my_seat >= cfg["seats"].size() or not seats_db.has(str(my_seat)) or cfg["seats"][my_seat]["ai"]:
		_say("Hai cambiato i giocatori dopo aver creato la stanza: creane una nuova.")
		return
	for i in cfg["seats"].size():
		var k := str(i)
		if seats_db.has(k) and seats_db[k] is Dictionary and not cfg["seats"][i]["ai"]:
			cfg["seats"][i]["name"] = str(seats_db[k].get("name", cfg["seats"][i]["name"]))
		else:
			cfg["seats"][i]["ai"] = true
	cfg["seed"] = 1 + randi() % 2000000000
	cfg.erase("view3d")
	var g := {"cfg": var_to_str(cfg)}
	if not await net.start_room(code, g):
		_say("Non riesco ad avviare la partita (%s)." % net.last_error)
		return
	_begin(g, false)


func _begin(g: Dictionary, rejoin: bool) -> void:
	var net: Net = main.get_net()
	var lob: Dictionary = main.lobby
	var backlog: Array = []
	if rejoin:
		backlog = await net.get_acts(lob["code"])
		net.set_away(lob["code"], int(lob["seat"]), false)
	var cfg = str_to_var(str(g.get("cfg", "")))
	if not (cfg is Dictionary):
		_say("Configurazione della partita non valida.")
		return
	var ses := OnlineSession.new()
	ses.setup(net, lob["code"], int(lob["seat"]), lob["role"], backlog)
	cfg["online"] = ses
	cfg["view3d"] = view3d == 1
	main.lobby = {}
	main.start_game(cfg)
