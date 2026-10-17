import AppKit
import ApplicationServices

enum RightClickEdge { case down, up }
struct CommandClickDecision: Equatable {
    let suppress: Bool
    let activate: Bool
}

// Listen only to right-mouse events. Modifier state comes from the mouse event;
// no keyboard-event stream or typed text is requested or recorded.
struct CommandClickMatcher {
    private var armed = false
    mutating func handle(_ edge: RightClickEdge, commandHeld: Bool) -> CommandClickDecision {
        switch edge {
        case .down:
            armed = commandHeld
            return CommandClickDecision(suppress: armed, activate: false)
        case .up:
            let matched = armed
            armed = false
            return CommandClickDecision(suppress: matched, activate: matched)
        }
    }
    mutating func reset() { armed = false }
}

// The event source and callback run on the main CFRunLoop. Keep the callback
// small: decide whether to suppress synchronously, then schedule the UI action.
final class CommandRightClickService {
    var onActivate: (@MainActor () -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var matcher = CommandClickMatcher()

    func start() -> Bool {
        guard AXIsProcessTrusted() else { stop(); return false }
        if let tap, CFMachPortIsValid(tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            return CGEvent.tapIsEnabled(tap: tap)
        }
        stop()
        let mask = (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<CommandRightClickService>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                service.matcher.reset()
                if AXIsProcessTrusted(), let tap = service.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .rightMouseDown || type == .rightMouseUp else { return Unmanaged.passUnretained(event) }
            let decision = service.matcher.handle(type == .rightMouseDown ? .down : .up,
                commandHeld: event.flags.contains(.maskCommand))
            if decision.activate {
                DispatchQueue.main.async { service.onActivate?() }
            }
            return decision.suppress ? nil : Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else { return false }
        tap = created
        source = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return CGEvent.tapIsEnabled(tap: created)
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        matcher.reset()
    }
}
