import Foundation

// Sports psychology (docs/VERSION-6.md §12): useful skills, not motivational quotes.

let psychologyLessons: [CampusLesson] = [
    campusLesson("ps-focus", "Focus and attention", 4,
                 hook: ("Where your attention goes, your body follows", "Focus isn't trying harder. It's choosing what to pay attention to."), [
        ("Outside beats inside", "Studies on learning movements find that focusing on the effect you want — 'drive the ground away', 'hit the back of the net', 'reach the cone' — usually works better than thinking about body parts like 'bend your knees'. Save body-part cues for practice; use outcome cues in games."),
        ("Narrow and broad", "Some moments need a narrow focus (a free throw, a serve). Others need a broad one (reading the field, scanning for a pass). Good athletes switch between the two on purpose."),
        ("Bring it back", "Everyone's focus drifts. The skill is noticing it and returning quickly. A cue word ('next', 'here', 'eyes up') or a breath can be the signal to come back."),
    ], example: "Diego, 16, a basketball player, used to think 'elbow in, wrist snap' at the free-throw line and tensed up. He switched to one cue — 'soft over the front of the rim' — and his percentage climbed.",
                 ["Focus on the outcome you want, not your body parts, in games.", "Switch between narrow and broad focus on purpose.", "Noticing and returning is the skill."]),

    campusLesson("ps-motivation", "Motivation that lasts", 3,
                 hook: ("Motivation comes and goes. Habits stay.", "Even the best athletes don't feel motivated every day. They show up anyway."), [
        ("Two kinds", "Motivation that comes from enjoying the sport, getting better and being part of a team tends to last. Motivation that comes only from trophies, approval or fear of letting people down tends to burn out."),
        ("Don't wait for it", "Waiting to feel motivated is unreliable. Make the next step small and specific — 'pack my bag', 'do the warm-up' — and motivation often follows action."),
        ("Low motivation is information", "A short dip is normal. Weeks of not wanting to play at all can mean too much training, stress, or something else going on — worth talking about with someone you trust."),
    ], example: "Lena, 15, a swimmer, dreaded 5 a.m. practice. She stopped asking herself whether she felt like going and set one rule: get to the pool. Once there, she almost always swam well.",
                 ["Enjoyment and getting better make motivation last.", "Action often comes before motivation.", "Long-lasting low motivation is worth talking about."]),

    campusLesson("ps-goals", "Process, performance and outcome goals", 4,
                 hook: ("You can't control winning", "Winning depends on opponents, referees and luck. Goals that work focus on what you can control."), [
        ("Three kinds of goals", "Outcome goals are about results: win the league, make varsity. Performance goals are about your numbers: run 400 m in 60 seconds, make 75% of free throws. Process goals are about how: 'drive my arms', 'call for the ball early'."),
        ("Use all three, lean on process", "Outcome goals give direction; performance goals measure progress; process goals are what you actually think about while training and competing. Athletes who focus on process are less anxious and often perform better."),
        ("Make them specific", "'Get better at defence' is a wish. 'Stay in a low stance for every possession in practice this week' is a goal."),
    ], example: "Amir, 17, wanted to make the state final. His coach helped him add a performance goal (a faster 200 m) and two process goals (relaxed shoulders, fast first 30 metres). He thought only about the process goals during races.",
                 ["Outcome gives direction; process gives control.", "Think about process during performance.", "Specific beats vague."]),

    campusLesson("ps-self-talk", "Self-talk that helps", 3,
                 hook: ("You're always talking to yourself", "The question is whether that voice is coaching you or criticising you."), [
        ("Two useful kinds", "Instructional self-talk tells you what to do ('stay low', 'follow through') and helps with skill and precision. Motivational self-talk lifts effort ('keep going', 'I've trained for this') and helps with endurance and confidence."),
        ("Talk to yourself like a teammate", "Would you call a teammate 'useless' after a mistake? Harsh self-talk raises tension and makes the next mistake more likely. Firm, specific and kind works better."),
        ("Prepare your words", "Pick two or three phrases before training or a game. Under pressure, it's much easier to use words you already chose."),
    ], example: "Mia, 16, a tennis player, said 'don't double fault' before every second serve — and often did. She changed it to 'loose arm, high toss'. Her double faults dropped.",
                 ["Instructional cues for skill, motivational cues for effort.", "Talk to yourself like a good teammate would.", "Choose your words before you need them."]),

    campusLesson("ps-imagery", "Imagery: practise in your head", 4,
                 hook: ("Your brain can rehearse", "Imagining a skill clearly uses many of the same brain areas as doing it."), [
        ("What imagery is", "Picturing and feeling yourself performing a skill or situation: the sights, the sounds, the feel of the ball, your heartbeat. The more senses, the better."),
        ("Make it realistic", "Imagine it in real time, from your own eyes, in the place you'll compete, including pressure and including how you'd respond to a mistake. Real conditions make the practice transfer."),
        ("When to use it", "A few minutes before bed, before practice, when injured and can't train, or right before a skill (a penalty, a routine). It adds to physical practice; it doesn't replace it."),
    ], example: "Owen, 15, a gymnast with a sprained wrist, spent ten minutes a day imagining his beam routine in detail. When he came back, his coach said his timing was sharper than his teammates expected.",
                 ["Use all your senses.", "Imagine real conditions, real speed, real pressure.", "Imagery adds to practice — especially when you can't train."]),

    campusLesson("ps-routines", "Pre-performance routines", 3,
                 hook: ("The same steps, every time", "Many top athletes do the same small routine before every serve, kick or shot. It isn't superstition."), [
        ("Why routines work", "A routine gives your attention something useful to do, keeps nerves from taking over, and tells your body 'this is the moment'. It makes pressure situations feel familiar."),
        ("Build your own", "Keep it short and the same: a breath, a cue word, a picture of what you want, then go. Practise it in training so it's automatic in games."),
        ("Routines, not rituals", "A routine helps you focus. A ritual you think you 'need' — lucky socks, a fixed song — can become a source of panic when it goes wrong. Keep routines flexible and in your control."),
    ], example: "Sofia, 17, a volleyball server, uses the same routine every time: two bounces, one breath, 'firm and deep', serve. In a tight fifth set, it was the one thing that felt normal.",
                 ["Short, the same, practised in training.", "A breath, a cue, a picture, go.", "Keep it in your control."]),

    campusLesson("ps-reset", "Reset routines after mistakes", 3,
                 hook: ("The next play is the only one you can change", "Mistakes happen in every game. The difference is how long they last."), [
        ("Have a reset", "A quick physical action that means 'done': wiping your hands, touching your shoe, a breath out. Then a cue word for the next play. Elite athletes use this exact pattern."),
        ("Recognise, release, refocus", "Notice what happened (one second), let it go (the action), and focus on your next job (the cue). Analysis comes after the game, not during it."),
        ("Practise resetting", "Use your reset in practice after every mistake, even small ones. Then it's automatic when it matters."),
    ], example: "Jack, 16, a goalkeeper, let in a soft goal early. He wiped his gloves on his shorts, said 'next ball', and made three saves before half-time.",
                 ["One physical action, one cue word.", "Recognise, release, refocus.", "Analyse after, not during."]),

    campusLesson("ps-emotions", "Emotional control", 4,
                 hook: ("Emotions aren't the problem", "Feeling angry, nervous or frustrated is normal. What you do next is what matters."), [
        ("Name it", "Putting a name on a feeling ('I'm frustrated') helps calm it. It moves you from reacting to noticing."),
        ("Change the body first", "Slow breathing — longer out than in — lowers your heart rate and steadies you within a minute. Relaxing your shoulders and hands helps too."),
        ("Choose the response", "Anger can become energy for the next play, or a foul that hurts your team. Nerves can become sharpness, or a frozen moment. A breath creates the gap where you choose."),
    ], example: "Kai, 17, a rugby player, used to argue with referees. He started using a long exhale and the word 'job' — his next task — whenever he felt it rising. His penalties dropped, and his coach trusted him with more minutes.",
                 ["Name the emotion.", "Breathe out longer than you breathe in.", "Create a gap, then choose your response."]),

    campusLesson("ps-bad-games", "After a poor performance", 4,
                 hook: ("Everyone has bad games", "Bad games are part of sport. Learning from them is a skill."), [
        ("First, recover", "Right after a bad game, emotions are high and judgement is poor. Eat, sleep, and give it a night before you analyse."),
        ("Then look honestly", "What went well? What went wrong that I can control — preparation, effort, decisions? What wasn't in my control? One or two lessons are enough."),
        ("Separate performance from worth", "A poor performance is something you did, not something you are. Your value as a person doesn't change with the scoreboard."),
        ("Turn it into a next step", "Pick one thing to work on in the next practice. That turns frustration into progress."),
    ], example: "Nina, 15, scored no points in a big basketball game. The next day she wrote one thing that went well (her defence), one lesson (she rushed her shots), and one plan (shooting at game speed in practice).",
                 ["Recover first, analyse the next day.", "Find one or two controllable lessons.", "A bad game is something you did, not who you are."]),

    campusLesson("ps-identity", "You're more than your sport", 4,
                 hook: ("Who are you when you're not playing?", "Sport can be a huge part of your life. It works best when it isn't the only part."), [
        ("Why it matters", "Athletes whose whole sense of self depends on sport tend to struggle more with injuries, bad seasons, being cut, or eventually stopping. Every athlete stops one day."),
        ("Build a wider base", "Friends outside your team, school subjects you enjoy, hobbies, family, things you care about. These make you more resilient — and often a calmer competitor."),
        ("When sport stops for a while", "Injury or illness can feel like losing yourself. Staying connected to the team, setting other goals and talking about how you feel all help. If it gets heavy, tell someone you trust."),
    ], example: "Leah, 16, missed a season with a knee injury. She stayed involved by filming practice for her coach, joined the school art club, and came back to soccer loving it more — with a life that didn't fall apart without it.",
                 ["Sport is part of who you are, not all of it.", "Friends, school and interests make you more resilient.", "If injury or a cut hits hard, talk to someone."]),
]

let psychologyQuestions: [String: [CampusQuestion]] = [
    "ps-focus": [
        .choice(prompt: "Which cue usually works better in a game?", options: ["'Bend your knees'", "'Drive the ground away'", "'Don't miss'"], answer: 1,
                explain: "An outside, outcome focus usually beats a body-part focus."),
    ],
    "ps-motivation": [
        .trueFalse(statement: "You should wait until you feel motivated before training.", answer: false, explain: "Action often comes first; motivation follows."),
    ],
    "ps-goals": [
        .match(prompt: "Match the goal to its type", pairs: [["Win the league", "Outcome"], ["Run 400 m in 60 s", "Performance"], ["Drive my arms", "Process"]]),
        .choice(prompt: "What should you think about during competition?", options: ["The final score", "Process goals", "What others think"], answer: 1, explain: "Process is what you control."),
    ],
    "ps-self-talk": [
        .choice(prompt: "Which is instructional self-talk?", options: ["'Keep going!'", "'Loose arm, high toss'", "'Don't mess up'"], answer: 1, explain: "It tells you what to do."),
    ],
    "ps-imagery": [
        .trueFalse(statement: "Imagery works best when you imagine the real place, real speed and real pressure.", answer: true,
                   explain: "Realistic imagery transfers better."),
    ],
    "ps-routines": [
        .choice(prompt: "A good pre-performance routine is…", options: ["Long and complicated", "Short, the same, practised", "Different every time"], answer: 1, explain: "Simple and automatic."),
    ],
    "ps-reset": [
        .fill(before: "Recognise, release,", after: ".", options: ["refocus", "replay", "regret"], answer: "refocus", explain: "Then onto the next play."),
    ],
    "ps-emotions": [
        .choice(prompt: "Which breathing calms you fastest?", options: ["Short, fast breaths", "Breathing out longer than in", "Holding your breath"], answer: 1,
                explain: "A long exhale slows the heart rate."),
    ],
    "ps-bad-games": [
        .trueFalse(statement: "The best time to analyse a bad game is right after the final whistle.", answer: false, explain: "Recover first; analyse the next day."),
    ],
    "ps-identity": [
        .trueFalse(statement: "Having friends and interests outside sport can make you a more resilient athlete.", answer: true,
                   explain: "A wider base helps with injuries, bad seasons and pressure."),
    ],
]
