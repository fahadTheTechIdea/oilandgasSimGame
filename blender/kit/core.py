"""Core asset builder: bmesh geometry accumulation, materials, LOD, export helpers.

Design goals
------------
* No bpy.ops for modelling (deterministic, fast, background-safe).
* One mesh per asset, multiple material slots -> low draw calls.
* Origin at base centre, +Z up, -Y forward, 1 unit = 1 m.
"""

from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

TAU = math.tau
D2R = math.pi / 180.0

# Global faceting factor: < 1 gives chunkier low-poly silhouettes (cartoon style).
FACET = 0.66


def facet_seg(n: int, minimum: int = 5) -> int:
    return max(minimum, int(round(n * FACET)))

# --------------------------------------------------------------------------- #
# scene helpers
# --------------------------------------------------------------------------- #


def reset_scene() -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 30
    return scene


def collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(coll)
    return coll


def purge_orphans() -> None:
    for _ in range(3):
        bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


# --------------------------------------------------------------------------- #
# asset builder
# --------------------------------------------------------------------------- #


class Asset:
    """Accumulates geometry into a single bmesh, then bakes one mesh object."""

    def __init__(self, aid: str, category: str, coll: bpy.types.Collection):
        self.aid = aid
        self.category = category
        self.coll = coll
        self.bm = bmesh.new()
        self.materials: list[bpy.types.Material] = []
        self.meta: dict = {}
        self.obj: bpy.types.Object | None = None
        self._verts: list = []

    # -- material bookkeeping ------------------------------------------------ #
    def mi(self, mat) -> int:
        m = mat if isinstance(mat, bpy.types.Material) else MATERIALS[mat]
        if m not in self.materials:
            self.materials.append(m)
        return self.materials.index(m)

    def _assign(self, verts, mat) -> None:
        idx = self.mi(mat)
        vs = set(verts)
        for v in verts:
            for f in v.link_faces:
                if all(vv in vs for vv in f.verts):
                    f.material_index = idx

    def _xform(self, verts, matrix: Matrix) -> None:
        for v in verts:
            v.co = matrix @ v.co

    # -- primitives ---------------------------------------------------------- #
    def box(self, size, loc=(0, 0, 0), mat="steel", rot=(0, 0, 0), bevel=0.012):
        """Axis-aligned (then rotated) box. `size` is full extents.

        Default bevel is the hard-surface primary-edge tier (0.012 m, 2 segments)
        so every hard edge catches light. Pass ``bevel=0.0`` for razor-sharp
        decals or intentionally flat panels.
        """
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        m = (
            Matrix.Translation(Vector(loc))
            @ Euler(rot, "XYZ").to_matrix().to_4x4()
            @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0)))
        )
        self._xform(verts, m)
        self._assign(verts, mat)
        if bevel > 0.0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(
                self.bm, geom=edges, offset=bevel, segments=2,
                affect="EDGES", profile=0.5, clamp_overlap=True,
            )
        return verts

    def cyl(self, r, h, loc=(0, 0, 0), mat="steel", seg=24, cap=True, r2=None,
            rot=(0, 0, 0), axis=None):
        res = bmesh.ops.create_cone(
            self.bm, cap_ends=cap, cap_tris=False, segments=facet_seg(seg),
            radius1=r, radius2=(r if r2 is None else r2), depth=h,
        )
        verts = res["verts"]
        if axis is not None:
            q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
            rotm = q.to_matrix().to_4x4()
        else:
            rotm = Euler(rot, "XYZ").to_matrix().to_4x4()
        self._xform(verts, Matrix.Translation(Vector(loc)) @ rotm)
        self._assign(verts, mat)
        return verts

    def sphere(self, r, loc=(0, 0, 0), mat="steel", seg=(16, 10), scale=(1, 1, 1)):
        res = bmesh.ops.create_uvsphere(
            self.bm, u_segments=facet_seg(seg[0], 8),
            v_segments=max(4, int(round(seg[1] * FACET))), radius=r,
        )
        verts = res["verts"]
        self._xform(verts, Matrix.Translation(Vector(loc)) @ Matrix.Diagonal(Vector((*scale, 1.0))))
        self._assign(verts, mat)
        return verts

    def beam(self, p1, p2, w, mat="steel", h=None, taper=None):
        """Square/rect section member between two points."""
        p1, p2 = Vector(p1), Vector(p2)
        d = p2 - p1
        length = d.length
        if length < 1e-6:
            return []
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        h = w if h is None else h
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        m = (
            Matrix.Translation((p1 + p2) * 0.5)
            @ q.to_matrix().to_4x4()
            @ Matrix.Diagonal(Vector((w, h, length, 1.0)))
        )
        self._xform(verts, m)
        self._assign(verts, mat)
        return verts

    def sweep(self, points, r, mat="steel", seg=10, caps=True):
        """Round tube following a polyline (pipes, handrails, cables)."""
        seg = facet_seg(seg, 5)
        pts = [Vector(p) for p in points]
        if len(pts) < 2:
            return []
        rings = []
        nm1 = len(pts) - 1
        for i, p in enumerate(pts):
            if i == 0:
                t = pts[1] - p
            elif i == nm1:
                t = p - pts[i - 1]
            else:
                t = pts[i + 1] - pts[i - 1]
            if t.length < 1e-8:
                t = Vector((0, 0, 1))
            t.normalize()
            up = Vector((0, 0, 1))
            if abs(t.dot(up)) > 0.985:
                up = Vector((1, 0, 0))
            x = t.cross(up).normalized()
            y = t.cross(x).normalized()
            ring = []
            for k in range(seg):
                ang = TAU * k / seg
                ring.append(self.bm.verts.new(p + x * (math.cos(ang) * r) + y * (math.sin(ang) * r)))
            rings.append(ring)
        faces = []
        for i in range(nm1):
            a, b = rings[i], rings[i + 1]
            for k in range(seg):
                k2 = (k + 1) % seg
                try:
                    faces.append(self.bm.faces.new((a[k], a[k2], b[k2], b[k])))
                except ValueError:
                    pass
        if caps:
            for ring in (rings[0], rings[-1]):
                try:
                    faces.append(self.bm.faces.new(ring))
                except ValueError:
                    pass
        verts = [v for ring in rings for v in ring]
        # material by face walk (the new verts only touch new faces)
        idx = self.mi(mat)
        for f in faces:
            f.material_index = idx
        return verts

    def loft(self, sections, mat="steel", caps=True):
        """Skin a list of equal-length point rings (hulls, ducts, nacelles)."""
        rings = [[self.bm.verts.new(p) for p in sec] for sec in sections]
        n = len(sections[0])
        faces = []
        for i in range(len(rings) - 1):
            for k in range(n):
                k2 = (k + 1) % n
                try:
                    faces.append(self.bm.faces.new(
                        (rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])))
                except ValueError:
                    pass
        if caps:
            for ring in (rings[0], rings[-1]):
                try:
                    faces.append(self.bm.faces.new(ring))
                except ValueError:
                    pass
        idx = self.mi(mat)
        for f in faces:
            f.material_index = idx
        return [v for r in rings for v in r]

    def dome(self, center, r, h, axis="Z", mat="steel", seg=20, rings=5, inward=False):
        """Dished/ellipsoidal head. `axis` may be 'X'/'Y'/'Z' or a vector."""
        seg = facet_seg(seg, 8)
        c = Vector(center)
        if isinstance(axis, str):
            axis = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis.upper()]
        q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
        rotm = q.to_matrix()
        rows = []
        for j in range(rings + 1):
            phi = (math.pi / 2) * j / rings
            rad = r * math.cos(phi)
            z = h * math.sin(phi) * (-1 if inward else 1)
            if j == rings:
                rows.append([self.bm.verts.new(c + rotm @ Vector((0, 0, z)))])
            else:
                row = []
                for k in range(seg):
                    ang = TAU * k / seg
                    row.append(self.bm.verts.new(c + rotm @ Vector((math.cos(ang) * rad, math.sin(ang) * rad, z))))
                rows.append(row)
        idx = self.mi(mat)
        for j in range(rings):
            a, b = rows[j], rows[j + 1]
            for k in range(seg):
                k2 = (k + 1) % seg
                try:
                    if len(b) == 1:
                        f = self.bm.faces.new((a[k], a[k2], b[0]))
                    else:
                        f = self.bm.faces.new((a[k], a[k2], b[k2], b[k]))
                    f.material_index = idx
                except ValueError:
                    pass
        return [v for row in rows for v in row]

    def ring(self, center, R, r, mat="steel", axis="Z", seg=24):
        pts = []
        c = Vector(center)
        for k in range(seg + 1):
            ang = TAU * k / seg
            pts.append(c + Vector((math.cos(ang) * R, math.sin(ang) * R, 0)))
        verts = self.sweep(pts, r, mat, seg=8, caps=False)
        if axis != "Z":
            # rotate the whole assembly is not tracked; callers use axis-aligned rings
            pass
        return verts

    # -- meta ---------------------------------------------------------------- #
    def set(self, **kw):
        self.meta.update(kw)
        return self

    # -- bake ---------------------------------------------------------------- #
    def finish(self, smooth=False) -> bpy.types.Object:
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        me = bpy.data.meshes.new(self.aid)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.materials:
            me.materials.append(m)
        if smooth:
            for p in me.polygons:
                p.use_smooth = True
        obj = bpy.data.objects.new(self.aid, me)
        self.coll.objects.link(obj)

        obj["asset_id"] = self.aid
        obj["category"] = self.category
        obj["units"] = "meters"
        obj["forward_axis"] = "-Y"
        obj["up_axis"] = "+Z"
        for k, v in self.meta.items():
            try:
                obj[k] = v
            except Exception:
                obj[k] = str(v)

        me.calc_loop_triangles()
        obj["tri_count"] = len(me.loop_triangles)
        dims = obj.dimensions
        obj["size_x"] = round(dims.x, 3)
        obj["size_y"] = round(dims.y, 3)
        obj["size_z"] = round(dims.z, 3)
        self.obj = obj
        return obj


# --------------------------------------------------------------------------- #
# LOD / collision / export
# --------------------------------------------------------------------------- #


def make_lods(obj: bpy.types.Object, ratios=(0.45, 0.18), min_tris=1500) -> list[bpy.types.Object]:
    """Generate decimated LOD copies named <asset>_LOD1, _LOD2."""
    src = obj.data
    src.calc_loop_triangles()
    if len(src.loop_triangles) < min_tris:
        return []
    out = []
    dg = bpy.context.evaluated_depsgraph_get()
    for level, ratio in enumerate(ratios, start=1):
        mod = obj.modifiers.new(f"lod{level}", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(
            ev, preserve_all_data_layers=False, depsgraph=dg
        )
        obj.modifiers.remove(mod)
        me.name = f"{obj.name}_LOD{level}"
        if not me.materials:
            for m in src.materials:
                me.materials.append(m)
        lod = bpy.data.objects.new(f"{obj.name}_LOD{level}", me)
        lod.matrix_world = obj.matrix_world.copy()
        obj.users_collection[0].objects.link(lod)
        lod["lod_level"] = level
        lod["asset_id"] = obj.name
        me.calc_loop_triangles()
        lod["tri_count"] = len(me.loop_triangles)
        out.append(lod)
    return out


def make_collision(obj: bpy.types.Object) -> bpy.types.Object:
    """Simple box collision hull, base aligned, named <asset>_COL."""
    dims = obj.dimensions
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    zmin = min(v.z for v in bb)
    cx = sum(v.x for v in bb) / 8.0
    cy = sum(v.y for v in bb) / 8.0
    me = bpy.data.meshes.new(f"{obj.name}_COL")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * dims.x * 1.02 + cx
        v.co.y = v.co.y * dims.y * 1.02 + cy
        v.co.z = v.co.z * dims.z * 1.02 + zmin + dims.z / 2
    bm.to_mesh(me)
    bm.free()
    col = bpy.data.objects.new(f"{obj.name}_COL", me)
    col.display_type = "WIRE"
    obj.users_collection[0].objects.link(col)
    col.hide_render = True
    col["collision_for"] = obj.name
    return col


def select_only(objs) -> None:
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
        if bpy.context.view_layer.objects.active is None:
            bpy.context.view_layer.objects.active = o
    bpy.context.view_layer.objects.active = objs[0] if objs else None


def export_glb(path: str, objs, extras=True) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_only(objs)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
        export_cameras=False,
        export_lights=False,
        export_extras=extras,
        export_animations=False,
    )
    return path


def export_fbx(path: str, objs) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    select_only(objs)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        use_mesh_modifiers=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Y",
        axis_up="Z",
        object_types={"MESH", "EMPTY"},
        mesh_smooth_type="FACE",
        use_custom_props=True,
        bake_anim=False,
    )
    return path


# --------------------------------------------------------------------------- #
# material registry (populated by mats.init_materials)
# --------------------------------------------------------------------------- #

MATERIALS: dict[str, bpy.types.Material] = {}


def bind_materials(registry: dict) -> None:
    MATERIALS.clear()
    MATERIALS.update(registry)
