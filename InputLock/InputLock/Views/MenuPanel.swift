import Foundation

enum MenuPanel: String, CaseIterable, Identifiable {
    case inputLock
    case clipboard

    var id: String {
        rawValue
    }
}
