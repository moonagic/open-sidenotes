import SwiftUI

struct TodoListListView: View {
    @ObservedObject var listStore: TodoListStore
    @ObservedObject var todoStore: TodoStore
    @Binding var selectedList: TodoList?
    var onClose: () -> Void

    @State private var hoveredListId: UUID?

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
                    .padding(.vertical, 8)
                }
            }
        }
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
