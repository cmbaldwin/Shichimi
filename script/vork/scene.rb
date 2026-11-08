#!/usr/bin/env ruby
# Builds a Vork scene for one exercise from tmp/exports/<slug>.{glb,json} (made by /dev/export/<slug>).
# Usage: ruby script/vork/scene.rb SLUG OUT_DIR   → OUT_DIR/<slug>.json (+ copies the GLB beside it)
# Look: seamless washi cyclorama (floor curving into the backdrop, so no horizon line), three-point studio
# light (soft key, warm fill, cool rim) over a dim environment, AgX "punchy", camera fitted to the whole loop.
require "json"
require "yaml"
require "fileutils"

slug, out = ARGV
abort "usage: scene.rb SLUG OUT_DIR" unless slug && out
root = File.expand_path("../..", __dir__)
src = ENV.fetch("SRC", "#{root}/tmp/exports")        # Mixamo: SRC=tmp/mixamo/<character> (script/mocap/mixamo_glb.py)
meta = JSON.parse(File.read("#{src}/#{slug}.json"))
motion = YAML.load_file("#{root}/config/catalog/motions/#{slug}.yml")
FileUtils.mkdir_p(out)
FileUtils.cp("#{src}/#{slug}.glb", "#{out}/#{slug}.glb")

lin = ->(hex) { hex.scan(/../).map { |c| v = c.to_i(16) / 255.0; v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 } }
add = ->(a, b, s = 1) { a.zip(b).map { _1 + _2 * s } }
yaw = meta["yaw"] * Math::PI / 180
# three.js rotation.y: figure space → world
rot = ->(x, z) { [ x * Math.cos(yaw) + z * Math.sin(yaw), -x * Math.sin(yaw) + z * Math.cos(yaw) ] }

# --- framing: the export box spans every key of the loop (world space, after yaw)
bmin, bmax = meta["box"]["min"], meta["box"]["max"]
# Mixamo: lowest point of the loop touches the floor (shoe soles), except chair moves where the seat is the anchor
lift = meta["mixamo"] && motion["prop"] != "chair" ? -bmin[1] : 0
bmin, bmax = [ bmin[0], bmin[1] + lift, bmin[2] ], [ bmax[0], bmax[1] + lift, bmax[2] ] if meta["mixamo"]
center = bmin.zip(bmax).map { (_1 + _2) / 2 }
corners = [ 0, 1 ].product([ 0, 1 ], [ 0, 1 ]).map { |i, j, k| [ [ bmin, bmax ][i][0], [ bmin, bmax ][j][1], [ bmin, bmax ][k][2] ] }
floor_move = (bmax[1] - bmin[1]) < 1.2                 # push-up, plank…: look down a little more
elev = (floor_move ? 22 : 10) * Math::PI / 180
dir = [ 0, Math.sin(elev), Math.cos(elev) ]            # target → camera (app camera looks along -Z)
fov = 30.0
half = Math.tan(fov / 2 * Math::PI / 180) / 1.07       # 7% margin each side
right = [ 1, 0, 0 ]
up = [ 0, Math.cos(elev), -Math.sin(elev) ]
dot = ->(a, b) { a.zip(b).sum { _1 * _2 } }
# smallest distance where every corner fits in the square frustum; centre on the projected extents
fit = lambda do |c, d|
  cam = add.(c, dir, d)
  corners.map { |p| v = add.(p, cam, -1); z = -dot.(v, dir); [ dot.(v, right) / z, dot.(v, up) / z ] }
end
d = 2.0
40.times do
  pr = fit.(center, d)
  xs, ys = pr.map(&:first), pr.map(&:last)
  # recentre on the projection, then scale distance to the larger extent
  center = add.(center, right, (xs.max + xs.min) / 2 * d)
  center = add.(center, up, (ys.max + ys.min) / 2 * d)
  d *= [ (xs.max - xs.min) / 2, (ys.max - ys.min) / 2 ].max / half
end
cam = add.(center, dir, d)
lens = 18.0 / Math.tan(fov / 2 * Math::PI / 180)

# --- cyclorama: floor → quarter-round cove → wall, behind the figure, facing the camera
washi = lin.("f7f2e9")
cz, wall_z, r = center[2], bmin[2] - 1.6, 1.2
profile = [ [ cam[2] + 2, 0.0 ] ]                      # [z, y] from in front of the camera back to the wall
12.times { |i| a = i / 11.0 * Math::PI / 2; profile << [ wall_z + r - Math.sin(a) * r, r - Math.cos(a) * r ] }
profile << [ wall_z, 12.0 ]
pos, idx = [], []
profile.each { |z, y| [ -12.0, 12.0 ].each { |x| pos.push(center[0] + x, y, z) } }
(profile.size - 1).times { |i| a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2) }
nrm = profile.each_with_index.flat_map do |(z, y), i|
  n = if i.zero? then [ 0, 1, 0 ] elsif i == profile.size - 1 then [ 0, 0, 1 ]
      else a = (i - 1) / 11.0 * Math::PI / 2; [ 0, Math.cos(a), Math.sin(a) ]
  end
  n + n
end

skin = { base_color: { attribute: "COLOR_0" }, specular_roughness: 0.55, specular_weight: 0.6,
         subsurface_weight: 0.25, subsurface_color: { attribute: "COLOR_0" }, subsurface_radius: 0.004,
         fuzz_weight: 0.1, fuzz_roughness: 0.6, fuzz_color: [ 1, 0.97, 0.94 ] }
wood = lin.("d9b98f")

nodes = [
  { type: "asset", name: "fig", file: "#{slug}.glb", rotation: { euler: [ 0, yaw, 0 ] }, translation: [ 0, lift, 0 ],
    materials: meta["mixamo"] ? {} : { "Body" => { inputs: skin } } },
  { type: "mesh", name: "cyc", geometry: { attributes: { POSITION: { type: "vec3", data: pos.each_slice(3).to_a }, NORMAL: { type: "vec3", data: nrm.each_slice(3).to_a } },
                                           indices: { type: "u32", data: idx } },
    materials: [ { inputs: { base_color: washi.map { _1 * 0.95 }, specular_roughness: 0.9, specular_weight: 0.0 } } ] },
  # key: big soft box high camera-left-front; fill: dim warm bounce camera-right; rim: cool kicker behind
  { type: "light", name: "key", shape: "rectangle", translation: [ center[0] - 2.4, 3.8, cz + 2.6 ], target: [ center[0], 0.9, cz ],
    energy: 240, size: 1.4, color: [ 1, 0.95, 0.88 ] },
  { type: "light", name: "fill", shape: "rectangle", translation: [ center[0] + 3.2, 1.6, cz + 2.4 ], target: [ center[0], 0.8, cz ],
    energy: 30, size: 3, color: [ 1, 0.9, 0.8 ] },
  { type: "light", name: "rim", shape: "rectangle", translation: [ center[0] + 1.8, 2.8, cz - 2.2 ], target: [ center[0], 1.0, cz ],
    energy: 260, size: 1.0, color: [ 0.88, 0.93, 1 ], illuminates: [ "fig" ] },
  { type: "light", name: "sky", shape: "environment", energy: 0.25, color: [ 1, 0.97, 0.93 ] },
  { type: "camera", name: "cam", translation: cam, target: center,
    material: { program: "std/camera", inputs: { lens: lens, sensor_width: 36 } } }
]
nodes[0][:light_link_tags] = [ "fig" ]

# props (figure space, as Stage#buildProps), rotated by yaw like the figure
if (prop = motion["prop"])
  px, pz = motion["prop_at"] || (prop == "wall" ? [ 0, -0.3 ] : [ 0, -0.45 ])
  box = ->(name, sx, sy, sz, x, y, z, mat) do
    wx, wz = rot.(px + x, pz + z)
    { type: "mesh", name:, translation: [ wx, y, wz ], rotation: { euler: [ 0, yaw, 0 ] },
      geometry: { std: "box", size: [ sx, sy, sz ] }, materials: [ mat ] }
  end
  wood_m = { inputs: { base_color: wood, specular_roughness: 0.5, coat_weight: 0.3, coat_roughness: 0.35 } }
  if prop == "chair"
    nodes << box.("seat", 0.44, 0.05, 0.42, 0, 0.425, 0, wood_m)
    [ [ 1, 1 ], [ 1, -1 ], [ -1, 1 ], [ -1, -1 ] ].each_with_index do |(a, b), i|
      nodes << box.("leg#{i}", 0.035, 0.4, 0.035, a * 0.19, 0.2, b * 0.18, wood_m)
    end
  elsif prop == "wall"
    nodes << box.("wall", 1.2, 1.7, 0.04, 0, 0.85, -0.02, { inputs: { base_color: lin.("e8e0d2"), specular_roughness: 0.9 } })
  end
end

scene = {
  version: 2,
  nodes:,
  animation: [ { clip: { target: "fig", name: "loop" }, loop: true } ],
  render: { display: { program: "std/standard" }, resolution: [ 720, 720 ], fps: meta["fps"], duration: meta["tempo"],
            background: washi }
}
File.write("#{out}/#{slug}.json", JSON.pretty_generate(scene))
puts "#{out}/#{slug}.json frames=#{meta["frames"]}"
