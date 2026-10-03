// Dev-only: OVERRIDE='{"slug":[{"at":[x,z],"facing":deg,"phase":p}, null]}' tweaks cast entries in memory,
// so a placement can be tried and rendered without editing the source.
export function applyOverrides(patterns) {
  if (!process.env.OVERRIDE) return;
  const o = JSON.parse(process.env.OVERRIDE);
  for (const p of patterns) for (const [i, patch] of (o[p.slug] ?? []).entries()) if (patch && p.cast?.[i]) Object.assign(p.cast[i], patch);
}
