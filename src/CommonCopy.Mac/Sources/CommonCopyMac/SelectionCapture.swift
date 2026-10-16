import AppKit
import ApplicationServices

// The coordinator can be tested without touching a user's clipboard, focus,
// Accessibility permissions, or keyboard. Only the live adapter uses macOS APIs.
@MainActor
protocol SelectionCaptureEnvironment: AnyObject {
    var hasPermission: Bool { get }
    var targetIsActive: Bool { get }
    var changeCount: Int { get }
    var clipboardText: String? { get }
    func requestPermission()
    func activateTarget() async throws
    func sendCopy() throws
    func pause() async throws
    func restoreText(_ text: String)
}

@MainActor
enum SelectionCapture {
    static func read(from environment: SelectionCaptureEnvironment, attempts: Int = 30) async throws -> String {
        guard environment.hasPermission else {
            environment.requestPermission()
            throw CoreError.failed("Enable CommonCopy in System Settings → Privacy & Security → Accessibility, then retry Save highlighted text.")
        }
        try await environment.activateTarget()
        guard environment.targetIsActive else {
            throw CoreError.failed("The source app did not regain focus. No copy command was sent.")
        }
        let previousText = environment.clipboardText
        let beforeCopy = environment.changeCount
        var copiedChange: Int?
        defer {
            if let previousText, let copiedChange, environment.changeCount == copiedChange {
                environment.restoreText(previousText)
            }
        }
        try environment.sendCopy()
        for _ in 0..<attempts {
            try await environment.pause()
            guard environment.targetIsActive else {
                throw CoreError.failed("Focus changed during capture. Select the text in the original app and try again.")
            }
            let current = environment.changeCount
            if current != beforeCopy {
                copiedChange = current
                guard let text = environment.clipboardText,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw CoreError.failed("The selection did not contain plain text. Highlight selectable text and try again.")
                }
                return text
            }
        }
        throw CoreError.failed("No highlighted text could be copied. Highlight selectable text in the source app and try again.")
    }
}

@MainActor
final class MacSelectionCaptureEnvironment: SelectionCaptureEnvironment {
    private let target: NSRunningApplication
    private let delay: Int
    init(target: NSRunningApplication, delay: Int) { self.target = target; self.delay = delay }
    var hasPermission: Bool { AXIsProcessTrusted() }
    var targetIsActive: Bool {
        !target.isTerminated && NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
    }
    var changeCount: Int { NSPasteboard.general.changeCount }
    var clipboardText: String? { NSPasteboard.general.string(forType: .string) }
    func requestPermission() {
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }
    func activateTarget() async throws {
        NSApp.hide(nil)
        target.activate(options: .activateIgnoringOtherApps)
        try await Task.sleep(nanoseconds: UInt64(max(150, delay)) * 1_000_000)
    }
    func sendCopy() throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: false) else {
            throw CoreError.failed("macOS could not prepare the copy command.")
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    func pause() async throws { try await Task.sleep(nanoseconds: 50_000_000) }
    func restoreText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
