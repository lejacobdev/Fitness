import Foundation

// Supplements & performance (docs/VERSION-6.md §13). Education only:
// "understand this", never "take this". No products, no doses for teens.

let supplementLessons: [CampusLesson] = [
    campusLesson("su-what", "What supplements are — and aren't", 4,
                 hook: ("A pill can't do what a season can", "Supplements are everywhere in sport. Before anything else, it helps to know what they actually are."), [
        ("What counts as a supplement", "A supplement is a product taken on top of normal food: powders, pills, drinks, gummies. In many countries, including the US, supplements don't need to be proven safe or effective before they're sold. The maker is responsible, and problems are often found only after people have used them."),
        ("Why athletes use them", "Some athletes want convenience (a shake after practice), some want to fix a real deficiency a doctor found, and many simply copy what they see older athletes or influencers doing. Wanting an edge is normal. The question is whether a product actually gives one — and at what risk."),
        ("What they can't replace", "No supplement replaces sleep, enough food, consistent training and recovery. Those four make the biggest difference by far. If they aren't in place, a supplement is fixing the wrong thing."),
        ("Talk to someone first", "For anyone under 18, any supplement is a conversation with a parent or guardian first, and ideally a doctor, sports dietitian or athletic trainer — especially if you take medication, have a health condition, or compete in a drug-tested sport."),
    ], example: "Ava, 16, asked her athletic trainer about a powder her teammates were using. They looked at her week together: she was skipping breakfast and sleeping six hours. Fixing those two did more for her energy than any product could.",
                 ["Supplements don't have to be proven safe or effective before they're sold.", "Sleep, food, training and recovery come first — always.", "Under 18: talk to a parent or guardian and a professional before taking anything."]),

    campusLesson("su-food-first", "Food first", 3,
                 hook: ("Food already is the supplement", "Almost everything a supplement promises, a normal meal already delivers — plus a lot more."), [
        ("Food comes as a package", "Milk gives protein, carbohydrate, calcium and fluid at once. Fruit gives carbohydrate, water, fibre and vitamins. A supplement usually isolates one thing and leaves the rest behind."),
        ("When a supplement can make sense", "A doctor may prescribe a vitamin D or iron supplement after a blood test shows a deficiency. That's treatment for a measured problem — very different from taking something because a label says 'performance'."),
        ("Convenience isn't magic", "A shake after practice can be handy when you can't eat soon. It isn't better than food; it's just quicker. A sandwich and a glass of milk do the same job."),
    ], example: "Leo, 15, thought he needed a protein powder to recover. His sports dietitian showed him that chocolate milk and a turkey sandwich after practice covered it — for less money and with more nutrients.",
                 ["Real food gives many nutrients together.", "Supplements fix measured problems, ideally with a doctor.", "Quick isn't the same as better."]),

    campusLesson("su-evidence", "What 'evidence' really means", 4,
                 hook: ("'Clinically proven' — proven how?", "Marketing loves the word 'evidence'. Here's how to tell strong evidence from a sales pitch."), [
        ("Who was studied", "Many supplement studies use adult men, often already trained. Results in 25-year-old lifters don't automatically apply to a 15-year-old whose body is still growing. Research on teenagers is much thinner."),
        ("How it was studied", "Stronger evidence comes from many studies that compare a product with a fake (a placebo) without the athletes knowing which they got, and that find the same result again and again. One small study, or a study paid for by the company selling the product, is weak evidence."),
        ("What was measured", "'Improved performance' might mean a slightly better lab test, not a faster sprint in a game. A tiny lab difference can be real and still not matter on the field."),
        ("Absence of harm isn't proof of safety", "Short studies can miss problems that show up over years, or in younger people, or with contaminated products. 'No side effects found' only means none were found in that study."),
    ], example: "Maya, 17, saw an ad saying a product 'boosted power 20%'. She looked closer: one study, ten adult men, paid for by the brand, measured on a bike in a lab. Not much to build a decision on.",
                 ["Ask who was studied — adults aren't teenagers.", "Many independent, placebo-controlled studies beat one sponsored study.", "A lab result isn't the same as better play."]),

    campusLesson("su-risks", "Contamination and banned substances", 4,
                 hook: ("What's in the tub isn't always what's on the label", "Testing has found supplements containing ingredients they don't list — including substances banned in sport."), [
        ("Contamination happens", "Because supplements aren't checked before they're sold, some contain extra ingredients, too much of an ingredient, or stimulants and steroid-like substances that aren't on the label. This has been found repeatedly by researchers and anti-doping labs."),
        ("Strict liability", "In drug-tested sport — many college and international competitions, and some high-school programmes — the athlete is responsible for anything found in their body. 'It was in my supplement' isn't accepted as an excuse."),
        ("Third-party certification", "Some independent programmes test batches of products for banned substances and award a certification mark. It lowers the risk; it doesn't remove it, and it says nothing about whether the product works or whether you need it."),
        ("The safest choice", "The lowest-risk supplement is the one you don't need. If you and your family decide to use one, a certified product chosen with a professional is far safer than something bought because of an ad."),
    ], example: "A college swimmer missed a season after a positive test traced to a contaminated pre-workout powder. She had never meant to cheat — but under the rules she was still responsible.",
                 ["Labels aren't guarantees.", "In tested sport, you're responsible for what's in your body.", "Certification lowers risk; it doesn't prove a product works."]),

    campusLesson("su-marketing", "How supplements are sold to you", 3,
                 hook: ("Built to make you want it", "Supplement marketing is very good at one thing: making you feel you're missing out."), [
        ("The usual tricks", "Before-and-after photos, athletes paid to post, words like 'clinically proven', 'pharmaceutical grade' or 'anabolic', countdown discounts, and secret 'proprietary blends' that hide how much of each ingredient is inside."),
        ("Why it works on athletes", "Athletes are motivated, competitive and willing to work hard — exactly the people most likely to believe that one product is the missing piece."),
        ("Questions to ask", "Who is selling it, and do they earn money if I buy it? What evidence, in people like me? What could go wrong? What would happen if I spent the same money on food and the same energy on sleep?"),
    ], example: "Jordan, 16, followed an influencer whose 'stack' cost more each month than his football fees. When he checked, the influencer earned a commission on every sale through his link.",
                 ["Ask who profits from your purchase.", "Hidden 'proprietary blends' are a warning sign.", "Your money and effort often go further in food and sleep."]),

    campusLesson("su-protein", "Protein powder", 4,
                 hook: ("The most common supplement in the locker room", "Protein powder is everywhere. Here's what it is, and what it isn't."), [
        ("What it is", "Protein extracted from milk (whey, casein), eggs or plants, dried into a powder. It's a food product in a convenient form."),
        ("Why athletes talk about it", "Muscles use protein to repair and adapt after training, so a shake looks like an easy way to 'recover'."),
        ("What research looks at", "Studies mostly compare total daily protein intake, and how it's spread across meals, on muscle repair and strength gains in trained adults. The overall finding: total protein from the whole day matters much more than whether it came from a shake."),
        ("Limits and risks", "Most teenage athletes who eat regular meals already get enough protein. Powders can be contaminated like any supplement, may contain added stimulants or sweeteners, and can replace meals that would have given far more nutrients."),
        ("Who should be cautious", "Anyone with a milk or other allergy, kidney problems, or who uses shakes instead of meals. In drug-tested sport, only certified products."),
        ("What matters more", "Protein at every meal from real food — eggs, dairy, meat, fish, beans, tofu — plus enough total food to grow and train."),
    ], example: "Sam, 15, was drinking two shakes a day but skipping lunch. When he ate lunch again and kept one glass of milk after practice, he felt better in afternoon practice and saved money.",
                 ["Total protein from the day matters more than shakes.", "Most teen athletes can meet their needs from food.", "A shake is convenience, not magic."]),

    campusLesson("su-creatine", "Creatine", 5,
                 hook: ("The most researched supplement — mostly in adults", "Creatine has more research behind it than almost any other supplement. That's exactly why the details matter."), [
        ("What it is", "Creatine is made by your body and found in meat and fish. Muscles use it to refuel their fastest energy system — the one for short, all-out efforts like a sprint or a heavy lift."),
        ("Why athletes talk about it", "Studies in adults show it can help with repeated short, hard efforts and with strength gains during training. Because the evidence is strong in adults, it's often marketed as safe and effective for everyone."),
        ("Limits", "Most research is in adults. There's far less research in people under 18, and long-term effects on growing bodies are not well studied. The benefit is for short, repeated high-intensity work — not endurance, not skill."),
        ("Risks and who should be cautious", "Common effects include weight gain from water held in muscle and stomach upset. Products can be contaminated. Major paediatric and sports-medicine organisations advise teenagers not to use performance-enhancing supplements, creatine included. Anyone with kidney problems or on medication must speak with a doctor."),
        ("Marketing claims to question", "'Builds muscle fast', 'cuts recovery time in half', 'natural steroid'. Creatine doesn't build muscle by itself — training does."),
        ("What matters more", "For a teenager: consistent strength training, enough food and protein, and sleep. These give far bigger gains, and you're still growing into your strength."),
    ], example: "Ethan, 17, asked his coach about creatine. His coach showed him his training log: two missed gym days a week and six hours of sleep. Fixing consistency added more to his squat in two months than any supplement study reports.",
                 ["Strong evidence in adults isn't evidence for teenagers.", "Paediatric experts advise teens against performance-enhancing supplements.", "Training, food and sleep give the biggest gains while you're growing."]),

    campusLesson("su-caffeine", "Caffeine and energy drinks", 4,
                 hook: ("A drug you can buy at every gas station", "Caffeine is so normal it's easy to forget it's a stimulant drug."), [
        ("What it is", "A stimulant found in coffee, tea, cola, energy drinks, many pre-workouts and some 'focus' gummies. It makes you feel more alert and can make hard effort feel a little easier."),
        ("What research looks at", "Studies in adults show caffeine can improve some endurance and high-intensity performance. Teenagers react to caffeine more strongly per kilogram of body weight, and research in young athletes is limited."),
        ("Risks", "Poor sleep (caffeine stays in your body for many hours), a racing heart, anxiety, upset stomach, and headaches when you stop. Energy drinks can contain a lot of caffeine plus other stimulants, and mixing several sources adds up fast."),
        ("Who should be cautious", "Paediatric organisations advise children and teenagers to avoid energy drinks and limit caffeine. Anyone with a heart condition, anxiety or trouble sleeping should avoid it — and talk to a doctor."),
        ("What matters more", "If you feel you need caffeine to get through practice, that's information: you probably need more sleep, more food, or less stress. Fix the cause, not the symptom."),
    ], example: "Chloe, 16, drank an energy drink before evening practices. She trained fine but lay awake until 1 a.m. and felt flat the next day. Swapping it for a snack and water fixed both.",
                 ["Caffeine is a stimulant, and teens are more sensitive to it.", "It can wreck sleep — the best recovery tool you have.", "Needing it to train is a sign to fix sleep and food."]),

    campusLesson("su-sports-drinks", "Sports drinks and electrolytes", 4,
                 hook: ("Useful sometimes — not every time", "Sports drinks help in some situations and add nothing but sugar in others."), [
        ("What they are", "Sports drinks are water with carbohydrate (sugar) and electrolytes, mostly sodium. Electrolyte products (tablets, powders) usually have salts with little or no sugar."),
        ("When they're useful", "Long sessions (roughly over an hour of hard work), very hot conditions, tournaments with several games a day, or heavy, salty sweaters. Then the carbs keep energy up and the sodium helps replace what's lost."),
        ("When water is enough", "Most practices under an hour, in normal weather. Then water during, and a normal meal or snack after, cover everything."),
        ("Risks and limits", "Sipping sugary drinks all day is hard on teeth and adds a lot of sugar. Drinking far more than you sweat, especially plain water in very long events, can also cause problems — drink to a plan, not to excess."),
        ("What matters more", "Arriving hydrated, drinking regularly during long or hot sessions, and eating salty, carbohydrate-rich food afterwards."),
    ], example: "Noah, 15, played three soccer games in one hot tournament day. Water plus a sports drink between games and salty snacks kept him going; on normal practice days he sticks to water.",
                 ["Long, hot or multi-game days: sports drinks can help.", "Short, normal practices: water is enough.", "Food after training replaces most of what you lose."]),

    campusLesson("su-vitamins", "Vitamins and minerals", 4,
                 hook: ("More isn't better", "If a little is good, a lot must be better? With vitamins and minerals, that's often wrong."), [
        ("What they are", "Small nutrients your body needs to work: vitamins (like C and D) and minerals (like iron and calcium). A varied diet provides almost all of them."),
        ("Why athletes talk about them", "Low iron can make you tired and slow, and low vitamin D is common where there's little winter sun. So athletes hear that supplements fix fatigue."),
        ("What research looks at", "Correcting a real deficiency, found with a blood test, helps. Taking extra when levels are already normal generally doesn't improve performance."),
        ("Risks", "Some vitamins (like A and D) and minerals (like iron) build up in the body and can cause harm in large amounts. Iron supplements without a measured need are a common example of something that should be a doctor's decision."),
        ("Who should be cautious", "Anyone thinking about iron, high-dose vitamins or 'megadoses'. Constant tiredness deserves a doctor's visit, not a guess — especially for female athletes and anyone eating very little."),
        ("What matters more", "Colourful, varied meals, enough total food, and a doctor's check if you're always tired."),
    ], example: "Grace, 16, a distance runner, felt exhausted for weeks. Her doctor found low iron with a blood test and treated it. Her teammate, with normal levels, took the same pills 'just in case' — and only got stomach aches.",
                 ["Varied food covers most needs.", "Deficiencies are found with a blood test, then treated.", "Large doses can harm — always a doctor's decision."]),

    campusLesson("su-preworkout", "Pre-workout products", 4,
                 hook: ("A stimulant cocktail in a tub", "Pre-workouts promise energy, focus and 'pumps'. Here's what's usually inside."), [
        ("What they are", "Powders or drinks taken before training, usually mixing caffeine (often a lot) with other stimulants and ingredients — sometimes in 'proprietary blends' that hide amounts."),
        ("Why athletes talk about them", "They make you feel wired and ready, and they're heavily promoted on social media."),
        ("What research looks at", "Most of the felt effect comes from caffeine. Research on the full blends is limited, often short, often industry-funded, and done in adults."),
        ("Risks", "Racing heart, anxiety, poor sleep, upset stomach, and contamination. Some products have contained banned or unsafe stimulants. Combining a pre-workout with energy drinks or coffee stacks the caffeine."),
        ("Who should be cautious", "These products aren't designed for teenagers, and paediatric guidance is to avoid them. Anyone with a heart condition, anxiety or sleep trouble, and anyone in drug-tested sport, should stay away."),
        ("What matters more", "A snack and water an hour before training, a proper warm-up, and enough sleep the night before give you real energy without the crash."),
    ], example: "Ryan, 17, felt shaky and his heart pounded during a lift after a pre-workout a friend gave him. He stopped the set, told his coach, and now warms up properly and eats a banana before training instead.",
                 ["Pre-workouts are mainly stimulants.", "They aren't designed for teenagers.", "A snack, a warm-up and sleep are the real pre-workout."]),
]

let supplementQuestions: [String: [CampusQuestion]] = [
    "su-what": [
        .trueFalse(statement: "In many countries, supplements must be proven safe and effective before they can be sold.", answer: false,
                   explain: "They usually don't — the maker is responsible, and problems often show up after people use them."),
        .choice(prompt: "What makes the biggest difference to performance?", options: ["The right supplement", "Sleep, food, training and recovery", "Taking several supplements together"], answer: 1,
                explain: "No product replaces the basics."),
    ],
    "su-food-first": [
        .choice(prompt: "When does a vitamin or mineral supplement clearly make sense?", options: ["When a label says 'performance'", "When a blood test shows a deficiency", "Before every game"], answer: 1,
                explain: "Treating a measured problem with a doctor is different from taking something just in case."),
        .trueFalse(statement: "A shake after practice is better than a normal meal.", answer: false, explain: "It's quicker, not better."),
    ],
    "su-evidence": [
        .choice(prompt: "Which is the strongest evidence?", options: ["One study paid for by the brand", "Many independent studies with a placebo", "An athlete's video review"], answer: 1,
                explain: "Repeated, independent, placebo-controlled results are hardest to fool."),
        .trueFalse(statement: "A result found in adult men applies the same way to a 15-year-old.", answer: false, explain: "Teenagers are still growing; research on them is thinner."),
    ],
    "su-risks": [
        .trueFalse(statement: "In drug-tested sport, 'it was in my supplement' is accepted as an excuse.", answer: false,
                   explain: "Athletes are responsible for anything found in their body."),
        .choice(prompt: "What does a third-party certification mark tell you?", options: ["The product works", "The batch was tested for banned substances", "You need the product"], answer: 1,
                explain: "It lowers contamination risk — nothing more."),
    ],
    "su-marketing": [
        .choice(prompt: "Which is a warning sign on a label?", options: ["A full ingredient list with amounts", "A hidden 'proprietary blend'", "A batch number"], answer: 1,
                explain: "Blends hide how much of each ingredient is inside."),
    ],
    "su-protein": [
        .trueFalse(statement: "Total protein across the whole day matters more than whether it came from a shake.", answer: true,
                   explain: "Shakes are just one convenient source."),
        .choice(prompt: "What's the best first step for more protein?", options: ["Two shakes a day", "Protein at every meal from food", "Skipping carbs"], answer: 1,
                explain: "Eggs, dairy, meat, fish, beans or tofu at each meal."),
    ],
    "su-creatine": [
        .choice(prompt: "Where is most creatine research done?", options: ["In teenagers", "In adults", "In children"], answer: 1,
                explain: "Far less is known about under-18s."),
        .trueFalse(statement: "Creatine builds muscle by itself, without training.", answer: false, explain: "Training builds muscle; creatine can only support certain kinds of work."),
    ],
    "su-caffeine": [
        .trueFalse(statement: "Teenagers react to caffeine more strongly per kilogram of body weight than adults.", answer: true,
                   explain: "Which is one reason paediatric guidance is cautious."),
        .choice(prompt: "Needing caffeine to get through practice usually means…", options: ["You need a stronger drink", "You need more sleep, food or less stress", "It's working"], answer: 1,
                explain: "Fix the cause, not the symptom."),
    ],
    "su-sports-drinks": [
        .choice(prompt: "When can a sports drink help?", options: ["A 40-minute practice in mild weather", "A hot tournament with three games", "Sitting in class"], answer: 1,
                explain: "Long, hot or multi-game days."),
    ],
    "su-vitamins": [
        .trueFalse(statement: "If vitamins are good, large doses are better.", answer: false, explain: "Some build up in the body and cause harm."),
    ],
    "su-preworkout": [
        .choice(prompt: "Most of a pre-workout's felt effect usually comes from…", options: ["Vitamins", "Caffeine and other stimulants", "Protein"], answer: 1,
                explain: "Which is why they can wreck sleep and race your heart."),
    ],
]
