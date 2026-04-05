import AppKit
import SwiftUI

@MainActor
final class OverlayManager {
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func show(_ type: ReminderType) {
        dismissImmediately()

        NSSound(named: "Tink")?.play()

        let view = OverlayIconView(type: type, onDismiss: { [weak self] in
            self?.dismiss()
        })
        let hosting = NSHostingView(rootView: view)

        let size = CGSize(width: 200, height: 200)
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        let w = OverlayWindow(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.contentView = hosting
        w.alphaValue = 0
        w.orderFrontRegardless()
        self.window = w

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            w.animator().alphaValue = 1
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        guard let w = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            w.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            w.orderOut(nil)
            w.close()
            self?.window = nil
        })
    }

    private func dismissImmediately() {
        dismissTask?.cancel()
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
