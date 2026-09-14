import Foundation

/// Content that can occupy either the primary or secondary slot of a key.
enum KeyContent: Codable, Equatable {
    case text(String)
    case image(Data)

    var isEmpty: Bool {
        switch self {
        case .text(let str): return str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let data): return data.isEmpty
        }
    }
}
