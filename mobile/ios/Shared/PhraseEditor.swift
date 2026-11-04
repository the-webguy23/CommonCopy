import SwiftUI

struct PhraseEditor: View {
    let store: LibraryStore
    let phrase: Phrase?
    var captured = ""
    let onSaved: () -> Void
    var onCancel: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var category = ""
    @State private var favorite = false
    @State private var library: LibraryDocument?
    @State private var error = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $text).frame(minHeight: 150).accessibilityLabel("Phrase text")
                if let library {
                    Picker("Category", selection: $category) { ForEach(library.categories) { c in Text(library.categoryPath(c.id)).tag(c.id) } }
                }
                Toggle("Favourite", isOn: $favorite)
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(phrase == nil ? "Save a phrase" : "Edit phrase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if let onCancel { onCancel() } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(library == nil) }
            }
            .onAppear {
                do { library = try store.load(); title = phrase?.title ?? ""; text = phrase?.text ?? captured; category = phrase?.categoryID ?? library?.categories.first?.id ?? ""; favorite = phrase?.favorite ?? false }
                catch { self.error = error.localizedDescription }
            }
        }.tint(.primary)
    }
    private func save() {
        do { try store.update { try $0.save(id: phrase?.id, title: title, text: text, categoryID: category, favorite: favorite) }; onSaved(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
