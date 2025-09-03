import SwiftUI

struct ProcessTreeView: View {
    @EnvironmentObject var processManager: ProcessManager
    @State private var expandedProcesses: Set<pid_t> = Set()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if processManager.viewMode == .tree {
                    ForEach(processManager.filteredProcesses, id: \.id) { process in
                        ProcessTreeNode(
                            process: process,
                            level: 0,
                            isExpanded: expandedProcesses.contains(process.pid),
                            expandedProcesses: $expandedProcesses,
                            onSelect: { processManager.selectedProcess = process }
                        )
                    }
                } else {
                    ForEach(processManager.filteredProcesses, id: \.id) { process in
                        ProcessRowView(
                            process: process,
                            isSelected: processManager.selectedProcess?.pid == process.pid,
                            onSelect: { processManager.selectedProcess = process }
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            // Auto-expand some important processes initially
            expandInitialProcesses()
        }
    }
    
    private func toggleExpansion(for process: ProcessInfo) {
        if expandedProcesses.contains(process.pid) {
            expandedProcesses.remove(process.pid)
            // Recursively collapse children
            collapseChildren(of: process)
        } else {
            expandedProcesses.insert(process.pid)
        }
    }
    
    private func collapseChildren(of process: ProcessInfo) {
        for child in process.children {
            expandedProcesses.remove(child.pid)
            collapseChildren(of: child)
        }
    }
    
    private func expandInitialProcesses() {
        // Auto-expand kernel, launchd, and a few other important processes
        for process in processManager.rootProcesses {
            if process.pid == 1 || // launchd
               process.name.lowercased().contains("kernel") ||
               process.name.lowercased().contains("windowserver") {
                expandedProcesses.insert(process.pid)
            }
        }
    }
}

struct ProcessTreeNode: View {
    let process: ProcessInfo
    let level: Int
    let isExpanded: Bool
    @Binding var expandedProcesses: Set<pid_t>
    let onSelect: () -> Void
    
    @EnvironmentObject var processManager: ProcessManager
    
    private let indentWidth: CGFloat = 16
    private let maxVisibleLevel: Int = 10
    
    var body: some View {
        if level <= maxVisibleLevel {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    // Indentation
                    HStack(spacing: 0) {
                        ForEach(0..<level, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: indentWidth, height: 1)
                        }
                    }
                    
                    // Expansion triangle or spacer
                    Group {
                        if process.hasChildren {
                            Button(action: {
                                if expandedProcesses.contains(process.pid) {
                                    expandedProcesses.remove(process.pid)
                                    // Recursively collapse children
                                    collapseChildren(of: process)
                                } else {
                                    expandedProcesses.insert(process.pid)
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Spacer()
                                .frame(width: 12)
                        }
                    }
                    .frame(width: 16)
                    
                    // Process row content
                    ProcessRowView(
                        process: process,
                        isSelected: processManager.selectedProcess?.pid == process.pid,
                        onSelect: onSelect
                    )
                }
                
                // Children (if expanded)
                if isExpanded && process.hasChildren {
                    ForEach(process.children, id: \.id) { child in
                        ProcessTreeNode(
                            process: child,
                            level: level + 1,
                            isExpanded: expandedProcesses.contains(child.pid),
                            expandedProcesses: $expandedProcesses,
                            onSelect: { processManager.selectedProcess = child }
                        )
                    }
                }
            }
        }
    }
    
    private func collapseChildren(of process: ProcessInfo) {
        for child in process.children {
            expandedProcesses.remove(child.pid)
            collapseChildren(of: child)
        }
    }
}


#Preview {
    ProcessTreeView()
        .environmentObject(ProcessManager())
        .frame(width: 600, height: 400)
}