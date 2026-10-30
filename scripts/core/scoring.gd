class_name CSScore
extends RefCounted
## Punteggio di fine partita di Cascadia (carte fauna A-G, corridoi di habitat, segnalini Natura,
## carte Landmark). Tutte funzioni statiche su un «ambiente»:
##   env: Dictionary  Vector2i(q, r) -> {"id": tessera, "rot": 0..5, "a": animale o "", "lm": habitat o ""}

const D = preload("res://scripts/data/cs_data.gd")
const DIRS := D.DIRS

# ------------------------------------------------------------------ tessere

static func info(cell: Dictionary) -> Dictionary:
	return D.tile_info(cell["id"])


## Habitat sul lato `dir` (0 = est, senso orario) della tessera, tenendo conto della rotazione.
static func edge_hab(env: Dictionary, p: Vector2i, dir: int) -> String:
	var c: Dictionary = env[p]
	return info(c)["e"][posmod(dir - int(c["rot"]), 6)]


static func habs_of(env: Dictionary, p: Vector2i) -> Array:
	var out := []
	for h in info(env[p])["e"]:
		if not out.has(h):
			out.append(h)
	return out


static func has_hab(env: Dictionary, p: Vector2i, h: String) -> bool:
	return info(env[p])["e"].has(h)


static func animal(env: Dictionary, p: Vector2i) -> String:
	return str(env[p]["a"]) if env.has(p) else ""


static func cells_with(env: Dictionary, a: String) -> Array:
	var out := []
	for p in env:
		if env[p]["a"] == a:
			out.append(p)
	return out


static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	return d in DIRS


# ------------------------------------------------------------------ corridoi

## Corridoi dell'habitat h: array di array di celle, dal più grande.
static func corridors(env: Dictionary, h: String) -> Array:
	var seen := {}
	var out := []
	for p in env:
		if seen.has(p) or not has_hab(env, p, h):
			continue
		var comp := []
		var stack := [p]
		seen[p] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			for d in 6:
				var n: Vector2i = c + DIRS[d]
				if seen.has(n) or not env.has(n):
					continue
				if edge_hab(env, c, d) == h and edge_hab(env, n, (d + 3) % 6) == h:
					seen[n] = true
					stack.append(n)
		out.append(comp)
	out.sort_custom(func(a, b): return a.size() > b.size())
	return out


## Valore di un habitat per i punteggi (corridore più grande, con le carte Landmark I e J).
static func habitat_value(env: Dictionary, h: String, lm_cards: Array) -> int:
	var cs := corridors(env, h)
	if cs.is_empty():
		return 0
	var v: int = cs[0].size()
	if lm_cards.has(h + "_I") and cs.size() > 1:
		v += cs[1].size()
	if lm_cards.has(h + "_J"):
		v += 2
	return v


# ------------------------------------------------------------------ gruppi e ricerca

static func groups_of(cells: Array) -> Array:
	var set := {}
	for c in cells:
		set[c] = true
	var seen := {}
	var out := []
	for c in cells:
		if seen.has(c):
			continue
		var comp := []
		var stack := [c]
		seen[c] = true
		while not stack.is_empty():
			var x: Vector2i = stack.pop_back()
			comp.append(x)
			for d in DIRS:
				var n: Vector2i = x + d
				if set.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		out.append(comp)
	return out


static func neighbors_in(c: Vector2i, set: Dictionary) -> int:
	var k := 0
	for d in DIRS:
		if set.has(c + d):
			k += 1
	return k


## Animali (celle) adiacenti a un gruppo, esclusi quelli del gruppo.
static func adjacent_animals(env: Dictionary, group: Array) -> Array:
	var gset := {}
	for c in group:
		gset[c] = true
	var seen := {}
	var out := []
	for c in group:
		for d in DIRS:
			var n: Vector2i = c + d
			if gset.has(n) or seen.has(n):
				continue
			seen[n] = true
			if animal(env, n) != "":
				out.append(n)
	return out


## Scelta di gruppi disgiunti di valore massimo. cells: elenco delle celle; cands: [{m: maschera, v: valore}].
## Ogni cella può anche restare fuori. Restituisce [valore, gruppi scelti].
static func best_packing(n: int, cands: Array) -> Array:
	var by_first := []
	for i in n:
		by_first.append([])
	for g in cands:
		var m: int = g["m"]
		for i in n:
			if m & (1 << i):
				by_first[i].append(g)
				break
	var memo := {}
	return _pack(0, n, by_first, memo)


static func _pack(mask: int, n: int, by_first: Array, memo: Dictionary) -> Array:
	var i := 0
	while i < n and (mask & (1 << i)):
		i += 1
	if i >= n:
		return [0, []]
	if memo.has(mask):
		return memo[mask]
	# la cella i resta fuori
	var best := _pack(mask | (1 << i), n, by_first, memo)
	best = [best[0], best[1]]
	for g in by_first[i]:
		var m: int = g["m"]
		if mask & m:
			continue
		var r := _pack(mask | m, n, by_first, memo)
		if r[0] + g["v"] > best[0]:
			best = [r[0] + g["v"], [g] + r[1]]
	memo[mask] = best
	return best


static func _mask(cells: Array, idx: Dictionary) -> int:
	var m := 0
	for c in cells:
		m |= 1 << int(idx[c])
	return m


static func _tbl(t: Array, n: int) -> int:
	if n <= 0:
		return 0
	return t[mini(n, t.size()) - 1]


# ------------------------------------------------------------------ orsi

static func score_bears(env: Dictionary, card: String) -> int:
	var bears := cells_with(env, "orso")
	var gs := groups_of(bears)
	var sizes := []
	for g in gs:
		sizes.append(g.size())
	match card:
		"A":
			return _tbl([4, 11, 19, 27], sizes.count(2))
		"B":
			return 10 * sizes.count(3)
		"C":
			var v := 2 * sizes.count(1) + 5 * sizes.count(2) + 8 * sizes.count(3)
			if sizes.count(1) > 0 and sizes.count(2) > 0 and sizes.count(3) > 0:
				v += 3
			return v
		"D":
			return 5 * sizes.count(2) + 8 * sizes.count(3) + 13 * sizes.count(4)
		"E":
			var v := 0
			for g in gs:
				if g.size() != 1:
					continue
				for d in DIRS:
					if not env.has(g[0] + d):
						v += 3
						break
			return v
		"F":
			var v := 0
			for g in gs:
				if g.size() < 3:
					continue
				var kinds := {}
				for n in adjacent_animals(env, g):
					kinds[animal(env, n)] = true
				if kinds.has("alce") and kinds.has("salmone") and kinds.has("falco") and kinds.has("volpe"):
					v += 12
			return v
		"G":
			var pairs := 0
			for g in gs:
				if g.size() == 2 and (has_hab(env, g[0], "foresta") or has_hab(env, g[1], "foresta")):
					pairs += 1
			return _tbl([5, 12, 20, 29], pairs)
	return 0


# ------------------------------------------------------------------ alci

static func _elk_shapes(elk: Array, set: Dictionary, idx: Dictionary, vals: Array, need_prairie: Callable) -> Array:
	# singoli, coppie, triangoli, rombi
	var cands := []
	var seen := {}
	for a in elk:
		var g1 := [a]
		if need_prairie.call(g1):
			cands.append({"m": _mask(g1, idx), "v": vals[0]})
		for d in 6:
			var b: Vector2i = a + DIRS[d]
			if not set.has(b):
				continue
			var g2 := [a, b]
			var m2 := _mask(g2, idx)
			if not seen.has(m2):
				seen[m2] = true
				if need_prairie.call(g2):
					cands.append({"m": m2, "v": vals[1]})
			# terzo vicino di entrambi: triangolo
			for d2 in [d + 1, d + 5]:
				var c: Vector2i = a + DIRS[d2 % 6]
				if not set.has(c):
					continue
				var g3 := [a, b, c]
				var m3 := _mask(g3, idx)
				if not seen.has(m3):
					seen[m3] = true
					if need_prairie.call(g3):
						cands.append({"m": m3, "v": vals[2]})
				# rombo: quarto alce vicino di b e c, dall'altra parte rispetto ad a
				var e: Vector2i = b + c - a
				if set.has(e):
					var g4 := [a, b, c, e]
					var m4 := _mask(g4, idx)
					if not seen.has(m4):
						seen[m4] = true
						if need_prairie.call(g4):
							cands.append({"m": m4, "v": vals[3]})
	return cands


static func _ring_arcs(elk: Array, set: Dictionary, idx: Dictionary, sizes: Array) -> Array:
	# archi di celle consecutive attorno a un centro qualunque
	var centers := {}
	for a in elk:
		for d in DIRS:
			centers[a + d] = true
	var out := []
	var seen := {}
	for c in centers:
		var ring := []
		for d in 6:
			ring.append(set.has(c + DIRS[d]))
		if ring.count(true) == 0:
			continue
		if ring.count(true) == 6 and sizes.has(6):
			var g := []
			for d in 6:
				g.append(c + DIRS[d])
			var m := _mask(g, idx)
			if not seen.has(m):
				seen[m] = true
				out.append({"m": m, "n": 6})
		for start in 6:
			for ln in range(1, 6):
				if not sizes.has(ln):
					continue
				var ok := true
				var g := []
				for k in ln:
					var dd := (start + k) % 6
					if not ring[dd]:
						ok = false
						break
					g.append(c + DIRS[dd])
				if not ok:
					continue
				var m := _mask(g, idx)
				if not seen.has(m):
					seen[m] = true
					out.append({"m": m, "n": ln})
	return out


static func score_elk(env: Dictionary, card: String) -> int:
	var elk := cells_with(env, "alce")
	if elk.is_empty():
		return 0
	if elk.size() > 40:
		elk.resize(40)
	var set := {}
	var idx := {}
	for i in elk.size():
		set[elk[i]] = true
		idx[elk[i]] = i
	var always := func(_g): return true
	match card:
		"A":
			var cands := []
			var vals := [2, 5, 9, 13]
			for a in elk:
				cands.append({"m": _mask([a], idx), "v": 2})
				for d in 3:
					var line := [a]
					var p: Vector2i = a
					for k in 3:
						p = p + DIRS[d]
						if not set.has(p):
							break
						line.append(p)
						cands.append({"m": _mask(line, idx), "v": vals[line.size() - 1]})
			return best_packing(elk.size(), cands)[0]
		"B":
			return best_packing(elk.size(), _elk_shapes(elk, set, idx, [2, 5, 9, 13], always))[0]
		"C":
			var v := 0
			for g in groups_of(elk):
				v += _tbl([2, 4, 7, 10, 14, 18, 23, 28], g.size())
			return v
		"D":
			var vals := [2, 5, 8, 12, 16, 21]
			var cands := []
			for g in _ring_arcs(elk, set, idx, [1, 2, 3, 4, 5, 6]):
				cands.append({"m": g["m"], "v": vals[g["n"] - 1]})
			return best_packing(elk.size(), cands)[0]
		"E":
			var cands := []
			for g in _ring_arcs(elk, set, idx, [3]):
				cands.append({"m": g["m"], "v": 1})
			var n: int = best_packing(elk.size(), cands)[0]
			return _tbl([10, 21, 33], n)
		"F":
			var cands := []
			for g in _elk_shapes(elk, set, idx, [0, 0, 1, 0], always):
				if g["v"] != 1:
					continue
				var cells := []
				for i in elk.size():
					if g["m"] & (1 << i):
						cells.append(elk[i])
				var v := 13 - adjacent_animals(env, cells).size()
				if v > 0:
					cands.append({"m": g["m"], "v": v})
			return best_packing(elk.size(), cands)[0]
		"G":
			var pr := func(g):
				for c in g:
					if has_hab(env, c, "prateria"):
						return true
				return false
			return best_packing(elk.size(), _elk_shapes(elk, set, idx, [3, 6, 10, 14], pr))[0]
	return 0


# ------------------------------------------------------------------ salmoni

## Corse valide: gruppi in cui ogni salmone ha al più 2 salmoni vicini.
static func salmon_runs(env: Dictionary) -> Array:
	var sal := cells_with(env, "salmone")
	var set := {}
	for c in sal:
		set[c] = true
	var out := []
	for g in groups_of(sal):
		var ok := true
		for c in g:
			if neighbors_in(c, set) > 2:
				ok = false
				break
		if ok:
			out.append(g)
	return out


static func _zigzag(run: Array) -> bool:
	if run.size() <= 2:
		return true
	var set := {}
	for c in run:
		set[c] = true
	var start = null
	for c in run:
		if neighbors_in(c, set) == 1:
			start = c
			break
	if start == null:
		return false   # anello chiuso (triangolo)
	var path := [start]
	var prev = null
	var cur: Vector2i = start
	while path.size() < run.size():
		var nxt = null
		for d in DIRS:
			var n: Vector2i = cur + d
			if set.has(n) and n != prev and not path.has(n):
				nxt = n
				break
		if nxt == null:
			return false
		prev = cur
		cur = nxt
		path.append(cur)
	var dirs := []
	for i in path.size() - 1:
		dirs.append(DIRS.find(path[i + 1] - path[i]))
	for i in dirs.size() - 1:
		var t := posmod(dirs[i + 1] - dirs[i], 6)
		if t != 1 and t != 5:
			return false
		if i + 2 < dirs.size() and dirs[i + 2] != dirs[i]:
			return false
	return true


static func score_salmon(env: Dictionary, card: String) -> int:
	var v := 0
	for r in salmon_runs(env):
		var n: int = r.size()
		match card:
			"A":
				v += _tbl([2, 5, 8, 12, 16, 20, 25], n)
			"B":
				v += _tbl([2, 4, 9, 11, 17], n)
			"C":
				if n >= 3:
					v += _tbl([0, 0, 10, 12, 15], n)
			"D":
				if n >= 3:
					v += n + adjacent_animals(env, r).size()
			"E":
				if _zigzag(r):
					v += _tbl([2, 5, 9, 13, 17, 21], n)
			"F":
				v += _tbl([1, 3, 7, 10, 13, 17, 22], n)
				for c in adjacent_animals(env, r):
					if animal(env, c) == "orso":
						v += 1
			"G":
				v += _tbl([2, 4, 7, 10, 14], n)
				for c in r:
					if has_hab(env, c, "fiume"):
						v += 1
	return v


# ------------------------------------------------------------------ falchi

static func _bounds(env: Dictionary) -> Rect2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := -mn
	for p in env:
		mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
		mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
	return Rect2i(mn - Vector2i(2, 2), mx - mn + Vector2i(5, 5))


## Linee di vista fra falchi non vicini: [[a, b, celle in mezzo], ...] (ogni coppia una volta).
static func hawk_sight(env: Dictionary) -> Array:
	var hawks := cells_with(env, "falco")
	var set := {}
	for h in hawks:
		set[h] = true
	var bb := _bounds(env)
	var out := []
	for a in hawks:
		for d in 3:
			var between := []
			var p: Vector2i = a
			var dist := 0
			while true:
				p = p + DIRS[d]
				dist += 1
				if not bb.has_point(p):
					break
				if set.has(p):
					if dist >= 2:
						out.append([a, p, between])
					break
				between.append(p)
	return out


static func _pair_matching(pairs: Array) -> int:
	# pairs: [[a, b, valore]]; ogni falco in una sola coppia; massimo della somma
	if pairs.is_empty():
		return 0
	var best := 0
	var first: Array = pairs[0]
	var rest := pairs.slice(1)
	# senza la prima coppia
	best = _pair_matching(rest)
	if first[2] > 0:
		var rest2 := []
		for q in rest:
			if q[0] != first[0] and q[0] != first[1] and q[1] != first[0] and q[1] != first[1]:
				rest2.append(q)
		best = maxi(best, first[2] + _pair_matching(rest2))
	return best


static func score_hawks(env: Dictionary, card: String) -> int:
	var hawks := cells_with(env, "falco")
	var set := {}
	for h in hawks:
		set[h] = true
	var lonely := []
	for h in hawks:
		if neighbors_in(h, set) == 0:
			lonely.append(h)
	match card:
		"A":
			return _tbl([2, 5, 8, 11, 14, 18, 22, 26], lonely.size())
		"B":
			var sight := hawk_sight(env)
			var has := {}
			for s in sight:
				has[s[0]] = true
				has[s[1]] = true
			var n := 0
			for h in lonely:
				if has.has(h):
					n += 1
			return 0 if n < 2 else _tbl([5, 9, 12, 16, 20, 24, 28], n - 1)
		"C":
			return 3 * hawk_sight(env).size()
		"D":
			var pairs := []
			for s in hawk_sight(env):
				var kinds := {}
				for c in s[2]:
					var a := animal(env, c)
					if a != "" and a != "falco":
						kinds[a] = true
				pairs.append([s[0], s[1], _tbl([4, 7, 9], kinds.size())])
			return _pair_matching(_limit(pairs))
		"E":
			var sight := hawk_sight(env)
			var cnt := {}
			for s in sight:
				cnt[s[0]] = int(cnt.get(s[0], 0)) + 1
				cnt[s[1]] = int(cnt.get(s[1], 0)) + 1
			var v := 0
			for s in sight:
				if cnt[s[0]] == 1 and cnt[s[1]] == 1:
					v += 7
			return v
		"F":
			var bb := _bounds(env)
			var n := 0
			for h in hawks:
				var ok := false
				for d in 6:
					var p: Vector2i = h
					var dist := 0
					while not ok:
						p = p + DIRS[d]
						dist += 1
						if not bb.has_point(p):
							break
						var a := animal(env, p)
						if a == "falco":
							break
						if a == "volpe":
							if dist >= 2:
								ok = true
							break
					if ok:
						break
				if ok:
					n += 1
			return _tbl([2, 5, 8, 10, 16, 18, 25], n)
		"G":
			var pairs := []
			for s in hawk_sight(env):
				var hs := {}
				for c in s[2]:
					if env.has(c):
						for h in habs_of(env, c):
							hs[h] = true
				pairs.append([s[0], s[1], 1 if hs.size() >= 3 else 0])
			return _tbl([7, 14, 22, 30], _pair_matching(_limit(pairs)))
	return 0


static func _limit(pairs: Array) -> Array:
	# la ricerca è esponenziale: con moltissime coppie si tengono le migliori
	if pairs.size() <= 18:
		return pairs
	var p := pairs.duplicate()
	p.sort_custom(func(a, b): return a[2] > b[2])
	return p.slice(0, 18)


# ------------------------------------------------------------------ volpi

static func _adj_counts(env: Dictionary, c: Vector2i) -> Dictionary:
	var k := {}
	for d in DIRS:
		var a := animal(env, c + d)
		if a != "":
			k[a] = int(k.get(a, 0)) + 1
	return k


static func score_foxes(env: Dictionary, card: String) -> int:
	var foxes := cells_with(env, "volpe")
	var v := 0
	match card:
		"A":
			for f in foxes:
				v += _adj_counts(env, f).size()
		"B":
			for f in foxes:
				var k := _adj_counts(env, f)
				var pairs := 0
				for a in k:
					if a != "volpe" and k[a] >= 2:
						pairs += 1
				v += _tbl([3, 5, 7], pairs)
		"C":
			for f in foxes:
				var k := _adj_counts(env, f)
				var best := 0
				for a in k:
					if a != "volpe":
						best = maxi(best, k[a])
				v += best
		"D":
			var set := {}
			for f in foxes:
				set[f] = true
			var pairs := []
			for f in foxes:
				for d in 3:
					var g: Vector2i = f + DIRS[d]
					if not set.has(g):
						continue
					var k := {}
					for c in adjacent_animals(env, [f, g]):
						var a := animal(env, c)
						if a != "volpe":
							k[a] = int(k.get(a, 0)) + 1
					var n := 0
					for a in k:
						if k[a] >= 2:
							n += 1
					pairs.append([f, g, _tbl([5, 7, 9, 11], n)])
			v = _pair_matching(_limit(pairs))
		"E":
			for f in foxes:
				var n := 0
				for d in DIRS:
					if animal(env, f + d) != "":
						n += 1
				if n == 6:
					v += 4
				elif n >= 4:
					v += 2
		"F":
			for f in foxes:
				if _adj_counts(env, f).size() == 2:
					v += 4
		"G":
			for f in foxes:
				var hs := {}
				for d in 6:
					var n: Vector2i = f + DIRS[d]
					if env.has(n):
						hs[edge_hab(env, n, (d + 3) % 6)] = true
				v += hs.size()
	return v


# ------------------------------------------------------------------ insieme

static func wildlife(env: Dictionary, a: String, card: String) -> int:
	match a:
		"orso":
			return score_bears(env, card)
		"alce":
			return score_elk(env, card)
		"salmone":
			return score_salmon(env, card)
		"falco":
			return score_hawks(env, card)
		"volpe":
			return score_foxes(env, card)
	return 0


## Punti di una carta Landmark ("foresta_E" ...). Le carte I e J agiscono sugli habitat.
static func landmark(env: Dictionary, key: String) -> int:
	var h := key.get_slice("_", 0) if not key.begins_with("zona_umida") else "zona_umida"
	var l := key.substr(key.length() - 1)
	match l:
		"A", "B", "C", "D":
			var kinds: Array = D.LM_ANIMALS[h][3] if l == "D" else [D.LM_ANIMALS[h]["ABC".find(l)]]
			var n := 0
			for p in env:
				if kinds.has(env[p]["a"]) and has_hab(env, p, h):
					n += 1
			return n
		"E":
			var cs := corridors(env, h)
			if cs.is_empty():
				return 0
			var k := {}
			for c in cs[0]:
				if env[c]["a"] != "":
					k[env[c]["a"]] = true
			return k.size()
		"F":
			var n := 0
			for p in env:
				if info(env[p])["k"] and env[p]["a"] != "" and has_hab(env, p, h):
					n += 1
			return 3 * (n / 2)
		"G":
			return corridors(env, h).size()
		"H":
			var n := 0
			for c in corridors(env, h):
				if c.size() >= 2:
					n += 1
			return 2 * n
		"I", "J":
			return 0
		"K":
			return clampi(6 - corridors(env, h).size(), 0, 5)
		"L":
			return 3
	return 0


## Punteggio completo di tutti i giocatori.
## players: [{env, nature, lm_cards: ["foresta_A", ...]}], cards: {animale: lettera}.
## Restituisce per giocatore {wild: {a: p}, hab: {h: p}, bonus: {h: p}, lm: {key: p}, nature, total}.
static func full(players: Array, cards: Dictionary) -> Array:
	var out := []
	var hv := []
	for pl in players:
		var r := {"wild": {}, "hab": {}, "bonus": {}, "lm": {}, "nature": int(pl["nature"]), "total": 0}
		for a in D.ANIMALS:
			r["wild"][a] = wildlife(pl["env"], a, cards[a])
		var hvals := {}
		for h in D.HABITATS:
			hvals[h] = habitat_value(pl["env"], h, pl.get("lm_cards", []))
			r["hab"][h] = hvals[h]
			r["bonus"][h] = 0
		for k in pl.get("lm_cards", []):
			r["lm"][k] = landmark(pl["env"], k)
		hv.append(hvals)
		out.append(r)
	var n := players.size()
	for h in D.HABITATS:
		if n == 1:
			if hv[0][h] >= 7:
				out[0]["bonus"][h] = 2
			continue
		var vals := []
		for i in n:
			vals.append(hv[i][h])
		var top: int = vals.max()
		if top <= 0:
			continue
		var tops := []
		for i in n:
			if vals[i] == top:
				tops.append(i)
		if n == 2:
			for i in tops:
				out[i]["bonus"][h] = 2 if tops.size() == 1 else 1
			continue
		if tops.size() == 1:
			out[tops[0]]["bonus"][h] = 3
			var second := -1
			for i in n:
				if i != tops[0]:
					second = maxi(second, vals[i])
			if second > 0:
				var seconds := []
				for i in n:
					if i != tops[0] and vals[i] == second:
						seconds.append(i)
				if seconds.size() == 1:
					out[seconds[0]]["bonus"][h] = 1
		elif tops.size() == 2:
			for i in tops:
				out[i]["bonus"][h] = 2
		else:
			for i in tops:
				out[i]["bonus"][h] = 1
	for r in out:
		var t: int = r["nature"]
		for a in r["wild"]:
			t += r["wild"][a]
		for h in r["hab"]:
			t += r["hab"][h] + r["bonus"][h]
		for k in r["lm"]:
			t += r["lm"][k]
		r["total"] = t
	return out
