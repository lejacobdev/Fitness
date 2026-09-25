import Foundation

/// The quote Home opens on each day: one from an athlete or coach, the same
/// all day, a different one tomorrow.
public struct DailyQuote: Sendable, Hashable {
    public let text: String
    public let author: String
    public let who: String
}

public enum DailyQuotes {
    public static let all: [DailyQuote] = [
        DailyQuote(text: "I've failed over and over and over again in my life. And that is why I succeed.", author: "Michael Jordan", who: "Basketball"),
        DailyQuote(text: "You miss 100% of the shots you don't take.", author: "Wayne Gretzky", who: "Ice hockey"),
        DailyQuote(text: "Champions keep playing until they get it right.", author: "Billie Jean King", who: "Tennis"),
        DailyQuote(text: "Pressure is a privilege.", author: "Billie Jean King", who: "Tennis"),
        DailyQuote(text: "The more difficult the victory, the greater the happiness in winning.", author: "Pelé", who: "Soccer"),
        DailyQuote(text: "Success is no accident. It is hard work, perseverance, learning, studying, sacrifice and most of all, love of what you are doing.", author: "Pelé", who: "Soccer"),
        DailyQuote(text: "Hard work beats talent when talent doesn't work hard.", author: "Tim Notke", who: "High-school coach"),
        DailyQuote(text: "It's not whether you get knocked down; it's whether you get up.", author: "Vince Lombardi", who: "Football coach"),
        DailyQuote(text: "Don't quit. Suffer now and live the rest of your life as a champion.", author: "Muhammad Ali", who: "Boxing"),
        DailyQuote(text: "Don't count the days, make the days count.", author: "Muhammad Ali", who: "Boxing"),
        DailyQuote(text: "It isn't the mountains ahead to climb that wear you out; it's the pebble in your shoe.", author: "Muhammad Ali", who: "Boxing"),
        DailyQuote(text: "Age is no barrier. It's a limitation you put on your mind.", author: "Jackie Joyner-Kersee", who: "Track & field"),
        DailyQuote(text: "You can't put a limit on anything. The more you dream, the farther you get.", author: "Michael Phelps", who: "Swimming"),
        DailyQuote(text: "Excellence is the gradual result of always striving to do better.", author: "Pat Riley", who: "Basketball coach"),
        DailyQuote(text: "Talent wins games, but teamwork and intelligence win championships.", author: "Michael Jordan", who: "Basketball"),
        DailyQuote(text: "Obstacles don't have to stop you. If you run into a wall, don't turn around and give up. Figure out how to climb it, go through it, or work around it.", author: "Michael Jordan", who: "Basketball"),
        DailyQuote(text: "Make each day your masterpiece.", author: "John Wooden", who: "Basketball coach"),
        DailyQuote(text: "Don't let what you cannot do interfere with what you can do.", author: "John Wooden", who: "Basketball coach"),
        DailyQuote(text: "A champion is someone who gets up when he can't.", author: "Jack Dempsey", who: "Boxing"),
        DailyQuote(text: "Nobody who ever gave his best regretted it.", author: "George Halas", who: "Football coach"),
        DailyQuote(text: "The will to win is important, but the will to prepare is vital.", author: "Joe Paterno", who: "Football coach"),
        DailyQuote(text: "Just keep going. Everybody gets better if they keep at it.", author: "Ted Williams", who: "Baseball"),
        DailyQuote(text: "Set your goals high, and don't stop till you get there.", author: "Bo Jackson", who: "Football & baseball"),
        DailyQuote(text: "I really think a champion is defined not by their wins but by how they can recover when they fall.", author: "Serena Williams", who: "Tennis"),
        DailyQuote(text: "Gold medals aren't really made of gold. They're made of sweat, determination, and a hard-to-find alloy called guts.", author: "Dan Gable", who: "Wrestling"),
        DailyQuote(text: "The reward is not so great without the struggle.", author: "Wilma Rudolph", who: "Track & field"),
        DailyQuote(text: "Champions aren't made in gyms. Champions are made from something they have deep inside them — a desire, a dream, a vision.", author: "Muhammad Ali", who: "Boxing"),
        DailyQuote(text: "Always work hard, never give up, and fight until the end because it's never really over until the whistle blows.", author: "Alex Morgan", who: "Soccer"),
        DailyQuote(text: "Hard days are the best because that's when champions are made.", author: "Gabby Douglas", who: "Gymnastics"),
        DailyQuote(text: "Some people want it to happen, some wish it would happen, others make it happen.", author: "Michael Jordan", who: "Basketball"),
        DailyQuote(text: "The principle is competing against yourself. It's about self-improvement, about being better than you were the day before.", author: "Steve Young", who: "Football"),
        DailyQuote(text: "The difference between the impossible and the possible lies in a person's determination.", author: "Tommy Lasorda", who: "Baseball"),
        DailyQuote(text: "I've learned that something constructive comes from every defeat.", author: "Tom Landry", who: "Football coach"),
        DailyQuote(text: "Once you learn to quit, it becomes a habit.", author: "Vince Lombardi", who: "Football coach"),
        DailyQuote(text: "Tough times don't last. Tough people do.", author: "Robert H. Schuller", who: "Author"),
        DailyQuote(text: "What you do today can improve all your tomorrows.", author: "Ralph Marston", who: "Author"),
        DailyQuote(text: "Never say never, because limits, like fears, are often just an illusion.", author: "Michael Jordan", who: "Basketball"),
        DailyQuote(text: "You have to expect things of yourself before you can do them.", author: "Michael Jordan", who: "Basketball"),
    ]

    /// Today's quote: the same all day, the next one tomorrow.
    public static func quote(for date: Date = .now, calendar: Calendar = .current) -> DailyQuote {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
