# Map data — «Великий штурм», Avdiivka (0.21)

**Map data © OpenStreetMap contributors**, available under the Open Database
License (ODbL 1.0): https://www.openstreetmap.org/copyright —
https://opendatacommons.org/licenses/odbl/1-0/

Buildings, streets, roads, railways, tree rows, woods, water and place names
of the Avdiivka area were exported from OpenStreetMap through the Overpass API
by `source/tools/build_avdiivka.py` and converted into the game's own formats
(`source/assets/maps/avdiivka/features.json`, `battle.bin`, `cover.bin`,
`forest.bin`, `trees.bin`). These files are a Derivative Database of
OpenStreetMap and are made available under the same ODbL 1.0. Building
heights, wall and roof colours, tree positions inside woods and the gaps in
the private sector are generated, not surveyed.

**Relief**: AWS Terrain Tiles (Mapzen «terrarium» encoding, zoom 13),
https://registry.opendata.aws/terrain-tiles/ — derived in this area from
SRTM (NASA / USGS, public domain). Resampled to a 20 m grid (`relief.bin`)
and a 1 m grid for the battlefield (`battle_relief.bin`).

The coordinate grid of the tablet is SK-42 / Gauss–Krüger zone 7 computed
from these data; magnetic declination and grid convergence are approximate
values for the area. The map is a game approximation and must not be used
for navigation.
