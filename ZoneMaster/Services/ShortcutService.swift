import AppKit
import Carbon.HIToolbox

/// Registers and manages global keyboard shortcuts.
/// Uses Carbon Event Manager (CGEvent tap) for global hotkey registration,
/// which works regardless of which app is focused.
final class ShortcutService: ObservableObject {
    @Published var bindings: ShortcutBindings

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Callbacks for each shortcut action
    var onMoveToNextZone: (() -> Void)?
    var onMoveToPreviousZone: (() -> Void)?
    var onMoveToZone: ((Int) -> Void)?  // zone index (0-based)
    var onToggleZones: (() -> Void)?
    var onNextProfile: (() -> Void)?

    init() {
        self.bindings = ShortcutBindings.makeDefault()
    }

    /// Start listening for global keyboard shortcuts
    func startListening() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let service = Unmanaged<ShortcutService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            print("ZoneMaster: Failed to create event tap. Accessibility permissions may be missing.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    /// Stop listening for shortcuts
    func stopListening() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let modifiers = extractModifiers(from: flags)

        // Check each binding
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToNextZone) {
            DispatchQueue.main.async { self.onMoveToNextZone?() }
            return nil // Consume the event
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToPreviousZone) {
            DispatchQueue.main.async { self.onMoveToPreviousZone?() }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToZone1) {
            DispatchQueue.main.async { self.onMoveToZone?(0) }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToZone2) {
            DispatchQueue.main.async { self.onMoveToZone?(1) }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToZone3) {
            DispatchQueue.main.async { self.onMoveToZone?(2) }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.moveToZone4) {
            DispatchQueue.main.async { self.onMoveToZone?(3) }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.toggleZones) {
            DispatchQueue.main.async { self.onToggleZones?() }
            return nil
        }
        if matches(keyCode: keyCode, modifiers: modifiers, binding: bindings.nextProfile) {
            DispatchQueue.main.async { self.onNextProfile?() }
            return nil
        }

        // Not our shortcut — pass through
        return Unmanaged.passRetained(event)
    }

    private func matches(keyCode: UInt16, modifiers: UInt, binding: KeyboardShortcut) -> Bool {
        guard binding.keyCode != 0 else { return false }
        return keyCode == binding.keyCode && modifiers == binding.modifiers
    }

    /// Extract modifier flags relevant for shortcut matching
    private func extractModifiers(from flags: CGEventFlags) -> UInt {
        var result: UInt = 0
        if flags.contains(.maskControl) { result |= 0x40000 }    // NSEvent.ModifierFlags.control
        if flags.contains(.maskAlternate) { result |= 0x80000 }  // NSEvent.ModifierFlags.option
        if flags.contains(.maskShift) { result |= 0x20000 }      // NSEvent.ModifierFlags.shift
        if flags.contains(.maskCommand) { result |= 0x100000 }   // NSEvent.ModifierFlags.command
        return result
    }

    /// Update bindings and re-register
    func updateBindings(_ newBindings: ShortcutBindings) {
        bindings = newBindings
    }
}
