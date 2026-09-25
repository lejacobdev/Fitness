import Foundation

/// Campus: short, evidence-based lessons for athletes, grouped into ten
/// topics. Written for teenagers — plain words, one idea per section, and
/// the few takeaways worth remembering. Never medical advice: anything
/// about pain or illness points to a coach, athletic trainer or doctor.
public struct CampusLesson: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let minutes: Int
    public let sections: [CampusSection]
    public let takeaways: [String]
}

public struct CampusSection: Hashable, Sendable {
    public let heading: String
    public let body: String
}

public struct CampusTopic: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let systemImage: String
    public let lessons: [CampusLesson]
}

private func lesson(_ id: String, _ title: String, _ minutes: Int, _ sections: [(String, String)], _ takeaways: [String]) -> CampusLesson {
    CampusLesson(id: id, title: title, minutes: minutes, sections: sections.map { CampusSection(heading: $0.0, body: $0.1) }, takeaways: takeaways)
}

public let campusTopics: [CampusTopic] = [
    CampusTopic(
        id: "training-science", title: "Training & exercise science",
        subtitle: "Strength, speed, endurance, mobility, recovery — and how your body adapts.",
        systemImage: "bolt.heart.fill",
        lessons: [
            lesson("adaptation", "How training makes you better", 3, [
                ("Stress, then recover", "A workout doesn't make you fitter on the spot — it tires you out. You get better in the hours and days after, while your body repairs and rebuilds a little stronger than before. Coaches call this adaptation. Train, recover, repeat: that loop is the whole game."),
                ("Progressive overload", "Your body only keeps adapting if the challenge slowly grows: a bit more weight, one more set, a slightly faster pace. Jumping up too fast is how athletes get hurt; never increasing means you stop improving. Small steps, week after week."),
                ("Specific beats random", "You get better at exactly what you train. Sprinters need short, fast efforts with full rest; distance runners need lots of easy aerobic miles. The best plans train the qualities your sport and position actually use."),
            ], ["Fitness is built during recovery, not during the workout.", "Increase load gradually — roughly one small step at a time.", "Train the qualities your sport really needs."]),
            lesson("qualities", "Strength, power, speed, endurance", 4, [
                ("Strength first", "Strength is how much force you can make. It underpins almost everything: sprinting, jumping, changing direction and resisting injury. For teenagers, supervised strength training with good technique is safe and effective — major sports-medicine bodies agree on this."),
                ("Power and speed", "Power is strength made fast: jumps, throws, sprints. It's trained with low reps done with full effort and full rest, while you're fresh — not at the end of a tiring session."),
                ("Endurance comes in two kinds", "Aerobic fitness lets you keep going and recover between efforts; it's built mostly with easy to moderate work. Anaerobic fitness handles repeated hard bursts. Most team sports need both."),
            ], ["Strength supports every other quality.", "Train power fresh, with full rest between reps.", "Most easy aerobic work should feel conversational."]),
            lesson("warm-up", "Warming up the right way", 3, [
                ("Raise, activate, mobilise, potentiate", "A good warm-up follows four steps: raise your heart rate and body temperature with light movement, activate key muscles (glutes, core, shoulders), move joints through their full range, then finish with a few fast, sport-like efforts."),
                ("Dynamic, not long static holds", "Before training, move through stretches (leg swings, lunges with a twist) rather than holding long static stretches — long holds right before sprinting or jumping can make you briefly slower. Save longer holds for after training or the evening."),
                ("It prevents injuries", "Structured warm-ups such as FIFA 11+ have been shown in studies to cut injuries in team-sport athletes substantially when done regularly."),
            ], ["Warm up for 10–15 minutes before every session.", "Move dynamically before; hold stretches after.", "End the warm-up with a few fast efforts."]),
        ]
    ),
    CampusTopic(
        id: "nutrition", title: "Nutrition & hydration",
        subtitle: "Fuel for performance — protein, carbs, fats, water and recovery. No extreme diets.",
        systemImage: "fork.knife",
        lessons: [
            lesson("fuel-basics", "The three macronutrients", 4, [
                ("Carbohydrates are your fuel", "Carbs — rice, pasta, bread, oats, potatoes, fruit — refill the energy stores your muscles use in hard training. On heavy training days you need more; on rest days, less. Cutting carbs as an athlete usually means slower, weaker sessions."),
                ("Protein builds and repairs", "Protein helps muscles repair and adapt. Athletes generally do well spreading protein across the day — something like 20–30 g per meal from eggs, dairy, meat, fish, beans or tofu — rather than one big serving."),
                ("Fats are not the enemy", "Healthy fats (nuts, olive oil, avocado, fish) support hormones and long-term health. They digest slowly, so keep big fatty meals away from the hour before training."),
            ], ["Carbs fuel hard training.", "Spread protein over 3–5 meals.", "Eat a real plate: carbs, protein, colour, some fat."]),
            lesson("hydration", "Hydration that actually works", 3, [
                ("Start hydrated", "Drink regularly through the day, and have a drink with your meal a few hours before training. Pale-yellow urine is a simple sign you're on track."),
                ("During and after", "In long or hot sessions, sip water every 15–20 minutes. For sessions over an hour, or heavy sweating, a sports drink or salty snack helps replace sodium. Afterwards, keep drinking and eat a meal with some salt."),
                ("More is not always better", "Forcing down huge amounts of plain water can be harmful. Drink to thirst plus a plan, and weigh yourself before and after a hard session once in a while to learn how much you sweat."),
            ], ["Pale-yellow urine = well hydrated.", "Long or hot sessions: add sodium.", "Don't force down excessive water."]),
            lesson("recovery-eating", "Eating around training", 3, [
                ("Before", "Eat a normal meal 2–4 hours before training, or a small carb snack (banana, toast, cereal bar) 30–60 minutes before if you're hungry."),
                ("After", "Within a couple of hours after training, have a meal or snack with both carbs and protein — for example yoghurt with fruit and granola, a sandwich, or rice with chicken. This starts the repair and refills your fuel."),
                ("Avoid extreme diets", "Crash diets, skipping meals and cutting whole food groups often lead to low energy, stalled growth, getting sick more and more injuries. If weight is a concern in your sport, talk to a doctor or sports dietitian — never guess alone."),
            ], ["Eat carbs + protein after training.", "Growing athletes need enough energy, every day.", "Weight goals: always with a professional."]),
        ]
    ),
    CampusTopic(
        id: "injury-anatomy", title: "Injury prevention & anatomy",
        subtitle: "Muscles, joints, technique, warm-ups — and when pain means stop and get checked.",
        systemImage: "cross.case.fill",
        lessons: [
            lesson("body-basics", "Your body in 3 minutes", 3, [
                ("Muscles pull, joints guide", "Muscles attach to bones through tendons and move you by pulling. Ligaments hold bones together at joints. Tendons and ligaments adapt more slowly than muscles, which is why big jumps in training load often hurt them first."),
                ("The big movers", "Glutes and hamstrings drive sprinting and jumping; quads absorb landings; calves and the Achilles tendon act like springs; the core transfers force between legs and arms; the shoulder's small rotator-cuff muscles keep throwing arms healthy."),
                ("Growth matters", "During growth spurts, bones can grow faster than muscles and tendons adapt, and growth plates are more vulnerable. Heel, knee and elbow pain in teenage athletes is common during these phases — don't ignore it."),
            ], ["Tendons adapt slower than muscles — build load gradually.", "Strong glutes, hamstrings and core protect you.", "Growth spurts are a time to be careful."]),
            lesson("pain", "When pain means stop", 3, [
                ("Soreness vs pain", "Muscle soreness a day or two after a hard session is normal: dull, spread out, and it eases as you warm up. Pain that is sharp, in one spot, in a joint or bone, or getting worse as you move is a warning."),
                ("Stop and get checked if…", "…you felt a pop or snap, a joint swells or gives way, you can't put weight on it, pain wakes you at night, you have numbness or tingling, or pain changes how you move. After any hit to the head, stop playing and get checked — never play through a possible concussion."),
                ("Tell someone early", "Report pain to your coach, athletic trainer or parent early. Small problems caught in week one are often a few days off; the same problem ignored for a month can end a season."),
            ], ["Sharp, local, worsening pain = stop.", "Head hit = stop and get checked, every time.", "Tell an adult early — it saves seasons."]),
            lesson("technique-load", "Technique and load protect you", 3, [
                ("Quality first", "Good technique spreads force across the right muscles and joints. Learn movements light, film yourself, and add load only when the movement looks the same every rep."),
                ("Watch sudden spikes", "Injuries often follow sudden jumps in training — a new sport, a double-session camp, the first week back after a break. Try not to increase your weekly training by a lot at once."),
                ("Prevention programmes work", "Short routines done 2–3 times a week — Nordic hamstring curls, Copenhagen side planks, landing drills, shoulder external-rotation work — reduce common injuries in many sports. Your plan includes the ones that matter for your sport."),
            ], ["Master light before going heavy.", "Avoid big weekly jumps in training.", "Do your prevention work — it's small and it works."]),
        ]
    ),
    CampusTopic(
        id: "sleep", title: "Sleep & recovery",
        subtitle: "Sleep quality, rest days, managing fatigue, avoiding overtraining.",
        systemImage: "bed.double.fill",
        lessons: [
            lesson("sleep-power", "Sleep is your best recovery tool", 3, [
                ("How much", "Teenagers are generally recommended 8–10 hours of sleep a night. Athletes who sleep less tend to react slower, make more mistakes, get sick more and get injured more."),
                ("Better sleep habits", "Keep the same bed and wake time most days, make the room dark and cool, and put screens away 30–60 minutes before bed. Avoid caffeine in the afternoon and evening."),
                ("Naps", "A short nap of 20–30 minutes in the early afternoon can help after a poor night — but it doesn't replace a full night's sleep."),
            ], ["Aim for 8–10 hours.", "Same schedule, dark cool room, screens away.", "Short early naps only."]),
            lesson("rest-days", "Rest days and deloads", 3, [
                ("Rest is part of training", "Muscles, tendons and your nervous system need time to rebuild. At least one full rest day a week, and lighter weeks every so often, let you come back stronger."),
                ("Active recovery", "Easy movement — a walk, light cycling, mobility — can help you feel fresher than doing nothing at all, as long as it stays truly easy."),
                ("Take breaks from your sport", "Having some time off from your main sport through the year, and not specialising too early, is linked to fewer overuse injuries and less burnout."),
            ], ["At least one full rest day each week.", "Easy means easy on recovery days.", "Plan breaks from your sport across the year."]),
            lesson("overtraining", "Spotting too much fatigue", 3, [
                ("Warning signs", "Performance dropping for weeks, always feeling heavy, poor sleep, low mood, getting sick often or losing motivation can mean you're doing too much or recovering too little."),
                ("What to do", "Tell your coach, pull back for a few days, sleep more and eat enough. Your morning check-in tracks sleep, soreness, energy and stress so the plan can ease off before you dig a hole."),
                ("Stress adds up", "Exams, family and friendships are stress too. Your body doesn't separate school stress from training stress — busy weeks may need lighter training."),
            ], ["Weeks of worse performance = warning sign.", "Check in every morning — it lets the plan adapt.", "Life stress counts as training stress."]),
        ]
    ),
    CampusTopic(
        id: "psychology", title: "Sports psychology",
        subtitle: "Confidence, focus, pressure, motivation, emotions, bouncing back.",
        systemImage: "brain.head.profile",
        lessons: [
            lesson("confidence", "Building real confidence", 3, [
                ("Confidence comes from evidence", "The strongest confidence comes from preparation you can point to: the reps you did, the sessions you finished. Keep track of what you've done — on a bad day it reminds you that you're ready."),
                ("Self-talk", "Talk to yourself like a good coach: short, specific and helpful. \"Drive the knee\" beats \"don't mess up\". Swap \"I can't\" for \"I'm learning to\"."),
                ("Control the controllables", "You can't control referees, weather or opponents. You can control effort, attitude, preparation and your next action. Put your energy there."),
            ], ["Confidence is built from preparation.", "Use short, helpful self-talk.", "Focus on what you control."]),
            lesson("pressure", "Handling pressure and nerves", 3, [
                ("Nerves are normal", "A faster heartbeat and butterflies are your body getting ready to perform. Many top athletes say \"I'm excited\" instead of \"I'm nervous\" — it's the same feeling pointed forward."),
                ("Breathe to reset", "Slow breathing — in for about four seconds, out for about six — calms the body in under a minute. Use it before a free throw, a serve or a start."),
                ("Routines", "A short pre-performance routine (same breath, same cue word, same movement) gives your mind something familiar to lock onto when the moment gets big."),
            ], ["Reframe nerves as readiness.", "Long exhales calm you down.", "Build a short routine and use it every time."]),
            lesson("mistakes", "Bouncing back after mistakes", 3, [
                ("Mistakes are data", "Every athlete makes mistakes. The difference is how fast you reset. Treat a mistake as information: what happened, what's the fix, next play."),
                ("A reset ritual", "Pick a physical reset — a clap, wiping your hands, touching your shoe — plus a word like \"next\". It tells your brain the last play is over."),
                ("After the game", "Reflect once, calmly: two things that went well, one thing to improve. Then let it go. Dwelling for days doesn't make you better — practice does."),
            ], ["Next play — reset fast.", "Use a physical reset ritual.", "Reflect once, then move on."]),
        ]
    ),
    CampusTopic(
        id: "technique", title: "Technique & biomechanics",
        subtitle: "How your body moves efficiently — and how small changes add up.",
        systemImage: "figure.run",
        lessons: [
            lesson("force", "Force, levers and the ground", 3, [
                ("Push the ground", "Nearly every sport movement starts by pushing into the ground. Sprinting fast is less about moving your legs quickly and more about hitting the ground hard, under your hips, in the right direction."),
                ("The kinetic chain", "Power flows from the ground through legs, hips and trunk into arms or a stick. Throws, swings and kicks are fastest when the hips turn before the shoulders and each segment passes speed to the next."),
                ("Stiff where it counts", "A strong, stable trunk lets force pass through instead of leaking away — that's why core work that resists movement (planks, anti-rotation) matters."),
            ], ["Push the ground hard, under your body.", "Hips lead, shoulders follow.", "A stable trunk transfers power."]),
            lesson("landing", "Landing and cutting safely", 3, [
                ("Land soft and stable", "Land on the balls of your feet, bend hips and knees together, and keep knees in line with your toes — not caving inward. Landing quietly is a good sign."),
                ("Cutting", "Lower your hips a few steps before a cut, plant with the foot slightly outside your body, and keep the knee over the foot. Many serious knee injuries happen in awkward, upright cuts and landings."),
                ("Train it", "Landing and cutting technique improves with practice — jump-and-stick drills, deceleration drills and single-leg strength are all in your plan for this reason."),
            ], ["Knees over toes, not caving in.", "Get low before you cut.", "Practise landings like a skill."]),
            lesson("feedback", "Getting better with feedback", 3, [
                ("Film yourself", "A phone video from the side or front shows things you can't feel. Compare slow-motion clips of your movement to good examples and to your coach's cues."),
                ("One cue at a time", "Change one thing at a time with one simple cue — \"tall hips\" or \"elbow high\". Too many cues at once makes movement stiff."),
                ("Slow to fast", "Learn a new technique slowly and light, then speed it up, then add pressure and fatigue. Skills that hold up under pressure are the ones that count."),
            ], ["Film, compare, adjust.", "One cue at a time.", "Slow and light, then fast, then under pressure."]),
        ]
    ),
    CampusTopic(
        id: "tactics", title: "Sport-specific tactics",
        subtitle: "Positioning, decisions, reading opponents, strategy and the rules.",
        systemImage: "rectangle.3.group.fill",
        lessons: [
            lesson("reading", "Reading the game", 3, [
                ("Scan before you receive", "Top players look around before the ball, puck or play arrives, so they already know their next move. Build the habit of a quick check over your shoulder."),
                ("Watch the hips, not the fakes", "An opponent's hips and centre of mass show where they're really going; heads, shoulders and the ball are where fakes happen."),
                ("Patterns repeat", "Teams and opponents repeat what works for them. Notice their favourite move, side or serve, and prepare for it."),
            ], ["Scan early and often.", "Read the hips.", "Spot the opponent's favourite pattern."]),
            lesson("positioning", "Positioning and decisions", 3, [
                ("Space and angles", "Good positioning is about angles: being where you can see both the play and your man, cutting off the easiest option, or giving a teammate a clear line to you."),
                ("Decide fast, simply", "Under pressure, the simple correct choice beats the spectacular risky one. Coaches often say \"make the easy play\" for a reason."),
                ("Learn the rules deeply", "Knowing the rules — offside, fouls, scoring edge cases — helps you use them and avoid giving easy points away. Read your sport's rulebook summary once a season."),
            ], ["Position for angles and vision.", "Choose the simple right play.", "Know the rules better than your opponent."]),
            lesson("game-plan", "Having a game plan", 3, [
                ("Before", "Know your role, your team's plan and one or two personal focus points. Keep it short enough to remember under pressure."),
                ("During", "Use breaks — timeouts, between points, halftime — to check: is the plan working? What's the opponent doing differently?"),
                ("After", "Watch film or talk with your coach about decisions, not just results. Good decisions that failed are still good decisions."),
            ], ["Two personal focus points per game.", "Adjust at every break.", "Judge decisions, not only outcomes."]),
        ]
    ),
    CampusTopic(
        id: "tracking", title: "Performance tracking",
        subtitle: "Which numbers matter — and how to use data without obsessing.",
        systemImage: "chart.xyaxis.line",
        lessons: [
            lesson("what-matters", "Numbers that actually matter", 3, [
                ("Track a few things well", "A handful of meaningful measures — a sprint time, a jump height, a key lift, how you feel each morning — beats tracking everything. Pick ones linked to your sport."),
                ("Trends, not single days", "One bad test day means little; sleep, stress and food all swing results. Look at the trend over weeks."),
                ("Training load", "How hard and how long you trained (effort × minutes) is one of the most useful numbers. Big sudden jumps are a warning sign; steady build-ups are good."),
            ], ["Pick 3–5 measures linked to your sport.", "Judge trends over weeks.", "Watch for sudden load spikes."]),
            lesson("check-ins", "Why the morning check-in matters", 3, [
                ("Your baseline", "Sleep, soreness, energy and stress mean most compared with your own normal. After a week or two of check-ins, the app knows your baseline and spots when you're off."),
                ("Consistency is the point", "Checking in every day — even on rest days — is what makes the numbers useful. It takes ten seconds."),
                ("It adapts your plan", "When your readiness is low the plan lightens the session; when you're fresh it keeps it as planned. You can always override it."),
            ], ["Check in every morning.", "Your normal is what counts.", "Low readiness lightens the plan."]),
            lesson("healthy-data", "Using data without obsessing", 3, [
                ("Data serves you", "Numbers are there to guide training, not to judge your worth. If tracking starts making you anxious, track less and talk to someone you trust."),
                ("Don't compare yourself constantly", "Other athletes grow, mature and develop at different times. Compare yourself with yourself from last season."),
                ("Feel still counts", "How you feel, how you move and what your coach sees are data too. Use numbers and feel together."),
            ], ["Numbers guide, they don't judge.", "Compare with your past self.", "Use numbers and feel together."]),
        ]
    ),
    CampusTopic(
        id: "teamwork", title: "Communication & teamwork",
        subtitle: "Coaches, teammates, leadership, feedback — and speaking up early.",
        systemImage: "person.3.fill",
        lessons: [
            lesson("coach", "Working with your coach", 3, [
                ("Ask good questions", "\"What's one thing I should work on?\" and \"What does good look like here?\" show you care and get you useful answers."),
                ("Speak up early", "Tell your coach early about pain, illness, exams, family stress or being tired. Coaches can adjust a plan they know about; they can't fix what they don't know."),
                ("Take feedback well", "Listen fully, say thanks, ask one clarifying question if needed, then try it. Feedback is about your play, not about you as a person."),
            ], ["Ask for one thing to work on.", "Tell your coach problems early.", "Listen, thank, try."]),
            lesson("teammates", "Being a great teammate", 3, [
                ("Communicate on the field", "Short, loud, specific calls — \"man on\", \"switch\", \"mine\" — prevent mistakes. Silence is the most common communication error in team sports."),
                ("Energy is contagious", "Encouragement after a mistake and effort when tired lift everyone around you. Negativity spreads just as fast."),
                ("Respect everyone", "Respect teammates of every level, officials and opponents. Teams that trust each other perform better under pressure."),
            ], ["Short, loud, specific calls.", "Lift teammates after mistakes.", "Respect builds trust."]),
            lesson("leadership", "Leadership without a title", 3, [
                ("Lead by example", "Showing up on time, finishing every rep and doing the boring work well are leadership. You don't need to be captain."),
                ("Include people", "Notice who's quiet or new and include them. Strong teams are built by people who make others feel part of it."),
                ("Handle conflict early", "If something bothers you, talk to the person privately and calmly, early. Small issues grow when they're ignored."),
            ], ["Leadership is behaviour, not a title.", "Include the quiet and the new.", "Solve conflict early and privately."]),
        ]
    ),
    CampusTopic(
        id: "long-term", title: "Long-term athlete development",
        subtitle: "Progress takes years — avoid peaking too early and balance sport, school and life.",
        systemImage: "chart.line.uptrend.xyaxis",
        lessons: [
            lesson("years", "Progress takes years", 3, [
                ("A long game", "Most athletes reach their best in their twenties. What you build now — movement skills, strength, a healthy relationship with training — sets you up for later."),
                ("Late bloomers win too", "Athletes who mature later are often overlooked at 14 and outstanding at 20. Early results are a poor predictor of adult success."),
                ("Don't chase peaks", "Trying to be at your absolute peak every week as a teenager leads to burnout and injury. Build steadily and let performances come."),
            ], ["Your best years are likely ahead.", "Early results don't decide your future.", "Build steadily; don't force peaks."]),
            lesson("specialise", "Specialising too early", 3, [
                ("Play more than one sport", "Young athletes who play several sports tend to have fewer overuse injuries and less burnout, and many elite athletes specialised relatively late."),
                ("A simple guide", "Sports-medicine groups suggest young athletes avoid training their main sport year-round without breaks and keep weekly training hours roughly in line with their age."),
                ("Keep it fun", "Enjoyment is one of the strongest reasons athletes keep playing. Protect it."),
            ], ["Multiple sports build better athletes.", "Take breaks from your main sport.", "Protect the fun."]),
            lesson("balance", "Balancing sport, school and life", 3, [
                ("Plan your week", "Put training, games, school and exams in one plan. Heavy exam weeks can be lighter training weeks — tell the app with the day status and tell your coach."),
                ("Life outside sport", "Friends, family, hobbies and rest make you a healthier person and, over time, a better athlete. Your identity is more than your sport."),
                ("Ask for help", "If sport starts to feel like pressure you can't handle, talk to a parent, coach, school counsellor or someone you trust."),
            ], ["One plan for sport and school.", "You are more than your sport.", "Talk to someone when it gets heavy."]),
        ]
    ),
]
