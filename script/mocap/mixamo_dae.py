# Mixamo Collada export (dae_mixamo, no skin, 30 fps) -> extract.py-style landmark JSON, so to_motion.py works unchanged.
# usage: uv run --with numpy python mixamo_dae.py in.dae out.json
import json, sys, xml.etree.ElementTree as ET, numpy as np

ns = {"c": "http://www.collada.org/2005/11/COLLADASchema"}
root = ET.parse(sys.argv[1]).getroot()
MAP = {11: "LeftArm", 12: "RightArm", 13: "LeftForeArm", 14: "RightForeArm", 15: "LeftHand", 16: "RightHand",
       23: "LeftUpLeg", 24: "RightUpLeg", 25: "LeftLeg", 26: "RightLeg", 27: "LeftFoot", 28: "RightFoot"}
mat = lambda s: np.array(s.split(), float).reshape(-1, 4, 4)
anim = {}
for a in root.iter("{%s}animation" % ns["c"]):
    for fa in a.iter("{%s}float_array" % ns["c"]):
        if fa.get("id", "").endswith("-Matrix-animation-output-transform-array"):
            anim[fa.get("id").split("-Matrix")[0]] = mat(fa.text)
n = max(len(v) for v in anim.values())
pos = {}
def walk(node, parent):                               # parent: (n,4,4) world matrices
    if node.get("type") != "JOINT": [walk(c, parent) for c in node.findall("c:node", ns)]; return
    m = anim.get(node.get("id"))
    if m is None: m = np.repeat(mat(node.find("c:matrix", ns).text), n, 0)
    w = parent @ m; pos[node.get("id").replace("mixamorig_", "")] = w[:, :3, 3]
    for c in node.findall("c:node", ns): walk(c, w)
for vs in root.iter("{%s}visual_scene" % ns["c"]):
    for nd in vs.findall("c:node", ns): walk(nd, np.repeat(np.eye(4)[None], n, 0))
frames = []
for i in range(n):
    f = [[0, 0, 0, 0]] * 33
    for k, b in MAP.items():
        x, y, z = pos[b][i] / 100; f[k] = [x, -y, -z, 1]     # to MediaPipe convention (y down, z away)
    frames.append(f)
json.dump({"fps": 30, "frames": frames}, open(sys.argv[2], "w"))
print(sys.argv[2], n, "frames")
