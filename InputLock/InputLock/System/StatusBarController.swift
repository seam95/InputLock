import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let clipboardWindowController: ClipboardWindowController
    private let lockState: LockStateManager
    private var cancellable: AnyCancellable?
    private var blueDotView: NSView?

    init(
        state: AppState,
        clipboardWindowController: ClipboardWindowController
    ) {
        self.clipboardWindowController = clipboardWindowController
        self.lockState = state.lockState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let hostingController = NSHostingController(
            rootView: ControlCenterContainerView(state: state)
        )
        hostingController.sizingOptions = .preferredContentSize

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController
        self.popover = popover

        super.init()

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.action = #selector(togglePopover)
            button.target = self
            setupBlueDot(in: button)
        }

        // 监听锁定状态变化，切换蓝色圆点显隐
        cancellable = lockState.$isLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                self?.blueDotView?.isHidden = !isLocked
            }
    }

    func toggleClipboardPanel() {
        if popover.isShown {
            popover.performClose(nil)
        }
        clipboardWindowController.toggleVisibility()
    }

    func showClipboardPanel() {
        if popover.isShown {
            popover.performClose(nil)
        }
        clipboardWindowController.show()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - 蓝色圆点指示器

    /// 在菜单栏按钮右下角创建蓝色圆点，用于指示锁定状态
    private func setupBlueDot(in button: NSStatusBarButton) {
        let dotSize: CGFloat = 6.0
        let dot = BlueDotView(frame: NSRect(
            x: button.bounds.width - dotSize - 1,
            y: 1,
            width: dotSize,
            height: dotSize
        ))
        dot.autoresizingMask = [.minXMargin, .maxYMargin]
        dot.isHidden = !lockState.isLocked
        button.addSubview(dot)
        blueDotView = dot
    }
}

// MARK: - 蓝色圆点视图

private class BlueDotView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }
}
