import Foundation
import Combine

class ProcessInfo: ObservableObject, Identifiable, Equatable {
    let id: pid_t
    @Published var name: String
    @Published var username: String
    @Published var path: String
    @Published var pid: pid_t
    @Published var ppid: pid_t
    @Published var userid: uid_t
    @Published var cpuUsage: Double
    @Published var children: [ProcessInfo] = []
    
    var parent: ProcessInfo?
    
    init(pid: pid_t, name: String, username: String = "", path: String = "", ppid: pid_t = 0, userid: uid_t = 0, cpuUsage: Double = 0.0) {
        self.id = pid
        self.pid = pid
        self.name = name
        self.username = username
        self.path = path
        self.ppid = ppid
        self.userid = userid
        self.cpuUsage = cpuUsage
    }
    
    func addChild(_ child: ProcessInfo) {
        child.parent = self
        children.append(child)
    }
    
    func removeAllChildren() {
        children.removeAll()
    }
    
    var hasChildren: Bool {
        !children.isEmpty
    }
    
    var isRoot: Bool {
        parent == nil
    }
    
    static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}

extension ProcessInfo {
    static func compareByName(_ lhs: ProcessInfo, _ rhs: ProcessInfo) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    
    static func compareByPID(_ lhs: ProcessInfo, _ rhs: ProcessInfo) -> Bool {
        lhs.pid < rhs.pid
    }
    
    static func compareByUser(_ lhs: ProcessInfo, _ rhs: ProcessInfo) -> Bool {
        lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
    }
    
    static func compareByCPU(_ lhs: ProcessInfo, _ rhs: ProcessInfo) -> Bool {
        lhs.cpuUsage > rhs.cpuUsage
    }
}

enum ProcessSortCriteria: String, CaseIterable {
    case name = "Name"
    case pid = "PID"
    case user = "User"
    case cpu = "CPU"
    
    var comparator: (ProcessInfo, ProcessInfo) -> Bool {
        switch self {
        case .name: return ProcessInfo.compareByName
        case .pid: return ProcessInfo.compareByPID
        case .user: return ProcessInfo.compareByUser
        case .cpu: return ProcessInfo.compareByCPU
        }
    }
}

enum ViewMode: String, CaseIterable {
    case tree = "Tree"
    case flat = "Flat"
}