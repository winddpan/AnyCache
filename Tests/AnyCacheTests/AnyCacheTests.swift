@testable import AnyCache
import XCTest

struct Model: Codable {
    var text: String
}

final class AnyCacheTests: XCTestCase {
    let cache = AnyCache(name: "Test")

    var model: Model? {
        didSet {
            try? cache.setObject(model, forKey: "key")
        }
    }

    @available(iOS 13.0.0, *)
    func testExample() async throws {
        func debugModel() {
            print((try? cache.object(forKey: "key", as: Model.self)) ?? "nil")
        }

        let model = Model(text: "1111")

        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)

        self.model = model
        debugModel()

        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)

        self.model = model
        debugModel()

        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)

        self.model = model
        debugModel()

        try await Task.sleep(nanoseconds: NSEC_PER_SEC * 3)

        self.model = nil
        debugModel()
    }
}
