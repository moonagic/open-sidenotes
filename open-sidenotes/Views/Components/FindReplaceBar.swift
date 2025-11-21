import SwiftUI

struct FindReplaceBar: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var showReplace: Bool
    var matchCount: Int
    var currentMatch: Int
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    var onClose: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Search row
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "888888"))

                    TextField("Find", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .focused($isSearchFocused)
                        .onSubmit { onNext() }

                    if !searchText.isEmpty {
                        Text("\(currentMatch)/\(matchCount)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "888888"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "FFFFFF"))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                )

                // Navigation buttons
                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(FindBarButton())
                .disabled(matchCount == 0)

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(FindBarButton())
                .disabled(matchCount == 0)

                // Toggle replace
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(FindBarButton(isActive: showReplace))

                Spacer()

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(FindBarButton())
            }

            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "888888"))

                        TextField("Replace", text: $replaceText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13))
                            .onSubmit { onReplace() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "FFFFFF"))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                    )

                    Button(action: onReplace) {
                        Text("Replace")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(FindBarButton())
                    .disabled(matchCount == 0)

                    Button(action: onReplaceAll) {
                        Text("All")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(FindBarButton())
                    .disabled(matchCount == 0)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "F5F5F5"))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}

struct FindBarButton: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? Color(hex: "7C9885") : Color(hex: "666666"))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color(hex: "E0E0E0") : (isActive ? Color(hex: "7C9885").opacity(0.1) : Color.clear))
            )
    }
}
