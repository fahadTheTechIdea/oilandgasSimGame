"""Game-scale modular kit for the Godot tycoon prototype.

Everything here is authored on a 16 m grid cell, centred on the origin with the
base at z = 0, so a cell at (i, j) can be filled by placing the model at the cell
centre and rotating in 90 degree steps.

Prefix GAM_ keeps these separate from the industrial-scale display kit.
"""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector

CELL = 16.0
HALF = CELL / 2


# --------------------------------------------------------------------------- #
# modular pipe tiles
# --------------------------------------------------------------------------- #


def _sleeper(a: Asset, x, y):
    a.box((1.2, 1.2, 0.35), (x, y, 0.18), "concrete")


def _pipe_tile(a: Asset, paths, r=0.55, mat="pipe_yellow", supports=()):
    """paths: list of polylines (each in tile space) drawn as one pipe network."""
    for path in paths:
        P.pipe_run(a, path, r, mat)
    for (x, y) in supports:
        _sleeper(a, x, y)


def game_pipe_straight(a: Asset):
    a.set(role="infrastructure")
    _pipe_tile(a, [[(-HALF, 0, 1.15), (HALF, 0, 1.15)]], supports=((-6, 0), (6, 0)))
    for s in (-1, 1):
        P.flange(a, (s * HALF, 0, 1.15), "X", 0.75, "steel_dark")


def game_pipe_corner(a: Asset):
    a.set(role="infrastructure")
    path = [(-HALF, 0, 1.15), (-4.0, 0, 1.15)]
    for i in range(1, 7):
        t = i / 7
        ang = -math.pi / 2 * t
        path.append((-4.0 + math.cos(ang) * 4.0, 4.0 + math.sin(ang) * 4.0, 1.15))
    path.append((0, HALF, 1.15))
    _pipe_tile(a, [path], supports=((-5, 0), (0, 5)))
    P.flange(a, (-HALF, 0, 1.15), "X", 0.75, "steel_dark")
    P.flange(a, (0, HALF, 1.15), "Y", 0.75, "steel_dark")


def game_pipe_tee(a: Asset):
    a.set(role="infrastructure")
    _pipe_tile(a, [
        [(-HALF, 0, 1.15), (HALF, 0, 1.15)],
        [(0, 0, 1.15), (0, HALF, 1.15)],
    ], supports=((-6, 0), (6, 0), (0, 6)))
    for (x, y, ax) in ((-HALF, 0, "X"), (HALF, 0, "X"), (0, HALF, "Y")):
        P.flange(a, (x, y, 1.15), ax, 0.75, "steel_dark")
    a.cyl(0.75, 0.55, (0, 0, 1.15), "steel_dark", seg=10, rot=(0, math.pi / 2, 0))


def game_pipe_cross(a: Asset):
    a.set(role="infrastructure")
    _pipe_tile(a, [
        [(-HALF, 0, 1.15), (HALF, 0, 1.15)],
        [(0, -HALF, 1.15), (0, HALF, 1.15)],
    ], supports=((-6, 0), (6, 0), (0, -6), (0, 6)))
    for (x, y, ax) in ((-HALF, 0, "X"), (HALF, 0, "X"), (0, -HALF, "Y"), (0, HALF, "Y")):
        P.flange(a, (x, y, 1.15), ax, 0.75, "steel_dark")
    a.cyl(0.78, 0.62, (0, 0, 1.15), "steel_dark", seg=12, rot=(0, math.pi / 2, 0))
    a.cyl(0.78, 0.62, (0, 0, 1.15), "steel_dark", seg=12, rot=(math.pi / 2, 0, 0))


def game_pipe_end(a: Asset):
    a.set(role="infrastructure")
    _pipe_tile(a, [[(-HALF, 0, 1.15), (4.2, 0, 1.15)]], supports=((-6, 0),))
    P.flange(a, (-HALF, 0, 1.15), "X", 0.75, "steel_dark")
    P.gate_valve(a, (2.6, 0, 1.15), "X", 0.7, "paint_red")
    P.flange(a, (4.2, 0, 1.15), "X", 0.75, "steel_dark", bolts=False)


# --------------------------------------------------------------------------- #
# modular road tiles
# --------------------------------------------------------------------------- #


def _road_base(a: Asset, horizontal=True, vertical=False):
    if horizontal:
        a.box((CELL, 7.0, 0.18), (0, 0, 0.09), "asphalt")
        for i in range(4):
            a.box((1.6, 0.16, 0.02), (-6.0 + i * 4.0, 0, 0.19), "paint_white")
    if vertical:
        a.box((7.0, CELL, 0.18), (0, 0, 0.09), "asphalt")
        for i in range(4):
            a.box((0.16, 1.6, 0.02), (0, -6.0 + i * 4.0, 0.19), "paint_white")


def game_road_straight(a: Asset):
    a.set(role="infrastructure")
    _road_base(a, True, False)


def game_road_corner(a: Asset):
    a.set(role="infrastructure")
    a.box((CELL, 7.0, 0.18), (0, HALF - 3.5, 0.09), "asphalt")
    a.box((7.0, CELL, 0.18), (-HALF + 3.5, 0, 0.09), "asphalt")
    a.box((2.0, 2.0, 0.18), (0, 0, 0.09), "asphalt")


def game_road_tee(a: Asset):
    a.set(role="infrastructure")
    _road_base(a, True, False)
    a.box((7.0, HALF, 0.18), (0, HALF / 2, 0.09), "asphalt")


def game_road_cross(a: Asset):
    a.set(role="infrastructure")
    _road_base(a, True, True)
    a.box((7.0, CELL, 0.18), (0, 0, 0.10), "asphalt")


# --------------------------------------------------------------------------- #
# buildings
# --------------------------------------------------------------------------- #


def game_storage(a: Asset):
    """Single API-650 style crude tank sized for one cell."""
    a.set(role="storage")
    P.pad(a, (13.0, 13.0), 0.25, (0, 0), "concrete")
    P.tank(a, 5.2, 8.5, (0, 0, 0.25), roof="cone", shell="paint_white",
           trim="steel", spiral=False, bands=2, seg=20)
    # caged ladder instead of a full spiral (game silhouette)
    P.caged_ladder(a, (5.4, 0.0, 0.25), 8.2, 0.5, (0, 1, 0))
    P.pipe_run(a, [(5.6, 0, 1.0), (7.6, 0, 1.0)], 0.35, "pipe_yellow")
    P.gate_valve(a, (6.9, 0, 1.0), "X", 0.5, "paint_red")
    P.floodlight(a, (-6.0, -6.0), 8.0, 2)

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # anchor bolts around the shell base
    for i in range(12):
        ang = i * math.pi / 6.0
        a.cyl(0.10, 0.14, (5.15 * math.cos(ang), 5.15 * math.sin(ang), 0.31),
              "steel_dark", seg=6)
    # roof handrail + posts
    for i in range(12):
        ang = i * math.pi / 6.0
        a.cyl(0.045, 0.9, (4.85 * math.cos(ang), 4.85 * math.sin(ang), 8.95),
              "galv", seg=5)
    a.sweep([(4.85 * math.cos(i * math.pi / 6.0), 4.85 * math.sin(i * math.pi / 6.0), 9.4)
             for i in range(13)], 0.05, "galv", seg=6)
    # side-mounted level gauge
    a.cyl(0.08, 5.4, (-5.35, 2.1, 3.4), "glass_dark", seg=6)
    for gz in (0.7, 6.1):
        a.cyl(0.16, 0.14, (-5.35, 2.1, gz), "steel_dark", seg=6)
    # inlet flange at the pipe stub
    a.cyl(0.55, 0.16, (5.55, 0, 1.0), "steel_dark", seg=12, axis=(1, 0, 0))


def game_refinery(a: Asset):
    """Compact 2x2-cell topping unit: furnace, column, air cooler, rack."""
    a.set(role="refining")
    P.pad(a, (30.0, 30.0), 0.3, (0, 0), "concrete")
    # crude furnace
    a.box((7.0, 6.0, 7.0), (-8.0, 5.0, 3.8), "paint_grey", bevel=0.1)
    a.cyl(0.9, 9.0, (-6.0, 5.0, 8.5), "steel_dark", seg=12)
    # distillation column
    a.cyl(2.2, 14.0, (3.0, 4.0, 7.3), "insulation", seg=16)
    a.dome((3.0, 4.0, 14.3), 2.2, 1.0, "Z", "insulation", seg=16, rings=4)
    for i in range(3):
        z = 3.0 + i * 4.0
        a.cyl(2.35, 0.18, (3.0, 4.0, z), "steel", seg=16)
    P.caged_ladder(a, (5.4, 4.0, 0.3), 13.5, 0.45, (0, 1, 0))
    # air cooler + product drum
    a.box((6.0, 5.0, 1.6), (8.0, -6.0, 1.4), "galv", bevel=0.06)
    for i in range(3):
        a.cyl(0.9, 0.25, (6.6 + i * 1.4, -6.0, 2.4), "steel_dark", seg=12)
    P.vessel(a, 1.1, 6.0, (-9.0, -7.0, 1.9), "X", "paint_white", 2)
    # pipe rack between units
    for i in range(4):
        x = -6.0 + i * 4.0
        for s in (-1, 1):
            a.beam((x, s * 1.6, 0.3), (x, s * 1.6, 4.4), 0.22, "galv")
        a.beam((x, -1.6, 4.4), (x, 1.6, 4.4), 0.18, "galv")
    for k in range(3):
        a.cyl(0.22, 16.0, (0.0, -0.9 + k * 0.9, 4.6),
              ("pipe_white", "pipe_yellow", "pipe_green")[k], seg=8, rot=(0, math.pi / 2, 0))
    # flare
    a.cyl(0.55, 16.0, (-12.0, -11.0, 8.0), "paint_grey", seg=10)
    a.cyl(0.8, 0.6, (-12.0, -11.0, 16.2), "steel_dark", seg=10)
    a.sphere(0.35, (-12.0, -11.0, 16.9), "emit_amber", seg=(8, 5))
    # control hut
    a.box((6.0, 5.0, 3.0), (10.0, 8.0, 1.8), "paint_white", bevel=0.08)
    a.box((5.0, 0.06, 1.0), (10.0, 5.48, 2.3), "glass_dark")
    # inlet / outlet stubs at the cell edges
    P.pipe_run(a, [(-14.0, 0, 0.8), (-9.0, 0, 0.8), (-9.0, 5.0, 0.8)], 0.4, "pipe_yellow")
    P.pipe_run(a, [(14.0, 0, 0.8), (10.0, 0, 0.8), (10.0, -7.0, 0.8)], 0.4, "pipe_green")
    P.floodlight(a, (12.0, -12.0), 10.0, 2)

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # control hut roof rail + rooftop AC
    for i in range(3):
        a.cyl(0.04, 0.55, (7.6 + i * 2.4, 10.4, 3.55), "galv", seg=5)
    a.sweep([(7.0, 10.4, 3.9), (13.0, 10.4, 3.9)], 0.04, "galv", seg=5)
    a.box((1.4, 1.0, 0.6), (8.6, 8.4, 3.65), "galv", bevel=0.03)
    # furnace access ladder
    P.caged_ladder(a, (-3.55, 5.0, 0.3), 7.2, 0.40, (0, 1, 0))
    # air-cooler handrails
    for by in (-8.5, -3.5):
        a.beam((5.0, by, 2.45), (11.0, by, 2.45), 0.05, "galv")
        for bx in (5.5, 8.0, 10.5):
            a.cyl(0.04, 0.75, (bx, by, 2.1), "galv", seg=5)
    # pipe-rack valve wheels + flow meter
    for k in range(3):
        a.cyl(0.18, 0.10, (2.4, -0.9 + k * 0.9, 5.0), "paint_red", seg=8)
    a.box((0.7, 0.7, 0.5), (-1.8, 1.7, 4.9), "paint_yellow", bevel=0.02)


def game_explorer(a: Asset):
    """Exploration office: field survey base that reveals deposits."""
    a.set(role="support")
    P.pad(a, (13.0, 11.0), 0.2, (0, 0), "concrete")
    a.box((10.0, 7.0, 3.4), (0, 0, 1.9), "paint_white", bevel=0.09)
    a.box((10.2, 7.2, 0.3), (0, 0, 3.7), "paint_grey")
    a.box((3.4, 0.06, 1.2), (-1.5, -3.53, 2.4), "glass_dark")
    a.box((0.9, 0.12, 2.0), (2.6, -3.53, 1.4), "paint_grey")
    # antenna + dish
    a.cyl(0.12, 7.0, (4.0, 3.0, 3.5), "galv", seg=8)
    a.cyl(0.9, 0.25, (4.0, 3.0, 7.1), "paint_white", seg=12, axis=(0.3, -0.4, 0.9))
    a.sphere(0.18, (4.0, 3.0, 7.5), "emit_red", seg=(6, 4))
    # sign
    for s in (-1, 1):
        a.cyl(0.07, 3.0, (-4.6 + s * 0.9, -4.6, 1.5), "galv", seg=6)
    a.box((2.6, 0.1, 1.0), (-4.6, -4.6, 3.0), "paint_blue")
    a.box((2.2, 0.06, 0.24), (-4.6, -4.66, 3.2), "paint_white")
    a.box((1.8, 0.06, 0.16), (-4.6, -4.66, 2.85), "paint_yellow")

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # roof edge rail
    for i in range(4):
        bx = -4.5 + i * 3.0
        for by in (-3.5, 3.5):
            a.cyl(0.045, 0.65, (bx, by, 4.0), "galv", seg=5)
    a.sweep([(-5.0, -3.5, 4.3), (5.0, -3.5, 4.3)], 0.045, "galv", seg=5)
    a.sweep([(-5.0, 3.5, 4.3), (5.0, 3.5, 4.3)], 0.045, "galv", seg=5)
    # rooftop AC + vent
    a.box((1.8, 1.4, 0.65), (-2.6, 1.4, 4.0), "galv", bevel=0.03)
    a.cyl(0.16, 1.1, (2.0, 2.2, 4.2), "steel_dark", seg=6)
    # entrance canopy + steps + bollards
    a.box((4.6, 1.8, 0.18), (0.6, -4.6, 2.55), "paint_grey", bevel=0.02)
    for i in range(3):
        a.box((4.2, 0.8, 0.12), (0.6, -4.3 - i * 0.5, 0.22 + i * 0.14), "concrete")
    for bx in (-1.4, 2.6):
        a.cyl(0.10, 0.85, (bx, -5.0, 0.62), "paint_yellow", seg=8)
    # glazing mullions
    for i in range(4):
        a.box((0.07, 0.09, 1.10), (-2.6 + i * 1.1, -3.54, 2.40), "steel_dark")
    # generator skid + exhaust
    a.box((2.0, 1.1, 0.35), (3.6, -2.2, 0.38), "steel_dark")
    a.box((1.4, 0.9, 0.9), (3.6, -2.2, 1.0), "paint_green", bevel=0.03)
    a.cyl(0.10, 1.4, (4.2, -2.2, 1.9), "steel_dark", seg=6)
    # cable conduit to the antenna mast
    a.sweep([(-2.0, 2.0, 3.9), (1.5, 2.6, 4.2), (3.6, 2.9, 4.6)], 0.07, "steel_dark", seg=5)
    # corner floodlights + pad joints
    for bx in (-5.9, 5.9):
        a.cyl(0.07, 2.8, (bx, -5.0, 1.55), "galv", seg=6)
        a.box((0.45, 0.28, 0.22), (bx, -5.0, 3.05), "emit_amber")
    for i in range(4):
        a.box((0.05, 10.0, 0.02), (-6.0 + i * 4.0, 0, 0.215), "steel_dark")


def game_deposit(a: Asset):
    """Survey marker sitting on an oil-bearing cell."""
    a.set(role="marker")
    a.cyl(5.5, 0.06, (0, 0, 0.03), "asphalt", seg=20)
    a.cyl(4.6, 0.07, (0, 0, 0.05), "oil", seg=20)
    a.cyl(0.12, 5.0, (0, 0, 2.5), "paint_red", seg=8)
    a.box((2.0, 0.08, 1.2), (1.0, 0, 4.4), "paint_yellow")
    a.box((0.9, 0.10, 0.4), (0.6, 0, 4.6), "paint_white")
    for i in range(4):
        ang = TAU * i / 4 + math.pi / 4
        a.cyl(0.08, 1.2, (math.cos(ang) * 6.0, math.sin(ang) * 6.0, 0.6), "galv", seg=6)


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(aid="gam_pipe_straight", name="Pipe Straight", build=game_pipe_straight,
         gameplay=dict(role="pipe", cost_usd=400, kind="pipe", mask=10)),
    dict(aid="gam_pipe_corner", name="Pipe Corner", build=game_pipe_corner,
         gameplay=dict(role="pipe", cost_usd=400, kind="pipe", mask=3)),
    dict(aid="gam_pipe_tee", name="Pipe Tee", build=game_pipe_tee,
         gameplay=dict(role="pipe", cost_usd=400, kind="pipe", mask=11)),
    dict(aid="gam_pipe_cross", name="Pipe Cross", build=game_pipe_cross,
         gameplay=dict(role="pipe", cost_usd=400, kind="pipe", mask=15)),
    dict(aid="gam_pipe_end", name="Pipe End", build=game_pipe_end,
         gameplay=dict(role="pipe", cost_usd=400, kind="pipe", mask=2)),
    dict(aid="gam_road_straight", name="Road Straight", build=game_road_straight,
         gameplay=dict(role="road", cost_usd=200, kind="road", mask=10)),
    dict(aid="gam_road_corner", name="Road Corner", build=game_road_corner,
         gameplay=dict(role="road", cost_usd=200, kind="road", mask=3)),
    dict(aid="gam_road_tee", name="Road Tee", build=game_road_tee,
         gameplay=dict(role="road", cost_usd=200, kind="road", mask=11)),
    dict(aid="gam_road_cross", name="Road Cross", build=game_road_cross,
         gameplay=dict(role="road", cost_usd=200, kind="road", mask=15)),
    dict(aid="gam_storage", name="Crude Storage Tank", build=game_storage,
         gameplay=dict(role="storage", cost_usd=25000, kind="storage", capacity=600)),
    dict(aid="gam_refinery", name="Topping Refinery", build=game_refinery,
         gameplay=dict(role="refining", cost_usd=120000, kind="refinery", size=2,
                       throughput=3.0)),
    dict(aid="gam_explorer", name="Exploration Office", build=game_explorer,
         gameplay=dict(role="support", cost_usd=30000, kind="explorer", radius=11, size=2)),
    dict(aid="gam_deposit", name="Oil Deposit Marker", build=game_deposit,
         gameplay=dict(role="marker", cost_usd=0, kind="deposit")),
]
