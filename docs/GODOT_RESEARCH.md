# Godot Research — Building a Tycoon/Management Game

Notes from researching how this genre is built in Godot 4, and how each finding
maps onto the prototype in `game/`.

---

## 1. Placement systems

**Finding.** The standard Godot 4 approach is *camera ray → ground plane → grid
snap*, with a ghost/placeholder prefab and a validation pass before commit.
Two data structures dominate:

| Approach | Use when | Trade-off |
|---|---|---|
| **GridMap + MeshLibrary** | fixed-size tiles, many of them (roads, pipes, walls) | batched per mesh type (fast), but rotation is an *orientation index* (0–23), and per-tile materials/variants are awkward |
| **Custom grid dictionaries + instanced scenes** | varied buildings with gameplay state | full control, but every tile is a node; needs batching if counts get large |

The BA "City Builder" prototype validates placement as: *cell is grass* **and**
*at least one adjacent road*, then auto-rotates the building toward that road.
Kenney's official **Starter Kit City Builder** (Godot 4.6, CC0) implements the
same loop plus save/load and a dynamic MeshLibrary.

**In our prototype.** We use the custom-dictionary approach (`occupied`, `pipes`,
`roads`, `deposits`), a camera-ray `_mouse_cell()`, a translucent quad ghost
tinted green/red by `_can_place()`, and drag-laying with Bresenham
(`_lay_line`). Buildings do **not** auto-rotate to roads yet — roads are cosmetic.

**Worth adopting next**
1. Auto-rotate a building toward an adjacent road (cheap, big readability win).
2. Save/load: serialise `{kind, cell}` lists + `cash/debt`; rebuild on load.
3. Move pipes/roads to a GridMap once the network exceeds a few thousand cells.

---

## 2. Performance

**Finding.** Godot's docs and community benchmarks agree:

- **GridMap** renders per-mesh-type batches through MultiMesh internally, and
  splits the map into octants (`cell_octant_size`, default 8). A community test
  of 10,000 1×1×1 boxes measured **~866 fps with GridMap vs ~204 fps with
  individual MeshInstance3D**.
- **MultiMeshInstance3D** is the tool for *non-grid* decoration (grass, rocks,
  trees) — one draw call for thousands of copies, at the cost of no per-instance
  frustum culling.
- GridMap's octant size is the tuning knob: bigger octants = fewer draw batches
  but more expensive edits.

**In our prototype.** Buildings and pipes are individual nodes (fine at
~100–500), and scenery is 140 nodes from Kenney's Nature Kit. That is well under
the point where batching matters, but the research says the next step is clear:
switch scenery to `MultiMeshInstance3D` per prop type before scaling the map.

**Worth adopting next**
- MultiMesh for scenery and for grass tufts.
- A `performance` overlay (draw calls, nodes) to catch regressions.

---

## 3. Toon / cel shading

**Finding.** Three tiers, in increasing quality:

1. **Built-in:** `StandardMaterial3D` → *Diffuse Mode = Toon*, *Specular Mode =
   Toon*, low roughness. Zero code, one soft step.
2. **Custom `light()` shader:** band `N·L × ATTENUATION × light strength` through
   `smoothstep` edges; optional rim (`1 − N·V`) and a hard Blinn-Phong highlight.
   This is what gives 2–6 bands, per-light banding and crisp shadow edges.
   A reference implementation ships free (CC0) for Godot 4.7 and works on
   Forward+, Mobile **and** Compatibility.
3. **Ink outline:** inverted hull — a second material in *Next Pass* with
   `render_mode cull_front`, vertices pushed along the normal in the vertex
   shader. Runtime cost scales with the mesh, so use it on hero props only.

Caveat from the CC0 shader docs: under **Compatibility**, shadow-casting lights
render bands much brighter; the demo disables sun shadows there.

**In our prototype.** We take tier 1: `_apply_toon()` duplicates each imported
`StandardMaterial3D` and sets `diffuse_mode = DIFFUSE_TOON`,
`specular_mode = SPECULAR_TOON`. The Blender side already bakes the palette and
matte roughness, so the two ends agree.

**Worth adopting next**
- Tier 2 `light()` shader for 3 bands + rim (matches the Blender previews).
- Tier 3 outline pass on buildings only, not on the 82-asset field.

---

## 4. Textures and materials

**Finding.** Imported glTF meshes from procedural generators often have **no
UVs**; Godot exposes `uv1_triplanar` on `StandardMaterial3D`, which samples by
world position and needs no UV layout. For a large ground plane, mipmaps +
anisotropic filtering are mandatory or the texture shimmers.

The other lesson from the research and from this project's iteration: **a ground
texture must depict a pattern, not individual plants.** Any texture with readable
leaves/flowers forces a scale choice where it is either a shrub the size of a
house or noise.

**In our prototype.** The road asphalt uses triplanar mapping
(`uv1_triplanar`, no UVs on the pipe/road meshes), and the ground uses a macro
"terrain" pattern tiled at ~24 m with mipmaps + anisotropic filtering.

---

## 5. Camera and input

**Finding.** RTS cameras converge on: WASD/middle-drag pan, wheel zoom,
Q/E or right-drag orbit, clamped to map bounds, with damping. Kenney's kit and
the Building Template both ship this.

**In our prototype.** `scripts/rts_camera.gd` implements exactly that, clamped to
the lease bounds, with `F` to recentre.

---

## 6. Data-driven design

**Finding.** Tycoon games keep building definitions in data (Godot `Resource`s
or JSON), not in code, so designers can tune costs and capacity without touching
scripts.

**In our prototype.** `CATALOG` in `main.gd` is a dictionary of
`{name, cost, foot, model, rate/capacity/throughput, upkeep}`. The Blender
manifest (`assets/json/manifest.json`) carries the same numbers for the 82
industrial assets, so the two can be merged into one `buildings.json` later.

---

## 7. Sources

- Godot Docs — *Optimization using MultiMeshes*: https://docs.godotengine.org/en/latest/tutorials/performance/using_multimesh.html
- Godot Docs — *GridMap*: https://docs.godotengine.org/en/stable/classes/class_gridmap.html
- Cadmus — *GridMap, modular levels*: https://cadmus.page/en/godot/02-3d/21-gridmap/
- Kenney — *Starter Kit City Builder* (Godot 4.6, CC0): https://github.com/kenneynl/starter-kit-city-builder
- BA Rapid Prototyping — *Unit 4 City Builder / Building Placement*: https://apwt.gitbook.io/ba-game-design/tutorials/godot/unit-4-city-builder
- Godot Learning — *Toon Shader* (CC0, Godot 4.7, banded `light()`): https://godotlearning.com/shaders/toon-shader
- Supermatrix — *Cel shading & outline guide*: https://supermatrix.studio/blog/creating-a-stylized-3d-cel-shader-in-godot-4-from-scratch
- Baldur Games — *Stylized toon shaders in Godot*: https://baldurgames.com/posts/stylized-shaders-godot
- Binbun3D — *Godot toon shading*: https://bun3d.com/tutorials/shading/godot-toon-shading/

---

## 8. Backlog derived from the research

| Priority | Item | Why |
|---|---|---|
| P1 | Save/load (`user://save.json`) | every reference kit has it; prototype has none |
| P1 | `toon.gdshader` with `bands` + rim | tier 2 cel look, matches Blender previews |
| P2 | Auto-rotate buildings toward adjacent road | readability, taught by the BA tutorial |
| P2 | MultiMesh scenery | 1 draw call instead of 140 nodes |
| P2 | GridMap for pipes/roads | batching once networks grow |
| P3 | Inverted-hull outline pass | ink edges on hero buildings |
| P3 | Data-driven `buildings.json` from the Blender manifest | one source of truth for art + economy |
