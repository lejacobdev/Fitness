import XCTest
#if canImport(Engine)
@testable import Engine
#endif

/// Every Campus lesson reads the same way: a hook, the explanation, an
/// athlete's example, then what it means for you, then the quiz.
final class CampusLessonTests: XCTestCase {
    func testEveryLessonHasHookExplanationExampleAndMeaning() {
        let lessons = campusTopics.flatMap(\.lessons)
        XCTAssertGreaterThanOrEqual(lessons.count, 90, "V6: a real education system")
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count, "lesson ids are unique")
        for lesson in lessons {
            let teach = lesson.steps.compactMap { step -> CampusSection? in
                if case .teach(let section) = step { return section } else { return nil }
            }
            XCTAssertGreaterThanOrEqual(teach.count, 4, lesson.id)
            if let hook = campusHooks[lesson.id] {
                XCTAssertEqual(teach.first?.heading, hook.0, "\(lesson.id) opens with its hook")
            }
            XCTAssertFalse(lesson.questions.isEmpty, "\(lesson.id) has a quiz")
            XCTAssertEqual(lesson.takeaways.count, 3, lesson.id)
            XCTAssertEqual(teach.dropLast().last?.heading, CampusLesson.exampleHeading, "\(lesson.id) has an example before the meaning")
            XCTAssertEqual(teach.last?.heading, CampusLesson.meansForYouHeading, lesson.id)
        }
    }
}

/// The lesson that fits the day.
final class LessonPickerTests: XCTestCase {
    func testTheDayPicksTheLesson() {
        XCTAssertEqual(LessonPicker.forToday(.init(sleepHours: 5.5))?.id, "sleep-power")
        XCTAssertEqual(LessonPicker.forToday(.init(daysToGame: 1))?.id, "pressure")
        XCTAssertEqual(LessonPicker.forToday(.init(sleepHours: 5.5, pain: true))?.id, "pain", "pain comes first")
        XCTAssertEqual(LessonPicker.forToday(.init(examWeek: true))?.id, "balance")
        XCTAssertNil(LessonPicker.forToday(.init(sleepHours: 8, soreness: 2, energy: 4, daysToGame: 5)), "an ordinary day follows the path")
        // V6 §16: the athlete's real situation picks the lesson.
        XCTAssertEqual(LessonPicker.forToday(.init(gameYesterday: true))?.id, "sr-after-games")
        XCTAssertEqual(LessonPicker.forToday(.init(shortNights: 3))?.id, "dg-sleep")
        XCTAssertEqual(LessonPicker.forToday(.init(trainingToday: ["power"]))?.id, "ts-power")
        XCTAssertEqual(LessonPicker.forToday(.init(lowConfidence: true))?.id, "confidence")
        XCTAssertEqual(LessonPicker.forToday(.init(daysToGame: 1, learned: ["pressure"]))?.id, "ps-routines", "the next useful one once learned")
        XCTAssertNil(LessonPicker.forToday(.init(trainingToday: ["power"], learned: ["ts-power"])), "nothing new to say: the path takes over")
        for id in ["pain", "sleep-power", "pressure", "rest-days", "overtraining", "balance", "su-creatine", "dg-sleep", "ps-focus"] {
            XCTAssertNotNil(LessonPicker.lesson(id), "\(id) exists")
        }
    }
}

/// V6 Campus: categories, levels, and supplements taught as education only.
final class CampusLibraryTests: XCTestCase {
    func testEveryCategoryHasFoundationsFirst() {
        for topic in campusTopics {
            XCTAssertFalse(topic.lessons.isEmpty, topic.id)
            let levels = topic.lessons.map { CampusLibrary.level(of: $0.id) }
            XCTAssertEqual(levels, levels.sorted(), "\(topic.id) runs from foundations up")
        }
        XCTAssertTrue(campusTopics.contains { $0.id == "supplements" })
        XCTAssertTrue(campusTopics.contains { $0.id == "digital" })
    }

    func testSupplementLessonsNeverTellAnAthleteToTakeSomething() {
        let supplements = campusTopics.first { $0.id == "supplements" }?.lessons ?? []
        XCTAssertGreaterThanOrEqual(supplements.count, 10)
        for lesson in supplements {
            let text = (lesson.sections.map(\.body) + lesson.takeaways).joined(separator: " ").lowercased()
            for phrase in ["you should take", "take this", "recommended dose", "grams per day", "mg per"] {
                XCTAssertFalse(text.contains(phrase), "\(lesson.id): “\(phrase)”")
            }
        }
    }

    func testContextualTagsPointAtRealLessons() {
        for tag in ["sleep", "game", "creatine", "phone-sleep", "confidence", "power", "after-game"] {
            XCTAssertFalse(CampusLibrary.lessons(tagged: tag).isEmpty, tag)
        }
    }
}
