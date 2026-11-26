class_name NetworkSolver
extends RefCounted
## Pure pipe-network solver: components, building ports, union through tanks and
## per-run throughput.
##
## No scene tree and no catalogue dependency — port masks and capacity are passed
## in as Callables (dependency inversion), so this class can be exercised in
## isolation.

static func solve(pipes: Dictionary, buildings: Array, dirs: Array,
		port_mask_for: Callable, cell_capacity_for: Callable,
		run_capacity_for: Callable, role_for: Callable,
		cell_height_for: Callable = Callable(), cell_grade_for: Callable = Callable()) -> Dictionary:
	# 1) flood fill pipe cells into components
	var comp_of: Dictionary = {}
	var next_id := 0
	for start in pipes.keys():
		if comp_of.has(start):
			continue
		var queue: Array = [start]
		comp_of[start] = next_id
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for d in dirs:
				var n: Vector2i = c + d
				if pipes.has(n) and not comp_of.has(n):
					comp_of[n] = next_id
					queue.append(n)
		next_id += 1

	# 2) a building joins every component it touches through a declared port and
	#    unions them, so a tank can bridge two runs while two buildings never link
	var parent: Dictionary = {}
	for i in next_id:
		parent[i] = i
	for b in buildings:
		var allowed := int(port_mask_for.call(b))
		var adj: Dictionary = {}
		for cell in b.cells:
			for d in dirs:
				if (allowed & int(side_bit(d))) == 0:
					continue
				var n: Vector2i = (cell as Vector2i) + d
				if comp_of.has(n):
					adj[int(comp_of[n])] = true
		var ids: Array = adj.keys()
		if ids.is_empty():
			b.comp = -1
			continue
		var first := int(ids[0])
		for i in range(1, ids.size()):
			_union(parent, first, int(ids[i]))
		b.comp = first

	# 3) remap cells to merged roots, group members and derive capacity.
	#    A run's ceiling is its weakest cell (grade bottleneck); boosters add head
	#    and friction over the span reduces it further.
	var pipe_comp: Dictionary = {}
	var cell_count: Dictionary = {}
	var min_cap: Dictionary = {}
	var bottleneck: Dictionary = {}
	var h_min: Dictionary = {}
	var h_max: Dictionary = {}
	var min_grade: Dictionary = {}
	for cell in pipes.keys():
		var root := _find(parent, int(comp_of[cell]))
		pipe_comp[cell] = root
		cell_count[root] = int(cell_count.get(root, 0)) + 1
		var cc := float(cell_capacity_for.call(cell))
		if not min_cap.has(root) or cc < float(min_cap[root]):
			min_cap[root] = cc
			bottleneck[root] = cell
		if cell_height_for.is_valid():
			var hh := float(cell_height_for.call(cell))
			if not h_min.has(root) or hh < float(h_min[root]):
				h_min[root] = hh
			if not h_max.has(root) or hh > float(h_max[root]):
				h_max[root] = hh
		if cell_grade_for.is_valid():
			var gg := int(cell_grade_for.call(cell))
			if not min_grade.has(root) or gg < int(min_grade[root]):
				min_grade[root] = gg

	var members: Dictionary = {}
	for b in buildings:
		if int(b.comp) < 0:
			continue
		var root := _find(parent, int(b.comp))
		b.comp = root
		if not members.has(root):
			members[root] = {"wells": [], "storages": [], "refineries": [], "pumps": [],
				"processors": [], "meters": []}
		var m: Dictionary = members[root]
		match String(role_for.call(String(b.kind))):
			"producer":
				m.wells.append(b)
			"buffer":
				m.storages.append(b)
			"consumer":
				m.refineries.append(b)
			"booster":
				m.pumps.append(b)
			"processor":
				m.processors.append(b)
			"meter":
				m.meters.append(b)

	# 4) pump stations / compressors raise the throughput of the run they sit on
	var boost: Dictionary = {}
	for root in members.keys():
		var total := 0.0
		for pump in members[root].pumps:
			total += float(pump.get("boost", 0.0))
		boost[root] = total

	var capacity: Dictionary = {}
	var relief: Dictionary = {}
	for root in cell_count.keys():
		var r := 0.0
		if h_min.has(root) and h_max.has(root):
			r = float(h_max[root]) - float(h_min[root])
		relief[root] = r
		capacity[root] = float(run_capacity_for.call(float(min_cap[root]),
			int(cell_count[root]), float(boost.get(root, 0.0)),
			r, int(min_grade.get(root, 0))))

	return {"pipe_comp": pipe_comp, "members": members, "capacity": capacity,
		"cells": cell_count, "min_cap": min_cap, "boost": boost,
		"bottleneck": bottleneck, "relief": relief, "min_grade": min_grade}


static func side_bit(d: Vector2i) -> int:
	if d.x > 0:
		return PortSpec.SIDE_E
	if d.x < 0:
		return PortSpec.SIDE_W
	if d.y < 0:
		return PortSpec.SIDE_N
	return PortSpec.SIDE_S


static func _find(parent: Dictionary, x: int) -> int:
	var r := x
	while int(parent[r]) != r:
		r = int(parent[r])
	while int(parent[x]) != r:
		var nx := int(parent[x])
		parent[x] = r
		x = nx
	return r


static func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[rb] = ra
