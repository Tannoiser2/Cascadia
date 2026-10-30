extends SceneTree
## Vista 3D di prova: le cinque chiavi di volta e alcune tessere doppie, con animali e un Landmark.
## xvfb-run godot --path . -s res://tests/tiles3d.gd
const D = preload("res://scripts/data/cs_data.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var b = load("res://scripts/ui/board3d.gd").new()
	b.size = Vector2(1600, 1000)
	root.add_child(b)
	var key := {}
	var dual := []
	for t in D.data()["tiles"]:
		if t["k"] and t["e"].count(t["e"][0]) == 6 and not key.has(t["e"][0]):
			key[t["e"][0]] = t["id"]
		elif not t["k"] and dual.size() < 4:
			dual.append(t["id"])
	var env := {}
	var i := 0
	for h in D.HABITATS:
		env[Vector2i(i, 0)] = {"id": key[h], "rot": 0, "a": "", "lm": ""}
		i += 1
	var animals := ["orso", "alce", "salmone", "falco"]
	for k in dual.size():
		env[Vector2i(k, 1)] = {"id": dual[k], "rot": k, "a": animals[k], "lm": ""}
	env[Vector2i(4, 1)] = {"id": dual[0], "rot": 0, "a": "", "lm": "fiume"}
	b.targets = [Vector2i(0, 0), Vector2i(4, 0)]
	b.target_kind = "token"
	b.ghost = {"cell": Vector2i(1, 2), "id": dual[1], "rot": 2}
	b.set_env(env, false)
	for f in 30:
		await process_frame
	var dir := OS.get_user_data_dir() + "/shots"
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/3d_a.png")
	b.pitch = 85.0
	b._update_cam()
	for f in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir + "/3d_top.png")
	print("ok")
	quit()
