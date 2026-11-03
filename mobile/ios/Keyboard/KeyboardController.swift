import UIKit

final class KeyboardController: UIInputViewController {
    private let store = LibraryStore()
    private var filter = "favourites"
    private let root = UIStackView()
    private let rows = UIStackView()
    private let categoryButton = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        root.axis = .vertical; root.spacing = 8; root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12), root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12), root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8), root.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8), view.heightAnchor.constraint(greaterThanOrEqualToConstant: 290)])
        let title = UILabel(); title.text = "CommonCopy"; title.font = .preferredFont(forTextStyle: .headline); title.adjustsFontForContentSizeCategory = true
        root.addArrangedSubview(title)
        let tools = UIStackView(); tools.spacing = 10; tools.distribution = .fillEqually
        categoryButton.setTitle("Categories", for: .normal); categoryButton.showsMenuAsPrimaryAction = true
        tools.addArrangedSubview(categoryButton)
        let next = button("Next keyboard") { [weak self] in self?.advanceToNextInputMode() }; tools.addArrangedSubview(next)
        let delete = button("⌫") { [weak self] in self?.textDocumentProxy.deleteBackward() }; delete.accessibilityLabel = "Delete backward"; tools.addArrangedSubview(delete)
        root.addArrangedSubview(tools)
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; rows.axis = .vertical; rows.spacing = 6; rows.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(rows); root.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([scroll.heightAnchor.constraint(equalToConstant: 185), rows.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), rows.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor), rows.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), rows.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor), rows.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        let bottom = UIStackView(); bottom.spacing = 10
        let globe = UIButton(type: .system); globe.setImage(UIImage(systemName: "globe"), for: .normal); globe.accessibilityLabel = "Switch keyboard"; globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents); globe.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; bottom.addArrangedSubview(globe)
        bottom.addArrangedSubview(button("Hide keyboard") { [weak self] in self?.dismissKeyboard() }); root.addArrangedSubview(bottom)
        refresh()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    private func button(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system); var config = UIButton.Configuration.bordered(); config.title = title; config.baseForegroundColor = .label; config.cornerStyle = .capsule; button.configuration = config
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
    }
    private func refresh() {
        guard isViewLoaded else { return }
        rows.arrangedSubviews.forEach { rows.removeArrangedSubview($0); $0.removeFromSuperview() }
        do {
            let library = try store.load()
            var choices = [("All phrases", "all"), ("Favourites", "favourites"), ("Commonly Used", "common")]
            choices += library.categories.filter { library.categoryEnabled($0.id) }.map { (library.categoryPath($0.id), $0.id) }
            categoryButton.menu = UIMenu(children: choices.map { title, value in UIAction(title: title, state: value == filter ? .on : .off) { [weak self] _ in self?.filter = value; self?.refresh() } })
            let phrases = library.visible(filter: filter)
            if phrases.isEmpty { showMessage("No phrases here yet. Try All phrases, or add some in the CommonCopy app.") }
            for phrase in phrases {
                let item = button(phrase.title) { [weak self] in
                    guard let self else { return }
                    do {
                        // Read again to respect edits, deleted phrases and disabled categories.
                        let current = try self.store.load()
                        guard let fresh = current.visible(filter: "all").first(where: { $0.id == phrase.id }) else { self.refresh(); return }
                        self.textDocumentProxy.insertText(fresh.text)
                        // No shared-container writes: Full Access is not required.
                    } catch { self.showMessage("Couldn't read this phrase. Open CommonCopy to check your library.") }
                }
                item.contentHorizontalAlignment = .leading; rows.addArrangedSubview(item)
            }
        } catch { showMessage(error.localizedDescription) }
    }
    private func showMessage(_ text: String) { let label = UILabel(); label.text = text; label.numberOfLines = 0; label.font = .preferredFont(forTextStyle: .subheadline); label.textColor = .secondaryLabel; rows.addArrangedSubview(label) }
}
