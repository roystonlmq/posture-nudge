import AppKit
import SwiftUI

@MainActor
final class OverlayManager {
    private var windows: [NSWindow] = []
    private var dismissTask: Task<Void, Never>?
    private var queue: [ReminderType] = []
    private var isShowing = false

    func show(_ type: ReminderType) {
        queue.append(type)
        if !isShowing {
            showNext()
        }
    }

    private func showNext() {
        guard let type = queue.first else {
            isShowing = false
            return
        }
        queue.removeFirst()
        isShowing = true

        NSSound(named: "Tink")?.play()

        // Create a window on every screen
        let size = CGSize(width: 200, height: 200)
        for screen in NSScreen.screens {
            let view = OverlayIconView(type: type, onDismiss: { [weak self] in
                self?.dismiss()
            })
            let hosting = NSHostingView(rootView: view)

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
            w.isReleasedWhenClosed = false
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = false
            w.contentView = hosting
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                w.animator().alphaValue = 1
            }
        }

        // Auto-dismiss after 4s, then show next in queue
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismissAndShowNext()
        }
    }

    func dismiss() {
        dismissAndShowNext()
    }

    private func dismissAndShowNext() {
        dismissTask?.cancel()
        let current = windows
        windows = []

        for w in current {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                w.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    w.orderOut(nil)
                }
            })
        }

        // Small gap before next overlay so they feel distinct
        if !queue.isEmpty {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                showNext()
            }
        } else {
            isShowing = false
        }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
