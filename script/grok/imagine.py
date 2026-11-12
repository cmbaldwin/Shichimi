#!/usr/bin/env python3
"""One exercise clip via the Imagine API. Writes raw.mp4 in the working directory.

The grok CLI's video status poll drops the request (network error) after the
server has already accepted it, so this calls the API directly and polls itself.
Exit 2 = usage balance exhausted (stop the batch). Other failures exit 1.
"""
import base64, json, math, subprocess, sys, time, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = ROOT / "script/grok/identity"
API = "https://api.x.ai/v1"


def token():
    auth = json.loads((Path.home() / ".grok/auth.json").read_text())
    return next(iter(auth.values()))["key"]


def refresh_token():
    # grok rewrites ~/.grok/auth.json when its access token is rejected.
    print("refreshing grok token", flush=True)
    subprocess.run(["grok", "models"], capture_output=True, text=True, timeout=90)


def api(method, path, body=None, timeout=120, refreshed=False):
    last = "no response"
    for attempt in range(1, 4):
        cmd = ["curl", "-sS", "--max-time", str(timeout), "-X", method,
               "-H", f"Authorization: Bearer {token()}",
               "-H", "Content-Type: application/json",
               "-H", "User-Agent: Mozilla/5.0",
               "-w", "\n%{http_code}", API + path]
        if body is not None:
            cmd[1:1] = ["--data-binary", "@-"]
        proc = subprocess.run(
            cmd, input=None if body is None else json.dumps(body),
            text=True, capture_output=True,
        )
        if proc.returncode != 0:
            last = (proc.stderr or proc.stdout).strip()[:300]
            print(f"retry {path} curl {proc.returncode} {last}", flush=True)
            time.sleep(5 * attempt)
            continue
        raw, _, code_s = proc.stdout.rpartition("\n")
        try:
            code = int(code_s)
        except ValueError:
            raise SystemExit(f"bad curl response {path}: {proc.stdout[:200]}")
        err = raw[:600]
        if code == 402 or "exhausted" in err or "Payment Required" in err or "spending-limit" in err:
            print(f"QUOTA {code} {err}")
            sys.exit(2)
        if code in (401, 403) and "bad-credentials" in err and not refreshed:
            refresh_token()
            return api(method, path, body, timeout, refreshed=True)
        if code in (429, 500, 502, 503, 504) and attempt < 3:
            print(f"retry {path} HTTP {code}", flush=True)
            time.sleep(5 * attempt)
            continue
        if code >= 400:
            raise SystemExit(f"HTTP {code} {path} {err}")
        return json.loads(raw)
    raise SystemExit(f"network failed {path}: {last}")


def image_ref(path):
    mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    raw = base64.b64encode(path.read_bytes()).decode()
    return {"url": f"data:{mime};base64,{raw}", "type": "image_url"}


def fetch(url, dest):
    # imgen.x.ai answers 1010 to urllib's default User-Agent, and a slow read
    # used to kill the clip. curl's max-time is a hard cap, with retries.
    last = "download failed"
    for attempt in range(1, 4):
        proc = subprocess.run(
            ["curl", "-fsS", "--max-time", "60", "-A", "Mozilla/5.0", "-o", str(dest), url],
            capture_output=True, text=True,
        )
        if proc.returncode == 0 and dest.exists() and dest.stat().st_size > 1000:
            return
        last = (proc.stderr or "").strip()[:200]
        print(f"retry download {attempt} {last}", flush=True)
        time.sleep(2 * attempt)
    raise SystemExit(f"download failed: {last}")


def save_image(payload, dest):
    if isinstance(payload, str) and payload.startswith("http"):
        fetch(payload, dest)
        return
    if isinstance(payload, dict):
        b64 = payload.get("b64_json") or payload.get("base64")
        if b64:
            dest.write_bytes(base64.b64decode(b64))
            return
        if payload.get("url"):
            fetch(payload["url"], dest)
            return
        for key in ("data", "image", "images"):
            if key in payload:
                item = payload[key]
                save_image(item[0] if isinstance(item, list) else item, dest)
                return
    raise SystemExit(f"no image in response keys={list(payload)[:8] if isinstance(payload, dict) else type(payload)}")


def edit(prompt, *paths):
    return api("POST", "/images/edits", {
        "model": "grok-imagine-image-quality",
        "prompt": prompt,
        "images": [image_ref(p) for p in paths],
        "aspect_ratio": "1:1",
        "resolution": "1k",
    })


def snap_times(length, dur, n):
    """Interior keyframe times, snapped to the 1/3 s grid and kept unique."""
    times = []
    for i in range(1, n + 1):
        raw = dur * i / (n + 1)
        slot = round(raw * 3) / 3
        slot = min(max(slot, 1 / 3), dur - 1 / 3)
        while any(abs(slot - t) < 0.2 for t in times):
            slot = min(slot + 1 / 3, dur - 1 / 3)
        times.append(round(slot, 3))
    return times


def poll_video(request_id):
    # GETs to the video status endpoint often hang; a short timeout and a long
    # deadline still catches a clip that finished server-side.
    deadline = time.time() + 20 * 60
    while time.time() < deadline:
        try:
            data = api("GET", f"/videos/{request_id}", timeout=20)
        except SystemExit:
            raise
        except Exception as e:
            print(f"poll retry {request_id}: {e}", flush=True)
            time.sleep(3)
            continue
        status = data.get("status")
        print(f"video {request_id} {status} {data.get('progress')}", flush=True)
        if status == "done":
            return data["video"]["url"]
        if status in ("failed", "expired"):
            Path("request.txt").unlink(missing_ok=True)
            raise SystemExit(f"video {status}: {json.dumps(data)[:400]}")
        time.sleep(5)
    raise SystemExit(f"video poll timed out {request_id}")


def main():
    fig, slug = sys.argv[1], sys.argv[2]
    src = Path("src.mp4")
    length = float(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(src)],
        text=True).strip())
    dur = min(15, max(2, math.ceil(length)))
    n = 2 if length < 2.6 else 4
    prop = ""
    motion = (ROOT / "config/catalog/motions" / f"{slug}.yml").read_text()
    for line in motion.splitlines():
        if line.startswith("prop:"):
            prop = line.split(":", 1)[1].strip()
    floor = subprocess.check_output([
        "ruby", "-ryaml", "-e",
        'e=YAML.load_file(ARGV[0]); e=e.values.first if e.is_a?(Hash); x=e.find{|h| h["slug"]==ARGV[1]}; print(x["floor"] ? "1" : "")',
        str(ROOT / "config/catalog/exercises.yml"), slug,
    ], text=True).strip()
    proptxt = {
        "chair": "He or she uses a plain sturdy light-wood stool (no back) standing on the floor; hands and feet rest ON its top surface and never pass through it.",
        "wall": "A plain flat cream wall stands behind; the back presses flat against it and never passes through it.",
    }.get(prop, "")
    pose = (
        "Photograph the exact person from image 1 only: same face, same hair, same skin, and the same clothes "
        "(grey t-shirt, black shorts or leggings, white shoes). Image 2 is a featureless mannequin used only "
        f"for joint angles. Do not copy image 2's face, beard, hair, skin, or clothing. Match image 2's body pose "
        f"for {slug}. Keep image 1's camera angle, framing, cream cyclorama and light. {proptxt} "
        "Correct anatomy, natural hands."
    )
    base = ID / f"{fig}_base.jpg"
    subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-frames:v", "1", "src0.png"])
    start = base
    if prop or floor:
        start = Path("pose0.jpg")
        if not (start.exists() and start.stat().st_size > 1000):
            print("edit start pose")
            save_image(edit(
                pose.replace("the body pose of image 2", "the body pose and position of image 2") + f" Start of {slug}.",
                base, Path("src0.png")), start)
        else:
            print("reuse start pose")
    times = snap_times(length, dur, n)
    poses = []
    for i, _t in enumerate(times, start=1):
        at = round(length * i / (n + 1), 2)
        frame = Path(f"src{i}.png")
        subprocess.check_call(["ffmpeg", "-v", "error", "-y", "-ss", str(at), "-i", str(src), "-frames:v", "1", str(frame)])
        dest = Path(f"pose{i}.jpg")
        if dest.exists() and dest.stat().st_size > 1000:
            print(f"reuse pose {i}")
        else:
            print(f"edit pose {i} at {at}s -> key {times[i-1]}s")
            save_image(edit(pose, base, frame), dest)
        poses.append(dest)
    prompt = (
        f"Real filmed fitness demo of {slug}. Static locked-off camera, fixed 3/4 angle, no camera movement, no cuts. "
        "Same person throughout, hair unchanged. Exactly one prop, which never moves, duplicates or changes shape; "
        f"camera never flips or mirrors. {proptxt} Starts in the exact first frame, moves smoothly through the keyframe "
        "poses with natural realistic motion and hands, and ends in the exact starting pose."
    )
    body = {
        "model": "grok-imagine-video-1.5",
        "prompt": prompt,
        "image": image_ref(start),
        "last_frame": image_ref(start),
        "reference_images": [image_ref(ID / f"{fig}.jpg")],
        "keyframes": [{"image": image_ref(p), "timestamp_s": t} for p, t in zip(poses, times)],
        "duration": dur,
        "aspect_ratio": "1:1",
        "resolution": "720p",
    }
    req_path = Path("request.txt")
    if req_path.exists():
        request_id = req_path.read_text().strip()
        print("resume", request_id, flush=True)
    else:
        print(f"video duration {dur} keyframes {times}", flush=True)
        started = api("POST", "/videos/generations", body, timeout=300)
        request_id = started.get("request_id") or started.get("id")
        if not request_id:
            raise SystemExit(f"no request_id: {json.dumps(started)[:400]}")
        req_path.write_text(request_id + "\n")
        print("request", request_id, flush=True)
    url = poll_video(request_id)
    fetch(url, Path("raw.mp4"))
    print("raw", Path("raw.mp4").stat().st_size)


if __name__ == "__main__":
    main()
