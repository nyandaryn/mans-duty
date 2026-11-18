# Equipment and ballistics — 0.10.0

## Using the loadout

Click a weapon card to open the weapon grid. Hover or focus a card to see its
caliber, empty mass, magazine capacity, muzzle velocity and operating modes.
Choose the assault backpack to enable a 6 × 4 grid. Item footprints occupy
actual cells: paper ammunition packets use 2 × 1; a medkit or rangefinder 2 × 2.
Click the catalog to add, drag to move, right-click to remove. Pack contents
must be removed before unequipping it. Empty pack mass is 1.35 kg; payload
limit is 18 kg. The cell layout is a gameplay abstraction, not a volume solver.

All carryable ammunition is packed in folded kraft-paper packets of 30 rounds,
including the requested 5.45 × 39 format. Other calibers use the same 30-round
inventory convention. Packet paper weighs 8 g. No metal ammunition cans are
carried. Per-round and equipment masses are representative game values.

Enter a name and Save/Update to store a preset. The dropdown loads a complete
weapon / uniform / backpack / contents layout. Saving an existing name updates
it. Files are local `user://loadouts.cfg` and `user://settings.cfg`. Up to 24
named presets, 32 characters per name. A mission receives its own copy;
consumption never edits the selected loadout or saved preset.

## In combat

- **Tab**: inventory, or interrupt handling and return to inventory. Combat continues.
- Select an ammunition packet, then a compatible magazine, then transfer.
- Alternatively select source and destination magazines of the same caliber.
- Handling closes the inventory to show the first-person animation. Weapons
  and movement are blocked during handling. Wounds interrupt the action.
- Backpack access takes 3.4 s; loading is 0.9 s per cartridge. Magazine handling
  without a backpack starts with a 1 s draw and ends with 0.8 s stow. Backpack
  items take 2.2 s to stow. A round is committed only at a completed transfer
  checkpoint. Interruption preserves completed rounds and the chamber.
- Paper packets visibly open and empty; an exhausted packet is discarded.
- **K**: retrieve/stow an equipped laser rangefinder. **Left mouse**: measure.
  6× view, 0.35 s sampling, 1 m display increments, 5–1200 m modeled range.
  Aim movement invalidates the sample. The first collider is measured;
  an obstructed target cannot be measured through the obstruction. Sky gives
  no return. Opaque leaf texels block a distant reading; transparent gaps do not.
  This is a simplified laser model, without material reflectivity,
  fog/rain attenuation or a beam-footprint solver.
- **H**: first use the two belt medkits. Once exhausted, access a backpack
  medkit before the existing 6 s treatment. In inventory a selected pack
  medkit can be used directly. It is consumed only after treatment completes.
- **T**, **T + 1/2/3**: physical magazine inspection, with a short, deliberately
  coarse weight estimate. Repeating an unchanged inspection does not reroll
  its uncertainty. No precise ammunition count is added to the combat HUD.
- **B** still changes fire mode. **K** is separate from that existing binding.

Yellow tape marks the player's squad (UA); red marks the opposing squad (RF).
Tape follows each upper-arm joint and does not change with camouflage.

## Load and running speed

Hunt, Tofari, Billing & Silk (2016), *Tactical combat movements*, studied 19
soldiers with external loads of 10–30 kg. Repeated 30 m sprint completion time
increased about 0.8% per kg on average; this is not a universal speed law.
Source: https://doi.org/10.1080/00140139.2015.1132780

The game translates that time relationship into speed:

`v(L) = 6.3 / [1 + 0.008 × (L − 10)] m/s`

`L` is total external carried mass, not body mass: clothing/armor/helmet,
weapons, all magazines, chambered cartridges, belt medkits, pack and contents.
The base 6.3 m/s is the game's 10 kg reference. At 20 kg it is 5.83 m/s; at
30 kg, 5.43 m/s. Outside the studied 10–30 kg range the formula is explicitly a
game extrapolation. Injury, stance and aiming restrictions apply separately.
Walking speed is unchanged. Spending ammunition or using medkits reduces mass.

## Projectile flight

`FlightModel` uses G1 drag coefficients by Mach number, representative per-load
BC values, standard-density air (1.225 kg/m³), 340.3 m/s speed of sound and
9.80665 m/s² gravity. Acceleration uses air-relative velocity. RK4 integration
and collision sweeps are bounded to 1/240 s; the projectile is never rendered
as a visible white dot. Wind support is implemented, default weather is calm.
Iron-sight zero and PSO-1 calibration use the same flight solver. Existing
geometric thickness, layered penetration and energy loss remain active.

Profiles (game FMJ approximations, not certified ammunition firing tables):

| Weapon | Muzzle m/s | G1 BC | Projectile kg |
| --- | ---: | ---: | ---: |
| AK-74M | 880 | .310 | .0034 |
| M16A2 | 940 | .304 | .0040 |
| SVD | 830 | .411 | .0096 |
| PM | 315 | .120 | .0061 |
| M9 | 365 | .160 | .0080 |

The solver is independently checked against the Hornady 2022 metric chart's
5.45 V-MAX reference at 50–300 m (BC .285, 856 m/s), within 4 m/s. That
reference validates the solver; it does not turn the game's FMJ into V-MAX.
Also tested: frame-step convergence, wind drift, sight zeros, scope alignment,
centimeter-thick barriers, tapered concrete and overlapping materials.

Sources:
- G1 BRL reference data / JBM: https://jbmballistics.com/downloads.html
- Numeric table mirror: https://github.com/gehtsoft-usa/go_ballisticcalc/blob/master/Drag.go
- Independent manufacturer reference: https://static.hornady.media/presscenter/docs/1410998059-2022-Metric-Ballistics-Chart.pdf

This remains a point-mass game simulation: no spin drift, Coriolis, bullet yaw,
fragment-by-fragment terminal mechanics or certified armor behavior.

## Reconnaissance quadcopter (0.11.0)

Розвіддрон / FPV — 0.11.0:
Додай «Розвіддрон / FPV» у наплічник (3×2 клітинки, комплект 1,2 кг).
J — дістати дрон / надягти або зняти окуляри; також через інвентар Tab.
WASD — горизонтальний рух, миша — курс і нахил камери.
Space — зліт / набір висоти, Ctrl — зниження / посадка, Shift — швидше.
F після посадки — вимкнути мотори; J — повернутися до бійця.
Підійди до дрона і натисни F: складання у наплічник займає 2,2 с.
Потрібні вільні 3×2 клітинки. Батарея й пошкодження зберігаються.
Пілот не рухається й не стріляє через окуляри, але може бути поранений.
Режим польоту стабілізований: після відпускання керування дрон гальмує
і зависає. Це не acro-симулятор. При втраті зв’язку / низькому заряді —
автопосадка; на порожній батареї мотори зупиняються.

Game parameters: 8 minutes nominal hovering, 6 m/s cruise / 12 m/s boost,
3 m/s climb, 4 m/s² acceleration, 450 m nominal radio range with occlusion
penalty, 100 m height limit. Pilot-side 0.4 kg controller/goggles remains
counted after deploying the 0.8 kg aircraft. Radio obstruction, battery and
flight controls are approximations; no weapons, automatic enemy markers,
acro/rate flight, GPS return-to-home, repair or battery exchange yet.

## RPO-A Shmel — 0.13.0

Choose the assault pack, then add the launcher from the equipment catalog.
The tube is carried on an exterior attachment and reserves 6 × 2 grid cells;
its loaded mass is 11 kg and the normal 18 kg payload limit still applies.
Press **4** to retrieve or stow, right mouse to aim and left mouse to fire.
Retrieval takes 3.8 seconds. The tube is single-use; only F8 retains it for
debug reuse. A blocked muzzle or interrupted draw does not consume it.
See [SHMEL-REFERENCES.md](SHMEL-REFERENCES.md) for nominal specifications
and the distinction between sourced values and game damage parameters.
