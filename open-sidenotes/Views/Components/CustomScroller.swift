import AppKit

class CustomScroller: NSScroller {
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        return 14
    }

    override class var isCompatibleWithOverlayScrollers: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        drawKnob()
    }

    override func drawKnob() {
        var knobRect = rect(for: .knob)

        guard knobRect.width > 0 && knobRect.height > 0 else { return }

        knobRect = knobRect.insetBy(dx: 0, dy: 2)

        let knobPath = NSBezierPath(roundedRect: knobRect, xRadius: 3, yRadius: 3)

        let knobColor = NSColor(red: 0.486, green: 0.596, blue: 0.522, alpha: 0.4)
        knobColor.setFill()
        knobPath.fill()
    }
}
