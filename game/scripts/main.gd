extends Node3D
## Oilfield Tycoon prototype.
## Flow: exploration reveals deposits -> pumpjack on a deposit -> pipe -> storage
## tank -> pipe -> refinery -> refined product is sold automatically.

const CELL := 16.0
const GRID := 44
const MAP_SIZE := GRID * CELL
const HALF := MAP_SIZE * 0.5

const START_CASH := 300000.0
const DEFAULT_PLAYERS := 3   # ready-made flat, prepared HQ plots at start
const BASE_SLOTS := [Vector2i(0, 0), Vector2i(7, 4), Vector2i(-7, 4),
	Vector2i(0, -7), Vector2i(7, -7), Vector2i(-7, -7)]
const SAVE_PATH := "user://oilfield_save.json"
const DEFAULT_HINT := "UNIT: click it to select · LEFT-click moves · RIGHT-click sends it to do its job · Esc deselects\nBUILD: click a structure or press its hotkey  ·  R rotate  ·  X bulldoze (drag)  ·  H help  ·  Tab networks  ·  C camera\nWASD pan · wheel zoom · Q/E rotate (3D mode) · F6 transfer fleet · F5 save · F9 load · Space pause"
const PIPE_HINT := "PIPE: drag from a green port strip to a tank/refinery  ·  joints snap to ports  ·  Esc cancels\nTab networks · F5 save · F9 load · Space pause"
const ROAD_HINT := "ROAD: drag to link 2+ sites  ·  green cells touch a site or a served street  ·  Esc cancels\nTab networks · F5 save · F9 load · Space pause"

# terrain-aware construction
const MAX_BUILD_RELIEF := 5.0  # m of unevenness a site can be levelled from
const MAX_GRADE := 3.5         # m of rise allowed between adjacent pipe/road cells
const MAX_INFRA_RELIEF := 2.0  # m of unevenness under a single pipe/road tile
const LEVEL_RATE := 9.0        # $ per m3 of cut/fill
const BUILDING_FIT := 0.98     # structure footprint vs cell: small apron, overlaps pipe arms
const PIPE_AXIS_Y := 1.15      # pipe centreline height above the pad
const PORT_JOINT := 0.45       # how far a pipe connector reaches into the structure
const CELL_CORNERS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]

var DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var catalogue: BuildingCatalogue
var _hotkeys: Dictionary = {}
var _screenshot_mode := false

# Structure data lives in res://data/catalogue.tres (BuildingCatalogue resources).

# Pipeline port sides are declared per structure in the catalogue (PortSpec).

const TILE_MODEL_IDS := [
	"gam_deposit",
	"gam_pipe_straight", "gam_pipe_corner", "gam_pipe_tee", "gam_pipe_cross", "gam_pipe_end",
	"gam_road_straight", "gam_road_corner", "gam_road_tee", "gam_road_cross",
]

const PROP_IDS := [
	"tree_pineTallA_detailed", "tree_default", "tree_oak", "tree_small", "tree_fat",
	"rock_largeA", "rock_largeC", "rock_smallA", "plant_bushDetailed", "grass_large",
	"stump_old", "log",
]

# --------------------------------------------------------------------------- #
# state
# --------------------------------------------------------------------------- #

var cash: float = START_CASH
var debt: float = 0.0
var fleet: Dictionary = {}
var fleet_units: Array[Dictionary] = []
var fleet_nodes: Array[Node3D] = []
var selected_unit := -1
var pending_action := ""
var _right_press_pos := Vector2.ZERO
var _float_texts: Array = []
var prepared: Dictionary = {}
var player_count: int = DEFAULT_PLAYERS
var base_origins: Array[Vector2i] = []
var pending_builds: Dictionary = {}
var pending_cells: Dictionary = {}
var prep_visuals: Dictionary = {}
var unit_ring: MeshInstance3D
var target_ring: MeshInstance3D
var unit_label: Label3D
var selection_beam: MeshInstance3D
var price: float = 74.0
var time: float = 0.0
var calendar: GameCalendar
var weather: WeatherSystem
var wind: WindSystem
var cloud_deck: MeshInstance3D
var cloud_shadow: MeshInstance3D
var snow_cover: MeshInstance3D
var rain_splash: CPUParticles3D
var wind_fx: CPUParticles3D
var weather_layer: CanvasLayer
var weather_rain: WeatherFX
var weather_snow: WeatherFX
var sway_props: Array[Node3D] = []
var sun_light: DirectionalLight3D
var sun_cloud_noise: FastNoiseLite
var sun_cloud_ramp: Gradient
var _cloud_shadow_t := 0.0
var _cloud_shade := -1.0
var world_env: Environment
var sky_mat_ref: ShaderMaterial
var rain_fx: CPUParticles3D
var snow_fx: CPUParticles3D
var _last_calendar_day := -1
var contract: Dictionary = {}
var contract_timer := 30.0
var speed: float = 1.0
var paused: bool = false
var income_rate: float = 0.0
var _income_accum: float = 0.0
var _income_timer: float = 0.0

var tool: String = ""
var bulldoze: bool = false
var build_rot: int = 0

var deposits: Dictionary = {}        # Vector2i -> {amount, revealed, node}
var occupied: Dictionary = {}        # Vector2i -> building dictionary
var pipes: Dictionary = {}           # Vector2i -> Node3D
var roads: Dictionary = {}           # Vector2i -> Node3D
var buildings: Array = []            # array of building dictionaries
var comp_members: Dictionary = {}    # comp id -> {wells, storages, refineries}
var pipe_comp: Dictionary = {}       # pipe cell -> component id
var comp_capacity: Dictionary = {}   # component root -> bbl/s throughput
var comp_min_cap: Dictionary = {}    # component root -> weakest-cell base capacity
var comp_boost: Dictionary = {}      # component root -> pump/compressor head
var comp_cells: Dictionary = {}      # component root -> pipe cell count
var comp_bottleneck: Dictionary = {} # component root -> weakest cell
var comp_load: Dictionary = {}       # component root -> actual crude bbl/s
var comp_util: Dictionary = {}       # component root -> load / capacity
var comp_full: Dictionary = {}       # component root -> storage full (backpressure)
var comp_relief: Dictionary = {}     # component root -> max-min terrain height (m)
var comp_pressure: Dictionary = {}   # component root -> head pressure ratio (0..1)
var comp_gas: Dictionary = {}        # component root -> associated gas units/s
var comp_gas_state: Dictionary = {}  # component root -> "sold" / "flared" / "vented"
var pipe_grade: Dictionary = {}      # pipe cell -> grade (0 std, 1 trunk, 2 HP)
var pipe_grade_choice := 0           # grade used by the pipe tool
var comp_income: Dictionary = {}     # component root -> smoothed $/s (dashboard)
var comp_income_tick: Dictionary = {} # component root -> $ this measurement window
var road_comp: Dictionary = {}       # road cell -> road network id
var road_served: Dictionary = {}     # road network id -> serves at least two sites
var road_capacity: Dictionary = {}   # road network id -> logistics capacity
var road_load: Dictionary = {}       # road network id -> logistics load
var road_isolated_cells := 0         # road cells in networks that serve < 2 sites

var hover_cell := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)
var _bulldoze_last := Vector2i(-1, -1)
var _mm_timer := 0.0
var won := false
var failed := false
var dragging := false
var last_drag := Vector2i(-1, -1)
var drag_start := Vector2i(-1, -1)
var drag_preview: MeshInstance3D
var drag_mesh: ImmediateMesh
var drag_mat: StandardMaterial3D
var hl_preview: MeshInstance3D
var hl_mesh: ImmediateMesh
var hl_mat: StandardMaterial3D
var warn_preview: MeshInstance3D
var warn_mesh: ImmediateMesh
var warn_mat: StandardMaterial3D
var net_preview: MeshInstance3D
var net_mesh: ImmediateMesh
var net_mat: StandardMaterial3D
var show_network := false
var _hl_key := ""

var camera
var hud
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var port_preview: MeshInstance3D
var port_mesh: ImmediateMesh
var port_mat: StandardMaterial3D

var world_root: Node3D
var buildings_root: Node3D
var pipes_root: Node3D
var roads_root: Node3D
var markers_root: Node3D

var MODEL_SCENES: Dictionary = {}
var PROP_SCENES: Array = []
var PROP_SCENE_IDS: Array[String] = []
var road_mat: StandardMaterial3D
var pipe_mat: StandardMaterial3D
var _pipe_grade_mats: Dictionary = {}
var apron_mat: StandardMaterial3D
var _toon_cache: Dictionary = {}


# --------------------------------------------------------------------------- #
# boot
# --------------------------------------------------------------------------- #

func _ready() -> void:
	randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--players="):
			player_count = clampi(int(a.substr(10)), 1, 6)
	catalogue = load("res://data/catalogue.tres")
	if catalogue == null:
		push_warning("catalogue.tres missing — building from factory")
		catalogue = BuildingCatalogueFactory.build()
	_build_hotkeys()
	_load_models()
	_build_world()
	_build_camera()
	# real time at 1×: one real second is one game second (24 h game day)
	calendar = GameCalendar.new(86400.0)
	weather = WeatherSystem.new(1337)
	weather.initialize(calendar.season(), calendar.daylight())
	wind = WindSystem.new(4242)
	var cli := OS.get_cmdline_user_args()
	for i in cli.size():
		var a := cli[i]
		if a.begins_with("--weather="):
			if not weather.set_by_name(a.trim_prefix("--weather=")):
				push_warning("Unknown --weather value: " + a)
		elif a == "--weather" and i + 1 < cli.size():
			if not weather.set_by_name(cli[i + 1]):
				push_warning("Unknown --weather value: " + cli[i + 1])
	_build_weather_fx()
	_apply_daylight()
	_update_weather_visuals()
	_generate_deposits()
	_decorate()
	_build_hud()
	_build_ghost()
	_build_port_hint()
	_build_drag_preview()
	_build_run_highlight()
	_build_road_warnings()
	_build_network_overlay()
	_build_unit_markers()
	hud.toast("Place an Exploration Office (4), or drill a known deposit (1)", Color(0.7, 0.9, 0.6))
	hud.set_hint(DEFAULT_HINT)
	_place_starting_base()

	var args := OS.get_cmdline_user_args()
	if args.has("--shot"):
		_screenshot_mode = true
		camera.input_enabled = false
	if args.has("--3d"):
		camera.set_orbit()
	if args.has("--demo"):
		_run_demo()
	if args.has("--showcase"):
		_run_showcase()
	if args.has("--playtest"):
		_run_playtest()
	if args.has("--prepseq"):
		_run_prepseq()
	if args.has("--markers"):
		_run_markers()
	if args.has("--buildshot"):
		_run_buildshot()
	if args.has("--baseshot"):
		_run_baseshot()
	if args.has("--selftest"):
		_selftest()
	if args.has("--overview"):
		_overview()
	if args.has("--shot"):
		_auto_shot()


func _overview() -> void:
	await get_tree().create_timer(0.5).timeout
	camera.set_orbit()
	camera.target = Vector3(0, 8, 40)
	camera.dist = 520.0
	camera.pitch = deg_to_rad(-58.0)
	camera.yaw = deg_to_rad(35.0)


func _auto_shot() -> void:
	await get_tree().create_timer(7.0).timeout
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shot.png")
	img.save_png(path)
	print("SHOT SAVED: ", path)
	get_tree().quit()


## Base-only opening: this is the actual start of the colony loop.
func _run_demo() -> void:
	await get_tree().create_timer(0.4).timeout
	cash = 300000.0
	paused = false
	hud.hide_start_overlay()
	var base := _find_base()
	if not base.is_empty():
		camera.target = cell_to_world(base.origin)
		if not OS.get_cmdline_user_args().has("--3d"):
			camera.set_classic()
			camera.ortho_size = 190.0
			camera.size = 190.0
		else:
			# near-horizon 3D view so the sky (and its clouds) is in frame
			camera.dist = 320.0
			camera.pitch = deg_to_rad(-10.0)
			camera.yaw = deg_to_rad(35.0)
	hud.toast("Field Base online — launch a Seismic Vehicle in FLEET", Color(0.7, 0.9, 0.6))
	# optional: stage agent units + a bulldozer mid-prep. Only freeze for a
	# screenshot; an interactive demo must keep running so the dozer visibly works.
	if OS.get_cmdline_user_args().has("--units"):
		paused = OS.get_cmdline_user_args().has("--shot")
		_buy_unit("seismic")
		_buy_unit("bulldozer")
		var bcell := Vector2i(GRID / 2, GRID / 2)
		if not _find_base().is_empty():
			bcell = _find_base().origin
		var target := _find_free_area(bcell + Vector2i(6, 0), 2)
		for i in fleet_units.size():
			if String(fleet_units[i].kind) == "bulldozer":
				_select_unit(i)
				if target.x >= 0:
					_execute_unit_action(target, "prepare")
					for k in 120:
						_update_units(0.1)
						_animate_units(0.1)
						if String(fleet_units[i].get("state", "")) == "working":
							break
					for k in 32:
						_update_units(0.1)
						_animate_units(0.1)
				break
		if target.x >= 0:
			# tight view on the working pad: blade, dust and changed ground
			var pad_centre := cell_to_world(target) + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
			camera.target = pad_centre
			if OS.get_cmdline_user_args().has("--3d"):
				camera.dist = 74.0
				camera.pitch = deg_to_rad(-47.0)
				camera.yaw = deg_to_rad(20.0)
			else:
				camera.set_classic()
				camera.ortho_size = 80.0
				camera.size = 80.0
			_show_unit_hint()


## Close-up of the Field Base, for asset review and docs.
func _run_baseshot() -> void:
	await get_tree().create_timer(0.4).timeout
	cash = 300000.0
	paused = true
	_screenshot_mode = true
	camera.input_enabled = false
	hud.hide_start_overlay()
	var base := _find_base()
	if not base.is_empty():
		var centre := cell_to_world(base.origin) + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
		camera.set_orbit()
		camera.target = centre + Vector3(0, 4.0, 0)
		camera.dist = 52.0
		camera.pitch = deg_to_rad(-38.0)
		camera.yaw = deg_to_rad(35.0)


## Capture a frame sequence of the bulldozer preparing a site, for docs.
func _run_prepseq() -> void:
	await get_tree().create_timer(0.35).timeout
	cash = 300000.0
	paused = true
	_screenshot_mode = true
	camera.input_enabled = false
	hud.hide_start_overlay()
	_buy_unit("bulldozer")
	var bcell := Vector2i(GRID / 2, GRID / 2)
	if not _find_base().is_empty():
		bcell = _find_base().origin
	var target := _find_free_area(bcell + Vector2i(6, 0), 2)
	if target.x < 0:
		get_tree().quit()
		return
	_select_unit(fleet_units.size() - 1)
	_execute_unit_action(target, "prepare")
	var pad_centre := cell_to_world(target) + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	camera.set_orbit()
	camera.target = pad_centre
	camera.dist = 80.0
	camera.pitch = deg_to_rad(-50.0)
	camera.yaw = deg_to_rad(20.0)
	var ui := fleet_units.size() - 1
	for i in 240:
		_update_units(0.07)
		_animate_units(0.07)
		if String(fleet_units[ui].get("state", "")) == "working":
			break
	var fracs := [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.84, 1.0]
	var shot := 0
	for f in fracs:
		for i in 500:
			var u: Dictionary = fleet_units[ui]
			var need := _unit_need(String(u.get("job", "")), String(u.get("state", "idle")))
			var p := float(u.get("progress", 0.0)) / need
			if p >= float(f) or String(u.get("state", "")) != "working":
				break
			_update_units(0.05)
			_animate_units(0.05)
		_animate_units(0.001)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://seq_%02d.png" % shot))
		shot += 1
		await get_tree().process_frame
	print("PREPSEQ SAVED %d frames" % shot)
	get_tree().quit()


## Stage a revealed deposit + selected seismic vehicle, for the marker docs.
func _run_markers() -> void:
	await get_tree().create_timer(0.35).timeout
	cash = 300000.0
	hud.hide_start_overlay()
	var bcell := Vector2i(GRID / 2, GRID / 2)
	if not _find_base().is_empty():
		bcell = _find_base().origin
	var best := Vector2i(-1, -1)
	var bd := 1.0e9
	for c in deposits.keys():
		var dd := (c as Vector2i).distance_to(bcell)
		if dd < bd:
			bd = dd
			best = c
	if best.x < 0:
		get_tree().quit()
		return
	_reveal(best)
	_buy_unit("seismic")
	var u := _selected_unit_dict()
	if not u.is_empty():
		var node: Node3D = u.get("node")
		var spot := _find_free_area(best + Vector2i(4, 0), 1)
		if node != null and is_instance_valid(node) and spot.x >= 0:
			node.position = cell_to_world(spot) + Vector3(0.0, 0.05, 0.0)
			u.cell = spot
	camera.set_orbit()
	camera.target = cell_to_world(best)
	camera.dist = 115.0
	camera.pitch = deg_to_rad(-52.0)
	camera.yaw = deg_to_rad(20.0)
	paused = OS.get_cmdline_user_args().has("--shot")


## Stage a Mobile Crane building a structure, for docs.
func _run_buildshot() -> void:
	await get_tree().create_timer(0.35).timeout
	cash = 300000.0
	hud.hide_start_overlay()
	_buy_unit("crane")
	var bcell := Vector2i(GRID / 2, GRID / 2)
	if not _find_base().is_empty():
		bcell = _find_base().origin
	var spot := _find_build_area(bcell + Vector2i(7, 2), 2)
	if spot.x < 0:
		get_tree().quit()
		return
	_request_build("storage", spot)
	_assign_crane_to_site(selected_unit, spot)
	for i in 240:
		_update_units(0.1)
		_animate_units(0.1)
		if String(_selected_unit_dict().get("state", "")) == "building":
			break
	for i in 45:
		_update_units(0.1)
		_animate_units(0.1)
	camera.set_orbit()
	camera.target = cell_to_world(spot) + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	camera.dist = 62.0
	camera.pitch = deg_to_rad(-46.0)
	camera.yaw = deg_to_rad(20.0)
	paused = OS.get_cmdline_user_args().has("--shot")


## Staged full field used by the screenshot documentation (was `--demo`).
func _run_showcase() -> void:
	await get_tree().create_timer(0.4).timeout
	_clear_world()
	_generate_deposits()
	var centre0 := Vector2i(GRID / 2, GRID / 2)
	var reveal_best := Vector2i(-1, -1)
	var reveal_dist := 1.0e9
	for c in deposits.keys():
		var d0 := (c as Vector2i).distance_to(centre0)
		if d0 < reveal_dist:
			reveal_dist = d0
			reveal_best = c
	if reveal_best.x >= 0:
		_reveal(reveal_best)
	var centre_cell := Vector2i(GRID / 2, GRID / 2)
	var dep := Vector2i(-1, -1)
	var best := 1.0e9
	for c in deposits.keys():
		if deposits[c].revealed and (c as Vector2i).distance_to(centre_cell) < best:
			best = (c as Vector2i).distance_to(centre_cell)
			dep = c
	if dep.x < 0:
		return

	# run the field toward the middle of the lease so it stays on the flat basin
	var toward := centre_cell - dep
	var dir := Vector2i(1 if toward.x > 0 else -1, 0) if absi(toward.x) >= absi(toward.y) else Vector2i(0, 1 if toward.y > 0 else -1)
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var perp := Vector2i(-dir.y, dir.x)
	if not _in_bounds(dep + dir * 17 + perp):
		dir = -dir
		perp = -perp

	cash = 600000.0
	paused = false
	hud.hide_start_overlay()

	# a small three-well field so the demo shows a real network
	var slots := [0, 4, 8]
	for k in slots:
		var c: Vector2i = dep + dir * k
		if not deposits.has(c):
			deposits[c] = {"amount": 24000.0, "revealed": true, "node": null}
		deposits[c].revealed = true

	_try_build("explorer", dep + dir * 5 - perp * 2)
	for k in slots:
		_try_build("well", dep + dir * k)
	_try_build("storage", dep + dir * 11)
	_try_build("storage", dep + dir * 14)
	_try_build("refinery", dep + dir * 17)
	_try_build("pump", dep + dir * 6 + perp * 2)
	_try_build("separator", dep + dir * 9 + perp * 2)
	_try_build("metering", dep + dir * 12 + perp * 2)
	_try_build("tank_farm", dep + dir * 3 + perp * 3)
	_try_build("depot", dep + dir * 10 - perp * 2)

	tool = "pipe"
	_lay_line(dep + perp, dep + dir * 17 + perp)
	# branch the tank farm into the run so the demo has no dangling structure
	_lay_line(dep + dir * 3 + perp, dep + dir * 3 + perp * 2)
	tool = "road"
	# stop at the refinery's edge: its 2x2 footprint occupies the next cell, and
	# (dir*15 - perp) is already adjacent to it, so access still works
	_lay_line(dep - perp, dep + dir * 15 - perp)
	# a deliberately isolated stub so the network warning is visible in the demo
	_place_infra(dep + dir * 8 - perp * 4)
	tool = ""
	_rebuild_components()
	# fleet needs a served street to be stationed on
	_buy_unit("pickup")

	camera.set_orbit()
	camera.target = cell_to_world(dep + dir * 8)
	camera.dist = 205.0
	speed = 2.0
	# show the pipeline management view in screenshots
	selected_cell = dep + dir * 8 + perp

	# optional: stage an in-progress pipe drag so the port-joint hints show
	if OS.get_cmdline_user_args().has("--pipe-route"):
		selected_cell = Vector2i(-1, -1)
		tool = "pipe"
		drag_start = dep + dir
		hover_cell = dep + dir * 3
		dragging = true
		_update_drag_preview()
		camera.target = cell_to_world(dep + dir * 2)
		camera.dist = 62.0
		camera.pitch = deg_to_rad(-52.0)

	# optional: stage an in-progress road drag for the placement screenshot
	if OS.get_cmdline_user_args().has("--route"):
		selected_cell = Vector2i(-1, -1)
		tool = "road"
		drag_start = dep + dir * 8 - perp * 4
		hover_cell = dep + dir * 8 - perp
		dragging = true
		_update_drag_preview()
		camera.target = cell_to_world(dep + dir * 8 - perp * 2)
		camera.dist = 84.0
		camera.pitch = deg_to_rad(-58.0)

	# optional: lay an L-shaped pipe run and inspect its corner joint
	if OS.get_cmdline_user_args().has("--bend"):
		selected_cell = Vector2i(-1, -1)
		var s := dep - perp * 3
		var corner := s + dir * 6
		tool = "pipe"
		_lay_line(s, corner)
		_lay_line(corner, corner + perp * 4)
		tool = ""
		_rebuild_components()
		selected_cell = corner
		camera.target = cell_to_world(corner)
		camera.dist = 74.0
		camera.pitch = deg_to_rad(-62.0)

	# optional: close-up of a pipe actually entering a pumpjack's port
	if OS.get_cmdline_user_args().has("--joint"):
		selected_cell = Vector2i(-1, -1)
		camera.target = cell_to_world(dep) + Vector3(perp.x, 0.0, perp.y) * (CELL * 0.6)
		camera.dist = 30.0
		camera.pitch = deg_to_rad(-34.0)
		camera.yaw = deg_to_rad(28.0)

	# optional: overhead layout view for checking joins and access
	if OS.get_cmdline_user_args().has("--top"):
		camera.target = cell_to_world(dep + dir * 8)
		camera.dist = 200.0
		camera.pitch = deg_to_rad(-80.0)
		camera.yaw = deg_to_rad(6.0)

	# optional: show the placement port hint over a free cell
	if OS.get_cmdline_user_args().has("--ports"):
		selected_cell = Vector2i(-1, -1)
		tool = "well"
		hover_cell = dep + dir * 2 + perp * 2
		_update_ghost()
		camera.target = cell_to_world(hover_cell)
		camera.dist = 48.0
		camera.pitch = deg_to_rad(-52.0)

	# optional: show every structure's pipe ports while the pipe tool is active
	if OS.get_cmdline_user_args().has("--pipe-ports"):
		selected_cell = Vector2i(-1, -1)
		tool = "pipe"
		hover_cell = dep + dir * 2
		_update_ghost()
		camera.target = cell_to_world(dep + dir * 2)
		camera.dist = 78.0
		camera.pitch = deg_to_rad(-56.0)

	# optional: show the pipe/road utilisation heat-map
	if OS.get_cmdline_user_args().has("--net"):
		show_network = true
		_rebuild_network_overlay()
		camera.target = cell_to_world(dep + dir * 8)
		camera.dist = 190.0
		camera.pitch = deg_to_rad(-66.0)
	# optional: an unconnected tank to show the warning markers
	if OS.get_cmdline_user_args().has("--warn"):
		var warn_cell := dep + dir * 6 + perp * 8
		var guard := 0
		while (not _cell_free(warn_cell) or _cell_relief(warn_cell) > MAX_INFRA_RELIEF) and guard < 48:
			warn_cell += Vector2i(0, 1)
			guard += 1
		_try_build("storage", warn_cell)
		camera.target = cell_to_world(warn_cell)
		camera.dist = 58.0
		camera.pitch = deg_to_rad(-46.0)
	# optional: show the field manual overlay
	if OS.get_cmdline_user_args().has("--help"):
		hud.toggle_help()
	# optional: show the foreclosure overlay
	if OS.get_cmdline_user_args().has("--gameover"):
		hud.show_game_over("Company value -$300,000 — the bank has called the lease.\nLoad a save (F9) or restart.")
	# optional: inspect the depot and its street boost
	if OS.get_cmdline_user_args().has("--depot"):
		var dcell := dep + dir * 10 - perp * 2
		selected_cell = dcell
		camera.target = cell_to_world(dcell)
		camera.dist = 56.0
		camera.pitch = deg_to_rad(-46.0)
	hud.toast("Demo field: 3 wells → 2 tanks → refinery, road south of the row", Color(0.7, 0.9, 0.6))
	if OS.get_cmdline_user_args().has("--victory"):
		cash = 1100000.0
	if OS.get_cmdline_user_args().has("--contract"):
		_offer_contract()


# --------------------------------------------------------------------------- #
# self-test: asserts the pipe / road / terrain rules the game is built on
# --------------------------------------------------------------------------- #

var _st_fails := 0
var _st_checks := 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	_st_checks += 1
	if ok:
		print("  PASS  ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		_st_fails += 1
		print("  FAIL  ", name, ("  (" + detail + ")") if detail != "" else "")


func _measure_income() -> float:
	_rebuild_components()
	for b in buildings:
		if b.kind == "well":
			b.deposit = 24000.0
		elif b.kind == "storage":
			b.crude = 0.0
	income_rate = 0.0
	_income_accum = 0.0
	_income_timer = 0.0
	_simulate(0.6)
	return income_rate


## Scripted normal-start check (QA, not part of the rules suite).
func _run_playtest() -> void:
	await get_tree().create_timer(0.4).timeout
	_clear_world()
	_generate_deposits()
	var centre0 := Vector2i(GRID / 2, GRID / 2)
	var reveal_best := Vector2i(-1, -1)
	var reveal_dist := 1.0e9
	for c in deposits.keys():
		var d0 := (c as Vector2i).distance_to(centre0)
		if d0 < reveal_dist:
			reveal_dist = d0
			reveal_best = c
	if reveal_best.x >= 0:
		_reveal(reveal_best)
	var centre_cell := Vector2i(GRID / 2, GRID / 2)
	var dep := Vector2i(-1, -1)
	var best := 1.0e9
	for c in deposits.keys():
		if deposits[c].revealed and (c as Vector2i).distance_to(centre_cell) < best:
			best = (c as Vector2i).distance_to(centre_cell)
			dep = c
	if dep.x < 0:
		print("PLAYTEST: no revealed deposit")
		get_tree().quit()
		return
	var toward := centre_cell - dep
	var dir := Vector2i(1 if toward.x > 0 else -1, 0) if absi(toward.x) >= absi(toward.y) \
		else Vector2i(0, 1 if toward.y > 0 else -1)
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var perp := Vector2i(-dir.y, dir.x)
	cash = 300000.0
	debt = 0.0
	paused = true
	hud.hide_start_overlay()
	_try_build("explorer", dep + dir * 3 - perp * 2)
	_try_build("well", dep)
	_try_build("storage", dep + dir * 3)
	_try_build("refinery", dep + dir * 6)
	tool = "pipe"
	_lay_line(dep + perp, dep + dir * 6 + perp)
	tool = "road"
	_lay_line(dep - perp, dep + dir * 6 - perp)
	tool = ""
	_rebuild_components()
	var after_build := cash
	if OS.get_cmdline_user_args().has("--shot"):
		# frame the upgraded assets: pumpjack, storage tank and refinery
		camera.set_orbit()
		camera.target = cell_to_world(dep) + Vector3(0, 3.2, 0)
		camera.dist = 44.0
		camera.pitch = deg_to_rad(-36.0)
		camera.yaw = deg_to_rad(34.0)
		return
	var wells := 0
	var tanks := 0
	var refineries := 0
	for b in buildings:
		match _role_of(b.kind):
			"producer":
				wells += 1
			"buffer":
				tanks += 1
			"consumer":
				refineries += 1
	for i in 120:
		_simulate(1.0)
	print("=== PLAYTEST (Normal $300k) ===")
	print("  after build: $%.0f (wells %d · tanks %d · refineries %d)" % [
		after_build, wells, tanks, refineries])
	print("  income: $%.1f/s" % income_rate)
	print("  after 120 s: cash $%.0f · value $%.0f" % [cash, cash - debt])
	print("  failed=%s won=%s" % [failed, won])
	get_tree().quit()


func _selftest() -> void:
	paused = true
	cash = 2000000.0
	hud.hide_start_overlay()
	_clear_world()
	# rule tests use a deterministic flat field; the game keeps its terrain
	_flatten_terrain(20.0)
	print("=== PIPELINE / STREET RULE TESTS ===")

	var base := Vector2i(GRID / 2, GRID / 2)
	if not deposits.has(base):
		deposits[base] = {"amount": 24000.0, "revealed": true, "node": null}
	deposits[base].revealed = true
	deposits[base].amount = 24000.0

	# ---- A: a well may never feed a refinery directly through one pipe run ----
	_try_build("well", base)
	_check("pumpjack builds on a revealed deposit", occupied.has(base))
	_check("site is levelled flat under the pad", _footprint_relief([base]) < 0.05,
		"relief %.3f m" % _footprint_relief([base]))

	# ---- A0: fleet needs a served street to station on ----
	var fleet0 := int(fleet.get("pickup", 0))
	_buy_unit("pickup")
	_check("fleet purchase requires a served street",
		int(fleet.get("pickup", 0)) == fleet0 and fleet_units.is_empty())
	tool = "pipe"
	_place_infra(base + Vector2i(1, 0))
	tool = "road"
	for k in 5:
		_place_infra(base + Vector2i(k, -1))
	tool = ""
	_try_build("refinery", base + Vector2i(2, 0))
	_check("refinery builds beside the well", occupied.has(base + Vector2i(2, 0)))
	var direct_income := _measure_income()
	_check("well -> pipe -> refinery makes NO income without storage", direct_income <= 0.001,
		"income %.3f" % direct_income)

	# ---- B: a storage tank bridges the two pipe runs ----
	_bulldoze_at(base + Vector2i(2, 0))
	_try_build("storage", base + Vector2i(2, 0))
	tool = "pipe"
	_place_infra(base + Vector2i(3, 0))
	tool = ""
	_try_build("refinery", base + Vector2i(4, 0))
	var bridged := _measure_income()
	_check("well -> tank -> refinery flows", bridged > 0.001, "income %.1f/s" % bridged)

	# ---- C: operation requires road access ----
	var road_cell := base + Vector2i(0, -1)
	_bulldoze_at(road_cell)
	var well_entry: Dictionary = occupied[base]
	_check("bulldozing a road cuts access immediately", not bool(well_entry.get("road", true)))
	var no_road := _measure_income()
	_check("pumpjack without road access stops producing", no_road <= 0.001,
		"income %.3f" % no_road)
	tool = "road"
	_place_infra(road_cell)
	tool = ""
	var with_road := _measure_income()
	_check("road access restores production", with_road > 0.001, "income %.1f/s" % with_road)

	# ---- D: a survey office needs a road, then reveals nearby deposits ----
	var ex := base + Vector2i(8, 4)
	var probe_dep := ex + Vector2i(2, 2)
	deposits[probe_dep] = {"amount": 9000.0, "revealed": false, "node": null}
	tool = "road"
	_place_infra(ex + Vector2i(0, -1))
	tool = ""
	_try_build("explorer", ex)
	_check("exploration office reveals a nearby deposit", bool(deposits[probe_dep].revealed))

	# ---- D2: without a road the office waits, then surveys when one arrives ----
	var ex3 := base + Vector2i(-10, 3)
	var probe3 := ex3 + Vector2i(1, 1)
	deposits[probe3] = {"amount": 1200.0, "revealed": false, "node": null}
	_try_build("explorer", ex3)
	_check("survey office waits for road access",
		occupied.has(ex3) and not bool(occupied[ex3].get("surveyed", true))
		and not bool(deposits[probe3].revealed))
	_check("survey office reports road need, not a pipe",
		_status_of(occupied[ex3]) == "no road access", _status_of(occupied[ex3]))
	tool = "road"
	_place_infra(ex3 + Vector2i(0, -1))
	tool = ""
	_check("survey starts when a road reaches the office",
		bool(occupied[ex3].get("surveyed", false)) and bool(deposits[probe3].revealed))
	_check("survey office is ok once it has a road",
		_status_of(occupied[ex3]) == "ok", _status_of(occupied[ex3]))

	# ---- E: pipeline cost is charged per cell ----
	var before := cash
	var pipes_before := pipes.size()
	tool = "pipe"
	for i in 5:
		_place_infra(base + Vector2i(-6 + i, 10))
	tool = ""
	var added := pipes.size() - pipes_before
	var spent := before - cash
	_check("pipeline costs by length", added == 5 and is_equal_approx(spent, float(added) * float(_def("pipe").cost)),
		"%d cells cost $%.0f" % [added, spent])

	# ---- E: roads cost by length too ----
	before = cash
	var roads_before := roads.size()
	tool = "road"
	for i in 5:
		_place_infra(base + Vector2i(-6 + i, 13))
	tool = ""
	var road_added := roads.size() - roads_before
	spent = before - cash
	_check("road costs by length", road_added == 5 and is_equal_approx(spent, float(road_added) * float(_def("road").cost)),
		"%d cells cost $%.0f" % [road_added, spent])

	# ---- F: the route preview matches what actually gets built ----
	tool = "road"
	var ra := Vector2i(base.x - 10, base.y + 6)
	var rb := Vector2i(base.x + 4, base.y + 6)
	var preview := _route_cells(ra, rb)
	var roads_before2 := roads.size()
	_lay_line(ra, rb)
	var built := roads.size() - roads_before2
	tool = ""
	_check("route preview matches the built run", preview.size() == built,
		"preview %d, built %d" % [preview.size(), built])

	# ---- G: pipeline throughput is the weakest-cell bottleneck minus friction ----
	var probe := base + Vector2i(1, 0)
	var root := int(pipe_comp.get(probe, -1))
	var ncells := int(comp_cells.get(root, 0))
	var cap := float(comp_capacity.get(root, 0.0))
	var expected := catalogue.pipe_run_capacity(catalogue.pipe_grade_capacity(0), ncells, 0.0)
	_check("pipeline capacity uses the weakest grade and friction",
		root >= 0 and is_equal_approx(cap, expected),
		"%d cells -> %.1f bbl/s" % [ncells, cap])
	_check("trunk and high-pressure pipe raise the ceiling",
		catalogue.pipe_grade_capacity(2) > catalogue.pipe_grade_capacity(1) \
		and catalogue.pipe_grade_capacity(1) > catalogue.pipe_grade_capacity(0),
		"%.0f / %.0f / %.0f bbl/s" % [catalogue.pipe_grade_capacity(0),
			catalogue.pipe_grade_capacity(1), catalogue.pipe_grade_capacity(2)])

	# ---- G1: terrain lift costs head; pump stations recover it ----
	var flat_cap := catalogue.pipe_run_capacity(catalogue.pipe_grade_capacity(0), ncells, 0.0, 0.0, 0)
	var uphill_cap := catalogue.pipe_run_capacity(catalogue.pipe_grade_capacity(0), ncells, 0.0, 30.0, 0)
	var pumped_cap := catalogue.pipe_run_capacity(catalogue.pipe_grade_capacity(0), ncells, 8.0, 30.0, 0)
	_check("terrain lift reduces run capacity", uphill_cap < flat_cap - 0.01,
		"%.1f -> %.1f bbl/s at 30 m lift" % [flat_cap, uphill_cap])
	_check("pump head recovers an uphill run", pumped_cap > uphill_cap,
		"%.1f -> %.1f bbl/s with a pump" % [uphill_cap, pumped_cap])
	_check("associated gas has a market",
		catalogue.gas_ratio() > 0.0 and catalogue.gas_price() > 0.0,
		"%.2f u/bbl at $%.0f" % [catalogue.gas_ratio(), catalogue.gas_price()])

	# ---- G2: the selected pipe grade is stored and priced ----
	var grade_cell := _find_build_area(base + Vector2i(12, 12), 1)
	var grade_ok := false
	if grade_cell.x >= 0:
		tool = "pipe"
		pipe_grade_choice = 1
		var cash0 := cash
		_place_infra(grade_cell)
		grade_ok = pipes.has(grade_cell) and int(pipe_grade.get(grade_cell, -1)) == 1 \
			and is_equal_approx(cash0 - cash, catalogue.pipe_grade_cost(1))
		pipe_grade_choice = 0
		tool = ""
	_check("pipe grade is stored and priced", grade_ok,
		"grade %d · $%s" % [int(pipe_grade.get(grade_cell, -1)),
			hud.fmt_num(catalogue.pipe_grade_cost(1))])

	# ---- H: buildings connect only through declared ports ----
	var ex2 := base + Vector2i(-8, 4)
	_try_build("explorer", ex2)
	tool = "pipe"
	_place_infra(ex2 + Vector2i(1, 0))
	tool = ""
	_rebuild_components()
	_check("exploration office exposes no pipeline port",
		occupied.has(ex2) and int(occupied[ex2].comp) == -1)

	# the pumpjack's motor/access side (south) is not a flowline port
	tool = "pipe"
	_place_infra(base + Vector2i(0, 1))
	tool = ""
	_rebuild_components()
	var south_cid := int(pipe_comp.get(base + Vector2i(0, 1), -1))
	var south_joined := south_cid >= 0 and comp_members.has(south_cid) \
		and not (comp_members[south_cid].wells as Array).is_empty()
	_check("pumpjack ignores a pipe on its motor side", not south_joined)
	_check("motor side has no pipe arm",
		(_pipe_mask(base + Vector2i(0, 1)) & PortSpec.SIDE_N) == 0,
		"mask %s" % _sides_text(_pipe_mask(base + Vector2i(0, 1))))
	_bulldoze_at(base + Vector2i(0, 1))

	# the same kind of pipe on a flowline side DOES grow a joint arm
	var west_cell := base + Vector2i(-1, 0)
	tool = "pipe"
	_place_infra(west_cell)
	tool = ""
	_check("pipe on a port side grows a joint arm",
		(_pipe_mask(west_cell) & PortSpec.SIDE_E) != 0,
		"mask %s" % _sides_text(_pipe_mask(west_cell)))
	_check("route preview flags port joints",
		(_port_joint_at(west_cell) & PortSpec.SIDE_E) != 0
		and _port_joint_at(base + Vector2i(0, 1)) == 0,
		"port side %s · motor side %s" % [_sides_text(_port_joint_at(west_cell)),
			_sides_text(_port_joint_at(base + Vector2i(0, 1)))])
	_bulldoze_at(west_cell)
	tool = "pipe"
	var priced: Array[Vector2i] = [base + Vector2i(-5, 9), base + Vector2i(-4, 9), base + Vector2i(-3, 9)]
	_check("route cost is priced per cell",
		is_equal_approx(_route_cost(priced), float(_def("pipe").cost) * 3.0),
		"$%.0f" % _route_cost(priced))
	tool = ""

	# ---- H2: a pipe laid BEFORE a structure must rebuild to reach its port ----
	var flow_area := Vector2i(-1, -1)
	var pre_pipe := Vector2i(-1, -1)
	for off in [Vector2i(18, 6), Vector2i(-16, -12), Vector2i(16, -14), Vector2i(-14, 16)]:
		var cand := _find_build_area(base + (off as Vector2i), 2)
		if cand.x < 0:
			continue
		var pc: Vector2i = cand + Vector2i(-1, 0)
		if _in_bounds(pc) and _cell_free(pc) and not deposits.has(pc):
			flow_area = cand
			pre_pipe = pc
			break
	var pre_ok := false
	if flow_area.x >= 0:
		tool = "pipe"
		_place_infra(pre_pipe)
		tool = ""
		_try_build("storage", flow_area)
		pre_ok = occupied.has(flow_area) and pipes.has(pre_pipe) \
			and (int(pipes[pre_pipe].get_meta("mask", 0)) & PortSpec.SIDE_E) != 0
	_check("pipe tile rebuilds to reach a later structure", pre_ok,
		"mask %s" % (_sides_text(int(pipes[pre_pipe].get_meta("mask", 0)))
			if pipes.has(pre_pipe) else "none"))

	# ---- I: a pump station raises the run's throughput ----
	var cap_before := float(comp_capacity.get(root, 0.0))
	_try_build("pump", base + Vector2i(1, 1))
	var cap_after := float(comp_capacity.get(root, 0.0))
	_check("pump station raises run capacity", cap_after > cap_before + 0.5,
		"%.1f -> %.1f bbl/s" % [cap_before, cap_after])

	# ---- J: diagonal drags still produce an edge-connected run ----
	var diag: Array[Vector2i] = _line_cells(base + Vector2i(-8, 20), base + Vector2i(-2, 24))
	var connected := diag.size() > 1
	for i in range(1, diag.size()):
		var step: Vector2i = diag[i] - diag[i - 1]
		if absi(step.x) + absi(step.y) != 1:
			connected = false
	_check("route cells are edge-connected (no diagonal gaps)", connected,
		"%d cells" % diag.size())

	# ---- J: every catalogue entry is complete ----
	var catalogue_ok := catalogue.entries.size() >= 12
	for e in catalogue.entries:
		if e.role == "" or e.ports == null or e.capacity == null:
			catalogue_ok = false
	_check("catalogue declares role, ports and capacity for every structure",
		catalogue_ok, "%d structures" % catalogue.entries.size())

	# ---- K: buffer volume comes from the resource ----
	_try_build("tank_farm", base + Vector2i(-2, 2))
	var farm: Dictionary = occupied.get(base + Vector2i(-2, 2), {})
	_check("tank farm takes its volume from the catalogue",
		not farm.is_empty() and is_equal_approx(float(farm.get("capacity", 0.0)), 2400.0),
		"%d bbl" % int(farm.get("capacity", 0.0)))

	# ---- K2: a 2x2 structure is scaled to its WHOLE footprint ----
	var farm_half: Vector2 = _structure_half(farm.get("node")) if not farm.is_empty() else Vector2.ZERO
	_check("2x2 structure fills its footprint",
		maxf(farm_half.x, farm_half.y) > CELL * 0.75,
		"model %.1f m across (cell %.0f m)" % [maxf(farm_half.x, farm_half.y) * 2.0, CELL])
	var farm_span := _connector_span(base + Vector2i(-2, 1), farm, Vector2i(0, 1))
	_check("2x2 pipe joints use the block's real face",
		not farm.is_empty() and farm_span.y > farm_span.x + 0.3 \
		and farm_span.y < CELL * 1.5,
		"joint %.2f -> %.2f m from the pipe centre" % [farm_span.x, farm_span.y])

	# ---- K3: the pipe joints are derived from the model, not a grid guess ----
	var tank_cell := base + Vector2i(-9, 7)
	while not _cell_free(tank_cell):
		tank_cell += Vector2i(1, 0)
	_try_build("storage", tank_cell)
	var pipe_cell := tank_cell + Vector2i(1, 0)
	tool = "pipe"
	_lay_line(pipe_cell, pipe_cell)
	tool = ""
	var tank: Dictionary = occupied.get(tank_cell, {})
	var pipe_node: Node3D = pipes.get(pipe_cell)
	var span := _connector_span(pipe_cell, tank, Vector2i(-1, 0))
	_check("pipe run is lifted to the structure pad",
		pipe_node != null and absf(pipe_node.position.y - float(tank.get("top", 0.0)) - 0.02) < 0.05,
		"pipe y %.2f · pad y %.2f" % [pipe_node.position.y if pipe_node != null else 0.0,
			float(tank.get("top", 0.0))])
	_check("pipe grows an arm toward a building port",
		(_pipe_mask(pipe_cell) & PortSpec.SIDE_W) != 0,
		"mask %s" % _sides_text(_pipe_mask(pipe_cell)))
	_check("pipe joint reaches the structure surface",
		not tank.is_empty() and span.y > span.x + 0.4 and span.y <= CELL * 0.5 + 1.2,
		"joint %.2f -> %.2f m from the pipe centre" % [span.x, span.y])
	_check("1x1 structure keeps a service apron",
		_structure_half(tank.get("node")).x < CELL * 0.5,
		"half-width %.2f m" % _structure_half(tank.get("node")).x)

	# ---- K4: a pipe drag snaps its endpoint to a structure port ----
	var approach := tank_cell + Vector2i(0, 2)
	var snapped := _snap_pipe_end(approach, tank_cell)
	_check("pipe drag snaps to a structure port",
		snapped != tank_cell and _port_joint_at(snapped) != 0,
		"snapped to %s" % str(snapped))
	# the pumpjack's south side is the motor side: a snap must pick a port instead
	var motor_snap := _snap_pipe_end(base + Vector2i(0, 2), base)
	_check("pipe snap avoids the pumpjack motor side",
		motor_snap != base and _port_joint_at(motor_snap) != 0,
		"snapped to %s" % str(motor_snap))

	# ---- L: a separator raises refined income on its run ----
	var before_sep := _measure_income()
	_try_build("separator", base + Vector2i(3, 1))
	var after_sep := _measure_income()
	_check("separator raises refined income", after_sep > before_sep + 0.5,
		"%.1f -> %.1f/s" % [before_sep, after_sep])

	# ---- M: a metering skid raises the sale price ----
	tool = "pipe"
	_place_infra(base + Vector2i(2, 1))
	tool = ""
	var before_meter := _measure_income()
	_try_build("metering", base + Vector2i(2, 2))
	var after_meter := _measure_income()
	_check("metering skid raises sale income", after_meter > before_meter + 0.5,
		"%.1f -> %.1f/s" % [before_meter, after_meter])
	var run_income := 0.0
	for id in comp_income.keys():
		run_income = maxf(run_income, float(comp_income[id]))
	_check("network manager shows per-run income", run_income > 0.0,
		"$%.1f/s" % run_income)

	# ---- N: the compressor is a catalogue-driven booster ----
	var comp_def := catalogue.find("compressor")
	_check("compressor is a catalogue booster (+5 bbl/s)",
		comp_def != null and comp_def.role == "booster" \
		and is_equal_approx(comp_def.capacity.boost, 5.0))

	# ---- O: a brand-new structure plugs in with data only ----
	var plug := BuildingDefinition.new()
	plug.id = "test_booster"
	plug.display_name = "Test Booster"
	plug.cost = 1000.0
	plug.footprint = 1
	plug.model_id = "mid_pump_station"
	plug.role = "booster"
	var plug_ports := PortSpec.new()
	plug_ports.in_sides = PortSpec.ALL_SIDES
	plug_ports.out_sides = PortSpec.ALL_SIDES
	plug_ports.links = 2
	plug.ports = plug_ports
	var plug_cap := CapacitySpec.new()
	plug_cap.boost = 3.0
	plug.capacity = plug_cap
	catalogue.entries.append(plug)

	tool = "pipe"
	_place_infra(base + Vector2i(0, 1))
	tool = ""
	_rebuild_components()
	var plug_run := int(pipe_comp.get(base + Vector2i(1, 0), -1))
	var plug_cap0 := float(comp_capacity.get(plug_run, 0.0))
	_try_build("test_booster", base + Vector2i(0, 2))
	var plug_cap1 := float(comp_capacity.get(plug_run, 0.0))
	_check("a new structure plugs in with data only", is_equal_approx(plug_cap1, plug_cap0 + 3.0),
		"%.1f -> %.1f bbl/s" % [plug_cap0, plug_cap1])

	# ---- P: road logistics capacity throttles when overloaded ----
	var road_cid := -1
	for id in road_capacity.keys():
		if bool(road_served.get(id, false)):
			road_cid = int(id)
			break
	_check("road network has logistics capacity and load",
		road_cid >= 0 and float(road_capacity.get(road_cid, 0.0)) > 0.0 \
		and float(road_load.get(road_cid, 0.0)) > 0.0,
		"load %.1f / cap %.1f" % [float(road_load.get(road_cid, 0.0)),
			float(road_capacity.get(road_cid, 0.0))])
	var well_b: Dictionary = occupied[base]
	var normal_factor := _road_factor(well_b)
	var saved_load := float(road_load.get(road_cid, 0.0))
	road_load[road_cid] = float(road_capacity.get(road_cid, 0.0)) * 2.0
	var throttled := _road_factor(well_b)
	road_load[road_cid] = saved_load
	_check("road congestion throttles throughput",
		is_equal_approx(normal_factor, 1.0) and throttled < 1.0,
		"factor %.2f -> %.2f" % [normal_factor, throttled])

	# ---- P2: road preview reports sites and network continuity ----
	var site_probe: Array[Vector2i] = [tank_cell + Vector2i(0, 1)]
	var net_probe: Array[Vector2i] = [base + Vector2i(1, -1)]
	_check("road preview counts the sites it serves",
		_road_preview_sites(site_probe) == 1 and not _road_preview_served(site_probe),
		"%d site(s), isolated" % _road_preview_sites(site_probe))
	_check("road preview recognises a served network",
		_road_preview_served(net_probe), "joins a served run")
	var road_info := _describe(road_cell)
	_check("road inspector lists the sites it serves",
		String(road_info[0]) == "Road" and String(road_info[1]).contains("Sites:"),
		String(road_info[1]).split("\n")[2] if String(road_info[1]).split("\n").size() > 2 else "")

	# ---- P3: the network manager lists every run and street ----
	var rows := _network_rows()
	var has_pipe := false
	var has_road := false
	for r in rows:
		if String(r.kind) == "pipe":
			has_pipe = true
		elif String(r.kind) == "road":
			has_road = true
	_check("network manager lists pipe runs and streets",
		has_pipe and has_road and rows.size() >= 2, "%d rows" % rows.size())

	# ---- Q: rotating a structure rotates its pipeline ports ----
	var rotated := _rot_mask(_ports_mask("well"), 2)
	_check("rotating a pumpjack moves its flowline port",
		(rotated & PortSpec.SIDE_S) != 0, "sides %s" % _sides_text(rotated))

	# ---- I: a cliff rejects the run instead of floating track ----
	var steep := Vector2i(-1, -1)
	for c in pipes.keys():
		for d in DIRS:
			var n: Vector2i = (c as Vector2i) + d
			if _in_bounds(n) and not pipes.has(n) and not roads.has(n) and not occupied.has(n):
				if absf(_cell_max_height(c) - _cell_max_height(n)) > MAX_GRADE:
					steep = n
					break
		if steep.x >= 0:
			break
	if steep.x >= 0:
		var pcount := pipes.size()
		tool = "pipe"
		_place_infra(steep)
		tool = ""
		_check("pipe refuses a grade steeper than %.1f m/cell" % MAX_GRADE, pipes.size() == pcount)
	else:
		print("  SKIP  no cliff on this lease to test the grade limit")

	# ---- S: fleet units raise road logistics on the street they serve ----
	selected_cell = road_cell
	var assigned := int(road_comp.get(road_cell, -1))
	var cap_before_fleet := float(road_capacity.get(assigned, 0.0))
	var cash_before_fleet := cash
	_buy_unit("pickup")
	# no manual rebuild here: purchasing must update capacity by itself
	var cap_after_fleet := float(road_capacity.get(assigned, 0.0))
	var assigned_bonus := _fleet_logistics_for(assigned)
	var other_bonus := 0.0
	for id in road_comp.values():
		if int(id) != assigned:
			other_bonus = maxf(other_bonus, _fleet_logistics_for(int(id)))
	_check("fleet unit raises the street it is assigned to",
		int(fleet.get("pickup", 0)) == 1 and cap_after_fleet > cap_before_fleet \
		and is_equal_approx(assigned_bonus, 2.0),
		"street %d cap %.1f -> %.1f (+%.0f logi)" % [
			assigned, cap_before_fleet, cap_after_fleet, assigned_bonus])
	_check("fleet logistics do not leak to other streets", other_bonus == 0.0,
		"other street bonus %.1f" % other_bonus)
	_check("fleet unit is paid for", cash < cash_before_fleet,
		"spent $%.0f" % (cash_before_fleet - cash))
	_check("fleet unit appears on the road", fleet_nodes.size() >= 1,
		"%d vehicles" % fleet_nodes.size())
	var sel_rows := _network_rows()
	var sel_marked := false
	for r in sel_rows:
		if bool(r.selected) and String(r.kind) == "road":
			sel_marked = true
	_check("network manager marks the selected street", sel_marked)

	# ---- S2: a second served street, then transfer a unit to the selected one ----
	var branch_cell := base + Vector2i(0, 1)
	tool = "road"
	_place_infra(branch_cell)
	tool = ""
	_rebuild_components()
	var branch_cid := int(road_comp.get(branch_cell, -1))
	_check("second street serves its sites", bool(road_served.get(branch_cid, false)))
	selected_cell = branch_cell
	_buy_unit("pickup")
	selected_cell = road_cell
	var home_cid := int(road_comp.get(road_cell, -1))
	var home_before := 0
	for u in fleet_units:
		if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == home_cid:
			home_before += 1
	_transfer_fleet_here()
	var home_after := 0
	for u in fleet_units:
		if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == home_cid:
			home_after += 1
	_check("fleet can be transferred to the selected street",
		home_after == home_before + 1 and fleet_units.size() == 2,
		"%d -> %d units" % [home_before, home_after])

	# ---- S3: demolish the selected street network in one action ----
	selected_cell = branch_cell
	var roads_before_demolish := roads.size()
	_demolish_selected_network()
	_check("demolish clears the selected street network",
		not roads.has(branch_cell) and roads.size() < roads_before_demolish,
		"%d -> %d roads" % [roads_before_demolish, roads.size()])

	# ---- S4: a truck depot boosts the street it sits beside ----
	var main_cid := int(road_comp.get(base + Vector2i(0, -1), -1))
	var cap_before_depot := float(road_capacity.get(main_cid, 0.0))
	_try_build("depot", base + Vector2i(0, -2))
	var cap_after_depot := float(road_capacity.get(main_cid, 0.0))
	_check("truck depot boosts its street",
		occupied.has(base + Vector2i(0, -2)) and cap_after_depot >= cap_before_depot + 2.9,
		"%.1f -> %.1f" % [cap_before_depot, cap_after_depot])
	var depot_info := _describe(base + Vector2i(0, -2))
	_check("depot inspector explains its street boost",
		String(depot_info[0]) == "Truck Depot" and String(depot_info[1]).contains("+3"),
		String(depot_info[1]).split("\n")[1] if String(depot_info[1]).split("\n").size() > 1 else "")

	# ---- U: infrastructure can be replaced in place ----
	var swap := base + Vector2i(8, 2)
	tool = "road"
	_place_infra(swap)
	tool = "pipe"
	_place_infra(swap)
	tool = ""
	_check("pipe replaces a road in place", pipes.has(swap) and not roads.has(swap))

	# ---- T: sales contract tracks deliveries ----
	contract = {"target": 1000.0, "done": 0.0, "time": 100.0, "bonus": 0.2}
	var contract_income := _measure_income()
	_check("sales contract tracks deliveries",
		contract_income > 0.0 and float(contract.done) > 0.0,
		"%.2f bbl delivered" % float(contract.done))
	contract = {}
	contract_timer = 30.0

	# ---- V: pipes and structures connect in either build order ----
	var link_cell := base + Vector2i(-16, 14)
	var guard := 0
	while guard < 24 and (not _cell_free(link_cell) \
			or not _cell_free(link_cell + Vector2i(1, 0)) \
			or _cell_relief(link_cell) > MAX_INFRA_RELIEF \
			or _footprint_relief([link_cell + Vector2i(1, 0)]) > MAX_BUILD_RELIEF):
		link_cell += Vector2i(1, 0)
		guard += 1
	tool = "pipe"
	_lay_line(link_cell, link_cell)
	tool = ""
	_try_build("storage", link_cell + Vector2i(1, 0))
	_check("pipe laid before a structure grows its joint arm",
		(_pipe_mask(link_cell) & PortSpec.SIDE_E) != 0,
		"mask %s" % _sides_text(_pipe_mask(link_cell)))
	_bulldoze_at(link_cell + Vector2i(1, 0))
	_check("bulldozing a structure removes the joint arm",
		(_pipe_mask(link_cell) & PortSpec.SIDE_E) == 0,
		"mask %s" % _sides_text(_pipe_mask(link_cell)))

	# ---- K6: demolish an entire pipe run ----
	selected_cell = link_cell
	var pipes_before_demolish := pipes.size()
	_demolish_selected_network()
	_check("demolish clears the selected pipe run",
		not pipes.has(link_cell) and pipes.size() < pipes_before_demolish,
		"%d -> %d pipes" % [pipes_before_demolish, pipes.size()])

	# ---- R: save and load round-trip ----
	_save_game()
	var saved_buildings := buildings.size()
	var saved_pipes := pipes.size()
	var saved_cash := cash
	var saved_fleet := int(fleet.get("pickup", 0))
	_bulldoze_at(base + Vector2i(1, 0))
	_check("save writes a file", FileAccess.file_exists(SAVE_PATH))
	var loaded_ok := _load_game()
	_check("load restores the field",
		loaded_ok and buildings.size() == saved_buildings and pipes.size() == saved_pipes \
		and is_equal_approx(cash, saved_cash),
		"%d buildings, %d pipes, $%.0f" % [buildings.size(), pipes.size(), cash])
	_check("load restores the fleet",
		loaded_ok and int(fleet.get("pickup", 0)) == saved_fleet and fleet_nodes.size() >= 1,
		"%d pickups, %d vehicles" % [int(fleet.get("pickup", 0)), fleet_nodes.size()])
	_check("load restores fleet assignment",
		loaded_ok and fleet_units.size() == saved_fleet and not fleet_units.is_empty() \
		and roads.has(fleet_units[0].cell),
		"%d unit(s) stationed" % fleet_units.size())
	_check("load clears stale run income", comp_income.is_empty())

	# ---- X: the unit loop ----
	var probe_node := Node3D.new()
	add_child(probe_node)
	_face_direction(probe_node, Vector3(1, 0, 0), 0.0, 1.0)
	_check("units face their travel direction",
		absf(wrapf(probe_node.rotation.y - PI * 0.5, -PI, PI)) < 0.05,
		"yaw %.2f" % probe_node.rotation.y)
	probe_node.queue_free()

	var dep_cell := _find_free_area(base + Vector2i(-14, -14), 1)
	var seismic_ok := false
	if dep_cell.x >= 0:
		deposits[dep_cell] = {"amount": 5000.0, "revealed": false, "node": null}
		var seismic_node := _spawn_unit_vehicle("seismic", dep_cell, false)
		fleet_units.append({"kind": "seismic", "cell": dep_cell, "node": seismic_node,
			"job": "seismic", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		selected_unit = fleet_units.size() - 1
		_command_unit(dep_cell)
		_update_units(0.2)
		_update_units(3.5)
		seismic_ok = bool(deposits[dep_cell].revealed)
	_check("seismic vehicle reveals a deposit", seismic_ok,
		"survey at %s" % str(dep_cell))

	var prep_cell := _find_free_area(base + Vector2i(14, -14), 2)
	var prep_ok := false
	if prep_cell.x >= 0:
		var prep_node := _spawn_unit_vehicle("bulldozer", prep_cell, false)
		fleet_units.append({"kind": "bulldozer", "cell": prep_cell, "node": prep_node,
			"job": "prep", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		selected_unit = fleet_units.size() - 1
		_command_unit(prep_cell)
		_update_units(0.2)
		# drive the patrol to completion (prep now takes ~14 s of dozer work)
		for _i in 40:
			if prepared.has(prep_cell):
				break
			_update_units(0.5)
		prep_ok = prepared.has(prep_cell) \
			and _footprint_relief(_cells_for(prep_cell, 2)) < 0.1
	_check("bulldozer prepares a site", prep_ok, "%d prepared cells" % prepared.size())

	# re-commanding the same already-prepared site must not wipe the pad
	var vis_before := prep_visuals.size()
	var redo_ok := false
	if prep_cell.x >= 0 and selected_unit >= 0:
		var pu: Dictionary = fleet_units[selected_unit]
		redo_ok = not _begin_prep(pu) and prep_visuals.size() == vis_before \
			and prepared.has(prep_cell)
	_check("re-preparing a prepared site keeps the dirt", redo_ok,
		"%d pad tiles kept" % prep_visuals.size())

	# structures are built by a builder unit, not placed instantly
	var build_cell := _find_build_area(base + Vector2i(-18, -2), 2)
	var built_ok := false
	if build_cell.x >= 0:
		var crane_node := _spawn_unit_vehicle("crane", build_cell, false)
		fleet_units.append({"kind": "crane", "cell": build_cell, "node": crane_node,
			"job": "build", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		selected_unit = fleet_units.size() - 1
		var before_build := buildings.size()
		_request_build("storage", build_cell)
		var reserved := pending_builds.has(build_cell)
		# the player must assign the crane manually
		_assign_crane_to_site(selected_unit, build_cell)
		for _i in 80:
			_update_units(0.5)
			if buildings.size() > before_build:
				break
		built_ok = reserved and buildings.size() > before_build and not pending_builds.has(build_cell)
	_check("builder unit constructs a structure", built_ok,
		"%d buildings" % buildings.size())

	# multiple cranes build separate sites in parallel (each assigned manually)
	var par1 := _find_build_area(base + Vector2i(-22, 8), 2)
	var par2 := _find_build_area(base + Vector2i(-22, -12), 2)
	var parallel_ok := false
	if par1.x >= 0 and par2.x >= 0:
		var cn1 := _spawn_unit_vehicle("crane", par1, false)
		var i1 := fleet_units.size()
		fleet_units.append({"kind": "crane", "cell": par1, "node": cn1,
			"job": "build", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		var cn2 := _spawn_unit_vehicle("crane", par2, false)
		var i2 := fleet_units.size()
		fleet_units.append({"kind": "crane", "cell": par2, "node": cn2,
			"job": "build", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		var b0 := buildings.size()
		_request_build("storage", par1)
		_request_build("storage", par2)
		_assign_crane_to_site(i1, par1)
		_assign_crane_to_site(i2, par2)
		var queued_two := pending_builds.size() == 2
		for _i in 120:
			_update_units(0.5)
			if buildings.size() >= b0 + 2:
				break
		parallel_ok = queued_two and buildings.size() >= b0 + 2
	_check("multiple cranes build in parallel", parallel_ok,
		"%d buildings" % buildings.size())

	# bulldozer Flatten action levels a 3x3 area back down
	var flat_origin := _find_free_area(base + Vector2i(10, -18), 3)
	var flatten_ok := false
	var before_relief := 0.0
	var after_relief := 0.0
	if flat_origin.x >= 0:
		var flat_cell := flat_origin + Vector2i(1, 1)
		_level_cells([flat_cell], 28.0)
		before_relief = _footprint_relief(_cells_for(flat_origin, 3))
		var dnode := _spawn_unit_vehicle("bulldozer", flat_cell, false)
		fleet_units.append({"kind": "bulldozer", "cell": flat_cell, "node": dnode,
			"job": "prep", "state": "idle", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0})
		selected_unit = fleet_units.size() - 1
		_execute_unit_action(flat_cell, "flatten")
		for _i in 40:
			_update_units(0.5)
			if String(fleet_units[selected_unit].get("state", "")) == "idle" \
					and (fleet_units[selected_unit].get("flat_cells", []) as Array).is_empty():
				break
		after_relief = _footprint_relief(_cells_for(flat_origin, 3))
		flatten_ok = before_relief > 1.0 and after_relief < 0.2
	_check("bulldozer flattens an area", flatten_ok,
		"%.1f -> %.1f m relief" % [before_relief, after_relief])

	var b2 := _find_build_area(base + Vector2i(-14, 14), 2)
	if b2.x >= 0:
		_try_build("base", b2)
	var hauler_ok := false
	var carried := 0.0
	if not _find_base().is_empty() and occupied.has(base) \
			and _role_of(String(occupied[base].kind)) == "producer":
		var hauler_node := _spawn_unit_vehicle("fuel_tanker", base, false)
		var hu := {"kind": "fuel_tanker", "cell": base, "node": hauler_node,
			"job": "hauler", "state": "loading", "target": Vector2i(-1, -1),
			"progress": 0.0, "carry": 0.0, "well": base}
		fleet_units.append(hu)
		var cash_h0 := cash
		var dep_h0 := float(occupied[base].deposit)
		_hauler_loaded(hu)
		carried = float(hu.get("carry", 0.0))
		var haul_loaded_ok := carried > 0.0 and float(occupied[base].deposit) < dep_h0
		_hauler_unloaded(hu)
		hauler_ok = haul_loaded_ok and cash > cash_h0 and float(hu.get("carry", 0.0)) == 0.0
	_check("tanker hauls crude to the base", hauler_ok, "carried %d bbl" % int(carried))

	# ---- CV: calendar + weather (pure domain objects) ----
	var cal := GameCalendar.new(120.0)
	var d0 := cal.day_index()
	cal.advance(120.0)
	_check("calendar advances one day per day-length", cal.day_index() == d0 + 1,
		cal.full_label())
	cal.load_data({"total_days": 0.0, "day_seconds": 120.0})
	var winter := cal.season()
	cal.load_data({"total_days": 90.0, "day_seconds": 120.0})
	_check("calendar maps months to seasons", winter == 0 and cal.season() == 1,
		"%s vs %s" % [GameCalendar.SEASON_NAMES[winter], cal.season_name()])

	var wx := WeatherSystem.new(7)
	var seen := {}
	for i in 200:
		wx.advance(4.0, i % 4, 0.7)
		seen[wx.state] = true
	_check("weather machine visits multiple states", seen.size() >= 3,
		"%d states" % seen.size())
	var storm := WeatherSystem.new(7)
	storm.set_by_name("storm")
	var clear := WeatherSystem.new(7)
	clear.set_by_name("clear")
	_check("weather modifies production and logistics",
		storm.production_factor() < clear.production_factor() \
		and storm.logistics_factor() < clear.logistics_factor(),
		"storm prod %.2f / logi %.2f" % [storm.production_factor(), storm.logistics_factor()])
	_check("pressure drives storm wind",
		storm.pressure_hpa < clear.pressure_hpa - 20.0 \
		and storm.wind_target_ms() > clear.wind_target_ms() + 4.0,
		"%.0f/%.1f vs %.0f/%.1f" % [storm.pressure_hpa, storm.wind_target_ms(),
			clear.pressure_hpa, clear.wind_target_ms()])
	_check("cloud cover reduces solar gain",
		storm.solar_factor() < clear.solar_factor() - 0.2,
		"%.2f vs %.2f" % [storm.solar_factor(), clear.solar_factor()])

	var snowy := WeatherSystem.new(1)
	snowy.set_by_name("snow")
	var rainy := WeatherSystem.new(1)
	rainy.set_by_name("rain")
	_check("precipitation type follows temperature",
		snowy.snow_intensity() > 0.2 and snowy.rain_intensity() == 0.0 \
		and rainy.rain_intensity() > 0.2 and rainy.snow_intensity() == 0.0,
		"snow %.1f @ %.0f°C · rain %.1f @ %.0f°C" % [snowy.snow_intensity(),
			snowy.temperature_c, rainy.rain_intensity(), rainy.temperature_c])
	var wguard := WeatherSystem.new(2)
	_check("unknown weather names are rejected",
		not wguard.set_by_name("lava") and wguard.set_by_name("SNOW"),
		"rejects unknown, accepts case-insensitive names")
	var wsave := storm.save_data()
	var wcopy := WeatherSystem.new(9)
	wcopy.load_data(wsave)
	_check("weather drivers survive a save/load round trip",
		is_equal_approx(wcopy.temperature_c, storm.temperature_c) \
		and is_equal_approx(wcopy.pressure_hpa, storm.pressure_hpa) \
		and is_equal_approx(wcopy.fog, storm.fog),
		"%.0f°C · %.0f hPa" % [wcopy.temperature_c, wcopy.pressure_hpa])

	var wdir := WindSystem.new(11)
	var wind_s0 := wdir.speed
	wdir.advance(8.0, 14.0)
	_check("wind follows the weather target", wdir.speed > wind_s0 and wdir.speed <= 14.0,
		wdir.label())
	var wind_copy := WindSystem.new(5)
	wind_copy.load_data(wdir.save_data())
	_check("wind survives a save/load round trip",
		is_equal_approx(wind_copy.speed, wdir.speed) \
		and is_equal_approx(wind_copy.direction_deg, wdir.direction_deg),
		wind_copy.label())
	var cloud_ok := true
	for st in [WeatherSystem.State.CLEAR, WeatherSystem.State.CLOUDY,
			WeatherSystem.State.STORM, WeatherSystem.State.SNOW]:
		var wtest := WeatherSystem.new(3)
		wtest.set_by_name(WeatherSystem.NAMES[st])
		if st == WeatherSystem.State.CLEAR:
			cloud_ok = cloud_ok and wtest.cloud_cover() < 0.05
		else:
			cloud_ok = cloud_ok and wtest.cloud_cover() > 0.4
	_check("weather exposes cloud cover for the deck", cloud_ok,
		"clear / cloudy / storm / snow")

	# ---- W: bankruptcy closes the loop ----
	won = false
	failed = false
	cash = -300000.0
	debt = 0.0
	paused = false
	_simulate(1.0)
	_check("bankruptcy pauses the field", failed and paused)

	print("=== %d/%d checks passed ===" % [_st_checks - _st_fails, _st_checks])
	get_tree().quit(0 if _st_fails == 0 else 1)


func _save_game() -> void:
	var data := {
		"version": 1,
		"cash": cash, "debt": debt, "time": time, "won": won,
		"buildings": [], "pipes": [], "roads": [], "deposits": [], "fleet": fleet,
		"contract": contract, "contract_timer": contract_timer,
	}
	for b in buildings:
		data["buildings"].append({
			"kind": b.kind, "origin": [b.origin.x, b.origin.y],
			"rot": int(b.get("rot", 0)), "top": float(b.get("top", 0.0)),
			"deposit": float(b.get("deposit", 0.0)), "crude": float(b.get("crude", 0.0)),
			"surveyed": bool(b.get("surveyed", false)),
			"boost": float(b.get("boost", 0.0)), "rate": float(b.get("rate", 0.0)),
			"capacity": float(b.get("capacity", 0.0)),
			"throughput": float(b.get("throughput", 0.0)),
			"yield_bonus": float(b.get("yield_bonus", 0.0)),
			"price_bonus": float(b.get("price_bonus", 0.0)),
		})
	for c in pipes.keys():
		data["pipes"].append([(c as Vector2i).x, (c as Vector2i).y])
	var grades: Array = []
	for c in pipe_grade.keys():
		grades.append([(c as Vector2i).x, (c as Vector2i).y, int(pipe_grade[c])])
	data["pipe_grade"] = grades
	for c in roads.keys():
		data["roads"].append([(c as Vector2i).x, (c as Vector2i).y])
	for c in deposits.keys():
		data["deposits"].append({
			"cell": [(c as Vector2i).x, (c as Vector2i).y],
			"amount": float(deposits[c].amount),
			"revealed": bool(deposits[c].revealed),
		})
	var units: Array = []
	for u in fleet_units:
		var cell: Vector2i = u.cell
		units.append({"kind": String(u.kind), "cell": [cell.x, cell.y]})
	data["fleet_units"] = units
	var prepared_cells: Array = []
	for c in prepared.keys():
		prepared_cells.append([(c as Vector2i).x, (c as Vector2i).y])
	data["prepared"] = prepared_cells
	if calendar != null:
		data["calendar"] = calendar.save_data()
	if weather != null:
		data["weather"] = weather.save_data()
	if wind != null:
		data["wind"] = wind.save_data()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		hud.toast("Could not write save", Color(1, 0.5, 0.4))
		return
	f.store_string(JSON.stringify(data))
	f.close()
	hud.toast("Saved", Color(0.7, 0.9, 0.6))
	Sfx.play("confirm", 1.1)


func _clear_world() -> void:
	for b in buildings:
		var node: Node3D = b.node
		if node != null:
			node.queue_free()
	for c in pipes.keys():
		var pn: Node3D = pipes[c]
		if pn != null:
			pn.queue_free()
	for c in roads.keys():
		var rn: Node3D = roads[c]
		if rn != null:
			rn.queue_free()
	for c in deposits.keys():
		if deposits[c].node != null:
			(deposits[c].node as Node3D).queue_free()
		var dmk = deposits[c].get("marker", null)
		if dmk != null and is_instance_valid(dmk):
			dmk.queue_free()
	for pb in pending_builds.values():
		if pb.get("node") != null and is_instance_valid(pb.node):
			pb.node.queue_free()
		var pv = pb.get("preview", null)
		if pv != null and is_instance_valid(pv):
			pv.queue_free()
		var pfx = pb.get("fx", null)
		if pfx != null and is_instance_valid(pfx):
			pfx.queue_free()
	pending_builds.clear()
	pending_cells.clear()
	for n in fleet_nodes:
		if n != null:
			n.queue_free()
	for u in fleet_units:
		var site = u.get("site", null)
		if site != null and is_instance_valid(site):
			site.queue_free()
		var ppath = u.get("prep_path", null)
		if ppath != null and is_instance_valid(ppath):
			ppath.queue_free()
	_clear_float_texts()
	fleet_nodes.clear()
	fleet_units.clear()
	buildings.clear()
	pipes.clear()
	roads.clear()
	deposits.clear()
	occupied.clear()
	comp_members.clear()
	pipe_comp.clear()
	comp_capacity.clear()
	comp_min_cap.clear()
	comp_boost.clear()
	comp_cells.clear()
	comp_bottleneck.clear()
	comp_relief.clear()
	comp_pressure.clear()
	comp_gas.clear()
	comp_gas_state.clear()
	comp_load.clear()
	comp_util.clear()
	comp_full.clear()
	pipe_grade.clear()
	comp_income.clear()
	comp_income_tick.clear()
	income_rate = 0.0
	_income_accum = 0.0
	_income_timer = 0.0
	road_comp.clear()
	road_served.clear()
	road_capacity.clear()
	road_load.clear()
	road_isolated_cells = 0
	selected_cell = Vector2i(-1, -1)
	prepared.clear()
	for c in prep_visuals.keys():
		var pv: Node3D = prep_visuals[c]
		if pv != null:
			pv.queue_free()
	prep_visuals.clear()
	fleet.clear()
	selected_unit = -1
	pending_action = ""
	if hud != null:
		hud.set_unit_actions("", "", false)
	_update_unit_markers()


func _restore_building(d: Dictionary) -> void:
	var kind := String(d.get("kind", ""))
	var def := _def(kind)
	if def == null:
		return
	var origin := Vector2i(int(d.origin[0]), int(d.origin[1]))
	var cells := _cells_for(origin, def.footprint)
	var top := float(d.get("top", 0.0))
	if top != 0.0:
		_level_cells(cells, top)
	var pos := Vector3(_cell_centre(origin).x, top, _cell_centre(origin).y)
	if def.footprint > 1:
		pos += Vector3(CELL * 0.5, 0, CELL * 0.5)
	var rot := int(d.get("rot", 0))
	var node := _spawn_model(def.model_id, pos, float(rot), true,
		float(def.footprint) * CELL * BUILDING_FIT)
	if node == null:
		return
	buildings_root.add_child(node)
	var cap := def.capacity
	var b := {
		"kind": kind, "name": def.display_name, "cells": cells, "origin": origin,
		"node": node, "comp": -1, "upkeep": def.upkeep, "rot": rot, "top": top,
		"half": _structure_half(node), "height": _structure_height(node),
		"boost": float(d.get("boost", cap.boost if cap != null else 0.0)),
	}
	match def.role:
		"producer":
			b["rate"] = float(d.get("rate", cap.rate if cap != null else 0.0))
			b["deposit"] = float(d.get("deposit", 0.0))
			if deposits.has(origin) and deposits[origin].node != null:
				(deposits[origin].node as Node3D).visible = false
		"buffer":
			b["capacity"] = float(d.get("capacity", cap.volume if cap != null else 0.0))
			b["crude"] = float(d.get("crude", 0.0))
		"consumer":
			b["throughput"] = float(d.get("throughput", cap.feed if cap != null else 0.0))
		"processor":
			b["yield_bonus"] = float(d.get("yield_bonus", cap.yield_bonus if cap != null else 0.0))
		"meter":
			b["price_bonus"] = float(d.get("price_bonus", cap.price_bonus if cap != null else 0.0))
		"survey":
			b["surveyed"] = bool(d.get("surveyed", false))
	buildings.append(b)
	for c in cells:
		occupied[c] = b
	_add_status_marker(b)


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		hud.toast("No save found", Color(1, 0.6, 0.4))
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	_clear_world()
	cash = float(data.get("cash", START_CASH))
	debt = float(data.get("debt", 0.0))
	time = float(data.get("time", 0.0))
	won = bool(data.get("won", false))
	failed = false
	fleet.clear()
	var saved_fleet: Dictionary = data.get("fleet", {})
	for k in saved_fleet.keys():
		fleet[String(k)] = int(saved_fleet[k])
	fleet_units.clear()
	for u in data.get("fleet_units", []):
		var cell := Vector2i(int(u.cell[0]), int(u.cell[1]))
		var k := String(u.kind)
		var d := _def(k)
		var job := d.unit_job if d != null else "logistics"
		fleet_units.append({"kind": k, "cell": cell, "job": job, "state": "idle",
			"target": Vector2i(-1, -1), "progress": 0.0, "carry": 0.0,
			"well": Vector2i(-1, -1)})
	prepared.clear()
	for p in data.get("prepared", []):
		prepared[Vector2i(int(p[0]), int(p[1]))] = true
	if data.has("calendar") and calendar != null:
		calendar.load_data(data["calendar"])
	if data.has("weather") and weather != null:
		weather.load_data(data["weather"])
	if data.has("wind") and wind != null:
		wind.load_data(data["wind"])
	if calendar != null:
		_last_calendar_day = calendar.day_index()
	_apply_daylight()
	_update_weather_visuals()
	var needs_placement := fleet_units.is_empty() and not fleet.is_empty()
	contract = {}
	var saved_contract = data.get("contract", {})
	if saved_contract is Dictionary and not saved_contract.is_empty():
		contract = saved_contract.duplicate()
	contract_timer = float(data.get("contract_timer", 30.0))
	for d in data.get("deposits", []):
		var cell := Vector2i(int(d.cell[0]), int(d.cell[1]))
		deposits[cell] = {"amount": float(d.amount), "revealed": false, "node": null}
		if bool(d.revealed):
			_reveal(cell)
	for d in data.get("buildings", []):
		_restore_building(d)
	pipe_grade.clear()
	for g in data.get("pipe_grade", []):
		pipe_grade[Vector2i(int(g[0]), int(g[1]))] = int(g[2])
	for p in data.get("pipes", []):
		var cell := Vector2i(int(p[0]), int(p[1]))
		pipes[cell] = _spawn_tile("pipe", cell)
	for r in data.get("roads", []):
		var cell := Vector2i(int(r[0]), int(r[1]))
		roads[cell] = _spawn_tile("road", cell)
	_rebuild_components()
	if needs_placement:
		# older saves stored counts only; station those units on the restored roads
		var road_cells := roads.keys()
		for k in fleet.keys():
			for i in int(fleet[k]):
				if road_cells.is_empty():
					break
				fleet_units.append({"kind": String(k),
					"cell": road_cells[randi() % road_cells.size()]})
		_rebuild_components()
	for c in prepared.keys():
		_add_prep_patch([c], _cell_max_height(c))
	_respawn_fleet()
	_update_ghost()
	hud.clear_victory()
	hud.clear_game_over()
	hud.hide_start_overlay()
	paused = false
	Sfx.enable()
	hud.toast("Loaded", Color(0.7, 0.9, 0.6))
	Sfx.play("confirm", 1.1)
	return true


func _load_models() -> void:
	var ids: Array = []
	for e in catalogue.entries:
		if e.model_id != "" and not ids.has(e.model_id):
			ids.append(e.model_id)
	for t in TILE_MODEL_IDS:
		if not ids.has(t):
			ids.append(t)
	for id in ids:
		var path := "res://assets/models/%s.glb" % id
		if ResourceLoader.exists(path):
			MODEL_SCENES[id] = load(path)
		else:
			push_warning("Missing model: " + path)
	for id in PROP_IDS:
		var pp := "res://assets/models/props/%s.glb" % id
		if ResourceLoader.exists(pp):
			PROP_SCENES.append(load(pp))
			PROP_SCENE_IDS.append(String(id))


func _build_world() -> void:
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)

	buildings_root = Node3D.new()
	pipes_root = Node3D.new()
	roads_root = Node3D.new()
	markers_root = Node3D.new()
	world_root.add_child(buildings_root)
	world_root.add_child(pipes_root)
	world_root.add_child(roads_root)
	world_root.add_child(markers_root)

	# ---- terrain ----------------------------------------------------------- #
	# Domain-warped fBm + ridged mountains + carved rivers + eroded detail,
	# mapped to soft biomes, plus a HeightMapShape3D collider.
	var _t0 := Time.get_ticks_msec()
	terrain = OilTerrainGen.generate(1337, 352, 2.0)
	print("Terrain generated in %d ms" % (Time.get_ticks_msec() - _t0))
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = OilTerrainGen.build_mesh(terrain)
	var tmat := StandardMaterial3D.new()
	var ttex: Texture2D = load("res://assets/textures/ground_terrain.png")
	if ttex != null:
		tmat.albedo_texture = ttex
	tmat.vertex_color_use_as_albedo = true
	tmat.albedo_color = Color(1, 1, 1)
	tmat.roughness = 1.0
	tmat.metallic = 0.0
	tmat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = tmat
	world_root.add_child(mi)
	terrain_mesh_inst = mi
	var tbody := OilTerrainGen.build_body(terrain)
	world_root.add_child(tbody)
	terrain_body = tbody
	terrain_shape = tbody.get_child(0).shape as HeightMapShape3D

	# sea level plane: low continental areas read as water, high ground stays dry
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sea_mesh := PlaneMesh.new()
	var sea_extent := terrain.world_size() + 240.0
	sea_mesh.size = Vector2(sea_extent, sea_extent)
	sea.mesh = sea_mesh
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.07, 0.30, 0.44, 0.72)
	sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea_mat.roughness = 0.12
	sea_mat.metallic = 0.15
	sea_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sea.material_override = sea_mat
	sea.position = Vector3(0.0, terrain.sea_level + 0.08, 0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(sea)

	# Terrain3D draws the visible ground, importing the exact heightmap the
	# gameplay queries, so props, roads and pipes sit on the real surface.
	terrain3d = null
	if ClassDB.class_exists("Terrain3D"):
		_build_terrain3d()
		if terrain3d != null:
			mi.visible = false


	# sun
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -38, 0)
	sun.light_energy = 1.02
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 350.0
	world_root.add_child(sun)
	sun_light = sun

	# Cloud shadows are drawn by a soft world-anchored shadow plane below.

	var env := WorldEnvironment.new()
	var e := Environment.new()

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/cloudy_sky.gdshader")
	sky_mat.set_shader_parameter("cloud_tex", load("res://assets/textures/clouds.png"))
	sky_mat.set_shader_parameter("sky_top", Color(0.24, 0.34, 0.46))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.68, 0.70, 0.58))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.58)
	e.ambient_light_energy = 0.26
	e.ssao_enabled = true
	e.ssao_radius = 2.0
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.fog_enabled = false
	e.fog_light_color = Color(0.66, 0.70, 0.62)
	e.fog_depth_begin = 900.0
	e.fog_depth_end = 2400.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment = e
	add_child(env)
	world_env = e
	sky_mat_ref = sky_mat


## Proven 2D rain/snow addon, overhead cloud layer and soft ground shadows.
func _build_weather_fx() -> void:
	# subtle overhead cloud layer (white puffs) and soft ground shadows
	cloud_deck = _make_weather_plane(42.0, "res://shaders/cloud_deck.gdshader")
	var dmat := cloud_deck.material_override as ShaderMaterial
	if dmat != null:
		dmat.set_shader_parameter("cloud_tex", load("res://assets/textures/clouds.png"))
	world_root.add_child(cloud_deck)

	var shadow_tex := NoiseTexture2D.new()
	shadow_tex.width = 512
	shadow_tex.height = 512
	shadow_tex.seamless = true
	shadow_tex.generate_mipmaps = true
	var sn := FastNoiseLite.new()
	sn.seed = 99
	sn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	sn.fractal_type = FastNoiseLite.FRACTAL_FBM
	sn.fractal_octaves = 3
	sn.frequency = 0.006
	shadow_tex.noise = sn
	cloud_shadow = _make_weather_plane(32.0, "res://shaders/cloud_shadow.gdshader")
	var cmat := cloud_shadow.material_override as ShaderMaterial
	if cmat != null:
		cmat.set_shader_parameter("noise_tex", shadow_tex)
	world_root.add_child(cloud_shadow)
	rain_splash = _make_splash()
	world_root.add_child(rain_splash)

	# Weather FX Free (CC BY 4.0) — tested rain/snow shaders that cover the view
	weather_layer = CanvasLayer.new()
	weather_layer.name = "WeatherFX"
	weather_layer.layer = 0
	add_child(weather_layer)
	weather_rain = WeatherFX.add(weather_layer, "rain", {
		"density": 0.0,
		"wind": 0.2,
		"drop_length": 30.0,
		"fall_speed": 1.0,
		"splashes": 0.8,
		"ground": 1.0,
		"color": Color(0.74, 0.82, 0.96, 0.55),
	})
	weather_snow = WeatherFX.add(weather_layer, "snow", {
		"density": 0.0,
		"wind": 0.2,
		"flake_size": 3.5,
		"fall_speed": 1.0,
		"drift": 0.6,
		"color": Color(1.0, 1.0, 1.0, 0.9),
	})
	weather_rain.visible = false
	weather_snow.visible = false


func _make_weather_plane(height: float, shader_path: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1100.0, 1100.0)
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	mi.material_override = mat
	mi.position = Vector3(0.0, height, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Ground splashes so rain visibly hits the ground and structures.
func _make_splash() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 520
	p.lifetime = 0.55
	p.preprocess = 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(62.0, 0.2, 62.0)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 80.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.78, 0.86, 0.98, 0.65)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = mat
	p.mesh = quad
	return p


## Wind-blown dust / leaf flecks, so wind reads even in clear weather.
func _make_wind_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = true
	p.amount = 120
	p.lifetime = 4.5
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(150.0, 14.0, 150.0)
	p.direction = Vector3(1.0, 0.0, 0.0)
	p.spread = 12.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -0.25, 0.0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.78, 0.72, 0.55, 0.38)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.06)
	quad.material = mat
	p.mesh = quad
	return p


func _make_precip(is_rain: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = false
	p.amount = 900 if is_rain else 520
	p.lifetime = 1.4 if is_rain else 5.0
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(72.0, 18.0, 72.0)
	p.direction = Vector3(0.10, -1.0, 0.04)
	p.spread = 6.0
	p.initial_velocity_min = 16.0 if is_rain else 1.5
	p.initial_velocity_max = 24.0 if is_rain else 3.5
	p.gravity = Vector3(0.0, -9.8, 0.0) if is_rain else Vector3(0.0, -0.6, 0.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.70, 0.80, 0.95, 0.62) if is_rain else Color(0.98, 0.99, 1.0, 0.92)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.85) if is_rain else Vector2(0.20, 0.20)
	quad.material = mat
	p.mesh = quad
	return p


## Sun, ambient and sky follow the calendar and the current weather.
func _apply_daylight() -> void:
	if calendar == null or sun_light == null:
		return
	var day := calendar.daylight()
	var solar := weather.solar_factor() if weather != null else 1.0
	var cloud := weather.cloud_cover() if weather != null else 0.0
	sun_light.rotation_degrees = calendar.sun_rotation_deg()
	sun_light.light_energy = lerpf(0.16, 1.10, day) * clampf(solar, 0.48, 1.15)
	var h := calendar.hour_float()
	var dawn_dusk := clampf(minf(absf(h - 6.0), absf(h - 18.0)) / 5.0, 0.0, 1.0)
	var warm := 1.0 - dawn_dusk
	sun_light.light_color = Color(1.0, lerpf(0.95, 0.70, warm), lerpf(0.85, 0.42, warm))
	if world_env != null:
		world_env.ambient_light_energy = lerpf(0.22, 0.30, day) * (1.0 - cloud * 0.10)
		world_env.ambient_light_color = Color(0.62, 0.66, 0.58).lerp(
			Color(0.30, 0.38, 0.52), 1.0 - day)
	if sky_mat_ref != null:
		var top := Color(0.24, 0.34, 0.46).lerp(Color(0.04, 0.06, 0.12), 1.0 - day)
		var hor := Color(0.68, 0.70, 0.58).lerp(Color(0.14, 0.16, 0.22), 1.0 - day)
		top = top.lerp(Color(0.32, 0.35, 0.38), cloud * 0.6)
		hor = hor.lerp(Color(0.46, 0.48, 0.48), cloud * 0.6)
		sky_mat_ref.set_shader_parameter("sky_top", top)
		sky_mat_ref.set_shader_parameter("sky_horizon", hor)
		sky_mat_ref.set_shader_parameter("coverage", cloud)
		sky_mat_ref.set_shader_parameter("brightness", 0.20 + 0.62 * day)
		var wv := wind.vector() if wind != null else Vector3.ZERO
		sky_mat_ref.set_shader_parameter("wind", Vector2(wv.x, wv.z))


func _update_weather_visuals() -> void:
	if weather == null:
		return
	var centre := Vector3.ZERO
	if camera != null:
		centre = camera.target
	var rain := weather.rain_intensity()
	var snow := weather.snow_intensity()
	var cloud := weather.cloud_cover()
	var wind_v := wind.vector() if wind != null else Vector3.ZERO

	# Weather FX Free: proven rain/snow shaders (density, wind, fall speed)
	if weather_rain != null:
		weather_rain.visible = rain > 0.02
		weather_rain.set_param(&"density", clampf(rain * 0.9, 0.0, 1.0))
		weather_rain.set_param(&"wind", clampf(wind_v.x / 14.0, -1.0, 1.0))
		weather_rain.set_param(&"fall_speed",
			1.0 + clampf(wind_v.length() / 24.0, 0.0, 0.6))
	if weather_snow != null:
		weather_snow.visible = snow > 0.02
		weather_snow.set_param(&"density", clampf(snow * 0.9, 0.0, 1.0))
		weather_snow.set_param(&"wind", clampf(wind_v.x / 14.0, -1.0, 1.0))
		weather_snow.set_param(&"fall_speed", 1.0)

	# visible clouds, moving cloud shadows and a snow dusting layer
	var ground := _terrain_height(centre.x, centre.z)
	if cloud_deck != null:
		# overhead puffs only make sense in the 3D/orbit view
		cloud_deck.visible = camera != null and not camera.is_classic()
		cloud_deck.global_position = Vector3(centre.x, maxf(40.0, ground + 22.0), centre.z)
		_set_cloud_layer(cloud_deck, Color(1.0, 1.0, 1.0),
			clampf(cloud * 0.10, 0.0, 0.10), maxf(0.05, cloud), 0.0035, wind_v)
	if cloud_shadow != null:
		cloud_shadow.global_position = Vector3(centre.x, maxf(30.0, ground + 14.0), centre.z)
		_set_cloud_layer(cloud_shadow, Color(0.02, 0.03, 0.05),
			clampf(cloud * 0.06, 0.0, 0.07), maxf(0.15, cloud), 0.0016, wind_v)
	if snow_cover != null:
		snow_cover.global_position = Vector3(centre.x, maxf(35.0, ground + 19.0), centre.z)
		_set_cloud_layer(snow_cover, Color(0.96, 0.98, 1.0),
			clampf(snow * 0.62, 0.0, 0.62), 0.84, 0.0060, wind_v)

	# drifting dust so wind is visible even in clear weather
	if wind_fx != null:
		wind_fx.global_position = centre + Vector3(0.0, 14.0, 0.0)
		var wspeed := wind_v.length()
		wind_fx.emitting = wspeed > 3.5
		if wspeed > 0.1:
			wind_fx.direction = Vector3(wind_v.x, 0.0, wind_v.z).normalized()
		wind_fx.initial_velocity_min = maxf(2.0, wspeed * 0.5)
		wind_fx.initial_velocity_max = maxf(4.0, wspeed)
		wind_fx.amount = int(clampf(40.0 + wspeed * 14.0, 40.0, 320.0))
	# vegetation sway
	var now := Time.get_ticks_msec() / 1000.0
	var sway := clampf(wind_v.length() / 16.0, 0.0, 1.0)
	for prop in sway_props:
		if prop == null or not is_instance_valid(prop):
			continue
		var ph := float(prop.get_meta("sway_phase", 0.0))
		var amp := 0.030 + sway * 0.14
		prop.rotation.z = sin(now * 1.6 + ph) * amp
		prop.rotation.x = cos(now * 1.2 + ph) * amp * 0.6

	# rain hitting the ground / pads
	if rain_splash != null:
		rain_splash.global_position = Vector3(centre.x, ground + 0.35, centre.z)
		rain_splash.emitting = rain > 0.2


func _set_cloud_layer(mi: MeshInstance3D, tint: Color, opacity: float,
		coverage: float, noise_scale: float, wind_v: Vector3) -> void:
	var mat := mi.material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("coverage", coverage)
	mat.set_shader_parameter("wind", Vector2(wind_v.x, wind_v.z))
	mat.set_shader_parameter("scale", noise_scale)


## Animate the directional-light cloud cookie; shadow strength tracks cover.
func _update_cloud_shadow(delta: float) -> void:
	_cloud_shadow_t += delta
	if _cloud_shadow_t < 0.25:
		return
	_cloud_shadow_t = 0.0
	if sun_cloud_noise == null or weather == null:
		return
	var w := wind.vector() if wind != null else Vector3.ZERO
	sun_cloud_noise.offset = Vector3(
		sun_cloud_noise.offset.x + w.x * 0.02,
		0.0,
		sun_cloud_noise.offset.z + w.z * 0.02)
	var shade := clampf(weather.cloud_cover(), 0.0, 1.0)
	if sun_cloud_ramp != null and absf(shade - _cloud_shade) > 0.02:
		_cloud_shade = shade
		sun_cloud_ramp.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0).lerp(Color(0.70, 0.70, 0.70), shade),
			Color(1.0, 1.0, 1.0).lerp(Color(0.35, 0.35, 0.35), shade)])


const T3D_VERTS := 128         # vertices per region edge
const T3D_SPACING := 2.0       # metres between vertices (matches OilTerrain cell)
const T3D_REGION_M := 256.0    # T3D_VERTS * T3D_SPACING
const T3D_HEIGHT_SCALE := 96.0 # R8 height 0..1 maps to 0..96 m

var terrain3d = null
var terrain: OilTerrain
var terrain_body: StaticBody3D
var terrain_shape: HeightMapShape3D
var terrain_mesh_inst: MeshInstance3D
var _last_grade_warn := -10.0


func _build_terrain3d() -> void:
	var t = ClassDB.instantiate("Terrain3D")
	t.name = "Terrain3D"
	t.region_size = T3D_VERTS
	t.vertex_spacing = T3D_SPACING
	t.assets = _terrain3d_assets()
	world_root.add_child(t)

	# Terrain3D's region grid is anchored at world 0 and each region is
	# T3D_REGION_M wide, so the lease (-HALF..HALF) needs -2..1 on both axes.
	var reach := int(ceil(HALF / T3D_REGION_M))
	for rz in range(-reach, reach):
		for rx in range(-reach, reach):
			var imgs := _terrain3d_region(rx, rz)
			t.data.import_images(imgs, Vector3(rx * T3D_REGION_M, 0.0, rz * T3D_REGION_M), 0.0, T3D_HEIGHT_SCALE)

	var hr: Vector2 = t.data.get_height_range()
	if not (is_finite(hr.x) and is_finite(hr.y)) or hr.y - hr.x < 0.5:
		push_warning("Terrain3D import produced no heights, keeping mesh terrain")
		t.queue_free()
		return
	terrain3d = t
	print("Terrain3D active: ", reach * 2, "x", reach * 2, " regions, heights ", hr)


## Height + baked control map (biome base/overlay + rock) for one 256 m region.
func _terrain3d_region(rx: int, rz: int) -> Array:
	var n := terrain.resolution
	var cs := terrain.cell_size
	var count := T3D_VERTS * T3D_VERTS
	var hbytes := PackedByteArray()
	hbytes.resize(count)
	var cvals := PackedFloat32Array()
	cvals.resize(count)
	var scratch := PackedByteArray()
	scratch.resize(4)

	for pz in T3D_VERTS:
		for px in T3D_VERTS:
			var wx := float(rx) * T3D_REGION_M + float(px) * T3D_SPACING
			var wz := float(rz) * T3D_REGION_M + float(pz) * T3D_SPACING
			var gx := clampi(int(round((wx + HALF) / cs)), 0, n - 1)
			var gz := clampi(int(round((wz + HALF) / cs)), 0, n - 1)
			var i := pz * T3D_VERTS + px
			var h := terrain.heights[gz * n + gx]
			hbytes[i] = int(clampf(h / T3D_HEIGHT_SCALE, 0.0, 1.0) * 255.0)

			# biome base/overlay from the generator, plus rock on steep/high
			# ground so cliffs and mountains always read as stone
			var gi := gz * n + gx
			var base_id := OilTerrain.BIOME_GRASS
			var overlay_id := OilTerrain.BIOME_ROCK
			var blend := 0.0
			if terrain.biomes.size() == n * n:
				base_id = int(terrain.biomes[gi])
			if terrain.biome_overlay.size() == n * n:
				overlay_id = int(terrain.biome_overlay[gi])
			if terrain.biome_blend.size() == n * n:
				blend = terrain.biome_blend[gi]
			var sx := (terrain.heights[gz * n + mini(gx + 1, n - 1)] - terrain.heights[gz * n + maxi(gx - 1, 0)]) / (2.0 * cs)
			var sz := (terrain.heights[mini(gz + 1, n - 1) * n + gx] - terrain.heights[maxi(gz - 1, 0) * n + gx]) / (2.0 * cs)
			var rock := maxf(
				clampf((sqrt(sx * sx + sz * sz) - 0.85) / 0.75, 0.0, 1.0),
				clampf((h - 52.0) / 8.0, 0.0, 1.0)
			)
			if rock > blend and base_id != OilTerrain.BIOME_ROCK:
				overlay_id = OilTerrain.BIOME_ROCK
				blend = rock
			if base_id == overlay_id:
				blend = 0.0
			# Terrain3D control map: bits 27-31 base id, 22-26 overlay id, 14-21 blend.
			scratch.encode_u32(0, (base_id << 27) | (overlay_id << 22) | (int(clampf(blend, 0.0, 1.0) * 255.0) << 14))
			cvals[i] = scratch.decode_float(0)

	var himg := Image.create_from_data(T3D_VERTS, T3D_VERTS, false, Image.FORMAT_R8, hbytes)
	var cimg := Image.create_from_data(T3D_VERTS, T3D_VERTS, false, Image.FORMAT_RF, cvals.to_byte_array())
	return [himg, cimg, null]


func _terrain3d_assets() -> Resource:
	var assets = ClassDB.instantiate("Terrain3DAssets")

	var grass = ClassDB.instantiate("Terrain3DTextureAsset")
	grass.name = "Grass"
	grass.id = 0
	grass.albedo_texture = load("res://assets/textures/terrain3d/ground037_alb_ht.png")
	grass.normal_texture = load("res://assets/textures/terrain3d/ground037_nrm_rgh.png")
	grass.albedo_color = Color(0.44, 0.54, 0.37)
	grass.uv_scale = 0.11
	grass.detiling_rotation = 0.161
	assets.set_texture_asset(0, grass)

	var rock = ClassDB.instantiate("Terrain3DTextureAsset")
	rock.name = "Rock"
	rock.id = 1
	rock.albedo_texture = load("res://assets/textures/terrain3d/rock_hill_alb.png")
	rock.normal_texture = load("res://assets/textures/terrain3d/rock_hill_nrm.png")
	rock.uv_scale = 0.07
	rock.albedo_color = Color(0.72, 0.70, 0.64)
	rock.detiling_rotation = 0.31
	rock.normal_depth = 1.0
	rock.displacement_scale = 0.0
	assets.set_texture_asset(1, rock)

	var sand = ClassDB.instantiate("Terrain3DTextureAsset")
	sand.name = "Sand"
	sand.id = 2
	sand.albedo_texture = load("res://assets/textures/terrain3d/sand_alb.png")
	if sand.albedo_texture == null:
		sand.albedo_texture = rock.albedo_texture
	sand.albedo_color = Color(0.92, 0.85, 0.70)
	sand.uv_scale = 0.12
	sand.detiling_rotation = 0.27
	assets.set_texture_asset(2, sand)

	var mud = ClassDB.instantiate("Terrain3DTextureAsset")
	mud.name = "Mud"
	mud.id = 3
	mud.albedo_texture = load("res://assets/textures/terrain3d/mud_alb.png")
	if mud.albedo_texture == null:
		mud.albedo_texture = grass.albedo_texture
	mud.albedo_color = Color(0.64, 0.59, 0.51)
	mud.uv_scale = 0.16
	mud.detiling_rotation = 0.11
	assets.set_texture_asset(3, mud)
	return assets


func _terrain_height(x: float, z: float) -> float:
	if terrain != null:
		return terrain.height_at(x, z)
	return 0.0


func _grid_texture() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 64:
		img.set_pixel(i, 0, Color(0.05, 0.06, 0.04, 0.45))
		img.set_pixel(0, i, Color(0.05, 0.06, 0.04, 0.45))
	return ImageTexture.create_from_image(img)


func _decorate() -> void:
	if PROP_SCENES.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centre := Vector2i(GRID / 2, GRID / 2)
	var decor := Node3D.new()
	world_root.add_child(decor)
	for i in 420:
		var c := Vector2i(rng.randi_range(0, GRID - 1), rng.randi_range(0, GRID - 1))
		if (c - centre).length() < 4.0:
			continue
		var near_base := false
		for slot in BASE_SLOTS:
			if (c - (centre + (slot as Vector2i))).length() < 3.0:
				near_base = true
				break
		if near_base or _is_water_cell(c) or deposits.has(c):
			continue
		var idx := rng.randi_range(0, PROP_SCENES.size() - 1)
		var scene: PackedScene = PROP_SCENES[idx]
		var n: Node3D = scene.instantiate()
		n.position = cell_to_world(c) + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
		n.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		var s := rng.randf_range(2.5, 5.0)
		n.scale = Vector3(s, s, s)
		var pid: String = PROP_SCENE_IDS[idx] if idx < PROP_SCENE_IDS.size() else ""
		if pid.contains("tree") or pid.contains("plant") or pid.contains("grass"):
			n.set_meta("sway_phase", rng.randf_range(0.0, TAU))
			sway_props.append(n)
		decor.add_child(n)


func _road_material() -> StandardMaterial3D:
	if road_mat == null:
		road_mat = StandardMaterial3D.new()
		road_mat.albedo_texture = load("res://assets/textures/road_asphalt.png")
		road_mat.albedo_color = Color(0.62, 0.62, 0.65)
		road_mat.uv1_triplanar = true
		road_mat.uv1_scale = Vector3(0.14, 0.14, 0.14)
		road_mat.roughness = 1.0
	return road_mat


func _pipe_material() -> StandardMaterial3D:
	if pipe_mat == null:
		pipe_mat = StandardMaterial3D.new()
		pipe_mat.albedo_color = Color(0.85, 0.68, 0.14)
		pipe_mat.roughness = 0.55
	return pipe_mat


## Grade tint: standard keeps the metal look, trunk is blue, HP is orange.
func _pipe_grade_material(grade: int) -> StandardMaterial3D:
	if _pipe_grade_mats.has(grade):
		return _pipe_grade_mats[grade]
	var m := StandardMaterial3D.new()
	match grade:
		1:
			m.albedo_color = Color(0.30, 0.55, 0.82)
		2:
			m.albedo_color = Color(0.92, 0.48, 0.16)
		_:
			m.albedo_color = Color(0.85, 0.68, 0.14)
	m.roughness = 0.45
	m.metallic = 0.3
	_pipe_grade_mats[grade] = m
	return m


func _apply_pipe_grade(cell: Vector2i, node: Node3D) -> void:
	var g := int(pipe_grade.get(cell, 0))
	if g <= 0:
		return
	var mat := _pipe_grade_material(g)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat


## Total pipe upkeep across all cells (grade-dependent).
func _pipe_upkeep_total() -> float:
	var total := 0.0
	for c in pipes.keys():
		total += catalogue.pipe_grade_upkeep(int(pipe_grade.get(c, 0)))
	return total


## Upkeep of one pipe run.
func _run_pipe_upkeep(root: int) -> float:
	var total := 0.0
	for c in pipes.keys():
		if int(pipe_comp.get(c, -1)) == root:
			total += catalogue.pipe_grade_upkeep(int(pipe_grade.get(c, 0)))
	return total


func _apron_material() -> StandardMaterial3D:
	if apron_mat == null:
		apron_mat = StandardMaterial3D.new()
		apron_mat.albedo_color = Color(0.58, 0.58, 0.55)
		apron_mat.roughness = 0.95
	return apron_mat


## World point of a structure pivot (footprint centre), from its origin cell.
func _building_centre(b: Dictionary) -> Vector2:
	var def := _def(b.kind)
	var size := def.footprint if def != null else 1
	var c := _cell_centre(b.origin)
	if size > 1:
		c += Vector2(CELL * 0.5, CELL * 0.5)
	return c


## Half-extents of the spawned model, measured on the pivot. Derived from the
## actual mesh bounds, so round tanks and boxy skids both report their silhouette.
func _structure_half(node: Node3D) -> Vector2:
	var inst := node.get_child(0) as Node3D
	if inst == null:
		return Vector2.ZERO
	var box := _model_aabb(inst)
	return Vector2(box.size.x * inst.scale.x, box.size.z * inst.scale.z) * 0.5


func _structure_height(node: Node3D) -> float:
	var inst := node.get_child(0) as Node3D
	if inst == null:
		return 0.0
	return _model_aabb(inst).size.y * inst.scale.y


## Billboard warning above a structure ("ROAD", "PIPE", "TANK", "IDLE").
## Management at a glance: problems are visible without opening the inspector.
func _add_status_marker(b: Dictionary) -> void:
	var node: Node3D = b.node
	if node == null:
		return
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.font_size = 40
	l.pixel_size = 0.045
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.06, 0.04, 0.9)
	l.modulate = Color(1, 1, 1, 0)
	l.text = ""
	l.position = Vector3(0.0, float(b.get("height", 6.0)) + 2.4, 0.0)
	node.add_child(l)
	b["marker"] = l


func _update_status_markers() -> void:
	for b in buildings:
		var l: Label3D = b.get("marker")
		if l == null:
			continue
		var text := ""
		var col := Color(1, 1, 1, 0)
		match _status_of(b):
			"no road access":
				text = "ROAD"
				col = Color(1.0, 0.45, 0.35)
			"not connected":
				text = "PIPE"
				col = Color(1.0, 0.5, 0.35)
			"no storage in network":
				text = "TANK"
				col = Color(1.0, 0.85, 0.4)
			"idle":
				text = "IDLE"
				col = Color(1.0, 0.85, 0.4)
		if l.text != text:
			l.text = text
		l.modulate = col


## Silhouette reach from the pivot toward the world side `d`.
func _building_reach(b: Dictionary, d: Vector2i) -> float:
	var def := _def(b.kind)
	var half: Vector2 = b.get("half", Vector2.ZERO)
	if half == Vector2.ZERO:
		var size := float(def.footprint if def != null else 1)
		half = Vector2.ONE * (size * CELL * BUILDING_FIT * 0.5)
	var steps := int(round(float(b.get("rot", 0.0)) / 90.0)) % 4
	var even := steps % 2 == 0
	if d.x != 0:
		return half.x if even else half.y
	return half.y if even else half.x


## Span of the joint, in metres from the pipe cell centre toward `d`:
## x = where the connector leaves the pipe tile, y = where it meets the structure.
## Shared by the renderer and the rule tests, so preview and build cannot drift.
func _connector_span(cell: Vector2i, b: Dictionary, d: Vector2i) -> Vector2:
	var pc := _cell_centre(cell)
	var bc := _building_centre(b)
	var dist := absf(bc.x - pc.x) if d.x != 0 else absf(bc.y - pc.y)
	var end := dist - _building_reach(b, d) + PORT_JOINT
	return Vector2(CELL * 0.5 - 0.5, end)


## Short stub from a pipe tile into an adjacent building, so the run visibly
## plugs in. The length comes from the structure's real silhouette, not from a
## fixed grid offset, so 1x1 and 2x2 sites join identically.
func _add_pipe_connectors(pivot: Node3D, cell: Vector2i, rot_deg: float) -> void:
	var inv := Basis(Vector3.UP, -deg_to_rad(rot_deg))
	var pipe_y := pivot.position.y + PIPE_AXIS_Y
	for d in DIRS:
		var nb: Vector2i = cell + d
		if not occupied.has(nb):
			continue
		var b: Dictionary = occupied[nb]
		# the structure's port facing this pipe is the opposite of `d`
		if (_building_port_mask(b) & _side_bit(-d)) == 0:
			continue
		var span := _connector_span(cell, b, d)
		if span.y <= span.x + 0.05:
			continue
		var local := inv * Vector3(d.x, 0.0, d.y)
		# horizontal spool into the structure, at pipe centreline height
		_add_pipe_segment(pivot, local, (span.x + span.y) * 0.5,
			pipe_y - pivot.position.y, span.y - span.x, false)
		# riser/sleeve at the wall: hides any pad-height difference so the joint
		# always reads as "pipe enters nozzle", never as a floating stub
		var pad := float(b.get("top", pivot.position.y))
		var riser := maxf(0.4, pipe_y - pad + 0.3)
		_add_pipe_segment(pivot, local, span.y - 0.12, pad + riser * 0.5 - pivot.position.y,
			riser, true)


## Vertical sleeve where two adjacent pipe cells sit at different heights, so a
## run over rolling ground reads as one continuous pipe instead of floating steps.
func _add_pipe_sleeves(pivot: Node3D, cell: Vector2i) -> void:
	var here := _cell_max_height(cell) + PIPE_AXIS_Y
	for d in DIRS:
		var nb: Vector2i = cell + d
		if not pipes.has(nb):
			continue
		# exactly one sleeve per neighbour pair
		if nb.x < cell.x or (nb.x == cell.x and nb.y < cell.y):
			continue
		var other := _cell_max_height(nb) + PIPE_AXIS_Y
		var diff := absf(other - here)
		if diff < 0.12:
			continue
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.55
		cyl.bottom_radius = 0.55
		cyl.height = diff + 0.8
		cyl.radial_segments = 10
		cyl.rings = 1
		mi.mesh = cyl
		mi.material_override = _pipe_material()
		mi.position = Vector3(
			float(d.x) * CELL * 0.5,
			(here + other) * 0.5 - pivot.position.y,
			float(d.y) * CELL * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)


func _add_pipe_segment(pivot: Node3D, local_dir: Vector3, offset: float, y: float,
		length: float, vertical: bool) -> void:
	if length <= 0.02:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = _pipe_material()
	mi.position = local_dir * offset + Vector3(0.0, y, 0.0)
	if not vertical:
		if absf(local_dir.x) > 0.5:
			mi.rotation_degrees.z = 90.0
		else:
			mi.rotation_degrees.x = 90.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)


## Concrete apron from a road tile to each adjacent structure. Roads grant
## access by adjacency; the apron makes that access visible instead of leaving
## the building floating beside an asphalt strip.
func _add_road_connectors(pivot: Node3D, cell: Vector2i, rot_deg: float) -> void:
	var inv := Basis(Vector3.UP, -deg_to_rad(rot_deg))
	for d in DIRS:
		var nb: Vector2i = cell + d
		if not occupied.has(nb):
			continue
		var b: Dictionary = occupied[nb]
		var local := inv * Vector3(d.x, 0.0, d.y)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 0.07, 2.2)
		mi.mesh = box
		mi.material_override = _apron_material()
		var pad := float(b.get("top", pivot.position.y))
		mi.position = local * (CELL * 0.5 + 0.45) \
			+ Vector3(0.0, maxf(pad, pivot.position.y) - pivot.position.y + 0.05, 0.0)
		if absf(local.x) > 0.5:
			mi.rotation_degrees.y = 90.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/rts_camera.gd"))
	camera.position = Vector3(0, 120, 200)
	add_child(camera)
	camera.current = true
	# Terrain3D picks clipmap/LOD levels from `clipmap_target`; point it at the
	# active camera so the orthographic view keeps a sharp terrain.
	if terrain3d != null:
		terrain3d.clipmap_target = camera


func _build_hud() -> void:
	hud = load("res://scripts/hud.gd").new()
	hud.register_catalogue(catalogue.entries)
	add_child(hud)
	hud.tool_selected.connect(_on_tool_selected)
	hud.bulldoze_selected.connect(_on_bulldoze)
	hud.loan_requested.connect(_on_loan)
	hud.speed_selected.connect(_on_speed)
	hud.difficulty_selected.connect(_on_difficulty)
	hud.victory_dismissed.connect(_on_victory_dismissed)
	hud.run_selected.connect(_on_run_selected)
	hud.minimap_target.connect(_on_minimap_target)
	hud.unit_action.connect(_on_unit_action)
	hud.restart_requested.connect(_on_restart)
	hud.show_start_overlay()
	paused = true


func _build_ghost() -> void:
	ghost = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CELL - 2.0, CELL - 2.0)
	ghost.mesh = q
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.35, 0.9, 0.45, 0.35)
	ghost_mat.no_depth_test = false
	ghost.material_override = ghost_mat
	ghost.rotation_degrees.x = -90
	ghost.visible = false
	add_child(ghost)


func _build_port_hint() -> void:
	port_mesh = ImmediateMesh.new()
	port_preview = MeshInstance3D.new()
	port_preview.mesh = port_mesh
	port_mat = StandardMaterial3D.new()
	port_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	port_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	port_mat.vertex_color_use_as_albedo = true
	port_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	port_preview.material_override = port_mat
	port_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(port_preview)


## Green strip = the structure accepts a pipe there; red = it does not.
func _update_port_hint() -> void:
	if port_mesh == null:
		return
	port_mesh.clear_surfaces()
	if bulldoze:
		return
	if tool == "pipe":
		_draw_all_ports()
		return
	if tool == "" or not _in_bounds(hover_cell):
		return
	var def := _def(tool)
	if def == null or def.port_mask() == 0:
		return
	var mask := _rot_mask(def.port_mask(), int(round(float(build_rot) / 90.0)) % 4)
	var size := def.footprint
	var pos := cell_to_world(hover_cell)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0, CELL * 0.5)
	var half := float(size) * CELL * 0.5
	var y := _cell_max_height(hover_cell) + 0.14
	var length := float(size) * CELL * 0.82
	var width := 1.2
	port_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, port_mat)
	_port_quad(pos.x + half, pos.z, true, length, width, y, _port_color(mask & PortSpec.SIDE_E))
	_port_quad(pos.x - half, pos.z, true, length, width, y, _port_color(mask & PortSpec.SIDE_W))
	_port_quad(pos.x, pos.z + half, false, length, width, y, _port_color(mask & PortSpec.SIDE_S))
	_port_quad(pos.x, pos.z - half, false, length, width, y, _port_color(mask & PortSpec.SIDE_N))
	port_mesh.surface_end()


## With the pipe tool active, mark every structure's declared port sides. The
## player can see all connection points at once, so a run is planned against the
## real ports instead of discovered by trial and error.
func _draw_all_ports() -> void:
	if buildings.is_empty():
		return
	var green := Color(0.35, 0.95, 0.45, 0.70)
	port_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, port_mat)
	for b in buildings:
		var mask := _building_port_mask(b)
		if mask == 0:
			continue
		var def := _def(b.kind)
		var size := def.footprint if def != null else 1
		var bc := _building_centre(b)
		var y := float(b.get("top", 0.0)) + 0.16
		var half := float(size) * CELL * 0.5
		var length := float(size) * CELL * 0.62
		var width := 0.9
		if mask & PortSpec.SIDE_E:
			_port_quad(bc.x + half, bc.y, true, length, width, y, green)
		if mask & PortSpec.SIDE_W:
			_port_quad(bc.x - half, bc.y, true, length, width, y, green)
		if mask & PortSpec.SIDE_S:
			_port_quad(bc.x, bc.y + half, false, length, width, y, green)
		if mask & PortSpec.SIDE_N:
			_port_quad(bc.x, bc.y - half, false, length, width, y, green)
	port_mesh.surface_end()


func _port_color(hit: int) -> Color:
	return Color(0.35, 0.95, 0.45, 0.80) if hit != 0 else Color(0.95, 0.30, 0.22, 0.50)


func _port_quad(cx: float, cz: float, along_z: bool, length: float, width: float,
		y: float, col: Color) -> void:
	var hw := width * 0.5
	var hl := length * 0.5
	port_mesh.surface_set_color(col)
	if along_z:
		port_mesh.surface_add_vertex(Vector3(cx - hw, y, cz - hl))
		port_mesh.surface_add_vertex(Vector3(cx + hw, y, cz - hl))
		port_mesh.surface_add_vertex(Vector3(cx + hw, y, cz + hl))
		port_mesh.surface_set_color(col)
		port_mesh.surface_add_vertex(Vector3(cx - hw, y, cz - hl))
		port_mesh.surface_add_vertex(Vector3(cx + hw, y, cz + hl))
		port_mesh.surface_add_vertex(Vector3(cx - hw, y, cz + hl))
	else:
		port_mesh.surface_set_color(col)
		port_mesh.surface_add_vertex(Vector3(cx - hl, y, cz - hw))
		port_mesh.surface_add_vertex(Vector3(cx - hl, y, cz + hw))
		port_mesh.surface_add_vertex(Vector3(cx + hl, y, cz + hw))
		port_mesh.surface_set_color(col)
		port_mesh.surface_add_vertex(Vector3(cx - hl, y, cz - hw))
		port_mesh.surface_add_vertex(Vector3(cx + hl, y, cz + hw))
		port_mesh.surface_add_vertex(Vector3(cx + hl, y, cz - hw))


func _build_drag_preview() -> void:
	drag_mesh = ImmediateMesh.new()
	drag_preview = MeshInstance3D.new()
	drag_preview.mesh = drag_mesh
	drag_mat = StandardMaterial3D.new()
	drag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drag_mat.vertex_color_use_as_albedo = true
	drag_mat.albedo_color = Color(1, 1, 1, 1)
	drag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	drag_preview.material_override = drag_mat
	drag_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drag_preview)


func _build_run_highlight() -> void:
	hl_mesh = ImmediateMesh.new()
	hl_preview = MeshInstance3D.new()
	hl_preview.mesh = hl_mesh
	hl_mat = StandardMaterial3D.new()
	hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hl_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.28)
	hl_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hl_preview.material_override = hl_mat
	hl_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hl_preview)


func _build_road_warnings() -> void:
	warn_mesh = ImmediateMesh.new()
	warn_preview = MeshInstance3D.new()
	warn_preview.mesh = warn_mesh
	warn_mat = StandardMaterial3D.new()
	warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warn_mat.albedo_color = Color(1.0, 0.55, 0.25, 0.30)
	warn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	warn_preview.material_override = warn_mat
	warn_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warn_preview)


func _build_network_overlay() -> void:
	net_mesh = ImmediateMesh.new()
	net_preview = MeshInstance3D.new()
	net_preview.mesh = net_mesh
	net_mat = StandardMaterial3D.new()
	net_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net_mat.vertex_color_use_as_albedo = true
	net_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	net_preview.material_override = net_mat
	net_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net_preview)


func _util_color(ratio: float) -> Color:
	if ratio >= 0.9:
		return Color(0.95, 0.30, 0.25, 0.50)
	if ratio >= 0.6:
		return Color(0.95, 0.85, 0.25, 0.40)
	return Color(0.30, 0.90, 0.40, 0.35)


func _draw_cell_quad(mesh: ImmediateMesh, cell: Vector2i, col: Color) -> void:
	var p := cell_to_world(cell)
	var h := _cell_max_height(cell) + 0.13
	var s := CELL * 0.46
	var a := Vector3(p.x - s, h, p.z - s)
	var b := Vector3(p.x + s, h, p.z - s)
	var cc := Vector3(p.x + s, h, p.z + s)
	var d := Vector3(p.x - s, h, p.z + s)
	mesh.surface_set_color(col)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(cc)
	mesh.surface_set_color(col)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(cc)
	mesh.surface_add_vertex(d)


## Heat-map of the critical networks: pipes by throughput load, roads by logistics
## (orange = isolated). Toggled with Tab.
func _rebuild_network_overlay() -> void:
	if net_mesh == null:
		return
	net_mesh.clear_surfaces()
	if not show_network:
		return
	net_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, net_mat)
	for cell in pipes.keys():
		var cid := int(pipe_comp.get(cell, -1))
		var col := Color(1.0, 0.55, 0.20, 0.45)
		if comp_members.has(cid):
			var m: Dictionary = comp_members[cid]
			if not m.storages.is_empty():
				var cap := float(comp_capacity.get(cid, 0.0))
				var want := 0.0
				for w in m.wells:
					if bool(w.get("road", true)):
						want += float(w.rate)
				col = _util_color(want / cap if cap > 0.0 else 1.0)
		_draw_cell_quad(net_mesh, cell, col)
	for cell in roads.keys():
		var cid := int(road_comp.get(cell, -1))
		var col := Color(1.0, 0.55, 0.20, 0.45)
		if bool(road_served.get(cid, false)):
			var cap := float(road_capacity.get(cid, 0.0))
			var load := float(road_load.get(cid, 0.0))
			col = _util_color(load / cap if cap > 0.0 else 1.0)
		_draw_cell_quad(net_mesh, cell, col)
	net_mesh.surface_end()


## Isolated road cells get an orange overlay so the network rule is visible.
func _rebuild_road_warnings() -> void:
	if warn_mesh == null:
		return
	warn_mesh.clear_surfaces()
	if road_isolated_cells == 0:
		return
	warn_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, warn_mat)
	for cell in road_comp.keys():
		if bool(road_served.get(int(road_comp[cell]), false)):
			continue
		var p := cell_to_world(cell)
		var h := _cell_max_height(cell) + 0.16
		var s := CELL * 0.46
		var a := Vector3(p.x - s, h, p.z - s)
		var b := Vector3(p.x + s, h, p.z - s)
		var cc := Vector3(p.x + s, h, p.z + s)
		var d := Vector3(p.x - s, h, p.z + s)
		warn_mesh.surface_add_vertex(a)
		warn_mesh.surface_add_vertex(b)
		warn_mesh.surface_add_vertex(cc)
		warn_mesh.surface_add_vertex(a)
		warn_mesh.surface_add_vertex(cc)
		warn_mesh.surface_add_vertex(d)
	warn_mesh.surface_end()


## All road cells 4-connected to start (roads have no component cache).
func _road_run(start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		out.append(c)
		for d in DIRS:
			var n: Vector2i = c + d
			if roads.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return out


## Highlights the pipe run or road network of the selected cell.
func _rebuild_run_highlight() -> void:
	if hl_mesh == null:
		return
	var key := "%d,%d|%d|%d|%d" % [selected_cell.x, selected_cell.y,
		pipes.size(), roads.size(), buildings.size()]
	if key == _hl_key:
		return
	_hl_key = key
	hl_mesh.clear_surfaces()
	if selected_cell.x < 0:
		return
	var cells: Array[Vector2i] = []
	if pipes.has(selected_cell):
		var cid := int(pipe_comp.get(selected_cell, -1))
		for p in pipes.keys():
			if int(pipe_comp.get(p, -1)) == cid:
				cells.append(p)
	elif roads.has(selected_cell):
		cells = _road_run(selected_cell)
	if cells.is_empty():
		return
	hl_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, hl_mat)
	for c in cells:
		var p := cell_to_world(c)
		var h := _cell_max_height(c) + 0.10
		var s := CELL * 0.48
		var a := Vector3(p.x - s, h, p.z - s)
		var b := Vector3(p.x + s, h, p.z - s)
		var cc := Vector3(p.x + s, h, p.z + s)
		var d := Vector3(p.x - s, h, p.z + s)
		hl_mesh.surface_add_vertex(a)
		hl_mesh.surface_add_vertex(b)
		hl_mesh.surface_add_vertex(cc)
		hl_mesh.surface_add_vertex(a)
		hl_mesh.surface_add_vertex(cc)
		hl_mesh.surface_add_vertex(d)
	hl_mesh.surface_end()


## Cells the current drag would actually fill. Mirrors `_place_infra`: skips
## occupied/other infrastructure and cells that break the grade limit, including
## against cells accepted earlier in the same route.
func _route_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var dict: Dictionary = pipes if tool == "pipe" else roads
	var primary := _filter_route(_line_cells(a, b, true), dict)
	var alternate := _filter_route(_line_cells(a, b, false), dict)
	# Prefer the orientation that keeps more of the requested route: a corner
	# obstacle on one L is routed around by the other without a full A*.
	return alternate if alternate.size() > primary.size() else primary


## Validity filter shared by both candidate L routes (occupancy, relief, grade).
func _filter_route(line: Array[Vector2i], dict: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var accepted: Dictionary = {}
	for c in line:
		if not _in_bounds(c):
			continue
		if occupied.has(c):
			continue
		if (tool == "pipe" and pipes.has(c)) or (tool == "road" and roads.has(c)):
			continue
		if _cell_relief(c) > MAX_INFRA_RELIEF:
			continue
		var here := _cell_max_height(c)
		var blocked := false
		for d in DIRS:
			var nb: Vector2i = c + d
			if (dict.has(nb) or accepted.has(nb)) and absf(here - _cell_max_height(nb)) > MAX_GRADE:
				blocked = true
				break
		if blocked:
			continue
		accepted[c] = true
		out.append(c)
	return out


func _update_drag_preview() -> void:
	if drag_mesh == null:
		return
	drag_mesh.clear_surfaces()
	if not dragging or (tool != "pipe" and tool != "road"):
		return
	if not _in_bounds(drag_start) or not _in_bounds(hover_cell):
		return
	var start := drag_start
	var end := hover_cell
	if tool == "pipe":
		var pair := _snap_pipe_route(drag_start, hover_cell)
		start = pair[0]
		end = pair[1]
	var cells := _route_cells(start, end)
	if cells.is_empty():
		return
	drag_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, drag_mat)
	for c in cells:
		var col := Color(0.95, 0.85, 0.25, 0.30)
		if tool == "pipe":
			# green = this cell lands on a declared port; orange = a structure is
			# adjacent but has no port there, so the run would dead-end.
			if _port_joint_at(c) != 0:
				col = Color(0.35, 0.95, 0.45, 0.44)
			elif _building_adjacent(c):
				col = Color(0.95, 0.45, 0.18, 0.40)
		elif _road_cell_links(c):
			# green = this road cell touches a site or an already-served network
			col = Color(0.35, 0.95, 0.45, 0.40)
		_draw_cell_quad(drag_mesh, c, col)
	drag_mesh.surface_end()


func _commit_drag() -> void:
	if dragging and (tool == "pipe" or tool == "road") \
			and _in_bounds(drag_start) and _in_bounds(hover_cell):
		if tool == "pipe":
			var pair := _snap_pipe_route(drag_start, hover_cell)
			_lay_line(pair[0], pair[1])
		else:
			_lay_line(drag_start, hover_cell)
	dragging = false
	_update_drag_preview()
	_rebuild_components()


# --------------------------------------------------------------------------- #
# deposits
# --------------------------------------------------------------------------- #

func _generate_deposits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	var placed := 0
	while placed < 18:
		var c := Vector2i(rng.randi_range(3, GRID - 4), rng.randi_range(3, GRID - 4))
		if deposits.has(c) or _is_water_cell(c):
			continue
		deposits[c] = {
			"amount": rng.randf_range(18000.0, 42000.0),
			"revealed": false,
			"node": null,
		}
		placed += 1


## Every player starts with a finished, flat, prepared HQ plot. Only the other
## sites on the lease need a bulldozer. `--players=N` sets the plot count.
func _place_starting_base() -> void:
	if not _find_base().is_empty():
		return
	cash = START_CASH
	base_origins.clear()
	var centre := Vector2i(GRID / 2, GRID / 2)
	var placed := 0
	for slot in BASE_SLOTS:
		if placed >= player_count:
			break
		var c: Vector2i = centre + (slot as Vector2i)
		if not _in_bounds(c):
			continue
		var cells := _cells_for(c, 2)
		var ok := true
		for cc in cells:
			if not _cell_free(cc) or deposits.has(cc) or _is_water_cell(cc):
				ok = false
				break
		if not ok:
			continue
		# a ready plot: flat ground and a prepared 4x4 dirt pad, no earthworks
		var pad := _cells_for(c - Vector2i(1, 1), 4)
		var total := 0.0
		for pc in pad:
			var p := _cell_centre(pc)
			total += _terrain_height(p.x, p.y)
		var target := total / float(pad.size())
		_level_cells(pad, target)
		for pc in pad:
			prepared[pc] = true
		var before := buildings.size()
		_try_build("base", c)
		if buildings.size() > before:
			base_origins.append(c)
			placed += 1
	if placed > 0:
		camera.target = cell_to_world(base_origins[0])
	print("Prepared %d/%d player base plots" % [placed, player_count])
	hud.toast("%d player bases prepared and flat" % placed, Color(0.7, 0.9, 0.6))


func _reveal(cell: Vector2i) -> void:
	var d: Dictionary = deposits[cell]
	if d.revealed:
		return
	d.revealed = true
	var node: Node3D = _spawn_model("gam_deposit", cell_to_world(cell), 0.0, true)
	if node != null:
		d.node = node
		markers_root.add_child(node)
	# a clear beacon so the player knows where to send the bulldozer
	var marker := _make_deposit_marker(cell)
	markers_root.add_child(marker)
	d.marker = marker


## Orange ground ring + light beam + "OIL" tag marking a revealed deposit.
func _make_deposit_marker(cell: Vector2i) -> Node3D:
	var root := Node3D.new()
	var p := cell_to_world(cell)
	root.position = Vector3(p.x, p.y, p.z)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.0
	tm.outer_radius = 3.7
	tm.rings = 28
	tm.ring_segments = 8
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(ring)

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.6
	cyl.height = 9.0
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.6, 0.2, 0.32)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0.0, 4.5, 0.0)
	root.add_child(beam)

	var lbl := Label3D.new()
	lbl.text = "OIL"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 48
	lbl.pixel_size = 0.04
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.05, 0.03, 0.0, 0.9)
	lbl.modulate = Color(1.0, 0.78, 0.30)
	lbl.position = Vector3(0.0, 6.0, 0.0)
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lbl)
	return root


func _reveal_around(origin: Vector2i, radius: float) -> int:
	var found := 0
	for c in deposits.keys():
		if not deposits[c].revealed and (c as Vector2i).distance_to(origin) <= radius:
			_reveal(c)
			found += 1
	return found


## A survey office runs its survey once road access exists.
func _do_survey(b: Dictionary) -> void:
	if bool(b.get("surveyed", false)):
		return
	b["surveyed"] = true
	var def := _def(b.kind)
	var radius := def.capacity.radius if def != null and def.capacity != null else 0.0
	var n := _reveal_around(b.origin, radius)
	if n > 0:
		hud.toast("Survey complete — %d new deposit%s found" % [n, "" if n == 1 else "s"], Color(0.6, 0.9, 0.6))
	else:
		hud.toast("Survey complete — no new deposits in range", Color(0.8, 0.85, 0.7))


## Called after a road tile is laid: any waiting office now adjacent to it surveys.
func _check_surveys() -> void:
	for b in buildings:
		if b.kind == "explorer" and not bool(b.get("surveyed", false)) and _road_near(b.cells):
			_do_survey(b)


# --------------------------------------------------------------------------- #
# placement helpers
# --------------------------------------------------------------------------- #

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(
		floori((p.x + HALF) / CELL),
		floori((p.z + HALF) / CELL)
	)


func cell_to_world(c: Vector2i) -> Vector3:
	var x := (c.x - GRID * 0.5 + 0.5) * CELL
	var z := (c.y - GRID * 0.5 + 0.5) * CELL
	return Vector3(x, _terrain_height(x, z), z)


## x/z of a cell centre, without touching the heightmap.
func _cell_centre(c: Vector2i) -> Vector2:
	return Vector2((c.x - GRID * 0.5 + 0.5) * CELL, (c.y - GRID * 0.5 + 0.5) * CELL)


## Heights at the four corners of a cell. Neighbouring cells share corners, so
## anything placed on this height meets its neighbour exactly.
func _cell_corners(c: Vector2i) -> PackedFloat32Array:
	var p := _cell_centre(c)
	var out := PackedFloat32Array()
	for k in CELL_CORNERS:
		out.append(_terrain_height(p.x + k.x * CELL, p.y + k.y * CELL))
	return out


## Highest corner of the cell: structures anchored here never sink into a slope.
func _cell_max_height(c: Vector2i) -> float:
	var hs := _cell_corners(c)
	var m := hs[0]
	for h in hs:
		m = maxf(m, h)
	return m


## Cut/fill needed to make the cell flat.
func _cell_relief(c: Vector2i) -> float:
	var hs := _cell_corners(c)
	var lo := hs[0]
	var hi := hs[0]
	for h in hs:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return hi - lo


func _footprint_relief(cells: Array) -> float:
	var r := 0.0
	for c in cells:
		r = maxf(r, _cell_relief(c))
	return r


## Cut/fill volume (m3) for levelling the given cells to target_y, without applying it.
func _level_moved(cells: Array, target_y: float) -> float:
	var n := terrain.resolution
	var cs := terrain.cell_size
	var half_span := float(n) * cs * 0.5
	var moved := 0.0
	for c in cells:
		var p := _cell_centre(c as Vector2i)
		var ax0 := clampi(int(round((p.x - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var ax1 := clampi(int(round((p.x + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az0 := clampi(int(round((p.y - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az1 := clampi(int(round((p.y + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		for gz in range(az0, az1 + 1):
			for gx in range(ax0, ax1 + 1):
				moved += absf(terrain.heights[gz * n + gx] - target_y)
	return moved * cs * cs


## Flattens every terrain sample under the given cells to target_y and returns
## the number of cubic metres moved. Keeps the collider and Terrain3D in sync.
func _level_cells(cells: Array, target_y: float) -> float:
	var n := terrain.resolution
	var cs := terrain.cell_size
	var half_span := float(n) * cs * 0.5
	var gx0 := n
	var gx1 := -1
	var gz0 := n
	var gz1 := -1
	var moved := 0.0
	for c in cells:
		var p := _cell_centre(c as Vector2i)
		var ax0 := clampi(int(round((p.x - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var ax1 := clampi(int(round((p.x + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az0 := clampi(int(round((p.y - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az1 := clampi(int(round((p.y + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		for gz in range(az0, az1 + 1):
			for gx in range(ax0, ax1 + 1):
				var i := gz * n + gx
				moved += absf(terrain.heights[i] - target_y)
				terrain.heights[i] = target_y
		gx0 = mini(gx0, ax0)
		gx1 = maxi(gx1, ax1)
		gz0 = mini(gz0, az0)
		gz1 = maxi(gz1, az1)

	# soften the rim so a levelled pad does not end in a vertical cliff
	for gz in range(gz0 - 1, gz1 + 2):
		for gx in range(gx0 - 1, gx1 + 2):
			if gx < 0 or gz < 0 or gx >= n or gz >= n:
				continue
			var inside := gx >= gx0 and gx <= gx1 and gz >= gz0 and gz <= gz1
			if inside:
				continue
			var i := gz * n + gx
			terrain.heights[i] = lerpf(terrain.heights[i], target_y, 0.5)

	_sync_terrain(gx0, gx1, gz0, gz1)
	return moved * cs * cs


## Pushes edited heights into the visible terrain and the collider.
func _sync_terrain(gx0: int, gx1: int, gz0: int, gz1: int) -> void:
	var n := terrain.resolution
	var cs := terrain.cell_size
	if terrain_shape != null:
		terrain_shape.map_data = terrain.heights
	if terrain3d != null:
		var half_span := float(n) * cs * 0.5
		var wx0 := (float(gx0) - half_span) * cs
		var wx1 := (float(gx1) - half_span) * cs
		var wz0 := (float(gz0) - half_span) * cs
		var wz1 := (float(gz1) - half_span) * cs
		var rx0 := int(floor(wx0 / T3D_REGION_M))
		var rx1 := int(floor(wx1 / T3D_REGION_M))
		var rz0 := int(floor(wz0 / T3D_REGION_M))
		var rz1 := int(floor(wz1 / T3D_REGION_M))
		for rz in range(rz0, rz1 + 1):
			for rx in range(rx0, rx1 + 1):
				terrain3d.data.import_images(_terrain3d_region(rx, rz),
					Vector3(rx * T3D_REGION_M, 0.0, rz * T3D_REGION_M), 0.0, T3D_HEIGHT_SCALE)
	elif terrain_mesh_inst != null:
		terrain_mesh_inst.mesh = OilTerrainGen.build_mesh(terrain)


## Test-only: flatten the whole heightfield so rule tests are independent of the
## procedural landscape. The shipped game keeps the rolling terrain.
func _flatten_terrain(y: float) -> void:
	if terrain == null:
		return
	for i in terrain.heights.size():
		terrain.heights[i] = y
	# also flatten any prepared-pad records so footprints read clean
	_sync_terrain(0, terrain.resolution - 1, 0, terrain.resolution - 1)


func _cells_for(origin: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in size:
		for dz in size:
			out.append(origin + Vector2i(dx, dz))
	return out


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID and c.y < GRID


func _cell_free(c: Vector2i) -> bool:
	return _in_bounds(c) and not occupied.has(c) and not pipes.has(c) \
		and not roads.has(c) and not pending_cells.has(c)


## True when the cell is below the sea plane (not buildable).
func _is_water_cell(c: Vector2i) -> bool:
	return terrain != null and _cell_max_height(c) < terrain.sea_level + 0.6


func _rel_transform(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _model_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var has := false
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = _rel_transform(m, root) * m.get_aabb()
		if has:
			box = box.merge(a)
		else:
			box = a
			has = true
	return box


func _toon_variant(src: StandardMaterial3D) -> StandardMaterial3D:
	var key := src.get_instance_id()
	if _toon_cache.has(key):
		return _toon_cache[key]
	var t: StandardMaterial3D = src.duplicate()
	t.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	t.specular_mode = BaseMaterial3D.SPECULAR_TOON
	t.metallic = 0.0
	t.roughness = 0.55
	t.rim_enabled = false
	_toon_cache[key] = t
	return t


func _apply_toon(node: Node3D) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.mesh == null:
			continue
		for i in mm.mesh.get_surface_count():
			var src := mm.get_active_material(i)
			if src is StandardMaterial3D:
				mm.set_surface_override_material(i, _toon_variant(src))


func _spawn_model(id: String, pos: Vector3, rot_deg: float, fit: bool = true, target: float = CELL * 0.94) -> Node3D:
	if not MODEL_SCENES.has(id):
		return null
	var inst: Node3D = MODEL_SCENES[id].instantiate()

	# every module is scaled so its longest ground footprint matches its cells,
	# i.e. authored metres are reconciled with the map cell size at runtime
	if fit:
		var box := _model_aabb(inst)
		var footprint: float = maxf(box.size.x, box.size.z)
		if footprint > 0.001:
			var s := target / footprint
			inst.scale = Vector3(s, s, s)
			inst.position = -Vector3(box.get_center().x, 0.0, box.get_center().z) * s

	var pivot := Node3D.new()
	pivot.add_child(inst)
	pivot.position = pos
	pivot.rotation_degrees.y = rot_deg
	pivot.set_meta("model_id", id)

	_apply_toon(pivot)

	if id.begins_with("gam_road"):
		var rm := _road_material()
		for mi in pivot.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			if mm.mesh == null:
				continue
			for i in mm.mesh.get_surface_count():
				mm.set_surface_override_material(i, rm)
	return pivot


# --------------------------------------------------------------------------- #
# input
# --------------------------------------------------------------------------- #

func _unhandled_input(event: InputEvent) -> void:
	if _screenshot_mode:
		return
	if event is InputEventMouseMotion:
		var cell := _mouse_cell()
		if cell != hover_cell:
			hover_cell = cell
			_update_ghost()
			if bulldoze and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
					and cell != _bulldoze_last:
				_bulldoze_last = cell
				_bulldoze_at(cell)
			elif dragging and (tool == "pipe" or tool == "road"):
				_update_drag_preview()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_click()
			else:
				_bulldoze_last = Vector2i(-1, -1)
				_commit_drag()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# Right-drag orbits the camera; a right-CLICK (no drag) issues the
			# selected unit's job at that spot — the classic RTS order.
			if mb.pressed:
				_right_press_pos = get_viewport().get_mouse_position()
			elif get_viewport().get_mouse_position().distance_to(_right_press_pos) < 6.0:
				_right_click_command(_mouse_cell())
			return
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if _hotkeys.has(k.keycode):
			_on_tool_selected(_hotkeys[k.keycode])
			return
		match k.keycode:
			KEY_X: _on_bulldoze()
			KEY_ESCAPE: _clear_tool()
			KEY_SPACE: paused = not paused
			KEY_G:
				pipe_grade_choice = (pipe_grade_choice + 1) % 3
				var gname := catalogue.pipe_grade_name(pipe_grade_choice)
				var gcost := catalogue.pipe_grade_cost(pipe_grade_choice)
				var gcap := catalogue.pipe_grade_capacity(pipe_grade_choice)
				hud.toast("Pipe grade: %s — $%s/cell · %.0f bbl/s" % [
					gname, hud.fmt_num(gcost), gcap], Color(0.85, 0.9, 0.6))
				if tool == "pipe":
					hud.set_hint(_pipe_hint())
			KEY_C:
				camera.toggle_mode()
				hud.toast(
					"Camera: classic isometric (C&C)" if camera.is_classic()
					else "Camera: 3D orbit",
					Color(0.8, 0.9, 0.75))
			KEY_R:
				build_rot = (build_rot + 90) % 360
				_update_ghost()
			KEY_F5: _save_game()
			KEY_F9: _load_game()
			KEY_F6: _transfer_fleet_here()
			KEY_F7: _demolish_selected_network()
			KEY_H: hud.toggle_help()
			KEY_TAB:
				show_network = not show_network
				_rebuild_network_overlay()
				hud.toast(
					"Network overlay %s — green <60%% · yellow <90%% · red ≥90%% · orange isolated" % ("on" if show_network else "off"),
					Color(0.8, 0.9, 0.75))
			KEY_F: camera.target = Vector3(0, 0, 40)


func _on_left_click() -> void:
	var cell := _mouse_cell()
	if not _in_bounds(cell):
		return
	if bulldoze:
		_bulldoze_last = cell
		_bulldoze_at(cell)
		return
	if tool == "":
		var unit_index := _unit_at_cell(cell)
		if unit_index >= 0:
			_select_unit(unit_index)
			return
		if not _selected_unit_dict().is_empty():
			if pending_action != "":
				_execute_unit_action(cell, pending_action)
				pending_action = ""
			else:
				# left-click is a plain move; the job is issued with right-click
				_execute_unit_action(cell, "move")
			_show_unit_hint()
			return
		selected_cell = cell if (occupied.has(cell) or pipes.has(cell) or roads.has(cell)) else Vector2i(-1, -1)
		if selected_cell.x >= 0:
			Sfx.play("click")
		return
	if tool == "pipe" or tool == "road":
		dragging = true
		drag_start = cell
		_update_drag_preview()
		return
	_request_build(tool, cell)


## Player build order: validate, reserve the site, and send a builder unit.
## Nothing is constructed until the builder arrives and finishes the work.
func _request_build(kind: String, cell: Vector2i) -> void:
	var def := _def(kind)
	if def == null:
		return
	# forgiving placement: clicking anywhere on a prepared pad places the
	# pumpjack on the revealed deposit inside it
	if kind == "well":
		var snapped := _nearby_revealed_deposit(cell, 1)
		if snapped.x >= 0:
			cell = snapped
	var size: int = def.footprint
	var cells := _cells_for(cell, size)
	var reason := _placement_reason(cell, kind)
	if reason != "":
		hud.toast(reason, Color(1.0, 0.6, 0.4))
		Sfx.play("error")
		return
	if cash < def.cost:
		hud.toast("Not enough cash for %s" % def.display_name, Color(1.0, 0.6, 0.4))
		Sfx.play("error")
		return
	_reserve_build(cell, kind, build_rot, cells)
	# leave build mode so the player can select a crane and assign it
	tool = ""
	bulldoze = false
	hud.set_tool("")
	ghost.visible = false
	var have_builder := false
	for u in fleet_units:
		if String(u.get("job", "")) == "build":
			have_builder = true
			break
	if have_builder:
		hud.toast("%s planned — select a Mobile Crane and right-click the site" % def.display_name,
			Color(0.8, 0.9, 0.6))
	else:
		hud.toast("%s planned — buy a Mobile Crane to build it" % def.display_name,
			Color(1.0, 0.78, 0.4))
	Sfx.play("confirm", 1.0)


## Manually assign a crane (by unit index) to a reserved site.
func _assign_crane_to_site(index: int, site: Vector2i) -> void:
	if index < 0 or index >= fleet_units.size():
		return
	if not pending_builds.has(site):
		return
	var u: Dictionary = fleet_units[index]
	if String(u.get("job", "")) != "build":
		hud.toast("Select a Mobile Crane to build this site", Color(1.0, 0.7, 0.4))
		Sfx.play("error")
		return
	# re-assigning the crane abandons its current site (which stays queued)
	if _in_bounds(u.get("build_cell", Vector2i(-1, -1))):
		_cancel_build(u)
	if not pending_builds.has(site):
		return
	var pb: Dictionary = pending_builds[site]
	pb["builder"] = index
	u.build_cell = site
	u.order = "build"
	u.target = _builder_access_cell(pb.cells)
	u.state = "moving"
	u.progress = float(pb.get("progress", 0.0))
	var lbl := _pending_label(pb)
	if lbl != null:
		lbl.text = "CONSTRUCTION"
	var def := _def(String(pb.kind))
	var nm := def.display_name if def != null else String(pb.kind)
	hud.toast("Mobile Crane assigned to build %s" % nm, Color(0.7, 0.9, 0.6))
	Sfx.play("confirm", 1.05)


## Origin of the pending build whose footprint contains `cell`, or (-1,-1).
func _pending_at(cell: Vector2i) -> Vector2i:
	for origin in pending_builds.keys():
		var pb: Dictionary = pending_builds[origin]
		if (pb.cells as Array).has(cell):
			return origin
	return Vector2i(-1, -1)


func _pending_label(pb: Dictionary) -> Label3D:
	var node = pb.get("node", null)
	if node == null or not is_instance_valid(node):
		return null
	return node.find_child("SiteLabel", true, false) as Label3D


func _reserve_build(cell: Vector2i, kind: String, rot: int, cells: Array) -> void:
	# replace any stale reservation on the same site
	if pending_builds.has(cell):
		_clear_pending_node(cell)
		for c in cells:
			pending_cells.erase(c)
	var scaffold := _make_scaffold(cell, kind, cells)
	markers_root.add_child(scaffold)
	var pb := {"kind": kind, "rot": rot, "cells": cells, "node": scaffold,
		"builder": -1, "progress": 0.0}
	pending_builds[cell] = pb
	for c in cells:
		pending_cells[c] = true
	_spawn_build_preview(pb, cell)


## Free every node owned by a pending site (scaffold, hologram, effects).
func _clear_pending_node(cell: Vector2i) -> void:
	if not pending_builds.has(cell):
		return
	var pb: Dictionary = pending_builds[cell]
	for key in ["node", "preview", "fx"]:
		var n = pb.get(key, null)
		if n != null and is_instance_valid(n):
			n.queue_free()
		pb.erase(key)


## Translucent block + tag marking a reserved/queued build site.
func _make_scaffold(cell: Vector2i, kind: String, cells: Array) -> Node3D:
	var def := _def(kind)
	var size: int = def.footprint if def != null else 1
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(float(size) * CELL * 0.9, 2.4, float(size) * CELL * 0.9)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.18)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(mi)
	var lbl := Label3D.new()
	lbl.name = "SiteLabel"
	lbl.text = "AWAITING CRANE"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 34
	lbl.pixel_size = 0.03
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.04, 0.03, 0.0, 0.9)
	lbl.modulate = Color(1.0, 0.85, 0.3)
	lbl.position = Vector3(0.0, 3.2, 0.0)
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lbl)
	var pos := cell_to_world(cell)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	root.position = pos
	return root


func _builder_access_cell(cells: Array) -> Vector2i:
	for c in cells:
		for d in DIRS:
			var n: Vector2i = c + d
			if not cells.has(n) and _cell_free(n):
				return n
	return cells[0]


func _cancel_build(u: Dictionary) -> void:
	var cell: Vector2i = u.get("build_cell", Vector2i(-1, -1))
	u.build_cell = Vector2i(-1, -1)
	if not _in_bounds(cell) or not pending_builds.has(cell):
		return
	var pb: Dictionary = pending_builds[cell]
	# keep the reserved site (hologram/scaffold) but return it to the queue so
	# another crane can take it, or the same crane once it is free again
	pb["builder"] = -1
	pb["progress"] = float(u.progress)
	var fx = pb.get("fx", null)
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	pb.erase("fx")
	var lbl := _pending_label(pb)
	if lbl != null:
		lbl.text = "AWAITING CRANE"
	hud.toast("Construction paused — site awaiting a crane",
		Color(1.0, 0.82, 0.45))


## Shader material that grows a preview of the structure from the ground up.
func _make_construction_material(base_y: float, height: float) -> ShaderMaterial:
	var sh: Shader = load("res://shaders/construction.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("base_y", base_y)
	mat.set_shader_parameter("build_height", height)
	mat.set_shader_parameter("progress", 0.0)
	return mat


## Beam + sparks + dust at the site while the crane is building.
func _make_construction_fx(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 1.7
	cyl.height = 10.0
	beam.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(0.40, 0.85, 1.0, 0.28)
	beam.material_override = bmat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(0.0, 5.0, 0.0)
	root.add_child(beam)

	var sparks := CPUParticles3D.new()
	sparks.amount = 26
	sparks.lifetime = 0.6
	sparks.one_shot = false
	sparks.emitting = true
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 62.0
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.85, 0.35, 0.95)
	sm.material = smat
	sparks.mesh = sm
	sparks.position = Vector3(0.0, 2.0, 0.0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sparks)

	var dust := CPUParticles3D.new()
	dust.amount = 24
	dust.lifetime = 1.1
	dust.one_shot = false
	dust.emitting = true
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 70.0
	dust.gravity = Vector3(0, -1.2, 0)
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.4
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(0.72, 0.65, 0.52, 0.30)
	dm.material = dmat
	dust.mesh = dm
	dust.position = Vector3(0.0, 0.6, 0.0)
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dust)
	return root


## Spawn the construction preview when the crane reaches the site.
## Spawn the C&C-style hologram preview for a reserved/queued site.
func _spawn_build_preview(pb: Dictionary, cell: Vector2i) -> void:
	var prev = pb.get("preview", null)
	if prev != null and is_instance_valid(prev):
		return
	var def := _def(String(pb.kind))
	if def == null:
		return
	var size: int = def.footprint
	var top := -1.0e9
	for c in pb.cells:
		top = maxf(top, _cell_max_height(c))
	var cp := _cell_centre(cell)
	var pos := Vector3(cp.x, top, cp.y)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	var preview := _spawn_model(def.model_id, pos, float(pb.rot), true,
		float(size) * CELL * BUILDING_FIT)
	if preview == null:
		return
	markers_root.add_child(preview)
	var aabb := _model_aabb(preview)
	var build_h := maxf(aabb.size.y, 1.5)
	var cmat := _make_construction_material(pos.y + aabb.position.y, build_h)
	cmat.set_shader_parameter("progress", float(pb.get("progress", 0.0)) / 10.0)
	for mi in preview.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = cmat
	pb["preview"] = preview
	pb["cmat"] = cmat


## Beam + sparks + dust while a crane is actively building.
func _start_build_fx(pb: Dictionary, cell: Vector2i) -> void:
	var fx = pb.get("fx", null)
	if fx != null and is_instance_valid(fx):
		return
	var def := _def(String(pb.kind))
	var size: int = def.footprint if def != null else 1
	var top := -1.0e9
	for c in pb.cells:
		top = maxf(top, _cell_max_height(c))
	var cp := _cell_centre(cell)
	var pos := Vector3(cp.x, top, cp.y)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	var node := _make_construction_fx(pos)
	markers_root.add_child(node)
	pb["fx"] = node


## The crane has finished: instantiate the real structure and release the site.
func _finalize_build(u: Dictionary) -> void:
	var cell: Vector2i = u.get("build_cell", Vector2i(-1, -1))
	u.build_cell = Vector2i(-1, -1)
	u.state = "idle"
	u.order = ""
	if not _in_bounds(cell) or not pending_builds.has(cell):
		return
	var pb: Dictionary = pending_builds[cell]
	var kind := String(pb.kind)
	var rot := int(pb.rot)
	var cells: Array = pb.cells
	_clear_pending_node(cell)
	for c in cells:
		pending_cells.erase(c)
	pending_builds.erase(cell)
	var old_rot := build_rot
	build_rot = rot
	_try_build(kind, cell)
	build_rot = old_rot
	var def := _def(kind)
	var nm := def.display_name if def != null else kind
	u.done_timer = 2.6
	u.done_text = "✓ %s built" % nm
	_spawn_float_text(cell_to_world(cell), "BUILT ✓", Color(0.6, 1.0, 0.6), 48)


func _mouse_cell() -> Vector2i:
	var mp := get_viewport().get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mp)
	var dir: Vector3 = camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t: float = -from.y / dir.y
	var p: Vector3 = from + dir * t
	for i in 3:
		var h := _terrain_height(p.x, p.z)
		t = (h - from.y) / dir.y
		p = from + dir * t
	return world_to_cell(p)


## Classic RTS order: right-click sends the selected unit to the cell and runs its
## single job there (survey / prepare / haul). Left-click only moves.
func _right_click_command(cell: Vector2i) -> void:
	if _screenshot_mode or not _in_bounds(cell):
		return
	if tool != "" or bulldoze:
		return
	var u := _selected_unit_dict()
	if u.is_empty():
		return
	# a builder right-clicks a reserved site to take the job
	var site := _pending_at(cell)
	if site.x >= 0:
		if String(u.get("job", "")) == "build":
			_assign_crane_to_site(selected_unit, site)
			pending_action = ""
			_show_unit_hint()
			return
		hud.toast("Select a Mobile Crane, then right-click the build site",
			Color(1.0, 0.8, 0.4))
		pending_action = ""
		return
	match String(u.get("job", "")):
		"seismic":
			_execute_unit_action(cell, "survey")
		"prep":
			_execute_unit_action(cell, "prepare")
		"hauler":
			_execute_unit_action(cell, "haul")
		_:
			_execute_unit_action(cell, "move")
	pending_action = ""
	_show_unit_hint()


func _update_ghost() -> void:
	_update_port_hint()
	if dragging:
		ghost.visible = false
		return
	if tool == "" or bulldoze or not _in_bounds(hover_cell):
		ghost.visible = false
		return
	ghost.visible = true
	# a pumpjack snaps to the revealed deposit inside the clicked pad
	var build_cell := hover_cell
	if tool == "well":
		var dep := _nearby_revealed_deposit(hover_cell, 1)
		if dep.x >= 0:
			build_cell = dep
	var size: int = _def(tool).footprint
	var pos := cell_to_world(build_cell)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0, CELL * 0.5)
	ghost.position = pos + Vector3(0, 0.08, 0)
	ghost.scale = Vector3(float(size), float(size), 1.0)
	var ok := _can_place(build_cell, tool)
	if ok and tool != "pipe" and tool != "road":
		var relief := _footprint_relief(_cells_for(build_cell, size))
		if relief > MAX_BUILD_RELIEF:
			ok = false
	ghost_mat.albedo_color = Color(0.35, 0.9, 0.45, 0.35) if ok else Color(0.95, 0.3, 0.25, 0.4)


# --------------------------------------------------------------------------- #
# build / demolish
# --------------------------------------------------------------------------- #

func _can_place(origin: Vector2i, kind: String) -> bool:
	var def := _def(kind)
	if def == null:
		return false
	var cells := _cells_for(origin, def.footprint)
	for c in cells:
		if not _cell_free(c) or _is_water_cell(c):
			return false
	if def.requires_deposit:
		if not deposits.has(origin) or not deposits[origin].revealed:
			return false
		if deposits[origin].amount <= 0.0:
			return false
	if def.spacing_role != "" and def.spacing_cells > 0:
		for b in buildings:
			if _role_of(b.kind) == def.spacing_role \
					and (b.origin as Vector2i).distance_to(origin) < float(def.spacing_cells):
				return false
	return true


## Why a placement is refused, in words the HUD can show. Empty means allowed.
func _placement_reason(cell: Vector2i, kind: String) -> String:
	var def := _def(kind)
	if def == null:
		return "Unknown structure"
	var cells := _cells_for(cell, def.footprint)
	for c in cells:
		if not _in_bounds(c):
			return "Outside the lease"
		if _is_water_cell(c):
			return "Cannot build on water — level the shore first"
		if not _cell_free(c):
			return "That space is blocked"
	if _footprint_relief(cells) > MAX_BUILD_RELIEF:
		return "Ground too steep — flatten it with a Bulldozer first"
	if def.requires_deposit:
		if not deposits.has(cell):
			if _site_prepared(cell):
				return "This prepared pad has no oil under it — survey with a Seismic Vehicle first"
			return "Pumpjacks must sit on a revealed oil deposit"
		if not bool(deposits[cell].revealed):
			return "Deposit not surveyed — use a Seismic Vehicle"
		if float(deposits[cell].amount) <= 0.0:
			return "That deposit is drained"
	if def.spacing_role != "" and def.spacing_cells > 0:
		for b in buildings:
			if _role_of(b.kind) == def.spacing_role \
					and (b.origin as Vector2i).distance_to(cell) < float(def.spacing_cells):
				var other := _def(b.kind)
				return "Too close to another %s" % (
					other.display_name if other != null else "structure")
	return ""


## Nearest revealed, non-empty deposit around a clicked cell, so a Pumpjack can
## be placed anywhere on a prepared pad and still land on the oil.
func _nearby_revealed_deposit(cell: Vector2i, radius: int = 1) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 999
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := cell + Vector2i(dx, dz)
			if not deposits.has(c):
				continue
			var d: Dictionary = deposits[c]
			if not bool(d.revealed) or float(d.amount) <= 0.0:
				continue
			if not _cell_free(c):
				continue
			var dist := absi(dx) + absi(dz)
			if dist < best_dist:
				best_dist = dist
				best = c
	return best


func _try_build(kind: String, cell: Vector2i) -> void:
	var def := _def(kind)
	if def == null:
		return
	var size: int = def.footprint
	var cells := _cells_for(cell, size)

	# terrain matters: a site must be flat enough to level economically
	var relief := _footprint_relief(cells)
	if relief > MAX_BUILD_RELIEF:
		hud.toast("Ground too steep (%.1f m drop) — build on flatter ground" % relief, Color(1, 0.6, 0.4))
		Sfx.play("error")
		return

	if not _can_place(cell, kind):
		if kind == "well":
			hud.toast("Pumpjacks must sit on a revealed oil deposit", Color(1, 0.6, 0.4))
		else:
			hud.toast("That space is blocked", Color(1, 0.6, 0.4))
		Sfx.play("error")
		return

	# level the pad first so the price includes the earthworks
	var top := -1.0e9
	for c in cells:
		top = maxf(top, _cell_max_height(c))
	var moved := _level_moved(cells, top)
	var earth := moved * LEVEL_RATE
	var total: float = def.cost + earth
	if cash < total:
		hud.toast("Not enough cash for %s + site levelling ($%s)" % [def.display_name, hud.fmt_num(total)], Color(1, 0.6, 0.4))
		Sfx.play("error")
		return

	cash -= total
	if earth > 0.5:
		_level_cells(cells, top)
		hud.toast("Site levelled: %.0f m³ moved, $%s" % [moved, hud.fmt_num(earth)], Color(0.75, 0.85, 0.65))

	var pos := Vector3(_cell_centre(cell).x, top, _cell_centre(cell).y)
	if size > 1:
		pos += Vector3(CELL * 0.5, 0, CELL * 0.5)
	# Fit to the WHOLE footprint. A 2x2 refinery must be 2 cells wide, otherwise
	# its model sits at the block centre and every port is a cell away from the pad.
	var node := _spawn_model(def.model_id, pos, float(build_rot), true,
		float(size) * CELL * BUILDING_FIT)
	if node == null:
		hud.toast("Missing model for " + def.display_name, Color(1, 0.4, 0.3))
		cash += def.cost
		return
	buildings_root.add_child(node)

	var cap := def.capacity
	var b := {
		"kind": kind, "name": def.display_name, "cells": cells, "origin": cell,
		"node": node, "comp": -1, "upkeep": def.upkeep, "rot": build_rot, "top": top,
		"half": _structure_half(node), "height": _structure_height(node),
		"boost": cap.boost if cap != null else 0.0,
	}
	match def.role:
		"producer":
			b["rate"] = cap.rate if cap != null else 0.0
			b["deposit"] = deposits[cell].amount
			if deposits[cell].node != null:
				(deposits[cell].node as Node3D).visible = false
			var dmk = deposits[cell].get("marker", null)
			if dmk != null and is_instance_valid(dmk):
				dmk.queue_free()
			deposits[cell]["marker"] = null
		"buffer":
			b["capacity"] = cap.volume if cap != null else 0.0
			b["crude"] = 0.0
		"consumer":
			b["throughput"] = cap.feed if cap != null else 0.0
		"processor":
			b["yield_bonus"] = cap.yield_bonus if cap != null else 0.0
		"meter":
			b["price_bonus"] = cap.price_bonus if cap != null else 0.0
		"survey":
			b["surveyed"] = false
			if _road_near(cells):
				_do_survey(b)
			else:
				hud.toast("Survey office built — connect a Road [6] to start surveying", Color(0.9, 0.82, 0.5))

	buildings.append(b)
	for c in cells:
		occupied[c] = b
	_add_status_marker(b)
	_rebuild_components()
	_refresh_neighbours(cells)
	_update_ghost()


func _bulldoze_at(cell: Vector2i) -> void:
	if pipes.has(cell):
		var node: Node3D = pipes[cell]
		pipes.erase(cell)
		node.queue_free()
		cash += catalogue.pipe_grade_cost(int(pipe_grade.get(cell, 0))) * 0.4
		pipe_grade.erase(cell)
		_refresh_tile(cell)
		_refresh_neighbours([cell])
		_rebuild_components()
		return
	if roads.has(cell):
		_relocate_fleet_from(cell)
		var node2: Node3D = roads[cell]
		roads.erase(cell)
		node2.queue_free()
		cash += _def("road").cost * 0.4
		_refresh_tile(cell)
		_refresh_neighbours([cell])
		_rebuild_components()
		return
	if occupied.has(cell):
		var b: Dictionary = occupied[cell]
		for c in b.cells:
			occupied.erase(c)
		buildings.erase(b)
		(b.node as Node3D).queue_free()
		cash += float(_def(b.kind).cost) * 0.5
		selected_cell = Vector2i(-1, -1)
		Sfx.play("drop")
		if b.kind == "well" and deposits.has(b.origin):
			if deposits[b.origin].node != null:
				(deposits[b.origin].node as Node3D).visible = true
		_rebuild_components()
		_refresh_neighbours(b.cells)


func _refresh_neighbours(cells: Array) -> void:
	var seen := {}
	for c in cells:
		for d in DIRS:
			var n: Vector2i = (c as Vector2i) + d
			if seen.has(n):
				continue
			seen[n] = true
			if pipes.has(n) or roads.has(n):
				_refresh_tile(n)


# --------------------------------------------------------------------------- #
# pipes & roads
# --------------------------------------------------------------------------- #

func _lay_line(a: Vector2i, b: Vector2i) -> void:
	# Resolve the route first (occupancy, evenness, grade), then grade the whole
	# corridor to one height and only then place the segments. This is how real
	# graded roads/pipelines work, and it means every joint sits at the same
	# height instead of stepping with the terrain.
	var cells := _route_cells(a, b)
	if cells.is_empty():
		return
	var sum := 0.0
	for c in cells:
		var p := _cell_centre(c)
		sum += _terrain_height(p.x, p.y)
	var target := sum / float(cells.size())
	# A run that plugs into a structure must sit at that structure's pad, not at
	# the surrounding grass: otherwise the connector is buried under the pad and
	# the joint reads as "pipe passes by" instead of "pipe enters nozzle".
	target = maxf(target, _adjacent_port_pad(cells))
	_level_cells(cells, target)
	for c in cells:
		_place_infra(c)


## Highest pad among the structures this run would plug into (port side only).
func _adjacent_port_pad(cells: Array) -> float:
	var best := -1.0e9
	for c in cells:
		for d in DIRS:
			var nb: Vector2i = (c as Vector2i) + d
			if not occupied.has(nb):
				continue
			var b: Dictionary = occupied[nb]
			if (_building_port_mask(b) & _side_bit(-d)) == 0:
				continue
			best = maxf(best, float(b.get("top", -1.0e9)))
	return best


## Orthogonal (edge-adjacent) path from a to b. Bresenham would emit diagonal
## steps, and a diagonal step is not a 4-neighbour connection, so a diagonal
## drag would look connected but break the pipe run. Longest axis first.
func _line_cells(a: Vector2i, b: Vector2i, longest_first: bool = true) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var cur := a
	var length_x := absi(b.x - a.x)
	var length_y := absi(b.y - a.y)
	var step_x := 1 if b.x > a.x else -1
	var step_y := 1 if b.y > a.y else -1
	var x_first := (length_x >= length_y) == longest_first
	if x_first:
		while cur.x != b.x:
			cur.x += step_x
			out.append(cur)
		while cur.y != b.y:
			cur.y += step_y
			out.append(cur)
	else:
		while cur.y != b.y:
			cur.y += step_y
			out.append(cur)
		while cur.x != b.x:
			cur.x += step_x
			out.append(cur)
	return out


func _place_infra(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	if occupied.has(cell):
		return
	if _is_water_cell(cell):
		if time - _last_grade_warn > 1.5:
			_last_grade_warn = time
			hud.toast("Cannot build on water — level the shore first", Color(1.0, 0.6, 0.4))
			Sfx.play("error")
		return
	var dict: Dictionary = pipes if tool == "pipe" else roads
	if dict.has(cell):
		return
	# replace the other infrastructure in place (drag a pipe over a road, etc.)
	if tool == "pipe" and roads.has(cell):
		_relocate_fleet_from(cell)
		var old_road: Node3D = roads[cell]
		roads.erase(cell)
		if old_road != null:
			old_road.queue_free()
		cash += _def("road").cost * 0.4
		_refresh_neighbours([cell])
	elif tool == "road" and pipes.has(cell):
		var old_pipe: Node3D = pipes[cell]
		pipes.erase(cell)
		if old_pipe != null:
			old_pipe.queue_free()
		cash += catalogue.pipe_grade_cost(int(pipe_grade.get(cell, 0))) * 0.4
		pipe_grade.erase(cell)
		_refresh_neighbours([cell])

	# grade limit: a run cannot climb a cliff, it has to follow the contours
	var here := _cell_max_height(cell)
	if _cell_relief(cell) > MAX_INFRA_RELIEF:
		if time - _last_grade_warn > 1.5:
			_last_grade_warn = time
			hud.toast("Ground too uneven for a %s here — level it first" % tool, Color(1, 0.6, 0.4))
			Sfx.play("error")
		return
	for d in DIRS:
		var nb: Vector2i = cell + d
		if dict.has(nb) and absf(here - _cell_max_height(nb)) > MAX_GRADE:
			if time - _last_grade_warn > 1.5:
				_last_grade_warn = time
				hud.toast("Grade too steep — route the %s around the slope" % tool, Color(1, 0.6, 0.4))
				Sfx.play("error")
			return

	if tool == "pipe":
		var g := clampi(pipe_grade_choice, 0, 2)
		var cost := catalogue.pipe_grade_cost(g)
		if cash < cost:
			return
		cash -= cost
		pipe_grade[cell] = g
		pipes[cell] = _spawn_tile("pipe", cell)
	elif tool == "road":
		if cash < _def("road").cost:
			return
		cash -= _def("road").cost
		roads[cell] = _spawn_tile("road", cell)
		# a new road can start a survey office that was waiting for access
		_check_surveys()
	# the neighbour masks of this cell and its neighbours just changed
	_refresh_tile(cell)
	for d in DIRS:
		_refresh_tile(cell + d)


func _spawn_tile(kind: String, cell: Vector2i) -> Node3D:
	var prefix := "gam_pipe" if kind == "pipe" else "gam_road"
	var mask := _pipe_mask(cell) if kind == "pipe" else _neighbour_mask(cell, kind)
	var pick := _tile_for_mask(prefix, mask)
	# Tiles are authored on the 16 m grid. Pipes already overshoot the cell at
	# their end flanges (AABB ~16.75 m), so they must NOT be rescaled to the cell
	# or every joint opens a seam. Roads are exactly one cell, so nudge them a
	# little wider to close the seam.
	var pos := cell_to_world(cell)
	pos.y += 0.02
	var node: Node3D = _spawn_model(pick[0], pos, pick[1], false)
	if node == null:
		return null
	# Grow the module 3% about its OWN pivot so flanges/road ends overlap the
	# neighbour. Recentring by AABB would move corner/tee pieces off the cell and
	# break the joints; scaling about the pivot keeps every arm on the edge.
	var inst := node.get_child(0) as Node3D
	if inst != null:
		inst.scale = Vector3(1.03, 1.0, 1.03)
	if kind == "pipe":
		_apply_pipe_grade(cell, node)
		_add_pipe_connectors(node, cell, pick[1])
		_add_pipe_sleeves(node, cell)
	else:
		_add_road_connectors(node, cell, pick[1])
	if node != null:
		node.set_meta("mask", mask)
		if kind == "pipe":
			pipes_root.add_child(node)
		else:
			roads_root.add_child(node)
	return node


func _neighbour_mask(cell: Vector2i, kind: String) -> int:
	var m := 0
	var dict: Dictionary = pipes if kind == "pipe" else roads
	if dict.has(cell + Vector2i(1, 0)):
		m |= PortSpec.SIDE_E
	if dict.has(cell + Vector2i(0, -1)):
		m |= PortSpec.SIDE_N
	if dict.has(cell + Vector2i(-1, 0)):
		m |= PortSpec.SIDE_W
	if dict.has(cell + Vector2i(0, 1)):
		m |= PortSpec.SIDE_S
	return m


## Pipe shape = pipe neighbours + building ports. Without the ports a pipe tile
## next to a tank renders as a dead-end and the joint has to be faked; with them
## the tile grows a real arm that reaches the structure's pad edge.
func _pipe_mask(cell: Vector2i) -> int:
	var m := _neighbour_mask(cell, "pipe")
	for d in DIRS:
		var nb: Vector2i = cell + d
		# `d` points from the pipe to the structure, so the structure's port that
		# faces this pipe is the opposite side (same convention as NetworkSolver).
		if occupied.has(nb) and (_building_port_mask(occupied[nb]) & _side_bit(-d)) != 0:
			m |= _side_bit(d)
	return m


## Pipe-side directions of this cell that land on a declared structure port.
## The route preview uses it to show, before the player commits, where the run
## will actually plug in.
func _port_joint_at(cell: Vector2i) -> int:
	var bits := 0
	for d in DIRS:
		var nb: Vector2i = cell + d
		if occupied.has(nb) and (_building_port_mask(occupied[nb]) & _side_bit(-d)) != 0:
			bits |= _side_bit(d)
	return bits


func _building_adjacent(cell: Vector2i) -> bool:
	for d in DIRS:
		if occupied.has(cell + d):
			return true
	return false


## Distinct building sites a planned road route would serve.
func _road_preview_sites(cells: Array) -> int:
	var seen := {}
	for c in cells:
		for d in DIRS:
			var nb: Vector2i = (c as Vector2i) + d
			if occupied.has(nb):
				seen[occupied[nb]["origin"]] = true
	return seen.size()


## True when the planned road would be a served network: joining a network that
## already serves 2+ sites, or touching 2+ sites itself.
func _road_preview_served(cells: Array) -> bool:
	for c in cells:
		for d in DIRS:
			var nb: Vector2i = (c as Vector2i) + d
			if roads.has(nb) and bool(road_served.get(int(road_comp.get(nb, -1)), false)):
				return true
	return _road_preview_sites(cells) >= 2


func _road_cell_links(cell: Vector2i) -> bool:
	if _building_adjacent(cell):
		return true
	for d in DIRS:
		var nb: Vector2i = cell + d
		if roads.has(nb) and bool(road_served.get(int(road_comp.get(nb, -1)), false)):
			return true
	return false


func _route_cost(cells: Array) -> float:
	if tool == "pipe":
		return catalogue.pipe_grade_cost(pipe_grade_choice) * float(cells.size())
	var def := _def(tool)
	return def.cost * float(cells.size()) if def != null else 0.0


## If a pipe drag touches a structure, aim at its port on the approach side
## instead of the occupied cell. Placement is forgiven; the grid stays honest.
func _snap_pipe_end(from: Vector2i, target: Vector2i) -> Vector2i:
	if not occupied.has(target):
		return target
	var b: Dictionary = occupied[target]
	var mask := _building_port_mask(b)
	var best := target
	var best_d := 1.0e9
	for d in DIRS:
		if (mask & _side_bit(d)) == 0:
			continue
		var c: Vector2i = target + d
		if not _in_bounds(c) or occupied.has(c) or pipes.has(c) or roads.has(c):
			continue
		var dist := Vector2(c.x - from.x, c.y - from.y).length()
		if dist < best_d:
			best_d = dist
			best = c
	return best


## Both ends of a pipe drag, snapped to structure ports where they touch one.
func _snap_pipe_route(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var start := a
	var end := b
	if occupied.has(end):
		end = _snap_pipe_end(start, end)
	if occupied.has(start):
		start = _snap_pipe_end(end, start)
		if occupied.has(end):
			end = _snap_pipe_end(start, end)
	var out: Array[Vector2i] = [start, end]
	return out


func _refresh_tile(cell: Vector2i) -> void:
	var is_pipe := pipes.has(cell)
	var is_road := roads.has(cell)
	if not is_pipe and not is_road:
		return
	var kind := "pipe" if is_pipe else "road"
	var dict: Dictionary = pipes if is_pipe else roads
	var node: Node3D = dict[cell]
	# Pipes include structure ports in their shape, so compare against the same
	# mask they were spawned with. Otherwise a pipe laid before a structure
	# never rebuilds to grow its joint arm.
	var mask := _pipe_mask(cell) if is_pipe else _neighbour_mask(cell, kind)
	if node.get_meta("mask", -1) == mask:
		return
	node.queue_free()
	dict[cell] = _spawn_tile(kind, cell)


func _rot_mask(mask: int, steps: int) -> int:
	var m := mask
	for i in steps:
		m = ((m << 1) | (m >> 3)) & 15
	return m


func _tile_for_mask(prefix: String, mask: int) -> Array:
	var count := 0
	for b in [PortSpec.SIDE_E, PortSpec.SIDE_N, PortSpec.SIDE_W, PortSpec.SIDE_S]:
		if mask & b:
			count += 1
	var base_id := prefix + "_straight"
	var base_mask := PortSpec.SIDE_E | PortSpec.SIDE_W
	if count == 0:
		base_id = prefix + "_straight"
		base_mask = PortSpec.SIDE_W | PortSpec.SIDE_E
	elif count == 4:
		base_id = prefix + "_cross"
		base_mask = 15
	elif count == 3:
		base_id = prefix + "_tee"
		base_mask = PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W
	elif count == 2:
		var opposite: bool = mask == (PortSpec.SIDE_E | PortSpec.SIDE_W) or mask == (PortSpec.SIDE_N | PortSpec.SIDE_S)
		base_id = prefix + "_straight" if opposite else prefix + "_corner"
		base_mask = (PortSpec.SIDE_E | PortSpec.SIDE_W) if opposite else (PortSpec.SIDE_N | PortSpec.SIDE_W)
	else:
		base_id = prefix + "_straight" if prefix == "gam_road" else prefix + "_end"
		base_mask = (PortSpec.SIDE_E | PortSpec.SIDE_W) if prefix == "gam_road" else PortSpec.SIDE_W
	for steps in 4:
		if _rot_mask(base_mask, steps) == mask:
			return [base_id, float(steps * 90)]
	return [base_id, 0.0]


# --------------------------------------------------------------------------- #
# simulation
# --------------------------------------------------------------------------- #

func _process(delta: float) -> void:
	if not paused:
		_simulate(delta * speed)
		_move_fleet(delta * speed)
		_update_units(delta * speed)
		_animate_units(delta * speed)
	# feedback text keeps rising/fading even while paused or in a screenshot
	_update_float_texts(delta)
	_update_weather_visuals()
	_update_cloud_shadow(delta)
	_update_hud()


func _offer_contract() -> void:
	contract = {
		"target": randf_range(250.0, 600.0),
		"done": 0.0,
		"time": 120.0,
		"bonus": 0.15,
	}
	contract_timer = 0.0
	hud.toast("Sales contract: %d bbl in 120 s (+15%% premium)" % int(contract.target), Color(0.9, 0.85, 0.5))


func _simulate(dt: float) -> void:
	time += dt
	price = 74.0 + sin(time * 0.05) * 7.0 + sin(time * 0.31) * 2.5

	# clock, calendar and weather advance with the same speed multiplier
	if calendar != null:
		calendar.advance(dt)
	if weather != null and calendar != null:
		var changed := weather.advance(dt / calendar.day_seconds * 24.0,
			calendar.season(), calendar.daylight())
		_apply_daylight()
		if changed:
			hud.toast("Weather: %s" % weather.describe(), weather.severity_color())
		var today := calendar.day_index()
		if today != _last_calendar_day:
			_last_calendar_day = today
			hud.toast("%s · %s" % [calendar.date_label(), weather.hud_label()],
				weather.severity_color())
	if wind != null and weather != null and calendar != null:
		wind.advance(dt / calendar.day_seconds * 24.0, weather.wind_target_ms())

	if contract.is_empty():
		contract_timer -= dt
		if contract_timer <= 0.0:
			_offer_contract()
	else:
		contract.time = float(contract.time) - dt
		if float(contract.time) <= 0.0:
			hud.toast("Contract expired", Color(1, 0.6, 0.4))
			contract = {}
			contract_timer = 60.0

	var upkeep := 0.0
	for b in buildings:
		upkeep += float(b.upkeep)
	upkeep += _pipe_upkeep_total() + roads.size() * _road_upkeep()
	for unit_id in fleet.keys():
		var unit_def := _def(String(unit_id))
		if unit_def != null:
			upkeep += float(fleet[unit_id]) * unit_def.upkeep
	cash -= upkeep * dt

	var tick_income := 0.0
	for id in comp_members:
		var m: Dictionary = comp_members[id]
		if m.storages.is_empty():
			continue

		var cap := 0.0
		var stored := 0.0
		for s in m.storages:
			cap += float(s.capacity)
			stored += float(s.crude)

		# wells produce into storage, but the run's pipe capacity is the ceiling
		var prod := 0.0
		var producing: Array = []
		for w in m.wells:
			if not bool(w.get("road", true)):
				continue
			if float(w.deposit) <= 0.0:
				continue
			var p: float = minf(float(w.rate) * dt, float(w.deposit)) * _road_factor(w) \
				* _weather_prod() * _weather_logi()
			producing.append([w, p])
			prod += p
		var flow_cap := float(comp_capacity.get(id, 0.0))
		if flow_cap > 0.0 and prod > flow_cap * dt:
			var scale := (flow_cap * dt) / prod
			for e in producing:
				e[1] = float(e[1]) * scale
			prod = flow_cap * dt
		var space: float = maxf(0.0, cap - stored)
		var accepted := minf(prod, space)
		# only consume deposit for crude that actually reaches storage; a full
		# tank throttles the wells instead of silently destroying oil
		if prod > 0.00001 and accepted < prod:
			var keep := accepted / prod
			for e in producing:
				e[1] = float(e[1]) * keep
			prod = accepted
		for e in producing:
			e[0].deposit = float(e[0].deposit) - float(e[1])
		if accepted > 0.0:
			_distribute(m.storages, accepted)
		comp_load[id] = accepted / maxf(dt, 0.0001)
		comp_util[id] = clampf(comp_load[id] / flow_cap, 0.0, 1.5) if flow_cap > 0.0 else 0.0
		comp_full[id] = space <= 0.01

		# Associated gas flows with the crude. A gas plant sells it, a flare
		# burns it safely, otherwise it is vented and costs a penalty.
		var gas := accepted * catalogue.gas_ratio()
		comp_gas[id] = gas / maxf(dt, 0.0001)
		var has_plant := false
		var has_flare := false
		for p in m.get("processors", []):
			var pk := String(p.get("kind", ""))
			if pk == "gas_plant":
				has_plant = true
			elif pk == "flare":
				has_flare = true
		if gas > 0.0:
			if has_plant:
				tick_income += gas * catalogue.gas_price()
				comp_gas_state[id] = "sold"
			elif has_flare:
				tick_income += gas * catalogue.gas_price() * 0.15
				comp_gas_state[id] = "flared"
			else:
				tick_income -= gas * catalogue.gas_price() * 0.10
				comp_gas_state[id] = "vented"
		else:
			comp_gas_state.erase(id)

		# refineries draw and sell; processors and meters modify the result
		if not m.refineries.is_empty():
			var avail := 0.0
			for s in m.storages:
				avail += float(s.crude)
			var rate := 0.0
			for r in m.refineries:
				if not bool(r.get("road", true)):
					continue
				rate += float(r.throughput) * _road_factor(r) * _weather_prod() * _weather_logi()
			var yield_mult := 1.0
			for p in m.get("processors", []):
				yield_mult += float(p.get("yield_bonus", 0.0))
			var price_mult := 1.0
			for mt in m.get("meters", []):
				price_mult += float(mt.get("price_bonus", 0.0))
			var take: float = minf(avail, rate * dt)
			if take > 0.0:
				_pull(m.storages, take)
				var sold_income := take * _refined_yield() * price * yield_mult * price_mult
				if not contract.is_empty():
					var remaining := float(contract.target) - float(contract.done)
					var contracted := minf(take, remaining)
					sold_income += contracted * _refined_yield() * price * float(contract.bonus)
					contract.done = float(contract.done) + contracted
					if float(contract.done) >= float(contract.target) - 0.01:
						var bonus := float(contract.target) * price * 0.10
						sold_income += bonus
						hud.toast("Contract complete! +$%s" % hud.fmt_num(bonus), Color(0.6, 0.9, 0.6))
						Sfx.play("confirm", 1.2)
						contract = {}
						contract_timer = 90.0
				tick_income += sold_income
				comp_income_tick[id] = float(comp_income_tick.get(id, 0.0)) + sold_income

	cash += tick_income
	_income_accum += tick_income
	_income_timer += dt
	if _income_timer >= 0.5:
		income_rate = _income_accum / _income_timer
		# per-run income for the management panel (smoothed, 0 when idle)
		for id in comp_members.keys():
			var target := float(comp_income_tick.get(id, 0.0)) / _income_timer
			comp_income[id] = lerpf(float(comp_income.get(id, 0.0)), target, 0.6)
			comp_income_tick[id] = 0.0
		_income_accum = 0.0
		_income_timer = 0.0

	if not failed and not won and cash - debt < -250000.0:
		failed = true
		paused = true
		hud.show_game_over("Company value $%s — the bank has called the lease.\nLoad a save (F9) or restart." % [
			hud.fmt_num(cash - debt)])


func _distribute(storages: Array, amount: float) -> void:
	var remaining := amount
	for s in storages:
		if remaining <= 0.0:
			break
		var room: float = float(s.capacity) - float(s.crude)
		if room <= 0.0:
			continue
		var add: float = minf(room, remaining)
		s.crude = float(s.crude) + add
		remaining -= add


func _pull(storages: Array, amount: float) -> void:
	var remaining := amount
	for s in storages:
		if remaining <= 0.0:
			break
		var have := float(s.crude)
		if have <= 0.0:
			continue
		var take: float = minf(have, remaining)
		s.crude = have - take
		remaining -= take


func _uf_find(parent: Dictionary, x: int) -> int:
	var r := x
	while int(parent[r]) != r:
		r = int(parent[r])
	while int(parent[x]) != r:
		var nx := int(parent[x])
		parent[x] = r
		x = nx
	return r


func _uf_union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _uf_find(parent, a)
	var rb := _uf_find(parent, b)
	if ra != rb:
		parent[rb] = ra


func _side_bit(d: Vector2i) -> int:
	if d.x > 0:
		return PortSpec.SIDE_E
	if d.x < 0:
		return PortSpec.SIDE_W
	if d.y < 0:
		return PortSpec.SIDE_N
	return PortSpec.SIDE_S


func _ports_mask(kind: String) -> int:
	var def := _def(kind)
	return def.port_mask() if def != null else 0


## Port mask in world space, after the structure's rotation.
func _building_port_mask(b: Dictionary) -> int:
	var base := _ports_mask(String(b.kind))
	var steps := int(round(float(b.get("rot", 0)) / 90.0)) % 4
	return _rot_mask(base, steps)


func _def(kind: String) -> BuildingDefinition:
	return catalogue.find(kind)


func _build_hotkeys() -> void:
	_hotkeys.clear()
	for e in catalogue.entries:
		var code := _keycode_for(e.hotkey)
		if code != 0:
			_hotkeys[code] = e.id


func _keycode_for(s: String) -> int:
	match s:
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
		"-": return KEY_MINUS
		"=": return KEY_EQUAL
	return 0


func _pipe_upkeep() -> float:
	var d := _def("pipe")
	return d.upkeep if d != null else 0.0


func _road_upkeep() -> float:
	var d := _def("road")
	return d.upkeep if d != null else 0.0


func _refined_yield() -> float:
	var d := _def("refinery")
	return d.capacity.yield_ratio if d != null and d.capacity != null else 1.0


## Units are bought, not placed. Logistics units are stationed on a street;
## agent units (seismic/prep/hauler) start at the Field Base and take orders.
func _buy_unit(kind: String) -> void:
	var def := _def(kind)
	if def == null or def.role != "unit":
		return
	if cash < def.cost:
		hud.toast("Not enough cash for %s" % def.display_name, Color(1, 0.6, 0.4))
		Sfx.play("error")
		return
	var job := def.unit_job
	if job != "" and job != "logistics":
		var cell := _base_spawn_cell()
		if cell.x < 0:
			hud.toast("Place the Field Base first", Color(1, 0.6, 0.4))
			Sfx.play("error")
			return
		cash -= def.cost
		fleet[kind] = int(fleet.get(kind, 0)) + 1
		var node := _spawn_unit_vehicle(kind, cell, false)
		if node == null:
			cash += def.cost
			return
		fleet_units.append({"kind": kind, "cell": cell, "node": node, "job": job,
			"state": "idle", "target": Vector2i(-1, -1), "progress": 0.0,
			"carry": 0.0, "well": Vector2i(-1, -1)})
		_select_unit(fleet_units.size() - 1)
		hud.toast("%s ready — %s" % [def.display_name, _unit_instruction(job)],
			Color(0.7, 0.9, 0.6))
		Sfx.play("confirm", 1.1)
		_update_hud()
		return
	var cell := _fleet_target_cell()
	if cell.x < 0:
		hud.toast("Build a served street network before buying fleet", Color(1, 0.6, 0.4))
		Sfx.play("error")
		return
	cash -= def.cost
	fleet[kind] = int(fleet.get(kind, 0)) + 1
	var node := _spawn_unit_vehicle(kind, cell, true)
	fleet_units.append({"kind": kind, "cell": cell, "node": node, "job": "logistics",
		"state": "logistics", "target": Vector2i(-1, -1), "progress": 0.0})
	# Fleet logistics is part of road capacity, so rebuild now.
	_rebuild_components()
	hud.toast("%s → Street %d (+%.0f logi)" % [
		def.display_name, int(road_comp.get(cell, -1)), def.logistics], Color(0.7, 0.9, 0.6))
	Sfx.play("confirm", 1.1)
	_update_hud()


func _find_base() -> Dictionary:
	for b in buildings:
		if String(b.kind) == "base":
			return b
	return {}


func _base_spawn_cell() -> Vector2i:
	var base := _find_base()
	if not base.is_empty():
		var o: Vector2i = base.origin
		for d in DIRS:
			if _cell_free(o + d):
				return o + d
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var c: Vector2i = o + Vector2i(dx, dz)
				if _cell_free(c):
					return c
	var centre := Vector2i(GRID / 2, GRID / 2)
	for r in range(0, 14):
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				var c := centre + Vector2i(x, z)
				if _cell_free(c):
					return c
	return Vector2i(-1, -1)


func _find_free_area(origin: Vector2i, size: int, max_radius: int = 18) -> Vector2i:
	for r in range(0, max_radius + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := origin + Vector2i(dx, dz)
				if not _in_bounds(c):
					continue
				var cells := _cells_for(c, size)
				var ok := true
				for cc in cells:
					if not _cell_free(cc):
						ok = false
						break
				if ok:
					return c
	return Vector2i(-1, -1)


func _find_build_area(origin: Vector2i, size: int, max_radius: int = 18) -> Vector2i:
	for r in range(0, max_radius + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := origin + Vector2i(dx, dz)
				if not _in_bounds(c):
					continue
				var cells := _cells_for(c, size)
				var ok := true
				for cc in cells:
					if not _cell_free(cc):
						ok = false
						break
				if ok and _footprint_relief(cells) <= MAX_BUILD_RELIEF:
					return c
	return Vector2i(-1, -1)


func _unit_instruction(job: String) -> String:
	match job:
		"seismic":
			return "right-click to survey a 7-cell radius"
		"prep":
			return "right-click a site to prepare a 2×2 pad"
		"hauler":
			return "right-click a pumpjack to haul to the base"
	return "right-click to act here"


## One-line summary of the job the unit performs on right-click.
func _job_action_name(job: String) -> String:
	match job:
		"seismic":
			return "survey here"
		"prep":
			return "prepare site here"
		"hauler":
			return "haul from here"
	return "move here"


func _has_unit_job(job: String) -> bool:
	for u in fleet_units:
		if String(u.get("job", "")) == job:
			return true
	return false


func _selected_unit_dict() -> Dictionary:
	if selected_unit >= 0 and selected_unit < fleet_units.size():
		return fleet_units[selected_unit]
	return {}


func _show_unit_hint() -> void:
	var u := _selected_unit_dict()
	if u.is_empty():
		hud.set_hint(DEFAULT_HINT)
		return
	var def := _def(String(u.kind))
	var name := def.display_name if def != null else String(u.kind)
	var job := String(u.get("job", ""))
	if pending_action != "":
		hud.set_hint("%s — %s: click a target  ·  Esc deselects" % [
			name.to_upper(), pending_action.capitalize()])
		return
	var status := _unit_status(u)
	if status == "":
		hud.set_hint("%s — Left-click: move  ·  Right-click: %s  ·  Esc deselects" % [
			name.to_upper(), _job_action_name(job)])
	else:
		hud.set_hint("%s — %s  ·  Esc deselects" % [name.to_upper(), status])


func _unit_at_cell(cell: Vector2i) -> int:
	var p := cell_to_world(cell)
	for i in fleet_units.size():
		var node: Node3D = fleet_units[i].get("node")
		if node == null or not is_instance_valid(node):
			continue
		if world_to_cell(node.position) == cell or node.position.distance_to(p) < CELL * 0.6:
			return i
	return -1


func _select_unit(index: int) -> void:
	if index < 0 or index >= fleet_units.size():
		return
	if tool != "":
		tool = ""
		bulldoze = false
		hud.set_tool("")
		ghost.visible = false
	selected_unit = index
	pending_action = ""
	selected_cell = Vector2i(-1, -1)
	var u: Dictionary = fleet_units[index]
	var def := _def(String(u.kind))
	hud.set_unit_actions(String(u.get("job", "")),
		def.display_name if def != null else String(u.kind), true)
	_show_unit_hint()
	_update_unit_markers()
	Sfx.play("click")


func _clear_unit_selection() -> void:
	selected_unit = -1
	pending_action = ""
	_update_unit_markers()
	if hud != null:
		hud.set_unit_actions("", "", false)
		hud.set_hint(DEFAULT_HINT)


func _on_unit_action(action: String) -> void:
	if _selected_unit_dict().is_empty():
		return
	if action == "deselect":
		_clear_unit_selection()
		return
	if action == "stop":
		_stop_selected_unit()
		return
	pending_action = action
	_show_unit_hint()
	hud.toast("Click a target for: %s" % action.capitalize(), Color(1.0, 0.85, 0.5))


func _stop_selected_unit() -> void:
	var u := _selected_unit_dict()
	if u.is_empty():
		return
	_cancel_build(u)
	u.state = "idle"
	u.target = Vector2i(-1, -1)
	u.progress = 0.0
	u.order = ""
	pending_action = ""
	_show_unit_hint()
	_update_unit_markers()
	hud.toast("Unit stopped", Color(1.0, 0.8, 0.5))


## Execute the action the player selected in the unit bar. Nothing runs until an
## action is chosen and a target clicked — no automatic orders from a plain click.
func _execute_unit_action(cell: Vector2i, action: String) -> void:
	var u := _selected_unit_dict()
	if u.is_empty():
		return
	_cancel_build(u)
	var job := String(u.get("job", ""))
	match action:
		"move":
			u.order = "move"
			u.target = cell
			u.state = "moving"
			u.progress = 0.0
		"survey":
			if job != "seismic":
				hud.toast("Only the seismic vehicle surveys", Color(1.0, 0.6, 0.4))
				return
			u.order = "survey"
			u.target = cell
			u.state = "moving"
			u.progress = 0.0
		"prepare":
			if job != "prep":
				hud.toast("Only the bulldozer prepares sites", Color(1.0, 0.6, 0.4))
				return
			if _site_prepared(cell):
				hud.toast("Site is already prepared — no earthworks needed",
					Color(1.0, 0.85, 0.5))
				Sfx.play("error")
				return
			u.order = "prepare"
			u.target = cell
			u.state = "moving"
			u.progress = 0.0
		"flatten":
			if job != "prep":
				hud.toast("Only the bulldozer levels ground", Color(1.0, 0.6, 0.4))
				return
			u.order = "flatten"
			u.target = cell
			u.state = "moving"
			u.progress = 0.0
		"haul":
			if job != "hauler":
				hud.toast("Only the tanker hauls", Color(1.0, 0.6, 0.4))
				return
			if not occupied.has(cell) or _role_of(String(occupied[cell].kind)) != "producer":
				hud.toast("Tanker needs a pumpjack to load from", Color(1.0, 0.6, 0.4))
				return
			var b: Dictionary = occupied[cell]
			u.order = "haul"
			u.well = b.origin
			u.target = b.origin
			u.state = "to_well"
			u.progress = 0.0
			u.carry = 0.0
		_:
			return
	_show_unit_hint()
	_update_unit_markers()


## True only when every cell of the 2x2 site is already prepared.
func _site_prepared(cell: Vector2i) -> bool:
	for c in _cells_for(cell, 2):
		if not prepared.has(c):
			return false
	return true


## Compatibility helper for scripted tests: pick the job's natural action.
func _command_unit(cell: Vector2i) -> void:
	var u := _selected_unit_dict()
	if u.is_empty():
		return
	match String(u.get("job", "")):
		"seismic":
			_execute_unit_action(cell, "survey")
		"prep":
			_execute_unit_action(cell, "prepare")
		"hauler":
			_execute_unit_action(cell, "haul")
		_:
			_execute_unit_action(cell, "move")


## Agent update: movement, work progress, and the tanker's load/haul/unload loop.
## Also drives the on-unit and on-site feedback (start, progress, finish).
func _update_units(delta: float) -> void:
	for u in fleet_units:
		var job := String(u.get("job", "logistics"))
		if job == "logistics":
			continue
		var node: Node3D = u.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if float(u.get("done_timer", 0.0)) > 0.0:
			u.done_timer = maxf(0.0, float(u.get("done_timer", 0.0)) - delta)
			if float(u.done_timer) <= 0.0:
				u.done_text = ""
		var state := String(u.get("state", "idle"))
		if state == "moving" or state == "to_well" or state == "to_base":
			var target: Vector2i = u.get("target", Vector2i(-1, -1))
			if not _in_bounds(target):
				u.state = "idle"
				continue
			var tp := cell_to_world(target)
			tp.y += 0.05
			var from := node.position
			node.position = node.position.move_toward(tp, 14.0 * delta)
			_face_direction(node, node.position - from,
				float(node.get_meta("forward_deg", 0.0)), delta)
			if node.position.distance_to(tp) < 0.9:
				match state:
					"moving":
						var order := String(u.get("order", "move"))
						if order == "survey" or order == "prepare":
							if order == "prepare" and not _begin_prep(u):
								u.state = "idle"
								u.order = ""
							else:
								u.state = "working"
								u.progress = 0.0
								_spawn_float_text(cell_to_world(target),
									"SITE PREP STARTED" if order == "prepare" else "SURVEY STARTED",
									Color(0.75, 0.95, 1.0))
						elif order == "build":
							var bc: Vector2i = u.get("build_cell", Vector2i(-1, -1))
							if pending_builds.has(bc):
								_start_build_fx(pending_builds[bc], bc)
								u.state = "building"
								u.progress = float(pending_builds[bc].get("progress", 0.0))
								_spawn_float_text(cell_to_world(bc), "CONSTRUCTION STARTED",
									Color(0.85, 0.95, 0.6))
							else:
								u.state = "idle"
								u.order = ""
						elif order == "flatten":
							if _begin_flatten(u):
								u.state = "flattening"
								u.progress = 0.0
								_spawn_float_text(cell_to_world(target), "LEVELLING STARTED",
									Color(0.85, 0.95, 0.6))
							else:
								u.state = "idle"
								u.order = ""
						else:
							u.state = "idle"
							u.order = ""
					"to_well":
						u.state = "loading"
						u.progress = 0.0
						_spawn_float_text(cell_to_world(target), "LOADING CRUDE",
							Color(1.0, 0.9, 0.6))
					"to_base":
						u.state = "unloading"
						u.progress = 0.0
		elif state == "working" or state == "loading" or state == "unloading" or state == "building" or state == "flattening":
			u.progress = float(u.get("progress", 0.0)) + delta
			var need := _unit_need(job, state)
			# Builder: face the site and drive the construction shader preview.
			if state == "building":
				var bc: Vector2i = u.get("build_cell", Vector2i(-1, -1))
				if pending_builds.has(bc):
					var pb: Dictionary = pending_builds[bc]
					var pdef := _def(String(pb.kind))
					var site_pos := cell_to_world(bc)
					if pdef != null and pdef.footprint > 1:
						site_pos += Vector3(CELL * 0.5, 0.0, CELL * 0.5)
					_face_direction(node, site_pos - node.position,
						float(node.get_meta("forward_deg", 0.0)), delta)
					pb["progress"] = float(u.progress)
					var cmat = pb.get("cmat", null)
					if cmat != null:
						cmat.set_shader_parameter("progress",
							clampf(float(u.progress) / need, 0.0, 1.0))
			# Bulldozer: drive the serpentine lanes, stamping dirt as it goes so
			# only the ground it has worked changes (rectangular, not a wedge).
			if state == "working" and job == "prep":
				var frac := clampf(float(u.progress) / need, 0.0, 1.0)
				var level_y := lerpf(float(u.get("prep_from", 0.0)),
					float(u.get("prep_target", 0.0)), frac)
				var follow: PathFollow3D = u.get("prep_follow", null)
				var pos := Vector3.ZERO
				if follow != null and is_instance_valid(follow):
					follow.progress_ratio = frac
					pos = follow.global_position
				if pos != Vector3.ZERO:
					var prev := node.position
					pos.y = level_y + 0.10
					node.position = pos
					_face_direction(node, pos - prev,
						float(node.get_meta("forward_deg", 0.0)), delta)
					u.cell = world_to_cell(node.position)
					_stamp_prep(u, pos, 6.0)
					var tyaw := node.rotation.y
					_stamp_tread(u, pos, Vector3(cos(tyaw), 0.0, -sin(tyaw)))
					u.burst_timer = float(u.get("burst_timer", 0.0)) + delta
					if float(u.burst_timer) >= 0.8:
						u.burst_timer = 0.0
						var burst: CPUParticles3D = node.get_meta("burst") if node.has_meta("burst") else null
						if burst != null:
							burst.restart()
							burst.emitting = true
						var clods: CPUParticles3D = node.get_meta("clods") if node.has_meta("clods") else null
						if clods != null:
							clods.restart()
							clods.emitting = true
				u.prep_timer = float(u.get("prep_timer", 0.0)) + delta
				if float(u.prep_timer) >= 0.1:
					u.prep_timer = 0.0
					var pcells: Array = u.get("prep_cells", [])
					if not pcells.is_empty():
						_level_cells(pcells, level_y)
						_move_prep_patch(pcells, level_y)
			if state == "flattening":
				u.flat_timer = float(u.get("flat_timer", 0.0)) + delta
				if float(u.flat_timer) >= 0.1:
					u.flat_timer = 0.0
					var fc: Array = u.get("flat_cells", [])
					if not fc.is_empty():
						_level_cells_toward(fc, float(u.get("flat_target_y", 0.0)), 0.22)
						node.position.y = _terrain_height(node.position.x, node.position.z) + 0.05
			if float(u.progress) >= need:
				u.progress = 0.0
				if state == "flattening":
					_finish_flatten(u)
				elif state == "building":
					_finalize_build(u)
				elif state == "working":
					if job == "seismic":
						var found := _reveal_around(u.target, 7.0)
						hud.toast("Seismic survey: %d deposit%s found" % [
							found, "" if found == 1 else "s"],
							Color(0.6, 0.9, 0.6) if found > 0 else Color(1, 0.7, 0.4))
						_spawn_float_text(cell_to_world(u.target),
							"✓ %d DEPOSIT%s FOUND" % [found, "" if found == 1 else "S"],
							Color(0.6, 1.0, 0.6) if found > 0 else Color(1.0, 0.7, 0.4))
						u.done_timer = 2.4
						u.done_text = "✓ Survey done"
					elif job == "prep":
						_finish_prep(u)
					u.state = "idle"
				elif state == "loading":
					_hauler_loaded(u)
				elif state == "unloading":
					_hauler_unloaded(u)
		u.cell = world_to_cell(node.position)
		_update_unit_visuals(u)
	_update_unit_markers()


## 3x3 area levelling: a manual bulldozer job separate from building prep.
func _begin_flatten(u: Dictionary) -> bool:
	var cell: Vector2i = u.get("target", Vector2i(-1, -1))
	if not _in_bounds(cell):
		return false
	var origin := cell - Vector2i(1, 1)
	var cells: Array[Vector2i] = []
	for dx in 3:
		for dz in 3:
			var c := origin + Vector2i(dx, dz)
			if not _in_bounds(c):
				continue
			if occupied.has(c) or pipes.has(c) or roads.has(c) or pending_cells.has(c):
				hud.toast("Flatten area is occupied", Color(1.0, 0.6, 0.4))
				Sfx.play("error")
				return false
			cells.append(c)
	if cells.is_empty():
		return false
	var total := 0.0
	for c in cells:
		var p := _cell_centre(c)
		total += _terrain_height(p.x, p.y)
	var target := total / float(cells.size())
	u.flat_cells = cells
	u.flat_target_y = target
	u.flat_moved = _level_moved(cells, target)
	u.flat_timer = 0.0
	return true


func _finish_flatten(u: Dictionary) -> void:
	var cells: Array = u.get("flat_cells", [])
	u.state = "idle"
	u.order = ""
	if cells.is_empty():
		return
	var target := float(u.get("flat_target_y", 0.0))
	_level_cells(cells, target)
	var cost := float(u.get("flat_moved", 0.0)) * LEVEL_RATE
	cash -= cost
	u.flat_cells = []
	var t: Vector2i = u.get("target", Vector2i(-1, -1))
	if _in_bounds(t):
		_spawn_float_text(cell_to_world(t), "AREA LEVELLED ✓", Color(0.6, 1.0, 0.6), 46)
	u.done_timer = 2.6
	u.done_text = "✓ Area levelled"
	hud.toast("Area levelled · $%s earthworks" % hud.fmt_num(cost),
		Color(0.7, 0.9, 0.6))


## Level every terrain sample under `cells` part-way toward target_y (animated).
func _level_cells_toward(cells: Array, target_y: float, k: float) -> void:
	var n := terrain.resolution
	var cs := terrain.cell_size
	var half_span := float(n) * cs * 0.5
	var gx0 := n
	var gx1 := -1
	var gz0 := n
	var gz1 := -1
	for c in cells:
		var p := _cell_centre(c as Vector2i)
		var ax0 := clampi(int(round((p.x - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var ax1 := clampi(int(round((p.x + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az0 := clampi(int(round((p.y - CELL * 0.5 + half_span) / cs)), 0, n - 1)
		var az1 := clampi(int(round((p.y + CELL * 0.5 + half_span) / cs)), 0, n - 1)
		for gz in range(az0, az1 + 1):
			for gx in range(ax0, ax1 + 1):
				var i := gz * n + gx
				terrain.heights[i] = lerpf(terrain.heights[i], target_y, clampf(k, 0.0, 1.0))
		gx0 = mini(gx0, ax0)
		gx1 = maxi(gx1, ax1)
		gz0 = mini(gz0, az0)
		gz1 = maxi(gz1, az1)
	_sync_terrain(gx0, gx1, gz0, gz1)


## Capture the site before the bulldozer starts so the terrain can be lowered
## progressively while it works.
func _begin_prep(u: Dictionary) -> bool:
	var cell: Vector2i = u.get("target", Vector2i(-1, -1))
	if not _in_bounds(cell):
		return false
	var cells := _cells_for(cell, 2)
	if _site_prepared(cell):
		hud.toast("Site is already prepared — no earthworks needed",
			Color(1.0, 0.85, 0.5))
		return false
	for c in cells:
		if _in_bounds(c) and (occupied.has(c) or pipes.has(c) or roads.has(c)):
			hud.toast("Site is blocked", Color(1, 0.6, 0.4))
			return false
	var top := -1.0e9
	var avg := 0.0
	for c in cells:
		top = maxf(top, _cell_max_height(c))
		var p := _cell_centre(c)
		avg += _terrain_height(p.x, p.y)
	avg /= 4.0
	u.prep_cells = cells
	u.prep_from = avg
	u.prep_target = top
	u.prep_moved = _level_moved(cells, top)
	u.prep_timer = 0.0
	# drop unfinished pad tiles, but keep cells that were already prepared so a
	# re-command never wipes finished dirt back to grass
	for c in cells:
		if prepared.has(c):
			continue
		var old = prep_visuals.get(c, null)
		if old != null and is_instance_valid(old):
			old.queue_free()
		prep_visuals.erase(c)
	var old_path_prev = u.get("prep_path", null)
	if old_path_prev != null and is_instance_valid(old_path_prev):
		old_path_prev.queue_free()
	u.erase("prep_path")
	u.erase("prep_follow")
	# A paintable mask, a serpentine patrol and a shader: the dozer drives the
	# lanes and stamps dirt into the mask, so only worked ground changes.
	var bounds := _prep_bounds(cells)
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	u.prep_img = img
	u.prep_tex = tex
	u.prep_bounds = bounds
	var pm := _make_prep_material(bounds, tex)
	u.prep_mat = pm
	_add_prep_patch(cells, avg, pm)
	_move_prep_patch(cells, avg)
	var patrol := _make_patrol(bounds, top)
	# start the lanes at the dozer so it does not snap across the pad
	var start_node: Node3D = u.get("node")
	if start_node != null and is_instance_valid(start_node):
		patrol.insert(0, start_node.position)
	# Follow the lanes with Godot's Path3D/PathFollow3D instead of manual math.
	var curve := Curve3D.new()
	for p in patrol:
		curve.add_point(p)
	var path := Path3D.new()
	path.curve = curve
	markers_root.add_child(path)
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_NONE
	path.add_child(follow)
	u.prep_path = path
	u.prep_follow = follow
	return true


func _finish_prep(u: Dictionary) -> void:
	var cells: Array = u.get("prep_cells", [])
	if cells.is_empty():
		return
	var target := float(u.get("prep_target", 0.0))
	_level_cells(cells, target)
	_move_prep_patch(cells, target)
	# Densify the swept lanes but do NOT fill the whole footprint: the finished
	# site is an irregular cleared patch with grass left at the corners.
	var follow: PathFollow3D = u.get("prep_follow", null)
	if follow != null and is_instance_valid(follow):
		for k in 41:
			follow.progress_ratio = float(k) / 40.0
			_stamp_prep(u, follow.global_position, 6.0)
	# rest the dozer on the finished pad surface
	var nd: Node3D = u.get("node")
	if nd != null and is_instance_valid(nd):
		nd.position.y = target + 0.4
	# the patrol path has served its purpose
	var path: Node = u.get("prep_path", null)
	if path != null and is_instance_valid(path):
		path.queue_free()
	u.erase("prep_path")
	u.erase("prep_follow")
	for c in cells:
		prepared[c] = true
	var cost := float(u.get("prep_moved", 0.0)) * LEVEL_RATE
	cash -= cost
	_add_prep_patch(cells, target)
	var site: Vector2i = u.get("target", Vector2i(-1, -1))
	if _in_bounds(site):
		_spawn_float_text(cell_to_world(site), "SITE READY ✓", Color(0.6, 1.0, 0.6), 48)
	u.done_timer = 2.8
	u.done_text = "✓ Site ready"
	var oil_here := false
	for c in cells:
		if deposits.has(c) and bool(deposits[c].revealed):
			oil_here = true
			break
	var msg := "Site prepared (2×2) · $%s earthworks" % hud.fmt_num(cost)
	if not oil_here:
		msg += " · no oil here — survey for a deposit to drill"
	hud.toast(msg, Color(0.7, 0.9, 0.6))


## Bare-earth pad. Tiles overlap and rise slightly so no leftover terrain pokes
## through; the material wipes the dirt in with the work percentage.
func _add_prep_patch(cells: Array, y: float, mat: Material = null) -> void:
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.42, 0.32, 0.21)
		m.roughness = 1.0
		mat = m
	for c in cells:
		if prep_visuals.has(c):
			continue
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(CELL + 0.4, 0.8, CELL + 0.4)
		mi.mesh = box
		mi.material_override = mat
		var p := _cell_centre(c)
		mi.position = Vector3(p.x, y, p.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markers_root.add_child(mi)
		prep_visuals[c] = mi


## Dirt is revealed from a mask the bulldozer paints as it drives over the pad,
## so the prepared area grows exactly where the machine has worked.
const PREP_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform float min_x = 0.0;
uniform float max_x = 1.0;
uniform float min_z = 0.0;
uniform float max_z = 1.0;
uniform float uv_scale = 0.06;
uniform vec4 dirt : source_color = vec4(0.42, 0.32, 0.21, 1.0);
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : filter_linear, repeat_disable;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float nx = clamp((wpos.x - min_x) / max(max_x - min_x, 0.001), 0.0, 1.0);
	float nz = clamp((wpos.z - min_z) / max(max_z - min_z, 0.001), 0.0, 1.0);
	float m = texture(mask_tex, vec2(nx, nz)).r;
	float n = hash(floor(wpos.xz * 2.0));
	float n2 = hash(floor(wpos.xz * 7.0) + 11.0);
	float thr = 0.33 + (n - 0.5) * 0.20 + (n2 - 0.5) * 0.10;
	if (m < thr) {
		discard;
	}
	vec3 base = mix(dirt.rgb, texture(dirt_tex, wpos.xz * uv_scale).rgb, 0.85);
	float tread = texture(mask_tex, vec2(nx, nz)).g;
	base *= mix(1.0, 0.76, clamp(tread, 0.0, 1.0));
	float fresh = 1.0 - smoothstep(0.42, 0.68, m);
	base = mix(base, base * 1.12, fresh * 0.5);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""


## World rectangle covered by a prep footprint (position = near corner).
func _prep_bounds(cells: Array) -> Rect2:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for c in cells:
		var p := _cell_centre(c)
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.y)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.y)
	return Rect2(lo - Vector2(CELL * 0.5, CELL * 0.5),
		(hi - lo) + Vector2(CELL, CELL))


## Build the per-site material around a paintable mask texture. The shader is a
## real `res://shaders/prep_mask.gdshader` resource (editable in the inspector).
func _make_prep_material(bounds: Rect2, mask: Texture2D) -> ShaderMaterial:
	var sh: Shader = load("res://shaders/prep_mask.gdshader")
	if sh == null:
		sh = Shader.new()
		sh.code = PREP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("min_x", bounds.position.x)
	mat.set_shader_parameter("max_x", bounds.position.x + bounds.size.x)
	mat.set_shader_parameter("min_z", bounds.position.y)
	mat.set_shader_parameter("max_z", bounds.position.y + bounds.size.y)
	mat.set_shader_parameter("mask_tex", mask)
	var tex := load("res://assets/textures/prep_dirt.png")
	if tex is Texture2D:
		mat.set_shader_parameter("dirt_tex", tex)
	return mat


## Serpentine lane path the dozer drives over the pad (alternating direction).
func _make_patrol(bounds: Rect2, y: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var inset := 5.0
	var x0 := bounds.position.x + inset
	var x1 := bounds.position.x + bounds.size.x - inset
	var z0 := bounds.position.y + inset
	var z1 := bounds.position.y + bounds.size.y - inset
	var rows := 3
	var steps := 10
	for r in rows:
		var z := lerpf(z0, z1, float(r) / float(rows - 1))
		var forward := (r % 2) == 0
		for s in steps:
			var k := float(s) / float(steps - 1)
			var x := lerpf(x0, x1, k) if forward else lerpf(x1, x0, k)
			pts.append(Vector3(x, y, z))
	return pts


## Position along the patrol polyline for a 0..1 fraction.
func _patrol_sample(u: Dictionary, frac: float) -> Vector3:
	var patrol: PackedVector3Array = u.get("patrol", PackedVector3Array())
	var cum: PackedFloat32Array = u.get("patrol_cum", PackedFloat32Array())
	var total := float(u.get("patrol_len", 0.0))
	if patrol.size() < 2 or cum.size() < 2 or total <= 0.0:
		return Vector3.ZERO
	var want := clampf(frac, 0.0, 1.0) * total
	var idx := 0
	while idx < cum.size() - 2 and cum[idx + 1] < want:
		idx += 1
	var seg := cum[idx + 1] - cum[idx]
	var k := (want - cum[idx]) / maxf(seg, 0.0001)
	return patrol[idx].lerp(patrol[idx + 1], clampf(k, 0.0, 1.0))


## Paint a soft circle of "prepared" into the site mask at a world position.
func _stamp_prep(u: Dictionary, world_pos: Vector3, radius: float) -> void:
	var img: Image = u.get("prep_img", null)
	var tex: ImageTexture = u.get("prep_tex", null)
	var bounds: Rect2 = u.get("prep_bounds", Rect2())
	if img == null or tex == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var cx := (world_pos.x - bounds.position.x) / bounds.size.x * float(w - 1)
	var cy := (world_pos.z - bounds.position.y) / bounds.size.y * float(h - 1)
	var rx := maxf(radius / bounds.size.x * float(w), 0.8)
	var ry := maxf(radius / bounds.size.y * float(h), 0.8)
	var x0 := clampi(int(floor(cx - rx)), 0, w - 1)
	var x1 := clampi(int(ceil(cx + rx)), 0, w - 1)
	var y0 := clampi(int(floor(cy - ry)), 0, h - 1)
	var y1 := clampi(int(ceil(cy + ry)), 0, h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			var dist := dx * dx + dy * dy
			if dist <= 1.0:
				# soft edge so adjacent passes blend into one pad
				var v := clampf((1.0 - dist) * 2.5, 0.0, 1.0)
				var oldc := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(maxf(oldc.r, v), oldc.g, 0.0, 1.0))
	tex.update(img)


## Paint the two track ruts the dozer leaves, using the mask's green channel.
func _stamp_tread(u: Dictionary, world_pos: Vector3, right: Vector3) -> void:
	var img: Image = u.get("prep_img", null)
	var tex: ImageTexture = u.get("prep_tex", null)
	var bounds: Rect2 = u.get("prep_bounds", Rect2())
	if img == null or tex == null or bounds.size.x <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	for side in [-1.0, 1.0]:
		var wp: Vector3 = world_pos + right * (0.95 * float(side))
		var cx: float = (wp.x - bounds.position.x) / bounds.size.x * float(w - 1)
		var cy: float = (wp.z - bounds.position.y) / bounds.size.y * float(h - 1)
		var rr: float = maxf(0.22 / bounds.size.x * float(w), 0.7)
		var x0 := clampi(int(floor(cx - rr)), 0, w - 1)
		var x1 := clampi(int(ceil(cx + rr)), 0, w - 1)
		var y0 := clampi(int(floor(cy - rr)), 0, h - 1)
		var y1 := clampi(int(ceil(cy + rr)), 0, h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var dx: float = (float(x) - cx) / rr
				var dy: float = (float(y) - cy) / rr
				if dx * dx + dy * dy <= 1.0:
					var oldc := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(oldc.r, 0.7, 0.0, 1.0))
	tex.update(img)


func _move_prep_patch(cells: Array, y: float) -> void:
	for c in cells:
		var pv: Node3D = prep_visuals.get(c)
		if pv != null:
			var p := _cell_centre(c)
			pv.position = Vector3(p.x, y, p.y)


func _hauler_loaded(u: Dictionary) -> void:
	var well: Vector2i = u.get("well", Vector2i(-1, -1))
	if not occupied.has(well) or _role_of(String(occupied[well].kind)) != "producer":
		u.state = "idle"
		hud.toast("Tanker: well is gone", Color(1, 0.6, 0.4))
		return
	var b: Dictionary = occupied[well]
	var take := minf(60.0, float(b.deposit))
	if take <= 0.0:
		u.state = "idle"
		hud.toast("Tanker: well is depleted", Color(1, 0.6, 0.4))
		return
	b.deposit = float(b.deposit) - take
	u.carry = take
	if _in_bounds(well):
		_spawn_float_text(cell_to_world(well), "LOADED %d bbl" % int(take),
			Color(1.0, 0.9, 0.55))
	var base := _find_base()
	if base.is_empty():
		u.state = "idle"
		return
	u.target = base.origin
	u.state = "to_base"


func _hauler_unloaded(u: Dictionary) -> void:
	var bbl := float(u.get("carry", 0.0))
	var sold := bbl * price * 0.85
	cash += sold
	u.carry = 0.0
	var base := _find_base()
	if not base.is_empty():
		_spawn_float_text(cell_to_world(base.origin), "+$%s SOLD" % hud.fmt_num(sold),
			Color(0.55, 1.0, 0.55), 44)
	u.done_timer = 1.8
	u.done_text = "+$%s" % hud.fmt_num(sold)
	hud.toast("Tanker sold %d bbl crude · +$%s" % [int(bbl), hud.fmt_num(sold)], Color(0.6, 0.9, 0.6))
	var well: Vector2i = u.get("well", Vector2i(-1, -1))
	if occupied.has(well) and float(occupied[well].deposit) > 0.0:
		u.target = well
		u.state = "to_well"
	else:
		u.state = "idle"


func _build_unit_markers() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.4
	ring_mesh.outer_radius = 3.0
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	unit_ring = MeshInstance3D.new()
	unit_ring.mesh = ring_mesh
	var um := StandardMaterial3D.new()
	um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	um.no_depth_test = true
	um.albedo_color = Color(1.0, 0.9, 0.2, 0.95)
	unit_ring.material_override = um
	unit_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	unit_ring.visible = false
	add_child(unit_ring)

	# tall beacon so the selection is obvious even over tall buildings
	selection_beam = MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.15
	scyl.bottom_radius = 0.7
	scyl.height = 7.0
	selection_beam.mesh = scyl
	var sbm := StandardMaterial3D.new()
	sbm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sbm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sbm.albedo_color = Color(1.0, 0.9, 0.25, 0.30)
	selection_beam.material_override = sbm
	selection_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection_beam.visible = false
	add_child(selection_beam)

	var target_mesh := TorusMesh.new()
	target_mesh.inner_radius = 1.1
	target_mesh.outer_radius = 1.35
	target_mesh.rings = 24
	target_mesh.ring_segments = 8
	target_ring = MeshInstance3D.new()
	target_ring.mesh = target_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.albedo_color = Color(0.4, 0.9, 1.0, 0.85)
	target_ring.material_override = tm
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_ring.visible = false
	add_child(target_ring)

	unit_label = Label3D.new()
	unit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	unit_label.no_depth_test = true
	unit_label.font_size = 36
	unit_label.pixel_size = 0.035
	unit_label.outline_size = 10
	unit_label.outline_modulate = Color(0.05, 0.06, 0.04, 0.9)
	unit_label.modulate = Color(1.0, 0.95, 0.7)
	unit_label.visible = false
	add_child(unit_label)


func _update_unit_markers() -> void:
	if unit_ring == null:
		return
	var u := _selected_unit_dict()
	var node: Node3D = u.get("node") if not u.is_empty() else null
	if u.is_empty() or node == null or not is_instance_valid(node):
		unit_ring.visible = false
		target_ring.visible = false
		unit_label.visible = false
		if selection_beam != null:
			selection_beam.visible = false
		return
	unit_ring.visible = true
	unit_ring.position = node.position + Vector3(0.0, 0.6, 0.0)
	var pulse := 1.0 + 0.07 * sin(Time.get_ticks_msec() * 0.006)
	unit_ring.scale = Vector3(pulse, 1.0, pulse)
	if selection_beam != null:
		selection_beam.visible = true
		selection_beam.position = node.position + Vector3(0.0, 3.5, 0.0)
	var state := String(u.get("state", "idle"))
	var def := _def(String(u.kind))
	# a floating name tag makes the selection unmistakable
	unit_label.text = "▸ " + (def.display_name if def != null else String(u.kind))
	unit_label.visible = true
	unit_label.position = node.position + Vector3(0.0, 4.6, 0.0)
	var target: Vector2i = u.get("target", Vector2i(-1, -1))
	if _in_bounds(target) and state != "idle" and state != "logistics":
		target_ring.visible = true
		var tp := cell_to_world(target)
		target_ring.position = Vector3(tp.x, tp.y + 0.08, tp.z)
	else:
		target_ring.visible = false


## --- unit feedback --------------------------------------------------------- #

## Every agent unit owns two labels: one pinned above the unit (its current
## state/progress) and one pinned to the job site on the ground.
func _ensure_unit_labels(u: Dictionary) -> void:
	var node: Node3D = u.get("node")
	if node == null or not is_instance_valid(node):
		return
	var status = node.get_meta("status") if node.has_meta("status") else null
	if status == null or not is_instance_valid(status):
		var sl := Label3D.new()
		sl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sl.no_depth_test = true
		sl.font_size = 30
		sl.pixel_size = 0.028
		sl.outline_size = 9
		sl.outline_modulate = Color(0.03, 0.04, 0.03, 0.9)
		sl.modulate = Color(0.92, 0.96, 0.82)
		sl.position = Vector3(0.0, 2.9, 0.0)
		sl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(sl)
		node.set_meta("status", sl)
	var site = u.get("site", null)
	if site == null or not is_instance_valid(site):
		var wl := Label3D.new()
		wl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		wl.no_depth_test = true
		wl.font_size = 34
		wl.pixel_size = 0.03
		wl.outline_size = 10
		wl.outline_modulate = Color(0.03, 0.04, 0.03, 0.9)
		wl.modulate = Color(0.7, 0.95, 1.0)
		wl.visible = false
		wl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markers_root.add_child(wl)
		u["site"] = wl


func _unit_need(job: String, state: String) -> float:
	if state == "working":
		return 14.0 if job == "prep" else 3.0
	if state == "building":
		return 10.0
	if state == "flattening":
		return 6.0
	if state == "loading" or state == "unloading":
		return 1.5
	return 1.0


func _unit_progress_pct(u: Dictionary) -> int:
	var need := _unit_need(String(u.get("job", "")), String(u.get("state", "idle")))
	return int(clampf(float(u.get("progress", 0.0)) / need, 0.0, 1.0) * 100.0)


## Short state line shown above the unit itself.
func _unit_status(u: Dictionary) -> String:
	var job := String(u.get("job", ""))
	var state := String(u.get("state", "idle"))
	var pct := _unit_progress_pct(u)
	match state:
		"moving":
			return "▶ Moving"
		"to_well":
			return "→ To well"
		"to_base":
			return "→ To base"
		"working":
			return ("Preparing… %d%%" if job == "prep" else "Surveying… %d%%") % pct
		"building":
			return "Building… %d%%" % pct
		"flattening":
			return "Flattening… %d%%" % pct
		"loading":
			return "Loading… %d%%" % pct
		"unloading":
			return "Selling… %d%%" % pct
		"idle":
			if float(u.get("done_timer", 0.0)) > 0.0:
				return String(u.get("done_text", "✓ Done"))
			return ""
	return ""


## Progress line pinned to the job location on the ground.
func _site_status(u: Dictionary) -> String:
	var job := String(u.get("job", ""))
	var state := String(u.get("state", "idle"))
	var pct := _unit_progress_pct(u)
	match state:
		"working":
			return ("SITE PREP %d%%" if job == "prep" else "SURVEY %d%%") % pct
		"building":
			return "BUILDING %d%%" % pct
		"flattening":
			return "FLATTEN %d%%" % pct
		"loading":
			return "LOADING %d%%" % pct
		"unloading":
			return "SELLING %d%%" % pct
		"moving", "to_well":
			return "EN ROUTE"
		"to_base":
			return "TO BASE"
		"idle":
			if float(u.get("done_timer", 0.0)) > 0.0:
				return String(u.get("done_text", "✓ DONE"))
			return ""
	return ""


func _update_unit_visuals(u: Dictionary) -> void:
	_ensure_unit_labels(u)
	var node: Node3D = u.get("node")
	if node == null or not is_instance_valid(node):
		return
	var state := String(u.get("state", "idle"))
	var status: Label3D = node.get_meta("status") if node.has_meta("status") else null
	if status != null and is_instance_valid(status):
		status.text = _unit_status(u)
		status.visible = status.text != ""
		if state == "working":
			status.modulate = Color(0.78, 1.0, 0.7)
		elif state == "loading" or state == "unloading":
			status.modulate = Color(1.0, 0.88, 0.55)
		elif state == "idle":
			status.modulate = Color(0.55, 1.0, 0.55)
		else:
			status.modulate = Color(0.85, 0.92, 1.0)
	var site: Label3D = u.get("site", null)
	if site == null or not is_instance_valid(site):
		return
	var target: Vector2i = u.get("target", Vector2i(-1, -1))
	if state == "building":
		var bc: Vector2i = u.get("build_cell", Vector2i(-1, -1))
		if _in_bounds(bc):
			target = bc
	var show_site := _in_bounds(target) \
		and (state != "idle" or float(u.get("done_timer", 0.0)) > 0.0)
	site.visible = show_site
	if show_site:
		var tp := cell_to_world(target)
		# sit the site tag beside the work cell so it does not overlap the unit
		site.position = Vector3(tp.x + CELL * 0.9, tp.y + 1.1, tp.z)
		site.text = _site_status(u)
		site.modulate = Color(0.55, 1.0, 0.55) if state == "idle" else Color(0.7, 0.95, 1.0)


## World-space text that rises and fades: job started / finished feedback.
func _spawn_float_text(world_pos: Vector3, text: String, color: Color, size: int = 42) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = 0.03
	l.outline_size = 12
	l.outline_modulate = Color(0.03, 0.04, 0.03, 0.92)
	l.modulate = color
	l.position = world_pos + Vector3(0.0, 2.0, 0.0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markers_root.add_child(l)
	_float_texts.append({"label": l, "t": 0.0, "life": 2.0,
		"from": world_pos + Vector3(0.0, 2.0, 0.0)})


func _update_float_texts(delta: float) -> void:
	for i in range(_float_texts.size() - 1, -1, -1):
		var f: Dictionary = _float_texts[i]
		f.t = float(f.t) + delta
		var k := float(f.t) / float(f.life)
		var l: Label3D = f.label
		if l == null or not is_instance_valid(l) or k >= 1.0:
			if l != null and is_instance_valid(l):
				l.queue_free()
			_float_texts.remove_at(i)
			continue
		l.position = (f.from as Vector3) + Vector3(0.0, 2.6 * k, 0.0)
		l.modulate.a = clampf(1.0 - k * k, 0.0, 1.0)


func _clear_float_texts() -> void:
	for f in _float_texts:
		var l: Label3D = f.label
		if l != null and is_instance_valid(l):
			l.queue_free()
	_float_texts.clear()


## Procedural unit animation. The pivot keeps movement/facing; the model child is
## animated: driving rumble, a thumper pulse while surveying, and a visible
## patrol + blade shove while bulldozing. The prep shader is advanced every frame.
func _animate_units(delta: float) -> void:
	for u in fleet_units:
		var node: Node3D = u.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var inst := node.get_child(0) as Node3D
		if inst == null:
			continue
		if not u.has("anim_base"):
			u["anim_base"] = inst.position
			u["anim_rot"] = inst.rotation
		u["anim_t"] = float(u.get("anim_t", 0.0)) + delta
		var t := float(u["anim_t"])
		var state := String(u.get("state", "idle"))
		var job := String(u.get("job", ""))
		var base: Vector3 = u["anim_base"]
		var base_rot: Vector3 = u["anim_rot"]
		# a faint idle engine tremble so a parked unit never looks frozen
		var bob := 0.008 * sin(t * 20.0)
		var pitch := 0.0
		var roll := 0.0
		var push := 0.0
		var lift := 0.0
		var sway := 0.0
		if state == "moving" or state == "to_well" or state == "to_base":
			bob = 0.05 * sin(t * 18.0)
			pitch = 0.035 * sin(t * 13.0)
			roll = 0.02 * sin(t * 9.0)
			sway = 0.03 * sin(t * 7.0)
		elif state == "working":
			if job == "prep":
				# the pivot is driven along the patrol lanes by _update_units; the
				# model adds a blade shove/lurch and engine rumble on top
				var lurch := maxf(0.0, sin(t * 6.4))
				push = 0.22 * sin(t * 3.2) + 0.16 * lurch
				bob = 0.045 * sin(t * 20.0)
				pitch = 0.05 * sin(t * 3.2) + 0.03 * lurch
				roll = 0.02 * sin(t * 7.0)
				lift = 0.30   # ride on top of the raised dirt pad
			else:
				bob = 0.08 * absf(sin(t * 12.0))
				roll = 0.04 * sin(t * 12.0)
		elif state == "loading" or state == "unloading":
			bob = 0.03 * sin(t * 8.0)
			pitch = 0.02 * sin(t * 8.0)
		elif state == "flattening":
			push = 0.25 * sin(t * 6.0)
			bob = 0.04 * sin(t * 20.0)
			pitch = 0.05 * sin(t * 6.0)
			roll = 0.02 * sin(t * 6.0)
		elif state == "building":
			bob = 0.02 * sin(t * 9.0)
			pitch = 0.012 * sin(t * 9.0)
		inst.position = base + Vector3(0.0, bob + lift, push)
		inst.rotation.x = base_rot.x + pitch
		inst.rotation.z = base_rot.z + roll
		inst.rotation.y = base_rot.y + sway
		# animate the Blender crane boom: fold while driving, reach over the site
		if node.has_meta("boom"):
			var boom: Node3D = node.get_meta("boom")
			if boom != null and is_instance_valid(boom):
				var target_boom := deg_to_rad(28.0)
				if state == "building":
					target_boom = deg_to_rad(32.0 - 20.0 * sin(t * 2.2))
				elif state == "moving" or state == "to_well" or state == "to_base":
					target_boom = deg_to_rad(64.0)
				boom.rotation.x = lerp_angle(boom.rotation.x, target_boom,
					clampf(3.0 * delta, 0.0, 1.0))
		var dust: CPUParticles3D = node.get_meta("dust") if node.has_meta("dust") else null
		if dust != null:
			dust.emitting = (state == "working" and job == "prep") or state == "flattening"
			dust.position = Vector3(0.0, 0.4, push + 1.2)


## Company-wide fleet logistics (display only; capacity is per network).
func _fleet_logistics() -> float:
	var total := 0.0
	for u in fleet_units:
		var def := _def(String(u.kind))
		if def != null:
			total += def.logistics
	return total


## Logistics stationed on one street network.
func _fleet_logistics_for(net_id: int) -> float:
	var total := 0.0
	for u in fleet_units:
		var cell: Vector2i = u.cell
		if not roads.has(cell):
			continue
		if int(road_comp.get(cell, -1)) != net_id:
			continue
		var def := _def(String(u.kind))
		if def != null:
			total += def.logistics
	return total


func _fleet_units_on(net_id: int) -> int:
	var n := 0
	for u in fleet_units:
		if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == net_id:
			n += 1
	return n


## Where a newly bought unit should be stationed: the selected served road, or
## the busiest served network when nothing is selected.
func _fleet_target_cell() -> Vector2i:
	if roads.has(selected_cell) \
			and bool(road_served.get(int(road_comp.get(selected_cell, -1)), false)):
		return selected_cell
	var best := Vector2i(-1, -1)
	var best_ratio := -1.0
	for c in roads.keys():
		var id := int(road_comp.get(c, -1))
		if not bool(road_served.get(id, false)):
			continue
		var cap := float(road_capacity.get(id, 0.0))
		var load := float(road_load.get(id, 0.0))
		var ratio := load / cap if cap > 0.0 else 0.0
		if ratio > best_ratio:
			best_ratio = ratio
			best = c
	return best


## Move one unit from the busiest other street to the selected street.
func _transfer_fleet_here() -> void:
	if not roads.has(selected_cell):
		hud.toast("Select a road on the receiving street", Color(1, 0.6, 0.4))
		return
	var dst := int(road_comp.get(selected_cell, -1))
	if not bool(road_served.get(dst, false)):
		hud.toast("The receiving street must serve 2+ sites", Color(1, 0.6, 0.4))
		return
	var donor := -1
	var donor_count := 0
	for u in fleet_units:
		if not roads.has(u.cell):
			continue
		var id := int(road_comp.get(u.cell, -1))
		if id == dst:
			continue
		var count := 0
		for v in fleet_units:
			if roads.has(v.cell) and int(road_comp.get(v.cell, -1)) == id:
				count += 1
		if count > donor_count:
			donor_count = count
			donor = id
	if donor < 0:
		hud.toast("No fleet on another street to transfer", Color(1, 0.6, 0.4))
		return
	var target := Vector2i(-1, -1)
	for c in roads.keys():
		if int(road_comp.get(c, -1)) == dst:
			target = c
			break
	if target.x < 0:
		return
	for u in fleet_units:
		if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == donor:
			u.cell = target
			break
	_rebuild_components()
	_respawn_fleet()
	hud.toast("Fleet transferred to Street %d" % dst, Color(0.7, 0.9, 0.6))
	Sfx.play("confirm", 1.05)


## Demolish the whole pipe run or street network under the selection, with the
## same refunds as cell bulldozing. Much faster than dragging X over a long run.
func _demolish_selected_network() -> void:
	if pipes.has(selected_cell):
		var cid := int(pipe_comp.get(selected_cell, -1))
		var cells: Array[Vector2i] = []
		for c in pipes.keys():
			if int(pipe_comp.get(c, -1)) == cid:
				cells.append(c)
		var refund := 0.0
		for c in cells:
			var node: Node3D = pipes[c]
			pipes.erase(c)
			if node != null:
				node.queue_free()
			refund += catalogue.pipe_grade_cost(int(pipe_grade.get(c, 0))) * 0.4
			pipe_grade.erase(c)
		cash += refund
		_refresh_neighbours(cells)
		_rebuild_components()
		selected_cell = Vector2i(-1, -1)
		_rebuild_run_highlight()
		hud.toast("Pipeline demolished (%d cells) · +$%s" % [
			cells.size(), hud.fmt_num(refund)], Color(0.9, 0.8, 0.55))
		Sfx.play("drop")
		return
	if roads.has(selected_cell):
		var cid := int(road_comp.get(selected_cell, -1))
		var cells: Array[Vector2i] = []
		for c in roads.keys():
			if int(road_comp.get(c, -1)) == cid:
				cells.append(c)
		var refund := 0.0
		var i := 0
		while i < fleet_units.size():
			var u: Dictionary = fleet_units[i]
			if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == cid:
				var def := _def(String(u.kind))
				if def != null:
					refund += def.cost * 0.5
				var k := String(u.kind)
				fleet[k] = maxi(0, int(fleet.get(k, 0)) - 1)
				fleet_units.remove_at(i)
			else:
				i += 1
		for c in cells:
			var node2: Node3D = roads[c]
			roads.erase(c)
			if node2 != null:
				node2.queue_free()
			refund += _def("road").cost * 0.4
		cash += refund
		_refresh_neighbours(cells)
		_rebuild_components()
		_respawn_fleet()
		selected_cell = Vector2i(-1, -1)
		_rebuild_run_highlight()
		hud.toast("Street network demolished (%d cells) · +$%s" % [
			cells.size(), hud.fmt_num(refund)], Color(0.9, 0.8, 0.55))
		Sfx.play("drop")
		return
	hud.toast("Select a pipe or road cell first", Color(1, 0.6, 0.4))


func _served_road_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in roads.keys():
		if bool(road_served.get(int(road_comp.get(c, -1)), false)):
			out.append(c)
	return out


## Spawn one unit. Logistics units are road-bound; agent units may start off-road.
func _spawn_unit_vehicle(kind: String, at_cell: Vector2i = Vector2i(-1, -1),
		require_road: bool = true) -> Node3D:
	var def := _def(kind)
	if def == null or def.model_id == "":
		return null
	var cell := at_cell
	if require_road:
		if not (roads.has(cell) and bool(road_served.get(int(road_comp.get(cell, -1)), false))):
			var cells := _served_road_cells()
			if cells.is_empty():
				return null
			cell = cells[randi() % cells.size()]
	elif not _in_bounds(cell):
		return null
	var pos := cell_to_world(cell)
	pos.y += 0.05
	# Kit vehicles are authored -Y forward in Blender, which is +Z in Godot.
	var node := _spawn_model(def.model_id, pos, 0.0, true, CELL * 0.36)
	if node == null:
		return null
	node.set_meta("kind", kind)
	node.set_meta("job", def.unit_job)
	node.set_meta("forward_deg", def.forward_deg)
	if require_road and roads.has(cell):
		node.set_meta("net", int(road_comp.get(cell, -1)))
	markers_root.add_child(node)
	fleet_nodes.append(node)
	node.set_meta("target", node.position)
	# the Blender crane truck has a separate Boom node we can animate
	var boom := node.find_child("Boom", true, false)
	if boom is Node3D:
		node.set_meta("boom", boom)
	if def.unit_job == "prep":
		# soft, translucent dust that fades with age (vertex-colour ramp)
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		ramp.colors = PackedColorArray([
			Color(0.85, 0.80, 0.70, 0.0),
			Color(0.85, 0.80, 0.70, 0.5),
			Color(0.85, 0.80, 0.70, 0.0)])
		var dust := CPUParticles3D.new()
		dust.amount = 90
		dust.lifetime = 0.9
		dust.preprocess = 1.0
		dust.one_shot = false
		dust.emitting = false
		dust.direction = Vector3(0, 1, -0.25)
		dust.spread = 70.0
		dust.gravity = Vector3(0, -2.0, 0)
		dust.initial_velocity_min = 1.0
		dust.initial_velocity_max = 2.6
		dust.scale_amount_min = 0.3
		dust.scale_amount_max = 0.85
		dust.color_ramp = ramp
		var dm := SphereMesh.new()
		dm.radius = 0.5
		dm.height = 1.0
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(1, 1, 1, 1)
		dmat.vertex_color_use_as_albedo = true
		dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.material = dmat
		dust.mesh = dm
		dust.position = Vector3(0, 0.6, 1.2)
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(dust)
		node.set_meta("dust", dust)
		# periodic heavier puff (dig/spill) at the blade
		var burst := CPUParticles3D.new()
		burst.amount = 22
		burst.lifetime = 0.8
		burst.one_shot = true
		burst.explosiveness = 0.9
		burst.emitting = false
		burst.direction = Vector3(0, 1, 0.2)
		burst.spread = 80.0
		burst.gravity = Vector3(0, -2.5, 0)
		burst.initial_velocity_min = 1.6
		burst.initial_velocity_max = 3.4
		burst.scale_amount_min = 0.4
		burst.scale_amount_max = 1.1
		burst.color_ramp = ramp
		var bm := SphereMesh.new()
		bm.radius = 0.5
		bm.height = 1.0
		bm.material = dmat
		burst.mesh = bm
		burst.position = Vector3(0, 0.5, 1.1)
		burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(burst)
		node.set_meta("burst", burst)
		# dirt clods thrown from the blade
		var clods := CPUParticles3D.new()
		clods.amount = 18
		clods.lifetime = 1.1
		clods.one_shot = true
		clods.explosiveness = 0.95
		clods.emitting = false
		clods.direction = Vector3(0, 1, 0.3)
		clods.spread = 55.0
		clods.gravity = Vector3(0, -9.0, 0)
		clods.initial_velocity_min = 3.0
		clods.initial_velocity_max = 6.5
		clods.scale_amount_min = 0.7
		clods.scale_amount_max = 1.6
		var cm := BoxMesh.new()
		cm.size = Vector3(0.22, 0.22, 0.22)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.30, 0.22, 0.14)
		cmat.roughness = 1.0
		cm.material = cmat
		clods.mesh = cm
		clods.position = Vector3(0, 0.5, 1.0)
		clods.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(clods)
		node.set_meta("clods", clods)
	return node


## Point a vehicle along its actual travel direction. look_at() faces -Z, while
## the kit vehicles face +Z, so the old code drove every truck backwards.
func _face_direction(node: Node3D, direction: Vector3, forward_deg: float, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var yaw := atan2(flat.x, flat.z) + deg_to_rad(forward_deg)
	node.rotation.y = lerp_angle(node.rotation.y, yaw, clampf(8.0 * delta, 0.0, 1.0))


## Logistics units drive between served road cells; agents are driven by jobs.
func _move_fleet(delta: float) -> void:
	if fleet_nodes.is_empty():
		return
	var all_cells := _served_road_cells()
	if all_cells.is_empty():
		return
	for node in fleet_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if String(node.get_meta("job", "logistics")) != "logistics":
			continue
		var cells := all_cells
		var net_id := int(node.get_meta("net", -1))
		if net_id >= 0:
			var own: Array[Vector2i] = []
			for c in all_cells:
				if int(road_comp.get(c, -1)) == net_id:
					own.append(c)
			if not own.is_empty():
				cells = own
		var target: Vector3 = node.get_meta("target", node.position)
		if node.position.distance_to(target) < 0.6:
			var cell: Vector2i = cells[randi() % cells.size()]
			target = cell_to_world(cell)
			target.y += 0.05
			node.set_meta("target", target)
		if node.position.distance_to(target) > 0.1:
			var from := node.position
			node.position = node.position.move_toward(target, 9.0 * delta)
			_face_direction(node, node.position - from,
				float(node.get_meta("forward_deg", 0.0)), delta)


func _respawn_fleet() -> void:
	for n in fleet_nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	fleet_nodes.clear()
	for u in fleet_units:
		var old_site = u.get("site", null)
		if old_site != null and is_instance_valid(old_site):
			old_site.queue_free()
		u.erase("site")
		var old_path = u.get("prep_path", null)
		if old_path != null and is_instance_valid(old_path):
			old_path.queue_free()
		u.erase("prep_path")
		u.erase("prep_follow")
		var job := String(u.get("job", "logistics"))
		u["node"] = _spawn_unit_vehicle(String(u.kind), u.cell, job == "logistics")


## Move units off a road cell that is about to be removed. They re-station on
## another cell of the same network, or are refunded if the network disappears.
func _relocate_fleet_from(cell: Vector2i) -> void:
	var cid := int(road_comp.get(cell, -1))
	var replacement := Vector2i(-1, -1)
	for c in roads.keys():
		if c == cell:
			continue
		if int(road_comp.get(c, -1)) == cid:
			replacement = c
			break
	var moved := false
	var i := 0
	while i < fleet_units.size():
		var u: Dictionary = fleet_units[i]
		if u.cell == cell:
			if replacement.x >= 0:
				u.cell = replacement
				moved = true
				i += 1
			else:
				var def := _def(String(u.kind))
				if def != null:
					cash += def.cost * 0.5
				var k := String(u.kind)
				fleet[k] = maxi(0, int(fleet.get(k, 0)) - 1)
				fleet_units.remove_at(i)
				moved = true
		else:
			i += 1
	if moved:
		_respawn_fleet()


func _sides_text(bits: int) -> String:
	var out: Array[String] = []
	if bits & PortSpec.SIDE_E:
		out.append("E")
	if bits & PortSpec.SIDE_N:
		out.append("N")
	if bits & PortSpec.SIDE_W:
		out.append("W")
	if bits & PortSpec.SIDE_S:
		out.append("S")
	return " ".join(out) if not out.is_empty() else "none"


## Sides of this building that actually have a pipe touching a port.
func _connected_sides(b: Dictionary) -> int:
	var bits := 0
	var allowed := _building_port_mask(b)
	for cell in b.cells:
		for d in DIRS:
			if (allowed & _side_bit(d)) == 0:
				continue
			if pipes.has((cell as Vector2i) + d):
				bits |= _side_bit(d)
	return bits


## Roads only grant access when the network serves at least two sites. A lone
## stub beside one building is not a road connection; it has to connect sites.
func _rebuild_roads() -> void:
	road_comp.clear()
	road_served.clear()
	road_capacity.clear()
	road_load.clear()
	road_isolated_cells = 0
	var net_sizes: Dictionary = {}
	var net_loads: Dictionary = {}
	var net_boosts: Dictionary = {}
	var net_served: Dictionary = {}
	var next_id := 0
	for start in roads.keys():
		if road_comp.has(start):
			continue
		var queue: Array = [start]
		road_comp[start] = next_id
		var net: Array = []
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			net.append(c)
			for d in DIRS:
				var n: Vector2i = c + d
				if roads.has(n) and not road_comp.has(n):
					road_comp[n] = next_id
					queue.append(n)
		var sites := 0
		var seen: Dictionary = {}
		var load := 0.0
		var boost := 0.0
		for rc in net:
			for d in DIRS:
				var nb: Vector2i = (rc as Vector2i) + d
				if occupied.has(nb):
					var bb: Dictionary = occupied[nb]
					var origin: Vector2i = bb["origin"]
					if not seen.has(origin):
						seen[origin] = true
						sites += 1
						var bd := _def(bb.kind)
						if bd != null:
							load += bd.logistics
							boost += bd.network_boost
		net_sizes[next_id] = net.size()
		net_loads[next_id] = load
		net_boosts[next_id] = boost
		net_served[next_id] = sites >= 2
		if sites < 2:
			road_isolated_cells += net.size()
		next_id += 1

	# Capacity is a second pass: fleet units are stationed on road cells, so the
	# whole road_comp map must exist before a network can count its trucks.
	var road_def := _def("road")
	for id in net_sizes.keys():
		var cap := 0.0
		if road_def != null and road_def.capacity != null:
			cap = road_def.capacity.road_base \
				+ road_def.capacity.road_per_cell * float(net_sizes[id]) \
				+ _fleet_logistics_for(int(id)) \
				+ float(net_boosts.get(int(id), 0.0))
		road_capacity[int(id)] = cap
		road_load[int(id)] = float(net_loads[int(id)])
		road_served[int(id)] = bool(net_served[int(id)])


func _has_road(b: Dictionary) -> bool:
	for cell in b.cells:
		for d in DIRS:
			var n: Vector2i = (cell as Vector2i) + d
			if roads.has(n) and bool(road_served.get(int(road_comp.get(n, -1)), false)):
				return true
	return false


## Throughput multiplier for a site whose road network is over capacity.
func _weather_prod() -> float:
	return weather.production_factor() if weather != null else 1.0


func _weather_logi() -> float:
	return weather.logistics_factor() if weather != null else 1.0


func _road_factor(b: Dictionary) -> float:
	for cell in b.cells:
		for d in DIRS:
			var n: Vector2i = (cell as Vector2i) + d
			if not roads.has(n):
				continue
			var cid := int(road_comp.get(n, -1))
			if not bool(road_served.get(cid, false)):
				continue
			var cap := float(road_capacity.get(cid, 0.0))
			var load := float(road_load.get(cid, 0.0))
			if load <= 0.0 or cap >= load:
				return 1.0
			return cap / load
	return 1.0


func _rebuild_components() -> void:
	var solved := NetworkSolver.solve(pipes, buildings, DIRS, _building_port_mask,
		_pipe_cell_capacity, _pipe_run_capacity, _role_of,
		_pipe_cell_height, _pipe_cell_grade)
	pipe_comp = solved.pipe_comp
	comp_members = solved.members
	comp_capacity = solved.capacity
	comp_cells = solved.get("cells", {})
	comp_min_cap = solved.get("min_cap", {})
	comp_boost = solved.get("boost", {})
	comp_bottleneck = solved.get("bottleneck", {})
	comp_relief = solved.get("relief", {})
	comp_pressure = {}
	var grades: Dictionary = solved.get("min_grade", {})
	for id in comp_capacity.keys():
		comp_pressure[id] = catalogue.pipe_run_pressure(
			int(comp_cells.get(id, 0)), float(comp_boost.get(id, 0.0)),
			float(comp_relief.get(id, 0.0)), int(grades.get(id, 0)))
	# drop telemetry for runs that no longer exist
	for id in comp_income.keys():
		if not comp_members.has(int(id)) and not comp_capacity.has(int(id)):
			comp_income.erase(id)
	for id in comp_income_tick.keys():
		if not comp_members.has(int(id)) and not comp_capacity.has(int(id)):
			comp_income_tick.erase(id)
	for id in comp_load.keys():
		if not comp_capacity.has(int(id)):
			comp_load.erase(id)
			comp_util.erase(id)
			comp_full.erase(id)
			comp_gas.erase(id)
	for id in comp_gas.keys():
		if not comp_capacity.has(int(id)):
			comp_gas.erase(id)
			comp_gas_state.erase(id)
	_rebuild_roads()
	_rebuild_road_warnings()
	_rebuild_network_overlay()
	for b in buildings:
		b["road"] = _has_road(b)


func _role_of(kind: String) -> String:
	var def := _def(kind)
	return def.role if def != null else ""


## Base capacity of one pipe cell, from its placed grade.
func _pipe_cell_capacity(cell: Vector2i) -> float:
	return catalogue.pipe_grade_capacity(int(pipe_grade.get(cell, 0)))


## Whole-run capacity: weakest cell + boost, eroded by terrain relief and friction.
func _pipe_run_capacity(min_cell_cap: float, cells: int, boost: float,
		relief: float = 0.0, grade: int = 0) -> float:
	return catalogue.pipe_run_capacity(min_cell_cap, cells, boost, relief, grade)


## Pipe cell ground height, used to measure the run's static lift.
func _pipe_cell_height(cell: Vector2i) -> float:
	return _cell_max_height(cell)


func _pipe_cell_grade(cell: Vector2i) -> int:
	return int(pipe_grade.get(cell, 0))


# --------------------------------------------------------------------------- #
# hud
# --------------------------------------------------------------------------- #

## One row per pipe run and street network, for the management panel.
func _network_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var sel_kind := ""
	var sel_id := -1
	if pipes.has(selected_cell):
		sel_kind = "pipe"
		sel_id = int(pipe_comp.get(selected_cell, -1))
	elif roads.has(selected_cell):
		sel_kind = "road"
		sel_id = int(road_comp.get(selected_cell, -1))
	var pipe_ids: Array[int] = []
	for c in pipes.keys():
		var id := int(pipe_comp.get(c, -1))
		if id >= 0 and not (id in pipe_ids):
			pipe_ids.append(id)
	pipe_ids.sort()
	for id in pipe_ids:
		var cells := int(comp_cells.get(id, 0))
		var cap := float(comp_capacity.get(id, 0.0))
		var has_tank := false
		if comp_members.has(id):
			has_tank = not comp_members[id].storages.is_empty()
		var flow := float(comp_load.get(id, 0.0)) if has_tank else 0.0
		var ratio := float(comp_util.get(id, 0.0)) if has_tank else 0.0
		var status := ""
		var alert := false
		if has_tank and bool(comp_full.get(id, false)):
			status = " - FULL"
			alert = true
		if not has_tank:
			status = " · dry"
			alert = true
			ratio = 1.0
		elif flow >= cap - 0.01:
			status = " · MAX"
			alert = true
		var income := float(comp_income.get(id, 0.0))
		var pressure := int(round(float(comp_pressure.get(id, 1.0)) * 100.0))
		var gas := float(comp_gas.get(id, 0.0))
		var gas_state := String(comp_gas_state.get(id, ""))
		var gas_txt := ""
		if gas > 0.01:
			match gas_state:
				"sold":
					gas_txt = " · G%.1f sold" % gas
				"flared":
					gas_txt = " · G%.1f flared" % gas
				"vented":
					gas_txt = " · G%.1f VENTED" % gas
					status += " · VENT"
					alert = true
		var sel := sel_kind == "pipe" and id == sel_id
		rows.append({"kind": "pipe", "id": id, "ratio": ratio, "alert": alert, "selected": sel,
			"text": "%sRUN %d · %dc · oil %.1f/%.1f · %d%% head%s · $%.0f/s%s" % [
				"▶ " if sel else "", id, cells, flow, cap, pressure, gas_txt, income, status]})
	var road_ids: Array[int] = []
	for c in roads.keys():
		var id := int(road_comp.get(c, -1))
		if id >= 0 and not (id in road_ids):
			road_ids.append(id)
	road_ids.sort()
	for id in road_ids:
		var cells := 0
		for c in roads.keys():
			if int(road_comp.get(c, -1)) == id:
				cells += 1
		var cap := float(road_capacity.get(id, 0.0))
		var load := float(road_load.get(id, 0.0))
		var ratio := load / cap if cap > 0.0 else 0.0
		var status := ""
		var alert := false
		if not bool(road_served.get(id, false)):
			status = " · isolated"
			alert = true
			ratio = 1.0
		elif load > cap:
			status = " · busy"
			alert = true
		var units := 0
		for u in fleet_units:
			if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) == id:
				units += 1
		if units > 0:
			status += " · F%d" % units
		var upkeep := float(cells) * _road_upkeep()
		var sel := sel_kind == "road" and id == sel_id
		rows.append({"kind": "road", "id": id, "ratio": ratio, "alert": alert, "selected": sel,
			"text": "%sSTREET %d · %dc · LOGI %.1f/%.1f · $%.2f/s%s" % [
				"▶ " if sel else "", id, cells, load, cap, upkeep, status]})
	# problems first, then pipelines, then streets
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.alert) != bool(b.alert):
			return bool(a.alert)
		if String(a.kind) != String(b.kind):
			return String(a.kind) == "pipe"
		return int(a.id) < int(b.id)
	)
	return rows


func _update_hud() -> void:
	var wells := 0
	var idle := 0
	var storages := 0
	var refineries := 0
	var crude := 0.0
	var no_road_wells := 0
	var no_road_ref := 0
	for b in buildings:
		match _role_of(b.kind):
			"producer":
				wells += 1
				if not bool(b.get("road", true)):
					no_road_wells += 1
				elif b.comp < 0 or not comp_members.has(b.comp) or comp_members[b.comp].storages.is_empty():
					idle += 1
			"buffer":
				storages += 1
				crude += float(b.crude)
			"consumer":
				refineries += 1
				if not bool(b.get("road", true)):
					no_road_ref += 1
	var capacity := 0.0
	for b in buildings:
		if _role_of(b.kind) == "buffer":
			capacity += float(b.capacity)

	var gas_rate := 0.0
	var venting := 0.0
	for id in comp_gas.keys():
		gas_rate += float(comp_gas[id])
		if String(comp_gas_state.get(id, "")) == "vented":
			venting += float(comp_gas[id])

	var clock_txt := "—"
	var weather_col := Color(0.78, 0.94, 0.70)
	if calendar != null:
		clock_txt = calendar.full_label()
	if weather != null:
		clock_txt += " · " + weather.hud_label()
		weather_col = weather.severity_color()
	if wind != null:
		clock_txt += " · " + wind.label()

	hud.update_stats({
		"cash": cash, "debt": debt, "value": cash - debt, "income": income_rate, "price": price,
		"wells": wells, "idle_wells": idle, "storages": storages,
		"crude": crude, "capacity": capacity, "refineries": refineries,
		"gas": gas_rate, "venting": venting, "fleet": fleet,
		"clock": clock_txt, "weather_color": weather_col,
	})
	hud.set_objective(_objective_text(wells, idle, storages, refineries, no_road_wells, no_road_ref))
	hud.set_runs(_network_rows())
	_update_status_markers()

	var upkeep_s := _pipe_upkeep_total() + roads.size() * _road_upkeep()
	var flow_cap := 0.0
	var flow_use := 0.0
	for id in comp_members:
		var m: Dictionary = comp_members[id]
		if m.storages.is_empty():
			continue
		flow_cap += float(comp_capacity.get(id, 0.0))
		flow_use += float(comp_load.get(id, 0.0))
	var net1 := "PIPES %d  ·  ROADS %d  ·  UPKEEP $%.2f/s  ·  FLOW %.1f/%.1f bbl/s" % [
		pipes.size(), roads.size(), upkeep_s, flow_use, flow_cap]
	var full_runs := 0
	var cap_runs := 0
	for id in comp_capacity.keys():
		if bool(comp_full.get(id, false)):
			full_runs += 1
		elif float(comp_util.get(id, 0.0)) >= 0.95:
			cap_runs += 1
	if full_runs > 0:
		net1 += "   ·   STORAGE FULL ×%d" % full_runs
	elif cap_runs > 0:
		net1 += "   ·   PIPELINE AT CAPACITY ×%d" % cap_runs
	var logi_cap := 0.0
	var logi_load := 0.0
	for id in road_capacity.keys():
		if bool(road_served.get(id, false)):
			logi_cap += float(road_capacity[id])
			logi_load += float(road_load[id])
	var net2 := "LOGI %.0f/%.0f" % [logi_load, logi_cap]
	var fleet_count := 0
	for unit_id in fleet.keys():
		fleet_count += int(fleet[unit_id])
	if fleet_count > 0:
		net2 += "  ·  FLEET %d (+%.0f logi assigned)" % [fleet_count, _fleet_logistics()]
	if not contract.is_empty():
		net2 += "  ·  CONTRACT %d/%d bbl · %.0fs" % [
			int(contract.done), int(contract.target), float(contract.time)]
	if show_network:
		net2 += "   ·   OVERLAY: green <60% · yellow <90% · red ≥90% · orange isolated"
	if int(no_road_wells) + int(no_road_ref) > 0:
		net2 += "   ·   %d need road access" % (int(no_road_wells) + int(no_road_ref))
	if road_isolated_cells > 0:
		net2 += "   ·   %d isolated road cell%s" % [road_isolated_cells, "" if road_isolated_cells == 1 else "s"]
	hud.set_network(net1 + "\n" + net2)
	_rebuild_run_highlight()

	if not won and cash - debt >= 1000000.0:
		won = true
		Sfx.play("confirm", 1.2)
		paused = true
		hud.show_victory("Company value $%s\nWells %d · Tanks %d · Refineries %d" % [
			hud.fmt_num(cash - debt), wells, storages, refineries])

	if dragging and (tool == "pipe" or tool == "road") and _in_bounds(hover_cell):
		var rstart := drag_start
		var rend := hover_cell
		if tool == "pipe":
			var pair := _snap_pipe_route(drag_start, hover_cell)
			rstart = pair[0]
			rend = pair[1]
		var route := _route_cells(rstart, rend)
		var rcost := _route_cost(route)
		var extra := ""
		if tool == "pipe":
			var joints := 0
			for c in route:
				if _port_joint_at(c) != 0:
					joints += 1
			extra = "\n%d port joint%s%s" % [joints, "" if joints == 1 else "s",
				" — no port on this route yet" if joints == 0 else ""]
			if not route.is_empty():
				var gcap := catalogue.pipe_grade_capacity(pipe_grade_choice)
				var proj := catalogue.pipe_run_capacity(gcap, route.size(), 0.0)
				extra += "\n%d cells · weakest %.1f bbl/s · run ≈ %.1f bbl/s" % [
					route.size(), gcap, proj]
		else:
			var sites := _road_preview_sites(route)
			extra = "\nserves %d site%s · %s" % [sites, "" if sites == 1 else "s",
				"network connected" if _road_preview_served(route)
				else "isolated — link 2+ sites or a served road"]
		var requested := _line_cells(rstart, rend)
		var blocked_structures := 0
		var blocked_ground := 0
		for c in requested:
			if occupied.has(c):
				blocked_structures += 1
			elif _cell_relief(c) > MAX_INFRA_RELIEF:
				blocked_ground += 1
		if blocked_structures > 0:
			extra += "\n%d cell%s blocked by structures" % [
				blocked_structures, "" if blocked_structures == 1 else "s"]
		if blocked_ground > 0:
			extra += "\n%d cell%s too uneven — level first" % [
				blocked_ground, "" if blocked_ground == 1 else "s"]
		hud.set_inspector("%s route" % _def(tool).display_name,
			"%d cells · $%s%s\nRelease to build · Esc to cancel" % [
				route.size(), hud.fmt_num(rcost), extra])
	elif tool != "" and not bulldoze and _in_bounds(hover_cell):
		var pv := _site_preview(tool)
		hud.set_inspector(pv[0], pv[1])
	else:
		var cell: Vector2i = selected_cell if selected_cell.x >= 0 else hover_cell
		var info := _describe(cell)
		if String(info[0]) == "":
			hud.set_inspector("Nothing selected", "Hover a building or click it to inspect.\n\n1-6 build · X bulldoze · Space pause")
		else:
			hud.set_inspector(info[0], info[1])

	_mm_timer += get_process_delta_time()
	if _mm_timer > 0.33:
		_mm_timer = 0.0
		hud.set_minimap(_minimap_cells())


func _objective_text(wells: int, idle: int, storages: int, refineries: int,
		no_road_wells: int = 0, no_road_ref: int = 0) -> String:
	if failed:
		return "BANKRUPT — restart or load a save (F9)"
	if won:
		return "VICTORY — company value over $1,000,000"
	if not _any_revealed_deposit():
		if _has_unit_job("seismic"):
			return "OBJECTIVE — Explore: select the Seismic Vehicle and click a target"
		return "OBJECTIVE — Explore: buy a Seismic Vehicle in FLEET, then survey"
	if buildings.is_empty():
		return "OBJECTIVE — Build the Field Base"
	if wells == 0:
		if not _has_unit_job("build"):
			return "OBJECTIVE — Build: buy a Mobile Crane in FLEET, then place a Pumpjack"
		return "OBJECTIVE — Drill: place a Pumpjack [1], then right-click the site with a Mobile Crane"
	if no_road_wells > 0:
		return "OBJECTIVE — Access: connect the pumpjack to a road (or haul with a tanker)"
	if idle > 0:
		if _has_unit_job("hauler"):
			return "OBJECTIVE — Gather: tanker hauling crude; add a tank/refinery for better prices"
		return "OBJECTIVE — Gather: buy a Fuel Tanker and click the pumpjack (or pipe it to a tank)"
	if refineries == 0:
		return "OBJECTIVE — Refine: build a Refinery [3] and pipe it to the tank"
	if no_road_ref > 0:
		return "OBJECTIVE — Access: connect the refinery and another site by road"
	if road_isolated_cells > 0:
		return "OBJECTIVE — Streets: connect isolated road cells into the network"
	if _road_congested():
		return "OBJECTIVE — Logistics: road network congested, add road cells"
	if _pipeline_at_capacity():
		return "OBJECTIVE — Throughput: add a pump/compressor or a second pipe run"
	if wells < 4:
		return "OBJECTIVE — Scale up: more wells, storage and haulers"
	return "OBJECTIVE — Grow to $1,000,000 company value (now $%s) — optimise tanks/refineries" % hud.fmt_num(cash - debt)


func _has_unsurveyed_office() -> bool:
	for b in buildings:
		if _role_of(b.kind) == "survey" and not bool(b.get("surveyed", false)):
			return true
	return false


func _any_revealed_deposit() -> bool:
	for c in deposits.keys():
		if bool(deposits[c].revealed):
			return true
	return false


func _pipeline_at_capacity() -> bool:
	for id in comp_members:
		var m: Dictionary = comp_members[id]
		if m.storages.is_empty():
			continue
		var cap := float(comp_capacity.get(id, 0.0))
		var want := 0.0
		for w in m.wells:
			if bool(w.get("road", true)):
				want += float(w.rate)
		if cap > 0.0 and want >= cap - 0.01:
			return true
	return false


func _road_congested() -> bool:
	for id in road_capacity.keys():
		if bool(road_served.get(id, false)) \
				and float(road_load.get(id, 0.0)) > float(road_capacity.get(id, 0.0)):
			return true
	return false


func _status_of(b: Dictionary) -> String:
	var role := _role_of(b.kind)
	if role == "base":
		return "ok"
	# The office has no pipeline port; only its road matters.
	if role == "survey":
		return "ok" if _road_near(b.cells) else "no road access"
	if role == "access":
		return "ok" if _served_road_near(b.cells) else "no road access"
	if role == "unit" or role == "transport":
		return "ok"
	if (role == "producer" or role == "consumer") and not bool(b.get("road", true)):
		return "no road access"
	if int(b.comp) < 0:
		return "not connected"
	if not comp_members.has(int(b.comp)):
		return "idle"
	var m: Dictionary = comp_members[int(b.comp)]
	match role:
		"producer":
			return "flowing" if not m.storages.is_empty() else "no storage in network"
		"buffer":
			return "linked" if (not m.wells.is_empty() or not m.refineries.is_empty()) else "not connected"
		"consumer":
			return "refining" if not m.storages.is_empty() else "no storage in network"
	return "ok"


func _site_preview(kind: String) -> Array:
	var def := _def(kind)
	if def == null:
		return ["", ""]
	var size: int = def.footprint
	var cells := _cells_for(hover_cell, size)
	var relief := _footprint_relief(cells)
	var top := -1.0e9
	for c in cells:
		top = maxf(top, _cell_max_height(c))
	var earth := _level_moved(cells, top) * LEVEL_RATE
	var free := _can_place(hover_cell, kind)
	var flat_enough := relief <= MAX_BUILD_RELIEF
	var ok := free and flat_enough

	var body := "Cost $%s" % hud.fmt_num(def.cost)
	if kind == "pipe" or kind == "road":
		body += " per cell\nThe run cannot climb more than %.1f m between cells." % MAX_GRADE
		if def.capacity != null:
			body += "\nCapacity: %s" % def.capacity.describe()
		return [def.display_name, body + ("\n\nDrag to lay." if cash >= def.cost else "\n\nNot enough cash.")]

	body += "  +  levelling $%s" % hud.fmt_num(earth)
	body += "\nGround relief: %.1f m" % relief
	if def.capacity != null:
		body += "\nCapacity: %s" % def.capacity.describe()
	if def.network_boost > 0.0:
		body += "\nStreet boost: +%.0f logistics" % def.network_boost
		body += " (road adjacent)" if _served_road_near(cells) else " — place beside a road"
	var prep_all := true
	for c in cells:
		if not prepared.has(c):
			prep_all = false
			break
	body += "\nSite: " + ("prepared" if prep_all else "unprepared — a bulldozer levels it")
	body += "\nRotation: %d° (R)" % build_rot
	if not free:
		body += "\nStatus: blocked"
	elif not flat_enough:
		body += "\nStatus: too steep — level the site or move"
	else:
		var road_ok := _served_road_near(cells)
		if def.role == "survey":
			road_ok = _road_near(cells)
		body += "\nStatus: ready" + (" (road adjacent)" if road_ok else " — no road adjacent")
	body += "\n\n" + ("Click to build." if ok and cash >= def.cost + earth else "Cannot build here.")
	return [def.display_name, body]


func _road_near(cells: Array) -> bool:
	for c in cells:
		for d in DIRS:
			if roads.has((c as Vector2i) + d):
				return true
	return false


func _served_road_near(cells: Array) -> bool:
	for c in cells:
		for d in DIRS:
			var n: Vector2i = (c as Vector2i) + d
			if roads.has(n) and bool(road_served.get(int(road_comp.get(n, -1)), false)):
				return true
	return false


func _describe(cell: Vector2i) -> Array:
	if occupied.has(cell):
		var b: Dictionary = occupied[cell]
		var def := _def(b.kind)
		if def == null:
			return ["", ""]
		var ports := "%s · pipe on %s" % [_sides_text(_building_port_mask(b)), _sides_text(_connected_sides(b))]
		match def.role:
			"producer":
				return [def.display_name, "Status: %s\nRate: %.1f bbl/s\nDeposit left: %s bbl\nFlowline port: %s" % [
					_status_of(b), float(b["rate"]), hud.fmt_num(float(b["deposit"])), ports]]
			"buffer":
				return [def.display_name, "Status: %s\nCrude: %s / %s bbl\nNozzles: %s" % [
					_status_of(b), hud.fmt_num(float(b["crude"])), hud.fmt_num(float(b["capacity"])), ports]]
			"consumer":
				return [def.display_name, "Status: %s\nThroughput: %.1f bbl/s\nYield: %d%%\nFeed port: %s" % [
					_status_of(b), float(b["throughput"]), int(_refined_yield() * 100.0), ports]]
			"booster":
				return [def.display_name, "Status: %s\n%s\nUpkeep $%.2f/s\nBooster: %s" % [
					_status_of(b), def.capacity.describe() if def.capacity != null else "—",
					float(b.upkeep), ports]]
			"processor", "meter":
				return [def.display_name, "Status: %s\n%s\nUpkeep $%.2f/s\nPorts: %s" % [
					_status_of(b), def.capacity.describe() if def.capacity != null else "—",
					float(b.upkeep), ports]]
			"survey":
				var st := "needs road access"
				if bool(b.get("surveyed", false)):
					st = "survey complete"
				elif _has_road(b):
					st = "surveying"
				return [def.display_name, "Status: %s\nSurvey radius: %d cells.\nNo pipeline port — it is a road-side survey office." % [
					st, int(def.capacity.radius) if def.capacity != null else 0]]
			"access":
				var near := _served_road_near(b.cells)
				return [def.display_name, "Status: %s\nNetwork boost: +%.0f logistics%s\nUpkeep $%.2f/s" % [
					"boosting a street" if near else "not beside a served street",
					def.network_boost,
					"" if near else " — place it beside a road network",
					float(b.upkeep)]]
			"base":
				return [def.display_name, "Field HQ\nLaunch Seismic Vehicles, Bulldozers and Tankers from FLEET.\nUpkeep $%.2f/s" % float(b.upkeep)]
	if pipes.has(cell):
		var cid := int(pipe_comp.get(cell, -1))
		var run := int(comp_cells.get(cid, 0))
		var cap_run := float(comp_capacity.get(cid, 0.0))
		var boost := float(comp_boost.get(cid, 0.0))
		var load := float(comp_load.get(cid, 0.0))
		var util := float(comp_util.get(cid, 0.0))
		var bottleneck = comp_bottleneck.get(cid, null)
		var bottleneck_txt := "none"
		if bottleneck != null:
			bottleneck_txt = "%s · %s (%.1f bbl/s)" % [
				str(bottleneck), catalogue.pipe_grade_name(int(pipe_grade.get(bottleneck, 0))),
				_pipe_cell_capacity(bottleneck)]
		var relief := float(comp_relief.get(cid, 0.0))
		var pressure := int(round(float(comp_pressure.get(cid, 1.0)) * 100.0))
		var gas := float(comp_gas.get(cid, 0.0))
		var gstate := String(comp_gas_state.get(cid, ""))
		var pbody := "Run: %d cells · upkeep $%.2f/s\nFlow: %.1f / %.1f bbl/s (%.0f%%)\nLift: %.1f m · pressure %d%%\nIncome: +$%s/s\nWeakest cell: %s · head +%.1f" % [
			run, _run_pipe_upkeep(cid), load, cap_run, util * 100.0,
			relief, pressure, hud.fmt_num(float(comp_income.get(cid, 0.0))), bottleneck_txt, boost]
		if gas > 0.01:
			pbody += "\nAssociated gas: %.1f u/s (%s)" % [gas, gstate]
		if comp_members.has(cid):
			var m: Dictionary = comp_members[cid]
			pbody += "\nWells %d · Tanks %d · Refineries %d" % [
				m.wells.size(), m.storages.size(), m.refineries.size()]
			if not m.get("processors", []).is_empty():
				var yb := 0.0
				for p in m.processors:
					yb += float(p.get("yield_bonus", 0.0))
				pbody += "\nProcessors %d (+%d%% yield)" % [m.processors.size(), int(yb * 100.0)]
			if not m.get("meters", []).is_empty():
				var pb := 0.0
				for mt in m.meters:
					pb += float(mt.get("price_bonus", 0.0))
				pbody += "\nMeters %d (+%d%% price)" % [m.meters.size(), int(pb * 100.0)]
			if m.storages.is_empty():
				pbody += "\nNo storage on this run — nothing flows."
			elif cap_run > 0.0 and load >= cap_run - 0.01:
				pbody += "\nAt capacity — add pipe or a second run."
		return ["Pipeline", pbody]
	if roads.has(cell):
		var cid := int(road_comp.get(cell, -1))
		var net_size := 0
		for rc in road_comp.keys():
			if int(road_comp[rc]) == cid:
				net_size += 1
		var cap := float(road_capacity.get(cid, 0.0))
		var load := float(road_load.get(cid, 0.0))
		var state := "serves sites" if bool(road_served.get(cid, false)) else "isolated — connect it to another site"
		var congested := " · congested" if (cap > 0.0 and load > cap) else ""
		var names: Array[String] = []
		for rc in road_comp.keys():
			if int(road_comp[rc]) != cid:
				continue
			for d in DIRS:
				var nb: Vector2i = (rc as Vector2i) + d
				if occupied.has(nb):
					var nm := String(occupied[nb].name)
					if not (nm in names):
						names.append(nm)
		var sites_line := "Sites: %s · Fleet: %d" % [
			", ".join(names) if not names.is_empty() else "none",
			_fleet_units_on(cid)]
		var road_def := _def("road")
		var base_cap := 0.0
		var cell_cap := 0.0
		if road_def != null and road_def.capacity != null:
			base_cap = road_def.capacity.road_base
			cell_cap = road_def.capacity.road_per_cell * float(net_size)
		var fleet_cap := _fleet_logistics_for(cid)
		var depot_cap := maxf(0.0, cap - base_cap - cell_cap - fleet_cap)
		var cap_line := "Capacity: %.1f base + %.1f cells + %.1f fleet + %.1f depot = %.1f" % [
			base_cap, cell_cap, fleet_cap, depot_cap, cap]
		var fleet_hint := ""
		for u in fleet_units:
			if roads.has(u.cell) and int(road_comp.get(u.cell, -1)) != cid:
				fleet_hint = "\nF6: transfer one fleet unit here"
				break
		return ["Road", "Network: %d cells · %s%s\nLogistics: %.1f / %.1f\n%s\n%s%s\nF7: demolish this network\nRoads gate production and must serve at least two sites." % [
			net_size, state, congested, load, cap, cap_line, sites_line, fleet_hint]]
	if deposits.has(cell):
		var d: Dictionary = deposits[cell]
		if d.revealed:
			return ["Oil Deposit", "In place: %s bbl\nPlace a Pumpjack [1] here." % hud.fmt_num(float(d.amount))]
		return ["Unexplored ground", "Survey with an Exploration Office [4]."]
	return ["", ""]


func _minimap_cells() -> Array:
	var out: Array = []
	for c in deposits.keys():
		if deposits[c].revealed:
			out.append([(c as Vector2i).x, (c as Vector2i).y, Color(0.16, 0.14, 0.10)])
	for c in pipes.keys():
		out.append([(c as Vector2i).x, (c as Vector2i).y, Color(0.86, 0.71, 0.16)])
	for c in roads.keys():
		out.append([(c as Vector2i).x, (c as Vector2i).y, Color(0.40, 0.42, 0.38)])
	for b in buildings:
		var bdef := _def(b.kind)
		var col: Color = bdef.minimap_color if bdef != null else Color(0.80, 0.80, 0.75)
		for cell in b.cells:
			out.append([(cell as Vector2i).x, (cell as Vector2i).y, col])
	return out


func _pipe_hint() -> String:
	return "PIPE (%s): drag from a green port strip  ·  G changes grade ($%s/cell, %.0f bbl/s)\nTab networks · F5 save · F9 load · Space pause · Esc cancels" % [
		catalogue.pipe_grade_name(pipe_grade_choice),
		hud.fmt_num(catalogue.pipe_grade_cost(pipe_grade_choice)),
		catalogue.pipe_grade_capacity(pipe_grade_choice)]


func _on_tool_selected(kind: String) -> void:
	var def := _def(kind)
	if def == null:
		return
	if def.role == "unit":
		_buy_unit(kind)
		return
	tool = kind
	bulldoze = false
	hud.set_tool(kind)
	_clear_unit_selection()
	if kind == "pipe":
		hud.set_hint(_pipe_hint())
	elif kind == "road":
		hud.set_hint(ROAD_HINT)
	else:
		hud.set_hint(DEFAULT_HINT)
	if def.description != "":
		hud.toast("%s $%s — %s" % [def.display_name, hud.fmt_num(def.cost), def.description])
	else:
		hud.toast("%s $%s" % [def.display_name, hud.fmt_num(def.cost)])
	_update_ghost()


func _on_bulldoze() -> void:
	bulldoze = true
	tool = ""
	_bulldoze_last = Vector2i(-1, -1)
	hud.set_tool("bulldoze")
	hud.set_hint("BULLDOZE: click or drag  ·  building 50% refund  ·  pipe/road 40%  ·  Esc cancels")
	hud.toast("Bulldoze: click or drag (building 50% · pipe/road 40%)", Color(1.0, 0.75, 0.5))
	_update_ghost()


func _clear_tool() -> void:
	tool = ""
	bulldoze = false
	dragging = false
	_clear_unit_selection()
	_update_drag_preview()
	_update_port_hint()
	hud.set_tool("")
	ghost.visible = false


func _on_difficulty(money: float) -> void:
	Sfx.enable()   # sound only after the player actually starts
	hud.clear_victory()
	hud.clear_game_over()
	cash = money
	debt = 0.0
	failed = false
	paused = false
	hud.hide_start_overlay()
	hud.toast("Lease acquired — survey for oil", Color(0.7, 0.9, 0.6))


func _on_loan() -> void:
	cash += 100000.0
	debt += 112000.0
	Sfx.play("confirm")
	hud.toast("Loan taken: +$100,000 (owe $112,000)", Color(0.9, 0.85, 0.5))


func _on_speed(mult: float) -> void:
	speed = mult
	paused = false
	hud.toast("Speed %dx" % int(mult))


func _on_victory_dismissed() -> void:
	paused = false


func _on_restart() -> void:
	get_tree().reload_current_scene()


func _on_minimap_target(cell: Vector2i) -> void:
	if _in_bounds(cell):
		camera.target = cell_to_world(cell)


func _on_run_selected(kind: String, id: int) -> void:
	var dict: Dictionary = pipes if kind == "pipe" else roads
	var comps: Dictionary = pipe_comp if kind == "pipe" else road_comp
	for c in dict.keys():
		if int(comps.get(c, -1)) == id:
			selected_cell = c
			camera.target = cell_to_world(c)
			_rebuild_run_highlight()
			hud.toast("%s %d selected" % [
				"Pipeline" if kind == "pipe" else "Street network", id], Color(0.8, 0.9, 0.75))
			return
