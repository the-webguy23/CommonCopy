import AppKit

// A disposable CI-only editor. Never included in CommonCopy.app. Test text is
// fixed; the sole argument is a temporary output path, not phrase content.
@main
enum FixtureApp {
    @MainActor static func main() {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
              CommandLine.arguments.count == 2 else { return }
        let application = NSApplication.shared
        let delegate = FixtureDelegate(path: CommandLine.arguments[1])
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    let path: String
    var window: NSWindow?
    var textView: NSTextView?
    init(path: String) { self.path = path }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let edit = NSMenuItem()
        let submenu = NSMenu(title: "Edit")
        submenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        submenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.submenu = submenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
        let created = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 450, height: 250),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 450, height: 250))
        editor.isRichText = false
        editor.string = "Selected fixture text\nUnicode: 🧠"
        editor.delegate = self
        created.contentView = editor
        created.makeKeyAndOrderFront(nil)
        created.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        NSApp.activate(ignoringOtherApps: true)
        window = created
        textView = editor
        persist()
    }
    func textDidChange(_ notification: Notification) { persist() }
    func persist() { try? textView?.string.write(toFile: path, atomically: true, encoding: .utf8) }
}
