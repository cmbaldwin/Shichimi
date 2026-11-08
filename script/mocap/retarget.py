# Our keyframed motion (tmp/exports/<slug>.glb from /dev/export, Quaternius UE-style rig) -> a Mixamo character.
# usage: Blender -b -P retarget.py -- character.fbx export.glb out.blend
# Both rigs rest in T-pose, so each mapped bone gets world rotation = src world rot * src rest^-1 * tgt rest,
# hips position scaled by hip height. Writes a .blend with only the character and action "loop" (frames 0..N);
# then: mixamo_glb.py -- out.blend DIR SLUG YAW 0 N
import bpy, sys
from mathutils import Matrix

char, src, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = 30
bpy.ops.import_scene.fbx(filepath=char, automatic_bone_orientation=False)
T = next(o for o in bpy.data.objects if o.type == "ARMATURE")
keep = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=src)
S = next(o for o in bpy.data.objects if o.type == "ARMATURE" and o not in keep)
pre = T.data.bones[0].name.split(":")[0] + ":"

M = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head"}
for s, side in (("l", "Left"), ("r", "Right")):
    M |= {f"clavicle_{s}": f"{side}Shoulder", f"upperarm_{s}": f"{side}Arm", f"lowerarm_{s}": f"{side}ForeArm",
          f"hand_{s}": f"{side}Hand", f"thigh_{s}": f"{side}UpLeg", f"calf_{s}": f"{side}Leg", f"foot_{s}": f"{side}Foot",
          f"ball_{s}": f"{side}ToeBase"}
    for fing, mx in (("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Pinky"), ("thumb", "Thumb")):
        M |= {f"{fing}_0{i}_{s}": f"{side}Hand{mx}{i}" for i in (1, 2, 3)}
M = {k: pre + v for k, v in M.items() if k in S.pose.bones and pre + v in T.pose.bones}

rest = lambda arm, b: (arm.matrix_world @ arm.data.bones[b].matrix_local).to_quaternion()
off = {s: rest(S, s).inverted() @ rest(T, t) for s, t in M.items()}
ratio = (T.matrix_world @ T.data.bones[pre + "Hips"].head_local).z / (S.matrix_world @ S.data.bones["pelvis"].head_local).z
Tmw = T.matrix_world.to_quaternion().inverted()
order = [b.name for b in T.data.bones if b.name in M.values()]          # parents first
inv = {t: s for s, t in M.items()}
act = S.animation_data.action
n = round(act.frame_range[1])

T.animation_data_create(); T.animation_data.action = None     # keyframe_insert makes a fresh action
for pb in T.pose.bones: pb.rotation_mode = "QUATERNION"
for f in range(0, n + 1):
    sc.frame_set(f)
    for t in order:
        s, pb = inv[t], T.pose.bones[t]
        w = (S.matrix_world @ S.pose.bones[s].matrix).to_quaternion() @ off[s]
        loc = pb.matrix.translation
        if t == pre + "Hips":
            loc = T.matrix_world.inverted() @ ((S.matrix_world @ S.pose.bones[s].matrix).translation * ratio)
        pb.matrix = Matrix.LocRotScale(loc, Tmw @ w, pb.matrix.to_scale())
        bpy.context.view_layer.update()
        pb.keyframe_insert("rotation_quaternion", frame=f)
        if t == pre + "Hips": pb.keyframe_insert("location", frame=f)

for o in [o for o in bpy.data.objects if o not in keep]: bpy.data.objects.remove(o)
T.animation_data.action.name = "loop"
for a in [a for a in bpy.data.actions if a != T.animation_data.action]: bpy.data.actions.remove(a)
bpy.ops.wm.save_as_mainfile(filepath=out)
print("RETARGET", out, n, "frames, hip ratio", round(ratio, 3))
