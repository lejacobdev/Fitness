#!/usr/bin/env node
/**
 * The one build step §21/§22 require: turn the authored content in src/ into
 * (a) compiled Swift source for the rendering infrastructure that never
 * varies by sport — qualities, muscles, the muscle map, pose patterns, props
 * — and (b) versioned, checksummed JSON content packs for the catalogue
 * itself (§3's "one small core pack... plus one pack per sport").
 *
 * The split is deliberate: §9 says a build script emits MuscleMapPaths.swift,
 * and that data is foundational rendering infrastructure identical for every
 * athlete regardless of which sports they follow, so it is compiled into the
 * app binary. The catalogue (exercises, drills, sport profiles) is what §3
 * says packs exist to let update without an App Store release, so it ships
 * as JSON, decoded and cross-referenced against the compiled Swift constants
 * by slug at runtime — never duplicated into both places.
 *
 *   node scripts/build.mjs
 */

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { CATALOGUE, BASE_ITEMS } from '../src/catalogue.js';
import { MUSCLE_MODEL_VERSION, MUSCLES } from '../src/muscles.js';
import { buildMuscleMapPaths } from '../src/muscleMap.js';
import { POSE_MODEL_VERSION, POSE_PATTERNS } from '../src/poses.js';
import { PROPS } from '../src/props.js';
import { QUALITIES, QUALITY_MODEL_VERSION } from '../src/qualities.js';
import { REST_POINTS, SEGMENTS } from '../src/rig.js';
import { SPORT_CATALOGUE_VERSION, SPORTS } from '../src/sports.js';
import {
  generatedHeader, swiftArray, swiftDict, swiftDoubleLiteral,
  swiftStringArrayLiteral, swiftStringLiteral,
} from './swiftgen.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CONTENT_ROOT = path.resolve(HERE, '..');
const REPO_ROOT = path.resolve(CONTENT_ROOT, '..');
const SWIFT_OUT = path.join(REPO_ROOT, 'app/Shared/Sources/Generated');
const PACKS_OUT = path.join(CONTENT_ROOT, 'dist');

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`wrote ${path.relative(REPO_ROOT, filePath)} (${content.length} bytes)`);
}

// ═══════════════════════════════════════════════════════════════════════════
// Swift codegen — rendering infrastructure (§9)
// ═══════════════════════════════════════════════════════════════════════════

function genQualitiesSwift() {
  const groups = [...new Set(QUALITIES.map((q) => q.group))];
  const groupEnumCases = groups.map((g) => `    case ${camel(g)} = ${swiftStringLiteral(g)}`).join('\n');

  const structs = QUALITIES.map((q) => `QualityInfo(
        id: ${swiftStringLiteral(q.slug)},
        group: .${camel(q.group)},
        name: ${swiftStringLiteral(q.name)},
        shortName: ${swiftStringLiteral(q.shortName)},
        info: ${swiftStringLiteral(q.description)}
    )`);

  return `${generatedHeader('content/src/qualities.js')}import Foundation

/// §6's fixed, versioned quality list. Bump this if QUALITY_MODEL_VERSION
/// changes in content/src/qualities.js — a mismatch means a downloaded pack
/// was authored against a different quality model than this binary compiles.
public let qualityModelVersion = ${QUALITY_MODEL_VERSION}

public enum QualityGroup: String, CaseIterable, Codable, Sendable {
${groupEnumCases}
}

public struct QualityInfo: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let group: QualityGroup
    public let name: String
    public let shortName: String
    public let info: String
}

public let qualities: [QualityInfo] = ${swiftArray(structs)}

public let qualitiesBySlug: [String: QualityInfo] =
    Dictionary(uniqueKeysWithValues: qualities.map { ($0.id, $0) })
`;
}

function genMusclesSwift() {
  const regions = [...new Set(MUSCLES.map((m) => m.region))];
  const regionCases = regions.map((r) => `    case ${camel(r)} = ${swiftStringLiteral(r)}`).join('\n');

  const structs = MUSCLES.map((m) => `MuscleInfo(
        id: ${swiftStringLiteral(m.slug)},
        name: ${swiftStringLiteral(m.name)},
        plainName: ${swiftStringLiteral(m.plainName)},
        region: .${camel(m.region)},
        views: ${swiftStringArrayLiteral(m.views)},
        drawable: ${m.drawable === false ? 'false' : 'true'},
        renderVia: ${m.renderVia ? swiftStringLiteral(m.renderVia) : 'nil'}
    )`);

  return `${generatedHeader('content/src/muscles.js')}import Foundation

public let muscleModelVersion = ${MUSCLE_MODEL_VERSION}

public enum MuscleRegion: String, CaseIterable, Codable, Sendable {
${regionCases}
}

public struct MuscleInfo: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let plainName: String
    public let region: MuscleRegion
    public let views: [String]
    public let drawable: Bool
    /// The drawable muscle this one highlights through, when \`drawable\` is
    /// false — see content/src/muscles.js for why some muscles have no
    /// distinct 2D silhouette.
    public let renderVia: String?
}

public let muscles: [MuscleInfo] = ${swiftArray(structs)}

public let musclesBySlug: [String: MuscleInfo] =
    Dictionary(uniqueKeysWithValues: muscles.map { ($0.id, $0) })

/// §9: primary muscles solid red, secondary ~45% opacity, stabilisers ~18%.
public enum MuscleRole {
    case primary, secondary, stabiliser

    public var opacity: Double {
        switch self {
        case .primary: return 1.0
        case .secondary: return 0.45
        case .stabiliser: return 0.18
        }
    }

    public init(weight: Double) {
        if weight >= 1.0 { self = .primary }
        else if weight >= 0.5 { self = .secondary }
        else { self = .stabiliser }
    }
}

/// §9: the fixed primary-muscle accent colour.
public let muscleMapPrimaryColorHex = "#E5383B"
`;
}

function genMuscleMapPathsSwift(paths) {
  const entries = Object.entries(paths)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => [swiftStringLiteral(k), swiftStringLiteral(v)]);

  return `${generatedHeader('content/src/muscleMap.js (rig.js + muscleRegions.js)')}import Foundation

/// One straight-edged SVG path \`d\` string per "\\(muscleSlug).\\(view).\\(side)"
/// key, rendered with SwiftUI Path/Canvas — no SVG library, works unchanged
/// on watchOS (§9). Coordinates are in a fixed 100x200 canonical space.
public let muscleMapPaths: [String: String] = ${swiftDict(entries.map(([k, v]) => `${k}: ${v}`))}

public let muscleMapCanonicalWidth: Double = 100
public let muscleMapCanonicalHeight: Double = 200
`;
}

function genPosePatternsSwift() {
  const joints = [...new Set(POSE_PATTERNS.flatMap((p) => Object.keys(p.start)))];
  const jointCases = joints.map((j) => `    case ${j} = ${swiftStringLiteral(j)}`).join('\n');

  function poseDict(angles) {
    const entries = Object.entries(angles).map(([j, v]) => [`.${j}`, swiftDoubleLiteral(v)]);
    return swiftDict(entries.map(([k, v]) => `${k}: ${v}`), '        ');
  }

  const structs = POSE_PATTERNS.map((p) => `PosePatternInfo(
        id: ${swiftStringLiteral(p.slug)},
        name: ${swiftStringLiteral(p.name)},
        start: ${poseDict(p.start)},
        end: ${poseDict(p.end)}
    )`);

  return `${generatedHeader('content/src/poses.js')}import Foundation

public let poseModelVersion = ${POSE_MODEL_VERSION}

/// The rig's joints (§9 job 2) — left/right paired where the body is.
public enum Joint: String, CaseIterable, Codable, Sendable, Hashable {
${jointCases}
}

public typealias Pose = [Joint: Double]

public struct PosePatternInfo: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let start: Pose
    public let end: Pose
}

/// §9: "roughly 25-35 pairs" — one canonical movement pattern per entry, every
/// item inherits its pattern's pair rather than being posed individually.
public let posePatterns: [PosePatternInfo] = ${swiftArray(structs)}

public let posePatternsBySlug: [String: PosePatternInfo] =
    Dictionary(uniqueKeysWithValues: posePatterns.map { ($0.id, $0) })

/// §7's unilateral expansion rule: mirrors every left/right joint pair. Used
/// at render time, never baked into a second copy of pose data.
public func mirrorPose(_ pose: Pose) -> Pose {
    var mirrored: Pose = [:]
    for joint in Joint.allCases {
        let name = joint.rawValue
        if name.hasSuffix("L") {
            let rJoint = Joint(rawValue: String(name.dropLast()) + "R")!
            mirrored[joint] = pose[rJoint]
        } else if name.hasSuffix("R") {
            let lJoint = Joint(rawValue: String(name.dropLast()) + "L")!
            mirrored[joint] = pose[lJoint]
        } else {
            mirrored[joint] = pose[joint]
        }
    }
    return mirrored
}
`;
}

function genPropsSwift() {
  const structs = PROPS.map((p) => `PropInfo(
        id: ${swiftStringLiteral(p.slug)},
        name: ${swiftStringLiteral(p.name)},
        attachTo: ${swiftStringLiteral(p.attachTo)},
        offsetX: ${swiftDoubleLiteral(p.offset.x)},
        offsetY: ${swiftDoubleLiteral(p.offset.y)}
    )`);

  return `${generatedHeader('content/src/props.js')}import Foundation

/// §9: "a small named shape positioned relative to a joint" — around a dozen
/// props cover every sport in the catalogue, so drills reuse the same rig
/// rather than needing their own art.
public struct PropInfo: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let attachTo: String
    public let offsetX: Double
    public let offsetY: Double
}

public let props: [PropInfo] = ${swiftArray(structs)}

public let propsBySlug: [String: PropInfo] =
    Dictionary(uniqueKeysWithValues: props.map { ($0.id, $0) })
`;
}

function genRigGeometrySwift() {
  const pointEntries = Object.entries(REST_POINTS).map(([name, p]) => [
    swiftStringLiteral(name),
    `RigPoint(x: ${swiftDoubleLiteral(p.x)}, y: ${swiftDoubleLiteral(p.y)})`,
  ]);

  const segmentEntries = Object.entries(SEGMENTS).map(([id, seg]) => {
    const value = seg.kind === 'line'
      ? `.line(a: ${swiftStringLiteral(seg.a)}, b: ${swiftStringLiteral(seg.b)}, halfWidth: ${swiftDoubleLiteral(seg.halfWidth)})`
      : `.point(center: ${swiftStringLiteral(seg.center)}, radius: ${swiftDoubleLiteral(seg.radius)})`;
    return [swiftStringLiteral(id), value];
  });

  return `${generatedHeader('content/src/rig.js')}import Foundation

/// The canonical (right-side; mirror x for left) reference-pose rig used only
/// by the §9 job-1 static muscle map. The job-2 animated pose rig is driven
/// entirely by PosePatternInfo's joint angles at runtime, not by this file.
public struct RigPoint: Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double
}

public enum RigSegment: Sendable, Hashable {
    case line(a: String, b: String, halfWidth: Double)
    case point(center: String, radius: Double)
}

public let rigCanonicalWidth: Double = 100
public let rigCanonicalHeight: Double = 200
public let rigMidlineX: Double = 50

public let rigRestPoints: [String: RigPoint] = ${swiftDict(pointEntries.map(([k, v]) => `${k}: ${v}`))}

public let rigSegments: [String: RigSegment] = ${swiftDict(segmentEntries.map(([k, v]) => `${k}: ${v}`))}
`;
}

function camel(kebab) {
  return kebab.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}

// ═══════════════════════════════════════════════════════════════════════════
// Content packs (§3) — JSON, versioned, checksummed
// ═══════════════════════════════════════════════════════════════════════════

function sha256(content) {
  return crypto.createHash('sha256').update(content, 'utf8').digest('hex');
}

function buildPacks() {
  fs.rmSync(PACKS_OUT, { recursive: true, force: true });
  fs.mkdirSync(PACKS_OUT, { recursive: true });

  const generatedAt = new Date().toISOString();
  const manifestPacks = [];

  function writePack(slug, version, body) {
    const payload = JSON.stringify({
      slug, version, generatedAt,
      qualityModelVersion: QUALITY_MODEL_VERSION,
      muscleModelVersion: MUSCLE_MODEL_VERSION,
      poseModelVersion: POSE_MODEL_VERSION,
      ...body,
    }, null, 2);
    const fileName = `${slug}.json`;
    const filePath = path.join(PACKS_OUT, fileName);
    fs.writeFileSync(filePath, payload, 'utf8');
    const checksum = sha256(payload);
    manifestPacks.push({
      slug, version, file: fileName,
      sizeBytes: Buffer.byteLength(payload, 'utf8'),
      checksum,
    });
    return filePath;
  }

  // Core pack: every sport-agnostic exercise (fully expanded), per §3 — "the
  // general exercise library, the shared drills" (the rig itself is compiled
  // Swift, not pack data — see the header comment on this file).
  const exerciseItems = CATALOGUE.filter((i) => i.kind === 'exercise');
  writePack('core', SPORT_CATALOGUE_VERSION, { items: exerciseItems });

  // One pack per sport: its profile plus its own drills (fully expanded).
  // A sport with no authored drills yet still gets a valid pack with an empty
  // drills array — §5: "no sport ships without" its profile existing, even
  // before its drill library is built out.
  for (const sport of SPORTS) {
    const drillItems = CATALOGUE.filter((i) => i.kind === 'drill' && i.sport === sport.slug);
    writePack(sport.slug, SPORT_CATALOGUE_VERSION, { sport, items: drillItems });
  }

  const manifest = {
    generatedAt,
    packs: manifestPacks.sort((a, b) => a.slug.localeCompare(b.slug)),
  };
  fs.writeFileSync(path.join(PACKS_OUT, 'manifest.json'), JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`wrote ${manifestPacks.length} packs + manifest.json to ${path.relative(REPO_ROOT, PACKS_OUT)}`);

  const totalBytes = manifestPacks.reduce((sum, p) => sum + p.sizeBytes, 0);
  console.log(`total pack size: ${(totalBytes / 1024).toFixed(1)} KB`);
}

// ═══════════════════════════════════════════════════════════════════════════

function main() {
  console.log(`content: ${BASE_ITEMS.length} base items -> ${CATALOGUE.length} expanded`);
  console.log(`sports: ${SPORTS.length}, qualities: ${QUALITIES.length}, muscles: ${MUSCLES.length}`);

  writeFile(path.join(SWIFT_OUT, 'Qualities.swift'), genQualitiesSwift());
  writeFile(path.join(SWIFT_OUT, 'Muscles.swift'), genMusclesSwift());
  writeFile(path.join(SWIFT_OUT, 'MuscleMapPaths.swift'), genMuscleMapPathsSwift(buildMuscleMapPaths()));
  writeFile(path.join(SWIFT_OUT, 'PosePatterns.swift'), genPosePatternsSwift());
  writeFile(path.join(SWIFT_OUT, 'Props.swift'), genPropsSwift());
  writeFile(path.join(SWIFT_OUT, 'RigGeometry.swift'), genRigGeometrySwift());

  buildPacks();
}

main();
