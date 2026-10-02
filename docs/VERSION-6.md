# AthleteOS — Version 6: product, UI and engine refocus

The owner's brief (2 October 2026), kept here so every session builds against
it. V6 adds no random features. Everything reinforces three pillars:

| Pillar | Question | Job |
|---|---|---|
| **Workout** | What should I physically do today? | Build the athlete |
| **Campus** | What should I understand to become a smarter athlete? | Teach the athlete |
| **Reflection** | What did I learn today, and how should tomorrow adapt? | Understand and adapt to the athlete |

Loop: **PREPARE → PERFORM → REFLECT → ADAPT** (morning check-in prepares,
workout performs, Campus explains why, evening reflection feeds tomorrow).

**Product priority:** 1 workout quality · 2 personalization / schedule
adaptation · 3 reflection · 4 Campus · 5 progress · 6 gamification. No effort
on trophies, XP, widgets or social while the workout engine is weak. Success =
athletes trust "the app knows what I should do today".

Definition: not "an AI that gives athletes workouts" but a personal
development system that decides what physical training makes sense around
real sport demands, teaches why, and learns from daily reflection.

## 1. Home completion UI
Remove the "Today Complete 1/4" ring (too Apple Fitness). Replace with a
horizontal **Daily Performance Track**: `01 / 04 COMPLETE`, thin segments or
nodes, labels (Practice / Workout / Mobility / Reflection) with state (DONE /
NEXT / LATER / TONIGHT). Minimal, cinematic, thin lines, subtle glow, no big
card. Complete = softly lit; next = red glow; future = muted. Activity colours
subtle: practice orange, workout red, mobility cyan, reflection violet,
game green. Not a game. A recommended rest day that is rested counts as
correct adherence.

## 2. Human-designed, not AI-generated
Avoid: identical rounded cards, every block in a container, generic icons,
repetitive layouts, excessive all-caps labels, too many glowing gradients,
equal weight for everything, too much per screen. Three component levels:
- **Hero** — one focus per screen, large type, open, minimal.
- **Information panel** — glass container for important supporting data.
- **Utility row** — flat row for secondary controls.
More whitespace, intentional asymmetry, content floating on the background.

## 4. Workout engine (rebuild)
Not SPORT → random sport exercises. Pipeline:
athlete profile → sport + position/event → season → sport demands → team
practice schedule → competition schedule → training experience → development
priorities → recent workload → morning check-in → equipment → available time
→ session type → training targets → workout.

Build complete athletes. Every athlete needs a sport-weighted mix of:
strength, relative strength, power, acceleration, speed, deceleration,
coordination, aerobic fitness, repeated-effort conditioning, mobility,
trunk strength/control, balance/stability, recovery. The sport changes the
priorities; it doesn't remove general development.

## 5. Conditioning engine
Types: aerobic base (long, easy) · aerobic power (structured hard intervals)
· tempo (controlled moderate) · repeated high-intensity ability (bursts with
recovery) · recovery conditioning (very light) · sport-provided conditioning
(already gained in practice). Ask: how much conditioning does the sport
already give? Cross country: enormous — no random extra running. Basketball:
practice may cover HIIT; extra only on real need. Golf: may benefit from
general aerobic work. Football: needed, type depends on position and
schedule. Cardio is programmed, never randomly added.

## 6. Session durations
- **After-practice:** 15–35 min. Upper body, trunk, small strength gaps,
  low-volume strength, controlled power, movement quality. Don't duplicate
  what practice heavily trained.
- **Gym development day:** usually 45–75 min (age, experience, season,
  schedule, time, competition proximity, readiness). Structure: movement prep
  5–10 · power/speed 5–15 · primary strength 15–25 · secondary strength
  10–15 · accessory/unilateral/trunk 5–15 · conditioning if needed 5–20. Not
  every section every time. 20–25 min only occasionally.
- **Mobility / movement:** 5–20 min, with a purpose: pre-training prep,
  targeted mobility, recovery movement, evening downshift. Not random stretches.

## 7. Quality over exercise count
A 25-minute session with 12 exercises is not serious strength training.
Typical: 4 prep drills, 1–2 explosive, 3–4 strength, 1–2 accessory/trunk.

## 8. Fatigue budget
Each session weighs development value, fatigue cost, competition proximity,
practice load, recovery state and recent exposure. "Good exercise, wrong
day" is a real outcome. Example: goal lower-body strength + hard practice
today + game tomorrow + high leg fatigue → no heavy lower body; upper body +
trunk + short mobility instead.

## 9. "Why this plan?"
Internally answer: why train today, why this session type, why this
duration, why these qualities, why these exercises, why this order, what
practice already trained, what we avoid, how it fits goals, how it progresses.
User sees a short version, e.g. "Practice already gave you substantial
lower-body and conditioning load today. This short session focuses on
upper-body strength and trunk work without adding unnecessary leg fatigue."

## 10. Exercise knowledge base
Per exercise: name, movement_pattern, primary_quality, secondary_qualities,
primary_regions, equipment, technical_difficulty, fatigue_cost,
impact_level, training_age_requirement, supervision_requirement,
sport_relevance, goal_relevance, progressions, regressions,
replacement_group, safety_flags, set_rep_options, tempo_options,
rest_options, coaching_cues, common_errors. Patterns: squat, hinge, push,
pull, carry, rotation, anti-rotation, unilateral lower, jump, throw, sprint,
deceleration. Select by purpose, not keywords.

## 11–17. Campus rebuild
Progressive paths, not random articles: **L1 Foundations · L2 Development ·
L3 Performance · L4 Sport IQ · L5 Self-coaching.**
Categories with substantial content:
- **Training science:** strength, relative strength, power, speed,
  acceleration, max velocity, endurance, conditioning, progressive overload,
  adaptation, specificity, fatigue, recovery, deloads, in-/off-season
  training, sets, reps, rest, frequency, soreness is not the goal, why more
  training can reduce performance.
- **Anatomy & movement:** muscle groups, joints, patterns (squat, hinge,
  push, pull, rotation, locomotion, landing, deceleration), mobility,
  stability, coordination, movement quality, basic biomechanics.
- **Nutrition & hydration** (performance, never dieting): carbs, protein,
  fats, hydration, electrolytes, pre-practice fuel, post-practice recovery,
  competition fuel, eating enough for growth + sport, under-fuelling, meal
  timing. Never a calorie-restriction tool for teens.
- **Sleep & recovery:** duration, quality, consistency, fatigue, school
  stress, travel, rest days, naps, bedtime routines, recovery after games and
  tournaments, nervous-system downshift.
- **Sports psychology** (deep, useful, no quotes): confidence, focus,
  attention, pressure, nerves, motivation, mistakes, reset routines,
  process/performance/outcome goals, self-talk, imagery, pre-performance
  routines, emotional control, poor performances, feedback, communication,
  leadership, identity outside sport.
- **Supplements & performance** (education only — "understand this", never
  "take this"; no products or doses for teens): what supplements are, why
  athletes use them, what evidence means, supplements vs food, can't replace
  sleep/training/nutrition, quality control, contamination and
  banned-substance risk, marketing manipulation, third-party certification,
  when to talk to a parent/guardian or professional. Modules: protein
  powder, creatine, caffeine, sports drinks, electrolytes, vitamins &
  minerals, pre-workouts — each: what is it, why athletes talk about it, what
  research examines, limitations, risks, who should be cautious, marketing
  claims, what matters more.
- **Digital performance** (no fearmongering, phones don't "destroy the
  brain"): effects on attention, focus, sleep timing, stimulation, stress,
  recovery, homework, meals, social time, pre-competition prep. Intentional
  use (texting coach, one training video, schedule, music) vs automatic use
  (opening short-video apps without intent, notification checking, endless
  scrolling). The problem is uncontrolled use replacing something more
  valuable. Phone + sleep: avoid long stimulating late scrolling, Focus / Do
  Not Disturb, fewer notifications, consistent routine, phone farther from
  bed if it helps, avoid intense content before sleep, relaxing vs
  stimulating use. "Use technology intentionally. Don't let it decide how you
  spend your recovery time."
- **Contextual:** recommendations react to the athlete — poor sleep → sleep
  & performance; competition tomorrow → handling pressure; after hard
  training → how recovery works; power workout → what is power; asks about
  creatine → supplements evidence & safety; repeated late check-ins → phone
  habits & sleep; low confidence → confidence from preparation.
- **Campus UI:** lead with "Recommended for you today" (title, minutes,
  Continue), then Continue learning, Explore, categories, then
  progression/XP. Feeling: learn something useful, not grind XP.

## 18–19. Reflection is core
Evening, 3–5 short questions depending on the day: how hard did today feel
(easy/normal/hard/very hard), how did your body feel (good/tired/very
tired/something hurt), how did practice go (poor/okay/good/great), what went
well (optional text), what to improve (optional text). It's how the app
learns the athlete. Occasionally return one small insight ("Practice felt
harder than usual today. Tomorrow's supplemental session has been
adjusted." / "You rated focus highly on three practices this week. What did
you do differently?").

## 20. Home centres the three pillars
Home answers: what do I do (workout), what should I learn (Campus), what
should I reflect on (reflection). E.g. TODAY — Team practice 4:00 PM ·
After-practice strength 22 min · Campus: why strength matters in season 4 min
· Reflection tonight 45 sec. Widgets, streaks etc. lower down.

## 21. Less gamification
Keep streaks, XP, levels, badges — secondary. Never punish rest, illness,
travel or planned recovery. No guilt ("DON'T LOSE YOUR STREAK"). Rest can be
correct execution.

## 22. Copy style
An excellent performance coach — not ChatGPT, not a Nike parody. Never
"unlock your potential / push past your limits / become unstoppable / crush
it". Instead: "Today's lower-body volume is reduced because you compete
tomorrow." "Practice already covered high-intensity conditioning."
"Recovery is part of the plan." Simple, precise, calm.

## 23. Development goals
Acceleration, speed, strength, relative strength, power, vertical jump,
conditioning, aerobic fitness, mobility, movement quality, sport skill,
recovery habits, confidence, focus. No body-dissatisfaction or restrictive
diet goals for teens.

## 24. Algorithm output
Structured decision first, words second:
```json
{
  "session_type": "after_practice",
  "duration_target": 24,
  "primary_targets": ["upper_body_strength", "trunk_strength"],
  "maintain": ["mobility"],
  "avoid_today": ["high_volume_lower_body", "hard_conditioning"],
  "reason_codes": ["HARD_TEAM_PRACTICE", "GAME_WITHIN_48H"]
}
```
The UI translates it. Any language layer explains the decision; it never
invents the safety/training decision.
