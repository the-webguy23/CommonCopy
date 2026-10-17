import XCTest
import AppKit
import ApplicationServices
@testable import CommonCopyMac

final class SystemWorkflowTests: XCTestCase {
    @MainActor private func requireDisposableMacSession() throws {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true", AXIsProcessTrusted() else {
            throw XCTSkip("Live system input runs only in a trusted disposable GitHub Actions Mac session.")
        }
        _ = NSApplication.shared
    }

    @MainActor func testRealCommandRightClickReachesMouseTapOnce() async throws {
        try requireDisposableMacSession()
        let service = CommandRightClickService()
        let activated = expectation(description: "Command-right-click delivered")
        activated.assertForOverFulfill = true
        var calls = 0
        service.onActivate = { calls += 1; activated.fulfill() }
        XCTAssertTrue(service.start(), "The CI event tap must be available")
        defer { service.stop() }
        let point = CGPoint(x: 400, y: 300)
        let down = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
            mouseCursorPosition: point, mouseButton: .right))
        let up = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
            mouseCursorPosition: point, mouseButton: .right))
        down.flags = .maskCommand
        up.flags = [] // Command may be released before the right button.
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        await fulfillment(of: [activated], timeout: 3)
        XCTAssertEqual(calls, 1)
    }

    @MainActor func testActualSelectionCaptureAndPasteIntoAnotherProcess() async throws {
        try requireDisposableMacSession()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("editor.txt")
        let fixture = Bundle(for: SystemWorkflowTests.self).bundleURL.deletingLastPathComponent()
            .appendingPathComponent("CommonCopyFixture")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.path))
        let process = Process()
        process.executableURL = fixture
        process.arguments = [output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        defer { if process.isRunning { process.terminate() } }
        for _ in 0..<60 {
            if FileManager.default.fileExists(atPath: output.path) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let target = try XCTUnwrap(NSRunningApplication(processIdentifier: process.processIdentifier))
        let service = PasteService()
        service.target = target
        let settings = Settings(appearance: "Light", restoreTextClipboardAfterPaste: true,
            clipboardRestoreDelayMilliseconds: 350, pasteDelayMilliseconds: 200)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Previous fixture clipboard", forType: .string)
        let captured = try await service.captureSelectedText(settings: settings)
        XCTAssertEqual(captured, "Selected fixture text\nUnicode: 🧠")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Previous fixture clipboard")
        try await service.paste("Inserted fixture phrase", settings: settings)
        for _ in 0..<30 {
            if (try? String(contentsOf: output, encoding: .utf8)) == "Inserted fixture phrase" { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "Inserted fixture phrase")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Previous fixture clipboard")
    }
}
