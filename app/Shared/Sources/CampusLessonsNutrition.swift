import Foundation

// Nutrition & hydration (docs/VERSION-6.md §12): performance education,
// never dieting, never calorie restriction for teenagers.

let nutritionLessons: [CampusLesson] = [
    campusLesson("nu-carbs", "Carbohydrates: training fuel", 3,
                 hook: ("Carbs aren't the enemy", "For athletes, carbohydrates are the main fuel for hard training."), [
        ("What they do", "Your muscles store carbohydrate as fuel for fast, hard efforts — sprints, jumps, intense practice. When stores run low, you slow down and feel heavy."),
        ("Where to get them", "Rice, pasta, bread, potatoes, oats, fruit, cereals, milk and yoghurt. Whole grains and fruit bring extra fibre and vitamins."),
        ("More on bigger days", "Hard practice and game days need more carbohydrate; rest days a bit less. Your plate changes with your day — you don't need to count anything."),
    ], example: "Daniel, 16, cut out bread and pasta after seeing a video online. His practices felt flat within a week. When he brought them back, his energy returned.",
                 ["Carbs fuel hard training.", "Grains, potatoes, fruit and dairy all count.", "Bigger training day, bigger carb portion."]),

    campusLesson("nu-protein", "Protein: how much is enough", 3,
                 hook: ("Spread it out", "Protein repairs and builds muscle — but when you eat it matters almost as much as how much."), [
        ("What it does", "After training, your body uses protein to repair muscle and adapt. It also supports growth, which teenagers are doing a lot of."),
        ("Every meal", "A portion about the size of your palm at each meal — eggs, milk, yoghurt, cheese, meat, fish, beans, lentils, tofu — works better than one huge serving at dinner."),
        ("Food covers it", "Most teenage athletes who eat regular meals already get enough. Shakes are a convenience, not a requirement."),
    ], example: "Nora, 15, ate almost no protein at breakfast and lunch, then a big dinner. Adding yoghurt in the morning and a chicken wrap at lunch helped her recover better between practices.",
                 ["Protein supports repair and growth.", "A palm-sized portion at every meal.", "Regular meals usually cover what you need."]),

    campusLesson("nu-fats", "Fats aren't the enemy", 3,
                 hook: ("Your body needs fat", "Fat helps with hormones, brain health and absorbing some vitamins."), [
        ("Good sources", "Nuts, seeds, olive oil, avocado, fish, eggs and dairy. They make meals filling and help you get enough energy overall."),
        ("Timing", "Fat digests slowly, so very fatty meals right before training can sit heavy in your stomach. Have them earlier in the day or after training."),
        ("Not about cutting", "Athletes who try to remove fat often end up not eating enough overall. Balanced meals include some fat."),
    ], example: "Tom, 17, avoided all fat and felt hungry all the time. Adding nuts, olive oil and eggs made his meals more satisfying, and his energy evened out.",
                 ["Fat supports hormones, brain and vitamins.", "Keep heavy, fatty meals away from training.", "Balanced meals include some fat."]),

    campusLesson("nu-electrolytes", "Sweat, salt and electrolytes", 3,
                 hook: ("Sweat isn't just water", "When you sweat, you lose salt too — some athletes much more than others."), [
        ("What electrolytes are", "Minerals like sodium and potassium that help your muscles and nerves work and help your body hold on to fluid."),
        ("Salty sweaters", "If your clothes or face have white, salty marks after training, you lose more salt than average. On hot, long days you may need more salt in food or drinks."),
        ("Food first", "Most of the time, normal meals replace what you lose. Salty snacks, soup, milk and fruit after long or hot sessions help."),
    ], example: "Leo, 16, got cramps in hot afternoon practices. He noticed salty marks on his shirt. Adding a salty snack and drinking regularly during practice helped a lot.",
                 ["Sweat contains salt as well as water.", "Salty marks mean you lose more.", "Meals and salty snacks usually replace it."]),

    campusLesson("nu-pre-practice", "Eating before practice", 3,
                 hook: ("Don't train on empty", "Practice after a long school day with nothing since lunch is training with the fuel light on."), [
        ("2–3 hours before", "A normal meal: carbohydrate, some protein, not too much fat or fibre. A sandwich, rice and chicken, pasta."),
        ("30–60 minutes before", "A small, easy snack if it's been a while: a banana, a cereal bar, toast, a yoghurt."),
        ("Find what works for you", "Some athletes' stomachs are sensitive. Try different snacks in practice — never something new on game day."),
    ], example: "Sophie, 15, felt dizzy in afternoon practices. She had lunch at 11:30 and nothing until dinner. A banana and a yoghurt at 3 p.m. fixed it.",
                 ["Meal 2–3 hours before, snack 30–60 minutes before.", "Easy-to-digest carbs work best close to training.", "Test snacks in practice, not on game day."]),

    campusLesson("nu-game-day", "Competition-day fuel", 3,
                 hook: ("Game day isn't the day to experiment", "What you eat on game day should be familiar, easy and planned."), [
        ("The meal before", "Two to four hours before: a familiar meal with plenty of carbohydrate, some protein, and not too much fat or spice."),
        ("Between games and at halftime", "Water and easy carbohydrates: fruit, a sandwich, a sports drink on long or hot days. Tournaments need a plan and packed snacks."),
        ("After", "Within a couple of hours: a proper meal with carbs and protein, plus fluid. It starts recovery for the next game."),
    ], example: "Marcus, 16, ate fast food between tournament games and felt sluggish. The next time he packed rice, chicken, fruit and water. He felt much better in the third game.",
                 ["Familiar food, planned ahead.", "Easy carbs and fluid between games.", "A real meal after starts recovery."]),

    campusLesson("nu-growth", "Eating enough to grow and play", 4,
                 hook: ("You're fuelling two jobs", "Teen athletes need energy for training and for growing. Not eating enough affects both."), [
        ("Under-fuelling", "When athletes don't eat enough for their training — on purpose or not — the body starts saving energy. That can mean feeling tired, getting sick or injured more, poorer performance, mood changes, and for girls, missed or irregular periods."),
        ("It can happen by accident", "Busy schedules, skipped breakfast, long training days and small appetites after practice all add up. Many athletes under-fuel without trying."),
        ("What to do", "Regular meals and snacks, bigger portions on bigger days, and never skipping meals to change your weight. If you notice those signs, talk to a parent, doctor or sports dietitian — it's common and treatable."),
    ], example: "Maya, 16, a runner, felt worn out and had stress fractures twice in a year. Her doctor and a sports dietitian helped her eat more around training. Her energy came back, and she stayed injury-free the next season.",
                 ["Athletes need energy for training and growing.", "Tiredness, frequent injuries or missed periods are warning signs.", "Never skip meals to change your weight — talk to a professional."]),

    campusLesson("nu-timing", "Meal timing basics", 3,
                 hook: ("When you eat changes how you feel", "The same food at different times can help or hurt your training."), [
        ("Regular rhythm", "Three meals and a couple of snacks spread through the day keep energy steady and make it easier to eat enough."),
        ("Around training", "Fuel before, drink during, and eat a meal or snack with carbs and protein within a couple of hours after."),
        ("Evenings and sleep", "A normal dinner supports overnight recovery. A very large or very late meal can disturb sleep for some people."),
    ], example: "Elliot, 17, ate almost nothing until a huge dinner at 9 p.m. and slept badly. Spreading his food through the day gave him more energy at practice and better sleep.",
                 ["Spread food through the day.", "Before, during and after training each matter.", "Avoid very large, very late meals."]),
]

let nutritionQuestions: [String: [CampusQuestion]] = [
    "nu-carbs": [
        .trueFalse(statement: "Athletes should cut carbohydrates to perform better.", answer: false, explain: "Carbs are the main fuel for hard training."),
    ],
    "nu-protein": [
        .choice(prompt: "What's the best way to eat protein?", options: ["One huge portion at dinner", "A palm-sized portion at every meal", "Only shakes"], answer: 1, explain: "Spread it through the day."),
    ],
    "nu-fats": [
        .trueFalse(statement: "A very fatty meal right before practice is ideal.", answer: false, explain: "Fat digests slowly — have it away from training."),
    ],
    "nu-electrolytes": [
        .choice(prompt: "White, salty marks on your shirt after practice mean…", options: ["You lose more salt than average", "You're not working hard", "Nothing"], answer: 0, explain: "Salty sweaters may need more salt on long, hot days."),
    ],
    "nu-pre-practice": [
        .match(prompt: "Match the timing", pairs: [["2–3 hours before", "A normal meal"], ["30–60 min before", "An easy snack"], ["Game day", "Nothing new"]]),
    ],
    "nu-game-day": [
        .trueFalse(statement: "Game day is a good time to try a new food.", answer: false, explain: "Familiar food, planned ahead."),
    ],
    "nu-growth": [
        .choice(prompt: "Which can be a sign of not eating enough for training?", options: ["Always having energy", "Frequent injuries and illness", "Getting faster"], answer: 1,
                explain: "Talk to a parent, doctor or sports dietitian if you notice signs like this."),
    ],
    "nu-timing": [
        .trueFalse(statement: "Spreading meals and snacks through the day helps you eat enough.", answer: true, explain: "Steady rhythm, steady energy."),
    ],
]
