import SwiftUI

@main
struct ProcessTreeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Process") {
                Button("Kill Selected Process") {
                    NotificationCenter.default.post(name: .killSelectedProcess, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Show Process Info") {
                    NotificationCenter.default.post(name: .showProcessInfo, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
                
                Divider()
                
                Button("Toggle Tree View") {
                    NotificationCenter.default.post(name: .toggleTreeView, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let killSelectedProcess = Notification.Name("killSelectedProcess")
    static let showProcessInfo = Notification.Name("showProcessInfo")
    static let toggleTreeView = Notification.Name("toggleTreeView")
}