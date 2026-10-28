import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def canvas(n=32):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)

def save(img, name, scale=2):
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(os.path.join(OUT, name))

def outline(img, color=(20, 14, 28, 255)):
    """Tambah outline 1px gelap di sekeliling piksel solid."""
    w, h = img.size
    src = img.copy()
    px, dst = src.load(), img.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 200:
                        dst[x, y] = color
                        break
    return img

PINK = (240, 120, 170, 255)
PINK_D = (200, 80, 135, 255)
SKIN = (250, 215, 190, 255)
CLOAK = (68, 56, 98, 255)
CLOAK_D = (48, 40, 74, 255)
BELT = (150, 105, 70, 255)
WOOD = (115, 78, 48, 255)
STEEL = (205, 210, 225, 255)
BOOT = (34, 28, 42, 255)
LAMP = (255, 214, 96, 255)
EYE = (40, 28, 52, 255)

# ---------------------------------------------------------------- Mira
def mira(view):
    img, d = canvas()
    # kaki
    d.rectangle((12, 26, 14, 30), fill=CLOAK_D)
    d.rectangle((17, 26, 19, 30), fill=CLOAK_D)
    d.rectangle((11, 30, 14, 31), fill=BOOT)
    d.rectangle((17, 30, 20, 31), fill=BOOT)
    if view == "side":
        d.rectangle((13, 26, 18, 30), fill=CLOAK_D)
        d.rectangle((12, 30, 19, 31), fill=BOOT)
    # badan
    d.polygon([(12, 15), (20, 15), (23, 27), (9, 27)], fill=CLOAK)
    d.polygon([(12, 15), (20, 15), (21, 18), (11, 18)], fill=CLOAK_D)
    d.rectangle((11, 21, 21, 22), fill=BELT)
    if view == "side":
        d.polygon([(13, 15), (19, 15), (21, 27), (11, 27)], fill=CLOAK)
        d.rectangle((12, 21, 20, 22), fill=BELT)
    # rambut belakang
    if view == "back":
        d.ellipse((9, 3, 23, 20), fill=PINK)
        d.rectangle((10, 12, 22, 19), fill=PINK)
        d.line((16, 6, 16, 18), fill=PINK_D)
    elif view == "front":
        d.rectangle((9, 8, 11, 18), fill=PINK)
        d.rectangle((21, 8, 23, 18), fill=PINK)
    else:
        d.rectangle((9, 8, 14, 19), fill=PINK)
    # kepala
    if view == "back":
        pass
    elif view == "front":
        d.ellipse((10, 3, 22, 16), fill=PINK)
        d.ellipse((11, 7, 21, 16), fill=SKIN)
        d.polygon([(10, 7), (22, 7), (20, 5), (12, 5)], fill=PINK)
        d.rectangle((12, 6, 14, 9), fill=PINK)
        d.rectangle((18, 6, 20, 9), fill=PINK)
        d.rectangle((13, 11, 14, 12), fill=EYE)
        d.rectangle((18, 11, 19, 12), fill=EYE)
        d.point((16, 14), fill=(200, 110, 110, 255))
    else:
        d.ellipse((9, 3, 22, 16), fill=PINK)
        d.ellipse((13, 7, 22, 16), fill=SKIN)
        d.polygon([(9, 6), (22, 6), (21, 4), (11, 3)], fill=PINK)
        d.rectangle((13, 6, 16, 9), fill=PINK)
        d.rectangle((19, 11, 20, 12), fill=EYE)
    # lentera di pinggang
    if view == "front":
        d.rectangle((22, 21, 25, 25), fill=LAMP)
        d.rectangle((22, 20, 25, 20), fill=BELT)
    elif view == "back":
        d.rectangle((7, 21, 10, 25), fill=LAMP)
        d.rectangle((7, 20, 10, 20), fill=BELT)
    else:
        d.rectangle((9, 21, 12, 25), fill=LAMP)
    # sabit
    if view == "front":
        d.line((26, 31, 26, 7), fill=WOOD, width=2)
        d.polygon([(26, 5), (31, 7), (30, 11), (27, 8), (25, 8)], fill=STEEL)
    elif view == "back":
        d.line((6, 31, 6, 7), fill=WOOD, width=2)
        d.polygon([(6, 5), (1, 7), (2, 11), (5, 8), (7, 8)], fill=STEEL)
    else:
        d.line((24, 29, 27, 8), fill=WOOD, width=2)
        d.polygon([(27, 6), (31, 9), (30, 12), (27, 9), (25, 9)], fill=STEEL)
    outline(img)
    return img

for v, n in (("front", "mira_front.png"), ("back", "mira_back.png"), ("side", "mira_side.png")):
    save(mira(v), n)

# ------------------------------------------------------------ Portrait
def portrait(expr):
    img, d = canvas()
    d.ellipse((4, 3, 28, 32), fill=PINK)
    d.rectangle((4, 15, 9, 31), fill=PINK)
    d.rectangle((23, 15, 28, 31), fill=PINK)
    d.ellipse((8, 8, 24, 28), fill=SKIN)
    d.polygon([(7, 14), (25, 14), (22, 6), (10, 6)], fill=PINK)
    d.polygon([(8, 14), (14, 9), (16, 14)], fill=PINK_D)
    d.polygon([(24, 14), (18, 9), (16, 14)], fill=PINK)
    if expr == "normal":
        d.rectangle((11, 17, 13, 20), fill=EYE)
        d.rectangle((19, 17, 21, 20), fill=EYE)
        d.line((14, 24, 18, 24), fill=(190, 100, 100, 255))
    elif expr == "hurt":
        d.line((10, 16, 13, 18), fill=EYE)
        d.line((10, 20, 13, 18), fill=EYE)
        d.line((22, 16, 19, 18), fill=EYE)
        d.line((22, 20, 19, 18), fill=EYE)
        d.line((14, 25, 18, 24), fill=(190, 100, 100, 255))
        d.rectangle((20, 22, 22, 23), fill=(220, 60, 70, 255))
        d.rectangle((9, 22, 10, 23), fill=(220, 60, 70, 255))
    else:  # angry
        d.line((10, 15, 14, 17), fill=EYE, width=1)
        d.line((22, 15, 18, 17), fill=EYE, width=1)
        d.rectangle((11, 18, 13, 20), fill=EYE)
        d.rectangle((19, 18, 21, 20), fill=EYE)
        d.line((13, 25, 19, 25), fill=(190, 80, 80, 255))
        d.point((13, 24), fill=(190, 80, 80, 255))
        d.point((19, 24), fill=(190, 80, 80, 255))
    outline(img)
    return img

for e in ("normal", "hurt", "angry"):
    save(portrait(e), f"portrait_mira_{e}.png")

# ---------------------------------------------------------------- Slime
def slime():
    img, d = canvas()
    G, GD, GL = (112, 192, 82, 255), (66, 132, 62, 255), (170, 230, 130, 255)
    d.ellipse((4, 13, 28, 31), fill=G)
    d.rectangle((4, 22, 28, 30), fill=G)
    d.ellipse((6, 11, 26, 24), fill=G)
    d.ellipse((8, 14, 14, 18), fill=GL)
    d.rectangle((5, 27, 27, 30), fill=GD)
    d.ellipse((17, 22, 23, 27), fill=GD)
    # lumut di atas
    for x, y in ((11, 10), (16, 9), (21, 11), (14, 8)):
        d.rectangle((x, y, x + 2, y + 2), fill=(52, 110, 52, 255))
    # mata
    d.ellipse((9, 18, 14, 24), fill=(250, 250, 250, 255))
    d.ellipse((18, 18, 23, 24), fill=(250, 250, 250, 255))
    d.rectangle((12, 20, 13, 23), fill=EYE)
    d.rectangle((21, 20, 22, 23), fill=EYE)
    outline(img)
    return img

save(slime(), "slime_lumut.png")

# ---------------------------------------------------------------- Tikus
def rat():
    img, d = canvas()
    B, BD = (125, 112, 112, 255), (88, 76, 80, 255)
    PK = (232, 160, 170, 255)
    d.line((6, 25, 3, 21), fill=PK, width=1)
    d.line((3, 21, 1, 22), fill=PK, width=1)
    d.line((3, 21, 2, 17), fill=PK, width=1)
    d.ellipse((5, 15, 23, 28), fill=B)
    d.rectangle((6, 22, 22, 27), fill=B)
    d.ellipse((18, 14, 28, 25), fill=B)
    d.polygon([(26, 17), (31, 22), (25, 24)], fill=B)
    d.point((31, 22), fill=PK)
    d.ellipse((19, 10, 24, 16), fill=PK)
    d.ellipse((20, 11, 23, 15), fill=BD)
    d.rectangle((24, 17, 25, 18), fill=(235, 40, 50, 255))
    d.rectangle((8, 27, 10, 30), fill=BD)
    d.rectangle((18, 27, 20, 30), fill=BD)
    d.line((9, 19, 18, 19), fill=BD)
    # taring
    d.rectangle((24, 20, 24, 20), fill=(240, 240, 240, 255))
    outline(img)
    return img

save(rat(), "tikus_gerogot.png")

# ---------------------------------------------------------------- Pip
def pip():
    img, d = canvas(32)
    d.ellipse((4, 4, 27, 27), fill=(255, 235, 160, 255))
    d.ellipse((7, 7, 24, 24), fill=(255, 250, 215, 255))
    d.rectangle((11, 9, 20, 23), fill=(255, 224, 120, 255))
    d.rectangle((10, 8, 21, 9), fill=(150, 108, 60, 255))
    d.rectangle((10, 23, 21, 24), fill=(150, 108, 60, 255))
    d.line((12, 9, 12, 23), fill=(150, 108, 60, 255))
    d.line((19, 9, 19, 23), fill=(150, 108, 60, 255))
    d.arc((11, 2, 20, 9), 180, 360, fill=(150, 108, 60, 255))
    d.rectangle((13, 14, 14, 16), fill=EYE)
    d.rectangle((17, 14, 18, 16), fill=EYE)
    d.line((14, 19, 17, 19), fill=(200, 110, 90, 255))
    return img

save(pip(), "pip.png")

# ---------------------------------------------------------------- Soul orb
def orb():
    img, d = canvas(32)
    d.ellipse((4, 4, 27, 27), fill=(120, 90, 235, 255))
    d.ellipse((7, 7, 24, 24), fill=(150, 200, 255, 255))
    d.ellipse((11, 11, 20, 20), fill=(225, 245, 255, 255))
    d.ellipse((14, 13, 17, 16), fill=(255, 255, 255, 255))
    return img

save(orb(), "soul_orb.png")

# ---------------------------------------------------------------- Old Bram
def bram():
    img, d = canvas()
    ROBE, ROBE_D = (110, 98, 74, 255), (78, 70, 52, 255)
    d.rectangle((12, 28, 15, 31), fill=BOOT)
    d.rectangle((17, 28, 20, 31), fill=BOOT)
    d.polygon([(11, 14), (21, 14), (24, 29), (8, 29)], fill=ROBE)
    d.polygon([(8, 25), (24, 25), (24, 29), (8, 29)], fill=ROBE_D)
    d.rectangle((10, 20, 22, 21), fill=BELT)
    for x, y in ((12, 24), (18, 26), (14, 17)):
        d.rectangle((x, y, x + 1, y + 1), fill=(60, 110, 60, 255))
    d.rectangle((10, 18, 14, 22), fill=(200, 40, 40, 255))  # luka
    d.ellipse((11, 3, 21, 14), fill=SKIN)
    d.polygon([(11, 9), (21, 9), (20, 20), (16, 22), (12, 20)], fill=(190, 190, 195, 255))
    d.ellipse((11, 2, 21, 8), fill=(170, 170, 178, 255))
    d.rectangle((13, 8, 14, 9), fill=EYE)
    d.rectangle((18, 8, 19, 9), fill=EYE)
    d.line((26, 31, 26, 8), fill=WOOD, width=2)
    d.ellipse((24, 5, 28, 9), fill=(150, 108, 60, 255))
    outline(img)
    return img

save(bram(), "old_bram.png")

# ---------------------------------------------------------------- Hati
HEART = [
    ".XX..XX.",
    "XXXXXXXX",
    "XXXXXXXX",
    "XXXXXXXX",
    ".XXXXXX.",
    "..XXXX..",
    "...XX...",
    "........",
]

def heart(kind):
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    p = img.load()
    for y, row in enumerate(HEART):
        for x, c in enumerate(row):
            if c != "X":
                continue
            if kind == "full":
                p[x, y] = (230, 50, 80, 255)
            elif kind == "half":
                p[x, y] = (230, 50, 80, 255) if x < 4 else (62, 40, 56, 255)
            else:
                p[x, y] = (62, 40, 56, 255)
    outline(img, (18, 10, 20, 255))
    return img

for k in ("full", "half", "empty"):
    save(heart(k).resize((10, 10), Image.NEAREST) if False else heart(k), f"heart_{k}.png", scale=3)

# ---------------------------------------------------------------- Shard
def shard():
    img, d = canvas(16)
    d.polygon([(8, 1), (13, 8), (8, 15), (3, 8)], fill=(110, 220, 255, 255))
    d.polygon([(8, 1), (13, 8), (8, 8)], fill=(190, 245, 255, 255))
    outline(img)
    return img

save(shard(), "shard.png", scale=2)

# ---------------------------------------------------------------- Tanah
def ground():
    n = 64
    img = Image.new("RGBA", (n, n), (150, 136, 116, 255))
    p = img.load()
    for y in range(0, n, 2):
        for x in range(0, n, 2):
            v = random.randint(-14, 14)
            r, g, b = 150 + v, 136 + v, 116 + v
            for dy in range(2):
                for dx in range(2):
                    p[x + dx, y + dy] = (r, g, b, 255)
    for _ in range(40):
        x, y = random.randrange(n - 3), random.randrange(n - 3)
        c = random.choice([(112, 100, 84), (170, 156, 134), (132, 150, 100)])
        w = random.choice([1, 2, 3])
        for dy in range(w):
            for dx in range(w):
                p[x + dx, y + dy] = c + (255,)
    img.save(os.path.join(OUT, "ground.png"))

ground()
print("OK", sorted(os.listdir(OUT)))
