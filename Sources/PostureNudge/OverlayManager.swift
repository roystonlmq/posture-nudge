import AppKit
import SwiftUI

@MainActor
protocol OverlayShowing {
    func show(_ type: ReminderType)
    func dismiss()
}

@MainActor
final class OverlayManager: OverlayShowing {
    private var windows: [NSWindow] = []
    private var dismissTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var queue: [ReminderType] = []
    private var isShowing = false

    // Observable countdown for break overlay
    private var breakCountdown: BreakCountdown?

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

        if type == .eyeBreak {
            showBreakOverlay()
        } else {
            showIconOverlay(type)
        }
    }

    // MARK: - Icon overlay (posture, blink)

    private func showIconOverlay(_ type: ReminderType) {
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

            let w = makeWindow(frame: CGRect(origin: origin, size: size))
            w.ignoresMouseEvents = false
            w.contentView = hosting
            showWindow(w)
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismissAndShowNext()
        }
    }

    // MARK: - Break overlay (eye break - full screen, blocking)

    private func showBreakOverlay() {
        let countdown = BreakCountdown(seconds: 20)
        self.breakCountdown = countdown

        for screen in NSScreen.screens {
            let hostView = BreakOverlayHostView(countdown: countdown, onSkip: { [weak self] in
                self?.dismiss()
            })
            let hosting = NSHostingView(rootView: hostView)

            let w = makeWindow(frame: screen.frame)
            w.ignoresMouseEvents = false
            w.contentView = hosting
            showWindow(w)
        }

        // Countdown timer
        countdownTask = Task {
            while countdown.remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown.remaining -= 1
            }
            dismissAndShowNext()
        }
    }

    // MARK: - Window helpers

    private func makeWindow(frame: CGRect) -> NSWindow {
        let w = OverlayWindow(
            contentRect: frame,
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
        windows.append(w)
        return w
    }

    private func showWindow(_ w: NSWindow) {
        w.alphaValue = 0
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            w.animator().alphaValue = 1
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        dismissAndShowNext()
    }

    private func dismissAndShowNext() {
        dismissTask?.cancel()
        countdownTask?.cancel()
        breakCountdown = nil

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

// MARK: - Break countdown model

@MainActor
final class BreakCountdown: ObservableObject {
    @Published var remaining: Int

    init(seconds: Int) {
        self.remaining = seconds
    }
}

// MARK: - Host view that observes countdown

private struct BreakOverlayHostView: View {
    @ObservedObject var countdown: BreakCountdown
    let onSkip: () -> Void

    var body: some View {
        BreakOverlayView(remainingSeconds: countdown.remaining, onSkip: onSkip)
    }
}

// MARK: - Window subclass

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
