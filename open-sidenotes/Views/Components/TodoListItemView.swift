import SwiftUI

struct TodoListItemView: View {
    let list: TodoList
    let todoStore: TodoStore
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: list.color))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: list.color).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(list.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "2C2C2C"))

                    if list.isInbox {
                        Text("INBOX")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "7C9885"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "7C9885").opacity(0.1))
                            .cornerRadius(3)
                    }
                }

                HStack(spacing: 8) {
                    let tasks = todoStore.todos(for: list.id)
                    let uncompleted = tasks.filter { !$0.isCompleted }.count
                    let total = tasks.count

                    Text("\(uncompleted)/\(total)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "888888"))

                    Circle()
                        .fill(Color(hex: "CCCCCC"))
                        .frame(width: 2, height: 2)

                    Text(relativeTime(from: list.updatedAt))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "999999"))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(Color(hex: list.color).opacity(0.3), lineWidth: 1)
                .opacity(isSelected ? 1 : 0)
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(hex: list.color).opacity(0.08)
        } else if isHovered {
            return Color(hex: "F0F0F0")
        } else {
            return Color.clear
        }
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) min ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours > 1 ? "s" : "") ago"
        } else if seconds < 604800 {
            let days = seconds / 86400
            return "\(days) day\(days > 1 ? "s" : "") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let todoStore = TodoStore()
    let list = TodoList(name: "Work", icon: "briefcase.fill", color: "7C9885")

    return TodoListItemView(
        list: list,
        todoStore: todoStore,
        isSelected: true,
        isHovered: false
    )
    .frame(width: 280)
}
