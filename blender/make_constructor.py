"""Low-poly construction crane truck for Oilfield Tycoon.

Built with the blender-skills hard-surface + godot-export standards:
  * primary volumes first, then panel breaks and small mechanical details
  * selective bevels (primary edges 0.02 m, panel strips 0.005 m)
  * moving parts are separate objects; the crane arm pivots on the `Boom` node
  * Principled BSDF -> glTF metallic-roughness, meters, +Z up / -Y forward
  * exported as a single GLB with modifiers applied

Run headless:
  blender -b -P blender/make_constructor.py

Exports `game/assets/models/veh_constructor.glb`.
"""
import bpy
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "models", "veh_constructor.glb")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgba, rough=0.65, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def bevel(obj, width=0.02, segments=2, angle=40.0):
    """Selective hard-surface bevel + weighted normals (kept non-destructive)."""
    b = obj.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle)
    w = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    w.keep_sharp = True
    return obj


def cube(name, loc, scale, mat, bev=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bev > 0.0:
        bevel(o, bev)
    return o


def cyl(name, loc, radius, depth, rot, mat, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    return o


def parent_keep(child, parent):
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def main():
    reset()

    paint = material("CraneYellow", (0.85, 0.60, 0.08, 1.0), 0.5)
    dark = material("CraneDark", (0.10, 0.11, 0.12, 1.0), 0.6)
    steel = material("CraneSteel", (0.42, 0.45, 0.48, 1.0), 0.4, 0.6)
    glass = material("CraneGlass", (0.28, 0.45, 0.55, 1.0), 0.15)
    rubber = material("CraneRubber", (0.05, 0.05, 0.05, 1.0), 0.9)
    warn = material("CraneWarning", (0.90, 0.35, 0.05, 1.0), 0.5)
    light = material("CraneLight", (1.0, 0.92, 0.70, 1.0), 0.2, 0.0, emit=2.0)

    parts = []

    # ---- primary volumes -------------------------------------------------- #
    parts.append(cube("Chassis", (0.0, 0.2, 0.95), (2.3, 6.2, 0.55), dark))
    parts.append(cube("Deck", (0.0, 0.9, 1.28), (2.4, 3.8, 0.18), paint))
    parts.append(cube("Cab", (0.0, -2.0, 1.85), (2.2, 1.8, 1.5), paint))
    parts.append(cube("Windshield", (0.0, -2.92, 2.05), (1.9, 0.10, 0.85), glass, 0.01))
    parts.append(cube("Bumper", (0.0, -3.02, 0.85), (2.3, 0.22, 0.35), steel))
    parts.append(cube("Grille", (0.0, -3.06, 1.35), (1.4, 0.08, 0.42), dark, 0.005))

    # ---- panel breaks + cab details -------------------------------------- #
    for x in (-1.21, 1.21):
        parts.append(cube("DeckPanel", (x, 0.9, 1.30), (0.04, 3.6, 0.16), dark, 0.005))
        parts.append(cube("CabDoor", (x, -2.0, 1.80), (0.03, 0.06, 1.10), dark, 0.005))
        parts.append(cube("Mirror", (x * 1.16, -2.85, 2.15), (0.16, 0.06, 0.12), dark, 0.005))
    parts.append(cube("Headlight", (-0.78, -3.10, 1.02), (0.34, 0.06, 0.20), light, 0.005))
    parts.append(cube("Headlight", (0.78, -3.10, 1.02), (0.34, 0.06, 0.20), light, 0.005))
    parts.append(cube("WarningChevron", (0.0, 3.27, 1.05), (2.1, 0.06, 0.28), warn, 0.005))
    parts.append(cyl("Exhaust", (1.02, -1.05, 2.55), 0.08, 1.25, (0, 0, 0), steel, 10))

    # ---- wheels: three axles, with hubs ---------------------------------- #
    for y in (-2.1, 0.5, 2.3):
        for x in (-1.15, 1.15):
            parts.append(cyl("Wheel", (x, y, 0.72), 0.72, 0.42,
                             (0.0, math.radians(90), 0.0), rubber))
            parts.append(cyl("Hub", (x + (0.16 if x > 0 else -0.16), y, 0.72), 0.26, 0.12,
                             (0.0, math.radians(90), 0.0), steel, 12))

    # ---- outriggers: four legs + pads ------------------------------------ #
    for x in (-1.62, 1.62):
        for y in (-0.3, 2.0):
            parts.append(cube("OutriggerArm", (x * 0.86, y, 0.72), (0.92, 0.32, 0.20), steel))
            parts.append(cube("OutriggerPad", (x, y, 0.16), (0.42, 0.42, 0.16), dark, 0.01))

    # ---- turret + boom pivot (separate node, animated in Godot) ---------- #
    parts.append(cyl("Turret", (0.0, 1.3, 1.6), 1.0, 0.7, (0, 0, 0), paint, verts=20))
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0.0, 1.3, 1.85))
    pivot = bpy.context.active_object
    pivot.name = "Boom"
    pivot.rotation_mode = 'XYZ'
    pivot.rotation_euler = (math.radians(-28.0), 0.0, 0.0)

    # lattice boom: two rails + cross braces reads as fabricated steel
    for x in (-0.19, 0.19):
        rail = cube("BoomRail", (x, 1.3, 4.35), (0.07, 0.16, 5.3), paint, 0.008)
        parent_keep(rail, pivot)
    for k in range(8):
        z = 2.1 + k * 0.62
        brace = cube("BoomBrace", (0.0, 1.3, z), (0.40, 0.10, 0.08), paint, 0.004)
        parent_keep(brace, pivot)
    tip = cube("BoomTip", (0.0, 1.3, 6.95), (0.46, 0.46, 0.42), steel)
    parent_keep(tip, pivot)
    # hydraulic ram from turret to the boom underside
    ram = cyl("BoomRam", (0.0, 0.55, 2.55), 0.12, 2.1, (math.radians(62), 0, 0), steel, 12)
    parent_keep(ram, pivot)
    cable = cube("Cable", (0.0, 1.3, 5.85), (0.05, 0.05, 2.3), dark, 0.0)
    parent_keep(cable, pivot)
    hook = cube("Hook", (0.0, 1.3, 4.65), (0.32, 0.32, 0.34), steel)
    parent_keep(hook, pivot)
    hook_block = cube("HookBlock", (0.0, 1.3, 4.95), (0.20, 0.20, 0.22), warn, 0.008)
    parent_keep(hook_block, pivot)

    # ---- export ----------------------------------------------------------- #
    bpy.ops.object.select_all(action='SELECT')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_animations=False,
    )
    print("EXPORTED", OUT)


main()
