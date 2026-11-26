# Reverse Engineering — "Oil Tycoon Simulator" (Benelux Edition)

The retro/boxed game in the reference video is **Oil Tycoon Simulator: Benelux
Edition**. The prototype in `game/` is built from the observable rules, not from
its code or assets.

## Method

1. Transcript of the reference playthrough (auto-captions, timestamps below).
2. The box/back-cover description quoted in the video intro.
3. Genre cross-check (city-builder / management conventions) for the parts the
   video never shows.
4. Each derived rule is implemented and then verified in-engine (see §4).

Sources: the video `youtube.com/watch?v=fKb8UAdfSn8` and its caption track.

---

## 1. Evidence → mechanic

| # | Evidence (timestamped quote) | Derived mechanic |
|---|---|---|
| E1 | *[0:16]* "run an international oil company and search for oil in places all over the world" | Campaign across regions; exploration is the entry verb |
| E2 | *[10:51]* "drill for oil … do I put the pump on … there's like oil there" | A well is drilled first, then a **pumpjack** is placed on it |
| E3 | *[11:07]* "now I have to put a storage tank … it wants me to put it a bit far from the pump jack" | Storage has a **minimum distance** from the well |
| E4 | *[11:07]* "so now I build the pipeline button" | Pipelines are a **placement tool**, drawn between buildings |
| E5 | *[11:16]* "remember you can never attach an oil well directly to a building using pipeline" | **Flow rule:** well → storage → refinery; direct well→building links are invalid |
| E6 | *[11:23]* "we need the exploration building we put that down in the city" | Exploration office is placed in settled land and **reveals** oil |
| E7 | *[12:01]* "we build the small storage tank … and then the pipeline to the storage tank … it's working" | Storage is the **only** sink for well output |
| E8 | *[12:07]* "now we want to refine it … a small Refinery … I don't have enough money for a Refinery" | Refinery capex ≫ starting cash |
| E9 | *[12:23]* "can I take out more loans? no the loan button doesn't work" | Loans exist but are **gated/limited** |
| E10 | *[14:54]* "I just needed to sign an order to sell the items" | Sales go through an **order/contract**, not instant cash |
| E11 | *[19:50]* "I don't have enough money to build the pipeline it's too far" | Pipeline cost scales with **length** |
| E12 | *[19:57]* "why am I not given enough money to start the first mission" | Missions have **budgets** |
| E13 | *[20:06]* "maybe I should put it on easy … I start with way more money" | **Difficulty** changes starting capital |
| E14 | *[20:14]* "no oil well found" | Drilling can **fail** (dry hole) |

---

## 2. Derived rule set

```
R1  Choose difficulty at start            -> starting cash (500k / 300k / 150k)
R2  Place Exploration Office              -> reveals deposits in a radius
R3  Drill on a revealed deposit           -> pumpjack only on oil-bearing cell
R4  Storage tank must be >= 2 cells away  -> from any well
R5  Draw pipelines cell by cell           -> $400/cell, long runs get expensive
R6  No direct well <-> building link      -> a storage must exist in the network
R7  Refinery needs the same network       -> pulls crude, sells product
R8  Roads give access                     -> wells/refineries need a road adjacent
R9  Loans and upkeep                      -> +$100k for $112k owed, $/s upkeep
R10 Reach $1,000,000 company value        -> victory
R11 Terrain is part of placement          -> pads are levelled (paid earthworks),
                                             runs refuse grades > 2.4 m/cell
R12 Pump stations boost a run             -> +8 bbl/s for $45k, run capacity is finite
```

R4, R8 and R10 are our explicit interpretations of E3 and of the genre; the
video only shows the tutorial insisting the tank be "a bit far". R11 comes from
the brief ("pipeline and street placement and management is critical") rather
than from the video.

---

## 3. What the prototype implements

| Rule | Where | Status |
|---|---|---|
| R1 difficulty | `hud.show_start_overlay()` → `_on_difficulty()` | done |
| R2 exploration | `_reveal_around()` / `_reveal()` | done |
| R3 pumpjack on deposit | `_can_place()` `kind == "well"` | done |
| R4 tank distance | `_can_place()` storage branch | done |
| R5 pipelines | `_lay_line()` + `_place_infra()` + `_spawn_tile()` | done |
| R6 no direct link | `_rebuild_components()` requires a pipe component containing a storage | done |
| R7 refining | `_simulate()` | done |
| R8 road access | `_has_road()` + `b["road"]` gate in `_simulate()` | done |
| R9 loans/upkeep | `_on_loan()` + upkeep in `_simulate()` | done |
| R10 victory | `_update_hud()` `cash - debt >= 1e6` | done |
| R11 terrain-aware build | `_cell_max_height()` / `_footprint_relief()` / `_level_cells()` / `_sync_terrain()`; `MAX_GRADE` in `_place_infra()` | done |
| E10 sales contracts | `_offer_contract()` + `_simulate()` | implemented: periodic contracts pay a premium; spot sale continues |

### Transport management surfaces

| Surface | What it shows |
|---|---|
| Network strip (bottom-left) | pipe cells, road cells, live upkeep $/s, count of buildings missing access |
| Pipeline inspector (click a pipe) | run length, run upkeep, wells/tanks/refineries on that run, "no storage — nothing flows" |
| Road inspector | network length, upkeep, and that roads gate production |
| Building inspector | `no road access` / `not connected` / `linked` |

---

## 4. Verification

- `godot --headless --path game --import` → no script parse errors.
- `godot --path game -- --selftest` → **15/15** rule checks pass (direct well→refinery
  yields nothing, a tank bridges the runs, road removal stops production, pipe and
  road cost scale per cell, pads level to 0 relief, a pump station raises capacity,
  exploration reveals deposits, routes stay edge-connected).
- `godot --path game -- --demo --shot` builds well → tank → refinery, lays pipe and
  road, waits 7 s, and writes `game/shot.png`.
- `godot --path game -- --demo --overview --shot` writes the terrain rim shot.
- The demo screenshot shows `INCOME +$239/s`, a connected tank, and the refinery
  consuming crude — i.e. the R6/R7 chain is live.
- Terrain3D is the visible ground: 4×4 regions, 64-vertex regions at 4 m spacing,
  textured grass/rock, heights 0–40 m.

---

## 5. Deliberate divergences

| Reference | Prototype | Why |
|---|---|---|
| International map of countries | single lease, 44×44 cells | scope: one playable loop first |
| Sales orders/contracts | periodic contracts + spot sale | contract premium; one active offer on the board |
| Tutorial missions | objective line + difficulty | same teaching effect, less content |
| Loan button sometimes disabled | always available | the reference's gating looked like a bug |
