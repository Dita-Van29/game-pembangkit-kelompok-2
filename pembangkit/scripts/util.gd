class_name Util
extends RefCounted
## Kumpulan fungsi bantu (static) untuk membangun sprite, mesh, dan efek sederhana.


static func load_tex(path: String) -> Texture2D:
	var tex = load(path)
	if tex == null:
		# Cadangan: kotak magenta supaya kelihatan jika aset hilang.
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1, 1))
		return ImageTexture.create_from_image(img)
	return tex


## Sprite3D billboard (Fixed Y), filter Nearest, alpha cut agar bisa bikin bayangan.
## world_height = tinggi seluruh kanvas gambar dalam satuan dunia.
## Kaki karakter berada di dasar gambar, jadi titik pusat node = tanah.
static func make_sprite(path: String, world_height: float, lit: bool = true) -> Sprite3D:
	var tex: Texture2D = load_tex(path)
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = lit
	s.double_sided = true
	s.pixel_size = world_height / float(tex.get_height())
	s.position = Vector3(0.0, world_height * 0.5, 0.0)
	return s


static func mat(color: Color, emissive: bool = false, transparent: bool = false, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emissive:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b, 1.0)
		m.emission_energy_multiplier = 1.6
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func box_mesh(parent: Node, size: Vector3, pos: Vector3, color: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color)
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi


static func cyl_mesh(parent: Node, radius_top: float, radius_bottom: float, height: float, pos: Vector3, color: Color, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius_top
	cm.bottom_radius = radius_bottom
	cm.height = height
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = mat(color)
	parent.add_child(mi)
	mi.position = pos
	return mi


## Collider kotak statis (layer 1 = dunia/dinding).
static func box_collider(parent: Node, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	return body


static func cyl_collider(parent: Node, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	return body


## Cakram datar di tanah (blob bayangan, telegraph, cincin Shade, dll).
static func disk(parent: Node, radius: float, color: Color, emissive: bool = false, y: float = 0.03) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 24
	cm.rings = 1
	mi.mesh = cm
	var m := mat(color, emissive, true, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = Vector3(0.0, y, 0.0)
	return mi


static func blob_shadow(parent: Node, radius: float) -> MeshInstance3D:
	return disk(parent, radius, Color(0, 0, 0, 0.35), false, 0.02)


## Busur datar (irisan sabit). Pusat busur menghadap -Z lokal.
static func make_arc_mesh(r_in: float, r_out: float, arc_deg: float, segs: int = 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = deg_to_rad(arc_deg) * 0.5
	for i in range(segs):
		var a0: float = -half + (half * 2.0) * float(i) / float(segs)
		var a1: float = -half + (half * 2.0) * float(i + 1) / float(segs)
		var p0i := Vector3(sin(a0), 0.0, -cos(a0)) * r_in
		var p0o := Vector3(sin(a0), 0.0, -cos(a0)) * r_out
		var p1i := Vector3(sin(a1), 0.0, -cos(a1)) * r_in
		var p1o := Vector3(sin(a1), 0.0, -cos(a1)) * r_out
		for p in [p0i, p0o, p1o, p0i, p1o, p1i]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()


## Sudut yaw agar -Z lokal menghadap ke arah dir (bidang XZ).
static func yaw_from_dir(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func white_tex() -> Texture2D:
	var img := Image.create(16, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


## Teks melayang (damage, status, dll).
static func popup(parent: Node, pos: Vector3, text: String, color: Color = Color.WHITE, size: int = 44) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.outline_size = 14
	label.outline_modulate = Color(0.05, 0.02, 0.1, 1.0)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.3, 0.9)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
