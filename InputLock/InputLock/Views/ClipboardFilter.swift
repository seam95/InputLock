import Foundation

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image
    case file
    case url
    case rtf

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .all:
            return "clipboard.filter.all"
        case .text:
            return "clipboard.filter.text"
        case .image:
            return "clipboard.filter.image"
        case .file:
            return "clipboard.filter.file"
        case .url:
            return "clipboard.filter.url"
        case .rtf:
            return "clipboard.filter.rtf"
        }
    }

    func matches(_ type: ClipboardContentType) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return type == .text
        case .image:
            return type == .image
        case .file:
            return type == .file
        case .url:
            return type == .url
        case .rtf:
            return type == .rtf
        }
    }
}

