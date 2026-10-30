extends SceneTree
## Screenshot automatici dell'interfaccia (serve un display: xvfb-run).
## xvfb-run godot --path . -s res://tests/shot.gd -- <modo> [turni]
## modo: menu | rules | gioco (1 persona + IA) ; CS_3D=1 per la vista 3D, CS_LM=1 per i Landmark.
## Le decisioni della persona le prende l'IA, con uno screenshot alla prima richiesta di ogni tipo.

var main
var n := 0
var seen := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func shot(name: String) -> void:
	for i in 4:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(OS.get_user_data_dir() + "/shots/%02d_%s.png" % [n, name])
	print("shot ", name)


func wait(f := 10) -> void:
	for i in range(f):
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "gioco"
	var turns := int(args[1]) if args.size() > 1 else 6
	await wait(8)
	if mode == "menu":
		await shot("menu")
		main.current._online_panel()
		await wait(4)
		await shot("online")
		quit()
		return
	if mode == "rules":
		main.show_rules()
		await wait(5)
		await shot("regole")
		quit()
		return
	var np := int(OS.get_environment("CS_NP")) if OS.get_environment("CS_NP") != "" else 3
	var seats := []
	for i in np:
		seats.append({"name": ["Stefano", "Marta", "Luca", "Anna", "Piero", "Gaia"][i], "ai": i > 0, "level": 1})
	main.start_game({"seats": seats, "ai_delay": 0.0, "view3d": OS.get_environment("CS_3D") == "1",
		"lm_module": OS.get_environment("CS_LM") == "1", "card_pool": "ABCDEFG", "seed": 7})
	await wait(10)
	var view = main.current
	var ai := CSAI.new(2, 3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await process_frame
		var e: CSEngine = view.engine
		if e.game_over:
			await wait(20)
			await shot("fine")
			break
		if view.pending.is_empty():
			continue
		var req: Dictionary = view.pending
		var k := str(req["type"])
		var key := k + ("_late" if e.turn_no >= turns else "")
		if not seen.has(key):
			seen[key] = true
			if k == "place_tile":
				# fantasma su una cella valida
				var plan = ai.decide(e, req["seat"], req)
				view._on_cell(Vector2i(plan[0], plan[1]))
				await wait(4)
			await shot(key)
		if k == "draft" and e.nature[req["seat"]] > 0 and not seen.has("ui_free"):
			# prova dei pulsanti: scelta libera con un segnalino Natura
			seen["ui_free"] = true
			var before: int = e.nature[req["seat"]]
			view._set_dmode("free")
			view.offer_click(0, "tile")
			view.offer_click(2, "token")
			await wait(3)
			await shot("ui_free")
			view.act_box.get_child(0).pressed.emit()
			await wait(3)
			print("UITEST libera: natura ", before, " -> ", e.nature[req["seat"]], " presa ", e.held_tile, " ", e.held_animal)
			continue
		if k == "draft" and e.nature[req["seat"]] > 0 and seen.has("ui_free") and not seen.has("ui_wipe"):
			seen["ui_wipe"] = true
			var w0: Array = e.disp_w.duplicate()
			view._set_dmode("wipe")
			view.offer_click(1, "token")
			view.offer_click(3, "token")
			await wait(3)
			await shot("ui_wipe")
			view.act_box.get_child(0).pressed.emit()
			await wait(3)
			print("UITEST rimescola: ", w0, " -> ", e.disp_w, " pending ", view.pending.get("type", ""))
			continue
		if k == "overpop" and not seen.has("ui_overpop"):
			seen["ui_overpop"] = true
			view.act_box.get_child(0).pressed.emit()
			print("UITEST sovrappopolazione rimescolata: ", e.disp_w)
			continue
		var r = ai.decide(e, req["seat"], req)
		view._provide(r)
	quit()
