/**
 * Minimal Swift source emission helpers. Deliberately not a templating
 * library — every function here just returns a string, and build.mjs is
 * responsible for what it writes. Keeps codegen free of a dependency that
 * would violate §7/§19's "no third-party Swift packages" in spirit even
 * though this runs on the content side, not inside the Xcode project.
 */

export function swiftStringLiteral(s) {
  return `"${String(s)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\t/g, '\\t')}"`;
}

export function swiftDoubleLiteral(n) {
  if (!Number.isFinite(n)) throw new Error(`not a finite number: ${n}`);
  // Force a decimal point so Swift infers Double, not Int, for whole numbers.
  return Number.isInteger(n) ? `${n}.0` : String(n);
}

export function swiftArray(items, indent = '    ') {
  if (items.length === 0) return '[]';
  return `[\n${items.map((i) => `${indent}${i},`).join('\n')}\n${indent.slice(4)}]`;
}

export function swiftStringArrayLiteral(strings) {
  if (strings.length === 0) return '[]';
  return `[${strings.map(swiftStringLiteral).join(', ')}]`;
}

/**
 * `entries` is an array of already-formatted "key: value" strings (matching
 * `swiftArray`'s convention below) — NOT [key, value] pairs. An earlier
 * version destructured each entry as `[k, v]`, which for a string silently
 * indexes by character (entries[0], entries[1]) instead of failing, and
 * produced single-character garbage keys/values with no error at all.
 */
export function swiftDict(entries, indent = '    ') {
  if (entries.length === 0) return '[:]';
  return `[\n${entries.map((e) => `${indent}${e},`).join('\n')}\n${indent.slice(4)}]`;
}

/** A generated-file header, identical across every emitted file. */
export function generatedHeader(sourceDescription) {
  return `// GENERATED FILE — do not edit by hand.
// Produced by content/scripts/build.mjs from ${sourceDescription}.
// Re-run \`npm run build\` in content/ after changing the source data.

`;
}
