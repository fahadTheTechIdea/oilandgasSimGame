"""Downstream refinery process units."""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P
from .midstream import column, pipe_rack, exchanger, control_building

V = Vector


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #


def fired_heater(a: Asset, loc, w=14.0, d=9.0, h=13.0, stack_h=22.0, mat="paint_grey"):
    x, y, z = P.xyz(loc)
    a.box((w, d, h), (x, y, z + h / 2), mat, bevel=0.06)
    a.box((w * 0.5, d * 0.5, 0.3), (x, y, z + h + 0.15), "steel_dark")
    a.cyl(1.1, stack_h, (x + w * 0.28, y, z + h + stack_h / 2), "steel_dark", seg=16)
    a.cyl(1.3, 1.2, (x + w * 0.28, y, z + h + stack_h), "paint_grey", seg=16)
    # burners + access platform
    for i in range(3):
        a.cyl(0.35, 0.8, (x - w * 0.3 + i * 2.6, y - d / 2 - 0.3, z + 1.2), "paint_red", seg=10)
    a.box((w * 1.1, 1.2, 0.12), (x, y - d / 2 - 0.5, z + 2.6), "galv")
    P.handrail(a, [(x - w * 0.55, y - d / 2 - 0.5, z + 2.7), (x + w * 0.55, y - d / 2 - 0.5, z + 2.7)], 1.0, "galv")
    # radiant tubes
    for i in range(4):
        a.cyl(0.22, h * 0.8, (x - w * 0.35 + i * w * 0.22, y + d * 0.2, z + h * 0.5), "copper", seg=8)


def reactor(a: Asset, loc, r=2.2, h=14.0, mat="insulation"):
    column(a, loc, r, h, mat, platforms=2, skirt=True)


def air_cooler(a: Asset, loc, w=10.0, d=6.0, mat="galv"):
    x, y, z = P.xyz(loc)
    a.box((w, d, 2.4), (x, y, z + 1.2), mat, bevel=0.04)
    for i in range(4):
        for j in range(2):
            a.cyl(1.1, 0.22, (x - w * 0.33 + i * w * 0.22, y - d * 0.22 + j * d * 0.44, z + 2.5),
                  "steel_dark", seg=14)
    for s in (-1, 1):
        a.beam((x - w * 0.45, y, z), (x - w * 0.45, y, z + 6.0), 0.3, "steel_dark")
        a.beam((x + w * 0.45, y, z), (x + w * 0.45, y, z + 6.0), 0.3, "steel_dark")
    a.beam((x - w * 0.45, y, z + 6.0), (x + w * 0.45, y, z + 6.0), 0.3, "steel_dark")


def furnace_stack(a: Asset, loc, h=30.0, r=1.4):
    x, y, z = P.xyz(loc)
    a.cyl(r, h, (x, y, z + h / 2), "steel_dark", seg=18)
    a.cyl(r * 1.15, 1.0, (x, y, z + h), "paint_grey", seg=18)
    for i in range(3):
        a.cyl(r * 1.05, 0.18, (x, y, z + h * (0.35 + i * 0.2)), "paint_grey", seg=18)


# --------------------------------------------------------------------------- #
# units
# --------------------------------------------------------------------------- #


def cdu_unit(a: Asset):
    """Crude distillation unit: furnace, atmospheric column, overhead system."""
    a.set(role="refining")
    P.pad(a, (66, 44), 0.3, (0, 0), "concrete")
    fired_heater(a, (-18, 6, 0.3), 16.0, 10.0, 15.0, 26.0)
    column(a, (2, 8, 0.3), 4.2, 48.0, "insulation", platforms=5)
    # overhead condensers + reflux drum
    for i in range(2):
        exchanger(a, (12, 18 + i * 6.0, 3.4), 8.0, 1.0, "X", "paint_white")
    P.vessel(a, 2.0, 10.0, (20, 20, 4.0), "X", "paint_white", 2)
    a.box((3.0, 3.0, 3.6), (20, 14, 2.1), "paint_blue", bevel=0.05)
    # side strippers
    for i, (x, y) in enumerate([(-8, 22), (-2, 26)]):
        a.cyl(1.4, 16.0, (x, y, 8.3), "insulation", seg=16)
        a.dome((x, y, 16.3), 1.4, 0.8, "Z", "insulation", seg=16, rings=4)
    pipe_rack(a, (0, -8, 0.3), 44.0, 10.0, 8.0, 3, "galv", 4)
    P.pipe_run(a, [(-26, -4, 6.0), (-14, -4, 6.0), (-14, 4, 6.0), (-18, 4, 6.0)], 0.32, "pipe_white", supports=True)
    control_building(a, (26, -16, 0.3), 12.0, 8.0, 4.5)
    air_cooler(a, (26, 4, 0.3))
    P.flare_stack(a, (-28, -16, 0.3), 38.0, "paint_grey", True)


def vdu_unit(a: Asset):
    a.set(role="refining")
    P.pad(a, (54, 36), 0.3, (0, 0), "concrete")
    fired_heater(a, (-16, 4, 0.3), 14.0, 9.0, 13.0, 24.0)
    column(a, (0, 4, 0.3), 3.6, 38.0, "insulation", platforms=4)
    # vacuum ejectors / condensers
    for i in range(3):
        a.cyl(0.9, 5.0, (10.0 + i * 2.2, 12.0, 3.0), "steel_dark", seg=14)
        a.cyl(0.5, 3.0, (10.0 + i * 2.2, 12.0, 7.0), "stainless", seg=12)
    P.vessel(a, 1.6, 8.0, (16, 8, 3.4), "X", "paint_white", 2)
    pipe_rack(a, (2, -8, 0.3), 34.0, 8.0, 7.0, 2, "galv", 3)
    exchanger(a, (16, -6, 3.0), 7.0, 0.8, "X")
    air_cooler(a, (-20, -12, 0.3), 8.0, 5.0)
    control_building(a, (22, -16, 0.3), 10.0, 7.0, 4.2)


def fcc_unit(a: Asset):
    """Fluid catalytic cracker: riser, regenerator, fractionator, blower."""
    a.set(role="refining")
    P.pad(a, (70, 50), 0.3, (0, 0), "concrete")
    # regenerator
    a.cyl(8.0, 16.0, (-4, 6, 12.3), "paint_grey", seg=24)
    a.dome((-4, 6, 20.3), 8.0, 3.2, "Z", "paint_grey", seg=24, rings=5)
    a.cyl(8.3, 0.8, (-4, 6, 20.0), "paint_yellow", seg=24)
    # riser + reactor
    a.cyl(1.6, 26.0, (8, 6, 17.3), "paint_white", seg=16)
    a.cyl(3.2, 8.0, (8, 6, 34.0), "paint_white", seg=18)
    a.dome((8, 6, 38.0), 3.2, 1.4, "Z", "paint_white", seg=18, rings=4)
    # fractionator
    column(a, (24, 6, 0.3), 4.0, 34.0, "insulation", platforms=4)
    # flue gas stack + blower
    furnace_stack(a, (-18, 6, 0.3), 34.0, 1.6)
    a.box((8.0, 5.0, 4.0), (-18, -6, 2.3), "paint_blue", bevel=0.06)
    a.cyl(1.4, 4.0, (-13, -6, 2.3), "steel_dark", seg=14, rot=(0, math.pi / 2, 0))
    # catalyst hopper + piping
    a.cyl(2.4, 9.0, (-14, 12, 5.3), "paint_red", seg=16)
    P.pipe_run(a, [(-14, 12, 10.0), (-8, 12, 10.0), (-8, 6, 12.0)], 0.35, "pipe_white")
    air_cooler(a, (24, -12, 0.3), 12.0, 7.0)
    pipe_rack(a, (8, -12, 0.3), 40.0, 9.0, 8.0, 3, "galv", 4)
    control_building(a, (-24, -16, 0.3), 12.0, 8.0, 4.5)
    P.flare_stack(a, (30, 22, 0.3), 42.0, "paint_grey", True)


def reformer_unit(a: Asset):
    a.set(role="refining")
    P.pad(a, (48, 36), 0.3, (0, 0), "concrete")
    for i in range(3):
        reactor(a, (-12 + i * 6.0, 8, 0.3), 1.9, 15.0 + i * 1.5, "paint_white")
    fired_heater(a, (8, 10, 0.3), 12.0, 8.0, 12.0, 22.0)
    # recycle gas compressor + knockout
    P.compressor_package(a, (18, -6, 0.3), "paint_blue")
    P.vessel(a, 1.4, 6.0, (18, 6, 3.0), "X", "paint_white", 2)
    pipe_rack(a, (-4, -10, 0.3), 30.0, 8.0, 7.0, 2, "galv", 3)
    exchanger(a, (-16, -6, 3.0), 6.0, 0.8, "X")
    air_cooler(a, (10, -14, 0.3), 8.0, 5.0)
    control_building(a, (-18, -18, 0.3), 10.0, 7.0, 4.0)


def hydrotreater_unit(a: Asset):
    a.set(role="refining")
    P.pad(a, (44, 32), 0.3, (0, 0), "concrete")
    reactor(a, (-6, 6, 0.3), 2.4, 20.0, "insulation")
    fired_heater(a, (6, 10, 0.3), 11.0, 7.0, 11.0, 20.0)
    # high pressure separator + recycle compressor
    P.vessel(a, 1.6, 8.0, (-14, -4, 3.4), "X", "paint_white", 2)
    P.compressor_package(a, (14, -6, 0.3), "paint_blue")
    # amine absorber tie-in
    column(a, (18, 8, 0.3), 1.6, 16.0, "paint_white", platforms=2)
    pipe_rack(a, (-2, -12, 0.3), 26.0, 7.0, 6.0, 2, "galv", 3)
    exchanger(a, (-16, 10, 3.0), 6.0, 0.7, "X")
    air_cooler(a, (4, -16, 0.3), 7.0, 4.5)
    control_building(a, (20, -16, 0.3), 9.0, 6.5, 4.0)


def coker_unit(a: Asset):
    a.set(role="refining")
    P.pad(a, (52, 42), 0.3, (0, 0), "concrete")
    # coke drums
    for i in range(2):
        x = -8 + i * 11.0
        a.cyl(3.4, 26.0, (x, 8, 13.3), "paint_grey", seg=20)
        a.dome((x, 8, 26.3), 3.4, 1.6, "Z", "paint_grey", seg=20, rings=4)
        a.cyl(3.6, 0.6, (x, 8, 26.0), "paint_yellow", seg=20)
        for k in range(3):
            a.cyl(3.5, 0.3, (x, 8, 6.0 + k * 7.0), "steel_dark", seg=20)
        # derrick structure
        for s in (-1, 1):
            a.beam((x + s * 3.6, 8, 26.5), (x + s * 2.2, 8, 36.0), 0.35, "paint_yellow")
        a.beam((x - 2.2, 8, 36.0), (x + 2.2, 8, 36.0), 0.3, "paint_yellow")
    column(a, (18, 8, 0.3), 3.4, 30.0, "insulation", platforms=3)
    fired_heater(a, (-20, -6, 0.3), 13.0, 9.0, 13.0, 24.0)
    # coke pit + conveyor
    a.box((18.0, 8.0, 0.6), (0, -14, 0.3), "concrete_dark")
    a.beam((0, -14, 2.0), (10, -20, 9.0), 0.9, "paint_yellow")
    air_cooler(a, (22, -14, 0.3), 10.0, 6.0)
    pipe_rack(a, (2, -4, 0.3), 30.0, 8.0, 7.0, 2, "galv", 3)
    control_building(a, (-24, 14, 0.3), 10.0, 7.0, 4.2)


def amine_unit(a: Asset):
    a.set(role="refining")
    P.pad(a, (40, 30), 0.3, (0, 0), "concrete")
    column(a, (-6, 6, 0.3), 2.2, 24.0, "paint_white", platforms=3)
    column(a, (10, 8, 0.3), 1.8, 18.0, "insulation", platforms=2)
    # reboiler + lean/rich exchangers
    exchanger(a, (2, -2, 3.0), 7.0, 0.9, "X", "paint_grey")
    a.box((5.0, 4.0, 2.6), (10, -8, 1.6), "paint_blue", bevel=0.05)
    # sump + surge drum
    P.vessel(a, 1.5, 7.0, (-14, -6, 3.2), "X", "paint_white", 2)
    a.cyl(1.0, 8.0, (18, -4, 4.3), "paint_white", seg=14)
    pipe_rack(a, (0, -12, 0.3), 26.0, 7.0, 6.0, 2, "galv", 3)
    air_cooler(a, (18, 10, 0.3), 7.0, 4.5)
    control_building(a, (-16, 16, 0.3), 9.0, 6.5, 4.0)


def sulfur_recovery(a: Asset):
    """Claus SRU: reaction furnace, converters, condensers, incinerator."""
    a.set(role="refining")
    P.pad(a, (44, 34), 0.3, (0, 0), "concrete")
    # reaction furnace
    a.box((9.0, 6.0, 6.0), (-14, 4, 3.3), "insulation", bevel=0.06)
    a.cyl(1.0, 18.0, (-10, 4, 9.3), "steel_dark", seg=14)
    # converters
    for i in range(2):
        a.cyl(2.2, 6.0, (-2 + i * 8.0, 6, 3.3), "paint_grey", seg=16)
        a.dome((-2 + i * 8.0, 6, 6.3), 2.2, 1.0, "Z", "paint_grey", seg=16, rings=4)
    # condensers
    for i in range(3):
        P.vessel(a, 1.2, 8.0, (-4 + i * 7.0, -4, 2.4), "X", "paint_white", 2)
    # sulfur pit + degassing
    a.box((12.0, 6.0, 1.4), (12, -12, 0.9), "concrete_dark")
    a.cyl(1.4, 5.0, (16, 12, 2.8), "paint_white", seg=14)
    # incinerator stack
    furnace_stack(a, (18, 0, 0.3), 30.0, 1.2)
    # tail gas piping
    P.pipe_run(a, [(-14, 0, 5.0), (16, 0, 5.0), (16, 8, 5.0)], 0.32, "pipe_white", supports=True, support_every=6.0)
    air_cooler(a, (-18, -10, 0.3), 7.0, 4.5)
    control_building(a, (-16, 14, 0.3), 8.0, 6.0, 3.8)


def cooling_tower(a: Asset):
    P.pad(a, (28, 28), 0.3, (0, 0), "concrete")
    # basin
    a.box((24.0, 24.0, 1.6), (0, 0, 1.1), "concrete")
    # louvers
    for s in (-1, 1):
        a.box((24.0, 0.6, 8.0), (0, s * 11.0, 5.5), "concrete_dark")
        a.box((0.6, 24.0, 8.0), (s * 11.0, 0, 5.5), "concrete_dark")
    for i in range(6):
        a.box((23.0, 0.3, 0.3), (0, -11.0 + 0.0, 2.4 + i * 1.3), "steel_dark")
    # fan deck
    a.box((22.0, 22.0, 1.0), (0, 0, 9.9), "concrete")
    for i in range(3):
        for j in range(3):
            a.cyl(3.0, 2.2, (-7 + i * 7.0, -7 + j * 7.0, 11.5), "galv", seg=16)
            a.cyl(2.7, 0.5, (-7 + i * 7.0, -7 + j * 7.0, 12.7), "steel_dark", seg=16)
            for k in range(4):
                a.box((5.4, 0.5, 0.08), (-7 + i * 7.0, -7 + j * 7.0, 12.85), "steel_light",
                      rot=(0, 0, math.pi * k / 4))
    # stair + rail
    P.stairs(a, (-13.5, 6.0, 0.3), 1.2, 10.0, 4.5, (-1, 0, 0), 16, "galv")
    P.handrail(a, [(-11.0, -11.0, 10.4), (11.0, -11.0, 10.4), (11.0, 11.0, 10.4),
                   (-11.0, 11.0, 10.4), (-11.0, -11.0, 10.4)], 1.1, "galv", spacing=4.0)


def refinery_flare(a: Asset):
    P.pad(a, (22, 22), 0.3, (0, 0), "concrete")
    P.flare_stack(a, (0, 0, 0.3), 62.0, "paint_grey", derrick_style=True)
    P.vessel(a, 1.6, 6.0, (6, 4, 2.4), "X", "paint_white", 2)
    P.pipe_run(a, [(6, 4, 3.0), (2, 4, 3.0), (2, 2, 0.3), (0, 2, 0.3)], 0.4, "pipe_yellow")
    P.fence(a, (-11, -11, 0.3), (11, -11, 0.3), 2.2, 3.0, barbed=True)


def pipe_rack_module(a: Asset):
    """20 m modular pipe rack (snap tile for refinery layout)."""
    P.pad(a, (21.0, 9.0), 0.15, (0, 0), "concrete")
    pipe_rack(a, (0, 0, 0.15), 20.0, 7.0, 6.5, 3, "galv", 4)
    for i in range(2):
        x = -9.0 + i * 18.0
        for s in (-1, 1):
            a.box((0.5, 0.5, 0.05), (x, s * 3.5, 0.2), "paint_yellow")


def control_room(a: Asset):
    P.pad(a, (30, 22), 0.3, (0, 0), "concrete")
    control_building(a, (-6, 0, 0.3), 16.0, 10.0, 6.0)
    # electrical substation
    for i in range(2):
        a.box((6.0, 4.0, 3.6), (10, -5 + i * 7.0, 2.1), "paint_grey", bevel=0.05)
        for k in range(3):
            a.cyl(0.22, 3.0, (10.0 - 2.0 + k * 2.0, -5 + i * 7.0, 5.4), "brass", seg=8)
    a.cyl(0.6, 10.0, (13, 8, 5.3), "galv", seg=10)
    P.floodlight(a, (-13, 9), 10.0)
    P.ac_unit(a, (0, -6, 6.3), (1.4, 1.0, 0.9))
    P.fence(a, (-15, -11, 0.3), (15, -11, 0.3), 2.2, 3.0, barbed=True)

    # --- hard-surface detail pass (blender-skills) ------------------------- #
    # roof safety rail around the parapet
    for i in range(6):
        bx = -14.0 + i * 3.2
        for by in (-5.0, 5.0):
            a.cyl(0.05, 0.8, (bx, by, 6.65), "galv", seg=5)
    a.sweep([(-14.0, -5.0, 7.05), (2.0, -5.0, 7.05)], 0.05, "galv", seg=5)
    a.sweep([(-14.0, 5.0, 7.05), (2.0, 5.0, 7.05)], 0.05, "galv", seg=5)
    # rooftop condensers + vent stack
    a.box((2.6, 1.8, 0.9), (-11.0, -2.0, 6.60), "galv", bevel=0.04)
    a.box((1.8, 1.4, 0.7), (-7.0, 2.5, 6.55), "galv", bevel=0.04)
    a.cyl(0.18, 1.4, (-4.5, 3.2, 7.00), "steel_dark", seg=6)
    # entrance canopy, steps and bollards (front is -Y)
    a.box((5.0, 2.0, 0.22), (-6.0, -6.6, 3.60), "paint_grey", bevel=0.03)
    for i in range(3):
        a.box((4.6, 0.9, 0.14), (-6.0, -6.3 - i * 0.55, 0.30 + i * 0.16), "concrete")
    for bx in (-8.6, -3.4):
        a.cyl(0.12, 0.9, (bx, -7.0, 0.75), "paint_yellow", seg=8)
    # glazing mullions + illuminated base sign
    for i in range(5):
        a.box((0.08, 0.10, 1.15), (-8.0 + i * 1.6, -5.06, 3.95), "steel_dark")
    a.box((3.4, 0.10, 0.70), (-6.0, -6.9, 4.55), "emit_amber")
    # cable tray from the substation to the control building
    a.sweep([(4.0, -3.0, 5.0), (2.0, -2.0, 5.0), (-2.0, -2.0, 5.0)], 0.10, "galv", seg=6)
    # corner floodlights on the apron
    for bx in (-13.0, 1.0):
        a.cyl(0.08, 3.2, (bx, -10.2, 1.90), "galv", seg=6)
        a.box((0.5, 0.3, 0.25), (bx, -10.2, 3.50), "emit_amber")
    # pad expansion joints
    for i in range(5):
        a.box((0.06, 20.0, 0.02), (-13.0 + i * 4.0, 0, 0.315), "steel_dark")


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(
        aid="ref_cdu", name="Crude Distillation Unit", build=cdu_unit,
        gameplay=dict(role="refining", tier=2, cost_usd=380_000_000, build_days=380,
                      crew=90, power_kw=18_000, footprint_m2=2900, upkeep_usd_day=150_000,
                      throughput_bpd=150_000, products=["naphtha", "kerosene", "diesel", "resid"]),
    ),
    dict(
        aid="ref_vdu", name="Vacuum Distillation Unit", build=vdu_unit,
        gameplay=dict(role="refining", tier=2, cost_usd=190_000_000, build_days=260,
                      crew=45, power_kw=9_000, footprint_m2=1900, upkeep_usd_day=78_000,
                      throughput_bpd=90_000, feed="atmospheric_resid"),
    ),
    dict(
        aid="ref_fcc", name="Fluid Catalytic Cracking Unit", build=fcc_unit,
        gameplay=dict(role="refining", tier=3, cost_usd=720_000_000, build_days=520,
                      crew=120, power_kw=42_000, footprint_m2=3500, upkeep_usd_day=260_000,
                      throughput_bpd=70_000, gasoline_yield=0.52),
    ),
    dict(
        aid="ref_reformer", name="Catalytic Reformer", build=reformer_unit,
        gameplay=dict(role="refining", tier=3, cost_usd=310_000_000, build_days=340,
                      crew=60, power_kw=14_000, footprint_m2=1700, upkeep_usd_day=110_000,
                      throughput_bpd=40_000, octane_gain=18),
    ),
    dict(
        aid="ref_hydrotreater", name="Hydrotreater", build=hydrotreater_unit,
        gameplay=dict(role="refining", tier=2, cost_usd=260_000_000, build_days=300,
                      crew=50, power_kw=11_000, footprint_m2=1400, upkeep_usd_day=92_000,
                      throughput_bpd=55_000, sulfur_removal_pct=99.5),
    ),
    dict(
        aid="ref_coker", name="Delayed Coking Unit", build=coker_unit,
        gameplay=dict(role="refining", tier=3, cost_usd=540_000_000, build_days=430,
                      crew=80, power_kw=16_000, footprint_m2=2100, upkeep_usd_day=180_000,
                      throughput_bpd=35_000, coke_t_day=900),
    ),
    dict(
        aid="ref_amine", name="Amine Sweetening Unit", build=amine_unit,
        gameplay=dict(role="refining", tier=2, cost_usd=120_000_000, build_days=200,
                      crew=30, power_kw=5_000, footprint_m2=1200, upkeep_usd_day=48_000,
                      capacity_mmscfd=120, h2s_removal_pct=99.9),
    ),
    dict(
        aid="ref_sru", name="Claus Sulfur Recovery Unit", build=sulfur_recovery,
        gameplay=dict(role="refining", tier=3, cost_usd=160_000_000, build_days=240,
                      crew=28, power_kw=2_800, footprint_m2=1500, upkeep_usd_day=52_000,
                      sulfur_t_day=220, recovery_pct=97.5),
    ),
    dict(
        aid="ref_cooling_tower", name="Induced Draft Cooling Tower", build=cooling_tower,
        gameplay=dict(role="support", tier=2, cost_usd=34_000_000, build_days=150,
                      crew=12, power_kw=4_200, footprint_m2=780, upkeep_usd_day=16_000,
                      cooling_mw=180),
    ),
    dict(
        aid="ref_flare", name="Refinery Flare (62 m)", build=refinery_flare,
        gameplay=dict(role="support", tier=1, cost_usd=22_000_000, build_days=120,
                      crew=8, power_kw=0, footprint_m2=480, upkeep_usd_day=8_500,
                      capacity_mmscfd=180),
    ),
    dict(
        aid="ref_pipe_rack", name="Pipe Rack Module (20 m)", build=pipe_rack_module,
        gameplay=dict(role="transport", tier=1, cost_usd=650_000, build_days=4,
                      crew=3, power_kw=0, footprint_m2=190, upkeep_usd_day=180,
                      length_m=20, snap="rack"),
    ),
    dict(
        aid="ref_control_room", name="Control Room & Substation", build=control_room,
        gameplay=dict(role="support", tier=2, cost_usd=48_000_000, build_days=160,
                      crew=40, power_kw=1_200, footprint_m2=660, upkeep_usd_day=22_000,
                      automation_bonus=0.08),
    ),
]
