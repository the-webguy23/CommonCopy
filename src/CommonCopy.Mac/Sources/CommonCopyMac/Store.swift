import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Store: ObservableObject {
    @Published var state: CoreState?
    @Published var selectedCategory = "all"
    @Published var search = ""
    @Published var error: String?
    @Published var busy = false
    private let bridge = CoreBridge()

    var dark: Bool { state?.document.settings.appearance == "Dark" }
    var categories: [CategoryOption] { state?.categoryList ?? [] }
    var phrases: [Phrase] {
        guard let state else { return [] }
        let ids: [String]?
        switch selectedCategory {
        case "all": ids = nil
        case "favourites": ids = state.favourites
        case "common": ids = state.commonlyUsed
        default: ids = state.categoryPhrases[selectedCategory] ?? []
        }
        let byId = Dictionary(uniqueKeysWithValues: state.document.phrases.map { ($0.id, $0) })
        let ordered = ids?.compactMap { byId[$0] } ?? state.document.phrases.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return ordered.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }
    }

    @discardableResult
    func perform(_ operation: String, _ fields: [String: Any] = [:]) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        var request = fields
        request["operation"] = operation
        do {
            state = try await bridge.request(request)
            if !["all", "favourites", "common"].contains(selectedCategory),
               !categories.contains(where: { $0.id == selectedCategory }) { selectedCategory = "all" }
            return true
        } catch {
            // Decoding and file errors are generic; do not display or log content.
            self.error = (error as? CoreError)?.errorDescription ?? "CommonCopy could not read or save the library. Your last saved data remains on disk."
            return false
        }
    }

    func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = "Replace the current phrase library?"
        alert.informativeText = "This imports categories, phrases, and appearance. The current library is backed up first."
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await perform("import", ["path": url.path]) }
    }

    func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "CommonCopy-library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await perform("export", ["path": url.path]) }
    }
}
