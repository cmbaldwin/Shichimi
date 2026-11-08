# Video -> per-frame MediaPipe Pose world landmarks (metres, hip-centred). CPU only.
# usage: python extract.py in.mp4 pose_heavy.task out.json [every_nth_frame]
import json, sys, cv2, mediapipe as mp
from mediapipe.tasks.python import BaseOptions, vision

src, model, out = sys.argv[1:4]
step = int(sys.argv[4]) if len(sys.argv) > 4 else 1
lm = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=model), running_mode=vision.RunningMode.VIDEO))
cap = cv2.VideoCapture(src); fps = cap.get(cv2.CAP_PROP_FPS); frames = []; i = 0
while True:
    ok, img = cap.read()
    if not ok: break
    if i % step == 0:
        r = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(img, cv2.COLOR_BGR2RGB)), int(i * 1000 / fps))
        frames.append([[round(p.x, 4), round(p.y, 4), round(p.z, 4), round(p.visibility, 2)] for p in r.pose_world_landmarks[0]] if r.pose_world_landmarks else None)
    i += 1
json.dump({"fps": fps / step, "frames": frames}, open(out, "w"))
print(out, len(frames), sum(f is None for f in frames), "missing")
