import Foundation

class Debouncer {
    private let queue = DispatchQueue.main
    private var workItem = DispatchWorkItem(block: {})
    private var interval: TimeInterval

    init(seconds: TimeInterval) {
        self.interval = seconds
    }

    func debounce(action: @escaping (() -> Void)) {
        workItem.cancel()
        workItem = DispatchWorkItem(block: { action() })
        queue.asyncAfter(deadline: .now() + interval, execute: workItem)
    }
}
