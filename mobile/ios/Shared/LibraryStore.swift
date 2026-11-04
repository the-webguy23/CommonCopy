import Foundation

/// Coordinated directory writes serialize app and Share-extension changes.
/// The keyboard only reads and does not require Full Access or network access.
final class LibraryStore {
    private let groupID: String
    init() { groupID = Bundle.main.object(forInfoDictionaryKey: "CommonCopyAppGroup") as? String ?? "" }
    private func container() throws -> URL {
        guard !groupID.isEmpty, let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { throw LibraryError.invalid("The shared library is unavailable. Check the App Group in Signing & Capabilities.") }
        return url
    }
    func load() throws -> LibraryDocument {
        let file = try container().appendingPathComponent("phrases.json")
        // The keyboard has read-only container access. Avoid coordinating the
        // directory itself, which fails in its restricted sandbox. Writers
        // replace this file atomically, so a reader sees one complete snapshot.
        do { return try LibraryDocument(data: Data(contentsOf: file)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            throw LibraryError.invalid("Open CommonCopy once to set up your library.")
        }
    }
    func update(_ change: (inout LibraryDocument) throws -> Void) throws {
        let root = try container(); var result: Result<Void, Error> = .failure(LibraryError.invalid("Couldn't save your library.")); var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: root, options: .forMerging, error: &coordinationError) { url in
            result = Result {
                let file = url.appendingPathComponent("phrases.json"); let exists = FileManager.default.fileExists(atPath: file.path)
                let previous = exists ? try Data(contentsOf: file) : nil
                var library = try previous.map { try LibraryDocument(data: $0) } ?? LibraryDocument()
                try change(&library); let data = try library.data()
                if let previous { try previous.write(to: url.appendingPathComponent("phrases.previous.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
                try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
        if let error = coordinationError { throw error }; try result.get()
    }
    func initialize() throws { if (try? load()) != nil { return }; try update { _ in } }
    func replace(data: Data) throws { let imported = try LibraryDocument(data: data); try update { $0 = imported } }
}
