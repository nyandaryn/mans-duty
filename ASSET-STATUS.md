# Weapon models — 0.4

All four shipped weapon models are original authored geometry and generated materials.
The AK-74M follows the requested dark metal / black polymer style, with a folding-stock silhouette, ribbed handguard, curved magazine, receiver controls, tangent rear sight, front sight and muzzle brake.
The M16, PM and M9 share the metal/polymer material treatment; PM slide/frame contours and pistol trigger guards have been rebuilt.

Visual reference: [AK-74M by SeveN](https://sketchfab.com/3d-models/ak-74m-84bb0a58a18047069706047639b82899).
Only its public preview was consulted. No Sketchfab geometry or textures are included. These are simplified game models, not a reproduction of the reference mesh or an assertion of identical visual quality.

## Editable assets

- `assets/models/ak74m.scn`
- `assets/models/m16.scn`
- `assets/models/pm.scn`
- `assets/models/m9.scn`

Open these Godot scenes to inspect meshes, materials, the Magazine and Bolt assemblies, and sight/muzzle markers. The runtime attaches the animated hands independently. Bots share the same AK-74M asset.

Original geometry builders: `scripts/weapon_art.gd` and `scripts/models.gd`.
Rebuild with `godot --headless --path . --script res://tests/bake_weapons.gd` after changing the builders. This replaces the baked scenes; hand edits to them should be preserved separately first.
Original 512-pixel metal/polymer/grip albedo, roughness and normal maps: `assets/textures/weapons/`.
Texture generation: `python3 tools/generate_weapon_textures.py` (Pillow).

The blood texture and remaining procedural geometry were also generated for this project. External audio attribution is in `assets/AUDIO-CREDITS.md`.
