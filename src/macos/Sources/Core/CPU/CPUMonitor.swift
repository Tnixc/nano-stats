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
        var processDetails: [ProcessCPUDetails] = []
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var bufferSize = 0

        // Get buffer size
        var sysctl_result = sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0)
        guard sysctl_result == 0, bufferSize > 0 else { return [] }

        // Allocate buffer
        let buffer = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        // Get process info
        sysctl_result = sysctl(&mib, UInt32(mib.count), buffer, &bufferSize, nil, 0)
        guard sysctl_result == 0 else { return [] }

        let processCount = bufferSize / MemoryLayout<kinfo_proc>.size

        for i in 0 ..< processCount {
            let info = buffer.advanced(by: i).pointee
            let pid = info.kp_proc.p_pid

            guard pid > 0 else { continue }

            // Get task info for CPU usage
            var taskInfo = proc_taskinfo()
            let taskInfoSize = MemoryLayout<proc_taskinfo>.size

            let bytesCopied = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &taskInfo,
                Int32(taskInfoSize)
            )

            guard bytesCopied == taskInfoSize else { continue }

            // Get process name
            var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathResult = proc_pidpath(pid, &nameBuffer, UInt32(nameBuffer.count))

            var processName: String
            if pathResult > 0 {
                let path = String(cString: nameBuffer)
                processName = URL(fileURLWithPath: path).lastPathComponent
            } else {
                processName = withUnsafeBytes(of: info.kp_proc.p_comm) { bytes in
                    let ptr = bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
                    return String(cString: ptr)
                }

                if processName.isEmpty {
                    processName = "pid-\(pid)"
                }
            }

            // Calculate CPU percentage
            let totalTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            let cpuPercentage = (Double(totalTime) / 10_000_000.0) // Convert to percentage

            if cpuPercentage > 0.1 {
                let details = ProcessCPUDetails(
                    pid: pid,
                    name: processName,
                    cpuPercentage: min(100.0, cpuPercentage)
                )
                processDetails.append(details)
            }
        }

        processDetails.sort()
        return Array(processDetails.prefix(limit))
    }
}
