import UIKit

final class KeyboardController: UIInputViewController {
    private let store = LibraryStore()
    private var filter = "all"
    private let rows = UIStackView()
    private let categoryButton = UIButton(type: .system)
    private let globe = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.tintColor = .label
        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = .defaultHigh
        height.isActive = true

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        let header = UIStackView()
        header.alignment = .center
        header.spacing = 4
        let title = UILabel()
        title.text = "CommonCopy"
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        header.addArrangedSubview(title)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.accessibilityLabel = "Switch keyboard"
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globe.widthAnchor.constraint(equalToConstant: 44).isActive = true
        header.addArrangedSubview(globe)
        header.addArrangedSubview(icon("delete.left", label: "Delete backward") { [weak self] in
            self?.textDocumentProxy.deleteBackward()
        })
        header.addArrangedSubview(icon("keyboard.chevron.compact.down", label: "Hide keyboard") { [weak self] in
            self?.dismissKeyboard()
        })
        header.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(header)

        categoryButton.showsMenuAsPrimaryAction = true
        categoryButton.contentHorizontalAlignment = .leading
        categoryButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(categoryButton)

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        rows.axis = .vertical
        rows.spacing = 6
        rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(rows)
        root.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            rows.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            rows.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            rows.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Face ID iPhones already supply a globe below the extension.
        globe.isHidden = !needsInputModeSwitchKey
    }

    private func icon(_ name: String, label: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: name), for: .normal)
        button.accessibilityLabel = label
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func configuration(_ title: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.background.backgroundColor = .secondarySystemBackground
        config.background.cornerRadius = 8
        config.background.strokeColor = .separator
        config.background.strokeWidth = 0.5
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        config.titleLineBreakMode = .byTruncatingTail
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16)
            return outgoing
        }
        return config
    }

    private func refresh() {
        guard isViewLoaded else { return }
        clearRows()
        var categoryConfig = configuration("All phrases")
        categoryConfig.image = UIImage(systemName: "chevron.down")
        categoryConfig.imagePlacement = .trailing
        categoryConfig.imagePadding = 8
        categoryButton.configuration = categoryConfig
        // Switching categories and retry remain available even after a read error.
        var choices = [("All phrases", "all"), ("Favourites", "favourites"), ("Commonly Used", "common")]
        do {
            let library = try store.load()
            choices += library.categories.filter { library.categoryEnabled($0.id) }.map { (library.categoryPath($0.id), $0.id) }
            if !choices.contains(where: { $0.1 == filter }) { filter = "all" }
            categoryConfig.title = choices.first(where: { $0.1 == filter })?.0
            categoryButton.configuration = categoryConfig
            let phrases = library.visible(filter: filter)
            if phrases.isEmpty { showMessage("No phrases here yet. Choose All phrases or add one in CommonCopy.") }
            for phrase in phrases {
                let item = UIButton(type: .system)
                item.configuration = configuration(phrase.title)
                item.contentHorizontalAlignment = .leading
                item.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                item.accessibilityHint = "Insert saved phrase"
                item.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    do {
                        let current = try self.store.load()
                        guard let fresh = current.visible(filter: "all").first(where: { $0.id == phrase.id }) else {
                            self.refresh(); return
                        }
                        self.textDocumentProxy.insertText(fresh.text)
                    } catch {
                        self.clearRows()
                        self.showMessage("Can't read your phrases. Open CommonCopy, then switch back to this keyboard.")
                    }
                }, for: .touchUpInside)
                rows.addArrangedSubview(item)
            }
        } catch {
            showMessage("Can't read your phrases. Open CommonCopy, then switch back to this keyboard.")
        }
        var actions = choices.map { title, value in
            UIAction(title: title, state: value == filter ? .on : .off) { [weak self] _ in
                self?.filter = value
                self?.refresh()
            }
        }
        actions.append(UIAction(title: "Reload phrases", image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in self?.refresh() })
        categoryButton.menu = UIMenu(children: actions)
    }

    private func clearRows() {
        rows.arrangedSubviews.forEach { rows.removeArrangedSubview($0); $0.removeFromSuperview() }
    }

    private func showMessage(_ text: String) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        rows.addArrangedSubview(label)
    }
}
