class_name BuildingCatalogue
extends Resource
## The set of buildable structures. Saved as `res://data/catalogue.tres` so it
## can be edited in the Inspector; lookups are O(n) over a handful of entries.

@export var entries: Array[BuildingDefinition] = []


func find(id: String) -> BuildingDefinition:
	for entry in entries:
		if entry.id == id:
			return entry
	return null


func has(id: String) -> bool:
	return find(id) != null


func cost(id: String) -> float:
	var entry := find(id)
	return entry.cost if entry != null else 0.0


## Base throughput of a single pipe cell of the given grade.
func pipe_grade_capacity(grade: int) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null:
		return 0.0
	var caps := pipe.capacity.pipe_grade_caps
	if caps.is_empty():
		return pipe.capacity.pipe_base
	return float(caps[clampi(grade, 0, caps.size() - 1)])


func pipe_grade_cost(grade: int) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null:
		return 0.0
	var costs := pipe.capacity.pipe_grade_costs
	if costs.is_empty():
		return pipe.cost
	return float(costs[clampi(grade, 0, costs.size() - 1)])


func pipe_grade_upkeep(grade: int) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null:
		return 0.0
	var up := pipe.capacity.pipe_grade_upkeep
	if up.is_empty():
		return pipe.upkeep
	return float(up[clampi(grade, 0, up.size() - 1)])


func pipe_grade_name(grade: int) -> String:
	match clampi(grade, 0, 2):
		1:
			return "Trunk"
		2:
			return "High-pressure"
	return "Standard"


## Available static head (metres) for a pipe grade.
func pipe_grade_head(grade: int) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null or pipe.capacity.pipe_grade_head.is_empty():
		return 0.0
	var heads := pipe.capacity.pipe_grade_head
	return float(heads[clampi(grade, 0, heads.size() - 1)])


## Pressure ratio (0..1) after climbing the run's relief and paying friction.
## Booster stations add head, so a pumped run keeps its nameplate throughput.
func pipe_run_pressure(cells: int, boost: float, relief: float, grade: int) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null:
		return 1.0
	var cap := pipe.capacity
	var head := pipe_grade_head(grade) + boost * cap.pipe_boost_head
	var need := maxf(0.0, relief) \
		+ cap.pipe_head_per_cell * maxf(0.0, float(cells) - cap.pipe_free_cells)
	var margin := head - need
	return clampf(1.0 + margin / maxf(1.0, cap.pipe_head_scale),
		cap.pipe_min_pressure, 1.0)


## Throughput of a whole run: the weakest cell is the ceiling, pumps/compressors
## add head, terrain relief and friction erode the rest.
func pipe_run_capacity(min_cell_cap: float, cells: int, boost: float,
		relief: float = 0.0, grade: int = 0) -> float:
	var pipe := find("pipe")
	if pipe == null or pipe.capacity == null:
		return min_cell_cap + boost
	var cap := pipe.capacity
	var base := min_cell_cap + boost
	var friction := cap.pipe_friction * maxf(0.0, float(cells) - cap.pipe_free_cells)
	if relief <= 0.0:
		return maxf(cap.pipe_min_fraction * min_cell_cap, base - friction)
	var pressure := pipe_run_pressure(cells, boost, relief, grade)
	return maxf(cap.pipe_min_fraction * min_cell_cap, base * pressure - friction)


func gas_ratio() -> float:
	var pipe := find("pipe")
	return pipe.capacity.gas_ratio if pipe != null and pipe.capacity != null else 0.0


func gas_price() -> float:
	var pipe := find("pipe")
	return pipe.capacity.gas_price if pipe != null and pipe.capacity != null else 0.0
