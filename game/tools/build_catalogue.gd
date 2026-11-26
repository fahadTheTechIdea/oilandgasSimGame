extends SceneTree
## One-off tool: serialise the default catalogue into editable data assets.
##
##   Godot --headless --path game --script res://tools/build_catalogue.gd
##
## Produces res://data/catalogue.tres and res://data/buildings/<id>.tres. Re-run
## after changing BuildingCatalogueFactory; the .tres files are plain text and
## can then be tuned in the Inspector without touching code.

func _initialize() -> void:
	var catalogue := BuildingCatalogueFactory.build()
	var dir := "res://data/buildings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for entry in catalogue.entries:
		var path := "%s/%s.tres" % [dir, entry.id]
		var err := ResourceSaver.save(entry, path)
		print("saved ", path, " err=", err)
	var cat_err := ResourceSaver.save(catalogue, "res://data/catalogue.tres")
	print("saved res://data/catalogue.tres err=", cat_err, " entries=", catalogue.entries.size())
	quit()
