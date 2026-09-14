import Foundation
import Combine

/// Loads/saves the TasselDocument as JSON under
/// ~/Library/Application Support/Tassel/document.json
final class DocumentStore: ObservableObject {
    @Published var document: TasselDocument

    private let fileURL: URL

    init() {
        let supportDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tassel", isDirectory: true)

        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.fileURL = supportDir.appendingPathComponent("document.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(TasselDocument.self, from: data) {
            self.document = decoded
        } else {
            self.document = .empty
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
