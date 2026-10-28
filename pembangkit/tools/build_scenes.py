import math, os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = "res://assets/sprites/"
HW, HD, GATE_HALF, CORRIDOR, SPACING = 13.0, 9.0, 3.0, 8.0, 34.0

WOOD = (0.38, 0.24, 0.14, 1)
WOOD_D = (0.27, 0.17, 0.1, 1)
STONE = (0.5, 0.52, 0.6, 1)


# ------------------------------------------------------------ serializer
class Raw:
    def __init__(self, s): self.s = s


def fn(v):
    t = f"{v:.6f}".rstrip("0").rstrip(".")
    return "0" if t in ("-0", "") else t


def V3(x, y, z): return Raw(f"Vector3({fn(x)}, {fn(y)}, {fn(z)})")
def V2(x, y): return Raw(f"Vector2({fn(x)}, {fn(y)})")
def Col(r, g, b, a=1.0): return Raw(f"Color({fn(r)}, {fn(g)}, {fn(b)}, {fn(a)})")


def ser(v):
    if isinstance(v, Raw): return v.s
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return fn(v)
    if isinstance(v, str): return '"' + v.replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)): return "[" + ", ".join(ser(x) for x in v) + "]"
    raise ValueError(v)


def XF(pos=(0, 0, 0), rot=None, scale=(1, 1, 1)):
    R = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    if rot:
        ax, a = rot
        c, s = math.cos(a), math.sin(a)
        if ax == "y": R = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
        elif ax == "x": R = [[1, 0, 0], [0, c, -s], [0, s, c]]
        else: R = [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    B = [[R[i][j] * scale[j] for j in range(3)] for i in range(3)]
    flat = [B[i][j] for i in range(3) for j in range(3)]
    return Raw("Transform3D(" + ", ".join(fn(x) for x in flat) + ", " + ", ".join(fn(x) for x in pos) + ")")


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def euler_xf(pos, rx=0.0, ry=0.0):
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    B = matmul(Ry, Rx)
    flat = [B[i][j] for i in range(3) for j in range(3)]
    return Raw("Transform3D(" + ", ".join(fn(x) for x in flat) + ", " + ", ".join(fn(x) for x in pos) + ")")


# ------------------------------------------------------------ scene writer
class Scene:
    def __init__(self, root_name, root_type="Node3D", props=None, script=None):
        self.ext, self.ext_list = {}, []
        self.subs, self.sub_cache = [], {}
        self.nodes = []
        self.counter = {}
        self.names = {}
        root_props = dict(props or {})
        if script:
            root_props["script"] = self.ext_res("Script", script)
        self.nodes.append((root_name, root_type, None, root_props, None, None))

    def ext_res(self, typ, path):
        if path not in self.ext:
            i = str(len(self.ext) + 1)
            self.ext[path] = i
            self.ext_list.append((i, typ, path))
        return Raw(f'ExtResource("{self.ext[path]}")')

    def sub(self, typ, props, unique=False):
        key = (typ, tuple((k, ser(v)) for k, v in props.items()))
        if not unique and key in self.sub_cache:
            return self.sub_cache[key]
        sid = f"{typ}_{len(self.subs) + 1}"
        self.subs.append((sid, typ, props))
        ref = Raw(f'SubResource("{sid}")')
        if not unique:
            self.sub_cache[key] = ref
        return ref

    def add(self, name, typ, parent=".", props=None, instance=None, groups=None):
        full = name if parent == "." else f"{parent}/{name}"
        # nama unik per parent
        k = (parent, name)
        if k in self.names:
            self.names[k] += 1
            name = f"{name}{self.names[k]}"
            full = name if parent == "." else f"{parent}/{name}"
        else:
            self.names[k] = 0
        self.nodes.append((name, typ, parent, dict(props or {}), instance, groups))
        return full

    def write(self, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out = [f"[gd_scene load_steps={len(self.ext_list) + len(self.subs) + 1} format=3]\n"]
        for i, t, p in self.ext_list:
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        out.append("")
        for sid, t, props in self.subs:
            out.append(f'[sub_resource type="{t}" id="{sid}"]')
            for k, v in props.items():
                out.append(f"{k} = {ser(v)}")
            out.append("")
        for name, typ, parent, props, inst, groups in self.nodes:
            head = f'[node name="{name}"'
            if typ and not inst: head += f' type="{typ}"'
            if parent is not None: head += f' parent="{parent}"'
            if inst: head += f" instance={ser(inst)}"
            if groups: head += " groups=[" + ", ".join(ser(g) for g in groups) + "]"
            out.append(head + "]")
            for k, v in props.items():
                out.append(f"{k} = {ser(v)}")
            out.append("")
        open(path, "w").write("\n".join(out))


# ------------------------------------------------------------ helper geometri
def mat(sc, color, emissive=False, transparent=False, unshaded=False, unique=False, cull_off=False):
    p = {"albedo_color": Col(*color), "roughness": 0.9}
    if emissive:
        p["emission_enabled"] = True
        p["emission"] = Col(color[0], color[1], color[2], 1.0)
        p["emission_energy_multiplier"] = 1.6
    if transparent: p["transparency"] = 1
    if unshaded: p["shading_mode"] = 0
    if cull_off: p["cull_mode"] = 2
    return sc.sub("StandardMaterial3D", p, unique)


def meshnode(sc, parent, name, mesh, material, pos=(0, 0, 0), rot=None, shadow=True):
    p = {"mesh": mesh, "material_override": material}
    if pos != (0, 0, 0) or rot: p["transform"] = XF(pos, rot)
    if not shadow: p["cast_shadow"] = 0
    return sc.add(name, "MeshInstance3D", parent, p)


def box(sc, parent, name, size, pos, color, rot=None, **mk):
    m = sc.sub("BoxMesh", {"size": V3(*size)})
    return meshnode(sc, parent, name, m, mat(sc, color, **mk), pos, rot, shadow=not mk.get("unshaded", False))


def cyl(sc, parent, name, rt, rb, h, pos, color, seg=12, rot=None, **mk):
    m = sc.sub("CylinderMesh", {"top_radius": rt, "bottom_radius": rb, "height": h, "radial_segments": seg})
    return meshnode(sc, parent, name, m, mat(sc, color, **mk), pos, rot, shadow=not mk.get("unshaded", False))


def box_col(sc, parent, name, size, pos):
    b = sc.add(name, "StaticBody3D", parent, {"transform": XF(pos), "collision_layer": 1, "collision_mask": 0})
    sc.add("Shape", "CollisionShape3D", b, {"shape": sc.sub("BoxShape3D", {"size": V3(*size)})})
    return b


def cyl_col(sc, parent, name, radius, height, pos):
    b = sc.add(name, "StaticBody3D", parent, {"transform": XF(pos), "collision_layer": 1, "collision_mask": 0})
    sc.add("Shape", "CollisionShape3D", b, {"shape": sc.sub("CylinderShape3D", {"radius": radius, "height": height})})
    return b


def omni(sc, parent, name, pos, color, energy, rng, flicker=False):
    return sc.add(name, "OmniLight3D", parent,
                  {"transform": XF(pos), "light_color": Col(*color), "light_energy": energy, "omni_range": rng},
                  groups=["flicker"] if flicker else None)


def label(sc, parent, name, text, pos, size=48, color=(1, 0.95, 0.75)):
    return sc.add(name, "Label3D", parent, {
        "transform": XF(pos), "billboard": 1, "no_depth_test": True, "modulate": Col(*color),
        "outline_size": 12, "text": text, "font_size": size, "pixel_size": 0.01})


def flame(sc, parent, name, pos, s):
    g = sc.add(name, "Node3D", parent, {"transform": XF(pos)})
    cyl(sc, g, "Cone", 0.0, 0.5 * s, 1.5 * s, (0, 0.75 * s, 0), (1.0, 0.5, 0.12, 1), emissive=True, unshaded=True)
    cyl(sc, g, "Core", 0.0, 0.3 * s, 1.0 * s, (0, 0.5 * s, 0), (1.0, 0.9, 0.4, 1), emissive=True, unshaded=True)
    omni(sc, g, "Light", (0, 1.2, 1.0), (1.0, 0.55, 0.2), 2.2, 9.0, True)


# ------------------------------------------------------------ PROP SCENES
def make_house(fname, size, burned, wall):
    sx, sy, sz = size
    sc = Scene("House")
    wc = (0.17, 0.13, 0.11, 1) if burned else wall
    box(sc, ".", "Walls", size, (0, sy / 2, 0), wc)
    box_col(sc, ".", "Collider", size, (0, sy / 2, 0))
    roof = sc.sub("PrismMesh", {"size": V3(sx + 0.8, 1.7, sz + 0.6)})
    meshnode(sc, ".", "Roof", roof, mat(sc, (0.14, 0.11, 0.11, 1) if burned else (0.5, 0.22, 0.17, 1)), (0, sy + 0.85, 0))
    fz = sz / 2 + 0.05
    box(sc, ".", "Door", (1.0, 1.7, 0.12), (0, 0.85, fz), (0.2, 0.12, 0.07, 1))
    if not burned:
        for i, wx in enumerate((-0.3, 0.3)):
            box(sc, ".", f"Window{i + 1}", (0.8, 0.8, 0.12), (sx * wx, 1.6, fz), (1.0, 0.7, 0.3, 1), emissive=True, unshaded=True)
        omni(sc, ".", "WindowLight", (0, 1.6, fz + 1.2), (1.0, 0.7, 0.35), 0.8, 5.0, True)
    else:
        flame(sc, ".", "RoofFlame1", (-sx * 0.25, sy + 1.2, 0), 1.4)
        flame(sc, ".", "RoofFlame2", (sx * 0.3, sy + 0.2, sz * 0.2), 1.0)
    sc.write(fname)


def make_props():
    make_house("scenes/props/house.tscn", (5.0, 2.8, 3.6), False, (0.5, 0.36, 0.24, 1))
    make_house("scenes/props/house_burned.tscn", (5.0, 2.8, 3.6), True, (1, 1, 1, 1))
    make_house("scenes/props/barn.tscn", (7.0, 3.4, 3.6), False, (0.55, 0.22, 0.18, 1))

    sc = Scene("Well")
    cyl(sc, ".", "Rim", 0.95, 1.0, 1.0, (0, 0.5, 0), (0.5, 0.5, 0.55, 1), 14)
    cyl(sc, ".", "Water", 0.7, 0.7, 0.06, (0, 0.98, 0), (0.05, 0.12, 0.22, 1), 14)
    box(sc, ".", "PostL", (0.2, 2.2, 0.2), (-0.95, 1.1, 0), WOOD)
    box(sc, ".", "PostR", (0.2, 2.2, 0.2), (0.95, 1.1, 0), WOOD)
    box(sc, ".", "Beam", (2.4, 0.2, 0.3), (0, 2.3, 0), WOOD_D)
    cyl_col(sc, ".", "Collider", 1.0, 2.0, (0, 1.0, 0))
    sc.write("scenes/props/well.tscn")

    for fname, broken in (("cart", False), ("cart_broken", True)):
        sc = Scene("Cart")
        box(sc, ".", "Bed", (2.4, 0.5, 1.3), (0, 0.75, 0), WOOD, rot=("z", 0.18) if broken else None)
        for i, z in enumerate((-0.65, 0.65)):
            cyl(sc, ".", f"Wheel{i + 1}", 0.45, 0.45, 0.12, (0, 0.45, z), WOOD_D, 10, rot=("x", math.pi / 2))
        box(sc, ".", "Cargo", (1.0, 0.6, 0.9), (0.4, 1.3, 0), (0.55, 0.45, 0.2, 1))
        box_col(sc, ".", "Collider", (2.4, 1.4, 1.5), (0, 0.7, 0))
        sc.write(f"scenes/props/{fname}.tscn")

    for s in (0.8, 1.0, 1.1):
        sc = Scene("Crate")
        box(sc, ".", "Box", (s, s, s), (0, s / 2, 0), (0.45, 0.3, 0.17, 1))
        box_col(sc, ".", "Collider", (s, s, s), (0, s / 2, 0))
        sc.write(f"scenes/props/crate_{int(s * 100):03d}.tscn")

    sc = Scene("HayBale")
    cyl(sc, ".", "Bale", 0.65, 0.65, 1.0, (0, 0.65, 0), (0.78, 0.65, 0.28, 1), 12, rot=("z", math.pi / 2))
    box_col(sc, ".", "Collider", (1.0, 1.3, 1.3), (0, 0.65, 0))
    sc.write("scenes/props/hay_bale.tscn")

    sc = Scene("Torch")
    cyl(sc, ".", "Post", 0.07, 0.09, 2.0, (0, 1.0, 0), WOOD, 8)
    cyl(sc, ".", "Flame", 0.0, 0.18, 0.5, (0, 2.2, 0), (1.0, 0.6, 0.15, 1), 8, emissive=True, unshaded=True)
    omni(sc, ".", "Light", (0, 2.6, 0), (1.0, 0.62, 0.3), 2.0, 8.0, True)
    sc.write("scenes/props/torch.tscn")

    sc = Scene("GardenBed")
    box(sc, ".", "Soil", (3.2, 0.35, 1.1), (0, 0.17, 0), (0.3, 0.2, 0.12, 1))
    for k in range(5):
        box(sc, ".", f"Cabbage{k + 1}", (0.42, 0.38, 0.42), (-1.2 + k * 0.6, 0.5, 0), (0.32, 0.62, 0.28, 1))
    sc.write("scenes/props/garden_bed.tscn")

    sc = Scene("Scarecrow")
    cyl(sc, ".", "Pole", 0.06, 0.06, 2.2, (0, 1.1, 0), WOOD, 8)
    box(sc, ".", "Arms", (1.6, 0.1, 0.1), (0, 1.6, 0), WOOD)
    cyl(sc, ".", "Head", 0.22, 0.22, 0.4, (0, 2.3, 0), (0.8, 0.68, 0.4, 1), 8)
    cyl(sc, ".", "Hat", 0.0, 0.4, 0.45, (0, 2.65, 0), (0.3, 0.2, 0.12, 1), 8)
    box(sc, ".", "Body", (0.7, 0.9, 0.2), (0, 1.3, 0), (0.5, 0.3, 0.25, 1))
    sc.write("scenes/props/scarecrow.tscn")

    sc = Scene("Pillar")
    h = 4.6
    box(sc, ".", "Shaft", (2.4, h, 2.4), (0, h / 2, 0), STONE)
    box(sc, ".", "Cap", (2.9, 0.4, 2.9), (0, h + 0.2, 0), (0.42, 0.44, 0.52, 1))
    box(sc, ".", "Banner", (1.0, 2.0, 0.08), (0, 2.6, 1.28), (0.45, 0.1, 0.25, 1))
    box(sc, ".", "BannerRod", (1.2, 0.1, 0.12), (0, 3.65, 1.28), WOOD_D)
    box_col(sc, ".", "Collider", (2.4, h, 2.4), (0, h / 2, 0))
    sc.write("scenes/props/pillar.tscn")

    sc = Scene("Tree")
    cyl(sc, ".", "Trunk", 0.22, 0.3, 1.4, (0, 0.7, 0), (0.22, 0.14, 0.09, 1), 6)
    for k in range(3):
        sck = 1.0 - 0.22 * k
        sc.add(f"Leaves{k + 1}", "MeshInstance3D", ".", {
            "transform": XF((0, 1.6 + 1.5 * k, 0), None, (sck, sck, sck)),
            "mesh": sc.sub("CylinderMesh", {"top_radius": 0.0, "bottom_radius": 1.3, "height": 3.2, "radial_segments": 8}),
            "material_override": mat(sc, (0.1, 0.26, 0.2, 1) if k % 2 == 0 else (0.13, 0.32, 0.24, 1))})
    sc.write("scenes/props/tree.tscn")

    # gerbang: Body (collider), Pivot (papan yang roboh), Mist (segel ungu)
    sc = Scene("Gate")
    box_col(sc, ".", "Body", (0.9, 3.0, GATE_HALF * 2 + 0.4), (0, 1.5, 0))
    sc.add("Pivot", "Node3D", ".")
    for k in range(7):
        box(sc, "Pivot", f"Plank{k + 1}", (0.3, 2.5, 0.55), (0, 1.25, -2.7 + k * 0.9), (0.36, 0.23, 0.13, 1))
    box(sc, "Pivot", "RailLow", (0.36, 0.2, 6.3), (0, 0.6, 0), WOOD_D)
    box(sc, "Pivot", "RailHigh", (0.36, 0.2, 6.3), (0, 1.9, 0), WOOD_D)
    box(sc, ".", "Mist", (0.25, 3.4, GATE_HALF * 2 + 0.4), (0, 1.7, 0), (0.6, 0.3, 1.0, 0.38),
        emissive=True, transparent=True, unshaded=True)
    omni(sc, ".", "GateLight", (-1.0, 2.0, 0), (0.65, 0.35, 1.0), 1.4, 7.0, True)
    sc.write("scenes/props/gate.tscn")

    # papan developer: muncul setelah Area 1 selesai, E untuk membuka identitas tim
    sc = Scene("DevSign", script="res://scripts/dev_sign.gd")
    box_col(sc, ".", "Body", (2.6, 2.3, 0.5), (0, 1.15, 0))
    for sx in (-1.15, 1.15):
        box(sc, ".", "Post", (0.2, 2.5, 0.2), (sx, 1.25, -0.02), WOOD_D)
    box(sc, ".", "Frame", (2.62, 1.82, 0.1), (0, 1.9, -0.02), WOOD_D)
    box(sc, ".", "Board", (2.5, 1.7, 0.12), (0, 1.9, 0), WOOD)
    sc.add("Photo", "Sprite3D", ".", {
        "transform": XF((0, 1.9, 0.07)), "pixel_size": 2.2 / 1264.0, "texture_filter": 0,
        "texture": sc.ext_res("Texture2D", SPR + "dev_team.jpg")})
    label(sc, ".", "Title", "PAPAN DEVELOPER", (0, 3.2, 0), 36, (1.0, 0.85, 0.5))
    pr = label(sc, ".", "Prompt", "[E]  Lihat papan developer", (0, 3.5, 0), 40, (0.8, 1.0, 0.9))
    sc.nodes[-1][3]["visible"] = False
    omni(sc, ".", "SignLight", (0, 2.4, 1.4), (1.0, 0.85, 0.55), 1.0, 5.0, True)
    zone = sc.add("Zone", "Area3D", ".", {"transform": XF((0, 1.0, 0.9)), "collision_layer": 0, "collision_mask": 2})
    sc.add("Shape", "CollisionShape3D", zone, {"shape": sc.sub("SphereShape3D", {"radius": 2.8})})
    sc.write("scenes/props/dev_sign.tscn")

    sc = Scene("OldBram")
    sc.add("Sprite", "Sprite3D", ".", {
        "transform": XF((0, 1.05, 0)), "pixel_size": 2.1 / 64.0, "billboard": 2, "double_sided": True,
        "alpha_cut": 1, "texture_filter": 0, "texture": sc.ext_res("Texture2D", SPR + "old_bram.png")})
    cyl(sc, ".", "Shadow", 0.6, 0.6, 0.02, (0, 0.02, 0), (0, 0, 0, 0.35), 24, transparent=True, unshaded=True)
    label(sc, ".", "Name", "Old Bram", (0, 2.5, 0), 34, (0.9, 0.85, 0.6))
    sc.write("scenes/characters/old_bram.tscn")


# ------------------------------------------------------------ KARAKTER / MUSUH
def sprite_node(sc, parent, name, tex, world_h, px, y, billboard=2, shaded=True, modulate=None):
    p = {"transform": XF((0, y, 0)), "pixel_size": world_h / px, "billboard": billboard, "double_sided": True,
         "alpha_cut": 1, "texture_filter": 0, "texture": sc.ext_res("Texture2D", SPR + tex)}
    if not shaded: p["shaded"] = False
    if modulate: p["modulate"] = Col(*modulate)
    return sc.add(name, "Sprite3D", parent, p)


def capsule(sc, radius, height):
    sc.add("Shape", "CollisionShape3D", ".", {"transform": XF((0, height / 2, 0)),
           "shape": sc.sub("CapsuleShape3D", {"radius": radius, "height": height})})


def blob(sc, name, radius):
    cyl(sc, ".", name, radius, radius, 0.02, (0, 0.02, 0), (0, 0, 0, 0.35), 24, transparent=True, unshaded=True)


ENEMIES = {  # id: (tekstur, tinggi sprite, radius badan)
    "slime_lumut": ("slime_lumut.png", 1.9, 0.55),
    "tikus_gerogot": ("tikus_gerogot.png", 1.5, 0.4),
}


def make_characters():
    # Mira
    sc = Scene("Mira", "CharacterBody3D", script="res://scripts/player.gd")
    capsule(sc, 0.4, 1.6)
    sc.nodes[-1][3]["transform"] = XF((0, 0.9, 0))
    sprite_node(sc, ".", "Sprite", "mira_front.png", 2.1, 64, 1.05)
    blob(sc, "Shadow", 0.6)
    omni(sc, ".", "Light", (0, 2.4, 0.6), (1.0, 0.8, 0.55), 1.1, 8.0)
    sc.write("scenes/characters/mira.tscn")

    # Pip
    sc = Scene("Pip", "Node3D", script="res://scripts/pip.gd")
    sprite_node(sc, ".", "Sprite", "pip.png", 1.0, 64, 0.0, billboard=1, shaded=False)
    omni(sc, ".", "Light", (0, 0, 0), (1.0, 0.92, 0.6), 1.6, 9.0)
    sc.write("scenes/characters/pip.tscn")

    for eid, fname, root in (("slime_lumut", "slime_lumut", "SlimeLumut"), ("tikus_gerogot", "tikus_gerogot", "TikusGerogot")):
        tex, h, r = ENEMIES[eid]
        ch = max(1.0, r * 2.4)
        # musuh
        sc = Scene(root, "CharacterBody3D", script="res://scripts/enemy.gd")
        sc.nodes[0][3]["data"] = sc.ext_res("Resource", f"res://data/enemies/{eid}.tres")
        capsule(sc, r, ch)
        sprite_node(sc, ".", "Sprite", tex, h, 64, h / 2)
        blob(sc, "Shadow", r * 1.3)
        sc.write(f"scenes/enemies/{fname}.tscn")
        # shade
        shade_name = "shade_slime" if eid == "slime_lumut" else "shade_tikus"
        sc = Scene("Shade" + root, "CharacterBody3D", script="res://scripts/shade.gd")
        sc.nodes[0][3]["data"] = sc.ext_res("Resource", f"res://data/enemies/{eid}.tres")
        capsule(sc, r, ch)
        sprite_node(sc, ".", "Sprite", tex, h, 64, h / 2 + 0.12, shaded=False, modulate=(0.55, 0.6, 1.5, 1.0))
        cyl(sc, ".", "Ring", r * 1.5, r * 1.5, 0.02, (0, 0.04, 0), (0.55, 0.4, 1.0, 0.55), 24,
            emissive=True, transparent=True, unshaded=True)
        omni(sc, ".", "Aura", (0, 1.0, 0), (0.5, 0.45, 1.0), 1.0, 4.0)
        sc.write(f"scenes/enemies/{shade_name}.tscn")

    # Soul Orb
    sc = Scene("SoulOrb", "Node3D", script="res://scripts/soul_orb.gd")
    sc.nodes[0][3]["data"] = sc.ext_res("Resource", "res://data/enemies/slime_lumut.tres")
    sc.nodes[0][3]["forced"] = True
    sprite_node(sc, ".", "Sprite", "soul_orb.png", 0.9, 64, 0.9, billboard=1, shaded=False, modulate=(1.2, 1.2, 1.6, 1.0))
    omni(sc, ".", "Light", (0, 1.0, 0), (0.55, 0.7, 1.0), 1.4, 5.0)
    sc.add("Prompt", "Label3D", ".", {"transform": XF((0, 2.0, 0)), "visible": False, "billboard": 1, "no_depth_test": True,
                                      "outline_size": 12, "text": "[E] RAISE", "font_size": 40, "pixel_size": 0.008})
    sc.write("scenes/enemies/soul_orb.tscn")

    # Api bahaya
    sc = Scene("FireHazard", "Node3D", script="res://scripts/fire_hazard.gd")
    cyl(sc, ".", "Scorch", 1.0, 1.0, 0.02, (0, 0.025, 0), (0.15, 0.05, 0.02, 0.55), 24, transparent=True, unshaded=True)
    for i in range(4):
        a = math.tau * i / 4.0 + 0.35 * i
        rr = 1.0 * 0.45 * (0.3 + (i % 2))
        h = 0.75 + 0.14 * i
        cyl(sc, ".", f"Flame{i + 1}", 0.0, 0.28, h, (math.cos(a) * rr, h / 2, math.sin(a) * rr), (1.0, 0.5, 0.12, 1), 12,
            emissive=True, unshaded=True)
    cyl(sc, ".", "Core", 0.0, 0.2, 0.9, (0, 0.45, 0), (1.0, 0.9, 0.4, 1), 12, emissive=True, unshaded=True)
    omni(sc, ".", "Light", (0, 1.0, 0), (1.0, 0.55, 0.2), 1.6, 6.0)
    sc.write("scenes/props/fire_hazard.tscn")


# ------------------------------------------------------------ LEVEL
def make_level():
    sc = Scene("Level")
    I = {}

    def inst(path):
        if path not in I:
            I[path] = sc.ext_res("PackedScene", path)
        return I[path]

    def place(parent, name, path, pos, rot_y=0.0, scale=1.0):
        return sc.add(name, "", parent, {"transform": XF(pos, ("y", rot_y) if rot_y else None, (scale,) * 3)}, instance=inst(path))

    tex = sc.ext_res("Texture2D", SPR + "ground.png")

    def ground(parent, name, center, size, tint):
        m = sc.sub("PlaneMesh", {"size": V2(*size)})
        mt = sc.sub("StandardMaterial3D", {
            "albedo_color": Col(*tint), "albedo_texture": tex, "roughness": 1.0,
            "uv1_scale": V3(size[0] / 6.0, size[1] / 6.0, 1.0), "texture_filter": 2})
        meshnode(sc, parent, name, m, mt, center)

    sc.add("Ground", "Node3D")
    ground("Ground", "Outer", (34, -0.04, 0), (170, 70), (0.3, 0.42, 0.34, 1))
    tints = [(1.0, 0.82, 0.62, 1), (0.72, 0.95, 0.62, 1), (0.82, 0.86, 1.0, 1)]
    for i in range(3):
        ground("Ground", f"Area{i}", (i * SPACING, 0, 0), (HW * 2, HD * 2), tints[i])
        if i < 2:
            ground("Ground", f"Corridor{i}", (i * SPACING + HW + CORRIDOR / 2, 0, 0), (CORRIDOR, GATE_HALF * 2), (0.85, 0.74, 0.58, 1))
    ground("Ground", "ExitPath", (2 * SPACING + HW + 5, 0, 0), (10, GATE_HALF * 2), (0.85, 0.75, 0.6, 1))

    def fence_x(parent, name, x0, x1, z):
        g = sc.add(name, "Node3D", parent)
        length = abs(x1 - x0); mid = (x0 + x1) / 2
        box_col(sc, g, "Collider", (length, 3.0, 0.7), (mid, 1.5, z))
        count = int(length / 2.0) + 1
        for i in range(count + 1):
            box(sc, g, "Post", (0.28, 1.6, 0.28), (min(x0, x1) + length * i / count, 0.8, z), WOOD)
        box(sc, g, "RailLow", (length, 0.14, 0.14), (mid, 0.6, z), WOOD_D)
        box(sc, g, "RailHigh", (length, 0.14, 0.14), (mid, 1.15, z), WOOD_D)

    def fence_z(parent, name, z0, z1, x):
        g = sc.add(name, "Node3D", parent)
        length = abs(z1 - z0); mid = (z0 + z1) / 2
        box_col(sc, g, "Collider", (0.7, 3.0, length), (x, 1.5, mid))
        count = int(length / 2.0) + 1
        for i in range(count + 1):
            box(sc, g, "Post", (0.28, 1.6, 0.28), (x, 0.8, min(z0, z1) + length * i / count), WOOD)
        box(sc, g, "RailLow", (0.14, 0.14, length), (x, 0.6, mid), WOOD_D)
        box(sc, g, "RailHigh", (0.14, 0.14, length), (x, 1.15, mid), WOOD_D)

    sc.add("Areas", "Node3D")
    sc.add("Gates", "Node3D")
    for i in range(3):
        cx = i * SPACING
        a = sc.add(f"Area{i}", "Node3D", "Areas")
        fz = sc.add("Fences", "Node3D", a)
        fence_x(fz, "North", cx - HW, cx + HW, -HD)
        fence_x(fz, "South", cx - HW, cx + HW, HD)
        if i == 0:
            fence_z(fz, "West", -HD, HD, cx - HW)
        else:
            fence_z(fz, "WestN", -HD, -GATE_HALF, cx - HW)
            fence_z(fz, "WestS", GATE_HALF, HD, cx - HW)
        fence_z(fz, "EastN", -HD, -GATE_HALF, cx + HW)
        fence_z(fz, "EastS", GATE_HALF, HD, cx + HW)
        fence_x(fz, "CorridorN", cx + HW, cx + HW + CORRIDOR, -GATE_HALF)
        fence_x(fz, "CorridorS", cx + HW, cx + HW + CORRIDOR, GATE_HALF)
        omni(sc, a, "AreaLight", (cx, 9.0, 1.0), (0.55, 0.6, 1.0), 0.9, 26.0)
        place("Gates", f"Gate{i}", "res://scenes/props/gate.tscn", (cx + HW, 0, 0))

    def torches(area, cx, pts):
        for k, (x, z) in enumerate(pts):
            place(area, f"Torch{k + 1}", "res://scenes/props/torch.tscn", (cx + x, 0, z))

    def fires(area, cx, pts):
        for k, (x, z) in enumerate(pts):
            place(area, f"Fire{k + 1}", "res://scenes/props/fire_hazard.tscn", (cx + x, 0, z))

    # ---- Area 0: Halaman Desa
    a0 = "Areas/Area0"
    place(a0, "HouseA", "res://scenes/props/house.tscn", (-6.5, 0, -6.6))
    place(a0, "HouseBurned", "res://scenes/props/house_burned.tscn", (6.0, 0, -6.6))
    place(a0, "Well", "res://scenes/props/well.tscn", (-3.0, 0, 2.2))
    place(a0, "Cart", "res://scenes/props/cart.tscn", (3.5, 0, 6.4))
    place(a0, "Crate1", "res://scenes/props/crate_100.tscn", (-11.0, 0, -3.6))
    place(a0, "Crate2", "res://scenes/props/crate_080.tscn", (-11.0, 0, -2.4))
    place(a0, "Crate3", "res://scenes/props/crate_110.tscn", (-10.2, 0, 6.8))
    torches(a0, 0, [(-11.6, -7), (-11.6, 7), (11.6, -7), (11.6, 7)])
    fires(a0, 0, [(6.0, -3.6), (-0.5, -2.2), (2.5, 3.6), (9.0, 2.6)])
    place(a0, "OldBram", "res://scenes/characters/old_bram.tscn", (-10.0, 0, 1.0))

    # ---- Area 1: Kebun Desa
    cx = SPACING
    a1 = "Areas/Area1"
    place(a1, "Barn", "res://scenes/props/barn.tscn", (cx + 7.0, 0, -6.7))
    for k in range(3):
        place(a1, f"BedN{k + 1}", "res://scenes/props/garden_bed.tscn", (cx - 9.0 + k * 3.8, 0, -6.6))
        place(a1, f"BedS{k + 1}", "res://scenes/props/garden_bed.tscn", (cx - 9.0 + k * 3.8, 0, 6.6))
    place(a1, "Scarecrow", "res://scenes/props/scarecrow.tscn", (cx - 6.0, 0, 0.5))
    place(a1, "Hay1", "res://scenes/props/hay_bale.tscn", (cx + 10.6, 0, 6.6))
    place(a1, "Hay2", "res://scenes/props/hay_bale.tscn", (cx + 8.8, 0, 7.2))
    place(a1, "Crate1", "res://scenes/props/crate_100.tscn", (cx - 11.0, 0, -2.6))
    torches(a1, cx, [(-11.6, -7), (-11.6, 7), (11.6, -7), (11.6, 7)])
    fires(a1, cx, [(2.5, -1.5), (6.5, 2.5), (-3.0, 4.0), (9.5, -3.0)])

    # ---- Area 2: Gerbang Desa
    cx = 2 * SPACING
    a2 = "Areas/Area2"
    place(a2, "PillarN", "res://scenes/props/pillar.tscn", (cx + 11.5, 0, -5.0))
    place(a2, "PillarS", "res://scenes/props/pillar.tscn", (cx + 11.5, 0, 5.0))
    place(a2, "BrokenCart", "res://scenes/props/cart_broken.tscn", (cx - 6.0, 0, -6.4))
    place(a2, "Crate1", "res://scenes/props/crate_110.tscn", (cx - 10.2, 0, 6.6))
    place(a2, "Crate2", "res://scenes/props/crate_080.tscn", (cx - 9.0, 0, 7.3))
    place(a2, "Hay", "res://scenes/props/hay_bale.tscn", (cx - 2.0, 0, 7.2))
    place(a2, "GateTorchN", "res://scenes/props/torch.tscn", (cx + 10.2, 0, -2.6))
    place(a2, "GateTorchS", "res://scenes/props/torch.tscn", (cx + 10.2, 0, 2.6))
    torches(a2, cx, [(-11.6, -7), (-11.6, 7)])
    fires(a2, cx, [(3.0, -2.5), (7.0, 3.0), (-1.0, 1.0)])

    # ---- Hutan di sekeliling
    rng = random.Random(4242)
    sc.add("Forest", "Node3D")
    x = -24.0
    while x < 100.0:
        for side in (-1.0, 1.0):
            z = side * rng.uniform(11.8, 18.0)
            place("Forest", "Tree", "res://scenes/props/tree.tscn", (x + rng.uniform(-1, 1), 0, z), 0.0, rng.uniform(0.9, 1.6))
        x += rng.uniform(2.4, 3.6)
    for k in range(9):
        place("Forest", "Tree", "res://scenes/props/tree.tscn", (rng.uniform(-22, -16), 0, -9 + k * 2.2), 0.0, rng.uniform(1.0, 1.6))
    for k in range(3):
        place("Forest", "Tree", "res://scenes/props/tree.tscn", (SPACING * 2 + HW + 12 + k * 2.5, 0, -6 + k * 6), 0.0, rng.uniform(1.2, 1.7))
    # Papan developer di lorong setelah Gerbang 1 (disembunyikan sampai Area 1 selesai)
    sc.add("Special", "Node3D")
    place("Special", "DevSign", "res://scenes/props/dev_sign.tscn", (HW + 2.6, 0, -1.9))
    sc.write("scenes/levels/Stage1Level.tscn")


# ------------------------------------------------------------ STAGE & WORKSPACE
def make_stage_scene():
    sc = Scene("Stage1", script="res://scripts/stage_1.gd")
    sc.add("Level", "", ".", instance=sc.ext_res("PackedScene", "res://scenes/levels/Stage1Level.tscn"))
    sc.add("World", "Node3D")
    sc.add("Mira", "", ".", {"transform": XF((-9.0, 0, 3.0))}, instance=sc.ext_res("PackedScene", "res://scenes/characters/mira.tscn"))
    sc.add("Pip", "", ".", {"transform": XF((-10.1, 2.7, 3.3))}, instance=sc.ext_res("PackedScene", "res://scenes/characters/pip.tscn"))
    # Contoh musuh/Shade/orb: hanya untuk dilihat di editor, dihapus otomatis saat game dijalankan
    sc.add("PreviewOnly", "Node3D")
    items = [("Slime", "res://scenes/enemies/slime_lumut.tscn", (1.5, 0, -0.5), "Slime Lumut (musuh)", 3.2),
             ("Tikus", "res://scenes/enemies/tikus_gerogot.tscn", (4.5, 0, -0.5), "Tikus Gerogot (musuh)", 2.8),
             ("ShadeSlime", "res://scenes/enemies/shade_slime.tscn", (1.5, 0, 2.2), "Shade Slime", 3.2),
             ("ShadeTikus", "res://scenes/enemies/shade_tikus.tscn", (4.5, 0, 2.2), "Shade Tikus", 2.8),
             ("SoulOrb", "res://scenes/enemies/soul_orb.tscn", (7.5, 0, 0.8), "Soul Orb", 2.4)]
    for n, path, pos, text, h in items:
        sc.add(n, "", "PreviewOnly", {"transform": XF(pos)}, instance=sc.ext_res("PackedScene", path))
        label(sc, "PreviewOnly", n + "Label", text, (pos[0], h, pos[2]), 36, (0.8, 0.9, 1.0))
    sc.write("scenes/Stage1.tscn")


def make_main_scene():
    sc = Scene("Title", script="res://scripts/main.gd")
    env = sc.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.03, 0.04, 0.09, 1),
        "ambient_light_source": 2, "ambient_light_color": Col(0.45, 0.5, 0.75, 1),
        "ambient_light_energy": 0.9, "glow_enabled": True})
    sc.add("WorldEnvironment", "WorldEnvironment", ".", {"environment": env})
    sc.add("Moon", "DirectionalLight3D", ".", {
        "transform": euler_xf((0, 20, 0), math.radians(-58), math.radians(-25)),
        "light_color": Col(0.6, 0.68, 1.0, 1), "light_energy": 0.95, "shadow_enabled": True})
    sc.add("Camera3D", "Camera3D", ".", {
        "transform": euler_xf((-2, 9, 17), math.radians(-30), 0), "current": True, "fov": 38.0, "far": 200.0})
    sc.add("Level", "", ".", instance=sc.ext_res("PackedScene", "res://scenes/levels/Stage1Level.tscn"))
    sc.add("Mira", "", ".", {"transform": XF((-8.0, 0, 3.0))}, instance=sc.ext_res("PackedScene", "res://scenes/characters/mira.tscn"))
    sc.add("Pip", "", ".", {"transform": XF((-9.1, 2.7, 3.3))}, instance=sc.ext_res("PackedScene", "res://scenes/characters/pip.tscn"))
    items = [("Slime", "res://scenes/enemies/slime_lumut.tscn", (1.5, 0, -0.5), "Slime Lumut", 3.2),
             ("Tikus", "res://scenes/enemies/tikus_gerogot.tscn", (4.5, 0, -0.5), "Tikus Gerogot", 2.8),
             ("ShadeSlime", "res://scenes/enemies/shade_slime.tscn", (1.5, 0, 2.2), "Shade Slime", 3.2),
             ("ShadeTikus", "res://scenes/enemies/shade_tikus.tscn", (4.5, 0, 2.2), "Shade Tikus", 2.8),
             ("SoulOrb", "res://scenes/enemies/soul_orb.tscn", (7.5, 0, 0.8), "Soul Orb", 2.4)]
    for n, path, pos, text, h in items:
        sc.add(n, "", ".", {"transform": XF(pos)}, instance=sc.ext_res("PackedScene", path))
        label(sc, ".", n + "Label", text, (pos[0], h, pos[2]), 36, (0.8, 0.9, 1.0))
    sc.write("scenes/Main.tscn")


def make_workspace():
    sc = Scene("Workspace", script="res://scripts/workspace.gd")
    env = sc.sub("Environment", {
        "background_mode": 1, "background_color": Col(0.05, 0.06, 0.12, 1),
        "ambient_light_source": 2, "ambient_light_color": Col(0.55, 0.6, 0.85, 1),
        "ambient_light_energy": 1.0})
    sc.add("WorldEnvironment", "WorldEnvironment", ".", {"environment": env})
    sc.add("Sun", "DirectionalLight3D", ".", {
        "transform": euler_xf((0, 20, 0), math.radians(-55), math.radians(-25)),
        "light_color": Col(0.9, 0.92, 1.0), "light_energy": 1.1, "shadow_enabled": True})
    sc.add("Camera3D", "Camera3D", ".", {
        "transform": euler_xf((0, 20, 34), math.radians(-30), 0), "current": True, "fov": 55.0, "far": 400.0})
    ground_tex = sc.ext_res("Texture2D", SPR + "ground.png")
    fl = sc.sub("PlaneMesh", {"size": V2(200, 170)})
    fm = sc.sub("StandardMaterial3D", {"albedo_color": Col(0.55, 0.6, 0.6, 1), "albedo_texture": ground_tex,
                                      "uv1_scale": V3(33, 28, 1), "texture_filter": 2, "roughness": 1.0})
    meshnode(sc, ".", "Floor", fl, fm, (20, -0.12, -40))

    def put(grp, name, path, pos, text, h=4.0, extra=None):
        p = {"transform": XF(pos)}
        p.update(extra or {})
        sc.add(name, "", grp, p, instance=sc.ext_res("PackedScene", path))
        label(sc, grp, name + "Label", text, (pos[0], h, pos[2] + 2.2), 40)

    sc.add("Karakter", "Node3D")
    label(sc, ".", "TitleChars", "KARAKTER & MUSUH", (0, 6.5, 6), 90, (1, 0.8, 0.5))
    chars = [
        ("Mira", "res://scenes/characters/mira.tscn", "Mira (Player)", 3.6),
        ("OldBram", "res://scenes/characters/old_bram.tscn", "Old Bram (NPC)", 3.6),
        ("Pip", "res://scenes/characters/pip.tscn", "Pip (lentera)", 3.6),
        ("Slime", "res://scenes/enemies/slime_lumut.tscn", "Slime Lumut", 3.2),
        ("Tikus", "res://scenes/enemies/tikus_gerogot.tscn", "Tikus Gerogot", 3.0),
        ("ShadeSlime", "res://scenes/enemies/shade_slime.tscn", "Shade Slime (Tank)", 3.2),
        ("ShadeTikus", "res://scenes/enemies/shade_tikus.tscn", "Shade Tikus (Striker)", 3.0),
        ("SoulOrb", "res://scenes/enemies/soul_orb.tscn", "Soul Orb", 2.6),
        ("Fire", "res://scenes/props/fire_hazard.tscn", "Api (bahaya)", 2.6),
    ]
    for k, (n, p, t, h) in enumerate(chars):
        put("Karakter", n, p, (-16 + k * 4.0, 0, 0), t, h)

    sc.add("Bangunan", "Node3D")
    label(sc, ".", "TitleBuild", "BANGUNAN", (0, 7, -9), 90, (1, 0.8, 0.5))
    for n, p, x, t in [("House", "house", -14, "Rumah"), ("HouseBurned", "house_burned", -4, "Rumah terbakar"),
                       ("Barn", "barn", 8, "Lumbung"), ("Well", "well", 18, "Sumur"),
                       ("Cart", "cart", 24, "Gerobak"), ("BrokenCart", "cart_broken", 30, "Gerobak rusak")]:
        put("Bangunan", n, f"res://scenes/props/{p}.tscn", (x, 0, -14), t, 6.0)

    sc.add("Prop", "Node3D")
    label(sc, ".", "TitleProps", "PROP & LINGKUNGAN", (0, 7, -24), 90, (1, 0.8, 0.5))
    props = [("Crate080", "crate_080", "Peti kecil"), ("Crate100", "crate_100", "Peti"), ("Crate110", "crate_110", "Peti besar"),
             ("Hay", "hay_bale", "Jerami"), ("Torch", "torch", "Obor"), ("Garden", "garden_bed", "Bedeng kebun"),
             ("Scarecrow", "scarecrow", "Orang-orangan sawah"), ("Pillar", "pillar", "Pilar gerbang"),
             ("Tree", "tree", "Pohon"), ("Gate", "gate", "Gerbang segel"),
             ("DevSign", "dev_sign", "Papan Developer")]
    for k, (n, p, t) in enumerate(props):
        put("Prop", n, f"res://scenes/props/{p}.tscn", (-18 + k * 5.0, 0, -30), t, 5.0)

    label(sc, ".", "TitleLevel", "LEVEL STAGE 1 LENGKAP  (scenes/levels/Stage1Level.tscn)", (30, 9, -52), 80, (0.7, 0.9, 1))
    sc.add("Stage1Level", "", ".", {"transform": XF((-4, 0, -75))},
           instance=sc.ext_res("PackedScene", "res://scenes/levels/Stage1Level.tscn"))
    sc.write("scenes/Workspace.tscn")


make_props()
make_characters()
make_level()
make_stage_scene()
make_main_scene()
make_workspace()
print("selesai")
