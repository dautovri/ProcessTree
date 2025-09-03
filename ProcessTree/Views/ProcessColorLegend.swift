import SwiftUI

struct ProcessColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Process Types")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                LegendItem(color: .red, label: "Root", description: "Root processes (UID 0)")
                LegendItem(color: .orange, label: "System", description: "System processes (UID < 500)")  
                LegendItem(color: .blue, label: "User", description: "User processes (UID ≥ 500)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(6)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let description: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .help(description)
    }
}

#Preview {
    ProcessColorLegend()
        .padding()
}