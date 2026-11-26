"""Ground vehicles, heavy equipment and aircraft.

All vehicles face **-Y** (forward), origin at ground contact between the wheels.
Wheels sit outside the body line with visible arches; cabs have glazing, mirrors,
grilles and steps so they read at RTS distance and in close-up.
"""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector


# --------------------------------------------------------------------------- #
# shared vehicle helpers
# --------------------------------------------------------------------------- #


def frame_rails(a: Asset, length, width=1.0, z=0.6, mat="steel_dark"):
    for s in (-1, 1):
        a.beam((s * width / 2, -length / 2, z), (s * width / 2, length / 2, z), 0.16, mat)
    for t in (-0.40, 0.0, 0.40):
        a.beam((-width / 2, length * t, z), (width / 2, length * t, z), 0.12, mat)


def axle_pair(a: Asset, y, x, r, w, dual=False):
    for s in (-1, 1):
        P.truck_wheel(a, (s * x, y, r), r, w)
        if dual:
            P.truck_wheel(a, (s * (x + w * 0.92), y, r), r, w * 0.9)


def fender_set(a: Asset, ys, x, r, w, mat):
    for y in ys:
        for s in (-1, 1):
            P.fender_arch(a, (s * x, y, r), r + 0.07, w + 0.05, mat)


def headlights(a: Asset, y, z, x=0.72, mat="emit_white", w=0.30, h=0.16):
    for s in (-1, 1):
        a.box((w, 0.06, h), (s * x, y, z), mat)


def taillights(a: Asset, y, z, x=0.78, mat="paint_red", w=0.22, h=0.30):
    for s in (-1, 1):
        a.box((w, 0.06, h), (s * x, y, z), mat)


def beacon(a: Asset, loc, h=0.16):
    x, y, z = loc
    a.cyl(0.09, 0.06, (x, y, z), "steel_dark", seg=8)
    a.cyl(0.075, h, (x, y, z + h / 2 + 0.03), "emit_amber", seg=10)


def exhaust(a: Asset, loc, h=1.6, r=0.07, mat="chrome"):
    x, y, z = loc
    a.cyl(r, h, (x, y, z + h / 2), mat, seg=10)
    a.cyl(r * 1.35, 0.12, (x, y, z + h), "steel_dark", seg=10)


def steps(a: Asset, loc, w=0.45, n=2, mat="galv"):
    x, y, z = loc
    for i in range(n):
        a.box((w, 0.30, 0.05), (x, y, z + i * 0.28), mat)
        a.beam((x - w / 2, y, z + i * 0.28), (x - w / 2, y, z + i * 0.28 + 0.26), 0.04, mat)


def livery(a: Asset, loc, size, mat="paint_yellow"):
    x, y, z = loc
    a.box(size, (x, y, z), mat)


def box_truck_body(a: Asset, loc, w, l, h, mat="paint_white", windows=0, ribs=0,
                   window_band=None):
    x, y, z = loc
    a.box((w, l, h), (x, y, z + h / 2), mat, bevel=0.06)
    if window_band:
        z0, z1 = window_band
        for s in (-1, 1):
            a.box((0.05, l * 0.84, (z1 - z0)), (x + s * (w / 2 + 0.01), y, z + (z0 + z1) / 2), "glass_dark")
            n = max(2, int(l / 1.4))
            for i in range(1, n):
                yy = y - l * 0.42 + i * (l * 0.84 / n)
                a.box((0.07, 0.09, z1 - z0), (x + s * (w / 2 + 0.03), yy, z + (z0 + z1) / 2), mat)
    if ribs:
        for i in range(ribs):
            yy = y - l / 2 + l * (i + 0.5) / ribs
            a.box((w * 1.012, 0.06, h * 0.9), (x, yy, z + h / 2), "steel_dark")


# --------------------------------------------------------------------------- #
# light vehicles
# --------------------------------------------------------------------------- #


def pickup(a: Asset):
    L, W, r = 5.5, 1.96, 0.40
    frame_rails(a, 4.7, 1.0, 0.62)
    ys = (-1.62, 1.72)
    axle_pair(a, ys[0], 0.80, r, 0.28)
    axle_pair(a, ys[1], 0.80, r, 0.28)
    fender_set(a, ys, 0.80, r, 0.28, "paint_white")

    # sculpted cab + hood (one loft: bumper -> nose -> hood -> windshield rake -> roof)
    P.shell(a, [
        (-2.92, P.body_profile(0.58, 0.76, 0.90, 0.88, 0.88)),
        (-2.72, P.body_profile(0.90, 0.72, 1.00, 0.84, 0.90)),
        (-2.34, P.body_profile(0.97, 0.70, 1.12, 0.80, 0.91)),
        (-1.76, P.body_profile(0.98, 0.70, 1.21, 0.80, 0.92)),
        (-1.46, P.body_profile(0.98, 0.70, 1.26, 0.80, 0.92)),
        (-1.22, P.body_profile(0.96, 0.70, 1.74, 0.82, 0.88)),
        (-0.58, P.body_profile(0.95, 0.70, 1.84, 0.84, 0.86)),
        (0.14, P.body_profile(0.94, 0.70, 1.82, 0.84, 0.86)),
        (0.26, P.body_profile(0.90, 0.72, 1.68, 0.86, 0.88)),
    ], "paint_white")

    # windshield (slab on the raked face)
    a.box((1.62, 0.56, 0.05), (0, -1.34, 1.49), "glass_dark", rot=(math.radians(63), 0, 0))
    # side glass + pillars + handles
    for s in (-1, 1):
        a.box((0.05, 1.10, 0.40), (s * 0.905, -0.55, 1.55), "glass_dark")
        a.box((0.05, 0.09, 0.52), (s * 0.930, -1.14, 1.50), "paint_white")
        a.box((0.05, 0.09, 0.52), (s * 0.930, 0.06, 1.50), "paint_white")
        a.box((0.05, 0.18, 0.05), (s * 0.945, -0.32, 1.16), "chrome")
        a.beam((s * 0.92, -1.20, 1.44), (s * 1.11, -1.24, 1.38), 0.05, "steel_dark")
        a.box((0.07, 0.20, 0.30), (s * 1.13, -1.24, 1.32), "steel_dark")

    # front grille, bumper, lights
    a.box((1.36, 0.05, 0.30), (0, -2.93, 0.98), "steel_dark")
    for i in range(3):
        a.box((1.30, 0.04, 0.045), (0, -2.96, 0.90 + i * 0.10), "chrome")
    a.box((W - 0.06, 0.20, 0.24), (0, -2.92, 0.64), "paint_grey", bevel=0.05)
    headlights(a, -2.93, 1.06, 0.66, w=0.36, h=0.18)
    for s in (-1, 1):
        a.box((0.16, 0.05, 0.11), (s * 0.86, -2.95, 0.66), "emit_amber")

    # bed (rounded rails)
    a.box((W - 0.04, 2.28, 0.10), (0, 1.46, 0.88), "steel_dark")
    for s in (-1, 1):
        a.box((0.09, 2.28, 0.46), (s * (W / 2 - 0.06), 1.46, 1.15), "paint_white", bevel=0.05)
        a.cyl(0.055, 2.28, (s * (W / 2 - 0.06), 1.46, 1.38), "paint_white", seg=8, rot=(math.pi / 2, 0, 0))
    a.box((W - 0.04, 0.09, 0.46), (0, 2.62, 1.15), "paint_white")
    a.box((W - 0.04, 0.09, 0.44), (0, 0.34, 1.13), "paint_white")
    a.cyl(0.055, W - 0.08, (0, 2.62, 1.38), "paint_white", seg=8, rot=(0, math.pi / 2, 0))
    a.box((W - 0.06, 0.18, 0.22), (0, 2.70, 0.64), "paint_grey", bevel=0.04)
    taillights(a, 2.70, 1.12)
    a.box((0.42, 0.04, 0.16), (0, 2.76, 0.82), "paint_white")
    beacon(a, (0, -0.50, 1.86))

    # mud flaps
    for s in (-1, 1):
        for y in (1.98, -1.34):
            a.box((0.34, 0.04, 0.36), (s * 0.80, y, 0.30), "rubber")

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    for s in (-1, 1):
        a.beam((s * 0.82, -0.55, 1.84), (s * 0.82, 0.20, 1.84), 0.05, "steel_dark")
        a.box((0.12, 1.30, 0.08), (s * 0.92, 0.62, 0.72), "steel_dark")
        a.box((0.10, 0.10, 0.10), (s * 0.92, 0.62, 0.70), "chrome")
    for i in range(3):
        a.box((W - 0.16, 0.06, 0.05), (0, 0.55 + i * 0.55, 0.93), "steel_dark")
    a.box((0.30, 0.34, 0.22), (0, 2.82, 0.52), "steel_dark")


def crew_car(a: Asset):
    L, W, r = 4.7, 1.90, 0.35
    frame_rails(a, 4.1, 0.95, 0.55)
    ys = (-1.45, 1.48)
    axle_pair(a, ys[0], 0.80, r, 0.25)
    axle_pair(a, ys[1], 0.80, r, 0.25)
    fender_set(a, ys, 0.80, r, 0.25, "paint_white")
    # lower body (wide, up to the belt line)
    P.shell(a, [
        (-2.36, P.body_profile(0.66, 0.54, 0.82, 0.90, 0.90)),
        (-2.20, P.body_profile(0.87, 0.50, 0.94, 0.84, 0.90)),
        (-1.78, P.body_profile(0.93, 0.48, 1.02, 0.82, 0.92)),
        (-1.30, P.body_profile(0.95, 0.48, 1.06, 0.82, 0.92)),
        (0.90, P.body_profile(0.95, 0.48, 1.06, 0.82, 0.92)),
        (1.62, P.body_profile(0.93, 0.48, 1.04, 0.82, 0.92)),
        (2.08, P.body_profile(0.88, 0.50, 0.98, 0.84, 0.90)),
        (2.26, P.body_profile(0.78, 0.54, 0.88, 0.88, 0.90)),
    ], "paint_white")
    # greenhouse (narrower, with tumblehome)
    P.shell(a, [
        (-1.10, P.body_profile(0.86, 1.02, 1.30, 0.90, 0.86, 0.74)),
        (-0.92, P.body_profile(0.88, 1.02, 1.50, 0.90, 0.86, 0.78)),
        (-0.20, P.body_profile(0.88, 1.02, 1.56, 0.90, 0.86, 0.80)),
        (0.95, P.body_profile(0.88, 1.02, 1.54, 0.90, 0.86, 0.78)),
        (1.42, P.body_profile(0.86, 1.02, 1.34, 0.90, 0.86, 0.72)),
        (1.58, P.body_profile(0.84, 1.02, 1.20, 0.90, 0.88, 0.70)),
    ], "paint_white")
    # glazing
    a.box((1.46, 0.50, 0.04), (0, -1.02, 1.28), "glass_dark", rot=(math.radians(56), 0, 0))
    a.box((1.36, 0.44, 0.04), (0, 1.50, 1.24), "glass_dark", rot=(math.radians(-58), 0, 0))
    for s in (-1, 1):
        a.box((0.04, 1.62, 0.38), (s * 0.875, 0.15, 1.31), "glass_dark")
        a.box((0.05, 0.09, 0.44), (s * 0.878, -0.30, 1.30), "paint_white")
        a.box((0.05, 0.09, 0.44), (s * 0.878, 0.72, 1.30), "paint_white")
        a.box((0.05, 0.16, 0.05), (s * 0.955, 0.10, 1.02), "chrome")
        a.beam((s * 0.90, -0.92, 1.10), (s * 1.06, -0.95, 1.16), 0.05, "steel_dark")
        a.box((0.06, 0.15, 0.20), (s * 1.07, -0.95, 1.12), "steel_dark")
        for y in (1.70, -1.66):
            a.box((0.30, 0.04, 0.30), (s * 0.80, y, 0.26), "rubber")
    # bumpers, lights, grille
    a.box((W + 0.02, 0.22, 0.30), (0, -2.38, 0.58), "paint_grey", bevel=0.05)
    a.box((W + 0.02, 0.22, 0.28), (0, 2.38, 0.58), "paint_grey", bevel=0.05)
    a.box((1.06, 0.05, 0.18), (0, -2.35, 0.80), "steel_dark")
    headlights(a, -2.34, 0.74, 0.62, w=0.32)
    taillights(a, 2.18, 0.78, 0.48, w=0.22, h=0.18)
    # roof rails + beacon
    for s in (-1, 1):
        a.beam((s * 0.60, -0.9, 1.60), (s * 0.60, 1.0, 1.60), 0.05, "galv")
    beacon(a, (0, -0.1, 1.58))


def crew_bus(a: Asset):
    L, W, r = 10.6, 2.52, 0.50
    frame_rails(a, 9.6, 1.1, 0.62)
    ys = (-3.55, 3.30)
    axle_pair(a, ys[0], 1.04, r, 0.34)
    axle_pair(a, ys[1], 1.04, r, 0.34, dual=True)
    fender_set(a, ys, 1.04, r, 0.34, "paint_white")
    # body shell (lofted: rounded roof, tapered ends)
    P.shell(a, [
        (-5.20, P.body_profile(1.08, 0.62, 2.46, 0.94, 0.90, 0.92)),
        (-5.00, P.body_profile(1.24, 0.58, 2.62, 0.92, 0.94, 1.10)),
        (-4.40, P.body_profile(1.26, 0.58, 2.66, 0.92, 0.95, 1.16)),
        (0.10, P.body_profile(1.26, 0.58, 2.66, 0.92, 0.95, 1.18)),
        (4.60, P.body_profile(1.26, 0.58, 2.66, 0.92, 0.95, 1.16)),
        (5.05, P.body_profile(1.24, 0.58, 2.62, 0.92, 0.94, 1.10)),
        (5.25, P.body_profile(1.08, 0.62, 2.46, 0.94, 0.90, 0.92)),
    ], "paint_white")
    a.box((W - 0.12, L - 0.4, 0.34), (0, 0.1, 0.68), "paint_grey")
    a.box((W - 0.20, L - 0.6, 0.12), (0, 0.1, 2.68), "paint_white")
    # window band + pillars (proud of the body so it never z-fights)
    for s in (-1, 1):
        a.box((0.06, L - 1.2, 0.78), (s * (W / 2 + 0.01), 0.1, 2.10), "glass_dark")
        n = 8
        for i in range(n + 1):
            yy = 0.1 - (L - 1.2) / 2 + i * (L - 1.2) / n
            a.box((0.09, 0.12, 0.82), (s * (W / 2 + 0.02), yy, 2.10), "paint_white")
    # front + rear glazing
    a.box((W - 0.24, 0.08, 0.85), (0, -L / 2 + 0.03, 2.05), "glass_dark")
    a.box((W - 0.30, 0.08, 0.75), (0, L / 2 - 0.03, 2.02), "glass_dark")
    # door (kerb side)
    a.box((0.07, 1.0, 1.85), (W / 2 + 0.005, -3.55, 1.58), "paint_grey")
    a.box((0.09, 0.9, 0.75), (W / 2 + 0.015, -3.55, 2.10), "glass_dark")
    # destination sign, lights, bumpers
    a.box((1.7, 0.05, 0.26), (0, -L / 2 - 0.02, 2.62), "emit_amber")
    headlights(a, -L / 2 - 0.06, 1.02, 0.86, w=0.34)
    taillights(a, L / 2 + 0.05, 1.20, 0.95, w=0.24, h=0.46)
    a.box((W + 0.02, 0.24, 0.36), (0, -L / 2 - 0.10, 0.60), "steel_dark", bevel=0.03)
    a.box((W + 0.02, 0.22, 0.32), (0, L / 2 + 0.10, 0.60), "steel_dark", bevel=0.03)
    # roof kit
    a.box((1.8, 3.0, 0.30), (0, 1.9, 2.84), "galv", bevel=0.04)
    a.box((0.9, 1.0, 0.22), (0, -2.2, 2.82), "paint_grey")
    # mirrors + wheels flaps
    for s in (-1, 1):
        a.beam((s * W / 2, -4.9, 2.55), (s * (W / 2 + 0.34), -4.95, 2.45), 0.05, "steel_dark")
        a.box((0.06, 0.18, 0.42), (s * (W / 2 + 0.36), -4.95, 2.35), "steel_dark")
        for y in (3.95, -2.90):
            a.box((0.40, 0.05, 0.50), (s * 1.04, y, 0.34), "rubber")


# --------------------------------------------------------------------------- #
# heavy trucks
# --------------------------------------------------------------------------- #


def fuel_tanker(a: Asset):
    L, W, r = 10.4, 2.50, 0.52
    frame_rails(a, 9.4, 1.1, 0.66)
    ys = (-3.90, 2.55, 3.75)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_orange")
    P.truck_cab(a, (0, -4.20, 0.95), 2.44, 2.25, 2.30, "paint_orange", sleeper=True)
    # tank
    a.cyl(1.02, 6.60, (0, 0.95, 2.05), "paint_white", seg=24, rot=(math.pi / 2, 0, 0))
    a.dome((0, 4.25, 2.05), 1.02, 0.42, "Y", "paint_white", seg=24, rings=4)
    a.dome((0, -2.35, 2.05), 1.02, 0.30, "Y", "paint_white", seg=24, rings=4)
    for i in range(3):
        a.cyl(1.03, 0.09, (0, -1.3 + i * 2.2, 2.05), "steel_dark", seg=24, rot=(math.pi / 2, 0, 0))
    # catwalk + rails + ladder
    a.box((0.9, 5.4, 0.08), (0, 0.95, 3.10), "galv")
    for s in (-1, 1):
        a.beam((s * 0.44, -1.6, 3.14), (s * 0.44, 3.4, 3.14), 0.05, "galv")
        a.beam((s * 0.44, -1.6, 3.60), (s * 0.44, 3.4, 3.60), 0.04, "galv")
        for y in (-1.4, 0.2, 1.8, 3.2):
            a.beam((s * 0.44, y, 3.14), (s * 0.44, y, 3.62), 0.04, "galv")
    for i in range(5):
        a.beam((-0.30, 4.15, 0.55 + i * 0.52), (0.30, 4.15, 0.55 + i * 0.52), 0.05, "galv")
    # valves + hose cabinet + placard
    a.box((1.1, 1.0, 0.7), (1.15, 1.2, 1.25), "galv", bevel=0.03)
    a.cyl(0.16, 0.9, (0.0, 3.9, 1.35), "chrome", seg=10, rot=(0, math.pi / 2, 0))
    a.box((0.34, 0.34, 0.34), (0, 3.05, 0.95), "paint_red", rot=(0, 0, math.pi / 4))
    # rear bumper + lights + flaps
    a.box((W, 0.22, 0.3), (0, 4.55, 0.6), "steel_dark", bevel=0.03)
    taillights(a, 4.66, 0.85, 0.92, w=0.22, h=0.34)
    for s in (-1, 1):
        a.box((0.42, 0.05, 0.55), (s * 1.04, 4.30, 0.36), "rubber")
    a.box((0.7, 2.2, 0.06), (0.0, 0.2, 0.70), "steel_dark")
    for s in (-1, 1):
        a.box((0.52, 1.9, 0.07), (s * 1.05, 3.15, 1.00), "steel_dark")
    exhaust(a, (1.24, -3.0, 0.95), 1.7)

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # rear ladder side rails + side marker lamps
    for s in (-1, 1):
        a.beam((s * 0.30, 4.05, 0.55), (s * 0.30, 4.05, 3.10), 0.04, "galv")
        a.box((0.24, 0.10, 0.26), (s * 0.90, 4.60, 0.92), "emit_red")
    # hose tray under the barrel + rear underride guard
    a.box((1.5, 3.2, 0.16), (0, 0.8, 0.95), "galv")
    a.box((2.2, 0.12, 0.45), (0, 4.72, 0.38), "galv")
    # band bolt heads around the barrel
    for i in range(3):
        for k in range(8):
            ang = k * math.tau / 8.0
            a.cyl(0.035, 0.08, (1.05 * math.cos(ang), -1.3 + i * 2.2,
                                2.05 + 1.05 * math.sin(ang)), "steel_dark", seg=5)


def vacuum_truck(a: Asset):
    L, W, r = 10.2, 2.50, 0.52
    frame_rails(a, 9.2, 1.1, 0.66)
    ys = (-3.85, 2.50, 3.70)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_green")
    P.truck_cab(a, (0, -4.15, 0.95), 2.44, 2.25, 2.30, "paint_green", sleeper=False)
    # vacuum barrel with domed rear door
    a.cyl(1.08, 6.9, (0, 1.0, 2.05), "stainless", seg=24, rot=(math.pi / 2, 0, 0))
    a.dome((0, -2.45, 2.05), 1.08, 0.34, "Y", "stainless", seg=24, rings=4)
    a.cyl(1.14, 0.28, (0, 4.45, 2.05), "steel_dark", seg=24, rot=(math.pi / 2, 0, 0))
    a.dome((0, 4.45, 2.05), 1.02, 0.30, "Y", "paint_grey", seg=24, rings=4, inward=True)
    for i in range(3):
        a.cyl(1.09, 0.09, (0, -1.3 + i * 2.5, 2.05), "steel_dark", seg=24, rot=(math.pi / 2, 0, 0))
    # rear door hinges + hose reel + boom
    for i in range(4):
        a.cyl(0.09, 0.36, (-0.95 + i * 0.63, 4.62, 2.05), "steel_dark", seg=8, rot=(math.pi / 2, 0, 0))
    a.cyl(0.55, 0.42, (0, 4.95, 1.15), "paint_yellow", seg=14, rot=(0, math.pi / 2, 0))
    a.beam((0, 4.3, 2.9), (0, 5.6, 3.8), 0.16, "paint_yellow")
    a.cyl(0.18, 0.6, (0, 5.65, 3.85), "steel_dark", seg=10)
    # side toolboxes + ladder
    a.box((0.5, 1.6, 0.7), (1.20, 0.4, 1.05), "galv", bevel=0.03)
    for i in range(5):
        a.beam((-0.34, 4.20, 0.55 + i * 0.5), (0.34, 4.20, 0.55 + i * 0.5), 0.05, "galv")
    taillights(a, 4.72, 0.85, 0.92, w=0.22, h=0.34)
    a.box((W, 0.22, 0.3), (0, 4.60, 0.6), "steel_dark", bevel=0.03)
    exhaust(a, (1.24, -2.95, 0.95), 1.7)


def crane_truck(a: Asset):
    L, W, r = 11.6, 2.55, 0.55
    frame_rails(a, 10.6, 1.2, 0.70)
    ys = (-4.45, 2.45, 3.75)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.06, r, 0.36, dual=(i > 0))
    fender_set(a, (ys[0],), 1.06, r, 0.36, "paint_yellow")
    P.truck_cab(a, (0, -4.55, 1.00), 2.46, 2.20, 2.25, "paint_yellow")
    # carrier deck + outriggers
    a.box((W, 6.0, 0.30), (0, 1.2, 1.02), "steel_dark")
    a.box((W, 2.2, 0.26), (0, -2.55, 1.00), "steel_dark")
    for y in (-2.0, 2.6):
        for s in (-1, 1):
            a.box((1.9, 0.42, 0.30), (s * 1.55, y, 0.62), "steel_dark")
            a.beam((s * 1.2, y, 0.78), (s * 2.45, y, 0.62), 0.20, "steel_dark")
            a.beam((s * 2.45, y, 0.62), (s * 2.45, y, 0.16), 0.15, "steel_dark")
            a.cyl(0.30, 0.14, (s * 2.45, y, 0.15), "steel_dark", seg=12)
    # turret + operator cab + counterweight
    a.cyl(1.15, 0.55, (0, 0.9, 1.40), "steel_dark", seg=20)
    a.box((2.20, 2.40, 1.15), (0, 1.75, 2.20), "paint_yellow", bevel=0.06)
    a.box((0.95, 1.0, 1.05), (-1.05, 0.65, 2.20), "paint_yellow", bevel=0.05)
    a.box((0.85, 0.85, 0.75), (-1.10, 0.62, 2.25), "glass_dark", bevel=0.03)
    a.box((2.20, 1.05, 1.00), (0, 3.05, 1.95), "concrete_dark", bevel=0.05)
    # telescopic boom, stowed over the cab
    a.beam((0, 0.95, 2.95), (0, -5.4, 3.45), 0.66, "paint_yellow")
    a.beam((0, 0.90, 2.95), (0, -6.3, 3.55), 0.50, "paint_yellow")
    a.beam((0, 0.86, 2.95), (0, -7.0, 3.62), 0.36, "paint_yellow")
    a.box((0.9, 0.6, 0.5), (0, 1.55, 3.05), "steel_dark", bevel=0.03)
    # boom rest + hook block
    a.beam((0, -7.1, 3.62), (0, -7.1, 2.55), 0.10, "steel_dark")
    a.box((0.6, 0.5, 0.75), (0, -7.1, 2.85), "paint_red", bevel=0.04)
    a.sweep([(0, -7.1, 3.6), (0, -7.1, 3.3)], 0.06, "steel_dark", seg=6)
    # rear lights + flaps + beacon
    taillights(a, 4.55, 0.90, 0.95, w=0.22, h=0.32)
    a.box((W, 0.22, 0.3), (0, 4.45, 0.62), "steel_dark", bevel=0.03)
    for s in (-1, 1):
        a.box((0.42, 0.05, 0.5), (s * 1.06, 4.20, 0.34), "rubber")
    beacon(a, (0, 2.9, 2.48))
    exhaust(a, (1.28, -3.4, 1.0), 1.7)


def pipe_truck(a: Asset):
    L, W, r = 12.0, 2.50, 0.52
    frame_rails(a, 11.0, 1.1, 0.68)
    ys = (-4.30, 2.70, 3.90)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_blue")
    P.truck_cab(a, (0, -4.55, 0.95), 2.44, 2.25, 2.30, "paint_blue", sleeper=True)
    # flat deck
    a.box((W, 7.6, 0.16), (0, 1.5, 1.02), "wood")
    for s in (-1, 1):
        a.box((0.10, 7.6, 0.28), (s * (W / 2 - 0.05), 1.5, 0.92), "paint_blue")
        # stake pockets + stakes
        for i in range(5):
            yy = -2.0 + i * 1.7
            a.beam((s * 1.16, yy, 1.05), (s * 1.16, yy, 2.05), 0.11, "galv")
    # headache rack behind cab
    a.box((W - 0.1, 0.12, 1.0), (0, -2.25, 1.60), "galv")
    for i in range(4):
        a.box((0.10, 0.12, 0.9), (-0.9 + i * 0.6, -2.25, 1.55), "steel_dark")
    # payload
    P.pipe_load(a, (0, 1.4, 1.10), 7.0, 21, 0.14, "rust_patchy")
    # rear + beacon
    a.box((W + 0.02, 0.22, 0.30), (0, 5.45, 0.62), "steel_dark", bevel=0.03)
    taillights(a, 5.55, 0.95, 0.92, w=0.22, h=0.30)
    beacon(a, (0.8, -2.25, 2.12))
    exhaust(a, (1.24, -3.15, 0.95), 1.7)


def cementing_truck(a: Asset):
    L, W, r = 9.8, 2.50, 0.52
    frame_rails(a, 8.8, 1.1, 0.66)
    ys = (-3.70, 2.35, 3.55)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_red")
    P.truck_cab(a, (0, -3.95, 0.95), 2.44, 2.25, 2.30, "paint_red", sleeper=True)
    # skid + mixing tub
    P.skid(a, 6.0, 2.3, 0.26, loc=(0, 1.6, 1.00))
    a.box((2.24, 1.35, 1.20), (0, -2.05, 1.28), "paint_red", bevel=0.04)
    a.box((2.2, 2.0, 1.10), (-0.35, 2.1, 1.75), "paint_blue", bevel=0.05)
    a.cyl(0.62, 1.2, (-0.35, 3.35, 1.95), "paint_grey", seg=16)
    a.dome((-0.35, 3.35, 2.55), 0.62, 0.35, "Z", "paint_grey", seg=16, rings=3)
    # pump + engine + manifold
    a.box((1.5, 2.2, 1.4), (0.95, 1.0, 1.90), "paint_blue", bevel=0.05)
    a.cyl(0.34, 1.7, (1.65, 1.8, 1.55), "steel_dark", seg=14)
    a.cyl(0.14, 2.6, (0, 0.15, 1.45), "chrome", seg=10, rot=(0, math.pi / 2, 0))
    for s in (-1, 1):
        a.cyl(0.15, 0.8, (s * 1.0, 0.15, 1.45), "paint_red", seg=10)
        a.cyl(0.26, 0.18, (s * 1.0, 0.15, 1.90), "steel_dark", seg=10)
    P.gauge(a, (1.5, 1.6, 2.75), 0.10, (1, 0, 0))
    # hose reel + control panel
    a.cyl(0.55, 0.34, (0.9, 3.1, 2.55), "paint_yellow", seg=14, rot=(0, math.pi / 2, 0))
    a.box((0.9, 0.35, 1.1), (-1.05, 0.6, 1.90), "galv", bevel=0.03)
    # rear + lights
    a.box((W + 0.02, 0.22, 0.3), (0, 4.35, 0.60), "steel_dark", bevel=0.03)
    taillights(a, 4.45, 0.90, 0.92, w=0.22, h=0.30)
    beacon(a, (-0.35, -0.2, 2.65))
    exhaust(a, (1.24, -2.75, 0.95), 1.7)


def wireline_truck(a: Asset):
    L, W, r = 9.8, 2.50, 0.52
    frame_rails(a, 8.8, 1.1, 0.66)
    ys = (-3.75, 2.30, 3.50)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_white")
    P.truck_cab(a, (0, -4.00, 0.95), 2.44, 2.25, 2.30, "paint_white", sleeper=True)
    # equipment body
    box_truck_body(a, (0, 1.35, 1.02), 2.44, 6.1, 2.45, "paint_white", ribs=5)
    a.box((2.44, 1.30, 1.90), (0, -2.30, 1.52), "paint_white", bevel=0.05)
    a.box((2.46, 1.4, 0.9), (0, 1.2, 2.60), "paint_grey")
    # winch drum + mast
    a.cyl(0.62, 2.1, (0, 3.55, 1.60), "steel_light", seg=16, rot=(0, math.pi / 2, 0))
    a.box((2.2, 0.7, 0.5), (0, 3.55, 2.20), "paint_white")
    a.box((1.1, 1.1, 0.35), (0, 3.85, 2.55), "steel_dark", bevel=0.03)
    for s in (-1, 1):
        a.beam((s * 0.5, 3.45, 2.55), (0, 3.85, 4.65), 0.10, "steel_dark")
    a.beam((0, 3.85, 2.45), (0, 3.85, 6.30), 0.26, "paint_orange")
    a.beam((0, 3.85, 6.30), (0, 5.25, 5.30), 0.20, "paint_orange")
    a.cyl(0.22, 0.14, (0, 3.85, 6.42), "steel_dark", seg=12, rot=(0, math.pi / 2, 0))
    a.cyl(0.18, 0.50, (0, 5.35, 5.20), "steel_dark", seg=10)
    a.sweep([(0, 5.35, 5.0), (0, 5.35, 4.4)], 0.02, "steel_dark", seg=4)
    # control cab window + steps + rear
    a.box((0.9, 0.06, 0.7), (-1.24, 1.0, 1.85), "glass_dark")
    a.box((W + 0.02, 0.22, 0.3), (0, 4.45, 0.60), "steel_dark", bevel=0.03)
    taillights(a, 4.55, 0.92, 0.92, w=0.22, h=0.30)
    beacon(a, (0, 2.2, 2.55))
    exhaust(a, (1.24, -2.80, 0.95), 1.7)

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # body handrails + access door and handle
    for s in (-1, 1):
        a.beam((s * 0.95, 3.55, 1.05), (s * 0.95, 3.55, 2.15), 0.06, "galv")
        a.beam((s * 0.95, 1.00, 1.05), (s * 0.95, 1.00, 2.15), 0.06, "galv")
    a.box((0.75, 0.06, 0.95), (1.24, 1.0, 1.60), "paint_grey")
    a.cyl(0.05, 1.2, (1.27, 1.35, 1.95), "steel_dark", seg=5)
    # winch drum guard + rear stabiliser jacks
    a.box((2.0, 0.08, 0.55), (0, 4.10, 2.05), "galv")
    for s in (-1, 1):
        a.beam((s * 0.90, 4.20, 0.60), (s * 1.15, 4.60, 0.15), 0.14, "steel_dark")
        a.box((0.30, 0.30, 0.12), (s * 1.15, 4.60, 0.10), "steel_dark")
    # mast work lights
    for s in (-1, 1):
        a.box((0.18, 0.10, 0.16), (s * 0.50, 3.85, 6.35), "emit_amber")


def frac_pump_trailer(a: Asset):
    L, W, r = 7.6, 2.55, 0.50
    # trailer bed + 3 axles
    a.box((W, L, 0.24), (0, 0, 0.95), "steel_dark")
    for y in (1.55, 2.65):
        axle_pair(a, y, 1.05, r, 0.34, dual=True)
        for s in (-1, 1):
            P.fender_arch(a, (s * 1.05, y, r), r + 0.06, 0.40, "paint_blue")
    # gooseneck + landing legs
    a.box((1.0, 1.5, 0.2), (0, -3.4, 0.95), "steel_dark")
    a.beam((0, -4.05, 0.85), (0, -4.05, 0.35), 0.14, "steel_dark")
    for s in (-1, 1):
        a.cyl(0.12, 0.8, (s * 0.9, -2.4, 0.55), "steel_dark", seg=8)
    # engine + transmission + pump
    a.box((1.55, 2.4, 1.5), (0, -0.55, 1.85), "paint_blue", bevel=0.06)
    a.box((1.0, 1.1, 0.9), (0, 1.0, 1.75), "galv", bevel=0.04)
    a.cyl(0.48, 1.7, (0, 1.9, 1.55), "steel_dark", seg=16, rot=(0, math.pi / 2, 0))
    a.cyl(0.30, 1.0, (0.85, 1.9, 1.55), "steel_light", seg=12, rot=(0, math.pi / 2, 0))
    # radiator + exhaust
    a.box((1.4, 0.25, 1.2), (-0.75, -1.75, 1.80), "galv")
    exhaust(a, (0.6, -1.5, 1.2), 1.6, 0.08, "steel_dark")
    # discharge manifold + valves + gauges
    a.cyl(0.16, 2.6, (0, -2.9, 1.55), "chrome", seg=10, rot=(0, math.pi / 2, 0))
    for s in (-1, 1):
        a.cyl(0.20, 1.0, (s * 1.0, -2.9, 1.55), "paint_red", seg=10)
        a.cyl(0.34, 0.20, (s * 1.0, -2.9, 2.10), "steel_dark", seg=10)
    P.gauge(a, (0.55, -2.2, 2.55), 0.11, (0, 1, 0))
    P.gauge(a, (-0.55, -2.2, 2.55), 0.11, (0, 1, 0))
    # control panel + hose tray
    a.box((1.1, 0.5, 1.3), (1.0, -1.0, 1.75), "galv", bevel=0.03)
    a.box((0.9, 0.06, 0.5), (1.0, -1.27, 2.0), "glass_dark")
    a.box((1.5, 1.6, 0.10), (-0.9, 0.4, 1.62), "steel_dark")
    for tx in (-1.55, -0.25):
        for ty in (-0.3, 1.1):
            a.beam((tx, ty, 1.62), (tx, ty, 1.10), 0.06, "steel_dark")
    a.cyl(0.42, 1.2, (-0.9, 0.4, 1.72), "rubber", seg=12, rot=(0, math.pi / 2, 0))


def fire_truck(a: Asset):
    L, W, r = 9.6, 2.50, 0.52
    frame_rails(a, 8.6, 1.1, 0.66)
    ys = (-3.70, 2.40, 3.60)
    for i, y in enumerate(ys):
        axle_pair(a, y, 1.04, r, 0.34, dual=(i > 0))
    fender_set(a, (ys[0],), 1.04, r, 0.34, "paint_red")
    P.truck_cab(a, (0, -3.95, 0.95), 2.44, 2.25, 2.30, "paint_red")
    # body with lockers
    a.box((W, 6.0, 2.10), (0, 1.25, 1.85), "paint_red", bevel=0.07)
    # pump module filling the cab/body gap
    a.box((W - 0.10, 1.25, 1.70), (0, -2.25, 1.55), "paint_red", bevel=0.05)
    a.box((0.9, 0.06, 0.9), (0.6, -2.89, 1.75), "galv")
    for i in range(3):
        a.cyl(0.11, 0.30, (0.35 + i * 0.28, -2.90, 1.55), "chrome", seg=8, rot=(math.pi / 2, 0, 0))
    for s in (-1, 1):
        for i in range(3):
            yy = -0.6 + i * 1.65
            a.box((0.06, 1.45, 0.9), (s * (W / 2 + 0.01), yy, 1.55), "galv")
            a.box((0.10, 0.55, 0.07), (s * (W / 2 + 0.03), yy, 1.55), "chrome")
        # chevron stripe
        a.box((0.05, 5.6, 0.18), (s * (W / 2 + 0.02), 1.25, 2.72), "paint_yellow")
    # roof ladder + monitor + light bar
    for i in range(6):
        a.beam((-0.55, -1.4 + i * 0.9, 2.95), (0.55, -1.4 + i * 0.9, 2.95), 0.07, "galv")
    for s in (-1, 1):
        a.beam((s * 0.55, -1.6, 2.95), (s * 0.55, 4.2, 2.95), 0.07, "galv")
    a.cyl(0.24, 0.7, (0, -0.4, 3.30), "paint_yellow", seg=10)
    a.beam((0, -0.4, 3.4), (0, -1.7, 3.6), 0.18, "chrome")
    a.box((1.6, 0.30, 0.22), (0, -1.9, 3.02), "paint_red")
    for i in range(4):
        a.box((0.34, 0.06, 0.18), (-0.6 + i * 0.4, -2.06, 3.02), "emit_red")
    # rear + lights
    a.box((W + 0.02, 0.22, 0.34), (0, 4.38, 0.62), "steel_dark", bevel=0.03)
    taillights(a, 4.48, 0.95, 0.92, w=0.24, h=0.34)
    beacon(a, (0, 3.4, 2.95))
    exhaust(a, (1.24, -2.75, 0.95), 1.5)


# --------------------------------------------------------------------------- #
# heavy equipment
# --------------------------------------------------------------------------- #


def track_assembly(a: Asset, loc, length, gauge, shoe_w, track_h=0.95, mat="rubber"):
    """Two crawler tracks with individual shoes, road wheels and sprockets."""
    x, y, z = P.xyz(loc)
    r = track_h / 2
    cz = z + r
    straight = length - track_h

    def loop(u):
        """u in [0,1) around a stadium-shaped path in (y,z)."""
        per = 2 * straight + 2 * math.pi * r
        d = u * per
        if d < straight:
            return (-straight / 2 + d, -r, 1)      # bottom run, +y
        d -= straight
        if d < math.pi * r:
            ang = -math.pi / 2 + d / r
            return (straight / 2 + math.cos(ang) * r, math.sin(ang) * r, 0)
        d -= math.pi * r
        if d < straight:
            return (straight / 2 - d, r, -1)       # top run, -y
        d -= straight
        ang = math.pi / 2 + d / r
        return (-straight / 2 + math.cos(ang) * r, math.sin(ang) * r, 0)

    for s in (-1, 1):
        cx = x + s * gauge / 2
        n = 40
        shoe_len = (2 * straight + 2 * math.pi * r) / n * 1.04
        for i in range(n):
            u = i / n
            py, pz, _ = loop(u)
            py2, pz2, _ = loop((i + 0.5) / n)
            ang = math.atan2(pz2 - pz, py2 - py) if (py2 - py) or (pz2 - pz) else 0.0
            a.box((shoe_w, shoe_len, 0.09),
                  (cx, y + py, cz + pz), mat,
                  rot=(ang, 0, 0))
        # track frame + road wheels + sprocket/idler
        a.box((shoe_w * 0.72, straight * 0.86, 0.42), (cx, y, cz), "steel_dark")
        for i in range(4):
            wy = y - straight * 0.3 + i * straight * 0.2
            a.cyl(r * 0.42, shoe_w * 0.8, (cx, wy, cz - r * 0.35), "steel_light", seg=12, rot=(0, math.pi / 2, 0))
        for sy in (-1, 1):
            a.cyl(r * 0.55, shoe_w * 0.9, (cx, y + sy * straight / 2, cz), "steel_light",
                  seg=14, rot=(0, math.pi / 2, 0))
    return z + track_h


def excavator(a: Asset):
    z0 = track_assembly(a, (0, 0, 0), 4.4, 2.35, 0.66, 1.0, "rubber")
    # slew ring + house
    a.cyl(1.15, 0.35, (0, 0.2, z0 + 0.18), "steel_dark", seg=18)
    a.box((2.30, 3.10, 1.35), (0, 0.25, z0 + 0.95), "paint_yellow", bevel=0.08)
    a.box((2.34, 1.1, 1.15), (0, 1.95, z0 + 0.95), "paint_grey", bevel=0.06)
    # cab
    a.box((1.10, 1.65, 1.55), (-0.62, -0.45, z0 + 1.85), "paint_yellow", bevel=0.06)
    a.box((1.12, 0.07, 0.82), (-0.62, -1.28, z0 + 2.05), "glass_dark")
    for s in (-1, 1):
        a.box((0.07, 1.42, 0.82), (-0.62 + s * 0.56, -0.50, z0 + 2.05), "glass_dark")
    # boom, stick, bucket
    boom_root = V((0, -1.15, z0 + 1.45))
    boom_mid = V((0, -3.30, z0 + 3.30))
    stick_end = V((0, -5.30, z0 + 1.55))
    a.beam(boom_root, boom_mid, 0.62, "paint_yellow", h=0.72)
    a.beam(boom_mid, stick_end, 0.46, "paint_yellow", h=0.55)
    a.cyl(0.30, 0.30, (0, boom_mid.y, boom_mid.z), "paint_yellow", seg=12, rot=(0, math.pi / 2, 0))
    # hydraulic cylinders
    a.cyl(0.16, 1.9, (0, -1.75, z0 + 2.35), "chrome", seg=10,
          axis=(0, -0.55, 1.0))
    a.cyl(0.13, 1.5, (0, -4.05, z0 + 2.55), "chrome", seg=10,
          axis=(0, -0.7, -0.7))
    # bucket with teeth
    a.box((1.45, 1.30, 0.95), (0, -5.75, z0 + 0.55), "steel_dark", bevel=0.08)
    for i in range(5):
        a.box((0.16, 0.42, 0.14), (-0.56 + i * 0.28, -6.35, z0 + 0.20), "steel_light")
    a.beam(stick_end, (0, -5.55, z0 + 0.75), 0.28, "paint_yellow")
    # handrails, exhaust, counterweight
    for s in (-1, 1):
        a.beam((s * 1.02, -0.4, z0 + 1.70), (s * 1.02, 0.9, z0 + 1.70), 0.05, "galv")
        a.beam((s * 1.02, 0.9, z0 + 1.70), (s * 1.02, 0.9, z0 + 2.30), 0.05, "galv")
    exhaust(a, (0.85, 0.95, z0 + 1.35), 0.9, 0.07, "steel_dark")
    a.cyl(0.06, 0.9, (-1.05, 0.55, z0 + 2.55), "galv", seg=8)


def wheel_loader(a: Asset):
    r = 0.78
    for y in (-1.55, 1.45):
        axle_pair(a, y, 1.12, r, 0.52)
        for s in (-1, 1):
            P.fender_arch(a, (s * 1.12, y, r), r + 0.10, 0.62, "paint_yellow")
    # rear body + engine hood
    a.box((2.10, 2.10, 1.15), (0, 1.35, 1.25), "paint_yellow", bevel=0.08)
    a.box((1.85, 1.45, 0.55), (0, 1.55, 2.10), "paint_yellow", bevel=0.06)
    # articulated joint + front body
    a.cyl(0.45, 0.9, (0, 0.0, 1.05), "steel_dark", seg=14)
    a.box((1.55, 1.15, 0.85), (0, -0.75, 1.25), "paint_yellow", bevel=0.06)
    # cab + ROPS
    a.box((1.18, 1.28, 1.35), (0, 0.45, 2.18), "paint_yellow", bevel=0.06)
    a.box((1.04, 0.07, 0.82), (0, -0.19, 2.30), "glass_dark")
    for s in (-1, 1):
        a.box((0.07, 1.02, 0.78), (s * 0.56, 0.45, 2.30), "glass_dark")
    for s in (-1, 1):
        a.beam((s * 0.60, -0.05, 1.75), (s * 0.60, 1.15, 1.75), 0.07, "paint_yellow")
        a.beam((s * 0.60, 1.15, 1.75), (s * 0.60, 1.15, 2.95), 0.07, "paint_yellow")
    a.box((1.34, 1.40, 0.10), (0, 0.45, 2.92), "paint_yellow")
    # loader arms + bucket
    for s in (-1, 1):
        a.beam((s * 0.85, -0.6, 1.55), (s * 0.85, -3.45, 2.55), 0.34, "paint_yellow")
        a.beam((s * 0.85, -3.45, 2.55), (s * 0.85, -4.30, 1.30), 0.28, "paint_yellow")
    a.cyl(0.14, 1.8, (0, -1.5, 1.55), "chrome", seg=10, axis=(0, -0.8, 0.6))
    a.cyl(0.14, 1.8, (-0.9, -1.5, 1.90), "chrome", seg=10, axis=(0, -0.8, 0.55))
    a.box((2.55, 1.05, 1.05), (0, -4.65, 0.95), "steel_dark", bevel=0.06)
    for i in range(7):
        a.box((0.16, 0.30, 0.16), (-0.96 + i * 0.32, -5.25, 0.62), "steel_light")
    exhaust(a, (0.72, 1.9, 2.35), 1.0, 0.07, "steel_dark")


def bulldozer(a: Asset):
    z0 = track_assembly(a, (0, 0, 0), 4.6, 2.45, 0.75, 1.05, "rubber")
    # body + cab
    a.box((2.15, 3.20, 1.15), (0, 0.15, z0 + 0.75), "paint_yellow", bevel=0.08)
    a.box((1.45, 1.65, 1.45), (0, 0.75, z0 + 1.95), "paint_yellow", bevel=0.07)
    a.box((1.32, 1.45, 0.95), (0, 0.80, z0 + 2.08), "glass_dark", bevel=0.04)
    a.box((1.50, 1.70, 0.10), (0, 0.75, z0 + 2.72), "paint_yellow")
    # blade
    a.box((3.55, 0.42, 1.55), (0, -3.55, z0 + 0.55), "paint_yellow", bevel=0.06)
    a.box((3.55, 0.30, 0.35), (0, -3.75, z0 - 0.18), "steel_dark", bevel=0.03)
    a.beam((0, -3.35, z0 + 1.25), (0, -2.85, z0 + 1.35), 0.30, "steel_dark")
    for s in (-1, 1):
        a.beam((s * 1.15, -1.15, z0 + 0.35), (s * 1.25, -3.45, z0 + 0.45), 0.42, "steel_dark")
        a.cyl(0.14, 1.6, (s * 0.75, -1.9, z0 + 0.9), "chrome", seg=8, axis=(0, -0.9, 0.35))
    # ripper at the rear
    a.beam((0, 1.85, z0 + 0.45), (0, 3.25, z0 - 0.25), 0.32, "steel_dark")
    a.box((1.55, 0.28, 0.75), (0, 3.35, z0 - 0.55), "steel_dark", bevel=0.04)
    for i in range(3):
        a.box((0.22, 0.25, 1.0), (-0.45 + i * 0.45, 3.45, z0 - 0.95), "steel_light")
    exhaust(a, (0.65, 1.55, z0 + 1.45), 1.0, 0.07, "steel_dark")
    beacon(a, (0, 0.75, z0 + 2.82))

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # blade stiffener ribs
    for i in range(5):
        a.box((0.10, 0.10, 1.20), (-1.40 + i * 0.70, -3.78, z0 + 0.55),
              "steel_dark", bevel=0.01)
    # track guards, work lights, hydraulic hoses, safety decal
    for s in (-1, 1):
        a.box((0.55, 3.00, 0.12), (s * 1.20, 0.10, z0 + 1.45), "paint_yellow")
        a.box((0.18, 0.10, 0.16), (s * 0.55, 0.55, z0 + 2.82), "emit_amber")
        a.sweep([(s * 0.75, -1.20, z0 + 1.10), (s * 0.90, -1.70, z0 + 0.90),
                 (s * 0.95, -2.20, z0 + 0.70)], 0.05, "steel_dark", seg=5)
    a.box((0.70, 0.06, 0.25), (-0.55, 0.14, z0 + 1.20), "paint_red")


def forklift(a: Asset):
    for s in (-1, 1):
        P.truck_wheel(a, (s * 0.70, 0.75, 0.42), 0.42, 0.30)
        P.truck_wheel(a, (s * 0.62, -1.05, 0.32), 0.32, 0.26)
        P.fender_arch(a, (s * 0.70, 0.75, 0.42), 0.49, 0.32, "paint_yellow")
    # chassis + counterweight
    a.box((1.35, 2.10, 0.85), (0, 0.15, 0.78), "paint_yellow", bevel=0.06)
    a.box((1.30, 1.05, 1.05), (0, 1.00, 1.30), "paint_grey", bevel=0.06)
    # seat + overhead guard
    a.box((0.55, 0.55, 0.35), (0, 0.30, 1.40), "plastic_black")
    a.box((0.55, 0.15, 0.55), (0, 0.58, 1.65), "plastic_black")
    for s in (-1, 1):
        a.beam((s * 0.58, -0.35, 1.20), (s * 0.58, -0.35, 2.35), 0.07, "steel_dark")
        a.beam((s * 0.58, 0.85, 1.20), (s * 0.58, 0.85, 2.35), 0.07, "steel_dark")
        a.beam((s * 0.58, -0.35, 2.35), (s * 0.58, 0.85, 2.35), 0.07, "steel_dark")
    a.box((1.24, 1.30, 0.08), (0, 0.25, 2.38), "galv")
    # mast + carriage + forks
    for s in (-1, 1):
        a.beam((s * 0.32, -1.20, 0.25), (s * 0.32, -1.20, 2.45), 0.13, "steel_dark")
    a.box((0.95, 0.18, 0.65), (0, -1.38, 1.00), "galv")
    for s in (-1, 1):
        a.box((0.13, 1.35, 0.07), (s * 0.34, -2.05, 0.30), "steel_light")
    a.box((0.95, 0.12, 0.35), (0, -1.50, 0.42), "steel_dark")
    a.cyl(0.10, 1.6, (0, -1.05, 1.55), "chrome", seg=8)
    beacon(a, (0, 0.9, 2.45), 0.12)


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(
        aid="veh_pickup", name="Crew Pickup (4x4)", build=pickup,
        gameplay=dict(role="vehicle", tier=1, cost_usd=48_000, upkeep_usd_day=45,
                      crew=5, speed_kmh=140, capacity_t=0.8),
    ),
    dict(
        aid="veh_crew_bus", name="Crew Bus", build=crew_bus,
        gameplay=dict(role="vehicle", tier=1, cost_usd=180_000, upkeep_usd_day=190,
                      crew=45, speed_kmh=100, capacity_t=1.5),
    ),
    dict(
        aid="veh_fuel_tanker", name="Fuel Tanker", build=fuel_tanker,
        gameplay=dict(role="vehicle", tier=1, cost_usd=260_000, upkeep_usd_day=240,
                      crew=2, speed_kmh=90, capacity_bbl=220),
    ),
    dict(
        aid="veh_vacuum_truck", name="Vacuum / Water Truck", build=vacuum_truck,
        gameplay=dict(role="vehicle", tier=1, cost_usd=320_000, upkeep_usd_day=280,
                      crew=2, speed_kmh=85, capacity_bbl=180),
    ),
    dict(
        aid="veh_crane_truck", name="Mobile Crane Truck", build=crane_truck,
        gameplay=dict(role="vehicle", tier=2, cost_usd=980_000, upkeep_usd_day=900,
                      crew=3, speed_kmh=80, lift_t=45, boom_m=38),
    ),
    dict(
        aid="veh_pipe_truck", name="Pipe Haul Truck", build=pipe_truck,
        gameplay=dict(role="vehicle", tier=1, cost_usd=290_000, upkeep_usd_day=260,
                      crew=2, speed_kmh=90, capacity_t=22),
    ),
    dict(
        aid="veh_cementing_truck", name="Cementing Unit", build=cementing_truck,
        gameplay=dict(role="vehicle", tier=2, cost_usd=1_100_000, upkeep_usd_day=1_050,
                      crew=4, speed_kmh=85, pump_rate_bpm=12),
    ),
    dict(
        aid="veh_wireline_truck", name="Wireline Unit", build=wireline_truck,
        gameplay=dict(role="vehicle", tier=2, cost_usd=860_000, upkeep_usd_day=820,
                      crew=4, speed_kmh=90, line_depth_m=6000),
    ),
    dict(
        aid="veh_frac_pump_trailer", name="Frac Pump Trailer", build=frac_pump_trailer,
        gameplay=dict(role="vehicle", tier=2, cost_usd=1_400_000, upkeep_usd_day=1_300,
                      crew=2, power_kw=2_500, pressure_psi=15_000, rate_bpm=22),
    ),
    dict(
        aid="veh_excavator", name="Excavator", build=excavator,
        gameplay=dict(role="vehicle", tier=1, cost_usd=420_000, upkeep_usd_day=380,
                      crew=1, dig_rate_m3_h=120),
    ),
    dict(
        aid="veh_wheel_loader", name="Wheel Loader", build=wheel_loader,
        gameplay=dict(role="vehicle", tier=1, cost_usd=350_000, upkeep_usd_day=320,
                      crew=1, bucket_m3=3.2),
    ),
    dict(
        aid="veh_bulldozer", name="Bulldozer", build=bulldozer,
        gameplay=dict(role="vehicle", tier=1, cost_usd=480_000, upkeep_usd_day=430,
                      crew=1, grading_m3_h=180),
    ),
    dict(
        aid="veh_fire_truck", name="Fire / Safety Truck", build=fire_truck,
        gameplay=dict(role="vehicle", tier=2, cost_usd=520_000, upkeep_usd_day=450,
                      crew=5, speed_kmh=110, water_l=9_000, safety_radius_m=120),
    ),
    dict(
        aid="veh_forklift", name="Forklift", build=forklift,
        gameplay=dict(role="vehicle", tier=1, cost_usd=65_000, upkeep_usd_day=60,
                      crew=1, lift_t=3.0),
    ),
    dict(
        aid="veh_crew_car", name="Field Car", build=crew_car,
        gameplay=dict(role="vehicle", tier=1, cost_usd=32_000, upkeep_usd_day=30,
                      crew=4, speed_kmh=160),
    ),
]
