extends SceneTree

func _initialize() -> void:
	print("HAS_TERRAIN3D=", ClassDB.class_exists("Terrain3D"))
	quit()
