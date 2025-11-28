import SwiftUI

struct TodoListListView: View {
    @ObservedObject var listStore: TodoListStore
    @ObservedObject var todoStore: TodoStore
    @Binding var selectedList: TodoList?
    var onClose: () -> Void

    @State private var hoveredListId: UUID?
    @State private var editingListId: UUID?
    @State private var editingListName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if listStore.isLoading {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if listStore.lists.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(Color(hex: "888888"))

                    Text("No lists yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "888888"))

                    Text("Creating inbox...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "999999"))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                CustomScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(listStore.lists) { list in
                            if editingListId == list.id {
                                EditableListItemView(
                                    list: list,
                                    editingName: $editingListName,
                                    onSave: {
                                        Task {
                                            await listStore.updateList(list, name: editingListName)
                                            editingListId = nil
                                        }
                                    },
                                    onCancel: {
                                        editingListId = nil
                                    }
                                )
                            } else {
                                TodoListItemView(
                                    list: list,
                                    todoStore: todoStore,
                                    isSelected: selectedList?.id == list.id,
                                    isHovered: hoveredListId == list.id
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedList = list
                                    onClose()
                                }
                                .onHover { hovering in
                                    hoveredListId = hovering ? list.id : nil
                                    if hovering {
                                        NSCursor.arrow.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                .contextMenu {
                                    if !list.isInbox {
                                        Button("Rename") {
                                            editingListId = list.id
                                            editingListName = list.name
                                        }
                                        Button("Delete", role: .destructive) {
                                            Task {
                                                await listStore.deleteList(list)
                                                if selectedList?.id == list.id {
                                                    selectedList = listStore.lists.first
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct EditableListItemView: View {
    let list: TodoList
    @Binding var editingName: String
    var onSave: () -> Void
    var onCancel: () -> Void

    @FocusState private var isFocused: Bool

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

            TextField("List name", text: $editingName)
                .font(.system(size: 15, weight: .medium))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(onSave)
                .onAppear {
                    isFocused = true
                }

            HStack(spacing: 8) {
                Button(action: onSave) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(hex: "999999"))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: list.color).opacity(0.08))
        .overlay(
            Rectangle()
                .stroke(Color(hex: list.color).opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var selectedList: TodoList? = nil
    let listStore = TodoListStore()
    let todoStore = TodoStore()

    return TodoListListView(
        listStore: listStore,
        todoStore: todoStore,
        selectedList: $selectedList,
        onClose: {}
    )
    .frame(width: 280, height: 600)
}
