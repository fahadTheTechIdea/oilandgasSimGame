"""Generate docs/ASSET_LIBRARY.md from assets/json/manifest.json."""

from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "json", "manifest.json")
OUT = os.path.join(ROOT, "docs", "ASSET_LIBRARY.md")

CATEGORY_TITLES = {
    "onshore": "Onshore Upstream",
    "offshore": "Offshore & Marine",
    "midstream": "Midstream — Pipelines, Gas & LNG",
    "refinery": "Downstream — Refinery",
    "vehicles": "Vehicles & Heavy Equipment",
    "props": "Environment, Site & Gameplay Props",
}

CATEGORY_NOTES = {
    "onshore": "Drilling, lift, separation, storage and gathering. Tier-1 through tier-2 play.",
    "offshore": "Waterline-origin assets (`placement: waterline`) except the subsea tree and "
                "manifold which sit on the seabed. Submerged structure is modelled to give the "
                "game a visible waterline cut.",
    "midstream": "The pipe between the field and the money. Capacity here is usually the binding "
                 "constraint in a match.",
    "refinery": "Process units are stylised but topologically honest: furnace, column, "
                "reactor, exchanger, flare. Each maps to one throughput decision.",
    "vehicles": "All vehicles face −Y. Wheels are separate geometry but joined into the body mesh; "
                "animate by splitting the wheel objects if you need rolling wheels.",
    "props": "Build-plot markers, roads, fences and site furniture — the pieces that make the map "
             "readable during placement.",
}

KEY_STATS = [
    ("capacity_bopd", "oil rate", "bbl/d"),
    ("capacity_bfpd", "fluid rate", "bbl/d"),
    ("capacity_mmscfd", "gas rate", "MMscf/d"),
    ("capacity_bbl", "storage", "bbl"),
    ("capacity_bwpd", "water", "bbl/d"),
    ("throughput_bpd", "throughput", "bbl/d"),
    ("capacity_mtpa", "LNG", "Mtpa"),
    ("capacity_m3", "volume", "m³"),
    ("well_slots", "well slots", ""),
    ("drill_depth_m", "max depth", "m"),
    ("water_depth_max_m", "water depth", "m"),
    ("water_depth_min_m", "min water depth", "m"),
    ("crew", "crew", ""),
    ("passengers", "passengers", ""),
    ("lift_t", "lift", "t"),
    ("speed_kmh", "speed", "km/h"),
    ("speed_kn", "speed", "kn"),
    ("power_kw", "power", "kW"),
    ("capacity_mmscfd", "gas", "MMscf/d"),
]


def money(v) -> str:
    if v is None:
        return "—"
    v = float(v)
    if v >= 1e9:
        return f"${v/1e9:.2f} bn"
    if v >= 1e6:
        return f"${v/1e6:.1f} M"
    if v >= 1e3:
        return f"${v/1e3:.0f} k"
    return f"${v:.0f}"


def stats(g: dict) -> str:
    out = []
    seen = set()
    for key, label, unit in KEY_STATS:
        if key in g and key not in seen:
            seen.add(key)
            val = g[key]
            if isinstance(val, float):
                val = f"{val:,.0f}" if val >= 100 else f"{val:g}"
            else:
                val = f"{val:,}" if isinstance(val, int) else str(val)
            out.append(f"{label} {val}{(' ' + unit) if unit else ''}")
    for extra in ("recovery_factor", "accuracy_pct", "sulfur_t_day", "gasoline_yield"):
        if extra in g:
            out.append(f"{extra.replace('_', ' ')} {g[extra]}")
    return " · ".join(out[:6])


def main() -> None:
    with open(MANIFEST, "r", encoding="utf-8") as fh:
        man = json.load(fh)

    by_cat: dict[str, list] = {}
    for a in man["assets"]:
        by_cat.setdefault(a["category"], []).append(a)

    lines = []
    lines.append("# Asset Library\n")
    lines.append(
        f"**{man['totals']['assets']} assets · {man['totals']['triangles']:,} triangles · "
        f"generated with Blender {man['blender_version']}**\n"
    )
    lines.append(
        "Auto-generated from `assets/json/manifest.json` by `blender/gen_docs.py`. "
        "Do not edit by hand — edit the builder in `blender/kit/` and rebuild.\n"
    )
    lines.append("## Conventions\n")
    lines.append("| | |")
    lines.append("|---|---|")
    for k, v in man["conventions"].items():
        if isinstance(v, list):
            v = ", ".join(f"`{x}`" for x in v)
        lines.append(f"| {k.replace('_', ' ')} | {v} |")
    lines.append("")

    lines.append("## Summary\n")
    lines.append("| Category | Assets | Triangles |")
    lines.append("|---|---:|---:|")
    for cat, items in by_cat.items():
        tris = sum(i["geometry"]["triangles"] for i in items)
        lines.append(f"| {CATEGORY_TITLES.get(cat, cat)} | {len(items)} | {tris:,} |")
    lines.append(f"| **Total** | **{man['totals']['assets']}** | "
                 f"**{man['totals']['triangles']:,}** |")
    lines.append("")

    for cat, items in by_cat.items():
        lines.append(f"## {CATEGORY_TITLES.get(cat, cat)}\n")
        if cat in CATEGORY_NOTES:
            lines.append(f"_{CATEGORY_NOTES[cat]}_\n")
        lines.append("| Asset | ID | Tris | Size L×W×H (m) | Capex | Build | Tier | Key stats |")
        lines.append("|---|---|---:|---|---:|---:|---:|---|")
        for a in sorted(items, key=lambda x: (x["gameplay"].get("tier", 9), x["id"])):
            g = a.get("gameplay", {})
            geo = a["geometry"]
            size = " × ".join(f"{v:g}" for v in geo["size_m"])
            lines.append(
                f"| {a['name']} | `{a['id']}` | {geo['triangles']:,} | {size} | "
                f"{money(g.get('cost_usd'))} | {g.get('build_days', '—')} d | "
                f"{g.get('tier', '—')} | {stats(g)} |"
            )
        lines.append("")

    lines.append("## Naming and engine notes\n")
    lines.append("""
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
""")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"wrote {os.path.relpath(OUT, ROOT)}")

    # ---- csv for spreadsheet balancing ---------------------------------- #
    import csv
    csv_path = os.path.join(ROOT, "assets", "json", "gameplay_balance.csv")
    keys = ["id", "name", "category", "tier", "role", "cost_usd", "build_days",
            "upkeep_usd_day", "crew", "power_kw", "footprint_m2", "capacity_bopd",
            "capacity_bfpd", "capacity_mmscfd", "capacity_bbl", "drill_depth_m",
            "water_depth_max_m", "triangles", "size_x", "size_y", "size_z"]
    with open(csv_path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(keys)
        for a in man["assets"]:
            g = a.get("gameplay", {})
            geo = a["geometry"]
            row = {
                "id": a["id"], "name": a["name"], "category": a["category"],
                "tier": g.get("tier", ""), "role": g.get("role", ""),
                "cost_usd": g.get("cost_usd", ""), "build_days": g.get("build_days", ""),
                "upkeep_usd_day": g.get("upkeep_usd_day", ""), "crew": g.get("crew", ""),
                "power_kw": g.get("power_kw", ""), "footprint_m2": g.get("footprint_m2", ""),
                "capacity_bopd": g.get("capacity_bopd", ""),
                "capacity_bfpd": g.get("capacity_bfpd", ""),
                "capacity_mmscfd": g.get("capacity_mmscfd", ""),
                "capacity_bbl": g.get("capacity_bbl", ""),
                "drill_depth_m": g.get("drill_depth_m", ""),
                "water_depth_max_m": g.get("water_depth_max_m", ""),
                "triangles": geo["triangles"],
                "size_x": geo["size_m"][0], "size_y": geo["size_m"][1],
                "size_z": geo["size_m"][2],
            }
            w.writerow([row[k] for k in keys])
    print(f"wrote {os.path.relpath(csv_path, ROOT)}")


if __name__ == "__main__":
    main()
