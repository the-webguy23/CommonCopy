import AppKit
import ApplicationServices

@MainActor
final class PasteService {
    var target: NSRunningApplication?
    private var inProgress = false

    func rememberTarget() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            target = app
        }
    }

    func captureSelectedText(settings: Settings) async throws -> String {
        guard !inProgress else { throw CoreError.failed("Wait for the current clipboard operation to finish.") }
        guard let target, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw CoreError.failed("Highlight text in another app, press Command–Shift–Space, then choose Save highlighted text.")
        }
        inProgress = true
        defer { inProgress = false }
        return try await SelectionCapture.read(from:
            MacSelectionCaptureEnvironment(target: target, delay: settings.pasteDelayMilliseconds))
    }

    func paste(_ text: String, settings: Settings) async throws {
        guard !inProgress else { throw CoreError.failed("Wait for the current paste to finish.") }
        guard let target, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            throw CoreError.failed("Focus a text field in another app, then open CommonCopy from the menu bar or press Command–Shift–Space.")
        }
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            throw CoreError.failed("Enable CommonCopy in System Settings → Privacy & Security → Accessibility, then try Paste again. Copy works without this permission.")
        }
        inProgress = true
        defer { inProgress = false }
        // Prepare the events before changing the user's clipboard.
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            throw CoreError.failed("macOS could not prepare the paste command.")
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        let pasteboard = NSPasteboard.general
        let oldText = pasteboard.string(forType: .string)
        NSApp.hide(nil)
        target.activate(options: .activateIgnoringOtherApps)
        try await Task.sleep(nanoseconds: UInt64(max(150, settings.pasteDelayMilliseconds)) * 1_000_000)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            throw CoreError.failed("The target app did not regain focus. No paste was sent.")
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writtenChange = pasteboard.changeCount
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        if settings.restoreTextClipboardAfterPaste, let oldText {
            try await Task.sleep(nanoseconds: UInt64(settings.clipboardRestoreDelayMilliseconds) * 1_000_000)
            // Never overwrite something the user copied while pasting.
            if pasteboard.changeCount == writtenChange {
                pasteboard.clearContents()
                pasteboard.setString(oldText, forType: .string)
            }
        }
    }
}
