# Asset Library

**82 assets · 440,190 triangles · generated with Blender 5.2.1 LTS**

Auto-generated from `assets/json/manifest.json` by `blender/gen_docs.py`. Do not edit by hand — edit the builder in `blender/kit/` and rebuild.

## Conventions

| | |
|---|---|
| units | meters |
| up axis | +Z |
| forward axis | -Y |
| origin | base centre, z=0 on ground |
| shading | flat/faceted stylised PBR |
| team tint materials | `paint_yellow`, `paint_orange`, `paint_blue`, `paint_red`, `paint_green`, `paint_teal` |

## Summary

| Category | Assets | Triangles |
|---|---:|---:|
| Onshore Upstream | 14 | 58,874 |
| Offshore & Marine | 15 | 96,560 |
| Midstream — Pipelines, Gas & LNG | 8 | 100,463 |
| Downstream — Refinery | 12 | 111,346 |
| Vehicles & Heavy Equipment | 15 | 64,715 |
| Environment, Site & Gameplay Props | 18 | 8,232 |
| **Total** | **82** | **440,190** |

## Onshore Upstream

_Drilling, lift, separation, storage and gathering. Tier-1 through tier-2 play._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Flare Stack 34 m | `on_flare` | 1,168 | 12 × 10 × 35.16 | $800 k | 8 d | 1 | gas rate 12 MMscf/d · crew 2 · power 0 kW |
| Wellpad Gathering Manifold | `on_gathering_manifold` | 3,768 | 16 × 8 × 1.5 | $350 k | 3 d | 1 | well slots 12 · crew 2 · power 0 kW |
| Heater Treater | `on_heater_treater` | 1,560 | 9 × 4 × 6.025 | $450 k | 4 d | 1 | fluid rate 2,500 bbl/d · crew 2 · power 40 kW |
| Land Drilling Rig (1500 HP) | `on_land_rig` | 18,164 | 46.035 × 44 × 52.61 | $18.0 M | 45 d | 1 | max depth 4,500 m · crew 52 · power 2,500 kW |
| Pipeline Segment (10 m) | `on_pipeline_segment` | 564 | 11 × 2.6 × 1.423 | $40 k | 1 d | 1 | oil rate 25,000 bbl/d · crew 1 · power 0 kW |
| Beam Pumping Unit | `on_pumpjack` | 3,372 | 16.8 × 6 × 8.15 | $250 k | 3 d | 1 | oil rate 250 bbl/d · crew 1 · power 45 kW · recovery factor 0.28 |
| 3-Phase Separator Package | `on_separator` | 1,480 | 6 × 3.943 × 2.9 | $900 k | 5 d | 1 | fluid rate 8,000 bbl/d · crew 3 · power 60 kW |
| Crude Tank Farm (4 x 10,000 bbl) | `on_tank_farm` | 10,336 | 46 × 37.8 × 12.539 | $1.6 M | 12 d | 1 | storage 40,000 bbl · crew 4 · power 120 kW |
| Wellhead / Christmas Tree | `on_wellhead` | 2,184 | 5.875 × 5 × 3.791 | $120 k | 2 d | 1 | crew 1 · power 0 kW |
| Gas Compressor Station | `on_compressor_station` | 2,636 | 26.3 × 18 × 12.25 | $2.2 M | 14 d | 2 | gas rate 10 MMscf/d · crew 6 · power 1,400 kW |
| Custody Metering Skid | `on_metering_skid` | 1,572 | 9.85 × 3.4 × 1.8 | $600 k | 4 d | 2 | crew 2 · power 25 kW · accuracy pct 0.25 |
| Pipeline Valve Station | `on_pipeline_valve` | 776 | 4.5 × 3.05 × 1.725 | $180 k | 2 d | 2 | crew 1 · power 5 kW |
| Saltwater Disposal Facility | `on_saltwater_disposal` | 4,382 | 18.982 × 14 × 8.835 | $700 k | 6 d | 2 | water 5,000 bbl/d · crew 3 · power 180 kW |
| Workover / Service Rig | `on_workover_rig` | 6,912 | 22 × 16 × 25.65 | $2.4 M | 8 d | 2 | max depth 2,500 m · crew 12 · power 320 kW |

## Offshore & Marine

_Waterline-origin assets (`placement: waterline`) except the subsea tree and manifold which sit on the seabed. Submerged structure is modelled to give the game a visible waterline cut._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Fast Crew Boat | `off_crew_boat` | 576 | 38 × 14.07 × 13.787 | $6.5 M | 20 d | 1 | crew 6 · passengers 60 · speed 32 kn · power 4,000 kW |
| Platform Supply Vessel | `off_supply_vessel` | 1,976 | 78 × 18 × 24.67 | $28.0 M | 60 d | 1 | crew 14 · speed 13 kn · power 5,000 kW |
| Anchor Handling Tug | `off_ahts` | 628 | 69.439 × 16 × 19.48 | $42.0 M | 70 d | 2 | crew 16 · power 18,000 kW |
| Fixed Steel Platform | `off_fixed_platform` | 6,144 | 67.8 × 46 × 88.875 | $340.0 M | 300 d | 2 | oil rate 45,000 bbl/d · well slots 24 · water depth 110 m · crew 60 · power 6,000 kW |
| Medium Transport Helicopter | `off_helicopter` | 1,212 | 13.55 × 7.352 × 4.245 | $18.0 M | 0 d | 2 | crew 2 · passengers 19 · speed 150 kn · power 2,600 kW |
| Jack-Up Drilling Rig | `off_jackup_rig` | 25,184 | 62 × 70.27 × 113.225 | $210.0 M | 120 d | 2 | max depth 7,600 m · water depth 120 m · crew 120 · power 12,000 kW |
| Hybrid Riser Joint (24 m) | `off_riser_joint` | 658 | 2.918 × 2.274 × 24 | $2.4 M | 2 d | 2 | oil rate 30,000 bbl/d · crew 0 · power 0 kW |
| Shuttle Tanker (1.0 MMbbl) | `off_shuttle_tanker` | 9,388 | 245 × 42 × 38.16 | $95.0 M | 120 d | 2 | crew 24 · speed 14 kn · power 14,000 kW |
| Subsea Production Manifold | `off_subsea_manifold` | 1,324 | 11.7 × 6.341 × 2.6 | $48.0 M | 30 d | 2 | well slots 6 · crew 0 · power 0 kW |
| Subsea Christmas Tree | `off_subsea_tree` | 638 | 6.045 × 5.677 × 4.35 | $32.0 M | 25 d | 2 | water depth 3,000 m · crew 0 · power 8 kW |
| FPSO (Floating Production Storage Offloading) | `off_fpso` | 7,560 | 248 × 86.846 × 91.174 | $1.10 bn | 420 d | 3 | oil rate 120,000 bbl/d · min water depth 300 m · crew 110 · power 28,000 kW |
| S-Lay Pipelay Barge | `off_pipelay_barge` | 3,600 | 151.516 × 53.648 × 47.018 | $260.0 M | 180 d | 3 | crew 240 · power 20,000 kW |
| Semi-Submersible Rig | `off_semi_submersible` | 17,028 | 71.78 × 80.926 × 79.225 | $520.0 M | 240 d | 3 | max depth 9,000 m · water depth 2,400 m · crew 180 · power 26,000 kW |
| Truss Spar Platform | `off_spar` | 4,232 | 84.232 × 84.232 × 115.149 | $820.0 M | 380 d | 3 | oil rate 70,000 bbl/d · well slots 16 · min water depth 600 m · crew 45 · power 9,000 kW |
| Ultra-Deepwater Drillship | `off_drillship` | 16,412 | 232.56 × 83.166 × 75.025 | $780.0 M | 300 d | 4 | max depth 12,000 m · water depth 3,600 m · crew 220 · power 42,000 kW |

## Midstream — Pipelines, Gas & LNG

_The pipe between the field and the money. Capacity here is usually the binding constraint in a match._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Pig Launcher / Receiver | `mid_pig_launcher` | 1,534 | 12 × 4 × 2.74 | $380 k | 3 d | 1 | crew 2 · power 0 kW |
| Pipeline Pump Station | `mid_pump_station` | 3,585 | 38 × 22.035 × 12.25 | $4.8 M | 18 d | 2 | oil rate 180,000 bbl/d · crew 8 · power 3,200 kW |
| Slug Catcher | `mid_slug_catcher` | 2,972 | 40 × 14 × 12.25 | $6.2 M | 22 d | 2 | gas rate 250 MMscf/d · crew 4 · power 120 kW |
| Gas Processing Plant | `mid_gas_plant` | 41,216 | 92.712 × 63.725 × 42.56 | $420.0 M | 420 d | 3 | gas rate 400 MMscf/d · crew 140 · power 34,000 kW · sulfur t day 180 |
| LNG Storage Sphere | `mid_lng_sphere` | 2,336 | 34 × 35 × 28.52 | $180.0 M | 180 d | 3 | volume 25,000 m³ · crew 6 · power 600 kW |
| Marine Loading Jetty | `mid_loading_jetty` | 2,652 | 44.727 × 143.64 × 28.453 | $240.0 M | 300 d | 3 | crew 30 · power 1,200 kW |
| Crude Terminal & Truck Loading | `mid_tank_terminal` | 17,224 | 115.1 × 80.5 × 31.48 | $96.0 M | 260 d | 3 | storage 1,200,000 bbl · crew 60 · power 4,500 kW |
| LNG Liquefaction Train (4 Mtpa) | `mid_lng_train` | 28,944 | 74.712 × 50.25 × 35.46 | $2.40 bn | 1100 d | 4 | LNG 4 Mtpa · crew 220 · power 180,000 kW |

## Downstream — Refinery

_Process units are stylised but topologically honest: furnace, column, reactor, exchanger, flare. Each maps to one throughput decision._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Refinery Flare (62 m) | `ref_flare` | 2,016 | 22.07 × 22.035 × 63.56 | $22.0 M | 120 d | 1 | gas rate 180 MMscf/d · crew 8 · power 0 kW |
| Pipe Rack Module (20 m) | `ref_pipe_rack` | 648 | 21 × 9 × 6.65 | $650 k | 4 d | 1 | crew 3 · power 0 kW |
| Amine Sweetening Unit | `ref_amine` | 14,560 | 42.225 × 35.042 × 25.51 | $120.0 M | 200 d | 2 | gas rate 120 MMscf/d · crew 30 · power 5,000 kW |
| Crude Distillation Unit | `ref_cdu` | 18,362 | 66 × 49.4 × 50.61 | $380.0 M | 380 d | 2 | throughput 150,000 bbl/d · crew 90 · power 18,000 kW |
| Control Room & Substation | `ref_control_room` | 1,012 | 30.07 × 22.035 × 10.3 | $48.0 M | 160 d | 2 | crew 40 · power 1,200 kW |
| Induced Draft Cooling Tower | `ref_cooling_tower` | 2,080 | 32.036 × 28 × 12.95 | $34.0 M | 150 d | 2 | crew 12 · power 4,200 kW |
| Hydrotreater | `ref_hydrotreater` | 13,396 | 46.725 × 35.412 × 31.9 | $260.0 M | 300 d | 2 | throughput 55,000 bbl/d · crew 50 · power 11,000 kW |
| Vacuum Distillation Unit | `ref_vdu` | 13,596 | 54.25 × 37.675 × 40.28 | $190.0 M | 260 d | 2 | throughput 90,000 bbl/d · crew 45 · power 9,000 kW |
| Delayed Coking Unit | `ref_coker` | 10,950 | 56.25 × 42 × 37.9 | $540.0 M | 430 d | 3 | throughput 35,000 bbl/d · crew 80 · power 16,000 kW |
| Fluid Catalytic Cracking Unit | `ref_fcc` | 13,608 | 70 × 50 × 43.46 | $720.0 M | 520 d | 3 | throughput 70,000 bbl/d · crew 120 · power 42,000 kW · gasoline yield 0.52 |
| Catalytic Reformer | `ref_reformer` | 17,852 | 48 × 39.675 × 34.9 | $310.0 M | 340 d | 3 | throughput 40,000 bbl/d · crew 60 · power 14,000 kW |
| Claus Sulfur Recovery Unit | `ref_sru` | 3,266 | 44 × 34.15 × 30.8 | $160.0 M | 240 d | 3 | crew 28 · power 2,800 kW · sulfur t day 220 |

## Vehicles & Heavy Equipment

_All vehicles face −Y. Wheels are separate geometry but joined into the body mesh; animate by splitting the wheel objects if you need rolling wheels._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Bulldozer | `veh_bulldozer` | 2,200 | 3.55 × 7.475 × 4.46 | $480 k | — d | 1 | crew 1 |
| Crew Bus | `veh_crew_bus` | 3,828 | 3.3 × 11.03 × 2.987 | $180 k | — d | 1 | crew 45 · speed 100 km/h |
| Field Car | `veh_crew_car` | 2,880 | 2.2 × 4.98 × 1.768 | $32 k | — d | 1 | crew 4 · speed 160 km/h |
| Excavator | `veh_excavator` | 2,132 | 3.01 × 9.06 × 4.673 | $420 k | — d | 1 | crew 1 |
| Forklift | `veh_forklift` | 2,284 | 1.79 × 4.25 × 2.598 | $65 k | — d | 1 | crew 1 · lift 3 t |
| Fuel Tanker | `veh_fuel_tanker` | 5,956 | 3.35 × 10.415 × 3.617 | $260 k | — d | 1 | storage 220 bbl · crew 2 · speed 90 km/h |
| Crew Pickup (4x4) | `veh_pickup` | 3,140 | 2.33 × 5.81 × 2.048 | $48 k | — d | 1 | crew 5 · speed 140 km/h |
| Pipe Haul Truck | `veh_pipe_truck` | 5,664 | 3.3 × 11.645 × 7.518 | $290 k | — d | 1 | crew 2 · speed 90 km/h |
| Vacuum / Water Truck | `veh_vacuum_truck` | 5,776 | 3.3 × 11.495 × 4.147 | $320 k | — d | 1 | storage 180 bbl · crew 2 · speed 85 km/h |
| Wheel Loader | `veh_wheel_loader` | 2,944 | 2.934 × 7.8 × 3.406 | $350 k | — d | 1 | crew 1 |
| Cementing Unit | `veh_cementing_truck` | 5,999 | 6 × 9.945 × 3.302 | $1.1 M | — d | 2 | crew 4 · speed 85 km/h |
| Mobile Crane Truck | `veh_crane_truck` | 6,056 | 5.5 × 12.65 × 3.796 | $980 k | — d | 2 | crew 3 · lift 45 t · speed 80 km/h |
| Fire / Safety Truck | `veh_fire_truck` | 5,628 | 3.3 × 9.975 × 3.686 | $520 k | — d | 2 | crew 5 · speed 110 km/h |
| Frac Pump Trailer | `veh_frac_pump_trailer` | 4,540 | 3.211 × 7.95 × 2.857 | $1.4 M | — d | 2 | crew 2 · power 2,500 kW |
| Wireline Unit | `veh_wireline_truck` | 5,688 | 3.34 × 11.045 × 6.637 | $860 k | — d | 2 | crew 4 · speed 90 km/h |

## Environment, Site & Gameplay Props

_Build-plot markers, roads, fences and site furniture — the pieces that make the map readable during placement._

| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |
|---|---|---:|---|---:|---:|---:|---|
| Barrel Cluster | `prp_barrels` | 780 | 2.197 × 2.183 × 0.88 | $900 | — d | 1 | storage 6 bbl |
| Build Plot (24 m) | `prp_build_plot` | 546 | 24 × 24 × 2.58 | $45 k | — d | 1 |  |
| Tricone Drill Bit | `prp_drill_bit` | 368 | 1.353 × 1.452 × 2.295 | $12 k | — d | 1 |  |
| Fence Module (4 m) | `prp_fence_module` | 124 | 4.45 × 0.45 × 2.272 | $1 k | — d | 1 |  |
| Floodlight Tower | `prp_floodlight` | 316 | 2.6 × 1.6 × 14.25 | $18 k | — d | 1 | power 4 kW |
| Gas Cylinder Rack | `prp_gas_cylinders` | 786 | 2.6 × 1.4 × 2.05 | $3 k | — d | 1 |  |
| Stacked Site Offices | `prp_office_stack` | 1,324 | 6.238 × 12.24 × 5.28 | $96 k | — d | 1 | crew 24 |
| Pipe Supply Stack | `prp_pipe_supply` | 432 | 9 × 4 × 7.518 | $28 k | — d | 1 |  |
| Build Plot Marker | `prp_plot_marker` | 332 | 16 × 16 × 1.22 | $0 | — d | 1 |  |
| Site Office Cabin | `prp_portacabin` | 428 | 6.2 × 2.6 × 3.5 | $26 k | — d | 1 | crew 8 |
| Road Corner | `prp_road_corner` | 120 | 14.45 × 17.95 × 0.24 | $11 k | — d | 1 |  |
| Road Tile (12 m) | `prp_road_straight` | 108 | 12 × 9.1 × 0.24 | $9 k | — d | 1 | speed 80 km/h |
| Site Security Gate | `prp_security_gate` | 464 | 12 × 9 × 3.25 | $65 k | — d | 1 |  |
| Site Sign | `prp_sign` | 200 | 3.2 × 0.8 × 3.25 | $2 k | — d | 1 |  |
| Team Ownership Flag | `prp_team_flag` | 472 | 4.05 × 2.9 × 7.31 | $5 k | — d | 1 |  |
| Water Storage Tank | `prp_water_tank` | 796 | 4.4 × 3.6 × 3.855 | $15 k | — d | 1 | storage 200 bbl |
| Well Marker | `prp_well_marker` | 64 | 1.45 × 0.9 × 2.4 | $400 | — d | 1 |  |
| Field Workshop | `prp_workshop` | 572 | 18 × 12 × 7.7 | $1.8 M | 90 d | 2 | crew 30 |

## Naming and engine notes


* **LODs** — `*_LOD1` (~45% tris) and `*_LOD2` (~18%) exist for any mesh above
  1,500 triangles. They live in the `.blend` only, so engines can generate their
  own or you can export them on demand.
* **Collision** — `*_COL` box hulls, wireframe, render-disabled. Use them as
  simple colliders or replace with engine-generated convex hulls.
* **Material slots** — every asset shares the same small material library, so
  batching is easy. `paint_*` materials are marked `team_tint` in Blender custom
  properties; swap their base colour per player at runtime.
* **Custom properties** — every object carries `asset_id`, `category`,
  `tri_count`, `size_x/y/z` and (for offshore) `placement`. glTF export keeps
  them as `extras`.
* **Snap tags** — `gameplay.snap` (`pipe`, `road`, `rack`, `plot`, `fence`) marks
  assets designed to tile on a grid.
