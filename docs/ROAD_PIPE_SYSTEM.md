# Road & Pipeline System — Research and Design

What the industry does for 3D road/pipeline building, and how this prototype maps
onto it. Every rule below is implemented in `game/scripts/main.gd`.

---

## 1. What the research says

### Roads are a graph of nodes and segments

Cities: Skylines models every network as **nodes + segments**. A node is a
position and a direction; two nodes make a segment; segments have a maximum
length so a "straight" road is still several segments, which lets it follow the
terrain without clipping. The road mesh is a tesselated strip deformed by a
vertex shader from the spline data, and junctions are generated separately.
([Game Developer: Traffic systems in Cities: Skylines](https://www.gamedeveloper.com/design/game-design-deep-dive-traffic-systems-in-i-cities-skylines-i-),
[Game Developer: How Traffic Works](https://www.gamedeveloper.com/design/how-traffic-works-in-cities-skylines))

The modding documentation states the constraint that matters most for seams:

> "Segment Length … needs to match the length of the mesh used for the segment
> (and node if used), otherwise the road will overlap itself or have holes."

It also lists **Max Slope** and **Max Turn Angle** as first-class build limits,
and notes that roads **flatten the terrain** under them (`Half-width` controls
the flatten area). ([CSL Modding: Network Asset Creation](https://cslmodding.info/asset/network/))

RoadTool2 implements the same shape: a single `RoadNetwork` graph of `RoadNode`s
joined by `RoadSegment`s (cubic Béziers), with junctions computed where roads
meet and chunk meshes reconciled against the graph.
([K3rhos/RoadTool2](https://github.com/K3rhos/RoadTool2))

### Grid games use connection masks, not splines

For a tile game the simpler model is a grid graph: each cell has four ports, and
an autotiler picks the piece from its neighbours. A Godot autotiler notes:

> "Roads, pipes, fences, walls (4 neighbours): **6 pieces cover all 16 cases by
> rotation**."

([GridMap Autotiler for Godot 4](https://madrasco.itch.io/gridmap-autotiler),
[Godot GridMap docs](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html))

A procedural city-generator thread describes the same kit: straight, L, X, T,
dead-end, plus an up/down slope segment, with heights assigned afterwards and
tunnels/bridges where a height cannot be met.
([Godot Forums: procedural city generator](https://godotforums.org/d/19821-coding-a-procedural-city-generator))

Terrain-aware road tools in Godot flatten the heightfield to the road level; the
godot-road-generator lists "Terrain3D integration: flatten terrain to meet the
level of your roads with margins and falloff".
([TheDuckCow/godot-road-generator](https://github.com/TheDuckCow/godot-road-generator))

Route search over a coarse grid with a **bend cost** (so roads do not zig-zag) is
the standard procedural approach.
([E. B. Linsley: Procedural Road Network Generator](http://ellison.thinkling.uk/procedural-road-networks/))

### Pipes are fluid segments, not per-tile tanks

Factorio's reworked fluids are the clearest model:

- Connected pipes and tanks merge into **one segment**; a segment holds one fluid.
- Connections are **per-edge ports** in the four cardinal directions.
- **Junctions stop mattering** — only the machines on the segment do.
- Throughput is limited at the segment's **inputs and outputs**, not by length.
- **Pumps** force direction / raise throughput.

([Factorio FFF #416: Fluids 2.0](https://www.factorio.com/blog/post/fff-416),
[Factorio Wiki: Fluid system](https://wiki.factorio.com/fluid_system))

This is exactly the shape a pipeline tycoon wants: a run is one capacity pool,
storage tanks bridge runs, and pumps are the capacity upgrade.

---

## 2. How the prototype implements it

| Research idea | Implementation |
|---|---|
| Nodes + segments | Cells are nodes; 4-neighbour adjacency are edges. `_neighbour_mask()` produces a 4-bit mask; `_tile_for_mask()` maps it to straight / corner / tee / cross / end and rotation. |
| Six pieces cover 16 cases | Five meshes (`gam_pipe_*`, `gam_road_*`) + 0/90/180/270 rotation cover all 16 masks. |
| Segment length must match mesh length | Pipes are authored at 16 m **plus end flanges** (AABB 16.11 m) so bodies overlap at joints. Scaling tiles to exactly 16 m was a bug and opened ≈0.7 m seams; tiles are now grown 3% **about their own pivot**, never recentred by AABB (that would shift corner/tee pieces off the cell). |
| Straight roads are split to follow terrain | A run is a sequence of 16 m segments; the whole corridor is **graded** (see below) so each segment meets its neighbours flush. |
| Roads flatten terrain under them | `_lay_line()` resolves the route, then `_level_cells()` cuts/fills the corridor to one height (with a blended shoulder), then the tiles are spawned. |
| Max slope / max build angle | `MAX_GRADE = 2.4 m` rise between adjacent cells; `MAX_INFRA_RELIEF = 1.2 m` of unevenness under a single tile; `MAX_BUILD_RELIEF = 3.2 m` for building sites (paid levelling). |
| No diagonal gaps | `_line_cells()` emits an orthogonal (edge-adjacent) path, not Bresenham, so a diagonal drag cannot silently break the run. |
| Junctions | Tee/cross pieces; tanks bridge runs because a building joins every pipe component it touches and unions them. |
| Fluid segments | One 4-neighbour flood fill = one run. `comp_capacity[root] = 2.0 + 0.5 × cells + 8 × pumps` bbl/s. Junction count does not affect it. |
| Pumps | `[7]` Pump Station, `$45k`, adds `+8 bbl/s` to the run it touches. |
| Throughput limits at endpoints | Wells are throttled by the run capacity; refineries are limited by throughput; storage by capacity. |
| Access roads | A well/refinery only operates with an adjacent road (the reference game's rule). |

### Placement pipeline

```
drag start ──► _line_cells()        orthogonal, edge-adjacent route
           ──► _route_cells()      drop occupied / other-infra / too-uneven / too-steep
           ──► preview overlay     same cells the commit will build, priced per cell
release    ──► _lay_line()         grade corridor to one height, then spawn segments
           ──► _rebuild_components() recompute runs, capacity and road access
```

The preview and the commit call the **same** `_route_cells()`, so the quoted
price and the built length cannot disagree (covered by a self-test).

---

## 3. Deliberate limitations

- **No splines.** This is a grid tycoon; curves would complicate the economy and
  the AI-free traffic model. 90° corners are the vocabulary.
- **No lane/traffic simulation.** Roads gate access and carry upkeep; there are
  no vehicles to path.
- **One fluid.** Pipes carry crude only; there are no fluid types or mixing.
- **Corridor grading is free** and bundled into the per-cell price, so "pipeline
  costs by length" stays an exact, testable rule.

---

## 4. Verification

```powershell
Godot_v4.7.1-stable_mono_win64.exe --path game -- --selftest
```

15/15 checks: direct well→refinery yields nothing, a tank bridges runs, road
removal cuts production immediately, pipe/road cost scales per cell, pads level
to zero relief, route previews equal built runs, routes stay edge-connected,
pump stations raise capacity.

Screenshot modes: `--demo --shot`, `--demo --top --shot` (overhead layout),
`--demo --route --shot` (in-progress drag), `--demo --bend --shot` (corner join),
`--demo --overview --shot` (terrain rim).
