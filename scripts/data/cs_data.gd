extends RefCounted
## Dati di Cascadia: habitat, fauna, carte punteggio e tessere (data/tiles.json, ricavato dal modulo TTS).

const HABITATS := ["foresta", "montagna", "prateria", "zona_umida", "fiume"]
const ANIMALS := ["orso", "alce", "salmone", "falco", "volpe"]

const HAB_NAME := {"foresta": "Foresta", "montagna": "Montagna", "prateria": "Prateria", "zona_umida": "Zona umida", "fiume": "Fiume"}
const HAB_PLURAL := {"foresta": "Foreste", "montagna": "Montagne", "prateria": "Praterie", "zona_umida": "Zone umide", "fiume": "Fiumi"}
const HAB_COLOR := {"foresta": "#2f7d3a", "montagna": "#8d949c", "prateria": "#f2c531", "zona_umida": "#9cc93f", "fiume": "#2a9fd8"}
const ANI_NAME := {"orso": "Orso", "alce": "Alce", "salmone": "Salmone", "falco": "Falco", "volpe": "Volpe"}
const ANI_PLURAL := {"orso": "Orsi", "alce": "Alci", "salmone": "Salmoni", "falco": "Falchi", "volpe": "Volpi"}
const ANI_FULL := {"orso": "Orso grizzly", "alce": "Alce di Roosevelt", "salmone": "Salmone reale", "falco": "Poiana coda rossa", "volpe": "Volpe rossa"}
const ANI_COLOR := {"orso": "#5a3a25", "alce": "#b39b67", "salmone": "#e0356b", "falco": "#7cc4ea", "volpe": "#ec7a1f"}

## Colori dei giocatori (fino a 6).
const PLAYER_COLORS := ["#c8553d", "#3d7cc8", "#e2b33a", "#5aa05a", "#9b6bc8", "#e07fa8"]
const PLAYER_COLOR_NAMES := ["Rosso", "Blu", "Giallo", "Verde", "Viola", "Rosa"]

## Direzioni esagonali (punta in alto, coordinate assiali q,r): lato 0 = est, poi in senso orario.
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]

## Carte punteggio della fauna: titolo italiano e testo breve (A-D base, E-G Landmarks).
const WILD_CARDS := {
	"orso": {
		"A": ["Coppie", "Per numero di coppie di orsi isolate (nessun altro orso accanto): 1: 4, 2: 11, 3: 19, 4+: 27."],
		"B": ["Mamma e cuccioli", "10 punti per ogni gruppo di esattamente 3 orsi, senza altri orsi accanto."],
		"C": ["Famiglie", "Gruppi di 1, 2 o 3 orsi: 2, 5, 8 punti. +3 se hai tutte e tre le misure."],
		"D": ["Grandi gruppi", "Gruppi di 2, 3 o 4 orsi: 5, 8, 13 punti."],
		"E": ["Ai margini", "3 punti per ogni orso solitario con almeno uno spazio vuoto (senza tessera) accanto."],
		"F": ["Signori della natura", "12 punti per ogni gruppo di 3+ orsi che tocca tutti gli altri 4 animali."],
		"G": ["Bosco fitto", "Coppie di orsi con almeno un orso su una tessera con foresta: 1: 5, 2: 12, 3: 20, 4+: 29."],
	},
	"alce": {
		"A": ["Linee", "Per ogni linea retta di alci (ogni alce in una sola linea): 1: 2, 2: 5, 3: 9, 4: 13."],
		"B": ["Formazioni", "Forme esatte: 1 alce 2, 2 alci 5, triangolo 9, rombo 13 (ogni alce in un solo gruppo)."],
		"C": ["Branchi", "Per ogni gruppo di alci di qualunque forma: 1: 2, 2: 4, 3: 7, 4: 10, 5: 14, 6: 18, 7: 23, 8+: 28."],
		"D": ["Cerchi", "Gruppi disposti ad anello attorno a uno spazio: 1: 2, 2: 5, 3: 8, 4: 12, 5: 16, 6: 21."],
		"E": ["Mezzi cerchi", "Gruppi di 3 alci a semicerchio: 1 gruppo 10, 2 gruppi 21, 3+ gruppi 33."],
		"F": ["Branchi solitari", "13 punti per ogni triangolo di 3 alci, −1 per ogni animale accanto al gruppo."],
		"G": ["Formazioni in prateria", "Forme di B con almeno un alce su una tessera con prateria: 3, 6, 10, 14."],
	},
	"salmone": {
		"A": ["Risalita lunga", "Per ogni corsa (salmoni in fila, nessuno con più di 2 vicini): 1: 2 … 7+: 25."],
		"B": ["Risalita breve", "Per ogni corsa: 1: 2, 2: 4, 3: 9, 4: 11, 5+: 17."],
		"C": ["Famiglie", "Corse di 3, 4 o 5+ salmoni: 10, 12, 15 punti."],
		"D": ["Circondati", "Corse di 3+: 1 punto per salmone e 1 per ogni animale accanto alla corsa."],
		"E": ["Zig-zag", "Corse a zig-zag: 1: 2, 2: 5, 3: 9, 4: 13, 5: 17, 6+: 21."],
		"F": ["Catena alimentare", "Per ogni corsa: 1: 1 … 7+: 22, +1 per ogni orso accanto alla corsa."],
		"G": ["Rapide", "Per ogni corsa: 1: 2, 2: 4, 3: 7, 4: 10, 5+: 14, +1 per ogni salmone su un fiume."],
	},
	"falco": {
		"A": ["Solitari", "Falchi senza altri falchi accanto: 1: 2 … 8+: 26."],
		"B": ["Collegati", "Falchi isolati che vedono in linea retta un altro falco: 2: 5 … 8: 28."],
		"C": ["Rete", "3 punti per ogni linea di vista diretta fra due falchi non vicini."],
		"D": ["Territori", "Coppie di falchi in vista: animali diversi fra loro 1: 4, 2: 7, 3+: 9 (ogni falco una volta)."],
		"E": ["Solo occhi per te", "7 punti per ogni coppia di falchi non vicini che vedono soltanto l'un l'altro."],
		"F": ["Amici predatori", "Falchi che vedono una volpe non vicina: 1: 2, 2: 5, 3: 8, 4: 10, 5: 16, 6: 18, 7+: 25."],
		"G": ["Dall'alto", "Coppie di falchi in vista con almeno 3 habitat diversi in mezzo: 1: 7, 2: 14, 3: 22, 4+: 30."],
	},
	"volpe": {
		"A": ["Animali vicini", "Per ogni volpe, 1 punto per ogni tipo di animale diverso accanto (volpi comprese)."],
		"B": ["Coppie vicine", "Per ogni volpe, coppie di animali uguali accanto (non volpi): 1: 3, 2: 5, 3: 7."],
		"C": ["Parenti vicini", "Per ogni volpe, quanti animali del tipo più numeroso accanto (non volpi): 1-6 punti."],
		"D": ["Coppie dinamiche", "Per ogni coppia di volpi, coppie di animali uguali accanto: 1: 5, 2: 7, 3: 9, 4: 11."],
		"E": ["In mezzo", "Volpe circondata da 6 animali: 4 punti; da 4 o 5: 2 punti."],
		"F": ["Vicini esclusivi", "4 punti per ogni volpe accanto a esattamente due tipi di animali (volpi comprese)."],
		"G": ["Terre diverse", "Per ogni volpe, 1 punto per ogni habitat diverso sui lati delle tessere vicine che la toccano."],
	},
}

## Carte Landmark (una serie per habitat, lettere A-L).
const LM_ANIMALS := {
	"foresta": ["orso", "alce", "volpe", ["falco", "salmone"]],
	"prateria": ["alce", "volpe", "salmone", ["falco", "orso"]],
	"zona_umida": ["volpe", "salmone", "falco", ["orso", "alce"]],
	"fiume": ["salmone", "falco", "orso", ["alce", "volpe"]],
	"montagna": ["falco", "orso", "alce", ["volpe", "salmone"]],
}
const LM_LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]


static func lm_card_text(h: String, l: String) -> Array:
	var hn: String = HAB_NAME[h].to_lower()
	match l:
		"A", "B", "C":
			var a: String = LM_ANIMALS[h]["ABC".find(l)]
			return ["%s su %s" % [ANI_NAME[a], hn], "1 punto per ogni %s su una tessera con %s." % [ANI_NAME[a].to_lower(), hn]]
		"D":
			var p: Array = LM_ANIMALS[h][3]
			return ["%s e %s" % [ANI_NAME[p[0]], ANI_NAME[p[1]].to_lower()], "1 punto per ogni %s e ogni %s su una tessera con %s." % [ANI_NAME[p[0]].to_lower(), ANI_NAME[p[1]].to_lower(), hn]]
		"E":
			return ["Fauna varia", "1 punto per ogni animale diverso sul corridoio di %s più grande." % hn]
		"F":
			return ["Chiavi di volta abitate", "3 punti per ogni coppia di tessere chiave di volta con %s occupate da un animale." % hn]
		"G":
			return ["Corridoi", "1 punto per ogni corridoio di %s." % hn]
		"H":
			return ["Grandi corridoi", "2 punti per ogni corridoio di %s di almeno 2 tessere." % hn]
		"I":
			return ["Due corridoi", "I due corridoi di %s più grandi si sommano nel punteggio degli habitat." % hn]
		"J":
			return ["Corridoio più grande", "Aggiunge 2 alla misura del corridoio di %s più grande." % hn]
		"K":
			return ["Pochi corridoi", "6 punti meno 1 per ogni corridoio di %s." % hn]
		_:
			return [HAB_NAME[h], "3 punti."]


static var _tiles := {}


static func data() -> Dictionary:
	if _tiles.is_empty():
		var f := FileAccess.open("res://data/tiles.json", FileAccess.READ)
		_tiles = JSON.parse_string(f.get_as_text())
	return _tiles


static func tile_info(id: String) -> Dictionary:
	var d := data()
	if not d.has("_index"):
		var idx := {}
		for t in d["tiles"]:
			idx[t["id"]] = t
		for s in d["starts"]:
			for t in s:
				idx[t["id"]] = t
		d["_index"] = idx
	return d["_index"][id]


static func tile_texture_path(id: String) -> String:
	if id.begins_with("S"):
		return "res://assets/start/%s.webp" % id
	return "res://assets/tiles/%s.webp" % id
