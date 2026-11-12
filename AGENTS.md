# AGENTS.md: Shichimi (七味)

A PWA for guided 7-minute body-weight workouts: 30 exercises, each with a procedural 3D
mannequin animation, 100 science-backed workouts in 7 timing formats, routines, history,
analytics and push reminders. The name is a pun: *shichi* (七) = 7, and shichimi tōgarashi is a
seven-spice blend, so each of the 7 formats is named after one spice.

Live target: **https://shichimi.moab.jp** on the moab box (5.223.44.132), deployed with Kamal
the same way as akotacos. See the fleet notes in `/Users/cody/Dev/AGENTS.md`.

## Stack

Ruby 4.0.9, Rails 8.1, SQLite (WAL), Propshaft and importmaps, Hotwire (Turbo and Stimulus), plain CSS,
Solid Queue in Puma, Minitest. Auth is the Rails 8 generator (`Session` = login session) plus
`RegistrationsController`. three.js r170 is vendored at `vendor/javascript/three.js` (`import * as THREE from "three"`).
No Node or bundler. JS deps are **vendored** in `vendor/javascript` (`bin/importmap pin x` downloads them). Never pin to a CDN URL.
Gems already added: `web-push`, `uchujin` (error tracker, cmbaldwin/Uchujin), test: `capybara selenium-webdriver minitest-mock slickrock` (cmbaldwin/slickrock).
Don't add more without a strong reason.

## Data model (contract: don't rename)

| Thing | Where | Notes |
|---|---|---|
| `Exercise` | `app/models/exercise.rb`, a `Data` PORO loaded from `config/catalog/exercises.yml` + `config/catalog/motions/<slug>.yml` | `Exercise.all / find(slug) / find_by(slug) / slugs / categories`, `#to_player` |
| `WorkoutFormat` | `app/models/workout_format.rb`, a PORO from `config/catalog/formats.yml` | 7 formats: classic, sprint, tabata, fifty_ten, forty_twenty, easy, double. `#total_seconds(n)` |
| `Workout` | DB. `user_id` nil = catalog (synced from `config/catalog/workouts.yml` by `Workout.sync_catalog!` in seeds) | `exercise_slugs` JSON. `#timeline`, `#same_category_neighbours`, derived `low_impact / needs_floor / equipment / total_seconds` |
| `RoutineItem` | DB | user's ordered rotation. `User#next_routine_workout` |
| `WorkoutLog` | DB, routes at `/history` | one finished (or partly finished) workout: snapshot of name/format/timing, `completed_slugs`, `duration_seconds`, `performed_at`, `rpe` (Borg CR10 1–10), `avg_hr`/`max_hr` (nullable, 30..240, from Web Bluetooth strap), `notes`, `#heart_rate(:avg_hr)`. `GET /history/:id.tcx` |
| `PushSubscription` | DB | endpoint, p256dh_key, auth_key |
| `User` | DB | `time_zone` (IANA), `weight_kg` (optional, used for kcal), `weekly_goal`, `reminders_enabled`, `reminder_time` "HH:MM", `reminder_days` (wday digits "0123456", 0=Sun), `last_reminded_on`, `voice` ("female"/"male"/"off"). Helpers `zone`, `today`, `display_name` |

Exercise categories: `cardio lower upper core`. The colors are the CSS tokens `--cardio --lower --upper --core`.
Exercise structural fields (slug, name, category, impact, level, equipment, floor, sides) are fixed in exercises.yml.
Each exercise also has `reference: { video_url, video_title, video_channel, source_url, source_name }`: a YouTube demo (checked with YouTube's oEmbed endpoint) and an official written form guide (ACE first, then NASM, Mayo, NHS or Cleveland Clinic). It is shown as "See it done" on the exercise page and enforced by `catalog_test.rb`. Motions were reviewed against these references.

### `Workout#timeline` (player contract)
Array of steps: `{ kind: "prep"|"work"|"rest", seconds:, slug:, round:, index:, switch_at: }`.
Prep and rest steps carry the slug of the **upcoming** exercise. `switch_at` (seconds into the work step)
appears only for `sides: true` exercises (side plank): at that point the player cues "switch sides" and mirrors the figure.

### Science rules for workouts (enforced by `test/models/catalog_test.rb`)
- Station count equals `format.stations`. All slugs exist. Names and slugs are unique. There are exactly 100 catalog workouts.
- No two adjacent exercises share a category (Klika & Jordan 2013). This includes the last→first wrap
  when rounds run back to back (`Workout#same_category_neighbours` must be empty).
- `focus` is one of `full cardio lower upper core quiet standing`. `quiet` means every exercise has `impact: low`
  (apartment-friendly, so no jumping). `standing` means no exercise has `floor: true`.

## Mannequin API (`app/javascript/mannequin.js`, pinned as `"mannequin"`)

```js
import { Mannequin, renderThumbnail } from "mannequin"
const m = new Mannequin(canvas, { motion, mirrored: false, autoplay: true, interactive: true })
m.setMotion(motion, { mirrored })   // swap exercise (player does this every step)
m.play(); m.pause(); m.setSpeed(1); m.dispose()
renderThumbnail(motion, { key: 0, width: 240, height: 240, mirrored: false }) // → data URL (shared offscreen renderer)
```
`modelReady()` (also exported) resolves `true` once thumbnails use the realistic model (`false` = procedural fallback);
`thumb_controller` re-renders after it, the dev sheet awaits it.

**Realistic body.** `app/assets/models/mannequin.glb` = Quaternius *Universal Base Characters* male (CC0,
https://quaternius.com/packs/universalbasecharacters.html, see `app/assets/models/CREDITS.md`), textures stripped,
outfit painted per vertex by dominant bone (shirt = category accent). Its digested URL comes from
`<meta name="mannequin-model">` in the layout (and `dev/motion`). GLTFLoader r170 is vendored
(`three/addons/...` pins). Retargeting: the old procedural `Rig` is still posed (hidden) from the motion keys; each
driven bone gets world rotation = rig segment world rotation × a rest offset measured once with both in T-pose, then the
model is grounded by markers on its own bones (heels, toes, knees, hands, elbows, head, butt, back). Motion files are unchanged.
`motion` is the parsed `motions/<slug>.yml` (it's in `Exercise#to_player[:motion]`). Stimulus wrappers:
`figure_controller.js` (`data-controller="figure" data-figure-motion-value="<json>"` on a `<canvas>`)
and `thumb_controller.js` (on an `<img>`, with `data-thumb-motion-value` and `data-thumb-key-value`). Only one live
WebGL canvas per page (the browser caps contexts). Use thumbnails for lists.

### Motion file format (`config/catalog/motions/<slug>.yml`)
Defined by the rig pass; the authoritative description is the header comment of `mannequin.js`. Outline:
```yaml
tempo: 2.0            # seconds per loop through all keys
yaw: 30               # default facing (deg) for the clearest view
prop: chair           # optional: chair | wall
keys:                 # poses, splined key0→key1→…→key0 (monotone cubic: smooth pass-through, soft stop at reversals). {} = standing rest pose.
  - { t: 1.4, hold: 0.2 }   # t = relative length of the segment leaving this key (default 1; tempo unchanged), hold = paused fraction of it
  - { root: [pitch, yaw, roll], spine: [flex, twist, side], lhip: [flex, abd, twist], lkn: 90, air: 0.1 }
```
A ~1° breathing oscillation (spine/shoulders) is added at runtime, so static holds need only one pose plus subtle extra keys.

Hands (realistic model): fingers curl by `hands:` in the motion file (`relaxed` default, `fist`). A hand is auto-planted (wrist extended, palm flat, fingers forward) when its forearm points down and its fingertips or palm reach the floor or anchor height. If a weight-bearing hand floats on the contact sheet, flatten the body angle a little (planks need root pitch ≈ shoulder flex ≈ 70–75° for this model's arm length).

## Secrets and TLS (user policy)
- **Kamal secrets only. No Rails encrypted credentials** (no `config/credentials.yml.enc` reads, no `RAILS_MASTER_KEY`).
  Every secret is an ENV var injected by `.kamal/secrets`, fetched with `kamal secrets fetch --adapter 1password`
  from the **moab app's shared `Production` vault** (same as `/Users/cody/Dev/moab/.kamal/secrets`). `SECRET_KEY_BASE` too.
- In dev, secrets come from a gitignored `.env` (or a dev-only fallback). Never commit keys.
- TLS: `shichimi.moab.jp` is already an orange-cloud A record to 5.223.44.132. Use the same Cloudflare Origin CA
  setup as akotacos and moab (`CLOUDFLARE_SSL_CERT_PEM` / `CLOUDFLARE_SSL_KEY_PEM` passed by secret name), not ACME.

## Product themes (from the user's naming shortlist; the name stays Shichimi)
- **Shichimi 七味**: seven spices, seven formats (`formats.yml` `spice`/`ja`/`heat`).
- **Nanairo 七色**: one color per format. Set `data-format="<key>"` and use `var(--format)` (see application.css).
- **Shichifuku 七福**: the Seven Lucky Gods unlock at streak/total milestones (`Stats#lucky_gods`, partial `stats/_lucky_gods`).
- **Nanakorobi yaoki 七転び八起き**: "Fall seven times, get up eight." Shown on Today after a missed day.
- **NanaFun 七分** (nana-fun = seven minutes) and **cup ramen** ("shorter than two cup ramens and change"): landing and marketing copy.

## File ownership (parallel agents: stay in your lane)

| Area | Owns |
|---|---|
| Catalog | `config/catalog/exercises.yml` content fields, `config/catalog/workouts.yml`, `test/models/catalog_test.rb`, `test/models/workout_test.rb` |
| Science | `config/catalog/formats.yml` `science` text, `config/catalog/references.yml`, `app/views/pages/science.html.erb`, `PagesController` |
| Install guide | `app/views/pages/install.html.erb` (CSS mockups in `install.css`, not real screenshots), `install_controller.js` (`beforeinstallprompt` button, standalone detection) |
| Player sounds | `public/audio/voice/` (voice clips), `script/voices/*`, `player_controller.js` `preload/say/sfx/bell`. Chimes are synthesized by `bell()` (no SFX files: the old Kenney clips were 10 ms clicks from a bad fade and too slight anyway). Ticks fire on the last 3 s of every step longer than 4 s |
| 3D rig | `app/javascript/mannequin.js`, `figure_controller.js`, `thumb_controller.js`, `ExercisesController` + `app/views/exercises/*`, `exercises.css` |
| Motions | `config/catalog/motions/*.yml` |
| Player | `WorkoutsController#show #play`, `app/views/workouts/show + play`, `player_controller.js`, `WorkoutLogsController#create #show #update`, `app/views/workout_logs/show`, `player.css` |
| App flows | `HomeController`, `WorkoutsController#index #new #create #edit #update #destroy` + views, `RoutineItemsController`, `WorkoutLogsController#index #destroy` + index view, `SettingsController`, sessions and registration views, `flows.css` |
| Stats | `app/models/stats.rb`, `StatsController`, `app/views/stats/*`, `stats.css`, `test/models/stats_test.rb`, `lib/tasks/dev.rake` (sample logs) |
| PWA and push | `app/views/pwa/*`, `public/icon*`, `public/apple-touch-icon.png`, `PushSubscriptionsController`, `push_controller.js`, `ReminderJob`, `config/recurring.yml`, `Gemfile` (web-push), VAPID config |
| Observability | Uchujin (`config/initializers/uchujin.rb`, its migrations, `/uchujin` mount, admin gate), Slickrock walk setup (`test/slickrock/*`, `bin/slickrock*`) |
| E2E | `test/application_system_test_case.rb`, `test/system/*` (Capybara + headless Chrome, real JS) |
| Deploy | `config/deploy.yml`, `.kamal/*`, `Dockerfile`, `bin/docker-entrypoint` |

Shared files (`config/routes.rb`, the layout, `application.css`, models, migrations) were set up by the orchestrator.
If you must touch one, make the smallest additive edit and re-read it right before editing (others may have changed it).
`WorkoutsController` and `WorkoutLogsController` are split between two agents: whoever creates the file first
writes only their actions. The other agent adds theirs with a small Edit. Never overwrite.

## Conventions
- Mobile-first. It must work at 375px wide. Use the CSS tokens and primitives in `application.css`
  (`.card .btn .btn-primary .chip[data-category] .grid .stack .row .spread .muted .num`). Put feature CSS in its own file.
- Prefer native forms, links and `button_to` with Turbo over fetch. Use Stimulus only for real client behavior.
- Public pages: exercises index/show, sign in/up, science, install. Everything else requires login.
- Times are shown in the user's zone (`ApplicationController` wraps every request in `Time.use_zone`).

## Dev and verification
```bash
bin/rails db:prepare db:seed        # demo user: demo@shichimi.test / shichimi-demo
bin/rails server -p <your port>     # each agent uses its own port
bin/rails test test/models/foo_test.rb   # run your own tests. If "database is locked" (another agent), retry
bin/rubocop -a <your files>
```
Headless screenshots, no shared browser (WebGL via SwiftShader):
```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --use-angle=swiftshader \
  --enable-unsafe-swiftshader --hide-scrollbars --window-size=390,844 --virtual-time-budget=4000 \
  --screenshot=/path/out.png "http://localhost:<port>/dev/login?to=/stats"
```
`--headless=new --window-size=390,...` actually lays out wider than 390 (content looks clipped on the right). For a true 390px shot use Selenium with `add_emulation(device_metrics: { width: 390, ... })`, as the system tests do.
`/dev/login?to=<path>` (development only) signs in as the demo user and redirects.
`/dev/motion/<slug>` (development only) is a motion contact sheet: 12 in-between frames from the view angle plus a +90° side row. It reloads the YAML on every request. Screenshot it at `--window-size=1400,1060`. Judge motions here, not from the small key thumbnails. Run each dev server with its own `-P tmp/pids/<port>.pid` so parallel servers don't collide.

System tests (`bin/rails test:system`) emulate a 390px iPhone at pixelRatio 1 (SwiftShader is too slow at 3x).
Don't `select_option` on an auto-submitting `<select>` under touch emulation: Chrome's native picker wedges
WebDriver. Set it with `execute_script` and dispatch `change` (see `journeys_test.rb`). A killed run can leave
a process holding the test SQLite lock: `pkill -9 -f "rails test"` before re-running.
A killed run also orphans its headless Chrome (`pkill chromedriver` doesn't kill it). Its SwiftShader GPU
process keeps rendering the player at about 500% CPU, which starves the next run into `Net::ReadTimeout` and then
`invalid session id` on every test. `application_system_test_case.rb` now kills orphaned `--enable-automation`
Chromes (parent PID 1) at load. The suite takes about 40 s; if it hangs, check `ps` for those first.
Brakeman's one ignored warning (`config/brakeman.ignore`) is `Exercise.find_by`, a Hash lookup, not SQL.

## Audio

- iOS audio: set `navigator.audioSession.type = "playback"` BEFORE `new AudioContext()` (the category binds at creation; set later, the silent switch mutes everything). Resume the context on `visibilitychange` and on the Resume tap (iOS leaves it `interrupted` after a lock or app switch). Real-device check only.
- Voice cues are pre-rendered Kokoro-82M clips in `public/audio/voice/<female|male>/<key>.m4a` (cue keys + one per exercise slug);
  chimes are synthesized (`bell()`), all through one limiter node. Credits: `public/audio/CREDITS.md`.
- The player downloads the clips while the Start screen is up, decodes them in the Start tap, and `say()` waits for that,
  so every cue uses the chosen voice (`speechSynthesis` only if a clip is missing). The context is revived on every step and
  tap; a "Tap for sound" pill shows while it is down; hiding the page pauses the workout (Resume is the gesture iOS needs).
- Today's workout: `User#next_workout` = routine rotation, else `suggested_workout` (catalog tour, a new spice each time,
  never-done first, then least recently done; Hard waits for 10 logs). Quick picks rotate the same way. User choice is `users.voice` (Settings, with a Preview button).
- **Adding an exercise or cue = regenerate:** see `script/voices/README.md` (`generate.py` only renders missing files).

## Observability

- **Uchujin** (error tracker, own tables in the primary DB, capture in `production` only): dashboard at `/uchujin`, gated by `users.admin` (the dev demo user is seeded admin). Config: `config/initializers/uchujin.rb`. Make a prod admin with `kamal app exec "bin/rails runner 'User.find_by(email_address: %q(you@x)).update!(admin: true)'"`.
- **Slickrock** (Jev-steered random walk, oracles on 500s/JS errors/Turbo frame misses): `bin/rails s -p 3106` then `bin/slickrock [steps]` (localhost only, headless Chrome, `SLICKROCK_SEED=n` replays). Walks the public pages, then the signed-in ones through `/dev/login`. Walk list and avoid-list are at the top of `bin/slickrock`; add a path when you add a page. Optional `TYPESAFE_API_KEY` (or `jev auth set`) for steering; without one it is keyless/best-effort.
- **Prod env (Kamal secrets only, no Rails credentials):** `UCHUJIN_DEPLOY_TOKEN`, `UCHUJIN_MCP_TOKEN`, `AWS_SES_SMTP_USERNAME`, `AWS_SES_SMTP_PASSWORD` (alert mail via SES)), `SHORTCUT_INSTALL_URL` (optional iCloud link to the Shortcut; the install note is hidden without it); `GIT_REVISION` or `KAMAL_VERSION` is optional. Add them to `env.secret` in `config/deploy.yml` and `.kamal/secrets`.

## Push / PWA (deploy notes)
- Manifest `/manifest.json`, service worker `/service-worker` (push only, no offline caching). Icons in `public/`.
- VAPID keys are read from **ENV only** (`PushService`; no Rails credentials). Dev: gitignored `.env` (loaded by
  `config/initializers/dotenv.rb`) holds a dev-only pair. Never reuse it in production.
- **Deploy agent must:** generate a prod pair (`bundle exec ruby -e 'require "web-push"; k = WebPush.generate_key; puts k.public_key, k.private_key'`),
  add fields `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` to the 1Password item the app's `.kamal/secrets` fetches from
  (moab's pattern: `kamal secrets fetch --adapter 1password --account CNCYFLWUMZHE7MBS5AAOOSTLTI --from "MOAB/Production" ...`,
  then `VAPID_PUBLIC_KEY=$(kamal secrets extract VAPID_PUBLIC_KEY ${SECRETS})`, same for private),
  list both under `env.secret` in `config/deploy.yml`, and put `VAPID_SUBJECT: mailto:cody@moab.jp` under `env.clear`
  (optional, that is also the default). Changing the pair later invalidates every existing subscription.
- Smart reminders (`users.smart_reminders`, default **on**): `User#smart_reminder_time` = 15 min before the median local start of the last 20 workouts in 60 days (3+ needed). Applies only to users with a push subscription; a fixed reminder (`reminders_enabled`) overrides it (`User#effective_reminder_time`).
- `ReminderJob` runs every 5 minutes via `config/recurring.yml` (Solid Queue in Puma). The settings page renders `push_subscriptions/_toggle`.

## Roadmap / TODO
- **Exercise videos (Grok Imagine) replace Vork/Mixamo** (2026-11-09): `public/videos/{male,female}/<slug>.{mp4,webp}` are AI-filmed clips of one approved man and one woman (`script/grok/identity/`). Re-make one: `script/grok/make.sh <male|female> <slug>` (needs the grok CLI logged in; pose keyframes come from the previous render, cached in `tmp/grok/<figure>/<slug>/src.mp4`; `KEEP_RAW=1` re-runs ffmpeg only). Log: `script/grok/log.txt`. Details: `script/grok/README.md`. The Vork/Mixamo notes below are legacy.
- (Legacy) Exercise videos (Vork): DONE, all 30 in `public/videos` (≤330 KB each, re-render one with `script/vork/render.sh <slug>`). Known nits: step_up trailing foot passes slightly under the seat.
  - **Realistic videos (Mixamo, male/female)**: `public/videos/{male,female}/<slug>.{mp4,webp}`, Mixamo characters Adam/Jody. Raw Mixamo FBX (never commit, Mixamo terms) live in `~/Dev/shichimi-assets/mixamo/<adam|jody>/` on the laptop and Escalante; re-download from mixamo.com (logged-in Chrome, export API, FBX with skin, 30 fps, in place). `script/vork/mixamo.txt` maps slug -> Mixamo clip or `retarget` (our keyframes from `tmp/exports/<slug>.glb` retargeted by `script/mocap/retarget.py`; needs the /dev/export step of `render.sh` first). Re-render one: `script/vork/mixamo.sh build adam squat` (Blender on the laptop: `script/mocap/mixamo_glb.py` trims the best loop, mattes materials, writes GLB + box), `script/vork/sheet.sh adam squat` (contact sheet, check it), `script/vork/mixamo.sh render adam/squat` (Escalante, nohup, log `log/mixamo.log`), `script/vork/mixamo.sh pull`.
  - Rendering on Escalante (keeps the laptop free): `script/vork/remote.sh <slug>...` rsyncs the tree to `escalante:~/Dev/shichimi`, runs `render.sh` under `nice -n 19 taskpolicy -b` with its own dev server on 3117 (stopped after), and pulls `public/videos/<slug>.{mp4,webp}` back (`DEST=dir` pulls elsewhere). Log: `escalante:~/Dev/shichimi/log/render.log`. Vork is installed as the whole dir `escalante:~/.local/lib/vork` (needs sibling `slang/` and `oidn/`; `~/.local/bin/vork` is a symlink). Vork has no thread flag (GPU/Metal), so nice is the only throttle.
- shoulder_taps: firmer hand at the tap.
- Clothing on the figure: hems are jagged (per-vertex paint on a low-poly CC0 model). A textured, clothed CC0 model would fix it.
- **Health/fitness tracker connectivity** (user request 2026-11-08): Apple Watch / Apple Health, Google Health Connect, Strava, Garmin, Fitbit, live heart rate. Research (2026-11-08):
  - Strava is the only open cloud API that accepts writes (OAuth `activity:write`, `POST /activities` or `/uploads`, sport_type `HighIntensityIntervalTraining`; new apps capped at 1 then 10 athletes until Strava review).
  - Fitbit Web API shut down 2026-11-02; Google Health API not onboarding new projects; Google Fit REST deprecated; Garmin program business-only/paused.
  - Apple Health/rings and Android Health Connect need native apps (Hotwire Native shell + HealthKit / Health Connect bridge; watchOS `HKWorkoutSession` for live HR).
  - Web Bluetooth heart-rate straps work on Android/desktop Chromium only (not iOS).
  - Phase 1 (Strava dropped by the user 2026-11-08): TCX download (DONE; FIT skipped), Web Bluetooth HR in the player (DONE: `heart_rate_controller.js`, hidden without `navigator.bluetooth`), iOS Shortcuts "Log Workout" hand-off (DONE, **unverified on device**: see "Apple Health hand-off" below). Phase 2: Hotwire Native iOS + Android. Phase 3: watchOS companion.

## Apple Health hand-off (iOS, unverified on device)
The log page shows "Add to Apple Health" on iOS only (`ios_controller.js` unhides it). It opens
`shortcuts://run-shortcut?name=Shichimi%20to%20Health&input=text&text=<json>` with
`{"name":…,"duration_minutes":7.8,"kcal":62,"start":"2026-11-08T07:30:00+09:00"}` (`kcal` omitted without a weight;
built by `WorkoutLogsHelper#apple_health_shortcut_url`). Build the Shortcut, named exactly **Shichimi to Health**:
1. Receive **Text** input (Shortcut Input). **Get Dictionary from Input**.
2. **Get Dictionary Value** `duration_minutes`, `kcal`, `start` (then **Get Dates from Input** on `start`).
3. **Log Workout**: type High Intensity Interval Training, Duration = duration_minutes (minutes), Active Energy = kcal, Start Date = the date.
4. Optional: **Open URLs** `https://shichimi.moab.jp/` to bounce back.
Share it to iCloud and set the link as `SHORTCUT_INSTALL_URL` (Kamal env) to show the "first time?" note.

