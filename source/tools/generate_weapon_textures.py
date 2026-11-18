from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random, math
p=Path(__file__).resolve().parents[1]/'assets/textures/weapons';p.mkdir(parents=True,exist_ok=True)
r=random.Random(7416);n=512
for kind in ['metal','polymer','grip']:
    img=Image.new('L',(n,n));pix=img.load()
    for y in range(n):
        for x in range(n):
            grain=r.gauss(0,6 if kind=='metal' else 11)
            if kind=='grip':grain+=28*math.sin((x+y)*math.pi/7)*math.sin((x-y)*math.pi/7)
            pix[x,y]=max(0,min(255,int(185+grain)))
    if kind=='metal':
        d=ImageDraw.Draw(img)
        for i in range(110):
            x=r.randrange(n);y=r.randrange(n)
            d.line((x,y,x+r.randint(2,25),y+r.randint(-2,2)),fill=r.randint(196,225),width=1)
    img.save(p/(kind+'-albedo.png'))
    rough=img.point(lambda v:max(85,min(240,int((v-185)*.45+(145 if kind=='metal' else 200)))))
    rough.save(p/(kind+'-roughness.png'))
    h=img.filter(ImageFilter.GaussianBlur(.4));hp=h.load();normal=Image.new('RGB',(n,n));np=normal.load()
    for y in range(n):
        for x in range(n):
            dx=(hp[(x+1)%n,y]-hp[(x-1)%n,y])*.25
            dy=(hp[x,(y+1)%n]-hp[x,(y-1)%n])*.25
            np[x,y]=(int(128-dx),int(128+dy),254)
    normal.save(p/(kind+'-normal.png'))
