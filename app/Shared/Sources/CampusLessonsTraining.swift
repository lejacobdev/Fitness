import Foundation

// Training science (docs/VERSION-6.md §12).

let trainingScienceLessons: [CampusLesson] = [
    campusLesson("ts-sets-reps", "Sets, reps and rest", 4,
                 hook: ("3 × 8 means something", "The numbers on your workout aren't random. Each one changes what the exercise trains."), [
        ("Reps", "Fewer reps with more weight (around 4–6) build maximal strength. Moderate reps (6–12) build strength and muscle. Higher reps (12–15+) build muscular endurance. For teenagers, most strength work sits in the 6–15 range with good technique."),
        ("Sets", "One set is a start; two or three sets of the main exercises give most of the benefit for younger athletes. More isn't automatically better — quality drops when you're tired."),
        ("Rest", "Rest is part of the prescription. Heavy strength and power work needs 2–3 minutes so each set is high quality. Smaller exercises need less. Cutting rest short turns strength work into fatigue work."),
        ("Leave a little in the tank", "Most sets should end with one or two good reps you could still do. Grinding to failure every set adds fatigue without adding much strength."),
    ], example: "Tyler, 16, rushed through his squats with 45 seconds' rest because it felt harder. When he took the full two minutes, he lifted more with better form — and got stronger faster.",
                 ["Reps decide what you train.", "Two or three good sets beat five tired ones.", "Rest is part of the workout."]),

    campusLesson("ts-soreness", "Why soreness isn't the goal", 3,
                 hook: ("Sore doesn't mean it worked", "Muscle soreness the day after a workout is common. It's a poor sign of a good session."), [
        ("What soreness is", "Delayed soreness usually peaks one to three days after a new or unusual workout. It comes mostly from doing something your muscles aren't used to — especially lowering a weight slowly or running downhill."),
        ("Why it's a bad target", "As you repeat a workout, soreness fades even though you're still getting stronger. Chasing soreness pushes you toward random, too-hard sessions that leave you flat for practice."),
        ("Soreness vs pain", "Normal soreness is dull, in the muscle, on both sides, and eases as you warm up. Sharp pain, pain in a joint, or pain that gets worse as you move is different — stop and tell someone."),
    ], example: "Ella, 15, felt she hadn't trained properly unless she could barely walk the next day. Her coach switched her to steady, repeatable sessions. She was sore less often — and set personal bests all season.",
                 ["Soreness fades as your body adapts — that's good.", "Progress shows in performance, not in soreness.", "Sharp or joint pain means stop."]),

    campusLesson("ts-relative-strength", "Strength vs relative strength", 3,
                 hook: ("Strong for your size", "In most sports you move your own body. That's why strength relative to your body weight matters."), [
        ("Two kinds", "Absolute strength is the total force you can make — useful for linemen and throwers. Relative strength is how strong you are for your body weight — what lets you jump, sprint, climb and change direction quickly."),
        ("How it grows", "Strength training builds both. As you grow, your body weight changes too, so relative strength can dip during growth spurts. That's normal."),
        ("Not a reason to diet", "Relative strength is improved by getting stronger, not by trying to weigh less. For growing athletes, eating enough is part of getting stronger."),
    ], example: "Chris, 15, could squat more than his teammate but jumped lower. Adding single-leg and jumping work alongside his squats helped him use his strength faster.",
                 ["Relative strength drives jumping, sprinting and agility.", "Growth spurts can shuffle the numbers — normal.", "Get stronger; don't try to get lighter."]),

    campusLesson("ts-power", "What is power?", 3,
                 hook: ("Strong isn't enough — it has to be fast", "Power is how quickly you can produce force. It's what turns strength into a jump, a throw or a first step."),
        [
        ("Strength made fast", "Two athletes can lift the same weight. The one who can produce that force faster jumps higher and accelerates quicker. Power needs both strength and speed."),
        ("How to train it", "Jumps, throws, sprints and fast lifts, done with full effort, few reps and full rest. The aim is maximum speed on every rep — when reps get slow, stop."),
        ("Why it comes first", "Power work goes early in a session, after the warm-up, while you're fresh. Tired power work trains you to be slow."),
    ], example: "Jasmine, 16, a volleyball player, did her box jumps at the end of practice, exhausted. Moving them to the start of her gym sessions, with full rest, added height to her block within weeks.",
                 ["Power = force produced quickly.", "Few reps, full effort, full rest.", "Train it fresh, at the start of the session."]),

    campusLesson("ts-acceleration", "Acceleration and top speed", 4,
                 hook: ("The first five steps decide most races", "In most team sports you rarely reach top speed. Getting there quickly matters more."), [
        ("Acceleration", "The first 10–20 metres. Your body leans forward, you push the ground back hard, and each step gets a little longer. It depends on strength, power and technique."),
        ("Top speed", "Reached after roughly 30 metres or more. You run tall, with quick, stiff ground contacts. Sprinters, wide receivers and wingers need it most."),
        ("How to train them", "Short sprints at full effort with full recovery: think 10–30 m with a minute or more between reps. Speed is trained fast or not at all — tired sprints just train tired running."),
        ("Strength helps", "Stronger legs push harder into the ground. Strength training, jumps and good sprint technique all add up."),
    ], example: "Marco, 16, a soccer winger, did long sets of tired sprints at the end of practice. His coach switched him to six fresh 20-metre sprints with full rest twice a week. His first step got noticeably sharper.",
                 ["Acceleration: lean, push, short powerful steps.", "Top speed: tall, quick ground contacts.", "Sprint fresh, short and with full rest."]),

    campusLesson("ts-conditioning", "The kinds of conditioning", 4,
                 hook: ("Not all cardio is the same", "A 30-minute jog and ten 10-second sprints train very different things."), [
        ("Aerobic base", "Longer, easy work you could talk through. It builds the engine that helps you recover between efforts and during the week."),
        ("Aerobic intervals", "Harder efforts of a minute or a few minutes, with recovery between. They raise how much work your aerobic system can handle."),
        ("Tempo work", "Controlled running at about 70% of top speed, with walk-backs. It builds fitness without the fatigue of all-out sprints."),
        ("Repeated sprints and short hard efforts", "Bursts of a few seconds with short rest, like most field and court sports. Or very hard 10–20 second efforts for sports like wrestling."),
        ("Your sport already counts", "Practice is conditioning too. Cross-country runners get huge aerobic work from their sport; basketball practice is full of repeated sprints. Extra conditioning should fill a real gap, not just add more."),
    ], example: "Sara, 15, a golfer, thought conditioning didn't matter for her. Two easy 25-minute rides a week improved how she felt walking 18 holes and how well she recovered between tournament days.",
                 ["Different conditioning trains different engines.", "Easy aerobic work builds the base for everything else.", "Count what practice already gives you."]),

    campusLesson("ts-fatigue", "What fatigue really is", 3,
                 hook: ("Tired comes in different kinds", "Feeling tired after one hard session is different from being worn down after weeks of too much."), [
        ("Short-term fatigue", "During and right after training, your muscles and nervous system are tired. A good night's sleep and food usually reset it."),
        ("Accumulated fatigue", "When hard days stack up without enough recovery, tiredness builds over days or weeks. Performance stalls, motivation drops, and injury and illness risk rise."),
        ("What adds up", "Fatigue isn't only training. School stress, short sleep, travel, games and not eating enough all draw from the same account."),
        ("Listen and adjust", "That's why your morning check-in and evening reflection matter: they show patterns before they become problems, and the plan adjusts."),
    ], example: "Aiden, 17, a lacrosse player, felt more tired every week during exams. His check-ins showed it, and his plan lightened for two weeks. After exams, his energy — and his sprint times — came back.",
                 ["One hard day's fatigue resets with sleep and food.", "Stacked fatigue needs more recovery.", "School, sleep and stress count too."]),

    campusLesson("ts-specificity", "Specific and general training", 4,
                 hook: ("Should a soccer player only train like a soccer player?", "Training your sport's movements matters. So does being a well-rounded athlete."), [
        ("Specificity", "You get better at what you practise. Sport practice is the most specific training there is."),
        ("General development", "Strength, power, speed, conditioning, mobility and trunk control support every sport. A stronger, more robust athlete learns skills better and gets hurt less."),
        ("Why the gym shouldn't copy the sport", "Swinging a weighted bat or kicking with ankle weights doesn't make you better at your sport and can mess with technique. The gym builds the athlete; practice builds the skill."),
    ], example: "Ruby, 16, a tennis player, used to do only tennis-style drills in the gym. Adding squats, rows and single-leg work made her faster around the court without changing her stroke.",
                 ["Practice builds the skill; the gym builds the athlete.", "Every athlete needs general strength and conditioning.", "Don't add weight to sport movements."]),

    campusLesson("ts-in-season", "Training in season", 3,
                 hook: ("Don't stop lifting when games start", "Athletes who stop strength training in season often lose strength by the end — exactly when the big games come."), [
        ("Maintain, don't build", "In season, the aim is to keep what you built. One or two short sessions a week, with fewer sets but still decent effort, is usually enough."),
        ("Work around games", "Heavier work early in the week, lighter closer to games, nothing hard the day before. After a game, recovery first."),
        ("Practice is a big part", "Team practice already trains your legs and lungs heavily. In-season gym work focuses on what practice misses: upper-body strength, trunk, and injury prevention."),
    ], example: "Ava, 17, a basketball player, kept two 25-minute strength sessions a week through the season. At the end of the season she was as strong as at the start, while teammates who stopped felt slower in the playoffs.",
                 ["In season: maintain with short, regular sessions.", "Heavier early in the week, light before games.", "Focus on what practice doesn't train."]),

    campusLesson("ts-off-season", "Making the off-season count", 3,
                 hook: ("The season is where you perform. The off-season is where you improve.", "Most physical progress happens when there are no games to recover for."), [
        ("Rest first", "After a long season, a couple of easy weeks lets your body and mind recover. Stay active with things you enjoy."),
        ("Then build", "This is the time for longer gym sessions, more sets, and building strength, power and fitness — usually three sessions a week with real progression."),
        ("Pick a focus", "You can't improve everything at once. Choose one or two goals, like acceleration or strength, and build the off-season around them."),
        ("Get closer to the season", "As the season approaches, training gets more sport-like and less tiring, so you arrive fresh and sharp."),
    ], example: "Lucas, 15, played video games for most of his off-season and started the next season slower. The following year he took two easy weeks, then followed a six-week strength block — and started the season faster than ever.",
                 ["Recover first, then build.", "Pick one or two goals.", "Arrive at the season fresh, not exhausted."]),

    campusLesson("ts-more-less", "When more training makes you worse", 4,
                 hook: ("More isn't always better", "There's a point where extra training stops making you better and starts making you slower, tired and more likely to get hurt."), [
        ("Adaptation needs recovery", "Training is the stress; recovery is where you improve. If stress keeps outpacing recovery, you don't adapt — you wear down."),
        ("Spikes are risky", "Big, sudden jumps in training — a new team plus extra private sessions, or a week of double days — are linked with more injuries. Build up gradually."),
        ("Signs it's too much", "Performance stalling or dropping, feeling heavy for days, poor sleep, getting sick often, losing enjoyment, nagging aches. Those are signals to back off and talk to someone."),
    ], example: "Jake, 16, added extra running on top of soccer practice to get fitter. Two weeks later he had sore shins and felt slower. When he dropped the extra runs and slept more, he felt quick again.",
                 ["You improve during recovery.", "Avoid sudden big jumps in training.", "Stalling, poor sleep and constant aches mean back off."]),

    campusLesson("ts-frequency", "How often to train", 3,
                 hook: ("Twice a week, every week, beats five times in one week", "Consistency builds athletes. Bursts of motivation don't."), [
        ("Strength", "Two or three strength sessions a week works well for most young athletes, with at least a day between hard sessions for the same muscles."),
        ("Power and speed", "Short, sharp exposures one to three times a week, always fresh."),
        ("Everything else counts", "Practice, games and PE all count toward your week. More sessions only help if you can recover from them."),
        ("Consistency wins", "Small sessions done for months beat big sessions done for two weeks. Plan a routine you can keep."),
    ], example: "Emma, 15, did five gym sessions the first week of January and none by February. The next year she planned two sessions a week and kept them all year. She made more progress than ever.",
                 ["Two or three strength sessions a week is enough for most.", "Count practice and games too.", "A routine you can keep beats a perfect one you can't."]),
]

let trainingScienceQuestions: [String: [CampusQuestion]] = [
    "ts-sets-reps": [
        .choice(prompt: "Why rest 2–3 minutes between heavy sets?", options: ["To stay warm", "So every set is high quality", "It doesn't matter"], answer: 1,
                explain: "Short rest turns strength work into fatigue work."),
        .trueFalse(statement: "Every set should go to complete failure.", answer: false, explain: "Leaving a rep or two in the tank builds strength with less fatigue."),
    ],
    "ts-soreness": [
        .trueFalse(statement: "If you're not sore, the workout didn't work.", answer: false, explain: "Soreness fades as you adapt; progress shows in performance."),
        .choice(prompt: "Which needs you to stop and tell someone?", options: ["Dull soreness in both legs", "Sharp pain in a joint", "Tired muscles"], answer: 1, explain: "Sharp or joint pain isn't normal soreness."),
    ],
    "ts-relative-strength": [
        .trueFalse(statement: "The best way to improve relative strength as a teenager is to eat less.", answer: false, explain: "Get stronger and eat enough to grow."),
    ],
    "ts-power": [
        .fill(before: "Power is force produced", after: ".", options: ["quickly", "slowly", "rarely"], answer: "quickly", explain: "Strength made fast."),
        .choice(prompt: "When should jumps and throws happen in a session?", options: ["At the start, fresh", "At the end, tired", "Between every set of squats"], answer: 0, explain: "Tired power work trains you to be slow."),
    ],
    "ts-acceleration": [
        .choice(prompt: "How should sprints be trained?", options: ["Long sets with little rest", "Short, all-out, with full recovery", "Only at the end of practice"], answer: 1, explain: "Speed is trained fast or not at all."),
    ],
    "ts-conditioning": [
        .match(prompt: "Match the conditioning", pairs: [["Easy 30-minute ride", "Aerobic base"], ["6 × 10 m sprints, short rest", "Repeated sprints"], ["Runs at 70%, walk back", "Tempo"]]),
        .trueFalse(statement: "A cross-country runner usually needs extra running added to their training.", answer: false, explain: "Their sport already gives them huge aerobic work."),
    ],
    "ts-fatigue": [
        .trueFalse(statement: "School stress and short sleep add to the same fatigue as training.", answer: true, explain: "Your body has one recovery account."),
    ],
    "ts-specificity": [
        .trueFalse(statement: "Adding weight to your sport movements is the best gym training.", answer: false, explain: "It can harm technique; the gym builds the athlete, practice builds the skill."),
    ],
    "ts-in-season": [
        .choice(prompt: "What's the goal of in-season strength training?", options: ["Build as much as possible", "Maintain what you built", "Stop completely"], answer: 1, explain: "Short, regular sessions keep your strength for the big games."),
    ],
    "ts-off-season": [
        .choice(prompt: "What comes first after a long season?", options: ["The hardest training block", "A couple of easier weeks", "Nothing for three months"], answer: 1, explain: "Recover first, then build."),
    ],
    "ts-more-less": [
        .trueFalse(statement: "Big, sudden jumps in training are linked with more injuries.", answer: true, explain: "Build up gradually."),
    ],
    "ts-frequency": [
        .choice(prompt: "What usually builds the most progress?", options: ["Five sessions in one week, then none", "Two sessions a week for months", "One huge session a month"], answer: 1, explain: "Consistency wins."),
    ],
]
