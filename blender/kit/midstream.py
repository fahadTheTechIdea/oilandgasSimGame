"""Midstream: pipelines, pumping, gas processing, LNG, terminals."""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #


def pipe_rack(a: Asset, loc, length, width=6.0, height=6.0, levels=3,
              mat="galv", pipes=3):
    x, y, z = P.xyz(loc)
    n = max(2, int(length / 8.0) + 1)
    for i in range(n):
        xx = x - length / 2 + length * i / (n - 1)
        for s in (-1, 1):
            a.beam((xx, y + s * width / 2, z), (xx, y + s * width / 2, z + height), 0.26, mat)
        for lv in range(1, levels + 1):
            zz = z + height * lv / (levels + 1)
            a.beam((xx, y - width / 2, zz), (xx, y + width / 2, zz), 0.20, mat)
            a.beam((xx, y - width / 2, zz), (xx, y + width / 2, zz + 1.4), 0.09, mat)
    for lv in range(1, levels + 1):
        zz = z + height * lv / (levels + 1)
        for k in range(pipes):
            yy = y - width * 0.3 + k * (width * 0.6 / max(1, pipes - 1))
            mat_pipe = ("pipe_white", "pipe_yellow", "pipe_green")[k % 3]
            a.cyl(0.26, length * 0.98, (x, yy, zz + 0.28), mat_pipe, seg=10,
                  rot=(0, math.pi / 2, 0))


def column(a: Asset, loc, r, h, mat="insulation", platforms=3, skirt=True,
           ladder=True, trim="steel", dome_h=None):
    x, y, z = P.xyz(loc)
    if skirt:
        a.cyl(r * 1.02, 4.0, (x, y, z + 2.0), "concrete_dark", seg=20)
        a.cyl(r, h - 4.0, (x, y, z + 4.0 + (h - 4.0) / 2), mat, seg=24)
    else:
        a.cyl(r, h, (x, y, z + h / 2), mat, seg=24)
    a.dome((x, y, z + h), r, dome_h or r * 0.55, "Z", mat, seg=24, rings=4)
    # bands + platforms
    for i in range(platforms):
        t = 0.25 if platforms == 1 else 0.24 + 0.58 * i / (platforms - 1)
        zz = z + h * t
        a.cyl(r * 1.08, 0.10, (x, y, zz), trim, seg=24)
        P.platform_disc(a, (x, y, zz), r * 1.02, r * 1.55, "galv", 16)
        ring = [(x + math.cos(TAU * k / 24) * r * 1.55, y + math.sin(TAU * k / 24) * r * 1.55, zz + 0.05)
                for k in range(25)]
        a.sweep(ring, 0.05, trim, seg=6, caps=False)
        for k in range(8):
            ang = TAU * k / 8
            a.beam((x + math.cos(ang) * r, y + math.sin(ang) * r, zz),
                   (x + math.cos(ang) * r * 1.55, y + math.sin(ang) * r * 1.55, zz), 0.08, trim)
    if ladder:
        P.caged_ladder(a, (x + r + 0.5, y, z), h * 0.95, 0.5, (0, 1, 0))
    # nozzles
    for i, (zz, rr) in enumerate([(h * 0.25, r), (h * 0.45, r), (h * 0.7, r)]):
        nz = (x - rr, y, z + zz)
        a.cyl(0.22, 0.9, nz, "pipe_white", seg=10, rot=(0, math.pi / 2, 0))
        P.flange(a, (x - rr - 0.45, y, z + zz), "X", 0.3, "steel_dark", bolts=False)


def exchanger(a: Asset, loc, length=8.0, r=1.0, axis="X", mat="paint_white"):
    x, y, z = P.xyz(loc)
    rot = (0, math.pi / 2, 0) if axis == "X" else (math.pi / 2, 0, 0)
    a.cyl(r, length, (x, y, z), mat, seg=18, rot=rot)
    for s in (-1, 1):
        off = length / 2 + 0.5 if axis == "X" else 0
        a.cyl(r * 0.85, 0.9, (x + s * off, y, z), "steel_dark", seg=16, rot=rot)
    for s in (-1, 1):
        a.cyl(0.22, 0.7, (x + s * length * 0.3, y, z + r), "pipe_white", seg=10)
    a.box((0.9, 1.2, 0.5), (x - length * 0.32, y, z - r - 0.25), "concrete_dark")


def control_building(a: Asset, loc, w=10.0, d=8.0, h=4.5, mat="paint_white"):
    x, y, z = P.xyz(loc)
    a.box((w, d, h), (x, y, z + h / 2), mat, bevel=0.08)
    a.box((w * 1.05, d * 1.05, 0.3), (x, y, z + h + 0.1), "paint_grey")
    a.box((w * 0.6, 0.08, 1.2), (x, y - d / 2 - 0.04, z + h * 0.6), "glass_dark")
    a.box((0.9, 0.12, 2.0), (x + w * 0.3, y - d / 2 - 0.06, z + 1.0), "paint_grey")
    a.box((1.4, 1.0, 0.6), (x - w * 0.35, y, z + h + 0.45), "galv")


def jetty_deck(a: Asset, loc, w=8.0, l=120.0):
    x, y, z = P.xyz(loc)
    a.box((w, l, 1.0), (x, y, z), "steel_dark")
    a.box((w * 0.94, l * 0.98, 0.12), (x, y, z + 0.56), "galv")
    n = int(l / 14)
    for i in range(n + 1):
        yy = y - l / 2 + i * l / n
        for sx in (-1, 1):
            a.cyl(0.55, 16.0, (x + sx * w * 0.38, yy, z - 8.0), "paint_yellow", seg=10)
        a.beam((x - w * 0.4, yy, z - 0.5), (x + w * 0.4, yy, z - 0.5), 0.3, "steel_dark")


def loading_arm(a: Asset, loc, reach=14.0, height=7.0, mat="paint_yellow"):
    x, y, z = P.xyz(loc)
    a.cyl(0.45, height, (x, y, z + height / 2), mat, seg=12)
    a.box((1.4, 1.4, 0.6), (x, y, z + 0.3), "steel_dark")
    a.beam((x, y, z + height), (x + reach * 0.45, y, z + height + 3.0), 0.35, mat)
    a.beam((x + reach * 0.45, y, z + height + 3.0), (x + reach, y, z + height - 0.5), 0.32, mat)
    a.cyl(0.20, 3.0, (x + reach, y, z + height - 1.8), "steel_light", seg=10)
    a.cyl(0.35, 0.8, (x + reach, y, z + height - 3.4), "paint_red", seg=10)
    a.sweep([(x, y, z + height - 0.6), (x + reach * 0.4, y, z + height + 2.0),
             (x + reach * 0.9, y, z + height - 0.4)], 0.10, "plastic_orange", seg=6)


# --------------------------------------------------------------------------- #
# assets
# --------------------------------------------------------------------------- #


def pump_station(a: Asset):
    a.set(role="transport")
    P.pad(a, (34, 22), 0.25, (0, 0), "concrete")
    # pump house
    a.box((14, 9, 6.5), (-6, 0, 3.5), "paint_white", bevel=0.08)
    a.box((14.2, 9.2, 0.4), (-6, 0, 6.9), "paint_grey")
    for i in range(3):
        a.box((2.2, 0.08, 1.2), (-11 + i * 4.0, -4.54, 2.4), "glass_dark")
    a.box((1.2, 0.12, 2.4), (-1.5, -4.54, 1.4), "paint_grey")
    # pumps inside/outside
    for i in range(3):
        P.skid(a, 4.2, 2.4, 0.3, loc=(9.0, -6.0 + i * 5.0, 0.25))
        a.box((2.4, 1.5, 1.4), (9.0, -6.0 + i * 5.0, 1.4), "paint_blue", bevel=0.04)
        a.cyl(0.42, 2.0, (9.0, -6.0 + i * 5.0, 2.3), "steel_dark", seg=14, rot=(0, math.pi / 2, 0))
        a.cyl(0.32, 1.2, (10.6, -6.0 + i * 5.0, 1.5), "steel_light", seg=12, rot=(0, math.pi / 2, 0))
    # manifold
    P.pipe_run(a, [(-16, -8, 1.0), (16, -8, 1.0)], 0.34, "pipe_yellow", supports=True, support_every=6.0)
    for i in range(3):
        P.pipe_run(a, [(9.0, -6.0 + i * 5.0, 1.0), (9.0, -8, 1.0)], 0.18, "pipe_yellow")
        P.gate_valve(a, (9.0, -7.4, 1.0), "Y", 0.24)
    P.pipe_run(a, [(16, -8, 1.0), (16, 6, 1.0), (20, 6, 1.0)], 0.30, "pipe_yellow")
    # pig launcher + metering
    a.cyl(0.8, 6.0, (-15, 6, 1.3), "paint_red", seg=16, rot=(0, math.pi / 2, 0))
    a.dome((-18.0, 6, 1.3), 0.8, 0.5, "X", "paint_red", seg=16, rings=4)
    a.box((3.0, 2.0, 1.6), (-8, 6, 1.0), "galv", bevel=0.04)
    for i in range(3):
        a.cyl(0.24, 0.8, (-8, 5.0 + i * 1.0, 2.2), "steel_dark", seg=10, rot=(math.pi / 2, 0, 0))
    P.pipe_run(a, [(-11, 6, 1.3), (-18, 6, 1.3)], 0.26, "pipe_yellow")
    P.floodlight(a, (-14, -9), 12.0)
    P.fence(a, (-17, -11, 0.25), (17, -11, 0.25), 2.0, 3.0, barbed=True)


def slug_catcher(a: Asset):
    P.pad(a, (40, 14), 0.25, (0, 0), "concrete")
    P.vessel(a, 2.2, 26.0, (0, 0, 3.0), "X", "paint_white", 3)
    # inlet piping + risers
    P.pipe_run(a, [(-16, 0, 2.6), (-16, 0, 9.0)], 0.45, "pipe_white")
    a.cyl(1.4, 1.6, (-16, 0, 9.6), "steel_dark", seg=16)
    P.pipe_run(a, [(-13, 1.8, 4.0), (-6, 1.8, 4.0), (-6, 1.8, 3.0)], 0.30, "pipe_yellow")
    for i in range(3):
        P.gate_valve(a, (-10 + i * 4.0, 1.8, 4.0), "X", 0.26)
    # liquid outlet + level instruments
    P.pipe_run(a, [(13, -1.6, 1.4), (18, -1.6, 1.4), (18, -1.6, 0.5)], 0.32, "pipe_green")
    for i in range(3):
        a.cyl(0.18, 1.0, (-4 + i * 4.0, 2.3, 4.4), "steel_dark", seg=8)
        P.gauge(a, (-4 + i * 4.0, 2.3, 5.0), 0.11, (0, 1, 0))
    a.box((2.0, 1.4, 2.0), (18, 3.0, 1.25), "paint_blue", bevel=0.04)
    P.floodlight(a, (-18, -5), 12.0)


def gas_processing_plant(a: Asset):
    a.set(role="processing")
    P.pad(a, (90, 62), 0.3, (0, 0), "concrete")

    # --- inlet separation -------------------------------------------------- #
    for i in range(2):
        P.vessel(a, 1.8, 11.0, (-34, -18 + i * 9.0, 4.2), "X", "paint_white", 2)
    P.pipe_run(a, [(-44, -18, 2.0), (-44, 4, 2.0), (-40, 4, 2.0)], 0.45, "pipe_white", supports=True, support_every=6.0)

    # --- glycol dehydration ------------------------------------------------ #
    column(a, (-16, 16, 0.3), 2.0, 20.0, "paint_white", platforms=3)
    column(a, (-6, 18, 0.3), 1.4, 14.0, "insulation", platforms=2)
    exchanger(a, (-11, 12, 0.3), 6.0, 0.7, "X", "paint_grey")
    a.box((4.0, 3.0, 2.4), (-16, 10, 1.5), "paint_yellow", bevel=0.05)

    # --- amine sweetening -------------------------------------------------- #
    column(a, (2, 20, 0.3), 2.4, 26.0, "paint_white", platforms=4)
    column(a, (13, 22, 0.3), 2.0, 21.0, "insulation", platforms=3)
    exchanger(a, (8, 15, 0.3), 8.0, 0.9, "X", "paint_grey")
    a.box((6.0, 4.0, 3.0), (4, 12, 1.8), "paint_blue", bevel=0.05)

    # --- cryogenic / cold box --------------------------------------------- #
    a.box((12.0, 9.0, 16.0), (28, -2, 8.3), "galv", bevel=0.08)
    a.box((12.4, 9.4, 0.5), (28, -2, 16.5), "steel_dark")
    for i in range(3):
        a.cyl(0.5, 12.0, (22 - i * 3.0, -8, 6.3), "stainless", seg=12)
    # deethanizer
    column(a, (34, 12, 0.3), 2.2, 30.0, "insulation", platforms=4)
    # turbo-expander house
    a.box((9.0, 7.0, 6.0), (16, -14, 3.3), "paint_white", bevel=0.06)
    a.box((8.0, 6.0, 0.4), (16, -14, 6.5), "galv")

    # --- pipe racks -------------------------------------------------------- #
    pipe_rack(a, (-22, -2, 0.3), 44.0, 8.0, 7.0, 3, "galv", 4)
    pipe_rack(a, (24, 22, 0.3), 30.0, 6.0, 6.0, 2, "galv", 3)

    # --- utilities --------------------------------------------------------- #
    P.generator_set(a, (-34, 22, 0.3), "paint_green")
    P.compressor_package(a, (40, -16, 0.3), "paint_blue")
    a.cyl(3.5, 10.0, (40, 4, 5.3), "paint_white", seg=18)
    a.dome((40, 4, 10.3), 3.5, 1.2, "Z", "paint_white", seg=18, rings=4)
    control_building(a, (0, -28, 0.3), 14.0, 9.0, 5.0)
    P.flare_stack(a, (44, 26, 0.3), 40.0, "paint_grey", derrick_style=True)
    P.floodlight(a, (-40, -26), 16.0)
    P.floodlight(a, (42, -24), 16.0)
    P.handrail(a, [(-44, -30, 0.3), (44, -30, 0.3)], 1.1, "galv", spacing=8.0)


def lng_train(a: Asset):
    a.set(role="processing")
    P.pad(a, (74, 50), 0.3, (0, 0), "concrete")
    # acid gas removal + dehydration
    column(a, (-28, 12, 0.3), 2.6, 28.0, "paint_white", platforms=4)
    column(a, (-16, 15, 0.3), 2.0, 18.0, "insulation", platforms=3)
    # main cryogenic heat exchanger (cold box)
    a.box((14.0, 12.0, 34.0), (-2, 2, 17.3), "galv", bevel=0.1)
    a.box((14.4, 12.4, 0.6), (-2, 2, 34.6), "steel_dark")
    for i in range(4):
        a.cyl(0.9, 30.0, (-2 - 4.0 + i * 2.6, -5.2, 15.3), "stainless", seg=12)
    # refrigerant compressor house
    a.box((20.0, 12.0, 9.0), (20, 8, 4.8), "paint_white", bevel=0.08)
    a.box((6.0, 5.0, 3.0), (20, 2, 1.8), "paint_blue", bevel=0.05)
    for i in range(3):
        a.cyl(1.2, 6.0, (26, -2 + i * 4.0, 3.3), "steel_dark", seg=14)
    # heavies removal / fractionation
    column(a, (34, -14, 0.3), 2.0, 22.0, "insulation", platforms=3)
    column(a, (26, -16, 0.3), 1.6, 16.0, "insulation", platforms=2)
    # flare + rundown
    P.flare_stack(a, (34, 20, 0.3), 34.0, "paint_grey", False)
    P.pipe_run(a, [(-28, -8, 1.2), (30, -8, 1.2)], 0.34, "pipe_white", supports=True, support_every=8.0)
    # control room
    control_building(a, (-14, -20, 0.3), 16.0, 10.0, 5.5)
    P.generator_set(a, (-34, -16, 0.3), "paint_green")
    P.floodlight(a, (-34, 22), 15.0)
    P.floodlight(a, (32, -24), 15.0)


def lng_sphere(a: Asset):
    """Single containment LNG sphere (25,000 m3 class)."""
    P.pad(a, (34, 34), 0.3, (0, 0), "concrete")
    a.cyl(11.0, 5.0, (0, 0, 2.8), "concrete_dark", seg=28)
    for i in range(8):
        ang = TAU * i / 8
        a.beam((math.cos(ang) * 10.0, math.sin(ang) * 10.0, 0.3),
               (math.cos(ang) * 8.5, math.sin(ang) * 8.5, 13.0), 0.5, "steel_dark")
    a.sphere(11.0, (0, 0, 14.0), "paint_white", seg=(28, 18))
    a.cyl(2.4, 2.0, (0, 0, 25.5), "galv", seg=16)
    a.cyl(1.2, 3.0, (0, 0, 27.0), "steel_dark", seg=12)
    P.spiral_stair(a, (0, 0), 12.0, 13.0, 1.1, 0.8, "galv")
    P.pipe_run(a, [(0, 11, 2.0), (0, 18, 2.0)], 0.35, "pipe_white", supports=True)
    P.floodlight(a, (14, 14), 12.0)
    P.fence(a, (-16, -16, 0.3), (16, -16, 0.3), 2.0, 2.6, barbed=True)
    P.fence(a, (16, -16, 0.3), (16, 16, 0.3), 2.0, 2.6, barbed=True)


def tank_terminal(a: Asset):
    a.set(role="storage")
    P.pad(a, (110, 76), 0.3, (0, 0), "gravel")
    positions = [(-34, -20), (0, -20), (34, -20), (-34, 16), (0, 16), (34, 16)]
    for i, (x, y) in enumerate(positions):
        P.tank(a, 11.0, 14.0, (x, y, 0.3), "floating" if i % 2 == 0 else "cone",
               "paint_white", "steel", spiral=True, bands=3, seg=28)
    # main manifold + pump house
    P.pipe_run(a, [(-48, 0, 1.4), (48, 0, 1.4)], 0.45, "pipe_white", supports=True, support_every=8.0)
    for (x, y) in positions:
        P.pipe_run(a, [(x, y, 1.4), (x, 0, 1.4)], 0.20, "pipe_white")
        P.gate_valve(a, (x, 0, 1.4), "Y", 0.28)
    a.box((16.0, 8.0, 7.0), (-52, -28, 3.8), "paint_white", bevel=0.08)
    a.box((16.2, 8.2, 0.4), (-52, -28, 7.5), "paint_grey")
    # truck loading gantry
    a.box((26.0, 5.0, 0.6), (28, -34, 6.0), "steel_dark")
    for i in range(5):
        x = 18 + i * 5.0
        a.beam((x, -34, 0.3), (x, -34, 6.0), 0.3, "galv")
        a.cyl(0.16, 4.0, (x, -34, 3.2), "pipe_white", seg=8)
        a.cyl(0.3, 0.6, (x, -36.2, 2.0), "paint_red", seg=10)
    P.pipe_run(a, [(-40, 0, 1.4), (-40, -34, 1.4), (28, -34, 1.4), (28, -34, 6.0)], 0.30, "pipe_yellow", supports=True, support_every=10.0)
    control_building(a, (-52, 26, 0.3), 14.0, 9.0, 5.0)
    P.floodlight(a, (-46, 42), 16.0)
    P.floodlight(a, (46, 42), 16.0)
    P.flare_stack(a, (48, 30, 0.3), 30.0, "paint_grey", False)


def loading_jetty(a: Asset):
    a.set(placement="waterline", role="transport")
    jetty_deck(a, (0, 0, 6.0), 10.0, 140.0)
    # head platform
    a.box((26.0, 24.0, 1.2), (0, 52.0, 6.0), "steel_dark")
    a.box((25.0, 23.0, 0.2), (0, 52.0, 6.7), "galv")
    for i in range(4):
        loading_arm(a, (-9.0 + i * 6.0, 46.0, 6.8), 12.0, 6.5)
    # mooring dolphins
    for i in range(4):
        a.cyl(1.8, 18.0, (-20.0 if i % 2 == 0 else 20.0, 40.0 + (i // 2) * 22.0, -3.0), "paint_yellow", seg=14)
        a.cyl(2.4, 1.0, (-20.0 if i % 2 == 0 else 20.0, 40.0 + (i // 2) * 22.0, 6.2), "steel_dark", seg=14)
    # pipe rack along jetty
    for i in range(6):
        yy = -60 + i * 22.0
        for s in (-1, 1):
            a.beam((-3.4, yy, 6.6), (-3.4, yy, 9.0), 0.22, "galv")
            a.beam((3.4, yy, 6.6), (3.4, yy, 9.0), 0.22, "galv")
        a.beam((-3.4, yy, 9.0), (3.4, yy, 9.0), 0.18, "galv")
    for k in range(3):
        a.cyl(0.22, 140.0, (-2.0 + k * 2.0, 0, 9.2), ("pipe_white", "pipe_yellow", "pipe_green")[k], seg=8, rot=(math.pi / 2, 0, 0))
    # walkway rails + lights
    P.handrail(a, [(-4.6, -70, 6.6), (-4.6, 40, 6.6)], 1.1, "galv", spacing=10.0)
    P.handrail(a, [(4.6, -70, 6.6), (4.6, 40, 6.6)], 1.1, "galv", spacing=10.0)
    for i in range(4):
        a.cyl(0.2, 8.0, (-4.4, -50 + i * 30, 10.6), "galv", seg=8)
        a.sphere(0.22, (-4.4, -50 + i * 30, 14.7), "emit_amber", seg=(8, 5))
    # control cabin + loading platform
    a.box((8.0, 10.0, 5.0), (0, -68.0, 9.1), "paint_white", bevel=0.06)
    a.box((7.0, 0.08, 1.2), (0, -73.05, 10.6), "glass_dark")


def pig_launcher(a: Asset):
    P.skid(a, 10.0, 4.0, 0.3, loc=(0, 0, 0))
    a.cyl(0.9, 7.0, (0, 0, 1.6), "paint_red", seg=16, rot=(0, math.pi / 2, 0))
    a.dome((3.5, 0, 1.6), 0.9, 0.7, "X", "paint_red", seg=16, rings=4)
    a.dome((-3.5, 0, 1.6), 0.9, 0.5, "X", "paint_red", seg=16, rings=4)
    a.cyl(1.1, 0.3, (3.0, 0, 1.6), "steel_dark", seg=16, rot=(0, math.pi / 2, 0))
    P.pipe_run(a, [(-4.4, 0, 1.6), (-6.0, 0, 1.6)], 0.55, "pipe_yellow")
    P.pipe_run(a, [(4.4, 0, 1.6), (6.0, 0, 1.6)], 0.55, "pipe_yellow")
    P.gate_valve(a, (3.9, 1.4, 1.6), "Y", 0.3)
    P.gate_valve(a, (-3.9, 1.4, 1.6), "Y", 0.3)
    P.pipe_run(a, [(0, 1.0, 0.8), (0, 1.8, 2.6), (2.0, 1.8, 2.6)], 0.14, "pipe_white")
    a.box((1.2, 1.0, 1.2), (2.6, -1.4, 0.9), "paint_blue")


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(
        aid="mid_pump_station", name="Pipeline Pump Station", build=pump_station,
        gameplay=dict(role="transport", tier=2, cost_usd=4_800_000, build_days=18,
                      crew=8, power_kw=3_200, footprint_m2=750, upkeep_usd_day=4_900,
                      capacity_bopd=180_000, boost_bar=45),
    ),
    dict(
        aid="mid_slug_catcher", name="Slug Catcher", build=slug_catcher,
        gameplay=dict(role="processing", tier=2, cost_usd=6_200_000, build_days=22,
                      crew=4, power_kw=120, footprint_m2=560, upkeep_usd_day=3_100,
                      capacity_mmscfd=250, liquid_bbl=12_000),
    ),
    dict(
        aid="mid_gas_plant", name="Gas Processing Plant", build=gas_processing_plant,
        gameplay=dict(role="processing", tier=3, cost_usd=420_000_000, build_days=420,
                      crew=140, power_kw=34_000, footprint_m2=5600, upkeep_usd_day=180_000,
                      capacity_mmscfd=400, ngl_bpd=22_000, sulfur_t_day=180),
    ),
    dict(
        aid="mid_lng_train", name="LNG Liquefaction Train (4 Mtpa)", build=lng_train,
        gameplay=dict(role="processing", tier=4, cost_usd=2_400_000_000, build_days=1100,
                      crew=220, power_kw=180_000, footprint_m2=3700, upkeep_usd_day=640_000,
                      capacity_mtpa=4.0, boiloff_pct_day=0.08),
    ),
    dict(
        aid="mid_lng_sphere", name="LNG Storage Sphere", build=lng_sphere,
        gameplay=dict(role="storage", tier=3, cost_usd=180_000_000, build_days=180,
                      crew=6, power_kw=600, footprint_m2=1150, upkeep_usd_day=24_000,
                      capacity_m3=25_000),
    ),
    dict(
        aid="mid_tank_terminal", name="Crude Terminal & Truck Loading", build=tank_terminal,
        gameplay=dict(role="storage", tier=3, cost_usd=96_000_000, build_days=260,
                      crew=60, power_kw=4_500, footprint_m2=8400, upkeep_usd_day=48_000,
                      capacity_bbl=1_200_000, load_bays=6),
    ),
    dict(
        aid="mid_loading_jetty", name="Marine Loading Jetty", build=loading_jetty,
        gameplay=dict(role="transport", tier=3, cost_usd=240_000_000, build_days=300,
                      crew=30, power_kw=1_200, footprint_m2=3600, upkeep_usd_day=62_000,
                      berths=1, load_rate_bph=45_000, placement="waterline"),
    ),
    dict(
        aid="mid_pig_launcher", name="Pig Launcher / Receiver", build=pig_launcher,
        gameplay=dict(role="support", tier=1, cost_usd=380_000, build_days=3,
                      crew=2, power_kw=0, footprint_m2=40, upkeep_usd_day=120,
                      max_pipe_inches=48),
    ),
]
