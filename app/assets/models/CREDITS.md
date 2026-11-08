# mannequin.glb

- Model: "Superhero_Male_FullBody" from **Universal Base Characters** (Standard, free) by Quaternius
- Source: https://quaternius.com/packs/universalbasecharacters.html (also https://quaternius.itch.io/universal-base-characters)
- License: **CC0 1.0** (public domain), https://creativecommons.org/publicdomain/zero/1.0/ (stated on the pack page and in the pack's `License_Standard.txt`)
- Changes: packed the glTF to GLB with textures, UVs and eyebrows removed (flat materials; shirt/shorts/shoes are painted
  per vertex in `app/javascript/mannequin.js`). ~740 KB, ~13k triangles, UE-style humanoid skeleton.

# Exercise videos (`public/videos/male/`, `public/videos/female/`)

- Characters: **Adam** (male) and **Jody** (female) from Adobe **Mixamo** (https://www.mixamo.com), © Adobe, used under the
  Mixamo terms (royalty-free in rendered works; raw character/animation files are not redistributed and are not in this repo).
- Animations: Mixamo motion capture (Air Squat, Push Up, Jumping Jacks, Burpee, Bicycle Crunch, Boxing) for those exercises;
  the rest are Shichimi's own keyframed motions retargeted onto the Mixamo characters (`script/mocap/retarget.py`).
