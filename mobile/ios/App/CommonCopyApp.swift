import SwiftUI
import UIKit
import UniformTypeIdentifiers

@main struct CommonCopyApp: App {
    var body: some Scene { WindowGroup { LibraryView() } }
}
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct LibraryView: View {
    let store = LibraryStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var library: LibraryDocument?
    @State private var query = ""
    @State private var filter = "all"
    @State private var editing: Phrase?
    @State private var addPhrase = false
    @State private var addCategory = false
    @State private var showSetup = false
    @State private var confirmImport = false
    @State private var importing = false
    @State private var exporting = false
    @State private var exportFile = ExportFile(data: Data())
    @State private var deleting: Phrase?
    @State private var message = ""
    var body: some View {
        NavigationStack {
            List {
                Section { Text("Save it once. Paste it forever.").foregroundStyle(.secondary)
                    Picker("Category", selection: $filter) {
                        Text("All phrases").tag("all"); Text("Favourites").tag("favourites"); Text("Commonly Used").tag("common")
                        if let library { ForEach(library.categories) { c in Text(library.categoryPath(c.id)).tag(c.id) } }
                    }
                }
                if let library {
                    let phrases = library.visible(filter: filter, query: query)
                    if phrases.isEmpty { Text("No phrases here yet. Add one or import your library.").foregroundStyle(.secondary) }
                    ForEach(phrases) { phrase in
                        VStack(alignment: .leading, spacing: 8) {
                            Text((phrase.favorite ? "★ " : "") + phrase.title).font(.headline)
                            Text(phrase.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                            HStack { Button("Copy") { copy(phrase) }; Spacer(); Button("Edit") { editing = phrase } }.buttonStyle(.borderless)
                        }.padding(.vertical, 8)
                        .swipeActions { Button("Delete", role: .destructive) { deleting = phrase } }
                    }
                } else { Text("Your library is unavailable. Your saved file has been kept.") }
            }
            .searchable(text: $query, prompt: "Search phrases")
            .navigationTitle("CommonCopy")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button { addPhrase = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add phrase").disabled(library == nil) }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Add category") { addCategory = true }
                        Button("Import library…") { confirmImport = true }
                        Button("Export library…") { export() }
                        Button("Keyboard & saving text") { showSetup = true }
                    } label: { Image(systemName: "line.3.horizontal") }.accessibilityLabel("Library options")
                }
            }
            .sheet(isPresented: $addPhrase) { PhraseEditor(store: store, phrase: nil, onSaved: reload) }
            .sheet(item: $editing) { phrase in PhraseEditor(store: store, phrase: phrase, onSaved: reload) }
            .sheet(isPresented: $addCategory) { CategoryEditor(store: store, onSaved: reload) }
            .sheet(isPresented: $showSetup) { SetupView() }
            .confirmationDialog("Import replaces this device's library. Export a backup first. The previous library is also kept locally.", isPresented: $confirmImport, titleVisibility: .visible) { Button("Choose library file") { importing = true } }
            .confirmationDialog("Delete this phrase?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if let phrase = deleting { do { try store.update { $0.remove(id: phrase.id) }; reload() } catch { message = error.localizedDescription } }; deleting = nil }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }; let data = try Data(contentsOf: url); try store.replace(data: data); filter = "all"; reload() }
                catch { message = error.localizedDescription }
            }
            .fileExporter(isPresented: $exporting, document: exportFile, contentType: .json, defaultFilename: "CommonCopy-library") { result in if case .failure(let error) = result { message = error.localizedDescription } }
            .alert("CommonCopy", isPresented: Binding(get: { !message.isEmpty }, set: { if !$0 { message = "" } })) { Button("OK") { message = "" } } message: { Text(message) }
            .task { do { try store.initialize(); reload() } catch { message = error.localizedDescription } }
            .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
        }.tint(.primary)
    }
    private func reload() { do { library = try store.load() } catch { message = error.localizedDescription } }
    private func copy(_ phrase: Phrase) { UIPasteboard.general.string = phrase.text; do { try store.update { $0.used(id: phrase.id) }; reload() } catch { message = "Copied, but the usage count could not be saved." } }
    private func export() { do { exportFile = ExportFile(data: try store.load().data()); exporting = true } catch { message = error.localizedDescription } }
}
struct CategoryEditor: View {
    let store: LibraryStore
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var library: LibraryDocument?
    @State private var name = ""
    @State private var parent = ""
    @State private var error = ""
    var body: some View {
        NavigationStack {
            Form { TextField("Category name", text: $name)
                Picker("Parent", selection: $parent) { Text("No parent").tag(""); if let library { ForEach(library.categories) { c in Text(library.categoryPath(c.id)).tag(c.id) } } }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Add category")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { do { try store.update { try $0.addCategory(name: name, parentID: parent.isEmpty ? nil : parent) }; onSaved(); dismiss() } catch { self.error = error.localizedDescription } } } }
            .onAppear { do { library = try store.load() } catch { self.error = error.localizedDescription } }
        }
    }
}
struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List {
        Section("Insert your phrases") { Text("In iPhone Settings, open General → Keyboard → Keyboards → Add New Keyboard → CommonCopy. When typing, use the globe key to switch to CommonCopy, then choose a category and phrase.")
            Text("CommonCopy is a phrase panel, not a full typing keyboard. Use Next keyboard to return to your regular keyboard. Some apps and secure fields don't support third-party keyboards.")
            Text("Full Access is not required. The keyboard reads your local library and never sends text over the network. Usage counts are updated when copying in the app; keyboard insertions do not change them.") }
        Section("Save selected text") { Text("Highlight text in an app that supports sharing, choose Share, then CommonCopy. Enter a title and category and tap Save. If CommonCopy isn't visible, check More in the share sheet.") }
        Section("Your library") { Text("Your words stay on this device. Use JSON import and export to transfer a desktop library. There is no automatic sync. Keep passwords and other secrets in a password manager.") }
    }.navigationTitle("A little help. Right here.").toolbar { Button("Done") { dismiss() } } } }
}
