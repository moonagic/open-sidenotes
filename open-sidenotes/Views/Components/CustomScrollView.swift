import SwiftUI
import AppKit

struct CustomScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = CustomScroller()
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        let hostingView = NSHostingView(rootView: content)
        scrollView.documentView = hostingView

        DispatchQueue.main.async {
            hostingView.layoutSubtreeIfNeeded()
            let size = hostingView.fittingSize
            hostingView.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: size.height)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let hostingView = scrollView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content

            DispatchQueue.main.async {
                hostingView.layoutSubtreeIfNeeded()
                let size = hostingView.fittingSize
                var frame = hostingView.frame
                frame.size.height = size.height
                frame.size.width = scrollView.contentSize.width
                hostingView.frame = frame
            }
        }
    }
}
