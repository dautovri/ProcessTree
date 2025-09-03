import SwiftUI

struct ContentView: View {
    @StateObject private var processManager = ProcessManager()
    @State private var searchText = ""
    @State private var selectedSortCriteria: ProcessSortCriteria = .name
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Process List
            VStack(spacing: 0) {
                // Header with controls
                ProcessListHeader()
                
                // Process Tree/List
                ProcessTreeView()
                    .searchable(text: $searchText, prompt: "Search processes...")
                    .onChange(of: searchText) { newValue in
                        processManager.searchText = newValue
                    }
            }
            .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 800)
        } detail: {
            // Detail - Process Information
            ProcessDetailView(process: processManager.selectedProcess)
                .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
        }
        .environmentObject(processManager)
        .onReceive(NotificationCenter.default.publisher(for: .killSelectedProcess)) { _ in
            if let selectedProcess = processManager.selectedProcess {
                processManager.killProcess(selectedProcess)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTreeView)) { _ in
            processManager.toggleViewMode()
        }
    }
}

struct ProcessListHeader: View {
    @EnvironmentObject var processManager: ProcessManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Processes")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if processManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Text("\(processManager.processes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Color legend
            HStack {
                ProcessColorLegend()
                Spacer()
            }
            
            // View mode and sort controls
            HStack {
                Picker("View Mode", selection: $processManager.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Menu {
                    Picker("Sort By", selection: $processManager.sortCriteria) {
                        ForEach(ProcessSortCriteria.allCases, id: \.self) { criteria in
                            Text(criteria.rawValue).tag(criteria)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 60)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ProcessToolbarButtons: View {
    @EnvironmentObject var processManager: ProcessManager
    
    var body: some View {
        HStack {
            // Refresh button
            Button(action: {
                Task {
                    await processManager.refreshProcessList()
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh process list")
            
            // Kill process button
            Button(action: {
                if let selectedProcess = processManager.selectedProcess {
                    processManager.killProcess(selectedProcess)
                }
            }) {
                Label("Kill Process", systemImage: "stop.fill")
            }
            .disabled(processManager.selectedProcess == nil || 
                     processManager.selectedProcess?.userid == 0)
            .help("Kill selected process")
            
            // Toggle view button
            Button(action: {
                processManager.toggleViewMode()
            }) {
                Label(
                    processManager.viewMode == .tree ? "Flat View" : "Tree View",
                    systemImage: processManager.viewMode == .tree ? "list.bullet" : "arrow.branch"
                )
            }
            .help("Toggle between tree and flat view")
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}