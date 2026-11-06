/*
 * Shichimi mannequin: one procedural wooden-artist figure (three.js), posed from motions/<slug>.yml.
 *
 * MOTION FORMAT (authoritative). All angles in DEGREES with anatomical meaning; missing = 0.
 *   tempo: 2.0          seconds per full loop through all keys (smoothstep key0→key1→…→key0)
 *   yaw: 30             view yaw of the whole figure (+ = turns toward its own left). Default 30.
 *   mirror: true        append L/R-mirrored copies of the keys (alternating moves: author one side only)
 *   feet: free          disable foot auto-leveling (default: keep soles flat to the floor, see ankles)
 *   prop: chair|wall    chair = 0.45 m seat box, wall = plane; prop_at: [x, z] m in figure space
 *                       (figure faces +Z, its left is +X). Defaults: chair [0, -0.45], wall [0, -0.3].
 *   anchor: { parts: [lhand, rhand], y: 0.45 }  ground those parts at height y instead of the floor.
 *   keys: [ {...}, ... ]  {} = standing rest pose (arms hanging, feet under hips).
 * Key fields:
 *   root:  [pitch, yaw, roll]  whole body about the pelvis. pitch + = tip forward (90 = prone/face-down,
 *          -90 = supine/face-up); yaw + = turn to own left; roll + = lean to own right (90 = lying on right side).
 *          Applied yaw→pitch→roll, interpolated by quaternion slerp (no flips).
 *   spine: [flex, twist, side] flex + = bend forward (crunch), twist + = chest toward own left, side + = to own right.
 *   head:  [flex, turn, tilt]  (or a number = flex) flex + = chin down.
 *   lsh/rsh, lhip/rhip: [flex, abd, twist]  flex + = limb swings forward/up (arm 180 = overhead,
 *          thigh 90 = knee at hip height), abd + = outward away from midline (same sign both sides;
 *          arm 90 = T-pose), twist + = external rotation. Abduction is applied first, then flex.
 *   lel/rel, lkn/rkn: bend + (0 = straight; elbow bends forearm forward, knee bends shin back). Never negative.
 *   lan/ran: plantarflex offset (+ = point toes) added on top of auto-leveling; with feet: free it is
 *          the full ankle angle. Auto-leveled ankles are clamped to −35 (dorsi) … +70 (plantar), so squats keep
 *          heels down and prone poses end up on tucked toes automatically.
 *   shift: [x, z] m translate the body (x + = own left); air: m lifted after grounding (jumps).
 * Grounding: after posing, the body is moved vertically so the lowest contact point (heels, toes, knees, hands,
 *   elbows, head, butt, upper back) touches y = 0. So push-ups/planks/lying poses never need a height.
 * mirrored option (setMotion/renderThumbnail): mirrors the whole motion (side plank other side).
 * Colors: motion.category (cardio|lower|upper|core) or option accent (CSS color) tints the joints.
 */
import * as THREE from "three"

const D = Math.PI / 180
const VEC = { root: 3, spine: 3, head: 3, lsh: 3, rsh: 3, lhip: 3, rhip: 3, lel: 1, rel: 1, lkn: 1, rkn: 1, lan: 1, ran: 1, shift: 2, air: 1 }
const PAIRS = [["lsh", "rsh"], ["lhip", "rhip"], ["lel", "rel"], ["lkn", "rkn"], ["lan", "ran"]]
const FALLBACK = { cardio: "#d1382b", lower: "#e08a1e", upper: "#4f7a3a", core: "#8a4a6b" }
const smooth = (t) => t * t * (3 - 2 * t)
const reducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches

function normKey(k = {}) {
  const o = {}
  for (const [name, n] of Object.entries(VEC)) {
    const v = k[name] == null ? [] : [].concat(k[name])
    o[name] = Array.from({ length: n }, (_, i) => Number(v[i]) || 0)
  }
  return o
}

function mirrorKey(k) {
  const o = structuredClone(k)
  for (const [a, b] of PAIRS) [o[a], o[b]] = [k[b], k[a]]
  o.root = [k.root[0], -k.root[1], -k.root[2]]
  o.spine = [k.spine[0], -k.spine[1], -k.spine[2]]
  o.head = [k.head[0], -k.head[1], -k.head[2]]
  o.shift = [-k.shift[0], k.shift[1]]
  return o
}

function prepare(motion, mirrored) {
  const m = motion || {}
  let keys = (m.keys?.length ? m.keys : [{}]).map(normKey)
  if (m.mirror) keys = keys.concat(keys.map(mirrorKey))
  if (mirrored) keys = keys.map(mirrorKey)
  const swap = { lhand: "rhand", rhand: "lhand", lelbow: "relbow", relbow: "lelbow", lknee: "rknee", rknee: "lknee" }
  let anchor = m.anchor
  if (anchor && mirrored) anchor = { ...anchor, parts: anchor.parts.map((p) => swap[p] || p) }
  return {
    keys, anchor,
    tempo: Number(m.tempo) || 2,
    yaw: (m.yaw ?? 30) * (mirrored ? -1 : 1),
    feetFree: m.feet === "free",
    prop: m.prop, propAt: m.prop_at, mirrored,
    category: m.category
  }
}

function lerpKey(a, b, t) {
  const o = {}
  for (const name in VEC) o[name] = a[name].map((v, i) => v + (b[name][i] - v) * t)
  return o
}

const rootQuat = (r) => new THREE.Quaternion().setFromEuler(new THREE.Euler(r[0] * D, r[1] * D, r[2] * D, "YXZ"))

// ---------- figure ----------
class Rig {
  constructor() {
    this.body = new THREE.MeshStandardMaterial({ color: 0xd9bf98, roughness: 0.55, metalness: 0 })
    this.accent = new THREE.MeshStandardMaterial({ color: 0x8a4a6b, roughness: 0.45 })
    this.markers = {}
    const g = (parent, x, y, z) => { const o = new THREE.Group(); o.position.set(x, y, z); parent.add(o); return o }
    const mesh = (parent, geo, mat, x = 0, y = 0, z = 0, s) => {
      const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); if (s) m.scale.set(...s)
      m.castShadow = true; parent.add(m); return m
    }
    const cap = (parent, r, len, mat = this.body) => mesh(parent, new THREE.CapsuleGeometry(r, len - 2 * r * 0.6, 6, 14), mat, 0, -len / 2)
    const ball = (parent, r, mat = this.accent) => mesh(parent, new THREE.SphereGeometry(r, 18, 12), mat)
    const mark = (name, parent, r, x = 0, y = 0, z = 0) => { this.markers[name] = [g(parent, x, y, z), r] }

    this.root = new THREE.Group()
    this.root.position.y = 0.92
    mesh(this.root, new THREE.SphereGeometry(0.13, 20, 14), this.body, 0, 0.0, 0, [1.25, 0.8, 0.9])
    mark("butt", this.root, 0.1, 0, 0, -0.02)

    this.spine = g(this.root, 0, 0.07, 0)
    mesh(this.spine, new THREE.SphereGeometry(0.1, 18, 12), this.body, 0, 0.1, 0, [1.05, 1.1, 0.85])
    mesh(this.spine, new THREE.SphereGeometry(0.17, 22, 16), this.body, 0, 0.29, 0, [1.1, 1, 0.72])
    mark("back", this.spine, 0.12, 0, 0.3, 0)
    this.neck = g(this.spine, 0, 0.44, 0)
    ball(this.neck, 0.045, this.body).position.y = 0.03
    const head = mesh(this.neck, new THREE.SphereGeometry(0.105, 22, 16), this.body, 0, 0.14, 0.01, [0.92, 1.1, 1])
    mesh(head, new THREE.SphereGeometry(0.03, 10, 8), this.accent, 0, -0.02, 0.1) // nose: shows facing
    mark("head", this.neck, 0.11, 0, 0.14, 0)

    for (const [s, x] of [["l", 1], ["r", -1]]) {
      const sh = this[s + "sh"] = g(this.spine, 0.2 * x, 0.38, 0)
      ball(sh, 0.058)
      cap(sh, 0.046, 0.29)
      const el = this[s + "el"] = g(sh, 0, -0.29, 0)
      ball(el, 0.044)
      cap(el, 0.039, 0.25)
      ball(el, 0.048, this.body).position.y = -0.3
      mark(s + "elbow", el, 0.045)
      mark(s + "hand", el, 0.048, 0, -0.3, 0)

      const hip = this[s + "hip"] = g(this.root, 0.095 * x, -0.02, 0)
      ball(hip, 0.07, this.body)
      cap(hip, 0.068, 0.42)
      const kn = this[s + "kn"] = g(hip, 0, -0.42, 0)
      ball(kn, 0.058)
      cap(kn, 0.052, 0.42)
      mark(s + "knee", kn, 0.058)
      const an = this[s + "an"] = g(kn, 0, -0.42, 0)
      ball(an, 0.042)
      const foot = mesh(an, new THREE.CapsuleGeometry(0.042, 0.15, 4, 10), this.body, 0, -0.038, 0.05, [1.05, 0.9, 1])
      foot.rotation.x = Math.PI / 2
      mark(s + "heel", an, 0, 0, -0.08, -0.07)
      mark(s + "toe", an, 0, 0, -0.08, 0.17)
    }
  }

  pose(k, { feetFree, anchor }) {
    this.root.position.set(k.shift[0], 0.92, k.shift[1])
    this.root.quaternion.copy(k.q || rootQuat(k.root))
    this.spine.rotation.set(k.spine[0] * D, k.spine[1] * D, k.spine[2] * D, "XZY")
    this.neck.rotation.set(k.head[0] * D, k.head[1] * D, k.head[2] * D, "XZY")
    for (const [s, x] of [["l", 1], ["r", -1]]) {
      const sh = k[s + "sh"], hp = k[s + "hip"]
      this[s + "sh"].rotation.set(-sh[0] * D, sh[2] * D * x, sh[1] * D * x, "XZY")
      this[s + "hip"].rotation.set(-hp[0] * D, hp[2] * D * x, hp[1] * D * x, "XZY")
      this[s + "el"].rotation.x = -k[s + "el"][0] * D
      this[s + "kn"].rotation.x = k[s + "kn"][0] * D
      this[s + "an"].rotation.x = 0
    }
    this.root.updateMatrixWorld(true)
    const q = new THREE.Quaternion(), up = new THREE.Vector3()
    for (const s of ["l", "r"]) {
      let a = k[s + "an"][0] * D
      if (!feetFree) {
        up.set(0, 1, 0).applyQuaternion(this[s + "kn"].getWorldQuaternion(q).invert())
        a = THREE.MathUtils.clamp(Math.atan2(up.z, up.y) + a, -35 * D, 70 * D)
      }
      this[s + "an"].rotation.x = a
    }
    this.root.updateMatrixWorld(true)
    const p = new THREE.Vector3()
    const low = (n) => { const [o, r] = this.markers[n]; return o.getWorldPosition(p).y - r }
    let dy
    if (anchor?.parts?.length) dy = Number(anchor.y || 0) - anchor.parts.reduce((s, n) => s + low(n), 0) / anchor.parts.length
    else dy = -Math.min(...Object.keys(this.markers).map(low))
    this.root.position.y += dy + k.air[0]
    this.root.updateMatrixWorld(true)
  }
}

function softDiscTexture() {
  const c = document.createElement("canvas"); c.width = c.height = 128
  const x = c.getContext("2d"), gr = x.createRadialGradient(64, 64, 0, 64, 64, 64)
  gr.addColorStop(0, "rgba(255,255,255,1)"); gr.addColorStop(0.7, "rgba(255,255,255,.75)"); gr.addColorStop(1, "rgba(255,255,255,0)")
  x.fillStyle = gr; x.fillRect(0, 0, 128, 128)
  return new THREE.CanvasTexture(c)
}

function accentColor(category, accent) {
  if (accent) return accent
  const css = category && getComputedStyle(document.documentElement).getPropertyValue(`--${category}`).trim()
  return css || FALLBACK[category] || "#b0896a"
}

// Scene + camera + one rig. Shared by the live canvas and the thumbnail renderer.
class Stage {
  constructor() {
    this.scene = new THREE.Scene()
    this.camera = new THREE.PerspectiveCamera(30, 1, 0.05, 50)
    this.scene.add(new THREE.HemisphereLight(0xfff4e6, 0x5a4a3a, 1.6))
    const key = new THREE.DirectionalLight(0xffffff, 2.2)
    key.position.set(1.5, 4, 2.5); key.castShadow = true
    key.shadow.mapSize.set(1024, 1024); key.shadow.radius = 4; key.shadow.bias = -0.0005
    Object.assign(key.shadow.camera, { left: -1.6, right: 1.6, top: 1.6, bottom: -1.6, near: 0.5, far: 10 })
    this.scene.add(key)
    const fill = new THREE.DirectionalLight(0xffe2c4, 0.7); fill.position.set(-3, 1.5, 1); this.scene.add(fill)

    this.discMat = new THREE.MeshBasicMaterial({ map: softDiscTexture(), transparent: true, opacity: 0.22, depthWrite: false })
    this.disc = new THREE.Mesh(new THREE.CircleGeometry(1, 48), this.discMat)
    this.disc.rotation.x = -Math.PI / 2
    this.shadow = new THREE.Mesh(new THREE.CircleGeometry(1, 48), new THREE.ShadowMaterial({ opacity: 0.28 }))
    this.shadow.rotation.x = -Math.PI / 2; this.shadow.position.y = 0.001; this.shadow.receiveShadow = true
    this.scene.add(this.disc, this.shadow)

    this.container = new THREE.Group()
    this.rig = new Rig()
    this.props = new THREE.Group()
    this.container.add(this.rig.root, this.props)
    this.scene.add(this.container)
    this.yawOffset = 0
  }

  load(motion, { mirrored = false, accent } = {}) {
    this.m = prepare(motion, mirrored)
    for (const k of this.m.keys) k.q = rootQuat(k.root)
    const c = new THREE.Color(accentColor(this.m.category, accent))
    this.rig.accent.color.copy(c)
    this.discMat.color.copy(c)
    this.buildProps()
    // fit the camera once to the bounds of every key at the base yaw
    this.container.rotation.y = this.m.yaw * D
    const box = new THREE.Box3()
    this.m.keys.forEach((_, i) => { this.poseKey(i); box.union(new THREE.Box3().setFromObject(this.container)) })
    this.box = box
    const r = Math.max(0.5, Math.hypot(box.max.x - box.min.x, box.max.z - box.min.z) / 2 * 0.85)
    this.disc.scale.setScalar(r); this.shadow.scale.setScalar(r * 1.3)
    const cx = (box.min.x + box.max.x) / 2, cz = (box.min.z + box.max.z) / 2
    this.disc.position.set(cx, 0, cz); this.shadow.position.set(cx, 0.001, cz)
    this.poseKey(0)
  }

  buildProps() {
    this.props.clear()
    const mat = new THREE.MeshStandardMaterial({ color: 0xb8a68c, roughness: 0.8 })
    const [x, z] = this.m.propAt || (this.m.prop === "wall" ? [0, -0.3] : [0, -0.45])
    const add = (geo, px, py, pz) => { const o = new THREE.Mesh(geo, mat); o.position.set(x + px, py, z + pz); o.castShadow = o.receiveShadow = true; this.props.add(o) }
    if (this.m.prop === "chair") {
      add(new THREE.BoxGeometry(0.44, 0.05, 0.42), 0, 0.425, 0)
      for (const [a, b] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) add(new THREE.BoxGeometry(0.035, 0.4, 0.035), a * 0.19, 0.2, b * 0.18)
    } else if (this.m.prop === "wall") {
      add(new THREE.BoxGeometry(1.2, 1.7, 0.04), 0, 0.85, -0.02)
    }
  }

  poseKey(i) { this.rig.pose(this.m.keys[i % this.m.keys.length], this.m) }

  poseAt(seconds) {
    const ks = this.m.keys, n = ks.length
    const u = (seconds / (this.m.tempo / n)) % n
    const i = Math.floor(u), t = smooth(u - i), a = ks[i], b = ks[(i + 1) % n]
    const k = lerpKey(a, b, t)
    k.q = a.q.clone().slerp(b.q, t)
    this.rig.pose(k, this.m)
  }

  frame(aspect) {
    this.container.rotation.y = (this.m.yaw * D) + this.yawOffset
    const b = this.box, half = Math.tan(this.camera.fov * D / 2)
    const c = b.getCenter(new THREE.Vector3()), s = b.getSize(new THREE.Vector3())
    const h = s.y / 2 + 0.06, w = s.x / 2 + 0.06
    const dist = Math.max(h / half, w / (half * aspect)) * 1.08 + s.z / 2
    const el = 10 * D
    this.camera.aspect = aspect
    this.camera.position.set(c.x, c.y + Math.sin(el) * dist, c.z + Math.cos(el) * dist)
    this.camera.lookAt(c.x, c.y - 0.02, c.z)
    this.camera.updateProjectionMatrix()
  }
}

function makeRenderer(canvas, opts = {}) {
  const r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, ...opts })
  r.setClearColor(0x000000, 0)
  r.shadowMap.enabled = true
  r.shadowMap.type = THREE.PCFSoftShadowMap
  return r
}

export class Mannequin {
  constructor(canvas, { motion = null, mirrored = false, autoplay = true, interactive = true, accent } = {}) {
    this.canvas = canvas
    this.accent = accent
    this.renderer = makeRenderer(canvas)
    this.stage = new Stage()
    this.speed = 1; this.time = 0; this.playing = autoplay; this.visible = true
    this.setMotion(motion, { mirrored })
    this.tick = this.tick.bind(this)

    this.resize = () => {
      const w = canvas.clientWidth || 300, h = canvas.clientHeight || 300
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
      this.renderer.setSize(w, h, false)
      this.aspect = w / h
      this.draw()
    }
    this.ro = new ResizeObserver(this.resize); this.ro.observe(canvas)
    this.io = new IntersectionObserver(([e]) => { this.visible = e.isIntersecting; this.loop() })
    this.io.observe(canvas)
    this.onVis = () => this.loop()
    document.addEventListener("visibilitychange", this.onVis)
    if (interactive) this.bindDrag()
    this.resize()
    this.loop()
  }

  setMotion(motion, { mirrored = false } = {}) {
    this.stage.load(motion, { mirrored, accent: this.accent })
    this.time = 0
    this.draw()
  }

  play() { this.playing = true; this.loop() }
  pause() { this.playing = false }
  setSpeed(x) { this.speed = Number(x) || 1 }

  get running() { return this.playing && this.visible && !document.hidden && !reducedMotion() }

  loop() {
    if (this.raf || !this.running) return
    this.last = performance.now()
    this.raf = requestAnimationFrame(this.tick)
  }

  tick(now) {
    this.raf = null
    if (!this.running) return
    this.time += Math.min(0.1, (now - this.last) / 1000) * this.speed
    this.last = now
    this.draw()
    this.raf = requestAnimationFrame(this.tick)
  }

  draw() {
    if (!this.aspect) return
    if (reducedMotion()) this.stage.poseKey(0); else this.stage.poseAt(this.time)
    this.stage.frame(this.aspect)
    this.renderer.render(this.stage.scene, this.stage.camera)
  }

  bindDrag() {
    let x0 = null
    this.canvas.style.touchAction = "pan-y"
    this.canvas.style.cursor = "grab"
    this.canvas.addEventListener("pointerdown", (e) => { x0 = e.clientX; this.canvas.setPointerCapture(e.pointerId) })
    this.canvas.addEventListener("pointermove", (e) => {
      if (x0 == null) return
      this.stage.yawOffset += (e.clientX - x0) * 0.012; x0 = e.clientX
      if (!this.running) this.draw()
    })
    const up = () => { x0 = null }
    this.canvas.addEventListener("pointerup", up); this.canvas.addEventListener("pointercancel", up)
  }

  dispose() {
    cancelAnimationFrame(this.raf); this.raf = null; this.playing = false
    this.ro.disconnect(); this.io.disconnect()
    document.removeEventListener("visibilitychange", this.onVis)
    this.renderer.dispose()
    this.renderer.forceContextLoss()
  }
}

let shared // one offscreen renderer + stage for every thumbnail on the page
export function renderThumbnail(motion, { key = 0, width = 240, height = 240, mirrored = false, accent } = {}) {
  shared ||= { renderer: makeRenderer(document.createElement("canvas"), { preserveDrawingBuffer: true }), stage: new Stage() }
  const { renderer, stage } = shared
  renderer.setPixelRatio(1)
  renderer.setSize(width, height, false)
  stage.load(motion, { mirrored, accent })
  stage.poseKey(key)
  stage.frame(width / height)
  renderer.render(stage.scene, stage.camera)
  return renderer.domElement.toDataURL("image/png")
}
export { THREE }
