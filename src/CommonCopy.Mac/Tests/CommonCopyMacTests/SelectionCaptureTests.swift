import XCTest
@testable import CommonCopyMac

final class SelectionCaptureTests: XCTestCase {
    @MainActor func testCaptureReturnsExactTextAndRestoresPreviousClipboard() async throws {
        let environment = FakeCaptureEnvironment()
        environment.result = "  First line\nsecond line 🧠  "
        let text = try await SelectionCapture.read(from: environment)
        XCTAssertEqual(text, "  First line\nsecond line 🧠  ")
        XCTAssertEqual(environment.currentText, "Previous clipboard")
        XCTAssertEqual(environment.copies, 1)
        XCTAssertEqual(environment.restores, 1)
    }

    @MainActor func testDeniedPermissionDoesNotActivateCopyOrRestore() async {
        let environment = FakeCaptureEnvironment()
        environment.hasPermission = false
        do { _ = try await SelectionCapture.read(from: environment); XCTFail("Expected permission error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Accessibility")) }
        XCTAssertEqual(environment.permissionRequests, 1)
        XCTAssertEqual(environment.activations, 0)
        XCTAssertEqual(environment.copies, 0)
        XCTAssertEqual(environment.restores, 0)
        XCTAssertEqual(environment.currentText, "Previous clipboard")
    }

    @MainActor func testNoSelectionTimesOutRatherThanReturningStaleClipboard() async {
        let environment = FakeCaptureEnvironment()
        environment.producesChange = false
        do { _ = try await SelectionCapture.read(from: environment, attempts: 3); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("No highlighted text")) }
        XCTAssertEqual(environment.pauses, 3)
        XCTAssertEqual(environment.restores, 0)
    }

    @MainActor func testUnfocusedTargetDoesNotSendCopy() async {
        let environment = FakeCaptureEnvironment()
        environment.targetIsActive = false
        do { _ = try await SelectionCapture.read(from: environment); XCTFail("Expected focus error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("focus")) }
        XCTAssertEqual(environment.copies, 0)
    }

    @MainActor func testNewClipboardWriteIsNotOverwrittenByRestore() async throws {
        let environment = FakeCaptureEnvironment()
        environment.replaceAfterRead = true
        _ = try await SelectionCapture.read(from: environment)
        XCTAssertEqual(environment.currentText, "New user copy")
        XCTAssertEqual(environment.restores, 0)
    }

    @MainActor func testWhitespaceSelectionFailsAndRestoresClipboard() async {
        let environment = FakeCaptureEnvironment()
        environment.result = " \n\t "
        do { _ = try await SelectionCapture.read(from: environment); XCTFail("Expected non-text error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("plain text")) }
        XCTAssertEqual(environment.currentText, "Previous clipboard")
        XCTAssertEqual(environment.restores, 1)
    }

    @MainActor func testFocusChangeDuringCopyDoesNotCaptureOtherAppsClipboard() async {
        let environment = FakeCaptureEnvironment()
        environment.changeFocusOnPause = true
        do { _ = try await SelectionCapture.read(from: environment); XCTFail("Expected focus error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("Focus changed")) }
        XCTAssertEqual(environment.restores, 0)
    }
}

@MainActor
private final class FakeCaptureEnvironment: SelectionCaptureEnvironment {
    var hasPermission = true
    var targetIsActive = true
    var changeCount = 1
    var currentText = "Previous clipboard"
    var result = "Captured selection"
    var producesChange = true
    var replaceAfterRead = false
    var changeFocusOnPause = false
    var permissionRequests = 0
    var activations = 0
    var copies = 0
    var restores = 0
    var pauses = 0
    var clipboardText: String? {
        let text = currentText
        if replaceAfterRead && copies > 0 {
            currentText = "New user copy"
            changeCount += 1
        }
        return text
    }
    func requestPermission() { permissionRequests += 1 }
    func activateTarget() async throws { activations += 1 }
    func sendCopy() throws {
        copies += 1
        if producesChange { currentText = result; changeCount += 1 }
    }
    func pause() async throws {
        pauses += 1
        if changeFocusOnPause { targetIsActive = false }
    }
    func restoreText(_ text: String) { currentText = text; changeCount += 1; restores += 1 }
}
