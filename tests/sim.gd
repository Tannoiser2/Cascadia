extends SceneTree
## Partite IA contro IA: godot --headless --path . -s tests/sim.gd -- <partite> <giocatori> [livello] [lm 0/1] [carte]
const E = preload("res://scripts/core/engine.gd")
const AI = preload("res://scripts/core/ai.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 3
	var np := int(args[1]) if args.size() > 1 else 2
	var lv := int(args[2]) if args.size() > 2 else 1
	var lm := args.size() > 3 and args[3] == "1"
	var pool := args[4] if args.size() > 4 else "ABCD"
	var tot := {}
	var t0 := Time.get_ticks_msec()
	for g in games:
		var e := E.new()
		e.headless = true
		root.add_child(e)
		var seats := []
		for i in np:
			seats.append({"name": "IA%d" % (i + 1), "ai": true, "level": lv if i > 0 else maxi(lv, 1)})
		e.setup({"seats": seats, "seed": 1000 + g, "lm_module": lm, "card_pool": pool})
		for i in np:
			e.ais[i] = AI.new(seats[i]["level"], 77 + i + g)
		await e.run()
		var line := "partita %d (%s): " % [g, " ".join(e.cards.values())]
		for r in e.results:
			line += "%d [fauna %s hab %s+%s lm %s nat %d]  " % [r["total"], _sum(r["wild"]), _sum(r["hab"]), _sum(r["bonus"]), _sum(r["lm"]), r["nature"]]
			tot[r["seat"]] = int(tot.get(r["seat"], 0)) + r["total"]
		print(line)
		for s in np:
			assert(e.turns_done[s] == 20, "turni %d" % e.turns_done[s])
			assert(e.envs[s].size() == 23 + (1 if lm else 0), "tessere %d" % e.envs[s].size())
		e.queue_free()
	print("medie: ", tot.values().map(func(v): return v / float(games)), "  tempo/partita: %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0 / games))
	quit()

func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += d[k]
	return t
