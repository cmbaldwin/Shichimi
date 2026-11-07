# Shichimi · 七味

**Seven minutes. Seven spices.** A home-screen web app (PWA) for guided body-weight workouts,
built on morning calisthenics. Each of the 30 exercises has an animated 3D mannequin, and there are 100
science-backed circuits across 7 timing formats. The app reminds you to work out, logs every
session, and shows you how you're doing.

Live: https://shichimi.moab.jp

## What's in it
- **30 exercises** in 4 categories (cardio, lower, upper, core). Each has a three.js animation of a rigged human
  (Quaternius Universal Base Characters, CC0, retargeted from procedural motion keys), coaching cues, regressions and progressions, and MET values.
- **7 formats**, each named after a spice in shichimi tōgarashi:

  | Format | Spice | Timing | Total |
  |---|---|---|---|
  | Classic 12 | Chinpi 陳皮 | 12 × 30 s on / 10 s rest | 7:50 |
  | Tōgarashi Sprint | Tōgarashi 唐辛子 | 8 × 20 / 10 (Tabata protocol) | 3:50 |
  | Sansho Seven | Sansho 山椒 | 7 moves × 2 rounds of 20 / 10 | 6:50 |
  | Shōga Fifty | Shōga 生姜 | 8 × 50 / 10 | 7:50 |
  | Nori Forty | Aonori 青のり | 7 × 40 / 20 | 6:40 |
  | Goma Easy | Goma 胡麻 | 7 × 30 / 30 | 6:30 |
  | Asa no Mi Double | Asa no mi 麻の実 | Classic 12 twice, 60 s break | 16:40 |

- **100 catalog workouts.** No two adjacent moves share a muscle group (Klika & Jordan 2013). There are themes for
  quiet apartment mornings, standing desk breaks, hotel rooms, sore-leg days and more. You can also build your own.
- **Player** with a drift-free timer, pre-rendered Kokoro voice cues (female/male/off) and CC0 sound effects (dink-dink-dink on the last 3 s of every interval, GO chime, rest, switch-sides, halfway and finish), regenerated via `script/voices/`, a screen wake lock, and side switching for side planks.
- **Smart reminders** (on by default): the installed app nudges you about 15 minutes before the time you usually work out, learned from your history. Skipped on days you've trained; switch off in Settings.
- **Exercise references**: each exercise page links a YouTube demo and an official form guide (ACE, NASM, Mayo Clinic, NHS or Cleveland Clinic).
- **`/install`**: how to add the app to an iPhone or Android home screen, with drawn menu mockups and a one-tap Install button where Chrome supports it.
- **Routine and history.** Rotate through your saved workouts, rate each one with Borg CR10 RPE, and add notes.
- **Stats.** Streaks, a heatmap, weekly minutes, WHO weekly targets, category balance, and the Seven Lucky Gods
  (七福) milestones.
- **Reminders** via Web Push at your chosen time and days, sent only if you haven't trained yet that day.
- See `/science` in the app for the references.

## Stack
Ruby 4.0.9 · Rails 8.1 · SQLite · Hotwire (Turbo and Stimulus) · importmaps with **vendored** JS (three.js r170 in
`vendor/javascript`, no CDN) · Propshaft · plain CSS · Solid Queue in Puma · Minitest and Capybara system tests ·
[Uchujin](https://github.com/cmbaldwin/Uchujin) error tracking · [Slickrock](https://github.com/cmbaldwin/slickrock)
UI walks · Kamal on the moab box.

## Develop
```bash
bundle install
bin/rails db:prepare db:seed      # seeds the catalog; set SHICHIMI_DEMO_PASSWORD to also create demo@shichimi.test
bin/rails dev:sample_logs         # optional: 6 months of fake history for the demo user
bin/rails server
bin/rails test                    # unit and integration
bin/rails test:system             # end-to-end in headless Chrome
```

## Deploy
Kamal to the moab box (5.223.44.132) behind Cloudflare. Secrets come only from 1Password through `.kamal/secrets`
(no Rails credentials). See `AGENTS.md`.

Contributors and coding agents should start with [`AGENTS.md`](AGENTS.md).
