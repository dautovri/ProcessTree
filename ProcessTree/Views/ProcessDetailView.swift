import SwiftUI

struct ProcessDetailView: View {
    let process: ProcessInfo?
    @EnvironmentObject var processManager: ProcessManager
    
    private var displayProcess: ProcessInfo? {
        if let process = process {
            return process
        }
        // Default to first root process in tree mode, or first process in flat mode
        if processManager.viewMode == .tree {
            return processManager.rootProcesses.first
        } else {
            return processManager.processes.first
        }
    }
    
    var body: some View {
        Group {
            if let process = displayProcess {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Process Header
                        ProcessHeaderView(process: process)
                        
                        Divider()
                        
                        // Process Information
                        ProcessInfoSection(process: process)
                        
                        Divider()
                        
                        // Process Hierarchy
                        ProcessHierarchySection(process: process)
                        
                        Divider()
                        
                        // Process Actions
                        ProcessActionsSection(process: process)
                        
                        Spacer()
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Process Selected")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select a process from the list to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ProcessHeaderView: View {
    let process: ProcessInfo
    
    var body: some View {
        HStack {
            Image(systemName: iconForProcess(process))
                .font(.system(size: 32))
                .foregroundColor(colorForProcess(process))
            
            VStack(alignment: .leading) {
                Text(process.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("PID: \(process.pid)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if process.hasChildren {
                VStack {
                    Text("\(process.children.count)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("children")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func iconForProcess(_ process: ProcessInfo) -> String {
        switch process.name.lowercased() {
        case let name where name.contains("kernel"):
            return "cpu"
        case let name where name.contains("finder"):
            return "folder"
        case let name where name.contains("safari"):
            return "safari"
        case let name where name.contains("chrome"):
            return "globe"
        case let name where name.contains("xcode"):
            return "hammer"
        case let name where name.contains("terminal"):
            return "terminal"
        default:
            return "app"
        }
    }
    
    private func colorForProcess(_ process: ProcessInfo) -> Color {
        switch process.userid {
        case 0: return .red
        case let uid where uid < 500: return .orange
        default: return .blue
        }
    }
}

struct ProcessInfoSection: View {
    let process: ProcessInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Process Information")
            
            InfoRow(label: "Name", value: process.name)
            InfoRow(label: "Process ID", value: "\(process.pid)")
            InfoRow(label: "Parent PID", value: "\(process.ppid)")
            InfoRow(label: "User", value: process.username)
            InfoRow(label: "User ID", value: "\(process.userid)")
            InfoRow(label: "CPU Usage", value: String(format: "%.1f%%", process.cpuUsage))
            
            if !process.path.isEmpty {
                InfoRow(label: "Path", value: process.path)
            }
        }
    }
}

struct ProcessHierarchySection: View {
    let process: ProcessInfo
    @EnvironmentObject var processManager: ProcessManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Process Hierarchy")
            
            // Parent process
            if let parent = process.parent {
                HStack {
                    Text("Parent:")
                        .fontWeight(.medium)
                    Button("\(parent.name) (\(parent.pid))") {
                        processManager.selectedProcess = parent
                    }
                    .buttonStyle(.link)
                }
            } else {
                Text("No parent process (root)")
                    .foregroundColor(.secondary)
            }
            
            // Child processes
            if process.hasChildren {
                Text("Children (\(process.children.count)):")
                    .fontWeight(.medium)
                
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(process.children.prefix(5), id: \.id) { child in
                        HStack {
                            Text("•")
                                .foregroundColor(.secondary)
                            Button("\(child.name) (\(child.pid))") {
                                processManager.selectedProcess = child
                            }
                            .buttonStyle(.link)
                        }
                    }
                    
                    if process.children.count > 5 {
                        Text("... and \(process.children.count - 5) more")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } else {
                Text("No child processes")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ProcessActionsSection: View {
    let process: ProcessInfo
    @EnvironmentObject var processManager: ProcessManager
    @State private var showKillConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Actions")
            
            HStack {
                Button("Kill Process") {
                    showKillConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(process.userid == 0) // Disable for root processes
                .alert("Kill Process", isPresented: $showKillConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Kill", role: .destructive) {
                        processManager.killProcess(process)
                    }
                } message: {
                    Text("Are you sure you want to kill \"\(process.name)\" (PID: \(process.pid))?\n\nThis action cannot be undone.")
                }
                
                Button("Copy PID") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(process.pid)", forType: .string)
                }
                .buttonStyle(.bordered)
            }
            
            if process.userid == 0 {
                Text("⚠️ System processes cannot be terminated")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .textSelection(.enabled)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .font(.system(.body, design: .monospaced))
    }
}

#Preview {
    ProcessDetailView(
        process: ProcessInfo(
            pid: 1234,
            name: "Safari",
            username: "user",
            path: "/Applications/Safari.app/Contents/MacOS/Safari",
            ppid: 1,
            userid: 501,
            cpuUsage: 5.7
        )
    )
    .environmentObject(ProcessManager())
    .frame(width: 350, height: 500)
}