import SwiftUI

struct PriorityBadge: View {
    let priority: Todo.Priority

    private var badgeColor: Color {
        switch priority {
        case .high:
            return Color(hex: "E74C3C")
        case .medium:
            return Color(hex: "F39C12")
        case .low:
            return Color(hex: "95A5A6")
        }
    }

    var body: some View {
        Text(priority.displayName)
            .font(.system(size: 9, weight: .medium))
            .tracking(0.3)
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(badgeColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
            )
    }
}

#Preview {
    VStack(spacing: 8) {
        PriorityBadge(priority: .high)
        PriorityBadge(priority: .medium)
        PriorityBadge(priority: .low)
    }
    .padding()
}
