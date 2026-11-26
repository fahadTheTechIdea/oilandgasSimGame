class_name BuildingCatalogueFactory
extends RefCounted
## Builds the default catalogue. This is the one place the shipped numbers live;
## `game/tools/build_catalogue.gd` serialises it to `res://data/catalogue.tres`.
##
## Adding a structure = one method here (+ a model). The menu, hotkeys, model
## loading and placement rules all read these fields, so no runtime code changes.

static func build() -> BuildingCatalogue:
	var catalogue := BuildingCatalogue.new()
	catalogue.entries = [
		_well(), _storage(), _refinery(), _explorer(), _pipe(), _road(),
		_pump(), _tank_farm(), _separator(), _metering(), _compressor(), _manifold(),
		_heater_treater(), _flare(), _refinery_cdu(),
		_refinery_vdu(), _refinery_fcc(), _control_room(), _cooling_tower(), _pig_launcher(),
		_gas_plant(), _water_disposal(), _tank_terminal(), _slug_catcher(), _depot(),
		_base(), _seismic(), _bulldozer(),
		_pickup(), _fuel_tanker(), _pipe_truck(), _crane(),
	]
	return catalogue


static func _def(id: String, name: String, cost: float, foot: int, model: String,
		upkeep: float, role: String, in_sides: int, out_sides: int, links: int,
		capacity: Dictionary) -> BuildingDefinition:
	var def := BuildingDefinition.new()
	def.id = id
	def.display_name = name
	def.cost = cost
	def.footprint = foot
	def.model_id = model
	def.upkeep = upkeep
	def.role = role
	# The build-menu section is data too: role decides the default, an entry can
	# override it. Adding a structure never edits HUD code.
	def.category = _category_for_role(role)
	# Logistics load is role-driven, so new structures inherit sensible behaviour.
	match role:
		"producer":
			def.logistics = 1.0
		"buffer":
			def.logistics = 0.5
		"consumer":
			def.logistics = 2.0
		"survey":
			def.logistics = 1.0
		"booster", "processor", "meter":
			def.logistics = 0.5
	# Icon convention: data asset named after the structure id. Add an id + a
	# matching PNG and the UI picks it up — no code changes.
	def.icon_path = "res://assets/icons/%s.png" % id
	var ports := PortSpec.new()
	ports.in_sides = in_sides
	ports.out_sides = out_sides
	ports.links = links
	def.ports = ports
	var cap := CapacitySpec.new()
	for key in capacity.keys():
		cap.set(key, capacity[key])
	def.capacity = cap
	return def


static func _category_for_role(role: String) -> String:
	match role:
		"producer", "survey":
			return "UPSTREAM"
		"buffer":
			return "STORAGE"
		"processor", "meter", "booster":
			return "PROCESSING"
		"consumer":
			return "REFINING"
		"transport", "access":
			return "INFRASTRUCTURE"
		"unit":
			return "FLEET"
		"base":
			return "BASE"
	return "OTHER"


static func _well() -> BuildingDefinition:
	var d := _def("well", "Pumpjack", 18000.0, 1, "on_pumpjack", 1.2, "producer",
		0, PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W, 1, {"rate": 1.7})
	d.hotkey = "1"
	d.order = 1
	d.icon_index = 4
	d.description = "place on a revealed deposit"
	d.minimap_color = Color(0.92, 0.62, 0.20)
	d.requires_deposit = true
	return d


static func _storage() -> BuildingDefinition:
	var d := _def("storage", "Storage Tank", 25000.0, 1, "gam_storage", 0.7, "buffer",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"volume": 600.0})
	d.hotkey = "2"
	d.order = 2
	d.icon_index = 5
	d.description = "buffers crude and bridges runs"
	d.minimap_color = Color(0.90, 0.93, 0.95)
	d.spacing_role = "producer"
	d.spacing_cells = 2
	return d


static func _refinery() -> BuildingDefinition:
	var d := _def("refinery", "Refinery", 120000.0, 2, "gam_refinery", 4.0, "consumer",
		PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W, 0, 1,
		{"feed": 3.4, "yield_ratio": 0.92})
	d.hotkey = "3"
	d.order = 3
	d.icon_index = 6
	d.description = "needs a pipe link to storage"
	d.minimap_color = Color(0.45, 0.78, 0.90)
	return d


static func _explorer() -> BuildingDefinition:
	var d := _def("explorer", "Exploration Office", 30000.0, 1, "gam_explorer", 2.0, "survey",
		0, 0, 0, {"radius": 11.0})
	d.hotkey = "4"
	d.order = 4
	d.icon_index = 3
	d.description = "needs road access to survey"
	d.minimap_color = Color(0.62, 0.90, 0.52)
	return d


static func _pipe() -> BuildingDefinition:
	var d := _def("pipe", "Pipeline", 400.0, 1, "", 0.02, "transport",
		0, 0, 0, {
			"pipe_base": 4.0, "pipe_per_cell": 0.0,
			"pipe_grade_caps": PackedFloat32Array([4.0, 8.0, 16.0]),
			"pipe_grade_costs": PackedFloat32Array([400.0, 900.0, 1800.0]),
			"pipe_grade_upkeep": PackedFloat32Array([0.02, 0.05, 0.10]),
			"pipe_friction": 0.08, "pipe_free_cells": 6.0, "pipe_min_fraction": 0.25,
		})
	d.hotkey = "5"
	d.order = 5
	d.description = "drag to lay · G changes grade · 4 / 8 / 16 bbl/s"
	d.minimap_color = Color(0.86, 0.71, 0.16)
	return d


static func _road() -> BuildingDefinition:
	var d := _def("road", "Road", 200.0, 1, "", 0.01, "access",
		0, 0, 0, {"gates": true, "road_base": 2.0, "road_per_cell": 0.5})
	d.hotkey = "6"
	d.order = 6
	d.description = "drag to lay · $200 per cell"
	d.minimap_color = Color(0.40, 0.42, 0.38)
	return d


static func _pump() -> BuildingDefinition:
	var d := _def("pump", "Pump Station", 45000.0, 1, "mid_pump_station", 3.0, "booster",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"boost": 8.0})
	d.hotkey = "7"
	d.order = 7
	d.icon_index = 7
	d.description = "boosts its pipe run"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


static func _tank_farm() -> BuildingDefinition:
	var d := _def("tank_farm", "Tank Farm", 90000.0, 2, "on_tank_farm", 2.5, "buffer",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"volume": 2400.0})
	d.hotkey = "8"
	d.order = 8
	d.icon_index = 5
	d.description = "large buffer; bridges runs"
	d.minimap_color = Color(0.90, 0.93, 0.95)
	d.spacing_role = "producer"
	d.spacing_cells = 2
	return d


static func _separator() -> BuildingDefinition:
	var d := _def("separator", "Separator", 40000.0, 1, "on_separator", 1.5, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.10})
	d.hotkey = "9"
	d.order = 9
	d.description = "cleans well flow for its run (+10% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _metering() -> BuildingDefinition:
	var d := _def("metering", "Metering Skid", 35000.0, 1, "on_metering_skid", 1.0, "meter",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"price_bonus": 0.06})
	d.hotkey = "0"
	d.order = 10
	d.description = "custody-transfer meter (+6% price)"
	d.minimap_color = Color(0.80, 0.70, 0.95)
	return d


static func _compressor() -> BuildingDefinition:
	var d := _def("compressor", "Compressor Station", 55000.0, 1, "on_compressor_station", 3.5, "booster",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"boost": 5.0})
	d.hotkey = "-"
	d.order = 11
	d.description = "boosts its pipe run (+5 bbl/s)"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


static func _manifold() -> BuildingDefinition:
	var d := _def("manifold", "Gathering Manifold", 18000.0, 1, "on_gathering_manifold", 1.0, "booster",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"boost": 2.0})
	d.hotkey = "="
	d.order = 12
	d.description = "small throughput boost / junction"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


static func _heater_treater() -> BuildingDefinition:
	var d := _def("heater_treater", "Heater Treater", 50000.0, 1, "on_heater_treater", 1.8, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.08})
	d.order = 13
	d.description = "heats the emulsion (+8% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _flare() -> BuildingDefinition:
	var d := _def("flare", "Flare", 20000.0, 1, "on_flare", 0.8, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.05})
	d.order = 14
	d.description = "safe operations (+5% yield)"
	d.minimap_color = Color(0.95, 0.55, 0.35)
	return d


static func _refinery_cdu() -> BuildingDefinition:
	var d := _def("refinery_cdu", "Crude Distillation Unit", 180000.0, 2, "ref_cdu", 6.0, "consumer",
		PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W, 0, 1,
		{"feed": 5.0, "yield_ratio": 0.90})
	d.order = 15
	d.description = "larger refinery feed (5 bbl/s)"
	d.minimap_color = Color(0.45, 0.78, 0.90)
	return d


static func _refinery_vdu() -> BuildingDefinition:
	var d := _def("refinery_vdu", "Vacuum Distillation", 220000.0, 2, "ref_vdu", 5.0, "consumer",
		PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W, 0, 1,
		{"feed": 4.5, "yield_ratio": 0.93})
	d.order = 16
	d.description = "vacuum unit (4.5 bbl/s feed)"
	d.minimap_color = Color(0.45, 0.78, 0.90)
	return d


static func _refinery_fcc() -> BuildingDefinition:
	var d := _def("refinery_fcc", "Catalytic Cracker", 320000.0, 2, "ref_fcc", 7.0, "consumer",
		PortSpec.SIDE_E | PortSpec.SIDE_N | PortSpec.SIDE_W, 0, 1,
		{"feed": 6.5, "yield_ratio": 0.95})
	d.order = 17
	d.description = "catalytic cracker (6.5 bbl/s feed)"
	d.minimap_color = Color(0.45, 0.78, 0.90)
	return d


static func _control_room() -> BuildingDefinition:
	var d := _def("control_room", "Control Room", 60000.0, 1, "ref_control_room", 1.2, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.03})
	d.order = 18
	d.description = "automation (+3% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _cooling_tower() -> BuildingDefinition:
	var d := _def("cooling_tower", "Cooling Tower", 40000.0, 2, "ref_cooling_tower", 1.0, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.02})
	d.order = 19
	d.description = "process cooling (+2% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _pig_launcher() -> BuildingDefinition:
	var d := _def("pig_launcher", "Pig Launcher", 30000.0, 1, "mid_pig_launcher", 0.8, "booster",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"boost": 3.0})
	d.order = 20
	d.description = "pipeline maintenance (+3 bbl/s)"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


static func _gas_plant() -> BuildingDefinition:
	var d := _def("gas_plant", "Gas Plant", 150000.0, 2, "mid_gas_plant", 4.0, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.06})
	d.order = 25
	d.description = "gas processing (+6% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _water_disposal() -> BuildingDefinition:
	var d := _def("water_disposal", "Water Disposal", 35000.0, 1, "on_saltwater_disposal", 1.0, "processor",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"yield_bonus": 0.03})
	d.order = 26
	d.description = "produced-water handling (+3% yield)"
	d.minimap_color = Color(0.70, 0.90, 0.70)
	return d


static func _tank_terminal() -> BuildingDefinition:
	var d := _def("tank_terminal", "Tank Terminal", 160000.0, 2, "mid_tank_terminal", 3.0, "buffer",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"volume": 3600.0})
	d.order = 27
	d.description = "large terminal storage (3,600 bbl)"
	d.minimap_color = Color(0.90, 0.93, 0.95)
	d.spacing_role = "producer"
	d.spacing_cells = 2
	return d


static func _slug_catcher() -> BuildingDefinition:
	var d := _def("slug_catcher", "Slug Catcher", 40000.0, 1, "mid_slug_catcher", 1.0, "booster",
		PortSpec.ALL_SIDES, PortSpec.ALL_SIDES, 2, {"boost": 2.0})
	d.order = 28
	d.description = "flow smoothing (+2 bbl/s)"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


## A static street-capacity building: place it beside a road network.
static func _depot() -> BuildingDefinition:
	var d := _def("depot", "Truck Depot", 45000.0, 1, "prp_workshop", 1.2, "access",
		0, 0, 0, {})
	d.order = 29
	d.description = "+3 street logistics on its network"
	d.network_boost = 3.0
	d.minimap_color = Color(0.85, 0.78, 0.55)
	return d


## Units are bought, not placed: logistics units add street capacity, while
## agent units (seismic/prep/hauler) take jobs from the field.
static func _unit(id: String, name: String, cost: float, upkeep: float,
		logistics: float, order: int, description: String, model: String,
		job: String = "logistics") -> BuildingDefinition:
	var d := _def(id, name, cost, 1, model, upkeep, "unit", 0, 0, 0, {})
	d.order = order
	d.description = description
	d.logistics = logistics
	d.unit_job = job
	d.minimap_color = Color(0.85, 0.80, 0.55)
	return d


static func _base() -> BuildingDefinition:
	var d := _def("base", "Field Base", 0.0, 2, "ref_control_room", 2.0, "base", 0, 0, 0, {})
	d.order = 0
	d.buildable = false
	d.description = "HQ — launches survey and site-prep units"
	d.minimap_color = Color(0.95, 0.85, 0.35)
	return d


static func _seismic() -> BuildingDefinition:
	var d := _unit("seismic", "Seismic Vehicle", 18000.0, 0.10, 0.0, 25,
		"surveys a 7-cell radius for oil", "veh_wireline_truck", "seismic")
	d.minimap_color = Color(0.55, 0.85, 0.95)
	return d


static func _bulldozer() -> BuildingDefinition:
	var d := _unit("bulldozer", "Site Bulldozer", 22000.0, 0.12, 0.0, 26,
		"levels and prepares a 2×2 site", "veh_bulldozer", "prep")
	d.minimap_color = Color(0.95, 0.75, 0.35)
	return d


static func _pickup() -> BuildingDefinition:
	return _unit("pickup", "Crew Pickup", 8000.0, 0.05, 2.0, 21, "+2 logi to the selected street", "veh_pickup")


static func _fuel_tanker() -> BuildingDefinition:
	var d := _unit("fuel_tanker", "Fuel Tanker", 26000.0, 0.15, 0.0, 22,
		"hauls crude from a well to the base", "veh_fuel_tanker", "hauler")
	d.minimap_color = Color(0.95, 0.60, 0.30)
	return d


static func _pipe_truck() -> BuildingDefinition:
	return _unit("pipe_truck", "Pipe Truck", 29000.0, 0.12, 3.0, 23, "+3 logi to the selected street", "veh_pipe_truck")


static func _crane() -> BuildingDefinition:
	var d := _unit("crane", "Mobile Crane", 45000.0, 0.20, 0.0, 24,
		"builds structures on a site", "veh_constructor", "build")
	d.minimap_color = Color(0.80, 0.85, 0.55)
	return d
