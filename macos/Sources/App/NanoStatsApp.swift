// macos/Sources/App/NanoStatsApp.swift
import AppKit
import Foundation
import QuartzCore

/// Main application class that manages the status bar item and menu.
public final class NanoStatsApp: NSObject, NSMenuDelegate {
  // MARK: - Properties
  private let status_bar: NSStatusBar
  private let status_item: NSStatusItem
  private let app: NSApplication
  private var memory_update_timer: Timer?
  private let process_menu: NSMenu
  private var total_physical_memory_bytes: UInt64 = 0
  private var status_view: MemoryStatusView?
  // Memory usage history for sparkline
  private var usage_history: [Double] = []
  private let max_history_points: Int = 180


  // Monitors
  private let memory_monitor = SystemMemoryMonitor()
  private let process_monitor = ProcessMemoryMonitor()

  // Configuration
  private let memory_update_interval_seconds: TimeInterval = 2.0
  private let top_process_count: Int = 5
  private let status_item_width: CGFloat = 40.0

  // State
  private var showingDetails: Bool = false

  // MARK: - Initialization
  public init(withTitle title: String) {
    assert(Thread.isMainThread, "NanoStatsApp must be initialized on the main thread.")

    self.app = NSApplication.shared
    self.status_bar = NSStatusBar.system
    self.status_item = self.status_bar.statusItem(withLength: status_item_width)
    self.process_menu = NSMenu()

    super.init()

    self.total_physical_memory_bytes = memory_monitor.fetchTotalPhysicalMemory()
    assert(self.total_physical_memory_bytes > 0, "Failed to fetch total physical memory at init.")

    setupStatusItem()
    setupMenu()

    if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil {
      self.app.setActivationPolicy(.accessory)
    }

    // Observe appearance changes to update UI
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appearanceChanged),
      name: Notification.Name("NSApplicationDidChangeEffectiveAppearanceNotification"),
      object: nil
    )

    updateMemoryDisplay()
  }

  // MARK: - Setup Methods
  private func setupStatusItem() {
    guard let button = self.status_item.button else {
      assertionFailure("Failed to get status item button.")
      return
    }

    // Create and configure custom view
    let custom_view = MemoryStatusView(
      frame: NSRect(x: 0, y: 0, width: status_item_width, height: 22))
    self.status_view = custom_view

    // Set the custom view as the status item's view
    button.subviews.forEach { $0.removeFromSuperview() }
    button.addSubview(custom_view)

    // Make the custom view resize with the button
    custom_view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      custom_view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      custom_view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
      custom_view.topAnchor.constraint(equalTo: button.topAnchor),
      custom_view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
    ])
  }

  private func setupMenu() {
    self.process_menu.delegate = self
    self.status_item.menu = self.process_menu
  }

  // MARK: - Public API
  public func run() {
    assert(Thread.isMainThread, "run() must be called on the main thread.")

    self.memory_update_timer = Timer.scheduledTimer(
      withTimeInterval: memory_update_interval_seconds,
      repeats: true
    ) { [weak self] _ in
      DispatchQueue.main.async {
        guard let strongSelf = self else { return }
        strongSelf.updateMemoryDisplay()
      }
    }

    if let timer = self.memory_update_timer {
      RunLoop.main.add(timer, forMode: .common)
    } else {
      assertionFailure("Failed to create memory update timer.")
    }

    self.app.run()
  }

  public func cleanup() {
    self.memory_update_timer?.invalidate()
    self.memory_update_timer = nil

    if self.status_bar.statusItem(withLength: status_item_width) === self.status_item {
      self.status_bar.removeStatusItem(self.status_item)
    }
  }

  // MARK: - Menu Delegate
  public func menuWillOpen(_ menu: NSMenu) {
    assert(Thread.isMainThread, "menuWillOpen must be called on the main thread.")
    assert(menu === self.process_menu, "Delegate called for unexpected menu.")

    buildMenu()
  }

  // MARK: - Private Methods
  private func buildMenu() {
    process_menu.removeAllItems()

    // Ensure enough width for the sparkline menu item
    process_menu.minimumWidth = max(process_menu.minimumWidth, 280)

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .memory
    formatter.zeroPadsFractionDigits = false
    formatter.isAdaptive = true

    // Memory Overview - Simplified
    if let breakdown = memory_monitor.fetchMemoryBreakdown() {
      // Total with usage percentage
      let total_item = NSMenuItem(
        title: "Memory: \(formatter.string(fromByteCount: Int64(breakdown.total_bytes)))",
        action: nil,
        keyEquivalent: ""
      )
      total_item.isEnabled = false
      process_menu.addItem(total_item)

      // Visual indicator
      addMemoryUsageSparkline()

      // Key metrics users care about
      addDisabledMenuItem(
        title: "Used: \(formatter.string(fromByteCount: Int64(breakdown.used_bytes)))")
      addDisabledMenuItem(
        title: "Available: \(formatter.string(fromByteCount: Int64(breakdown.free_bytes)))")

      // Add "Show Details..." option for power users
      if showingDetails {
        process_menu.addItem(NSMenuItem.separator())
        addDisabledMenuItem(title: "Memory Details")
        addDisabledMenuItem(
          title: "  Active: \(formatter.string(fromByteCount: Int64(breakdown.active_bytes)))")
        addDisabledMenuItem(
          title: "  Wired: \(formatter.string(fromByteCount: Int64(breakdown.wired_bytes)))")
        addDisabledMenuItem(
          title: "  Inactive: \(formatter.string(fromByteCount: Int64(breakdown.inactive_bytes)))")
        addDisabledMenuItem(
          title:
            "  Compressed: \(formatter.string(fromByteCount: Int64(breakdown.compressed_bytes)))")
      }

      // Toggle for showing details
      process_menu.addItem(NSMenuItem.separator())
      let details_item = NSMenuItem(
        title: showingDetails ? "Hide Details" : "Show Details...",
        action: #selector(toggleDetails),
        keyEquivalent: ""
      )
      details_item.target = self
      process_menu.addItem(details_item)
    } else {
      addDisabledMenuItem(title: "Could not fetch memory details")
    }

    // Process List - Streamlined
    process_menu.addItem(NSMenuItem.separator())
    addDisabledMenuItem(title: "Apps Using Memory")

    guard self.total_physical_memory_bytes > 0 else {
      addDisabledMenuItem(title: "Error: Could not determine memory usage")
      process_menu.addItem(NSMenuItem.separator())
      addQuitItem()
      return
    }

    // Get top processes
    let top_processes = process_monitor.fetchTopMemoryProcesses(
      limit: top_process_count,
      totalPhysicalMemory: self.total_physical_memory_bytes
    )

    if top_processes.isEmpty {
      addDisabledMenuItem(title: "No significant memory usage detected")
    } else {
      // Add processes - Apple style with subtitles
      for process in top_processes {
        let memory_str = formatter.string(fromByteCount: Int64(process.memory_usage_bytes))

        // Create menu item with app name and memory as subtitle
        let percentage_str = String(format: "%.1f%%", process.memory_usage_percentage)
        let title = "\(process.name) — \(memory_str) (\(percentage_str))"
        let menu_item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

        // Use subtitle if available (macOS 11+), otherwise fall back to title with dash


        // Add to menu
        process_menu.addItem(menu_item)
      }

      // Option to open Activity Monitor
      process_menu.addItem(NSMenuItem.separator())
      let activity_monitor_item = NSMenuItem(
        title: "Open Activity Monitor...",
        action: #selector(openActivityMonitor),
        keyEquivalent: ""
      )
      activity_monitor_item.target = self
      process_menu.addItem(activity_monitor_item)
    }

    // Add memory pressure warning if needed
    if let breakdown = memory_monitor.fetchMemoryBreakdown(), breakdown.usage_percentage > 85 {
      process_menu.addItem(NSMenuItem.separator())

      let high_usage_item = NSMenuItem(
        title: "Memory pressure is high",
        action: #selector(showMemoryTips),
        keyEquivalent: ""
      )
      high_usage_item.target = self
      process_menu.addItem(high_usage_item)
    }

    // Quit item
    process_menu.addItem(NSMenuItem.separator())
    addQuitItem()
  }

  private func addMemoryUsageBar(percentage: Double) {
    // Full-width system-colored memory bar with subtle gradient sparkle
    let width = max(process_menu.minimumWidth, 280)
    let height: CGFloat = 28

    let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

    let marginX: CGFloat = 12
    let barHeight: CGFloat = 6
    let trackX = marginX
    let trackWidth = width - (marginX * 2)
    let trackY = (height - barHeight) / 2

    // Track
    let track = NSView(frame: NSRect(x: trackX, y: trackY, width: trackWidth, height: barHeight))
    track.wantsLayer = true
    track.layer?.cornerRadius = barHeight / 2
    track.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor

    // Fill
    let fillWidth = max(0, min(trackWidth, (CGFloat(percentage) / 100.0) * trackWidth))
    let fill = NSView(frame: NSRect(x: trackX, y: trackY, width: fillWidth, height: barHeight))
    fill.wantsLayer = true
    fill.layer?.cornerRadius = barHeight / 2

    let baseColor: NSColor
    if percentage > 85 {
      baseColor = NSColor.systemRed
    } else if percentage > 60 {
      baseColor = NSColor.systemOrange
    } else if #available(macOS 10.14, *) {
      baseColor = NSColor.controlAccentColor
    } else {
      baseColor = NSColor.systemBlue
    }

    if let layer = fill.layer {
      let gradient = CAGradientLayer()
      gradient.frame = layer.bounds
      gradient.colors = [
        baseColor.withAlphaComponent(0.9).cgColor,
        baseColor.withAlphaComponent(0.35).cgColor
      ]
      gradient.startPoint = CGPoint(x: 0, y: 0.5)
      gradient.endPoint = CGPoint(x: 1, y: 0.5)
      gradient.cornerRadius = barHeight / 2

      // Subtle sparkle/glow
      layer.shadowColor = baseColor.withAlphaComponent(0.6).cgColor
      layer.shadowOpacity = 0.6
      layer.shadowRadius = 3
      layer.shadowOffset = .zero

      layer.addSublayer(gradient)
      layer.masksToBounds = true
      layer.backgroundColor = NSColor.clear.cgColor
    }

    container.addSubview(track)
    container.addSubview(fill)

    let menu_item = NSMenuItem()
    menu_item.view = container
    process_menu.addItem(menu_item)
  }
  
  private func addMemoryUsageSparkline() {
    let width = max(process_menu.minimumWidth, 280)
    let height: CGFloat = 28
    let marginX: CGFloat = 8
    let marginY: CGFloat = 4
    let sparkFrame = NSRect(
      x: marginX,
      y: marginY,
      width: width - (marginX * 2),
      height: height - (marginY * 2)
    )
    let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    let spark = SparklineView(frame: sparkFrame)
    spark.yScaleMode = SparklineView.YScaleMode.unit
    spark.lineColorMode = SparklineView.LineColorMode.memoryPressure
    spark.showsGradientFill = true
    spark.setValues(usage_history, capToMax: true)
    container.addSubview(spark)
    let menu_item = NSMenuItem()
    menu_item.view = container
    process_menu.addItem(menu_item)
  }

  private func addDisabledMenuItem(title: String) {
    let menu_item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    menu_item.isEnabled = false
    process_menu.addItem(menu_item)
  }

  private func addQuitItem() {
    let quit_item = NSMenuItem(
      title: "Quit NanoStats",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quit_item.target = NSApp
    process_menu.addItem(quit_item)
  }

  private func updateMemoryDisplay() {
    if let breakdown = memory_monitor.fetchMemoryBreakdown() {
      let v = breakdown.usage_percentage / 100.0
      usage_history.append(v)
      if usage_history.count > max_history_points {
        usage_history.removeFirst(usage_history.count - max_history_points)
      }

      if let status_view = self.status_view {
        status_view.updatePercentage(breakdown.usage_percentage)
      } else if let button = self.status_item.button {
        // Fallback if custom view isn't available
        button.title = String(format: "RAM: %.1f%%", breakdown.usage_percentage)
      }
    } else {
      if let button = self.status_item.button {
        button.title = "RAM: Error"
      }
    }
  }

  @objc private func openActivityMonitor() {
    let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
    NSWorkspace.shared.open(url)
  }

  @objc private func toggleDetails() {
    showingDetails = !showingDetails
    // Refresh menu
    if let menu = status_item.menu {
      self.menuWillOpen(menu)
    }
  }

  @objc private func showMemoryTips() {
    // In a full implementation, this would show a window with memory optimization tips
    let alert = NSAlert()
    alert.messageText = "Memory Usage Tips"
    alert.informativeText =
      "• Close applications you're not using\n• Restart applications that have been running for a long time\n• Check Activity Monitor for memory-intensive processes"
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Open Activity Monitor")

    let response = alert.runModal()
    if response == NSApplication.ModalResponse.alertSecondButtonReturn {
      openActivityMonitor()
    }
  }

  @objc private func appearanceChanged() {
    // Update the status view when appearance changes
    updateMemoryDisplay()
  }
}
