/** Sport guides: ice hockey, skiing, snowboarding. See guides/index.js for the shape. */
export const SNOW_ICE = [
  {
    slug: 'ice-hockey',
    headline: 'Hockey is short, explosive shifts on skates — powerful strides, strong hips and groins, and fast hands.',
    demands: [
      { label: 'Shift length', value: '30–60 seconds, then 2–4 minutes rest' },
      { label: 'Key qualities', value: 'Skating power, repeated sprints, body contact' },
      { label: 'Movement', value: 'Lateral push-off from bent hips and knees' },
      { label: 'Contact', value: 'Checking (age-dependent), boards, sticks, puck' },
    ],
    succeed: [
      { title: 'Stride power', body: 'Skating speed comes from pushing sideways and back from a deep knee bend. Single-leg and lateral strength build it.' },
      { title: 'Short, hard shifts', body: 'Conditioning should match shifts: 30–60 second efforts with rest, not long jogs.' },
      { title: 'Strong groins', body: 'Adductor strains are common in hockey. A pre-season adductor programme cut them from 3.2 to 0.7 per 1000 game exposures in pro players.' },
      { title: 'Puck skills', body: 'Stickhandling and shooting at home (off-ice) add thousands of reps.' },
      { title: 'Head up', body: 'Keep your head up along the boards; checking from behind is the most dangerous hit.' },
    ],
    season: {
      off: 'Strength (single-leg, lateral), power, aerobic base; rest from skating for a few weeks.',
      pre: 'Skating power, shift conditioning, adductor programme.',
      in: 'Two short strength sessions; groin and hip care.',
    },
    gym: {
      focus: ['Lateral power', 'Single-leg strength', 'Adductor strength', 'Hip mobility', 'Neck strength'],
      exercises: ['lateral-bound', 'skater-hops', 'bulgarian-split-squat', 'copenhagen-plank', 'adductor-squeeze', 'neck-isometrics'],
    },
    injuries: [
      { area: 'Groin and hips', body: 'Skating loads the adductors. Strengthen them before and during the season.', exercises: ['copenhagen-plank', 'adductor-squeeze', 'lateral-lunge', '90-90-hip-switch'] },
      { area: 'Head (concussion)', body: 'Head up, no hits from behind, and out the same day if in doubt.', exercises: ['neck-isometrics', 'band-neck-extension'] },
      { area: 'Shoulders', body: 'Boards and falls: strengthen the cuff and upper back.', exercises: ['band-external-rotation', 'face-pull'] },
    ],
    positions: {
      goaltender: 'Hip mobility, lateral push power and reaction speed; protect the hips from overuse.',
      defence: 'Backwards skating, pivots, strong in front of the net and a hard first pass.',
      forward: 'Explosive first strides, puck protection and quick release.',
    },
    mindset: ['Every shift is a fresh start — reset on the bench.', 'Compete for pucks: effort is a skill.'],
    fuel: 'A carb-rich meal before games, fluids during intermissions — you sweat a lot under the gear.',
    sources: ['hockeyAdductor', 'concussion', 'copenhagen'],
    quiz: [
      { type: 'trueFalse', statement: 'A pre-season adductor programme cut groin strains in hockey players.', answer: true, explain: 'From 3.2 to 0.7 per 1000 game exposures.' },
      { type: 'choice', prompt: 'How long is a typical hockey shift?', options: ['30–60 seconds', '5 minutes', '15 minutes'], answer: 0, explain: 'Short, hard efforts with rest.' },
      { type: 'choice', prompt: 'Which direction does a skating stride push?', options: ['Sideways and back', 'Straight down', 'Forward'], answer: 0, explain: 'Lateral strength builds stride power.' },
      { type: 'trueFalse', statement: 'Long slow jogs are the best hockey conditioning.', answer: false, explain: 'Match the shift: short, hard efforts.' },
    ],
  },
  {
    slug: 'skiing',
    headline: 'Ski racing is strength and control at speed: strong legs hold the edge, and a strong core keeps you balanced.',
    demands: [
      { label: 'Run length', value: '40 seconds to 2+ minutes' },
      { label: 'Forces', value: 'Several times bodyweight through the legs in turns' },
      { label: 'Key qualities', value: 'Leg strength (holding positions), balance, reaction' },
      { label: 'Environment', value: 'Cold, altitude, changing snow' },
    ],
    succeed: [
      { title: 'Strong legs', body: 'Squats, split squats and wall-sits build the strength to hold a low, powerful position through turns.' },
      { title: 'Balance and reaction', body: 'Single-leg balance, agility and reaction drills help you recover when the ski slips.' },
      { title: 'Protect the knees', body: 'ACL injuries are the most serious skiing injury. Strong hamstrings, good landings and properly set bindings help.' },
      { title: 'Wear a helmet', body: 'Helmets lowered head injuries by about a third in skiers and snowboarders, without raising neck injuries.' },
    ],
    season: {
      off: 'Summer: strength, power and aerobic base; mountain biking and agility work.',
      pre: 'Autumn: dryland intensity rises, first on-snow camps.',
      in: 'Short strength sessions to keep leg strength through a long season.',
    },
    gym: {
      focus: ['Leg strength (squat, split squat, isometrics)', 'Hamstrings (ACL protection)', 'Balance', 'Core'],
      exercises: ['barbell-back-squat', 'wall-sit', 'bulgarian-split-squat', 'nordic-hamstring-curl', 'single-leg-balance-reach', 'lateral-bound'],
    },
    injuries: [
      { area: 'Knees (ACL)', body: 'Falls backwards and landing jumps. Strong hamstrings, good technique and correct binding settings.', exercises: ['nordic-hamstring-curl', 'drop-landing-stick', 'single-leg-rdl'] },
      { area: 'Head', body: 'Helmets reduce head injuries. Always wear one.', exercises: [] },
      { area: 'Thumb and shoulder', body: 'Falls with the pole in hand. Let go of the pole when you fall.', exercises: ['band-external-rotation'] },
    ],
    positions: {},
    mindset: ['Inspect the course, then trust it: visualise the run before you go.', 'Commit to the line — hesitation costs more than a mistake.'],
    fuel: 'Cold burns energy: eat breakfast, carry snacks, drink even when you\'re not thirsty.',
    sources: ['helmets', 'acl'],
    quiz: [
      { type: 'trueFalse', statement: 'Helmets lower head injuries in skiers without raising neck injuries.', answer: true, explain: 'A meta-analysis found about a third fewer head injuries.' },
      { type: 'choice', prompt: 'Which is the most serious common skiing knee injury?', options: ['ACL tear', 'Bruised shin', 'Blister'], answer: 0, explain: 'Strong hamstrings and correct bindings help.' },
      { type: 'choice', prompt: 'Which exercise builds strength for holding a low position?', options: ['Wall-sit', 'Bicep curl', 'Neck roll'], answer: 0, explain: 'Isometric leg strength holds the turn.' },
      { type: 'trueFalse', statement: 'You should hold onto your pole when you fall.', answer: false, explain: 'Let go to protect your thumb.' },
    ],
  },
  {
    slug: 'snowboarding',
    headline: 'Snowboarding asks for balance, leg strength and body control — and smart protection, because falls are part of it.',
    demands: [
      { label: 'Stance', value: 'Sideways, both feet fixed on one board' },
      { label: 'Key qualities', value: 'Balance, leg strength, rotation, air awareness' },
      { label: 'Falls', value: 'Frequent, especially for beginners' },
      { label: 'Environment', value: 'Cold, altitude, park features' },
    ],
    succeed: [
      { title: 'Balance and edge control', body: 'Single-leg balance, squats and rotation training help you hold an edge and absorb bumps.' },
      { title: 'Learn to fall', body: 'Falling with fists closed and arms tucked, rolling instead of reaching, protects the wrists.' },
      { title: 'Wear wrist guards', body: 'In a study of 5,000 riders, wrist guards cut wrist injuries from 29 to 8 — beginners benefited most.' },
      { title: 'Progress step by step in the park', body: 'Master small jumps before big ones. Air awareness can be trained on a trampoline with a coach.' },
    ],
    season: {
      off: 'Strength, balance, trampoline and skateboard for air awareness.',
      pre: 'Leg endurance and power; first days on snow.',
      in: 'Short strength sessions; keep up wrist and knee protection.',
    },
    gym: {
      focus: ['Leg strength and endurance', 'Balance', 'Rotational control', 'Landing mechanics'],
      exercises: ['goblet-squat', 'wall-sit', 'single-leg-balance-reach', 'drop-landing-stick', 'landmine-rotation', 'box-jump'],
    },
    injuries: [
      { area: 'Wrists', body: 'The most common snowboard injury, from falling onto an outstretched hand. Wear wrist guards and learn to fall.', exercises: ['band-wrist-extension', 'wrist-roller'] },
      { area: 'Head', body: 'Helmets reduce head injuries — always wear one, especially in the park.', exercises: [] },
      { area: 'Knees and ankles', body: 'Landing jumps; strong legs and good landings help.', exercises: ['drop-landing-stick', 'single-leg-balance-reach', 'eccentric-step-down'] },
    ],
    positions: {
      freestyle: 'Air awareness, landings, spins and rail balance; progress features gradually.',
      alpine: 'Edge hold and leg strength through carved gates at speed.',
      boardercross: 'Starts, pumping through rollers, racing lines with other riders.',
    },
    mindset: ['Progress one step at a time; confidence comes from mastering the small stuff.', 'Visualise the trick before you drop in.'],
    fuel: 'Cold days burn energy: breakfast, snacks in your jacket, water at lunch.',
    sources: ['snowboardWrist', 'helmets'],
    quiz: [
      { type: 'trueFalse', statement: 'Wrist guards lowered wrist injuries in snowboarders.', answer: true, explain: 'From 29 to 8 in a study of 5,000 riders.' },
      { type: 'choice', prompt: 'Who benefits most from wrist guards?', options: ['Beginners', 'Only pros', 'Nobody'], answer: 0, explain: 'Beginners fall most.' },
      { type: 'choice', prompt: 'How should you fall?', options: ['Fists closed, roll', 'Arms straight out', 'Head first'], answer: 0, explain: 'Reaching with open hands hurts wrists.' },
      { type: 'trueFalse', statement: 'You should try the biggest jump in the park first.', answer: false, explain: 'Master small features first.' },
    ],
  },
];
