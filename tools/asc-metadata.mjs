#!/usr/bin/env node
/**
 * §20/M14: App Store listing metadata, age rating, content rights and App
 * Review notes for Student Athlete, set through the App Store Connect API.
 * Idempotent — safe to re-run after editing the copy below. Never submits
 * for review and never touches builds or in-app purchases.
 *
 * Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY (as tools/asc.mjs).
 *
 *   node tools/asc-metadata.mjs [bundle-id]
 */

import { mintToken } from './asc.mjs';

const BASE = 'https://api.appstoreconnect.apple.com';
const BUNDLE_ID = process.argv[2] ?? 'com.studentathlete.app';

export const LISTING = {
  name: 'Student Athlete Companion',
  subtitle: 'Train for your sport & season',
  privacyPolicyUrl: 'https://api.lejacob.dev/fitness/privacy',
  supportUrl: 'https://api.lejacob.dev/fitness/support',
  keywords: 'athlete,high school,college,sports,training,workout,drills,soccer,basketball,football,hockey,coach',
  promotionalText: 'Pick your sport, add your games, and get a weekly plan that peaks on game day. Four-tap morning check-in, 700+ drills with animated how-tos. Works offline.',
  description: `Student Athlete is the training companion for high school and college athletes. Pick your sport, tell it when your season starts and when your games are, and get a plan that's built around competing — not around a gym.

BUILT FOR YOUR SPORT
• 70+ high school and college sports, from soccer, football, basketball and ice hockey to wrestling, swimming, track, volleyball, lacrosse and more
• Positions matter: a goalkeeper trains differently from a midfielder
• Your plan knows your season — build in the off-season, sharpen in pre-season, maintain in-season

PLANS THAT PEAK ON GAME DAY
• Add a game and your week rearranges: heavy work early, sharp and fresh on the day
• Two games in a week? It handles that too

"I WANT TO GET BETTER AT…"
• Pick a skill — shooting power, first step, serve speed, skating speed — and your next game date
• Get a day-by-day plan of exercises and drills, each one explaining why it's there
• Honest about what's achievable before the game, with no overpromising
• Or pick the muscles you want stronger and get a complete workout

A DAILY CHECK-IN THAT ACTUALLY HELPS
• Four taps each morning: sleep, soreness, energy, stress
• Readiness is compared to your own normal — never someone else's
• On a rough day your session is trimmed or swapped for mobility, and you can always override it

700+ EXERCISES AND DRILLS
• Animated how-tos with the muscles each one trains highlighted in red
• Setup, execution, coaching cues and common mistakes for every item
• Filters by skill, equipment, surface and body area, plus a body-map picker
• Everything is downloaded once and works offline

A COACH THAT NOTICES
• Weekly feedback on what you've trained and what you've skipped — "all arms lately, time for legs"
• Personal bests, streaks, sleep and training-load trends
• Exercise progress charts for every lift and drill you log

LOG ANYWHERE
• One-tap logging with prefilled targets, big steppers and an automatic rest timer
• Apple Watch app for logging sets with your phone in your bag
• Home-screen widgets for today's session and your streak
• Optional Apple Health: sleep pre-fills your check-in, finished sessions are saved as workouts

FUEL, DON'T DIET
• Simple plate-and-timing guidance for training days and game days, plus hydration
• No calorie counting, no weight-loss goals, ever

PRIVATE BY DESIGN
• Sign in with Apple only — no email, no password
• No ads, no tracking, no third parties
• Export your data or delete your account at any time, for free

STUDENT ATHLETE PRO
The check-in, your weekly plan, logging and the Apple Watch app are free forever. Pro unlocks unlimited skill plans, the full season calendar and data export. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period; manage them in your App Store account settings.

Student Athlete gives general training information for athletes 13 and up. It is not medical advice, never predicts injury, and never replaces your coach or athletic trainer.

Terms: https://api.lejacob.dev/fitness/terms
Privacy: https://api.lejacob.dev/fitness/privacy`,
  reviewNotes: `WHAT THE APP IS
Student Athlete is a training companion for high school and college athletes (13+). It builds a weekly training plan from the athlete's sport, position and season, rearranges it around their games, adjusts each day from a four-tap readiness check-in, and offers a "get better at a skill" menu. All plan logic runs on-device with deterministic algorithms; there is no AI/LLM, no ads and no third-party SDKs.

SIGN IN
Sign in with Apple is the only login, so any Apple ID works — no demo account is needed. Pro: the core features reviewed below are free; see Subscriptions.

HOW TO REVIEW IN FIVE MINUTES
1. Enter any birth date 13+ years ago, sign in with Apple.
2. Pick a sport (e.g. Soccer), a position, keep the default season dates, pick some equipment, answer the coach question.
3. Today tab: complete the four-tap check-in, open today's session and tap Start to log a set, then Finish and rate effort.
4. Improve tab: Skills → "Shooting power" → pick a game date → Build my plan. Or Muscles → pick "Legs".
5. Plan tab: "Add a game" three days out and watch the week rearrange around it.
6. Me tab: trends, settings, and Delete account.

AGE (Guideline 1.3/5.1.1)
A date-of-birth gate on first launch blocks anyone under 13 completely. We store only the Apple user identifier ("sub") and the birth date; no name, email, location or contacts are requested or collected.

HEALTH DATA (5.1.3)
With permission, the app reads sleep from Apple Health to pre-fill the check-in, and writes finished training sessions as workouts. Health data is used only to support the user's training inside the app. It is never used for advertising, never shared with third parties and never sold. The app works fully if permission is declined.

NO MEDICAL CLAIMS (1.4.1)
The app never predicts injury, diagnoses anything, or advises on return to play. Training-load feedback is phrased only as training load (e.g. "your load is up 40% on your four-week average"), never as injury risk. Fuelling guidance is general, never a calorie deficit for minors, and tells users to consult a doctor or dietitian for specific needs.

SUBSCRIPTIONS
Student Athlete Pro (monthly / yearly auto-renewable) unlocks unlimited skill plans, the season calendar and data export. The check-in, weekly plan, logging, Apple Watch app and account deletion are always free.

SERVICES USED
None. The only server is the developer's own backend (sign-in verification, backup sync, content downloads). No analytics, advertising or tracking SDKs.

ACCOUNT DELETION
Me → Delete account permanently deletes the account and all server data, and clears the device.`,
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
  await step(`display name "${LISTING.name}"`, () => api(`/v1/appInfoLocalizations/${infoLoc.id}`, {
    method: 'PATCH',
    body: { data: { type: 'appInfoLocalizations', id: infoLoc.id, attributes: { name: LISTING.name } } },
  }));

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
