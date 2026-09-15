import Foundation
import Combine

/// Loads/saves the KeyWiiDocument as JSON under
/// ~/Library/Application Support/KeyWii/document.json
final class DocumentStore: ObservableObject {
    @Published var document: KeyWiiDocument

    private let fileURL: URL

    init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyWii", isDirectory: true)

        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("document.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(KeyWiiDocument.self, from: data) {
            self.document = decoded
        } else {
            self.document = .initial
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
