# MediaPipe world landmarks (extract.py JSON) -> Shichimi motion YAML (dense keys, existing format; no player changes).
# usage: uv run --with numpy python to_motion.py in.json start_frame end_frame "<comment>" [yaw] [smooth] > motion.yml
# Inverts Rig.pose: limb rest (0,-1,0), Euler XZY(-flex, twist, abd) => d = (s*sin a, -cos a cos f, cos a sin f).
import json, sys, numpy as np

src, a, b, note = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
yaw = float(sys.argv[5]) if len(sys.argv) > 5 else 30
win = int(sys.argv[6]) if len(sys.argv) > 6 else 5
d = json.load(open(src)); fps = d["fps"]
P = np.array([f if f else [[np.nan] * 4] * 33 for f in d["frames"]], float)[:, :, :3]
P = P * [1, -1, -1]                                   # MP (x right, y down, z away) -> y up, z toward camera
for j in range(33):                                   # fill gaps, then moving-average smooth (ponytail: box filter)
    for c in range(3):
        v = P[:, j, c]; ok = ~np.isnan(v); P[:, j, c] = np.interp(np.arange(len(v)), np.flatnonzero(ok), v[ok])
k = np.ones(win) / win
P = np.apply_along_axis(lambda v: np.convolve(np.pad(v, win // 2, mode="edge"), k, "valid"), 0, P)
P = P[a:b + 1]
n = len(P)
# seamless loop: blend the drift between last and first frame out over the clip
P = P - np.linspace(0, 1, n)[:, None, None] * (P[-1] - P[0])
P = P[:-1]

unit = lambda v: v / np.linalg.norm(v)
deg = np.degrees

def rx(t): c, s_ = np.cos(t), np.sin(t); return np.array([[1, 0, 0], [0, c, -s_], [0, s_, c]])
def rz(t): c, s_ = np.cos(t), np.sin(t); return np.array([[c, -s_, 0], [s_, c, 0], [0, 0, 1]])

def limb(R, root, j, s, end):
    v = unit(R.T @ (P_[j] - P_[root]))                 # in body frame (x left, y up, z forward)
    ab = np.arcsin(np.clip(s * v[0], -1, 1)); fl = np.arctan2(v[2], -v[1])
    if v[1] > 0 and abs(v[2]) < abs(v[0]):            # overhead/side: take the abduction branch (jacks), not flex 180
        ab = np.pi - ab; fl = np.arctan2(-v[2], v[1])
    # twist: where the bent forearm/shin points around the upper segment (zero twist = forearm forward, shin back)
    f = (rx(-fl) @ rz(s * ab)).T @ (R.T @ (P_[end] - P_[j]))
    tw = s * np.arctan2(f[0], f[2]) if root in (11, 12) else s * np.arctan2(-f[0], -f[2])
    if np.hypot(f[0], f[2]) < 0.35 * np.linalg.norm(f): tw = 0   # nearly straight: twist undefined
    return [round(deg(fl)), round(deg(ab)), round(deg(tw))]

def bend(p, q, r):
    u, w = unit(P_[q] - P_[p]), unit(P_[r] - P_[q])
    return round(deg(np.arccos(np.clip(u @ w, -1, 1))))

keys, yaws = [], []
for P_ in P:
    X = unit(P_[23] - P_[24])                         # right hip -> left hip = own left
    Y = (P_[11] + P_[12]) / 2 - (P_[23] + P_[24]) / 2
    Y = unit(Y - (Y @ X) * X); Z = np.cross(X, Y)
    R = np.stack([X, Y, Z], 1)                         # body -> world
    # Euler YXZ (three.js rootQuat order): pitch about X (+ = tip forward), yaw about Y, roll about Z (sign per rig doc)
    pitch = np.arcsin(np.clip(-R[1, 2], -1, 1))
    yw = np.arctan2(R[0, 2], R[2, 2]); roll = np.arctan2(R[1, 0], R[1, 1])
    yaws.append(yw)
    keys.append(dict(root=[round(deg(pitch)), yw, round(deg(roll))],
        lsh=limb(R, 11, 13, 1, 15), rsh=limb(R, 12, 14, -1, 16), lhip=limb(R, 23, 25, 1, 27), rhip=limb(R, 24, 26, -1, 28),
        lel=bend(11, 13, 15), rel=bend(12, 14, 16), lkn=bend(23, 25, 27), rkn=bend(24, 26, 28)))
my = np.angle(np.mean(np.exp(1j * np.array(yaws))))  # camera-facing yaw -> 0, keep the wobble
for kk in keys: kk["root"][1] = round(deg(np.angle(np.exp(1j * (kk["root"][1] - my)))))
print(f"# {note}\n# Captured: MediaPipe Pose world landmarks, frames {a}-{b} @ {fps:.0f} fps (script/mocap). One key per frame.")
print(f"tempo: {(n - 1) / fps:.2f}\nyaw: {yaw:g}\nkeys:")
fmt = lambda v: "[" + ", ".join(str(int(x)) for x in v) + "]" if isinstance(v, list) else str(int(v))
for kk in keys: print("  - { " + ", ".join(f"{n_}: {fmt(v)}" for n_, v in kk.items()) + " }")
