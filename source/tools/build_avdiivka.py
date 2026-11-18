#!/usr/bin/env python3
"""Builds the Avdiivka operation area for «Великий штурм» from real map data.

Inputs (downloaded separately, never executed):
  osm.json   — Overpass API export (out geom) of buildings, roads, railways,
               land use, woods and water around Avdiivka, © OpenStreetMap
               contributors, ODbL 1.0.
  dem/       — Terrarium elevation tiles z13 (AWS Terrain Tiles / Mapzen,
               SRTM-derived), named t_<x>_<y>.png.

Outputs into source/assets/maps/avdiivka/:
  meta.json      — origin, base altitude, sheet names, places, objectives.
  relief.bin     — float32 LE heights (m above the base altitude), 20 m grid.
  cover.bin      — RGB8 land cover of the outer terrain, one pixel per node.
  forest.bin     — L8 forest mask on the same grid (canopy over these nodes).
  battle.bin     — RGB8 1 m ground colour of the 400 × 400 m battlefield; the
                   last 18 m blend into the outer land cover.
  battle_relief.bin — float32 LE 1 m heights of the battlefield: Catmull–Rom
                   relief, blended over the last 24 m into the outer ground's
                   triangles so both meshes share the edge.
  trees.bin      — trees outside the battlefield: int16 x, z (0.25 m), u8
                   kind (0 wood, 1 tree row, 2 yard), u8 height (0.1 m).
  features.json  — buildings, roads, railways, water, woods in game metres.

Game coordinates: x = easting − E0, z = −(northing − N0): −Z is grid north of
the Gauss–Krüger zone 7 (central meridian 39° E, Krasovsky ellipsoid), as on
SK-42 maps. WGS84 latitude/longitude are projected without a datum shift, so
absolute coordinates are approximate (~100 m); relative geometry is exact.

Usage: python3 -I build_avdiivka.py <osm.json> <dem_dir> <out_dir>
"""
import json, math, os, struct, sys, random
from PIL import Image, ImageDraw

# Battlefield centre: the southern private sector between Yaroslava Homzy,
# Sportyvna and Soborna streets.
ORIGIN_LAT, ORIGIN_LON = 48.11749, 37.75733
HALF = 6000          # outer area, metres from the origin
STEP = 20            # relief grid
BATTLE = 200         # battlefield half size
A_KR, F_KR = 6378245.0, 1/298.3
L0 = math.radians(39.0)
FALSE_EASTING = 7_500_000.0


def gk(lat, lon):
    """Gauss–Krüger zone 7 easting/northing (Snyder transverse Mercator)."""
    a, f = A_KR, F_KR
    e2 = 2*f-f*f; ep2 = e2/(1-e2)
    phi = math.radians(lat); lam = math.radians(lon)
    n = a/math.sqrt(1-e2*math.sin(phi)**2)
    t = math.tan(phi)**2; c = ep2*math.cos(phi)**2
    A = (lam-L0)*math.cos(phi)
    e4, e6 = e2*e2, e2*e2*e2
    m = a*((1-e2/4-3*e4/64-5*e6/256)*phi-(3*e2/8+3*e4/32+45*e6/1024)*math.sin(2*phi)
           + (15*e4/256+45*e6/1024)*math.sin(4*phi)-(35*e6/3072)*math.sin(6*phi))
    x = n*(A+(1-t+c)*A**3/6+(5-18*t+t*t+72*c-58*ep2)*A**5/120)
    y = m+n*math.tan(phi)*(A*A/2+(5-t+9*c+4*c*c)*A**4/24+(61-58*t+t*t+600*c-330*ep2)*A**6/720)
    return x+FALSE_EASTING, y


E0, N0 = (round(v) for v in gk(ORIGIN_LAT, ORIGIN_LON))


def game(lat, lon):
    e, n = gk(lat, lon)
    return (e-E0, -(n-N0))


def latlon(x, z):
    """Inverse of game() by Newton iteration on the forward projection."""
    lat, lon = ORIGIN_LAT-z/111200.0, ORIGIN_LON+x/74300.0
    for _ in range(6):
        gx, gz = game(lat, lon)
        dx, dz = x-gx, z-gz
        if abs(dx) < 0.01 and abs(dz) < 0.01:
            break
        h = 1e-5
        ax, az = game(lat+h, lon); bx, bz = game(lat, lon+h)
        j11, j12, j21, j22 = (ax-gx)/h, (bx-gx)/h, (az-gz)/h, (bz-gz)/h
        det = j11*j22-j12*j21
        lat += (j22*dx-j12*dz)/det
        lon += (-j21*dx+j11*dz)/det
    return lat, lon


# --- elevation ---------------------------------------------------------------

class Terrarium:
    def __init__(self, folder):
        self.z = 13
        self.tiles = {}
        for name in os.listdir(folder):
            if name.startswith('t_') and name.endswith('.png'):
                _, tx, ty = name[:-4].split('_')
                img = Image.open(os.path.join(folder, name)).convert('RGB')
                self.tiles[(int(tx), int(ty))] = img.load()

    def raw(self, px, py):
        tx, ty = px//256, py//256
        tile = self.tiles.get((tx, ty))
        if tile is None:
            raise KeyError(f'missing elevation tile {tx},{ty}')
        r, g, b = tile[px % 256, py % 256]
        return r*256+g+b/256-32768

    def height(self, lat, lon):
        n = 2**self.z*256
        fx = (lon+180)/360*n
        fy = (1-math.log(math.tan(math.radians(lat))+1/math.cos(math.radians(lat)))/math.pi)/2*n
        x0, y0 = int(math.floor(fx-0.5)), int(math.floor(fy-0.5))
        u, v = fx-0.5-x0, fy-0.5-y0
        h00, h10 = self.raw(x0, y0), self.raw(x0+1, y0)
        h01, h11 = self.raw(x0, y0+1), self.raw(x0+1, y0+1)
        return (h00*(1-u)+h10*u)*(1-v)+(h01*(1-u)+h11*u)*v


# --- geometry helpers ----------------------------------------------------------

def hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]


def min_rect(points):
    """Minimum-area rectangle: centre, size along the edge, size across, angle."""
    h = hull(points)
    best = None
    for i in range(len(h)):
        a, b = h[i], h[(i+1) % len(h)]
        ang = math.atan2(b[1]-a[1], b[0]-a[0])
        c, s = math.cos(ang), math.sin(ang)
        us = [p[0]*c+p[1]*s for p in h]; vs = [-p[0]*s+p[1]*c for p in h]
        area = (max(us)-min(us))*(max(vs)-min(vs))
        if best is None or area < best[0]:
            cu, cv = (max(us)+min(us))/2, (max(vs)+min(vs))/2
            best = (area, (cu*c-cv*s, cu*s+cv*c), max(us)-min(us), max(vs)-min(vs), ang)
    return best


def polygon_area(p):
    return abs(sum(p[i][0]*p[(i+1) % len(p)][1]-p[(i+1) % len(p)][0]*p[i][1] for i in range(len(p))))/2


def simplify(points, tolerance):
    """Douglas–Peucker; a closed ring is split in two so its ends never collapse."""
    if len(points) < 3:
        return points
    if math.dist(points[0], points[-1]) < 0.01 and len(points) > 4:
        mid = len(points)//2
        return simplify(points[:mid+1], tolerance)[:-1]+simplify(points[mid:], tolerance)
    a, b = points[0], points[-1]
    dx, dz = b[0]-a[0], b[1]-a[1]
    length = math.hypot(dx, dz) or 1e-9
    worst, index = -1, 0
    for i in range(1, len(points)-1):
        d = abs(dz*points[i][0]-dx*points[i][1]+b[0]*a[1]-b[1]*a[0])/length
        if d > worst:
            worst, index = d, i
    if worst <= tolerance:
        return [a, b]
    return simplify(points[:index+1], tolerance)[:-1]+simplify(points[index:], tolerance)


def rings(parts):
    """Joins open member ways of a multipolygon into closed rings."""
    parts = [p for p in parts if len(p) >= 2]
    out = []
    while parts:
        ring = parts.pop(0)
        changed = True
        while changed and math.dist(ring[0], ring[-1]) > 0.5:
            changed = False
            for i, p in enumerate(parts):
                if math.dist(ring[-1], p[0]) < 0.5: ring += p[1:]
                elif math.dist(ring[-1], p[-1]) < 0.5: ring += p[::-1][1:]
                elif math.dist(ring[0], p[-1]) < 0.5: ring = p+ring[1:]
                elif math.dist(ring[0], p[0]) < 0.5: ring = p[::-1]+ring[1:]
                else: continue
                parts.pop(i); changed = True
                break
        out.append(ring)
    return out


def flat(points, digits=1):
    out = []
    for x, z in points:
        out += [round(x, digits), round(z, digits)]
    return out


def inside(p, half):
    return abs(p[0]) <= half and abs(p[1]) <= half


# --- main ----------------------------------------------------------------------

ROAD_WIDTH = {'motorway': 14, 'trunk': 13, 'primary': 9, 'secondary': 8, 'tertiary': 7, 'trunk_link': 7, 'primary_link': 7,
              'secondary_link': 6.5, 'residential': 6, 'unclassified': 5.5, 'living_street': 5, 'service': 3.6, 'track': 3.2,
              'pedestrian': 4, 'footway': 1.6, 'path': 1.4, 'steps': 1.6}
PAVED = {'asphalt', 'concrete', 'paved', 'paving_stones', 'concrete:plates', 'sett'}
UNPAVED = {'ground', 'dirt', 'unpaved', 'compacted', 'gravel', 'fine_gravel', 'grass', 'sand', 'earth', 'mud'}
LANDUSE_KIND = {'farmland': 'field', 'meadow': 'grass', 'grass': 'grass', 'grassland': 'grass', 'heath': 'grass',
                'allotments': 'garden', 'orchard': 'garden', 'residential': 'residential', 'industrial': 'industrial',
                'railway': 'industrial', 'garages': 'industrial', 'retail': 'industrial', 'construction': 'industrial',
                'landfill': 'waste', 'quarry': 'waste', 'cemetery': 'cemetery', 'farmyard': 'industrial',
                'greenhouse_horticulture': 'garden', 'recreation_ground': 'grass', 'greenfield': 'grass', 'basin': 'water',
                'wetland': 'wet', 'scrub': 'scrub', 'spoil_heap': 'waste', 'beach': 'grass', 'sand': 'waste', 'park': 'grass',
                'pitch': 'grass', 'stadium': 'grass', 'common': 'grass'}
COVER = {'field': (148, 140, 92), 'grass': (122, 131, 84), 'garden': (112, 124, 74), 'residential': (128, 128, 98),
         'industrial': (128, 124, 114), 'waste': (122, 112, 96), 'cemetery': (104, 116, 82), 'water': (80, 100, 104),
         'wet': (96, 110, 80), 'scrub': (98, 110, 70), 'wood': (70, 86, 54), 'steppe': (140, 134, 94)}


def main(osm_path, dem_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    data = json.load(open(osm_path, encoding='utf-8'))
    dem = Terrarium(dem_dir)
    random.seed(161126)

    # Relief grid: SRTM-class data with a light 3×3 smoothing of radar noise.
    size = HALF*2//STEP+1
    raw = [[0.0]*size for _ in range(size)]
    for j in range(size):
        for i in range(size):
            lat, lon = latlon(-HALF+i*STEP, -HALF+j*STEP)
            raw[j][i] = dem.height(lat, lon)
    relief = [[0.0]*size for _ in range(size)]
    for j in range(size):
        for i in range(size):
            total, weight = 0.0, 0.0
            for dj in (-1, 0, 1):
                for di in (-1, 0, 1):
                    jj, ii = min(size-1, max(0, j+dj)), min(size-1, max(0, i+di))
                    w = 4 if dj == 0 and di == 0 else (2 if dj == 0 or di == 0 else 1)
                    total += raw[jj][ii]*w; weight += w
            relief[j][i] = total/weight
    centre = relief[size//2][size//2]
    base = float(round(centre))
    with open(os.path.join(out_dir, 'relief.bin'), 'wb') as f:
        for row in relief:
            f.write(struct.pack('<%df' % size, *[h-base for h in row]))

    def g(e):
        return [game(p['lat'], p['lon']) for p in e.get('geometry', []) if p]

    buildings, roads, rails, streams, water, woods, rows, landuse, places = [], [], [], [], [], [], [], [], []
    for e in data['elements']:
        t = e.get('tags', {})
        if e['type'] == 'node' and 'place' in t:
            x, z = game(e['lat'], e['lon'])
            if inside((x, z), HALF+3000):
                places.append([t.get('name:uk', t.get('name', '')), round(x), round(z), t['place']])
            continue
        if e['type'] == 'relation':
            # Multipolygon land use: outer members joined end to end into rings.
            kind = 'wood' if t.get('natural') == 'wood' or t.get('landuse') == 'forest' else LANDUSE_KIND.get(t.get('landuse', t.get('natural', '')))
            if not kind:
                continue
            for pts in rings([[game(p['lat'], p['lon']) for p in m['geometry'] if p] for m in e.get('members', []) if m.get('role') == 'outer' and 'geometry' in m]):
                if len(pts) >= 3 and any(inside(p, HALF+500) for p in pts):
                    pts = simplify(pts, 1.0)
                    (woods if kind == 'wood' else landuse).append(pts if kind == 'wood' else [kind, pts])
            continue
        if e['type'] != 'way':
            continue
        pts = g(e)
        if len(pts) < 2 or not any(inside(p, HALF+400) for p in pts):
            continue
        if 'building' in t:
            if len(pts) < 4:
                continue
            area, (cx, cz), w, d, ang = min_rect(pts[:-1] if pts[0] == pts[-1] else pts)
            if w < 2 or d < 2:
                continue
            levels = t.get('building:levels')
            try:
                levels = max(1, min(16, int(float(levels))))
            except (TypeError, ValueError):
                levels = 0
            kind = t['building']
            footprint = polygon_area(pts)
            if kind in ('apartments', 'dormitory') or (levels >= 3):
                code = 'A'
            elif kind in ('industrial', 'warehouse', 'factory', 'manufacture', 'hangar', 'service', 'transportation', 'storage_tank', 'silo'):
                code = 'I'
            elif kind in ('garage', 'garages', 'shed', 'roof', 'hut', 'barn', 'kiosk', 'greenhouse'):
                code = 'S'
            elif kind in ('school', 'kindergarten', 'hospital', 'public', 'commercial', 'retail', 'office', 'civic', 'church', 'train_station', 'college', 'university'):
                code = 'P'
            elif footprint > 450 and kind == 'yes':
                code = 'I'
            elif footprint < 22:
                code = 'S'
            else:
                code = 'H'
            if levels == 0:
                levels = {'A': 5, 'I': 1, 'S': 1, 'P': 2, 'H': 1}[code]
            yaw = -ang  # Basis(UP, yaw) maps local +X to (cos yaw, −sin yaw)
            buildings.append([round(cx, 1), round(cz, 1), round(w, 1), round(d, 1), round(yaw, 3), levels, code])
            continue
        if 'highway' in t and t['highway'] in ROAD_WIDTH:
            surface = t.get('surface', '')
            hw = t['highway']
            paved = surface in PAVED or (surface not in UNPAVED and hw in ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'trunk_link', 'primary_link', 'secondary_link', 'residential', 'living_street'))
            if hw in ('track',) and surface not in PAVED:
                paved = False
            width = ROAD_WIDTH[hw]
            if 'lanes' in t:
                try:
                    width = max(width, int(t['lanes'])*3.5)
                except ValueError:
                    pass
            roads.append([hw, width, 1 if paved else 0, flat(simplify(pts, 0.6)), t.get('name', '')])
            continue
        if t.get('railway') in ('rail',) and t.get('service') not in ('yard', 'siding', 'spur') or t.get('railway') == 'rail' and len(pts) > 6:
            rails.append(flat(simplify(pts, 0.8)))
            continue
        if t.get('waterway') in ('stream', 'river', 'canal', 'ditch', 'drain'):
            streams.append([t['waterway'], flat(simplify(pts, 1.5))])
            continue
        if t.get('natural') == 'water' or t.get('landuse') == 'basin':
            water.append(simplify(pts, 1.0))
            continue
        if t.get('natural') == 'wood' or t.get('landuse') == 'forest':
            woods.append(simplify(pts, 1.0))
            continue
        if t.get('natural') == 'tree_row':
            rows.append(flat(simplify(pts, 1.0)))
            continue
        kind = LANDUSE_KIND.get(t.get('landuse', t.get('natural', t.get('leisure', ''))))
        if kind and len(pts) >= 3:
            landuse.append([kind, simplify(pts, 1.0)])

    # Outer land cover, one pixel per relief node (row 0 = north edge).
    scale = 1.0/STEP
    def to_px(p): return ((p[0]+HALF)*scale, (p[1]+HALF)*scale)
    cover = Image.new('RGB', (size, size), COVER['steppe'])
    draw = ImageDraw.Draw(cover)
    order = ['field', 'grass', 'garden', 'residential', 'cemetery', 'industrial', 'waste', 'scrub', 'wet']
    for kind in order:
        for k, pts in landuse:
            if k == kind:
                draw.polygon([to_px(p) for p in pts], fill=COVER[kind])
    for pts in woods:
        draw.polygon([to_px(p) for p in pts], fill=COVER['wood'])
    for pts in water:
        draw.polygon([to_px(p) for p in pts], fill=COVER['water'])
    open(os.path.join(out_dir, 'cover.bin'), 'wb').write(cover.tobytes())
    # Forest mask (same grid): canopy is raised over these nodes.
    mask = Image.new('L', (size, size), 0)
    md = ImageDraw.Draw(mask)
    for pts in woods:
        md.polygon([to_px(p) for p in pts], fill=255)
    for line in rows:
        pts = [(line[i], line[i+1]) for i in range(0, len(line), 2)]
        md.line([to_px(p) for p in pts], fill=255, width=1)
    open(os.path.join(out_dir, 'forest.bin'), 'wb').write(mask.tobytes())

    # Trees of the outer area: jittered stands inside woods, tree rows and a
    # fruit tree or two in private yards, never on roads or in houses.
    fine = 4
    fsize = HALF*2//fine
    def f_px(p): return ((p[0]+HALF)/fine, (p[1]+HALF)/fine)
    wood_mask = Image.new('L', (fsize, fsize), 0)
    wd = ImageDraw.Draw(wood_mask)
    for pts in woods:
        wd.polygon([f_px(p) for p in pts], fill=255)
    block = Image.new('L', (fsize, fsize), 0)
    bd = ImageDraw.Draw(block)
    for hw, width, paved, line, name in roads:
        if hw in ('footway', 'path', 'steps'):
            continue
        bd.line([f_px((line[i], line[i+1])) for i in range(0, len(line), 2)], fill=255, width=max(1, int((width+3)/fine)))
    for b in buildings:
        c, s_ = math.cos(-b[4]), math.sin(-b[4])
        w, d = b[2]/2+1.5, b[3]/2+1.5
        bd.polygon([f_px((b[0]+u*c-v*s_, b[1]+u*s_+v*c)) for u, v in ((-w, -d), (w, -d), (w, d), (-w, d))], fill=255)
    wpx, bpx = wood_mask.load(), block.load()
    def free(x, z):
        if abs(x) <= BATTLE+2 and abs(z) <= BATTLE+2 or abs(x) > HALF-30 or abs(z) > HALF-30:
            return False
        i, j = int((x+HALF)/fine), int((z+HALF)/fine)
        return 0 <= i < fsize and 0 <= j < fsize and bpx[i, j] == 0
    trees = []
    spacing = 9.0
    n = int(HALF*2/spacing)
    for j in range(n):
        for i in range(n):
            x = -HALF+(i+0.5+random.uniform(-0.4, 0.4))*spacing
            z = -HALF+(j+0.5+random.uniform(-0.4, 0.4))*spacing
            pi_, pj = int((x+HALF)/fine), int((z+HALF)/fine)
            if 0 <= pi_ < fsize and 0 <= pj < fsize and wpx[pi_, pj] and free(x, z):
                trees.append((x, z, 0, random.uniform(9, 17)))
    for line in rows:
        pts = [(line[i], line[i+1]) for i in range(0, len(line), 2)]
        for a, b in zip(pts, pts[1:]):
            length = math.dist(a, b)
            for k in range(int(length/6)+1):
                t = k*6/length if length else 0
                x, z = a[0]+(b[0]-a[0])*t+random.uniform(-1, 1), a[1]+(b[1]-a[1])*t+random.uniform(-1, 1)
                if free(x, z):
                    trees.append((x, z, 1, random.uniform(8, 14)))
    for b in buildings:
        if b[6] != 'H' or random.random() < 0.35:
            continue
        for k in range(random.choice((1, 1, 2))):
            ang = random.uniform(0, math.tau); r = max(b[2], b[3])/2+random.uniform(4, 9)
            x, z = b[0]+math.cos(ang)*r, b[1]+math.sin(ang)*r
            if free(x, z):
                trees.append((x, z, 2, random.uniform(4, 7)))
    with open(os.path.join(out_dir, 'trees.bin'), 'wb') as f:
        for x, z, kind, h in trees:
            f.write(struct.pack('<hhBB', round(x*4), round(z*4), kind, min(255, round(h*10))))

    # Battlefield ground at 1 m: soil, yards, paved and dirt roads, paths.
    bsize = BATTLE*2+1
    ground = Image.new('RGB', (bsize, bsize), (118, 126, 80))
    gd = ImageDraw.Draw(ground)
    def b_px(p): return (p[0]+BATTLE, p[1]+BATTLE)
    for kind, pts in landuse:
        if True:
            gd.polygon([b_px(p) for p in pts], fill={'field': (140, 132, 88), 'garden': (106, 118, 70), 'residential': (116, 122, 80)}.get(kind, COVER[kind]))
    for pts in woods:
        gd.polygon([b_px(p) for p in pts], fill=(92, 98, 62))
    # Worn yards around houses.
    for b in buildings:
        if inside((b[0], b[1]), BATTLE+20) and b[6] in 'HSP':
            c, s = math.cos(-b[4]), math.sin(-b[4])
            w, d = b[2]/2+3.5, b[3]/2+3.5
            pts = [(b[0]+u*c-v*s, b[1]+u*s+v*c) for u, v in ((-w, -d), (w, -d), (w, d), (-w, d))]
            gd.polygon([b_px(p) for p in pts], fill=(128, 122, 92))
    for hw, width, paved, line, name in roads:
        pts = [(line[i], line[i+1]) for i in range(0, len(line), 2)]
        if not any(inside(p, BATTLE+60) for p in pts):
            continue
        if paved:
            gd.line([b_px(p) for p in pts], fill=(120, 118, 102), width=int(width+3))
            gd.line([b_px(p) for p in pts], fill=(72, 75, 74), width=int(width))
        else:
            gd.line([b_px(p) for p in pts], fill=(124, 108, 80), width=int(width+1))
            gd.line([b_px(p) for p in pts], fill=(112, 96, 70), width=max(1, int(width*0.6)))
    # Battlefield relief at 1 m and the colour blend into the outer cover.
    rel = [[h-base for h in row] for row in relief]
    def node(i, j):
        return rel[min(size-1, max(0, j))][min(size-1, max(0, i))]
    def tri(x, z):
        gx = min(max((x+HALF)/STEP, 0), size-1.0001); gz = min(max((z+HALF)/STEP, 0), size-1.0001)
        i, j = int(gx), int(gz); u, v = gx-i, gz-j
        a, b, c, d = node(i, j), node(i+1, j), node(i, j+1), node(i+1, j+1)
        return a+(b-a)*u+(c-a)*v if u+v <= 1 else d+(c-d)*(1-u)+(b-d)*(1-v)
    def cubic(p0, p1, p2, p3, t):
        return p1+0.5*t*(p2-p0+t*(2*p0-5*p1+4*p2-p3+t*(3*(p1-p2)+p3-p0)))
    def smooth(x, z):
        gx, gz = (x+HALF)/STEP, (z+HALF)/STEP
        i, j = math.floor(gx), math.floor(gz); u, v = gx-i, gz-j
        rows_ = [cubic(node(i-1, j+dj), node(i, j+dj), node(i+1, j+dj), node(i+2, j+dj), u) for dj in (-1, 0, 1, 2)]
        return cubic(rows_[0], rows_[1], rows_[2], rows_[3], v)
    def sstep(e0, e1, x):
        t = min(max((x-e0)/(e1-e0), 0.0), 1.0)
        return t*t*(3-2*t)
    cpx = cover.load()
    def cover_at(x, z):
        gx, gz = (x+HALF)/STEP, (z+HALF)/STEP
        i, j = math.floor(gx), math.floor(gz); u, v = gx-i, gz-j
        def c(ii, jj): return cpx[min(size-1, max(0, ii)), min(size-1, max(0, jj))]
        top = [c(i, j)[k]*(1-u)+c(i+1, j)[k]*u for k in range(3)]
        bottom = [c(i, j+1)[k]*(1-u)+c(i+1, j+1)[k]*u for k in range(3)]
        return [top[k]*(1-v)+bottom[k]*v for k in range(3)]
    gpx = ground.load()
    with open(os.path.join(out_dir, 'battle_relief.bin'), 'wb') as f:
        for zi in range(bsize):
            row = []
            for xi in range(bsize):
                x, z = xi-BATTLE, zi-BATTLE
                edge = BATTLE-max(abs(x), abs(z))
                t = tri(x, z)
                row.append(t+(smooth(x, z)-t)*sstep(0, 24, edge))
                blend = 1-sstep(0, 18, edge)
                if blend > 0:
                    cv = cover_at(x, z); g0 = gpx[xi, zi]
                    gpx[xi, zi] = tuple(round(g0[k]+(cv[k]-g0[k])*blend) for k in range(3))
            f.write(struct.pack('<%df' % bsize, *row))
    open(os.path.join(out_dir, 'battle.bin'), 'wb').write(ground.tobytes())
    if os.environ.get('PREVIEW'):
        for img, name in ((cover, 'cover'), (mask, 'forest'), (ground, 'battle')):
            img.save(os.path.join(os.environ['PREVIEW'], name+'.png'))

    # Objectives: on the three streets along the axis of attack.
    def street(name):
        lines = []
        for hw, width, paved, line, n in roads:
            if n == name:
                lines.append([(line[i], line[i+1]) for i in range(0, len(line), 2)])
        return lines
    def foot(p, lines):
        best = None
        for pts in lines:
            for a, b in zip(pts, pts[1:]):
                dx, dz = b[0]-a[0], b[1]-a[1]; L = dx*dx+dz*dz
                t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dz)/L)) if L else 0
                q = (a[0]+dx*t, a[1]+dz*t); dd = math.dist(p, q)
                if best is None or dd < best[0]:
                    best = (dd, q)
        return best[1]
    objectives = {}
    for name in ('Соборна вулиця', 'Спортивна вулиця', 'вулиця Ярослава Гомзи'):
        objectives[name] = [[round(v, 1) for v in foot((0, 0), street(name))]]

    # Sheet nomenclature of the 1:10 000 sheet holding the battlefield.
    def sheet(lat, lon):
        row = int((88-lat)//4)  # unused letter rows except M
        col = int((lon+180)//6)+1
        letter = chr(ord('A')+int(lat//4))
        mlat, mlon = lat-int(lat//4)*4, lon-((col-1)*6-180)
        n100 = int((4-mlat)//(1/3))*12+int(mlon//0.5)+1
        rlat, rlon = mlat % (1/3), mlon % 0.5
        q50 = 'АБВГ'[(0 if rlat >= 1/6 else 2)+(0 if rlon < 0.25 else 1)]
        rlat, rlon = rlat % (1/6), rlon % 0.25
        q25 = 'абвг'[(0 if rlat >= 1/12 else 2)+(0 if rlon < 0.125 else 1)]
        rlat, rlon = rlat % (1/12), rlon % 0.125
        q10 = str((0 if rlat >= 1/24 else 2)+(0 if rlon < 0.0625 else 1)+1)
        letter = {'L': 'L', 'M': 'М'}.get(letter, letter)
        return f'{letter}-{col}-{n100}', q50, q25, q10
    s100, s50, s25, s10 = sheet(ORIGIN_LAT, ORIGIN_LON)

    meta = {
        'source': 'OpenStreetMap contributors (ODbL 1.0), Overpass export; AWS Terrain Tiles / Mapzen terrarium z13 (SRTM-derived)',
        'origin': {'lat': ORIGIN_LAT, 'lon': ORIGIN_LON, 'easting': E0, 'northing': N0},
        'projection': 'Gauss-Kruger zone 7 (CM 39E), Krasovsky ellipsoid, WGS84 input without datum shift',
        'base_altitude': base,
        'relief': {'file': 'relief.bin', 'half': HALF, 'step': STEP, 'size': size},
        'sheet_10k': f'{s100}-{s50}-{s25}-{s10}', 'sheet_50k': f'{s100}-{s50}',
        'places': places, 'objectives': objectives,
        'convergence_deg': round(math.degrees((math.radians(ORIGIN_LON)-L0)*math.sin(math.radians(ORIGIN_LAT))), 3),
    }
    json.dump(meta, open(os.path.join(out_dir, 'meta.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    features = {'buildings': buildings, 'roads': roads, 'rails': rails, 'streams': streams,
                'water': [flat(p) for p in water], 'woods': [flat(p) for p in woods], 'rows': rows,
                'landuse': [[k, flat(p)] for k, p in landuse]}
    json.dump(features, open(os.path.join(out_dir, 'features.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('origin', E0, N0, 'base', base, 'relief', min(min(r) for r in relief)-base, max(max(r) for r in relief)-base)
    print('buildings', len(buildings), 'battle', sum(1 for b in buildings if inside((b[0], b[1]), BATTLE)),
          'roads', len(roads), 'rails', len(rails), 'woods', len(woods), 'rows', len(rows), 'water', len(water), 'landuse', len(landuse))
    print('trees', len(trees), 'by kind', [sum(1 for t in trees if t[2] == k) for k in range(3)])
    print('sheet', meta['sheet_10k'], 'objectives', objectives, 'convergence', meta['convergence_deg'])


if __name__ == '__main__':
    main(*sys.argv[1:4])
