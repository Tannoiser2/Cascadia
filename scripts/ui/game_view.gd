extends Control
## Vista di gioco: l'offerta (4 coppie tessera + animale) a sinistra, l'ambiente del giocatore al centro
## (2D con le tessere del gioco oppure 3D con diorami e miniature), giocatori e carte punteggio a destra,
## la barra delle decisioni in basso, il diario e il riepilogo dei punti.

const D = preload("res://scripts/data/cs_data.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const Board3D = preload("res://scripts/ui/board3d.gd")

var main
var config: Dictionary
var engine: CSEngine
var online = null
var pending: Dictionary = {}
var viewer := 0
var pinned := false
var local_seats: Array = []
var _dirty := false
var view3d := false

var map                          # vista attiva
var map2d
var map3d
var center_box: Control
var view_btn: Button
var turn_lbl: Label
var hint_lbl: Label
var status_lbl: Label
var act_box: HBoxContainer
var offer_rows: Array = []
var nature_lbl: Label
var deck_lbl: Label
var b_free: Button
var b_wipe: Button
var players_box: VBoxContainer
var cards_box: GridContainer
var right_panel: PanelContainer
var left_box: VBoxContainer
var card_w := 80.0               # larghezza delle carte nella colonna destra (calcolata in _layout)
var lm_card_w := 80.0
var bot_panel: PanelContainer
var side_w := 404.0
var player_row_h := 50.0             # larghezza della colonna destra, si adatta alla finestra
var lm_box: VBoxContainer
var log_panel: PanelContainer
var log_text: RichTextLabel
var overlay: Control
var env_lbl: Label

# stato delle scelte in corso
var dmode := ""                  # "", "free", "wipe"
var sel_t := -1
var sel_w := -1
var wipe_sel: Array = []
var ghost := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = CSEngine.new()
	add_child(engine)
	online = config.get("online", null)
	if online != null:
		add_child(online)
		online.view = self
		engine.online = online
	engine.setup(config)
	for s in engine.players.size():
		var p: Dictionary = engine.players[s]
		engine.ais[s] = CSAI.new(int(p["level"]), int(config.get("seed", 0)) * 7 + s + 1 if config.has("seed") else randi())
		if online != null:
			if s == online.seat:
				local_seats.append(s)
		elif not p["ai"]:
			local_seats.append(s)
	viewer = local_seats[0] if not local_seats.is_empty() else 0
	engine.ai_delay = float(config.get("ai_delay", 0.6))
	view3d = bool(config.get("view3d", false))
	_build()
	engine.changed.connect(_mark)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.game_ended.connect(_on_end)
	engine.fx.connect(_on_fx)
	_layout()
	get_viewport().size_changed.connect(_layout)
	_refresh()
	_fit_later()
	if online != null and online.role != "host":
		online.heartbeat_loop()
	engine.run.call_deferred()


func _fit_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	map.fit()


func _mark() -> void:
	if not _dirty:
		_dirty = true
		_refresh.call_deferred()


# ================================================================ costruzione

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#195f35")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# tappeto verde da tavolo da gioco (trama ripetuta) con i bordi più scuri
	var felt := TextureRect.new()
	felt.texture = UI.tex("res://assets/misc/panno.webp")
	felt.stretch_mode = TextureRect.STRETCH_TILE
	felt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(felt)
	var vig := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.45))
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.05, 1.05)
	vig.texture = grad
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	# --- barra in alto
	var top := PanelContainer.new()
	var tsb := UI.wood_style(0)
	tsb.set_content_margin_all(8)
	top.add_theme_stylebox_override("panel", tsb)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 66
	add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	th.add_child(UI.title("Cascadia", 34, UI.CREAM))
	turn_lbl = UI.label("", 24, UI.CREAM, UI.font_semi)
	turn_lbl.custom_minimum_size.x = 470
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th.add_child(turn_lbl)
	status_lbl = UI.label("", 19, Color("#f2d79a"))
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_lbl.clip_text = true
	status_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_lbl.custom_minimum_size.x = 80
	th.add_child(status_lbl)
	view_btn = UI.button("", 150, 46, 19)
	view_btn.pressed.connect(_toggle_3d)
	th.add_child(view_btn)
	var b_pts := UI.button("Punti", 110, 46, 19)
	b_pts.pressed.connect(func(): _show_scores(false))
	th.add_child(b_pts)
	var b_rules := UI.button("Regole", 120, 46, 19)
	b_rules.pressed.connect(_show_rules_popup)
	th.add_child(b_rules)
	var b_log := UI.button("Diario", 110, 46, 19)
	b_log.pressed.connect(func(): log_panel.visible = not log_panel.visible)
	th.add_child(b_log)
	var b_menu := UI.button("Menu", 100, 46, 19)
	b_menu.pressed.connect(_confirm_menu)
	th.add_child(b_menu)

	# --- offerta a sinistra
	var left := PanelContainer.new()
	left.position = Vector2(12, 78)
	left.custom_minimum_size = Vector2(332, 0)
	left.set_anchor(SIDE_BOTTOM, 1.0)
	left.offset_bottom = -12
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	left_box = lv
	lv.add_child(UI.heading("Offerta", 26))
	for i in 4:
		var row := OfferRow.new()
		row.view = self
		row.slot = i
		row.custom_minimum_size = Vector2(310, 150)
		lv.add_child(row)
		offer_rows.append(row)
	deck_lbl = UI.label("", 18, UI.MUTED)
	lv.add_child(deck_lbl)
	lv.add_child(HSeparator.new())
	var nh := HBoxContainer.new()
	nh.add_child(UI.icon_rect(UI.token_tex("natura"), Vector2(40, 40)))
	nature_lbl = UI.label("", 20, UI.WOOD, UI.font_semi)
	nh.add_child(nature_lbl)
	lv.add_child(nh)
	b_free = UI.button("Scegli tessera e animale separati", 310, 44, 17)
	b_free.tooltip_text = "Spendi un segnalino Natura per prendere una tessera qualunque e un animale qualunque dell'offerta."
	b_free.pressed.connect(func(): _set_dmode("free"))
	lv.add_child(b_free)
	b_wipe = UI.button("Rimescola animali a scelta", 310, 44, 17)
	b_wipe.tooltip_text = "Spendi un segnalino Natura per rimettere nel sacchetto gli animali che scegli e pescarne di nuovi."
	b_wipe.pressed.connect(func(): _set_dmode("wipe"))
	lv.add_child(b_wipe)

	# --- destra: giocatori e carte
	var right := PanelContainer.new()
	right.set_anchor(SIDE_LEFT, 1.0)
	right.set_anchor(SIDE_RIGHT, 1.0)
	right.set_anchor(SIDE_BOTTOM, 1.0)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -12
	right.offset_top = 78
	right.offset_bottom = -12
	add_child(right)
	right_panel = right
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(rv)
	rv.add_child(UI.heading("Giocatori", 28))
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 4)
	rv.add_child(players_box)
	rv.add_child(HSeparator.new())
	rv.add_child(UI.heading("Carte fauna", 26))
	cards_box = GridContainer.new()
	cards_box.columns = 5
	cards_box.add_theme_constant_override("h_separation", 6)
	cards_box.add_theme_constant_override("v_separation", 6)
	rv.add_child(cards_box)
	for a in D.ANIMALS:
		var key := engine.card_key(a)
		var b := TextureButton.new()
		b.texture_normal = UI.card_tex(key)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.tooltip_text = "%s %s — %s\n%s" % [D.ANI_NAME[a], engine.cards[a], D.WILD_CARDS[a][engine.cards[a]][0], D.WILD_CARDS[a][engine.cards[a]][1]]
		b.pressed.connect(func(): _zoom_card(key))
		cards_box.add_child(b)
	lm_box = VBoxContainer.new()
	lm_box.add_theme_constant_override("separation", 4)
	rv.add_child(lm_box)

	# --- centro: ambiente
	center_box = Control.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.offset_left = 356
	center_box.offset_right = -416
	center_box.offset_top = 78
	center_box.offset_bottom = -118
	add_child(center_box)
	map2d = MapView.new()
	map2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.add_child(map2d)
	map2d.cell_clicked.connect(_on_cell)
	map2d.cell_hovered.connect(_on_hover)
	map2d.rotate_requested.connect(_rotate)
	map3d = Board3D.new()
	map3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_box.add_child(map3d)
	map3d.cell_clicked.connect(_on_cell)
	map3d.cell_hovered.connect(_on_hover)
	map3d.rotate_requested.connect(_rotate)
	env_lbl = UI.heading("", 24, UI.CREAM)
	env_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	env_lbl.add_theme_constant_override("shadow_offset_y", 2)
	env_lbl.position = Vector2(14, 8)
	center_box.add_child(env_lbl)
	var b_fit := UI.button("Centra", 110, 40, 17)
	b_fit.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b_fit.position = Vector2(-124, 8)
	b_fit.pressed.connect(func(): map.fit())
	center_box.add_child(b_fit)
	_apply_view()

	# --- barra delle decisioni
	var bot := PanelContainer.new()
	bot_panel = bot
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 356
	bot.offset_right = -416
	bot.offset_top = -108
	bot.offset_bottom = -12
	add_child(bot)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bot.add_child(bh)
	hint_lbl = UI.label("", 21, UI.INK, UI.font_semi)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(hint_lbl)
	act_box = HBoxContainer.new()
	act_box.add_theme_constant_override("separation", 8)
	bh.add_child(act_box)

	# --- diario
	log_panel = PanelContainer.new()
	log_panel.set_anchor(SIDE_LEFT, 1.0)
	log_panel.set_anchor(SIDE_RIGHT, 1.0)
	log_panel.offset_left = -820
	log_panel.offset_right = -420
	log_panel.offset_top = 80
	log_panel.offset_bottom = 680
	log_panel.visible = false
	add_child(log_panel)
	log_text = RichTextLabel.new()
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 17)
	log_panel.add_child(log_text)


## Adatta le colonne alla finestra: niente scorrimento, tutto deve starci.
## Destra: giocatori, le 5 carte fauna su una riga, le carte Landmark in righe da 5 (una per giocatore).
## Sinistra: le 4 coppie dell'offerta si accorciano se la finestra è bassa.
func _layout() -> void:
	var vs := get_viewport_rect().size
	side_w = clampf(vs.x * 0.27, 470.0, 760.0)
	right_panel.offset_left = -side_w - 12
	center_box.offset_right = -side_w - 24
	bot_panel.offset_right = -side_w - 24
	log_panel.offset_right = -side_w - 28
	log_panel.offset_left = log_panel.offset_right - 420
	var n := engine.players.size()
	var inner := side_w - 24.0
	var avail := vs.y - 78.0 - 12.0 - 24.0
	# altezza fissa: titoli, separatori, righe dei giocatori
	var pr := clampf((avail * 0.26) / n, 38.0, 58.0)
	player_row_h = pr
	var fixed := 3 * 38.0 + 2 * 10.0 + n * (pr + 4.0) + 6 * 6.0
	var rest := avail - fixed
	var w_max := floorf((inner - 4 * 6.0) / 5.0)
	var w := w_max
	if engine.lm_module:
		# carte fauna (alte 1,73 volte la larghezza) + n righe di carte Landmark (0,66)
		w = minf(w_max, floorf((rest - n * 4.0) / (1.73 + 0.66 * n)))
	else:
		w = minf(w_max, floorf(rest / 1.73))
	card_w = maxf(w, 40.0)
	lm_card_w = card_w
	for b in cards_box.get_children():
		b.custom_minimum_size = Vector2(card_w, roundf(card_w * 1.73))
	# sinistra: 4 righe dell'offerta
	var left_fixed := 38.0 + 26.0 + 10.0 + 44.0 + 2 * 46.0 + 8 * 6.0 + 24.0
	var rh := clampf((avail - left_fixed) / 4.0, 80.0, 165.0)
	for r in offer_rows:
		r.custom_minimum_size = Vector2(310, rh)
	_mark()


func _apply_view() -> void:
	map = map3d if view3d else map2d
	map2d.visible = not view3d
	map3d.visible = view3d
	view_btn.text = "Vista 2D" if view3d else "Vista 3D"


func _toggle_3d() -> void:
	view3d = not view3d
	_apply_view()
	_refresh()
	map.fit()


# ================================================================ aggiornamento

func _refresh() -> void:
	_dirty = false
	if engine == null:
		return
	var s := engine.current
	if not pending.is_empty():
		viewer = int(pending["seat"])
	elif not pinned and s >= 0:
		viewer = s
	var n := engine.players.size()
	var t := engine.turn_no
	if engine.game_over:
		turn_lbl.text = "Partita finita"
	elif s >= 0:
		turn_lbl.text = "Turno %d di %d · tocca a %s" % [mini(t, CSEngine.TURNS), CSEngine.TURNS, engine.pname(s)]
	deck_lbl.text = "Tessere nel mazzo: %d" % engine.deck.size()
	for r in offer_rows:
		r.queue_redraw()
	var me := int(pending["seat"]) if not pending.is_empty() else -1
	var nat: int = engine.nature[me] if me >= 0 else (engine.nature[viewer] if viewer >= 0 else 0)
	nature_lbl.text = "  Segnalini Natura: %d" % nat
	var drafting: bool = not pending.is_empty() and pending["type"] == "draft"
	b_free.disabled = not drafting or nat <= 0
	b_wipe.disabled = not drafting or nat <= 0
	_refresh_players()
	_refresh_lm()
	# ambiente mostrato
	var env: Dictionary = engine.envs[viewer]
	env_lbl.text = "Ambiente di %s" % engine.pname(viewer)
	env_lbl.add_theme_color_override("font_color", UI.pcol(viewer).lightened(0.55))
	var tg: Array = []
	var kind := ""
	if not pending.is_empty():
		match str(pending["type"]):
			"place_tile":
				tg = engine.frontier(viewer)
				kind = "tile"
			"place_token":
				tg = pending["cells"]
				kind = "token"
	for m in [map2d, map3d]:
		m.targets = tg
		m.target_kind = kind
		m.ghost = ghost
		m.ghost_animal = str(pending.get("animal", "")) if kind == "token" else ""
		m.last_cell = engine.last_cell if viewer == engine.current else null
		m.pcolor = UI.pcol(viewer)
	if map == map2d:
		map2d.set_env(env)
	else:
		map3d.set_env(env)
	map2d.queue_redraw()


func _refresh_players() -> void:
	for c in players_box.get_children():
		c.queue_free()
	var sc := engine.live_scores()
	for s in engine.players.size():
		var row := PanelContainer.new()
		var on := s == engine.current and not engine.game_over
		var sb := UI.panel_style(Color(UI.pcol(s), 0.22 if on else 0.08), UI.pcol(s) if (on or s == viewer) else Color(UI.pcol(s), 0.35), 3 if s == viewer else 1, 8)
		sb.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Clic per vedere l'ambiente di %s" % engine.pname(s)
		var ss := s
		row.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if pending.is_empty():
					viewer = ss
					pinned = ss != engine.current
					_refresh()
					map.fit())
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		var chip := ColorRect.new()
		chip.color = UI.pcol(s)
		chip.custom_minimum_size = Vector2(12, player_row_h - 12.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(chip)
		var nm := UI.label(engine.pname(s) + (" (IA)" if engine.players[s]["ai"] else ""), 23, UI.INK, UI.font_semi)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		hb.add_child(nm)
		# carte Landmark prese da questo giocatore (piccole, una per habitat)
		for k in engine.lm_cards[s]:
			var lb := _card_button(k, Vector2(roundf((player_row_h - 14.0) * 1.5), player_row_h - 14.0))
			hb.add_child(lb)
		hb.add_child(UI.icon_rect(UI.token_tex("natura"), Vector2(34, 34)))
		hb.add_child(UI.label("%d" % engine.nature[s], 23, UI.WOOD, UI.font_bold))
		var pts := UI.label("  %d pt" % sc[s]["total"], 25, UI.PINE, UI.font_bold)
		pts.tooltip_text = "Punteggio se la partita finisse adesso"
		hb.add_child(pts)
		for ch in hb.get_children():
			if not (ch is TextureButton):
				ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		players_box.add_child(row)


func _refresh_lm() -> void:
	for c in lm_box.get_children():
		c.queue_free()
	if not engine.lm_module:
		return
	lm_box.add_child(HSeparator.new())
	lm_box.add_child(UI.heading("Carte Landmark disponibili", 24))
	var lsz := Vector2(lm_card_w, roundf(lm_card_w * 0.66))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	lm_box.add_child(grid)
	var rows := 2 if engine.players.size() == 1 else engine.players.size()
	for r in rows:
		for h in D.HABITATS:
			var offer: Array = engine.lm_offer.get(h, [])
			if r < offer.size():
				grid.add_child(_card_button("%s_%s" % [h, offer[r]], lsz))
			else:
				var empty := Control.new()
				empty.custom_minimum_size = lsz
				grid.add_child(empty)


func _card_button(key: String, sz: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = UI.card_tex(key)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = sz
	var h := key.substr(0, key.length() - 2)
	var tx := D.lm_card_text(h, key.substr(key.length() - 1))
	b.tooltip_text = "%s — %s\n%s" % [D.HAB_NAME[h], tx[0], tx[1]]
	b.pressed.connect(func(): _zoom_card(key))
	return b


# ================================================================ decisioni

func _on_decision(req: Dictionary) -> void:
	pending = req
	pinned = false
	viewer = int(req["seat"])
	dmode = ""
	sel_t = -1
	sel_w = -1
	wipe_sel = []
	ghost = {}
	_show_decision()
	_refresh()
	if req["type"] == "place_tile" and engine.envs[viewer].size() <= 4:
		map.fit()


func _clear_actions() -> void:
	for c in act_box.get_children():
		c.queue_free()


func _act(text: String, cb: Callable, primary := false, w := 170.0) -> Button:
	var b := UI.button(text, w, 56, 19)
	if primary:
		UI.primary(b)
	b.pressed.connect(cb)
	act_box.add_child(b)
	return b


func _show_decision() -> void:
	_clear_actions()
	if pending.is_empty():
		hint_lbl.text = ""
		return
	var who := ("%s: " % engine.pname(int(pending["seat"]))) if local_seats.size() > 1 else ""
	match str(pending["type"]):
		"overpop":
			hint_lbl.text = who + "Sovrappopolazione: nell'offerta ci sono tre %s. Vuoi rimetterli nel sacchetto e pescarne altri tre?" % D.ANI_PLURAL[pending["animal"]].to_lower()
			_act("Rimescola", func(): _provide(true), true)
			_act("Tieni", func(): _provide(false))
		"draft":
			match dmode:
				"free":
					hint_lbl.text = who + "Segnalino Natura: scegli una tessera e un animale qualunque nell'offerta (clic sulla tessera, poi sull'animale)."
					var ok := _act("Conferma", func(): _provide({"k": "free", "t": sel_t, "w": sel_w}), true)
					ok.disabled = sel_t < 0 or sel_w < 0
					_act("Annulla", func(): _set_dmode(""))
				"wipe":
					hint_lbl.text = who + "Segnalino Natura: clicca gli animali da rimettere nel sacchetto, poi conferma."
					var ok := _act("Rimescola", func(): _provide({"k": "wipe", "s": wipe_sel.duplicate()}), true)
					ok.disabled = wipe_sel.is_empty()
					_act("Annulla", func(): _set_dmode(""))
				_:
					hint_lbl.text = who + "Scegli una coppia tessera + animale nell'offerta a sinistra."
		"keystone":
			hint_lbl.text = who + "Landmarks: scegli la chiave di volta in più da aggiungere al tuo ambiente."
			_show_keystones()
		"place_tile":
			hint_lbl.text = who + "Posa la tessera: clic su uno spazio accanto al tuo ambiente, ruotala (clic destro o R), poi conferma."
			_rot_button(-1)
			_rot_button(1)
			var ok := _act("Conferma", _confirm_tile, true)
			ok.disabled = ghost.is_empty()
		"landmark":
			hint_lbl.text = who + "Il corridoio ha raggiunto 5 tessere: puoi posare un Landmark su questa tessera (poi non potrà ospitare animali)."
			_show_landmarks()
		"place_token":
			var a: String = pending["animal"]
			hint_lbl.text = who + "Metti %s su una tessera bordata d'oro (su una chiave di volta guadagni un segnalino Natura)." % engine._art(a)
			_act("Rimetti nel sacchetto", func(): _provide([]), false, 240)


## Pulsante di rotazione con la freccia disegnata (nessun simbolo di testo: i font non li hanno).
func _rot_button(dir: int) -> void:
	var b := RotButton.new()
	b.dir = dir
	b.custom_minimum_size = Vector2(64, 56)
	b.tooltip_text = "Ruota in senso orario (R, E, clic destro)" if dir > 0 else "Ruota in senso antiorario (Q)"
	b.pressed.connect(func(): _rotate(dir))
	act_box.add_child(b)


func _set_dmode(m: String) -> void:
	if pending.is_empty() or pending["type"] != "draft":
		return
	dmode = m
	sel_t = -1
	sel_w = -1
	wipe_sel = []
	_show_decision()
	_refresh()


func offer_click(slot: int, part: String) -> void:
	if pending.is_empty() or pending["type"] != "draft":
		return
	match dmode:
		"free":
			if part == "tile":
				sel_t = slot
			else:
				sel_w = slot
			_show_decision()
		"wipe":
			if part == "token":
				if wipe_sel.has(slot):
					wipe_sel.erase(slot)
				else:
					wipe_sel.append(slot)
			_show_decision()
		_:
			_provide({"k": "pair", "i": slot})
			return
	for r in offer_rows:
		r.queue_redraw()


func _on_cell(c: Vector2i) -> void:
	if pending.is_empty():
		return
	match str(pending["type"]):
		"place_tile":
			if not engine.can_place(viewer, c):
				return
			if not ghost.is_empty() and ghost["cell"] == c:
				_confirm_tile()
				return
			var rot: int = ghost.get("rot", _best_rot(c))
			ghost = {"cell": c, "id": engine.held_tile, "rot": rot}
			_show_decision()
			_refresh()
		"place_token":
			if pending["cells"].has(c):
				_provide([c.x, c.y])


## Rotazione iniziale proposta: quella che allunga di più i corridoi.
func _best_rot(c: Vector2i) -> int:
	var env: Dictionary = engine.envs[viewer]
	var best := 0
	var bv := -1
	for r in 6:
		env[c] = {"id": engine.held_tile, "rot": r, "a": "", "lm": ""}
		var v := 0
		for d in 6:
			var n: Vector2i = c + D.DIRS[d]
			if env.has(n) and CSScore.edge_hab(env, c, d) == CSScore.edge_hab(env, n, (d + 3) % 6):
				v += 1
		env.erase(c)
		if v > bv:
			bv = v
			best = r
	return best


func _on_hover(_c) -> void:
	pass


func _rotate(step: int) -> void:
	if pending.is_empty() or pending["type"] != "place_tile" or ghost.is_empty():
		return
	ghost["rot"] = posmod(int(ghost["rot"]) + step, 6)
	_refresh()


func _confirm_tile() -> void:
	if ghost.is_empty():
		return
	var c: Vector2i = ghost["cell"]
	var r: int = ghost["rot"]
	ghost = {}
	_provide([c.x, c.y, r])


func _provide(v) -> void:
	if pending.is_empty():
		return
	pending = {}
	dmode = ""
	ghost = {}
	_close_overlay()
	_clear_actions()
	hint_lbl.text = ""
	engine.provide_decision(v)
	_mark()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_R, KEY_E:
				_rotate(1)
			KEY_Q:
				_rotate(-1)
			KEY_ENTER, KEY_KP_ENTER:
				if not pending.is_empty() and pending["type"] == "place_tile":
					_confirm_tile()
			KEY_ESCAPE:
				if dmode != "":
					_set_dmode("")
				elif overlay != null and not (not pending.is_empty() and pending["type"] in ["keystone", "landmark"]):
					_close_overlay()


# ================================================================ finestre

func _open_overlay(w: float) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.08, 0.04, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb


func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _zoom_card(key: String) -> void:
	var vb := _open_overlay(560)
	var a := key.substr(0, key.length() - 2)
	var l := key.substr(key.length() - 1)
	if D.ANIMALS.has(a):
		vb.add_child(UI.heading("%s — carta %s: «%s»" % [D.ANI_FULL[a], l, D.WILD_CARDS[a][l][0]], 26))
		vb.add_child(UI.icon_rect(UI.card_tex(key), Vector2(520, 600)))
		vb.add_child(UI.wrap(UI.label(D.WILD_CARDS[a][l][1], 20), 520))
	else:
		var tx := D.lm_card_text(a, l)
		vb.add_child(UI.heading("Landmark %s — «%s»" % [D.HAB_NAME[a].to_lower(), tx[0]], 26))
		vb.add_child(UI.icon_rect(UI.card_tex(key), Vector2(520, 342)))
		vb.add_child(UI.wrap(UI.label(tx[1], 20), 520))
	var b := UI.button("Chiudi", 200, 50)
	b.pressed.connect(_close_overlay)
	vb.add_child(b)


func _show_keystones() -> void:
	var vb := _open_overlay(900)
	vb.add_child(UI.heading("Scegli una chiave di volta in più", 28))
	vb.add_child(UI.label("Andrà nel tuo ambiente prima dell'inizio (poi la posi e la ruoti come le altre).", 19, UI.MUTED))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var tiles: Array = pending["tiles"]
	for i in tiles.size():
		var b := TextureButton.new()
		b.texture_normal = UI.tile_tex(tiles[i])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(140, 162)
		var ii := i
		b.pressed.connect(func(): _provide(ii))
		hb.add_child(b)


func _show_landmarks() -> void:
	var vb := _open_overlay(980)
	vb.add_child(UI.heading("Posa un Landmark", 28))
	vb.add_child(UI.wrap(UI.label("Il Landmark resta su questa tessera (niente animali sopra). Scegli la carta che vuoi: segnerà punti a fine partita.", 19, UI.MUTED), 940))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(grid)
	var opts: Array = pending["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var key := "%s_%s" % [o["h"], o["l"]]
		var col := VBoxContainer.new()
		var b := TextureButton.new()
		b.texture_normal = UI.card_tex(key)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(220, 145)
		var tx := D.lm_card_text(o["h"], o["l"])
		b.tooltip_text = tx[1]
		var ii := i
		b.pressed.connect(func(): _provide(ii))
		col.add_child(b)
		var env: Dictionary = engine.envs[viewer]
		var now := CSScore.landmark(env, key)
		col.add_child(UI.wrap(UI.label("%s — ora %d pt" % [tx[0], now] if not o["l"] in ["I", "J"] else tx[0], 16, UI.WOOD), 220))
		grid.add_child(col)
	var b2 := UI.button("Nessun Landmark", 260, 52)
	b2.pressed.connect(func(): _provide(-1))
	vb.add_child(b2)


func _show_scores(final: bool) -> void:
	var res: Array = engine.results if final else engine.live_scores()
	var n := engine.players.size()
	var vb := _open_overlay(minf(1500.0, 360.0 + 170.0 * n))
	if final:
		var order := range(n)
		order.sort_custom(func(a, b):
			if res[a]["total"] != res[b]["total"]:
				return res[a]["total"] > res[b]["total"]
			return engine.nature[a] > engine.nature[b])
		var w: int = order[0]
		var t := UI.heading("Vince %s con %d punti!" % [engine.pname(w), res[w]["total"]] if n > 1 else "Punteggio finale: %d" % res[0]["total"], 38, UI.PINE)
		vb.add_child(t)
		if n == 1:
			var tot: int = res[0]["total"]
			var lv := "Ascesa!!" if tot >= 110 else ("Élite!" if tot >= 100 else ("Eccellente!" if tot >= 90 else ("Molto bene!" if tot >= 80 else ("Ci stai prendendo la mano!" if tot >= 70 else "Un buon inizio!"))))
			vb.add_child(UI.italic(lv, 24, UI.WOOD))
	else:
		vb.add_child(UI.heading("Punti se la partita finisse adesso", 30))
	var grid := GridContainer.new()
	grid.columns = n + 1
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	grid.add_child(UI.label("", 18))
	for s in n:
		var l := UI.label(engine.pname(s), 20, UI.pcol(s).darkened(0.3), UI.font_bold)
		l.custom_minimum_size.x = 140
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(l)
	var rows := []
	for a in D.ANIMALS:
		rows.append(["%s (%s)" % [D.ANI_PLURAL[a], engine.cards[a]], func(r): return str(r["wild"][a])])
	rows.append(["Fauna", func(r): return str(_sum(r["wild"])), true])
	for h in D.HABITATS:
		rows.append([D.HAB_PLURAL[h], func(r): return "%d%s" % [r["hab"][h], (" +%d" % r["bonus"][h]) if r["bonus"][h] > 0 else ""]])
	rows.append(["Habitat", func(r): return str(_sum(r["hab"]) + _sum(r["bonus"])), true])
	if engine.lm_module:
		rows.append(["Landmark", func(r): return str(_sum(r["lm"])), true])
	rows.append(["Segnalini Natura", func(r): return str(r["nature"])])
	rows.append(["TOTALE", func(r): return str(r["total"]), true])
	for row in rows:
		var bold: bool = row.size() > 2
		grid.add_child(UI.label(row[0], 19, UI.WOOD if bold else UI.INK, UI.font_bold if bold else UI.font_body))
		for s in n:
			var l := UI.label(row[1].call(res[s]), 20 if not bold else 22, UI.PINE if bold else UI.INK, UI.font_bold if bold else UI.font_body)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	if final:
		var again := UI.primary(UI.button("Nuova partita", 280, 56))
		again.pressed.connect(func(): main.show_menu())
		hb.add_child(again)
		var stay := UI.button("Guarda gli ambienti", 280, 56)
		stay.pressed.connect(_close_overlay)
		hb.add_child(stay)
	else:
		var b := UI.button("Chiudi", 200, 52)
		b.pressed.connect(_close_overlay)
		hb.add_child(b)


func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += d[k]
	return t


func _show_rules_popup() -> void:
	var vb := _open_overlay(1100)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = Vector2(1060, 760)
	rt.text = preload("res://scripts/ui/rules_view.gd").RULES
	vb.add_child(rt)
	var b := UI.button("Chiudi", 200, 50)
	b.pressed.connect(_close_overlay)
	vb.add_child(b)


func _confirm_menu() -> void:
	var vb := _open_overlay(620)
	vb.add_child(UI.heading("Tornare al menu?", 30))
	vb.add_child(UI.label("La partita in corso andrà persa.", 20))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var yes := UI.primary(UI.button("Sì, al menu", 240, 54))
	yes.pressed.connect(func():
		engine.abort = true
		if online != null:
			online.alive = false
		if not pending.is_empty():
			pending = {}
			engine.provide_decision(null)
		main.show_menu())
	hb.add_child(yes)
	var no := UI.button("Continua", 200, 54)
	no.pressed.connect(func():
		_close_overlay()
		if not pending.is_empty():
			_show_decision()
			if pending["type"] in ["keystone", "landmark"]:
				_show_decision())
	hb.add_child(no)


# ================================================================ eventi

func _on_log(t: String) -> void:
	if t.begins_with("—"):
		log_text.append_text("\n[b]%s[/b]\n" % t)
	else:
		log_text.append_text(t + "\n")
	if engine.current >= 0 and not engine.players[engine.current]["ai"] and online == null:
		return
	if not t.begins_with("—"):
		status_lbl.text = t.left(90)


func _on_fx(kind: String, data: Dictionary) -> void:
	_mark()


func _on_end(results: Array) -> void:
	pending = {}
	_clear_actions()
	hint_lbl.text = "Partita finita."
	if online != null:
		online.finish()
	if engine.abort:
		return
	viewer = local_seats[0] if not local_seats.is_empty() else 0
	pinned = true
	_refresh()
	map.fit()
	_show_scores(true)


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		status_lbl.text = ""
	else:
		status_lbl.text = "Aspetto %s…%s" % [engine.pname(s), " (lento)" if slow else ""]


func online_status(t: String) -> void:
	status_lbl.text = t


func online_cancel_decision(t: String) -> void:
	pending = {}
	_close_overlay()
	_clear_actions()
	status_lbl.text = t
	_refresh()


func online_caught_up() -> void:
	status_lbl.text = "Partita ripresa."


# ================================================================ controlli disegnati

## Una coppia dell'offerta in due riquadri: la tessera a sinistra, l'animale a destra.
## Clic (senza segnalino Natura) = si prende la coppia: i due riquadri restano evidenziati finché
## tessera e animale non sono posati. Col segnalino Natura si sceglie un riquadro alla volta.
class OfferRow extends Control:
	var view
	var slot := 0
	var _hover := ""
	const GAP := 8.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func():
			_hover = ""
			queue_redraw())

	func tile_rect() -> Rect2:
		var w := minf(size.y * 0.866 + 24.0, (size.x - GAP) * 0.55)
		return Rect2(Vector2.ZERO, Vector2(w, size.y))

	func token_rect() -> Rect2:
		var t := tile_rect()
		return Rect2(Vector2(t.size.x + GAP, 0), Vector2(size.x - t.size.x - GAP, size.y))

	func _part(p: Vector2) -> String:
		return "tile" if p.x < tile_rect().size.x + GAP / 2 else "token"

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := _part(ev.position)
			if h != _hover:
				_hover = h
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			view.offer_click(slot, _part(ev.position))

	func _box(r: Rect2, state: String) -> void:
		# state: "" normale, "hover" possibile scelta, "sel" scelta col segnalino, "held" presa in questo turno
		var bg := Color(UI.CREAM, 0.92)
		var border := Color(UI.WOOD, 0.25)
		var bw := 1
		match state:
			"hover":
				bg = Color("#fff7df")
				border = UI.PINE
				bw = 3
			"sel":
				bg = Color("#fff3cf")
				border = UI.GOLD
				bw = 4
			"held":
				bg = Color("#fde9b0")
				border = UI.GOLD
				bw = 5
		draw_style_box(UI.panel_style(bg, border, bw, 10), r)

	func _draw() -> void:
		var e: CSEngine = view.engine
		var drafting: bool = not view.pending.is_empty() and view.pending["type"] == "draft"
		var tr := tile_rect()
		var wr := token_rect()
		# tessera: quella dell'offerta oppure, se presa in questo turno, quella in mano
		var t: String = e.disp_t[slot]
		var t_state := ""
		var rot := 0
		if t == "" and e.held_t_slot == slot and e.held_tile != "":
			t = e.held_tile
			t_state = "held"
			rot = int(view.ghost.get("rot", 0))
		var a: String = e.disp_w[slot]
		var a_state := ""
		if a == "" and e.held_w_slot == slot and e.held_animal != "":
			a = e.held_animal
			a_state = "held"
		if drafting:
			match view.dmode:
				"":
					if _hover != "":
						t_state = "hover"
						a_state = "hover"
				"free":
					if view.sel_t == slot:
						t_state = "sel"
					elif _hover == "tile":
						t_state = "hover"
					if view.sel_w == slot:
						a_state = "sel"
					elif _hover == "token":
						a_state = "hover"
				"wipe":
					if _hover == "token":
						a_state = "hover"
		_box(tr, t_state)
		_box(wr, a_state)
		if t != "":
			var h := tr.size.y - 14.0
			var w := h * 0.866
			var c := tr.get_center() + Vector2(6, 0)
			draw_set_transform(c, deg_to_rad(60.0 * rot), Vector2.ONE)
			draw_texture_rect(UI.tile_tex(t), Rect2(-w / 2, -h / 2, w, h), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# animali che la tessera può ospitare
			var ws: Array = D.tile_info(t)["w"]
			var dr := clampf(h * 0.055, 5.0, 9.0)
			for k in ws.size():
				draw_circle(Vector2(tr.position.x + dr + 5, tr.position.y + 12 + dr + k * (dr * 2.4)), dr, Color(D.ANI_COLOR[ws[k]]))
		if a != "":
			var c := wr.get_center()
			var rr := minf(wr.size.x, wr.size.y) * 0.38
			draw_circle(c + Vector2(0, 3), rr, Color(0, 0, 0, 0.25))
			draw_texture_rect(UI.token_tex(a), Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2), false)
			if view.dmode == "wipe" and view.wipe_sel.has(slot):
				var x := rr * 0.6
				draw_line(c - Vector2(x, x), c + Vector2(x, x), UI.RED, 8.0)
				draw_line(c + Vector2(-x, x), c + Vector2(x, -x), UI.RED, 8.0)


## Pulsante con una freccia circolare disegnata.
class RotButton extends Button:
	var dir := 1

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.26
		var col := UI.INK if not is_hovered() else UI.PINE
		var a0 := deg_to_rad(-60.0)
		var a1 := deg_to_rad(210.0)
		draw_arc(c, r, a0, a1, 32, col, 3.0, true)
		# punta della freccia all'estremo nel verso della rotazione
		var at := a1 if dir > 0 else a0
		var p := c + Vector2(cos(at), sin(at)) * r
		var tang := Vector2(-sin(at), cos(at)) * (1.0 if dir > 0 else -1.0)
		var norm := Vector2(cos(at), sin(at))
		draw_colored_polygon(PackedVector2Array([p + tang * 9.0, p - tang * 2.0 + norm * 7.0, p - tang * 2.0 - norm * 7.0]), col)


