import Foundation

/// Coordinated directory reads/writes serialize app and Share-extension changes.
/// The keyboard only reads and does not require Full Access or network access.
final class LibraryStore {
    private let groupID: String
    init() { groupID = Bundle.main.object(forInfoDictionaryKey: "CommonCopyAppGroup") as? String ?? "" }
    private func container() throws -> URL {
        guard !groupID.isEmpty, let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { throw LibraryError.invalid("The shared library is unavailable. Check the App Group in Signing & Capabilities.") }
        return url
    }
    func load() throws -> LibraryDocument {
        let root = try container(); var result: Result<LibraryDocument, Error> = .failure(LibraryError.invalid("Couldn't read your library.")); var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: root, options: [], error: &coordinationError) { url in
            result = Result { let file = url.appendingPathComponent("phrases.json"); guard FileManager.default.fileExists(atPath: file.path) else { throw LibraryError.invalid("Open CommonCopy once to set up your library.") }; return try LibraryDocument(data: Data(contentsOf: file)) }
        }
        if let error = coordinationError { throw error }; return try result.get()
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
