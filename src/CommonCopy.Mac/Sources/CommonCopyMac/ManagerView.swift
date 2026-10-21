import AppKit
import SwiftUI

struct Palette {
    let dark: Bool
    var background: Color { Color(hex: dark ? 0x181818 : 0xFFFFFF) }
    var surface: Color { Color(hex: dark ? 0x222222 : 0xF5F5F5) }
    var text: Color { Color(hex: dark ? 0xF5F5F5 : 0x111111) }
    var muted: Color { Color(hex: dark ? 0xBBBBBB : 0x686868) }
    var border: Color { Color(hex: dark ? 0x666666 : 0xBDBDBD) }
    var accent: Color { dark ? .white : .black }
    var accentText: Color { dark ? .black : .white }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

struct MonochromeButton: ButtonStyle {
    let palette: Palette
    var filled = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundColor(filled ? palette.accentText : palette.text)
            .background(filled ? palette.accent : palette.background)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(palette.border, lineWidth: 0.7))
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.65 : 1)
    }
}

struct BrandMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var resourceDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
    var body: some View {
        if let image = NSImage(contentsOf: resourceDirectory
            .appendingPathComponent(colorScheme == .dark ? "CommonCopyLogoReverse.svg" : "CommonCopyLogo.svg")) {
            Image(nsImage: image).resizable().scaledToFit()
                .frame(width: 38, height: 38).accessibilityHidden(true)
        }
    }
}

struct ManagerView: View {
    @ObservedObject var store: Store
    let paste: (Phrase) -> Void
    let capture: () -> Void
    let configureActivation: () -> Void
    let finishPhraseSave: () -> Void
    @State private var phraseSaved = false
    @State private var categoryEditor: CategoryDraft?
    @State private var deletion: Deletion?
    @State private var settingsOpen = false
    private var palette: Palette { Palette(dark: store.dark) }
    private var sectionTitle: String {
        switch store.selectedCategory {
        case "all": return "All phrases"
        case "favourites": return "Favourites"
        case "common": return "Commonly Used"
        default: return store.categories.first { $0.id == store.selectedCategory }?.displayName ?? "Your phrases"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(palette.border).frame(width: 0.7)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your phrases").font(.system(size: 28, weight: .medium))
                        Text("Save it once. Paste it forever.").font(.system(size: 12)).foregroundColor(palette.muted)
                    }
                    Spacer()
                    Button("Add phrase", action: addPhrase)
                        .buttonStyle(MonochromeButton(palette: palette, filled: true))
                }
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundColor(palette.muted)
                    TextField("Search your phrases", text: $store.search).textFieldStyle(.plain)
                        .accessibilityLabel("Search phrase titles and text")
                    if !store.search.isEmpty {
                        Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear search")
                    }
                }.padding(11).background(palette.background)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.border, lineWidth: 0.7))
                HStack {
                    Text(sectionTitle).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(store.phrases.count) shown · \(store.state?.document.phrases.count ?? 0) total")
                        .font(.system(size: 11)).foregroundColor(palette.muted)
                }
                phraseList
                selectedPhraseCard
                HStack {
                    Image(systemName: store.commandRightClickAvailable ? "checkmark.circle" : "info.circle")
                    Text(store.commandRightClickAvailable ? "⌘ + right-click opens your menu.  ⌘⇧Space also works."
                         : "Enable Accessibility in Settings to use Command + right-click.")
                    Spacer()
                    if store.busy || store.capturing { ProgressView().controlSize(.small) }
                }.font(.system(size: 10)).foregroundColor(palette.muted)
            }.padding(24)
        }
        .foregroundColor(palette.text).background(palette.background)
        .buttonStyle(MonochromeButton(palette: palette))
        .preferredColorScheme(store.dark ? .dark : .light)
        .tint(palette.accent)
        .disabled(store.busy || store.capturing)
        .sheet(item: $store.phraseEditor, onDismiss: {
            guard phraseSaved else { return }
            phraseSaved = false
            finishPhraseSave()
        }) { draft in
            PhraseEditor(store: store, draft: draft, onSaved: { phraseSaved = true })
        }
        .sheet(item: $categoryEditor) { draft in CategoryEditor(store: store, draft: draft) }
        .sheet(isPresented: $settingsOpen) {
            SettingsView(store: store, configureActivation: configureActivation)
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

    private func addPhrase() {
        guard let id = selectedParent ?? store.categories.first?.id else {
            store.error = "Add a category before creating a phrase."
            return
        }
        store.phraseEditor = PhraseDraft(categoryId: id)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(spacing: 9) {
                BrandMark()
                Text("CommonCopy").font(.system(size: 18, weight: .semibold)).lineLimit(1)
            }.padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 5) {
                categoryButton("All phrases", icon: "square.stack", id: "all")
                categoryButton("Favourites", icon: "star", id: "favourites")
                categoryButton("Commonly Used", icon: "clock", id: "common")
            }
            Rectangle().fill(palette.border).frame(height: 0.7)
            HStack {
                Text("Categories").font(.system(size: 11)).foregroundColor(palette.muted)
                Spacer()
                Button { categoryEditor = CategoryDraft(parentId: selectedParent ?? "") } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).help("Add category").accessibilityLabel("Add category")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.categories) { item in
                        if let id = item.id {
                            categoryButton(item.displayName, icon: "folder", id: id)
                                .contextMenu {
                                    Button("Add subcategory") { categoryEditor = CategoryDraft(parentId: id) }
                                    if let category = store.state?.document.categories.first(where: { $0.id == id }) {
                                        Button("Edit category") { categoryEditor = CategoryDraft(category: category) }
                                    }
                                    Button("Delete category", role: .destructive) { deletion = Deletion(id: id, category: true) }
                                }
                        }
                    }
                }
            }
            if let id = selectedParent,
               let category = store.state?.document.categories.first(where: { $0.id == id }) {
                HStack {
                    Text("Category options").font(.system(size: 10)).foregroundColor(palette.muted)
                    Spacer()
                    Menu {
                        Button("Add subcategory") { categoryEditor = CategoryDraft(parentId: id) }
                        Button("Edit category") { categoryEditor = CategoryDraft(category: category) }
                        Button("Delete category", role: .destructive) { deletion = Deletion(id: id, category: true) }
                    } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).fixedSize().help("Category options")
                }
            }
            Button("Save highlighted text…", action: capture).frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(palette.border).frame(height: 0.7)
            HStack {
                Button { settingsOpen = true } label: { Label("Settings", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                Spacer()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.plain).help("Quit CommonCopy").accessibilityLabel("Quit CommonCopy")
            }.font(.system(size: 12))
        }.padding(20).frame(width: 220).background(palette.surface)
    }

    private func categoryButton(_ title: String, icon: String, id: String) -> some View {
        let selected = store.selectedCategory == id
        return Button { store.selectedCategory = id } label: {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 14)
                Text(title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.system(size: 12)).padding(.horizontal, 10).padding(.vertical, 10)
                .foregroundColor(selected ? .white : palette.text)
                .background(selected ? Color(hex: store.dark ? 0x3A3A3A : 0x222222) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 16, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundColor(palette.muted)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phraseList: some View {
        Group {
            if store.state == nil {
                emptyState(store.busy ? "Loading your library…" : "Your library couldn’t be loaded.",
                    detail: "Open Settings to reload your library.")
            } else if store.phrases.isEmpty {
                emptyState(store.search.isEmpty ? "A place for your next useful phrase." : "No matching phrases.",
                    detail: store.search.isEmpty ? "Add a phrase, or save highlighted text from another app." : "Try another word or choose a different category.")
            } else {
                Table(store.phrases, selection: $store.selectedPhraseId) {
                    TableColumn("★") { phrase in
                        Image(systemName: phrase.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 10)).opacity(phrase.isFavorite ? 1 : 0.25)
                            .accessibilityLabel(phrase.isFavorite ? "Favourite" : "Not a favourite")
                    }.width(26)
                    TableColumn("Title") { phrase in
                        HStack(spacing: 5) {
                            Text(phrase.title).lineLimit(1)
                            if !phrase.isEnabled { Image(systemName: "pause.circle").help("Disabled") }
                        }
                        .contextMenu { phraseOptions(phrase) }
                    }.width(min: 120, ideal: 180, max: 260)
                    TableColumn("Text preview") { phrase in
                        Text(phrase.text.replacingOccurrences(of: "\n", with: " "))
                            .lineLimit(1)
                    }.width(min: 100, ideal: 280)
                    TableColumn("Uses") { phrase in
                        Text("\(phrase.useCount)").monospacedDigit()
                    }.width(44)
                }
                .tableStyle(.inset)
                .accessibilityLabel("Your phrases")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border, lineWidth: 0.7))
    }

    private var selectedPhraseCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Selected Phrase").font(.system(size: 10)).foregroundColor(palette.muted)
            if let phrase = store.selectedPhrase {
                HStack {
                    Text(phrase.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer()
                    if !phrase.isEnabled { Text("Disabled").font(.caption).foregroundColor(palette.muted) }
                }
                ScrollView {
                    Text(phrase.text).font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 8) {
                    Button("Copy") { copyPhrase(phrase) }.disabled(!phrase.isEnabled)
                        .buttonStyle(MonochromeButton(palette: palette, filled: true))
                    Button("Edit") { store.phraseEditor = PhraseDraft(phrase: phrase) }
                    Spacer()
                    Menu { phraseOptions(phrase) } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).fixedSize()
                        .help("Phrase options").accessibilityLabel("Options for selected phrase")
                }
            } else {
                Text("Select a phrase to preview its full text.")
                    .font(.system(size: 12)).foregroundColor(palette.muted)
                Spacer()
            }
        }
        .padding(16).frame(maxWidth: .infinity).frame(height: 178)
        .background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border, lineWidth: 0.7))
        .accessibilityIdentifier("selected-phrase-preview")
    }

    private func copyPhrase(_ phrase: Phrase) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(phrase.text, forType: .string)
        Task { await store.perform("recordUse", ["id": phrase.id]) }
    }

    @ViewBuilder private func phraseOptions(_ phrase: Phrase) -> some View {
        Button("Paste") { paste(phrase) }.disabled(!phrase.isEnabled)
        Button("Edit phrase") { store.phraseEditor = PhraseDraft(phrase: phrase) }
        Button(phrase.isFavorite ? "Remove from Favourites" : "Add to Favourites") { saveFlags(phrase, favourite: !phrase.isFavorite) }
        Button(phrase.isEnabled ? "Disable phrase" : "Enable phrase") { saveFlags(phrase, enabled: !phrase.isEnabled) }
        Button("Duplicate phrase") { Task { await store.perform("duplicatePhrase", ["id": phrase.id]) } }
        Divider()
        Button("Delete phrase", role: .destructive) { deletion = Deletion(id: phrase.id, category: false) }
    }

    private func saveFlags(_ phrase: Phrase, favourite: Bool? = nil, enabled: Bool? = nil) {
        Task { await store.perform("savePhrase", ["id": phrase.id, "categoryId": phrase.categoryId,
            "title": phrase.title, "text": phrase.text, "isFavorite": favourite ?? phrase.isFavorite,
            "isEnabled": enabled ?? phrase.isEnabled]) }
    }
}

struct SettingsView: View {
    @ObservedObject var store: Store
    let configureActivation: () -> Void
    @Environment(\.dismiss) private var dismiss
    private var palette: Palette { Palette(dark: store.dark) }
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Settings").font(.system(size: 26, weight: .medium))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick access").font(.headline)
                Toggle("Command + right-click", isOn: $store.commandRightClickEnabled)
                    .onChange(of: store.commandRightClickEnabled) { _ in configureActivation() }
                Text("⌘⇧Space also opens your compact phrase menu.").font(.caption).foregroundColor(palette.muted)
                if store.commandRightClickEnabled && !store.commandRightClickAvailable {
                    Button("Enable Accessibility…", action: configureActivation)
                    Text("Enable CommonCopy in System Settings → Privacy & Security → Accessibility, then return here.")
                        .font(.caption).foregroundColor(palette.muted)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance").font(.headline)
                Picker("Appearance", selection: Binding(get: { store.dark ? "Dark" : "Light" }, set: { value in
                    Task { await store.perform("appearance", ["appearance": value]) }
                })) { Text("Light").tag("Light"); Text("Dark").tag("Dark") }.pickerStyle(.segmented).labelsHidden()
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Your library").font(.headline)
                Text("Stored on this Mac. Export a copy for a lasting backup.").font(.caption).foregroundColor(palette.muted)
                HStack {
                    Button("Import…") { store.importLibrary() }
                    Button("Export…") { store.exportLibrary() }
                    Spacer()
                    Button("Reload") { Task { await store.perform("snapshot") } }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Help").font(.headline)
                Button("Guides, examples & troubleshooting", action: openHelp)
                Text("Opens the included guide in your browser. Works offline.")
                    .font(.caption).foregroundColor(palette.muted)
            }
            Divider()
            HStack { BrandMark(); Text("CommonCopy\nSave it once. Paste it forever.").font(.caption).foregroundColor(palette.muted) }
            Button("Quit CommonCopy") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.caption)
        }.padding(28)
        }.frame(width: 460, height: 650).foregroundColor(palette.text).background(palette.background)
            .buttonStyle(MonochromeButton(palette: palette)).disabled(store.busy)
    }
    private func openHelp() {
        guard let url = Bundle.main.url(forResource: "help", withExtension: "html") else {
            store.error = "The included help guide is missing. Reinstall the complete CommonCopy application; keep your phrase data."
            return
        }
        if !NSWorkspace.shared.open(url) {
            store.error = "Could not open your browser. The included guide is in CommonCopy.app → Contents → Resources → help.html."
        }
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
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var failure = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.existingId == nil ? "Add phrase" : "Edit phrase").font(.system(size: 24, weight: .medium))
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
                        if await store.perform("savePhrase", fields) {
                            onSaved()
                            dismiss()
                        } else { failure = true }
                    }
                }.keyboardShortcut(.defaultAction)
                    .buttonStyle(MonochromeButton(palette: Palette(dark: store.dark), filled: true))
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.text.isEmpty || store.busy)
            }
        }.padding(24).frame(width: 520)
            .buttonStyle(MonochromeButton(palette: Palette(dark: store.dark)))
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
                    .buttonStyle(MonochromeButton(palette: Palette(dark: store.dark), filled: true))
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            }
        }.padding(24).frame(width: 420)
            .buttonStyle(MonochromeButton(palette: Palette(dark: store.dark)))
    }
}
