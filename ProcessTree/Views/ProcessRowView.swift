import SwiftUI

struct ProcessRowView: View {
    let process: ProcessInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Process icon (generic app icon or system process icon)
            Image(systemName: iconForProcess(process))
                .foregroundColor(colorForProcess(process))
                .frame(width: 16, height: 16)
            
            // Process name
            Text(process.name)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isSelected ? .primary : .primary)
                .lineLimit(1)
                .frame(minWidth: 150, alignment: .leading)
            
            Spacer()
            
            // PID
            Text("\(process.pid)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .trailing)
            
            // Username
            Text(process.username)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            
            // CPU usage (placeholder)
            Text(String(format: "%.1f%%", process.cpuUsage))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 50, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            ProcessContextMenu(process: process)
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
        case 0: // root
            return .red
        case let uid where uid < 500: // system
            return .orange
        default: // user
            return .blue
        }
    }
}

struct ProcessContextMenu: View {
    let process: ProcessInfo
    @EnvironmentObject var processManager: ProcessManager
    
    var body: some View {
        Button("Kill Process") {
            processManager.killProcess(process)
        }
        .disabled(process.userid == 0) // Disable for root processes
        
        Button("Show Info") {
            processManager.selectedProcess = process
        }
        
        Divider()
        
        Button("Copy PID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(process.pid)", forType: .string)
        }
        
        Button("Copy Name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(process.name, forType: .string)
        }
    }
}

#Preview {
    ProcessRowView(
        process: ProcessInfo(
            pid: 1234,
            name: "Safari",
            username: "user",
            path: "/Applications/Safari.app/Contents/MacOS/Safari",
            ppid: 1,
            userid: 501,
            cpuUsage: 5.7
        ),
        isSelected: false,
        onSelect: {}
    )
    .environmentObject(ProcessManager())
}