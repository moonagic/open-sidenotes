import SwiftUI

struct TodoListDetailView: View {
    @ObservedObject var listStore: TodoListStore
    @ObservedObject var todoStore: TodoStore
    @Binding var selectedList: TodoList?
    var onToggleDrawer: () -> Void

    @State private var quickAddText: String = ""
    @FocusState private var isInputFocused: Bool

    private var tasks: [Todo] {
        guard let list = selectedList else {
            return []
        }
        return todoStore.todos(for: list.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onToggleDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "7C9885"))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(hex: "7C9885").opacity(0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                if let list = selectedList {
                    HStack(spacing: 8) {
                        Image(systemName: list.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: list.color))

                        Text(list.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "2C2C2C"))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if selectedList != nil {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "7C9885"))

                    TextField("Add a task (press Enter)", text: $quickAddText)
                        .font(.system(size: 15))
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .onSubmit {
                            Task { await quickAddTask() }
                        }

                    if !quickAddText.isEmpty {
                        Button(action: { quickAddText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "888888"))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(hex: "F9F9F9"))

                Divider()
                    .background(Color(hex: "E8E8E8"))

                if tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(Color(hex: "CCCCCC"))

                        Text("No tasks yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "888888"))

                        Text("Use the input above to add tasks")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "999999"))
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    CustomScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(tasks) { task in
                                SimpleTaskRow(task: task, todoStore: todoStore)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray.2")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(Color(hex: "CACACA"))

                    Text("Select a list")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "999999"))

                    Text("or create a new one")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "BBBBBB"))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func quickAddTask() async {
        guard let list = selectedList, !quickAddText.isEmpty else {
            return
        }
        await todoStore.addTodo(listId: list.id, title: quickAddText)
        quickAddText = ""
        isInputFocused = true
    }
}

struct SimpleTaskRow: View {
    let task: Todo
    @ObservedObject var todoStore: TodoStore
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task { await todoStore.toggleCompletion(task) }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(task.isCompleted ? Color(hex: "7C9885") : Color(hex: "CCCCCC"))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(task.isCompleted, color: Color(hex: "888888"))
                    .foregroundColor(task.isCompleted ? Color(hex: "888888") : Color(hex: "2C2C2C"))

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "999999"))
                        .lineLimit(1)
                }
            }

            Spacer()

            if isHovered {
                Button(action: {
                    Task { await todoStore.deleteTodo(task) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "888888"))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Menu {
                ForEach(Todo.Priority.allCases, id: \.self) { priority in
                    Button(action: {
                        Task { await updatePriority(priority) }
                    }) {
                        HStack {
                            Text(priority.displayName)
                            if task.priority == priority {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                PriorityBadge(priority: task.priority)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func updatePriority(_ priority: Todo.Priority) async {
        await todoStore.updateTodo(
            task,
            title: task.title,
            description: task.description,
            priority: priority
        )
    }
}

#Preview {
    @Previewable @State var selectedList: TodoList? = TodoList(name: "Inbox", isInbox: true)
    let listStore = TodoListStore()
    let todoStore = TodoStore()

    return TodoListDetailView(
        listStore: listStore,
        todoStore: todoStore,
        selectedList: $selectedList,
        onToggleDrawer: {}
    )
    .frame(width: 800, height: 600)
}
