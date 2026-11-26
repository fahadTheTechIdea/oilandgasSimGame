"""Environment, site and gameplay props."""

from __future__ import annotations

import math

from mathutils import Vector

from .core import TAU, Asset
from . import parts as P

V = Vector


def fence_module(a: Asset):
    P.fence(a, (-2.0, 0, 0), (2.0, 0, 0), 2.0, 2.0, "galv", True)
    for s in (-1, 1):
        a.box((0.45, 0.45, 0.25), (s * 2.0, 0, 0.12), "concrete")


def floodlight_tower(a: Asset):
    P.floodlight(a, (0, 0), 14.0, 4, "galv")
    a.box((1.6, 1.6, 0.9), (0, 0, 0.45), "paint_grey", bevel=0.04)
    for i in range(3):
        a.cyl(0.08, 4.0, (0.5, -0.4 + i * 0.4, 8.0), "plastic_black", seg=6)


def portacabin(a: Asset):
    a.set(role="support")
    P.skid(a, 6.2, 2.6, 0.2, loc=(0, 0, 0), lugs=False)
    a.box((6.0, 2.4, 2.5), (0, 0, 1.45), "paint_white", bevel=0.04)
    a.box((6.1, 2.5, 0.16), (0, 0, 2.78), "paint_grey")
    # door + windows
    a.box((0.9, 0.08, 1.95), (1.8, -1.22, 1.2), "paint_grey")
    for i in range(2):
        a.box((1.2, 0.06, 0.85), (-1.6 + i * 1.8, -1.22, 1.85), "glass_dark")
    a.box((0.06, 0.9, 0.7), (-3.02, 0, 1.8), "glass_dark")
    P.ac_unit(a, (2.2, 0, 3.0), (0.9, 0.7, 0.5))
    a.box((0.9, 0.5, 0.1), (-2.4, -1.05, 0.95), "galv")   # step
    # lifting lugs
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.box((0.12, 0.12, 0.18), (sx * 2.9, sy * 1.1, 2.95), "steel_dark")


def site_sign(a: Asset):
    P.pad(a, (3.2, 0.8), 0.25, (0, 0), "concrete")
    for s in (-1, 1):
        a.cyl(0.07, 3.0, (s * 1.1, 0, 1.75), "galv", seg=8)
    a.box((2.8, 0.1, 1.2), (0, 0, 2.6), "paint_blue", bevel=0.02)
    a.box((2.5, 0.06, 0.35), (0, -0.09, 2.95), "paint_white")
    a.box((2.2, 0.06, 0.2), (0, -0.09, 2.5), "paint_yellow")
    a.box((1.4, 0.06, 0.14), (0, -0.09, 2.28), "paint_white")


def barrel_cluster(a: Asset):
    for i, (x, y) in enumerate([(0, 0), (0.62, 0), (1.24, 0), (0.3, 0.62), (0.92, 0.62), (0.62, 1.24)]):
        P.barrel(a, (x - 0.6, y - 0.6, 0), ("paint_red", "paint_blue", "paint_green")[i % 3])
    a.box((2.0, 2.0, 0.06), (0.3, 0.3, 0.03), "wood")


def gas_cylinder_rack(a: Asset):
    P.skid(a, 2.6, 1.4, 0.15, loc=(0, 0, 0), lugs=False)
    for i in range(3):
        for j in range(2):
            P.gas_cylinder(a, (-0.8 + i * 0.8, -0.3 + j * 0.6, 0.15), ("paint_green", "paint_red")[j])
    for s in (-1, 1):
        a.beam((s * 1.25, -0.65, 0.15), (s * 1.25, -0.65, 1.9), 0.08, "galv")
        a.beam((s * 1.25, 0.65, 0.15), (s * 1.25, 0.65, 1.9), 0.08, "galv")
    a.beam((-1.25, 0, 2.0), (1.25, 0, 2.0), 0.1, "galv")


def road_straight(a: Asset):
    a.box((12.0, 7.0, 0.18), (0, 0, 0.09), "asphalt")
    for i in range(4):
        a.box((1.6, 0.16, 0.02), (-4.5 + i * 3.0, 0, 0.19), "paint_white")
    for s in (-1, 1):
        a.box((12.0, 0.12, 0.02), (0, s * 3.3, 0.19), "paint_white")
    for s in (-1, 1):
        a.box((12.0, 0.9, 0.24), (0, s * 4.1, 0.12), "gravel")


def road_corner(a: Asset):
    a.box((12.0, 7.0, 0.18), (0, -3.5, 0.09), "asphalt")
    a.box((7.0, 12.0, 0.18), (-3.5, 3.5, 0.09), "asphalt")
    for i in range(3):
        a.box((0.16, 1.6, 0.02), (-1.6, -5.0 + i * 3.0, 0.19), "paint_white")
        a.box((1.6, 0.16, 0.02), (-5.0 + i * 3.0, 1.6, 0.19), "paint_white")
    a.box((10.0, 0.9, 0.24), (0, -8.0, 0.12), "gravel")
    a.box((0.9, 10.0, 0.24), (-8.0, 0, 0.12), "gravel")


def build_plot(a: Asset):
    """Gameplay build plot: graded pad with a survey outline."""
    P.pad(a, (24.0, 24.0), 0.25, (0, 0), "gravel")
    pts = [(math.cos(TAU * i / 6 + math.pi / 6) * 11.5,
            math.sin(TAU * i / 6 + math.pi / 6) * 11.5, 0.30) for i in range(7)]
    a.sweep(pts, 0.24, "paint_teal", seg=8, caps=False)
    for i in range(6):
        ang = TAU * i / 6 + math.pi / 6
        px, py = math.cos(ang) * 11.5, math.sin(ang) * 11.5
        a.cyl(0.20, 2.0, (px, py, 1.25), "paint_yellow", seg=8)
        a.sphere(0.28, (px, py, 2.30), "emit_blue", seg=(8, 5))
    # inner corner-to-corner cross
    for i in range(3):
        ang = math.pi / 6 + TAU * i / 3
        a.sweep([(0, 0, 0.30), (math.cos(ang) * 11.0, math.sin(ang) * 11.0, 0.30)],
                0.06, "paint_teal", seg=6, caps=False)
    # corner posts
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.box((0.25, 0.25, 0.5), (sx * 11.0, sy * 11.0, 0.4), "paint_yellow")


def well_marker(a: Asset):
    a.cyl(0.08, 2.4, (0.4, 0.4, 1.2), "galv", seg=8)
    a.box((1.2, 0.08, 0.7), (0, 0.4, 2.0), "paint_orange", rot=(0, 0, 0))
    a.box((1.0, 0.06, 0.18), (0, 0.35, 2.18), "paint_white")
    a.box((0.8, 0.06, 0.14), (0, 0.35, 1.95), "paint_white")
    a.box((0.9, 0.9, 0.12), (0.4, 0.4, 0.06), "concrete_dark")


def drill_bit(a: Asset):
    a.cyl(0.55, 0.7, (0, 0, 0.75), "steel_dark", seg=16)
    a.cyl(0.32, 0.9, (0, 0, 1.5), "steel_light", seg=14)
    a.cyl(0.42, 0.35, (0, 0, 2.1), "steel_dark", seg=14)
    for i in range(3):
        ang = TAU * i / 3
        cx, cy = math.cos(ang) * 0.42, math.sin(ang) * 0.42
        a.cyl(0.30, 0.55, (cx, cy, 0.35), "steel", seg=12, axis=(cx, cy, -1))
        for k in range(4):
            a.box((0.10, 0.10, 0.24), (cx * 1.25, cy * 1.25, 0.12 + k * 0.1), "chrome",
                  rot=(0, 0, ang + k * 0.4))
    for i in range(3):
        ang = TAU * i / 3 + 0.5
        a.beam((0, 0, 1.9), (math.cos(ang) * 0.45, math.sin(ang) * 0.45, 1.5), 0.09, "steel_dark")


def pipe_supply(a: Asset):
    P.pad(a, (9.0, 4.0), 0.2, (0, 0), "gravel")
    for s in (-1, 1):
        for t in (-1, 1):
            a.beam((s * 3.6, t * 1.5, 0.2), (s * 3.6, t * 1.5, 1.2), 0.16, "steel_dark")
    P.pipe_load(a, (0, 0, 0.3), 7.0, 21, 0.14, "rust_patchy")
    a.beam((-3.6, -1.5, 1.0), (3.6, -1.5, 1.0), 0.1, "steel_dark")
    a.beam((-3.6, 1.5, 1.0), (3.6, 1.5, 1.0), 0.1, "steel_dark")


def water_tank(a: Asset):
    a.box((3.6, 3.6, 0.25), (0, 0, 0.12), "concrete")
    a.cyl(1.55, 3.2, (0, 0, 1.85), "hdpe_white", seg=20)
    a.cyl(1.65, 0.18, (0, 0, 3.45), "hdpe_white", seg=20)
    a.cyl(0.3, 0.4, (0, 0, 3.65), "hdpe_yellow", seg=10)
    for i in range(2):
        a.cyl(1.58, 0.08, (0, 0, 0.9 + i * 1.2), "steel_dark", seg=20)
    P.pipe_run(a, [(1.6, 0, 0.5), (2.6, 0, 0.5)], 0.14, "pipe_white")
    P.gate_valve(a, (2.2, 0, 0.5), "X", 0.2)


def workshop(a: Asset):
    P.pad(a, (18, 12), 0.25, (0, 0), "concrete")
    a.box((16.0, 10.0, 6.0), (0, 0, 3.25), "paint_grey", bevel=0.06)
    a.box((16.4, 10.4, 0.3), (0, 0, 6.4), "steel_dark")
    # roller doors
    for i in range(2):
        a.box((4.2, 0.12, 4.0), (-4.0 + i * 8.0, -5.06, 2.2), "paint_white")
        for k in range(6):
            a.box((4.2, 0.1, 0.06), (-4.0 + i * 8.0, -5.12, 0.5 + k * 0.66), "steel_dark")
    # windows + vents
    for i in range(3):
        a.box((1.2, 0.06, 0.7), (0.0, -5.06, 4.6), "glass_dark") if i == 1 else None
    for i in range(3):
        a.box((1.2, 0.06, 0.7), (-6.0 + i * 2.0, 5.06, 4.6), "glass_dark")
    for i in range(3):
        a.cyl(0.35, 1.4, (-5.0 + i * 5.0, 3.5, 7.0), "galv", seg=10)
    P.ac_unit(a, (5.4, 0, 6.6), (1.4, 1.0, 0.9))


def security_gate(a: Asset):
    P.pad(a, (12, 7), 0.2, (0, 0), "asphalt")
    for s in (-1, 1):
        a.box((0.6, 0.6, 2.6), (s * 3.6, 0, 1.5), "concrete")
        a.box((0.8, 0.8, 0.2), (s * 3.6, 0, 2.9), "paint_yellow")
    # boom barrier
    a.cyl(0.18, 1.2, (3.0, -1.5, 0.8), "paint_grey", seg=10)
    a.box((0.16, 7.0, 0.16), (3.0, -1.5 + 3.5, 1.35), "paint_red", rot=(0, 0, 0))
    for i in range(6):
        a.box((0.18, 0.5, 0.18), (3.0, -1.5 + 0.8 + i * 1.1, 1.35), "paint_white")
    # guard hut
    a.box((2.6, 2.2, 2.4), (-4.4, 2.6, 1.4), "paint_white", bevel=0.05)
    a.box((2.2, 0.06, 0.9), (-4.4, 1.46, 1.9), "glass_dark")
    a.box((2.7, 2.3, 0.15), (-4.4, 2.6, 2.65), "paint_grey")
    P.ac_unit(a, (-4.4, 3.2, 2.8), (0.8, 0.6, 0.45))
    a.box((8.0, 0.1, 0.1), (-1.0, 3.6, 2.3), "galv")


def team_flag(a: Asset):
    """Gameplay marker: ownership flag for a claimed field or asset."""
    a.box((2.0, 2.0, 0.18), (0, 0, 0.09), "concrete_dark")
    a.cyl(0.08, 7.0, (0, 0, 3.6), "galv", seg=8)
    a.box((2.6, 0.06, 1.5), (1.3, 0, 6.1), "paint_yellow", bevel=0.02)
    a.box((0.9, 0.07, 0.5), (0.6, 0, 6.2), "paint_white")
    for i in range(3):
        a.box((1.6 - i * 0.4, 0.05, 0.09), (0.9, 0, 5.6 - i * 0.22), "paint_white")
    a.ring((0, 0, 0.22), 1.4, 0.05, "emit_blue", seg=24)
    a.sphere(0.16, (0, 0, 7.15), "emit_amber", seg=(8, 5))


def plot_marker(a: Asset):
    """Empty build-plot footprint used while placing structures."""
    a.box((16.0, 16.0, 0.06), (0, 0, 0.03), "gravel")
    pts = [(math.cos(TAU * i / 4 + math.pi / 4) * 7.8,
            math.sin(TAU * i / 4 + math.pi / 4) * 7.8, 0.08) for i in range(5)]
    a.sweep(pts, 0.07, "emit_blue", seg=6, caps=False)
    for i in range(4):
        ang = TAU * i / 4 + math.pi / 4
        px, py = math.cos(ang) * 7.8, math.sin(ang) * 7.8
        a.cyl(0.09, 1.0, (px, py, 0.55), "galv", seg=8)
        a.sphere(0.12, (px, py, 1.1), "emit_blue", seg=(6, 4))
    # centre cross
    a.box((2.2, 0.12, 0.02), (0, 0, 0.08), "paint_white")
    a.box((0.12, 2.2, 0.02), (0, 0, 0.08), "paint_white")


def office_container_stack(a: Asset):
    for i in range(2):
        P.container(a, (0, -3.1 + i * 6.2, 0), (2.4, 6.0, 2.6), "paint_blue")
    P.container(a, (0, 0, 2.65), (2.4, 6.0, 2.6), "paint_white")
    # stair + landing
    P.stairs(a, (2.0, 2.0, 0), 1.2, 2.65, 3.0, (1, 0, 0), 8, "galv")
    a.box((2.0, 2.0, 0.08), (2.6, 4.0, 2.65), "galv")
    P.handrail(a, [(1.7, 3.0, 2.73), (3.6, 3.0, 2.73)], 1.0, "galv")
    for i in range(3):
        a.box((0.06, 1.0, 0.7), (1.22, -3.0 + i * 2.2, 1.7), "glass_dark")


# --------------------------------------------------------------------------- #
# registry
# --------------------------------------------------------------------------- #

REGISTRY = [
    dict(aid="prp_fence_module", name="Fence Module (4 m)", build=fence_module,
         gameplay=dict(role="prop", tier=1, cost_usd=1_200, snap="fence")),
    dict(aid="prp_floodlight", name="Floodlight Tower", build=floodlight_tower,
         gameplay=dict(role="prop", tier=1, cost_usd=18_000, power_kw=4, light_radius_m=90)),
    dict(aid="prp_portacabin", name="Site Office Cabin", build=portacabin,
         gameplay=dict(role="prop", tier=1, cost_usd=26_000, crew=8, footprint_m2=16)),
    dict(aid="prp_sign", name="Site Sign", build=site_sign,
         gameplay=dict(role="prop", tier=1, cost_usd=2_500)),
    dict(aid="prp_barrels", name="Barrel Cluster", build=barrel_cluster,
         gameplay=dict(role="prop", tier=1, cost_usd=900, capacity_bbl=6)),
    dict(aid="prp_gas_cylinders", name="Gas Cylinder Rack", build=gas_cylinder_rack,
         gameplay=dict(role="prop", tier=1, cost_usd=3_200)),
    dict(aid="prp_road_straight", name="Road Tile (12 m)", build=road_straight,
         gameplay=dict(role="infrastructure", tier=1, cost_usd=9_000, snap="road",
                       length_m=12, speed_kmh=80)),
    dict(aid="prp_road_corner", name="Road Corner", build=road_corner,
         gameplay=dict(role="infrastructure", tier=1, cost_usd=11_000, snap="road")),
    dict(aid="prp_build_plot", name="Build Plot (24 m)", build=build_plot,
         gameplay=dict(role="gameplay", tier=1, cost_usd=45_000, snap="plot",
                       footprint_m2=576)),
    dict(aid="prp_well_marker", name="Well Marker", build=well_marker,
         gameplay=dict(role="gameplay", tier=1, cost_usd=400)),
    dict(aid="prp_drill_bit", name="Tricone Drill Bit", build=drill_bit,
         gameplay=dict(role="prop", tier=1, cost_usd=12_000, wear_part=True)),
    dict(aid="prp_pipe_supply", name="Pipe Supply Stack", build=pipe_supply,
         gameplay=dict(role="prop", tier=1, cost_usd=28_000, pipe_joints=24)),
    dict(aid="prp_water_tank", name="Water Storage Tank", build=water_tank,
         gameplay=dict(role="prop", tier=1, cost_usd=15_000, capacity_bbl=200)),
    dict(aid="prp_workshop", name="Field Workshop", build=workshop,
         gameplay=dict(role="support", tier=2, cost_usd=1_800_000, build_days=90,
                       crew=30, footprint_m2=180, repair_rate=0.25)),
    dict(aid="prp_security_gate", name="Site Security Gate", build=security_gate,
         gameplay=dict(role="prop", tier=1, cost_usd=65_000, security=0.1)),
    dict(aid="prp_team_flag", name="Team Ownership Flag", build=team_flag,
         gameplay=dict(role="gameplay", tier=1, cost_usd=5_000, claim_marker=True)),
    dict(aid="prp_plot_marker", name="Build Plot Marker", build=plot_marker,
         gameplay=dict(role="gameplay", tier=1, cost_usd=0, placement_preview=True)),
    dict(aid="prp_office_stack", name="Stacked Site Offices", build=office_container_stack,
         gameplay=dict(role="support", tier=1, cost_usd=96_000, crew=24, footprint_m2=40)),
]
