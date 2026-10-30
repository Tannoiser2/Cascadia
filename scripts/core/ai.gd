class_name CSAI
extends RefCounted
## IA di Cascadia. Valuta ogni coppia tessera + animale dell'offerta (e, con i segnalini Natura, le
## combinazioni libere) provando i piazzamenti possibili: per la tessera conta come crescono i corridoi
## (con i premi di maggioranza rispetto agli avversari) e le carte che dipendono dagli habitat; per
## l'animale conta di quanto salgono i punti delle carte fauna. Livelli: 0 facile, 1 normale, 2 difficile.

const D = preload("res://scripts/data/cs_data.gd")
const S = preload("res://scripts/core/scoring.gd")

## Carte fauna che cambiano anche solo posando tessere (habitat o spazi vuoti).
const TILE_SENSITIVE := {"orso": ["E", "G"], "alce": ["G"], "salmone": ["G"], "falco": ["G"], "volpe": ["G"]}

var level := 1
var rng := RandomNumberGenerator.new()
var plan := {}


func _init(lv := 1, seed := 0) -> void:
	level = lv
	rng.seed = seed if seed != 0 else 12345


func decide(eng, s: int, req: Dictionary):
	match str(req["type"]):
		"overpop":
			return _overpop(eng, s, req)
		"draft":
			return _draft(eng, s)
		"keystone":
			return _keystone(eng, s, req)
		"place_tile":
			return _place_tile(eng, s, str(req["tile"]))
		"landmark":
			return _landmark(eng, s, req)
		"place_token":
			return _place_token(eng, s, str(req["animal"]), req["cells"])
	return null


func _noise() -> float:
	return rng.randf_range(-4.0, 4.0) if level == 0 else (rng.randf_range(-0.3, 0.3) if level == 1 else 0.0)


# ------------------------------------------------------------------ valutazioni

func _wild_total(eng, env: Dictionary) -> float:
	var t := 0.0
	for a in D.ANIMALS:
		t += S.wildlife(env, a, eng.cards[a])
	return t


func _tile_sensitive_total(eng, env: Dictionary) -> float:
	var t := 0.0
	for a in D.ANIMALS:
		if TILE_SENSITIVE[a].has(eng.cards[a]):
			t += S.wildlife(env, a, eng.cards[a])
	return t


func _lm_total(eng, s: int, env: Dictionary) -> float:
	var t := 0.0
	for k in eng.lm_cards[s]:
		t += S.landmark(env, k)
	return t


## Valore di un habitat con il premio di maggioranza stimato sui corridoi attuali degli avversari.
func _hab_score(eng, s: int, env: Dictionary, h: String, others: Dictionary) -> float:
	var v := S.habitat_value(env, h, eng.lm_cards[s])
	var n: int = eng.players.size()
	var bonus := 0.0
	if n == 1:
		bonus = 2.0 if v >= 7 else (0.25 * v if v >= 4 else 0.0)
	else:
		var best_o: int = others.get(h, 0)
		if v > best_o:
			bonus = 2.0 if n == 2 else 3.0
		elif v == best_o and v > 0:
			bonus = 1.0 if n == 2 else 2.0
		elif n > 2 and v >= best_o - 1:
			bonus = 0.8
	return v + bonus * (0.6 if level == 0 else 1.0)


func _others_best(eng, s: int) -> Dictionary:
	var out := {}
	for o in eng.players.size():
		if o == s:
			continue
		for h in D.HABITATS:
			out[h] = maxi(int(out.get(h, 0)), S.habitat_value(eng.envs[o], h, eng.lm_cards[o]))
	return out


## Valore «di flessibilità» delle tessere libere: quanti animali utili potranno ancora ospitare.
func _slot_value(eng, env: Dictionary) -> float:
	if level < 2:
		return 0.0
	var t := 0.0
	for p in env:
		var c: Dictionary = env[p]
		if c["a"] == "" and c["lm"] == "":
			t += 0.35 * D.tile_info(c["id"])["w"].size()
	return t


func _hab_total(eng, s: int, env: Dictionary, others: Dictionary, habs: Array) -> float:
	var t := 0.0
	for h in habs:
		t += _hab_score(eng, s, env, h, others)
	return t


# ------------------------------------------------------------------ tessere

func _rotations(t: String) -> Array:
	var e: Array = D.tile_info(t)["e"]
	var seen := {}
	var out := []
	for r in 6:
		var key := ""
		for d in 6:
			key += e[posmod(d - r, 6)].substr(0, 2)
		if not seen.has(key):
			seen[key] = true
			out.append(r)
	return out


## Migliori piazzamenti della tessera t: [[valore, cella, rotazione], ...] dal migliore.
func _tile_options(eng, s: int, t: String, others: Dictionary) -> Array:
	var env: Dictionary = eng.envs[s]
	var habs: Array = []
	for h in D.tile_info(t)["e"]:
		if not habs.has(h):
			habs.append(h)
	var base_h := _hab_total(eng, s, env, others, habs)
	var base_w := _tile_sensitive_total(eng, env)
	var base_l := _lm_total(eng, s, env)
	var out := []
	for q in eng.frontier(s):
		for r in _rotations(t):
			env[q] = {"id": t, "rot": r, "a": "", "lm": ""}
			var v := _hab_total(eng, s, env, others, habs) - base_h
			v += _tile_sensitive_total(eng, env) - base_w
			v += _lm_total(eng, s, env) - base_l
			if level >= 2:
				# tessere compatte: meglio vicine a più tessere (corridoi futuri)
				var nb := 0
				for d in D.DIRS:
					if env.has(q + d):
						nb += 1
				v += 0.15 * nb
			env.erase(q)
			out.append([v + _noise(), q, r])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out


# ------------------------------------------------------------------ animali

## Migliori celle per l'animale a: [[valore, cella], ...]; valore = punti guadagnati.
func _token_options(eng, s: int, a: String, cells: Array) -> Array:
	var env: Dictionary = eng.envs[s]
	var base := _wild_total(eng, env) + _lm_total(eng, s, env) + _slot_value(eng, env)
	var out := []
	for p in cells:
		env[p]["a"] = a
		var v := _wild_total(eng, env) + _lm_total(eng, s, env) + _slot_value(eng, env) - base
		if D.tile_info(env[p]["id"])["k"]:
			v += 1.0 if level < 2 else 1.3
		env[p]["a"] = ""
		out.append([v + _noise(), p])
	out.sort_custom(func(x, y): return x[0] > y[0])
	return out


## Valore complessivo di prendere la tessera t e l'animale a. Restituisce [valore, piano].
func _combo(eng, s: int, t: String, a: String, others: Dictionary, tile_cache: Dictionary, tok_cache: Dictionary) -> Array:
	if not tile_cache.has(t):
		tile_cache[t] = _tile_options(eng, s, t, others)
	var topts: Array = tile_cache[t]
	if topts.is_empty():
		return [-999.0, {}]
	if not tok_cache.has(a):
		tok_cache[a] = _token_options(eng, s, a, eng.token_cells(s, a))
	var wopts: Array = tok_cache[a]
	var best_w: float = wopts[0][0] if not wopts.is_empty() else 0.0
	var best_cell = wopts[0][1] if not wopts.is_empty() else null
	var best := [topts[0][0] + maxf(best_w, 0.0), {"tile": t, "cell": topts[0][1], "rot": topts[0][2],
		"animal": a, "tok": best_cell if best_w > 0.0 or level == 0 else null}]
	# l'animale sulla tessera appena posata (se la tessera lo accoglie)
	if D.tile_info(t)["w"].has(a):
		var env: Dictionary = eng.envs[s]
		for k in mini(3, topts.size()):
			var o: Array = topts[k]
			env[o[1]] = {"id": t, "rot": o[2], "a": "", "lm": ""}
			var w := _token_options(eng, s, a, [o[1]])
			env.erase(o[1])
			var v: float = o[0] + w[0][0]
			if v > best[0]:
				best = [v, {"tile": t, "cell": o[1], "rot": o[2], "animal": a, "tok": o[1]}]
	return best


func _draft(eng, s: int):
	var others := _others_best(eng, s)
	var tc := {}
	var wc := {}
	var best_pair := -1
	var best_v := -1e9
	for i in 4:
		var r := _combo(eng, s, eng.disp_t[i], eng.disp_w[i], others, tc, wc)
		if r[0] > best_v:
			best_v = r[0]
			best_pair = i
			plan = r[1]
	if eng.nature[s] > 0 and level >= 1:
		var thr := 3.5 if level == 1 else 2.0
		# a fine partita i segnalini valgono un punto: si spendono se rendono di più
		var fb := -1e9
		var fp := {}
		var ft := -1
		var fw := -1
		for i in 4:
			for j in 4:
				if i == j:
					continue
				var r := _combo(eng, s, eng.disp_t[i], eng.disp_w[j], others, tc, wc)
				if r[0] > fb:
					fb = r[0]
					fp = r[1]
					ft = i
					fw = j
		if fb - best_v > thr:
			plan = fp
			return {"k": "free", "t": ft, "w": fw}
	return {"k": "pair", "i": best_pair}


func _overpop(eng, s: int, req: Dictionary) -> bool:
	if level == 0:
		return rng.randf() < 0.5
	# si rimescola se l'animale triplicato rende poco
	var a := str(req["animal"])
	var opts := _token_options(eng, s, a, eng.token_cells(s, a))
	var v: float = opts[0][0] if not opts.is_empty() else 0.0
	return v < 2.0


func _keystone(eng, s: int, req: Dictionary) -> int:
	var others := _others_best(eng, s)
	var best := 0
	var bv := -1e9
	var tiles: Array = req["tiles"]
	for i in tiles.size():
		var o := _tile_options(eng, s, tiles[i], others)
		var v: float = o[0][0] if not o.is_empty() else 0.0
		if v > bv:
			bv = v
			best = i
	return best


func _place_tile(eng, s: int, t: String) -> Array:
	if plan.get("tile", "") == t and eng.can_place(s, plan["cell"]):
		var c: Vector2i = plan["cell"]
		return [c.x, c.y, int(plan["rot"])]
	var o := _tile_options(eng, s, t, _others_best(eng, s))
	plan = {}
	return [o[0][1].x, o[0][1].y, o[0][2]]


func _landmark(eng, s: int, req: Dictionary) -> int:
	if level == 0:
		return 0
	var env: Dictionary = eng.envs[s]
	var best := -1
	var bv := 0.5
	var others := _others_best(eng, s)
	for i in req["options"].size():
		var o: Dictionary = req["options"][i]
		var key := "%s_%s" % [o["h"], o["l"]]
		var v := float(S.landmark(env, key))
		if o["l"] == "I" or o["l"] == "J":
			var before := _hab_score(eng, s, env, o["h"], others)
			eng.lm_cards[s].append(key)
			v = _hab_score(eng, s, env, o["h"], others) - before + 1.5
			eng.lm_cards[s].erase(key)
		elif o["l"] in ["A", "B", "C", "D", "E", "F", "G", "H"]:
			v += 2.0  # crescerà nel resto della partita
		if v > bv:
			bv = v
			best = i
	# il Landmark occupa la tessera: se l'animale pianificato doveva andare lì, si cambia piano
	if best >= 0 and plan.get("tok") != null:
		var c: Array = req["cell"]
		if plan["tok"] == Vector2i(int(c[0]), int(c[1])):
			plan["tok"] = null
	return best


func _place_token(eng, s: int, a: String, cells: Array):
	var opts := _token_options(eng, s, a, cells)
	plan = {}
	if opts.is_empty():
		return []
	if opts[0][0] < -0.5 and level >= 1:
		return []   # meglio rimetterlo nel sacchetto
	var p: Vector2i = opts[0][1]
	return [p.x, p.y]
