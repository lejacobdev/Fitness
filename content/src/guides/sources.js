/**
 * The evidence behind the sport guides. Every entry was checked in PubMed
 * (title, journal, year, DOI) before being cited; the guides reference
 * these by key. Organisational guidelines without a DOI link to the
 * organisation's own page.
 */
export const SOURCES = {
  fifa11: {
    title: 'Comprehensive warm-up programme to prevent injuries in young female footballers',
    detail: 'Soligard et al., BMJ 2008 — the FIFA 11+ warm-up: fewer injuries overall, fewer severe and overuse injuries.',
    url: 'https://doi.org/10.1136/bmj.a2469',
  },
  nordic: {
    title: 'The preventive effect of the Nordic hamstring exercise on hamstring injuries in amateur soccer players',
    detail: 'van der Horst et al., Am J Sports Med 2015 — hamstring injuries cut to about a third with the Nordic curl.',
    url: 'https://doi.org/10.1177/0363546515574057',
  },
  copenhagen: {
    title: 'The Adductor Strengthening Programme prevents groin problems among male football players',
    detail: 'Harøy et al., Br J Sports Med 2019 — the Copenhagen adduction exercise lowered groin problems by 41%.',
    url: 'https://doi.org/10.1136/bjsports-2017-098937',
  },
  balance: {
    title: 'The effect of a balance training program on the risk of ankle sprains in high school athletes',
    detail: 'McGuine & Keene, Am J Sports Med 2006 — balance training roughly halved ankle sprains in high school soccer and basketball.',
    url: 'https://doi.org/10.1177/0363546505284191',
  },
  hockeyAdductor: {
    title: 'A preseason exercise program to prevent adductor muscle strains in professional ice hockey players',
    detail: 'Tyler et al., Am J Sports Med 2002 — adductor strengthening cut groin strains from 3.2 to 0.7 per 1000 game exposures.',
    url: 'https://doi.org/10.1177/03635465020300050801',
  },
  rugbyActivate: {
    title: 'Reducing injury and concussion risk in schoolboy rugby players with a pre-activity movement control programme',
    detail: 'Hislop et al., Br J Sports Med 2017 — done 3+ times a week, match injuries and concussions dropped sharply.',
    url: 'https://doi.org/10.1136/bjsports-2016-097434',
  },
  pitchers: {
    title: 'Risk of serious injury for young baseball pitchers: a 10-year prospective study',
    detail: 'Fleisig et al., Am J Sports Med 2011 — pitching more than 100 innings a year made serious injury 3.5 times more likely.',
    url: 'https://doi.org/10.1177/0363546510384224',
  },
  volleyballAnkle: {
    title: 'A twofold reduction in acute ankle sprains in volleyball after an injury prevention program',
    detail: 'Bahr, Lian & Bahr, Scand J Med Sci Sports 1997 — landing technique plus balance training halved ankle sprains.',
    url: 'https://doi.org/10.1111/j.1600-0838.1997.tb00135.x',
  },
  swimShoulder: {
    title: 'Shoulder pain in elite swimmers: primarily due to swim-volume-induced supraspinatus tendinopathy',
    detail: 'Sein et al., Br J Sports Med 2010 — shoulder pain tracked hours and distance swum, not looseness of the joint.',
    url: 'https://doi.org/10.1136/bjsm.2008.047282',
  },
  reds: {
    title: '2023 IOC consensus statement on Relative Energy Deficiency in Sport (REDs)',
    detail: 'Mountjoy et al., Br J Sports Med 2023 — not eating enough for your training harms health and performance, in girls and boys.',
    url: 'https://doi.org/10.1136/bjsports-2023-106994',
  },
  snowboardWrist: {
    title: 'The efficacy of wrist protectors in preventing snowboarding injuries',
    detail: 'Rønning et al., Am J Sports Med 2001 — wrist guards: 8 wrist injuries instead of 29 in 5,000 riders; beginners were most at risk.',
    url: 'https://doi.org/10.1177/03635465010290051001',
  },
  concussion: {
    title: 'Consensus statement on concussion in sport — Amsterdam 2022',
    detail: 'Patricios et al., Br J Sports Med 2023 — how to recognise, manage and return from concussion.',
    url: 'https://doi.org/10.1136/bjsports-2023-106898',
  },
  acl: {
    title: 'Meta-analysis of meta-analyses of ACL injury reduction training programs',
    detail: 'Webster & Hewett, J Orthop Res 2018 — prevention programmes halve ACL injuries; two-thirds fewer non-contact ACL tears in girls.',
    url: 'https://doi.org/10.1002/jor.24043',
  },
  rowingBack: {
    title: '2021 consensus statement for preventing and managing low back pain in rowers',
    detail: 'Wilson et al., Br J Sports Med 2021 — education on technique and training load; early unloading and exercise when it hurts.',
    url: 'https://doi.org/10.1136/bjsports-2020-103385',
  },
  youthStrength: {
    title: 'Position statement on youth resistance training: the 2014 International Consensus',
    detail: 'Lloyd et al., Br J Sports Med 2014 — supervised strength training is safe and effective for young athletes and lowers injury risk.',
    url: 'https://doi.org/10.1136/bjsports-2013-092952',
  },
  sleep: {
    title: 'Chronic lack of sleep is associated with increased sports injuries in adolescent athletes',
    detail: 'Milewski et al., J Pediatr Orthop 2014 — athletes sleeping under 8 hours were 1.7 times more likely to be injured.',
    url: 'https://doi.org/10.1097/BPO.0000000000000151',
  },
  helmets: {
    title: 'The effect of helmets on the risk of head and neck injuries among skiers and snowboarders: a meta-analysis',
    detail: 'Russell et al., CMAJ 2010 — helmets lowered head injuries by about a third, with no rise in neck injuries.',
    url: 'https://doi.org/10.1503/cmaj.091080',
  },
  specialization: {
    title: 'Sports-specialized intensive training and the risk of injury in young athletes',
    detail: 'Jayanthi et al., Am J Sports Med 2015 — more weekly hours than your age, or organised sport over twice your free play, raised serious overuse injuries.',
    url: 'https://doi.org/10.1177/0363546514567298',
  },
  cheer: {
    title: 'Cheerleading injuries: epidemiology and recommendations for prevention',
    detail: 'American Academy of Pediatrics, Pediatrics 2012 — stunts on hard surfaces and poorly trained supervision raise the risk; spotting and mats lower it.',
    url: 'https://doi.org/10.1542/peds.2012-2480',
  },
  wrestlingWeight: {
    title: 'ACSM position stand: weight loss in wrestlers',
    detail: 'American College of Sports Medicine — rapid weight cutting harms performance, health and growth.',
    url: 'https://pubmed.ncbi.nlm.nih.gov/8926865/',
  },
  pitchSmart: {
    title: 'Pitch Smart — pitch counts and rest days by age',
    detail: 'MLB and USA Baseball guidelines for young pitchers and catchers.',
    url: 'https://www.mlb.com/pitch-smart',
  },
  heat: {
    title: 'NATA position statement: exertional heat illnesses',
    detail: 'National Athletic Trainers\' Association — heat acclimatisation over the first 14 days of pre-season; cool first, transport second.',
    url: 'https://www.nata.org/sites/default/files/exertional-heat-illnesses.pdf',
  },
};
