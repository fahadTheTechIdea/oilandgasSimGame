"""Cartoon / low-poly material library.

Same hue family as before (so asset colour-coding and team tinting still work),
but every surface is fully matte: no metallic response, high roughness, low
specular. That is what makes the faceted geometry read as cartoon rather than
as painted metal.
"""

from __future__ import annotations

import bpy

# name -> (hex colour, metallic, roughness, emission_strength)
SPECS = {
    # structural steel
    "steel":          ("8A9096", 0.00, 0.88, 0.0),
    "steel_dark":     ("4B5157", 0.00, 0.92, 0.0),
    "steel_light":    ("C3C8CC", 0.00, 0.84, 0.0),
    "galv":           ("9DA6AC", 0.00, 0.86, 0.0),
    "chrome":         ("DDE2E5", 0.00, 0.55, 0.0),
    "rust":           ("8C4C2B", 0.00, 0.96, 0.0),
    "rust_patchy":    ("6E452E", 0.00, 0.96, 0.0),

    # paints (team-tint candidates)
    "paint_yellow":   ("E3B21E", 0.00, 0.82, 0.0),
    "paint_orange":   ("D9631B", 0.00, 0.82, 0.0),
    "paint_red":      ("B62A22", 0.00, 0.82, 0.0),
    "paint_blue":     ("1F5C8B", 0.00, 0.82, 0.0),
    "paint_teal":     ("1D7A78", 0.00, 0.82, 0.0),
    "paint_green":    ("2C6B4C", 0.00, 0.82, 0.0),
    "paint_white":    ("E4E6E4", 0.00, 0.80, 0.0),
    "paint_grey":     ("767C80", 0.00, 0.86, 0.0),
    "paint_black":    ("2A2C2E", 0.00, 0.90, 0.0),

    # civil
    "concrete":       ("B4B1A8", 0.00, 0.94, 0.0),
    "concrete_dark":  ("85837C", 0.00, 0.95, 0.0),
    "asphalt":        ("35383A", 0.00, 0.96, 0.0),
    "gravel":         ("8E8778", 0.00, 0.96, 0.0),
    "sand":           ("C6B393", 0.00, 0.95, 0.0),
    "soil":           ("6B5742", 0.00, 0.97, 0.0),
    "grass":          ("55603E", 0.00, 0.95, 0.0),

    # pipework
    "pipe_white":     ("DCDEDB", 0.00, 0.86, 0.0),
    "pipe_blue":      ("2F6E96", 0.00, 0.86, 0.0),
    "pipe_green":     ("2E7350", 0.00, 0.86, 0.0),
    "pipe_yellow":    ("CFA61E", 0.00, 0.86, 0.0),
    "copper":         ("A96A3C", 0.00, 0.80, 0.0),
    "brass":          ("BC9A4A", 0.00, 0.78, 0.0),
    "stainless":      ("B9BEC2", 0.00, 0.62, 0.0),
    "insulation":     ("C9C7BF", 0.00, 0.94, 0.0),

    # non-metal
    "rubber":         ("1C1E1F", 0.00, 0.95, 0.0),
    "plastic_black":  ("232527", 0.00, 0.88, 0.0),
    "plastic_orange": ("D9711F", 0.00, 0.84, 0.0),
    "glass_dark":     ("26333C", 0.00, 0.45, 0.0),
    "glass_light":    ("7E9AA8", 0.00, 0.40, 0.0),
    "hdpe_white":     ("E2E4E1", 0.00, 0.88, 0.0),
    "hdpe_yellow":    ("D7AC1F", 0.00, 0.86, 0.0),
    "wood":           ("8B6B47", 0.00, 0.94, 0.0),
    "fabric":         ("4A5560", 0.00, 0.96, 0.0),
    "safety_net":     ("C7CBCE", 0.00, 0.92, 0.0),
    "composite":      ("5B6367", 0.00, 0.90, 0.0),

    # fluids / emissive accents (dimmed so they read as dots, not lamps)
    "oil":            ("14100D", 0.00, 0.45, 0.0),
    "water":          ("1B4A5F", 0.00, 0.30, 0.0),
    "emit_red":       ("FF2A12", 0.00, 0.80, 2.4),
    "emit_green":     ("22FF6A", 0.00, 0.80, 2.0),
    "emit_amber":     ("FFB020", 0.00, 0.80, 2.4),
    "emit_white":     ("FFFFFF", 0.00, 0.80, 1.8),
    "emit_blue":      ("3FA9FF", 0.00, 0.80, 1.8),
}


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h: str, alpha: float = 1.0):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (_srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b), alpha)


def _set(bsdf, name, value) -> None:
    if name in bsdf.inputs:
        bsdf.inputs[name].default_value = value


def build(name: str, spec) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    hexc, metallic, rough, emit = spec
    rgba = hex_rgba(hexc)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    _set(bsdf, "Base Color", rgba)
    _set(bsdf, "Metallic", metallic)
    _set(bsdf, "Roughness", rough)
    _set(bsdf, "Specular IOR Level", 0.12)
    _set(bsdf, "Sheen Weight", 0.0)
    _set(bsdf, "Coat Weight", 0.0)
    if emit > 0:
        _set(bsdf, "Emission Color", rgba)
        _set(bsdf, "Emission Strength", emit)
    mat.diffuse_color = rgba
    mat.metallic = metallic
    mat.roughness = rough
    mat["style"] = "cartoon"
    if name.startswith("emit_"):
        mat["is_emissive"] = True
    if name.startswith("paint_"):
        mat["team_tint"] = True
    mat.use_backface_culling = False
    return mat


def init_materials() -> dict:
    from . import core
    mats = {n: build(n, s) for n, s in SPECS.items()}
    core.bind_materials(mats)
    return mats
