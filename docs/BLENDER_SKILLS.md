# Blender skills for asset production

The project uses the **blender-skills** pack (94 specialist Blender skills,
MIT licence) to keep asset work production-grade and Godot-ready.

- Upstream: <https://github.com/arjun988/blender-skills>
- Local clone: `blender/blender-skills/`
- Installed skills: `.claude/skills/` (also mirrored to `.cursor/skills/`)

## Skills in use

| Skill | Why |
| --- | --- |
| `godot-export` | GLB output, meters, +Y-up on import, clean hierarchy, collision naming |
| `hard-surface` | Primary volumes, panel breaks, selective bevels, weighted normals |
| `vehicle-artist` | Vehicle proportions, functional parts as separate objects |
| `asset-optimization` | Polycount/UV/material sanity before export |
| `prop-artist`, `materials`, `uv-workflow` | Supporting passes for props and surfaces |

## Conventions used by this project

- Units: **meters**; Blender `+Z` up, truck front `-Y` (becomes `+Z` in Godot).
- Origin at **base centre, z = 0 on the ground**.
- Materials: Principled BSDF (metallic/roughness) so glTF PBR round-trips.
- Moving parts are separate nodes, e.g. the crane arm pivots on the `Boom`
  empty; the game finds it by name (`find_child("Boom", ...)`).
- Export: single **GLB**, modifiers applied, animations only when needed.

## Global hard-surface pass

`blender/kit/core.py` now defaults every box to the **primary-edge bevel tier**
(0.012 m, 2 segments, clamped) so all hard edges catch light, not just the
hand-detailed assets. Builders can still pass `bevel=0.0` for razor-sharp decals.

A full rebuild currently produces **95 kit assets / 847,269 tris** with no build
failures; every GLB is mirrored into `game/assets/models/`. The custom Mobile
Crane (`veh_constructor.glb`) is generated separately and is not overwritten.

Rebuild the entire kit and mirror it into the game:

```powershell
blender -b -P blender/build.py -- --no-demo
Get-ChildItem assets\glb -Recurse -Filter *.glb |
  ForEach-Object { Copy-Item $_.FullName "game\assets\models\$($_.Name)" -Force }
```

## Assets with an explicit detail pass

| Asset | Game model | Pass applied |
| --- | --- | --- |
| Mobile Crane | `veh_constructor.glb` | selective bevels + weighted normals, cab/deck panel breaks, lattice boom, hydraulic ram, outriggers, hubs, lights, chevrons |
| Pumpjack | `on_pumpjack.glb` | gearbox panel seams + foundation bolts, prime-mover louvres, crank guard rail, control panel + conduit, access steps, warning plate |
| Storage Tank | `gam_storage.glb` | shell anchor bolts, roof handrail + posts, side level gauge with flanges, inlet flange ring |
| Field Base / Control Room | `ref_control_room.glb` | roof safety rail, rooftop condensers + vent, entrance canopy/steps/bollards, glazing mullions, illuminated sign, cable tray, corner floodlights, pad expansion joints |
| Exploration Office | `gam_explorer.glb` | roof rail, rooftop AC + vent, canopy/steps/bollards, mullions, generator skid + exhaust, antenna conduit, floodlights, pad joints |
| Refinery | `gam_refinery.glb` | control-hut roof rail + AC, furnace caged ladder, cooler handrails, rack valve wheels + flow meter |
| Tank Farm | `on_tank_farm.glb` | per-tank roof rail ring, anchor bolts, side level gauge |
| Crew Pickup | `veh_pickup.glb` | roof rack, side steps, bed ribs, tow hitch |
| Fuel Tanker | `veh_fuel_tanker.glb` | rear ladder rails, side marker lamps, hose tray, underride guard, barrel band bolts |
| Seismic / Wireline | `veh_wireline_truck.glb` | body handrails, access door, winch-drum guard, rear stabiliser jacks, mast work lights |
| Bulldozer | `veh_bulldozer.glb` | blade stiffener ribs, track guards, work lights, hydraulic hoses, safety decal |

## Regenerating

Mobile Crane (standalone script):

```powershell
blender -b -P blender/make_constructor.py
```

Kit assets (Pumpjack, Storage Tank, …):

```powershell
blender -b -P blender/build.py -- --only onshore,game,refinery,vehicles `
  --asset on_pumpjack,gam_storage,ref_control_room,gam_explorer,on_tank_farm,gam_refinery,veh_pickup,veh_fuel_tanker,veh_wireline_truck,veh_bulldozer `
  --no-demo

# copy each GLB into the game model folder (same base name)
copy assets\glb\onshore\on_pumpjack.glb       game\assets\models\on_pumpjack.glb
copy assets\glb\game\gam_storage.glb          game\assets\models\gam_storage.glb
copy assets\glb\refinery\ref_control_room.glb game\assets\models\ref_control_room.glb
copy assets\glb\game\gam_explorer.glb         game\assets\models\gam_explorer.glb
copy assets\glb\onshore\on_tank_farm.glb      game\assets\models\on_tank_farm.glb
copy assets\glb\game\gam_refinery.glb         game\assets\models\gam_refinery.glb
copy assets\glb\vehicles\veh_pickup.glb       game\assets\models\veh_pickup.glb
copy assets\glb\vehicles\veh_fuel_tanker.glb  game\assets\models\veh_fuel_tanker.glb
copy assets\glb\vehicles\veh_wireline_truck.glb game\assets\models\veh_wireline_truck.glb
copy assets\glb\vehicles\veh_bulldozer.glb    game\assets\models\veh_bulldozer.glb
```

Then reimport in Godot (`--headless --path game --import`) and run `--selftest`.

## Adding a new asset

1. Block the primary silhouette at real-world scale.
2. Add panel breaks at structural seams (not random).
3. Bevel by detail tier (primary 0.02 m / panel 0.005 m).
4. Keep moving parts separate and named.
5. Export GLB with modifiers applied; verify scale and materials in Godot.
6. Run the suite (`--selftest`) and a screenshot pass before shipping.
