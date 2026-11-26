# Research Notes — What the Kit Is Based On

The asset list and the gameplay metadata were built from industry descriptions of
field development hardware, not from generic "factory" shapes. This file records
what was researched, what was taken, and where the simulation deliberately
simplifies.

## Sources consulted

| Source | Used for |
|---|---|
| OSHA Oil & Gas Well Drilling and Servicing eTool — Illustrated Glossary | rig component vocabulary (accumulator, rotary table, BOP, mud system) |
| SLB Oilfield Review, *Overview of Drilling Operations* | drill string, BHA, kelly, casing programme, depth classes |
| [eyerov.com — 7 types of offshore drilling platforms](https://eyerov.com/blogs/offshore-drilling-platforms) | platform taxonomy + water-depth envelopes |
| [Worldwide Recruitment Solutions — rig & platform types](https://www.worldwide-rs.com/blog/oil-rigs-offshore-platform-types) | jack-up / semi / drillship vs. fixed / compliant tower / TLP / spar / FPSO |
| [Drilling Manual — offshore rig selection](https://www.drillingmanual.com/offshore-drilling-rigs-types-in-oil-gas) | jack-up leg penetration, cantilever reach, tender-assist |
| [Deep Trekker — Offshore Platforms 101](https://www.deeptrekker.com/resources/oil-energy-platforms) | subsea wellhead vs. surface tree, risers, FPSO mooring |
| [Armoda — types of offshore drilling platforms](https://armoda.com/blog/types-of-offshore-drilling-platforms) | FPSO turret/swivel, spar generations |
| SPE JPT — *From Pixels to Pipelines* | how oil & gas games are used (Drill Deal, DrillSIM, MOL Freshhh upstream game) |
| SPE JPT — *Top 7 open-source petroleum simulators* | fidelity expectations for drilling sims |
| [IJEAIS — onshore rig structure design study](http://ijeais.org/wp-content/uploads/2021/4/IJEAIS210465.pdf) | land rig portability, skid-mounted modules, mast types |
| [US20210350477A1 — oil field simulation scenarios](https://patents.google.com/patent/US20210350477A1/en) | field development planning: rig schedules, development drilling, economics |

Game references used for the match loop: **Turmoil** (competitive multiplayer
rounds), **Drill Deal** (rig management), **Oil Enterprise / Oil Tycoon
Simulator** (leases, loans, contracts), **MOL Freshhh** (15-round NPV contest
format), **SimRefinery** (accessible process units).

---

## 1. Onshore drilling rig → `on_land_rig`

Real 1,500 HP land rigs are skid-mounted and move in loads. The kit models the
recognisable surface spread:

| Real component | In the model |
|---|---|
| Derrick / cantilever mast, 30–45 m | 36 m four-leg lattice with X bracing, crown block, travelling block, racked drill pipe |
| Substructure, 3–8 m high | 14 × 14 m box frame with stairs and V-door |
| Drawworks + rotary table + kelly | drum house beside the derrick, rotary table at floor level, kelly in the bushing |
| BOP stack + accumulator bottles | stacked annular/ram bodies under the floor, nitrogen bottles on the skid |
| Mud system | two 12 × 5 m tanks with agitators, two shale shakers, two mud pumps |
| Pipe rack + catwalk | 28 m three-tier rack feeding the V-door |
| Doghouse, gensets, fuel/water | site office, two generator packages, horizontal fuel tank |
| Flare / vent line | modelled on the production assets, not the rig |

Water-depth and depth capabilities in `manifest.json` (`drill_depth_m`,
`drill_rate_m_day`) follow the published class ranges: land rigs 3,000–7,600 m.

## 2. Offshore unit selection → five rigs + three production hosts

The kit deliberately covers the **whole selection matrix**, because choosing the
wrong host is the central strategic decision in the offshore game.

| Water depth | Drilling unit | Production host |
|---|---|---|
| 0–120 m | jack-up (`off_jackup_rig`, 120 m leg class) | fixed steel platform (`off_fixed_platform`) |
| 100–600 m | jack-up / moored semi | fixed platform limit → compliant tower (not modelled; TLP stands in) |
| 300–1,500 m | moored semi (`off_semi_submersible`) | TLP / spar (`off_spar`, 600 m+) |
| 600–3,000 m | dynamically positioned semi / drillship | spar, FPSO |
| 1,500–3,600 m | drillship (`off_drillship`) | FPSO (`off_fpso`) + subsea tie-back |

Structural vocabulary that made it into the meshes:

- **Jack-up** — triangular buoyant hull, three truss legs with spud cans, jacking
  houses, cantilever skid, 40 m derrick, helideck, pedestal cranes, lifeboats.
- **Semi-submersible** — two pontoons, four stability columns, deck box, derrick
  over the moonpool, thrusters, bracing.
- **Drillship** — ship hull, moonpool, dual-derrick arrangement, azimuth thrusters,
  forward helideck.
- **Fixed platform** — eight-leg jacket with X bracing and mudmats, boat landings,
  integrated deck, separation train, flare boom, riser porch, cranes, helideck.
- **FPSO** — internal turret + swivel stack, five topside process modules, amine
  and glycol columns, flare boom, aft accommodation, offloading hose, mooring.
- **Spar** — hard tank, truss section, soft tank, deck with drilling and process
  modules, mooring lines.

## 3. Subsea → `off_subsea_tree`, `off_subsea_manifold`, `off_riser_joint`

Subsea wells put the tree on the seabed and the wellhead on the seafloor, with
flowlines and risers carrying production to the host. Modelled accordingly:
protection frame, wellhead, tree body with gate valves and actuators, subsea
control module, flying lead, flowline hub; a six-slot manifold with headers,
branch valves and hubs; a hybrid riser joint with buoyancy modules and flanges.
`placement: "seabed"` tells the game to drop these to the seabed rather than the
waterline.

## 4. Midstream → processing and export

- **Gas plant** follows a conventional train: inlet separation → glycol
  dehydration → amine sweetening → cryogenic cold box / turbo-expander →
  deethanizer → product rundown, with pipe racks and a flare.
- **LNG train** adds the main cryogenic heat exchanger (cold box), refrigerant
  compressor house, heavies removal and a 4 Mtpa class layout. A separate LNG
  sphere covers storage (25,000 m³ class, single containment).
- **Terminal / jetty** — floating-roof tank farm, truck loading gantry, marine
  loading arms on a piled jetty with mooring dolphins.
- **Slug catcher, pig launcher, pump station** — the three objects that make a
  long pipeline legible on a map.

## 5. Refinery → 12 units that form a real flow

The downstream cluster is ordered the way a real refinery is:

```
CDU ─► VDU ─► FCC ─► (gasoline)
 │      └───► hydrocracker/hydrotreater ─► diesel
 ├─► reformer (naphtha → high-octane)
 ├─► coker (resid → coke + light ends)
 └─► amine (H2S removal) ─► Claus SRU (elemental sulfur)
```

Each unit is represented by its signature hardware: fired heater + column
(CDU/VDU), riser + regenerator + fractionator (FCC), three reactors + recycle
compressor (reformer), high-pressure separator (hydrotreater), paired coke drums
with derrick structure (coker), contactor/regenerator pair (amine), reaction
furnace + converters + incinerator (SRU), fan-deck cooling tower, and a 62 m
derrick flare.

## 6. Vehicles → what actually shows up on a lease

Pickups, crew buses, fuel and vacuum trucks, mobile cranes, pipe haulers,
cementing and wireline units, frac pump trailers, excavators, loaders, dozers,
fire trucks, forklifts. Speeds, capacities and crew counts in the manifest are
typical field values, rounded for gameplay.

## 7. Where the simulation deliberately simplifies

Honesty matters more than apparent fidelity:

| Reality | Kit / model |
|---|---|
| Dozens of pipe classes, elbows, reducers, supports | one generic pipe, flange, gate valve, gauge |
| Compressors, exchangers with thousands of tubes | boxes and cylinders with readable silhouettes |
| Structural design by code (API RP 2A, ISO 19902) | proportioned by eye for silhouette |
| Reservoir simulation (finite difference, compositional) | hyperbolic decline + material balance |
| Real refinery chemistry | topology and capacity only |
| Emissions, sour gas, HSE | single scalar per asset (`emissions_t_day`) |

That is the right trade for a tycoon-scale camera where a column is 40 px tall.
The shapes read correctly, the capacities are directionally right, and the
economy is where the depth lives.
