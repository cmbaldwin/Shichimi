# Mixamo FBX (with skin, 30 fps) -> loop GLB + meta JSON that script/vork/scene.rb reads.
# usage: Blender -b -P mixamo_glb.py -- in.fbx out_dir slug yaw [start end] [tex_px]
#   start/end: loop frames (end pose == start pose, end excluded from the video). Omitted: best loop is searched.
# Writes out_dir/<slug>.glb and <slug>.json {fps, frames, tempo, yaw, box{min,max} (world, after yaw), mixamo: true}.
import bpy, sys, json, math
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, out, slug, yaw = a[0], a[1], a[2], float(a[3])
start = int(a[4]) if len(a) > 5 else None
end = int(a[5]) if len(a) > 5 else None
tex = int(a[6]) if len(a) > 6 else 1024

if src.endswith(".blend"):                                # from retarget.py
    bpy.ops.wm.open_mainfile(filepath=src)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src, automatic_bone_orientation=False)
sc = bpy.context.scene
sc.render.fps = 30
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
act = arm.animation_data.action
f0, f1 = (int(x) for x in act.frame_range)

def pose(f):
    sc.frame_set(f)
    return [pb.matrix.to_quaternion() for pb in arm.pose.bones] + [arm.pose.bones[0].matrix.translation.copy()]

if start is None:
    # ponytail: brute-force best loop (O(n^2) frame pairs), fine for clips < 300 frames
    P = {f: pose(f) for f in range(f0, f1 + 1)}
    def dist(p, q):
        r = sum(1 - abs(x.dot(y)) for x, y in zip(p[:-1], q[:-1]))
        return r + 0.002 * (p[-1] - q[-1]).length          # hips in cm
    n = f1 - f0
    best = min(((dist(P[s], P[e]) + 0.02 * (1 - (e - s) / n), s, e)
                for s in range(f0, f0 + max(1, n // 3)) for e in range(s + max(15, n // 3), f1 + 1)))
    _, start, end = best
    print(f"LOOP {start}-{end} score {best[0]:.4f} of {f0}-{f1}")

for img in bpy.data.images:                               # 4K textures -> tex px (render is 720 px)
    if img.size[0] > tex:
        img.scale(tex, tex * img.size[1] // img.size[0])

# Mixamo's spec/gloss maps come through as latex-shiny cloth: matte everything (skin a bit less)
for mat in bpy.data.materials:
    b = mat.node_tree and next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not b: continue
    for k in ("Metallic", "Roughness", "Specular IOR Level"):
        for l in list(b.inputs[k].links): mat.node_tree.links.remove(l)
    b.inputs["Metallic"].default_value = 0
    b.inputs["Roughness"].default_value = 0.55 if "body" == mat.name.split("_")[-1].lower() else 0.85
    b.inputs["Specular IOR Level"].default_value = 0.4

# shift the action so the loop starts at frame 0; frame `frames` == frame 0
for fc in act.fcurves:
    for k in fc.keyframe_points:
        k.co.x -= start; k.handle_left.x -= start; k.handle_right.x -= start
act.name = "loop"
frames = end - start
sc.frame_start, sc.frame_end = 0, frames

# box over the loop from evaluated mesh vertices (every 2nd frame), in world after yaw; ground min y to 0
cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
dg = bpy.context.evaluated_depsgraph_get()
for f in range(0, frames, 2):
    sc.frame_set(f); dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        e = o.evaluated_get(dg); m = e.to_mesh(); mw = o.matrix_world
        for i in range(0, len(m.vertices), 7):
            w = mw @ m.vertices[i].co                                  # Blender Z-up -> glTF: x, z, -y
            x, y, z = w.x, w.z, -w.y
            p = Vector((x * cy + z * sy, y, -x * sy + z * cy))
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
        e.to_mesh_clear()
bpy.ops.export_scene.gltf(filepath=f"{out}/{slug}.glb", export_format="GLB", export_animations=True,
                          export_frame_range=True, export_force_sampling=True, export_image_format="JPEG",
                          export_jpeg_quality=85)
json.dump({"fps": 30, "frames": frames, "tempo": frames / 30, "yaw": yaw, "mixamo": True,
           "box": {"min": list(lo), "max": list(hi)}}, open(f"{out}/{slug}.json", "w"))
print("WROTE", out, slug, frames, list(lo), list(hi))
