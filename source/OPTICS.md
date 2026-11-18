# SVD / PSO-1 implementation — 0.9.0

This is a game simulation, not a validated firing-table or optical-design tool.

## Reference and representation

The original SVD manual describes a 10-round 7.62×54R rifle and a fixed 4× PSO-1
with a 6° field, 6 mm exit pupil and 68.2 mm eye relief. The representative
ordinary cartridge uses a 9.6 g projectile at 830 m/s. The original manual,
including specifications and reticle drawings, is available at
https://www.kronzky.info/misc/dragunov.pdf.

The game uses an original full-size wooden-stock SVD mesh with a side-mounted
PSO-1, separate magazine and bolt, working reload/inspection/rack actions and
persistent rimmed case/live-round debris. The first load contains 40 rounds:
9 in the inserted magazine, 1 in the chamber and three full spare magazines.
It is semi-automatic; holding the trigger does not repeat shots. The mechanical
cooldown is not a claim about practical aimed rounds per minute.

## Controls and optics

While aiming with RMB:

- Page Up / Page Down: elevation setting, 100–1000 m in 100 m steps.
- [ / ]: half-milliradian windage clicks, ±10 mil range.
- L: red reticle illumination. This does not brighten the scene.
- Hold Shift while stationary: limited breath hold, followed by recovery.

The etched chevrons, lateral mil marks and 1.7 m stadiametric scale are angular
geometry. Scale labels 2–10 correspond to 200–1000 m; no target/range lookup is
performed. The three lower chevrons are calibrated for the game's 1100/1200/1300 m
trajectories when the elevation dial is at 1000 m. Most campaign sightlines are
much shorter. Reading the scale and choosing a correction are manual actions.

A 768×768 MSAA viewport renders the existing world through a 6° camera. The
optical disc and eye relief give four-times magnification relative to the
surrounding view. The main ADS camera also narrows its peripheral field to 50°.
The physical gun and first-person hands are excluded from the optical camera.
Eye displacement and relief error produce a dark crescent/blackout. Occlusion
between the eye and objective blacks out the image instead of looking through
nearby cover. Rendering stops outside usable ADS, during actions and in menus.

Bore direction is physical. Elevation/windage move the reticle in a fixed
optical image, rather than rotating the camera or redirecting a bullet toward
a target. Gravity and Mach-dependent G1 drag use RK4 integration with steps no larger than 1/240 s. The zero and
holdover are calibrated against that same integrator, including the offset
between bore and sight. Tests compare against 240 Hz trajectories out to 1300 m.
Actual obstruction, penetration, movement, recoil and injury can still spoil a
shot. Crouching/prone position and holding breath reduce sway; sprint fatigue,
injury and repeated firing increase instability.

## Explicit limits

The G1 reference curve is tabulated; per-load BC values remain representative game approximations. See EQUIPMENT.md for the independent velocity-table validation.
Wind-relative drag is supported with calm default weather. Spin drift,
atmospheric variation, optical aberrations, diopter adjustment and detailed
focus/parallax optics are not simulated. Third-person fighters
currently carry AK-74M; the selected SVD appears on the player's loadout and
inventory character. SVD gunfire temporarily uses the existing licensed AK
recording as an acoustic stand-in, not an authentic SVD recording. See
`assets/AUDIO-CREDITS.md` and `assets/CHARACTER-CREDITS.md`.
