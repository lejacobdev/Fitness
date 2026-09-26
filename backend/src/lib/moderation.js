/**
 * Names and short texts other people see — nicknames, league, team and
 * workout names, a coach's notes — are checked before they are saved
 * (App Store guideline 1.2: filter objectionable content). Deliberately a
 * short list of unambiguous words in English and German, matched as whole
 * words after undoing common disguises (l33t, dots, repeats), so ordinary
 * names ("Scunthorpe", "Dickson") pass.
 */
const WORDS = [
  // English profanity and sexual terms
  'fuck', 'fucker', 'fucking', 'motherfucker', 'shit', 'bullshit', 'bitch', 'bastard', 'asshole', 'dick', 'dickhead',
  'cock', 'cunt', 'pussy', 'twat', 'wanker', 'slut', 'whore', 'porn', 'porno', 'sex', 'sexy', 'nude', 'nudes', 'boobs',
  'tits', 'penis', 'vagina', 'rape', 'rapist', 'dildo', 'horny', 'cum', 'jizz', 'milf',
  // English slurs and hate
  'nigger', 'nigga', 'faggot', 'fag', 'retard', 'retarded', 'spastic', 'tranny', 'kike', 'chink', 'spic', 'wetback',
  'gook', 'nazi', 'hitler', 'kkk',
  // Violence / self-harm ("suicide sprints" is a real drill, so not that word)
  'killyourself',
  // Drugs
  'cocaine', 'heroin', 'meth',
  // German
  'scheisse', 'scheiße', 'scheiss', 'arschloch', 'arsch', 'hurensohn', 'hure', 'fotze', 'wichser', 'fick', 'ficken',
  'schlampe', 'nutte', 'missgeburt', 'spast', 'behindert', 'schwuchtel', 'kanake', 'neger', 'vergewaltigung',
];

const BANNED = new Set(WORDS);
/**
 * Caught even inside other words ("xXfuckXx"). Only words that never occur
 * inside ordinary ones — so no "arsch" (Marsch), "cunt" (Scunthorpe) or "sex".
 */
const EMBEDDED = ['fuck', 'nigger', 'nigga', 'faggot', 'hitler', 'hurensohn', 'fotze', 'wichser', 'schwuchtel', 'killyourself'];

const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', 8: 'b', '@': 'a', $: 's', '!': 'i', '€': 'e' };

function normalise(text) {
  return String(text ?? '')
    .toLowerCase()
    .normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[013457 8@$!€]/g, (c) => LEET[c] ?? c)
    .replace(/(.)\1{2,}/g, '$1$1');
}

/** True when the text contains a word nobody should see in a name or note. */
export function isObjectionable(text) {
  const clean = normalise(text);
  const words = clean.split(/[^\p{L}]+/u).filter(Boolean);
  for (const word of words) {
    if (BANNED.has(word) || BANNED.has(word.replace(/(.)\1+/g, '$1'))) return true;
  }
  // Disguised with spaces or dots: "f.u.c.k", "n a z i".
  const squashed = clean.replace(/[^\p{L}]+/gu, '');
  if (words.length > 1 && words.every((w) => w.length === 1) && BANNED.has(squashed)) return true;
  return EMBEDDED.some((w) => squashed.includes(w));
}
