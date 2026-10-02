import Foundation

// Self-coaching (docs/VERSION-6.md §11, level 5): teaching the athlete to
// make good decisions on their own.

let selfCoachingLessons: [CampusLesson] = [
    campusLesson("sc-reading-body", "Reading your own body", 4,
                 hook: ("The best data is you", "Watches and apps help. But learning what your own body is telling you is a skill that lasts a lifetime."), [
        ("Signals worth noticing", "How you slept, how your legs feel walking up stairs, your mood, your motivation, how warm-ups feel. Patterns over a few days matter more than one bad morning."),
        ("Soreness, tiredness, pain", "Soreness is normal after new training. Tiredness that lasts days means more recovery. Pain that's sharp, in a joint, or getting worse means stop and tell someone."),
        ("Check against reality", "Feeling flat in the morning often improves after a good warm-up. Feeling worse as you warm up is a stronger signal to back off."),
    ], example: "Nate, 17, felt tired most mornings but always good after warming up. He learned that for him, warm-up was the real test — and backed off only when warm-ups felt heavy too.",
                 ["Patterns over days beat one bad morning.", "Know soreness, tiredness and pain apart.", "The warm-up is a useful test."]),

    campusLesson("sc-adjusting", "Adjusting a plan yourself", 4,
                 hook: ("No plan survives a real week", "Practice runs long, a test moves, you sleep badly. Good athletes adjust instead of quitting or forcing it."), [
        ("Keep the main thing", "If time is short, do the main exercises and drop the extras. Two good sets of the main lift beat a rushed full session."),
        ("Lighter, not nothing", "On a rough day, cut sets or weight, keep the movement. Showing up and moving well keeps the habit."),
        ("Know when to skip", "Illness with fever, sharp pain, a head knock, or a game tomorrow after a brutal practice — those are days the right session is no session."),
        ("Then tell the app", "Your check-in and reflection let the plan adjust with you, so tomorrow fits today."),
    ], example: "Isla, 16, had 20 minutes instead of 50 for a gym day. She did her warm-up, her two main lifts, and skipped the rest. Her coach said it was exactly the right call.",
                 ["Short on time: keep the main exercises.", "Rough day: lighter, not nothing.", "Some days the right session is no session."]),

    campusLesson("sc-own-session", "Building your own session", 5,
                 hook: ("The order is the secret", "Most good sessions follow the same shape. Once you know it, you can build your own."), [
        ("The shape", "Movement prep → fast and explosive work → the main strength exercises → secondary strength → trunk and small injury-prevention work → conditioning if needed."),
        ("Pick by pattern", "One lower-body main lift (squat or hinge), one upper push and one upper pull, a single-leg exercise, a trunk exercise. That's a complete session."),
        ("Few, done well", "Five or six exercises done with quality beat twelve done tired. Add sets or weight over the weeks, not more exercises."),
    ], example: "Leo, 17, had to train on his own during a holiday. Using the session shape, he built a 45-minute workout with six exercises and kept his strength through the break.",
                 ["Prep, fast, strong, secondary, trunk, conditioning.", "Choose by movement pattern.", "Few exercises, done well, progressed over weeks."]),

    campusLesson("sc-season-plan", "Planning your own season", 5,
                 hook: ("A year has seasons", "Athletes who plan the whole year peak when it matters and get hurt less."), [
        ("The phases", "Off-season: recover, then build. Pre-season: get sport-ready. In-season: maintain and perform. Post-season: rest and reflect."),
        ("Put the big things in first", "Games, tournaments, exams and holidays go in the calendar first. Training fits around them."),
        ("Review and adjust", "Every few weeks, look back: what worked, what didn't, how do you feel? Season reviews turn experience into knowledge."),
    ], example: "Amelia, 16, mapped her soccer season, exam dates and summer holiday into one calendar in August. She knew in advance where her hard training weeks and her easy weeks would be.",
                 ["Off-season, pre-season, in-season, post-season.", "Games and exams go in first.", "Review every few weeks."]),
]

let selfCoachingQuestions: [String: [CampusQuestion]] = [
    "sc-reading-body": [
        .trueFalse(statement: "Feeling worse as you warm up is a stronger signal to back off than feeling flat in the morning.", answer: true,
                   explain: "The warm-up is a useful test."),
    ],
    "sc-adjusting": [
        .choice(prompt: "You have 20 minutes instead of 50. What do you do?", options: ["Skip it completely", "Do the main exercises, drop the extras", "Rush every exercise"], answer: 1,
                explain: "Keep the main thing."),
    ],
    "sc-own-session": [
        .choice(prompt: "What comes right after movement prep?", options: ["Conditioning", "Fast and explosive work", "Small accessory exercises"], answer: 1, explain: "Fast work while you're fresh."),
    ],
    "sc-season-plan": [
        .trueFalse(statement: "Games and exams should go into your calendar before training.", answer: true, explain: "Training fits around the big things."),
    ],
]
