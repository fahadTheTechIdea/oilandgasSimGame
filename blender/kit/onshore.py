"""Upstream onshore assets: drilling, production, gathering, storage."""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector


# --------------------------------------------------------------------------- #
# local helpers
# --------------------------------------------------------------------------- #


def mud_tank(a: Asset, loc, w=12.0, d=5.0, h=2.6, mat="paint_grey"):
    x, y, z = loc
    a.box((w, d, h), (x, y, z + h / 2), mat, bevel=0.04)
    # stiffener ribs
    n = int(w / 1.6)
    for i in range(n + 1):
        a.box((0.12, d * 1.02, h * 0.96), (x - w / 2 + i * w / n, y, z + h / 2), "steel_dark")
    # top walkway + handrail
    P.grating(a, (w * 0.95, 1.0), (x, y + d * 0.3, z + h), bars=True)
    P.handrail(a, [(x - w / 2, y + d / 2 - 0.15, z + h), (x + w / 2, y + d / 2 - 0.15, z + h)], 1.0, "galv")
    # agitator motors
    for t in (-0.28, 0.0, 0.28):
        a.cyl(0.18, 0.7, (x + w * t, y - d * 0.2, z + h + 0.35), "paint_yellow", seg=10)
        a.box((0.5, 0.5, 0.45), (x + w * t, y - d * 0.2, z + h + 0.85), "steel_dark")
    # outlet manifold
    P.pipe_run(a, [(x + w / 2, y - d / 2 + 0.6, z + 0.7), (x + w / 2 + 1.6, y - d / 2 + 0.6, z + 0.7)], 0.18, "pipe_white")
    P.gate_valve(a, (x + w / 2 + 1.2, y - d / 2 + 0.6, z + 0.7), "X", 0.26)


def drill_pipe_rack(a: Asset, loc, length=28.0, tiers=3, mat="rust_patchy"):
    x, y, z = loc
    # rack supports
    for yy in (-length / 2, 0, length / 2):
        for sx in (-1, 1):
            a.beam((x + sx * 1.4, y + yy, z), (x + sx * 1.4, y + yy, z + 1.4 + tiers * 0.55), 0.12, "steel_dark")
        a.beam((x - 1.4, y + yy, z + 0.45), (x + 1.4, y + yy, z + 0.45), 0.10, "steel_dark")
        a.beam((x - 1.4, y + yy, z + 1.0), (x + 1.4, y + yy, z + 1.0), 0.10, "steel_dark")
    for t in range(tiers):
        zz = z + 0.45 + t * 0.5
        for i in range(7):
            px = x - 1.1 + i * 0.36
            a.cyl(0.075, length * 0.94, (px, y, zz + 0.075), mat, seg=8)


def bund_wall(a: Asset, size, h=1.2, t=0.35, loc=(0, 0, 0), mat="concrete"):
    x, y, z = loc
    w, d = size
    a.box((w, t, h), (x, y - d / 2 + t / 2, z + h / 2), mat)
    a.box((w, t, h), (x, y + d / 2 - t / 2, z + h / 2), mat)
    a.box((t, d - 2 * t, h), (x - w / 2 + t / 2, y, z + h / 2), mat)
    a.box((t, d - 2 * t, h), (x + w / 2 - t / 2, y, z + h / 2), mat)


# --------------------------------------------------------------------------- #
# assets
# --------------------------------------------------------------------------- #


def land_drilling_rig(a: Asset):
    """Full 1,500 HP land rig: substructure, 36 m derrick, mud system, pipe racks."""
    a.set(role="drilling", tier=1)
    P.pad(a, (46, 44), 0.25, (1, 2), "gravel")

    # --- substructure ------------------------------------------------------ #
    a.box((14, 14, 0.45), (0, 0, 3.0), "steel_dark")
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.beam((sx * 6.4, sy * 6.4, 0.25), (sx * 6.4, sy * 6.4, 3.0), 0.45, "paint_red")
    for i in range(1, 4):
        a.beam((-6.4, -6.4 + i * 3.2, 1.6), (6.4, -6.4 + i * 3.2, 1.6), 0.16, "steel_dark")
    a.box((14, 0.4, 0.35), (0, -6.8, 3.15), "paint_yellow")
    # stairs up to floor
    P.stairs(a, (7.4, 4.0, 0.25), 1.4, 3.0, 5.0, (1, 0, 0), 9, "galv")

    # --- derrick ----------------------------------------------------------- #
    P.derrick(a, (0, 0, 3.2), 36.0, 7.2, 1.9, "paint_red", bays=9, crown=True, setback=True)

    # rotary table + kelly
    a.cyl(1.5, 0.35, (0, 0, 3.35), "steel_dark", seg=20)
    a.cyl(1.15, 0.4, (0, 0, 3.45), "steel", seg=20)
    a.box((0.42, 0.42, 1.2), (0, 0, 4.2), "chrome")
    # BOP stack under floor
    for i, r in enumerate((0.75, 0.62, 0.75, 0.55)):
        a.cyl(r, 0.55, (0, 0, 0.55 + i * 0.58), "steel_dark", seg=16)
        a.cyl(r * 1.1, 0.10, (0, 0, 0.55 + i * 0.58), "paint_yellow", seg=16)
    P.pipe_run(a, [(0.85, 0, 1.3), (2.6, 0, 1.3), (2.6, 0, 0.35)], 0.12, "pipe_yellow")
    # accumulator bottles
    for i in range(4):
        a.cyl(0.22, 1.6, (-7.6 + i * 0.55, -4.0, 0.9), "paint_green", seg=10)
        a.dome((-7.6 + i * 0.55, -4.0, 1.7), 0.22, 0.2, "Z", "paint_green", seg=10, rings=3)

    # --- drawworks house --------------------------------------------------- #
    a.box((5.0, 6.5, 3.2), (9.2, 0, 4.8), "paint_orange", bevel=0.06)
    a.box((5.1, 2.2, 2.2), (9.2, 0.6, 5.1), "steel_dark")
    a.cyl(0.65, 4.6, (9.2, 0.2, 5.1), "steel_light", seg=16, rot=(math.pi / 2, 0, 0))
    a.beam((9.2, 2.6, 6.1), (9.2, 4.2, 7.6), 0.2, "steel_dark")
    a.sweep([(9.2, 0.4, 6.4), (0.6, 0, 4.6)], 0.05, "steel_dark", seg=6)
    a.box((0.9, 0.9, 0.7), (9.2, -3.6, 4.0), "paint_yellow")

    # --- doghouse / site office ------------------------------------------- #
    a.box((7.0, 5.0, 2.9), (8.6, 8.6, 1.7), "paint_white", bevel=0.08)
    a.box((7.1, 5.1, 0.35), (8.6, 8.6, 3.2), "paint_grey")
    for i in range(4):
        a.box((1.0, 0.06, 0.8), (6.2 + i * 1.5, 11.14, 2.1), "glass_dark")
    a.box((0.9, 0.12, 1.9), (10.4, 11.1, 1.2), "paint_grey")
    P.ac_unit(a, (11.6, 6.6, 3.35), (1.0, 0.7, 0.6))

    # --- generating station ------------------------------------------------ #
    P.generator_set(a, (-10.5, 9.0, 0.25), "paint_green")
    P.generator_set(a, (-10.5, 5.6, 0.25), "paint_green")
    a.box((3.4, 2.2, 2.0), (-10.5, 12.6, 1.25), "steel_dark")
    for i in range(3):
        a.cyl(0.22, 1.8, (-12.4, 8.4 + i * 1.0, 3.4), "steel_dark", seg=8)

    # --- mud system -------------------------------------------------------- #
    mud_tank(a, (-5.0, 17.0, 0.25), 12.0, 5.0, 2.6)
    mud_tank(a, (8.0, 17.0, 0.25), 12.0, 5.0, 2.6)
    # shakers
    for i in range(2):
        a.box((3.0, 2.2, 1.2), (-6.0 + i * 3.4, 11.6, 1.35), "paint_orange", bevel=0.04)
        a.box((2.6, 1.6, 0.16), (-6.0 + i * 3.4, 11.6, 2.0), "paint_green")
        a.box((0.5, 0.5, 0.8), (-6.0 + i * 3.4, 10.3, 1.2), "steel_dark")
    # mud pumps
    for i in range(2):
        a.box((5.4, 2.6, 1.6), (14.2, 12.0 + i * 3.4, 1.05), "paint_blue", bevel=0.05)
        a.cyl(0.42, 3.0, (14.2, 12.0 + i * 3.4, 2.3), "steel_dark", seg=12, rot=(0, math.pi / 2, 0))
        a.cyl(0.3, 1.4, (11.8, 12.0 + i * 3.4, 1.4), "steel_light", seg=10, rot=(0, math.pi / 2, 0))
    P.pipe_run(a, [(-5.0, 14.5, 1.3), (-5.0, 13.0, 1.3), (13.0, 13.0, 0.9), (13.0, 3.0, 0.9)], 0.2, "pipe_white")

    # --- pipe rack + catwalk ---------------------------------------------- #
    drill_pipe_rack(a, (-17.0, 0.0, 0.25), 28.0, 3)
    a.box((2.4, 16.0, 0.25), (-8.0, 0.0, 1.15), "galv")
    P.handrail(a, [(-9.2, 8.0, 1.28), (-9.2, -8.0, 1.28)], 0.9, "galv", toe=True)
    P.handrail(a, [(-6.8, 8.0, 1.28), (-6.8, -8.0, 1.28)], 0.9, "galv", toe=True)

    # --- fuel + water ------------------------------------------------------ #
    a.cyl(1.7, 6.5, (15.5, -9.0, 1.6), "paint_white", seg=18, rot=(math.pi / 2, 0, 0))
    a.box((3.4, 1.4, 0.5), (15.5, -12.4, 0.5), "steel_dark")
    a.box((3.0, 1.0, 1.4), (15.5, -6.2, 0.95), "paint_yellow")

    # --- miscellaneous ----------------------------------------------------- #
    P.floodlight(a, (-19.0, 12.0), 14.0)
    P.floodlight(a, (19.0, -6.0), 14.0)
    P.fence(a, (-22.0, -14.0, 0.25), (-22.0, 20.0, 0.25), 2.0, 3.0, barbed=False)
    a.cyl(0.35, 3.2, (-13.0, -10.0, 1.85), "paint_red", seg=10)   # fire hydrant / deluge


def workover_rig(a: Asset):
    """Mobile service/workover rig on a truck-mounted mast."""
    P.pad(a, (22, 16), 0.15, (0, 0), "gravel")
    P.chassis(a, 9.0, 2.6, 0.9, 0.55, (0.3, -0.28), "steel_dark", dual=True)
    P.truck_cab(a, (0, 4.6, 0.95), 2.5, 2.6, 2.5, "paint_orange", sleeper=True)
    P.mast(a, (0, -2.4, 1.1), 24.0, 4.2, "paint_orange", 6)
    # drawworks + winch
    a.box((2.2, 3.0, 1.8), (0, -0.4, 2.0), "paint_orange", bevel=0.05)
    a.cyl(0.55, 2.2, (0, -0.2, 2.7), "steel_light", seg=14, rot=(math.pi / 2, 0, 0))
    # outriggers
    for sy in (-1, 1):
        for sx in (-1, 1):
            a.beam((sx * 1.4, sy * 3.4, 0.9), (sx * 2.6, sy * 4.0, 0.15), 0.22, "steel_dark")
            a.cyl(0.42, 0.2, (sx * 2.6, sy * 4.0, 0.1), "steel_dark", seg=12)
    # tool boxes
    a.box((1.4, 2.6, 1.0), (0, -3.6, 1.5), "paint_yellow")
    # wellhead
    wellhead_stack(a, (0, -2.4, 0.15))


def wellhead_stack(a: Asset, loc, scale=1.0, flowline=True):
    x, y, z = loc
    s = scale
    a.cyl(0.55 * s, 0.35 * s, (x, y, z + 0.18 * s), "concrete_dark", seg=14)
    # casing head
    a.cyl(0.32 * s, 0.6 * s, (x, y, z + 0.65 * s), "steel_dark", seg=14)
    a.cyl(0.40 * s, 0.10 * s, (x, y, z + 0.36 * s), "steel", seg=14)
    # tubing head
    a.cyl(0.26 * s, 0.55 * s, (x, y, z + 1.2 * s), "steel_dark", seg=14)
    a.cyl(0.34 * s, 0.12 * s, (x, y, z + 1.48 * s), "steel", seg=14)
    # master valve
    P.gate_valve(a, (x, y, z + 1.75 * s), "Z", 0.22 * s, "paint_yellow")
    # flow cross + wings
    a.cyl(0.10 * s, 1.2 * s, (x, y, z + 2.25 * s), "steel_dark", seg=10, rot=(0, math.pi / 2, 0))
    P.gate_valve(a, (x + 0.55 * s, y, z + 2.25 * s), "X", 0.16 * s, "paint_red")
    P.gate_valve(a, (x - 0.55 * s, y, z + 2.25 * s), "X", 0.16 * s, "paint_red")
    P.pipe_run(a, [(x - 0.6 * s, y, z + 2.25 * s), (x - 2.4 * s, y, z + 2.25 * s),
                (x - 2.4 * s, y, z + 0.6 * s)], 0.10 * s, "pipe_white")
    P.gauge(a, (x + 0.62 * s, y - 0.28 * s, z + 2.5 * s), 0.09 * s, (0, -1, 0))
    P.gauge(a, (x - 0.62 * s, y - 0.28 * s, z + 2.5 * s), 0.09 * s, (0, -1, 0))
    # cap / pressure gauge on top
    a.cyl(0.16 * s, 0.22 * s, (x, y, z + 2.55 * s), "paint_yellow", seg=10)
    if flowline:
        P.pipe_run(a, [(x, y + 0.5 * s, z + 1.2 * s), (x, y + 1.8 * s, z + 1.2 * s)], 0.09 * s, "pipe_white")


def pumpjack(a: Asset):
    """API C-series beam pumping unit (~250 bpd class)."""
    a.set(role="production")
    P.pad(a, (16.0, 6.0), 0.25, (-2, 0), "concrete")
    # wellhead + stuffing box (directly under the horsehead)
    wellhead_stack(a, (-8.3, 0, 0.25), 1.0)
    # --- base / gearbox ---------------------------------------------------- #
    a.box((4.2, 2.4, 0.9), (-1.2, 0, 0.7), "paint_grey", bevel=0.04)
    a.box((2.2, 1.6, 1.5), (-1.2, 0, 1.7), "paint_grey", bevel=0.05)
    a.cyl(0.75, 1.3, (-1.2, 0, 1.9), "steel_dark", seg=16, rot=(math.pi / 2, 0, 0))
    # prime mover
    a.box((1.6, 1.3, 1.2), (1.6, 1.2, 1.3), "paint_blue", bevel=0.04)
    a.cyl(0.3, 1.2, (1.6, 1.2, 2.0), "steel_dark", seg=12)
    a.box((1.8, 0.9, 0.5), (0.9, 1.1, 1.4), "paint_yellow")
    # --- samson post ------------------------------------------------------- #
    for s in (-1, 1):
        a.beam((-0.1, s * 0.9, 1.0), (-0.2, s * 0.25, 6.2), 0.22, "paint_grey")
        a.beam((-0.1, s * 0.9, 1.0), (-0.2, s * 0.85, 4.2), 0.12, "paint_grey")
    a.beam((-0.2, -0.9, 3.6), (-0.2, 0.9, 3.6), 0.16, "paint_grey")
    # --- walking beam ------------------------------------------------------ #
    a.box((9.4, 0.55, 0.55), (-3.4, 0, 6.55), "paint_orange", rot=(0, -0.055, 0), bevel=0.04)
    a.beam((-7.6, 0, 6.9), (-7.6, 0, 7.6), 0.4, "paint_orange")
    # horsehead
    a.cyl(1.15, 0.65, (-8.1, 0, 7.0), "paint_orange", seg=20, rot=(math.pi / 2, 0, 0))
    a.box((0.5, 0.7, 1.4), (-8.45, 0, 6.7), "paint_orange")
    # bridle + carrier bar
    for s in (-1, 1):
        a.sweep([(-8.3, s * 0.55, 6.6), (-8.3, s * 0.55, 4.6)], 0.03, "steel_dark", seg=5)
    a.box((0.35, 1.3, 0.16), (-8.3, 0, 4.55), "steel_dark")
    a.cyl(0.07, 3.2, (-8.3, 0, 3.0), "chrome", seg=8)
    a.box((0.6, 0.6, 0.5), (-8.3, 0, 4.65), "steel_dark")
    # --- crank + counterweights ------------------------------------------- #
    a.cyl(0.42, 0.5, (-1.2, 0.95, 1.9), "steel_dark", seg=14, rot=(math.pi / 2, 0, 0))
    for s in (-1, 1):
        cy = s * 1.05
        a.beam((-1.2, cy, 1.9), (-2.4, cy, 1.35), 0.26, "paint_grey")
        a.box((1.9, 0.30, 0.9), (-2.95, cy, 1.22), "paint_grey", rot=(0, 0, 0), bevel=0.03)
        a.box((0.14, 0.34, 1.0), (-1.9, cy, 1.5), "steel_dark")
    # pin + crank pin
    a.cyl(0.14, 2.4, (-2.4, 0, 1.35), "steel_light", seg=10, rot=(math.pi / 2, 0, 0))
    a.beam((-2.4, 1.1, 1.35), (-1.2, 1.05, 1.9), 0.14, "paint_grey")
    # --- guards / skid ----------------------------------------------------- #
    a.box((2.6, 1.2, 0.08), (0.6, 1.2, 1.9), "paint_yellow")
    a.box((2.4, 0.9, 0.5), (2.2, -1.3, 0.6), "paint_grey")

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # gearbox panel seams + foundation bolts (instanced, low poly)
    for by in (-1.02, 1.02):
        a.box((2.25, 0.05, 0.07), (-1.2, by, 1.72), "steel_dark")
        for bx in (-2.15, -0.25):
            a.cyl(0.06, 0.10, (bx, by, 0.78), "steel_dark", seg=6)
    # prime-mover louvres + panel seam
    for i in range(3):
        a.box((0.05, 0.85, 0.07), (2.42, 1.2, 1.10 + i * 0.17), "steel_dark")
    a.box((0.05, 1.05, 0.06), (0.8, 1.2, 1.55), "steel_dark")
    # crank guard rail (safety cage)
    for s in (-1, 1):
        for gx in (-2.4, -0.3):
            a.cyl(0.05, 1.05, (gx, s * 1.55, 1.85), "galv", seg=6)
        a.beam((-2.4, s * 1.55, 2.35), (-0.3, s * 1.55, 2.35), 0.06, "galv")
    # control panel + flexible conduit to the motor
    a.box((0.72, 0.36, 0.90), (2.25, -0.62, 1.70), "paint_green", bevel=0.02)
    a.cyl(0.05, 0.7, (2.25, -0.62, 2.18), "steel_dark", seg=6)
    a.sweep([(2.25, -0.45, 1.70), (2.05, 0.15, 1.45), (1.75, 1.0, 1.30)],
            0.04, "steel_dark", seg=5)
    # access steps up to the gearbox deck
    for i in range(3):
        a.box((0.55, 0.60, 0.08), (-0.1, 1.75, 0.42 + i * 0.34), "galv")
    # warning plate on the fence line
    a.box((0.72, 0.05, 0.50), (-10.45, 2.60, 1.35), "paint_yellow", bevel=0.01)

    P.fence(a, (-10.5, -2.6, 0.25), (-10.5, 2.6, 0.25), 1.8, 1.3, barbed=False)
    P.fence(a, (-10.5, 2.6, 0.25), (5.0, 2.6, 0.25), 1.8, 2.0, barbed=False)


def wellhead_xmas_tree(a: Asset):
    a.set(role="production")
    P.pad(a, (5.0, 5.0), 0.2, (0, 0), "concrete")
    wellhead_stack(a, (0, 0, 0.2), 1.35)
    a.box((1.4, 1.4, 0.7), (1.8, -1.2, 0.55), "paint_yellow")
    P.gauge(a, (1.8, -0.4, 1.0), 0.12, (0, -1, 0))
    P.pipe_run(a, [(0.8, 0, 1.2), (2.2, 0, 1.2), (2.2, 0.7, 1.2)], 0.12, "pipe_yellow")


def three_phase_separator(a: Asset):
    a.set(role="processing")
    P.separator_package(a, (0, 0, 0), 1.0)
    # sand jet + drain
    P.pipe_run(a, [(-1.0, -1.2, 0.4), (-1.0, -2.2, 0.4), (-1.0, -2.2, 0.1)], 0.11)
    P.gauge(a, (2.0, 1.6, 1.9), 0.11, (0, 1, 0))
    a.box((0.8, 0.8, 1.1), (0.6, -1.4, 0.85), "paint_yellow")


def heater_treater(a: Asset):
    P.pad(a, (9.0, 4.0), 0.2, (0, 0), "concrete")
    P.vessel(a, 0.85, 5.6, (0, 0, 1.55), "X", "paint_white", 2)
    # firetube
    a.cyl(0.35, 2.2, (0.6, 0, 1.55), "steel_dark", seg=14, rot=(0, math.pi / 2, 0))
    # stack
    a.cyl(0.30, 3.2, (2.0, 0, 4.2), "paint_grey", seg=14)
    a.cyl(0.36, 0.25, (2.0, 0, 5.9), "steel_dark", seg=14)
    # burner
    a.box((1.0, 0.9, 0.8), (-3.2, 0, 1.4), "paint_red", bevel=0.03)
    a.cyl(0.16, 1.6, (-3.2, 0, 2.1), "steel_dark", seg=10)
    # piping + valves
    P.pipe_run(a, [(-2.6, 0.5, 2.2), (-2.6, 1.6, 2.2), (-2.6, 1.6, 0.4)], 0.12, "pipe_white")
    P.gate_valve(a, (-2.6, 1.0, 2.2), "Y", 0.18)
    P.pipe_run(a, [(2.9, 0, 2.2), (3.6, 0, 2.2)], 0.12)
    P.gauge(a, (0, 1.1, 2.2), 0.1, (0, 1, 0))


def tank_farm(a: Asset):
    """Four-tank crude battery with bund wall, manifold and stair access."""
    a.set(role="storage")
    P.pad(a, (46, 34), 0.2, (0, 2), "gravel")
    bund_wall(a, (44, 32), 0.9, 0.35, (0, 2, 0.2), "concrete_dark")
    positions = [(-11, -5), (11, -5), (-11, 12), (11, 12)]
    for i, (x, y) in enumerate(positions):
        P.tank(a, 6.2, 10.5, (x, y, 0.2), "floating" if i % 2 == 0 else "cone",
               "paint_white", "steel", spiral=True, bands=3)
        # hard-surface detail: roof rail ring, anchor bolts, level gauge
        a.sweep([(x + 5.85 * math.cos(k * math.tau / 12.0),
                  y + 5.85 * math.sin(k * math.tau / 12.0), 11.05)
                 for k in range(13)], 0.04, "galv", seg=5)
        for k in range(12):
            ang = k * math.tau / 12.0
            a.cyl(0.08, 0.12, (x + 5.98 * math.cos(ang), y + 5.98 * math.sin(ang), 0.28),
                  "steel_dark", seg=5)
        a.cyl(0.06, 7.0, (x - 6.30, y + 2.0, 4.2), "glass_dark", seg=6)
    # manifold
    P.pipe_run(a, [(-17, 22, 1.0), (17, 22, 1.0)], 0.22, "pipe_white", supports=True, support_every=4.0)
    for (x, y) in positions:
        P.pipe_run(a, [(x, y, 1.0), (x, 22, 1.0)], 0.13, "pipe_white")
        P.gate_valve(a, (x, 20.5, 1.0), "Y", 0.2, "paint_yellow")
    P.gate_valve(a, (0, 22, 1.0), "X", 0.24, "paint_yellow")
    # pumps
    a.box((2.4, 1.6, 1.2), (-19.5, 22, 0.8), "paint_blue", bevel=0.04)
    a.cyl(0.35, 1.6, (-19.5, 22, 1.7), "steel_dark", seg=12)
    # stairs over bund
    P.stairs(a, (-15, 16.5, 0.2), 1.2, 1.3, 2.2, (0, 1, 0), 4, "galv")
    P.floodlight(a, (20, 14), 12.0)


def flare_stack_onshore(a: Asset):
    P.flare_stack(a, (0, 0, 0), 34.0, "paint_grey", derrick_style=True)
    P.pad(a, (12, 10), 0.2, (1, 0), "gravel")


def compressor_station(a: Asset):
    a.set(role="processing")
    P.pad(a, (26, 18), 0.25, (0, 0), "concrete")
    P.compressor_package(a, (-6.0, 0, 0.25), "paint_blue")
    P.compressor_package(a, (2.0, 0, 0.25), "paint_blue")
    # suction scrubber + cooler
    P.vessel(a, 0.7, 2.4, (-11.0, 4.5, 1.4), "Y", "paint_white", 2)
    a.box((4.6, 2.6, 1.8), (9.0, 3.0, 1.15), "galv", bevel=0.04)
    for i in range(4):
        a.cyl(0.55, 0.2, (7.6 + i * 1.0, 3.0, 1.9), "steel_dark", seg=12, rot=(math.pi / 2, 0, 0))
    P.pipe_run(a, [(-6.0, 1.6, 2.6), (-6.0, 2.4, 2.6), (9.0, 2.4, 2.6), (9.0, 3.0, 2.6)], 0.2, "pipe_yellow", supports=True)
    P.gate_valve(a, (-2.0, 2.4, 2.6), "X", 0.24)
    a.box((3.0, 2.2, 2.6), (11.0, -5.0, 1.55), "paint_white", bevel=0.06)
    a.box((2.4, 0.08, 1.0), (11.0, -6.12, 2.0), "glass_dark")
    P.pipe_run(a, [(-11.0, 6.0, 1.4), (-11.0, 6.0, 3.0), (-6.0, 3.0, 3.0)], 0.16)
    P.floodlight(a, (-12.0, -6.0), 12.0)


def metering_skid(a: Asset):
    P.skid(a, 9.0, 3.4, 0.3, loc=(0, 0, 0))
    for s in (-1, 1):
        y = s * 0.9
        P.pipe_run(a, [(-4.0, y, 1.2), (4.0, y, 1.2)], 0.16, "pipe_white")
        a.cyl(0.32, 0.9, (-1.0, y, 1.2), "steel_light", seg=14, rot=(0, math.pi / 2, 0))
        a.cyl(0.30, 0.35, (0.4, y, 1.2), "paint_blue", seg=14, rot=(0, math.pi / 2, 0))
        P.gate_valve(a, (2.4, y, 1.2), "X", 0.18)
    a.box((1.1, 1.2, 1.5), (4.6, 0, 1.05), "paint_grey", bevel=0.03)
    a.box((0.9, 0.06, 0.7), (4.6, -0.62, 1.25), "glass_dark")
    P.gauge(a, (3.6, 1.6, 1.5), 0.1, (0, 1, 0))
    a.box((0.6, 0.6, 0.55), (-4.4, 0, 1.0), "paint_yellow")


def gathering_manifold(a: Asset):
    P.pad(a, (16, 8), 0.2, (0, 0), "concrete")
    P.skid(a, 14.0, 5.0, 0.3, loc=(0, 0, 0))
    P.pipe_run(a, [(-6.0, 1.4, 1.1), (6.0, 1.4, 1.1)], 0.26, "pipe_white")
    for i in range(6):
        x = -5.0 + i * 2.0
        P.pipe_run(a, [(x, 1.4, 1.1), (x, -1.6, 1.1)], 0.12, "pipe_white")
        P.gate_valve(a, (x, -0.6, 1.1), "Y", 0.18, "paint_yellow")
        a.cyl(0.2, 0.3, (x, -1.75, 1.1), "steel_dark", seg=10, rot=(math.pi / 2, 0, 0))
    P.pipe_run(a, [(6.0, 1.4, 1.1), (7.6, 1.4, 1.1), (7.6, 0, 0.5)], 0.26)
    a.box((1.4, 1.0, 1.2), (-7.2, 1.4, 0.9), "paint_blue")


def saltwater_disposal(a: Asset):
    P.pad(a, (18, 14), 0.2, (0, 0), "concrete")
    P.tank(a, 4.5, 7.0, (-4.5, 0, 0.2), "cone", "paint_green", "steel", spiral=True, bands=2)
    # injection pump
    P.skid(a, 4.0, 2.4, 0.3, loc=(4.5, -3.0, 0.2))
    a.box((2.4, 1.4, 1.2), (4.5, -3.0, 1.2), "paint_blue", bevel=0.04)
    a.cyl(0.32, 1.6, (4.5, -3.0, 2.1), "steel_dark", seg=12)
    P.pipe_run(a, [(-4.5, 0, 1.0), (2.0, 0, 1.0)], 0.16, "pipe_white", supports=True)
    P.gate_valve(a, (3.2, 0, 1.0), "X", 0.22)
    # disposal wellhead
    wellhead_stack(a, (7.0, 3.0, 0.2), 1.1)
    P.pipe_run(a, [(4.5, -1.0, 1.2), (7.0, -1.0, 1.2), (7.0, 3.0, 1.2)], 0.14)
    P.fence(a, (-9.0, -6.5, 0.2), (9.0, -6.5, 0.2), 2.0, 2.5, barbed=True)


def pipeline_segment(a: Asset):
    """10 m of buried-ready line pipe on sleeper supports (snap tile)."""
    P.pad(a, (11.0, 2.6), 0.12, (0, 0), "gravel")
    P.pipe_run(a, [(-5.0, 0, 1.0), (5.0, 0, 1.0)], 0.30, "pipe_yellow", supports=True, support_every=3.3)
    P.flange(a, (-5.0, 0, 1.0), "X", 0.45, "steel_dark")
    P.flange(a, (5.0, 0, 1.0), "X", 0.45, "steel_dark")
    a.box((0.5, 0.5, 0.06), (0, 0, 1.34), "paint_white")
    for i in range(3):
        a.box((0.2, 1.3, 0.02), (-2.1 + i * 2.1, 0, 0.13), "paint_yellow")


def pipeline_valve_station(a: Asset):
    P.valve_station(a, (0, 0, 0), 3.0, 0.42)
    P.gauge(a, (0.0, 0.75, 1.35), 0.12, (0, 1, 0))
    a.box((0.9, 0.7, 1.4), (-1.8, -1.5, 0.85), "paint_blue")
    a.box((0.9, 0.7, 1.4), (1.8, -1.5, 0.85), "paint_blue")


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(
        aid="on_land_rig", name="Land Drilling Rig (1500 HP)", build=land_drilling_rig,
        gameplay=dict(role="drilling", tier=1, cost_usd=18_000_000, build_days=45,
                      crew=52, power_kw=2500, footprint_m2=2000, upkeep_usd_day=24_000,
                      drill_depth_m=4500, drill_rate_m_day=120, well_cost_factor=1.0,
                      emissions_t_day=6.0),
    ),
    dict(
        aid="on_workover_rig", name="Workover / Service Rig", build=workover_rig,
        gameplay=dict(role="drilling", tier=2, cost_usd=2_400_000, build_days=8,
                      crew=12, power_kw=320, footprint_m2=350, upkeep_usd_day=3_200,
                      drill_depth_m=2500, drill_rate_m_day=180, well_cost_factor=0.25,
                      emissions_t_day=0.9),
    ),
    dict(
        aid="on_pumpjack", name="Beam Pumping Unit", build=pumpjack,
        gameplay=dict(role="production", tier=1, cost_usd=250_000, build_days=3,
                      crew=1, power_kw=45, footprint_m2=120, upkeep_usd_day=320,
                      capacity_bopd=250, recovery_factor=0.28, emissions_t_day=0.2),
    ),
    dict(
        aid="on_wellhead", name="Wellhead / Christmas Tree", build=wellhead_xmas_tree,
        gameplay=dict(role="production", tier=1, cost_usd=120_000, build_days=2,
                      crew=1, power_kw=0, footprint_m2=30, upkeep_usd_day=90,
                      design_pressure_psi=5000),
    ),
    dict(
        aid="on_separator", name="3-Phase Separator Package", build=three_phase_separator,
        gameplay=dict(role="processing", tier=1, cost_usd=900_000, build_days=5,
                      crew=3, power_kw=60, footprint_m2=180, upkeep_usd_day=1_100,
                      capacity_bfpd=8000, water_cut_capability=0.85),
    ),
    dict(
        aid="on_heater_treater", name="Heater Treater", build=heater_treater,
        gameplay=dict(role="processing", tier=1, cost_usd=450_000, build_days=4,
                      crew=2, power_kw=40, footprint_m2=90, upkeep_usd_day=650,
                      capacity_bfpd=2500, fuel_gas_mcfd=260),
    ),
    dict(
        aid="on_tank_farm", name="Crude Tank Farm (4 x 10,000 bbl)", build=tank_farm,
        gameplay=dict(role="storage", tier=1, cost_usd=1_600_000, build_days=12,
                      crew=4, power_kw=120, footprint_m2=1500, upkeep_usd_day=1_400,
                      capacity_bbl=40_000),
    ),
    dict(
        aid="on_flare", name="Flare Stack 34 m", build=flare_stack_onshore,
        gameplay=dict(role="support", tier=1, cost_usd=800_000, build_days=8,
                      crew=2, power_kw=0, footprint_m2=120, upkeep_usd_day=400,
                      capacity_mmscfd=12),
    ),
    dict(
        aid="on_compressor_station", name="Gas Compressor Station", build=compressor_station,
        gameplay=dict(role="processing", tier=2, cost_usd=2_200_000, build_days=14,
                      crew=6, power_kw=1400, footprint_m2=480, upkeep_usd_day=3_600,
                      capacity_mmscfd=10),
    ),
    dict(
        aid="on_metering_skid", name="Custody Metering Skid", build=metering_skid,
        gameplay=dict(role="support", tier=2, cost_usd=600_000, build_days=4,
                      crew=2, power_kw=25, footprint_m2=36, upkeep_usd_day=450,
                      accuracy_pct=0.25),
    ),
    dict(
        aid="on_gathering_manifold", name="Wellpad Gathering Manifold", build=gathering_manifold,
        gameplay=dict(role="transport", tier=1, cost_usd=350_000, build_days=3,
                      crew=2, power_kw=0, footprint_m2=140, upkeep_usd_day=180,
                      well_slots=12),
    ),
    dict(
        aid="on_saltwater_disposal", name="Saltwater Disposal Facility", build=saltwater_disposal,
        gameplay=dict(role="support", tier=2, cost_usd=700_000, build_days=6,
                      crew=3, power_kw=180, footprint_m2=260, upkeep_usd_day=700,
                      capacity_bwpd=5000),
    ),
    dict(
        aid="on_pipeline_segment", name="Pipeline Segment (10 m)", build=pipeline_segment,
        gameplay=dict(role="transport", tier=1, cost_usd=40_000, build_days=1,
                      crew=1, power_kw=0, footprint_m2=28, upkeep_usd_day=15,
                      capacity_bopd=25_000, length_m=10, snap="pipe"),
    ),
    dict(
        aid="on_pipeline_valve", name="Pipeline Valve Station", build=pipeline_valve_station,
        gameplay=dict(role="transport", tier=2, cost_usd=180_000, build_days=2,
                      crew=1, power_kw=5, footprint_m2=40, upkeep_usd_day=60,
                      isolation_capability=True),
    ),
]
