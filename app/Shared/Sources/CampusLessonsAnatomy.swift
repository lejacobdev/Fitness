import Foundation

// Anatomy & movement (docs/VERSION-6.md §12).

let anatomyLessons: [CampusLesson] = [
    campusLesson("am-muscles", "The muscles that move you", 4,
                 hook: ("Your engine has names", "Knowing the main muscles helps you understand every workout — and every coaching cue."), [
        ("The big lower-body muscles", "Glutes (your backside) drive you forward and up and keep your knees in line. Quadriceps (front of the thigh) straighten the knee for jumping and landing. Hamstrings (back of the thigh) power sprinting and help brake. Calves push you off the ground with every step."),
        ("The trunk", "The muscles around your stomach, sides and lower back don't just do sit-ups. Their main job is to stay firm so force can travel from your legs to your arms — in a throw, a tackle or a shot."),
        ("The upper body", "Chest and shoulders push. Upper back and lats (the big muscles down the side of your back) pull. The small rotator-cuff muscles keep the shoulder joint centred — important for every throwing and swinging sport."),
    ], example: "Riley, 15, wondered why her coach kept cueing 'glutes' during lunges. Once she knew what they did — power, and keeping her knee in line — the cue started to make sense, and her lunges looked much steadier.",
                 ["Glutes, quads, hamstrings and calves power most sport movements.", "The trunk's main job is to stay firm and transfer force.", "Push and pull muscles both need training."]),

    campusLesson("am-joints", "Joints: mobility and stability", 3,
                 hook: ("Some joints should move. Some should hold.", "A simple way coaches think about the body: alternating joints that need range and joints that need control."), [
        ("A useful simplification", "Ankles, hips and the upper back need good range of motion. Knees, the lower back and the shoulder blades mostly need control and stability. Real bodies are more complicated, but this pattern explains a lot."),
        ("When one joint can't move", "If your ankles are stiff, your knees or feet often make up for it when you squat or land. If your hips are stiff, your lower back may take extra strain."),
        ("What to do", "Mobility work for the joints that need range; strength and control work for the joints that need stability. Most good programmes include both."),
    ], example: "Ben, 16, felt his knees cave when he squatted. A physio found stiff ankles. Ankle mobility work plus single-leg strength fixed both the squat and his landings in basketball.",
                 ["Ankles, hips and upper back need range.", "Knees, lower back and shoulder blades need control.", "A stiff joint often makes another one work too hard."]),

    campusLesson("am-patterns", "The movement patterns", 3,
                 hook: ("Hundreds of exercises, a handful of patterns", "Almost every exercise is a version of a few basic movements."), [
        ("The patterns", "Squat (hips and knees bend together), hinge (bend at the hips, back flat), push (away from you), pull (toward you), lunge or single-leg, carry, rotate, and resist rotation. Jumping, throwing and sprinting are the fast versions."),
        ("Why they matter", "A balanced plan trains all of them over a week. That's how AthleteOS picks exercises: by pattern and purpose, not at random."),
        ("Swaps make sense", "If you swap an exercise, swap it for the same pattern. A goblet squat can replace a back squat; a push-up can't."),
    ], example: "Omar, 15, only did bench press and curls. When he learned the patterns, he added squats, hinges, rows and carries. His posture and his sport both improved.",
                 ["Squat, hinge, push, pull, single-leg, carry, rotate.", "A good week trains all the patterns.", "Swap exercises within the same pattern."]),

    campusLesson("am-squat-hinge", "Squat vs hinge", 3,
                 hook: ("Two ways to bend down", "They look similar. They train different things."), [
        ("Squat", "Hips and knees bend together, torso fairly upright: goblet squat, back squat, split squat. It loads the quads and glutes — great for jumping, landing and accelerating."),
        ("Hinge", "Hips push back, knees only slightly bent, back flat: Romanian deadlift, trap-bar deadlift, kettlebell swing. It loads the glutes and hamstrings — key for sprinting and protecting the hamstrings."),
        ("Train both", "Athletes need both patterns every week. AthleteOS alternates the main lower-body lift between them for this reason."),
    ], example: "Lily, 16, a sprinter, did lots of squats but almost no hinges. After a hamstring strain, her coach added Romanian deadlifts and Nordic curls. She stayed healthy the next season.",
                 ["Squat: hips and knees together.", "Hinge: hips back, back flat.", "Every athlete needs both, every week."]),

    campusLesson("am-push-pull", "Push and pull, balanced", 3,
                 hook: ("Bench press needs a partner", "Athletes love pushing exercises. Shoulders stay healthier when pulling gets equal attention."), [
        ("Why balance matters", "Lots of pushing and little pulling can pull the shoulders forward and leave the muscles that stabilise the shoulder blades weak — a common setup for shoulder pain in throwing and swimming sports."),
        ("A simple rule", "At least as much pulling as pushing: rows, pull-ups and face pulls alongside push-ups and presses."),
        ("Both directions", "Push and pull horizontally (push-ups, rows) and vertically (overhead presses, pull-ups) over the week."),
    ], example: "Noah, 17, a baseball pitcher, had sore shoulders every spring. Adding rows, pull-ups and band work, at least as much as his pressing, made his shoulders feel solid through the season.",
                 ["Pull at least as much as you push.", "Train both horizontal and vertical directions.", "Balanced shoulders are healthier shoulders."]),

    campusLesson("am-deceleration", "Braking: the forgotten skill", 3,
                 hook: ("Stopping is harder than starting", "Many non-contact injuries happen when an athlete slows down, lands or cuts — not when they speed up."), [
        ("What braking takes", "Strong muscles that can absorb force while lengthening (especially quads and hamstrings), plus good positions: knees in line with toes, hips back, chest over the knees."),
        ("How to train it", "Landing drills, stopping drills, slow lowering (eccentric) exercises, single-leg strength, and practising cuts at gradually higher speeds."),
        ("Why it matters", "An athlete who can stop quickly can also change direction quickly. Braking is both protection and performance."),
    ], example: "Hailey, 15, a soccer player, worked on stick-landings and slow step-downs for six weeks. Her coach noticed she cut more sharply — and she felt more confident landing headers.",
                 ["Many injuries happen when slowing down.", "Train landing, stopping and slow lowering.", "Better brakes mean faster direction changes."]),

    campusLesson("am-locomotion", "How running works", 4,
                 hook: ("Running is a series of jumps", "Each stride is a push into the ground. How you push decides how fast you go."), [
        ("Force into the ground", "Faster runners don't move their legs dramatically faster — they push harder into the ground in a short time. Strength and stiffness in the ankles and legs help."),
        ("Posture", "A slight forward lean when accelerating, tall when running fast, arms driving from the shoulders, relaxed face and hands."),
        ("Practise it", "Sprint drills (A-skips, B-skips), short sprints with good form, and strength training all improve running — and help prevent hamstring and calf injuries."),
    ], example: "Isaiah, 14, a football player, ran with tense shoulders and short steps. Twice-weekly sprint drills and short accelerations made his running look smoother and his 20-metre time dropped.",
                 ["Speed comes from force into the ground.", "Lean to accelerate, run tall at top speed.", "Drills, sprints and strength all help."]),

    campusLesson("am-mobility-stability", "Mobility isn't flexibility", 4,
                 hook: ("Touching your toes isn't the goal", "Flexibility is how far a joint can be moved. Mobility is how far you can move it yourself, with control."), [
        ("The difference", "A flexible hamstring can be stretched far by a partner. Mobility is being able to reach that range on your own, under control, in the movements your sport uses."),
        ("Range you can use", "Range without strength is hard to use and may not protect you. That's why good mobility work often looks like slow, controlled movements and strength at the end of your range."),
        ("Don't chase extremes", "Most athletes need enough mobility for their sport, not maximum flexibility. Gymnasts and dancers need more; a rower needs specific hip and ankle range."),
    ], example: "Freya, 16, a dancer, was very flexible but kept rolling her ankle. Adding strength in her end ranges — controlled balance and calf work — made her landings much more stable.",
                 ["Mobility is controlled, usable range.", "Strength at the end of range makes it usable.", "Enough for your sport beats maximum."]),

    campusLesson("am-coordination", "Coordination and movement quality", 4,
                 hook: ("Good movement looks easy", "The best athletes don't look like they're working hard. That's coordination."), [
        ("What coordination is", "Your brain timing your muscles: the right ones, in the right order, with the right amount of force. It's learned through practice — lots of quality repetitions."),
        ("Quality first", "Practising a movement badly under fatigue teaches the bad version. Learn new skills and exercises fresh, with good form, then add speed and load."),
        ("Variety helps", "Young athletes who play several sports or practise many different movements often develop better coordination — and transfer it to their main sport."),
    ], example: "Sami, 14, played soccer and in winter did a gymnastics class. His soccer coach noticed his balance and body control improved more than his teammates'.",
                 ["Coordination is learned with quality repetitions.", "Learn fresh; add speed and load later.", "Variety builds a better-moving athlete."]),
]

let anatomyQuestions: [String: [CampusQuestion]] = [
    "am-muscles": [
        .match(prompt: "Match the muscle to its job", pairs: [["Glutes", "Drive forward and up"], ["Hamstrings", "Power sprinting, help brake"], ["Rotator cuff", "Keep the shoulder centred"]]),
        .trueFalse(statement: "The trunk's main job is to stay firm and pass force from legs to arms.", answer: true, explain: "That's why anti-rotation work matters."),
    ],
    "am-joints": [
        .choice(prompt: "Which joint mostly needs control rather than lots of range?", options: ["Ankle", "Knee", "Upper back"], answer: 1, explain: "Ankles, hips and upper back need range; knees need control."),
    ],
    "am-patterns": [
        .choice(prompt: "What's a fair swap for a back squat?", options: ["A push-up", "A goblet squat", "A bicep curl"], answer: 1, explain: "Swap within the same pattern."),
    ],
    "am-squat-hinge": [
        .match(prompt: "Squat or hinge?", pairs: [["Goblet squat", "Squat"], ["Romanian deadlift", "Hinge"], ["Kettlebell swing", "Hinge"]]),
    ],
    "am-push-pull": [
        .trueFalse(statement: "For healthy shoulders, pull at least as much as you push.", answer: true, explain: "Rows and pull-ups balance presses."),
    ],
    "am-deceleration": [
        .trueFalse(statement: "Most non-contact injuries happen when athletes speed up, not when they slow down.", answer: false,
                   explain: "Landing, stopping and cutting are common moments."),
    ],
    "am-locomotion": [
        .choice(prompt: "What mainly makes runners faster?", options: ["Moving legs dramatically faster", "Pushing harder into the ground", "Longer arms"], answer: 1, explain: "Force into the ground."),
    ],
    "am-mobility-stability": [
        .choice(prompt: "Mobility is…", options: ["How far someone can stretch you", "Range you can control yourself", "Touching your toes"], answer: 1, explain: "Controlled, usable range."),
    ],
    "am-coordination": [
        .trueFalse(statement: "Practising a new skill while exhausted is the best way to learn it.", answer: false, explain: "Learn fresh with good form."),
    ],
]
