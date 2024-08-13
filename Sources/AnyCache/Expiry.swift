import Foundation

public enum Expiry {
    case never
    case seconds(TimeInterval)
    case date(Date)

    public var date: Date {
        switch self {
        case .never:
            return Date(timeIntervalSince1970: TimeInterval(Int32.max))
        case .seconds(let seconds):
            return Date().addingTimeInterval(seconds)
        case .date(let date):
            return date
        }
    }

    public var isExpired: Bool {
        return date.timeIntervalSinceNow < 0
    }

    init(from date: Date) {
        if date == Date(timeIntervalSince1970: TimeInterval(Int32.max)) {
            self = .never
        } else {
            self = .date(date)
        }
    }
}
