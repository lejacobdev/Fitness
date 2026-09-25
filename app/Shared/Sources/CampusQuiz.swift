import Foundation

/// The exercises in each Campus lesson, Duolingo-style: pick one, true or
/// false, fill the blank from a word bank, and match the pairs.
public enum CampusQuestion: Hashable, Sendable {
    case choice(prompt: String, options: [String], answer: Int, explain: String)
    case trueFalse(statement: String, answer: Bool, explain: String)
    /// `before` ___ `after`; the right word is `answer`, one of `options`.
    case fill(before: String, after: String, options: [String], answer: String, explain: String)
    /// Pairs of [left, right]; the right column is shuffled.
    case match(prompt: String, pairs: [[String]])
}

/// One screen of a lesson: a short teaching card, or an exercise.
public enum CampusStep: Hashable, Sendable {
    case teach(CampusSection)
    case question(CampusQuestion)
}

public extension CampusLesson {
    var questions: [CampusQuestion] { campusQuestions[id] ?? [] }

    /// Teaching cards and exercises interleaved: learn a bit, use it straight away.
    var steps: [CampusStep] {
        var out: [CampusStep] = []
        var qs = questions[...]
        for section in sections {
            out.append(.teach(section))
            if let q = qs.popFirst() { out.append(.question(q)) }
        }
        out += qs.map { CampusStep.question($0) }
        return out
    }
}

public let campusQuestions: [String: [CampusQuestion]] = [
    // Training & exercise science
    "adaptation": [
        .choice(prompt: "When do you actually get fitter?", options: ["During the workout", "While you recover after it", "Only on game days"], answer: 1,
                explain: "Training is the stress; the rebuilding happens while you recover."),
        .trueFalse(statement: "Adding a lot more weight every session is the fastest safe way to improve.", answer: false,
                   explain: "Progress in small steps — big jumps are how athletes get hurt."),
        .fill(before: "Slowly increasing the challenge is called progressive", after: ".", options: ["overload", "rest", "taper"], answer: "overload",
              explain: "Progressive overload: a little more, week after week."),
        .match(prompt: "Match the athlete to what they need most", pairs: [["Sprinter", "Short, fast efforts"], ["Distance runner", "Easy aerobic miles"], ["Every athlete", "Recovery"]]),
    ],
    "qualities": [
        .choice(prompt: "Which quality supports almost every other one?", options: ["Flexibility", "Strength", "Balance"], answer: 1,
                explain: "Strength underpins sprinting, jumping, cutting and resisting injury."),
        .trueFalse(statement: "Supervised strength training with good technique is safe for teenagers.", answer: true,
                   explain: "Major sports-medicine bodies agree it's safe and effective."),
        .choice(prompt: "When should you train power — jumps, throws, sprints?", options: ["At the end of a tiring session", "Fresh, with full rest", "It doesn't matter"], answer: 1,
                explain: "Power needs full effort, so train it fresh with full rest between reps."),
        .fill(before: "Most easy aerobic work should feel", after: ".", options: ["conversational", "exhausting", "painful"], answer: "conversational",
              explain: "If you can talk in sentences, it's easy enough."),
    ],
    "warm-up": [
        .match(prompt: "Match the warm-up step", pairs: [["Raise", "Light jog"], ["Activate", "Wake up glutes"], ["Mobilise", "Full-range movement"], ["Potentiate", "A few fast efforts"]]),
        .trueFalse(statement: "Long static stretches right before sprinting can make you briefly slower.", answer: true,
                   explain: "Move dynamically before training; save long holds for after."),
        .choice(prompt: "How long should a good warm-up take?", options: ["2 minutes", "10–15 minutes", "45 minutes"], answer: 1,
                explain: "10–15 minutes gets your body ready without tiring you out."),
        .fill(before: "Hold longer stretches", after: "training.", options: ["after", "right before", "instead of"], answer: "after",
              explain: "Long holds fit best after training or in the evening."),
    ],
    // Nutrition & hydration
    "fuel-basics": [
        .choice(prompt: "What's the main fuel for hard training?", options: ["Carbohydrates", "Fats", "Vitamins"], answer: 0,
                explain: "Carbs refill the energy stores your muscles use in hard training."),
        .fill(before: "Spread protein across the day — about", after: "per meal.", options: ["20–30 g", "100 g", "5 g"], answer: "20–30 g",
              explain: "Several moderate servings beat one huge one."),
        .trueFalse(statement: "Athletes should cut out all fats.", answer: false,
                   explain: "Healthy fats support hormones and health — just not a big fatty meal right before training."),
        .match(prompt: "Match the food to its main nutrient", pairs: [["Rice", "Carbohydrates"], ["Eggs", "Protein"], ["Olive oil", "Fat"]]),
    ],
    "hydration": [
        .choice(prompt: "A simple sign you're well hydrated:", options: ["Dark urine", "Pale-yellow urine", "Feeling thirsty"], answer: 1,
                explain: "Pale yellow means you're on track."),
        .trueFalse(statement: "For long or very sweaty sessions, adding sodium helps.", answer: true,
                   explain: "A sports drink or salty snack replaces the salt you sweat out."),
        .fill(before: "During long sessions, sip water every", after: "minutes.", options: ["15–20", "60", "2"], answer: "15–20",
              explain: "Small, regular sips keep you topped up."),
        .trueFalse(statement: "Forcing down huge amounts of plain water is always safe.", answer: false,
                   explain: "Too much plain water can be harmful. Drink to a plan and to thirst."),
    ],
    "recovery-eating": [
        .choice(prompt: "Best snack 30–60 minutes before training?", options: ["A banana or toast", "A big burger", "Nothing, ever"], answer: 0,
                explain: "A small, easy carb snack gives energy without a heavy stomach."),
        .choice(prompt: "After training, eat…", options: ["Only protein", "Carbs and protein", "Nothing for five hours"], answer: 1,
                explain: "Carbs refill fuel; protein starts the repair."),
        .trueFalse(statement: "Crash diets can lead to low energy, more illness and more injuries.", answer: true,
                   explain: "Growing athletes need enough energy every day."),
        .fill(before: "Weight goals in sport? Always talk to a", after: ".", options: ["doctor or sports dietitian", "teammate", "random video"], answer: "doctor or sports dietitian",
              explain: "Never guess alone — get a professional involved."),
    ],
    // Injury prevention & anatomy
    "body-basics": [
        .match(prompt: "Match the body part to its job", pairs: [["Muscle", "Pulls to move bones"], ["Tendon", "Links muscle to bone"], ["Ligament", "Holds bones together"]]),
        .trueFalse(statement: "Tendons adapt faster than muscles.", answer: false,
                   explain: "Tendons adapt slower — that's why load should build gradually."),
        .choice(prompt: "Which muscles drive sprinting and jumping most?", options: ["Glutes and hamstrings", "Biceps", "Neck muscles"], answer: 0,
                explain: "Glutes and hamstrings are the engine of sprinting and jumping."),
        .choice(prompt: "During a growth spurt you should…", options: ["Train harder than ever", "Take heel and knee pain seriously", "Stop all sport"], answer: 1,
                explain: "Growth spurts make bones and growth plates more vulnerable."),
    ],
    "pain": [
        .choice(prompt: "Which one is normal muscle soreness?", options: ["Sharp pain in a joint", "A dull ache that eases as you warm up", "Pain that wakes you at night"], answer: 1,
                explain: "Dull, spread out and easing with movement is normal soreness."),
        .trueFalse(statement: "After a hit to the head you can keep playing if you feel okay.", answer: false,
                   explain: "Always stop and get checked — never play through a possible concussion."),
        .choice(prompt: "You felt a pop and your knee swelled. What now?", options: ["Play through it", "Stop and get it checked", "Train on it tomorrow"], answer: 1,
                explain: "A pop plus swelling needs a professional to look at it."),
        .fill(before: "Tell a coach or trainer about pain", after: ".", options: ["early", "after the season", "never"], answer: "early",
              explain: "Caught early, most problems are a few days off."),
    ],
    "technique-load": [
        .choice(prompt: "When should you add weight to a lift?", options: ["When every rep looks the same", "After your first rep", "Never"], answer: 0,
                explain: "Consistent technique first, then load."),
        .trueFalse(statement: "Injuries often follow sudden jumps in training.", answer: true,
                   explain: "New camps and first weeks back are classic spike moments."),
        .match(prompt: "Match the prevention exercise to the area it protects", pairs: [["Nordic curl", "Hamstrings"], ["Copenhagen plank", "Groin"], ["External rotation", "Shoulder"]]),
        .fill(before: "Learn a movement", after: "before going heavy.", options: ["light", "heavy", "tired"], answer: "light",
              explain: "Master it light, then add load."),
    ],
    // Sleep & recovery
    "sleep-power": [
        .choice(prompt: "How much sleep do teenagers generally need?", options: ["5–6 hours", "8–10 hours", "12–14 hours"], answer: 1,
                explain: "8–10 hours is the usual recommendation for teens."),
        .trueFalse(statement: "Screens right before bed can make sleep worse.", answer: true,
                   explain: "Put screens away 30–60 minutes before bed."),
        .fill(before: "Keep your bedroom dark and", after: ".", options: ["cool", "hot", "bright"], answer: "cool",
              explain: "Dark and cool helps you fall and stay asleep."),
        .choice(prompt: "The best kind of nap:", options: ["20–30 minutes, early afternoon", "3 hours in the evening", "Never nap"], answer: 0,
                explain: "Short and early — long late naps wreck the night."),
    ],
    "rest-days": [
        .choice(prompt: "How many full rest days a week, at minimum?", options: ["None", "At least one", "Five"], answer: 1,
                explain: "Muscles, tendons and your nervous system need time to rebuild."),
        .trueFalse(statement: "Active recovery should feel hard.", answer: false,
                   explain: "Recovery only works if it stays truly easy."),
        .trueFalse(statement: "Taking breaks from your main sport during the year lowers overuse-injury risk.", answer: true,
                   explain: "Breaks and variety reduce overuse injuries and burnout."),
        .fill(before: "On recovery days, easy means", after: ".", options: ["easy", "medium", "max effort"], answer: "easy",
              explain: "Keep it easy — really easy."),
    ],
    "overtraining": [
        .choice(prompt: "Which can signal too much fatigue?", options: ["Weeks of worse performance and poor sleep", "One tough practice", "Being hungry after training"], answer: 0,
                explain: "A pattern over weeks is the warning, not one hard day."),
        .trueFalse(statement: "Exam stress has no effect on your training.", answer: false,
                   explain: "Your body doesn't separate school stress from training stress."),
        .choice(prompt: "What helps your plan ease off before you dig a hole?", options: ["Skipping check-ins", "Your daily morning check-in", "Training more"], answer: 1,
                explain: "Daily check-ins let the plan spot fatigue early."),
        .fill(before: "Life stress counts as", after: "stress.", options: ["training", "no", "good"], answer: "training",
              explain: "Busy weeks may need lighter training."),
    ],
    // Sports psychology
    "confidence": [
        .choice(prompt: "The strongest source of confidence:", options: ["Hoping it goes well", "Preparation you can point to", "Comparing yourself with others"], answer: 1,
                explain: "Confidence built on real preparation holds up on bad days."),
        .choice(prompt: "Which is the most helpful self-talk?", options: ["\"Don't mess up\"", "\"Drive the knee\"", "\"I always choke\""], answer: 1,
                explain: "Short, specific and positive — like a good coach."),
        .choice(prompt: "Which of these can you control?", options: ["The referee", "The weather", "Your effort"], answer: 2,
                explain: "Put your energy into effort, attitude and preparation."),
        .trueFalse(statement: "Swapping \"I can't\" for \"I'm learning to\" is useful self-talk.", answer: true,
                   explain: "It keeps you focused on getting better."),
    ],
    "pressure": [
        .trueFalse(statement: "Butterflies before a game mean you're not ready.", answer: false,
                   explain: "They're your body getting ready to perform."),
        .choice(prompt: "A calming breathing pattern:", options: ["In for 4, out for 6", "In for 6, out for 1", "Hold your breath"], answer: 0,
                explain: "Long exhales calm your body in under a minute."),
        .fill(before: "A short pre-performance", after: "helps you lock in under pressure.", options: ["routine", "argument", "snack"], answer: "routine",
              explain: "Same breath, same cue word, same movement — every time."),
        .choice(prompt: "Reframe \"I'm nervous\" as…", options: ["\"I'm excited\"", "\"I'm doomed\"", "\"I'm tired\""], answer: 0,
                explain: "Same feeling, pointed forward."),
    ],
    "mistakes": [
        .choice(prompt: "After a mistake, the best move is to…", options: ["Replay it all game", "Reset and play the next play", "Argue with the referee"], answer: 1,
                explain: "Next play. The fastest reset wins."),
        .fill(before: "Say a reset word like", after: "after a mistake.", options: ["\"next\"", "\"why\"", "\"again\""], answer: "\"next\"",
              explain: "Pair it with a physical reset, like a clap."),
        .trueFalse(statement: "Dwelling on a loss for days makes you better.", answer: false,
                   explain: "Reflect once, then let practice do the work."),
        .choice(prompt: "A good post-game reflection:", options: ["Two things that went well, one to improve", "Only list your mistakes", "Don't think about it at all"], answer: 0,
                explain: "Balanced and short — then move on."),
    ],
    // Technique & biomechanics
    "force": [
        .trueFalse(statement: "Sprinting fast is mostly about moving your legs quickly in the air.", answer: false,
                   explain: "It's about pushing the ground hard, under your hips."),
        .choice(prompt: "In a throw or swing, what should turn first?", options: ["The shoulders", "The hips", "The hands"], answer: 1,
                explain: "Hips lead, shoulders follow — each part passes speed to the next."),
        .fill(before: "A stable", after: "transfers power from legs to arms.", options: ["trunk", "wrist", "neck"], answer: "trunk",
              explain: "That's why planks and anti-rotation work matter."),
        .choice(prompt: "Why do planks and anti-rotation exercises matter?", options: ["They make you taller", "They stop force leaking away", "They replace cardio"], answer: 1,
                explain: "A stiff trunk lets force pass through instead of leaking."),
    ],
    "landing": [
        .choice(prompt: "When you land, your knees should…", options: ["Cave inward", "Stay in line with your toes", "Lock straight"], answer: 1,
                explain: "Knees over toes protects the knee."),
        .trueFalse(statement: "Landing quietly is a good sign.", answer: true,
                   explain: "Quiet landings mean your muscles are absorbing the force."),
        .choice(prompt: "Before a sharp cut you should…", options: ["Stay upright", "Lower your hips a few steps early", "Close your eyes"], answer: 1,
                explain: "Getting low early makes the cut faster and safer."),
        .fill(before: "Practise landings like a", after: ".", options: ["skill", "punishment", "cool-down"], answer: "skill",
              explain: "Jump-and-stick drills train it."),
    ],
    "feedback": [
        .choice(prompt: "How many cues should you focus on at once?", options: ["One", "Five", "Ten"], answer: 0,
                explain: "Too many cues make movement stiff."),
        .match(prompt: "Put the learning steps in order", pairs: [["First", "Slow and light"], ["Then", "Fast"], ["Finally", "Under pressure"]]),
        .trueFalse(statement: "Filming yourself shows things you can't feel.", answer: true,
                   explain: "A side-on phone video is one of the best coaching tools."),
        .fill(before: "Film, compare,", after: ".", options: ["adjust", "delete", "ignore"], answer: "adjust",
              explain: "Then film again."),
    ],
    // Tactics
    "reading": [
        .choice(prompt: "When should you scan the field?", options: ["After you receive", "Before the ball arrives", "Never"], answer: 1,
                explain: "Know your next move before the ball gets to you."),
        .choice(prompt: "To see through a fake, watch the opponent's…", options: ["Eyes", "Hips", "Shoes"], answer: 1,
                explain: "The hips show where they're really going."),
        .trueFalse(statement: "Opponents often repeat what works for them.", answer: true,
                   explain: "Spot their favourite pattern and prepare for it."),
        .fill(before: "Top players", after: "before the ball arrives.", options: ["scan", "sit", "stop"], answer: "scan",
              explain: "A quick look over the shoulder, every time."),
    ],
    "positioning": [
        .choice(prompt: "Under pressure, the best choice is usually…", options: ["The spectacular risky play", "The simple correct play", "Doing nothing"], answer: 1,
                explain: "Make the easy play."),
        .trueFalse(statement: "Knowing the rules deeply can win you points.", answer: true,
                   explain: "Use the rules — and avoid giving away easy points."),
        .fill(before: "Good positioning is about", after: "and vision.", options: ["angles", "luck", "speed only"], answer: "angles",
              explain: "See the play, cut off options, open lanes for teammates."),
        .choice(prompt: "How often should you refresh your sport's rules?", options: ["Once a season", "Never", "Every day"], answer: 0,
                explain: "A quick read each season keeps you sharp."),
    ],
    "game-plan": [
        .choice(prompt: "How many personal focus points per game?", options: ["One or two", "Ten", "None"], answer: 0,
                explain: "Short enough to remember under pressure."),
        .trueFalse(statement: "A good decision that failed is still a good decision.", answer: true,
                   explain: "Judge the decision, not only the outcome."),
        .fill(before: "Check the plan at every", after: ".", options: ["break", "goal", "meal"], answer: "break",
              explain: "Timeouts, between points, halftime."),
        .choice(prompt: "After the game, review…", options: ["Only the score", "Your decisions", "Nothing"], answer: 1,
                explain: "Decisions are what you can improve."),
    ],
    // Performance tracking
    "what-matters": [
        .choice(prompt: "How many measures should you track?", options: ["A handful linked to your sport", "Everything possible", "None"], answer: 0,
                explain: "A few meaningful numbers beat a pile of noise."),
        .trueFalse(statement: "One bad test day means you got worse.", answer: false,
                   explain: "Look at the trend over weeks."),
        .fill(before: "Training load = effort ×", after: ".", options: ["minutes", "shoe size", "sleep"], answer: "minutes",
              explain: "How hard times how long."),
        .choice(prompt: "A warning sign in your training load:", options: ["A steady build-up", "A sudden big jump", "A rest day"], answer: 1,
                explain: "Sudden spikes are linked to injuries."),
    ],
    "check-ins": [
        .choice(prompt: "Your check-in numbers mean most compared with…", options: ["Your own normal", "Your teammates", "Pro athletes"], answer: 0,
                explain: "The app learns your baseline."),
        .trueFalse(statement: "You only need to check in on training days.", answer: false,
                   explain: "Every day — consistency is what makes the numbers useful."),
        .choice(prompt: "When your readiness is low, the plan…", options: ["Gets harder", "Lightens the session", "Deletes your week"], answer: 1,
                explain: "And you can always override it."),
        .fill(before: "A check-in takes about", after: "seconds.", options: ["ten", "sixty", "three hundred"], answer: "ten",
              explain: "Ten seconds a day."),
    ],
    "healthy-data": [
        .trueFalse(statement: "Numbers decide your worth as an athlete.", answer: false,
                   explain: "Numbers guide training — they don't judge you."),
        .choice(prompt: "Compare yourself mostly with…", options: ["Other athletes online", "Yourself last season", "Your coach"], answer: 1,
                explain: "Everyone develops at a different time."),
        .fill(before: "Use numbers and", after: "together.", options: ["feel", "luck", "guesses"], answer: "feel",
              explain: "How you feel and move is data too."),
        .choice(prompt: "If tracking starts making you anxious…", options: ["Track more", "Track less and talk to someone", "Hide it"], answer: 1,
                explain: "Data is there to serve you."),
    ],
    // Communication & teamwork
    "coach": [
        .choice(prompt: "A great question for your coach:", options: ["\"What's one thing I should work on?\"", "\"Why am I even here?\"", "No questions, ever"], answer: 0,
                explain: "Specific questions get useful answers."),
        .trueFalse(statement: "Coaches can adjust plans for problems they don't know about.", answer: false,
                   explain: "Tell them early — they can't fix what they don't know."),
        .match(prompt: "Taking feedback, step by step", pairs: [["First", "Listen fully"], ["Then", "Say thanks"], ["Finally", "Try it"]]),
        .fill(before: "Tell your coach about pain or stress", after: ".", options: ["early", "never", "after the season"], answer: "early",
              explain: "Early is always better."),
    ],
    "teammates": [
        .choice(prompt: "Best on-field communication:", options: ["Long explanations", "Short, loud, specific calls", "Silence"], answer: 1,
                explain: "\"Man on\", \"switch\", \"mine\"."),
        .trueFalse(statement: "Encouraging a teammate after a mistake helps the whole team.", answer: true,
                   explain: "Energy is contagious — in both directions."),
        .fill(before: "The most common communication error is", after: ".", options: ["silence", "shouting", "high-fives"], answer: "silence",
              explain: "Talk more than you think you need to."),
        .choice(prompt: "Respect is owed to…", options: ["Only the best players", "Teammates, officials and opponents", "Nobody"], answer: 1,
                explain: "Teams that trust each other perform better under pressure."),
    ],
    "leadership": [
        .trueFalse(statement: "You need to be captain to be a leader.", answer: false,
                   explain: "Leadership is behaviour, not a title."),
        .choice(prompt: "Leading by example looks like…", options: ["Arriving on time and finishing every rep", "Telling others what to do", "Skipping the boring work"], answer: 0,
                explain: "Doing the ordinary things well, every day."),
        .fill(before: "Notice who's quiet or", after: "and include them.", options: ["new", "fast", "tall"], answer: "new",
              explain: "Strong teams make everyone feel part of it."),
        .choice(prompt: "Handle conflict…", options: ["Early and privately", "Publicly online", "Never"], answer: 0,
                explain: "Small issues grow when ignored."),
    ],
    // Long-term development
    "years": [
        .choice(prompt: "When do most athletes reach their best?", options: ["At 14", "In their twenties", "At 10"], answer: 1,
                explain: "What you build now sets up your best years."),
        .trueFalse(statement: "Results at 14 reliably predict who succeeds as an adult.", answer: false,
                   explain: "Late bloomers are often outstanding later."),
        .fill(before: "Build steadily and don't", after: "peaks.", options: ["force", "plan", "enjoy"], answer: "force",
              explain: "Forcing peaks as a teen leads to burnout and injury."),
        .choice(prompt: "Late bloomers…", options: ["Never catch up", "Are often outstanding later", "Should quit"], answer: 1,
                explain: "Maturity timing varies a lot."),
    ],
    "specialise": [
        .trueFalse(statement: "Playing several sports is linked to fewer overuse injuries.", answer: true,
                   explain: "Variety builds better, healthier athletes."),
        .choice(prompt: "A simple guide for weekly training hours:", options: ["Roughly your age", "Double your age", "As many as possible"], answer: 0,
                explain: "A common guideline from sports medicine."),
        .fill(before: "One of the strongest reasons athletes keep playing is", after: ".", options: ["enjoyment", "pressure", "trophies"], answer: "enjoyment",
              explain: "Protect the fun."),
        .choice(prompt: "Training your main sport year-round with no breaks is…", options: ["Recommended", "Best avoided", "Required"], answer: 1,
                explain: "Planned breaks reduce overuse injuries and burnout."),
    ],
    "balance": [
        .choice(prompt: "Heavy exam week? A smart move is…", options: ["Lighter training and telling your coach", "Doubling training", "Skipping sleep"], answer: 0,
                explain: "Plan sport and school together."),
        .trueFalse(statement: "Your identity is more than your sport.", answer: true,
                   explain: "Friends, family and hobbies make you healthier — and a better athlete over time."),
        .fill(before: "Put training, games and school in", after: "plan.", options: ["one", "no", "three"], answer: "one",
              explain: "One plan, no surprises."),
        .choice(prompt: "If sport feels like too much pressure…", options: ["Keep it to yourself", "Talk to someone you trust", "Quit instantly"], answer: 1,
                explain: "A parent, coach or counsellor can help."),
    ],
]
