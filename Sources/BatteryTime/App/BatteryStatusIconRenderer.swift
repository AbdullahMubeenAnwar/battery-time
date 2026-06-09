import AppKit

enum BatteryStatusIconRenderer {
    private static let widgetSpacing: CGFloat = 2
    private static let regularBatterySize = CGSize(width: 22, height: 12)
    private static let xlBatterySize = CGSize(width: 26, height: 14)
    private static let borderWidth: CGFloat = 1
    private static let offset: CGFloat = 0.5
    // Match Stats: the whole widget draws into a frame the height of the menu bar,
    // so text rows and the battery share one vertical center.
    private static var widgetHeight: CGFloat { menuBarHeight }
    private static var menuBarHeight: CGFloat {
        let height = NSApplication.shared.mainMenu?.menuBarHeight ?? 22
        return height == 0 ? 22 : height
    }

    static func image(
        for snapshot: BatterySnapshot,
        title: String = "",
        showsInnerPercentage: Bool = false,
        colorize: Bool = true,
        xlSize: Bool = false,
        chargerInside: Bool = true
    ) -> NSImage {
        let components = title.components(separatedBy: "\n").filter { !$0.isEmpty }
        let textWidth = titleWidth(for: components)
        let textGap = textWidth > 0 ? widgetSpacing : 0
        let batterySize = batterySize(xlSize: xlSize)
        let showsExternalCharger = snapshot.isPluggedIn && !chargerInside
        let chargerWidth = showsExternalCharger ? 6 + widgetSpacing : 0
        let chargerGap = showsExternalCharger && textWidth > 0 ? widgetSpacing : 0
        let batteryGap = showsExternalCharger ? widgetSpacing : 0
        let batteryWidth = batterySize.width + borderWidth * 2 + 2
        let width = textWidth + textGap + chargerGap + chargerWidth + batteryGap + batteryWidth
        let size = NSSize(width: width, height: widgetHeight)

        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return true
            }

            var x: CGFloat = 0

            switch components.count {
            case 1:
                let rowWidth = drawOneRow(value: components[0], x: x, height: rect.height).rounded(.up)
                x += rowWidth + widgetSpacing
            case 2...:
                let rowWidth = drawTwoRows(
                    first: components[0],
                    second: components[1],
                    x: x,
                    height: rect.height
                ).rounded(.up)
                x += rowWidth + widgetSpacing
            default:
                break
            }

            if showsExternalCharger {
                if x != 0 {
                    x += widgetSpacing
                }

                drawACIcon(
                    context: context,
                    center: CGPoint(x: x + 3, y: rect.height / 2),
                    height: 12,
                    charging: snapshot.isCharging
                )
                x += 6 + widgetSpacing
            }

            if x != 0 {
                x += widgetSpacing
            }

            drawBattery(
                snapshot: snapshot,
                context: context,
                x: x,
                height: rect.height,
                batterySize: batterySize,
                showsInnerPercentage: showsInnerPercentage,
                colorize: colorize,
                chargerInside: chargerInside
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func batterySize(xlSize: Bool) -> CGSize {
        xlSize ? xlBatterySize : regularBatterySize
    }

    private static func drawBattery(
        snapshot: BatterySnapshot,
        context: CGContext,
        x: CGFloat,
        height: CGFloat,
        batterySize: CGSize,
        showsInnerPercentage: Bool,
        colorize: Bool,
        chargerInside: Bool
    ) {
        let batteryRadius: CGFloat = batterySize.height > regularBatterySize.height ? 3 : 2
        let innerRadius: CGFloat = batterySize.height > regularBatterySize.height ? 2 : 1

        let bodyPath = NSBezierPath(roundedRect: NSRect(
            x: x + borderWidth + offset,
            y: ((height - batterySize.height) / 2) + offset,
            width: batterySize.width - borderWidth,
            height: batterySize.height - borderWidth
        ), xRadius: batteryRadius, yRadius: batteryRadius)

        NSColor.textColor.withAlphaComponent(0.5).set()
        bodyPath.lineWidth = borderWidth
        bodyPath.stroke()

        let capX = bodyPath.bounds.origin.x + bodyPath.bounds.width + 1
        let capY = bodyPath.bounds.origin.y + bodyPath.bounds.height / 2 - 2
        let capPath = NSBezierPath(roundedRect: NSRect(
            x: capX - 1,
            y: capY,
            width: 3,
            height: 4
        ), xRadius: 2, yRadius: 2)
        capPath.fill()

        let capSeparator = NSBezierPath()
        capSeparator.move(to: CGPoint(x: capX, y: bodyPath.bounds.origin.y))
        capSeparator.line(to: CGPoint(x: capX, y: bodyPath.bounds.origin.y + bodyPath.bounds.height))
        context.saveGState()
        context.setBlendMode(.destinationOut)
        NSColor.white.set()
        capSeparator.lineWidth = borderWidth
        capSeparator.stroke()
        context.restoreGState()

        if let percentage = snapshot.percentage {
            let percent = min(1.0, max(0.0, Double(percentage) / 100.0))
            let maxWidth = batterySize.width - offset * 2 - borderWidth * 2 - 1
            let innerWidth = max(1, maxWidth * CGFloat(percent))
            let innerOffset = -offset + borderWidth + 1

            if showsInnerPercentage {
                let innerUnderground = NSBezierPath(roundedRect: NSRect(
                    x: bodyPath.bounds.origin.x + innerOffset,
                    y: bodyPath.bounds.origin.y + innerOffset,
                    width: maxWidth,
                    height: batterySize.height - offset * 2 - borderWidth * 2 - 1
                ), xRadius: innerRadius, yRadius: innerRadius)
                batteryColor(percent: percent, colorize: colorize)
                    .withAlphaComponent(0.5)
                    .set()
                innerUnderground.fill()
            }

            let innerPath = NSBezierPath(roundedRect: NSRect(
                x: bodyPath.bounds.origin.x + innerOffset,
                y: bodyPath.bounds.origin.y + innerOffset,
                width: innerWidth,
                height: batterySize.height - offset * 2 - borderWidth * 2 - 1
            ), xRadius: innerRadius, yRadius: innerRadius)

            batteryColor(percent: percent, colorize: colorize).set()
            innerPath.fill()

            if showsInnerPercentage {
                drawInnerPercentage(
                    snapshot.percentage,
                    context: context,
                    in: CGRect(
                        x: bodyPath.bounds.origin.x + innerOffset,
                        y: bodyPath.bounds.origin.y + innerOffset,
                        width: maxWidth,
                        height: batterySize.height - offset * 2 - borderWidth * 2 - 1
                    ),
                    xlSize: batterySize.height > regularBatterySize.height
                )
            }
        } else {
            drawUnavailableMark(in: bodyPath.bounds)
        }

        if chargerInside && snapshot.isPluggedIn {
            drawACIcon(
                context: context,
                center: CGPoint(
                    x: bodyPath.bounds.origin.x + bodyPath.bounds.width / 2,
                    y: bodyPath.bounds.origin.y + bodyPath.bounds.height / 2
                ),
                height: 12,
                charging: snapshot.isCharging
            )
        }
    }

    private static func batteryColor(percent: Double, colorize: Bool) -> NSColor {
        switch percent {
        case 0.2...0.4:
            guard colorize else {
                return NSColor.textColor
            }
            return NSColor.systemOrange
        case 0.4...1:
            guard colorize, percent < 1 else {
                return NSColor.textColor
            }
            return NSColor.systemGreen
        default:
            return NSColor.systemRed
        }
    }

    private static func drawInnerPercentage(
        _ percentage: Int?,
        context: CGContext,
        in rect: CGRect,
        xlSize: Bool
    ) {
        guard let percentage else {
            return
        }

        let value = "\(percentage)"
        let fontSize: CGFloat = xlSize ? 9 : 8
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.clear,
            .paragraphStyle: style
        ]
        let text = NSAttributedString(string: value, attributes: attributes)
        // Stats' view has frame.origin.y=2; add 2 to match absolute button-y position.
        let textRect = CGRect(
            x: rect.minX,
            y: (menuBarHeight - (fontSize + 2)) / 2 + 2,
            width: rect.width,
            height: fontSize
        )

        context.saveGState()
        context.setBlendMode(.destinationIn)
        text.draw(with: textRect)
        context.restoreGState()
    }

    private static func drawUnavailableMark(in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: NSMutableParagraphStyle()
        ]

        let center = CGPoint(x: rect.midX, y: rect.midY)
        NSAttributedString(string: "?", attributes: attributes).draw(
            with: CGRect(x: center.x - 3, y: center.y - 4, width: 8, height: 12)
        )
    }

    private static func drawOneRow(value: String, x: CGFloat, height: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: NSMutableParagraphStyle()
        ]
        let rowWidth = value.width(using: font)
        // Stats' view has frame.origin.y=2; add 2 to match absolute button-y position.
        let rect = CGRect(x: x, y: (height - 13) / 2 + 2, width: rowWidth, height: 12)
        NSAttributedString(string: value, attributes: attributes).draw(with: rect)

        return rowWidth
    }

    private static func drawTwoRows(first: String, second: String, x: CGFloat, height: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 9, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]
        // Stats' BatteryWidget view has frame.origin.y=2 and height=menuBarHeight-4,
        // so rowHeight = (menuBarHeight-4)/2 and rows draw at y=1 and y=rowHeight+1 inside
        // the view. Translating to NSImage coords (y=0 at bottom): add 2 to both y values.
        let rowHeight = (height - 4) / 2
        let rowWidth = max(first.width(using: font), second.width(using: font))

        NSAttributedString(string: first, attributes: attributes).draw(
            with: CGRect(x: x, y: rowHeight + 2, width: rowWidth, height: rowHeight)
        )
        NSAttributedString(string: second, attributes: attributes).draw(
            with: CGRect(x: x, y: 4, width: rowWidth, height: rowHeight)
        )

        return rowWidth
    }

    private static func titleWidth(for components: [String]) -> CGFloat {
        switch components.count {
        case 1:
            return components[0].width(using: .systemFont(ofSize: 12, weight: .regular)).rounded(.up)
        case 2...:
            let font = NSFont.systemFont(ofSize: 9, weight: .regular)
            return max(components[0].width(using: font), components[1].width(using: font)).rounded(.up)
        default:
            return 0
        }
    }

    private static func drawACIcon(context: CGContext, center batteryCenter: CGPoint, height: CGFloat, charging: Bool) {
        let points: [CGPoint]

        if charging {
            let iconSize = CGSize(width: 9, height: height + 6)
            let min = CGPoint(
                x: batteryCenter.x - iconSize.width / 2,
                y: batteryCenter.y - iconSize.height / 2
            )
            let max = CGPoint(
                x: batteryCenter.x + iconSize.width / 2,
                y: batteryCenter.y + iconSize.height / 2
            )

            points = [
                CGPoint(x: batteryCenter.x - 3, y: min.y),
                CGPoint(x: max.x, y: batteryCenter.y + 1.5),
                CGPoint(x: batteryCenter.x + 1, y: batteryCenter.y + 1.5),
                CGPoint(x: batteryCenter.x + 3, y: max.y),
                CGPoint(x: min.x, y: batteryCenter.y - 1.5),
                CGPoint(x: batteryCenter.x - 1, y: batteryCenter.y - 1.5)
            ]
        } else {
            let iconSize = CGSize(width: 9, height: height + 2)
            let minY = batteryCenter.y - iconSize.height / 2
            let maxY = batteryCenter.y + iconSize.height / 2

            points = [
                CGPoint(x: batteryCenter.x - 1.5, y: minY + 0.5),
                CGPoint(x: batteryCenter.x + 1.5, y: minY + 0.5),
                CGPoint(x: batteryCenter.x + 1.5, y: batteryCenter.y - 2.5),
                CGPoint(x: batteryCenter.x + 4, y: batteryCenter.y + 0.5),
                CGPoint(x: batteryCenter.x + 4, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x + 2.75, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x + 2.75, y: maxY - 0.25),
                CGPoint(x: batteryCenter.x + 0.25, y: maxY - 0.25),
                CGPoint(x: batteryCenter.x + 0.25, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x - 0.25, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x - 0.25, y: maxY - 0.25),
                CGPoint(x: batteryCenter.x - 2.75, y: maxY - 0.25),
                CGPoint(x: batteryCenter.x - 2.75, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x - 4, y: batteryCenter.y + 4.25),
                CGPoint(x: batteryCenter.x - 4, y: batteryCenter.y + 0.5),
                CGPoint(x: batteryCenter.x - 1.5, y: batteryCenter.y - 2.5),
                CGPoint(x: batteryCenter.x - 1.5, y: minY + 0.5)
            ]
        }

        let linePath = NSBezierPath()
        linePath.move(to: points[0])
        for point in points.dropFirst() {
            linePath.line(to: point)
        }
        linePath.line(to: points[0])

        NSColor.textColor.set()
        linePath.fill()

        context.saveGState()
        context.setBlendMode(.destinationOut)
        NSColor.textColor.set()
        linePath.lineWidth = 1
        linePath.stroke()
        context.restoreGState()
    }

}

private extension String {
    func width(using font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (self as NSString).size(withAttributes: attributes).width
    }
}
