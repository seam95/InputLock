import Combine
import Foundation

final class LanguageManager: ObservableObject {
    @Published private(set) var preferredLanguage: String? {
        didSet {
            updateBundle()
        }
    }

    private let userDefaults: UserDefaults
    private var bundle: Bundle = .main

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.preferredLanguage = userDefaults.string(forKey: UserDefaultsKeys.preferredLanguage)
        updateBundle()
    }

    func setPreferredLanguage(_ code: String?) {
        preferredLanguage = code
        if let code {
            userDefaults.set(code, forKey: UserDefaultsKeys.preferredLanguage)
        } else {
            userDefaults.removeObject(forKey: UserDefaultsKeys.preferredLanguage)
        }
    }

    func localized(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private func updateBundle() {
        if let code = preferredLanguage,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
    }
}
