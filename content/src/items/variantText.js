/**
 * Setup and execution for variants whose equipment or side changes how the
 * movement is set up — the generated variant otherwise repeats its base
 * item's text ("stand inside the trap bar" on the band version). Keyed by
 * variant slug; only the fields given replace the base's.
 */
export const VARIANT_TEXT = {
  'trap-bar-deadlift-dumbbell': {
    setup: ['Stand with feet hip-width, a dumbbell on the floor just outside each foot.'],
    execution: ['Hinge at the hips and bend the knees to grip the dumbbells, chest up, back flat.', 'Drive through the floor to stand tall, hips and knees finishing together.', 'Lower the dumbbells under control by reversing the motion.'],
  },
  'trap-bar-deadlift-band': {
    setup: ['Stand on the middle of a long band, feet hip-width, one end in each hand.'],
    execution: ['Hinge at the hips and bend the knees until the hands reach the shins, chest up, back flat.', 'Drive through the floor to stand tall against the band, hips and knees finishing together.', 'Lower under control by reversing the motion.'],
  },
  'trap-bar-deadlift-bodyweight': {
    setup: ['Stand tall, feet shoulder-width, toes slightly out, arms by your sides.'],
    execution: ['Sit the hips back and down, reaching the arms forward for balance, until the thighs are about parallel.', 'Drive up through the whole foot to stand tall.'],
  },
  'trap-bar-deadlift-unilateral': {
    setup: ['Stand inside the trap bar on one leg, a handle in each hand, slight bend in the standing knee.'],
    execution: ['Hinge at the hip, lowering the bar while the free leg extends straight behind you.', 'Stop when the torso is about parallel to the floor, then drive back to standing.', 'Finish the set, then switch legs.'],
  },
  'goblet-squat-band': {
    setup: ['Stand on the middle of a band, feet shoulder-width; hold both ends at the front of the shoulders.'],
    execution: ['Squat down, chest up, until the thighs are at least parallel.', 'Drive back up against the band through the whole foot.'],
  },
  'goblet-squat-bodyweight': {
    setup: ['Stand tall, feet shoulder-width, toes slightly out, arms by your sides.'],
    execution: ['Sit down between the heels, reaching the arms forward for balance, chest up.', 'Drive back up through the whole foot.'],
  },
  'goblet-squat-unilateral': {
    setup: ['Split stance, one foot a long step behind the other, a dumbbell held vertically at the chest.'],
    execution: ['Lower straight down until the back knee nearly touches the floor.', 'Drive up through the front foot; finish the set, then switch legs.'],
  },
  'bench-press-dumbbell': {
    setup: ['Lie on a flat bench with a dumbbell in each hand over the chest, feet flat on the floor.'],
    execution: ['Lower the dumbbells to the sides of the chest, elbows about 45 degrees from the body.', 'Press back up to straight arms.'],
  },
  'bench-press-band': {
    setup: ['Lie on your back on the floor, knees bent, a band across the upper back with one end in each hand.'],
    execution: ['Press the hands straight up until the arms are extended.', 'Lower under control until the upper arms touch the floor.'],
  },
  'bench-press-bodyweight': {
    setup: ['Hands on the floor slightly wider than the shoulders, body straight from head to heels.'],
    execution: ['Lower the chest to just above the floor, elbows about 45 degrees from the body.', 'Press back up to straight arms.'],
  },
  'bench-press-unilateral': {
    equipment: ['dumbbell', 'bench'],
    setup: ['Lie on a flat bench, feet flat, one dumbbell held over the chest; rest the free hand on your body.'],
    execution: ['Lower the dumbbell to the side of the chest without letting the body twist.', 'Press back up to a straight arm; finish the set, then switch arms.'],
  },
  'dumbbell-bench-press-unilateral': {
    setup: ['Lie on a flat bench, feet flat, one dumbbell held over the chest; rest the free hand on your body.'],
    execution: ['Lower the dumbbell to the side of the chest without letting the body twist.', 'Press back up to a straight arm; finish the set, then switch arms.'],
  },
  'barbell-front-squat-dumbbell': {
    setup: ['Hold a dumbbell at each shoulder, elbows high, feet shoulder-width.'],
    execution: ['Sit straight down between your heels, keeping the elbows high and the chest tall.', 'Drive up through the whole foot to standing.'],
  },
  'barbell-front-squat-bodyweight': {
    setup: ['Stand tall, feet shoulder-width, toes slightly out, arms by your sides.'],
    execution: ['Sit straight down between your heels, reaching the arms forward, chest tall.', 'Drive up through the whole foot to standing.'],
  },
  'romanian-deadlift-dumbbell': {
    setup: ['Stand tall holding a dumbbell in each hand in front of the thighs, soft knees.'],
    execution: ['Push the hips back and slide the dumbbells down the thighs until you feel a strong hamstring stretch.', 'Drive the hips forward to stand tall again.'],
  },
  'romanian-deadlift-band': {
    setup: ['Stand on the middle of a band, feet hip-width, one end in each hand at the hips, soft knees.'],
    execution: ['Push the hips back, hands sliding down the thighs, until you feel a strong hamstring stretch.', 'Drive the hips forward to stand tall against the band.'],
  },
  'romanian-deadlift-unilateral': {
    setup: ['Stand on one leg holding the bar at the hips, slight bend in the standing knee.'],
    execution: ['Hinge at the hip, sliding the bar down the standing leg while the free leg extends straight behind you.', 'Stop at a strong hamstring stretch, then drive back to standing; finish the set, then switch legs.'],
  },
  'hip-thrust-band': {
    setup: ['Upper back against a bench, feet flat, a band across the hips held down by your hands (or anchored at the floor).'],
    execution: ['Drive through the heels and lift the hips until the body is flat from shoulders to knees.', 'Squeeze the glutes for a second at the top and lower under control.'],
  },
  'hip-thrust-bodyweight': {
    setup: ['Lie on your back, knees bent, feet flat on the floor, arms by your sides.'],
    execution: ['Drive through the heels and lift the hips until the body is straight from shoulders to knees.', 'Squeeze the glutes for a second at the top and lower under control.'],
  },
  'hip-thrust-unilateral': {
    setup: ['Upper back against a bench, bar over the hips (use a pad), one foot flat, the other knee drawn up.'],
    execution: ['Drive through the planted heel and lift the hips until the body is flat from shoulders to knee.', 'Keep the hips level, squeeze at the top and lower under control; finish the set, then switch legs.'],
  },
  'step-up-bodyweight': {
    setup: ['A box about knee height; stand facing it, arms by your sides.'],
  },
  'reverse-lunge-bodyweight': {
    setup: ['Stand tall, feet hip-width, arms by your sides.'],
  },
  'dumbbell-bench-press-band': {
    setup: ['Lie on your back on the floor, knees bent, a band across the upper back with one end in each hand.'],
    execution: ['Press the hands straight up until the arms are extended.', 'Lower under control until the upper arms touch the floor.'],
  },
  'dumbbell-bench-press-bodyweight': {
    setup: ['Hands on the floor slightly wider than the shoulders, body straight from head to heels.'],
    execution: ['Lower the chest to just above the floor, elbows about 45 degrees from the body.', 'Press back up to straight arms.'],
  },
  'overhead-press-dumbbell-band': {
    setup: ['Stand on the middle of a band, feet hip-width, one end in each hand at the shoulders.'],
    execution: ['Press the hands straight up until the arms are locked out beside the ears.', 'Lower under control back to the shoulders.'],
  },
  'overhead-press-dumbbell-unilateral': {
    setup: ['Stand tall, one dumbbell at the shoulder, the free hand on the hip.'],
    execution: ['Press the dumbbell straight up until the arm is locked out beside the ear, without leaning away.', 'Lower under control; finish the set, then switch arms.'],
  },
  'dumbbell-row-band': {
    setup: ['Anchor a band at chest height; stand facing it in a slight hinge, the ends in your hands.'],
    execution: ['Row the hands to the ribs, driving the elbows back.', 'Return until the arms are straight and repeat.'],
  },
  'lat-pulldown-band': {
    setup: ['Loop a band over a pull-up bar; sit or kneel under it holding the ends, arms straight overhead.'],
    execution: ['Pull the hands to the top of the chest, driving the elbows down and back.', 'Let them rise slowly until the arms are straight.'],
  },
  'seated-cable-row-band': {
    setup: ['Sit tall facing a band anchored at chest height, knees slightly bent, an end in each hand.'],
    execution: ['Row the hands to the lower ribs, squeezing the shoulder blades together.', 'Return until the arms are straight without rounding forward.'],
  },
  'face-pull-band': {
    setup: ['Anchor a band at head height; hold each end with thumbs pointing back.'],
  },
  'dumbbell-curl-band': {
    setup: ['Stand on the middle of a band, feet hip-width, an end in each hand, palms forward.'],
    execution: ['Curl the hands up without moving the elbows forward.', 'Lower slowly to straight arms.'],
  },
  'triceps-extension-band-band': {
    setup: ['Face a band anchored high, an end in each hand, elbows pinned to the ribs.'],
    execution: ['Press the hands down until the arms are straight.', 'Let them rise back to 90 degrees under control.'],
  },
  'suitcase-carry-dumbbell': {
    setup: ['Hold one heavy dumbbell at your side.'],
  },
  'half-kneeling-chop-band': {
    setup: ['Half-kneel side-on to a band anchored low, inside knee down, both hands on the band.'],
    execution: ['Pull the band from low across the body to above the far shoulder, keeping the hips still.', 'Return slowly.'],
  },
  'push-press-dumbbell': {
    setup: ['Stand tall, a dumbbell at each shoulder, feet hip-width.'],
    execution: ['Dip a few centimetres with the knees, then drive up and press the dumbbells overhead in one move.', 'Lower to the shoulders under control.'],
  },
  'reverse-fly-dumbbell-band': {
    setup: ['Stand on the middle of a band and hinge forward with a flat back, an end in each hand below the chest.'],
    execution: ['Raise the hands out to the sides with a slight bend in the elbows.', 'Lower slowly.'],
  },
  'countermovement-jump-unilateral': {
    setup: ['Stand tall on one leg, the other knee slightly bent and the foot off the floor.'],
    execution: ['Dip quickly to about a quarter squat on the standing leg, arms swinging back.', 'Reverse immediately and jump as high as possible, swinging the arms up.', 'Land softly on the same leg with a bent knee; finish the set, then switch legs.'],
  },
  'standing-calf-raise-unilateral': {
    setup: ['Ball of one foot on a step edge, the other foot tucked up behind, holding a rail for balance.'],
  },
  'hamstring-slider-curl-unilateral': {
    setup: ['Lie on your back, one heel on a slider or towel, the other leg raised straight.'],
  },
  'leg-curl-machine-unilateral': {
    setup: ['Lie face down on the machine, the pad just above one heel; the other leg rests straight.'],
  },
};
