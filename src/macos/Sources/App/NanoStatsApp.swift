// macos/Sources/App/NanoStatsApp.swift
import SwiftUI
import AppKit

/// Main application class that manages the status bar item and SwiftUI menu.
public final class NanoStatsApp: NSObject {
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let app: NSApplication
    private var memoryDataModel: MemoryDataModel
    private var memoryUpdateTimer: Timer?
    private var popover: NSPopover?

    public init(withTitle title: String) {
        assert(Thread.isMainThread, "NanoStatsApp must be initialized on the main thread.")

        self.app = NSApplication.shared
        self.statusBar = NSStatusBar.system
        self.statusItem = self.statusBar.statusItem(withLength: NSStatusItem.variableLength)
        self.memoryDataModel = MemoryDataModel()

        super.init()

        setupStatusItem()
        setupPopover()

        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil {
            self.app.setActivationPolicy(.accessory)
        }

        // Start monitoring
        startMemoryMonitoring()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else {
            assertionFailure("Failed to get status item button.")
            return
        }

        // Create SwiftUI view for status bar
        let statusView = StatusBarLabel(memoryData: memoryDataModel)
        let hostingView = NSHostingView(rootView: statusView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 60, height: 22)

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        button.target = self
        button.action = #selector(statusItemClicked)
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

        // Set up timer for periodic updates (every 2 seconds)
        memoryUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.memoryDataModel.refresh()
        }

        if let timer = memoryUpdateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    public func run() {
        assert(Thread.isMainThread, "run() must be called on the main thread.")
        print("NanoStats is running. Check your menu bar!")
        self.app.run()
    }

    public func cleanup() {
        memoryUpdateTimer?.invalidate()
        memoryUpdateTimer = nil
        popover?.performClose(nil)
    }
}

// MARK: - Status Bar Label

struct StatusBarLabel: View {
    @ObservedObject var memoryData: MemoryDataModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForPercentage(memoryData.usagePercentage))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(colorForPercentage(memoryData.usagePercentage))

            Text("\(Int(memoryData.usagePercentage))%")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(colorForPercentage(memoryData.usagePercentage))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func iconForPercentage(_ percentage: Double) -> String {
        if percentage > 85 {
            return "memorychip.fill"
        } else {
            return "memorychip"
        }
    }

    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage > 85 {
            return .red
        } else if percentage > 70 {
            return .orange
        } else if percentage > 50 {
            return .yellow
        } else {
            return .primary
        }
    }
}
