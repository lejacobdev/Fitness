import Foundation
import SwiftData

/// One place both the phone and Watch app entry points configure their
/// `ModelContainer` from, so the two can never silently drift into
/// incompatible schemas (they already share `athleteModelTypes` for the
/// same reason). Each device keeps its own local store — §16: "The Watch
/// keeps the current session's plan and every logged set locally," synced
/// through the backend (§3), not shared directly between devices via the
/// App Group; the App Group is for the widget/complication's much smaller
/// read-only snapshot (§16), never the full relational graph.
public enum AthleteStore {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(athleteModelTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
