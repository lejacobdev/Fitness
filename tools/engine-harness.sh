#!/bin/sh
# Compile and test the Foundation-only parts of the app (the V6 workout
# engine, reflection insights, Campus content) on Linux with Docker, without
# waiting for CI. Needs Docker and a built content/dist (cd content && npm run build).
#
#   tools/engine-harness.sh [dir]        # default dir: /tmp/aos-engine-harness
#
# The app's own files are linked, not copied; a few app-only pieces are
# stubbed (SwiftData's Dose, PainArea, EveningSignal, the knowledge quarantine).
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO/app/Shared/Sources"
TESTS="$REPO/app/StudentAthleteTests/Sources"
H=${1:-/tmp/aos-engine-harness}
rm -rf "$H"
mkdir -p "$H/Sources/Engine" "$H/Tests/EngineTests"

for f in CatalogueModels ExerciseProfile SportDemands WorkoutEngine ConditioningEngine SessionBuilder PlanExplanation \
         PlanGenerator SeasonPhase TrainingExperience SeededGenerator Mindset ReflectionInsight \
         CampusContent CampusQuiz CampusLibrary CampusLessonsSupplements CampusLessonsDigital CampusLessonsPsychology \
         CampusLessonsTraining CampusLessonsAnatomy CampusLessonsNutrition CampusLessonsSleep CampusLessonsSelfCoaching \
         Generated/Qualities Generated/Equipment Generated/AllSports; do
  ln -s "$SRC/$f.swift" "$H/Sources/Engine/$(basename "$f").swift"
done
# App-only lines stripped.
grep -v "KnowledgeReleaseStore" "$SRC/CatalogueStore.swift" > "$H/Sources/Engine/CatalogueStore.swift"
awk '/^\/\/\/ Today.s workouts with today.s pain/{exit} {print}' "$SRC/PainFilter.swift" > "$H/Sources/Engine/PainFilter.swift"
{ echo "import Foundation"; awk '/^public enum LessonPicker/,/^}/' "$SRC/CampusToday.swift"; } > "$H/Sources/Engine/LessonPicker.swift"
{
  echo "import Foundation"
  awk '/^public enum PainArea/,/^}/' "$SRC/DailyLoop.swift"
  awk '/^public struct EveningSignal/,/^}/' "$SRC/DailyLoop.swift"
  awk '/^public struct Dose: Codable/,/^}/' "$SRC/AthleteModels.swift"
} > "$H/Sources/Engine/Shims.swift"

for t in WorkoutEngineTests ReflectionInsightTests CampusLessonTests; do
  ln -s "$TESTS/$t.swift" "$H/Tests/EngineTests/$t.swift"
done

cat > "$H/Package.swift" <<'EOF'
// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "Engine", targets: [
  .target(name: "Engine", path: "Sources/Engine", swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])]),
  .testTarget(name: "EngineTests", dependencies: ["Engine"], path: "Tests/EngineTests"),
])
EOF

docker run --rm -v "$H:/w" -v "$REPO:$REPO:ro" -e AOS_CONTENT_DIST="$REPO/content/dist" -w /w swift:6.0 swift test 2>&1 \
  | grep -E "error:|failed|Executed .* tests" | sort -u
