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
    private let commandClick = CommandRightClickService()
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var hotkey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var showingPhraseMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenus()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CommonCopy")
        item.button?.target = self
        item.button?.action = #selector(showManager)
        statusItem = item
        registerShortcut()
        commandClick.onActivate = { [weak self] in self?.showPhraseMenu() }
        configureCommandClick()
        showManager()
        Task { await store.perform("snapshot") }
    }

    @objc func showManager() {
        configureCommandClick()
        pasteService.rememberTarget()
        if window == nil {
            let content = ManagerView(store: store, paste: { [weak self] phrase in
                self?.paste(phrase)
            }, capture: { [weak self] in
                self?.captureSelection()
            }, configureActivation: { [weak self] in
                self?.configureCommandClick(requestPermission: true)
            })
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            created.title = "CommonCopy — Save it once. Paste it forever."
            created.contentView = NSHostingView(rootView: content)
            created.minSize = NSSize(width: 820, height: 540)
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) { configureCommandClick() }

    func configureCommandClick(requestPermission: Bool = false) {
        guard store.commandRightClickEnabled else {
            commandClick.stop()
            store.commandRightClickAvailable = false
            return
        }
        if requestPermission && !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            store.error = "Enable CommonCopy in System Settings → Privacy & Security → Accessibility, then return here. Command–Shift–Space remains available."
        }
        store.commandRightClickAvailable = commandClick.start()
    }

    func showPhraseMenu() {
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
        commandClick.stop()
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
