import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        guard let provider = items.flatMap({ $0.attachments ?? [] }).first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) else { failure("Share a text selection to save it in CommonCopy."); return }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
            let text = (item as? String) ?? (item as? NSAttributedString)?.string
            DispatchQueue.main.async {
                guard let self else { return }
                guard error == nil, let text, !text.isEmpty, text.utf8.count <= 1_000_000 else { self.failure("Share a text selection smaller than 1 MB."); return }
                do {
                    let store = LibraryStore(); try store.initialize()
                    let editor = PhraseEditor(store: store, phrase: nil, captured: text, onSaved: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }, onCancel: { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) })
                    let host = UIHostingController(rootView: editor); self.addChild(host); self.view.addSubview(host.view); host.view.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor), host.view.topAnchor.constraint(equalTo: self.view.topAnchor), host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)]); host.didMove(toParent: self)
                } catch { self.failure(error.localizedDescription) }
            }
        }
    }
    private func failure(_ message: String) {
        let alert = UIAlertController(title: "CommonCopy", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in self?.extensionContext?.completeRequest(returningItems: nil) })
        // Wait for presentation instead of attempting to present during viewDidLoad.
        pendingAlert = alert
        if view.window != nil { present(alert, animated: true); pendingAlert = nil }
    }
    private var pendingAlert: UIAlertController?
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); if let alert = pendingAlert { pendingAlert = nil; present(alert, animated: true) } }
}
