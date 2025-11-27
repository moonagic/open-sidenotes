import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTagText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "7C9885"))

                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(hex: "7C9885").opacity(0.6))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "7C9885").opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(hex: "7C9885").opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "888888"))

                TextField("Add tag (press Enter)", text: $newTagText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "2C2C2C"))
                    .focused($isInputFocused)
                    .onSubmit {
                        addTag()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "F5F5F5"))
            .cornerRadius(6)
        }
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTagText = ""
            return
        }
        tags.append(trimmed)
        newTagText = ""
    }
}

#Preview {
    @Previewable @State var tags = ["work", "urgent", "project"]

    return VStack {
        TagInputView(tags: $tags)
        Spacer()
    }
    .padding()
    .frame(width: 400)
}
