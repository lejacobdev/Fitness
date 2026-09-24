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

import { buildAnatomy } from '../src/anatomy.js';
import { CATALOGUE, BASE_ITEMS, INTERIM_BY_POSE } from '../src/catalogue.js';
import { MUSCLE_MODEL_VERSION, MUSCLES } from '../src/muscles.js';
import { JOINTS, POSE_MODEL_VERSION, POSE_PATTERNS } from '../src/poses.js';
import { frameAt, frameAtTime, pathSeconds, placeKeyframes } from '../src/rig3d.js';
import { PROPS } from '../src/props.js';
import { QUALITIES, QUALITY_MODEL_VERSION } from '../src/qualities.js';
import { EQUIPMENT, EQUIPMENT_LEVELS, PLYOMETRIC_DOSE_KIND } from '../src/schema.js';
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

public enum QualityGroup: String, CaseIterable, Codable, Sendable, Hashable {
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

/**
 * §10's plan generator needs the same equipment-level table
 * content/src/schema.js already validates every item against, so the
 * generator's eligibility check can never mean something different from
 * what the sport-coverage tests (§21) already proved every sport satisfies.
 */
function genEquipmentSwift() {
  const levelEnumCases = EQUIPMENT_LEVELS.map((l) => `    case ${camel(l)} = ${swiftStringLiteral(l)}`).join('\n');
  const rankCases = EQUIPMENT_LEVELS.map((l, i) => `        case .${camel(l)}: return ${i}`).join('\n');
  const tagEntries = Object.entries(EQUIPMENT).map(
    ([tag, level]) => `${swiftStringLiteral(tag)}: .${camel(level)}`,
  );

  return `${generatedHeader('content/src/schema.js')}import Foundation

/// \`.none\` means the athlete needs nothing they would not already have.
/// Ordered low to high so a higher level is always assumed to include every
/// lower one (an athlete with \`.full\` gym access also has whatever \`.minimal\`
/// or \`.none\` needs).
public enum EquipmentLevel: String, CaseIterable, Codable, Sendable, Comparable {
${levelEnumCases}

    private var rank: Int {
        switch self {
${rankCases}
        }
    }

    public static func < (lhs: EquipmentLevel, rhs: EquipmentLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Every equipment tag an item may require, and the lowest level at which it
/// is available (content/src/schema.js's own EQUIPMENT table, verbatim).
public let equipmentLevelByTag: [String: EquipmentLevel] = ${swiftDict(tagEntries)}

/// §7/§10: "plyometric volume is prescribed in ground contacts... An item
/// whose dose kind is \`contacts\` is a plyometric as far as §10's volume cap
/// is concerned" — schema.js's own PLYOMETRIC_DOSE_KIND, verbatim, so the
/// generator's ground-contact cap can never drift from what content
/// considers a plyometric.
public let plyometricDoseKind = ${swiftStringLiteral(PLYOMETRIC_DOSE_KIND)}
`;
}

/**
 * Every sport's profile (name, positions, skills, quality weights),
 * compiled directly into the binary rather than pack-delivered. §15's sport
 * picker needs real names for all ~73 sports before the athlete has
 * downloaded anything — the deeper per-sport DATA (drills/items) still
 * arrives via packs (§3); this is only the index needed to choose a sport.
 * Embedded as raw JSON text (decoded at runtime through CatalogueModels.
 * swift's already-proven SportInfo decoder) rather than hand-built Swift
 * struct literals, so there is exactly one place that knows this shape.
 */
function genAllSportsSwift() {
  const json = JSON.stringify(SPORTS);
  return `${generatedHeader('content/src/sports.js')}import Foundation

public let allSportsJSON = #"""
${json}
"""#

public let allSports: [SportInfo] = (try? JSONDecoder().decode([SportInfo].self, from: Data(allSportsJSON.utf8))) ?? []

public let allSportsBySlug: [String: SportInfo] =
    Dictionary(uniqueKeysWithValues: allSports.map { ($0.slug, $0) })
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

function genAnatomySwift(anatomy) {
  const entries = Object.entries(anatomy.muscles)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${swiftStringLiteral(k)}: ${swiftStringLiteral(v)}`);
  const details = (view) => swiftArray(anatomy.details[view].map(swiftStringLiteral));
  const h = anatomy.head;
  return `${generatedHeader('content/src/anatomy.js')}import Foundation

/// §9 job 1: the anatomical mannequin every muscle map draws — an athletic
/// figure in a relaxed A-pose, authored as smooth spline data in
/// content/src/anatomy.js (never traced or imported art). One path string per
/// "muscle-slug.view.side" key, SVG commands M/C/Z only, in a
/// fixed 100 x 200 canonical space; rendered with SVGPathParser + Canvas, so
/// it works unchanged on watchOS.
public let muscleMapPaths: [String: String] = ${swiftDict(entries)}

/// The whole-body silhouette (both views share it).
public let anatomyOutlinePath = ${swiftStringLiteral(anatomy.outline)}

/// The head, drawn as an ellipse over the neck.
public let anatomyHead = (cx: ${swiftDoubleLiteral(h.cx)}, cy: ${swiftDoubleLiteral(h.cy)}, rx: ${swiftDoubleLiteral(h.rx)}, ry: ${swiftDoubleLiteral(h.ry)})

/// Surface definition lines (clavicles, linea alba, kneecaps, spine...), open strokes.
public let anatomyDetailPathsFront: [String] = ${details('front')}
public let anatomyDetailPathsBack: [String] = ${details('back')}

public let muscleMapCanonicalWidth: Double = 100
public let muscleMapCanonicalHeight: Double = 200
`;
}



function genPosePatternsSwift() {
  const jointCases = JOINTS.map((j) => `    case ${j} = ${swiftStringLiteral(j)}`).join('\n');
  const r3 = (v) => Math.round((v ?? 0) * 1000) / 1000;

  // The data ships as JSON inside a raw string and is decoded once at
  // launch: a Swift array literal this size makes the type checker run out
  // of memory, a string literal costs nothing to compile.
  const patterns = POSE_PATTERNS.map((p) => ({
    id: p.slug, name: p.name, view: p.view ?? 'side', loops: !!p.loop, thumb: p.thumb ?? 0,
    fixture: p.fixture ? {
      kind: p.fixture.kind,
      params: Object.fromEntries(Object.entries(p.fixture).filter(([k, v]) => k !== 'kind' && typeof v === 'number').map(([k, v]) => [k, r3(v)])),
      under: typeof p.fixture.under === 'string' ? p.fixture.under : null,
    } : null,
    implement: p.implement ? {
      kind: p.implement.kind, at: p.implement.at ?? 'hands', to: p.implement.to ? p.implement.to.map(r3) : null,
      flags: Object.entries(p.implement).filter(([, v]) => v === true).map(([k]) => k),
      numbers: Object.fromEntries(Object.entries(p.implement).filter(([, v]) => typeof v === 'number').map(([k, v]) => [k, r3(v)])),
    } : null,
    ball: p.ball ? { r: r3(p.ball.r ?? 6), color: p.ball.color ?? 'red', shape: p.ball.shape ?? null } : null,
    prosthetic: p.prosthetic ?? null,
    cast: p.cast ? p.cast.map((c) => ({ pattern: c.pattern, at: [r3(c.at?.[0] ?? 0), r3(c.at?.[1] ?? 0)], facing: r3(c.facing ?? 0), phase: r3(c.phase ?? 0), follow: !!c.follow, tether: !!c.tether })) : null,
    path: p.path ? { kind: p.path.kind, length: p.path.length ?? null, radius: p.path.radius ?? null, angle: p.path.angle ?? null, grade: p.path.grade ?? null, turn: p.path.turn ?? null, dir: p.path.dir ?? null, speed: p.path.speed ?? null } : null,
    keyframes: p.keyframes.map((k) => ({
      angles: JOINTS.map((j) => r3(k.pose[j])), contact: k.contact, hold: r3(k.hold ?? 0), move: r3(k.move ?? 0.6),
      surface: r3(k.surface ?? 0), travel: [r3(k.travel?.[0] ?? 0), r3(k.travel?.[1] ?? 0)], chain: k.chain ?? [0, 1],
      ball: k.ball == null ? null
        : typeof k.ball === 'string' ? { kind: k.ball }
        : k.ball.floor ? { kind: 'floor', side: k.ball.floor, dx: r3(k.ball.dx ?? 0), dl: r3(k.ball.dl ?? 0) }
        : { kind: 'at', at: k.ball.at.map(r3) },
      ballArc: r3(k.ballArc ?? 0),
    })),
  }));

  // Golden samples: where rig3d.js puts key points, for the Swift parity test.
  const samples = [];
  for (const p of [...POSE_PATTERNS.slice(0, 12), ...POSE_PATTERNS.filter((x) => x.ball).slice(0, 6)]) {
    const placed = placeKeyframes(p);
    for (const t of [0, 0.37, 0.71]) {
      const s = frameAt(p, t, placed);
      samples.push({ pattern: p.slug, t, points: [s.pelvis, s.head, s.L.ankle, s.R.toe, s.L.wrist, s.R.elbow, s.L.knee].flat().map(r3), ball: s.ball ? s.ball.map(r3) : null });
    }
  }
  for (const p of POSE_PATTERNS.filter((x) => x.path).slice(0, 4)) {
    const placed = placeKeyframes(p);
    const total = pathSeconds(p, placed);
    for (const f of [0.1, 0.45, 0.8]) {
      const s = frameAtTime(p, f * total, placed);
      samples.push({ pattern: p.slug, t: r3(f * total), time: true, points: [s.pelvis, s.head, s.L.ankle, s.R.toe, s.L.wrist, s.R.elbow, s.L.knee].flat().map(r3), ball: s.ball ? s.ball.map(r3) : null });
    }
  }
  for (const p of POSE_PATTERNS.filter((x) => x.cast).slice(0, 4)) {
    const placed = placeKeyframes(p);
    const total = pathSeconds(p, placed);
    for (const f of [0.2, 0.6]) {
      const s = frameAtTime(p, f * total, placed);
      const m = s.cast[0].s;
      samples.push({ pattern: p.slug, t: r3(f * total), time: true, points: [s.pelvis, s.head, s.L.ankle, s.R.toe, s.L.wrist, m.pelvis, m.head].flat().map(r3), ball: s.ball ? s.ball.map(r3) : null, cast: true });
    }
  }
  const json = (v) => JSON.stringify(v);
  if (json(patterns).includes('"#')) throw new Error('pose JSON would break the raw string literal');
  // Every item's pattern, compiled into the app so packs downloaded before a
  // pose change (which name older patterns) still animate correctly.
  const itemPoses = Object.fromEntries(CATALOGUE.map((i) => [i.slug, i.startPose]));

  return `${generatedHeader('content/src/poses.js')}import Foundation

public let poseModelVersion = ${POSE_MODEL_VERSION}

/// The rig's joints (§9 job 2) — see content/src/rig3d.js for every convention.
public enum Joint: String, CaseIterable, Codable, Sendable, Hashable {
${jointCases}
}

public typealias Pose = [Joint: Double]

/// One keyframe of a movement: joint angles in \`Joint.allCases\` order.
public struct PoseKeyframe: Sendable, Hashable, Codable {
    public let angles: [Double]
    public let contact: String
    public let hold: Double
    public let move: Double
    public let surface: Double
    public let travel: [Double]
    public let chain: [Int]
    /// Where the ball is at this keyframe (nil → in both hands).
    public let ball: PoseBall?
    /// Height of the arc the ball flies on when it leaves this keyframe.
    public let ballArc: Double

    public var pose: Pose {
        var out: Pose = [:]
        for (index, joint) in Joint.allCases.enumerated() { out[joint] = angles[index] }
        return out
    }
}

/// A keyframe's ball: kind is a hand/foot ('L', 'R', 'hands', 'Ldown', 'Rdown',
/// 'footL', 'footR'), 'floor' (under a hand), 'at' (a point from the pelvis) or 'none'.
public struct PoseBall: Sendable, Hashable, Codable {
    public let kind: String
    public let side: String?
    public let dx: Double?
    public let dl: Double?
    public let at: [Double]?
}

/// Another person in the drill (partner, passer, defender): they play
/// \`pattern\` in step with the athlete, standing at \`at\` (forward, left in
/// the athlete's axes), turned \`facing\` degrees, shifted \`phase\` of a cycle.
public struct RigCastSpec: Sendable, Hashable, Codable {
    public let pattern: String
    public let at: [Double]
    public let facing: Double
    public let phase: Double
    public let follow: Bool
    /// A guide runner's tether between the athlete's left hand and theirs.
    public let tether: Bool
}

/// A travelling drill's path through the scene (see rig3d.js pathAt).
public struct RigPathSpec: Sendable, Hashable, Codable {
    /// Degrees of arc for an 'arc' path.
    public let angle: Double?
    /// Rise per unit along a line path (a hill; negative runs downhill).
    public let grade: Double?
    public let kind: String
    public let length: Double?
    public let radius: Double?
    public let turn: Double?
    public let dir: String?
    public let speed: Double?
}

/// The ball a pattern uses: radius and colour name.
public struct RigBallSpec: Sendable, Hashable, Codable {
    public let r: Double
    public let color: String
    /// "baton" for a relay baton; nil for a ball.
    public let shape: String?
}

/// A fixed object in the scene (bench, bar, box, bike…); numbers as in poses.js.
public struct RigFixtureSpec: Sendable, Hashable, Codable {
    public let kind: String
    public let params: [String: Double]
    public let under: String?
}

/// Equipment held or worn (barbell, racket, ball…).
public struct RigImplementSpec: Sendable, Hashable, Codable {
    public let kind: String
    public let at: String
    public let to: [Double]?
    /// Switches such as "puck" (draw a puck at the blade) or "ball".
    public let flags: [String]
    public let numbers: [String: Double]
}

public struct PosePatternInfo: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let view: String
    /// A continuous rhythm that wraps last → first; otherwise one rep that cuts back to the start.
    public let loops: Bool
    /// Keyframe shown as the still thumbnail.
    public let thumb: Int
    public let fixture: RigFixtureSpec?
    public let implement: RigImplementSpec?
    public let ball: RigBallSpec?
    public let path: RigPathSpec?
    public let cast: [RigCastSpec]?
    /// "L" / "R": that leg is a below-knee running blade.
    public let prosthetic: String?
    public let keyframes: [PoseKeyframe]

    public var start: Pose { keyframes[0].pose }
    public var end: Pose { keyframes[min(thumb, keyframes.count - 1)].pose }
}

/// Every movement the catalogue animates; each item names exactly one.
public let posePatterns: [PosePatternInfo] = {
    do {
        return try JSONDecoder().decode([PosePatternInfo].self, from: Data(posePatternsJSON.utf8))
    } catch {
        assertionFailure("pose data failed to decode: \\(error)")
        return []
    }
}()

public let posePatternsBySlug: [String: PosePatternInfo] =
    Dictionary(uniqueKeysWithValues: posePatterns.map { ($0.id, $0) })

/// Reference joint positions computed by content/src/rig3d.js.
public struct RigGoldenSample: Sendable, Codable {
    public let pattern: String
    public let t: Double
    /// pelvis, head, L ankle, R toe, L wrist, R elbow, L knee — x, y, z each.
    public let points: [Double]
    /// The ball's centre, when the pattern has a ball in play at t.
    public let ball: [Double]?
    /// True when t is seconds of real time along a path (not a cycle fraction).
    public let time: Bool?
    /// True when the last two points are the first cast member's pelvis and head.
    public let cast: Bool?
}

public let rigGoldenSamples: [RigGoldenSample] =
    (try? JSONDecoder().decode([RigGoldenSample].self, from: Data(rigGoldenSamplesJSON.utf8))) ?? []

/// Swaps every left/right joint pair.
public func mirrorPose(_ pose: Pose) -> Pose {
    var mirrored: Pose = [:]
    for joint in Joint.allCases {
        let name = joint.rawValue
        if name.hasSuffix("L"), let other = Joint(rawValue: String(name.dropLast()) + "R") {
            mirrored[joint] = pose[other]
        } else if name.hasSuffix("R"), let other = Joint(rawValue: String(name.dropLast()) + "L") {
            mirrored[joint] = pose[other]
        } else {
            mirrored[joint] = pose[joint]
        }
    }
    return mirrored
}

private let posePatternsJSON = #"${json(patterns)}"#

private let rigGoldenSamplesJSON = #"${json(samples)}"#

/// Item slug → its movement pattern, as of this build of the app.
public let posePatternForItem: [String: String] =
    (try? JSONDecoder().decode([String: String].self, from: Data(itemPosesJSON.utf8))) ?? [:]

/// Older pattern names (from packs downloaded before the 3D rig) → today's.
public let legacyPosePatterns: [String: String] =
    (try? JSONDecoder().decode([String: String].self, from: Data(legacyPosesJSON.utf8))) ?? [:]

private let itemPosesJSON = #"${json(itemPoses)}"#

private let legacyPosesJSON = #"${json(INTERIM_BY_POSE)}"#
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
  writeFile(path.join(SWIFT_OUT, 'Equipment.swift'), genEquipmentSwift());
  writeFile(path.join(SWIFT_OUT, 'AllSports.swift'), genAllSportsSwift());
  writeFile(path.join(SWIFT_OUT, 'Muscles.swift'), genMusclesSwift());
  writeFile(path.join(SWIFT_OUT, 'MuscleMapPaths.swift'), genAnatomySwift(buildAnatomy()));
  writeFile(path.join(SWIFT_OUT, 'PosePatterns.swift'), genPosePatternsSwift());
  writeFile(path.join(SWIFT_OUT, 'Props.swift'), genPropsSwift());

  buildPacks();
}

main();
