extends SceneTree
## Verifica delle carte punteggio su ambienti costruiti a mano: godot --headless --path . -s tests/score_test.gd
const D = preload("res://scripts/data/cs_data.gd")
const S = preload("res://scripts/core/scoring.gd")
var KEY := {}
var fails := 0

func _init() -> void:
	for t in D.data()["tiles"]:
		if t["k"] and not KEY.has(t["e"][0]) and t["e"].count(t["e"][0]) == 6:
			KEY[t["e"][0]] = t["id"]
	# --- orsi: due coppie isolate e un singolo
	var env := _env({Vector2i(0,0): "orso", Vector2i(1,0): "orso", Vector2i(4,0): "orso", Vector2i(5,0): "orso", Vector2i(0,3): "orso"})
	_eq(S.score_bears(env, "A"), 11, "orso A due coppie")
	_eq(S.score_bears(env, "C"), 2 + 5 + 5, "orso C")
	_eq(S.score_bears(env, "D"), 10, "orso D")
	# --- alci: linea di 3 e linea di 2 separate
	env = _env({Vector2i(0,0): "alce", Vector2i(1,0): "alce", Vector2i(2,0): "alce", Vector2i(0,3): "alce", Vector2i(1,3): "alce"})
	_eq(S.score_elk(env, "A"), 14, "alce A")
	_eq(S.score_elk(env, "C"), 7 + 4, "alce C")
	# triangolo + singolo
	env = _env({Vector2i(0,0): "alce", Vector2i(1,0): "alce", Vector2i(0,1): "alce", Vector2i(5,5): "alce"})
	_eq(S.score_elk(env, "B"), 9 + 2, "alce B triangolo")
	_eq(S.score_elk(env, "F"), 13 + 0, "alce F triangolo isolato")
	# rombo
	env = _env({Vector2i(0,0): "alce", Vector2i(1,0): "alce", Vector2i(0,1): "alce", Vector2i(1,-1): "alce"})
	_eq(S.score_elk(env, "B"), 13, "alce B rombo")
	# anello completo di 6 attorno a uno spazio
	var ring := {}
	for d in D.DIRS:
		ring[d] = "alce"
	env = _env(ring)
	_eq(S.score_elk(env, "D"), 21, "alce D anello")
	_eq(S.score_elk(env, "E"), 21, "alce E due semicerchi")
	# --- salmoni: corsa di 5 in linea, poi un gruppo non valido (salmone con 3 vicini)
	env = _env({Vector2i(0,0): "salmone", Vector2i(1,0): "salmone", Vector2i(2,0): "salmone", Vector2i(3,0): "salmone", Vector2i(4,0): "salmone"})
	_eq(S.score_salmon(env, "A"), 16, "salmone A corsa 5")
	_eq(S.score_salmon(env, "C"), 15, "salmone C")
	_eq(S.score_salmon(env, "E"), 0, "salmone E linea non è zig-zag")
	env = _env({Vector2i(0,0): "salmone", Vector2i(1,0): "salmone", Vector2i(-1,0): "salmone", Vector2i(0,1): "salmone"})
	_eq(S.score_salmon(env, "A"), 0, "salmone A gruppo non valido")
	env = _env({Vector2i(0,0): "salmone", Vector2i(0,1): "salmone", Vector2i(1,1): "salmone", Vector2i(1,2): "salmone"})
	_eq(S.score_salmon(env, "E"), 13, "salmone E zig-zag 4")
	# --- falchi: tre isolati, due in linea di vista
	env = _env({Vector2i(0,0): "falco", Vector2i(3,0): "falco", Vector2i(0,4): "falco"})
	_eq(S.score_hawks(env, "A"), 8, "falco A")
	_eq(S.score_hawks(env, "C"), 3 * 2, "falco C due linee")
	_eq(S.score_hawks(env, "B"), 9, "falco B 3 falchi")
	env = _env({Vector2i(0,0): "falco", Vector2i(3,0): "falco", Vector2i(1,0): "orso", Vector2i(2,0): "volpe"})
	_eq(S.score_hawks(env, "D"), 7, "falco D due animali in mezzo")
	_eq(S.score_hawks(env, "E"), 7, "falco E")
	_eq(S.score_hawks(env, "F"), 1 * 0 + 2, "falco F (vede la volpe a distanza 2)")
	# --- volpi
	env = _env({Vector2i(0,0): "volpe", Vector2i(1,0): "orso", Vector2i(0,1): "orso", Vector2i(-1,1): "salmone", Vector2i(-1,0): "salmone", Vector2i(0,-1): "falco"})
	_eq(S.score_foxes(env, "A"), 3, "volpe A")
	_eq(S.score_foxes(env, "B"), 5, "volpe B")
	_eq(S.score_foxes(env, "C"), 2, "volpe C")
	_eq(S.score_foxes(env, "E"), 2, "volpe E (5 vicini)")
	# --- corridoi: tessere chiave di volta della stessa foresta in fila
	env = _env({Vector2i(0,0): "", Vector2i(1,0): "", Vector2i(2,0): ""}, "foresta")
	_eq(S.habitat_value(env, "foresta", []), 3, "corridoio foresta 3")
	_eq(S.habitat_value(env, "foresta", ["foresta_J"]), 5, "foresta + J")
	_eq(S.landmark(env, "foresta_G"), 1, "landmark G")
	_eq(S.landmark(env, "foresta_K"), 5, "landmark K")
	# premi di maggioranza a 3 giocatori
	var e1 := _env({Vector2i(0,0): "", Vector2i(1,0): "", Vector2i(2,0): ""}, "foresta")
	var e2 := _env({Vector2i(0,0): "", Vector2i(1,0): ""}, "foresta")
	var e3 := _env({Vector2i(0,0): ""}, "foresta")
	var cards := {"orso": "A", "alce": "A", "salmone": "A", "falco": "A", "volpe": "A"}
	var res := S.full([{"env": e1, "nature": 2}, {"env": e2, "nature": 0}, {"env": e3, "nature": 0}], cards)
	_eq(res[0]["bonus"]["foresta"], 3, "maggioranza primo")
	_eq(res[1]["bonus"]["foresta"], 1, "maggioranza secondo")
	_eq(res[0]["total"], 3 + 3 + 2, "totale")
	print("FALLITI: %d" % fails if fails else "TUTTO OK")
	quit(1 if fails else 0)

func _env(animals: Dictionary, hab := "prateria") -> Dictionary:
	var env := {}
	for p in animals:
		env[p] = {"id": KEY[hab], "rot": 0, "a": animals[p], "lm": ""}
	return env

func _eq(a, b, what: String) -> void:
	if a != b:
		fails += 1
		print("ERRATO %s: %s invece di %s" % [what, a, b])
