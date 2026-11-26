"""Assemble a demo field from the kit: onshore field -> midstream -> refinery -> offshore."""

from __future__ import annotations

import json
import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")

DEMO = "OilFieldDemo"

# shared with preview/index.html via assets/json/demo_layout.json
TERRAIN = {
    "land": {"center": [-400, 0], "size": [1700, 3000], "plane": "grass", "z": -0.8},
    "shore": {"center": [405, 0], "size": [90, 3000], "plane": "sand", "z": -0.6},
    "sea": {"center": [1500, 0], "size": [2100, 3000], "plane": "water", "z": 0.0},
}


# --------------------------------------------------------------------------- #
# scene scaffolding
# --------------------------------------------------------------------------- #


def _mat(name, fallback="concrete"):
    return bpy.data.materials.get(name) or bpy.data.materials.get(fallback)


def _plane(name, coll, center, size, mat_name, z=0.0):
    x, y = center
    w, d = size
    me = bpy.data.meshes.new(name)
    me.from_pydata(
        [(x - w / 2, y - d / 2, z), (x + w / 2, y - d / 2, z),
         (x + w / 2, y + d / 2, z), (x - w / 2, y + d / 2, z)],
        [], [(0, 1, 2, 3)],
    )
    me.materials.append(_mat(mat_name))
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def _water_material():
    mat = bpy.data.materials.get("DEMO_WATER")
    if mat:
        return mat
    mat = bpy.data.materials.new("DEMO_WATER")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.02, 0.09, 0.14, 1)
    b.inputs["Roughness"].default_value = 0.08
    b.inputs["Metallic"].default_value = 0.15
    b.inputs["Alpha"].default_value = 0.92
    try:
        mat.blend_method = "BLEND"
    except Exception:
        pass
    return mat


PLACEMENTS = [
    # ---- onshore upstream ------------------------------------------------ #
    ("on_land_rig", -560, 60, 0),
    ("on_workover_rig", -470, -170, 15),
    ("on_pumpjack", -470, -110, 0),
    ("on_pumpjack", -470, -50, 0),
    ("on_pumpjack", -470, 10, 0),
    ("on_pumpjack", -400, -110, 0),
    ("on_pumpjack", -400, -50, 0),
    ("on_pumpjack", -400, 10, 0),
    ("on_gathering_manifold", -350, -40, 0),
    ("on_separator", -350, 40, 0),
    ("on_heater_treater", -350, 90, 0),
    ("on_tank_farm", -270, 150, 0),
    ("on_compressor_station", -270, 20, 0),
    ("on_flare", -230, 200, 0),
    ("prp_workshop", -600, -120, 0),
    ("prp_office_stack", -600, -190, 0),
    ("on_pipeline_valve", -310, 60, 90),
    # ---- midstream ------------------------------------------------------- #
    ("mid_pump_station", -160, 60, 0),
    ("mid_pig_launcher", -105, 60, 90),
    ("mid_gas_plant", 20, -60, 0),
    ("mid_lng_train", 150, 150, 0),
    ("mid_lng_sphere", 90, 250, 0),
    ("mid_tank_terminal", -40, 240, 0),
    # ---- refinery -------------------------------------------------------- #
    ("ref_cdu", -60, -250, 0),
    ("ref_vdu", 30, -270, 0),
    ("ref_fcc", 130, -290, 0),
    ("ref_reformer", -70, -360, 0),
    ("ref_hydrotreater", 10, -360, 0),
    ("ref_coker", 100, -380, 0),
    ("ref_amine", 190, -340, 0),
    ("ref_sru", 190, -255, 0),
    ("ref_cooling_tower", 270, -330, 0),
    ("ref_flare", -160, -330, 0),
    ("ref_control_room", -160, -250, 0),
    ("ref_pipe_rack", -105, -310, 0),
    ("ref_pipe_rack", -85, -310, 0),
    ("ref_pipe_rack", -65, -310, 0),
    ("ref_pipe_rack", -45, -310, 0),
    # ---- coast + marine --------------------------------------------------- #
    ("mid_loading_jetty", 470, 240, 90),
    ("off_fixed_platform", 640, 120, 0),
    ("off_jackup_rig", 640, -80, 20),
    ("off_fpso", 700, 340, -8),
    ("off_supply_vessel", 540, 300, 10),
    ("off_ahts", 540, 150, -20),
    ("off_shuttle_tanker", 760, -230, 5),
    ("off_spar", 780, 180, 0),
    ("off_helicopter", 600, 210, 0, 70),
    ("off_pipelay_barge", 540, -210, 0),
    # ---- vehicles -------------------------------------------------------- #
    ("veh_pickup", -520, 10, 20),
    ("veh_pickup", -480, 120, -35),
    ("veh_crew_bus", -560, -40, 5),
    ("veh_fuel_tanker", -300, 100, 0),
    ("veh_crane_truck", -120, -200, 90),
    ("veh_pipe_truck", -120, 30, 0),
    ("veh_excavator", -610, -250, 30),
    ("veh_bulldozer", -660, -180, -10),
    ("veh_fire_truck", -540, 140, 0),
    ("veh_forklift", -300, -120, 0),
    ("veh_crew_car", 170, 60, 180),
    # ---- props ----------------------------------------------------------- #
    ("prp_team_flag", -520, 170, 0),
    ("prp_team_flag", -180, -320, 0),
    ("prp_floodlight", -620, 40, 0),
    ("prp_floodlight", -230, -220, 0),
]


def build(manifest=None, render_hero=False):
    src_scene = bpy.context.scene
    demo = bpy.data.scenes.new(DEMO)
    root = demo.collection

    terrain = bpy.data.collections.new("DEMO_Terrain")
    field = bpy.data.collections.new("DEMO_Field")
    root.children.link(terrain)
    root.children.link(field)

    # ---- terrain / sea --------------------------------------------------- #
    _plane("DEMO_LAND", terrain, TERRAIN["land"]["center"], TERRAIN["land"]["size"],
           TERRAIN["land"]["plane"], TERRAIN["land"]["z"])
    _plane("DEMO_SHORE", terrain, TERRAIN["shore"]["center"], TERRAIN["shore"]["size"],
           TERRAIN["shore"]["plane"], TERRAIN["shore"]["z"])
    water = _plane("DEMO_SEA", terrain, TERRAIN["sea"]["center"], TERRAIN["sea"]["size"],
                   TERRAIN["sea"]["plane"], TERRAIN["sea"]["z"])
    water.data.materials.clear()
    water.data.materials.append(_water_material())
    try:
        water.visible_shadow = False
    except Exception:
        pass

    # ---- assets ---------------------------------------------------------- #
    placed = 0
    missing = []
    layout_objects = []
    for entry in PLACEMENTS:
        aid, x, y, rot = entry[0], entry[1], entry[2], entry[3]
        z = entry[4] if len(entry) > 4 else 0.0
        src = bpy.data.objects.get(aid)
        if src is None:
            missing.append(aid)
            continue
        ob = src.copy()
        ob.name = f"{aid}.{placed:03d}"
        ob.data = src.data
        ob.location = (x, y, z)
        ob.rotation_euler = (0, 0, math.radians(rot))
        ob.hide_render = False
        field.objects.link(ob)
        layout_objects.append({"id": aid, "x": x, "y": y, "z": z, "rot": rot})
        placed += 1

    # ---- roads ----------------------------------------------------------- #
    road = bpy.data.objects.get("prp_road_straight")
    if road:
        for i in range(62):
            ob = road.copy()
            ob.name = f"road.ew.{i:03d}"
            ob.data = road.data
            ob.location = (-620 + i * 12.0, -20, 0.02)
            field.objects.link(ob)
            layout_objects.append({"id": "prp_road_straight", "x": -620 + i * 12.0,
                                   "y": -20, "z": 0.02, "rot": 0})
        for i in range(20):
            ob = road.copy()
            ob.name = f"road.ns.{i:03d}"
            ob.data = road.data
            ob.location = (-330, -20 + i * 12.0, 0.04)
            ob.rotation_euler = (0, 0, math.radians(90))
            field.objects.link(ob)
            layout_objects.append({"id": "prp_road_straight", "x": -330,
                                   "y": -20 + i * 12.0, "z": 0.04, "rot": 90})

    # ---- lighting / sky -------------------------------------------------- #
    world = bpy.data.worlds.new("DEMO_SKY")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.28, 0.42, 0.58, 1)
    bg.inputs["Strength"].default_value = 1.1
    demo.world = world

    for name, energy, rot, color in (
        ("SUN", 4.0, (math.radians(52), 0, math.radians(35)), (1.0, 0.96, 0.88)),
        ("FILL", 1.2, (math.radians(65), 0, math.radians(-120)), (0.72, 0.84, 1.0)),
    ):
        ld = bpy.data.lights.new(f"DEMO_{name}", "SUN")
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(6)
        lo = bpy.data.objects.new(f"DEMO_{name}", ld)
        lo.rotation_euler = rot
        terrain.objects.link(lo)

    # ---- camera ---------------------------------------------------------- #
    cam_data = bpy.data.cameras.new("DEMO_CAM")
    cam_data.clip_start = 0.5
    cam_data.clip_end = 25000.0
    cam_data.lens = 28
    cam = bpy.data.objects.new("DEMO_CAM", cam_data)
    cam.location = (300, -1200, 620)
    target = Vector((140, 0, 0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    terrain.objects.link(cam)
    demo.camera = cam

    demo.render.engine = "BLENDER_EEVEE"
    demo.render.resolution_x = 1920
    demo.render.resolution_y = 1080
    demo.render.film_transparent = False
    demo.view_settings.view_transform = "AgX"
    try:
        demo.view_settings.look = "AgX - Medium High Contrast"
        demo.eevee.taa_render_samples = 32
    except Exception:
        pass
    demo.view_settings.exposure = 0.4

    # ---- save ------------------------------------------------------------ #
    layout = {
        "units": "meters",
        "source": "blender/demo_scene.py",
        "terrain": TERRAIN,
        "camera": {"position": [300, -1200, 620], "target": [140, 0, 0], "lens_mm": 28},
        "objects": layout_objects,
    }
    os.makedirs(os.path.join(ASSETS, "json"), exist_ok=True)
    with open(os.path.join(ASSETS, "json", "demo_layout.json"), "w", encoding="utf-8") as fh:
        json.dump(layout, fh, indent=1)

    try:
        bpy.context.window.scene = demo
    except Exception:
        pass

    if render_hero:
        demo.render.filepath = os.path.join(ASSETS, "previews", "demo_field.png")
        os.makedirs(os.path.dirname(demo.render.filepath), exist_ok=True)
        bpy.ops.render.render(write_still=True, scene=demo.name)

    if src_scene.name != DEMO:
        bpy.data.scenes.remove(src_scene)
    # drop the orphaned kit datablocks so the demo file contains only the demo
    for _ in range(3):
        try:
            bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
        except Exception:
            break

    path = os.path.join(ASSETS, "blend", "oilfield_demo_field.blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print(f"[ok] demo scene: {placed} objects, missing={missing}")
    return path
