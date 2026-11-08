# Exercise loop videos (Vork)

The exercise page plays `public/videos/<slug>.mp4` (poster `<slug>.webp`) when the file exists, and falls back to the live 3D canvas.
The checkbox chip swaps in the interactive canvas.

Pipeline (all local, dev only):
1. `GET /dev/export/<slug>` (development route) poses the app's own rig for one loop at 30 fps and bakes every bone into a
   glTF animation clip on the skinned Quaternius model. It POSTs `tmp/exports/<slug>.glb` and `<slug>.json`
   (tempo, yaw, the app's camera position, target and fov).
2. `script/vork/scene.rb SLUG DIR` writes a Vork scene: the GLB yawed like the app, a washi floor and backdrop (#f7f2e9),
   rect key + fill and a warm environment, the app's camera, the `std/standard` display, 720×720.
3. `vork render` writes PNG frames 0..N-1 (frame N == frame 0, so the loop is seamless).
   ffmpeg encodes H.264 with CRF 23 and `+faststart`. cwebp writes the poster from frame 0.

## Run
```sh
curl -fL https://github.com/voyager-so/vork/releases/latest/download/install.sh -o /tmp/vork-install.sh && sh /tmp/vork-install.sh  # once
bin/rails s -p 3117 -P tmp/pids/3117.pid -d
script/vork/render.sh squat push_up burpees          # or: script/vork/render.sh $(bin/rails runner 'puts Exercise.slugs.join(" ")')
kill $(cat tmp/pids/3117.pid)
```
Env: `OUT` (work dir, default `tmp/vork`), `PROFILE` (`std/final`, or `std/draft` for speed), `CRF` (23), `PORT`, `VORK`, `CHROME`.
Pilot timings on an M4 with `std/final`: about 0.4 s per frame. A 2–4 s loop takes 25–45 s and encodes to 50–120 KB.

Not handled yet: props. The chair and wall exist only in the three.js scene (`Stage#buildProps`), so the export leaves them out.
Add a box mesh in `scene.rb` when `prop` is set (positions are in `buildProps`).
