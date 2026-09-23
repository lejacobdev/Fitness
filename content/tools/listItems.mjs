// Dev-only: list base items from one source file to choose their pose pattern.
//   node tools/listItems.mjs exercises|exercisesExtra|drills|drills/<file>
const which = process.argv[2];
const mod = await import(`../src/items/${which}.js`);
const items = Object.values(mod).find(Array.isArray);
for (const i of items) {
  const how = (i.execution ?? [])[0] ?? '';
  console.log(`${i.slug} | ${i.name} | ${i.sport ?? '-'} | eq:${(i.equipment ?? []).join(',') || '-'} | was:${i.startPose}${i.endPose !== i.startPose ? '→' + i.endPose : ''} | ${how.slice(0, 110)}`);
}
