class_name CSEngine
extends Node
## Motore delle regole di Cascadia (con l'espansione Landmarks), senza dipendenze dalla UI.
## Ogni scelta passa da `decide()`: l'IA risponde subito; per le persone viene emesso
## `decision_requested` e si attende `provide_decision()`. Online le scelte viaggiano nel registro di
## mosse (OnlineSession): con lo stesso seme ogni dispositivo gioca la stessa partita.
##
## Tipi di richiesta (req["type"]):
##  - "overpop": tre animali uguali nell'offerta, si possono rimescolare. Risposta: true / false
##  - "draft": scelta nell'offerta. Risposta: {"k": "pair", "i": slot}
##             oppure (spendendo un segnalino Natura) {"k": "free", "t": slot tessera, "w": slot animale}
##             oppure {"k": "wipe", "s": [slot degli animali da rimescolare]}
##  - "keystone": (Landmarks, preparazione) scelta fra le tessere chiave di volta scoperte. Risposta: indice
##  - "place_tile": piazzamento della tessera req["tile"]. Risposta: [q, r, rotazione 0-5]
##  - "landmark": si può mettere un Landmark sulla tessera appena posata. req["options"] = [{h, l}].
##                Risposta: indice dell'opzione, -1 per rinunciare
##  - "place_token": piazzamento dell'animale req["animal"] in req["cells"]. Risposta: [q, r] oppure [] (nel sacchetto)

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(results: Array)
signal fx(kind: String, data: Dictionary)

const D = preload("res://scripts/data/cs_data.gd")
const S = preload("res://scripts/core/scoring.gd")
const TURNS := 20

var rng := RandomNumberGenerator.new()
var ai_delay := 0.0
var headless := false
var ais := {}
var online = null
var abort := false

# ---- configurazione
var players: Array = []          # {name, ai, level, color}
var cards: Dictionary = {}       # animale -> lettera
var lm_tiles := true             # tessere dell'espansione Landmarks
var lm_module := false           # segnalini e carte Landmark

# ---- stato
var envs: Array = []             # per giocatore: Vector2i -> {id, rot, a, lm}
var nature: Array = []
var lm_cards: Array = []         # per giocatore: ["foresta_E", ...]
var lm_offer: Dictionary = {}    # habitat -> lettere ancora disponibili
var deck: Array = []
var disp_t: Array = ["", "", "", ""]
var disp_w: Array = ["", "", "", ""]
var bag: Array = []
var turns_done: Array = []
var current := -1
var turn_no := 0
var phase := ""
var held_tile := ""              # tessera presa, in attesa di piazzamento
var held_animal := ""
var held_t_slot := -1            # da quale riquadro dell'offerta vengono (per la UI)
var held_w_slot := -1
var last_cell = null             # ultima tessera posata (per la UI)
var game_over := false
var results: Array = []
var log_lines: Array = []


# ================================================================ preparazione

func setup(config: Dictionary) -> void:
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	ai_delay = float(config.get("ai_delay", 0.0))
	lm_tiles = bool(config.get("lm_tiles", true))
	lm_module = bool(config.get("lm_module", false))
	players = []
	var seats: Array = config["seats"]
	if seats.size() > 4:
		lm_tiles = true
	for i in seats.size():
		var s: Dictionary = seats[i]
		players.append({"name": str(s.get("name", "")), "ai": bool(s.get("ai", false)), "level": int(s.get("level", 1)),
			"color": D.PLAYER_COLORS[i]})
	# carte fauna: lettera fissa oppure "?" a caso fra le ammesse
	var pool: String = str(config.get("card_pool", "ABCD"))
	var chosen: Dictionary = config.get("cards", {})
	cards = {}
	for a in D.ANIMALS:
		var l := str(chosen.get(a, "?"))
		if l == "?" or l == "":
			l = pool[rng.randi() % pool.length()]
		cards[a] = l
	_build()


func _build() -> void:
	var n := players.size()
	var td: Dictionary = D.data()
	# tessere: 20 per giocatore + 3 (in solitario come in due)
	var all := []
	for t in td["tiles"]:
		if lm_tiles or not t["x"]:
			all.append(t["id"])
	_shuffle(all)
	var need: int = 20 * maxi(n, 2) + 3
	var keystones := []
	if lm_module:
		# una tessera chiave di volta in più per giocatore, scelta durante la preparazione
		var i := 0
		while keystones.size() < n and i < all.size():
			if D.tile_info(all[i])["k"]:
				keystones.append(all[i])
				all.remove_at(i)
			else:
				i += 1
	deck = all.slice(0, mini(need, all.size()))
	# animali: 20 per tipo, 27 con le tessere Landmarks
	bag = []
	for a in D.ANIMALS:
		for k in (27 if lm_tiles else 20):
			bag.append(a)
	_shuffle(bag)
	envs = []
	nature = []
	lm_cards = []
	turns_done = []
	var starts: Array = range(td["starts"].size())
	_shuffle(starts)
	for i in n:
		var env := {}
		var st: Array = td["starts"][starts[i]]
		var pos := [Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)]
		for j in 3:
			env[pos[j]] = {"id": st[j]["id"], "rot": 0, "a": "", "lm": ""}
		envs.append(env)
		nature.append(0)
		lm_cards.append([])
		turns_done.append(0)
	lm_offer = {}
	if lm_module:
		for h in D.HABITATS:
			var ls: Array = D.LM_LETTERS.duplicate()
			_shuffle(ls)
			lm_offer[h] = ls.slice(0, 2 if n == 1 else n)
	_pending_keystones = keystones
	for k in 4:
		disp_t[k] = deck.pop_back()
		disp_w[k] = bag.pop_back()


var _pending_keystones: Array = []


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func pname(s: int) -> String:
	return str(players[s]["name"])


func card_key(a: String) -> String:
	return "%s_%s" % [a, cards[a]]


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	changed.emit()
	if abort:
		return ais[seat].decide(self, seat, req)
	if online != null:
		var r0 = await online.decide(self, seat, req)
		return r0
	if players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		return ais[seat].decide(self, seat, req)
	decision_requested.emit(req)
	var r = await decision_provided
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


# ================================================================ svolgimento

func run() -> void:
	var n := players.size()
	log_msg("Carte fauna: " + ", ".join(D.ANIMALS.map(func(a): return "%s %s" % [D.ANI_NAME[a], cards[a]])) + ".")
	if not _pending_keystones.is_empty():
		await _setup_keystones()
	while not game_over and not abort:
		for s in n:
			if game_over or abort:
				break
			await _turn(s)
	if abort:
		return
	_finish()


## Landmarks: ogni giocatore, in ordine inverso, sceglie una tessera chiave di volta in più.
func _setup_keystones() -> void:
	var ks: Array = _pending_keystones
	_pending_keystones = []
	for s in range(players.size() - 1, -1, -1):
		phase = "keystone"
		var i := 0
		if ks.size() > 1:
			var r = await decide(s, {"type": "keystone", "tiles": ks.duplicate()})
			i = clampi(int(r) if (r is int or r is float) else 0, 0, ks.size() - 1)
		var t: String = ks[i]
		ks.remove_at(i)
		held_tile = t
		await _place_tile(s, t, false)
		held_tile = ""
	changed.emit()


func _turn(s: int) -> void:
	current = s
	turn_no = turns_done[s] + 1
	held_tile = ""
	held_animal = ""
	held_t_slot = -1
	held_w_slot = -1
	phase = "draft"
	log_msg("— Turno %d di %s —" % [turn_no, pname(s)])
	_auto_overpop()
	changed.emit()
	# tre animali uguali: si possono rimescolare (una volta per turno)
	var tri := _triple()
	if tri != "":
		var r = await decide(s, {"type": "overpop", "animal": tri})
		if r == true:
			var slots := []
			for k in 4:
				if disp_w[k] == tri:
					slots.append(k)
			_wipe(slots)
			log_msg("%s rimescola i tre %s." % [pname(s), D.ANI_PLURAL[tri].to_lower()])
			_auto_overpop()
			changed.emit()
	# scelta (eventualmente spendendo segnalini Natura)
	var take_t := -1
	var take_w := -1
	var guard := 0
	while take_t < 0:
		guard += 1
		var r = await decide(s, {"type": "draft"})
		var ch: Dictionary = r if r is Dictionary else {"k": "pair", "i": 0}
		var k := str(ch.get("k", "pair"))
		if k == "wipe" and nature[s] > 0 and guard < 30:
			var slots := []
			for x in ch.get("s", []):
				var xi := int(x)
				if xi >= 0 and xi < 4 and not slots.has(xi):
					slots.append(xi)
			if slots.is_empty():
				continue
			nature[s] -= 1
			_wipe(slots)
			log_msg("%s spende un segnalino Natura e rimescola %d animal%s." % [pname(s), slots.size(), "e" if slots.size() == 1 else "i"])
			_auto_overpop()
			changed.emit()
		elif k == "free" and nature[s] > 0:
			nature[s] -= 1
			take_t = clampi(int(ch.get("t", 0)), 0, 3)
			take_w = clampi(int(ch.get("w", 0)), 0, 3)
			log_msg("%s spende un segnalino Natura per scegliere tessera e animale separati." % pname(s))
		else:
			take_t = clampi(int(ch.get("i", 0)), 0, 3)
			take_w = take_t
	held_tile = disp_t[take_t]
	held_animal = disp_w[take_w]
	held_t_slot = take_t
	held_w_slot = take_w
	disp_t[take_t] = ""
	disp_w[take_w] = ""
	log_msg("%s prende una tessera e %s." % [pname(s), _art(held_animal)])
	changed.emit()
	# piazzamento della tessera (ed eventuale Landmark)
	phase = "place_tile"
	await _place_tile(s, held_tile, true)
	held_tile = ""
	# piazzamento dell'animale
	phase = "place_token"
	var cells := token_cells(s, held_animal)
	if cells.is_empty():
		log_msg("Nessuna tessera libera accoglie %s: torna nel sacchetto." % _art(held_animal))
		bag.append(held_animal)
	else:
		var r = await decide(s, {"type": "place_token", "animal": held_animal, "cells": cells})
		var p = null
		if r is Array and r.size() == 2:
			p = Vector2i(int(r[0]), int(r[1]))
		if p != null and cells.has(p):
			envs[s][p]["a"] = held_animal
			last_cell = p
			var msg := "%s mette %s nel suo ambiente" % [pname(s), _art(held_animal)]
			if D.tile_info(envs[s][p]["id"])["k"]:
				nature[s] += 1
				msg += " su una chiave di volta e guadagna un segnalino Natura"
			log_msg(msg + ".")
			fx.emit("token", {"seat": s, "cell": p, "animal": held_animal})
		else:
			log_msg("%s rimette %s nel sacchetto." % [pname(s), _art(held_animal)])
			bag.append(held_animal)
	held_animal = ""
	held_t_slot = -1
	held_w_slot = -1
	turns_done[s] += 1
	_refill(take_t, take_w)
	changed.emit()


func _art(a: String) -> String:
	match a:
		"orso":
			return "un orso"
		"alce":
			return "un alce"
		"salmone":
			return "un salmone"
		"falco":
			return "un falco"
		"volpe":
			return "una volpe"
	return a


func _place_tile(s: int, t: String, allow_lm: bool) -> void:
	var env: Dictionary = envs[s]
	var r = await decide(s, {"type": "place_tile", "tile": t})
	var q := Vector2i.ZERO
	var rot := 0
	var ok := false
	if r is Array and r.size() >= 2:
		q = Vector2i(int(r[0]), int(r[1]))
		rot = posmod(int(r[2]) if r.size() > 2 else 0, 6)
		ok = can_place(s, q)
	if not ok:
		var fr := frontier(s)
		q = fr[0]
		rot = 0
	env[q] = {"id": t, "rot": rot, "a": "", "lm": ""}
	last_cell = q
	fx.emit("tile", {"seat": s, "cell": q})
	changed.emit()
	if allow_lm and lm_module:
		var opts := landmark_options(s, q)
		if not opts.is_empty():
			var c = await decide(s, {"type": "landmark", "options": opts, "cell": [q.x, q.y]})
			var ci := int(c) if (c is int or c is float) else -1
			if ci >= 0 and ci < opts.size():
				var o: Dictionary = opts[ci]
				env[q]["lm"] = o["h"]
				lm_cards[s].append("%s_%s" % [o["h"], o["l"]])
				lm_offer[o["h"]].erase(o["l"])
				var tx := D.lm_card_text(o["h"], o["l"])
				log_msg("%s posa il Landmark di %s e prende la carta «%s»." % [pname(s), D.HAB_NAME[o["h"]].to_lower(), tx[0]])
				fx.emit("landmark", {"seat": s, "cell": q, "h": o["h"]})
				changed.emit()


func _refill(take_t: int, take_w: int) -> void:
	var n := players.size()
	if n == 1:
		# solitario: si scarta la coppia più lontana dal mazzo, le altre scorrono e si pescano due nuove
		var rest_t := []
		var rest_w := []
		for k in 4:
			if disp_t[k] != "":
				rest_t.append(disp_t[k])
			if disp_w[k] != "":
				rest_w.append(disp_w[k])
		rest_t.pop_back()
		var dropped: String = rest_w.pop_back()
		if dropped != "":
			pass  # l'animale scartato esce dal gioco
		if deck.size() < 2:
			game_over = true
			return
		disp_t = [deck.pop_back(), deck.pop_back(), rest_t[0], rest_t[1]]
		disp_w = [_draw(), _draw(), rest_w[0], rest_w[1]]
		return
	if deck.is_empty():
		game_over = true
		return
	disp_t[take_t] = deck.pop_back()
	disp_w[take_w] = _draw()


func _draw() -> String:
	if bag.is_empty():
		return D.ANIMALS[rng.randi() % 5]
	return bag.pop_back()


func _triple() -> String:
	var k := {}
	for a in disp_w:
		k[a] = int(k.get(a, 0)) + 1
	for a in k:
		if k[a] == 3:
			return a
	return ""


func _auto_overpop() -> void:
	var guard := 0
	while disp_w[0] == disp_w[1] and disp_w[1] == disp_w[2] and disp_w[2] == disp_w[3] and guard < 20:
		guard += 1
		log_msg("Sovrappopolazione: quattro %s! Si rimescolano." % D.ANI_PLURAL[disp_w[0]].to_lower())
		_wipe([0, 1, 2, 3])


func _wipe(slots: Array) -> void:
	var aside := []
	for k in slots:
		aside.append(disp_w[k])
		disp_w[k] = _draw()
	for a in aside:
		bag.append(a)
	_shuffle(bag)


func _finish() -> void:
	game_over = true
	phase = "over"
	var pls := []
	for s in players.size():
		pls.append({"env": envs[s], "nature": nature[s], "lm_cards": lm_cards[s]})
	results = S.full(pls, cards)
	for s in players.size():
		results[s]["seat"] = s
	var order := range(players.size())
	order.sort_custom(func(a, b):
		if results[a]["total"] != results[b]["total"]:
			return results[a]["total"] > results[b]["total"]
		return nature[a] > nature[b])
	var parts := []
	for s in order:
		parts.append("%s %d" % [pname(s), results[s]["total"]])
	log_msg("Fine della partita: " + ", ".join(parts) + ".")
	changed.emit()
	game_ended.emit(results)


# ================================================================ regole di piazzamento

func frontier(s: int) -> Array:
	var env: Dictionary = envs[s]
	var seen := {}
	var out := []
	for p in env:
		for d in D.DIRS:
			var n: Vector2i = p + d
			if not env.has(n) and not seen.has(n):
				seen[n] = true
				out.append(n)
	out.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func can_place(s: int, q: Vector2i) -> bool:
	var env: Dictionary = envs[s]
	if env.has(q):
		return false
	for d in D.DIRS:
		if env.has(q + d):
			return true
	return false


func token_cells(s: int, a: String) -> Array:
	var out := []
	var env: Dictionary = envs[s]
	for p in env:
		var c: Dictionary = env[p]
		if c["a"] == "" and c["lm"] == "" and D.tile_info(c["id"])["w"].has(a):
			out.append(p)
	out.sort_custom(func(x, y): return x.y < y.y or (x.y == y.y and x.x < y.x))
	return out


## Landmark possibili sulla tessera appena posata in q (corridoio di 5+ tessere che la comprende).
func landmark_options(s: int, q: Vector2i) -> Array:
	var env: Dictionary = envs[s]
	var have := {}
	for k in lm_cards[s]:
		have[k.substr(0, k.length() - 2)] = true
	var out := []
	for h in S.habs_of(env, q):
		if have.has(h) or lm_offer.get(h, []).is_empty():
			continue
		for c in S.corridors(env, h):
			if c.has(q):
				if c.size() >= 5:
					for l in lm_offer[h]:
						out.append({"h": h, "l": l})
				break
	return out


## Punteggio provvisorio (per la UI e l'IA).
func live_scores() -> Array:
	var pls := []
	for s in players.size():
		pls.append({"env": envs[s], "nature": nature[s], "lm_cards": lm_cards[s]})
	return S.full(pls, cards)


## Impronta della partita (per verificare che online tutti i dispositivi abbiano giocato la stessa).
func fingerprint() -> String:
	var parts := []
	for s in players.size():
		var keys: Array = envs[s].keys()
		keys.sort()
		for c in keys:
			var e: Dictionary = envs[s][c]
			parts.append("%d:%s%s%d%s%s" % [s, c, e["id"], e["rot"], e["a"], e["lm"]])
		parts.append("n%d" % nature[s])
	var tot := []
	for r in results:
		tot.append(str(r["total"]))
	return str(hash("|".join(parts))) + " punti " + ",".join(tot)
