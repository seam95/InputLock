import Combine
import Foundation
import ServiceManagement

protocol LaunchAtLoginClient {
    func setEnabled(_ enabled: Bool) throws
}

final class FakeLaunchAtLoginClient: LaunchAtLoginClient {
    private(set) var lastEnabled: Bool?

    func setEnabled(_ enabled: Bool) throws {
        lastEnabled = enabled
    }
}

final class ServiceManagementLaunchAtLoginClient: LaunchAtLoginClient {
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let client: LaunchAtLoginClient
    private let userDefaults: UserDefaults

    init(client: LaunchAtLoginClient, userDefaults: UserDefaults = .standard) {
        self.client = client
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKeys.launchAtLogin)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.launchAtLogin)
        try? client.setEnabled(enabled)
    }
}
