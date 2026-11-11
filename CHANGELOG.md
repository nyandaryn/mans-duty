# 0.5.3

- Magazine inspection 3.8 -> 2.1 s; chamber check 2.5 -> 1.8 s.
- R during the in-hand inspection window promotes the held magazine into reload. Prepared-pouch exchange takes 1.75 s; already-removed loaded magazine takes 2.25 s, plus chambering if needed.
- Separate weapon-well, three chest-pouch and two belt-pouch retrieval/return paths.
- Corrected cartridge seating, added feed lips, rebuilt inclined pistol magazine bodies/floorplates and aligned witness apertures.
- Added 277 handoff, interruption/conservation, geometry and input checks; graphical inspection of magazine and accelerated reload poses.

# 0.5.2

- Replaced sparse shelterbelt rows and open fields with dense woodland across the playable area and surrounding scenery: 1039 trees and 2067 undergrowth patches.
- Narrow winding path replaces straight farm track. Small clearances preserve access to shelters, firing bays and spawn points.
- Taller undergrowth obstructs standing-height recognition; wider overlapping crowns provide forest shade.
- Verified all bot/interior routes, protected insertion and sampled foliage screening; graphical check with active bots averaged about 60 FPS at one viewpoint on RX 550, 1280x720 (not a map-wide performance guarantee).

# 0.5.1

- Fixed cadence drift from discarded frame remainder and floating-point cooldown boundaries.
- AK 600 rpm; M16A2 800 rpm within three-shot bursts. PM/M9 semi-auto trigger cycle gates 0.12/0.10 s, with no held-trigger auto-fire.
- Bots use weapon cycle intervals and preserve within-burst timer remainder.
- Added 37 timing/trigger checks at 4, 20, 30, 60 and 120 Hz.

# 0.5.0

- Two selectable maps: furnished city ground floors and a 192 m shelterbelt with fields and shelters.
- Equipment slots, character preview, seven outfits and enemy uniform selection.
- Distance, exposed body, background color, shade, movement and gunfire based recognition.
- Finite magazines with persistent identity/ammunition; R+slot exchange, I chamber and T magazine inspections.
- No combat hit/kill/ammunition confirmations; return-to-start mission report. Impact blood spray.
- Physical spent cases and live cartridges persist through the match.
- Recorded positional pain voices, stronger blackout, distance gunfire falloff and cumulative temporary tinnitus/muffling.

# 0.4.2

- Wound classification uses the full trajectory through each oriented hit region; lateral penetrating shots no longer become automatic grazes.
- Head hit region covers the visible helmet; PM head hits are regression-tested in standing and kneeling poses from front and side.
- Tight bone-aligned arm/thigh/shin regions and separate feet replace oversized diagonal boxes. Central upper-limb tracks trigger the simplified severe-vessel wound.
- Increased penetrating limb damage; disabling wounds interrupt firing, trigger a visible collapse, and restrict movement. Critical player blood loss blocks firing and movement.
- Injured bots use two finite universal kits with six-second visible treatment. Bleeding continues until completion; incoming damage interrupts, pause freezes, death prevents treatment.
- Bot crouch uses a forward supporting leg and a rear grounded knee. Injured players must remain prone (or crouched where lying down is obstructed) until healed.
- The medical model remains a gameplay approximation: no geometric organs/bones, validated armor classes, or calibrated clinical timing. Universal full recovery remains temporary gameplay behavior.

# 0.4.1

- Added F8 / pause-menu debug immortality with an explicit HUD indicator; activation clears injuries and restores health, and disabling restores normal damage.
- Replaced oversized concrete-barrier box collision with the exact tapered mesh, removed marks for invalid surface normals, and added a barrel-obstruction HUD warning.

- Added Z toggle for prone: horizontal body collision and hit regions, 0.85 m/s crawl, low eye level, aimed fire and reduced recoil; sprint/jump and blind-over-cover fire are disabled while prone.
- Check space before lying down, standing up and rotating the horizontal body near walls.
- Moved spawn to a sheltered rear courtyard behind the south-east apartment block, facing the exit; added paving and low cover, with routes around either side.
- Verified all ten initial enemy sightlines are blocked and both exits remain reachable; added 35 posture/spawn regression checks.

# 0.4.0

- Moved head rotation to the base of the neck, aligned the eye with the weapon, limited neck extension in aiming and ragdoll, and added 9 pose/physics regression checks.

- Added original AK-74M geometry in the requested reference style, editable baked weapon scenes, shared 512px metal/polymer/grip maps, revised M16 controls and pistol contours; bots use the same AK model.
- Fixed mixed indexed/unindexed mesh batching dropping geometry. Added 18 geometry preservation / moving assembly checks.

- Fixed PM slide/frame geometry and hard-surface normals; neutral daylight replaces tinted fog.
- Added anatomy-following projectile hit areas, separate degrading armour plates, fatal head hits, grazing/blunt/penetrating/arterial/internal wound categories, limb function loss, bleeding and visual symptoms.
- Added original blood-stain texture projected onto clothing geometry and limited persistent blood marks on ground.
- Added six-second animated universal medical kit; two per match, interrupted by damage, with no armour repair.
- Replaced rigid death tween with jointed physical bodies and a dropped rifle, including pause/restart handling.
- Added bot hearing uncertainty, reaction delay, shared last-known contacts, suppression, reachable/reserved cover, crouch/peek/reposition, aimed bursts, recoil and finite-magazine reload animations/sounds.
- Added collision-limited Q/E lean, C top peek and Alt+Q/E/C blind rifle fire. Crouching now changes the movement capsule and hit areas.
- Added spring camera recoil and weapon kick with stance/movement/aim/burst modifiers. Removed omniscient enemy radar.
- WOUND-MODEL.md documents the simplified injury/armour rules and symptom research sources.

# 0.3.0

- Rebuilt district facades with framed windows, balcony railings, entrances, panel seams, downpipes, AC units and rooftop details.
- Added profiled sedan bodies, wheel arches, tyres, rims, windows, door lines, mirrors, lighting and bumpers.
- Added branched trees with original alpha-cutout foliage, slatted benches, swings, bins, kerbs, drains, manholes, road repairs and vegetation.
- Replaced block characters with rounded anatomy, camouflaged uniforms, helmets, eye protection, plate carriers, pouches, packs, knee pads and boots. Added hip/knee gait and model-based muzzle origins.
- Batched static geometry by material and spatial cell; merged rigid character parts. Enabled budget directional shadows with a menu toggle.
- Preserved simplified gameplay cover and navigation; all ten bot spawns retain routes to the player.

Limits: low-poly procedural art, simple distant buildings, no building interiors, simplified prop collisions, cosmetic bot equipment.

# 0.2.0

- Rebuilt all four weapon models: bevelled metal parts, wood/bakelite/polymer surfaces, actual open iron sights, separate magazines and bolt/slide assemblies.
- Aligned the camera to front/rear sight geometry; aperture on M16A2, open notches on AK-74/PM/M9. No fake sight overlay.
- Animated magazine extraction, insertion and chambering with moving support hand, separate forearms and phase-timed mechanism audio. Retained interrupted-reload state and chamber semantics.
- Corrected two-handed pistol grip and sleeve behavior during slide manipulation.
- Replaced hitscan damage and visible tracers with invisible swept-segment projectiles, muzzle origin, representative muzzle velocity, gravity, quadratic drag and energy-scaled damage. Applied to players and bots.
- Added case ejection, brief small muzzle flash, impact marks and dust.
- Added CC0 recorded shots and handling sounds. Sources and stand-ins are explicitly documented in assets/AUDIO-CREDITS.md.
- Verified 159 weapon-state checks, 24 ballistic/geometry/animation checks, match lifecycle tests, graphical previews and a recorded demo.

Limits: procedural art and animation, approximate exterior ballistics, no penetration/ricochet/wind, several audio recordings substitute for the exact named weapons.
