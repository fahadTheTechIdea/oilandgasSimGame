"""Build orchestrator.

    blender --background --python blender/build.py -- [options]

Options
    --only a,b          only these categories
    --asset x,y         only these asset ids
    --render            render preview PNGs
    --no-export         skip glb/fbx
    --no-lods           skip LOD generation
    --contact-sheet     build a contact sheet from previews (implies nothing)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from kit import core, mats  # noqa: E402
from kit import onshore, offshore, midstream, refinery, vehicles, props, game  # noqa: E402

ASSETS_DIR = os.path.join(ROOT, "assets")

CATEGORIES = [
    ("onshore", "KIT_Onshore", "ON_", onshore.REGISTRY),
    ("offshore", "KIT_Offshore", "OFF_", offshore.REGISTRY),
    ("midstream", "KIT_Midstream", "MID_", midstream.REGISTRY),
    ("refinery", "KIT_Refinery", "REF_", refinery.REGISTRY),
    ("vehicles", "KIT_Vehicles", "VEH_", vehicles.REGISTRY),
    ("props", "KIT_Props", "PRP_", props.REGISTRY),
    ("game", "KIT_Game", "GAM_", game.REGISTRY),
]


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--only", default="")
    p.add_argument("--asset", default="")
    p.add_argument("--render", action="store_true")
    p.add_argument("--no-export", action="store_true")
    p.add_argument("--no-lods", action="store_true")
    p.add_argument("--no-demo", action="store_true")
    p.add_argument("--preview-size", type=int, default=640)
    return p.parse_args(argv)


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace("\\", "/")


def main() -> None:
    args = parse_args()
    only = {s.strip() for s in args.only.split(",") if s.strip()}
    wanted = {s.strip() for s in args.asset.split(",") if s.strip()}
    filtered = bool(only or wanted)

    t0 = time.time()
    core.reset_scene()
    mats.init_materials()
    scene = bpy.context.scene
    scene.name = "OilfieldKit"

    manifest = {
        "schema": "oilfield-kit/1",
        "generator": "blender",
        "blender_version": bpy.app.version_string,
        "conventions": {
            "units": "meters",
            "up_axis": "+Z",
            "forward_axis": "-Y",
            "origin": "base centre, z=0 on ground",
            "shading": "flat/faceted stylised PBR",
            "team_tint_materials": ["paint_yellow", "paint_orange", "paint_blue",
                                    "paint_red", "paint_green", "paint_teal"],
        },
        "assets": [],
        "categories": {},
    }

    built: list[tuple[str, bpy.types.Object, dict]] = []
    errors: list[str] = []

    for cat_key, coll_name, prefix, registry in CATEGORIES:
        if only and cat_key not in only:
            continue
        coll = core.collection(coll_name)
        cat_assets = []
        for entry in registry:
            aid = entry["aid"]
            if wanted and aid not in wanted:
                continue
            # enforce prefix
            if not aid.startswith(prefix.lower()):
                aid = prefix.lower() + aid
                entry["aid"] = aid
            t1 = time.time()
            try:
                a = core.Asset(aid, cat_key, coll)
                entry["build"](a)
                obj = a.finish()
            except Exception as exc:
                errors.append(f"{aid}: {exc}\n{traceback.format_exc()}")
                print(f"[FAIL] {aid}: {exc}")
                print(traceback.format_exc())
                continue
            lods = []
            if not args.no_lods:
                try:
                    lods = core.make_lods(obj)
                except Exception as exc:
                    print(f"[warn] LOD failed for {aid}: {exc}")
            col = core.make_collision(obj)
            obj["display_name"] = entry.get("name", aid)
            entry["_obj"] = obj
            entry["_lods"] = lods
            entry["_col"] = col
            built.append((cat_key, obj, entry))
            cat_assets.append(aid)
            dt = time.time() - t1
            print(f"[ok] {aid:28s} {obj['tri_count']:6d} tris  {dt:5.2f}s")
        manifest["categories"][cat_key] = cat_assets

    # ------------------------------------------------------------------ export
    if not args.no_export and built:
        for cat_key, obj, entry in built:
            aid = entry["aid"]
            core.export_glb(os.path.join(ASSETS_DIR, "glb", cat_key, f"{aid}.glb"), [obj])
            core.export_fbx(os.path.join(ASSETS_DIR, "fbx", cat_key, f"{aid}.fbx"), [obj])
        if not filtered:
            core.export_glb(os.path.join(ASSETS_DIR, "glb", "oilfield_kit.glb"),
                            [o for _, o, _ in built])
        print("[ok] exported kit")

    # ------------------------------------------------------------------ blend
    os.makedirs(os.path.join(ASSETS_DIR, "blend"), exist_ok=True)
    kit_blend = os.path.join(ASSETS_DIR, "blend", "oilfield_kit.blend")
    if not filtered:
        bpy.ops.wm.save_as_mainfile(filepath=kit_blend)
        print(f"[ok] saved {rel(kit_blend)}")
    else:
        print("[info] filtered build — master .blend and manifest left untouched")

    # ------------------------------------------------------------------ previews
    prepared = None
    if args.render and built:
        import render_previews
        prepared = render_previews.setup_preview_scene()
        for cat_key, obj, entry in built:
            try:
                path = os.path.join(ASSETS_DIR, "previews", f"{entry['aid']}.png")
                render_previews.render_object(prepared, obj, path, args.preview_size)
                entry["_preview"] = path
            except Exception as exc:
                print(f"[warn] preview failed for {entry['aid']}: {exc}")
                errors.append(f"preview {entry['aid']}: {exc}")

    # ------------------------------------------------------------------ manifest
    for cat_key, obj, entry in built:
        aid = entry["aid"]
        lod_tris = [l["tri_count"] for l in entry.get("_lods", [])]
        rec = {
            "id": aid,
            "name": entry.get("name", aid),
            "category": cat_key,
            "collection": "KIT_" + cat_key.capitalize(),
            "object": obj.name,
            "gameplay": entry.get("gameplay", {}),
            "geometry": {
                "triangles": obj["tri_count"],
                "lod_triangles": lod_tris,
                "size_m": [obj["size_x"], obj["size_y"], obj["size_z"]],
                "materials": [m.name for m in obj.data.materials],
            },
            "files": {
                "glb": rel(os.path.join(ASSETS_DIR, "glb", cat_key, f"{aid}.glb"))
                if not args.no_export else None,
                "fbx": rel(os.path.join(ASSETS_DIR, "fbx", cat_key, f"{aid}.fbx"))
                if not args.no_export else None,
                "preview": rel(entry["_preview"]) if entry.get("_preview") else None,
            },
        }
        manifest["assets"].append(rec)

    manifest["totals"] = {
        "assets": len(manifest["assets"]),
        "triangles": sum(a["geometry"]["triangles"] for a in manifest["assets"]),
        "categories": len([c for c in manifest["categories"] if manifest["categories"][c]]),
    }
    os.makedirs(os.path.join(ASSETS_DIR, "json"), exist_ok=True)
    mpath = os.path.join(ASSETS_DIR, "json", "manifest.json")
    if not filtered:
        with open(mpath, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2)

    # ------------------------------------------------------------------ demo
    if not args.no_demo and not only and not wanted:
        try:
            import demo_scene
            demo_scene.build(manifest, render_hero=args.render)
        except Exception as exc:
            print(f"[warn] demo scene failed: {exc}")
            errors.append(f"demo: {exc}\n{traceback.format_exc()}")

    print(f"\n=== DONE in {time.time() - t0:.1f}s ===")
    print(f"assets: {manifest['totals']['assets']}  "
          f"tris: {manifest['totals']['triangles']:,}")
    print(f"manifest: {rel(mpath)}")
    if errors:
        print(f"\n{len(errors)} problem(s):")
        for e in errors:
            print(" -", e.splitlines()[0])


if __name__ == "__main__":
    main()
