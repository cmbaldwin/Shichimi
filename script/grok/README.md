# Grok Imagine exercise clips

Real-looking demo videos for `public/videos/<male|female>/<slug>.{mp4,webp}`, made with the logged-in `grok` CLI
(Grok Imagine). They replace the Vork/Mixamo renders. Identity images (AI-generated, ours) are in `identity/`:
`<figure>.jpg` is the identity reference and `<figure>_base.jpg` is the neutral standing start pose.

```bash
script/grok/make.sh male step_up          # one clip
KEEP_RAW=1 script/grok/make.sh male squat # re-run only the ffmpeg post-process on tmp/grok/male/squat/raw.mp4
```

## What make.sh does
1. Copies the existing render to `tmp/grok/<figure>/<slug>/src.mp4` (the motion source) and grabs 2 pose frames (4 for clips over 2.6 s).
   Prop and floor moves (`prop:` in the motion yml, `floor: true` in exercises.yml) first get their own start still (base + render frame 0), which is used as first/last frame, so the stool or floor pose is in the loop frame.
2. `imagine.py` calls the Imagine API with the logged-in grok token (the CLI accepts a video and then drops the status poll).
   - image edit [base, render frame] makes a pose still for each keyframe.
   - reference-to-video: 1:1, 720p, duration = ceil(render length) (2–15 s), first frame = last frame = base (this makes the loop), keyframes = the pose stills, one identity reference.
   - Props (`prop:` in the motion yml): chair becomes a plain stool, wall becomes a plain wall. The prompt says hands and body don't pass through them.
   Exit 2 means the usage balance is exhausted; stop the batch.
3. Downloads the finished mp4 to `raw.mp4`.
4. ffmpeg: a 3-frame crossfade at the loop seam; ≤720p H.264 yuv420p, faststart, no audio; CRF raised until the file is <400 KB. The poster is the first frame through `cwebp` (this ffmpeg has no webp encoder). `strip.png` goes in the tmp dir for review.
5. Appends `date slug figure OK|FAIL note` to `log.txt`.

## Tools grok exposes (CLI, late 2026)
- `image_gen` (aspect 1:1, 16:9, 9:16, 3:2, 2:3).
- `image_edit` (several input images).
- `image_to_video` (6 or 10 s, 480p/720p).
- `reference_to_video`: 1–15 s, 480p/720p, up to 14 refs, `first_frame`/`last_frame`, up to 4 `keyframes`.
- No tool takes an input video, so the form is driven only by keyframes.
- Quota: `grok usage` doesn't show it. Run `/usage` in the TUI. One clip = 1 video + 2–4 image edits.

## Review
Look at `tmp/grok/<figure>/<slug>/strip.png` and the poster contact sheet. Check:
- the same face and hair as the identity (the ponytail can fade mid-clip);
- the camera holds 3/4;
- the form matches the render;
- the props are solid.
For `sides: true` moves (side_plank), make one side only. The app mirrors.
