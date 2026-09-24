/**
 * Drills whose text has another person in them → the version of their
 * movement that shows that person (poses/partners.js). Applied last, so it
 * overrides the solo pattern the item had before.
 */
export const PARTNER_POSES = {
  // Racket sports
  'tennis-crosscourt-forehand-rally': 'tennis-forehand-rally', 'tennis-crosscourt-forehand-rally-moving': 'tennis-forehand-rally',
  'tennis-wide-ball-recovery': 'tennis-forehand-rally', 'tennis-backhand-down-the-line': 'tennis-backhand-fed',
  'tennis-overhead-smash-feed': 'tennis-overhead-fed', 'tennis-serve-and-first-ball': 'tennis-serve-returned',
  'racquetball-reaction-rebounds': 'low-forehand-fed', 'racquetball-serve-and-return-drill': 'low-forehand-fed', 'squash-boast-drive-pattern': 'low-forehand-fed',
  'table-tennis-falkenberg-footwork': 'tt-forehand-loop-fed', 'table-tennis-forehand-loop-multiball': 'tt-forehand-loop-fed',
  'table-tennis-random-placement-rally': 'tt-forehand-loop-fed', 'table-tennis-backhand-flick-drill': 'tt-backhand-flick-fed',
  'pickleball-crosscourt-dink-rally': 'pickleball-dink-rally', 'pickleball-third-shot-drop-reps': 'pickleball-dink-rally',
  'pickleball-hands-battle-volleys': 'volley-rally', 'squash-volley-drop-nicks': 'volley-rally',
  'tennis-split-step-reaction': 'split-step-signal', 'tennis-return-of-serve-reads': 'split-step-return', 'pickleball-split-step-kitchen-rush': 'split-step-pickleball',
  'badminton-clear-drop-rally': 'badminton-clear-rally', 'badminton-jump-smash-feeds': 'badminton-smash-fed',
  'badminton-net-kill-and-spin': 'racket-net-lunge-fed', 'badminton-deception-hold-and-flick': 'racket-net-lunge-fed', 'badminton-six-corner-footwork': 'racket-net-lunge-called',
  'squash-lunge-drop-recovery': 'squash-lunge-drop-fed', 'squash-ghosting-six-corners': 'squash-lunge-drop-called', 'racquetball-ceiling-ball-rally': 'racquetball-ceiling-ball',
  'flag-football-hesitation-burst': 'ball-carry-run-opposed', 'flag-football-route-tree-sprints': 'cut-45-catch',
  'volleyball-wall-setting': 'vb-set-wall', 'pickleball-reaction-wall-volleys': 'volley-wall', 'table-tennis-reaction-ball-catches': 'wall-ball-catch',
  'stir-the-pot': 'stir-the-pot', 'sailing-balance-catch': 'balance-catch-foam', 'single-leg-rdl': 'single-leg-rdl-bodyweight',
  // Volleyball and roundnet
  'boys-volleyball-high-ball-swing': 'vb-spike-set', 'boys-volleyball-quick-attack-timing': 'vb-spike-set',
  'volleyball-box-set-attack': 'vb-spike-set', 'volleyball-transition-approach': 'vb-spike-set',
  'volleyball-pepper-control': 'vb-forearm-pass-served', 'volleyball-serve-receive-platform': 'vb-forearm-pass-served', 'volleyball-serve-receive-platform-moving': 'vb-forearm-pass-served',
  'volleyball-defensive-shuffle-dig': 'vb-shuffle-dig-fed', 'sand-volleyball-two-person-coverage': 'vb-shuffle-dig-pair',
  'sand-volleyball-dive-and-recover': 'vb-dive-fed', 'sand-volleyball-sand-sprint-chase': 'vb-dive-fed', 'volleyball-read-block-timing': 'vb-block-read',
  'sitting-volleyball-seated-spike-reach': 'sit-vb-spike-set', 'sitting-volleyball-seated-dig-reaction': 'sit-vb-dig-fed', 'sitting-volleyball-seated-trunk-rotations': 'sit-vb-rotation-partner',
  'spikeball-defense-dig-bursts': 'roundnet-set-fed', 'spikeball-reaction-returns': 'roundnet-set-fed', 'spikeball-set-touch-control': 'roundnet-set-fed',
  'spikeball-hit-power-downballs': 'roundnet-hit-set', 'spikeball-serve-placement': 'roundnet-serve-received', 'spikeball-lateral-dive-and-pop': 'roundnet-dive-fed',
  'spikeball-roundnet-footwork': 'lateral-shuffle-mirror',
  // Soccer
  'soccer-one-touch-finishing': 'soccer-instep-kick-fed', 'soccer-one-touch-finishing-one-touch': 'soccer-instep-kick-fed',
  'soccer-driven-pass-gates': 'soccer-static-strike-partner', 'soccer-driven-pass-gates-one-touch': 'soccer-static-strike-partner',
  'soccer-target-corner-shooting': 'soccer-side-foot-pass-keeper', 'soccer-heading-toss-and-attack': 'soccer-header-tossed',
  'soccer-one-v-one-channel': 'soccer-dribble-1v1', 'soccer-first-touch-wall-rebounds': 'soccer-first-touch-wall', 'soccer-first-touch-wall-rebounds-moving': 'soccer-first-touch-wall',
  // Bat and ball, throwing
  'baseball-infield-first-step-reaction': 'field-grounder-fed', 'baseball-infield-first-step-reaction-moving': 'field-grounder-fed', 'softball-infield-reaction-grounders': 'field-grounder-fed',
  'baseball-front-toss-hitting': 'baseball-swing-front-toss', 'beep-baseball-pitcher-batter-timing': 'baseball-swing-pitched', 'beep-baseball-blindfolded-tee-swings': 'baseball-swing-coached',
  'baseball-long-toss-progression': 'long-toss-partner', 'softball-outfield-crow-hop-throws': 'crow-hop-throw-partner', 'softball-windmill-k-drill': 'softball-windmill-catcher',
  'beep-baseball-sound-location-pointing': 'point-and-track-rolled', 'beep-baseball-coached-dive-on-mats': 'side-dive-coached', 'beep-baseball-side-fall-progression': 'side-fall-partner',
  'beep-baseball-med-ball-rotational-throw': 'rotational-throw-wall-coached', 'goalball-med-ball-rotational-throws': 'rotational-throw-wall-coached',
  // Football, rugby
  'football-open-field-tackle': 'football-tackle-shield', 'rugby-tackle-technique-shield': 'football-tackle-shield', 'football-hand-fighting-shield': 'hand-strike-shield',
  'rugby-ruck-clear-drive': 'ruck-drive', 'flag-football-one-hand-catch-series': 'catch-high-thrown', 'football-catching-in-traffic': 'catch-high-traffic',
  'flag-football-quick-release-accuracy': 'qb-drop-throw-receiver', 'football-qb-drop-and-throw': 'qb-drop-throw-receiver', 'football-ball-security-gauntlet': 'ball-carry-gauntlet',
  'rugby-pass-down-the-line': 'rugby-pass-receiver', 'rugby-spin-pass-to-target': 'rugby-pass-receiver',
  'flag-football-flag-pull-mirror': 'lateral-shuffle-mirror', 'reactive-mirror-drill': 'lateral-shuffle-mirror', 'flag-football-flag-defense-angle-pursuit': 'sprint-pursuit',
  // Court sports
  'unified-basketball-layup-lines': 'bb-layup-fed', 'unified-basketball-pass-and-cut': 'bb-layup-fed',
  'unified-basketball-relay-dribble-conditioning': 'bb-dribble-relay', 'unified-basketball-mixed-pair-scrimmage-conditioning': 'bb-dribble-2v2',
  'team-handball-one-v-one-defending-box': 'bb-defensive-slide-attacker', 'unified-basketball-defense-spacing-game': 'bb-defensive-slide-dribbler',
  'unified-basketball-partner-form-shooting': 'bb-set-shot-rebounder', 'netball-rebound-jumps': 'bb-rebound-thrown', 'basketball-first-step-attack': 'bb-first-step-defender',
  'netball-chest-pass-accuracy': 'bb-chest-pass-partner', 'netball-drive-and-land': 'netball-drive-catch-fed', 'netball-three-foot-defending': 'netball-defend-thrower',
  'netball-dodge-and-lead': 'cut-45-feeder', 'team-handball-passing-on-the-run': 'overarm-pass-receiver', 'team-handball-jump-shot': 'handball-jump-shot-keeper',
  'team-handball-feint-and-break': 'handball-feint-defender', 'team-handball-fast-break-sprints': 'sprint-from-keeper',
  // Stick sports, goalball
  'ice-hockey-quick-release-snap-shots': 'hockey-snap-shot-fed', 'ice-hockey-quick-release-snap-shots-one-touch': 'hockey-snap-shot-fed',
  'ice-hockey-one-timer-reps': 'hockey-slap-shot-fed', 'adapted-floor-hockey-target-shooting': 'hockey-wrist-shot-partner',
  'adapted-floor-hockey-position-zones': 'hockey-walk-to-position-called', 'ice-hockey-board-battle-body-position': 'hockey-board-battle-pair',
  'ice-hockey-goaltender-t-push-tracking': 'goalie-t-push-shooter', 'field-hockey-goalkeeping-get-up-drill': 'fh-gk-block-get-up-shooter',
  'field-hockey-goalkeeping-angle-positioning-walk': 'fh-gk-angle-walk-shooter', 'lacrosse-ground-ball-scoop-and-go': 'lax-ground-ball-fed',
  'goalball-sound-tracking-reps': 'goalball-sound-tracking-partner', 'goalball-lateral-coverage-slides': 'goalball-slide-partner',
  // Running, jumping, conditioning
  'beep-baseball-buzzer-base-sprint': 'sprint-to-base', 'beep-baseball-guided-acceleration-starts': 'acceleration-start-guided', 'resisted-band-sprint': 'acceleration-start-band',
  'sprint-from-push-up-start': 'burpee-called', 'unified-track-hop-and-stick': 'single-leg-hop-stick-spotted',
  'competitive-spirit-toe-touch-jump-drill': 'toe-touch-jump-pair', 'cheerleading-sideline-herkie-drill': 'herkie-drill-pair', 'competitive-spirit-motion-sharpness': 'cheer-motions-pair',
  'adapted-swimming-rhythmic-breathing': 'swim-rhythmic-breathing-supported', 'skiing-foam-balance-reaches': 'star-excursion-foam-spotted',
  // Held, spotted, coached
  'nordic-hamstring-curl': 'nordic-curl-partner', 'nordic-assisted-band': 'nordic-curl-partner-band', 'lacrosse-box-defensive-stick-positioning': 'lax-defend-carrier', 'sailing-hiking-bench-holds': 'sail-hiking-partner',
  'sailing-tack-crossover-drill': 'sail-tack-crew', 'boccia-seated-band-rows': 'seated-band-row-partner', 'rifle-wall-dot-hold': 'rifle-wall-dot-partner',
  'equestrian-no-stirrups-work': 'ride-no-stirrups-coached', 'bowling-arrow-targeting': 'bowling-approach-watched', 'bowling-speed-control-targets': 'bowling-approach-watched',
  'bowling-follow-through-freeze': 'bowling-follow-through-watched', 'archery-blank-bale-shooting': 'archery-shot-coached', 'archery-scored-end-under-fatigue': 'archery-shot-coached',
  'wrestling-penetration-step-shots': 'wrestling-pen-step-opponent', 'ultimate-beach-wind-throwing': 'disc-backhand-receiver', 'ultimate-flick-to-target': 'ultimate-flick-receiver',
  'ultimate-beach-sand-layout-progression': 'ultimate-layout-thrower', 'ultimate-layout-from-knees': 'ultimate-layout-knees-thrower',
};
