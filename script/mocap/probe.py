# blender -b -P probe.py -- in.fbx : print anim range, bones, materials
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=sys.argv[-1])
for a in bpy.data.actions: print("ACTION", a.name, a.frame_range[:])
for o in bpy.data.objects: print("OBJ", o.type, o.name, [m.name for m in getattr(o.data,'materials',[]) or []])
for i in bpy.data.images: print("IMG", i.name, i.size[:])
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]; print("BONES", len(arm.data.bones), [b.name for b in arm.data.bones][:8], arm.scale[:])
print("FPS", bpy.context.scene.render.fps)
