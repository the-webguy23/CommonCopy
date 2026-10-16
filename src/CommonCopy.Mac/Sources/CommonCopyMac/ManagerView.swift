import AppKit
import SwiftUI

struct Palette {
    let dark: Bool
    var background: Color { Color(hex: dark ? 0x242623 : 0xF9F7F1) }
    var surface: Color { Color(hex: dark ? 0x30322D : 0xFFFFFF) }
    var text: Color { Color(hex: dark ? 0xF5F1E8 : 0x252A25) }
    var muted: Color { Color(hex: dark ? 0xCAC9BF : 0x656D64) }
    var accent: Color { Color(hex: dark ? 0x76533E : 0xA65A3C) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct CopperButton: ButtonStyle {
    let palette: Palette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundColor(.white)
            .background(palette.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ManagerView: View {
    @ObservedObject var store: Store
    let paste: (Phrase) -> Void
    @State private var phraseEditor: PhraseDraft?
    @State private var categoryEditor: CategoryDraft?
    @State private var deletion: Deletion?
    private var palette: Palette { Palette(dark: store.dark) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your phrases").font(.system(size: 30, weight: .semibold, design: .serif))
                        Text("Save it once. Paste it forever.").foregroundColor(palette.muted)
                    }
                    Spacer()
                    Button("Add phrase") {
                        guard let id = selectedParent ?? store.categories.first?.id else {
                            store.error = "Add a category before creating a phrase."
                            return
                        }
                        phraseEditor = PhraseDraft(categoryId: id)
                    }
                }
                TextField("Search titles and phrase text", text: $store.search)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if store.state == nil {
                            Text(store.busy ? "Loading your library…" : "Library unavailable. Try Reload.")
                                .foregroundColor(palette.muted).padding()
                        } else if store.phrases.isEmpty {
                            Text("No phrases here yet.").foregroundColor(palette.muted).padding()
                        }
                        ForEach(store.phrases) { phrase in phraseCard(phrase) }
                    }.padding(12)
                }
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text("⌘⇧Space opens CommonCopy from another app.").font(.caption).foregroundColor(palette.muted)
                    Spacer()
                    if store.busy { ProgressView().controlSize(.small) }
                    Button("Reload") { Task { await store.perform("snapshot") } }
                }
            }.padding(24)
        }
        .foregroundColor(palette.text).background(palette.background)
        .buttonStyle(CopperButton(palette: palette))
        .preferredColorScheme(store.dark ? .dark : .light)
        .disabled(store.busy)
        .sheet(item: $phraseEditor) { draft in
            PhraseEditor(store: store, draft: draft)
        }
        .sheet(item: $categoryEditor) { draft in
            CategoryEditor(store: store, draft: draft)
        }
        .alert("CommonCopy", isPresented: Binding(get: { store.error != nil },
            set: { if !$0 { store.error = nil } })) {
            Button("OK") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .alert(item: $deletion) { item in
            Alert(title: Text(item.category ? "Delete this category and everything inside it?" : "Delete this phrase?"),
                message: Text(item.category ? "All nested categories and their phrases will also be deleted. The previous library is backed up." : "The previous library is backed up."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await store.perform(item.category ? "deleteCategory" : "deletePhrase", ["id": item.id]) }
                }, secondaryButton: .cancel())
        }
    }

    private var selectedParent: String? {
        store.categories.contains { $0.id == store.selectedCategory } ? store.selectedCategory : nil
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CommonCopy").font(.system(size: 24, weight: .bold, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.8).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    categoryButton("All phrases", id: "all")
                    categoryButton("Favourites", id: "favourites")
                    categoryButton("Commonly Used", id: "common")
                    Divider().padding(.vertical, 6)
                    ForEach(store.categories) { category in
                        if let id = category.id { categoryButton(category.displayName, id: id) }
                    }
                }
            }
            Button("Add category") { categoryEditor = CategoryDraft(parentId: selectedParent ?? "") }
            if let id = selectedParent,
               let category = store.state?.document.categories.first(where: { $0.id == id }) {
                HStack {
                    Button("Edit") { categoryEditor = CategoryDraft(category: category) }
                    Button("Delete") { deletion = Deletion(id: id, category: true) }
                }
            }
            Divider()
            Text("Appearance").font(.caption).foregroundColor(palette.muted)
            Picker("Appearance", selection: Binding(get: { store.dark ? "Dark" : "Light" }, set: { value in
                Task { await store.perform("appearance", ["appearance": value]) }
            })) {
                Text("Warm Editorial").tag("Light")
                Text("Burnished Copper").tag("Dark")
            }.labelsHidden()
            HStack {
                Button("Import") { store.importLibrary() }
                Button("Export") { store.exportLibrary() }
            }
            Button("Quit CommonCopy") { NSApp.terminate(nil) }
        }.padding(20).frame(width: 230)
    }

    private func categoryButton(_ title: String, id: String) -> some View {
        Button { store.selectedCategory = id } label: {
            Text(title).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .foregroundColor(store.selectedCategory == id ? .white : palette.text)
                .background(store.selectedCategory == id ? palette.accent : palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }

    private func phraseCard(_ phrase: Phrase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(phrase.title).font(.headline)
                if phrase.isFavorite { Image(systemName: "star.fill").foregroundColor(palette.accent) }
                Spacer()
                if !phrase.isEnabled { Text("Disabled").font(.caption).foregroundColor(palette.muted) }
                Text("\(phrase.useCount) uses").font(.caption).foregroundColor(palette.muted)
            }
            Text(phrase.text).lineLimit(3).foregroundColor(palette.muted).textSelection(.enabled)
            HStack {
                Button("Paste") { paste(phrase) }.disabled(!phrase.isEnabled)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(phrase.text, forType: .string)
                    Task { await store.perform("recordUse", ["id": phrase.id]) }
                }.disabled(!phrase.isEnabled)
                Spacer()
                Button("Edit") { phraseEditor = PhraseDraft(phrase: phrase) }
                Button("Duplicate") { Task { await store.perform("duplicatePhrase", ["id": phrase.id]) } }
                Button("Delete") { deletion = Deletion(id: phrase.id, category: false) }
            }
        }.padding(14).background(palette.background).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct Deletion: Identifiable { let id: String; let category: Bool }

struct PhraseDraft: Identifiable {
    let id = UUID()
    var existingId: String?
    var categoryId: String
    var title = ""
    var text = ""
    var favourite = false
    var enabled = true
    init(categoryId: String) { self.categoryId = categoryId }
    init(phrase: Phrase) {
        existingId = phrase.id; categoryId = phrase.categoryId; title = phrase.title
        text = phrase.text; favourite = phrase.isFavorite; enabled = phrase.isEnabled
    }
}

struct PhraseEditor: View {
    @ObservedObject var store: Store
    @State var draft: PhraseDraft
    @Environment(\.dismiss) private var dismiss
    @State private var failure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.existingId == nil ? "Add phrase" : "Edit phrase").font(.title2)
            TextField("Title", text: $draft.title)
            Picker("Category", selection: $draft.categoryId) {
                ForEach(store.categories) { item in
                    if let id = item.id { Text(item.displayName).tag(id) }
                }
            }
            TextEditor(text: $draft.text).font(.body.monospaced()).frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
            HStack {
                Toggle("Favourite", isOn: $draft.favourite)
                Toggle("Enabled", isOn: $draft.enabled)
            }
            if failure { Text("Could not save. Check the fields and try again.").foregroundColor(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        var fields: [String: Any] = ["categoryId": draft.categoryId, "title": draft.title,
                            "text": draft.text, "isFavorite": draft.favourite, "isEnabled": draft.enabled]
                        if let id = draft.existingId { fields["id"] = id }
                        if await store.perform("savePhrase", fields) { dismiss() } else { failure = true }
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.text.isEmpty || store.busy)
            }
        }.padding(24).frame(width: 520)
            .buttonStyle(CopperButton(palette: Palette(dark: store.dark)))
    }
}

struct CategoryDraft: Identifiable {
    let id = UUID()
    var existingId: String?
    var name = ""
    var parentId: String
    init(parentId: String) { self.parentId = parentId }
    init(category: Category) {
        existingId = category.id; name = category.name; parentId = category.parentId ?? ""
    }
}

struct CategoryEditor: View {
    @ObservedObject var store: Store
    @State var draft: CategoryDraft
    @Environment(\.dismiss) private var dismiss
    @State private var failure = false
    // Core validation also rejects cycles; omit the edited subtree from the picker.
    private var parents: [CategoryOption] {
        let categories = store.state?.document.categories ?? []
        var excluded = Set<String>()
        if let id = draft.existingId {
            excluded.insert(id)
            var changed = true
            while changed {
                let before = excluded.count
                for category in categories where category.parentId.map(excluded.contains) == true {
                    excluded.insert(category.id)
                }
                changed = before != excluded.count
            }
        }
        return store.categories.filter { !excluded.contains($0.id ?? "") }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.existingId == nil ? "Add category" : "Edit category").font(.title2)
            TextField("Name, e.g. GPT or Image based", text: $draft.name)
            Picker("Parent category", selection: $draft.parentId) {
                Text("Top level").tag("")
                ForEach(parents) { item in
                    if let id = item.id { Text(item.displayName).tag(id) }
                }
            }
            Text("Choose Prompts as the parent to create a prompt subcategory.").font(.caption)
            if failure { Text("Could not save. Check the name and parent category.").foregroundColor(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        var fields: [String: Any] = ["name": draft.name]
                        if !draft.parentId.isEmpty { fields["parentId"] = draft.parentId }
                        if let id = draft.existingId { fields["id"] = id }
                        if await store.perform("saveCategory", fields) { dismiss() } else { failure = true }
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            }
        }.padding(24).frame(width: 420)
            .buttonStyle(CopperButton(palette: Palette(dark: store.dark)))
    }
}
