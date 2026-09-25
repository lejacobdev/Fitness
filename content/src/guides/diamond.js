/** Sport guides: baseball and softball. See guides/index.js for the shape. */
export const DIAMOND = [
  {
    slug: 'baseball',
    headline: 'Baseball is short, explosive actions — throwing, swinging and sprinting — built on rotational power and a healthy arm.',
    demands: [
      { label: 'Action', value: 'Bursts of 1–5 seconds' },
      { label: 'Key qualities', value: 'Rotational power, arm health, first-step speed' },
      { label: 'Throwing', value: 'Pitchers: 70–100+ pitches per start' },
      { label: 'Contact', value: 'Minimal (collisions at bases)' },
    ],
    succeed: [
      { title: 'Power comes from the hips', body: 'Bat speed and throwing velocity start with the legs and hips rotating. Train rotational throws and lower-body power.' },
      { title: 'Protect the arm', body: 'Respect pitch counts and rest days. Pitching more than 100 innings in a year made serious injury 3.5 times more likely in a 10-year study.' },
      { title: 'Don\'t pitch year-round', body: 'Take at least 2–3 months a year off from competitive throwing, and never pitch with arm fatigue.' },
      { title: 'Short-sprint speed', body: 'Home to first is under 5 seconds. Acceleration training helps on the bases and in the field.' },
      { title: 'Plan every at-bat', body: 'Know the count, the pitcher\'s patterns and your approach before you step in.' },
    ],
    season: {
      off: 'Rest the arm first, then strength (legs, trunk, shoulder) and a gradual throwing programme.',
      pre: 'Build pitch and throw counts gradually; speed and power.',
      in: 'Short strength and arm-care sessions; follow pitch count rules.',
    },
    gym: {
      focus: ['Rotational power', 'Shoulder and elbow care', 'Lower-body strength', 'First-step speed'],
      exercises: ['med-ball-rotational-throw', 'band-external-rotation', 'trap-bar-deadlift', 'split-squat', 'prone-y-t-w-raise', 'acceleration-wall-drill'],
    },
    injuries: [
      { area: 'Elbow and shoulder', body: 'Overuse from throwing too much. Follow pitch counts, rest days and no pitching on consecutive days.', exercises: ['band-external-rotation', 'sleeper-stretch', 'prone-y-t-w-raise', 'serratus-wall-slide'] },
      { area: 'Hamstrings', body: 'Sprinting out of the box; keep eccentric hamstring strength up.', exercises: ['nordic-hamstring-curl', 'single-leg-rdl'] },
    ],
    positions: {
      pitcher: 'Arm care every day, pitch counts, and leg drive into a stable front side.',
      infield: 'Quick first step, soft hands and fast, accurate throws.',
      outfield: 'Reading the ball off the bat, top speed and a strong throwing arm.',
      catcher: 'Hip and knee mobility for the squat, a quick transfer and strong legs.',
    },
    mindset: ['Failure is part of hitting — even great hitters fail 7 times in 10. Judge the at-bat, not the result.', 'A pre-pitch routine brings you back to the present.'],
    fuel: 'Long days: pack snacks, drink regularly, and eat a proper meal after games.',
    sources: ['pitchers', 'pitchSmart', 'nordic'],
    quiz: [
      { type: 'trueFalse', statement: 'Pitching more than 100 innings a year made serious injury 3.5 times more likely.', answer: true, explain: 'Found in a 10-year study of young pitchers.' },
      { type: 'choice', prompt: 'Where does bat speed come from?', options: ['Legs and hips rotating', 'Only the wrists', 'Only the arms'], answer: 0, explain: 'Power starts from the ground.' },
      { type: 'choice', prompt: 'How long should young pitchers rest from competitive throwing each year?', options: ['At least 2–3 months', 'Never', 'One week'], answer: 0, explain: 'The arm needs time to recover.' },
      { type: 'trueFalse', statement: 'It\'s fine to pitch with a tired arm.', answer: false, explain: 'Pitching through fatigue is a major injury risk.' },
    ],
  },
  {
    slug: 'softball',
    headline: 'Softball is explosive and fast — a shorter field means quicker reactions, and power comes from the hips.',
    demands: [
      { label: 'Action', value: 'Bursts of 1–5 seconds' },
      { label: 'Key qualities', value: 'Rotational power, reaction, first-step speed' },
      { label: 'Pitching', value: 'Windmill — many pitches, several games a weekend' },
      { label: 'Contact', value: 'Minimal' },
    ],
    succeed: [
      { title: 'Rotational power', body: 'Hitting and throwing speed come from legs and hips. Med ball throws and strong legs pay off.' },
      { title: 'Pitchers need care too', body: 'Windmill pitching is less stressful on the elbow than overhand, but shoulder and back overuse is common. Track your pitches and rest.' },
      { title: 'React faster', body: 'The pitch arrives very fast from a short distance. Tracking drills and seeing lots of live pitching help.' },
      { title: 'Short sprint speed', body: 'Bases are 60 ft apart: acceleration wins infield hits and steals.' },
    ],
    season: {
      off: 'Strength and power, arm care, aerobic base.',
      pre: 'Build throwing and pitching volume gradually.',
      in: 'Short strength sessions and arm care between tournaments.',
    },
    gym: {
      focus: ['Rotational power', 'Shoulder care', 'Lower-body strength', 'Acceleration'],
      exercises: ['med-ball-rotational-throw', 'landmine-rotation', 'band-external-rotation', 'goblet-squat', 'hip-thrust', 'acceleration-wall-drill'],
    },
    injuries: [
      { area: 'Shoulder', body: 'Throwing and windmill pitching load the shoulder. Strengthen the cuff and shoulder blade.', exercises: ['band-external-rotation', 'prone-y-t-w-raise', 'face-pull'] },
      { area: 'Knees (ACL)', body: 'Girls\' sports carry higher ACL risk; landing and cutting training help.', exercises: ['drop-landing-stick', 'lateral-hop-to-stick', 'nordic-hamstring-curl'] },
    ],
    positions: {
      pitcher: 'Track pitch counts across a tournament weekend and keep the shoulder and back strong.',
      infield: 'Quick hands and feet, fast throws and reaction to hard-hit balls.',
      outfield: 'Reading the ball, top speed and accurate throws.',
    },
    mindset: ['Next pitch: let go of the last one.', 'Talk on defence — know the situation before every pitch.'],
    fuel: 'Tournament days: small, regular snacks and plenty of water in the heat.',
    sources: ['acl', 'heat'],
    quiz: [
      { type: 'choice', prompt: 'Where does throwing speed come from?', options: ['Legs and hips', 'Fingers only', 'Neck'], answer: 0, explain: 'Power starts from the ground.' },
      { type: 'trueFalse', statement: 'Windmill pitchers never need to rest.', answer: false, explain: 'Shoulder and back overuse are common; track pitches and rest.' },
      { type: 'choice', prompt: 'How far apart are softball bases?', options: ['60 feet', '90 feet', '120 feet'], answer: 0, explain: 'Short distances — acceleration matters.' },
      { type: 'trueFalse', statement: 'Landing and cutting training can lower ACL injuries in girls.', answer: true, explain: 'By about two-thirds for non-contact ACL tears.' },
    ],
  },
];
