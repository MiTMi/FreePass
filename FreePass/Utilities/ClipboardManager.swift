import AppKit
import Combine

/// Manages clipboard operations with auto-clear for security.
@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()
    private var clearTimer: Timer?
    private var clearDelay: TimeInterval {
        if UserDefaults.standard.object(forKey: "clearClipboardDelay") == nil {
            return 30
        }
        return UserDefaults.standard.double(forKey: "clearClipboardDelay")
    }

    private init() {}

    /// Copies a string to the clipboard and schedules auto-clear after 30 seconds.
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        scheduleClear()
    }

    /// Clears the clipboard immediately.
    func clear() {
        NSPasteboard.general.clearContents()
        clearTimer?.invalidate()
        clearTimer = nil
    }

    private func scheduleClear() {
        clearTimer?.invalidate()
        let delay = clearDelay
        if delay > 0 {
            clearTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.clear()
                }
            }
        }
    }
}
