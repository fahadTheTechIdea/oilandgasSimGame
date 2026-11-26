"""Studio preview renders for every asset (EEVEE, headless)."""

from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector

PREVIEW_TAG = "_PREVIEW"


def _srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def setup_preview_scene():
    scene = bpy.context.scene
    coll = bpy.data.collections.new(PREVIEW_TAG)
    scene.collection.children.link(coll)

    # ---- world ---------------------------------------------------------- #
    world = bpy.data.worlds.new("PREVIEW_WORLD")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (_srgb(0.155), _srgb(0.165), _srgb(0.140), 1.0)
    bg.inputs["Strength"].default_value = 0.95
    scene.world = world

    # ---- ground: radial falloff so the floor melts into the backdrop ---- #
    bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -0.02))
    ground = bpy.context.active_object
    ground.name = "PREVIEW_GROUND"
    gmat = bpy.data.materials.new("PREVIEW_GROUND_MAT")
    gmat.use_nodes = True
    nt = gmat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.94
    bsdf.inputs["Metallic"].default_value = 0.0
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (0.125, 0.132, 0.112, 1.0)
    cr.elements[1].position = 0.055
    cr.elements[1].color = (0.042, 0.045, 0.038, 1.0)
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    nt.links.new(ln.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    ground.data.materials.append(gmat)
    for c in ground.users_collection:
        c.objects.unlink(ground)
    coll.objects.link(ground)

    # ---- camera --------------------------------------------------------- #
    cam_data = bpy.data.cameras.new("PREVIEW_CAM")
    cam_data.lens = 52
    cam = bpy.data.objects.new("PREVIEW_CAM", cam_data)
    coll.objects.link(cam)
    scene.camera = cam

    # ---- lights (suns = scale independent) ------------------------------ #
    lights = []
    for name, energy, rot, color in (
        ("KEY", 4.9, (math.radians(56), 0, math.radians(34)), (1.0, 0.95, 0.86)),
        ("FILL", 1.05, (math.radians(68), 0, math.radians(-118)), (0.72, 0.84, 1.0)),
        ("RIM", 2.4, (math.radians(74), 0, math.radians(198)), (1.0, 0.92, 0.80)),
    ):
        ld = bpy.data.lights.new(f"PREVIEW_{name}", "SUN")
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(14)
        lo = bpy.data.objects.new(f"PREVIEW_{name}", ld)
        lo.rotation_euler = rot
        coll.objects.link(lo)
        lights.append(lo)

    # ---- render settings ------------------------------------------------- #
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except Exception:
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    try:
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    try:
        scene.eevee.use_raytracing = True
    except Exception:
        pass
    scene.render.use_persistent_data = True
    scene.view_settings.view_transform = "Standard"
    try:
        scene.view_settings.look = "None"
    except Exception:
        pass
    scene.view_settings.exposure = 0.05

    # ---- toon / faceted presentation ------------------------------------ #
    scene.render.use_freestyle = True
    scene.render.line_thickness = 1.1
    for vl in scene.view_layers:
        vl.use_freestyle = True
        fs = vl.freestyle_settings
        fs.crease_angle = math.radians(118)
        if not fs.linesets:
            fs.linesets.new("Toon")
        ls = fs.linesets[0]
        ls.select_silhouette = True
        ls.select_border = False
        ls.select_crease = False
        ls.select_edge_mark = False
        ls.select_contour = False
        if ls.linestyle is None:
            ls.linestyle = bpy.data.linestyles.new("ToonLine")
        ls.linestyle.color = (0.06, 0.07, 0.05)
        ls.linestyle.thickness = 1.25

    return {"coll": coll, "cam": cam, "scene": scene, "ground": ground}


def _frame_camera(cam, obj, scene=None, margin=0.9):
    """Iteratively fit the camera so the asset fills `margin` of the frame."""
    from bpy_extras.object_utils import world_to_camera_view

    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    center = sum(bb, Vector()) / 8.0
    radius = max((v - center).length for v in bb)
    direction = Vector((1.0, -1.35, 0.72)).normalized()
    fov = cam.data.angle
    dist = radius / math.tan(fov * 0.5) * 1.05
    for _ in range(5):
        cam.location = center + direction * dist
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        if scene is None:
            break
        bpy.context.view_layer.update()
        coords = [world_to_camera_view(scene, cam, v) for v in bb]
        ext = max(
            max(abs(c.x - 0.5) for c in coords) * 2.0,
            max(abs(c.y - 0.5) for c in coords) * 2.0,
        )
        if ext < 1e-4:
            break
        factor = ext / margin
        if abs(factor - 1.0) < 0.02:
            break
        dist *= factor
    cam.location = center + direction * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    return radius * 2.0


def _toon_material(src):
    """Build a 3-band cel material from a flat PBR source (preview only)."""
    mat = bpy.data.materials.new(src.name + "_TOON")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    bsdf = src.node_tree.nodes.get("Principled BSDF") if src.use_nodes else None
    base = tuple(bsdf.inputs["Base Color"].default_value)[:3] if bsdf else (0.6, 0.6, 0.6)

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (700, 0)
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.location = (-150, 0)
    diff.inputs["Color"].default_value = (*base, 1.0)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    s2r.location = (50, 0)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.location = (250, 0)
    cr = ramp.color_ramp
    cr.interpolation = "CONSTANT"
    cr.elements[0].position = 0.0
    cr.elements[0].color = (base[0] * 0.62, base[1] * 0.62, base[2] * 0.67, 1.0)
    cr.elements[1].position = 0.22
    cr.elements[1].color = (base[0] * 0.85, base[1] * 0.85, base[2] * 0.89, 1.0)
    e = cr.elements.new(0.52)
    e.color = (min(1.0, base[0] * 1.06), min(1.0, base[1] * 1.06), min(1.0, base[2] * 1.06), 1.0)
    emis = nt.nodes.new("ShaderNodeEmission")
    emis.location = (500, 0)
    emis.inputs["Strength"].default_value = 1.0

    nt.links.new(diff.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emis.inputs["Color"])
    nt.links.new(emis.outputs[0], out.inputs["Surface"])
    mat["style"] = "toon"
    return mat


_TOON_CACHE = {}


def apply_toon(obj):
    """Swap an object's materials for cel versions; returns originals for restore."""
    originals = []
    for slot in obj.material_slots:
        src = slot.material
        originals.append(src)
        if src is None or src.name.startswith("emit_"):
            continue
        key = src.name
        tm = _TOON_CACHE.get(key)
        if tm is None:
            tm = _toon_material(src)
            _TOON_CACHE[key] = tm
        slot.material = tm
    return originals


def restore_materials(obj, originals):
    for slot, src in zip(obj.material_slots, originals):
        slot.material = src


def render_object(prepared, obj, path, size=640, toon=True):
    scene = prepared["scene"]
    cam = prepared["cam"]
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100

    # show only the target
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name != "PREVIEW_GROUND":
            o.hide_render = True
    obj.hide_render = False

    originals = apply_toon(obj) if toon else None

    _frame_camera(cam, obj, scene)
    max_dim = max(obj.dimensions.x, obj.dimensions.y, obj.dimensions.z, 1.0)
    prepared["ground"].scale = (max_dim * 40.0, max_dim * 40.0, max_dim * 40.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    if originals is not None:
        restore_materials(obj, originals)
    obj.hide_render = True
    return path


def teardown(prepared):
    for o in list(prepared["coll"].objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(prepared["coll"])
