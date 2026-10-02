import Foundation

// Digital performance (docs/VERSION-6.md §14–§15). No fearmongering: phones
// aren't the enemy; uncontrolled use replacing something better is.

let digitalLessons: [CampusLesson] = [
    campusLesson("dg-intentional", "Intentional vs automatic use", 3,
                 hook: ("You picked up your phone. Why?", "Most phone use isn't a decision. It's a reflex. Noticing the difference is the whole skill."), [
        ("Intentional use", "You open the phone for a reason and close it when you're done: texting your coach, checking the practice time, watching one technique video, putting on music for the bus."),
        ("Automatic use", "You open it without deciding to: a notification, a spare second, boredom. One short video becomes forty minutes. Nothing about it was a choice."),
        ("The real issue", "Phone use isn't bad. The problem is when uncontrolled use quietly replaces something more valuable — sleep, homework, a proper meal, talking with friends, getting ready to compete."),
    ], example: "Isaac, 16, tracked one evening: 12 minutes of messages he needed, then 70 minutes of short videos he couldn't remember. He kept the messages and moved the phone out of reach after 9 p.m.",
                 ["Ask 'why am I opening this?' before you open it.", "Intentional use is fine — that's what phones are for.", "Watch for use that replaces sleep, food, homework or people."]),

    campusLesson("dg-attention", "Your phone and your attention", 4,
                 hook: ("Focus is trained — in both directions", "Attention behaves a bit like fitness: what you practise is what you get better at."), [
        ("Switching costs", "Every time you check a notification in the middle of something, it takes time to get fully back into the task. Lots of small switches add up to a lot of half-attention."),
        ("Practising short attention", "Hours of very short, fast-changing content give your brain lots of practice at switching and very little at staying with one thing. That isn't damage — it's habit. And habits can be changed."),
        ("Why athletes should care", "Film study, learning a play, listening to a coach and staying locked in for a whole game all need sustained attention. It's a skill like any other, and you can train it."),
        ("Simple training", "One task at a time with the phone in another room. Start with 20–30 minutes and build up. During practice or film, phone in the bag."),
    ], example: "Priya, 15, did homework with her phone face-down beside her and still checked it every few minutes. With the phone in the kitchen for 30 minutes at a time, she finished faster and had more free time afterwards.",
                 ["Constant checking leaves you half-focused.", "Sustained attention is a trainable skill.", "Phone out of reach for focused work and film."]),

    campusLesson("dg-sleep", "Phones and sleep", 4,
                 hook: ("The last hour decides the night", "What you do in the hour before bed changes how fast you fall asleep and how well you sleep."), [
        ("Stimulation, not just light", "A lot of attention goes to screen light. The bigger issue is usually what you're doing and for how long: exciting games, arguments in group chats, endless scrolling and intense videos keep your brain switched on when it should be winding down."),
        ("Time that disappears", "Late-night scrolling often just pushes bedtime later. Twenty minutes becomes an hour, and that's an hour less sleep before school and practice."),
        ("What helps", "Use Do Not Disturb or a Focus mode at night. Turn off notifications you don't need. Keep a similar bedtime every night. If it helps, charge your phone away from your bed. Choose calm things late at night — music, a show you've seen, reading."),
        ("Relaxing vs stimulating", "Listening to calm music or a podcast can help some people relax. A competitive game, a heated chat or emotionally intense content does the opposite. Notice which is which for you."),
    ], example: "Marcus, 17, was always tired at morning lifts. He set his phone's Focus mode to start at 10 p.m. and charged it in the hallway. Within two weeks he was falling asleep about half an hour earlier.",
                 ["Use technology on purpose — don't let it decide your recovery time.", "Calm content late; intense content earlier.", "Focus mode, fewer notifications and the phone away from your bed all help."]),

    campusLesson("dg-notifications", "Take back control of notifications", 3,
                 hook: ("Who decides when you pick up your phone?", "Every notification is an app asking for your attention. Most of them don't need it."), [
        ("Sort your notifications", "Keep the ones from people and things that matter: family, coach, team schedule. Turn off the rest — especially apps designed to pull you back in."),
        ("Batch, don't drip", "Checking messages a few times at set moments is less draining than reacting to every buzz. Most messages can wait 30 minutes."),
        ("Use the tools", "Focus modes can let only important people through during school, homework, practice and sleep. Grayscale mode makes the phone less tempting for some people."),
    ], example: "Lucia, 15, had 300+ notifications a day. She turned off everything except messages and her team app. 'My phone got boring,' she said, 'which was the point.'",
                 ["Keep notifications from people who matter; mute the rest.", "Check at set times instead of every buzz.", "Use Focus modes for school, practice and sleep."]),

    campusLesson("dg-before-games", "Phones before competition", 3,
                 hook: ("Your pre-game starts before warm-up", "What you look at in the hours before a game can change how you feel walking onto the field."), [
        ("Helpful use", "Music that gets you in the right mood, a quick look at your game plan, a message from family. Short, chosen, useful."),
        ("Unhelpful use", "Reading what people are saying about the game, comparing yourself with opponents online, getting into arguments, or scrolling until your focus is scattered."),
        ("A simple routine", "Decide in advance: phone for music and one check-in, then away from a set time before warm-up. Your pre-game routine works better when the phone is part of the plan, not an interruption."),
    ], example: "Ben, 17, used to read the opposing team's posts before games and walk out angry. Now he puts his phone in his bag after choosing his warm-up playlist, and spends that time on his routine.",
                 ["Plan your phone use before competition.", "Music and your game plan: yes. Comments and comparison: no.", "Phone away at a set time before warm-up."]),

    campusLesson("dg-recovery-time", "Recovery time, not scroll time", 3,
                 hook: ("Rest isn't the same as being on your phone", "Lying on the couch scrolling for two hours can leave you more tired than when you started."), [
        ("What recovery needs", "Sleep, food, calm and some time with people. A bit of fun screen time can be part of relaxing. But hours of fast, stimulating content keep your brain busy while your body is trying to recover."),
        ("What it pushes out", "Meals eaten while scrolling are often rushed or skipped. Homework gets pushed late, which pushes sleep late. Time with friends and family gets shorter."),
        ("Make a plan", "Pick the screen time you actually enjoy and give it a time limit. Protect meals, homework and the hour before bed."),
    ], example: "Hana, 16, noticed she felt worse after rest days spent mostly on her phone. Now she keeps a two-hour limit on rest days and spends the rest outside, with friends, or reading — and feels fresher for practice.",
                 ["Choose your screen time; don't drift into it.", "Protect meals, homework and the hour before bed.", "Real rest includes calm and people."]),

    campusLesson("dg-comparison", "Highlights and comparison", 4,
                 hook: ("You're comparing your full story to their best ten seconds", "Social media shows highlight reels, edited training clips and the best photos. That isn't anyone's real life."), [
        ("What you don't see", "The missed shots, the bad days, the injuries, the editing, the lighting, and sometimes the filters or the products being sold. Many 'fitness' posts are advertising."),
        ("Why it matters", "Constant comparison can make you feel behind, push you into training you're not ready for, or make you unhappy with a body that's still growing and working well."),
        ("Healthier habits", "Follow accounts that teach you something or make you feel good. Mute ones that make you feel worse. Compare yourself with yourself last month, not with someone else's highlights."),
    ], example: "Zoe, 15, felt she wasn't strong enough after following lots of fitness influencers. When she unfollowed most of them and started tracking her own progress in the app, she realised how much she had improved.",
                 ["Highlights aren't real life.", "Unfollow what makes you feel worse.", "Compare yourself with your past self."]),
]

let digitalQuestions: [String: [CampusQuestion]] = [
    "dg-intentional": [
        .choice(prompt: "Which is intentional phone use?", options: ["Opening an app because you're bored", "Checking tomorrow's practice time", "Scrolling until you fall asleep"], answer: 1,
                explain: "You opened it for a reason and can close it when you're done."),
        .trueFalse(statement: "All phone use is bad for athletes.", answer: false, explain: "The problem is uncontrolled use replacing something more valuable."),
    ],
    "dg-attention": [
        .trueFalse(statement: "Sustained attention is a skill you can train.", answer: true, explain: "Practise one thing at a time, with the phone out of reach."),
    ],
    "dg-sleep": [
        .choice(prompt: "Which is usually the bigger sleep problem late at night?", options: ["Screen light alone", "Stimulating content and time that disappears", "Charging the phone"], answer: 1,
                explain: "What you do, and for how long, matters most."),
        .choice(prompt: "Which helps most people fall asleep?", options: ["A heated group chat", "Calm music with Do Not Disturb on", "A competitive game"], answer: 1,
                explain: "Relaxing, not stimulating."),
    ],
    "dg-notifications": [
        .choice(prompt: "Which notifications are worth keeping?", options: ["Every app's", "People and team schedule", "Games and shopping"], answer: 1, explain: "Keep what matters; mute the rest."),
    ],
    "dg-before-games": [
        .trueFalse(statement: "Reading comments about the game right before warm-up helps you focus.", answer: false, explain: "It usually scatters focus or raises nerves."),
    ],
    "dg-recovery-time": [
        .trueFalse(statement: "Hours of fast, stimulating content count as full recovery.", answer: false, explain: "Recovery needs sleep, food, calm and people too."),
    ],
    "dg-comparison": [
        .choice(prompt: "Who is the most useful person to compare yourself with?", options: ["Influencers", "Pro athletes", "Yourself a month ago"], answer: 2, explain: "Your own progress is the fair comparison."),
    ],
]
