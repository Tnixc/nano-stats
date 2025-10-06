// macos/Sources/Core/CPU/CPUMonitor.swift
import Darwin
import Foundation

/// Responsible for monitoring system-wide and per-process CPU usage.
public final class CPUMonitor {
    /// Holds CPU usage information for display.
    public struct CPUUsage {
        public let userPercentage: Double
        public let systemPercentage: Double
        public let totalPercentage: Double

        public init(userPercentage: Double, systemPercentage: Double, totalPercentage: Double) {
            self.userPercentage = userPercentage
            self.systemPercentage = systemPercentage
            self.totalPercentage = totalPercentage
        }
    }

    /// Holds information about a process's CPU usage.
    public struct ProcessCPUDetails: Comparable, Hashable {
        public let pid: pid_t
        public let name: String
        public let cpuPercentage: Double

        public init(pid: pid_t, name: String, cpuPercentage: Double) {
            self.pid = pid
            self.name = name
            self.cpuPercentage = cpuPercentage
        }

        public static func < (lhs: ProcessCPUDetails, rhs: ProcessCPUDetails) -> Bool {
            return lhs.cpuPercentage > rhs.cpuPercentage
        }

        public static func == (lhs: ProcessCPUDetails, rhs: ProcessCPUDetails) -> Bool {
            return lhs.pid == rhs.pid
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(pid)
        }
    }

    private var previousCPUInfo: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var lastUpdateTime: Date?

    public init() {}

    /// Fetches current system-wide CPU usage.
    public func fetchCPUUsage() -> CPUUsage? {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return nil
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0 ..< Int(numCPUs) {
            let cpuLoadInfo = cpuInfo.advanced(by: Int(i) * Int(CPU_STATE_MAX))
            totalUser += UInt64(cpuLoadInfo[Int(CPU_STATE_USER)])
            totalSystem += UInt64(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            totalNice += UInt64(cpuLoadInfo[Int(CPU_STATE_NICE)])
        }

        let currentInfo = (user: totalUser, system: totalSystem, idle: totalIdle, nice: totalNice)

        guard let previous = previousCPUInfo else {
            previousCPUInfo = currentInfo
            lastUpdateTime = Date()
            return CPUUsage(userPercentage: 0, systemPercentage: 0, totalPercentage: 0)
        }

        let userDelta = Double(currentInfo.user - previous.user)
        let systemDelta = Double(currentInfo.system - previous.system)
        let idleDelta = Double(currentInfo.idle - previous.idle)
        let niceDelta = Double(currentInfo.nice - previous.nice)

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

        guard totalDelta > 0 else {
            return CPUUsage(userPercentage: 0, systemPercentage: 0, totalPercentage: 0)
        }

        let userPercentage = (userDelta / totalDelta) * 100.0
        let systemPercentage = (systemDelta / totalDelta) * 100.0
        let totalPercentage = ((userDelta + systemDelta + niceDelta) / totalDelta) * 100.0

        previousCPUInfo = currentInfo
        lastUpdateTime = Date()

        return CPUUsage(
            userPercentage: max(0, min(100, userPercentage)),
            systemPercentage: max(0, min(100, systemPercentage)),
            totalPercentage: max(0, min(100, totalPercentage))
        )
    }

    /// Fetches top processes by CPU usage.
    public func fetchTopCPUProcesses(limit: Int) -> [ProcessCPUDetails] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,pcpu,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processDetails: [ProcessCPUDetails] = []

            // Skip header line
            let lines = output.split(separator: "\n").dropFirst()

            for line in lines {
                let components = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard components.count >= 3 else { continue }

                guard let pid = pid_t(components[0]),
                      let cpuPercentage = Double(components[1]) else { continue }

                let command = String(components[2])
                let processName = URL(fileURLWithPath: String(command)).lastPathComponent

                // Only include processes with meaningful CPU usage
                if cpuPercentage > 0.1 {
                    let details = ProcessCPUDetails(
                        pid: pid,
                        name: processName,
                        cpuPercentage: min(100.0, cpuPercentage)
                    )
                    processDetails.append(details)
                }

                if processDetails.count >= limit {
                    break
                }
            }

            return processDetails
        } catch {
            return []
        }
    }
}
