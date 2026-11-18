# Character assets — Mans Duty 0.9.0

The adult male head/neck is derived from the **MakeHuman Community** core assets,
licensed under **CC0 1.0 Universal**. No MakeHuman program code is incorporated.

Pinned upstream revision: `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`.

- Base mesh: https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/3dobjs/base.obj
- Adult male morph: https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/targets/macrodetails/caucasian-male-young.target
- Average build morph: https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/targets/macrodetails/universal-male-young-averagemuscle-averageweight.target
- Upstream license: https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/LICENSE.md
- License explanation: https://www.makehumancommunity.org/about/license.html
- CC0 license: https://creativecommons.org/publicdomain/zero/1.0/

`characters/MAKEHUMAN-LICENSE.md` preserves the upstream license statement. Its
AGPL section concerns the separate MakeHuman application, not these CC0 assets.

## Texture

`characters/young_caucasian_male_diffuse.png` is the unmodified 2048×2048
`skins/young_caucasian_male/young_lightskinned_male_diffuse.png` from the official
MakeHuman system asset pack. Author: `makehuman_system`; listed license: CC0.

Asset/license listing: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html
Download: https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip

## Modifications and game-owned assets

`tools/build_character_head.py` applies the adult male morphs, extracts only the
visible head/neck body surface, retains original UVs, mirrors the forward axis,
scales to metres and moves the neck pivot. Its output is `characters/head.json`
(8,516 triangles). Helper geometry and the rest of the anatomical mesh are not
redistributed. Mesh, texture and materials are cached and shared by instances.

The jacket, trousers, helmet, carrier, pouches, boots, gloves, articulated rig,
camouflage patterns, SVD mesh and PSO-1 reticle renderer are original project
geometry/code. Existing camouflage IDs, blood attachment and animation joints
are preserved. No Sketchfab model or texture has been copied.
