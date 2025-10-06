// macos/Sources/Core/Battery/BatteryMonitor.swift
import Foundation
import IOKit.ps

/// Responsible for monitoring battery status and system uptime.
public final class BatteryMonitor {
    /// Holds battery information for display.
    public struct BatteryInfo {
        public let percentage: Double
        public let isCharging: Bool
        public let timeRemaining: TimeInterval?
        public let uptime: TimeInterval

        public init(percentage: Double, isCharging: Bool, timeRemaining: TimeInterval?, uptime: TimeInterval) {
            self.percentage = percentage
            self.isCharging = isCharging
            self.timeRemaining = timeRemaining
            self.uptime = uptime
        }
    }

    public init() {}

    /// Fetches current battery information and system uptime.
    public func fetchBatteryInfo() -> BatteryInfo? {
        let uptime = ProcessInfo.processInfo.systemUptime

        // Get battery info using IOKit
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryInfo(percentage: 0, isCharging: false, timeRemaining: nil, uptime: uptime)
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
            return BatteryInfo(percentage: 0, isCharging: false, timeRemaining: nil, uptime: uptime)
        }

        let sourcesArray = sources as [CFTypeRef]

        guard let source = sourcesArray.first else {
            return BatteryInfo(percentage: 0, isCharging: false, timeRemaining: nil, uptime: uptime)
        }

        guard let psDict = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? NSDictionary else {
            return BatteryInfo(percentage: 0, isCharging: false, timeRemaining: nil, uptime: uptime)
        }

        // Get battery percentage
        let capacity = psDict[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = psDict[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = maxCapacity > 0 ? Double(capacity) / Double(maxCapacity) * 100.0 : 0.0

        // Get charging state
        let isCharging = (psDict[kIOPSIsChargingKey] as? Bool) ?? false

        // Get time remaining
        var timeRemaining: TimeInterval? = nil
        if let timeToEmpty = psDict[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0 {
            timeRemaining = TimeInterval(timeToEmpty * 60) // Convert minutes to seconds
        } else if let timeToFull = psDict[kIOPSTimeToFullChargeKey] as? Int, timeToFull > 0 {
            timeRemaining = TimeInterval(timeToFull * 60) // Convert minutes to seconds
        }

        return BatteryInfo(
            percentage: min(100.0, max(0.0, percentage)),
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            uptime: uptime
        )
    }

    /// Formats uptime as a human-readable string.
    public static func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return String(format: "%dd %dh %dm", days, hours, minutes)
        } else if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    /// Formats time remaining as a human-readable string.
    public static func formatTimeRemaining(_ timeRemaining: TimeInterval?, isCharging: Bool) -> String {
        guard let time = timeRemaining, time > 0 else {
            return isCharging ? "Calculating..." : "Unknown"
        }

        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
