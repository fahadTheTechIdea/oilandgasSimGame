# Specification: SOLID foundation for the oil tycoon prototype

**Author:** engineering
**Date:** 2026-11-23
**Status:** in-progress

## 1. What problem does this solve?

`game/scripts/main.gd` is a single ~2,200-line class that owns geometry,
the building catalogue, placement validation, pipe/road connectivity, terrain
editing, the economy, input, HUD wiring and self-tests. Any change to one
concern risks another, and the file cannot be unit-tested in isolation.

## 2. What does success look like?

- Every structure (cost, footprint, model, upkeep, pipeline ports, capacity)
  is declared once in a catalogue class; adding a structure touches one file.
- Grid math, network solving and economy are pure classes with no scene-tree
  dependency, callable from tests.
- `main.gd` is a composition root/controller only: it wires input, views and
  domain services; it contains no rule logic.
- The existing rule suite still passes at 100%.
- No behaviour regressions in `--demo`, `--top`, `--route`, `--bend`,
  `--overview` screenshots.

## 3. Constraints

- **Engine:** Godot 4.7.1, GDScript only, Compatibility renderer.
- **Compatibility:** the game must keep running after every phase.
- **Non-goals:** changing art, balance or the reference-derived rules.
- **Quality bar:** rule suite green after each phase; SOLID checklist per phase.
- **No patching/wrapping:** extract real classes; no shim methods that just
  forward to the old monolith.
