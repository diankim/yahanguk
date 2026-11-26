from PIL import Image, ImageDraw, ImageFont
W,H=120,84
C=dict(bg=(0,0,0,0),hull=(122,78,44),hull2=(92,56,30),hl=(160,108,62),deck=(176,132,84),sail=(232,220,190),sail2=(205,190,155),bat=(140,112,80),
 mast=(98,64,36),red=(178,52,44),gold=(222,176,72),blue=(70,120,170),wat=(96,150,196),wat2=(150,196,228),roof=(70,60,58),win=(250,214,120),rope=(90,70,50),white=(245,240,230),cyan=(60,130,140))
def base():
    im=Image.new('RGBA',(W,H),C['bg']); return im,ImageDraw.Draw(im)
def water(d):
    pass
def water2(d):
    d.rectangle([0,69,W,H],fill=C['wat'])
    for x in range(0,W,6):
        d.line([(x,69),(x+3,68)],fill=C['wat2'])
def hull(d,x0,x1,y,h,bow=10,stern=6,col='hull'):
    d.polygon([(x0,y),(x1,y),(x1-bow,y+h),(x0+stern,y+h)],fill=C[col])
    d.line([(x0,y),(x1,y)],fill=C['hl']); d.line([(x0+stern,y+h),(x1-bow,y+h)],fill=C['hull2'])
    for yy in range(y+3,y+h,3): d.line([(x0+2+(yy-y)*stern//h,yy),(x1-2-(yy-y)*bow//h,yy)],fill=C['hull2'])
def sail(d,x,top,bot,w,battens=True,col='sail'):
    d.polygon([(x-w//2,top),(x+w//2,top+2),(x+w//2+2,bot),(x-w//2-2,bot)],fill=C[col])
    if battens:
        for yy in range(top+4,bot,4): d.line([(x-w//2-1,yy),(x+w//2+1,yy+1)],fill=C['bat'])
def mast(d,x,top,bot): d.line([(x,top),(x,bot)],fill=C['mast'],width=2)
def outline(im):
    px=im.load(); out=im.copy(); o=out.load()
    for y in range(H):
        for x in range(W):
            if px[x,y][3]==0:
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    xx,yy=x+dx,y+dy
                    if 0<=xx<W and 0<=yy<H and px[xx,yy][3] and px[xx,yy][:3] not in (C['wat'],C['wat2']):
                        o[x,y]=(26,18,14,255); break
    return out
def s1():
    im,d=base(); water(d); hull(d,34,86,62,9,bow=9,stern=7)
    d.line([(78,30),(66,76)],fill=C['mast'],width=1)  # 삿대
    d.rectangle([50,56,60,61],fill=C['deck']); return im
def s2():
    im,d=base(); water(d); hull(d,24,96,60,11,bow=12,stern=8)
    mast(d,60,26,60); sail(d,60,28,52,20)
    d.line([(30,56),(30,48)],fill=C['mast']); return im
def s3():
    im,d=base(); water(d); hull(d,16,104,58,13,bow=14,stern=9)
    mast(d,64,14,58); sail(d,64,16,50,30)
    d.rectangle([24,50,38,58],fill=C['roof']); d.rectangle([27,53,30,56],fill=C['win'])
    d.line([(64,14),(98,57)],fill=C['rope']); d.line([(64,14),(22,52)],fill=C['rope']); return im
def s4():
    im,d=base(); water(d); hull(d,8,112,58,14,bow=13,stern=10)
    d.rectangle([20,46,100,58],fill=C['deck'])  # 판옥
    for x in range(24,100,8): d.rectangle([x,49,x+3,53],fill=C['hull2'])
    d.rectangle([18,44,102,46],fill=C['red'])
    mast(d,46,12,46); sail(d,46,14,40,26); mast(d,76,16,46); sail(d,76,18,40,22)
    d.polygon([(52,36),(60,30),(68,36)],fill=C['roof']); return im
def s5():
    im,d=base(); water(d); hull(d,4,116,56,16,bow=14,stern=8)
    d.rectangle([14,44,104,56],fill=C['deck']); d.rectangle([12,42,106,44],fill=C['red'])
    d.rectangle([14,34,34,44],fill=C['deck']); d.polygon([(12,34),(24,28),(36,34)],fill=C['roof'])
    for x in (18,26): d.rectangle([x,37,x+3,40],fill=C['win'])
    for x in range(40,104,7): d.rectangle([x,47,x+3,51],fill=C['win'])
    mast(d,52,4,42); sail(d,52,6,34,26); mast(d,78,8,42); sail(d,78,10,34,24); mast(d,98,18,42); sail(d,98,20,36,14)
    d.polygon([(52,4),(52,0),(60,2)],fill=C['red']); d.polygon([(78,8),(78,4),(86,6)],fill=C['gold'])
    for x in (20,108): d.line([(x,44),(x,48)],fill=C['rope']); d.rectangle([x-1,48,x+1,51],fill=C['red'])
    d.line([(4,56),(0,50)],fill=C['mast']); return im
names=['나룻배','거룻배','돛배','판옥배','대양함선']
def wrap(f):
    im=f(); im=outline(im); water2(ImageDraw.Draw(im)); return im
ims=[wrap(f) for f in (s1,s2,s3,s4,s5)]
S=4; pad=20
sheet=Image.new('RGB',(pad+len(ims)*(W*S+pad),H*S+70),(24,24,30))
dr=ImageDraw.Draw(sheet)
try: font=ImageFont.truetype('/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',26)
except Exception: font=ImageFont.load_default()
for i,(im,n) in enumerate(zip(ims,names)):
    big=im.resize((W*S,H*S),Image.NEAREST); x=pad+i*(W*S+pad)
    sheet.paste(big,(x,20),big)
    dr.text((x+W*S//2-len(n)*13,H*S+30),f'{i+1}. {n}',fill=(230,220,200),font=font)
sheet.save('/home/user/yahanguk/supabase/gen_part2/ports/ships_mock.png')
print(sheet.size)
