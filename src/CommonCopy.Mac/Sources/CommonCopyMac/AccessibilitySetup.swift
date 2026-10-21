import AppKit
import ApplicationServices
import SwiftUI

enum AccessibilitySetupPhase: Equatable {
    case checking, installRequired, permissionRequired, ready
}

@MainActor
protocol AccessibilitySetupEnvironment {
    var installedInApplications: Bool { get }
    var accessibilityGranted: Bool { get }
    func requestAccessibility()
    func openAccessibilitySettings() -> Bool
    func revealApplication()
}

@MainActor
final class MacAccessibilitySetupEnvironment: AccessibilitySetupEnvironment {
    var installedInApplications: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL.path
        let roots = ["/Applications", NSHomeDirectory() + "/Applications"]
        return roots.contains { path.hasPrefix($0 + "/") } && path.hasSuffix(".app")
    }
    var accessibilityGranted: Bool { AXIsProcessTrusted() }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
        return NSWorkspace.shared.open(url)
    }
    func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}

// Permission is read from macOS, never from a remembered 'setup completed' flag.
// Polling never prompts, posts input, reads the clipboard, or edits the library.
@MainActor
final class AccessibilitySetupController: ObservableObject {
    @Published private(set) var phase: AccessibilitySetupPhase = .checking
    @Published private(set) var settingsOpened = false
    @Published private(set) var settingsError: String?
    var onPhaseChanged: ((AccessibilitySetupPhase) -> Void)?
    private let environment: AccessibilitySetupEnvironment
    private var requestedPermission = false

    convenience init() { self.init(environment: MacAccessibilitySetupEnvironment()) }
    init(environment: AccessibilitySetupEnvironment) { self.environment = environment }

    func refresh() {
        let next: AccessibilitySetupPhase = !environment.installedInApplications ? .installRequired
            : environment.accessibilityGranted ? .ready : .permissionRequired
        guard next != phase else { return }
        phase = next
        settingsOpened = false
        settingsError = nil
        if next == .permissionRequired { requestedPermission = false }
        onPhaseChanged?(next)
    }

    func openSettings() {
        refresh()
        guard phase == .permissionRequired else { return }
        if !requestedPermission {
            requestedPermission = true
            environment.requestAccessibility()
        }
        settingsOpened = environment.openAccessibilitySettings()
        settingsError = settingsOpened ? nil
            : "Open System Settings → Privacy & Security → Accessibility, then enable CommonCopy."
        refresh()
    }

    func revealApplication() { environment.revealApplication() }
}

struct AccessibilitySetupView: View {
    @ObservedObject var setup: AccessibilitySetupController
    @ObservedObject var store: Store
    var brandResources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
    private var palette: Palette { Palette(dark: store.dark) }
    private var needsInstall: Bool { setup.phase == .installRequired }

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(spacing: 11) {
                BrandMark(resourceDirectory: brandResources)
                VStack(alignment: .leading, spacing: 4) {
                    Text("CommonCopy").font(.system(size: 18, weight: .semibold))
                    Text("Save it once. Paste it forever.").font(.system(size: 11)).foregroundColor(palette.muted)
                }
            }
            Rectangle().fill(palette.border).frame(height: 0.7)
            VStack(alignment: .leading, spacing: 11) {
                Text(needsInstall ? "A place to call home." : "One quick step.")
                    .font(.system(size: 31, weight: .medium))
                Text(needsInstall
                     ? "Drag CommonCopy into Applications, then open it from there to finish setup."
                     : "Enable Accessibility so CommonCopy can open with Command + right-click, paste phrases, and save highlighted text.")
                    .font(.system(size: 13)).foregroundColor(palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 17) {
                if needsInstall {
                    step("1", "Drag to Applications", "Use the Applications folder in the installer window.")
                    step("2", "Open CommonCopy", "Quit this copy, then launch the installed app from Applications.")
                } else {
                    step("1", "Open Accessibility settings", "We’ll take you to the right place in System Settings.")
                    step("2", "Enable CommonCopy", "Turn on the switch beside CommonCopy. Your Mac may ask you to unlock settings.")
                    step("3", "You’re ready", "CommonCopy will continue automatically when access is enabled.")
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.border, lineWidth: 0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Group {
                if let error = setup.settingsError {
                    Text(error).font(.system(size: 12)).foregroundColor(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if setup.settingsOpened && !needsInstall {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for Accessibility access…").font(.system(size: 12))
                    }.foregroundColor(palette.muted)
                } else {
                    Color.clear
                }
            }.frame(height: 34, alignment: .leading)
            if needsInstall {
                HStack(spacing: 10) {
                    Button("Show CommonCopy in Finder") { setup.revealApplication() }
                        .buttonStyle(MonochromeButton(palette: palette, filled: true))
                    Button("Quit CommonCopy") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(MonochromeButton(palette: palette, filled: false))
                }
            } else {
                Button(setup.settingsOpened ? "Open Accessibility Settings Again" : "Open Accessibility Settings") {
                    setup.openSettings()
                }.buttonStyle(MonochromeButton(palette: palette, filled: true))
                    .accessibilityIdentifier("open-accessibility-settings")
            }
            Text(needsInstall ? "Your saved phrases stay on this Mac."
                 : "Access is used for the actions you choose. CommonCopy doesn’t record your typing or keep clipboard history.")
                .font(.system(size: 11)).foregroundColor(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(29).frame(width: 500, alignment: .leading)
        .foregroundColor(palette.text).background(palette.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.border, lineWidth: 0.7))
        .padding(12).background(palette.surface)
        .preferredColorScheme(store.dark ? .dark : .light)
        .accessibilityIdentifier("commoncopy-accessibility-setup")
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(palette.border, lineWidth: 0.7))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundColor(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
