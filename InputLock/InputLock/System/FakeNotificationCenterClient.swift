import Foundation

final class FakeNotificationCenterClient: NotificationCenterClient {
    private var observers: [Notification.Name: [() -> Void]] = [:]

    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject {
        observers[name, default: []].append(block)
        return NSObject()
    }

    func post(name: Notification.Name) {
        observers[name, default: []].forEach { $0() }
    }
}
