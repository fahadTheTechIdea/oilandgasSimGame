extends SceneTree

## Probe Terrain3D's region anchoring and asset API without rendering.

func _initialize() -> void:
	print("HAS_TERRAIN3D=", ClassDB.class_exists("Terrain3D"))
	print("HAS_ASSETS=", ClassDB.class_exists("Terrain3DAssets"))
	print("HAS_TEXTURE_ASSET=", ClassDB.class_exists("Terrain3DTextureAsset"))

	var t = ClassDB.instantiate("Terrain3D")
	t.name = "Probe"
	t.region_size = 64
	t.vertex_spacing = 1.0
	get_root().add_child(t)

	# vertical ramp: value 0 at x=0, 1 at x=63 so anchoring is obvious
	var img := Image.create_empty(64, 64, false, Image.FORMAT_R8)
	for z in 64:
		for x in 64:
			img.set_pixel(x, z, Color(float(x) / 63.0, 0, 0, 1))
	t.data.import_images([img], Vector3(0, 0, 0), 0.0, 100.0)

	print("regions=", t.data.region_locations)
	for p in [Vector3(0, 0, 0), Vector3(10, 0, 10), Vector3(-10, 0, -10),
			Vector3(31, 0, 31), Vector3(-31, 0, -31), Vector3(40, 0, 40), Vector3(-40, 0, -40)]:
		print(p, " -> h=", t.data.get_height(p), " region=", t.data.get_region_location(p))

	var assets = ClassDB.instantiate("Terrain3DAssets")
	var tex = ClassDB.instantiate("Terrain3DTextureAsset")
	tex.name = "Grass"
	tex.id = 0
	tex.uv_scale = 0.25
	print("assets ok=", assets != null, " tex ok=", tex != null, " tex.has albedo=", "albedo_texture" in tex)
	assets.set_texture_asset(0, tex)
	print("texture_count=", assets.get_texture_count())
	t.assets = assets
	print("terrain.assets=", t.assets, " show_texture_albedo=", t.show_texture_albedo)
	quit()
