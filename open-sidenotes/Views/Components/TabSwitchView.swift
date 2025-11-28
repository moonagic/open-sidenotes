import SwiftUI

struct TabSwitchView: View {
    @Binding var activeTab: String
    let tabs: [(id: String, label: String)]

    @State private var hoveredTab: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                ForEach(tabs, id: \.id) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab.id
                        }
                    }) {
                        Text(tab.label)
                            .font(.system(size: 13, weight: .medium))
                            .tracking(0.3)
                            .foregroundColor(activeTab == tab.id ? Color(hex: "7C9885") : Color(hex: "888888"))
                            .opacity(hoveredTab == tab.id && activeTab != tab.id ? 0.6 : 1.0)
                            .padding(.bottom, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        hoveredTab = hovering ? tab.id : nil
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            GeometryReader { geometry in
                let tabWidth = (geometry.size.width - 40 - CGFloat((tabs.count - 1) * 24)) / CGFloat(tabs.count)
                let selectedIndex = tabs.firstIndex(where: { $0.id == activeTab }) ?? 0
                let offset = 20 + CGFloat(selectedIndex) * (tabWidth + 24)

                Rectangle()
                    .fill(Color(hex: "7C9885"))
                    .frame(width: tabWidth, height: 2)
                    .offset(x: offset)
            }
            .frame(height: 2)
        }
    }
}

#Preview {
    @Previewable @State var activeTab = "notes"

    return TabSwitchView(
        activeTab: $activeTab,
        tabs: [
            (id: "notes", label: "NOTES"),
            (id: "tasks", label: "TASKS")
        ]
    )
    .frame(width: 280)
}
