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
| `WorkoutLog` | DB, routes at `/history` | one finished (or partly finished) workout: snapshot of name/format/timing, `completed_slugs`, `duration_seconds`, `performed_at`, `rpe` (Borg CR10 1–10), `notes`. `#kcal` |
| `PushSubscription` | DB | endpoint, p256dh_key, auth_key |
| `User` | DB | `time_zone` (IANA), `weight_kg` (optional, used for kcal), `weekly_goal`, `reminders_enabled`, `reminder_time` "HH:MM", `reminder_days` (wday digits "0123456", 0=Sun), `last_reminded_on`, `voice_enabled`. Helpers `zone`, `today`, `display_name` |

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
keys:                 # poses, eased key0→key1→…→key0. {} = standing rest pose.
  - {}
  - { root: [pitch, yaw, roll], spine: [flex, twist, side], lhip: [flex, abd, twist], lkn: 90, air: 0.1 }
```

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
| Player sounds | `player_controller.js` `SFX` table + `bell()` (Web Audio synth, no audio files). Ticks fire on the last 3 s of every step longer than 4 s |
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
`/dev/login?to=<path>` (development only) signs in as the demo user and redirects.
`/dev/motion/<slug>` (development only) is a motion contact sheet: 12 in-between frames from the view angle plus a +90° side row. It reloads the YAML on every request. Screenshot it at `--window-size=1400,1060`. Judge motions here, not from the small key thumbnails. Run each dev server with its own `-P tmp/pids/<port>.pid` so parallel servers don't collide.

System tests (`bin/rails test:system`) emulate a 390px iPhone at pixelRatio 1 (SwiftShader is too slow at 3x).
Don't `select_option` on an auto-submitting `<select>` under touch emulation: Chrome's native picker wedges
WebDriver. Set it with `execute_script` and dispatch `change` (see `journeys_test.rb`). A killed run can leave
a process holding the test SQLite lock: `pkill -9 -f "rails test"` before re-running.
Brakeman's one ignored warning (`config/brakeman.ignore`) is `Exercise.find_by`, a Hash lookup, not SQL.

## Observability

- **Uchujin** (error tracker, own tables in the primary DB, capture in `production` only): dashboard at `/uchujin`, gated by `users.admin` (the dev demo user is seeded admin). Config: `config/initializers/uchujin.rb`. Make a prod admin with `kamal app exec "bin/rails runner 'User.find_by(email_address: %q(you@x)).update!(admin: true)'"`.
- **Slickrock** (Jev-steered random walk, oracles on 500s/JS errors/Turbo frame misses): `bin/rails s -p 3106` then `bin/slickrock [steps]` (localhost only, headless Chrome, `SLICKROCK_SEED=n` replays). Walks the public pages, then the signed-in ones through `/dev/login`. Walk list and avoid-list are at the top of `bin/slickrock`; add a path when you add a page. Optional `TYPESAFE_API_KEY` (or `jev auth set`) for steering; without one it is keyless/best-effort.
- **Prod env (Kamal secrets only, no Rails credentials):** `UCHUJIN_DEPLOY_TOKEN`, `UCHUJIN_MCP_TOKEN`, `AWS_SES_SMTP_USERNAME`, `AWS_SES_SMTP_PASSWORD` (alert mail via SES); `GIT_REVISION` or `KAMAL_VERSION` is optional. Add them to `env.secret` in `config/deploy.yml` and `.kamal/secrets`.

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
- `ReminderJob` runs every 5 minutes via `config/recurring.yml` (Solid Queue in Puma). The settings page renders `push_subscriptions/_toggle`.
