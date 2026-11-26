class_name CapacitySpec
extends Resource
## Capacity numbers for one structure. Only the fields that matter for that
## structure's role are set; `describe()` renders the relevant ones.
##
## Keeping this as data (not code branches) means a designer can retune a
## building in the Inspector and the simulation follows.

@export_group("Producer")
@export var rate: float = 0.0            # bbl/s
@export_group("Storage")
@export var volume: float = 0.0          # bbl
@export_group("Refinery")
@export var feed: float = 0.0            # bbl/s
@export_range(0.0, 1.0) var yield_ratio: float = 1.0
@export_group("Booster")
@export var boost: float = 0.0           # bbl/s added to a run
@export_group("Processing")
@export_range(0.0, 1.0) var yield_bonus: float = 0.0
@export_group("Metering")
@export_range(0.0, 1.0) var price_bonus: float = 0.0
@export_group("Survey")
@export var radius: float = 0.0          # cells
@export_group("Pipeline")
@export var pipe_base: float = 0.0       # bbl/s for any connected run (legacy)
@export var pipe_per_cell: float = 0.0   # bbl/s per pipe cell (legacy)
@export var pipe_grade_caps: PackedFloat32Array = PackedFloat32Array([4.0, 8.0, 16.0])
@export var pipe_grade_costs: PackedFloat32Array = PackedFloat32Array([400.0, 900.0, 1800.0])
@export var pipe_grade_upkeep: PackedFloat32Array = PackedFloat32Array([0.02, 0.05, 0.10])
@export var pipe_friction: float = 0.08  # bbl/s lost per cell beyond the free span
@export var pipe_free_cells: float = 6.0
@export var pipe_min_fraction: float = 0.25
# Hydraulics: a pipe grade can lift a certain head (metres); terrain relief and
# friction consume it, pumps/compressors add it back. Pressure scales throughput.
@export var pipe_grade_head: PackedFloat32Array = PackedFloat32Array([14.0, 30.0, 50.0])
@export var pipe_head_per_cell: float = 0.45   # m of friction head per cell beyond the free span
@export var pipe_boost_head: float = 2.5       # m of head per bbl/s of booster
@export var pipe_head_scale: float = 55.0      # m of head margin per 100% throughput
@export var pipe_min_pressure: float = 0.20
# Associated gas: gas units produced per bbl of crude. Handled by a gas plant
# (sold), a flare (burned safely) or vented with a penalty.
@export var gas_ratio: float = 0.35
@export var gas_price: float = 14.0
@export_group("Access")
@export var gates: bool = false
@export var road_base: float = 0.0       # logistics capacity of any network
@export var road_per_cell: float = 0.0   # logistics capacity per road cell


func describe() -> String:
	if rate > 0.0:
		return "%.1f bbl/s" % rate
	if volume > 0.0:
		return "%d bbl" % int(volume)
	if feed > 0.0:
		return "%.1f bbl/s feed · %d%% yield" % [feed, int(yield_ratio * 100.0)]
	if boost > 0.0:
		return "+%.1f bbl/s" % boost
	if yield_bonus > 0.0:
		return "+%d%% refined yield" % int(yield_bonus * 100.0)
	if price_bonus > 0.0:
		return "+%d%% sale price" % int(price_bonus * 100.0)
	if radius > 0.0:
		return "%d cell survey radius" % int(radius)
	if pipe_base > 0.0:
		return "%.1f + %.1f/cell bbl/s" % [pipe_base, pipe_per_cell]
	if gates:
		return "site access"
	if road_base > 0.0:
		return "%.1f + %.1f/cell logistics" % [road_base, road_per_cell]
	return "—"
