extends SceneTree
## Animali in movimento: fotogrammi a intervalli (xvfb-run godot --path . -s res://tests/vivo.gd)
const D = preload("res://scripts/data/cs_data.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var b = load("res://scripts/ui/board3d.gd").new()
	b.size = Vector2(1200, 800)
	root.add_child(b)
	var key := {}
	for t in D.data()["tiles"]:
		if t["k"] and t["e"].count(t["e"][0]) == 6 and not key.has(t["e"][0]):
			key[t["e"][0]] = t["id"]
	var env := {}
	var an := ["orso", "alce", "salmone", "falco", "volpe"]
	var hb := ["foresta", "prateria", "fiume", "montagna", "zona_umida"]
	for i in 5:
		env[Vector2i(i - 2, 0)] = {"id": key[hb[i]], "rot": 0, "a": an[i], "lm": ""}
	b.set_env(env, false)
	b.pitch = 30.0
	b._update_cam()
	var dir := OS.get_user_data_dir() + "/shots"
	DirAccess.make_dir_recursive_absolute(dir)
	b.target = Vector3(0, 0.3, 0)
	b.dist = 5.5
	b._update_cam()
	for k in 12:
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(dir + "/vivo_%d.png" % k)
	b.set_animated(false)
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(dir + "/vivo_fermi.png")
	print("ok")
	quit()
