# Game Design — Competitive Oil Field Development

A design brief for the game this asset kit was built for: **1–6 players compete to
develop the same hydrocarbon basin**, and win on value created, not on clicks per
minute.

The kit is deliberately *role-complete*: every decision in the loop below has a
physical object that represents it on the map.

---

## 1. The pitch

> A basin has been opened for licensing. Six companies start with the same cash,
> the same seismic data, and no infrastructure. Over ten in-game years you bid for
> blocks, drill, build gathering systems, fight for pipeline capacity, sign offtake
> contracts and race rivals to first oil.
>
> At the end, the auditor values your company. Highest enterprise value wins.

Think *Offshore Engineers* meets *Railroad Tycoon*, with the asset vocabulary of a
real field development plan.

---

## 2. Why this genre works (and what to steal)

| Reference | What to take | What to avoid |
|---|---|---|
| **Turmoil** (multiplayer update) | Short, punchy competitive rounds; visible rival progress | Cartoon economy with no infrastructure |
| **Drill Deal** | Rig management, staff morale, upgrade paths | Single-player idle pacing |
| **Oil Enterprise / Oil Tycoon Simulator** | Field acquisition, loans, long-term contracts | Click-to-drill simplicity, no spatial planning |
| **MOL Freshhh upstream game** (real industry competition) | 15-round, $3 bn budget, 10 prospects, NPV ranking | Spreadsheet-only presentation |
| **SimRefinery** (Chevron/Maxis) | Simplified but honest process units | Full chemical fidelity |
| **Railroad Tycoon / Transport Tycoon** | Spatial network building is the fun | Pure sandbox with no pressure |

**Design thesis:** the fun is in *spatial capital allocation under competition* —
where you put the pad, which route the pipeline takes, whether you share a
processing plant with a rival or build your own.

---

## 3. Core loop

```
  BID ──► EXPLORE ──► APPRAISE ──► DEVELOP ──► PRODUCE ──► MOVE ──► SELL ──┐
   ▲                                                                        │
   └────────────────────── REINVEST / DIVEST ◄──────────────────────────────┘
```

1. **Bid** — sealed-bid auction for exploration blocks each quarter. Information
   is asymmetric: everyone sees basin-scale seismic, only the winner sees detail.
2. **Explore** — shoot 2D/3D seismic (cost/time), then drill an exploration well.
   Outcomes are sampled from a hidden geological model — dry hole, oil, gas,
   condensate.
3. **Appraise** — delineation wells reduce uncertainty on OOIP and productivity.
   Each well is a real cost and a real delay.
4. **Develop** — the core of the game. Choose:
   - onshore pad + beam pumps vs. a single high-rate well with artificial lift
   - central processing vs. satellite wells tied back to a shared plant
   - fixed platform vs. FPSO vs. subsea tie-back for offshore
   - where the pipeline runs, and how much capacity to build
5. **Produce** — decline curves, water cut, gas-oil ratio, pressure support
   (water/gas injection). Facilities capacity caps your rate.
6. **Move** — gathering lines → trunkline → pump stations → terminal → refinery
   or export jetty. Every segment has capacity; bottlenecks are visible on the map.
7. **Sell** — spot price, or fixed offtake contracts that pay less but derisk.
8. **Reinvest / divest** — buy rivals' stranded assets, sell mature fields,
   farm-out, or share infrastructure for a tariff.

---

## 4. Match structure

| Mode | Length | Win condition |
|---|---|---|
| **Field Development Challenge** (default) | 10 in-game years, ~90–120 min | Highest NPV at audit |
| **Rush** | 3 years | First to 100,000 bbl cumulative |
| **Basin Domination** | 20 years | Control > 50% of basin production for 4 consecutive quarters |
| **Co-op vs. basin** | 10 years | Team NPV vs. a scripted AI operator |

Turn model: **1 tick = 1 week**, 52 ticks per year, with real-time-with-pause
default. Async multiplayer runs the same deterministic sim on a server; clients
replay the tick log. Never trust client-side RNG.

**Seeding.** Every match uses a seed that generates the geology, the oil price
path, and the event deck. Two players on the same seed have identical inputs —
which is what makes head-to-head comparison fair and makes leaderboards meaningful.

---

## 5. The simulation model (minimum viable fidelity)

### 5.1 Reservoir
Per block, hidden until explored:

```
OOIP (MMbbl), API gravity, GOR (scf/bbl), depth (m), permeability (mD),
porosity, net pay (m), pressure (psi), water saturation, fault risk
```

Production per well follows a hyperbolic decline:

```
q(t) = q_i / (1 + b·D·t)^(1/b)          b ≈ 0.8–1.2, D from permeability & lift
```

Recovery factor improves with:
- pressure maintenance (water/gas injection)
- artificial lift (pumpjack → ESP → gas lift)
- infill drilling (diminishing returns)
- EOR (CO₂ / polymer) — expensive, late-game

### 5.2 Facilities
Each asset exposes capacities in `manifest.json`. Production is the **minimum of
the chain**:

```
well potential → manifold capacity → separator capacity → pipeline capacity
              → terminal storage → offtake contract → market
```

That min() is where the game lives. A player with great wells and a 20,000 bbl/d
line will watch 40,000 bbl/d of potential evaporate — and must decide whether to
build a second line or sell the field.

### 5.3 Economy
- **Capex** — one-off, from `gameplay.cost_usd`, paid over `build_days`.
- **Opex** — daily, scaled by utilisation and age (maintenance drift).
- **Decommissioning** — 8–12% of capex, payable at end of life. Ignoring it is a
  classic way to lose the audit.
- **Oil price** — mean-reverting with occasional shocks; gas priced separately
  and often stranded without a pipeline.
- **Financing** — debt with covenants (debt/EBITDA ≤ 2.5), equity dilution, farm-outs.
- **Taxes/royalty** — flat royalty 12.5%, profit tax 25%, accelerated depreciation.
  Keep it simple but present: it changes optimal timing.

### 5.4 Competition mechanics
- Sealed-bid lease auctions (second-price) each quarter.
- **Shared infrastructure**: any player may ship through another's pipeline for a
  tariff set by the owner. Refusing capacity is legal but hurts reputation.
- **Offtake contracts**: fixed-volume, fixed-price, penalty for shortfall.
  Signing early funds development; missing delivery destroys your credit rating.
- **Espionage (optional)**: buy seismic reprocessing or satellite production
  estimates on rivals — imperfect information, no sabotage of physical assets.
- **Events**: strike, hurricane, spill, OPEC cut, technology breakthrough.
  Deterministic per seed so competitive matches stay fair.

---

## 6. How the asset kit maps to decisions

| Player decision | Asset in kit |
|---|---|
| Drill the well | `on_land_rig`, `off_jackup_rig`, `off_semi_submersible`, `off_drillship` |
| Complete the well | `on_wellhead`, `off_subsea_tree`, `veh_cementing_truck`, `veh_wireline_truck` |
| Lift the oil | `on_pumpjack` |
| Separate / treat | `on_separator`, `on_heater_treater` |
| Store | `on_tank_farm`, `mid_tank_terminal`, `mid_lng_sphere` |
| Gather | `on_gathering_manifold`, `on_pipeline_segment`, `on_pipeline_valve` |
| Move long distance | `mid_pump_station`, `mid_pig_launcher`, `off_riser_joint` |
| Process gas | `on_compressor_station`, `mid_gas_plant`, `mid_slug_catcher` |
| Export LNG | `mid_lng_train`, `mid_loading_jetty` |
| Offshore production | `off_fixed_platform`, `off_fpso`, `off_spar` |
| Subsea development | `off_subsea_manifold`, `off_riser_joint` |
| Refine | `ref_cdu`, `ref_vdu`, `ref_fcc`, `ref_reformer`, `ref_hydrotreater`, `ref_coker`, `ref_amine`, `ref_sru` |
| Utilities / safety | `ref_cooling_tower`, `flares`, `prp_fire_truck` ▶ `veh_fire_truck` |
| Logistics | all `veh_*` units |
| Claim a field | `prp_team_flag`, `prp_build_plot` |

`docs/ASSET_LIBRARY.md` lists every asset with its gameplay payload.

---

## 7. Progression

`gameplay.tier` on every asset gives a natural tech ladder:

| Tier | Theme | Unlocks |
|---|---|---|
| 1 | Bootstrap | land rig, pumpjack, tank battery, roads, pickups |
| 2 | Industrialise | workover rig, jack-up, fixed platform, gas plant, CDU |
| 3 | Scale | semisub, FPSO, spar, LNG, FCC, coker |
| 4 | Frontier | drillship, ultra-deepwater, mega LNG train |

Unlock by cumulative production or by research spend — but **never** gate the
physics. A tier-1 rig must still be able to drill a bad well; it just can't reach
deep water.

---

## 8. Multiplayer architecture notes

- **Server-authoritative deterministic tick.** Fixed-point economics, integer
  barrels, seeded RNG streams per subsystem (geology / prices / events) so replays
  are exact.
- **Command queue, not state sync.** Clients send intents (`build`, `bid`,
  `sign_contract`); server applies them at tick boundaries. This tolerates latency
  and disconnects.
- **Fog of war on geology and finance.** Reveal only what the player has paid to
  know. Rival production is estimated from satellite/flare data, not exact.
- **Anti-cheat by design.** No hidden client state worth tampering with; the sim
  is the server.
- **Async turns.** A 10-year match can run over days with 1 tick per hour and
  email/push notifications ("Bid window closes in 6 h").

---

## 9. UI surfaces the kit implies

1. **Basin map** — the demo scene is the visual reference: onshore field, trunk
   pipeline, refinery cluster, coast, offshore cluster.
2. **Asset card** — one per manifest entry: cost, build time, capacity, opex,
   emissions, footprint, tier.
3. **Build ghost** — `prp_plot_marker` and `prp_build_plot` are the placement
   previews; snap tags in the manifest (`snap: pipe | road | rack | plot | fence`)
   drive the ghost rules.
4. **Network inspector** — click a pipeline segment to see flow vs. capacity and
   the bottleneck upstream/downstream.
5. **Company dashboard** — cash, debt, production, decline forecast, contract book.

---

## 10. Balancing starting point

Using the manifest numbers directly:

- Start cash: **$250 M** (challenge mode), debt facility $400 M at 7.5%.
- Land rig day-rate equivalent: ~$24k/day opex; a 4,500 m well ≈ 38 days ≈ $6.5 M
  all-in with casing and completion.
- A tier-1 onshore development (2 wells + pumpjacks + separator + tank + 1 km line)
  ≈ **$3.5 M** and returns ~250 bopd → pays back in ~18 months at $70/bbl.
- Offshore fixed platform ≈ **$340 M**; needs ≥ 15,000 bopd to be viable.
- A refinery unit only makes sense once basin production exceeds its throughput,
  which forces late-game vertical integration or cooperative processing.

Tune by changing `gameplay` values in the registries and re-running the build —
the manifest is the single source of truth for both 3D and game data.

---

## 11. What to build next

1. **Terrain + coastline generator** on the same tile grid as `prp_road_straight`.
2. **Flow visualisation** — animated pipeline flow, flare particles, pumpjack
   animation (all assets are static meshes today; pivots are already separated by
   naming where it matters, e.g. `on_pumpjack` beam).
3. **Damage/wear variants** — a `_worn` material set swapped by maintenance state.
4. **AI operator** — a scripted NPV maximiser using the same action API as players.
5. **Match server** — deterministic tick + command log, then replay viewer.
