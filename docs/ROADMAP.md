# AthleteOS roadmap

Proposed 2026-09-26. Section 1 is already promised and blocks App Store submission;
the rest is a backlog, not commitments.

## 1. Finish Version 3 (already promised)
1. Optional first name, so Home says "Good morning, Name".
2. Training Experience in Training Setup, and have it change the plan (beginner vs. experienced lifter).
3. Smarter Movement Prep: 5–15 minutes, different before practice than in the evening.
4. Rewrite Campus lessons as hook, explanation, athlete example, "what this means for you".
5. Calm down the Campus lesson player (still Duolingo-style hearts and chunky buttons).
6. Cut text on the screens V3 hasn't touched yet: Library, Sport Guide, Food, Tests, Skill plans, Mindset, Team/Coach, onboarding, paywall, live workout.
7. Remove the remaining repeated disclaimers and the small "PRO" badges.
8. Update App Store texts, review notes and screenshots for V3. Must happen before submitting.
9. Take simulator screenshots of every screen and check the layout.

## 2. Wearables and Health
10. Use Apple Watch / Health workouts as training load: a hard run makes today's plan lighter automatically.
11. Detect practice from the watch: a workout at practice time counts as "practice done".
12. Heart rate and effort in the post-workout summary.
13. Suggest a bedtime from sleep data and tomorrow's schedule.
14. Check-in and evening reflection on the watch in two taps.
15. Live Activities / Dynamic Island for a running workout and rest timer.

## 3. Training quality
16. Progressive overload: suggest next week's weight or reps from what was logged.
17. Deload weeks, planned automatically every 4–6 weeks.
18. Sport-specific warm-up built into every workout.
19. Build the plan from the actual free time (60 minutes free → 25-minute session).
20. In-season vs. off-season plans that look clearly different, with a visible "phase" explanation.
21. Injury return plans after reported pain: conservative 1–2 week ramp, never a diagnosis.
22. Video or photo alternatives where an animation is weak.
23. More catalogue items (original goal 1,000+ exercises).

## 4. Daily loop and motivation
24. Smart notifications: check-in on wake-up, reflection after practice, bedtime. Quiet and limited.
25. Weekly review every Sunday: what you did, one highlight, next week's focus.
26. Streak freeze for sick, travel and holiday days.
27. Measurable goals (e.g. vertical jump +5 cm by March), tracked from the tests.
28. Celebrate personal records in tests and lifts.
29. Home-screen widgets in the V3 style: readiness, training, next game.

## 5. Nutrition and recovery
30. Meal logging by photo or quick picks ("Did you eat before practice?"), not calories.
31. Hydration reminder on hot days and game days.
32. Game-day timeline tied to game time: meal 3 hours before, snack, warm-up.
33. Travel-day food tips for away games.

## 6. Team, coach and parents
34. Coach dashboard: readiness trend, missed check-ins, pain reports (with the athlete's consent).
35. Coach assigns a workout for a specific day.
36. One-way team announcements (no chat).
37. Weekly parent summary by email or push.
38. School / athletic trainer mode: pain reports and head-injury pauses for their team.

## 7. Campus and learning
39. Lesson recommendation from today (poor night → sleep lesson; before a game → nerves).
40. Short audio versions of lessons.
41. Position-specific lessons ("Know your position").
42. Review questions inside the evening reflection (spaced repetition).

## 8. Progress and data
43. Test progress page: jump, sprint and strength over the season in one chart.
44. Shareable season report at season end.
45. Readable PDF export for coaches, recruiters and parents.
46. Recruiting profile for college-bound athletes (could be Pro).

## 9. Accessibility and reach
47. Languages: German first, then Spanish.
48. Full VoiceOver pass and Dynamic Type check on every screen.
49. Metric/imperial check everywhere.
50. iPad layout (at least not broken).

## 10. Business and App Store
51. Free trial on the yearly plan.
52. Family or team plan (a coach buys Pro for the team).
53. Onboarding that shows value before sign-in, with a 60-second "your first day" demo.
54. Product page A/B tests (icons, screenshots).
55. Ratings prompt after a good moment, never after a pain report.
56. Privacy-respecting analytics: on-device or aggregate only.

## 11. Reliability and engineering
57. Crash reporting with MetricKit, no third-party SDKs.
58. Offline daily loop as a tested scenario.
59. CI keeps building after the first compile error, so one run shows all errors.
60. Snapshot tests of key screens.
61. Backend: off-machine database backups and uptime monitoring for api.lejacob.dev.
