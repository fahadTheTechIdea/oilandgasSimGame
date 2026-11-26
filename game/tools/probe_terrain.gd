extends SceneTree

func _init() -> void:
	var t := OilTerrainGen.generate(1337, 352, 2.0)
	var pts := [
		Vector2(0, 0), Vector2(40, 0), Vector2(80, 0), Vector2(120, 0),
		Vector2(-40, 0), Vector2(-80, 0), Vector2(-120, 0),
		Vector2(0, 40), Vector2(0, 80), Vector2(0, 120),
		Vector2(0, -40), Vector2(0, -80), Vector2(0, -120),
		Vector2(200, 0), Vector2(0, 250),
	]
	var lo := 1.0e9
	var hi := -1.0e9
	for h in t.heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	print("height range: %.2f .. %.2f" % [lo, hi])
	for p in pts:
		print(p, " -> %.2f" % t.height_at(p.x, p.y))
	quit()
