"""Extract the CC0 MakeHuman hm08 head; input is an upstream base.obj.

Usage: python3 tools/build_character_head.py /path/to/base.obj /path/to/macrodetails
Source revision and license are recorded in assets/CHARACTER-CREDITS.md.
Only the visible head/neck surface is redistributed, not helper geometry.
"""
import json
import sys
from pathlib import Path

vertices, texcoords, faces = [], [], []
group = ''
for line in Path(sys.argv[1]).read_text().splitlines():
    parts = line.split()
    if not parts:
        continue
    if parts[0] == 'v':
        vertices.append(tuple(map(float, parts[1:4])))
    elif parts[0] == 'vt':
        u, v = map(float, parts[1:3])
        texcoords.append((u, 1-v))
    elif parts[0] == 'g':
        group = parts[1]
    elif parts[0] == 'f' and group == 'body':
        face = [tuple(int(i)-1 for i in value.split('/')[:2]) for value in parts[1:]]
        if min(vertices[i[0]][1] for i in face) >= 5.88:
            faces.append(face)

if len(sys.argv) > 2:
    for name in ['caucasian-male-young.target', 'universal-male-young-averagemuscle-averageweight.target']:
        for line in (Path(sys.argv[2])/name).read_text().splitlines():
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            index = int(parts[0])
            vertices[index] = tuple(a+float(b) for a,b in zip(vertices[index], parts[1:4]))
    # Preserve game neck pivot and overall height after the adult male morph.
    vertices = [(x,y-.809,z) for x,y,z in vertices]

used = sorted({index for face in faces for index in face})
mapping = {index: i for i, index in enumerate(used)}
points, uvs = [], []
for index, uv_index in used:
    x, y, z = vertices[index]
    # MakeHuman faces +Z; the game's skeleton faces -Z, with a neck pivot.
    points.append([round(x * .105, 6), round((y - 5.9) * .105, 6), round(-z * .105 + .015, 6)])
    uvs.append([round(value, 7) for value in texcoords[uv_index]])
triangles = []
for face in faces:
    # Godot uses clockwise front faces; flipping Z reverses OBJ winding.
    for i in range(1, len(face)-1):
        triangles.extend([mapping[face[0]], mapping[face[i]], mapping[face[i+1]]])
out = Path(__file__).resolve().parents[1] / 'assets/characters/head.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({'positions': points, 'uvs': uvs, 'indices': triangles}, separators=(',', ':')))
print(f'Head: {len(points)} vertices, {len(triangles)//3} triangles, {out.stat().st_size} bytes')
