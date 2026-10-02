import Foundation

// Sleep & recovery (docs/VERSION-6.md §12).

let sleepLessons: [CampusLesson] = [
    campusLesson("sr-how-much", "How much sleep athletes need", 3,
                 hook: ("Teenagers need more than adults", "Sleep experts recommend 8 to 10 hours a night for 13- to 18-year-olds. Most get much less."), [
        ("Why so much", "During deep sleep your body releases growth hormone and repairs muscle; during dream sleep your brain stores what you learned — including new skills from practice."),
        ("What short sleep costs", "Studies link short sleep in young athletes with slower reactions, worse decisions, lower mood, getting sick more often and more injuries."),
        ("Your body clock shifts", "In the teenage years, the body clock naturally moves later — you get sleepy later at night. Early school starts make this hard. That's why protecting your bedtime matters."),
    ], example: "Jordan, 16, slept about six and a half hours on school nights. When he moved his bedtime 45 minutes earlier for a month, his coach noticed sharper decisions in scrimmages.",
                 ["Teenagers need about 8–10 hours.", "Sleep repairs muscle and stores new skills.", "Protect your bedtime — your body clock runs late."]),

    campusLesson("sr-consistency", "Consistent sleep beats catch-up", 3,
                 hook: ("You can't fully bank sleep on Saturday", "Sleeping in on weekends helps a little. Steady sleep every night helps a lot more."), [
        ("Your body likes a rhythm", "Going to bed and waking at similar times — even on weekends — makes it easier to fall asleep and wake up feeling rested."),
        ("Social jet lag", "Staying up very late and sleeping until noon on weekends shifts your body clock, so Monday morning feels like flying across time zones."),
        ("Small changes", "Keep weekend wake-up times within about an hour or two of school days, and get daylight in the morning."),
    ], example: "Ana, 15, stayed up until 2 a.m. on weekends and dreaded Mondays. Keeping her weekend bedtime within an hour of her school-night one made Monday practices feel normal again.",
                 ["Similar bed and wake times every day.", "Big weekend shifts feel like jet lag.", "Morning daylight helps set your clock."]),

    campusLesson("sr-routine", "A bedtime routine that works", 3,
                 hook: ("Sleep starts an hour before bed", "Your brain needs a runway to slow down."), [
        ("Wind down", "The last 30–60 minutes: dim lights, calm activities, the same order every night. A shower, reading, calm music, preparing tomorrow's bag."),
        ("The bedroom", "Cool, dark and quiet works best. Keep the bed for sleep, not for long sessions on your phone."),
        ("If you can't sleep", "Don't lie there stressed. Get up, do something calm in dim light, and go back when you feel sleepy. Writing tomorrow's worries on paper can help clear your head."),
    ], example: "Callum, 17, lay awake thinking about games. He started writing a short to-do list and three things that went well each night before bed. Falling asleep got much easier.",
                 ["Same calm routine every night.", "Cool, dark, quiet bedroom.", "Can't sleep? Get up, stay calm, come back sleepy."]),

    campusLesson("sr-naps", "Naps that help", 3,
                 hook: ("Short and early", "A good nap can sharpen you. A bad one can wreck the night."), [
        ("How long", "About 20–30 minutes gives a boost without grogginess. Longer naps can leave you foggy and make night sleep harder."),
        ("When", "Early afternoon is best. Napping after about 4 p.m. often pushes bedtime later."),
        ("Not a replacement", "Naps help after a short night or on tournament days, but they don't replace a full night's sleep."),
    ], example: "Priya, 16, napped for two hours after school and then couldn't sleep until midnight. Switching to a 25-minute nap right after school gave her energy for practice without ruining her night.",
                 ["20–30 minutes, early afternoon.", "Long or late naps can hurt night sleep.", "Naps help; they don't replace nights."]),

    campusLesson("sr-school-stress", "School stress and recovery", 3,
                 hook: ("Your body doesn't know the difference", "Stress from exams and stress from training draw on the same recovery."), [
        ("Stress adds up", "A big test, problems with friends, worries at home — they raise stress hormones, disturb sleep and make training feel harder. That's not weakness; it's biology."),
        ("Adjust the plan", "During exam weeks, lighter training is smart, not lazy. AthleteOS lightens exam weeks automatically when your school calendar is connected."),
        ("Recovery for the mind", "Breaks, time outside, slow breathing, time with friends and enough sleep help your mind recover the same way rest helps your muscles."),
    ], example: "Matteo, 17, kept his full training load through finals week and got sick. The next term, he and his coach lightened exam weeks — and he trained and studied better.",
                 ["School stress and training stress add up.", "Lighter training in exam weeks is smart.", "Your mind needs recovery too."]),

    campusLesson("sr-travel", "Sleep when travelling", 3,
                 hook: ("Away games, new beds", "Travel disrupts sleep in predictable ways. Planning helps."), [
        ("New places", "Many people sleep lighter the first night somewhere new. Bring what helps you sleep at home: your pillow, an eye mask, earplugs, your routine."),
        ("Time zones", "Crossing time zones shifts your body clock. Get daylight at the new location in the morning, eat at local times, and try to sleep at local bedtime."),
        ("Long journeys", "Stand up and move every hour or so, drink water, and don't rely on caffeine to push through."),
    ], example: "Ella, 16, travelled three time zones for a tournament. She went outside in the morning light, kept meals to local times, and felt adjusted by the second day.",
                 ["Bring your sleep routine with you.", "Morning daylight helps reset your clock.", "Move and drink water on long journeys."]),

    campusLesson("sr-after-games", "Recovering after games and tournaments", 3,
                 hook: ("The next game starts after the last one ends", "What you do in the hours after competing decides how you feel next time."), [
        ("The first hours", "An easy cool-down, fluid, and a meal or snack with carbs and protein within a couple of hours."),
        ("The night", "Sleep is your strongest recovery tool. Late games make it hard; a calm routine and a dark room help you fall asleep after the excitement."),
        ("The next day", "Easy movement — a walk, an easy bike, mobility — usually feels better than complete rest. Save hard training until you feel fresh again."),
        ("Tournaments", "Between games: eat, drink, rest in the shade, keep moving lightly. Plan snacks and fluids before the day starts."),
    ], example: "Owen, 15, used to collapse on the couch after weekend tournaments and feel stiff until Wednesday. Eating soon after, sleeping well and doing an easy bike ride on Sunday had him fresh by Monday.",
                 ["Fuel and fluid soon after competing.", "Sleep is the strongest recovery tool.", "Easy movement the next day."]),

    campusLesson("sr-downshift", "Switching off: the nervous system", 4,
                 hook: ("Training turns you on. Recovery needs you to turn off.", "Your nervous system has an 'go' mode and a 'recover' mode. Athletes need both."), [
        ("Two modes", "The 'go' side raises heart rate and alertness for training and competition. The 'rest and digest' side lowers them so your body can recover, digest and sleep."),
        ("Stuck in go mode", "Hard training, late games, stress and screens can keep you in 'go' mode at night — wired but tired."),
        ("How to switch", "Slow breathing (longer out than in), calm movement, a warm shower, dim lights and quiet time all help your body shift into recovery mode."),
    ], example: "Ines, 17, couldn't sleep after evening games. Five minutes of slow breathing with a longer exhale, then dim lights and no phone, helped her fall asleep much faster.",
                 ["Your body needs a 'go' mode and a 'recover' mode.", "Late games and screens keep you switched on.", "Slow breathing and calm routines switch you off."]),
]

let sleepQuestions: [String: [CampusQuestion]] = [
    "sr-how-much": [
        .choice(prompt: "How much sleep do teenagers need?", options: ["6–7 hours", "8–10 hours", "11–12 hours"], answer: 1, explain: "The recommendation for 13- to 18-year-olds."),
        .trueFalse(statement: "Sleep helps your brain store skills you practised that day.", answer: true, explain: "Sleep is part of learning."),
    ],
    "sr-consistency": [
        .trueFalse(statement: "Sleeping until noon on weekends fully makes up for short school nights.", answer: false, explain: "Steady sleep every night works better."),
    ],
    "sr-routine": [
        .choice(prompt: "Can't fall asleep after 20 minutes?", options: ["Scroll until you're tired", "Get up, do something calm, come back sleepy", "Do push-ups"], answer: 1, explain: "Calm and dim, then back to bed."),
    ],
    "sr-naps": [
        .choice(prompt: "The best nap is usually…", options: ["2 hours at 6 p.m.", "20–30 minutes early afternoon", "Never"], answer: 1, explain: "Short and early."),
    ],
    "sr-school-stress": [
        .trueFalse(statement: "Lighter training during exam week is a smart choice.", answer: true, explain: "Stress from school and training add up."),
    ],
    "sr-travel": [
        .choice(prompt: "What helps your body clock adjust to a new time zone?", options: ["Morning daylight", "Napping all day", "Extra caffeine"], answer: 0, explain: "Light is the strongest signal."),
    ],
    "sr-after-games": [
        .trueFalse(statement: "Easy movement the day after a game often helps you feel better than complete rest.", answer: true, explain: "A walk, an easy bike, some mobility."),
    ],
    "sr-downshift": [
        .choice(prompt: "Which helps your body switch into recovery mode?", options: ["An intense video game", "Slow breathing with a long exhale", "An energy drink"], answer: 1, explain: "Long exhales calm the system."),
    ],
]
