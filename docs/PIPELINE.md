# Pipeline & Integration Guide

How the kit is generated, how to extend it, and how to get it into an engine
without surprises.

---

## 1. Architecture

```
blender/
├── build.py            orchestrator + CLI (scene, build, export, manifest, demo)
├── gen_docs.py         regenerates docs/ASSET_LIBRARY.md from the manifest
├── demo_scene.py       assembles the demo field + writes demo_layout.json
├── render_previews.py  EEVEE studio thumbnails
└── kit/
    ├── core.py         Asset builder (bmesh), LODs, collision, exporters
    ├── mats.py         flat-PBR material library (23 materials)
    ├── parts.py        reusable industrial vocabulary (40+ part functions)
    ├── onshore.py      upstream onshore
    ├── offshore.py     offshore structures + marine vessels
    ├── midstream.py    pipelines, gas processing, LNG, terminals
    ├── refinery.py     downstream process units
    ├── vehicles.py     trucks, heavy equipment, aircraft
    └── props.py        environment + gameplay props

preview/
├── index.html          three.js asset browser + field view (no build step)
├── serve.ps1           local static server
└── vendor/             three.js r160 (module + GLTFLoader/OrbitControls)
```

Each category module ends with a `REGISTRY` list. That list is the **only**
declaration of what exists — the mesh, the collection, the `.glb`, the `.fbx`,
the manifest entry and the docs table are all derived from it.

### The Asset builder

`core.Asset` accumulates geometry in one `bmesh`, assigning material indices per
face as it goes, then bakes a single mesh object:

```python
a = core.Asset("on_pumpjack", "onshore", collection)
a.box((4, 2, 0.5), (0, 0, 0.25), "concrete")
a.cyl(0.8, 6.0, (0, 0, 3.0), "paint_orange", seg=16)
a.beam((0, 0, 0), (2, 0, 3), 0.2, "galv")
a.sweep([(0, 0, 0), (1, 0, 1), (2, 0, 1)], 0.1, "pipe_white")
obj = a.finish()
```

No `bpy.ops` is used for modelling. That means:

- deterministic output (no dependency on selection or context),
- fast (82 assets in ~45 s including export),
- safe in `--background` (no UI context required).

**Primitives available:** `box`, `cyl`, `sphere`, `beam`, `sweep` (tube along a
polyline), `loft` (skinned sections — hulls), `dome` (vessel heads), `ring`.

---

## 2. Adding an asset

```python
# blender/kit/onshore.py

def my_compressor(a):
    P.skid(a, 6.0, 3.0, 0.3, loc=(0, 0, 0))
    a.box((2.0, 1.8, 1.6), (0, 0, 1.3), "paint_blue", bevel=0.05)
    P.pipe_run(a, [(-2, 0, 1.8), (2, 0, 1.8)], 0.18, "pipe_yellow", supports=True)

REGISTRY = [
    # ...
    dict(
        aid="on_my_compressor",
        name="My Compressor",
        build=my_compressor,
        gameplay=dict(role="processing", tier=2, cost_usd=1_200_000,
                      build_days=9, capacity_mmscfd=6),
    ),
]
```

Then:

```powershell
blender --background --python blender/build.py -- --asset on_my_compressor --render
```

The asset appears in the collection, both exports, the manifest and (after
`gen_docs.py`) the catalogue. The `aid` prefix is enforced automatically from the
category (`ON_`, `OFF_`, `MID_`, `REF_`, `VEH_`, `PRP_`).

### Reusable parts worth knowing

| Part | What it gives you |
|---|---|
| `pad`, `foundation`, `skid` | civil base, steel frame with lifting lugs |
| `derrick`, `mast` | 4-leg lattice tower / A-frame with crown block |
| `tank`, `vessel`, `column` | storage tank (cone/floating/dome roofs), horizontal drum, process column with platforms |
| `handrail`, `caged_ladder`, `stairs`, `spiral_stair` | access and safety detail |
| `pipe_run`, `flange`, `gate_valve`, `gauge` | pipework with supports and fittings |
| `pedestal_crane`, `helideck`, `lifeboat` | offshore deck furniture |
| `chassis`, `truck_cab`, `flatbed`, `wheel` | vehicle kit |
| `fence`, `floodlight`, `barrel`, `container`, `generator_set` | site furniture |

---

## 3. Build CLI

```powershell
blender --background --python blender/build.py -- [flags]

  --only onshore,refinery   # subset of categories
  --asset on_land_rig       # subset of asset ids (comma separated)
  --render                  # render previews + demo hero image
  --no-export               # skip glb/fbx
  --no-lods                 # skip LOD generation
  --no-demo                 # skip demo field
  --preview-size 640        # thumbnail resolution
```

Outputs:

```
assets/
├── blend/
│   ├── oilfield_kit.blend          # one collection per category, LODs, collisions
│   └── oilfield_demo_field.blend   # assembled demo field
├── glb/
│   ├── oilfield_kit.glb            # everything, one node per asset
│   └── <category>/<asset>.glb
├── fbx/<category>/<asset>.fbx
├── json/manifest.json
└── previews/*.png
```

---

## 4. Export settings and coordinates

| | Blender | glTF (`.glb`) | Unreal (`.fbx`) |
|---|---|---|---|
| Up | +Z | +Y | +Z |
| Forward | −Y | +Z | +X |
| Scale | 1 unit = 1 m | 1 unit = 1 m | 1 unit = 1 cm (applied) |
| Origin | base centre / waterline | same | same |

The glTF exporter is called with `export_yup=True`, `export_apply=True`,
`export_extras=True`, no animation and no cameras/lights. Custom properties
(`asset_id`, `category`, gameplay tags) survive as glTF **extras**.

FBX uses `apply_scale_options="FBX_SCALE_ALL"`, `axis_forward="-Y"`,
`axis_up="Z"`, `use_custom_props=True`.

### Engine notes

**Unity** — drop `.glb` (Unity 2022+ imports glTF via `UnityGLTF`, or convert to
`.fbx`). Scale factor 1, Y-up. Materials come in as URP/HDRP-compatible PBR.
Pivot is at the base, so `Instantiate(prefab, hit.point, rotation)` just works.

**Unreal** — import `.fbx` with "Convert Scene" on. The exporter already bakes
scale, so no 0.01 multiplier is needed. Set "Import Uniform Scale" to 1.

**Godot 4** — `.glb` imports directly, `MeshInstance3D` per asset, materials as
`StandardMaterial3D`. Origins behave the same.

**three.js / web** — `GLTFLoader` + `DRACOLoader` if you enable compression.
Total kit is ~43 MB uncompressed; enable Draco or gltfpack (`export_use_gltfpack`)
to cut it by ~70%.

---

## 5. Performance budget

| Tier | Triangles | Notes |
|---|---|---|
| Hero assets (rigs, platforms, FPSO) | 18k–28k | LOD1 ≈ 45%, LOD2 ≈ 18% |
| Process units | 3k–8k | LOD1/LOD2 generated |
| Vehicles | 600–3.5k | no LODs (below threshold) |
| Props | 200–2k | no LODs |

Total kit: **~450k triangles**, which is roughly one mid-size environment for an
RTS camera. In practice a match uses 30–60 instances, not all 82 unique meshes.

Draw calls: one mesh per asset, with 2–8 material slots on simple props and up to
~18 on the hero assets (a jack-up uses 18). If you need to go further, merge by
material at import or use GPU instancing for repeated props (pumpjacks, road
tiles, pipeline segments, fences).

### Animation hooks

Assets are static meshes. The ones players expect to move:

| Asset | Suggested approach |
|---|---|
| `on_pumpjack` | split `walking beam` geometry into its own mesh, rotate about the samson post pin |
| rigs | travelling block: animate along the derrick centre line |
| cranes | boom slew + hoist: separate `boom` and `hook` meshes |
| flares | particle emitter at the tip (position is `z = height`) |
| vehicles | split wheels (4 or 6) and rotate about their local X |
| helicopter | rotor disc: rotate the 4-blade assembly about Z |
| FPSO / spar | mooring is static; animate the whole asset with a slow sine heave |

Nothing in the geometry prevents this — it's a matter of separating the parts you
want to move. The generator can be extended with a `a.group()` helper to tag
sub-assemblies if you need it.

---

## 6. Materials and team colours

All materials are flat Principled BSDF — no textures — so per-player recolouring
is a one-line material change:

```csharp
// Unity
var mats = renderer.sharedMaterials;
for (int i = 0; i < mats.Length; i++)
    if (mats[i].name.StartsWith("paint_"))
        mats[i].SetColor("_BaseColor", teamColor);
```

Retintable slots: `paint_yellow`, `paint_orange`, `paint_blue`, `paint_red`,
`paint_green`, `paint_teal`. They are marked with the `team_tint` custom property
in the `.blend`.

Because there are no textures, the whole kit is **< 43 MB** and every asset shares
the same 23-material library — which also means good batching and cheap memory.

If you later want grime, generate a single trim-sheet atlas and multiply it in the
shader; the meshes have UVs from Blender's primitives already.

---

## 7. Regenerating safely

1. Change a number or geometry in `kit/`.
2. `blender --background --python blender/build.py -- --only <category>`
3. Check the printed triangle counts and any `[FAIL]` lines.
4. `blender --background --python blender/gen_docs.py` to refresh the catalogue.

The build is idempotent: it starts from `read_factory_settings(use_empty=True)`,
so no stale objects survive.

Failures are per-asset: one broken builder won't abort the run, and the traceback
is printed. That's intentional — with 80+ procedural assets you want the other 81
to ship.

---

## 8. Extending into a full game

The manifest is the contract between art and code. A typed mirror in your engine
is enough to build the build-menu, economy and validation:

```ts
type Gameplay = {
  role: "drilling" | "production" | "processing" | "storage" |
        "transport" | "support" | "refining" | "marine" | "air" |
        "vehicle" | "infrastructure" | "gameplay" | "prop";
  tier: 1 | 2 | 3 | 4;
  cost_usd: number;
  build_days: number;
  upkeep_usd_day?: number;
  capacity_bopd?: number;
  [k: string]: unknown;
};

type AssetEntry = {
  id: string;
  name: string;
  category: string;
  gameplay: Gameplay;
  geometry: { triangles: number; size_m: [number, number, number]; materials: string[] };
  files: { glb: string; fbx: string; preview: string | null };
};
```

Load `manifest.json`, map `id -> prefab`, and the placement system can validate
footprints (`size_m`), tiers, and snap rules without any hard-coded tables.

---

## 9. Web preview

`preview/index.html` is a zero-build three.js viewer. It exists to prove the kit is
actually usable, not just renderable:

| Mode | Source | What it demonstrates |
|---|---|---|
| **Assets** | `assets/json/manifest.json` + `assets/glb/<cat>/<id>.glb` | per-asset inspection, gameplay stats, wireframe, team tint |
| **Field** | `assets/json/demo_layout.json` | 145 instances composed at basin scale |

### Coordinate handoff

`manifest.json` is authored in Blender space. The preview (and your engine) must
apply the same conversion the glTF exporter does:

```js
// Blender (x, y, z)  ->  glTF (x, z, -y)
mesh.position.set(o.x, o.z, -o.y);
mesh.rotation.y = THREE.MathUtils.degToRad(o.rot);   // Blender Z == glTF Y
```

Because every asset already has its origin at the base/waterline, `position.y = 0`
puts it on the ground or the sea surface with no offset table.

### Rebuilding the field view

`blender/demo_scene.py` writes `assets/json/demo_layout.json` on every full build
(placements, road tiles, terrain extents, camera). Move an object in the Blender
scene, rebuild, and the web view follows — no duplicated coordinates in the HTML.

```powershell
powershell -ExecutionPolicy Bypass -File preview\serve.ps1   # port 8000
```

`file://` will not work: ES modules and `fetch()` are blocked by CORS. Any static
server pointed at the repo root is fine (`python -m http.server`, `npx serve`, IIS).

---

## 10. In-game pipeline & street rules (Godot prototype)

The Godot prototype in `game/` is where the reference game's transport rules are
actually enforced. Terrain is a first-class input, not decoration.

See also:

- `docs/ROAD_PIPE_SYSTEM.md` — industry research on 3D road/pipeline systems and
  how the prototype maps onto it (nodes/segments, segment-length contract,
  graded corridors, fluid segments, pumps).
- `docs/BUILDING_CONNECTIONS.md` — every building's pipeline port sides, flow
  role, and the rule that an exploration office has no pipeline port.


### Terrain

- `OilTerrainGen` builds a deterministic heightfield: `FastNoiseLite.get_image()`
  → basin mask → terraced hills → material bands → `OilTerrain` resource.
- Terrain3D (`game/addons/terrain_3d`) renders the same heights: 4×4 regions of
  64 vertices at 4 m spacing (256 m per region), imported through
  `Terrain3DData.import_images([height, control, color], pos, 0.0, 64.0)`.
- The control map is a packed `R32F` image — base id in bits 27–31, overlay id in
  22–26, blend in 14–21 — so grass (id 0) blends into rock (id 1) on slopes.
- A `HeightMapShape3D` collider mirrors the same `heights` array, so picking and
  placement agree with what is drawn.

### Placement is height-aware

| Rule | Implementation |
|---|---|
| Structures are anchored to the **highest corner** of their cell | `_cell_max_height()` samples all four corners; neighbours share corners, so modules meet exactly |
| A site must be flat enough to level | `MAX_BUILD_RELIEF = 3.2 m`; steeper sites are refused with a toast |
| Building a pad **levels the footprint** and charges the earthworks | `_level_cells()` cuts/fills the heightmap, then `_sync_terrain()` updates the collider and re-imports the affected Terrain3D regions; cost = `moved m³ × $9` |
| Pipe/road runs may not climb a cliff | `MAX_GRADE = 2.4 m` per 16 m cell between adjacent tiles; the cell is skipped and the reason is shown |
| Tiles follow the authored 16 m grid | pipes keep their authored size so the end flanges overlap and joints show no seam; roads are nudged 3% wider to close the seam. Forcing every module to exactly 16 m was a bug — it shrank the pipe and opened ≈0.7 m gaps. |

### Port joints are geometry, not a fixed stub

Structures and pipes share the 16 m grid, but a structure's visible face is not
necessarily the cell edge. The joint is therefore derived from the model:

| Rule | Implementation |
|---|---|
| A 2×2 structure fills **two** cells | `_try_build()` fits the model to `footprint × CELL × BUILDING_FIT`, so a refinery's face is on the block edge, not the block centre |
| A pipe tile grows an arm toward a port | `_pipe_mask()` = pipe neighbours **plus** adjacent building ports (building→pipe side, the same convention as `NetworkSolver`) |
| The joint ends on the structure's real silhouette | `_structure_half()` measures the spawned mesh bounds; `_connector_span()` returns where the spool leaves the pipe tile and where it meets the wall |
| The joint is never buried | `_lay_line()` lifts the graded corridor to the highest pad it plugs into; a short riser at the wall absorbs any remaining height difference |
| Preview tells the truth | joint cells are green in the drag overlay and the inspector reports `N port joints` (and warns when the route has none) |

All of it is generic: a new catalogue entry with ports gets the same treatment.

### Transport rules

1. A pipe component is a 4-neighbour flood fill over pipe cells.
2. A building joins every pipe component it touches; a **storage tank unions**
   two components, which is why it can bridge a well run and a refinery run.
3. A component with **no storage** produces and sells nothing — a pumpjack can
   never feed a refinery directly through one pipe.
4. Wells and refineries only operate with an **adjacent road** (`_has_road`).
5. Pipes cost `$400` per cell and `$0.02/s` upkeep; roads cost `$200` per cell and
   `$0.01/s`.
6. **A run's throughput is finite**: `2.0 bbl/s + 0.5 bbl/s per pipe cell`. Wells
   beyond that ceiling are throttled, so a long field needs more pipe, a second
   run, or a tank bridge. The HUD shows `FLOW used/cap` and flags
   `PIPELINE AT CAPACITY`.
8. **Fleet units are stationed on a street network.** Select a road cell (or a
   NETWORKS row) before buying; the unit adds its logistics only to that
   network, and vehicles drive that network. `F6` transfers one unit from the
   busiest other street to the selected one; removing a road re-stations its
   units on the same network, or refunds half their cost if the network is gone.
9. **Truck Depots are buildings, not fleet.** Place one beside a street network
   for a static `+3` logistics there (`$45k`, `$1.2/s` upkeep); the NETWORKS row
   and the road inspector show the boost.
9. **Pump stations** (`[7]`, `$45k`, `$3/s` upkeep) sit next to a pipe and add
   `+8 bbl/s` to that run. They are the answer to a run at capacity without
   re-routing the whole field.

### Placement flow

Pipes and roads are **planned before they are paid for**:

1. Pick the tool from the **filterable build menu** (or press its hotkey).
2. Press and hold with the pipe/road tool: a translucent route overlay appears.
2. The inspector shows the route length and its price (e.g. `10 cells · $2,000`).
   For pipes it also counts `port joints` and warns when the route touches no
   declared port.
3. Both L orientations are evaluated and the one with more valid cells wins, so
   a corner obstacle is routed around without A* and without manual re-dragging.
4. Pipe route cells that land on a port are **green**; a cell beside a structure
   with no port on that side is **orange**, so a dead-end is visible before the
   player pays.
5. Release to build, `Esc` to cancel. Only cells actually filled are charged.
6. Route cells that are occupied or already other infrastructure are skipped.
7. **Snapping.** If a pipe drag starts or ends on a structure, that end snaps to
   the structure's port on the approach side (`_snap_pipe_route`), so dropping
   the cursor on a tank connects instead of hitting the occupied cell.
8. **Street preview.** Road cells that touch a site or an already-served network
   preview green, and the inspector reports `serves N sites · network connected`
   or `isolated — link 2+ sites or a served road`.


### Network manager

The right-hand **NETWORKS** panel lists every pipe run and street network:

- `RUN n · cells · flow/capacity · +$income/s` with `dry` (no storage) or `MAX`.
- `STREET n · cells · LOGI load/capacity · $upkeep/s · Fn` with `isolated`
  (< 2 sites) or `busy` (over capacity).
- Selecting a cell repeats the detail in the inspector, including run income and
  the street's site list and fleet count.
- Problems sort first and rows are colour-coded; **clicking a row selects and
  focuses** that run in the world, so management is one click from the overview.
  `F6` transfers a fleet unit here; `F7` demolishes the whole selected network.
- **Warning markers** float above structures that need attention (`ROAD`, `PIPE`,
  `TANK`, `IDLE`), so problems are visible without opening the inspector.

### Verification

```powershell
Godot_v4.7.1-stable_mono_win64.exe --path game -- --selftest
```

Runs the rule suite and exits non-zero on failure:

```
=== PIPELINE / STREET RULE TESTS ===
  PASS  pumpjack builds on a revealed deposit
  PASS  site is levelled flat under the pad  (relief 0.000 m)
  PASS  fleet purchase requires a served street
  PASS  refinery builds beside the well
  PASS  well -> pipe -> refinery makes NO income without storage  (income 0.000)
  PASS  well -> tank -> refinery flows  (income 117.8/s)
  PASS  bulldozing a road cuts access immediately
  PASS  pumpjack without road access stops producing  (income 0.000)
  PASS  road access restores production  (income 119.7/s)
  PASS  exploration office reveals a nearby deposit
  PASS  survey office waits for road access
  PASS  survey office reports road need, not a pipe  (no road access)
  PASS  survey starts when a road reaches the office
  PASS  survey office is ok once it has a road  (ok)
  PASS  pipeline costs by length  (5 cells cost $2000)
  PASS  road costs by length  (5 cells cost $1000)
  PASS  route preview matches the built run  (preview 15, built 15)
  PASS  pipeline capacity scales with run length  (2 cells -> 3.0 bbl/s)
  PASS  exploration office exposes no pipeline port
  PASS  pumpjack ignores a pipe on its motor side
  PASS  motor side has no pipe arm  (mask none)
  PASS  pipe on a port side grows a joint arm  (mask E)
  PASS  route preview flags port joints  (port side E · motor side none)
  PASS  route cost is priced per cell  ($1200)
  PASS  pump station raises run capacity  (3.0 -> 11.0 bbl/s)
  PASS  route cells are edge-connected (no diagonal gaps)  (11 cells)
  PASS  catalogue declares role, ports and capacity for every structure  (29 structures)
  PASS  tank farm takes its volume from the catalogue  (2400 bbl)
  PASS  2x2 structure fills its footprint  (model 31.4 m across (cell 16 m))
  PASS  2x2 pipe joints use the block's real face  (joint 7.50 -> 11.57 m from the pipe centre)
  PASS  pipe run is lifted to the structure pad  (pipe y 0.26 · pad y 0.19)
  PASS  pipe grows an arm toward a building port  (mask W)
  PASS  pipe joint reaches the structure surface  (joint 7.50 -> 8.61 m from the pipe centre)
  PASS  1x1 structure keeps a service apron  (half-width 7.84 m)
  PASS  pipe drag snaps to a structure port  (snapped to (14, 20))
  PASS  pipe snap avoids the pumpjack motor side  (snapped to (20, 19))
  PASS  separator raises refined income  (120.5 -> 133.3/s)
  PASS  metering skid raises sale income  (134.0 -> 142.5/s)
  PASS  compressor is a catalogue booster (+5 bbl/s)
  PASS  a new structure plugs in with data only  (12.0 -> 15.0 bbl/s)
  PASS  road network has logistics capacity and load  (load 3.5 / cap 4.5)
  PASS  road congestion throttles throughput  (factor 1.00 -> 0.50)
  PASS  road preview counts the sites it serves  (1 site(s), isolated)
  PASS  road preview recognises a served network  (joins a served run)
  PASS  road inspector lists the sites it serves  (Sites: Pumpjack, Storage Tank, Refinery)
  PASS  network manager shows per-run income  ($137.2/s)
  PASS  network manager lists pipe runs and streets  (3 rows)
  PASS  rotating a pumpjack moves its flowline port  (sides E W S)
  SKIP  no cliff on this lease to test the grade limit
  PASS  fleet unit raises the street it is assigned to  (street 0 cap 4.5 -> 6.5 (+2 logi))
  PASS  fleet logistics do not leak to other streets  (other street bonus 0.0)
  PASS  fleet unit is paid for  (spent $8000)
  PASS  fleet unit appears on the road  (1 vehicles)
  PASS  network manager marks the selected street
  PASS  second street serves its sites
  PASS  fleet can be transferred to the selected street  (1 -> 2 units)
  PASS  demolish clears the selected street network  (28 -> 27 roads)
  PASS  truck depot boosts its street  (8.5 -> 11.5)
  PASS  depot inspector explains its street boost  (Network boost: +3 logistics)
  PASS  pipe replaces a road in place
  PASS  sales contract tracks deliveries  (1.02 bbl delivered)
  PASS  pipe laid before a structure grows its joint arm  (mask E)
  PASS  bulldozing a structure removes the joint arm  (mask none)
  PASS  demolish clears the selected pipe run  (12 -> 11 pipes)
  PASS  save writes a file
  PASS  load restores the field  (13 buildings, 11 pipes, $1351872)
  PASS  load restores the fleet  (2 pickups, 2 vehicles)
  PASS  load restores fleet assignment  (2 unit(s) stationed)
  PASS  load clears stale run income
  PASS  bankruptcy pauses the field
=== 69/69 checks passed ===
```

Screenshot modes: `-- --demo --shot` (field), `-- --demo --joint --shot` (pipe
entering a pumpjack port), `-- --demo --pipe-route --shot` (route preview with
port-joint cells), `-- --demo --pipe-ports --shot` (every structure's ports while
piping), `-- --demo --route --shot` (in-progress road drag with route cost),
`-- --demo --ports --shot` (placement port hint), `-- --demo --warn --shot`
(warning markers), `-- --demo --help --shot` (field manual),
`-- --demo --gameover --shot` (foreclosure),
`-- --demo --depot --shot` (Truck Depot inspector),
`-- --demo --top --shot`, `-- --demo --bend --shot`,
`-- --demo --net --shot` (utilisation overlay), and `-- --demo --overview --shot`
(terrain rim). Output lands in `game/shot.png`.


