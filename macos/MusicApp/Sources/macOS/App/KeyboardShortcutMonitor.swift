import AppKit

/// Installs an NSEvent local monitor so a few unmodified keys act as
/// playback shortcuts: Space (play/pause), ← (previous), → (next).
///
/// Events are forwarded unchanged when any of these is true, so typing in
/// a text field or using ⌘-menu shortcuts keeps working:
///   - the first responder is a text editor (NSText, NSTextView, NSSearchField);
///   - any of Command / Option / Control is held;
///   - the key is not one we care about.
@MainActor
final class KeyboardShortcutMonitor {
    private var monitor: Any?
    private weak var player: AudioEngine?

    func attach(player: AudioEngine) {
        self.player = player
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func detach() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Don't steal keys while the user is typing or while a menu shortcut
        // is being issued — both have legitimate uses for these keys.
        if isEditingText() { return event }
        if !event.modifierFlags.intersection([.command, .option, .control]).isEmpty { return event }

        guard let player else { return event }

        switch event.keyCode {
        case 49: // Space
            player.togglePlayPause()
            return nil
        case 123: // Left arrow
            player.previous()
            return nil
        case 124: // Right arrow
            player.next()
            return nil
        default:
            return event
        }
    }

    private func isEditingText() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        // NSTextField uses a shared field editor (an NSTextView) as the first
        // responder; checking NSText covers both NSTextField and NSTextView.
        return responder is NSText
            || responder is NSTextView
            || responder is NSSearchField
    }
}
