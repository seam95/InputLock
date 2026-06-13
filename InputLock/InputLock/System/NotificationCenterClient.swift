import Foundation

protocol NotificationCenterClient {
    @discardableResult
    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject

    func post(name: Notification.Name)
}

extension Notification.Name {
    static let tisSelectedKeyboardInputSourceChanged = Notification.Name(
        "com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"
    )
}

final class DistributedNotificationCenterAdapter: NotificationCenterClient {
    func addObserver(forName name: Notification.Name, using block: @escaping () -> Void) -> AnyObject {
        let center = DistributedNotificationCenter.default()
        return center.addObserver(forName: name, object: nil, queue: .main) { _ in
            block()
        } as AnyObject
    }

    func post(name: Notification.Name) {
        DistributedNotificationCenter.default().post(name: name, object: nil)
    }
}
