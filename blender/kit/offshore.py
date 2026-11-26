"""Offshore structures and marine vessels.

Convention: for floating/fixed offshore assets the origin is the **waterline**
(z = 0 = mean sea level), with submerged structure at negative z. The manifest
marks these with `placement: "waterline"`.
"""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector


# --------------------------------------------------------------------------- #
# marine helpers
# --------------------------------------------------------------------------- #


def ship_hull(a: Asset, loc, length, beam, depth, mat="paint_blue",
              bow=0.22, stern="transom", keel=0.18):
    """Lofted stylised hull, waterline at z=0 of `loc`."""
    x, y, z = P.xyz(loc)
    stations = 9
    sections = []
    for i in range(stations + 1):
        t = i / stations
        # taper towards bow (x = +L/2)
        if t > 0.62:
            k = (t - 0.62) / 0.38
            b = beam * (1.0 - 0.88 * k ** 1.6)
            d = depth * (1.0 - 0.20 * k ** 2)
        else:
            b = beam
            d = depth
        cx = x - length / 2 + length * t
        prof = [
            (cx, y - b / 2, z - depth * keel * 0.2),
            (cx, y - b / 2, z + d * 0.62),
            (cx, y - b * 0.30, z + d),
            (cx, y + b * 0.30, z + d),
            (cx, y + b / 2, z + d * 0.62),
            (cx, y + b / 2, z - depth * keel * 0.2),
            (cx, y, z - depth * keel),
        ]
        sections.append(prof)
    a.loft(sections, mat)
    # deck plate
    a.box((length * 0.80, beam * 0.98, 0.12), (x - length * 0.06, y, z + depth), "steel_dark")
    return z + depth


def deckhouse(a: Asset, loc, w, l, h, decks=3, mat="paint_white", windows=True):
    x, y, z = P.xyz(loc)
    a.box((w, l, h), (x, y, z + h / 2), mat, bevel=0.05)
    if windows:
        for d in range(decks):
            zz = z + h * (d + 0.55) / decks
            a.box((w * 1.005, l * 0.92, h / decks * 0.34), (x, y, zz), "glass_dark")
            a.box((w * 0.92, l * 1.005, h / decks * 0.30), (x, y, zz), "glass_dark")
    # bridge wings
    a.box((w * 1.5, l * 0.35, 0.3), (x, y + l * 0.18, z + h * 0.92), mat)
    a.box((w * 1.5, l * 0.34, 1.0), (x, y + l * 0.18, z + h * 0.92 + 0.6), "glass_dark")
    # roof kit
    a.box((0.8, 0.8, 0.9), (x - w * 0.2, y - l * 0.2, z + h + 0.45), "steel_dark")
    a.cyl(0.5, 0.3, (x + w * 0.25, y - l * 0.15, z + h + 0.15), "paint_white", seg=12)
    return z + h


def pedestal_pair(a: Asset, loc, beam, height=18.0, boom=24.0):
    x, y, z = P.xyz(loc)
    P.pedestal_crane(a, (x, y + beam * 0.32, z), height, boom, slew=math.pi / 2, mat="paint_yellow")
    P.pedestal_crane(a, (x, y - beam * 0.32, z), height, boom, slew=-math.pi / 2, mat="paint_yellow")


def lifeboat_pair(a: Asset, loc, beam, z_off=0.0):
    x, y, z = P.xyz(loc)
    for s in (-1, 1):
        P.lifeboat(a, (x + s * 2.0, y + beam * 0.5, z + z_off), mat="paint_orange")
        a.beam((x + s * 2.0, y + beam * 0.44, z + z_off + 1.2),
               (x + s * 2.0, y + beam * 0.40, z + z_off + 5.0), 0.16, "steel_dark")
        a.beam((x + s * 2.0, y + beam * 0.40, z + z_off + 5.0),
               (x + s * 2.0, y + beam * 0.20, z + z_off + 3.4), 0.12, "steel_dark")


def moonpool(a: Asset, loc, w, l):
    x, y, z = P.xyz(loc)
    a.box((w, l, 0.4), (x, y, z), "steel_dark")
    a.box((w * 0.55, l * 0.8, 0.42), (x, y, z + 0.05), "oil")


def truss_leg(a: Asset, base, top, size=2.4, bays=8, mat="paint_yellow"):
    """Square lattice leg with X bracing (jack-up leg)."""
    b, t = V(base), V(top)
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    levels = []
    for i in range(bays + 1):
        k = i / bays
        c = b.lerp(t, k)
        s = size * (1.0 - 0.25 * k)
        levels.append([c + V((cx * s / 2, cy * s / 2, 0)) for cx, cy in corners])
    for i in range(bays):
        lo, hi = levels[i], levels[i + 1]
        for j in range(4):
            j2 = (j + 1) % 4
            a.beam(lo[j], hi[j], size * 0.13, mat)
            a.beam(lo[j], hi[j2], size * 0.07, mat)
            a.beam(lo[j2], hi[j], size * 0.07, mat)
            a.beam(lo[j], lo[j2], size * 0.07, mat)
    return levels[-1]


# --------------------------------------------------------------------------- #
# drilling units
# --------------------------------------------------------------------------- #


def jackup_rig(a: Asset):
    """Three-leg jack-up, triangular hull, cantilevered 40 m derrick."""
    a.set(placement="waterline", role="drilling")
    hull_z = 12.0
    L, B = 62.0, 56.0
    # --- triangular hull -------------------------------------------------- #
    pts = [(-L / 2, -B / 3), (L / 2, -B / 3), (0, B * 0.62)]
    a.box((L, B * 0.72, 1.0), (0, -B * 0.05, hull_z + 0.5), "steel_dark")
    a.box((L * 0.96, B * 0.68, 5.0), (0, -B * 0.05, hull_z - 2.5), "paint_blue", bevel=0.1)
    a.box((L * 0.9, B * 0.62, 1.2), (0, -B * 0.05, hull_z + 8.0), "paint_blue", bevel=0.06)
    # bow sponson (triangle front)
    a.box((L * 0.5, B * 0.40, 5.0), (0, B * 0.34, hull_z - 2.5), "paint_blue", bevel=0.1)
    # deck edge stripe
    a.box((L * 0.97, 0.5, 0.35), (0, -B * 0.05 + B * 0.34, hull_z + 8.9), "paint_yellow")

    # --- legs ------------------------------------------------------------- #
    leg_pos = [(L * 0.40, -B * 0.30), (-L * 0.40, -B * 0.30), (0, B * 0.52)]
    for (lx, ly) in leg_pos:
        truss_leg(a, (lx, ly, -46.0), (lx, ly, hull_z + 26.0), 3.2, 14)
        # spud can
        a.cyl(5.0, 3.0, (lx, ly, -47.5), "paint_yellow", seg=20, r2=2.6)
        a.cyl(5.2, 0.6, (lx, ly, -46.2), "steel_dark", seg=20)
        # jacking house
        a.box((6.0, 6.0, 5.0), (lx, ly, hull_z + 8.0), "paint_orange", bevel=0.06)
        for i in range(4):
            a.cyl(0.55, 1.6, (lx - 1.8 + i * 1.2, ly + 3.3, hull_z + 6.4), "steel_dark", seg=10, rot=(math.pi / 2, 0, 0))

    # --- derrick + cantilever --------------------------------------------- #
    a.box((26.0, 16.0, 1.4), (0, -B * 0.16, hull_z + 9.4), "steel_dark")
    for sx in (-1, 1):
        a.beam((sx * 12.0, -B * 0.16 - 7.0, hull_z + 10.1), (sx * 10.0, -B * 0.16 + 6.0, hull_z + 10.1), 0.35, "paint_orange")
    a.box((12.0, 10.0, 1.2), (0, -B * 0.16, hull_z + 10.6), "galv")
    P.derrick(a, (0, -B * 0.16, hull_z + 11.2), 40.0, 8.0, 2.2, "paint_orange", bays=10)
    a.box((3.0, 8.0, 2.4), (8.0, -B * 0.16, hull_z + 12.0), "paint_red", bevel=0.05)
    a.cyl(0.8, 5.0, (8.0, -B * 0.16 + 1.0, hull_z + 13.2), "steel_light", seg=14, rot=(math.pi / 2, 0, 0))

    # --- accommodation + helideck ----------------------------------------- #
    deck_z = hull_z + 9.0
    deckhouse(a, (-L * 0.26, B * 0.02, deck_z), 16.0, 20.0, 12.0, decks=3, mat="paint_white")
    P.helideck(a, (-L * 0.26, B * 0.02, deck_z + 14.2), 10.5, mat="paint_green")
    P.heli_pad_tower(a, (-L * 0.26, B * 0.02, deck_z), 14.0)

    # --- process modules --------------------------------------------------- #
    for i in range(3):
        a.box((9.0, 6.0, 4.0), (L * 0.12 + i * 0.2, B * 0.24 - i * 6.5, deck_z + 2.0), "galv", bevel=0.05)
        a.box((8.0, 5.0, 0.2), (L * 0.12 + i * 0.2, B * 0.24 - i * 6.5, deck_z + 4.2), "steel_dark")
    P.generator_set(a, (L * 0.30, -B * 0.26, deck_z), "paint_green")
    P.generator_set(a, (L * 0.30, -B * 0.18, deck_z), "paint_green")
    # drill water / fuel tanks
    a.cyl(3.0, 6.0, (L * 0.34, B * 0.10, deck_z + 3.0), "paint_white", seg=16, rot=(math.pi / 2, 0, 0))

    # --- cranes, boats, safety -------------------------------------------- #
    pedestal_pair(a, (L * 0.34, 0, deck_z), B * 0.5, 20.0, 26.0)
    lifeboat_pair(a, (-L * 0.34, 0, deck_z + 3.0), B * 0.55)
    P.handrail(a, [(L * 0.46, -B * 0.32, deck_z), (L * 0.46, B * 0.44, deck_z),
                   (-L * 0.46, B * 0.44, deck_z), (-L * 0.46, -B * 0.32, deck_z),
                   (L * 0.46, -B * 0.32, deck_z)], 1.1, "galv", spacing=6.0)
    a.cyl(0.6, 8.0, (L * 0.44, -B * 0.30, deck_z + 4.0), "paint_grey", seg=12)
    a.sphere(0.25, (L * 0.44, -B * 0.30, deck_z + 8.1), "emit_red", seg=(8, 5))
    _ = pts


def semi_submersible(a: Asset):
    """Fourth-generation semi-submersible with two pontoons and four columns."""
    a.set(placement="waterline", role="drilling")
    L, B = 74.0, 64.0
    # --- pontoons ---------------------------------------------------------- #
    for sy in (-1, 1):
        a.box((L * 0.82, 13.0, 9.5), (0, sy * 20.0, -13.0), "paint_blue", bevel=0.4)
        a.box((L * 0.78, 11.0, 0.4), (0, sy * 20.0, -8.2), "steel_dark")
        a.box((L * 0.30, 12.0, 3.0), (0, sy * 20.0, -17.0), "paint_red")
    # --- columns ----------------------------------------------------------- #
    col_x = L * 0.31
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.cyl(4.2, 22.0, (sx * col_x, sy * 20.0, 0.0), "paint_blue", seg=18)
            a.cyl(4.6, 1.2, (sx * col_x, sy * 20.0, 6.0), "paint_yellow", seg=18)
            a.cyl(4.6, 0.8, (sx * col_x, sy * 20.0, -8.0), "paint_yellow", seg=18)
            # bracing
            if sx * sy > 0:
                pass
    for sy in (-1, 1):
        a.beam((-col_x, sy * 20.0, -6.0), (col_x, sy * 20.0, -6.0), 1.4, "paint_blue")
    for sx in (-1, 1):
        a.beam((sx * col_x, -20.0, -6.0), (sx * col_x, 20.0, -6.0), 1.4, "paint_blue")

    # --- deck box ---------------------------------------------------------- #
    deck_z = 11.0
    a.box((L * 0.92, B * 0.86, 3.2), (0, 0, deck_z + 1.6), "steel_dark")
    a.box((L * 0.96, B * 0.9, 1.0), (0, 0, deck_z + 3.7), "galv")
    a.box((L * 0.97, 0.6, 0.4), (0, B * 0.45, deck_z + 4.2), "paint_yellow")

    # --- derrick ----------------------------------------------------------- #
    P.derrick(a, (0, -6.0, deck_z + 4.2), 44.0, 9.0, 2.2, "paint_yellow", bays=11)
    a.box((14.0, 12.0, 2.0), (0, -6.0, deck_z + 4.4), "galv")
    a.box((4.0, 7.0, 3.0), (11.0, -6.0, deck_z + 5.8), "paint_red", bevel=0.05)
    a.cyl(0.9, 6.0, (11.0, -4.0, deck_z + 7.4), "steel_light", seg=14, rot=(math.pi / 2, 0, 0))
    moonpool(a, (-6.0, -6.0, deck_z - 0.4), 8.0, 10.0)

    # --- accommodation ----------------------------------------------------- #
    deckhouse(a, (-L * 0.30, B * 0.16, deck_z + 4.2), 18.0, 22.0, 13.0, 3, "paint_white")
    P.helideck(a, (-L * 0.30, B * 0.16, deck_z + 19.0), 11.0, "paint_green")
    P.heli_pad_tower(a, (-L * 0.30, B * 0.16, deck_z + 4.2), 18.0)

    # --- modules / cranes -------------------------------------------------- #
    for i in range(3):
        a.box((10.0, 7.0, 4.5), (L * 0.16, -B * 0.26 + i * 8.0, deck_z + 6.4), "galv", bevel=0.05)
    P.generator_set(a, (L * 0.34, -B * 0.34, deck_z + 4.2), "paint_green")
    pedestal_pair(a, (L * 0.36, B * 0.02, deck_z + 4.2), B * 0.6, 22.0, 28.0)
    lifeboat_pair(a, (-L * 0.16, 0, deck_z + 6.0), B * 0.72)
    # thrusters
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.cyl(2.2, 3.2, (sx * L * 0.36, sy * 20.0, -17.0), "paint_yellow", seg=14)
            a.cyl(1.4, 0.4, (sx * L * 0.36, sy * 20.0, -18.8), "steel_dark", seg=14)


def drillship(a: Asset):
    """Ultra-deepwater drillship with dual derrick and moonpool."""
    a.set(placement="waterline", role="drilling")
    L, B = 228.0, 42.0
    deck = ship_hull(a, (0, 0, 0), L, B, 12.0, "paint_white", 0.20)
    a.box((L * 0.84, B * 0.9, 1.0), (0, 0, deck + 0.5), "galv")
    # bow flare / helideck forward
    P.helideck(a, (L * 0.34, 0, deck + 6.0), 12.0, "paint_green")
    P.heli_pad_tower(a, (L * 0.34, 0, deck + 1.0), 5.0)
    # accommodation aft
    deckhouse(a, (-L * 0.33, 0, deck + 1.0), 24.0, 30.0, 16.0, 4, "paint_white")
    # moonpool + derrick
    moonpool(a, (0, 0, deck + 0.05), 14.0, 22.0)
    a.box((30.0, 26.0, 2.0), (0, 0, deck + 1.0), "steel_dark")
    P.derrick(a, (0, 0, deck + 2.0), 48.0, 10.0, 2.4, "paint_yellow", bays=11)
    a.box((8.0, 6.0, 4.0), (16.0, 0, deck + 3.0), "paint_red", bevel=0.06)
    # pipe rack + cranes
    for i in range(3):
        a.box((26.0, 3.0, 1.6), (-16.0, -B * 0.28 + i * 3.4, deck + 1.8), "paint_orange")
    pedestal_pair(a, (L * 0.16, 0, deck + 1.0), B * 0.7, 24.0, 32.0)
    lifeboat_pair(a, (-L * 0.12, 0, deck + 2.0), B * 0.9)
    # thrusters / azipods
    for i in range(3):
        a.cyl(2.4, 4.0, (-L * 0.40 + i * 10.0, 0, -10.0), "paint_yellow", seg=14)
    a.box((L * 0.20, 6.0, 3.0), (-L * 0.42, 0, deck + 1.5), "paint_grey")


def fixed_platform(a: Asset):
    """Eight-leg steel jacket production platform with integrated deck."""
    a.set(placement="waterline", role="production")
    wd = 45.0
    legs = [(-11, -11), (11, -11), (11, 11), (-11, 11),
            (-4, -4), (4, -4), (4, 4), (-4, 4)]
    for i, (lx, ly) in enumerate(legs):
        outer = i < 4
        a.beam((lx * 1.6, ly * 1.6, -wd), (lx, ly, 12.0), 1.05 if outer else 0.80, "paint_yellow")
        a.cyl(1.2, 2.4, (lx * 1.6, ly * 1.6, -wd), "steel_dark", seg=10)
        if outer:
            a.box((3.6, 3.6, 1.1), (lx * 1.6, ly * 1.6, -wd + 0.55), "steel_dark")
    # horizontal frames + X bracing
    for level, z in enumerate((-36.0, -22.0, -8.0, 6.0)):
        s = 1.6 - (z + wd) / (wd + 12.0) * 0.6
        ring = [(lx * s, ly * s, z) for lx, ly in legs[:4]]
        for k in range(4):
            a.beam(ring[k], ring[(k + 1) % 4], 0.70, "paint_yellow")
        if level < 3:
            for k in range(4):
                a.beam(ring[k], ring[(k + 1) % 4], 0.40, "paint_yellow")
    # X bracing on faces
    for k in range(4):
        l0, l1 = legs[k], legs[(k + 1) % 4]
        a.beam((l0[0] * 1.6, l0[1] * 1.6, -wd), (l1[0] * 1.0, l1[1] * 1.0, 6.0), 0.55, "paint_yellow")
        a.beam((l1[0] * 1.6, l1[1] * 1.6, -wd), (l0[0] * 1.0, l0[1] * 1.0, 6.0), 0.55, "paint_yellow")
    # boat landing
    for sy in (-1, 1):
        a.box((2.0, 6.0, 10.0), (0, sy * 20.0, -6.0), "paint_yellow")
        for i in range(5):
            a.beam((0, sy * 20.0, -10.0 + i * 2.4), (0, sy * 17.0, -10.0 + i * 2.4), 0.2, "steel_dark")

    # --- deck -------------------------------------------------------------- #
    deck_z = 12.0
    a.box((30.0, 30.0, 2.0), (0, 0, deck_z + 1.0), "steel_dark")
    a.box((31.0, 31.0, 0.6), (0, 0, deck_z + 2.3), "galv")
    a.box((8.0, 30.0, 0.4), (18.0, 0, deck_z + 2.2), "galv")
    # modules
    for i, (mx, my, mw, ml, mh, col) in enumerate([
        (-8, -8, 12, 10, 5, "paint_white"),
        (2, -8, 10, 10, 4, "galv"),
        (-8, 6, 11, 9, 4, "paint_white"),
        (3, 6, 8, 9, 6, "paint_grey"),
    ]):
        a.box((mw, ml, mh), (mx, my, deck_z + 2.6 + mh / 2), col, bevel=0.05)
    # separation train
    P.vessel(a, 1.6, 7.0, (-8.0, -8.0, deck_z + 8.0), "X", "paint_white", 2)
    # accommodation + helideck
    deckhouse(a, (10.0, 10.0, deck_z + 2.6), 10.0, 10.0, 10.0, 3, "paint_white")
    P.helideck(a, (10.0, 10.0, deck_z + 14.2), 9.0, "paint_green")
    # flare boom
    a.beam((13.0, -13.0, deck_z + 2.0), (46.0, -20.0, deck_z + 26.0), 0.9, "paint_grey")
    a.beam((13.0, -11.0, deck_z + 2.0), (46.0, -20.0, deck_z + 26.0), 0.5, "paint_grey")
    a.cyl(0.9, 2.0, (47.5, -20.5, deck_z + 27.0), "steel_dark", seg=12)
    a.sphere(0.4, (47.5, -20.5, deck_z + 28.2), "emit_amber", seg=(8, 5))
    # cranes + lifeboats
    P.pedestal_crane(a, (-14.0, -14.0, deck_z + 2.5), 16.0, 22.0, 0.8, "paint_yellow")
    P.pedestal_crane(a, (14.0, -14.0, deck_z + 2.5), 16.0, 20.0, 2.2, "paint_yellow")
    lifeboat_pair(a, (-6.0, 0, deck_z + 4.0), 30.0)
    # riser porch
    for i in range(4):
        a.cyl(0.55, 2.0, (-15.0, -12.0 + i * 2.2, deck_z - 1.0), "paint_yellow", seg=10)
    P.handrail(a, [(-15.5, -15.5, deck_z + 2.4), (15.5, -15.5, deck_z + 2.4),
                   (15.5, 15.5, deck_z + 2.4), (-15.5, 15.5, deck_z + 2.4),
                   (-15.5, -15.5, deck_z + 2.4)], 1.1, "galv", spacing=5.0)


def fpso(a: Asset):
    """Ship-shaped FPSO: internal turret, two topside module rows, flare boom."""
    a.set(placement="waterline", role="production")
    L, B = 248.0, 46.0
    deck = ship_hull(a, (0, 0, 0), L, B, 16.0, "paint_blue", 0.18)
    a.box((L * 0.86, B * 0.94, 0.5), (-L * 0.02, 0, deck + 0.25), "paint_grey")
    for s in (-1, 1):
        a.box((L * 0.84, 1.1, 0.55), (-L * 0.02, s * B * 0.465, deck + 0.55), "paint_orange")

    # --- internal turret + swivel ----------------------------------------- #
    a.cyl(10.0, 5.0, (L * 0.36, 0, deck + 1.0), "paint_yellow", seg=26)
    a.cyl(7.0, 2.5, (L * 0.36, 0, deck + 4.7), "steel_dark", seg=22)
    a.cyl(1.4, 2.2, (L * 0.36, 0, deck + 6.8), "paint_red", seg=12)
    for i in range(4):
        ang = TAU * i / 4
        a.cyl(0.35, 3.0, (L * 0.36 + math.cos(ang) * 8.0, math.sin(ang) * 8.0, deck + 2.0),
              "steel", seg=10)

    # --- topside module rows ---------------------------------------------- #
    for i in range(5):
        x = -L * 0.22 + i * L * 0.075
        a.box((19.0, 13.0, 8.0), (x, -B * 0.21, deck + 4.5), "paint_grey", bevel=0.07)
        a.box((18.0, 12.0, 0.35), (x, -B * 0.21, deck + 8.6), "steel_dark")
        a.box((17.0, 12.0, 6.5), (x + 1.5, B * 0.21, deck + 3.75), "paint_white", bevel=0.07)
        a.box((16.0, 11.0, 0.35), (x + 1.5, B * 0.21, deck + 7.1), "steel_dark")
    # deck-edge walkways
    for s in (-1, 1):
        P.handrail(a, [(-L * 0.40, s * B * 0.46, deck + 0.5), (L * 0.30, s * B * 0.46, deck + 0.5)],
                   1.1, "galv", spacing=12)
    P.vessel(a, 1.1, 7.0, (-L * 0.06, -B * 0.345, deck + 9.6), "X", "paint_white", 2)
    # process columns
    for i, (cx, cy, cr, ch) in enumerate([
        (L * 0.20, -7.0, 2.4, 22.0),
        (L * 0.24, 7.0, 2.0, 17.0),
    ]):
        a.cyl(cr, ch, (cx, cy, deck + 2.0 + ch / 2), "paint_white", seg=18)
        a.dome((cx, cy, deck + 2.0 + ch), cr, cr * 0.5, "Z", "paint_white", seg=18, rings=4)

    # --- pipe rack spine --------------------------------------------------- #
    for i in range(9):
        x = -L * 0.26 + i * L * 0.048
        for s in (-1, 1):
            a.beam((x, s * 2.6, deck + 0.5), (x, s * 2.6, deck + 5.6), 0.22, "galv")
        a.beam((x, -2.6, deck + 5.6), (x, 2.6, deck + 5.6), 0.16, "galv")
    for k in range(3):
        a.cyl(0.24, L * 0.40, (-L * 0.07, -1.6 + k * 1.6, deck + 5.8),
              ("pipe_white", "pipe_yellow", "pipe_green")[k], seg=10, rot=(0, math.pi / 2, 0))

    # --- flare boom (trussed) ---------------------------------------------- #
    root = V((-L * 0.10, B * 0.42, deck + 2.0))
    tip = V((-L * 0.30, B * 0.58, deck + 30.0))
    for off in (-1.2, 1.2):
        a.beam(root + V((0, off, 0)), tip + V((0, off * 0.2, 0)), 0.5, "paint_grey")
    for i in range(7):
        t0 = i / 7
        t1 = (i + 1) / 7
        p0 = root.lerp(tip, t0)
        p1 = root.lerp(tip, t1)
        a.beam(p0 + V((0, -1.2, 0)), p1 + V((0, 1.2, 0)), 0.14, "paint_grey")
        a.beam(p0 + V((0, 1.2, 0)), p1 + V((0, -1.2, 0)), 0.14, "paint_grey")
    a.cyl(1.0, 2.4, tip + V((0, 0, 1.0)), "steel_dark", seg=12)
    a.sphere(0.45, tip + V((0, 0, 2.4)), "emit_amber", seg=(8, 5))

    # --- accommodation, helideck, cranes, boats ---------------------------- #
    deckhouse(a, (-L * 0.38, 0, deck + 0.5), 20.0, 26.0, 20.0, 4, "paint_white")
    P.helideck(a, (-L * 0.38, 0, deck + 22.5), 11.0, "paint_green")
    pedestal_pair(a, (-L * 0.26, 0, deck + 0.5), B * 0.9, 20.0, 30.0)
    lifeboat_pair(a, (-L * 0.44, 0, deck + 4.0), B * 1.0)
    P.ac_unit(a, (-L * 0.44, 0, deck + 21.2), (2.0, 1.4, 1.1))

    # --- offloading + mooring ---------------------------------------------- #
    a.cyl(1.8, 10.0, (-L * 0.33, -B * 0.46, deck + 2.4), "paint_orange", seg=14, rot=(0, math.pi / 2, 0))
    for i in range(4):
        P.pipe_run(a, [(-L * 0.30 + i * 2.4, -B * 0.44, deck + 1.2),
                       (-L * 0.30 + i * 2.4, -B * 0.50, deck - 3.0)], 0.26, "pipe_white")
    for i in range(8):
        ang = TAU * i / 8
        a.sweep([(L * 0.34 + math.cos(ang) * 10.0, math.sin(ang) * 10.0, -4.0),
                 (L * 0.34 + math.cos(ang) * 34.0, math.sin(ang) * 34.0, -38.0)],
                0.22, "steel_dark", seg=5)


def spar_platform(a: Asset):
    """Truss spar: hard tank, truss section, deck & topsides."""
    a.set(placement="waterline", role="production")
    # hard tank
    a.cyl(18.0, 62.0, (0, 0, -20.0), "paint_grey", seg=24)
    a.dome((0, 0, -51.0), 18.0, 6.0, (0, 0, -1), "paint_grey", seg=24, rings=5)
    a.cyl(18.4, 1.2, (0, 0, 8.0), "paint_yellow", seg=24)
    a.cyl(18.4, 1.2, (0, 0, -8.0), "paint_yellow", seg=24)
    a.cyl(18.4, 1.2, (0, 0, -30.0), "paint_yellow", seg=24)
    # soft tank / ballast
    a.cyl(16.0, 8.0, (0, 0, -47.0), "paint_red", seg=20)
    # truss section
    for i in range(3):
        ang = TAU * i / 3
        for j in range(4):
            ang2 = TAU * j / 4 + math.pi / 4
            a.beam((math.cos(ang2) * 12.0, math.sin(ang2) * 12.0, 9.0),
                   (math.cos(ang2) * 14.0, math.sin(ang2) * 14.0, 26.0), 0.9, "paint_yellow")
        a.beam((math.cos(ang) * 13.0, math.sin(ang) * 13.0, 10.0),
               (math.cos(ang) * 17.0, math.sin(ang) * 17.0, 26.0), 0.6, "paint_yellow")
    for z in (12.0, 18.0, 24.0):
        pts = [(math.cos(TAU * k / 24) * 14.0, math.sin(TAU * k / 24) * 14.0, z) for k in range(25)]
        a.sweep(pts, 0.5, "paint_yellow", seg=8, caps=False)
    # deck
    a.box((34.0, 34.0, 2.4), (0, 0, 27.2), "steel_dark")
    a.box((35.0, 35.0, 0.7), (0, 0, 28.7), "galv")
    deckhouse(a, (-8.0, 8.0, 29.0), 12.0, 12.0, 10.0, 3, "paint_white")
    P.helideck(a, (8.0, 8.0, 34.2), 9.0, "paint_green")
    for i in range(3):
        a.box((9.0, 8.0, 4.0), (-9.0 + i * 0.4, -8.0 + i * 7.0, 31.2), "galv", bevel=0.05)
    a.cyl(1.8, 10.0, (11.0, -10.0, 34.0), "paint_white", seg=14)
    P.pedestal_crane(a, (-14.0, -12.0, 29.0), 14.0, 18.0, 0.7, "paint_yellow")
    a.beam((-14.0, 14.0, 29.0), (-30.0, 26.0, 48.0), 0.8, "paint_grey")
    a.cyl(0.9, 1.8, (-30.0, 26.0, 48.5), "steel_dark", seg=10)
    # mooring lines
    for i in range(8):
        ang = TAU * i / 8
        a.sweep([(math.cos(ang) * 18.0, math.sin(ang) * 18.0, -46.0),
                 (math.cos(ang) * 42.0, math.sin(ang) * 42.0, -62.0)], 0.22, "steel_dark", seg=5)


# --------------------------------------------------------------------------- #
# subsea
# --------------------------------------------------------------------------- #


def subsea_tree(a: Asset):
    a.set(placement="seabed", role="production")
    # protection frame
    a.box((4.6, 4.6, 0.5), (0, 0, 0.25), "paint_yellow")
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.beam((sx * 2.0, sy * 2.0, 0.0), (sx * 2.0, sy * 2.0, 3.4), 0.22, "paint_yellow")
    a.box((4.8, 0.4, 0.4), (0, -2.0, 3.4), "paint_yellow")
    a.box((4.8, 0.4, 0.4), (0, 2.0, 3.4), "paint_yellow")
    a.box((0.4, 4.8, 0.4), (2.0, 0, 3.4), "paint_yellow")
    # wellhead + tree body
    a.cyl(0.55, 1.2, (0, 0, 1.1), "steel_dark", seg=14)
    a.cyl(0.42, 1.8, (0, 0, 2.6), "paint_yellow", seg=14)
    for zz in (1.85, 2.6, 3.35):
        a.cyl(0.55, 0.22, (0, 0, zz), "steel", seg=14)
    # valves / actuators
    for ang, col in ((0.0, "paint_red"), (math.pi / 2, "paint_blue"), (math.pi, "paint_green")):
        px, py = math.cos(ang) * 0.85, math.sin(ang) * 0.85
        a.cyl(0.22, 1.4, (px, py, 2.6), col, seg=10, rot=(0, math.pi / 2, ang))
        a.cyl(0.30, 0.35, (px * 1.5, py * 1.5, 2.6), "steel_light", seg=10, rot=(0, math.pi / 2, ang))
    # control module + flying lead
    a.box((1.0, 0.8, 0.9), (1.4, -1.4, 3.9), "paint_grey", bevel=0.03)
    a.sweep([(1.4, -1.0, 3.9), (2.6, -2.6, 0.4), (3.6, -3.2, 0.2)], 0.09, "plastic_orange", seg=6)
    # flowline hub
    a.cyl(0.4, 0.7, (-1.8, -1.8, 1.6), "steel_light", seg=12, rot=(0, math.pi / 2, 0))
    a.cyl(0.55, 0.2, (-2.2, -1.8, 1.6), "paint_yellow", seg=12, rot=(0, math.pi / 2, 0))
    a.sphere(0.18, (2.0, 2.0, 3.0), "emit_green", seg=(8, 5))


def subsea_manifold(a: Asset):
    a.set(placement="seabed", role="transport")
    a.box((11.0, 6.0, 0.6), (0, 0, 0.3), "paint_yellow")
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.cyl(0.6, 1.2, (sx * 5.0, sy * 2.6, 0.6), "steel_dark", seg=10)
    # header pipes
    for sy in (-1.4, 1.4):
        a.cyl(0.32, 10.0, (0, sy, 1.6), "pipe_green", seg=12, rot=(0, math.pi / 2, 0))
    for i in range(4):
        x = -3.6 + i * 2.4
        a.cyl(0.22, 3.0, (x, 0, 1.4), "pipe_green", seg=10, rot=(math.pi / 2, 0, 0))
        a.cyl(0.42, 0.5, (x, 0, 1.7), "paint_red", seg=10)
        a.box((0.7, 0.7, 0.6), (x, -0.9, 2.1), "paint_grey", bevel=0.03)
        a.box((0.7, 0.7, 0.6), (x, 0.9, 2.1), "paint_grey", bevel=0.03)
    # hub ends
    for sx in (-1, 1):
        a.cyl(0.7, 0.5, (sx * 5.6, 0, 1.6), "steel_light", seg=12, rot=(0, math.pi / 2, 0))
    a.sphere(0.2, (0, 0, 2.4), "emit_amber", seg=(8, 5))


def riser_joint(a: Asset):
    """Free-standing hybrid riser joint with buoyancy modules."""
    a.set(placement="vertical")
    a.cyl(0.45, 24.0, (0, 0, 12.0), "pipe_yellow", seg=14)
    for i in range(5):
        a.cyl(0.85, 2.6, (0, 0, 2.0 + i * 4.6), "paint_yellow", seg=14)
    P.flange(a, (0, 0, 0.3), "Z", 0.7, "steel_dark")
    P.flange(a, (0, 0, 23.7), "Z", 0.7, "steel_dark")
    a.cyl(0.30, 0.8, (0.9, 0, 12.0), "steel_light", seg=10, rot=(0, math.pi / 2, 0))
    a.sweep([(0.9, 0, 12.0), (1.6, 0.6, 11.0), (2.0, 1.4, 9.0)], 0.09, "plastic_orange", seg=6)


# --------------------------------------------------------------------------- #
# vessels
# --------------------------------------------------------------------------- #


def platform_supply_vessel(a: Asset):
    a.set(placement="waterline", role="marine")
    L, B = 78.0, 18.0
    deck = ship_hull(a, (0, 0, 0), L, B, 6.5, "paint_orange", 0.2)
    deckhouse(a, (L * 0.34, 0, deck + 0.1), 8.0, 12.0, 7.0, 2, "paint_white")
    a.box((9.0, 10.0, 0.4), (L * 0.34, 0, deck + 11.0), "paint_grey")
    # cargo deck
    a.box((L * 0.55, B * 0.88, 0.5), (-L * 0.14, 0, deck + 0.25), "steel_dark")
    P.handrail(a, [(-L * 0.42, -B * 0.44, deck + 0.5), (L * 0.16, -B * 0.44, deck + 0.5)], 1.0, "galv")
    P.handrail(a, [(-L * 0.42, B * 0.44, deck + 0.5), (L * 0.16, B * 0.44, deck + 0.5)], 1.0, "galv")
    # deck cargo
    for i in range(3):
        a.box((4.0, 6.0, 3.0), (-L * 0.34 + i * 12.0, -B * 0.18, deck + 2.0), "paint_blue", bevel=0.06)
        a.box((1.0, 8.0, 2.4), (-L * 0.34 + i * 12.0 + 5.0, B * 0.18, deck + 1.7), "galv")
    # aft winch + towing gear
    a.cyl(1.2, 4.0, (-L * 0.42, 0, deck + 1.6), "paint_yellow", seg=14, rot=(math.pi / 2, 0, 0))
    a.box((3.0, 6.0, 1.2), (-L * 0.45, 0, deck + 0.9), "steel_dark")
    # bow crane / A-frame
    a.beam((L * 0.24, -3.0, deck + 0.8), (L * 0.36, -3.0, deck + 12.0), 0.5, "paint_yellow")
    a.beam((L * 0.24, 3.0, deck + 0.8), (L * 0.36, 3.0, deck + 12.0), 0.5, "paint_yellow")
    a.beam((L * 0.36, -3.0, deck + 12.0), (L * 0.36, 3.0, deck + 12.0), 0.4, "paint_yellow")
    # lifeboats
    for s in (-1, 1):
        P.lifeboat(a, (L * 0.30, s * 4.0, deck + 8.0), mat="paint_orange")
    a.cyl(0.3, 8.0, (L * 0.34, 0, deck + 13.0), "galv", seg=8)


def ahts_tug(a: Asset):
    a.set(placement="waterline", role="marine")
    L, B = 68.0, 16.0
    deck = ship_hull(a, (0, 0, 0), L, B, 6.0, "paint_yellow", 0.22)
    deckhouse(a, (L * 0.22, 0, deck + 0.1), 11.0, 9.0, 8.0, 3, "paint_white")
    a.box((8.0, 8.0, 0.4), (L * 0.22, 0, deck + 12.2), "paint_grey")
    # stern roller + winch
    a.cyl(1.6, 9.0, (-L * 0.44, 0, deck + 0.4), "steel_dark", seg=16, rot=(math.pi / 2, 0, 0))
    a.box((5.0, 7.0, 1.6), (-L * 0.40, 0, deck + 1.2), "paint_orange")
    for i in range(3):
        a.cyl(0.9, 3.0, (-L * 0.36, -4.0 + i * 4.0, deck + 2.6), "steel_light", seg=12, rot=(math.pi / 2, 0, 0))
    # fire monitors
    for s in (-1, 1):
        a.cyl(0.25, 0.8, (L * 0.28, s * 4.0, deck + 9.0), "paint_red", seg=8)
        a.beam((L * 0.28, s * 4.0, deck + 8.6), (L * 0.34, s * 5.0, deck + 10.0), 0.2, "chrome")
    # towing bridle
    for s in (-1, 1):
        a.sweep([(-L * 0.40, s * 3.0, deck + 1.8), (-L * 0.52, s * 1.0, 1.0)], 0.12, "steel_dark", seg=6)


def shuttle_tanker(a: Asset):
    a.set(placement="waterline", role="marine")
    L, B = 245.0, 42.0
    deck = ship_hull(a, (0, 0, 0), L, B, 12.0, "paint_red", 0.16)
    # cargo deck + walkways
    a.box((L * 0.72, B * 0.90, 0.35), (-L * 0.03, 0, deck + 0.18), "paint_grey")
    for s in (-1, 1):
        P.handrail(a, [(-L * 0.34, s * B * 0.44, deck + 0.36),
                       (L * 0.40, s * B * 0.44, deck + 0.36)], 1.05, "galv", spacing=12)
    # tank hatches with coamings
    for i in range(6):
        x = -L * 0.26 + i * 20.0
        a.cyl(3.60, 0.50, (x, 0, deck + 0.60), "paint_grey", seg=18)
        a.cyl(3.95, 0.22, (x, 0, deck + 0.32), "steel_dark", seg=18)
        a.box((1.1, 1.1, 0.30), (x + 2.4, 2.2, deck + 0.50), "paint_yellow")
    # cargo manifold: two headers with branch valves
    for sy in (-1, 1):
        P.pipe_run(a, [(-L * 0.30, sy * 7.0, deck + 0.95), (L * 0.32, sy * 7.0, deck + 0.95)],
                   0.28, "pipe_yellow")
        for i in range(6):
            x = -L * 0.26 + i * 20.0
            P.pipe_run(a, [(x, sy * 7.0, deck + 0.95), (x, sy * 2.8, deck + 0.95)], 0.16)
            P.gate_valve(a, (x, sy * 4.6, deck + 0.95), "Y", 0.22)
    # cargo control station
    a.box((6.0, 4.5, 2.6), (L * 0.08, -B * 0.30, deck + 1.65), "paint_white", bevel=0.05)
    a.box((4.6, 3.2, 0.10), (L * 0.08, -B * 0.30, deck + 3.00), "paint_grey")
    # bow loading station
    a.box((7.0, 6.0, 2.2), (L * 0.38, 0, deck + 1.20), "paint_red", bevel=0.05)
    a.cyl(0.50, 2.2, (L * 0.40, -2.4, deck + 3.2), "paint_yellow", seg=10)
    a.beam((L * 0.40, -2.4, deck + 4.2), (L * 0.40, -5.2, deck + 3.2), 0.26, "paint_yellow")
    # superstructure aft + funnel
    deckhouse(a, (-L * 0.36, 0, deck + 0.5), 20.0, 22.0, 16.0, 4, "paint_white")
    a.cyl(2.0, 15.0, (-L * 0.42, 0, deck + 16.0), "paint_blue", seg=16)
    a.cyl(2.08, 1.8, (-L * 0.42, 0, deck + 21.0), "paint_white", seg=16)
    a.cyl(2.10, 1.2, (-L * 0.42, 0, deck + 23.4), "paint_red", seg=16)
    P.ac_unit(a, (-L * 0.40, 3.0, deck + 17.0), (2.0, 1.4, 1.0))
    # bow forecastle + mast
    a.box((16.0, B * 0.70, 3.0), (L * 0.42, 0, deck + 1.5), "paint_red")
    a.cyl(0.55, 11.0, (L * 0.46, 0, deck + 6.5), "galv", seg=8)
    a.sphere(0.22, (L * 0.46, 0, deck + 12.2), "emit_red", seg=(6, 4))
    for s in (-1, 1):
        P.lifeboat(a, (-L * 0.30, s * 12.0, deck + 8.0))


def crew_boat(a: Asset):
    a.set(placement="waterline", role="marine")
    L, B = 38.0, 9.0
    deck = ship_hull(a, (0, 0, 0), L, B, 4.2, "paint_white", 0.24)
    deckhouse(a, (L * 0.05, 0, deck + 0.1), 7.0, 14.0, 3.4, 2, "paint_white")
    a.box((7.2, 8.0, 2.2), (-L * 0.2, 0, deck + 1.2), "paint_white", bevel=0.06)
    a.box((6.0, 7.0, 0.06), (-L * 0.2, 0, deck + 2.4), "glass_dark")
    # jet drives + fender
    for s in (-1, 1):
        a.cyl(0.5, 1.4, (-L * 0.46, s * 2.4, -0.6), "steel_dark", seg=10, rot=(0, math.pi / 2, 0))
    for s in (-1, 1):
        a.box((L * 0.5, 0.35, 0.55), (0, s * B * 0.5, 0.4), "rubber")
    a.cyl(0.22, 5.0, (L * 0.12, 0, deck + 6.0), "galv", seg=8)


def helicopter(a: Asset):
    """Medium twin-engine transport helicopter (S-92 class silhouette)."""
    a.set(placement="origin_skids", role="air")
    cz = 2.55
    # lofted fuselage: nose -> cabin -> tail transition
    stations = [
        (4.10, 0.28, 0.26), (3.55, 0.78, 0.70), (2.60, 1.04, 0.94),
        (1.30, 1.18, 1.08), (0.00, 1.20, 1.10), (-1.30, 1.14, 1.04),
        (-2.50, 0.94, 0.90), (-3.50, 0.58, 0.68),
    ]
    ring_n = 12
    sections = []
    for (x, ry, rz) in stations:
        sections.append([(x, math.cos(TAU * i / ring_n) * ry,
                          cz + math.sin(TAU * i / ring_n) * rz) for i in range(ring_n)])
    a.loft(sections, "paint_white")

    # tail boom + fin + stabiliser
    a.beam((-3.4, 0, cz), (-9.0, 0, cz + 0.38), 0.52, "paint_white", h=0.44)
    a.box((0.70, 0.14, 1.60), (-9.05, 0, cz + 1.10), "paint_white", bevel=0.04)
    a.box((0.55, 0.10, 0.55), (-9.05, 0, cz + 1.95), "paint_red")
    for s in (-1, 1):
        a.box((0.90, 0.75, 0.10), (-8.55, s * 0.42, cz + 0.55), "paint_white")

    # glazing
    a.box((0.10, 1.35, 0.72), (3.06, 0, cz + 0.18), "glass_dark", rot=(0, -0.38, 0))
    for s in (-1, 1):
        a.box((1.70, 0.07, 0.58), (2.30, s * 0.92, cz + 0.22), "glass_dark")
        a.box((1.30, 0.06, 0.46), (0.55, s * 1.14, cz + 0.18), "glass_dark")
        a.box((0.90, 0.06, 0.40), (-1.05, s * 1.12, cz + 0.16), "glass_dark")
        # livery stripe + door seams
        a.box((6.4, 0.05, 0.16), (-0.1, s * 1.20, cz - 0.34), "paint_red")
        a.beam((-2.30, s * 1.19, cz - 0.55), (-2.30, s * 1.19, cz + 0.55), 0.03, "steel_dark")
        a.beam((0.95, s * 1.19, cz - 0.55), (0.95, s * 1.19, cz + 0.55), 0.03, "steel_dark")
        # engine nacelle + intake
        a.box((1.70, 0.66, 0.62), (0.15, s * 0.98, cz + 1.18), "galv", bevel=0.06)
        a.cyl(0.22, 0.30, (-0.75, s * 0.98, cz + 1.18), "steel_dark", seg=10, rot=(0, math.pi / 2, 0))
        a.box((1.10, 0.50, 0.30), (-1.05, s * 0.98, cz + 1.42), "steel_dark")

    # main rotor: mast, hub, 5 blades
    a.cyl(0.34, 0.70, (0.35, 0, cz + 1.30), "steel_dark", seg=12)
    a.cyl(0.52, 0.22, (0.35, 0, cz + 1.66), "steel_dark", seg=14)
    for i in range(5):
        ang = TAU * i / 5
        a.box((3.9, 0.40, 0.075),
              (0.35 + math.cos(ang) * 1.85, math.sin(ang) * 1.85, cz + 1.72),
              "paint_black", rot=(0, 0, ang))
    # tail rotor
    a.cyl(0.16, 0.26, (-9.05, 0.22, cz + 1.10), "steel_dark", seg=10, rot=(math.pi / 2, 0, 0))
    for i in range(4):
        a.box((0.06, 0.24, 2.30), (-9.05, 0.30, cz + 1.10), "paint_black", rot=(TAU * i / 8, 0, 0))

    # skid landing gear
    for s in (-1, 1):
        a.box((3.30, 0.13, 0.13), (0.55, s * 1.00, 0.62), "steel_dark")
        a.beam((1.55, s * 1.00, 0.62), (1.15, s * 0.80, 1.55), 0.11, "steel_dark")
        a.beam((-0.35, s * 1.00, 0.62), (-0.15, s * 0.80, 1.55), 0.11, "steel_dark")
        a.beam((-1.10, s * 1.00, 0.62), (-1.55, s * 1.00, 0.90), 0.10, "steel_dark")
    a.beam((0.55, -1.00, 0.66), (0.55, 1.00, 0.66), 0.13, "steel_dark")
    a.beam((-0.40, -1.00, 0.66), (-0.40, 1.00, 0.66), 0.11, "steel_dark")

    # lights + winch
    a.sphere(0.10, (3.35, 0, cz - 0.25), "emit_white", seg=(6, 4))
    a.sphere(0.09, (-9.05, 0, cz + 1.90), "emit_red", seg=(6, 4))
    a.cyl(0.16, 0.55, (-2.40, 0, cz - 0.85), "paint_yellow", seg=8)


def pipe_lay_barge(a: Asset):
    a.set(placement="waterline", role="marine")
    L, B = 140.0, 34.0
    a.box((L, B, 7.0), (0, 0, -2.0), "paint_blue", bevel=0.12)
    a.box((L * 0.98, B * 0.98, 1.0), (0, 0, 1.9), "steel_dark")
    # accommodation block forward
    deckhouse(a, (L * 0.34, 0, 2.4), 18.0, 20.0, 14.0, 3, "paint_white")
    P.helideck(a, (L * 0.34, 0, 18.0), 9.0, "paint_green")
    # pipe racks
    for i in range(5):
        a.box((5.0, 12.0, 1.2), (-L * 0.28 + i * 14.0, 0, 3.2), "galv")
    for i in range(4):
        a.cyl(0.9, 40.0, (-L * 0.30 + i * 10.0, B * 0.30, 4.6), "rust_patchy", seg=10, rot=(0, math.pi / 2, 0))
    # stinger (pipe launch ramp)
    a.beam((-L * 0.50, -6.0, 2.4), (-L * 0.58, -6.0, -12.0), 0.8, "paint_yellow")
    a.beam((-L * 0.50, 6.0, 2.4), (-L * 0.58, 6.0, -12.0), 0.8, "paint_yellow")
    for i in range(4):
        t = i / 4
        a.beam((-L * 0.50 - L * 0.08 * t, -6.0, 2.4 - 14.0 * t),
               (-L * 0.50 - L * 0.08 * t, 6.0, 2.4 - 14.0 * t), 0.35, "paint_yellow")
    # tensioners
    for i in range(2):
        a.box((4.0, 8.0, 4.0), (-L * 0.34 + i * 8.0, 0, 5.2), "paint_orange", bevel=0.06)
    P.pedestal_crane(a, (L * 0.20, B * 0.36, 2.4), 18.0, 26.0, 1.2, "paint_yellow")
    P.pedestal_crane(a, (-L * 0.16, B * 0.36, 2.4), 18.0, 26.0, 2.6, "paint_yellow")


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(
        aid="off_jackup_rig", name="Jack-Up Drilling Rig", build=jackup_rig,
        gameplay=dict(role="drilling", tier=2, cost_usd=210_000_000, build_days=120,
                      crew=120, power_kw=12_000, footprint_m2=3500, upkeep_usd_day=180_000,
                      water_depth_max_m=120, drill_depth_m=7600, drill_rate_m_day=150,
                      placement="waterline", relocation_days=9),
    ),
    dict(
        aid="off_semi_submersible", name="Semi-Submersible Rig", build=semi_submersible,
        gameplay=dict(role="drilling", tier=3, cost_usd=520_000_000, build_days=240,
                      crew=180, power_kw=26_000, footprint_m2=5000, upkeep_usd_day=320_000,
                      water_depth_max_m=2400, drill_depth_m=9000, drill_rate_m_day=130,
                      placement="waterline", relocation_days=14),
    ),
    dict(
        aid="off_drillship", name="Ultra-Deepwater Drillship", build=drillship,
        gameplay=dict(role="drilling", tier=4, cost_usd=780_000_000, build_days=300,
                      crew=220, power_kw=42_000, footprint_m2=9000, upkeep_usd_day=410_000,
                      water_depth_max_m=3600, drill_depth_m=12000, drill_rate_m_day=160,
                      placement="waterline", relocation_days=10),
    ),
    dict(
        aid="off_fixed_platform", name="Fixed Steel Platform", build=fixed_platform,
        gameplay=dict(role="production", tier=2, cost_usd=340_000_000, build_days=300,
                      crew=60, power_kw=6000, footprint_m2=900, upkeep_usd_day=95_000,
                      water_depth_max_m=110, capacity_bopd=45_000, well_slots=24,
                      placement="waterline"),
    ),
    dict(
        aid="off_fpso", name="FPSO (Floating Production Storage Offloading)", build=fpso,
        gameplay=dict(role="production", tier=3, cost_usd=1_100_000_000, build_days=420,
                      crew=110, power_kw=28_000, footprint_m2=11_000, upkeep_usd_day=260_000,
                      water_depth_min_m=300, capacity_bopd=120_000, storage_bbl=1_400_000,
                      placement="waterline"),
    ),
    dict(
        aid="off_spar", name="Truss Spar Platform", build=spar_platform,
        gameplay=dict(role="production", tier=3, cost_usd=820_000_000, build_days=380,
                      crew=45, power_kw=9_000, footprint_m2=1200, upkeep_usd_day=140_000,
                      water_depth_min_m=600, capacity_bopd=70_000, well_slots=16,
                      placement="waterline"),
    ),
    dict(
        aid="off_subsea_tree", name="Subsea Christmas Tree", build=subsea_tree,
        gameplay=dict(role="production", tier=2, cost_usd=32_000_000, build_days=25,
                      crew=0, power_kw=8, footprint_m2=25, upkeep_usd_day=6_000,
                      water_depth_max_m=3000, design_pressure_psi=15000,
                      placement="seabed"),
    ),
    dict(
        aid="off_subsea_manifold", name="Subsea Production Manifold", build=subsea_manifold,
        gameplay=dict(role="transport", tier=2, cost_usd=48_000_000, build_days=30,
                      crew=0, power_kw=0, footprint_m2=80, upkeep_usd_day=4_500,
                      well_slots=6, placement="seabed"),
    ),
    dict(
        aid="off_riser_joint", name="Hybrid Riser Joint (24 m)", build=riser_joint,
        gameplay=dict(role="transport", tier=2, cost_usd=2_400_000, build_days=2,
                      crew=0, power_kw=0, footprint_m2=8, upkeep_usd_day=600,
                      capacity_bopd=30_000, length_m=24, placement="vertical"),
    ),
    dict(
        aid="off_supply_vessel", name="Platform Supply Vessel", build=platform_supply_vessel,
        gameplay=dict(role="marine", tier=1, cost_usd=28_000_000, build_days=60,
                      crew=14, power_kw=5_000, footprint_m2=1400, upkeep_usd_day=9_500,
                      cargo_t=3500, speed_kn=13, placement="waterline"),
    ),
    dict(
        aid="off_ahts", name="Anchor Handling Tug", build=ahts_tug,
        gameplay=dict(role="marine", tier=2, cost_usd=42_000_000, build_days=70,
                      crew=16, power_kw=18_000, footprint_m2=1100, upkeep_usd_day=12_000,
                      bollard_pull_t=250, placement="waterline"),
    ),
    dict(
        aid="off_shuttle_tanker", name="Shuttle Tanker (1.0 MMbbl)", build=shuttle_tanker,
        gameplay=dict(role="marine", tier=2, cost_usd=95_000_000, build_days=120,
                      crew=24, power_kw=14_000, footprint_m2=10_000, upkeep_usd_day=28_000,
                      cargo_bbl=1_000_000, speed_kn=14, placement="waterline"),
    ),
    dict(
        aid="off_crew_boat", name="Fast Crew Boat", build=crew_boat,
        gameplay=dict(role="marine", tier=1, cost_usd=6_500_000, build_days=20,
                      crew=6, power_kw=4_000, footprint_m2=350, upkeep_usd_day=2_600,
                      passengers=60, speed_kn=32, placement="waterline"),
    ),
    dict(
        aid="off_helicopter", name="Medium Transport Helicopter", build=helicopter,
        gameplay=dict(role="air", tier=2, cost_usd=18_000_000, build_days=0,
                      crew=2, power_kw=2_600, footprint_m2=200, upkeep_usd_day=7_200,
                      passengers=19, speed_kn=150, placement="origin_skids"),
    ),
    dict(
        aid="off_pipelay_barge", name="S-Lay Pipelay Barge", build=pipe_lay_barge,
        gameplay=dict(role="marine", tier=3, cost_usd=260_000_000, build_days=180,
                      crew=240, power_kw=20_000, footprint_m2=4800, upkeep_usd_day=210_000,
                      lay_rate_km_day=2.4, pipe_diameter_max_in=48, placement="waterline"),
    ),
]
