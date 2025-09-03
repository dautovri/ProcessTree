import Foundation
import Combine
import Darwin

class ProcessManager: ObservableObject, @unchecked Sendable {
    @Published var processes: [ProcessInfo] = []
    @Published var rootProcesses: [ProcessInfo] = []
    @Published var selectedProcess: ProcessInfo?
    @Published var viewMode: ViewMode = .tree
    @Published var sortCriteria: ProcessSortCriteria = .name
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 3.0  // Reduced from 1 second to 3 seconds
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await self.refreshProcessList()
            }
        }
        
        Task {
            await refreshProcessList()
        }
    }
    
    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @MainActor
    func refreshProcessList() async {
        // Don't show loading for regular refreshes to avoid UI jumping
        let shouldShowLoading = processes.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        
        do {
            let processData = try await getSystemProcesses()
            let processDict = buildProcessDictionary(from: processData)
            let (processes, rootProcesses) = buildProcessTree(from: processDict)
            
            self.processes = processes
            self.rootProcesses = rootProcesses
            
        } catch {
            print("Error refreshing process list: \(error)")
        }
        
        if shouldShowLoading {
            isLoading = false
        }
    }
    
    private func getSystemProcesses() async throws -> [kinfo_proc] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let processes = try self.getBSDProcessList()
                    continuation.resume(returning: processes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func getBSDProcessList() throws -> [kinfo_proc] {
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var length: size_t = 0
        
        // Get the size needed
        if sysctl(&name, u_int(name.count), nil, &length, nil, 0) != 0 {
            throw ProcessError.systemCallFailed
        }
        
        let count = length / MemoryLayout<kinfo_proc>.size
        var processes = Array<kinfo_proc>(repeating: kinfo_proc(), count: count)
        
        // Get the actual data
        if sysctl(&name, u_int(name.count), &processes, &length, nil, 0) != 0 {
            throw ProcessError.systemCallFailed
        }
        
        let actualCount = length / MemoryLayout<kinfo_proc>.size
        return Array(processes.prefix(actualCount))
    }
    
    private func buildProcessDictionary(from rawProcesses: [kinfo_proc]) -> [pid_t: ProcessInfo] {
        var processDict: [pid_t: ProcessInfo] = [:]
        
        for proc in rawProcesses {
            let process = ProcessInfo(
                pid: proc.kp_proc.p_pid,
                name: String(cString: withUnsafePointer(to: proc.kp_proc.p_comm) {
                    $0.withMemoryRebound(to: Int8.self, capacity: MemoryLayout.size(ofValue: $0)) { $0 }
                }),
                username: getUserName(for: proc.kp_eproc.e_ucred.cr_uid),
                path: getProcessPath(for: proc.kp_proc.p_pid),
                ppid: proc.kp_eproc.e_ppid,
                userid: proc.kp_eproc.e_ucred.cr_uid,
                cpuUsage: 0.0 // CPU usage calculation would require additional system calls
            )
            processDict[process.pid] = process
        }
        
        return processDict
    }
    
    private func buildProcessTree(from processDict: [pid_t: ProcessInfo]) -> ([ProcessInfo], [ProcessInfo]) {
        var rootProcesses: [ProcessInfo] = []
        
        // Build parent-child relationships
        for process in processDict.values {
            if let parent = processDict[process.ppid], process.ppid != 0 {
                parent.addChild(process)
            } else {
                // Consider processes with PPID 0 or non-existent parents as roots
                rootProcesses.append(process)
            }
        }
        
        // If we have no root processes (shouldn't happen), use processes with lowest PIDs as fallback
        if rootProcesses.isEmpty {
            let topLevelProcesses = Array(processDict.values)
                .filter { $0.ppid <= 1 || processDict[$0.ppid] == nil }
                .sorted { $0.pid < $1.pid }
                .prefix(10)
            rootProcesses = Array(topLevelProcesses)
        }
        
        // Sort processes
        let sortedRoots = rootProcesses.sorted(by: sortCriteria.comparator)
        sortProcessTreeRecursively(sortedRoots)
        
        let allProcesses = Array(processDict.values).sorted(by: sortCriteria.comparator)
        
        return (allProcesses, sortedRoots)
    }
    
    private func sortProcessTreeRecursively(_ processes: [ProcessInfo]) {
        for process in processes {
            process.children.sort(by: sortCriteria.comparator)
            sortProcessTreeRecursively(process.children)
        }
    }
    
    private func getUserName(for uid: uid_t) -> String {
        guard let passwd = getpwuid(uid) else { return "\(uid)" }
        return String(cString: passwd.pointee.pw_name)
    }
    
    private func getProcessPath(for pid: pid_t) -> String {
        var path = [CChar](repeating: 0, count: 4096) // MAXPATHLEN * 4
        let result = proc_pidpath(pid, &path, 4096)
        return result > 0 ? String(cString: path) : ""
    }
    
    func killProcess(_ process: ProcessInfo) {
        let result = kill(process.pid, SIGTERM)
        if result != 0 {
            // Try SIGKILL if SIGTERM fails
            kill(process.pid, SIGKILL)
        }
        
        // Refresh immediately after killing
        Task {
            await refreshProcessList()
        }
    }
    
    func toggleViewMode() {
        viewMode = viewMode == .tree ? .flat : .tree
    }
    
    var filteredProcesses: [ProcessInfo] {
        let processesToFilter: [ProcessInfo]
        
        if viewMode == .tree {
            // Use rootProcesses for tree mode, fallback to regular processes if no roots
            processesToFilter = rootProcesses.isEmpty ? processes : rootProcesses
        } else {
            processesToFilter = processes
        }
        
        
        if searchText.isEmpty {
            return processesToFilter
        }
        
        return processesToFilter.filter { process in
            matchesSearch(process, searchText: searchText)
        }
    }
    
    private func matchesSearch(_ process: ProcessInfo, searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        
        if process.name.lowercased().contains(lowercaseSearch) ||
           process.username.lowercased().contains(lowercaseSearch) ||
           "\(process.pid)".contains(lowercaseSearch) {
            return true
        }
        
        // For tree view, also check children
        if viewMode == .tree {
            return process.children.contains { matchesSearch($0, searchText: searchText) }
        }
        
        return false
    }
}

enum ProcessError: Error {
    case systemCallFailed
    case processNotFound
    case insufficientPermissions
}