"""Reusable industrial parts.

Every function takes an `Asset` builder (see core.Asset) and appends geometry.
These are the vocabulary pieces: derricks, tanks, valves, handrails, wheels.
"""

from __future__ import annotations

import math

from mathutils import Euler, Matrix, Vector

from .core import TAU, Asset

V = Vector


def xyz(loc):
    """Accept 2- or 3-tuples for positions."""
    if loc is None:
        return (0.0, 0.0, 0.0)
    if len(loc) == 2:
        return (float(loc[0]), float(loc[1]), 0.0)
    return (float(loc[0]), float(loc[1]), float(loc[2]))



# --------------------------------------------------------------------------- #
# small utilities
# --------------------------------------------------------------------------- #


def poly_points(pts, spacing: float) -> list[Vector]:
    """Resample a polyline so no gap exceeds `spacing`."""
    pts = [V(p) for p in pts]
    out = []
    for i in range(len(pts) - 1):
        p, q = pts[i], pts[i + 1]
        seg = (q - p).length
        n = max(1, int(math.ceil(seg / spacing)))
        for k in range(n):
            out.append(p.lerp(q, k / n))
    out.append(pts[-1])
    return out


def axis_rot(axis: str):
    return {
        "X": (0, math.pi / 2, 0),
        "Y": (math.pi / 2, 0, 0),
        "Z": (0, 0, 0),
    }[axis]


# --------------------------------------------------------------------------- #
# civil / structure
# --------------------------------------------------------------------------- #


def pad(a: Asset, size, h=0.2, loc=(0, 0, 0), mat="concrete", chamfer=True):
    x, y, z = xyz(loc)
    a.box((size[0], size[1], h), (x, y, z + h / 2), mat)
    if chamfer:
        a.box((size[0] * 0.94, size[1] * 0.94, 0.05), (x, y, z + h + 0.02), "concrete_dark")


def foundation(a: Asset, size, depth=0.6, loc=(0, 0, 0), mat="concrete"):
    foundation_size = (size[0], size[1], depth)
    pad(a, foundation_size, depth, (loc[0], loc[1], loc[2] - depth), mat, chamfer=False)


def skid(a: Asset, w, d, h=0.28, deck=True, loc=(0, 0, 0),
         mat="steel_dark", mat_deck="galv", lugs=True):
    x, y, z = xyz(loc)
    t = max(0.07, min(w, d) * 0.035)
    a.box((w, t, h), (x, y - d / 2 + t / 2, z + h / 2), mat)
    a.box((w, t, h), (x, y + d / 2 - t / 2, z + h / 2), mat)
    a.box((t, d - 2 * t, h), (x - w / 2 + t / 2, y, z + h / 2), mat)
    a.box((t, d - 2 * t, h), (x + w / 2 - t / 2, y, z + h / 2), mat)
    if deck:
        a.box((w - 2 * t, d - 2 * t, 0.05), (x, y, z + h - 0.03), mat_deck)
    if lugs:
        for sx in (-1, 1):
            for sy in (-1, 1):
                a.box((0.1, 0.1, 0.2), (x + sx * (w / 2 - 0.09), y + sy * (d / 2 - 0.09), z + h + 0.1), mat)


def platform_disc(a: Asset, center, r_in, r_out, mat="galv", seg=16, z_off=0.0):
    """Annular deck around a column/vessel (built from radial planks)."""
    c = V(xyz(center))
    chord = 2 * r_out * math.sin(math.pi / seg) * 0.98
    rr = (r_in + r_out) / 2
    for k in range(seg):
        ang = TAU * (k + 0.5) / seg
        a.box(((r_out - r_in), chord, 0.06),
              (c.x + math.cos(ang) * rr, c.y + math.sin(ang) * rr, c.z + z_off),
              mat, rot=(0, 0, ang))


def grating(a: Asset, size, loc, mat="galv", bars=False):
    """Walkway / floor plate."""
    x, y, z = xyz(loc)
    a.box((size[0], size[1], 0.05), (x, y, z + 0.025), mat)
    if bars:
        n = max(2, int(size[0] / 0.12))
        for i in range(n):
            bx = x - size[0] / 2 + (i + 0.5) * size[0] / n
            a.box((0.03, size[1], 0.02), (bx, y, z + 0.06), "steel_dark")


def handrail(a: Asset, pts, h=1.1, mat="galv", spacing=1.8, toe=False, mid=True):
    pts = [V(p) for p in pts]
    top = [p + V((0, 0, h)) for p in pts]
    a.sweep(top, 0.055, mat, seg=8)
    if mid:
        midp = [p + V((0, 0, h * 0.52)) for p in pts]
        a.sweep(midp, 0.042, mat, seg=8)
    for p in poly_points(pts, spacing):
        a.beam(p, p + V((0, 0, h)), 0.065, mat)
    if toe:
        a.sweep([p + V((0, 0, 0.1)) for p in pts], 0.042, mat, seg=6)


def caged_ladder(a: Asset, base, height, width=0.5, facing=(0, 1, 0),
                 mat="galv", cage=True, cage_from=2.4, rungs=0.3):
    b = V(xyz(base))
    f = V(facing).normalized()
    side = V((-f.y, f.x, 0)).normalized()
    left = b - side * (width / 2)
    right = b + side * (width / 2)
    a.beam(left, left + V((0, 0, height)), 0.078, mat)
    a.beam(right, right + V((0, 0, height)), 0.078, mat)
    n = int(height / rungs)
    for i in range(1, n):
        z = i * rungs
        a.beam(left + V((0, 0, z)), right + V((0, 0, z)), 0.045, mat)
    if cage and height > cage_from:
        R = width * 0.72
        center = b + f * (width * 0.35)
        straps = 5
        zs = []
        z = cage_from
        while z <= height:
            zs.append(z)
            z += 0.62
        for z in zs:
            hoops = []
            for k in range(13):
                ang = math.pi * (k / 12) - math.pi / 2
                hoops.append(center + side * (math.cos(ang) * R) + f * (math.sin(ang) * R) + V((0, 0, z)))
            a.sweep(hoops, 0.022, mat, seg=6, caps=False)
        if zs:
            for k in range(straps):
                ang = math.pi * (k / (straps - 1)) - math.pi / 2
                p0 = center + side * (math.cos(ang) * R) + f * (math.sin(ang) * R) + V((0, 0, zs[0]))
                p1 = center + side * (math.cos(ang) * R) + f * (math.sin(ang) * R) + V((0, 0, zs[-1]))
                a.beam(p0, p1, 0.03, mat)


def stairs(a: Asset, base, width, total_rise, total_run, dir_xy=(0, 1, 0),
           steps=8, mat="galv", rails=True):
    b = V(xyz(base))
    d = V(dir_xy).normalized()
    side = V((-d.y, d.x, 0)).normalized()
    rot = math.atan2(d.y, d.x) + math.pi / 2
    for i in range(steps):
        t = (i + 0.5) / steps
        p = b + d * (total_run * t)
        z = total_rise * (i + 1) / steps
        c = p + V((0, 0, z - 0.025))
        a.box((width, total_run / steps * 1.1, 0.05), (c.x, c.y, c.z), mat, rot=(0, 0, rot))
    # stringers
    for s in (-1, 1):
        off = side * (width / 2 * s)
        a.beam(b + off, b + off + d * total_run + V((0, 0, total_rise)), 0.08, mat)
    if rails:
        for s in (-1, 1):
            off = side * (width / 2 - 0.06) * s
            p0 = b + off
            p1 = b + off + d * total_run + V((0, 0, total_rise))
            a.sweep([p0 + V((0, 0, 1.0)), p1 + V((0, 0, 1.0))], 0.04, mat, seg=8)
            for k in range(0, steps + 1, max(1, steps // 4)):
                t = k / steps
                pp = b + off + d * (total_run * t) + V((0, 0, total_rise * t))
                a.beam(pp, pp + V((0, 0, 1.0)), 0.05, mat)


def spiral_stair(a: Asset, center, r, height, turns=1.2, width=0.9, mat="galv"):
    c = V(xyz(center))
    n = max(8, int(height / 0.25))
    for i in range(n):
        t = i / n
        ang0 = t * turns * TAU
        ang1 = (t + 0.9 / n) * turns * TAU
        z = height * t
        p0 = c + V((math.cos(ang0) * r, math.sin(ang0) * r, z))
        p1 = c + V((math.cos(ang1) * r, math.sin(ang1) * r, z))
        mid = (p0 + p1) / 2
        length = (p1 - p0).length
        rot = math.atan2(p1.y - p0.y, p1.x - p0.x)
        a.box((length, width, 0.04), (mid.x, mid.y, mid.z), mat, rot=(0, 0, rot))
        if i % 3 == 0:
            base = c + V((math.cos(ang0) * (r + width / 2), math.sin(ang0) * (r + width / 2), 0))
            a.beam(base, base + V((0, 0, z + 1.0)), 0.05, mat)
            a.beam(c + V((math.cos(ang0) * (r + width / 2), math.sin(ang0) * (r + width / 2), z + 1.0)),
                   p0 + V((0, 0, 1.0)), 0.04, mat)


# --------------------------------------------------------------------------- #
# pipework & valves
# --------------------------------------------------------------------------- #


def flange(a: Asset, center, axis, dn=0.3, mat="steel", bolts=True):
    c = V(xyz(center))
    rot = axis_rot(axis)
    av = {"X": V((1, 0, 0)), "Y": V((0, 1, 0)), "Z": V((0, 0, 1))}[axis]
    a.cyl(dn * 0.95, 0.06, c, mat, seg=16, rot=rot)
    a.cyl(dn * 0.62, 0.11, c, mat, seg=16, rot=rot)
    if bolts:
        n = 8
        for i in range(n):
            ang = TAU * i / n
            if axis == "X":
                off = V((0, math.cos(ang) * dn * 0.8, math.sin(ang) * dn * 0.8))
            elif axis == "Y":
                off = V((math.cos(ang) * dn * 0.8, 0, math.sin(ang) * dn * 0.8))
            else:
                off = V((math.cos(ang) * dn * 0.8, math.sin(ang) * dn * 0.8, 0))
            a.cyl(0.035, 0.09, c + off, "steel_dark", seg=6, rot=rot)
    return av


def gate_valve(a: Asset, center, axis, dn=0.3, mat="paint_yellow", wheel=True):
    c = V(xyz(center))
    rot = axis_rot(axis)
    a.cyl(dn * 0.72, dn * 1.5, c, mat, seg=16, rot=rot)
    flange(a, c, axis, dn * 1.25, "steel_dark")
    # bonnet + stem
    if axis == "X":
        a.cyl(dn * 0.42, dn * 0.9, c + V((0, 0, dn * 0.9)), mat, seg=12)
        stem_top = c + V((0, 0, dn * 1.9))
        a.cyl(0.05, dn * 1.0, c + V((0, 0, dn * 1.3)), "chrome", seg=8)
    elif axis == "Y":
        a.cyl(dn * 0.42, dn * 0.9, c + V((0, 0, dn * 0.9)), mat, seg=12)
        stem_top = c + V((0, 0, dn * 1.9))
        a.cyl(0.05, dn * 1.0, c + V((0, 0, dn * 1.3)), "chrome", seg=8)
    else:
        a.cyl(dn * 0.42, dn * 0.9, c + V((0, 0, dn * 0.9)), mat, seg=12)
        stem_top = c + V((0, 0, dn * 1.9))
        a.cyl(0.05, dn * 1.0, c + V((0, 0, dn * 1.3)), "chrome", seg=8)
    if wheel:
        R = dn * 0.75
        pts = [stem_top + V((math.cos(TAU * i / 20) * R, math.sin(TAU * i / 20) * R, 0)) for i in range(21)]
        a.sweep(pts, 0.028, "paint_red", seg=6, caps=False)
        for i in range(4):
            ang = TAU * i / 4
            a.beam(stem_top, stem_top + V((math.cos(ang) * R, math.sin(ang) * R, 0)), 0.025, "paint_red")


def gauge(a: Asset, loc, r=0.09, facing=(1, 0, 0), mat="steel"):
    c = V(loc)
    f = V(facing).normalized()
    a.cyl(r, 0.05, c, mat, seg=12, axis=f)
    a.cyl(r * 0.82, 0.055, c + f * 0.005, "paint_white", seg=12, axis=f)
    a.beam(c, c - f * 0.20, 0.02, "chrome")


def pipe_run(a: Asset, pts, r=0.15, mat="pipe_white", supports=False,
             support_mat="steel_dark", support_every=4.0, flanges_every=0):
    pts = [V(p) for p in pts]
    a.sweep(pts, r, mat, seg=12)
    if flanges_every:
        acc = 0.0
        for i in range(len(pts) - 1):
            seg = (pts[i + 1] - pts[i]).length
            d = pts[i + 1] - pts[i]
            d.normalize()
            t = 0.0
            while t < seg:
                p = pts[i] + d * t
                axis = "X" if abs(d.x) > 0.5 else ("Y" if abs(d.y) > 0.5 else "Z")
                flange(a, p, axis, r * 2.2, "steel_dark", bolts=False)
                t += flanges_every
            acc += seg
    if supports:
        for i in range(len(pts) - 1):
            p, q = pts[i], pts[i + 1]
            if abs(q.z - p.z) < 0.01 and p.z > 0.5:
                for t in [k / max(1, int((q - p).length / support_every)) for k in range(1, max(1, int((q - p).length / support_every)))]:
                    c = p.lerp(q, t)
                    a.box((0.18, 0.18, c.z - r), (c.x, c.y, (c.z - r) / 2), support_mat)
                    a.box((0.36, 0.36, 0.05), (c.x, c.y, 0.025), support_mat)


def valve_station(a: Asset, loc, size=1.6, dn=0.35, mat="paint_yellow"):
    x, y, z = xyz(loc)
    pad(a, (size, size * 0.8), 0.15, (x, y, z), "concrete")
    pipe_run(a, [(x - size * 0.7, y, z + 0.9), (x + size * 0.7, y, z + 0.9)], dn, "pipe_yellow")
    gate_valve(a, (x, y, z + 0.9), "X", dn, mat)
    gauge(a, (x + 0.5, y - 0.35, z + 1.1), 0.1, (0, -1, 0))
    a.box((0.3, 0.3, 0.75), (x - 0.6, y, z + 0.38), "steel_dark")
    a.box((0.3, 0.3, 0.75), (x + 0.6, y, z + 0.38), "steel_dark")


# --------------------------------------------------------------------------- #
# tanks & vessels
# --------------------------------------------------------------------------- #


def tank(a: Asset, r, h, loc=(0, 0, 0), roof="cone", shell="paint_white",
         trim="steel", spiral=True, nozzles=True, bands=3, seg=32):
    x, y, z = xyz(loc)
    c = V((x, y, z))
    a.cyl(r, h, c + V((0, 0, h / 2)), shell, seg=seg, cap=False)
    a.cyl(r * 1.005, 0.08, c + V((0, 0, 0.04)), trim, seg=seg)
    for i in range(1, bands + 1):
        zz = h * i / (bands + 1)
        a.cyl(r * 1.012, 0.06, c + V((0, 0, zz)), trim, seg=seg)
    top = c + V((0, 0, h))
    if roof == "cone":
        a.cyl(r * 1.02, 0.05, top, trim, seg=seg)
        a.cyl(r, 0.9 + 0.12 * r, top + V((0, 0, 0.45 + 0.06 * r)), shell, seg=seg, r2=max(0.25, r * 0.12))
        a.cyl(0.28, 0.35, top + V((0, 0, 0.9 + 0.12 * r)), trim, seg=12)
    elif roof == "dome":
        a.dome(top, r, 0.35 * r, "Z", shell, seg=seg, rings=5)
        a.cyl(0.3, 0.3, top + V((0, 0, 0.35 * r)), trim, seg=12)
    elif roof == "floating":
        a.cyl(r * 0.96, 0.35, top + V((0, 0, -0.15)), trim, seg=seg)
        a.cyl(r * 0.55, 0.10, top + V((0, 0, 0.16)), trim, seg=seg)
        for i in range(6):
            ang = TAU * i / 6
            a.beam(top + V((math.cos(ang) * r * 0.35, math.sin(ang) * r * 0.35, 0.2)),
                   top + V((math.cos(ang) * r * 0.9, math.sin(ang) * r * 0.9, 0.2)), 0.06, trim)
    elif roof == "open":
        a.cyl(r * 1.02, 0.06, top, trim, seg=seg)
    if nozzles:
        ang = 0.0
        nz = c + V((math.cos(ang) * r, math.sin(ang) * r, h * 0.28))
        a.cyl(0.13, 0.5, nz, "pipe_white", seg=12, axis=(1, 0, 0))
        flange(a, nz + V((0.25, 0, 0)), "X", 0.18, "steel_dark", bolts=False)
        a.cyl(0.10, 0.4, c + V((0, -r, h * 0.12)), "pipe_white", seg=10, axis=(0, 1, 0))
    # manway
    a.cyl(0.32, 0.30, c + V((0, r * 0.95, h * 0.62)), trim, seg=14, axis=(0, 1, 0))
    if spiral:
        r_st = r + 0.55
        spiral_stair(a, (x, y), r_st, h * 0.92, turns=1.15, width=0.8, mat="galv")
        top_land = c + V((0, 0, h * 0.92))
        a.box((1.1, 1.4, 0.05), (x + r * 0.98, y, h * 0.92), "galv")
        handrail(a, [(x + r * 0.6, y - 0.7, h * 0.92), (x + r * 1.3, y - 0.7, h * 0.92),
                     (x + r * 1.3, y + 0.7, h * 0.92), (x + r * 0.6, y + 0.7, h * 0.92)],
                 h=1.0, mat="galv")
        _ = top_land


def vessel(a: Asset, r, length, loc=(0, 0, 0), axis="X", shell="paint_white",
           saddles=2, heads=True, trim="steel", seg=24):
    c = V(loc)
    rot = axis_rot(axis)
    av = {"X": V((1, 0, 0)), "Y": V((0, 1, 0)), "Z": V((0, 0, 1))}[axis]
    a.cyl(r, length, c, shell, seg=seg, rot=rot)
    if heads:
        a.dome(c + av * (length / 2), r, r * 0.55, av, shell, seg=seg, rings=4)
        a.dome(c - av * (length / 2), r, r * 0.55, av, shell, seg=seg, rings=4)
    # nozzles on top
    for t in (-0.28, 0.28):
        nz = c + av * (length * t) + V((0, 0, r))
        a.cyl(0.14, 0.45, nz, trim, seg=12)
        flange(a, nz + V((0, 0, 0.24)), "Z", 0.2, trim, bolts=False)
    # instrument
    gauge(a, c + av * (length * 0.1) + V((0, 0, r + 0.3)), 0.1)
    a.beam(c + av * (length * 0.1) + V((0, 0, r)), c + av * (length * 0.1) + V((0, 0, r + 0.32)), 0.04, trim)
    for i in range(saddles):
        t = -0.32 + 0.64 * (i / max(1, saddles - 1) if saddles > 1 else 0.5)
        sc = c + av * (length * t)
        a.box((0.5, r * 1.5, r * 0.75), (sc.x, sc.y, sc.z - r * 0.62), "concrete_dark")
        a.box((0.35, r * 1.7, 0.12), (sc.x, sc.y, sc.z - r * 0.98), "steel_dark")


def separator_package(a: Asset, loc=(0, 0, 0), scale=1.0):
    x, y, z = xyz(loc)
    s = scale
    skid(a, 6.0 * s, 3.0 * s, 0.3, loc=(x, y, z))
    vessel(a, 0.85 * s, 4.6 * s, (x, y, z + 1.5 * s), "X", "paint_white", 2)
    pipe_run(a, [(x - 2.2 * s, y, z + 2.4 * s), (x - 2.2 * s, y + 1.2 * s, z + 2.4 * s),
                (x - 2.2 * s, y + 1.2 * s, z + 0.6 * s)], 0.16 * s)
    gate_valve(a, (x - 2.2 * s, y + 0.6 * s, z + 2.4 * s), "Y", 0.22 * s)
    a.box((0.6 * s, 0.6 * s, 1.2 * s), (x + 2.4 * s, y + 1.0 * s, z + 0.9 * s), "paint_grey")
    a.cyl(0.1 * s, 2.0 * s, (x + 2.4 * s, y + 1.0 * s, z + 1.9 * s), "steel_dark", seg=10)


# --------------------------------------------------------------------------- #
# derricks / masts / cranes
# --------------------------------------------------------------------------- #


def derrick(a: Asset, base, height, base_w, top_w, mat="paint_red",
            bays=8, ladder=True, crown=True, setback=True):
    b = V(xyz(base))
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    levels = []
    for i in range(bays + 1):
        t = i / bays
        w = base_w + (top_w - base_w) * t
        z = height * t
        pts = [b + V((cx * w / 2, cy * w / 2, z)) for cx, cy in corners]
        levels.append(pts)
    leg = 0.16 + 0.10 * (base_w / 10)
    for i in range(bays):
        lo, hi = levels[i], levels[i + 1]
        for k in range(4):
            a.beam(lo[k], hi[k], leg * 0.75, mat)
            k2 = (k + 1) % 4
            a.beam(lo[k], hi[k2], 0.09, mat)   # X brace
            a.beam(lo[k2], hi[k], 0.09, mat)
        for k in range(4):
            k2 = (k + 1) % 4
            a.beam(lo[k], lo[k2], 0.10, mat)
    # crown platform
    top = levels[-1]
    for k in range(4):
        k2 = (k + 1) % 4
        a.beam(top[k], top[k2], 0.14, mat)
    plat = b + V((0, 0, height + 0.3))
    a.box((top_w + 0.8, top_w + 0.8, 0.12), (plat.x, plat.y, plat.z), "galv")
    if crown:
        cb = plat + V((0, 0, 0.45))
        a.box((1.0, 0.7, 0.55), (cb.x, cb.y, cb.z), "steel_dark")
        for s in (-1, 1):
            a.cyl(0.26, 0.12, (cb.x + s * 0.42, cb.y, cb.z), "steel_light", seg=14, rot=(0, math.pi / 2, 0))
        a.beam(plat + V((0, 0, 0.12)), cb, 0.12, "steel_dark")
    # travelling block + hook
    tb = b + V((0, 0, height * 0.62))
    a.box((0.7, 0.5, 0.5), (tb.x, tb.y, tb.z), "paint_yellow")
    a.beam(tb, tb + V((0, 0, -0.45)), 0.12, "steel_dark")
    a.sweep([tb + V((0, 0, 0.3)), b + V((0, 0, height + 0.5))], 0.03, "steel_dark", seg=6)
    # ladder + stairs on one face
    if ladder:
        caged_ladder(a, b + V((base_w / 2 + 0.25, 0, 0)), height * 0.92, 0.55, (0, 1, 0))
    if setback:
        # racked drill pipe standing in the derrick
        for i in range(6):
            px = b.x - base_w * 0.28 + i * 0.34
            py = b.y - base_w * 0.05
            a.cyl(0.075, height * 0.55, (px, py, height * 0.28), "rust_patchy", seg=8)


def mast(a: Asset, base, height, width, mat="paint_orange", braces=5):
    """Cantilever / A-frame mast used on land rigs and mobile rigs."""
    b = V(xyz(base))
    apex = b + V((0, 0, height))
    legs = [b + V((-width / 2, -0.5, 0)), b + V((width / 2, -0.5, 0)),
            b + V((-width / 2 * 0.55, 0.9, 0)), b + V((width / 2 * 0.55, 0.9, 0))]
    tops = [apex + V((-0.7, -0.2, 0)), apex + V((0.7, -0.2, 0)),
            apex + V((-0.5, 0.4, 0)), apex + V((0.5, 0.4, 0))]
    for lo, hi in zip(legs, tops):
        a.beam(lo, hi, 0.2, mat)
    for i in range(1, braces + 1):
        t = i / (braces + 1)
        seg = [lo.lerp(hi, t) for lo, hi in zip(legs, tops)]
        for k in range(4):
            k2 = (k + 1) % 4
            a.beam(seg[k], seg[k2], 0.1, mat)
            a.beam(seg[k].lerp(seg[k2], 0.0), seg[k2].lerp(seg[k], 0.0), 0.07, mat)
        a.beam(seg[0], seg[2], 0.07, mat)
    a.box((1.6, 1.0, 0.18), (apex.x, apex.y, apex.z), "galv")
    a.box((0.9, 0.6, 0.5), (apex.x, apex.y, apex.z + 0.3), "steel_dark")


def pedestal_crane(a: Asset, base, height, boom_len, slew=0.0, mat="paint_yellow", lattice=True):
    b = V(xyz(base))
    a.cyl(1.3, 0.5, b + V((0, 0, 0.25)), "steel_dark", seg=20)
    a.cyl(0.85, height, b + V((0, 0, height / 2)), mat, seg=16)
    for i in range(4):
        ang = TAU * i / 4 + math.pi / 4
        a.box((0.16, 0.16, height), (b.x + math.cos(ang) * 0.85 * 0.7, b.y + math.sin(ang) * 0.85 * 0.7, height / 2), "steel_dark")
    # A-frame
    a.beam(b + V((0, 0, height)), b + V((0.8, 0, height + 1.6)), 0.14, mat)
    a.beam(b + V((0, 0, height)), b + V((-0.8, 0, height + 1.6)), 0.14, mat)
    # cab
    a.box((1.5, 1.4, 1.4), (b.x + 0.55, b.y, height + 0.55), "paint_yellow", bevel=0.06)
    a.box((0.9, 0.9, 0.9), (b.x + 0.55, b.y, height + 0.55), "glass_dark")
    # boom
    ang = slew
    tip = b + V((math.cos(ang) * boom_len, math.sin(ang) * boom_len, height + boom_len * 0.55))
    root = b + V((0, 0, height + 0.4))
    if lattice:
        perp = V((-math.sin(ang), math.cos(ang), 0)) * 0.45
        a.beam(root + perp, tip + perp * 0.5, 0.12, mat)
        a.beam(root - perp, tip - perp * 0.5, 0.12, mat)
        n = 9
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            p0 = root.lerp(tip, t0); p1 = root.lerp(tip, t1)
            a.beam(p0 + perp * (1 - t0 * 0.5), p1 - perp * (1 - t1 * 0.5), 0.06, mat)
            a.beam(p0 - perp * (1 - t0 * 0.5), p1 + perp * (1 - t1 * 0.5), 0.06, mat)
            a.beam(p1 + perp * (1 - t1 * 0.5), p1 - perp * (1 - t1 * 0.5), 0.05, mat)
    else:
        a.beam(root, tip, 0.55, mat)
    # hook + block
    a.sweep([tip, tip + V((0, 0, -6.0))], 0.035, "steel_dark", seg=6)
    a.box((0.45, 0.35, 0.65), (tip.x, tip.y, tip.z - 6.2), "paint_orange")
    # counter-jib
    back = b + V((-math.cos(ang) * 5.0, -math.sin(ang) * 5.0, height + 0.6))
    a.beam(root, back, 0.35, mat)
    a.box((1.6, 1.2, 1.0), (back.x, back.y, back.z - 0.4), "concrete_dark")


def flare_stack(a: Asset, base, height, mat="paint_grey", derrick_style=True):
    b = V(xyz(base))
    pad(a, (4.5, 4.5), 0.3, (b.x, b.y, b.z), "concrete")
    if derrick_style:
        w = 2.4
        for i in range(3):
            ang = TAU * i / 3
            a.beam(b + V((math.cos(ang) * w / 2, math.sin(ang) * w / 2, 0.3)),
                   b + V((math.cos(ang) * 0.45, math.sin(ang) * 0.45, height)), 0.14, mat)
        for i in range(1, 6):
            z = height * i / 6
            rr = w / 2 * (1 - z / height * 0.85) + 0.2
            for k in range(3):
                ang = TAU * k / 3
                a.beam(b + V((math.cos(ang) * rr, math.sin(ang) * rr, z)),
                       b + V((math.cos(ang + TAU / 3) * rr, math.sin(ang + TAU / 3) * rr, z)), 0.07, mat)
    else:
        a.cyl(0.6, height, b + V((0, 0, height / 2)), mat, seg=16)
    # tip / flare burner
    tip = b + V((0, 0, height))
    a.cyl(0.7, 1.2, tip, "steel_dark", seg=16)
    for i in range(3):
        ang = TAU * i / 3
        a.cyl(0.1, 0.9, tip + V((math.cos(ang) * 0.95, math.sin(ang) * 0.95, 0.5)), "paint_red", seg=8)
        a.sphere(0.16, tip + V((math.cos(ang) * 0.95, math.sin(ang) * 0.95, 1.0)), "emit_amber", seg=(8, 5))
    # knockout drum + riser
    vessel(a, 0.75, 2.2, (b.x + 2.2, b.y, b.z + 1.2), "X", "paint_grey", 2)
    pipe_run(a, [(b.x + 1.2, b.y, b.z + 1.0), (b.x + 0.2, b.y, b.z + 1.0),
                (b.x + 0.2, b.y, b.z + height * 0.85)], 0.22, "pipe_white", supports=False)


# --------------------------------------------------------------------------- #
# offshore / marine parts
# --------------------------------------------------------------------------- #


def helideck(a: Asset, loc, r=9.0, mat="paint_grey", support=True):
    c = V(xyz(loc))
    a.cyl(r, 0.40, c, mat, seg=36)
    # perimeter band + aiming circle (rings, not discs — an overlaid disc hides the deck)
    a.ring(c + V((0, 0, 0.21)), r * 0.975, 0.085, "paint_yellow", seg=36)
    a.ring(c + V((0, 0, 0.205)), r * 0.42, 0.05, "paint_white", seg=32)
    # H marking
    a.box((0.55, r * 1.1, 0.03), (c.x - r * 0.30, c.y, c.z + 0.21), "paint_white")
    a.box((0.55, r * 1.1, 0.03), (c.x + r * 0.30, c.y, c.z + 0.21), "paint_white")
    a.box((r * 0.62, 0.55, 0.03), (c.x, c.y, c.z + 0.21), "paint_white")
    # perimeter net + lights
    net = [c + V((math.cos(TAU * i / 36) * r * 1.06, math.sin(TAU * i / 36) * r * 1.06, 0.18)) for i in range(37)]
    a.sweep(net, 0.06, "safety_net", seg=6, caps=False)
    for i in range(12):
        ang = TAU * i / 12
        a.cyl(0.10, 0.18, c + V((math.cos(ang) * r * 1.06, math.sin(ang) * r * 1.06, 0.02)), "emit_green", seg=8)
    if support:
        for i in range(6):
            ang = TAU * i / 6
            a.beam(c + V((math.cos(ang) * r * 0.8, math.sin(ang) * r * 0.8, -0.1)),
                   c + V((math.cos(ang) * r * 0.3, math.sin(ang) * r * 0.3, -2.2)), 0.2, "steel_dark")


def lifeboat(a: Asset, loc, rot=(0, 0, 0), mat="paint_orange"):
    c = V(loc)
    rotm = Euler(rot, "XYZ").to_matrix()
    # capsule hull built from a scaled sphere + a cylinder mid
    a.cyl(1.0, 4.2, c, mat, seg=16, rot=(0, math.pi / 2, 0))
    a.sphere(1.0, c + V((2.1, 0, 0)), mat, seg=(14, 8), scale=(1.0, 1.0, 1.0))
    a.sphere(1.0, c + V((-2.1, 0, 0)), mat, seg=(14, 8), scale=(1.0, 1.0, 1.0))
    a.box((3.2, 0.9, 0.25), (c.x, c.y, c.z + 1.0), "paint_white")
    a.beam(c + V((-1.6, 0, 1.1)), c + V((1.6, 0, 1.1)), 0.08, "steel_dark")


def heli_pad_tower(a: Asset, loc, height):
    c = V(loc)
    for i in range(4):
        ang = TAU * i / 4 + math.pi / 4
        a.beam(c + V((math.cos(ang) * 2.2, math.sin(ang) * 2.2, 0)),
               c + V((math.cos(ang) * 1.4, math.sin(ang) * 1.4, height)), 0.22, "steel_dark")


# --------------------------------------------------------------------------- #
# vehicles parts
# --------------------------------------------------------------------------- #


def wheel(a: Asset, center, r, width, axis="X", tyre="rubber", rim="steel_light", spokes=5):
    """Road wheel: tyre, sidewall, spoked rim, hub, lug nuts. Axis = rotation axis."""
    c = V(xyz(center))
    rot = axis_rot(axis)
    av = {"X": V((1, 0, 0)), "Y": V((0, 1, 0)), "Z": V((0, 0, 1))}[axis]
    ref = V((0, 1, 0)) if axis != "Y" else V((1, 0, 0))
    e1 = (ref - av * ref.dot(av)).normalized()
    e2 = av.cross(e1)
    a.cyl(r, width, c, tyre, seg=22, rot=rot)
    a.cyl(r * 0.80, width * 1.03, c, "steel_dark", seg=22, rot=rot)
    a.cyl(r * 0.56, width * 1.07, c, rim, seg=20, rot=rot)
    for s in (-1, 1):
        face = c + av * (width * 0.55 * s)
        for i in range(spokes):
            ang = TAU * i / spokes
            rad = e1 * math.cos(ang) + e2 * math.sin(ang)
            a.beam(face + rad * r * 0.14, face + rad * r * 0.48, 0.06, rim)
    a.cyl(r * 0.16, width * 1.1, c, "chrome", seg=12, rot=rot)
    for i in range(6):
        ang = TAU * i / 6
        rad = e1 * math.cos(ang) + e2 * math.sin(ang)
        a.cyl(0.028, width * 1.05, c + rad * r * 0.33, "steel_dark", seg=6, rot=rot)


def fender_arch(a: Asset, center, r, width, mat="paint_white", seg=9):
    """Wheel-arch flare: a band of boxes following the upper half of the wheel."""
    c = V(xyz(center))
    chord = r * math.pi / seg
    for i in range(seg):
        ang = math.pi * (i + 0.5) / seg
        a.box((width * 1.12, chord * 1.18, 0.055),
              (c.x, c.y + math.cos(ang) * r, c.z + math.sin(ang) * r),
              mat, rot=(ang + math.pi / 2, 0, 0))


def body_profile(w, zb, zt, tuck=0.80, shoulder=0.90, top_w=None):
    """Chamfered cross-section for lofted vehicle bodies: (x, z) ring of 8 points."""
    h = max(zt - zb, 1e-3)
    tw = w * shoulder if top_w is None else top_w
    return [
        (-w * tuck, zb),
        (-w, zb + h * 0.30),
        (-w, zt - h * 0.35),
        (-tw, zt),
        (tw, zt),
        (w, zt - h * 0.35),
        (w, zb + h * 0.30),
        (w * tuck, zb),
    ]


def shell(a: Asset, stations, mat="paint_white", caps=True):
    """Loft a run of chamfered sections into one sculpted body."""
    sections = [[(x, y, z) for (x, z) in ring] for (y, ring) in stations]
    a.loft(sections, mat, caps=caps)


def truck_wheel(a: Asset, center, r=0.55, width=0.4, axis="X"):
    wheel(a, center, r, width, axis)


def chassis(a: Asset, length, width, z=0.55, wheel_r=0.55, axles=(0.32, -0.28),
            mat="steel_dark", dual=True):
    a.box((width, length, 0.22), (0, 0, z), mat)
    for t in axles:
        ay = length * t
        for s in (-1, 1):
            truck_wheel(a, (s * (width / 2 - 0.05), ay, wheel_r), wheel_r, 0.38)
            if dual:
                truck_wheel(a, (s * (width / 2 + 0.32), ay, wheel_r), wheel_r, 0.36)


def truck_cab(a: Asset, loc, width=2.4, length=2.2, height=2.6, mat="paint_white", sleeper=False):
    """Cab-over-engine truck cab with glazing, grille, bumper, mirrors and steps."""
    x, y, z = xyz(loc)
    hw = width / 2
    y0, y1 = y - length / 2, y + length / 2
    shell(a, [
        (y0, body_profile(hw * 0.93, z + 0.03, z + height * 0.985, 0.90, 0.88, hw * 0.80)),
        (y0 + 0.14, body_profile(hw, z, z + height, 0.88, 0.90, hw * 0.84)),
        (y1 - 0.14, body_profile(hw, z, z + height, 0.88, 0.92, hw * 0.86)),
        (y1, body_profile(hw * 0.93, z + 0.03, z + height * 0.99, 0.90, 0.90, hw * 0.82)),
    ], mat)
    # windshield + side glass
    a.box((width * 0.88, 0.07, height * 0.34), (x, y - length / 2 - 0.02, z + height * 0.71), "glass_dark")
    for s in (-1, 1):
        a.box((0.07, length * 0.5, height * 0.28), (x + s * (width / 2 + 0.015), y + length * 0.06, z + height * 0.71), "glass_dark")
        a.box((0.04, 0.05, height * 0.5), (x + s * (width / 2 + 0.03), y + length * 0.26, z + height * 0.42), "steel_dark")
        a.box((0.05, 0.24, 0.06), (x + s * (width / 2 + 0.05), y - length * 0.02, z + height * 0.46), "chrome")
        a.beam((x + s * width / 2, y - length * 0.36, z + height * 0.82),
               (x + s * (width / 2 + 0.38), y - length * 0.44, z + height * 0.88), 0.05, "steel_dark")
        a.box((0.06, 0.20, 0.34), (x + s * (width / 2 + 0.40), y - length * 0.44, z + height * 0.80), "steel_dark")
    # grille slats
    for i in range(3):
        a.box((width * 0.78, 0.06, 0.08), (x, y - length / 2 - 0.03, z + height * 0.26 + i * 0.16), "steel_dark")
    # bumper + fog lights
    a.box((width * 1.05, 0.30, 0.34), (x, y - length / 2 - 0.13, z + 0.27), "steel_dark", bevel=0.03)
    for s in (-1, 1):
        a.box((0.30, 0.06, 0.16), (x + s * width * 0.36, y - length / 2 - 0.29, z + 0.33), "emit_white")
    # sun visor + roof markers
    a.box((width * 1.04, 0.44, 0.08), (x, y - length / 2 - 0.17, z + height * 0.95), mat)
    for i in range(5):
        a.box((0.13, 0.08, 0.07), (x - width * 0.30 + i * width * 0.15,
                                   y - length / 2 + 0.12, z + height + 0.02), "emit_amber")
    # steps
    for i in range(2):
        a.box((0.48, 0.32, 0.05), (x + width / 2 - 0.02, y - length * 0.08, z + 0.16 + i * 0.26), "galv")
    if sleeper:
        a.box((width * 0.97, length * 0.72, height * 0.9), (x, y + length * 0.80, z + height * 0.45), mat, bevel=0.08)
        a.box((width * 0.66, 0.06, height * 0.2), (x, y + length * 1.16, z + height * 0.70), "glass_dark")


def flatbed(a: Asset, loc, length, width, mat="steel_dark", deck="wood"):
    x, y, z = xyz(loc)
    a.box((width, length, 0.14), (x, y, z + 0.07), deck)
    a.box((0.08, length, 0.3), (x - width / 2, y, z + 0.05), mat)
    a.box((0.08, length, 0.3), (x + width / 2, y, z + 0.05), mat)


def pipe_load(a: Asset, loc, length, count=12, r=0.11, mat="rust_patchy"):
    x, y, z = xyz(loc)
    cols = max(1, int(round(count / 3)))
    for i in range(count):
        layer = i // cols
        idx = i % cols
        a.cyl(r, length, (x - (cols - 1) * r * 2.2 / 2 + idx * r * 2.2,
                          y, z + r + layer * r * 1.85), mat, seg=8, cap=True)


def container(a: Asset, loc, size=(2.4, 6.0, 2.6), mat="paint_blue", rot=0.0):
    x, y, z = xyz(loc)
    a.box(size, (x, y, z + size[2] / 2), mat, rot=(0, 0, rot), bevel=0.05)
    # corrugation
    n = int(size[1] / 0.35)
    for i in range(1, n):
        yy = y - size[1] / 2 + i * size[1] / n
        a.box((size[0] * 1.01, 0.05, size[2] * 0.92), (x, yy, z + size[2] / 2), "steel_dark", rot=(0, 0, rot))
    a.box((size[0] * 0.6, 0.08, size[2] * 0.8), (x, y + size[1] / 2, z + size[2] / 2), "steel_dark", rot=(0, 0, rot))


def generator_set(a: Asset, loc=(0, 0, 0), mat="paint_green"):
    x, y, z = xyz(loc)
    skid(a, 4.2, 2.2, 0.25, loc=(x, y, z))
    a.box((3.0, 1.5, 1.3), (x, y - 0.1, z + 1.0), mat, bevel=0.05)
    a.box((0.9, 1.4, 1.2), (x + 1.8, y - 0.1, z + 0.95), "steel_dark")
    a.cyl(0.28, 1.4, (x + 1.8, y - 0.1, z + 1.55), "steel_dark", seg=10)
    a.box((0.6, 0.6, 0.5), (x - 1.4, y, z + 1.1), "paint_yellow")
    gauge(a, (x - 1.0, y + 0.8, z + 1.4), 0.09, (0, 1, 0))


def compressor_package(a: Asset, loc=(0, 0, 0), mat="paint_blue"):
    x, y, z = xyz(loc)
    skid(a, 5.0, 2.6, 0.3, loc=(x, y, z))
    a.box((1.6, 1.6, 1.5), (x - 1.2, y, z + 1.1), mat, bevel=0.05)
    a.cyl(0.55, 1.8, (x + 0.9, y, z + 1.2), "steel_dark", seg=16, rot=(0, math.pi / 2, 0))
    a.cyl(0.45, 1.0, (x + 1.9, y, z + 2.2), "steel_dark", seg=12)
    pipe_run(a, [(x + 1.9, y, z + 2.7), (x + 1.9, y + 1.4, z + 2.7), (x + 1.9, y + 1.4, z + 0.5)], 0.14, "pipe_yellow")
    gauge(a, (x - 1.2, y + 0.9, z + 1.8), 0.1, (0, 1, 0))


# --------------------------------------------------------------------------- #
# misc props
# --------------------------------------------------------------------------- #


def floodlight(a: Asset, base, height=12.0, n_lights=4, mat="galv"):
    b = V(xyz(base))
    a.cyl(0.22, height, b + V((0, 0, height / 2)), mat, seg=10)
    a.cyl(0.5, 0.3, b + V((0, 0, 0.15)), "concrete_dark", seg=12)
    head = b + V((0, 0, height))
    a.box((2.6, 0.35, 0.25), (head.x, head.y, head.z), "steel_dark")
    for i in range(n_lights):
        off = (i - (n_lights - 1) / 2) * 0.55
        a.box((0.45, 0.3, 0.4), (head.x + off, head.y + 0.18, head.z + 0.05), "steel_dark")
        a.box((0.38, 0.06, 0.32), (head.x + off, head.y + 0.35, head.z + 0.05), "emit_white")


def fence(a: Asset, start, end, height=2.0, spacing=2.5, mat="galv", barbed=True):
    p0, p1 = V(xyz(start)), V(xyz(end))
    d = (p1 - p0)
    n = max(1, int(d.length / spacing))
    for i in range(n + 1):
        p = p0 + d * (i / n)
        a.beam(p, p + V((0, 0, height)), 0.07, mat)
    pts = [p0 + V((0, 0, h)) for h in (height, height * 0.55, 0.25)]
    if barbed:
        pts.insert(0, p0 + V((0, 0, height + 0.25)))
    for y in pts:
        a.sweep([(p0.x, p0.y, y.z), (p1.x, p1.y, y.z)], 0.018, mat, seg=5)


def barrel(a: Asset, loc, mat="paint_red", r=0.29, h=0.88):
    c = V(loc)
    a.cyl(r, h, c + V((0, 0, h / 2)), mat, seg=14)
    for zz in (0.28, 0.58, 0.82):
        a.cyl(r * 1.04, 0.05, c + V((0, 0, h * zz)), "steel_dark", seg=14)


def gas_cylinder(a: Asset, loc, mat="paint_green", h=1.4, r=0.22):
    c = V(loc)
    a.cyl(r, h, c + V((0, 0, h / 2)), mat, seg=14)
    a.dome(c + V((0, 0, h)), r, r * 0.7, "Z", mat, seg=14, rings=4)
    a.cyl(0.07, 0.18, c + V((0, 0, h + r * 0.65)), "brass", seg=8)


def ac_unit(a: Asset, loc, size=(1.1, 0.8, 0.7), mat="galv"):
    x, y, z = xyz(loc)
    a.box(size, (x, y, z + size[2] / 2), mat, bevel=0.03)
    a.cyl(size[2] * 0.36, 0.05, (x, y + size[1] / 2, z + size[2] / 2), "steel_dark", seg=14, rot=(math.pi / 2, 0, 0))


def antenna(a: Asset, base, height=8.0):
    b = V(xyz(base))
    a.cyl(0.06, height, b + V((0, 0, height / 2)), "galv", seg=6)
    for i in range(3):
        z = height * (0.55 + i * 0.15)
        a.box((1.2 - i * 0.3, 0.05, 0.05), (b.x, b.y, z), "galv")
    a.sphere(0.12, b + V((0, 0, height)), "emit_red", seg=(8, 5))
