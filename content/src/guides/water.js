/** Sport guides: swimming & diving, water polo, rowing. See guides/index.js for the shape. */
export const WATER = [
  {
    slug: 'swimming-diving',
    headline: 'Swimming is technique first — the most efficient stroke wins — and the shoulder is the joint to look after.',
    demands: [
      { label: 'Training volume', value: 'High: often thousands of metres per session' },
      { label: 'Strokes', value: 'Thousands of shoulder rotations a week' },
      { label: 'Races', value: '20 seconds to 15+ minutes' },
      { label: 'Diving', value: 'Take-off power, air awareness, core control' },
    ],
    succeed: [
      { title: 'Technique beats effort', body: 'A long, efficient stroke with good body position saves energy. Drills matter as much as distance.' },
      { title: 'Starts, turns and underwaters', body: 'In short-course races, a big part of the time is off the walls. Train starts, turns and streamlines.' },
      { title: 'Dryland strength', body: 'Strength and power out of the water improve starts and turns and protect the shoulder.' },
      { title: 'Watch the volume', body: 'Shoulder pain in swimmers tracks how much you swim. Build up gradually and cut back when it hurts.' },
    ],
    season: {
      off: 'Short break, then aerobic base, technique and dryland strength.',
      pre: 'Volume builds; race-pace work begins.',
      in: 'Race-pace sets, dryland maintained, taper before championships.',
    },
    gym: {
      focus: ['Shoulder (rotator cuff and shoulder blade)', 'Core and streamline', 'Leg power for starts and turns', 'Thoracic mobility'],
      exercises: ['band-external-rotation', 'prone-y-t-w-raise', 'serratus-wall-slide', 'hollow-hold', 'box-jump', 'thoracic-open-book'],
    },
    injuries: [
      { area: 'Shoulder', body: 'Swimmer\'s shoulder is mostly a tendon overuse problem linked to volume. Strengthen the cuff and shoulder blade, and manage yardage.', exercises: ['band-external-rotation', 'prone-y-t-w-raise', 'scapular-wall-slide', 'serratus-wall-slide'] },
      { area: 'Knees (breaststroke)', body: 'The whip kick stresses the inside of the knee. Hip strength and a gradual build-up of breaststroke kick help.', exercises: ['lateral-band-walk', 'adductor-squeeze'] },
      { area: 'Lower back (butterfly and diving)', body: 'Arching and landing load the back; core control protects it.', exercises: ['dead-bug', 'bird-dog', 'hollow-hold'] },
    ],
    positions: {
      sprinter: 'Power, starts and turns, and race-pace speed.',
      distance: 'A big aerobic base, pacing and an efficient stroke.',
      diver: 'Take-off power, body control in the air and a tight entry.',
    },
    mindset: ['Break long sets into pieces: one length at a time.', 'Race day: stick to your warm-up routine and focus on your lane.'],
    fuel: 'Early practices: eat something small before. Big training days need big meals; bring a snack for after.',
    sources: ['swimShoulder', 'reds', 'sleep'],
    quiz: [
      { type: 'trueFalse', statement: 'Shoulder pain in swimmers is linked to how much they swim.', answer: true, explain: 'It tracked hours and distance swum.' },
      { type: 'choice', prompt: 'What matters as much as distance swum?', options: ['Technique drills', 'Swimsuit colour', 'Pool temperature'], answer: 0, explain: 'Efficient technique saves energy.' },
      { type: 'choice', prompt: 'Which kick can stress the inside of the knee?', options: ['Breaststroke', 'Flutter', 'Dolphin'], answer: 0, explain: 'The whip kick loads the knee ligament.' },
      { type: 'trueFalse', statement: 'Dryland training is useless for swimmers.', answer: false, explain: 'It improves starts, turns and shoulder health.' },
    ],
  },
  {
    slug: 'water-polo',
    headline: 'Water polo combines swimming speed, treading water and throwing with contact — a strong shoulder and legs that never stop.',
    demands: [
      { label: 'Game', value: '4 quarters of 7–8 minutes' },
      { label: 'Movement', value: 'Sprint swimming and constant eggbeater' },
      { label: 'Throwing', value: 'Overhead shots and passes' },
      { label: 'Contact', value: 'Constant wrestling for position' },
    ],
    succeed: [
      { title: 'Eggbeater legs', body: 'A strong eggbeater keeps you high in the water for shots, blocks and passes. Hip and leg strength help.' },
      { title: 'Sprint swimming', body: 'Counterattacks are won by the fastest swimmers — head-up freestyle speed.' },
      { title: 'Shoulder care', body: 'Throwing plus swimming means a lot of shoulder load. Cuff and shoulder blade training every week.' },
      { title: 'Strength for position', body: 'Holding position against a defender needs full-body strength.' },
    ],
    season: {
      off: 'Strength, swimming base and shoulder programme.',
      pre: 'Sprint swimming, leg endurance, shooting volume builds gradually.',
      in: 'Short strength sessions and shoulder care.',
    },
    gym: {
      focus: ['Shoulder care', 'Hip and leg strength (eggbeater)', 'Rotational power', 'Upper-body pull'],
      exercises: ['band-external-rotation', 'face-pull', 'goblet-squat', 'adductor-squeeze', 'med-ball-rotational-throw', 'pull-up'],
    },
    injuries: [
      { area: 'Shoulder', body: 'Overuse from swimming and throwing. Strengthen and manage shooting volume.', exercises: ['band-external-rotation', 'prone-y-t-w-raise', 'serratus-wall-slide'] },
      { area: 'Hips and knees', body: 'The eggbeater loads the inside of the knee and hips.', exercises: ['adductor-squeeze', 'lateral-band-walk'] },
      { area: 'Head and face', body: 'Contact means knocks; wear your cap with ear guards.', exercises: [] },
    ],
    positions: {},
    mindset: ['Play the next possession — defence starts the moment you lose the ball.', 'Stay calm when physical: composure wins exclusions.'],
    fuel: 'You sweat in the pool too: drink at breaks and eat enough for two-a-days.',
    sources: ['swimShoulder', 'concussion'],
    quiz: [
      { type: 'choice', prompt: 'What keeps a water polo player high in the water?', options: ['Eggbeater kick', 'Flutter kick', 'Standing on the bottom'], answer: 0, explain: 'A strong eggbeater supports shots and blocks.' },
      { type: 'trueFalse', statement: 'Water polo puts a lot of load on the shoulder.', answer: true, explain: 'Swimming plus throwing.' },
      { type: 'choice', prompt: 'Who wins counterattacks?', options: ['The fastest swimmers', 'The tallest players', 'The goalie'], answer: 0, explain: 'Head-up sprint speed.' },
      { type: 'trueFalse', statement: 'You don\'t sweat when training in water.', answer: false, explain: 'You do — drink at breaks.' },
    ],
  },
  {
    slug: 'rowing',
    headline: 'Rowing is a full-body endurance sport where power comes from the legs — and the back needs to be looked after.',
    demands: [
      { label: 'Race', value: '2000 m (about 6–8 minutes)' },
      { label: 'Energy', value: 'Mostly aerobic, with a big power demand' },
      { label: 'Stroke', value: 'Legs, then back, then arms' },
      { label: 'Training', value: 'High volume on water and ergometer' },
    ],
    succeed: [
      { title: 'Legs, back, arms', body: 'Most power comes from the leg drive. Squats and deadlifts build it; good sequencing uses it.' },
      { title: 'Aerobic base', body: 'Lots of steady rowing builds the engine for 2000 m. Hard pieces are a small part of the week.' },
      { title: 'Protect the back', body: 'Low back pain is the most common rowing problem. Learn good technique, manage volume, and keep hips mobile.' },
      { title: 'Crew rhythm', body: 'Boat speed comes from rowing together. Timing matters as much as power.' },
    ],
    season: {
      off: 'Erg and cross-training base; strength phase.',
      pre: 'Water volume, technique and pieces.',
      in: 'Race preparation, strength maintained, taper for regattas.',
    },
    gym: {
      focus: ['Leg drive (squat, deadlift)', 'Back endurance', 'Hip mobility', 'Upper-back pull'],
      exercises: ['barbell-back-squat', 'romanian-deadlift', 'barbell-bent-over-row', 'back-extension', 'side-plank', '90-90-hip-switch'],
    },
    injuries: [
      { area: 'Lower back', body: 'Technique education and training load management matter most. When it hurts, reduce load early and keep moving with exercise.', exercises: ['bird-dog', 'side-plank', 'back-extension', 'cat-camel'] },
      { area: 'Ribs', body: 'Rib stress injuries come from big jumps in volume. Build up gradually.', exercises: ['serratus-wall-slide'] },
      { area: 'Wrists and forearms', body: 'Feathering and grip: relax your hands on the handle.', exercises: ['band-wrist-extension'] },
    ],
    positions: {},
    mindset: ['In the third 500 m, focus on the next stroke, not the finish line.', 'Trust your crew — rowing is the ultimate team sport.'],
    fuel: 'High volume needs lots of energy: carbohydrate around sessions, protein every meal. Avoid crash dieting for weight classes.',
    sources: ['rowingBack', 'reds', 'youthStrength'],
    quiz: [
      { type: 'choice', prompt: 'Where does most rowing power come from?', options: ['Legs', 'Arms', 'Wrists'], answer: 0, explain: 'Legs, then back, then arms.' },
      { type: 'trueFalse', statement: 'Low back pain is the most common rowing problem.', answer: true, explain: 'Technique and load management help prevent it.' },
      { type: 'choice', prompt: 'What causes rib stress injuries?', options: ['Big jumps in training volume', 'Too much sleep', 'Warm-ups'], answer: 0, explain: 'Build up gradually.' },
      { type: 'trueFalse', statement: 'Most rowing training should be all-out pieces.', answer: false, explain: 'Steady rowing builds the aerobic base.' },
    ],
  },
];
