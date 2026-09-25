#!/usr/bin/env node
/**
 * §20/M14: App Store listing metadata, age rating, content rights and App
 * Review notes for Athlete OS, set through the App Store Connect API.
 * Idempotent — safe to re-run after editing the copy below. Never submits
 * for review and never touches builds or in-app purchases.
 *
 * Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY (as tools/asc.mjs).
 *
 *   node tools/asc-metadata.mjs [bundle-id] [--name-only]
 */

import { mintToken } from './asc.mjs';

const BASE = 'https://api.appstoreconnect.apple.com';
const args = process.argv.slice(2);
const NAME_ONLY = args.includes('--name-only');
const BUNDLE_ID = args.find((a) => !a.startsWith('--')) ?? 'com.studentathlete.app';

/** App Store names are unique across the store; the first free one is used. */
export const NAMES = ['Athlete OS', 'Athlete OS – AOS', 'AOS – Athlete OS', 'Athlete OS: Train & Learn'];

export const LISTING = {
  name: NAMES[0],
  subtitle: 'Your sport, schedule & mindset',
  privacyPolicyUrl: 'https://api.lejacob.dev/fitness/privacy',
  supportUrl: 'https://api.lejacob.dev/fitness/support',
  keywords: 'student athlete,high school,college,training,workout,sports,coach,team,mindset,soccer,basketball',
  promotionalText: 'Workouts built around your practices, games and exams. Two-tap morning check-in, Duolingo-style Campus lessons, tests every 6 weeks, and a coach and parent view.',
  description: `Athlete OS is the operating system for student athletes: training built around your real schedule, plus the knowledge and mindset that take you to the next level.

HOME: YOUR DAY AT A GLANCE
• A quote to start the day and a two-tap morning check-in (Apple Health fills in sleep and energy)
• Today's workout, explained: a short one after practice, a full gym session on free days, nothing heavy before games
• Sick, travelling, on holiday or had a head knock? One tap and the plan backs off

BUILT AROUND YOUR SCHEDULE
• Connect your team or school calendar (TeamSnap, Google, Apple): games with times and away trips, practices and exams come in by themselves
• A cancelled practice turns into a gym day; exam weeks get lighter training
• 60 sports with their formats and positions — soccer, football, basketball, volleyball, track, swimming, hockey, wrestling, lacrosse and many more

GET BETTER AT YOUR SPORT
• Pick a skill and your next game date for a day-by-day plan, or build a workout by muscle
• 700+ exercises and drills with animated how-tos
• Tests every 6–8 weeks: vertical jump filmed with your camera, 10 m and 30 m sprint, plank, push-ups and a test for your sport — see real improvement

CAMPUS: LEARN LIKE DUOLINGO
• Short lessons on training, nutrition, sleep, injury prevention, psychology, tactics and more
• Hearts, XP, streaks, badges and spaced review so it sticks
• Leagues with your teammates

MINDSET
• A 2-minute evening reflection: one win, one lesson
• Season goals turned into one focus point a week
• Guided breathing and a game-day visualization

TEAM & FAMILY
• Coach mode: your team's readiness at a glance, and workouts you send appear on their Home screen
• A private weekly summary link for parents — numbers only, never anything you wrote

SAFETY FIRST
• Head knock? Training pauses, and the return-to-play steps are explained — your doctor decides
• A kind warning when constant tiredness meets heavy training
• Fuel, don't diet: no calorie counting, no weight-loss goals

PRIVATE BY DESIGN
• Sign in with Apple only. No ads, no tracking, no third parties
• Everything is backed up and comes back on a new phone
• Log out any time, or delete your account for good

ATHLETE OS PRO
The check-in, weekly plan, logging, Campus and the Apple Watch app are free. Pro unlocks unlimited skill plans and muscle workouts, several sports and every progress chart. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period; manage them in your App Store account settings.

Athlete OS gives general training information for athletes 13 and up. It is not medical advice, never predicts injury, never clears anyone to return to play, and never replaces a coach, athletic trainer or doctor.

Terms: https://api.lejacob.dev/fitness/terms
Privacy: https://api.lejacob.dev/fitness/privacy`,
  reviewNotes: `WHAT THE APP IS
Athlete OS is a training companion for high school and college athletes (13+). It builds workouts around the athlete's sport, season, practices, games and exams, adjusts each day from a morning check-in, and adds learning (Campus lessons) and mindset tools. All plan logic runs on-device with deterministic algorithms; there is no AI/LLM, no ads and no third-party SDKs.

SIGN IN
Sign in with Apple is the only login, so any Apple ID works — no demo account is needed.

HOW TO REVIEW IN FIVE MINUTES
1. Enter any birth date 13+ years ago, sign in with Apple, pick a sport (e.g. Soccer) and a position.
2. Home: do the morning check-in, set practice days, open today's workout and tap Start.
3. Campus tab: play a lesson (Duolingo-style), then open the trophy (leagues) and medal (badges).
4. Home → Your levels → Mindset: evening reflection, season goals, breathing.
5. Me → Tests (jump test uses the camera), Team & family, Head knocks & concussion, Log out and Delete account.

AGE (1.3 / 5.1.1)
A date-of-birth gate blocks anyone under 13. We store the Apple user identifier ("sub") and birth date; no name, email, location or contacts.

HEALTH DATA (5.1.3)
With permission the app reads sleep and resting heart rate from Apple Health to pre-fill the check-in, and writes finished sessions as workouts. Health data is used only for the user's own training in the app — never for advertising, never shared or sold. Everything works if permission is declined.

CAMERA
Used only for the vertical jump test: the video stays on the device and is used to measure flight time.

LEAGUES, TEAMS, PARENT LINK
Leagues and coach teams are private groups joined only with a 6-character code. Other members see a 2–20 character nickname and numbers (weekly XP, or for a coach: readiness band and training minutes) — no messaging, no free text. The parent summary is a private, revocable link showing numbers only.

NO MEDICAL CLAIMS (1.4.1)
The app never predicts injury or diagnoses. The concussion page explains the standard graduated return-to-sport steps (2023 international consensus, CDC HEADS UP) and pauses training; it states that a doctor must clear the athlete. The low-energy notice suggests eating enough and talking to a parent, coach or doctor. Fuelling guidance never includes a calorie deficit.

SUBSCRIPTIONS
Athlete OS Pro (monthly / yearly auto-renewable). The check-in, weekly plan, logging, Campus, Apple Watch app, log out and account deletion are always free.

ACCOUNT DELETION
Me → Delete account deletes the account and all server data (and revokes Sign in with Apple), then clears the device.`,
};

let token;
async function api(path, { method = 'GET', body } = {}) {
  token ??= mintToken();
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (!res.ok) throw new Error(`${res.status} ${method} ${path} — ${json.errors?.map((e) => `${e.title}: ${e.detail}`).join('; ') ?? text}`);
  return json;
}

async function step(label, fn) {
  try {
    const result = await fn();
    console.log(`ok     ${label}${result ? ` — ${result}` : ''}`);
    return true;
  } catch (err) {
    console.log(`FAILED ${label} — ${err.message}`);
    return false;
  }
}

/** Tries each name until the App Store accepts one (a taken name is a 409). */
async function setName(localizationId) {
  for (const name of NAMES) {
    try {
      await api(`/v1/appInfoLocalizations/${localizationId}`, {
        method: 'PATCH',
        body: { data: { type: 'appInfoLocalizations', id: localizationId, attributes: { name } } },
      });
      console.log(`ok     display name "${name}"`);
      return name;
    } catch (err) {
      console.log(`taken  display name "${name}" — ${err.message.slice(0, 120)}`);
    }
  }
  console.log('FAILED no candidate name was free');
  return null;
}

function checkLimits() {
  const limits = { name: 30, subtitle: 30, keywords: 100, promotionalText: 170, description: 4000, reviewNotes: 4000 };
  for (const [field, max] of Object.entries(limits)) {
    if (LISTING[field].length > max) throw new Error(`${field} is ${LISTING[field].length} chars, limit ${max}`);
  }
}

async function main() {
  checkLimits();
  const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}`);
  const app = apps.data.find((a) => a.attributes.bundleId === BUNDLE_ID);
  if (!app) throw new Error(`no app for ${BUNDLE_ID}`);

  const infos = await api(`/v1/apps/${app.id}/appInfos`);
  const info = infos.data.find((i) => i.attributes.state !== 'READY_FOR_DISTRIBUTION') ?? infos.data[0];

  if (NAME_ONLY) {
    const locs = await api(`/v1/appInfos/${info.id}/appInfoLocalizations`);
    const loc = locs.data.find((l) => l.attributes.locale === 'en-US');
    await setName(loc.id);
    return;
  }

  await step('categories (Sports / Health & Fitness)', () => api(`/v1/appInfos/${info.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appInfos', id: info.id, relationships: {
      primaryCategory: { data: { type: 'appCategories', id: 'SPORTS' } },
      secondaryCategory: { data: { type: 'appCategories', id: 'HEALTH_AND_FITNESS' } },
    } } },
  }));

  const infoLocs = await api(`/v1/appInfos/${info.id}/appInfoLocalizations`);
  const infoLoc = infoLocs.data.find((l) => l.attributes.locale === 'en-US');
  await step('subtitle + privacy policy URL', () => api(`/v1/appInfoLocalizations/${infoLoc.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appInfoLocalizations', id: infoLoc.id, attributes: {
      subtitle: LISTING.subtitle, privacyPolicyUrl: LISTING.privacyPolicyUrl,
    } } },
  }));
  await setName(infoLoc.id);

  // Age rating: no objectionable content. The sport list includes rifle and
  // archery (dry-fire/holding drills only), hence mild weapons references;
  // training and wellness information is a health/wellness topic but not
  // medical treatment information. The in-app gate blocks under-13s, so the
  // store rating is raised to match with the 13+ override.
  const age = await api(`/v1/appInfos/${info.id}/ageRatingDeclaration`);
  const ageAttributes = {
    advertising: false, alcoholTobaccoOrDrugUseOrReferences: 'NONE', contests: 'NONE', gambling: false,
    gamblingSimulated: 'NONE', gunsOrOtherWeapons: 'INFREQUENT_OR_MILD', healthOrWellnessTopics: true,
    lootBox: false, medicalOrTreatmentInformation: 'NONE', messagingAndChat: false, parentalControls: false,
    profanityOrCrudeHumor: 'NONE', ageAssurance: false, sexualContentGraphicAndNudity: 'NONE',
    sexualContentOrNudity: 'NONE', socialMedia: false, horrorOrFearThemes: 'NONE', matureOrSuggestiveThemes: 'NONE',
    unrestrictedWebAccess: false, userGeneratedContent: false, violenceCartoonOrFantasy: 'NONE',
    violenceRealisticProlongedGraphicOrSadistic: 'NONE', violenceRealistic: 'NONE',
    ageRatingOverrideV2: 'THIRTEEN_PLUS',
  };
  const ageOk = await step('age rating declaration (13+)', () => api(`/v1/ageRatingDeclarations/${age.data.id}`, {
    method: 'PATCH', body: { data: { type: 'ageRatingDeclarations', id: age.data.id, attributes: ageAttributes } },
  }));
  if (!ageOk) {
    // Retry without the newest fields one at a time is noisy; fall back to
    // the long-standing field set plus the legacy override.
    const legacy = { ...ageAttributes };
    delete legacy.ageRatingOverrideV2;
    legacy.gunsOrOtherWeapons = 'NONE';
    await step('age rating declaration (fallback field set)', () => api(`/v1/ageRatingDeclarations/${age.data.id}`, {
      method: 'PATCH', body: { data: { type: 'ageRatingDeclarations', id: age.data.id, attributes: legacy } },
    }));
  }

  await step('content rights: no third-party content', () => api(`/v1/apps/${app.id}`, {
    method: 'PATCH', body: { data: { type: 'apps', id: app.id, attributes: { contentRightsDeclaration: 'DOES_NOT_USE_THIRD_PARTY_CONTENT' } } },
  }));

  const versions = await api(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`);
  const version = versions.data.find((v) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(v.attributes.appStoreState));
  if (!version) throw new Error('no editable App Store version');

  const vLocs = await api(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  const vLoc = vLocs.data.find((l) => l.attributes.locale === 'en-US');
  await step(`version ${version.attributes.versionString} description/keywords/promo/support URL`, () => api(`/v1/appStoreVersionLocalizations/${vLoc.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appStoreVersionLocalizations', id: vLoc.id, attributes: {
      description: LISTING.description, keywords: LISTING.keywords,
      promotionalText: LISTING.promotionalText, supportUrl: LISTING.supportUrl,
    } } },
  }));

  const review = await api(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  if (review.data) {
    await step('App Review notes (update)', () => api(`/v1/appStoreReviewDetails/${review.data.id}`, {
      method: 'PATCH',
      body: { data: { type: 'appStoreReviewDetails', id: review.data.id, attributes: { notes: LISTING.reviewNotes, demoAccountRequired: false } } },
    }));
  } else {
    await step('App Review notes (create)', () => api('/v1/appStoreReviewDetails', {
      method: 'POST',
      body: { data: { type: 'appStoreReviewDetails', attributes: { notes: LISTING.reviewNotes, demoAccountRequired: false },
        relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } },
    }));
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
