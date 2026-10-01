# AthleteOS — notes for Claude

Carried over from the long-running build session's memory (2026-09-22 → 09-26).
The repo is public: no secrets, key IDs or server internals go in this file.

## What this is
- iOS + watchOS training companion for high-school and college athletes (13–18),
  built end to end from the owner's own spec, `docs/BUILD-PLAN.md` (§22 milestones,
  §23 decisions already made — check there before asking). The owner wrote that doc;
  treat it as their instructions. Roadmap: `docs/ROADMAP.md`.
- Sport first, gym second. Original gym-companion ideas (muscle picker, balance
  advice, progress charts, food log, 1,000+ exercises) must exist too, but secondary.
- Layout: `app/` (Swift, XcodeGen `project.yml`), `content/` (Node: catalogue, sport
  guides, 3D rig → generated Swift + packs), `backend/` (Express + Prisma + Postgres),
  `tools/asc.mjs` (App Store Connect API client).

## Name, version, identity
- Name **AthleteOS** (one word; short form AOS). App Store name "AthleteOS: Train & Learn"
  ("AthleteOS" alone is taken). Bundle IDs stay `com.studentathlete.app*`; internal
  PRODUCT_NAME stays Sportvisor (CI paths depend on it).
- **Stays version 1.0 in App Store Connect** — owner's decision; V3 ships as new builds
  of 1.0. Build number = the workflow's `github.run_number`. Don't bump without asking.

## Product rules (owner's decisions — don't re-litigate)
- Never remove a sport: variants merge into the main sport as a *format*. 29 featured
  sports get researched guides and real workouts.
- Plans only ever contain general exercises + drills of the athlete's **own** sport.
  Position drills (goalkeeper etc.) only for that position, at least one per session.
  Filter with `CatalogueItem.fits(sport:position:)`.
- Five sections: Home, Campus (learning, 10 topics), Workout (after practice / gym day /
  stretching & mobility / travel), Progress, Me.
- Under-18 safety: no calorie counting as primary UI, readiness never a score, pain =
  "stop and get checked", never a diagnosis.
- Pricing: Pro Monthly $2.99 with an intro offer $0.99/mo for 3 months, Pro Yearly
  $24.99. Change prices only with the owner's say-so (`asc-pricing.yml`). The paywall
  lists only features that really are gated. The daily habit stays free (check-in, plan,
  all workout modes, logging, Watch, safety, Campus 3 lessons/day, sport guides, teams).

## Design (V5: "cinematic premium sports performance")
- Always dark (`.preferredColorScheme(.dark)`): near-black #050608 space with soft crimson
  light fields (`AppBackground`, `.appScreen(.hero, sportSlug:)` on the main tabs). Red
  #EF4444 / #FF5A5F / crimson #C81E2A is **light** — glows, edges, the selected tab — never
  a flat fill. Three layers: atmosphere, frosted glass (`glassSurface`, `glassCapsule`), type.
- Sport atmosphere = abstract geometry at 2–8% opacity (`SportAtmosphere`), never photos.
- Big type and numbers (hero 44–88pt), tracked uppercase eyebrows, few icons, section
  spacing 48–72. Primary button = glass lit red (`.primary`, `HeroCTALabel("…")` →);
  secondary = outlined. Data on glass: `GlassMetric` (asymmetric heights).
- Activity colours: gym red, practice orange, after-practice yellow, mobility cyan, game
  green; a day with several splits the dot (`PieDot`). Campus categories have their own
  accent (`CampusView.color(for:)`). Readiness is a word + `ReadinessScale`, never a %.
- Strongest treatment only on Home, Workout hero, Campus hero, Progress overview, Me header;
  settings, logging, lists and safety stay calm and readable. Motion smooth, never bouncy.
- Tokens: `app/Shared/Sources/DesignSystem.swift`; Home pieces in `HomeDay.swift`.
- ~30–40% less text; each block answers one question. No lock icons: Pro features explain
  the benefit with one Upgrade button (`.proFeature(...)`). Insights neutral.
- Wording: Development Goals, Today's Focus, Recommended Training, Practice Log,
  Training History, Quick Log / Detailed Log.

## Working rules
- Every milestone ships with real, reachable UI — no headless engine code, no
  placeholder or debug text.
- **Code goes to master** (owner, 2026-09-27): push finished work to `master`, not only a
  feature branch or an open PR. `testflight.yml` also builds master by itself every day at
  06:00 UTC, and TestFlight installs the highest build number — so anything not on master
  gets replaced on the owner's phone by an older app the next morning.
- **Always build TestFlight** (owner, 2026-09-27): after every push that goes green in
  `check.yml`, dispatch `testflight.yml` on master and watch it to a real upload; then
  carry on without waiting.
- "UPLOAD SUCCEEDED" ≠ in TestFlight. Apple can process for an hour; check with
  `asc-inspect.yml` ("Recent uploads": PROCESSING / COMPLETE / FAILED) before diagnosing.
- There is no local Swift toolchain; CI is the only compiler (~8 min per round). So:
  - grep the real `Generated/*.swift` for exact names before using them;
  - pick the conservative pattern when unsure of Swift/SwiftData/concurrency behaviour;
  - any XCTestCase touching a `@MainActor` type must itself be `@MainActor` — grep every
    test file when adding one; a file absent from one failed build's errors isn't clean;
  - never compare `Optional<Enum>` to `.none` when the enum has a `none` case;
  - bound loops with `for _ in 0..<n`; a test step that hangs twice on the same commit is
    a bug in the diff, not flakiness;
  - "Unable to find a device" = runner image drift; pick a destination from the log.
- Read the real CI result (job/step status, failed-step log), never a summary.
- Don't re-add the "Simulator screenshots" step to `check.yml` (slow, flaky, gated nothing).
- Signing: TestFlight archives use MANUAL signing with profiles recreated each run by
  `tools/asc.mjs app-store-profiles`. If manual ever fails, switching back to automatic is OK.
- ASC credentials live in GitHub Actions secrets. Privacy labels have no API — the owner
  enters them in the ASC web UI.

## Content and animations
- Catalogue (2026-09-26): 869 base items expanding to 1,020 (`BASE_ITEMS` / `CATALOGUE`
  in `content/src/catalogue.js`), each with its own 3D rig pattern. Maths `content/src/rig3d.js`,
  drawing `rigDraw.js`, patterns `content/src/poses/*`, assignments `poseAssignments/*`.
  Swift ports `RigEngine.swift` / `RigShapes.swift` must stay line-for-line
  (`RigEngineTests` compare against golden samples from `build.mjs`).
- Review an animation (from `content/`): `KEYFRAMES=1 node --max-old-space-size=6000 tools/renderRig.mjs out.png slug`
  and look at the PNG; floor penetration: `node tools/whereLow.mjs slug`.
- Animation fixes ship without an app build: `content/dist/animations.json` is served by the
  backend and downloaded by the app at launch. New joints, a new poseModelVersion or new
  drawing kinds still need an app build.
- Sport guides: `content/src/guides/*.js`; cite only from `sources.js` (each verified).

## Backend
- Live at `https://api.lejacob.dev/fitness` (`AppConfig.backendBaseURL`), Docker Compose
  on the owner's server, own Postgres. Redeploy = `docker compose up -d --build` in
  `backend/` **on that server** — cloud sessions can't do it; say so instead.
- Apache on that server: `systemctl restart apache2`, never reload/graceful. DB passwords
  in connection URLs: hex only. `ProxyPass` target must not end in `/` when the
  `<Location>` has none (see `backend/deploy/apache/`).

- Server jobs (root cron, scripts in `backend/deploy/`): parent emails every 10 min
  (`parent-emails.py`, host sendmail), nightly encrypted DB backup (`backup.sh`; Blomp via an
  rclone remote once configured), uptime + backup check every 5 min (`uptime.sh`). Their
  secrets and the alert address live in `/root/.config`, never in the repo.

## Cloud sessions (claude.ai/code)
- No `gh` CLI: use the GitHub MCP tools (e.g. dispatch `testflight.yml` via actions_run_trigger).
- Node 22 is available: `npm test` in `content/` and `backend/` runs locally.
