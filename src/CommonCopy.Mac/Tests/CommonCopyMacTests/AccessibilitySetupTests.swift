import AppKit
import SwiftUI
import XCTest
@testable import CommonCopyMac

@MainActor
private final class SetupEnvironment: AccessibilitySetupEnvironment {
    var installedInApplications = true
    var accessibilityGranted = false
    var settingsAvailable = true
    var requests = 0
    var opens = 0
    var reveals = 0
    func requestAccessibility() { requests += 1 }
    func openAccessibilitySettings() -> Bool { opens += 1; return settingsAvailable }
    func revealApplication() { reveals += 1 }
}

final class AccessibilitySetupTests: XCTestCase {
    @MainActor func testPollingNeverPromptsAndGrantAndRevocationAreDetected() {
        let environment = SetupEnvironment()
        let setup = AccessibilitySetupController(environment: environment)
        var phases: [AccessibilitySetupPhase] = []
        setup.onPhaseChanged = { phases.append($0) }
        for _ in 0..<5 { setup.refresh() }
        XCTAssertEqual(setup.phase, .permissionRequired)
        XCTAssertEqual(environment.requests, 0)
        environment.accessibilityGranted = true
        setup.refresh()
        setup.refresh()
        environment.accessibilityGranted = false
        setup.refresh()
        XCTAssertEqual(phases, [.permissionRequired, .ready, .permissionRequired])
        XCTAssertEqual(environment.requests, 0)
    }

    @MainActor func testSettingsRetriesDoNotRepeatSystemPromptAndHaveManualFallback() {
        let environment = SetupEnvironment()
        let setup = AccessibilitySetupController(environment: environment)
        environment.settingsAvailable = false
        setup.openSettings()
        XCTAssertNotNil(setup.settingsError)
        XCTAssertFalse(setup.settingsOpened)
        environment.settingsAvailable = true
        setup.openSettings()
        XCTAssertTrue(setup.settingsOpened)
        XCTAssertNil(setup.settingsError)
        XCTAssertEqual(environment.requests, 1)
        XCTAssertEqual(environment.opens, 2)
        XCTAssertEqual(setup.phase, .permissionRequired)
    }

    @MainActor func testExistingPermissionNeedsNoSetupAndUninstalledCopyCannotRequestAccess() {
        let environment = SetupEnvironment()
        environment.accessibilityGranted = true
        let setup = AccessibilitySetupController(environment: environment)
        setup.refresh()
        XCTAssertEqual(setup.phase, .ready)
        setup.openSettings()
        XCTAssertEqual(environment.requests, 0)
        environment.installedInApplications = false
        setup.openSettings()
        setup.revealApplication()
        XCTAssertEqual(setup.phase, .installRequired)
        XCTAssertEqual(environment.requests, 0)
        XCTAssertEqual(environment.opens, 0)
        XCTAssertEqual(environment.reveals, 1)
    }

    @MainActor func testClosingSetupCannotOpenManagerOrUtilityActionsWithoutPermission() throws {
        _ = NSApplication.shared
        let environment = SetupEnvironment()
        let delegate = AppDelegate(setup: AccessibilitySetupController(environment: environment))
        let changeCount = NSPasteboard.general.changeCount
        delegate.showManager()
        XCTAssertNil(delegate.window)
        let window = try XCTUnwrap(delegate.setupWindow)
        XCTAssertTrue(window.isVisible)
        window.close()
        delegate.showPhraseMenu()
        delegate.captureSelection()
        delegate.paste(Phrase(id: "fixture", categoryId: "fixture", title: "Fixture", text: "Fixture",
                              isFavorite: false, isEnabled: true, useCount: 0, sortOrder: 0))
        XCTAssertTrue(window.isVisible)
        XCTAssertNil(delegate.window)
        XCTAssertFalse(delegate.store.capturing)
        XCTAssertEqual(NSPasteboard.general.changeCount, changeCount)
        window.close()
    }

    @MainActor func testGrantAutomaticallyOpensManagerAndRevocationReturnsToSetup() throws {
        _ = NSApplication.shared
        let environment = SetupEnvironment()
        let delegate = AppDelegate(setup: AccessibilitySetupController(environment: environment))
        defer {
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            delegate.window?.close()
            delegate.setupWindow?.close()
        }
        delegate.showManager()
        XCTAssertNil(delegate.window)
        environment.accessibilityGranted = true
        delegate.setup.refresh()
        XCTAssertTrue(try XCTUnwrap(delegate.window).isVisible)
        XCTAssertFalse(try XCTUnwrap(delegate.setupWindow).isVisible)
        environment.accessibilityGranted = false
        delegate.setup.refresh()
        XCTAssertFalse(try XCTUnwrap(delegate.window).isVisible)
        XCTAssertTrue(try XCTUnwrap(delegate.setupWindow).isVisible)
        XCTAssertFalse(delegate.store.commandRightClickAvailable)
    }

    // Render the real SwiftUI card on the native runner without changing TCC or
    // introducing a permission bypass into the shipped application.
    @MainActor func testNativeSetupCardLayouts() throws {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
              let root = ProcessInfo.processInfo.environment["GITHUB_WORKSPACE"] else {
            throw XCTSkip("Native visual captures run on the disposable CI desktop.")
        }
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: root).appendingPathComponent("artifacts/macos-setup-check")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let resources = output.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let master = try String(contentsOf: URL(fileURLWithPath: root)
            .appendingPathComponent("src/CommonCopy.Mac/Assets/CommonCopyLogo.svg"), encoding: .utf8)
        try master.write(to: resources.appendingPathComponent("CommonCopyLogo.svg"), atomically: true, encoding: .utf8)
        try master.replacingOccurrences(of: "fill=\"#000000\"", with: "fill=\"#FFFFFF\"")
            .replacingOccurrences(of: "fill=\"#585858\"", with: "fill=\"#AAAAAA\"")
            .write(to: resources.appendingPathComponent("CommonCopyLogoReverse.svg"), atomically: true, encoding: .utf8)
        let environment = SetupEnvironment()
        let setup = AccessibilitySetupController(environment: environment)
        let store = Store()
        setup.refresh()
        for name in ["permission", "waiting", "manual-fallback", "install"] {
            if name == "waiting" { setup.openSettings() }
            if name == "manual-fallback" { environment.settingsAvailable = false; setup.openSettings() }
            if name == "install" { environment.installedInApplications = false; setup.refresh() }
            let view = NSHostingView(rootView: AccessibilitySetupView(setup: setup, store: store, brandResources: resources))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: view.fittingSize),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            window.center()
            window.makeKeyAndOrderFront(nil)
            XCTAssertGreaterThan(view.fittingSize.height, 400)
            XCTAssertLessThan(view.fittingSize.height, 780, "Card must fit a laptop display.")
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent(name + ".png"))
            window.close()
        }
    }
}
