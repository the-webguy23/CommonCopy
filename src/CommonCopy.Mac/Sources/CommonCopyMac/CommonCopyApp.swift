import AppKit
import Carbon
import SwiftUI
import ApplicationServices

@main
enum CommonCopyApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    let pasteService = PasteService()
    let setup: AccessibilitySetupController
    private let commandClick = CommandRightClickService()
    private var statusItem: NSStatusItem?
    private(set) var window: NSWindow?
    private(set) var setupWindow: NSWindow?
    private var permissionMonitor: Task<Void, Never>?
    private var hotkey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var showingPhraseMenu = false

    override convenience init() { self.init(setup: AccessibilitySetupController()) }
    init(setup: AccessibilitySetupController) {
        self.setup = setup
        super.init()
        setup.onPhaseChanged = { [weak self] phase in self?.setupChanged(phase) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenus()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CommonCopy")
        item.button?.target = self
        item.button?.action = #selector(showManager)
        statusItem = item
        commandClick.onActivate = { [weak self] in self?.showPhraseMenu() }
        setup.refresh()
        permissionMonitor = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 750_000_000) } catch { return }
                self?.setup.refresh()
            }
        }
        Task { await store.perform("snapshot") }
    }

    @objc func showManager() {
        guard ensureSetup() else { return }
        configureCommandClick()
        pasteService.rememberTarget()
        if window == nil {
            let content = ManagerView(store: store, paste: { [weak self] phrase in
                self?.paste(phrase)
            }, capture: { [weak self] in
                self?.captureSelection()
            }, configureActivation: { [weak self] in
                self?.configureCommandClick(requestPermission: true)
            }, finishPhraseSave: { [weak self] in
                self?.finishPhraseSave()
            })
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            created.title = "CommonCopy — Save it once. Paste it forever."
            created.contentView = NSHostingView(rootView: content)
            created.minSize = NSSize(width: 900, height: 620)
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // Both the status item and all utility entry points return here while access
    // is missing. Closing this window never completes or skips setup.
    @discardableResult
    private func ensureSetup() -> Bool {
        setup.refresh()
        guard setup.phase == .ready else {
            showSetup()
            return false
        }
        return true
    }

    private func showSetup() {
        if setupWindow == nil {
            let view = AccessibilitySetupView(setup: setup, store: store)
            let hosting = NSHostingView(rootView: view)
            let created = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            created.title = "Set up CommonCopy"
            created.contentView = hosting
            created.isReleasedWhenClosed = false
            created.center()
            setupWindow = created
        }
        if let content = setupWindow?.contentView {
            content.layoutSubtreeIfNeeded()
            setupWindow?.setContentSize(content.fittingSize)
        }
        window?.orderOut(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }

    private func setupChanged(_ phase: AccessibilitySetupPhase) {
        if phase == .ready {
            setupWindow?.orderOut(nil)
            registerShortcut()
            showManager()
        } else {
            commandClick.stop()
            stopShortcut()
            store.commandRightClickAvailable = false
            showSetup()
        }
    }

    // Wait for the editor sheet to dismiss before hiding its parent window.
    // Keep the menu-bar utility alive and return the user to the source app.
    func finishPhraseSave() {
        window?.orderOut(nil)
        NSApp.hide(nil)
        if let target = pasteService.target, !target.isTerminated {
            target.activate(options: .activateIgnoringOtherApps)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        setup.refresh()
        configureCommandClick()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showManager()
        return true
    }

    func configureCommandClick(requestPermission: Bool = false) {
        guard setup.phase == .ready else {
            commandClick.stop()
            store.commandRightClickAvailable = false
            return
        }
        guard store.commandRightClickEnabled else {
            commandClick.stop()
            store.commandRightClickAvailable = false
            return
        }
        if requestPermission && !AXIsProcessTrusted() {
            setup.refresh()
            showSetup()
            return
        }
        store.commandRightClickAvailable = commandClick.start()
    }

    func showPhraseMenu() {
        guard ensureSetup() else { return }
        guard !store.busy, !store.capturing, !showingPhraseMenu else { return }
        guard store.phraseEditor == nil, let state = store.state else {
            showManager()
            return
        }
        pasteService.rememberTarget()
        let menu = makePhraseMenu(state: state)
        NSApp.unhide(nil)
        window?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        showingPhraseMenu = true
        defer { showingPhraseMenu = false }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func makePhraseMenu(state: CoreState) -> NSMenu {
        let menu = NSMenu(title: "CommonCopy")
        menu.appearance = NSAppearance(named: store.dark ? .darkAqua : .aqua)
        menu.addItem(withTitle: "Save highlighted text…", action: #selector(captureFromMenu), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let byId = Dictionary(uniqueKeysWithValues: state.document.phrases.map { ($0.id, $0) })
        func appendPhrases(_ ids: [String], to submenu: NSMenu) {
            for id in ids {
                guard let phrase = byId[id], phrase.isEnabled else { continue }
                let item = submenu.addItem(withTitle: phrase.title, action: #selector(pasteFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = id
            }
        }
        func appendGroup(_ title: String, ids: [String]) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            appendPhrases(ids, to: submenu)
            if submenu.items.isEmpty { submenu.addItem(withTitle: "No phrases yet", action: nil, keyEquivalent: "") }
            item.submenu = submenu
            menu.addItem(item)
        }
        appendGroup("Favourites", ids: state.favourites)
        appendGroup("Commonly Used", ids: state.commonlyUsed)
        menu.addItem(.separator())
        let byCategory = Dictionary(uniqueKeysWithValues: state.document.categories.map { ($0.id, $0) })
        let ordered = state.categoryList.compactMap { $0.id.flatMap { byCategory[$0] } }
        func appendCategories(parent: String?, to destination: NSMenu) {
            for category in ordered where category.parentId == parent {
                let item = NSMenuItem(title: category.name, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: category.name)
                let direct = state.document.phrases.filter { $0.categoryId == category.id && $0.isEnabled }
                    .sorted { $0.sortOrder == $1.sortOrder
                        ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                        : $0.sortOrder < $1.sortOrder }
                appendPhrases(direct.map(\.id), to: submenu)
                appendCategories(parent: category.id, to: submenu)
                if submenu.items.isEmpty { submenu.addItem(withTitle: "No phrases yet", action: nil, keyEquivalent: "") }
                item.submenu = submenu
                destination.addItem(item)
            }
        }
        appendCategories(parent: nil, to: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Manage phrases…", action: #selector(showManager), keyEquivalent: "").target = self
        return menu
    }

    @objc private func captureFromMenu() { captureSelection() }
    @objc private func pasteFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let phrase = store.state?.document.phrases.first(where: { $0.id == id }) else { return }
        paste(phrase)
    }

    func paste(_ phrase: Phrase) {
        guard ensureSetup() else { return }
        guard phrase.isEnabled, !store.busy, !store.capturing, let settings = store.state?.document.settings else { return }
        Task {
            do {
                try await pasteService.paste(phrase.text, settings: settings)
                await store.perform("recordUse", ["id": phrase.id])
            } catch {
                showManager()
                store.error = (error as? CoreError)?.errorDescription ?? "The paste could not complete."
            }
        }
    }

    func captureSelection() {
        guard ensureSetup() else { return }
        guard !store.busy, !store.capturing, store.phraseEditor == nil,
              let settings = store.state?.document.settings else { return }
        guard let categoryId = store.categories.first(where: { $0.id == store.selectedCategory })?.id
                ?? store.categories.first?.id else {
            store.error = "Add a category before saving highlighted text."
            return
        }
        store.capturing = true
        Task {
            defer { store.capturing = false }
            do {
                let text = try await pasteService.captureSelectedText(settings: settings)
                // Title generation uses the same core routine as Windows. Preparing
                // a draft never writes the capture into the phrase library.
                guard await store.perform("captureDraft", ["text": text]) else {
                    showManager()
                    return
                }
                var draft = PhraseDraft(categoryId: categoryId)
                draft.text = text
                draft.title = store.state?.captureTitle ?? "Captured phrase"
                showManager()
                store.phraseEditor = draft
            } catch {
                showManager()
                store.error = (error as? CoreError)?.errorDescription ?? "Highlighted text could not be captured."
            }
        }
    }

    private func registerShortcut() {
        guard hotkey == nil, eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x43434F50, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in delegate.showPhraseMenu() }
            return noErr
        }
        let installed = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        let registered = installed == noErr
            ? RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey | shiftKey),
                EventHotKeyID(signature: 0x43434F50, id: 1), GetApplicationEventTarget(), 0, &hotkey)
            : installed
        if registered != noErr {
            store.error = "Command–Shift–Space is unavailable. You can still open CommonCopy from its menu-bar icon."
        }
    }

    private func configureMenus() {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Open CommonCopy", action: #selector(showManager), keyEquivalent: "0").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit CommonCopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = appMenu
        menu.addItem(applicationItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionMonitor?.cancel()
        commandClick.stop()
        stopShortcut()
    }

    private func stopShortcut() {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotkey = nil
        eventHandler = nil
    }
}
