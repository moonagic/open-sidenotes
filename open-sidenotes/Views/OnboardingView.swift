import SwiftUI

struct OnboardingView: View {
    @State private var cursorX: CGFloat = 300
    @State private var panelOffset: CGFloat = 140
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "FAF9F6")

            VStack(spacing: 20) {
                Image(systemName: "note.text")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "7C9885"))
                    .padding(.top, 50)

                Text("Welcome to Open Sidenotes")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(hex: "2C2C2C"))

                Text("Move your mouse to the right edge\nof the screen to open the notes panel")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "666666"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "FFFFFF"))
                        .frame(width: 480, height: 220)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "7C9885").opacity(0.15))
                            .frame(width: 140, height: 200)
                            .overlay(
                                VStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "7C9885").opacity(0.25))
                                        .frame(width: 100, height: 14)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "7C9885").opacity(0.25))
                                        .frame(width: 100, height: 14)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "7C9885").opacity(0.25))
                                        .frame(width: 100, height: 14)
                                }
                            )
                            .offset(x: panelOffset)
                    }
                    .frame(width: 460, height: 200, alignment: .trailing)
                    .clipped()

                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "2C2C2C"))
                        .position(x: cursorX, y: 100)
                }
                .padding(.vertical, 8)

                Text("Slide to the edge to toggle")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "999999"))

                Button(action: onClose) {
                    Text("Got it!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .padding(.vertical, 10)
                        .background(Color(hex: "7C9885"))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 50)
            }
        }
        .frame(width: 600, height: 560)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 2.0)) {
                cursorX = 500
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    panelOffset = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        panelOffset = 140
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            cursorX = 300
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            startAnimation()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView(onClose: {})
        .frame(width: 600, height: 560)
}
