# SOLID Refactor — Master Tracker

Goal: turn `game/scripts/main.gd` into a composition root over focused domain
classes, without changing game rules.

Legend: ⬜ not done · ✅ done · ❌ blocked

## Phase 1 — Building catalogue ✅

Single source of truth for structures: cost, footprint, model, upkeep, pipeline
**role**, **ports** (in/out/links) and **capacity**. Adding a structure = one
entry.

| # | Task | Status |
|---|------|--------|
| 1.1 | `game/scripts/domain/building_catalogue.gd` (`BuildingCatalogue`) | ✅ |
| 1.2 | Move `CATALOG` + `PORTS` out of `main.gd`; all reads via the class | ✅ |
| 1.3 | Capacity-driven sim (well rate, tank volume, refinery feed, pump boost, pipe capacity) | ✅ |
| 1.4 | Rule suite green | ✅ |

## Phase 2 — Grid geometry ⬜

`GridGeometry` owns `CELL/GRID/HALF`, side bits, `DIRS`, `cell_to_world`,
`world_to_cell`, `cells_for`, `line_cells`, `in_bounds`. Removes duplicate
constants and makes routing testable.

| # | Task | Status |
|---|------|--------|
| 2.1 | `game/scripts/domain/grid_geometry.gd` | ⬜ |
| 2.2 | Delete geometry constants/helpers from `main.gd`; call the class | ⬜ |
| 2.3 | Rule suite green | ⬜ |

## Phase 3 — Network solver ✅

`NetworkSolver` (pure): pipe components, union of runs through buildings,
per-run capacity, connected port sides. Inputs are plain data; ports come from
a `Callable`, so the solver does not import the catalogue (DIP).

| # | Task | Status |
|---|------|--------|
| 3.1 | `game/scripts/domain/network_solver.gd` | ⬜ |
| 3.2 | `main._rebuild_components()` delegates; no rule logic left | ⬜ |
| 3.3 | Solver unit test (headless) | ⬜ |

## Phase 4 — Economy + survey services ⬜

| # | Task | Status |
|---|------|--------|
| 4.1 | `Economy` (cash, debt, price, upkeep, loan, victory) | ⬜ |
| 4.2 | `SurveyService` (reveal radius, road gating) | ⬜ |
| 4.3 | `main._simulate()` delegates | ⬜ |

## Phase 5 — Placement rules ⬜

| # | Task | Status |
|---|------|--------|
| 5.1 | `PlacementRules` (occupancy, ports, grade, relief, cash, route) | ⬜ |
| 5.2 | Ghost/route preview use the same rules object | ⬜ |
| 5.3 | Rule suite + SOLID review | ⬜ |

## Phase 7 — Catalogue expansion ✅

Grew the buildable set from 7 to **28** entries through data only (24 structures +
4 units). Each entry is a `BuildingDefinition` resource with role, ports,
capacity and UI data; the menu, hotkeys, icons, model loading and placement
rules all read the catalogue.

| Batch | Structures |
|---|---|
| Core | Pumpjack, Storage Tank, Refinery, Exploration Office, Pipeline, Road, Pump Station |
| Process | Tank Farm, Separator, Heater Treater, Flare, Metering Skid, Compressor, Manifold, Gas Plant, Water Disposal, Slug Catcher |
| Refining | Crude Distillation, Vacuum Distillation, Catalytic Cracker, Control Room, Cooling Tower, Pig Launcher, Tank Terminal |
| Units | Crew Pickup, Fuel Tanker, Pipe Truck, Mobile Crane |

- Menu is generated and scrollable; hotkeys, icons (`assets/icons/<id>.png`),
  model list and placement flags are all data — no per-structure code.
- Every structure has a generated UI icon.
- Rule check: a runtime-defined `test_booster` builds and boosts capacity with
  **no code changes**.

| # | Task | Status |
|---|------|--------|
| 7.1 | 20 model assets staged | ✅ |
| 7.2 | `.tres` catalogue (20 entries) generated | ✅ |
| 7.3 | Generated icons + `icon_path` convention | ✅ |
| 7.4 | Scrollable, data-driven build menu + hotkeys | ✅ |
| 7.5 | Role-driven solver + simulation bonuses | ✅ |

## Phase 8 — Street network management ✅

| # | Task | Status |
|---|------|--------|
| 8.1 | Access requires a network serving ≥2 sites | ✅ |
| 8.2 | Logistics capacity (`2 + 0.5/cell`) + congestion throttle | ✅ |
| 8.3 | HUD `LOGI`, isolated-road overlay, road inspector | ✅ |
| 8.4 | Rule checks: capacity/load and congestion | ✅ |

## Phase 9 — Structure rotation ✅

| # | Task | Status |
|---|------|--------|
| 9.1 | `R` rotates the pending structure and its port mask | ✅ |
| 9.2 | `_building_port_mask()` used by solver/inspector/connectors | ✅ |
| 9.3 | Rule check: rotated pumpjack exposes its south port | ✅ |

## Phase 10 — Persistence ✅

| # | Task | Status |
|---|------|--------|
| 10.1 | `F5` saves cash/debt/time/structures/pipes/roads/deposits | ✅ |
| 10.2 | `F9` clears and rebuilds the field | ✅ |
| 10.3 | Rule check: save → mutate → load restores counts and cash | ✅ |

## Phase 11 — Composition root ⬜

| # | Task | Status |
|---|------|--------|
| 11.1 | `main.gd` wires services/views only; no rules | ⬜ |
| 11.2 | SOLID checklist (§5 of dev-lifecycle-standards) | ⬜ |
| 11.3 | Docs + screenshots regenerated | ⬜ |

## Phase 12 — Fleet / units ✅

Units are bought from the same catalogue (role `unit`), so adding a vehicle is
data only: a definition, a model and an icon.

| # | Task | Status |
|---|------|--------|
| 12.1 | 4 units: Crew Pickup, Fuel Tanker, Pipe Truck, Mobile Crane | ✅ |
| 12.2 | Buying adds road logistics capacity + upkeep | ✅ |
| 12.3 | Vehicle spawns on a served road cell | ✅ |
| 12.4 | FLEET menu section, per-unit counts, strip readout | ✅ |
| 12.5 | Save/load persists the fleet and respawns vehicles | ✅ |
| 12.6 | Rule checks: logistics, payment, vehicle, persistence (34/34) | ✅ |

## Phase 13 — Sales contracts ✅

| # | Task | Status |
|---|------|--------|
| 13.1 | Periodic contract offers (target / time / premium) | ✅ |
| 13.2 | Sales apply the premium and track delivered barrels | ✅ |
| 13.3 | Completion bonus and expiry handling | ✅ |
| 13.4 | HUD contract line + persistence | ✅ |
| 13.5 | Rule check (36/36) | ✅ |

## Phase 14 — In-place replacement ✅

| # | Task | Status |
|---|------|--------|
| 14.1 | Dragging a pipe over a road (or road over pipe) replaces it | ✅ |
| 14.2 | Route preview allows replaceable cells, matching the build | ✅ |
| 14.3 | Rule check (36/36) | ✅ |

## Phase 15 — Port joints & placement preview ✅

The grid was connecting pipes to the wrong side because the connector loop used
the pipe→building direction. Fixed and hardened:

| # | Task | Status |
|---|------|--------|
| 15.1 | Connector checks the building's port facing the pipe (`-d`) | ✅ |
| 15.2 | Pipe tiling mask includes adjacent ports, so tiles grow real arms | ✅ |
| 15.3 | 2×2 structures scale to their whole footprint (31.4 m, not 15 m) | ✅ |
| 15.4 | Joint ends on the model silhouette (`_structure_half`) | ✅ |
| 15.5 | Corridor lifted to the pad, riser hides height gaps | ✅ |
| 15.6 | Route preview colours port joints green / dead-ends orange | ✅ |
| 15.7 | Inspector shows route length, price and port-joint count | ✅ |
| 15.8 | Pipe drag snaps to a structure port (and skips the motor side) | ✅ |
| 15.9 | Road preview reports sites served and network continuity | ✅ |
| 15.10 | Rule checks: motor side, port side, joint span, pad lift, route price, snapping, road preview | ✅ |
| 15.11 | `--joint` and `--pipe-route` screenshots | ✅ |
| 15.12 | Full suite green (**49/49**) | ✅ |

## Phase 16 — Network manager ✅

| # | Task | Status |
|---|------|--------|
| 16.1 | `_network_rows()` summarises every pipe run and street network | ✅ |
| 16.2 | HUD NETWORKS panel lists runs with utilisation, `dry`/`MAX`/`isolated`/`busy` | ✅ |
| 16.3 | Rows are colour-coded and click-to-highlight the run (camera focuses) | ✅ |
| 16.4 | Concrete driveways visually connect roads to pads | ✅ |
| 16.5 | Rule check: manager lists both pipe runs and streets | ✅ |
| 16.6 | Warning markers + road inspector site list | ✅ |
| 16.7 | Fleet assigned to the selected street network (no global leak) | ✅ |
| 16.8 | Fleet purchase rebuilds capacity immediately; assignment persists | ✅ |
| 16.9 | `F6` transfers a unit to the selected street; selection marked in panel | ✅ |
| 16.10 | Build-order regression: pipe→structure and bulldoze | ✅ |
| 16.11 | Per-run income on the dashboard; survey office status fixed | ✅ |
| 16.12 | Load clears stale run income | ✅ |
| 16.13 | `F7` demolishes the selected run/street with refunds | ✅ |
| 16.14 | `H` field manual for the network rules and keys | ✅ |
| 16.15 | Pipe-run demolish regression | ✅ |
| 16.16 | Click the minimap to jump the camera | ✅ |
| 16.17 | Build-menu filter; 8× speed; inspector income/fleet | ✅ |
| 16.18 | Foreclosure at −$250k with restart; victory loop closed | ✅ |
| 16.19 | Company-value chip tracks the $1M goal | ✅ |
| 16.20 | Truck Depot: data-only street boost (+3 logistics) | ✅ |
| 16.21 | Depot inspector explains its street boost | ✅ |
| 16.22 | Depot uses the workshop model + `--depot` screenshot | ✅ |
| 16.23 | `--playtest` normal-start check + `docs/VERIFICATION.md` | ✅ |
| 16.24 | Victory overlay "New lease" restart | ✅ |
| 16.25 | Full suite green (**69/69**) | ✅ |
