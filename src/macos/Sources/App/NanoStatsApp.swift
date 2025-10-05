// macos/Sources/App/NanoStatsApp.swift
import AppKit
import SwiftUI

/// Main application class that manages the status bar item and SwiftUI menu.
public final class NanoStatsApp: NSObject {
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let app: NSApplication
    private var memoryDataModel: MemoryDataModel
    private var memoryUpdateTimer: Timer?
    private var popover: NSPopover?

    public init(withTitle _: String) {
        assert(Thread.isMainThread, "NanoStatsApp must be initialized on the main thread.")

        app = NSApplication.shared
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        memoryDataModel = MemoryDataModel()

        super.init()

        setupStatusItem()
        setupPopover()

        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil {
            app.setActivationPolicy(.accessory)
        }

        // Start monitoring
        startMemoryMonitoring()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else {
            assertionFailure("Failed to get status item button.")
            return
        }

        // Set initial title
        updateStatusBarTitle()

        button.target = self
        button.action = #selector(statusItemClicked)
        button.isEnabled = true
    }

    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }

        let percentage = Int(memoryDataModel.usagePercentage)
        let icon: String
        let color: NSColor

        if memoryDataModel.usagePercentage > 85 {
            icon = "􀫖" // memorychip.fill
            color = .systemRed
        } else if memoryDataModel.usagePercentage > 70 {
            icon = "􀫖"
            color = .systemOrange
        } else if memoryDataModel.usagePercentage > 50 {
            icon = "􀫖"
            color = .systemYellow
        } else {
            icon = "􀫖"
            color = .labelColor
        }

        let text = "\(icon) \(percentage)%"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: color,
        ]

        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.animates = true

        // Create SwiftUI view for popover
        let menuView = MenuBarView(memoryMonitor: memoryDataModel)
        popover.contentViewController = NSHostingController(rootView: menuView)

        self.popover = popover
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh data before showing
            memoryDataModel.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func startMemoryMonitoring() {
        // Initial update
        memoryDataModel.refresh()
        updateStatusBarTitle()

        // Set up timer for periodic updates (every 2 seconds)
        memoryUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.memoryDataModel.refresh()
            self?.updateStatusBarTitle()
        }

        if let timer = memoryUpdateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    public func run() {
        assert(Thread.isMainThread, "run() must be called on the main thread.")
        print("NanoStats is running. Check your menu bar!")
        app.run()
    }

    public func cleanup() {
        memoryUpdateTimer?.invalidate()
        memoryUpdateTimer = nil
        popover?.performClose(nil)
    }
}
