# Building ↔ Pipeline Connections

Which buildings connect to a pipeline, where the connection is, and why.
Everything here is data in `game/scripts/main.gd` (`PORTS`) and is enforced at
runtime.

---

## 1. The real chain (so the game mirrors it)

A producing lease is wired like this:

```
wellhead (Christmas tree)
   └─ flowline ──► separator / heater-treater ──► storage tank(s) ──► LACT meter
                                                                        └─ gathering / sales pipeline ──► refinery
```

- A **flowline** carries total well fluids from the *wellhead* to the first
  separation equipment.
- **Interconnecting piping** joins separators, heaters, pumps and tanks.
- A **gathering / sales pipeline** leaves the battery (usually through the LACT
  unit) for a refinery or terminal.
- Tanks have **inlet and outlet nozzles** and are the buffer between the two.
  ([J. J. Keller: flowlines and gathering lines](https://jjkellercompliancenetwork.com/institute/flowlines-and-gathering-lines),
  [PetroWiki: Piping and Pipelines](https://petrowiki.spe.org/PEH:Piping_and_Pipelines),
  [AAPG: Surface production equipment](https://wiki.aapg.org/Surface_production_equipment))

No process fluid goes to an **office**. Field offices, workshops and warehouses
are on the **road** side of the site, not the pipe side.

---

## 2. Ports per building

Sides use the 4-neighbour bits `E=1 N=2 W=4 S=8`.

| Building | Pipe role | Port sides | Links | Capacity | Notes |
|---|---|---|---|---|---|
| **Pumpjack** | producer | `E N W` | 1 | 1.7 bbl/s | Flowline leaves the production side; the **south** side is the motor/access side and is not a port. |
| **Storage Tank** | buffer | `E N W S` | 2 | 600 bbl | Inlet/outlet nozzles; **bridges two runs**. |
| **Tank Farm** | buffer | `E N W S` | 2 | 2,400 bbl | 2×2 pad, large buffer, bridges runs. |
| **Separator** | processor | `E N W S` | 2 | +10% refined yield | Cleans well flow for the run it sits on. |
| **Heater Treater** | processor | `E N W S` | 2 | +8% refined yield | Heats the emulsion before storage. |
| **Flare** | processor | `E N W S` | 2 | +5% refined yield | Safe-operations bonus; small plot. |
| **Metering Skid** | meter | `E N W S` | 2 | +6% sale price | Custody-transfer meter for the run. |
| **Compressor Station** | booster | `E N W S` | 2 | +5 bbl/s | Raises run throughput. |
| **Gathering Manifold** | booster | `E N W S` | 2 | +2 bbl/s | Small throughput boost / junction. |
| **Refinery** | consumer | `E N W` | 1 | 3.4 bbl/s feed, 92% yield | Feed inlet on the process side; product sold automatically. The **south** side is the road side. |
| **Crude Distillation Unit** | consumer | `E N W` | 1 | 5.0 bbl/s feed, 90% yield | Larger 2×2 refinery. |
| **Pump Station** | booster | `E N W S` | 2 | +8 bbl/s | Inline booster. |
| **Exploration Office** | survey | none | 0 | 11-cell radius | **No pipeline port**; needs a road before it surveys. |
| **Pipeline** | transport | — | — | 2.0 + 0.5/cell bbl/s | Per-cell cost/upkeep; graded corridor. |
| **Road** | access | — | — | 2.0 + 0.5/cell logistics | Must serve **≥2 sites**; over-capacity throttles throughput. |

### Why the office has no ports

- It handles no fluid: no flowline, no inlet, no outlet. Piping an office would
  be a modelling error, not a shortcut.
- Its logistics are **road** access (crews, survey crews), which is a different
  network in this game.
- Gameplay: it keeps the build menu honest — only process equipment accepts a
  pipeline, so the pipe tool is never a "decorate anything" tool.

The self-test asserts this: a pipe placed next to an exploration office must not
join any run (`occupied[office].comp == -1`).

---

## 3. How a connection is made

1. **Adjacency through a port.** `_rebuild_components()` walks each building's
   cells; a neighbouring pipe cell only counts if its direction is in the
   building's port mask (`_side_bit()` + `_ports_mask()`).
2. **Components and bridging.** Pipe cells form 4-neighbour components. A
   building joins every component it touches through a port and **unions** them.
   Tanks can bridge two runs; wells and refineries cannot.
3. **Direction is a role, not a per-tile arrow.**
   - wells push into the run,
   - tanks store,
   - refineries pull and sell,
   - pumps boost the run's capacity.
   Junctions therefore do not matter — the run is one capacity pool, the same
   simplification Factorio adopted for fluids
   ([FFF #416](https://www.factorio.com/blog/post/fff-416)).
4. **Visual connector, derived from the model.** `_add_pipe_connectors()` draws
   the joint from the pipe tile to the structure's **actual silhouette**:
   - `_structure_half()` measures the spawned model's mesh bounds, so a round
     tank and a boxy skid both report their real face.
   - `_pipe_mask()` adds an arm toward every adjacent **port** (same
     building→pipe direction convention as `NetworkSolver`), so the tile is a
     tee/elbow instead of a dead-end.
   - `_lay_line()` lifts the graded corridor to the highest pad it plugs into,
     so the spool meets the nozzle instead of being buried under the pad.
   - A short riser at the wall hides any remaining pad-height difference.
   Nothing here is per-structure: a new definition with ports gets the same
   treatment automatically.
5. **Inspector.** Selecting a building shows its port sides and which sides
   actually carry a pipe, e.g. `Flowline port: E N W · pipe on N`.

---

## 4. Placement rules that fall out of this

- A pumpjack's pipe must touch its `E`, `N` or `W` side; a pipe on the south
  side is refused (self-test: "pumpjack ignores a pipe on its motor side").
- A refinery's feed likewise cannot come from its south side.
- A tank can accept a pipe on any side and is the only bridge between runs.
- An office can never be part of a run.
- Everything still needs a **road** to operate (wells and refineries), which is
  the second, orthogonal network.

---

## 5. Game-system references

- **Nodes + segments** for road/pipe networks, with per-direction connections:
  Cities: Skylines
  ([Game Developer](https://www.gamedeveloper.com/design/game-design-deep-dive-traffic-systems-in-i-cities-skylines-i-),
  [CSL modding: Network Asset Creation](https://cslmodding.info/asset/network/)).
- **Per-entity pipe connection positions and directions** (fluid boxes), and
  connected pipes treated as one segment: Factorio
  ([FluidBox docs](https://lua-api.factorio.com/latest/types/FluidBox.html),
  [Fluid system](https://wiki.factorio.com/fluid_system)).
- **4-neighbour autotiling** (6 pieces cover 16 cases by rotation) and
  GridMap/MeshLibrary: Godot
  ([GridMap Autotiler](https://madrasco.itch.io/gridmap-autotiler),
  [GridMap docs](https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html)).

---

## 6. Verification

```powershell
Godot_v4.7.1-stable_mono_win64.exe --path game -- --selftest
```

Relevant checks (17/17 total):

```
PASS  well -> tank -> refinery flows
PASS  well -> pipe -> refinery makes NO income without storage
PASS  exploration office exposes no pipeline port
PASS  pumpjack ignores a pipe on its motor side
PASS  pump station raises run capacity
```
