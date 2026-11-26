# Time, calendar and weather

## Research notes

- **Day/night** (GameDev Academy, Godot 4 tutorials): rotate a
  `DirectionalLight3D` by time-of-day, fade its energy near dawn/dusk, and
  drive the `WorldEnvironment` ambient/sky with the same factor. A sun that
  rises east, peaks at solar noon and sets west reads best.
- **Seasons & weather** (tycoon/sim design write-ups): each season has its own
  weighted weather table (winter snow, summer heat, spring/autumn rain), states
  last several game hours, and the state carries explicit gameplay modifiers.
  Probability tables are easier to tune and test than continuous simulation.
- **Tycoon weather systems** (reddit/r/tycoon design thread): combine seasonal
  averages with a seeded RNG so results are reproducible and saveable.

## One connected model

`game/scripts/domain/weather_system.gd` keeps a single set of physical drivers:

`temperature_c · pressure_hpa · humidity · cloud · precipitation · fog`

Everything else is **derived**, so the system stays coherent:

| Derived from | Rule |
| --- | --- |
| Rain vs snow | `precipitation` with `temperature <= 2.5 °C` → snow, otherwise rain |
| Wind target | `2 + pressure deficit × 0.32 + precipitation × 2.2` m/s |
| Sunlight | `1 − 0.65·cloud − 0.25·fog − 0.15·rain − 0.10·snow` |
| Production | reduced by rain/snow/fog, temperature extremes and pressure deficit |
| Logistics | reduced more strongly by snow/fog/rain and pressure deficit |
| Cloud shadows / overlay | cloud, rain, snow, wind |
| Day/night light | calendar daylight × solar factor |

The regime state machine (clear/cloudy/rain/storm/fog/heatwave/snow) only picks
seasonal **targets**; the drivers ease toward them, so a storm builds pressure
and cloud before the rain, and a winter “rain” regime falls as snow.

## Calendar model

`game/scripts/domain/game_calendar.gd`

- Time is one float: **elapsed game days**. At **1× the clock is real time**:
  `day_seconds = 86,400`, so one real second is one game second and a game day
  is a real day.
- 12 months × 28 days = 336-day years. Months: Jan…Dec; seasons:
  **Winter** (Dec–Feb), **Spring** (Mar–May), **Summer** (Jun–Aug),
  **Autumn** (Sep–Nov).
- The speed buttons (`1×/2×/4×/8×`) accelerate the clock; weather transitions
  are every **0.5–1.5 game hours**, i.e. every 3–11 real minutes at 8×.
- Helpers: year/month/day, `hour_float()`, `daylight()` (0 at night, 1 at solar
  noon), `sun_rotation_deg()`, labels for the HUD, and `save_data()/load_data()`.
- The game-speed multiplier (`1×/2×/4×/8×`) also scales calendar time, so 8×
  runs a game day in ~22 s.

## Day/night

`main.gd::_apply_daylight()`

- Sun rotation follows `calendar.sun_rotation_deg()`.
- Sun energy lerps between night moonlight (0.06) and full day (1.05), scaled by
  the weather's solar factor and cloud cover.
- Light colour warms toward dawn/dusk; ambient energy/colour and the
  `ProceduralSkyMaterial` top/horizon colours follow daylight and cloud cover.

## Weather state machine

`game/scripts/domain/weather_system.gd`

| State | Prod | Logi | Solar | Visual |
| --- | ---: | ---: | ---: | --- |
| Clear | 1.00 | 1.00 | 1.00 | — |
| Cloudy | 0.99 | 0.98 | 0.70 | high cloud |
| Rain | 0.92 | 0.88 | 0.50 | rain |
| Storm | 0.78 | 0.65 | 0.30 | heavy rain, dark |
| Fog | 0.95 | 0.75 | 0.45 | grey sky |
| Heatwave | 0.86 | 1.00 | 1.20 | warm light |
| Snow | 0.80 | 0.60 | 0.40 | snow |

Seasonal weights decide the next state each 0.5–1.5 game hours:

| Season | Weights |
| --- | --- |
| Winter | Clear 28, Cloudy 20, Snow 34, Fog 12, Storm 6 |
| Spring | Clear 30, Cloudy 24, Rain 30, Storm 8, Fog 8 |
| Summer | Clear 44, Cloudy 15, Rain 10, Storm 6, Heatwave 25 |
| Autumn | Clear 30, Cloudy 20, Rain 25, Storm 12, Fog 13 |

A seeded `RandomNumberGenerator` makes forecasts deterministic; its state is
saved with the run.

## Wind

`game/scripts/domain/wind_system.gd`

- Direction wanders slowly; speed eases toward a per-weather target
  (Clear 3, Cloudy 5, Rain 8, Storm 16, Fog 1.5, Heatwave 2, Snow 7 m/s).
- Drives the cloud scroll, the rain/snow slant and the HUD bearing
  (`SW 18 km/h`). Deterministic and saved with the run.

## Clouds, shadows and surface weather

Researched approach: **sky-shader clouds + world-anchored cloud shadows +
texture-driven screen precipitation**.

- `cloudy_sky.gdshader` (a `shader_type sky`, `void sky()`) projects the
  generated cloud map onto the dome, animated by wind, and fades it cleanly at
  the horizon. The 3D orbit camera can pitch to the horizon (`C`, drag up) so
  the clouds are visible; the classic top-down camera does not show sky.
- `cloud_deck.gdshader` draws a **very soft overhead puff layer only in the 3D
  view** (opacity ≈ 0.10 × cover). In classic it is hidden so it cannot tint or
  blanket the map.
- `cloud_shadow.gdshader` is a world-anchored, low-opacity dark noise layer
  (≈ 0.06 × cover) that slides over terrain and roofs with the wind — the
  classic top-down representation of clouds.
- **Rain and snow use the installed [Weather FX Free](https://github.com/Spyridon-Pikoulas/godot-weather-fx-free) addon** (`game/addons/weather_fx`, CC BY 4.0). It is a proven Godot 4.3–4.7 shader kit tested on Compatibility: three depth layers of angled rain streaks, four parallax layers of round snow flakes, wind slant, fall speed, density and optional ground splashes. The game drives its uniforms from the weather drivers.
- **Credit:** `Weather FX Free by heyheythere — https://heyheythere.itch.io/weather-fx-free — CC BY 4.0`.
- Rain splashes and 3D precipitation add depth; snow also applies a cold tint.
- Vegetation sways with wind strength; the HUD reports the bearing and speed.

## Gameplay + presentation

- Well production and refinery throughput multiply by
  `production_factor() * logistics_factor()`.
- Rain/snow `CPUParticles3D` emitters follow the camera target; storm intensity
  increases the particle count.
- The HUD **Date** chip shows `Y1 Mar 14 · 08:30 · Rain −12%`, coloured by
  severity.
- Weather changes and each new day announce themselves with a toast.
- Calendar and weather are persisted in `user://oilfield_save.json`.

## Tests

The suite covers: one day per `day_seconds`, month→season mapping, multiple
weather states over time, storm/clear production + logistics modifiers, wind
tracking its weather target, a wind save/load round trip, and cloud cover
exposed for the deck/shadow layers.
